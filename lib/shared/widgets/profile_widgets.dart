import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ProfileSectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color cardBg;
  final Color border;
  final Color textColor;
  final Widget child;
  final Widget? trailing;
  final Color iconColor;

  const ProfileSectionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.cardBg,
    required this.border,
    required this.textColor,
    required this.child,
    this.trailing,
    this.iconColor = const Color(0xFFB577F2),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: textColor,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: border, height: 1),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class ProfileInfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color subtitleColor;
  final Color valueColor;
  final bool rightBold;
  final Color inputBg;
  final IconData? icon;

  const ProfileInfoRow({
    super.key,
    required this.label,
    required this.value,
    required this.subtitleColor,
    required this.valueColor,
    this.rightBold = false,
    required this.inputBg,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: inputBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.outfit(fontSize: 11, color: subtitleColor)),
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: subtitleColor),
                const SizedBox(width: 6),
              ],
              Text(
                value,
                style: GoogleFonts.outfit(
                  fontSize: icon != null ? 13 : 11,
                  fontWeight: rightBold || icon != null ? FontWeight.w900 : FontWeight.w600,
                  color: valueColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ProfileFieldGrid extends StatelessWidget {
  final List<Widget> children;
  final double spacing;

  const ProfileFieldGrid({
    super.key,
    required this.children,
    this.spacing = 12.0,
  });

  @override
  Widget build(BuildContext context) {
    final List<Widget> items = [];
    for (int i = 0; i < children.length; i++) {
      items.add(Expanded(child: children[i]));
      if (i < children.length - 1) {
        items.add(SizedBox(width: spacing));
      }
    }
    return Row(children: items);
  }
}

class ProfileField extends StatelessWidget {
  final String label;
  final String value;
  final Color inputBg;
  final Color valueColor;
  final Color subtitleColor;
  final IconData icon;
  final bool fullWidth;
  final bool isPlaceholder;

  const ProfileField({
    super.key,
    required this.label,
    required this.value,
    required this.inputBg,
    required this.valueColor,
    required this.subtitleColor,
    required this.icon,
    this.fullWidth = false,
    this.isPlaceholder = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 11, color: subtitleColor),
            const SizedBox(width: 5),
            Text(
              label.toUpperCase(),
              style: GoogleFonts.outfit(
                fontSize: 8,
                fontWeight: FontWeight.w900,
                color: subtitleColor,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          width: fullWidth ? double.infinity : null,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: inputBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: isPlaceholder ? FontWeight.w500 : FontWeight.w700,
              color: valueColor,
              fontStyle: isPlaceholder ? FontStyle.italic : FontStyle.normal,
            ),
          ),
        ),
      ],
    );
  }
}

class ProfileDropdownField extends StatelessWidget {
  final String label;
  final String value;
  final Color inputBg;
  final Color textColor;
  final Color subtitleColor;
  final Color borderTint;

  const ProfileDropdownField({
    super.key,
    required this.label,
    required this.value,
    required this.inputBg,
    required this.textColor,
    required this.subtitleColor,
    required this.borderTint,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w700, color: subtitleColor),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: inputBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderTint.withOpacity(0.15)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700, color: textColor),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: subtitleColor),
            ],
          ),
        ),
      ],
    );
  }
}
