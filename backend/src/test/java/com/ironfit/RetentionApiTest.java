package com.ironfit;

import static org.assertj.core.api.Assertions.assertThat;

import com.fasterxml.jackson.databind.JsonNode;
import java.sql.Date;
import java.time.LocalDate;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.MethodOrderer;
import org.junit.jupiter.api.Order;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.TestMethodOrder;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.jdbc.core.JdbcTemplate;

/** Membres à risque : droits d'accès, détection, analyse automatique et relances manuelles. */
@TestMethodOrder(MethodOrderer.OrderAnnotation.class)
class RetentionApiTest extends ApiTestSupport {
    static final String REMINDER_TITLE = "On ne vous a pas vu depuis un moment";

    @Autowired JdbcTemplate jdbc;
    String admin, sami, leila, youssef, amira;

    @BeforeEach
    void tokens() throws Exception {
        admin = login("admin");
        sami = login("sami");
        leila = login("leila");
        youssef = login("youssef");
        amira = login("amira");
    }

    @Test
    @Order(1)
    void seulsLAdminEtLesCoachsConsultentLesMembresARisque() throws Exception {
        assertThat(get("risk", null).status()).isEqualTo(401);
        assertThat(get("risk", youssef).status()).isEqualTo(403);
        assertThat(get("risk", amira).status()).isEqualTo(403);
        assertThat(get("risk", admin).status()).isEqualTo(200);
        assertThat(get("risk", sami).status()).isEqualTo(200);
        assertThat(post("risk/run", null, sami).status()).isEqualTo(403);
        assertThat(post("risk/run", null, youssef).status()).isEqualTo(403);
    }

    @Test
    @Order(2)
    void unCoachNeVoitQueSesClientsActifs() throws Exception {
        assertThat(texts(get("risk?all=true", sami).body(), "login")).containsExactlyInAnyOrder("leila", "youssef"); // pas Amira : demande en attente
        assertThat(get("risk?all=true", leila).body().size()).isZero();                                              // Leila n'a aucun client
        assertThat(texts(get("risk?all=true", admin).body(), "login")).contains("youssef", "leila", "amira");
        JsonNode first = get("risk?all=true", admin).body().get(0);
        assertThat(first.has("score")).isTrue();
        assertThat(first.has("level")).isTrue();
        assertThat(first.get("reasons").isArray()).isTrue();
    }

    @Test
    @Order(3)
    void unMembreInactifRemonteEnRisqueEleve() throws Exception {
        assertThat(texts(get("risk", sami).body(), "login")).doesNotContain("youssef"); // actif et abonné : risque faible
        // Youssef arrête de venir : dernière séance il y a 20 jours, dernière présence il y a 25 jours, abonnement qui expire dans 3 jours
        jdbc.update("update workouts set done_on = ? where user_id = ?", Date.valueOf(LocalDate.now().minusDays(20)), id("youssef"));
        jdbc.update("update checkins set checkin_on = ? where member_id = ?", Date.valueOf(LocalDate.now().minusDays(25)), id("youssef"));
        jdbc.update("update users set sub_end = ? where login = 'youssef'", Date.valueOf(LocalDate.now().plusDays(3)));

        JsonNode list = get("risk", sami).body();
        JsonNode y = list.get(0);
        assertThat(y.get("login").asText()).isEqualTo("youssef");
        assertThat(y.get("level").asText()).isEqualTo("high");
        assertThat(y.get("score").asInt()).isGreaterThanOrEqualTo(60);
        assertThat(y.get("days_inactive").asInt()).isEqualTo(20);
        assertThat(y.get("reasons").size()).isGreaterThanOrEqualTo(2);
        assertThat(y.get("last_reminder").isNull()).isTrue();
    }

    @Test
    @Order(4)
    void lAnalyseAutomatiqueRelanceLeMembreEtPrevientSonCoachUneSeuleFois() throws Exception {
        assertThat(post("risk/run", null, admin).body().get("alerts").asInt()).isEqualTo(1);   // Youssef uniquement

        assertThat(texts(get("notifications", youssef).body().get("items"), "title")).contains(REMINDER_TITLE);
        assertThat(texts(get("notifications", sami).body().get("items"), "title")).contains("Membre à risque : Youssef Karray");
        assertThat(get("risk", sami).body().get(0).get("last_reminder").isNull()).isFalse();

        assertThat(post("risk/run", null, admin).body().get("alerts").asInt()).isZero();       // délai de 7 jours : pas de doublon
    }

    @Test
    @Order(5)
    void relanceManuelleReserveeAuCoachDuMembreOuAdminEtLimiteeAUneParJour() throws Exception {
        long leilaId = id("leila");
        assertThat(post("risk/" + leilaId + "/remind", null, youssef).status()).isEqualTo(403);   // membre simple
        assertThat(post("risk/" + leilaId + "/remind", null, leila).status()).isEqualTo(403);     // pas son propre coach
        assertThat(post("risk/" + id("amira") + "/remind", null, sami).status()).isEqualTo(403);  // demande encore en attente
        assertThat(post("risk/999999/remind", null, sami).status()).isEqualTo(404);
        assertThat(post("risk/" + id("admin") + "/remind", null, sami).status()).isEqualTo(404);  // l'admin n'est pas un membre

        Res sent = post("risk/" + leilaId + "/remind", null, sami);
        assertThat(sent.status()).isEqualTo(200);
        assertThat(sent.body().get("ok").asBoolean()).isTrue();
        assertThat(sent.body().get("email_sent").asBoolean()).isFalse();            // adresse fictive @ironfit.local
        assertThat(sent.body().get("email_info").asText()).contains("fictive");
        assertThat(texts(get("notifications", leila).body().get("items"), "title")).contains(REMINDER_TITLE);
        Res again = post("risk/" + leilaId + "/remind", null, sami);
        assertThat(again.status()).isEqualTo(409);
        assertThat(again.error()).contains("déjà été envoyée");

        assertThat(post("risk/" + id("amira") + "/remind", null, admin).status()).isEqualTo(200); // l'admin peut relancer n'importe qui
    }
}
