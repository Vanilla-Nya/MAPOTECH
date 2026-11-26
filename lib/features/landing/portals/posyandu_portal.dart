import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapotech/features/landing/landing_page_data.dart';
import 'package:mapotech/shared/layouts/responsive_layout.dart';
import 'package:mapotech/shared/widgets/three_dimensional_device_wrapper.dart';
import 'package:mapotech/shared/widgets/segera_hadir_mockup.dart';
import 'package:mapotech/shared/widgets/ui.dart';

class PosyanduPortal extends ConsumerWidget {
  const PosyanduPortal({super.key});

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
          icon: Icons.favorite_rounded,
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
        Wrap(
          spacing: 8, runSpacing: 8,
          children: [
            PortalBadgeChip(
              cardColor: cardColor,
              borderColor: borderColor,
              textColor: textColor,
              icon: Icons.child_friendly_rounded,
              iconColor: Colors.pink,
              label: lang == 'id' ? 'Tumbuh Kembang Balita' : 'Toddler Growth',
            ),
            PortalBadgeChip(
              cardColor: cardColor,
              borderColor: borderColor,
              textColor: textColor,
              icon: Icons.vaccines_rounded,
              iconColor: Colors.orange,
              label: lang == 'id' ? 'Imunisasi Digital' : 'Digital Immunization',
            ),
          ],
        ),
      ],
    );

    Widget heroVisual = const SegeraHadirMockup(portalPath: 'POSYANDU');
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
        'icon': Icons.monitor_weight_rounded,
        'title': lang == 'id' ? 'KMS Tumbuh Kembang' : 'Growth KMS Card',
        'desc': lang == 'id' ? 'Kartu menuju sehat digital dengan grafik pertumbuhan berstandar WHO dan riwayat penimbangan.' : 'Digital health chart with WHO-standard growth graph and weighing history.',
        'color': const Color(0xFFEC407A),
      },
      {
        'icon': Icons.vaccines_rounded,
        'title': lang == 'id' ? 'Manajemen Imunisasi' : 'Immunization Mgmt',
        'desc': lang == 'id' ? 'Rekam, jadwalkan, dan ingatkan imunisasi anak otomatis sesuai program nasional Kemenkes.' : 'Record, schedule, and automatically remind child immunization per national Kemenkes program.',
        'color': Colors.orange,
      },
      {
        'icon': Icons.restaurant_rounded,
        'title': lang == 'id' ? 'Edukasi Gizi' : 'Nutrition Education',
        'desc': lang == 'id' ? 'Panduan gizi ibu hamil, menyusui, dan MPASI berbasis standar nasional dengan edukasi interaktif.' : 'Nutrition guidelines for pregnant, nursing, and MPASI based on national standards with interactive education.',
        'color': Colors.green,
      },
      {
        'icon': Icons.people_rounded,
        'title': lang == 'id' ? 'Manajemen Kader' : 'Cadre Management',
        'desc': lang == 'id' ? 'Daftarkan kader posyandu, atur jadwal kegiatan rutin, dan pantau laporan kegiatan bulanan.' : 'Register posyandu cadres, set routine activity schedules, and monitor monthly activity reports.',
        'color': const Color(0xFF3F51B5),
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PortalSectionHeader(
          category: lang == 'id' ? 'FITUR POSYANDU' : 'POSYANDU FEATURES',
          title: lang == 'id' ? 'Tumbuh Kembang Prima' : 'Prime Growth & Development',
          description: lang == 'id' ? 'Sistem pemantauan balita, imunisasi, dan gizi ibu terintegrasi di tingkat posyandu.' : 'Integrated toddler monitoring, immunization, and maternal nutrition system at posyandu level.',
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
