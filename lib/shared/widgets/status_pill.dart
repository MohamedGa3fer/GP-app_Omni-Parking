import 'package:flutter/material.dart';

/// A small rounded label (e.g. "Auto", "Active", "Completed") on a translucent
/// tint of [color].
class StatusPill extends StatelessWidget {
  final String text;
  final Color color;
  final EdgeInsets padding;
  final double radius;
  final double fontSize;
  final FontWeight fontWeight;

  const StatusPill({
    super.key,
    required this.text,
    required this.color,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    this.radius = 20,
    this.fontSize = 12,
    this.fontWeight = FontWeight.w500,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
        ),
      ),
    );
  }
}
