import { randomUUID } from 'node:crypto';

import type { UnitOfWork } from '../../../core/db/unit-of-work.js';
import { NotFoundError, UnauthorizedError } from '../../../core/errors/app-error.js';
import type { PasswordHasher } from '../../../core/security/password-hasher.js';
import type { Clock } from '../../../core/utils/clock.js';
import type { AuthService, Session, SessionMeta } from '../../auth/application/auth.service.js';
import type { RefreshTokenRepository } from '../../auth/domain/refresh-token.js';
import type { User, UserRepository } from '../../auth/domain/user.js';

/** The signed-in user's own account: profile, password, deletion. */
export class AccountService {
  constructor(
    private readonly users: UserRepository,
    private readonly refreshTokens: RefreshTokenRepository,
    private readonly auth: AuthService,
    private readonly hasher: PasswordHasher,
    private readonly uow: UnitOfWork,
    private readonly clock: Clock,
  ) {}

  async me(userId: string): Promise<User> {
    const user = await this.users.findById(userId);
    if (!user) throw new NotFoundError('Account', 'account_not_found');
    return user;
  }

  async updateProfile(userId: string, input: { fullName: string }): Promise<User> {
    const user = await this.users.updateProfile(userId, input, this.clock.now());
    if (!user) throw new NotFoundError('Account', 'account_not_found');
    return user;
  }

  /** Changes the password, ends every other session and returns a fresh one. */
  async changePassword(
    userId: string,
    input: { currentPassword: string; newPassword: string },
    meta: SessionMeta,
  ): Promise<Session> {
    const user = await this.users.findById(userId);
    if (!user) throw new NotFoundError('Account', 'account_not_found');
    if (!(await this.hasher.verify(user.passwordHash, input.currentPassword))) {
      throw new UnauthorizedError('Your current password is not correct.', 'invalid_password');
    }
    const hash = await this.hasher.hash(input.newPassword);
    const now = this.clock.now();

    return this.uow.run(async (tx) => {
      await this.users.updatePassword(userId, hash, now, tx);
      await this.refreshTokens.revokeAllForUser(userId, now, tx);
      const session = await this.auth.issueSession(user, randomUUID(), meta, tx);
      return { user: session.user, tokens: session.tokens };
    });
  }

  /** Deletes the account and everything in it (tasks, devices, tokens...). */
  async deleteAccount(userId: string, password: string): Promise<void> {
    const user = await this.users.findById(userId);
    if (!user) return;
    if (!(await this.hasher.verify(user.passwordHash, password))) {
      throw new UnauthorizedError('Your password is not correct.', 'invalid_password');
    }
    await this.uow.run((tx) => this.users.delete(userId, tx));
  }
}
