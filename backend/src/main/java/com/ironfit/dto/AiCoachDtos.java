package com.ironfit.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import java.util.List;

/** AI Coach : conversation envoyée par l'application (l'historique de la session est gardé côté client). */
public final class AiCoachDtos {
    private AiCoachDtos() {}

    /** Longueur maximale d'un message de l'utilisateur (vérifiée par le service). */
    public static final int MAX_MESSAGE_CHARS = 2000;
    /** Longueur maximale d'un message quelconque de l'historique (les réponses du coach peuvent être plus longues). */
    public static final int MAX_ANY_MESSAGE_CHARS = 8000;
    /** Volume maximal d'historique transmis au modèle : au-delà, les messages les plus anciens sont ignorés. */
    public static final int MAX_HISTORY_CHARS = 16000;
    /** Nombre maximal de messages de l'historique envoyés en une fois. */
    public static final int MAX_HISTORY = 20;

    /**
     * @param messages  historique (du plus ancien au plus récent), le dernier message est celui de l'utilisateur
     * @param workspace « personal » (défaut) ou « coach » : espace affiché pour un coach
     */
    public record ChatRequest(
            @NotEmpty(message = "Message vide")
            @Size(max = MAX_HISTORY, message = "Conversation trop longue : effacez-la pour recommencer")
            List<@Valid ChatMessage> messages,
            @Pattern(regexp = "personal|coach", message = "Valeur invalide : workspace") String workspace) {}

    public record ChatMessage(
            @NotBlank(message = "Valeur invalide : role") @Pattern(regexp = "user|assistant", message = "Valeur invalide : role") String role,
            @NotBlank(message = "Message vide") @Size(max = MAX_ANY_MESSAGE_CHARS, message = "Message trop long") String content) {}
}
