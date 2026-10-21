package com.ironfit.dto;

import com.ironfit.entity.Checkin;
import com.ironfit.entity.Measure;
import com.ironfit.entity.Payment;
import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.PositiveOrZero;
import jakarta.validation.constraints.Size;
import java.math.BigDecimal;
import java.time.LocalDate;

/** Données rattachées à un membre : paiements, mesures, présences. */
public final class RecordDtos {
    private RecordDtos() {}

    public record PaymentDto(Long id, Long memberId, BigDecimal amount, String method, LocalDate paidOn, String note, String memberName) {
        public static PaymentDto of(Payment p) {
            return new PaymentDto(p.getId(), p.getMember().getId(), p.getAmount(), p.getMethod(), p.getPaidOn(), p.getNote(), p.getMember().getName());
        }
    }

    public record PaymentRequest(
            @NotNull(message = "Champ obligatoire : Membre") Long memberId,
            @NotNull(message = "Champ obligatoire : Montant") @PositiveOrZero(message = "Valeur invalide : Montant") BigDecimal amount,
            @Size(max = 30, message = "Mode de paiement invalide") String method,
            LocalDate paidOn,
            @Size(max = 500, message = "Note trop longue") String note) {}

    public record MeasureDto(Long id, Long memberId, LocalDate measuredOn, Double weight, Double bodyFat, String note, String memberName) {
        public static MeasureDto of(Measure m) {
            return new MeasureDto(m.getId(), m.getMember().getId(), m.getMeasuredOn(), m.getWeight(), m.getBodyFat(), m.getNote(), m.getMember().getName());
        }
    }

    public record MeasureRequest(
            @NotNull(message = "Champ obligatoire : Membre") Long memberId,
            LocalDate measuredOn,
            @DecimalMin(value = "20", message = "Poids : 20 à 400 kg") @DecimalMax(value = "400", message = "Poids : 20 à 400 kg") Double weight,
            @DecimalMin(value = "0", message = "Valeur invalide : Masse grasse") @DecimalMax(value = "100", message = "Valeur invalide : Masse grasse") Double bodyFat,
            @Size(max = 500, message = "Note trop longue") String note) {}

    public record CheckinDto(Long id, Long memberId, LocalDate checkinOn, String note, String memberName) {
        public static CheckinDto of(Checkin c) {
            return new CheckinDto(c.getId(), c.getMember().getId(), c.getCheckinOn(), c.getNote(), c.getMember().getName());
        }
    }

    public record CheckinRequest(
            @NotNull(message = "Champ obligatoire : Membre") Long memberId,
            LocalDate checkinOn,
            @Size(max = 500, message = "Note trop longue") String note) {}
}
