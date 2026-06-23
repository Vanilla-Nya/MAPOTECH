import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapotech/features/landing/landing_page_data.dart';
import 'package:mapotech/shared/layouts/responsive_layout.dart';
import 'package:mapotech/shared/widgets/custom_button.dart';
import 'package:mapotech/shared/widgets/three_dimensional_device_wrapper.dart';
import 'package:mapotech/shared/widgets/segera_hadir_mockup.dart';

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
              Icon(Icons.favorite_rounded, color: activeColor, size: 14),
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
        Wrap(
          spacing: 8, runSpacing: 8,
          children: [
            _buildBadge(cardColor, borderColor, textColor, Icons.child_friendly_rounded, Colors.pink, lang == 'id' ? 'Tumbuh Kembang Balita' : 'Toddler Growth'),
            _buildBadge(cardColor, borderColor, textColor, Icons.vaccines_rounded, Colors.orange, lang == 'id' ? 'Imunisasi Digital' : 'Digital Immunization'),
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

  Widget _buildBadge(Color cardColor, Color borderColor, Color textColor, IconData icon, Color iconColor, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(100), border: Border.all(color: borderColor)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(icon, size: 13, color: iconColor), const SizedBox(width: 6), Text(label, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700, color: textColor))],
      ),
    );
  }

  Widget _buildPosyanduMockup(bool isDark, Color borderColor, Color cardColor, Color activeColor, Color textColor, Color bodyTextColor, String lang) {
    final phoneContentBg = isDark ? const Color(0xFF161616) : const Color(0xFFFFF5F9);
    const accentPink = Color(0xFFEC407A);
    const accentOrange = Color(0xFFFFA726);

    return Container(
      height: 480,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accentPink.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: borderColor),
      ),
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Mobile mockup
            Container(
              width: 190,
              height: 380,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1C1C1E) : Colors.black,
                borderRadius: BorderRadius.circular(34),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.2), blurRadius: 30, offset: const Offset(0, 15))],
              ),
              padding: const EdgeInsets.all(8),
              child: Container(
                decoration: BoxDecoration(color: phoneContentBg, borderRadius: BorderRadius.circular(28)),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    // Status bar
                    Container(
                      height: 24, padding: const EdgeInsets.symmetric(horizontal: 14),
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
                            // Header
                            Row(
                              children: [
                                Container(width: 22, height: 22, decoration: const BoxDecoration(shape: BoxShape.circle, color: accentPink), child: const Icon(Icons.favorite_rounded, size: 11, color: Colors.white)),
                                const SizedBox(width: 6),
                                Text('POSYANDU', style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w900, color: textColor)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Child card
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: accentPink.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
                              child: Row(
                                children: [
                                  Container(width: 28, height: 28, decoration: const BoxDecoration(color: accentPink, shape: BoxShape.circle), alignment: Alignment.center, child: Text('🧒', style: const TextStyle(fontSize: 14))),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Bintang (2 Th)', style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w900, color: textColor)),
                                        Text(lang == 'id' ? 'Status: Normal' : 'Status: Normal', style: GoogleFonts.outfit(fontSize: 6, color: Colors.green, fontWeight: FontWeight.w800)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Growth chart mini
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: isDark ? const Color(0xFF222222) : Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: isDark ? const Color(0xFF333333) : Colors.grey[200]!)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(lang == 'id' ? 'BERAT BADAN' : 'WEIGHT', style: GoogleFonts.outfit(fontSize: 6, fontWeight: FontWeight.w900, color: textColor, letterSpacing: 0.5)),
                                  const SizedBox(height: 4),
                                  SizedBox(
                                    height: 40,
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [9.2, 9.8, 10.1, 10.5, 11.0, 11.3].asMap().entries.map((e) {
                                        final frac = (e.value - 9.0) / 3.0;
                                        return Expanded(child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 1),
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.end,
                                            children: [
                                              Expanded(child: Align(
                                                alignment: Alignment.bottomCenter,
                                                child: FractionallySizedBox(
                                                  heightFactor: frac.clamp(0.2, 1.0),
                                                  child: Container(decoration: BoxDecoration(color: e.key == 5 ? accentPink : accentPink.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(2))),
                                                ),
                                              )),
                                            ],
                                          ),
                                        ));
                                      }).toList(),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text('11.3 kg', style: GoogleFonts.outfit(fontSize: 8, fontWeight: FontWeight.w900, color: accentPink)),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Immunization row
                            Text(lang == 'id' ? 'IMUNISASI' : 'IMMUNIZATION', style: GoogleFonts.outfit(fontSize: 6, fontWeight: FontWeight.w900, color: textColor, letterSpacing: 0.5)),
                            const SizedBox(height: 5),
                            Row(
                              children: [
                                _buildVaccineChip('BCG', Colors.green, true),
                                const SizedBox(width: 4),
                                _buildVaccineChip('DPT', Colors.green, true),
                                const SizedBox(width: 4),
                                _buildVaccineChip('Polio', accentOrange, false),
                                const SizedBox(width: 4),
                                _buildVaccineChip('MR', Colors.grey, false),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Next schedule
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: accentOrange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_month_rounded, size: 12, color: accentOrange),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(lang == 'id' ? 'Jadwal Berikutnya' : 'Next Schedule', style: GoogleFonts.outfit(fontSize: 6, color: accentOrange, fontWeight: FontWeight.w900)),
                                        Text(lang == 'id' ? 'Polio - 1 Jun 2026' : 'Polio - Jun 1, 2026', style: GoogleFonts.outfit(fontSize: 7, fontWeight: FontWeight.bold, color: textColor)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 24),
            // Feature info panel
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow(cardColor, borderColor, textColor, bodyTextColor, accentPink, Icons.monitor_weight_rounded, lang == 'id' ? 'KMS Digital' : 'Digital Growth Card', lang == 'id' ? 'Grafik KMS tumbuh kembang balita berbasis standar WHO.' : 'WHO-standard toddler growth KMS chart digitally.'),
                  const SizedBox(height: 12),
                  _buildInfoRow(cardColor, borderColor, textColor, bodyTextColor, accentOrange, Icons.vaccines_rounded, lang == 'id' ? 'Jadwal Imunisasi' : 'Immunization Schedule', lang == 'id' ? 'Rekam imunisasi lengkap dengan pengingat jadwal otomatis.' : 'Full immunization records with automatic schedule reminders.'),
                  const SizedBox(height: 12),
                  _buildInfoRow(cardColor, borderColor, textColor, bodyTextColor, Colors.green, Icons.restaurant_rounded, lang == 'id' ? 'Edukasi Gizi Ibu' : 'Maternal Nutrition', lang == 'id' ? 'Panduan gizi ibu hamil dan menyusui berbasis wilayah.' : 'Regional-based nutrition guidelines for pregnant and nursing mothers.'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVaccineChip(String label, Color color, bool isDone) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: isDone ? 0.5 : 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isDone) Icon(Icons.check_rounded, size: 6, color: color),
          Text(label, style: GoogleFonts.outfit(fontSize: 6, fontWeight: FontWeight.w900, color: color)),
        ],
      ),
    );
  }

  Widget _buildInfoRow(Color cardColor, Color borderColor, Color textColor, Color bodyTextColor, Color color, IconData icon, String title, String desc) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: borderColor)),
      child: Row(
        children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 18)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w800, color: textColor)),
                const SizedBox(height: 2),
                Text(desc, style: GoogleFonts.outfit(fontSize: 11, color: bodyTextColor, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
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
        Center(
          child: Column(
            children: [
              Text(lang == 'id' ? 'FITUR POSYANDU' : 'POSYANDU FEATURES',
                style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 2, color: activeColor)),
              const SizedBox(height: 8),
              Text(lang == 'id' ? 'Tumbuh Kembang Prima' : 'Prime Growth & Development',
                textAlign: TextAlign.center, style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.w900, color: textColor)),
              const SizedBox(height: 8),
              Text(lang == 'id' ? 'Sistem pemantauan balita, imunisasi, dan gizi ibu terintegrasi di tingkat posyandu.' : 'Integrated toddler monitoring, immunization, and maternal nutrition system at posyandu level.',
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
