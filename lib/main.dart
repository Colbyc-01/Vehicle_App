import 'package:flutter/material.dart';
import 'api.dart';
import 'garage_screen.dart';

/// Override at run-time if needed:
/// flutter run -d windows --dart-define=API_BASE_URL=http://127.0.0.1:8000
const String kApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://127.0.0.1:8000',
);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const VehicleApp());
}

class VehicleApp extends StatelessWidget {
  const VehicleApp({super.key});

  @override
  Widget build(BuildContext context) {
    final api = ApiClient(baseUrl: kApiBaseUrl);

    return MaterialApp(
      title: 'Vehicle Maintenance',
      theme: ThemeData(useMaterial3: true),
      home: GarageScreen(api: api),
    );
  }
}
