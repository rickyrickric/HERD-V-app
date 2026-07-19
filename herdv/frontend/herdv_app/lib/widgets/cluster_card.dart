// frontend/herdv_app/lib/widgets/cluster_card.dart
import 'package:flutter/material.dart';
import '../utils/herd_metrics.dart';

class ClusterCard extends StatelessWidget {
  final String title;
  final int count;
  final Map<String, dynamic> means;
  final String recommendation;
  final VoidCallback onTap;

  /// The cluster id, used to draw the shared cluster color badge.
  final dynamic clusterId;

  const ClusterCard(
      {super.key,
      required this.title,
      required this.count,
      required this.means,
      required this.recommendation,
      required this.onTap,
      this.clusterId});

  @override
  Widget build(BuildContext context) {
    final badge = clusterColor(clusterId ?? means['cluster_id'] ?? means['id']);
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                CircleAvatar(radius: 8, backgroundColor: badge),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(title,
                        style: const TextStyle(fontWeight: FontWeight.bold))),
                const SizedBox(width: 8),
                Chip(
                    label: Text('$count'), visualDensity: VisualDensity.compact)
              ]),
              const SizedBox(height: 6),
              Text(
                  'Milk: ${fmt(means['Milk_Yield'])} • Fertility: ${fmt(means['Fertility_Score'])} • Parasites: ${fmt(means['Parasite_Load_Index'])}'),
              if (recommendation.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(recommendation,
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
