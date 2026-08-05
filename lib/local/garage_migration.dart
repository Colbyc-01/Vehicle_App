import 'package:shared_preferences/shared_preferences.dart';
import 'garage_repo.dart';

class GarageMigration {
  static const _doneKey = 'garage_migrated_to_db_v1';

  static Future<void> migrateIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final done = prefs.getBool(_doneKey) ?? false;
    if (done) return;

    final list = prefs.getStringList('garage_list') ?? [];
    if (list.isEmpty) {
      await prefs.setBool(_doneKey, true);
      return;
    }

    final repo = GarageRepo();

    for (final raw in list) {
      // Accept both your “VIN | title | engine” and legacy plain title.
      final parts = raw.split('|').map((s) => s.trim()).toList();

      String? vin;
      String? title;
      String? engine;

      if (parts.isNotEmpty) {
        final candidate = parts[0].toUpperCase();
        final vinRegex = RegExp(r'^[A-HJ-NPR-Z0-9]{17}$');
        if (vinRegex.hasMatch(candidate)) {
          vin = candidate;
          title = parts.length > 1 ? parts[1] : null;
          engine = parts.length > 2 ? parts[2] : null;
        } else {
          title = raw.trim();
        }
      }

      // Try to parse year/make/model from title (best-effort)
      int? year;
      String? make;
      String? model;

      if (title != null) {
        final tokens = title.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
        if (tokens.isNotEmpty) {
          final y = int.tryParse(tokens.first);
          if (y != null) {
            year = y;
            if (tokens.length >= 2) make = tokens[1];
            if (tokens.length >= 3) model = tokens.sublist(2).join(' ');
          }
        }
      }

      await repo.upsertVehicle(
        vin: vin,
        year: year,
        make: make,
        model: model,
        engineLabel: engine,
        engineCode: null,
        vehicleId: null,
      );
    }

    // Optional: keep old list for now, or clear it once you trust migration:
    // await prefs.remove('garage_list');

    await prefs.setBool(_doneKey, true);
  }
}
