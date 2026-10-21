package com.ironfit.service.impl;

import com.ironfit.dto.ClassDtos.*;
import com.ironfit.dto.CommonDtos.IdResponse;
import com.ironfit.entity.Booking;
import com.ironfit.entity.Checkin;
import com.ironfit.entity.ClassSession;
import com.ironfit.entity.Role;
import com.ironfit.entity.User;
import com.ironfit.exception.ApiException;
import com.ironfit.repository.BookingRepository;
import com.ironfit.repository.CheckinRepository;
import com.ironfit.repository.ClassSessionRepository;
import com.ironfit.repository.UserRepository;
import com.ironfit.security.CurrentUser;
import com.ironfit.service.AccessService;
import com.ironfit.service.ClassService;
import com.ironfit.service.NotificationService;
import java.time.LocalDate;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@Transactional
public class ClassServiceImpl implements ClassService {
    private final ClassSessionRepository classes;
    private final BookingRepository bookings;
    private final CheckinRepository checkins;
    private final UserRepository users;
    private final AccessService access;
    private final NotificationService notifications;

    public ClassServiceImpl(ClassSessionRepository classes, BookingRepository bookings, CheckinRepository checkins, UserRepository users,
                            AccessService access, NotificationService notifications) {
        this.classes = classes;
        this.bookings = bookings;
        this.checkins = checkins;
        this.users = users;
        this.access = access;
        this.notifications = notifications;
    }

    private ClassSession cls(Long id) {
        return classes.findById(id == null ? -1 : id).orElseThrow(() -> ApiException.notFound("Séance introuvable"));
    }

    /** Seuls l'admin et le coach qui anime la séance gèrent ses participants. */
    private static void manage(CurrentUser me, ClassSession c) {
        AccessService.require(me.isAdmin() || Objects.equals(c.coachId(), me.id()));
    }

    @Override
    @Transactional(readOnly = true)
    public List<ClassDto> list(CurrentUser me) {
        Map<Long, Long> taken = new HashMap<>();
        for (Object[] row : bookings.countPerClass()) taken.put((Long) row[0], (Long) row[1]);
        Set<Long> mine = new HashSet<>(bookings.classIdsBookedBy(me.id()));
        return classes.findAllWithCoach().stream().map(c -> new ClassDto(c.getId(), c.getDay(), c.getTime(), c.getTitle(), c.coachId(), c.getSpots(),
                c.getCoach() == null ? null : c.getCoach().getName(), c.getCoach() == null ? null : c.getCoach().getSpecialty(),
                taken.getOrDefault(c.getId(), 0L), mine.contains(c.getId()))).toList();
    }

    /** Coach : la séance lui est toujours attribuée. Admin : coach libre (doit être un coach). */
    private void apply(CurrentUser me, ClassSession c, ClassRequest req) {
        Long coachId = me.isCoach() ? me.id() : req.coachId();
        User coach = null;
        if (coachId != null) {
            coach = users.findById(coachId).filter(u -> u.getRole() == Role.COACH).orElseThrow(() -> ApiException.badRequest("Coach introuvable"));
        }
        c.setDay(req.day());
        c.setTime(req.time());
        c.setTitle(req.title().trim());
        c.setCoach(coach);
        c.setSpots(req.spots() == null ? 10 : req.spots());
    }

    private ClassSession owned(CurrentUser me, Long id) {
        AccessService.require(me.isAdmin() || me.isCoach());
        ClassSession c = cls(id);
        if (me.isCoach() && !Objects.equals(c.coachId(), me.id())) throw ApiException.forbidden("Vous ne pouvez modifier que vos propres séances");
        return c;
    }

    private void notifyBooked(Long classId, String title, String body) {
        for (User u : bookings.participants(classId)) notifications.notify(u.getId(), title, body);
    }

    @Override
    public IdResponse create(CurrentUser me, ClassRequest req) {
        AccessService.require(me.isAdmin() || me.isCoach());
        ClassSession c = new ClassSession();
        apply(me, c, req);
        return new IdResponse(classes.save(c).getId());
    }

    @Override
    public void update(CurrentUser me, Long id, ClassRequest req) {
        ClassSession c = owned(me, id);
        boolean moved = !Objects.equals(c.getDay(), req.day()) || !Objects.equals(c.getTime(), req.time());
        apply(me, c, req);
        if (moved) notifyBooked(c.getId(), "Séance modifiée", "« " + c.getTitle() + " » a lieu désormais à " + c.getTime() + ".");
    }

    @Override
    public void delete(CurrentUser me, Long id) {
        ClassSession c = owned(me, id);
        // avant la suppression : les réservations disparaissent en cascade
        notifyBooked(c.getId(), "Séance annulée", "« " + c.getTitle() + " » (" + c.getTime() + ") a été retirée du planning.");
        classes.delete(c);
    }

    @Override
    public BookResponse book(CurrentUser me, Long classId) {
        AccessService.require(me.isMember());
        ClassSession c = cls(classId);
        var existing = bookings.findByUserIdAndClassSessionId(me.id(), c.getId());
        if (existing.isPresent()) {
            bookings.delete(existing.get());
            return new BookResponse(true, false);
        }
        if (Objects.equals(c.coachId(), me.id())) throw ApiException.badRequest("Vous animez cette séance");
        User u = access.user(me.id());
        if (u.getSubEnd() == null || u.getSubEnd().isBefore(LocalDate.now())) {
            throw ApiException.forbidden("Abonnement actif requis pour réserver (voir Explorer → Tarifs)");
        }
        if (bookings.countByClassSessionId(c.getId()) >= c.getSpots()) throw ApiException.conflict("Séance complète");
        bookings.save(new Booking(u, c));
        return new BookResponse(true, true);
    }

    @Override
    @Transactional(readOnly = true)
    public List<ParticipantDto> participants(CurrentUser me, Long classId) {
        ClassSession c = cls(classId);
        manage(me, c);
        Set<Long> present = new HashSet<>(checkins.memberIdsPresent(LocalDate.now(), c.getTitle()));
        return bookings.participants(c.getId()).stream()
                .map(u -> new ParticipantDto(u.getId(), u.getName(), u.getPhone(), present.contains(u.getId()))).toList();
    }

    @Override
    public void markPresent(CurrentUser me, Long classId, Long memberId) {
        ClassSession c = cls(classId);
        manage(me, c);
        if (memberId == null || !bookings.existsByUserIdAndClassSessionId(memberId, c.getId())) {
            throw ApiException.notFound("Ce membre n’a pas réservé cette séance");
        }
        LocalDate today = LocalDate.now();
        if (c.getDay() != today.getDayOfWeek().getValue() - 1) throw ApiException.badRequest("Le pointage se fait le jour de la séance");
        if (!checkins.existsByMemberIdAndCheckinOnAndNote(memberId, today, c.getTitle())) {
            Checkin k = new Checkin();
            k.setMember(users.getReferenceById(memberId));
            k.setCheckinOn(today);
            k.setNote(c.getTitle());
            checkins.save(k);
        }
    }
}
