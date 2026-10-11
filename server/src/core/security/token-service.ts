import { createHash, randomBytes, randomUUID } from 'node:crypto';

import { errors as joseErrors, jwtVerify, SignJWT } from 'jose';

import { UnauthorizedError } from '../errors/app-error.js';

export interface AccessTokenClaims {
  userId: string;
}

export interface TokenServiceOptions {
  secret: string;
  issuer: string;
  audience: string;
  accessTtlSeconds: number;
}

/**
 * Short-lived JWT access tokens (HS256) and opaque refresh tokens.
 *
 * Refresh tokens are 256 random bits. Only their SHA-256 is stored, so a
 * database leak does not hand out working sessions.
 */
export class TokenService {
  private readonly key: Uint8Array;

  constructor(private readonly options: TokenServiceOptions) {
    this.key = new TextEncoder().encode(options.secret);
  }

  get accessTtlSeconds(): number {
    return this.options.accessTtlSeconds;
  }

  async signAccessToken(claims: AccessTokenClaims, now: Date): Promise<string> {
    const issuedAt = Math.floor(now.getTime() / 1000);
    return new SignJWT({})
      .setProtectedHeader({ alg: 'HS256', typ: 'JWT' })
      .setSubject(claims.userId)
      .setIssuer(this.options.issuer)
      .setAudience(this.options.audience)
      .setJti(randomUUID())
      .setIssuedAt(issuedAt)
      .setExpirationTime(issuedAt + this.options.accessTtlSeconds)
      .sign(this.key);
  }

  async verifyAccessToken(
    token: string,
    now: Date,
  ): Promise<AccessTokenClaims & { issuedAt: Date }> {
    try {
      const { payload } = await jwtVerify(token, this.key, {
        issuer: this.options.issuer,
        audience: this.options.audience,
        algorithms: ['HS256'],
        currentDate: now,
      });
      if (!payload.sub) throw new UnauthorizedError('Invalid access token.', 'invalid_token');
      return { userId: payload.sub, issuedAt: new Date((payload.iat ?? 0) * 1000) };
    } catch (error) {
      if (error instanceof UnauthorizedError) throw error;
      if (error instanceof joseErrors.JWTExpired) {
        throw new UnauthorizedError('Access token expired.', 'token_expired');
      }
      throw new UnauthorizedError('Invalid access token.', 'invalid_token');
    }
  }

  newRefreshToken(): { token: string; hash: string } {
    const token = randomBytes(32).toString('base64url');
    return { token, hash: TokenService.hashRefreshToken(token) };
  }

  static hashRefreshToken(token: string): string {
    return createHash('sha256').update(token).digest('hex');
  }
}
