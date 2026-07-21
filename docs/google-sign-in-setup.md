# Google Sign-In setup (required for real Google accounts)

LIFEOS AI now uses the real Google account picker. It will **never** invent a fake `google.user@lifeos.local` account.

For Google Sign-In to succeed on a device, you must connect a real Firebase / Google Cloud OAuth client:

1. Create a Firebase project at https://console.firebase.google.com
2. Add an Android app with package name `com.example.lifeos_ai`
3. Add your debug SHA-1:
   ```bash
   cd android
   ./gradlew signingReport
   ```
4. Enable **Google** under Authentication → Sign-in method
5. Run:
   ```bash
   flutterfire configure
   ```
6. Rebuild the APK:
   ```bash
   flutter build apk --release
   ```

Until this is done, the Google button opens the real Google flow (or shows a clear configuration error). Use **email sign-up / sign-in** in the meantime — that works fully offline.
