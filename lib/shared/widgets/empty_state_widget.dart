import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle; // Make subtitle optional
  final Color cardBg;
  final Color border;
  final Color textColor;
  final Color subtitleColor;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.cardBg,
    required this.border,
    required this.textColor,
    required this.subtitleColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 60),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: subtitleColor.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w900, color: textColor),
            textAlign: TextAlign.center,
          ),
          if (subtitle != null && subtitle!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              style: GoogleFonts.outfit(fontSize: 11, color: subtitleColor),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
