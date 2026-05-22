import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/api/api_client.dart';
import 'core/api/api_constants.dart';
import 'core/auth/token_storage.dart';
import 'core/notifications/push_notification_service.dart';
import 'core/socket/socket_service.dart';
import 'core/theme/app_theme.dart';
import 'models/chat.dart';
import 'providers/auth_provider.dart';
import 'providers/notification_provider.dart';
import 'screens/auth/change_password_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/chat/chat_list_screen.dart';
import 'screens/chat/chat_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/notifications/notifications_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/tasks/tasks_screen.dart';

class PulseApp extends StatelessWidget {
  const PulseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ],
      child: MaterialApp(
        title: 'Pulse',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.theme,
        home: const _AuthGate(),
      ),
    );
  }
}

class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  bool _sessionStarted = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        switch (auth.status) {
          case AuthStatus.unknown:
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );

          case AuthStatus.unauthenticated:
            if (_sessionStarted) {
              _sessionStarted = false;
              SocketService().disconnect();
            }
            return const LoginScreen();

          case AuthStatus.authenticated:
            final user = auth.user!;

            if (!_sessionStarted) {
              _sessionStarted = true;
              // Wire up socket and notifications after first authenticated frame.
              WidgetsBinding.instance.addPostFrameCallback((_) async {
                final token = await _readToken();
                if (token != null) SocketService().connect(token);

                final np = context.read<NotificationProvider>();
                np.load(refresh: true);
                np.loadChatUnread();

                PushNotificationService().onTokenRefresh = (fcmToken) {
                  ApiClient().dio.post(ApiConstants.deviceToken,
                      data: {'token': fcmToken}).catchError((_) => null);
                };
              });
            }

            if (user.mustChangePassword) {
              return const ChangePasswordScreen(forced: true);
            }

            return _MainShell(userId: user.id, username: user.username);
        }
      },
    );
  }

  Future<String?> _readToken() => TokenStorage.getToken();
}

// ── Main shell ────────────────────────────────────────────────────────────────

class _MainShell extends StatefulWidget {
  final int userId;
  final String username;

  const _MainShell({required this.userId, required this.username});

  @override
  State<_MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<_MainShell> {
  int _tab = 0;

  // Chat sub-navigation
  ChatChannel? _activeChannel;

  @override
  Widget build(BuildContext context) {
    final np = context.watch<NotificationProvider>();
    final dio = ApiClient().dio;

    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          // 0 — Dashboard
          const DashboardScreen(),

          // 1 — Chat
          _activeChannel == null
              ? ChatListScreen(
                  dio: dio,
                  myUserId: widget.userId,
                  onChannelTap: (ch) => setState(() => _activeChannel = ch),
                )
              : WillPopScope(
                  onWillPop: () async {
                    setState(() => _activeChannel = null);
                    return false;
                  },
                  child: ChatScreen(
                    channel: _activeChannel!,
                    dio: dio,
                    myUserId: widget.userId,
                    myUsername: widget.username,
                    socket: SocketService(),
                  ),
                ),

          // 2 — Tasks (new)
          TasksScreen(dio: dio, myUserId: widget.userId),

          // 3 — Notifications
          const NotificationsScreen(),

          // 4 — Profile
          const ProfileScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tab,
        onTap: (i) {
          if (i == 1 && _tab == 1 && _activeChannel != null) {
            setState(() => _activeChannel = null);
            return;
          }
          setState(() => _tab = i);
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppTheme.primary,
        unselectedItemColor: Colors.grey,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: _badge(Icons.chat_bubble_outline, np.chatUnreadCount),
            activeIcon: _badge(Icons.chat_bubble, np.chatUnreadCount),
            label: 'Chat',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.task_alt_outlined),
            activeIcon: Icon(Icons.task_alt),
            label: 'Tasks',
          ),
          BottomNavigationBarItem(
            icon: _badge(Icons.notifications_outlined, np.unreadCount),
            activeIcon: _badge(Icons.notifications, np.unreadCount),
            label: 'Alerts',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _badge(IconData icon, int count) {
    if (count == 0) return Icon(icon);
    return Badge(
      label: Text(count > 99 ? '99+' : '$count'),
      child: Icon(icon),
    );
  }
}
