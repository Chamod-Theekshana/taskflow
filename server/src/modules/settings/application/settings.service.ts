import { lockUser, type TxContext, type UnitOfWork } from '../../../core/db/unit-of-work.js';
import type { Clock } from '../../../core/utils/clock.js';
import type { ChangeNotifier } from '../../sync/domain/change-notifier.js';
import {
  defaultSettings,
  normalizeCategories,
  type SettingsRepository,
  type UserSettings,
} from '../domain/settings.js';
import type { SettingsPatch } from './settings.schemas.js';

/**
 * Defaults are stamped with the epoch, so the first settings a device pushes
 * (e.g. preferences from before the account existed) always win over them.
 */
const NEVER_EDITED = new Date(0);

export type SettingsApplyResult = { status: 'applied' | 'stale'; settings: UserSettings };

export class SettingsService {
  constructor(
    private readonly repo: SettingsRepository,
    private readonly uow: UnitOfWork,
    private readonly clock: Clock,
    private readonly changes: ChangeNotifier,
  ) {}

  /** The user's settings, created with defaults the first time. */
  async get(userId: string): Promise<UserSettings> {
    const existing = await this.repo.get(userId);
    if (existing) return existing;
    return this.uow.run(async (tx) => {
      await lockUser(tx, userId);
      return (
        (await this.repo.get(userId, tx)) ??
        this.repo.save(userId, defaultSettings('UTC', NEVER_EDITED), tx)
      );
    });
  }

  async update(userId: string, patch: SettingsPatch, origin?: string): Promise<UserSettings> {
    const result = await this.uow.run(async (tx) => {
      await lockUser(tx, userId);
      return this.applyInTx(userId, patch, tx);
    });
    if (result.status === 'applied') this.changes.changed(userId, origin);
    return result.settings;
  }

  /**
   * Applies [patch] inside an open transaction (the caller holds the user
   * lock). Last write wins: a patch older than what is stored is ignored.
   */
  async applyInTx(
    userId: string,
    patch: SettingsPatch,
    tx: TxContext,
  ): Promise<SettingsApplyResult> {
    const now = this.clock.now();
    const current = (await this.repo.get(userId, tx)) ?? {
      ...defaultSettings(patch.timezone ?? 'UTC', NEVER_EDITED),
      changeSeq: 0,
    };
    const updatedAt = patch.updatedAt ?? now;
    if (updatedAt.getTime() < current.updatedAt.getTime()) {
      return { status: 'stale', settings: current };
    }

    const saved = await this.repo.save(
      userId,
      {
        notificationsEnabled: patch.notificationsEnabled ?? current.notificationsEnabled,
        dailyDigestEnabled: patch.dailyDigestEnabled ?? current.dailyDigestEnabled,
        dailyDigestTime: patch.dailyDigestTime ?? current.dailyDigestTime,
        themeMode: patch.themeMode ?? current.themeMode,
        defaultPriority: patch.defaultPriority ?? current.defaultPriority,
        dailyGoal: patch.dailyGoal ?? current.dailyGoal,
        customCategories: normalizeCategories(patch.customCategories ?? current.customCategories),
        timezone: patch.timezone ?? current.timezone,
        updatedAt,
      },
      tx,
    );
    return { status: 'applied', settings: saved };
  }

  /** Called at sign-up. */
  createDefaults(userId: string, timezone: string, tx: TxContext): Promise<UserSettings> {
    return this.repo.save(userId, defaultSettings(timezone, NEVER_EDITED), tx);
  }
}
