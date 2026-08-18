import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Reusable filter chip button with selection state, badge count, and theme integration.
class CustomFilterChip<T> extends StatelessWidget {
  final String label;
  final T value;
  final T selectedValue;
  final ValueChanged<T> onSelected;
  final Color? activeColor;
  final Color? inactiveBgColor;
  final Color? inactiveTextColor;
  final Color? borderColor;
  final int? count;
  final IconData? icon;

  const CustomFilterChip({
    super.key,
    required this.label,
    required this.value,
    required this.selectedValue,
    required this.onSelected,
    this.activeColor,
    this.inactiveBgColor,
    this.inactiveTextColor,
    this.borderColor,
    this.count,
    this.icon,
  });

  bool get isSelected => value == selectedValue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final accent = activeColor ?? theme.colorScheme.primary;
    final inBg = inactiveBgColor ?? (isDark ? const Color(0xFF1E1E22) : Colors.white);
    final inText = inactiveTextColor ?? (isDark ? Colors.grey[400]! : const Color(0xFF6F6A8A));
    final border = borderColor ?? (isDark ? const Color(0xFF2B2B30) : const Color(0xFFECEEF2));

    return InkWell(
      onTap: () => onSelected(value),
      borderRadius: BorderRadius.circular(100),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? accent : inBg,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: isSelected ? accent : border,
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: isSelected ? Colors.white : inText,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : inText,
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.2)
                      : inText.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  count.toString(),
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : inText,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
