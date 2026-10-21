package com.ironfit.entity;

import com.fasterxml.jackson.annotation.JsonValue;

/** Rôle d'un compte. Un coach est aussi un membre (abonnement, réservations, programmes personnels). */
public enum Role {
    ADMIN("admin"), COACH("coach"), ATHLETE("athlete");

    private final String value;

    Role(String value) { this.value = value; }

    @JsonValue
    public String value() { return value; }

    public boolean isMember() { return this == COACH || this == ATHLETE; }

    public static Role from(String v) {
        for (Role r : values()) if (r.value.equalsIgnoreCase(v)) return r;
        throw new IllegalArgumentException("Rôle inconnu : " + v);
    }
}
