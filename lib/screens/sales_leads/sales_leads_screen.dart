import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import '../../providers/auth_provider.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_constants.dart';
import '../../core/database/cache_store.dart';
import '../../models/sales_lead.dart';
import '../../widgets/common_widgets.dart';

class SalesLeadsScreen extends StatefulWidget {
  final String? initialStage;
  const SalesLeadsScreen({super.key, this.initialStage});

  @override
  State<SalesLeadsScreen> createState() => _SalesLeadsScreenState();
}

class _SalesLeadsScreenState extends State<SalesLeadsScreen> {
  final _api = ApiClient().dio;
  final _scrollCtrl = ScrollController();

  List<SalesLead> _leads = [];
  bool _loading = false;
  bool _hasMore = true;
  int _page = 1;
  String? _stageFilter;

  @override
  void initState() {
    super.initState();
    _stageFilter = widget.initialStage;
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
    if (refresh) { _page = 1; _hasMore = true; _leads = []; }

    if (refresh && _stageFilter == null) {
      final cached = await CacheStore().getList('leads', page: 1);
      if (cached != null && _leads.isEmpty && mounted) {
        setState(() => _leads = cached.map((j) => SalesLead.fromJson(j as Map<String, dynamic>)).toList());
      }
    }

    setState(() => _loading = true);
    try {
      final res = await _api.get(ApiConstants.salesLeads, queryParameters: {
        'page': _page,
        'limit': 20,
        if (_stageFilter != null) 'stage': _stageFilter,
      });
      final data = res.data;
      final items = (data['data'] ?? data as List? ?? []) as List;
      final totalPages = data is Map ? (data['pages'] ?? 1) : 1;
      if (_stageFilter == null) await CacheStore().saveList('leads', _page, items);
      setState(() {
        if (refresh) _leads = [];
        _leads.addAll(items.map((j) => SalesLead.fromJson(j)));
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
    final canCreate = user.isAdmin || user.isSupport;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales Leads'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (v) {
              setState(() => _stageFilter = v.isEmpty ? null : v);
              _load(refresh: true);
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: '', child: Text('All')),
              ...['new', 'contacted', 'proposal', 'negotiation', 'won', 'lost']
                  .map((s) => PopupMenuItem(value: s, child: Text(s))),
            ],
          ),
        ],
      ),
      floatingActionButton: canCreate
          ? FloatingActionButton(
              onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const CreateLeadScreen()))
                  .then((_) => _load(refresh: true)),
              child: const Icon(Icons.add),
            )
          : null,
      body: _leads.isEmpty && _loading
          ? const ShimmerList()
          : RefreshIndicator(
              onRefresh: () => _load(refresh: true),
              child: ListView.builder(
                controller: _scrollCtrl,
                itemCount: _leads.length + (_hasMore ? 1 : 0),
                itemBuilder: (_, i) {
                  if (i == _leads.length) {
                    return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
                  }
                  final lead = _leads[i];
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _stageColor(lead.stage).withOpacity(0.15),
                        child: Icon(Icons.trending_up, color: _stageColor(lead.stage)),
                      ),
                      title: Text(lead.prospectName ?? lead.client?.name ?? lead.productOfInterest),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(lead.productOfInterest),
                          if (lead.estimatedValue != null)
                            Text('ZMW ${lead.estimatedValue!.toStringAsFixed(0)}',
                                style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                      isThreeLine: lead.estimatedValue != null,
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          StatusChip(label: lead.stage),
                          const SizedBox(height: 4),
                          StatusChip(label: lead.probability),
                        ],
                      ),
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => LeadDetailScreen(lead: lead)))
                          .then((_) => _load(refresh: true)),
                    ),
                  );
                },
              ),
            ),
    );
  }

  Color _stageColor(String stage) {
    switch (stage) {
      case 'new': return Colors.blue;
      case 'contacted': return Colors.orange;
      case 'proposal': return Colors.purple;
      case 'negotiation': return Colors.amber;
      case 'won': return Colors.green;
      case 'lost': return Colors.red;
      default: return Colors.grey;
    }
  }
}

class LeadDetailScreen extends StatelessWidget {
  final SalesLead lead;
  const LeadDetailScreen({super.key, required this.lead});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(lead.prospectName ?? lead.productOfInterest)),
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
                      StatusChip(label: lead.stage),
                      const SizedBox(width: 8),
                      StatusChip(label: lead.probability),
                    ]),
                    const SizedBox(height: 12),
                    InfoRow(icon: Icons.inventory, label: 'Product', value: lead.productOfInterest),
                    InfoRow(icon: Icons.source, label: 'Source', value: lead.leadSource),
                    if (lead.contactPerson != null) InfoRow(icon: Icons.person, label: 'Contact', value: lead.contactPerson!),
                    if (lead.contactPhone != null) InfoRow(icon: Icons.phone, label: 'Phone', value: lead.contactPhone!),
                    if (lead.contactEmail != null) InfoRow(icon: Icons.email, label: 'Email', value: lead.contactEmail!),
                    if (lead.estimatedValue != null)
                      InfoRow(icon: Icons.attach_money, label: 'Est. Value', value: 'ZMW ${lead.estimatedValue!.toStringAsFixed(2)}'),
                    if (lead.nextFollowUpDate != null)
                      InfoRow(icon: Icons.calendar_today, label: 'Next Follow-up', value: lead.nextFollowUpDate!),
                    if (lead.assignedOfficer != null)
                      InfoRow(icon: Icons.person_pin, label: 'Officer', value: lead.assignedOfficer!.fullName),
                    if (lead.notes != null) InfoRow(icon: Icons.notes, label: 'Notes', value: lead.notes!),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
}

class CreateLeadScreen extends StatefulWidget {
  const CreateLeadScreen({super.key});

  @override
  State<CreateLeadScreen> createState() => _CreateLeadScreenState();
}

class _CreateLeadScreenState extends State<CreateLeadScreen> {
  final _formKey = GlobalKey<FormState>();
  final _api = ApiClient().dio;
  final _productCtrl = TextEditingController();
  final _prospectCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _valueCtrl = TextEditingController();
  String _source = 'referral';
  String _stage = 'new';
  String _probability = 'medium';
  bool _loading = false;

  @override
  void dispose() {
    for (final c in [_productCtrl, _prospectCtrl, _contactCtrl, _phoneCtrl, _emailCtrl, _valueCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await _api.post(ApiConstants.salesLeads, data: {
        'leadSource': _source,
        'productOfInterest': _productCtrl.text.trim(),
        'stage': _stage,
        'probability': _probability,
        if (_prospectCtrl.text.isNotEmpty) 'prospectName': _prospectCtrl.text.trim(),
        if (_contactCtrl.text.isNotEmpty) 'contactPerson': _contactCtrl.text.trim(),
        if (_phoneCtrl.text.isNotEmpty) 'contactPhone': _phoneCtrl.text.trim(),
        if (_emailCtrl.text.isNotEmpty) 'contactEmail': _emailCtrl.text.trim(),
        if (_valueCtrl.text.isNotEmpty) 'estimatedValue': double.tryParse(_valueCtrl.text),
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
        appBar: AppBar(title: const Text('New Lead')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _productCtrl,
                  decoration: const InputDecoration(labelText: 'Product of Interest'),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(controller: _prospectCtrl, decoration: const InputDecoration(labelText: 'Prospect Name')),
                const SizedBox(height: 12),
                TextFormField(controller: _contactCtrl, decoration: const InputDecoration(labelText: 'Contact Person')),
                const SizedBox(height: 12),
                TextFormField(controller: _phoneCtrl, decoration: const InputDecoration(labelText: 'Phone')),
                const SizedBox(height: 12),
                TextFormField(controller: _emailCtrl, decoration: const InputDecoration(labelText: 'Email')),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _valueCtrl,
                  decoration: const InputDecoration(labelText: 'Estimated Value (ZMW)'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _source,
                  decoration: const InputDecoration(labelText: 'Source'),
                  items: ['referral', 'cold_call', 'website', 'email', 'social_media', 'other']
                      .map((s) => DropdownMenuItem(value: s, child: Text(s.replaceAll('_', ' '))))
                      .toList(),
                  onChanged: (v) => setState(() => _source = v!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _stage,
                  decoration: const InputDecoration(labelText: 'Stage'),
                  items: ['new', 'contacted', 'proposal', 'negotiation']
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) => setState(() => _stage = v!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _probability,
                  decoration: const InputDecoration(labelText: 'Probability'),
                  items: ['low', 'medium', 'high']
                      .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                      .toList(),
                  onChanged: (v) => setState(() => _probability = v!),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton(onPressed: _submit, child: const Text('Create Lead')),
                ),
              ],
            ),
          ),
        ),
      );
}
