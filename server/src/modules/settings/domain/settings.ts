import type { TxContext } from '../../../core/db/unit-of-work.js';
import type { Priority } from '../../tasks/domain/task.js';

export const THEME_MODES = ['dark', 'light', 'system'] as const;
export type ThemeMode = (typeof THEME_MODES)[number];

/** Mirrors `AppSettings` in the app (features/settings/domain/settings.dart). */
export interface UserSettings {
  notificationsEnabled: boolean;
  dailyDigestEnabled: boolean;
  /** `HH:mm`, 24-hour. */
  dailyDigestTime: string;
  themeMode: ThemeMode;
  defaultPriority: Priority;
  dailyGoal: number;
  customCategories: string[];
  timezone: string;
  updatedAt: Date;
  changeSeq: number;
}

export type SettingsValues = Omit<UserSettings, 'changeSeq'>;

export function defaultSettings(timezone: string, now: Date): SettingsValues {
  return {
    notificationsEnabled: true,
    dailyDigestEnabled: false,
    dailyDigestTime: '08:00',
    themeMode: 'dark',
    defaultPriority: 'medium',
    dailyGoal: 4,
    customCategories: [],
    timezone,
    updatedAt: now,
  };
}

/** Trims, drops empties and case-insensitive duplicates, keeps the first spelling. */
export function normalizeCategories(names: string[]): string[] {
  const seen = new Set<string>();
  const result: string[] = [];
  for (const name of names) {
    const clean = name.trim();
    if (!clean || seen.has(clean.toLowerCase())) continue;
    seen.add(clean.toLowerCase());
    result.push(clean);
  }
  return result;
}

export interface SettingsRepository {
  get(userId: string, tx?: TxContext): Promise<UserSettings | null>;
  /** Inserts or replaces the row and takes a new change_seq. */
  save(userId: string, values: SettingsValues, tx: TxContext): Promise<UserSettings>;
  /** The settings if they changed after [cursor]. */
  changedSince(userId: string, cursor: number, tx?: TxContext): Promise<UserSettings | null>;
}
