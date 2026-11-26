import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapotech/features/landing/landing_page_data.dart';

class MapotechLoadingScreen extends ConsumerStatefulWidget {
  final ValueNotifier<double> progressNotifier;
  final VoidCallback? onComplete;

  const MapotechLoadingScreen({
    super.key,
    required this.progressNotifier,
    this.onComplete,
  });

  @override
  ConsumerState<MapotechLoadingScreen> createState() => _MapotechLoadingScreenState();
}

class _MapotechLoadingScreenState extends ConsumerState<MapotechLoadingScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  
  int _faqIndex = 0;
  Timer? _faqTimer;
  double _currentProgress = 0.0;

  // FAQ Data for Indonesian and English
  final List<Map<String, String>> _faqId = [
    {
      'q': 'Apa itu MAPOTECH?',
      'a': 'Medical Application Platform for Operational Technology and Connected Healthcare, platform ekosistem kesehatan digital modern.'
    },
    {
      'q': 'Apakah data saya terintegrasi dengan SatuSehat?',
      'a': 'Ya, MAPOTECH terintegrasi secara resmi dengan SatuSehat Kemenkes untuk menjamin keamanan & kemudahan sinkronisasi data.'
    },
    {
      'q': 'Peran apa saja yang didukung oleh MAPOTECH?',
      'a': 'MAPOTECH mendukung peran Masyarakat (Pasien), Praktik Mandiri Dokter, Apotek, Klinik, Puskesmas, dan Rumah Sakit.'
    },
    {
      'q': 'Bagaimana cara mendaftar akun?',
      'a': 'Klik tombol "DAFTAR" di pojok kanan atas, pilih peran Anda, dan isi formulir pendaftaran secara lengkap.'
    },
    {
      'q': 'Apakah ada biaya untuk menggunakan platform ini?',
      'a': 'MAPOTECH menyediakan akses gratis untuk fitur-fitur dasar masyarakat dan tarif terjangkau bagi operasional entitas kesehatan.'
    }
  ];

  final List<Map<String, String>> _faqEn = [
    {
      'q': 'What is MAPOTECH?',
      'a': 'Medical Application Platform for Operational Technology and Connected Healthcare, a modern digital health ecosystem.'
    },
    {
      'q': 'Is my data integrated with SatuSehat?',
      'a': 'Yes, MAPOTECH is officially integrated with Kemenkes SatuSehat to guarantee secure and easy data synchronization.'
    },
    {
      'q': 'What roles are supported by MAPOTECH?',
      'a': 'MAPOTECH supports Patients (Masyarakat), Independent Doctors, Pharmacies (Apotek), Clinics, Puskesmas, and Hospitals.'
    },
    {
      'q': 'How do I register an account?',
      'a': 'Click the "REGISTER" button on the top right, select your role, and complete the registration form.'
    },
    {
      'q': 'Are there any fees to use the platform?',
      'a': 'MAPOTECH provides free access for basic patient features and affordable plans for health entities operational needs.'
    }
  ];

  @override
  void initState() {
    super.initState();
    
    // Background logo pulse animation
    _pulseController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 0.08, end: 0.20).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Initial progress value
    _currentProgress = widget.progressNotifier.value;
    widget.progressNotifier.addListener(_onProgressChanged);

    // FAQ rotation timer (every 1.2 seconds)
    _faqTimer = Timer.periodic(const Duration(milliseconds: 1200), (timer) {
      if (mounted) {
        setState(() {
          final isId = ref.read(landingPageProvider).language == 'id';
          final faqList = isId ? _faqId : _faqEn;
          _faqIndex = (_faqIndex + 1) % faqList.length;
        });
      }
    });
  }

  void _onProgressChanged() {
    if (mounted) {
      setState(() {
        _currentProgress = widget.progressNotifier.value;
      });
      if (_currentProgress >= 1.0) {
        widget.onComplete?.call();
      }
    }
  }

  @override
  void dispose() {
    widget.progressNotifier.removeListener(_onProgressChanged);
    _pulseController.dispose();
    _faqTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(landingPageProvider);
    final notifier = ref.read(landingPageProvider.notifier);

    final isDark = state.appearance == 'dark';
    final primaryColor = notifier.getPrimaryColor();
    final secondaryColor = notifier.getSecondaryColor();
    final backgroundColor = notifier.getBackgroundColor();
    final textColor = notifier.getTextColor();
    final bodyTextColor = notifier.getBodyTextColor();

    final isId = state.language == 'id';
    final faqList = isId ? _faqId : _faqEn;
    final currentFaq = faqList[_faqIndex];

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          // 1. Watermarked Background Logo (with Pulsing Effect)
          Center(
            child: AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Opacity(
                  opacity: _pulseAnimation.value,
                  child: Transform.scale(
                    scale: 1.0 + (_pulseAnimation.value * 0.3),
                    child: Image.asset(
                      'assets/images/logo.png',
                      width: 280,
                      height: 280,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        // Fallback icon if logo image is not found or fails to load
                        return Icon(
                          Icons.local_hospital_rounded,
                          size: 150,
                          color: primaryColor,
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),

          // Background subtle gradients to feel premium
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primaryColor.withValues(alpha: 0.06),
              ),
            ),
          ),
          Positioned(
            bottom: -150,
            left: -150,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: secondaryColor.withValues(alpha: 0.04),
              ),
            ),
          ),

          // Main Layout Wrapper
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 2. Rotating FAQ Card (Top)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 10),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(100),
                            border: Border.all(
                              color: primaryColor.withValues(alpha: 0.25),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.lightbulb_rounded,
                                color: primaryColor,
                                size: 14,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isId ? 'EDUKASI & FAQ' : 'EDUCATION & FAQ',
                                style: GoogleFonts.outfit(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: primaryColor,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 600),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (Widget child, Animation<double> animation) {
                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0.0, 0.15),
                                end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            ),
                          );
                        },
                        child: Container(
                          key: ValueKey<int>(_faqIndex),
                          padding: const EdgeInsets.all(20.0),
                          decoration: BoxDecoration(
                            color: isDark 
                                ? const Color(0xFF1E293B).withValues(alpha: 0.85)
                                : const Color(0xFFF8FAFC).withValues(alpha: 0.95),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isDark 
                                  ? Colors.white.withValues(alpha: 0.05)
                                  : primaryColor.withValues(alpha: 0.15),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: isDark 
                                    ? Colors.black.withValues(alpha: 0.2)
                                    : Colors.black.withValues(alpha: 0.05),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                currentFaq['q'] ?? '',
                                style: GoogleFonts.outfit(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : textColor,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                currentFaq['a'] ?? '',
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  height: 1.4,
                                  fontWeight: FontWeight.w500,
                                  color: isDark 
                                      ? const Color(0xFFF3F4F6).withValues(alpha: 0.75)
                                      : bodyTextColor.withValues(alpha: 0.8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  // 3. Middle Decorative Space
                  const Spacer(),

                  // 4. Progress Indicator and Loading text (Bottom)
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isId ? 'SEDANG MEMUAT...' : 'LOADING...',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: bodyTextColor.withValues(alpha: 0.5),
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // Custom Progress Bar
                      Container(
                        height: 12,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[200],
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(
                            color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey[300]!,
                            width: 1,
                          ),
                        ),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final maxWidth = constraints.maxWidth;
                            final targetWidth = maxWidth * _currentProgress.clamp(0.0, 1.0);
                            
                            return Align(
                              alignment: Alignment.centerLeft,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                curve: Curves.easeOutCubic,
                                width: targetWidth,
                                height: double.infinity,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [secondaryColor, primaryColor],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                                  borderRadius: BorderRadius.circular(100),
                                  boxShadow: [
                                    BoxShadow(
                                      color: primaryColor.withValues(alpha: 0.35),
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                      
                      // Progress percentage text
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isId ? 'Sistem Terintegrasi SatuSehat' : 'SatuSehat Integrated System',
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: primaryColor.withValues(alpha: 0.8),
                            ),
                          ),
                          Text(
                            '${(_currentProgress * 100).toInt()}%',
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: primaryColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
