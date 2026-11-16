package com.ironfit.service;

import com.ironfit.ai.OpenRouterClient.Message;
import com.ironfit.dto.AiCoachDtos.ChatRequest;
import com.ironfit.security.CurrentUser;
import java.util.List;

/** AI Coach : prépare la conversation (prompt système + données IronFit de l'utilisateur) envoyée au modèle. */
public interface AiCoachService {
    /**
     * Messages à envoyer à OpenRouter : prompt système construit à partir des données de l'utilisateur connecté,
     * puis l'historique validé. Seules les données de l'utilisateur lui-même sont incluses (agrégats pour coach / admin).
     */
    List<Message> prepare(CurrentUser me, ChatRequest request);
}
