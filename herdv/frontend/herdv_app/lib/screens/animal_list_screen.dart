// frontend/herdv_app/lib/screens/animal_list_screen.dart
import 'package:flutter/material.dart';
import 'package:csv/csv.dart';
import '../state/app_state.dart';

class AnimalListScreen extends StatefulWidget {
  final int? clusterId;
  final String? clusterName;
  const AnimalListScreen({super.key, this.clusterId, this.clusterName});

  @override
  State<AnimalListScreen> createState() => _AnimalListScreenState();
}

class _AnimalListScreenState extends State<AnimalListScreen> {
  final app = AppState();
  String _query = '';
  int? _filterClusterId;

  @override
  void initState() {
    super.initState();
    _filterClusterId = widget.clusterId;
    app.addListener(_onAppChanged);
    _scrollController = ScrollController();
    _screenTitle = (widget.clusterName == null || widget.clusterName!.isEmpty)
        ? 'Animals'
        : widget.clusterName!;
    // check navigation arguments for highlight/scroll flags
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map) {
        final hl = args['highlightImported'] as bool? ?? false;
        final scroll = args['scrollToTop'] as bool? ?? hl;
        if (scroll) {
          _scrollToTopAndHighlight(hl: hl);
        }
      }
    });
  }

  @override
  void dispose() {
    app.removeListener(_onAppChanged);
    _scrollController.dispose();
    super.dispose();
  }

  void _onAppChanged() => setState(() {});

  List<Map<String, dynamic>> get _allRecords => app.records;

  int? _clusterForRecord(Map<String, dynamic> r) {
    final clusterField =
        r['Cluster'] ?? r['cluster'] ?? r['Cluster_ID'] ?? r['cluster_id'];
    if (clusterField != null) {
      if (clusterField is num) return clusterField.toInt();
      if (clusterField is String) return int.tryParse(clusterField);
    }
    final id =
        r['ID']?.toString() ?? r['id']?.toString() ?? r['Tag']?.toString();
    if (id == null) return null;
    try {
      final a = app.assignments.firstWhere((x) => x['ID']?.toString() == id);
      final cid = a['cluster_id'] ?? a['Cluster'] ?? a['cluster'];
      if (cid is num) return cid.toInt();
      if (cid is String) return int.tryParse(cid);
    } catch (_) {}
    return null;
  }

  String _clusterNameForId(int? id) {
    if (id == null) return 'Unassigned';
    try {
      final c = app.clusters.firstWhere((e) {
        if (e is Map && e.containsKey('cluster_id'))
          return e['cluster_id'] == id;
        if (e is Map && e.containsKey('id')) return e['id'] == id;
        return false;
      });
      if (c is Map && c.containsKey('name')) return c['name'].toString();
    } catch (_) {}
    return 'Cluster $id';
  }

  Color _clusterColor(int? id) {
    if (id == null) return Colors.grey;
    return Colors.primaries[id.abs() % Colors.primaries.length];
  }

  List<Map<String, dynamic>> _filteredRecords() {
    return _allRecords.where((r) {
      if (_query.isNotEmpty) {
        final hay =
            r.values.map((v) => v?.toString() ?? '').join(' ').toLowerCase();
        if (!hay.contains(_query.toLowerCase())) return false;
      }
      final cid = _clusterForRecord(r);
      if (_filterClusterId != null) return cid == _filterClusterId;
      return true;
    }).toList();
  }

  late ScrollController _scrollController;
  bool _highlightTop = false;
  late String _screenTitle;

  Future<void> _editTitle() async {
    final controller = TextEditingController(text: _screenTitle);
    final result = await showDialog<String>(
        context: context,
        builder: (_) => AlertDialog(
              title: const Text('Edit title'),
              content: TextField(
                controller: controller,
                decoration: const InputDecoration(hintText: 'Title'),
                autofocus: true,
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(_, null),
                    child: const Text('Cancel')),
                ElevatedButton(
                    onPressed: () => Navigator.pop(_, controller.text.trim()),
                    child: const Text('Save'))
              ],
            ));
    if (result != null && result.isNotEmpty) {
      setState(() => _screenTitle = result);
    }
  }

  void _scrollToTopAndHighlight({bool hl = true}) {
    try {
      _scrollController.animateTo(0,
          duration: const Duration(milliseconds: 500), curve: Curves.easeOut);
    } catch (_) {}
    if (hl) {
      setState(() => _highlightTop = true);
      Future.delayed(const Duration(milliseconds: 1600), () {
        if (mounted) setState(() => _highlightTop = false);
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Showing imported animals'),
        duration: Duration(milliseconds: 1400),
      ));
    }
  }

  void _exportVisible(List<Map<String, dynamic>> visible) {
    if (visible.isEmpty) {
      showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
                title: const Text('Export Visible'),
                content: const Text('No records to export'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(_),
                      child: const Text('Close'))
                ],
              ));
      return;
    }

    final headers = visible.first.keys.map((k) => k.toString()).toList();
    final rows = <List<dynamic>>[];
    rows.add(headers);
    for (final r in visible) {
      rows.add(headers.map((h) => r[h]).toList());
    }
    final csv = const ListToCsvConverter().convert(rows);

    showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
              title: const Text('Export Visible'),
              content: SingleChildScrollView(child: SelectableText(csv)),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(_),
                    child: const Text('Close'))
              ],
            ));
  }

  @override
  Widget build(BuildContext context) {
    final clusters = app.clusters;
    final visible = _filteredRecords();

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: _editTitle,
          child: Text(_screenTitle),
        ),
        actions: [
          IconButton(
              onPressed: () => _exportVisible(visible),
              icon: const Icon(Icons.download))
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search animals (ID, breed, etc.)',
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              const SizedBox(width: 8),
              DropdownButton<int?>(
                value: _filterClusterId,
                hint: const Text('Filter'),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('All')),
                  ...clusters.map<DropdownMenuItem<int?>>((c) {
                    final id =
                        (c is Map && (c['cluster_id'] ?? c['id']) != null)
                            ? (c['cluster_id'] ?? c['id']) as int
                            : null;
                    final name = (c is Map && c['name'] != null)
                        ? c['name'].toString()
                        : 'Cluster ${id ?? '?'}';
                    return DropdownMenuItem<int?>(value: id, child: Text(name));
                  }).toList()
                ],
                onChanged: (v) => setState(() => _filterClusterId = v),
              )
            ]),
          ),
        ),
      ),
      body: visible.isEmpty
          ? const Center(child: Text('No animals found'))
          : ListView.separated(
              itemCount: visible.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final r = visible[i];
                final cid = _clusterForRecord(r);
                final clusterName = _clusterNameForId(cid);
                final id = r['ID'] ?? r['id'] ?? r['Tag'] ?? '—';
                final subtitle = <String>[];
                if (r.containsKey('Breed')) subtitle.add('${r['Breed']}');
                if (r.containsKey('Milk_Yield'))
                  subtitle.add('Milk: ${r['Milk_Yield']}');
                subtitle.add(clusterName);

                final badgeColor = _clusterColor(cid);
                final isTop = i == 0;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  color: isTop && _highlightTop
                      ? const Color.fromRGBO(255, 235, 59, 0.25)
                      : null,
                  child: ListTile(
                    leading: CircleAvatar(
                        backgroundColor: badgeColor,
                        child: const Padding(
                          padding: EdgeInsets.all(6.0),
                          child: Text('🐄',
                              style:
                                  TextStyle(color: Colors.white, fontSize: 20)),
                        )),
                    title: Text('$id'),
                    subtitle: Text(subtitle.join(' • ')),
                    onTap: () {
                      final enriched = Map<String, dynamic>.from(r);
                      if (cid != null) enriched['cluster_id'] = cid;
                      Navigator.pushNamed(context, '/animal_detail',
                          arguments: {'animal': enriched});
                    },
                  ),
                );
              },
            ),
    );
  }
}
