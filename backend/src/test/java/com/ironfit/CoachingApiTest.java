package com.ironfit;

import static org.assertj.core.api.Assertions.assertThat;

import com.fasterxml.jackson.databind.JsonNode;
import java.util.Map;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.MethodOrderer;
import org.junit.jupiter.api.Order;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.TestMethodOrder;

/** Coachs et clients : isolation des données personnelles. */
@TestMethodOrder(MethodOrderer.OrderAnnotation.class)
class CoachingApiTest extends ApiTestSupport {
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
    void unCoachNeVoitQueSesClientsActifs() throws Exception {
        assertThat(texts(get("members", sami).body(), "login")).containsExactlyInAnyOrder("leila", "youssef"); // Amira : demande en attente
        assertThat(get("members/" + id("amira"), sami).status()).isEqualTo(403);
        assertThat(get("members", leila).body().size()).isZero();
    }

    @Test
    @Order(2)
    void mesuresAccesLimiteAuMembreASonCoachEtALadmin() throws Exception {
        assertThat(get("measures?member_id=" + id("youssef"), sami).status()).isEqualTo(200);
        assertThat(get("measures?member_id=" + id("youssef"), leila).status()).isEqualTo(403);
        assertThat(get("measures?member_id=" + id("youssef"), amira).status()).isEqualTo(403);
        assertThat(post("measures", Map.of("member_id", id("amira"), "weight", 60), sami).status()).isEqualTo(403);
        assertThat(post("measures", Map.of("member_id", id("admin"), "weight", 60), sami).status()).isEqualTo(404);
        assertThat(post("measures", Map.of("member_id", id("youssef"), "weight", 80), sami).status()).isEqualTo(201);
        assertThat(post("measures", Map.of("member_id", id("youssef"), "weight", "abc"), sami).status()).isEqualTo(400);
        assertThat(post("measures", Map.of("member_id", id("youssef"), "weight", 900), sami).error()).isEqualTo("Poids : 20 à 400 kg");
        assertThat(post("measures", Map.of("member_id", id("amira"), "weight", 61), amira).status()).isEqualTo(201); // suivi personnel
        JsonNode clients = get("measures?scope=clients", sami).body();
        clients.forEach(m -> assertThat(m.get("member_id").asLong()).isIn(id("youssef"), id("leila")));
        assertThat(get("measures?scope=clients", youssef).status()).isEqualTo(403);
    }

    @Test
    @Order(3)
    void demandeAcceptationAccesPuisFinDuSuiviCoupeLacces() throws Exception {
        JsonNode pending = null;
        for (JsonNode l : get("coaching/clients", sami).body()) if (l.get("client_id").asLong() == id("amira")) pending = l;
        assertThat(pending).isNotNull();
        assertThat(pending.get("status").asText()).isEqualTo("pending");
        assertThat(pending.get("client_phone").isNull()).isTrue();
        long linkId = pending.get("id").asLong();
        assertThat(post("coaching/" + linkId + "/accept", null, leila).status()).isEqualTo(403);
        assertThat(post("coaching/" + linkId + "/accept", null, sami).status()).isEqualTo(200);
        assertThat(get("measures?member_id=" + id("amira"), sami).status()).isEqualTo(200);
        JsonNode notes = get("notifications", amira).body();
        assertThat(texts(notes.get("items"), "title")).contains("Demande de coaching acceptée");
        assertThat(notes.get("unread").asLong()).isGreaterThanOrEqualTo(1);
        assertThat(post("coaching/" + linkId + "/end", null, amira).status()).isEqualTo(200);
        assertThat(get("measures?member_id=" + id("amira"), sami).status()).isEqualTo(403);
    }

    @Test
    @Order(4)
    void unMembreNePeutPasSeChoisirLuiMemeNiUnNonCoach() throws Exception {
        assertThat(post("coaching/request", Map.of("coach_id", id("leila")), leila).status()).isEqualTo(400);
        assertThat(post("coaching/request", Map.of("coach_id", id("youssef")), amira).status()).isEqualTo(404);
        assertThat(post("coaching/request", Map.of("coach_id", id("leila")), youssef).status()).isEqualTo(200);
        assertThat(post("coaching/request", Map.of("coach_id", id("leila")), youssef).status()).isEqualTo(409);
    }

    @Test
    @Order(5)
    void ladminAttribueUnCoachDirectement() throws Exception {
        assertThat(post("coaching/assign", Map.of("coach_id", id("leila"), "client_id", id("amira")), admin).status()).isEqualTo(200);
        assertThat(longs(get("members", leila).body(), "id")).contains(id("amira"));
        assertThat(get("coaching?status=active", admin).body().size()).isGreaterThanOrEqualTo(3);
    }

    @Test
    @Order(6)
    void retrograderUnCoachClotSesSuivisEtPrevientSesClients() throws Exception {
        JsonNode u = get("members?q=sami", admin).body().get(0);
        var body = json.convertValue(u, java.util.Map.class);
        body.put("role", "athlete");
        assertThat(call("PUT", "members/" + id("sami"), body, admin).status()).isEqualTo(200);
        assertThat(get("members", login("sami")).status()).isEqualTo(403);
        assertThat(texts(get("notifications", youssef).body().get("items"), "title")).contains("Suivi coaching terminé");
        for (JsonNode l : get("coaching/mine", youssef).body()) {
            if (l.get("coach_id").asLong() == id("sami")) assertThat(l.get("status").asText()).isEqualTo("ended");
        }
    }
}
