# Remaining vs original LIFEOS AI prompt

Updated after latest build. ✅ working · 🟡 partial · ❌ not yet

## Done in this pass
- ✅ Home weather widget (Open-Meteo + city in Settings)
- ✅ Calendar Month / Week / Agenda views
- ✅ Recurring tasks (daily / weekly / monthly) + auto next occurrence
- ✅ Local task reminders (1 hour before due)
- ✅ Notes markdown editor + preview + checklist/heading helpers
- ✅ Focus modes (Pomodoro / Deep Work / Break) + ambient sound toggle
- ✅ Habits streak chart + achievements counter
- ✅ Backup export, Kanban, real Google account picker (needs Firebase OAuth config)

## Still remaining

### Auth / cloud
| Feature | Status |
|---|---|
| Finish Google Sign-In with Firebase OAuth + SHA-1 | 🟡 code ready, config needed |
| Apple Sign-In on iOS | 🟡 |
| Multi-device Firestore sync | ❌ |
| Real SMS/email OTP delivery | ❌ |

### AI
| Feature | Status |
|---|---|
| Offline AI over your data | ✅ |
| Voice chat | ❌ |
| Cloud LLM (ChatGPT/Gemini) | ❌ |
| PDF summaries / OCR / email drafting API | ❌ |

### Tasks / Notes / Calendar extras
| Feature | Status |
|---|---|
| Subtasks, timeline, attachments, comments, collaboration, templates | ❌ |
| Drawing canvas, voice notes, OCR, version history, PDF export | ❌ |
| Drag-drop calendar, invitations, external sync, time blocking | ❌ |

### Other modules
| Feature | Status |
|---|---|
| Receipt scanner, vision board, HealthKit/Google Fit | ❌ |
| Website blocking ready hooks | ❌ |
| FCM push, Crashlytics live, Remote Config | ❌ |
| Lottie / glassmorphism design pack | ❌ |
| Full test suites | 🟡 basic unit tests |

## Next priority
1. Subtasks + task templates
2. Notes PDF export
3. Expense charts polish + receipt photo attach
4. Firestore sync once Firebase is configured
