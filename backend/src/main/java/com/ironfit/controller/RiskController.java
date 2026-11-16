package com.ironfit.controller;

import com.ironfit.dto.RiskDtos.RemindResponse;
import com.ironfit.dto.RiskDtos.RiskMemberDto;
import com.ironfit.dto.RiskDtos.RunResponse;
import com.ironfit.security.CurrentUser;
import com.ironfit.service.RetentionService;
import java.util.List;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

/** Membres à risque d'abandon : liste (admin : tous ; coach : ses clients), relance manuelle, analyse à la demande. */
@RestController
@RequestMapping("/api/risk")
public class RiskController {
    private final RetentionService retention;

    public RiskController(RetentionService retention) { this.retention = retention; }

    @GetMapping
    @PreAuthorize("hasAnyRole('ADMIN','COACH')")
    public List<RiskMemberDto> atRisk(@AuthenticationPrincipal CurrentUser me, @RequestParam(name = "all", defaultValue = "false") boolean all) {
        return retention.atRisk(me, all);
    }

    @PostMapping("/{memberId}/remind")
    @PreAuthorize("hasAnyRole('ADMIN','COACH')")
    public RemindResponse remind(@AuthenticationPrincipal CurrentUser me, @PathVariable Long memberId) {
        return retention.remind(me, memberId);
    }

    /** Lance l'analyse nocturne immédiatement (démonstration, ou rattrapage après une panne). */
    @PostMapping("/run")
    @PreAuthorize("hasRole('ADMIN')")
    public RunResponse run() { return new RunResponse(retention.runNightly()); }
}
