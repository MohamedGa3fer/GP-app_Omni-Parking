import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/l10n/app_translations.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/icon_badge.dart';
import '../../domain/entities/parking_session.dart';
import '../providers/parking_provider.dart';
import 'checkout_ticket_screen.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _searchController = TextEditingController();
  ParkingSession? _selectedSession;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ParkingProvider>(context, listen: false).loadActiveSessions();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = Provider.of<ParkingProvider>(context);
    final sessions = provider.state.activeSessions;
    final rate = provider.state.garageSettings.hourlyRateEgp;

    // Match against the plate with spaces stripped so a query works whether the
    // user types digits or letters. (toUpperCase is a no-op for Arabic/digits.)
    final query = _searchController.text.trim().replaceAll(' ', '');
    final filtered = query.isEmpty
        ? sessions
        : sessions
              .where((s) => s.licensePlate.replaceAll(' ', '').contains(query))
              .toList();

    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      appBar: AppBar(
        backgroundColor: AppColors.surface(isDark),
        title: Text(tr(context, 'check_out')),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface(isDark),
                borderRadius: BorderRadius.circular(15),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                style: TextStyle(color: AppColors.textPrimary(isDark)),
                decoration: InputDecoration(
                  hintText: tr(context, 'search_by_plate'),
                  hintStyle: TextStyle(
                    color: AppColors.textSecondaryColor(isDark),
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: AppColors.textSecondaryColor(isDark),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      tr(context, 'no_active_sessions'),
                      style: TextStyle(
                        color: AppColors.textSecondaryColor(isDark),
                        fontSize: 16,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filtered.length,
                    itemBuilder: (_, index) =>
                        _buildSessionCard(filtered[index], isDark, rate),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionCard(ParkingSession session, bool isDark, double rate) {
    final isSelected = _selectedSession?.id == session.id;
    final now = DateTime.now();
    final hours = now.difference(session.entryTime).inMinutes / 60.0;
    final fee = hours * rate;

    return AppCard(
      isDark: isDark,
      selected: isSelected,
      onTap: () => setState(() => _selectedSession = session),
      child: Column(
        children: [
          Row(
            children: [
              const IconBadge(
                icon: Icons.directions_car,
                color: AppColors.primaryPurple,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayPlate(session.licensePlate),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary(isDark),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${tr(context, 'zone_label')}${bidiIsolate(session.zoneId)} - ${formatTime(context, session.entryTime)}',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondaryColor(isDark),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${hours.toStringAsFixed(1)}${tr(context, 'hours_short')}',
                    style: TextStyle(
                      color: AppColors.textSecondaryColor(isDark),
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    '${fee.toStringAsFixed(2)} ${tr(context, 'egp')}',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (isSelected) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _confirmCheckout(session, rate),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryPurple,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  '${tr(context, 'confirm_checkout')}${fee.toStringAsFixed(2)} ${tr(context, 'egp')}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Opens the checkout ticket as a *payment-due* screen. The car is NOT
  /// checked out yet — the actual checkout (closing the transaction, freeing
  /// the spot) happens on the ticket only after payment is confirmed.
  void _confirmCheckout(ParkingSession session, double rate) {
    setState(() => _selectedSession = null);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CheckoutTicketScreen(session: session, rate: rate),
      ),
    );
  }
}
