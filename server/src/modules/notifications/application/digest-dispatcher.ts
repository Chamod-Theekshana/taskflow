import { DateTime } from 'luxon';

import type { Clock } from '../../../core/utils/clock.js';
import type { DeviceRepository } from '../../devices/domain/device.js';
import type { DigestQueries } from '../domain/digest-queries.js';
import type { NotificationRepository } from '../domain/notification.js';
import type { PushDispatcher } from './push-dispatcher.js';

/** The digest goes out if the job runs within this many minutes after the chosen time. */
const WINDOW_MINUTES = 15;

export const DIGEST_CHANNEL = 'daily_digest';

/**
 * Morning digest for clients that don't build it themselves (the mobile app
 * schedules its own local digest). One per user per local day, guaranteed by
 * the `digest:<user>:<date>` dedupe key.
 */
export class DigestDispatcher {
  constructor(
    private readonly queries: DigestQueries,
    private readonly devices: DeviceRepository,
    private readonly notifications: NotificationRepository,
    private readonly push: PushDispatcher,
    private readonly clock: Clock,
  ) {}

  async run(): Promise<{ sent: number }> {
    const now = this.clock.now();
    let sent = 0;

    for (const candidate of await this.queries.candidates()) {
      const local = DateTime.fromJSDate(now, { zone: candidate.timezone });
      const [hour, minute] = candidate.digestTime.split(':').map(Number);
      const target = local.set({ hour: hour ?? 8, minute: minute ?? 0, second: 0, millisecond: 0 });
      const minutesLate = local.diff(target, 'minutes').minutes;
      if (minutesLate < 0 || minutesLate >= WINDOW_MINUTES) continue;

      const date = local.toISODate()!;
      const counts = await this.queries.dayCounts(candidate.userId, date);
      const body =
        counts.due === 0
          ? 'Nothing is due today.'
          : `${counts.due} ${counts.due === 1 ? 'task' : 'tasks'} due today` +
            (counts.high > 0 ? ` · ${counts.high} high priority` : '');

      const notification = await this.notifications.createIfAbsent({
        userId: candidate.userId,
        type: 'digest',
        title: 'Your day at a glance',
        body,
        data: { type: 'digest', date },
        dedupeKey: `digest:${candidate.userId}:${date}`,
      });
      if (!notification) continue;

      const targets = (await this.devices.pushTargets(candidate.userId)).filter(
        (d) => !d.localReminders,
      );
      const results = await this.push.deliver(
        targets.map((d) => ({
          token: d.pushToken!,
          kind: 'alert' as const,
          title: notification.title,
          body,
          channelId: DIGEST_CHANNEL,
          collapseKey: 'daily-digest',
          data: { type: 'digest', date, notificationId: notification.id },
        })),
      );
      const ok = results.filter((r) => r.success).length;
      if (ok > 0) await this.notifications.recordPushes(notification.id, ok);
      sent += 1;
    }
    return { sent };
  }
}
