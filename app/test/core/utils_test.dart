import 'package:flutter_test/flutter_test.dart';
import 'package:ironfit/core/utils/dates.dart';
import 'package:ironfit/core/utils/values.dart';

void main() {
  // Mercredi 15 octobre 2025 (index 2).
  final wed = DateTime(2025, 10, 15, 18, 30);

  group('dates', () {
    test('isoDate pads month and day', () {
      expect(isoDate(DateTime(2026, 3, 7)), '2026-03-07');
      expect(todayIso(wed), '2025-10-15');
    });

    test('todayIndex is 0 for Monday and 6 for Sunday', () {
      expect(todayIndex(DateTime(2025, 10, 13)), 0);
      expect(todayIndex(DateTime(2025, 10, 19)), 6);
      expect(todayIndex(wed), 2);
    });

    test('dayLabel says today / tomorrow, then the day name, wrapping the week', () {
      expect(dayLabel(2, wed), 'Aujourd\'hui');
      expect(dayLabel(3, wed), 'Demain');
      expect(dayLabel(0, wed), 'Lundi');
      expect(dayLabel(1, wed), 'Mardi');
    });

    test('daysAhead orders the coming days of the week', () {
      expect([for (var d = 0; d < 7; d++) daysAhead(d, wed)], [5, 6, 0, 1, 2, 3, 4]);
    });

    test('monthLabel handles valid and invalid input', () {
      expect(monthLabel('2026-01'), 'Jan');
      expect(monthLabel('2026-12-31'), 'Déc');
      expect(monthLabel('2026-13'), '?');
      expect(monthLabel('bad'), '?');
    });

    test('dayOptions matches dayNames', () {
      expect(dayOptions.values.toList(), dayNames);
      expect(dayOptions.keys.toList(), List.generate(7, (i) => i));
    });

    test('withoutYear strips the year', () => expect(withoutYear('2026-10-19'), '10-19'));

    test('localStamp converts a SQLite UTC stamp to local time and keeps unknown input', () {
      final expected = DateTime.utc(2026, 10, 19, 8, 5).toLocal();
      expect(localStamp('2026-10-19 08:05:00'), '${isoDate(expected)} ${twoDigits(expected.hour)}:05');
      expect(localStamp('pas une date'), 'pas une date');
      expect(localStamp(null), '');
    });

    test('datePart keeps the date of a SQLite stamp', () {
      expect(datePart('2026-10-01 10:00:00'), '2026-10-01');
      expect(datePart(null), '');
    });
  });

  group('values', () {
    test('toDouble tolerates numbers, strings with comma and null', () {
      expect(toDouble(3), 3.0);
      expect(toDouble('2,5'), 2.5);
      expect(toDouble('x'), 0);
      expect(toDouble(null), 0);
      expect(toInt('12.9'), 12);
    });

    test('asBool accepts SQLite 1 and bool true only', () {
      expect(asBool(1), isTrue);
      expect(asBool(true), isTrue);
      expect(asBool(0), isFalse);
      expect(asBool('1'), isFalse);
      expect(asBool(null), isFalse);
    });

    test('initialOf never throws on empty names', () {
      expect(initialOf('sami'), 'S');
      expect(initialOf(''), '?');
      expect(initialOf('   '), '?');
      expect(initialOf(null), '?');
    });

    test('firstName and plural', () {
      expect(firstName('Youssef Ben Ali'), 'Youssef');
      expect(plural(1, 'séance'), '1 séance');
      expect(plural(3, 'séance'), '3 séances');
      expect(plural(2, 'travail', 'travaux'), '2 travaux');
    });
  });
}
