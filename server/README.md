# TaskFlow API

The backend for the TaskFlow app: accounts, tasks, offline-first sync, settings, devices and
local + push notifications.

**Stack:** Node.js 22, TypeScript, Express 5, Neon (serverless PostgreSQL), Drizzle ORM, zod,
JWT (jose), Argon2id, Firebase Cloud Messaging, pino, Vitest, OpenAPI 3.1 / Swagger UI.

## Quick start

```bash
cd server
cp .env.example .env         # fill in DATABASE_URL, MIGRATION_DATABASE_URL, JWT_ACCESS_SECRET
npm install
npm run db:migrate           # creates the tables in Neon
npm run dev                  # http://localhost:8080 - docs at http://localhost:8080/docs
```

No Neon account yet? `docker compose up --build` runs a local Postgres 17 and the API.

## Neon setup

1. Create a project at <https://console.neon.tech>.
2. **Connect** → copy the _pooled_ connection string (host contains `-pooler`) into
   `DATABASE_URL`, and the _direct_ one into `MIGRATION_DATABASE_URL`.
3. `npm run db:migrate`.

With a `*.neon.tech` host the API uses Neon's serverless driver (`@neondatabase/serverless`,
WebSockets, full transactions); with any other host it uses `node-postgres`. Force one with
`DB_DRIVER=neon|pg`.

## Push notifications (Firebase)

1. Create a Firebase project and add the Android app (`com.taskflow.taskflow`) and the iOS app.
2. Project settings → **Service accounts** → _Generate new private key_.
3. Put the JSON in `FIREBASE_SERVICE_ACCOUNT` (raw JSON on one line, or `base64 -w0 key.json`).
4. For iOS, upload an APNs key under Project settings → Cloud Messaging.

Without the key the API still works; pushes are written to the log instead of being sent.
`POST /api/v1/notifications/test` sends a test push to all of your devices.

## Scripts

| Command                       | What it does                                                                |
| ----------------------------- | --------------------------------------------------------------------------- |
| `npm run dev`                 | API with hot reload (also runs the jobs)                                    |
| `npm run dev:worker`          | Jobs only (reminders, digest, cleanup)                                      |
| `npm run build` / `npm start` | Compile to `dist/` and run                                                  |
| `npm test`                    | Unit and integration tests (in-memory Postgres via PGlite, no setup needed) |
| `npm run check`               | Typecheck + lint + tests                                                    |
| `npm run db:generate`         | New SQL migration after changing `src/core/db/schema.ts`                    |
| `npm run db:migrate`          | Apply migrations                                                            |
| `npm run db:studio`           | Browse the database (Drizzle Studio)                                        |
| `npm run openapi:export`      | Write `docs/openapi.json`                                                   |

## Architecture

The same feature-first Clean Architecture as the Flutter app (`features/<x>/{data,domain,presentation}`):

```
src/
  server.ts, worker.ts      entry points (HTTP + jobs / jobs only), graceful shutdown
  app.ts                    Express app: middleware, routes, docs
  container.ts              composition root (dependency injection), like core/di in the app
  config/env.ts             validated environment
  core/                     db (Drizzle schema, client, unit of work), http (middleware,
                            validation, OpenAPI), security (JWT, Argon2), jobs, logger, errors
  modules/<feature>/
    domain/                 entities, business rules, repository ports (no framework code)
    application/            use cases (services) and request/response schemas
    infrastructure/         Drizzle repositories, FCM gateway (adapters)
    presentation/           Express routes + OpenAPI docs
  jobs/                     cross-module jobs (cleanup)
tests/                      unit (domain) and integration (HTTP + database) tests
drizzle/                    generated SQL migrations
```

Features: `auth`, `users` (account), `tasks`, `sync`, `settings`, `devices`, `notifications`,
`stats`, `health`.

## API overview (`/api/v1`)

| Area          | Endpoints                                                                                                                     |
| ------------- | ----------------------------------------------------------------------------------------------------------------------------- |
| Auth          | `POST /auth/register`, `/auth/login`, `/auth/refresh`, `/auth/logout`                                                         |
| Account       | `GET/PATCH/DELETE /users/me`, `POST /users/me/password`                                                                       |
| Tasks         | `GET/POST /tasks`, `GET/PATCH/DELETE /tasks/:id`, `POST /tasks/:id/complete`, `/reopen`, subtasks under `/tasks/:id/subtasks` |
| Sync          | `POST /sync/push`, `GET /sync/pull?cursor=`                                                                                   |
| Settings      | `GET/PATCH /settings`                                                                                                         |
| Devices       | `PUT/DELETE /devices/:installationId`                                                                                         |
| Notifications | `GET /notifications`, `POST /notifications/:id/read`, `/read-all`, `/test`                                                    |
| Stats         | `GET /stats/summary?period=week                                                                                               | month | all` |
| Health        | `GET /health/live`, `/health/ready`                                                                                           |

Full reference: `/docs` (Swagger UI) or `/openapi.json`. Successful responses are
`{ "data": ... }`; errors are RFC 9457 problem details (`application/problem+json`).

## How notifications work

- **Local (on the phone):** the app schedules each reminder and the morning digest with
  `flutter_local_notifications`, so they fire offline and on time.
- **Push (FCM):**
  - **Reminder fallback:** a job runs every 30 s. When a reminder is due it pushes only to
    devices that have _not_ synced the latest version of that task (their `last_pulled_seq`
    is behind the task's `change_seq`), or that don't schedule reminders themselves. No
    duplicates, no missed reminders after editing on another device.
  - **Sync nudge:** after any change, a silent `{type: "sync"}` push goes to the user's other
    devices so they pull at once and reschedule their local reminders.
  - **Daily digest** for clients without a local digest (`localReminders: false`).
- Every server notification is also stored in an inbox (`GET /notifications`), and dedupe
  keys make each one idempotent even with several workers.

## Security

Argon2id password hashing, 15-minute JWT access tokens, rotating refresh tokens that are
stored hashed (reuse revokes the session), helmet, CORS, rate limiting, request size limits,
strict zod validation (unknown fields rejected), per-user data isolation on every query,
secrets redacted from logs, non-root Docker image.

## Deploying

Any Node host works (Render, Railway, Fly.io, a VM). Set the environment variables, run
`node dist/core/db/migrate.js` once per release, and start `node dist/server.js`. With
several API replicas, set `JOBS_ENABLED=false` on them and run one or more `node dist/worker.js`
(jobs use `FOR UPDATE SKIP LOCKED`, so workers never send the same thing twice).
