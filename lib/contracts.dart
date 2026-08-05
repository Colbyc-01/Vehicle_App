// lib/contracts.dart
// Minimal contract guards for backend JSON response shapes.

class ContractError implements Exception {
  final String message;
  ContractError(this.message);
  @override
  String toString() => 'ContractError: $message';
}

Map<String, dynamic> _asMap(dynamic v, String where) {
  if (v is Map) return v.cast<String, dynamic>();
  throw ContractError('$where: expected object, got ${v.runtimeType}');
}

List<dynamic> _asList(dynamic v, String where) {
  if (v is List) return v;
  throw ContractError('$where: expected array, got ${v.runtimeType}');
}

String _reqStr(Map<String, dynamic> m, String k, String where) {
  final v = m[k];
  if (v is String && v.trim().isNotEmpty) return v;
  throw ContractError('$where: missing/invalid "$k"');
}

List<int> guardYears(dynamic json) {
  final list = _asList(json, '/years');
  return list.map((e) {
    if (e is int) return e;
    if (e is num) return e.toInt();
    throw ContractError('/years: expected number, got ${e.runtimeType}');
  }).toList();
}

List<String> guardStringList(dynamic json, String where) {
  final list = _asList(json, where);
  return list.map((e) => e.toString()).toList();
}

dynamic guardVehiclesSearch(dynamic json) {
  // We only validate the fields the UI relies on: engine_label + engine_codes.
  final m = _asMap(json, '/vehicles/search');
  final results = _asList(m['results'], '/vehicles/search.results');
  for (final r in results) {
    final rm = _asMap(r, '/vehicles/search.results[]');
    final v = (rm['vehicle'] is Map) ? (rm['vehicle'] as Map).cast<String, dynamic>() : rm;
    _reqStr(v, 'engine_label', '/vehicles/search.results[].vehicle.engine_label');
    final codes = v['engine_codes'];
    if (codes is! List || codes.isEmpty) {
      throw ContractError('/vehicles/search.results[].vehicle.engine_codes missing/empty');
    }
  }
  return json;
}

dynamic guardOilChangeByEngine(dynamic json) {
  final m = _asMap(json, '/oil-change/by-engine');
  final oilSpec = m['oil_spec'];
  final oilCap = m['oil_capacity'];
  if (oilSpec is! Map) throw ContractError('/oil-change/by-engine: missing oil_spec');
  if (oilCap is! Map) throw ContractError('/oil-change/by-engine: missing oil_capacity');
  _reqStr(oilSpec.cast<String, dynamic>(), 'label', '/oil-change/by-engine.oil_spec.label');
  _reqStr(oilCap.cast<String, dynamic>(), 'capacity_label_with_filter',
      '/oil-change/by-engine.oil_capacity.capacity_label_with_filter');
  return json;
}

dynamic guardVinResolve(dynamic json) {
  final m = _asMap(json, '/vin/resolve');
  _reqStr(m, 'status', '/vin/resolve.status');
  if (m['decoded'] is! Map) throw ContractError('/vin/resolve.decoded missing');
  return json;
}
