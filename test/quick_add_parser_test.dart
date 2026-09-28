import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_test/flutter_test.dart';
import 'package:taskflow/core/utils/quick_add_parser.dart';
import 'package:taskflow/features/tasks/domain/entities/task.dart';

void main() {
  final now = DateTime(2026, 9, 28, 10); // Monday

  QuickAdd parse(String text) =>
      parseQuickAdd(text, now: now, categories: const ['Work', 'Personal']);

  test('finds date, time, tag and priority and cleans the title', () {
    final r = parse('Call Sam tomorrow at 5pm #personal !high');
    expect(r.title, 'Call Sam');
    expect(r.date, DateTime(2026, 9, 29));
    expect(r.time, const TimeOfDay(hour: 17, minute: 0));
    expect(r.category, 'Personal');
    expect(r.priority, TaskPriority.high);
  });

  test('weekday names mean the coming one', () {
    expect(parse('Gym on friday').date, DateTime(2026, 10, 2));
    expect(parse('Standup monday').date, DateTime(2026, 9, 28));
    expect(parse('Review next monday').date, DateTime(2026, 10, 5));
  });

  test('relative days, weeks and tonight', () {
    expect(parse('Renew passport in 3 days').date, DateTime(2026, 10, 1));
    expect(parse('Plan trip in a week').date, DateTime(2026, 10, 5));
    final tonight = parse('Movie tonight');
    expect(tonight.date, DateTime(2026, 9, 28));
    expect(tonight.time, const TimeOfDay(hour: 20, minute: 0));
    expect(tonight.title, 'Movie');
  });

  test('12 and 24 hour times', () {
    expect(
      parse('Lunch at 12:30pm').time,
      const TimeOfDay(hour: 12, minute: 30),
    );
    expect(parse('Pay rent 12am').time, const TimeOfDay(hour: 0, minute: 0));
    expect(parse('Call at 17:45').time, const TimeOfDay(hour: 17, minute: 45));
    expect(parse('Break at noon').time, const TimeOfDay(hour: 12, minute: 0));
  });

  test('new tags are capitalised, known ones keep their spelling', () {
    expect(parse('Read #study').category, 'Study');
    expect(parse('Email boss #WORK').category, 'Work');
  });

  test("leaves ordinary words alone", () {
    final r = parse("Finish today's report");
    expect(r.hasMatches, isFalse);
    expect(r.title, "Finish today's report");
    expect(parse('Buy 2 apples').hasMatches, isFalse);
  });
}
