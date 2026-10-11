import { lockUser, type TxContext, type UnitOfWork } from '../../../core/db/unit-of-work.js';
import { ConflictError, NotFoundError, ValidationError } from '../../../core/errors/app-error.js';
import type { Clock } from '../../../core/utils/clock.js';
import type { SettingsRepository } from '../../settings/domain/settings.js';
import type { ChangeNotifier } from '../../sync/domain/change-notifier.js';
import { nextOccurrence } from '../domain/repeat-rule.js';
import { MAX_SUBTASKS, type Task, type TaskFields } from '../domain/task.js';
import type { TaskListFilter, TaskPage, TaskRepository } from '../domain/task.repository.js';
import { prepareTaskWrite, toFields } from '../domain/task-writer.js';
import type { CreateTaskInput, UpdateTaskInput } from './task.schemas.js';

/**
 * Task use cases for the REST API. Every write:
 * 1. runs in one transaction holding the user's lock,
 * 2. stores the whole aggregate (task + subtasks) with a new change_seq,
 * 3. after commit, nudges the user's other devices to sync.
 */
export class TaskService {
  constructor(
    private readonly tasks: TaskRepository,
    private readonly settings: SettingsRepository,
    private readonly uow: UnitOfWork,
    private readonly clock: Clock,
    private readonly changes: ChangeNotifier,
  ) {}

  list(userId: string, filter: TaskListFilter): Promise<TaskPage> {
    return this.tasks.list(userId, filter);
  }

  async get(userId: string, id: string): Promise<Task> {
    const task = await this.tasks.findById(userId, id);
    if (!task) throw new NotFoundError('Task', 'task_not_found');
    return task;
  }

  async create(userId: string, input: CreateTaskInput, origin?: string): Promise<Task> {
    const now = this.clock.now();
    const task = await this.write(userId, origin, async (tx) => {
      if (input.id && (await this.tasks.findAnyById(input.id, tx))) {
        throw new ConflictError('A task with this id already exists.', 'task_exists');
      }
      const fields: TaskFields & { id?: string } = {
        ...input,
        timezone: input.timezone ?? (await this.userTimezone(userId, tx)),
        createdAt: input.createdAt ?? now,
        updatedAt: input.updatedAt ?? now,
      };
      return this.tasks.insert(userId, prepareTaskWrite(fields, null, now), tx);
    });
    return task;
  }

  async update(userId: string, id: string, patch: UpdateTaskInput, origin?: string): Promise<Task> {
    return this.write(userId, origin, async (tx) => {
      const existing = await this.require(userId, id, tx);
      const now = this.clock.now();
      const merged: TaskFields = {
        ...toFields(existing),
        ...patch,
        updatedAt: patch.updatedAt ?? now,
      };
      if (patch.isCompleted === false) merged.completedAt = null;
      return this.tasks.update(userId, prepareTaskWrite(merged, existing, now), tx);
    });
  }

  async remove(userId: string, id: string, origin?: string): Promise<void> {
    await this.write(userId, origin, async (tx) => {
      await this.require(userId, id, tx);
      return this.tasks.softDelete(userId, id, this.clock.now(), tx);
    });
  }

  /**
   * Completes a task and its subtasks. A repeating task gets its next
   * occurrence, unless an open copy for that day already exists.
   */
  async complete(
    userId: string,
    id: string,
    origin?: string,
  ): Promise<{ task: Task; next: Task | null }> {
    return this.write(userId, origin, async (tx) => {
      const existing = await this.require(userId, id, tx);
      if (existing.isCompleted) return { task: existing, next: null };

      const now = this.clock.now();
      const fields = toFields(existing);
      const task = await this.tasks.update(
        userId,
        prepareTaskWrite(
          {
            ...fields,
            isCompleted: true,
            completedAt: now,
            updatedAt: now,
            subtasks: fields.subtasks.map((s) => ({ ...s, isCompleted: true })),
          },
          existing,
          now,
        ),
        tx,
      );

      const follower = nextOccurrence(existing, now);
      if (!follower) return { task, next: null };
      const duplicate = await this.tasks.hasOpenOccurrence(
        userId,
        { title: follower.title, repeat: follower.repeat, dueDate: follower.dueDate },
        tx,
      );
      if (duplicate) return { task, next: null };
      const next = await this.tasks.insert(userId, prepareTaskWrite(follower, null, now), tx);
      return { task, next };
    });
  }

  async reopen(userId: string, id: string, origin?: string): Promise<Task> {
    return this.update(userId, id, { isCompleted: false }, origin);
  }

  async addSubtask(userId: string, taskId: string, title: string, origin?: string): Promise<Task> {
    return this.editSubtasks(userId, taskId, origin, (subtasks) => {
      if (subtasks.length >= MAX_SUBTASKS) {
        throw new ValidationError(`A task can have at most ${MAX_SUBTASKS} subtasks.`);
      }
      return [...subtasks, { title, isCompleted: false }];
    });
  }

  async updateSubtask(
    userId: string,
    taskId: string,
    subtaskId: string,
    patch: { title?: string; isCompleted?: boolean },
    origin?: string,
  ): Promise<Task> {
    return this.editSubtasks(userId, taskId, origin, (subtasks) => {
      if (!subtasks.some((s) => s.id === subtaskId))
        throw new NotFoundError('Subtask', 'subtask_not_found');
      return subtasks.map((s) => (s.id === subtaskId ? { ...s, ...patch } : s));
    });
  }

  async deleteSubtask(
    userId: string,
    taskId: string,
    subtaskId: string,
    origin?: string,
  ): Promise<Task> {
    return this.editSubtasks(userId, taskId, origin, (subtasks) => {
      if (!subtasks.some((s) => s.id === subtaskId))
        throw new NotFoundError('Subtask', 'subtask_not_found');
      return subtasks.filter((s) => s.id !== subtaskId);
    });
  }

  // ----------------------------------------------------------------- helpers

  private async editSubtasks(
    userId: string,
    taskId: string,
    origin: string | undefined,
    change: (subtasks: TaskFields['subtasks']) => TaskFields['subtasks'],
  ): Promise<Task> {
    return this.write(userId, origin, async (tx) => {
      const existing = await this.require(userId, taskId, tx);
      const now = this.clock.now();
      const fields = toFields(existing);
      const write = prepareTaskWrite(
        { ...fields, subtasks: change(fields.subtasks), updatedAt: now },
        existing,
        now,
      );
      return this.tasks.update(userId, write, tx);
    });
  }

  private async write<T>(
    userId: string,
    origin: string | undefined,
    work: (tx: TxContext) => Promise<T>,
  ): Promise<T> {
    const result = await this.uow.run(async (tx) => {
      await lockUser(tx, userId);
      return work(tx);
    });
    this.changes.changed(userId, origin);
    return result;
  }

  private async require(userId: string, id: string, tx: TxContext): Promise<Task> {
    const task = await this.tasks.findById(userId, id, tx);
    if (!task) throw new NotFoundError('Task', 'task_not_found');
    return task;
  }

  private async userTimezone(userId: string, tx: TxContext): Promise<string> {
    return (await this.settings.get(userId, tx))?.timezone ?? 'UTC';
  }
}
