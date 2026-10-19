import 'package:flutter_test/flutter_test.dart';
import 'package:ironfit/core/api/api.dart';
import 'package:ironfit/core/utils/values.dart';
import 'package:ironfit/core/widgets/form_dialog.dart';
import 'package:ironfit/features/admin/admin_home_page.dart';
import 'package:ironfit/features/auth/auth_page.dart';
import 'package:ironfit/features/coach/clients_page.dart';
import 'package:ironfit/features/crud/form_sheet.dart';
import 'package:ironfit/features/crud/module.dart';
import 'package:ironfit/features/crud/module_catalogue.dart';
import 'package:ironfit/features/member/explore_page.dart';
import 'package:ironfit/features/member/member_home_page.dart';
import 'package:ironfit/features/member/progress.dart';
import 'package:ironfit/features/member/subscription.dart';
import 'package:ironfit/features/planning/booking.dart';
import 'package:ironfit/features/profile/profile_page.dart';
import 'package:ironfit/features/programs/program_detail_page.dart';
import 'package:ironfit/features/programs/program_list.dart';
import 'package:ironfit/features/programs/workouts.dart';
import 'package:ironfit/features/shell/modules_grid.dart';

import '../helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Lundi 19 octobre 2026, 21 h.
  final now = DateTime(2026, 10, 19, 21);

  group('SubscriptionStatus', () {
    test('no end date', () {
      final s = SubscriptionStatus.of(null, now: now);
      expect(s.active, isFalse);
      expect(s.hasPlan, isFalse);
      expect(s.label, 'Aucun abonnement');
    });

    test('ends today counts as one day left regardless of the time of day', () {
      final s = SubscriptionStatus.of('2026-10-19', now: now);
      expect(s.active, isTrue);
      expect(s.daysLeft, 1);
      expect(s.label, 'Actif · 1 jour restant');
    });

    test('several days left, expired, malformed', () {
      expect(SubscriptionStatus.of('2026-10-28', now: now).label, 'Actif · 10 jours restants');
      final expired = SubscriptionStatus.of('2026-10-18', now: now);
      expect(expired.active, isFalse);
      expect(expired.label, 'Expiré le 2026-10-18');
      expect(SubscriptionStatus.of('n/a', now: now).label, 'Date de fin invalide');
    });

    test('isPast and clientSubscription', () {
      expect(isPast('2026-10-18', now: now), isTrue);
      expect(isPast('2026-10-19', now: now), isFalse);
      expect(isPast(null, now: now), isFalse);
      expect(clientSubscription(null), 'Sans abonnement');
      expect(clientSubscription('2000-01-01'), 'Abonnement expiré');
      expect(clientSubscription('2099-01-31'), 'Abonné jusqu\'au 2099-01-31');
    });
  });

  group('module catalogue', () {
    test('ids are unique and every module is reachable by id', () {
      final ids = modules.map((m) => m.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
      for (final id in ids) {
        expect(moduleById(id).id, id);
      }
    });

    test('roles are valid and writers can also read', () {
      const roles = {'admin', 'coach', 'athlete'};
      for (final m in modules) {
        expect(roles.containsAll(m.read), isTrue, reason: m.id);
        expect(roles.containsAll(m.write), isTrue, reason: m.id);
        expect(m.read.toSet().containsAll(m.write), isTrue, reason: m.id);
      }
    });

    test('select fields have options or a known reference list', () {
      for (final m in modules) {
        for (final f in m.fields.where((f) => f.type == FieldType.select)) {
          expect(
            f.options != null || {'plans', 'coaches', 'members'}.contains(f.ref),
            isTrue,
            reason: '${m.id}.${f.key}',
          );
        }
      }
    });

    test('titles and subtitles tolerate empty rows', () {
      for (final m in modules) {
        expect(() => m.titleOf(const {}), returnsNormally, reason: m.id);
        expect(() => m.subtitleOf(const {}), returnsNormally, reason: m.id);
      }
    });

    test('payment options match payMethods', () => expect(payOptions.keys.toList(), payMethods));

    test('a coach manages classes, equipment, announcements, measures and check-ins only', () {
      expect(managedModules('coach').map((m) => m.id), [
        'classes',
        'equipment',
        'announcements',
        'measures',
        'checkins',
      ]);
      expect(managedModules('admin').map((m) => m.id), contains('payments'));
    });
  });

  group('CRUD form', () {
    const pw = Field('password', 'Mot de passe', type: FieldType.password);
    const price = Field('price', 'Prix', type: FieldType.number, required: true);
    const mail = Field('email', 'E-mail', type: FieldType.email);

    test('required, number and negative values', () {
      expect(validateField(price, '', creating: true), 'Obligatoire');
      expect(validateField(price, 'abc', creating: true), 'Nombre invalide');
      expect(validateField(price, '-3', creating: true), 'Doit être positif');
      expect(validateField(price, '12,5', creating: true), isNull);
    });

    test('password is required on creation only and needs 6 characters', () {
      expect(validateField(pw, '', creating: true), 'Obligatoire');
      expect(validateField(pw, '', creating: false), isNull);
      expect(validateField(pw, '123', creating: false), '6 caractères minimum');
    });

    test('e-mail format', () {
      expect(validateField(mail, 'nope', creating: true), 'E-mail invalide');
      expect(validateField(mail, 'a@b.tn', creating: true), isNull);
      expect(validateField(mail, '', creating: true), isNull);
    });

    test('buildBody trims, converts the decimal comma and drops an empty password', () {
      final fields = moduleById('coaches').fields;
      final body = buildBody(fields, {
        'name': '  Sami ',
        'login': 'sami',
        'email': 's@x.tn',
        'password': '',
        'phone': '',
      });
      expect(body['name'], 'Sami');
      expect(body['phone'], isNull);
      expect(body.containsKey('password'), isFalse);
      expect(buildBody(moduleById('plans').fields, {'name': 'Mensuel', 'price': '59,9'})['price'], '59.9');
    });

    test('the coach field of a class is only visible to the admin', () async {
      final coachField = moduleById('classes').fields.firstWhere((f) => f.key == 'coach_id');
      await signedIn(coach);
      expect(coachField.visible, isFalse);
      await signedIn(admin);
      expect(coachField.visible, isTrue);
    });
  });

  test('dialog field validation (integer and decimal bounds)', () {
    const sets = DField('sets', 'Séries', type: DType.integer, max: 50);
    const weight = DField('weight', 'Poids', type: DType.decimal, min: 20, max: 400);
    expect(validateDField(sets, ''), isNull);
    expect(validateDField(sets, '4.5'), 'Nombre entier attendu');
    expect(validateDField(sets, '60'), 'Entre 0 et 50');
    expect(validateDField(weight, '10'), 'Entre 20 et 400');
    expect(validateDField(weight, '72,5'), isNull);
    expect(validateDField(const DField('title', 'Titre', required: true), ' '), 'Obligatoire');
  });

  test('auth validators', () {
    expect(AuthValidators.login('ab'), isNotNull);
    expect(AuthValidators.login('sami_01'), isNull);
    expect(AuthValidators.email(''), 'Obligatoire');
    expect(AuthValidators.email('x@y.z'), isNull);
    expect(AuthValidators.password('12345'), '6 caractères minimum');
    expect(AuthValidators.code('12a456'), 'Code à 6 chiffres');
    expect(AuthValidators.code('123456'), isNull);
  });

  group('planning and dashboards', () {
    test('ClassSlot: full only when not booked; the coach running it is detected', () async {
      await signedIn(coach);
      expect(ClassSlot({'taken': 10, 'spots': 10, 'mine': 0}).full, isTrue);
      expect(ClassSlot({'taken': 10, 'spots': 10, 'mine': 1}).full, isFalse);
      expect(ClassSlot({'taken': 3, 'spots': 0}).ratio, 0);
      expect(ClassSlot({'taken': 15, 'spots': 10}).ratio, 1);
      expect(ClassSlot({'coach_id': 2}).teaching, isTrue);
      expect(ClassSlot({'coach_id': 3}).teaching, isFalse);
    });

    test('MemberDashboard: upcoming classes, last week workouts, latest weight', () {
      const d = MemberDashboard(
        classes: [
          {'title': 'Yoga', 'day': 6, 'time': '10:00', 'mine': 1},
          {'title': 'Crossfit', 'day': 0, 'time': '18:00', 'mine': 1},
          {'title': 'Spinning', 'day': 1, 'time': '07:00', 'mine': 0},
        ],
        announcements: [],
        promos: [],
        requests: [],
        measures: [
          {'measured_on': '2026-10-01', 'weight': 80},
          {'measured_on': '2026-10-15', 'weight': 78.5},
          {'measured_on': '2026-10-18', 'body_fat': 18},
        ],
        programs: [],
        workouts: [
          {'done_on': '2026-10-18'},
          {'done_on': '2026-10-01'},
        ],
      );
      expect(d.upcoming(now).map((c) => c['title']), ['Crossfit', 'Yoga']);
      expect(d.workoutsLastWeek(now), 1);
      expect(d.latestWeight(), '78.5 kg');
    });

    test('revenueFor sums one month only', () {
      final rev = [
        {'m': '2026-09', 'total': 100},
        {'m': '2026-10', 'total': 60},
        {'m': '2026-10', 'total': '40.5'},
      ];
      expect(revenueFor(rev, '2026-10'), 100.5);
      expect(revenueFor(rev, '2026-11'), 0);
    });

    test('profile role text', () {
      expect(roleText(coach), 'Coach · membre · Musculation');
      expect(roleText(athlete), 'Membre');
      expect(roleText(admin), 'Administrateur');
    });
  });

  group('programs and progress', () {
    test('exerciseLine and groupByDay', () {
      expect(
        exerciseLine({'sets': 4, 'reps': '8-12', 'load': '40 kg', 'rest': '90 s'}),
        '4 × 8-12 · 40 kg · repos 90 s',
      );
      expect(exerciseLine({'reps': '45 s'}), '? × 45 s');
      expect(exerciseLine(const {}), '');
      final groups = groupByDay([
        {'name': 'Squat', 'day': 'A'},
        {'name': 'Gainage'},
        {'name': 'Fentes', 'day': 'A'},
      ]);
      expect(groups.keys, ['A', '']);
      expect(groups['A']!.map((e) => e['name']), ['Squat', 'Fentes']);
    });

    test('programSubtitle', () {
      final p = {'coach_id': 2, 'coach_name': 'Sami', 'goal': 'Force', 'exercises': 1, 'sessions': 3};
      expect(programSubtitle(p, showAuthor: true), 'Par Sami · Force · 1 exercice · 3 séances');
      expect(programSubtitle(const {'exercises': 0, 'sessions': 0}, showAuthor: false), '0 exercice · 0 séance');
    });

    test('WorkoutStats counts this week from Monday and this month minutes', () {
      final s = WorkoutStats([
        {'done_on': '2026-10-19', 'duration': 45},
        {'done_on': '2026-10-18', 'duration': 30},
        {'done_on': '2026-09-30', 'duration': 60},
      ], now);
      expect(s.thisWeek, 1);
      expect(s.monthMinutes, 75);
      expect(s.total, 3);
    });

    test('ProgressSummary computes weight change and last body fat', () {
      final s = ProgressSummary([
        {'weight': 80, 'body_fat': 20},
        {'weight': null, 'body_fat': 19.5},
        {'weight': 77.5},
      ]);
      expect(s.weights, [80, 77.5]);
      expect(s.change, -2.5);
      expect(s.lastBodyFat, 19.5);
      expect(ProgressSummary(const <Json>[]).change, 0);
    });

    test('stockLabel', () {
      expect(stockLabel(0), 'Rupture');
      expect(stockLabel('3'), 'Stock limité');
      expect(stockLabel(20), 'Disponible');
    });
  });
}
