import 'package:flutter/material.dart';
import '../../../../core/l10n/app_translations.dart';
import '../../../../shared/widgets/plate_input_fields.dart';
import '../../domain/entities/plate_result.dart';
import 'zone_selection_screen.dart';

class ManualEntryScreen extends StatefulWidget {
  const ManualEntryScreen({super.key});

  @override
  State<ManualEntryScreen> createState() => _ManualEntryScreenState();
}

class _ManualEntryScreenState extends State<ManualEntryScreen> {
  final TextEditingController _digitsController = TextEditingController();
  final TextEditingController _lettersController = TextEditingController();

  @override
  void dispose() {
    _digitsController.dispose();
    _lettersController.dispose();
    super.dispose();
  }

  void _submit() {
    final plate = PlateInputFields.combine(_digitsController, _lettersController);
    if (plate.isEmpty) return;
    // The user typed it themselves (nothing to "verify"), so go straight to
    // zone selection — the duplicate guard runs at check-in.
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ZoneSelectionScreen(
          plateResult: PlateResult(plateText: plate),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      appBar: AppBar(
        title: Text(tr(context, 'manual_entry')),
        backgroundColor: AppColors.surface(isDark),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      // Scrollable so the keyboard never overflows the layout.
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface(isDark),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.keyboard,
                    size: 60,
                    color: AppColors.primaryPink,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    tr(context, 'enter_plate'),
                    style: TextStyle(
                      color: AppColors.textPrimary(isDark),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 25),
                  // Separate Numbers + Letters fields.
                  PlateInputFields(
                    digitsController: _digitsController,
                    lettersController: _lettersController,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryPink,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      child: Text(
                        tr(context, 'continue_btn'),
                        style: const TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
