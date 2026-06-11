import 'package:flutter/material.dart';
import '../../../../core/l10n/app_translations.dart';
import 'dashboard_screen.dart';

class TicketScreen extends StatelessWidget {
  final String plateText;
  final String zoneName;
  final DateTime entryTime;

  const TicketScreen({
    super.key,
    required this.plateText,
    required this.zoneName,
    required this.entryTime,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      appBar: AppBar(
        backgroundColor: AppColors.surface(isDark),
        title: Text(tr(context, 'entry_ticket')),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const DashboardScreen()),
            (route) => false,
          ),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  color: AppColors.surface(isDark),
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryPink.withValues(alpha: 0.2),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.background(isDark),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Column(
                        children: [
                          _buildTicketRow(tr(context, 'plate_number'), displayPlate(plateText), AppColors.primaryPink, isDark),
                          const Divider(height: 20),
                          _buildTicketRow(tr(context, 'zone'), zoneName, AppColors.primaryPurple, isDark),
                          const Divider(height: 20),
                          _buildTicketRow(tr(context, 'entry_date'), formatDate(entryTime), AppColors.textPrimary(isDark), isDark),
                          const Divider(height: 20),
                          _buildTicketRow(tr(context, 'entry_time'), formatTime(context, entryTime), AppColors.textPrimary(isDark), isDark),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      tr(context, 'check_in_success'),
                      style: const TextStyle(
                        color: AppColors.successGreen,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const DashboardScreen()),
                    (route) => false,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryPink,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  child: Text(tr(context, 'dashboard'), style: const TextStyle(color: Colors.white, fontSize: 18)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTicketRow(String label, String value, Color valueColor, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: AppColors.textSecondaryColor(isDark), fontSize: 14)),
        Text(value, style: TextStyle(color: valueColor, fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

