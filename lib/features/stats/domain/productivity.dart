import '../../../core/utils/date_time_utils.dart';
import '../../tasks/domain/entities/task.dart';

enum StatsPeriod {
  week('This Week', 'last week'),
  month('This Month', 'last month'),
  all('All Time', '');

  const StatsPeriod(this.label, this.previousLabel);
  final String label;
  final String previousLabel;
}

class CategoryShare {
  final String name;
  final int count;
  final double share;

  const CategoryShare(this.name, this.count, this.share);
}

/// The two-hour slot in which the most tasks get finished.
class FocusWindow {
  final int startHour;
  final int count;

  const FocusWindow(this.startHour, this.count);

  int get endHour => startHour + 2;
}

class Milestone {
  final String title;

  /// Shown once the milestone is reached.
  final String description;

  /// Shown while it is the next thing to aim for.
  final String goal;

  const Milestone(this.title, this.description, this.goal);
}

class ProductivityReport {
  final StatsPeriod period;
  final int completed;

  /// Completed in the previous week / month; null for all time.
  final int? previousCompleted;
  final double onTimeRate;
  final int overdue;
  final int streak;
  final int bestStreak;
  final int flowScore;

  /// Tasks completed per weekday, Monday first.
  final List<int> byWeekday;
  final List<CategoryShare> categories;
  final FocusWindow? focusWindow;
  final Milestone? achievement;
  final Milestone? nextMilestone;

  const ProductivityReport({
    required this.period,
    required this.completed,
    required this.previousCompleted,
    required this.onTimeRate,
    required this.overdue,
    required this.streak,
    required this.bestStreak,
    required this.flowScore,
    required this.byWeekday,
    required this.categories,
    required this.focusWindow,
    required this.achievement,
    required this.nextMilestone,
  });

  String get flowLabel {
    if (flowScore >= 80) return 'Optimal';
    if (flowScore >= 60) return 'Steady';
    if (flowScore >= 35) return 'Building';
    if (flowScore > 0) return 'Warming up';
    return 'No data yet';
  }

  /// Change against the previous period, e.g. `+18%`; null when there is
  /// nothing to compare with.
  String? get trendLabel {
    final previous = previousCompleted;
    if (previous == null) return null;
    if (previous == 0) {
      return completed == 0 ? null : '+$completed vs ${period.previousLabel}';
    }
    final change = ((completed - previous) / previous * 100).round();
    final sign = change > 0 ? '+' : '';
    return '$sign$change% vs ${period.previousLabel}';
  }

  bool get trendIsUp => (previousCompleted ?? 0) <= completed;
}

class _Range {
  final DateTime start;
  final DateTime end;

  const _Range(this.start, this.end);

  bool contains(DateTime t) => !t.isBefore(start) && t.isBefore(end);
}

_Range? _rangeFor(StatsPeriod period, DateTime now, {int offset = 0}) {
  switch (period) {
    case StatsPeriod.week:
      final monday = addDays(startOfWeek(now), 7 * offset);
      return _Range(monday, addDays(monday, 7));
    case StatsPeriod.month:
      final start = DateTime(now.year, now.month + offset);
      return _Range(start, DateTime(start.year, start.month + 1));
    case StatsPeriod.all:
      return null;
  }
}

ProductivityReport buildReport(
  List<Task> tasks,
  StatsPeriod period,
  DateTime now,
) {
  final range = _rangeFor(period, now);
  bool inRange(DateTime t) => range == null || range.contains(t);

  final done = [
    for (final t in tasks)
      if (t.isCompleted && inRange(t.effectiveCompletedAt!)) t,
  ];
  final onTime = done
      .where((t) => !t.effectiveCompletedAt!.isAfter(t.deadline))
      .length;
  final onTimeRate = done.isEmpty ? 0.0 : onTime / done.length;

  int? previous;
  final previousRange = _rangeFor(period, now, offset: -1);
  if (previousRange != null) {
    previous = tasks
        .where(
          (t) =>
              t.isCompleted && previousRange.contains(t.effectiveCompletedAt!),
        )
        .length;
  }

  // Flow score: how much of what was due got done (60%) and how much of the
  // finished work landed on time (40%).
  final dueSoFar = [
    for (final t in tasks)
      if (inRange(t.deadline) && !t.deadline.isAfter(now)) t,
  ];
  final completionRate = dueSoFar.isEmpty
      ? (done.isEmpty ? 0.0 : 1.0)
      : dueSoFar.where((t) => t.isCompleted).length / dueSoFar.length;
  final flowScore = (done.isEmpty && dueSoFar.isEmpty)
      ? 0
      : (100 * (0.6 * completionRate + 0.4 * onTimeRate)).round();

  final byWeekday = List<int>.filled(7, 0);
  for (final t in done) {
    byWeekday[t.effectiveCompletedAt!.weekday - 1]++;
  }

  final (streak, best) = streaks(tasks, now);

  return ProductivityReport(
    period: period,
    completed: done.length,
    previousCompleted: previous,
    onTimeRate: onTimeRate,
    overdue: tasks.where((t) => t.isOverdue(now)).length,
    streak: streak,
    bestStreak: best,
    flowScore: flowScore,
    byWeekday: byWeekday,
    categories: categoryShares([
      for (final t in tasks)
        if (inRange(t.dueDate)) t,
    ]),
    focusWindow: focusWindow(done),
    achievement: _achievement(tasks, best),
    nextMilestone: _nextMilestone(tasks, best),
  );
}

/// Current streak (ending today, or yesterday if nothing is done yet today)
/// and the best streak ever, in days with at least one completed task.
(int, int) streaks(List<Task> tasks, DateTime now) {
  final days = <DateTime>{
    for (final t in tasks)
      if (t.isCompleted) dateOnly(t.effectiveCompletedAt!),
  };
  if (days.isEmpty) return (0, 0);

  final today = dateOnly(now);
  var day = days.contains(today) ? today : addDays(today, -1);
  var current = 0;
  while (days.contains(day)) {
    current++;
    day = addDays(day, -1);
  }

  final sorted = days.toList()..sort();
  var best = 1;
  var run = 1;
  for (var i = 1; i < sorted.length; i++) {
    run = daysBetween(sorted[i - 1], sorted[i]) == 1 ? run + 1 : 1;
    if (run > best) best = run;
  }
  return (current, best);
}

/// Completions per day for the week containing [now], Monday first.
List<int> completionsThisWeek(List<Task> tasks, DateTime now) {
  final monday = startOfWeek(now);
  final result = List<int>.filled(7, 0);
  for (final t in tasks) {
    if (!t.isCompleted) continue;
    final index = daysBetween(monday, t.effectiveCompletedAt!);
    if (index >= 0 && index < 7) result[index]++;
  }
  return result;
}

/// The three biggest categories, the rest folded into "Other".
List<CategoryShare> categoryShares(List<Task> tasks) {
  if (tasks.isEmpty) return const [];
  final counts = <String, int>{};
  for (final t in tasks) {
    final name = t.category.trim().isEmpty ? 'Uncategorized' : t.category;
    counts[name] = (counts[name] ?? 0) + 1;
  }
  final entries = counts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final top = entries.take(3).toList();
  final rest = entries.skip(3).fold(0, (sum, e) => sum + e.value);
  final total = tasks.length;
  return [
    for (final e in top) CategoryShare(e.key, e.value, e.value / total),
    if (rest > 0) CategoryShare('Other', rest, rest / total),
  ];
}

FocusWindow? focusWindow(List<Task> completed) {
  if (completed.length < 3) return null;
  final perHour = List<int>.filled(24, 0);
  for (final t in completed) {
    perHour[t.effectiveCompletedAt!.hour]++;
  }
  var bestStart = 0;
  var bestCount = -1;
  for (var h = 0; h < 23; h++) {
    final count = perHour[h] + perHour[h + 1];
    if (count > bestCount) {
      bestCount = count;
      bestStart = h;
    }
  }
  return FocusWindow(bestStart, bestCount);
}

typedef _Progress = ({int done, int bestStreak, double onTime});

final _milestones = <(Milestone, bool Function(_Progress))>[
  (
    const Milestone(
      'First Step',
      'You finished your very first task.',
      'Complete your first task.',
    ),
    (p) => p.done >= 1,
  ),
  (
    const Milestone(
      '3-Day Streak',
      'Tasks done three days running.',
      'Get something done three days in a row.',
    ),
    (p) => p.bestStreak >= 3,
  ),
  (
    const Milestone(
      'Getting Into Flow',
      '10 tasks completed so far.',
      'Complete 10 tasks.',
    ),
    (p) => p.done >= 10,
  ),
  (
    const Milestone(
      'Week-Long Streak',
      'Something finished every day for a week.',
      'Finish something every day for a week.',
    ),
    (p) => p.bestStreak >= 7,
  ),
  (
    const Milestone(
      'Steady Hands',
      '25 tasks completed so far.',
      'Complete 25 tasks.',
    ),
    (p) => p.done >= 25,
  ),
  (
    const Milestone(
      'Always On Time',
      '90% of your tasks finished before they were due.',
      'Finish 90% of at least 10 tasks before they are due.',
    ),
    (p) => p.done >= 10 && p.onTime >= 0.9,
  ),
  (
    const Milestone(
      'Two-Week Streak',
      'Fourteen days in a row with progress.',
      'Keep a streak going for 14 days.',
    ),
    (p) => p.bestStreak >= 14,
  ),
  (
    const Milestone(
      'Half Century',
      '50 tasks completed so far.',
      'Complete 50 tasks.',
    ),
    (p) => p.done >= 50,
  ),
  (
    const Milestone(
      'Month of Momentum',
      'A 30-day streak. Remarkable.',
      'Keep a streak going for 30 days.',
    ),
    (p) => p.bestStreak >= 30,
  ),
  (
    const Milestone(
      'Centurion',
      '100 tasks completed so far.',
      'Complete 100 tasks.',
    ),
    (p) => p.done >= 100,
  ),
];

_Progress _progress(List<Task> tasks, int bestStreak) {
  final done = tasks.where((t) => t.isCompleted).toList();
  final onTime = done
      .where((t) => !t.effectiveCompletedAt!.isAfter(t.deadline))
      .length;
  return (
    done: done.length,
    bestStreak: bestStreak,
    onTime: done.isEmpty ? 0.0 : onTime / done.length,
  );
}

/// The most advanced milestone reached so far.
Milestone? _achievement(List<Task> tasks, int bestStreak) {
  final progress = _progress(tasks, bestStreak);
  Milestone? latest;
  for (final (milestone, reached) in _milestones) {
    if (reached(progress)) latest = milestone;
  }
  return latest;
}

Milestone? _nextMilestone(List<Task> tasks, int bestStreak) {
  final progress = _progress(tasks, bestStreak);
  for (final (milestone, reached) in _milestones) {
    if (!reached(progress)) return milestone;
  }
  return null;
}
