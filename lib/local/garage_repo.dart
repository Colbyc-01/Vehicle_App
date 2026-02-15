import 'package:sqflite/sqflite.dart';
import 'app_db.dart';

class GarageRepo {
  String _makeVehicleId({
    required String vin,
    required int year,
    required String make,
    required String model,
    String? engineCode,
    String? engineLabel,
  }) {
    // Stable key; same inputs => same id
    final parts = [
      vin.trim().toUpperCase(),
      year.toString(),
      make.trim().toLowerCase(),
      model.trim().toLowerCase(),
      (engineCode ?? '').trim().toLowerCase(),
      (engineLabel ?? '').trim().toLowerCase(),
    ];
    return parts.join('|');
  }

  Future<int> addVehicle({
    required String vin,
    required int year,
    required String make,
    required String model,
    String? engineLabel,
    String? engineCode,
    String? vehicleId,
  }) async {
    final Database db = await AppDb.instance.db;
    final now = DateTime.now().millisecondsSinceEpoch;

    final id = (vehicleId?.trim().isNotEmpty ?? false)
        ? vehicleId!.trim()
        : _makeVehicleId(
            vin: vin,
            year: year,
            make: make,
            model: model,
            engineCode: engineCode,
            engineLabel: engineLabel,
          );

    return db.insert('vehicles', {
      'vin': vin.trim().toUpperCase(),
      'year': year,
      'make': make.trim(),
      'model': model.trim(),
      'engine_label': engineLabel?.trim(),
      'engine_code': engineCode?.trim(),
      'vehicle_id': id,            // <- never null now
      'created_at': now,
    });
  }

  Future<int> deleteVehicle(String vehicleId) async {
    final db = await AppDb.instance.db;
    return db.delete('vehicles', where: 'vehicle_id = ?', whereArgs: [vehicleId]);
  }

  Future<List<Map<String, Object?>>> listVehicles() async {
    final Database db = await AppDb.instance.db;
    return db.query('vehicles', orderBy: 'created_at DESC');
  }

  Future<int> deleteAllVehicles() async {
    final db = await AppDb.instance.db;
    return db.delete('vehicles');
  }

  Future<void> upsertVehicle({
    String? vin,
    int? year,
    String? make,
    String? model,
    String? engineLabel,
    String? engineCode,
    String? vehicleId,
  }) async {
    // Skip if we don't have at least year, make, and model
    if (year == null || make == null || model == null) {
      return;
    }

    final Database db = await AppDb.instance.db;
    final now = DateTime.now().millisecondsSinceEpoch;

    final id = (vehicleId?.trim().isNotEmpty ?? false)
        ? vehicleId!.trim()
        : _makeVehicleId(
            vin: vin ?? '',
            year: year,
            make: make,
            model: model,
            engineCode: engineCode,
            engineLabel: engineLabel,
          );

    // Check if vehicle already exists
    final existing = await db.query(
      'vehicles',
      where: 'vehicle_id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      // Update existing vehicle
      await db.update(
        'vehicles',
        {
          'vin': (vin ?? '').trim().toUpperCase(),
          'year': year,
          'make': make.trim(),
          'model': model.trim(),
          'engine_label': engineLabel?.trim(),
          'engine_code': engineCode?.trim(),
        },
        where: 'vehicle_id = ?',
        whereArgs: [id],
      );
    } else {
      // Insert new vehicle
      await db.insert('vehicles', {
        'vin': (vin ?? '').trim().toUpperCase(),
        'year': year,
        'make': make.trim(),
        'model': model.trim(),
        'engine_label': engineLabel?.trim(),
        'engine_code': engineCode?.trim(),
        'vehicle_id': id,
        'created_at': now,
      });
    }
  }
}
