import { DateTime } from 'luxon';

import { effectiveCompletedAt, isOverdue, type Task } from '../../tasks/domain/task.js';

/**
 * Productivity numbers, computed the same way as the app's stats screen
 * (features/stats/domain/productivity.dart), in the user's time zone.
 */
export const PERIODS = ['week', 'month', 'all'] as const;
export type Period = (typeof PERIODS)[number];

export interface CategoryShare {
  name: string;
  count: number;
  share: number;
}

export interface ProductivityReport {
  period: Period;
  completed: number;
  previousCompleted: number | null;
  onTimeRate: number;
  overdue: number;
  streak: number;
  bestStreak: number;
  flowScore: number;
  /** Completions per weekday, Monday first. */
  byWeekday: number[];
  categories: CategoryShare[];
  /** Start hour of the two-hour window with the most completions, or null. */
  focusWindowStart: number | null;
}

interface Range {
  start: DateTime;
  end: DateTime;
}

function rangeFor(period: Period, now: DateTime, offset = 0): Range | null {
  if (period === 'week') {
    const start = now.startOf('week').plus({ weeks: offset }); // luxon weeks start on Monday
    return { start, end: start.plus({ weeks: 1 }) };
  }
  if (period === 'month') {
    const start = now.startOf('month').plus({ months: offset });
    return { start, end: start.plus({ months: 1 }) };
  }
  return null;
}

const inRange = (range: Range | null, instant: Date) =>
  range === null || (instant >= range.start.toJSDate() && instant < range.end.toJSDate());

export function buildReport(
  tasks: Task[],
  period: Period,
  nowDate: Date,
  zone: string,
): ProductivityReport {
  const now = DateTime.fromJSDate(nowDate, { zone });
  const range = rangeFor(period, now);

  const done = tasks.filter((t) => {
    const at = effectiveCompletedAt(t);
    return at !== null && inRange(range, at);
  });
  const onTime = done.filter((t) => effectiveCompletedAt(t)!.getTime() <= t.dueAt.getTime()).length;
  const onTimeRate = done.length === 0 ? 0 : onTime / done.length;

  const previousRange = rangeFor(period, now, -1);
  const previousCompleted = previousRange
    ? tasks.filter((t) => {
        const at = effectiveCompletedAt(t);
        return at !== null && inRange(previousRange, at);
      }).length
    : null;

  // 60%: how much of what was due got done; 40%: how much of it was on time.
  const dueSoFar = tasks.filter(
    (t) => inRange(range, t.dueAt) && t.dueAt.getTime() <= nowDate.getTime(),
  );
  const completionRate =
    dueSoFar.length === 0
      ? done.length === 0
        ? 0
        : 1
      : dueSoFar.filter((t) => t.isCompleted).length / dueSoFar.length;
  const flowScore =
    done.length === 0 && dueSoFar.length === 0
      ? 0
      : Math.round(100 * (0.6 * completionRate + 0.4 * onTimeRate));

  const byWeekday = [0, 0, 0, 0, 0, 0, 0];
  const perHour = new Array<number>(24).fill(0);
  for (const t of done) {
    const local = DateTime.fromJSDate(effectiveCompletedAt(t)!, { zone });
    byWeekday[local.weekday - 1]! += 1;
    perHour[local.hour]! += 1;
  }

  const [streak, bestStreak] = streaks(tasks, now);

  return {
    period,
    completed: done.length,
    previousCompleted,
    onTimeRate,
    overdue: tasks.filter((t) => isOverdue(t, nowDate)).length,
    streak,
    bestStreak,
    flowScore,
    byWeekday,
    categories: categoryShares(tasks.filter((t) => inRange(range, t.dueAt))),
    focusWindowStart: done.length < 3 ? null : bestWindow(perHour),
  };
}

/** Current streak (ending today, or yesterday if nothing is done yet today) and the best one. */
export function streaks(tasks: Task[], now: DateTime): [number, number] {
  const days = new Set<string>();
  for (const t of tasks) {
    const at = effectiveCompletedAt(t);
    if (at) days.add(DateTime.fromJSDate(at, { zone: now.zone }).toISODate()!);
  }
  if (days.size === 0) return [0, 0];

  const today = now.startOf('day');
  let day = days.has(today.toISODate()!) ? today : today.minus({ days: 1 });
  let current = 0;
  while (days.has(day.toISODate()!)) {
    current += 1;
    day = day.minus({ days: 1 });
  }

  const sorted = [...days].sort();
  let best = 1;
  let run = 1;
  for (let i = 1; i < sorted.length; i++) {
    const gap = DateTime.fromISO(sorted[i]!).diff(DateTime.fromISO(sorted[i - 1]!), 'days').days;
    run = Math.round(gap) === 1 ? run + 1 : 1;
    best = Math.max(best, run);
  }
  return [current, best];
}

/** The three biggest categories; the rest folded into "Other". */
export function categoryShares(tasks: Task[]): CategoryShare[] {
  if (tasks.length === 0) return [];
  const counts = new Map<string, number>();
  for (const t of tasks) {
    const name = t.category.trim() || 'Uncategorized';
    counts.set(name, (counts.get(name) ?? 0) + 1);
  }
  const entries = [...counts.entries()].sort((a, b) => b[1] - a[1]);
  const top = entries.slice(0, 3);
  const rest = entries.slice(3).reduce((sum, [, n]) => sum + n, 0);
  const total = tasks.length;
  return [
    ...top.map(([name, count]) => ({ name, count, share: count / total })),
    ...(rest > 0 ? [{ name: 'Other', count: rest, share: rest / total }] : []),
  ];
}

function bestWindow(perHour: number[]): number {
  let bestStart = 0;
  let bestCount = -1;
  for (let h = 0; h < 23; h++) {
    const count = perHour[h]! + perHour[h + 1]!;
    if (count > bestCount) {
      bestCount = count;
      bestStart = h;
    }
  }
  return bestStart;
}
