import { OpenApiGeneratorV31, OpenAPIRegistry } from '@asteasolutions/zod-to-openapi';

import { z } from './zod.js';

export { OpenAPIRegistry };

export const ProblemSchema = z
  .object({
    type: z.string().openapi({ example: 'https://taskflow.app/problems/validation_failed' }),
    title: z.string().openapi({ example: 'Unprocessable Content' }),
    status: z.number().int().openapi({ example: 422 }),
    detail: z.string().openapi({ example: 'The request body is invalid.' }),
    code: z.string().openapi({ example: 'validation_failed' }),
    requestId: z.string().optional(),
    errors: z
      .array(z.object({ path: z.string(), message: z.string() }))
      .optional()
      .openapi({ description: 'Present for validation errors.' }),
  })
  .openapi('Problem');

/** `{ data: T }`, the shape of every successful JSON response. */
export const envelope = <T extends z.ZodType>(schema: T) => z.object({ data: schema });

const problemResponse = (description: string) => ({
  description,
  content: { 'application/problem+json': { schema: ProblemSchema } },
});

/** The error responses most routes can return. */
export const commonErrors = {
  401: problemResponse('Missing, invalid or expired access token.'),
  422: problemResponse('Validation failed.'),
  429: problemResponse('Rate limit exceeded.'),
};

export const errorResponses = {
  400: problemResponse('Bad request.'),
  401: commonErrors[401],
  403: problemResponse('Forbidden.'),
  404: problemResponse('Not found.'),
  409: problemResponse('Conflict.'),
  422: commonErrors[422],
  429: commonErrors[429],
};

export const jsonContent = <T extends z.ZodType>(schema: T, description: string) => ({
  description,
  content: { 'application/json': { schema } },
});

export const bearerAuth = [{ bearerAuth: [] }];

export function createRegistry(): OpenAPIRegistry {
  const registry = new OpenAPIRegistry();
  registry.registerComponent('securitySchemes', 'bearerAuth', {
    type: 'http',
    scheme: 'bearer',
    bearerFormat: 'JWT',
    description: 'Access token from /auth/login, /auth/register or /auth/refresh.',
  });
  registry.register('Problem', ProblemSchema);
  return registry;
}

export function buildOpenApiDocument(registry: OpenAPIRegistry, serverUrl: string) {
  return new OpenApiGeneratorV31(registry.definitions).generateDocument({
    openapi: '3.1.0',
    info: {
      title: 'TaskFlow API',
      version: '1.0.0',
      description:
        'Backend for the TaskFlow app: accounts, tasks, offline-first sync, settings, devices and push notifications.\n\n' +
        'Errors use RFC 9457 problem details (`application/problem+json`). Successful JSON responses are wrapped in `{ "data": ... }`.\n\n' +
        'Send `X-Device-Id: <installation id>` from the app so sync and push can tell your devices apart.',
    },
    servers: [{ url: serverUrl }],
    tags: [
      { name: 'Auth', description: 'Sign up, sign in and sessions' },
      { name: 'Account', description: 'The signed-in user' },
      { name: 'Tasks', description: 'Task and subtask CRUD' },
      { name: 'Sync', description: 'Offline-first replication for the app' },
      { name: 'Settings', description: 'User preferences' },
      { name: 'Devices', description: 'Installations and push tokens' },
      { name: 'Notifications', description: 'Inbox and test pushes' },
      { name: 'Stats', description: 'Productivity numbers' },
      { name: 'Health', description: 'Liveness and readiness probes' },
    ],
  });
}
