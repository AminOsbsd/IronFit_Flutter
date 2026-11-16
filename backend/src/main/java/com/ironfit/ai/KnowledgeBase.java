package com.ironfit.ai;

import com.ironfit.config.AiCoachProperties;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.attribute.FileTime;
import java.util.stream.Collectors;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

/**
 * Base de connaissances d'AI Coach : fichier texte / Markdown modifiable par la salle (horaires, règles, FAQ, consignes).
 * Relu automatiquement quand il change (pas besoin de redémarrer). Dans une ligne contenant « À COMPLÉTER », la suite est
 * remplacée par {@link #UNKNOWN} : un fait explicitement « inconnu » empêche bien mieux un petit modèle d'inventer
 * (horaires, adresse…) qu'une ligne absente, vérifié avec un modèle gratuit. Taille limitée à {@link #MAX_CHARS}.
 */
@Component
public class KnowledgeBase {
    private static final Logger log = LoggerFactory.getLogger(KnowledgeBase.class);
    /** ≈ 3 000 jetons : assez pour une salle, sans alourdir chaque requête. */
    public static final int MAX_CHARS = 12_000;
    static final String TODO_MARK = "À COMPLÉTER";
    static final String UNKNOWN = "UNKNOWN (not provided by the gym: say you do not know and suggest asking at the front desk)";

    private final Path file;
    private FileTime loadedAt;
    private String text = "";
    private boolean missingLogged;

    public KnowledgeBase(AiCoachProperties props) {
        this.file = props.knowledgeFile() == null || props.knowledgeFile().isBlank() ? null : Path.of(props.knowledgeFile());
    }

    /** Contenu courant (vide si aucun fichier). */
    public synchronized String text() {
        if (file == null) return "";
        try {
            if (!Files.isRegularFile(file)) {
                if (!missingLogged) log.info("Base de connaissances AI Coach absente : {}", file.toAbsolutePath());
                missingLogged = true;
                loadedAt = null;
                text = "";
                return text;
            }
            missingLogged = false;
            FileTime modified = Files.getLastModifiedTime(file);
            if (!modified.equals(loadedAt)) {
                text = clean(Files.readString(file, StandardCharsets.UTF_8));
                loadedAt = modified;
                log.info("Base de connaissances AI Coach chargée : {} caractères ({})", text.length(), file.getFileName());
            }
        } catch (IOException e) {
            log.warn("Base de connaissances AI Coach illisible : {}", e.getClass().getSimpleName());
        }
        return text;
    }

    /** Marque les informations à compléter comme inconnues, retire les commentaires HTML et les lignes vides en trop ; coupe au-delà de MAX_CHARS. */
    static String clean(String raw) {
        String noComments = raw.replace("\r\n", "\n").replaceAll("(?s)<!--.*?-->", "");
        String kept = noComments.lines()
                .map(KnowledgeBase::unknownIfTodo)
                .collect(Collectors.joining("\n"))
                .replaceAll("\n{3,}", "\n\n")
                .trim();
        return kept.length() <= MAX_CHARS ? kept : kept.substring(0, MAX_CHARS) + "\n[…]";
    }

    /** « - Adresse : À COMPLÉTER (ex. …) » → « - Adresse : UNKNOWN (…) » ; les autres lignes sont inchangées. */
    private static String unknownIfTodo(String line) {
        int at = line.toUpperCase().indexOf(TODO_MARK);
        return at < 0 ? line : line.substring(0, at) + UNKNOWN;
    }
}
