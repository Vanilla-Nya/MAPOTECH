import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class MetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String count;
  final Color subtitleColor;
  final Color countColor;
  final Color cardBgColor;
  final Color borderColor;

  const MetricCard({
    super.key,
    required this.icon,
    required this.label,
    required this.count,
    required this.subtitleColor,
    required this.countColor,
    required this.cardBgColor,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: subtitleColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: subtitleColor,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            count,
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: countColor,
            ),
          ),
        ],
      ),
    );
  }
}
