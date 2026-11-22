package com.ironfit.service.impl;

import static com.ironfit.ai.CoachPrompt.clip;

import com.ironfit.ai.CoachPrompt;
import com.ironfit.ai.KnowledgeBase;
import com.ironfit.ai.CoachPrompt.Mode;
import com.ironfit.ai.OpenRouterClient.Message;
import com.ironfit.dto.AiCoachDtos;
import com.ironfit.dto.AiCoachDtos.ChatMessage;
import com.ironfit.dto.AiCoachDtos.ChatRequest;
import com.ironfit.entity.*;
import com.ironfit.exception.ApiException;
import com.ironfit.repository.*;
import com.ironfit.security.CurrentUser;
import com.ironfit.service.AccessService;
import com.ironfit.service.AiCoachService;
import java.time.LocalDate;
import java.time.temporal.ChronoUnit;
import java.util.*;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class AiCoachServiceImpl implements AiCoachService {
    private static final String[] DAYS = {"Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"};
    private static final int WINDOW_DAYS = 28;

    private final UserRepository users;
    private final ProgramRepository programs;
    private final ExerciseRepository exercises;
    private final WorkoutRepository workouts;
    private final MeasureRepository measures;
    private final CheckinRepository checkins;
    private final DatedBookingRepository bookings;
    private final ClassSessionRepository classes;
    private final CoachClientRepository links;
    private final PlanRepository plans;
    private final PromoRepository promos;
    private final KnowledgeBase knowledge;

    public AiCoachServiceImpl(UserRepository users, ProgramRepository programs, ExerciseRepository exercises, WorkoutRepository workouts,
                              MeasureRepository measures, CheckinRepository checkins, DatedBookingRepository bookings,
                              ClassSessionRepository classes, CoachClientRepository links, PlanRepository plans,
                              PromoRepository promos, KnowledgeBase knowledge) {
        this.users = users;
        this.programs = programs;
        this.exercises = exercises;
        this.workouts = workouts;
        this.measures = measures;
        this.checkins = checkins;
        this.bookings = bookings;
        this.classes = classes;
        this.links = links;
        this.plans = plans;
        this.promos = promos;
        this.knowledge = knowledge;
    }

    @Override
    @Transactional(readOnly = true)
    public List<Message> prepare(CurrentUser me, ChatRequest request) {
        List<ChatMessage> history = request.messages();
        ChatMessage last = history.get(history.size() - 1);
        if (!"user".equals(last.role())) throw ApiException.badRequest("Le dernier message doit venir de l'utilisateur");
        for (ChatMessage m : history) {
            if ("user".equals(m.role()) && m.content().length() > AiCoachDtos.MAX_MESSAGE_CHARS) {
                throw ApiException.badRequest("Message trop long (" + AiCoachDtos.MAX_MESSAGE_CHARS + " caractères max.)");
            }
        }

        User u = users.findById(me.id()).orElseThrow(() -> ApiException.unauthorized("Session expirée"));
        LocalDate today = LocalDate.now();
        Mode mode = me.isAdmin() ? Mode.ADMIN : (me.isCoach() && "coach".equals(request.workspace()) ? Mode.COACH : Mode.MEMBER);
        List<String> facts = switch (mode) {
            case ADMIN -> adminFacts(today);
            case COACH -> coachFacts(u, today);
            case MEMBER -> memberFacts(u, today);
        };

        List<Message> out = new ArrayList<>();
        out.add(new Message("system", CoachPrompt.system(mode, firstName(u.getName()), today, knowledge.text(), gymFacts(today), facts)));
        out.addAll(recent(history));
        return out;
    }

    /** Les messages les plus récents qui tiennent dans le budget de caractères (le dernier est toujours gardé). */
    static List<Message> recent(List<ChatMessage> history) {
        Deque<Message> kept = new ArrayDeque<>();
        int total = 0;
        for (int i = history.size() - 1; i >= 0; i--) {
            ChatMessage m = history.get(i);
            total += m.content().length();
            if (total > AiCoachDtos.MAX_HISTORY_CHARS && !kept.isEmpty()) break;
            kept.addFirst(new Message(m.role(), m.content().trim()));
        }
        return new ArrayList<>(kept);
    }

    // ------------------------------------------------------------------ données de la salle (identiques pour tous)

    /** Formules, planning hebdomadaire, offres en cours et coachs : ce que tout membre voit déjà dans l'application. */
    List<String> gymFacts(LocalDate today) {
        List<String> f = new ArrayList<>();
        List<Plan> allPlans = plans.search(null, PageRequest.of(0, 20));
        if (allPlans.isEmpty()) f.add("Subscription plans: none listed");
        for (Plan p : allPlans) {
            f.add("Plan \"" + clip(p.getName(), 60) + "\": " + money(p.getPrice()) + " " + p.getCurrency()
                    + (p.getDuration() == null || p.getDuration().isBlank() ? "" : " for " + clip(p.getDuration(), 40))
                    + (p.getDescr() == null || p.getDescr().isBlank() ? "" : " (" + clip(p.getDescr(), 120) + ")"));
        }

        List<ClassSession> week = classes.findAllWithCoach().stream().limit(40).toList();
        if (week.isEmpty()) f.add("Weekly group classes: none scheduled");
        else {
            StringJoiner j = new StringJoiner("; ");
            for (ClassSession c : week) {
                j.add(day(c.getDay()) + " " + c.getTime() + " " + clip(c.getTitle(), 50)
                        + (c.getCoach() == null ? "" : " with " + firstName(c.getCoach().getName()))
                        + (c.getSpots() == null ? "" : " (max capacity " + c.getSpots() + " people)"));
            }
            f.add("Weekly group class schedule (repeats every week, book in the \"Planning\" tab): " + j);
        }

        List<Promo> offers = promos.findByUntilIsNullOrUntilGreaterThanEqualOrderByDiscountDesc(today, PageRequest.of(0, 10));
        for (Promo p : offers) {
            f.add("Current offer \"" + clip(p.getTitle(), 60) + "\""
                    + (p.getDiscount() == null ? "" : p.getDiscount() >= 100 ? ": FREE (100 % off)" : ": " + p.getDiscount() + " % off")
                    + (p.getDescr() == null || p.getDescr().isBlank() ? "" : " (" + clip(p.getDescr(), 120) + ")")
                    + (p.getUntil() == null ? "" : ", valid until " + p.getUntil()));
        }
        if (offers.isEmpty()) f.add("Current offers: none");

        List<User> staff = users.findByRoleAndActiveTrueOrderByNameAsc(Role.COACH);
        if (!staff.isEmpty()) {
            StringJoiner j = new StringJoiner(", ");
            staff.stream().limit(30).forEach(c -> j.add(firstName(c.getName()) + (c.getSpecialty() == null || c.getSpecialty().isBlank() ? "" : " (" + clip(c.getSpecialty(), 50) + ")")));
            f.add("Coaches (members can request one in \"Explorer\" > Coachs): " + j);
        }
        return f;
    }

    private static String money(java.math.BigDecimal v) {
        return v == null ? "?" : v.stripTrailingZeros().toPlainString();
    }

    // ------------------------------------------------------------------ membre (ou coach dans « Mon entraînement »)

    private List<String> memberFacts(User u, LocalDate today) {
        List<String> f = new ArrayList<>();
        Long id = u.getId();
        f.add("Role: " + (u.isCoach() ? "coach, currently looking at their own personal training" : "gym member"));

        String plan = u.getPlan() == null ? null : u.getPlan().getName();
        if (u.getSubEnd() == null) f.add("Subscription: none yet (needed to book classes; see the \"Explorer\" tab for plans)");
        else if (u.getSubEnd().isBefore(today)) f.add("Subscription: expired on " + u.getSubEnd() + (plan == null ? "" : " (plan: " + plan + ")"));
        else f.add("Subscription: active until " + u.getSubEnd() + (plan == null ? "" : " (plan: " + plan + ")"));

        List<String> coaches = links.findForClient(id).stream()
                .filter(cc -> "active".equals(cc.getStatus()))
                .map(cc -> firstName(cc.getCoach().getName()) + (cc.getCoach().getSpecialty() == null ? "" : " (" + clip(cc.getCoach().getSpecialty(), 60) + ")"))
                .toList();
        f.add(coaches.isEmpty() ? "Personal coach: none (they can request one from the \"Explorer\" tab > Coachs)" : "Personal coach: " + String.join(", ", coaches));

        // Programmes actifs et leurs exercices
        List<Program> active = programs.findPersonal(id).stream().filter(Program::isActive).limit(3).toList();
        if (active.isEmpty()) f.add("Active training programs: none");
        for (Program p : active) {
            StringBuilder sb = new StringBuilder("Active program \"").append(clip(p.getTitle(), 80)).append('"');
            sb.append(p.getCoach() == null ? " (personal)" : " (written by coach " + firstName(p.getCoach().getName()) + ")");
            if (p.getGoal() != null && !p.getGoal().isBlank()) sb.append(", goal: ").append(clip(p.getGoal(), 120));
            if (p.getNotes() != null && !p.getNotes().isBlank()) sb.append(", notes: ").append(clip(p.getNotes(), 200));
            List<Exercise> items = exercises.findForProgram(p.getId());
            if (!items.isEmpty()) {
                sb.append(". Exercises: ");
                StringJoiner j = new StringJoiner("; ");
                items.stream().limit(15).forEach(e -> j.add(exercise(e)));
                sb.append(j);
                if (items.size() > 15) sb.append("; … (").append(items.size() - 15).append(" more)");
            }
            f.add(sb.toString());
        }

        // Séances réalisées
        List<Workout> recentWorkouts = workouts.findForUser(id, null, null, PageRequest.of(0, 8));
        long sessions28 = countFor(workouts.countSinceByUser(List.of(id), today.minusDays(WINDOW_DAYS)));
        long checkins28 = countFor(checkins.countSinceByMember(List.of(id), today.minusDays(WINDOW_DAYS)));
        f.add("Logged workouts in the last " + WINDOW_DAYS + " days: " + sessions28 + "; class check-ins in the last " + WINDOW_DAYS + " days: " + checkins28);
        if (recentWorkouts.isEmpty()) f.add("Workout log: no session logged yet");
        else {
            LocalDate lastDone = recentWorkouts.get(0).getDoneOn();
            f.add("Last logged workout: " + lastDone + " (" + ChronoUnit.DAYS.between(lastDone, today) + " days ago)");
            for (Workout w : recentWorkouts) f.add("Workout " + workout(w));
            f.add(workoutSummary(recentWorkouts));
        }

        // Mesures
        List<Measure> ms = measures.search(false, List.of(id), null, PageRequest.of(0, 6));
        if (ms.isEmpty()) f.add("Body measurements: none recorded (\"Mon espace\" > \"Ma progression\")");
        for (Measure m : ms) {
            StringBuilder sb = new StringBuilder("Measurement ").append(m.getMeasuredOn() == null ? "(no date)" : m.getMeasuredOn()).append(':');
            if (m.getWeight() != null) sb.append(" weight ").append(num(m.getWeight())).append(" kg");
            if (m.getBodyFat() != null) sb.append(", body fat ").append(num(m.getBodyFat())).append(" %");
            if (m.getNote() != null && !m.getNote().isBlank()) sb.append(", note: ").append(clip(m.getNote(), 100));
            f.add(sb.toString());
        }
        String trend = measureTrend(ms);
        if (trend != null) f.add(trend);

        // Cours réservés
        var booked = bookings.findTop10ByUserIdAndSessionDateGreaterThanEqualOrderBySessionDateAsc(id, today);
        if (booked.isEmpty()) f.add("Booked dated classes: none");
        else {
            StringJoiner j = new StringJoiner(", ");
            for (var booking : booked) {
                var c = booking.getClassSession();
                j.add(clip(c.getTitle(), 60) + " on " + booking.getSessionDate() + " at " + c.getTime());
            }
            f.add("Booked dated classes: " + j);
        }
        return f;
    }

    // ------------------------------------------------------------------ coach (espace coach) : agrégats uniquement

    private List<String> coachFacts(User u, LocalDate today) {
        List<String> f = new ArrayList<>();
        Long id = u.getId();
        f.add("Role: coach" + (u.getSpecialty() == null ? "" : ", specialty: " + clip(u.getSpecialty(), 60)));
        List<Long> clients = links.activeClientIds(id);
        f.add("Active clients: " + clients.size());
        f.add("Pending coaching requests: " + links.countByCoachIdAndStatus(id, "pending"));
        f.add("Active programs written for clients: " + programs.countActiveForCoach(id));
        if (!clients.isEmpty()) {
            f.add("Client sessions logged on this coach's programs in the last 7 days: " + workouts.countForCoachSince(id, today.minusDays(7), clients));
            f.add("Client sessions waiting for the coach's comment: " + workouts.countToReview(id, clients));
        }
        f.add("Weekly group classes taught: " + classes.countByCoachId(id));
        return f;
    }

    // ------------------------------------------------------------------ administrateur : agrégats de la salle

    private List<String> adminFacts(LocalDate today) {
        List<String> f = new ArrayList<>();
        f.add("Role: gym administrator");
        f.add("Members (athletes and coaches): " + users.countByRoleIn(AccessService.MEMBER_ROLES) + ", of which coaches: " + users.countByRole(Role.COACH));
        f.add("Members with an active subscription: " + users.countByRoleInAndSubEndGreaterThanEqual(AccessService.MEMBER_ROLES, today));
        f.add("Subscriptions expiring within 7 days: " + users.findExpiring(AccessService.MEMBER_ROLES, today, today.plusDays(7)).size());
        f.add("Pending coaching requests: " + links.countByStatus("pending") + "; active coaching relationships: " + links.countByStatus("active"));
        f.add("Workouts logged in the last 7 days (whole gym): " + workouts.countByDoneOnGreaterThanEqual(today.minusDays(7)));
        f.add("Check-ins today: " + checkins.countByCheckinOn(today));
        f.add("Weekly group classes scheduled: " + classes.count());
        return f;
    }

    // ------------------------------------------------------------------ mise en forme

    private static String exercise(Exercise e) {
        StringBuilder sb = new StringBuilder();
        if (e.getDay() != null && !e.getDay().isBlank()) sb.append('[').append(clip(e.getDay(), 20)).append("] ");
        sb.append(clip(e.getName(), 60));
        if (e.getSets() != null || e.getReps() != null) sb.append(' ').append(e.getSets() == null ? "?" : e.getSets()).append('x').append(e.getReps() == null ? "?" : clip(e.getReps(), 20));
        if (e.getLoad() != null && !e.getLoad().isBlank()) sb.append(" @ ").append(clip(e.getLoad(), 20));
        if (e.getRest() != null && !e.getRest().isBlank()) sb.append(", rest ").append(clip(e.getRest(), 20));
        return sb.toString();
    }

    private static String workout(Workout w) {
        StringBuilder sb = new StringBuilder().append(w.getDoneOn());
        if (w.getProgram() != null) sb.append(", program \"").append(clip(w.getProgram().getTitle(), 60)).append('"');
        if (w.getDuration() != null) sb.append(", ").append(w.getDuration()).append(" min");
        if (w.getRpe() != null) sb.append(", RPE ").append(w.getRpe());
        if (w.getNotes() != null && !w.getNotes().isBlank()) sb.append(", member notes: ").append(clip(w.getNotes(), 150));
        if (w.getCoachComment() != null && !w.getCoachComment().isBlank()) sb.append(", coach comment: ").append(clip(w.getCoachComment(), 150));
        return sb.toString();
    }

    /**
     * Calculs faits côté serveur : les petits modèles se trompent en additionnant des listes
     * (vérifié : écarts de poids et nombre de séances difficiles faux sans ce résumé).
     */
    static String workoutSummary(List<Workout> ws) {
        List<Integer> rpes = ws.stream().map(Workout::getRpe).filter(Objects::nonNull).toList();
        List<Integer> minutes = ws.stream().map(Workout::getDuration).filter(Objects::nonNull).toList();
        StringBuilder sb = new StringBuilder("PRE-COMPUTED summary of the ").append(ws.size()).append(" workouts listed above (use these numbers as is): ");
        sb.append("from ").append(ws.get(ws.size() - 1).getDoneOn()).append(" to ").append(ws.get(0).getDoneOn());
        if (!rpes.isEmpty()) {
            sb.append(", average RPE ").append(String.format(Locale.ROOT, "%.1f", rpes.stream().mapToInt(Integer::intValue).average().orElse(0)));
            sb.append(", sessions at RPE 8 or more: ").append(rpes.stream().filter(r -> r >= 8).count());
        }
        if (!minutes.isEmpty()) sb.append(", average duration ").append(Math.round(minutes.stream().mapToInt(Integer::intValue).average().orElse(0))).append(" min");
        return sb.toString();
    }

    /** Évolution entre la plus ancienne et la plus récente mesure renseignée (poids, masse grasse). null si moins de 2 mesures. */
    static String measureTrend(List<Measure> ms) {
        List<Measure> dated = ms.stream().filter(m -> m.getMeasuredOn() != null).sorted(Comparator.comparing(Measure::getMeasuredOn)).toList();
        List<String> parts = new ArrayList<>();
        List<Measure> w = dated.stream().filter(m -> m.getWeight() != null).toList();
        if (w.size() >= 2) {
            Measure a = w.get(0), b = w.get(w.size() - 1);
            parts.add("weight " + num(a.getWeight()) + " kg on " + a.getMeasuredOn() + " -> " + num(b.getWeight()) + " kg on " + b.getMeasuredOn()
                    + " (change " + signed(b.getWeight() - a.getWeight()) + " kg)");
        }
        List<Measure> bf = dated.stream().filter(m -> m.getBodyFat() != null).toList();
        if (bf.size() >= 2) {
            Measure a = bf.get(0), b = bf.get(bf.size() - 1);
            parts.add("body fat " + num(a.getBodyFat()) + " % -> " + num(b.getBodyFat()) + " % (change " + signed(b.getBodyFat() - a.getBodyFat()) + " points)");
        }
        return parts.isEmpty() ? null : "PRE-COMPUTED measurement trend (use these numbers as is): " + String.join("; ", parts);
    }

    private static String signed(double v) {
        double r = Math.round(v * 10) / 10.0;
        return (r > 0 ? "+" : "") + num(r);
    }

    private static long countFor(List<Object[]> rows) {
        return rows.isEmpty() ? 0 : ((Number) rows.get(0)[1]).longValue();
    }

    private static String day(Integer d) { return d == null || d < 0 || d > 6 ? "?" : DAYS[d]; }

    private static String num(Double v) { return v == Math.rint(v) ? String.valueOf(v.longValue()) : String.valueOf(v); }

    static String firstName(String name) {
        if (name == null || name.isBlank()) return "";
        return name.trim().split("\\s+")[0];
    }
}
