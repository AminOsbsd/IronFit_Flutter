package com.ironfit.controller;

import com.ironfit.dto.CommonDtos.IdResponse;
import com.ironfit.dto.CommonDtos.OkResponse;
import com.ironfit.dto.ProgramDtos.*;
import com.ironfit.security.CurrentUser;
import com.ironfit.service.ProgramService;
import jakarta.validation.Valid;
import java.util.List;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

/** Programmes d'entraînement et exercices. */
@RestController
@RequestMapping("/api")
public class ProgramController {
    private final ProgramService programs;

    public ProgramController(ProgramService programs) { this.programs = programs; }

    /** scope=personal (défaut) | coaching (&client_id=) | all (admin). */
    @GetMapping("/programs")
    public List<ProgramDto> list(@AuthenticationPrincipal CurrentUser me, @RequestParam(required = false) String scope,
                                 @RequestParam(name = "client_id", required = false) Long clientId,
                                 @RequestParam(required = false) Integer limit, @RequestParam(required = false) Integer offset) {
        return programs.list(me, scope, clientId, limit, offset);
    }

    @GetMapping("/programs/{id}")
    public ProgramDetailDto get(@AuthenticationPrincipal CurrentUser me, @PathVariable Long id) { return programs.get(me, id); }

    @PostMapping("/programs")
    @ResponseStatus(HttpStatus.CREATED)
    public IdResponse create(@AuthenticationPrincipal CurrentUser me, @Valid @RequestBody ProgramRequest body) { return programs.create(me, body); }

    @PutMapping("/programs/{id}")
    public OkResponse update(@AuthenticationPrincipal CurrentUser me, @PathVariable Long id, @Valid @RequestBody ProgramRequest body) {
        programs.update(me, id, body);
        return OkResponse.OK;
    }

    @DeleteMapping("/programs/{id}")
    public OkResponse delete(@AuthenticationPrincipal CurrentUser me, @PathVariable Long id) {
        programs.delete(me, id);
        return OkResponse.OK;
    }

    @PostMapping("/programs/{id}/exercises")
    @ResponseStatus(HttpStatus.CREATED)
    public IdResponse addExercise(@AuthenticationPrincipal CurrentUser me, @PathVariable Long id, @Valid @RequestBody ExerciseRequest body) {
        return programs.addExercise(me, id, body);
    }

    @PutMapping("/exercises/{id}")
    public OkResponse updateExercise(@AuthenticationPrincipal CurrentUser me, @PathVariable Long id, @Valid @RequestBody ExerciseRequest body) {
        programs.updateExercise(me, id, body);
        return OkResponse.OK;
    }

    @DeleteMapping("/exercises/{id}")
    public OkResponse deleteExercise(@AuthenticationPrincipal CurrentUser me, @PathVariable Long id) {
        programs.deleteExercise(me, id);
        return OkResponse.OK;
    }
}
