package com.ironfit.service;

import com.ironfit.dto.NotificationDtos.NotificationPage;
import com.ironfit.security.CurrentUser;

/** Notifications personnelles (abonnement, coaching, programmes, commentaires, annonces, cours annulés). */
public interface NotificationService {
    NotificationPage page(CurrentUser me, Integer limit, Integer offset);

    void markRead(CurrentUser me, Long id);

    void markAllRead(CurrentUser me);

    /** Notification dans l'application + copie par e-mail (en arrière-plan). */
    void notify(Long userId, String title, String body);

    /** Idem, avec choix de la copie par e-mail (false : l'appelant envoie lui-même l'e-mail). */
    void notify(Long userId, String title, String body, boolean emailCopy);

    /** Tous les membres actifs (athlètes et coachs), sauf l'auteur. */
    void notifyAllMembers(Long excludedUserId, String title, String body);
}
