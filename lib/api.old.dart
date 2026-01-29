import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiClient {
  final String baseUrl;
  ApiClient({required this.baseUrl});

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final u = Uri.parse(baseUrl + path);
    if (query == null) return u;
    return u.replace(
      queryParameters: query.map((k, v) => MapEntry(k, v.toString())),
    );
  }

  Future<dynamic> getJson(String path, {Map<String, dynamic>? query}) async {
    final r = await http.get(_uri(path, query));
    if (r.statusCode < 200 || r.statusCode >= 300) {
      throw Exception('HTTP ${r.statusCode}: ${r.body}');
    }
    return jsonDecode(r.body);
  }

  Future<dynamic> postJson(String path, Map<String, dynamic> body) async {
    final r = await http.post(
      _uri(path),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (r.statusCode < 200 || r.statusCode >= 300) {
      throw Exception('HTTP ${r.statusCode}: ${r.body}');
    }
    return jsonDecode(r.body);
  }
}

class VehicleApi {
  // Windows + Flutter: prefer 127.0.0.1 over localhost.
  static const String baseUrl = 'http://127.0.0.1:8000';
}
