import type { Logger } from '../../../core/logger.js';
import type { DeviceRepository } from '../../devices/domain/device.js';
import type { ChangeNotifier } from '../../sync/domain/change-notifier.js';
import type { PushDispatcher } from './push-dispatcher.js';

interface Pending {
  timer: NodeJS.Timeout;
  /** The device that made every change so far, or null once two devices were involved. */
  origin: string | null;
}

/**
 * After a change, sends a silent `{ type: 'sync' }` push to the user's other
 * devices so they pull right away (and reschedule their local reminders).
 *
 * Bursts are coalesced: many edits within [delayMs] produce one push.
 */
export class SyncPushNotifier implements ChangeNotifier {
  private readonly pending = new Map<string, Pending>();
  private readonly inFlight = new Set<Promise<void>>();

  constructor(
    private readonly devices: DeviceRepository,
    private readonly push: PushDispatcher,
    private readonly logger: Logger,
    private readonly delayMs = 2_000,
  ) {}

  changed(userId: string, originInstallationId?: string): void {
    const origin = originInstallationId ?? null;
    const existing = this.pending.get(userId);
    if (existing) {
      if (existing.origin !== origin) existing.origin = null;
      return;
    }
    const timer = setTimeout(() => this.flush(userId), this.delayMs);
    timer.unref();
    this.pending.set(userId, { timer, origin });
  }

  /** Sends everything that is waiting (tests, shutdown). */
  async flushAll(): Promise<void> {
    for (const userId of [...this.pending.keys()]) this.flush(userId);
    await Promise.allSettled([...this.inFlight]);
  }

  private flush(userId: string): void {
    const entry = this.pending.get(userId);
    if (!entry) return;
    clearTimeout(entry.timer);
    this.pending.delete(userId);

    const work = this.send(userId, entry.origin ?? undefined)
      .catch((error: unknown) => this.logger.warn({ err: error, userId }, 'Sync push failed'))
      .finally(() => this.inFlight.delete(work));
    this.inFlight.add(work);
  }

  private async send(userId: string, origin?: string): Promise<void> {
    const targets = await this.devices.pushTargets(userId, origin);
    await this.push.deliver(
      targets.map((d) => ({
        token: d.pushToken!,
        kind: 'silent' as const,
        collapseKey: 'sync',
        data: { type: 'sync' },
      })),
    );
  }
}
