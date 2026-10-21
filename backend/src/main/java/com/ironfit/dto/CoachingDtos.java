package com.ironfit.dto;

import java.time.Instant;
import java.time.LocalDate;

/** Relations coach ↔ client. */
public final class CoachingDtos {
    private CoachingDtos() {}

    /** {@code clientPhone} n'est renseigné que pour une relation active. */
    public record CoachingLinkDto(Long id, Long coachId, Long clientId, String status, Instant created, Instant updated,
                                  String coachName, String coachSpecialty, String clientName, String clientLogin,
                                  String clientPhone, LocalDate clientSubEnd, LocalDate lastWorkout) {}

    public record CoachRequest(Long coachId) {}

    public record AssignRequest(Long coachId, Long clientId) {}
}
