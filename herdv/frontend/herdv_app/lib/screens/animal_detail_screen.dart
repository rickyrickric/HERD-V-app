// frontend/herdv_app/lib/screens/animal_detail_screen.dart
import 'package:flutter/material.dart';
import '../state/app_state.dart';
import '../utils/herd_metrics.dart';

class AnimalDetailScreen extends StatelessWidget {
  final Map<String, dynamic> animal;
  const AnimalDetailScreen({super.key, required this.animal});

  @override
  Widget build(BuildContext context) {
    final app = AppState();
    // Score this animal against the current herd, not fixed thresholds.
    final stats = HerdStats.fromRecords(app.records);
    final level = stats.risk(animal);
    final reasons = stats.reasons(animal);
    final id = animal['ID'] ?? animal['id'] ?? animal['Tag'] ?? '—';

    return Scaffold(
      appBar: AppBar(title: Text('Animal $id')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // ---- Risk explanation card ----
          Card(
            color: level.color.withValues(alpha: 0.08),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                            color: level.color, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Text(level.label,
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: level.color)),
                  ]),
                  const SizedBox(height: 8),
                  if (reasons.isEmpty)
                    const Text(
                        'No metrics stand out against the rest of the herd.')
                  else ...[
                    const Text('Why:',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    ...reasons.map((r) => Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text('• $r'),
                        )),
                    const SizedBox(height: 8),
                    const Text('Suggested action:',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(_action(level)),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          // ---- Raw metrics ----
          ...animal.entries.map((e) => ListTile(
                dense: true,
                title: Text('${e.key}'),
                trailing: Text(_display(e.value)),
              )),
        ],
      ),
    );
  }

  // Round only non-integer doubles; leave ints, bools, and strings as-is.
  String _display(dynamic v) {
    if (v == null) return '';
    if (v is double) return v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);
    return v.toString();
  }

  String _action(RiskLevel level) {
    switch (level) {
      case RiskLevel.atRisk:
        return 'Prioritize a veterinary check; review parasite control, '
            'nutrition, and reproductive status.';
      case RiskLevel.watch:
        return 'Monitor closely over the next days and recheck the flagged '
            'metric before it worsens.';
      case RiskLevel.none:
        return 'Maintain current management and routine monitoring.';
    }
  }
}
