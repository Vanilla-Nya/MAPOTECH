import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapotech/features/landing/landing_page_data.dart';
import 'package:mapotech/shared/layouts/responsive_layout.dart';
import 'package:mapotech/shared/widgets/custom_button.dart';
import 'package:mapotech/shared/widgets/floating_settings.dart';
import 'package:mapotech/shared/widgets/ui.dart';

// Import standalone portals
import 'package:mapotech/features/landing/portals/mapotech_home_portal.dart';
import 'package:mapotech/features/pasien/portal/frontend/masyarakat_portal.dart';
import 'package:mapotech/features/dokter/portal/frontend/praktik_mandiri_portal.dart';
import 'package:mapotech/features/apotek/portal/frontend/apotek_portal.dart';
import 'package:mapotech/features/landing/portals/klinik_portal.dart';
import 'package:mapotech/features/landing/portals/puskesmas_portal.dart';
import 'package:mapotech/features/landing/portals/rumah_sakit_portal.dart';
import 'package:mapotech/features/landing/portals/ponkesdes_portal.dart';
import 'package:mapotech/features/landing/portals/posyandu_portal.dart';
import 'package:mapotech/shared/widgets/animated_portal_switcher.dart';
import 'package:mapotech/shared/widgets/auth_modals.dart';
import 'package:mapotech/features/dashboard/dashboard_shell.dart';

class LandingPageLayout extends ConsumerStatefulWidget {
  const LandingPageLayout({super.key});

  @override
  ConsumerState<LandingPageLayout> createState() => _LandingPageLayoutState();
}

class _LandingPageLayoutState extends ConsumerState<LandingPageLayout> {
  final ScrollController _scrollController = ScrollController();
  bool _isScrolled = false;
  bool _isFirstTimeLoading = true;
  final ValueNotifier<double> _loadingProgressNotifier = ValueNotifier<double>(0.0);

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    _startFirstTimeLoad();
  }

  void _startFirstTimeLoad() {
    _loadingProgressNotifier.value = 0.0;
    Timer.periodic(const Duration(milliseconds: 20), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final current = _loadingProgressNotifier.value;
      if (current >= 1.0) {
        timer.cancel();
        Future.delayed(const Duration(milliseconds: 250), () {
          if (mounted) {
            setState(() {
              _isFirstTimeLoading = false;
            });
          }
        });
      } else {
        _loadingProgressNotifier.value = current + 0.015;
      }
    });
  }

  void _scrollListener() {
    if (_scrollController.offset > 20 && !_isScrolled) {
      setState(() => _isScrolled = true);
    } else if (_scrollController.offset <= 20 && _isScrolled) {
      setState(() => _isScrolled = false);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _loadingProgressNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(landingPageProvider);
    final notifier = ref.read(landingPageProvider.notifier);

    if (_isFirstTimeLoading) {
      return MapotechLoadingScreen(
        progressNotifier: _loadingProgressNotifier,
      );
    }

    if (state.isLoggedIn) {
      return const DashboardShell();
    }

    final activeColor = notifier.getPrimaryColor();
    final darkGreenColor = notifier.getSecondaryColor();
    final backgroundColor = notifier.getBackgroundColor();

    // Scroll to top smoothly when the active portal changes
    ref.listen<LandingPageState>(landingPageProvider, (previous, next) {
      if (previous?.activeTab != next.activeTab) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
          );
        }
      }
    });

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      color: backgroundColor,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        drawer: _buildMobileDrawer(state, notifier),
        body: Stack(
          children: [
            // Background subtle gradients
            Positioned(
              top: -150,
              right: -150,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                width: 500,
                height: 500,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: activeColor.withOpacity(0.08),
                ),
              ),
            ),
            Positioned(
              top: 400,
              left: -200,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                width: 600,
                height: 600,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: darkGreenColor.withOpacity(0.04),
                ),
              ),
            ),

            // Main Content
            FadeTransitionOnChange(
              animationKey: '${state.appearance}_${state.language}',
              child: SafeArea(
            top: false,
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                // Custom Navigation Bar
                SliverToBoxAdapter(
                  child: _buildNavbar(context, state, notifier),
                ),

                // Core Landing Body
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      const SizedBox(height: 40),
                      AnimatedPortalSwitcher(
                        switcherKey: state.activeTab,
                        child: Column(
                          key: ValueKey(state.activeTab),
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: _buildActivePortalViews(
                            context,
                            state,
                            notifier,
                          ),
                        ),
                      ),
                      const SizedBox(height: 80),
                      _buildAchievementsSection(context, state, notifier),
                      const SizedBox(height: 80),
                      _buildFooter(context, state, notifier),
                      const SizedBox(height: 40),
                    ]),
                  ),
                ),
              ],
            ),
          ),),

          // Floating settings panel
          const FloatingSettings(),
        ],
      ),
    ),);
  }

  // --- ACTIVE PORTALS ROUTER ---
  List<Widget> _buildActivePortalViews(
    BuildContext context,
    LandingPageState state,
    LandingPageNotifier notifier,
  ) {
    switch (state.activeTab) {
      case 'pasien':
        return [const MasyarakatPortal()];
      case 'dokter':
        return [const PraktikMandiriPortal()];
      case 'apotek':
        return [const ApotekPortal()];
      case 'klinik':
        return [const KlinikPortal()];
      case 'puskesmas':
        return [const PuskesmasPortal()];
      case 'rumahsakit':
        return [const RumahSakitPortal()];
      case 'ponkesdes':
        return [const PonkesdesPortal()];
      case 'posyandu':
        return [const PosyanduPortal()];
      case 'mapotek':
      default:
        return [const MapotechHomePortal()];
    }
  }

  // --- MOBILE DRAWER ---
  Widget _buildMobileDrawer(
    LandingPageState state,
    LandingPageNotifier notifier,
  ) {
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildBrandLogo(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 28),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 40),
              Text(
                notifier.t('entities'),
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  color: const Color(0xFF48C9B0),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  children: notifier.getEntities().map((entity) {
                    final isSelected = state.activeTab == entity.id;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: InkWell(
                        onTap: () {
                          notifier.setActiveTab(entity.id);
                          Navigator.pop(context);
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF48C9B0).withOpacity(0.1)
                                : Colors.grey[50]!,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF48C9B0).withOpacity(0.3)
                                  : Colors.transparent,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                entity.icon,
                                color: isSelected
                                    ? const Color(0xFF1B4F42)
                                    : Colors.grey[600],
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  entity.label,
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                    color: isSelected
                                        ? const Color(0xFF1B4F42)
                                        : Colors.grey[700],
                                  ),
                                ),
                              ),
                              if (entity.isSoon)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF48C9B0,
                                    ).withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    notifier.t('soon'),
                                    style: GoogleFonts.outfit(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w900,
                                      color: const Color(0xFF1B4F42),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const Divider(),
              const SizedBox(height: 16),
              if (state.isLoggedIn) ...[
                // ─── Logged-in user card ───────────────────────────────────
                Builder(
                  builder: (context) {
                    final avatarUrl =
                        state.loggedInUser?['avatar_url'] as String?;
                    final name = state.loggedInName ?? 'User';
                    final role = (state.loggedInRole ?? 'pasien').toUpperCase();
                    final initials = name.isNotEmpty
                        ? name
                              .split(' ')
                              .map((p) => p[0])
                              .take(2)
                              .join('')
                              .toUpperCase()
                        : 'U';
                    final accent = const Color(0xFF48C9B0);

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF7BE5D3), Color(0xFF48C9B0)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: accent.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Avatar circle
                          Container(
                            width: 48,
                            height: 48,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: ClipOval(
                              child: (avatarUrl != null && avatarUrl.isNotEmpty)
                                  ? Image.network(
                                      avatarUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => Center(
                                        child: Text(
                                          initials,
                                          style: GoogleFonts.outfit(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w900,
                                            color: accent,
                                          ),
                                        ),
                                      ),
                                    )
                                  : Center(
                                      child: Text(
                                        initials,
                                        style: GoogleFonts.outfit(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w900,
                                          color: accent,
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
                                Container(
                                  margin: const EdgeInsets.only(top: 3),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    role,
                                    style: GoogleFonts.outfit(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Logout button
                          IconButton(
                            icon: const Icon(
                              Icons.logout_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                            onPressed: () {
                              Navigator.pop(context);
                              notifier.logout();
                            },
                            tooltip: 'Keluar',
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ] else ...[
                CustomButton(
                  text: notifier.t('login'),
                  isSecondary: true,
                  onPressed: () {
                    Navigator.pop(context); // Close drawer
                    showLoginModal(context, ref);
                  },
                ),
                const SizedBox(height: 12),
                CustomButton(
                  text: notifier.t('register'),
                  onPressed: () {
                    Navigator.pop(context); // Close drawer
                    showRegisterModal(context, ref);
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // --- NAVBAR ---
  Widget _buildNavbar(
    BuildContext context,
    LandingPageState state,
    LandingPageNotifier notifier,
  ) {
    final isMobile = ResponsiveLayout.isMobile(context);
    final activeColor = notifier.getPrimaryColor();

    final navBgColor = state.appearance == 'dark'
        ? const Color(0xFF161616).withOpacity(0.9)
        : (state.appearance == 'rev'
              ? const Color(0xFFF0F5FA).withOpacity(0.9)
              : Colors.white.withOpacity(0.9));

    final navBorderColor = state.appearance == 'dark'
        ? const Color(0xFF2C2C2C)
        : (state.appearance == 'rev'
              ? const Color(0xFFE2C4F9)
              : Colors.grey[200]!);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 40,
        vertical: _isScrolled ? 16 : 24,
      ),
      decoration: BoxDecoration(
        color: _isScrolled ? navBgColor : Colors.transparent,
        border: Border(
          bottom: BorderSide(
            color: _isScrolled ? navBorderColor : Colors.transparent,
          ),
        ),
        boxShadow: [
          if (_isScrolled)
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Logo
          _buildBrandLogo(),

          // Desktop capsule selection
          if (!isMobile) _buildNavbarCapsule(state, notifier),

          // Desktop menu or Mobile menu
          if (!isMobile)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Login & Register Buttons
                CustomButton(
                  text: notifier.t('login'),
                  isSecondary: true,
                  height: 44,
                  primaryColor: Colors.transparent,
                  textColor: state.appearance == 'dark'
                      ? Colors.white
                      : (state.appearance == 'rev'
                            ? const Color(0xFF5E1B8C)
                            : const Color(0xFF1B4F42)),
                  borderColor: state.appearance == 'dark'
                      ? const Color(0xFF333333)
                      : (state.appearance == 'rev'
                            ? const Color(0xFFE2C4F9)
                            : const Color(0xFFECECEC)),
                  onPressed: () {
                    showLoginModal(context, ref);
                  },
                ),
                const SizedBox(width: 12),
                CustomButton(
                  text: notifier.t('register'),
                  height: 44,
                  primaryColor: activeColor,
                  textColor: state.appearance == 'dark'
                      ? Colors.black
                      : Colors.white,
                  onPressed: () {
                    showRegisterModal(context, ref);
                  },
                ),
              ],
            )
          else
            // Mobile Menu Drawer Trigger
            IconButton(
              icon: Icon(
                Icons.menu_rounded,
                size: 28,
                color: state.appearance == 'dark'
                    ? Colors.white
                    : const Color(0xFF1B4F42),
              ),
              onPressed: () {
                Scaffold.of(context).openDrawer();
              },
            ),
        ],
      ),
    );
  }

  Widget _buildNavbarCapsule(
    LandingPageState state,
    LandingPageNotifier notifier,
  ) {
    final isDark = state.appearance == 'dark';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1E1E1E)
            : const Color(0xFFF3EEFC).withOpacity(0.4),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: isDark
              ? const Color(0xFF2C2C2C)
              : const Color(0xFFE2C4F9).withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: notifier.getEntities().map((entity) {
          final isSelected = state.activeTab == entity.id;

          Color textColor;
          Color iconColor;
          Color bgColor;
          FontWeight fontWeight;

          if (isSelected) {
            bgColor = isDark ? const Color(0xFF2E2E2E) : Colors.white;
            textColor = isDark
                ? Colors.white
                : (state.appearance == 'rev'
                      ? const Color(0xFF5E1B8C)
                      : const Color(0xFF1B4F42));
            iconColor = textColor;
            fontWeight = FontWeight.w900;
          } else {
            bgColor = Colors.transparent;
            textColor = isDark ? Colors.grey[400]! : Colors.grey[700]!;
            iconColor = textColor.withOpacity(0.7);
            fontWeight = FontWeight.w600;
          }

          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            child: InkWell(
              onTap: () {
                notifier.setActiveTab(entity.id);
              },
              borderRadius: BorderRadius.circular(100),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(100),
                  boxShadow: [
                    if (isSelected)
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(entity.icon, size: 13, color: iconColor),
                    const SizedBox(width: 5),
                    Text(
                      isSelected ? entity.label.toUpperCase() : entity.label,
                      style: GoogleFonts.outfit(
                        fontSize: 9,
                        fontWeight: fontWeight,
                        color: textColor,
                      ),
                    ),
                    if (entity.isSoon)
                      Container(
                        margin: const EdgeInsets.only(left: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF48C9B0).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          notifier.t('soon').toUpperCase(),
                          style: GoogleFonts.outfit(
                            fontSize: 6,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF1B4F42),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBrandLogo() {
    final notifier = ref.read(landingPageProvider.notifier);
    final activeColor = notifier.getPrimaryColor();
    final darkGreenColor = notifier.getSecondaryColor();

    return InkWell(
      onTap: () => notifier.setActiveTab('mapotek'),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/logo.png',
              width: 38,
              height: 38,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [activeColor, darkGreenColor],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Icon(
                  Icons.healing_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 12),
            ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: [darkGreenColor, activeColor],
              ).createShader(bounds),
              child: Text(
                'MAPOTECH',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- ACHIEVEMENTS / AWARDS ---
  Widget _buildAchievementsSection(
    BuildContext context,
    LandingPageState state,
    LandingPageNotifier notifier,
  ) {
    final achievements = notifier.getAchievements();
    final isMobile = ResponsiveLayout.isMobile(context);
    final textColor = notifier.getTextColor();
    final bodyTextColor = notifier.getBodyTextColor();
    final cardColor = notifier.getCardColor();
    final borderColor = notifier.getBorderColor();
    final isDark = state.appearance == 'dark';
    final lang = state.language;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
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
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      notifier.t('achievements').toUpperCase(),
                      style: GoogleFonts.outfit(
                        fontSize: 9,
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
                      text: lang == 'id' ? 'Pencapaian ' : 'Achievements of ',
                      style: GoogleFonts.outfit(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: textColor,
                      ),
                    ),
                    TextSpan(
                      text: 'MAPOTECH',
                      style: GoogleFonts.outfit(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        foreground: Paint()
                          ..shader =
                              const LinearGradient(
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
                lang == 'id'
                    ? 'Pengakuan dan keunggulan dalam pengembangan teknologi medis.'
                    : 'Recognition and excellence in medical technology development.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: bodyTextColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 48),

        if (isMobile) ...[
          _buildAchievementCard(
            0,
            achievements[0],
            isDark,
            borderColor,
            cardColor,
            textColor,
            bodyTextColor,
          ),
          const SizedBox(height: 24),
          _buildAchievementCard(
            1,
            achievements[1],
            isDark,
            borderColor,
            cardColor,
            textColor,
            bodyTextColor,
          ),
        ] else ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildAchievementCard(
                  0,
                  achievements[0],
                  isDark,
                  borderColor,
                  cardColor,
                  textColor,
                  bodyTextColor,
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: _buildAchievementCard(
                  1,
                  achievements[1],
                  isDark,
                  borderColor,
                  cardColor,
                  textColor,
                  bodyTextColor,
                ),
              ),
            ],
          ),
        ],
      ],
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
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          index == 0
              ? buildCertificate1(isDark, borderColor, cardColor)
              : buildCertificate2(isDark, borderColor, cardColor),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  achievement.title,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  achievement.description,
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
  }

  Widget buildCertificate1(bool isDark, Color borderColor, Color cardColor) {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFDCDCDC), Color(0xFFF5F5F5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: Stack(
        children: [
          Positioned(
            left: -40,
            top: -40,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.black.withOpacity(0.03),
                  width: 8,
                ),
              ),
            ),
          ),
          Positioned(
            right: -30,
            bottom: -30,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.black.withOpacity(0.03),
                  width: 8,
                ),
              ),
            ),
          ),
          Center(
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

          Positioned(
            bottom: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Colors.orange,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.emoji_events_rounded,
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
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                'LIHAT SERTIFIKAT',
                style: GoogleFonts.outfit(
                  fontSize: 7,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildCertificate2(bool isDark, Color borderColor, Color cardColor) {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE5E8E8), Color(0xFFF2F4F4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: Stack(
        children: [
          Positioned(
            left: -20,
            bottom: -20,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.blue.withOpacity(0.03),
                  width: 6,
                ),
              ),
            ),
          ),
          Center(
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

          Positioned(
            bottom: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Colors.blueAccent,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.workspace_premium_rounded,
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
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                'LIHAT SERTIFIKAT',
                style: GoogleFonts.outfit(
                  fontSize: 7,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- FOOTER ---
  Widget _buildFooter(
    BuildContext context,
    LandingPageState state,
    LandingPageNotifier notifier,
  ) {
    final isMobile = ResponsiveLayout.isMobile(context);
    final borderColor = notifier.getBorderColor();
    final bodyTextColor = notifier.getBodyTextColor();
    final textColor = notifier.getTextColor();
    final activeColor = notifier.getPrimaryColor();
    final isDark = state.appearance == 'dark';
    final lang = state.language;

    final sitemap = notifier.getSitemap();

    Widget brandColumn = Column(
      crossAxisAlignment: isMobile
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/logo.png',
              width: 32,
              height: 32,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [activeColor, notifier.getSecondaryColor()],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Icon(
                  Icons.healing_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'MAPOTECH',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: textColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Layanan Terpadu untuk Setiap Komunitas',
          textAlign: isMobile ? TextAlign.center : TextAlign.start,
          style: GoogleFonts.outfit(
            fontSize: 11,
            color: bodyTextColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: isMobile
              ? MainAxisAlignment.center
              : MainAxisAlignment.start,
          children: [
            _buildPlatformIconButton(
              Icons.phone_iphone_rounded,
              isDark,
              borderColor,
            ),
            const SizedBox(width: 8),
            _buildPlatformIconButton(
              Icons.language_rounded,
              isDark,
              borderColor,
            ),
            const SizedBox(width: 8),
            _buildPlatformIconButton(
              Icons.computer_rounded,
              isDark,
              borderColor,
            ),
          ],
        ),
      ],
    );

    Widget sitemapGrid = Wrap(
      spacing: isMobile ? 32.0 : 48.0,
      runSpacing: 24.0,
      alignment: isMobile ? WrapAlignment.center : WrapAlignment.start,
      children: sitemap.map((column) {
        return SizedBox(
          width: isMobile ? 130 : 140,
          child: Column(
            crossAxisAlignment: isMobile
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: [
              Text(
                column['title'] as String,
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: textColor.withOpacity(0.5),
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 16),
              ...((column['items'] as List).map((item) {
                final label = item['label'] as String;
                final tab = item['tab'] as String;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: InkWell(
                    onTap: () {
                      if (tab.isNotEmpty) {
                        notifier.setActiveTab(tab);
                      }
                    },
                    borderRadius: BorderRadius.circular(4),
                    child: Text(
                      label,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: bodyTextColor,
                      ),
                    ),
                  ),
                );
              })),
            ],
          ),
        );
      }).toList(),
    );

    Widget bottomBar = Column(
      children: [
        const SizedBox(height: 24),
        Container(height: 1.0, color: borderColor),
        const SizedBox(height: 24),
        isMobile
            ? Column(
                children: [
                  Text(
                    lang == 'id'
                        ? '© 2026 MAPOTECH DIGITAL SYSTEM - HAK CIPTA DILINDUNGI'
                        : '© 2026 MAPOTECH DIGITAL SYSTEM - ALL RIGHTS RESERVED',
                    style: GoogleFonts.outfit(
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      color: bodyTextColor.withOpacity(0.6),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFF27C93F),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        lang == 'id'
                            ? 'STATUS JARINGAN: OPERASIONAL'
                            : 'NETWORK STATUS: OPERATIONAL',
                        style: GoogleFonts.outfit(
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          color: bodyTextColor.withOpacity(0.6),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    lang == 'id'
                        ? '© 2026 MAPOTECH DIGITAL SYSTEM - HAK CIPTA DILINDUNGI'
                        : '© 2026 MAPOTECH DIGITAL SYSTEM - ALL RIGHTS RESERVED',
                    style: GoogleFonts.outfit(
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      color: bodyTextColor.withOpacity(0.6),
                      letterSpacing: 0.5,
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFF27C93F),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        lang == 'id'
                            ? 'STATUS JARINGAN: OPERASIONAL'
                            : 'NETWORK STATUS: OPERATIONAL',
                        style: GoogleFonts.outfit(
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          color: bodyTextColor.withOpacity(0.6),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
      ],
    );

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 60),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: borderColor, width: 1.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          isMobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    brandColumn,
                    const SizedBox(height: 48),
                    sitemapGrid,
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: brandColumn),
                    const SizedBox(width: 48),
                    Expanded(flex: 7, child: sitemapGrid),
                  ],
                ),
          bottomBar,
        ],
      ),
    );
  }

  Widget _buildPlatformIconButton(
    IconData icon,
    bool isDark,
    Color borderColor,
  ) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Center(
        child: Icon(
          icon,
          size: 16,
          color: isDark ? Colors.white70 : Colors.grey[600],
        ),
      ),
    );
  }
}

class FadeTransitionOnChange extends StatefulWidget {
  final Widget child;
  final String animationKey;

  const FadeTransitionOnChange({
    super.key,
    required this.child,
    required this.animationKey,
  });

  @override
  State<FadeTransitionOnChange> createState() => _FadeTransitionOnChangeState();
}

class _FadeTransitionOnChangeState extends State<FadeTransitionOnChange>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  late String _currentKey;

  @override
  void initState() {
    super.initState();
    _currentKey = widget.animationKey;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
    _controller.forward(from: 1.0);
  }

  @override
  void didUpdateWidget(covariant FadeTransitionOnChange oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animationKey != _currentKey) {
      _currentKey = widget.animationKey;
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacityAnimation,
      child: widget.child,
    );
  }
}
