package com.ironfit.security;

import com.ironfit.config.AppProperties;
import com.ironfit.exception.ApiException;
import jakarta.servlet.http.HttpServletRequest;
import java.util.ArrayDeque;
import java.util.Deque;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import org.springframework.stereotype.Component;

/**
 * Fenêtre glissante d'une minute par IP et par route pour la connexion, l'inscription et la réinitialisation.
 * En mémoire : prévu pour une seule instance du serveur.
 */
@Component
public class RateLimiter {
    private static final long WINDOW_MS = 60_000;
    private final int max;
    private final Map<String, Deque<Long>> hits = new ConcurrentHashMap<>();

    public RateLimiter(AppProperties props) { this.max = props.rateLimit(); }

    public void check(HttpServletRequest req) {
        if (limited(req.getRemoteAddr() + " " + req.getRequestURI(), max)) throw ApiException.tooManyRequests();
    }

    /** Variante à clé libre (ex. par utilisateur) et seuil propre, avec un message adapté (AI Coach). */
    public void check(String key, int maxPerMinute, String message) {
        if (limited(key, maxPerMinute)) throw new ApiException(org.springframework.http.HttpStatus.TOO_MANY_REQUESTS, message);
    }

    private boolean limited(String key, int maxPerMinute) {
        long now = System.currentTimeMillis();
        Deque<Long> q = hits.computeIfAbsent(key, k -> new ArrayDeque<>());
        boolean limited;
        synchronized (q) {
            while (!q.isEmpty() && now - q.peekFirst() >= WINDOW_MS) q.pollFirst();
            q.addLast(now);
            limited = q.size() > maxPerMinute;
        }
        if (hits.size() > 10_000) hits.entrySet().removeIf(e -> e.getValue().isEmpty() || now - e.getValue().peekLast() >= WINDOW_MS);
        return limited;
    }
}
