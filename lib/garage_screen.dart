import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api.dart';
import 'vin_screen.dart';

class GarageScreen extends StatefulWidget {
  final ApiClient api;
  const GarageScreen({super.key, required this.api});

  @override
  State<GarageScreen> createState() => _GarageScreenState();
}

class _GarageScreenState extends State<GarageScreen> {
  List<String> vehicles = [];

  @override
  void initState() {
    super.initState();
    loadGarage();
  }

  Future<void> loadGarage() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('garage_list') ?? [];
    setState(() => vehicles = list);
  }

  /// Stored format (v1): "VIN|year make model|engine"
  /// Example: "3C6...|2012 RAM 2500|6.7L I6"
  /// VIN may be empty.
({String vin, String title, String engine}) _parse(String raw) {
  final parts = raw.split('|');

  String vin = '';
  String title = '';
  String engine = '';

  if (parts.isNotEmpty) {
    final candidate = parts[0].trim().toUpperCase();

    // Real VIN check (17 chars, no I/O/Q)
    final vinRegex = RegExp(r'^[A-HJ-NPR-Z0-9]{17}$');

    if (vinRegex.hasMatch(candidate)) {
      vin = candidate;
      title = parts.length > 1 ? parts[1].trim() : '';
      engine = parts.length > 2 ? parts[2].trim() : '';
    } else {
      // Legacy / manual entries
      title = raw.trim();
    }
  }

  return (vin: vin, title: title, engine: engine);
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
    appBar: AppBar(
    title: const Text('Garage'),
    actions: [
    IconButton(
      icon: const Icon(Icons.delete_forever),
      onPressed: () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('garage_list');
        await loadGarage();
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
              builder: (_) => VinFlowScreen(api: widget.api),
            ),
          );
          await loadGarage();
        },
      ),
      body: vehicles.isEmpty
          ? const Center(child: Text('Garage empty'))
          : ListView.separated(
              itemCount: vehicles.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final raw = vehicles[index];
                final parsed = _parse(raw);

                final title = parsed.engine.isNotEmpty
                    ? '${parsed.title} ${parsed.engine}'.trim()
                    : parsed.title;

                return ListTile(
                  title: Text(title),
                  subtitle: parsed.vin.isNotEmpty ? Text(parsed.vin) : null,
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => VinFlowScreen(
                          api: widget.api,
                          presetVin: parsed.vin.isNotEmpty ? parsed.vin : null,
                        ),
                      ),
                    );
                    await loadGarage();
                  },
                );
              },
            ),
    );
  }
}
