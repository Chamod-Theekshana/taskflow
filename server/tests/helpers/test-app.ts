import { fileURLToPath } from 'node:url';

import { PGlite } from '@electric-sql/pglite';
import { sql } from 'drizzle-orm';
import { drizzle } from 'drizzle-orm/pglite';
import { migrate } from 'drizzle-orm/pglite/migrator';
import supertest from 'supertest';

import { createApp } from '../../src/app.js';
import { loadConfig } from '../../src/config/env.js';
import { createContainer } from '../../src/container.js';
import type { Database, DatabaseHandle } from '../../src/core/db/client.js';
import * as schema from '../../src/core/db/schema.js';
import { createLogger } from '../../src/core/logger.js';
import { FixedClock } from '../../src/core/utils/clock.js';
import { InMemoryPushGateway } from '../../src/modules/notifications/infrastructure/log-push.gateway.js';

const migrationsFolder = fileURLToPath(new URL('../../drizzle', import.meta.url));

/**
 * A complete API on an in-memory PostgreSQL (PGlite), with the real
 * migrations, a controllable clock and a push gateway that records messages.
 */
export async function createTestApp(
  start = new Date('2026-09-29T08:00:00.000Z'),
  options: { accessTtlSeconds?: number } = {},
) {
  const client = new PGlite();
  await migrate(drizzle({ client }), { migrationsFolder });
  const db = drizzle({ client, schema }) as unknown as Database;

  const database: DatabaseHandle = {
    db,
    driver: 'pglite',
    ping: async () => {
      await db.execute(sql`select 1`);
    },
    close: () => client.close(),
  };

  const config = loadConfig({
    NODE_ENV: 'test',
    DATABASE_URL: 'postgres://test:test@localhost:5432/test',
    JWT_ACCESS_SECRET: 'test-secret-that-is-long-enough-for-hs256-0123456789',
    LOG_LEVEL: 'silent',
    JOBS_ENABLED: 'false',
    JWT_ACCESS_TTL_SECONDS: String(options.accessTtlSeconds ?? 900),
  });
  const logger = createLogger({ level: 'silent', pretty: false });
  const clock = new FixedClock(start);
  const push = new InMemoryPushGateway();
  const container = createContainer({
    config,
    database,
    logger,
    clock,
    pushGateway: push,
    syncPushDelayMs: 0,
  });
  const app = createApp(container, {
    rateLimits: { globalPerMinute: 10_000, authPerMinute: 10_000, syncPerMinute: 10_000 },
  });
  const request = supertest(app);

  let counter = 0;
  /** Registers a fresh user and returns an authorised request helper. */
  async function signUp(overrides: { email?: string; timezone?: string } = {}) {
    counter += 1;
    const email = overrides.email ?? `user${counter}@example.com`;
    const res = await request
      .post('/api/v1/auth/register')
      .send({
        fullName: `User ${counter}`,
        email,
        password: 'Secret123',
        timezone: overrides.timezone ?? 'Asia/Colombo',
      })
      .expect(201);
    const token: string = res.body.data.tokens.accessToken;
    const auth = { Authorization: `Bearer ${token}` };
    return {
      email,
      userId: res.body.data.user.id as string,
      tokens: res.body.data.tokens as { accessToken: string; refreshToken: string },
      auth,
      get: (url: string, device?: string) =>
        request
          .get(url)
          .set(auth)
          .set(device ? { 'X-Device-Id': device } : {}),
      post: (url: string, body?: object, device?: string) =>
        request
          .post(url)
          .set(auth)
          .set(device ? { 'X-Device-Id': device } : {})
          .send(body ?? {}),
      patch: (url: string, body: object, device?: string) =>
        request
          .patch(url)
          .set(auth)
          .set(device ? { 'X-Device-Id': device } : {})
          .send(body),
      put: (url: string, body: object) => request.put(url).set(auth).send(body),
      del: (url: string, body?: object) =>
        request
          .delete(url)
          .set(auth)
          .send(body ?? {}),
    };
  }

  return {
    app,
    request,
    container,
    clock,
    push,
    db,
    signUp,
    /** Lets fire-and-forget sync pushes finish. */
    settle: () => container.syncNotifier.flushAll(),
    close: () => container.shutdown(),
  };
}

export type TestApp = Awaited<ReturnType<typeof createTestApp>>;
export type TestUser = Awaited<ReturnType<TestApp['signUp']>>;
