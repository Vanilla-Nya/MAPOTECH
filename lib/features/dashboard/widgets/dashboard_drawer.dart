import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapotech/features/landing/landing_page_data.dart';
import 'package:mapotech/shared/l10n/app_translations.dart';
import 'dart:ui' as ui;

bool _isCorsafeUrl(String url) {
  if (url.isEmpty) return false;
  return url.startsWith('http://') || url.startsWith('https://');
}

class DrawerMenuItem {
  final String id;
  final String label;
  final IconData icon;
  final List<String> clusters;
  final String? badgeText;

  const DrawerMenuItem({
    required this.id,
    required this.label,
    required this.icon,
    this.clusters = const ['all'],
    this.badgeText,
  });
}

class PuskesmasClusterInfo {
  final String id;
  final String labelId;
  final String labelEn;
  final IconData icon;
  final Color accentColor;

  const PuskesmasClusterInfo({
    required this.id,
    required this.labelId,
    required this.labelEn,
    required this.icon,
    required this.accentColor,
  });
}

const List<PuskesmasClusterInfo> puskesmasClusterList = [
  PuskesmasClusterInfo(
    id: 'all',
    labelId: 'Semua Cluster',
    labelEn: 'All Clusters',
    icon: Icons.grid_view_rounded,
    accentColor: Color(0xFF48C9B0),
  ),
  PuskesmasClusterInfo(
    id: 'cluster_1',
    labelId: 'Cluster 1 (Manajemen)',
    labelEn: 'Cluster 1 (Management)',
    icon: Icons.business_center_rounded,
    accentColor: Color(0xFF3498DB),
  ),
  PuskesmasClusterInfo(
    id: 'cluster_2',
    labelId: 'Cluster 2 (Ibu & Anak)',
    labelEn: 'Cluster 2 (Maternal & Child)',
    icon: Icons.child_care_rounded,
    accentColor: Color(0xFFE91E63),
  ),
  PuskesmasClusterInfo(
    id: 'cluster_3',
    labelId: 'Cluster 3 (Dewasa & Lansia)',
    labelEn: 'Cluster 3 (Adult & Elderly)',
    icon: Icons.elderly_rounded,
    accentColor: Color(0xFF9B59B6),
  ),
  PuskesmasClusterInfo(
    id: 'lintas_cluster',
    labelId: 'Lintas Cluster',
    labelEn: 'Cross Cluster',
    icon: Icons.hub_rounded,
    accentColor: Color(0xFFE67E22),
  ),
  PuskesmasClusterInfo(
    id: 'custom_menu',
    labelId: 'Custom Menu (DLC)',
    labelEn: 'Custom Menu (DLC)',
    icon: Icons.extension_rounded,
    accentColor: Color(0xFF1ABC9C),
  ),
];

List<DrawerMenuItem> getMenuItemsForRole(
  String role,
  String lang, {
  LandingPageState? state,
}) {
  final isEn = lang == 'en';

  if (state != null &&
      !state.isSubscribed &&
      (role == 'dokter' || role == 'apotek')) {
    return [
      DrawerMenuItem(
        id: 'profile',
        label: isEn ? 'Profile' : 'Profil',
        icon: role == 'dokter'
            ? Icons.person_rounded
            : Icons.account_circle_rounded,
      ),
    ];
  }

  List<DrawerMenuItem> items = [];
  if (role == 'dokter') {
    items = [
      DrawerMenuItem(
        id: 'dashboard',
        label: 'Dashboard',
        icon: Icons.dashboard_rounded,
      ),
      DrawerMenuItem(
        id: 'pasien',
        label: isEn ? 'Patients' : 'Pasien',
        icon: Icons.people_rounded,
      ),
      DrawerMenuItem(
        id: 'obat',
        label: isEn ? 'Medicines' : 'Obat',
        icon: Icons.medication_rounded,
      ),
      DrawerMenuItem(
        id: 'antrian',
        label: isEn ? 'Queues' : 'Antrian',
        icon: Icons.hourglass_empty_rounded,
      ),
      DrawerMenuItem(
        id: 'pemeriksaan',
        label: isEn ? 'Examinations' : 'Pemeriksaan',
        icon: Icons.assignment_rounded,
      ),
      DrawerMenuItem(
        id: 'pembukuan',
        label: isEn ? 'Bookkeeping' : 'Pembukuan',
        icon: Icons.account_balance_wallet_rounded,
      ),
      DrawerMenuItem(
        id: 'asisten_praktik',
        label: isEn ? 'Practice Assistant' : 'Asisten Praktik',
        icon: Icons.badge_rounded,
      ),
      DrawerMenuItem(
        id: 'profile',
        label: isEn ? 'Profile' : 'Profil',
        icon: Icons.person_rounded,
      ),
    ];
  } else if (role == 'apotek') {
    items = [
      DrawerMenuItem(
        id: 'dashboard',
        label: 'Dashboard',
        icon: Icons.dashboard_rounded,
      ),
      DrawerMenuItem(
        id: 'penjualan',
        label: isEn ? 'POS (Sales)' : 'POS (Penjualan)',
        icon: Icons.shopping_cart_rounded,
      ),
      DrawerMenuItem(
        id: 'inventori',
        label: isEn ? 'Inventory' : 'Inventori',
        icon: Icons.inventory_2_rounded,
      ),
      DrawerMenuItem(
        id: 'pesanan',
        label: isEn ? 'Incoming Orders' : 'Pesanan Masuk',
        icon: Icons.description_rounded,
      ),
      DrawerMenuItem(
        id: 'laporan',
        label: isEn ? 'Financial Reports' : 'Laporan Keuangan',
        icon: Icons.bar_chart_rounded,
      ),
      DrawerMenuItem(
        id: 'staff',
        label: isEn ? 'Staff Management' : 'Manajemen Staff',
        icon: Icons.groups_rounded,
      ),
      DrawerMenuItem(
        id: 'profile',
        label: isEn ? 'Profile' : 'Profil',
        icon: Icons.account_circle_rounded,
      ),
    ];
  } else if (role == 'puskesmas') {
    items = [
      DrawerMenuItem(
        id: 'dashboard',
        label: 'Dashboard',
        icon: Icons.dashboard_rounded,
        clusters: const ['all', 'cluster_1'],
        badgeText: 'CL-1',
      ),
      DrawerMenuItem(
        id: 'pasien',
        label: isEn ? 'Patients' : 'Pasien',
        icon: Icons.people_rounded,
        clusters: const ['all', 'cluster_2', 'cluster_3'],
        badgeText: 'CL-2 & 3',
      ),
      DrawerMenuItem(
        id: 'dlc_vitascale_screening',
        label: isEn ? 'Child Screening' : 'Screening Anak/Bayi',
        icon: Icons.monitor_weight_rounded,
        clusters: const ['all', 'custom_menu', 'cluster_2'],
        badgeText: 'AI & MLP',
      ),
      DrawerMenuItem(
        id: 'dlc_vitascale_data_anak',
        label: isEn ? 'Child/Infant Data' : 'Data Anak/Bayi',
        icon: Icons.child_care_rounded,
        clusters: const ['all', 'custom_menu', 'cluster_2'],
        badgeText: 'VITASCALE',
      ),
      DrawerMenuItem(
        id: 'dlc_pantauan_ibu_hamil',
        label: isEn ? 'Maternal Monitoring' : 'Pantauan Ibu Hamil',
        icon: Icons.pregnant_woman_rounded,
        clusters: const ['all', 'custom_menu', 'cluster_2'],
        badgeText: 'DLC KIA',
      ),
      DrawerMenuItem(
        id: 'dlc_form_ibu_hamil',
        label: isEn ? 'Maternal Exam Form' : 'Form Pemeriksaan Ibu Hamil',
        icon: Icons.assignment_rounded,
        clusters: const ['all', 'custom_menu', 'cluster_2'],
        badgeText: 'DLC KIA',
      ),
      DrawerMenuItem(
        id: 'obat',
        label: isEn ? 'Medicines' : 'Obat',
        icon: Icons.medication_rounded,
        clusters: const ['all', 'lintas_cluster'],
        badgeText: 'LINTAS',
      ),
      DrawerMenuItem(
        id: 'antrian',
        label: isEn ? 'Queues' : 'Antrian',
        icon: Icons.hourglass_empty_rounded,
        clusters: const ['all', 'cluster_2', 'cluster_3', 'lintas_cluster'],
        badgeText: 'LINTAS',
      ),
      DrawerMenuItem(
        id: 'pemeriksaan',
        label: isEn ? 'Examinations' : 'Pemeriksaan',
        icon: Icons.assignment_rounded,
        clusters: const ['all', 'cluster_2', 'cluster_3'],
        badgeText: 'CL-2 & 3',
      ),
      DrawerMenuItem(
        id: 'pembukuan',
        label: isEn ? 'Bookkeeping' : 'Pembukuan',
        icon: Icons.account_balance_wallet_rounded,
        clusters: const ['all', 'cluster_1'],
        badgeText: 'CL-1',
      ),
      DrawerMenuItem(
        id: 'management_pekerja',
        label: isEn ? 'Worker Management' : 'Management Pekerja',
        icon: Icons.engineering_rounded,
        clusters: const ['all', 'cluster_1'],
        badgeText: 'CL-1',
      ),
      DrawerMenuItem(
        id: 'management_pustu_ponkesdes',
        label: isEn
            ? 'Pustu/Ponkesdes Management'
            : 'Management Pustu/Ponkesdes',
        icon: Icons.home_work_rounded,
        clusters: const ['all', 'cluster_1'],
        badgeText: 'PUSTU',
      ),
      DrawerMenuItem(
        id: 'profile',
        label: isEn ? 'Profile' : 'Profil',
        icon: Icons.domain_rounded,
        clusters: const ['all', 'cluster_1'],
        badgeText: 'CL-1',
      ),
    ];
  } else if (role == 'ponkesdes') {
    items = [
      DrawerMenuItem(
        id: 'dashboard',
        label: 'Dashboard',
        icon: Icons.dashboard_rounded,
        badgeText: 'PKD',
      ),
      DrawerMenuItem(
        id: 'dlc_pantauan_ibu_hamil',
        label: isEn ? 'Maternal Care Monitoring' : 'Pantauan Ibu Hamil',
        icon: Icons.pregnant_woman_rounded,
        badgeText: 'DLC BUMIL',
      ),
      DrawerMenuItem(
        id: 'dlc_form_ibu_hamil',
        label: isEn ? 'Maternal Exam Form' : 'Form Pemeriksaan Ibu Hamil',
        icon: Icons.assignment_rounded,
        badgeText: 'ANC 10T',
      ),
      DrawerMenuItem(
        id: 'dlc_vitascale_data_anak',
        label: isEn ? 'VitaScale Child Nutrition' : 'VitaScale Gizi Balita',
        icon: Icons.child_care_rounded,
        badgeText: 'DLC BALITA',
      ),
      DrawerMenuItem(
        id: 'pasien',
        label: isEn ? 'Village Patients' : 'Pasien Binaan Desa',
        icon: Icons.people_rounded,
      ),
      DrawerMenuItem(
        id: 'obat',
        label: isEn ? 'Medicines' : 'Obat',
        icon: Icons.medication_rounded,
      ),
      DrawerMenuItem(
        id: 'antrian',
        label: isEn ? 'Queues' : 'Antrian',
        icon: Icons.hourglass_empty_rounded,
      ),
      DrawerMenuItem(
        id: 'pemeriksaan',
        label: isEn ? 'Examinations' : 'Pemeriksaan',
        icon: Icons.assignment_rounded,
      ),
      DrawerMenuItem(
        id: 'pembukuan',
        label: isEn ? 'Bookkeeping' : 'Pembukuan',
        icon: Icons.account_balance_wallet_rounded,
      ),
      DrawerMenuItem(
        id: 'asisten_praktik',
        label: isEn ? 'Practice Assistant' : 'Asisten Praktik',
        icon: Icons.badge_rounded,
      ),
      DrawerMenuItem(
        id: 'profile',
        label: isEn ? 'Profile' : 'Profil',
        icon: Icons.home_work_rounded,
      ),
    ];
  } else {
    items = [
      DrawerMenuItem(
        id: 'dashboard',
        label: 'Dashboard',
        icon: Icons.dashboard_rounded,
      ),
      DrawerMenuItem(
        id: 'ai_assistant',
        label: isEn ? 'AI Helper' : 'Asisten AI',
        icon: Icons.smart_toy_rounded,
      ),
      DrawerMenuItem(
        id: 'qr_scanner',
        label: isEn ? 'Scan QR Code' : 'Scan QR Dokter & Apotek',
        icon: Icons.qr_code_scanner_rounded,
      ),
      DrawerMenuItem(
        id: 'dokter_search',
        label: isEn ? 'Search Private Practice' : 'Cari Praktik Mandiri',
        icon: Icons.person_search_rounded,
      ),
      DrawerMenuItem(
        id: 'puskesmas_search',
        label: isEn ? 'Search Puskesmas' : 'Cari Puskesmas',
        icon: Icons.domain_rounded,
      ),
      DrawerMenuItem(
        id: 'pustu_search',
        label: isEn ? 'Search Pustu/Ponkesdes' : 'Cari Pustu/Ponkesdes',
        icon: Icons.home_work_rounded,
      ),
      DrawerMenuItem(
        id: 'apotek_search',
        label: isEn ? 'Search Pharmacy' : 'Cari Apotek',
        icon: Icons.local_pharmacy_rounded,
      ),
      DrawerMenuItem(
        id: 'history',
        label: isEn ? 'History' : 'Riwayat',
        icon: Icons.history_rounded,
      ),
      DrawerMenuItem(
        id: 'prescription',
        label: isEn ? 'Prescriptions' : 'Resep Obat',
        icon: Icons.medication_rounded,
      ),
      DrawerMenuItem(
        id: 'children',
        label: isEn ? 'My Children' : 'Data Anak',
        icon: Icons.child_care_rounded,
      ),
      DrawerMenuItem(
        id: 'profile',
        label: isEn ? 'Profile' : 'Profil',
        icon: Icons.person_rounded,
      ),
    ];
  }

  if (state != null && state.isAssistant) {
    final permsList =
        state.loggedInUser?['permissions'] as List<dynamic>? ?? [];
    final Set<String> permissions = permsList
        .map((p) => p.toString().toUpperCase())
        .toSet();

    return items.where((item) {
      if (item.id == 'profile' || item.id == 'settings') {
        return true;
      }
      String permKey = item.id.toUpperCase();
      if (permKey == 'ASISTEN_PRAKTIK') {
        permKey = 'ASISTEN';
      }
      if (permKey == 'MANAGEMENT_PEKERJA') {
        permKey = 'PEKERJA';
      }
      return permissions.contains(permKey);
    }).toList();
  }

  return items;
}

class DashboardDrawer extends ConsumerWidget {
  final String activeMenu;
  final ValueChanged<String> onMenuSelected;

  const DashboardDrawer({
    super.key,
    required this.activeMenu,
    required this.onMenuSelected,
  });

  List<DrawerMenuItem> _getMenuItemsForRole(LandingPageState state) {
    return getMenuItemsForRole(
      state.loggedInRole ?? 'pasien',
      state.language,
      state: state,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(landingPageProvider);
    final notifier = ref.read(landingPageProvider.notifier);

    final isDark = state.appearance == 'dark';
    final cardBgColor = notifier.getCardColor();
    final borderColor = notifier.getBorderColor();
    final themeAccent = notifier.getPrimaryColor();

    final String avatarName =
        state.loggedInName ??
        (state.loggedInRole == 'pasien'
            ? 'Alvin'
            : (state.loggedInRole == 'dokter'
                  ? 'dr. Agoes Soetanto'
                  : 'CyrenElysia~♪'));

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
    final isEn = state.language == 'en';
    final String avatarRoleLabel = state.loggedInRole == 'pasien'
        ? (isEn ? 'PATIENT' : 'PASIEN')
        : (state.loggedInRole == 'dokter'
              ? (() {
                  final prof = (state.loggedInUser?['profession'] as String?)
                      ?.toLowerCase();
                  if (prof == 'midwife') {
                    return isEn ? 'MIDWIFE' : 'BIDAN';
                  } else if (prof == 'nurse') {
                    return isEn ? 'NURSE' : 'PERAWAT';
                  } else {
                    return isEn ? 'DOCTOR' : 'DOKTER';
                  }
                })()
              : (state.loggedInRole == 'apotek'
                    ? (isEn ? 'PHARMACY' : 'APOTEK')
                    : (state.loggedInRole == 'puskesmas'
                          ? (isEn ? 'HEALTH CENTER' : 'PUSKESMAS')
                          : (isEn ? 'VILLAGE CLINIC' : 'PONKESDES'))));

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
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: state.appearance == 'rev'
                              ? const [Color(0xFFEAB7EE), Color(0xFFB577F2)]
                              : (state.appearance == 'dark'
                                    ? const [
                                        Color(0xFF3A3A40),
                                        Color(0xFF252528),
                                      ]
                                    : const [
                                        Color(0xFF7BE5D3),
                                        Color(0xFF48C9B0),
                                      ]),
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
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        children: [
                          if (state.loggedInUser?['avatar_url'] != null &&
                              (state.loggedInUser!['avatar_url'] as String)
                                  .isNotEmpty &&
                              state.blurProfileEffectEnabled)
                            Positioned.fill(
                              child: ShaderMask(
                                shaderCallback: (rect) {
                                  return const LinearGradient(
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                    colors: [Colors.black, Colors.transparent],
                                    stops: [0.0, 0.8],
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
                              (state.loggedInUser!['avatar_url'] as String)
                                  .isNotEmpty &&
                              state.blurProfileEffectEnabled)
                            Positioned.fill(
                              child: ShaderMask(
                                shaderCallback: (rect) {
                                  return const LinearGradient(
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                    colors: [Colors.black, Colors.transparent],
                                    stops: [0.0, 0.8],
                                  ).createShader(rect);
                                },
                                blendMode: BlendMode.dstIn,
                                child: Container(
                                  color: isDark
                                      ? Colors.black.withOpacity(0.4)
                                      : themeAccent.withOpacity(0.15),
                                ),
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 12,
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
                                        if (state.loggedInUser?['avatar_url'] !=
                                                null &&
                                            (state.loggedInUser!['avatar_url']
                                                    as String)
                                                .isNotEmpty &&
                                            _isCorsafeUrl(
                                              state.loggedInUser!['avatar_url']
                                                  as String,
                                            ))
                                          Image.network(
                                            state.loggedInUser!['avatar_url']
                                                as String,
                                            fit: BoxFit.cover,
                                            width: 40,
                                            height: 40,
                                            errorBuilder: (_, _, _) => Center(
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
                                              border: Border.all(
                                                color: Colors.white,
                                                width: 1.5,
                                              ),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                  icon: const Icon(
                                    Icons.open_in_full_rounded,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                  onPressed: () {
                                    notifier.toggleFullScreenDrawer();
                                  },
                                  visualDensity: VisualDensity.compact,
                                ),
                              ],
                            ),
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
                            child:
                                (state.loggedInUser?['avatar_url'] != null &&
                                    (state.loggedInUser!['avatar_url']
                                            as String)
                                        .isNotEmpty &&
                                    _isCorsafeUrl(
                                      state.loggedInUser!['avatar_url']
                                          as String,
                                    ))
                                ? Image.network(
                                    state.loggedInUser!['avatar_url'] as String,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => Center(
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
              children: _getMenuItemsForRole(state)
                  .where((item) {
                    // Dashboard and AI Assistant are always fixed
                    if (item.id == 'dashboard' || item.id == 'ai_assistant') {
                      return true;
                    }
                    // VitaScale DLC menus ALWAYS directly visible in sidebar
                    if (item.id == 'dlc_vitascale_data_anak' ||
                        item.id == 'dlc_vitascale_screening') {
                      return true;
                    }
                    // Otherwise, only show if marked as favorite
                    return state.favoriteMenuItems.contains(item.id);
                  })
                  .map((item) {
                    return _buildMenuItem(
                      context,
                      item.icon,
                      item.label,
                      item.id,
                      showLabels,
                      themeAccent,
                      isDark,
                      badgeText: state.loggedInRole == 'puskesmas'
                          ? item.badgeText
                          : null,
                    );
                  })
                  .toList(),
            ),
          ),

          // Footer Actions: Settings & Logout
          Container(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                _buildMenuItem(
                  context,
                  Icons.settings_rounded,
                  state.language == 'en' ? 'Settings' : 'Pengaturan',
                  'settings',
                  showLabels,
                  themeAccent,
                  isDark,
                  badgeText: state.loggedInRole == 'puskesmas' ? 'CL-1' : null,
                ),
                const SizedBox(height: 6),
                _buildMenuItem(
                  context,
                  Icons.logout_rounded,
                  state.language == 'en' ? 'Logout' : 'Keluar',
                  'logout',
                  showLabels,
                  Colors.redAccent,
                  isDark,
                  isLogout: true,
                  onTap: () {
                    notifier.logout();
                  },
                ),
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
    String? badgeText,
    VoidCallback? onTap,
  }) {
    final isSelected = activeMenu == menuId;
    final activeBg = accentColor.withOpacity(0.12);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap:
            onTap ??
            () {
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
            mainAxisAlignment: showLabels
                ? MainAxisAlignment.start
                : MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected
                    ? accentColor
                    : (isLogout ? Colors.redAccent : const Color(0xFF6F6A8A)),
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
                      fontWeight: isSelected
                          ? FontWeight.w900
                          : FontWeight.w500,
                      color: isSelected
                          ? accentColor
                          : (isLogout
                                ? Colors.redAccent
                                : (isDark
                                      ? Colors.white70
                                      : const Color(0xFF1B0C3C))),
                    ),
                  ),
                ),
                if (badgeText != null && badgeText.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      badgeText,
                      style: GoogleFonts.outfit(
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        color: accentColor,
                      ),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class FullScreenDrawerOverlay extends ConsumerStatefulWidget {
  final String activeMenu;
  final ValueChanged<String> onMenuSelected;

  const FullScreenDrawerOverlay({
    super.key,
    required this.activeMenu,
    required this.onMenuSelected,
  });

  @override
  ConsumerState<FullScreenDrawerOverlay> createState() =>
      _FullScreenDrawerOverlayState();
}

class _FullScreenDrawerOverlayState
    extends ConsumerState<FullScreenDrawerOverlay> {
  String _selectedClusterFilter = 'all';
  String _selectedDlcSubCategory = 'all_dlc';
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showDlcInfoDialog(
    BuildContext context,
    String title,
    String subtitle,
    String desc,
  ) {
    final state = ref.read(landingPageProvider);
    final isDark = state.appearance == 'dark';
    final isEn = state.language == 'en';
    final themeAccent = ref
        .read(landingPageProvider.notifier)
        .getPrimaryColor();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          backgroundColor: isDark ? const Color(0xFF222228) : Colors.white,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: themeAccent.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.extension_rounded,
                  color: themeAccent,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF1B0C3C),
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: themeAccent,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  desc,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: isDark ? Colors.white70 : Colors.black87,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: themeAccent.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: themeAccent.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: themeAccent,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          isEn
                              ? 'Fitur DLC Custom Menu dapat dikustomisasi sesuai regulasi & alur Faskes Puskesmas Anda.'
                              : 'Fitur DLC Custom Menu dapat dikustomisasi sesuai regulasi & alur Faskes Puskesmas Anda.',
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: themeAccent,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                isEn ? 'Close' : 'Tutup',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  color: themeAccent,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: themeAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      isEn
                          ? 'Modul DLC "$title" telah diaktifkan dalam mode pratinjau!'
                          : 'Modul DLC "$title" telah diaktifkan dalam mode pratinjau!',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                    ),
                    backgroundColor: themeAccent,
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              child: Text(
                isEn ? 'Activate DLC' : 'Aktifkan DLC',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(landingPageProvider);
    final notifier = ref.read(landingPageProvider.notifier);
    final isEn = ref.watch(isEnglishProvider);

    final isDark = state.appearance == 'dark';
    final isRev = state.appearance == 'rev';
    final bgColor = notifier.getBackgroundColor();
    final cardBgColor = notifier.getCardColor();
    final textColor = notifier.getTextColor();
    final subtitleColor = notifier.getBodyTextColor();
    final borderColor = notifier.getBorderColor();
    final themeAccent = notifier.getPrimaryColor();

    final titleGradient = isDark
        ? const [Color(0xFF2C2C32), Color(0xFF1E1E22)]
        : (isRev
              ? const [Color(0xFFEAB7EE), Color(0xFFB577F2)]
              : const [Color(0xFF7BE5D3), Color(0xFF48C9B0)]);

    final String avatarName =
        state.loggedInName ??
        (state.loggedInRole == 'pasien'
            ? 'Alvin'
            : (state.loggedInRole == 'dokter'
                  ? 'dr. Agoes Soetanto'
                  : 'Puskesmas Sumbersari'));

    String avatarInitials = 'P';
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
          : (state.loggedInRole == 'dokter' ? 'AS' : 'PS');
    }
    final String avatarRoleLabel = state.loggedInRole == 'pasien'
        ? 'PASIEN'
        : (state.loggedInRole == 'dokter'
              ? (() {
                  final prof = (state.loggedInUser?['profession'] as String?)
                      ?.toLowerCase();
                  if (prof == 'midwife') {
                    return 'BIDAN';
                  } else if (prof == 'nurse') {
                    return 'PERAWAT';
                  } else {
                    return 'DOKTER';
                  }
                })()
              : (state.loggedInRole == 'puskesmas' ? 'PUSKESMAS' : 'APOTEK'));

    final isMobile = MediaQuery.of(context).size.width < 768;

    // Filter cards logic
    List<Widget> gridCards = [];

    if (state.loggedInRole == 'puskesmas' &&
        _selectedClusterFilter == 'custom_menu') {
      List<Map<String, dynamic>> allDlcItems = [
        {
          'title': isEn ? 'Maternal Care Monitoring' : 'Pantauan Ibu Hamil',
          'icon': Icons.pregnant_woman_rounded,
          'id': 'dlc_pantauan_ibu_hamil',
          'color': const Color(0xFFE91E63),
          'badge': 'DLC KIA 1',
          'category': 'kia_dlc',
          'onTap': () {
            widget.onMenuSelected('dlc_pantauan_ibu_hamil');
            notifier.setDrawerSize(1);
          },
        },
        {
          'title': isEn ? 'Maternal Exam Form' : 'Form Pemeriksaan Ibu Hamil',
          'icon': Icons.assignment_rounded,
          'id': 'dlc_form_ibu_hamil',
          'color': const Color(0xFFEC407A),
          'badge': 'DLC KIA 2',
          'category': 'kia_dlc',
          'onTap': () {
            widget.onMenuSelected('dlc_form_ibu_hamil');
            notifier.setDrawerSize(1);
          },
        },
        {
          'title': isEn
              ? 'Stunting & Child Screening'
              : 'Skrining Stunting & Balita',
          'icon': Icons.child_friendly_rounded,
          'id': 'dlc_skrining_stunting',
          'color': const Color(0xFFAB47BC),
          'badge': 'DLC KIA 3',
          'category': 'kia_dlc',
          'onTap': () {
            _showDlcInfoDialog(
              context,
              isEn
                  ? 'Stunting & Child Screening DLC'
                  : 'Modul DLC Skrining Stunting & Balita',
              isEn
                  ? 'Early Stunting Detection & Digital Growth Monitoring'
                  : 'Deteksi Dini Stunting & Pemantauan KMS Digital',
              isEn
                  ? 'DLC module for recording child stunting Z-Scores, digital KMS growth charts, and Supplementary Feeding Program (PMT).'
                  : 'Modul DLC inovasi untuk pencatatan Z-Score stunting balita, grafik tumbuh kembang KMS digital, dan distribusi Program Makanan Tambahan (PMT) Puskesmas.',
            );
          },
        },
        {
          'title': isEn ? 'Telemedicine DLC Module' : 'Modul DLC Telemedis',
          'icon': Icons.video_call_rounded,
          'id': 'dlc_telemedis',
          'color': const Color(0xFF8E24AA),
          'badge': 'DLC MED 1',
          'category': 'pelayanan_dlc',
          'onTap': () {
            _showDlcInfoDialog(
              context,
              isEn
                  ? 'Telemedicine DLC Module'
                  : 'Modul DLC Telemedis Puskesmas',
              isEn
                  ? 'Remote Consultation & e-Prescription'
                  : 'Konsultasi Jarak Jauh & e-Resep Puskesmas',
              isEn
                  ? 'Provides teleconsultation, patient medication reminders, and remote prescription services for remote areas.'
                  : 'Menyediakan fitur telekonsultasi, pengingat jadwal minum obat pasien, dan peresepan obat jarak jauh untuk kawasan terpencil.',
            );
          },
        },
        {
          'title': isEn ? 'Home Care DLC Module' : 'Modul DLC Home Care',
          'icon': Icons.home_work_rounded,
          'id': 'dlc_homecare',
          'color': const Color(0xFF3498DB),
          'badge': 'DLC MED 2',
          'category': 'pelayanan_dlc',
          'onTap': () {
            _showDlcInfoDialog(
              context,
              isEn
                  ? 'Home Care & Posyandu DLC Module'
                  : 'Modul DLC Home Care & Posyandu',
              isEn
                  ? 'Home Visits & Community Health Guidance'
                  : 'Kunjungan Rumah & Pembinaan Wilayah Puskesmas',
              isEn
                  ? 'DLC customization for medical team home visits to elderly/chronic patients and Posyandu monitoring in each Puskesmas region.'
                  : 'Fitur kustomisasi DLC untuk pengelolaan kunjungan tim medis ke rumah pasien lansia/kronis serta pemantauan Posyandu di setiap wilayah kerja Puskesmas.',
            );
          },
        },
        {
          'title': isEn
              ? 'E-Posyandu & EWRS High-Risk'
              : 'E-Posyandu & EWRS Risk',
          'icon': Icons.warning_amber_rounded,
          'id': 'dlc_eposyandu',
          'color': const Color(0xFFFF9800),
          'badge': 'DLC MED 3',
          'category': 'pelayanan_dlc',
          'onTap': () {
            _showDlcInfoDialog(
              context,
              isEn
                  ? 'E-Posyandu & EWRS High-Risk DLC'
                  : 'Modul DLC E-Posyandu & EWRS High-Risk',
              isEn
                  ? 'Early Warning Risk System & Posyandu Integration'
                  : 'Early Warning Risk System & Integrasi Posyandu',
              isEn
                  ? 'Automated early warning system for high-risk pregnancies, hypertension, pulmonary TB, and Posyandu cadre reporting integration.'
                  : 'Sistem peringatan dini otomatis untuk pasien risiko tinggi kehamilan, hipertensi, TB paru, dan integrasi pelaporan data kader Posyandu.',
            );
          },
        },
        {
          'title': isEn ? 'Child/Infant Data' : 'Data Anak/Bayi',
          'icon': Icons.child_care_rounded,
          'id': 'dlc_vitascale_data_anak',
          'color': const Color(0xFF1ABC9C),
          'badge': 'DLC VTS 1',
          'category': 'sistem_dlc',
          'onTap': () {
            widget.onMenuSelected('dlc_vitascale_data_anak');
            notifier.setDrawerSize(1);
          },
        },
        {
          'title': isEn ? 'Child Screening' : 'Screening Anak/Bayi',
          'icon': Icons.monitor_weight_rounded,
          'id': 'dlc_vitascale_screening',
          'color': const Color(0xFF16A085),
          'badge': 'DLC VTS 2',
          'category': 'sistem_dlc',
          'onTap': () {
            widget.onMenuSelected('dlc_vitascale_screening');
            notifier.setDrawerSize(1);
          },
        },
        {
          'title': isEn
              ? 'SatuSehat Pro DLC Module'
              : 'Modul DLC SatuSehat Pro',
          'icon': Icons.health_and_safety_rounded,
          'id': 'dlc_satusehat',
          'color': const Color(0xFF1ABC9C),
          'badge': 'DLC SYS 1',
          'category': 'pelayanan_dlc',
          'onTap': () {
            _showDlcInfoDialog(
              context,
              isEn ? 'SatuSehat Pro DLC Module' : 'Modul DLC SatuSehat Pro',
              isEn
                  ? 'EMR & BPJS P-Care Bridging'
                  : 'Integrasi RME & BPJS P-Care Terintegrasi',
              isEn
                  ? 'Expands Puskesmas EMR workflows with automated SatuSehat NIK validation and seamless BPJS P-Care bridging.'
                  : 'Modul tambahan DLC ini memperluas alur Rekam Medis Elektronik (RME) Puskesmas dengan otomatisasi validasi NIK SatuSehat dan sinkronisasi bridging P-Care BPJS tanpa jeda.',
            );
          },
        },
        {
          'title': 'BPJS P-Care Bridging',
          'icon': Icons.cloud_sync_rounded,
          'id': 'dlc_pcare',
          'color': const Color(0xFF00BCD4),
          'badge': 'DLC SYS 2',
          'category': 'pelayanan_dlc',
          'onTap': () {
            _showDlcInfoDialog(
              context,
              isEn
                  ? 'BPJS P-Care Automatic Bridging DLC'
                  : 'Modul DLC BPJS P-Care Automatic Bridging',
              isEn
                  ? 'Claim Integration & BPJS Data Entry'
                  : 'Integrasi Klaim & Entri Data BPJS P-Care',
              isEn
                  ? 'Automated submission of registration data, ICD-10 diagnoses, and patient interventions directly to BPJS P-Care servers.'
                  : 'Otomatisasi pengiriman data pendaftaran, diagnosa ICD-10, dan tindakan pasien ke server BPJS P-Care tanpa input ulang secara manual.',
            );
          },
        },
        {
          'title': isEn ? '+ Add Custom DLC Menu' : '+ Tambah Custom Menu DLC',
          'icon': Icons.add_circle_outline_rounded,
          'id': 'dlc_add',
          'color': const Color(0xFFE67E22),
          'badge': 'CUSTOM',
          'category': 'all_dlc',
          'onTap': () {
            _showDlcInfoDialog(
              context,
              isEn ? 'Add Custom DLC Menu' : 'Tambah Custom Menu (DLC)',
              isEn
                  ? 'Customization for Healthcare Facilities'
                  : 'Kustomisasi Modul Khusus Faskes Puskesmas',
              isEn
                  ? 'You can request new custom DLC modules tailored to your operational workflows and health facility regulations.'
                  : 'Anda dapat meminta modul custom DLC baru yang disesuaikan dengan kebutuhan alur operasional dan regulasi Puskesmas Anda.',
            );
          },
        },
      ];

      if (_selectedDlcSubCategory != 'all_dlc') {
        allDlcItems = allDlcItems.where((item) {
          return item['category'] == _selectedDlcSubCategory ||
              item['id'] == 'dlc_add';
        }).toList();
      }

      gridCards = allDlcItems.map((item) {
        return _buildGridMenuCard(
          ref,
          item['title'] as String,
          item['icon'] as IconData,
          item['id'] as String,
          item['color'] as Color,
          cardBgColor,
          isDark,
          badgeText: item['badge'] as String?,
          onTap: item['onTap'] as VoidCallback?,
        );
      }).toList();
    } else {
      var rawItems = getMenuItemsForRole(
        state.loggedInRole ?? 'pasien',
        state.language,
        state: state,
      );

      if (state.loggedInRole == 'puskesmas' &&
          _selectedClusterFilter != 'all') {
        rawItems = rawItems
            .where((item) => item.clusters.contains(_selectedClusterFilter))
            .toList();
      }

      if (_searchQuery.isNotEmpty) {
        rawItems = rawItems
            .where(
              (item) =>
                  item.label.toLowerCase().contains(_searchQuery.toLowerCase()),
            )
            .toList();
      }

      gridCards = [
        ...rawItems.map((item) {
          return _buildGridMenuCard(
            ref,
            item.label,
            item.icon,
            item.id,
            themeAccent,
            cardBgColor,
            isDark,
            badgeText: state.loggedInRole == 'puskesmas'
                ? item.badgeText
                : null,
          );
        }),
        if (_searchQuery.isEmpty &&
            (_selectedClusterFilter == 'all' ||
                _selectedClusterFilter == 'cluster_1')) ...[
          _buildGridMenuCard(
            ref,
            state.language == 'en' ? 'Settings' : 'Pengaturan',
            Icons.settings_rounded,
            'settings',
            themeAccent,
            cardBgColor,
            isDark,
            badgeText: state.loggedInRole == 'puskesmas' ? 'CL-1' : null,
          ),
          _buildGridMenuCard(
            ref,
            state.language == 'en' ? 'Logout' : 'Keluar',
            Icons.logout_rounded,
            'logout',
            Colors.redAccent,
            cardBgColor,
            isDark,
            isLogout: true,
            onTap: () {
              notifier.logout();
            },
          ),
        ],
      ];
    }

    return Container(
      color: bgColor,
      child: Column(
        children: [
          // Header Panel
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: titleGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(32),
              ),
              boxShadow: [
                BoxShadow(
                  color: themeAccent.withOpacity(0.25),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
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
                          stops: [0.0, 0.25, 0.75, 1.0],
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
                          stops: [0.0, 0.25, 0.75, 1.0],
                        ).createShader(rect);
                      },
                      blendMode: BlendMode.dstIn,
                      child: Container(
                        color: isDark
                            ? Colors.black.withOpacity(0.4)
                            : themeAccent.withOpacity(0.15),
                      ),
                    ),
                  ),
                Padding(
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 20,
                    bottom: 24,
                    left: 24,
                    right: 24,
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
                          child: const Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
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
                                _buildTranslucentBadge(
                                  Icons.calendar_today_rounded,
                                  AppTranslations.formatDate(
                                    DateTime.now(),
                                    lang: state.language,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _buildTranslucentBadge(
                                  Icons.access_time_rounded,
                                  '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}',
                                ),
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
                                  (state.loggedInUser!['avatar_url'] as String)
                                      .isNotEmpty &&
                                  _isCorsafeUrl(
                                    state.loggedInUser!['avatar_url'] as String,
                                  ))
                                Image.network(
                                  state.loggedInUser!['avatar_url'] as String,
                                  fit: BoxFit.cover,
                                  width: 56,
                                  height: 56,
                                  errorBuilder: (_, _, _) => Center(
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
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2.0,
                                    ),
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
                color: isDark
                    ? const Color(0xFF1E1E22)
                    : const Color(0xFFF1EEFA),
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
                      controller: _searchController,
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val.trim();
                        });
                      },
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                      decoration: InputDecoration(
                        hintText: isEn
                            ? 'What are you looking for today?'
                            : 'Apa yang ingin Anda cari hari ini?',
                        hintStyle: GoogleFonts.outfit(
                          fontSize: 13,
                          color: subtitleColor.withOpacity(0.5),
                        ),
                        border: InputBorder.none,
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _searchQuery = '';
                                  });
                                },
                              )
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Puskesmas Cluster Level Filter Bar
          if (state.loggedInRole == 'puskesmas') ...[
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Icon(Icons.tune_rounded, size: 14, color: themeAccent),
                  const SizedBox(width: 8),
                  Text(
                    state.language == 'en'
                        ? 'PUSKESMAS CLUSTER LEVEL FILTER'
                        : 'FILTER TINGKAT CLUSTER PUSKESMAS',
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: themeAccent,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _selectedClusterFilter == 'all'
                        ? (state.language == 'en'
                              ? 'Showing All'
                              : 'Menampilkan Semua')
                        : puskesmasClusterList
                              .firstWhere(
                                (c) => c.id == _selectedClusterFilter,
                                orElse: () => puskesmasClusterList.first,
                              )
                              .labelId,
                    style: GoogleFonts.outfit(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: subtitleColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 42,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: puskesmasClusterList.length,
                separatorBuilder: (context, index) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final cluster = puskesmasClusterList[index];
                  final isSelected = _selectedClusterFilter == cluster.id;
                  final label = state.language == 'en'
                      ? cluster.labelEn
                      : cluster.labelId;

                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedClusterFilter = cluster.id;
                      });
                    },
                    borderRadius: BorderRadius.circular(100),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? cluster.accentColor
                            : (isDark
                                  ? const Color(0xFF1E1E22)
                                  : const Color(0xFFF1EEFA)),
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(
                          color: isSelected ? cluster.accentColor : borderColor,
                          width: isSelected ? 2 : 1,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: cluster.accentColor.withOpacity(0.35),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : [],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            cluster.icon,
                            size: 16,
                            color: isSelected
                                ? Colors.white
                                : (isDark
                                      ? Colors.white70
                                      : const Color(0xFF1B0C3C)),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            label,
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: isSelected
                                  ? FontWeight.w900
                                  : FontWeight.w600,
                              color: isSelected
                                  ? Colors.white
                                  : (isDark
                                        ? Colors.white
                                        : const Color(0xFF1B0C3C)),
                            ),
                          ),
                          if (cluster.id == 'custom_menu') ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.white.withOpacity(0.25)
                                    : themeAccent.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: Text(
                                'DLC',
                                style: GoogleFonts.outfit(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w900,
                                  color: isSelected
                                      ? Colors.white
                                      : themeAccent,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],

          if (state.loggedInRole == 'puskesmas' &&
              _selectedClusterFilter == 'custom_menu') ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                children: [
                  _buildDlcSubFilterChip(
                    'all_dlc',
                    isEn ? 'All DLC Innovations' : 'Semua Inovasi DLC',
                    Icons.auto_awesome_rounded,
                  ),
                  const SizedBox(width: 8),
                  _buildDlcSubFilterChip(
                    'kia_dlc',
                    isEn
                        ? 'Maternal & Child (KIA)'
                        : 'Kesehatan Ibu & Anak (KIA)',
                    Icons.pregnant_woman_rounded,
                  ),
                  const SizedBox(width: 8),
                  _buildDlcSubFilterChip(
                    'pelayanan_dlc',
                    isEn
                        ? 'Medical Services & Posyandu'
                        : 'Pelayanan Medis & Posyandu',
                    Icons.medical_services_rounded,
                  ),
                  const SizedBox(width: 8),
                  _buildDlcSubFilterChip(
                    'sistem_dlc',
                    'VITASCALE By MAPOTECH',
                    Icons.monitor_weight_rounded,
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Grid Menu Cards
          Expanded(
            child: GridView.count(
              crossAxisCount: isMobile ? 2 : 4,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.1,
              children: gridCards,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDlcSubFilterChip(String id, String label, IconData icon) {
    final isSelected = _selectedDlcSubCategory == id;
    final state = ref.watch(landingPageProvider);
    final isDark = state.appearance == 'dark';
    final themeAccent = ref
        .read(landingPageProvider.notifier)
        .getPrimaryColor();
    final borderColor = ref.read(landingPageProvider.notifier).getBorderColor();

    return InkWell(
      onTap: () {
        setState(() {
          _selectedDlcSubCategory = id;
        });
      },
      borderRadius: BorderRadius.circular(100),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? themeAccent.withOpacity(0.18)
              : (isDark ? const Color(0xFF1E1E22) : const Color(0xFFF1EEFA)),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: isSelected ? themeAccent : borderColor,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected
                  ? themeAccent
                  : (isDark ? Colors.white70 : const Color(0xFF1B0C3C)),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                color: isSelected
                    ? themeAccent
                    : (isDark ? Colors.white : const Color(0xFF1B0C3C)),
              ),
            ),
          ],
        ),
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
    String? badgeText,
    VoidCallback? onTap,
  }) {
    final isSelected = widget.activeMenu == menuId;
    final notifier = ref.read(landingPageProvider.notifier);

    final state = ref.watch(landingPageProvider);
    final isRev = state.appearance == 'rev';
    final isFav = state.favoriteMenuItems.contains(menuId);
    final showFavButton = !isLogout && menuId != 'dlc_add';

    final Color cardBg;
    if (isSelected) {
      cardBg = isDark
          ? accentColor.withOpacity(0.24)
          : (isRev ? const Color(0xFFF9E7F9) : const Color(0xFFE8F8F5));
    } else {
      cardBg = isDark
          ? const Color(0xFF1E1E22)
          : (isRev ? const Color(0xFFF4EDFC) : const Color(0xFFEBF7F5));
    }

    final Color iconBoxBg = isSelected
        ? accentColor
        : (isDark
              ? const Color(0xFF2C2C32)
              : (isRev ? const Color(0xFFD2B4DE) : const Color(0xFFA3E4D7)));

    final Color iconColor = isSelected
        ? Colors.white
        : (isLogout
              ? Colors.redAccent
              : (isDark
                    ? Colors.white
                    : (isRev
                          ? const Color(0xFF5E1B8C)
                          : const Color(0xFF1B4F42))));

    final Color borderCol = isSelected ? accentColor : Colors.transparent;

    final VoidCallback handleCardTap =
        onTap ??
        () {
          widget.onMenuSelected(menuId);
          notifier.setDrawerSize(1);
        };

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderCol, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: handleCardTap,
          borderRadius: BorderRadius.circular(24),
          hoverColor: accentColor.withOpacity(0.08),
          splashColor: accentColor.withOpacity(0.15),
          highlightColor: accentColor.withOpacity(0.05),
          child: Stack(
            children: [
              // 1. Center Content (Main body of the card)
              Center(
                child: Padding(
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
                        child: Icon(icon, color: iconColor, size: 24),
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

              // 2. Favorite toggle button (Positioned at top-left, handles tap independently)
              if (showFavButton)
                Positioned(
                  top: 10,
                  left: 10,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        notifier.toggleFavoriteMenuItem(menuId);
                      },
                      borderRadius: BorderRadius.circular(100),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: isFav
                              ? (isDark
                                    ? const Color(0xFFFFB800).withOpacity(0.25)
                                    : const Color(0xFFFFF8E1))
                              : (isDark
                                    ? Colors.white.withOpacity(0.06)
                                    : Colors.black.withOpacity(0.04)),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isFav
                                ? const Color(0xFFFFB800).withOpacity(0.6)
                                : Colors.transparent,
                            width: 1,
                          ),
                        ),
                        child: Icon(
                          isFav
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          color: isFav
                              ? const Color(0xFFFFB800)
                              : (isDark
                                    ? Colors.white38
                                    : const Color(0xFFB0BEC5)),
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ),

              // 3. Cluster / Module badge (Positioned at top-right, IgnorePointer so card receives taps)
              if (badgeText != null && badgeText.isNotEmpty)
                Positioned(
                  top: 12,
                  right: 12,
                  child: IgnorePointer(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? accentColor
                            : accentColor.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        badgeText,
                        style: GoogleFonts.outfit(
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          color: isSelected ? Colors.white : accentColor,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
