import type { TxContext } from '../../../core/db/unit-of-work.js';

export const NOTIFICATION_TYPES = ['reminder', 'digest', 'system', 'test'] as const;
export type NotificationType = (typeof NOTIFICATION_TYPES)[number];

/** An entry in the user's in-app inbox; also the record of what was pushed. */
export interface AppNotification {
  id: string;
  userId: string;
  type: NotificationType;
  title: string;
  body: string;
  data: Record<string, string>;
  taskId: string | null;
  readAt: Date | null;
  createdAt: Date;
}

export interface NewNotification {
  userId: string;
  type: NotificationType;
  title: string;
  body: string;
  data?: Record<string, string>;
  taskId?: string | null;
  /** Unique; a second insert with the same key is ignored. */
  dedupeKey?: string | null;
}

export interface NotificationRepository {
  /** Inserts unless a notification with the same dedupe key exists; returns null then. */
  createIfAbsent(notification: NewNotification, tx?: TxContext): Promise<AppNotification | null>;
  list(
    userId: string,
    options: { unreadOnly: boolean; limit: number; before?: Date },
  ): Promise<AppNotification[]>;
  markRead(userId: string, id: string, now: Date): Promise<boolean>;
  markAllRead(userId: string, now: Date): Promise<number>;
  recordPushes(id: string, count: number): Promise<void>;
  deleteOlderThan(before: Date): Promise<number>;
}
