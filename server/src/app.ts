import compression from 'compression';
import cors from 'cors';
import express, { Router, type Request } from 'express';
import helmet from 'helmet';
import { pinoHttp } from 'pino-http';
import swaggerUi from 'swagger-ui-express';

import type { Container } from './container.js';
import { authenticate } from './core/http/middleware/authenticate.js';
import { errorHandler, notFoundHandler } from './core/http/middleware/error-handler.js';
import { limiter } from './core/http/middleware/rate-limit.js';
import { requestContext } from './core/http/middleware/request-context.js';
import { buildOpenApiDocument, createRegistry } from './core/http/openapi.js';
import './core/http/request-context.js';
import { registerAuthDocs } from './modules/auth/presentation/auth.openapi.js';
import { authRoutes } from './modules/auth/presentation/auth.routes.js';
import { deviceRoutes, registerDeviceDocs } from './modules/devices/presentation/device.routes.js';
import { healthRoutes, registerHealthDocs } from './modules/health/presentation/health.routes.js';
import {
  notificationRoutes,
  registerNotificationDocs,
} from './modules/notifications/presentation/notification.routes.js';
import {
  registerSettingsDocs,
  settingsRoutes,
} from './modules/settings/presentation/settings.routes.js';
import { registerStatsDocs, statsRoutes } from './modules/stats/presentation/stats.routes.js';
import { registerSyncDocs, syncRoutes } from './modules/sync/presentation/sync.routes.js';
import { registerTaskDocs } from './modules/tasks/presentation/task.openapi.js';
import { taskRoutes } from './modules/tasks/presentation/task.routes.js';
import { accountRoutes, registerAccountDocs } from './modules/users/presentation/account.routes.js';
import { APP_VERSION } from './version.js';

export interface AppOptions {
  /** Requests per minute. Tests raise these. */
  rateLimits?: { globalPerMinute: number; authPerMinute: number; syncPerMinute: number };
}

const MINUTE = 60_000;

export function buildApiDocument(serverUrl = '/') {
  const registry = createRegistry();
  registerHealthDocs(registry);
  registerAuthDocs(registry);
  registerAccountDocs(registry);
  registerTaskDocs(registry);
  registerSyncDocs(registry);
  registerSettingsDocs(registry);
  registerDeviceDocs(registry);
  registerNotificationDocs(registry);
  registerStatsDocs(registry);
  return buildOpenApiDocument(registry, serverUrl);
}

/**
 * Builds the Express application. Presentation layer only: every route hands
 * off to a service from the container.
 */
export function createApp(container: Container, options: AppOptions = {}) {
  const { config, logger, services, tokenService, clock, database } = container;
  const limits = options.rateLimits ?? {
    globalPerMinute: 600,
    authPerMinute: 20,
    syncPerMinute: 120,
  };

  const app = express();
  app.disable('x-powered-by');
  app.set('trust proxy', config.http.trustProxy);

  app.use(requestContext());
  app.use(
    pinoHttp({
      logger,
      genReqId: (req) => (req as Request).requestId ?? 'unknown',
      autoLogging: { ignore: (req) => req.url?.startsWith('/health') ?? false },
      customLogLevel: (_req, res, error) =>
        error || res.statusCode >= 500 ? 'error' : res.statusCode >= 400 ? 'warn' : 'info',
      customSuccessMessage: (req, res, time) =>
        `${req.method} ${(req as Request).originalUrl ?? req.url} ${res.statusCode} ${Math.round(time)}ms`,
      serializers: {
        req: (req: { method: string; url: string }) => ({ method: req.method, url: req.url }),
        res: (res: { statusCode: number }) => ({ statusCode: res.statusCode }),
      },
    }),
  );

  // API docs: Swagger UI needs its own inline assets, so it gets a relaxed CSP.
  const apiDocument = buildApiDocument();
  if (config.http.docsEnabled) {
    app.get('/openapi.json', (_req, res) => {
      res.json(apiDocument);
    });
    app.use(
      '/docs',
      helmet({ contentSecurityPolicy: false }),
      swaggerUi.serve,
      swaggerUi.setup(apiDocument, {
        customSiteTitle: 'TaskFlow API',
        swaggerOptions: { persistAuthorization: true },
      }),
    );
  }

  app.use(helmet());
  app.use(
    cors({
      origin: config.http.corsOrigins,
      allowedHeaders: ['Authorization', 'Content-Type', 'X-Device-Id', 'X-Request-Id'],
      exposedHeaders: ['X-Request-Id', 'Location', 'RateLimit', 'RateLimit-Policy', 'Retry-After'],
      maxAge: 600,
    }),
  );
  app.use(compression());
  app.use(express.json({ limit: '1mb' }));

  app.use('/health', healthRoutes({ ping: database.ping, version: APP_VERSION }));

  const requireUser = authenticate(tokenService, clock);
  const api = Router();
  api.use(limiter({ windowMs: MINUTE, limit: limits.globalPerMinute }));
  api.use(
    '/auth',
    authRoutes({
      auth: services.auth,
      limiter: limiter({ windowMs: MINUTE, limit: limits.authPerMinute }),
    }),
  );
  api.use('/users', requireUser, accountRoutes({ account: services.account }));
  api.use('/tasks', requireUser, taskRoutes({ tasks: services.tasks }));
  api.use(
    '/sync',
    requireUser,
    syncRoutes({
      sync: services.sync,
      limiter: limiter({ windowMs: MINUTE, limit: limits.syncPerMinute, perUser: true }),
    }),
  );
  api.use('/settings', requireUser, settingsRoutes({ settings: services.settings }));
  api.use('/devices', requireUser, deviceRoutes({ devices: services.devices }));
  api.use(
    '/notifications',
    requireUser,
    notificationRoutes({
      notifications: services.notifications,
      testLimiter: limiter({ windowMs: MINUTE, limit: 5, perUser: true }),
    }),
  );
  api.use('/stats', requireUser, statsRoutes({ stats: services.stats }));
  app.use('/api/v1', api);

  app.get('/', (_req, res) => {
    res.json({
      name: 'TaskFlow API',
      version: APP_VERSION,
      docs: config.http.docsEnabled ? '/docs' : undefined,
    });
  });

  app.use(notFoundHandler());
  app.use(errorHandler(logger));
  return app;
}
