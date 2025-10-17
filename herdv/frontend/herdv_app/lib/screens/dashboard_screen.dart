import 'package:flutter/material.dart';
import '../state/app_state.dart';
import '../services/import_service.dart';
import '../widgets/kpi_card.dart';

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

  @override
  Widget build(BuildContext context) {
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
                    value: app.kpis['average_Milk_Yield']?.toStringAsFixed(2) ??
                        '--',
                    icon: Icons.local_drink,
                  ),
                ),
                Expanded(
                  child: KpiCard(
                    label: 'Avg Fertility',
                    value: app.kpis['average_Fertility_Score']
                            ?.toStringAsFixed(2) ??
                        '--',
                    icon: Icons.favorite,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: KpiCard(
                    label: 'Avg Parasite Load',
                    value: app.kpis['average_Parasite_Load_Index']
                            ?.toStringAsFixed(2) ??
                        '--',
                    icon: Icons.bug_report,
                  ),
                ),
                Expanded(
                  child: KpiCard(
                    label: 'Avg Remaining Months',
                    value: app.kpis['average_Remaining_Months']
                            ?.toStringAsFixed(2) ??
                        '--',
                    icon: Icons.calendar_today,
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
                      // One-click import: pick file and import, then refresh UI
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
                ElevatedButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/health'),
                  icon: const Icon(Icons.health_and_safety),
                  label: const Text('Health Overview'),
                ),
              ],
            ),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: app.clusters.isEmpty
                  ? null
                  : () => Navigator.pushNamed(context, '/clusters'),
              icon: const Icon(Icons.insights),
              label: const Text('View Cluster Insights'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                setState(() {
                  app.clear();
                });
              },
              child: const Text('Clear/Reset'),
            ),
          ],
        ),
      ),
    );
  }
}
