# Setting up Firebase (Spark, free)

The app runs without Firebase (everything stays on the phone). These steps switch it to Firebase
Authentication and Cloud Firestore, the only two services the report uses (4.3). Never add a card:
Spark has no billing, and the report rules out Cloud Storage and Cloud Functions.

1. Go to console.firebase.google.com, Add project, name it `mypet-pcs04`, turn Google Analytics off.
   Stay on the Spark plan.
2. Build > Authentication > Get started > Email/Password > Enable.
3. Build > Firestore Database > Create database, location `asia-southeast1` (Singapore, closest to
   Monash Malaysia), start in production mode.
4. On the Mac:
   ```sh
   npm install -g firebase-tools
   dart pub global activate flutterfire_cli
   firebase login
   cd app
   flutterfire configure --project mypet-pcs04 --platforms ios,android
   ```
   This rewrites `lib/firebase_options.dart`. The values in it are not secrets (they identify the
   project; the security rules protect the data).
5. Publish the rules:
   ```sh
   cd firebase && firebase deploy --only firestore:rules --project mypet-pcs04
   ```
6. Run the app with Firebase:
   ```sh
   flutter run --dart-define=BACKEND=firebase
   ```

Rules tests run against the local emulator, no project needed:
```sh
cd firebase/rules_test && npm install && npm test
```
