import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapotech/shared/widgets/ui.dart';
import '../data/vitascale_models.dart';
import '../logic/anthropometry_mode.dart';

class VitaScaleStatusBar extends StatelessWidget {
  final ScreeningSession session;
  final DeviceConnectionStatus deviceStatus;
  final bool isCameraReady;
  final Color cardBgColor;
  final Color borderColor;
  final Color textColor;
  final Color subtitleColor;
  final Color themeAccent;
  final ValueChanged<AnthropometryMode> onModeChanged;
  final VoidCallback onCloseSession;

  const VitaScaleStatusBar({
    super.key,
    required this.session,
    required this.deviceStatus,
    required this.isCameraReady,
    required this.cardBgColor,
    required this.borderColor,
    required this.textColor,
    required this.subtitleColor,
    required this.themeAccent,
    required this.onModeChanged,
    required this.onCloseSession,
  });

  @override
  Widget build(BuildContext context) {
    final child = session.child;
    final warning = AnthropometryModeHelper.getOverrideWarning(
      ageInMonths: child.ageInMonths,
      chosenMode: session.mode,
    );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar Anak / Bayi
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: (child.gender == 'L' ? const Color(0xFF3498DB) : const Color(0xFFE91E63))
                      .withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  child.isUnder24Months ? Icons.child_friendly_rounded : Icons.face_rounded,
                  color: child.gender == 'L' ? const Color(0xFF3498DB) : const Color(0xFFE91E63),
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              // Detail Pasien
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            child.name,
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: textColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        StatusBadge(
                          label: child.gender == 'L' ? 'LAKI-LAKI' : 'PEREMPUAN',
                          color: child.gender == 'L' ? const Color(0xFF3498DB) : const Color(0xFFE91E63),
                          fontSize: 9,
                          showDot: false,
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: themeAccent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(
                            'USIA: ${child.ageLabel}',
                            style: GoogleFonts.outfit(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: themeAccent,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'NIK: ${child.nik} • Wali: ${child.parentName} • ID Sesi: ${session.sessionId}',
                      style: GoogleFonts.outfit(fontSize: 11, color: subtitleColor),
                    ),
                  ],
                ),
              ),
              // Status Indikator Hardware & Kamera
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  StatusBadge(
                    label: 'ESP32: ${deviceStatus.label}',
                    color: deviceStatus.color,
                    icon: Icons.wifi_rounded,
                    fontSize: 10,
                  ),
                  StatusBadge(
                    label: isCameraReady ? 'KAMERA AKTIF' : 'KAMERA MEMUAT',
                    color: isCameraReady ? const Color(0xFF2ECC71) : const Color(0xFFF39C12),
                    icon: Icons.videocam_rounded,
                    fontSize: 10,
                  ),
                  CustomButton(
                    text: 'Tutup Sesi',
                    isSecondary: true,
                    height: 34,
                    icon: Icons.close_rounded,
                    textColor: const Color(0xFFE74C3C),
                    borderColor: const Color(0xFFE74C3C).withValues(alpha: 0.4),
                    onPressed: onCloseSession,
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Baris Pemilihan Mode Antropometri
          Row(
            children: [
              Icon(Icons.straighten_rounded, size: 16, color: themeAccent),
              const SizedBox(width: 8),
              Text(
                'Mode Antropometri:',
                style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: textColor),
              ),
              const SizedBox(width: 10),
              // Pilihan Telentang vs Berdiri
              _buildModeChip(
                mode: AnthropometryMode.recumbentLength,
                isSelected: session.mode == AnthropometryMode.recumbentLength,
                label: 'Panjang Badan Telentang (< 24 Bln)',
              ),
              const SizedBox(width: 8),
              _buildModeChip(
                mode: AnthropometryMode.standingHeight,
                isSelected: session.mode == AnthropometryMode.standingHeight,
                label: 'Tinggi Badan Berdiri (≥ 24 Bln)',
              ),
              if (session.isModeManualOverride) ...[
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF39C12).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    'Disesuaikan Manual Petugas',
                    style: GoogleFonts.outfit(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFF39C12),
                    ),
                  ),
                ),
              ],
            ],
          ),

          if (warning != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF39C12).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFF39C12).withValues(alpha: 0.35)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFF39C12)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      warning,
                      style: GoogleFonts.outfit(
                        fontSize: 10.5,
                        color: textColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildModeChip({
    required AnthropometryMode mode,
    required bool isSelected,
    required String label,
  }) {
    return InkWell(
      onTap: () => onModeChanged(mode),
      borderRadius: BorderRadius.circular(100),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? themeAccent : Colors.transparent,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: isSelected ? themeAccent : borderColor,
            width: 1.2,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 10.5,
            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
            color: isSelected ? Colors.white : subtitleColor,
          ),
        ),
      ),
    );
  }
}
