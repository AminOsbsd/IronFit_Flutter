package com.ironfit.service;

import com.ironfit.dto.CommonDtos.IdResponse;
import com.ironfit.dto.ProgramDtos.WorkoutDto;
import com.ironfit.dto.ProgramDtos.WorkoutRequest;
import com.ironfit.security.CurrentUser;
import java.util.List;

/** Séances réalisées et commentaires du coach. Un coach ne voit que les séances liées aux programmes qu'il a écrits. */
public interface WorkoutService {
    List<WorkoutDto> list(CurrentUser me, Long userId, Long programId, Integer limit, Integer offset);

    IdResponse create(CurrentUser me, WorkoutRequest req);

    void delete(CurrentUser me, Long id);

    void feedback(CurrentUser me, Long id, String comment);
}
