package com.ironfit;

import static org.assertj.core.api.Assertions.assertThat;

import com.fasterxml.jackson.databind.JsonNode;
import java.time.LocalDate;
import java.util.Map;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

/** Cours, annonces, abonnements, statistiques et intégrité des données. */
class ClassAndDataApiTest extends ApiTestSupport {
    String admin, sami, leila, youssef;

    @BeforeEach
    void tokens() throws Exception {
        admin = login("admin");
        sami = login("sami");
        leila = login("leila");
        youssef = login("youssef");
    }

    private JsonNode classOf(String coachLogin) throws Exception {
        for (JsonNode c : get("classes", admin).body()) if (c.get("coach_id").asLong() == id(coachLogin)) return c;
        throw new AssertionError("aucun cours pour " + coachLogin);
    }

    @Test
    void validationDesCoursEtProprieteDuCoach() throws Exception {
        assertThat(post("classes", Map.of("day", 9, "time", "18:00", "title", "X"), sami).error()).isEqualTo("Valeur invalide : Jour");
        assertThat(post("classes", Map.of("day", 1, "time", "25:00", "title", "X"), sami).status()).isEqualTo(400);
        assertThat(post("classes", Map.of("day", 1, "time", "18:00", "title", "X", "spots", 0), sami).error()).isEqualTo("Places : 1 à 500");
        Res c = post("classes", Map.of("day", 1, "time", "07:00", "title", "Boxe", "coach_id", id("leila")), sami);
        assertThat(c.status()).isEqualTo(201);
        JsonNode mine = null;
        for (JsonNode x : get("classes", sami).body()) if (x.get("id").asLong() == c.body().get("id").asLong()) mine = x;
        assertThat(mine.get("coach_id").asLong()).isEqualTo(id("sami")); // le coach ne crée que pour lui-même
        long leilaClass = classOf("leila").get("id").asLong();
        assertThat(call("DELETE", "classes/" + leilaClass, null, sami).status()).isEqualTo(403);
        assertThat(get("classes/" + leilaClass + "/participants", sami).status()).isEqualTo(403);
        assertThat(post("classes", Map.of("day", 1, "time", "08:00", "title", "Admin", "coach_id", id("youssef")), admin).error()).isEqualTo("Coach introuvable");
    }

    @Test
    void supprimerUnCoursPrevientLesMembresInscrits() throws Exception {
        long c = classOf("sami").get("id").asLong();
        post("book", Map.of("class_id", c), youssef);
        assertThat(call("DELETE", "classes/" + c, null, admin).status()).isEqualTo(200);
        assertThat(texts(get("notifications", youssef).body().get("items"), "title")).contains("Séance annulée");
    }

    @Test
    void pointageSeulementLesInscritsLeJourDuCours() throws Exception {
        long c = classOf("sami").get("id").asLong();
        assertThat(post("classes/" + c + "/present", Map.of("member_id", id("amira")), sami).status()).isEqualTo(404);
        // cours créé pour aujourd'hui : l'inscrit peut être pointé
        int today = LocalDate.now().getDayOfWeek().getValue() - 1;
        long todayClass = post("classes", Map.of("day", today, "time", "06:00", "title", "Réveil"), sami).body().get("id").asLong();
        post("book", Map.of("class_id", todayClass), youssef);
        assertThat(post("classes/" + todayClass + "/present", Map.of("member_id", id("youssef")), sami).status()).isEqualTo(200);
        JsonNode participants = get("classes/" + todayClass + "/participants", sami).body();
        assertThat(participants.get(0).get("present").asBoolean()).isTrue();
    }

    @Test
    void annoncesUnCoachNeModifieQueLesSiennesEtLesMembresSontNotifies() throws Exception {
        long adminAnn = get("announcements", sami).body().get(0).get("id").asLong();
        assertThat(call("DELETE", "announcements/" + adminAnn, null, sami).status()).isEqualTo(403);
        long a = post("announcements", Map.of("title", "Cours offert", "body", "Samedi"), sami).body().get("id").asLong();
        assertThat(call("PUT", "announcements/" + a, Map.of("title", "Cours offert !"), sami).status()).isEqualTo(200);
        assertThat(call("DELETE", "announcements/" + a, null, leila).status()).isEqualTo(403);
        assertThat(texts(get("notifications", youssef).body().get("items"), "title")).anyMatch(t -> t.contains("Cours offert"));
        JsonNode first = get("announcements", youssef).body().get(0);
        assertThat(first.get("author_name").asText()).isEqualTo("Sami Ben Ali");
        assertThat(first.get("posted_on").asText()).isEqualTo(LocalDate.now().toString());
    }

    @Test
    void demandeDabonnementValidationAdminProlongeEtEnregistreLePaiement() throws Exception {
        String amira = login("amira");
        String before = get("me", amira).body().get("sub_end").asText();
        long plan = get("plans", amira).body().get(1).get("id").asLong();
        long r = post("requests", Map.of("plan_id", plan), amira).body().get("id").asLong();
        assertThat(post("requests", Map.of("plan_id", plan), amira).status()).isEqualTo(409);
        assertThat(post("requests/" + r + "/approve", Map.of("method", "Carte"), sami).status()).isEqualTo(403);
        assertThat(texts(get("requests", admin).body(), "member_name")).contains("Amira Jlassi");
        assertThat(post("requests/" + r + "/approve", Map.of("method", "Carte"), admin).status()).isEqualTo(200);
        String after = get("me", amira).body().get("sub_end").asText();
        assertThat(after).isGreaterThan(before);
        assertThat(texts(get("payments", amira).body(), "method")).contains("Carte");
        assertThat(texts(get("notifications", amira).body().get("items"), "title")).contains("Abonnement activé");
    }

    @Test
    void statistiquesGlobalesPourLadminLimiteesPourLeCoach() throws Exception {
        JsonNode a = get("stats", admin).body(), c = get("stats", sami).body();
        assertThat(a.has("revenue")).isTrue();
        assertThat(a.get("athletes").asLong()).isEqualTo(4);
        assertThat(c.has("revenue")).isFalse();
        assertThat(c.get("clients").asLong()).isEqualTo(2);
        assertThat(c.get("pending_clients").asLong()).isEqualTo(1);
    }

    @Test
    void catalogueRechercheEtSuppressionDunTarifReference() throws Exception {
        assertThat(texts(get("plans?q=trim", youssef).body(), "name")).containsExactly("Trimestriel");
        long monthly = get("plans?q=mensuel", admin).body().get(0).get("id").asLong();
        // le tarif est référencé par des membres et des demandes : suppression possible (ON DELETE SET NULL / CASCADE)
        assertThat(call("DELETE", "plans/" + monthly, null, admin).status()).isEqualTo(200);
        assertThat(get("me", youssef).body().get("plan_id").isNull()).isTrue();
        assertThat(post("equipment", Map.of("name", "Rameur", "status", "Cassé"), sami).error()).isEqualTo("État invalide");
        assertThat(post("equipment", Map.of("name", "Rameur", "status", "OK", "qty", 2), sami).status()).isEqualTo(201);
    }
}
