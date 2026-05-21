import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import '../../providers/auth_provider.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_constants.dart';
import '../../core/database/cache_store.dart';
import '../../models/client.dart';
import '../../widgets/common_widgets.dart';

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  final _api = ApiClient().dio;
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  List<Client> _clients = [];
  bool _loading = false;
  bool _hasMore = true;
  int _page = 1;
  String _search = '';

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
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({bool refresh = false}) async {
    if (_loading || (!_hasMore && !refresh)) return;
    if (refresh) { _page = 1; _hasMore = true; _clients = []; }

    if (refresh && _search.isEmpty) {
      final cached = await CacheStore().getList('clients', page: 1);
      if (cached != null && _clients.isEmpty && mounted) {
        setState(() => _clients = cached.map((j) => Client.fromJson(j as Map<String, dynamic>)).toList());
      }
    }

    setState(() => _loading = true);
    try {
      final res = await _api.get(ApiConstants.clients, queryParameters: {
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
      if (_search.isEmpty) await CacheStore().saveList('clients', _page, items);
      setState(() {
        if (refresh) _clients = [];
        _clients.addAll(items.map((j) => Client.fromJson(j)));
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
    final canEdit = user.isAdmin || user.isSupport;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Clients'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search clients...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
              onChanged: (v) { _search = v; _load(refresh: true); },
            ),
          ),
        ),
      ),
      floatingActionButton: canEdit
          ? FloatingActionButton(onPressed: () => _openForm(context), child: const Icon(Icons.add))
          : null,
      body: _clients.isEmpty && _loading
          ? const ShimmerList()
          : RefreshIndicator(
              onRefresh: () => _load(refresh: true),
              child: ListView.builder(
                controller: _scrollCtrl,
                itemCount: _clients.length + (_hasMore ? 1 : 0),
                itemBuilder: (_, i) {
                  if (i == _clients.length) {
                    return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
                  }
                  final c = _clients[i];
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(child: Text(c.name[0])),
                      title: Text(c.name),
                      subtitle: Text('${c.clientCode} • ${c.supportLevel}'),
                      trailing: StatusChip(label: c.isActive ? 'active' : 'inactive'),
                      onTap: () => _openDetail(context, c),
                    ),
                  );
                },
              ),
            ),
    );
  }

  void _openDetail(BuildContext context, Client client) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => ClientDetailScreen(client: client)));
  }

  void _openForm(BuildContext context, [Client? client]) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => ClientFormScreen(client: client)))
        .then((_) => _load(refresh: true));
  }
}

class ClientDetailScreen extends StatelessWidget {
  final Client client;
  const ClientDetailScreen({super.key, required this.client});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(client.name)),
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
                      Text(client.clientCode, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const Spacer(),
                      StatusChip(label: client.isActive ? 'active' : 'inactive'),
                    ]),
                    const Divider(),
                    if (client.contactPerson != null) InfoRow(icon: Icons.person, label: 'Contact', value: client.contactPerson!),
                    if (client.phone != null) InfoRow(icon: Icons.phone, label: 'Phone', value: client.phone!),
                    if (client.email != null) InfoRow(icon: Icons.email, label: 'Email', value: client.email!),
                    if (client.address != null) InfoRow(icon: Icons.location_on, label: 'Address', value: client.address!),
                    if (client.industry != null) InfoRow(icon: Icons.business, label: 'Industry', value: client.industry!),
                    InfoRow(icon: Icons.support, label: 'Support Level', value: client.supportLevel),
                    if (client.supportExpiryDate != null)
                      InfoRow(icon: Icons.calendar_today, label: 'Support Expiry', value: client.supportExpiryDate!),
                    if (client.notes != null) InfoRow(icon: Icons.notes, label: 'Notes', value: client.notes!),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
}

class ClientFormScreen extends StatefulWidget {
  final Client? client;
  const ClientFormScreen({super.key, this.client});

  @override
  State<ClientFormScreen> createState() => _ClientFormScreenState();
}

class _ClientFormScreenState extends State<ClientFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _api = ApiClient().dio;
  bool _loading = false;

  late final _nameCtrl = TextEditingController(text: widget.client?.name ?? '');
  late final _codeCtrl = TextEditingController(text: widget.client?.clientCode ?? '');
  late final _contactCtrl = TextEditingController(text: widget.client?.contactPerson ?? '');
  late final _phoneCtrl = TextEditingController(text: widget.client?.phone ?? '');
  late final _emailCtrl = TextEditingController(text: widget.client?.email ?? '');
  late String _supportLevel = widget.client?.supportLevel ?? 'none';

  @override
  void dispose() {
    for (final c in [_nameCtrl, _codeCtrl, _contactCtrl, _phoneCtrl, _emailCtrl]) c.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final body = {
        'name': _nameCtrl.text.trim(),
        'supportLevel': _supportLevel,
        if (_contactCtrl.text.isNotEmpty) 'contactPerson': _contactCtrl.text.trim(),
        if (_phoneCtrl.text.isNotEmpty) 'phone': _phoneCtrl.text.trim(),
        if (_emailCtrl.text.isNotEmpty) 'email': _emailCtrl.text.trim(),
      };
      if (widget.client == null) {
        body['clientCode'] = _codeCtrl.text.trim();
        await _api.post(ApiConstants.clients, data: body);
      } else {
        await _api.put('${ApiConstants.clients}/${widget.client!.id}', data: body);
      }
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
        appBar: AppBar(title: Text(widget.client == null ? 'New Client' : 'Edit Client')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                if (widget.client == null) ...[
                  TextFormField(
                    controller: _codeCtrl,
                    decoration: const InputDecoration(labelText: 'Client Code'),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                ],
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(labelText: 'Client Name'),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(controller: _contactCtrl, decoration: const InputDecoration(labelText: 'Contact Person')),
                const SizedBox(height: 12),
                TextFormField(controller: _phoneCtrl, decoration: const InputDecoration(labelText: 'Phone')),
                const SizedBox(height: 12),
                TextFormField(controller: _emailCtrl, decoration: const InputDecoration(labelText: 'Email')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _supportLevel,
                  decoration: const InputDecoration(labelText: 'Support Level'),
                  items: ['none', 'basic', 'standard', 'premium']
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) => setState(() => _supportLevel = v!),
                ),
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
}
