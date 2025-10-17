// frontend/herdv_app/lib/screens/cluster_insights_screen.dart
import 'package:flutter/material.dart';
import '../state/app_state.dart';
import '../widgets/cluster_card.dart';
import '../widgets/charts.dart';
import 'dart:convert';
import 'dart:io' as io;
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import '../services/api_client.dart';

class ClusterInsightsScreen extends StatefulWidget {
  const ClusterInsightsScreen({super.key});
  @override
  State<ClusterInsightsScreen> createState() => _ClusterInsightsScreenState();
}

class _ClusterInsightsScreenState extends State<ClusterInsightsScreen> {
  final app = AppState();
  final api = ApiClient('http://localhost:8000');

  // Dendrogram removed per request

  @override
  void initState() {
    super.initState();
    app.addListener(_onAppChanged);
  }

  void _onAppChanged() => setState(() {});

  // Dendrogram methods removed

  @override
  void dispose() {
    app.removeListener(_onAppChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clusters = app.clusters;
    return Scaffold(
      appBar: AppBar(title: const Text('Cluster Insights')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // ---- Overview ----
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Overview',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(spacing: 12, runSpacing: 8, children: [
                      Chip(label: Text('Clusters: ${clusters.length}')),
                      GestureDetector(
                        onTap: () {
                          Navigator.pushNamed(context, '/animals', arguments: {
                            'clusterId': null,
                            'clusterName': null,
                            'scrollToTop': true,
                            'highlightImported': true,
                          });
                        },
                        child: Chip(
                            label:
                                Text('Total Animals: ${app.records.length}')),
                      ),
                      if (app.kpis.isNotEmpty &&
                          app.kpis['average_Milk_Yield'] != null)
                        Chip(
                            label: Text(
                                'Avg Milk: ${app.kpis['average_Milk_Yield'].toString()}')),
                      if (app.kpis.isNotEmpty &&
                          app.kpis['average_Fertility_Score'] != null)
                        Chip(
                            label: Text(
                                'Avg Fertility: ${app.kpis['average_Fertility_Score'].toString()}')),
                    ])
                  ]),
            ),
          ),
          const SizedBox(height: 12),

          // ---- Charts: Pie and Scatter--
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: LayoutBuilder(builder: (ctx, constr) {
                final narrow = constr.maxWidth < 700;
                if (narrow) {
                  return Column(children: [
                    ClusterDistributionPieChart(
                        clusters: clusters, title: 'Cluster Distribution'),
                    const SizedBox(height: 12),
                    ScatterMilkFertility(
                        clusters: clusters, title: 'Milk Yield vs Fertility')
                  ]);
                }
                return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                          flex: 3,
                          child: ClusterDistributionPieChart(
                              clusters: clusters,
                              title: 'Cluster Distribution')),
                      const SizedBox(width: 12),
                      Expanded(
                          flex: 4,
                          child: ScatterMilkFertility(
                              clusters: clusters,
                              title: 'Milk Yield vs Fertility')),
                    ]);
              }),
            ),
          ),
          const SizedBox(height: 12),
          // ---- Clusters ----
          const Text('Clusters', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...clusters.map<Widget>((c) => ClusterCard(
                title: 'Cluster ${c['cluster_id']}',
                count: c['count'],
                means: c['means'],
                recommendation: c['recommendation'],
                onTap: () => Navigator.pushNamed(context, '/animals',
                    arguments: {
                      'clusterId': c['cluster_id'],
                      'clusterName': c['name']
                    }),
              )),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child: ElevatedButton.icon(
                      onPressed: () async {
                        // Prefer exporting the current in-memory dataset so any
                        // locally-added animals are included. Fall back to the
                        // server export when no records are loaded.
                        try {
                          if (app.records.isNotEmpty) {
                            final headers = app.records.first.keys
                                .map((k) => k.toString())
                                .toList();
                            final rows = <List<dynamic>>[];
                            rows.add(headers);
                            for (final r in app.records) {
                              rows.add(headers.map((h) => r[h] ?? '').toList());
                            }
                            final csv =
                                const ListToCsvConverter().convert(rows);
                            final bytes = utf8.encode(csv);
                            // Show dialog with options to view or save
                            await showDialog<void>(
                                context: context,
                                builder: (_) => AlertDialog(
                                      title: const Text('Exported Dataset CSV'),
                                      content: SingleChildScrollView(
                                          child: SelectableText(csv)),
                                      actions: [
                                        TextButton(
                                            onPressed: () => Navigator.pop(_),
                                            child: const Text('Close')),
                                        TextButton(
                                            onPressed: () async {
                                              Navigator.pop(_);
                                              try {
                                                final dir =
                                                    await getApplicationDocumentsDirectory();
                                                final ts = DateTime.now()
                                                    .toIso8601String()
                                                    .replaceAll(':', '-');
                                                final path =
                                                    '${dir.path}/herd_export_$ts.csv';
                                                final file = io.File(path);
                                                await file.writeAsBytes(bytes);
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(SnackBar(
                                                        content: Text(
                                                            'Saved CSV to $path')));
                                              } catch (e) {
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(SnackBar(
                                                        content: Text(
                                                            'Save failed: $e')));
                                              }
                                            },
                                            child:
                                                const Text('Save to device')),
                                      ],
                                    ));
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text(
                                    'Exported CSV — ${bytes.length} bytes')));
                          } else {
                            final bytes = await api.downloadAssignmentsCsv();
                            final csv = utf8.decode(bytes);
                            await showDialog<void>(
                                context: context,
                                builder: (_) => AlertDialog(
                                      title: const Text(
                                          'Exported Assignments CSV'),
                                      content: SingleChildScrollView(
                                          child: SelectableText(csv)),
                                      actions: [
                                        TextButton(
                                            onPressed: () => Navigator.pop(_),
                                            child: const Text('Close')),
                                        TextButton(
                                            onPressed: () async {
                                              Navigator.pop(_);
                                              try {
                                                final dir =
                                                    await getApplicationDocumentsDirectory();
                                                final ts = DateTime.now()
                                                    .toIso8601String()
                                                    .replaceAll(':', '-');
                                                final path =
                                                    '${dir.path}/herd_export_$ts.csv';
                                                final file = io.File(path);
                                                await file.writeAsBytes(bytes);
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(SnackBar(
                                                        content: Text(
                                                            'Saved CSV to $path')));
                                              } catch (e) {
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(SnackBar(
                                                        content: Text(
                                                            'Save failed: $e')));
                                              }
                                            },
                                            child: const Text('Save to device'))
                                      ],
                                    ));
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text(
                                    'Exported CSV — ${bytes.length} bytes')));
                          }
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Export failed: $e')));
                        }
                      },
                      icon: const Icon(Icons.download),
                      label: const Text('Export CSV'))),
              const SizedBox(width: 8),
              Expanded(
                  child: ElevatedButton.icon(
                      onPressed: () async {
                        final bytes =
                            await api.exportRecommendations(format: 'pdf');
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content:
                                Text('Exported PDF — ${bytes.length} bytes')));
                      },
                      icon: const Icon(Icons.picture_as_pdf),
                      label: const Text('Export PDF'))),
            ],
          ),
        ],
      ),
    );
  }
}
