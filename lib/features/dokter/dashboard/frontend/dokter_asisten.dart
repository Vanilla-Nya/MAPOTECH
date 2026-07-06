import 'package:flutter/material.dart';
import 'dart:ui' show PathMetric;
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
  final String username;
  final String gender;
  final String birthPlace;
  final String birthDate;
  final String address;
  final String province;
  final String district;
  final String subDistrict;
  final String village;
  final String createdAt;

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
    required this.username,
    required this.gender,
    required this.birthPlace,
    required this.birthDate,
    required this.address,
    required this.province,
    required this.district,
    required this.subDistrict,
    required this.village,
    required this.createdAt,
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
    String? username,
    String? gender,
    String? birthPlace,
    String? birthDate,
    String? address,
    String? province,
    String? district,
    String? subDistrict,
    String? village,
    String? createdAt,
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
      username: username ?? this.username,
      gender: gender ?? this.gender,
      birthPlace: birthPlace ?? this.birthPlace,
      birthDate: birthDate ?? this.birthDate,
      address: address ?? this.address,
      province: province ?? this.province,
      district: district ?? this.district,
      subDistrict: subDistrict ?? this.subDistrict,
      village: village ?? this.village,
      createdAt: createdAt ?? this.createdAt,
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

  List<String> _mapDbPermissionsToUi(List<dynamic> dbPerms) {
    final Set<String> uiPerms = {};
    for (final perm in dbPerms) {
      final p = perm.toString();
      if (p == 'Rekam Medis (EMR)') {
        uiPerms.add('PASIEN');
        uiPerms.add('DASHBOARD');
      } else if (p == 'Pemeriksaan Awal') {
        uiPerms.add('PEMERIKSAAN');
        uiPerms.add('DASHBOARD');
      } else if (p == 'Registrasi & Antrian') {
        uiPerms.add('ANTRIAN');
        uiPerms.add('DASHBOARD');
      } else if (p == 'Billing / Kasir') {
        uiPerms.add('PEMBUKUAN');
        uiPerms.add('DASHBOARD');
      } else if (p == 'Stok Obat') {
        uiPerms.add('OBAT');
        uiPerms.add('DASHBOARD');
      } else {
        uiPerms.add(p);
      }
    }
    return uiPerms.toList();
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
          permissions: _mapDbPermissionsToUi(roles),
          avatarBg: da['peran'] == 'Perawat'
              ? const Color(0xFF48C9B0)
              : (da['peran'] == 'Front Desk'
                    ? const Color(0xFFB577F2)
                    : const Color(0xFFF39C12)),
          username: da['username'] as String? ?? '',
          gender: da['gender'] as String? ?? 'Male',
          birthPlace: da['birth_place'] as String? ?? '',
          birthDate: da['birth_date'] as String? ?? '',
          address: da['address'] as String? ?? '',
          province: da['province'] as String? ?? '',
          district: da['district'] as String? ?? '',
          subDistrict: da['sub_district'] as String? ?? '',
          village: da['village'] as String? ?? '',
          createdAt: da['created_at'] as String? ?? '',
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

  Future<void> addAsisten(AsistenModel asisten, String password) async {
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
        username: asisten.username,
        password: password,
        gender: asisten.gender,
        birthPlace: asisten.birthPlace,
        birthDate: asisten.birthDate,
        address: asisten.address,
        province: asisten.province,
        district: asisten.district,
        subDistrict: asisten.subDistrict,
        village: asisten.village,
      );
      await loadAssistants();
    } catch (e) {
      debugPrint('Error adding assistant: $e');
      rethrow;
    }
  }

  Future<void> updateAsisten(AsistenModel asisten, {String? password}) async {
    try {
      await _db.updateDoctorAssistant(
        assistantId: asisten.id,
        name: asisten.nama,
        email: asisten.email,
        nik: asisten.nik,
        phone: asisten.telepon,
        sip: asisten.sip,
        peran: asisten.peran,
        username: asisten.username,
        gender: asisten.gender,
        birthPlace: asisten.birthPlace,
        birthDate: asisten.birthDate,
        address: asisten.address,
        province: asisten.province,
        district: asisten.district,
        subDistrict: asisten.subDistrict,
        village: asisten.village,
        password: password,
      );
      await loadAssistants();
    } catch (e) {
      debugPrint('Error updating assistant: $e');
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
          if (a.id == id) a.copyWith(isBertugas: nextDuty) else a,
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
          if (a.id == id) a.copyWith(permissions: permissions) else a,
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
      final userState = ref.watch(landingPageProvider);
      final doctorId =
          userState.activeDoctorId ??
          '8f93471a-74f8-486b-8e85-4002dc44c11c';
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
    final borderColor = isDark
        ? const Color(0xFF252528)
        : const Color(0xFFECEEF2);
    final isRev = state.appearance == 'rev';
    final themeAccent = isRev ? const Color(0xFFB577F2) : const Color(0xFF48C9B0);
    final purpleAccent = themeAccent;
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
              count:
                  '$totalStaff ${state.language == 'en' ? 'People' : 'Orang'}',
              subtitleColor: subtitleColor,
              countColor: textColor,
              cardBgColor: cardBgColor,
              borderColor: borderColor,
            ),
            MetricCard(
              icon: Icons.check_circle_outline_rounded,
              label: 'BERTUGAS HARI INI'.tr(state),
              count:
                  '$activeStaff ${state.language == 'en' ? 'Active' : 'Aktif'}',
              subtitleColor: subtitleColor,
              countColor: const Color(0xFF48C9B0),
              cardBgColor: cardBgColor,
              borderColor: borderColor,
            ),
            MetricCard(
              icon: Icons.medical_services_outlined,
              label: 'PERAWAT KLINIK'.tr(state),
              count:
                  '$nursesCount ${state.language == 'en' ? 'People' : 'Orang'}',
              subtitleColor: subtitleColor,
              countColor: purpleAccent,
              cardBgColor: cardBgColor,
              borderColor: borderColor,
            ),
            MetricCard(
              icon: Icons.badge_outlined,
              label: 'ADMIN / FRONT DESK'.tr(state),
              count:
                  '$adminsCount ${state.language == 'en' ? 'People' : 'Orang'}',
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
                          hintText: 'Cari nama, NIK, atau peran asisten...'.tr(
                            state,
                          ),
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
          const SkeletonScope(child: SkeletonAssistantGrid())
        else if (allAssistants.isEmpty)
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: isMobile ? 1 : 3,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: isMobile ? 1.4 : 1.2,
            children: [
              _buildRegisterAssistantCard(
                context,
                cardBgColor,
                borderColor,
                textColor,
                subtitleColor,
              ),
            ],
          )
        else if (filteredAssistants.isEmpty)
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
                  'Asisten tidak ditemukan',
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
            itemCount: filteredAssistants.length + 1,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isMobile ? 1 : 3,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              mainAxisExtent: 280,
            ),
            itemBuilder: (context, index) {
              if (index < filteredAssistants.length) {
                final a = filteredAssistants[index];
                return _buildAssistantCard(
                  context,
                  a,
                  cardBgColor,
                  borderColor,
                  textColor,
                  subtitleColor,
                  purpleAccent,
                );
              } else {
                return _buildRegisterAssistantCard(
                  context,
                  cardBgColor,
                  borderColor,
                  textColor,
                  subtitleColor,
                );
              }
            },
          ),
      ],
    );
  }

  // ─── Dashed Border Painter ──────────────────────────────────────────────────

  Widget _buildRegisterAssistantCard(
    BuildContext context,
    Color cardBg,
    Color border,
    Color text,
    Color subtitle,
  ) {
    return GestureDetector(
      onTap: () => _showAddAssistantDialog(context),
      child: CustomPaint(
        painter: DashedBorderPainter(color: border),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: cardBg.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: border),
                ),
                child: Icon(Icons.add, color: text.withOpacity(0.8), size: 20),
              ),
              const SizedBox(height: 18),
              Text(
                'Register New Assistant',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: text,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Complete the form below to add a new doctor assistant.',
                style: GoogleFonts.outfit(fontSize: 9, color: subtitle),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
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
        : (a.peran == 'Front Desk'
              ? const Color(0xFFB577F2)
              : const Color(0xFFF39C12));

    return GestureDetector(
      onTap: () {
        _showAssistantDetailDialog(context, a);
      },
      child: Container(
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
                    a.nama.substring(0, min(2, a.nama.length)).toUpperCase(),
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
                          a.peran.toUpperCase(),
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
            _buildDetailRow(Icons.badge_outlined, 'NIK: ${a.nik}', subtitle),
            if (a.peran == 'Perawat')
              _buildDetailRow(
                Icons.assignment_ind_outlined,
                'SIP: ${a.sip}',
                subtitle,
              )
            else
              _buildDetailRow(
                Icons.assignment_ind_outlined,
                'SIP: Tidak diperlukan',
                subtitle,
              ),
            _buildDetailRow(Icons.phone_outlined, a.telepon, subtitle),

            const SizedBox(height: 12),

            // Access Permissions Badges
            Expanded(
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: a.permissions.map((p) {
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

            // Footer actions: nonaktifkan & izin akses
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: Icon(
                    Icons.security_rounded,
                    size: 14,
                    color: subtitle,
                  ),
                  onPressed: () {
                    _showAssistantDetailDialog(
                      context,
                      a,
                      startTabIndex: 1,
                    );
                  },
                  tooltip: 'Ubah Izin Akses',
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    size: 14,
                    color: Colors.redAccent,
                  ),
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

  // ─── Assistant Detail Dialog Popup (Tabs: Data Personal, Izin Akses) ────────

  void _showAssistantDetailDialog(
    BuildContext context,
    AsistenModel a, {
    int startTabIndex = 0,
  }) {
    showDialog(
      context: context,
      builder: (context) {
        return DefaultTabController(
          length: 2,
          initialIndex: startTabIndex,
          child: StatefulBuilder(
            builder: (context, setModalState) {
              final state = ref.watch(landingPageProvider);
              final isDark = state.appearance == 'dark';
              final dialogBg = isDark ? const Color(0xFF1E1E22) : Colors.white;
              final txtColor = isDark ? Colors.white : const Color(0xFF1B0C3C);
              final subColor = isDark
                  ? Colors.grey[400]!
                  : const Color(0xFF6F6A8A);
              final borderColor = isDark
                  ? const Color(0xFF2E2E32)
                  : const Color(0xFFECEEF2);
              final purpleAccent = state.appearance == 'rev'
                  ? const Color(0xFFB577F2)
                  : const Color(0xFF48C9B0);

              final availablePerms = [
                'DASHBOARD',
                'PASIEN',
                'OBAT',
                'ANTRIAN',
                'PEMERIKSAAN',
                'PEMBUKUAN',
                'ASISTEN',
              ];

              final roleTemplates = {
                'Standard Assistant (Default)': [
                  'DASHBOARD',
                  'PASIEN',
                  'OBAT',
                  'ANTRIAN',
                  'PEMERIKSAAN',
                ],
                'Front Desk': ['DASHBOARD', 'PASIEN', 'ANTRIAN'],
                'Administrator': [
                  'DASHBOARD',
                  'PASIEN',
                  'OBAT',
                  'ANTRIAN',
                  'PEMERIKSAAN',
                  'PEMBUKUAN',
                  'ASISTEN',
                ],
              };

              // Re-fetch current state of this assistant from notifier list
              final currentAsistList = ref.watch(dokterAsistenListProvider);
              final currentA = currentAsistList.firstWhere(
                (item) => item.id == a.id,
                orElse: () => a,
              );

              // Determine selected template role based on permissions
              String matchedRoleTemplate = 'Custom';
              roleTemplates.forEach((key, val) {
                if (val.length == currentA.permissions.length &&
                    val.every((p) => currentA.permissions.contains(p))) {
                  matchedRoleTemplate = key;
                }
              });

              return Dialog(
                backgroundColor: dialogBg,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 620,
                    maxHeight: 680,
                  ),
                  child: Column(
                    children: [
                      // Purple Header Area
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            height: 120,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  purpleAccent.withOpacity(0.8),
                                  purpleAccent.withOpacity(0.5),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(24),
                                topRight: Radius.circular(24),
                              ),
                            ),
                          ),
                          // Close button
                          Positioned(
                            top: 14,
                            right: 14,
                            child: IconButton(
                              icon: const Icon(
                                Icons.close_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ),
                          // Status Badge
                          Positioned(
                            bottom: 14,
                            right: 20,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.24),
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: currentA.isBertugas
                                          ? const Color(0xFF48C9B0)
                                          : subColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    currentA.isBertugas ? 'ACTIVE' : 'LIBUR',
                                    style: GoogleFonts.outfit(
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Initials Avatar
                          Positioned(
                            left: 24,
                            bottom: -24,
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: currentA.avatarBg,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 4,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.12),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                currentA.nama
                                    .substring(0, min(2, currentA.nama.length))
                                    .toUpperCase(),
                                style: GoogleFonts.outfit(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 36),

                      // Tabs Selector
                      TabBar(
                        labelColor: purpleAccent,
                        unselectedLabelColor: subColor,
                        indicatorColor: purpleAccent,
                        labelStyle: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                        unselectedLabelStyle: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                        indicatorSize: TabBarIndicatorSize.label,
                        tabs: const [
                          Tab(text: 'DATA PERSONAL'),
                          Tab(text: 'IZIN AKSES'),
                        ],
                      ),

                      Divider(color: borderColor, height: 1),

                      // Tabs Content
                      Expanded(
                        child: TabBarView(
                          children: [
                            // Tab 1: DATA PERSONAL
                            SingleChildScrollView(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Name and Username
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              currentA.nama,
                                              style: GoogleFonts.outfit(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w900,
                                                color: txtColor,
                                              ),
                                            ),
                                            Text(
                                              currentA.username.isEmpty
                                                  ? '@${currentA.nama.split(' ').first.toLowerCase()}'
                                                  : '@${currentA.username}',
                                              style: GoogleFonts.outfit(
                                                fontSize: 12,
                                                color: purpleAccent,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      TextButton.icon(
                                        icon: Icon(
                                          Icons.edit_outlined,
                                          size: 14,
                                          color: purpleAccent,
                                        ),
                                        label: Text(
                                          'Edit',
                                          style: GoogleFonts.outfit(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: purpleAccent,
                                          ),
                                        ),
                                        onPressed: () async {
                                          _showEditAssistantInfoDialog(
                                            context,
                                            currentA,
                                          );
                                          setModalState(() {});
                                        },
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 20),

                                  // Two Column Grid
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Left Column: Informasi Pribadi
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            _buildSectionLabel(
                                              'INFORMASI PRIBADI',
                                              subColor,
                                            ),
                                            const SizedBox(height: 8),
                                            _buildInfoTile(
                                              Icons.badge_outlined,
                                              'NIK (KTP)',
                                              currentA.nik,
                                              subColor,
                                              txtColor,
                                            ),
                                            _buildInfoTile(
                                              Icons.cake_outlined,
                                              'TEMPAT & TANGGAL LAHIR',
                                              '${currentA.birthPlace.isEmpty ? 'Bondowoso' : currentA.birthPlace}, ${currentA.birthDate.isEmpty ? '2005-07-13' : currentA.birthDate}',
                                              subColor,
                                              txtColor,
                                            ),
                                            _buildInfoTile(
                                              Icons.email_outlined,
                                              'ALAMAT EMAIL',
                                              currentA.email,
                                              subColor,
                                              txtColor,
                                            ),
                                          ],
                                        ),
                                      ),

                                      const SizedBox(width: 24),

                                      // Right Column: Detail Pekerjaan
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            _buildSectionLabel(
                                              'DETAIL PEKERJAAN',
                                              subColor,
                                            ),
                                            const SizedBox(height: 8),
                                            _buildInfoTile(
                                              Icons.phone_iphone_rounded,
                                              'WHATSAPP / TELEPON',
                                              currentA.telepon,
                                              subColor,
                                              txtColor,
                                            ),
                                            _buildInfoTile(
                                              Icons.location_on_outlined,
                                              'ALAMAT DOMISILI',
                                              currentA.address.isEmpty
                                                  ? 'Kel. KEJAYAN, Kec. PUJER, KABUPATEN BONDOWOSO, Prov. JAWA TIMUR'
                                                  : 'Kel. ${currentA.village.isEmpty ? 'KEJAYAN' : currentA.village}, Kec. ${currentA.subDistrict.isEmpty ? 'PUJER' : currentA.subDistrict}, ${currentA.district.isEmpty ? 'KABUPATEN BONDOWOSO' : currentA.district}, Prov. ${currentA.province.isEmpty ? 'JAWA TIMUR' : currentA.province}\n${currentA.address}',
                                              subColor,
                                              txtColor,
                                            ),
                                            _buildInfoTile(
                                              Icons.calendar_today_outlined,
                                              'TANGGAL BERGABUNG',
                                              _formatJoinedDate(
                                                currentA.createdAt,
                                              ),
                                              subColor,
                                              txtColor,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // Tab 2: IZIN AKSES
                            SingleChildScrollView(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildSectionLabel(
                                    'ROLE TEMPLATE / POSISI',
                                    subColor,
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    height: 46,
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? const Color(0xFF282830)
                                          : const Color(0xFFF3F0FA),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: borderColor),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: matchedRoleTemplate,
                                        dropdownColor: dialogBg,
                                        isExpanded: true,
                                        style: GoogleFonts.outfit(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: txtColor,
                                        ),
                                        items:
                                            [
                                              'Standard Assistant (Default)',
                                              'Front Desk',
                                              'Administrator',
                                              'Custom',
                                            ].map((String role) {
                                              return DropdownMenuItem<String>(
                                                value: role,
                                                child: Text(role),
                                              );
                                            }).toList(),
                                        onChanged: (val) {
                                          if (val != null && val != 'Custom') {
                                            final perms = roleTemplates[val];
                                            if (perms != null) {
                                              ref
                                                  .read(
                                                    dokterAsistenListProvider
                                                        .notifier,
                                                  )
                                                  .updatePermissions(
                                                    currentA.id,
                                                    perms,
                                                  );
                                              setModalState(() {});
                                            }
                                          }
                                        },
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 24),

                                  _buildSectionLabel(
                                    'IZIN AKSES MENU (CUSTOM)',
                                    subColor,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Select which menus this assistant can access.',
                                    style: GoogleFonts.outfit(
                                      fontSize: 10,
                                      color: subColor,
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  // List of permissions
                                  Column(
                                    children: availablePerms.map((p) {
                                      final isChecked = currentA.permissions
                                          .contains(p);
                                      return CheckboxListTile(
                                        title: Text(
                                          p,
                                          style: GoogleFonts.outfit(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: txtColor,
                                          ),
                                        ),
                                        value: isChecked,
                                        activeColor: purpleAccent,
                                        contentPadding: EdgeInsets.zero,
                                        dense: true,
                                        onChanged: (val) {
                                          final updated = List<String>.from(
                                            currentA.permissions,
                                          );
                                          if (val == true) {
                                            updated.add(p);
                                          } else {
                                            updated.remove(p);
                                          }
                                          ref
                                              .read(
                                                dokterAsistenListProvider
                                                    .notifier,
                                              )
                                              .updatePermissions(
                                                currentA.id,
                                                updated,
                                              );
                                          setModalState(() {});
                                        },
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      Divider(color: borderColor, height: 1),

                      // Bottom actions
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            TextButton.icon(
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                color: Colors.redAccent,
                                size: 16,
                              ),
                              label: Text(
                                'HAPUS DATA ASISTEN',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.redAccent,
                                ),
                              ),
                              onPressed: () {
                                _confirmDelete(context, currentA);
                              },
                            ),
                            CustomButton(
                              text: 'TUTUP',
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              primaryColor: purpleAccent,
                              textColor: Colors.white,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildSectionLabel(String label, Color color) {
    return Text(
      '● $label',
      style: GoogleFonts.outfit(
        fontSize: 9,
        fontWeight: FontWeight.w900,
        color: color,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildInfoTile(
    IconData icon,
    String label,
    String value,
    Color subColor,
    Color valColor,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 14, color: subColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.outfit(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: subColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: valColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatJoinedDate(String? rawDate) {
    if (rawDate == null || rawDate.isEmpty) return 'May 2026';
    try {
      final dt = DateTime.parse(rawDate);
      final months = [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
      ];
      return '${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return 'May 2026';
    }
  }

  // ─── Edit Assistant Personal Info Modal Dialog ──────────────────────────────

  void _showEditAssistantInfoDialog(BuildContext context, AsistenModel a) {
    final nameController = TextEditingController(text: a.nama);
    final nikController = TextEditingController(text: a.nik);
    final phoneController = TextEditingController(text: a.telepon);
    final emailController = TextEditingController(text: a.email);
    final sipController = TextEditingController(text: a.sip);
    final usernameController = TextEditingController(text: a.username);
    final birthPlaceController = TextEditingController(text: a.birthPlace);
    final addressController = TextEditingController(text: a.address);
    final passwordController = TextEditingController();

    String selectedRole = a.peran;
    String selectedGender = a.gender.isEmpty
        ? 'Male'
        : (a.gender.toLowerCase() == 'female' ? 'Female' : 'Male');
    DateTime? selectedBirthDate = a.birthDate.isNotEmpty
        ? DateTime.tryParse(a.birthDate)
        : null;

    String prov = a.province.isEmpty ? 'Pilih Provinsi' : a.province;
    String kota = a.district.isEmpty ? 'Pilih Kota/Kabupaten' : a.district;
    String kec = a.subDistrict.isEmpty ? 'Pilih Kecamatan' : a.subDistrict;
    String kel = a.village.isEmpty ? 'Pilih Kelurahan/Desa' : a.village;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final state = ref.watch(landingPageProvider);
            final isDark = state.appearance == 'dark';
            final dialogBg = isDark ? const Color(0xFF1E1E22) : Colors.white;
            final txtColor = isDark ? Colors.white : const Color(0xFF1B0C3C);
            final subColor = isDark
                ? Colors.grey[400]!
                : const Color(0xFF6F6A8A);
            final inputBg = isDark
                ? const Color(0xFF282830)
                : const Color(0xFFF3F0FA);
            final purple = ref.read(landingPageProvider.notifier).getPrimaryColor();

            // Dynamic regions mapping
            final provinces = ['Pilih Provinsi', 'Jawa Timur', 'DKI Jakarta'];
            List<String> cities = ['Pilih Kota/Kabupaten'];
            if (prov == 'Jawa Timur') {
              cities.addAll(['Bondowoso', 'Surabaya']);
            } else if (prov == 'DKI Jakarta') {
              cities.add('Jakarta Selatan');
            }

            List<String> districts = ['Pilih Kecamatan'];
            if (kota == 'Bondowoso') {
              districts.addAll(['Pujer', 'Tamanan']);
            } else if (kota == 'Surabaya') {
              districts.add('Gubeng');
            } else if (kota == 'Jakarta Selatan') {
              districts.add('Tebet');
            }

            List<String> villages = ['Pilih Kelurahan/Desa'];
            if (kec == 'Pujer') {
              villages.addAll(['Kejayan', 'Mengok']);
            } else if (kec == 'Tamanan') {
              villages.add('Tamanan');
            } else if (kec == 'Gubeng') {
              villages.add('Mojo');
            } else if (kec == 'Tebet') {
              villages.add('Menteng Dalam');
            }

            return Dialog(
              backgroundColor: dialogBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 550,
                  maxHeight: 680,
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Edit Data Asisten',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: txtColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Perbarui data personal asisten klinik Anda',
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
                        'Contoh: Siti Aminah, A.Md.Kep.',
                        inputBg,
                        txtColor,
                        subColor,
                      ),
                      const SizedBox(height: 12),

                      // Username & Password Row
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildInputLabel('USERNAME', subColor),
                                _buildInputField(
                                  usernameController,
                                  'username',
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
                                _buildInputLabel(
                                  'PASSWORD (BIARKAN KOSONG JIKA TIDAK DIUBAH)',
                                  subColor,
                                ),
                                _buildInputField(
                                  passwordController,
                                  '********',
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
                                _buildInputLabel('PERAN / JABATAN', subColor),
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
                                            'Perawat',
                                            'Front Desk',
                                            'Administrator',
                                          ].map((String role) {
                                            return DropdownMenuItem<String>(
                                              value: role,
                                              child: Text(role),
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
                        _buildInputLabel(
                          'SURAT IZIN PRAKTEK (SIP) PERAWAT',
                          subColor,
                        ),
                        _buildInputField(
                          sipController,
                          'Contoh: 503/1204/SIP.P/...',
                          inputBg,
                          txtColor,
                          subColor,
                        ),
                        const SizedBox(height: 12),
                      ],

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
                                _buildInputLabel('EMAIL KLINIK', subColor),
                                _buildInputField(
                                  emailController,
                                  'asisten@gmail.com',
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

                      // Gender & Birth Date Row
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildInputLabel('GENDER', subColor),
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
                                      value: selectedGender,
                                      dropdownColor: dialogBg,
                                      style: GoogleFonts.outfit(
                                        fontSize: 12,
                                        color: txtColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      isExpanded: true,
                                      items: ['Male', 'Female'].map((String g) {
                                        return DropdownMenuItem(
                                          value: g,
                                          child: Text(g),
                                        );
                                      }).toList(),
                                      onChanged: (val) {
                                        setModalState(() {
                                          selectedGender = val ?? 'Male';
                                        });
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildInputLabel('PLACE OF BIRTH', subColor),
                                _buildInputField(
                                  birthPlaceController,
                                  'Example: London',
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
                                _buildInputLabel('DATE OF BIRTH', subColor),
                                GestureDetector(
                                  onTap: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate:
                                          selectedBirthDate ?? DateTime(2000),
                                      firstDate: DateTime(1960),
                                      lastDate: DateTime.now(),
                                    );
                                    if (picked != null) {
                                      setModalState(() {
                                        selectedBirthDate = picked;
                                      });
                                    }
                                  },
                                  child: Container(
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: inputBg,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    alignment: Alignment.centerLeft,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          selectedBirthDate == null
                                              ? 'mm/dd/yyyy'
                                              : '${selectedBirthDate!.year}-${selectedBirthDate!.month.toString().padLeft(2, '0')}-${selectedBirthDate!.day.toString().padLeft(2, '0')}',
                                          style: GoogleFonts.outfit(
                                            fontSize: 12,
                                            color: txtColor,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Icon(
                                          Icons.calendar_month,
                                          size: 16,
                                          color: subColor,
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
                      const SizedBox(height: 12),

                      // Full Address
                      _buildInputLabel('PROVINSI', subColor),
                      Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: inputBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: prov,
                            dropdownColor: dialogBg,
                            isExpanded: true,
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: txtColor,
                              fontWeight: FontWeight.bold,
                            ),
                            items: provinces
                                .map(
                                  (p) => DropdownMenuItem(
                                    value: p,
                                    child: Text(p),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setModalState(() {
                                  prov = val;
                                  kota = 'Pilih Kota/Kabupaten';
                                  kec = 'Pilih Kecamatan';
                                  kel = 'Pilih Kelurahan/Desa';
                                });
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildInputLabel('KOTA / KABUPATEN', subColor),
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
                                      value: cities.contains(kota)
                                          ? kota
                                          : 'Pilih Kota/Kabupaten',
                                      dropdownColor: dialogBg,
                                      isExpanded: true,
                                      style: GoogleFonts.outfit(
                                        fontSize: 12,
                                        color: txtColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      items: cities
                                          .map(
                                            (c) => DropdownMenuItem(
                                              value: c,
                                              child: Text(c),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (val) {
                                        if (val != null) {
                                          setModalState(() {
                                            kota = val;
                                            kec = 'Pilih Kecamatan';
                                            kel = 'Pilih Kelurahan/Desa';
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildInputLabel('KECAMATAN', subColor),
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
                                      value: districts.contains(kec)
                                          ? kec
                                          : 'Pilih Kecamatan',
                                      dropdownColor: dialogBg,
                                      isExpanded: true,
                                      style: GoogleFonts.outfit(
                                        fontSize: 12,
                                        color: txtColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      items: districts
                                          .map(
                                            (d) => DropdownMenuItem(
                                              value: d,
                                              child: Text(d),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (val) {
                                        if (val != null) {
                                          setModalState(() {
                                            kec = val;
                                            kel = 'Pilih Kelurahan/Desa';
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildInputLabel('KELURAHAN / DESA', subColor),
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
                                      value: villages.contains(kel)
                                          ? kel
                                          : 'Pilih Kelurahan/Desa',
                                      dropdownColor: dialogBg,
                                      isExpanded: true,
                                      style: GoogleFonts.outfit(
                                        fontSize: 12,
                                        color: txtColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      items: villages
                                          .map(
                                            (v) => DropdownMenuItem(
                                              value: v,
                                              child: Text(v),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (val) {
                                        if (val != null) {
                                          setModalState(() {
                                            kel = val;
                                          });
                                        }
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

                      _buildInputLabel('DETAIL JALAN', subColor),
                      Container(
                        decoration: BoxDecoration(
                          color: inputBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: TextField(
                          controller: addressController,
                          maxLines: 3,
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: txtColor,
                            fontWeight: FontWeight.bold,
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Enter street name, house number...',
                            border: InputBorder.none,
                          ),
                        ),
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
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const SizedBox(width: 14),
                          CustomButton(
                            text: 'Simpan',
                            onPressed: () {
                              final name = nameController.text.trim();
                              final nik = nikController.text.trim();
                              final phone = phoneController.text.trim();
                              final email = emailController.text.trim();
                              final sip = sipController.text.trim();
                              final user = usernameController.text.trim();
                              final addr = addressController.text.trim();
                              final pass = passwordController.text.trim();

                              if (name.isEmpty ||
                                  nik.isEmpty ||
                                  phone.isEmpty ||
                                  user.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Nama, Username, NIK, dan Telepon wajib diisi!',
                                    ),
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                                return;
                              }

                              final birthDateStr = selectedBirthDate == null
                                  ? ''
                                  : '${selectedBirthDate!.year}-${selectedBirthDate!.month.toString().padLeft(2, '0')}-${selectedBirthDate!.day.toString().padLeft(2, '0')}';

                              final updatedAsisten = a.copyWith(
                                nama: name,
                                email: email.isEmpty ? '-' : email,
                                nik: nik,
                                sip: selectedRole == 'Perawat'
                                    ? (sip.isEmpty ? '-' : sip)
                                    : '-',
                                peran: selectedRole,
                                telepon: phone,
                                username: user,
                                gender: selectedGender,
                                birthPlace: birthPlaceController.text.trim(),
                                birthDate: birthDateStr,
                                address: addr,
                                province: prov == 'Pilih Provinsi' ? '' : prov,
                                district: kota == 'Pilih Kota/Kabupaten'
                                    ? ''
                                    : kota,
                                subDistrict: kec == 'Pilih Kecamatan'
                                    ? ''
                                    : kec,
                                village: kel == 'Pilih Kelurahan/Desa'
                                    ? ''
                                    : kel,
                              );

                              showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (context) => const Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );

                              ref
                                  .read(dokterAsistenListProvider.notifier)
                                  .updateAsisten(
                                    updatedAsisten,
                                    password: pass.isEmpty ? null : pass,
                                  )
                                  .then((_) {
                                    Navigator.pop(
                                      context,
                                    ); // Pop loading spinner
                                    Navigator.pop(context); // Pop edit dialog
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Data asisten ${name} berhasil diperbarui!',
                                        ),
                                        backgroundColor: const Color(
                                          0xFF48C9B0,
                                        ),
                                      ),
                                    );
                                  })
                                  .catchError((err) {
                                    Navigator.pop(
                                      context,
                                    ); // Pop loading spinner
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Gagal memperbarui data: $err',
                                        ),
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

  // ─── Add Assistant Form Overlay Dialog Wizard (Screenshots 4 & 5) ───────────

  void _showAddAssistantDialog(BuildContext context) {
    final nameController = TextEditingController();
    final usernameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();

    final nikController = TextEditingController();
    final phoneController = TextEditingController();
    final birthPlaceController = TextEditingController();
    final sipController = TextEditingController();
    final addressController = TextEditingController();

    String selectedRole = 'Perawat';
    String selectedGender = 'Male';
    DateTime? selectedBirthDate;

    String prov = 'Pilih Provinsi';
    String kota = 'Pilih Kota/Kabupaten';
    String kec = 'Pilih Kecamatan';
    String kel = 'Pilih Kelurahan/Desa';

    List<String> selectedPerms = [
      'DASHBOARD',
      'PASIEN',
      'OBAT',
      'ANTRIAN',
      'PEMERIKSAAN',
    ];
    bool obscurePassword = true;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final state = ref.watch(landingPageProvider);
            final isDark = state.appearance == 'dark';
            final dialogBg = isDark ? const Color(0xFF1E1E22) : Colors.white;
            final txtColor = isDark ? Colors.white : const Color(0xFF1B0C3C);
            final subColor = isDark
                ? Colors.grey[400]!
                : const Color(0xFF6F6A8A);
            final inputBg = isDark
                ? const Color(0xFF282830)
                : const Color(0xFFF3F0FA);
            final borderColor = isDark
                ? const Color(0xFF2E2E32)
                : const Color(0xFFECEEF2);
            final purple = ref.read(landingPageProvider.notifier).getPrimaryColor();

            final availablePerms = [
              'DASHBOARD',
              'PASIEN',
              'OBAT',
              'ANTRIAN',
              'PEMERIKSAAN',
              'PEMBUKUAN',
              'ASISTEN',
            ];

            // Region data pickers
            final provinces = ['Pilih Provinsi', 'Jawa Timur', 'DKI Jakarta'];
            List<String> cities = ['Pilih Kota/Kabupaten'];
            if (prov == 'Jawa Timur') {
              cities.addAll(['Bondowoso', 'Surabaya']);
            } else if (prov == 'DKI Jakarta') {
              cities.add('Jakarta Selatan');
            }

            List<String> districts = ['Pilih Kecamatan'];
            if (kota == 'Bondowoso') {
              districts.addAll(['Pujer', 'Tamanan']);
            } else if (kota == 'Surabaya') {
              districts.add('Gubeng');
            } else if (kota == 'Jakarta Selatan') {
              districts.add('Tebet');
            }

            List<String> villages = ['Pilih Kelurahan/Desa'];
            if (kec == 'Pujer') {
              villages.addAll(['Kejayan', 'Mengok']);
            } else if (kec == 'Tamanan') {
              villages.add('Tamanan');
            } else if (kec == 'Gubeng') {
              villages.add('Mojo');
            } else if (kec == 'Tebet') {
              villages.add('Menteng Dalam');
            }

            return Dialog(
              backgroundColor: dialogBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 600,
                  maxHeight: 720,
                ),
                child: Column(
                  children: [
                    // Title Bar
                    Padding(
                      padding: const EdgeInsets.only(
                        left: 28,
                        right: 28,
                        top: 28,
                        bottom: 10,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.person_add_outlined,
                                    size: 20,
                                    color: purple,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Register New Assistant',
                                    style: GoogleFonts.outfit(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color: txtColor,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Complete the form below to add a new doctor assistant.',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  color: subColor,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: Icon(Icons.close, color: subColor, size: 20),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),

                    Divider(color: borderColor, height: 1),

                    // Scrollable Form content
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 20,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // INFORMASI AKUN SECTION
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                border: Border.all(color: borderColor),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'INFORMASI AKUN',
                                    style: GoogleFonts.outfit(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: purple,
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            _buildInputLabel(
                                              'Template Role / Posisi',
                                              subColor,
                                            ),
                                            Container(
                                              height: 44,
                                              decoration: BoxDecoration(
                                                color: inputBg,
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                  ),
                                              child: DropdownButtonHideUnderline(
                                                child: DropdownButton<String>(
                                                  value: selectedRole,
                                                  dropdownColor: dialogBg,
                                                  style: GoogleFonts.outfit(
                                                    fontSize: 12,
                                                    color: txtColor,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                  isExpanded: true,
                                                  items:
                                                      [
                                                        'Perawat',
                                                        'Front Desk',
                                                        'Administrator',
                                                      ].map((String role) {
                                                        return DropdownMenuItem(
                                                          value: role,
                                                          child: Text(role),
                                                        );
                                                      }).toList(),
                                                  onChanged: (val) {
                                                    setModalState(() {
                                                      selectedRole =
                                                          val ?? 'Perawat';
                                                      // Auto populate permissions
                                                      if (selectedRole ==
                                                          'Perawat') {
                                                        selectedPerms = [
                                                          'DASHBOARD',
                                                          'PASIEN',
                                                          'OBAT',
                                                          'ANTRIAN',
                                                          'PEMERIKSAAN',
                                                        ];
                                                      } else if (selectedRole ==
                                                          'Front Desk') {
                                                        selectedPerms = [
                                                          'DASHBOARD',
                                                          'PASIEN',
                                                          'ANTRIAN',
                                                        ];
                                                      } else {
                                                        selectedPerms = [
                                                          'DASHBOARD',
                                                          'PASIEN',
                                                          'OBAT',
                                                          'ANTRIAN',
                                                          'PEMERIKSAAN',
                                                          'PEMBUKUAN',
                                                          'ASISTEN',
                                                        ];
                                                      }
                                                    });
                                                  },
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            _buildInputLabel(
                                              'Username',
                                              subColor,
                                            ),
                                            _buildInputField(
                                              usernameController,
                                              '@ Enter username',
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

                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            _buildInputLabel('Email', subColor),
                                            _buildInputField(
                                              emailController,
                                              'example@clinic.com',
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
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            _buildInputLabel(
                                              'Password',
                                              subColor,
                                            ),
                                            Container(
                                              height: 44,
                                              decoration: BoxDecoration(
                                                color: inputBg,
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                  ),
                                              child: Row(
                                                children: [
                                                  Expanded(
                                                    child: TextField(
                                                      controller:
                                                          passwordController,
                                                      obscureText:
                                                          obscurePassword,
                                                      style: GoogleFonts.outfit(
                                                        fontSize: 12,
                                                        color: txtColor,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                      decoration: InputDecoration(
                                                        hintText: '********',
                                                        hintStyle:
                                                            GoogleFonts.outfit(
                                                              fontSize: 11,
                                                              color: subColor
                                                                  .withOpacity(
                                                                    0.5,
                                                                  ),
                                                            ),
                                                        border:
                                                            InputBorder.none,
                                                        isDense: true,
                                                      ),
                                                    ),
                                                  ),
                                                  IconButton(
                                                    icon: Icon(
                                                      obscurePassword
                                                          ? Icons.visibility_off
                                                          : Icons.visibility,
                                                      size: 16,
                                                      color: subColor,
                                                    ),
                                                    onPressed: () {
                                                      setModalState(() {
                                                        obscurePassword =
                                                            !obscurePassword;
                                                      });
                                                    },
                                                    padding: EdgeInsets.zero,
                                                    constraints:
                                                        const BoxConstraints(),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 16),

                            // DATA PRIBADI SECTION
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                border: Border.all(color: borderColor),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'DATA PRIBADI',
                                    style: GoogleFonts.outfit(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: purple,
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  _buildInputLabel('Full Name', subColor),
                                  _buildInputField(
                                    nameController,
                                    'Enter full name',
                                    inputBg,
                                    txtColor,
                                    subColor,
                                  ),
                                  const SizedBox(height: 12),

                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            _buildInputLabel(
                                              'NIK (ID Number)',
                                              subColor,
                                            ),
                                            _buildInputField(
                                              nikController,
                                              '16-digit NIK',
                                              inputBg,
                                              txtColor,
                                              subColor,
                                              keyboardType:
                                                  TextInputType.number,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            _buildInputLabel(
                                              'Phone Number',
                                              subColor,
                                            ),
                                            _buildInputField(
                                              phoneController,
                                              '+62 8...',
                                              inputBg,
                                              txtColor,
                                              subColor,
                                              keyboardType: TextInputType.phone,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),

                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            _buildInputLabel(
                                              'Gender',
                                              subColor,
                                            ),
                                            Container(
                                              height: 44,
                                              decoration: BoxDecoration(
                                                color: inputBg,
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                  ),
                                              child: DropdownButtonHideUnderline(
                                                child: DropdownButton<String>(
                                                  value: selectedGender,
                                                  dropdownColor: dialogBg,
                                                  style: GoogleFonts.outfit(
                                                    fontSize: 12,
                                                    color: txtColor,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                  isExpanded: true,
                                                  items: ['Male', 'Female'].map(
                                                    (String g) {
                                                      return DropdownMenuItem(
                                                        value: g,
                                                        child: Text(g),
                                                      );
                                                    },
                                                  ).toList(),
                                                  onChanged: (val) {
                                                    setModalState(() {
                                                      selectedGender =
                                                          val ?? 'Male';
                                                    });
                                                  },
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            _buildInputLabel(
                                              'Place of Birth',
                                              subColor,
                                            ),
                                            _buildInputField(
                                              birthPlaceController,
                                              'Example: London',
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
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            _buildInputLabel(
                                              'Date of Birth',
                                              subColor,
                                            ),
                                            GestureDetector(
                                              onTap: () async {
                                                final picked =
                                                    await showDatePicker(
                                                      context: context,
                                                      initialDate: DateTime(
                                                        2000,
                                                      ),
                                                      firstDate: DateTime(1960),
                                                      lastDate: DateTime.now(),
                                                    );
                                                if (picked != null) {
                                                  setModalState(() {
                                                    selectedBirthDate = picked;
                                                  });
                                                }
                                              },
                                              child: Container(
                                                height: 44,
                                                decoration: BoxDecoration(
                                                  color: inputBg,
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                                alignment: Alignment.centerLeft,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                    ),
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment
                                                          .spaceBetween,
                                                  children: [
                                                    Text(
                                                      selectedBirthDate == null
                                                          ? 'mm/dd/yyyy'
                                                          : '${selectedBirthDate!.year}-${selectedBirthDate!.month.toString().padLeft(2, '0')}-${selectedBirthDate!.day.toString().padLeft(2, '0')}',
                                                      style: GoogleFonts.outfit(
                                                        fontSize: 12,
                                                        color: txtColor,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                    Icon(
                                                      Icons.calendar_month,
                                                      size: 16,
                                                      color: subColor,
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

                                  if (selectedRole == 'Perawat') ...[
                                    const SizedBox(height: 12),
                                    _buildInputLabel(
                                      'SURAT IZIN PRAKTEK (SIP) PERAWAT',
                                      subColor,
                                    ),
                                    _buildInputField(
                                      sipController,
                                      'Contoh: 503/1204/SIP.P/...',
                                      inputBg,
                                      txtColor,
                                      subColor,
                                    ),
                                  ],
                                ],
                              ),
                            ),

                            const SizedBox(height: 16),

                            // FULL ADDRESS SECTION
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                border: Border.all(color: borderColor),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Full Address',
                                    style: GoogleFonts.outfit(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: purple,
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            _buildInputLabel(
                                              'Provinsi',
                                              subColor,
                                            ),
                                            Container(
                                              height: 44,
                                              decoration: BoxDecoration(
                                                color: inputBg,
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                  ),
                                              child: DropdownButtonHideUnderline(
                                                child: DropdownButton<String>(
                                                  value: prov,
                                                  dropdownColor: dialogBg,
                                                  isExpanded: true,
                                                  style: GoogleFonts.outfit(
                                                    fontSize: 12,
                                                    color: txtColor,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                  items: provinces
                                                      .map(
                                                        (p) => DropdownMenuItem(
                                                          value: p,
                                                          child: Text(p),
                                                        ),
                                                      )
                                                      .toList(),
                                                  onChanged: (val) {
                                                    if (val != null) {
                                                      setModalState(() {
                                                        prov = val;
                                                        kota =
                                                            'Pilih Kota/Kabupaten';
                                                        kec = 'Pilih Kecamatan';
                                                        kel =
                                                            'Pilih Kelurahan/Desa';
                                                      });
                                                    }
                                                  },
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            _buildInputLabel(
                                              'Kota/Kabupaten',
                                              subColor,
                                            ),
                                            Container(
                                              height: 44,
                                              decoration: BoxDecoration(
                                                color: inputBg,
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                  ),
                                              child: DropdownButtonHideUnderline(
                                                child: DropdownButton<String>(
                                                  value: cities.contains(kota)
                                                      ? kota
                                                      : 'Pilih Kota/Kabupaten',
                                                  dropdownColor: dialogBg,
                                                  isExpanded: true,
                                                  style: GoogleFonts.outfit(
                                                    fontSize: 12,
                                                    color: txtColor,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                  items: cities
                                                      .map(
                                                        (c) => DropdownMenuItem(
                                                          value: c,
                                                          child: Text(c),
                                                        ),
                                                      )
                                                      .toList(),
                                                  onChanged: (val) {
                                                    if (val != null) {
                                                      setModalState(() {
                                                        kota = val;
                                                        kec = 'Pilih Kecamatan';
                                                        kel =
                                                            'Pilih Kelurahan/Desa';
                                                      });
                                                    }
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

                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            _buildInputLabel(
                                              'Kecamatan',
                                              subColor,
                                            ),
                                            Container(
                                              height: 44,
                                              decoration: BoxDecoration(
                                                color: inputBg,
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                  ),
                                              child: DropdownButtonHideUnderline(
                                                child: DropdownButton<String>(
                                                  value: districts.contains(kec)
                                                      ? kec
                                                      : 'Pilih Kecamatan',
                                                  dropdownColor: dialogBg,
                                                  isExpanded: true,
                                                  style: GoogleFonts.outfit(
                                                    fontSize: 12,
                                                    color: txtColor,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                  items: districts
                                                      .map(
                                                        (d) => DropdownMenuItem(
                                                          value: d,
                                                          child: Text(d),
                                                        ),
                                                      )
                                                      .toList(),
                                                  onChanged: (val) {
                                                    if (val != null) {
                                                      setModalState(() {
                                                        kec = val;
                                                        kel =
                                                            'Pilih Kelurahan/Desa';
                                                      });
                                                    }
                                                  },
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            _buildInputLabel(
                                              'Kelurahan/Desa',
                                              subColor,
                                            ),
                                            Container(
                                              height: 44,
                                              decoration: BoxDecoration(
                                                color: inputBg,
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                  ),
                                              child: DropdownButtonHideUnderline(
                                                child: DropdownButton<String>(
                                                  value: villages.contains(kel)
                                                      ? kel
                                                      : 'Pilih Kelurahan/Desa',
                                                  dropdownColor: dialogBg,
                                                  isExpanded: true,
                                                  style: GoogleFonts.outfit(
                                                    fontSize: 12,
                                                    color: txtColor,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                  items: villages
                                                      .map(
                                                        (v) => DropdownMenuItem(
                                                          value: v,
                                                          child: Text(v),
                                                        ),
                                                      )
                                                      .toList(),
                                                  onChanged: (val) {
                                                    if (val != null) {
                                                      setModalState(() {
                                                        kel = val;
                                                      });
                                                    }
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

                                  _buildInputLabel(
                                    'Detail Jalan (Optional / Nilai Saat Ini)',
                                    subColor,
                                  ),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: inputBg,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    child: TextField(
                                      controller: addressController,
                                      maxLines: 3,
                                      style: GoogleFonts.outfit(
                                        fontSize: 12,
                                        color: txtColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      decoration: const InputDecoration(
                                        hintText: 'Enter assistant address...',
                                        border: InputBorder.none,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 16),

                            // AKSES & MEDIA SECTION
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                border: Border.all(color: borderColor),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'AKSES & MEDIA',
                                    style: GoogleFonts.outfit(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: purple,
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Menu Access
                                      Expanded(
                                        flex: 3,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.verified_user_outlined,
                                                  size: 14,
                                                  color: purple,
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  'Menu Access',
                                                  style: GoogleFonts.outfit(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: txtColor,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Column(
                                              children: availablePerms.map((p) {
                                                final isChecked = selectedPerms
                                                    .contains(p);
                                                return CheckboxListTile(
                                                  title: Text(
                                                    p,
                                                    style: GoogleFonts.outfit(
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: txtColor,
                                                    ),
                                                  ),
                                                  value: isChecked,
                                                  activeColor: purple,
                                                  contentPadding:
                                                      EdgeInsets.zero,
                                                  dense: true,
                                                  onChanged: (val) {
                                                    setModalState(() {
                                                      if (val == true) {
                                                        selectedPerms.add(p);
                                                      } else {
                                                        selectedPerms.remove(p);
                                                      }
                                                    });
                                                  },
                                                );
                                              }).toList(),
                                            ),
                                          ],
                                        ),
                                      ),

                                      const SizedBox(width: 16),

                                      // Photo Profil Mockup
                                      Expanded(
                                        flex: 2,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            Text(
                                              'Photo Profil',
                                              style: GoogleFonts.outfit(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: txtColor,
                                              ),
                                            ),
                                            const SizedBox(height: 12),
                                            Container(
                                              height: 120,
                                              width: double.infinity,
                                              decoration: BoxDecoration(
                                                border: Border.all(
                                                  color: borderColor,
                                                  style: BorderStyle.none,
                                                ), // dashed in design
                                              ),
                                              child: CustomPaint(
                                                painter: DashedBorderPainter(
                                                  color: borderColor,
                                                ),
                                                child: Container(
                                                  alignment: Alignment.center,
                                                  child: Column(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      Icon(
                                                        Icons
                                                            .photo_camera_outlined,
                                                        size: 24,
                                                        color: subColor,
                                                      ),
                                                      const SizedBox(
                                                        height: 10,
                                                      ),
                                                      Text(
                                                        'UPLOAD PHOTO',
                                                        style:
                                                            GoogleFonts.outfit(
                                                              fontSize: 8,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              color: txtColor,
                                                            ),
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        'PNG OR JPG UP TO 5MB',
                                                        style:
                                                            GoogleFonts.outfit(
                                                              fontSize: 6,
                                                              color: subColor,
                                                            ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
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

                    Divider(color: borderColor, height: 1),

                    // Dialog Actions Footer
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 16,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            child: Text(
                              'Batal',
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                color: subColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const SizedBox(width: 14),
                          CustomButton(
                            text: 'Simpan Asisten',
                            onPressed: () {
                              final name = nameController.text.trim();
                              final nik = nikController.text.trim();
                              final phone = phoneController.text.trim();
                              final email = emailController.text.trim();
                              final username = usernameController.text.trim();
                              final password = passwordController.text.trim();
                              final sip = sipController.text.trim();
                              final addr = addressController.text.trim();

                              if (name.isEmpty ||
                                  nik.isEmpty ||
                                  phone.isEmpty ||
                                  username.isEmpty ||
                                  password.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Nama, Username, Password, NIK, dan Telepon wajib diisi!',
                                    ),
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                                return;
                              }

                              if (nik.length < 16) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('NIK harus 16 digit!'),
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                                return;
                              }

                              final birthDateStr = selectedBirthDate == null
                                  ? ''
                                  : '${selectedBirthDate!.year}-${selectedBirthDate!.month.toString().padLeft(2, '0')}-${selectedBirthDate!.day.toString().padLeft(2, '0')}';

                              final newId = _generateUuidV4();
                              final newAsisten = AsistenModel(
                                id: newId,
                                nama: name,
                                email: email.isEmpty ? '-' : email,
                                nik: nik,
                                sip: selectedRole == 'Perawat'
                                    ? (sip.isEmpty ? '-' : sip)
                                    : '-',
                                peran: selectedRole,
                                telepon: phone,
                                isBertugas: true,
                                permissions: selectedPerms.isEmpty
                                    ? ['DASHBOARD']
                                    : selectedPerms,
                                avatarBg: selectedRole == 'Perawat'
                                    ? const Color(0xFF48C9B0)
                                    : (selectedRole == 'Front Desk'
                                          ? const Color(0xFFB577F2)
                                          : const Color(0xFFF39C12)),
                                username: username,
                                gender: selectedGender,
                                birthPlace: birthPlaceController.text.trim(),
                                birthDate: birthDateStr,
                                address: addr,
                                province: prov == 'Pilih Provinsi' ? '' : prov,
                                district: kota == 'Pilih Kota/Kabupaten'
                                    ? ''
                                    : kota,
                                subDistrict: kec == 'Pilih Kecamatan'
                                    ? ''
                                    : kec,
                                village: kel == 'Pilih Kelurahan/Desa'
                                    ? ''
                                    : kel,
                                createdAt: DateTime.now()
                                    .toUtc()
                                    .toIso8601String(),
                              );

                              showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (context) => const Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );

                              ref
                                  .read(dokterAsistenListProvider.notifier)
                                  .addAsisten(newAsisten, password)
                                  .then((_) {
                                    Navigator.pop(
                                      context,
                                    ); // Pop loading spinner
                                    Navigator.pop(context); // Pop add dialog
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Asisten $name berhasil didaftarkan!',
                                        ),
                                        backgroundColor: const Color(
                                          0xFF48C9B0,
                                        ),
                                      ),
                                    );
                                  })
                                  .catchError((err) {
                                    Navigator.pop(
                                      context,
                                    ); // Pop loading spinner
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Gagal mendaftarkan asisten: $err',
                                        ),
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
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Confirm delete assistant dialog
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Hapus Asisten?',
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: txtColor,
            ),
          ),
          content: Text(
            'Apakah Anda yakin ingin menghapus ${a.nama} dari daftar asisten praktik?',
            style: GoogleFonts.outfit(fontSize: 12, color: subColor),
          ),
          actions: [
            TextButton(
              child: Text(
                'Batal',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: subColor,
                  fontWeight: FontWeight.bold,
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
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) =>
                      const Center(child: CircularProgressIndicator()),
                );
                ref
                    .read(dokterAsistenListProvider.notifier)
                    .removeAsisten(a.id)
                    .then((_) {
                      Navigator.pop(context); // Pop loading spinner
                      Navigator.pop(context); // Pop confirm delete
                      Navigator.pop(context); // Pop detail dialog
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Asisten ${a.nama} berhasil dihapus.'),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                    })
                    .catchError((err) {
                      Navigator.pop(context); // Pop loading spinner
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Gagal menghapus asisten: $err'),
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
        style: GoogleFonts.outfit(
          fontSize: 12,
          color: text,
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

// ─── Dashed Border Painter implementation ────────────────────────────────────

class DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double gap;
  final double dash;
  final double borderRadius;

  DashedBorderPainter({
    required this.color,
    this.strokeWidth = 1.0,
    this.gap = 5.0,
    this.dash = 5.0,
    this.borderRadius = 20.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width, size.height),
          Radius.circular(borderRadius),
        ),
      );

    final dashPath = _buildDashedPath(path, dash, gap);
    canvas.drawPath(dashPath, paint);
  }

  Path _buildDashedPath(Path source, double dashWidth, double gapWidth) {
    final Path dest = Path();
    for (final PathMetric metric in source.computeMetrics()) {
      double distance = 0.0;
      bool draw = true;
      while (distance < metric.length) {
        final double len = draw ? dashWidth : gapWidth;
        if (distance + len >= metric.length) {
          if (draw) {
            dest.addPath(
              metric.extractPath(distance, metric.length),
              Offset.zero,
            );
          }
          break;
        }
        if (draw) {
          dest.addPath(
            metric.extractPath(distance, distance + len),
            Offset.zero,
          );
        }
        distance += len;
        draw = !draw;
      }
    }
    return dest;
  }

  @override
  bool shouldRepaint(covariant DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.gap != gap ||
        oldDelegate.dash != dash ||
        oldDelegate.borderRadius != borderRadius;
  }
}
