import 'package:flutter/material.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_constants.dart';
import '../../models/kpi.dart';
import '../../widgets/common_widgets.dart';

class KpiScreen extends StatefulWidget {
  const KpiScreen({super.key});

  @override
  State<KpiScreen> createState() => _KpiScreenState();
}

class _KpiScreenState extends State<KpiScreen> {
  final _api = ApiClient().dio;
  List<KpiScore> _scores = [];
  KpiScorecardSummary? _summary;
  bool _loading = true;
  int _month = DateTime.now().month;
  int _year = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _api.get(ApiConstants.kpiScorecard, queryParameters: {
        'month': _month,
        'year': _year,
      });
      setState(() {
        _scores = (res.data['scores'] as List? ?? []).map((j) => KpiScore.fromJson(j)).toList();
        _summary = res.data['summary'] != null ? KpiScorecardSummary.fromJson(res.data['summary']) : null;
      });
    } catch (_) {} finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('KPI Scorecard'),
        actions: [
          TextButton(
            onPressed: _pickPeriod,
            child: Text('$_month/$_year', style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: _loading
          ? const LoadingWidget()
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_summary != null) _SummaryCard(summary: _summary!),
                  const SizedBox(height: 16),
                  if (_scores.isEmpty)
                    const EmptyWidget(message: 'No KPI scores for this period', icon: Icons.bar_chart)
                  else
                    ..._scores.map((s) => _ScoreCard(score: s)),
                ],
              ),
            ),
    );
  }

  Future<void> _pickPeriod() async {
    int month = _month;
    int year = _year;
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Select Period'),
        content: StatefulBuilder(
          builder: (_, ss) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                initialValue: month,
                decoration: const InputDecoration(labelText: 'Month'),
                items: List.generate(12, (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1}'))),
                onChanged: (v) => ss(() => month = v!),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: year,
                decoration: const InputDecoration(labelText: 'Year'),
                items: List.generate(5, (i) => DropdownMenuItem(value: DateTime.now().year - i,
                    child: Text('${DateTime.now().year - i}'))),
                onChanged: (v) => ss(() => year = v!),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() { _month = month; _year = year; });
              _load();
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final KpiScorecardSummary summary;
  const _SummaryCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final ratingColor = switch (summary.rating) {
      'excellent' => Colors.green,
      'good' => Colors.blue,
      'needs_improvement' => Colors.orange,
      _ => Colors.red,
    };
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(children: [
                  Text('${summary.overallScore.toStringAsFixed(1)}%',
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                  const Text('Overall Score'),
                ]),
                Column(children: [
                  Text('${summary.totalKPIs}',
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                  const Text('Total KPIs'),
                ]),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: ratingColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: ratingColor),
              ),
              child: Text(
                summary.rating.replaceAll('_', ' ').toUpperCase(),
                style: TextStyle(color: ratingColor, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreCard extends StatelessWidget {
  final KpiScore score;
  const _ScoreCard({required this.score});

  @override
  Widget build(BuildContext context) {
    final pct = (score.score ?? 0) / 100.0;
    final clampedPct = pct.clamp(0.0, 1.0);
    final barColor = pct >= 0.8
        ? Colors.green
        : pct >= 0.6
            ? Colors.blue
            : pct >= 0.4
                ? Colors.orange
                : Colors.red;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text(score.template?.name ?? 'KPI #${score.kpiTemplateId}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              Text(
                '${score.score?.toStringAsFixed(1) ?? '0'}%',
                style: TextStyle(fontWeight: FontWeight.bold, color: barColor, fontSize: 15),
              ),
            ]),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: clampedPct,
                minHeight: 6,
                backgroundColor: barColor.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _Stat('Target', score.target?.toStringAsFixed(1) ?? '-'),
                _Stat('Actual', score.actualPerformance?.toStringAsFixed(1) ?? '-'),
                _Stat('Score', score.score?.toStringAsFixed(1) ?? '-'),
                _Stat('Weight', score.weight?.toStringAsFixed(1) ?? '-'),
              ],
            ),
            if (score.supervisorComments != null) ...[
              const SizedBox(height: 6),
              Text('Supervisor: ${score.supervisorComments!}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat(this.label, this.value);

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          children: [
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      );
}
