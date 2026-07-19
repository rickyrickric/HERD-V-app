// frontend/herdv_app/lib/widgets/kpi_card.dart
import 'package:flutter/material.dart';

class KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  /// Optional status color (green/amber/red). When null the card is neutral.
  final Color? status;

  /// Optional short delta note vs. previous import, e.g. "+1.2 vs last".
  final String? delta;

  const KpiCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.status,
    this.delta,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFE9E2CF),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF8B6F47)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  Row(
                    children: [
                      if (status != null) ...[
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: status,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Flexible(
                        child: Text(value,
                            style: const TextStyle(fontSize: 18)),
                      ),
                    ],
                  ),
                  if (delta != null)
                    Text(delta!,
                        style: TextStyle(
                            fontSize: 11, color: Colors.brown.shade400)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
