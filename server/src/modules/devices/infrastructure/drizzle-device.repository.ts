import { and, eq, inArray, isNotNull, lt, ne, sql } from 'drizzle-orm';

import type { Database } from '../../../core/db/client.js';
import { devices, type DeviceRow } from '../../../core/db/schema.js';
import type { Device, DeviceRegistration, DeviceRepository, Platform } from '../domain/device.js';

function toDomain(row: DeviceRow): Device {
  return {
    id: row.id,
    userId: row.userId,
    installationId: row.installationId,
    platform: row.platform as Platform,
    pushToken: row.pushToken,
    appVersion: row.appVersion,
    timezone: row.timezone,
    localReminders: row.localReminders,
    lastPulledSeq: Number(row.lastPulledSeq),
    lastSeenAt: row.lastSeenAt,
    createdAt: row.createdAt,
  };
}

export class DrizzleDeviceRepository implements DeviceRepository {
  constructor(private readonly db: Database) {}

  async register(userId: string, r: DeviceRegistration, now: Date): Promise<Device> {
    return this.db.transaction(async (tx) => {
      const token = r.pushToken ?? null;
      if (token) {
        await tx
          .update(devices)
          .set({ pushToken: null, updatedAt: now })
          .where(
            and(
              eq(devices.pushToken, token),
              sql`not (${devices.userId} = ${userId} and ${devices.installationId} = ${r.installationId})`,
            ),
          );
      }
      const values = {
        platform: r.platform,
        ...(r.pushToken !== undefined ? { pushToken: token } : {}),
        ...(r.appVersion !== undefined ? { appVersion: r.appVersion } : {}),
        ...(r.timezone !== undefined ? { timezone: r.timezone } : {}),
        localReminders: r.localReminders,
        lastSeenAt: now,
        updatedAt: now,
      };
      const [row] = await tx
        .insert(devices)
        .values({ userId, installationId: r.installationId, ...values })
        .onConflictDoUpdate({ target: [devices.userId, devices.installationId], set: values })
        .returning();
      if (!row) throw new Error('Device upsert returned no row');
      return toDomain(row);
    });
  }

  async remove(userId: string, installationId: string): Promise<boolean> {
    const deleted = await this.db
      .delete(devices)
      .where(and(eq(devices.userId, userId), eq(devices.installationId, installationId)))
      .returning({ id: devices.id });
    return deleted.length > 0;
  }

  async markPulled(userId: string, installationId: string, seq: number, now: Date): Promise<void> {
    await this.db
      .insert(devices)
      .values({ userId, installationId, lastPulledSeq: seq, lastSeenAt: now })
      .onConflictDoUpdate({
        target: [devices.userId, devices.installationId],
        set: {
          // Never move backwards if two pulls finish out of order.
          lastPulledSeq: sql`greatest(${devices.lastPulledSeq}, ${seq})`,
          lastSeenAt: now,
        },
      });
  }

  async pushTargets(userId: string, excludeInstallationId?: string): Promise<Device[]> {
    const rows = await this.db
      .select()
      .from(devices)
      .where(
        and(
          eq(devices.userId, userId),
          isNotNull(devices.pushToken),
          excludeInstallationId ? ne(devices.installationId, excludeInstallationId) : undefined,
        ),
      );
    return rows.map(toDomain);
  }

  async clearPushTokens(tokens: string[]): Promise<void> {
    if (tokens.length === 0) return;
    await this.db
      .update(devices)
      .set({ pushToken: null })
      .where(inArray(devices.pushToken, tokens));
  }

  async deleteInactive(before: Date): Promise<number> {
    const deleted = await this.db
      .delete(devices)
      .where(lt(devices.lastSeenAt, before))
      .returning({ id: devices.id });
    return deleted.length;
  }
}
