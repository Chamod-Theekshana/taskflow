import { sql } from 'drizzle-orm';
import {
  bigint,
  boolean,
  check,
  date,
  index,
  integer,
  jsonb,
  pgSequence,
  pgTable,
  text,
  timestamp,
  uniqueIndex,
  uuid,
  varchar,
} from 'drizzle-orm/pg-core';

/**
 * Database schema (Neon / PostgreSQL 16+), the single source of truth for the
 * generated SQL migrations in /drizzle.
 *
 * Sync model: every write to a task or to a user's settings takes a fresh
 * value from the global `change_seq` sequence. Clients remember the highest
 * value they have seen and ask for "everything after N", so a pull is one
 * indexed range scan. Deleted tasks stay behind as tombstones (`deleted_at`)
 * until every device has pulled them.
 */

export const changeSeq = pgSequence('change_seq', { startWith: 1, increment: 1 });

const nextChangeSeq = sql`nextval('change_seq')`;

const timestamps = {
  createdAt: timestamp('created_at', { withTimezone: true, mode: 'date' }).notNull().defaultNow(),
  updatedAt: timestamp('updated_at', { withTimezone: true, mode: 'date' }).notNull().defaultNow(),
};

// ---------------------------------------------------------------- users

export const users = pgTable(
  'users',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    /** Stored lower-cased, so the unique index is case-insensitive. */
    email: varchar('email', { length: 254 }).notNull(),
    fullName: varchar('full_name', { length: 120 }).notNull(),
    passwordHash: text('password_hash').notNull(),
    passwordChangedAt: timestamp('password_changed_at', { withTimezone: true, mode: 'date' }),
    ...timestamps,
  },
  (t) => [uniqueIndex('users_email_key').on(t.email)],
);

export const refreshTokens = pgTable(
  'refresh_tokens',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    userId: uuid('user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    /** All tokens issued from one sign-in share a family; reuse of a rotated token revokes it. */
    familyId: uuid('family_id').notNull(),
    /** SHA-256 of the opaque token. The token itself is never stored. */
    tokenHash: varchar('token_hash', { length: 64 }).notNull(),
    expiresAt: timestamp('expires_at', { withTimezone: true, mode: 'date' }).notNull(),
    revokedAt: timestamp('revoked_at', { withTimezone: true, mode: 'date' }),
    replacedById: uuid('replaced_by_id'),
    installationId: varchar('installation_id', { length: 64 }),
    userAgent: varchar('user_agent', { length: 400 }),
    ip: varchar('ip', { length: 64 }),
    createdAt: timestamp('created_at', { withTimezone: true, mode: 'date' }).notNull().defaultNow(),
  },
  (t) => [
    uniqueIndex('refresh_tokens_token_hash_key').on(t.tokenHash),
    index('refresh_tokens_user_idx').on(t.userId),
    index('refresh_tokens_family_idx').on(t.familyId),
  ],
);

// ---------------------------------------------------------------- settings

export const settings = pgTable(
  'settings',
  {
    userId: uuid('user_id')
      .primaryKey()
      .references(() => users.id, { onDelete: 'cascade' }),
    notificationsEnabled: boolean('notifications_enabled').notNull().default(true),
    dailyDigestEnabled: boolean('daily_digest_enabled').notNull().default(false),
    /** `HH:mm`, 24-hour, in the user's time zone. */
    dailyDigestTime: varchar('daily_digest_time', { length: 5 }).notNull().default('08:00'),
    themeMode: varchar('theme_mode', { length: 10 }).notNull().default('dark'),
    defaultPriority: varchar('default_priority', { length: 10 }).notNull().default('medium'),
    dailyGoal: integer('daily_goal').notNull().default(4),
    customCategories: jsonb('custom_categories')
      .$type<string[]>()
      .notNull()
      .default(sql`'[]'::jsonb`),
    /** IANA zone, e.g. `Asia/Colombo`. Used for the digest and server-side stats. */
    timezone: varchar('timezone', { length: 64 }).notNull().default('UTC'),
    /** Last change as seen by the client that made it (last-write-wins). */
    updatedAt: timestamp('updated_at', { withTimezone: true, mode: 'date' }).notNull().defaultNow(),
    changeSeq: bigint('change_seq', { mode: 'number' }).notNull().default(nextChangeSeq),
  },
  (t) => [
    check('settings_theme_mode_check', sql`${t.themeMode} in ('dark', 'light', 'system')`),
    check('settings_priority_check', sql`${t.defaultPriority} in ('low', 'medium', 'high')`),
    check('settings_daily_goal_check', sql`${t.dailyGoal} between 1 and 20`),
  ],
);

// ---------------------------------------------------------------- tasks

export const tasks = pgTable(
  'tasks',
  {
    /** Client generated (UUID v4) so tasks can be created offline. */
    id: uuid('id').primaryKey().defaultRandom(),
    userId: uuid('user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    title: varchar('title', { length: 200 }).notNull(),
    description: text('description').notNull().default(''),
    /** Calendar day in the task's time zone. */
    dueDate: date('due_date', { mode: 'string' }).notNull(),
    /** `HH:mm`, 24-hour; null for all-day tasks. */
    dueTime: varchar('due_time', { length: 5 }),
    isAllDay: boolean('is_all_day').notNull().default(false),
    timezone: varchar('timezone', { length: 64 }).notNull().default('UTC'),
    /** The moment the task is due (end of day for all-day tasks). Derived. */
    dueAt: timestamp('due_at', { withTimezone: true, mode: 'date' }).notNull(),
    priority: varchar('priority', { length: 10 }).notNull().default('medium'),
    category: varchar('category', { length: 100 }).notNull().default(''),
    isCompleted: boolean('is_completed').notNull().default(false),
    completedAt: timestamp('completed_at', { withTimezone: true, mode: 'date' }),
    reminder: boolean('reminder').notNull().default(false),
    reminderMinutes: integer('reminder_minutes').notNull().default(15),
    /** When the reminder fires; null without a reminder. Derived. */
    remindAt: timestamp('remind_at', { withTimezone: true, mode: 'date' }),
    /** Set once the push fallback for the current `remind_at` went out. */
    reminderSentAt: timestamp('reminder_sent_at', { withTimezone: true, mode: 'date' }),
    repeatRule: varchar('repeat_rule', { length: 10 }).notNull().default('none'),
    /** Client clock; used for last-write-wins between devices. */
    createdAt: timestamp('created_at', { withTimezone: true, mode: 'date' }).notNull().defaultNow(),
    updatedAt: timestamp('updated_at', { withTimezone: true, mode: 'date' }).notNull().defaultNow(),
    /** Tombstone for sync. Tasks are never hard-deleted by the API. */
    deletedAt: timestamp('deleted_at', { withTimezone: true, mode: 'date' }),
    serverUpdatedAt: timestamp('server_updated_at', { withTimezone: true, mode: 'date' })
      .notNull()
      .defaultNow(),
    changeSeq: bigint('change_seq', { mode: 'number' }).notNull().default(nextChangeSeq),
  },
  (t) => [
    index('tasks_user_change_seq_idx').on(t.userId, t.changeSeq),
    index('tasks_user_due_idx').on(t.userId, t.dueAt),
    index('tasks_pending_reminder_idx')
      .on(t.remindAt)
      .where(
        sql`${t.reminder} = true and ${t.isCompleted} = false and ${t.deletedAt} is null and ${t.reminderSentAt} is null`,
      ),
    check('tasks_priority_check', sql`${t.priority} in ('low', 'medium', 'high')`),
    check(
      'tasks_repeat_rule_check',
      sql`${t.repeatRule} in ('none', 'daily', 'weekdays', 'weekly', 'monthly')`,
    ),
    check('tasks_reminder_minutes_check', sql`${t.reminderMinutes} between 0 and 10080`),
  ],
);

export const subtasks = pgTable(
  'subtasks',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    taskId: uuid('task_id')
      .notNull()
      .references(() => tasks.id, { onDelete: 'cascade' }),
    title: varchar('title', { length: 200 }).notNull(),
    isCompleted: boolean('is_completed').notNull().default(false),
    position: integer('position').notNull().default(0),
  },
  (t) => [index('subtasks_task_idx').on(t.taskId, t.position)],
);

// ---------------------------------------------------------------- devices

export const devices = pgTable(
  'devices',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    userId: uuid('user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    /** Random id the app generates once per install (`X-Device-Id`). */
    installationId: varchar('installation_id', { length: 64 }).notNull(),
    platform: varchar('platform', { length: 10 }).notNull().default('other'),
    /** Firebase Cloud Messaging registration token. */
    pushToken: text('push_token'),
    appVersion: varchar('app_version', { length: 32 }),
    timezone: varchar('timezone', { length: 64 }),
    /**
     * The app schedules reminders and the digest on the device itself.
     * Such devices only get a reminder push when they have not synced the
     * latest version of the task yet.
     */
    localReminders: boolean('local_reminders').notNull().default(true),
    /** Highest change_seq this device has pulled. */
    lastPulledSeq: bigint('last_pulled_seq', { mode: 'number' }).notNull().default(0),
    lastSeenAt: timestamp('last_seen_at', { withTimezone: true, mode: 'date' })
      .notNull()
      .defaultNow(),
    ...timestamps,
  },
  (t) => [
    uniqueIndex('devices_user_installation_key').on(t.userId, t.installationId),
    uniqueIndex('devices_push_token_key')
      .on(t.pushToken)
      .where(sql`${t.pushToken} is not null`),
    check('devices_platform_check', sql`${t.platform} in ('android', 'ios', 'web', 'other')`),
  ],
);

// ---------------------------------------------------------------- notifications

export const notifications = pgTable(
  'notifications',
  {
    id: uuid('id').primaryKey().defaultRandom(),
    userId: uuid('user_id')
      .notNull()
      .references(() => users.id, { onDelete: 'cascade' }),
    type: varchar('type', { length: 20 }).notNull(),
    title: varchar('title', { length: 200 }).notNull(),
    body: text('body').notNull().default(''),
    data: jsonb('data')
      .$type<Record<string, string>>()
      .notNull()
      .default(sql`'{}'::jsonb`),
    taskId: uuid('task_id').references(() => tasks.id, { onDelete: 'set null' }),
    /** Makes a notification idempotent, e.g. `reminder:<task>:<remind_at>`. */
    dedupeKey: varchar('dedupe_key', { length: 200 }),
    pushedCount: integer('pushed_count').notNull().default(0),
    readAt: timestamp('read_at', { withTimezone: true, mode: 'date' }),
    createdAt: timestamp('created_at', { withTimezone: true, mode: 'date' }).notNull().defaultNow(),
  },
  (t) => [
    index('notifications_user_created_idx').on(t.userId, t.createdAt),
    uniqueIndex('notifications_dedupe_key').on(t.dedupeKey),
    check('notifications_type_check', sql`${t.type} in ('reminder', 'digest', 'system', 'test')`),
  ],
);

export type UserRow = typeof users.$inferSelect;
export type RefreshTokenRow = typeof refreshTokens.$inferSelect;
export type SettingsRow = typeof settings.$inferSelect;
export type TaskRow = typeof tasks.$inferSelect;
export type SubtaskRow = typeof subtasks.$inferSelect;
export type DeviceRow = typeof devices.$inferSelect;
export type NotificationRow = typeof notifications.$inferSelect;
