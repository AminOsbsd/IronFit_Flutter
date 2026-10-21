package com.ironfit.controller;

import com.ironfit.security.CurrentUser;
import com.ironfit.service.StatsService;
import java.util.Map;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

/** Tableaux de bord (admin : global ; coach : ses clients et ses cours). */
@RestController
public class StatsController {
    private final StatsService stats;

    public StatsController(StatsService stats) { this.stats = stats; }

    @GetMapping("/api/stats")
    @PreAuthorize("hasAnyRole('ADMIN','COACH')")
    public Map<String, Object> stats(@AuthenticationPrincipal CurrentUser me) { return stats.stats(me); }
}
