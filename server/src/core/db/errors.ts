/** Postgres error codes we react to (https://www.postgresql.org/docs/current/errcodes-appendix.html). */
const UNIQUE_VIOLATION = '23505';
const FOREIGN_KEY_VIOLATION = '23503';
const CHECK_VIOLATION = '23514';

function pgCode(error: unknown): string | undefined {
  // Drizzle wraps driver errors; the Postgres code sits on the error or its cause.
  const e = error as { code?: unknown; cause?: { code?: unknown } } | null;
  const code = e?.code ?? e?.cause?.code;
  return typeof code === 'string' ? code : undefined;
}

export const isUniqueViolation = (error: unknown) => pgCode(error) === UNIQUE_VIOLATION;
export const isForeignKeyViolation = (error: unknown) => pgCode(error) === FOREIGN_KEY_VIOLATION;
export const isCheckViolation = (error: unknown) => pgCode(error) === CHECK_VIOLATION;
