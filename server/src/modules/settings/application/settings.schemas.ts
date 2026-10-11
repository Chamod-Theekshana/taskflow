import { z } from '../../../core/http/zod.js';
import { isValidTime, isValidTimeZone } from '../../tasks/domain/schedule.js';
import { PRIORITIES } from '../../tasks/domain/task.js';
import { THEME_MODES, type UserSettings } from '../domain/settings.js';

export const timezoneSchema = z
  .string()
  .max(64)
  .refine(isValidTimeZone, 'Unknown IANA time zone.')
  .openapi({ example: 'Asia/Colombo' });

export const timeOfDaySchema = z
  .string()
  .refine(isValidTime, 'Use 24-hour HH:mm.')
  .openapi({ example: '08:00' });

export const isoDateTime = z.iso
  .datetime({ offset: true })
  .transform((value) => new Date(value))
  .openapi({ type: 'string', format: 'date-time', example: '2026-09-29T08:30:00.000Z' });

const categories = z.array(z.string().trim().min(1).max(24)).max(50);

export const SettingsSchema = z
  .object({
    notificationsEnabled: z.boolean(),
    dailyDigestEnabled: z.boolean(),
    dailyDigestTime: z.string().openapi({ example: '08:00' }),
    themeMode: z.enum(THEME_MODES),
    defaultPriority: z.enum(PRIORITIES),
    dailyGoal: z.number().int().min(1).max(20),
    customCategories: z.array(z.string()),
    timezone: z.string().openapi({ example: 'Asia/Colombo' }),
    updatedAt: z.string().openapi({ format: 'date-time' }),
  })
  .openapi('Settings');

export type SettingsDto = z.infer<typeof SettingsSchema>;

/** Partial update; `updatedAt` (client clock) decides conflicts between devices. */
export const SettingsPatchSchema = z
  .object({
    notificationsEnabled: z.boolean().optional(),
    dailyDigestEnabled: z.boolean().optional(),
    dailyDigestTime: timeOfDaySchema.optional(),
    themeMode: z.enum(THEME_MODES).optional(),
    defaultPriority: z.enum(PRIORITIES).optional(),
    dailyGoal: z.number().int().min(1).max(20).optional(),
    customCategories: categories.optional(),
    timezone: timezoneSchema.optional(),
    updatedAt: isoDateTime.optional(),
  })
  .strict()
  .openapi('SettingsPatch');

export type SettingsPatch = z.output<typeof SettingsPatchSchema>;

export function toSettingsDto(s: UserSettings): SettingsDto {
  return {
    notificationsEnabled: s.notificationsEnabled,
    dailyDigestEnabled: s.dailyDigestEnabled,
    dailyDigestTime: s.dailyDigestTime,
    themeMode: s.themeMode,
    defaultPriority: s.defaultPriority,
    dailyGoal: s.dailyGoal,
    customCategories: s.customCategories,
    timezone: s.timezone,
    updatedAt: s.updatedAt.toISOString(),
  };
}
