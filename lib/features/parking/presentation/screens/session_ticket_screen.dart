import 'package:flutter/material.dart';
import '../../../../core/l10n/app_translations.dart';
import '../../../../shared/widgets/status_pill.dart';
import '../../domain/entities/parking_session.dart';

/// Read-only ticket detail, opened by tapping a session card in the dashboard's
/// Recent Activity or in History. For an **active** session it shows the entry
/// ticket; for a **completed** one it additionally shows the checkout details
/// (exit date/time, duration, total fee).
class SessionTicketScreen extends StatelessWidget {
  final ParkingSession session;

  const SessionTicketScreen({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final completed = session.status == 'completed';
    final exitTime = session.exitTime;
    final accent = completed ? AppColors.successGreen : AppColors.primary;
    final durationLabel =
        '${session.durationHours.toStringAsFixed(1)} ${tr(context, 'hours_short')}';
    final feeLabel = '${session.totalFee.toStringAsFixed(2)} ${tr(context, 'egp')}';

    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      appBar: AppBar(
        backgroundColor: AppColors.surface(isDark),
        title: Text(tr(context, completed ? 'checkout_ticket' : 'entry_ticket')),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
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
                      color: accent.withValues(alpha: 0.2),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    StatusPill(
                      text: tr(context, completed ? 'completed' : 'active'),
                      color: completed ? Colors.grey : AppColors.successGreen,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      radius: 12,
                      fontSize: 12,
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.background(isDark),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Column(
                        children: [
                          _row(context, 'plate_number', displayPlate(session.licensePlate), AppColors.primaryPink, isDark),
                          const Divider(height: 20),
                          _row(context, 'zone', session.zoneId, AppColors.primaryPurple, isDark),
                          const Divider(height: 20),
                          _row(context, 'entry_date', formatDate(session.entryTime), AppColors.textPrimary(isDark), isDark),
                          const Divider(height: 20),
                          _row(context, 'entry_time', formatTime(context, session.entryTime), AppColors.textPrimary(isDark), isDark),
                          if (completed && exitTime != null) ...[
                            const Divider(height: 20),
                            _row(context, 'exit_date', formatDate(exitTime), AppColors.textPrimary(isDark), isDark),
                            const Divider(height: 20),
                            _row(context, 'exit_time', formatTime(context, exitTime), AppColors.textPrimary(isDark), isDark),
                            const Divider(height: 20),
                            _row(context, 'duration', durationLabel, AppColors.textPrimary(isDark), isDark),
                          ],
                        ],
                      ),
                    ),
                    if (completed) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            vertical: 16, horizontal: 20),
                        decoration: BoxDecoration(
                          color: AppColors.successGreen.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              tr(context, 'total_fee'),
                              style: TextStyle(
                                color: AppColors.textPrimary(isDark),
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              feeLabel,
                              style: const TextStyle(
                                color: AppColors.successGreen,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15)),
                  ),
                  child: Text(tr(context, 'done'),
                      style: const TextStyle(color: Colors.white, fontSize: 18)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String labelKey, String value,
      Color valueColor, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(tr(context, labelKey),
            style:
                TextStyle(color: AppColors.textSecondaryColor(isDark), fontSize: 14)),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
                color: valueColor, fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
