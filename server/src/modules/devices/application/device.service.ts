import { NotFoundError } from '../../../core/errors/app-error.js';
import type { Clock } from '../../../core/utils/clock.js';
import type { Device, DeviceRegistration, DeviceRepository } from '../domain/device.js';

export class DeviceService {
  constructor(
    private readonly devices: DeviceRepository,
    private readonly clock: Clock,
  ) {}

  register(userId: string, registration: DeviceRegistration): Promise<Device> {
    return this.devices.register(userId, registration, this.clock.now());
  }

  /** Called on sign-out: the device stops getting pushes for this account. */
  async unregister(userId: string, installationId: string): Promise<void> {
    const removed = await this.devices.remove(userId, installationId);
    if (!removed) throw new NotFoundError('Device', 'device_not_found');
  }
}
