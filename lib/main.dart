import 'package:flutter/material.dart';
import 'api.dart';
import 'garage_screen.dart';
import 'package:vehicle_app/local/app_db.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vehicle_app/local/garage_repo.dart';




/// Override at run-time if needed:
/// flutter run -d windows --dart-define=API_BASE_URL=http://127.0.0.1:8001
const String kApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://127.0.0.1:8000',
);

Future<void> main() async{
  WidgetsFlutterBinding.ensureInitialized();

  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final db = await AppDb.instance.db;
  debugPrint('✅ DB opened at ${db.path}');
  final repo = GarageRepo();
  final rows = await repo.listVehicles();
  debugPrint('✅ vehicles rows = ${rows.length}');
  
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
      debugShowCheckedModeBanner: false,
    );
  }
}
