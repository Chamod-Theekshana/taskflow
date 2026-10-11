import { lockUser, type TxContext, type UnitOfWork } from '../../../core/db/unit-of-work.js';
import { zodIssues } from '../../../core/http/validation.js';
import type { Clock } from '../../../core/utils/clock.js';
import type { DeviceRepository } from '../../devices/domain/device.js';
import { SettingsPatchSchema } from '../../settings/application/settings.schemas.js';
import type { SettingsService } from '../../settings/application/settings.service.js';
import type { SettingsRepository, UserSettings } from '../../settings/domain/settings.js';
import type { Task } from '../../tasks/domain/task.js';
import type { TaskRepository } from '../../tasks/domain/task.repository.js';
import { prepareTaskWrite } from '../../tasks/domain/task-writer.js';
import type { ChangeNotifier } from '../domain/change-notifier.js';
import {
  ChangeSchema,
  type ChangeResult,
  type SyncChange,
  type SyncTaskInput,
} from './sync.schemas.js';

export interface PullResult {
  tasks: Task[];
  settings: UserSettings | null;
  cursor: number;
  hasMore: boolean;
}

export interface PushResult {
  results: ChangeResult[];
  settings: 'applied' | 'stale' | 'rejected' | null;
}

/**
 * Offline-first replication for the app.
 *
 * Pull: "give me everything that changed after cursor N". Cursors are
 * change_seq values; a user's writes are serialised (see `lockUser`), so they
 * commit in sequence order and a pull never skips a row.
 *
 * Push: the device sends whole task aggregates and deletions it made while
 * offline. Conflicts are resolved per task with last-write-wins on the
 * client's `updatedAt`; the loser is reported as `stale` and the device gets
 * the winning version on its next pull.
 */
export class SyncService {
  constructor(
    private readonly tasks: TaskRepository,
    private readonly settingsRepo: SettingsRepository,
    private readonly settings: SettingsService,
    private readonly devices: DeviceRepository,
    private readonly uow: UnitOfWork,
    private readonly clock: Clock,
    private readonly changes: ChangeNotifier,
  ) {}

  async pull(
    userId: string,
    installationId: string | undefined,
    cursor: number,
    limit: number,
  ): Promise<PullResult> {
    const rows = await this.tasks.changesSince(userId, cursor, limit + 1);
    const hasMore = rows.length > limit;
    const page = rows.slice(0, limit);
    const settings = await this.settingsRepo.changedSince(userId, cursor);

    let next = page.at(-1)?.changeSeq ?? cursor;
    if (!hasMore && settings) next = Math.max(next, settings.changeSeq);

    if (!hasMore && installationId) {
      await this.devices.markPulled(userId, installationId, next, this.clock.now());
    }
    return { tasks: page, settings, cursor: next, hasMore };
  }

  async push(
    userId: string,
    installationId: string | undefined,
    request: { changes: unknown[]; settings?: unknown },
  ): Promise<PushResult> {
    const now = this.clock.now();
    const outcome = await this.uow.run(async (tx) => {
      await lockUser(tx, userId);
      const results: ChangeResult[] = [];
      for (const raw of request.changes) {
        const parsed = ChangeSchema.safeParse(raw);
        if (!parsed.success) {
          results.push({
            id: idOf(raw),
            status: 'rejected',
            reason: zodIssues(parsed.error)
              .map((i) => `${i.path}: ${i.message}`)
              .join('; '),
          });
          continue;
        }
        results.push(await this.apply(userId, parsed.data, now, tx));
      }

      let settings: PushResult['settings'] = null;
      if (request.settings !== undefined && request.settings !== null) {
        const parsed = SettingsPatchSchema.safeParse(request.settings);
        settings = parsed.success
          ? (await this.settings.applyInTx(userId, parsed.data, tx)).status
          : 'rejected';
      }
      return { results, settings };
    });

    if (outcome.settings === 'applied' || outcome.results.some((r) => r.status === 'applied')) {
      this.changes.changed(userId, installationId);
    }
    return outcome;
  }

  private async apply(
    userId: string,
    change: SyncChange,
    now: Date,
    tx: TxContext,
  ): Promise<ChangeResult> {
    if (change.op === 'upsert') return this.upsert(userId, change.task, now, tx);

    const existing = await this.tasks.findAnyById(change.id, tx);
    if (!existing || existing.deletedAt) return { id: change.id, status: 'applied' };
    if (existing.userId !== userId)
      return { id: change.id, status: 'rejected', reason: 'id_conflict' };
    // Edited on another device after this deletion: the edit wins.
    if (change.deletedAt.getTime() < existing.updatedAt.getTime())
      return { id: change.id, status: 'stale' };
    await this.tasks.softDelete(userId, change.id, change.deletedAt, tx);
    return { id: change.id, status: 'applied' };
  }

  private async upsert(
    userId: string,
    input: SyncTaskInput,
    now: Date,
    tx: TxContext,
  ): Promise<ChangeResult> {
    const existing = await this.tasks.findAnyById(input.id, tx);
    if (existing && existing.userId !== userId) {
      return { id: input.id, status: 'rejected', reason: 'id_conflict' };
    }
    if (existing && input.updatedAt.getTime() < existing.updatedAt.getTime()) {
      return { id: input.id, status: 'stale' };
    }

    const write = prepareTaskWrite(input, existing, now);
    if (existing) await this.tasks.update(userId, write, tx);
    else await this.tasks.insert(userId, write, tx);
    return { id: input.id, status: 'applied' };
  }
}

function idOf(raw: unknown): string {
  const value = raw as { id?: unknown; task?: { id?: unknown } } | null;
  const id = value?.task?.id ?? value?.id;
  return typeof id === 'string' ? id.slice(0, 64) : 'unknown';
}
