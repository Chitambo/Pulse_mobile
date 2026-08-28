# Pulse Mobile

Flutter client for **Pulse** — W&C Computer Limited's internal operations platform.
Companion to the web app; talks to the same backend API and Socket.io server.

## Requirements

- Flutter (Dart SDK ≥ 3.11)
- Android Studio / Xcode toolchains
- A running Pulse backend (see the main repo)

## Configure the server

The API origin is a compile-time constant with a production default. Override it
without touching code:

```bash
# local backend
flutter run --dart-define=API_ORIGIN=http://10.0.2.2:5000        # Android emulator -> host
flutter run --dart-define=API_ORIGIN=http://192.168.1.20:5000    # physical device on LAN
```

Default (no flag): `https://pulse.52.42.96.17.nip.io` (production).

> `network_security_config.xml` permits cleartext **only** to `10.0.2.2` / `localhost`
> for local dev. Everything else must be HTTPS.

## Run

```bash
flutter pub get
flutter run --dart-define=API_ORIGIN=<your backend>
```

## Push notifications (optional)

Push is off until Firebase is configured — the app still works and polls
`/notifications`. See **FIREBASE_SETUP.md** to enable FCM.

## Release build

1. Create a keystore and `android/key.properties` (see `android/key.properties.example`).
2. `flutter build appbundle --release --dart-define=API_ORIGIN=https://<prod>`

Without `key.properties` the release build falls back to debug signing (fine for
sideloading, not for the Play Store).

## Project layout

```
lib/
  core/        api client, auth storage, socket, push, theme, offline cache
  models/      JSON models
  providers/   ChangeNotifier state (auth, notifications)
  screens/     one folder per feature area
  widgets/     shared UI (loading / empty / error / status chip ...)
  app.dart     auth gate + bottom-nav shell
  main.dart    bootstrap (Firebase, then runApp)
```
