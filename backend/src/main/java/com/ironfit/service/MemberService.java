package com.ironfit.service;

import com.ironfit.dto.CommonDtos.IdResponse;
import com.ironfit.dto.UserDtos.*;
import com.ironfit.security.CurrentUser;
import java.util.List;

/** Membres et coachs : liste (admin : tous ; coach : ses clients actifs), gestion des comptes (admin), annuaire des coachs. */
public interface MemberService {
    List<UserDto> search(CurrentUser me, String q, String role, Boolean active, Integer limit, Integer offset);

    UserDto get(CurrentUser me, Long id);

    IdResponse create(MemberRequest req);

    void update(Long id, MemberRequest req);

    StatusResponse setStatus(Long id, boolean active);

    void delete(Long id);

    List<CoachSummaryDto> coaches();
}
