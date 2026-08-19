import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mapotech/features/landing/landing_page_data.dart';
import 'package:mapotech/shared/layouts/responsive_layout.dart';

/// Helper to convert Google Drive sharing link to a direct high-res image CDN URL
String? getDriveImageDirectUrl(String driveUrl, {int width = 1200}) {
  final regExp = RegExp(r'(?:/d/|id=)([a-zA-Z0-9_-]+)');
  final match = regExp.firstMatch(driveUrl);
  if (match != null && match.groupCount >= 1) {
    final fileId = match.group(1);
    return 'https://lh3.googleusercontent.com/d/$fileId=w$width';
  }
  return null;
}

class AchievementsCarouselSection extends StatefulWidget {
  final List<AchievementItem> achievements;
  final bool isDark;
  final Color borderColor;
  final Color cardColor;
  final Color textColor;
  final Color bodyTextColor;
  final Color primaryColor;
  final String language;
  final String sectionTitle;
  final String sectionSubtitle;
  final String badgeText;

  const AchievementsCarouselSection({
    super.key,
    required this.achievements,
    required this.isDark,
    required this.borderColor,
    required this.cardColor,
    required this.textColor,
    required this.bodyTextColor,
    required this.primaryColor,
    required this.language,
    required this.sectionTitle,
    required this.sectionSubtitle,
    required this.badgeText,
  });

  @override
  State<AchievementsCarouselSection> createState() =>
      _AchievementsCarouselSectionState();
}

class _AchievementsCarouselSectionState
    extends State<AchievementsCarouselSection> {
  PageController? _pageController;
  bool? _lastIsMobile;
  Timer? _timer;
  int _currentPageIndex = 0;
  bool _isHovered = false;
  static const int _virtualBase = 600; // Large multiple of achievements.length

  @override
  void initState() {
    super.initState();
    _currentPageIndex = 0;
    _startTimer();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final isMobile = ResponsiveLayout.isMobile(context);
    if (_lastIsMobile != isMobile) {
      _lastIsMobile = isMobile;
      final currentVirtual = _pageController != null && _pageController!.hasClients
          ? _pageController!.page?.round() ?? _virtualBase
          : _virtualBase;
      _pageController?.dispose();
      _pageController = PageController(
        initialPage: currentVirtual,
        viewportFraction: isMobile ? 1.0 : 0.5,
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController?.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 7), (timer) {
      if (!_isHovered && mounted && _pageController != null && _pageController!.hasClients) {
        _pageController!.nextPage(
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  void _next() {
    if (_pageController != null && _pageController!.hasClients) {
      _pageController!.nextPage(
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _prev() {
    if (_pageController != null && _pageController!.hasClients) {
      _pageController!.previousPage(
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _showCertificateDialog(AchievementItem achievement, int index) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.75),
      builder: (ctx) => CertificateDetailModal(
        achievement: achievement,
        index: index,
        isDark: widget.isDark,
        language: widget.language,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveLayout.isMobile(context);
    final totalItems = widget.achievements.length;
    if (totalItems == 0) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Section Header
        Center(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF5E7),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                    color: const Color(0xFFF5B041).withOpacity(0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.emoji_events_outlined,
                      color: Color(0xFFF5B041),
                      size: 15,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.badgeText.toUpperCase(),
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        color: const Color(0xFFF5B041),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: widget.language == 'id'
                          ? 'Pencapaian '
                          : 'Achievements of ',
                      style: GoogleFonts.outfit(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: widget.textColor,
                      ),
                    ),
                    TextSpan(
                      text: 'MAPOTECH',
                      style: GoogleFonts.outfit(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        foreground: Paint()
                          ..shader = const LinearGradient(
                            colors: [Color(0xFF48C9B0), Color(0xFFB577F2)],
                          ).createShader(
                            const Rect.fromLTWH(0.0, 0.0, 200.0, 70.0),
                          ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.sectionSubtitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: widget.bodyTextColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 40),

        // Carousel Container with Nav Arrows
        MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // PageView
              SizedBox(
                height: 400,
                child: PageView.builder(
                  controller: _pageController,
                  padEnds: false,
                  physics: const BouncingScrollPhysics(),
                  onPageChanged: (idx) {
                    setState(() {
                      _currentPageIndex = idx % totalItems;
                    });
                  },
                  itemBuilder: (context, virtualIdx) {
                    final realIdx = virtualIdx % totalItems;
                    final achievement = widget.achievements[realIdx];

                    return Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 4 : 12,
                      ),
                      child: _buildAchievementCard(
                        realIdx,
                        achievement,
                        widget.isDark,
                        widget.borderColor,
                        widget.cardColor,
                        widget.textColor,
                        widget.bodyTextColor,
                      ),
                    );
                  },
                ),
              ),

              // Left Nav Arrow
              Positioned(
                left: isMobile ? -6 : -18,
                child: _buildNavButton(
                  icon: Icons.chevron_left_rounded,
                  onTap: _prev,
                ),
              ),

              // Right Nav Arrow
              Positioned(
                right: isMobile ? -6 : -18,
                child: _buildNavButton(
                  icon: Icons.chevron_right_rounded,
                  onTap: _next,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 28),

        // Pagination Dots & Timer Progress Indicator
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (int i = 0; i < totalItems; i++) ...[
              GestureDetector(
                onTap: () {
                  if (_pageController != null && _pageController!.hasClients) {
                    final currentVirtual = _pageController!.page?.round() ?? _virtualBase;
                    final currentModulo = currentVirtual % totalItems;
                    final diff = i - currentModulo;
                    _pageController!.animateToPage(
                      currentVirtual + diff,
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeInOutCubic,
                    );
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 350),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentPageIndex == i ? 28 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentPageIndex == i
                        ? const Color(0xFF48C9B0)
                        : (widget.isDark
                            ? Colors.white.withOpacity(0.2)
                            : Colors.black.withOpacity(0.12)),
                    borderRadius: BorderRadius.circular(100),
                    boxShadow: _currentPageIndex == i
                        ? [
                            BoxShadow(
                              color: const Color(0xFF48C9B0).withOpacity(0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildNavButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(100),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: widget.isDark
                ? const Color(0xFF1E293B).withOpacity(0.9)
                : Colors.white.withOpacity(0.9),
            shape: BoxShape.circle,
            border: Border.all(
              color: widget.isDark
                  ? Colors.white.withOpacity(0.15)
                  : Colors.black.withOpacity(0.08),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            icon,
            size: 24,
            color: widget.isDark ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _buildAchievementCard(
    int index,
    AchievementItem achievement,
    bool isDark,
    Color borderColor,
    Color cardColor,
    Color textColor,
    Color bodyTextColor,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showCertificateDialog(achievement, index),
          hoverColor: Colors.black.withOpacity(0.02),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Certificate Preview Header
              _buildCertificateHeader(index, achievement, isDark, borderColor, cardColor),

              // Card Description & Click hint
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            achievement.title,
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: textColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            achievement.description,
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: bodyTextColor,
                              height: 1.35,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          const Icon(
                            Icons.zoom_in_rounded,
                            size: 14,
                            color: Color(0xFF48C9B0),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            widget.language == 'id'
                                ? 'Klik untuk memperbesar sertifikat'
                                : 'Click to view full certificate',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF48C9B0),
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
      ),
    );
  }

  Widget _buildCertificateHeader(
    int index,
    AchievementItem achievement,
    bool isDark,
    Color borderColor,
    Color cardColor,
  ) {
    final directImageUrl = getDriveImageDirectUrl(achievement.link, width: 900);

    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Real Google Drive Certificate Image
          if (directImageUrl != null)
            Image.network(
              directImageUrl,
              fit: BoxFit.contain,
              alignment: Alignment.center,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Center(
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                      color: const Color(0xFF48C9B0),
                    ),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                // Fallback to rendered template if image network fails
                return _buildFallbackTemplate(index, isDark, borderColor, cardColor);
              },
            )
          else
            _buildFallbackTemplate(index, isDark, borderColor, cardColor),

          // 2. Bottom Badge & View Pill Overlay
          Positioned(
            bottom: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: index == 0
                    ? Colors.orange
                    : index == 1
                        ? Colors.blueAccent
                        : const Color(0xFF5B2C6F),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: Icon(
                achievement.icon,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),

          Positioned(
            bottom: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.65),
                borderRadius: BorderRadius.circular(100),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 0.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.fullscreen_rounded,
                    color: Colors.white,
                    size: 12,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'LIHAT SERTIFIKAT',
                    style: GoogleFonts.outfit(
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackTemplate(
    int index,
    bool isDark,
    Color borderColor,
    Color cardColor,
  ) {
    if (index == 0) {
      return buildCertificate1(isDark, borderColor, cardColor);
    } else if (index == 1) {
      return buildCertificate2(isDark, borderColor, cardColor);
    } else {
      return buildCertificate3(isDark, borderColor, cardColor);
    }
  }

  // --- CERTIFICATE 1: SEMESTER 3 ---
  Widget buildCertificate1(bool isDark, Color borderColor, Color cardColor) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFDCDCDC), Color(0xFFF5F5F5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Diberikan kepada kelompok dengan judul :',
                style: GoogleFonts.outfit(
                  fontSize: 8,
                  fontWeight: FontWeight.w600,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'SISTEM INFORMASI PRAKTEK\nDOKTER MANDIRI',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: Colors.black87,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Sebagai :',
                style: GoogleFonts.outfit(
                  fontSize: 8,
                  fontWeight: FontWeight.w600,
                  color: Colors.black54,
                ),
              ),
              Text(
                'JUARA 1',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                  letterSpacing: 1.0,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B4F42),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'APLIKASI',
                  style: GoogleFonts.outfit(
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'SEMESTER 3',
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Dalam Acara TIF EXHIBITION\nSemester Ganjil Tahun Ajaran 2025/2026 Program Studi\nTeknik Informatika Jurusan Teknologi Informasi\nPoliteknik Negeri Jember',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 6,
                  fontWeight: FontWeight.bold,
                  color: Colors.black54,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- CERTIFICATE 2: SEMESTER 1 & 2 POSTER ---
  Widget buildCertificate2(bool isDark, Color borderColor, Color cardColor) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE5E8E8), Color(0xFFF2F4F4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Diberikan Kepada Kelompok Dengan Judul :',
                style: GoogleFonts.outfit(
                  fontSize: 8,
                  fontWeight: FontWeight.w600,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'MAPOTEK',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF1B4F42),
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Sebagai',
                style: GoogleFonts.outfit(
                  fontSize: 8,
                  fontWeight: FontWeight.w600,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'JUARA 1 POSTER',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF1E3F66),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Dalam Acara TIF EXHIBITION\nSemester Genap Tahun Ajaran 2024/2025\nProgram Studi Teknik Informatika\nJurusan Teknologi Informasi\nPoliteknik Negeri Jember',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 7,
                  fontWeight: FontWeight.bold,
                  color: Colors.black54,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- CERTIFICATE 3: SEMESTER 4 WINNER ---
  Widget buildCertificate3(bool isDark, Color borderColor, Color cardColor) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE8EEF5), Color(0xFFF3F0FA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Diberikan Kepada Kelompok Dengan Judul :',
                style: GoogleFonts.outfit(
                  fontSize: 8,
                  fontWeight: FontWeight.w600,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'MAPOTECH',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF2C3E50),
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Sebagai :',
                style: GoogleFonts.outfit(
                  fontSize: 8,
                  fontWeight: FontWeight.w600,
                  color: Colors.black54,
                ),
              ),
              Text(
                'JUARA 1',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF1B4F42),
                  letterSpacing: 1.0,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                        colors: [Color(0xFF0E6655), Color(0xFF5B2C6F)],
                      ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'SISTEM & APLIKASI WEB',
                  style: GoogleFonts.outfit(
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'SEMESTER 4',
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Dalam Acara TIF EXHIBITION\nSemester Genap Tahun Ajaran 2025/2026 Program Studi\nTeknik Informatika Jurusan Teknologi Informasi\nPoliteknik Negeri Jember',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 6,
                  fontWeight: FontWeight.bold,
                  color: Colors.black54,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// FULL-SIZE CERTIFICATE MODAL
// ==========================================
class CertificateDetailModal extends StatelessWidget {
  final AchievementItem achievement;
  final int index;
  final bool isDark;
  final String language;

  const CertificateDetailModal({
    super.key,
    required this.achievement,
    required this.index,
    required this.isDark,
    required this.language,
  });

  Future<void> _openDriveLink(BuildContext context) async {
    final uri = Uri.parse(achievement.link);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              language == 'id'
                  ? 'Gagal membuka tautan Google Drive.'
                  : 'Unable to open Google Drive link.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveLayout.isMobile(context);
    final directImageUrl = getDriveImageDirectUrl(achievement.link, width: 1600);

    // Certificate metadata based on index
    final String semesterText = index == 0
        ? 'SEMESTER 3'
        : index == 1
            ? 'SEMESTER 1 & 2'
            : 'SEMESTER 4';

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(
          horizontal: isMobile ? 12 : 32,
          vertical: 20,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960, maxHeight: 720),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.15)
                    : Colors.black.withOpacity(0.08),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 36,
                  offset: const Offset(0, 18),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Modal Header with Close Button
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 18, 16, 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5B041).withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.workspace_premium_rounded,
                              color: Color(0xFFF5B041),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                language == 'id'
                                    ? 'Sertifikat Penghargaan Asli'
                                    : 'Original Certificate of Achievement',
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              Text(
                                '$semesterText • JUARA 1',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF48C9B0),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withOpacity(0.1)
                                : Colors.black.withOpacity(0.05),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1),

                // Large Official Certificate Display Canvas
                Expanded(
                  child: Container(
                    width: double.infinity,
                    margin: EdgeInsets.all(isMobile ? 12 : 20),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF020617) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: const Color(0xFFD4AF37).withOpacity(0.5),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: directImageUrl != null
                        ? InteractiveViewer(
                            panEnabled: true,
                            minScale: 0.8,
                            maxScale: 3.5,
                            child: Image.network(
                              directImageUrl,
                              fit: BoxFit.contain,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CircularProgressIndicator(
                                        strokeWidth: 3,
                                        value: loadingProgress.expectedTotalBytes != null
                                            ? loadingProgress.cumulativeBytesLoaded /
                                                loadingProgress.expectedTotalBytes!
                                            : null,
                                        color: const Color(0xFF48C9B0),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        language == 'id'
                                            ? 'Memuat sertifikat dari Google Drive...'
                                            : 'Loading certificate from Google Drive...',
                                        style: GoogleFonts.outfit(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? Colors.white70 : Colors.black54,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) {
                                return Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.broken_image_rounded,
                                          size: 48,
                                          color: Colors.grey,
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          language == 'id'
                                              ? 'Tidak dapat memuat gambar pratinjau langsung.'
                                              : 'Unable to load direct image preview.',
                                          style: GoogleFonts.outfit(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: isDark ? Colors.white70 : Colors.black54,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        ElevatedButton.icon(
                                          onPressed: () => _openDriveLink(context),
                                          icon: const Icon(Icons.open_in_new_rounded, size: 16),
                                          label: Text(
                                            language == 'id'
                                                ? 'Buka di Google Drive'
                                                : 'Open in Google Drive',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),

                const Divider(height: 1),

                // Modal Footer Actions
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 16 : 24,
                    vertical: 14,
                  ),
                  child: isMobile
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ElevatedButton.icon(
                              onPressed: () => _openDriveLink(context),
                              icon: const Icon(Icons.open_in_new_rounded, size: 16),
                              label: Text(
                                language == 'id'
                                    ? 'Buka di Google Drive'
                                    : 'Open in Google Drive',
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1B4F42),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                elevation: 0,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: Text(
                                language == 'id' ? 'Tutup' : 'Close',
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white70 : Colors.black54,
                                ),
                              ),
                            ),
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.verified_rounded,
                                  size: 16,
                                  color: Color(0xFF48C9B0),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  language == 'id'
                                      ? 'Dokumen asli terverifikasi dari Google Drive'
                                      : 'Original verified document from Google Drive',
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white54 : Colors.black45,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                OutlinedButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(
                                      color: isDark
                                          ? Colors.white.withOpacity(0.2)
                                          : Colors.black.withOpacity(0.15),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: Text(
                                    language == 'id' ? 'Tutup' : 'Close',
                                    style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                ElevatedButton.icon(
                                  onPressed: () => _openDriveLink(context),
                                  icon: const Icon(
                                    Icons.open_in_new_rounded,
                                    size: 16,
                                  ),
                                  label: Text(
                                    language == 'id'
                                        ? 'Buka di Google Drive'
                                        : 'Open in Google Drive',
                                    style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1B4F42),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 0,
                                  ),
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
      ),
    );
  }
}
