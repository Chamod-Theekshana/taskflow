import type { Logger } from '../../../core/logger.js';
import type { DeviceRepository } from '../../devices/domain/device.js';
import type { PushGateway, PushMessage, PushResult } from '../domain/push-gateway.js';

/** Sends through the gateway and forgets tokens FCM says are dead. */
export class PushDispatcher {
  constructor(
    private readonly gateway: PushGateway,
    private readonly devices: DeviceRepository,
    private readonly logger: Logger,
  ) {}

  get enabled(): boolean {
    return this.gateway.enabled;
  }

  async deliver(messages: PushMessage[]): Promise<PushResult[]> {
    if (messages.length === 0) return [];
    const results = await this.gateway.send(messages);

    const dead = results.filter((r) => r.invalidToken).map((r) => r.token);
    if (dead.length > 0) {
      await this.devices.clearPushTokens(dead);
      this.logger.info({ count: dead.length }, 'Removed invalid push tokens');
    }
    const failed = results.filter(
      (r) => !r.success && !r.invalidToken && r.error !== 'push_not_configured',
    );
    if (failed.length > 0) {
      this.logger.warn(
        { count: failed.length, errors: [...new Set(failed.map((f) => f.error))] },
        'Some pushes failed',
      );
    }
    return results;
  }
}
