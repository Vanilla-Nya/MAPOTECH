import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapotech/features/landing/landing_page_data.dart';
import 'package:mapotech/shared/widgets/ui.dart';
import 'package:mapotech/shared/supabase_service.dart';
import 'package:uuid/uuid.dart';

// ─── Data Models ─────────────────────────────────────────────────────────────

class ApotekStaffModel {
  final String id;
  final String nama;
  final String email;
  final String nik;
  final String strttk; // Optional: STR Tenaga Teknis Kefarmasian
  final String peran; // 'Asisten Apoteker', 'Kasir', 'Gudang', 'Kurir'
  final String telepon;
  final String shift; // 'Pagi', 'Sore', 'Malam'
  final bool isStandby;
  final List<String> permissions;
  final Color avatarBg;

  const ApotekStaffModel({
    required this.id,
    required this.nama,
    required this.email,
    required this.nik,
    required this.strttk,
    required this.peran,
    required this.telepon,
    required this.shift,
    required this.isStandby,
    required this.permissions,
    required this.avatarBg,
  });

  ApotekStaffModel copyWith({
    String? id,
    String? nama,
    String? email,
    String? nik,
    String? strttk,
    String? peran,
    String? telepon,
    String? shift,
    bool? isStandby,
    List<String>? permissions,
    Color? avatarBg,
  }) {
    return ApotekStaffModel(
      id: id ?? this.id,
      nama: nama ?? this.nama,
      email: email ?? this.email,
      nik: nik ?? this.nik,
      strttk: strttk ?? this.strttk,
      peran: peran ?? this.peran,
      telepon: telepon ?? this.telepon,
      shift: shift ?? this.shift,
      isStandby: isStandby ?? this.isStandby,
      permissions: permissions ?? this.permissions,
      avatarBg: avatarBg ?? this.avatarBg,
    );
  }
}

// ─── Riverpod State Provider ──────────────────────────────────────────────────

class ApotekAsistenListNotifier extends StateNotifier<List<ApotekStaffModel>> {
  final String apotekId;
  final SupabaseService _db = SupabaseService();
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  ApotekAsistenListNotifier(this.apotekId) : super([]) {
    loadStaff();
  }

  Future<void> loadStaff() async {
    _isLoading = true;
    try {
      final dbStaff = await _db.fetchPharmacistStaff(apotekId);
      state = dbStaff.map((ds) {
        return ApotekStaffModel(
          id: ds['id'] as String,
          nama: ds['nama'] as String,
          email: ds['email'] as String? ?? '-',
          nik: ds['nik'] as String,
          strttk: ds['strttk'] as String? ?? '-',
          peran: ds['peran'] as String? ?? 'Asisten Apoteker',
          telepon: ds['telepon'] as String? ?? '-',
          shift: ds['shift'] as String? ?? 'Pagi',
          isStandby: ds['isStandby'] as bool? ?? true,
          permissions: List<String>.from(ds['permissions'] ?? ['POS Kasir']),
          avatarBg: ds['peran'] == 'Asisten Apoteker'
              ? const Color(0xFF48C9B0)
              : (ds['peran'] == 'Kasir'
                    ? const Color(0xFFB577F2)
                    : const Color(0xFFF39C12)),
        );
      }).toList();
    } catch (e) {
      debugPrint('Error loading pharmacist staff: $e');
    } finally {
      _isLoading = false;
      if (mounted) {
        state = List.from(state);
      }
    }
  }

  Future<void> addStaff(
    ApotekStaffModel staff, {
    required String username,
    required String password,
  }) async {
    try {
      await _db.addPharmacistStaff(
        apotekId: apotekId,
        staffId: staff.id,
        name: staff.nama,
        email: staff.email,
        nik: staff.nik,
        phone: staff.telepon,
        strttk: staff.strttk,
        peran: staff.peran,
        shift: staff.shift,
        username: username,
        password: password,
      );
      await loadStaff();
    } catch (e) {
      debugPrint('Error adding staff: $e');
      rethrow;
    }
  }

  Future<void> removeStaff(String id) async {
    try {
      await _db.deletePharmacistStaff(id);
      await loadStaff();
    } catch (e) {
      debugPrint('Error removing staff: $e');
      rethrow;
    }
  }

  Future<void> toggleStandby(String id) async {
    try {
      final staff = state.firstWhere((s) => s.id == id);
      final nextStandby = !staff.isStandby;

      // Optimistic UI response
      state = [
        for (final s in state)
          if (s.id == id) s.copyWith(isStandby: nextStandby) else s,
      ];

      await _db.updatePharmacistStaffDuty(id, nextStandby);
    } catch (e) {
      debugPrint('Error toggling duty: $e');
      await loadStaff();
    }
  }

  Future<void> updateShift(String id, String newShift) async {
    try {
      // Optimistic UI response
      state = [
        for (final s in state)
          if (s.id == id) s.copyWith(shift: newShift) else s,
      ];

      await _db.updatePharmacistStaffShift(id, newShift);
    } catch (e) {
      debugPrint('Error updating shift: $e');
      await loadStaff();
    }
  }
}

final apotekAsistenListProvider =
    StateNotifierProvider<ApotekAsistenListNotifier, List<ApotekStaffModel>>((
      ref,
    ) {
      final userState = ref.watch(landingPageProvider);
      final loggedInUser = userState.loggedInUser;
      final apotekId = userState.activeApotekId ??
          loggedInUser?['id']?.toString() ??
          '10b247b2-94ec-4eb4-829b-e53f9164e313';
      return ApotekAsistenListNotifier(apotekId);
    });

// ─── Apotek Staff View ────────────────────────────────────────────────────────

class ApotekAsisten extends ConsumerStatefulWidget {
  const ApotekAsisten({super.key});

  @override
  ConsumerState<ApotekAsisten> createState() => _ApotekAsistenState();
}

class _ApotekAsistenState extends ConsumerState<ApotekAsisten> {
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(apotekAsistenListProvider.notifier).loadStaff();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(landingPageProvider);
    final allStaff = ref.watch(apotekAsistenListProvider);
    final isLoading = ref.watch(apotekAsistenListProvider.notifier).isLoading;

    final isDark = state.appearance == 'dark';
    final isRev = state.appearance == 'rev';
    final cardBgColor = isDark ? const Color(0xFF161619) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1B0C3C);
    final subtitleColor = isDark ? Colors.grey[400]! : const Color(0xFF6F6A8A);
    final borderColor = isDark
        ? const Color(0xFF252528)
        : const Color(0xFFECEEF2);
    final themeAccent = isRev
        ? const Color(0xFFB577F2)
        : const Color(0xFF48C9B0);
    final isMobile = MediaQuery.of(context).size.width < 768;

    // Filtered lists
    final filteredStaff = allStaff.where((s) {
      final q = _searchQuery.toLowerCase();
      return s.nama.toLowerCase().contains(q) ||
          s.nik.contains(q) ||
          s.peran.toLowerCase().contains(q);
    }).toList();

    // Summary counts
    final totalStaff = allStaff.length;
    final activeStaff = allStaff.where((s) => s.isStandby).length;
    final apotekerCount = allStaff
        .where((s) => s.peran == 'Asisten Apoteker')
        .length;
    final shiftPagiCount = allStaff.where((s) => s.shift == 'Pagi').length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Metrics Summary ───────────────────────────────────────────────
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: isMobile ? 2 : 4,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.6,
          children: [
            MetricCard(
              icon: Icons.groups_outlined,
              label: 'TOTAL STAFF APOTEK',
              count: '$totalStaff Orang',
              subtitleColor: subtitleColor,
              countColor: textColor,
              cardBgColor: cardBgColor,
              borderColor: borderColor,
            ),
            MetricCard(
              icon: Icons.run_circle_outlined,
              label: 'STANDBY SEKARANG',
              count: '$activeStaff Standby',
              subtitleColor: subtitleColor,
              countColor: themeAccent,
              cardBgColor: cardBgColor,
              borderColor: borderColor,
            ),
            MetricCard(
              icon: Icons.local_pharmacy_outlined,
              label: 'ASISTEN APOTEKER',
              count: '$apotekerCount Orang',
              subtitleColor: subtitleColor,
              countColor: const Color(0xFF3498DB),
              cardBgColor: cardBgColor,
              borderColor: borderColor,
            ),
            MetricCard(
              icon: Icons.wb_sunny_outlined,
              label: 'SHIFT PAGI TODAY',
              count: '$shiftPagiCount Orang',
              subtitleColor: subtitleColor,
              countColor: const Color(0xFFF39C12),
              cardBgColor: cardBgColor,
              borderColor: borderColor,
            ),
          ],
        ),

        const SizedBox(height: 28),

        // ── Controls Panel ────────────────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: cardBgColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderColor),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(Icons.search_rounded, size: 18, color: subtitleColor),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: textColor,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Cari nama, NIK, atau jabatan staff...',
                          hintStyle: GoogleFonts.outfit(
                            fontSize: 11,
                            color: subtitleColor.withOpacity(0.6),
                          ),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        onChanged: (val) {
                          setState(() {
                            _searchQuery = val;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            CustomButton(
              text: '+ Tambah Staff',
              onPressed: () {
                _showAddStaffDialog(context);
              },
              primaryColor: themeAccent,
              textColor: Colors.white,
            ),
          ],
        ),

        const SizedBox(height: 24),

        // ── Staff Cards Grid ──────────────────────────────────────────────
        if (isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 60),
              child: CircularProgressIndicator(),
            ),
          )
        else if (filteredStaff.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 60),
            alignment: Alignment.center,
            child: Column(
              children: [
                Icon(
                  Icons.badge_outlined,
                  size: 48,
                  color: subtitleColor.withOpacity(0.3),
                ),
                const SizedBox(height: 16),
                Text(
                  'Staff tidak ditemukan',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: subtitleColor,
                  ),
                ),
              ],
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filteredStaff.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isMobile ? 1 : 3,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              mainAxisExtent: 280,
            ),
            itemBuilder: (context, index) {
              final s = filteredStaff[index];
              return _buildStaffCard(
                context,
                s,
                cardBgColor,
                borderColor,
                textColor,
                subtitleColor,
                themeAccent,
              );
            },
          ),
      ],
    );
  }

  // ─── Staff Card Widget ──────────────────────────────────────────────────────

  Widget _buildStaffCard(
    BuildContext context,
    ApotekStaffModel s,
    Color cardBg,
    Color border,
    Color text,
    Color subtitle,
    Color accent,
  ) {
    final roleColor = s.peran == 'Asisten Apoteker'
        ? const Color(0xFF48C9B0)
        : (s.peran == 'Kasir'
              ? const Color(0xFFB577F2)
              : const Color(0xFFF39C12));

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header info: Avatar & Name
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: s.avatarBg.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  s.nama.substring(0, 2).toUpperCase(),
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: s.avatarBg,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.nama,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: text,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: roleColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        s.peran.toUpperCase(),
                        style: GoogleFonts.outfit(
                          fontSize: 7,
                          fontWeight: FontWeight.w900,
                          color: roleColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          Divider(color: border, height: 1),
          const SizedBox(height: 12),

          // Details
          _buildDetailRow(Icons.badge_outlined, 'NIK: ${s.nik}', subtitle),
          if (s.peran == 'Asisten Apoteker')
            _buildDetailRow(
              Icons.assignment_ind_outlined,
              'STRTTK: ${s.strttk}',
              subtitle,
            )
          else
            _buildDetailRow(
              Icons.assignment_ind_outlined,
              'STRTTK: Tidak diperlukan',
              subtitle,
            ),
          _buildDetailRow(
            Icons.schedule_outlined,
            'Shift Aktif: Shift ${s.shift}',
            subtitle,
          ),
          _buildDetailRow(Icons.phone_outlined, s.telepon, subtitle),

          const SizedBox(height: 12),

          // Access Permissions Badges
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: s.permissions.map((p) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: subtitle.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: border),
                  ),
                  child: Text(
                    p,
                    style: GoogleFonts.outfit(
                      fontSize: 8,
                      color: text.withOpacity(0.8),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 12),

          // Footer actions: isStandby toggle & nonaktifkan/shift change
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // isStandby Switch
              Row(
                children: [
                  Text(
                    s.isStandby ? 'STANDBY' : 'OFF',
                    style: GoogleFonts.outfit(
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      color: s.isStandby ? const Color(0xFF48C9B0) : subtitle,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    height: 18,
                    width: 32,
                    child: Switch(
                      value: s.isStandby,
                      activeThumbColor: const Color(0xFF48C9B0),
                      onChanged: (val) {
                        ref
                            .read(apotekAsistenListProvider.notifier)
                            .toggleStandby(s.id);
                      },
                    ),
                  ),
                ],
              ),

              // Modify/Remove Row
              Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.edit_calendar_outlined,
                      size: 14,
                      color: subtitle,
                    ),
                    onPressed: () {
                      _showChangeShiftDialog(context, s);
                    },
                    tooltip: 'Ubah Shift Kerja',
                    visualDensity: VisualDensity.compact,
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      size: 14,
                      color: Colors.redAccent,
                    ),
                    onPressed: () {
                      _confirmDelete(context, s);
                    },
                    tooltip: 'Hapus Staff',
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String value, Color subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 11, color: subtitle),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.outfit(
                fontSize: 10,
                color: subtitle,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Change Shift Overlay Dialog ────────────────────────────────────────────

  void _showChangeShiftDialog(BuildContext context, ApotekStaffModel s) {
    String tempShift = s.shift;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isDark = ref.watch(landingPageProvider).appearance == 'dark';
            final dialogBg = isDark ? const Color(0xFF1E1E22) : Colors.white;
            final txtColor = isDark ? Colors.white : const Color(0xFF1B0C3C);
            final subColor = isDark
                ? Colors.grey[400]!
                : const Color(0xFF6F6A8A);
            final activeAccent =
                ref.watch(landingPageProvider).appearance == 'rev'
                ? const Color(0xFFB577F2)
                : const Color(0xFF48C9B0);

            return Dialog(
              backgroundColor: dialogBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Jadwalkan Shift Staff',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: txtColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Pilih shift operasional untuk ${s.nama}',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          color: subColor,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Column(
                        children: ['Pagi', 'Sore', 'Malam'].map((shiftOpt) {
                          return RadioListTile<String>(
                            title: Text(
                              'Shift $shiftOpt',
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                color: txtColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              shiftOpt == 'Pagi'
                                  ? '07:00 - 15:00 WIB'
                                  : (shiftOpt == 'Sore'
                                        ? '15:00 - 22:00 WIB'
                                        : '22:00 - 07:00 WIB'),
                              style: GoogleFonts.outfit(
                                fontSize: 10,
                                color: subColor,
                              ),
                            ),
                            value: shiftOpt,
                            groupValue: tempShift,
                            activeColor: activeAccent,
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            onChanged: (val) {
                              setModalState(() {
                                tempShift = val ?? 'Pagi';
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            child: Text(
                              'Batal',
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                color: subColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const SizedBox(width: 12),
                          CustomButton(
                            text: 'Simpan Shift',
                            onPressed: () {
                              ref
                                  .read(apotekAsistenListProvider.notifier)
                                  .updateShift(s.id, tempShift);
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Shift ${s.nama} berhasil diubah ke Shift $tempShift!',
                                    style: GoogleFonts.outfit(fontSize: 12),
                                  ),
                                  backgroundColor: const Color(0xFF48C9B0),
                                ),
                              );
                            },
                            primaryColor: activeAccent,
                            textColor: Colors.white,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ─── Delete Confirmation Overlay Dialog ─────────────────────────────────────

  void _confirmDelete(BuildContext context, ApotekStaffModel s) {
    showDialog(
      context: context,
      builder: (context) {
        final isDark = ref.watch(landingPageProvider).appearance == 'dark';
        final dialogBg = isDark ? const Color(0xFF1E1E22) : Colors.white;
        final txtColor = isDark ? Colors.white : const Color(0xFF1B0C3C);
        final subColor = isDark ? Colors.grey[400]! : const Color(0xFF6F6A8A);

        return AlertDialog(
          backgroundColor: dialogBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Hapus Staff?',
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: txtColor,
            ),
          ),
          content: Text(
            'Apakah Anda yakin ingin menghapus ${s.nama} dari daftar staff apotek?',
            style: GoogleFonts.outfit(fontSize: 12, color: subColor),
          ),
          actions: [
            TextButton(
              child: Text(
                'Batal',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: subColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            TextButton(
              child: Text(
                'Hapus',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: Colors.redAccent,
                  fontWeight: FontWeight.w700,
                ),
              ),
              onPressed: () {
                ref.read(apotekAsistenListProvider.notifier).removeStaff(s.id);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Staff ${s.nama} berhasil dihapus.',
                      style: GoogleFonts.outfit(fontSize: 12),
                    ),
                    backgroundColor: Colors.redAccent,
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  // ─── Add Staff Form Overlay Dialog Wizard ───────────────────────────────────

  void _showAddStaffDialog(BuildContext context) {
    final nameController = TextEditingController();
    final nikController = TextEditingController();
    final strttkController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();
    String selectedRole = 'Asisten Apoteker';
    String selectedShift = 'Pagi';
    List<String> selectedPerms = ['POS Kasir'];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isDark = ref.watch(landingPageProvider).appearance == 'dark';
            final isRev = ref.watch(landingPageProvider).appearance == 'rev';
            final dialogBg = isDark ? const Color(0xFF1E1E22) : Colors.white;
            final txtColor = isDark ? Colors.white : const Color(0xFF1B0C3C);
            final subColor = isDark
                ? Colors.grey[400]!
                : const Color(0xFF6F6A8A);
            final inputBg = isDark
                ? const Color(0xFF282830)
                : const Color(0xFFF3F0FA);
            final themeAccent = isRev
                ? const Color(0xFFB577F2)
                : const Color(0xFF48C9B0);

            final availablePerms = [
              'POS Kasir',
              'Kelola Resep',
              'Stok Opname',
              'Inventaris Gudang',
              'Laporan Keuangan',
            ];

            return Dialog(
              backgroundColor: dialogBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 550),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Registrasi Staff Apotek Baru',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: txtColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Daftarkan asisten apoteker atau kasir baru',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          color: subColor,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Nama
                      _buildInputLabel('NAMA LENGKAP & GELAR', subColor),
                      _buildInputField(
                        nameController,
                        'Contoh: Fatimah Az-Zahra, A.Md.Farm.',
                        inputBg,
                        txtColor,
                        subColor,
                      ),
                      const SizedBox(height: 12),

                      // NIK & Peran Row
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildInputLabel(
                                  'NIK (KTP 16-DIGIT)',
                                  subColor,
                                ),
                                _buildInputField(
                                  nikController,
                                  '351108...',
                                  inputBg,
                                  txtColor,
                                  subColor,
                                  keyboardType: TextInputType.number,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildInputLabel('JABATAN APOTEK', subColor),
                                Container(
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: inputBg,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: selectedRole,
                                      dropdownColor: dialogBg,
                                      style: GoogleFonts.outfit(
                                        fontSize: 12,
                                        color: txtColor,
                                        fontWeight: FontWeight.w700,
                                      ),
                                      isExpanded: true,
                                      items:
                                          [
                                            'Asisten Apoteker',
                                            'Kasir',
                                            'Gudang',
                                            'Kurir',
                                          ].map((String role) {
                                            return DropdownMenuItem<String>(
                                              value: role,
                                              child: Text(role),
                                            );
                                          }).toList(),
                                      onChanged: (val) {
                                        setModalState(() {
                                          selectedRole =
                                              val ?? 'Asisten Apoteker';
                                        });
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // STRTTK & Shift Row
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildInputLabel(
                                  'STRTTK APOTEKER (JIKA ADA)',
                                  subColor,
                                ),
                                _buildInputField(
                                  strttkController,
                                  selectedRole == 'Asisten Apoteker'
                                      ? '1999/STRTTK/...'
                                      : 'Tidak diperlukan',
                                  inputBg,
                                  txtColor,
                                  subColor,
                                  enabled: selectedRole == 'Asisten Apoteker',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildInputLabel('SHIFT KERJA UTAMA', subColor),
                                Container(
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: inputBg,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: selectedShift,
                                      dropdownColor: dialogBg,
                                      style: GoogleFonts.outfit(
                                        fontSize: 12,
                                        color: txtColor,
                                        fontWeight: FontWeight.w700,
                                      ),
                                      isExpanded: true,
                                      items: ['Pagi', 'Sore', 'Malam'].map((
                                        String sh,
                                      ) {
                                        return DropdownMenuItem<String>(
                                          value: sh,
                                          child: Text('Shift $sh'),
                                        );
                                      }).toList(),
                                      onChanged: (val) {
                                        setModalState(() {
                                          selectedShift = val ?? 'Pagi';
                                        });
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Telepon & Email
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildInputLabel('NOMOR TELEPON', subColor),
                                _buildInputField(
                                  phoneController,
                                  '0812...',
                                  inputBg,
                                  txtColor,
                                  subColor,
                                  keyboardType: TextInputType.phone,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildInputLabel('EMAIL RESMI', subColor),
                                _buildInputField(
                                  emailController,
                                  'staff@gmail.com',
                                  inputBg,
                                  txtColor,
                                  subColor,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Username & Password
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildInputLabel('USERNAME LOGIN', subColor),
                                _buildInputField(
                                  usernameController,
                                  'staff_username',
                                  inputBg,
                                  txtColor,
                                  subColor,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildInputLabel('PASSWORD LOGIN', subColor),
                                _buildInputField(
                                  passwordController,
                                  '••••••••',
                                  inputBg,
                                  txtColor,
                                  subColor,
                                  obscureText: true,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Permissions
                      _buildInputLabel('IZIN AKSES SISTEM', subColor),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: availablePerms.map((p) {
                          final isChecked = selectedPerms.contains(p);
                          return FilterChip(
                            label: Text(
                              p,
                              style: GoogleFonts.outfit(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: isChecked ? Colors.white : txtColor,
                              ),
                            ),
                            selected: isChecked,
                            selectedColor: themeAccent,
                            checkmarkColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            onSelected: (val) {
                              setModalState(() {
                                if (val) {
                                  selectedPerms.add(p);
                                } else {
                                  selectedPerms.remove(p);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 28),

                      // Actions
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            child: Text(
                              'Batal',
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                color: subColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const SizedBox(width: 14),
                          CustomButton(
                            text: 'Simpan Staff',
                            onPressed: () async {
                              final name = nameController.text.trim();
                              final nik = nikController.text.trim();
                              final phone = phoneController.text.trim();
                              final email = emailController.text.trim();
                              final strttk = strttkController.text.trim();
                              final username = usernameController.text.trim();
                              final password = passwordController.text.trim();

                              if (name.isEmpty ||
                                  nik.isEmpty ||
                                  phone.isEmpty ||
                                  username.isEmpty ||
                                  password.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Semua field wajib diisi!',
                                      style: GoogleFonts.outfit(fontSize: 12),
                                    ),
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                                return;
                              }

                              if (nik.length < 16) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'NIK harus 16 digit!',
                                      style: GoogleFonts.outfit(fontSize: 12),
                                    ),
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                                return;
                              }

                              final String staffUuid = const Uuid().v4();
                              final newStaff = ApotekStaffModel(
                                id: staffUuid,
                                nama: name,
                                email: email.isEmpty ? '-' : email,
                                nik: nik,
                                strttk: selectedRole == 'Asisten Apoteker'
                                    ? (strttk.isEmpty ? '-' : strttk)
                                    : '-',
                                peran: selectedRole,
                                telepon: phone,
                                shift: selectedShift,
                                isStandby: true,
                                permissions: selectedPerms.isEmpty
                                    ? ['POS Kasir']
                                    : selectedPerms,
                                avatarBg: selectedRole == 'Asisten Apoteker'
                                    ? const Color(0xFF48C9B0)
                                    : (selectedRole == 'Kasir'
                                          ? const Color(0xFFB577F2)
                                          : const Color(0xFFF39C12)),
                              );

                              final nav = Navigator.of(context);
                              final messenger = ScaffoldMessenger.of(context);

                              try {
                                showDialog(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (context) => const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );

                                await ref
                                    .read(apotekAsistenListProvider.notifier)
                                    .addStaff(
                                      newStaff,
                                      username: username,
                                      password: password,
                                    );

                                nav.pop(); // Pop loading dialog
                                nav.pop(); // Pop form dialog

                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Staff $name berhasil didaftarkan!',
                                      style: GoogleFonts.outfit(fontSize: 12),
                                    ),
                                    backgroundColor: const Color(0xFF48C9B0),
                                  ),
                                );
                              } catch (e) {
                                nav.pop(); // Pop loading dialog
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Gagal mendaftarkan staff: $e',
                                      style: GoogleFonts.outfit(fontSize: 12),
                                    ),
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                              }
                            },
                            primaryColor: themeAccent,
                            textColor: Colors.white,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildInputLabel(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 4),
      child: Text(
        label,
        style: GoogleFonts.outfit(
          fontSize: 8,
          fontWeight: FontWeight.w900,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildInputField(
    TextEditingController controller,
    String hint,
    Color bg,
    Color text,
    Color subtitle, {
    TextInputType keyboardType = TextInputType.text,
    bool enabled = true,
    bool obscureText = false,
  }) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        enabled: enabled,
        obscureText: obscureText,
        style: GoogleFonts.outfit(
          fontSize: 12,
          color: enabled ? text : text.withOpacity(0.4),
          fontWeight: FontWeight.w700,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.outfit(
            fontSize: 11,
            color: subtitle.withOpacity(0.5),
            fontWeight: FontWeight.w500,
          ),
          border: InputBorder.none,
          isDense: true,
        ),
      ),
    );
  }
}
