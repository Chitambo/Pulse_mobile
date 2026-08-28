import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import '../../providers/auth_provider.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_constants.dart';
import '../../core/database/cache_store.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/common_widgets.dart';
import '../support_tickets/support_tickets_screen.dart';
import '../development_tasks/development_tasks_screen.dart';
import '../invoices/invoices_screen.dart';
import '../sales_leads/sales_leads_screen.dart';
import '../daily_activities/daily_activities_screen.dart';
import '../weekly_summaries/weekly_summaries_screen.dart';
import '../approvals/approvals_screen.dart';
import '../expenses/expenses_screen.dart';
import '../quotations/quotations_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _api = ApiClient().dio;
  Map<String, dynamic>? _myData;
  Map<String, dynamic>? _roleData;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cache = CacheStore();
    final user = context.read<AuthProvider>().user!;

    // Show cached data immediately — never block the UI on the network.
    try {
      final cachedMy = await cache.getItem('dashboard_my', 0);
      final cachedRole = await cache.getItem('dashboard_role', 0);
      if (cachedMy != null && mounted) {
        setState(() {
          _myData = cachedMy;
          if (cachedRole != null) _roleData = cachedRole;
          _loading = false;
        });
      } else if (mounted) {
        setState(() { _loading = true; _error = null; });
      }
    } catch (_) {
      if (mounted) setState(() { _loading = true; _error = null; });
    }

    try {
      final futures = [_api.get(ApiConstants.dashboardMy)];
      if (user.isAdmin || user.isCeo) {
        futures.add(_api.get(ApiConstants.dashboardCeo));
      } else if (user.isSupport) {
        futures.add(_api.get(ApiConstants.dashboardSupport));
      } else if (user.isDeveloper) {
        futures.add(_api.get(ApiConstants.dashboardDeveloper));
      }

      final results = await Future.wait(futures);
      final myData = Map<String, dynamic>.from(results[0].data as Map);
      final roleData = results.length > 1 ? Map<String, dynamic>.from(results[1].data as Map) : null;

      await Future.wait([
        cache.saveItem('dashboard_my', 0, myData),
        if (roleData != null) cache.saveItem('dashboard_role', 0, roleData),
      ]);

      if (mounted) setState(() { _myData = myData; _roleData = roleData; _error = null; });
    } on DioException catch (e) {
      if (mounted && _myData == null) {
        setState(() => _error = e.response?.data?['message'] ?? 'Failed to load dashboard');
      }
    } catch (_) {
      if (mounted && _myData == null) {
        setState(() => _error = 'Failed to load dashboard');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user!;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Dashboard'),
            Text('Welcome, ${user.employee?.fullName ?? user.username}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Approvals',
            icon: const Icon(Icons.fact_check_outlined),
            onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const ApprovalsScreen())),
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const LoadingWidget()
          : _error != null
              ? ErrorRetryWidget(message: _error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (_myData != null) _MyDashboard(data: _myData!),
                      const SizedBox(height: 8),
                      _QuickLinks(user: user),
                      if (_roleData != null) ...[
                        const SizedBox(height: 16),
                        if (user.isAdmin || user.isCeo) _CeoDashboard(data: _roleData!),
                        if (user.isSupport) _SupportDashboard(data: _roleData!),
                        if (user.isDeveloper) _DevDashboard(data: _roleData!),
                      ],
                    ],
                  ),
                ),
    );
  }
}

// ─── Quick links ──────────────────────────────────────────────────────────────

class _QuickLinks extends StatelessWidget {
  final dynamic user;
  const _QuickLinks({required this.user});

  @override
  Widget build(BuildContext context) {
    final finance = user.isAdmin || user.isAccounts;
    void go(Widget s) => Navigator.push(context, MaterialPageRoute(builder: (_) => s));

    final chips = <Widget>[
      ActionChip(
        avatar: const Icon(Icons.fact_check_outlined, size: 18),
        label: const Text('Approvals'),
        onPressed: () => go(const ApprovalsScreen()),
      ),
      ActionChip(
        avatar: const Icon(Icons.receipt_long_outlined, size: 18),
        label: const Text('Expenses'),
        onPressed: () => go(const ExpensesScreen()),
      ),
      if (finance)
        ActionChip(
          avatar: const Icon(Icons.request_quote_outlined, size: 18),
          label: const Text('Quotations'),
          onPressed: () => go(const QuotationsScreen()),
        ),
    ];

    return Wrap(spacing: 8, runSpacing: 8, children: chips);
  }
}

// ─── My Dashboard ──────────────────────────────────────────────────────────────

class _MyDashboard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _MyDashboard({required this.data});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'My Overview'),
          Row(
            children: [
              Expanded(child: _KpiCard(
                'Daily Report',
                data['todayReported'] == true ? 'Submitted' : 'Not yet',
                Icons.today,
                data['todayReported'] == true ? Colors.green : Colors.red,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DailyActivitiesScreen())),
              )),
              const SizedBox(width: 8),
              Expanded(child: _KpiCard(
                'This Week',
                '${data['weekActivities'] ?? 0}',
                Icons.date_range_outlined,
                Colors.green,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DailyActivitiesScreen())),
              )),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _KpiCard(
                'Pending Tasks',
                '${data['pendingTasks'] ?? 0}',
                Icons.pending_actions,
                Colors.orange,
                onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => const DevelopmentTasksScreen(initialStatus: 'pending'),
                )),
              )),
              const SizedBox(width: 8),
              Expanded(child: _KpiCard(
                'Weekly Report',
                data['weeklySubmitted'] == true ? 'Submitted' : 'Pending',
                Icons.assignment,
                data['weeklySubmitted'] == true ? Colors.green : Colors.red,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WeeklySummariesScreen())),
              )),
            ],
          ),
        ],
      );
}

// ─── CEO Dashboard ─────────────────────────────────────────────────────────────

class _CeoDashboard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _CeoDashboard({required this.data});

  @override
  Widget build(BuildContext context) {
    final tickets = data['tickets'] ?? {};
    final revenue = data['revenue'] ?? {};
    final leads = data['leads'] ?? {};
    final tasks = data['tasks'] ?? {};
    final recentTickets = data['recentTickets'] as List? ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Operations Overview'),
        _ResponsiveGrid(children: [
          _KpiCard('Open Tickets', '${tickets['open'] ?? 0}', Icons.support_agent, Colors.orange,
              onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => const SupportTicketsScreen(initialStatus: 'open'),
              ))),
          _KpiCard('Critical', '${tickets['critical'] ?? 0}', Icons.warning, Colors.red,
              onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => const SupportTicketsScreen(initialPriority: 'critical'),
              ))),
          _KpiCard('Revenue (ZMW)', _fmt(revenue['totalInvoiced']), Icons.payments, Colors.green,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InvoicesScreen()))),
          _KpiCard('Outstanding', _fmt(revenue['outstanding']), Icons.account_balance, Colors.blue,
              onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => const InvoicesScreen(initialStatus: 'unpaid'),
              ))),
          _KpiCard('Active Leads', '${leads['active'] ?? 0}', Icons.trending_up, Colors.purple,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SalesLeadsScreen()))),
          _KpiCard('Tasks Overdue', '${tasks['overdue'] ?? 0}', Icons.schedule, Colors.red,
              onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => const DevelopmentTasksScreen(initialStatus: 'overdue'),
              ))),
        ]),
        if (recentTickets.isNotEmpty) ...[
          _SectionHeaderWithAction(
            title: 'Recent Tickets',
            actionLabel: 'View All',
            onAction: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupportTicketsScreen())),
          ),
          ...recentTickets.take(3).map((t) => _TicketTile(t)),
        ],
      ],
    );
  }

  String _fmt(dynamic v) {
    if (v == null) return '0';
    final d = double.tryParse(v.toString()) ?? 0;
    if (d >= 1000000) return '${(d / 1000000).toStringAsFixed(1)}M';
    if (d >= 1000) return '${(d / 1000).toStringAsFixed(1)}K';
    return d.toStringAsFixed(0);
  }
}

// ─── Support Dashboard ─────────────────────────────────────────────────────────

class _SupportDashboard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _SupportDashboard({required this.data});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Support Overview'),
          Row(
            children: [
              Expanded(child: _KpiCard('Open', '${data['open'] ?? 0}', Icons.inbox, Colors.orange,
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const SupportTicketsScreen(initialStatus: 'open'),
                  )))),
              const SizedBox(width: 8),
              Expanded(child: _KpiCard('Resolved', '${data['resolved'] ?? 0}', Icons.check_circle, Colors.green,
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const SupportTicketsScreen(initialStatus: 'resolved'),
                  )))),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _KpiCard('Critical', '${data['critical'] ?? 0}', Icons.warning, Colors.red,
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => const SupportTicketsScreen(initialPriority: 'critical'),
                  )))),
              const SizedBox(width: 8),
              Expanded(child: _KpiCard('Chargeable', '${data['chargeable'] ?? 0}', Icons.attach_money, Colors.blue,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SupportTicketsScreen())))),
            ],
          ),
        ],
      );
}

// ─── Dev Dashboard ─────────────────────────────────────────────────────────────

class _DevDashboard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _DevDashboard({required this.data});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Dev Overview'),
          _ResponsiveGrid(children: [
            _KpiCard('Assigned', '${data['assigned'] ?? 0}', Icons.assignment_ind, Colors.blue,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DevelopmentTasksScreen()))),
            _KpiCard('In Progress', '${data['inProgress'] ?? 0}', Icons.autorenew, Colors.orange,
                onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => const DevelopmentTasksScreen(initialStatus: 'in_progress'),
                ))),
            _KpiCard('Completed', '${data['completed'] ?? 0}', Icons.check_circle, Colors.green,
                onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => const DevelopmentTasksScreen(initialStatus: 'completed'),
                ))),
            _KpiCard('Overdue', '${data['overdue'] ?? 0}', Icons.schedule, Colors.red,
                onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => const DevelopmentTasksScreen(initialStatus: 'overdue'),
                ))),
          ]),
        ],
      );
}

// ─── Reusable widgets ──────────────────────────────────────────────────────────

class _ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  const _ResponsiveGrid({required this.children});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final cols = width >= 600 ? 3 : 2;
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += cols) {
      final rowChildren = <Widget>[];
      for (var j = i; j < i + cols && j < children.length; j++) {
        if (rowChildren.isNotEmpty) rowChildren.add(const SizedBox(width: 8));
        rowChildren.add(Expanded(child: children[j]));
      }
      if (i > 0) rows.add(const SizedBox(height: 8));
      rows.add(Row(children: rowChildren));
    }
    return Column(children: rows);
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _KpiCard(this.title, this.value, this.icon, this.color, {this.onTap});

  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey), maxLines: 2),
                    ],
                  ),
                ),
                if (onTap != null)
                  Icon(Icons.chevron_right, color: Colors.grey[400], size: 18),
              ],
            ),
          ),
        ),
      );
}

class _TicketTile extends StatelessWidget {
  final Map<String, dynamic> ticket;
  const _TicketTile(this.ticket);

  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            final id = ticket['id'];
            if (id != null) {
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => TicketDetailScreen(ticketId: id is int ? id : int.parse(id.toString())),
              ));
            }
          },
          child: ListTile(
            leading: const Icon(Icons.support_agent),
            title: Text(ticket['issueCategory'] ?? 'Ticket', overflow: TextOverflow.ellipsis),
            subtitle: Text(ticket['client']?['name'] ?? ''),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                StatusChip(label: ticket['status'] ?? 'open'),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right, color: Colors.grey[400], size: 18),
              ],
            ),
          ),
        ),
      );
}

class _SectionHeaderWithAction extends StatelessWidget {
  final String title;
  final String actionLabel;
  final VoidCallback onAction;
  const _SectionHeaderWithAction({required this.title, required this.actionLabel, required this.onAction});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Row(
          children: [
            Text(title,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primary)),
            const Spacer(),
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              child: Text(actionLabel, style: const TextStyle(fontSize: 13)),
            ),
          ],
        ),
      );
}
