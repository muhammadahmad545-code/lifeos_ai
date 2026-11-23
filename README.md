# Plania

*Renamed from **LifeOS** in 2.0.1.*

An offline personal organizer for Android, part of the Basalt app suite. Tasks, notes, calendar,
habits, journal, expenses, goals and a focus timer in one calm app. No account, no cloud: everything
stays on the phone.

## Features

- **Home**: today at a glance. Tasks due today and overdue, habit check-offs, today's events, focus minutes.
- **Tasks**: due date and time, priority, repeat (daily, weekdays, weekly, monthly, yearly), reminders,
  subtasks. Open / Today / Upcoming / Done views. Completing a repeating task creates the next one (undo removes it).
- **Reminders**: local notifications with exact alarms when allowed (inexact fallback), restored after a reboot.
- **Notes**: title, text and checklists, pinning, search.
- **Calendar**: month grid with markers, day agenda with events and due tasks, all-day and multi-day events.
- **Habits**: daily check-offs, current and best streaks, a 7-day strip to fix missed days, pause or delete.
- **Journal**: entries with a mood.
- **Expenses**: expenses and income by category, monthly totals, a 6-month trend, per-category budgets.
- **Goals**: target date, milestones that drive progress (or manual progress).
- **Focus timer**: 15/25/45/60 minute sessions that survive the app closing, with an end-of-session notification.
- **Search** across everything.
- **Assistant**: a rule-based helper that answers questions about your own data (plan my day, overdue,
  week ahead, spending, habit streaks, goals, focus, mood). It runs on the device, with no internet.
- **Settings**: System/Light/Dark theme, currency symbol, notification status, optional app lock
  (fingerprint, face or phone PIN), JSON backup export and import, updates.

## Stack

Flutter, Riverpod, Drift (SQLite), flutter_local_notifications, local_auth, file_picker and the shared
[`basalt`](https://github.com/muhammadahmad545-code/basalt-flutter) package for the design system and updater.

## Updates

On every launch (and when resumed after 15 minutes) the app checks this repo's GitHub releases. When a
newer version exists, Home shows a card that downloads the APK for the phone's ABI, verifies its SHA-256
and opens the installer. Settings > Updates checks by hand.

## Build

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # Drift code generation
flutter test
flutter build apk --release --split-per-abi
```

CI (`.github/workflows/build.yml`) runs analysis and tests, builds the APKs, and runs an emulator smoke
test with end-to-end checks (`scripts/smoke.sh`, `scripts/e2e.sh`). Tags `v*` publish a release, signed
with the suite key from repository secrets.

## Upgrading from 1.x

1.x was `com.example.lifeos_ai` with local accounts. 2.0 is `dev.basalt.lifeos`, single-user. The
database migration (schema 5) keeps all rows, assigns them to the local user, rebuilds habit history from
the old streak counters and drops the old accounts table.
