import { randomUUID } from 'node:crypto';

import { DateTime } from 'luxon';

import { computeDueAt } from './schedule.js';
import type { RepeatRule, Task, TaskFields } from './task.js';

/**
 * The next calendar day for [rule] after [dueDate] (`YYYY-MM-DD`).
 * Calendar arithmetic runs in UTC so daylight saving can't shift a day.
 * Mirrors `RepeatRule.next` in the app.
 */
export function nextDueDate(rule: RepeatRule, dueDate: string): string {
  const date = DateTime.fromISO(dueDate, { zone: 'utc' });
  let next: DateTime;
  switch (rule) {
    case 'none':
      return dueDate;
    case 'daily':
      next = date.plus({ days: 1 });
      break;
    case 'weekdays':
      next = date.plus({ days: 1 });
      while (next.weekday === 6 || next.weekday === 7) next = next.plus({ days: 1 });
      break;
    case 'weekly':
      next = date.plus({ weeks: 1 });
      break;
    case 'monthly':
      // Luxon clamps Jan 31 + 1 month to Feb 28/29, like the app does.
      next = date.plus({ months: 1 });
      break;
  }
  return next.toISODate() ?? dueDate;
}

/**
 * The follow-up of a repeating task that was just completed: due on the first
 * occurrence that isn't already in the past, with fresh subtasks.
 */
export function nextOccurrence(task: Task, now: Date): (TaskFields & { id: string }) | null {
  if (task.repeat === 'none') return null;

  let dueDate = nextDueDate(task.repeat, task.dueDate);
  // A task finished long after it was due skips the occurrences already missed.
  for (let guard = 0; guard < 1000; guard++) {
    const dueAt = computeDueAt({ ...task, dueDate });
    if (dueAt.getTime() >= now.getTime()) break;
    dueDate = nextDueDate(task.repeat, dueDate);
  }

  return {
    id: randomUUID(),
    title: task.title,
    description: task.description,
    dueDate,
    dueTime: task.dueTime,
    isAllDay: task.isAllDay,
    timezone: task.timezone,
    priority: task.priority,
    category: task.category,
    isCompleted: false,
    completedAt: null,
    reminder: task.reminder,
    reminderMinutes: task.reminderMinutes,
    repeat: task.repeat,
    createdAt: now,
    updatedAt: now,
    subtasks: task.subtasks.map((s) => ({ title: s.title, isCompleted: false })),
  };
}
