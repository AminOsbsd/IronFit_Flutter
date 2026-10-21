package com.ironfit.service.impl;

import com.ironfit.entity.Program;
import com.ironfit.security.CurrentUser;
import com.ironfit.service.AccessService;
import org.springframework.stereotype.Component;

/** Droits sur un programme, partagés par les services programmes et séances. */
@Component
class ProgramAccess {
    private final AccessService access;

    ProgramAccess(AccessService access) { this.access = access; }

    /** Coach auteur du programme, avec une relation toujours active envers le client. */
    boolean isAuthor(CurrentUser me, Program p) {
        return p.coachId() != null && p.coachId().equals(me.id()) && me.isCoach() && access.coaches(me.id(), p.getClient().getId());
    }

    boolean canRead(CurrentUser me, Program p) {
        return me.isAdmin() || p.getClient().getId().equals(me.id()) || isAuthor(me, p);
    }

    boolean canEdit(CurrentUser me, Program p) {
        return p.getCoach() == null ? p.getClient().getId().equals(me.id()) : isAuthor(me, p);
    }
}
