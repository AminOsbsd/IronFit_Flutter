package com.ironfit.service;

import com.ironfit.security.CurrentUser;
import java.util.Map;

/** Tableaux de bord : vue globale (admin) ou limitée aux clients et aux cours du coach. */
public interface StatsService {
    Map<String, Object> stats(CurrentUser me);
}
