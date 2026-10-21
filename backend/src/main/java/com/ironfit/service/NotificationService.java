package com.ironfit.service;

import com.ironfit.dto.NotificationDtos.NotificationPage;
import com.ironfit.security.CurrentUser;

/** Notifications personnelles (abonnement, coaching, programmes, commentaires, annonces, cours annulés). */
public interface NotificationService {
    NotificationPage page(CurrentUser me, Integer limit, Integer offset);

    void markRead(CurrentUser me, Long id);

    void markAllRead(CurrentUser me);

    void notify(Long userId, String title, String body);

    /** Tous les membres actifs (athlètes et coachs), sauf l'auteur. */
    void notifyAllMembers(Long excludedUserId, String title, String body);
}
