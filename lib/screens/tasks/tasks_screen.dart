import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import '../../models/chat.dart';
import '../../core/api/api_constants.dart';

/// New screen — My Tasks.
/// Shows tasks assigned to the current user or created by them.
/// Grouped by status with collapsible sections.
/// Supports inline status change and task deletion.
class TasksScreen extends StatefulWidget {
  final Dio dio;
  final int myUserId;

  const TasksScreen({Key? key, required this.dio, required this.myUserId}) : super(key: key);

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<ChatTask> _myTasks = [];
  List<ChatTask> _createdTasks = [];
  bool _loading = true;

  // Keep track of which status groups are expanded
  final Set<String> _collapsed = {};

  static const _statusOrder = [
    'todo',
    'in_progress',
    'waiting_client',
    'testing',
    'completed',
  ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _loadTasks();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadTasks() async {
    setState(() => _loading = true);
    try {
      final res = await widget.dio.get(ApiConstants.chatTasks);
      final all = (res.data as List).map((j) => ChatTask.fromJson(j)).toList();
      if (mounted) {
        setState(() {
          _myTasks = all.where((t) => t.assignedTo?.id == widget.myUserId).toList();
          _createdTasks = all.where((t) => t.createdBy?.id == widget.myUserId).toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _updateStatus(ChatTask task, String newStatus) async {
    try {
      await widget.dio.put(ApiConstants.taskById(task.id), data: {'status': newStatus});
      await _loadTasks();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update status')),
        );
      }
    }
  }

  Future<void> _deleteTask(ChatTask task) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete task?'),
        content: Text(task.title),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await widget.dio.delete(ApiConstants.taskById(task.id));
      await _loadTasks();
    } catch (_) {}
  }

  Map<String, List<ChatTask>> _groupByStatus(List<ChatTask> tasks) {
    final map = <String, List<ChatTask>>{};
    for (final s in _statusOrder) {
      map[s] = tasks.where((t) => t.status == s).toList()
        ..sort((a, b) {
          // Overdue first, then by due date, then by id
          if (a.isOverdue && !b.isOverdue) return -1;
          if (!a.isOverdue && b.isOverdue) return 1;
          if (a.dueDate != null && b.dueDate != null) {
            return a.dueDate!.compareTo(b.dueDate!);
          }
          if (a.dueDate != null) return -1;
          if (b.dueDate != null) return 1;
          return b.id.compareTo(a.id);
        });
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Tasks'),
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: 'Assigned to me (${_myTasks.length})'),
            Tab(text: 'Created by me (${_createdTasks.length})'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTasks,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabs,
              children: [
                _TaskList(
                  tasks: _myTasks,
                  grouped: _groupByStatus(_myTasks),
                  collapsed: _collapsed,
                  onToggleCollapse: (s) => setState(() {
                    if (_collapsed.contains(s)) _collapsed.remove(s); else _collapsed.add(s);
                  }),
                  onStatusChange: _updateStatus,
                  onDelete: _deleteTask,
                  showAssignee: false,
                ),
                _TaskList(
                  tasks: _createdTasks,
                  grouped: _groupByStatus(_createdTasks),
                  collapsed: _collapsed,
                  onToggleCollapse: (s) => setState(() {
                    if (_collapsed.contains(s)) _collapsed.remove(s); else _collapsed.add(s);
                  }),
                  onStatusChange: _updateStatus,
                  onDelete: _deleteTask,
                  showAssignee: true,
                ),
              ],
            ),
    );
  }
}

// ── Task List ─────────────────────────────────────────────────────────────────

class _TaskList extends StatelessWidget {
  final List<ChatTask> tasks;
  final Map<String, List<ChatTask>> grouped;
  final Set<String> collapsed;
  final void Function(String status) onToggleCollapse;
  final Future<void> Function(ChatTask, String) onStatusChange;
  final Future<void> Function(ChatTask) onDelete;
  final bool showAssignee;

  const _TaskList({
    required this.tasks,
    required this.grouped,
    required this.collapsed,
    required this.onToggleCollapse,
    required this.onStatusChange,
    required this.onDelete,
    required this.showAssignee,
  });

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.task_alt, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text('No tasks yet', style: TextStyle(color: Colors.grey.shade500)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {},
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: _TasksScreen._statusOrder.map((status) {
          final items = grouped[status] ?? [];
          if (items.isEmpty) return const SizedBox.shrink();
          final isCollapsed = collapsed.contains(status);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section header
              InkWell(
                onTap: () => onToggleCollapse(status),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      _StatusDot(status: status),
                      const SizedBox(width: 8),
                      Text(
                        ChatTask.statusLabels[status] ?? status,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('${items.length}', style: const TextStyle(fontSize: 11)),
                      ),
                      const Spacer(),
                      Icon(
                        isCollapsed ? Icons.expand_more : Icons.expand_less,
                        size: 18,
                        color: Colors.grey,
                      ),
                    ],
                  ),
                ),
              ),
              if (!isCollapsed)
                ...items.map((task) => _TaskCard(
                  task: task,
                  showAssignee: showAssignee,
                  onStatusChange: onStatusChange,
                  onDelete: onDelete,
                )),
            ],
          );
        }).toList(),
      ),
    );
  }
}

// ── Task Card ─────────────────────────────────────────────────────────────────

class _TaskCard extends StatelessWidget {
  final ChatTask task;
  final bool showAssignee;
  final Future<void> Function(ChatTask, String) onStatusChange;
  final Future<void> Function(ChatTask) onDelete;

  const _TaskCard({
    required this.task,
    required this.showAssignee,
    required this.onStatusChange,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isOverdue = task.isOverdue;

    return Dismissible(
      key: Key('task-${task.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red.shade600,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        await onDelete(task);
        return false; // list reloads via _loadTasks, no need to remove here
      },
      child: Card(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: isOverdue ? Colors.red.shade300 : Colors.grey.shade200,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      task.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        decoration: task.status == 'completed'
                            ? TextDecoration.lineThrough
                            : null,
                        color: task.status == 'completed' ? Colors.grey : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _PriorityBadge(priority: task.priority),
                ],
              ),

              if (task.description != null && task.description!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  task.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],

              const SizedBox(height: 8),

              // Bottom row: due date + assignee + status picker
              Row(
                children: [
                  if (task.dueDate != null) ...[
                    Icon(
                      Icons.calendar_today,
                      size: 12,
                      color: isOverdue ? Colors.red : Colors.grey.shade500,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      _formatDate(task.dueDate!),
                      style: TextStyle(
                        fontSize: 11,
                        color: isOverdue ? Colors.red : Colors.grey.shade500,
                        fontWeight: isOverdue ? FontWeight.bold : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (showAssignee && task.assignedTo != null) ...[
                    CircleAvatar(
                      radius: 8,
                      backgroundColor: Colors.indigo.shade100,
                      child: Text(
                        task.assignedTo!.displayName.isNotEmpty
                            ? task.assignedTo!.displayName[0].toUpperCase()
                            : '?',
                        style: TextStyle(fontSize: 8, color: Colors.indigo.shade700),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      task.assignedTo!.displayName,
                      style: const TextStyle(fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(width: 8),
                  ],
                  const Spacer(),
                  // Inline status picker
                  _StatusPicker(
                    current: task.status,
                    onChanged: (s) => onStatusChange(task, s),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      return DateFormat('MMM d').format(DateTime.parse(dateStr));
    } catch (_) {
      return dateStr;
    }
  }
}

// ── Status dot ────────────────────────────────────────────────────────────────

class _StatusDot extends StatelessWidget {
  final String status;
  const _StatusDot({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: _color, shape: BoxShape.circle),
    );
  }

  Color get _color {
    switch (status) {
      case 'todo': return Colors.grey;
      case 'in_progress': return Colors.blue;
      case 'waiting_client': return Colors.orange;
      case 'testing': return Colors.purple;
      case 'completed': return Colors.green;
      default: return Colors.grey;
    }
  }
}

// ── Priority Badge ────────────────────────────────────────────────────────────

class _PriorityBadge extends StatelessWidget {
  final String priority;
  const _PriorityBadge({required this.priority});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        ChatTask.priorityLabels[priority] ?? priority,
        style: TextStyle(fontSize: 10, color: _fg, fontWeight: FontWeight.bold),
      ),
    );
  }

  Color get _bg {
    switch (priority) {
      case 'urgent': return Colors.red.shade100;
      case 'high': return Colors.orange.shade100;
      case 'medium': return Colors.yellow.shade100;
      default: return Colors.grey.shade100;
    }
  }

  Color get _fg {
    switch (priority) {
      case 'urgent': return Colors.red.shade800;
      case 'high': return Colors.orange.shade800;
      case 'medium': return Colors.yellow.shade900;
      default: return Colors.grey.shade700;
    }
  }
}

// ── Status Picker ─────────────────────────────────────────────────────────────

class _StatusPicker extends StatelessWidget {
  final String current;
  final void Function(String) onChanged;

  const _StatusPicker({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showPicker(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: _statusColor(current).withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _statusColor(current).withOpacity(0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              ChatTask.statusLabels[current] ?? current,
              style: TextStyle(
                fontSize: 11,
                color: _statusColor(current),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 3),
            Icon(Icons.arrow_drop_down, size: 14, color: _statusColor(current)),
          ],
        ),
      ),
    );
  }

  void _showPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Change Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 12),
            ..._TasksScreen._statusOrder.map((s) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: _StatusDot(status: s),
              title: Text(ChatTask.statusLabels[s] ?? s),
              trailing: current == s ? Icon(Icons.check, color: _statusColor(s)) : null,
              onTap: () {
                Navigator.pop(context);
                if (s != current) onChanged(s);
              },
            )),
          ],
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'todo': return Colors.grey.shade600;
      case 'in_progress': return Colors.blue.shade700;
      case 'waiting_client': return Colors.orange.shade700;
      case 'testing': return Colors.purple.shade700;
      case 'completed': return Colors.green.shade700;
      default: return Colors.grey.shade600;
    }
  }
}
