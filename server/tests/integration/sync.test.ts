import { randomUUID } from 'node:crypto';

import { afterAll, beforeAll, describe, expect, it } from 'vitest';

import { createTestApp, type TestApp, type TestUser } from '../helpers/test-app.js';

const PHONE = 'phone-0000-0000-0001';
const TABLET = 'tablet-000-0000-0002';

function syncTask(overrides: Record<string, unknown> = {}) {
  return {
    id: randomUUID(),
    title: 'Offline task',
    description: '',
    dueDate: '2026-10-01',
    dueTime: '09:00',
    isAllDay: false,
    timezone: 'Asia/Colombo',
    priority: 'medium',
    category: 'Work',
    isCompleted: false,
    completedAt: null,
    reminder: false,
    reminderMinutes: 15,
    repeat: 'none',
    subtasks: [{ id: randomUUID(), title: 'Step one', isCompleted: false }],
    createdAt: '2026-09-29T07:00:00.000Z',
    updatedAt: '2026-09-29T07:00:00.000Z',
    ...overrides,
  };
}

describe('sync', () => {
  let t: TestApp;
  let user: TestUser;

  beforeAll(async () => {
    t = await createTestApp();
    user = await t.signUp();
  });
  afterAll(() => t.close());

  it('pushes offline work and pulls it on another device', async () => {
    const task = syncTask();
    const pushed = await user
      .post('/api/v1/sync/push', { changes: [{ op: 'upsert', task }] }, PHONE)
      .expect(200);
    expect(pushed.body.data.results).toEqual([{ id: task.id, status: 'applied' }]);

    const pulled = await user.get('/api/v1/sync/pull?cursor=0', TABLET).expect(200);
    const found = pulled.body.data.tasks.find((x: { id: string }) => x.id === task.id);
    expect(found).toMatchObject({ title: 'Offline task', dueAt: '2026-10-01T03:30:00.000Z' });
    expect(found.subtasks[0].id).toBe(task.subtasks[0]!.id);
    expect(pulled.body.data.settings).not.toBeNull(); // first pull includes settings
    expect(pulled.body.data.hasMore).toBe(false);

    // Nothing new since that cursor.
    const again = await user
      .get(`/api/v1/sync/pull?cursor=${pulled.body.data.cursor}`, TABLET)
      .expect(200);
    expect(again.body.data.tasks).toHaveLength(0);
    expect(again.body.data.settings).toBeNull();
  });

  it('pages through large pulls', async () => {
    const fresh = await t.signUp();
    const changes = Array.from({ length: 5 }, (_, i) => ({
      op: 'upsert',
      task: syncTask({ title: `T${i}` }),
    }));
    await fresh.post('/api/v1/sync/push', { changes }).expect(200);

    let cursor = 0;
    const titles: string[] = [];
    for (let guard = 0; guard < 10; guard++) {
      const page = await fresh.get(`/api/v1/sync/pull?cursor=${cursor}&limit=2`).expect(200);
      titles.push(...page.body.data.tasks.map((x: { title: string }) => x.title));
      cursor = page.body.data.cursor;
      if (!page.body.data.hasMore) break;
    }
    expect(titles).toEqual(['T0', 'T1', 'T2', 'T3', 'T4']);
  });

  it('resolves conflicts with last-write-wins', async () => {
    const task = syncTask();
    await user.post('/api/v1/sync/push', { changes: [{ op: 'upsert', task }] }, PHONE).expect(200);

    const newer = { ...task, title: 'Edited on tablet', updatedAt: '2026-09-29T09:00:00.000Z' };
    const older = { ...task, title: 'Edited on phone', updatedAt: '2026-09-29T08:00:00.000Z' };
    await user
      .post('/api/v1/sync/push', { changes: [{ op: 'upsert', task: newer }] }, TABLET)
      .expect(200);
    const res = await user
      .post('/api/v1/sync/push', { changes: [{ op: 'upsert', task: older }] }, PHONE)
      .expect(200);
    expect(res.body.data.results[0].status).toBe('stale');

    const current = await user.get(`/api/v1/tasks/${task.id}`).expect(200);
    expect(current.body.data.title).toBe('Edited on tablet');
  });

  it('propagates deletions as tombstones', async () => {
    const task = syncTask();
    await user.post('/api/v1/sync/push', { changes: [{ op: 'upsert', task }] }, PHONE).expect(200);
    const before = await user.get('/api/v1/sync/pull?cursor=0', TABLET).expect(200);

    await user
      .post(
        '/api/v1/sync/push',
        { changes: [{ op: 'delete', id: task.id, deletedAt: '2026-09-29T10:00:00.000Z' }] },
        PHONE,
      )
      .expect(200);
    const after = await user
      .get(`/api/v1/sync/pull?cursor=${before.body.data.cursor}`, TABLET)
      .expect(200);
    const tombstone = after.body.data.tasks.find((x: { id: string }) => x.id === task.id);
    expect(tombstone.deletedAt).toBe('2026-09-29T10:00:00.000Z');
    await user.get(`/api/v1/tasks/${task.id}`).expect(404);
  });

  it('rejects invalid changes one by one instead of failing the batch', async () => {
    const good = syncTask();
    const res = await user
      .post('/api/v1/sync/push', {
        changes: [
          { op: 'upsert', task: { ...syncTask(), timezone: 'Mars/Olympus' } },
          { op: 'upsert', task: good },
          { op: 'explode' },
        ],
      })
      .expect(200);
    expect(res.body.data.results.map((r: { status: string }) => r.status)).toEqual([
      'rejected',
      'applied',
      'rejected',
    ]);
  });

  it("refuses to overwrite another user's task id", async () => {
    const task = syncTask();
    await user.post('/api/v1/sync/push', { changes: [{ op: 'upsert', task }] }).expect(200);
    const intruder = await t.signUp();
    const res = await intruder.post('/api/v1/sync/push', {
      changes: [{ op: 'upsert', task: { ...task, updatedAt: '2030-01-01T00:00:00.000Z' } }],
    });
    expect(res.body.data.results[0]).toMatchObject({ status: 'rejected', reason: 'id_conflict' });
  });

  it('syncs settings with last-write-wins', async () => {
    const fresh = await t.signUp();
    // Settings made before the account existed win over the server defaults.
    const res = await fresh
      .post('/api/v1/sync/push', {
        settings: {
          customCategories: ['Study', 'study', ' Home '],
          themeMode: 'light',
          updatedAt: '2026-01-01T00:00:00.000Z',
        },
      })
      .expect(200);
    expect(res.body.data.settings).toBe('applied');
    const stale = await fresh
      .post('/api/v1/sync/push', {
        settings: { themeMode: 'dark', updatedAt: '2025-01-01T00:00:00.000Z' },
      })
      .expect(200);
    expect(stale.body.data.settings).toBe('stale');

    const settings = await fresh.get('/api/v1/settings').expect(200);
    expect(settings.body.data.themeMode).toBe('light');
    expect(settings.body.data.customCategories).toEqual(['Study', 'Home']);
  });

  it('reports invalid settings as rejected without failing the push', async () => {
    const fresh = await t.signUp();
    const res = await fresh
      .post('/api/v1/sync/push', {
        changes: [{ op: 'upsert', task: syncTask() }],
        settings: { dailyGoal: 999, updatedAt: '2026-09-29T09:00:00.000Z' },
      })
      .expect(200);
    expect(res.body.data.settings).toBe('rejected');
    expect(res.body.data.results[0].status).toBe('applied');
  });

  it('nudges the other devices with a silent push after a change', async () => {
    const fresh = await t.signUp();
    await fresh
      .put(`/api/v1/devices/${PHONE}`, { platform: 'android', pushToken: 'token-phone-1234567890' })
      .expect(200);
    await fresh
      .put(`/api/v1/devices/${TABLET}`, { platform: 'ios', pushToken: 'token-tablet-1234567890' })
      .expect(200);
    t.push.clear();

    await fresh
      .post('/api/v1/sync/push', { changes: [{ op: 'upsert', task: syncTask() }] }, PHONE)
      .expect(200);
    await t.settle();

    expect(t.push.sent).toHaveLength(1);
    expect(t.push.sent[0]).toMatchObject({
      token: 'token-tablet-1234567890',
      kind: 'silent',
      data: { type: 'sync' },
    });
  });
});
