import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Tagline badge pill commonly placed at top of portal hero sections.
class PortalTaglineBadge extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color activeColor;
  final Color cardColor;
  final Color textColor;

  const PortalTaglineBadge({
    super.key,
    required this.icon,
    required this.text,
    required this.activeColor,
    required this.cardColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: activeColor.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: activeColor.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: activeColor, size: 14),
          const SizedBox(width: 8),
          Text(
            text,
            style: GoogleFonts.outfit(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
              color: textColor.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small info badge chip (e.g. SatuSehat, BPJS) used in portal hero sections.
class PortalBadgeChip extends StatelessWidget {
  final Color cardColor;
  final Color borderColor;
  final Color textColor;
  final IconData icon;
  final Color iconColor;
  final String label;

  const PortalBadgeChip({
    super.key,
    required this.cardColor,
    required this.borderColor,
    required this.textColor,
    required this.icon,
    required this.iconColor,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// Section header for portal features with a category pill, main title, and description.
class PortalSectionHeader extends StatelessWidget {
  final String category;
  final String title;
  final String description;
  final Color activeColor;
  final Color textColor;
  final Color bodyTextColor;
  final bool isMobile;

  const PortalSectionHeader({
    super.key,
    required this.category,
    required this.title,
    required this.description,
    required this.activeColor,
    required this.textColor,
    required this.bodyTextColor,
    this.isMobile = false,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          Text(
            category,
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
              color: activeColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: isMobile ? 28 : 36,
              fontWeight: FontWeight.w900,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: bodyTextColor,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Reusable feature card with an icon container, title, and description.
class PortalFeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final Color cardColor;
  final Color borderColor;
  final Color textColor;
  final Color bodyTextColor;
  final EdgeInsetsGeometry padding;

  const PortalFeatureCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.cardColor,
    required this.borderColor,
    required this.textColor,
    required this.bodyTextColor,
    this.padding = const EdgeInsets.all(24),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: GoogleFonts.outfit(
              fontSize: 13,
              color: bodyTextColor,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
