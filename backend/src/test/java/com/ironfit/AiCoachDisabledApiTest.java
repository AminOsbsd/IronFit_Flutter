package com.ironfit;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.Test;

/** Sans OPENROUTER_API_KEY : AI Coach désactivé proprement (503 + message clair), le reste de l'API fonctionne. */
class AiCoachDisabledApiTest extends ApiTestSupport {
    @Test
    void sansCleLeCoachRepond503AvecUnMessageClair() throws Exception {
        String token = login("youssef");
        assertThat(get("ai-coach/status", token).body().path("enabled").asBoolean()).isFalse();
        Res r = post("ai-coach/chat", Map.of("messages", List.of(Map.of("role", "user", "content", "Salut"))), token);
        assertThat(r.status()).isEqualTo(503);
        assertThat(r.error()).contains("pas configuré");
    }
}
