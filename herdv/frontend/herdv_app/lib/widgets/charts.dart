// frontend/herdv_app/lib/widgets/charts.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../utils/herd_metrics.dart';

class ClusterMeansBarChart extends StatelessWidget {
  final List<dynamic> clusters;
  final String metricKey;
  final String? title;
  const ClusterMeansBarChart(
      {super.key, required this.clusters, required this.metricKey, this.title});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(title!,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            SizedBox(
              height: 200,
              child: Padding(
                // extra horizontal padding prevents labels from touching card edges
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: BarChart(
                  BarChartData(
                    titlesData: FlTitlesData(
                      show: true,
                      leftTitles: AxisTitles(
                        sideTitles:
                            SideTitles(showTitles: true, reservedSize: 40),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 28,
                          getTitlesWidget: (v, meta) {
                            final idx = v.toInt();
                            return Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4.0),
                              child: Text('C$idx'),
                            );
                          },
                        ),
                      ),
                    ),
                    barGroups: clusters.map<BarChartGroupData>((c) {
                      final id = c['cluster_id'] as int;
                      final val = (c['means'][metricKey] ?? 0.0) as double;
                      return BarChartGroupData(
                        x: id,
                        barRods: [
                          BarChartRodData(
                              toY: val, color: const Color(0xFF6B8E23))
                        ],
                      );
                    }).toList(),
                    gridData: FlGridData(show: true),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One bubble per cluster on a Milk-Yield (x) vs Fertility (y) plane.
/// Bubbles are NOT connected by a line: clusters are categorical, so a line
/// would imply a false 0→1→2→3 ordering. Bubble size encodes population and
/// color matches the cluster color used elsewhere in the app.
class ScatterMilkFertility extends StatelessWidget {
  final List<dynamic> clusters;
  final String? title;
  const ScatterMilkFertility({super.key, required this.clusters, this.title});

  @override
  Widget build(BuildContext context) {
    final entries = <({double milk, double fert, int count, int id})>[];
    for (final c in clusters) {
      final means = (c['means'] is Map) ? c['means'] as Map : const {};
      entries.add((
        milk: toDouble(means['Milk_Yield']),
        fert: toDouble(means['Fertility_Score']),
        count: (c['count'] is num) ? (c['count'] as num).toInt() : 0,
        id: (c['cluster_id'] is num) ? (c['cluster_id'] as num).toInt() : 0,
      ));
    }

    if (entries.isEmpty) {
      return _wrap(context, const SizedBox(
          height: 200, child: Center(child: Text('No cluster data'))));
    }

    final maxCount =
        entries.map((e) => e.count).fold<int>(1, (a, b) => a > b ? a : b);

    final spots = entries.map((e) {
      // Scale radius 8..24 by population so a bubble can't imply ordering.
      final radius = 8.0 + (maxCount == 0 ? 0 : e.count / maxCount) * 16.0;
      return ScatterSpot(
        e.milk,
        e.fert,
        dotPainter: FlDotCirclePainter(
          radius: radius,
          color: clusterColor(e.id).withValues(alpha: 0.75),
          strokeWidth: 1.5,
          strokeColor: Colors.white,
        ),
      );
    }).toList();

    double reduceX(bool Function(double, double) pick, double seed) =>
        entries.map((e) => e.milk).fold(seed, (a, b) => pick(a, b) ? a : b);
    double reduceY(bool Function(double, double) pick, double seed) =>
        entries.map((e) => e.fert).fold(seed, (a, b) => pick(a, b) ? a : b);

    final minX = reduceX((a, b) => a < b, double.infinity);
    final maxX = reduceX((a, b) => a > b, double.negativeInfinity);
    final minY = reduceY((a, b) => a < b, double.infinity);
    final maxY = reduceY((a, b) => a > b, double.negativeInfinity);
    final xPad = (maxX - minX) == 0 ? 1.0 : (maxX - minX) * 0.18;
    final yPad = (maxY - minY) == 0 ? 1.0 : (maxY - minY) * 0.25;

    final chart = SizedBox(
      height: 220,
      child: Padding(
        padding: const EdgeInsets.only(top: 8, right: 8),
        child: ScatterChart(
          ScatterChartData(
            scatterSpots: spots,
            minX: minX - xPad,
            maxX: maxX + xPad,
            minY: minY - yPad,
            maxY: maxY + yPad,
            titlesData: FlTitlesData(
              show: true,
              topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(
                axisNameWidget: const Text('Fertility',
                    style: TextStyle(fontSize: 11)),
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  getTitlesWidget: (v, meta) =>
                      Text(v.toStringAsFixed(1),
                          style: const TextStyle(fontSize: 10)),
                ),
              ),
              bottomTitles: AxisTitles(
                axisNameWidget: const Text('Milk Yield',
                    style: TextStyle(fontSize: 11)),
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  getTitlesWidget: (v, meta) =>
                      Text(v.toStringAsFixed(0),
                          style: const TextStyle(fontSize: 10)),
                ),
              ),
            ),
            gridData: const FlGridData(show: true),
            borderData: FlBorderData(show: true),
            scatterTouchData: ScatterTouchData(enabled: false),
          ),
        ),
      ),
    );

    // Legend so each bubble color/size is readable.
    final legend = Wrap(
      spacing: 12,
      runSpacing: 4,
      children: entries.map((e) {
        return Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
                color: clusterColor(e.id), shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text('Cluster ${e.id} (${e.count})',
              style: const TextStyle(fontSize: 11)),
        ]);
      }).toList(),
    );

    return _wrap(
        context,
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          chart,
          const SizedBox(height: 8),
          legend,
        ]));
  }

  Widget _wrap(BuildContext context, Widget child) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(title!,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            child,
          ],
        ),
      ),
    );
  }
}

class ClusterDistributionPieChart extends StatelessWidget {
  final List<dynamic> clusters;
  final String? title;
  const ClusterDistributionPieChart(
      {super.key, required this.clusters, this.title});

  @override
  Widget build(BuildContext context) {
    final total =
        clusters.fold<int>(0, (s, c) => s + ((c['count'] ?? 0) as int));
    if (total == 0) return const SizedBox.shrink();
    // Build counts and determine largest cluster index
    final counts = clusters.map<int>((c) => (c['count'] ?? 0) as int).toList();
    int maxIndex = 0;
    for (int i = 1; i < counts.length; i++)
      if (counts[i] > counts[maxIndex]) maxIndex = i;

    final sections = List<PieChartSectionData>.generate(clusters.length, (i) {
      final cnt = (clusters[i]['count'] ?? 0) as int;
      final perc = total == 0 ? 0.0 : (cnt / total * 100);
      final cid = (clusters[i]['cluster_id'] ?? clusters[i]['id'] ?? i);
      final color = clusterColor(cid);
      final isLargest = i == maxIndex;
      return PieChartSectionData(
        value: cnt.toDouble(),
        color: color,
        title: '${perc.toStringAsFixed(0)}%',
        titleStyle: const TextStyle(
            fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
        radius: isLargest ? 66 : 52,
        // subtle white border to separate slices
        borderSide: const BorderSide(color: Colors.white, width: 1.4),
        // offset the largest slice slightly for exploded effect
        titlePositionPercentageOffset: isLargest ? 0.6 : 0.55,
      );
    });

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title ?? 'Cluster Distribution',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            LayoutBuilder(builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 500;
              final legend = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                      padding: EdgeInsets.only(bottom: 8.0),
                      child: Text('Clusters',
                          style: TextStyle(fontWeight: FontWeight.w600))),
                  ...List<Widget>.generate(clusters.length, (i) {
                    final c = clusters[i];
                    final cid = (c['cluster_id'] ?? c['id'] ?? i) as int;
                    final color = clusterColor(cid);
                    final name = c['name']?.toString() ?? 'Cluster ${cid}';
                    final cnt = (c['count'] ?? 0) as int;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6.0),
                      child: Row(children: [
                        Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.black12),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(name)),
                        const SizedBox(width: 8),
                        Text('${cnt}'),
                      ]),
                    );
                  })
                ],
              );

              final pie = SizedBox(
                width: isNarrow ? double.infinity : 220,
                height: 220,
                child: PhysicalModel(
                  color: Colors.transparent,
                  elevation: 6,
                  shadowColor: Colors.black12,
                  borderRadius: BorderRadius.circular(8),
                  child: PieChart(
                    PieChartData(
                      sections: sections,
                      centerSpaceRadius: 36,
                      sectionsSpace: 4,
                      startDegreeOffset: -90,
                    ),
                  ),
                ),
              );

              if (isNarrow) {
                return Column(
                    children: [pie, const SizedBox(height: 8), legend]);
              }

              return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    pie,
                    const SizedBox(width: 16),
                    Expanded(child: SingleChildScrollView(child: legend)),
                  ]);
            })
          ],
        ),
      ),
    );
  }
}
