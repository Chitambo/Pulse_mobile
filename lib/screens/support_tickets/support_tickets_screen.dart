import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import '../../providers/auth_provider.dart';
import '../../core/database/cache_store.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_constants.dart';
import '../../models/support_ticket.dart';
import '../../widgets/common_widgets.dart';

class SupportTicketsScreen extends StatefulWidget {
  final String? initialStatus;
  final String? initialPriority;
  const SupportTicketsScreen({super.key, this.initialStatus, this.initialPriority});

  @override
  State<SupportTicketsScreen> createState() => _SupportTicketsScreenState();
}

class _SupportTicketsScreenState extends State<SupportTicketsScreen> {
  final _api = ApiClient().dio;
  final _scrollCtrl = ScrollController();

  List<SupportTicket> _tickets = [];
  bool _loading = false;
  bool _hasMore = true;
  int _page = 1;
  String? _statusFilter;
  String? _priorityFilter;
  String? _error;

  @override
  void initState() {
    super.initState();
    _statusFilter = widget.initialStatus;
    _priorityFilter = widget.initialPriority;
    _load(refresh: true);
    _scrollCtrl.addListener(() {
      if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 200) _load();
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({bool refresh = false}) async {
    if (_loading || (!_hasMore && !refresh)) return;
    if (refresh) { _page = 1; _hasMore = true; _tickets = []; }

    if (refresh && _statusFilter == null && _priorityFilter == null) {
      final cacheKey = 'tickets';
      final cached = await CacheStore().getList(cacheKey, page: 1);
      if (cached != null && _tickets.isEmpty && mounted) {
        setState(() => _tickets = cached.map((j) => SupportTicket.fromJson(j as Map<String, dynamic>)).toList());
      }
    }

    setState(() { _loading = true; _error = null; });
    try {
      final res = await _api.get(ApiConstants.supportTickets, queryParameters: {
        'page': _page,
        'limit': 20,
        if (_statusFilter != null) 'status': _statusFilter,
        if (_priorityFilter != null) 'priority': _priorityFilter,
      });
      final data = res.data;
      final items = (data['data'] ?? data as List? ?? []) as List;
      final totalPages = data is Map ? (data['pages'] ?? 1) : 1;
      if (_statusFilter == null && _priorityFilter == null) {
        await CacheStore().saveList('tickets', _page, items);
      }
      final loaded = items.map((j) => SupportTicket.fromJson(j)).toList();
      setState(() {
        if (refresh) _tickets = [];
        _tickets.addAll(loaded);
        _hasMore = _page < totalPages;
        _page++;
      });
    } on DioException catch (e) {
      setState(() => _error = e.response?.data?['message'] ?? 'Error');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canCreate = context.watch<AuthProvider>().user!.let(
      (u) => u.isAdmin || u.isSupport,
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Support Tickets'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (v) {
              final parts = v.split(':');
              setState(() {
                if (parts[0] == 'status') _statusFilter = parts[1].isEmpty ? null : parts[1];
                if (parts[0] == 'priority') _priorityFilter = parts[1].isEmpty ? null : parts[1];
              });
              _load(refresh: true);
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'status:', child: Text('All statuses')),
              ..._statuses.map((s) => PopupMenuItem(value: 'status:$s', child: Text(s))),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'priority:', child: Text('All priorities')),
              ..._priorities.map((p) => PopupMenuItem(value: 'priority:$p', child: Text(p))),
            ],
          ),
        ],
      ),
      floatingActionButton: canCreate
          ? FloatingActionButton(
              onPressed: () => _openCreate(context),
              child: const Icon(Icons.add),
            )
          : null,
      body: _error != null && _tickets.isEmpty
          ? ErrorRetryWidget(message: _error!, onRetry: () => _load(refresh: true))
          : _tickets.isEmpty && _loading
              ? const ShimmerList()
              : RefreshIndicator(
                  onRefresh: () => _load(refresh: true),
                  child: ListView.builder(
                    controller: _scrollCtrl,
                    itemCount: _tickets.length + (_hasMore ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (i == _tickets.length) {
                        return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
                      }
                      final t = _tickets[i];
                      return Card(
                        child: ListTile(
                          title: Text(t.ticketNumber, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(t.issueCategory),
                              Text(t.client?.name ?? 'No client', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                            ],
                          ),
                          isThreeLine: true,
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              StatusChip(label: t.priority),
                              const SizedBox(height: 4),
                              StatusChip(label: t.status),
                            ],
                          ),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => TicketDetailScreen(ticketId: t.id)),
                          ).then((_) => _load(refresh: true)),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  void _openCreate(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateTicketScreen()))
        .then((_) => _load(refresh: true));
  }
}

const _statuses = ['open', 'pending', 'in_progress', 'escalated', 'resolved', 'closed'];
const _priorities = ['low', 'medium', 'high', 'critical'];

class TicketDetailScreen extends StatefulWidget {
  final int ticketId;
  const TicketDetailScreen({super.key, required this.ticketId});

  @override
  State<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<TicketDetailScreen> {
  final _api = ApiClient().dio;
  SupportTicket? _ticket;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _api.get('${ApiConstants.supportTickets}/${widget.ticketId}');
      setState(() { _ticket = SupportTicket.fromJson(res.data); _loading = false; });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: LoadingWidget());
    if (_ticket == null) return Scaffold(appBar: AppBar(), body: const Center(child: Text('Not found')));
    final t = _ticket!;
    final user = context.read<AuthProvider>().user!;

    return Scaffold(
      appBar: AppBar(
        title: Text(t.ticketNumber),
        actions: [
          if (user.isAdmin || user.isSupport)
            IconButton(icon: const Icon(Icons.edit), onPressed: () => _showUpdateSheet(context, t)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    StatusChip(label: t.priority),
                    const SizedBox(width: 8),
                    StatusChip(label: t.status),
                    const Spacer(),
                    if (t.isChargeable) const StatusChip(label: 'Chargeable'),
                  ]),
                  const SizedBox(height: 12),
                  Text(t.issueCategory, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(t.issueDescription),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (t.client != null) InfoRow(icon: Icons.business, label: 'Client', value: t.client!.name),
                  if (t.contactPerson != null) InfoRow(icon: Icons.person, label: 'Contact', value: t.contactPerson!),
                  if (t.assignedOfficer != null) InfoRow(icon: Icons.support_agent, label: 'Officer', value: t.assignedOfficer!.fullName),
                  if (t.assignedDeveloper != null) InfoRow(icon: Icons.code, label: 'Developer', value: t.assignedDeveloper!.fullName),
                  if (t.resolution != null) InfoRow(icon: Icons.check, label: 'Resolution', value: t.resolution!),
                ],
              ),
            ),
          ),
          if (t.updates.isNotEmpty) ...[
            const SectionHeader(title: 'Updates'),
            ...t.updates.map((u) => Card(
              margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (u.status != null) StatusChip(label: u.status!),
                    if (u.comment != null) ...[const SizedBox(height: 6), Text(u.comment!)],
                    const SizedBox(height: 4),
                    Text(u.createdAt, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ),
            )),
          ],
        ],
      ),
    );
  }

  void _showUpdateSheet(BuildContext context, SupportTicket ticket) {
    String? status = ticket.status;
    final commentCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Update Ticket', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: _statuses.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (v) => status = v,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: commentCtrl,
                decoration: const InputDecoration(labelText: 'Comment'),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  try {
                    await _api.put('${ApiConstants.supportTickets}/${ticket.id}', data: {
                      if (status != null) 'status': status,
                      if (commentCtrl.text.isNotEmpty) 'comment': commentCtrl.text,
                    });
                    _load();
                  } catch (_) {}
                },
                child: const Text('Update'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CreateTicketScreen extends StatefulWidget {
  const CreateTicketScreen({super.key});

  @override
  State<CreateTicketScreen> createState() => _CreateTicketScreenState();
}

class _CreateTicketScreenState extends State<CreateTicketScreen> {
  final _formKey = GlobalKey<FormState>();
  final _api = ApiClient().dio;
  final _descCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  String _priority = 'medium';
  bool _loading = false;

  @override
  void dispose() {
    _descCtrl.dispose();
    _categoryCtrl.dispose();
    _contactCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await _api.post(ApiConstants.supportTickets, data: {
        'issueCategory': _categoryCtrl.text.trim(),
        'issueDescription': _descCtrl.text.trim(),
        'priority': _priority,
        if (_contactCtrl.text.isNotEmpty) 'contactPerson': _contactCtrl.text.trim(),
      });
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ticket created'), backgroundColor: Colors.green),
        );
      }
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.response?.data?['message'] ?? 'Error'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('New Ticket')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _categoryCtrl,
                  decoration: const InputDecoration(labelText: 'Issue Category'),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descCtrl,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 4,
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(controller: _contactCtrl, decoration: const InputDecoration(labelText: 'Contact Person')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _priority,
                  decoration: const InputDecoration(labelText: 'Priority'),
                  items: _priorities.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                  onChanged: (v) => setState(() => _priority = v!),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton(onPressed: _submit, child: const Text('Submit Ticket')),
                ),
              ],
            ),
          ),
        ),
      );
}

extension _Let<T> on T {
  R let<R>(R Function(T) block) => block(this);
}
