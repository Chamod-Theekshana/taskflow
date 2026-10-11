import type { Request } from 'express';
import type { z, ZodError, ZodType } from 'zod';

import { UnauthorizedError, ValidationError, type FieldError } from '../errors/app-error.js';
import type { AuthContext } from './request-context.js';

export function zodIssues(error: ZodError): FieldError[] {
  return error.issues.map((issue) => ({
    path: issue.path.map(String).join('.') || '(root)',
    message: issue.message,
  }));
}

function parse<S extends ZodType>(schema: S, value: unknown, where: string): z.output<S> {
  const result = schema.safeParse(value);
  if (!result.success) {
    throw new ValidationError(`The request ${where} is invalid.`, zodIssues(result.error));
  }
  return result.data;
}

/** Validates and types the JSON body. Throws a 422 with field errors. */
export const parseBody = <S extends ZodType>(schema: S, req: Request): z.output<S> =>
  parse(schema, req.body ?? {}, 'body');

/** Validates and types the query string. */
export const parseQuery = <S extends ZodType>(schema: S, req: Request): z.output<S> =>
  parse(schema, req.query, 'query');

/** Validates and types the path parameters. */
export const parseParams = <S extends ZodType>(schema: S, req: Request): z.output<S> =>
  parse(schema, req.params, 'path');

/** The signed-in user. Only valid on routes behind `authenticate`. */
export function requireAuth(req: Request): AuthContext {
  if (!req.auth) throw new UnauthorizedError();
  return req.auth;
}
