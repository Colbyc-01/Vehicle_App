import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScanVinScreen extends StatefulWidget {
  const ScanVinScreen({super.key});

  @override
  State<ScanVinScreen> createState() => _ScanVinScreenState();
}

class _ScanVinScreenState extends State<ScanVinScreen> {
  bool _found = false;
  bool _torchOn = false;

  late final MobileScannerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      torchEnabled: false,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? _extractVin(String raw) {
    // Keep only A-Z and 0-9, uppercase.
    final cleaned = raw.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

    // Find a VIN-like 17-char substring (VINs typically exclude I, O, Q).
    final match = RegExp(r'[A-HJ-NPR-Z0-9]{17}').firstMatch(cleaned);
    return match?.group(0);
  }

  Future<void> _toggleTorch() async {
    try {
      await _controller.toggleTorch();
      if (!mounted) return;
      setState(() => _torchOn = !_torchOn);
    } catch (_) {
      // If torch isn't available on this device, just ignore.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan VIN')),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (capture) async {
              if (_found) return;
              if (capture.barcodes.isEmpty) return;

              final raw = capture.barcodes.first.rawValue;
              if (raw == null || raw.isEmpty) return;

              final vin = _extractVin(raw);
              if (vin == null) return;

              _found = true;

              // Haptics are best-effort (depends on device vibration settings).
              try {
                HapticFeedback.selectionClick();
              } catch (_) {}

              // Tiny delay so the user perceives "success"
              await Future.delayed(const Duration(milliseconds: 200));
              if (!mounted) return;
              Navigator.pop(context, vin);
            },
          ),

          // Dark overlay (lets the target box stand out)
          Positioned.fill(
            child: IgnorePointer(
              child: Container(color: Colors.black.withOpacity(0.35)),
            ),
          ),

          // Target box
          Center(
            child: IgnorePointer(
              child: Container(
                width: 280,
                height: 160,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          // Torch toggle (version-proof: no TorchState dependency)
          Positioned(
            bottom: 28,
            left: 0,
            right: 0,
            child: Center(
              child: IconButton(
                iconSize: 48,
                color: Colors.white,
                icon: Icon(_torchOn ? Icons.flash_off : Icons.flash_on),
                onPressed: _toggleTorch,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
