import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_constants.dart';
import '../../providers/auth_provider.dart';
import '../../models/expense.dart';
import '../../widgets/common_widgets.dart';

final _zmw = NumberFormat.currency(locale: 'en_ZM', symbol: 'ZMW ', decimalDigits: 2);

/// Parse "1,250.50" / "ZMW 1250" / " 200 " -> 1250.5 / 1250 / 200
double _parseMoney(String s) => double.tryParse(s.replaceAll(RegExp(r'[^0-9.\-]'), '')) ?? 0;

/// Human-readable message for a Dio failure (network vs server).
String _dioMessage(DioException e) {
  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.sendTimeout:
      return 'The server did not respond. Check your connection.';
    case DioExceptionType.connectionError:
      return 'Can’t reach the server (${ApiConstants.origin}).';
    default:
      return (e.response?.data is Map ? e.response?.data['message'] : null)?.toString()
          ?? 'Request failed (${e.response?.statusCode ?? 'no response'})';
  }
}

Color _statusColor(String s) => {
      'paid': Colors.green,
      'approved': Colors.teal,
      'payment_initiated': Colors.blue,
      'pending': Colors.orange,
      'draft': Colors.grey,
      'rejected': Colors.red,
      'cancelled': Colors.grey,
    }[s] ?? Colors.grey;

class ExpensesScreen extends StatefulWidget {
  final String? initialStatus;
  const ExpensesScreen({super.key, this.initialStatus});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final _api = ApiClient().dio;
  final _scrollCtrl = ScrollController();

  List<Expense> _rows = [];
  bool _loading = false;
  bool _hasMore = true;
  int _page = 1;
  String? _status;

  @override
  void initState() {
    super.initState();
    _status = widget.initialStatus;
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
    if (refresh) { _page = 1; _hasMore = true; }
    setState(() => _loading = true);
    try {
      final res = await _api.get(ApiConstants.expenses, queryParameters: {
        'page': _page, 'limit': 20,
        if (_status != null) 'status': _status,
      });
      final data = res.data;
      final items = (data['data'] ?? []) as List;
      final totalPages = data is Map ? (data['pages'] ?? 1) : 1;
      setState(() {
        if (refresh) _rows = [];
        _rows.addAll(items.map((j) => Expense.fromJson(j)));
        _hasMore = _page < totalPages;
        _page++;
      });
    } catch (_) {} finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expenses'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (v) { setState(() => _status = v.isEmpty ? null : v); _load(refresh: true); },
            itemBuilder: (_) => [
              const PopupMenuItem(value: '', child: Text('All')),
              for (final s in ['pending', 'approved', 'payment_initiated', 'paid', 'rejected'])
                PopupMenuItem(value: s, child: Text(s.replaceAll('_', ' '))),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const _NewExpenseScreen()),
        ).then((_) => _load(refresh: true)),
        icon: const Icon(Icons.add),
        label: const Text('Submit'),
      ),
      body: _rows.isEmpty && _loading
          ? const ShimmerList()
          : _rows.isEmpty
              ? const EmptyWidget(message: 'No expenses')
              : RefreshIndicator(
                  onRefresh: () => _load(refresh: true),
                  child: ListView.builder(
                    controller: _scrollCtrl,
                    itemCount: _rows.length + (_hasMore ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (i == _rows.length) {
                        return const Padding(
                            padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
                      }
                      final e = _rows[i];
                      return Card(
                        child: ListTile(
                          title: Text(e.payee, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${e.expenseNumber} · ${e.category.replaceAll('_', ' ')}'),
                              Text(e.date, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                          isThreeLine: true,
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(_zmw.format(e.totalAmount),
                                  style: const TextStyle(fontWeight: FontWeight.bold)),
                              StatusChip(label: e.status, color: _statusColor(e.status)),
                            ],
                          ),
                          onTap: () => _showDetail(e),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  void _showDetail(Expense e) {
    final user = context.read<AuthProvider>().user!;
    final isFinance = user.isAdmin || user.isAccounts;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(e.payee, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text('${e.expenseNumber}${e.voucherNumber != null ? ' · ${e.voucherNumber}' : ''}',
                style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 10),
            StatusChip(label: e.status, color: _statusColor(e.status)),
            const Divider(height: 24),
            InfoRow(icon: Icons.category, label: 'Category', value: e.category.replaceAll('_', ' ')),
            InfoRow(icon: Icons.calendar_today, label: 'Date', value: e.date),
            InfoRow(icon: Icons.payments, label: 'Total', value: _zmw.format(e.totalAmount)),
            InfoRow(icon: Icons.account_balance_wallet, label: 'Method',
                value: e.paymentMethod.replaceAll('_', ' ')),
            if (e.description != null) InfoRow(icon: Icons.notes, label: 'Description', value: e.description!),
            if (e.submittedByName != null)
              InfoRow(icon: Icons.person, label: 'Submitted by', value: e.submittedByName!),
            if (e.rejectionReason != null)
              InfoRow(icon: Icons.block, label: 'Rejection reason', value: e.rejectionReason!),
            if (e.status == 'pending')
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Awaiting approval — see the Approvals screen.',
                    style: TextStyle(fontSize: 12, color: Colors.orange)),
              ),
            if (isFinance && (e.status == 'approved' || e.status == 'payment_initiated')) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  if (e.status == 'approved')
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () { Navigator.pop(ctx); _setStatus(e, 'payment_initiated'); },
                        child: const Text('Initiate payment'),
                      ),
                    ),
                  if (e.status == 'approved') const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () { Navigator.pop(ctx); _setStatus(e, 'paid'); },
                      child: const Text('Mark paid'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _setStatus(Expense e, String status) async {
    try {
      await _api.put('${ApiConstants.expenses}/${e.id}', data: {'status': status});
      _load(refresh: true);
    } on DioException catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_dioMessage(err)), backgroundColor: Colors.red));
      }
    }
  }
}

class _NewExpenseScreen extends StatefulWidget {
  const _NewExpenseScreen();

  @override
  State<_NewExpenseScreen> createState() => _NewExpenseScreenState();
}

class _NewExpenseScreenState extends State<_NewExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _api = ApiClient().dio;
  final _payeeCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _vatCtrl = TextEditingController(text: '0');
  final _descCtrl = TextEditingController();
  final _dateCtrl = TextEditingController(text: DateFormat('yyyy-MM-dd').format(DateTime.now()));
  String _category = 'other';
  String _method = 'cash';
  bool _saving = false;

  @override
  void dispose() {
    _payeeCtrl.dispose();
    _amountCtrl.dispose();
    _vatCtrl.dispose();
    _descCtrl.dispose();
    _dateCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final res = await _api.post(ApiConstants.expenses, data: {
        'date': _dateCtrl.text,
        'category': _category,
        'payee': _payeeCtrl.text.trim(),
        'amount': _parseMoney(_amountCtrl.text),
        'vatAmount': _parseMoney(_vatCtrl.text),
        'paymentMethod': _method,
        if (_descCtrl.text.isNotEmpty) 'description': _descCtrl.text.trim(),
      });
      if (!mounted) return;
      final status = res.data['status'];
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(status == 'approved'
            ? 'Expense ${res.data['expenseNumber']} approved'
            : 'Expense ${res.data['expenseNumber']} submitted for approval'),
      ));
      Navigator.pop(context);
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_dioMessage(e)), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Unexpected error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Submit Expense')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _payeeCtrl,
                decoration: const InputDecoration(labelText: 'Payee *'),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: expenseCategories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c.replaceAll('_', ' '))))
                    .toList(),
                onChanged: (v) => setState(() => _category = v!),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: TextFormField(
                    controller: _amountCtrl,
                    decoration: const InputDecoration(labelText: 'Amount (ZMW) *'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Required';
                      return _parseMoney(v) > 0 ? null : 'Enter a valid amount';
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _vatCtrl,
                    decoration: const InputDecoration(labelText: 'VAT (ZMW)'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _method,
                decoration: const InputDecoration(labelText: 'Payment method'),
                items: ['cash', 'bank_transfer', 'cheque', 'mobile_money', 'other']
                    .map((m) => DropdownMenuItem(value: m, child: Text(m.replaceAll('_', ' '))))
                    .toList(),
                onChanged: (v) => setState(() => _method = v!),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _dateCtrl,
                readOnly: true,
                decoration: const InputDecoration(labelText: 'Date', suffixIcon: Icon(Icons.calendar_today)),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now().subtract(const Duration(days: 90)),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) _dateCtrl.text = DateFormat('yyyy-MM-dd').format(picked);
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descCtrl,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 2,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: _saving
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(onPressed: _submit, child: const Text('Submit for approval')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
