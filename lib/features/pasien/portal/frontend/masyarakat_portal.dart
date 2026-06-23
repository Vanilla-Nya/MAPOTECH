import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapotech/features/landing/landing_page_data.dart';
import 'package:mapotech/shared/layouts/responsive_layout.dart';
import 'package:mapotech/shared/widgets/custom_button.dart';
import 'package:mapotech/shared/widgets/three_dimensional_device_wrapper.dart';

class MasyarakatPortal extends ConsumerWidget {
  const MasyarakatPortal({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(landingPageProvider);
    final notifier = ref.read(landingPageProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeroSection(context, state, notifier),
        const SizedBox(height: 80),
        _buildMasyarakatFeatures(context, state, notifier),
        const SizedBox(height: 80),
        _buildTimelineSection(context, state, notifier),
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

    Widget heroText = Column(
      crossAxisAlignment:
          isMobile ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        // Tagline
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: activeColor.withOpacity(0.2),
            ),
            boxShadow: [
              BoxShadow(
                color: activeColor.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.favorite_rounded,
                color: activeColor,
                size: 14,
              ),
              const SizedBox(width: 8),
              Text(
                notifier.getHeroTagline(),
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  color: textColor.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Main Title
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

        // Sub description
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

        // Action Buttons
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

        // Social proof
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
                          'https://api.dicebear.com/7.x/avataaars/png?seed=${index + 12}',
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

    Widget heroVisual = _buildMasyarakatBrowserMockup(
      context,
      isDark,
      borderColor,
      cardColor,
      activeColor,
      darkGreenColor,
      textColor,
      bodyTextColor,
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

  // --- BROWSER MOCKUP ---
  Widget _buildMasyarakatBrowserMockup(
    BuildContext context,
    bool isDark,
    Color borderColor,
    Color cardColor,
    Color activeColor,
    Color darkGreenColor,
    Color textColor,
    Color bodyTextColor,
  ) {
    return Container(
      height: 480,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: darkGreenColor.withOpacity(0.03),
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
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
                  blurRadius: 30,
                  offset: const Offset(0, 15),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                // Top Browser Bar (Address bar & controls)
                Container(
                  height: 36,
                  color: isDark ? const Color(0xFF161616) : const Color(0xFFF2F4F4),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Row(
                        children: [
                          Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFFFF5F56), shape: BoxShape.circle)),
                          const SizedBox(width: 6),
                          Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFFFFBD2E), shape: BoxShape.circle)),
                          const SizedBox(width: 6),
                          Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF27C93F), shape: BoxShape.circle)),
                        ],
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: Container(
                          height: 24,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF222222) : Colors.white,
                            borderRadius: BorderRadius.circular(100),
                            border: Border.all(color: borderColor.withOpacity(0.5)),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'HTTPS://MAPOTECH.DIGITAL/APP/PASIEN',
                            style: GoogleFonts.outfit(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[500],
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 24),
                      Icon(Icons.refresh_rounded, size: 14, color: Colors.grey[500]),
                    ],
                  ),
                ),
                
                // Browser Main Body (Sidebar + Content)
                Expanded(
                  child: Row(
                    children: [
                      // Left Sidebar
                      Container(
                        width: 48,
                        color: isDark ? const Color(0xFF161616) : const Color(0xFFF3EEFC),
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Column(
                          children: [
                            Icon(Icons.show_chart_rounded, size: 18, color: activeColor),
                            const SizedBox(height: 20),
                            Icon(Icons.grid_view_rounded, size: 16, color: Colors.grey[500]),
                            const SizedBox(height: 20),
                            Icon(Icons.favorite_rounded, size: 16, color: Colors.grey[500]),
                            const SizedBox(height: 20),
                            Icon(Icons.lock_rounded, size: 16, color: Colors.grey[500]),
                            const SizedBox(height: 20),
                            Icon(Icons.history_rounded, size: 16, color: Colors.grey[500]),
                            const SizedBox(height: 20),
                            Icon(Icons.settings_rounded, size: 16, color: Colors.grey[500]),
                          ],
                        ),
                      ),
                      
                      // Right Dashboard Panel
                      Expanded(
                        child: Container(
                          color: isDark ? const Color(0xFF121212) : const Color(0xFFFBFBFC),
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Top Greeting Pill
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE8F8F5),
                                    borderRadius: BorderRadius.circular(100),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(width: 4, height: 4, decoration: const BoxDecoration(color: Color(0xFF48C9B0), shape: BoxShape.circle)),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Selamat Datang, Elysia-♪',
                                        style: GoogleFonts.outfit(
                                          fontSize: 8,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF1B4F42),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              
                              // Profile Card
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: cardColor,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: borderColor),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(color: const Color(0xFFFFB5E8), width: 2), // pink outline
                                        color: const Color(0xFFFDF6FA),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        'EL',
                                        style: GoogleFonts.outfit(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w900,
                                          color: const Color(0xFFFF8BCC),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Elysia-♪',
                                            style: GoogleFonts.outfit(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w900,
                                              color: textColor,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Row(
                                            children: [
                                              Text(
                                                'USIA\n20 TH',
                                                style: GoogleFonts.outfit(fontSize: 6, fontWeight: FontWeight.bold, color: Colors.grey),
                                              ),
                                              const SizedBox(width: 12),
                                              Text(
                                                'DOMISILI\nRT 01/RW 02',
                                                style: GoogleFonts.outfit(fontSize: 6, fontWeight: FontWeight.bold, color: Colors.grey),
                                              ),
                                              const SizedBox(width: 12),
                                              Text(
                                                'NIK\n1234567890123456',
                                                style: GoogleFonts.outfit(fontSize: 6, fontWeight: FontWeight.bold, color: Colors.grey),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFB577F2),
                                            borderRadius: BorderRadius.circular(100),
                                          ),
                                          child: Text(
                                            'EDIT PROFIL',
                                            style: GoogleFonts.outfit(fontSize: 6, fontWeight: FontWeight.w900, color: Colors.white),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFDF6FA),
                                            border: Border.all(color: const Color(0xFFFFB5E8)),
                                            borderRadius: BorderRadius.circular(100),
                                          ),
                                          child: Text(
                                            'BAGIKAN DATA',
                                            style: GoogleFonts.outfit(fontSize: 6, fontWeight: FontWeight.w900, color: const Color(0xFFFF8BCC)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              
                              // Shortcut Row
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildBrowserShortcutCard(
                                      isDark,
                                      borderColor,
                                      cardColor,
                                      textColor,
                                      'BOOKING LAGI',
                                      'Dr. Vanillanyan',
                                      'Dokter Umum',
                                      Icons.history_rounded,
                                      const Color(0xFFB577F2),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildBrowserShortcutCard(
                                      isDark,
                                      borderColor,
                                      cardColor,
                                      textColor,
                                      'QR RESEP',
                                      'Resep Digital',
                                      'Tebus obat di apotek',
                                      Icons.qr_code_2_rounded,
                                      const Color(0xFF48C9B0),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              
                              // Lower Panels (Janji Temu + Map Lokasi Klinik)
                              Expanded(
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 4,
                                      child: Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: cardColor,
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(color: borderColor),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                const Icon(Icons.access_time_rounded, size: 8, color: Color(0xFFB577F2)),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'JANJI TEMU',
                                                  style: GoogleFonts.outfit(fontSize: 7, fontWeight: FontWeight.w900, color: textColor, letterSpacing: 0.5),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              'JANJI TEMU\nBERIKUTNYA',
                                              style: GoogleFonts.outfit(fontSize: 6, fontWeight: FontWeight.bold, color: Colors.grey[500]),
                                            ),
                                            const SizedBox(height: 6),
                                            Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: isDark ? const Color(0xFF222222) : const Color(0xFFF9F9FB),
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(color: borderColor),
                                              ),
                                              child: Row(
                                                children: [
                                                  CircleAvatar(
                                                    radius: 10,
                                                    backgroundColor: activeColor.withOpacity(0.15),
                                                    child: Icon(Icons.person_rounded, size: 10, color: activeColor),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Text(
                                                        'Dr. Vanillanyan',
                                                        style: GoogleFonts.outfit(fontSize: 7, fontWeight: FontWeight.bold, color: textColor),
                                                      ),
                                                      Text(
                                                        'Dokter',
                                                        style: GoogleFonts.outfit(fontSize: 5, color: Colors.grey),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      flex: 6,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: cardColor,
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(color: borderColor),
                                        ),
                                        clipBehavior: Clip.antiAlias,
                                        child: Stack(
                                          children: [
                                            Positioned.fill(
                                              child: CustomPaint(
                                                painter: MapGridPainter(color: borderColor.withOpacity(isDark ? 0.3 : 0.7)),
                                              ),
                                            ),
                                            Positioned(
                                              top: 8,
                                              left: 8,
                                              child: Row(
                                                children: [
                                                  const Icon(Icons.search_rounded, size: 8, color: Color(0xFFB577F2)),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    'LOKASI KLINIK',
                                                    style: GoogleFonts.outfit(fontSize: 7, fontWeight: FontWeight.w900, color: textColor, letterSpacing: 0.5),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Positioned(
                                              top: 8,
                                              right: 8,
                                              child: Text(
                                                'PETUNJUK ARAH',
                                                style: GoogleFonts.outfit(fontSize: 6, fontWeight: FontWeight.w900, color: const Color(0xFFB577F2)),
                                              ),
                                            ),
                                            Center(
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: Colors.black,
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: Text(
                                                      'KLINIK VANILLANYAN',
                                                      style: GoogleFonts.outfit(fontSize: 6, fontWeight: FontWeight.w900, color: Colors.white),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Container(
                                                    width: 6,
                                                    height: 6,
                                                    decoration: const BoxDecoration(
                                                      color: Color(0xFFB577F2),
                                                      shape: BoxShape.circle,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Positioned(
                                              left: 8,
                                              bottom: 8,
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  _buildMapZoomButton('+', isDark, borderColor),
                                                  const SizedBox(height: 2),
                                                  _buildMapZoomButton('-', isDark, borderColor),
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

  Widget _buildBrowserShortcutCard(
    bool isDark,
    Color borderColor,
    Color cardColor,
    Color textColor,
    String badgeText,
    String title,
    String desc,
    IconData icon,
    Color themeColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: themeColor.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 12, color: themeColor),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  badgeText,
                  style: GoogleFonts.outfit(fontSize: 5, fontWeight: FontWeight.w900, color: Colors.grey),
                ),
                Text(
                  title,
                  style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.bold, color: textColor),
                ),
                Text(
                  desc,
                  style: GoogleFonts.outfit(fontSize: 6, color: Colors.grey),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, size: 12, color: Colors.grey[400]),
        ],
      ),
    );
  }

  Widget _buildMapZoomButton(String label, bool isDark, Color borderColor) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(2),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: GoogleFonts.outfit(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.black87),
      ),
    );
  }

  // --- FEATURES ---
  Widget _buildMasyarakatFeatures(BuildContext context, LandingPageState state, LandingPageNotifier notifier) {
    final isMobile = ResponsiveLayout.isMobile(context);
    final textColor = notifier.getTextColor();
    final bodyTextColor = notifier.getBodyTextColor();
    final cardColor = notifier.getCardColor();
    final borderColor = notifier.getBorderColor();

    final features = [
      {
        'title': 'Profil Kesehatan',
        'desc': 'Akses data kesehatan pribadi and riwayat kunjungan dalam satu akun.',
        'icon': Icons.person_outline_rounded,
      },
      {
        'title': 'Riwayat Medis',
        'desc': 'Lihat resep, diagnosis, and hasil pemeriksaan kapan saja.',
        'icon': Icons.history_rounded,
      },
      {
        'title': 'Booking Online',
        'desc': 'Buat janji temu dengan dokter atau faskes pilihan dengan mudah.',
        'icon': Icons.access_time_rounded,
      },
      {
        'title': 'Resep Digital',
        'desc': 'Akses resep obat digital yang dapat digunakan di apotek mitra.',
        'icon': Icons.medical_services_outlined,
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Column(
            children: [
              Text(
                'FITUR UNGGULAN',
                style: GoogleFonts.outfit(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: 60,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFB577F2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 48),

        if (isMobile) ...[
          ...features.map((feature) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: _buildMasyarakatFeatureCard(
                feature['title'] as String,
                feature['desc'] as String,
                feature['icon'] as IconData,
                cardColor,
                borderColor,
                textColor,
                bodyTextColor,
              ),
            );
          }),
        ] else ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: features.map((feature) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: _buildMasyarakatFeatureCard(
                    feature['title'] as String,
                    feature['desc'] as String,
                    feature['icon'] as IconData,
                    cardColor,
                    borderColor,
                    textColor,
                    bodyTextColor,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildMasyarakatFeatureCard(
    String title,
    String desc,
    IconData icon,
    Color cardColor,
    Color borderColor,
    Color textColor,
    Color bodyTextColor,
  ) {
    return Container(
      height: 180,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF3EEFC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: const Color(0xFFB577F2),
              size: 20,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Text(
              desc,
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: bodyTextColor,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- TIMELINE SECTION ---
  Widget _buildTimelineSection(BuildContext context, LandingPageState state, LandingPageNotifier notifier) {
    final isMobile = ResponsiveLayout.isMobile(context);
    final activeColor = notifier.getPrimaryColor();
    final textColor = notifier.getTextColor();
    final bodyTextColor = notifier.getBodyTextColor();
    final cardColor = notifier.getCardColor();
    final borderColor = notifier.getBorderColor();
    final isDark = state.appearance == 'dark';
    final lang = state.language;
    final updates = notifier.getUpdatesForActiveTab();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isMobile) ...[
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTimelineHeaderBadge(notifier),
              const SizedBox(height: 12),
              Text(
                notifier.t('masyarakat_timeline_title'),
                style: GoogleFonts.outfit(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                notifier.t('timeline_desc'),
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: bodyTextColor,
                ),
              ),
              const SizedBox(height: 24),
              _buildVersionBadge(isDark, borderColor, cardColor, textColor),
            ],
          )
        ] else ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTimelineHeaderBadge(notifier),
                    const SizedBox(height: 16),
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: lang == 'id' ? 'Apa yang Baru di ' : 'What\'s New in ',
                            style: GoogleFonts.outfit(
                              fontSize: 36,
                              fontWeight: FontWeight.w900,
                              color: textColor,
                            ),
                          ),
                          TextSpan(
                            text: lang == 'id' ? 'MASYARAKAT' : 'COMMUNITY',
                            style: GoogleFonts.outfit(
                              fontSize: 36,
                              fontWeight: FontWeight.w900,
                              foreground: Paint()
                                ..shader = const LinearGradient(
                                  colors: [
                                    Color(0xFF48C9B0),
                                    Color(0xFFB577F2),
                                  ],
                                ).createShader(const Rect.fromLTWH(0.0, 0.0, 200.0, 70.0)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      notifier.t('timeline_desc'),
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: bodyTextColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              _buildVersionBadge(isDark, borderColor, cardColor, textColor),
            ],
          ),
        ],
        const SizedBox(height: 60),

        Stack(
          children: [
            Positioned(
              top: 0,
              bottom: 0,
              left: isMobile ? 16 : null,
              right: isMobile ? null : 0,
              child: isMobile
                  ? Container(width: 2, color: const Color(0xFFE2C4F9))
                  : Center(
                      child: Container(width: 2, color: const Color(0xFFE2C4F9)),
                    ),
            ),

            Column(
              children: List.generate(updates.length, (index) {
                final update = updates[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24.0),
                  child: _buildTimelineRowItem(
                    index,
                    update,
                    isMobile,
                    isDark,
                    cardColor,
                    borderColor,
                    textColor,
                    bodyTextColor,
                    activeColor,
                  ),
                );
              }),
            ),
          ],
        ),

        const SizedBox(height: 48),

        Center(
          child: _buildGitHubGitCapsule(isDark, borderColor, cardColor, textColor),
        ),
      ],
    );
  }

  Widget _buildTimelineHeaderBadge(LandingPageNotifier notifier) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF3EEFC),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: const Color(0xFFE2C4F9).withOpacity(0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.history_rounded,
            color: Color(0xFFB577F2),
            size: 14,
          ),
          const SizedBox(width: 6),
          Text(
            notifier.t('timeline_badge').toUpperCase(),
            style: GoogleFonts.outfit(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
              color: const Color(0xFFB577F2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVersionBadge(bool isDark, Color borderColor, Color cardColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'VERSI SAAT INI',
                style: GoogleFonts.outfit(
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                  color: Colors.grey[500],
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                'Alpha 0.2.1',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF3EEFC),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFE2C4F9).withOpacity(0.5)),
            ),
            child: const Icon(
              Icons.rocket_launch_rounded,
              color: Color(0xFFB577F2),
              size: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineRowItem(
    int index,
    UpdateItem update,
    bool isMobile,
    bool isDark,
    Color cardColor,
    Color borderColor,
    Color textColor,
    Color bodyTextColor,
    Color activeColor,
  ) {
    final isLeft = index % 2 == 0;

    final cardWidget = Container(
      width: isMobile ? double.infinity : 460,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF3EEFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2C4F9).withOpacity(0.4)),
              ),
              child: const Icon(
                Icons.star_rounded,
                color: Color(0xFFB577F2),
                size: 16,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    update.date.toUpperCase(),
                    style: GoogleFonts.outfit(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: Colors.grey[500],
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F8F5),
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(color: const Color(0xFF48C9B0).withOpacity(0.3)),
                    ),
                    child: Text(
                      'FITUR BARU',
                      style: GoogleFonts.outfit(
                        fontSize: 7,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF1B4F42),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                update.title,
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                update.description,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: bodyTextColor,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Text(
                    'BACA SELENGKAPNYA',
                    style: GoogleFonts.outfit(
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFFB577F2),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    color: Color(0xFFB577F2),
                    size: 10,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    if (isMobile) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            alignment: Alignment.center,
            child: Container(
              width: 12,
              height: 12,
              decoration: const BoxDecoration(
                color: Color(0xFF48C9B0),
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: cardWidget),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: isLeft
              ? Align(alignment: Alignment.centerRight, child: cardWidget)
              : const SizedBox(),
        ),
        Container(
          width: 60,
          alignment: Alignment.center,
          child: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: const Color(0xFF48C9B0),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF48C9B0).withOpacity(0.4),
                  blurRadius: 6,
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: !isLeft
              ? Align(alignment: Alignment.centerLeft, child: cardWidget)
              : const SizedBox(),
        ),
      ],
    );
  }

  Widget _buildGitHubGitCapsule(bool isDark, Color borderColor, Color cardColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 64,
            height: 24,
            child: Stack(
              children: List.generate(3, (index) {
                return Positioned(
                  left: index * 14.0,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: cardColor, width: 1.5),
                    ),
                    child: ClipOval(
                      child: Image.network(
                        'https://api.dicebear.com/7.x/avataaars/png?seed=${index + 55}',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'TETAP TERUPDATE',
                style: GoogleFonts.outfit(
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                  color: Colors.grey[500],
                  letterSpacing: 0.5,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Ikuti sumber di ',
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  Text(
                    'GitHub',
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFB577F2),
                    ),
                  ),
                  const SizedBox(width: 3),
                  const Icon(
                    Icons.arrow_outward_rounded,
                    color: Color(0xFFB577F2),
                    size: 10,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class MapGridPainter extends CustomPainter {
  final Color color;
  MapGridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    const step = 20.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
