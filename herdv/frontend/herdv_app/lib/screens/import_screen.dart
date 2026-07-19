// frontend/herdv_app/lib/screens/import_screen.dart
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'dart:typed_data';
// kIsWeb is not required here; keep imports minimal
import '../services/api_client.dart';
import '../services/import_service.dart';
import '../state/app_state.dart';

class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key});
  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  final app = AppState();
  final api = ApiClient('http://localhost:8000'); // adjust for device/network
  bool loading = false;
  String? loadingMessage;
  double? loadingProgress;
  final List<String> _progressLog = [];
  late ScrollController _logScrollController;
  int nClusters = 4;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _logScrollController = ScrollController();
  }

  @override
  void dispose() {
    _logScrollController.dispose();
    super.dispose();
  }

  // Simple manual entry model
  final formKey = GlobalKey<FormState>();
  final Map<String, dynamic> record = {
    "ID": "",
    "Breed": "",
    "Age": 0,
    "Weight_kg": 0,
    "Milk_Yield": 0,
    "Fertility_Score": 0,
    "Rumination_Minutes_Per_Day": 0,
    "Ear_Temperature_C": 0,
    "Parasite_Load_Index": 0,
    "Fecal_Egg_Count": 0,
    "Respiration_Rate_BPM": 0,
    "Forage_Quality_Index": 0,
    "Vaccination_Up_To_Date": false,
    "Movement_Score": 0,
    "Remaining_Months": 0
  };

  Future<void> importCsv() async {
    final result = await FilePicker.platform
        .pickFiles(type: FileType.custom, allowedExtensions: ['csv']);
    if (result == null) return;
    final bytes = result.files.single.bytes!;
    setState(() {
      loading = true;
    });
    try {
      setState(() => loadingMessage = 'Validating CSV...');
      final v = await api.validateCsv(bytes);
      // Defensive: backend may return null for keys; coerce to expected shapes
      final missing =
          (v['missing'] is List) ? v['missing'] as List : <dynamic>[];
      if (missing.isNotEmpty) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Missing columns: $missing')));
        setState(() {
          loading = false;
        });
        return;
      }

      // Delegate to importCsvFromBytes which does backend-first and local fallback
      final ok = await importCsvFromBytes(context, bytes,
          nClusters: nClusters, apiClient: api, onProgress: (msg, p) {
        setState(() {
          loadingMessage = msg;
          loadingProgress = p;
          _progressLog.add(msg);
        });
        // auto-scroll to bottom after frame
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_logScrollController.hasClients) {
            _logScrollController.animateTo(
                _logScrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut);
          }
        });
      });
      if (!ok) {
        setState(() => loading = false);
        return;
      }
      // At this point importCsvFromBytes populated AppState and cached it
      // Show success and provide post-import actions
      // ignore: avoid_print
      print(
          'Import successful: records=${app.records.length}, clusters=${app.clusters.length}');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Imported ${app.records.length} rows — ${app.clusters.length} batches')));
      await showPostImportDialog(context, api, app);
      Navigator.pop(context);
    } catch (e) {
      final msg = 'Error: $e';
      setState(() => errorMessage = msg);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      setState(() {
        loading = false;
        loadingMessage = null;
      });
    }
  }

  Future<void> showPostImportDialog(
      BuildContext ctx, ApiClient api, AppState app) async {
    return showDialog<void>(
      context: ctx,
      builder: (c) => AlertDialog(
        title: const Text('Import complete'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Rows imported: ${app.records.length}'),
          const SizedBox(height: 8),
          Text('Batches: ${app.clusters.length}'),
        ]),
        actions: [
          TextButton(
              onPressed: () async {
                // Compare clusterings
                Navigator.of(c).pop();
                try {
                  final res = await api.compareClusterings(ks: '3,4,5');
                  await showDialog<void>(
                      context: ctx,
                      builder: (_) => AlertDialog(
                            title: const Text('Batch Comparison'),
                            content: SingleChildScrollView(
                                child: Text(
                                    'Counts: ${res['counts']}\nARI: ${res['ari']}')),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(_),
                                  child: const Text('Close'))
                            ],
                          ));
                } catch (e) {
                  ScaffoldMessenger.of(ctx)
                      .showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              child: const Text('Compare Batches')),
          TextButton(
              onPressed: () async {
                Navigator.of(c).pop();
                try {
                  final bytes = await api.getMilkYieldBoxplot();
                  await showImageBytesDialog(ctx, 'Milk Yield Boxplot', bytes);
                } catch (e) {
                  ScaffoldMessenger.of(ctx)
                      .showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              child: const Text('View Boxplot')),
          TextButton(
              onPressed: () async {
                Navigator.of(c).pop();
                try {
                  final csvBytes = await api.downloadAssignmentsCsv();
                  final csv = String.fromCharCodes(csvBytes);
                  await showDialog<void>(
                      context: ctx,
                      builder: (_) => AlertDialog(
                            title: const Text('Assignments CSV'),
                            content: SingleChildScrollView(child: Text(csv)),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(_),
                                  child: const Text('Close'))
                            ],
                          ));
                } catch (e) {
                  ScaffoldMessenger.of(ctx)
                      .showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              child: const Text('Download Assignments')),
          TextButton(
              onPressed: () => Navigator.of(c).pop(),
              child: const Text('Close'))
        ],
      ),
    );
  }

  Future<void> showImageBytesDialog(
      BuildContext ctx, String title, List<int> bytes) async {
    final image = Image.memory(Uint8List.fromList(bytes));
    return showDialog<void>(
        context: ctx,
        builder: (_) => AlertDialog(
              title: Text(title),
              content: SingleChildScrollView(child: image),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(_),
                    child: const Text('Close'))
              ],
            ));
  }

  Future<void> submitManual() async {
    if (!formKey.currentState!.validate()) return;
    formKey.currentState!.save();
    setState(() {
      loading = true;
    });
    try {
      // Merge with existing records so clustering uses current herd + new entry.
      final existing = List<Map<String, dynamic>>.from(app.records);
      final combined = <Map<String, dynamic>>[];
      combined.addAll(existing);
      combined.add(Map<String, dynamic>.from(record));

      Map<String, dynamic> clustered;
      try {
        clustered =
            await api.clusterFromRecords(combined, nClusters: nClusters);
      } catch (e) {
        // fallback to local clustering when offline
        clustered =
            await localClusterFromRecords(combined, nClusters: nClusters);
      }

      final labeled = (clustered['labeled_records'] is List)
          ? List<Map<String, dynamic>>.from(clustered['labeled_records'])
          : <Map<String, dynamic>>[];
      final kpis = (clustered['kpis'] is Map)
          ? Map<String, dynamic>.from(clustered['kpis'])
          : <String, dynamic>{};
      final clustersList = (clustered['clusters'] is List)
          ? List<dynamic>.from(clustered['clusters'])
          : <dynamic>[];
      final assignmentsList = (clustered['assignments'] is List)
          ? List<Map<String, dynamic>>.from(clustered['assignments'])
          : <Map<String, dynamic>>[];

      // Update AppState with the merged clustering result
      app.records = labeled.isNotEmpty ? labeled : combined;
      app.assignments = assignmentsList.isNotEmpty
          ? List<dynamic>.from(assignmentsList)
          : assignmentsList;
      app.clusters = clustersList;
      app.kpis = kpis;
      app.cache();
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Manual entry added to batches')));
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() {
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final manualMode = args?['mode'] == 'manual';
    return Scaffold(
      appBar: AppBar(title: Text(manualMode ? 'Add Animal' : 'Import CSV')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            manualMode ? buildManualForm() : buildCsvImport(),
            if (loading)
              Positioned.fill(
                child: Container(
                  color: const Color.fromRGBO(0, 0, 0, 0.4),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 12),
                        if (loadingProgress != null)
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 24.0),
                            child:
                                LinearProgressIndicator(value: loadingProgress),
                          ),
                        const SizedBox(height: 8),
                        // Progress log area
                        if (_progressLog.isNotEmpty)
                          Container(
                            width: 420,
                            constraints: const BoxConstraints(maxHeight: 160),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12.0, vertical: 8.0),
                            decoration: BoxDecoration(
                              color: const Color.fromRGBO(0, 0, 0, 0.6),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Scrollbar(
                              child: SingleChildScrollView(
                                controller: _logScrollController,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: _progressLog
                                      .map((s) => Text(s,
                                          style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 12)))
                                      .toList(),
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 8),
                        Text(loadingMessage ?? 'Processing...',
                            style: const TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                ),
              )
          ],
        ),
      ),
    );
  }

  Widget buildCsvImport() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              errorMessage!,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        Row(children: [
          Expanded(
              child: Slider(
                  value: nClusters.toDouble(),
                  min: 2,
                  max: 8,
                  divisions: 6,
                  label: '$nClusters batches',
                  onChanged: (v) => setState(() => nClusters = v.toInt()))),
          Text('$nClusters batches'),
        ]),
        const SizedBox(height: 8),
        ElevatedButton.icon(
            onPressed: loading
                ? null
                : () async {
                    setState(() {
                      loading = true;
                      loadingMessage = 'Waiting for file selection...';
                      loadingProgress = null;
                    });
                    try {
                      final ok = await pickAndImportCsv(context,
                          nClusters: nClusters, onProgress: (msg, p) {
                        setState(() {
                          loadingMessage = msg;
                          loadingProgress = p;
                        });
                      });
                      if (ok) Navigator.pop(context);
                    } finally {
                      setState(() {
                        loading = false;
                        loadingMessage = null;
                        loadingProgress = null;
                      });
                    }
                  },
            icon: const Icon(Icons.file_open),
            label: const Text('Select CSV')),
        const SizedBox(height: 12),
        const Text(
            'CSV schema required:\nID, Breed, Age, Weight_kg, Milk_Yield, Fertility_Score, Rumination_Minutes_Per_Day, Ear_Temperature_C, Parasite_Load_Index, Fecal_Egg_Count, Respiration_Rate_BPM, Forage_Quality_Index, Vaccination_Up_To_Date, Movement_Score, Remaining_Months')
      ],
    );
  }

  // ---- Manual entry field helpers ----

  InputDecoration _deco(String label, {String? suffix, String? hint}) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        suffixText: suffix,
        border: const OutlineInputBorder(),
        isDense: true,
      );

  Widget _textField(String label, void Function(String) onSaved) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          decoration: _deco(label),
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Required' : null,
          onSaved: (v) => onSaved(v ?? ''),
        ),
      );

  Widget _numField(String label, void Function(double) onSaved,
      {String? suffix}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        decoration: _deco(label, suffix: suffix),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        validator: (v) {
          if (v == null || v.trim().isEmpty) return 'Required';
          if (double.tryParse(v) == null) return 'Enter a number';
          return null;
        },
        onSaved: (v) => onSaved(double.tryParse(v ?? '') ?? 0),
      ),
    );
  }

  Widget _section(String title, IconData icon, List<Widget> children) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(icon, size: 18, color: const Color(0xFF8B6F47)),
                const SizedBox(width: 8),
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
              ]),
              const SizedBox(height: 12),
              ...children,
            ],
          ),
        ),
      );

  Widget buildManualForm() {
    return Form(
      key: formKey,
      child: ListView(
        children: [
          _section('Identity', Icons.badge, [
            _textField('Tag / ID', (v) => record['ID'] = v),
            _textField('Breed', (v) => record['Breed'] = v),
            _numField('Age', (v) => record['Age'] = v.toInt(), suffix: 'yrs'),
            _numField('Weight', (v) => record['Weight_kg'] = v, suffix: 'kg'),
          ]),
          _section('Production', Icons.local_drink, [
            _numField('Milk Yield', (v) => record['Milk_Yield'] = v,
                suffix: 'L/day'),
            _numField('Fertility Score',
                (v) => record['Fertility_Score'] = v, suffix: '/10'),
            _numField('Rumination',
                (v) => record['Rumination_Minutes_Per_Day'] = v,
                suffix: 'min/day'),
            _numField('Forage Quality Index',
                (v) => record['Forage_Quality_Index'] = v),
            _numField('Movement Score', (v) => record['Movement_Score'] = v),
          ]),
          _section('Health', Icons.health_and_safety, [
            _numField('Ear Temperature',
                (v) => record['Ear_Temperature_C'] = v, suffix: '°C'),
            _numField('Respiration Rate',
                (v) => record['Respiration_Rate_BPM'] = v, suffix: 'bpm'),
            _numField('Parasite Load Index',
                (v) => record['Parasite_Load_Index'] = v),
            _numField('Fecal Egg Count',
                (v) => record['Fecal_Egg_Count'] = v, suffix: 'epg'),
            _numField('Remaining Months',
                (v) => record['Remaining_Months'] = v, suffix: 'mo'),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Vaccination up to date'),
              value: (record['Vaccination_Up_To_Date'] as bool),
              onChanged: (v) =>
                  setState(() => record['Vaccination_Up_To_Date'] = v),
            ),
          ]),
          const SizedBox(height: 4),
          ElevatedButton.icon(
              onPressed: loading ? null : submitManual,
              icon: const Icon(Icons.insights),
              label: const Text('Run Batching')),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
