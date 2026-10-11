import { z } from '../../../core/http/zod.js';
import {
  isoDateTime,
  timeOfDaySchema,
  timezoneSchema,
} from '../../settings/application/settings.schemas.js';
import { isValidDate } from '../domain/schedule.js';
import { MAX_SUBTASKS, PRIORITIES, REPEAT_RULES, type Task } from '../domain/task.js';

export const dateSchema = z
  .string()
  .refine(isValidDate, 'Use a real date in YYYY-MM-DD format.')
  .openapi({ example: '2026-09-29' });

const title = z.string().trim().min(1, 'Give the task a title.').max(200);

export const SubtaskInputSchema = z
  .object({
    id: z.uuid().optional(),
    title: z.string().trim().min(1).max(200),
    isCompleted: z.boolean().default(false),
  })
  .openapi('SubtaskInput');

/** Body of POST /tasks. `id` lets offline clients choose the id themselves. */
export const CreateTaskSchema = z
  .object({
    id: z.uuid().optional().openapi({ description: 'Optional client-generated UUID.' }),
    title,
    description: z.string().max(20_000).default(''),
    dueDate: dateSchema,
    dueTime: timeOfDaySchema.nullable().default(null),
    isAllDay: z.boolean().default(false),
    timezone: timezoneSchema
      .optional()
      .openapi({ description: "Defaults to the user's time zone." }),
    priority: z.enum(PRIORITIES).default('medium'),
    category: z.string().trim().max(100).default(''),
    isCompleted: z.boolean().default(false),
    completedAt: isoDateTime.nullable().default(null),
    reminder: z.boolean().default(false),
    reminderMinutes: z.number().int().min(0).max(10_080).default(15),
    repeat: z.enum(REPEAT_RULES).default('none'),
    subtasks: z.array(SubtaskInputSchema).max(MAX_SUBTASKS).default([]),
    createdAt: isoDateTime.optional(),
    updatedAt: isoDateTime.optional(),
  })
  .strict()
  .openapi('CreateTaskRequest');

/** Body of PATCH /tasks/:id. Only the fields sent change. */
export const UpdateTaskSchema = z
  .object({
    title: title.optional(),
    description: z.string().max(20_000).optional(),
    dueDate: dateSchema.optional(),
    dueTime: timeOfDaySchema.nullable().optional(),
    isAllDay: z.boolean().optional(),
    timezone: timezoneSchema.optional(),
    priority: z.enum(PRIORITIES).optional(),
    category: z.string().trim().max(100).optional(),
    isCompleted: z.boolean().optional(),
    completedAt: isoDateTime.nullable().optional(),
    reminder: z.boolean().optional(),
    reminderMinutes: z.number().int().min(0).max(10_080).optional(),
    repeat: z.enum(REPEAT_RULES).optional(),
    subtasks: z.array(SubtaskInputSchema).max(MAX_SUBTASKS).optional(),
    updatedAt: isoDateTime.optional(),
  })
  .strict()
  .openapi('UpdateTaskRequest');

export const AddSubtaskSchema = z
  .object({ title: z.string().trim().min(1).max(200) })
  .openapi('AddSubtaskRequest');

export const UpdateSubtaskSchema = z
  .object({
    title: z.string().trim().min(1).max(200).optional(),
    isCompleted: z.boolean().optional(),
  })
  .strict()
  .openapi('UpdateSubtaskRequest');

export const ListTasksQuerySchema = z.object({
  status: z.enum(['open', 'completed', 'all']).default('all'),
  from: dateSchema.optional().openapi({ description: 'Due on or after (YYYY-MM-DD).' }),
  to: dateSchema.optional().openapi({ description: 'Due on or before (YYYY-MM-DD).' }),
  q: z
    .string()
    .trim()
    .min(1)
    .max(100)
    .optional()
    .openapi({ description: 'Searches title, notes, category and subtasks.' }),
  priority: z.enum(PRIORITIES).optional(),
  category: z.string().trim().min(1).max(100).optional(),
  limit: z.coerce.number().int().min(1).max(200).default(50),
  cursor: z
    .string()
    .max(300)
    .optional()
    .openapi({ description: '`meta.nextCursor` of the previous page.' }),
});

export const SubtaskSchema = z
  .object({
    id: z.uuid(),
    title: z.string(),
    isCompleted: z.boolean(),
    position: z.number().int(),
  })
  .openapi('Subtask');

const dateTime = z.string().openapi({ format: 'date-time' });

export const TaskSchema = z
  .object({
    id: z.uuid(),
    title: z.string(),
    description: z.string(),
    dueDate: z.string().openapi({ example: '2026-09-29' }),
    dueTime: z.string().nullable().openapi({ example: '14:00' }),
    isAllDay: z.boolean(),
    timezone: z.string(),
    dueAt: dateTime.openapi({ description: 'Derived instant the task is due.' }),
    priority: z.enum(PRIORITIES),
    category: z.string(),
    isCompleted: z.boolean(),
    completedAt: dateTime.nullable(),
    reminder: z.boolean(),
    reminderMinutes: z.number().int(),
    remindAt: dateTime.nullable().openapi({ description: 'Derived instant the reminder fires.' }),
    repeat: z.enum(REPEAT_RULES),
    subtasks: z.array(SubtaskSchema),
    createdAt: dateTime,
    updatedAt: dateTime,
    deletedAt: dateTime.nullable().openapi({ description: 'Set on tombstones (sync only).' }),
  })
  .openapi('Task');

export type CreateTaskInput = z.output<typeof CreateTaskSchema>;
export type UpdateTaskInput = z.output<typeof UpdateTaskSchema>;
export type ListTasksQuery = z.output<typeof ListTasksQuerySchema>;
export type TaskDto = z.infer<typeof TaskSchema>;

export function toTaskDto(task: Task): TaskDto {
  return {
    id: task.id,
    title: task.title,
    description: task.description,
    dueDate: task.dueDate,
    dueTime: task.dueTime,
    isAllDay: task.isAllDay,
    timezone: task.timezone,
    dueAt: task.dueAt.toISOString(),
    priority: task.priority,
    category: task.category,
    isCompleted: task.isCompleted,
    completedAt: task.completedAt?.toISOString() ?? null,
    reminder: task.reminder,
    reminderMinutes: task.reminderMinutes,
    remindAt: task.remindAt?.toISOString() ?? null,
    repeat: task.repeat,
    subtasks: task.subtasks.map((s) => ({
      id: s.id,
      title: s.title,
      isCompleted: s.isCompleted,
      position: s.position,
    })),
    createdAt: task.createdAt.toISOString(),
    updatedAt: task.updatedAt.toISOString(),
    deletedAt: task.deletedAt?.toISOString() ?? null,
  };
}
