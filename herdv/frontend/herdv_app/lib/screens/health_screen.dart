import 'package:flutter/material.dart';
import '../state/app_state.dart';

class HealthScreen extends StatelessWidget {
  const HealthScreen({super.key});

  Color riskColor(Map<String, dynamic> a) {
    int risks = 0;
    double pli = 0, temp = 0, resp = 0, fert = 1;
    try {
      pli = (a['Parasite_Load_Index'] ?? a['Parasite'] ?? 0).toDouble();
    } catch (_) {
      pli =
          double.tryParse('${a['Parasite_Load_Index'] ?? a['Parasite']}') ?? 0;
    }
    try {
      temp = (a['Ear_Temperature_C'] ?? 0).toDouble();
    } catch (_) {
      temp = double.tryParse('${a['Ear_Temperature_C']}') ?? 0;
    }
    try {
      resp = (a['Respiration_Rate_BPM'] ?? 0).toDouble();
    } catch (_) {
      resp = double.tryParse('${a['Respiration_Rate_BPM']}') ?? 0;
    }
    try {
      fert = (a['Fertility_Score'] ?? a['Fertility'] ?? 1).toDouble();
    } catch (_) {
      fert = double.tryParse('${a['Fertility_Score'] ?? a['Fertility']}') ?? 1;
    }

    // thresholds adapted to normalized indexes (PLI 0-1, Fertility 0-1)
    if (pli > 0.6) risks++;
    if (temp > 39.5 && resp > 35) risks++;
    if (fert < 0.4) risks++;
    if (risks >= 2) return Colors.red;
    if (risks == 1) return Colors.orange;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    final app = AppState();
    final animals = app.records.isNotEmpty ? app.records : app.assignments;

    return Scaffold(
      appBar: AppBar(title: const Text('Herd Health Overview')),
      body: animals.isEmpty
          ? const Center(child: Text('No animals loaded'))
          : ListView.builder(
              itemCount: animals.length,
              itemBuilder: (_, i) {
                final a = animals[i];
                final id = a['ID'] ?? a['id'] ?? a['Tag'] ?? '—';
                final cid =
                    a['cluster_id'] ?? a['Cluster'] ?? a['cluster'] ?? 'Null';
                return ListTile(
                  leading: Text('🐄',
                      style: TextStyle(color: riskColor(a), fontSize: 22)),
                  title: Text('Animal $id'),
                  subtitle: Text('Cluster ${cid ?? 'Null'}'),
                  onTap: () => Navigator.pushNamed(context, '/animal_detail',
                      arguments: {'animal': a}),
                );
              },
            ),
    );
  }
}
