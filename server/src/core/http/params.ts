import type { Request } from 'express';

import { NotFoundError } from '../errors/app-error.js';
import { z } from './zod.js';

const uuid = z.uuid();

/** A UUID path parameter. Anything malformed is simply "not found". */
export function uuidParam(req: Request, name: string, resource: string): string {
  const parsed = uuid.safeParse(req.params[name]);
  if (!parsed.success) throw new NotFoundError(resource);
  return parsed.data;
}

export const idParams = (...names: string[]) =>
  z.object(Object.fromEntries(names.map((n) => [n, z.uuid()])) as Record<string, z.ZodUUID>);
