package com.ironfit.ai;

import static org.assertj.core.api.Assertions.assertThat;

import com.ironfit.config.AiCoachProperties;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.attribute.FileTime;
import java.time.Instant;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

class KnowledgeBaseTest {
    private static KnowledgeBase kb(Path file) {
        return new KnowledgeBase(new AiCoachProperties("k", null, null, null, null, null, null, 0, 0, 0, 0, file == null ? null : file.toString()));
    }

    @Test
    void lesInformationsACompleterDeviennentInconnuesEtLesCommentairesSontRetires() {
        String cleaned = KnowledgeBase.clean("<!-- consignes\nsur deux lignes -->\n# Salle\r\n- Horaires : 7 h – 21 h\n- Adresse : À COMPLÉTER (ex. rue…)\n- Tél : à compléter\n\n\n\n# Règles");
        assertThat(cleaned).isEqualTo("# Salle\n- Horaires : 7 h – 21 h\n- Adresse : " + KnowledgeBase.UNKNOWN + "\n- Tél : " + KnowledgeBase.UNKNOWN + "\n\n# Règles");
        assertThat(cleaned).doesNotContain("COMPLÉTER", "ex. rue", "consignes");
    }

    @Test
    void laTailleEstLimitee() {
        assertThat(KnowledgeBase.clean("x".repeat(KnowledgeBase.MAX_CHARS + 500))).hasSize(KnowledgeBase.MAX_CHARS + 4).endsWith("[…]");
    }

    @Test
    void leFichierEstReluQuandIlChangeEtUnFichierAbsentDonneUnTexteVide(@TempDir Path dir) throws Exception {
        Path f = dir.resolve("kb.md");
        KnowledgeBase kb = kb(f);
        assertThat(kb.text()).isEmpty();

        Files.writeString(f, "Horaires : 7 h – 21 h", StandardCharsets.UTF_8);
        assertThat(kb.text()).isEqualTo("Horaires : 7 h – 21 h");

        Files.writeString(f, "Horaires : 6 h – 23 h", StandardCharsets.UTF_8);
        Files.setLastModifiedTime(f, FileTime.from(Instant.now().plusSeconds(5))); // horodatage distinct même sur un disque lent
        assertThat(kb.text()).isEqualTo("Horaires : 6 h – 23 h");

        Files.delete(f);
        assertThat(kb.text()).isEmpty();
        assertThat(kb(null).text()).isEmpty();
    }

    @Test
    void lePromptPlaceLaBaseEtLesDonneesDeLaSalleAvantLesDonneesDeLUtilisateur() {
        String p = CoachPrompt.system(CoachPrompt.Mode.MEMBER, "Youssef", java.time.LocalDate.of(2026, 11, 16),
                "Horaires : 7 h – 21 h", java.util.List.of("Plan \"Mensuel\": 60 DT"), java.util.List.of("Last logged workout: 2026-11-14"));
        assertThat(p).contains("answer ONLY from the GYM KNOWLEDGE BASE", "Never make up prices");
        assertThat(p.indexOf("Horaires : 7 h – 21 h")).isLessThan(p.indexOf("- Plan \"Mensuel\": 60 DT"));
        assertThat(p.indexOf("- Plan \"Mensuel\": 60 DT")).isLessThan(p.indexOf("USER DATA"));
        assertThat(p.indexOf("USER DATA")).isLessThan(p.indexOf("Last logged workout"));
        assertThat(CoachPrompt.system(CoachPrompt.Mode.ADMIN, "A", java.time.LocalDate.of(2026, 1, 1), java.util.List.of()))
                .contains("GYM KNOWLEDGE BASE (written by the gym staff):\n(empty)");
    }
}
