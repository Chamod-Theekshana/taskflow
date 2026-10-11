import { randomUUID } from 'node:crypto';

import { isUniqueViolation } from '../../../core/db/errors.js';
import type { TxContext, UnitOfWork } from '../../../core/db/unit-of-work.js';
import { ConflictError, UnauthorizedError } from '../../../core/errors/app-error.js';
import type { PasswordHasher } from '../../../core/security/password-hasher.js';
import { TokenService } from '../../../core/security/token-service.js';
import type { Clock } from '../../../core/utils/clock.js';
import type { SettingsService } from '../../settings/application/settings.service.js';
import type { RefreshTokenRepository } from '../domain/refresh-token.js';
import { normalizeEmail, type User, type UserRepository } from '../domain/user.js';
import type { LoginInput, RegisterInput, TokensDto } from './auth.schemas.js';

export interface SessionMeta {
  installationId?: string;
  userAgent?: string;
  ip?: string;
}

export interface Session {
  user: User;
  tokens: TokensDto;
}

/**
 * A rotated refresh token presented again this soon is treated as a harmless
 * race (two requests refreshing at once) rather than token theft.
 */
const REUSE_GRACE_MS = 30_000;

export class AuthService {
  private dummyHash?: Promise<string>;

  constructor(
    private readonly users: UserRepository,
    private readonly refreshTokens: RefreshTokenRepository,
    private readonly settings: SettingsService,
    private readonly hasher: PasswordHasher,
    private readonly tokens: TokenService,
    private readonly uow: UnitOfWork,
    private readonly clock: Clock,
    private readonly refreshTtlDays: number,
  ) {}

  async register(input: RegisterInput, meta: SessionMeta): Promise<Session> {
    const email = normalizeEmail(input.email);
    if (await this.users.findByEmail(email)) {
      throw new ConflictError('An account with this email already exists.', 'email_taken');
    }
    const passwordHash = await this.hasher.hash(input.password);

    try {
      return await this.uow.run(async (tx) => {
        const user = await this.users.create({ email, fullName: input.fullName, passwordHash }, tx);
        await this.settings.createDefaults(user.id, input.timezone ?? 'UTC', tx);
        return this.issueSession(user, randomUUID(), meta, tx);
      });
    } catch (error) {
      if (isUniqueViolation(error)) {
        throw new ConflictError('An account with this email already exists.', 'email_taken');
      }
      throw error;
    }
  }

  async login(input: LoginInput, meta: SessionMeta): Promise<Session> {
    const user = await this.users.findByEmail(input.email);
    // Hash even when the account doesn't exist so response times don't reveal which emails are registered.
    const ok = user
      ? await this.hasher.verify(user.passwordHash, input.password)
      : await this.hasher.verify(await this.getDummyHash(), input.password).then(() => false);
    if (!user || !ok)
      throw new UnauthorizedError('Invalid email or password.', 'invalid_credentials');

    return this.uow.run((tx) => this.issueSession(user, randomUUID(), meta, tx));
  }

  /**
   * Rotates a refresh token. Each token works once; presenting an already
   * rotated token (outside a short grace window) revokes the whole session,
   * because it means the token was copied.
   */
  async refresh(refreshToken: string, meta: SessionMeta): Promise<Session> {
    const now = this.clock.now();
    const hash = TokenService.hashRefreshToken(refreshToken);

    const outcome = await this.uow.run(async (tx) => {
      const stored = await this.refreshTokens.findByHashForUpdate(hash, tx);
      if (!stored) return { error: 'invalid' as const };

      if (stored.revokedAt) {
        const rotatedRecently =
          stored.replacedById !== null &&
          now.getTime() - stored.revokedAt.getTime() < REUSE_GRACE_MS;
        if (stored.replacedById !== null && !rotatedRecently) {
          await this.refreshTokens.revokeFamily(stored.familyId, now, tx);
          return { error: 'reused' as const };
        }
        return { error: 'revoked' as const };
      }
      if (stored.expiresAt.getTime() <= now.getTime()) return { error: 'expired' as const };

      const user = await this.users.findById(stored.userId, tx);
      if (!user) return { error: 'invalid' as const };

      const session = await this.issueSession(user, stored.familyId, meta, tx);
      await this.refreshTokens.markRotated(stored.id, session.tokenId, now, tx);
      return { session };
    });

    if (outcome.session) return { user: outcome.session.user, tokens: outcome.session.tokens };
    const reason = outcome.error ?? 'invalid';
    const messages = {
      invalid: 'Invalid refresh token.',
      revoked: 'This session has ended. Please sign in again.',
      reused: 'This session was ended for your security. Please sign in again.',
      expired: 'Your session expired. Please sign in again.',
    } as const;
    throw new UnauthorizedError(messages[reason], `refresh_token_${reason}`);
  }

  /** Ends the session the refresh token belongs to. Unknown tokens are ignored. */
  async logout(refreshToken: string): Promise<void> {
    const hash = TokenService.hashRefreshToken(refreshToken);
    await this.uow.run(async (tx) => {
      const stored = await this.refreshTokens.findByHashForUpdate(hash, tx);
      if (stored) await this.refreshTokens.revokeFamily(stored.familyId, this.clock.now(), tx);
    });
  }

  /** New access + refresh token pair inside [tx]. */
  async issueSession(
    user: User,
    familyId: string,
    meta: SessionMeta,
    tx: TxContext,
  ): Promise<Session & { tokenId: string }> {
    const now = this.clock.now();
    const { token, hash } = this.tokens.newRefreshToken();
    const record = await this.refreshTokens.create(
      {
        userId: user.id,
        familyId,
        tokenHash: hash,
        expiresAt: new Date(now.getTime() + this.refreshTtlDays * 86_400_000),
        installationId: meta.installationId ?? null,
        userAgent: meta.userAgent ?? null,
        ip: meta.ip ?? null,
      },
      tx,
    );
    const accessToken = await this.tokens.signAccessToken({ userId: user.id }, now);
    return {
      user,
      tokenId: record.id,
      tokens: {
        accessToken,
        refreshToken: token,
        tokenType: 'Bearer',
        expiresIn: this.tokens.accessTtlSeconds,
      },
    };
  }

  private getDummyHash(): Promise<string> {
    this.dummyHash ??= this.hasher.hash('timing-equaliser-Password1');
    return this.dummyHash;
  }
}
