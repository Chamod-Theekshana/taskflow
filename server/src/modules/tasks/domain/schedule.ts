import { DateTime, IANAZone } from 'luxon';

/**
 * Turns the calendar fields a user picked (day, time, "all day", time zone)
 * into instants. Same rules as the app:
 * - an all-day task is due at the end of its day (23:59:59),
 * - an all-day reminder fires at 09:00 that day,
 * - a timed reminder fires `reminderMinutes` before the due time.
 */
export interface ScheduleInput {
  dueDate: string;
  dueTime: string | null;
  isAllDay: boolean;
  timezone: string;
}

export function isValidTimeZone(zone: string): boolean {
  return IANAZone.isValidZone(zone);
}

export function isValidDate(value: string): boolean {
  return /^\d{4}-\d{2}-\d{2}$/.test(value) && DateTime.fromISO(value, { zone: 'utc' }).isValid;
}

export function isValidTime(value: string): boolean {
  return /^([01]\d|2[0-3]):[0-5]\d$/.test(value);
}

function local(dueDate: string, time: string, zone: string): DateTime {
  const parsed = DateTime.fromISO(`${dueDate}T${time}`, { zone });
  if (!parsed.isValid) throw new RangeError(`Invalid date ${dueDate} ${time} in ${zone}`);
  return parsed;
}

export function computeDueAt(input: ScheduleInput): Date {
  if (input.isAllDay) return local(input.dueDate, '23:59:59', input.timezone).toJSDate();
  return local(input.dueDate, input.dueTime ?? '00:00', input.timezone).toJSDate();
}

export function computeRemindAt(
  input: ScheduleInput & { reminder: boolean; reminderMinutes: number },
): Date | null {
  if (!input.reminder) return null;
  if (input.isAllDay) return local(input.dueDate, '09:00', input.timezone).toJSDate();
  return DateTime.fromJSDate(computeDueAt(input))
    .minus({ minutes: input.reminderMinutes })
    .toJSDate();
}

/** `YYYY-MM-DD` of [instant] in [zone]. */
export function localDate(instant: Date, zone: string): string {
  return DateTime.fromJSDate(instant, { zone }).toISODate() ?? '';
}

/** `HH:mm` of [instant] in [zone]. */
export function localTime(instant: Date, zone: string): string {
  return DateTime.fromJSDate(instant, { zone }).toFormat('HH:mm');
}
