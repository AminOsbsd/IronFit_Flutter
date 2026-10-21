package com.ironfit.service.impl;

import com.ironfit.dto.CommonDtos.IdResponse;
import com.ironfit.dto.UserDtos.*;
import com.ironfit.entity.Plan;
import com.ironfit.entity.Role;
import com.ironfit.entity.User;
import com.ironfit.exception.ApiException;
import com.ironfit.repository.ClassSessionRepository;
import com.ironfit.repository.CoachClientRepository;
import com.ironfit.repository.OffsetLimit;
import com.ironfit.repository.PlanRepository;
import com.ironfit.repository.UserRepository;
import com.ironfit.security.CurrentUser;
import com.ironfit.service.AccessService;
import com.ironfit.service.CoachingService;
import com.ironfit.service.MemberService;
import com.ironfit.service.Texts;
import java.util.List;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@Transactional
public class MemberServiceImpl implements MemberService {
    private final UserRepository users;
    private final PlanRepository plans;
    private final ClassSessionRepository classes;
    private final CoachClientRepository links;
    private final CoachingService coaching;
    private final AccessService access;
    private final PasswordEncoder encoder;

    public MemberServiceImpl(UserRepository users, PlanRepository plans, ClassSessionRepository classes, CoachClientRepository links,
                             CoachingService coaching, AccessService access, PasswordEncoder encoder) {
        this.users = users;
        this.plans = plans;
        this.classes = classes;
        this.links = links;
        this.coaching = coaching;
        this.access = access;
        this.encoder = encoder;
    }

    private static UserDto dto(User u) { return UserDto.of(u, u.getPlan() == null ? null : u.getPlan().getName()); }

    @Override
    @Transactional(readOnly = true)
    public List<UserDto> search(CurrentUser me, String q, String role, Boolean active, Integer limit, Integer offset) {
        AccessService.require(me.isAdmin() || me.isCoach());
        Role r = "athlete".equals(role) || "coach".equals(role) ? Role.from(role) : null;
        Long coachId = me.isAdmin() ? null : me.id(); // coach : uniquement ses clients actifs
        return users.search(AccessService.MEMBER_ROLES, r, active, Texts.like(q), coachId, OffsetLimit.of(offset, limit, 500))
                .stream().map(MemberServiceImpl::dto).toList();
    }

    @Override
    @Transactional(readOnly = true)
    public UserDto get(CurrentUser me, Long id) {
        User u = access.member(id);
        AccessService.require(access.canSeeMember(me, u.getId()));
        return dto(u);
    }

    /** Compte géré par l'admin : jamais un autre administrateur. */
    private User target(Long id) {
        User u = users.findById(id).orElseThrow(() -> ApiException.notFound("Utilisateur introuvable"));
        if (u.isAdmin()) throw ApiException.forbidden("Le compte administrateur ne se gère pas ici");
        return u;
    }

    private void apply(User u, MemberRequest req) {
        String login = req.login().trim(), email = req.email().trim();
        boolean taken = u.getId() == null
                ? users.existsByLoginIgnoreCase(login) || users.existsByEmailIgnoreCase(email)
                : users.existsByLoginIgnoreCaseAndIdNot(login, u.getId()) || users.existsByEmailIgnoreCaseAndIdNot(email, u.getId());
        if (taken) throw ApiException.conflict("Identifiant ou e-mail déjà utilisé");
        Plan plan = req.planId() == null ? null : plans.findById(req.planId()).orElseThrow(() -> ApiException.badRequest("Abonnement introuvable"));
        u.setName(req.name().trim());
        u.setLogin(login);
        u.setEmail(email);
        u.setPhone(Texts.clean(req.phone()));
        u.setPlan(plan);
        u.setSubEnd(req.subEnd());
        u.setSpecialty(Texts.clean(req.specialty()));
        if (Texts.clean(req.password()) != null) {
            u.setPasswordHash(encoder.encode(req.password()));
            u.setTokenVersion(u.getTokenVersion() + 1);
        }
    }

    @Override
    public IdResponse create(MemberRequest req) {
        if (Texts.clean(req.password()) == null) throw ApiException.badRequest("Mot de passe obligatoire");
        User u = new User();
        u.setRole(Texts.clean(req.role()) == null ? Role.ATHLETE : Role.from(req.role()));
        apply(u, req);
        return new IdResponse(users.save(u).getId());
    }

    @Override
    public void update(Long id, MemberRequest req) {
        User u = target(id);
        Role before = u.getRole();
        apply(u, req);
        if (Texts.clean(req.role()) != null) u.setRole(Role.from(req.role()));
        if (before == Role.COACH && u.getRole() == Role.ATHLETE) coaching.endAllFor(u, u.getName() + " n'est plus coach à la salle.");
    }

    @Override
    public StatusResponse setStatus(Long id, boolean active) {
        User u = target(id);
        u.setActive(active);
        if (!active) u.setTokenVersion(u.getTokenVersion() + 1); // la désactivation coupe immédiatement les sessions
        return new StatusResponse(true, active);
    }

    @Override
    public void delete(Long id) {
        User u = target(id);
        if (u.isCoach()) coaching.endAllFor(u, u.getName() + " a quitté la salle.");
        users.flush();
        users.delete(u); // données personnelles supprimées en cascade par la base (ON DELETE CASCADE / SET NULL)
    }

    @Override
    @Transactional(readOnly = true)
    public List<CoachSummaryDto> coaches() {
        return users.findByRoleAndActiveTrueOrderByNameAsc(Role.COACH).stream()
                .map(c -> new CoachSummaryDto(c.getId(), c.getName(), c.getSpecialty(), classes.countByCoachId(c.getId()),
                        links.countByCoachIdAndStatus(c.getId(), "active")))
                .toList();
    }
}
