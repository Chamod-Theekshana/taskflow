import type { RequestHandler } from 'express';

import { UnauthorizedError } from '../../errors/app-error.js';
import type { TokenService } from '../../security/token-service.js';
import type { Clock } from '../../utils/clock.js';

/**
 * Requires `Authorization: Bearer <access token>` and puts the user on
 * `req.auth`. Access tokens are verified statelessly (no database round trip);
 * they live 15 minutes and revocation happens at refresh time.
 */
export function authenticate(tokens: TokenService, clock: Clock): RequestHandler {
  return async (req, _res, next) => {
    const header = req.headers.authorization ?? '';
    const [scheme, token] = header.split(' ');
    if (scheme?.toLowerCase() !== 'bearer' || !token) {
      throw new UnauthorizedError('Missing bearer token.', 'missing_token');
    }
    const claims = await tokens.verifyAccessToken(token, clock.now());
    req.auth = { userId: claims.userId };
    next();
  };
}
