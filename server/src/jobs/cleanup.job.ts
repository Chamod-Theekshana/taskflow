import type { Clock } from '../core/utils/clock.js';
import type { RefreshTokenRepository } from '../modules/auth/domain/refresh-token.js';
import type { DeviceRepository } from '../modules/devices/domain/device.js';
import type { NotificationRepository } from '../modules/notifications/domain/notification.js';
import type { TaskRepository } from '../modules/tasks/domain/task.repository.js';

const DAY = 86_400_000;

/** Housekeeping, hourly: old tokens, synced tombstones, old inbox entries, abandoned devices. */
export class CleanupJob {
  constructor(
    private readonly refreshTokens: RefreshTokenRepository,
    private readonly tasks: TaskRepository,
    private readonly notifications: NotificationRepository,
    private readonly devices: DeviceRepository,
    private readonly clock: Clock,
  ) {}

  async run(): Promise<Record<string, number>> {
    const now = this.clock.now().getTime();
    return {
      refreshTokens: await this.refreshTokens.deleteStale(new Date(now - 7 * DAY)),
      tombstones: await this.tasks.purgeTombstones(new Date(now - 30 * DAY)),
      notifications: await this.notifications.deleteOlderThan(new Date(now - 90 * DAY)),
      devices: await this.devices.deleteInactive(new Date(now - 180 * DAY)),
    };
  }
}
