import 'package:flutter/material.dart';
// ignore: unused_import
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vehicle_app/local/garage_repo.dart';

import 'api.dart';
import 'vin_screen.dart';

class GarageScreen extends StatefulWidget {
  final ApiClient api;
  const GarageScreen({super.key, required this.api});

  @override
  State<GarageScreen> createState() => _GarageScreenState();
}

class _GarageScreenState extends State<GarageScreen> {
  List<Map<String, Object?>> vehicles = [];

  @override
  void initState() {
    super.initState();
    loadGarage();
  }

Future<void> loadGarage() async {
  final repo = GarageRepo();
  final rows = await repo.listVehicles();

  if (!mounted) return;

  setState(() {
    vehicles = rows;
  });
}

  /// Stored format (v1): "VIN|year make model|engine"
  /// Example: "3C6...|2012 RAM 2500|6.7L I6"
  /// VIN may be empty.

      @override
      Widget build(BuildContext context) {
        return Scaffold(
      appBar: AppBar(
        title: const Text('Garage'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever),
      onPressed: () async {
        final repo = GarageRepo();
        await repo.deleteAllVehicles();

        await loadGarage(); // whatever your refresh is
      },
    ),
  ],
),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => VinFlowScreen(api: widget.api, isAddFlow: true)
            ),
          );
          await loadGarage();
        },
      ),
      body: vehicles.isEmpty
          ? const Center(child: Text('Garage empty'))
          : ListView.separated(
              itemCount: vehicles.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final v = vehicles[index];
                final yearStr = v['year']?.toString() ?? '';
                final makeStr = v['make']?.toString() ?? '';
                final modelStr = v['model']?.toString() ?? '';
                final vinStr = v['vin']?.toString() ?? '';
                final engineStr = v['engine_label']?.toString() ?? '';
                final enginePreset = v['engine_code']?.toString() ?? '';

                final title = [
                  yearStr, makeStr, modelStr,
                  if (engineStr.isNotEmpty) '— $engineStr',
                ].where((s) => s.isNotEmpty).join(' ');


          return ListTile(
            title: Text(title),
            subtitle: vinStr.isNotEmpty ? Text(vinStr) : null,
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => VinFlowScreen(
                    api: widget.api,
                    presetVin: vinStr.isNotEmpty && vinStr != 'MANUAL' ? vinStr : null,
                    presetEngineText: v['engine_label']?.toString(),
                    presetEngineCode: enginePreset.isNotEmpty ? enginePreset : null,
                  ),
                ),
              );
              await loadGarage(); // refresh after returning
            },
            
          );
              },
            ),
    );
      }
}