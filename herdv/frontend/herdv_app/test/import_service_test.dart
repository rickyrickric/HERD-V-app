import 'package:flutter_test/flutter_test.dart';
import 'package:herdv_app/services/import_service.dart';

class FakeApiClient {
  Future<Map<String, dynamic>> validateCsv(List<int> bytes) async {
    return {
      'missing': [],
      'preview': [
        {'ID': 'T1', 'Milk_Yield': 10}
      ]
    };
  }

  Future<Map<String, dynamic>> clusterFromCsv(List<int> bytes,
      {int nClusters = 4}) async {
    return {
      'assignments': [
        {'ID': 'T1', 'cluster_id': 0},
      ],
      'clusters': [
        {
          'cluster_id': 0,
          'name': 'Test',
          'count': 1,
          'means': {},
          'recommendation': 'None'
        }
      ],
      'kpis': {'average_Milk_Yield': 10}
    };
  }
}

void main() {
  test('validateCsvBytes returns preview and valid when no missing cols',
      () async {
    final fake = FakeApiClient();
    final bytes = <int>[1, 2, 3];
    final result = await validateCsvBytes(bytes, apiClient: fake as dynamic);
    expect(result['valid'], true);
    expect(result['preview'], isA<List>());
  });
}
