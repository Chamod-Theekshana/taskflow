import { Router } from 'express';

import { jsonContent, type OpenAPIRegistry } from '../../../core/http/openapi.js';
import { z } from '../../../core/http/zod.js';

/** Liveness (the process runs) and readiness (it can reach the database). */
export function healthRoutes(deps: { ping: () => Promise<void>; version: string }): Router {
  const router = Router();

  router.get('/live', (_req, res) => {
    res.json({ status: 'ok', version: deps.version, uptime: Math.round(process.uptime()) });
  });

  router.get('/ready', async (_req, res) => {
    const started = Date.now();
    try {
      await deps.ping();
      res.json({ status: 'ok', database: 'up', latencyMs: Date.now() - started });
    } catch {
      res.status(503).json({ status: 'error', database: 'down' });
    }
  });

  return router;
}

export function registerHealthDocs(registry: OpenAPIRegistry): void {
  registry.registerPath({
    method: 'get',
    path: '/health/live',
    tags: ['Health'],
    summary: 'Liveness probe',
    responses: {
      200: jsonContent(
        z.object({ status: z.literal('ok'), version: z.string(), uptime: z.number() }),
        'Running.',
      ),
    },
  });
  registry.registerPath({
    method: 'get',
    path: '/health/ready',
    tags: ['Health'],
    summary: 'Readiness probe (checks the database)',
    responses: {
      200: jsonContent(
        z.object({ status: z.literal('ok'), database: z.literal('up'), latencyMs: z.number() }),
        'Ready.',
      ),
      503: jsonContent(
        z.object({ status: z.literal('error'), database: z.literal('down') }),
        'Database unreachable.',
      ),
    },
  });
}
