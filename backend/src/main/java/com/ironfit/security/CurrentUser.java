package com.ironfit.security;

import com.ironfit.entity.Role;
import com.ironfit.entity.User;

/** Utilisateur authentifié de la requête courante (principal Spring Security). */
public record CurrentUser(Long id, Role role, String name) {
    public static CurrentUser of(User u) { return new CurrentUser(u.getId(), u.getRole(), u.getName()); }

    public boolean isAdmin() { return role == Role.ADMIN; }
    public boolean isCoach() { return role == Role.COACH; }
    /** Un coach est aussi membre. */
    public boolean isMember() { return role.isMember(); }
}
