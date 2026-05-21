import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'core/notifications/push_notification_service.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Register the FCM background handler before anything else.
  FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);

  // To activate Firebase / FCM:
  //   1. Create a Firebase project at console.firebase.google.com
  //   2. Add Android app with package: com.wandc.pulse_mobile
  //   3. Download google-services.json → android/app/google-services.json
  //   4. Add to android/settings.gradle.kts plugins block:
  //        id("com.google.gms.google-services") version "4.4.2" apply false
  //   5. Add to android/app/build.gradle.kts plugins block:
  //        id("com.google.gms.google-services")
  //   6. Uncomment the two lines below:
  // import 'package:firebase_core/firebase_core.dart';
  // await Firebase.initializeApp();

  // Start notification init in background — don't block runApp.
  unawaited(PushNotificationService().init());

  runApp(const PulseApp());
}
