import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

import 'core/api/api_constants.dart';
import 'core/socket/socket_service.dart';
import 'core/notifications/push_notification_service.dart';
import 'screens/chat/chat_list_screen.dart';
import 'screens/chat/chat_screen.dart';
import 'screens/tasks/tasks_screen.dart';
import 'models/chat.dart';

/// Drop-in replacement for app.dart / main app widget.
///
/// Integration notes:
///  1. Replace your existing root widget with PulseApp (or merge the routing
///     into your existing MaterialApp).
///  2. Pass your authenticated Dio instance and myUserId/myUsername once the
///     user has logged in — you can keep your existing auth flow and just call
///     PulseApp.of(context).setSession(...) after login.
///  3. The SocketService and PushNotificationService singletons are initialised
///     here so their lifecycle matches the logged-in session.
///
/// New things vs the old app.dart:
///  - Tasks bottom-nav tab with TasksScreen
///  - PushNotificationService.onNotificationTap routes taps correctly for all
///    payload types: regular message, urgent_message, task_assigned,
///    message_assigned, reminder_due
///  - SocketService is disconnected on logout / session teardown

class PulseApp extends StatefulWidget {
  final String? initialToken;
  final int? initialUserId;
  final String? initialUsername;

  const PulseApp({
    Key? key,
    this.initialToken,
    this.initialUserId,
    this.initialUsername,
  }) : super(key: key);

  @override
  State<PulseApp> createState() => PulseAppState();

  static PulseAppState of(BuildContext context) =>
      context.findAncestorStateOfType<PulseAppState>()!;
}

class PulseAppState extends State<PulseApp> {
  String? _token;
  int? _userId;
  String? _username;
  Dio? _dio;

  // Navigation
  int _tabIndex = 0;
  ChatChannel? _pendingChannel;

  // For navigating after a notification tap
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    if (widget.initialToken != null) {
      _startSession(
        token: widget.initialToken!,
        userId: widget.initialUserId!,
        username: widget.initialUsername ?? '',
      );
    }
    PushNotificationService().onNotificationTap = _handleNotificationTap;
    PushNotificationService().init();
  }

  // Call this after login
  void setSession({
    required String token,
    required int userId,
    required String username,
  }) {
    _startSession(token: token, userId: userId, username: username);
  }

  void _startSession({
    required String token,
    required int userId,
    required String username,
  }) {
    setState(() {
      _token = token;
      _userId = userId;
      _username = username;
      _dio = _buildDio(token);
    });
    SocketService().connect(token);
    _registerDeviceToken();
  }

  // Call this on logout
  void clearSession() {
    SocketService().disconnect();
    setState(() {
      _token = null;
      _userId = null;
      _username = null;
      _dio = null;
    });
  }

  Dio _buildDio(String token) {
    final dio = Dio(BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      headers: {'Authorization': 'Bearer $token'},
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
    ));
    // Refresh token interceptor can be added here if needed
    return dio;
  }

  Future<void> _registerDeviceToken() async {
    if (_dio == null) return;
    final fcmToken = await PushNotificationService().getToken();
    if (fcmToken == null) return;
    try {
      await _dio!.post(ApiConstants.deviceToken, data: {'token': fcmToken});
    } catch (_) {}
    PushNotificationService().onTokenRefresh = (newToken) async {
      try {
        await _dio!.post(ApiConstants.deviceToken, data: {'token': newToken});
      } catch (_) {}
    };
  }

  void _handleNotificationTap(Map<String, dynamic> data) {
    final type = data['type'] as String? ?? 'message';
    switch (type) {
      case 'urgent_message':
      case 'message':
        // Navigate to the relevant channel
        final channelId = data['channelId'];
        if (channelId != null) {
          _openChannel(channelId is int ? channelId : int.tryParse('$channelId') ?? 0);
        }
        break;

      case 'task_assigned':
        // Switch to Tasks tab
        setState(() => _tabIndex = 2);
        break;

      case 'message_assigned':
        final chId = data['channelId'];
        if (chId != null) {
          _openChannel(chId is int ? chId : int.tryParse('$chId') ?? 0);
        }
        break;

      case 'reminder_due':
        final mChId = data['channelId'];
        if (mChId != null) {
          _openChannel(mChId is int ? mChId : int.tryParse('$mChId') ?? 0);
        } else {
          // Fallback: go to tasks tab
          setState(() => _tabIndex = 2);
        }
        break;

      default:
        setState(() => _tabIndex = 1);
    }
  }

  Future<void> _openChannel(int channelId) async {
    if (_dio == null) return;
    try {
      final res = await _dio!.get('${ApiConstants.chatChannels}/$channelId');
      final channel = ChatChannel.fromJson(res.data);
      if (!mounted) return;
      setState(() { _tabIndex = 1; _pendingChannel = channel; });
    } catch (_) {
      // Just switch to chat tab
      setState(() => _tabIndex = 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_token == null || _dio == null || _userId == null) {
      // Return your existing login screen here
      return const MaterialApp(
        home: Scaffold(body: Center(child: Text('Please log in'))),
      );
    }

    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'Pulse',
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
      ),
      home: _MainShell(
        dio: _dio!,
        myUserId: _userId!,
        myUsername: _username ?? '',
        tabIndex: _tabIndex,
        pendingChannel: _pendingChannel,
        onTabChanged: (i) => setState(() => _tabIndex = i),
        onPendingChannelConsumed: () => setState(() => _pendingChannel = null),
      ),
    );
  }
}

// ── Main shell with bottom navigation ────────────────────────────────────────

class _MainShell extends StatefulWidget {
  final Dio dio;
  final int myUserId;
  final String myUsername;
  final int tabIndex;
  final ChatChannel? pendingChannel;
  final void Function(int) onTabChanged;
  final VoidCallback onPendingChannelConsumed;

  const _MainShell({
    required this.dio,
    required this.myUserId,
    required this.myUsername,
    required this.tabIndex,
    required this.pendingChannel,
    required this.onTabChanged,
    required this.onPendingChannelConsumed,
  });

  @override
  State<_MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<_MainShell> {
  // Chat sub-navigation stack
  ChatChannel? _activeChannel;

  @override
  void didUpdateWidget(_MainShell old) {
    super.didUpdateWidget(old);
    // If a pending channel arrived from a notification tap, open it
    if (widget.pendingChannel != null &&
        widget.pendingChannel != old.pendingChannel) {
      _activeChannel = widget.pendingChannel;
      widget.onPendingChannelConsumed();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: widget.tabIndex,
        children: [
          // Tab 0 — Dashboard / Home (keep your existing widget here)
          const _PlaceholderTab(label: 'Dashboard'),

          // Tab 1 — Messages
          _activeChannel == null
              ? ChatListScreen(
                  dio: widget.dio,
                  myUserId: widget.myUserId,
                  onChannelTap: (ch) => setState(() => _activeChannel = ch),
                )
              : WillPopScope(
                  onWillPop: () async {
                    setState(() => _activeChannel = null);
                    return false;
                  },
                  child: ChatScreen(
                    channel: _activeChannel!,
                    dio: widget.dio,
                    myUserId: widget.myUserId,
                    myUsername: widget.myUsername,
                    socket: SocketService(),
                  ),
                ),

          // Tab 2 — Tasks (NEW)
          TasksScreen(
            dio: widget.dio,
            myUserId: widget.myUserId,
          ),

          // Tab 3 — Profile / Settings (keep your existing widget here)
          const _PlaceholderTab(label: 'Profile'),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: widget.tabIndex,
        onTap: (i) {
          if (i == 1 && widget.tabIndex == 1 && _activeChannel != null) {
            // Tapping Messages while in a channel goes back to channel list
            setState(() => _activeChannel = null);
            return;
          }
          widget.onTabChanged(i);
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.indigo,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: 'Messages'),
          BottomNavigationBarItem(icon: Icon(Icons.task_alt_outlined), label: 'Tasks'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }
}

class _PlaceholderTab extends StatelessWidget {
  final String label;
  const _PlaceholderTab({required this.label});

  @override
  Widget build(BuildContext context) =>
      Center(child: Text(label, style: const TextStyle(fontSize: 16, color: Colors.grey)));
}
