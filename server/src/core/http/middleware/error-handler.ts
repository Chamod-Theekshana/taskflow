import type { ErrorRequestHandler, RequestHandler } from 'express';
import { ZodError } from 'zod';

import { AppError, NotFoundError, ValidationError } from '../../errors/app-error.js';
import type { Logger } from '../../logger.js';
import { zodIssues } from '../validation.js';

/** RFC 9457 problem details, the body of every error response. */
export interface Problem {
  type: string;
  title: string;
  status: number;
  detail: string;
  code: string;
  requestId?: string;
  errors?: { path: string; message: string }[];
}

const titles: Record<number, string> = {
  400: 'Bad Request',
  401: 'Unauthorized',
  403: 'Forbidden',
  404: 'Not Found',
  409: 'Conflict',
  413: 'Payload Too Large',
  415: 'Unsupported Media Type',
  422: 'Unprocessable Content',
  429: 'Too Many Requests',
  500: 'Internal Server Error',
  503: 'Service Unavailable',
};

function toAppError(error: unknown): AppError | null {
  if (error instanceof AppError) return error;
  if (error instanceof ZodError) return new ValidationError(undefined, zodIssues(error));

  // Errors raised by express.json() carry a `type` and a `status`.
  const bodyError = error as { type?: string; status?: number };
  if (bodyError?.type === 'entity.parse.failed') {
    return new AppError(400, 'invalid_json', 'The request body is not valid JSON.');
  }
  if (bodyError?.type === 'entity.too.large') {
    return new AppError(413, 'payload_too_large', 'The request body is too large.');
  }
  if (bodyError?.type === 'encoding.unsupported' || bodyError?.type === 'charset.unsupported') {
    return new AppError(415, 'unsupported_encoding', 'Unsupported request encoding.');
  }
  return null;
}

export function notFoundHandler(): RequestHandler {
  return (req) => {
    throw new NotFoundError(`Route ${req.method} ${req.path}`, 'route_not_found');
  };
}

export function errorHandler(logger: Logger): ErrorRequestHandler {
  return (error: unknown, req, res, _next) => {
    const known = toAppError(error);
    const status = known?.status ?? 500;
    const log = req.log ?? logger;

    if (status >= 500) {
      log.error({ err: error, requestId: req.requestId }, 'Unhandled error');
    } else {
      log.debug({ code: known?.code, status }, known?.message);
    }

    const problem: Problem = {
      type: `https://taskflow.app/problems/${known?.code ?? 'internal_error'}`,
      title: titles[status] ?? 'Error',
      status,
      detail: known?.message ?? 'Something went wrong on our side. Please try again.',
      code: known?.code ?? 'internal_error',
      requestId: req.requestId,
    };
    const fieldErrors = known?.details?.errors;
    if (fieldErrors && fieldErrors.length > 0) problem.errors = fieldErrors;

    if (res.headersSent) return;
    res.status(status).type('application/problem+json').json(problem);
  };
}
