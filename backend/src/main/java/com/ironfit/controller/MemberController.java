package com.ironfit.controller;

import com.ironfit.dto.CommonDtos.IdResponse;
import com.ironfit.dto.CommonDtos.OkResponse;
import com.ironfit.dto.UserDtos.*;
import com.ironfit.security.CurrentUser;
import com.ironfit.service.MemberService;
import com.ironfit.service.SubscriptionService;
import jakarta.validation.Valid;
import java.util.List;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

/** Membres et coachs. Liste : admin (tous) ou coach (ses clients actifs). Gestion des comptes : admin. */
@RestController
@RequestMapping("/api")
public class MemberController {
    private final MemberService members;
    private final SubscriptionService subscriptions;

    public MemberController(MemberService members, SubscriptionService subscriptions) {
        this.members = members;
        this.subscriptions = subscriptions;
    }

    @GetMapping("/members")
    @PreAuthorize("hasAnyRole('ADMIN','COACH')")
    public List<UserDto> list(@AuthenticationPrincipal CurrentUser me, @RequestParam(required = false) String q, @RequestParam(required = false) String role,
                              @RequestParam(required = false) Boolean active, @RequestParam(required = false) Integer limit,
                              @RequestParam(required = false) Integer offset) {
        return members.search(me, q, role, active, limit, offset);
    }

    @GetMapping("/members/{id}")
    public UserDto get(@AuthenticationPrincipal CurrentUser me, @PathVariable Long id) { return members.get(me, id); }

    @PostMapping("/members")
    @PreAuthorize("hasRole('ADMIN')")
    @ResponseStatus(HttpStatus.CREATED)
    public IdResponse create(@Valid @RequestBody MemberRequest body) { return members.create(body); }

    @PutMapping("/members/{id}")
    @PreAuthorize("hasRole('ADMIN')")
    public OkResponse update(@PathVariable Long id, @Valid @RequestBody MemberRequest body) {
        members.update(id, body);
        return OkResponse.OK;
    }

    /** Activer / désactiver un compte ; la désactivation révoque ses sessions. */
    @PostMapping("/members/{id}/status")
    @PreAuthorize("hasRole('ADMIN')")
    public StatusResponse status(@PathVariable Long id, @RequestBody StatusRequest body) {
        return members.setStatus(id, Boolean.TRUE.equals(body.active()));
    }

    @DeleteMapping("/members/{id}")
    @PreAuthorize("hasRole('ADMIN')")
    public OkResponse delete(@PathVariable Long id) {
        members.delete(id);
        return OkResponse.OK;
    }

    /** Prolonge l'abonnement et enregistre le paiement. */
    @PostMapping("/members/{id}/renew")
    @PreAuthorize("hasRole('ADMIN')")
    public OkResponse renew(@PathVariable Long id, @RequestBody RenewRequest body) {
        subscriptions.renew(id, body.planId(), body.method());
        return OkResponse.OK;
    }

    /** Annuaire des coachs (tous les utilisateurs connectés). */
    @GetMapping("/coaches")
    public List<CoachSummaryDto> coaches() { return members.coaches(); }
}
