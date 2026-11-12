package com.ironfit.retention;

import static org.assertj.core.api.Assertions.assertThat;

import com.ironfit.retention.ChurnScorer.Input;
import com.ironfit.retention.ChurnScorer.Result;
import java.time.LocalDate;
import org.junit.jupiter.api.Test;

/** Tests unitaires du score de risque : classe pure, sans Spring ni base de données. */
class ChurnScorerTest {
    static final LocalDate TODAY = LocalDate.of(2026, 10, 27);

    static Input input(Integer daysSinceLast, int sessions28, Integer subEndInDays, int accountAgeDays) {
        return new Input(TODAY,
                daysSinceLast == null ? null : TODAY.minusDays(daysSinceLast),
                sessions28,
                subEndInDays == null ? null : TODAY.plusDays(subEndInDays),
                TODAY.minusDays(accountAgeDays));
    }

    @Test
    void membreAssiduAScoreNulEtRisqueFaible() {
        Result r = ChurnScorer.score(input(1, 12, 60, 200));
        assertThat(r.score()).isZero();
        assertThat(r.level()).isEqualTo("low");
        assertThat(r.reasons()).isEmpty();
        assertThat(r.daysInactive()).isEqualTo(1);
    }

    @Test
    void inactiviteDe20JoursEtAbonnementProcheDonnentUnRisqueEleve() {
        Result r = ChurnScorer.score(input(20, 2, 3, 60));   // 47 (inactivité) + 15 (régularité) + 20 (abonnement)
        assertThat(r.score()).isEqualTo(82);
        assertThat(r.level()).isEqualTo("high");
        assertThat(r.reasons()).hasSize(3);
        assertThat(r.reasons().get(0)).contains("20 jours");
    }

    @Test
    void risqueMoyen() {
        Result r = ChurnScorer.score(input(11, 5, 12, 90));  // 22 + 5 + 10
        assertThat(r.score()).isEqualTo(37);
        assertThat(r.level()).isEqualTo("medium");
    }

    @Test
    void troisJoursSansSeanceNeSontPasPenalises() {
        assertThat(ChurnScorer.score(input(3, 8, null, 90)).score()).isZero();
        assertThat(ChurnScorer.score(input(4, 8, null, 90)).score()).isEqualTo(3);
    }

    @Test
    void jamaisVenuDepuisLInscriptionEstDetecte() {
        Result r = ChurnScorer.score(input(null, 0, 10, 40));  // 40 jours d'ancienneté sans aucune séance
        assertThat(r.score()).isEqualTo(85);
        assertThat(r.level()).isEqualTo("high");
        assertThat(r.daysInactive()).isNull();
        assertThat(r.reasons().get(0)).contains("depuis l'inscription");
    }

    @Test
    void nouveauMembreBeneficieDUnePeriodeDAdaptation() {
        Result r = ChurnScorer.score(input(null, 0, 30, 2));
        assertThat(r.score()).isZero();
        // 10 jours d'ancienneté, 10 jours sans venir : seule l'inactivité compte, pas la régularité
        assertThat(ChurnScorer.score(input(10, 0, 30, 10)).score()).isEqualTo(19);
    }

    @Test
    void lAbonnementExpireAjouteDesPointsEtLeScoreEstPlafonneA100() {
        Result r = ChurnScorer.score(input(30, 0, -5, 300));
        assertThat(r.score()).isEqualTo(100);
        assertThat(r.reasons()).anyMatch(s -> s.contains("expiré depuis 5 jours"));
        assertThat(ChurnScorer.score(input(1, 10, -1, 90)).score()).isEqualTo(25);
        assertThat(ChurnScorer.score(input(1, 10, 1, 90)).score()).isEqualTo(20);
    }

    @Test
    void seuilsDesNiveaux() {
        assertThat(ChurnScorer.level(34)).isEqualTo("low");
        assertThat(ChurnScorer.level(35)).isEqualTo("medium");
        assertThat(ChurnScorer.level(59)).isEqualTo("medium");
        assertThat(ChurnScorer.level(60)).isEqualTo("high");
    }

    @Test
    void donneesIncompletesNeFontPasPlanter() {
        Result r = ChurnScorer.score(new Input(TODAY, null, 0, null, null));
        assertThat(r.score()).isEqualTo(25);
        assertThat(r.daysInactive()).isNull();
    }
}
