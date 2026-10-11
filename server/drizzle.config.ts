import { defineConfig } from 'drizzle-kit';

export default defineConfig({
  dialect: 'postgresql',
  schema: './src/core/db/schema.ts',
  out: './drizzle',
  dbCredentials: {
    // Only needed by `drizzle-kit studio`; `generate` works offline.
    url: process.env.MIGRATION_DATABASE_URL ?? process.env.DATABASE_URL ?? '',
  },
  strict: true,
  verbose: true,
});
