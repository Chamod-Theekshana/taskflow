import {
  and,
  asc,
  eq,
  gt,
  gte,
  inArray,
  isNotNull,
  isNull,
  lt,
  lte,
  or,
  sql,
  type SQL,
} from 'drizzle-orm';

import type { Database } from '../../../core/db/client.js';
import {
  devices,
  subtasks,
  tasks,
  type SubtaskRow,
  type TaskRow,
} from '../../../core/db/schema.js';
import { executor, type TxContext } from '../../../core/db/unit-of-work.js';
import { BadRequestError } from '../../../core/errors/app-error.js';
import type { Priority, RepeatRule, Subtask, Task, TaskWrite } from '../domain/task.js';
import type { TaskListFilter, TaskPage, TaskRepository } from '../domain/task.repository.js';

const nextSeq = sql`nextval('change_seq')`;

function toDomain(row: TaskRow, items: Subtask[]): Task {
  return {
    id: row.id,
    userId: row.userId,
    title: row.title,
    description: row.description,
    dueDate: row.dueDate,
    dueTime: row.dueTime,
    isAllDay: row.isAllDay,
    timezone: row.timezone,
    dueAt: row.dueAt,
    priority: row.priority as Priority,
    category: row.category,
    isCompleted: row.isCompleted,
    completedAt: row.completedAt,
    reminder: row.reminder,
    reminderMinutes: row.reminderMinutes,
    remindAt: row.remindAt,
    reminderSentAt: row.reminderSentAt,
    repeat: row.repeatRule as RepeatRule,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
    deletedAt: row.deletedAt,
    changeSeq: Number(row.changeSeq),
    subtasks: items,
  };
}

function toSubtask(row: SubtaskRow): Subtask {
  return { id: row.id, title: row.title, isCompleted: row.isCompleted, position: row.position };
}

/** Values shared by insert and update. */
function columns(task: TaskWrite) {
  return {
    title: task.title,
    description: task.description,
    dueDate: task.dueDate,
    dueTime: task.dueTime,
    isAllDay: task.isAllDay,
    timezone: task.timezone,
    dueAt: task.dueAt,
    priority: task.priority,
    category: task.category,
    isCompleted: task.isCompleted,
    completedAt: task.completedAt,
    reminder: task.reminder,
    reminderMinutes: task.reminderMinutes,
    remindAt: task.remindAt,
    repeatRule: task.repeat,
    createdAt: task.createdAt,
    updatedAt: task.updatedAt,
  };
}

function escapeLike(text: string): string {
  return text.replace(/[\\%_]/g, (c) => `\\${c}`);
}

function encodeCursor(task: Task): string {
  return Buffer.from(`${task.dueAt.toISOString()}|${task.id}`).toString('base64url');
}

function decodeCursor(cursor: string): { dueAt: Date; id: string } {
  const [due, id] = Buffer.from(cursor, 'base64url').toString('utf8').split('|');
  const dueAt = new Date(due ?? '');
  if (!id || Number.isNaN(dueAt.getTime()))
    throw new BadRequestError('Invalid cursor.', 'invalid_cursor');
  return { dueAt, id };
}

export class DrizzleTaskRepository implements TaskRepository {
  constructor(private readonly db: Database) {}

  private async withSubtasks(db: Database, rows: TaskRow[]): Promise<Task[]> {
    if (rows.length === 0) return [];
    const children = await db
      .select()
      .from(subtasks)
      .where(
        inArray(
          subtasks.taskId,
          rows.map((r) => r.id),
        ),
      )
      .orderBy(asc(subtasks.taskId), asc(subtasks.position));

    const byTask = new Map<string, Subtask[]>();
    for (const child of children) {
      const list = byTask.get(child.taskId) ?? [];
      list.push(toSubtask(child));
      byTask.set(child.taskId, list);
    }
    return rows.map((row) => toDomain(row, byTask.get(row.id) ?? []));
  }

  async findById(userId: string, id: string, tx?: TxContext): Promise<Task | null> {
    const db = executor(this.db, tx);
    const rows = await db
      .select()
      .from(tasks)
      .where(and(eq(tasks.userId, userId), eq(tasks.id, id), isNull(tasks.deletedAt)))
      .limit(1);
    const [task] = await this.withSubtasks(db, rows);
    return task ?? null;
  }

  async findAnyById(id: string, tx?: TxContext): Promise<Task | null> {
    const db = executor(this.db, tx);
    const rows = await db.select().from(tasks).where(eq(tasks.id, id)).limit(1);
    const [task] = await this.withSubtasks(db, rows);
    return task ?? null;
  }

  async list(userId: string, filter: TaskListFilter): Promise<TaskPage> {
    const conditions: SQL[] = [eq(tasks.userId, userId), isNull(tasks.deletedAt)];

    if (filter.status === 'open') conditions.push(eq(tasks.isCompleted, false));
    if (filter.status === 'completed') conditions.push(eq(tasks.isCompleted, true));
    if (filter.from) conditions.push(gte(tasks.dueDate, filter.from));
    if (filter.to) conditions.push(lte(tasks.dueDate, filter.to));
    if (filter.priority) conditions.push(eq(tasks.priority, filter.priority));
    if (filter.category) {
      conditions.push(sql`lower(${tasks.category}) = lower(${filter.category})`);
    }
    if (filter.query) {
      const pattern = `%${escapeLike(filter.query)}%`;
      conditions.push(
        sql`(${tasks.title} ilike ${pattern} or ${tasks.description} ilike ${pattern} or ${tasks.category} ilike ${pattern} or exists (select 1 from ${subtasks} where ${subtasks.taskId} = ${tasks.id} and ${subtasks.title} ilike ${pattern}))`,
      );
    }
    if (filter.cursor) {
      const { dueAt, id } = decodeCursor(filter.cursor);
      const after = or(gt(tasks.dueAt, dueAt), and(eq(tasks.dueAt, dueAt), gt(tasks.id, id)));
      if (after) conditions.push(after);
    }

    const rows = await this.db
      .select()
      .from(tasks)
      .where(and(...conditions))
      .orderBy(asc(tasks.dueAt), asc(tasks.id))
      .limit(filter.limit + 1);

    const hasMore = rows.length > filter.limit;
    const items = await this.withSubtasks(this.db, rows.slice(0, filter.limit));
    const last = items.at(-1);
    return { items, nextCursor: hasMore && last ? encodeCursor(last) : null };
  }

  async listLive(userId: string): Promise<Task[]> {
    const rows = await this.db
      .select()
      .from(tasks)
      .where(and(eq(tasks.userId, userId), isNull(tasks.deletedAt)))
      .orderBy(asc(tasks.dueAt));
    return this.withSubtasks(this.db, rows);
  }

  async changesSince(
    userId: string,
    cursor: number,
    limit: number,
    tx?: TxContext,
  ): Promise<Task[]> {
    const db = executor(this.db, tx);
    const rows = await db
      .select()
      .from(tasks)
      .where(and(eq(tasks.userId, userId), gt(tasks.changeSeq, cursor)))
      .orderBy(asc(tasks.changeSeq))
      .limit(limit);
    return this.withSubtasks(db, rows);
  }

  async hasOpenOccurrence(
    userId: string,
    occurrence: { title: string; repeat: string; dueDate: string },
    tx?: TxContext,
  ): Promise<boolean> {
    const db = executor(this.db, tx);
    const rows = await db
      .select({ id: tasks.id })
      .from(tasks)
      .where(
        and(
          eq(tasks.userId, userId),
          isNull(tasks.deletedAt),
          eq(tasks.isCompleted, false),
          eq(tasks.title, occurrence.title),
          eq(tasks.repeatRule, occurrence.repeat),
          eq(tasks.dueDate, occurrence.dueDate),
        ),
      )
      .limit(1);
    return rows.length > 0;
  }

  private async replaceSubtasks(db: Database, task: TaskWrite): Promise<void> {
    await db.delete(subtasks).where(eq(subtasks.taskId, task.id));
    if (task.subtasks.length === 0) return;
    await db.insert(subtasks).values(
      task.subtasks.map((s) => ({
        id: s.id,
        taskId: task.id,
        title: s.title,
        isCompleted: s.isCompleted,
        position: s.position,
      })),
    );
  }

  async insert(userId: string, task: TaskWrite, tx: TxContext): Promise<Task> {
    const db = executor(this.db, tx);
    const [row] = await db
      .insert(tasks)
      .values({
        id: task.id,
        userId,
        ...columns(task),
        deletedAt: null,
        reminderSentAt: null,
        serverUpdatedAt: sql`now()`,
        changeSeq: nextSeq,
      })
      .returning();
    if (!row) throw new Error('Insert returned no row');
    await this.replaceSubtasks(db, task);
    const [saved] = await this.withSubtasks(db, [row]);
    return saved!;
  }

  async update(userId: string, task: TaskWrite, tx: TxContext): Promise<Task> {
    const db = executor(this.db, tx);
    const [row] = await db
      .update(tasks)
      .set({
        ...columns(task),
        deletedAt: null,
        serverUpdatedAt: sql`now()`,
        changeSeq: nextSeq,
        ...(task.resetReminder ? { reminderSentAt: null } : {}),
      })
      .where(and(eq(tasks.id, task.id), eq(tasks.userId, userId)))
      .returning();
    if (!row) throw new Error(`Task ${task.id} vanished during update`);
    await this.replaceSubtasks(db, task);
    const [saved] = await this.withSubtasks(db, [row]);
    return saved!;
  }

  async softDelete(
    userId: string,
    id: string,
    deletedAt: Date,
    tx: TxContext,
  ): Promise<Task | null> {
    const db = executor(this.db, tx);
    const [row] = await db
      .update(tasks)
      .set({
        deletedAt,
        updatedAt: deletedAt,
        serverUpdatedAt: sql`now()`,
        changeSeq: nextSeq,
      })
      .where(and(eq(tasks.id, id), eq(tasks.userId, userId)))
      .returning();
    if (!row) return null;
    await db.delete(subtasks).where(eq(subtasks.taskId, id));
    return toDomain(row, []);
  }

  async claimDueReminders(now: Date, limit: number, tx: TxContext): Promise<Task[]> {
    const db = executor(this.db, tx);
    const rows = await db
      .select()
      .from(tasks)
      .where(
        and(
          eq(tasks.reminder, true),
          eq(tasks.isCompleted, false),
          isNull(tasks.deletedAt),
          isNull(tasks.reminderSentAt),
          lte(tasks.remindAt, now),
        ),
      )
      .orderBy(asc(tasks.remindAt))
      .limit(limit)
      .for('update', { skipLocked: true });
    return this.withSubtasks(db, rows);
  }

  async markRemindersSent(ids: string[], at: Date, tx: TxContext): Promise<void> {
    if (ids.length === 0) return;
    const db = executor(this.db, tx);
    await db.update(tasks).set({ reminderSentAt: at }).where(inArray(tasks.id, ids));
  }

  async purgeTombstones(olderThan: Date): Promise<number> {
    const cutoff = olderThan.toISOString();
    const deleted = await this.db
      .delete(tasks)
      .where(
        and(
          isNotNull(tasks.deletedAt),
          lt(tasks.deletedAt, olderThan),
          sql`${tasks.changeSeq} <= coalesce((select min(${devices.lastPulledSeq}) from ${devices} where ${devices.userId} = ${tasks.userId} and ${devices.lastSeenAt} > ${cutoff}::timestamptz), 9223372036854775807)`,
        ),
      )
      .returning({ id: tasks.id });
    return deleted.length;
  }
}
