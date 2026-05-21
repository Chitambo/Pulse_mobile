import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_constants.dart';
import '../../core/database/cache_store.dart';
import '../../models/daily_activity.dart';
import '../../widgets/common_widgets.dart';

class DailyActivitiesScreen extends StatefulWidget {
  const DailyActivitiesScreen({super.key});

  @override
  State<DailyActivitiesScreen> createState() => _DailyActivitiesScreenState();
}

class _DailyActivitiesScreenState extends State<DailyActivitiesScreen> {
  final _api = ApiClient().dio;
  final _scrollCtrl = ScrollController();

  List<DailyActivity> _activities = [];
  bool _loading = false;
  bool _hasMore = true;
  int _page = 1;
  String _date = DateFormat('yyyy-MM-dd').format(DateTime.now());

  @override
  void initState() {
    super.initState();
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
    if (refresh) {
      _page = 1; _hasMore = true; _activities = [];
      final todayKey = 'activities_$_date';
      final cached = await CacheStore().getList(todayKey, page: 1);
      if (cached != null && mounted) {
        setState(() => _activities = cached.map((j) => DailyActivity.fromJson(j as Map<String, dynamic>)).toList());
      }
    }
    setState(() => _loading = true);
    try {
      final res = await _api.get(ApiConstants.dailyActivities, queryParameters: {
        'page': _page,
        'limit': 20,
        'date': _date,
      });
      final data = res.data;
      final items = (data is Map ? data['data'] : data as List? ?? []) as List;
      final totalPages = data is Map ? (data['pages'] ?? 1) : 1;
      await CacheStore().saveList('activities_$_date', _page, items);
      setState(() {
        if (refresh) _activities = [];
        _activities.addAll(items.map((j) => DailyActivity.fromJson(j)));
        _hasMore = _page < totalPages;
        _page++;
      });
    } catch (_) {} finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(_date) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _date = DateFormat('yyyy-MM-dd').format(picked));
      _load(refresh: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Activities'),
        actions: [
          TextButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_today, color: Colors.white),
            label: Text(_date, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => CreateActivityScreen(date: _date)))
            .then((_) => _load(refresh: true)),
        child: const Icon(Icons.add),
      ),
      body: _activities.isEmpty && _loading
          ? const ShimmerList()
          : _activities.isEmpty
              ? const EmptyWidget(message: 'No activities for this date', icon: Icons.today)
              : RefreshIndicator(
                  onRefresh: () => _load(refresh: true),
                  child: ListView.builder(
                    controller: _scrollCtrl,
                    itemCount: _activities.length + (_hasMore ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (i == _activities.length) {
                        return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
                      }
                      final a = _activities[i];
                      return Card(
                        child: ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _typeColor(a.activityType).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(_typeIcon(a.activityType), color: _typeColor(a.activityType)),
                          ),
                          title: Text(a.activityType.replaceAll('_', ' ').toUpperCase(),
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          subtitle: Text(a.description, maxLines: 2, overflow: TextOverflow.ellipsis),
                          trailing: a.employee != null
                              ? Text(a.employee!.firstName, style: const TextStyle(fontSize: 12, color: Colors.grey))
                              : null,
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'support': return Colors.orange;
      case 'development': return Colors.blue;
      case 'sales': return Colors.green;
      case 'meeting': return Colors.purple;
      case 'training': return Colors.teal;
      default: return Colors.grey;
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'support': return Icons.headset_mic;
      case 'development': return Icons.code;
      case 'sales': return Icons.trending_up;
      case 'meeting': return Icons.people;
      case 'training': return Icons.school;
      default: return Icons.work;
    }
  }
}

class CreateActivityScreen extends StatefulWidget {
  final String date;
  const CreateActivityScreen({super.key, required this.date});

  @override
  State<CreateActivityScreen> createState() => _CreateActivityScreenState();
}

class _CreateActivityScreenState extends State<CreateActivityScreen> {
  final _formKey = GlobalKey<FormState>();
  final _api = ApiClient().dio;
  final _descCtrl = TextEditingController();
  String _activityType = 'other';
  String _status = 'completed';
  String _revenueImpact = 'none';
  bool _loading = false;

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await _api.post(ApiConstants.dailyActivities, data: {
        'date': widget.date,
        'activityType': _activityType,
        'description': _descCtrl.text.trim(),
        'status': _status,
        'revenueImpact': _revenueImpact,
      });
      if (mounted) Navigator.pop(context);
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
        appBar: AppBar(title: const Text('Log Activity')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  value: _activityType,
                  decoration: const InputDecoration(labelText: 'Activity Type'),
                  items: ['support', 'development', 'sales', 'admin', 'training', 'meeting', 'other']
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (v) => setState(() => _activityType = v!),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descCtrl,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 4,
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: ['completed', 'in_progress', 'pending']
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) => setState(() => _status = v!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _revenueImpact,
                  decoration: const InputDecoration(labelText: 'Revenue Impact'),
                  items: ['none', 'indirect', 'direct']
                      .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                      .toList(),
                  onChanged: (v) => setState(() => _revenueImpact = v!),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton(onPressed: _submit, child: const Text('Save Activity')),
                ),
              ],
            ),
          ),
        ),
      );
}
