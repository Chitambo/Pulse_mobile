import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_constants.dart';
import '../../core/database/cache_store.dart';
import '../../models/weekly_summary.dart';
import '../../widgets/common_widgets.dart';

class WeeklySummariesScreen extends StatefulWidget {
  const WeeklySummariesScreen({super.key});

  @override
  State<WeeklySummariesScreen> createState() => _WeeklySummariesScreenState();
}

class _WeeklySummariesScreenState extends State<WeeklySummariesScreen> {
  final _api = ApiClient().dio;
  List<WeeklySummary> _summaries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cached = await CacheStore().getList('weekly_summaries', page: 1);
    if (cached != null && mounted) {
      setState(() {
        _summaries = cached.map((j) => WeeklySummary.fromJson(j as Map<String, dynamic>)).toList();
        _loading = false;
      });
    } else {
      setState(() => _loading = true);
    }
    try {
      final res = await _api.get(ApiConstants.weeklySummaries);
      final items = res.data is List ? res.data as List : (res.data['data'] ?? []) as List;
      await CacheStore().saveList('weekly_summaries', 1, items);
      setState(() => _summaries = items.map((j) => WeeklySummary.fromJson(j)).toList());
    } catch (_) {} finally {
      setState(() => _loading = false);
    }
  }

  String _thisWeekEnding() {
    final now = DateTime.now();
    final friday = now.add(Duration(days: 5 - now.weekday));
    return DateFormat('yyyy-MM-dd').format(friday);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Weekly Summaries')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => WeeklySummaryFormScreen(weekEnding: _thisWeekEnding())))
            .then((_) => _load()),
        icon: const Icon(Icons.edit),
        label: const Text('This Week\'s Report'),
      ),
      body: _loading
          ? const ShimmerList()
          : _summaries.isEmpty
              ? const EmptyWidget(message: 'No weekly reports yet', icon: Icons.assignment_outlined)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _summaries.length,
                    itemBuilder: (_, i) {
                      final s = _summaries[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: const CircleAvatar(child: Icon(Icons.calendar_today)),
                          title: Text('Week ending ${s.weekEnding}',
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: s.supervisorComments != null
                              ? Text('Reviewed', style: TextStyle(color: Colors.green[700]))
                              : const Text('Pending review'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) => WeeklySummaryFormScreen(
                                weekEnding: s.weekEnding,
                                existing: s,
                              ))).then((_) => _load()),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

class WeeklySummaryFormScreen extends StatefulWidget {
  final String weekEnding;
  final WeeklySummary? existing;
  const WeeklySummaryFormScreen({super.key, required this.weekEnding, this.existing});

  @override
  State<WeeklySummaryFormScreen> createState() => _WeeklySummaryFormScreenState();
}

class _WeeklySummaryFormScreenState extends State<WeeklySummaryFormScreen> {
  final _api = ApiClient().dio;
  late final _completedCtrl = TextEditingController(text: widget.existing?.completedTasks ?? '');
  late final _pendingCtrl = TextEditingController(text: widget.existing?.pendingTasks ?? '');
  late final _delayedCtrl = TextEditingController(text: widget.existing?.delayedTasks ?? '');
  late final _clientCtrl = TextEditingController(text: widget.existing?.clientIssues ?? '');
  late final _internalCtrl = TextEditingController(text: widget.existing?.internalIssues ?? '');
  late final _targetsCtrl = TextEditingController(text: widget.existing?.targetsNextWeek ?? '');
  late final _revenueCtrl = TextEditingController(
      text: widget.existing?.revenueContributed?.toString() ?? '');
  bool _loading = false;

  @override
  void dispose() {
    for (final c in [_completedCtrl, _pendingCtrl, _delayedCtrl, _clientCtrl, _internalCtrl, _targetsCtrl, _revenueCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _loading = true);
    try {
      await _api.post(ApiConstants.weeklySummaries, data: {
        'weekEnding': widget.weekEnding,
        if (_completedCtrl.text.isNotEmpty) 'completedTasks': _completedCtrl.text,
        if (_pendingCtrl.text.isNotEmpty) 'pendingTasks': _pendingCtrl.text,
        if (_delayedCtrl.text.isNotEmpty) 'delayedTasks': _delayedCtrl.text,
        if (_clientCtrl.text.isNotEmpty) 'clientIssues': _clientCtrl.text,
        if (_internalCtrl.text.isNotEmpty) 'internalIssues': _internalCtrl.text,
        if (_targetsCtrl.text.isNotEmpty) 'targetsNextWeek': _targetsCtrl.text,
        if (_revenueCtrl.text.isNotEmpty) 'revenueContributed': double.tryParse(_revenueCtrl.text),
      });
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report saved'), backgroundColor: Colors.green),
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
        appBar: AppBar(title: Text('Week ending ${widget.weekEnding}')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              if (widget.existing?.supervisorComments != null) ...[
                Card(
                  color: Colors.green[50],
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Supervisor Remarks', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                        const SizedBox(height: 4),
                        Text(widget.existing!.supervisorComments!),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              _multilineField(_completedCtrl, 'Completed Tasks'),
              const SizedBox(height: 12),
              _multilineField(_pendingCtrl, 'Pending Tasks'),
              const SizedBox(height: 12),
              _multilineField(_delayedCtrl, 'Delayed Tasks'),
              const SizedBox(height: 12),
              _multilineField(_clientCtrl, 'Client Issues'),
              const SizedBox(height: 12),
              _multilineField(_internalCtrl, 'Internal Issues'),
              const SizedBox(height: 12),
              _multilineField(_targetsCtrl, 'Targets for Next Week'),
              const SizedBox(height: 12),
              TextFormField(
                controller: _revenueCtrl,
                decoration: const InputDecoration(labelText: 'Revenue Contributed (ZMW)'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(onPressed: _submit, child: const Text('Submit Report')),
              ),
            ],
          ),
        ),
      );

  Widget _multilineField(TextEditingController ctrl, String label) => TextFormField(
        controller: ctrl,
        decoration: InputDecoration(labelText: label),
        maxLines: 3,
      );
}
