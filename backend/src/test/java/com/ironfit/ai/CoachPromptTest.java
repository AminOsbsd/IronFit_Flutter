package com.ironfit.ai;

import static org.assertj.core.api.Assertions.assertThat;

import com.ironfit.ai.CoachPrompt.Mode;
import com.ironfit.config.AiCoachProperties;
import java.time.LocalDate;
import java.util.List;
import org.junit.jupiter.api.Test;

class CoachPromptTest {
    private static final LocalDate TODAY = LocalDate.of(2026, 11, 16);

    @Test
    void lePromptMembreContientLesDonneesLesReglesEtLaDate() {
        String p = CoachPrompt.system(Mode.MEMBER, "Youssef", TODAY, List.of("Last logged workout: 2026-11-14", "Measurement 2026-11-15: weight 80.6 kg"));
        assertThat(p).contains("AI Coach", "IronFit", "Youssef", "2026-11-16")
                .contains("- Last logged workout: 2026-11-14", "- Measurement 2026-11-15: weight 80.6 kg")
                .contains("gym member about their own training")
                .contains("not a doctor")           // règle de sécurité
                .contains("default to French")      // langue de l'application
                .doesNotContain("talking with a coach");
    }

    @Test
    void chaqueModeAdapteLeContexteEtSansDonneesLePromptLeDit() {
        assertThat(CoachPrompt.system(Mode.COACH, "Sami", TODAY, List.of())).contains("talking with a coach", "- No data recorded yet.");
        assertThat(CoachPrompt.system(Mode.ADMIN, " ", TODAY, null)).contains("gym administrator", "first name: unknown");
    }

    @Test
    void clipNormaliseLesEspacesEtTronque() {
        assertThat(CoachPrompt.clip("  a\n\n b  ", 10)).isEqualTo("a b");
        assertThat(CoachPrompt.clip("abcdefghij", 5)).isEqualTo("abcd…");
        assertThat(CoachPrompt.clip(null, 5)).isEmpty();
    }

    @Test
    void laCleDExempleOuVideNActivePasLeCoachEtNApparaitJamaisDansToString() {
        assertThat(props("").enabled()).isFalse();
        assertThat(props("sk-or-v1-your-key-here").enabled()).isFalse();
        AiCoachProperties real = props("sk-or-v1-secret");
        assertThat(real.enabled()).isTrue();
        assertThat(real.toString()).doesNotContain("secret");
        assertThat(real.model()).isEqualTo(AiCoachProperties.DEFAULT_MODEL);
    }

    private static AiCoachProperties props(String key) { return new AiCoachProperties(key, null, null, null, null, null, null, 0, 0, 0, 0); }

    @Test
    void raisonnementDesactiveParDefautEtModelesDeSecoursNettoyes() {
        AiCoachProperties p = new AiCoachProperties("k", " a/b:free ", java.util.List.of(" c/d:free", "", "c/d:free"), null, null, null, null, 0, 0, 0, 0);
        assertThat(p.model()).isEqualTo("a/b:free");
        assertThat(p.fallbackModels()).containsExactly("c/d:free");
        assertThat(p.reasoning()).isEqualTo("off");
        assertThat(OpenRouterClient.reasoning("off")).isEqualTo(java.util.Map.of("enabled", false));
        assertThat(OpenRouterClient.reasoning("low")).containsEntry("effort", "low").containsEntry("exclude", true);
        assertThat(OpenRouterClient.reasoning("default")).isNull();
        assertThat(new AiCoachProperties("k", null, null, "bizarre", null, null, null, 0, 0, 0, 0).reasoning()).isEqualTo("off");
    }

    @Test
    void lesErreursOpenRouterDonnentDesMessagesClairsSansJamaisRenvoyer401() {
        assertThat(OpenRouterClient.forStatus(401).getStatus().value()).isEqualTo(502);
        assertThat(OpenRouterClient.forStatus(401).getMessage()).contains("clé OpenRouter");
        assertThat(OpenRouterClient.forStatus(402).getMessage()).contains("crédit");
        assertThat(OpenRouterClient.forStatus(429).getStatus().value()).isEqualTo(429);
        assertThat(OpenRouterClient.forStatus(408).getStatus().value()).isEqualTo(504);
        assertThat(OpenRouterClient.forStatus(503).getStatus().value()).isEqualTo(502);
    }
}
