package com.ironfit.dto;

import com.ironfit.entity.Exercise;
import com.ironfit.entity.Workout;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;

/** Programmes, exercices et séances réalisées. */
public final class ProgramDtos {
    private ProgramDtos() {}

    public record ProgramDto(Long id, Long clientId, Long coachId, String title, String goal, String notes, boolean active, Instant created,
                             String coachName, String clientName, long exercises, long sessions, LocalDate lastDone) {}

    public record ProgramDetailDto(Long id, Long clientId, Long coachId, String title, String goal, String notes, boolean active, Instant created,
                                   String coachName, String clientName, long exercises, long sessions, LocalDate lastDone,
                                   boolean canEdit, boolean canLog, boolean canComment, List<ExerciseDto> items, List<WorkoutDto> workouts) {}

    /** {@code clientId} absent (ou égal à soi) = programme personnel ; sinon programme écrit par le coach pour ce client. */
    public record ProgramRequest(
            @NotBlank(message = "Champ obligatoire : Titre") @Size(max = 160, message = "Titre trop long") String title,
            @Size(max = 160, message = "Objectif trop long") String goal,
            @Size(max = 2000, message = "Consignes trop longues") String notes,
            Long clientId,
            Boolean active) {}

    public record ExerciseDto(Long id, Long programId, String day, String name, Integer sets, String reps, String load, String rest, String notes, int position) {
        public static ExerciseDto of(Exercise e) {
            return new ExerciseDto(e.getId(), e.getProgram().getId(), e.getDay(), e.getName(), e.getSets(), e.getReps(), e.getLoad(), e.getRest(), e.getNotes(), e.getPosition());
        }
    }

    public record ExerciseRequest(
            @Size(max = 40, message = "Jour trop long") String day,
            @NotBlank(message = "Champ obligatoire : Exercice") @Size(max = 120, message = "Nom d'exercice trop long") String name,
            @Min(value = 0, message = "Valeur invalide : Séries") @Max(value = 50, message = "Valeur invalide : Séries") Integer sets,
            @Size(max = 40, message = "Répétitions : 40 caractères max.") String reps,
            @Size(max = 40, message = "Charge : 40 caractères max.") String load,
            @Size(max = 40, message = "Repos : 40 caractères max.") String rest,
            @Size(max = 500, message = "Notes trop longues") String notes,
            @Min(value = 0, message = "Valeur invalide : Ordre") Integer position) {}

    public record WorkoutDto(Long id, Long userId, Long programId, LocalDate doneOn, Integer duration, Integer rpe, String notes, String coachComment,
                             Instant created, String programTitle, Long coachId) {
        public static WorkoutDto of(Workout w) {
            var p = w.getProgram();
            return new WorkoutDto(w.getId(), w.getUser().getId(), p == null ? null : p.getId(), w.getDoneOn(), w.getDuration(), w.getRpe(), w.getNotes(),
                    w.getCoachComment(), w.getCreated(), p == null ? null : p.getTitle(), p == null ? null : p.coachId());
        }
    }

    public record WorkoutRequest(
            Long programId,
            LocalDate doneOn,
            @Min(value = 1, message = "Durée : 1 à 600 minutes") @Max(value = 600, message = "Durée : 1 à 600 minutes") Integer duration,
            @Min(value = 1, message = "Difficulté : 1 à 10") @Max(value = 10, message = "Difficulté : 1 à 10") Integer rpe,
            @Size(max = 1000, message = "Notes trop longues") String notes) {}

    public record FeedbackRequest(String comment) {}
}
