import { randomUUID } from 'node:crypto';

import { afterAll, beforeAll, describe, expect, it } from 'vitest';

import { createTestApp, type TestApp, type TestUser } from '../helpers/test-app.js';

describe('tasks REST API', () => {
  let t: TestApp;
  let user: TestUser;

  beforeAll(async () => {
    t = await createTestApp();
    user = await t.signUp({ timezone: 'Asia/Colombo' });
  });
  afterAll(() => t.close());

  it('creates a task with derived due and reminder instants', async () => {
    const res = await user
      .post('/api/v1/tasks', {
        title: '  Call Sam ',
        dueDate: '2026-09-30',
        dueTime: '17:00',
        priority: 'high',
        category: 'Personal',
        reminder: true,
        reminderMinutes: 30,
        subtasks: [{ title: 'Find number' }],
      })
      .expect(201);
    const task = res.body.data;
    expect(task.title).toBe('Call Sam');
    expect(task.timezone).toBe('Asia/Colombo'); // from the user's settings
    expect(task.dueAt).toBe('2026-09-30T11:30:00.000Z');
    expect(task.remindAt).toBe('2026-09-30T11:00:00.000Z');
    expect(task.subtasks).toHaveLength(1);
    expect(res.headers.location).toContain(task.id);
  });

  it('validates input', async () => {
    const res = await user
      .post('/api/v1/tasks', { title: '', dueDate: '2026-02-30', priority: 'urgent' })
      .expect(422);
    const paths = res.body.errors.map((e: { path: string }) => e.path);
    expect(paths).toEqual(expect.arrayContaining(['title', 'dueDate', 'priority']));
    await user
      .post('/api/v1/tasks', { title: 'X', dueDate: '2026-09-30', hacker: true })
      .expect(422);
  });

  it('lists with filters, search and keyset pagination', async () => {
    const other = await t.signUp();
    for (let day = 1; day <= 5; day++) {
      await other.post('/api/v1/tasks', {
        title: `Task ${day}`,
        dueDate: `2026-10-0${day}`,
        category: day % 2 ? 'Work' : 'Home',
      });
    }
    const page1 = await other.get('/api/v1/tasks?limit=2').expect(200);
    expect(page1.body.data.map((x: { title: string }) => x.title)).toEqual(['Task 1', 'Task 2']);
    const page2 = await other
      .get(`/api/v1/tasks?limit=2&cursor=${page1.body.meta.nextCursor}`)
      .expect(200);
    expect(page2.body.data.map((x: { title: string }) => x.title)).toEqual(['Task 3', 'Task 4']);

    const work = await other.get('/api/v1/tasks?category=work').expect(200);
    expect(work.body.data).toHaveLength(3);
    const search = await other.get('/api/v1/tasks?q=task%204').expect(200);
    expect(search.body.data).toHaveLength(1);
    const range = await other.get('/api/v1/tasks?from=2026-10-02&to=2026-10-03').expect(200);
    expect(range.body.data).toHaveLength(2);
  });

  it("never exposes another user's tasks", async () => {
    const mine = await user
      .post('/api/v1/tasks', { title: 'Private', dueDate: '2026-10-01' })
      .expect(201);
    const stranger = await t.signUp();
    await stranger.get(`/api/v1/tasks/${mine.body.data.id}`).expect(404);
    await stranger.patch(`/api/v1/tasks/${mine.body.data.id}`, { title: 'Hacked' }).expect(404);
    await stranger.get('/api/v1/tasks/not-a-uuid').expect(404);
  });

  it('updates, reschedules and recomputes the reminder', async () => {
    const created = await user
      .post('/api/v1/tasks', {
        title: 'Report',
        dueDate: '2026-10-01',
        dueTime: '09:00',
        reminder: true,
      })
      .expect(201);
    const id = created.body.data.id;
    const updated = await user
      .patch(`/api/v1/tasks/${id}`, { dueTime: '10:00', reminderMinutes: 60 })
      .expect(200);
    expect(updated.body.data.remindAt).toBe('2026-10-01T03:30:00.000Z');
    const allDay = await user.patch(`/api/v1/tasks/${id}`, { isAllDay: true }).expect(200);
    expect(allDay.body.data.dueTime).toBeNull();
    expect(allDay.body.data.remindAt).toBe('2026-10-01T03:30:00.000Z'); // 09:00 Colombo
  });

  it('completing a repeating task schedules the next one exactly once', async () => {
    const created = await user
      .post('/api/v1/tasks', {
        title: 'Water plants',
        dueDate: '2026-09-29',
        dueTime: '18:00',
        repeat: 'daily',
        subtasks: [{ title: 'Balcony' }],
      })
      .expect(201);
    const id = created.body.data.id;

    const done = await user.post(`/api/v1/tasks/${id}/complete`).expect(200);
    expect(done.body.data.task.isCompleted).toBe(true);
    expect(done.body.data.task.subtasks[0].isCompleted).toBe(true);
    expect(done.body.data.next.dueDate).toBe('2026-09-30');
    expect(done.body.data.next.subtasks[0].isCompleted).toBe(false);

    await user.post(`/api/v1/tasks/${id}/reopen`).expect(200);
    const again = await user.post(`/api/v1/tasks/${id}/complete`).expect(200);
    expect(again.body.data.next).toBeNull(); // the copy for the 30th already exists
  });

  it('manages subtasks', async () => {
    const created = await user
      .post('/api/v1/tasks', { title: 'Trip', dueDate: '2026-10-10' })
      .expect(201);
    const id = created.body.data.id;
    const withOne = await user.post(`/api/v1/tasks/${id}/subtasks`, { title: 'Pack' }).expect(201);
    const subId = withOne.body.data.subtasks[0].id;
    const ticked = await user
      .patch(`/api/v1/tasks/${id}/subtasks/${subId}`, { isCompleted: true })
      .expect(200);
    expect(ticked.body.data.subtasks[0].isCompleted).toBe(true);
    await user
      .patch(`/api/v1/tasks/${id}/subtasks/${randomUUID()}`, { isCompleted: true })
      .expect(404);
    const removed = await user.del(`/api/v1/tasks/${id}/subtasks/${subId}`).expect(200);
    expect(removed.body.data.subtasks).toHaveLength(0);
  });

  it('deletes tasks and accepts client-generated ids once', async () => {
    const id = randomUUID();
    await user.post('/api/v1/tasks', { id, title: 'Mine', dueDate: '2026-10-01' }).expect(201);
    await user.post('/api/v1/tasks', { id, title: 'Again', dueDate: '2026-10-01' }).expect(409);
    await user.del(`/api/v1/tasks/${id}`).expect(204);
    await user.get(`/api/v1/tasks/${id}`).expect(404);
  });

  it('reports productivity stats', async () => {
    const res = await user.get('/api/v1/stats/summary?period=week').expect(200);
    expect(res.body.data.completed).toBeGreaterThanOrEqual(1);
    expect(res.body.data.byWeekday).toHaveLength(7);
  });
});
