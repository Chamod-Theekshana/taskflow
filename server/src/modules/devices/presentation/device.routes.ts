import { Router, type Request } from 'express';

import { NotFoundError } from '../../../core/errors/app-error.js';
import {
  bearerAuth,
  envelope,
  errorResponses,
  jsonContent,
  type OpenAPIRegistry,
} from '../../../core/http/openapi.js';
import { parseBody, requireAuth } from '../../../core/http/validation.js';
import { z } from '../../../core/http/zod.js';
import { timezoneSchema } from '../../settings/application/settings.schemas.js';
import type { DeviceService } from '../application/device.service.js';
import { PLATFORMS, type Device } from '../domain/device.js';

const installationIdSchema = z
  .string()
  .regex(/^[A-Za-z0-9._-]{8,64}$/)
  .openapi({
    description: 'Random id generated once per install.',
    example: '3f2b8c1e-5d7a-4c55-9f3e-8a1b2c3d4e5f',
  });

const RegisterDeviceSchema = z
  .object({
    platform: z.enum(PLATFORMS),
    pushToken: z
      .string()
      .min(10)
      .max(4096)
      .nullable()
      .optional()
      .openapi({ description: 'FCM registration token; null to stop pushes.' }),
    appVersion: z.string().max(32).nullable().optional(),
    timezone: timezoneSchema.nullable().optional(),
    localReminders: z
      .boolean()
      .default(true)
      .openapi({ description: 'The client schedules reminders itself (the mobile app does).' }),
  })
  .strict()
  .openapi('RegisterDeviceRequest');

const DeviceSchema = z
  .object({
    installationId: z.string(),
    platform: z.enum(PLATFORMS),
    pushEnabled: z.boolean(),
    appVersion: z.string().nullable(),
    timezone: z.string().nullable(),
    localReminders: z.boolean(),
    lastSeenAt: z.string().openapi({ format: 'date-time' }),
  })
  .openapi('Device');

const toDeviceDto = (d: Device): z.infer<typeof DeviceSchema> => ({
  installationId: d.installationId,
  platform: d.platform,
  pushEnabled: d.pushToken !== null,
  appVersion: d.appVersion,
  timezone: d.timezone,
  localReminders: d.localReminders,
  lastSeenAt: d.lastSeenAt.toISOString(),
});

function installationParam(req: Request): string {
  const parsed = installationIdSchema.safeParse(req.params.installationId);
  if (!parsed.success) throw new NotFoundError('Device', 'device_not_found');
  return parsed.data;
}

/** /api/v1/devices (behind `authenticate`) */
export function deviceRoutes(deps: { devices: DeviceService }): Router {
  const { devices } = deps;
  const router = Router();

  router.put('/:installationId', async (req, res) => {
    const { userId } = requireAuth(req);
    const installationId = installationParam(req);
    const input = parseBody(RegisterDeviceSchema, req);
    const device = await devices.register(userId, { installationId, ...input });
    res.json({ data: toDeviceDto(device) });
  });

  router.delete('/:installationId', async (req, res) => {
    const { userId } = requireAuth(req);
    await devices.unregister(userId, installationParam(req));
    res.status(204).end();
  });

  return router;
}

export function registerDeviceDocs(registry: OpenAPIRegistry): void {
  const params = z.object({ installationId: installationIdSchema });

  registry.registerPath({
    method: 'put',
    path: '/api/v1/devices/{installationId}',
    tags: ['Devices'],
    summary: 'Register this device (and its push token)',
    description: 'Idempotent. Call at sign-in, on start-up and whenever FCM hands out a new token.',
    security: bearerAuth,
    request: {
      params,
      body: { content: { 'application/json': { schema: RegisterDeviceSchema } } },
    },
    responses: {
      200: jsonContent(envelope(DeviceSchema), 'Registered.'),
      401: errorResponses[401],
      422: errorResponses[422],
    },
  });

  registry.registerPath({
    method: 'delete',
    path: '/api/v1/devices/{installationId}',
    tags: ['Devices'],
    summary: 'Unregister this device',
    description: 'Call on sign-out so the device stops receiving pushes for the account.',
    security: bearerAuth,
    request: { params },
    responses: {
      204: { description: 'Removed.' },
      401: errorResponses[401],
      404: errorResponses[404],
    },
  });
}
