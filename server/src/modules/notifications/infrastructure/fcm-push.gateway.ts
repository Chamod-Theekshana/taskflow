import { cert, getApps, initializeApp, type App, type ServiceAccount } from 'firebase-admin/app';
import { getMessaging, type Message } from 'firebase-admin/messaging';

import type { Logger } from '../../../core/logger.js';
import type { PushGateway, PushMessage, PushResult } from '../domain/push-gateway.js';

const INVALID_TOKEN_CODES = new Set([
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
]);

/** FCM allows at most 500 messages per batch. */
const BATCH_SIZE = 500;

const BRAND_COLOR = '#FF6B00';

/** Firebase Cloud Messaging (HTTP v1 API) through the Admin SDK. Covers Android and iOS (APNs). */
export class FcmPushGateway implements PushGateway {
  readonly enabled = true;
  private readonly app: App;

  constructor(
    serviceAccount: Record<string, unknown>,
    private readonly logger: Logger,
  ) {
    const name = 'taskflow-push';
    this.app =
      getApps().find((a) => a.name === name) ??
      initializeApp({ credential: cert(serviceAccount as ServiceAccount) }, name);
  }

  async send(messages: PushMessage[]): Promise<PushResult[]> {
    const results: PushResult[] = [];
    for (let i = 0; i < messages.length; i += BATCH_SIZE) {
      const batch = messages.slice(i, i + BATCH_SIZE);
      try {
        const response = await getMessaging(this.app).sendEach(batch.map(toFcmMessage));
        response.responses.forEach((r, index) => {
          const token = batch[index]!.token;
          const code = r.error?.code;
          results.push({
            token,
            success: r.success,
            invalidToken: code !== undefined && INVALID_TOKEN_CODES.has(code),
            error: code,
          });
        });
      } catch (error) {
        this.logger.error({ err: error, count: batch.length }, 'FCM batch failed');
        for (const m of batch) {
          results.push({
            token: m.token,
            success: false,
            invalidToken: false,
            error: 'batch_failed',
          });
        }
      }
    }
    return results;
  }
}

function toFcmMessage(m: PushMessage): Message {
  if (m.kind === 'silent') {
    return {
      token: m.token,
      data: m.data,
      android: { priority: 'high', collapseKey: m.collapseKey, ttl: 60 * 60 * 1000 },
      apns: {
        headers: { 'apns-push-type': 'background', 'apns-priority': '5' },
        payload: { aps: { contentAvailable: true } },
      },
    };
  }
  return {
    token: m.token,
    notification: { title: m.title, body: m.body },
    data: m.data,
    android: {
      priority: 'high',
      collapseKey: m.collapseKey,
      notification: {
        channelId: m.channelId,
        icon: 'ic_notification',
        color: BRAND_COLOR,
        tag: m.collapseKey,
      },
    },
    apns: {
      headers: {
        'apns-priority': '10',
        ...(m.collapseKey ? { 'apns-collapse-id': m.collapseKey } : {}),
      },
      payload: { aps: { sound: 'default' } },
    },
  };
}
