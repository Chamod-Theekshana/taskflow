/**
 * The task aggregate: a task and its subtasks always change together.
 * Mirrors `Task` / `Subtask` in the app (features/tasks/domain/entities).
 */
export const PRIORITIES = ['low', 'medium', 'high'] as const;
export type Priority = (typeof PRIORITIES)[number];

export const REPEAT_RULES = ['none', 'daily', 'weekdays', 'weekly', 'monthly'] as const;
export type RepeatRule = (typeof REPEAT_RULES)[number];

export const MAX_SUBTASKS = 100;

export interface Subtask {
  id: string;
  title: string;
  isCompleted: boolean;
  position: number;
}

export interface Task {
  id: string;
  userId: string;
  title: string;
  description: string;
  /** `YYYY-MM-DD` in [timezone]. */
  dueDate: string;
  /** `HH:mm`, 24-hour; null for all-day tasks. */
  dueTime: string | null;
  isAllDay: boolean;
  timezone: string;
  /** Derived: the instant the task is due. */
  dueAt: Date;
  priority: Priority;
  category: string;
  isCompleted: boolean;
  completedAt: Date | null;
  reminder: boolean;
  reminderMinutes: number;
  /** Derived: when the reminder fires, or null. */
  remindAt: Date | null;
  reminderSentAt: Date | null;
  repeat: RepeatRule;
  createdAt: Date;
  updatedAt: Date;
  deletedAt: Date | null;
  changeSeq: number;
  subtasks: Subtask[];
}

/** The fields a client controls; everything else is derived or managed. */
export interface TaskFields {
  title: string;
  description: string;
  dueDate: string;
  dueTime: string | null;
  isAllDay: boolean;
  timezone: string;
  priority: Priority;
  category: string;
  isCompleted: boolean;
  completedAt: Date | null;
  reminder: boolean;
  reminderMinutes: number;
  repeat: RepeatRule;
  createdAt: Date;
  updatedAt: Date;
  subtasks: { id?: string; title: string; isCompleted: boolean }[];
}

/** What a repository writes: client fields plus the derived schedule. */
export interface TaskWrite extends Omit<TaskFields, 'subtasks'> {
  id: string;
  dueAt: Date;
  remindAt: Date | null;
  /** True when the reminder moved, so its push fallback must go out again. */
  resetReminder: boolean;
  subtasks: { id: string; title: string; isCompleted: boolean; position: number }[];
}

export function isOverdue(task: Pick<Task, 'isCompleted' | 'dueAt'>, now: Date): boolean {
  return !task.isCompleted && task.dueAt.getTime() < now.getTime();
}

export function effectiveCompletedAt(
  task: Pick<Task, 'isCompleted' | 'completedAt' | 'updatedAt'>,
): Date | null {
  return task.isCompleted ? (task.completedAt ?? task.updatedAt) : null;
}
