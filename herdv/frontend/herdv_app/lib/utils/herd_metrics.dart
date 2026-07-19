// frontend/herdv_app/lib/utils/herd_metrics.dart
//
// Single source of truth for:
//  - number formatting (rounded display values)
//  - a consistent per-cluster color palette (donut, bubble chart, risk dots)
//  - HERD-RELATIVE risk scoring
//
// Why herd-relative: the backend returns RAW, unscaled values (e.g. a parasite
// load index of ~35-70, a fertility score of ~5-8). Older code compared these
// against 0-1 thresholds (`> 0.6`, `< 0.4`), which flagged every animal or none.
// Instead we compare each animal against the current herd's own distribution
// (mean +/- standard deviation), so "high" and "low" mean high/low *for this herd*.

import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Coerce any JSON-ish value to a double.
double toDouble(dynamic v, [double fallback = 0.0]) {
  if (v == null) return fallback;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.replaceAll(',', '').trim()) ?? fallback;
  return fallback;
}

/// Rounded display string, e.g. 6.699218750000001 -> "6.70".
String fmt(dynamic v, {int dp = 2, String dash = '--'}) {
  if (v == null) return dash;
  if (v is String && double.tryParse(v) == null) return v;
  return toDouble(v).toStringAsFixed(dp);
}

/// Consistent cluster color used everywhere a cluster is shown.
/// Earthy palette that matches the app theme; wraps for large k.
const List<Color> _clusterPalette = [
  Color(0xFF6B8E23), // olive
  Color(0xFF8B6F47), // brown
  Color(0xFF4E7C8A), // teal
  Color(0xFFB5651D), // ochre
  Color(0xFF7B6D8D), // muted purple
  Color(0xFF3F7D5B), // pine
  Color(0xFFC08552), // tan
  Color(0xFF5B7DB1), // slate blue
];

Color clusterColor(dynamic id) {
  if (id == null) return Colors.grey;
  final i = (id is int) ? id : int.tryParse(id.toString()) ?? 0;
  return _clusterPalette[i.abs() % _clusterPalette.length];
}

/// Risk severity for a single animal, evaluated against the herd.
enum RiskLevel { none, watch, atRisk }

extension RiskLevelColor on RiskLevel {
  /// Higher = more severe; used for sorting.
  int get severity {
    switch (this) {
      case RiskLevel.atRisk:
        return 2;
      case RiskLevel.watch:
        return 1;
      case RiskLevel.none:
        return 0;
    }
  }

  Color get color {
    switch (this) {
      case RiskLevel.atRisk:
        return const Color(0xFFC62828); // red
      case RiskLevel.watch:
        return const Color(0xFFEF8E29); // amber
      case RiskLevel.none:
        return const Color(0xFF2E7D32); // green
    }
  }

  String get label {
    switch (this) {
      case RiskLevel.atRisk:
        return 'At risk';
      case RiskLevel.watch:
        return 'Watch';
      case RiskLevel.none:
        return 'Healthy';
    }
  }
}

/// Per-metric mean and standard deviation across the herd.
class HerdStats {
  final Map<String, double> mean;
  final Map<String, double> std;
  final int n;

  HerdStats._(this.mean, this.std, this.n);

  /// Metrics we evaluate for risk. High-is-bad and low-is-bad handled in scoring.
  static const metrics = [
    'Parasite_Load_Index',
    'Ear_Temperature_C',
    'Respiration_Rate_BPM',
    'Fertility_Score',
    'Fecal_Egg_Count',
  ];

  factory HerdStats.fromRecords(List<dynamic> records) {
    final mean = <String, double>{};
    final std = <String, double>{};
    final n = records.length;
    for (final key in metrics) {
      final values = <double>[];
      for (final r in records) {
        if (r is Map && r.containsKey(key)) {
          values.add(toDouble(r[key]));
        }
      }
      if (values.isEmpty) {
        mean[key] = 0;
        std[key] = 0;
        continue;
      }
      final m = values.reduce((a, b) => a + b) / values.length;
      final variance =
          values.map((v) => (v - m) * (v - m)).reduce((a, b) => a + b) /
              values.length;
      mean[key] = m;
      std[key] = variance <= 0 ? 0 : math.sqrt(variance);
    }
    return HerdStats._(mean, std, n);
  }

  bool _above(Map<String, dynamic> a, String key) {
    final s = std[key] ?? 0;
    if (s == 0) return false; // uniform / single animal -> nothing stands out
    return toDouble(a[key]) >= (mean[key] ?? 0) + s;
  }

  bool _below(Map<String, dynamic> a, String key) {
    final s = std[key] ?? 0;
    if (s == 0) return false;
    return toDouble(a[key]) <= (mean[key] ?? 0) - s;
  }

  /// Human-readable reasons this animal is flagged, herd-relative.
  List<String> reasons(Map<String, dynamic> a) {
    final out = <String>[];
    if (_above(a, 'Parasite_Load_Index')) {
      out.add('Parasite load high vs herd');
    }
    if (_above(a, 'Fecal_Egg_Count')) {
      out.add('Fecal egg count high vs herd');
    }
    if (_above(a, 'Ear_Temperature_C') && _above(a, 'Respiration_Rate_BPM')) {
      out.add('Elevated temperature & respiration');
    }
    if (_below(a, 'Fertility_Score')) {
      out.add('Low fertility vs herd');
    }
    return out;
  }

  RiskLevel risk(Map<String, dynamic> a) {
    final count = reasons(a).length;
    if (count >= 2) return RiskLevel.atRisk;
    if (count == 1) return RiskLevel.watch;
    return RiskLevel.none;
  }
}
