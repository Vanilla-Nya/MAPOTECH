import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapotech/features/landing/landing_page_data.dart';
import 'package:mapotech/shared/layouts/responsive_layout.dart';
import 'package:mapotech/shared/widgets/three_dimensional_device_wrapper.dart';
import 'package:mapotech/shared/widgets/segera_hadir_mockup.dart';
import 'package:mapotech/shared/widgets/ui.dart';

class RumahSakitPortal extends ConsumerWidget {
  const RumahSakitPortal({super.key});

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
      crossAxisAlignment: isMobile ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        PortalTaglineBadge(
          icon: Icons.corporate_fare_rounded,
          text: notifier.getHeroTagline(),
          activeColor: activeColor,
          cardColor: cardColor,
          textColor: textColor,
        ),
        const SizedBox(height: 24),
        Text(notifier.getHeroTitle(), textAlign: isMobile ? TextAlign.center : TextAlign.start,
          style: GoogleFonts.outfit(fontSize: isMobile ? 48 : 72, fontWeight: FontWeight.w900, letterSpacing: -2.0, height: 0.9, color: textColor)),
        const SizedBox(height: 16),
        Text(notifier.getHeroDescription(), textAlign: isMobile ? TextAlign.center : TextAlign.start,
          style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w500, height: 1.5, color: bodyTextColor)),
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: isMobile ? MainAxisAlignment.center : MainAxisAlignment.start,
          children: [
            CustomButton(text: notifier.t('learn_more'), isSecondary: true, primaryColor: Colors.transparent, textColor: textColor, borderColor: borderColor, onPressed: () {}),
          ],
        ),
        const SizedBox(height: 32),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: [
            PortalBadgeChip(
              cardColor: cardColor,
              borderColor: borderColor,
              textColor: textColor,
              icon: Icons.verified_rounded,
              iconColor: activeColor,
              label: 'SatuSehat',
            ),
            PortalBadgeChip(
              cardColor: cardColor,
              borderColor: borderColor,
              textColor: textColor,
              icon: Icons.security_rounded,
              iconColor: Colors.indigo,
              label: lang == 'id' ? 'Enterprise Grade' : 'Enterprise Grade',
            ),
            PortalBadgeChip(
              cardColor: cardColor,
              borderColor: borderColor,
              textColor: textColor,
              icon: Icons.account_balance_rounded,
              iconColor: Colors.blue,
              label: 'BPJS',
            ),
          ],
        ),
      ],
    );

    Widget heroVisual = const SegeraHadirMockup(portalPath: 'RUMAHSAKIT');
    heroVisual = ThreeDimensionalDeviceWrapper(child: heroVisual);

    if (isMobile) {
      return Column(children: [heroText, const SizedBox(height: 48), heroVisual]);
    }
    return Row(children: [Expanded(child: heroText), const SizedBox(width: 60), Expanded(child: heroVisual)]);
  }

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
        'icon': Icons.bed_rounded,
        'title': lang == 'id' ? 'Manajemen Bangsal & Rawat Inap' : 'Ward & Inpatient Mgmt',
        'desc': lang == 'id' ? 'Kelola kapasitas bangsal, transfer pasien, dan monitoring real-time tempat tidur seluruh RS.' : 'Manage ward capacity, patient transfers, and real-time bed monitoring across the hospital.',
        'color': const Color(0xFF3F51B5),
      },
      {
        'icon': Icons.directions_run_rounded,
        'title': lang == 'id' ? 'Rawat Jalan & Poliklinik' : 'Outpatient & Polyclinic',
        'desc': lang == 'id' ? 'Sistem antrean poli, rekam medis pasien rawat jalan, dan manajemen dokter tamu.' : 'Polyclinic queue system, outpatient EMR, and visiting doctor management.',
        'color': Colors.teal,
      },
      {
        'icon': Icons.science_rounded,
        'title': lang == 'id' ? 'Laboratorium & Farmasi' : 'Laboratory & Pharmacy',
        'desc': lang == 'id' ? 'Manajemen sampel lab, distribusi hasil digital, dan stok farmasi terintegrasi.' : 'Lab sample management, digital result distribution, and integrated pharmacy stock.',
        'color': Colors.green,
      },
      {
        'icon': Icons.receipt_long_rounded,
        'title': lang == 'id' ? 'Billing & Klaim BPJS' : 'Billing & BPJS Claims',
        'desc': lang == 'id' ? 'Sistem billing terpusat dengan validasi klaim BPJS otomatis dan laporan keuangan RS.' : 'Centralized billing with automatic BPJS claim validation and hospital financial reports.',
        'color': Colors.orange,
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PortalSectionHeader(
          category: lang == 'id' ? 'SISTEM ERP RUMAH SAKIT' : 'HOSPITAL ERP SYSTEM',
          title: lang == 'id' ? 'Kelas Enterprise untuk RS' : 'Enterprise-Grade for Hospitals',
          description: lang == 'id' ? 'Menghubungkan setiap departemen dalam satu platform terintegrasi.' : 'Connecting every department in one integrated platform.',
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
