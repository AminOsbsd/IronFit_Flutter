package com.ironfit.ai;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.ironfit.config.AiCoachProperties;
import com.ironfit.exception.ApiException;
import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.net.http.HttpTimeoutException;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.TimeUnit;
import java.util.function.Consumer;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;

/**
 * Appel de l'API OpenRouter (format OpenAI /chat/completions) en streaming SSE.
 * Toutes les erreurs sont converties en {@link ApiException} avec un message lisible ; jamais de 401 renvoyé à l'application
 * (un 401 la déconnecterait), jamais la clé ni le contenu des messages dans les journaux.
 */
@Component
public class OpenRouterClient {
    private static final Logger log = LoggerFactory.getLogger(OpenRouterClient.class);

    /** Message au format OpenAI : role = system, user ou assistant. */
    public record Message(String role, String content) {}

    private final AiCoachProperties props;
    private final HttpClient http;
    private final ObjectMapper json = new ObjectMapper();

    public OpenRouterClient(AiCoachProperties props) {
        this.props = props;
        this.http = HttpClient.newBuilder().connectTimeout(Duration.ofSeconds(10)).build();
    }

    /**
     * Ouvre une réponse en streaming. Les erreurs survenues avant le premier octet (clé absente ou invalide, 429, délai, réseau)
     * sont levées ici, ce qui permet de renvoyer un vrai code HTTP au client.
     */
    public Completion stream(List<Message> messages) {
        if (!props.enabled()) {
            throw new ApiException(HttpStatus.SERVICE_UNAVAILABLE, "AI Coach n'est pas configuré sur le serveur (clé OpenRouter manquante).");
        }
        Map<String, Object> body = new LinkedHashMap<>();
        body.put("model", props.model());
        body.put("messages", messages);
        body.put("stream", true);
        body.put("max_tokens", props.maxTokens());
        body.put("temperature", 0.6);

        HttpRequest req;
        try {
            req = HttpRequest.newBuilder(URI.create(props.baseUrl() + "/chat/completions"))
                    .timeout(Duration.ofSeconds(props.timeoutSeconds()))
                    .header("Authorization", "Bearer " + props.apiKey())
                    .header("Content-Type", "application/json")
                    .header("Accept", "text/event-stream")
                    .header("HTTP-Referer", props.siteUrl())
                    .header("X-Title", props.appTitle())
                    .POST(HttpRequest.BodyPublishers.ofString(json.writeValueAsString(body), StandardCharsets.UTF_8))
                    .build();
        } catch (IOException | IllegalArgumentException e) {
            log.error("Requête OpenRouter impossible à construire : {}", e.getClass().getSimpleName());
            throw new ApiException(HttpStatus.INTERNAL_SERVER_ERROR, "AI Coach est mal configuré sur le serveur.");
        }

        HttpResponse<InputStream> res;
        try {
            res = http.send(req, HttpResponse.BodyHandlers.ofInputStream());
        } catch (HttpTimeoutException e) {
            throw timeout();
        } catch (IOException e) {
            log.warn("OpenRouter injoignable : {}", e.getClass().getSimpleName());
            throw unreachable();
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw unreachable();
        }

        if (res.statusCode() >= 400) {
            String detail = upstreamMessage(readQuietly(res.body()));
            log.warn("OpenRouter a répondu {} : {}", res.statusCode(), detail);
            throw forStatus(res.statusCode());
        }
        return new Completion(res.body(), props.maxDurationSeconds());
    }

    /** Code HTTP d'OpenRouter → erreur affichable (https://openrouter.ai/docs/api-reference/errors). */
    static ApiException forStatus(int status) {
        return switch (status) {
            case 401, 403 -> new ApiException(HttpStatus.BAD_GATEWAY, "La clé OpenRouter du serveur est invalide ou refusée. Prévenez l'administrateur.");
            case 402 -> new ApiException(HttpStatus.BAD_GATEWAY, "Le crédit OpenRouter du serveur est épuisé. Prévenez l'administrateur.");
            case 408 -> timeout();
            case 429 -> new ApiException(HttpStatus.TOO_MANY_REQUESTS, "AI Coach est très sollicité. Réessayez dans un instant.");
            case 400, 404, 422 -> new ApiException(HttpStatus.BAD_GATEWAY, "Le modèle d'IA a refusé la demande (modèle OPENROUTER_MODEL invalide ?).");
            default -> new ApiException(HttpStatus.BAD_GATEWAY, "Le service d'IA est momentanément indisponible. Réessayez plus tard.");
        };
    }

    static ApiException timeout() {
        return new ApiException(HttpStatus.GATEWAY_TIMEOUT, "AI Coach met trop de temps à répondre. Réessayez.");
    }

    static ApiException unreachable() {
        return new ApiException(HttpStatus.BAD_GATEWAY, "Impossible de joindre le service d'IA (problème réseau du serveur).");
    }

    private static String readQuietly(InputStream in) {
        try (in) {
            byte[] b = in.readNBytes(4000);
            return new String(b, StandardCharsets.UTF_8);
        } catch (IOException e) {
            return "";
        }
    }

    /** Message d'erreur d'OpenRouter ({"error":{"message":…}}), tronqué pour les journaux. */
    private String upstreamMessage(String body) {
        try {
            String m = json.readTree(body).path("error").path("message").asText("");
            return m.length() > 200 ? m.substring(0, 200) : m;
        } catch (IOException e) {
            return "";
        }
    }

    /** Réponse en cours de réception : lit les événements SSE et transmet chaque morceau de texte. */
    public final class Completion implements AutoCloseable {
        private final InputStream in;
        private volatile boolean expired;

        Completion(InputStream in, int maxSeconds) {
            this.in = in;
            // Durée maximale : fermer le flux débloque la lecture en cours
            CompletableFuture.delayedExecutor(maxSeconds, TimeUnit.SECONDS).execute(() -> {
                expired = true;
                close();
            });
        }

        /** Appelle {@code onDelta} pour chaque morceau de texte, jusqu'à « [DONE] » ou la fin du flux. */
        public void forEachDelta(Consumer<String> onDelta) {
            try (BufferedReader r = new BufferedReader(new InputStreamReader(in, StandardCharsets.UTF_8))) {
                String line;
                while ((line = r.readLine()) != null) {
                    // Lignes vides (séparateurs) et commentaires « : OPENROUTER PROCESSING » ignorés
                    if (!line.startsWith("data:")) continue;
                    String data = line.substring(5).trim();
                    if (data.equals("[DONE]")) return;
                    JsonNode node;
                    try {
                        node = json.readTree(data);
                    } catch (IOException e) {
                        continue; // morceau illisible : ignoré
                    }
                    if (node.has("error")) {
                        log.warn("Erreur OpenRouter pendant le streaming : {}", node.path("error").path("code").asText(""));
                        throw new ApiException(HttpStatus.BAD_GATEWAY, "La réponse d'AI Coach a été interrompue. Réessayez.");
                    }
                    String text = node.path("choices").path(0).path("delta").path("content").asText("");
                    if (!text.isEmpty()) onDelta.accept(text);
                }
            } catch (IOException e) {
                if (expired) throw new ApiException(HttpStatus.GATEWAY_TIMEOUT, "Réponse trop longue : AI Coach a été interrompu.");
                throw new ApiException(HttpStatus.BAD_GATEWAY, "La connexion au service d'IA a été interrompue. Réessayez.");
            }
        }

        @Override
        public void close() {
            try {
                in.close();
            } catch (IOException ignored) {
                // déjà fermé
            }
        }
    }
}
