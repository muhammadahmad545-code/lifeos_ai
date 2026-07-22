# Remaining vs original LIFEOS AI prompt

Updated after latest build. ✅ working · 🟡 partial · ❌ not yet

## Done in this pass
- ✅ GitHub Actions release APK + in-app update banner/installer
- ✅ Notes version history (auto-snapshot on edit, restore)
- ✅ Calendar Day view + time blocking (hourly grid, colors)
- ✅ On-device OCR (notes scan + receipt amount/category extract)
- ✅ Task templates, expense charts/receipts, voice/draw notes, vision board (earlier)

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
| PDF summaries / email drafting API | ❌ |
| OCR | ✅ |

### Tasks / Notes / Calendar extras
| Feature | Status |
|---|---|
| Subtasks + templates + version history | ✅ |
| Timeline, attachments, comments, collaboration | ❌ |
| Drawing canvas, voice notes, PDF export, OCR | ✅ |
| Drag-drop calendar, invitations, external sync | ❌ |
| Time blocking | ✅ |

### Other modules
| Feature | Status |
|---|---|
| Receipt photo + OCR extract | ✅ |
| Vision board | ✅ |
| HealthKit/Google Fit | ❌ |
| Website blocking ready hooks | ❌ |
| FCM push, Crashlytics live, Remote Config | ❌ |
| Lottie / glassmorphism design pack | ❌ |
| Full test suites | 🟡 basic unit tests |

## Next priority
1. Firestore sync once Firebase is configured
2. Task timeline / attachments
3. Voice AI chat
4. Push notifications (FCM) + Crashlytics
