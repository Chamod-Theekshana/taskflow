import { Router } from 'express';

import {
  bearerAuth,
  envelope,
  errorResponses,
  jsonContent,
  type OpenAPIRegistry,
} from '../../../core/http/openapi.js';
import { parseQuery, requireAuth } from '../../../core/http/validation.js';
import { z } from '../../../core/http/zod.js';
import { timezoneSchema } from '../../settings/application/settings.schemas.js';
import type { StatsService } from '../application/stats.service.js';
import { PERIODS } from '../domain/productivity.js';

const SummaryQuerySchema = z.object({
  period: z.enum(PERIODS).default('week'),
  timezone: timezoneSchema.optional().openapi({ description: "Defaults to the user's time zone." }),
});

const SummarySchema = z
  .object({
    period: z.enum(PERIODS),
    completed: z.number().int(),
    previousCompleted: z.number().int().nullable(),
    onTimeRate: z.number().openapi({ description: '0..1' }),
    overdue: z.number().int(),
    streak: z.number().int(),
    bestStreak: z.number().int(),
    flowScore: z.number().int().openapi({ description: '0..100' }),
    byWeekday: z.array(z.number().int()).openapi({ description: 'Monday first.' }),
    categories: z.array(z.object({ name: z.string(), count: z.number().int(), share: z.number() })),
    focusWindowStart: z.number().int().nullable(),
  })
  .openapi('StatsSummary');

/** /api/v1/stats (behind `authenticate`) */
export function statsRoutes(deps: { stats: StatsService }): Router {
  const router = Router();

  router.get('/summary', async (req, res) => {
    const { userId } = requireAuth(req);
    const q = parseQuery(SummaryQuerySchema, req);
    res.json({ data: await deps.stats.summary(userId, q.period, q.timezone) });
  });

  return router;
}

export function registerStatsDocs(registry: OpenAPIRegistry): void {
  registry.registerPath({
    method: 'get',
    path: '/api/v1/stats/summary',
    tags: ['Stats'],
    summary: 'Flow score, on-time rate, streaks and more',
    security: bearerAuth,
    request: { query: SummaryQuerySchema },
    responses: {
      200: jsonContent(envelope(SummarySchema), 'The report.'),
      401: errorResponses[401],
      422: errorResponses[422],
    },
  });
}
