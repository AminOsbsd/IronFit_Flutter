package com.ironfit.security;

import com.ironfit.entity.User;
import com.ironfit.repository.UserRepository;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.util.ArrayList;
import java.util.List;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.filter.OncePerRequestFilter;

/**
 * Lit « Authorization: Bearer <jeton> », vérifie le jeton puis l'état du compte en base (existant, actif, même version de jeton).
 * En cas d'échec, la raison est mémorisée pour la réponse 401 ({@link RestAuthHandlers}).
 * Autorités : ROLE_ADMIN, ROLE_COACH, ROLE_MEMBER (athlètes et coachs).
 */
public class JwtAuthFilter extends OncePerRequestFilter {
    public static final String AUTH_ERROR = "ironfit.authError";
    private final JwtService jwt;
    private final UserRepository users;

    public JwtAuthFilter(JwtService jwt, UserRepository users) {
        this.jwt = jwt;
        this.users = users;
    }

    @Override
    protected void doFilterInternal(HttpServletRequest req, HttpServletResponse res, FilterChain chain) throws ServletException, IOException {
        String header = req.getHeader("Authorization");
        if (header != null && header.regionMatches(true, 0, "Bearer ", 0, 7)) {
            String error = "Session expirée, reconnectez-vous";
            var data = jwt.read(header.substring(7).trim());
            if (data.isPresent()) {
                User u = users.findById(data.get().userId()).orElse(null);
                if (u != null && u.getTokenVersion() == data.get().tokenVersion()) {
                    if (u.isActive()) {
                        authenticate(u);
                        error = null;
                    } else {
                        error = "Compte désactivé. Contactez l’accueil de la salle.";
                    }
                }
            }
            if (error != null) req.setAttribute(AUTH_ERROR, error);
        }
        chain.doFilter(req, res);
    }

    private static void authenticate(User u) {
        List<SimpleGrantedAuthority> roles = new ArrayList<>();
        roles.add(new SimpleGrantedAuthority("ROLE_" + u.getRole().name()));
        if (u.isMember()) roles.add(new SimpleGrantedAuthority("ROLE_MEMBER"));
        var auth = new UsernamePasswordAuthenticationToken(CurrentUser.of(u), null, roles);
        SecurityContextHolder.getContext().setAuthentication(auth);
    }
}
