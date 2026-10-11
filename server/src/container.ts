import type { AppConfig } from './config/env.js';
import type { DatabaseHandle } from './core/db/client.js';
import { DrizzleUnitOfWork } from './core/db/unit-of-work.js';
import { JobScheduler } from './core/jobs/scheduler.js';
import type { Logger } from './core/logger.js';
import { Argon2PasswordHasher, type PasswordHasher } from './core/security/password-hasher.js';
import { TokenService } from './core/security/token-service.js';
import { systemClock, type Clock } from './core/utils/clock.js';
import { CleanupJob } from './jobs/cleanup.job.js';
import { AuthService } from './modules/auth/application/auth.service.js';
import { DrizzleRefreshTokenRepository } from './modules/auth/infrastructure/drizzle-refresh-token.repository.js';
import { DrizzleUserRepository } from './modules/auth/infrastructure/drizzle-user.repository.js';
import { DeviceService } from './modules/devices/application/device.service.js';
import { DrizzleDeviceRepository } from './modules/devices/infrastructure/drizzle-device.repository.js';
import { DigestDispatcher } from './modules/notifications/application/digest-dispatcher.js';
import { NotificationService } from './modules/notifications/application/notification.service.js';
import { PushDispatcher } from './modules/notifications/application/push-dispatcher.js';
import { ReminderDispatcher } from './modules/notifications/application/reminder-dispatcher.js';
import { SyncPushNotifier } from './modules/notifications/application/sync-push.notifier.js';
import type { PushGateway } from './modules/notifications/domain/push-gateway.js';
import { DrizzleDigestQueries } from './modules/notifications/infrastructure/drizzle-digest.queries.js';
import { DrizzleNotificationRepository } from './modules/notifications/infrastructure/drizzle-notification.repository.js';
import { FcmPushGateway } from './modules/notifications/infrastructure/fcm-push.gateway.js';
import { LogPushGateway } from './modules/notifications/infrastructure/log-push.gateway.js';
import { SettingsService } from './modules/settings/application/settings.service.js';
import { DrizzleSettingsRepository } from './modules/settings/infrastructure/drizzle-settings.repository.js';
import { StatsService } from './modules/stats/application/stats.service.js';
import { SyncService } from './modules/sync/application/sync.service.js';
import { TaskService } from './modules/tasks/application/task.service.js';
import { DrizzleTaskRepository } from './modules/tasks/infrastructure/drizzle-task.repository.js';
import { AccountService } from './modules/users/application/account.service.js';

export interface ContainerOptions {
  config: AppConfig;
  database: DatabaseHandle;
  logger: Logger;
  /** Overrides for tests. */
  clock?: Clock;
  pushGateway?: PushGateway;
  passwordHasher?: PasswordHasher;
  syncPushDelayMs?: number;
}

/**
 * Composition root: the one place that knows which implementation backs each
 * port. The counterpart of `core/di/providers.dart` in the app. Everything
 * else receives its collaborators through constructors, which is what makes
 * each layer testable on its own.
 */
export function createContainer(options: ContainerOptions) {
  const { config, database, logger } = options;
  const { db } = database;
  const clock = options.clock ?? systemClock;
  const uow = new DrizzleUnitOfWork(db);

  // Infrastructure (adapters)
  const repositories = {
    users: new DrizzleUserRepository(db),
    refreshTokens: new DrizzleRefreshTokenRepository(db),
    settings: new DrizzleSettingsRepository(db),
    tasks: new DrizzleTaskRepository(db),
    devices: new DrizzleDeviceRepository(db),
    notifications: new DrizzleNotificationRepository(db),
    digest: new DrizzleDigestQueries(db),
  };

  const pushGateway =
    options.pushGateway ??
    (config.firebase.serviceAccount
      ? new FcmPushGateway(config.firebase.serviceAccount, logger)
      : new LogPushGateway(logger));
  if (!pushGateway.enabled) {
    logger.warn('FIREBASE_SERVICE_ACCOUNT is not set: push notifications are logged, not sent.');
  }

  const push = new PushDispatcher(pushGateway, repositories.devices, logger);
  const syncNotifier = new SyncPushNotifier(
    repositories.devices,
    push,
    logger,
    options.syncPushDelayMs,
  );

  const tokenService = new TokenService({
    secret: config.auth.accessSecret,
    issuer: config.auth.issuer,
    audience: config.auth.audience,
    accessTtlSeconds: config.auth.accessTtlSeconds,
  });
  const passwordHasher = options.passwordHasher ?? new Argon2PasswordHasher();

  // Application (use cases)
  const settings = new SettingsService(repositories.settings, uow, clock, syncNotifier);
  const auth = new AuthService(
    repositories.users,
    repositories.refreshTokens,
    settings,
    passwordHasher,
    tokenService,
    uow,
    clock,
    config.auth.refreshTtlDays,
  );
  const services = {
    auth,
    account: new AccountService(
      repositories.users,
      repositories.refreshTokens,
      auth,
      passwordHasher,
      uow,
      clock,
    ),
    settings,
    tasks: new TaskService(repositories.tasks, repositories.settings, uow, clock, syncNotifier),
    sync: new SyncService(
      repositories.tasks,
      repositories.settings,
      settings,
      repositories.devices,
      uow,
      clock,
      syncNotifier,
    ),
    devices: new DeviceService(repositories.devices, clock),
    notifications: new NotificationService(
      repositories.notifications,
      repositories.devices,
      push,
      clock,
    ),
    stats: new StatsService(repositories.tasks, repositories.settings, clock),
  };

  // Background jobs
  const reminders = new ReminderDispatcher(
    repositories.tasks,
    repositories.devices,
    repositories.settings,
    repositories.notifications,
    push,
    uow,
    clock,
  );
  const digests = new DigestDispatcher(
    repositories.digest,
    repositories.devices,
    repositories.notifications,
    push,
    clock,
  );
  const cleanup = new CleanupJob(
    repositories.refreshTokens,
    repositories.tasks,
    repositories.notifications,
    repositories.devices,
    clock,
  );
  const scheduler = new JobScheduler(logger)
    .register({
      name: 'reminders',
      intervalMs: config.jobs.reminderIntervalMs,
      run: () => reminders.run(),
    })
    .register({
      name: 'digest',
      intervalMs: config.jobs.digestIntervalMs,
      run: () => digests.run(),
    })
    .register({
      name: 'cleanup',
      intervalMs: config.jobs.cleanupIntervalMs,
      run: () => cleanup.run(),
    });

  return {
    config,
    logger,
    clock,
    database,
    tokenService,
    repositories,
    services,
    push,
    syncNotifier,
    jobs: { scheduler, reminders, digests, cleanup },

    /** Stops jobs, sends pending sync pushes, closes the pool. */
    async shutdown(): Promise<void> {
      await scheduler.stop();
      await syncNotifier.flushAll();
      await database.close();
    },
  };
}

export type Container = ReturnType<typeof createContainer>;
