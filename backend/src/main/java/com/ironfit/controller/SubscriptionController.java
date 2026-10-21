package com.ironfit.controller;

import com.ironfit.dto.CommonDtos.IdResponse;
import com.ironfit.dto.CommonDtos.OkResponse;
import com.ironfit.dto.SubscriptionDtos.ActionRequest;
import com.ironfit.dto.SubscriptionDtos.CreateRequest;
import com.ironfit.dto.SubscriptionDtos.RequestDto;
import com.ironfit.security.CurrentUser;
import com.ironfit.service.SubscriptionService;
import java.util.List;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

/** Demandes d'abonnement : le membre demande, l'admin valide (paiement reçu) ou refuse. */
@RestController
@RequestMapping("/api/requests")
public class SubscriptionController {
    private final SubscriptionService subscriptions;

    public SubscriptionController(SubscriptionService subscriptions) { this.subscriptions = subscriptions; }

    /** Membre : ses demandes ; admin : demandes en attente. */
    @GetMapping
    public List<RequestDto> list(@AuthenticationPrincipal CurrentUser me) { return subscriptions.list(me); }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public IdResponse create(@AuthenticationPrincipal CurrentUser me, @RequestBody CreateRequest body) { return subscriptions.create(me, body.planId()); }

    @PostMapping("/{id}/{action:approve|reject|cancel}")
    public OkResponse act(@AuthenticationPrincipal CurrentUser me, @PathVariable Long id, @PathVariable String action,
                          @RequestBody(required = false) ActionRequest body) {
        subscriptions.act(me, id, action, body == null ? null : body.method());
        return OkResponse.OK;
    }
}
