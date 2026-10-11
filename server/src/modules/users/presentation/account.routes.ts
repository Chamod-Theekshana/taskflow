import { Router } from 'express';

import {
  bearerAuth,
  envelope,
  errorResponses,
  jsonContent,
  type OpenAPIRegistry,
} from '../../../core/http/openapi.js';
import { parseBody, requireAuth } from '../../../core/http/validation.js';
import { z } from '../../../core/http/zod.js';
import {
  newPasswordSchema,
  SessionSchema,
  toUserDto,
  UserSchema,
} from '../../auth/application/auth.schemas.js';
import { sessionMeta } from '../../auth/presentation/auth.routes.js';
import type { AccountService } from '../application/account.service.js';

const UpdateProfileSchema = z
  .object({ fullName: z.string().trim().min(1, 'Name cannot be empty.').max(120) })
  .openapi('UpdateProfileRequest');

const ChangePasswordSchema = z
  .object({
    currentPassword: z.string().min(1).max(128),
    newPassword: newPasswordSchema,
  })
  .openapi('ChangePasswordRequest');

const DeleteAccountSchema = z
  .object({ password: z.string().min(1).max(128) })
  .openapi('DeleteAccountRequest');

/** /api/v1/users (behind `authenticate`) */
export function accountRoutes(deps: { account: AccountService }): Router {
  const { account } = deps;
  const router = Router();

  router.get('/me', async (req, res) => {
    const { userId } = requireAuth(req);
    res.json({ data: toUserDto(await account.me(userId)) });
  });

  router.patch('/me', async (req, res) => {
    const { userId } = requireAuth(req);
    const input = parseBody(UpdateProfileSchema, req);
    res.json({ data: toUserDto(await account.updateProfile(userId, input)) });
  });

  router.post('/me/password', async (req, res) => {
    const { userId } = requireAuth(req);
    const input = parseBody(ChangePasswordSchema, req);
    const session = await account.changePassword(userId, input, sessionMeta(req));
    res.json({ data: { user: toUserDto(session.user), tokens: session.tokens } });
  });

  router.delete('/me', async (req, res) => {
    const { userId } = requireAuth(req);
    const { password } = parseBody(DeleteAccountSchema, req);
    await account.deleteAccount(userId, password);
    res.status(204).end();
  });

  return router;
}

export function registerAccountDocs(registry: OpenAPIRegistry): void {
  const user = envelope(UserSchema);

  registry.registerPath({
    method: 'get',
    path: '/api/v1/users/me',
    tags: ['Account'],
    summary: 'The signed-in user',
    security: bearerAuth,
    responses: { 200: jsonContent(user, 'The user.'), 401: errorResponses[401] },
  });

  registry.registerPath({
    method: 'patch',
    path: '/api/v1/users/me',
    tags: ['Account'],
    summary: 'Update the name',
    security: bearerAuth,
    request: { body: { content: { 'application/json': { schema: UpdateProfileSchema } } } },
    responses: {
      200: jsonContent(user, 'Updated user.'),
      401: errorResponses[401],
      422: errorResponses[422],
    },
  });

  registry.registerPath({
    method: 'post',
    path: '/api/v1/users/me/password',
    tags: ['Account'],
    summary: 'Change the password',
    description: 'Signs out every other session and returns a new token pair for this one.',
    security: bearerAuth,
    request: { body: { content: { 'application/json': { schema: ChangePasswordSchema } } } },
    responses: {
      200: jsonContent(envelope(SessionSchema), 'Password changed.'),
      401: errorResponses[401],
      422: errorResponses[422],
    },
  });

  registry.registerPath({
    method: 'delete',
    path: '/api/v1/users/me',
    tags: ['Account'],
    summary: 'Delete the account and all its data',
    security: bearerAuth,
    request: { body: { content: { 'application/json': { schema: DeleteAccountSchema } } } },
    responses: { 204: { description: 'Deleted.' }, 401: errorResponses[401] },
  });
}
