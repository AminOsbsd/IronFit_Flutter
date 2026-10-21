package com.ironfit;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.Test;
import org.springframework.test.context.TestPropertySource;

/** Limitation de débit des routes d'authentification. */
@TestPropertySource(properties = "ironfit.rate-limit=3")
class RateLimitApiTest extends ApiTestSupport {
    @Test
    void tropDeTentativesDeConnexionDonne429() throws Exception {
        List<Integer> codes = new ArrayList<>();
        for (int i = 0; i < 5; i++) codes.add(post("login", Map.of("login", "x", "password", "y"), null).status());
        assertThat(codes).containsExactly(401, 401, 401, 429, 429);
    }
}
