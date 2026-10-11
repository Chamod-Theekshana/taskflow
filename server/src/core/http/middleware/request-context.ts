import { randomUUID } from 'node:crypto';

import type { RequestHandler } from 'express';

const safeId = /^[A-Za-z0-9._-]{1,64}$/;

/**
 * Gives every request an id (reusing a sane incoming `X-Request-Id`) and
 * reads the optional `X-Device-Id` header the mobile app sends.
 */
export function requestContext(): RequestHandler {
  return (req, res, next) => {
    const incoming = req.header('x-request-id');
    req.requestId = incoming && safeId.test(incoming) ? incoming : randomUUID();
    res.setHeader('X-Request-Id', req.requestId);

    const device = req.header('x-device-id');
    if (device && safeId.test(device)) req.installationId = device;
    next();
  };
}
