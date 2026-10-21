package com.ironfit.controller;

import com.ironfit.dto.CommonDtos.OkResponse;
import com.ironfit.dto.NotificationDtos.NotificationPage;
import com.ironfit.security.CurrentUser;
import com.ironfit.service.NotificationService;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

/** Notifications de l'utilisateur connecté. */
@RestController
@RequestMapping("/api/notifications")
public class NotificationController {
    private final NotificationService notifications;

    public NotificationController(NotificationService notifications) { this.notifications = notifications; }

    @GetMapping
    public NotificationPage list(@AuthenticationPrincipal CurrentUser me, @RequestParam(required = false) Integer limit,
                                 @RequestParam(required = false) Integer offset) {
        return notifications.page(me, limit, offset);
    }

    @PostMapping("/{id}/read")
    public OkResponse read(@AuthenticationPrincipal CurrentUser me, @PathVariable Long id) {
        notifications.markRead(me, id);
        return OkResponse.OK;
    }

    @PostMapping("/read-all")
    public OkResponse readAll(@AuthenticationPrincipal CurrentUser me) {
        notifications.markAllRead(me);
        return OkResponse.OK;
    }
}
