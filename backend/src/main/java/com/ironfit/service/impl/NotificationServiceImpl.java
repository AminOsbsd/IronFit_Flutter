package com.ironfit.service.impl;

import com.ironfit.dto.NotificationDtos.NotificationDto;
import com.ironfit.dto.NotificationDtos.NotificationPage;
import com.ironfit.entity.Notification;
import com.ironfit.entity.User;
import com.ironfit.repository.NotificationRepository;
import com.ironfit.repository.OffsetLimit;
import com.ironfit.repository.UserRepository;
import com.ironfit.security.CurrentUser;
import com.ironfit.service.AccessService;
import com.ironfit.service.MailService;
import com.ironfit.service.NotificationService;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@Transactional
public class NotificationServiceImpl implements NotificationService {
    private final NotificationRepository notifications;
    private final UserRepository users;
    private final MailService mail;
    private final boolean emailCopy;

    public NotificationServiceImpl(NotificationRepository notifications, UserRepository users, MailService mail,
                                   @Value("${ironfit.notifications.email:true}") boolean emailCopy) {
        this.notifications = notifications;
        this.users = users;
        this.mail = mail;
        this.emailCopy = emailCopy;
    }

    @Override
    @Transactional(readOnly = true)
    public NotificationPage page(CurrentUser me, Integer limit, Integer offset) {
        var items = notifications.findForUser(me.id(), OffsetLimit.of(offset, limit, 50)).stream().map(NotificationDto::of).toList();
        return new NotificationPage(notifications.countByUserIdAndSeenFalse(me.id()), items);
    }

    @Override
    public void markRead(CurrentUser me, Long id) { notifications.markRead(id, me.id()); }

    @Override
    public void markAllRead(CurrentUser me) { notifications.markAllRead(me.id()); }

    @Override
    public void notify(Long userId, String title, String body) { notify(userId, title, body, true); }

    @Override
    public void notify(Long userId, String title, String body, boolean emailCopy) {
        User u = users.getReferenceById(userId);
        notifications.save(new Notification(u, title, body));
        if (emailCopy) emailCopy(u, title, body);
    }

    @Override
    public void notifyAllMembers(Long excludedUserId, String title, String body) {
        var recipients = users.findByRoleInAndActiveTrueAndIdNot(AccessService.MEMBER_ROLES, excludedUserId);
        notifications.saveAll(recipients.stream().map(u -> new Notification(u, title, body)).toList());
        recipients.forEach(u -> emailCopy(u, title, body));
    }

    /**
     * Chaque notification est aussi envoyée par e-mail (en arrière-plan) à l'adresse du compte.
     * Ignoré si ironfit.notifications.email=false, si l'adresse est vide ou factice (@ironfit.local), ou si le SMTP n'est pas configuré.
     */
    private void emailCopy(User u, String title, String body) {
        String to = u.getEmail();
        if (!emailCopy || !MailService.isRealAddress(to)) return;
        mail.send(to, "IronFit - " + title, body + "\n\n-- \nVous recevez cet e-mail car vous avez un compte IronFit.");
    }
}
