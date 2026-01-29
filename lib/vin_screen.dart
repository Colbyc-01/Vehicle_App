import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api.dart';
import 'vin_service.dart';
import 'scan_vin_screen.dart';

class VinFlowScreen extends StatefulWidget {
  final ApiClient api;
  const VinFlowScreen({super.key, required this.api});

  @override
  State<VinFlowScreen> createState() => _VinFlowScreenState();
}

class _VinFlowScreenState extends State<VinFlowScreen> {
  late final VinService svc;

  final vinCtrl = TextEditingController();

  bool loading = false;
  String? error;

  List<int> years = [];
  int? year;
  List<String> makes = [];
  String? make;
  List<String> models = [];
  String? model;

  String? vehicleId;

  List<Map<String, String>> engineOptions = [];
  Map<String, String>? selectedEngine;

  Map<String, dynamic>? bundle;

  static const String _emptyCopy =
      "Coming soon — refer to owner’s manual for fitment.";

  // Local persistence keys
  static const _kVehicleId = "last_vehicle_id";
  static const _kYear = "last_year";
  static const _kMake = "last_make";
  static const _kModel = "last_model";
  static const _kEngineCode = "last_engine_code";
  static const _kEngineLabel = "last_engine_label";

  @override
  void initState() {
    super.initState();
    svc = VinService(widget.api);
    _boot();
  }

  Future<void> _boot() async {
    await _loadYears();
    await _restoreLastSelectionIfAny();
  }

  Future<void> _loadYears() async {
    years = await svc.years();
    setState(() {});
  }

  List<Map<String, String>> _buildEngineOptions(dynamic results) {
    final out = <Map<String, String>>[];
    final seen = <String>{};

    if (results is List) {
      for (final r in results) {
        final v = r['vehicle'] ?? r;
        final label = (v['engine_label'] ?? '').toString();
        final codes =
            (v['engine_codes'] as List?)?.map((e) => e.toString()).toList() ?? [];

        for (final c in codes) {
          if (seen.contains(c)) continue;
          seen.add(c);
          out.add({
            'code': c,
            'label': label.isNotEmpty ? label : c,
          });
        }
      }
    }

    return out;
  }

  String _engineOptionLabel(Map<String, String> opt) {
    final l = opt['label'] ?? '';
    final c = opt['code'] ?? '';
    return l == c ? c : '$l ($c)';
  }

  Future<void> _saveLastSelection() async {
    if (vehicleId == null || year == null || make == null || model == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kVehicleId, vehicleId!);
    await prefs.setInt(_kYear, year!);
    await prefs.setString(_kMake, make!);
    await prefs.setString(_kModel, model!);
    if (selectedEngine?['code'] != null) {
      await prefs.setString(_kEngineCode, selectedEngine!['code']!);
    }
    if (selectedEngine?['label'] != null) {
      await prefs.setString(_kEngineLabel, selectedEngine!['label']!);
    }
  }

  Future<void> _restoreLastSelectionIfAny() async {
    final prefs = await SharedPreferences.getInstance();
    final savedVehicleId = prefs.getString(_kVehicleId);
    final savedYear = prefs.getInt(_kYear);
    final savedMake = prefs.getString(_kMake);
    final savedModel = prefs.getString(_kModel);
    final savedEngineCode = prefs.getString(_kEngineCode);
    final savedEngineLabel = prefs.getString(_kEngineLabel);

    if (savedVehicleId == null ||
        savedYear == null ||
        savedMake == null ||
        savedModel == null) {
      return;
    }

  



    setState(() {
      vehicleId = savedVehicleId;
      year = savedYear;
      make = savedMake;
      model = savedModel;

      // populate engine selection if we have it
      if (savedEngineCode != null) {
        selectedEngine = {
          'code': savedEngineCode,
          'label': (savedEngineLabel ?? savedEngineCode),
        };
      }
    });

    // Populate pickers so UI stays consistent
    makes = await svc.makes(savedYear);
    models = await svc.models(savedYear, savedMake);
    setState(() {});

    // If we have engine code saved, auto-load bundle
    if (savedEngineCode != null) {
      await _loadBundle({'code': savedEngineCode, 'label': savedEngineLabel ?? savedEngineCode});
    }
  }

  Future<void> _clearVehicle() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kVehicleId);
    await prefs.remove(_kYear);
    await prefs.remove(_kMake);
    await prefs.remove(_kModel);
    await prefs.remove(_kEngineCode);
    await prefs.remove(_kEngineLabel);

    setState(() {
    vinCtrl.clear();
    vehicleId = null;
    year = null;
    make = null;
    model = null;
    engineOptions = [];
    selectedEngine = null;
    bundle = null;
    makes = [];
    models = [];
    });
  }



  Future<void> _searchVehicle() async {
    if (year == null || make == null || model == null) return;

    setState(() {
      loading = true;
      engineOptions = [];
      selectedEngine = null;
      bundle = null;
      vehicleId = null;
    });

    final res = await svc.vehicleSearch(year!, make!, model!);

    final results = res['results'] as List?;
    if (results != null && results.isNotEmpty) {
      final first = results.first['vehicle'] ?? results.first;
      vehicleId = first['vehicle_id'];
    }

    engineOptions = _buildEngineOptions(res['results']);

    if (engineOptions.length == 1 && vehicleId != null) {
      selectedEngine = engineOptions.first;
      bundle = await svc.maintenanceBundle(
        vehicleId: vehicleId!,
        year: year!,
        engineCode: selectedEngine!['code'],
      );
      await _saveLastSelection();
    }

    setState(() => loading = false);
  }

  Future<void> _loadBundle(Map<String, String> opt) async {
    if (vehicleId == null || year == null) return;

    setState(() {
      selectedEngine = opt;
      bundle = null;
    });

    final res = await svc.maintenanceBundle(
      vehicleId: vehicleId!,
      year: year!,
      engineCode: opt['code'],
    );

    setState(() {
      bundle = res;
    });

    await _saveLastSelection();
  }

  Future<void> _resolveVin() async {
    final vin = vinCtrl.text.trim().toUpperCase();
    if (vin.isEmpty) return;

    setState(() {
      loading = true;
      error = null;
    });

    try {
      final res = await svc.resolveVinAndBundle(vin);
      final status = res['status']?.toString();

      final decoded = (res['decoded'] as Map?)?.cast<String, dynamic>();
      final vehicle = (res['vehicle'] as Map?)?.cast<String, dynamic>();
      final vehicleCandidates = (res['vehicle_candidates'] as List?)?.cast<dynamic>();
      final engineChoices = (res['engine_choices'] as List?)?.cast<dynamic>();
      final resolvedEngineCode = res['engine_code']?.toString();

      // Always populate the pickers with whatever VIN gave us (best effort)
      if (decoded != null) {
        year = decoded['year'];
        make = decoded['make'];
        model = decoded['model'];

        if (year != null) {
          years = await svc.years();
          makes = await svc.makes(year!);
          if (make != null) {
            models = await svc.models(year!, make!);
          }
        }
      }

      // Helper: set vehicle selection and build engine options from vehicle payload
      void applyVehicle(Map<String, dynamic> v) {
        vehicleId = v['vehicle_id']?.toString();
        // Prefer canonical make/model from catalog when provided
        make = v['make']?.toString() ?? make;
        model = v['model']?.toString() ?? model;

        final codes = (v['engine_codes'] as List?)?.map((e) => e.toString()).toList() ?? const <String>[];
        final label = v['engine_label']?.toString();

        engineOptions = [
          for (final c in codes)
            {
              'code': c,
              'label': (label != null && label.isNotEmpty) ? label : c,
            }
        ];
        selectedEngine = null;
        bundle = null;
      }


      // If backend returned everything in one shot, we're done.
      if (status == 'READY') {
        if (vehicle != null) {
          applyVehicle(vehicle);
        }
        final ec = res['engine_code']?.toString();
        if (ec != null && ec.isNotEmpty) {
          selectedEngine = {'code': ec, 'label': ec};
        }
        final b = (res['bundle'] as Map?)?.cast<String, dynamic>();
        if (b != null) {
          bundle = b;
        }
        await _saveLastSelection();
        setState(() {});
        return;
      }

      // If VIN didn't map to catalog, leave user in manual picker mode (no dead end)
      if (status == 'UNSUPPORTED') {
        setState(() {});
        return;
      }

      // If VIN maps to multiple catalog vehicles (eg Silverado family), ask user which one
      if ((status == 'AMBIGUOUS' || status == 'NEEDS_VEHICLE_CONFIRMATION') && vehicleCandidates != null && vehicleCandidates.isNotEmpty) {
        final picked = await _pickFromBottomSheet<Map<String, dynamic>>(
          title: 'Select Vehicle',
          items: vehicleCandidates
              .whereType<Map>()
              .map((m) => m.cast<String, dynamic>())
              .toList(),
          labelOf: (v) {
            final mk = (v['make'] ?? '').toString();
            final md = (v['model'] ?? '').toString();
            final y0 = (v['year_min'] ?? '').toString();
            final y1 = (v['year_max'] ?? '').toString();
            final yr = (y0.isNotEmpty && y1.isNotEmpty) ? '$y0–$y1' : '';
            return yr.isEmpty ? '$mk $md' : '$mk $md ($yr)';
          },
          searchHint: 'Search models…',
        );

        if (picked != null) {
          applyVehicle(picked);
        }
      } else if (vehicle != null) {
        applyVehicle(vehicle);
      }

      // If we have engine choices from backend (ambiguous engines), ask user
      if ((status == 'NEEDS_ENGINE_CONFIRMATION' || status == 'AMBIGUOUS') && engineChoices != null && engineChoices.isNotEmpty) {
        final pickedEngine = await _pickFromBottomSheet<Map<String, dynamic>>(
          title: 'Select Engine',
          items: engineChoices
              .whereType<Map>()
              .map((m) => m.cast<String, dynamic>())
              .toList(),
          labelOf: (e) {
            final name = (e['engine_name'] ?? '').toString();
            final code = (e['engine_code'] ?? '').toString();
            return name.isNotEmpty && name != code ? '$name ($code)' : code;
          },
          searchHint: 'Search engines…',
        );

        if (pickedEngine != null) {
          final code = pickedEngine['engine_code']?.toString();
          final name = pickedEngine['engine_name']?.toString();
          if (code != null && code.isNotEmpty) {
            await _loadBundle({'code': code, 'label': (name != null && name.isNotEmpty) ? name : code});
          }
        }

        setState(() {});
        return;
      }

      // If backend already resolved engine_code, load bundle automatically
      if (vehicleId != null && year != null && resolvedEngineCode != null && resolvedEngineCode.isNotEmpty) {
        await _loadBundle({'code': resolvedEngineCode, 'label': resolvedEngineCode});
      } else {
        // Otherwise user can tap Engine picker (if multiple) or Search flow
        setState(() {});
      }
    } finally {
      setState(() {
        loading = false;
      });
    }
  }

List _sectionItems(dynamic section) {
    if (section is List) return section;
    if (section is Map) {
      if (section['items'] is List) return section['items'] as List;
      for (final k in const [
        'engine_air_filter',
        'cabin_air_filter',
        'wiper_blades',
        'headlight_bulbs',
        'battery',
        'oil_filter',
      ]) {
        final v = section[k];
        if (v is List) return v;
      }
    }
    return const [];
  }

  bool _sectionHasVerified(dynamic section) {
    final items = _sectionItems(section);
    for (final e in items) {
      if (e is Map && e['verified'] == true) return true;
    }
    return false;
  }

  String? _sectionWarning(dynamic section) {
    if (section is Map && section['warning'] != null) {
      return section['warning']?.toString();
    }
    return null;
  }

  List<String> _labels(dynamic section) {
    final items = _sectionItems(section);
    return items.map((e) {
      if (e is Map && e['label'] != null) return e['label'].toString();
      return e.toString();
    }).toList();
  }

  Widget _badge({required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text, style: Theme.of(context).textTheme.labelSmall),
    );
  }

  Widget _expandCard({
    required String title,
    required IconData icon,
    required dynamic section,
    String? subtitle,
  }) {
    final warning = _sectionWarning(section);
    final labels = _labels(section);
    final hasVerified = _sectionHasVerified(section);

    // Primary + alternatives:
    final primary = labels.isNotEmpty ? labels.first : null;
    final alts = labels.length > 1 ? labels.sublist(1) : const <String>[];

    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        leading: Icon(icon),
        title: Text(title, style: Theme.of(context).textTheme.titleMedium),
        subtitle: subtitle == null || subtitle.isEmpty ? null : Text(subtitle),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasVerified) _badge(text: "Verified"),
            const SizedBox(width: 8),
            const Icon(Icons.expand_more),
          ],
        ),
        children: [
          if (warning != null && warning.isNotEmpty) ...[
            Text(warning, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 10),
          ],
          if (primary == null) ...[
            Text(_emptyCopy),
          ] else ...[
            Text("Primary", style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            Text(primary),
            if (alts.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text("Recommended alternatives",
                  style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 6),
              ...alts.map((a) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text("• $a"),
                  )),
            ],
          ],
        ],
      ),
    );
  }

  Future<T?> _pickFromBottomSheet<T>({
    required String title,
    required List<T> items,
    required String Function(T) labelOf,
    String searchHint = 'Search...',
  }) async {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) {
        final controller = TextEditingController();
        String q = '';
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final filtered = q.trim().isEmpty
                ? items
                : items
                    .where((it) =>
                        labelOf(it).toLowerCase().contains(q.toLowerCase()))
                    .toList();
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 8,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(ctx).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      hintText: searchHint,
                      prefixIcon: const Icon(Icons.search),
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (v) => setSheetState(() => q = v),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: MediaQuery.of(ctx).size.height * 0.55,
                    child: ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final it = filtered[i];
                        return ListTile(
                          title: Text(labelOf(it)),
                          onTap: () => Navigator.of(ctx).pop<T>(it),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _pickerTile({
    required String label,
    required String value,
    required VoidCallback? onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(child: Text(value.isEmpty ? 'Select…' : value)),
                const Icon(Icons.expand_more),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final oil = bundle?['oil_change'];
    final selectedYearText = year?.toString() ?? '';
    final selectedMakeText = make ?? '';
    final selectedModelText = model ?? '';
    final selectedEngineText =
        selectedEngine == null ? '' : _engineOptionLabel(selectedEngine!);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
TextField(
  controller: vinCtrl,
  decoration: InputDecoration(
    labelText: 'VIN',
    suffixIcon: IconButton(
      icon: const Icon(Icons.camera_alt),
      onPressed: () async {
        final scanned = await Navigator.push<String>(
          context,
          MaterialPageRoute(builder: (_) => const ScanVinScreen()),
        );

        if (scanned != null && scanned.isNotEmpty) {
          vinCtrl.text = scanned;
          await _resolveVin(); // auto run decode
        }
      },
    ),
  ),
),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _resolveVin,
                    child: const Text('Resolve VIN'),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _clearVehicle,
                  child: const Text('Clear'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            _pickerTile(
              label: 'Year',
              value: selectedYearText,
              onTap: years.isEmpty
                  ? null
                  : () async {
                      final picked = await _pickFromBottomSheet<int>(
                        title: 'Select Year',
                        items: years,
                        labelOf: (y) => y.toString(),
                        searchHint: 'Type a year…',
                      );
                      if (picked == null) return;
                      setState(() {
                        year = picked;
                        make = null;
                        model = null;
                        makes = [];
                        models = [];
                        engineOptions = [];
                        selectedEngine = null;
                        bundle = null;
                        vehicleId = null;
                      });
                      makes = await svc.makes(picked);
                      setState(() {});
                    },
            ),

            const SizedBox(height: 12),

            _pickerTile(
              label: 'Make',
              value: selectedMakeText,
              onTap: (year == null || makes.isEmpty)
                  ? null
                  : () async {
                      final picked = await _pickFromBottomSheet<String>(
                        title: 'Select Make',
                        items: makes,
                        labelOf: (m) => m,
                        searchHint: 'Search makes…',
                      );
                      if (picked == null) return;
                      setState(() {
                        make = picked;
                        model = null;
                        models = [];
                        engineOptions = [];
                        selectedEngine = null;
                        bundle = null;
                        vehicleId = null;
                      });
                      models = await svc.models(year!, picked);
                      setState(() {});
                    },
            ),

            const SizedBox(height: 12),

            _pickerTile(
              label: 'Model',
              value: selectedModelText,
              onTap: (year == null || make == null || models.isEmpty)
                  ? null
                  : () async {
                      final picked = await _pickFromBottomSheet<String>(
                        title: 'Select Model',
                        items: models,
                        labelOf: (m) => m,
                        searchHint: 'Search models…',
                      );
                      if (picked == null) return;
                      setState(() {
                        model = picked;
                        engineOptions = [];
                        selectedEngine = null;
                        bundle = null;
                        vehicleId = null;
                      });
                    },
            ),

            const SizedBox(height: 12),

            ElevatedButton(onPressed: _searchVehicle, child: const Text('Search')),

            if (engineOptions.isNotEmpty) ...[
              const SizedBox(height: 20),
              _pickerTile(
                label: 'Engine',
                value: selectedEngineText,
                onTap: () async {
                  final picked = await _pickFromBottomSheet<Map<String, String>>(
                    title: 'Select Engine',
                    items: engineOptions,
                    labelOf: (o) => _engineOptionLabel(o),
                    searchHint: 'Search engines…',
                  );
                  if (picked == null) return;
                  await _loadBundle(picked);
                },
              ),
            ],

            if (bundle != null) ...[
              const SizedBox(height: 14),

              Card(
                margin: const EdgeInsets.only(top: 12),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.oil_barrel),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Oil Change Summary',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          if (_sectionHasVerified(oil?['oil_parts'])) _badge(text: "Verified"),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text('Oil Spec: ${oil?['oil_spec']?['label']}'),
                      Text('Capacity: ${oil?['oil_capacity']?['capacity_label_with_filter']}'),
                    ],
                  ),
                ),
              ),

              _expandCard(
                title: 'Oil Filter',
                icon: Icons.filter_alt,
                section: oil?['oil_parts'],
              ),
              _expandCard(
                title: 'Engine Air Filter',
                icon: Icons.air,
                section: bundle?['engine_air_filter'],
              ),
              _expandCard(
                title: 'Cabin Air Filter',
                icon: Icons.airline_seat_recline_normal,
                section: bundle?['cabin_air_filter'],
              ),
              _expandCard(
                title: 'Wiper Blades',
                icon: Icons.water_drop,
                section: bundle?['wiper_blades'],
              ),
              _expandCard(
                title: 'Headlight Bulbs',
                icon: Icons.lightbulb,
                section: bundle?['headlight_bulbs'],
              ),
              _expandCard(
                title: 'Battery',
                icon: Icons.battery_full,
                section: bundle?['battery'],
              ),
            ],
          ],
        ),
      ),
    );
  }
}