import { Router, type RequestHandler } from 'express';

import {
  bearerAuth,
  envelope,
  errorResponses,
  jsonContent,
  type OpenAPIRegistry,
} from '../../../core/http/openapi.js';
import { parseBody, parseQuery, requireAuth } from '../../../core/http/validation.js';
import { z } from '../../../core/http/zod.js';
import { toSettingsDto } from '../../settings/application/settings.schemas.js';
import { toTaskDto } from '../../tasks/application/task.schemas.js';
import {
  ChangeSchema,
  PullQuerySchema,
  PullResponseSchema,
  PushRequestSchema,
  PushResponseSchema,
} from '../application/sync.schemas.js';
import type { SyncService } from '../application/sync.service.js';

/** /api/v1/sync (behind `authenticate`) */
export function syncRoutes(deps: { sync: SyncService; limiter: RequestHandler }): Router {
  const { sync, limiter } = deps;
  const router = Router();

  router.get('/pull', limiter, async (req, res) => {
    const { userId } = requireAuth(req);
    const q = parseQuery(PullQuerySchema, req);
    const result = await sync.pull(userId, req.installationId, q.cursor, q.limit);
    res.json({
      data: {
        tasks: result.tasks.map(toTaskDto),
        settings: result.settings ? toSettingsDto(result.settings) : null,
        cursor: result.cursor,
        hasMore: result.hasMore,
      },
    });
  });

  router.post('/push', limiter, async (req, res) => {
    const { userId } = requireAuth(req);
    const body = parseBody(PushRequestSchema, req);
    res.json({ data: await sync.push(userId, req.installationId, body) });
  });

  return router;
}

export function registerSyncDocs(registry: OpenAPIRegistry): void {
  registry.register('SyncChange', ChangeSchema);
  const deviceHeader = z.object({
    'x-device-id': z
      .string()
      .optional()
      .openapi({ description: 'Installation id of the calling device.' }),
  });

  registry.registerPath({
    method: 'get',
    path: '/api/v1/sync/pull',
    tags: ['Sync'],
    summary: 'Changes since a cursor',
    description:
      'Returns tasks (with tombstones) and settings changed after `cursor`. Keep calling with the returned ' +
      '`cursor` while `hasMore` is true. With `X-Device-Id` the server also records how far this device has synced, ' +
      'which decides whether it still needs reminder pushes.',
    security: bearerAuth,
    request: { query: PullQuerySchema, headers: deviceHeader },
    responses: {
      200: jsonContent(envelope(PullResponseSchema), 'A page of changes.'),
      401: errorResponses[401],
      422: errorResponses[422],
    },
  });

  registry.registerPath({
    method: 'post',
    path: '/api/v1/sync/push',
    tags: ['Sync'],
    summary: 'Upload local changes',
    description:
      'Up to 200 changes per call. Each is applied independently with last-write-wins on `updatedAt`. ' +
      'Pull afterwards to receive what other devices changed.',
    security: bearerAuth,
    request: {
      headers: deviceHeader,
      body: { content: { 'application/json': { schema: PushRequestSchema } } },
    },
    responses: {
      200: jsonContent(envelope(PushResponseSchema), 'Per-change results.'),
      401: errorResponses[401],
      422: errorResponses[422],
      429: errorResponses[429],
    },
  });
}
