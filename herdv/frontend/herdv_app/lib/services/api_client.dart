// frontend/herdv_app/lib/services/api_client.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;

class ApiClient {
  final String baseUrl;

  /// Normalize baseUrl for common emulator setups.
  /// If running on Android (not web) and the provided host is `localhost` or
  /// `127.0.0.1`, rewrite it to `10.0.2.2` so the Android emulator can reach
  /// the host machine without changing code elsewhere.
  ApiClient(String baseUrl) : baseUrl = _normalizeBaseUrl(baseUrl);

  static String _normalizeBaseUrl(String url) {
    if (kIsWeb) return url;
    try {
      final uri = Uri.parse(url);
      if ((uri.host == 'localhost' || uri.host == '127.0.0.1') &&
          defaultTargetPlatform == TargetPlatform.android) {
        final replaced = uri.replace(host: '10.0.2.2');
        return replaced.toString();
      }
    } catch (_) {}
    return url;
  }

  Future<Map<String, dynamic>> validateCsv(List<int> bytes) async {
    try {
      if (kIsWeb) {
        // Some browsers struggle with multipart/form-data from dart:html.
        // Send raw bytes with text/csv content-type which the backend now accepts.
        final resp = await http.post(Uri.parse('$baseUrl/schema/validate'),
            headers: {'Content-Type': 'text/csv'}, body: bytes);
        if (resp.statusCode != 200) {
          throw Exception(
              'validateCsv failed: ${resp.statusCode} ${resp.reasonPhrase} - ${resp.body}');
        }
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
      final req = http.MultipartRequest(
          'POST', Uri.parse('$baseUrl/schema/validate'))
        ..files.add(
            http.MultipartFile.fromBytes('file', bytes, filename: 'data.csv'));
      final streamed = await req.send();
      final body = await streamed.stream.bytesToString();
      if (streamed.statusCode != 200) {
        throw Exception('validateCsv failed: ${streamed.statusCode} - $body');
      }
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Network error during validateCsv: $e');
    }
  }

  Future<Map<String, dynamic>> clusterFromCsv(List<int> bytes,
      {int nClusters = 4}) async {
    try {
      if (kIsWeb) {
        final resp = await http.post(
            Uri.parse('$baseUrl/cluster?n_clusters=$nClusters'),
            headers: {'Content-Type': 'text/csv'},
            body: bytes);
        if (resp.statusCode != 200) {
          throw Exception(
              'clusterFromCsv failed: ${resp.statusCode} ${resp.reasonPhrase} - ${resp.body}');
        }
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
      final req = http.MultipartRequest(
          'POST', Uri.parse('$baseUrl/cluster?n_clusters=$nClusters'))
        ..files.add(
            http.MultipartFile.fromBytes('file', bytes, filename: 'data.csv'));
      final streamed = await req.send();
      final body = await streamed.stream.bytesToString();
      if (streamed.statusCode != 200) {
        throw Exception(
            'clusterFromCsv failed: ${streamed.statusCode} - $body');
      }
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Network error during clusterFromCsv: $e');
    }
  }

  Future<Map<String, dynamic>> clusterFromRecords(
      List<Map<String, dynamic>> records,
      {int nClusters = 4}) async {
    try {
      final resp = await http.post(
        Uri.parse('$baseUrl/cluster'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'records': records, 'n_clusters': nClusters}),
      );
      if (resp.statusCode != 200) {
        throw Exception(
            'clusterFromRecords failed: ${resp.statusCode} ${resp.reasonPhrase} - ${resp.body}');
      }
      return jsonDecode(resp.body) as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Network error during clusterFromRecords: $e');
    }
  }

  Uri dendrogramUrl() => Uri.parse('$baseUrl/dendrogram');

  Future<List<int>> getDendrogramBytes() async {
    try {
      final resp = await http.get(Uri.parse('$baseUrl/dendrogram'));
      if (resp.statusCode != 200) {
        // Try to extract a helpful message if the server returned JSON
        try {
          final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
          if (decoded.containsKey('error')) {
            throw Exception('dendrogram failed: ${decoded['error']}');
          }
        } catch (_) {}
        throw Exception('dendrogram failed: ${resp.statusCode} - ${resp.body}');
      }
      return resp.bodyBytes;
    } catch (e) {
      throw Exception('Network error during getDendrogramBytes: $e');
    }
  }

  Future<List<int>> getMilkYieldBoxplot() async {
    try {
      final resp =
          await http.get(Uri.parse('$baseUrl/plots/boxplot/milk_yield'));
      if (resp.statusCode != 200) {
        throw Exception('boxplot failed: ${resp.statusCode} - ${resp.body}');
      }
      return resp.bodyBytes;
    } catch (e) {
      throw Exception('Network error during getMilkYieldBoxplot: $e');
    }
  }

  Future<List<int>> downloadAssignmentsCsv() async {
    try {
      final resp = await http.get(Uri.parse('$baseUrl/export/assignments'));
      if (resp.statusCode != 200) {
        throw Exception(
            'downloadAssignmentsCsv failed: ${resp.statusCode} - ${resp.body}');
      }
      return resp.bodyBytes;
    } catch (e) {
      throw Exception('Network error during downloadAssignmentsCsv: $e');
    }
  }

  Future<Map<String, dynamic>> compareClusterings({String ks = '3,4,5'}) async {
    try {
      final resp = await http.get(Uri.parse('$baseUrl/cluster/compare?ks=$ks'));
      if (resp.statusCode != 200) {
        throw Exception(
            'compareClusterings failed: ${resp.statusCode} - ${resp.body}');
      }
      return jsonDecode(resp.body) as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Network error during compareClusterings: $e');
    }
  }

  Future<List<int>> exportRecommendations({String format = 'csv'}) async {
    try {
      final resp = await http.post(
        Uri.parse('$baseUrl/recommendations/export'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'format': format}),
      );
      if (resp.statusCode != 200) {
        throw Exception(
            'exportRecommendations failed: ${resp.statusCode} ${resp.reasonPhrase} - ${resp.body}');
      }
      return resp.bodyBytes;
    } catch (e) {
      throw Exception('Network error during exportRecommendations: $e');
    }
  }
}
