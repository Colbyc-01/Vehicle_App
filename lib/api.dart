import 'dart:convert';
import 'package:http/http.dart' as http;

import 'contracts.dart';

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

  dynamic _guard(String path, dynamic json) {
    // Fail-fast guards for endpoints the app relies on.
    switch (path) {
      case '/years':
        return guardYears(json);
      case '/makes':
        return guardStringList(json, '/makes');
      case '/models':
        return guardStringList(json, '/models');
      case '/vehicles/search':
        return guardVehiclesSearch(json);
      case '/oil-change/by-engine':
        return guardOilChangeByEngine(json);
      case '/vin/resolve':
        return guardVinResolve(json);

      // New combined endpoint (returns a larger object; keep raw for now)
      case '/vin/resolve_and_bundle':
        return json;

      default:
        return json; // no guard for other endpoints
    }
  }

  Future<dynamic> getJson(String path, {Map<String, dynamic>? query}) async {
    final r = await http.get(_uri(path, query));
    if (r.statusCode < 200 || r.statusCode >= 300) {
      throw Exception('HTTP ${r.statusCode}: ${r.body}');
    }
    final json = jsonDecode(r.body);
    return _guard(path, json);
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
    final json = jsonDecode(r.body);
    return _guard(path, json);
  }

  /// Convenience: one-shot VIN -> vehicle + engine + maintenance bundle.
  /// Returns raw JSON Map so callers can branch on status ("READY", etc.).
  Future<Map<String, dynamic>> resolveVinAndBundle(String vin) async {
    final json = await postJson('/vin/resolve_and_bundle', {'vin': vin});
    return (json as Map).cast<String, dynamic>();
  }
}

class VehicleApi {
  // Windows + Flutter: prefer 127.0.0.1 over localhost.
  static const String baseUrl = 'http://192.168.1.104:8000';
}
