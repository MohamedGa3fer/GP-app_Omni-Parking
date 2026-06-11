import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gp_app/core/l10n/app_translations.dart';
import 'package:gp_app/data/dataproviders/on_device_ai_helper.dart';
import 'package:gp_app/features/parking/domain/entities/plate_result.dart';
import 'package:gp_app/features/parking/presentation/providers/parking_provider.dart';
import 'package:gp_app/features/parking/presentation/screens/plate_scan_mode.dart';
import 'package:gp_app/features/parking/presentation/screens/plate_verification_sheet.dart';
import 'package:gp_app/features/parking/presentation/screens/camera_capture_screen.dart';

class ScannerScreen extends StatefulWidget {
  final PlateScanMode mode;

  const ScannerScreen({super.key, this.mode = PlateScanMode.entry});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  bool _isScanning = false;
  String? _error;

  // The TFLite models load lazily (not at app startup), so warm them up as soon
  // as the scanner opens — by the time the user frames a plate they're ready.
  bool _modelReady = false;
  String? _modelError;

  @override
  void initState() {
    super.initState();
    _warmUpModel();
    // Exit lookups read the active sessions list, so make sure it's current.
    if (widget.mode == PlateScanMode.exit) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Provider.of<ParkingProvider>(context, listen: false)
            .loadActiveSessions();
      });
    }
  }

  Future<void> _warmUpModel() async {
    try {
      await OnDeviceAiHelper().loadModel();
      if (mounted) setState(() => _modelReady = true);
    } catch (e) {
      if (mounted) {
        setState(
            () => _modelError = e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  void _retryWarmUp() {
    setState(() => _modelError = null);
    _warmUpModel();
  }

  Future<void> _scanWithCamera() async {
    // 1. Open the camera guide screen and get the captured image path
    final imagePath = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const CameraCaptureScreen()),
    );
    if (!mounted || imagePath == null) return;

    setState(() {
      _isScanning = true;
      _error = null;
    });

    bool retry = false;
    try {
      // 2. Run OCR on the captured photo. recognizePlate() lazily loads the
      //    models if the warm-up hasn't finished yet, so this is always safe.
      final ai = OnDeviceAiHelper();
      final rec = await ai.recognizePlate(imagePath);

      if (!mounted) return;
      // 3. Show the verification sheet. Low-confidence reads are passed through
      //    (flagged) so the user can correct them instead of hitting a dead end.
      //    The sheet returns true if the user chose "Try Again".
      final result = await PlateVerificationSheet.show(
        context,
        PlateResult(
          plateText: rec.text,
          confidence: rec.confidence,
          isLowConfidence: rec.isLowConfidence,
        ),
        mode: widget.mode,
      );
      retry = result == true;
    } catch (e) {
      if (mounted) {
        final msg = e.toString().replaceFirst('Exception: ', '');
        // No detection / unreadable crop → friendly localized message.
        final friendly =
            (msg.contains('No plate detected') || msg.contains('empty OCR'))
                ? tr(context, 'no_plate_found')
                : msg;
        setState(() => _error = friendly);
      }
    } finally {
      if (mounted) setState(() => _isScanning = false);
      // Delete the temp capture so JPEGs don't pile up in the cache dir.
      // The OCR isolate has finished reading it by now (awaited above).
      try {
        await File(imagePath).delete();
      } catch (_) {/* already gone — ignore */}
    }

    // 4. User asked to retake — re-open the camera for a fresh shot.
    if (retry && mounted) {
      await _scanWithCamera();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Still loading the models (no error yet) → the camera button waits.
    final preparing = !_modelReady && _modelError == null;
    final busy = _isScanning || preparing;
    final displayError = _modelError ?? _error;

    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      appBar: AppBar(
        title: Text(tr(
            context,
            widget.mode == PlateScanMode.exit
                ? 'car_exit'
                : 'scan_plate_title')),
        backgroundColor: AppColors.surface(isDark),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(flex: 2),
            Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: AppColors.surface(isDark),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.camera_alt,
                    size: 72,
                    color: AppColors.primaryPink,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    tr(context, 'scan_plate'),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary(isDark),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tr(context, 'use_camera'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            if (displayError != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        displayError,
                        style: const TextStyle(color: Colors.red, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: busy
                    ? null
                    : (_modelError != null ? _retryWarmUp : _scanWithCamera),
                icon: busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : Icon(
                        _modelError != null
                            ? Icons.refresh
                            : Icons.camera_alt,
                        color: Colors.white),
                label: Text(
                  _isScanning
                      ? tr(context, 'scanning')
                      : preparing
                          ? tr(context, 'preparing_scanner')
                          : _modelError != null
                              ? tr(context, 'try_again')
                              : tr(context, 'open_camera'),
                  style: const TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryPink,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),
            ),
            const Spacer(flex: 3),
          ],
        ),
      ),
    );
  }
}
