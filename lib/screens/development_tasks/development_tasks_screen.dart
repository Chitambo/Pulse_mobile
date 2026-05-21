import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import '../../providers/auth_provider.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_constants.dart';
import '../../core/database/cache_store.dart';
import '../../models/development_task.dart';
import '../../widgets/common_widgets.dart';

class DevelopmentTasksScreen extends StatefulWidget {
  final String? initialStatus;
  const DevelopmentTasksScreen({super.key, this.initialStatus});

  @override
  State<DevelopmentTasksScreen> createState() => _DevelopmentTasksScreenState();
}

class _DevelopmentTasksScreenState extends State<DevelopmentTasksScreen> {
  final _api = ApiClient().dio;
  final _scrollCtrl = ScrollController();

  List<DevelopmentTask> _tasks = [];
  bool _loading = false;
  bool _hasMore = true;
  int _page = 1;
  String? _statusFilter;

  @override
  void initState() {
    super.initState();
    _statusFilter = widget.initialStatus;
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
    if (refresh) { _page = 1; _hasMore = true; _tasks = []; }

    if (refresh && _statusFilter == null) {
      final cached = await CacheStore().getList('dev_tasks', page: 1);
      if (cached != null && _tasks.isEmpty && mounted) {
        setState(() => _tasks = cached.map((j) => DevelopmentTask.fromJson(j as Map<String, dynamic>)).toList());
      }
    }

    setState(() => _loading = true);
    try {
      final res = await _api.get(ApiConstants.developmentTasks, queryParameters: {
        'page': _page,
        'limit': 20,
        if (_statusFilter != null) 'status': _statusFilter,
      });
      final data = res.data;
      final items = (data['data'] ?? data as List? ?? []) as List;
      final totalPages = data is Map ? (data['pages'] ?? 1) : 1;
      if (_statusFilter == null) await CacheStore().saveList('dev_tasks', _page, items);
      setState(() {
        if (refresh) _tasks = [];
        _tasks.addAll(items.map((j) => DevelopmentTask.fromJson(j)));
        _hasMore = _page < totalPages;
        _page++;
      });
    } catch (_) {} finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user!;
    final canCreate = user.isAdmin || user.isDeveloper;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dev Tasks'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (v) {
              setState(() => _statusFilter = v.isEmpty ? null : v);
              _load(refresh: true);
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: '', child: Text('All')),
              ...['pending', 'in_progress', 'testing', 'completed', 'deployed', 'cancelled']
                  .map((s) => PopupMenuItem(value: s, child: Text(s))),
            ],
          ),
        ],
      ),
      floatingActionButton: canCreate
          ? FloatingActionButton(
              onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const CreateTaskScreen()))
                  .then((_) => _load(refresh: true)),
              child: const Icon(Icons.add),
            )
          : null,
      body: _tasks.isEmpty && _loading
          ? const ShimmerList()
          : RefreshIndicator(
              onRefresh: () => _load(refresh: true),
              child: ListView.builder(
                controller: _scrollCtrl,
                itemCount: _tasks.length + (_hasMore ? 1 : 0),
                itemBuilder: (_, i) {
                  if (i == _tasks.length) {
                    return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
                  }
                  final t = _tasks[i];
                  return Card(
                    child: ListTile(
                      title: Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.taskType.replaceAll('_', ' ')),
                          if (t.dueDate != null) Text('Due: ${t.dueDate}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                      isThreeLine: t.dueDate != null,
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          StatusChip(label: t.priority),
                          const SizedBox(height: 4),
                          StatusChip(label: t.status),
                        ],
                      ),
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => TaskDetailScreen(task: t)))
                          .then((_) => _load(refresh: true)),
                    ),
                  );
                },
              ),
            ),
    );
  }
}

class TaskDetailScreen extends StatefulWidget {
  final DevelopmentTask task;
  const TaskDetailScreen({super.key, required this.task});

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  final _api = ApiClient().dio;
  late DevelopmentTask _task = widget.task;

  void _showUpdateSheet() {
    String status = _task.status;
    int progress = _task.percentageProgress ?? 0;
    final notesCtrl = TextEditingController(text: _task.testingNotes ?? '');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: StatefulBuilder(
            builder: (_, setSheetState) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Update Task', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: ['pending', 'in_progress', 'testing', 'completed', 'deployed', 'cancelled']
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) => setSheetState(() => status = v!),
                ),
                const SizedBox(height: 12),
                Text('Progress: $progress%'),
                Slider(
                  value: progress.toDouble(),
                  min: 0,
                  max: 100,
                  divisions: 20,
                  label: '$progress%',
                  onChanged: (v) => setSheetState(() => progress = v.round()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(labelText: 'Testing Notes'),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    try {
                      final res = await _api.put('${ApiConstants.developmentTasks}/${_task.id}', data: {
                        'status': status,
                        'percentageProgress': progress,
                        if (notesCtrl.text.isNotEmpty) 'testingNotes': notesCtrl.text,
                      });
                      setState(() => _task = DevelopmentTask.fromJson(res.data));
                    } catch (_) {}
                  },
                  child: const Text('Update'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthProvider>().user!;
    return Scaffold(
      appBar: AppBar(
        title: Text(_task.title, overflow: TextOverflow.ellipsis),
        actions: [
          if (user.isAdmin || user.isDeveloper)
            IconButton(icon: const Icon(Icons.edit), onPressed: _showUpdateSheet),
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
                    StatusChip(label: _task.priority),
                    const SizedBox(width: 8),
                    StatusChip(label: _task.status),
                    const SizedBox(width: 8),
                    StatusChip(label: _task.taskType),
                  ]),
                  const SizedBox(height: 12),
                  Text(_task.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(_task.description),
                  if (_task.percentageProgress != null) ...[
                    const SizedBox(height: 12),
                    Text('Progress: ${_task.percentageProgress}%'),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(value: (_task.percentageProgress ?? 0) / 100),
                  ],
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
                  if (_task.dueDate != null) InfoRow(icon: Icons.calendar_today, label: 'Due Date', value: _task.dueDate!),
                  if (_task.assignedDeveloper != null)
                    InfoRow(icon: Icons.person, label: 'Developer', value: _task.assignedDeveloper!.fullName),
                  if (_task.module != null) InfoRow(icon: Icons.folder, label: 'Module', value: _task.module!),
                  if (_task.gitBranch != null) InfoRow(icon: Icons.code, label: 'Branch', value: _task.gitBranch!),
                  if (_task.testingNotes != null) InfoRow(icon: Icons.science, label: 'Testing Notes', value: _task.testingNotes!),
                  if (_task.deploymentNotes != null) InfoRow(icon: Icons.rocket_launch, label: 'Deployment Notes', value: _task.deploymentNotes!),
                  if (_task.delayReason != null) InfoRow(icon: Icons.warning, label: 'Delay Reason', value: _task.delayReason!),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CreateTaskScreen extends StatefulWidget {
  const CreateTaskScreen({super.key});

  @override
  State<CreateTaskScreen> createState() => _CreateTaskScreenState();
}

class _CreateTaskScreenState extends State<CreateTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _api = ApiClient().dio;
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _dueDateCtrl = TextEditingController();
  String _taskType = 'feature';
  String _priority = 'medium';
  bool _loading = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _dueDateCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await _api.post(ApiConstants.developmentTasks, data: {
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'taskType': _taskType,
        'priority': _priority,
        if (_dueDateCtrl.text.isNotEmpty) 'dueDate': _dueDateCtrl.text.trim(),
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
        appBar: AppBar(title: const Text('New Task')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(labelText: 'Title'),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descCtrl,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 3,
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _taskType,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: ['bug_fix', 'feature', 'enhancement', 'maintenance', 'deployment']
                      .map((t) => DropdownMenuItem(value: t, child: Text(t.replaceAll('_', ' '))))
                      .toList(),
                  onChanged: (v) => setState(() => _taskType = v!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _priority,
                  decoration: const InputDecoration(labelText: 'Priority'),
                  items: ['low', 'medium', 'high', 'critical']
                      .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                      .toList(),
                  onChanged: (v) => setState(() => _priority = v!),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _dueDateCtrl,
                  decoration: const InputDecoration(labelText: 'Due Date (yyyy-MM-dd)', suffixIcon: Icon(Icons.calendar_today)),
                  readOnly: true,
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      _dueDateCtrl.text = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                    }
                  },
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton(onPressed: _submit, child: const Text('Create Task')),
                ),
              ],
            ),
          ),
        ),
      );
}
