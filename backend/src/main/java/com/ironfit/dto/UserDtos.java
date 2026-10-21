package com.ironfit.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import com.ironfit.entity.Role;
import com.ironfit.entity.User;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import java.time.Instant;
import java.time.LocalDate;

/** Comptes, authentification, profil et gestion des membres. */
public final class UserDtos {
    private UserDtos() {}

    static final String LOGIN_RULE = "^[A-Za-z0-9_.-]{3,20}$";
    static final String LOGIN_MSG = "Identifiant : 3 à 20 caractères (lettres, chiffres, . _ -)";

    /** Données publiques d'un compte (jamais le hachage ni la version de jeton). */
    public record UserDto(Long id, String name, String login, String email, String phone, Role role, Long planId,
                          LocalDate subEnd, String specialty, boolean active, Instant created, String planName) {
        public static UserDto of(User u) { return of(u, null); }

        public static UserDto of(User u, String planName) {
            return new UserDto(u.getId(), u.getName(), u.getLogin(), u.getEmail(), u.getPhone(), u.getRole(), u.planId(),
                    u.getSubEnd(), u.getSpecialty(), u.isActive(), u.getCreated(), planName);
        }
    }

    public record SignupRequest(
            @NotBlank(message = "Nom invalide") @Size(min = 2, max = 80, message = "Nom invalide") String name,
            @NotBlank(message = LOGIN_MSG) @Pattern(regexp = LOGIN_RULE, message = LOGIN_MSG) String login,
            @NotBlank(message = "E-mail invalide") @Email(message = "E-mail invalide") @Size(max = 120, message = "E-mail invalide") String email,
            @NotBlank(message = "Mot de passe : 6 caractères minimum") @Size(min = 6, max = 200, message = "Mot de passe : 6 caractères minimum") String password) {}

    public record LoginRequest(String login, String password) {}

    public record AuthResponse(String token, UserDto user) {}

    public record ForgotRequest(String email) {}

    /** {@code devCode} n'est renseigné qu'en mode démonstration (SHOW_RESET_CODE=true). */
    public record ForgotResponse(boolean ok, String devCode) {}

    public record ResetRequest(String email, String code, String password) {}

    public record ProfileRequest(
            @NotBlank(message = "Nom invalide") @Size(min = 2, max = 80, message = "Nom invalide") String name,
            @NotBlank(message = "E-mail invalide") @Email(message = "E-mail invalide") @Size(max = 120, message = "E-mail invalide") String email,
            @Size(max = 30, message = "Téléphone invalide") String phone,
            @Size(max = 80, message = "Spécialité trop longue") String specialty) {}

    public record PasswordChangeRequest(String old, @JsonProperty("new") String newPassword) {}

    public record TokenResponse(boolean ok, String token) {}

    /** Création / modification d'un membre ou d'un coach par l'admin. */
    public record MemberRequest(
            @NotBlank(message = "Nom invalide") @Size(min = 2, max = 80, message = "Nom invalide") String name,
            @NotBlank(message = LOGIN_MSG) @Pattern(regexp = LOGIN_RULE, message = LOGIN_MSG) String login,
            @NotBlank(message = "E-mail invalide") @Email(message = "E-mail invalide") @Size(max = 120, message = "E-mail invalide") String email,
            @Size(min = 6, max = 200, message = "Mot de passe : 6 caractères minimum") String password,
            @Size(max = 30, message = "Téléphone invalide") String phone,
            Long planId,
            LocalDate subEnd,
            @Size(max = 80, message = "Spécialité trop longue") String specialty,
            @Pattern(regexp = "^(athlete|coach)?$", message = "Rôle invalide") String role) {}

    public record StatusRequest(Boolean active) {}

    public record StatusResponse(boolean ok, boolean active) {}

    public record RenewRequest(Long planId, String method) {}

    /** Annuaire des coachs : aucune donnée de contact. */
    public record CoachSummaryDto(Long id, String name, String specialty, long classes, long clients) {}
}
