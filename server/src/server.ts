import { createApp } from './app.js';
import { loadConfig } from './config/env.js';
import { createContainer } from './container.js';
import { createDatabase } from './core/db/client.js';
import { createLogger } from './core/logger.js';
import { APP_VERSION } from './version.js';

/**
 * HTTP entry point. Also runs the notification jobs unless JOBS_ENABLED=false
 * (then run `npm run start:worker` separately).
 */
async function main(): Promise<void> {
  const config = loadConfig();
  const logger = createLogger({
    level: config.logLevel,
    pretty: !config.isProduction && process.stdout.isTTY,
  });
  const database = createDatabase(config.database);
  const container = createContainer({ config, database, logger });
  const app = createApp(container);

  try {
    await database.ping();
  } catch (error) {
    logger.error({ err: error }, 'Database is not reachable. Check DATABASE_URL.');
  }

  const server = app.listen(config.port, config.host, () => {
    logger.info(
      { port: config.port, driver: database.driver, env: config.env, version: APP_VERSION },
      `TaskFlow API listening on http://${config.host}:${config.port}`,
    );
  });
  // Longer than typical load balancer idle timeouts (60 s), so they close first.
  server.keepAliveTimeout = 65_000;
  server.headersTimeout = 66_000;

  if (config.jobs.enabled) container.jobs.scheduler.start();

  let stopping = false;
  const shutdown = async (signal: string, code = 0) => {
    if (stopping) return;
    stopping = true;
    logger.info({ signal }, 'Shutting down');
    const force = setTimeout(() => {
      logger.error('Forced exit after 10 s');
      process.exit(1);
    }, 10_000);
    force.unref();

    await new Promise<void>((resolve) => server.close(() => resolve()));
    await container.shutdown();
    logger.info('Bye');
    process.exit(code);
  };

  process.on('SIGTERM', () => void shutdown('SIGTERM'));
  process.on('SIGINT', () => void shutdown('SIGINT'));
  process.on('unhandledRejection', (reason) => {
    logger.fatal({ err: reason }, 'Unhandled promise rejection');
    void shutdown('unhandledRejection', 1);
  });
}

main().catch((error: unknown) => {
  // eslint-disable-next-line no-console
  console.error(error instanceof Error ? error.message : error);
  process.exit(1);
});
