import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_client.dart';
import '../../core/api/api_constants.dart';
import '../../models/quotation.dart';
import '../../widgets/common_widgets.dart';

final _zmw = NumberFormat.currency(locale: 'en_ZM', symbol: 'ZMW ', decimalDigits: 2);

class QuotationsScreen extends StatefulWidget {
  const QuotationsScreen({super.key});

  @override
  State<QuotationsScreen> createState() => _QuotationsScreenState();
}

class _QuotationsScreenState extends State<QuotationsScreen> {
  final _api = ApiClient().dio;
  final _scrollCtrl = ScrollController();

  List<Quotation> _rows = [];
  bool _loading = false;
  bool _hasMore = true;
  int _page = 1;
  String? _status;

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
    if (refresh) { _page = 1; _hasMore = true; }
    setState(() => _loading = true);
    try {
      final res = await _api.get(ApiConstants.quotations, queryParameters: {
        'page': _page, 'limit': 20,
        if (_status != null) 'status': _status,
      });
      final data = res.data;
      final items = (data['data'] ?? []) as List;
      final totalPages = data is Map ? (data['pages'] ?? 1) : 1;
      setState(() {
        if (refresh) _rows = [];
        _rows.addAll(items.map((j) => Quotation.fromJson(j)));
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
        title: const Text('Quotations'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (v) { setState(() => _status = v.isEmpty ? null : v); _load(refresh: true); },
            itemBuilder: (_) => [
              const PopupMenuItem(value: '', child: Text('All')),
              for (final s in ['draft', 'sent', 'accepted', 'rejected', 'converted'])
                PopupMenuItem(value: s, child: Text(s)),
            ],
          ),
        ],
      ),
      body: _rows.isEmpty && _loading
          ? const ShimmerList()
          : _rows.isEmpty
              ? const EmptyWidget(message: 'No quotations')
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
                      final q = _rows[i];
                      return Card(
                        child: ListTile(
                          title: Text(q.quotationNumber, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(q.clientName ?? q.prospectName ?? '—'),
                              Text('Issued ${q.issueDate} · expires ${q.expiryDate}',
                                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                          isThreeLine: true,
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(_zmw.format(q.totalAmount),
                                  style: const TextStyle(fontWeight: FontWeight.bold)),
                              StatusChip(label: q.status),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
