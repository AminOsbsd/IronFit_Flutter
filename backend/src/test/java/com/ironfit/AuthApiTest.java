package com.ironfit;

import static org.assertj.core.api.Assertions.assertThat;

import com.ironfit.entity.Role;
import com.ironfit.entity.User;
import java.util.Base64;
import java.util.Map;
import org.junit.jupiter.api.Test;

/** Authentification, sessions, révocation des jetons, comptes désactivés, erreurs HTTP. */
class AuthApiTest extends ApiTestSupport {

    @Test
    void connexionValideEtInvalide() throws Exception {
        assertThat(post("login", Map.of("login", "admin", "password", "admin123"), null).status()).isEqualTo(200);
        assertThat(post("login", Map.of("login", "ADMIN@ironfit.local", "password", "admin123"), null).status()).isEqualTo(200);
        Res bad = post("login", Map.of("login", "admin", "password", "nope"), null);
        assertThat(bad.status()).isEqualTo(401);
        assertThat(bad.error()).isEqualTo("Identifiant ou mot de passe incorrect");
        assertThat(post("login", Map.of("login", "inconnu", "password", "x"), null).status()).isEqualTo(401);
    }

    @Test
    void routesProtegeesExigentUnJetonValideEtNonFalsifie() throws Exception {
        assertThat(get("me", null).status()).isEqualTo(401);
        String tok = login("youssef");
        assertThat(get("me", tok).body().get("login").asText()).isEqualTo("youssef");
        assertThat(get("me", tok).body().has("password_hash")).isFalse();
        // charge utile modifiée (sujet = admin) avec l'ancienne signature
        String[] parts = tok.split("\\.");
        String forgedPayload = Base64.getUrlEncoder().withoutPadding().encodeToString(("{\"sub\":\"" + id("admin") + "\",\"tv\":0,\"exp\":9999999999}").getBytes());
        assertThat(get("me", parts[0] + "." + forgedPayload + "." + parts[2]).status()).isEqualTo(401);
        assertThat(get("me", "nimporte.quoi.ici").status()).isEqualTo(401);
    }

    @Test
    void inscriptionValideLesChampsEtImposeLeRoleMembre() throws Exception {
        assertThat(post("signup", Map.of("name", "A", "login", "ab", "email", "x", "password", "1"), null).status()).isEqualTo(400);
        Res r = post("signup", Map.of("name", "Nouveau Membre", "login", "nouveau", "email", "nouveau@test.tn", "password", "secret1", "role", "admin"), null);
        assertThat(r.status()).isEqualTo(201);
        assertThat(r.body().at("/user/role").asText()).isEqualTo("athlete");
        assertThat(post("signup", Map.of("name", "Doublon", "login", "NOUVEAU", "email", "autre@test.tn", "password", "secret1"), null).status()).isEqualTo(409);
    }

    @Test
    void changerDeMotDePasseRevoqueLesAnciensJetons() throws Exception {
        String old = login("amira");
        Res r = post("password", Map.of("old", "1234", "new", "nouveau1"), old);
        assertThat(r.status()).isEqualTo(200);
        assertThat(get("me", old).status()).isEqualTo(401);
        assertThat(get("me", r.body().get("token").asText()).status()).isEqualTo(200);
        assertThat(post("login", Map.of("login", "amira", "password", "nouveau1"), null).status()).isEqualTo(200);
        assertThat(post("password", Map.of("old", "faux", "new", "abcdef"), r.body().get("token").asText()).error()).isEqualTo("Ancien mot de passe incorrect");
    }

    @Test
    void motDePasseOublieCodeEssaisLimitesReinitialisation() throws Exception {
        Res f = post("forgot", Map.of("email", "leila@ironfit.local"), null);
        String code = f.body().get("dev_code").asText();
        assertThat(code).matches("\\d{6}");
        assertThat(post("reset", Map.of("email", "leila@ironfit.local", "code", "000000", "password", "abcdef"), null).status()).isEqualTo(400);
        assertThat(post("reset", Map.of("email", "leila@ironfit.local", "code", code, "password", "abcdef"), null).status()).isEqualTo(200);
        assertThat(post("login", Map.of("login", "leila", "password", "abcdef"), null).status()).isEqualTo(200);
        // e-mail inconnu : même réponse, sans code
        Res unknown = post("forgot", Map.of("email", "personne@test.tn"), null);
        assertThat(unknown.body().get("ok").asBoolean()).isTrue();
        assertThat(unknown.body().get("dev_code").isNull()).isTrue();
    }

    @Test
    void desactivationCoupeLesSessionsEtRefuseLaConnexion() throws Exception {
        String admin = login("admin"), y = login("youssef");
        assertThat(post("members/" + id("youssef") + "/status", Map.of("active", false), admin).status()).isEqualTo(200);
        Res me = get("me", y);
        assertThat(me.status()).isEqualTo(401);
        assertThat(post("login", Map.of("login", "youssef", "password", "1234"), null).status()).isEqualTo(403);
        post("members/" + id("youssef") + "/status", Map.of("active", true), admin);
        assertThat(post("login", Map.of("login", "youssef", "password", "1234"), null).status()).isEqualTo(200);
    }

    @Test
    void erreursHttp404_405EtJsonInvalide() throws Exception {
        String tok = login("youssef");
        assertThat(get("nimporte", tok).status()).isEqualTo(404);
        assertThat(call("PUT", "me", Map.of(), tok).status()).isEqualTo(405);
        assertThat(post("login", "{oops", null).status()).isEqualTo(400);
    }

    /** Comptes importés de l'ancienne base SQLite : hachage scrypt de l'API Node.js, converti en bcrypt à la connexion. */
    @Test
    void compteImporteAvecHachageScryptPeutSeConnecter() throws Exception {
        User u = new User();
        u.setName("Ancien Membre");
        u.setLogin("ancien");
        u.setEmail("ancien@test.tn");
        u.setRole(Role.ATHLETE);
        u.setPasswordHash("00112233445566778899aabbccddeeff:a9d90a5b903041d430f3120a37e7dcb3bdc71c05ec54f79c2088ad704db11ba5f4a7439b074e74bcde4645244266dd11c8aec76fb8d0ee315803a1e465367226");
        users.save(u);
        assertThat(post("login", Map.of("login", "ancien", "password", "faux"), null).status()).isEqualTo(401);
        assertThat(post("login", Map.of("login", "ancien", "password", "1234"), null).status()).isEqualTo(200);
        assertThat(users.findByLoginOrEmail("ancien").orElseThrow().getPasswordHash()).startsWith("$2");
        assertThat(post("login", Map.of("login", "ancien", "password", "1234"), null).status()).isEqualTo(200);
    }
}
