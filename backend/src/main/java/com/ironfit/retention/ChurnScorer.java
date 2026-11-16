package com.ironfit.retention;

import java.time.LocalDate;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.List;

/**
 * Score de risque d'abandon d'un membre (0 = fidèle, 100 = sur le point de partir).
 * Classe pure : aucune dépendance Spring ni base de données, donc testable seule.
 *
 * <pre>
 *   Inactivité   0 à 50 pts : jours depuis la dernière séance / présence (0 pt jusqu'à 3 jours, 50 pts à 21 jours)
 *   Régularité   0 à 25 pts : nombre de séances + présences sur les 28 derniers jours
 *   Abonnement   0 à 25 pts : expiré ou proche de la fin
 * </pre>
 */
public final class ChurnScorer {
    public static final int HIGH = 60;
    public static final int MEDIUM = 35;
    /** Un compte plus récent que cela n'est pas jugé sur sa régularité (période d'adaptation). */
    public static final int GRACE_DAYS = 14;

    private ChurnScorer() {}

    /**
     * @param lastActivity dernière séance ou présence (null si jamais)
     * @param recentSessions séances + présences sur les 28 derniers jours
     * @param subEnd fin d'abonnement (null = jamais abonné)
     * @param createdOn date de création du compte (null = inconnue, traitée comme ancienne)
     */
    public record Input(LocalDate today, LocalDate lastActivity, int recentSessions, LocalDate subEnd, LocalDate createdOn) {}

    public record Result(int score, String level, List<String> reasons, Integer daysInactive) {}

    public static Result score(Input in) {
        List<String> reasons = new ArrayList<>();
        int points = 0;

        // 1. Inactivité
        LocalDate ref = in.lastActivity() != null ? in.lastActivity() : in.createdOn();
        Integer daysInactive = null;
        if (ref != null) {
            int days = (int) Math.max(0, ChronoUnit.DAYS.between(ref, in.today()));
            if (in.lastActivity() != null) daysInactive = days;
            if (days > 3) {
                points += (int) Math.min(50, Math.round((days - 3) * 50 / 18.0));
                reasons.add(in.lastActivity() != null
                        ? "Dernière activité il y a " + days + " jours"
                        : "Aucune séance depuis l'inscription (" + days + " jours)");
            }
        }

        // 2. Régularité (non évaluée pendant la période d'adaptation)
        boolean newcomer = in.createdOn() != null && ChronoUnit.DAYS.between(in.createdOn(), in.today()) < GRACE_DAYS;
        if (!newcomer) {
            int n = in.recentSessions();
            if (n == 0) {
                points += 25;
                reasons.add("Aucune séance sur les 28 derniers jours");
            } else if (n <= 3) {
                points += 15;
                reasons.add("Seulement " + n + " séance" + (n > 1 ? "s" : "") + " sur 28 jours");
            } else if (n <= 7) {
                points += 5;
                reasons.add("Rythme en baisse (" + n + " séances sur 28 jours)");
            }
        }

        // 3. Abonnement
        if (in.subEnd() != null) {
            long left = ChronoUnit.DAYS.between(in.today(), in.subEnd());
            if (left < 0) {
                points += 25;
                reasons.add("Abonnement expiré depuis " + (-left) + " jour" + (left < -1 ? "s" : ""));
            } else if (left <= 7) {
                points += 20;
                reasons.add("Abonnement expire dans " + left + " jour" + (left > 1 ? "s" : ""));
            } else if (left <= 14) {
                points += 10;
                reasons.add("Abonnement expire dans " + left + " jours");
            }
        }

        int score = Math.min(100, points);
        return new Result(score, level(score), List.copyOf(reasons), daysInactive);
    }

    public static String level(int score) {
        return score >= HIGH ? "high" : score >= MEDIUM ? "medium" : "low";
    }
}
