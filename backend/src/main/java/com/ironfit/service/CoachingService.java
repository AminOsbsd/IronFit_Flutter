package com.ironfit.service;

import com.ironfit.dto.CoachingDtos.CoachingLinkDto;
import com.ironfit.entity.User;
import com.ironfit.security.CurrentUser;
import java.util.List;

/** Relations coach ↔ client : demande, acceptation, attribution par l'admin, fin du suivi. */
public interface CoachingService {
    List<CoachingLinkDto> mine(CurrentUser me);

    List<CoachingLinkDto> clients(CurrentUser me);

    List<CoachingLinkDto> all(String status);

    void request(CurrentUser me, Long coachId);

    void assign(Long coachId, Long clientId);

    void act(CurrentUser me, Long linkId, String action);

    /** Clôt toutes les relations d'un coach (rétrogradé ou supprimé) et prévient ses clients actifs. */
    void endAllFor(User coach, String reason);
}
