package com.ironfit.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * AI Coach (OpenRouter) — préfixe « ironfit.ai » dans application.properties, surchargeable par variables d'environnement.
 * La clé reste côté serveur : elle n'est jamais renvoyée à l'application ni journalisée.
 *
 * @param apiKey             clé OpenRouter (OPENROUTER_API_KEY) ; vide = AI Coach désactivé (503)
 * @param model              modèle OpenRouter (OPENROUTER_MODEL)
 * @param baseUrl            adresse de l'API compatible OpenAI (OPENROUTER_BASE_URL, modifiable pour les tests)
 * @param siteUrl            en-tête HTTP-Referer recommandé par OpenRouter
 * @param appTitle           en-tête X-Title recommandé par OpenRouter
 * @param timeoutSeconds     délai maximal pour recevoir le début de la réponse
 * @param maxDurationSeconds durée maximale d'une réponse en streaming (coupée au-delà)
 * @param maxTokens          longueur maximale d'une réponse
 * @param rateLimit          messages par minute et par utilisateur
 */
@ConfigurationProperties(prefix = "ironfit.ai")
public record AiCoachProperties(
        String apiKey,
        String model,
        String baseUrl,
        String siteUrl,
        String appTitle,
        int timeoutSeconds,
        int maxDurationSeconds,
        int maxTokens,
        int rateLimit) {

    public static final String DEFAULT_MODEL = "anthropic/claude-haiku-5.5";

    public AiCoachProperties {
        if (model == null || model.isBlank()) model = DEFAULT_MODEL;
        if (baseUrl == null || baseUrl.isBlank()) baseUrl = "https://openrouter.ai/api/v1";
        baseUrl = baseUrl.replaceAll("/+$", "");
        if (siteUrl == null || siteUrl.isBlank()) siteUrl = "https://github.com/AminOsbsd/IronFit_Flutter";
        if (appTitle == null || appTitle.isBlank()) appTitle = "IronFit";
        if (timeoutSeconds <= 0) timeoutSeconds = 30;
        if (maxDurationSeconds <= 0) maxDurationSeconds = 90;
        if (maxTokens <= 0) maxTokens = 700;
        if (rateLimit <= 0) rateLimit = 12;
    }

    /** Valeur d'exemple de .env.example : copiée telle quelle, elle ne doit pas activer AI Coach. */
    static final String PLACEHOLDER_KEY = "sk-or-v1-your-key-here";

    public boolean enabled() { return apiKey != null && !apiKey.isBlank() && !PLACEHOLDER_KEY.equals(apiKey.trim()); }

    /** Jamais la clé dans les journaux, même par accident (toString d'un record). */
    @Override
    public String toString() {
        return "AiCoachProperties[model=" + model + ", baseUrl=" + baseUrl + ", enabled=" + enabled() + "]";
    }
}
