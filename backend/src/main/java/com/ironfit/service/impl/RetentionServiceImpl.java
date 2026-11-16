package com.ironfit.service.impl;

import com.ironfit.dto.RiskDtos.RemindResponse;
import com.ironfit.dto.RiskDtos.RiskMemberDto;
import com.ironfit.entity.RetentionAlert;
import com.ironfit.entity.User;
import com.ironfit.exception.ApiException;
import com.ironfit.repository.*;
import com.ironfit.retention.ChurnScorer;
import com.ironfit.security.CurrentUser;
import com.ironfit.service.AccessService;
import com.ironfit.service.MailService;
import com.ironfit.service.NotificationService;
import com.ironfit.service.RetentionService;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.time.format.DateTimeFormatter;
import java.time.temporal.ChronoUnit;
import java.util.*;
import java.util.stream.Collectors;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@Transactional
public class RetentionServiceImpl implements RetentionService {
    private static final Logger log = LoggerFactory.getLogger(RetentionServiceImpl.class);
    private static final DateTimeFormatter FR = DateTimeFormatter.ofPattern("dd/MM/yyyy");
    /** Délai minimal entre deux relances automatiques d'un même membre. */
    static final int AUTO_COOLDOWN_DAYS = 7;
    /** Au-delà, un abonnement expiré n'est plus relancé automatiquement (le membre est considéré parti). */
    static final int WIN_BACK_DAYS = 30;
    private static final int WINDOW_DAYS = 28;

    private final UserRepository users;
    private final WorkoutRepository workouts;
    private final CheckinRepository checkins;
    private final CoachClientRepository links;
    private final RetentionAlertRepository alerts;
    private final PromoRepository promos;
    private final AccessService access;
    private final NotificationService notifications;
    private final MailService mail;

    public RetentionServiceImpl(UserRepository users, WorkoutRepository workouts, CheckinRepository checkins, CoachClientRepository links,
                                RetentionAlertRepository alerts, PromoRepository promos, AccessService access,
                                NotificationService notifications, MailService mail) {
        this.users = users;
        this.workouts = workouts;
        this.checkins = checkins;
        this.links = links;
        this.alerts = alerts;
        this.promos = promos;
        this.access = access;
        this.notifications = notifications;
        this.mail = mail;
    }

    // ------------------------------------------------------------------ consultation

    @Override
    @Transactional(readOnly = true)
    public List<RiskMemberDto> atRisk(CurrentUser me, boolean includeLow) {
        AccessService.require(me.isAdmin() || me.isCoach());
        List<User> members = me.isAdmin()
                ? users.findByRoleInAndActiveTrue(AccessService.MEMBER_ROLES)
                : users.findAllById(access.activeClientIdsOrNone(me.id())).stream().filter(User::isActive).filter(User::isMember).toList();
        return evaluate(members, LocalDate.now()).stream().filter(r -> includeLow || !"low".equals(r.level())).toList();
    }

    // ------------------------------------------------------------------ relance manuelle

    @Override
    public RemindResponse remind(CurrentUser me, Long memberId) {
        AccessService.require(me.isAdmin() || me.isCoach());
        User m = access.member(memberId);                                         // 404 si ce n'est pas un membre
        AccessService.require(me.isAdmin() || access.coaches(me.id(), memberId)); // 403 si ce n'est pas son client actif
        if (!m.isActive()) throw ApiException.badRequest("Ce compte est désactivé");
        LocalDate today = LocalDate.now();
        if (alerts.existsByMemberIdAndSentOn(memberId, today)) {
            throw ApiException.conflict("Une relance a déjà été envoyée aujourd'hui à " + m.getName());
        }
        String emailError = sendReminder(m, evaluate(List.of(m), today).get(0), today, me.isAdmin() ? "admin" : "coach");
        return new RemindResponse(true, emailError == null, emailError);
    }

    // ------------------------------------------------------------------ analyse automatique

    @Override
    public int runNightly() {
        LocalDate today = LocalDate.now();
        List<User> members = users.findByRoleInAndActiveTrue(AccessService.MEMBER_ROLES);
        Map<Long, User> byId = members.stream().collect(Collectors.toMap(User::getId, u -> u));
        List<RiskMemberDto> due = evaluate(members, today).stream().filter(r -> "high".equals(r.level()) && eligible(r, today)).toList();
        if (due.isEmpty()) return 0;

        Map<Long, List<Long>> coachesOf = new HashMap<>();
        for (Object[] row : links.activeCoachPairs(due.stream().map(RiskMemberDto::id).toList())) {
            coachesOf.computeIfAbsent((Long) row[0], k -> new ArrayList<>()).add((Long) row[1]);
        }
        for (RiskMemberDto r : due) {
            sendReminder(byId.get(r.id()), r, today, "auto");
            for (Long coachId : coachesOf.getOrDefault(r.id(), List.of())) {
                notifications.notify(coachId, "Membre à risque : " + r.name(),
                        "Score " + r.score() + "/100. " + String.join(" · ", r.reasons()));
            }
        }
        log.info("Rétention : {} relance(s) automatique(s) envoyée(s)", due.size());
        return due.size();
    }

    /** Relance automatique permise : abonnement valide ou expiré depuis peu, et pas de relance récente. */
    private static boolean eligible(RiskMemberDto r, LocalDate today) {
        if (r.subEnd() == null || r.subEnd().isBefore(today.minusDays(WIN_BACK_DAYS))) return false;
        return r.lastReminder() == null || ChronoUnit.DAYS.between(r.lastReminder(), today) >= AUTO_COOLDOWN_DAYS;
    }

    // ------------------------------------------------------------------ calcul pour un ensemble de membres

    private List<RiskMemberDto> evaluate(Collection<User> members, LocalDate today) {
        if (members.isEmpty()) return List.of();
        List<Long> ids = members.stream().map(User::getId).toList();
        LocalDate since = today.minusDays(WINDOW_DAYS);
        // 5 requêtes au total, quel que soit le nombre de membres (pas de N+1)
        Map<Long, LocalDate> lastWorkout = dates(workouts.lastDoneByUser(ids));
        Map<Long, LocalDate> lastCheckin = dates(checkins.lastByMember(ids));
        Map<Long, Long> recentWorkouts = counts(workouts.countSinceByUser(ids, since));
        Map<Long, Long> recentCheckins = counts(checkins.countSinceByMember(ids, since));
        Map<Long, LocalDate> lastReminder = dates(alerts.lastSentByMember(ids));

        List<RiskMemberDto> out = new ArrayList<>();
        for (User u : members) {
            LocalDate last = latest(lastWorkout.get(u.getId()), lastCheckin.get(u.getId()));
            int sessions = (int) (recentWorkouts.getOrDefault(u.getId(), 0L) + recentCheckins.getOrDefault(u.getId(), 0L));
            LocalDate createdOn = u.getCreated() == null ? null : LocalDate.ofInstant(u.getCreated(), ZoneOffset.UTC);
            ChurnScorer.Result r = ChurnScorer.score(new ChurnScorer.Input(today, last, sessions, u.getSubEnd(), createdOn));
            out.add(new RiskMemberDto(u.getId(), u.getName(), u.getLogin(), r.score(), r.level(), r.reasons(), last, r.daysInactive(),
                    sessions, u.getSubEnd(), lastReminder.get(u.getId())));
        }
        out.sort(Comparator.comparingInt(RiskMemberDto::score).reversed().thenComparing(RiskMemberDto::name, String.CASE_INSENSITIVE_ORDER));
        return out;
    }

    private static Map<Long, LocalDate> dates(List<Object[]> rows) {
        Map<Long, LocalDate> m = new HashMap<>();
        for (Object[] r : rows) m.put((Long) r[0], (LocalDate) r[1]);
        return m;
    }

    private static Map<Long, Long> counts(List<Object[]> rows) {
        Map<Long, Long> m = new HashMap<>();
        for (Object[] r : rows) m.put((Long) r[0], (Long) r[1]);
        return m;
    }

    private static LocalDate latest(LocalDate a, LocalDate b) {
        return a == null ? b : b == null ? a : (a.isAfter(b) ? a : b);
    }

    // ------------------------------------------------------------------ message

    /** Notification dans l'application + e-mail envoyé immédiatement. Renvoie null si l'e-mail est parti, sinon la raison. */
    private String sendReminder(User m, RiskMemberDto r, LocalDate today, String source) {
        String title = "On ne vous a pas vu depuis un moment";
        String body = reminderText(m, r, today);
        notifications.notify(m.getId(), title, body, false);   // cloche de l'application (l'e-mail est géré ci-dessous)
        String emailError = MailService.isRealAddress(m.getEmail())
                ? mail.sendNow(m.getEmail(), "IronFit - " + title, body + "\n\n-- \nL'équipe IronFit")
                : "adresse e-mail absente ou fictive (" + m.getEmail() + ") : modifiez-la dans le profil du membre";
        if (emailError != null) log.warn("Relance de {} : notification créée mais e-mail non envoyé ({})", m.getLogin(), emailError);
        alerts.save(new RetentionAlert(m, today, r.score(), source));
        return emailError;
    }

    private String reminderText(User m, RiskMemberDto r, LocalDate today) {
        String first = m.getName().trim().split("\\s+")[0];
        StringBuilder sb = new StringBuilder("Bonjour ").append(first).append(", ");
        if (r.lastActivity() == null) sb.append("nous n'avons pas encore enregistré de séance pour vous. ");
        else sb.append("votre dernière séance remonte à ").append(ChronoUnit.DAYS.between(r.lastActivity(), today)).append(" jours. ");
        sb.append("Reprenez en douceur : votre coach et l'équipe IronFit vous attendent.");
        if (r.subEnd() != null && !r.subEnd().isAfter(today.plusDays(14))) {
            sb.append(r.subEnd().isBefore(today) ? " Votre abonnement a pris fin le " : " Votre abonnement se termine le ")
                    .append(r.subEnd().format(FR)).append('.');
        }
        promos.findByUntilIsNullOrUntilGreaterThanEqualOrderByDiscountDesc(today, PageRequest.of(0, 1)).stream().findFirst().ifPresent(p ->
                sb.append(" Offre en cours : ").append(p.getTitle()).append(" (-").append(p.getDiscount()).append(" %)."));
        return sb.toString();
    }
}
