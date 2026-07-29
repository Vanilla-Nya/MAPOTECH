import 'package:flutter/material.dart';
import 'dart:ui' show PathMetric;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapotech/features/landing/landing_page_data.dart';
import 'package:mapotech/shared/supabase_service.dart';
import 'package:mapotech/shared/widgets/ui.dart';
import 'package:mapotech/shared/widgets/location_selector_widget.dart';
import 'dart:math';

// ─── Worker Data Model ────────────────────────────────────────────────────────

class PekerjaModel {
  final String id;
  final String nama;
  final String email;
  final String nik;
  final String idPekerja;
  final String peran;
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

  const PekerjaModel({
    required this.id,
    required this.nama,
    required this.email,
    required this.nik,
    required this.idPekerja,
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

  PekerjaModel copyWith({
    String? id,
    String? nama,
    String? email,
    String? nik,
    String? idPekerja,
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
    return PekerjaModel(
      id: id ?? this.id,
      nama: nama ?? this.nama,
      email: email ?? this.email,
      nik: nik ?? this.nik,
      idPekerja: idPekerja ?? this.idPekerja,
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

  /// Build a PekerjaModel from a Supabase DB row map.
  factory PekerjaModel.fromMap(Map<String, dynamic> map) {
    final permsRaw = map['permissions'];
    final List<String> perms = permsRaw is List
        ? List<String>.from(permsRaw.map((e) => e.toString()))
        : <String>[];

    // Parse avatar_color hex string to Color
    Color avatarColor = const Color(0xFF48C9B0);
    final colorStr = map['avatar_color'] as String?;
    if (colorStr != null && colorStr.startsWith('#')) {
      try {
        avatarColor = Color(
          int.parse(colorStr.replaceFirst('#', 'FF'), radix: 16),
        );
      } catch (_) {}
    }

    // Format createdAt from timestamptz
    String createdAt = '';
    final createdRaw = map['created_at'] as String?;
    if (createdRaw != null) {
      try {
        final dt = DateTime.parse(createdRaw);
        const months = [
          'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
          'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
        ];
        createdAt = '${months[dt.month - 1]} ${dt.year}';
      } catch (_) {
        createdAt = createdRaw;
      }
    }

    return PekerjaModel(
      id: map['id'] as String? ?? '',
      nama: map['nama'] as String? ?? '',
      email: map['email'] as String? ?? '',
      nik: map['nik'] as String? ?? '',
      idPekerja: map['id_pekerja'] as String? ?? '',
      peran: map['peran'] as String? ?? '',
      telepon: map['telepon'] as String? ?? '',
      isBertugas: map['is_bertugas'] as bool? ?? true,
      permissions: perms,
      avatarBg: avatarColor,
      username: map['username'] as String? ?? '',
      gender: map['gender'] as String? ?? '',
      birthPlace: map['birth_place'] as String? ?? '',
      birthDate: map['birth_date'] as String? ?? '',
      address: map['address'] as String? ?? '',
      province: map['province'] as String? ?? '',
      district: map['district'] as String? ?? '',
      subDistrict: map['sub_district'] as String? ?? '',
      village: map['village'] as String? ?? '',
      createdAt: createdAt,
    );
  }
}

// ─── Async State for Pekerja List ─────────────────────────────────────────────

class PekerjaListState {
  final List<PekerjaModel> workers;
  final bool isLoading;
  final String? error;

  const PekerjaListState({
    this.workers = const [],
    this.isLoading = false,
    this.error,
  });

  PekerjaListState copyWith({
    List<PekerjaModel>? workers,
    bool? isLoading,
    String? error,
  }) {
    return PekerjaListState(
      workers: workers ?? this.workers,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// ─── Async Notifier ──────────────────────────────────────────────────────────

class PekerjaListNotifier extends StateNotifier<PekerjaListState> {
  final SupabaseService _service = SupabaseService();
  String? _ownerId;

  PekerjaListNotifier() : super(const PekerjaListState());

  /// Called once when the widget mounts — loads workers from DB.
  Future<void> loadWorkers(String ownerId) async {
    _ownerId = ownerId;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final rows = await _service.fetchPekerjaList(ownerId);
      final workers = rows.map(PekerjaModel.fromMap).toList();
      state = state.copyWith(workers: workers, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Gagal memuat data pekerja: $e',
      );
    }
  }

  /// Insert a new worker into DB then refresh local state.
  Future<String?> addPekerja({
    required String nama,
    String email = '',
    String nik = '',
    String idPekerja = '',
    String peran = '',
    String telepon = '',
    String username = '',
    String gender = 'Laki-laki',
    String birthPlace = '',
    String birthDate = '',
    String address = '',
    String province = '',
    String district = '',
    String subDistrict = '',
    String village = '',
    List<String> permissions = const ['DASHBOARD'],
    String avatarColor = '#48C9B0',
  }) async {
    if (_ownerId == null) return 'Owner ID tidak tersedia.';
    try {
      final row = await _service.insertPekerja(
        ownerId: _ownerId!,
        nama: nama,
        email: email.isEmpty ? null : email,
        nik: nik.isEmpty ? null : nik,
        idPekerja: idPekerja.isEmpty ? null : idPekerja,
        peran: peran.isEmpty ? null : peran,
        telepon: telepon.isEmpty ? null : telepon,
        username: username.isEmpty ? null : username,
        gender: gender.isEmpty ? null : gender,
        birthPlace: birthPlace.isEmpty ? null : birthPlace,
        birthDate: birthDate.isEmpty ? null : birthDate,
        address: address.isEmpty ? null : address,
        province: province.isEmpty ? null : province,
        district: district.isEmpty ? null : district,
        subDistrict: subDistrict.isEmpty ? null : subDistrict,
        village: village.isEmpty ? null : village,
        isBertugas: true,
        permissions: permissions,
        avatarColor: avatarColor,
      );
      if (row != null) {
        final newWorker = PekerjaModel.fromMap(row);
        state = state.copyWith(workers: [...state.workers, newWorker]);
      }
      return null; // success
    } catch (e) {
      return 'Gagal menambahkan pekerja: $e';
    }
  }

  /// Update existing worker in DB then refresh local state.
  Future<String?> editPekerja({
    required String workerId,
    String? nama,
    String? email,
    String? nik,
    String? idPekerja,
    String? peran,
    String? telepon,
    String? username,
    String? gender,
    String? birthPlace,
    String? birthDate,
    String? address,
    String? province,
    String? district,
    String? subDistrict,
    String? village,
  }) async {
    try {
      await _service.updatePekerja(
        workerId: workerId,
        nama: nama,
        email: email,
        nik: nik,
        idPekerja: idPekerja,
        peran: peran,
        telepon: telepon,
        username: username,
        gender: gender,
        birthPlace: birthPlace,
        birthDate: birthDate,
        address: address,
        province: province,
        district: district,
        subDistrict: subDistrict,
        village: village,
      );
      // Update local state
      state = state.copyWith(
        workers: state.workers.map((w) {
          if (w.id != workerId) return w;
          return w.copyWith(
            nama: nama,
            email: email,
            nik: nik,
            idPekerja: idPekerja,
            peran: peran,
            telepon: telepon,
            username: username,
            gender: gender,
            birthPlace: birthPlace,
            birthDate: birthDate,
            address: address,
            province: province,
            district: district,
            subDistrict: subDistrict,
            village: village,
          );
        }).toList(),
      );
      return null;
    } catch (e) {
      return 'Gagal memperbarui pekerja: $e';
    }
  }

  /// Toggle duty status in DB and local state.
  Future<void> toggleDuty(String workerId, bool current) async {
    final next = !current;
    // Optimistic update
    state = state.copyWith(
      workers: state.workers.map((w) {
        return w.id == workerId ? w.copyWith(isBertugas: next) : w;
      }).toList(),
    );
    await _service.togglePekerjaDuty(workerId, next);
  }

  /// Update permissions in DB and local state.
  Future<void> updatePermissions(String workerId, List<String> permissions) async {
    // Optimistic update
    state = state.copyWith(
      workers: state.workers.map((w) {
        return w.id == workerId ? w.copyWith(permissions: permissions) : w;
      }).toList(),
    );
    await _service.updatePekerjaPermissions(workerId, permissions);
  }

  /// Delete worker from DB and local state.
  Future<String?> removePekerja(String workerId) async {
    try {
      await _service.deletePekerja(workerId);
      state = state.copyWith(
        workers: state.workers.where((w) => w.id != workerId).toList(),
      );
      return null;
    } catch (e) {
      return 'Gagal menghapus pekerja: $e';
    }
  }
}

final pekerjaListProvider =
    StateNotifierProvider<PekerjaListNotifier, PekerjaListState>((ref) {
  return PekerjaListNotifier();
});

// ─── Main Management Pekerja Widget ──────────────────────────────────────────

class ManagementPekerjaWidget extends ConsumerStatefulWidget {
  const ManagementPekerjaWidget({super.key});

  @override
  ConsumerState<ManagementPekerjaWidget> createState() =>
      _ManagementPekerjaWidgetState();
}

class _ManagementPekerjaWidgetState
    extends ConsumerState<ManagementPekerjaWidget> {
  String _searchQuery = '';
  String _roleFilter = 'SEMUA';
  int _visibleCount = 6; // lazy-load batch size
  static const int _batchSize = 6;

  final List<String> _availableRoles = const [
    'Petugas Kebersihan',
    'Satpam / Security',
    'Sopir Ambulans',
    'Teknisi / Maintenance',
    'Admin Logistik',
    'Staf Umum',
  ];

  @override
  void initState() {
    super.initState();
    // Defer provider mutation until after first frame to avoid
    // "modified provider during build" error.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final landingState = ref.read(landingPageProvider);
      final ownerId = landingState.loggedInUser?['id'] as String?;
      if (ownerId != null && ownerId.isNotEmpty) {
        ref.read(pekerjaListProvider.notifier).loadWorkers(ownerId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(landingPageProvider);
    final pekerjaState = ref.watch(pekerjaListProvider);
    final allWorkers = pekerjaState.workers;
    final isLoading = pekerjaState.isLoading;

    final isDark = state.appearance == 'dark';
    final cardBgColor = isDark ? const Color(0xFF161619) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1B0C3C);
    final subtitleColor = isDark ? Colors.grey[400]! : const Color(0xFF6F6A8A);
    final borderColor = isDark ? const Color(0xFF252528) : const Color(0xFFECEEF2);
    final isRev = state.appearance == 'rev';
    final themeAccent = isRev ? const Color(0xFFB577F2) : const Color(0xFF48C9B0);
    final isMobile = MediaQuery.of(context).size.width < 768;

    final filteredWorkers = allWorkers.where((w) {
      final q = _searchQuery.toLowerCase();
      final matchesQuery = w.nama.toLowerCase().contains(q) ||
          w.nik.contains(q) ||
          w.peran.toLowerCase().contains(q) ||
          w.telepon.contains(q);
      final matchesRole = _roleFilter == 'SEMUA' || w.peran == _roleFilter;
      return matchesQuery && matchesRole;
    }).toList();

    final totalWorkers = allWorkers.length;
    final activeWorkers = allWorkers.where((w) => w.isBertugas).length;
    final securityDriversCount = allWorkers
        .where((w) => w.peran.contains('Satpam') || w.peran.contains('Ambulans'))
        .length;
    final techHygieneCount = allWorkers
        .where((w) => w.peran.contains('Kebersihan') || w.peran.contains('Teknisi'))
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Metrics Summary Header ──────────────────────────────────────────
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: isMobile ? 2 : 4,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.6,
          children: [
            MetricCard(
              icon: Icons.engineering_rounded,
              label: state.language == 'en' ? 'TOTAL WORKERS' : 'TOTAL PEKERJA',
              count: '$totalWorkers ${state.language == 'en' ? 'People' : 'Orang'}',
              subtitleColor: subtitleColor,
              countColor: textColor,
              cardBgColor: cardBgColor,
              borderColor: borderColor,
            ),
            MetricCard(
              icon: Icons.check_circle_outline_rounded,
              label: state.language == 'en' ? 'ON-DUTY TODAY' : 'BERTUGAS HARI INI',
              count: '$activeWorkers ${state.language == 'en' ? 'Active' : 'Aktif'}',
              subtitleColor: subtitleColor,
              countColor: const Color(0xFF48C9B0),
              cardBgColor: cardBgColor,
              borderColor: borderColor,
            ),
            MetricCard(
              icon: Icons.shield_outlined,
              label: state.language == 'en' ? 'SECURITY & DRIVERS' : 'SATPAM & AMBULANS',
              count: '$securityDriversCount ${state.language == 'en' ? 'People' : 'Orang'}',
              subtitleColor: subtitleColor,
              countColor: themeAccent,
              cardBgColor: cardBgColor,
              borderColor: borderColor,
            ),
            MetricCard(
              icon: Icons.build_circle_outlined,
              label: state.language == 'en' ? 'TECH & HYGIENE' : 'TEKNISI & KEBERSIHAN',
              count: '$techHygieneCount ${state.language == 'en' ? 'People' : 'Orang'}',
              subtitleColor: subtitleColor,
              countColor: const Color(0xFFF39C12),
              cardBgColor: cardBgColor,
              borderColor: borderColor,
            ),
          ],
        ),

        const SizedBox(height: 24),

        // ── Controls Panel ────────────────────────────────────────────────
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  width: isMobile ? 200 : 320,
                  height: 46,
                  decoration: BoxDecoration(
                    color: cardBgColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: borderColor),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      Icon(Icons.search_rounded, size: 18, color: subtitleColor),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          style: GoogleFonts.outfit(fontSize: 12, color: textColor),
                          decoration: InputDecoration(
                            hintText: state.language == 'en'
                                ? 'Search name, NIK, or role...'
                                : 'Cari nama, NIK, atau peran...',
                            hintStyle: GoogleFonts.outfit(
                              fontSize: 11,
                              color: subtitleColor.withOpacity(0.6),
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          onChanged: (val) => setState(() {
                            _searchQuery = val;
                            _visibleCount = _batchSize; // reset lazy window
                          }),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 46,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: cardBgColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: borderColor),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _roleFilter,
                      icon: Icon(Icons.keyboard_arrow_down_rounded, color: subtitleColor, size: 20),
                      style: GoogleFonts.outfit(fontSize: 12, color: textColor, fontWeight: FontWeight.w600),
                      dropdownColor: cardBgColor,
                      items: [
                        DropdownMenuItem(
                          value: 'SEMUA',
                          child: Text(state.language == 'en' ? 'All Roles' : 'Semua Peran'),
                        ),
                        ..._availableRoles.map(
                          (r) => DropdownMenuItem(value: r, child: Text(r)),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() {
                          _roleFilter = val;
                          _visibleCount = _batchSize; // reset lazy window
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),
            ElevatedButton.icon(
              onPressed: () => _showWorkerFormDialog(context, ref),
              icon: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
              label: Text(
                state.language == 'en' ? '+ Add Worker' : '+ Tambah Pekerja',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: themeAccent,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // ── Loading / Grid ────────────────────────────────────────────────
        if (isLoading)
          Container(
            height: 200,
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: themeAccent, strokeWidth: 2),
                const SizedBox(height: 12),
                Text(
                  'Memuat data pekerja...',
                  style: GoogleFonts.outfit(fontSize: 13, color: subtitleColor),
                ),
              ],
            ),
          )
        else if (pekerjaState.error != null)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cardBgColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.redAccent),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    pekerjaState.error!,
                    style: GoogleFonts.outfit(fontSize: 12, color: Colors.redAccent),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    final s = ref.read(landingPageProvider);
                    final ownerId = s.loggedInUser?['id'] as String?;
                    if (ownerId != null) {
                      ref.read(pekerjaListProvider.notifier).loadWorkers(ownerId);
                    }
                  },
                  child: Text('Retry', style: GoogleFonts.outfit(color: themeAccent)),
                ),
              ],
            ),
          )
        else
          NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              // Lazy-load: reveal next batch when user nears the bottom
              if (notification is ScrollEndNotification ||
                  notification is ScrollUpdateNotification) {
                final metrics = notification.metrics;
                if (metrics.pixels >= metrics.maxScrollExtent - 300) {
                  if (_visibleCount < filteredWorkers.length + 1) {
                    setState(() {
                      _visibleCount = (_visibleCount + _batchSize)
                          .clamp(0, filteredWorkers.length + 1);
                    });
                  }
                }
              }
              return false;
            },
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _visibleCount.clamp(0, filteredWorkers.length + 1),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: isMobile ? 1 : 3,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                mainAxisExtent: 280,
              ),
              itemBuilder: (context, index) {
                if (index < filteredWorkers.length) {
                  final worker = filteredWorkers[index];
                  return _buildWorkerGridCard(
                    context,
                    ref,
                    worker: worker,
                    state: state,
                    cardBgColor: cardBgColor,
                    textColor: textColor,
                    subtitleColor: subtitleColor,
                    borderColor: borderColor,
                    themeAccent: themeAccent,
                  );
                } else {
                  return _buildRegisterWorkerCard(
                    context,
                    cardBgColor,
                    borderColor,
                    textColor,
                    subtitleColor,
                  );
                }
              },
            ),
          ),
      ],
    );
  }

  // ── Grid Worker Card ──────────────────────────────────────────────────────

  Widget _buildWorkerGridCard(
    BuildContext context,
    WidgetRef ref, {
    required PekerjaModel worker,
    required LandingPageState state,
    required Color cardBgColor,
    required Color textColor,
    required Color subtitleColor,
    required Color borderColor,
    required Color themeAccent,
  }) {
    final initials = worker.nama.isNotEmpty
        ? worker.nama.trim().split(' ').map((e) => e[0]).take(2).join('').toUpperCase()
        : 'W';

    return GestureDetector(
      onTap: () => _showWorkerDetailDialog(context, ref, worker: worker),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: cardBgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: worker.avatarBg.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initials,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: worker.avatarBg,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        worker.nama,
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: textColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF48C9B0).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          worker.peran.toUpperCase(),
                          style: GoogleFonts.outfit(
                            fontSize: 7,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF48C9B0),
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
            Divider(color: borderColor, height: 1),
            const SizedBox(height: 12),
            _buildDetailRowItem(Icons.badge_outlined, 'NIK: ${worker.nik.isEmpty ? '-' : worker.nik}', subtitleColor),
            _buildDetailRowItem(Icons.assignment_ind_outlined, 'SIP: ${worker.idPekerja.isEmpty ? '-' : worker.idPekerja}', subtitleColor),
            _buildDetailRowItem(Icons.phone_outlined, worker.telepon.isEmpty ? '-' : worker.telepon, subtitleColor),
            const SizedBox(height: 12),
            Expanded(
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: worker.permissions.map((p) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: subtitleColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: borderColor),
                    ),
                    child: Text(
                      p,
                      style: GoogleFonts.outfit(
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        color: subtitleColor,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.shield_outlined, size: 18),
                  color: subtitleColor.withOpacity(0.7),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Detail & Hak Akses',
                  onPressed: () => _showWorkerDetailDialog(context, ref, worker: worker, startTabIndex: 1),
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  color: Colors.redAccent.withOpacity(0.8),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Hapus Pekerja',
                  onPressed: () => _showDeleteConfirmDialog(context, ref, worker: worker),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegisterWorkerCard(
    BuildContext context,
    Color cardBg,
    Color border,
    Color text,
    Color subtitle,
  ) {
    return GestureDetector(
      onTap: () => _showWorkerFormDialog(context, ref),
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
                'Register New Worker',
                style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: text),
              ),
              const SizedBox(height: 6),
              Text(
                'Complete the form to add a new operational worker.',
                style: GoogleFonts.outfit(fontSize: 9, color: subtitle),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRowItem(IconData icon, String text, Color subColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 14, color: subColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600, color: subColor),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  List<String> _getAvailableMenusForRole(LandingPageState state) {
    final role = (state.loggedInRole ?? state.loggedInUser?['role'] as String?)
            ?.toLowerCase() ??
        'puskesmas';

    if (role == 'dokter') {
      return [
        'DASHBOARD',
        'PASIEN',
        'OBAT',
        'ANTRIAN',
        'PEMERIKSAAN',
        'PEMBUKUAN',
        'ASISTEN PRAKTIK',
      ];
    } else if (role == 'apotek') {
      return [
        'DASHBOARD',
        'POS (PENJUALAN)',
        'INVENTORI',
        'PESANAN MASUK',
        'LAPORAN KEUANGAN',
        'MANAJEMEN STAFF',
        'MANAGEMENT PEKERJA',
      ];
    } else if (role == 'ponkesdes') {
      return [
        'DASHBOARD',
        'PASIEN',
        'OBAT',
        'ANTRIAN',
        'PEMERIKSAAN',
        'PEMBUKUAN',
        'MANAGEMENT PEKERJA',
      ];
    } else {
      // puskesmas or default
      return [
        'DASHBOARD',
        'PASIEN',
        'PANTAUAN IBU HAMIL',
        'FORM IBU HAMIL',
        'SKRINING STUNTING',
        'RUJUKAN INTERNAL',
        'HOME CARE POSYANDU',
        'EPOSYANDU EWRS',
        'SATUSEHAT PRO',
        'BPJS PCARE BRIDGING',
        'OBAT',
        'ANTRIAN',
        'PEMERIKSAAN',
        'PEMBUKUAN',
        'MANAGEMENT PEKERJA',
      ];
    }
  }

  // ── 3-Tab Worker Detail Dialog ────────────────────────────────────────────

  void _showWorkerDetailDialog(
    BuildContext context,
    WidgetRef ref, {
    required PekerjaModel worker,
    int startTabIndex = 0,
  }) {
    String detailPermSearchQuery = '';
    String detailClusterFilter = 'all';
    String detailDlcSubFilter = 'all_dlc';

    showDialog(
      context: context,
      builder: (context) {
        return DefaultTabController(
          length: 3,
          initialIndex: startTabIndex,
          child: StatefulBuilder(
            builder: (context, setModalState) {
              final state = ref.watch(landingPageProvider);
              final allWorkers = ref.watch(pekerjaListProvider).workers;
              final currentWorker = allWorkers.firstWhere(
                (w) => w.id == worker.id,
                orElse: () => worker,
              );

              final isDark = state.appearance == 'dark';
              final dialogBg = isDark ? const Color(0xFF1E1E22) : Colors.white;
              final txtColor = isDark ? Colors.white : const Color(0xFF1B0C3C);
              final subColor = isDark ? Colors.grey[400]! : const Color(0xFF6F6A8A);
              final borderColor = isDark ? const Color(0xFF2E2E32) : const Color(0xFFECEEF2);
              final tealAccent = const Color(0xFF48C9B0);

              final availablePerms = _getAvailableMenusForRole(state);

              final roleTemplates = {
                'Standard Worker (Default)': ['DASHBOARD', 'PASIEN', 'OBAT', 'ANTRIAN', 'PEMERIKSAAN'],
                'Security Guard': ['DASHBOARD', 'KEAMANAN', 'FASILITAS', 'ANTRIAN'],
                'Driver Ambulans': ['DASHBOARD', 'AMBULANS', 'PASIEN'],
                'Admin Logistik': ['DASHBOARD', 'LOGISTIK', 'OBAT', 'FASILITAS'],
              };

              String selectedTemplate = 'Custom';
              roleTemplates.forEach((key, val) {
                if (val.length == currentWorker.permissions.length &&
                    val.every((p) => currentWorker.permissions.contains(p))) {
                  selectedTemplate = key;
                }
              });

              final initials = currentWorker.nama.isNotEmpty
                  ? currentWorker.nama.trim().split(' ').map((e) => e[0]).take(2).join('').toUpperCase()
                  : 'W';

              return Dialog(
                backgroundColor: dialogBg,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680, maxHeight: 720),
                  child: Column(
                    children: [
                      // Header Banner
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            height: 120,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [tealAccent.withOpacity(0.85), tealAccent.withOpacity(0.55)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(24),
                                topRight: Radius.circular(24),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 14, right: 14,
                            child: IconButton(
                              icon: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ),
                          Positioned(
                            bottom: 14, right: 20,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.25),
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 6, height: 6,
                                    decoration: BoxDecoration(
                                      color: currentWorker.isBertugas ? Colors.white : Colors.grey[400],
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    currentWorker.isBertugas ? 'ACTIVE' : 'OFF DUTY',
                                    style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            left: 24, bottom: -24,
                            child: Container(
                              width: 80, height: 80,
                              decoration: BoxDecoration(
                                color: tealAccent,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 4),
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 10, offset: const Offset(0, 4))],
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                initials,
                                style: GoogleFonts.outfit(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 36),

                      TabBar(
                        labelColor: tealAccent,
                        unselectedLabelColor: subColor,
                        indicatorColor: tealAccent,
                        labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 11),
                        unselectedLabelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 11),
                        indicatorSize: TabBarIndicatorSize.label,
                        tabs: const [
                          Tab(text: 'DATA PERSONAL'),
                          Tab(text: 'IZIN AKSES'),
                          Tab(text: 'PERFORMA USER'),
                        ],
                      ),

                      Divider(color: borderColor, height: 1),

                      Expanded(
                        child: TabBarView(
                          children: [
                            // ── TAB 1: DATA PERSONAL ──────────────────────
                            SingleChildScrollView(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(currentWorker.nama,
                                              style: GoogleFonts.outfit(fontSize: 19, fontWeight: FontWeight.w900, color: txtColor)),
                                            Text('@${currentWorker.username.isEmpty ? currentWorker.nama.toLowerCase().split(' ').first : currentWorker.username}',
                                              style: GoogleFonts.outfit(fontSize: 12, color: tealAccent, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                      ),
                                      TextButton.icon(
                                        icon: Icon(Icons.edit_outlined, size: 15, color: tealAccent),
                                        label: Text('Edit', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: tealAccent)),
                                        onPressed: () {
                                          Navigator.pop(context);
                                          _showWorkerFormDialog(context, ref, worker: currentWorker);
                                        },
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 24),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                        _buildDetailSectionTitle('INFORMASI PRIBADI', subColor),
                                        const SizedBox(height: 12),
                                        _buildDetailFieldItem(icon: Icons.badge_outlined, label: 'NIK (KTP)', value: currentWorker.nik, txtColor: txtColor, subColor: subColor),
                                        const SizedBox(height: 12),
                                        _buildDetailFieldItem(icon: Icons.cake_outlined, label: 'TEMPAT & TANGGAL LAHIR', value: '${currentWorker.birthPlace}, ${currentWorker.birthDate}', txtColor: txtColor, subColor: subColor),
                                        const SizedBox(height: 12),
                                        _buildDetailFieldItem(icon: Icons.email_outlined, label: 'ALAMAT EMAIL', value: currentWorker.email, txtColor: txtColor, subColor: subColor),
                                      ])),
                                      const SizedBox(width: 20),
                                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                        _buildDetailSectionTitle('DETAIL PEKERJAAN', subColor),
                                        const SizedBox(height: 12),
                                        _buildDetailFieldItem(icon: Icons.phone_android_outlined, label: 'WHATSAPP / TELEPON', value: currentWorker.telepon, txtColor: txtColor, subColor: subColor),
                                        const SizedBox(height: 12),
                                        _buildDetailFieldItem(icon: Icons.location_on_outlined, label: 'ALAMAT DOMISILI', value: currentWorker.address, txtColor: txtColor, subColor: subColor),
                                        const SizedBox(height: 12),
                                        _buildDetailFieldItem(icon: Icons.calendar_today_outlined, label: 'TANGGAL BERGABUNG', value: currentWorker.createdAt, txtColor: txtColor, subColor: subColor),
                                      ])),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // ── TAB 2: IZIN AKSES ─────────────────────────
                            SingleChildScrollView(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildDetailSectionTitle('ROLE TEMPLATE / POSISI', subColor),
                                  const SizedBox(height: 10),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(horizontal: 14),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF252529) : const Color(0xFFF3F4F8),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: selectedTemplate,
                                        isExpanded: true,
                                        style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: txtColor),
                                        dropdownColor: dialogBg,
                                        items: [
                                          const DropdownMenuItem(value: 'Custom', child: Text('Custom Access (Manual)')),
                                          ...roleTemplates.keys.map((t) => DropdownMenuItem(value: t, child: Text(t))),
                                        ],
                                        onChanged: (val) {
                                          if (val != null && roleTemplates.containsKey(val)) {
                                            ref.read(pekerjaListProvider.notifier).updatePermissions(currentWorker.id, roleTemplates[val]!);
                                            setModalState(() {});
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  _buildDetailSectionTitle('IZIN AKSES MENU (CUSTOM)', subColor),
                                  const SizedBox(height: 4),
                                  Text('Pilih modul yang dapat diakses oleh pekerja ini dalam sistem.', style: GoogleFonts.outfit(fontSize: 11, color: subColor)),
                                  const SizedBox(height: 16),
                                  _buildPermissionSearchAndFilterSection(
                                    context: context,
                                    searchQuery: detailPermSearchQuery,
                                    selectedCluster: detailClusterFilter,
                                    selectedDlcSub: detailDlcSubFilter,
                                    availablePerms: availablePerms,
                                    currentSelectedPerms: currentWorker.permissions,
                                    txtColor: txtColor,
                                    subColor: subColor,
                                    borderColor: borderColor,
                                    accentColor: tealAccent,
                                    isDark: isDark,
                                    onSearchChanged: (q) => setModalState(() => detailPermSearchQuery = q),
                                    onClusterChanged: (c) => setModalState(() => detailClusterFilter = c),
                                    onDlcSubChanged: (sc) => setModalState(() => detailDlcSubFilter = sc),
                                    onPermissionsUpdated: (updatedPerms) {
                                      ref.read(pekerjaListProvider.notifier).updatePermissions(currentWorker.id, updatedPerms);
                                      setModalState(() {});
                                    },
                                  ),
                                ],
                              ),
                            ),

                            // ── TAB 3: PERFORMA USER (Coming Soon) ────────
                            SingleChildScrollView(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildDetailSectionTitle('METRIK PERFORMA & KINERJA PEKERJA', subColor),
                                  const SizedBox(height: 24),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF252529) : const Color(0xFFF8F9FC),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: isDark ? const Color(0xFF333338) : const Color(0xFFE8EBF0),
                                        style: BorderStyle.solid,
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        Icon(Icons.bar_chart_rounded, size: 48, color: tealAccent.withOpacity(0.5)),
                                        const SizedBox(height: 16),
                                        Text(
                                          'Coming Soon',
                                          style: GoogleFonts.outfit(
                                            fontSize: 22,
                                            fontWeight: FontWeight.w900,
                                            color: txtColor,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Fitur Performa User sedang dalam pengembangan.\nData kinerja dan metrik pekerja akan segera tersedia.',
                                          style: GoogleFonts.outfit(fontSize: 12, color: subColor, height: 1.6),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      Divider(color: borderColor, height: 1),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            TextButton.icon(
                              icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Colors.redAccent),
                              label: Text('HAPUS DATA WORKER',
                                style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                              onPressed: () {
                                Navigator.pop(context);
                                _showDeleteConfirmDialog(context, ref, worker: currentWorker);
                              },
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: tealAccent,
                                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                              ),
                              child: Text('TUTUP', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.white)),
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

  Widget _buildDetailSectionTitle(String title, Color subColor) {
    return Row(
      children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: subColor, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(title, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: subColor, letterSpacing: 0.8)),
      ],
    );
  }

  Widget _buildDetailFieldItem({required IconData icon, required String label, required String value, required Color txtColor, required Color subColor}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: subColor),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.bold, color: subColor)),
              const SizedBox(height: 2),
              Text(value.isEmpty ? '-' : value, style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: txtColor)),
            ],
          ),
        ),
      ],
    );
  }



  Widget _buildPermissionSearchAndFilterSection({
    required BuildContext context,
    required String searchQuery,
    required String selectedCluster,
    required String selectedDlcSub,
    required List<String> availablePerms,
    required List<String> currentSelectedPerms,
    required Color txtColor,
    required Color subColor,
    required Color borderColor,
    required Color accentColor,
    required bool isDark,
    required Function(String query) onSearchChanged,
    required Function(String cluster) onClusterChanged,
    required Function(String dlcSub) onDlcSubChanged,
    required Function(List<String> updatedPerms) onPermissionsUpdated,
  }) {
    final primaryClusters = [
      {'id': 'all', 'label': 'All Clusters', 'icon': Icons.grid_view_rounded},
      {'id': 'cluster_1', 'label': 'Cluster 1 (Management)', 'icon': Icons.business_center_rounded},
      {'id': 'cluster_2', 'label': 'Cluster 2 (Maternal & Child)', 'icon': Icons.face_rounded},
      {'id': 'cluster_3', 'label': 'Cluster 3 (Adult & Elderly)', 'icon': Icons.nordic_walking_rounded},
      {'id': 'lintas_cluster', 'label': 'Cross Cluster', 'icon': Icons.hub_rounded},
      {'id': 'custom_menu', 'label': 'Custom Menu (DLC)', 'icon': Icons.extension_rounded, 'badge': 'DLC'},
    ];

    final dlcSubCategories = [
      {'id': 'all_dlc', 'label': 'Semua Inovasi DLC', 'icon': Icons.auto_awesome_rounded},
      {'id': 'kia_dlc', 'label': 'Kesehatan Ibu & Anak (KIA)', 'icon': Icons.pregnant_woman_rounded},
      {'id': 'pelayanan_dlc', 'label': 'Pelayanan Medis & Posyandu', 'icon': Icons.medical_services_rounded},
      {'id': 'sistem_dlc', 'label': 'Integrasi Sistem & SatuSehat', 'icon': Icons.dns_rounded},
    ];

    final List<PuskesmasPermissionModel> permissionModels = availablePerms
        .map(getPermissionModel)
        .toList();

    final filteredList = permissionModels.where((item) {
      final q = searchQuery.trim().toLowerCase();
      final matchesQuery = q.isEmpty ||
          item.name.toLowerCase().contains(q) ||
          item.badge.toLowerCase().contains(q) ||
          item.categoryLabel.toLowerCase().contains(q);

      if (!matchesQuery) return false;

      if (selectedCluster == 'all') {
        return true;
      } else if (selectedCluster == 'custom_menu') {
        if (item.mainCluster != 'custom_menu') return false;
        if (selectedDlcSub == 'all_dlc') return true;
        return item.dlcSubCat == selectedDlcSub;
      } else if (selectedCluster == 'cluster_2' || selectedCluster == 'cluster_3') {
        return item.mainCluster == 'cluster_2' || item.mainCluster == 'cluster_3';
      } else {
        return item.mainCluster == selectedCluster;
      }
    }).toList();

    final allSelected = filteredList.isNotEmpty &&
        filteredList.every((p) => currentSelectedPerms.contains(p.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── PUSKESMAS CLUSTER LEVEL FILTER ─────────────────────────────────────
        Row(
          children: [
            Icon(Icons.tune_rounded, size: 14, color: accentColor),
            const SizedBox(width: 6),
            Text(
              'PUSKESMAS CLUSTER LEVEL FILTER',
              style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: accentColor, letterSpacing: 0.8),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Row 1: Primary Clusters Chips
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: primaryClusters.map((c) {
            final cId = c['id'] as String;
            final isSel = selectedCluster == cId;
            final isDlc = cId == 'custom_menu';
            final badge = c['badge'] as String?;

            return InkWell(
              onTap: () => onClusterChanged(cId),
              borderRadius: BorderRadius.circular(100),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: isSel
                      ? accentColor
                      : (isDark ? const Color(0xFF252529) : const Color(0xFFF3F4F8)),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                    color: isSel ? accentColor : (isDlc ? accentColor.withOpacity(0.4) : borderColor),
                    width: isDlc ? 1.5 : 1.0,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      c['icon'] as IconData,
                      size: 13,
                      color: isSel ? Colors.white : (isDlc ? accentColor : subColor),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      c['label'] as String,
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isSel ? Colors.white : txtColor,
                      ),
                    ),
                    if (badge != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: isSel ? Colors.white.withOpacity(0.25) : accentColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badge,
                          style: GoogleFonts.outfit(
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            color: isSel ? Colors.white : accentColor,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
        ),

        // Row 2: Sub-category chips box (when Custom Menu DLC is active)
        if (selectedCluster == 'custom_menu') ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: accentColor.withOpacity(0.3),
                width: 1.2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.subdirectory_arrow_right_rounded, size: 14, color: accentColor),
                    const SizedBox(width: 4),
                    Text(
                      'SUB-KATEGORI INOVASI DLC',
                      style: GoogleFonts.outfit(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: accentColor,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: dlcSubCategories.map((sc) {
                    final scId = sc['id'] as String;
                    final isSel = selectedDlcSub == scId;

                    return InkWell(
                      onTap: () => onDlcSubChanged(scId),
                      borderRadius: BorderRadius.circular(100),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSel
                              ? accentColor
                              : (isDark ? const Color(0xFF1E1E22) : Colors.white),
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(
                            color: isSel ? accentColor : borderColor,
                            width: isSel ? 1.5 : 1.0,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              sc['icon'] as IconData,
                              size: 13,
                              color: isSel ? Colors.white : subColor,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              sc['label'] as String,
                              style: GoogleFonts.outfit(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isSel ? Colors.white : txtColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 12),
        Divider(color: borderColor, height: 1, thickness: 1),
        const SizedBox(height: 14),

        // Search Bar & Select All Action
        Row(
          children: [
            Expanded(
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF252529) : const Color(0xFFF3F4F8),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Icon(Icons.search_rounded, size: 18, color: subColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: TextEditingController.fromValue(
                          TextEditingValue(
                            text: searchQuery,
                            selection: TextSelection.collapsed(offset: searchQuery.length),
                          ),
                        ),
                        style: GoogleFonts.outfit(fontSize: 12, color: txtColor),
                        decoration: InputDecoration(
                          hintText: 'Cari modul (Pasien, KIA, Obat, Bridging)...',
                          hintStyle: GoogleFonts.outfit(fontSize: 11, color: subColor.withOpacity(0.6)),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        onChanged: onSearchChanged,
                      ),
                    ),
                    if (searchQuery.isNotEmpty)
                      GestureDetector(
                        onTap: () => onSearchChanged(''),
                        child: Icon(Icons.close_rounded, size: 16, color: subColor),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton.icon(
              icon: Icon(
                allSelected ? Icons.deselect_rounded : Icons.select_all_rounded,
                size: 15,
                color: Colors.white,
              ),
              label: Text(
                allSelected ? 'Batal Semua' : 'Pilih Semua',
                style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              onPressed: () {
                final nextPerms = List<String>.from(currentSelectedPerms);
                if (allSelected) {
                  for (final p in filteredList) {
                    nextPerms.remove(p.id);
                  }
                } else {
                  for (final p in filteredList) {
                    if (!nextPerms.contains(p.id)) nextPerms.add(p.id);
                  }
                }
                onPermissionsUpdated(nextPerms);
              },
            ),
          ],
        ),

        const SizedBox(height: 14),

        // Permissions Cards List
        if (filteredList.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF252529) : const Color(0xFFF8F9FC),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Icon(Icons.search_off_rounded, size: 28, color: subColor),
                const SizedBox(height: 8),
                Text(
                  'Tidak ada modul yang cocok dengan filter cluster & pencarian.',
                  style: GoogleFonts.outfit(fontSize: 12, color: subColor),
                ),
              ],
            ),
          )
        else
          ...filteredList.map((item) {
            final isChecked = currentSelectedPerms.contains(item.id);
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF252529) : const Color(0xFFF8F9FC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isChecked ? accentColor.withOpacity(0.5) : borderColor,
                  width: isChecked ? 1.5 : 1.0,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: isChecked
                          ? accentColor.withOpacity(0.15)
                          : (isDark ? const Color(0xFF1E1E22) : const Color(0xFFECEEF2)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(item.icon, size: 18, color: isChecked ? accentColor : subColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.name,
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: txtColor,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: accentColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                item.badge,
                                style: GoogleFonts.outfit(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: accentColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.categoryLabel,
                          style: GoogleFonts.outfit(fontSize: 10, color: subColor),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Checkbox(
                    value: isChecked,
                    activeColor: accentColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    onChanged: (val) {
                      final nextPerms = List<String>.from(currentSelectedPerms);
                      if (val == true) {
                        if (!nextPerms.contains(item.id)) nextPerms.add(item.id);
                      } else {
                        nextPerms.remove(item.id);
                      }
                      onPermissionsUpdated(nextPerms);
                    },
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  // ── Worker Add / Edit Form Dialog (matching assistant style) ──────────────

  void _showWorkerFormDialog(
    BuildContext context,
    WidgetRef ref, {
    PekerjaModel? worker,
  }) {
    final isEdit = worker != null;
    final state  = ref.read(landingPageProvider);

    // Available drawer menus filtered by institution role
    final availableMenus = _getAvailableMenusForRole(state);

    // Template presets
    const roleTemplates = <String, List<String>>{
      'Perawat / Bidan':           ['DASHBOARD', 'PASIEN', 'PEMERIKSAAN', 'ANTRIAN', 'PANTAUAN IBU HAMIL'],
      'Satpam / Security':         ['DASHBOARD', 'PASIEN', 'ANTRIAN'],
      'Sopir Ambulans':            ['DASHBOARD', 'PASIEN'],
      'Teknisi / Maintenance':     ['DASHBOARD'],
      'Admin Logistik':            ['DASHBOARD', 'OBAT', 'PEMBUKUAN'],
      'Petugas Kebersihan':        ['DASHBOARD'],
      'Staf Umum':                 ['DASHBOARD', 'PASIEN', 'ANTRIAN'],
      'Administrator Puskesmas':   ['DASHBOARD', 'PASIEN', 'PEMERIKSAAN', 'ANTRIAN', 'OBAT', 'PEMBUKUAN', 'MANAGEMENT PEKERJA'],
      'Lain-lain (Isi Sendiri)':   ['DASHBOARD'],
    };

    // Controllers
    final nameCtrl      = TextEditingController(text: worker?.nama      ?? '');
    final nikCtrl       = TextEditingController(text: worker?.nik       ?? '');
    final idCtrl        = TextEditingController(text: worker?.idPekerja ?? '');
    final emailCtrl     = TextEditingController(text: worker?.email     ?? '');
    final phoneCtrl     = TextEditingController(text: worker?.telepon   ?? '');
    final usernameCtrl  = TextEditingController(text: worker?.username  ?? '');
    final addressCtrl   = TextEditingController(text: worker?.address   ?? '');
    final birthPlaceCtrl= TextEditingController(text: worker?.birthPlace ?? '');
    final customRoleCtrl= TextEditingController(
      text: roleTemplates.containsKey(worker?.peran) ? '' : (worker?.peran ?? ''),
    );

    // Detect if existing peran matches a template
    String selectedTemplate = roleTemplates.keys.contains(worker?.peran)
        ? (worker!.peran)
        : 'Lain-lain (Isi Sendiri)';
    String selectedGender   = worker?.gender ?? 'Laki-laki';
    DateTime? selectedBirthDate = (worker?.birthDate != null && worker!.birthDate.isNotEmpty)
        ? DateTime.tryParse(worker.birthDate)
        : null;

    List<String> selectedPerms = List<String>.from(
      worker?.permissions ?? roleTemplates[selectedTemplate] ?? ['DASHBOARD'],
    );
    
    String formPermSearchQuery = '';
    String formClusterFilter = 'all';
    String formDlcSubFilter = 'all_dlc';

    String prov = worker?.province    ?? '';
    String kota = worker?.district    ?? '';
    String kec  = worker?.subDistrict ?? '';
    String kel  = worker?.village     ?? '';

    showDialog(
      context: context,
      useSafeArea: true,
      builder: (ctx) {
        final state      = ref.read(landingPageProvider);
        final isDark     = state.appearance == 'dark';
        final dialogBg   = isDark ? const Color(0xFF1E1E22) : Colors.white;
        final txtColor   = isDark ? Colors.white : const Color(0xFF1B0C3C);
        final subColor   = isDark ? Colors.grey[400]! : const Color(0xFF6F6A8A);
        final borderColor= isDark ? const Color(0xFF2C2C30) : const Color(0xFFECEEF2);
        final inputBg    = isDark ? const Color(0xFF252529) : const Color(0xFFF3F5FA);
        const teal       = Color(0xFF48C9B0);

        bool obscurePass = true;
        final passCtrl   = TextEditingController();

        Widget inputLabel(String text) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(text, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: subColor)),
        );

        Widget inputField(TextEditingController ctrl, String hint, {TextInputType? type, bool readOnly = false}) {
          return Container(
            height: 44,
            decoration: BoxDecoration(color: inputBg, borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              controller: ctrl,
              readOnly: readOnly,
              keyboardType: type,
              style: GoogleFonts.outfit(fontSize: 12, color: txtColor, fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: GoogleFonts.outfit(fontSize: 11, color: subColor.withAlpha(130)),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          );
        }

        Container section(String title, List<Widget> children) => Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(border: Border.all(color: borderColor), borderRadius: BorderRadius.circular(16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: teal)),
              const SizedBox(height: 12),
              ...children,
            ],
          ),
        );

        return StatefulBuilder(
          builder: (context, setS) {
            return Dialog(
              backgroundColor: dialogBg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700, maxHeight: 780),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Header ─────────────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.fromLTRB(28, 20, 20, 20),
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: borderColor)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(color: teal.withAlpha(26), borderRadius: BorderRadius.circular(12)),
                            child: const Icon(Icons.person_add_alt_1_rounded, color: teal, size: 20),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isEdit ? 'Edit Data Pekerja' : 'Register New Worker',
                                  style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900, color: txtColor),
                                ),
                                Text(
                                  isEdit
                                    ? 'Perbarui informasi pekerja Puskesmas.'
                                    : 'Lengkapi form untuk menambahkan pekerja operasional baru.',
                                  style: GoogleFonts.outfit(fontSize: 11, color: subColor),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close_rounded, color: subColor),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                    ),

                    // ── Scrollable Body ────────────────────────────────────
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [

                            // ── SECTION 1: INFORMASI AKUN ─────────────────
                            section('INFORMASI AKUN', [
                              Row(children: [
                                Expanded(
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    inputLabel('Template Role / Posisi'),
                                    Container(
                                      height: 44,
                                      decoration: BoxDecoration(color: inputBg, borderRadius: BorderRadius.circular(10)),
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          value: selectedTemplate,
                                          isExpanded: true,
                                          dropdownColor: dialogBg,
                                          style: GoogleFonts.outfit(fontSize: 12, color: txtColor, fontWeight: FontWeight.bold),
                                          items: roleTemplates.keys
                                              .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                                              .toList(),
                                          onChanged: (val) {
                                            if (val == null) return;
                                            setS(() {
                                              selectedTemplate = val;
                                              selectedPerms = List<String>.from(roleTemplates[val] ?? ['DASHBOARD']);
                                              if (val != 'Lain-lain (Isi Sendiri)') {
                                                customRoleCtrl.text = '';
                                              }
                                            });
                                          },
                                        ),
                                      ),
                                    ),
                                    // Free-text role when "Lain-lain"
                                    if (selectedTemplate == 'Lain-lain (Isi Sendiri)') ...[
                                      const SizedBox(height: 8),
                                      inputField(customRoleCtrl, 'Tulis jabatan / posisi sendiri...'),
                                    ],
                                  ]),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    inputLabel('Username'),
                                    inputField(usernameCtrl, '@ username pekerja'),
                                  ]),
                                ),
                              ]),
                              const SizedBox(height: 12),
                              Row(children: [
                                Expanded(
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    inputLabel('Email'),
                                    inputField(emailCtrl, 'contoh@puskesmas.go.id'),
                                  ]),
                                ),
                                const SizedBox(width: 14),
                                if (!isEdit)
                                  Expanded(
                                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      inputLabel('Password (Opsional)'),
                                      Container(
                                        height: 44,
                                        decoration: BoxDecoration(color: inputBg, borderRadius: BorderRadius.circular(10)),
                                        padding: const EdgeInsets.symmetric(horizontal: 12),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: TextField(
                                                controller: passCtrl,
                                                obscureText: obscurePass,
                                                style: GoogleFonts.outfit(fontSize: 12, color: txtColor, fontWeight: FontWeight.w700),
                                                decoration: InputDecoration(
                                                  hintText: '••••••••',
                                                  hintStyle: GoogleFonts.outfit(fontSize: 11, color: subColor.withAlpha(130)),
                                                  border: InputBorder.none,
                                                  isDense: true,
                                                ),
                                              ),
                                            ),
                                            IconButton(
                                              icon: Icon(obscurePass ? Icons.visibility_off : Icons.visibility, size: 16, color: subColor),
                                              onPressed: () => setS(() => obscurePass = !obscurePass),
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ]),
                                  )
                                else
                                  const Expanded(child: SizedBox()),
                              ]),
                            ]),

                            const SizedBox(height: 16),

                            // ── SECTION 2: DATA PRIBADI ───────────────────
                            section('DATA PRIBADI', [
                              inputLabel('Nama Lengkap'),
                              inputField(nameCtrl, 'Masukkan nama lengkap pekerja'),
                              const SizedBox(height: 12),
                              Row(children: [
                                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  inputLabel('NIK (16 Digit)'),
                                  inputField(nikCtrl, 'e.g. 3515081504900001', type: TextInputType.number),
                                ])),
                                const SizedBox(width: 14),
                                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  inputLabel('No. Telepon / WhatsApp'),
                                  inputField(phoneCtrl, '+62 8...', type: TextInputType.phone),
                                ])),
                              ]),
                              const SizedBox(height: 12),
                              Row(children: [
                                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  inputLabel('Jenis Kelamin'),
                                  Container(
                                    height: 44,
                                    decoration: BoxDecoration(color: inputBg, borderRadius: BorderRadius.circular(10)),
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: selectedGender,
                                        isExpanded: true,
                                        dropdownColor: dialogBg,
                                        style: GoogleFonts.outfit(fontSize: 12, color: txtColor, fontWeight: FontWeight.bold),
                                        items: ['Laki-laki', 'Perempuan'].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                                        onChanged: (val) { if (val != null) setS(() => selectedGender = val); },
                                      ),
                                    ),
                                  ),
                                ])),
                                const SizedBox(width: 14),
                                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  inputLabel('Tempat Lahir'),
                                  inputField(birthPlaceCtrl, 'Contoh: Surabaya'),
                                ])),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    inputLabel('Tanggal Lahir'),
                                    GestureDetector(
                                      onTap: () async {
                                        final picked = await showDatePicker(
                                          context: context,
                                          initialDate: selectedBirthDate ?? DateTime(1995),
                                          firstDate: DateTime(1950),
                                          lastDate: DateTime.now(),
                                        );
                                        if (picked != null) setS(() => selectedBirthDate = picked);
                                      },
                                      child: Container(
                                        height: 44,
                                        decoration: BoxDecoration(color: inputBg, borderRadius: BorderRadius.circular(10)),
                                        padding: const EdgeInsets.symmetric(horizontal: 12),
                                        alignment: Alignment.centerLeft,
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              selectedBirthDate == null
                                                ? 'dd/mm/yyyy'
                                                : '${selectedBirthDate!.year}-${selectedBirthDate!.month.toString().padLeft(2, '0')}-${selectedBirthDate!.day.toString().padLeft(2, '0')}',
                                              style: GoogleFonts.outfit(fontSize: 12, color: selectedBirthDate == null ? subColor.withAlpha(130) : txtColor, fontWeight: FontWeight.bold),
                                            ),
                                            Icon(Icons.calendar_month, size: 16, color: subColor),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ]),
                                ),
                              ]),
                              const SizedBox(height: 12),
                              inputLabel('ID Pekerja / SIP (Opsional)'),
                              inputField(idCtrl, 'PKJ/503/XXXX/2026'),
                            ]),

                            const SizedBox(height: 16),

                            // ── SECTION 3: FULL ADDRESS ───────────────────
                            section('Alamat Lengkap', [
                              LocationSelectorWidget(
                                initialProvince: prov,
                                initialDistrict: kota,
                                initialSubDistrict: kec,
                                initialVillage: kel,
                                fieldBg: inputBg,
                                textColor: txtColor,
                                subtitleColor: subColor,
                                borderColor: borderColor,
                                dropdownColor: dialogBg,
                                fontSize: 12,
                                onChanged: (p, d, sd, v) {
                                  setS(() { prov = p; kota = d; kec = sd; kel = v; });
                                },
                              ),
                              const SizedBox(height: 12),
                              inputLabel('Detail Jalan (Opsional)'),
                              Container(
                                decoration: BoxDecoration(color: inputBg, borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                child: TextField(
                                  controller: addressCtrl,
                                  maxLines: 3,
                                  style: GoogleFonts.outfit(fontSize: 12, color: txtColor, fontWeight: FontWeight.w700),
                                  decoration: InputDecoration(
                                    hintText: 'Masukkan alamat detail pekerja...',
                                    hintStyle: GoogleFonts.outfit(fontSize: 11, color: subColor.withAlpha(130)),
                                    border: InputBorder.none,
                                  ),
                                ),
                              ),
                            ]),

                            const SizedBox(height: 16),

                            // ── SECTION 4: AKSES & MEDIA ──────────────────
                            section('AKSES & MEDIA', [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Menu Access column
                                  Expanded(
                                    flex: 3,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(children: [
                                          const Icon(Icons.verified_user_outlined, size: 14, color: teal),
                                          const SizedBox(width: 6),
                                          Text('Menu Access', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: txtColor)),
                                        ]),
                                        const SizedBox(height: 12),
                                        _buildPermissionSearchAndFilterSection(
                                          context: context,
                                          searchQuery: formPermSearchQuery,
                                          selectedCluster: formClusterFilter,
                                          selectedDlcSub: formDlcSubFilter,
                                          availablePerms: availableMenus,
                                          currentSelectedPerms: selectedPerms,
                                          txtColor: txtColor,
                                          subColor: subColor,
                                          borderColor: borderColor,
                                          accentColor: teal,
                                          isDark: isDark,
                                          onSearchChanged: (q) => setS(() => formPermSearchQuery = q),
                                          onClusterChanged: (c) => setS(() => formClusterFilter = c),
                                          onDlcSubChanged: (sc) => setS(() => formDlcSubFilter = sc),
                                          onPermissionsUpdated: (updatedPerms) {
                                            setS(() {
                                              selectedPerms.clear();
                                              selectedPerms.addAll(updatedPerms);
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(width: 16),

                                  // Photo Profil placeholder
                                  Expanded(
                                    flex: 2,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Text('Photo Profil', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: txtColor)),
                                        const SizedBox(height: 12),
                                        CustomPaint(
                                          painter: DashedBorderPainter(color: borderColor),
                                          child: Container(
                                            height: 120,
                                            width: double.infinity,
                                            alignment: Alignment.center,
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(Icons.photo_camera_outlined, size: 24, color: subColor),
                                                const SizedBox(height: 6),
                                                Text('UPLOAD PHOTO', style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.bold, color: subColor)),
                                                Text('PNG or JPG up to 5MB', style: GoogleFonts.outfit(fontSize: 8, color: subColor)),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ]),

                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),

                    // ── Footer Actions ─────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                      decoration: BoxDecoration(border: Border(top: BorderSide(color: borderColor))),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: Text('Batal', style: GoogleFonts.outfit(color: subColor, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: () async {
                              final nama = nameCtrl.text.trim();
                              if (nama.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Nama wajib diisi!')),
                                );
                                return;
                              }

                              // Resolve actual role: template label or custom text
                              final resolvedRole = selectedTemplate == 'Lain-lain (Isi Sendiri)'
                                  ? (customRoleCtrl.text.trim().isEmpty ? 'Staf Umum' : customRoleCtrl.text.trim())
                                  : selectedTemplate;

                              final birthDateStr = selectedBirthDate == null
                                  ? ''
                                  : '${selectedBirthDate!.year}-${selectedBirthDate!.month.toString().padLeft(2, '0')}-${selectedBirthDate!.day.toString().padLeft(2, '0')}';

                              final fullAddress = [
                                kel, kec, kota, prov,
                              ].where((s) => s.isNotEmpty).join(', ');
                              final detailAddress = addressCtrl.text.trim();
                              final combinedAddress = [detailAddress, fullAddress].where((s) => s.isNotEmpty).join(', ');

                              Navigator.pop(ctx);

                              if (isEdit) {
                                final err = await ref.read(pekerjaListProvider.notifier).editPekerja(
                                  workerId: worker.id,
                                  nama: nama,
                                  email: emailCtrl.text.trim(),
                                  nik: nikCtrl.text.trim(),
                                  idPekerja: idCtrl.text.trim(),
                                  peran: resolvedRole,
                                  telepon: phoneCtrl.text.trim(),
                                  username: usernameCtrl.text.trim(),
                                  gender: selectedGender,
                                  birthPlace: birthPlaceCtrl.text.trim(),
                                  birthDate: birthDateStr,
                                  address: combinedAddress,
                                  province: prov,
                                  district: kota,
                                  subDistrict: kec,
                                  village: kel,
                                );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                    backgroundColor: err == null ? teal : Colors.redAccent,
                                    content: Text(err ?? 'Data pekerja berhasil diperbarui!'),
                                  ));
                                }
                              } else {
                                final err = await ref.read(pekerjaListProvider.notifier).addPekerja(
                                  nama: nama,
                                  email: emailCtrl.text.trim(),
                                  nik: nikCtrl.text.trim(),
                                  idPekerja: idCtrl.text.trim().isEmpty
                                      ? 'PKJ/503/${Random().nextInt(8999) + 1000}/2026'
                                      : idCtrl.text.trim(),
                                  peran: resolvedRole,
                                  telepon: phoneCtrl.text.trim(),
                                  username: usernameCtrl.text.trim().isEmpty
                                      ? nama.toLowerCase().replaceAll(' ', '_')
                                      : usernameCtrl.text.trim(),
                                  gender: selectedGender,
                                  birthPlace: birthPlaceCtrl.text.trim(),
                                  birthDate: birthDateStr,
                                  address: combinedAddress,
                                  province: prov,
                                  district: kota,
                                  subDistrict: kec,
                                  village: kel,
                                  permissions: List<String>.from(selectedPerms),
                                  avatarColor: '#48C9B0',
                                );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                    backgroundColor: err == null ? teal : Colors.redAccent,
                                    content: Text(err ?? 'Pekerja baru berhasil didaftarkan ke sistem Puskesmas!'),
                                  ));
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: teal,
                              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                              elevation: 0,
                            ),
                            child: Text(
                              isEdit ? 'Simpan Pekerja' : 'Tambah Pekerja',
                              style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
                            ),
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


  // ── Delete Confirm ─────────────────────────────────────────────────────────

  void _showDeleteConfirmDialog(
    BuildContext context,
    WidgetRef ref, {
    required PekerjaModel worker,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Data Pekerja?'),
        content: Text('Apakah Anda yakin ingin menghapus data "${worker.nama}"? Tindakan ini tidak dapat dibatalkan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final err = await ref.read(pekerjaListProvider.notifier).removePekerja(worker.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  backgroundColor: err == null ? Colors.green : Colors.redAccent,
                  content: Text(err ?? 'Data pekerja telah dihapus.'),
                ));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ─── Dashed Border Painter ──────────────────────────────────────────────────

class DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double gap;

  DashedBorderPainter({required this.color, this.strokeWidth = 1.5, this.gap = 5.0});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final Path path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        const Radius.circular(20),
      ));

    final Path dashPath = Path();
    double distance = 0.0;
    for (final PathMetric pathMetric in path.computeMetrics()) {
      while (distance < pathMetric.length) {
        dashPath.addPath(pathMetric.extractPath(distance, distance + gap), Offset.zero);
        distance += gap * 2;
      }
    }
    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(covariant DashedBorderPainter oldDelegate) => oldDelegate.color != color;
}

// ─── Puskesmas Permission Model & Dictionary ────────────────────────────────

class PuskesmasPermissionModel {
  final String id;
  final String name;
  final String badge;
  final IconData icon;
  final String mainCluster;
  final String dlcSubCat;
  final String categoryLabel;

  const PuskesmasPermissionModel({
    required this.id,
    required this.name,
    required this.badge,
    required this.icon,
    required this.mainCluster,
    this.dlcSubCat = '',
    required this.categoryLabel,
  });
}

final Map<String, PuskesmasPermissionModel> kPuskesmasPermissionDict = {
  'DASHBOARD': const PuskesmasPermissionModel(id: 'DASHBOARD', name: 'DASHBOARD', badge: 'CL-1', icon: Icons.dashboard_rounded, mainCluster: 'cluster_1', categoryLabel: 'Cluster 1 (Management)'),
  'PEMBUKUAN': const PuskesmasPermissionModel(id: 'PEMBUKUAN', name: 'PEMBUKUAN', badge: 'CL-1', icon: Icons.account_balance_wallet_rounded, mainCluster: 'cluster_1', categoryLabel: 'Cluster 1 (Management)'),
  'MANAGEMENT PEKERJA': const PuskesmasPermissionModel(id: 'MANAGEMENT PEKERJA', name: 'MANAGEMENT PEKERJA', badge: 'CL-1', icon: Icons.engineering_rounded, mainCluster: 'cluster_1', categoryLabel: 'Cluster 1 (Management)'),
  'PROFIL': const PuskesmasPermissionModel(id: 'PROFIL', name: 'PROFIL', badge: 'CL-1', icon: Icons.domain_rounded, mainCluster: 'cluster_1', categoryLabel: 'Cluster 1 (Management)'),
  'PROFILE': const PuskesmasPermissionModel(id: 'PROFILE', name: 'PROFIL', badge: 'CL-1', icon: Icons.domain_rounded, mainCluster: 'cluster_1', categoryLabel: 'Cluster 1 (Management)'),

  'PASIEN': const PuskesmasPermissionModel(id: 'PASIEN', name: 'PASIEN', badge: 'CL-2 & 3', icon: Icons.people_rounded, mainCluster: 'cluster_2', categoryLabel: 'Cluster 2 & 3 (Pelayanan Klinis)'),
  'PEMERIKSAAN': const PuskesmasPermissionModel(id: 'PEMERIKSAAN', name: 'PEMERIKSAAN', badge: 'CL-2 & 3', icon: Icons.assignment_rounded, mainCluster: 'cluster_2', categoryLabel: 'Cluster 2 & 3 (Pelayanan Klinis)'),

  'OBAT': const PuskesmasPermissionModel(id: 'OBAT', name: 'OBAT', badge: 'LINTAS', icon: Icons.medication_rounded, mainCluster: 'lintas_cluster', categoryLabel: 'Cross Cluster (Farmasi)'),
  'ANTRIAN': const PuskesmasPermissionModel(id: 'ANTRIAN', name: 'ANTRIAN', badge: 'LINTAS', icon: Icons.hourglass_empty_rounded, mainCluster: 'lintas_cluster', categoryLabel: 'Cross Cluster (Antrian)'),

  'PANTAUAN IBU HAMIL': const PuskesmasPermissionModel(id: 'PANTAUAN IBU HAMIL', name: 'PANTAUAN IBU HAMIL', badge: 'DLC KIA 1', icon: Icons.pregnant_woman_rounded, mainCluster: 'custom_menu', dlcSubCat: 'kia_dlc', categoryLabel: 'DLC Kesehatan Ibu & Anak'),
  'FORM IBU HAMIL': const PuskesmasPermissionModel(id: 'FORM IBU HAMIL', name: 'FORM PEMERIKSAAN IBU HAMIL', badge: 'DLC KIA 2', icon: Icons.assignment_rounded, mainCluster: 'custom_menu', dlcSubCat: 'kia_dlc', categoryLabel: 'DLC Kesehatan Ibu & Anak'),
  'SKRINING STUNTING': const PuskesmasPermissionModel(id: 'SKRINING STUNTING', name: 'SKRINING STUNTING & BALITA', badge: 'DLC KIA 3', icon: Icons.child_friendly_rounded, mainCluster: 'custom_menu', dlcSubCat: 'kia_dlc', categoryLabel: 'DLC Kesehatan Ibu & Anak'),
  'RUJUKAN INTERNAL': const PuskesmasPermissionModel(id: 'RUJUKAN INTERNAL', name: 'RUJUKAN INTERNAL & POLI', badge: 'DLC MED 1', icon: Icons.alt_route_rounded, mainCluster: 'custom_menu', dlcSubCat: 'pelayanan_dlc', categoryLabel: 'DLC Pelayanan Medis'),
  'HOME CARE POSYANDU': const PuskesmasPermissionModel(id: 'HOME CARE POSYANDU', name: 'HOME CARE & POSYANDU', badge: 'DLC MED 2', icon: Icons.home_work_rounded, mainCluster: 'custom_menu', dlcSubCat: 'pelayanan_dlc', categoryLabel: 'DLC Pelayanan Medis'),
  'EPOSYANDU EWRS': const PuskesmasPermissionModel(id: 'EPOSYANDU EWRS', name: 'E-POSYANDU & EWRS RISK', badge: 'DLC MED 3', icon: Icons.warning_amber_rounded, mainCluster: 'custom_menu', dlcSubCat: 'pelayanan_dlc', categoryLabel: 'DLC Pelayanan Medis'),
  'SATUSEHAT PRO': const PuskesmasPermissionModel(id: 'SATUSEHAT PRO', name: 'MODUL DLC SATUSEHAT PRO', badge: 'DLC SYS 1', icon: Icons.health_and_safety_rounded, mainCluster: 'custom_menu', dlcSubCat: 'sistem_dlc', categoryLabel: 'DLC Integrasi Sistem'),
  'BPJS PCARE BRIDGING': const PuskesmasPermissionModel(id: 'BPJS PCARE BRIDGING', name: 'BPJS P-CARE BRIDGING', badge: 'DLC SYS 2', icon: Icons.cloud_sync_rounded, mainCluster: 'custom_menu', dlcSubCat: 'sistem_dlc', categoryLabel: 'DLC Integrasi Sistem'),
};

PuskesmasPermissionModel getPermissionModel(String permId) {
  final upper = permId.toUpperCase();
  final exact = kPuskesmasPermissionDict[upper];
  if (exact != null) return exact;

  if (upper.contains('PANTAUAN') || upper.contains('FORM IBU') || upper.contains('KIA')) {
    return PuskesmasPermissionModel(id: permId, name: permId, badge: 'DLC KIA', icon: Icons.pregnant_woman_rounded, mainCluster: 'custom_menu', dlcSubCat: 'kia_dlc', categoryLabel: 'DLC Kesehatan Ibu & Anak');
  } else if (upper.contains('PASIEN') || upper.contains('PEMERIKSAAN') || upper.contains('ANTRIAN')) {
    return PuskesmasPermissionModel(id: permId, name: permId, badge: 'CL-2 & 3', icon: Icons.personal_injury_rounded, mainCluster: 'cluster_2', categoryLabel: 'Cluster 2 & 3 (Pelayanan Klinis)');
  } else if (upper.contains('OBAT') || upper.contains('INVENTORI') || upper.contains('POS') || upper.contains('PESANAN')) {
    return PuskesmasPermissionModel(id: permId, name: permId, badge: 'LINTAS', icon: Icons.medication_rounded, mainCluster: 'lintas_cluster', categoryLabel: 'Cross Cluster (Farmasi)');
  } else if (upper.contains('SATUSEHAT') || upper.contains('PCARE') || upper.contains('BRIDGING')) {
    return PuskesmasPermissionModel(id: permId, name: permId, badge: 'DLC SYS', icon: Icons.cloud_sync_rounded, mainCluster: 'custom_menu', dlcSubCat: 'sistem_dlc', categoryLabel: 'DLC Integrasi Sistem');
  } else if (upper.contains('HOME') || upper.contains('POSYANDU') || upper.contains('RUJUKAN') || upper.contains('EWRS')) {
    return PuskesmasPermissionModel(id: permId, name: permId, badge: 'DLC MED', icon: Icons.medical_services_rounded, mainCluster: 'custom_menu', dlcSubCat: 'pelayanan_dlc', categoryLabel: 'DLC Pelayanan Medis');
  } else {
    return PuskesmasPermissionModel(id: permId, name: permId, badge: 'CL-1', icon: Icons.admin_panel_settings_rounded, mainCluster: 'cluster_1', categoryLabel: 'Cluster 1 (Management)');
  }
}
