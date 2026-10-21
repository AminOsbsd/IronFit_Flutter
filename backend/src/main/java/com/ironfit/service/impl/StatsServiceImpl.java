package com.ironfit.service.impl;

import com.ironfit.entity.ClassSession;
import com.ironfit.entity.Payment;
import com.ironfit.entity.Role;
import com.ironfit.entity.User;
import com.ironfit.repository.*;
import com.ironfit.security.CurrentUser;
import com.ironfit.service.AccessService;
import com.ironfit.service.StatsService;
import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.YearMonth;
import java.util.*;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@Transactional(readOnly = true)
public class StatsServiceImpl implements StatsService {
    private final UserRepository users;
    private final SubscriptionRequestRepository requests;
    private final CoachClientRepository links;
    private final WorkoutRepository workouts;
    private final BookingRepository bookings;
    private final ProductRepository products;
    private final EquipmentRepository equipment;
    private final CheckinRepository checkins;
    private final PaymentRepository payments;
    private final ClassSessionRepository classes;
    private final ProgramRepository programs;
    private final AccessService access;

    public StatsServiceImpl(UserRepository users, SubscriptionRequestRepository requests, CoachClientRepository links, WorkoutRepository workouts,
                            BookingRepository bookings, ProductRepository products, EquipmentRepository equipment, CheckinRepository checkins,
                            PaymentRepository payments, ClassSessionRepository classes, ProgramRepository programs, AccessService access) {
        this.users = users;
        this.requests = requests;
        this.links = links;
        this.workouts = workouts;
        this.bookings = bookings;
        this.products = products;
        this.equipment = equipment;
        this.checkins = checkins;
        this.payments = payments;
        this.classes = classes;
        this.programs = programs;
        this.access = access;
    }

    @Override
    public Map<String, Object> stats(CurrentUser me) {
        AccessService.require(me.isAdmin() || me.isCoach());
        return me.isAdmin() ? admin() : coach(me);
    }

    private static Map<String, Object> sub(User u, boolean withPlan) {
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("id", u.getId());
        m.put("name", u.getName());
        m.put("sub_end", u.getSubEnd());
        if (withPlan) m.put("plan_id", u.planId());
        return m;
    }

    private List<Map<String, Object>> fill(List<ClassSession> list) {
        Map<Long, Long> taken = new HashMap<>();
        for (Object[] row : bookings.countPerClass()) taken.put((Long) row[0], (Long) row[1]);
        List<Map<String, Object>> out = new ArrayList<>();
        for (ClassSession c : list) {
            Map<String, Object> m = new LinkedHashMap<>();
            m.put("id", c.getId());
            m.put("title", c.getTitle());
            m.put("day", c.getDay());
            m.put("time", c.getTime());
            m.put("spots", c.getSpots());
            m.put("taken", taken.getOrDefault(c.getId(), 0L));
            out.add(m);
        }
        return out;
    }

    private List<Map<String, Object>> maintenance() {
        return equipment.findByStatusNot("OK").stream().map(e -> Map.<String, Object>of("id", e.getId(), "name", e.getName(), "status", e.getStatus())).toList();
    }

    private Map<String, Object> admin() {
        LocalDate t = LocalDate.now();
        Set<Role> m = AccessService.MEMBER_ROLES;
        Map<String, Object> s = new LinkedHashMap<>();
        s.put("athletes", users.countByRoleIn(m));
        s.put("coaches", users.countByRole(Role.COACH));
        s.put("active", users.countByRoleInAndSubEndGreaterThanEqual(m, t));
        s.put("expired", users.countAthletesWithoutSubscription(t));
        s.put("disabled", users.countByRoleInAndActiveFalse(m));
        s.put("expiring", users.findExpiring(m, t, t.plusDays(7)).stream().map(u -> sub(u, true)).toList());
        s.put("lapsed", users.findLapsed(m, t, OffsetLimit.first(10)).stream().map(u -> sub(u, true)).toList());
        s.put("pending", requests.countByStatus("pending"));
        s.put("coachings", links.countByStatus("active"));
        s.put("pending_coachings", links.countByStatus("pending"));
        s.put("workouts_7d", workouts.countByDoneOnGreaterThanEqual(t.minusDays(7)));
        s.put("bookings", bookings.count());
        s.put("low_stock", products.findByStockLessThanEqualOrderByStockAsc(5).stream()
                .map(p -> Map.<String, Object>of("id", p.getId(), "name", p.getName(), "stock", p.getStock())).toList());
        s.put("maintenance", maintenance());
        s.put("checkins_today", checkins.countByCheckinOn(t));
        s.put("revenue", revenue(t));
        List<Map<String, Object>> fill = new ArrayList<>(fill(classes.findAllWithCoach()));
        fill.sort(Comparator.comparingDouble((Map<String, Object> c) -> -((Long) c.get("taken")) / (double) Math.max((Integer) c.get("spots"), 1)));
        s.put("fill", fill.subList(0, Math.min(5, fill.size())));
        return s;
    }

    /** Revenus des 6 derniers mois (mois ayant au moins un paiement), du plus ancien au plus récent. */
    private List<Map<String, Object>> revenue(LocalDate today) {
        TreeMap<YearMonth, BigDecimal> byMonth = new TreeMap<>();
        for (Payment p : payments.findByPaidOnGreaterThanEqual(YearMonth.from(today).minusMonths(5).atDay(1))) {
            byMonth.merge(YearMonth.from(p.getPaidOn()), p.getAmount(), BigDecimal::add);
        }
        return byMonth.entrySet().stream().map(e -> Map.<String, Object>of("m", e.getKey().toString(), "total", e.getValue())).toList();
    }

    private Map<String, Object> coach(CurrentUser me) {
        LocalDate t = LocalDate.now();
        List<Long> clients = access.activeClientIdsOrNone(me.id());
        Map<String, Object> s = new LinkedHashMap<>();
        s.put("clients", links.countByCoachIdAndStatus(me.id(), "active"));
        s.put("pending_clients", links.countByCoachIdAndStatus(me.id(), "pending"));
        s.put("programs", programs.countActiveForCoach(me.id()));
        s.put("workouts_7d", workouts.countForCoachSince(me.id(), t.minusDays(7), clients));
        s.put("to_review", workouts.countToReview(me.id(), clients));
        s.put("expiring", users.findExpiringAmong(clients, t, t.plusDays(7)).stream().map(u -> sub(u, false)).toList());
        s.put("maintenance", maintenance());
        s.put("fill", fill(classes.findByCoach(me.id())));
        return s;
    }
}
