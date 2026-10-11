import { eq } from 'drizzle-orm';

import type { Database } from '../../../core/db/client.js';
import { users, type UserRow } from '../../../core/db/schema.js';
import { executor, type TxContext } from '../../../core/db/unit-of-work.js';
import {
  normalizeEmail,
  type User,
  type UserCredentials,
  type UserRepository,
} from '../domain/user.js';

function toUser(row: UserRow): User {
  return {
    id: row.id,
    email: row.email,
    fullName: row.fullName,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
  };
}

function toCredentials(row: UserRow): UserCredentials {
  return {
    ...toUser(row),
    passwordHash: row.passwordHash,
    passwordChangedAt: row.passwordChangedAt,
  };
}

export class DrizzleUserRepository implements UserRepository {
  constructor(private readonly db: Database) {}

  async findById(id: string, tx?: TxContext): Promise<UserCredentials | null> {
    const rows = await executor(this.db, tx).select().from(users).where(eq(users.id, id)).limit(1);
    return rows[0] ? toCredentials(rows[0]) : null;
  }

  async findByEmail(email: string, tx?: TxContext): Promise<UserCredentials | null> {
    const rows = await executor(this.db, tx)
      .select()
      .from(users)
      .where(eq(users.email, normalizeEmail(email)))
      .limit(1);
    return rows[0] ? toCredentials(rows[0]) : null;
  }

  async create(
    data: { email: string; fullName: string; passwordHash: string },
    tx: TxContext,
  ): Promise<User> {
    const [row] = await executor(this.db, tx)
      .insert(users)
      .values({
        email: normalizeEmail(data.email),
        fullName: data.fullName.trim(),
        passwordHash: data.passwordHash,
      })
      .returning();
    if (!row) throw new Error('User insert returned no row');
    return toUser(row);
  }

  async updateProfile(id: string, data: { fullName: string }, now: Date): Promise<User | null> {
    const [row] = await this.db
      .update(users)
      .set({ fullName: data.fullName.trim(), updatedAt: now })
      .where(eq(users.id, id))
      .returning();
    return row ? toUser(row) : null;
  }

  async updatePassword(id: string, passwordHash: string, now: Date, tx: TxContext): Promise<void> {
    await executor(this.db, tx)
      .update(users)
      .set({ passwordHash, passwordChangedAt: now, updatedAt: now })
      .where(eq(users.id, id));
  }

  async delete(id: string, tx: TxContext): Promise<void> {
    await executor(this.db, tx).delete(users).where(eq(users.id, id));
  }
}
