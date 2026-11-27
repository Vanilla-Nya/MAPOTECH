import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapotech/shared/widgets/celestial_theme_transition.dart';

class SettingsSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color textColor;
  final Color subtitleColor;
  final Widget child;

  const SettingsSection({
    super.key,
    required this.title,
    required this.subtitle,
    required this.textColor,
    required this.subtitleColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: textColor,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: GoogleFonts.outfit(fontSize: 11, color: subtitleColor),
        ),
        const SizedBox(height: 14),
        child,
      ],
    );
  }
}

class SettingsChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool isSelected;
  final VoidCallback? onTap;
  final ValueChanged<Offset?>? onTapWithOrigin;
  final Color purple;
  final Color teal;
  final bool isDark;
  final Color borderColor;
  final EdgeInsetsGeometry padding;

  const SettingsChip({
    super.key,
    required this.label,
    this.icon,
    required this.isSelected,
    this.onTap,
    this.onTapWithOrigin,
    required this.purple,
    required this.teal,
    required this.isDark,
    required this.borderColor,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
  });

  @override
  Widget build(BuildContext context) {
    final Color activeColor = isDark ? teal : purple;
    final Color bg = isSelected
        ? activeColor.withValues(alpha: 0.12)
        : (isDark ? const Color(0xFF1E1E22) : Colors.white);
    final Color fg = isSelected ? activeColor : (isDark ? Colors.grey[400]! : const Color(0xFF6F6A8A));

    return Builder(
      builder: (chipContext) => GestureDetector(
        onTap: () {
          if (onTapWithOrigin != null) {
            onTapWithOrigin!(
              CelestialThemeCoordinator.globalCenterOf(chipContext),
            );
          }
          onTap?.call();
        },
        child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: padding,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? activeColor : borderColor,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: fg),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }
}
