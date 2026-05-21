import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_constants.dart';
import '../../core/database/cache_store.dart';
import '../../models/invoice.dart';
import '../../widgets/common_widgets.dart';

final _zmw = NumberFormat.currency(locale: 'en_ZM', symbol: 'ZMW ', decimalDigits: 2);

class InvoicesScreen extends StatefulWidget {
  final String? initialStatus;
  const InvoicesScreen({super.key, this.initialStatus});

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  final _api = ApiClient().dio;
  final _scrollCtrl = ScrollController();

  List<Invoice> _invoices = [];
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
    if (refresh) { _page = 1; _hasMore = true; _invoices = []; }

    if (refresh && _statusFilter == null) {
      final cached = await CacheStore().getList('invoices', page: 1);
      if (cached != null && _invoices.isEmpty && mounted) {
        setState(() => _invoices = cached.map((j) => Invoice.fromJson(j as Map<String, dynamic>)).toList());
      }
    }

    setState(() => _loading = true);
    try {
      final res = await _api.get(ApiConstants.invoices, queryParameters: {
        'page': _page,
        'limit': 20,
        if (_statusFilter != null) 'paymentStatus': _statusFilter,
      });
      final data = res.data;
      final items = (data['data'] ?? data as List? ?? []) as List;
      final totalPages = data is Map ? (data['pages'] ?? 1) : 1;
      if (_statusFilter == null) await CacheStore().saveList('invoices', _page, items);
      setState(() {
        if (refresh) _invoices = [];
        _invoices.addAll(items.map((j) => Invoice.fromJson(j)));
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
    final canCreate = user.isAdmin || user.isAccounts;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoices'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (v) {
              setState(() => _statusFilter = v.isEmpty ? null : v);
              _load(refresh: true);
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: '', child: Text('All')),
              ...['unpaid', 'partial', 'paid', 'overdue']
                  .map((s) => PopupMenuItem(value: s, child: Text(s))),
            ],
          ),
        ],
      ),
      floatingActionButton: canCreate
          ? FloatingActionButton(
              onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const CreateInvoiceScreen()))
                  .then((_) => _load(refresh: true)),
              child: const Icon(Icons.add),
            )
          : null,
      body: _invoices.isEmpty && _loading
          ? const ShimmerList()
          : RefreshIndicator(
              onRefresh: () => _load(refresh: true),
              child: ListView.builder(
                controller: _scrollCtrl,
                itemCount: _invoices.length + (_hasMore ? 1 : 0),
                itemBuilder: (_, i) {
                  if (i == _invoices.length) {
                    return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
                  }
                  final inv = _invoices[i];
                  return Card(
                    child: ListTile(
                      title: Text(inv.invoiceNumber, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(inv.client?.name ?? 'No client'),
                          Text('Due: ${inv.dueDate}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                      isThreeLine: true,
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(_zmw.format(inv.totalAmount), style: const TextStyle(fontWeight: FontWeight.bold)),
                          StatusChip(label: inv.paymentStatus),
                        ],
                      ),
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => InvoiceDetailScreen(invoiceId: inv.id)))
                          .then((_) => _load(refresh: true)),
                    ),
                  );
                },
              ),
            ),
    );
  }
}

class InvoiceDetailScreen extends StatefulWidget {
  final int invoiceId;
  const InvoiceDetailScreen({super.key, required this.invoiceId});

  @override
  State<InvoiceDetailScreen> createState() => _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends State<InvoiceDetailScreen> {
  final _api = ApiClient().dio;
  Invoice? _invoice;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _api.get('${ApiConstants.invoices}/${widget.invoiceId}');
      setState(() { _invoice = Invoice.fromJson(res.data); _loading = false; });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  void _recordPayment() {
    final dateCtrl = TextEditingController(text: DateFormat('yyyy-MM-dd').format(DateTime.now()));
    final amountCtrl = TextEditingController();
    final refCtrl = TextEditingController();
    String method = 'bank_transfer';

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
              const Text('Record Payment', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextFormField(controller: dateCtrl, decoration: const InputDecoration(labelText: 'Date')),
              const SizedBox(height: 12),
              TextFormField(
                controller: amountCtrl,
                decoration: const InputDecoration(labelText: 'Amount (ZMW)'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              StatefulBuilder(
                builder: (_, ss) => DropdownButtonFormField<String>(
                  value: method,
                  decoration: const InputDecoration(labelText: 'Method'),
                  items: ['bank_transfer', 'cash', 'mobile_money', 'cheque']
                      .map((m) => DropdownMenuItem(value: m, child: Text(m.replaceAll('_', ' '))))
                      .toList(),
                  onChanged: (v) => ss(() => method = v!),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(controller: refCtrl, decoration: const InputDecoration(labelText: 'Reference')),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  try {
                    await _api.post('${ApiConstants.invoices}/${_invoice!.id}/payments', data: {
                      'paymentDate': dateCtrl.text,
                      'amount': double.tryParse(amountCtrl.text) ?? 0,
                      'paymentMethod': method,
                      if (refCtrl.text.isNotEmpty) 'reference': refCtrl.text,
                    });
                    _load();
                  } catch (_) {}
                },
                child: const Text('Record Payment'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: LoadingWidget());
    if (_invoice == null) return Scaffold(appBar: AppBar(), body: const Center(child: Text('Not found')));
    final inv = _invoice!;
    final user = context.read<AuthProvider>().user!;

    return Scaffold(
      appBar: AppBar(
        title: Text(inv.invoiceNumber),
        actions: [
          if (user.isAdmin || user.isAccounts)
            IconButton(icon: const Icon(Icons.add_card), onPressed: _recordPayment),
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
                    StatusChip(label: inv.paymentStatus),
                    const Spacer(),
                    Text(inv.dueDate, style: const TextStyle(color: Colors.grey)),
                  ]),
                  const SizedBox(height: 12),
                  if (inv.client != null) InfoRow(icon: Icons.business, label: 'Client', value: inv.client!.name),
                  InfoRow(icon: Icons.miscellaneous_services, label: 'Service', value: inv.serviceType),
                  if (inv.description != null) InfoRow(icon: Icons.notes, label: 'Description', value: inv.description!),
                  const Divider(),
                  _AmountRow('Amount (before VAT)', inv.amountBeforeVat),
                  _AmountRow('VAT (${inv.vatRate.toStringAsFixed(0)}%)', inv.vatAmount),
                  _AmountRow('Total', inv.totalAmount, bold: true),
                  _AmountRow('Paid', inv.amountPaid, color: Colors.green),
                  _AmountRow('Balance', inv.balance, color: inv.balance > 0 ? Colors.red : Colors.green, bold: true),
                ],
              ),
            ),
          ),
          if (inv.payments.isNotEmpty) ...[
            const SectionHeader(title: 'Payments'),
            ...inv.payments.map((p) => Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                leading: const Icon(Icons.payment),
                title: Text(_zmw.format(p.amount), style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${p.paymentDate} • ${p.paymentMethod?.replaceAll('_', ' ') ?? ''}'),
                trailing: p.reference != null ? Text(p.reference!, style: const TextStyle(fontSize: 12)) : null,
              ),
            )),
          ],
        ],
      ),
    );
  }
}

class _AmountRow extends StatelessWidget {
  final String label;
  final double amount;
  final bool bold;
  final Color? color;

  const _AmountRow(this.label, this.amount, {this.bold = false, this.color});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Text(label, style: TextStyle(color: Colors.grey[600])),
            const Spacer(),
            Text(
              _zmw.format(amount),
              style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal, color: color),
            ),
          ],
        ),
      );
}

class CreateInvoiceScreen extends StatefulWidget {
  const CreateInvoiceScreen({super.key});

  @override
  State<CreateInvoiceScreen> createState() => _CreateInvoiceScreenState();
}

class _CreateInvoiceScreenState extends State<CreateInvoiceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _api = ApiClient().dio;
  final _serviceCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _dueDateCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _serviceCtrl.dispose();
    _amountCtrl.dispose();
    _dueDateCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await _api.post(ApiConstants.invoices, data: {
        'serviceType': _serviceCtrl.text.trim(),
        'amountBeforeVat': double.tryParse(_amountCtrl.text) ?? 0,
        'dueDate': _dueDateCtrl.text.trim(),
        if (_descCtrl.text.isNotEmpty) 'description': _descCtrl.text.trim(),
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
        appBar: AppBar(title: const Text('New Invoice')),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _serviceCtrl,
                  decoration: const InputDecoration(labelText: 'Service Type'),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _amountCtrl,
                  decoration: const InputDecoration(labelText: 'Amount (before VAT, ZMW)'),
                  keyboardType: TextInputType.number,
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _dueDateCtrl,
                  decoration: const InputDecoration(labelText: 'Due Date', suffixIcon: Icon(Icons.calendar_today)),
                  readOnly: true,
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now().add(const Duration(days: 30)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      _dueDateCtrl.text = DateFormat('yyyy-MM-dd').format(picked);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descCtrl,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 3,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton(onPressed: _submit, child: const Text('Create Invoice')),
                ),
              ],
            ),
          ),
        ),
      );
}
