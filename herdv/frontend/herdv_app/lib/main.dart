// frontend/herdv_app/lib/main.dart
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'screens/dashboard_screen.dart';
import 'screens/import_screen.dart';
import 'screens/cluster_insights_screen.dart';
import 'screens/animal_list_screen.dart';
import 'screens/animal_detail_screen.dart';
import 'screens/health_screen.dart';
import 'state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('herdv_cache');

  // ✅ preload cached state before app starts
  final app = AppState();
  app.loadCache();

  runApp(const HerdVApp());
}

class HerdVApp extends StatelessWidget {
  const HerdVApp({super.key});

  @override
  Widget build(BuildContext context) {
    final earthy = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF6B8E23), // olive green
      ),
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFFF6F2E8), // warm parchment
    );

    return MaterialApp(
      title: 'HERD‑V',
      debugShowCheckedModeBanner: false,
      theme: earthy,
      initialRoute: '/dashboard',
      routes: {
        '/dashboard': (_) => const DashboardScreen(),
        '/import': (_) => const ImportScreen(),
        '/clusters': (_) => const ClusterInsightsScreen(),
        '/health': (_) => const HealthScreen(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/animals') {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (_) => AnimalListScreen(
              clusterId: args['clusterId'],
              clusterName: args['clusterName'],
            ),
          );
        }
        if (settings.name == '/animal_detail') {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (_) => AnimalDetailScreen(animal: args['animal']),
          );
        }
        return null;
      },
    );
  }
}
