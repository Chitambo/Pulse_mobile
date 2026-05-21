import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:badges/badges.dart' as badges;
import 'core/theme/app_theme.dart';
import 'core/notifications/push_notification_service.dart';
import 'providers/auth_provider.dart';
import 'providers/notification_provider.dart';
import 'models/user.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/change_password_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/chat/chat_list_screen.dart';
import 'screens/notifications/notifications_screen.dart';
import 'screens/employees/employees_screen.dart';
import 'screens/clients/clients_screen.dart';
import 'screens/support_tickets/support_tickets_screen.dart';
import 'screens/development_tasks/development_tasks_screen.dart';
import 'screens/daily_activities/daily_activities_screen.dart';
import 'screens/weekly_summaries/weekly_summaries_screen.dart';
import 'screens/documents/documents_screen.dart';
import 'screens/invoices/invoices_screen.dart';
import 'screens/sales_leads/sales_leads_screen.dart';
import 'screens/kpi/kpi_screen.dart';
import 'screens/profile/profile_screen.dart';

// Global key used by PushNotificationService to navigate without BuildContext.
final navigatorKey = GlobalKey<NavigatorState>();

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
        navigatorKey: navigatorKey,
        home: const _RootNavigator(),
      ),
    );
  }
}

class _RootNavigator extends StatelessWidget {
  const _RootNavigator();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return switch (auth.status) {
      AuthStatus.unknown => const Scaffold(body: Center(child: CircularProgressIndicator())),
      AuthStatus.unauthenticated => const LoginScreen(),
      AuthStatus.authenticated => auth.user!.mustChangePassword
          ? const ChangePasswordScreen(forced: true)
          : const _MainShell(),
    };
  }
}

// ─── Main shell ────────────────────────────────────────────────────────────────

class _MainShell extends StatefulWidget {
  const _MainShell();

  @override
  State<_MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<_MainShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final np = context.read<NotificationProvider>();
      np.load(refresh: true);
      np.loadChatUnread();
      _registerFcmToken();
      _setupNotificationTapHandler();
    });
  }

  Future<void> _registerFcmToken() async {
    final notifService = PushNotificationService();
    final token = await notifService.getToken();
    if (token != null && mounted) {
      final platform = 'android';
      context.read<AuthProvider>().registerFcmToken(token, platform);
    }
    // Re-register when token rotates
    notifService.onTokenRefresh = (token) {
      if (mounted) context.read<AuthProvider>().registerFcmToken(token, 'android');
    };
  }

  void _setupNotificationTapHandler() {
    PushNotificationService().onNotificationTap = (data) {
      final nav = navigatorKey.currentState;
      if (nav == null) return;
      final type = data['type'] as String? ?? '';
      final entityId = int.tryParse(data['entityId']?.toString() ?? '');

      switch (type) {
        case 'chat':
          nav.push(MaterialPageRoute(builder: (_) => const ChatListScreen()));
        case 'ticket':
          if (entityId != null) {
            nav.push(MaterialPageRoute(
                builder: (_) => TicketDetailScreen(ticketId: entityId)));
          } else {
            nav.push(MaterialPageRoute(builder: (_) => const SupportTicketsScreen()));
          }
        case 'task':
          nav.push(MaterialPageRoute(builder: (_) => const DevelopmentTasksScreen()));
        case 'invoice':
          nav.push(MaterialPageRoute(builder: (_) => const InvoicesScreen()));
        case 'lead':
          nav.push(MaterialPageRoute(builder: (_) => const SalesLeadsScreen()));
        default:
          nav.push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
      }
    };
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user!;
    final notifCount = context.watch<NotificationProvider>().unreadCount;
    final tabs = _buildTabs(user);

    // clamp index in case role changes number of tabs
    final safeIndex = _index.clamp(0, tabs.length - 1);

    final chatUnread = context.watch<NotificationProvider>().chatUnreadCount;

    return Scaffold(
      body: IndexedStack(
        index: safeIndex,
        children: tabs.map((t) => t.screen).toList(),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: safeIndex,
        onTap: (i) => setState(() => _index = i),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppTheme.primary,
        unselectedItemColor: Colors.grey,
        items: tabs.map((t) {
          final isNotif = t.label == 'Alerts';
          final isChat = t.label == 'Chat';
          final badgeCount = isNotif ? notifCount : (isChat ? chatUnread : 0);
          return BottomNavigationBarItem(
            icon: badgeCount > 0
                ? badges.Badge(
                    badgeContent: Text(
                      badgeCount > 99 ? '99+' : '$badgeCount',
                      style: const TextStyle(color: Colors.white, fontSize: 9),
                    ),
                    child: Icon(t.icon),
                  )
                : Icon(t.icon),
            label: t.label,
          );
        }).toList(),
      ),
    );
  }

  List<_Tab> _buildTabs(AuthUser user) {
    final role = user.role.slug;
    final isAdmin = role == 'ceo' || role == 'admin';
    final isSupport = role == 'support_officer';
    final isDev = role == 'developer';
    final isAccounts = role == 'accounts';

    return [
      const _Tab('Home', Icons.dashboard_outlined, DashboardScreen()),
      const _Tab('Chat', Icons.chat_bubble_outline, ChatListScreen()),
      const _Tab('Alerts', Icons.notifications_outlined, NotificationsScreen()),
      _Tab(
        'Work',
        _workIcon(role),
        _workScreen(isAdmin, isSupport, isDev, isAccounts),
      ),
      _Tab('More', Icons.grid_view_rounded, _MoreScreen(user: user)),
    ];
  }

  IconData _workIcon(String role) {
    if (role == 'developer') return Icons.code;
    if (role == 'accounts') return Icons.receipt_long;
    return Icons.support_agent;
  }

  Widget _workScreen(bool isAdmin, bool isSupport, bool isDev, bool isAccounts) {
    if (isDev) return const DevelopmentTasksScreen();
    if (isAccounts) return const InvoicesScreen();
    return const SupportTicketsScreen();
  }
}

class _Tab {
  final String label;
  final IconData icon;
  final Widget screen;
  const _Tab(this.label, this.icon, this.screen);
}

// ─── More screen ───────────────────────────────────────────────────────────────

class _MoreScreen extends StatelessWidget {
  final AuthUser user;
  const _MoreScreen({required this.user});

  @override
  Widget build(BuildContext context) {
    final role = user.role.slug;
    final isAdmin = role == 'ceo' || role == 'admin';
    final isSupport = role == 'support_officer';
    final isDev = role == 'developer';
    final isAccounts = role == 'accounts';

    final items = <_MoreItem>[
      if (isAdmin || isSupport || isDev)
        _MoreItem('Employees', Icons.people, Colors.indigo,
            const EmployeesScreen()),
      if (isAdmin || isSupport)
        _MoreItem('Clients', Icons.business, Colors.teal,
            const ClientsScreen()),
      if (isAdmin || isSupport)
        _MoreItem('Support Tickets', Icons.support_agent, Colors.orange,
            const SupportTicketsScreen()),
      if (isAdmin || isDev)
        _MoreItem('Dev Tasks', Icons.code, Colors.blue,
            const DevelopmentTasksScreen()),
      if (isAdmin || isAccounts)
        _MoreItem('Invoices', Icons.receipt_long, Colors.green,
            const InvoicesScreen()),
      if (isAdmin || isSupport)
        _MoreItem('Sales Leads', Icons.trending_up, Colors.purple,
            const SalesLeadsScreen()),
      _MoreItem('Daily Activities', Icons.today, Colors.cyan,
          const DailyActivitiesScreen()),
      _MoreItem('Weekly Reports', Icons.assignment, Colors.deepOrange,
          const WeeklySummariesScreen()),
      _MoreItem('Documents', Icons.folder_outlined, Colors.brown,
          const DocumentsScreen()),
      _MoreItem('KPI', Icons.bar_chart, Colors.pink,
          const KpiScreen()),
      _MoreItem('Profile', Icons.person_outline, Colors.grey,
          const ProfileScreen()),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.9,
        ),
        itemCount: items.length,
        itemBuilder: (_, i) => _MoreTile(item: items[i]),
      ),
    );
  }
}

class _MoreItem {
  final String label;
  final IconData icon;
  final Color color;
  final Widget screen;
  const _MoreItem(this.label, this.icon, this.color, this.screen);
}

class _MoreTile extends StatelessWidget {
  final _MoreItem item;
  const _MoreTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => item.screen),
      ),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: item.color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: item.color.withValues(alpha: 0.2)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: item.color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(item.icon, color: item.color, size: 26),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                item.label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: item.color.withValues(alpha: 0.9),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
