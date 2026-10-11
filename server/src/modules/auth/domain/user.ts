import type { TxContext } from '../../../core/db/unit-of-work.js';

/** Mirrors `User` in the app (features/auth/domain/entities/user.dart). */
export interface User {
  id: string;
  email: string;
  fullName: string;
  createdAt: Date;
  updatedAt: Date;
}

export interface UserCredentials extends User {
  passwordHash: string;
  passwordChangedAt: Date | null;
}

export function normalizeEmail(email: string): string {
  return email.trim().toLowerCase();
}

export interface UserRepository {
  findById(id: string, tx?: TxContext): Promise<UserCredentials | null>;
  findByEmail(email: string, tx?: TxContext): Promise<UserCredentials | null>;
  create(
    data: { email: string; fullName: string; passwordHash: string },
    tx: TxContext,
  ): Promise<User>;
  updateProfile(id: string, data: { fullName: string }, now: Date): Promise<User | null>;
  updatePassword(id: string, passwordHash: string, now: Date, tx: TxContext): Promise<void>;
  delete(id: string, tx: TxContext): Promise<void>;
}
