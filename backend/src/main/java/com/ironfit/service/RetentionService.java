package com.ironfit.service;

import com.ironfit.dto.RiskDtos.RemindResponse;
import com.ironfit.dto.RiskDtos.RiskMemberDto;
import com.ironfit.security.CurrentUser;
import java.util.List;

/** Détection des membres à risque d'abandon et relances (manuelles ou automatiques). */
public interface RetentionService {
    /** Admin : tous les membres ; coach : ses clients actifs. Triés du plus risqué au moins risqué. */
    List<RiskMemberDto> atRisk(CurrentUser me, boolean includeLow);

    /** Relance manuelle (notification + e-mail) d'un membre par son coach actif ou par l'admin. */
    RemindResponse remind(CurrentUser me, Long memberId);

    /** Analyse complète : relance les membres à risque élevé et prévient leurs coachs. Renvoie le nombre de relances. */
    int runNightly();
}
