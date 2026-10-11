/**
 * Expected, client-facing errors. The error middleware turns them into
 * RFC 9457 "problem details" responses. Anything that is not an AppError is
 * treated as a bug: logged with its stack and answered with a generic 500.
 *
 * Mirrors `Failure` in the Flutter app (core/error/failures.dart).
 */
export interface FieldError {
  path: string;
  message: string;
}

export class AppError extends Error {
  constructor(
    readonly status: number,
    readonly code: string,
    message: string,
    readonly details?: { errors?: FieldError[]; [key: string]: unknown },
  ) {
    super(message);
    this.name = new.target.name;
  }
}

export class ValidationError extends AppError {
  constructor(message = 'The request is invalid.', errors: FieldError[] = []) {
    super(422, 'validation_failed', message, { errors });
  }
}

export class BadRequestError extends AppError {
  constructor(message = 'Bad request.', code = 'bad_request') {
    super(400, code, message);
  }
}

export class UnauthorizedError extends AppError {
  constructor(message = 'Authentication required.', code = 'unauthorized') {
    super(401, code, message);
  }
}

export class ForbiddenError extends AppError {
  constructor(message = 'You do not have access to this resource.', code = 'forbidden') {
    super(403, code, message);
  }
}

export class NotFoundError extends AppError {
  constructor(resource = 'Resource', code = 'not_found') {
    super(404, code, `${resource} not found.`);
  }
}

export class ConflictError extends AppError {
  constructor(message: string, code = 'conflict') {
    super(409, code, message);
  }
}

export class TooManyRequestsError extends AppError {
  constructor(message = 'Too many requests. Please slow down.') {
    super(429, 'rate_limited', message);
  }
}
