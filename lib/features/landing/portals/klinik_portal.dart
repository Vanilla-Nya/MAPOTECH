import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapotech/features/landing/landing_page_data.dart';
import 'package:mapotech/shared/layouts/responsive_layout.dart';
import 'package:mapotech/shared/widgets/three_dimensional_device_wrapper.dart';
import 'package:mapotech/shared/widgets/segera_hadir_mockup.dart';
import 'package:mapotech/shared/widgets/ui.dart';

class KlinikPortal extends ConsumerWidget {
  const KlinikPortal({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(landingPageProvider);
    final notifier = ref.read(landingPageProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeroSection(context, state, notifier),
        const SizedBox(height: 80),
        _buildFeaturesSection(context, state, notifier),
      ],
    );
  }

  // --- HERO SECTION ---
  Widget _buildHeroSection(BuildContext context, LandingPageState state,
      LandingPageNotifier notifier) {
    final isMobile = ResponsiveLayout.isMobile(context);
    final activeColor = notifier.getPrimaryColor();
    final textColor = notifier.getTextColor();
    final bodyTextColor = notifier.getBodyTextColor();
    final cardColor = notifier.getCardColor();
    final borderColor = notifier.getBorderColor();
    final lang = state.language;

    Widget heroText = Column(
      crossAxisAlignment:
          isMobile ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        PortalTaglineBadge(
          icon: Icons.local_hospital_rounded,
          text: notifier.getHeroTagline(),
          activeColor: activeColor,
          cardColor: cardColor,
          textColor: textColor,
        ),
        const SizedBox(height: 24),
        Text(
          notifier.getHeroTitle(),
          textAlign: isMobile ? TextAlign.center : TextAlign.start,
          style: GoogleFonts.outfit(fontSize: isMobile ? 48 : 72, fontWeight: FontWeight.w900, letterSpacing: -2.0, height: 0.9, color: textColor),
        ),
        const SizedBox(height: 16),
        Text(
          notifier.getHeroDescription(),
          textAlign: isMobile ? TextAlign.center : TextAlign.start,
          style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w500, height: 1.5, color: bodyTextColor),
        ),
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: isMobile ? MainAxisAlignment.center : MainAxisAlignment.start,
          children: [
            CustomButton(
              text: notifier.t('learn_more'),
              isSecondary: true,
              primaryColor: Colors.transparent,
              textColor: textColor,
              borderColor: borderColor,
              onPressed: () {},
            ),
          ],
        ),
        const SizedBox(height: 32),
        PortalBadgeChip(
          cardColor: cardColor,
          borderColor: borderColor,
          textColor: textColor,
          icon: Icons.verified_rounded,
          iconColor: activeColor,
          label: lang == 'id' ? 'Terintegrasi SatuSehat & BPJS' : 'SatuSehat & BPJS Integrated',
        ),
      ],
    );

    Widget heroVisual = const SegeraHadirMockup(portalPath: 'KLINIK');

    heroVisual = ThreeDimensionalDeviceWrapper(child: heroVisual);

    if (isMobile) {
      return Column(children: [heroText, const SizedBox(height: 48), heroVisual]);
    }
    return Row(children: [
      Expanded(child: heroText),
      const SizedBox(width: 60),
      Expanded(child: heroVisual),
    ]);
  }

  // --- FEATURES SECTION ---
  Widget _buildFeaturesSection(BuildContext context, LandingPageState state,
      LandingPageNotifier notifier) {
    final isMobile = ResponsiveLayout.isMobile(context);
    final activeColor = notifier.getPrimaryColor();
    final textColor = notifier.getTextColor();
    final bodyTextColor = notifier.getBodyTextColor();
    final cardColor = notifier.getCardColor();
    final borderColor = notifier.getBorderColor();
    final lang = state.language;

    final features = [
      {
        'icon': Icons.folder_shared_rounded,
        'title': lang == 'id' ? 'RME Klinik Mandiri' : 'Independent Clinic EMR',
        'desc': lang == 'id'
            ? 'Sistem rekam medis elektronik mandiri tanpa bergantung pada ekosistem luar.'
            : 'Independent EMR system without external ecosystem dependency.',
        'color': const Color(0xFF4A90E2),
      },
      {
        'icon': Icons.queue_rounded,
        'title': lang == 'id' ? 'Manajemen Antrean' : 'Queue Management',
        'desc': lang == 'id'
            ? 'Display antrean digital dengan notifikasi pasien otomatis dan estimasi waktu tunggu.'
            : 'Digital queue display with automatic patient notifications and wait time estimation.',
        'color': Colors.orange,
      },
      {
        'icon': Icons.point_of_sale_rounded,
        'title': lang == 'id' ? 'Kasir & Billing' : 'POS & Billing',
        'desc': lang == 'id'
            ? 'Kasir terintegrasi dengan struk digital, pencatatan pembayaran BPJS, dan laporan harian.'
            : 'POS integrated with digital receipts, BPJS payment recording, and daily reports.',
        'color': Colors.green,
      },
      {
        'icon': Icons.people_rounded,
        'title': lang == 'id' ? 'Manajemen Staf & Dokter' : 'Staff & Doctor Mgmt',
        'desc': lang == 'id'
            ? 'Atur jadwal praktik, slot dokter, dan hak akses staf klinis secara terpusat.'
            : 'Manage practice schedules, doctor slots, and clinical staff access rights centrally.',
        'color': const Color(0xFFB577F2),
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PortalSectionHeader(
          category: lang == 'id' ? 'FITUR SISTEM KLINIK' : 'CLINIC SYSTEM FEATURES',
          title: lang == 'id' ? 'Solusi Klinik Terpadu' : 'Integrated Clinic Solution',
          description: lang == 'id' ? 'RME, Antrean, Kasir, dan lebih banyak lagi — dalam satu sistem.' : 'EMR, Queue, POS, and more — in one system.',
          activeColor: activeColor,
          textColor: textColor,
          bodyTextColor: bodyTextColor,
          isMobile: isMobile,
        ),
        const SizedBox(height: 48),
        if (isMobile)
          ...features.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: PortalFeatureCard(
                  icon: f['icon'] as IconData,
                  title: f['title'] as String,
                  description: f['desc'] as String,
                  color: f['color'] as Color,
                  cardColor: cardColor,
                  borderColor: borderColor,
                  textColor: textColor,
                  bodyTextColor: bodyTextColor,
                ),
              ))
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: features.map((f) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: PortalFeatureCard(
                  icon: f['icon'] as IconData,
                  title: f['title'] as String,
                  description: f['desc'] as String,
                  color: f['color'] as Color,
                  cardColor: cardColor,
                  borderColor: borderColor,
                  textColor: textColor,
                  bodyTextColor: bodyTextColor,
                ),
              ),
            )).toList(),
          ),
      ],
    );
  }
}
