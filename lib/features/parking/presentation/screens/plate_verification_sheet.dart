import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/l10n/app_translations.dart';
import '../../../../shared/widgets/plate_input_fields.dart';
import '../../domain/entities/plate_result.dart';
import '../providers/parking_provider.dart';
import 'checkout_ticket_screen.dart';
import 'plate_scan_mode.dart';
import 'zone_selection_screen.dart';

class PlateVerificationSheet extends StatefulWidget {
  final PlateResult plateResult;
  final PlateScanMode mode;

  const PlateVerificationSheet({
    super.key,
    required this.plateResult,
    this.mode = PlateScanMode.entry,
  });

  /// Returns `true` if the user tapped "Try Again" (caller should re-open the
  /// camera). Returns `null`/`false` otherwise.
  static Future<bool?> show(
    BuildContext context,
    PlateResult result, {
    PlateScanMode mode = PlateScanMode.entry,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface(isDark),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (_) => PlateVerificationSheet(plateResult: result, mode: mode),
    );
  }

  @override
  State<PlateVerificationSheet> createState() => _PlateVerificationSheetState();
}

class _PlateVerificationSheetState extends State<PlateVerificationSheet> {
  late TextEditingController _digitsController;
  late TextEditingController _lettersController;

  /// Exit mode only: set when no parked car matches the (corrected) plate.
  String? _exitError;

  bool get _isExit => widget.mode == PlateScanMode.exit;

  @override
  void initState() {
    super.initState();
    // Canonical plate is "digits + letters" (e.g. "7268مطو"). Split on the
    // first non-digit so each part gets its own field — no RTL/LTR conflict.
    final text = widget.plateResult.plateText;
    _digitsController =
        TextEditingController(text: PlateInputFields.digitsOf(text));
    // Letters are shown space-separated (م ط و) so Arabic doesn't render as a
    // connected word. The spaces are display-only — stripped in [_combined].
    _lettersController =
        TextEditingController(text: PlateInputFields.spacedLettersOf(text));
  }

  @override
  void dispose() {
    _digitsController.dispose();
    _lettersController.dispose();
    super.dispose();
  }

  /// Letters with the display spaces stripped back out.
  String get _lettersRaw => _lettersController.text.replaceAll(' ', '').trim();

  /// Recombine the two fields back into the canonical "digits + letters" form.
  String get _combined =>
      PlateInputFields.combine(_digitsController, _lettersController);

  bool get _isCorrected => _combined != widget.plateResult.plateText;

  bool get _isComplete =>
      _digitsController.text.trim().isNotEmpty && _lettersRaw.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = Provider.of<ParkingProvider>(context, listen: false);
    final normalized =
        _combined.toUpperCase().replaceAll(RegExp(r'[\s\-_]'), '');
    final existing = provider.state.activeSessions
        .where((s) => s.normalizedPlate == normalized)
        .toList();
    // A plate already parked is a *duplicate* on entry, but exactly what we
    // want on exit — so the duplicate warning only applies to entry.
    final isDuplicate = !_isExit && existing.isNotEmpty;
    final isLowConf = !isDuplicate &&
        widget.plateResult.isLowConfidence &&
        !_isCorrected;

    // Banner state: duplicate > low-confidence > ok.
    final Color accent;
    final IconData icon;
    final String title;
    if (isDuplicate) {
      accent = Colors.orange;
      icon = Icons.warning_amber;
      title = tr(context, 'plate_duplicate');
    } else if (isLowConf) {
      accent = Colors.amber;
      icon = Icons.help_outline;
      title = tr(context, 'low_confidence_title');
    } else {
      accent = AppColors.successGreen;
      icon = Icons.check_circle;
      title = tr(context, 'plate_detected');
    }

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: 25,
        right: 25,
        top: 25,
        bottom: MediaQuery.of(context).viewInsets.bottom + 25,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textSecondary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, color: accent, size: 40),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              color: isDuplicate || isLowConf
                  ? accent
                  : AppColors.textSecondaryColor(isDark),
            ),
          ),
          if (isDuplicate) ...[
            const SizedBox(height: 8),
            Text(
              '${tr(context, 'duplicate_session_msg')} ${existing.first.zoneId}',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondaryColor(isDark)),
            ),
          ] else if (isLowConf) ...[
            const SizedBox(height: 8),
            Text(
              tr(context, 'low_confidence_msg'),
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondaryColor(isDark)),
            ),
          ],
          const SizedBox(height: 20),

          // Two separate fields: Numbers (left) + Letters (right).
          PlateInputFields(
            digitsController: _digitsController,
            lettersController: _lettersController,
            isDark: isDark,
            onChanged: (_) => setState(() => _exitError = null),
          ),
          if (_exitError != null) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
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
                    child: Text(_exitError!,
                        style: const TextStyle(color: Colors.red, fontSize: 13)),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 25),
          // Try Again — always available. Pops the sheet with `true` so the
          // scanner re-opens the camera for a fresh shot. Amber when the read
          // is low-confidence ("Not sure about this plate"), otherwise blue.
          Builder(
            builder: (context) {
              final retryColor = isLowConf ? Colors.amber : AppColors.primary;
              return SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context, true),
                  icon: Icon(Icons.camera_alt, color: retryColor, size: 20),
                  label: Text(tr(context, 'try_again'),
                      style: TextStyle(color: retryColor, fontSize: 16)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: retryColor),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15)),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(
                        color: AppColors.textSecondaryColor(isDark)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15)),
                  ),
                  child: Text(tr(context, 'cancel'),
                      style: TextStyle(color: AppColors.textPrimary(isDark))),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: ElevatedButton(
                  onPressed: (isDuplicate || !_isComplete)
                      ? null
                      : () => _isExit
                          ? _findAndCheckout(provider, normalized)
                          : _proceedToEntry(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15)),
                  ),
                  child: Text(tr(context, _isExit ? 'check_out' : 'confirm_entry'),
                      style: const TextStyle(
                          color: Colors.white, fontSize: 16)),
                ),
              ),
            ],
          ),
          // Entry scan of an already-parked car: offer to check it out instead.
          if (!_isExit && isDuplicate) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _findAndCheckout(provider, normalized),
                icon: const Icon(Icons.logout, color: Colors.white, size: 20),
                label: Text(tr(context, 'check_out'),
                    style: const TextStyle(color: Colors.white, fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.successGreen,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Entry: hand the confirmed plate to zone selection for check-in.
  void _proceedToEntry() {
    final result = PlateResult(plateText: _combined);
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ZoneSelectionScreen(plateResult: result),
      ),
    );
  }

  /// Exit: find the parked car matching the confirmed plate and go straight to
  /// its checkout ticket. If nothing matches, surface an inline error.
  void _findAndCheckout(ParkingProvider provider, String normalized) {
    final matches = provider.state.activeSessions
        .where((s) => s.normalizedPlate == normalized)
        .toList();
    if (matches.isEmpty) {
      setState(() => _exitError = tr(context, 'car_not_found'));
      return;
    }
    final session = matches.first;
    final rate = provider.state.garageSettings.hourlyRateEgp;
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CheckoutTicketScreen(session: session, rate: rate),
      ),
    );
  }
}
