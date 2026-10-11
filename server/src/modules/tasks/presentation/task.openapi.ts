import {
  bearerAuth,
  envelope,
  errorResponses,
  jsonContent,
  type OpenAPIRegistry,
} from '../../../core/http/openapi.js';
import { idParams } from '../../../core/http/params.js';
import { z } from '../../../core/http/zod.js';
import {
  AddSubtaskSchema,
  CreateTaskSchema,
  ListTasksQuerySchema,
  TaskSchema,
  UpdateSubtaskSchema,
  UpdateTaskSchema,
} from '../application/task.schemas.js';

export function registerTaskDocs(registry: OpenAPIRegistry): void {
  const task = envelope(TaskSchema);
  const tags = ['Tasks'];
  const idOnly = idParams('id');
  const withSubtask = idParams('id', 'subtaskId');
  const body = <T extends z.ZodType>(schema: T) => ({
    body: { content: { 'application/json': { schema } } },
  });

  registry.registerPath({
    method: 'get',
    path: '/api/v1/tasks',
    tags,
    summary: 'List tasks',
    description: 'Ordered by due time. Keyset pagination: pass `meta.nextCursor` as `cursor`.',
    security: bearerAuth,
    request: { query: ListTasksQuerySchema },
    responses: {
      200: jsonContent(
        z.object({
          data: z.array(TaskSchema),
          meta: z.object({ nextCursor: z.string().nullable() }),
        }),
        'A page of tasks.',
      ),
      401: errorResponses[401],
      422: errorResponses[422],
    },
  });

  registry.registerPath({
    method: 'post',
    path: '/api/v1/tasks',
    tags,
    summary: 'Create a task',
    security: bearerAuth,
    request: body(CreateTaskSchema),
    responses: {
      201: jsonContent(task, 'Created.'),
      401: errorResponses[401],
      409: errorResponses[409],
      422: errorResponses[422],
    },
  });

  registry.registerPath({
    method: 'get',
    path: '/api/v1/tasks/{id}',
    tags,
    summary: 'Get a task',
    security: bearerAuth,
    request: { params: idOnly },
    responses: {
      200: jsonContent(task, 'The task.'),
      401: errorResponses[401],
      404: errorResponses[404],
    },
  });

  registry.registerPath({
    method: 'patch',
    path: '/api/v1/tasks/{id}',
    tags,
    summary: 'Update a task',
    description: 'Only the fields sent change. Sending `subtasks` replaces the whole list.',
    security: bearerAuth,
    request: { params: idOnly, ...body(UpdateTaskSchema) },
    responses: {
      200: jsonContent(task, 'Updated.'),
      401: errorResponses[401],
      404: errorResponses[404],
      422: errorResponses[422],
    },
  });

  registry.registerPath({
    method: 'delete',
    path: '/api/v1/tasks/{id}',
    tags,
    summary: 'Delete a task',
    security: bearerAuth,
    request: { params: idOnly },
    responses: {
      204: { description: 'Deleted.' },
      401: errorResponses[401],
      404: errorResponses[404],
    },
  });

  registry.registerPath({
    method: 'post',
    path: '/api/v1/tasks/{id}/complete',
    tags,
    summary: 'Complete a task',
    description:
      'Ticks off its subtasks too. A repeating task returns its next occurrence in `next`.',
    security: bearerAuth,
    request: { params: idOnly },
    responses: {
      200: jsonContent(
        envelope(z.object({ task: TaskSchema, next: TaskSchema.nullable() })),
        'Completed.',
      ),
      401: errorResponses[401],
      404: errorResponses[404],
    },
  });

  registry.registerPath({
    method: 'post',
    path: '/api/v1/tasks/{id}/reopen',
    tags,
    summary: 'Reopen a completed task',
    security: bearerAuth,
    request: { params: idOnly },
    responses: {
      200: jsonContent(task, 'Reopened.'),
      401: errorResponses[401],
      404: errorResponses[404],
    },
  });

  registry.registerPath({
    method: 'post',
    path: '/api/v1/tasks/{id}/subtasks',
    tags,
    summary: 'Add a subtask',
    security: bearerAuth,
    request: { params: idOnly, ...body(AddSubtaskSchema) },
    responses: {
      201: jsonContent(task, 'The task with the new subtask.'),
      401: errorResponses[401],
      404: errorResponses[404],
      422: errorResponses[422],
    },
  });

  registry.registerPath({
    method: 'patch',
    path: '/api/v1/tasks/{id}/subtasks/{subtaskId}',
    tags,
    summary: 'Rename or tick a subtask',
    security: bearerAuth,
    request: { params: withSubtask, ...body(UpdateSubtaskSchema) },
    responses: {
      200: jsonContent(task, 'The updated task.'),
      401: errorResponses[401],
      404: errorResponses[404],
      422: errorResponses[422],
    },
  });

  registry.registerPath({
    method: 'delete',
    path: '/api/v1/tasks/{id}/subtasks/{subtaskId}',
    tags,
    summary: 'Remove a subtask',
    security: bearerAuth,
    request: { params: withSubtask },
    responses: {
      200: jsonContent(task, 'The updated task.'),
      401: errorResponses[401],
      404: errorResponses[404],
    },
  });
}
