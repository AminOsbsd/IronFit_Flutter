package com.ironfit;

import static org.assertj.core.api.Assertions.assertThat;

import com.fasterxml.jackson.databind.JsonNode;
import java.util.Map;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/** Coach qui est aussi membre : un seul compte, données personnelles et de coaching séparées. */
class DualRoleApiTest extends ApiTestSupport {
    String sami, leila, youssef;

    @BeforeEach
    void tokens() throws Exception {
        sami = login("sami");
        leila = login("leila");
        youssef = login("youssef");
    }

    private JsonNode classOf(String coachLogin, String token) throws Exception {
        for (JsonNode c : get("classes", token).body()) if (c.get("coach_id").asLong() == id(coachLogin)) return c;
        throw new AssertionError("aucun cours pour " + coachLogin);
    }

    @Test
    void unCoachAbonneReserveUnCoursMaisPasLeSien() throws Exception {
        long other = classOf("sami", leila).get("id").asLong(), own = classOf("leila", leila).get("id").asLong();
        Res b = post("book", Map.of("class_id", other), leila);
        assertThat(b.body().get("booked").asBoolean()).isTrue();
        assertThat(post("book", Map.of("class_id", own), leila).status()).isEqualTo(400);
        // Sami n'a pas d'abonnement : réservation refusée
        assertThat(post("book", Map.of("class_id", own), sami).status()).isEqualTo(403);
        // annulation (bascule)
        assertThat(post("book", Map.of("class_id", other), leila).body().get("booked").asBoolean()).isFalse();
    }

    @Test
    void unCoachPeutDemanderUnAbonnementCommeUnMembre() throws Exception {
        long planId = get("plans", sami).body().get(1).get("id").asLong();
        assertThat(post("requests", Map.of("plan_id", planId), sami).status()).isEqualTo(201);
    }

    @Test
    void programmesPersonnelsEtDeCoachingRestentSepares() throws Exception {
        assertThat(texts(get("programs?scope=personal", leila).body(), "title")).containsExactly("Mobilité du matin");
        assertThat(get("programs?scope=coaching", leila).body().size()).isZero();
        JsonNode coaching = get("programs?scope=coaching", sami).body();
        assertThat(coaching.size()).isEqualTo(1);
        assertThat(coaching.get(0).get("coach_id").asLong()).isEqualTo(id("sami"));
        assertThat(get("programs?scope=personal", sami).body().size()).isZero();
        assertThat(get("programs?scope=coaching", youssef).status()).isEqualTo(403);
    }

    @Test
    void cycleCompletProgrammeDuCoachSeanceDuClientCommentaire() throws Exception {
        Res p = post("programs", Map.of("title", "Gainage", "goal", "Tonus", "client_id", id("leila")), sami);
        assertThat(p.status()).isEqualTo(201);
        long pid = p.body().get("id").asLong();
        assertThat(post("programs/" + pid + "/exercises", Map.of("name", "Planche", "sets", 3, "reps", "45 s"), sami).status()).isEqualTo(201);
        // Leila (cliente ici) voit le programme mais ne peut pas le modifier
        JsonNode detail = get("programs/" + pid, leila).body();
        assertThat(detail.get("can_edit").asBoolean()).isFalse();
        assertThat(detail.get("can_log").asBoolean()).isTrue();
        assertThat(detail.get("items").size()).isEqualTo(1);
        assertThat(detail.at("/items/0/reps").asText()).isEqualTo("45 s");
        assertThat(call("PUT", "programs/" + pid, Map.of("title", "Hack"), leila).status()).isEqualTo(403);
        // Youssef (autre client de Sami) n'y a pas accès
        assertThat(get("programs/" + pid, youssef).status()).isEqualTo(403);

        Res w = post("workouts", Map.of("program_id", pid, "duration", 30, "rpe", 6, "notes", "Dur !"), leila);
        assertThat(w.status()).isEqualTo(201);
        assertThat(texts(get("notifications", sami).body().get("items"), "title")).contains("Séance terminée");
        long wid = w.body().get("id").asLong();
        assertThat(post("workouts/" + wid + "/feedback", Map.of("comment", "Top"), youssef).status()).isEqualTo(403);
        assertThat(post("workouts/" + wid + "/feedback", Map.of("comment", "Top"), sami).status()).isEqualTo(200);
        assertThat(texts(get("workouts?user_id=" + id("leila"), sami).body(), "coach_comment")).containsExactly("Top"); // pas ses séances personnelles
        assertThat(get("workouts?user_id=" + id("leila"), youssef).status()).isEqualTo(403);
        assertThat(texts(get("notifications", leila).body().get("items"), "title")).contains("Nouveau commentaire de votre coach");
    }

    @Test
    void validationDesSeancesRealisees() throws Exception {
        assertThat(post("workouts", Map.of("duration", 9999), youssef).error()).isEqualTo("Durée : 1 à 600 minutes");
        assertThat(post("workouts", Map.of("done_on", "2999-01-01"), youssef).status()).isEqualTo(400);
        long perso = get("programs?scope=personal", leila).body().get(0).get("id").asLong();
        assertThat(post("workouts", Map.of("program_id", perso), youssef).status()).isEqualTo(403);
    }
}
