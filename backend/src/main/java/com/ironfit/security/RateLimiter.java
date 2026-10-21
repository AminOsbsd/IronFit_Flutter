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
        long now = System.currentTimeMillis();
        String key = req.getRemoteAddr() + " " + req.getRequestURI();
        Deque<Long> q = hits.computeIfAbsent(key, k -> new ArrayDeque<>());
        boolean limited;
        synchronized (q) {
            while (!q.isEmpty() && now - q.peekFirst() >= WINDOW_MS) q.pollFirst();
            q.addLast(now);
            limited = q.size() > max;
        }
        if (hits.size() > 10_000) hits.entrySet().removeIf(e -> e.getValue().isEmpty() || now - e.getValue().peekLast() >= WINDOW_MS);
        if (limited) throw ApiException.tooManyRequests();
    }
}
