// lib/screens/health_screen.dart
import 'package:flutter/material.dart';
import '../state/app_state.dart';
import '../utils/herd_metrics.dart';

class HealthScreen extends StatefulWidget {
  const HealthScreen({super.key});

  @override
  State<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends State<HealthScreen> {
  final app = AppState();
  bool _sortByRisk = true;

  @override
  void initState() {
    super.initState();
    app.addListener(_onAppChanged);
  }

  void _onAppChanged() => setState(() {});

  @override
  void dispose() {
    app.removeListener(_onAppChanged);
    super.dispose();
  }

  int? _clusterOf(Map<String, dynamic> a) {
    final v = a['cluster_id'] ?? a['Cluster'] ?? a['cluster'];
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    // Prefer full records (they carry the health metrics); fall back to
    // assignments only when records are unavailable.
    final source = app.records.isNotEmpty ? app.records : <Map<String, dynamic>>[];
    final stats = HerdStats.fromRecords(source);

    final animals = List<Map<String, dynamic>>.from(source);
    if (_sortByRisk) {
      animals.sort((a, b) =>
          stats.risk(b).severity.compareTo(stats.risk(a).severity));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Herd Health Overview'),
        actions: [
          IconButton(
            tooltip: _sortByRisk ? 'Sorted by risk' : 'Sort by risk',
            icon: Icon(_sortByRisk ? Icons.warning_amber : Icons.sort),
            onPressed: () => setState(() => _sortByRisk = !_sortByRisk),
          ),
        ],
      ),
      body: animals.isEmpty
          ? const Center(child: Text('Import a herd to see health status'))
          : Column(
              children: [
                _legend(),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    itemCount: animals.length,
                    itemBuilder: (_, i) {
                      final a = animals[i];
                      final level = stats.risk(a);
                      final reasons = stats.reasons(a);
                      final cid = _clusterOf(a);
                      return ListTile(
                        leading: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                              color: level.color, shape: BoxShape.circle),
                        ),
                        title: Text('Animal ${a['ID'] ?? a['id'] ?? '—'}'),
                        subtitle: Text(reasons.isEmpty
                            ? (cid != null ? 'Cluster $cid • healthy' : 'healthy')
                            : reasons.join(' • ')),
                        trailing: Text(level.label,
                            style: TextStyle(
                                color: level.color,
                                fontWeight: FontWeight.w600)),
                        onTap: () => Navigator.pushNamed(
                            context, '/animal_detail',
                            arguments: {'animal': Map<String, dynamic>.from(a)}),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _legend() {
    Widget dot(RiskLevel l) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 12,
                height: 12,
                decoration:
                    BoxDecoration(color: l.color, shape: BoxShape.circle)),
            const SizedBox(width: 4),
            Text(l.label, style: const TextStyle(fontSize: 12)),
          ]),
        );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [dot(RiskLevel.none), dot(RiskLevel.watch), dot(RiskLevel.atRisk)],
      ),
    );
  }
}
