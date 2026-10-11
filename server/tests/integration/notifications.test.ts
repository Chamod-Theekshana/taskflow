import { randomUUID } from 'node:crypto';

import { afterAll, beforeEach, describe, expect, it } from 'vitest';

import { createTestApp, type TestApp } from '../helpers/test-app.js';

const MINUTE = 60_000;

describe('notifications', () => {
  let t: TestApp;
  beforeEach(async () => {
    if (t) await t.close();
    // Long-lived access tokens: these tests move the clock by hours.
    t = await createTestApp(new Date('2026-09-29T08:00:00.000Z'), {
      accessTtlSeconds: 90 * 86_400,
    });
  });

  /** Visible notifications only; silent sync nudges are covered in sync.test.ts. */
  const alerts = () => t.push.sent.filter((m) => m.kind === 'alert');
  afterAll(() => t.close());

  async function userWithTask(options: { deviceSynced: boolean; localReminders?: boolean }) {
    const user = await t.signUp({ timezone: 'UTC' });
    await user
      .put('/api/v1/devices/phone-installation-01', {
        platform: 'android',
        pushToken: 'fcm-token-phone-0000001',
        localReminders: options.localReminders ?? true,
      })
      .expect(200);
    // Reminder at 08:10 UTC (due 08:20, 10 minutes before).
    const task = await user
      .post('/api/v1/tasks', {
        title: 'Stand-up',
        dueDate: '2026-09-29',
        dueTime: '08:20',
        reminder: true,
        reminderMinutes: 10,
      })
      .expect(201);
    if (options.deviceSynced) {
      await user.get('/api/v1/sync/pull?cursor=0', 'phone-installation-01').expect(200);
    }
    await t.settle();
    t.push.clear();
    return { user, task: task.body.data };
  }

  it('does not push reminders the device already scheduled locally', async () => {
    await userWithTask({ deviceSynced: true });
    t.clock.advance(11 * MINUTE);
    const result = await t.container.jobs.reminders.run();
    expect(result.claimed).toBe(1);
    expect(alerts()).toHaveLength(0);
  });

  it('pushes the reminder to a device that has not synced the task yet', async () => {
    const { user, task } = await userWithTask({ deviceSynced: false });

    t.clock.advance(5 * MINUTE);
    await t.container.jobs.reminders.run();
    expect(alerts()).toHaveLength(0); // not due yet

    t.clock.advance(6 * MINUTE);
    await t.container.jobs.reminders.run();
    expect(alerts()).toHaveLength(1);
    expect(alerts()[0]).toMatchObject({
      kind: 'alert',
      title: 'Stand-up',
      body: 'Due at 8:20 AM',
      channelId: 'task_reminders',
      data: { type: 'reminder', taskId: task.id },
    });

    // Sent once only.
    await t.container.jobs.reminders.run();
    expect(alerts()).toHaveLength(1);

    const inbox = await user.get('/api/v1/notifications').expect(200);
    expect(inbox.body.data[0]).toMatchObject({ type: 'reminder', taskId: task.id, read: false });
    await user.post(`/api/v1/notifications/${inbox.body.data[0].id}/read`).expect(204);
    const unread = await user.get('/api/v1/notifications?unread=true').expect(200);
    expect(unread.body.data).toHaveLength(0);
  });

  it('always pushes to clients without local reminders', async () => {
    await userWithTask({ deviceSynced: true, localReminders: false });
    t.clock.advance(11 * MINUTE);
    await t.container.jobs.reminders.run();
    expect(alerts()).toHaveLength(1);
  });

  it('sends again after the reminder is moved, and skips completed tasks', async () => {
    const { user, task } = await userWithTask({ deviceSynced: false, localReminders: false });
    t.clock.advance(11 * MINUTE);
    await t.container.jobs.reminders.run();
    expect(alerts()).toHaveLength(1);

    await user.patch(`/api/v1/tasks/${task.id}`, { dueTime: '09:00' }).expect(200);
    t.clock.advance(40 * MINUTE); // 08:51 -> reminder at 08:50
    await t.container.jobs.reminders.run();
    expect(alerts()).toHaveLength(2);

    const second = await user
      .post('/api/v1/tasks', {
        title: 'Done early',
        dueDate: '2026-09-29',
        dueTime: '10:00',
        reminder: true,
      })
      .expect(201);
    await user.post(`/api/v1/tasks/${second.body.data.id}/complete`).expect(200);
    t.clock.advance(60 * MINUTE);
    await t.container.jobs.reminders.run();
    expect(alerts()).toHaveLength(2);
  });

  it('respects the notifications switch and forgets dead tokens', async () => {
    const { user } = await userWithTask({ deviceSynced: false });
    await user.patch('/api/v1/settings', { notificationsEnabled: false }).expect(200);
    t.clock.advance(11 * MINUTE);
    await t.container.jobs.reminders.run();
    expect(alerts()).toHaveLength(0);

    await user.patch('/api/v1/settings', { notificationsEnabled: true }).expect(200);
    await t.settle();
    t.push.invalidTokens.add('fcm-token-phone-0000001');
    const res = await user.post('/api/v1/notifications/test').expect(200);
    expect(res.body.data).toMatchObject({ devices: 1, delivered: 0 });
    const again = await user.post('/api/v1/notifications/test').expect(200);
    expect(again.body.data.devices).toBe(0); // token was removed
  });

  it('builds the daily digest for clients that rely on the server', async () => {
    const user = await t.signUp({ timezone: 'Asia/Colombo' });
    await user
      .patch('/api/v1/settings', { dailyDigestEnabled: true, dailyDigestTime: '14:00' })
      .expect(200);
    await user
      .put('/api/v1/devices/web-installation-01', {
        platform: 'web',
        pushToken: 'fcm-token-web-000000001',
        localReminders: false,
      })
      .expect(200);
    await user
      .post('/api/v1/tasks', { title: 'A', dueDate: '2026-09-29', priority: 'high' })
      .expect(201);
    await user.post('/api/v1/tasks', { title: 'B', dueDate: '2026-09-29' }).expect(201);
    await t.settle();
    t.push.clear();

    // 08:00Z = 13:30 in Colombo: too early.
    await t.container.jobs.digests.run();
    expect(alerts()).toHaveLength(0);

    t.clock.advance(35 * MINUTE); // 14:05 local
    await t.container.jobs.digests.run();
    await t.container.jobs.digests.run(); // once per day
    expect(alerts()).toHaveLength(1);
    expect(alerts()[0]).toMatchObject({
      title: 'Your day at a glance',
      body: '2 tasks due today · 1 high priority',
    });
  });

  it('cleans up old data', async () => {
    const user = await t.signUp();
    const id = randomUUID();
    await user.post('/api/v1/tasks', { id, title: 'Old', dueDate: '2026-09-29' }).expect(201);
    await user.del(`/api/v1/tasks/${id}`).expect(204);
    t.clock.advance(31 * 24 * 60 * MINUTE);
    const result = await t.container.jobs.cleanup.run();
    expect(result.tombstones).toBe(1);
  });
});
