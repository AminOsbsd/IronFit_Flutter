package com.ironfit;

import static org.assertj.core.api.Assertions.assertThat;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.ironfit.repository.UserRepository;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.HttpMethod;
import org.springframework.http.MediaType;
import org.springframework.test.annotation.DirtiesContext;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders;

/**
 * Base des tests d'intégration : contexte Spring complet + MockMvc, base H2 neuve (données de démo) par classe de test.
 * Les appels passent par toute la chaîne (filtre JWT, sécurité, validation, services, JPA).
 */
@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
@DirtiesContext(classMode = DirtiesContext.ClassMode.AFTER_CLASS)
public abstract class ApiTestSupport {
    @Autowired protected MockMvc mvc;
    @Autowired protected ObjectMapper json;
    @Autowired protected UserRepository users;

    /** Réponse : code HTTP + corps JSON. */
    public record Res(int status, JsonNode body) {
        public String error() { return body.path("error").asText(); }
    }

    protected Res call(String method, String path, Object body, String token) throws Exception {
        MockHttpServletRequestBuilder req = MockMvcRequestBuilders.request(HttpMethod.valueOf(method), "/api/" + path)
                .contentType(MediaType.APPLICATION_JSON);
        if (token != null) req.header("Authorization", "Bearer " + token);
        if (body != null) req.content(body instanceof String s ? s : json.writeValueAsString(body));
        MvcResult r = mvc.perform(req).andReturn();
        String text = r.getResponse().getContentAsString(StandardCharsets.UTF_8);
        return new Res(r.getResponse().getStatus(), text.isEmpty() ? json.createObjectNode() : json.readTree(text));
    }

    protected Res get(String path, String token) throws Exception { return call("GET", path, null, token); }

    protected Res post(String path, Object body, String token) throws Exception { return call("POST", path, body, token); }

    protected String login(String login, String password) throws Exception {
        Res r = post("login", java.util.Map.of("login", login, "password", password), null);
        assertThat(r.status()).as("connexion %s : %s", login, r.body()).isEqualTo(200);
        return r.body().get("token").asText();
    }

    protected String login(String login) throws Exception { return login(login, "admin".equals(login) ? "admin123" : "1234"); }

    protected Long id(String login) { return users.findByLoginOrEmail(login).orElseThrow().getId(); }

    protected static List<String> texts(JsonNode array, String field) {
        List<String> out = new ArrayList<>();
        array.forEach(n -> out.add(n.path(field).asText()));
        return out;
    }

    protected static List<Long> longs(JsonNode array, String field) {
        List<Long> out = new ArrayList<>();
        array.forEach(n -> out.add(n.path(field).asLong()));
        return out;
    }
}
