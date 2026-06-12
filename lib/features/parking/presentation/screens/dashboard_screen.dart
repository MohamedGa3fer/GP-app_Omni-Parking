import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/l10n/app_translations.dart';
import '../../domain/entities/garage_settings.dart';
import '../../domain/entities/parking_session.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/icon_badge.dart';
import '../../../../shared/widgets/status_pill.dart';
import '../providers/parking_provider.dart';
import 'checkout_screen.dart';
import 'garage_config_screen.dart';
import 'history_screen.dart';
import 'manual_entry_screen.dart';
import 'plate_scan_mode.dart';
import 'scanner_screen.dart';
import 'session_filter.dart';
import 'session_ticket_screen.dart';
import 'settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // "Show All" on the dashboard jumps to the History tab.
    final screens = [
      _DashboardBody(onShowAll: () => setState(() => _selectedIndex = 2)),
      const CheckoutScreen(),
      const HistoryScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: screens[_selectedIndex],
      bottomNavigationBar: _buildBottomBar(context, isDark),
      // The Car-Entry circle is a center-docked button: rendered on top of
      // everything, so its whole area (including the part above the bar) is
      // tappable, and it overlaps the content for the raised look.
      floatingActionButton: _carEntryButton(context),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  // ── Custom bottom bar: 4 tabs + a raised central Car-Entry button ──────────

  Widget _buildBottomBar(BuildContext context, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface(isDark),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 66,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _navItem(
                context,
                index: 0,
                icon: Icons.dashboard_outlined,
                selectedIcon: Icons.dashboard,
                label: tr(context, 'dashboard'),
              ),
              _navItem(
                context,
                index: 1,
                icon: Icons.logout_outlined,
                selectedIcon: Icons.logout,
                label: tr(context, 'check_out'),
              ),
              // Center slot: just the "Scan Plate" label — the circle button
              // is the center-docked FAB sitting above it.
              Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      tr(context, 'scan_plate'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.primaryPink,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              _navItem(
                context,
                index: 2,
                icon: Icons.history_outlined,
                selectedIcon: Icons.history,
                label: tr(context, 'history'),
              ),
              _navItem(
                context,
                index: 3,
                icon: Icons.settings_outlined,
                selectedIcon: Icons.settings,
                label: tr(context, 'settings'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(
    BuildContext context, {
    required int index,
    required IconData icon,
    required IconData selectedIcon,
    required String label,
  }) {
    final selected = _selectedIndex == index;
    final color = selected ? AppColors.primaryPink : AppColors.textSecondary;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedIndex = index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(selected ? selectedIcon : icon, color: color, size: 24),
            const SizedBox(height: 4),
            // Reserve the label's height so icons stay aligned; the text only
            // shows for the selected tab.
            SizedBox(
              height: 14,
              child: selected
                  ? Text(
                      label,
                      style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  /// The Car-Entry circle. Used as a center-docked button so it sits over the
  /// bar's top edge and is fully tappable.
  Widget _carEntryButton(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _showEntryOptions(context),
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          gradient: AppColors.mainGradient,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryPink.withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(Icons.add_a_photo, color: Colors.white, size: 36),
      ),
    );
  }

  void _showEntryOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(25),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textSecondary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ── Car Entry ──────────────────────────────────────────────
              _buildSectionTitle(context, tr(context, 'car_entry')),
              const SizedBox(height: 15),
              _buildOptionTile(
                context: context,
                icon: Icons.camera_alt,
                title: tr(context, 'scan_plate'),
                subtitle: tr(context, 'use_camera'),
                color: AppColors.primaryPink,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ScannerScreen()),
                  );
                },
              ),
              const SizedBox(height: 12),
              _buildOptionTile(
                context: context,
                icon: Icons.keyboard,
                title: tr(context, 'enter_plate_manually'),
                subtitle: tr(context, 'enter_plate'),
                color: AppColors.primaryPurple,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ManualEntryScreen()),
                  );
                },
              ),
              const SizedBox(height: 24),

              // ── Car Exit ───────────────────────────────────────────────
              _buildSectionTitle(context, tr(context, 'car_exit')),
              const SizedBox(height: 15),
              _buildOptionTile(
                context: context,
                icon: Icons.logout,
                title: tr(context, 'scan_plate'),
                subtitle: tr(context, 'scan_to_checkout'),
                color: AppColors.secondary,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const ScannerScreen(mode: PlateScanMode.exit),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: const TextStyle(
        color: AppColors.primaryPink,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildOptionTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: color, size: 18),
          ],
        ),
      ),
    );
  }
}

class _DashboardBody extends StatefulWidget {
  final VoidCallback? onShowAll;
  const _DashboardBody({this.onShowAll});

  @override
  State<_DashboardBody> createState() => _DashboardBodyState();
}

class _DashboardBodyState extends State<_DashboardBody> {
  SessionFilter _filter = SessionFilter.all;

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ParkingProvider>(context);
    final localeService = Provider.of<LocaleService>(context, listen: false);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sessions = provider.state.activeSessions;
    final settings = provider.state.garageSettings;
    final error = provider.state.error;

    // Recent activity = active + completed, newest first (by checkout time, or
    // entry time if still parked), capped at 10. "Show All" opens History.
    final recent = [
      ...provider.state.activeSessions,
      ...provider.state.completedSessions,
    ];
    recent.sort(
      (a, b) =>
          (b.exitTime ?? b.entryTime).compareTo(a.exitTime ?? a.entryTime),
    );
    final recentActivity = _filter.apply(recent).take(10).toList();

    // Today's revenue = fees actually collected from check-outs that happened
    // today (exit time is today), not an estimate from active cars.
    final now = DateTime.now();
    final todaysRevenue = provider.state.completedSessions
        .where((s) => s.exitTime != null && isSameDay(s.exitTime!, now))
        .fold(0.0, (sum, s) => sum + s.totalFee);

    final needsSetup = provider.state.zones.isEmpty;

    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _buildHeader(context, localeService),
                _buildSearchBar(context, isDark),
                if (error != null) _buildErrorBanner(context, error),
                const SizedBox(height: 15),
                _buildStatsSection(
                  context,
                  sessions,
                  settings,
                  todaysRevenue,
                  isDark,
                ),
                const SizedBox(height: 25),
                _buildRecentActivityHeader(context),
                Expanded(
                  child: recentActivity.isEmpty
                      ? _buildEmptyState(context, isDark)
                      : _buildSessionsList(context, recentActivity, isDark),
                ),
              ],
            ),
          ),
          // First-time prompt: no garage configured yet.
          if (needsSetup) _buildSetupPrompt(context, isDark),
        ],
      ),
    );
  }

  /// Centered card shown when the user hasn't built their garage yet.
  Widget _buildSetupPrompt(BuildContext context, bool isDark) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.5),
        alignment: Alignment.center,
        child: Container(
          margin: const EdgeInsets.all(32),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surface(isDark),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.apartment,
                    color: AppColors.primary, size: 40),
              ),
              const SizedBox(height: 18),
              Text(
                tr(context, 'no_garage_title'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary(isDark),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                tr(context, 'no_garage_msg'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondaryColor(isDark),
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const GarageConfigScreen(isFirstRun: false),
                    ),
                  ),
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: Text(
                    tr(context, 'set_up_now'),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorBanner(BuildContext context, String error) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              error.replaceFirst('Exception: ', ''),
              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, LocaleService localeService) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
      decoration: const BoxDecoration(
        gradient: AppColors.mainGradient,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(35),
          bottomRight: Radius.circular(35),
        ),
      ),
      // The app name is always English and pinned to the left, even in
      // Arabic (RTL), so force LTR for the header block.
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Colors.white, Colors.white70],
                  ).createShader(bounds),
                  child: Text(
                    tr(context, 'app_name'),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  tr(context, 'dashboard'),
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface(isDark),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.search, color: AppColors.textSecondary, size: 20),
            const SizedBox(width: 10),
            Text(
              tr(context, 'search_plates'),
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSection(
    BuildContext context,
    List<ParkingSession> sessions,
    GarageSettings settings,
    double todaysRevenue,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              icon: Icons.directions_car,
              title: tr(context, 'cars'),
              value: sessions.length.toString(),
              color: AppColors.primaryPink,
              isDark: isDark,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              icon: Icons.local_parking,
              title: tr(context, 'available_spots'),
              value: (settings.totalCapacity - sessions.length).toString(),
              color: AppColors.successGreen,
              isDark: isDark,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              icon: Icons.account_balance_wallet,
              title: tr(context, 'revenue'),
              value: todaysRevenue.toStringAsFixed(0),
              color: AppColors.primaryPurple,
              isDark: isDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface(isDark),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          // Scale down so a large count/revenue never overflows the card.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivityHeader(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    tr(context, 'recent_activity'),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary(isDark),
                    ),
                  ),
                ),
                // Small dropdown to filter the list: All / Active / Completed.
                SessionFilterMenu(
                  value: _filter,
                  onSelected: (f) => setState(() => _filter = f),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.arrow_drop_down,
                      // Tinted when a filter is active, so it's clear the list
                      // isn't showing everything.
                      color: _filter == SessionFilter.all
                          ? AppColors.textSecondaryColor(isDark)
                          : AppColors.primaryPink,
                    ),
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: widget.onShowAll,
            child: Text(
              tr(context, 'show_all'),
              style: const TextStyle(color: AppColors.primaryPink),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    // Centered when there's room; scrolls instead of overflowing when the body
    // is squeezed (e.g. the keyboard opens).
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(
                  color: AppColors.surface(isDark),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.directions_car_filled_outlined,
                  size: 60,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                tr(context, 'parking_empty'),
                style: const TextStyle(
                  fontSize: 18,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                tr(context, 'tap_to_start'),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSessionsList(
    BuildContext context,
    List<ParkingSession> sessions,
    bool isDark,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: sessions.length,
      itemBuilder: (context, index) {
        final session = sessions[index];
        return AppCard(
          isDark: isDark,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SessionTicketScreen(session: session),
            ),
          ),
          child: Row(
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
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppColors.textPrimary(isDark),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.access_time,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          formatTime(context, session.entryTime),
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Icon(
                          Icons.location_on,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          session.zoneId,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              StatusPill(
                text: session.status == 'active'
                    ? tr(context, 'active')
                    : tr(context, 'completed'),
                color: session.status == 'active'
                    ? AppColors.successGreen
                    : Colors.grey,
              ),
            ],
          ),
        );
      },
    );
  }
}
