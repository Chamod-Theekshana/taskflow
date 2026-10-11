# TaskFlow

A focused, offline-first task manager: a **Flutter** app with a **Node.js / Express / Neon
PostgreSQL** backend (in [`server/`](server/README.md)).

The app keeps working without a connection. Tasks are saved in SQLite on the phone first
and synced with the server in the background, so they also appear on your other devices.
Reminders are local notifications (they fire even when offline); the server adds push
notifications through Firebase for the cases a phone can't know about yet.

## Features

- **Accounts**: sign up / log in against the API (JWT + rotating refresh tokens, stored in
  the Keychain / Keystore). "Remember me" off keeps the session in memory only.
- **Tasks** with notes, subtasks, priority, category, due date/time or all-day
- **Quick add** that reads the title as you type:
  `Call Sam tomorrow at 5pm #personal !high` sets the date, time, tag and priority
- **Repeating tasks** (daily, weekdays, weekly, monthly): finishing one schedules the next
- **Sync** across devices, offline-first, with last-write-wins per task
- **Notifications**: local reminders and morning digest + Firebase push (reminders for
  tasks changed on another device, instant "sync" nudges)
- **Search**, **calendar** month view, **stats** (flow score, on-time rate, streaks...)
- **Backup**: export / import JSON through the clipboard
- Dark (default) and light theme

## Run it

### 1. Backend

```bash
cd server
cp .env.example .env      # Neon connection strings + JWT secret
npm install
npm run db:migrate
npm run dev               # http://localhost:8080, API docs at /docs
```

Details (Neon, Firebase service account, deployment): [server/README.md](server/README.md).

### 2. App

Requires Flutter 3.47+ (Dart 3.13+).

```bash
flutter pub get
flutter run                                    # uses http://10.0.2.2:8080 (Android emulator)
flutter run --dart-define-from-file=config/dev.json
```

`config/example.json` lists the build settings: `API_BASE_URL` and, for push notifications,
the Firebase client values (Firebase console → Project settings → Your apps). Without the
Firebase values the app runs normally, just without remote pushes.

For push on iOS also enable **Push Notifications** and **Background Modes → Remote
notifications** in Xcode (Runner → Signing & Capabilities) and upload an APNs key to Firebase.

Tests: `flutter test` (app) and `cd server && npm test` (API).

Full guides: [`docs/TaskFlow-Frontend-Guide.pdf`](docs/TaskFlow-Frontend-Guide.pdf) and
[`docs/TaskFlow-Backend-Guide.pdf`](docs/TaskFlow-Backend-Guide.pdf).

## Project layout

```
lib/
  app.dart, main.dart
  core/          config, database, network (API client), storage (tokens), sync bus,
                 routing, theme, notifications (local + push), helpers
  features/
    auth/        splash / welcome, log in / sign up, session
    tasks/       task list, search, calendar, details, add / edit
    sync/        sync engine (push local changes, pull remote ones)
    devices/     registers this install and its push token with the API
    stats/       productivity numbers and the stats screen
    settings/    preferences and the profile screen
  shared/        app shell (the notched dock), headers, UI kit
server/          the API (see server/README.md)
test/            unit tests
docs/            frontend and backend guides (PDF)
```

Each feature is split into `data`, `domain` and `presentation`. State is handled with
Riverpod 3 and navigation with go_router. The backend uses the same feature-first layout
(`server/src/modules/<feature>/{domain,application,infrastructure,presentation}`).

## Notes

- **Upgrading from the offline-only version:** existing local tasks and preferences are kept.
  After signing up (or in) with the same email they are adopted by the account and uploaded.
- **Database upgrades** are handled in `core/database/app_database.dart` (schema version 5
  adds the sync columns).
- **Design tokens.** Colours live in `core/theme/app_colors.dart` (`AppPalette`, read with
  `context.palette`); text styles in `core/theme/app_theme.dart`.
