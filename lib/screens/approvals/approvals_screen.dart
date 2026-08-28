import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_constants.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../../models/approval.dart';
import '../../widgets/common_widgets.dart';

final _zmw = NumberFormat.currency(locale: 'en_ZM', symbol: 'ZMW ', decimalDigits: 2);

class ApprovalsScreen extends StatefulWidget {
  const ApprovalsScreen({super.key});

  @override
  State<ApprovalsScreen> createState() => _ApprovalsScreenState();
}

class _ApprovalsScreenState extends State<ApprovalsScreen> with SingleTickerProviderStateMixin {
  final _api = ApiClient().dio;
  late final TabController _tabs = TabController(length: 2, vsync: this);

  List<ApprovalRequest> _inbox = [];
  List<ApprovalRequest> _mine = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _api.get(ApiConstants.approvals),
        _api.get(ApiConstants.approvalsMine),
      ]);
      List<ApprovalRequest> parse(dynamic d) =>
          (d as List).map((j) => ApprovalRequest.fromJson(j as Map<String, dynamic>)).toList();
      if (!mounted) return;
      setState(() {
        _inbox = parse(results[0].data);
        _mine = parse(results[1].data);
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _act(ApprovalRequest r, String action) async {
    final commentCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(action == 'approve' ? 'Approve request' : 'Reject request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(r.title),
            if (r.amount != null) Text(_zmw.format(r.amount), style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            TextField(
              controller: commentCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: action == 'reject' ? 'Reason (required)' : 'Comment (optional)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: action == 'reject' ? ElevatedButton.styleFrom(backgroundColor: Colors.red) : null,
            child: Text(action == 'approve' ? 'Approve' : 'Reject'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (action == 'reject' && commentCtrl.text.trim().isEmpty) {
      _snack('A comment is required to reject');
      return;
    }

    try {
      final res = await _api.post(ApiConstants.approvalAct(r.id), data: {
        'action': action,
        if (commentCtrl.text.trim().isNotEmpty) 'comment': commentCtrl.text.trim(),
      });
      final resolved = res.data['resolved'] == true;
      _snack(resolved ? 'Request ${res.data['outcome']}' : 'Approved — sent to the next approver');
      if (mounted) context.read<NotificationProvider>().load(refresh: true);
      _load();
    } on DioException catch (e) {
      _snack(e.response?.data?['message'] ?? 'Failed');
    }
  }

  void _snack(String m) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Approvals'),
        bottom: TabBar(
          controller: _tabs,
          labelColor: Colors.white,
          indicatorColor: Colors.white,
          tabs: [
            Tab(text: 'To review (${_inbox.length})'),
            const Tab(text: 'Raised by me'),
          ],
        ),
      ),
      body: _loading
          ? const ShimmerList()
          : RefreshIndicator(
              onRefresh: _load,
              child: TabBarView(
                controller: _tabs,
                children: [
                  _list(_inbox, canAct: true),
                  _list(_mine, canAct: false),
                ],
              ),
            ),
    );
  }

  Widget _list(List<ApprovalRequest> rows, {required bool canAct}) {
    if (rows.isEmpty) {
      return ListView(children: [
        const SizedBox(height: 120),
        EmptyWidget(message: canAct ? 'Nothing waiting for you' : 'You haven’t raised any requests'),
      ]);
    }
    final myRole = context.read<AuthProvider>().user!.role.slug;
    final myId = context.read<AuthProvider>().user!.id;

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: rows.length,
      itemBuilder: (_, i) {
        final r = rows[i];
        final step = r.current;
        final actable = canAct &&
            r.status == 'pending' &&
            step != null &&
            step.requiredRole == myRole &&
            r.requestedById != myId;

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(r.title, style: const TextStyle(fontWeight: FontWeight.bold))),
                    if (r.amount != null)
                      Text(_zmw.format(r.amount), style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (final s in r.steps)
                      _StepChip(
                        role: s.requiredRole,
                        state: s.status == 'pending' && s.sequence == r.currentStep ? 'current' : s.status,
                      ),
                    _StatusPill(r.status),
                  ],
                ),
                if (r.requestedByName != null) ...[
                  const SizedBox(height: 6),
                  Text('Requested by ${r.requestedByName}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
                if (actable) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(onPressed: () => _act(r, 'reject'), child: const Text('Reject')),
                      const SizedBox(width: 8),
                      ElevatedButton(onPressed: () => _act(r, 'approve'), child: const Text('Approve')),
                    ],
                  ),
                ] else if (canAct && r.status == 'pending') ...[
                  const SizedBox(height: 4),
                  Text('Awaiting ${step?.requiredRole ?? '—'}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StepChip extends StatelessWidget {
  final String role;
  final String state; // approved | rejected | current | pending | skipped
  const _StepChip({required this.role, required this.state});

  @override
  Widget build(BuildContext context) {
    late Color c;
    String suffix = '';
    switch (state) {
      case 'approved':
        c = Colors.green;
        suffix = ' ✓';
        break;
      case 'rejected':
        c = Colors.red;
        suffix = ' ✗';
        break;
      case 'current':
        c = Colors.orange;
        break;
      default:
        c = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
      child: Text('$role$suffix', style: TextStyle(fontSize: 11, color: c, fontWeight: FontWeight.w600)),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String status;
  const _StatusPill(this.status);

  @override
  Widget build(BuildContext context) {
    final c = {
      'approved': Colors.green,
      'rejected': Colors.red,
      'cancelled': Colors.grey,
    }[status] ?? Colors.blue;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
      child: Text(status, style: TextStyle(fontSize: 11, color: c, fontWeight: FontWeight.w600)),
    );
  }
}
