import { and, eq, gt, sql } from 'drizzle-orm';

import type { Database } from '../../../core/db/client.js';
import { settings, type SettingsRow } from '../../../core/db/schema.js';
import { executor, type TxContext } from '../../../core/db/unit-of-work.js';
import type { Priority } from '../../tasks/domain/task.js';
import type {
  SettingsRepository,
  SettingsValues,
  ThemeMode,
  UserSettings,
} from '../domain/settings.js';

function toDomain(row: SettingsRow): UserSettings {
  return {
    notificationsEnabled: row.notificationsEnabled,
    dailyDigestEnabled: row.dailyDigestEnabled,
    dailyDigestTime: row.dailyDigestTime,
    themeMode: row.themeMode as ThemeMode,
    defaultPriority: row.defaultPriority as Priority,
    dailyGoal: row.dailyGoal,
    customCategories: row.customCategories,
    timezone: row.timezone,
    updatedAt: row.updatedAt,
    changeSeq: Number(row.changeSeq),
  };
}

export class DrizzleSettingsRepository implements SettingsRepository {
  constructor(private readonly db: Database) {}

  async get(userId: string, tx?: TxContext): Promise<UserSettings | null> {
    const rows = await executor(this.db, tx)
      .select()
      .from(settings)
      .where(eq(settings.userId, userId))
      .limit(1);
    return rows[0] ? toDomain(rows[0]) : null;
  }

  async save(userId: string, values: SettingsValues, tx: TxContext): Promise<UserSettings> {
    const row = {
      notificationsEnabled: values.notificationsEnabled,
      dailyDigestEnabled: values.dailyDigestEnabled,
      dailyDigestTime: values.dailyDigestTime,
      themeMode: values.themeMode,
      defaultPriority: values.defaultPriority,
      dailyGoal: values.dailyGoal,
      customCategories: values.customCategories,
      timezone: values.timezone,
      updatedAt: values.updatedAt,
      changeSeq: sql`nextval('change_seq')`,
    };
    const [saved] = await executor(this.db, tx)
      .insert(settings)
      .values({ userId, ...row })
      .onConflictDoUpdate({ target: settings.userId, set: row })
      .returning();
    if (!saved) throw new Error('Settings upsert returned no row');
    return toDomain(saved);
  }

  async changedSince(userId: string, cursor: number, tx?: TxContext): Promise<UserSettings | null> {
    const rows = await executor(this.db, tx)
      .select()
      .from(settings)
      .where(and(eq(settings.userId, userId), gt(settings.changeSeq, cursor)))
      .limit(1);
    return rows[0] ? toDomain(rows[0]) : null;
  }
}
