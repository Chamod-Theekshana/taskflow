import { Router, type Request, type RequestHandler } from 'express';

import { parseBody } from '../../../core/http/validation.js';
import type { AuthService, Session, SessionMeta } from '../application/auth.service.js';
import {
  LoginSchema,
  RefreshSchema,
  RegisterSchema,
  toUserDto,
} from '../application/auth.schemas.js';

export function sessionMeta(req: Request): SessionMeta {
  return {
    installationId: req.installationId,
    userAgent: req.get('user-agent'),
    ip: req.ip,
  };
}

const sessionBody = (session: Session) => ({
  data: { user: toUserDto(session.user), tokens: session.tokens },
});

/** /api/v1/auth */
export function authRoutes(deps: { auth: AuthService; limiter: RequestHandler }): Router {
  const { auth, limiter } = deps;
  const router = Router();

  router.post('/register', limiter, async (req, res) => {
    const input = parseBody(RegisterSchema, req);
    res.status(201).json(sessionBody(await auth.register(input, sessionMeta(req))));
  });

  router.post('/login', limiter, async (req, res) => {
    const input = parseBody(LoginSchema, req);
    res.json(sessionBody(await auth.login(input, sessionMeta(req))));
  });

  router.post('/refresh', limiter, async (req, res) => {
    const { refreshToken } = parseBody(RefreshSchema, req);
    res.json(sessionBody(await auth.refresh(refreshToken, sessionMeta(req))));
  });

  router.post('/logout', async (req, res) => {
    const { refreshToken } = parseBody(RefreshSchema, req);
    await auth.logout(refreshToken);
    res.status(204).end();
  });

  return router;
}
