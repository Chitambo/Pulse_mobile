import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// Top-level background handler — must be a bare function, not a class method.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  // The FCM plugin shows a system notification automatically in background/terminated.
  // Nothing extra needed here unless you want custom handling.
}

class PushNotificationService {
  static final _instance = PushNotificationService._internal();
  PushNotificationService._internal();
  factory PushNotificationService() => _instance;

  final _plugin = FlutterLocalNotificationsPlugin();

  // Set this from app.dart after authentication to handle navigation on tap.
  void Function(Map<String, dynamic> data)? onNotificationTap;

  static const _channelId = 'pulse_notifications';
  static const _channelName = 'Pulse';

  // ── Init ──────────────────────────────────────────────────────────────────

  Future<void> init() async {
    await _initLocal();
    await _initFcm();
  }

  Future<void> _initLocal() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      const InitializationSettings(android: android),
      onDidReceiveNotificationResponse: _onLocalTap,
    );

    // Create the high-importance channel required for Android 8+
    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: 'Pulse app alerts',
      importance: Importance.high,
      enableVibration: true,
      playSound: true,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // Request POST_NOTIFICATIONS permission (Android 13+)
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  Future<void> _initFcm() async {
    try {
      final messaging = FirebaseMessaging.instance;

      // Request permission (harmless if Firebase isn't configured)
      await messaging.requestPermission(alert: true, badge: true, sound: true);

      // Override FCM foreground presentation — we show our own local notification
      await messaging.setForegroundNotificationPresentationOptions(
        alert: false,
        badge: true,
        sound: false,
      );

      // Foreground: FCM delivers silently — we show a local notification
      FirebaseMessaging.onMessage.listen((msg) {
        showLocal(
          title: msg.notification?.title ?? 'Pulse',
          body: msg.notification?.body ?? '',
          data: msg.data,
        );
      });

      // Tap while app was in background
      FirebaseMessaging.onMessageOpenedApp.listen((msg) {
        onNotificationTap?.call(msg.data);
      });

      // Tap from terminated state
      final initial = await messaging.getInitialMessage();
      if (initial != null) {
        Future.delayed(const Duration(milliseconds: 500), () {
          onNotificationTap?.call(initial.data);
        });
      }

      // Keep token fresh
      messaging.onTokenRefresh.listen(_onTokenRefresh);
    } catch (_) {
      // Firebase not yet configured — local notifications still work.
    }
  }

  // ── Token ─────────────────────────────────────────────────────────────────

  Future<String?> getToken() async {
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (_) {
      return null;
    }
  }

  void _onTokenRefresh(String token) {
    // Forwarded to AuthProvider via the onTokenRefresh callback if set.
    onTokenRefresh?.call(token);
  }

  void Function(String token)? onTokenRefresh;

  // ── Show a local notification ─────────────────────────────────────────────

  Future<void> showLocal({
    required String title,
    required String body,
    Map<String, dynamic> data = const {},
    int? id,
  }) async {
    await _plugin.show(
      id ?? (DateTime.now().millisecondsSinceEpoch & 0x7FFFFFFF),
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      payload: data.isEmpty ? null : jsonEncode(data),
    );
  }

  // ── Tap handler ───────────────────────────────────────────────────────────

  void _onLocalTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      onNotificationTap?.call(data);
    } catch (_) {}
  }
}
