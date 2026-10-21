package com.ironfit.service.impl;

import com.ironfit.dto.CoachingDtos.CoachingLinkDto;
import com.ironfit.entity.CoachClient;
import com.ironfit.entity.Role;
import com.ironfit.entity.User;
import com.ironfit.exception.ApiException;
import com.ironfit.repository.CoachClientRepository;
import com.ironfit.repository.UserRepository;
import com.ironfit.repository.WorkoutRepository;
import com.ironfit.security.CurrentUser;
import com.ironfit.service.AccessService;
import com.ironfit.service.CoachingService;
import com.ironfit.service.NotificationService;
import java.time.Instant;
import java.util.Comparator;
import java.util.List;
import java.util.Objects;
import java.util.Set;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@Transactional
public class CoachingServiceImpl implements CoachingService {
    private static final Set<String> STATUSES = Set.of("pending", "active", "declined", "ended");
    private static final Comparator<CoachingLinkDto> RECENT = Comparator.comparing(CoachingLinkDto::updated, Comparator.nullsLast(Comparator.<Instant>naturalOrder())).reversed();

    private final CoachClientRepository links;
    private final UserRepository users;
    private final WorkoutRepository workouts;
    private final AccessService access;
    private final NotificationService notifications;

    public CoachingServiceImpl(CoachClientRepository links, UserRepository users, WorkoutRepository workouts, AccessService access,
                               NotificationService notifications) {
        this.links = links;
        this.users = users;
        this.workouts = workouts;
        this.access = access;
        this.notifications = notifications;
    }

    private CoachingLinkDto dto(CoachClient l) {
        User co = l.getCoach(), cl = l.getClient();
        boolean active = "active".equals(l.getStatus());
        return new CoachingLinkDto(l.getId(), co.getId(), cl.getId(), l.getStatus(), l.getCreated(), l.getUpdated(),
                co.getName(), co.getSpecialty(), cl.getName(), cl.getLogin(), active ? cl.getPhone() : null, cl.getSubEnd(),
                workouts.lastForCoachAndClient(co.getId(), cl.getId()));
    }

    private static int activeFirst(CoachingLinkDto l) { return "active".equals(l.status()) ? 0 : 1; }

    @Override
    @Transactional(readOnly = true)
    public List<CoachingLinkDto> mine(CurrentUser me) {
        return links.findForClient(me.id()).stream().map(this::dto)
                .sorted(Comparator.comparingInt(CoachingServiceImpl::activeFirst).thenComparing(RECENT)).toList();
    }

    @Override
    @Transactional(readOnly = true)
    public List<CoachingLinkDto> clients(CurrentUser me) {
        AccessService.require(me.isCoach());
        return links.findForCoach(me.id(), List.of("pending", "active")).stream().map(this::dto)
                .sorted(Comparator.comparingInt((CoachingLinkDto l) -> "pending".equals(l.status()) ? 0 : 1)
                        .thenComparing(l -> l.clientName().toLowerCase()))
                .toList();
    }

    @Override
    @Transactional(readOnly = true)
    public List<CoachingLinkDto> all(String status) {
        String st = STATUSES.contains(status) ? status : null;
        return links.findAllWithUsers(st).stream().map(this::dto)
                .sorted(Comparator.comparingInt(CoachingServiceImpl::activeFirst).thenComparing(RECENT)).toList();
    }

    private User coach(Long id) {
        return users.findById(id == null ? -1 : id).filter(u -> u.getRole() == Role.COACH && u.isActive())
                .orElseThrow(() -> ApiException.notFound("Coach introuvable"));
    }

    private void upsert(User coach, User client, String status) {
        CoachClient l = links.findByCoachIdAndClientId(coach.getId(), client.getId()).orElseGet(CoachClient::new);
        l.setCoach(coach);
        l.setClient(client);
        l.setStatus(status);
        l.setUpdated(Instant.now());
        links.save(l);
    }

    @Override
    public void request(CurrentUser me, Long coachId) {
        AccessService.require(me.isMember());
        User c = coach(coachId);
        if (c.getId().equals(me.id())) throw ApiException.badRequest("Vous ne pouvez pas être votre propre coach");
        String cur = links.findByCoachIdAndClientId(c.getId(), me.id()).map(CoachClient::getStatus).orElse(null);
        if ("active".equals(cur)) throw ApiException.conflict(c.getName() + " est déjà votre coach");
        if ("pending".equals(cur)) throw ApiException.conflict("Demande déjà envoyée");
        upsert(c, users.getReferenceById(me.id()), "pending");
        notifications.notify(c.getId(), "Nouvelle demande de coaching", me.name() + " souhaite être suivi(e) par vous.");
    }

    @Override
    public void assign(Long coachId, Long clientId) {
        User c = coach(coachId), m = access.member(clientId);
        if (c.getId().equals(m.getId())) throw ApiException.badRequest("Un coach ne peut pas être son propre client");
        upsert(c, m, "active");
        notifications.notify(c.getId(), "Nouveau client", m.getName() + " vous a été attribué(e) par l’administration.");
        notifications.notify(m.getId(), "Coach attribué", c.getName() + " assure désormais votre suivi.");
    }

    @Override
    public void act(CurrentUser me, Long linkId, String action) {
        CoachClient l = links.findById(linkId).orElseThrow(() -> ApiException.notFound("Relation introuvable"));
        String coachName = l.getCoach().getName(), clientName = l.getClient().getName();
        Long coachId = l.getCoach().getId(), clientId = l.getClient().getId();
        if ("accept".equals(action) || "decline".equals(action)) {
            AccessService.require(me.isCoach() && me.id().equals(coachId));
            if (!"pending".equals(l.getStatus())) throw ApiException.conflict("Cette demande a déjà été traitée");
            boolean accept = "accept".equals(action);
            l.setStatus(accept ? "active" : "declined");
            l.setUpdated(Instant.now());
            notifications.notify(clientId, accept ? "Demande de coaching acceptée" : "Demande de coaching refusée",
                    coachName + " a " + (accept ? "accepté" : "décliné") + " votre demande.");
            return;
        }
        // Fin du suivi (ou annulation d'une demande) : le coach, le client ou l'admin
        AccessService.require(me.id().equals(coachId) || me.id().equals(clientId) || me.isAdmin());
        String was = l.getStatus();
        if (!"pending".equals(was) && !"active".equals(was)) throw ApiException.conflict("Relation déjà terminée");
        l.setStatus("ended");
        l.setUpdated(Instant.now());
        if ("active".equals(was)) {
            if (!me.id().equals(clientId)) notifications.notify(clientId, "Suivi coaching terminé", "Votre suivi avec " + coachName + " est terminé.");
            if (!me.id().equals(coachId)) notifications.notify(coachId, "Suivi coaching terminé", clientName + " n’est plus suivi(e) par vous.");
        }
    }

    @Override
    public void endAllFor(User coach, String reason) {
        for (CoachClient l : links.findForCoach(coach.getId(), List.of("pending", "active"))) {
            boolean wasActive = Objects.equals(l.getStatus(), "active");
            l.setStatus("ended");
            l.setUpdated(Instant.now());
            if (wasActive) notifications.notify(l.getClient().getId(), "Suivi coaching terminé", reason);
        }
    }
}
