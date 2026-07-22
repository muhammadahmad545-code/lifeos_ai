# Remaining vs original LIFEOS AI prompt

Updated after latest build. ✅ working · 🟡 partial · ❌ not yet

## Done in this pass
- ✅ Task templates (built-in + save custom from any task)
- ✅ Expense pie chart by category
- ✅ Receipt photo attach (camera / gallery)
- ✅ Notes voice recording + playback
- ✅ Notes drawing canvas (saved into note markdown)
- ✅ Goals vision board (colors + optional image)
- ✅ Notes PDF export, subtasks, recurring tasks, reminders (earlier)

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
| Subtasks + templates | ✅ |
| Timeline, attachments, comments, collaboration | ❌ |
| Drawing canvas, voice notes, PDF export | ✅ |
| OCR, version history | ❌ |
| Drag-drop calendar, invitations, external sync, time blocking | ❌ |

### Other modules
| Feature | Status |
|---|---|
| Receipt photo attach | ✅ |
| Receipt OCR scanner | ❌ |
| Vision board | ✅ |
| HealthKit/Google Fit | ❌ |
| Website blocking ready hooks | ❌ |
| FCM push, Crashlytics live, Remote Config | ❌ |
| Lottie / glassmorphism design pack | ❌ |
| Full test suites | 🟡 basic unit tests |

## Next priority
1. Notes version history
2. Calendar time blocking
3. Simple OCR / receipt text extract (on-device if possible)
4. Firestore sync once Firebase is configured
