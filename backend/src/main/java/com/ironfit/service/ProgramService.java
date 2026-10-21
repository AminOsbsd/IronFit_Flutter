package com.ironfit.service;

import com.ironfit.dto.CommonDtos.IdResponse;
import com.ironfit.dto.ProgramDtos.*;
import com.ironfit.security.CurrentUser;
import java.util.List;

/**
 * Programmes et exercices.
 * Programme personnel (coach NULL) : modifiable par son propriétaire. Programme de coaching : modifiable par son coach
 * auteur tant que la relation est active ; le client le consulte et y enregistre ses séances.
 */
public interface ProgramService {
    List<ProgramDto> list(CurrentUser me, String scope, Long clientId, Integer limit, Integer offset);

    ProgramDetailDto get(CurrentUser me, Long id);

    IdResponse create(CurrentUser me, ProgramRequest req);

    void update(CurrentUser me, Long id, ProgramRequest req);

    void delete(CurrentUser me, Long id);

    IdResponse addExercise(CurrentUser me, Long programId, ExerciseRequest req);

    void updateExercise(CurrentUser me, Long exerciseId, ExerciseRequest req);

    void deleteExercise(CurrentUser me, Long exerciseId);
}
