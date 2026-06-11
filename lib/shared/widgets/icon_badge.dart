import 'package:flutter/material.dart';

/// A colored, rounded square containing an icon — the leading element of the
/// session cards on Dashboard, Check-Out and History.
class IconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double padding;
  final double radius;
  final double? iconSize;

  const IconBadge({
    super.key,
    required this.icon,
    required this.color,
    this.padding = 12,
    this.radius = 12,
    this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(icon, color: color, size: iconSize),
    );
  }
}
