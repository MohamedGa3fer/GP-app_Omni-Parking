import 'package:flutter/material.dart';
import 'package:gp_app/core/l10n/app_translations.dart';

/// The rounded surface container used for list items across the app. Supports
/// an optional selected state (highlight tint + border) and a tap handler.
class AppCard extends StatelessWidget {
  final Widget child;
  final bool isDark;
  final EdgeInsets margin;
  final EdgeInsets padding;
  final double radius;
  final bool selected;
  final Color selectedColor;
  final VoidCallback? onTap;

  const AppCard({
    super.key,
    required this.child,
    required this.isDark,
    this.margin = const EdgeInsets.only(bottom: 12),
    this.padding = const EdgeInsets.all(16),
    this.radius = 16,
    this.selected = false,
    this.selectedColor = AppColors.primaryPink,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: selected
            ? selectedColor.withValues(alpha: 0.1)
            : AppColors.surface(isDark),
        borderRadius: BorderRadius.circular(radius),
        border: selected ? Border.all(color: selectedColor, width: 2) : null,
        // Soft lift so cards separate from the background (mainly in light
        // theme; on dark surfaces a black shadow is effectively invisible).
        boxShadow: selected
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: child,
    );
    if (onTap == null) return card;
    return GestureDetector(onTap: onTap, child: card);
  }
}
