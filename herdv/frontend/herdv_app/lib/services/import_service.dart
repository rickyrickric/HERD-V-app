import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:math';
// dart:io is not available on web; guard usage by checking kIsWeb in callers
import 'dart:io' as io;
import 'api_client.dart';
import '../state/app_state.dart';
import 'package:csv/csv.dart';

typedef ProgressCallback = void Function(String message, double? progress);

double _toDouble(dynamic v, [double fallback = 0.0]) {
  if (v == null) return fallback;
  if (v is double) return v;
  if (v is int) return v.toDouble();
  if (v is String) return double.tryParse(v.replaceAll(',', '')) ?? fallback;
  return fallback;
}

/// Import CSV bytes, validate schema via backend, run clustering and update AppState.
/// Returns true on success, false on failure. Shows user-visible SnackBars for errors.
/// Validate CSV bytes and return a map with keys:
/// - 'valid': bool
/// - 'missing': list of missing columns (if any)
/// - 'preview': first rows preview (List<Map>)
Future<Map<String, dynamic>> validateCsvBytes(List<int> bytes,
    {dynamic apiClient}) async {
  final api = apiClient ?? (ApiClient('http://localhost:8000'));
  // Attempt local CSV parse first (works offline and avoids CORS/web issues)
  try {
    final decoded = const Utf8Decoder().convert(bytes);
    final rows = const CsvToListConverter(eol: '\n').convert(decoded);
    if (rows.isEmpty) throw Exception('Empty CSV');
    final header = rows.first.map((h) => h.toString().trim()).toList();
    final dataRows = rows.skip(1).map((r) {
      final map = <String, dynamic>{};
      for (var i = 0; i < header.length && i < r.length; i++) {
        map[header[i]] = r[i];
      }
      return map;
    }).toList();
    final required = [
      'ID',
      'Breed',
      'Age',
      'Weight_kg',
      'Milk_Yield',
      'Fertility_Score',
      'Rumination_Minutes_Per_Day',
      'Ear_Temperature_C',
      'Parasite_Load_Index',
      'Fecal_Egg_Count',
      'Respiration_Rate_BPM',
      'Forage_Quality_Index',
      'Vaccination_Up_To_Date',
      'Movement_Score',
      'Remaining_Months'
    ];
    final missing = required.where((c) => !header.contains(c)).toList();
    final preview =
        dataRows.take(5).map((m) => Map<String, dynamic>.from(m)).toList();
    if (missing.isEmpty) {
      return {'valid': true, 'missing': missing, 'preview': preview};
    }
    // If local parse is missing columns, attempt backend validation as fallback
    final v = await api.validateCsv(bytes);
    final bmissing =
        (v['missing'] is List) ? v['missing'] as List : <dynamic>[];
    final bpreview = (v['preview'] is List)
        ? List<Map<String, dynamic>>.from(v['preview'])
        : <Map<String, dynamic>>[];
    return {
      'valid': bmissing.isEmpty,
      'missing': bmissing,
      'preview': bpreview
    };
  } catch (e) {
    // Fallback to backend validation if local parse fails
    try {
      final v = await api.validateCsv(bytes);
      final missing =
          (v['missing'] is List) ? v['missing'] as List : <dynamic>[];
      final preview = (v['preview'] is List)
          ? List<Map<String, dynamic>>.from(v['preview'])
          : <Map<String, dynamic>>[];
      return {'valid': missing.isEmpty, 'missing': missing, 'preview': preview};
    } catch (e2) {
      rethrow;
    }
  }
}

Future<bool> importCsvFromBytes(BuildContext context, List<int> bytes,
    {int nClusters = 4,
    dynamic apiClient,
    ProgressCallback? onProgress}) async {
  final api = apiClient ?? (ApiClient('http://localhost:8000'));
  final app = AppState();
  try {
    Map<String, dynamic> clustered;
    try {
      // Try backend first
      onProgress?.call('Clustering (server) — sending to backend', null);
      clustered = await api.clusterFromCsv(bytes, nClusters: nClusters);
    } catch (e) {
      // Backend failed or offline: run local clustering
      onProgress?.call('Running local clustering (offline)', 0.0);
      clustered = await _localClusterFromCsv(bytes,
          nClusters: nClusters, onProgress: onProgress);
    }
    // Extract labeled records (full rows) and assignments (ID->cluster) separately
    List<Map<String, dynamic>> labeledRecords = [];
    List<Map<String, dynamic>> assignmentsOnly = [];
    try {
      if (clustered['labeled_records'] is List) {
        labeledRecords = (clustered['labeled_records'] as List)
            .map<Map<String, dynamic>>((e) =>
                e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{})
            .toList();
      }
    } catch (_) {
      labeledRecords = [];
    }
    try {
      if (clustered['assignments'] is List) {
        assignmentsOnly = (clustered['assignments'] as List)
            .map<Map<String, dynamic>>((e) =>
                e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{})
            .toList();
      }
    } catch (_) {
      assignmentsOnly = [];
    }

    final kpisMap = (clustered['kpis'] is Map)
        ? Map<String, dynamic>.from(clustered['kpis'])
        : <String, dynamic>{};
    final clustersList = (clustered['clusters'] is List)
        ? List<dynamic>.from(clustered['clusters'])
        : <dynamic>[];
    // Normalize KPI keys and ensure numeric values
    final normKpis = <String, dynamic>{};
    if (kpisMap.isNotEmpty) {
      normKpis['average_Milk_Yield'] = _toDouble(kpisMap['average_Milk_Yield']);
      normKpis['average_Fertility_Score'] = _toDouble(
          kpisMap['average_Fertility_Score'] ??
              kpisMap['avg_fertility'] ??
              kpisMap['fertility']);
      normKpis['average_Parasite_Load_Index'] = _toDouble(
          kpisMap['average_Parasite_Load_Index'] ??
              kpisMap['avg_parasite'] ??
              kpisMap['parasite']);
      normKpis['average_Remaining_Months'] = _toDouble(
          kpisMap['average_Remaining_Months'] ??
              kpisMap['avg_remaining_months'] ??
              kpisMap['remaining_months']);
    }

    // Prefer full labeled records when available; otherwise use assignments-only as a fallback
    if (labeledRecords.isNotEmpty) {
      app.records = labeledRecords;
    } else if (assignmentsOnly.isNotEmpty) {
      // assignmentsOnly contains objects like {'ID':..., 'cluster_id':...}
      app.records = assignmentsOnly;
    } else {
      app.records = [];
    }

    app.kpis = normKpis.isNotEmpty ? normKpis : kpisMap;
    app.clusters = clustersList;
    app.assignments =
        assignmentsOnly.isNotEmpty ? assignmentsOnly : labeledRecords;

    // Debug logging to help diagnose empty UI issues
    // ignore: avoid_print
    print(
        'importCsvFromBytes: labeled_records=${labeledRecords.length}, assignments=${assignmentsOnly.length}, clusters=${clustersList.length}, kpis=${app.kpis.keys}');
    app.cache();
    onProgress?.call('Finalizing import', 1.0);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Import complete')));
    return true;
  } catch (e) {
    final msg =
        'Invalid CSV format. Please ensure the required fields are included.';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    // ignore: avoid_print
    print('importCsvFromBytes error: $e');
    return false;
  }
}

/// Helper to pick a CSV file from the device and import it via importCsvFromBytes.
Future<bool> pickAndImportCsv(BuildContext context,
    {int nClusters = 4,
    ApiClient? apiClient,
    ProgressCallback? onProgress}) async {
  final result = await FilePicker.platform
      .pickFiles(type: FileType.custom, allowedExtensions: ['csv']);
  if (result == null) return false;
  // On Android the FilePicker often returns a path but not inline bytes.
  // Prefer in-memory bytes when available; otherwise read from the provided path.
  Uint8List? bytes = result.files.single.bytes;
  if (bytes == null) {
    final path = result.files.single.path;
    if (path == null) return false;
    try {
      final file = io.File(path);
      bytes = await file.readAsBytes();
    } catch (e) {
      // ignore: avoid_print
      print('Failed to read picked file bytes from path: $e');
      return false;
    }
  }
  // First validate and show preview
  try {
    onProgress?.call('Validating CSV', null);
    final validation = await validateCsvBytes(bytes, apiClient: apiClient);
    if (!(validation['valid'] as bool)) {
      final msg =
          'Invalid CSV format. Please ensure the required fields are included.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      return false;
    }
    final preview = validation['preview'] as List<Map<String, dynamic>>;
    // Show preview dialog and ask to continue
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Preview first rows'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              children: preview.take(5).map((r) {
                return Text(r.toString());
              }).toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Import')),
        ],
      ),
    );
    if (proceed != true) return false;
    onProgress?.call('Uploading CSV and clustering', 0.0);
    return await importCsvFromBytes(context, bytes,
        nClusters: nClusters, apiClient: apiClient, onProgress: onProgress);
  } catch (e) {
    final msg =
        'Invalid CSV format. Please ensure the required fields are included.';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    // ignore: avoid_print
    print('pickAndImportCsv error: $e');
    return false;
  }
}

// ---------------- Local clustering fallback ----------------
Future<Map<String, dynamic>> _localClusterFromCsv(List<int> bytes,
    {int nClusters = 4, ProgressCallback? onProgress}) async {
  final decoded = const Utf8Decoder().convert(bytes);
  final rows = const CsvToListConverter(eol: '\n').convert(decoded);
  if (rows.length < 2) throw Exception('Not enough rows');
  final header = rows.first.map((h) => h.toString().trim()).toList();
  final records = rows.skip(1).map((r) {
    final map = <String, dynamic>{};
    for (var i = 0; i < header.length && i < r.length; i++) {
      map[header[i]] = r[i];
    }
    return map;
  }).toList();

  // Extract numeric features in a fixed order
  final numericKeys = [
    'Age',
    'Weight_kg',
    'Milk_Yield',
    'Fertility_Score',
    'Rumination_Minutes_Per_Day',
    'Ear_Temperature_C',
    'Parasite_Load_Index',
    'Fecal_Egg_Count',
    'Respiration_Rate_BPM',
    'Forage_Quality_Index',
    'Movement_Score',
    'Remaining_Months',
    'Vaccination_Up_To_Date'
  ];

  final data = <List<double>>[];
  for (final r in records) {
    final row = <double>[];
    for (final k in numericKeys) {
      var v = r[k];
      double d = 0;
      if (v == null)
        d = 0;
      else if (v is num)
        d = v.toDouble();
      else {
        final s = v.toString().replaceAll(',', '').trim();
        d = double.tryParse(s) ?? 0.0;
      }
      row.add(d);
    }
    data.add(row);
  }

  // Standardize
  final means = List<double>.filled(numericKeys.length, 0.0);
  final stds = List<double>.filled(numericKeys.length, 0.0);
  final n = data.length;
  for (var j = 0; j < numericKeys.length; j++) {
    double sum = 0;
    for (var i = 0; i < n; i++) sum += data[i][j];
    means[j] = sum / n;
    double ss = 0;
    for (var i = 0; i < n; i++) ss += pow(data[i][j] - means[j], 2) as double;
    stds[j] = sqrt(ss / n);
    if (stds[j] == 0) stds[j] = 1.0;
  }
  final scaled = data.map((row) {
    final out = <double>[];
    for (var j = 0; j < row.length; j++) out.add((row[j] - means[j]) / stds[j]);
    return out;
  }).toList();

  // K-means simple implementation
  final rand = Random(0);
  final k = nClusters;
  final dim = numericKeys.length;
  final centroids = <List<double>>[];
  // initialize centroids from random distinct points
  final indices = List<int>.generate(n, (i) => i)..shuffle(rand);
  for (var i = 0; i < k; i++)
    centroids.add(List<double>.from(scaled[indices[i % n]]));

  List<int> labels = List<int>.filled(n, 0);
  final int maxIter = 100;
  final sw = Stopwatch()..start();
  for (var iter = 0; iter < maxIter; iter++) {
    var changed = false;
    // assign
    for (var i = 0; i < n; i++) {
      var best = 0;
      var bestDist = double.infinity;
      for (var c = 0; c < k; c++) {
        var d = 0.0;
        for (var j = 0; j < dim; j++) {
          final diff = scaled[i][j] - centroids[c][j];
          d += diff * diff;
        }
        if (d < bestDist) {
          bestDist = d;
          best = c;
        }
      }
      if (labels[i] != best) {
        labels[i] = best;
        changed = true;
      }
    }
    // recompute centroids
    final sums = List.generate(k, (_) => List<double>.filled(dim, 0.0));
    final counts = List<int>.filled(k, 0);
    for (var i = 0; i < n; i++) {
      final lab = labels[i];
      counts[lab] += 1;
      for (var j = 0; j < dim; j++) sums[lab][j] += scaled[i][j];
    }
    for (var c = 0; c < k; c++) {
      if (counts[c] == 0) {
        // reinitialize
        centroids[c] = List<double>.from(scaled[rand.nextInt(n)]);
      } else {
        for (var j = 0; j < dim; j++) centroids[c][j] = sums[c][j] / counts[c];
      }
    }
    if (!changed) {
      // also report final progress
      onProgress?.call(
          'Local clustering: converged at iteration ${iter + 1}/$maxIter', 1.0);
      break;
    }
    // report progress at end of iteration where progress is fraction of max iters
    final progress = (iter + 1) / maxIter;
    // ETA estimate using average iteration duration
    final avgMs = sw.elapsedMilliseconds / (iter + 1);
    final remaining = maxIter - (iter + 1);
    final etaMs = (avgMs * remaining).round();
    final etaSeconds = (etaMs / 1000).ceil();
    final minutes = etaSeconds ~/ 60;
    final seconds = etaSeconds % 60;
    final etaText =
        '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    onProgress?.call(
        'Local clustering: iteration ${iter + 1}/$maxIter (ETA: $etaText)',
        progress);
  }

  // Build output
  final assignments = <Map<String, dynamic>>[];
  for (var i = 0; i < n; i++) {
    final rec = Map<String, dynamic>.from(records[i]);
    rec['Cluster'] = labels[i];
    assignments.add({'ID': rec['ID'].toString(), 'cluster_id': labels[i]});
  }

  // cluster means simple (on original numeric values)
  final meansByCluster = <int, List<double>>{};
  final countsByCluster = <int, int>{};
  for (var i = 0; i < n; i++) {
    final c = labels[i];
    countsByCluster[c] = (countsByCluster[c] ?? 0) + 1;
    meansByCluster[c] = meansByCluster[c] ?? List<double>.filled(dim, 0.0);
    for (var j = 0; j < dim; j++) {
      meansByCluster[c]![j] = meansByCluster[c]![j] + data[i][j];
    }
  }
  final clusters = <Map<String, dynamic>>[];
  for (var c = 0; c < k; c++) {
    final cnt = countsByCluster[c] ?? 0;
    final m = <String, double>{};
    if (cnt > 0) {
      for (var j = 0; j < dim; j++) {
        m[numericKeys[j]] = meansByCluster[c]![j] / cnt;
      }
    } else {
      for (var j = 0; j < dim; j++) m[numericKeys[j]] = 0.0;
    }
    clusters.add({
      'cluster_id': c,
      'name': 'Cluster $c',
      'count': cnt,
      'means': m,
      'recommendation': ''
    });
  }

  // kpis
  double avgMilk = 0;
  for (var i = 0; i < n; i++) avgMilk += data[i][2];
  avgMilk = avgMilk / n;

  // Ensure labeledRecords include numeric coercion and cluster_id
  final labeledRecords = <Map<String, dynamic>>[];
  for (var i = 0; i < records.length; i++) {
    final original = records[i];
    final rec = <String, dynamic>{};
    for (final entry in original.entries) {
      final k = entry.key;
      final v = entry.value;
      if (numericKeys.contains(k)) {
        if (v == null) {
          rec[k] = 0.0;
        } else if (v is num) {
          rec[k] = v.toDouble();
        } else {
          rec[k] = double.tryParse(v.toString().replaceAll(',', '')) ?? 0.0;
        }
      } else {
        rec[k] = v;
      }
    }
    // attach cluster id as numeric
    rec['cluster_id'] = labels[i];
    rec['Cluster'] = labels[i];
    labeledRecords.add(rec);
  }

  double _meanFromKey(List<List<double>> mat, List<String> keys, String key) {
    final idx = keys.indexOf(key);
    if (idx < 0) return 0.0;
    double s = 0;
    for (var i = 0; i < mat.length; i++) s += mat[i][idx];
    return mat.isEmpty ? 0.0 : s / mat.length;
  }

  return {
    'assignments': assignments,
    'clusters': clusters,
    'kpis': {
      'average_Milk_Yield': avgMilk,
      'average_Fertility_Score':
          _meanFromKey(data, numericKeys, 'Fertility_Score'),
      'average_Parasite_Load_Index':
          _meanFromKey(data, numericKeys, 'Parasite_Load_Index'),
      'average_Remaining_Months':
          _meanFromKey(data, numericKeys, 'Remaining_Months')
    },
    'feature_names': numericKeys,
    'labeled_records': labeledRecords,
  };
}

// Cluster from in-memory records (used for manual add offline)
Future<Map<String, dynamic>> localClusterFromRecords(
    List<Map<String, dynamic>> records,
    {int nClusters = 4}) async {
  // Serialize to CSV and call local cluster
  if (records.isEmpty) throw Exception('No records');
  final headers = records.first.keys.toList();
  final rows = <List<dynamic>>[headers];
  for (final r in records) rows.add(headers.map((h) => r[h]).toList());
  final csv = const ListToCsvConverter().convert(rows);
  return await _localClusterFromCsv(utf8.encode(csv), nClusters: nClusters);
}
