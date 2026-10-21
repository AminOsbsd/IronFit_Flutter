package com.ironfit.service;

import com.ironfit.entity.Role;
import com.ironfit.entity.User;
import com.ironfit.exception.ApiException;
import com.ironfit.repository.CoachClientRepository;
import com.ironfit.repository.UserRepository;
import com.ironfit.security.CurrentUser;
import java.util.EnumSet;
import java.util.List;
import java.util.Set;
import org.springframework.stereotype.Service;

/**
 * Règles d'accès communes. Un coach n'accède aux données personnelles d'un membre
 * que si leur relation de coaching est « active ».
 */
@Service
public class AccessService {
    public static final Set<Role> MEMBER_ROLES = EnumSet.of(Role.ATHLETE, Role.COACH);
    private final CoachClientRepository links;
    private final UserRepository users;

    public AccessService(CoachClientRepository links, UserRepository users) {
        this.links = links;
        this.users = users;
    }

    /** Lève 403 si la condition est fausse. */
    public static void require(boolean allowed) {
        if (!allowed) throw ApiException.forbidden();
    }

    /** Vrai si {@code coachId} suit actuellement {@code clientId}. */
    public boolean coaches(Long coachId, Long clientId) {
        return coachId != null && clientId != null && links.existsByCoachIdAndClientIdAndStatus(coachId, clientId, "active");
    }

    /** Données personnelles d'un membre : lui-même, l'admin, ou son coach actif. */
    public boolean canSeeMember(CurrentUser me, Long memberId) {
        return me.isAdmin() || me.id().equals(memberId) || (me.isCoach() && coaches(me.id(), memberId));
    }

    public boolean coachOf(CurrentUser me, Long memberId) {
        return me.isCoach() && coaches(me.id(), memberId);
    }

    /** Membre (athlète ou coach) existant, sinon 404. */
    public User member(Long id) {
        if (id == null) throw ApiException.notFound("Membre introuvable");
        return users.findByIdAndRoleIn(id, MEMBER_ROLES).orElseThrow(() -> ApiException.notFound("Membre introuvable"));
    }

    public User user(Long id) {
        return users.findById(id).orElseThrow(() -> ApiException.unauthorized("Session expirée, reconnectez-vous"));
    }

    /** Identifiants des clients actifs d'un coach (jamais vide, pour les clauses IN). */
    public List<Long> activeClientIdsOrNone(Long coachId) {
        List<Long> ids = links.activeClientIds(coachId);
        return ids.isEmpty() ? List.of(-1L) : ids;
    }
}
