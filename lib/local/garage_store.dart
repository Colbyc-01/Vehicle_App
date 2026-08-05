import 'package:vehicle_app/local/garage_repo.dart';

class GarageStore {
  final GarageRepo _repo = GarageRepo();

  Future<void> saveVehicle({
    required String vin,
    required int year,
    required String make,
    required String model,
    String? engineLabel,
    String? engineCode,
    String? vehicleId,
  }) async {
    // Later we can add dedupe/upsert here.
    await _repo.addVehicle(
      vin: vin,
      year: year,
      make: make,
      model: model,
      engineLabel: engineLabel,
      engineCode: engineCode,
      vehicleId: vehicleId,
    );
  }
}
