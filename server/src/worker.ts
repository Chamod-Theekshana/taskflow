import { loadConfig } from './config/env.js';
import { createContainer } from './container.js';
import { createDatabase } from './core/db/client.js';
import { createLogger } from './core/logger.js';

/**
 * Background worker: reminders, daily digest and cleanup, without HTTP.
 * Use it when the API runs with JOBS_ENABLED=false (e.g. several API
 * replicas, or a serverless API). Several workers can run side by side.
 */
async function main(): Promise<void> {
  const config = loadConfig();
  const logger = createLogger({
    level: config.logLevel,
    pretty: !config.isProduction && process.stdout.isTTY,
  });
  const database = createDatabase(config.database);
  const container = createContainer({ config, database, logger });

  container.jobs.scheduler.start();
  logger.info('TaskFlow worker started');

  const stop = async (signal: string) => {
    logger.info({ signal }, 'Stopping worker');
    await container.shutdown();
    process.exit(0);
  };
  process.on('SIGTERM', () => void stop('SIGTERM'));
  process.on('SIGINT', () => void stop('SIGINT'));
}

main().catch((error: unknown) => {
  // eslint-disable-next-line no-console
  console.error(error instanceof Error ? error.message : error);
  process.exit(1);
});
