import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapotech/features/landing/landing_page_data.dart';
import 'package:mapotech/shared/layouts/responsive_layout.dart';
import 'package:mapotech/shared/widgets/custom_button.dart';
import 'package:mapotech/shared/widgets/three_dimensional_device_wrapper.dart';
import 'package:mapotech/shared/widgets/segera_hadir_mockup.dart';

class PuskesmasPortal extends ConsumerWidget {
  const PuskesmasPortal({super.key});

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
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: activeColor.withValues(alpha: 0.2)),
            boxShadow: [BoxShadow(color: activeColor.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 2))],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.domain_rounded, color: activeColor, size: 14),
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
            CustomButton(text: notifier.t('learn_more'), isSecondary: true, primaryColor: Colors.transparent, textColor: textColor, borderColor: borderColor, onPressed: () {}),
          ],
        ),
        const SizedBox(height: 32),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildBadgeChip(cardColor, borderColor, textColor, Icons.verified_rounded, activeColor, 'SatuSehat'),
            _buildBadgeChip(cardColor, borderColor, textColor, Icons.account_balance_rounded, Colors.blue, lang == 'id' ? 'BPJS Terintegrasi' : 'BPJS Integrated'),
          ],
        ),
      ],
    );

    Widget heroVisual = const SegeraHadirMockup(portalPath: 'PUSKESMAS');
    heroVisual = ThreeDimensionalDeviceWrapper(child: heroVisual);

    if (isMobile) {
      return Column(children: [heroText, const SizedBox(height: 48), heroVisual]);
    }
    return Row(children: [Expanded(child: heroText), const SizedBox(width: 60), Expanded(child: heroVisual)]);
  }

  Widget _buildBadgeChip(Color cardColor, Color borderColor, Color textColor, IconData icon, Color iconColor, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(100), border: Border.all(color: borderColor)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 6),
          Text(label, style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700, color: textColor)),
        ],
      ),
    );
  }

  Widget _buildPuskesmasMockup(bool isDark, Color borderColor, Color cardColor, Color activeColor, Color textColor, Color bodyTextColor, String lang) {
    final bgColor = isDark ? const Color(0xFF0D1117) : const Color(0xFFF5FEF9);
    final panelColor = isDark ? const Color(0xFF161B22) : Colors.white;
    final subText = isDark ? Colors.grey[400]! : Colors.grey[600]!;
    const accentTeal = Color(0xFF00BFA5);

    return Container(
      height: 480,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: activeColor.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: borderColor),
      ),
      child: Center(
        child: FittedBox(
          fit: BoxFit.contain,
          child: Container(
            width: 620,
            height: 400,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor, width: 1.5),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08), blurRadius: 30, offset: const Offset(0, 15))],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                // Browser bar
                Container(
                  height: 32, color: isDark ? const Color(0xFF161616) : const Color(0xFFE8F8F5),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Row(children: [
                        Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFFFF5F56), shape: BoxShape.circle)),
                        const SizedBox(width: 5),
                        Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFFFFBD2E), shape: BoxShape.circle)),
                        const SizedBox(width: 5),
                        Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF27C93F), shape: BoxShape.circle)),
                      ]),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Container(
                          height: 20, decoration: BoxDecoration(color: isDark ? const Color(0xFF222222) : Colors.white, borderRadius: BorderRadius.circular(100), border: Border.all(color: borderColor.withValues(alpha: 0.5))),
                          alignment: Alignment.center,
                          child: Text('HTTPS://MAPOTECH.DIGITAL/APP/PUSKESMAS', style: GoogleFonts.outfit(fontSize: 7, fontWeight: FontWeight.bold, color: Colors.grey[500], letterSpacing: 0.5)),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Icon(Icons.refresh_rounded, size: 12, color: Colors.grey[500]),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      // Sidebar
                      Container(
                        width: 44, color: isDark ? const Color(0xFF1A2E1A) : const Color(0xFF1B4F42),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Column(
                          children: [
                            Image.asset(
                              'assets/images/logo.png',
                              width: 28,
                              height: 28,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) => Container(
                                width: 28, height: 28,
                                decoration: BoxDecoration(color: accentTeal.withValues(alpha: 0.4), shape: BoxShape.circle),
                                child: const Icon(Icons.domain_rounded, size: 14, color: Colors.white),
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Icon(Icons.bar_chart_rounded, size: 16, color: Colors.white),
                            const SizedBox(height: 16),
                            const Icon(Icons.queue_rounded, size: 16, color: Colors.white54),
                            const SizedBox(height: 16),
                            const Icon(Icons.people_rounded, size: 16, color: Colors.white54),
                            const SizedBox(height: 16),
                            const Icon(Icons.sync_rounded, size: 16, color: Colors.white54),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Container(
                          color: bgColor, padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(child: Text(lang == 'id' ? 'Analitik Kesehatan' : 'Health Analytics', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w900, color: textColor))),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(color: accentTeal.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(100)),
                                    child: Text(lang == 'id' ? 'REAL-TIME' : 'REAL-TIME', style: GoogleFonts.outfit(fontSize: 7, fontWeight: FontWeight.w900, color: accentTeal)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  _buildStatBox(panelColor, borderColor, textColor, subText, accentTeal, '214', lang == 'id' ? 'Kunjungan' : 'Visits'),
                                  const SizedBox(width: 8),
                                  _buildStatBox(panelColor, borderColor, textColor, subText, Colors.orange, '18', lang == 'id' ? 'Antrean' : 'Queue'),
                                  const SizedBox(width: 8),
                                  _buildStatBox(panelColor, borderColor, textColor, subText, Colors.blue, '3', lang == 'id' ? 'Rujukan' : 'Referral'),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Expanded(
                                child: Row(
                                  children: [
                                    // Health trend chart
                                    Expanded(
                                      flex: 5,
                                      child: Container(
                                        decoration: BoxDecoration(color: panelColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
                                        padding: const EdgeInsets.all(10),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(lang == 'id' ? 'TREN KUNJUNGAN' : 'VISIT TRENDS', style: GoogleFonts.outfit(fontSize: 7, fontWeight: FontWeight.w900, color: textColor, letterSpacing: 0.5)),
                                            const SizedBox(height: 8),
                                            Expanded(child: _buildSimpleBarChart(accentTeal, borderColor)),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // SatuSehat sync + referral
                                    Expanded(
                                      flex: 3,
                                      child: Column(
                                        children: [
                                          Expanded(
                                            child: Container(
                                              decoration: BoxDecoration(color: panelColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
                                              padding: const EdgeInsets.all(10),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  const Icon(Icons.verified_rounded, size: 12, color: accentTeal),
                                                  const SizedBox(height: 4),
                                                  Text('SatuSehat', style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w900, color: textColor)),
                                                  Text(lang == 'id' ? 'Data tersinkron' : 'Data synced', style: GoogleFonts.outfit(fontSize: 6, color: subText)),
                                                  const SizedBox(height: 4),
                                                  LinearProgressIndicator(value: 0.9, color: accentTeal, backgroundColor: accentTeal.withValues(alpha: 0.15), minHeight: 4, borderRadius: BorderRadius.circular(2)),
                                                ],
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Expanded(
                                            child: Container(
                                              decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blue.withValues(alpha: 0.2))),
                                              padding: const EdgeInsets.all(10),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  const Icon(Icons.arrow_forward_rounded, size: 12, color: Colors.blue),
                                                  const SizedBox(height: 4),
                                                  Text(lang == 'id' ? 'Rujukan' : 'Referral', style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w900, color: textColor)),
                                                  Text('RSUD - 2', style: GoogleFonts.outfit(fontSize: 6, color: Colors.blue)),
                                                  Text('RS PKU - 1', style: GoogleFonts.outfit(fontSize: 6, color: Colors.blue)),
                                                ],
                                              ),
                                            ),
                                          ),
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatBox(Color panelColor, Color borderColor, Color textColor, Color subText, Color accent, String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: panelColor, borderRadius: BorderRadius.circular(10), border: Border.all(color: borderColor)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900, color: accent, height: 1.0)),
          Text(label, style: GoogleFonts.outfit(fontSize: 6, color: subText)),
        ]),
      ),
    );
  }

  Widget _buildSimpleBarChart(Color accent, Color borderColor) {
    final values = [0.4, 0.6, 0.8, 0.55, 0.9, 0.7, 0.85];
    final days = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (i) {
        return Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: FractionallySizedBox(
                  heightFactor: values[i],
                  child: Container(
                    width: 14,
                    decoration: BoxDecoration(
                      color: i == 4 ? accent : accent.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(days[i], style: GoogleFonts.outfit(fontSize: 6, color: Colors.grey[500])),
          ],
        );
      }),
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
        'icon': Icons.bar_chart_rounded,
        'title': lang == 'id' ? 'Analitik Kesehatan Masyarakat' : 'Public Health Analytics',
        'desc': lang == 'id' ? 'Pantau tren penyakit, kunjungan, dan indikator kesehatan wilayah secara real-time.' : 'Monitor disease trends, visits, and regional health indicators in real-time.',
        'color': const Color(0xFF00BFA5),
      },
      {
        'icon': Icons.queue_rounded,
        'title': lang == 'id' ? 'Antrean & Faskes Rujukan' : 'Queue & Referral',
        'desc': lang == 'id' ? 'Sistem antrean digital terintegrasi dengan manajemen rujukan ke faskes yang lebih tinggi.' : 'Digital queue system integrated with referral management to higher health facilities.',
        'color': Colors.orange,
      },
      {
        'icon': Icons.sync_rounded,
        'title': lang == 'id' ? 'Jembatan SatuSehat' : 'SatuSehat Bridge',
        'desc': lang == 'id' ? 'Sinkronisasi data kesehatan masyarakat ke platform SatuSehat Kemenkes secara seamless.' : 'Synchronize community health data to SatuSehat Kemenkes platform seamlessly.',
        'color': Colors.blue,
      },
      {
        'icon': Icons.account_balance_rounded,
        'title': lang == 'id' ? 'Klaim BPJS' : 'BPJS Claims',
        'desc': lang == 'id' ? 'Proses klaim BPJS Kesehatan dengan validasi otomatis dan laporan yang mudah diekspor.' : 'Process BPJS Health claims with automatic validation and easily exportable reports.',
        'color': const Color(0xFFB577F2),
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Column(
            children: [
              Text(lang == 'id' ? 'FITUR PUSKESMAS' : 'HEALTH CENTER FEATURES',
                style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 2, color: activeColor)),
              const SizedBox(height: 8),
              Text(lang == 'id' ? 'Pelayanan Kesehatan Masyarakat' : 'Community Healthcare',
                textAlign: TextAlign.center, style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.w900, color: textColor)),
              const SizedBox(height: 8),
              Text(lang == 'id' ? 'Solusi digital terintegrasi untuk pusat kesehatan masyarakat.' : 'Integrated digital solution for community health centers.',
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
