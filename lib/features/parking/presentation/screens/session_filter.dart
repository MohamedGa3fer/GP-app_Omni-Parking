import 'package:flutter/material.dart';
import '../../../../core/l10n/app_translations.dart';
import '../../domain/entities/parking_session.dart';

/// Active/completed filter shared by the dashboard's Recent Activity and the
/// History screen, so both behave (and look) identically.
enum SessionFilter { all, active, completed }

extension SessionFilterX on SessionFilter {
  /// Translation key for this option's label.
  String get labelKey => switch (this) {
        SessionFilter.all => 'all',
        SessionFilter.active => 'active',
        SessionFilter.completed => 'completed',
      };

  /// Filters a session list by status. [SessionFilter.all] is a no-op.
  List<ParkingSession> apply(List<ParkingSession> sessions) => switch (this) {
        SessionFilter.all => sessions,
        SessionFilter.active =>
          sessions.where((s) => s.status == 'active').toList(),
        SessionFilter.completed =>
          sessions.where((s) => s.status == 'completed').toList(),
      };
}

/// A dropdown that picks a [SessionFilter]. [child] is the tappable trigger
/// (an arrow on the dashboard, a filter icon in History). The menu uses the
/// app's popup theme; the selected row is shown in bold pink with a check.
class SessionFilterMenu extends StatelessWidget {
  final SessionFilter value;
  final ValueChanged<SessionFilter> onSelected;
  final Widget child;

  const SessionFilterMenu({
    super.key,
    required this.value,
    required this.onSelected,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<SessionFilter>(
      tooltip: tr(context, 'filter'),
      initialValue: value,
      onSelected: onSelected,
      itemBuilder: (_) =>
          SessionFilter.values.map((f) => _item(context, f)).toList(),
      child: child,
    );
  }

  PopupMenuItem<SessionFilter> _item(BuildContext context, SessionFilter f) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selected = f == value;
    return PopupMenuItem<SessionFilter>(
      value: f,
      child: Row(
        children: [
          Text(
            tr(context, f.labelKey),
            style: TextStyle(
              color: selected
                  ? AppColors.primaryPink
                  : AppColors.textPrimary(isDark),
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          const Spacer(),
          if (selected)
            const Icon(Icons.check_circle,
                color: AppColors.primaryPink, size: 18),
        ],
      ),
    );
  }
}
