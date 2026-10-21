package com.ironfit.service;

import com.ironfit.dto.CommonDtos.IdResponse;
import com.ironfit.dto.SubscriptionDtos.RequestDto;
import com.ironfit.security.CurrentUser;
import java.util.List;

/** Demandes d'abonnement (membre → admin) et renouvellement par l'admin. */
public interface SubscriptionService {
    List<RequestDto> list(CurrentUser me);

    IdResponse create(CurrentUser me, Long planId);

    void act(CurrentUser me, Long requestId, String action, String method);

    void renew(Long memberId, Long planId, String method);
}
