package com.ironfit.controller;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.ironfit.ai.OpenRouterClient;
import com.ironfit.ai.OpenRouterClient.Completion;
import com.ironfit.ai.OpenRouterClient.Message;
import com.ironfit.config.AiCoachProperties;
import com.ironfit.dto.AiCoachDtos.ChatRequest;
import com.ironfit.exception.ApiException;
import com.ironfit.exception.ErrorResponse;
import com.ironfit.security.CurrentUser;
import com.ironfit.security.RateLimiter;
import com.ironfit.service.AiCoachService;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.validation.Valid;
import java.io.IOException;
import java.io.OutputStream;
import java.io.UncheckedIOException;
import java.nio.charset.StandardCharsets;
import java.util.List;
import java.util.Map;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

/**
 * AI Coach : proxy sécurisé vers OpenRouter (la clé ne quitte jamais le serveur).
 * Réponse en flux SSE (text/event-stream) : {@code data: {"delta":"…"}} pour chaque morceau, puis {@code data: {"done":true}},
 * ou {@code data: {"error":"…"}} si la réponse est interrompue. Les erreurs survenant avant le premier morceau
 * (configuration, 429, délai, réseau, validation) sont renvoyées au format JSON habituel avec leur code HTTP.
 */
@RestController
@RequestMapping("/api/ai-coach")
public class AiCoachController {
    private final AiCoachService coach;
    private final OpenRouterClient openRouter;
    private final RateLimiter limiter;
    private final AiCoachProperties props;
    private final ObjectMapper json;

    public AiCoachController(AiCoachService coach, OpenRouterClient openRouter, RateLimiter limiter, AiCoachProperties props,
                             ObjectMapper json) {
        this.coach = coach;
        this.openRouter = openRouter;
        this.limiter = limiter;
        this.props = props;
        this.json = json;
    }

    /** Indique à l'application si AI Coach est configuré (sans jamais exposer la clé). */
    @GetMapping("/status")
    public Map<String, Object> status() { return Map.of("enabled", props.enabled(), "model", props.model()); }

    @PostMapping("/chat")
    public void chat(@AuthenticationPrincipal CurrentUser me, @Valid @RequestBody ChatRequest body, HttpServletResponse res) throws IOException {
        Completion opened;
        try {
            limiter.check("ai-coach " + me.id(), props.rateLimit(), "Vous envoyez beaucoup de messages : patientez une minute avant de réessayer.");
            List<Message> messages = coach.prepare(me, body);
            opened = openRouter.stream(messages);
        } catch (ApiException e) {
            // Écrit directement en JSON : un client qui n'accepte que text/event-stream reçoit quand même l'erreur (sinon 500)
            res.setStatus(e.getStatus().value());
            res.setContentType("application/json");
            res.setCharacterEncoding("UTF-8");
            res.getWriter().write(json.writeValueAsString(ErrorResponse.of(e.getStatus().value(), e.getMessage())));
            return;
        }

        try (Completion completion = opened) {
            res.setStatus(200);
            res.setContentType("text/event-stream");
            res.setCharacterEncoding("UTF-8");
            res.setHeader("Cache-Control", "no-cache");
            res.setHeader("X-Accel-Buffering", "no"); // pas de mise en tampon derrière un reverse proxy nginx
            OutputStream out = res.getOutputStream();
            try {
                completion.forEachDelta(text -> send(out, Map.of("delta", text)));
                send(out, Map.of("done", true));
            } catch (ApiException e) {
                send(out, Map.of("error", e.getMessage()));
            }
        } catch (UncheckedIOException e) {
            // L'application a fermé la connexion (panneau fermé) : la réponse amont est abandonnée
        }
    }

    private void send(OutputStream out, Map<String, Object> event) {
        try {
            out.write(("data: " + json.writeValueAsString(event) + "\n\n").getBytes(StandardCharsets.UTF_8));
            out.flush();
        } catch (IOException e) {
            throw new UncheckedIOException(e);
        }
    }
}
