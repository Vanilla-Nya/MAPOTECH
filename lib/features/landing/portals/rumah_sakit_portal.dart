import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapotech/features/landing/landing_page_data.dart';
import 'package:mapotech/shared/layouts/responsive_layout.dart';
import 'package:mapotech/shared/widgets/custom_button.dart';
import 'package:mapotech/shared/widgets/three_dimensional_device_wrapper.dart';
import 'package:mapotech/shared/widgets/segera_hadir_mockup.dart';

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
              Icon(Icons.corporate_fare_rounded, color: activeColor, size: 14),
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
          spacing: 8, runSpacing: 8,
          children: [
            _buildBadge(cardColor, borderColor, textColor, Icons.verified_rounded, activeColor, 'SatuSehat'),
            _buildBadge(cardColor, borderColor, textColor, Icons.security_rounded, Colors.indigo, lang == 'id' ? 'Enterprise Grade' : 'Enterprise Grade'),
            _buildBadge(cardColor, borderColor, textColor, Icons.account_balance_rounded, Colors.blue, 'BPJS'),
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

  Widget _buildHospitalERPMockup(bool isDark, Color borderColor, Color cardColor, Color activeColor, Color textColor, Color bodyTextColor, String lang) {
    final bgColor = isDark ? const Color(0xFF0D0F1A) : const Color(0xFFF2F5FF);
    final panelColor = isDark ? const Color(0xFF161B2E) : Colors.white;
    final subText = isDark ? Colors.grey[400]! : Colors.grey[600]!;
    const accentIndigo = Color(0xFF3F51B5);

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
            width: 640,
            height: 400,
            decoration: BoxDecoration(
              color: bgColor, borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor, width: 1.5),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.1), blurRadius: 30, offset: const Offset(0, 15))],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                // Top app bar
                Container(
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF283593), Color(0xFF3949AB)]),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Image.asset(
                        'assets/images/logo.png',
                        width: 16,
                        height: 16,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => const Icon(
                          Icons.corporate_fare_rounded,
                          size: 16,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(lang == 'id' ? 'MAPOTECH Hospital ERP' : 'MAPOTECH Hospital ERP', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white)),
                      const Spacer(),
                      Row(children: [
                        Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF69F0AE), shape: BoxShape.circle)),
                        const SizedBox(width: 4),
                        Text(lang == 'id' ? 'ONLINE' : 'ONLINE', style: GoogleFonts.outfit(fontSize: 7, fontWeight: FontWeight.w900, color: Colors.white70)),
                      ]),
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      // ERP Nav sidebar
                      Container(
                        width: 110,
                        color: isDark ? const Color(0xFF1A1A35) : const Color(0xFF1A237E),
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildNavItem(Icons.dashboard_rounded, lang == 'id' ? 'Dashboard' : 'Dashboard', true, isDark),
                            _buildNavItem(Icons.bed_rounded, lang == 'id' ? 'Rawat Inap' : 'Inpatient', false, isDark),
                            _buildNavItem(Icons.directions_run_rounded, lang == 'id' ? 'Rawat Jalan' : 'Outpatient', false, isDark),
                            _buildNavItem(Icons.science_rounded, lang == 'id' ? 'Laboratorium' : 'Laboratory', false, isDark),
                            _buildNavItem(Icons.local_pharmacy_rounded, lang == 'id' ? 'Farmasi' : 'Pharmacy', false, isDark),
                            _buildNavItem(Icons.receipt_rounded, lang == 'id' ? 'Billing' : 'Billing', false, isDark),
                          ],
                        ),
                      ),
                      // Main ERP content
                      Expanded(
                        child: Container(
                          color: bgColor, padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // KPI Row
                              Row(
                                children: [
                                  _buildKpiBox(panelColor, borderColor, textColor, subText, accentIndigo, '168', lang == 'id' ? 'Pasien Aktif' : 'Active Patients', Icons.people_rounded),
                                  const SizedBox(width: 6),
                                  _buildKpiBox(panelColor, borderColor, textColor, subText, Colors.green, '42', lang == 'id' ? 'Tempat Tidur' : 'Beds Available', Icons.bed_rounded),
                                  const SizedBox(width: 6),
                                  _buildKpiBox(panelColor, borderColor, textColor, subText, Colors.orange, '12', lang == 'id' ? 'Operasi Hari Ini' : 'Today\'s OR', Icons.science_rounded),
                                ],
                              ),
                              const SizedBox(height: 8),
                              // Ward status
                              Expanded(
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 5,
                                      child: Container(
                                        decoration: BoxDecoration(color: panelColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
                                        padding: const EdgeInsets.all(10),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(lang == 'id' ? 'STATUS BANGSAL' : 'WARD STATUS', style: GoogleFonts.outfit(fontSize: 7, fontWeight: FontWeight.w900, color: textColor, letterSpacing: 0.5)),
                                            const SizedBox(height: 8),
                                            _buildWardRow('Bangsal A', '24/30', 0.8, Colors.orange, borderColor, textColor, subText, panelColor),
                                            _buildWardRow('Bangsal B', '18/30', 0.6, Colors.green, borderColor, textColor, subText, panelColor),
                                            _buildWardRow('ICU', '8/10', 0.8, Colors.red, borderColor, textColor, subText, panelColor),
                                            _buildWardRow(lang == 'id' ? 'VIP' : 'VIP', '3/10', 0.3, Colors.blue, borderColor, textColor, subText, panelColor),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
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
                                                  const Icon(Icons.science_rounded, size: 10, color: Colors.green),
                                                  const SizedBox(height: 4),
                                                  Text(lang == 'id' ? 'Laboratorium' : 'Laboratory', style: GoogleFonts.outfit(fontSize: 8, fontWeight: FontWeight.w900, color: textColor)),
                                                  Text('15 ${lang == 'id' ? 'Sampel Antri' : 'Pending'}', style: GoogleFonts.outfit(fontSize: 6, color: subText)),
                                                  const SizedBox(height: 6),
                                                  Container(height: 3, decoration: BoxDecoration(color: borderColor, borderRadius: BorderRadius.circular(2)), child: FractionallySizedBox(alignment: Alignment.centerLeft, widthFactor: 0.6, child: Container(decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(2))))),
                                                ],
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Expanded(
                                            child: Container(
                                              decoration: BoxDecoration(color: accentIndigo.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: accentIndigo.withValues(alpha: 0.2))),
                                              padding: const EdgeInsets.all(10),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  const Icon(Icons.verified_rounded, size: 10, color: Color(0xFF00BFA5)),
                                                  const SizedBox(height: 4),
                                                  Text('SatuSehat', style: GoogleFonts.outfit(fontSize: 8, fontWeight: FontWeight.w900, color: textColor)),
                                                  Text(lang == 'id' ? 'Terkoneksi' : 'Connected', style: GoogleFonts.outfit(fontSize: 6, color: const Color(0xFF00BFA5))),
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

  Widget _buildNavItem(IconData icon, String label, bool isActive, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: isActive ? BoxDecoration(color: Colors.white.withValues(alpha: 0.15), border: const Border(left: BorderSide(color: Color(0xFF69F0AE), width: 2))) : null,
      child: Row(
        children: [
          Icon(icon, size: 13, color: isActive ? Colors.white : Colors.white54),
          const SizedBox(width: 6),
          Text(label, style: GoogleFonts.outfit(fontSize: 8, fontWeight: isActive ? FontWeight.w900 : FontWeight.w500, color: isActive ? Colors.white : Colors.white54)),
        ],
      ),
    );
  }

  Widget _buildKpiBox(Color panelColor, Color borderColor, Color textColor, Color subText, Color accent, String value, String label, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: panelColor, borderRadius: BorderRadius.circular(10), border: Border.all(color: borderColor)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 11, color: accent),
          const SizedBox(height: 3),
          Text(value, style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w900, color: textColor, height: 1.0)),
          Text(label, style: GoogleFonts.outfit(fontSize: 5.5, color: subText)),
        ]),
      ),
    );
  }

  Widget _buildWardRow(String name, String occ, double fill, Color color, Color borderColor, Color textColor, Color subText, Color panelColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(width: 55, child: Text(name, style: GoogleFonts.outfit(fontSize: 7, fontWeight: FontWeight.bold, color: textColor))),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(height: 5, decoration: BoxDecoration(color: borderColor, borderRadius: BorderRadius.circular(3)), child: FractionallySizedBox(alignment: Alignment.centerLeft, widthFactor: fill, child: Container(decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))))),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(occ, style: GoogleFonts.outfit(fontSize: 6, fontWeight: FontWeight.w700, color: subText)),
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
        Center(
          child: Column(
            children: [
              Text(lang == 'id' ? 'SISTEM ERP RUMAH SAKIT' : 'HOSPITAL ERP SYSTEM',
                style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 2, color: activeColor)),
              const SizedBox(height: 8),
              Text(lang == 'id' ? 'Kelas Enterprise untuk RS' : 'Enterprise-Grade for Hospitals',
                textAlign: TextAlign.center, style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.w900, color: textColor)),
              const SizedBox(height: 8),
              Text(lang == 'id' ? 'Menghubungkan setiap departemen dalam satu platform terintegrasi.' : 'Connecting every department in one integrated platform.',
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
