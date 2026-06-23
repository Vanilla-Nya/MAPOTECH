import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapotech/features/landing/landing_page_data.dart';
import 'package:mapotech/shared/layouts/responsive_layout.dart';
import 'package:mapotech/shared/widgets/custom_button.dart';
import 'package:mapotech/shared/widgets/three_dimensional_device_wrapper.dart';

class PraktikMandiriPortal extends ConsumerWidget {
  const PraktikMandiriPortal({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(landingPageProvider);
    final notifier = ref.read(landingPageProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeroSection(context, state, notifier),
        const SizedBox(height: 80),
        _buildFeaturesGrid(context, state, notifier),
        const SizedBox(height: 80),
        _buildWorkflowSection(context, state, notifier),
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
            boxShadow: [
              BoxShadow(
                color: activeColor.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.medical_services_rounded, color: activeColor, size: 14),
              const SizedBox(width: 8),
              Text(
                notifier.getHeroTagline(),
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  color: textColor.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          notifier.getHeroTitle(),
          textAlign: isMobile ? TextAlign.center : TextAlign.start,
          style: GoogleFonts.outfit(
            fontSize: isMobile ? 48 : 72,
            fontWeight: FontWeight.w900,
            letterSpacing: -2.0,
            height: 0.9,
            color: textColor,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          notifier.getHeroDescription(),
          textAlign: isMobile ? TextAlign.center : TextAlign.start,
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            height: 1.5,
            color: bodyTextColor,
          ),
        ),
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment:
              isMobile ? MainAxisAlignment.center : MainAxisAlignment.start,
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
          mainAxisAlignment:
              isMobile ? MainAxisAlignment.center : MainAxisAlignment.start,
          children: [
            SizedBox(
              width: 100,
              height: 36,
              child: Stack(
                children: List.generate(4, (index) {
                  return Positioned(
                    left: index * 20.0,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                            width: 2),
                        color: isDark ? const Color(0xFF222222) : Colors.grey[200],
                      ),
                      child: ClipOval(
                        child: Image.network(
                          'https://api.dicebear.com/7.x/avataaars/png?seed=${index + 20}',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
            Text(
              '2,000+ ${notifier.t('trusted_providers')}',
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: bodyTextColor,
              ),
            ),
          ],
        ),
      ],
    );

    Widget heroVisual = _buildDoctorDashboardMockup(
      context, isDark, borderColor, cardColor, activeColor, darkGreenColor, textColor, lang,
    );

    heroVisual = ThreeDimensionalDeviceWrapper(child: heroVisual);

    if (isMobile) {
      return Column(
        children: [
          heroText,
          const SizedBox(height: 48),
          heroVisual,
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: heroText),
        const SizedBox(width: 60),
        Expanded(child: heroVisual),
      ],
    );
  }

  // --- DOCTOR WEB DASHBOARD MOCKUP ---
  Widget _buildDoctorDashboardMockup(
    BuildContext context, bool isDark, Color borderColor, Color cardColor,
    Color activeColor, Color darkColor, Color textColor, String lang,
  ) {
    final bgColor = isDark ? const Color(0xFF0D1117) : const Color(0xFFF4FBF9);
    final panelColor = isDark ? const Color(0xFF161B22) : Colors.white;
    final subText = isDark ? Colors.grey[400]! : Colors.grey[600]!;

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
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                  blurRadius: 30,
                  offset: const Offset(0, 15),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                // Browser topbar
                Container(
                  height: 32,
                  color: isDark ? const Color(0xFF161616) : const Color(0xFFEDF7F5),
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
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF222222) : Colors.white,
                            borderRadius: BorderRadius.circular(100),
                            border: Border.all(color: borderColor.withValues(alpha: 0.5)),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'HTTPS://MAPOTECH.DIGITAL/APP/DOKTER',
                            style: GoogleFonts.outfit(fontSize: 7, fontWeight: FontWeight.bold, color: Colors.grey[500], letterSpacing: 0.5),
                          ),
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
                      // Sidebar
                      Container(
                        width: 44,
                        color: isDark ? const Color(0xFF1A1A2E) : const Color(0xFF1B4F42),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Column(
                          children: [
                            Container(
                              width: 28, height: 28,
                              decoration: const BoxDecoration(color: Color(0xFF48C9B0), shape: BoxShape.circle),
                              child: const Icon(Icons.healing_rounded, size: 14, color: Colors.white),
                            ),
                            const SizedBox(height: 20),
                            Icon(Icons.dashboard_rounded, size: 16, color: Colors.white),
                            const SizedBox(height: 16),
                            Icon(Icons.people_rounded, size: 16, color: Colors.white54),
                            const SizedBox(height: 16),
                            Icon(Icons.description_rounded, size: 16, color: Colors.white54),
                            const SizedBox(height: 16),
                            Icon(Icons.medication_rounded, size: 16, color: Colors.white54),
                            const SizedBox(height: 16),
                            Icon(Icons.sync_rounded, size: 16, color: Colors.white54),
                          ],
                        ),
                      ),
                      // Main content
                      Expanded(
                        child: Container(
                          color: bgColor,
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Top bar
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      lang == 'id' ? 'Dasbor Praktik' : 'Practice Dashboard',
                                      style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w900, color: textColor),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF48C9B0).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(100),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(width: 5, height: 5, decoration: const BoxDecoration(color: Color(0xFF48C9B0), shape: BoxShape.circle)),
                                        const SizedBox(width: 4),
                                        Text(lang == 'id' ? 'BERTUGAS' : 'ON DUTY', style: GoogleFonts.outfit(fontSize: 7, fontWeight: FontWeight.w900, color: const Color(0xFF1B4F42))),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              // Stats row
                              Row(
                                children: [
                                  _buildStatCard(panelColor, borderColor, textColor, subText, activeColor, Icons.people_alt_rounded, '6', lang == 'id' ? 'Pasien' : 'Patients', false),
                                  const SizedBox(width: 8),
                                  _buildStatCard(panelColor, borderColor, textColor, subText, Colors.orange, Icons.pending_actions_rounded, '2', lang == 'id' ? 'Antrean' : 'Queue', false),
                                  const SizedBox(width: 8),
                                  _buildStatCard(panelColor, borderColor, textColor, subText, const Color(0xFF48C9B0), Icons.description_rounded, '8', lang == 'id' ? 'E-Resep' : 'E-Rx', false),
                                ],
                              ),
                              const SizedBox(height: 10),
                              // Patient queue table header
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: activeColor.withValues(alpha: 0.08),
                                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(10), topRight: Radius.circular(10)),
                                ),
                                child: Row(
                                  children: [
                                    Text(lang == 'id' ? 'ANTREAN HARI INI' : "TODAY'S QUEUE", style: GoogleFonts.outfit(fontSize: 7, fontWeight: FontWeight.w900, color: textColor)),
                                    const Spacer(),
                                    Text(lang == 'id' ? 'LIHAT SEMUA' : 'VIEW ALL', style: GoogleFonts.outfit(fontSize: 6, fontWeight: FontWeight.w900, color: activeColor)),
                                  ],
                                ),
                              ),
                              // Patient rows
                              ..._buildPatientRows(isDark, panelColor, borderColor, textColor, subText, activeColor, lang),
                              const SizedBox(height: 10),
                              // SatuSehat badge
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: panelColor,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: borderColor),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(5),
                                      decoration: BoxDecoration(color: const Color(0xFF48C9B0).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                                      child: const Icon(Icons.verified_rounded, size: 12, color: Color(0xFF48C9B0)),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('SatuSehat', style: GoogleFonts.outfit(fontSize: 8, fontWeight: FontWeight.w900, color: textColor)),
                                          Text(lang == 'id' ? 'Data berhasil disinkronisasi' : 'Data synced successfully', style: GoogleFonts.outfit(fontSize: 6, color: subText)),
                                        ],
                                      ),
                                    ),
                                    Text(lang == 'id' ? 'SYNC' : 'SYNC', style: GoogleFonts.outfit(fontSize: 7, fontWeight: FontWeight.w900, color: const Color(0xFF48C9B0))),
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

  Widget _buildStatCard(Color panelColor, Color borderColor, Color textColor, Color subText, Color accentColor, IconData icon, String value, String label, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: panelColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 12, color: accentColor),
            const SizedBox(height: 4),
            Text(value, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900, color: textColor, height: 1.0)),
            Text(label, style: GoogleFonts.outfit(fontSize: 6, fontWeight: FontWeight.w600, color: subText)),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildPatientRows(bool isDark, Color panelColor, Color borderColor, Color textColor, Color subText, Color activeColor, String lang) {
    final patients = [
      {'name': 'Aditya S.', 'no': '01', 'status': lang == 'id' ? 'Selesai' : 'Done', 'color': Colors.green},
      {'name': 'Ratih M.', 'no': '02', 'status': lang == 'id' ? 'Dilayani' : 'Active', 'color': Colors.orange},
      {'name': 'Budi H.', 'no': '03', 'status': lang == 'id' ? 'Menunggu' : 'Waiting', 'color': Colors.grey},
    ];
    return patients.map((p) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: panelColor,
          border: Border(
            left: BorderSide(color: borderColor),
            right: BorderSide(color: borderColor),
            bottom: BorderSide(color: borderColor),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 16, height: 16,
              decoration: BoxDecoration(color: activeColor.withValues(alpha: 0.15), shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Text(p['no'] as String, style: GoogleFonts.outfit(fontSize: 6, fontWeight: FontWeight.w900, color: activeColor)),
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(p['name'] as String, style: GoogleFonts.outfit(fontSize: 8, fontWeight: FontWeight.bold, color: textColor))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: (p['color'] as Color).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(p['status'] as String, style: GoogleFonts.outfit(fontSize: 6, fontWeight: FontWeight.w900, color: p['color'] as Color)),
            ),
          ],
        ),
      );
    }).toList();
  }

  // --- FEATURES GRID ---
  Widget _buildFeaturesGrid(BuildContext context, LandingPageState state,
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
        'icon': Icons.people_alt_rounded,
        'title': lang == 'id' ? 'Rekam Medis Elektronik' : 'Electronic Medical Records',
        'desc': lang == 'id'
            ? 'Catat anamnesis, diagnosis, dan resep pasien dalam sistem RME terstandarisasi SatuSehat.'
            : 'Record anamnesis, diagnosis, and prescriptions in a SatuSehat-standardized EMR system.',
        'color': activeColor,
      },
      {
        'icon': Icons.description_rounded,
        'title': lang == 'id' ? 'E-Resep Digital' : 'Digital E-Prescription',
        'desc': lang == 'id'
            ? 'Kirim resep elektronik langsung ke apotek mitra MAPOTECH untuk penebusan tanpa kertas.'
            : 'Send digital prescriptions directly to MAPOTECH partner pharmacies for paperless redemption.',
        'color': Colors.orange,
      },
      {
        'icon': Icons.sync_rounded,
        'title': 'SatuSehat Sync',
        'desc': lang == 'id'
            ? 'Sinkronisasi data pasien dan hasil pemeriksaan ke platform SatuSehat Kemenkes secara otomatis.'
            : 'Synchronize patient data and examination results to SatuSehat Kemenkes automatically.',
        'color': const Color(0xFF48C9B0),
      },
      {
        'icon': Icons.pending_actions_rounded,
        'title': lang == 'id' ? 'Antrean & Jadwal' : 'Queue & Schedule',
        'desc': lang == 'id'
            ? 'Manajemen antrean otomatis dengan notifikasi pasien secara real-time via aplikasi mobile.'
            : 'Automated queue management with real-time patient notifications via mobile app.',
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
                lang == 'id' ? 'FITUR PRAKTIK MANDIRI' : 'PRIVATE PRACTICE FEATURES',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  color: activeColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                lang == 'id' ? 'Semua yang Anda Butuhkan' : 'Everything You Need',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                lang == 'id'
                    ? 'Platform lengkap untuk efisiensi praktik medis Anda.'
                    : 'A complete platform for your medical practice efficiency.',
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
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(feature['icon'] as IconData, color: color, size: 22),
          ),
          const SizedBox(height: 16),
          Text(
            feature['title'] as String,
            style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w800, color: textColor),
          ),
          const SizedBox(height: 8),
          Text(
            feature['desc'] as String,
            style: GoogleFonts.outfit(fontSize: 13, color: bodyTextColor, height: 1.5),
          ),
        ],
      ),
    );
  }

  // --- WORKFLOW SECTION ---
  Widget _buildWorkflowSection(BuildContext context, LandingPageState state,
      LandingPageNotifier notifier) {
    final isMobile = ResponsiveLayout.isMobile(context);
    final activeColor = notifier.getPrimaryColor();
    final textColor = notifier.getTextColor();
    final bodyTextColor = notifier.getBodyTextColor();
    final cardColor = notifier.getCardColor();
    final borderColor = notifier.getBorderColor();
    final isDark = state.appearance == 'dark';
    final lang = state.language;

    final steps = [
      {
        'num': '01',
        'title': lang == 'id' ? 'Pasien Mendaftar' : 'Patient Registers',
        'desc': lang == 'id' ? 'Pasien booking antrean via aplikasi mobile MAPOTECH.' : 'Patient books queue via MAPOTECH mobile app.',
        'icon': Icons.person_add_rounded,
      },
      {
        'num': '02',
        'title': lang == 'id' ? 'Pemeriksaan & RME' : 'Examination & EMR',
        'desc': lang == 'id' ? 'Dokter mencatat hasil pemeriksaan ke RME digital.' : 'Doctor records examination results into digital EMR.',
        'icon': Icons.assignment_rounded,
      },
      {
        'num': '03',
        'title': lang == 'id' ? 'E-Resep Dikirim' : 'E-Rx Sent',
        'desc': lang == 'id' ? 'Resep digital langsung dikirim ke apotek mitra.' : 'Digital prescription sent directly to partner pharmacy.',
        'icon': Icons.send_rounded,
      },
      {
        'num': '04',
        'title': 'SatuSehat Sync',
        'desc': lang == 'id' ? 'Data otomatis tersinkron ke platform Kemenkes.' : 'Data auto-synced to Kemenkes platform.',
        'icon': Icons.cloud_done_rounded,
      },
    ];

    return Container(
      padding: EdgeInsets.all(isMobile ? 24 : 40),
      decoration: BoxDecoration(
        color: activeColor.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: activeColor.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Column(
              children: [
                Text(
                  lang == 'id' ? 'ALUR KERJA' : 'WORKFLOW',
                  style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2, color: activeColor),
                ),
                const SizedBox(height: 8),
                Text(
                  lang == 'id' ? 'Proses yang Mulus' : 'Seamless Process',
                  style: GoogleFonts.outfit(fontSize: 26, fontWeight: FontWeight.w900, color: textColor),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          if (isMobile)
            ...steps.asMap().entries.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _buildWorkflowStep(e.value, activeColor, cardColor, borderColor, textColor, bodyTextColor, isDark, e.key < steps.length - 1),
                ))
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: steps.asMap().entries.map((e) => Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildWorkflowStep(e.value, activeColor, cardColor, borderColor, textColor, bodyTextColor, isDark, false)),
                    if (e.key < steps.length - 1) ...[
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(top: 32),
                        child: Icon(Icons.arrow_forward_rounded, size: 16, color: activeColor.withValues(alpha: 0.4)),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              )).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildWorkflowStep(Map<String, dynamic> step, Color activeColor, Color cardColor, Color borderColor, Color textColor, Color bodyTextColor, bool isDark, bool showArrow) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: activeColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(step['num'] as String, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: isDark ? Colors.black : Colors.white)),
              ),
              const Spacer(),
              Icon(step['icon'] as IconData, size: 18, color: activeColor.withValues(alpha: 0.4)),
            ],
          ),
          const SizedBox(height: 12),
          Text(step['title'] as String, style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w800, color: textColor)),
          const SizedBox(height: 6),
          Text(step['desc'] as String, style: GoogleFonts.outfit(fontSize: 11, color: bodyTextColor, height: 1.4)),
        ],
      ),
    );
  }
}
