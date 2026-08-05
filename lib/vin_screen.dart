import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api.dart';
// ignore: unused_import
import 'garage_service.dart';
import 'maintenance_fitment.dart';
import 'vin_service.dart';
import 'scan_vin_screen.dart';
import 'package:vehicle_app/local/garage_store.dart';


class VinFlowScreen extends StatefulWidget {
  final ApiClient api;
  final String? presetVin;
  final String? presetEngineText;
  final String? presetEngineCode;

  final bool isAddFlow;

  const VinFlowScreen({
    super.key,
    required this.api,
    this.presetVin,
    this.presetEngineText,
    this.presetEngineCode,
    this.isAddFlow = false,
  });

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
  String? selectedEngineText;
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

    debugPrint('VIN_SCREEN presetEngineText = ${widget.presetEngineText}');


    // Prefill VIN when launched from Garage.
    if (widget.presetVin != null && widget.presetVin!.trim().isNotEmpty) {
      vinCtrl.text = widget.presetVin!.trim().toUpperCase();
    }

    // Prefill engine text when launched from Garage.
    if (widget.presetEngineText != null && widget.presetEngineText!.trim().isNotEmpty) {
      final code = widget.presetEngineCode!.trim();
      final label = (widget.presetEngineText ?? code).trim();

      selectedEngine = {'code': code, 'label': label};
    }
    if (selectedEngine != null &&
      year != null &&
      make != null &&
      model != null) {

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadBundle(selectedEngine!);
    });
  }


    svc = VinService(widget.api);
    _boot();
    // If we were launched with a VIN, auto-resolve after first frame.
    if (vinCtrl.text.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _resolveVin();
      });
    }
  }

  Future<void> _openExternal(String url) async {
  try {
    final uri = Uri.parse(url);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open link')),
      );
    }
  } catch (_) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open link')),
      );
    }
  }
}


  Future<void> _boot() async {
    await _loadYears();

    if (!widget.isAddFlow) {
      // In edit flow, try to restore last selection so user can see previous choice and modify if needed.
      await _restoreLastSelectionIfAny();
    }
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

  String _engineAliasFromCode(String code) {
    // Example: FORD_Coyote50 -> Coyote
    if (code.isEmpty) return '';
    var raw = code;
    final idx = code.indexOf('_');
    if (idx >= 0 && idx + 1 < code.length) {
      raw = code.substring(idx + 1);
    }
    raw = raw.replaceAll('_', ' ').trim();
    if (raw.isEmpty) return '';

    // Strip tiny trailing displacement-like suffixes (e.g., Coyote50 -> Coyote).
    final m = RegExp(r'^([A-Za-z]{4,})(\d{1,2})$').firstMatch(raw);
    if (m != null) {
      return m.group(1) ?? raw;
    }
    return raw;
  }

  String _engineOptionLabel(Map<String, String> opt) {
    final l = (opt['label'] ?? '').trim();
    final c = (opt['code'] ?? '').trim();
    final alias = _engineAliasFromCode(c);

    // If backend label is missing or equals code, prefer alias (when it looks nicer).
    final base = (l.isEmpty || l == c) ? (alias.isNotEmpty ? alias : c) : l;

    // If we have both a nice base label and a distinct alias, show both.
    final showAlias = alias.isNotEmpty &&
        base.isNotEmpty &&
        alias.toLowerCase() != base.toLowerCase() &&
        !base.toLowerCase().contains(alias.toLowerCase());

    if (showAlias) {
      return '$base — $alias ($c)';
    }
    if (base == c) return c;
    return '$base ($c)';
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
      error = null;
      engineOptions = [];
      selectedEngine = null;
      bundle = null;
      vehicleId = null;
    });

    try {
      final res = await svc.vehicleSearch(year!, make!, model!);
      final results = (res['results'] as List?) ?? const [];

      if (results.isEmpty) {
        if (!mounted) return;
        setState(() {
          error = 'No vehicles found for that selection.';
          loading = false;
        });
        return;
      }

      final first = results.first is Map ? (results.first['vehicle'] ?? results.first) : results.first;
      final vid = (first is Map) ? (first['vehicle_id']?.toString()) : null;

      final opts = _buildEngineOptions(results);

      if (!mounted) return;
      setState(() {
        vehicleId = vid;
        engineOptions = opts;
      });

      if (vehicleId == null) {
        if (!mounted) return;
        setState(() {
          error = 'Vehicle search returned no vehicle_id.';
          loading = false;
        });
        return;
      }

      // Auto-flow:
      if (engineOptions.length == 1) {
        await _loadBundle(engineOptions.first);
      } else if (engineOptions.length > 1 && mounted) {
        // Stop the spinner before showing the sheet so UI feels responsive.
        setState(() => loading = false);

        final picked = await _pickFromBottomSheet<Map<String, String>>(
          title: 'Select Engine',
          items: engineOptions,
          labelOf: _engineOptionLabel,
          searchHint: 'Search engines…',
        );

        if (picked != null) {
          await _loadBundle(picked);
        }
        return;
      }

      if (!mounted) return;
      setState(() => loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = 'Manual search failed: $e';
        loading = false;
      });
    }
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
     final en = res['engine_name']?.toString();   // <-- ADD THIS

    if (ec != null && ec.isNotEmpty) {
    selectedEngine = {
      'code': ec,
      'label': (en != null && en.isNotEmpty) ? en : ec,   // <-- USE engine_name
    };
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
        'spark_plugs',
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

  Widget _fitmentBadge(dynamic section) {
    final state = maintenanceFitmentState(section);
    if (state == MaintenanceFitmentState.unavailable) {
      return const SizedBox.shrink();
    }

    final verified = state == MaintenanceFitmentState.verified;
    final color = verified ? Colors.green : Colors.orange;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            verified ? Icons.verified_outlined : Icons.info_outline,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            verified ? 'Verified' : 'Verify fitment',
            style: TextStyle(fontSize: 12, color: color),
          ),
        ],
      ),
    );
  }

  Widget _expandCard({
  required String title,
  required IconData icon,
  required dynamic section,
  String? subtitle,
}) {
  final fitmentState = maintenanceFitmentState(section);
  if (fitmentState == MaintenanceFitmentState.unavailable) {
    return const SizedBox.shrink();
  }

  final warning = _sectionWarning(section);
  final labels = _labels(section);

  String partLabel(Map p) {
    final lbl = p['label']?.toString();
    if (lbl != null && lbl.isNotEmpty) return lbl;
    final brand = p['brand']?.toString() ?? '';
    final pn = p['part_number']?.toString() ?? '';
    final combo = [brand, pn].where((s) => s.trim().isNotEmpty).join(' ');
    return combo.isNotEmpty ? combo : p.toString();
  }


Widget buyButtons(dynamic p) {
  if (p is! Map) return const SizedBox.shrink();

  final links = (p['buy_links'] is Map)
      ? (p['buy_links'] as Map).cast<String, dynamic>()
      : const <String, dynamic>{};

  final amazon = links['amazon']?.toString();
  final ebay = links['ebay']?.toString();
  final walmart = links['walmart']?.toString();

  if (amazon == null && ebay == null && walmart == null) {
    return const SizedBox.shrink();
  }

  return Wrap(
    spacing: 10,
    runSpacing: 8,
    children: [
      if (amazon != null)
        ElevatedButton(
          onPressed: () {
            debugPrint('AMAZON URL: $amazon');
            _openExternal(amazon);
          },
          child: const Text('Buy on Amazon'),
        ),
      if (ebay != null)
        OutlinedButton(
          onPressed: () => _openExternal(ebay),
          child: const Text('Buy on eBay'),
        ),
      if (walmart != null)
        OutlinedButton(
          onPressed: () => _openExternal(walmart),
          child: const Text('Walmart'),
        ),
    ],
  );
}

  // Oil filter special schema:
  // section: { engine_code, oil_filter: { oem: {...buy_links}, alternatives: [...] } }
  // Parts schema (oil filter + air filter share the same shape):
  // section: { engine_code, oil_filter|air_filter: { oem: {...buy_links}, alternatives: [...] } }
final partContainer = (section is Map)
    ? ((section.containsKey('oem') || section.containsKey('alternatives'))
        ? section
        : (section['oil_products'] ??
            section['oil_filter'] ??
            section['air_filter'] ??
            section['cabin_filter'] ??
            (section['spark_plugs'] is Map ? section['spark_plugs'] : null)))
    : null;
  final oem = (partContainer is Map) ? (partContainer['oem'] ?? partContainer['primary']) : null;
  final altParts = (partContainer is Map && partContainer['alternatives'] is List)
      ? partContainer['alternatives'] as List
      : const [];

// Spark plug specific variables
final isSpark = title.toLowerCase().contains('spark');
final sparkQty = (isSpark && partContainer is Map) ? partContainer['qty_per_engine'] : null;
final sparkGap = (isSpark && partContainer is Map && partContainer['spec'] is Map)
    ? (partContainer['spec'] as Map)['gap_in']
    : null;


    // --- Wiper schema: { positions: { front_driver: { oem, spec, alternatives } ... } }
  final wiperPositions = (section is Map) ? section['positions'] : null;
  if (wiperPositions is Map) {
    String prettyPos(String k) =>
        k.replaceAll('_', ' ').split(' ').map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');

    return Card(
      child: ExpansionTile(
      tilePadding: const EdgeInsets.all(14),
      childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      title: Row(
        children: [
          Icon(icon),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          _fitmentBadge(section),
        ],
      ),
      children: [
        if (warning != null) ...[
          const SizedBox(height: 8),
          Text(warning, style: const TextStyle(color: Colors.orange)),
        ],
        const SizedBox(height: 12),

        for (final entry in wiperPositions.entries) ...[
          if (entry.value is Map) ...[
            Text(
              prettyPos(entry.key.toString()),
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 6),

          // spec line
            if ((entry.value as Map)['spec'] is Map) ...[
              Builder(builder: (_) {
                final spec = ((entry.value as Map)['spec'] as Map).cast<String, dynamic>();
                final len = spec['length_in'];
                final blade = spec['blade_type'];
                final conn = spec['connector_type'];
                final bits = [
                  if (len != null) '$len"',
                  if (blade != null) blade.toString(),
                  if (conn != null) conn.toString().replaceAll('_', ' ')
                ];
                return Text(bits.join(' • '));
              }),

            const SizedBox(height: 8),
          ],

          // OEM search (has buy_links)
          if ((entry.value as Map)['oem'] is Map) ...[
            buyButtons(((entry.value as Map)['oem'] as Map).cast<String, dynamic>()),
          ],

          // alternatives
          if ((entry.value as Map)['alternatives'] is List) ...[
            const SizedBox(height: 8),
            for (final a in ((entry.value as Map)['alternatives'] as List))
              if (a is Map) ...[
                Text("• ${partLabel(a.cast<String, dynamic>())}"),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.only(left: 14),
                  child: buyButtons(a.cast<String, dynamic>()),
                ),
                const SizedBox(height: 8),
              ],
          ],

          const SizedBox(height: 12),
        ],
      ],
    ],
  ),
);
  }


  // Primary + alternatives (generic label-only fallback)
  final primary = labels.isNotEmpty ? labels.first : null;
  final alts = labels.length > 1 ? labels.sublist(1) : const <String>[];

  return Card(
    margin: const EdgeInsets.only(top: 12),
    child: ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      leading: Icon(icon),
      title: Text(title, style: Theme.of(context).textTheme.titleMedium),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (subtitle != null && subtitle.isNotEmpty) Text(subtitle),
            _fitmentBadge(section),
          ],
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(width: 8),
          const Icon(Icons.expand_more),
        ],
      ),
      children: [
        if (warning != null && warning.isNotEmpty) ...[
          Text(warning, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 10),
        ],
         if (isSpark && (sparkQty != null || sparkGap != null)) ...[
          if (sparkQty != null) Text("Qty needed: $sparkQty"),
          if (sparkGap is num) Text("Gap: ${sparkGap.toStringAsFixed(3)}"),
          const SizedBox(height: 10),
        ],

        // Parts: render with buy links if present
        if (oem is Map) ...[
          Text("Primary", style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          Text(partLabel(oem.cast<String, dynamic>())),
          const SizedBox(height: 8),
          buyButtons(oem.cast<String, dynamic>()),

          if (altParts.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text("Recommended alternatives",
                style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            for (final a in altParts)
              if (a is Map) ...[
                Text("• ${partLabel(a.cast<String, dynamic>())}"),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.only(left: 14),
                  child: buyButtons(a.cast<String, dynamic>()),
                ),
                const SizedBox(height: 8),
              ],
          ],
        ] else if (primary == null) ...[
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
                      // ignore: unnecessary_underscores
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
      appBar: AppBar(title: const Text('Vin')),
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
            if (error != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  // ignore: deprecated_member_use
                  color: Colors.redAccent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                  // ignore: deprecated_member_use
                  border: Border.all(color: Colors.redAccent.withOpacity(0.35)),
                ),
                child: Text(
                  error!,
                  style: const TextStyle(fontSize: 12),
                ),
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
                      try {
                        makes = await svc.makes(picked);
                        error = null;
                      } catch (e) {
                        makes = [];
                        error = 'Could not load Makes.\n$e';
                      }
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
                      try {
                        models = await svc.models(year!, picked);
                        error = null;
                      } catch (e) {
                        models = [];
                        error = 'Could not load Models.\n$e';
                      }
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

            if (engineOptions.isNotEmpty || selectedEngine != null) ...[
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

              // Manual "Save to Garage" (user-confirmed)
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.star_border),
                  label: const Text('Save to Garage'),
                onPressed: () async {
                  final vin = vinCtrl.text.trim().toUpperCase();
                  final y = (year?.toString() ?? '').trim();
                  final mk = (make ?? '').trim();
                  final md = (model ?? '').trim();
                  final eng = selectedEngineText.trim();

                  final title = [y, mk, md].where((s) => s.isNotEmpty).join(' ');

                  // ignore: unused_local_variable
                  final stored = vin.isNotEmpty
                  ? '$vin | $title | $eng'
                  : 'MANUAL | $title | $eng';

                  final engineCode =
                      selectedEngine?['engine_code']?.toString() ?? selectedEngineText.trim();

                  await GarageStore().saveVehicle(
                    vin: vin.isNotEmpty ? vin : 'MANUAL',
                    year: year ?? 0,
                    make: (make ?? '').trim(),
                    model: (model ?? '').trim(),
                    engineLabel: selectedEngineText.trim(),
                    engineCode: engineCode,
                    vehicleId: vehicleId,
                  );

                  if (mounted) {
                    // ignore: use_build_context_synchronously
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Saved to Garage')),
                    );
                  }
                },
                ),
              ),

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
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text('Oil Spec: ${oil?['oil_spec']?['label']}'),
                          _fitmentBadge(oil?['oil_spec']),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text('Capacity: ${oil?['oil_capacity']?['capacity_label_with_filter']}'),
                          _fitmentBadge(oil?['oil_capacity']),
                        ],
                      ),
                      if (oil?['purchase_guidance']?['suggested'] != null)
                        Text(
                          'Buy plan: ${oil?['purchase_guidance']['suggested'].map((s) => "${s['count']}×${s['size_qt']}qt").join(" + ")} '
                          '(${oil?['purchase_guidance']?['qt_to_buy']} qt total)'
                        ),

                    ],
                  ),
                ),
              ),

              _expandCard(
                title: 'Engine Oil',
                icon: Icons.oil_barrel_outlined,
                section: oil?['oil_products'],
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
                title: 'Spark Plugs',
                icon: Icons.bolt,
                section: bundle?['spark_plugs'],
              ),
              _expandCard(
                title: 'Cabin Air Filter',
                icon: Icons.airline_seat_recline_normal,
                section: bundle?['cabin_air_filter'],
              ),
              _expandCard(
                title: 'Wiper Blades',
                icon: Icons.water_drop,
                section: bundle?['wiper'],
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
