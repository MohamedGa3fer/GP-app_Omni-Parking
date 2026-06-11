import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/l10n/app_translations.dart';
import '../../domain/entities/parking_session.dart';
import '../providers/parking_provider.dart';
import 'dashboard_screen.dart';

/// Checkout receipt + payment screen. Opens as a *payment-due* view for an
/// active session: it shows the amount owed but the car is NOT checked out yet.
/// Only after the operator taps "Confirm Payment" do we commit the checkout
/// (close the transaction, free the spot) and switch to the success state —
/// so we never claim success before payment is collected.
class CheckoutTicketScreen extends StatefulWidget {
  /// The active session being checked out (not yet completed).
  final ParkingSession session;
  final double rate;

  const CheckoutTicketScreen({
    super.key,
    required this.session,
    required this.rate,
  });

  @override
  State<CheckoutTicketScreen> createState() => _CheckoutTicketScreenState();
}

class _CheckoutTicketScreenState extends State<CheckoutTicketScreen> {
  bool _processing = false;

  /// Set once payment is confirmed and the checkout is committed. While null,
  /// the screen is in the payment-due state.
  ParkingSession? _completed;

  /// Merchant's online-payment QR, shown in the payment-due state if configured
  /// in Settings and the file still exists. Null = no online payment offered.
  String? _qrPath;

  bool get _paid => _completed != null;

  @override
  void initState() {
    super.initState();
    _loadPaymentQr();
  }

  Future<void> _loadPaymentQr() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString('payment_qr_path');
    if (path != null && File(path).existsSync() && mounted) {
      setState(() => _qrPath = path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Use the committed session once paid; otherwise a live preview from "now".
    final entryTime = widget.session.entryTime;
    final exitTime = _completed?.exitTime;
    final durationHours = _paid
        ? _completed!.durationHours
        : DateTime.now().difference(entryTime).inMinutes / 60.0;
    final billable = durationHours < 1.0 ? 1.0 : durationHours;
    final fee = _paid ? _completed!.totalFee : billable * widget.rate;

    final durationLabel =
        '${durationHours.toStringAsFixed(1)} ${tr(context, 'hours_short')}';
    final feeLabel = '${fee.toStringAsFixed(2)} ${tr(context, 'egp')}';
    final accent = _paid ? AppColors.successGreen : AppColors.primary;

    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      appBar: AppBar(
        backgroundColor: AppColors.surface(isDark),
        title: Text(tr(context, 'checkout_ticket')),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          // Once paid the checkout is committed — go home rather than back to
          // the scanner. Before payment, back is a normal cancel (pop).
          onPressed: _paid ? _goHome : () => Navigator.pop(context),
        ),
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
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.background(isDark),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Column(
                        children: [
                          _buildTicketRow(tr(context, 'plate_number'), displayPlate(widget.session.licensePlate), AppColors.primaryPink, isDark),
                          const Divider(height: 20),
                          _buildTicketRow(tr(context, 'zone'), widget.session.zoneId, AppColors.primaryPurple, isDark),
                          const Divider(height: 20),
                          _buildTicketRow(tr(context, 'entry_date'), formatDate(entryTime), AppColors.textPrimary(isDark), isDark),
                          const Divider(height: 20),
                          _buildTicketRow(tr(context, 'entry_time'), formatTime(context, entryTime), AppColors.textPrimary(isDark), isDark),
                          // Exit date/time only exist once checkout is committed.
                          if (exitTime != null) ...[
                            const Divider(height: 20),
                            _buildTicketRow(tr(context, 'exit_date'), formatDate(exitTime), AppColors.textPrimary(isDark), isDark),
                            const Divider(height: 20),
                            _buildTicketRow(tr(context, 'exit_time'), formatTime(context, exitTime), AppColors.textPrimary(isDark), isDark),
                          ],
                          const Divider(height: 20),
                          _buildTicketRow(tr(context, 'duration'), durationLabel, AppColors.textPrimary(isDark), isDark),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // The amount — labelled "Amount Due" until paid, "Total Fee" after.
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            tr(context, _paid ? 'total_fee' : 'amount_due'),
                            style: TextStyle(
                              color: AppColors.textPrimary(isDark),
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            feeLabel,
                            style: TextStyle(
                              color: accent,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Online-payment QR — only while awaiting payment.
                    if (!_paid && _qrPath != null) ...[
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Image.file(
                          File(_qrPath!),
                          width: 170,
                          height: 170,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        tr(context, 'scan_to_pay'),
                        style: TextStyle(
                          color: AppColors.textSecondaryColor(isDark),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Text(
                      tr(context, _paid ? 'checkout_success' : 'awaiting_payment'),
                      style: TextStyle(
                        color: _paid
                            ? AppColors.successGreen
                            : AppColors.textSecondaryColor(isDark),
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
                  onPressed: _processing
                      ? null
                      : (_paid ? _goHome : _confirmPayment),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  child: _processing
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          tr(context, _paid ? 'done' : 'confirm_payment'),
                          style: const TextStyle(color: Colors.white, fontSize: 18),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Returns to the dashboard, clearing the scanner/checkout screens behind
  /// this ticket so "Done" never lands back on the Scan Plate screen.
  void _goHome() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const DashboardScreen()),
      (route) => false,
    );
  }

  Future<void> _confirmPayment() async {
    setState(() => _processing = true);
    final provider = Provider.of<ParkingProvider>(context, listen: false);
    final completed = await provider.checkOut(widget.session.id!);
    if (!mounted) return;
    setState(() {
      _processing = false;
      _completed = completed;
    });
    if (completed == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(context, 'check_in_error'),
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  Widget _buildTicketRow(String label, String value, Color valueColor, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: AppColors.textSecondaryColor(isDark), fontSize: 14)),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(color: valueColor, fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
