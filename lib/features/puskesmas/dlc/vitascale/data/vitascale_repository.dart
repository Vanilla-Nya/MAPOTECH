import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'vitascale_models.dart';

abstract class IVitaScaleRepository {
  Future<List<ChildProfile>> searchChildren({String query = ''});
  Future<List<ChildProfile>> searchMapotechRegisteredBalita({
    String query = '',
    String ageFilter = 'Semua',
  });
  bool isChildRegisteredInPuskesmas(ChildProfile child);
  void registerChild(ChildProfile child);
  Future<bool> saveScreeningResult(ScreeningSession session, {required String staffName});
  Future<List<ScreeningSession>> fetchChildScreeningHistory(String childId);
}

class VitaScaleRepository implements IVitaScaleRepository {
  final SupabaseClient? _client;

  VitaScaleRepository({SupabaseClient? client})
      : _client = client ?? _resolveSupabaseClient();

  static SupabaseClient? _resolveSupabaseClient() {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  // Master profil anak yang saat ini terdaftar di Faskes Puskesmas ini
  static final List<ChildProfile> _sampleChildren = [
    ChildProfile(
      id: 'ANK-001',
      name: 'Muhammad Rayyan Al-Fatih',
      nik: '3511082208230001',
      birthDate: DateTime.now().subtract(const Duration(days: 420)), // ~14 bulan (bayi telentang)
      gender: 'L',
      parentName: 'Ahmad Fauzi & Siti Rahmawati',
      noKk: '3511080101180005',
      phone: '0812-3456-7890',
      address: 'Dusun Krajan RT 02 / RW 01, Sumber Wringin',
      latitude: -7.9582,
      longitude: 113.9123,
    ),
    ChildProfile(
      id: 'ANK-002',
      name: 'Aisyah Putri Azzahra',
      nik: '3511085511210002',
      birthDate: DateTime.now().subtract(const Duration(days: 1050)), // ~35 bulan (balita berdiri)
      gender: 'P',
      parentName: 'Budi Santoso & Dewi Lestari',
      noKk: '3511080202190008',
      phone: '0852-9876-5432',
      address: 'Dusun Barat RT 04 / RW 02, Sukorejo',
      latitude: -7.9645,
      longitude: 113.9056,
    ),
    ChildProfile(
      id: 'ANK-003',
      name: 'Kenzo Arkananta Pratama',
      nik: '3511081504250003',
      birthDate: DateTime.now().subtract(const Duration(days: 210)), // ~7 bulan (bayi telentang)
      gender: 'L',
      parentName: 'Rian Pratama & Anisa Putri',
      noKk: '3511080303200012',
      phone: '0813-1122-3344',
      address: 'Dusun Tengah RT 01 / RW 03, Tlogosari',
      latitude: -7.9512,
      longitude: 113.9215,
    ),
    ChildProfile(
      id: 'ANK-004',
      name: 'Nabila Syakira Ramadhani',
      nik: '3511086009180004',
      birthDate: DateTime.now().subtract(const Duration(days: 2200)), // ~6 tahun (anak berdiri)
      gender: 'P',
      parentName: 'Hendra Wijaya & Maria Ulfa',
      noKk: '3511080404210015',
      phone: '0877-6543-2100',
      address: 'Dusun Selatan RT 03 / RW 01, Rejoagung',
      latitude: -7.9701,
      longitude: 113.8990,
    ),
  ];

  // Master katalog pasien balita & anak yang sudah terdaftar di Mapotech secara keseluruhan
  static final List<ChildProfile> _mapotechMasterBalita = [
    ChildProfile(
      id: 'MAPO-BLT-001',
      name: 'Kenzo Arkananta Pratama',
      nik: '3511081504250003',
      birthDate: DateTime.now().subtract(const Duration(days: 210)), // ~7 bulan
      gender: 'L',
      parentName: 'Rian Pratama & Anisa Putri',
      noKk: '3511080303200012',
      phone: '0813-1122-3344',
      address: 'Dusun Tengah RT 01 / RW 03, Tlogosari',
    ),
    ChildProfile(
      id: 'MAPO-BLT-002',
      name: 'Gibran Hafizh Pratama',
      nik: '3511080503250009',
      birthDate: DateTime.now().subtract(const Duration(days: 245)), // ~8 bulan
      gender: 'L',
      parentName: 'Firman & Nur Halimah',
      noKk: '3511080505210019',
      phone: '0821-4455-6677',
      address: 'Dusun Krajan RT 05 / RW 03, Sumber Wringin',
    ),
    ChildProfile(
      id: 'MAPO-BLT-003',
      name: 'Althaf Ryan Wardhana',
      nik: '3511082501250011',
      birthDate: DateTime.now().subtract(const Duration(days: 280)), // ~9 bulan
      gender: 'L',
      parentName: 'Ryan Wardhana & Linda',
      noKk: '3511080606210022',
      phone: '0856-1234-9876',
      address: 'Dusun Kebun RT 03 / RW 02, Sumber Wringin',
    ),
    ChildProfile(
      id: 'MAPO-BLT-004',
      name: 'Bima Raditya Putra',
      nik: '3511081910240007',
      birthDate: DateTime.now().subtract(const Duration(days: 365)), // ~12 bulan (1 tahun)
      gender: 'L',
      parentName: 'Joko Susilo & Ratna Dewi',
      noKk: '3511080707200033',
      phone: '0813-1122-3345',
      address: 'Dusun Selatan RT 03 / RW 02, Sukorejo',
    ),
    ChildProfile(
      id: 'MAPO-BLT-005',
      name: 'Muhammad Rayyan Al-Fatih',
      nik: '3511082208230001',
      birthDate: DateTime.now().subtract(const Duration(days: 420)), // ~14 bulan
      gender: 'L',
      parentName: 'Ahmad Fauzi & Siti Rahmawati',
      noKk: '3511080101180005',
      phone: '0812-3456-7890',
      address: 'Dusun Krajan RT 02 / RW 01, Sumber Wringin',
    ),
    ChildProfile(
      id: 'MAPO-BLT-006',
      name: 'Naura Shakila',
      nik: '3511086508240014',
      birthDate: DateTime.now().subtract(const Duration(days: 435)), // ~14 bulan
      gender: 'P',
      parentName: 'Faisal Akbar & Siti Rohani',
      noKk: '3511080808220044',
      phone: '0812-9988-7766',
      address: 'Dusun Timur RT 01 / RW 02, Sumber Wringin',
    ),
    ChildProfile(
      id: 'MAPO-BLT-007',
      name: 'Arka Danendra Pratama',
      nik: '3511081406240005',
      birthDate: DateTime.now().subtract(const Duration(days: 490)), // ~16 bulan
      gender: 'L',
      parentName: 'Agus Pratama & Maya Sari',
      noKk: '3511080909210055',
      phone: '0812-3456-7891',
      address: 'Dusun Barat RT 02 / RW 01, Sumber Wringin',
    ),
    ChildProfile(
      id: 'MAPO-BLT-008',
      name: 'Kayla Almira Maritza',
      nik: '3511084203240016',
      birthDate: DateTime.now().subtract(const Duration(days: 560)), // ~18 bulan
      gender: 'P',
      parentName: 'Dian Pramana & Linda',
      noKk: '3511081010210066',
      phone: '0858-1234-5678',
      address: 'Dusun Rejo RT 02 / RW 04, Rejoagung',
    ),
    ChildProfile(
      id: 'MAPO-BLT-009',
      name: 'Alvaro Daniswara',
      nik: '3511081105230013',
      birthDate: DateTime.now().subtract(const Duration(days: 870)), // ~29 bulan (2 thn 5 bln)
      gender: 'L',
      parentName: 'Danang Wicaksono & Tri Wahyuni',
      noKk: '3511081111200077',
      phone: '0822-3344-5566',
      address: 'Dusun Curah RT 04 / RW 03, Sukorejo',
    ),
    ChildProfile(
      id: 'MAPO-BLT-010',
      name: 'Khadijah Al-Zahra',
      nik: '3511086102230006',
      birthDate: DateTime.now().subtract(const Duration(days: 970)), // ~32 bulan (2 thn 8 bln)
      gender: 'P',
      parentName: 'Yusuf Mansur & Fatimah',
      noKk: '3511081212190088',
      phone: '0852-9876-5431',
      address: 'Dusun Krajan RT 01 / RW 02, Tlogosari',
    ),
    ChildProfile(
      id: 'MAPO-BLT-011',
      name: 'Bilqis Hanifa Azzahra',
      nik: '3511087012220012',
      birthDate: DateTime.now().subtract(const Duration(days: 1020)), // ~34 bulan
      gender: 'P',
      parentName: 'Arif Rahman & Nurul Hidayah',
      noKk: '3511081313200099',
      phone: '0813-7788-9900',
      address: 'Dusun Karang RT 02 / RW 01, Tlogosari',
    ),
    ChildProfile(
      id: 'MAPO-BLT-012',
      name: 'Aisyah Putri Azzahra',
      nik: '3511085511210002',
      birthDate: DateTime.now().subtract(const Duration(days: 1050)), // ~35 bulan (2 thn 11 bln)
      gender: 'P',
      parentName: 'Budi Santoso & Dewi Lestari',
      noKk: '3511080202190008',
      phone: '0852-9876-5432',
      address: 'Dusun Barat RT 04 / RW 02, Sukorejo',
    ),
    ChildProfile(
      id: 'MAPO-BLT-013',
      name: 'Safiya Nur Aulia',
      nik: '3511085207220008',
      birthDate: DateTime.now().subtract(const Duration(days: 1180)), // ~39 bulan (3 thn 3 bln)
      gender: 'P',
      parentName: 'Irwan Setiawan & Rini Anggraini',
      noKk: '3511081414210100',
      phone: '0877-6543-2101',
      address: 'Dusun Tengah RT 04 / RW 01, Rejoagung',
    ),
    ChildProfile(
      id: 'MAPO-BLT-014',
      name: 'Malik Ibrahim',
      nik: '3511081709220017',
      birthDate: DateTime.now().subtract(const Duration(days: 1260)), // ~42 bulan (3 thn 6 bln)
      gender: 'L',
      parentName: 'Rusdi & Fatmawati',
      noKk: '3511081515200111',
      phone: '0823-4567-8901',
      address: 'Dusun Krajan RT 03 / RW 01, Tlogosari',
    ),
    ChildProfile(
      id: 'MAPO-BLT-015',
      name: 'Zahra Salsabila',
      nik: '3511084809210010',
      birthDate: DateTime.now().subtract(const Duration(days: 1470)), // ~49 bulan (4 thn 1 bln)
      gender: 'P',
      parentName: 'Hadi Prasetyo & Siti Aminah',
      noKk: '3511081616210122',
      phone: '0819-8765-4321',
      address: 'Dusun Rejo RT 01 / RW 01, Sukosari',
    ),
    ChildProfile(
      id: 'MAPO-BLT-016',
      name: 'Dhafin Raffa Al-Ghifari',
      nik: '3511081804200015',
      birthDate: DateTime.now().subtract(const Duration(days: 1980)), // ~66 bulan (5.5 thn)
      gender: 'L',
      parentName: 'Ghifari & Annisa',
      noKk: '3511081717190133',
      phone: '0857-1122-3344',
      address: 'Dusun Barat RT 02 / RW 02, Rejoagung',
    ),
    ChildProfile(
      id: 'MAPO-BLT-017',
      name: 'Nabila Syakira Ramadhani',
      nik: '3511086009180004',
      birthDate: DateTime.now().subtract(const Duration(days: 2200)), // ~6 tahun (72 bulan)
      gender: 'P',
      parentName: 'Hendra Wijaya & Maria Ulfa',
      noKk: '3511080404210015',
      phone: '0877-6543-2100',
      address: 'Dusun Selatan RT 03 / RW 01, Rejoagung',
    ),
  ];

  static final List<ScreeningSession> _mockHistory = [];

  // Pool gabungan seluruh pasien balita terdaftar hardcode (sample faskes + katalog master Mapotech)
  static List<ChildProfile> get _allRegisteredChildren {
    final Map<String, ChildProfile> map = {};
    for (final c in _sampleChildren) {
      final key = c.nik.isNotEmpty && c.nik != '-' ? c.nik : c.id;
      map[key] = c;
    }
    for (final c in _mapotechMasterBalita) {
      final key = c.nik.isNotEmpty && c.nik != '-' ? c.nik : c.id;
      if (!map.containsKey(key)) {
        map[key] = c;
      }
    }
    return map.values.toList();
  }

  @override
  bool isChildRegisteredInPuskesmas(ChildProfile child) {
    return _allRegisteredChildren.any(
      (c) => c.id == child.id || (child.nik != '-' && c.nik == child.nik),
    );
  }

  @override
  void registerChild(ChildProfile child) {
    if (!isChildRegisteredInPuskesmas(child)) {
      _sampleChildren.insert(0, child);
    }
  }

  @override
  Future<List<ChildProfile>> searchChildren({String query = ''}) async {
    final cleanQ = query.trim().toLowerCase();

    // 1. Coba ambil dari Supabase pasien riil jika koneksi tersedia
    if (_client != null) {
      try {
        final List<ChildProfile> dbResults = [];

        var req = _client
            .from('user')
            .select('id, name, nik, gender, birth_date, phone_number, address')
            .or('role.eq.pasien,role.eq.patient');

        if (cleanQ.isNotEmpty) {
          req = req.or('name.ilike.%$cleanQ%,nik.ilike.%$cleanQ%');
        }

        final res = await req.limit(30);

        for (final row in (res as List)) {
          final bDateStr = row['birth_date']?.toString();
          if (bDateStr != null) {
            final bDate = DateTime.tryParse(bDateStr);
            if (bDate != null) {
              final ageMonths = (DateTime.now().year - bDate.year) * 12 + DateTime.now().month - bDate.month;
              if (ageMonths <= 144) {
                dbResults.add(ChildProfile(
                  id: row['id']?.toString() ?? '',
                  name: row['name']?.toString() ?? 'Tanpa Nama',
                  nik: row['nik']?.toString() ?? '-',
                  birthDate: bDate,
                  gender: (row['gender']?.toString().toLowerCase().startsWith('l') ?? true) ? 'L' : 'P',
                  parentName: 'Wali Terdaftar',
                  phone: row['phone_number']?.toString(),
                  address: row['address']?.toString() ?? 'Puskesmas',
                ));
              }
            }
          }
        }

        if (dbResults.isNotEmpty) {
          // Merge with registered children deduplicated
          final Map<String, ChildProfile> merged = {};
          for (final c in _allRegisteredChildren) {
            merged[c.nik.isNotEmpty && c.nik != '-' ? c.nik : c.id] = c;
          }
          for (final c in dbResults) {
            merged[c.nik.isNotEmpty && c.nik != '-' ? c.nik : c.id] = c;
          }
          return merged.values.where((c) {
            if (cleanQ.isEmpty) return true;
            return c.name.toLowerCase().contains(cleanQ) ||
                c.nik.contains(cleanQ) ||
                c.parentName.toLowerCase().contains(cleanQ);
          }).toList();
        }
      } catch (e) {
        debugPrint('Supabase searchChildren error: $e');
      }
    }

    // 2. Filter dari master sample hardcode
    final pool = _allRegisteredChildren;
    if (cleanQ.isEmpty) {
      return List.from(pool);
    }

    return pool.where((c) {
      return c.name.toLowerCase().contains(cleanQ) ||
          c.nik.contains(cleanQ) ||
          c.id.toLowerCase().contains(cleanQ) ||
          c.parentName.toLowerCase().contains(cleanQ);
    }).toList();
  }

  /// Mencari data pasien balita & anak yang sudah terdaftar di ekosistem Mapotech
  /// Mendukung pencarian berdasarkan NIK (16 digit), Nama, dan difilter berdasarkan usia (Balita < 5 Thn, Bayi < 24 Bln, dll)
  @override
  Future<List<ChildProfile>> searchMapotechRegisteredBalita({
    String query = '',
    String ageFilter = 'Semua',
  }) async {
    final cleanQ = query.trim().toLowerCase();
    final Map<String, ChildProfile> candidatesMap = {};

    // 1. Coba query dari Supabase jika koneksi online
    if (_client != null) {
      try {
        var queryBuilder = _client
            .from('user')
            .select('id, name, nik, gender, birth_date, phone_number, address')
            .or('role.eq.pasien,role.eq.patient');

        if (cleanQ.isNotEmpty) {
          queryBuilder = queryBuilder.or('name.ilike.%$cleanQ%,nik.ilike.%$cleanQ%');
        }

        final res = await queryBuilder.limit(40);
        for (final row in (res as List)) {
          final bDateStr = row['birth_date']?.toString();
          if (bDateStr != null) {
            final bDate = DateTime.tryParse(bDateStr);
            if (bDate != null) {
              final ageMonths = (DateTime.now().year - bDate.year) * 12 + DateTime.now().month - bDate.month;
              if (ageMonths <= 144) {
                final child = ChildProfile(
                  id: row['id']?.toString() ?? 'USR-${DateTime.now().millisecondsSinceEpoch}',
                  name: row['name']?.toString() ?? 'Tanpa Nama',
                  nik: row['nik']?.toString() ?? '-',
                  birthDate: bDate,
                  gender: (row['gender']?.toString().toLowerCase().startsWith('l') ?? true) ? 'L' : 'P',
                  parentName: 'Wali Terdaftar Mapotech',
                  phone: row['phone_number']?.toString(),
                  address: row['address']?.toString() ?? 'Bondowoso',
                );
                final key = child.nik != '-' ? child.nik : child.id;
                candidatesMap[key] = child;
              }
            }
          }
        }
      } catch (e) {
        debugPrint('Supabase searchMapotechRegisteredBalita error: $e');
      }
    }

    // 2. Gabungkan dengan data master pool pasien Mapotech
    for (final child in _mapotechMasterBalita) {
      final key = child.nik != '-' ? child.nik : child.id;
      if (!candidatesMap.containsKey(key)) {
        candidatesMap[key] = child;
      }
    }

    // 3. Terapkan Filter Pencarian (NIK atau Nama atau Wali)
    List<ChildProfile> resultList = candidatesMap.values.toList();

    if (cleanQ.isNotEmpty) {
      resultList = resultList.where((child) {
        final matchNik = child.nik.toLowerCase().contains(cleanQ);
        final matchName = child.name.toLowerCase().contains(cleanQ);
        final matchParent = child.parentName.toLowerCase().contains(cleanQ);
        return matchNik || matchName || matchParent;
      }).toList();
    }

    // 4. Terapkan Filter Usia
    if (ageFilter == 'Balita (< 5 Thn)' || ageFilter == 'Balita') {
      resultList = resultList.where((c) => c.isBalita).toList();
    } else if (ageFilter == 'Bayi (< 24 Bln)' || ageFilter == 'Bayi') {
      resultList = resultList.where((c) => c.isUnder24Months).toList();
    } else if (ageFilter == 'Anak (≥ 24 Bln)' || ageFilter == 'Anak') {
      resultList = resultList.where((c) => !c.isUnder24Months).toList();
    } else {
      // 'Semua' -> Semua usia 0 - 12 tahun
      resultList = resultList.where((c) => c.ageInMonths <= 144).toList();
    }

    // 5. Urutkan dari usia termuda ke yang lebih tua
    resultList.sort((a, b) => a.ageInMonths.compareTo(b.ageInMonths));

    return resultList;
  }

  @override
  Future<bool> saveScreeningResult(
    ScreeningSession session, {
    required String staffName,
  }) async {
    _mockHistory.insert(0, session);

    if (_client != null && !session.isDemo) {
      try {
        await _client.schema('vitascale').from('screening_results').insert({
          'session_id': session.sessionId,
          'facility_id': session.facilityId,
          'child_id': session.child.id,
          'child_name': session.child.name,
          'child_nik': session.child.nik,
          'child_age_months': session.child.ageInMonths,
          'mode': session.mode.code,
          'weight_kg': session.weight.value,
          'height_cm': session.height.value,
          'waist_cm': session.waist.value,
          'whtr_ratio': session.calculatedWHtR,
          'verified_by': staffName,
          'verified_at': DateTime.now().toIso8601String(),
          'notes': session.notes,
        });
      } catch (_) {}
    }

    return true;
  }

  @override
  Future<List<ScreeningSession>> fetchChildScreeningHistory(String childId) async {
    return _mockHistory.where((s) => s.child.id == childId).toList();
  }
}
