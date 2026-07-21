# LIFEOS AI

**Your entire life in one intelligent application.**

Offline-first Flutter productivity app with local SQLite (Drift), Hive settings, secure sessions, and a built-in AI assistant that reasons over your own data.

## Features

- **Auth** — Email sign-up / sign-in, OTP (`123456`), Google/Apple local providers, biometric unlock, remember me, profile & security (2FA flag + biometrics)
- **Home** — Live productivity score, today’s tasks, calendar, habits, notes, water, mood, AI tip, daily quote
- **Tasks / Notes / Calendar / Habits / Journal / Expenses / Goals** — Real CRUD persisted in Drift
- **Focus** — Working Pomodoro timer with saved sessions
- **Health** — Water, sleep, weight, workout, medicine logs
- **Files** — Local file picker + favorites/folders
- **AI Assistant** — Offline intent engine (planning, prioritization, summaries, expense insights, journal reflection, translate, brainstorm)
- **Search / Notifications / Settings / Admin** — Cross-module search, notification center, theme/language prefs, live admin counts

## Run

```bash
cd lifeos_ai
flutter pub get
dart run build_runner build
flutter run
```

### First login

1. Open the app → **Create account** (sign-up toggle)
2. Use any email + password (min 6 chars)
3. Explore modules from Home or **More → Settings → Modules**

OTP / password reset demo code: `123456`

## Build release APK

```bash
flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk`

## Architecture

- Feature-first Clean Architecture (domain / data / presentation)
- Riverpod DI + GoRouter
- Drift SQLite for structured data
- Hive for settings
- Secure storage for sessions
- Firebase packages ready — app auto-falls back to **local mode** until real `flutterfire configure` credentials are added

## Docs

See `docs/` for architecture, installation, contributing, and developer guides.
