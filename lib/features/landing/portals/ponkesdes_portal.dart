import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapotech/features/landing/landing_page_data.dart';
import 'package:mapotech/shared/layouts/responsive_layout.dart';
import 'package:mapotech/shared/widgets/custom_button.dart';
import 'package:mapotech/shared/widgets/three_dimensional_device_wrapper.dart';
import 'package:mapotech/shared/widgets/segera_hadir_mockup.dart';

class PonkesdesPortal extends ConsumerWidget {
  const PonkesdesPortal({super.key});

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
    final darkGreenColor = notifier.getSecondaryColor();
    final textColor = notifier.getTextColor();
    final bodyTextColor = notifier.getBodyTextColor();
    final cardColor = notifier.getCardColor();
    final borderColor = notifier.getBorderColor();
    final isDark = state.appearance == 'dark';
    final lang = state.language;

    Widget heroText = Column(
      crossAxisAlignment: isMobile ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(100), border: Border.all(color: activeColor.withValues(alpha: 0.2)), boxShadow: [BoxShadow(color: activeColor.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 2))]),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.home_work_rounded, color: activeColor, size: 14),
              const SizedBox(width: 8),
              Text(notifier.getHeroTagline(), style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: textColor.withValues(alpha: 0.7))),
            ],
          ),
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
        Row(
          mainAxisAlignment: isMobile ? MainAxisAlignment.center : MainAxisAlignment.start,
          children: [
            Icon(Icons.home_work_rounded, size: 14, color: bodyTextColor),
            const SizedBox(width: 8),
            Flexible(child: Text(
              lang == 'id' ? 'Melayani hingga ke tingkat desa & kelurahan' : 'Serving down to village & kelurahan level',
              style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: bodyTextColor),
            )),
          ],
        ),
      ],
    );

    Widget heroVisual = const SegeraHadirMockup(portalPath: 'PONKESDES');
    heroVisual = ThreeDimensionalDeviceWrapper(child: heroVisual);

    if (isMobile) {
      return Column(children: [heroText, const SizedBox(height: 48), heroVisual]);
    }
    return Row(children: [Expanded(child: heroText), const SizedBox(width: 60), Expanded(child: heroVisual)]);
  }

  Widget _buildPonkesdesMockup(bool isDark, Color borderColor, Color cardColor, Color activeColor, Color textColor, Color bodyTextColor, String lang) {
    // Mobile app mockup for village health worker
    final isDarkMode = isDark;
    const accentGreen = Color(0xFF4CAF50);

    return Container(
      height: 480,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: activeColor.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: borderColor),
      ),
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Phone mockup - petugas bidan view
            _buildPhoneMockup(isDarkMode, borderColor, activeColor, textColor, lang, true),
            const SizedBox(width: 24),
            // Info panel
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoPanel(isDarkMode, borderColor, cardColor, textColor, bodyTextColor, accentGreen, lang),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhoneMockup(bool isDark, Color borderColor, Color activeColor, Color textColor, String lang, bool isBidan) {
    final phoneContentBg = isDark ? const Color(0xFF161616) : const Color(0xFFFDFDFC);
    const accentGreen = Color(0xFF4CAF50);

    return Container(
      width: 180,
      height: 340,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.black,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.2), blurRadius: 30, offset: const Offset(0, 15))],
      ),
      padding: const EdgeInsets.all(8),
      child: Container(
        decoration: BoxDecoration(color: phoneContentBg, borderRadius: BorderRadius.circular(26)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            // Status bar
            Container(
              height: 24,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('9:41', style: GoogleFonts.outfit(fontSize: 8, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                  Row(children: [
                    Icon(Icons.signal_cellular_4_bar_rounded, size: 8, color: isDark ? Colors.white : Colors.black),
                    const SizedBox(width: 3),
                    Icon(Icons.battery_5_bar_rounded, size: 8, color: isDark ? Colors.white : Colors.black),
                  ]),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(width: 22, height: 22, decoration: BoxDecoration(shape: BoxShape.circle, color: accentGreen), child: const Icon(Icons.home_work_rounded, size: 11, color: Colors.white)),
                        const SizedBox(width: 6),
                        Text('PONKESDES', style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w900, color: textColor)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Greeting
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: accentGreen.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(lang == 'id' ? 'Selamat Pagi' : 'Good Morning', style: GoogleFonts.outfit(fontSize: 6, color: accentGreen, fontWeight: FontWeight.w800)),
                          Text('Bd. Sari Dewi', style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w900, color: textColor)),
                          Text(lang == 'id' ? 'Bidan Desa - RT 01-05' : 'Village Midwife - RT 01-05', style: GoogleFonts.outfit(fontSize: 5.5, color: Colors.grey[500])),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Quick actions
                    Row(
                      children: [
                        _buildQuickAction(accentGreen, Icons.home_rounded, lang == 'id' ? 'Kunjungan' : 'Visit', textColor, isDark),
                        const SizedBox(width: 6),
                        _buildQuickAction(Colors.orange, Icons.assignment_rounded, lang == 'id' ? 'Catatan' : 'Record', textColor, isDark),
                        const SizedBox(width: 6),
                        _buildQuickAction(Colors.blue, Icons.sync_rounded, lang == 'id' ? 'Sinkron' : 'Sync', textColor, isDark),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(lang == 'id' ? 'KUNJUNGAN RUMAH' : 'HOME VISITS', style: GoogleFonts.outfit(fontSize: 6, fontWeight: FontWeight.w900, color: textColor, letterSpacing: 0.5)),
                    const SizedBox(height: 6),
                    ..._buildVisitItems(isDark, accentGreen, textColor, lang),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAction(Color color, IconData icon, String label, Color textColor, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(height: 2),
            Text(label, style: GoogleFonts.outfit(fontSize: 5.5, fontWeight: FontWeight.bold, color: textColor)),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildVisitItems(bool isDark, Color accentColor, Color textColor, String lang) {
    final items = [
      {'name': 'Bu Ratna (68)', 'status': lang == 'id' ? 'Selesai' : 'Done', 'color': Colors.green},
      {'name': 'Pak Heru (72)', 'status': lang == 'id' ? 'Aktif' : 'Active', 'color': Colors.orange},
    ];
    return items.map((item) => Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF222222) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isDark ? const Color(0xFF333333) : Colors.grey[200]!),
        ),
        child: Row(
          children: [
            Container(width: 5, height: 5, decoration: BoxDecoration(color: item['color'] as Color, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Expanded(child: Text(item['name'] as String, style: GoogleFonts.outfit(fontSize: 7, fontWeight: FontWeight.bold, color: textColor))),
            Text(item['status'] as String, style: GoogleFonts.outfit(fontSize: 6, color: item['color'] as Color, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    )).toList();
  }

  Widget _buildInfoPanel(bool isDark, Color borderColor, Color cardColor, Color textColor, Color bodyTextColor, Color accentColor, String lang) {
    final items = [
      {'icon': Icons.home_rounded, 'title': lang == 'id' ? 'Kunjungan Rumah Digital' : 'Digital Home Visits', 'desc': lang == 'id' ? 'Catat hasil kunjungan rumah langsung dari lapangan.' : 'Record home visit results directly from the field.'},
      {'icon': Icons.pregnant_woman_rounded, 'title': lang == 'id' ? 'Bidan Desa Terintegrasi' : 'Integrated Village Midwife', 'desc': lang == 'id' ? 'Pantau ibu hamil dan balita di wilayah binaan.' : 'Monitor pregnant women and toddlers in assigned areas.'},
      {'icon': Icons.sync_rounded, 'title': lang == 'id' ? 'Sinkron Offline-Online' : 'Offline-Online Sync', 'desc': lang == 'id' ? 'Bekerja tanpa internet, data tersinkron saat online.' : 'Work without internet, data syncs when online.'},
    ];
    return Column(
      children: items.map((item) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: borderColor)),
          child: Row(
            children: [
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: accentColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)), child: Icon(item['icon'] as IconData, color: accentColor, size: 18)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item['title'] as String, style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w800, color: textColor)),
                    const SizedBox(height: 2),
                    Text(item['desc'] as String, style: GoogleFonts.outfit(fontSize: 11, color: bodyTextColor, height: 1.4)),
                  ],
                ),
              ),
            ],
          ),
        ),
      )).toList(),
    );
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
        'icon': Icons.home_rounded,
        'title': lang == 'id' ? 'Kunjungan Rumah' : 'Home Visits',
        'desc': lang == 'id' ? 'Sistem pencatatan kunjungan rumah digital dengan lokasi GPS dan tanda tangan digital keluarga.' : 'Digital home visit recording system with GPS location and family digital signature.',
        'color': const Color(0xFF4CAF50),
      },
      {
        'icon': Icons.pregnant_woman_rounded,
        'title': lang == 'id' ? 'Pemantauan Ibu Hamil' : 'Maternal Monitoring',
        'desc': lang == 'id' ? 'Pantau kehamilan, jadwal ANC, dan kondisi kesehatan ibu hamil secara terdigital.' : 'Monitor pregnancy, ANC schedule, and maternal health conditions digitally.',
        'color': Colors.pink,
      },
      {
        'icon': Icons.wifi_off_rounded,
        'title': lang == 'id' ? 'Mode Offline' : 'Offline Mode',
        'desc': lang == 'id' ? 'Bekerja di daerah tanpa sinyal. Data tersinkron otomatis saat terkoneksi internet.' : 'Work in areas without signal. Data auto-syncs when connected to internet.',
        'color': Colors.orange,
      },
      {
        'icon': Icons.map_rounded,
        'title': lang == 'id' ? 'Peta Wilayah Binaan' : 'Coverage Area Map',
        'desc': lang == 'id' ? 'Visualisasi wilayah binaan dengan status kesehatan masyarakat per RT/RW secara georeferenced.' : 'Visualize coverage areas with community health status per RT/RW georeferenced.',
        'color': const Color(0xFF3F51B5),
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Column(
            children: [
              Text(lang == 'id' ? 'FITUR PONKESDES' : 'VILLAGE HEALTH FEATURES',
                style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 2, color: activeColor)),
              const SizedBox(height: 8),
              Text(lang == 'id' ? 'Kesehatan Sampai ke Desa' : 'Health Down to the Village',
                textAlign: TextAlign.center, style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.w900, color: textColor)),
              const SizedBox(height: 8),
              Text(lang == 'id' ? 'Digitalisasi layanan kesehatan tingkat desa, kelurahan, dan RT/RW.' : 'Digitizing health services at village, kelurahan, and RT/RW level.',
                textAlign: TextAlign.center, style: GoogleFonts.outfit(fontSize: 14, color: bodyTextColor, height: 1.5)),
            ],
          ),
        ),
        const SizedBox(height: 48),
        if (isMobile)
          ...features.map((f) => Padding(padding: const EdgeInsets.only(bottom: 16), child: _buildFeatureCard(f, cardColor, borderColor, textColor, bodyTextColor)))
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: features.map((f) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: _buildFeatureCard(f, cardColor, borderColor, textColor, bodyTextColor)))).toList(),
          ),
      ],
    );
  }

  Widget _buildFeatureCard(Map<String, dynamic> feature, Color cardColor, Color borderColor, Color textColor, Color bodyTextColor) {
    final color = feature['color'] as Color;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(20), border: Border.all(color: borderColor)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)), child: Icon(feature['icon'] as IconData, color: color, size: 22)),
          const SizedBox(height: 16),
          Text(feature['title'] as String, style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w800, color: textColor)),
          const SizedBox(height: 8),
          Text(feature['desc'] as String, style: GoogleFonts.outfit(fontSize: 13, color: bodyTextColor, height: 1.5)),
        ],
      ),
    );
  }
}
