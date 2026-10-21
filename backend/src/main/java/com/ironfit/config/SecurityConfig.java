package com.ironfit.config;

import com.ironfit.repository.UserRepository;
import com.ironfit.security.JwtAuthFilter;
import com.ironfit.security.JwtService;
import com.ironfit.security.PasswordHasher;
import com.ironfit.security.RestAuthHandlers;
import jakarta.servlet.http.HttpServletResponse;
import java.util.List;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configurers.AbstractHttpConfigurer;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;
import org.springframework.security.web.header.writers.ReferrerPolicyHeaderWriter;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.CorsConfigurationSource;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;
import org.springframework.web.filter.OncePerRequestFilter;

/**
 * API sans session (JWT en en-tête Bearer, pas de cookie → CSRF sans objet).
 * Routes publiques : inscription, connexion, mot de passe oublié / réinitialisation ; tout le reste de /api exige un jeton.
 * Les règles fines (admin, coach de ce client, propriétaire…) sont appliquées par @PreAuthorize et par les services.
 */
@Configuration
@EnableMethodSecurity
public class SecurityConfig {
    private static final long MAX_BODY = 100_000;

    @Bean
    public PasswordEncoder passwordEncoder() { return new PasswordHasher(); }

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http, JwtService jwt, UserRepository users, RestAuthHandlers handlers) throws Exception {
        http
                .csrf(AbstractHttpConfigurer::disable)
                .cors(c -> {})
                .httpBasic(AbstractHttpConfigurer::disable)
                .formLogin(AbstractHttpConfigurer::disable)
                .logout(AbstractHttpConfigurer::disable)
                .sessionManagement(s -> s.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
                .headers(h -> h.referrerPolicy(r -> r.policy(ReferrerPolicyHeaderWriter.ReferrerPolicy.NO_REFERRER)))
                .exceptionHandling(e -> e.authenticationEntryPoint(handlers).accessDeniedHandler(handlers))
                .authorizeHttpRequests(a -> a
                        .requestMatchers(HttpMethod.OPTIONS, "/**").permitAll()
                        .requestMatchers(HttpMethod.POST, "/api/signup", "/api/login", "/api/forgot", "/api/reset").permitAll()
                        .requestMatchers("/error").permitAll()
                        .requestMatchers("/api/**").authenticated()
                        .anyRequest().permitAll())
                .addFilterBefore(new JwtAuthFilter(jwt, users), UsernamePasswordAuthenticationFilter.class)
                .addFilterBefore(bodySizeLimit(), JwtAuthFilter.class);
        return http.build();
    }

    /** CORS pour Flutter Web : origines configurables (CORS_ORIGINS), aucun cookie autorisé. */
    @Bean
    public CorsConfigurationSource corsConfigurationSource(AppProperties props) {
        CorsConfiguration c = new CorsConfiguration();
        c.setAllowedOriginPatterns(props.corsOrigins());
        c.setAllowedMethods(List.of("GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"));
        c.setAllowedHeaders(List.of("Content-Type", "Authorization"));
        c.setAllowCredentials(false);
        c.setMaxAge(3600L);
        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/api/**", c);
        return source;
    }

    /** Refuse les corps de requête de plus de 100 Ko (413). */
    private static OncePerRequestFilter bodySizeLimit() {
        return new OncePerRequestFilter() {
            @Override
            protected void doFilterInternal(jakarta.servlet.http.HttpServletRequest req, HttpServletResponse res, jakarta.servlet.FilterChain chain)
                    throws java.io.IOException, jakarta.servlet.ServletException {
                if (req.getContentLengthLong() > MAX_BODY) {
                    res.setStatus(413);
                    res.setContentType("application/json;charset=UTF-8");
                    res.getWriter().write("{\"error\":\"Requête trop grande\",\"status\":413}");
                    return;
                }
                chain.doFilter(req, res);
            }
        };
    }
}
