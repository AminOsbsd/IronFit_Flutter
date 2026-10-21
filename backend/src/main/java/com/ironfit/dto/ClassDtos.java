package com.ironfit.dto;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

/** Cours collectifs, réservations, participants et pointage. */
public final class ClassDtos {
    private ClassDtos() {}

    public record ClassDto(Long id, Integer day, String time, String title, Long coachId, Integer spots,
                           String coachName, String coachSpecialty, long taken, boolean mine) {}

    public record ClassRequest(
            @NotNull(message = "Champ obligatoire : Jour") @Min(value = 0, message = "Valeur invalide : Jour") @Max(value = 6, message = "Valeur invalide : Jour") Integer day,
            @NotBlank(message = "Champ obligatoire : Heure") @Pattern(regexp = "^([01]\\d|2[0-3]):[0-5]\\d$", message = "Valeur invalide : Heure") String time,
            @NotBlank(message = "Champ obligatoire : Activité") @Size(max = 120, message = "Activité trop longue") String title,
            Long coachId,
            @Min(value = 1, message = "Places : 1 à 500") @Max(value = 500, message = "Places : 1 à 500") Integer spots) {}

    public record BookRequest(Long classId) {}

    public record BookResponse(boolean ok, boolean booked) {}

    public record ParticipantDto(Long id, String name, String phone, boolean present) {}

    public record PresentRequest(Long memberId) {}
}
