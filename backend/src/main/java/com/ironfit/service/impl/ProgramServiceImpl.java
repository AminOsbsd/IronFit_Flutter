package com.ironfit.service.impl;

import com.ironfit.dto.CommonDtos.IdResponse;
import com.ironfit.dto.ProgramDtos.*;
import com.ironfit.entity.Exercise;
import com.ironfit.entity.Program;
import com.ironfit.exception.ApiException;
import com.ironfit.repository.ExerciseRepository;
import com.ironfit.repository.OffsetLimit;
import com.ironfit.repository.ProgramRepository;
import com.ironfit.repository.UserRepository;
import com.ironfit.repository.WorkoutRepository;
import com.ironfit.security.CurrentUser;
import com.ironfit.service.AccessService;
import com.ironfit.service.NotificationService;
import com.ironfit.service.ProgramService;
import com.ironfit.service.Texts;
import java.time.LocalDate;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@Transactional
public class ProgramServiceImpl implements ProgramService {
    private final ProgramRepository programs;
    private final ExerciseRepository exercises;
    private final WorkoutRepository workouts;
    private final UserRepository users;
    private final AccessService access;
    private final ProgramAccess rights;
    private final NotificationService notifications;

    public ProgramServiceImpl(ProgramRepository programs, ExerciseRepository exercises, WorkoutRepository workouts, UserRepository users,
                              AccessService access, ProgramAccess rights, NotificationService notifications) {
        this.programs = programs;
        this.exercises = exercises;
        this.workouts = workouts;
        this.users = users;
        this.access = access;
        this.rights = rights;
        this.notifications = notifications;
    }

    private record Counts(long exercises, long sessions, LocalDate lastDone) {}

    private Map<Long, Counts> counts(List<Program> list) {
        Map<Long, Counts> out = new HashMap<>();
        if (list.isEmpty()) return out;
        List<Long> ids = list.stream().map(Program::getId).toList();
        Map<Long, Long> ex = new HashMap<>();
        for (Object[] row : exercises.countPerProgram(ids)) ex.put((Long) row[0], (Long) row[1]);
        for (Object[] row : workouts.statsPerProgram(ids)) out.put((Long) row[0], new Counts(0, (Long) row[1], (LocalDate) row[2]));
        for (Long id : ids) {
            Counts c = out.getOrDefault(id, new Counts(0, 0, null));
            out.put(id, new Counts(ex.getOrDefault(id, 0L), c.sessions(), c.lastDone()));
        }
        return out;
    }

    private static ProgramDto dto(Program p, Counts c) {
        return new ProgramDto(p.getId(), p.getClient().getId(), p.coachId(), p.getTitle(), p.getGoal(), p.getNotes(), p.isActive(), p.getCreated(),
                p.getCoach() == null ? null : p.getCoach().getName(), p.getClient().getName(), c.exercises(), c.sessions(), c.lastDone());
    }

    private List<ProgramDto> withCounts(List<Program> list) {
        Map<Long, Counts> c = counts(list);
        return list.stream().map(p -> dto(p, c.get(p.getId()))).toList();
    }

    private Program program(Long id) { return programs.findById(id).orElseThrow(() -> ApiException.notFound("Programme introuvable")); }

    private Program editable(CurrentUser me, Long id) {
        Program p = program(id);
        AccessService.require(rights.canEdit(me, p));
        return p;
    }

    @Override
    @Transactional(readOnly = true)
    public List<ProgramDto> list(CurrentUser me, String scope, Long clientId, Integer limit, Integer offset) {
        String s = scope == null ? "personal" : scope;
        switch (s) {
            case "personal" -> {
                AccessService.require(me.isMember());
                return withCounts(programs.findPersonal(me.id()));
            }
            case "coaching" -> {
                AccessService.require(me.isCoach());
                return withCounts(programs.findCoaching(me.id(), clientId));
            }
            case "all" -> {
                AccessService.require(me.isAdmin());
                return withCounts(programs.findAllWithUsers(OffsetLimit.of(offset, limit, 500)));
            }
            default -> throw ApiException.badRequest("Paramètre scope invalide");
        }
    }

    @Override
    @Transactional(readOnly = true)
    public ProgramDetailDto get(CurrentUser me, Long id) {
        Program p = program(id);
        AccessService.require(rights.canRead(me, p));
        Counts c = counts(List.of(p)).get(p.getId());
        return new ProgramDetailDto(p.getId(), p.getClient().getId(), p.coachId(), p.getTitle(), p.getGoal(), p.getNotes(), p.isActive(), p.getCreated(),
                p.getCoach() == null ? null : p.getCoach().getName(), p.getClient().getName(), c.exercises(), c.sessions(), c.lastDone(),
                rights.canEdit(me, p), p.getClient().getId().equals(me.id()), rights.isAuthor(me, p),
                exercises.findForProgram(p.getId()).stream().map(ExerciseDto::of).toList(),
                workouts.findForProgram(p.getId(), OffsetLimit.first(30)).stream().map(WorkoutDto::of).toList());
    }

    @Override
    public IdResponse create(CurrentUser me, ProgramRequest req) {
        Long client = req.clientId() == null ? me.id() : req.clientId();
        boolean forClient = !client.equals(me.id());
        if (forClient) AccessService.require(me.isCoach() && access.coaches(me.id(), client));
        else AccessService.require(me.isMember());
        Program p = new Program();
        p.setClient(users.getReferenceById(client));
        p.setCoach(forClient ? users.getReferenceById(me.id()) : null);
        p.setTitle(req.title().trim());
        p.setGoal(Texts.clean(req.goal()));
        p.setNotes(Texts.clean(req.notes()));
        Long id = programs.save(p).getId();
        if (forClient) notifications.notify(client, "Nouveau programme", me.name() + " vous a préparé « " + p.getTitle() + " ».");
        return new IdResponse(id);
    }

    @Override
    public void update(CurrentUser me, Long id, ProgramRequest req) {
        Program p = editable(me, id);
        p.setTitle(req.title().trim());
        p.setGoal(Texts.clean(req.goal()));
        p.setNotes(Texts.clean(req.notes()));
        if (req.active() != null) p.setActive(req.active());
    }

    @Override
    public void delete(CurrentUser me, Long id) { programs.delete(editable(me, id)); }

    private static void apply(Exercise e, ExerciseRequest req) {
        e.setDay(Texts.clean(req.day()));
        e.setName(req.name().trim());
        e.setSets(req.sets());
        e.setReps(Texts.clean(req.reps()));
        e.setLoad(Texts.clean(req.load()));
        e.setRest(Texts.clean(req.rest()));
        e.setNotes(Texts.clean(req.notes()));
    }

    @Override
    public IdResponse addExercise(CurrentUser me, Long programId, ExerciseRequest req) {
        Program p = editable(me, programId);
        Exercise e = new Exercise();
        e.setProgram(p);
        apply(e, req);
        e.setPosition(req.position() != null ? req.position() : (int) exercises.countByProgramId(p.getId()));
        return new IdResponse(exercises.save(e).getId());
    }

    private Exercise exercise(CurrentUser me, Long id) {
        Exercise e = exercises.findById(id).orElseThrow(() -> ApiException.notFound("Exercice introuvable"));
        editable(me, e.getProgram().getId());
        return e;
    }

    @Override
    public void updateExercise(CurrentUser me, Long exerciseId, ExerciseRequest req) {
        Exercise e = exercise(me, exerciseId);
        apply(e, req);
        if (req.position() != null) e.setPosition(req.position());
    }

    @Override
    public void deleteExercise(CurrentUser me, Long exerciseId) { exercises.delete(exercise(me, exerciseId)); }
}
