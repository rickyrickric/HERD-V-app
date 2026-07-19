import 'package:flutter/material.dart';
import '../state/app_state.dart';
import '../services/import_service.dart';
import '../widgets/kpi_card.dart';
import '../utils/herd_metrics.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final app = AppState();

  @override
  void initState() {
    super.initState();
    app.loadCache();
    app.addListener(_onAppChanged);
  }

  void _onAppChanged() => setState(() {});

  @override
  void dispose() {
    app.removeListener(_onAppChanged);
    super.dispose();
  }

  /// Delta note + status color for a KPI vs the previous import.
  /// [higherIsBetter] flips the good/bad direction (e.g. parasite load).
  (Color?, String?) _statusFor(String key, {required bool higherIsBetter}) {
    final cur = app.kpis[key];
    final prev = app.prevKpis[key];
    if (cur == null || prev == null) return (null, null);
    final d = toDouble(cur) - toDouble(prev);
    if (d.abs() < 0.005) {
      return (const Color(0xFF2E7D32), 'no change vs last');
    }
    final improved = higherIsBetter ? d > 0 : d < 0;
    final sign = d > 0 ? '+' : '';
    final note = '$sign${d.toStringAsFixed(2)} vs last';
    return (
      improved ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
      note,
    );
  }

  @override
  Widget build(BuildContext context) {
    final records = app.records;
    final stats = HerdStats.fromRecords(records);
    final atRisk = records
        .where((r) => stats.risk(r) == RiskLevel.atRisk)
        .toList();

    final milk = _statusFor('average_Milk_Yield', higherIsBetter: true);
    final fert = _statusFor('average_Fertility_Score', higherIsBetter: true);
    final para = _statusFor('average_Parasite_Load_Index', higherIsBetter: false);
    final rem = _statusFor('average_Remaining_Months', higherIsBetter: true);

    return Scaffold(
      appBar: AppBar(title: const Text('HERD‑V Dashboard')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: KpiCard(
                    label: 'Avg Milk Yield',
                    value: fmt(app.kpis['average_Milk_Yield']),
                    icon: Icons.local_drink,
                    status: milk.$1,
                    delta: milk.$2,
                  ),
                ),
                Expanded(
                  child: KpiCard(
                    label: 'Avg Fertility',
                    value: fmt(app.kpis['average_Fertility_Score']),
                    icon: Icons.favorite,
                    status: fert.$1,
                    delta: fert.$2,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: KpiCard(
                    label: 'Avg Parasite Load',
                    value: fmt(app.kpis['average_Parasite_Load_Index']),
                    icon: Icons.bug_report,
                    status: para.$1,
                    delta: para.$2,
                  ),
                ),
                Expanded(
                  child: KpiCard(
                    label: 'Avg Remaining Months',
                    value: fmt(app.kpis['average_Remaining_Months']),
                    icon: Icons.calendar_today,
                    status: rem.$1,
                    delta: rem.$2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final ok = await pickAndImportCsv(context);
                      if (ok) setState(() {});
                    },
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Import CSV'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pushNamed(
                      context,
                      '/import',
                      arguments: {'mode': 'manual'},
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('Add animal'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pushNamed(context, '/health'),
                    icon: const Icon(Icons.health_and_safety),
                    label: const Text('Health'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(child: _atRiskPreview(atRisk, stats)),
            ElevatedButton.icon(
              onPressed: app.clusters.isEmpty
                  ? null
                  : () => Navigator.pushNamed(context, '/clusters'),
              icon: const Icon(Icons.insights),
              label: const Text('View Cluster Insights'),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: app.records.isEmpty ? null : _confirmClear,
              icon: Icon(Icons.delete_outline, color: Colors.red.shade700),
              label: Text('Clear / Reset',
                  style: TextStyle(color: Colors.red.shade700)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _atRiskPreview(List<Map<String, dynamic>> atRisk, HerdStats stats) {
    if (app.records.isEmpty) {
      return const Center(
        child: Text('Import a CSV to see herd insights',
            style: TextStyle(color: Colors.black54)),
      );
    }
    if (atRisk.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, color: Colors.green.shade600, size: 40),
            const SizedBox(height: 8),
            const Text('No at-risk animals in this herd'),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 4),
          child: Text('At-risk animals (${atRisk.length})',
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: Card(
            child: ListView.separated(
              itemCount: atRisk.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final a = atRisk[i];
                final id = a['ID'] ?? a['id'] ?? a['Tag'] ?? '—';
                final reasons = stats.reasons(a);
                return ListTile(
                  dense: true,
                  leading: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                        color: RiskLevel.atRisk.color,
                        shape: BoxShape.circle),
                  ),
                  title: Text('Animal $id'),
                  subtitle: Text(reasons.join(' • ')),
                  onTap: () {
                    final enriched = Map<String, dynamic>.from(a);
                    Navigator.pushNamed(context, '/animal_detail',
                        arguments: {'animal': enriched});
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmClear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear all data?'),
        content: const Text(
            'This removes the imported herd, clusters, and cached results from '
            'this device. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (ok == true) {
      setState(() => app.clear());
    }
  }
}
