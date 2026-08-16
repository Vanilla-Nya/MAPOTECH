import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:mapotech/features/landing/landing_page_data.dart';
import 'package:mapotech/shared/supabase_service.dart';
import 'package:mapotech/shared/widgets/ui.dart';
import 'package:mapotech/shared/widgets/revgeo_wilayah_map_widget.dart';

// ─── Pustu / Ponkesdes Data Model ─────────────────────────────────────────────

class PustuPonkesdesModel {
  final String id;
  final String nama;
  final String tipe; // 'PUSTU' or 'PONKESDES'
  final String kodeUnit;
  final String penanggungJawab;
  final String nikPenanggungJawab;
  final String telepon;
  final String alamat;
  final String village; // Desa / Kelurahan
  final String kecamatan;
  final double latitude;
  final double longitude;
  final String statusOperasional; // 'Aktif / Buka', 'Tutup', 'Dalam Perbaikan'
  final String jamLayanan;
  final List<String> permissions;
  final Color avatarBg;
  final String createdAt;

  const PustuPonkesdesModel({
    required this.id,
    required this.nama,
    required this.tipe,
    required this.kodeUnit,
    required this.penanggungJawab,
    required this.nikPenanggungJawab,
    required this.telepon,
    required this.alamat,
    required this.village,
    required this.kecamatan,
    required this.latitude,
    required this.longitude,
    required this.statusOperasional,
    required this.jamLayanan,
    required this.permissions,
    required this.avatarBg,
    required this.createdAt,
  });

  PustuPonkesdesModel copyWith({
    String? id,
    String? nama,
    String? tipe,
    String? kodeUnit,
    String? penanggungJawab,
    String? nikPenanggungJawab,
    String? telepon,
    String? alamat,
    String? village,
    String? kecamatan,
    double? latitude,
    double? longitude,
    String? statusOperasional,
    String? jamLayanan,
    List<String>? permissions,
    Color? avatarBg,
    String? createdAt,
  }) {
    return PustuPonkesdesModel(
      id: id ?? this.id,
      nama: nama ?? this.nama,
      tipe: tipe ?? this.tipe,
      kodeUnit: kodeUnit ?? this.kodeUnit,
      penanggungJawab: penanggungJawab ?? this.penanggungJawab,
      nikPenanggungJawab: nikPenanggungJawab ?? this.nikPenanggungJawab,
      telepon: telepon ?? this.telepon,
      alamat: alamat ?? this.alamat,
      village: village ?? this.village,
      kecamatan: kecamatan ?? this.kecamatan,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      statusOperasional: statusOperasional ?? this.statusOperasional,
      jamLayanan: jamLayanan ?? this.jamLayanan,
      permissions: permissions ?? this.permissions,
      avatarBg: avatarBg ?? this.avatarBg,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory PustuPonkesdesModel.fromMap(Map<String, dynamic> map) {
    final permsRaw = map['permissions'];
    final List<String> perms = permsRaw is List
        ? List<String>.from(permsRaw.map((e) => e.toString()))
        : <String>['DASHBOARD', 'FORM_IBU_HAMIL', 'ANTRIAN'];

    Color avatarColor = const Color(0xFF48C9B0);
    final colorStr = map['avatar_color'] as String?;
    if (colorStr != null && colorStr.startsWith('#')) {
      try {
        avatarColor = Color(
          int.parse(colorStr.replaceFirst('#', 'FF'), radix: 16),
        );
      } catch (_) {}
    }

    return PustuPonkesdesModel(
      id: map['id'] as String? ?? UniqueKey().toString(),
      nama: map['nama'] as String? ?? 'Pustu Desa',
      tipe: (map['tipe'] as String? ?? 'PUSTU').toUpperCase(),
      kodeUnit: map['kode_unit'] as String? ?? 'PST-001',
      penanggungJawab: map['penanggung_jawab'] as String? ?? 'Bidan Desa',
      nikPenanggungJawab: map['nik_penanggung_jawab'] as String? ?? '3511010101900001',
      telepon: map['telepon'] as String? ?? '081234567890',
      alamat: map['alamat'] as String? ?? 'Jl. Raya Desa No. 12',
      village: map['village'] as String? ?? 'Sukorejo',
      kecamatan: map['kecamatan'] as String? ?? 'Sumber Wringin',
      latitude: (map['latitude'] as num?)?.toDouble() ?? -7.9797,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 113.8228,
      statusOperasional: map['status_operasional'] as String? ?? 'Aktif / Buka',
      jamLayanan: map['jam_layanan'] as String? ?? '08:00 - 14:00 WIB',
      permissions: perms,
      avatarBg: avatarColor,
      createdAt: map['created_at'] as String? ?? 'Jan 2026',
    );
  }
}

// ─── Initial Mock Dataset for Pustu & Ponkesdes ───────────────────────────────

final List<PustuPonkesdesModel> _initialSampleUnits = [
  const PustuPonkesdesModel(
    id: 'pustu_1',
    nama: 'Pustu Sukorejo',
    tipe: 'PUSTU',
    kodeUnit: 'PST-001',
    penanggungJawab: 'Bidan Sapti Wijaya, A.Md.Keb',
    nikPenanggungJawab: '3511014503920001',
    telepon: '081234567891',
    alamat: 'Jl. Raya Sukorejo No. 45',
    village: 'Sukorejo',
    kecamatan: 'Sumber Wringin',
    latitude: -7.9750,
    longitude: 113.8290,
    statusOperasional: 'Aktif / Buka',
    jamLayanan: '08:00 - 14:00 WIB',
    permissions: ['DASHBOARD', 'MANAGEMENT_PEKERJA', 'ANTRIAN', 'FORM_IBU_HAMIL', 'PANTAUAN_IBU_HAMIL'],
    avatarBg: Color(0xFF48C9B0),
    createdAt: 'Jan 2026',
  ),
  const PustuPonkesdesModel(
    id: 'ponkesdes_1',
    nama: 'Ponkesdes Rejoagung',
    tipe: 'PONKESDES',
    kodeUnit: 'PNK-001',
    penanggungJawab: 'Perawat Ahmad Fauzi, S.Kep',
    nikPenanggungJawab: '3511011807890003',
    telepon: '082198765432',
    alamat: 'Dusun Krajan RT 02/01',
    village: 'Rejoagung',
    kecamatan: 'Sumber Wringin',
    latitude: -7.9850,
    longitude: 113.8150,
    statusOperasional: 'Aktif / Buka',
    jamLayanan: '07:30 - 15:00 WIB',
    permissions: ['DASHBOARD', 'ANTRIAN', 'FORM_IBU_HAMIL', 'PANTAUAN_IBU_HAMIL'],
    avatarBg: Color(0xFF3498DB),
    createdAt: 'Jan 2026',
  ),
  const PustuPonkesdesModel(
    id: 'pustu_2',
    nama: 'Pustu Tlogosari',
    tipe: 'PUSTU',
    kodeUnit: 'PST-002',
    penanggungJawab: 'Bidan Ratna Sari, S.Tr.Keb',
    nikPenanggungJawab: '3511016208940002',
    telepon: '081333444555',
    alamat: 'Jl. Pemuda No. 08, Tlogosari',
    village: 'Tlogosari',
    kecamatan: 'Sumber Wringin',
    latitude: -7.9680,
    longitude: 113.8350,
    statusOperasional: 'Aktif / Buka',
    jamLayanan: '08:00 - 13:30 WIB',
    permissions: ['DASHBOARD', 'MANAGEMENT_PEKERJA', 'ANTRIAN', 'FORM_IBU_HAMIL'],
    avatarBg: Color(0xFF9B59B6),
    createdAt: 'Feb 2026',
  ),
];

// ─── Async State & Notifier ───────────────────────────────────────────────────

class PustuPonkesdesListState {
  final List<PustuPonkesdesModel> units;
  final bool isLoading;
  final String? error;

  const PustuPonkesdesListState({
    this.units = const [],
    this.isLoading = false,
    this.error,
  });

  PustuPonkesdesListState copyWith({
    List<PustuPonkesdesModel>? units,
    bool? isLoading,
    String? error,
  }) {
    return PustuPonkesdesListState(
      units: units ?? this.units,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class PustuPonkesdesListNotifier extends StateNotifier<PustuPonkesdesListState> {
  final SupabaseService _service = SupabaseService();
  String? _ownerId;

  PustuPonkesdesListNotifier()
      : super(PustuPonkesdesListState(units: List.from(_initialSampleUnits)));

  Future<void> loadUnits(String ownerId) async {
    _ownerId = ownerId;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final rows = await _service.fetchPustuPonkesdesList(ownerId);
      if (rows.isNotEmpty) {
        final fetched = rows.map(PustuPonkesdesModel.fromMap).toList();
        state = state.copyWith(units: fetched, isLoading: false);
      } else {
        // Keep initial rich sample dataset if DB table is empty/not configured
        state = state.copyWith(units: List.from(_initialSampleUnits), isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: null);
    }
  }

  Future<String?> addUnit({
    required String nama,
    required String tipe,
    required String kodeUnit,
    required String penanggungJawab,
    required String nikPenanggungJawab,
    required String telepon,
    required String alamat,
    required String village,
    required String kecamatan,
    required double latitude,
    required double longitude,
    required String statusOperasional,
    required String jamLayanan,
    required List<String> permissions,
    required Color avatarBg,
  }) async {
    final colorHex = '#${avatarBg.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
    
    // Try Supabase insert
    if (_ownerId != null) {
      final row = await _service.insertPustuPonkesdes(
        ownerId: _ownerId!,
        nama: nama,
        tipe: tipe,
        kodeUnit: kodeUnit,
        penanggungJawab: penanggungJawab,
        nikPenanggungJawab: nikPenanggungJawab,
        telepon: telepon,
        alamat: alamat,
        village: village,
        kecamatan: kecamatan,
        latitude: latitude,
        longitude: longitude,
        statusOperasional: statusOperasional,
        jamLayanan: jamLayanan,
        permissions: permissions,
        avatarColor: colorHex,
      );
      if (row != null) {
        final newUnit = PustuPonkesdesModel.fromMap(row);
        state = state.copyWith(units: [...state.units, newUnit]);
        return null;
      }
    }

    // Local fallback
    final newUnit = PustuPonkesdesModel(
      id: UniqueKey().toString(),
      nama: nama,
      tipe: tipe,
      kodeUnit: kodeUnit,
      penanggungJawab: penanggungJawab,
      nikPenanggungJawab: nikPenanggungJawab,
      telepon: telepon,
      alamat: alamat,
      village: village,
      kecamatan: kecamatan,
      latitude: latitude,
      longitude: longitude,
      statusOperasional: statusOperasional,
      jamLayanan: jamLayanan,
      permissions: permissions,
      avatarBg: avatarBg,
      createdAt: 'Now',
    );

    state = state.copyWith(units: [...state.units, newUnit]);
    return null;
  }

  Future<String?> editUnit({
    required String unitId,
    required String nama,
    required String tipe,
    required String kodeUnit,
    required String penanggungJawab,
    required String nikPenanggungJawab,
    required String telepon,
    required String alamat,
    required String village,
    required String kecamatan,
    required double latitude,
    required double longitude,
    required String statusOperasional,
    required String jamLayanan,
  }) async {
    await _service.updatePustuPonkesdes(
      unitId: unitId,
      nama: nama,
      tipe: tipe,
      kodeUnit: kodeUnit,
      penanggungJawab: penanggungJawab,
      nikPenanggungJawab: nikPenanggungJawab,
      telepon: telepon,
      alamat: alamat,
      village: village,
      kecamatan: kecamatan,
      latitude: latitude,
      longitude: longitude,
      statusOperasional: statusOperasional,
      jamLayanan: jamLayanan,
    );

    state = state.copyWith(
      units: state.units.map((u) {
        if (u.id != unitId) return u;
        return u.copyWith(
          nama: nama,
          tipe: tipe,
          kodeUnit: kodeUnit,
          penanggungJawab: penanggungJawab,
          nikPenanggungJawab: nikPenanggungJawab,
          telepon: telepon,
          alamat: alamat,
          village: village,
          kecamatan: kecamatan,
          latitude: latitude,
          longitude: longitude,
          statusOperasional: statusOperasional,
          jamLayanan: jamLayanan,
        );
      }).toList(),
    );
    return null;
  }

  Future<void> toggleStatus(String unitId, String currentStatus) async {
    final nextStatus = currentStatus.startsWith('Aktif') ? 'Tutup' : 'Aktif / Buka';
    state = state.copyWith(
      units: state.units.map((u) {
        return u.id == unitId ? u.copyWith(statusOperasional: nextStatus) : u;
      }).toList(),
    );
    await _service.togglePustuPonkesdesStatus(unitId, nextStatus);
  }

  Future<String?> removeUnit(String unitId) async {
    await _service.deletePustuPonkesdes(unitId);
    state = state.copyWith(
      units: state.units.where((u) => u.id != unitId).toList(),
    );
    return null;
  }
}

final pustuPonkesdesListProvider =
    StateNotifierProvider<PustuPonkesdesListNotifier, PustuPonkesdesListState>((ref) {
  return PustuPonkesdesListNotifier();
});

// ─── Main Management Pustu / Ponkesdes Widget ────────────────────────────────

class ManagementPustuPonkesdesWidget extends ConsumerStatefulWidget {
  const ManagementPustuPonkesdesWidget({super.key});

  @override
  ConsumerState<ManagementPustuPonkesdesWidget> createState() =>
      _ManagementPustuPonkesdesWidgetState();
}

class _ManagementPustuPonkesdesWidgetState
    extends ConsumerState<ManagementPustuPonkesdesWidget> {
  String _searchQuery = '';
  String _tipeFilter = 'SEMUA';
  
  // Selected map focus unit
  PustuPonkesdesModel? _selectedMapFocusUnit;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final landingState = ref.read(landingPageProvider);
      final ownerId = landingState.loggedInUser?['id'] as String?;
      if (ownerId != null && ownerId.isNotEmpty) {
        ref.read(pustuPonkesdesListProvider.notifier).loadUnits(ownerId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(landingPageProvider);
    final pustuState = ref.watch(pustuPonkesdesListProvider);
    final allUnits = pustuState.units;

    final isDark = state.appearance == 'dark';
    final cardBgColor = isDark ? const Color(0xFF161619) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1B0C3C);
    final subtitleColor = isDark ? Colors.grey[400]! : const Color(0xFF6F6A8A);
    final borderColor = isDark ? const Color(0xFF252528) : const Color(0xFFECEEF2);
    final isRev = state.appearance == 'rev';
    final themeAccent = isRev ? const Color(0xFFB577F2) : const Color(0xFF48C9B0);
    final isMobile = MediaQuery.of(context).size.width < 768;

    final filteredUnits = allUnits.where((u) {
      final q = _searchQuery.toLowerCase();
      final matchesQuery = u.nama.toLowerCase().contains(q) ||
          u.kodeUnit.toLowerCase().contains(q) ||
          u.penanggungJawab.toLowerCase().contains(q) ||
          u.village.toLowerCase().contains(q) ||
          u.telepon.contains(q);
      final matchesTipe = _tipeFilter == 'SEMUA' || u.tipe == _tipeFilter;
      return matchesQuery && matchesTipe;
    }).toList();

    final totalUnits = allUnits.length;
    final activeUnits = allUnits.where((u) => u.statusOperasional.startsWith('Aktif')).length;
    final pustuCount = allUnits.where((u) => u.tipe == 'PUSTU').length;
    final ponkesdesCount = allUnits.where((u) => u.tipe == 'PONKESDES').length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Map Header Top Section (Replaces 4 Metric Cards as Requested) ─────
        AnimatedEntrance(
          delay: const Duration(milliseconds: 50),
          type: EntranceAnimationType.slideUp,
          child: Container(
            decoration: BoxDecoration(
              color: cardBgColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: borderColor),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: themeAccent.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.map_rounded, color: themeAccent, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'PETA CAKUPAN PUSTU & PONKESDES',
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: textColor,
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              'Sebaran Lokasi Faskes Penunjang Pembantu & Pondok Kesehatan Desa',
                              style: GoogleFonts.outfit(fontSize: 10, color: subtitleColor),
                            ),
                          ],
                        ),
                      ],
                    ),
                    // Summary chips over the map
                    if (!isMobile)
                      Wrap(
                        spacing: 8,
                        children: [
                          StatusBadge(label: 'Total: $totalUnits Unit', color: themeAccent, showDot: false),
                          StatusBadge(label: 'Aktif: $activeUnits Unit', color: const Color(0xFF2ECC71), showDot: false),
                          StatusBadge(label: 'Pustu: $pustuCount', color: const Color(0xFF3498DB), showDot: false),
                          StatusBadge(label: 'Ponkesdes: $ponkesdesCount', color: const Color(0xFF9B59B6), showDot: false),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: RevGeoWilayahMapWidget(
                    initialProvince: 'JAWA TIMUR',
                    initialDistrict: 'KABUPATEN BONDOWOSO',
                    initialSubDistrict: 'SUMBER WRINGIN',
                    fieldBg: cardBgColor,
                    textColor: textColor,
                    subtitleColor: subtitleColor,
                    borderColor: borderColor,
                    dropdownColor: isDark ? const Color(0xFF1B1B1E) : Colors.white,
                    themeAccent: themeAccent,
                    isDark: isDark,
                    isEn: state.language == 'en',
                    height: isMobile ? 220 : 280,
                    showOnlyMap: true,
                    onChanged: (prov, reg, dist, vill) {},
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        // ── Controls Panel (Search, Filter, Add Action) ───────────────────────
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
                SizedBox(
                  width: isMobile ? 200 : 320,
                  child: CustomSearchBar(
                    hintText: 'Cari Pustu, Ponkesdes, kode, atau PJ...',
                    height: 46,
                    backgroundColor: cardBgColor,
                    borderColor: borderColor,
                    textColor: textColor,
                    hintColor: subtitleColor,
                    iconColor: subtitleColor,
                    onChanged: (val) => setState(() => _searchQuery = val),
                    onClear: () => setState(() => _searchQuery = ''),
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
                      value: _tipeFilter,
                      icon: Icon(Icons.keyboard_arrow_down_rounded, color: subtitleColor, size: 20),
                      style: GoogleFonts.outfit(fontSize: 12, color: textColor, fontWeight: FontWeight.w600),
                      dropdownColor: cardBgColor,
                      items: const [
                        DropdownMenuItem(value: 'SEMUA', child: Text('Semua Tipe Unit')),
                        DropdownMenuItem(value: 'PUSTU', child: Text('Pustu (Puskesmas Pembantu)')),
                        DropdownMenuItem(value: 'PONKESDES', child: Text('Ponkesdes (Pondok Kesehatan)')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _tipeFilter = val);
                      },
                    ),
                  ),
                ),
              ],
            ),
            ElevatedButton.icon(
              onPressed: () => _showPustuFormDialog(context, ref),
              icon: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
              label: Text(
                '+ Tambah Pustu / Ponkesdes',
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

        const SizedBox(height: 20),

        // ── Pustu & Ponkesdes Cards Grid ─────────────────────────────────────
        LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = isMobile
                ? constraints.maxWidth
                : (constraints.maxWidth - 20) / 2;

            return Wrap(
              spacing: 20,
              runSpacing: 20,
              children: [
                ...filteredUnits.map(
                  (unit) => SizedBox(
                    width: cardWidth,
                    child: _buildUnitCard(
                      unit,
                      context,
                      ref,
                      cardBgColor,
                      textColor,
                      subtitleColor,
                      borderColor,
                      themeAccent,
                    ),
                  ),
                ),
                // Dashed "Register New Pustu/Ponkesdes" Placeholder Card
                SizedBox(
                  width: cardWidth,
                  child: _buildDashedRegisterCard(
                    context,
                    ref,
                    cardBgColor,
                    textColor,
                    subtitleColor,
                    borderColor,
                    themeAccent,
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  // ── Unit Card Component ─────────────────────────────────────────────────────

  Widget _buildUnitCard(
    PustuPonkesdesModel unit,
    BuildContext context,
    WidgetRef ref,
    Color cardBgColor,
    Color textColor,
    Color subtitleColor,
    Color borderColor,
    Color themeAccent,
  ) {
    final isPustu = unit.tipe == 'PUSTU';
    final typeBadgeColor = isPustu ? const Color(0xFF3498DB) : const Color(0xFF9B59B6);
    final isAktif = unit.statusOperasional.startsWith('Aktif');

    return Container(
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Unit Initial Avatar + Title + Code + Options
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: unit.avatarBg.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  unit.nama.isNotEmpty ? unit.nama.substring(0, 2).toUpperCase() : 'PU',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: unit.avatarBg,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            unit.nama,
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: textColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: typeBadgeColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            unit.tipe,
                            style: GoogleFonts.outfit(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: typeBadgeColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Kode Unit: ${unit.kodeUnit} • Jam: ${unit.jamLayanan}',
                      style: GoogleFonts.outfit(fontSize: 10, color: subtitleColor),
                    ),
                  ],
                ),
              ),
              // Status Badge Toggle
              GestureDetector(
                onTap: () {
                  ref
                      .read(pustuPonkesdesListProvider.notifier)
                      .toggleStatus(unit.id, unit.statusOperasional);
                },
                child: StatusBadge(
                  label: isAktif ? 'AKTIF' : 'TUTUP',
                  color: isAktif ? const Color(0xFF2ECC71) : Colors.redAccent,
                  fontSize: 9,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 14),

          // Details List: PJ, NIK, Telepon, Alamat
          _buildInfoRow(Icons.badge_outlined, 'PJ', unit.penanggungJawab, textColor, subtitleColor),
          const SizedBox(height: 6),
          _buildInfoRow(Icons.fingerprint_rounded, 'NIK PJ', unit.nikPenanggungJawab, textColor, subtitleColor),
          const SizedBox(height: 6),
          _buildInfoRow(Icons.phone_outlined, 'Kontak', unit.telepon, textColor, subtitleColor),
          const SizedBox(height: 6),
          _buildInfoRow(Icons.location_on_outlined, 'Wilayah', '${unit.alamat}, Desa ${unit.village}', textColor, subtitleColor),

          const SizedBox(height: 14),

          // Module Permissions Chips
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: unit.permissions.map((p) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: textColor.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  p.replaceAll('_', ' '),
                  style: GoogleFonts.outfit(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w700,
                    color: subtitleColor,
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 16),

          // Action Buttons: Focus Map, Edit, Delete
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: () {
                  setState(() => _selectedMapFocusUnit = unit);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Fokus lokasi peta diatur ke ${unit.nama}'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                icon: Icon(Icons.my_location_rounded, size: 14, color: themeAccent),
                label: Text(
                  'Lihat di Map',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: themeAccent,
                  ),
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.edit_outlined, size: 18, color: subtitleColor),
                    onPressed: () => _showPustuFormDialog(context, ref, existingUnit: unit),
                    tooltip: 'Edit Unit',
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                    onPressed: () => _confirmDeleteUnit(context, ref, unit),
                    tooltip: 'Hapus Unit',
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, Color textColor, Color subtitleColor) {
    return Row(
      children: [
        Icon(icon, size: 14, color: subtitleColor),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: subtitleColor),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.outfit(fontSize: 11, color: textColor),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // ── Dashed Register Card ────────────────────────────────────────────────────

  Widget _buildDashedRegisterCard(
    BuildContext context,
    WidgetRef ref,
    Color cardBgColor,
    Color textColor,
    Color subtitleColor,
    Color borderColor,
    Color themeAccent,
  ) {
    return Container(
      height: 280,
      decoration: BoxDecoration(
        color: cardBgColor.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: themeAccent.withOpacity(0.4),
          width: 1.5,
          style: BorderStyle.solid,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _showPustuFormDialog(context, ref),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: themeAccent.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.add_rounded, size: 28, color: themeAccent),
                ),
                const SizedBox(height: 16),
                Text(
                  'Register New Pustu/Ponkesdes',
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Lengkapi form untuk mendaftarkan unit Puskesmas Pembantu atau Pondok Kesehatan Desa baru.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: subtitleColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Delete Confirmation Dialog ──────────────────────────────────────────────

  void _confirmDeleteUnit(BuildContext context, WidgetRef ref, PustuPonkesdesModel unit) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Hapus ${unit.nama}?', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Text('Apakah Anda yakin ingin menghapus data unit ${unit.nama} (${unit.kodeUnit})? Data yang dihapus tidak dapat dikembalikan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              await ref.read(pustuPonkesdesListProvider.notifier).removeUnit(unit.id);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── Modal Form Dialog (Register / Edit) ─────────────────────────────────────

  void _showPustuFormDialog(
    BuildContext context,
    WidgetRef ref, {
    PustuPonkesdesModel? existingUnit,
  }) {
    final isEdit = existingUnit != null;

    final namaCtrl = TextEditingController(text: existingUnit?.nama ?? '');
    final kodeCtrl = TextEditingController(
      text: existingUnit?.kodeUnit ?? 'PST-00${DateTime.now().second % 90 + 10}',
    );
    final pjCtrl = TextEditingController(text: existingUnit?.penanggungJawab ?? '');
    final nikCtrl = TextEditingController(text: existingUnit?.nikPenanggungJawab ?? '');
    final telpCtrl = TextEditingController(text: existingUnit?.telepon ?? '');
    final alamatCtrl = TextEditingController(text: existingUnit?.alamat ?? '');
    final villageCtrl = TextEditingController(text: existingUnit?.village ?? 'Sumber Wringin');
    final kecCtrl = TextEditingController(text: existingUnit?.kecamatan ?? 'Sumber Wringin');
    final latCtrl = TextEditingController(text: existingUnit?.latitude.toString() ?? '-7.9797');
    final lngCtrl = TextEditingController(text: existingUnit?.longitude.toString() ?? '113.8228');
    final jamCtrl = TextEditingController(text: existingUnit?.jamLayanan ?? '08:00 - 14:00 WIB');

    String tipeSelected = existingUnit?.tipe ?? 'PUSTU';
    String statusSelected = existingUnit?.statusOperasional ?? 'Aktif / Buka';
    List<String> selectedPermissions = List.from(
      existingUnit?.permissions ?? ['DASHBOARD', 'ANTRIAN', 'FORM_IBU_HAMIL', 'PANTAUAN_IBU_HAMIL'],
    );

    bool isSaving = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setModalState) {
          final notifier = ref.read(landingPageProvider.notifier);
          final cardBg = notifier.getCardColor();
          final textColor = notifier.getTextColor();
          final subtitleColor = notifier.getBodyTextColor();
          final borderColor = notifier.getBorderColor();
          final themeAccent = notifier.getPrimaryColor();

          return AlertDialog(
            backgroundColor: cardBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: borderColor),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: themeAccent.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isEdit ? Icons.edit_rounded : Icons.domain_add_rounded,
                    color: themeAccent,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEdit ? 'Edit Data Pustu / Ponkesdes' : 'Registrasi Pustu / Ponkesdes Baru',
                        style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
                      ),
                      Text(
                        'Isi kelengkapan informasi faskes penunjang wilayah',
                        style: GoogleFonts.outfit(fontSize: 10, color: subtitleColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 520,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tipe Unit & Status
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('TIPE UNIT', style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.bold, color: subtitleColor)),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                initialValue: tipeSelected,
                                dropdownColor: cardBg,
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: cardBg,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                                items: const [
                                  DropdownMenuItem(value: 'PUSTU', child: Text('PUSTU')),
                                  DropdownMenuItem(value: 'PONKESDES', child: Text('PONKESDES')),
                                ],
                                onChanged: (val) {
                                  if (val != null) setModalState(() => tipeSelected = val);
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('STATUS OPERASIONAL', style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.bold, color: subtitleColor)),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                initialValue: statusSelected,
                                dropdownColor: cardBg,
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: cardBg,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                                items: const [
                                  DropdownMenuItem(value: 'Aktif / Buka', child: Text('Aktif / Buka')),
                                  DropdownMenuItem(value: 'Tutup', child: Text('Tutup')),
                                  DropdownMenuItem(value: 'Dalam Perbaikan', child: Text('Dalam Perbaikan')),
                                ],
                                onChanged: (val) {
                                  if (val != null) setModalState(() => statusSelected = val);
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Nama Unit & Kode Unit
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: _buildTextField('NAMA UNIT', namaCtrl, 'e.g. Pustu Sukorejo 1', textColor, subtitleColor, cardBg, borderColor),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 1,
                          child: _buildTextField('KODE UNIT', kodeCtrl, 'PST-001', textColor, subtitleColor, cardBg, borderColor),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Penanggung Jawab & NIK PJ
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField('PENANGGUNG JAWAB (BIDAN/PERAWAT)', pjCtrl, 'Nama PJ', textColor, subtitleColor, cardBg, borderColor),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField('NIK PENANGGUNG JAWAB', nikCtrl, '16 Digit NIK', textColor, subtitleColor, cardBg, borderColor),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Telepon & Jam Layanan
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField('NO TELEPON / KONTAK', telpCtrl, '081234567890', textColor, subtitleColor, cardBg, borderColor),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField('JAM LAYANAN', jamCtrl, '08:00 - 14:00 WIB', textColor, subtitleColor, cardBg, borderColor),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Alamat & Desa
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: _buildTextField('ALAMAT / JALAN', alamatCtrl, 'Jl. Raya Desa...', textColor, subtitleColor, cardBg, borderColor),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 1,
                          child: _buildTextField('DESA / KELURAHAN', villageCtrl, 'Nama Desa', textColor, subtitleColor, cardBg, borderColor),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Coordinat Latitude & Longitude
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField('LATITUDE MAP', latCtrl, '-7.9797', textColor, subtitleColor, cardBg, borderColor),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField('LONGITUDE MAP', lngCtrl, '113.8228', textColor, subtitleColor, cardBg, borderColor),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Akses Fitur Permissions Checkboxes
                    Text('IZIN AKSES SUB-MODUL', style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.bold, color: subtitleColor)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        'DASHBOARD',
                        'MANAGEMENT_PEKERJA',
                        'ANTRIAN',
                        'FORM_IBU_HAMIL',
                        'PANTAUAN_IBU_HAMIL',
                      ].map((perm) {
                        final isChecked = selectedPermissions.contains(perm);
                        return FilterChip(
                          label: Text(perm.replaceAll('_', ' '), style: GoogleFonts.outfit(fontSize: 10)),
                          selected: isChecked,
                          selectedColor: themeAccent.withOpacity(0.2),
                          onSelected: (val) {
                            setModalState(() {
                              if (val) {
                                selectedPermissions.add(perm);
                              } else {
                                selectedPermissions.remove(perm);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: Text('Batal', style: GoogleFonts.outfit(color: subtitleColor)),
              ),
              ElevatedButton.icon(
                icon: isSaving
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_rounded, size: 16),
                label: Text(
                  isSaving ? 'Menyimpan...' : (isEdit ? 'Simpan Perubahan' : 'Registrasi Unit'),
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: isSaving
                    ? null
                    : () async {
                        final nama = namaCtrl.text.trim();
                        final kode = kodeCtrl.text.trim();
                        final pj = pjCtrl.text.trim();
                        final nik = nikCtrl.text.trim();
                        final telp = telpCtrl.text.trim();
                        final alamat = alamatCtrl.text.trim();
                        final village = villageCtrl.text.trim();
                        final lat = double.tryParse(latCtrl.text.trim()) ?? -7.9797;
                        final lng = double.tryParse(lngCtrl.text.trim()) ?? 113.8228;

                        if (nama.isEmpty || pj.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Nama Unit dan Penanggung Jawab wajib diisi!')),
                          );
                          return;
                        }

                        setModalState(() => isSaving = true);

                        if (isEdit) {
                          await ref.read(pustuPonkesdesListProvider.notifier).editUnit(
                                unitId: existingUnit.id,
                                nama: nama,
                                tipe: tipeSelected,
                                kodeUnit: kode,
                                penanggungJawab: pj,
                                nikPenanggungJawab: nik,
                                telepon: telp,
                                alamat: alamat,
                                village: village,
                                kecamatan: kecCtrl.text.trim(),
                                latitude: lat,
                                longitude: lng,
                                statusOperasional: statusSelected,
                                jamLayanan: jamCtrl.text.trim(),
                              );
                        } else {
                          await ref.read(pustuPonkesdesListProvider.notifier).addUnit(
                                nama: nama,
                                tipe: tipeSelected,
                                kodeUnit: kode,
                                penanggungJawab: pj,
                                nikPenanggungJawab: nik,
                                telepon: telp,
                                alamat: alamat,
                                village: village,
                                kecamatan: kecCtrl.text.trim(),
                                latitude: lat,
                                longitude: lng,
                                statusOperasional: statusSelected,
                                jamLayanan: jamCtrl.text.trim(),
                                permissions: selectedPermissions,
                                avatarBg: tipeSelected == 'PUSTU'
                                    ? const Color(0xFF48C9B0)
                                    : const Color(0xFF9B59B6),
                              );
                        }

                        if (dialogCtx.mounted) {
                          Navigator.pop(dialogCtx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                isEdit ? 'Data Pustu/Ponkesdes berhasil diperbarui!' : 'Unit Pustu/Ponkesdes baru berhasil diregistrasi!',
                              ),
                              backgroundColor: themeAccent,
                            ),
                          );
                        }
                      },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    String hint,
    Color textColor,
    Color subtitleColor,
    Color cardBg,
    Color borderColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.bold, color: subtitleColor)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          style: GoogleFonts.outfit(fontSize: 12, color: textColor),
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: cardBg,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
          ),
        ),
      ],
    );
  }
}
