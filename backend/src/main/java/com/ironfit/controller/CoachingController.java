package com.ironfit.controller;

import com.ironfit.dto.CoachingDtos.*;
import com.ironfit.dto.CommonDtos.OkResponse;
import com.ironfit.security.CurrentUser;
import com.ironfit.service.CoachingService;
import java.util.List;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

/** Relations coach ↔ client. */
@RestController
@RequestMapping("/api/coaching")
public class CoachingController {
    private final CoachingService coaching;

    public CoachingController(CoachingService coaching) { this.coaching = coaching; }

    /** Mes coachs (vue membre). */
    @GetMapping("/mine")
    public List<CoachingLinkDto> mine(@AuthenticationPrincipal CurrentUser me) { return coaching.mine(me); }

    /** Mes clients : demandes en attente + suivis actifs (vue coach). */
    @GetMapping("/clients")
    @PreAuthorize("hasRole('COACH')")
    public List<CoachingLinkDto> clients(@AuthenticationPrincipal CurrentUser me) { return coaching.clients(me); }

    /** Toutes les relations (admin). */
    @GetMapping
    @PreAuthorize("hasRole('ADMIN')")
    public List<CoachingLinkDto> all(@RequestParam(required = false) String status) { return coaching.all(status); }

    @PostMapping("/request")
    @PreAuthorize("hasRole('MEMBER')")
    public OkResponse request(@AuthenticationPrincipal CurrentUser me, @RequestBody CoachRequest body) {
        coaching.request(me, body.coachId());
        return OkResponse.OK;
    }

    @PostMapping("/assign")
    @PreAuthorize("hasRole('ADMIN')")
    public OkResponse assign(@RequestBody AssignRequest body) {
        coaching.assign(body.coachId(), body.clientId());
        return OkResponse.OK;
    }

    @PostMapping("/{id}/{action:accept|decline|end}")
    public OkResponse act(@AuthenticationPrincipal CurrentUser me, @PathVariable Long id, @PathVariable String action) {
        coaching.act(me, id, action);
        return OkResponse.OK;
    }
}
