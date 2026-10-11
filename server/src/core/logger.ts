import { pino, type Logger, type LoggerOptions } from 'pino';

export type { Logger };

/**
 * Structured JSON logs in production, pretty logs while developing.
 * Secrets that could end up in a log line are redacted.
 */
export function createLogger(options: { level: LoggerOptions['level']; pretty: boolean }): Logger {
  return pino({
    level: options.level,
    base: { service: 'taskflow-api' },
    timestamp: pino.stdTimeFunctions.isoTime,
    redact: {
      paths: [
        'req.headers.authorization',
        'req.headers.cookie',
        '*.password',
        '*.currentPassword',
        '*.newPassword',
        '*.refreshToken',
        '*.accessToken',
        '*.pushToken',
      ],
      censor: '[redacted]',
    },
    ...(options.pretty
      ? {
          transport: {
            target: 'pino-pretty',
            options: {
              colorize: true,
              translateTime: 'SYS:HH:MM:ss',
              ignore: 'pid,hostname,service',
            },
          },
        }
      : {}),
  });
}
