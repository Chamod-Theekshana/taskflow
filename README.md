# TaskFlow

TaskFlow is an offline-first task manager built with Flutter. All data stays on
the device: accounts and tasks are stored in SQLite, and settings in
SharedPreferences.

- **State management:** Riverpod 3
- **Navigation:** go_router 18
- **Architecture:** clean architecture (data / domain / presentation per feature)

## Getting started

```bash
flutter pub get
flutter run
```

Run the unit tests with:

```bash
flutter test
```

Requirements: Flutter 3.47 or newer and Dart 3.13 or newer (see `pubspec.yaml`).

## Project structure

```
lib/
  core/        DI providers, routing (router + pure route guard), theme,
               database, date/time helpers, failures
  features/
    auth/      sign up / sign in / session (salted password hashing)
    tasks/     tasks, subtasks, home, calendar, detail, add / edit
    settings/  preferences and the profile screen
  shared/      app shell (bottom dock), avatar, not-found screen
test/          unit tests for the route guard, date utils, task logic, hashing
```

## What was fixed in this version

### Blocking bugs

1. **The app stayed on the splash screen.** The router redirect treated
   `/splash` as an auth page that signed-out users may stay on. After the
   saved session was restored, a signed-out user was never sent to `/login`.
   The same thing happened after logging out and after a failed login. The
   guard is now a pure function (`core/routing/route_guard.dart`) covered by
   tests.
2. **Sign-in, sign-up and sign-out bounced to the splash screen.** Each one
   put the global auth state back into "loading". The router answered by
   switching to the splash screen, which unmounted the login form and hid any
   error. Auth actions now update the state directly and throw failures back
   to the form.
3. **`context.go('/')` pointed at a route that didn't exist.** A `/` route
   now redirects to `/home`, and there is a proper not-found page.
4. **Tasks never loaded on Home.** `TaskListNotifier.build()` wrote to `state`
   before it was initialised, which throws in Riverpod, so the list stayed
   empty. The first load now runs after `build()`, errors are caught, and
   results from a previous account are discarded.
5. **Task details crashed with a red error screen.** `firstWhere` without
   `orElse` threw while tasks were still loading, for bad links and right
   after deleting a task. Invalid `:id` values in the URL also crashed
   `int.parse`.
6. **Editing an overdue task crashed the date picker.** `firstDate` was
   `DateTime.now()`, so an overdue task's date fell before it.
7. **Profile: the "Daily Breakdown" chart overflowed.** 104 px of bars and
   labels were placed in 88 px of space.
8. **The splash screen could still freeze on the Android emulator.** It
   blurred the whole screen with a `BackdropFilter` (sigma 50) and redrew it
   on every frame of two endless animations. On the emulator's Impeller
   OpenGLES renderer this could stall rendering. The glow is now drawn with
   radial gradients (no blur). Start-up can also no longer hang: restoring
   the saved session times out after 10 s and falls back to "signed out",
   the database and preferences time out after 20 s and show the error
   screen, and the splash screen asks the router to re-check once the
   session is restored. Each start-up step is logged to the console
   (`TaskFlow: ...` / `TaskFlow router: ...`).
9. **Theme: text and icons were invisible.** `primaryFixed`, `tertiaryFixed`
   and the `surfaceContainer*` colours were never set, so Flutter fell back to
   `primary`, `tertiary` or `surface`. Selected categories, the medium
   priority option and the reminder icon became invisible, and cards blended
   into the background. The dark theme only set three colours and lost the
   app fonts.

### Data and security

- **Database version 3.**
  - Creates the `users` table on upgrade (the old v1 to v2 migration forgot
    it).
  - Enables foreign keys, so deleting a task also deletes its subtasks.
  - Adds indexes and cleans up orphaned subtasks.
- **Tasks are private to each account.** Before, every account on the device
  saw every task. Tasks created by older versions have no owner. The first
  account that signs in after the upgrade adopts them, so no data disappears.
- **Tasks store their real due time.** A new `completedAt` column records
  when a task was finished, which makes Upcoming, Overdue, On-time % and
  Streak correct.
- **Passwords use salted, iterated SHA-256.** Old unsalted hashes still work
  and are upgraded the next time that user signs in.
- **Email addresses are trimmed and case-insensitive.**
- **"Remember me" now works.**
- **Invalid stored settings no longer crash the app.** An out-of-range
  default priority, for example, falls back safely.
- **A database error at start-up now shows an error screen** instead of
  leaving the native splash screen up forever.

### Features that did nothing, or showed fake data

- **Add / Edit:**
  - The time picker works (the time was stuck at 02:00 PM).
  - "Default Priority" from the profile screen is used for new tasks.
  - The title counter updates and titles are limited to 120 characters.
  - Cmd/Ctrl + Enter saves the task.
  - The picked date is shown on its chip.
- **Task detail:**
  - Due date, relative time ("In 3 hours", "Overdue by 2 days"), "Created"
    and "Last updated" are calculated. They used to be hard-coded ("Due
    Today", "In 3 hours", "Created yesterday by Alex").
  - Reschedule works.
  - Subtasks can be deleted, and Enter adds a subtask.
- **Calendar:**
  - The month title and the selected-day label are live (they used to say
    "October 2024" and "Oct 24").
  - The Today, previous and next buttons work.
  - Days with tasks show dots.
  - Each task shows its real time and opens its detail page when tapped.
  - The list no longer overflows or hides behind the navigation dock.
- **Home:**
  - Loading, empty and error states.
  - The filter counts match the filters.
  - Search can be cleared.
  - Pull to refresh.
  - The "…" menu on each card has Edit and Delete (with confirmation).
- **Profile:**
  - Done, On-time, Streak and the weekly chart use real data.
  - You can edit your name.
  - The digest time can be picked.
  - "Export Tasks" copies all tasks to the clipboard as JSON.
  - Logging out asks for confirmation.
  - The fake "Pro Plan", "Top 5%", "+14%" and "Last synced 5m ago" labels are
    gone.
- **Avatars:** photos loaded from `pravatar.cc` (a stranger's face that
  needed internet) are replaced by the user's initials.
- **Android release builds:** added the `INTERNET` permission so
  `google_fonts` can download the fonts once and cache them.
- **Navigation dock:**
  - It hides while the keyboard is open.
  - SnackBars appear above it instead of covering it.
  - It respects the gesture bar.
  - Its buttons have semantic labels.

## Known limitations

- The **"Remind me"**, **Push Notifications** and **Daily Digest** switches
  are saved as preferences, but no notifications are scheduled yet. That
  needs a notification plugin, for example `flutter_local_notifications`.
- **Repeating tasks** are not implemented. The Repeat row says so when
  tapped.
- Social sign-in (Google or Apple) and "Forgot password" are not available in
  local-only mode.
