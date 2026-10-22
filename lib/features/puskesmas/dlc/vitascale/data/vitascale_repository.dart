import 'package:supabase_flutter/supabase_flutter.dart';
import 'vitascale_models.dart';

abstract class IVitaScaleRepository {
  Future<List<ChildProfile>> searchChildren({String query = ''});
  Future<bool> saveScreeningResult(ScreeningSession session, {required String staffName});
  Future<List<ScreeningSession>> fetchChildScreeningHistory(String childId);
}

class VitaScaleRepository implements IVitaScaleRepository {
  final SupabaseClient? _client;

  VitaScaleRepository({SupabaseClient? client}) : _client = client;

  // Master profil anak realistis untuk development & mode pratinjau (Demo)
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
    ),
  ];

  static final List<ScreeningSession> _mockHistory = [];

  @override
  Future<List<ChildProfile>> searchChildren({String query = ''}) async {
    final cleanQ = query.trim().toLowerCase();

    // 1. Coba ambil dari Supabase pasien riil jika koneksi tersedia
    if (_client != null) {
      try {
        final List<ChildProfile> dbResults = [];

        // Cari pasien public.user usia <= 12 tahun
        final res = await _client
            .from('user')
            .select('id, name, nik, gender, birth_date, phone_number, address')
            .or('role.eq.pasien,role.eq.patient')
            .ilike('name', '%$cleanQ%')
            .limit(20);

        for (final row in (res as List)) {
          final bDateStr = row['birth_date']?.toString();
          if (bDateStr != null) {
            final bDate = DateTime.tryParse(bDateStr);
            if (bDate != null) {
              final ageMonths = (DateTime.now().year - bDate.year) * 12 + DateTime.now().month - bDate.month;
              if (ageMonths <= 144) {
                // Anak usia 0 - 12 tahun
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
          return dbResults;
        }
      } catch (_) {
        // Fallback ke master sample jika offline / tabel belum ada
      }
    }

    // 2. Filter dari preloaded sample children
    if (cleanQ.isEmpty) {
      return _sampleChildren;
    }

    return _sampleChildren.where((c) {
      return c.name.toLowerCase().contains(cleanQ) ||
          c.nik.contains(cleanQ) ||
          c.id.toLowerCase().contains(cleanQ) ||
          c.parentName.toLowerCase().contains(cleanQ);
    }).toList();
  }

  @override
  Future<bool> saveScreeningResult(
    ScreeningSession session, {
    required String staffName,
  }) async {
    // Simpan ke in-memory history
    _mockHistory.insert(0, session);

    // Draft Supabase Insert (bila tabel vitascale.screening_results sudah aktif di cloud)
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
      } catch (_) {
        // Abaikan jika tabel cloud belum di-apply
      }
    }

    return true;
  }

  @override
  Future<List<ScreeningSession>> fetchChildScreeningHistory(String childId) async {
    return _mockHistory.where((s) => s.child.id == childId).toList();
  }
}
