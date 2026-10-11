import type { TxContext } from '../../../core/db/unit-of-work.js';
import type { Priority, Task, TaskWrite } from './task.js';

export interface TaskListFilter {
  status: 'open' | 'completed' | 'all';
  /** Inclusive `YYYY-MM-DD` bounds on the due day. */
  from?: string;
  to?: string;
  query?: string;
  priority?: Priority;
  category?: string;
  limit: number;
  /** Opaque keyset cursor from the previous page. */
  cursor?: string;
}

export interface TaskPage {
  items: Task[];
  nextCursor: string | null;
}

/** Port. Implemented with Drizzle in infrastructure/drizzle-task.repository.ts. */
export interface TaskRepository {
  /** A live (not deleted) task of [userId]. */
  findById(userId: string, id: string, tx?: TxContext): Promise<Task | null>;

  /** Any task with this id, deleted or not, whoever owns it. For sync conflict checks. */
  findAnyById(id: string, tx?: TxContext): Promise<Task | null>;

  list(userId: string, filter: TaskListFilter): Promise<TaskPage>;

  /** Every live task of a user (stats). */
  listLive(userId: string): Promise<Task[]>;

  /** Tasks (tombstones included) changed after [cursor], oldest change first. */
  changesSince(userId: string, cursor: number, limit: number, tx?: TxContext): Promise<Task[]>;

  /** An open task with the same title and repeat rule already due on [dueDate]? */
  hasOpenOccurrence(
    userId: string,
    occurrence: { title: string; repeat: string; dueDate: string },
    tx?: TxContext,
  ): Promise<boolean>;

  insert(userId: string, task: TaskWrite, tx: TxContext): Promise<Task>;

  /** Replaces the task and its subtasks; revives a tombstone. */
  update(userId: string, task: TaskWrite, tx: TxContext): Promise<Task>;

  /** Turns the task into a tombstone. */
  softDelete(userId: string, id: string, deletedAt: Date, tx: TxContext): Promise<Task | null>;

  /**
   * Locks and returns tasks whose reminder is due and not yet sent.
   * Uses FOR UPDATE SKIP LOCKED, so concurrent workers split the work.
   */
  claimDueReminders(now: Date, limit: number, tx: TxContext): Promise<Task[]>;

  markRemindersSent(ids: string[], at: Date, tx: TxContext): Promise<void>;

  /** Removes tombstones every recently active device has already pulled. */
  purgeTombstones(olderThan: Date): Promise<number>;
}
