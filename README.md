# ClassTrack

Attendance + class-schedule tracker for students, with **Gemini AI** timetable import.
Built with **Flutter** (iOS + Android) and **Firebase** (Auth, Firestore, Storage, Cloud Functions).

- Track per-subject and overall attendance %, with a color-coded progress ring.
- **Bunk calculator** — how many classes you can still skip (or must attend) to stay above your target %.
- Weekly recurring schedule with **Day / Week / Month** calendar views.
- **AI import**: snap a photo / upload a PDF / paste text → Gemini parses it → you review before saving.
- Local reminders before class and to mark attendance.
- Export schedule as **.ics**, attendance summary as **PDF / CSV**, share links via the native share sheet.
- Light & dark mode, Google + email sign-in, account deletion, privacy policy (Play Store ready).

---

## 0. Prerequisites

Flutter is **not** installed in this scaffold's build environment, so you must install it locally:

1. Install the **Flutter SDK** (latest stable): https://docs.flutter.dev/get-started/install
2. Install **Android Studio** (for the Android SDK + an emulator) and/or **Xcode** (macOS, for iOS).
3. Install the **Firebase CLI** and **FlutterFire CLI**:
   ```bash
   npm install -g firebase-tools
   dart pub global activate flutterfire_cli
   ```
4. Verify: `flutter doctor` should be all green for your target platform.

---

## 1. Get the app compiling

From the project root (`ClassTrack/`):

```bash
flutter pub get          # fetch Dart/Flutter packages
```

> The native folders (`android/`, `ios/`, `web/`), the **app icon**, and the **splash screen**
> are already generated. Icon source art lives in `assets/icon/`. To regenerate after changing it:
>
> ```bash
> dart run flutter_launcher_icons
> dart run flutter_native_splash:create
> ```

Then check for issues:

```bash
flutter analyze
```

> Verified on Flutter 3.44.6 / Dart 3.12.2: `flutter analyze` → 0 errors, `flutter test` passes,
> and `flutter build web` compiles the whole app.

---

## 2. Firebase setup

1. Create a Firebase project at https://console.firebase.google.com.
2. **Lock in the package name / bundle ID before anything else** — this app uses
   `com.classtrack.app` and it **cannot be changed after publishing**.
3. Enable these products in the console:
   - **Authentication** → Email/Password **and** Google.
   - **Cloud Firestore** (production mode).
   - **Cloud Storage**.
   - **Cloud Functions** (requires the Blaze plan to deploy; the Spark free tier still covers
     Auth/Firestore/Storage — Functions need Blaze but stay within the free invocation grant).
4. Connect the app (regenerates `lib/firebase_options.dart` with your real keys):
   ```bash
   flutterfire configure
   ```
   This also drops `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) in place.
5. Deploy security rules:
   ```bash
   firebase deploy --only firestore:rules,storage
   ```

### Google Sign-In extra steps
- **Android**: add your SHA-1 and SHA-256 fingerprints in Firebase → Project settings → your Android app,
  then re-run `flutterfire configure`.
- **iOS**: add the reversed client ID URL scheme to `ios/Runner/Info.plist` (FlutterFire prints it).

---

## 3. Gemini Cloud Function

The Gemini API key lives **only** on the server.

```bash
cd functions
npm install

# Store your Gemini API key as a secret (get a key at https://aistudio.google.com/app/apikey)
firebase functions:secrets:set GEMINI_API_KEY

# Deploy
firebase deploy --only functions
```

The callable function `parseSchedule` accepts:
- `{ sourceType: "text", text }` — pasted timetable, or
- `{ sourceType: "image"|"pdf", storagePath, inlineData?, mimeType }` — uploaded file.

It forces Gemini (`gemini-2.0-flash`) to return **strict JSON**, validates it, and returns it to the
client. The client shows an **editable review screen** and only writes to Firestore after you confirm.

---

## 4. Run on your phone

> ⚠️ The app calls `Firebase.initializeApp` on launch, so it will **crash on startup until you
> complete Step 2 (`flutterfire configure`)**. Do that first.

### Android (easiest — works from Windows)
1. Finish the Android toolchain in Android Studio: open **More Actions → SDK Manager →
   SDK Tools**, tick **Android SDK Command-line Tools**, apply. Then accept licenses:
   ```bash
   flutter doctor --android-licenses
   ```
2. On the phone: **Settings → About phone →** tap **Build number** 7×, then in
   **Developer options** enable **USB debugging**.
3. Plug the phone into the PC via USB and approve the "Allow USB debugging" prompt.
4. Confirm it's detected and run:
   ```bash
   flutter devices
   flutter run
   ```
   Or build an installable APK and copy it to the phone:
   ```bash
   flutter build apk --release
   # output: build/app/outputs/flutter-apk/app-release.apk
   ```

### Wireless (no cable)
```bash
adb pair <phone-ip>:<pair-port>      # from the phone's Wireless debugging screen
adb connect <phone-ip>:<port>
flutter run
```

### iOS (requires a Mac)
Open `ios/Runner.xcworkspace` in Xcode, set your signing team, then `flutter run` with the
iPhone connected.

### Quick UI preview without a phone
```bash
flutter run -d chrome
```
(Firebase web config from `flutterfire configure` still required for anything past the splash.)

---

## 5. Platform config notes

Add these before building release binaries:

**Android** (`android/app/src/main/AndroidManifest.xml`)
- Permissions: `INTERNET`, `POST_NOTIFICATIONS` (Android 13+), `SCHEDULE_EXACT_ALARM` (optional, for exact reminders).
- `minSdkVersion 23` (set in `android/app/build.gradle`).
- For `flutter_local_notifications` scheduling, add the receivers noted in its README.

**iOS** (`ios/Runner/Info.plist`)
- `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription` (image import).
- Enable Push/Notifications capability; set deployment target to **13.0+**.

**Local notification time zones**
- The notification service initialises the tz database but defaults `tz.local` to UTC.
  For exact local-time reminders, add [`flutter_timezone`](https://pub.dev/packages/flutter_timezone)
  and call `tz.setLocalLocation(tz.getLocation(await FlutterTimezone.getLocalTimezone()))`
  inside `NotificationService.init()`.

---

## 6. Store checklist

- **App icons / splash**: use `flutter_launcher_icons` + `flutter_native_splash` (add to dev_deps).
- **Privacy policy**: in-app screen exists (`Settings → Privacy policy`). Host the full text at a public
  URL and set `AppConstants.privacyPolicyUrl`.
- **Account deletion**: implemented (`Settings → Delete account`) — required by Google Play for apps
  that collect user data.
- **Play Data Safety form**: disclose Auth (email), user content (schedule/attendance), and files (uploads).
- Target **Android minSdk 23+** and **iOS 13+**.

---

## 7. Architecture

Feature-first, Riverpod for state.

```
lib/
  core/            theme, router, constants, utils, providers (Firebase, settings)
  shared/          reusable widgets (progress ring, buttons, empty states, confetti)
  services/        notification_service
  features/
    auth/          data · domain · presentation (splash, login, signup, onboarding)
    subjects/      subject CRUD + detail
    schedule/      sessions + day/week/month views
    attendance/    marking flow, stats, bunk calculator
    import/        Gemini upload + editable review
    export/        .ics / PDF / CSV
    home/          shell + dashboard
    settings/      settings + privacy policy
functions/         parseSchedule Gemini Cloud Function
firestore.rules    owner-only access
storage.rules      owner-only uploads (image/pdf, <10 MB)
```

### Firestore data model
```
users/{uid}                                   displayName, email, targetAttendancePercent, createdAt
users/{uid}/subjects/{id}                      name, colorHex, professor, credits, classLink, resourceLinks[]
users/{uid}/subjects/{id}/sessions/{id}        recurring, dayOfWeek(0-6)|specificDate, startTime, endTime, room, cancelledOn[]
users/{uid}/subjects/{id}/attendance/{dateId}  date, status(present|absent|cancelled), markedAt
```

---

## 8. Package name / bundle ID

`com.classtrack.app` — **decide and lock this before creating the Firebase project**; it cannot be
changed after you publish to the stores.
