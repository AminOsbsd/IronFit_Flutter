package com.ironfit.controller;

import com.ironfit.dto.ClassDtos.*;
import com.ironfit.dto.CommonDtos.IdResponse;
import com.ironfit.dto.CommonDtos.OkResponse;
import com.ironfit.security.CurrentUser;
import com.ironfit.service.ClassService;
import jakarta.validation.Valid;
import java.util.List;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.*;

/** Planning, réservations, participants et pointage. */
@RestController
@RequestMapping("/api")
public class ClassController {
    private final ClassService classes;

    public ClassController(ClassService classes) { this.classes = classes; }

    @GetMapping("/classes")
    public List<ClassDto> list(@AuthenticationPrincipal CurrentUser me) { return classes.list(me); }

    @PostMapping("/classes")
    @PreAuthorize("hasAnyRole('ADMIN','COACH')")
    @ResponseStatus(HttpStatus.CREATED)
    public IdResponse create(@AuthenticationPrincipal CurrentUser me, @Valid @RequestBody ClassRequest body) { return classes.create(me, body); }

    @PutMapping("/classes/{id}")
    @PreAuthorize("hasAnyRole('ADMIN','COACH')")
    public OkResponse update(@AuthenticationPrincipal CurrentUser me, @PathVariable Long id, @Valid @RequestBody ClassRequest body) {
        classes.update(me, id, body);
        return OkResponse.OK;
    }

    @DeleteMapping("/classes/{id}")
    @PreAuthorize("hasAnyRole('ADMIN','COACH')")
    public OkResponse delete(@AuthenticationPrincipal CurrentUser me, @PathVariable Long id) {
        classes.delete(me, id);
        return OkResponse.OK;
    }

    /** Réserve ou annule (bascule) ; abonnement actif requis pour réserver. */
    @PostMapping("/book")
    @PreAuthorize("hasRole('MEMBER')")
    public BookResponse book(@AuthenticationPrincipal CurrentUser me, @RequestBody BookRequest body) { return classes.book(me, body.classId()); }

    @GetMapping("/classes/{id}/participants")
    public List<ParticipantDto> participants(@AuthenticationPrincipal CurrentUser me, @PathVariable Long id) { return classes.participants(me, id); }

    @PostMapping("/classes/{id}/present")
    public OkResponse present(@AuthenticationPrincipal CurrentUser me, @PathVariable Long id, @RequestBody PresentRequest body) {
        classes.markPresent(me, id, body.memberId());
        return OkResponse.OK;
    }
}
