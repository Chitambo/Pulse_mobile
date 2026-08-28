import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'core/notifications/push_notification_service.dart';
import 'app.dart';

/// True once Firebase has initialised. When false the app still runs fully —
/// it just polls /notifications instead of receiving push.
bool firebaseReady = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase needs android/app/google-services.json (Android) and the
  // GoogleService-Info.plist (iOS), plus the google-services Gradle plugin.
  // See FIREBASE_SETUP.md. Until that's in place initializeApp() throws — the
  // app carries on without push.
  try {
    await Firebase.initializeApp();
    firebaseReady = true;
    FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);
  } catch (e) {
    debugPrint('Firebase not configured — push notifications disabled ($e)');
  }

  // Start notification init in the background — don't block runApp.
  if (firebaseReady) unawaited(PushNotificationService().init());

  runApp(const PulseApp());
}
