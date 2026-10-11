export const PLATFORMS = ['android', 'ios', 'web', 'other'] as const;
export type Platform = (typeof PLATFORMS)[number];

/** One installation of the app (or a browser) signed in to an account. */
export interface Device {
  id: string;
  userId: string;
  installationId: string;
  platform: Platform;
  pushToken: string | null;
  appVersion: string | null;
  timezone: string | null;
  /** Schedules reminders and the digest on the device itself. */
  localReminders: boolean;
  lastPulledSeq: number;
  lastSeenAt: Date;
  createdAt: Date;
}

export interface DeviceRegistration {
  installationId: string;
  platform: Platform;
  pushToken?: string | null;
  appVersion?: string | null;
  timezone?: string | null;
  localReminders: boolean;
}

export interface DeviceRepository {
  /**
   * Creates or updates the device. A push token can only belong to one
   * device: it is taken away from any other row first (reinstall, account switch).
   */
  register(userId: string, registration: DeviceRegistration, now: Date): Promise<Device>;
  remove(userId: string, installationId: string): Promise<boolean>;
  /** Records how far the device has synced (creates a bare row if needed). */
  markPulled(userId: string, installationId: string, seq: number, now: Date): Promise<void>;
  /** Devices of [userId] with a push token, except [excludeInstallationId]. */
  pushTargets(userId: string, excludeInstallationId?: string): Promise<Device[]>;
  /** Forgets tokens FCM reported as invalid. */
  clearPushTokens(tokens: string[]): Promise<void>;
  deleteInactive(before: Date): Promise<number>;
}
