import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapotech/features/landing/landing_page_data.dart';

/// Returns true if [url] is from a domain that allows CORS access from localhost/web.
bool _isCorsafeUrl(String url) {
  if (url.isEmpty) return false;
  return url.contains('supabase.co') ||
      url.contains('supabase.in') ||
      url.startsWith('https://images.unsplash.com') ||
      url.startsWith('https://picsum.photos') ||
      url.startsWith('https://lh3.googleusercontent.com') ||
      url.startsWith('https://avatars.githubusercontent.com');
}

class DrawerMenuItem {
  final String id;
  final String label;
  final IconData icon;

  const DrawerMenuItem({
    required this.id,
    required this.label,
    required this.icon,
  });
}

List<DrawerMenuItem> getMenuItemsForRole(String role) {
  if (role == 'dokter') {
    return const [
      DrawerMenuItem(id: 'dashboard', label: 'Dashboard', icon: Icons.dashboard_rounded),
      DrawerMenuItem(id: 'pasien', label: 'Pasien', icon: Icons.people_rounded),
      DrawerMenuItem(id: 'obat', label: 'Obat', icon: Icons.medication_rounded),
      DrawerMenuItem(id: 'antrian', label: 'Antrian', icon: Icons.hourglass_empty_rounded),
      DrawerMenuItem(id: 'pemeriksaan', label: 'Pemeriksaan', icon: Icons.assignment_rounded),
      DrawerMenuItem(id: 'pembukuan', label: 'Pembukuan', icon: Icons.account_balance_wallet_rounded),
      DrawerMenuItem(id: 'asisten_praktik', label: 'Asisten Praktik', icon: Icons.badge_rounded),
      DrawerMenuItem(id: 'profile', label: 'Profil', icon: Icons.person_rounded),
    ];
  } else if (role == 'apotek') {
    return const [
      DrawerMenuItem(id: 'dashboard', label: 'Dashboard', icon: Icons.dashboard_rounded),
      DrawerMenuItem(id: 'penjualan', label: 'POS (Penjualan)', icon: Icons.shopping_cart_rounded),
      DrawerMenuItem(id: 'inventori', label: 'Inventori', icon: Icons.inventory_2_rounded),
      DrawerMenuItem(id: 'pesanan', label: 'Pesanan Masuk', icon: Icons.description_rounded),
      DrawerMenuItem(id: 'laporan', label: 'Laporan Keuangan', icon: Icons.bar_chart_rounded),
      DrawerMenuItem(id: 'staff', label: 'Manajemen Staff', icon: Icons.groups_rounded),
      DrawerMenuItem(id: 'profile', label: 'Profil', icon: Icons.account_circle_rounded),
    ];
  } else {
    return const [
      DrawerMenuItem(id: 'dashboard', label: 'Dashboard', icon: Icons.dashboard_rounded),
      DrawerMenuItem(id: 'dokter_search', label: 'Cari Praktik Mandiri', icon: Icons.search_rounded),
      DrawerMenuItem(id: 'apotek_search', label: 'Cari Apotek', icon: Icons.local_pharmacy_rounded),
      DrawerMenuItem(id: 'history', label: 'Riwayat', icon: Icons.history_rounded),
      DrawerMenuItem(id: 'prescription', label: 'Resep Obat', icon: Icons.medication_rounded),
      DrawerMenuItem(id: 'profile', label: 'Profil', icon: Icons.person_rounded),
    ];
  }
}

class DashboardDrawer extends ConsumerWidget {
  final String activeMenu;
  final ValueChanged<String> onMenuSelected;

  const DashboardDrawer({
    super.key,
    required this.activeMenu,
    required this.onMenuSelected,
  });

  List<DrawerMenuItem> _getMenuItemsForRole(String role) {
    return getMenuItemsForRole(role);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(landingPageProvider);
    final notifier = ref.read(landingPageProvider.notifier);

    final isDark = state.appearance == 'dark';
    final isRev = state.appearance == 'rev';
    final cardBgColor = isDark ? const Color(0xFF161619) : Colors.white;
    final borderColor = isDark ? const Color(0xFF252528) : const Color(0xFFECEEF2);
    final themeAccent = isRev ? const Color(0xFFB577F2) : const Color(0xFF48C9B0);

    final String avatarName = state.loggedInName ?? (state.loggedInRole == 'pasien' 
        ? 'Alvin' 
        : (state.loggedInRole == 'dokter' ? 'dr. Agoes Soetanto' : 'CyrenElysia~♪'));

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
    final String avatarRoleLabel = state.loggedInRole == 'pasien' 
        ? 'PASIEN' 
        : (state.loggedInRole == 'dokter' ? 'DOKTER' : 'APOTEK');

    final showLabels = state.drawerSize == 1;

    return Container(
      color: cardBgColor,
      child: Column(
        children: [
          // Drawer Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: borderColor)),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: showLabels
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: state.appearance == 'rev'
                              ? const [Color(0xFFEAB7EE), Color(0xFFB577F2)]
                              : (state.appearance == 'dark'
                                  ? const [Color(0xFF3A3A40), Color(0xFF252528)]
                                  : const [Color(0xFF7BE5D3), Color(0xFF48C9B0)]),
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: themeAccent.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: ClipOval(
                              child: Stack(
                                children: [
                                  if (state.loggedInUser?['avatar_url'] != null &&
                                      (state.loggedInUser!['avatar_url'] as String).isNotEmpty &&
                                      _isCorsafeUrl(state.loggedInUser!['avatar_url'] as String))
                                    Image.network(
                                      state.loggedInUser!['avatar_url'] as String,
                                      fit: BoxFit.cover,
                                      width: 40,
                                      height: 40,
                                      errorBuilder: (_, __, ___) => Center(
                                        child: Text(
                                          avatarInitials,
                                          style: GoogleFonts.outfit(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w900,
                                            color: themeAccent,
                                          ),
                                        ),
                                      ),
                                    )
                                  else
                                    Center(
                                      child: Text(
                                        avatarInitials,
                                        style: GoogleFonts.outfit(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w900,
                                          color: themeAccent,
                                        ),
                                      ),
                                    ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF48C9B0),
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 1.5),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  avatarName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  avatarRoleLabel,
                                  style: GoogleFonts.outfit(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white.withOpacity(0.7),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.open_in_full_rounded, size: 14, color: Colors.white),
                            onPressed: () {
                              notifier.toggleFullScreenDrawer();
                            },
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                    )
                  : Center(
                      child: InkWell(
                        onTap: () => notifier.setDrawerSize(1),
                        borderRadius: BorderRadius.circular(100),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: themeAccent.withOpacity(0.12),
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
                                          fontSize: 14,
                                          fontWeight: FontWeight.w900,
                                          color: themeAccent,
                                        ),
                                      ),
                                    ),
                                  )
                                : Center(
                                    child: Text(
                                      avatarInitials,
                                      style: GoogleFonts.outfit(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w900,
                                        color: themeAccent,
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
            ),
          ),

          const SizedBox(height: 16),

          // Menu items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: _getMenuItemsForRole(state.loggedInRole ?? 'pasien').map((item) {
                return _buildMenuItem(context, item.icon, item.label, item.id, showLabels, themeAccent, isDark);
              }).toList(),
            ),
          ),

          // Footer Actions: Settings & Logout
          Container(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                _buildMenuItem(context, Icons.settings_rounded, 'Pengaturan', 'settings', showLabels, themeAccent, isDark),
                const SizedBox(height: 6),
                _buildMenuItem(context, Icons.logout_rounded, 'Keluar', 'logout', showLabels, Colors.redAccent, isDark, isLogout: true, onTap: () {
                  notifier.logout();
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context,
    IconData icon,
    String label,
    String menuId,
    bool showLabels,
    Color accentColor,
    bool isDark, {
    bool isLogout = false,
    VoidCallback? onTap,
  }) {
    final isSelected = activeMenu == menuId;
    final activeBg = accentColor.withOpacity(0.12);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap ?? () {
          onMenuSelected(menuId);
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 48,
          padding: EdgeInsets.symmetric(horizontal: showLabels ? 14 : 10),
          decoration: BoxDecoration(
            color: isSelected ? activeBg : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: showLabels ? MainAxisAlignment.start : MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? accentColor : (isLogout ? Colors.redAccent : const Color(0xFF6F6A8A)),
                size: 20,
              ),
              if (showLabels) ...[
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w900 : FontWeight.w500,
                      color: isSelected 
                          ? accentColor 
                          : (isLogout 
                              ? Colors.redAccent 
                              : (isDark ? Colors.white70 : const Color(0xFF1B0C3C))),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class FullScreenDrawerOverlay extends ConsumerWidget {
  final String activeMenu;
  final ValueChanged<String> onMenuSelected;

  const FullScreenDrawerOverlay({
    super.key,
    required this.activeMenu,
    required this.onMenuSelected,
  });

  List<DrawerMenuItem> _getMenuItemsForRole(String role) {
    return getMenuItemsForRole(role);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(landingPageProvider);
    final notifier = ref.read(landingPageProvider.notifier);

    final isDark = state.appearance == 'dark';
    final isRev = state.appearance == 'rev';
    final bgColor = isDark ? const Color(0xFF0F0F11) : const Color(0xFFF8FAFC);
    final cardBgColor = isDark ? const Color(0xFF161619) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1B0C3C);
    final subtitleColor = isDark ? Colors.grey[400]! : const Color(0xFF6F6A8A);
    final borderColor = isDark ? const Color(0xFF252528) : const Color(0xFFECEEF2);
    final themeAccent = isRev ? const Color(0xFFB577F2) : const Color(0xFF48C9B0);

    final titleGradient = isDark
        ? const [Color(0xFF2C2C32), Color(0xFF1E1E22)]
        : (isRev
            ? const [Color(0xFFEAB7EE), Color(0xFFB577F2)]
            : const [Color(0xFF7BE5D3), Color(0xFF48C9B0)]);

    final String avatarName = state.loggedInName ?? (state.loggedInRole == 'pasien' 
        ? 'Alvin' 
        : (state.loggedInRole == 'dokter' ? 'dr. Agoes Soetanto' : 'CyrenElysia~♪'));

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
    final String avatarRoleLabel = state.loggedInRole == 'pasien' 
        ? 'PASIEN' 
        : (state.loggedInRole == 'dokter' ? 'DOKTER' : 'APOTEK');

    final isMobile = MediaQuery.of(context).size.width < 768;

    return Container(
      color: bgColor,
      child: Column(
        children: [
          // Header Panel
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 20,
              bottom: 24,
              left: 24,
              right: 24,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: titleGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
              boxShadow: [
                BoxShadow(
                  color: themeAccent.withOpacity(0.25),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                )
              ],
            ),
            child: Row(
              children: [
                InkWell(
                  onTap: () {
                    notifier.setDrawerSize(1);
                  },
                  borderRadius: BorderRadius.circular(100),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        avatarName,
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        avatarRoleLabel,
                        style: GoogleFonts.outfit(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: Colors.white.withOpacity(0.75),
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _buildTranslucentBadge(Icons.calendar_today_rounded, 'Selasa, 26 Mei 2026'),
                          const SizedBox(width: 8),
                          _buildTranslucentBadge(Icons.access_time_rounded, '13.52'),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: ClipOval(
                    child: Stack(
                      children: [
                        if (state.loggedInUser?['avatar_url'] != null &&
                            (state.loggedInUser!['avatar_url'] as String).isNotEmpty &&
                            _isCorsafeUrl(state.loggedInUser!['avatar_url'] as String))
                          Image.network(
                            state.loggedInUser!['avatar_url'] as String,
                            fit: BoxFit.cover,
                            width: 56,
                            height: 56,
                            errorBuilder: (_, __, ___) => Center(
                              child: Text(
                                avatarInitials,
                                style: GoogleFonts.outfit(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: themeAccent,
                                ),
                              ),
                            ),
                          )
                        else
                          Center(
                            child: Text(
                              avatarInitials,
                              style: GoogleFonts.outfit(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: themeAccent,
                              ),
                            ),
                          ),
                        Positioned(
                          bottom: 2,
                          right: 2,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: const Color(0xFF48C9B0),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2.0),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E22) : const Color(0xFFF1EEFA),
                borderRadius: BorderRadius.circular(100),
                border: Border.all(color: borderColor),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Icon(Icons.search_rounded, size: 20, color: subtitleColor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: textColor),
                      decoration: InputDecoration(
                        hintText: 'Apa yang ingin Anda cari hari ini?',
                        hintStyle: GoogleFonts.outfit(fontSize: 13, color: subtitleColor.withOpacity(0.5)),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 36),

          // Grid Menu Cards
          Expanded(
            child: GridView.count(
              crossAxisCount: isMobile ? 2 : 4,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.1,
              children: [
                ..._getMenuItemsForRole(state.loggedInRole ?? 'pasien').map((item) {
                  return _buildGridMenuCard(ref, item.label, item.icon, item.id, themeAccent, cardBgColor, isDark);
                }),
                _buildGridMenuCard(ref, 'Pengaturan', Icons.settings_rounded, 'settings', themeAccent, cardBgColor, isDark),
                _buildGridMenuCard(ref, 'Keluar', Icons.logout_rounded, 'logout', Colors.redAccent, cardBgColor, isDark, isLogout: true, onTap: () {
                  notifier.logout();
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTranslucentBadge(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 10),
          const SizedBox(width: 6),
          Text(
            text,
            style: GoogleFonts.outfit(
              fontSize: 8,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridMenuCard(
    WidgetRef ref,
    String label,
    IconData icon,
    String menuId,
    Color accentColor,
    Color cardBgColor,
    bool isDark, {
    bool isLogout = false,
    VoidCallback? onTap,
  }) {
    final isSelected = activeMenu == menuId;
    final notifier = ref.read(landingPageProvider.notifier);

    final state = ref.watch(landingPageProvider);
    final isRev = state.appearance == 'rev';

    final Color cardBg;
    if (isSelected) {
      cardBg = isDark
          ? accentColor.withOpacity(0.24)
          : (isRev
              ? const Color(0xFFF9E7F9)
              : const Color(0xFFE8F8F5));
    } else {
      cardBg = isDark
          ? const Color(0xFF1E1E22)
          : (isRev
              ? const Color(0xFFF4EDFC)
              : const Color(0xFFEBF7F5));
    }

    final Color iconBoxBg = isSelected
        ? accentColor
        : (isDark
            ? const Color(0xFF2C2C32)
            : (isRev
                ? const Color(0xFFD2B4DE)
                : const Color(0xFFA3E4D7)));

    final Color iconColor = isSelected
        ? Colors.white
        : (isLogout
            ? Colors.redAccent
            : (isDark
                ? Colors.white
                : (isRev
                    ? const Color(0xFF5E1B8C)
                    : const Color(0xFF1B4F42))));

    final Color borderCol = isSelected
        ? accentColor
        : Colors.transparent;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap ?? () {
          onMenuSelected(menuId);
          notifier.setDrawerSize(1);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: borderCol,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              )
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: iconBoxBg,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 24,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: isLogout
                      ? Colors.redAccent
                      : (isDark
                          ? Colors.white
                          : (isRev
                              ? const Color(0xFF5E1B8C)
                              : const Color(0xFF1B4F42))),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
