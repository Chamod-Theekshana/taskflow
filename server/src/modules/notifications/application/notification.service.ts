import { NotFoundError } from '../../../core/errors/app-error.js';
import type { Clock } from '../../../core/utils/clock.js';
import type { DeviceRepository } from '../../devices/domain/device.js';
import type { AppNotification, NotificationRepository } from '../domain/notification.js';
import type { PushDispatcher } from './push-dispatcher.js';
import { REMINDER_CHANNEL } from './reminder-dispatcher.js';

export class NotificationService {
  constructor(
    private readonly notifications: NotificationRepository,
    private readonly devices: DeviceRepository,
    private readonly push: PushDispatcher,
    private readonly clock: Clock,
  ) {}

  list(
    userId: string,
    options: { unreadOnly: boolean; limit: number; before?: Date },
  ): Promise<AppNotification[]> {
    return this.notifications.list(userId, options);
  }

  async markRead(userId: string, id: string): Promise<void> {
    if (!(await this.notifications.markRead(userId, id, this.clock.now()))) {
      throw new NotFoundError('Notification', 'notification_not_found');
    }
  }

  markAllRead(userId: string): Promise<number> {
    return this.notifications.markAllRead(userId, this.clock.now());
  }

  /** Pushes a test notification to every device of the user that has a push token. */
  async sendTest(
    userId: string,
  ): Promise<{ devices: number; delivered: number; pushConfigured: boolean }> {
    const notification = await this.notifications.createIfAbsent({
      userId,
      type: 'test',
      title: 'TaskFlow',
      body: 'Push notifications are working.',
      data: { type: 'test' },
    });
    const targets = await this.devices.pushTargets(userId);
    const results = await this.push.deliver(
      targets.map((d) => ({
        token: d.pushToken!,
        kind: 'alert' as const,
        title: 'TaskFlow',
        body: 'Push notifications are working.',
        channelId: REMINDER_CHANNEL,
        data: { type: 'test', notificationId: notification?.id ?? '' },
      })),
    );
    const delivered = results.filter((r) => r.success).length;
    if (notification && delivered > 0)
      await this.notifications.recordPushes(notification.id, delivered);
    return { devices: targets.length, delivered, pushConfigured: this.push.enabled };
  }
}
