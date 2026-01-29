import 'api.dart';

class VinService {
  final ApiClient api;
  VinService(this.api);

  Future<Map<String, dynamic>> resolveVin(String vin) async {
    final data = await api.postJson('/vin/resolve', {
      'vin': vin.trim().toUpperCase(),
      'app_version': 'flutter',
      'seed_version': 'dev',
    });
    return (data as Map).cast<String, dynamic>();
  }


  // NEW: one-shot VIN -> vehicle + engine + maintenance bundle
  Future<Map<String, dynamic>> resolveVinAndBundle(String vin) async {
    final data = await api.postJson('/vin/resolve_and_bundle', {
      'vin': vin.trim().toUpperCase(),
      'app_version': 'flutter',
      'seed_version': 'dev',
    });
    return (data as Map).cast<String, dynamic>();
  }

  Future<List<int>> years() async {
    final data = await api.getJson('/years');
    return (data as List).map((e) => e as int).toList();
  }

  Future<List<String>> makes(int year) async {
    final data = await api.getJson('/makes', query: {'year': year});
    return (data as List).map((e) => e.toString()).toList();
  }

  Future<List<String>> models(int year, String make) async {
    final data = await api.getJson('/models', query: {'year': year, 'make': make});
    return (data as List).map((e) => e.toString()).toList();
  }

  Future<Map<String, dynamic>> vehicleSearch(int year, String make, String model) async {
    final data = await api.getJson('/vehicles/search', query: {
      'year': year,
      'make': make,
      'model': model,
    });
    return (data as Map).cast<String, dynamic>();
  }

  // NEW: maintenance bundle (replaces oilByEngine)
  Future<Map<String, dynamic>> maintenanceBundle({
    required String vehicleId,
    required int year,
    String? engineCode,
  }) async {
    final data = await api.getJson(
      '/maintenance/bundle',
      query: {
        'vehicle_id': vehicleId,
        'year': year.toString(),
        if (engineCode != null) 'engine_code': engineCode,
      },
    );

    return (data as Map).cast<String, dynamic>();
  }
}