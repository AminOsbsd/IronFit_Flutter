package com.ironfit.service.impl;

import com.ironfit.dto.ClassDtos.*;
import com.ironfit.dto.CommonDtos.IdResponse;
import com.ironfit.entity.DatedBooking;
import com.ironfit.entity.Checkin;
import com.ironfit.entity.ClassSession;
import com.ironfit.entity.Role;
import com.ironfit.entity.User;
import com.ironfit.exception.ApiException;
import com.ironfit.repository.DatedBookingRepository;
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
    @jakarta.persistence.PersistenceContext private jakarta.persistence.EntityManager em;
    private static LocalDate today() { return LocalDate.now(java.time.ZoneId.of("Africa/Tunis")); }
    private LocalDate date(ClassSession c, LocalDate requested) {
        LocalDate d=requested==null ? today().plusDays((c.getDay()-today().getDayOfWeek().getValue()+8)%7) : requested;
        if(requested==null && d.equals(today()) && java.time.LocalTime.parse(c.getTime()).isBefore(java.time.LocalTime.now(java.time.ZoneId.of("Africa/Tunis")))) d=d.plusWeeks(1);
        if(d.getDayOfWeek().getValue()-1 != c.getDay()) throw ApiException.badRequest("Date incompatible avec le jour du cours");
        return d;
    }

    private final ClassSessionRepository classes;
    private final DatedBookingRepository bookings;
    private final CheckinRepository checkins;
    private final UserRepository users;
    private final AccessService access;
    private final NotificationService notifications;

    public ClassServiceImpl(ClassSessionRepository classes, DatedBookingRepository bookings, CheckinRepository checkins, UserRepository users,
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
    public List<ClassDto> list(CurrentUser me, LocalDate week) {
        LocalDate monday=week==null ? null : week.minusDays(week.getDayOfWeek().getValue()-1);
        return classes.findAllWithCoach().stream().map(c -> {
            LocalDate d=date(c,monday==null?null:monday.plusDays(c.getDay()));
            return new ClassDto(c.getId(),c.getDay(),c.getTime(),c.getTitle(),c.coachId(),c.getSpots(),c.getCoach()==null?null:c.getCoach().getName(),c.getCoach()==null?null:c.getCoach().getSpecialty(),bookings.countByClassSessionIdAndSessionDate(c.getId(),d),bookings.findByUserIdAndClassSessionIdAndSessionDate(me.id(),c.getId(),d).isPresent(),d);
        }).toList();
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
        em.lock(c,jakarta.persistence.LockModeType.PESSIMISTIC_WRITE);
        if(!Objects.equals(c.getDay(),req.day()) && bookings.countByClassSessionId(c.getId())>0) throw ApiException.conflict("Ce cours possède des réservations datées. Annulez-les avant de changer son jour.");
        int capacity=req.spots()==null?10:req.spots();
        for(var b:bookings.findAll()) if(b.getClassSession().getId().equals(c.getId()) && !b.getSessionDate().isBefore(today()) && bookings.countByClassSessionIdAndSessionDate(c.getId(),b.getSessionDate())>capacity) throw ApiException.conflict("La capacité ne peut pas être inférieure aux réservations existantes");
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
    public BookResponse book(CurrentUser me, Long classId, LocalDate requested, Boolean desired) {
        AccessService.require(me.isMember());
        ClassSession c = cls(classId);
        em.lock(c,jakarta.persistence.LockModeType.PESSIMISTIC_WRITE);
        LocalDate d=date(c,requested);
        if(d.isBefore(today()) || d.isAfter(today().plusDays(90))) throw ApiException.badRequest("Réservation possible entre aujourd’hui et 90 jours");
        var existing = bookings.findByUserIdAndClassSessionIdAndSessionDate(me.id(), c.getId(),d);
        if(desired!=null && desired==existing.isPresent()) return new BookResponse(true,desired);
        if (existing.isPresent()) {
            bookings.delete(existing.get());
            return new BookResponse(true, false);
        }
        if(d.equals(today()) && java.time.LocalTime.parse(c.getTime()).isBefore(java.time.LocalTime.now(java.time.ZoneId.of("Africa/Tunis")))) throw ApiException.badRequest("Ce cours a déjà commencé");
        if(Boolean.FALSE.equals(desired)) return new BookResponse(true,false);
        if (Objects.equals(c.coachId(), me.id())) throw ApiException.badRequest("Vous animez cette séance");
        User u = access.user(me.id());
        if (u.getSubEnd() == null || u.getSubEnd().isBefore(d)) {
            throw ApiException.forbidden("Abonnement actif requis pour réserver (voir Explorer → Tarifs)");
        }
        if (bookings.countByClassSessionIdAndSessionDate(c.getId(),d) >= c.getSpots()) throw ApiException.conflict("Séance complète");
        DatedBooking booking=new DatedBooking(u,c);booking.setSessionDate(d);bookings.save(booking);
        return new BookResponse(true, true);
    }

    @Override
    @Transactional(readOnly = true)
    public List<ParticipantDto> participants(CurrentUser me, Long classId, LocalDate requested) {
        ClassSession c = cls(classId);
        manage(me, c);
        LocalDate d=date(c,requested);
        return bookings.findByClassSessionIdAndSessionDate(c.getId(),d).stream().map(b -> new ParticipantDto(b.getUser().getId(),b.getUser().getName(),b.getUser().getPhone(),b.isPresent())).toList();
    }

    @Override
    public void markPresent(CurrentUser me, Long classId, Long memberId, LocalDate requested) {
        ClassSession c = cls(classId);
        manage(me, c);
        LocalDate today=date(c,requested);
        var booking=bookings.findByUserIdAndClassSessionIdAndSessionDate(memberId,c.getId(),today).orElseThrow(()->ApiException.notFound("Réservation introuvable"));
        if(!today.equals(today())) throw ApiException.badRequest("Le pointage se fait le jour de la séance");
        booking.setPresent(true);
        if (!checkins.existsByMemberIdAndCheckinOnAndNote(memberId, today, c.getTitle())) {
            Checkin k = new Checkin();
            k.setMember(users.getReferenceById(memberId));
            k.setCheckinOn(today);
            k.setNote(c.getTitle());
            checkins.save(k);
        }
    }
}
