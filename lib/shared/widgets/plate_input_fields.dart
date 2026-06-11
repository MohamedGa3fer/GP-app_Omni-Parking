import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gp_app/core/l10n/app_translations.dart';

/// The two side-by-side plate inputs — **Numbers** (left, LTR, digits, max 4)
/// and **Letters** (right, RTL, Arabic, space-separated, max 3). Shared by the
/// manual-entry screen and the plate-verification sheet so both behave
/// identically. The parent owns the two controllers.
class PlateInputFields extends StatelessWidget {
  final TextEditingController digitsController;
  final TextEditingController lettersController;
  final bool isDark;

  /// Called (with the recombined canonical plate) whenever either field changes.
  final ValueChanged<String>? onChanged;

  const PlateInputFields({
    super.key,
    required this.digitsController,
    required this.lettersController,
    required this.isDark,
    this.onChanged,
  });

  // ── Canonical <-> field helpers ───────────────────────────────────────────

  /// Digits part of a canonical plate: "7268مطو" → "7268".
  static String digitsOf(String canonical) =>
      RegExp(r'^(\d*)').firstMatch(canonical)?.group(1) ?? '';

  /// Letters part, space-separated for display: "7268مطو" → "م ط و".
  static String spacedLettersOf(String canonical) {
    final m = RegExp(r'^\d*(.*)$').firstMatch(canonical);
    return (m?.group(1) ?? '').split('').join(' ');
  }

  /// Recombine the two controllers into canonical "digits + letters" form
  /// (letters with the display spaces stripped).
  static String combine(
    TextEditingController digits,
    TextEditingController letters,
  ) =>
      '${digits.text.trim()}${letters.text.replaceAll(' ', '').trim()}';

  @override
  Widget build(BuildContext context) {
    // Forced LTR so digits stay on the left and letters on the right, matching
    // how the plate reads, regardless of app locale.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: _field(
              context: context,
              controller: digitsController,
              label: tr(context, 'numbers_label'),
              direction: TextDirection.ltr,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(4),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: _field(
              context: context,
              controller: lettersController,
              label: tr(context, 'letters_label'),
              direction: TextDirection.rtl,
              keyboardType: TextInputType.text,
              inputFormatters: [
                // Arabic letters only (block digits & latin)
                FilteringTextInputFormatter.deny(RegExp(r'[0-9a-zA-Z]')),
                // Keep letters space-separated (max 3) as the user types
                _SpacedLettersFormatter(maxLetters: 3),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _field({
    required BuildContext context,
    required TextEditingController controller,
    required String label,
    required TextDirection direction,
    required TextInputType keyboardType,
    required List<TextInputFormatter> inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondaryColor(isDark),
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          textAlign: TextAlign.center,
          textDirection: direction,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          onChanged: (_) =>
              onChanged?.call(combine(digitsController, lettersController)),
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary(isDark),
            letterSpacing: 3,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.surface(isDark),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide:
                  BorderSide(color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
          ),
        ),
      ],
    );
  }
}

/// Keeps Arabic plate letters space-separated as the user types (e.g. "م ط و")
/// so they don't render as a connected word, while capping the raw letter
/// count. The spaces are display-only; callers strip them before storing.
class _SpacedLettersFormatter extends TextInputFormatter {
  _SpacedLettersFormatter({required this.maxLetters});

  final int maxLetters;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var raw = newValue.text.replaceAll(' ', '');
    if (raw.length > maxLetters) raw = raw.substring(0, maxLetters);
    final spaced = raw.split('').join(' ');
    return TextEditingValue(
      text: spaced,
      selection: TextSelection.collapsed(offset: spaced.length),
    );
  }
}
