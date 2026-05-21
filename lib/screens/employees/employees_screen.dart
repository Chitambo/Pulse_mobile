import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import '../../providers/auth_provider.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_constants.dart';
import '../../core/database/cache_store.dart';
import '../../models/employee.dart';
import '../../widgets/common_widgets.dart';

class EmployeesScreen extends StatefulWidget {
  const EmployeesScreen({super.key});

  @override
  State<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends State<EmployeesScreen> {
  final _api = ApiClient().dio;
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  List<Employee> _employees = [];
  bool _loading = false;
  bool _hasMore = true;
  int _page = 1;
  String _search = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    _load(refresh: true);
    _scrollCtrl.addListener(() {
      if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 200) {
        _load();
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({bool refresh = false}) async {
    if (_loading || (!_hasMore && !refresh)) return;
    if (refresh) { _page = 1; _hasMore = true; _employees = []; }

    // ── 1. Serve from cache immediately ──────────────────────────────────────
    if (refresh && _search.isEmpty) {
      final cached = await CacheStore().getList('employees', page: 1);
      if (cached != null && _employees.isEmpty) {
        final loaded = cached.map((j) => Employee.fromJson(j as Map<String, dynamic>)).toList();
        if (mounted) setState(() => _employees = loaded);
      }
    }

    setState(() { _loading = true; _error = null; });
    try {
      final res = await _api.get(ApiConstants.employees, queryParameters: {
        'page': _page,
        'limit': 20,
        if (_search.isNotEmpty) 'search': _search,
      });
      final data = res.data;
      List items;
      int totalPages;
      if (data is Map) {
        items = data['data'] ?? [];
        totalPages = data['pagination']?['totalPages'] ?? 1;
      } else {
        items = data as List;
        totalPages = 1;
      }
      // ── 2. Persist to cache ───────────────────────────────────────────────
      if (_search.isEmpty) {
        await CacheStore().saveList('employees', _page, items);
      }
      final loaded = items.map((j) => Employee.fromJson(j)).toList();
      setState(() {
        if (refresh && _employees.isNotEmpty) _employees = [];
        _employees.addAll(loaded);
        _hasMore = _page < totalPages;
        _page++;
      });
    } on DioException catch (e) {
      setState(() => _error = e.response?.data?['message'] ?? 'Error loading employees');
    } finally {
      setState(() => _loading = false);
    }
  }

  void _onSearch(String v) {
    _search = v;
    _load(refresh: true);
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = context.watch<AuthProvider>().user!.isAdmin;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Employees'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search employees...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
              onChanged: _onSearch,
            ),
          ),
        ),
      ),
      floatingActionButton: canEdit
          ? FloatingActionButton(
              onPressed: () => _openForm(context),
              child: const Icon(Icons.add),
            )
          : null,
      body: _error != null && _employees.isEmpty
          ? ErrorRetryWidget(message: _error!, onRetry: () => _load(refresh: true))
          : _employees.isEmpty && _loading
              ? const ShimmerList()
              : RefreshIndicator(
                  onRefresh: () => _load(refresh: true),
                  child: ListView.builder(
                    controller: _scrollCtrl,
                    itemCount: _employees.length + (_hasMore ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (i == _employees.length) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      return _EmployeeTile(
                        employee: _employees[i],
                        onTap: () => _openDetail(context, _employees[i]),
                      );
                    },
                  ),
                ),
    );
  }

  void _openDetail(BuildContext context, Employee emp) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => EmployeeDetailScreen(employee: emp)));
  }

  void _openForm(BuildContext context, [Employee? emp]) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => EmployeeFormScreen(employee: emp)))
        .then((_) => _load(refresh: true));
  }
}

class _EmployeeTile extends StatelessWidget {
  final Employee employee;
  final VoidCallback onTap;
  const _EmployeeTile({required this.employee, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final photoUrl = employee.photo != null
        ? '${ApiConstants.uploadsUrl}/employees/${employee.photo}'
        : null;
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          radius: 24,
          backgroundImage: photoUrl != null ? CachedNetworkImageProvider(photoUrl) : null,
          child: photoUrl == null ? Text(employee.firstName[0]) : null,
        ),
        title: Text(employee.fullName),
        subtitle: Text('${employee.jobTitle} • ${employee.department?.name ?? 'No dept'}'),
        trailing: StatusChip(label: employee.status),
        onTap: onTap,
      ),
    );
  }
}

class EmployeeDetailScreen extends StatelessWidget {
  final Employee employee;
  const EmployeeDetailScreen({super.key, required this.employee});

  @override
  Widget build(BuildContext context) {
    final photoUrl = employee.photo != null
        ? '${ApiConstants.uploadsUrl}/employees/${employee.photo}'
        : null;
    return Scaffold(
      appBar: AppBar(title: Text(employee.fullName)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: CircleAvatar(
              radius: 50,
              backgroundImage: photoUrl != null ? CachedNetworkImageProvider(photoUrl) : null,
              child: photoUrl == null ? Text(employee.firstName[0], style: const TextStyle(fontSize: 32)) : null,
            ),
          ),
          const SizedBox(height: 16),
          Center(child: Text(employee.fullName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
          Center(child: Text(employee.jobTitle, style: const TextStyle(color: Colors.grey))),
          const SizedBox(height: 8),
          Center(child: StatusChip(label: employee.status)),
          const Divider(height: 32),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  InfoRow(icon: Icons.badge, label: 'Employee #', value: employee.employeeNumber),
                  InfoRow(icon: Icons.business, label: 'Department', value: employee.department?.name ?? 'N/A'),
                  if (employee.email != null) InfoRow(icon: Icons.email, label: 'Email', value: employee.email!),
                  if (employee.phone != null) InfoRow(icon: Icons.phone, label: 'Phone', value: employee.phone!),
                  InfoRow(icon: Icons.calendar_today, label: 'Date Joined', value: employee.dateJoined),
                  if (employee.supervisor != null)
                    InfoRow(icon: Icons.supervisor_account, label: 'Supervisor', value: employee.supervisor!.fullName),
                  if (employee.notes != null) InfoRow(icon: Icons.notes, label: 'Notes', value: employee.notes!),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class EmployeeFormScreen extends StatefulWidget {
  final Employee? employee;
  const EmployeeFormScreen({super.key, this.employee});

  @override
  State<EmployeeFormScreen> createState() => _EmployeeFormScreenState();
}

class _EmployeeFormScreenState extends State<EmployeeFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _api = ApiClient().dio;
  bool _loading = false;

  late final _firstCtrl = TextEditingController(text: widget.employee?.firstName ?? '');
  late final _lastCtrl = TextEditingController(text: widget.employee?.lastName ?? '');
  late final _numCtrl = TextEditingController(text: widget.employee?.employeeNumber ?? '');
  late final _titleCtrl = TextEditingController(text: widget.employee?.jobTitle ?? '');
  late final _emailCtrl = TextEditingController(text: widget.employee?.email ?? '');
  late final _phoneCtrl = TextEditingController(text: widget.employee?.phone ?? '');
  late final _joinedCtrl = TextEditingController(text: widget.employee?.dateJoined ?? '');

  @override
  void dispose() {
    for (final c in [_firstCtrl, _lastCtrl, _numCtrl, _titleCtrl, _emailCtrl, _phoneCtrl, _joinedCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final body = {
        'firstName': _firstCtrl.text.trim(),
        'lastName': _lastCtrl.text.trim(),
        'jobTitle': _titleCtrl.text.trim(),
        if (_emailCtrl.text.isNotEmpty) 'email': _emailCtrl.text.trim(),
        if (_phoneCtrl.text.isNotEmpty) 'phone': _phoneCtrl.text.trim(),
      };
      if (widget.employee == null) {
        body['employeeNumber'] = _numCtrl.text.trim();
        body['dateJoined'] = _joinedCtrl.text.trim();
        await _api.post(ApiConstants.employees, data: body);
      } else {
        await _api.put('${ApiConstants.employees}/${widget.employee!.id}', data: body);
      }
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved successfully'), backgroundColor: Colors.green),
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
        appBar: AppBar(title: Text(widget.employee == null ? 'Add Employee' : 'Edit Employee')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                if (widget.employee == null) ...[
                  _field(_numCtrl, 'Employee Number', required: true),
                  const SizedBox(height: 12),
                  _field(_joinedCtrl, 'Date Joined (yyyy-MM-dd)', required: true),
                  const SizedBox(height: 12),
                ],
                _field(_firstCtrl, 'First Name', required: true),
                const SizedBox(height: 12),
                _field(_lastCtrl, 'Last Name', required: true),
                const SizedBox(height: 12),
                _field(_titleCtrl, 'Job Title', required: true),
                const SizedBox(height: 12),
                _field(_emailCtrl, 'Email'),
                const SizedBox(height: 12),
                _field(_phoneCtrl, 'Phone'),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton(onPressed: _submit, child: const Text('Save')),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _field(TextEditingController ctrl, String label, {bool required = false}) => TextFormField(
        controller: ctrl,
        decoration: InputDecoration(labelText: label),
        validator: required ? (v) => v!.isEmpty ? 'Required' : null : null,
      );
}
