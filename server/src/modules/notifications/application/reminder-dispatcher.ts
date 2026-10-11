import { DateTime } from 'luxon';

import type { UnitOfWork } from '../../../core/db/unit-of-work.js';
import type { Clock } from '../../../core/utils/clock.js';
import type { Device, DeviceRepository } from '../../devices/domain/device.js';
import type { SettingsRepository } from '../../settings/domain/settings.js';
import type { Task } from '../../tasks/domain/task.js';
import type { TaskRepository } from '../../tasks/domain/task.repository.js';
import type { AppNotification, NotificationRepository } from '../domain/notification.js';
import type { PushMessage } from '../domain/push-gateway.js';
import type { PushDispatcher } from './push-dispatcher.js';

/** Reminders more than this late (e.g. after downtime) are skipped rather than sent. */
const MAX_LATENESS_MS = 60 * 60 * 1000;
const BATCH = 200;

export const REMINDER_CHANNEL = 'task_reminders';

/**
 * Server side of task reminders (runs every ~30 s).
 *
 * The app schedules reminders locally, so a push is only needed where the
 * local one can't be right: a device that has not synced the latest version
 * of the task (`last_pulled_seq < task.change_seq`), or a client that doesn't
 * schedule reminders itself (`local_reminders = false`, e.g. a web client).
 * That keeps offline reminders working without ever notifying twice.
 *
 * Delivery is at-most-once: the task is marked sent in the same transaction
 * that claims it, and the inbox row's dedupe key blocks repeats.
 */
export class ReminderDispatcher {
  constructor(
    private readonly tasks: TaskRepository,
    private readonly devices: DeviceRepository,
    private readonly settings: SettingsRepository,
    private readonly notifications: NotificationRepository,
    private readonly push: PushDispatcher,
    private readonly uow: UnitOfWork,
    private readonly clock: Clock,
  ) {}

  async run(): Promise<{ claimed: number; notified: number; pushed: number }> {
    const now = this.clock.now();

    const claimed = await this.uow.run(async (tx) => {
      const due = await this.tasks.claimDueReminders(now, BATCH, tx);
      if (due.length === 0) return [];
      await this.tasks.markRemindersSent(
        due.map((t) => t.id),
        now,
        tx,
      );

      const created: { task: Task; notification: AppNotification }[] = [];
      for (const task of due) {
        const late = now.getTime() - (task.remindAt ?? now).getTime();
        if (late > MAX_LATENESS_MS) continue;
        const notification = await this.notifications.createIfAbsent(
          {
            userId: task.userId,
            type: 'reminder',
            title: task.title,
            body: reminderBody(task),
            taskId: task.id,
            data: { type: 'reminder', taskId: task.id },
            dedupeKey: `reminder:${task.id}:${task.remindAt?.toISOString()}`,
          },
          tx,
        );
        if (notification) created.push({ task, notification });
      }
      return created;
    });

    let pushed = 0;
    const byUser = Map.groupBy(claimed, (c) => c.task.userId);
    for (const [userId, items] of byUser) {
      const prefs = await this.settings.get(userId);
      if (prefs && !prefs.notificationsEnabled) continue;
      const targets = await this.devices.pushTargets(userId);

      for (const { task, notification } of items) {
        const recipients = targets.filter((d) => needsPush(d, task));
        const messages: PushMessage[] = recipients.map((d) => ({
          token: d.pushToken!,
          kind: 'alert',
          title: task.title,
          body: notification.body,
          channelId: REMINDER_CHANNEL,
          collapseKey: `task-${task.id}`,
          data: { type: 'reminder', taskId: task.id, notificationId: notification.id },
        }));
        const results = await this.push.deliver(messages);
        const ok = results.filter((r) => r.success).length;
        pushed += ok;
        if (ok > 0) await this.notifications.recordPushes(notification.id, ok);
      }
    }

    return { claimed: claimed.length, notified: claimed.length, pushed };
  }
}

/** Does this device need the server to push the reminder? */
export function needsPush(device: Device, task: Task): boolean {
  if (!device.pushToken) return false;
  if (!device.localReminders) return true;
  return device.lastPulledSeq < task.changeSeq;
}

function reminderBody(task: Task): string {
  if (task.isAllDay) return 'Due today';
  const due = DateTime.fromJSDate(task.dueAt, { zone: task.timezone });
  return `Due at ${due.toFormat('h:mm a')}`;
}
