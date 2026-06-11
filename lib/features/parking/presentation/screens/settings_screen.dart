import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gp_app/data/dataproviders/local_db_helper.dart';
import '../../../../core/l10n/app_translations.dart';
import 'garage_config_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  double _hourlyRate = 10.0;
  int _cleanHistoryDays = 0; // 0 = never
  String? _paymentQrPath; // null = no online-payment QR configured

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final qrPath = prefs.getString('payment_qr_path');
    // Treat a missing file as "not set" so a stale path never breaks the UI.
    final qrExists = qrPath != null && File(qrPath).existsSync();
    setState(() {
      _hourlyRate = prefs.getDouble('hourly_rate') ?? 10.0;
      _cleanHistoryDays = prefs.getInt('clean_history_days') ?? 0;
      _paymentQrPath = qrExists ? qrPath : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final localeService = Provider.of<LocaleService>(context, listen: false);
    final themeService = Provider.of<ThemeService>(context); // for the toggle
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = localeService.isArabic;

    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      appBar: AppBar(
        backgroundColor: AppColors.surface(isDark),
        title: Text(tr(context, 'settings')),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSettingsHeader(),
            const SizedBox(height: 25),

            // ── General ───────────────────────────────────────────────
            _buildSectionTitle(tr(context, 'general')),
            const SizedBox(height: 15),
            _buildSettingsList([
              _buildSettingsItem(
                context: context,
                icon: Icons.language,
                title: tr(context, 'language'),
                subtitle: isArabic
                    ? tr(context, 'arabic')
                    : tr(context, 'english'),
                onTap: () => _showLanguageSelector(context),
                isDark: isDark,
              ),
              _buildSettingsItem(
                context: context,
                icon: Icons.dark_mode,
                title: tr(context, 'dark_mode'),
                onTap: null,
                trailing: Switch(
                  value: isDark,
                  onChanged: (value) => themeService.setDarkMode(value),
                  activeTrackColor: AppColors.primaryPink,
                ),
                isDark: isDark,
              ),
            ]),
            const SizedBox(height: 25),

            // ── Garage ────────────────────────────────────────────────
            _buildSectionTitle(tr(context, 'garage')),
            const SizedBox(height: 15),
            _buildSettingsList([
              _buildSettingsItem(
                context: context,
                icon: Icons.grid_view,
                title: tr(context, 'manage_zones'),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        const GarageConfigScreen(isFirstRun: false),
                  ),
                ),
                isDark: isDark,
              ),
              _buildSettingsItem(
                context: context,
                icon: Icons.attach_money,
                title: tr(context, 'hourly_rate'),
                subtitle:
                    '${_hourlyRate.toStringAsFixed(0)} ${tr(context, 'egp_hour')}',
                onTap: () => _showRateDialog(context),
                isDark: isDark,
              ),
              _buildSettingsItem(
                context: context,
                icon: Icons.qr_code_2,
                title: tr(context, 'payment_qr'),
                subtitle: _paymentQrPath == null
                    ? tr(context, 'payment_qr_none')
                    : tr(context, 'payment_qr_set'),
                trailing: _paymentQrPath == null
                    ? null
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.file(
                          File(_paymentQrPath!),
                          width: 36,
                          height: 36,
                          fit: BoxFit.cover,
                        ),
                      ),
                onTap: () => _showPaymentQrSheet(context),
                isDark: isDark,
              ),
              _buildSettingsItem(
                context: context,
                icon: Icons.auto_delete_outlined,
                title: tr(context, 'clean_history'),
                subtitle: _cleanHistoryLabel(context),
                onTap: () => _showCleanHistorySheet(context),
                isDark: isDark,
              ),
            ]),
            const SizedBox(height: 25),

            // ── App ───────────────────────────────────────────────────
            _buildSectionTitle(tr(context, 'app')),
            const SizedBox(height: 15),
            _buildSettingsList([
              _buildSettingsItem(
                context: context,
                icon: Icons.info,
                title: tr(context, 'about'),
                subtitle: '${tr(context, 'version')} 1.0.0',
                onTap: () => _showAboutDialog(context),
                isDark: isDark,
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.mainGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(Icons.settings, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 20),
          Expanded(
            // Scale down to fit on a single row if the text is too wide.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                tr(context, 'customize_experience'),
                maxLines: 1,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: AppColors.primaryPink,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildSettingsList(List<Widget> items) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface(isDark),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: items.asMap().entries.map((entry) {
          final isLast = entry.key == items.length - 1;
          return Column(
            children: [
              entry.value,
              if (!isLast)
                Divider(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.05)),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSettingsItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primaryPink.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.primaryPink, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: AppColors.textPrimary(isDark),
                  fontSize: 16,
                ),
              ),
            ),
            if (subtitle != null && subtitle.isNotEmpty)
              Text(
                subtitle,
                style: TextStyle(
                  color: AppColors.textSecondaryColor(isDark),
                  fontSize: 14,
                ),
              ),
            ?trailing,
            if (onTap != null && trailing == null) ...[
              const SizedBox(width: 8),
              Icon(
                // arrow_forward_ios auto-mirrors in RTL (→ in LTR, ← in Arabic).
                Icons.arrow_forward_ios,
                color: AppColors.textSecondaryColor(isDark),
                size: 16,
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _cleanHistoryLabel(BuildContext context) {
    switch (_cleanHistoryDays) {
      case 7:
        return tr(context, 'after_7_days');
      case 30:
        return tr(context, 'after_30_days');
      case 90:
        return tr(context, 'after_90_days');
      default:
        return tr(context, 'never');
    }
  }

  Future<void> _showRateDialog(BuildContext context) async {
    final controller =
        TextEditingController(text: _hourlyRate.toStringAsFixed(0));
    final messenger = ScaffoldMessenger.of(context);
    final rateUpdatedMsg = tr(context, 'rate_updated');
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(tr(ctx, 'hourly_rate'),
            style: TextStyle(color: AppColors.textPrimary(isDark))),
        content: TextField(
          controller: controller,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          style: TextStyle(
              color: AppColors.textPrimary(isDark),
              fontSize: 24,
              fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            hintText: '10',
            hintStyle: const TextStyle(color: AppColors.textSecondary),
            suffix: Text(tr(ctx, 'egp_hour'),
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 14)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  BorderSide(color: AppColors.primary.withValues(alpha: 0.4)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr(ctx, 'cancel'),
                style: const TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              final v = double.tryParse(controller.text.trim());
              if (v != null && v > 0) Navigator.pop(ctx, v);
            },
            child: Text(tr(ctx, 'done'),
                style: const TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
    if (result != null && mounted) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('hourly_rate', result);
      setState(() => _hourlyRate = result);
      messenger.showSnackBar(SnackBar(
        content: Text(rateUpdatedMsg),
        backgroundColor: AppColors.successGreen,
      ));
    }
  }

  void _showPaymentQrSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(25),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.textSecondary,
                    borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 20),
              Text(tr(ctx, 'payment_qr'),
                  style: TextStyle(
                      color: AppColors.textPrimary(isDark),
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(tr(ctx, 'payment_qr_hint'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 20),
              if (_paymentQrPath != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(_paymentQrPath!),
                    width: 160,
                    height: 160,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 20),
              ],
              _buildSheetAction(
                icon: Icons.photo_library_outlined,
                label: tr(ctx, 'choose_from_gallery'),
                color: AppColors.primary,
                isDark: isDark,
                onTap: () => _pickPaymentQr(ctx),
              ),
              if (_paymentQrPath != null)
                _buildSheetAction(
                  icon: Icons.delete_outline,
                  label: tr(ctx, 'remove'),
                  color: Colors.red,
                  isDark: isDark,
                  onTap: () => _removePaymentQr(ctx),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSheetAction({
    required IconData icon,
    required String label,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 14),
            Text(label,
                style: TextStyle(
                    color: AppColors.textPrimary(isDark), fontSize: 16)),
          ],
        ),
      ),
    );
  }

  Future<void> _pickPaymentQr(BuildContext sheetCtx) async {
    final messenger = ScaffoldMessenger.of(context);
    final qrUpdatedMsg = tr(context, 'qr_updated');
    final picked =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    // Copy into app storage under a fresh name; a unique filename avoids
    // Flutter's path-keyed image cache showing the previous QR.
    final docs = await getApplicationDocumentsDirectory();
    final ext = picked.path.contains('.') ? picked.path.split('.').last : 'png';
    final dest =
        '${docs.path}/payment_qr_${DateTime.now().millisecondsSinceEpoch}.$ext';
    await picked.saveTo(dest);

    final old = _paymentQrPath;
    if (old != null && old != dest && File(old).existsSync()) {
      try {
        File(old).deleteSync();
      } catch (_) {}
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('payment_qr_path', dest);
    if (!mounted) return;
    setState(() => _paymentQrPath = dest);
    if (sheetCtx.mounted) Navigator.pop(sheetCtx);
    messenger.showSnackBar(SnackBar(
      content: Text(qrUpdatedMsg),
      backgroundColor: AppColors.successGreen,
    ));
  }

  Future<void> _removePaymentQr(BuildContext sheetCtx) async {
    final messenger = ScaffoldMessenger.of(context);
    final qrRemovedMsg = tr(context, 'qr_removed');
    final old = _paymentQrPath;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('payment_qr_path');
    if (old != null && File(old).existsSync()) {
      try {
        File(old).deleteSync();
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() => _paymentQrPath = null);
    if (sheetCtx.mounted) Navigator.pop(sheetCtx);
    messenger.showSnackBar(SnackBar(
      content: Text(qrRemovedMsg),
      backgroundColor: AppColors.successGreen,
    ));
  }

  void _showCleanHistorySheet(BuildContext context) {
    final options = [
      (0, tr(context, 'never')),
      (7, tr(context, 'after_7_days')),
      (30, tr(context, 'after_30_days')),
      (90, tr(context, 'after_90_days')),
    ];
    final messenger = ScaffoldMessenger.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          padding: const EdgeInsets.all(25),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.textSecondary,
                    borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 20),
              Text(tr(ctx, 'clean_history'),
                  style: TextStyle(
                      color: AppColors.textPrimary(isDark),
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(tr(ctx, 'auto_delete'),
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 20),
              ...options.map((opt) {
                final (days, label) = opt;
                final selected = _cleanHistoryDays == days;
                return InkWell(
                  onTap: () async {
                    setSheetState(() {});
                    setState(() => _cleanHistoryDays = days);
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setInt('clean_history_days', days);
                    if (days > 0) {
                      final deleted = await LocalDbHelper.instance
                          .deleteOldCompletedTransactions(days);
                      if (deleted > 0 && ctx.mounted) {
                        messenger.showSnackBar(SnackBar(
                          content: Text(tr(context, 'history_cleaned')),
                          backgroundColor: AppColors.successGreen,
                        ));
                      }
                    }
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.primary.withValues(alpha: 0.1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected
                            ? AppColors.primary
                            : AppColors.textSecondary
                                .withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          days == 0
                              ? Icons.block
                              : Icons.auto_delete_outlined,
                          color: selected
                              ? AppColors.primary
                              : AppColors.textSecondary,
                          size: 20,
                        ),
                        const SizedBox(width: 14),
                        Text(label,
                            style: TextStyle(
                              color: selected
                                  ? AppColors.primary
                                  : AppColors.textPrimary(isDark),
                              fontSize: 16,
                            )),
                        const Spacer(),
                        if (selected)
                          const Icon(Icons.check_circle,
                              color: AppColors.primary),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  void _showLanguageSelector(BuildContext context) {
    final localeService =
        Provider.of<LocaleService>(context, listen: false);
    final isArabic = localeService.isArabic;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(25),
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
            Text(
              tr(ctx, 'select_language'),
              style: TextStyle(
                color: AppColors.textPrimary(isDark),
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            _buildLanguageOption(
              tr(ctx, 'english'),
              'EN',
              !isArabic,
              isDark,
              () async {
                final nav = Navigator.of(ctx);
                await localeService.setLocale(const Locale('en'));
                if (mounted) nav.pop();
              },
            ),
            _buildLanguageOption(
              tr(ctx, 'arabic'),
              'AR',
              isArabic,
              isDark,
              () async {
                final nav = Navigator.of(ctx);
                await localeService.setLocale(const Locale('ar'));
                if (mounted) nav.pop();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageOption(
    String language,
    String code,
    bool isSelected,
    bool isDark,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryPink.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppColors.primaryPink
                : AppColors.textSecondary.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primaryPink
                    : AppColors.textSecondary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                code,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 15),
            Text(
              language,
              style: TextStyle(
                color: isSelected
                    ? AppColors.primaryPink
                    : AppColors.textPrimary(isDark),
                fontSize: 16,
              ),
            ),
            const Spacer(),
            if (isSelected)
              const Icon(Icons.check_circle,
                  color: AppColors.primaryPink),
          ],
        ),
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: AppColors.mainGradient,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.directions_car,
                  color: Colors.white, size: 50),
            ),
            const SizedBox(height: 20),
            Text(
              'Omni Parking',
              style: TextStyle(
                color: AppColors.textPrimary(isDark),
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '${tr(context, 'version')} 1.0.0',
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              tr(context, 'close'),
              style: const TextStyle(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}
