package com.ironfit.config;

import com.ironfit.entity.*;
import com.ironfit.repository.*;
import java.math.BigDecimal;
import java.time.LocalDate;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

/**
 * Base vide au démarrage : crée le compte « admin » (ADMIN_PASSWORD) et, si SEED_DEMO=true, des données de démonstration.
 * Ne fait rien si au moins un utilisateur existe (données importées ou déjà saisies).
 */
@Component
public class DataInitializer implements ApplicationRunner {
    private static final Logger log = LoggerFactory.getLogger(DataInitializer.class);

    private final AppProperties props;
    private final PasswordEncoder encoder;
    private final UserRepository users;
    private final PlanRepository plans;
    private final PromoRepository promos;
    private final ClassSessionRepository classes;
    private final PaymentRepository payments;
    private final EquipmentRepository equipment;
    private final ProductRepository products;
    private final AnnouncementRepository announcements;
    private final MeasureRepository measures;
    private final CheckinRepository checkins;
    private final CoachClientRepository links;
    private final ProgramRepository programs;
    private final ExerciseRepository exercises;
    private final WorkoutRepository workouts;
    private final NotificationRepository notifications;

    public DataInitializer(AppProperties props, PasswordEncoder encoder, UserRepository users, PlanRepository plans, PromoRepository promos,
                           ClassSessionRepository classes, PaymentRepository payments, EquipmentRepository equipment, ProductRepository products,
                           AnnouncementRepository announcements, MeasureRepository measures, CheckinRepository checkins, CoachClientRepository links,
                           ProgramRepository programs, ExerciseRepository exercises, WorkoutRepository workouts, NotificationRepository notifications) {
        this.props = props;
        this.encoder = encoder;
        this.users = users;
        this.plans = plans;
        this.promos = promos;
        this.classes = classes;
        this.payments = payments;
        this.equipment = equipment;
        this.products = products;
        this.announcements = announcements;
        this.measures = measures;
        this.checkins = checkins;
        this.links = links;
        this.programs = programs;
        this.exercises = exercises;
        this.workouts = workouts;
        this.notifications = notifications;
    }

    @Override
    @Transactional
    public void run(ApplicationArguments args) {
        if (users.count() > 0) return;
        if (props.adminPassword() == null || props.adminPassword().isBlank()) {
            throw new IllegalStateException("Base vide : définissez ADMIN_PASSWORD pour créer le compte administrateur");
        }
        User admin = user("Administrateur", "admin", Role.ADMIN, props.adminPassword(), null, null, null);
        if (props.seedDemo()) seedDemo(admin);
        log.info("Base initialisée{}", props.seedDemo() ? " avec les données de démonstration" : " (compte admin uniquement)");
    }

    private User user(String name, String login, Role role, String password, Plan plan, LocalDate subEnd, String specialty) {
        User u = new User();
        u.setName(name);
        u.setLogin(login);
        u.setEmail(login + "@ironfit.local");
        u.setRole(role);
        u.setPasswordHash(encoder.encode(password));
        u.setPlan(plan);
        u.setSubEnd(subEnd);
        u.setSpecialty(specialty);
        return users.save(u);
    }

    private Plan plan(String name, int price, String duration, String descr) {
        Plan p = new Plan();
        p.setName(name);
        p.setPrice(BigDecimal.valueOf(price));
        p.setDuration(duration);
        p.setDescr(descr);
        return plans.save(p);
    }

    private void seedDemo(User admin) {
        LocalDate t = LocalDate.now();
        plan("Séance", 10, "1 entrée", "Accès salle pour une journée");
        Plan monthly = plan("Mensuel", 60, "1 mois", "Salle + cours collectifs illimités");
        Plan quarterly = plan("Trimestriel", 160, "3 mois", "Salle + cours + bilan coach");
        plan("Annuel", 550, "12 mois", "Tout inclus + coaching mensuel");

        User sami = user("Sami Ben Ali", "sami", Role.COACH, "1234", null, null, "Musculation");
        // Leila est coach ET membre : elle a son propre abonnement et s'entraîne avec Sami
        User leila = user("Leila Trabelsi", "leila", Role.COACH, "1234", monthly, t.plusDays(45), "Yoga & Pilates");
        User youssef = user("Youssef Karray", "youssef", Role.ATHLETE, "1234", monthly, t.plusDays(100), null);
        User amira = user("Amira Jlassi", "amira", Role.ATHLETE, "1234", quarterly, t.plusDays(5), null);

        Object[][] cls = {{0, "18:00", "Musculation", sami, 15}, {1, "19:00", "Yoga", leila, 12}, {2, "18:30", "CrossFit", sami, 10},
                {3, "19:00", "Pilates", leila, 12}, {4, "17:00", "Cardio HIIT", sami, 20}, {5, "10:00", "Stretching", leila, 15}};
        for (Object[] c : cls) {
            ClassSession s = new ClassSession();
            s.setDay((Integer) c[0]);
            s.setTime((String) c[1]);
            s.setTitle((String) c[2]);
            s.setCoach((User) c[3]);
            s.setSpots((Integer) c[4]);
            classes.save(s);
        }

        promo("Rentrée sportive", "Sur l’abonnement trimestriel", 20, t.plusDays(30));
        promo("Amenez un ami", "Une séance offerte pour vous deux", 100, t.plusDays(75));

        payment(youssef, 60, "Espèces", t.minusDays(30), "Abonnement Mensuel");
        payment(amira, 160, "Carte", t.minusDays(85), "Abonnement Trimestriel");
        payment(leila, 60, "Carte", t.minusDays(15), "Abonnement Mensuel");

        for (Object[] e : new Object[][]{{"Tapis de course", "Cardio", 6, "OK"}, {"Banc de musculation", "Musculation", 8, "OK"}, {"Vélo elliptique", "Cardio", 4, "Maintenance"}}) {
            Equipment x = new Equipment();
            x.setName((String) e[0]);
            x.setCategory((String) e[1]);
            x.setQty((Integer) e[2]);
            x.setStatus((String) e[3]);
            equipment.save(x);
        }
        for (Object[] p : new Object[][]{{"Whey protéine 1kg", "Nutrition", 75, 20}, {"Gourde 750ml", "Accessoires", 12, 40}, {"Serviette sport", "Accessoires", 8, 3}}) {
            Product x = new Product();
            x.setName((String) p[0]);
            x.setCategory((String) p[1]);
            x.setPrice(BigDecimal.valueOf((Integer) p[2]));
            x.setStock((Integer) p[3]);
            products.save(x);
        }

        Announcement a = new Announcement();
        a.setTitle("Nouveaux horaires du week-end");
        a.setBody("La salle ouvre à 8h le samedi et le dimanche. Bon entraînement !");
        a.setPostedOn(t.minusDays(7));
        a.setAuthor(admin);
        announcements.save(a);

        measure(youssef, t.minusDays(28), 82.5, 19.5, "Début du programme");
        measure(youssef, t.minusDays(14), 81.4, 18.9, "Bilan 2 semaines");
        measure(youssef, t.minusDays(1), 80.6, 18.2, "Bilan mensuel");
        measure(leila, t.minusDays(10), 58.2, 21.0, "Bilan personnel");

        Checkin k = new Checkin();
        k.setMember(youssef);
        k.setCheckinOn(t.minusDays(3));
        k.setNote("Musculation");
        checkins.save(k);

        // Coaching : Sami suit Youssef et Leila ; Amira a une demande en attente auprès de Sami
        link(sami, youssef, "active");
        link(sami, leila, "active");
        link(sami, amira, "pending");

        Program prog = program(youssef, sami, "Prise de force — 4 semaines", "Force", "Échauffement 10 min avant chaque séance.");
        Object[][] ex = {{"A", "Squat", 4, "6-8", "70 kg", "2 min"}, {"A", "Développé couché", 4, "6-8", "60 kg", "2 min"},
                {"B", "Soulevé de terre", 3, "5", "90 kg", "3 min"}, {"B", "Tractions", 3, "max", null, "90 s"}};
        for (int i = 0; i < ex.length; i++) exercise(prog, (String) ex[i][0], (String) ex[i][1], (Integer) ex[i][2], (String) ex[i][3], (String) ex[i][4], (String) ex[i][5], i);

        Workout w = new Workout();
        w.setUser(youssef);
        w.setProgram(prog);
        w.setDoneOn(t.minusDays(2));
        w.setDuration(65);
        w.setRpe(7);
        w.setNotes("Séance A, bonnes sensations");
        w.setCoachComment("Bravo ! On augmente le squat de 2,5 kg la prochaine fois.");
        workouts.save(w);

        Program perso = program(leila, null, "Mobilité du matin", "Souplesse", null);
        exercise(perso, null, "Salutation au soleil", 3, "5", null, null, 0);

        notifications.save(new Notification(youssef, "Nouveau commentaire de votre coach", "Sami a commenté votre séance."));
    }

    private void promo(String title, String descr, int discount, LocalDate until) {
        Promo p = new Promo();
        p.setTitle(title);
        p.setDescr(descr);
        p.setDiscount(discount);
        p.setUntil(until);
        promos.save(p);
    }

    private void payment(User m, int amount, String method, LocalDate on, String note) {
        Payment p = new Payment();
        p.setMember(m);
        p.setAmount(BigDecimal.valueOf(amount));
        p.setMethod(method);
        p.setPaidOn(on);
        p.setNote(note);
        payments.save(p);
    }

    private void measure(User m, LocalDate on, double weight, double fat, String note) {
        Measure x = new Measure();
        x.setMember(m);
        x.setMeasuredOn(on);
        x.setWeight(weight);
        x.setBodyFat(fat);
        x.setNote(note);
        measures.save(x);
    }

    private void link(User coach, User client, String status) {
        CoachClient l = new CoachClient();
        l.setCoach(coach);
        l.setClient(client);
        l.setStatus(status);
        links.save(l);
    }

    private Program program(User client, User coach, String title, String goal, String notes) {
        Program p = new Program();
        p.setClient(client);
        p.setCoach(coach);
        p.setTitle(title);
        p.setGoal(goal);
        p.setNotes(notes);
        return programs.save(p);
    }

    private void exercise(Program p, String day, String name, Integer sets, String reps, String load, String rest, int position) {
        Exercise e = new Exercise();
        e.setProgram(p);
        e.setDay(day);
        e.setName(name);
        e.setSets(sets);
        e.setReps(reps);
        e.setLoad(load);
        e.setRest(rest);
        e.setPosition(position);
        exercises.save(e);
    }

}
