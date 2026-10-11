import { Router } from 'express';

import { uuidParam } from '../../../core/http/params.js';
import { parseBody, parseQuery, requireAuth } from '../../../core/http/validation.js';
import type { TaskService } from '../application/task.service.js';
import {
  AddSubtaskSchema,
  CreateTaskSchema,
  ListTasksQuerySchema,
  toTaskDto,
  UpdateSubtaskSchema,
  UpdateTaskSchema,
} from '../application/task.schemas.js';

/** /api/v1/tasks (behind `authenticate`) */
export function taskRoutes(deps: { tasks: TaskService }): Router {
  const { tasks } = deps;
  const router = Router();
  const taskId = (req: Parameters<typeof uuidParam>[0]) => uuidParam(req, 'id', 'Task');

  router.get('/', async (req, res) => {
    const { userId } = requireAuth(req);
    const q = parseQuery(ListTasksQuerySchema, req);
    const page = await tasks.list(userId, {
      status: q.status,
      from: q.from,
      to: q.to,
      query: q.q,
      priority: q.priority,
      category: q.category,
      limit: q.limit,
      cursor: q.cursor,
    });
    res.json({ data: page.items.map(toTaskDto), meta: { nextCursor: page.nextCursor } });
  });

  router.post('/', async (req, res) => {
    const { userId } = requireAuth(req);
    const input = parseBody(CreateTaskSchema, req);
    const task = await tasks.create(userId, input, req.installationId);
    res
      .status(201)
      .location(`${req.baseUrl}/${task.id}`)
      .json({ data: toTaskDto(task) });
  });

  router.get('/:id', async (req, res) => {
    const { userId } = requireAuth(req);
    res.json({ data: toTaskDto(await tasks.get(userId, taskId(req))) });
  });

  router.patch('/:id', async (req, res) => {
    const { userId } = requireAuth(req);
    const id = taskId(req);
    const patch = parseBody(UpdateTaskSchema, req);
    res.json({ data: toTaskDto(await tasks.update(userId, id, patch, req.installationId)) });
  });

  router.delete('/:id', async (req, res) => {
    const { userId } = requireAuth(req);
    await tasks.remove(userId, taskId(req), req.installationId);
    res.status(204).end();
  });

  router.post('/:id/complete', async (req, res) => {
    const { userId } = requireAuth(req);
    const result = await tasks.complete(userId, taskId(req), req.installationId);
    res.json({
      data: { task: toTaskDto(result.task), next: result.next ? toTaskDto(result.next) : null },
    });
  });

  router.post('/:id/reopen', async (req, res) => {
    const { userId } = requireAuth(req);
    res.json({ data: toTaskDto(await tasks.reopen(userId, taskId(req), req.installationId)) });
  });

  router.post('/:id/subtasks', async (req, res) => {
    const { userId } = requireAuth(req);
    const id = taskId(req);
    const { title } = parseBody(AddSubtaskSchema, req);
    res
      .status(201)
      .json({ data: toTaskDto(await tasks.addSubtask(userId, id, title, req.installationId)) });
  });

  router.patch('/:id/subtasks/:subtaskId', async (req, res) => {
    const { userId } = requireAuth(req);
    const id = taskId(req);
    const subtaskId = uuidParam(req, 'subtaskId', 'Subtask');
    const patch = parseBody(UpdateSubtaskSchema, req);
    res.json({
      data: toTaskDto(await tasks.updateSubtask(userId, id, subtaskId, patch, req.installationId)),
    });
  });

  router.delete('/:id/subtasks/:subtaskId', async (req, res) => {
    const { userId } = requireAuth(req);
    const id = taskId(req);
    const subtaskId = uuidParam(req, 'subtaskId', 'Subtask');
    res.json({
      data: toTaskDto(await tasks.deleteSubtask(userId, id, subtaskId, req.installationId)),
    });
  });

  return router;
}
