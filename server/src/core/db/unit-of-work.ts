import { sql } from 'drizzle-orm';

import type { Database } from './client.js';

declare const txBrand: unique symbol;

/**
 * An open database transaction, opaque to the domain and application layers.
 * Only repositories (infrastructure) know it is a Drizzle transaction.
 */
export interface TxContext {
  readonly [txBrand]: true;
}

export interface UnitOfWork {
  /** Runs [work] in one transaction: everything commits or nothing does. */
  run<T>(work: (tx: TxContext) => Promise<T>): Promise<T>;
}

export class DrizzleUnitOfWork implements UnitOfWork {
  constructor(private readonly db: Database) {}

  run<T>(work: (tx: TxContext) => Promise<T>): Promise<T> {
    return this.db.transaction((tx) => work(tx as unknown as TxContext));
  }
}

/** The transaction when there is one, otherwise the pool. */
export function executor(db: Database, tx?: TxContext): Database {
  return (tx as unknown as Database | undefined) ?? db;
}

/**
 * Serialises writes per user for the rest of the transaction.
 *
 * Sync relies on change_seq values of one user being committed in increasing
 * order; taking this lock before any write guarantees that. It also stops two
 * devices from racing on the same task.
 */
export async function lockUser(tx: TxContext, userId: string): Promise<void> {
  const db = tx as unknown as Database;
  await db.execute(sql`select pg_advisory_xact_lock(hashtextextended(${userId}, 0))`);
}
