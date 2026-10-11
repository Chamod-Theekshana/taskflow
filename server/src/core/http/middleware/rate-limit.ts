import type { RequestHandler } from 'express';
import { ipKeyGenerator, rateLimit } from 'express-rate-limit';

import { TooManyRequestsError } from '../../errors/app-error.js';

export interface RateLimitOptions {
  windowMs: number;
  limit: number;
  /** Per signed-in user instead of per IP (for authenticated routes). */
  perUser?: boolean;
}

/**
 * In-memory limiter: fine for one instance. With several replicas, plug a
 * shared store (e.g. `rate-limit-postgresql` or Redis) into `store`.
 */
export function limiter(options: RateLimitOptions): RequestHandler {
  return rateLimit({
    windowMs: options.windowMs,
    limit: options.limit,
    standardHeaders: 'draft-8',
    legacyHeaders: false,
    ...(options.perUser
      ? { keyGenerator: (req) => req.auth?.userId ?? ipKeyGenerator(req.ip ?? '0.0.0.0') }
      : {}),
    handler: (_req, _res, next) => next(new TooManyRequestsError()),
  });
}
