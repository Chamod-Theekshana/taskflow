import { and, count, eq, isNull, sql } from 'drizzle-orm';

import type { Database } from '../../../core/db/client.js';
import { devices, settings, tasks } from '../../../core/db/schema.js';
import type { DigestCandidate, DigestQueries } from '../domain/digest-queries.js';

export class DrizzleDigestQueries implements DigestQueries {
  constructor(private readonly db: Database) {}

  async candidates(): Promise<DigestCandidate[]> {
    return this.db
      .select({
        userId: settings.userId,
        timezone: settings.timezone,
        digestTime: settings.dailyDigestTime,
      })
      .from(settings)
      .where(
        and(
          eq(settings.dailyDigestEnabled, true),
          eq(settings.notificationsEnabled, true),
          sql`exists (select 1 from ${devices} where ${devices.userId} = ${settings.userId} and ${devices.pushToken} is not null and ${devices.localReminders} = false)`,
        ),
      );
  }

  async dayCounts(userId: string, date: string): Promise<{ due: number; high: number }> {
    const [row] = await this.db
      .select({
        due: count(),
        high: sql<number>`count(*) filter (where ${tasks.priority} = 'high')`.mapWith(Number),
      })
      .from(tasks)
      .where(
        and(
          eq(tasks.userId, userId),
          eq(tasks.dueDate, date),
          eq(tasks.isCompleted, false),
          isNull(tasks.deletedAt),
        ),
      );
    return { due: Number(row?.due ?? 0), high: Number(row?.high ?? 0) };
  }
}
