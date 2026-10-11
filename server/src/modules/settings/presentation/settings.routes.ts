import { Router } from 'express';

import {
  bearerAuth,
  envelope,
  errorResponses,
  jsonContent,
  type OpenAPIRegistry,
} from '../../../core/http/openapi.js';
import { parseBody, requireAuth } from '../../../core/http/validation.js';
import type { SettingsService } from '../application/settings.service.js';
import {
  SettingsPatchSchema,
  SettingsSchema,
  toSettingsDto,
} from '../application/settings.schemas.js';

/** /api/v1/settings (behind `authenticate`) */
export function settingsRoutes(deps: { settings: SettingsService }): Router {
  const { settings } = deps;
  const router = Router();

  router.get('/', async (req, res) => {
    const { userId } = requireAuth(req);
    res.json({ data: toSettingsDto(await settings.get(userId)) });
  });

  router.patch('/', async (req, res) => {
    const { userId } = requireAuth(req);
    const patch = parseBody(SettingsPatchSchema, req);
    res.json({ data: toSettingsDto(await settings.update(userId, patch, req.installationId)) });
  });

  return router;
}

export function registerSettingsDocs(registry: OpenAPIRegistry): void {
  registry.registerPath({
    method: 'get',
    path: '/api/v1/settings',
    tags: ['Settings'],
    summary: 'My preferences',
    security: bearerAuth,
    responses: {
      200: jsonContent(envelope(SettingsSchema), 'Settings.'),
      401: errorResponses[401],
    },
  });

  registry.registerPath({
    method: 'patch',
    path: '/api/v1/settings',
    tags: ['Settings'],
    summary: 'Change preferences',
    description:
      'Only the fields sent change. If `updatedAt` is older than the stored value the patch is ignored.',
    security: bearerAuth,
    request: { body: { content: { 'application/json': { schema: SettingsPatchSchema } } } },
    responses: {
      200: jsonContent(envelope(SettingsSchema), 'The resulting settings.'),
      401: errorResponses[401],
      422: errorResponses[422],
    },
  });
}
