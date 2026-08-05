import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vehicle_app/local/app_db.dart';
import 'package:vehicle_app/local/garage_repo.dart';

import 'api.dart';
import 'app_config.dart';
import 'garage_screen.dart';

Future<void> main() async{
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

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
