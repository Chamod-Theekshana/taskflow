import { randomUUID } from 'node:crypto';

import { computeDueAt, computeRemindAt } from './schedule.js';
import type { Task, TaskFields, TaskWrite } from './task.js';

/**
 * Builds what gets stored from what a client sent: trims text, keeps
 * completion consistent, derives `dueAt` / `remindAt` and decides whether the
 * reminder has to be sent again.
 */
export function prepareTaskWrite(
  fields: TaskFields & { id?: string },
  existing: Task | null,
  now: Date,
): TaskWrite {
  const title = fields.title.trim();
  const isCompleted = fields.isCompleted;
  const completedAt = isCompleted ? (fields.completedAt ?? existing?.completedAt ?? now) : null;
  const dueTime = fields.isAllDay ? null : fields.dueTime;

  const schedule = {
    dueDate: fields.dueDate,
    dueTime,
    isAllDay: fields.isAllDay,
    timezone: fields.timezone,
  };
  const dueAt = computeDueAt(schedule);
  const remindAt = computeRemindAt({
    ...schedule,
    reminder: fields.reminder,
    reminderMinutes: fields.reminderMinutes,
  });

  const previous = existing?.remindAt?.getTime() ?? null;
  const resetReminder = (remindAt?.getTime() ?? null) !== previous;

  return {
    id: fields.id ?? existing?.id ?? randomUUID(),
    title,
    description: fields.description.trim(),
    dueDate: fields.dueDate,
    dueTime,
    isAllDay: fields.isAllDay,
    timezone: fields.timezone,
    dueAt,
    priority: fields.priority,
    category: fields.category.trim(),
    isCompleted,
    completedAt,
    reminder: fields.reminder,
    reminderMinutes: fields.reminderMinutes,
    remindAt,
    resetReminder,
    repeat: fields.repeat,
    createdAt: existing?.createdAt ?? fields.createdAt,
    updatedAt: fields.updatedAt,
    subtasks: fields.subtasks
      .map((s) => ({ ...s, title: s.title.trim() }))
      .filter((s) => s.title.length > 0)
      .map((s, position) => ({
        id: s.id ?? randomUUID(),
        title: s.title,
        isCompleted: s.isCompleted,
        position,
      })),
  };
}

/** A stored task as editable fields, e.g. to apply a partial update on top. */
export function toFields(task: Task): TaskFields {
  return {
    title: task.title,
    description: task.description,
    dueDate: task.dueDate,
    dueTime: task.dueTime,
    isAllDay: task.isAllDay,
    timezone: task.timezone,
    priority: task.priority,
    category: task.category,
    isCompleted: task.isCompleted,
    completedAt: task.completedAt,
    reminder: task.reminder,
    reminderMinutes: task.reminderMinutes,
    repeat: task.repeat,
    createdAt: task.createdAt,
    updatedAt: task.updatedAt,
    subtasks: task.subtasks.map((s) => ({ id: s.id, title: s.title, isCompleted: s.isCompleted })),
  };
}
