# TaskFlow

A calm, offline-first task manager built with Flutter. Everything lives on the
device: accounts and tasks in SQLite, preferences in SharedPreferences. There
is no server and nothing is sent anywhere.

The UI follows the "Serene Focus" design (indigo on soft off-white, Plus
Jakarta Sans for headings, Inter for body text).

## Features

- **Tasks** with notes, subtasks, priority, category, due date/time or all-day
- **Quick add** that reads the title as you type:
  `Call Sam tomorrow at 5pm #personal !high` sets the date, time, tag and
  priority and saves the task as "Call Sam"
- **Repeating tasks** (daily, weekdays, weekly, monthly) - finishing one
  schedules the next
- **Reminders** before a task is due and an optional **morning digest**
  (local notifications)
- **Search** across titles, notes, categories and subtasks
- **Calendar** month view with per-day task dots
- **Stats**: flow score, on-time rate, streaks, weekday chart, category split,
  best focus hours and milestones
- **Backup**: export all tasks as JSON to the clipboard and import them again
- Light and dark theme

## Getting started

Requires Flutter 3.47+ (Dart 3.13+).

```bash
flutter pub get
flutter run
```

Run the tests:

```bash
flutter test
```

## Project layout

```
lib/
  app.dart, main.dart
  core/          database, routing, theme, notifications, helpers
  features/
    auth/        splash, sign in / sign up, local accounts
    tasks/       task list, search, calendar, details, add / edit
    stats/       productivity numbers and the stats screen
    settings/    preferences and the profile screen
  shared/        app shell (the floating dock), headers, small widgets
assets/fonts/    Plus Jakarta Sans and Inter (SIL Open Font License)
test/            unit tests
```

Each feature is split into `data`, `domain` and `presentation`. State is
handled with Riverpod 3 and navigation with go_router.

## Notes

- **Notifications.** Uses `flutter_local_notifications`. Android needs core
  library desugaring (already enabled in `android/app/build.gradle.kts`) and the
  receivers declared in `AndroidManifest.xml`. The app asks for notification
  permission the first time a reminder is saved or notifications are switched
  on in Profile.
- **Start-up.** The splash screen plays while the saved session is restored
  and then hands over to the router, which opens the task list or the sign-in
  screen.
- **Passwords** are stored as salted, iterated SHA-256 hashes.
- **Database upgrades** are handled in `core/database/app_database.dart`
  (currently schema version 4).
