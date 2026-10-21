package com.ironfit.config;

import java.util.List;
import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * Paramètres applicatifs (préfixe « ironfit » dans application.properties, surchargeables par variables d'environnement).
 *
 * @param jwtSecret     clé HMAC des jetons (32 caractères min.) ; vide = clé générée dans {@code dataDir/jwt.secret}
 * @param tokenDays     durée de validité d'un jeton
 * @param dataDir       dossier local (clé JWT générée)
 * @param corsOrigins   origines autorisées pour Flutter Web
 * @param showResetCode renvoie le code « mot de passe oublié » à l'application (démo uniquement)
 * @param seedDemo      données de démonstration quand la base est vide
 * @param adminPassword mot de passe du compte « admin » créé quand la base est vide
 * @param rateLimit     tentatives d'authentification par minute, par IP et par route
 */
@ConfigurationProperties(prefix = "ironfit")
public record AppProperties(
        String jwtSecret,
        int tokenDays,
        String dataDir,
        List<String> corsOrigins,
        boolean showResetCode,
        boolean seedDemo,
        String adminPassword,
        int rateLimit) {

    public AppProperties {
        if (tokenDays <= 0) tokenDays = 7;
        if (dataDir == null || dataDir.isBlank()) dataDir = "./data";
        if (corsOrigins == null || corsOrigins.isEmpty()) corsOrigins = List.of("*");
        if (rateLimit <= 0) rateLimit = 10;
    }
}
