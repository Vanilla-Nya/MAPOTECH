import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapotech/features/landing/landing_page_data.dart';
import 'package:mapotech/shared/layouts/responsive_layout.dart';
import 'package:mapotech/shared/widgets/custom_button.dart';
import 'package:mapotech/shared/widgets/three_dimensional_device_wrapper.dart';
import 'package:mapotech/shared/widgets/segera_hadir_mockup.dart';

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
    final darkGreenColor = notifier.getSecondaryColor();
    final textColor = notifier.getTextColor();
    final bodyTextColor = notifier.getBodyTextColor();
    final cardColor = notifier.getCardColor();
    final borderColor = notifier.getBorderColor();
    final isDark = state.appearance == 'dark';
    final lang = state.language;

    Widget heroText = Column(
      crossAxisAlignment:
          isMobile ? CrossAxisAlignment.center : CrossAxisAlignment.start,
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
              Icon(Icons.local_hospital_rounded, color: activeColor, size: 14),
              const SizedBox(width: 8),
              Text(
                notifier.getHeroTagline(),
                style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: textColor.withValues(alpha: 0.7)),
              ),
            ],
          ),
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
        // Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.verified_rounded, color: activeColor, size: 16),
              const SizedBox(width: 8),
              Text(
                lang == 'id' ? 'Terintegrasi SatuSehat & BPJS' : 'SatuSehat & BPJS Integrated',
                style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700, color: textColor),
              ),
            ],
          ),
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

  Widget _buildClinicDashboardMockup(
    BuildContext context, bool isDark, Color borderColor, Color cardColor,
    Color activeColor, Color textColor, Color bodyTextColor, String lang,
  ) {
    final bgColor = isDark ? const Color(0xFF0D1117) : const Color(0xFFF5F9FF);
    final panelColor = isDark ? const Color(0xFF161B22) : Colors.white;
    final subText = isDark ? Colors.grey[400]! : Colors.grey[600]!;
    const accentBlue = Color(0xFF4A90E2);

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
                  height: 32,
                  color: isDark ? const Color(0xFF161616) : const Color(0xFFEEF3FF),
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
                          height: 20,
                          decoration: BoxDecoration(color: isDark ? const Color(0xFF222222) : Colors.white, borderRadius: BorderRadius.circular(100), border: Border.all(color: borderColor.withValues(alpha: 0.5))),
                          alignment: Alignment.center,
                          child: Text('HTTPS://MAPOTECH.DIGITAL/APP/KLINIK', style: GoogleFonts.outfit(fontSize: 7, fontWeight: FontWeight.bold, color: Colors.grey[500], letterSpacing: 0.5)),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Icon(Icons.refresh_rounded, size: 12, color: Colors.grey[500]),
                    ],
                  ),
                ),
                // Body
                Expanded(
                  child: Row(
                    children: [
                      // Dark sidebar
                      Container(
                        width: 44,
                        color: isDark ? const Color(0xFF1A1A2E) : accentBlue,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Column(
                          children: [
                            Container(width: 28, height: 28, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle), child: const Icon(Icons.local_hospital_rounded, size: 14, color: Colors.white)),
                            const SizedBox(height: 20),
                            const Icon(Icons.dashboard_rounded, size: 16, color: Colors.white),
                            const SizedBox(height: 16),
                            const Icon(Icons.queue_rounded, size: 16, color: Colors.white54),
                            const SizedBox(height: 16),
                            const Icon(Icons.folder_shared_rounded, size: 16, color: Colors.white54),
                            const SizedBox(height: 16),
                            const Icon(Icons.receipt_long_rounded, size: 16, color: Colors.white54),
                            const SizedBox(height: 16),
                            const Icon(Icons.settings_rounded, size: 16, color: Colors.white54),
                          ],
                        ),
                      ),
                      // Main area
                      Expanded(
                        child: Container(
                          color: bgColor,
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(child: Text(lang == 'id' ? 'Dashboard Klinik' : 'Clinic Dashboard', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w900, color: textColor))),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(color: accentBlue.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(100)),
                                    child: Text(lang == 'id' ? 'BUKA' : 'OPEN', style: GoogleFonts.outfit(fontSize: 7, fontWeight: FontWeight.w900, color: accentBlue)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              // Stats
                              Row(
                                children: [
                                  _buildMini(panelColor, borderColor, textColor, subText, accentBlue, Icons.people_rounded, '32', lang == 'id' ? 'Pasien' : 'Patients'),
                                  const SizedBox(width: 8),
                                  _buildMini(panelColor, borderColor, textColor, subText, Colors.orange, Icons.queue_rounded, '7', lang == 'id' ? 'Antrean' : 'Queue'),
                                  const SizedBox(width: 8),
                                  _buildMini(panelColor, borderColor, textColor, subText, Colors.green, Icons.medical_services_rounded, '3', lang == 'id' ? 'Dokter' : 'Doctors'),
                                ],
                              ),
                              const SizedBox(height: 10),
                              // Billing + Queue Panel
                              Expanded(
                                child: Row(
                                  children: [
                                    // Queue Panel
                                    Expanded(
                                      flex: 3,
                                      child: Container(
                                        decoration: BoxDecoration(color: panelColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
                                        padding: const EdgeInsets.all(10),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(children: [
                                              const Icon(Icons.queue_rounded, size: 8, color: Color(0xFF4A90E2)),
                                              const SizedBox(width: 4),
                                              Text(lang == 'id' ? 'ANTREAN' : 'QUEUE', style: GoogleFonts.outfit(fontSize: 7, fontWeight: FontWeight.w900, color: textColor, letterSpacing: 0.5)),
                                            ]),
                                            const SizedBox(height: 8),
                                            ..._buildQueueItems(panelColor, borderColor, textColor, subText, lang),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // Billing Panel
                                    Expanded(
                                      flex: 4,
                                      child: Container(
                                        decoration: BoxDecoration(color: panelColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
                                        padding: const EdgeInsets.all(10),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(children: [
                                              const Icon(Icons.receipt_long_rounded, size: 8, color: Colors.green),
                                              const SizedBox(width: 4),
                                              Text(lang == 'id' ? 'KASIR KLINIK' : 'CLINIC BILLING', style: GoogleFonts.outfit(fontSize: 7, fontWeight: FontWeight.w900, color: textColor, letterSpacing: 0.5)),
                                            ]),
                                            const SizedBox(height: 8),
                                            _buildBillingRow(textColor, subText, lang == 'id' ? 'Konsultasi' : 'Consultation', 'Rp 75.000'),
                                            _buildBillingRow(textColor, subText, lang == 'id' ? 'Obat & Resep' : 'Meds & Rx', 'Rp 120.000'),
                                            _buildBillingRow(textColor, subText, lang == 'id' ? 'Tindakan' : 'Treatment', 'Rp 50.000'),
                                            const Divider(height: 12, thickness: 0.5),
                                            Row(
                                              children: [
                                                Text('TOTAL', style: GoogleFonts.outfit(fontSize: 7, fontWeight: FontWeight.w900, color: textColor)),
                                                const Spacer(),
                                                Text('Rp 245.000', style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.green)),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            Container(
                                              width: double.infinity,
                                              padding: const EdgeInsets.symmetric(vertical: 5),
                                              decoration: BoxDecoration(color: const Color(0xFF4A90E2), borderRadius: BorderRadius.circular(6)),
                                              alignment: Alignment.center,
                                              child: Text(lang == 'id' ? 'BAYAR' : 'PAY', style: GoogleFonts.outfit(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.white)),
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

  Widget _buildMini(Color panelColor, Color borderColor, Color textColor, Color subText, Color accent, IconData icon, String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: panelColor, borderRadius: BorderRadius.circular(10), border: Border.all(color: borderColor)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 11, color: accent),
          const SizedBox(height: 3),
          Text(value, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w900, color: textColor, height: 1.0)),
          Text(label, style: GoogleFonts.outfit(fontSize: 6, color: subText)),
        ]),
      ),
    );
  }

  List<Widget> _buildQueueItems(Color panelColor, Color borderColor, Color textColor, Color subText, String lang) {
    final items = [
      {'name': 'Sri W.', 'status': lang == 'id' ? 'Dilayani' : 'Active', 'color': Colors.orange},
      {'name': 'Hendra B.', 'status': lang == 'id' ? 'Menunggu' : 'Waiting', 'color': Colors.grey},
      {'name': 'Ayu N.', 'status': lang == 'id' ? 'Menunggu' : 'Waiting', 'color': Colors.grey},
    ];
    return items.map((item) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        Container(width: 5, height: 5, decoration: BoxDecoration(color: item['color'] as Color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Expanded(child: Text(item['name'] as String, style: GoogleFonts.outfit(fontSize: 7, fontWeight: FontWeight.bold, color: textColor))),
        Text(item['status'] as String, style: GoogleFonts.outfit(fontSize: 6, color: item['color'] as Color)),
      ]),
    )).toList();
  }

  Widget _buildBillingRow(Color textColor, Color subText, String item, String price) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: [
        Text(item, style: GoogleFonts.outfit(fontSize: 7, color: subText)),
        const Spacer(),
        Text(price, style: GoogleFonts.outfit(fontSize: 7, fontWeight: FontWeight.bold, color: textColor)),
      ]),
    );
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
        Center(
          child: Column(
            children: [
              Text(
                lang == 'id' ? 'FITUR SISTEM KLINIK' : 'CLINIC SYSTEM FEATURES',
                style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 2, color: activeColor),
              ),
              const SizedBox(height: 8),
              Text(
                lang == 'id' ? 'Solusi Klinik Terpadu' : 'Integrated Clinic Solution',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.w900, color: textColor),
              ),
              const SizedBox(height: 8),
              Text(
                lang == 'id' ? 'RME, Antrean, Kasir, dan lebih banyak lagi — dalam satu sistem.' : 'EMR, Queue, POS, and more — in one system.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(fontSize: 14, color: bodyTextColor, height: 1.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 48),
        if (isMobile)
          ...features.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _buildFeatureCard(f, cardColor, borderColor, textColor, bodyTextColor),
              ))
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: features.map((f) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: _buildFeatureCard(f, cardColor, borderColor, textColor, bodyTextColor),
              ),
            )).toList(),
          ),
      ],
    );
  }

  Widget _buildFeatureCard(Map<String, dynamic> feature, Color cardColor, Color borderColor, Color textColor, Color bodyTextColor) {
    final color = feature['color'] as Color;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
            child: Icon(feature['icon'] as IconData, color: color, size: 22),
          ),
          const SizedBox(height: 16),
          Text(feature['title'] as String, style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w800, color: textColor)),
          const SizedBox(height: 8),
          Text(feature['desc'] as String, style: GoogleFonts.outfit(fontSize: 13, color: bodyTextColor, height: 1.5)),
        ],
      ),
    );
  }
}
