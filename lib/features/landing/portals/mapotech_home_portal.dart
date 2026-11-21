import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapotech/features/landing/landing_page_data.dart';
import 'package:mapotech/shared/layouts/responsive_layout.dart';
import 'package:mapotech/shared/widgets/custom_button.dart';
import 'package:mapotech/shared/widgets/three_dimensional_device_wrapper.dart';
import 'package:mapotech/shared/widgets/selection_modal.dart';

class MapotechHomePortal extends ConsumerStatefulWidget {
  const MapotechHomePortal({super.key});

  @override
  ConsumerState<MapotechHomePortal> createState() => _MapotechHomePortalState();
}

class _MapotechHomePortalState extends ConsumerState<MapotechHomePortal>
    with SingleTickerProviderStateMixin {
  int _selectedPlatformIndex = 0;
  late AnimationController _floatController;
  late Animation<double> _floatAnimation;

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
    _floatAnimation = Tween<double>(begin: -8.0, end: 8.0).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(landingPageProvider);
    final notifier = ref.read(landingPageProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeroSection(context, state, notifier),
        const SizedBox(height: 80),
        _buildFiturUnggulan(context, state, notifier),
        const SizedBox(height: 80),
        _buildMultiPlatformSection(context, state, notifier),
        const SizedBox(height: 80),
        _buildVisiKamiSection(context, state, notifier),
        const SizedBox(height: 80),
        _buildTimelineSection(context, state, notifier),
      ],
    );
  }

  // --- HERO SECTION ---
  Widget _buildHeroSection(
    BuildContext context,
    LandingPageState state,
    LandingPageNotifier notifier,
  ) {
    final isMobile = ResponsiveLayout.isMobile(context);
    final activeColor = notifier.getPrimaryColor();
    final darkGreenColor = notifier.getSecondaryColor();
    final textColor = notifier.getTextColor();
    final bodyTextColor = notifier.getBodyTextColor();
    final cardColor = notifier.getCardColor();
    final borderColor = notifier.getBorderColor();
    final isDark = state.appearance == 'dark';

    Widget heroText = Column(
      crossAxisAlignment: isMobile
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        // Tagline
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: activeColor.withOpacity(0.2)),
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
              Icon(Icons.favorite_rounded, color: activeColor, size: 14),
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
          mainAxisAlignment: isMobile
              ? MainAxisAlignment.center
              : MainAxisAlignment.start,
          children: [
            CustomButton(
              text: notifier.t('start_access'),
              isGradient: true,
              gradientColors: [activeColor, darkGreenColor],
              textColor: isDark ? Colors.black : Colors.white,
              onPressed: () {
                showSelectionModal(context, ref);
              },
            ),
            const SizedBox(width: 16),
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
          mainAxisAlignment: isMobile
              ? MainAxisAlignment.center
              : MainAxisAlignment.start,
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
                          color: isDark
                              ? const Color(0xFF2C2C2C)
                              : Colors.white,
                          width: 2,
                        ),
                        color: isDark
                            ? const Color(0xFF222222)
                            : Colors.grey[200],
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

    Widget heroVisual = Container(
      height: 480,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: darkGreenColor.withOpacity(0.03),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: borderColor),
      ),
      child: Center(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Main tablet illustration container
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.4 : 0.1),
                    blurRadius: 30,
                    offset: const Offset(0, 15),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: Image.asset(
                  'assets/images/mapotech_hero_illustration.png',
                  fit: BoxFit.cover,
                  height: 400,
                  width: 320,
                  errorBuilder: (context, error, stackTrace) {
                    return Image.network(
                      'mapotech_hero_illustration.png',
                      fit: BoxFit.cover,
                      height: 400,
                      width: 320,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 320,
                          height: 400,
                          color: activeColor.withValues(alpha: 0.1),
                          child: Icon(
                            Icons.tablet_rounded,
                            size: 64,
                            color: activeColor,
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),

            // Floating Card Top Right: Pulse chart
            Positioned(
              top: -20,
              right: -20,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF222222) : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: borderColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.show_chart_rounded,
                  color: Color(0xFFB577F2), // purple
                  size: 24,
                ),
              ),
            ),

            // Floating Card Bottom Left: STATUS
            Positioned(
              bottom: -20,
              left: -20,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF222222) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Color(0xFFE8F8F5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle_rounded,
                        color: Color(0xFF48C9B0),
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'STATUS',
                          style: GoogleFonts.outfit(
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            color: Colors.grey,
                            letterSpacing: 1.0,
                          ),
                        ),
                        Text(
                          'Terintegrasi dengan Aman',
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );

    heroVisual = ThreeDimensionalDeviceWrapper(child: heroVisual);

    if (isMobile) {
      return Column(
        children: [heroText, const SizedBox(height: 48), heroVisual],
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

  // --- FITUR UNGGULAN ---
  Widget _buildFiturUnggulan(
    BuildContext context,
    LandingPageState state,
    LandingPageNotifier notifier,
  ) {
    final isMobile = ResponsiveLayout.isMobile(context);
    final activeColor = notifier.getPrimaryColor();
    final textColor = notifier.getTextColor();
    final bodyTextColor = notifier.getBodyTextColor();
    final isDark = state.appearance == 'dark';

    Widget featureCard(
      IconData icon,
      String heading,
      List<Map<String, String>> items,
      Color themeColor,
      Color containerBg,
      Color containerBorder,
      Widget? footer,
    ) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: containerBg,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: containerBorder, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: themeColor.withOpacity(0.04),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: themeColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: themeColor, size: 24),
                ),
                const SizedBox(width: 16),
                Text(
                  heading,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: themeColor,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            ...items.map((item) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 24.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF2E2E2E) : Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.check_rounded,
                        size: 10,
                        color: themeColor,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['title']!,
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item['desc']!,
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: bodyTextColor,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),

            if (footer != null) ...[const SizedBox(height: 12), footer],
          ],
        ),
      );
    }

    final providerItems = [
      {
        'title': 'Manajemen Praktik',
        'desc':
            'Kelola operasional harian praktik mandiri, klinik, hingga rumah sakit.',
      },
      {
        'title': 'Rekam Medis Elektronik',
        'desc':
            'Sentralisasi data kunjungan, diagnosis, tindakan, dan resep pasien. Dilengkapi dengan bridging dengan SatuSehat, BPJS, & Mobile JKN.',
      },
      {
        'title': 'Antrean & Janji Temu',
        'desc': 'Atur jadwal konsultasi dan antrean pasien secara real-time.',
      },
      {
        'title': 'Apotek & Inventori',
        'desc': 'Stok obat, mutasi, dispensing, hingga pelacakan kedaluwarsa.',
      },
      {
        'title': 'Billing & Transaksi',
        'desc':
            'Kasir layanan, transaksi farmasi, dan laporan keuangan terpadu.',
      },
    ];

    final communityItems = [
      {
        'title': 'Profil Kesehatan',
        'desc':
            'Akses data kesehatan pribadi dan riwayat kunjungan dalam satu akun.',
      },
      {
        'title': 'Riwayat Medis',
        'desc': 'Lihat resep, diagnosis, dan hasil pemeriksaan kapan saja.',
      },
      {
        'title': 'Booking Online',
        'desc':
            'Buat janji temu dengan dokter atau faskes pilihan dengan mudah.',
      },
      {
        'title': 'Resep Digital',
        'desc':
            'Akses resep obat digital yang dapat digunakan di apotek mitra.',
      },
    ];

    final providerCardColor = isDark
        ? const Color(0xFF1E1C28)
        : const Color(0xFFF9F6FD);
    final communityCardColor = isDark
        ? const Color(0xFF281C22)
        : const Color(0xFFFDF6FA);

    final providerBorder = isDark
        ? const Color(0xFF372C4C)
        : const Color(0xFFE2C4F9).withOpacity(0.6);
    final communityBorder = isDark
        ? const Color(0xFF4C2C39)
        : const Color(0xFFF9C4E2).withOpacity(0.6);

    const purpleThemeColor = Color(0xFFB577F2); // purple
    const pinkThemeColor = Color(0xFFFF8BCC); // pink

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Column(
            children: [
              Text(
                'Fitur Unggulan',
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
                  color: activeColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 48),

        if (isMobile) ...[
          featureCard(
            Icons.domain_rounded,
            'UNTUK PENYEDIA LAYANAN',
            providerItems,
            purpleThemeColor,
            providerCardColor,
            providerBorder,
            null,
          ),
          const SizedBox(height: 32),
          featureCard(
            Icons.person_rounded,
            'UNTUK MASYARAKAT',
            communityItems,
            pinkThemeColor,
            communityCardColor,
            communityBorder,
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF161616) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: communityBorder),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TERSEDIA SEKARANG',
                          style: GoogleFonts.outfit(
                            fontSize: 7,
                            fontWeight: FontWeight.w900,
                            color: pinkThemeColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          'Satu Akun, Layanan Universal.',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_outward_rounded,
                    color: pinkThemeColor,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ] else ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: featureCard(
                  Icons.domain_rounded,
                  'UNTUK PENYEDIA LAYANAN',
                  providerItems,
                  purpleThemeColor,
                  providerCardColor,
                  providerBorder,
                  null,
                ),
              ),
              const SizedBox(width: 32),
              Expanded(
                child: featureCard(
                  Icons.person_rounded,
                  'UNTUK MASYARAKAT',
                  communityItems,
                  pinkThemeColor,
                  communityCardColor,
                  communityBorder,
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF161616) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: communityBorder),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'TERSEDIA SEKARANG',
                                style: GoogleFonts.outfit(
                                  fontSize: 7,
                                  fontWeight: FontWeight.w900,
                                  color: pinkThemeColor,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              Text(
                                'Satu Akun, Layanan Universal.',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.arrow_outward_rounded,
                          color: pinkThemeColor,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  // --- DUKUNGAN MULTI-PLATFORM SECTION (3D DEVICE SCENE) ---
  Widget _buildMultiPlatformSection(
    BuildContext context,
    LandingPageState state,
    LandingPageNotifier notifier,
  ) {
    final isMobile = ResponsiveLayout.isMobile(context);
    final activeColor = notifier.getPrimaryColor();
    final lang = state.language;

    Widget buildOptionRow(int index, IconData icon, String title) {
      final isSelected = _selectedPlatformIndex == index;
      return Padding(
        padding: const EdgeInsets.only(bottom: 12.0),
        child: InkWell(
          onTap: () => setState(() => _selectedPlatformIndex = index),
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF1E1E24) : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected
                    ? activeColor.withValues(alpha: 0.3)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? activeColor.withValues(alpha: 0.15)
                        : Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: isSelected ? activeColor : Colors.grey,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : Colors.grey[400]!,
                        ),
                      ),
                      if (isSelected) ...[
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Container(
                              width: 5,
                              height: 5,
                              decoration: const BoxDecoration(
                                color: Color(0xFF48C9B0),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              lang == 'id'
                                  ? 'PRATINJAU AKTIF'
                                  : 'ACTIVE PREVIEW',
                              style: GoogleFonts.outfit(
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF48C9B0),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(isMobile ? 24 : 48),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0B10),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: const Color(0xFF1E1E28), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 60,
            offset: const Offset(0, 25),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isMobile) ...[
            Text(
              lang == 'id'
                  ? 'Dukungan Multi-Platform'
                  : 'Multi-Platform Support',
              style: GoogleFonts.outfit(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              lang == 'id'
                  ? 'Satu basis kode untuk pengalaman konsisten di semua perangkat.'
                  : 'One codebase for a consistent experience across all devices.',
              style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey[400]!),
            ),
            const SizedBox(height: 32),
            SizedBox(
              height: 260,
              child: _build3DDeviceScene(activeColor, isMobile),
            ),
            const SizedBox(height: 36),
            buildOptionRow(
              0,
              Icons.phone_iphone_rounded,
              'Mobile (Android & iOS)',
            ),
            buildOptionRow(
              1,
              Icons.language_rounded,
              lang == 'id' ? 'Web Browser' : 'Web Browser',
            ),
            buildOptionRow(
              2,
              Icons.computer_rounded,
              'Desktop (Windows, macOS, Linux)',
            ),
          ] else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 3D Device Scene
                Expanded(
                  flex: 12,
                  child: SizedBox(
                    height: 380,
                    child: _build3DDeviceScene(activeColor, isMobile),
                  ),
                ),
                const SizedBox(width: 56),
                // Text + options
                Expanded(
                  flex: 11,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: activeColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(
                            color: activeColor.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.devices_rounded,
                              size: 12,
                              color: activeColor,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              lang == 'id'
                                  ? 'FLUTTER CROSS-PLATFORM'
                                  : 'FLUTTER CROSS-PLATFORM',
                              style: GoogleFonts.outfit(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1,
                                color: activeColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        lang == 'id'
                            ? 'Dukungan\nMulti-Platform'
                            : 'Multi-Platform\nSupport',
                        style: GoogleFonts.outfit(
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1.05,
                          letterSpacing: -1.0,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        lang == 'id'
                            ? 'Satu basis kode Flutter untuk pengalaman konsisten di semua perangkat — dari smartphone hingga desktop enterprise.'
                            : 'One Flutter codebase for a consistent experience across all devices — from smartphones to enterprise desktops.',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          color: Colors.grey[400]!,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 32),
                      buildOptionRow(
                        0,
                        Icons.phone_iphone_rounded,
                        'Mobile (Android & iOS)',
                      ),
                      buildOptionRow(
                        1,
                        Icons.language_rounded,
                        lang == 'id' ? 'Web Browser' : 'Web Browser',
                      ),
                      buildOptionRow(
                        2,
                        Icons.computer_rounded,
                        'Desktop (Windows, macOS, Linux)',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // --- 3D DEVICE SCENE ---
  Widget _build3DDeviceScene(Color activeColor, bool isMobile) {
    return AnimatedBuilder(
      animation: _floatAnimation,
      builder: (context, child) {
        final float = _floatAnimation.value;
        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            // Glow backdrop
            Positioned(
              bottom: 10,
              child: Container(
                width: isMobile ? 200 : 320,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(100),
                  boxShadow: [
                    BoxShadow(
                      color: activeColor.withValues(alpha: 0.25),
                      blurRadius: 60,
                      spreadRadius: 10,
                    ),
                  ],
                ),
              ),
            ),

            // ─── MONITOR (back-left, rotated) ───
            if (!isMobile)
              Positioned(
                left: 0,
                top: 20,
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.001)
                    ..rotateY(0.25)
                    ..translate(0.0, float * 0.3),
                  child: Opacity(
                    opacity: _selectedPlatformIndex == 2 ? 1.0 : 0.55,
                    child: _buildMonitor3D(activeColor),
                  ),
                ),
              ),

            // ─── LAPTOP (back-right, rotated) ───
            if (!isMobile)
              Positioned(
                right: 0,
                top: 50,
                child: Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.001)
                    ..rotateY(-0.20)
                    ..translate(0.0, float * 0.4),
                  child: Opacity(
                    opacity: _selectedPlatformIndex == 1 ? 1.0 : 0.5,
                    child: _buildLaptop3D(activeColor),
                  ),
                ),
              ),

            // ─── PHONE (front-center, dominant) ───
            Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateX(-0.04)
                ..translate(0.0, float),
              child: AnimatedScale(
                duration: const Duration(milliseconds: 300),
                scale: _selectedPlatformIndex == 0
                    ? 1.0
                    : (isMobile ? 0.85 : 0.75),
                child: _buildPhone3D(activeColor),
              ),
            ),
          ],
        );
      },
    );
  }

  // ─── 3D PHONE WIDGET ───
  Widget _buildPhone3D(Color activeColor) {
    return Container(
      width: 110,
      height: 220,
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D10),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF2A2A35), width: 2.5),
        boxShadow: [
          BoxShadow(
            color: activeColor.withValues(alpha: 0.35),
            blurRadius: 30,
            spreadRadius: 2,
            offset: const Offset(0, 10),
          ),
          const BoxShadow(
            color: Colors.black54,
            blurRadius: 20,
            offset: Offset(0, 15),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Screen gradient
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF2A0D5C),
                    activeColor.withValues(alpha: 0.6),
                    const Color(0xFF0D0D30),
                  ],
                ),
              ),
            ),
            // Screen glare
            Positioned(
              top: -20,
              left: -20,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              ),
            ),
            // Notch
            Positioned(
              top: 8,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 30,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
            // App UI
            Positioned(
              top: 28,
              left: 10,
              child: Text(
                'MAPOTECH',
                style: GoogleFonts.outfit(
                  fontSize: 7,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 1,
                ),
              ),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.favorite_rounded,
                      size: 22,
                      color: activeColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sehat Digital',
                    style: GoogleFonts.outfit(
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            // Bottom button
            Positioned(
              bottom: 14,
              left: 14,
              right: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  'MULAI',
                  style: GoogleFonts.outfit(
                    fontSize: 7,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
            // Edge gloss
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.07),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── 3D LAPTOP WIDGET ───
  Widget _buildLaptop3D(Color activeColor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Screen
        Container(
          width: 190,
          height: 125,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(10),
              topRight: Radius.circular(10),
            ),
            border: Border.all(color: const Color(0xFF2A2A35), width: 2),
            boxShadow: [
              BoxShadow(
                color: activeColor.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          padding: const EdgeInsets.all(5),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF1A1035),
                  activeColor.withValues(alpha: 0.4),
                  const Color(0xFF0A0A1A),
                ],
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                // Glare
                Positioned(
                  top: -10,
                  left: -10,
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                ),
                Positioned(
                  top: 6,
                  left: 6,
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: activeColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'MAPOTECH Web',
                        style: GoogleFonts.outfit(
                          fontSize: 5,
                          fontWeight: FontWeight.w900,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  bottom: 8,
                  left: 8,
                  right: 8,
                  child: Row(
                    children: List.generate(
                      3,
                      (i) => Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: Container(
                            height: 45,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Gloss overlay
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withValues(alpha: 0.05),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Hinge
        Container(width: 194, height: 4, color: const Color(0xFF1A1A22)),
        // Base
        Container(
          width: 210,
          height: 10,
          decoration: BoxDecoration(
            color: const Color(0xFF151520),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(6),
              bottomRight: Radius.circular(6),
            ),
            border: Border.all(color: const Color(0xFF222230), width: 1),
          ),
        ),
        // Shadow ellipse
        Container(
          width: 200,
          height: 6,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── 3D MONITOR WIDGET ───
  Widget _buildMonitor3D(Color activeColor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Screen
        Container(
          width: 200,
          height: 130,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF2A2A3A), width: 4),
            boxShadow: [
              BoxShadow(
                color: activeColor.withValues(alpha: 0.12),
                blurRadius: 25,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          padding: const EdgeInsets.all(6),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF0E1228),
                  activeColor.withValues(alpha: 0.35),
                  const Color(0xFF06061A),
                ],
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                Positioned(
                  top: -10,
                  left: -10,
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.04),
                    ),
                  ),
                ),
                // Top bar sim
                Positioned(
                  top: 4,
                  left: 4,
                  right: 4,
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: activeColor.withValues(alpha: 0.3),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.bar_chart_rounded,
                          size: 8,
                          color: activeColor,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Enterprise',
                        style: GoogleFonts.outfit(
                          fontSize: 5,
                          fontWeight: FontWeight.w900,
                          color: Colors.white60,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '99.9% SLA',
                        style: GoogleFonts.outfit(
                          fontSize: 5,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF48C9B0),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  bottom: 6,
                  left: 6,
                  child: Text(
                    'MAPOTECH',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: Colors.white.withValues(alpha: 0.15),
                      letterSpacing: 2,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(
                      Icons.lock_outline_rounded,
                      size: 12,
                      color: activeColor,
                    ),
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withValues(alpha: 0.06),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Neck
        Container(width: 20, height: 25, color: const Color(0xFF151520)),
        // Stand
        Container(
          width: 80,
          height: 8,
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A25),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        // Shadow
        Container(
          width: 90,
          height: 6,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- VISI KAMI ---
  Widget _buildVisiKamiSection(
    BuildContext context,
    LandingPageState state,
    LandingPageNotifier notifier,
  ) {
    final isMobile = ResponsiveLayout.isMobile(context);
    final isDark = state.appearance == 'dark';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0C),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: const Color(0xFF222225), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: CapsuleGridPainter(
                color: Colors.white.withOpacity(isDark ? 0.02 : 0.015),
              ),
            ),
          ),

          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 24.0 : 64.0,
              vertical: 56.0,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.08),
                      width: 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.bolt_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        notifier.t('vision_badge'),
                        style: GoogleFonts.outfit(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Text(
                    notifier.t('vision_title'),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: isMobile ? 32 : 48,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.1,
                      letterSpacing: -1.0,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 700),
                  child: Text(
                    notifier.t('vision_desc'),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFFB0B0B0),
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 36),

                CustomButton(
                  text: notifier.t('vision_btn'),
                  textColor: Colors.white,
                  isGradient: true,
                  gradientColors: const [Color(0xFFEAB7EE), Color(0xFFD6A4F2)],
                  height: 48,
                  onPressed: () {
                    showSelectionModal(context, ref);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- TIMELINE SECTION ---
  Widget _buildTimelineSection(
    BuildContext context,
    LandingPageState state,
    LandingPageNotifier notifier,
  ) {
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
                notifier.t('timeline_title'),
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
          ),
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
                            text: lang == 'id'
                                ? 'Apa yang Baru di '
                                : 'What\'s New in ',
                            style: GoogleFonts.outfit(
                              fontSize: 36,
                              fontWeight: FontWeight.w900,
                              color: textColor,
                            ),
                          ),
                          TextSpan(
                            text: 'MAPOTECH',
                            style: GoogleFonts.outfit(
                              fontSize: 36,
                              fontWeight: FontWeight.w900,
                              foreground: Paint()
                                ..shader =
                                    const LinearGradient(
                                      colors: [
                                        Color(0xFF48C9B0),
                                        Color(0xFFB577F2),
                                      ],
                                    ).createShader(
                                      const Rect.fromLTWH(
                                        0.0,
                                        0.0,
                                        200.0,
                                        70.0,
                                      ),
                                    ),
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
                      child: Container(
                        width: 2,
                        color: const Color(0xFFE2C4F9),
                      ),
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
          child: _buildGitHubGitCapsule(
            isDark,
            borderColor,
            cardColor,
            textColor,
          ),
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
        border: Border.all(color: const Color(0xFFE2C4F9).withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.history_rounded, color: Color(0xFFB577F2), size: 14),
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

  Widget _buildVersionBadge(
    bool isDark,
    Color borderColor,
    Color cardColor,
    Color textColor,
  ) {
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
              border: Border.all(
                color: const Color(0xFFE2C4F9).withOpacity(0.5),
              ),
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
                border: Border.all(
                  color: const Color(0xFFE2C4F9).withOpacity(0.4),
                ),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F8F5),
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(
                        color: const Color(0xFF48C9B0).withOpacity(0.3),
                      ),
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

  Widget _buildGitHubGitCapsule(
    bool isDark,
    Color borderColor,
    Color cardColor,
    Color textColor,
  ) {
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

class CapsuleGridPainter extends CustomPainter {
  final Color color;
  CapsuleGridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    const capsuleWidth = 90.0;
    const capsuleHeight = 180.0;
    const spacingX = 16.0;
    const spacingY = 16.0;

    for (
      double x = -capsuleWidth;
      x < size.width + capsuleWidth;
      x += capsuleWidth + spacingX
    ) {
      for (
        double y = -capsuleHeight;
        y < size.height + capsuleHeight;
        y += capsuleHeight + spacingY
      ) {
        final rect = Rect.fromLTWH(x, y, capsuleWidth, capsuleHeight);
        final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(32));
        canvas.drawRRect(rrect, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
