// lib/screens/health_screen.dart
import 'package:flutter/material.dart';
import '../state/app_state.dart';

class HealthScreen extends StatefulWidget {
  const HealthScreen({super.key});

  @override
  State<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends State<HealthScreen> {
  final app = AppState();

  @override
  void initState() {
    super.initState();
    app.addListener(_onAppChanged);
  }

  void _onAppChanged() => setState(() {});

  @override
  void dispose() {
    app.removeListener(_onAppChanged);
    super.dispose();
  }

  Color riskColor(Map<String, dynamic> a) {
    int risks = 0;
    final pli = (a['Parasite_Load_Index'] ?? 0).toDouble();
    final temp = (a['Ear_Temperature_C'] ?? 0).toDouble();
    final resp = (a['Respiration_Rate_BPM'] ?? 0).toDouble();
    final fert = (a['Fertility_Score'] ?? 0).toDouble();
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
    final animals = app.assignments;

    return Scaffold(
      appBar: AppBar(title: const Text('Herd Health Overview')),
      body: ListView.builder(
        itemCount: animals.length,
        itemBuilder: (_, i) {
          final a = animals[i];
          return ListTile(
            leading:
                Text('🐄', style: TextStyle(color: riskColor(a), fontSize: 22)),
            title: Text('Animal ${a['ID']}'),
            subtitle: Text('Cluster ${a['cluster_id']}'),
          );
        },
      ),
    );
  }
}
