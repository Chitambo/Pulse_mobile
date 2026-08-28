# Enabling push notifications (FCM)

The Dart side is already wired. The app runs fine without this — it just polls
`/notifications` instead of receiving push. Do the steps below to turn on push.

## 1. Firebase project

1. https://console.firebase.google.com -> create/choose a project.
2. **Add Android app**, package name `com.wandc.pulse_mobile`.
3. Download `google-services.json` -> `android/app/google-services.json`.
4. (iOS) Add an iOS app, download `GoogleService-Info.plist` -> `ios/Runner/`,
   and enable Push Notifications + Background Modes in Xcode.

## 2. Gradle (Android)

`android/settings.gradle.kts` — add to the `plugins { }` block:

```kotlin
id("com.google.gms.google-services") version "4.4.2" apply false
```

`android/app/build.gradle.kts` — add to the `plugins { }` block:

```kotlin
id("com.google.gms.google-services")
```

## 3. That's it

`main.dart` already calls `Firebase.initializeApp()` inside a try/catch and only
starts FCM (`PushNotificationService().init()`) when it succeeds. On the next
run, `firebaseReady` flips to true, the device token is registered with
`POST /api/auth/device-token` as `{ fcmToken, platform }`, and the backend
(`utils/push.js`) will deliver push for the same events it already creates
Notification rows for.

## 4. Backend

The backend needs its `FIREBASE_*` env vars set (service-account credentials) —
see the main repo's `.env` table. Without them `utils/push.js` silently no-ops.
