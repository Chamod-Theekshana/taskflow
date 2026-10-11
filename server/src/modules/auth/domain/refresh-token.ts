import type { TxContext } from '../../../core/db/unit-of-work.js';

export interface RefreshToken {
  id: string;
  userId: string;
  familyId: string;
  expiresAt: Date;
  revokedAt: Date | null;
  replacedById: string | null;
  installationId: string | null;
}

export interface NewRefreshToken {
  userId: string;
  familyId: string;
  tokenHash: string;
  expiresAt: Date;
  installationId?: string | null;
  userAgent?: string | null;
  ip?: string | null;
}

export interface RefreshTokenRepository {
  create(token: NewRefreshToken, tx: TxContext): Promise<RefreshToken>;
  /** Locks the row for the rest of the transaction. */
  findByHashForUpdate(tokenHash: string, tx: TxContext): Promise<RefreshToken | null>;
  markRotated(id: string, replacedById: string, at: Date, tx: TxContext): Promise<void>;
  revokeFamily(familyId: string, at: Date, tx?: TxContext): Promise<void>;
  revokeAllForUser(userId: string, at: Date, tx: TxContext): Promise<void>;
  /** Removes tokens that expired or were revoked before [before]. */
  deleteStale(before: Date): Promise<number>;
}
