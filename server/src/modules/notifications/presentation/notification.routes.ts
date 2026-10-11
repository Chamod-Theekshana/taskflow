import { Router, type RequestHandler } from 'express';

import {
  bearerAuth,
  envelope,
  errorResponses,
  jsonContent,
  type OpenAPIRegistry,
} from '../../../core/http/openapi.js';
import { idParams, uuidParam } from '../../../core/http/params.js';
import { parseQuery, requireAuth } from '../../../core/http/validation.js';
import { z } from '../../../core/http/zod.js';
import { isoDateTime } from '../../settings/application/settings.schemas.js';
import type { NotificationService } from '../application/notification.service.js';
import { NOTIFICATION_TYPES, type AppNotification } from '../domain/notification.js';

const ListQuerySchema = z.object({
  unread: z
    .enum(['true', 'false'])
    .default('false')
    .transform((v) => v === 'true'),
  limit: z.coerce.number().int().min(1).max(100).default(50),
  before: isoDateTime
    .optional()
    .openapi({ description: '`createdAt` of the last item of the previous page.' }),
});

const NotificationSchema = z
  .object({
    id: z.uuid(),
    type: z.enum(NOTIFICATION_TYPES),
    title: z.string(),
    body: z.string(),
    data: z.record(z.string(), z.string()),
    taskId: z.uuid().nullable(),
    read: z.boolean(),
    createdAt: z.string().openapi({ format: 'date-time' }),
  })
  .openapi('Notification');

const TestResultSchema = z
  .object({
    devices: z.number().int(),
    delivered: z.number().int(),
    pushConfigured: z.boolean(),
  })
  .openapi('TestPushResult');

const toDto = (n: AppNotification): z.infer<typeof NotificationSchema> => ({
  id: n.id,
  type: n.type,
  title: n.title,
  body: n.body,
  data: n.data,
  taskId: n.taskId,
  read: n.readAt !== null,
  createdAt: n.createdAt.toISOString(),
});

/** /api/v1/notifications (behind `authenticate`) */
export function notificationRoutes(deps: {
  notifications: NotificationService;
  testLimiter: RequestHandler;
}): Router {
  const { notifications, testLimiter } = deps;
  const router = Router();

  router.get('/', async (req, res) => {
    const { userId } = requireAuth(req);
    const q = parseQuery(ListQuerySchema, req);
    const items = await notifications.list(userId, {
      unreadOnly: q.unread,
      limit: q.limit,
      before: q.before,
    });
    res.json({ data: items.map(toDto) });
  });

  router.post('/read-all', async (req, res) => {
    const { userId } = requireAuth(req);
    res.json({ data: { updated: await notifications.markAllRead(userId) } });
  });

  router.post('/test', testLimiter, async (req, res) => {
    const { userId } = requireAuth(req);
    res.json({ data: await notifications.sendTest(userId) });
  });

  router.post('/:id/read', async (req, res) => {
    const { userId } = requireAuth(req);
    await notifications.markRead(userId, uuidParam(req, 'id', 'Notification'));
    res.status(204).end();
  });

  return router;
}

export function registerNotificationDocs(registry: OpenAPIRegistry): void {
  const tags = ['Notifications'];

  registry.registerPath({
    method: 'get',
    path: '/api/v1/notifications',
    tags,
    summary: 'Inbox: reminders and digests the server created',
    security: bearerAuth,
    request: { query: ListQuerySchema },
    responses: {
      200: jsonContent(envelope(z.array(NotificationSchema)), 'Newest first.'),
      401: errorResponses[401],
    },
  });

  registry.registerPath({
    method: 'post',
    path: '/api/v1/notifications/{id}/read',
    tags,
    summary: 'Mark one as read',
    security: bearerAuth,
    request: { params: idParams('id') },
    responses: {
      204: { description: 'Marked.' },
      401: errorResponses[401],
      404: errorResponses[404],
    },
  });

  registry.registerPath({
    method: 'post',
    path: '/api/v1/notifications/read-all',
    tags,
    summary: 'Mark all as read',
    security: bearerAuth,
    responses: {
      200: jsonContent(envelope(z.object({ updated: z.number().int() })), 'How many changed.'),
      401: errorResponses[401],
    },
  });

  registry.registerPath({
    method: 'post',
    path: '/api/v1/notifications/test',
    tags,
    summary: 'Send a test push to all my devices',
    security: bearerAuth,
    responses: {
      200: jsonContent(envelope(TestResultSchema), 'What happened.'),
      401: errorResponses[401],
      429: errorResponses[429],
    },
  });
}
