package com.ironfit.dto;

import com.ironfit.entity.Notification;
import java.time.Instant;
import java.util.List;

/** Notifications personnelles. */
public final class NotificationDtos {
    private NotificationDtos() {}

    public record NotificationDto(Long id, Long userId, String title, String body, boolean seen, Instant created) {
        public static NotificationDto of(Notification n) {
            return new NotificationDto(n.getId(), n.getUser().getId(), n.getTitle(), n.getBody(), n.isSeen(), n.getCreated());
        }
    }

    public record NotificationPage(long unread, List<NotificationDto> items) {}
}
