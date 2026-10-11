/**
 * Port: delivers push messages (Firebase Cloud Messaging in production).
 *
 * - `alert` messages show a notification (title + body) on the device.
 * - `silent` messages carry only data, e.g. `{ type: 'sync' }`, and wake the
 *   app so it can refresh.
 */
export interface PushMessage {
  token: string;
  kind: 'alert' | 'silent';
  title?: string;
  body?: string;
  /** String values only (an FCM requirement). */
  data: Record<string, string>;
  /** Android notification channel, e.g. `task_reminders`. */
  channelId?: string;
  /** Newer messages with the same key replace older undelivered ones. */
  collapseKey?: string;
}

export interface PushResult {
  token: string;
  success: boolean;
  /** The token is dead (app uninstalled, token rotated): stop using it. */
  invalidToken: boolean;
  error?: string;
}

export interface PushGateway {
  /** False when push isn't configured; messages are then only logged. */
  readonly enabled: boolean;
  send(messages: PushMessage[]): Promise<PushResult[]>;
}
