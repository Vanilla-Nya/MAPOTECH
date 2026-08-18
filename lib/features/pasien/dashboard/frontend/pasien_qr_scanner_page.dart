import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapotech/features/landing/landing_page_data.dart';
import 'package:mapotech/features/pasien/dashboard/frontend/widgets/pasien_qr_scanner_dialog.dart';
import 'package:mapotech/features/pasien/dashboard/frontend/widgets/pasien_apotek_pos_dialog.dart';
import 'package:mapotech/features/pasien/dashboard/frontend/pasien_dokter_search.dart';

/// Full-page dedicated QR Scanner view for Pasien role
class PasienQrScannerPage extends ConsumerStatefulWidget {
  final Function(String menu)? onNavigate;
  const PasienQrScannerPage({super.key, this.onNavigate});

  @override
  ConsumerState<PasienQrScannerPage> createState() => _PasienQrScannerPageState();
}

class _PasienQrScannerPageState extends ConsumerState<PasienQrScannerPage> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(landingPageProvider);
    final notifier = ref.read(landingPageProvider.notifier);
    final isDark = state.appearance == 'dark';

    final cardBgColor = notifier.getCardColor();
    final textColor = notifier.getTextColor();
    final subtitleColor = notifier.getBodyTextColor();
    final borderColor = notifier.getBorderColor();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top Banner
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: cardBgColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF0F9D58),
                      Color(0xFF00875A),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.qr_code_scanner_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pemindai QR Dokter & Apotek',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Pindai QR Code untuk registrasi / booking dokter instan atau terhubung ke POS Apotek',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: subtitleColor,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.arrow_back_rounded, color: subtitleColor),
                tooltip: 'Kembali ke Dashboard',
                onPressed: () {
                  widget.onNavigate?.call('dashboard');
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Embedded Scanner Container
        Container(
          decoration: BoxDecoration(
            color: cardBgColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: PasienQrScannerDialog(
            onDoctorScanned: (doctor) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Dokter terdeteksi: ${doctor["name"] ?? "Dokter"}. Membuka pendaftaran...',
                    style: GoogleFonts.outfit(),
                  ),
                  backgroundColor: const Color(0xFF0F9D58),
                  duration: const Duration(seconds: 2),
                ),
              );
              showDialog(
                context: context,
                barrierColor: Colors.black.withOpacity(0.45),
                builder: (dCtx) => DoctorDetailDialog(
                  dokter: doctor,
                  isDark: isDark,
                  initialTabIndex: 1,
                ),
              );
            },
            onApotekScanned: (apotek) {
              showDialog(
                context: context,
                barrierColor: Colors.black.withOpacity(0.55),
                builder: (dCtx) => PasienApotekPosDialog(
                  pharmacy: apotek,
                  isDark: isDark,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
