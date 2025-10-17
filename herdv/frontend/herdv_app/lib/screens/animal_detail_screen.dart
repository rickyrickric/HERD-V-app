// frontend/herdv_app/lib/screens/animal_detail_screen.dart
import 'package:flutter/material.dart';

class AnimalDetailScreen extends StatelessWidget {
  final Map<String, dynamic> animal;
  const AnimalDetailScreen({super.key, required this.animal});

  double _toDouble(dynamic v, [double fallback = 0]) {
    if (v == null) return fallback;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? fallback;
    return fallback;
  }

  Color riskColor(Map<String, dynamic> a) {
    int risks = 0;
    final pli = _toDouble(a['Parasite_Load_Index'], 0);
    final temp = _toDouble(a['Ear_Temperature_C'], 0);
    final resp = _toDouble(a['Respiration_Rate_BPM'], 0);
    final fert = _toDouble(a['Fertility_Score'], 1);
    if (pli > 0.6) risks++;
    if (temp > 39.5 && resp > 35) risks++;
    if (fert < 0.4) risks++; // heuristic
    if (risks >= 2) return Colors.red;
    if (risks == 1) return Colors.orange;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    final color = riskColor(animal);
    final id = animal['ID'] ?? animal['id'] ?? animal['Tag'] ?? '—';
    return Scaffold(
      appBar: AppBar(title: Text('Animal $id')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                  width: 16,
                  height: 16,
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              const Text('Risk Indicator')
            ]),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                children: animal.entries
                    .map((e) => ListTile(
                        title: Text('${e.key}'),
                        subtitle: Text('${e.value ?? ''}')))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
