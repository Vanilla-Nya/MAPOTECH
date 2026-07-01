import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapotech/features/landing/landing_page_data.dart';
import 'package:mapotech/shared/widgets/ui.dart';

import 'package:mapotech/shared/supabase_service.dart';
import 'dart:math';

// ─── UUID Generation Helper ──────────────────────────────────────────────────

String _generateUuidV4() {
  final random = Random.secure();
  final values = List<int>.generate(16, (i) => random.nextInt(256));
  
  // Set version to 4
  values[6] = (values[6] & 0x0f) | 0x40;
  // Set variant to 10xx
  values[8] = (values[8] & 0x3f) | 0x80;
  
  final buffer = StringBuffer();
  for (var i = 0; i < 16; i++) {
    if (i == 4 || i == 6 || i == 8 || i == 10) {
      buffer.write('-');
    }
    buffer.write(values[i].toRadixString(16).padLeft(2, '0'));
  }
  return buffer.toString();
}

// ─── Data Models ─────────────────────────────────────────────────────────────

class AsistenModel {
  final String id;
  final String nama;
  final String email;
  final String nik;
  final String sip; // Optional: Surat Izin Praktik (Perawat)
  final String peran; // 'Perawat', 'Front Desk', 'Administrator'
  final String telepon;
  final bool isBertugas;
  final List<String> permissions;
  final Color avatarBg;

  const AsistenModel({
    required this.id,
    required this.nama,
    required this.email,
    required this.nik,
    required this.sip,
    required this.peran,
    required this.telepon,
    required this.isBertugas,
    required this.permissions,
    required this.avatarBg,
  });

  AsistenModel copyWith({
    String? id,
    String? nama,
    String? email,
    String? nik,
    String? sip,
    String? peran,
    String? telepon,
    bool? isBertugas,
    List<String>? permissions,
    Color? avatarBg,
  }) {
    return AsistenModel(
      id: id ?? this.id,
      nama: nama ?? this.nama,
      email: email ?? this.email,
      nik: nik ?? this.nik,
      sip: sip ?? this.sip,
      peran: peran ?? this.peran,
      telepon: telepon ?? this.telepon,
      isBertugas: isBertugas ?? this.isBertugas,
      permissions: permissions ?? this.permissions,
      avatarBg: avatarBg ?? this.avatarBg,
    );
  }
}

// ─── Riverpod State Provider ──────────────────────────────────────────────────

class DokterAsistenListNotifier extends StateNotifier<List<AsistenModel>> {
  final String doctorId;
  final SupabaseService _db = SupabaseService();
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  DokterAsistenListNotifier(this.doctorId) : super([]) {
    loadAssistants();
  }

  Future<void> loadAssistants() async {
    _isLoading = true;
    try {
      final dbAssistants = await _db.fetchDoctorAssistants(doctorId);
      state = dbAssistants.map((da) {
        final roles = da['permissions'] as List<dynamic>? ?? [];
        return AsistenModel(
          id: da['id'] as String,
          nama: da['nama'] as String,
          email: da['email'] as String? ?? '-',
          nik: da['nik'] as String,
          sip: da['sip'] as String? ?? '-',
          peran: da['peran'] as String? ?? 'Perawat',
          telepon: da['telepon'] as String? ?? '-',
          isBertugas: da['is_bertugas'] as bool? ?? true,
          permissions: roles.map((r) => r.toString()).toList(),
          avatarBg: da['peran'] == 'Perawat'
              ? const Color(0xFF48C9B0)
              : (da['peran'] == 'Front Desk' ? const Color(0xFFB577F2) : const Color(0xFFF39C12)),
        );
      }).toList();
    } catch (e) {
      debugPrint('Error loading assistants: $e');
    } finally {
      _isLoading = false;
      if (mounted) {
        state = List.from(state);
      }
    }
  }

  Future<void> addAsisten(AsistenModel asisten) async {
    try {
      await _db.addDoctorAssistant(
        doctorId: doctorId,
        assistantId: asisten.id,
        name: asisten.nama,
        email: asisten.email,
        nik: asisten.nik,
        phone: asisten.telepon,
        sip: asisten.sip,
        peran: asisten.peran,
        permissions: asisten.permissions,
      );
      await loadAssistants();
    } catch (e) {
      debugPrint('Error adding assistant: $e');
      rethrow;
    }
  }

  Future<void> toggleDuty(String id) async {
    try {
      final assistant = state.firstWhere((a) => a.id == id);
      final nextDuty = !assistant.isBertugas;

      // Optimistic UI response
      state = [
        for (final a in state)
          if (a.id == id) a.copyWith(isBertugas: nextDuty) else a
      ];

      await _db.updateDoctorAssistantDuty(id, nextDuty);
    } catch (e) {
      debugPrint('Error toggling duty: $e');
      await loadAssistants();
    }
  }

  Future<void> removeAsisten(String id) async {
    try {
      await _db.deleteDoctorAssistant(id);
      await loadAssistants();
    } catch (e) {
      debugPrint('Error removing assistant: $e');
      rethrow;
    }
  }

  Future<void> updatePermissions(String id, List<String> permissions) async {
    try {
      // Optimistic update
      state = [
        for (final a in state)
          if (a.id == id) a.copyWith(permissions: permissions) else a
      ];
      await _db.updateDoctorAssistantPermissions(id, permissions);
    } catch (e) {
      debugPrint('Error updating permissions: $e');
      await loadAssistants();
    }
  }
}

final dokterAsistenListProvider =
    StateNotifierProvider<DokterAsistenListNotifier, List<AsistenModel>>((ref) {
  final userState = ref.watch(landingPageProvider).loggedInUser;
  final doctorId = userState?['id']?.toString() ?? '8f93471a-74f8-486b-8e85-4002dc44c11c';
  return DokterAsistenListNotifier(doctorId);
});


// ─── Dokter Asisten View ───────────────────────────────────────────────────────

class DokterAsisten extends ConsumerStatefulWidget {
  const DokterAsisten({super.key});

  @override
  ConsumerState<DokterAsisten> createState() => _DokterAsistenState();
}

class _DokterAsistenState extends ConsumerState<DokterAsisten> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(landingPageProvider);
    final allAssistants = ref.watch(dokterAsistenListProvider);
    final isLoading = ref.watch(dokterAsistenListProvider.notifier).isLoading;

    final isDark = state.appearance == 'dark';
    final cardBgColor = isDark ? const Color(0xFF161619) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1B0C3C);
    final subtitleColor = isDark ? Colors.grey[400]! : const Color(0xFF6F6A8A);
    final borderColor = isDark ? const Color(0xFF252528) : const Color(0xFFECEEF2);
    final purpleAccent = const Color(0xFFB577F2);
    final isMobile = MediaQuery.of(context).size.width < 768;

    // Filtered list
    final filteredAssistants = allAssistants.where((a) {
      final q = _searchQuery.toLowerCase();
      return a.nama.toLowerCase().contains(q) ||
          a.nik.contains(q) ||
          a.peran.toLowerCase().contains(q);
    }).toList();

    // Summary counts
    final totalStaff = allAssistants.length;
    final activeStaff = allAssistants.where((a) => a.isBertugas).length;
    final nursesCount = allAssistants.where((a) => a.peran == 'Perawat').length;
    final adminsCount = allAssistants.where((a) => a.peran != 'Perawat').length;

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
              icon: Icons.people_outline_rounded,
              label: 'TOTAL ASISTEN'.tr(state),
              count: '$totalStaff ' + (state.language == 'en' ? 'People' : 'Orang'),
              subtitleColor: subtitleColor,
              countColor: textColor,
              cardBgColor: cardBgColor,
              borderColor: borderColor,
            ),
            MetricCard(
              icon: Icons.check_circle_outline_rounded,
              label: 'BERTUGAS HARI INI'.tr(state),
              count: '$activeStaff ' + (state.language == 'en' ? 'Active' : 'Aktif'),
              subtitleColor: subtitleColor,
              countColor: const Color(0xFF48C9B0),
              cardBgColor: cardBgColor,
              borderColor: borderColor,
            ),
            MetricCard(
              icon: Icons.medical_services_outlined,
              label: 'PERAWAT KLINIK'.tr(state),
              count: '$nursesCount ' + (state.language == 'en' ? 'People' : 'Orang'),
              subtitleColor: subtitleColor,
              countColor: purpleAccent,
              cardBgColor: cardBgColor,
              borderColor: borderColor,
            ),
            MetricCard(
              icon: Icons.badge_outlined,
              label: 'ADMIN / FRONT DESK'.tr(state),
              count: '$adminsCount ' + (state.language == 'en' ? 'People' : 'Orang'),
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
                        style: GoogleFonts.outfit(fontSize: 12, color: textColor),
                        decoration: InputDecoration(
                          hintText: 'Cari nama, NIK, atau peran asisten...'.tr(state),
                          hintStyle: GoogleFonts.outfit(fontSize: 11, color: subtitleColor.withOpacity(0.6)),
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
              text: '+ Tambah Asisten'.tr(state),
              onPressed: () {
                _showAddAssistantDialog(context);
              },
              primaryColor: purpleAccent,
              textColor: Colors.white,
            ),
          ],
        ),

        const SizedBox(height: 24),

        // ── Assistant Cards Grid ──────────────────────────────────────────
        if (isLoading && allAssistants.isEmpty)
          const SkeletonScope(
            child: SkeletonAssistantGrid(),
          )
        else if (filteredAssistants.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 60),
            alignment: Alignment.center,
            child: Column(
              children: [
                Icon(Icons.badge_outlined, size: 48, color: subtitleColor.withOpacity(0.3)),
                const SizedBox(height: 16),
                Text(
                  'Asisten tidak ditemukan',
                  style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: subtitleColor),
                ),
              ],
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filteredAssistants.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isMobile ? 1 : 3,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              mainAxisExtent: 280,
            ),
            itemBuilder: (context, index) {
              final a = filteredAssistants[index];
              return _buildAssistantCard(context, a, cardBgColor, borderColor, textColor, subtitleColor, purpleAccent);
            },
          ),
      ],
    );
  }

  // ─── Assistant Card Widget ──────────────────────────────────────────────────

  Widget _buildAssistantCard(
    BuildContext context,
    AsistenModel a,
    Color cardBg,
    Color border,
    Color text,
    Color subtitle,
    Color purple,
  ) {
    final roleColor = a.peran == 'Perawat'
        ? const Color(0xFF48C9B0)
        : (a.peran == 'Front Desk' ? const Color(0xFFB577F2) : const Color(0xFFF39C12));

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
                  color: a.avatarBg.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  a.nama.substring(0, 2).toUpperCase(),
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: a.avatarBg,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      a.nama,
                      style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: text),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: roleColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        a.peran.toUpperCase(),
                        style: GoogleFonts.outfit(fontSize: 7, fontWeight: FontWeight.w900, color: roleColor, letterSpacing: 0.5),
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
          _buildDetailRow(Icons.badge_outlined, 'NIK: ${a.nik}', subtitle),
          if (a.peran == 'Perawat')
            _buildDetailRow(Icons.assignment_ind_outlined, 'SIP: ${a.sip}', subtitle)
          else
            _buildDetailRow(Icons.assignment_ind_outlined, 'SIP: Tidak diperlukan', subtitle),
          _buildDetailRow(Icons.phone_outlined, a.telepon, subtitle),

          const SizedBox(height: 12),

          // Access Permissions Badges
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: a.permissions.map((p) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: subtitle.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: border),
                  ),
                  child: Text(
                    p,
                    style: GoogleFonts.outfit(fontSize: 8, color: text.withOpacity(0.8), fontWeight: FontWeight.w600),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 12),

          // Footer actions: isBertugas toggle & nonaktifkan
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // isBertugas Switch
              Row(
                children: [
                  Text(
                    a.isBertugas ? 'BERTUGAS' : 'LIBUR',
                    style: GoogleFonts.outfit(
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      color: a.isBertugas ? const Color(0xFF48C9B0) : subtitle,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    height: 18,
                    width: 32,
                    child: Switch(
                      value: a.isBertugas,
                      activeColor: const Color(0xFF48C9B0),
                      onChanged: (val) {
                        ref.read(dokterAsistenListProvider.notifier).toggleDuty(a.id);
                      },
                    ),
                  ),
                ],
              ),

              // Modify/Remove Row
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.security_rounded, size: 14, color: subtitle),
                    onPressed: () {
                      _showEditPermissionsDialog(context, a);
                    },
                    tooltip: 'Ubah Izin Akses',
                    visualDensity: VisualDensity.compact,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 14, color: Colors.redAccent),
                    onPressed: () {
                      _confirmDelete(context, a);
                    },
                    tooltip: 'Hapus Asisten',
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
              style: GoogleFonts.outfit(fontSize: 10, color: subtitle, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Edit Permissions Overlay Dialog ────────────────────────────────────────

  void _showEditPermissionsDialog(BuildContext context, AsistenModel a) {
    final available = ['Rekam Medis (EMR)', 'Pemeriksaan Awal', 'Registrasi & Antrian', 'Billing / Kasir', 'Stok Obat'];
    List<String> tempPermissions = List.from(a.permissions);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isDark = ref.watch(landingPageProvider).appearance == 'dark';
            final dialogBg = isDark ? const Color(0xFF1E1E22) : Colors.white;
            final txtColor = isDark ? Colors.white : const Color(0xFF1B0C3C);
            final subColor = isDark ? Colors.grey[400]! : const Color(0xFF6F6A8A);
            final activePurple = const Color(0xFFB577F2);

            return Dialog(
              backgroundColor: dialogBg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Izin Akses Asisten',
                        style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900, color: txtColor),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Sesuaikan hak akses untuk ${a.nama}',
                        style: GoogleFonts.outfit(fontSize: 11, color: subColor),
                      ),
                      const SizedBox(height: 18),
                      Column(
                        children: available.map((p) {
                          final isChecked = tempPermissions.contains(p);
                          return CheckboxListTile(
                            title: Text(
                              p,
                              style: GoogleFonts.outfit(fontSize: 12, color: txtColor, fontWeight: FontWeight.w600),
                            ),
                            value: isChecked,
                            activeColor: activePurple,
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            onChanged: (val) {
                              setModalState(() {
                                if (val == true) {
                                  tempPermissions.add(p);
                                } else {
                                  tempPermissions.remove(p);
                                }
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
                            child: Text('Batal', style: GoogleFonts.outfit(fontSize: 12, color: subColor, fontWeight: FontWeight.w700)),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const SizedBox(width: 12),
                          CustomButton(
                            text: 'Simpan Izin',
                            onPressed: () {
                              ref.read(dokterAsistenListProvider.notifier).updatePermissions(a.id, tempPermissions);
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Izin akses ${a.nama} berhasil diperbarui!', style: GoogleFonts.outfit(fontSize: 12)),
                                  backgroundColor: const Color(0xFF48C9B0),
                                ),
                              );
                            },
                            primaryColor: activePurple,
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

  void _confirmDelete(BuildContext context, AsistenModel a) {
    showDialog(
      context: context,
      builder: (context) {
        final isDark = ref.watch(landingPageProvider).appearance == 'dark';
        final dialogBg = isDark ? const Color(0xFF1E1E22) : Colors.white;
        final txtColor = isDark ? Colors.white : const Color(0xFF1B0C3C);
        final subColor = isDark ? Colors.grey[400]! : const Color(0xFF6F6A8A);

        return AlertDialog(
          backgroundColor: dialogBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Hapus Asisten?',
            style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900, color: txtColor),
          ),
          content: Text(
            'Apakah Anda yakin ingin menghapus ${a.nama} dari daftar asisten praktik?',
            style: GoogleFonts.outfit(fontSize: 12, color: subColor),
          ),
          actions: [
            TextButton(
              child: Text('Batal', style: GoogleFonts.outfit(fontSize: 12, color: subColor, fontWeight: FontWeight.w700)),
              onPressed: () => Navigator.pop(context),
            ),
            TextButton(
              child: Text('Hapus', style: GoogleFonts.outfit(fontSize: 12, color: Colors.redAccent, fontWeight: FontWeight.w700)),
              onPressed: () {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const Center(child: CircularProgressIndicator()),
                );
                ref.read(dokterAsistenListProvider.notifier).removeAsisten(a.id).then((_) {
                  Navigator.pop(context); // Pop loading indicator
                  Navigator.pop(context); // Pop confirm dialog
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Asisten ${a.nama} berhasil dihapus.', style: GoogleFonts.outfit(fontSize: 12)),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }).catchError((err) {
                  Navigator.pop(context); // Pop loading indicator
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Gagal menghapus asisten: $err', style: GoogleFonts.outfit(fontSize: 12)),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                });
              },
            ),
          ],
        );
      },
    );
  }

  // ─── Add Assistant Form Overlay Dialog Wizard ───────────────────────────────

  void _showAddAssistantDialog(BuildContext context) {
    final nameController = TextEditingController();
    final nikController = TextEditingController();
    final sipController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();
    String selectedRole = 'Perawat';
    List<String> selectedPerms = ['Rekam Medis (EMR)'];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final state = ref.watch(landingPageProvider);
            final isDark = state.appearance == 'dark';
            final dialogBg = isDark ? const Color(0xFF1E1E22) : Colors.white;
            final txtColor = isDark ? Colors.white : const Color(0xFF1B0C3C);
            final subColor = isDark ? Colors.grey[400]! : const Color(0xFF6F6A8A);
            final inputBg = isDark ? const Color(0xFF282830) : const Color(0xFFF3F0FA);
            final purple = const Color(0xFFB577F2);

            final availablePerms = ['Rekam Medis (EMR)', 'Pemeriksaan Awal', 'Registrasi & Antrian', 'Billing / Kasir', 'Stok Obat'];

            return Dialog(
              backgroundColor: dialogBg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 550),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Registrasi Asisten Baru'.tr(state),
                        style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900, color: txtColor),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Daftarkan asisten klinik praktik mandiri Anda'.tr(state),
                        style: GoogleFonts.outfit(fontSize: 11, color: subColor),
                      ),
                      const SizedBox(height: 20),

                      // Nama
                      _buildInputLabel('NAMA LENGKAP & GELAR'.tr(state), subColor),
                      _buildInputField(nameController, 'Contoh: Siti Aminah, A.Md.Kep.'.tr(state), inputBg, txtColor, subColor),
                      const SizedBox(height: 12),

                      // NIK & Peran Row
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildInputLabel('NIK (KTP 16-DIGIT)'.tr(state), subColor),
                                _buildInputField(nikController, '351108...', inputBg, txtColor, subColor, keyboardType: TextInputType.number),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildInputLabel('PERAN / JABATAN'.tr(state), subColor),
                                Container(
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: inputBg,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: selectedRole,
                                      dropdownColor: dialogBg,
                                      style: GoogleFonts.outfit(fontSize: 12, color: txtColor, fontWeight: FontWeight.w700),
                                      isExpanded: true,
                                      items: ['Perawat', 'Front Desk', 'Administrator'].map((String role) {
                                        return DropdownMenuItem<String>(
                                          value: role,
                                          child: Text(role.tr(state)),
                                        );
                                      }).toList(),
                                      onChanged: (val) {
                                        setModalState(() {
                                          selectedRole = val ?? 'Perawat';
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

                      // SIP (only if nurse)
                      if (selectedRole == 'Perawat') ...[
                        _buildInputLabel('SURAT IZIN PRAKTEK (SIP) PERAWAT'.tr(state), subColor),
                        _buildInputField(sipController, 'Contoh: 503/1204/SIP.P/...'.tr(state), inputBg, txtColor, subColor),
                        const SizedBox(height: 12),
                      ],

                      // Telepon & Email
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildInputLabel('NOMOR TELEPON'.tr(state), subColor),
                                _buildInputField(phoneController, '0812...', inputBg, txtColor, subColor, keyboardType: TextInputType.phone),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildInputLabel('EMAIL KLINIK'.tr(state), subColor),
                                _buildInputField(emailController, 'asisten@gmail.com', inputBg, txtColor, subColor),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Permissions
                      _buildInputLabel('IZIN AKSES UTAMA'.tr(state), subColor),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: availablePerms.map((p) {
                          final isChecked = selectedPerms.contains(p);
                          return FilterChip(
                            label: Text(
                              p.tr(state),
                              style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.bold, color: isChecked ? Colors.white : txtColor),
                            ),
                            selected: isChecked,
                            selectedColor: purple,
                            checkmarkColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                            child: Text('Batal'.tr(state), style: GoogleFonts.outfit(fontSize: 12, color: subColor, fontWeight: FontWeight.w700)),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const SizedBox(width: 14),
                          CustomButton(
                            text: 'Simpan Asisten'.tr(state),
                            onPressed: () {
                              final name = nameController.text.trim();
                              final nik = nikController.text.trim();
                              final phone = phoneController.text.trim();
                              final email = emailController.text.trim();
                              final sip = sipController.text.trim();

                              if (name.isEmpty || nik.isEmpty || phone.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Nama, NIK, dan Telepon wajib diisi!', style: GoogleFonts.outfit(fontSize: 12)),
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                                return;
                              }

                              if (nik.length < 16) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('NIK harus 16 digit!', style: GoogleFonts.outfit(fontSize: 12)),
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                                return;
                              }

                              final newId = _generateUuidV4();
                              final newAsisten = AsistenModel(
                                id: newId,
                                nama: name,
                                email: email.isEmpty ? '-' : email,
                                nik: nik,
                                sip: selectedRole == 'Perawat' ? (sip.isEmpty ? '-' : sip) : '-',
                                peran: selectedRole,
                                telepon: phone,
                                isBertugas: true,
                                permissions: selectedPerms.isEmpty ? ['Pemeriksaan Awal'] : selectedPerms,
                                avatarBg: selectedRole == 'Perawat'
                                    ? const Color(0xFF48C9B0)
                                    : (selectedRole == 'Front Desk' ? const Color(0xFFB577F2) : const Color(0xFFF39C12)),
                              );

                              showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (context) => const Center(child: CircularProgressIndicator()),
                              );

                              ref.read(dokterAsistenListProvider.notifier).addAsisten(newAsisten).then((_) {
                                Navigator.pop(context); // Pop loading spinner
                                Navigator.pop(context); // Pop add dialog
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Asisten $name berhasil didaftarkan!', style: GoogleFonts.outfit(fontSize: 12)),
                                    backgroundColor: const Color(0xFF48C9B0),
                                  ),
                                );
                              }).catchError((err) {
                                Navigator.pop(context); // Pop loading spinner
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Gagal mendaftarkan asisten: $err', style: GoogleFonts.outfit(fontSize: 12)),
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                              });
                            },
                            primaryColor: purple,
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
        style: GoogleFonts.outfit(fontSize: 8, fontWeight: FontWeight.w900, color: color, letterSpacing: 0.5),
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
        style: GoogleFonts.outfit(fontSize: 12, color: text, fontWeight: FontWeight.w700),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.outfit(fontSize: 11, color: subtitle.withOpacity(0.5), fontWeight: FontWeight.w500),
          border: InputBorder.none,
          isDense: true,
        ),
      ),
    );
  }
}
