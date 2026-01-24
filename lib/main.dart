import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const VehicleApp());
}

/// CHANGE THIS depending on where Flutter is running:
/// - Windows desktop app: "http://127.0.0.1:8000"
/// - Android Emulator:    "http://10.0.2.2:8000"
const String apiBaseUrl = "http://127.0.0.1:8000";

class VehicleApp extends StatelessWidget {
  const VehicleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vehicle Data',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const VehicleSearchPage(),
    );
  }
}

class Vehicle {
  final int year;
  final String make;
  final String model;
  final String engine;
  final List<String> engineCodes;
  final String fitmentId;

  Vehicle({
    required this.year,
    required this.make,
    required this.model,
    required this.engine,
    required this.engineCodes,
    required this.fitmentId,
  });

  factory Vehicle.fromJson(Map<String, dynamic> m) {
    final rawCodes = m["engine_code"];
    final codes = (rawCodes is List)
        ? rawCodes.map((e) => e.toString()).toList()
        : (rawCodes == null ? <String>[] : <String>[rawCodes.toString()]);

    return Vehicle(
      year: (m["year"] is num) ? (m["year"] as num).toInt() : 0,
      make: (m["make"] ?? "").toString(),
      model: (m["model"] ?? "").toString(),
      engine: (m["engine"] ?? "").toString(),
      engineCodes: codes,
      fitmentId: (m["fitment_id"] ?? "").toString(),
    );
  }
}

Future<List<Vehicle>> fetchVehicles({
  required int year,
  required String make,
  required String model,
}) async {
  final uri = Uri.parse("$apiBaseUrl/vehicles/search").replace(
    queryParameters: {
      "year": year.toString(),
      "make": make,
      "model": model,
    },
  );

  final res = await http.get(uri, headers: {"accept": "application/json"});
  if (res.statusCode != 200) {
    throw Exception("API ${res.statusCode}: ${res.body}");
  }

  final data = jsonDecode(res.body) as Map<String, dynamic>;
  final items = (data["vehicles"] as List<dynamic>? ?? []);

  return items
      .map((e) => Vehicle.fromJson(e as Map<String, dynamic>))
      .toList();
}

class VehicleSearchPage extends StatefulWidget {
  const VehicleSearchPage({super.key});

  @override
  State<VehicleSearchPage> createState() => _VehicleSearchPageState();
}

class _VehicleSearchPageState extends State<VehicleSearchPage> {
  final yearCtrl = TextEditingController(text: "2020");
  final makeCtrl = TextEditingController(text: "honda");
  final modelCtrl = TextEditingController(text: "civic");

  bool loading = false;
  String error = "";
  List<Vehicle> results = [];

  Future<void> runSearch() async {
    setState(() {
      loading = true;
      error = "";
      results = [];
    });

    try {
      final year = int.tryParse(yearCtrl.text.trim());
      final make = makeCtrl.text.trim();
      final model = modelCtrl.text.trim();

      if (year == null) {
        throw Exception("Year must be a number (ex: 2020).");
      }
      if (make.isEmpty || model.isEmpty) {
        throw Exception("Make and model can’t be blank.");
      }

      final data = await fetchVehicles(year: year, make: make, model: model);

      setState(() {
        results = data;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
      });
    } finally {
      setState(() {
        loading = false;
      });
    }
  }

  @override
  void dispose() {
    yearCtrl.dispose();
    makeCtrl.dispose();
    modelCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Vehicle Data"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: yearCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Year",
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => runSearch(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: makeCtrl,
                    decoration: const InputDecoration(
                      labelText: "Make",
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => runSearch(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: modelCtrl,
              decoration: const InputDecoration(
                labelText: "Model",
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => runSearch(),
            ),
            const SizedBox(height: 10),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: loading ? null : runSearch,
                icon: const Icon(Icons.search),
                label: Text(loading ? "Searching..." : "Search"),
              ),
            ),

            if (error.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                error,
                style: const TextStyle(color: Colors.red),
              ),
            ],

            const SizedBox(height: 10),
            Expanded(
              child: results.isEmpty
                  ? const Center(child: Text("No results yet."))
                  : ListView.separated(
                      itemCount: results.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final v = results[i];
                        return ListTile(
                          title: Text("${v.year} ${v.make} ${v.model}"),
                          subtitle: Text(
                            "${v.engine} • ${v.engineCodes.join(", ")}",
                          ),
                          trailing: v.fitmentId.isEmpty
                              ? null
                              : Text(
                                  v.fitmentId,
                                  style: const TextStyle(fontSize: 12),
                                ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
