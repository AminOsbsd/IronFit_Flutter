package com.ironfit.service.impl;

import com.ironfit.dto.CommonDtos.IdResponse;
import com.ironfit.dto.SubscriptionDtos.RequestDto;
import com.ironfit.entity.Payment;
import com.ironfit.entity.Plan;
import com.ironfit.entity.SubscriptionRequest;
import com.ironfit.entity.User;
import com.ironfit.exception.ApiException;
import com.ironfit.repository.PaymentRepository;
import com.ironfit.repository.PlanRepository;
import com.ironfit.repository.SubscriptionRequestRepository;
import com.ironfit.repository.UserRepository;
import com.ironfit.security.CurrentUser;
import com.ironfit.service.AccessService;
import com.ironfit.service.NotificationService;
import com.ironfit.service.SubscriptionService;
import java.time.LocalDate;
import java.util.List;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@Transactional
public class SubscriptionServiceImpl implements SubscriptionService {
    private static final Set<String> METHODS = Set.of("Espèces", "Carte", "Virement", "Chèque");
    private static final Pattern MONTHS = Pattern.compile("(\\d+)\\s*mois", Pattern.CASE_INSENSITIVE);
    private static final Pattern DAYS = Pattern.compile("(\\d+)\\s*j", Pattern.CASE_INSENSITIVE);
    private static final Pattern ONE_SHOT = Pattern.compile("entr|séance", Pattern.CASE_INSENSITIVE);

    private final SubscriptionRequestRepository requests;
    private final PlanRepository plans;
    private final UserRepository users;
    private final PaymentRepository payments;
    private final NotificationService notifications;

    public SubscriptionServiceImpl(SubscriptionRequestRepository requests, PlanRepository plans, UserRepository users,
                                   PaymentRepository payments, NotificationService notifications) {
        this.requests = requests;
        this.plans = plans;
        this.users = users;
        this.payments = payments;
        this.notifications = notifications;
    }

    /** Nouvelle date de fin : à partir de la fin actuelle si elle est future, sinon d'aujourd'hui. */
    static LocalDate extend(LocalDate from, String duration, LocalDate today) {
        LocalDate d = from != null && from.isAfter(today) ? from : today;
        String s = duration == null ? "" : duration;
        Matcher mo = MONTHS.matcher(s), j = DAYS.matcher(s);
        if (mo.find()) return d.plusMonths(Long.parseLong(mo.group(1)));
        if (j.find()) return d.plusDays(Long.parseLong(j.group(1)));
        return d.plusDays(ONE_SHOT.matcher(s).find() ? 1 : 30);
    }

    /** Active / prolonge l'abonnement d'un membre (athlète ou coach) et enregistre le paiement correspondant. */
    private void activate(Long userId, Long planId, String method) {
        Plan p = planId == null ? null : plans.findById(planId).orElse(null);
        User u = userId == null ? null : users.findByIdAndRoleIn(userId, AccessService.MEMBER_ROLES).orElse(null);
        if (p == null || u == null) throw ApiException.notFound("Membre ou tarif introuvable");
        LocalDate end = extend(u.getSubEnd(), p.getDuration(), LocalDate.now());
        u.setPlan(p);
        u.setSubEnd(end);
        Payment pay = new Payment();
        pay.setMember(u);
        pay.setAmount(p.getPrice());
        pay.setMethod(METHODS.contains(method) ? method : "Espèces");
        pay.setPaidOn(LocalDate.now());
        pay.setNote("Abonnement " + p.getName());
        payments.save(pay);
        notifications.notify(u.getId(), "Abonnement activé", p.getName() + " — valable jusqu’au " + end + ".");
    }

    @Override
    @Transactional(readOnly = true)
    public List<RequestDto> list(CurrentUser me) {
        if (!me.isAdmin()) return requests.findForMember(me.id()).stream().map(r -> RequestDto.of(r, false)).toList();
        return requests.findPending().stream().map(r -> RequestDto.of(r, true)).toList();
    }

    @Override
    public IdResponse create(CurrentUser me, Long planId) {
        AccessService.require(me.isMember());
        Plan p = planId == null ? null : plans.findById(planId).orElse(null);
        if (p == null) throw ApiException.notFound("Tarif introuvable");
        if (requests.existsByMemberIdAndStatus(me.id(), "pending")) throw ApiException.conflict("Vous avez déjà une demande en attente");
        SubscriptionRequest r = new SubscriptionRequest();
        r.setMember(users.getReferenceById(me.id()));
        r.setPlan(p);
        return new IdResponse(requests.save(r).getId());
    }

    @Override
    public void act(CurrentUser me, Long requestId, String action, String method) {
        SubscriptionRequest r = requests.findById(requestId).filter(x -> "pending".equals(x.getStatus()))
                .orElseThrow(() -> ApiException.notFound("Demande introuvable"));
        if ("cancel".equals(action)) {
            AccessService.require(me.id().equals(r.getMember().getId()));
            r.setStatus("cancelled");
            return;
        }
        AccessService.require(me.isAdmin());
        if ("approve".equals(action)) {
            activate(r.getMember().getId(), r.getPlan().getId(), method);
            r.setStatus("approved");
        } else {
            notifications.notify(r.getMember().getId(), "Demande d’abonnement refusée", "Rapprochez-vous de l’accueil pour plus d’informations.");
            r.setStatus("rejected");
        }
    }

    @Override
    public void renew(Long memberId, Long planId, String method) { activate(memberId, planId, method); }
}
