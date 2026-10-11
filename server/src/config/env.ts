import { z } from 'zod';

/**
 * Every setting the API reads from the environment, validated once at start-up.
 * A missing or malformed value stops the process with a readable message instead
 * of failing later at runtime.
 */
const boolean = z
  .enum(['true', 'false', '1', '0', 'yes', 'no'])
  .transform((v) => v === 'true' || v === '1' || v === 'yes');

const envSchema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  HOST: z.string().default('0.0.0.0'),
  PORT: z.coerce.number().int().min(1).max(65_535).default(8080),
  LOG_LEVEL: z.enum(['fatal', 'error', 'warn', 'info', 'debug', 'trace', 'silent']).default('info'),

  /** Neon connection string (the pooled one for the API). */
  DATABASE_URL: z.url(),
  /** Neon direct (unpooled) connection string for migrations; falls back to DATABASE_URL. */
  MIGRATION_DATABASE_URL: z.url().optional(),
  /** `neon` = Neon serverless driver (WebSocket), `pg` = node-postgres (TCP), `auto` = neon for *.neon.tech hosts. */
  DB_DRIVER: z.enum(['auto', 'neon', 'pg']).default('auto'),
  DB_POOL_MAX: z.coerce.number().int().min(1).max(100).default(10),

  JWT_ACCESS_SECRET: z.string().min(32, 'JWT_ACCESS_SECRET must be at least 32 characters'),
  JWT_ACCESS_TTL_SECONDS: z.coerce.number().int().min(60).default(900),
  JWT_ISSUER: z.string().default('taskflow-api'),
  JWT_AUDIENCE: z.string().default('taskflow-app'),
  REFRESH_TOKEN_TTL_DAYS: z.coerce.number().int().min(1).max(365).default(30),

  /** Comma separated list of allowed origins, or `*`. Mobile apps don't send an Origin. */
  CORS_ORIGINS: z.string().default('*'),
  /** Value for Express `trust proxy` (hops in front of the app: load balancer, Render, Fly...). */
  TRUST_PROXY: z.coerce.number().int().min(0).default(1),
  DOCS_ENABLED: boolean.default(true),

  /** Run the notification jobs in this process. Turn off on API replicas if a separate worker runs them. */
  JOBS_ENABLED: boolean.default(true),
  REMINDER_INTERVAL_MS: z.coerce.number().int().min(5_000).default(30_000),
  DIGEST_INTERVAL_MS: z.coerce.number().int().min(10_000).default(60_000),
  CLEANUP_INTERVAL_MS: z.coerce.number().int().min(60_000).default(3_600_000),

  /** Firebase service account JSON, raw or base64 encoded. Without it pushes are only logged. */
  FIREBASE_SERVICE_ACCOUNT: z.string().optional(),
});

export type Env = z.infer<typeof envSchema>;

export interface AppConfig {
  env: Env['NODE_ENV'];
  isProduction: boolean;
  isTest: boolean;
  host: string;
  port: number;
  logLevel: Env['LOG_LEVEL'];
  database: {
    url: string;
    migrationUrl: string;
    driver: 'neon' | 'pg';
    poolMax: number;
  };
  auth: {
    accessSecret: string;
    accessTtlSeconds: number;
    issuer: string;
    audience: string;
    refreshTtlDays: number;
  };
  http: {
    corsOrigins: string[] | '*';
    trustProxy: number;
    docsEnabled: boolean;
  };
  jobs: {
    enabled: boolean;
    reminderIntervalMs: number;
    digestIntervalMs: number;
    cleanupIntervalMs: number;
  };
  firebase: {
    serviceAccount: Record<string, unknown> | null;
  };
}

function parseServiceAccount(raw: string | undefined): Record<string, unknown> | null {
  if (!raw || raw.trim() === '') return null;
  const text = raw.trim().startsWith('{') ? raw : Buffer.from(raw, 'base64').toString('utf8');
  try {
    return JSON.parse(text) as Record<string, unknown>;
  } catch {
    throw new Error('FIREBASE_SERVICE_ACCOUNT is not valid JSON (raw or base64).');
  }
}

function resolveDriver(driver: Env['DB_DRIVER'], url: string): 'neon' | 'pg' {
  if (driver !== 'auto') return driver;
  return new URL(url).hostname.endsWith('.neon.tech') ? 'neon' : 'pg';
}

export function loadConfig(source: NodeJS.ProcessEnv = process.env): AppConfig {
  const parsed = envSchema.safeParse(source);
  if (!parsed.success) {
    const problems = parsed.error.issues
      .map((issue) => `  - ${issue.path.join('.') || '(root)'}: ${issue.message}`)
      .join('\n');
    throw new Error(`Invalid environment configuration:\n${problems}`);
  }
  const env = parsed.data;
  const origins = env.CORS_ORIGINS.trim();

  return {
    env: env.NODE_ENV,
    isProduction: env.NODE_ENV === 'production',
    isTest: env.NODE_ENV === 'test',
    host: env.HOST,
    port: env.PORT,
    logLevel: env.LOG_LEVEL,
    database: {
      url: env.DATABASE_URL,
      migrationUrl: env.MIGRATION_DATABASE_URL ?? env.DATABASE_URL,
      driver: resolveDriver(env.DB_DRIVER, env.DATABASE_URL),
      poolMax: env.DB_POOL_MAX,
    },
    auth: {
      accessSecret: env.JWT_ACCESS_SECRET,
      accessTtlSeconds: env.JWT_ACCESS_TTL_SECONDS,
      issuer: env.JWT_ISSUER,
      audience: env.JWT_AUDIENCE,
      refreshTtlDays: env.REFRESH_TOKEN_TTL_DAYS,
    },
    http: {
      corsOrigins:
        origins === '*'
          ? '*'
          : origins
              .split(',')
              .map((o) => o.trim())
              .filter(Boolean),
      trustProxy: env.TRUST_PROXY,
      docsEnabled: env.DOCS_ENABLED,
    },
    jobs: {
      enabled: env.JOBS_ENABLED,
      reminderIntervalMs: env.REMINDER_INTERVAL_MS,
      digestIntervalMs: env.DIGEST_INTERVAL_MS,
      cleanupIntervalMs: env.CLEANUP_INTERVAL_MS,
    },
    firebase: {
      serviceAccount: parseServiceAccount(env.FIREBASE_SERVICE_ACCOUNT),
    },
  };
}
