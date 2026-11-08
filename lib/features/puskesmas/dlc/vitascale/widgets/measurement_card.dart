import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapotech/shared/widgets/ui.dart';
import '../data/vitascale_models.dart';

class MeasurementCard extends StatelessWidget {
  final MeasurementType type;
  final MeasurementItem item;
  final IconData icon;
  final Color cardBgColor;
  final Color borderColor;
  final Color textColor;
  final Color subtitleColor;
  final Color themeAccent;
  final VoidCallback onReset;
  final VoidCallback? onSimulate;
  final String? simulateLabel;

  const MeasurementCard({
    super.key,
    required this.type,
    required this.item,
    required this.icon,
    required this.cardBgColor,
    required this.borderColor,
    required this.textColor,
    required this.subtitleColor,
    required this.themeAccent,
    required this.onReset,
    this.onSimulate,
    this.simulateLabel,
  });

  @override
  Widget build(BuildContext context) {
    final hasVal = item.value != null;
    final displayValue = hasVal
        ? (type == MeasurementType.weight
              ? item.value!.toStringAsFixed(2)
              : item.value!.toStringAsFixed(1))
        : '—';

    return CustomCard(
      color: cardBgColor,
      borderColor: item.status == MeasurementStatus.failed
          ? const Color(0xFFE74C3C)
          : (item.status == MeasurementStatus.stable
                ? const Color(0xFF27AE60).withOpacity(0.5)
                : borderColor),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Parameter & Icon
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: themeAccent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, size: 16, color: themeAccent),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        type.label.toUpperCase(),
                        style: GoogleFonts.outfit(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                          color: textColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        'Satuan: ${type.unit}',
                        style: GoogleFonts.outfit(
                          fontSize: 9,
                          color: subtitleColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              StatusBadge(
                label: item.status.label,
                color: item.status.color,
                fontSize: 8.5,
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Angka Besar Nilai Pengukuran
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                displayValue,
                style: GoogleFonts.outfit(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  color: item.status == MeasurementStatus.failed
                      ? const Color(0xFFE74C3C)
                      : (item.status == MeasurementStatus.stable ||
                                item.status == MeasurementStatus.verified
                            ? const Color(0xFF27AE60)
                            : textColor),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                type.unit,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: subtitleColor,
                ),
              ),
            ],
          ),

          // Banner Error jika ada
          if (item.errorMessage != null && item.errorMessage!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFE74C3C).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    size: 14,
                    color: Color(0xFFE74C3C),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      item.errorMessage!,
                      style: GoogleFonts.outfit(
                        fontSize: 9.5,
                        color: const Color(0xFFE74C3C),
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const Spacer(),
          const Divider(height: 12),

          // Action Buttons: Ukur Ulang & Simulator Trigger
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: hasVal ? onReset : null,
                icon: const Icon(Icons.refresh_rounded, size: 14),
                label: Text(
                  'Ukur Ulang',
                  style: GoogleFonts.outfit(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: hasVal
                      ? textColor
                      : subtitleColor.withOpacity(0.4),
                ),
              ),
              if (onSimulate != null)
                CustomButton(
                  text: simulateLabel ?? 'Simulasi Data',
                  isSecondary: true,
                  height: 30,
                  icon: Icons.play_arrow_rounded,
                  textColor: themeAccent,
                  borderColor: themeAccent.withOpacity(0.3),
                  onPressed: onSimulate!,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
