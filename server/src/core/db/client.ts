import { Pool as NeonPool, neonConfig } from '@neondatabase/serverless';
import { sql } from 'drizzle-orm';
import { drizzle as drizzleNeon } from 'drizzle-orm/neon-serverless';
import { drizzle as drizzlePg } from 'drizzle-orm/node-postgres';
import type { PgDatabase, PgQueryResultHKT } from 'drizzle-orm/pg-core';
import pg from 'pg';
import ws from 'ws';

import * as schema from './schema.js';

/**
 * The Drizzle database, independent of the driver underneath: Neon's
 * serverless driver in production, node-postgres against a local Postgres,
 * PGlite in the tests.
 */
export type Database = PgDatabase<PgQueryResultHKT, typeof schema>;

export interface DatabaseHandle {
  db: Database;
  driver: 'neon' | 'pg' | 'pglite';
  ping(): Promise<void>;
  close(): Promise<void>;
}

export interface DatabaseOptions {
  url: string;
  driver: 'neon' | 'pg';
  poolMax: number;
}

export function createDatabase(options: DatabaseOptions): DatabaseHandle {
  if (options.driver === 'neon') {
    // Node 22 ships a WebSocket, but `ws` is faster and handles proxies/keep-alive better.
    neonConfig.webSocketConstructor = ws;
    const pool = new NeonPool({ connectionString: options.url, max: options.poolMax });
    const db = drizzleNeon({ client: pool, schema }) as unknown as Database;
    return {
      db,
      driver: 'neon',
      ping: async () => {
        await db.execute(sql`select 1`);
      },
      close: () => pool.end(),
    };
  }

  const pool = new pg.Pool({
    connectionString: options.url,
    max: options.poolMax,
    idleTimeoutMillis: 30_000,
    connectionTimeoutMillis: 10_000,
  });
  const db = drizzlePg({ client: pool, schema }) as unknown as Database;
  return {
    db,
    driver: 'pg',
    ping: async () => {
      await db.execute(sql`select 1`);
    },
    close: () => pool.end(),
  };
}

export { schema };
