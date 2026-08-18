import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum StatusBadgeVariant { filled, subtle, outline }

/// Status badge pill with optional dot/icon indicator and theme-adaptive coloring.
class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  final bool showDot;
  final StatusBadgeVariant variant;
  final double fontSize;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  const StatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.showDot = true,
    this.variant = StatusBadgeVariant.subtle,
    this.fontSize = 11.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    this.borderRadius = 100.0,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color border;
    Color textCol;

    switch (variant) {
      case StatusBadgeVariant.filled:
        bg = color;
        border = color;
        textCol = Colors.white;
        break;
      case StatusBadgeVariant.outline:
        bg = Colors.transparent;
        border = color.withValues(alpha: 0.5);
        textCol = color;
        break;
      case StatusBadgeVariant.subtle:
        bg = color.withValues(alpha: 0.12);
        border = color.withValues(alpha: 0.25);
        textCol = color;
        break;
    }

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: fontSize + 2, color: textCol),
            const SizedBox(width: 4),
          ] else if (showDot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: textCol,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              color: textCol,
            ),
          ),
        ],
      ),
    );
  }
}
