import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {}

class PushNotificationService {
  static final _instance = PushNotificationService._internal();
  PushNotificationService._internal();
  factory PushNotificationService() => _instance;

  final _plugin = FlutterLocalNotificationsPlugin();

  void Function(Map<String, dynamic> data)? onNotificationTap;
  void Function(String token)? onTokenRefresh;

  // Standard channel
  static const _channelId = 'pulse_notifications';
  static const _channelName = 'Pulse';

  // Urgent channel — max importance, full-screen intent on Android
  static const _urgentChannelId = 'pulse_urgent';
  static const _urgentChannelName = 'Pulse Urgent Alerts';

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

    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    // Standard channel
    await androidImpl?.createNotificationChannel(const AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: 'Pulse app alerts',
      importance: Importance.high,
      enableVibration: true,
      playSound: true,
    ));

    // Urgent channel — highest importance, vibration pattern, sound
    await androidImpl?.createNotificationChannel(AndroidNotificationChannel(
      _urgentChannelId,
      _urgentChannelName,
      description: 'Critical alerts that require immediate attention',
      importance: Importance.max,
      enableVibration: true,
      playSound: true,
      enableLights: true,
      ledColor: const Color.fromARGB(255, 220, 38, 38),
    ));

    await androidImpl?.requestNotificationsPermission();
  }

  Future<void> _initFcm() async {
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);
      await messaging.setForegroundNotificationPresentationOptions(
        alert: false, badge: true, sound: false,
      );

      FirebaseMessaging.onMessage.listen((msg) {
        final isUrgent = msg.data['type'] == 'urgent_message';
        showLocal(
          title: msg.notification?.title ?? 'Pulse',
          body: msg.notification?.body ?? '',
          data: msg.data,
          urgent: isUrgent,
        );
      });

      FirebaseMessaging.onMessageOpenedApp.listen((msg) {
        onNotificationTap?.call(msg.data);
      });

      final initial = await messaging.getInitialMessage();
      if (initial != null) {
        Future.delayed(const Duration(milliseconds: 500), () {
          onNotificationTap?.call(initial.data);
        });
      }

      messaging.onTokenRefresh.listen(_onTokenRefresh);

      // Hand the current token straight to the app so it can register it.
      final current = await messaging.getToken();
      if (current != null) onTokenRefresh?.call(current);
    } catch (e) {
      debugPrint('FCM init failed: $e');
    }
  }

  Future<String?> getToken() async {
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (e) {
      debugPrint('FCM getToken failed: $e');
      return null;
    }
  }

  void _onTokenRefresh(String token) => onTokenRefresh?.call(token);

  Future<void> showLocal({
    required String title,
    required String body,
    Map<String, dynamic> data = const {},
    bool urgent = false,
    int? id,
  }) async {
    final channelId = urgent ? _urgentChannelId : _channelId;
    final channelName = urgent ? _urgentChannelName : _channelName;

    await _plugin.show(
      id ?? (DateTime.now().millisecondsSinceEpoch & 0x7FFFFFFF),
      urgent ? '🚨 $title' : title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          importance: urgent ? Importance.max : Importance.high,
          priority: urgent ? Priority.max : Priority.high,
          icon: '@mipmap/ic_launcher',
          color: urgent ? const Color.fromARGB(255, 220, 38, 38) : null,
          enableVibration: true,
          fullScreenIntent: urgent,
        ),
      ),
      payload: data.isEmpty ? null : jsonEncode(data),
    );
  }

  void _onLocalTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      onNotificationTap?.call(data);
    } catch (_) {}
  }
}
