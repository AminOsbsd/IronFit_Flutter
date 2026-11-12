package com.ironfit.dto;

import java.time.LocalDate;
import java.util.List;

/** Membres à risque d'abandon. */
public final class RiskDtos {
    private RiskDtos() {}

    /**
     * @param score          0 à 100 (plus c'est haut, plus le risque est grand)
     * @param level          low, medium ou high
     * @param reasons        explications lisibles du score
     * @param lastActivity   dernière séance ou présence
     * @param daysInactive   jours depuis cette dernière activité (null si aucune)
     * @param recentSessions séances + présences sur 28 jours
     * @param lastReminder   dernière relance envoyée
     */
    public record RiskMemberDto(Long id, String name, String login, int score, String level, List<String> reasons,
                                LocalDate lastActivity, Integer daysInactive, int recentSessions, LocalDate subEnd,
                                LocalDate lastReminder) {}

    public record RunResponse(int alerts) {}

    /**
     * Résultat d'une relance manuelle.
     * @param emailSent true si l'e-mail est parti ; sinon emailInfo donne la raison (SMTP absent, adresse fictive, erreur du serveur…)
     */
    public record RemindResponse(boolean ok, boolean emailSent, String emailInfo) {}
}
