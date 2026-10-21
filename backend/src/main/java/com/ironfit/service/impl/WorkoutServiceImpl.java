package com.ironfit.service.impl;

import com.ironfit.dto.CommonDtos.IdResponse;
import com.ironfit.dto.ProgramDtos.WorkoutDto;
import com.ironfit.dto.ProgramDtos.WorkoutRequest;
import com.ironfit.entity.Program;
import com.ironfit.entity.Workout;
import com.ironfit.exception.ApiException;
import com.ironfit.repository.OffsetLimit;
import com.ironfit.repository.ProgramRepository;
import com.ironfit.repository.UserRepository;
import com.ironfit.repository.WorkoutRepository;
import com.ironfit.security.CurrentUser;
import com.ironfit.service.AccessService;
import com.ironfit.service.NotificationService;
import com.ironfit.service.Texts;
import com.ironfit.service.WorkoutService;
import java.time.LocalDate;
import java.util.List;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@Transactional
public class WorkoutServiceImpl implements WorkoutService {
    private final WorkoutRepository workouts;
    private final ProgramRepository programs;
    private final UserRepository users;
    private final AccessService access;
    private final ProgramAccess rights;
    private final NotificationService notifications;

    public WorkoutServiceImpl(WorkoutRepository workouts, ProgramRepository programs, UserRepository users, AccessService access,
                              ProgramAccess rights, NotificationService notifications) {
        this.workouts = workouts;
        this.programs = programs;
        this.users = users;
        this.access = access;
        this.rights = rights;
        this.notifications = notifications;
    }

    @Override
    @Transactional(readOnly = true)
    public List<WorkoutDto> list(CurrentUser me, Long userId, Long programId, Integer limit, Integer offset) {
        Long user = userId == null ? me.id() : userId;
        var page = OffsetLimit.of(offset, limit, 100);
        if (user.equals(me.id()) || me.isAdmin()) return workouts.findForUser(user, programId, null, page).stream().map(WorkoutDto::of).toList();
        // Coach : uniquement les séances liées aux programmes qu'il a écrits pour ce client
        AccessService.require(me.isCoach() && access.coaches(me.id(), user));
        return workouts.findForUser(user, programId, me.id(), page).stream().map(WorkoutDto::of).toList();
    }

    @Override
    public IdResponse create(CurrentUser me, WorkoutRequest req) {
        AccessService.require(me.isMember());
        LocalDate day = req.doneOn() == null ? LocalDate.now() : req.doneOn();
        if (day.isAfter(LocalDate.now())) throw ApiException.badRequest("La date ne peut pas être dans le futur");
        Program p = null;
        if (req.programId() != null) {
            p = programs.findById(req.programId()).orElseThrow(() -> ApiException.notFound("Programme introuvable"));
            AccessService.require(p.getClient().getId().equals(me.id()));
        }
        Workout w = new Workout();
        w.setUser(users.getReferenceById(me.id()));
        w.setProgram(p);
        w.setDoneOn(day);
        w.setDuration(req.duration());
        w.setRpe(req.rpe());
        w.setNotes(Texts.clean(req.notes()));
        Long id = workouts.save(w).getId();
        if (p != null && p.getCoach() != null && access.coaches(p.getCoach().getId(), me.id())) {
            notifications.notify(p.getCoach().getId(), "Séance terminée", me.name() + " a réalisé « " + p.getTitle() + " » (" + day + ").");
        }
        return new IdResponse(id);
    }

    @Override
    public void delete(CurrentUser me, Long id) {
        Workout w = workouts.findById(id).orElseThrow(() -> ApiException.notFound("Séance introuvable"));
        AccessService.require(w.getUser().getId().equals(me.id()));
        workouts.delete(w);
    }

    @Override
    public void feedback(CurrentUser me, Long id, String comment) {
        Workout w = workouts.findById(id).filter(x -> x.getProgram() != null).orElseThrow(() -> ApiException.notFound("Séance introuvable"));
        AccessService.require(rights.isAuthor(me, w.getProgram()));
        String c = Texts.clean(comment);
        if (c != null && c.length() > 1000) c = c.substring(0, 1000);
        w.setCoachComment(c);
        if (c != null) notifications.notify(w.getUser().getId(), "Nouveau commentaire de votre coach",
                me.name() + " a commenté votre séance « " + w.getProgram().getTitle() + " ».");
    }
}
