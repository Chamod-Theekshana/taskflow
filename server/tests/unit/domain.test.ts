import { DateTime } from 'luxon';
import { describe, expect, it } from 'vitest';

import {
  buildReport,
  categoryShares,
  streaks,
} from '../../src/modules/stats/domain/productivity.js';
import { nextDueDate, nextOccurrence } from '../../src/modules/tasks/domain/repeat-rule.js';
import {
  computeDueAt,
  computeRemindAt,
  isValidDate,
  isValidTimeZone,
} from '../../src/modules/tasks/domain/schedule.js';
import type { Task } from '../../src/modules/tasks/domain/task.js';
import { prepareTaskWrite } from '../../src/modules/tasks/domain/task-writer.js';

function task(overrides: Partial<Task> = {}): Task {
  const base = {
    id: '6f1f7d0e-8a57-4c2e-9c7b-2f5a3b9d1e01',
    userId: 'u',
    title: 'Plan sprint',
    description: '',
    dueDate: '2026-09-28',
    dueTime: '14:30',
    isAllDay: false,
    timezone: 'Asia/Colombo',
    priority: 'medium' as const,
    category: 'Work',
    isCompleted: false,
    completedAt: null,
    reminder: true,
    reminderMinutes: 15,
    remindAt: null,
    reminderSentAt: null,
    repeat: 'none' as const,
    createdAt: new Date('2026-09-01T00:00:00Z'),
    updatedAt: new Date('2026-09-01T00:00:00Z'),
    deletedAt: null,
    changeSeq: 1,
    subtasks: [],
    ...overrides,
  };
  return { ...base, dueAt: overrides.dueAt ?? computeDueAt(base) };
}

describe('schedule', () => {
  it('turns local date and time into an instant in the task time zone', () => {
    // Colombo is UTC+05:30.
    expect(
      computeDueAt({
        dueDate: '2026-09-29',
        dueTime: '14:00',
        isAllDay: false,
        timezone: 'Asia/Colombo',
      }).toISOString(),
    ).toBe('2026-09-29T08:30:00.000Z');
  });

  it('all-day tasks are due at the end of the day and remind at 9 AM', () => {
    const input = { dueDate: '2026-09-29', dueTime: null, isAllDay: true, timezone: 'UTC' };
    expect(computeDueAt(input).toISOString()).toBe('2026-09-29T23:59:59.000Z');
    expect(computeRemindAt({ ...input, reminder: true, reminderMinutes: 30 })?.toISOString()).toBe(
      '2026-09-29T09:00:00.000Z',
    );
  });

  it('timed reminders fire minutes before the due time, or not at all', () => {
    const input = { dueDate: '2026-09-29', dueTime: '10:00', isAllDay: false, timezone: 'UTC' };
    expect(computeRemindAt({ ...input, reminder: true, reminderMinutes: 15 })?.toISOString()).toBe(
      '2026-09-29T09:45:00.000Z',
    );
    expect(computeRemindAt({ ...input, reminder: false, reminderMinutes: 15 })).toBeNull();
  });

  it('respects daylight saving time', () => {
    // New York switches to EST on 2026-11-01.
    const before = computeDueAt({
      dueDate: '2026-10-31',
      dueTime: '09:00',
      isAllDay: false,
      timezone: 'America/New_York',
    });
    const after = computeDueAt({
      dueDate: '2026-11-02',
      dueTime: '09:00',
      isAllDay: false,
      timezone: 'America/New_York',
    });
    expect(before.toISOString()).toBe('2026-10-31T13:00:00.000Z');
    expect(after.toISOString()).toBe('2026-11-02T14:00:00.000Z');
  });

  it('validates dates and zones', () => {
    expect(isValidDate('2026-02-29')).toBe(false);
    expect(isValidDate('2028-02-29')).toBe(true);
    expect(isValidTimeZone('Asia/Colombo')).toBe(true);
    expect(isValidTimeZone('Mars/Olympus')).toBe(false);
  });
});

describe('repeat rules', () => {
  it('moves by the rule and keeps calendar days', () => {
    expect(nextDueDate('daily', '2026-09-28')).toBe('2026-09-29');
    expect(nextDueDate('weekly', '2026-09-28')).toBe('2026-10-05');
    expect(nextDueDate('weekdays', '2026-10-02')).toBe('2026-10-05'); // Friday -> Monday
    expect(nextDueDate('monthly', '2026-01-31')).toBe('2026-02-28');
  });

  it('the next occurrence skips days already in the past and resets subtasks', () => {
    const t = task({
      repeat: 'daily',
      dueDate: '2026-09-20',
      subtasks: [{ id: 's1', title: 'Step', isCompleted: true, position: 0 }],
    });
    const next = nextOccurrence(t, new Date('2026-09-29T12:00:00Z'))!;
    expect(next.dueDate).toBe('2026-09-30'); // 29th 14:30 Colombo = 09:00Z, already past at 12:00Z
    expect(next.subtasks).toEqual([{ title: 'Step', isCompleted: false }]);
    expect(next.isCompleted).toBe(false);
  });

  it('non-repeating tasks have no follow-up', () => {
    expect(nextOccurrence(task(), new Date())).toBeNull();
  });
});

describe('task writer', () => {
  it('derives the schedule and flags a moved reminder', () => {
    const existing = task({ remindAt: new Date('2026-09-28T08:45:00Z') });
    const now = new Date('2026-09-28T00:00:00Z');
    const same = prepareTaskWrite({ ...existing, subtasks: [] }, existing, now);
    expect(same.remindAt?.toISOString()).toBe('2026-09-28T08:45:00.000Z');
    expect(same.resetReminder).toBe(false);

    const moved = prepareTaskWrite({ ...existing, dueTime: '16:00', subtasks: [] }, existing, now);
    expect(moved.resetReminder).toBe(true);
  });

  it('drops the time of all-day tasks and stamps completion', () => {
    const now = new Date('2026-09-28T10:00:00Z');
    const write = prepareTaskWrite(
      {
        ...task(),
        isAllDay: true,
        isCompleted: true,
        subtasks: [{ title: '  ', isCompleted: false }],
      },
      null,
      now,
    );
    expect(write.dueTime).toBeNull();
    expect(write.completedAt).toEqual(now);
    expect(write.subtasks).toHaveLength(0);
  });
});

describe('productivity', () => {
  const zone = 'UTC';
  const now = new Date('2026-09-30T12:00:00Z'); // Wednesday

  it('counts streaks of days with completions', () => {
    const done = (day: string) =>
      task({ isCompleted: true, completedAt: new Date(`${day}T10:00:00Z`), dueDate: day });
    const tasks = [done('2026-09-28'), done('2026-09-29'), done('2026-09-30'), done('2026-09-20')];
    expect(streaks(tasks, DateTime.fromJSDate(now, { zone }))).toEqual([3, 3]);
  });

  it('builds a weekly report', () => {
    const tasks = [
      task({
        dueDate: '2026-09-29',
        dueTime: '12:00',
        timezone: zone,
        isCompleted: true,
        completedAt: new Date('2026-09-29T11:00:00Z'),
      }),
      task({
        dueDate: '2026-09-29',
        dueTime: '12:00',
        timezone: zone,
        isCompleted: true,
        completedAt: new Date('2026-09-29T13:00:00Z'),
      }),
      task({ dueDate: '2026-09-29', dueTime: '09:00', timezone: zone }),
    ];
    const report = buildReport(tasks, 'week', now, zone);
    expect(report.completed).toBe(2);
    expect(report.onTimeRate).toBe(0.5);
    expect(report.overdue).toBe(1);
    expect(report.byWeekday[1]).toBe(2); // Tuesday
    expect(report.flowScore).toBe(Math.round(100 * (0.6 * (2 / 3) + 0.4 * 0.5)));
  });

  it('folds small categories into Other', () => {
    const names = ['A', 'A', 'B', 'C', 'D', 'E'];
    const shares = categoryShares(names.map((category) => task({ category })));
    expect(shares.map((s) => s.name)).toEqual(['A', 'B', 'C', 'Other']);
    expect(shares.at(-1)?.count).toBe(2);
  });
});
