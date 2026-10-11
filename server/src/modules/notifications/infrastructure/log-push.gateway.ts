import type { Logger } from '../../../core/logger.js';
import type { PushGateway, PushMessage, PushResult } from '../domain/push-gateway.js';

/**
 * Used when FIREBASE_SERVICE_ACCOUNT is not set: nothing leaves the server,
 * each message is logged so the flow can still be followed while developing.
 */
export class LogPushGateway implements PushGateway {
  readonly enabled = false;

  constructor(private readonly logger: Logger) {}

  async send(messages: PushMessage[]): Promise<PushResult[]> {
    for (const m of messages) {
      this.logger.info(
        { kind: m.kind, title: m.title, data: m.data, token: `${m.token.slice(0, 8)}...` },
        'Push not sent (FCM not configured)',
      );
    }
    return messages.map((m) => ({
      token: m.token,
      success: false,
      invalidToken: false,
      error: 'push_not_configured',
    }));
  }
}

/** Records messages instead of sending them. For tests. */
export class InMemoryPushGateway implements PushGateway {
  readonly enabled = true;
  readonly sent: PushMessage[] = [];
  readonly invalidTokens = new Set<string>();

  async send(messages: PushMessage[]): Promise<PushResult[]> {
    this.sent.push(...messages);
    return messages.map((m) => {
      const invalid = this.invalidTokens.has(m.token);
      return { token: m.token, success: !invalid, invalidToken: invalid };
    });
  }

  clear(): void {
    this.sent.length = 0;
  }
}
