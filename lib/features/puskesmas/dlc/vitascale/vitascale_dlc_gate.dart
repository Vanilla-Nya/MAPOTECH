import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapotech/features/landing/landing_page_data.dart';
import 'package:mapotech/shared/widgets/ui.dart';

/// Provider lokal untuk status pembukaan kunci Modul DLC VitaScale
final vitascaleDlcUnlockedProvider = StateProvider<bool>((ref) => false);

/// Wrapper pengaman DLC terkunci sesuai aturan Rule.md §5
class VitaScaleDlcGate extends ConsumerWidget {
  final Widget child;
  final String menuTitle;

  const VitaScaleDlcGate({
    super.key,
    required this.child,
    this.menuTitle = 'VITASCALE By MAPOTECH',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isUnlocked = ref.watch(vitascaleDlcUnlockedProvider);
    ref.watch(landingPageProvider);
    final notifier = ref.read(landingPageProvider.notifier);

    final cardBgColor = notifier.getCardColor();
    final textColor = notifier.getTextColor();
    final subtitleColor = notifier.getBodyTextColor();
    final borderColor = notifier.getBorderColor();
    final themeAccent = notifier.getPrimaryColor();

    if (isUnlocked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner penanda Mode Pratinjau / Demo DLC
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF39C12).withOpacity(0.15),
              border: Border(
                bottom: BorderSide(color: const Color(0xFFF39C12).withOpacity(0.4)),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFFF39C12)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'MODE PRATINJAU DLC (DEMO): Modul VitaScale aktif dalam mode pratinjau. '
                    'Seluruh pengukuran simulator & fixture tidak disimpan ke rekam medis final pasien asli.',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFF39C12),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    ref.read(vitascaleDlcUnlockedProvider.notifier).state = false;
                  },
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: const Color(0xFFE74C3C),
                  ),
                  child: Text(
                    'Kunci Kembali',
                    style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: child),
        ],
      );
    }

    // Tampilan Terkunci (Locked by Default - Rule.md §5)
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: CustomCard(
            color: cardBgColor,
            borderColor: borderColor,
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: themeAccent.withOpacity(0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: themeAccent.withOpacity(0.25), width: 2),
                  ),
                  alignment: Alignment.center,
                  child: Icon(Icons.lock_outline_rounded, size: 38, color: themeAccent),
                ),
                const SizedBox(height: 20),
                StatusBadge(
                  label: 'MODUL DLC TERKUNCI (ADD-ON)',
                  color: themeAccent,
                  variant: StatusBadgeVariant.subtle,
                  fontSize: 10,
                ),
                const SizedBox(height: 12),
                Text(
                  'Modul DLC: $menuTitle',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Fitur skrining antropometri digital terintegrasi perangkat keras VitaScale '
                  '(Load Cell HX711, Pengukur Sudut AS5600, dan Computer Vision OpenCV.js). '
                  'Faskes Anda memerlukan lisensi ekspansi DLC untuk mengaktifkan modul ini.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: subtitleColor,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: themeAccent.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: themeAccent.withOpacity(0.2)),
                  ),
                  child: Column(
                    children: [
                      _buildFeatureRow(
                        Icons.monitor_weight_rounded,
                        'Penimbangan Digital Cepat (4x Load Cell 50kg HX711)',
                        textColor,
                        themeAccent,
                      ),
                      const SizedBox(height: 10),
                      _buildFeatureRow(
                        Icons.camera_alt_rounded,
                        'Zero-Install Computer Vision (Marker Board Panjang/Tinggi)',
                        textColor,
                        themeAccent,
                      ),
                      const SizedBox(height: 10),
                      _buildFeatureRow(
                        Icons.straighten_rounded,
                        'Sensor Lingkar Perut Presisi Magnetik AS5600',
                        textColor,
                        themeAccent,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    CustomButton(
                      text: 'Hubungi Sales MAPOTECH',
                      isSecondary: true,
                      height: 42,
                      textColor: textColor,
                      onPressed: () {
                        CustomSnackbar.info(
                          context,
                          'Informasi pemesanan DLC VitaScale telah dikirimkan ke kontak admin faskes.',
                          title: 'Permintaan DLC',
                        );
                      },
                    ),
                    CustomButton(
                      text: 'Aktifkan Pratinjau (Demo)',
                      isSecondary: false,
                      height: 42,
                      primaryColor: themeAccent,
                      icon: Icons.play_arrow_rounded,
                      onPressed: () {
                        ref.read(vitascaleDlcUnlockedProvider.notifier).state = true;
                        ref.read(landingPageProvider.notifier).addFavoriteMenuItem('dlc_vitascale_data_anak');
                        ref.read(landingPageProvider.notifier).addFavoriteMenuItem('dlc_vitascale_screening');
                        CustomSnackbar.success(
                          context,
                          'Modul DLC VitaScale diaktifkan dalam Mode Pratinjau (Demo).',
                          title: 'Pratinjau Diaktifkan',
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String text, Color textColor, Color accent) {
    return Row(
      children: [
        Icon(icon, size: 16, color: accent),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ),
      ],
    );
  }
}
