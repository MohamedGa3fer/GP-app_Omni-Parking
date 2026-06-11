import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/l10n/app_translations.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/icon_badge.dart';
import '../../../../shared/widgets/status_pill.dart';
import '../../domain/entities/parking_session.dart';
import '../providers/parking_provider.dart';
import 'session_filter.dart';
import 'session_ticket_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  SessionFilter _filter = SessionFilter.all;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Completed sessions aren't part of the dashboard's active load, so pull
    // them when History opens.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ParkingProvider>(
        context,
        listen: false,
      ).loadCompletedSessions();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = Provider.of<ParkingProvider>(context);
    final allSessions = [
      ...provider.state.activeSessions,
      ...provider.state.completedSessions,
    ];
    final now = DateTime.now();
    // "Today" = entered today OR checked out today, so today's revenue (which
    // is collected at checkout) counts cars that exited today even if they
    // entered earlier.
    final todaySessions = allSessions
        .where((s) =>
            isSameDay(s.entryTime, now) ||
            (s.exitTime != null && isSameDay(s.exitTime!, now)))
        .toList();

    // Apply the status filter + plate search to whichever tab is showing.
    final query = _searchController.text.trim().replaceAll(' ', '');
    List<ParkingSession> view(List<ParkingSession> list) {
      var out = _filter.apply(list);
      if (query.isNotEmpty) {
        out = out
            .where((s) => s.licensePlate.replaceAll(' ', '').contains(query))
            .toList();
      }
      return out;
    }

    return Scaffold(
      backgroundColor: AppColors.background(isDark),
      appBar: AppBar(
        backgroundColor: AppColors.surface(isDark),
        title: Text(tr(context, 'history')),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: [
            Tab(text: tr(context, 'today')),
            Tab(text: tr(context, 'all')),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildSearchAndFilter(isDark),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTabContent(view(todaySessions), isDark),
                _buildTabContent(view(allSessions), isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilter(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Expanded(
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
                  hintStyle:
                      TextStyle(color: AppColors.textSecondaryColor(isDark)),
                  prefixIcon: Icon(Icons.search,
                      color: AppColors.textSecondaryColor(isDark)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SessionFilterMenu(
            value: _filter,
            onSelected: (f) => setState(() => _filter = f),
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.surface(isDark),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(
                Icons.filter_list,
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
    );
  }

  Widget _buildTabContent(List<ParkingSession> sessions, bool isDark) {
    if (sessions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 60,
              color: AppColors.textSecondaryColor(isDark),
            ),
            const SizedBox(height: 16),
            Text(
              tr(context, 'no_transactions'),
              style: TextStyle(
                color: AppColors.textSecondaryColor(isDark),
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sessions.length + 1,
      itemBuilder: (_, index) {
        if (index == 0) {
          return _buildSummaryCard(sessions, isDark);
        }
        final session = sessions[index - 1];
        final statusColor = session.status == 'active'
            ? AppColors.successGreen
            : AppColors.primaryPink;
        return AppCard(
          isDark: isDark,
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          radius: 14,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SessionTicketScreen(session: session),
            ),
          ),
          child: Row(
            children: [
              IconBadge(
                icon: session.status == 'active' ? Icons.login : Icons.logout,
                color: statusColor,
                padding: 10,
                radius: 10,
                iconSize: 20,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayPlate(session.licensePlate),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppColors.textPrimary(isDark),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${tr(context, 'zone_label')}${bidiIsolate(session.zoneId)} · ${formatTime(context, session.entryTime)}',
                      style: TextStyle(
                        fontSize: 12,
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
                    '${session.totalFee.toStringAsFixed(2)} ${tr(context, 'egp')}',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  StatusPill(
                    text: session.status == 'active'
                        ? tr(context, 'active')
                        : tr(context, 'completed'),
                    color: session.status == 'active'
                        ? AppColors.successGreen
                        : Colors.grey,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    radius: 10,
                    fontSize: 10,
                    fontWeight: FontWeight.normal,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryCard(List<ParkingSession> sessions, bool isDark) {
    // All three metrics are completed-only so they stay consistent: a
    // still-parked car has no fee and no final duration, so it isn't a
    // finished transaction.
    final completed = sessions.where((s) => s.status == 'completed').toList();
    final totalRevenue = completed.fold(0.0, (sum, s) => sum + s.totalFee);
    final withDuration = completed.where((s) => s.durationHours > 0).toList();
    final totalDuration = withDuration.fold(
      0.0,
      (sum, s) => sum + s.durationHours,
    );
    final avgDur = withDuration.isNotEmpty
        ? totalDuration / withDuration.length
        : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.mainGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                Text(
                  '${completed.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  tr(context, 'transactions'),
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  totalRevenue.toStringAsFixed(0),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  tr(context, 'revenue'),
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  '${avgDur.toStringAsFixed(1)}${tr(context, 'hours_short')}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  tr(context, 'avg_duration'),
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
