package com.ironfit.controller;

import com.ironfit.dto.CommonDtos.IdResponse;
import com.ironfit.dto.CommonDtos.OkResponse;
import com.ironfit.dto.ProgramDtos.FeedbackRequest;
import com.ironfit.dto.ProgramDtos.WorkoutDto;
import com.ironfit.dto.ProgramDtos.WorkoutRequest;
import com.ironfit.security.CurrentUser;
import com.ironfit.service.WorkoutService;
import jakarta.validation.Valid;
import java.util.List;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

/** Séances réalisées et commentaires du coach. */
@RestController
@RequestMapping("/api/workouts")
public class WorkoutController {
    private final WorkoutService workouts;

    public WorkoutController(WorkoutService workouts) { this.workouts = workouts; }

    @GetMapping
    public List<WorkoutDto> list(@AuthenticationPrincipal CurrentUser me, @RequestParam(name = "user_id", required = false) Long userId,
                                 @RequestParam(name = "program_id", required = false) Long programId,
                                 @RequestParam(required = false) Integer limit, @RequestParam(required = false) Integer offset) {
        return workouts.list(me, userId, programId, limit, offset);
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public IdResponse create(@AuthenticationPrincipal CurrentUser me, @Valid @RequestBody WorkoutRequest body) { return workouts.create(me, body); }

    @DeleteMapping("/{id}")
    public OkResponse delete(@AuthenticationPrincipal CurrentUser me, @PathVariable Long id) {
        workouts.delete(me, id);
        return OkResponse.OK;
    }

    @PostMapping("/{id}/feedback")
    public OkResponse feedback(@AuthenticationPrincipal CurrentUser me, @PathVariable Long id, @RequestBody FeedbackRequest body) {
        workouts.feedback(me, id, body.comment());
        return OkResponse.OK;
    }
}
