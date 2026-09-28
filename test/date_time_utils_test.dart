import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskflow/core/utils/date_time_utils.dart';

void main() {
  group('parseTimeOfDay', () {
    test('parses 12-hour strings', () {
      expect(parseTimeOfDay('02:00 PM'), const TimeOfDay(hour: 14, minute: 0));
      expect(parseTimeOfDay('12:05 am'), const TimeOfDay(hour: 0, minute: 5));
      expect(parseTimeOfDay('12:30 PM'), const TimeOfDay(hour: 12, minute: 30));
      expect(parseTimeOfDay('9:15am'), const TimeOfDay(hour: 9, minute: 15));
    });

    test('parses 24-hour strings', () {
      expect(parseTimeOfDay('08:00'), const TimeOfDay(hour: 8, minute: 0));
      expect(parseTimeOfDay('23:59'), const TimeOfDay(hour: 23, minute: 59));
    });

    test('rejects invalid input', () {
      expect(parseTimeOfDay(null), isNull);
      expect(parseTimeOfDay(''), isNull);
      expect(parseTimeOfDay('25:00'), isNull);
      expect(parseTimeOfDay('13:00 PM'), isNull);
      expect(parseTimeOfDay('10:75'), isNull);
    });
  });

  test('formatTimeOfDay round-trips through parseTimeOfDay', () {
    for (final time in const [
      TimeOfDay(hour: 0, minute: 0),
      TimeOfDay(hour: 9, minute: 5),
      TimeOfDay(hour: 12, minute: 0),
      TimeOfDay(hour: 23, minute: 45),
    ]) {
      expect(parseTimeOfDay(formatTimeOfDay(time)), time);
    }
    expect(formatTimeOfDay(const TimeOfDay(hour: 14, minute: 0)), '02:00 PM');
    expect(formatTime24(const TimeOfDay(hour: 8, minute: 5)), '08:05');
  });

  test('dayLabel', () {
    final now = DateTime(2026, 9, 28, 10);
    expect(dayLabel(DateTime(2026, 9, 28, 23), now: now), 'Today');
    expect(dayLabel(DateTime(2026, 9, 29), now: now), 'Tomorrow');
    expect(dayLabel(DateTime(2026, 9, 27), now: now), 'Yesterday');
  });

  test('relativeDueLabel', () {
    final now = DateTime(2026, 9, 28, 10);
    expect(relativeDueLabel(DateTime(2026, 9, 28, 13), now: now), 'In 3 hours');
    expect(
      relativeDueLabel(DateTime(2026, 9, 28, 10, 20), now: now),
      'In 20 minutes',
    );
    expect(
      relativeDueLabel(DateTime(2026, 9, 26, 10), now: now),
      'Overdue by 2 days',
    );
  });

  test('daysBetween counts calendar days', () {
    expect(daysBetween(DateTime(2026, 3, 1), DateTime(2026, 3, 31, 23)), 30);
    expect(daysBetween(DateTime(2026, 1, 2), DateTime(2026, 1, 1)), -1);
  });
}
