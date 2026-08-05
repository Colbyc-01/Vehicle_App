import 'package:flutter_test/flutter_test.dart';
import 'package:vehicle_app/maintenance_fitment.dart';

void main() {
  test('marks OEM-verified maintenance data as verified', () {
    final state = maintenanceFitmentState({
      'label': 'API CK-4 15W-40',
      'status': 'OEM_VERIFIED',
      'confidence': 'HIGH',
      'verified': true,
    });

    expect(state, MaintenanceFitmentState.verified);
  });

  test('requires fitment verification for seeded data', () {
    final state = maintenanceFitmentState({
      'label': 'API CK-4 15W-40',
      'status': 'SEEDED',
      'confidence': 'MEDIUM',
      'verified': false,
    });

    expect(state, MaintenanceFitmentState.verifyFitment);
  });

  test('hides sections that contain only placeholders', () {
    final state = maintenanceFitmentState({
      'items': [],
      'oem': {
        'brand': 'TBD',
        'part_number': 'TBD',
        'label': 'TBD headlight bulb • verify by VIN',
      },
      'warning': 'not covered',
    });

    expect(state, MaintenanceFitmentState.unavailable);
  });

  test('keeps unverified sections when useful alternatives exist', () {
    final state = maintenanceFitmentState({
      'verified': false,
      'oem': {'brand': 'TBD', 'part_number': 'TBD'},
      'alternatives': [
        {'brand': 'WIX', 'part_number': 'WA10855'},
      ],
    });

    expect(state, MaintenanceFitmentState.verifyFitment);
  });

  test('keeps covered wiper sections with position specifications', () {
    final state = maintenanceFitmentState({
      'coverage': 'covered',
      'positions': {
        'front_driver': {
          'spec': {'length_in': 24, 'connector_type': 'j_hook'},
        },
      },
    });

    expect(state, MaintenanceFitmentState.verified);
  });
}
