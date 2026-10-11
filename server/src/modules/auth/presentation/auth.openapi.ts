import {
  envelope,
  errorResponses,
  jsonContent,
  type OpenAPIRegistry,
} from '../../../core/http/openapi.js';
import {
  LoginSchema,
  RefreshSchema,
  RegisterSchema,
  SessionSchema,
} from '../application/auth.schemas.js';

export function registerAuthDocs(registry: OpenAPIRegistry): void {
  const session = envelope(SessionSchema);

  registry.registerPath({
    method: 'post',
    path: '/api/v1/auth/register',
    tags: ['Auth'],
    summary: 'Create an account',
    description: 'Creates the user with default settings and signs them in.',
    request: { body: { content: { 'application/json': { schema: RegisterSchema } } } },
    responses: {
      201: jsonContent(session, 'Signed up and signed in.'),
      409: errorResponses[409],
      422: errorResponses[422],
      429: errorResponses[429],
    },
  });

  registry.registerPath({
    method: 'post',
    path: '/api/v1/auth/login',
    tags: ['Auth'],
    summary: 'Sign in with email and password',
    request: { body: { content: { 'application/json': { schema: LoginSchema } } } },
    responses: {
      200: jsonContent(session, 'Signed in.'),
      401: errorResponses[401],
      422: errorResponses[422],
      429: errorResponses[429],
    },
  });

  registry.registerPath({
    method: 'post',
    path: '/api/v1/auth/refresh',
    tags: ['Auth'],
    summary: 'Rotate the refresh token',
    description:
      'Returns a new access token and a new refresh token. Each refresh token works once; ' +
      'reusing an old one ends the session.',
    request: { body: { content: { 'application/json': { schema: RefreshSchema } } } },
    responses: {
      200: jsonContent(session, 'New token pair.'),
      401: errorResponses[401],
      422: errorResponses[422],
    },
  });

  registry.registerPath({
    method: 'post',
    path: '/api/v1/auth/logout',
    tags: ['Auth'],
    summary: 'End the session',
    request: { body: { content: { 'application/json': { schema: RefreshSchema } } } },
    responses: { 204: { description: 'Signed out.' }, 422: errorResponses[422] },
  });
}
