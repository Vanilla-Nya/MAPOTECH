import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapotech/features/apotek/dashboard/frontend/apotek_pesanan.dart';
import 'package:mapotech/features/landing/landing_page_data.dart';
import 'package:mapotech/shared/supabase_service.dart';
import 'dart:ui' as ui;
import 'package:mapotech/shared/widgets/page_tutorial_data.dart';
import 'package:mapotech/shared/widgets/page_tutorial_dialog.dart';
import 'package:mapotech/shared/widgets/animated_portal_switcher.dart';
// Import split widgets and views
import 'package:mapotech/features/dashboard/widgets/dashboard_drawer.dart';
import 'package:mapotech/features/pasien/dashboard/frontend/pasien_dashboard.dart';
import 'package:mapotech/features/pasien/dashboard/frontend/pasien_dokter_search.dart';
import 'package:mapotech/features/pasien/dashboard/frontend/pasien_apotek_search.dart';
import 'package:mapotech/features/pasien/dashboard/frontend/pasien_history.dart';
import 'package:mapotech/features/pasien/dashboard/frontend/pasien_prescription.dart';
import 'package:mapotech/features/pasien/dashboard/frontend/pasien_profile.dart';
import 'package:mapotech/features/pasien/dashboard/frontend/pasien_settings.dart';
import 'package:mapotech/features/dokter/dashboard/frontend/dokter_dashboard.dart';
import 'package:mapotech/features/dokter/dashboard/frontend/dokter_pasien.dart';
import 'package:mapotech/features/dokter/dashboard/frontend/dokter_obat.dart';
import 'package:mapotech/features/dokter/dashboard/frontend/dokter_antrian.dart';
import 'package:mapotech/features/dokter/dashboard/frontend/dokter_pemeriksaan.dart';
import 'package:mapotech/features/dokter/dashboard/frontend/dokter_pembukuan.dart';
import 'package:mapotech/features/dokter/dashboard/frontend/dokter_asisten.dart';
import 'package:mapotech/features/dokter/dashboard/frontend/dokter_profile.dart';
import 'package:mapotech/features/dokter/dashboard/frontend/dokter_settings.dart';
import 'package:mapotech/features/apotek/dashboard/frontend/apotek_dashboard.dart';
import 'package:mapotech/features/apotek/dashboard/frontend/apotek_profile.dart';
import 'package:mapotech/features/apotek/dashboard/frontend/apotek_asisten.dart';
import 'package:mapotech/features/apotek/dashboard/frontend/apotek_penjualan.dart';
import 'package:mapotech/features/apotek/dashboard/frontend/apotek_inventori.dart';
import 'package:mapotech/features/apotek/dashboard/frontend/apotek_laporan.dart';
import 'package:mapotech/shared/widgets/segera_hadir_mockup.dart';
import 'package:mapotech/features/puskesmas/dashboard/frontend/puskesmas_profile.dart';
import 'package:mapotech/features/ponkesdes/dashboard/frontend/ponkesdes_profile.dart';

bool _isCorsafeUrl(String url) {
  if (url.isEmpty) return false;
  return url.startsWith('http://') || url.startsWith('https://');
}

/// The unified interior shell shown when the user is logged in.
class DashboardShell extends ConsumerStatefulWidget {
  const DashboardShell({super.key});

  @override
  ConsumerState<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends ConsumerState<DashboardShell> {
  String _activeMenu = 'dashboard';
  bool _isGuideActive = false;
  PageTutorialData? _activeGuideTutorial;
  int _activeGuideStepIndex = 0;

  String? _lastCheckedUserId;
  bool _hasShownSubNotice = false;

  bool _shouldUseShellScroll(String menu) {
    if (menu == 'doctors' || menu == 'pharmacies' || menu == 'pasien') {
      return false;
    }
    return true;
  }

  void _showSubscriptionNotice(bool active, DateTime? expiry, String role) {
    if (_hasShownSubNotice) return;
    _hasShownSubNotice = true;

    final state = ref.read(landingPageProvider);
    final isEn = state.language == 'en';
    final now = DateTime.now();

    if (!active) {
      // EXPIRED OR INACTIVE
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.redAccent,
                ),
                const SizedBox(width: 10),
                Text(
                  isEn ? 'Subscription Expired' : 'Langganan Kedaluwarsa',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: Text(
              isEn
                  ? 'Your subscription for the ${role == 'dokter' ? 'Private Practice' : 'Pharmacy'} has expired. Please renew it in the Profile settings to unlock all menus.'
                  : 'Langganan ${role == 'dokter' ? 'Praktik Mandiri' : 'Apotek'} Anda telah kedaluwarsa. Silakan perbarui di menu Profil untuk membuka kembali semua akses.',
              style: GoogleFonts.outfit(fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _activeMenu = 'profile';
                  });
                },
                child: Text(
                  isEn ? 'Go to Profile' : 'Ke Profil',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    color: Colors.purple,
                  ),
                ),
              ),
            ],
          ),
        );
      });
    } else if (expiry != null) {
      // ACTIVE BUT EXPIRING SOON (<= 5 DAYS)
      final diff = expiry.difference(now);
      final daysLeft = diff.inDays;

      if (daysLeft <= 5) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.orangeAccent),
                  const SizedBox(width: 10),
                  Text(
                    isEn
                        ? 'Subscription Expiring Soon'
                        : 'Langganan Segera Habis',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: Text(
                isEn
                    ? 'Your subscription for the ${role == 'dokter' ? 'Private Practice' : 'Pharmacy'} will expire in $daysLeft days. Renew now to prevent service disruptions.'
                    : 'Langganan ${role == 'dokter' ? 'Praktik Mandiri' : 'Apotek'} Anda akan habis dalam $daysLeft hari. Perbarui sekarang untuk mencegah gangguan layanan.',
                style: GoogleFonts.outfit(fontSize: 14),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    isEn ? 'Dismiss' : 'Tutup',
                    style: GoogleFonts.outfit(color: Colors.grey),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _activeMenu = 'profile';
                    });
                  },
                  child: Text(
                    isEn ? 'Renew Now' : 'Perbarui Sekarang',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      color: Colors.purple,
                    ),
                  ),
                ),
              ],
            ),
          );
        });
      }
    }
  }

  Future<void> _checkSubscription() async {
    final state = ref.read(landingPageProvider);
    if (!state.isLoggedIn) return;
    final userId = state.loggedInUser?['id'];
    if (userId == _lastCheckedUserId) return;
    _lastCheckedUserId = userId;
    _hasShownSubNotice = false; // reset for new user session

    final role = state.loggedInRole;
    if (role != 'dokter' &&
        role != 'apotek' &&
        role != 'puskesmas' &&
        role != 'ponkesdes') {
      ref.read(landingPageProvider.notifier).setSubscribed(true);
      return;
    }

    try {
      final client = SupabaseService.client;
      if (role == 'dokter') {
        final doctorId = state.activeDoctorId ?? userId;
        if (doctorId != null) {
          final res = await client
              .from('user_detail_doctor')
              .select(
                'subscription_status, subscription_expired_at, profession',
              )
              .eq('id', doctorId)
              .maybeSingle();
          if (res != null) {
            final status = (res['subscription_status'] ?? 'INACTIVE')
                .toString()
                .toUpperCase();
            final expiredAt = res['subscription_expired_at'];
            final profession = res['profession']?.toString() ?? 'Doctor';
            bool active = false;
            DateTime? expiry;
            if (status == 'ACTIVE' && expiredAt != null) {
              try {
                expiry = DateTime.parse(expiredAt.toString());
                active = expiry.isAfter(DateTime.now());
              } catch (_) {}
            }
            ref.read(landingPageProvider.notifier).updateUser({
              'profession': profession,
            });
            ref.read(landingPageProvider.notifier).setSubscribed(active);
            _showSubscriptionNotice(active, expiry, role!);
            return;
          }
        }
      } else if (role == 'puskesmas' || role == 'ponkesdes') {
        final res = await client
            .from('user')
            .select('subscription_status, subscription_expires_at')
            .eq('id', userId)
            .maybeSingle();
        if (res != null) {
          final status = (res['subscription_status'] ?? 'INACTIVE')
              .toString()
              .toUpperCase();
          final expiredAt = res['subscription_expires_at'];
          bool active = false;
          DateTime? expiry;
          if (status == 'ACTIVE' && expiredAt != null) {
            try {
              expiry = DateTime.parse(expiredAt.toString());
              active = expiry.isAfter(DateTime.now());
            } catch (_) {}
          }
          ref.read(landingPageProvider.notifier).setSubscribed(active);
          _showSubscriptionNotice(active, expiry, role!);
          return;
        }
      } else if (role == 'apotek') {
        final apotekId = state.activeApotekId;
        if (apotekId != null) {
          final res = await client
              .from('user_detail_pharmacist')
              .select('subscription_status, subscription_expired_at')
              .eq('id', apotekId)
              .maybeSingle();
          if (res != null) {
            final status = (res['subscription_status'] ?? 'INACTIVE')
                .toString()
                .toUpperCase();
            final expiredAt = res['subscription_expired_at'];
            bool active = false;
            DateTime? expiry;
            if (status == 'ACTIVE' && expiredAt != null) {
              try {
                expiry = DateTime.parse(expiredAt.toString());
                active = expiry.isAfter(DateTime.now());
              } catch (_) {}
            }
            ref.read(landingPageProvider.notifier).setSubscribed(active);
            _showSubscriptionNotice(active, expiry, role!);
            return;
          }
        }
      }
    } catch (e) {
      debugPrint('Error checking subscription: $e');
    }
    ref.read(landingPageProvider.notifier).setSubscribed(false);
    _showSubscriptionNotice(false, null, role ?? 'dokter');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(landingPageProvider);
    final notifier = ref.read(landingPageProvider.notifier);

    // Check subscription status if user changes
    if (state.isLoggedIn && state.loggedInUser?['id'] != _lastCheckedUserId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkSubscription();
      });
    }

    // Safety redirect: If the logged-in user is a doctor or apotek and has no active subscription, force profile menu.
    if (state.isLoggedIn &&
        (state.loggedInRole == 'dokter' || state.loggedInRole == 'apotek') &&
        !state.isSubscribed) {
      if (_activeMenu != 'profile') {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _activeMenu = 'profile';
            });
          }
        });
      }
    }

    // Safety redirect: If the logged-in user is an assistant, they should only see permitted menus.
    if (state.isLoggedIn && state.isAssistant) {
      final menuItems = getMenuItemsForRole(
        state.loggedInRole ?? 'dokter',
        state.language,
        state: state,
      );
      if (menuItems.isNotEmpty &&
          !menuItems.any((item) => item.id == _activeMenu) &&
          _activeMenu != 'settings') {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _activeMenu = menuItems.first.id;
            });
          }
        });
      }
    }

    final isDark = state.appearance == 'dark';
    final isRev = state.appearance == 'rev';
    final bgColor = notifier.getBackgroundColor();
    final textColor = notifier.getTextColor();
    final borderColor = notifier.getBorderColor();
    final themeAccent = notifier.getPrimaryColor();

    final isMobile = MediaQuery.of(context).size.width < 768;

    // Drawer Width Animation
    double drawerWidth = 260.0;
    if (state.drawerSize == 0) {
      drawerWidth = 72.0;
    } else if (state.drawerSize == 2) {
      drawerWidth = MediaQuery.of(context).size.width; // full screen!
    }

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // MAIN ROW HOUSING THE DRAWER AND CONTENT (for collapsed & expanded sizes)
          Row(
            children: [
              // Dynamic Side Drawer
              if (state.drawerSize != 2)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  width: isMobile ? 0 : drawerWidth,
                  height: double.infinity,
                  child: DashboardDrawer(
                    activeMenu: _activeMenu,
                    onMenuSelected: (menu) {
                      setState(() {
                        _activeMenu = menu;
                      });
                    },
                  ),
                ),

              // Active Dashboard Content Body
              Expanded(
                child: Column(
                  children: [
                    // Top Bar Navigation
                    _buildTopBar(
                      state,
                      notifier,
                      textColor,
                      borderColor,
                      isMobile,
                    ),

                    // Inner Scrollable Panel
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.all(isMobile ? 16 : 28),
                        child: AnimatedPortalSwitcher(
                          switcherKey: _activeMenu,
                          child: _buildRoleDashboardBody(
                            state.loggedInRole ?? 'pasien',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // FULL SCREEN DRAWER LAYOUT OVERLAY (Triggered when drawerSize == 2)
          if (state.drawerSize == 2)
            Positioned.fill(
              child: FullScreenDrawerOverlay(
                activeMenu: _activeMenu,
                onMenuSelected: (menu) {
                  setState(() {
                    _activeMenu = menu;
                  });
                },
              ),
            ),

          // Pulsing Interactive Guide Target Focus
          if (_isGuideActive && _activeGuideTutorial != null)
            _buildGuideFocusTarget(state),

          // Floating Interactive Guide Card
          if (_isGuideActive && _activeGuideTutorial != null)
            _buildGuideFloatingCard(
              state,
              isDark,
              themeAccent,
              textColor,
              textColor.withOpacity(0.65),
              notifier.getCardColor(),
              borderColor,
              Colors.black.withOpacity(isDark ? 0.4 : 0.08),
            ),
        ],
      ),
    );
  }

  // ==================== 1. TOP BAR ====================

  Widget _buildTopBar(
    LandingPageState state,
    LandingPageNotifier notifier,
    Color textColor,
    Color borderColor,
    bool isMobile,
  ) {
    final isDark = state.appearance == 'dark';
    String avatarInitials = 'A';
    if (state.loggedInName != null && state.loggedInName!.isNotEmpty) {
      final parts = state.loggedInName!.split(' ');
      if (parts.length > 1) {
        avatarInitials = (parts[0][0] + parts[1][0]).toUpperCase();
      } else {
        avatarInitials = parts[0][0].toUpperCase();
      }
    } else {
      avatarInitials = state.loggedInRole == 'pasien'
          ? 'A'
          : (state.loggedInRole == 'dokter' ? 'AS' : 'CE');
    }

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: notifier.getCardColor(),
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: ClipRect(
        child: Stack(
          children: [
            if (state.loggedInUser?['avatar_url'] != null &&
                (state.loggedInUser!['avatar_url'] as String).isNotEmpty &&
                state.blurProfileEffectEnabled)
              Positioned.fill(
                child: ShaderMask(
                  shaderCallback: (rect) {
                    return const LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Colors.transparent,
                        Colors.black,
                        Colors.black,
                        Colors.transparent,
                      ],
                      stops: [0.0, 0.35, 0.65, 1.0],
                    ).createShader(rect);
                  },
                  blendMode: BlendMode.dstIn,
                  child: ImageFiltered(
                    imageFilter: ui.ImageFilter.blur(
                      sigmaX: 15.0,
                      sigmaY: 15.0,
                    ),
                    child: Image.network(
                      state.loggedInUser!['avatar_url'] as String,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox(),
                    ),
                  ),
                ),
              ),
            if (state.loggedInUser?['avatar_url'] != null &&
                (state.loggedInUser!['avatar_url'] as String).isNotEmpty &&
                state.blurProfileEffectEnabled)
              Positioned.fill(
                child: ShaderMask(
                  shaderCallback: (rect) {
                    return const LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Colors.transparent,
                        Colors.black,
                        Colors.black,
                        Colors.transparent,
                      ],
                      stops: [0.0, 0.35, 0.65, 1.0],
                    ).createShader(rect);
                  },
                  blendMode: BlendMode.dstIn,
                  child: Container(
                    color: isDark
                        ? Colors.black.withOpacity(0.4)
                        : (state.appearance == 'rev'
                              ? const Color(0xFFB577F2).withOpacity(0.08)
                              : const Color(0xFF48C9B0).withOpacity(0.08)),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Left section: Drawer trigger or Page title
                  Row(
                    children: [
                      if (isMobile)
                        IconButton(
                          icon: const Icon(Icons.menu_rounded),
                          onPressed: () {
                            // Mobile trigger switches straight to biggest full screen size!
                            notifier.setDrawerSize(2);
                          },
                        )
                      else
                        IconButton(
                          icon: Icon(
                            state.drawerSize == 0
                                ? Icons.menu_open_rounded
                                : Icons.menu_rounded,
                            color: textColor.withOpacity(0.7),
                          ),
                          onPressed: () {
                            notifier.toggleDrawerSize();
                          },
                        ),
                      const SizedBox(width: 8),
                      Builder(
                        builder: (context) {
                          final role = state.loggedInRole ?? 'pasien';
                          final menuItems = getMenuItemsForRole(
                            role,
                            state.language,
                            state: state,
                          );
                          String displayTitle = _activeMenu.toUpperCase();
                          for (final item in menuItems) {
                            if (item.id == _activeMenu) {
                              displayTitle = item.label.toUpperCase();
                              break;
                            }
                          }
                          if (_activeMenu == 'settings') {
                            displayTitle = state.language == 'en'
                                ? 'SETTINGS'
                                : 'PENGATURAN';
                          }
                          return Text(
                            displayTitle,
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: textColor,
                              letterSpacing: 1.0,
                            ),
                          );
                        },
                      ),
                    ],
                  ),

                  // Right section: Info status indicator and avatar shortcut
                  Row(
                    children: [
                      // Time & Sparkle Notification
                      Container(
                        margin: const EdgeInsets.only(right: 12),
                        child: IconButton(
                          icon: Icon(
                            Icons.help_outline_rounded,
                            size: 20,
                            color: textColor.withOpacity(0.6),
                          ),
                          onPressed: () {
                            final role = state.loggedInRole ?? 'pasien';
                            final menuItems = getMenuItemsForRole(
                              role,
                              state.language,
                              state: state,
                            );
                            String menuLabel = _activeMenu.toUpperCase();
                            for (final item in menuItems) {
                              if (item.id == _activeMenu) {
                                menuLabel = item.label;
                                break;
                              }
                            }
                            if (_activeMenu == 'settings') {
                              menuLabel = state.language.toLowerCase() == 'en'
                                  ? 'Settings'
                                  : 'Pengaturan';
                            }

                            PageTutorialDialog.show(
                              context,
                              role: role,
                              menuId: _activeMenu,
                              menuLabel: menuLabel,
                              onStartInteractiveGuide: () {
                                setState(() {
                                  _activeGuideTutorial = getTutorialData(
                                    role,
                                    _activeMenu,
                                    menuLabel,
                                    state.language,
                                  );
                                  _activeGuideStepIndex = 0;
                                  _isGuideActive = true;
                                });
                              },
                            );
                          },
                        ),
                      ),

                      // Status Badge / Avatar
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xFFB577F2).withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: ClipOval(
                          child:
                              (state.loggedInUser?['avatar_url'] != null &&
                                  (state.loggedInUser!['avatar_url'] as String)
                                      .isNotEmpty &&
                                  _isCorsafeUrl(
                                    state.loggedInUser!['avatar_url'] as String,
                                  ))
                              ? Image.network(
                                  state.loggedInUser!['avatar_url'] as String,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Center(
                                    child: Text(
                                      avatarInitials,
                                      style: GoogleFonts.outfit(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w900,
                                        color: const Color(0xFFB577F2),
                                      ),
                                    ),
                                  ),
                                )
                              : Center(
                                  child: Text(
                                    avatarInitials,
                                    style: GoogleFonts.outfit(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                      color: const Color(0xFFB577F2),
                                    ),
                                  ),
                                ),
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
    );
  }

  // ==================== 2. ROLE SPECIFIC DASHBOARDS ROUTER ====================

  Widget _buildRoleDashboardBody(String role) {
    if (role == 'dokter') {
      switch (_activeMenu) {
        case 'pasien':
          return const DokterPasien();
        case 'obat':
          return const DokterObat();
        case 'antrian':
          return const DokterAntrian();
        case 'pemeriksaan':
          return const DokterPemeriksaan();
        case 'pembukuan':
          return const DokterPembukuan();
        case 'asisten_praktik':
          return const DokterAsisten();
        case 'profile':
          return const DokterProfile();
        case 'settings':
          return const DokterSettings();
        case 'dashboard':
          return const DokterDashboard();
        default:
          return SegeraHadirMockup(portalPath: 'DOKTER/$_activeMenu');
      }
    } else if (role == 'puskesmas') {
      switch (_activeMenu) {
        case 'profile':
          return const PuskesmasProfile();
        case 'settings':
          return const DokterSettings();
        case 'pasien':
          return const DokterPasien();
        case 'obat':
          return const DokterObat();
        case 'antrian':
          return const DokterAntrian();
        case 'pemeriksaan':
          return const DokterPemeriksaan();
        case 'pembukuan':
          return const DokterPembukuan();
        case 'asisten_praktik':
          return const DokterAsisten();
        case 'dashboard':
        default:
          return const DokterDashboard();
      }
    } else if (role == 'ponkesdes') {
      switch (_activeMenu) {
        case 'profile':
          return const PonkesdesProfile();
        case 'settings':
          return const DokterSettings();
        case 'pasien':
          return const DokterPasien();
        case 'obat':
          return const DokterObat();
        case 'antrian':
          return const DokterAntrian();
        case 'pemeriksaan':
          return const DokterPemeriksaan();
        case 'pembukuan':
          return const DokterPembukuan();
        case 'asisten_praktik':
          return const DokterAsisten();
        case 'dashboard':
        default:
          return const DokterDashboard();
      }
    } else if (role == 'apotek') {
      switch (_activeMenu) {
        case 'profile':
          return const ApotekProfile();
        case 'dashboard':
          return const ApotekDashboard();
        case 'staff':
          return const ApotekAsisten();
        case 'penjualan':
          return const ApotekPenjualan();
        case 'inventori':
          return const ApotekInventori();
        case 'pesanan':
          return const ApotekPesanan();
        case 'laporan':
          return const ApotekLaporan();
        default:
          return SegeraHadirMockup(portalPath: 'APOTEK/$_activeMenu');
      }
    } else {
      // Pasien role: route by active menu
      switch (_activeMenu) {
        case 'dokter_search':
          return const PasienDokterSearch();
        case 'apotek_search':
          return const PasienApotekSearch();
        case 'history':
          return const PasienHistory();
        case 'prescription':
          return const PasienPrescription();
        case 'profile':
          return const PasienProfile();
        case 'settings':
          return const PasienSettings();
        case 'dashboard':
        default:
          return PasienDashboard(
            onNavigate: (menu) {
              setState(() {
                _activeMenu = menu;
              });
            },
          );
      }
    }
  }

  // ==================== 3. INTERACTIVE GUIDE OVERLAY WIDGETS ====================

  Widget _buildGuideFocusTarget(LandingPageState state) {
    final themeAccent = ref
        .read(landingPageProvider.notifier)
        .getPrimaryColor();

    final alignment = _getGuideTargetAlignment(
      _activeGuideTutorial!.title,
      _activeGuideStepIndex,
    );

    return Align(
      alignment: alignment,
      child: _PulsingTarget(color: themeAccent),
    );
  }

  Widget _buildGuideFloatingCard(
    LandingPageState state,
    bool isDark,
    Color themeAccent,
    Color textColor,
    Color secondaryTextColor,
    Color cardBg,
    Color borderColor,
    Color shadowColor,
  ) {
    final step = _activeGuideTutorial!.steps[_activeGuideStepIndex];
    final isEn = state.language.toLowerCase() == 'en';

    final labelPrev = isEn ? 'BACK' : 'KEMBALI';
    final labelNext =
        (_activeGuideStepIndex == _activeGuideTutorial!.steps.length - 1)
        ? (isEn ? 'FINISH' : 'SELESAI')
        : (isEn ? 'NEXT' : 'LANJUT');
    final labelGuide = isEn ? 'INTERACTIVE GUIDE' : 'PANDUAN INTERAKTIF';
    final stepProgress =
        (_activeGuideStepIndex + 1) / _activeGuideTutorial!.steps.length;

    return Positioned(
      bottom: 24,
      right: 24,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Container(
          decoration: BoxDecoration(
            color: ref
                .read(landingPageProvider.notifier)
                .getCardColor()
                .withOpacity(0.95),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: themeAccent.withOpacity(0.5), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              LinearProgressIndicator(
                value: stepProgress,
                backgroundColor: ref
                    .read(landingPageProvider.notifier)
                    .getBorderColor(),
                valueColor: AlwaysStoppedAnimation<Color>(themeAccent),
                minHeight: 4,
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '$labelGuide • ${_activeGuideStepIndex + 1}/${_activeGuideTutorial!.steps.length}',
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                            color: themeAccent,
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: textColor.withOpacity(0.5),
                          ),
                          onPressed: () {
                            setState(() {
                              _isGuideActive = false;
                            });
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      step.title,
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      step.description,
                      style: GoogleFonts.outfit(
                        fontSize: 12.5,
                        color: secondaryTextColor,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (_activeGuideStepIndex > 0)
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _activeGuideStepIndex--;
                              });
                            },
                            child: Text(
                              labelPrev,
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: themeAccent,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              if (_activeGuideStepIndex <
                                  _activeGuideTutorial!.steps.length - 1) {
                                _activeGuideStepIndex++;
                              } else {
                                _isGuideActive = false;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Row(
                                      children: [
                                        const Icon(
                                          Icons.check_circle_outline_rounded,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          isEn
                                              ? 'Guide completed successfully!'
                                              : 'Panduan berhasil diselesaikan!',
                                          style: GoogleFonts.outfit(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                    backgroundColor: themeAccent,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: themeAccent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            labelNext,
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
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
    );
  }

  Alignment _getGuideTargetAlignment(String title, int stepIndex) {
    final t = title.toLowerCase();
    if (t.contains('dokter') || t.contains('doctor')) {
      if (t.contains('profil') || t.contains('profile')) {
        return stepIndex == 0
            ? const Alignment(-0.6, -0.2)
            : const Alignment(-0.6, 0.3);
      }
      if (t.contains('dashboard')) {
        return stepIndex == 0
            ? const Alignment(-0.1, -0.4)
            : const Alignment(-0.5, 0.4);
      }
    } else if (t.contains('pasien') || t.contains('patient')) {
      if (t.contains('portal') ||
          t.contains('layanan') ||
          t.contains('services')) {
        return stepIndex == 0
            ? const Alignment(0.0, -0.4)
            : const Alignment(0.0, 0.3);
      }
    } else if (t.contains('apotek') || t.contains('pharmacy')) {
      if (t.contains('dashboard') || t.contains('operasional')) {
        return stepIndex == 0
            ? const Alignment(0.0, -0.3)
            : const Alignment(0.0, 0.4);
      }
    }

    switch (stepIndex % 4) {
      case 0:
        return const Alignment(-0.3, -0.3);
      case 1:
        return const Alignment(0.3, 0.3);
      case 2:
        return const Alignment(-0.3, 0.3);
      case 3:
      default:
        return const Alignment(0.3, -0.3);
    }
  }
}

class _PulsingTarget extends StatefulWidget {
  final Color color;
  const _PulsingTarget({required this.color});

  @override
  State<_PulsingTarget> createState() => _PulsingTargetState();
}

class _PulsingTargetState extends State<_PulsingTarget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 24 + (56 * _controller.value),
              height: 24 + (56 * _controller.value),
              decoration: BoxDecoration(
                color: widget.color.withOpacity(1.0 - _controller.value),
                shape: BoxShape.circle,
              ),
            ),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: widget.color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 6,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
