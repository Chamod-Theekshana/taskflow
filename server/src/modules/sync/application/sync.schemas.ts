import { z } from '../../../core/http/zod.js';
import {
  isoDateTime,
  SettingsSchema,
  timeOfDaySchema,
  timezoneSchema,
} from '../../settings/application/settings.schemas.js';
import {
  dateSchema,
  SubtaskInputSchema,
  TaskSchema,
} from '../../tasks/application/task.schemas.js';
import { MAX_SUBTASKS, PRIORITIES, REPEAT_RULES } from '../../tasks/domain/task.js';

/** A full task as the app stores it. Everything is required: sync sends whole aggregates. */
export const SyncTaskSchema = z
  .object({
    id: z.uuid(),
    title: z.string().trim().min(1).max(200),
    description: z.string().max(20_000),
    dueDate: dateSchema,
    dueTime: timeOfDaySchema.nullable(),
    isAllDay: z.boolean(),
    timezone: timezoneSchema,
    priority: z.enum(PRIORITIES),
    category: z.string().trim().max(100),
    isCompleted: z.boolean(),
    completedAt: isoDateTime.nullable(),
    reminder: z.boolean(),
    reminderMinutes: z.number().int().min(0).max(10_080),
    repeat: z.enum(REPEAT_RULES),
    subtasks: z.array(SubtaskInputSchema).max(MAX_SUBTASKS),
    createdAt: isoDateTime,
    updatedAt: isoDateTime,
  })
  .openapi('SyncTask');

export const ChangeSchema = z
  .discriminatedUnion('op', [
    z.object({ op: z.literal('upsert'), task: SyncTaskSchema }),
    z.object({ op: z.literal('delete'), id: z.uuid(), deletedAt: isoDateTime }),
  ])
  .openapi('SyncChange');

export type SyncChange = z.output<typeof ChangeSchema>;
export type SyncTaskInput = z.output<typeof SyncTaskSchema>;

export const MAX_CHANGES_PER_PUSH = 200;

/**
 * Changes are validated one by one in the service, so a single bad row can't
 * block the rest of the queue forever.
 */
export const PushRequestSchema = z
  .object({
    changes: z
      .array(z.unknown())
      .max(MAX_CHANGES_PER_PUSH)
      .default([])
      .openapi({ type: 'array', items: { $ref: '#/components/schemas/SyncChange' } }),
    settings: z
      .unknown()
      .optional()
      .openapi({
        type: 'object',
        description:
          'Local settings in the `SettingsPatch` shape; send `updatedAt` so the newest edit wins. ' +
          'Invalid settings are reported as `rejected` without failing the push.',
      }),
  })
  .openapi('SyncPushRequest');

export const ChangeResultSchema = z
  .object({
    id: z.string(),
    status: z.enum(['applied', 'stale', 'rejected']).openapi({
      description:
        '`stale`: the server has a newer version (it comes with the next pull). `rejected`: invalid, do not retry.',
    }),
    reason: z.string().optional(),
  })
  .openapi('SyncChangeResult');

export const PushResponseSchema = z
  .object({
    results: z.array(ChangeResultSchema),
    settings: z.enum(['applied', 'stale', 'rejected']).nullable(),
  })
  .openapi('SyncPushResponse');

export const PullQuerySchema = z.object({
  cursor: z.coerce
    .number()
    .int()
    .min(0)
    .default(0)
    .openapi({ description: 'Last `cursor` received; 0 for everything.' }),
  limit: z.coerce.number().int().min(1).max(1000).default(500),
});

export const PullResponseSchema = z
  .object({
    tasks: z
      .array(TaskSchema)
      .openapi({ description: 'Changed tasks, tombstones (deletedAt set) included.' }),
    settings: SettingsSchema.nullable(),
    cursor: z.number().int(),
    hasMore: z.boolean(),
  })
  .openapi('SyncPullResponse');

export type ChangeResult = z.infer<typeof ChangeResultSchema>;
