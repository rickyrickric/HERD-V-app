// frontend/herdv_app/lib/widgets/cluster_card.dart
import 'package:flutter/material.dart';

class ClusterCard extends StatelessWidget {
  final String title;
  final int count;
  final Map<String, dynamic> means;
  final String recommendation;
  final VoidCallback onTap;
  const ClusterCard(
      {super.key,
      required this.title,
      required this.count,
      required this.means,
      required this.recommendation,
      required this.onTap});

  Color healthColor(Map<String, dynamic> m) {
    int risks = 0;
    final pli = (m['Parasite_Load_Index'] ?? 0).toDouble();
    final temp = (m['Ear_Temperature_C'] ?? 0).toDouble();
    final resp = (m['Respiration_Rate_BPM'] ?? 0).toDouble();
    final fert = (m['Fertility_Score'] ?? 0).toDouble();
    if (pli > 0.6) risks++;
    if (temp > 39.5 && resp > 35) risks++;
    if (fert < 0.4) risks++;
    if (risks >= 2) return Colors.red;
    if (risks == 1) return Colors.orange;
    return Colors.green;
  }

  Color clusterColor(dynamic id) {
    if (id == null) return Colors.grey;
    final i = (id is int) ? id : int.tryParse(id.toString()) ?? 0;
    return Colors.primaries[i % Colors.primaries.length];
  }

  @override
  Widget build(BuildContext context) {
    final badge = clusterColor((means['cluster_id'] ?? means['id']));
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.agriculture, size: 18),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(title,
                        style: const TextStyle(fontWeight: FontWeight.bold))),
                const SizedBox(width: 8),
                CircleAvatar(radius: 8, backgroundColor: badge),
                const SizedBox(width: 8),
                Chip(
                    label: Text('$count'), visualDensity: VisualDensity.compact)
              ]),
              const SizedBox(height: 6),
              Text(
                  'Milk: ${means['Milk_Yield']?.toStringAsFixed(2) ?? '--'} • Fertility: ${means['Fertility_Score']?.toStringAsFixed(2) ?? '--'} • Parasites: ${means['Parasite_Load_Index']?.toStringAsFixed(2) ?? '--'}'),
              const SizedBox(height: 6),
              Text(recommendation,
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}
