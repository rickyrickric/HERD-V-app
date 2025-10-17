// frontend/herdv_app/lib/widgets/charts.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

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

class ScatterMilkFertility extends StatelessWidget {
  final List<dynamic> clusters;
  final String? title;
  const ScatterMilkFertility({super.key, required this.clusters, this.title});

  @override
  Widget build(BuildContext context) {
    final points = clusters.map((c) {
      final milk = (c['means']['Milk_Yield'] ?? 0.0) as double;
      final fert = (c['means']['Fertility_Score'] ?? 0.0) as double;
      return FlSpot(milk, fert);
    }).toList();

    double minX = points.isEmpty
        ? 0.0
        : points.map((p) => p.x).reduce((a, b) => a < b ? a : b);
    double maxX = points.isEmpty
        ? 1.0
        : points.map((p) => p.x).reduce((a, b) => a > b ? a : b);
    double minY = points.isEmpty
        ? 0.0
        : points.map((p) => p.y).reduce((a, b) => a < b ? a : b);
    double maxY = points.isEmpty
        ? 1.0
        : points.map((p) => p.y).reduce((a, b) => a > b ? a : b);
    final xPad = (maxX - minX) == 0
        ? 0.5
        : (maxX - minX) * 0.08; // 8% padding or default
    final yPad = (maxY - minY) == 0
        ? 0.5
        : (maxY - minY) * 0.12; // 12% padding for vertical labels

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
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: LineChart(
                  LineChartData(
                    minX: minX - xPad,
                    maxX: maxX + xPad,
                    minY: minY - yPad,
                    maxY: maxY + yPad,
                    lineBarsData: [
                      LineChartBarData(
                          spots: points,
                          isCurved: false,
                          dotData: FlDotData(show: true),
                          color: const Color(0xFF8B6F47))
                    ],
                    titlesData: FlTitlesData(
                      show: true,
                      leftTitles: AxisTitles(
                        sideTitles:
                            SideTitles(showTitles: true, reservedSize: 40),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles:
                            SideTitles(showTitles: true, reservedSize: 36),
                      ),
                    ),
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

    // Base color from theme (keeps app consistent)
    final base = Theme.of(context).colorScheme.primary;

    // Rank clusters by size to determine shade ordering
    final indexed = List<int>.generate(clusters.length, (i) => i);
    indexed.sort((a, b) => counts[b].compareTo(counts[a])); // descending
    final rank = <int, int>{};
    for (var i = 0; i < indexed.length; i++) rank[indexed[i]] = i;

    Color shadeForRank(int r) {
      final hsl = HSLColor.fromColor(base);
      final n = clusters.length;
      // dark to light range
      final dark = 0.28; // darkest lightness
      final light = 0.78; // lightest
      final t = n == 1 ? 0.0 : (r / (n - 1));
      final lightness = dark + t * (light - dark);
      return hsl.withLightness(lightness).toColor();
    }

    final sections = List<PieChartSectionData>.generate(clusters.length, (i) {
      final cnt = (clusters[i]['count'] ?? 0) as int;
      final perc = total == 0 ? 0.0 : (cnt / total * 100);
      final r = rank[i] ?? i;
      final color = shadeForRank(r);
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
                    final r = rank[i] ?? i;
                    final color = shadeForRank(r);
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
