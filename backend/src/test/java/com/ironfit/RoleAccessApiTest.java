package com.ironfit;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.Map;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/** Contrôle d'accès par rôle appliqué côté serveur. */
class RoleAccessApiTest extends ApiTestSupport {
    String admin, coach, member;

    @BeforeEach
    void tokens() throws Exception {
        admin = login("admin");
        coach = login("sami");
        member = login("youssef");
    }

    @Test
    void unMembreNePeutPasAccederALaGestion() throws Exception {
        assertThat(get("members", member).status()).isEqualTo(403);
        assertThat(get("stats", member).status()).isEqualTo(403);
        assertThat(get("equipment", member).status()).isEqualTo(403);
        assertThat(get("coaching", member).status()).isEqualTo(403);
        assertThat(post("plans", Map.of("name", "X", "price", 1), member).status()).isEqualTo(403);
        assertThat(post("members", Map.of("name", "Xx", "login", "xxx", "email", "x@x.tn", "password", "123456"), member).status()).isEqualTo(403);
        assertThat(post("announcements", Map.of("title", "x"), member).status()).isEqualTo(403);
        assertThat(post("checkins", Map.of("member_id", id("youssef")), member).status()).isEqualTo(403);
    }

    @Test
    void unCoachNePeutPasFaireLesActionsAdmin() throws Exception {
        assertThat(post("plans", Map.of("name", "X", "price", 1), coach).status()).isEqualTo(403);
        assertThat(post("members", Map.of("name", "Xx", "login", "xxx", "email", "x@x.tn", "password", "123456"), coach).status()).isEqualTo(403);
        assertThat(post("members/" + id("amira") + "/status", Map.of("active", false), coach).status()).isEqualTo(403);
        assertThat(post("coaching/assign", Map.of("coach_id", id("sami"), "client_id", id("amira")), coach).status()).isEqualTo(403);
        get("requests", coach).body().forEach(r -> assertThat(r.get("member_id").asLong()).isEqualTo(id("sami")));
    }

    @Test
    void paiementsChacunLesSiensAdminTout() throws Exception {
        assertThat(get("payments", admin).body().size()).isGreaterThanOrEqualTo(3);
        get("payments", member).body().forEach(p -> assertThat(p.get("member_id").asLong()).isEqualTo(id("youssef")));
        assertThat(get("payments", coach).body().size()).isZero();
        assertThat(get("payments?member_id=" + id("youssef"), coach).status()).isEqualTo(403);
    }

    @Test
    void ladminGereLesUtilisateursRechercheEtPagination() throws Exception {
        var list = get("members?q=karray", admin).body();
        assertThat(texts(list, "login")).containsExactly("youssef");
        assertThat(list.get(0).has("password_hash")).isFalse();
        assertThat(list.get(0).has("token_version")).isFalse();
        assertThat(get("members?limit=2", admin).body().size()).isEqualTo(2);
        assertThat(get("members?limit=2&offset=2", admin).body().size()).isEqualTo(2);
        assertThat(get("members?role=coach", admin).body().size()).isEqualTo(2);
        Res r = post("members", Map.of("name", "Coach Test", "login", "coachtest", "email", "ct@test.tn", "password", "123456", "role", "coach", "specialty", "Boxe"), admin);
        assertThat(r.status()).isEqualTo(201);
        assertThat(texts(get("coaches", member).body(), "name")).contains("Coach Test");
        assertThat(call("PUT", "members/" + id("admin"), Map.of("name", "Pirate", "login", "admin", "email", "a@a.tn"), admin).status()).isEqualTo(403);
        assertThat(post("members", Map.of("name", "Sans Mdp", "login", "sansmdp", "email", "s@test.tn"), admin).error()).isEqualTo("Mot de passe obligatoire");
    }
}
