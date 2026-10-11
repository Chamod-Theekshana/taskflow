import { and, desc, eq, isNull, lt } from 'drizzle-orm';

import type { Database } from '../../../core/db/client.js';
import { notifications, type NotificationRow } from '../../../core/db/schema.js';
import { executor, type TxContext } from '../../../core/db/unit-of-work.js';
import type {
  AppNotification,
  NewNotification,
  NotificationRepository,
  NotificationType,
} from '../domain/notification.js';

function toDomain(row: NotificationRow): AppNotification {
  return {
    id: row.id,
    userId: row.userId,
    type: row.type as NotificationType,
    title: row.title,
    body: row.body,
    data: row.data,
    taskId: row.taskId,
    readAt: row.readAt,
    createdAt: row.createdAt,
  };
}

export class DrizzleNotificationRepository implements NotificationRepository {
  constructor(private readonly db: Database) {}

  async createIfAbsent(n: NewNotification, tx?: TxContext): Promise<AppNotification | null> {
    const rows = await executor(this.db, tx)
      .insert(notifications)
      .values({
        userId: n.userId,
        type: n.type,
        title: n.title.slice(0, 200),
        body: n.body,
        data: n.data ?? {},
        taskId: n.taskId ?? null,
        dedupeKey: n.dedupeKey ?? null,
      })
      .onConflictDoNothing()
      .returning();
    return rows[0] ? toDomain(rows[0]) : null;
  }

  async list(
    userId: string,
    options: { unreadOnly: boolean; limit: number; before?: Date },
  ): Promise<AppNotification[]> {
    const rows = await this.db
      .select()
      .from(notifications)
      .where(
        and(
          eq(notifications.userId, userId),
          options.unreadOnly ? isNull(notifications.readAt) : undefined,
          options.before ? lt(notifications.createdAt, options.before) : undefined,
        ),
      )
      .orderBy(desc(notifications.createdAt))
      .limit(options.limit);
    return rows.map(toDomain);
  }

  async markRead(userId: string, id: string, now: Date): Promise<boolean> {
    const rows = await this.db
      .update(notifications)
      .set({ readAt: now })
      .where(
        and(
          eq(notifications.userId, userId),
          eq(notifications.id, id),
          isNull(notifications.readAt),
        ),
      )
      .returning({ id: notifications.id });
    if (rows.length > 0) return true;
    // Already read counts as success; only a missing notification is not.
    const existing = await this.db
      .select({ id: notifications.id })
      .from(notifications)
      .where(and(eq(notifications.userId, userId), eq(notifications.id, id)))
      .limit(1);
    return existing.length > 0;
  }

  async markAllRead(userId: string, now: Date): Promise<number> {
    const rows = await this.db
      .update(notifications)
      .set({ readAt: now })
      .where(and(eq(notifications.userId, userId), isNull(notifications.readAt)))
      .returning({ id: notifications.id });
    return rows.length;
  }

  async recordPushes(id: string, count: number): Promise<void> {
    await this.db.update(notifications).set({ pushedCount: count }).where(eq(notifications.id, id));
  }

  async deleteOlderThan(before: Date): Promise<number> {
    const rows = await this.db
      .delete(notifications)
      .where(lt(notifications.createdAt, before))
      .returning({ id: notifications.id });
    return rows.length;
  }
}
