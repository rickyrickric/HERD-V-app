// frontend/herdv_app/lib/state/app_state.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

class AppState extends ChangeNotifier {
  static final AppState _instance = AppState._internal();
  factory AppState() => _instance;
  AppState._internal();

  List<Map<String, dynamic>> _records = [];
  Map<String, dynamic> _kpis = {};
  Map<String, dynamic> _prevKpis = {};
  List<dynamic> _clusters = [];
  List<dynamic> _assignments = [];
  String? dendrogramUrl; // computed from backend base

  List<Map<String, dynamic>> get records => _records;
  Map<String, dynamic> get kpis => _kpis;

  /// KPIs from the import prior to the current one, used to show deltas.
  Map<String, dynamic> get prevKpis => _prevKpis;
  List<dynamic> get clusters => _clusters;
  List<dynamic> get assignments => _assignments;

  set records(List<Map<String, dynamic>> v) {
    _records = v;
    notifyListeners();
  }

  set kpis(Map<String, dynamic> v) {
    // Snapshot the outgoing KPIs so the dashboard can show deltas vs last import.
    if (_kpis.isNotEmpty) _prevKpis = Map<String, dynamic>.from(_kpis);
    _kpis = v;
    notifyListeners();
  }

  set clusters(List<dynamic> v) {
    _clusters = v;
    notifyListeners();
  }

  set assignments(List<dynamic> v) {
    _assignments = v;
    notifyListeners();
  }

  void cache() {
    if (!Hive.isBoxOpen('herdv_cache')) return;
    final box = Hive.box('herdv_cache');
    box.put('records', jsonEncode(_records));
    box.put('kpis', jsonEncode(_kpis));
    box.put('prevKpis', jsonEncode(_prevKpis));
    box.put('clusters', jsonEncode(_clusters));
    box.put('assignments', jsonEncode(_assignments));
  }

  void loadCache() {
    if (!Hive.isBoxOpen('herdv_cache')) return;
    final box = Hive.box('herdv_cache');
    // records are expected to be List<Map<String, dynamic>>; decode defensively
    try {
      final decodedRecords = jsonDecode(box.get('records', defaultValue: '[]'));
      if (decodedRecords is List) {
        _records = decodedRecords.map<Map<String, dynamic>>((e) {
          if (e is Map) return Map<String, dynamic>.from(e);
          return <String, dynamic>{};
        }).toList();
      } else {
        _records = [];
      }
    } catch (_) {
      _records = [];
    }

    // kpis expected to be a map
    try {
      final decodedKpis = jsonDecode(box.get('kpis', defaultValue: '{}'));
      if (decodedKpis is Map) {
        _kpis = Map<String, dynamic>.from(decodedKpis);
      } else {
        _kpis = {};
      }
    } catch (_) {
      _kpis = {};
    }

    // previous-import kpis (for deltas); absent on first run
    try {
      final decodedPrev = jsonDecode(box.get('prevKpis', defaultValue: '{}'));
      _prevKpis = (decodedPrev is Map) ? Map<String, dynamic>.from(decodedPrev) : {};
    } catch (_) {
      _prevKpis = {};
    }

    // clusters and assignments can remain dynamic lists
    try {
      final decodedClusters =
          jsonDecode(box.get('clusters', defaultValue: '[]'));
      _clusters = (decodedClusters is List) ? decodedClusters : [];
    } catch (_) {
      _clusters = [];
    }

    try {
      final decodedAssignments =
          jsonDecode(box.get('assignments', defaultValue: '[]'));
      _assignments = (decodedAssignments is List) ? decodedAssignments : [];
    } catch (_) {
      _assignments = [];
    }
  }

  void clear() {
    _records = [];
    _kpis = {};
    _prevKpis = {};
    _clusters = [];
    _assignments = [];
    if (Hive.isBoxOpen('herdv_cache')) Hive.box('herdv_cache').clear();
    notifyListeners();
  }
}
