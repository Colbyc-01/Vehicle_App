import 'package:flutter/material.dart';
import 'api.dart';
import 'vin_screen.dart';

void main() {
  runApp(const VehicleApp());
}

class VehicleApp extends StatelessWidget {
  const VehicleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vehicle Maintenance',
      theme: ThemeData(useMaterial3: true),
      home: VinFlowScreen(api: ApiClient(baseUrl: VehicleApi.baseUrl)),
    );
  }
}
