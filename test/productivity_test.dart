import 'package:flutter_test/flutter_test.dart';
import 'package:taskflow/features/stats/domain/productivity.dart';
import 'package:taskflow/features/tasks/domain/entities/task.dart';

Task _task(
  int id, {
  required DateTime due,
  DateTime? doneAt,
  String category = 'Work',
}) => Task(
  id: id,
  title: 'Task $id',
  dueDate: due,
  category: category,
  isCompleted: doneAt != null,
  completedAt: doneAt,
  createdAt: DateTime(2026, 9, 1),
  updatedAt: DateTime(2026, 9, 1),
);

void main() {
  final now = DateTime(2026, 9, 28, 12); // Monday

  test('weekly report: completions, on-time rate, streak, weekdays', () {
    final tasks = [
      // Done today, early.
      _task(
        1,
        due: DateTime(2026, 9, 28, 18),
        doneAt: DateTime(2026, 9, 28, 9),
      ),
      // Done yesterday (last week), late.
      _task(2, due: DateTime(2026, 9, 26), doneAt: DateTime(2026, 9, 27, 9)),
      // Still open, overdue.
      _task(3, due: DateTime(2026, 9, 27, 8)),
      _task(4, due: DateTime(2026, 10, 1), category: 'Home'),
    ];

    final report = buildReport(tasks, StatsPeriod.week, now);
    expect(report.completed, 1);
    expect(report.previousCompleted, 1);
    expect(report.onTimeRate, 1.0);
    expect(report.overdue, 1);
    expect(report.streak, 2);
    expect(report.byWeekday, [1, 0, 0, 0, 0, 0, 0]);
    expect(report.trendLabel, '0% vs last week');
  });

  test('streaks: current and best', () {
    final tasks = [
      for (final day in [1, 2, 3, 4, 10, 11])
        _task(
          day,
          due: DateTime(2026, 9, day),
          doneAt: DateTime(2026, 9, day, 12),
        ),
    ];
    final (current, best) = streaks(tasks, DateTime(2026, 9, 12, 9));
    expect(current, 2);
    expect(best, 4);
  });

  test('category shares fold small ones into Other', () {
    final tasks = [
      for (var i = 0; i < 4; i++) _task(i, due: now, category: 'Work'),
      for (var i = 4; i < 7; i++) _task(i, due: now, category: 'Home'),
      for (var i = 7; i < 9; i++) _task(i, due: now, category: 'Gym'),
      _task(9, due: now, category: 'Study'),
      _task(10, due: now, category: ''),
    ];
    final shares = categoryShares(tasks);
    expect(shares.map((s) => s.name), ['Work', 'Home', 'Gym', 'Other']);
    expect(shares.first.share, closeTo(4 / 11, 1e-9));
    expect(shares.last.count, 2);
  });

  test('focus window needs a few completions', () {
    expect(focusWindow([]), isNull);
    final done = [
      for (final h in [9, 10, 10, 15])
        _task(h, due: now, doneAt: DateTime(2026, 9, 28, h)),
    ];
    final window = focusWindow(done)!;
    expect(window.startHour, 9);
    expect(window.count, 3);
  });

  test('milestones: first step unlocked, next one suggested', () {
    final report = buildReport(
      [_task(1, due: now, doneAt: now)],
      StatsPeriod.all,
      now,
    );
    expect(report.achievement?.title, 'First Step');
    expect(report.nextMilestone?.title, '3-Day Streak');
    expect(report.previousCompleted, isNull);
    expect(report.flowScore, greaterThan(0));
  });

  test('an empty list scores zero', () {
    final report = buildReport(const [], StatsPeriod.month, now);
    expect(report.flowScore, 0);
    expect(report.flowLabel, 'No data yet');
    expect(report.achievement, isNull);
  });
}
