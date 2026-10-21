package com.ironfit.service.impl;

import com.ironfit.dto.NotificationDtos.NotificationDto;
import com.ironfit.dto.NotificationDtos.NotificationPage;
import com.ironfit.entity.Notification;
import com.ironfit.repository.NotificationRepository;
import com.ironfit.repository.OffsetLimit;
import com.ironfit.repository.UserRepository;
import com.ironfit.security.CurrentUser;
import com.ironfit.service.AccessService;
import com.ironfit.service.NotificationService;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@Transactional
public class NotificationServiceImpl implements NotificationService {
    private final NotificationRepository notifications;
    private final UserRepository users;

    public NotificationServiceImpl(NotificationRepository notifications, UserRepository users) {
        this.notifications = notifications;
        this.users = users;
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
    public void notify(Long userId, String title, String body) {
        notifications.save(new Notification(users.getReferenceById(userId), title, body));
    }

    @Override
    public void notifyAllMembers(Long excludedUserId, String title, String body) {
        var recipients = users.findByRoleInAndActiveTrueAndIdNot(AccessService.MEMBER_ROLES, excludedUserId);
        notifications.saveAll(recipients.stream().map(u -> new Notification(u, title, body)).toList());
    }
}
