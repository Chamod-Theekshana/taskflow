import { and, eq, isNull, lt, or } from 'drizzle-orm';

import type { Database } from '../../../core/db/client.js';
import { refreshTokens, type RefreshTokenRow } from '../../../core/db/schema.js';
import { executor, type TxContext } from '../../../core/db/unit-of-work.js';
import type {
  NewRefreshToken,
  RefreshToken,
  RefreshTokenRepository,
} from '../domain/refresh-token.js';

function toDomain(row: RefreshTokenRow): RefreshToken {
  return {
    id: row.id,
    userId: row.userId,
    familyId: row.familyId,
    expiresAt: row.expiresAt,
    revokedAt: row.revokedAt,
    replacedById: row.replacedById,
    installationId: row.installationId,
  };
}

export class DrizzleRefreshTokenRepository implements RefreshTokenRepository {
  constructor(private readonly db: Database) {}

  async create(token: NewRefreshToken, tx: TxContext): Promise<RefreshToken> {
    const [row] = await executor(this.db, tx)
      .insert(refreshTokens)
      .values({
        userId: token.userId,
        familyId: token.familyId,
        tokenHash: token.tokenHash,
        expiresAt: token.expiresAt,
        installationId: token.installationId ?? null,
        userAgent: token.userAgent?.slice(0, 400) ?? null,
        ip: token.ip?.slice(0, 64) ?? null,
      })
      .returning();
    if (!row) throw new Error('Refresh token insert returned no row');
    return toDomain(row);
  }

  async findByHashForUpdate(tokenHash: string, tx: TxContext): Promise<RefreshToken | null> {
    const rows = await executor(this.db, tx)
      .select()
      .from(refreshTokens)
      .where(eq(refreshTokens.tokenHash, tokenHash))
      .limit(1)
      .for('update');
    return rows[0] ? toDomain(rows[0]) : null;
  }

  async markRotated(id: string, replacedById: string, at: Date, tx: TxContext): Promise<void> {
    await executor(this.db, tx)
      .update(refreshTokens)
      .set({ revokedAt: at, replacedById })
      .where(eq(refreshTokens.id, id));
  }

  async revokeFamily(familyId: string, at: Date, tx?: TxContext): Promise<void> {
    await executor(this.db, tx)
      .update(refreshTokens)
      .set({ revokedAt: at })
      .where(and(eq(refreshTokens.familyId, familyId), isNull(refreshTokens.revokedAt)));
  }

  async revokeAllForUser(userId: string, at: Date, tx: TxContext): Promise<void> {
    await executor(this.db, tx)
      .update(refreshTokens)
      .set({ revokedAt: at })
      .where(and(eq(refreshTokens.userId, userId), isNull(refreshTokens.revokedAt)));
  }

  async deleteStale(before: Date): Promise<number> {
    const deleted = await this.db
      .delete(refreshTokens)
      .where(or(lt(refreshTokens.expiresAt, before), lt(refreshTokens.revokedAt, before)))
      .returning({ id: refreshTokens.id });
    return deleted.length;
  }
}
