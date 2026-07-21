# Firebase Setup

The app is wired to expect FlutterFire-generated configuration.

Required generated artifacts:

- `lib/firebase_options.dart`
- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`

Generate them with FlutterFire CLI for your Firebase project, then replace the placeholder `lib/firebase_options.dart` file.
