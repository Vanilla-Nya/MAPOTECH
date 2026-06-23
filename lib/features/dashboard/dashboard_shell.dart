import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapotech/features/landing/landing_page_data.dart';

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
import 'package:mapotech/features/apotek/dashboard/frontend/apotek_pesanan.dart';
import 'package:mapotech/features/apotek/dashboard/frontend/apotek_laporan.dart';
import 'package:mapotech/shared/widgets/segera_hadir_mockup.dart';

/// Returns true if the [url] is from a domain that allows CORS access
/// from localhost/web. External hospital servers typically block CORS.
bool _isCorsafeUrl(String url) {
  if (url.isEmpty) return false;
  return url.contains('supabase.co') ||
      url.contains('supabase.in') ||
      url.startsWith('https://images.unsplash.com') ||
      url.startsWith('https://picsum.photos') ||
      url.startsWith('https://lh3.googleusercontent.com') ||
      url.startsWith('https://avatars.githubusercontent.com');
}

/// The unified interior shell shown when the user is logged in.
class DashboardShell extends ConsumerStatefulWidget {
  const DashboardShell({super.key});

  @override
  ConsumerState<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends ConsumerState<DashboardShell> {
  String _activeMenu = 'dashboard';

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(landingPageProvider);
    final notifier = ref.read(landingPageProvider.notifier);

    final isDark = state.appearance == 'dark';
    final bgColor = isDark ? const Color(0xFF0F0F11) : const Color(0xFFF8FAFC);
    final textColor = isDark ? Colors.white : const Color(0xFF1B0C3C);
    final borderColor = isDark ? const Color(0xFF252528) : const Color(0xFFECEEF2);

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
                        child: _buildRoleDashboardBody(state.loggedInRole ?? 'pasien'),
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
      height: 70,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161619) : Colors.white,
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
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
                    state.drawerSize == 0 ? Icons.menu_open_rounded : Icons.menu_rounded,
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
                  final menuItems = getMenuItemsForRole(role);
                  String displayTitle = _activeMenu.toUpperCase();
                  for (final item in menuItems) {
                    if (item.id == _activeMenu) {
                      displayTitle = item.label.toUpperCase();
                      break;
                    }
                  }
                  if (_activeMenu == 'settings') {
                    displayTitle = 'PENGATURAN';
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
                  icon: Icon(Icons.help_outline_rounded, size: 20, color: textColor.withOpacity(0.6)),
                  onPressed: () {},
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
                  child: (state.loggedInUser?['avatar_url'] != null &&
                      (state.loggedInUser!['avatar_url'] as String).isNotEmpty &&
                      _isCorsafeUrl(state.loggedInUser!['avatar_url'] as String))
                      ? Image.network(
                          state.loggedInUser!['avatar_url'] as String,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Center(
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
}
