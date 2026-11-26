import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:mapotech/shared/supabase_service.dart';
import 'package:mapotech/shared/web_helpers.dart';

/// Service Terpadu untuk Skema `community_health_center` di Supabase
/// Menangani Modul:
/// 1. MomiCare (Ibu Hamil, 0–9 Bulan)
/// 2. VitaScale Anak (Balita, 0–59 Bulan)
/// Arsitektur: Append-Only (ALL INSERT) + SHA-256 Blockchain Hash Chain
class CommunityHealthCenterService {
  static final CommunityHealthCenterService _instance =
      CommunityHealthCenterService._internal();
  factory CommunityHealthCenterService() => _instance;
  CommunityHealthCenterService._internal();

  static const String schemaName = 'community_health_center';
  static const String genesisHash =
      '0000000000000000000000000000000000000000000000000000000000000000';

  /// Helper untuk komputasi Hash SHA-256
  static String calculateHash(String input) {
    final bytes = utf8.encode(input);
    return sha256.convert(bytes).toString();
  }

  // ===========================================================================
  // 1. MOMICARE (IBU HAMIL 0–9 BULAN)
  // ===========================================================================

  /// Mengambil daftar antrian ibu hamil aktif di Puskesmas
  Future<List<Map<String, dynamic>>> fetchMomiCareQueues({
    String? facilityId,
    String? search,
  }) async {
    try {
      var query = SupabaseService.client
          .schema(schemaName)
          .from('momicare_queue')
          .select();

      if (facilityId != null && facilityId.isNotEmpty) {
        query = query.eq('facility_id', facilityId);
      }
      if (search != null && search.trim().isNotEmpty) {
        query = query.or('nama_lengkap.ilike.%$search%,nik.ilike.%$search%');
      }

      final response = await query.order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('[MomiCare] Error fetch queues: $e');
      return [];
    }
  }

  /// Membuat antrian kehamilan baru di MomiCare
  Future<Map<String, dynamic>?> createMomiCareQueue({
    required String facilityId,
    String? idPatient,
    required String nik,
    required String namaLengkap,
    String? namaSuami,
    String? noKk,
    String? noTelepon,
    required String alamat,
    double latitude = -7.9582,
    double longitude = 113.9123,
    required DateTime hpht,
    required DateTime hpl,
    int gravida = 1,
    int partus = 0,
    int abortus = 0,
    int ksprScore = 2,
    String ksprStatus = 'KRR',
  }) async {
    try {
      final payload = {
        'facility_id': facilityId,
        'id_patient': idPatient,
        'nik': nik,
        'nama_lengkap': namaLengkap,
        'nama_suami': namaSuami,
        'no_kk': noKk,
        'no_telepon': noTelepon,
        'alamat': alamat,
        'latitude': latitude,
        'longitude': longitude,
        'hpht': hpht.toIso8601String().split('T')[0],
        'hpl': hpl.toIso8601String().split('T')[0],
        'gravida': gravida,
        'partus': partus,
        'abortus': abortus,
        'kspr_score': ksprScore,
        'kspr_status': ksprStatus,
        'lifecycle': 'aktif',
      };

      final res = await SupabaseService.client
          .schema(schemaName)
          .from('momicare_queue')
          .insert(payload)
          .select()
          .single();

      return res;
    } catch (e) {
      debugPrint('[MomiCare] Error create queue: $e');
      return null;
    }
  }

  /// Menambahkan Kunjungan ANC Baru (ALL INSERT + Hash Chain SHA-256)
  Future<bool> insertMomiCareKunjunganWithExam({
    required String idQueue,
    String? idPatient,
    required String visitNumber, // 'K1' s/d 'K6'
    required DateTime visitDate,
    required String examinerName,
    String examinerRole = 'Bidan',
    bool isHomeVisit = false,
    String? notes,
    // Parameter Pemeriksaan Fisik 10T
    required double usiaKehamilanMinggu,
    required double beratBadanKg,
    required double tinggiBadanCm,
    int sistol = 120,
    int diastol = 80,
    required double lilaCm,
    double? tfuCm,
    int? djjBpm,
    String presentasiJanin = 'Kepala',
    String statusImunisasiTt = 'T2',
    int tabletFe = 30,
    double? hbGDl,
    String proteinUrine = 'Negatif',
    // Diagnosa
    String? icd10Code,
    required String diagnosaText,
    String? faktorRisiko,
    String? tindakanTerapi,
    String? anjuranNutrisi,
  }) async {
    try {
      // 1. Dapatkan previous_hash dari kunjungan terakhir pada queue ini
      String previousHash = genesisHash;
      try {
        final lastRow = await SupabaseService.client
            .schema(schemaName)
            .from('momicare_kunjungan')
            .select('current_hash')
            .eq('id_queue', idQueue)
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();

        if (lastRow != null && lastRow['current_hash'] != null) {
          previousHash = lastRow['current_hash'] as String;
        }
      } catch (_) {}

      // 2. Hitung current_hash
      final nowStr = DateTime.now().toIso8601String();
      final visitDateStr = visitDate.toIso8601String().split('T')[0];
      final rawHashPayload = '$previousHash$idQueue$visitNumber$visitDateStr$nowStr';
      final currentHash = calculateHash(rawHashPayload);

      // 3. ALL INSERT ke momicare_kunjungan
      final kunjunganRes = await SupabaseService.client
          .schema(schemaName)
          .from('momicare_kunjungan')
          .insert({
            'id_queue': idQueue,
            'id_patient': idPatient,
            'visit_number': visitNumber,
            'visit_date': visitDateStr,
            'examiner_name': examinerName,
            'examiner_role': examinerRole,
            'is_home_visit': isHomeVisit,
            'notes': notes,
            'previous_hash': previousHash,
            'current_hash': currentHash,
          })
          .select('id')
          .single();

      final kunjunganId = kunjunganRes['id'] as String;

      // 4. ALL INSERT ke momicare_pemeriksaan
      await SupabaseService.client
          .schema(schemaName)
          .from('momicare_pemeriksaan')
          .insert({
            'id_kunjungan': kunjunganId,
            'usia_kehamilan_minggu': usiaKehamilanMinggu,
            'berat_badan_kg': beratBadanKg,
            'tinggi_badan_cm': tinggiBadanCm,
            'tekanan_darah_sistol': sistol,
            'tekanan_darah_diastol': diastol,
            'lila_cm': lilaCm,
            'tfu_cm': tfuCm,
            'djj_bpm': djjBpm,
            'presentasi_janin': presentasiJanin,
            'status_imunisasi_tt': statusImunisasiTt,
            'tablet_fe_diberikan': tabletFe,
            'hb_g_dl': hbGDl,
            'protein_urine': proteinUrine,
          });

      // 5. ALL INSERT ke momicare_diagnosa
      await SupabaseService.client
          .schema(schemaName)
          .from('momicare_diagnosa')
          .insert({
            'id_kunjungan': kunjunganId,
            'icd10_code': icd10Code,
            'diagnosa_text': diagnosaText,
            'faktor_risiko': faktorRisiko,
            'tindakan_terapi': tindakanTerapi,
            'anjuran_nutrisi': anjuranNutrisi,
          });

      return true;
    } catch (e) {
      debugPrint('[MomiCare] Error insert visit: $e');
      return false;
    }
  }

  // ===========================================================================
  // 2. TRANSISI PERSALINAN (9 BULAN) -> VITASCALE ANAK (0–59 BULAN)
  // ===========================================================================

  /// Mencatat persalinan ibu hamil, menutup antrian MomiCare (arsip permanen),
  /// dan membuat antrian balita baru di VitaScale Anak (0–59 bulan)
  Future<Map<String, dynamic>?> transitionBirthToVitaScaleAnak({
    required String momicareQueueId,
    required String facilityId,
    String? idPatientAnak,
    required String namaAnak,
    required String nikAnak,
    required String jenisKelamin, // 'L' atau 'P'
    required DateTime tanggalLahir,
    required String namaWali,
    String? noKk,
    String? noTelepon,
    required String alamat,
    double latitude = -7.9582,
    double longitude = 113.9123,
    double beratLahirKg = 3.1,
    double panjangLahirCm = 49.0,
  }) async {
    try {
      // 1. Tandai antrian MomiCare sebagai selesai
      await SupabaseService.client
          .schema(schemaName)
          .from('momicare_queue')
          .update({'lifecycle': 'selesai'})
          .eq('id', momicareQueueId);

      // 2. Buat antrian baru di vitascale_anak_queue terhubung dengan id_momicare_queue
      final anakPayload = {
        'facility_id': facilityId,
        'id_momicare_queue': momicareQueueId,
        'id_patient': idPatientAnak,
        'nik': nikAnak,
        'nama_anak': namaAnak,
        'jenis_kelamin': jenisKelamin,
        'tanggal_lahir': tanggalLahir.toIso8601String().split('T')[0],
        'nama_wali': namaWali,
        'no_kk': noKk,
        'no_telepon': noTelepon,
        'alamat': alamat,
        'latitude': latitude,
        'longitude': longitude,
        'lifecycle': 'aktif',
      };

      final anakRes = await SupabaseService.client
          .schema(schemaName)
          .from('vitascale_anak_queue')
          .insert(anakPayload)
          .select()
          .single();

      final idAnakQueue = anakRes['id'] as String;

      // 3. Catat kunjungan awal kelahiran (Kunjungan Neonatus 1 / Bulan-0) dengan Hash Chain Genesis
      await insertVitaScaleAnakKunjunganWithAntropometry(
        idQueue: idAnakQueue,
        visitNumber: 'Bulan-0 (Lahir)',
        visitDate: tanggalLahir,
        posyanduName: 'Ruang Bersalin Puskesmas',
        examinerName: 'Bidan Penolong Persalinan',
        usiaBulan: 0,
        beratBadanKg: beratLahirKg,
        panjangTinggiCm: panjangLahirCm,
        metodeUkur: 'PB',
        statusGizi: 'Gizi Baik (Berat Lahir Cukup)',
        statusStunting: 'Normal (Panjang Lahir Sesuai)',
        diagnosaPrimer: 'Bayi Baru Lahir Cukup Bulan Sehat',
        rencanaNutrisiHarian: 'Inisiasi Menyusu Dini (IMD) & ASI Eksklusif 0–6 Bulan.',
      );

      return anakRes;
    } catch (e) {
      debugPrint('[Transition] Error transition birth: $e');
      return null;
    }
  }

  // ===========================================================================
  // 3. VITASCALE ANAK (BALITA 0–59 BULAN)
  // ===========================================================================

  /// Mengambil daftar antrian balita di Puskesmas
  Future<List<Map<String, dynamic>>> fetchVitaScaleAnakQueues({
    String? facilityId,
    String? search,
  }) async {
    try {
      var query = SupabaseService.client
          .schema(schemaName)
          .from('vitascale_anak_queue')
          .select();

      if (facilityId != null && facilityId.isNotEmpty) {
        query = query.eq('facility_id', facilityId);
      }
      if (search != null && search.trim().isNotEmpty) {
        query = query.or('nama_anak.ilike.%$search%,nik.ilike.%$search%,nama_wali.ilike.%$search%');
      }

      final response = await query.order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('[VitaScale Anak] Error fetch queues: $e');
      return [];
    }
  }

  /// Menambahkan Kunjungan Penimbangan Posyandu Baru (ALL INSERT + Hash Chain SHA-256)
  Future<bool> insertVitaScaleAnakKunjunganWithAntropometry({
    required String idQueue,
    String? idPatient,
    required String visitNumber, // e.g. 'Bulan-6', 'Bulan-12'
    required DateTime visitDate,
    String posyanduName = 'Posyandu Terpadu Puskesmas',
    required String examinerName,
    bool isHomeVisit = false,
    String? notes,
    // Antropometri IoT
    required int usiaBulan,
    required double beratBadanKg,
    required double panjangTinggiCm,
    String metodeUkur = 'PB',
    double? lingkarKepalaCm,
    double? lilaCm,
    double? lingkarPerutCm,
    double? zscoreBbu,
    double? zscoreTbu,
    double? zscoreBbtb,
    String statusGizi = 'Gizi Baik',
    String statusStunting = 'Normal',
    String kmsStatus = 'N',
    bool dapatVitA = false,
    bool dapatObatCacing = false,
    String? imunisasi,
    String iotSource = 'esp32_hx711_ultrasonic',
    // Diagnosa & Rencana Nutrisi AI
    String icd10Code = 'E44.0',
    required String diagnosaPrimer,
    String? faktorEtiologi,
    required String rencanaNutrisiHarian,
    String? rekomendasiProteinHewani,
    String? edukasiOrangTua,
  }) async {
    try {
      // 1. Dapatkan previous_hash balita ini
      String previousHash = genesisHash;
      try {
        final lastRow = await SupabaseService.client
            .schema(schemaName)
            .from('vitascale_anak_kunjungan')
            .select('current_hash')
            .eq('id_queue', idQueue)
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();

        if (lastRow != null && lastRow['current_hash'] != null) {
          previousHash = lastRow['current_hash'] as String;
        }
      } catch (_) {}

      // 2. Hitung current_hash
      final nowStr = DateTime.now().toIso8601String();
      final visitDateStr = visitDate.toIso8601String().split('T')[0];
      final rawHashPayload = '$previousHash$idQueue$visitNumber$visitDateStr$nowStr';
      final currentHash = calculateHash(rawHashPayload);

      // 3. ALL INSERT ke vitascale_anak_kunjungan
      final kunjunganRes = await SupabaseService.client
          .schema(schemaName)
          .from('vitascale_anak_kunjungan')
          .insert({
            'id_queue': idQueue,
            'id_patient': idPatient,
            'visit_number': visitNumber,
            'visit_date': visitDateStr,
            'posyandu_name': posyanduName,
            'examiner_name': examinerName,
            'is_home_visit': isHomeVisit,
            'notes': notes,
            'previous_hash': previousHash,
            'current_hash': currentHash,
          })
          .select('id')
          .single();

      final kunjunganId = kunjunganRes['id'] as String;

      // 4. ALL INSERT ke vitascale_anak_pemeriksaan
      await SupabaseService.client
          .schema(schemaName)
          .from('vitascale_anak_pemeriksaan')
          .insert({
            'id_kunjungan': kunjunganId,
            'usia_bulan': usiaBulan,
            'berat_badan_kg': beratBadanKg,
            'panjang_tinggi_cm': panjangTinggiCm,
            'metode_ukur': metodeUkur,
            'lingkar_kepala_cm': lingkarKepalaCm,
            'lingkar_lengan_lila_cm': lilaCm,
            'lingkar_perut_cm': lingkarPerutCm,
            'zscore_bbu': zscoreBbu,
            'zscore_tbu': zscoreTbu,
            'zscore_bbtb': zscoreBbtb,
            'status_gizi': statusGizi,
            'status_stunting': statusStunting,
            'kms_status': kmsStatus,
            'dapat_vitamin_a': dapatVitA,
            'dapat_obat_cacing': dapatObatCacing,
            'imunisasi_diberikan': imunisasi,
            'iot_source': iotSource,
          });

      // 5. ALL INSERT ke vitascale_anak_diagnosa
      await SupabaseService.client
          .schema(schemaName)
          .from('vitascale_anak_diagnosa')
          .insert({
            'id_kunjungan': kunjunganId,
            'icd10_code': icd10Code,
            'diagnosa_primer': diagnosaPrimer,
            'faktor_etiologi': faktorEtiologi,
            'rencana_nutrisi_harian': rencanaNutrisiHarian,
            'rekomendasi_protein_hewani': rekomendasiProteinHewani,
            'edukasi_orang_tua': edukasiOrangTua,
          });

      return true;
    } catch (e) {
      debugPrint('[VitaScale Anak] Error insert visit: $e');
      return false;
    }
  }

  /// Memastikan antrean anak ada lalu menyimpan hasil skrining, antropometri,
  /// dan diagnosa AI Reasoning ke skema `community_health_center`.
  Future<bool> saveVitaScaleScreeningRecord({
    required String facilityId,
    required String nik,
    required String namaAnak,
    required String jenisKelamin,
    required DateTime tanggalLahir,
    required String namaWali,
    required String alamat,
    String? noTelepon,
    required String examinerName,
    required int usiaBulan,
    required double beratBadanKg,
    required double panjangTinggiCm,
    required String metodeUkur,
    double? lingkarKepalaCm,
    double? lilaCm,
    double? lingkarPerutCm,
    String statusGizi = 'Gizi Baik',
    String statusStunting = 'Normal',
    String kmsStatus = 'N',
    bool dapatVitA = false,
    bool dapatObatCacing = false,
    String iotSource = 'manual_input',
    String icd10Code = 'Z00.1',
    required String diagnosaPrimer,
    String? faktorEtiologi,
    required String rencanaNutrisiHarian,
    String? edukasiOrangTua,
    String? notes,
  }) async {
    if (!_isValidUuid(facilityId)) return false;

    try {
      final client = SupabaseService.client;
      final existingQueue = await client
          .schema(schemaName)
          .from('vitascale_anak_queue')
          .select('id')
          .eq('facility_id', facilityId)
          .eq('nik', nik)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      String idQueue;
      if (existingQueue != null && existingQueue['id'] != null) {
        idQueue = existingQueue['id'].toString();
      } else {
        final created = await client
            .schema(schemaName)
            .from('vitascale_anak_queue')
            .insert({
              'facility_id': facilityId,
              'nik': nik,
              'nama_anak': namaAnak,
              'jenis_kelamin': jenisKelamin,
              'tanggal_lahir': tanggalLahir.toIso8601String().split('T')[0],
              'nama_wali': namaWali,
              'no_telepon': noTelepon,
              'alamat': alamat,
              'lifecycle': 'aktif',
            })
            .select('id')
            .single();
        idQueue = created['id'].toString();
      }

      return await insertVitaScaleAnakKunjunganWithAntropometry(
        idQueue: idQueue,
        visitNumber: 'Bulan-$usiaBulan',
        visitDate: DateTime.now(),
        examinerName: examinerName,
        notes: notes,
        usiaBulan: usiaBulan,
        beratBadanKg: beratBadanKg,
        panjangTinggiCm: panjangTinggiCm,
        metodeUkur: metodeUkur,
        lingkarKepalaCm: lingkarKepalaCm,
        lilaCm: lilaCm,
        lingkarPerutCm: lingkarPerutCm,
        statusGizi: statusGizi,
        statusStunting: statusStunting,
        kmsStatus: kmsStatus,
        dapatVitA: dapatVitA,
        dapatObatCacing: dapatObatCacing,
        iotSource: iotSource,
        icd10Code: icd10Code,
        diagnosaPrimer: diagnosaPrimer,
        faktorEtiologi: faktorEtiologi,
        rencanaNutrisiHarian: rencanaNutrisiHarian,
        edukasiOrangTua: edukasiOrangTua,
      );
    } catch (e) {
      debugPrint('[VitaScale Anak] Error saveVitaScaleScreeningRecord: $e');
      return false;
    }
  }

  // ===========================================================================
  // 4. AKSES PORTAL PASIEN (PORTAL MOMICARE & MY FAMILY)
  // ===========================================================================

  /// Mengambil riwayat kehamilan MomiCare untuk akun pasien tertentu
  Future<Map<String, dynamic>?> fetchPatientActivePregnancy(String patientNik) async {
    try {
      final queue = await SupabaseService.client
          .schema(schemaName)
          .from('momicare_queue')
          .select()
          .eq('nik', patientNik)
          .eq('lifecycle', 'aktif')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (queue == null) return null;

      // Ambil seluruh log kunjungan berantai
      final visits = await SupabaseService.client
          .schema(schemaName)
          .from('momicare_kunjungan')
          .select('*, momicare_pemeriksaan(*), momicare_diagnosa(*)')
          .eq('id_queue', queue['id'])
          .order('created_at', ascending: false);

      return {
        'queue': queue,
        'visits': visits,
      };
    } catch (e) {
      debugPrint('[Patient MomiCare] Error fetch: $e');
      return null;
    }
  }

  // ===========================================================================
  // 5. VITASCALE IOT DEVICES & SAVED WI-FI (SUPABASE + LOCAL QUEUE FALLBACK)
  // ===========================================================================

  static const String _kPendingWifiSyncKey = 'vitascale_pending_wifi_sync_v1';
  static String _savedWifiCacheKey(String faskesCode) =>
      'vitascale_saved_wifi_cache_${faskesCode.trim().toUpperCase()}';
  static String _deviceCfgCacheKey(String faskesCode, String deviceId) =>
      'vitascale_device_cfg_${faskesCode.trim().toUpperCase()}_${deviceId.trim().toUpperCase()}';

  static bool _isValidUuid(String? value) {
    if (value == null || value.isEmpty) return false;
    return RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(value.trim());
  }

  List<Map<String, dynamic>> _readLocalJsonList(String key) {
    try {
      final raw = WebStorageHelper.getItem(key);
      if (raw == null || raw.isEmpty) return [];
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    } catch (e) {
      debugPrint('[VitaScale Wi-Fi Local] Error parse $key: $e');
    }
    return [];
  }

  void _writeLocalJsonList(String key, List<Map<String, dynamic>> items) {
    try {
      WebStorageHelper.setItem(key, jsonEncode(items));
    } catch (e) {
      debugPrint('[VitaScale Wi-Fi Local] Error write $key: $e');
    }
  }

  /// Jumlah konfigurasi Wi-Fi yang menunggu sinkronisasi ke Supabase (saat offline di AP alat)
  int getPendingWifiSyncCount() {
    return _readLocalJsonList(_kPendingWifiSyncKey).length;
  }

  /// Mengambil daftar Wi-Fi tersimpan untuk Puskesmas ini (gabungan Supabase + Cache Lokal)
  Future<List<Map<String, dynamic>>> fetchSavedWifiProfiles({
    required String faskesCode,
    String? facilityId,
  }) async {
    final normalizedCode = faskesCode.trim().isEmpty ? 'PUSKESMAS-001' : faskesCode.trim();
    final cacheKey = _savedWifiCacheKey(normalizedCode);
    final mergedBySsid = <String, Map<String, dynamic>>{};

    for (final localRow in _readLocalJsonList(cacheKey)) {
      final ssid = (localRow['ssid'] ?? '').toString();
      if (ssid.isNotEmpty) mergedBySsid[ssid] = localRow;
    }

    try {
      var query = SupabaseService.client
          .schema(schemaName)
          .from('vitascale_saved_wifi')
          .select();

      if (_isValidUuid(facilityId)) {
        query = query.or('facility_id.eq.$facilityId,faskes_code.eq.$normalizedCode');
      } else {
        query = query.eq('faskes_code', normalizedCode);
      }

      final rows = await query.order('last_connected_at', ascending: false);
      for (final row in List<Map<String, dynamic>>.from(rows)) {
        final ssid = (row['ssid'] ?? '').toString();
        if (ssid.isNotEmpty) {
          final existing = mergedBySsid[ssid];
          if (existing == null || existing['pending_sync'] != true) {
            mergedBySsid[ssid] = {...row, 'synced_cloud': true};
          }
        }
      }
      _writeLocalJsonList(cacheKey, mergedBySsid.values.toList());
    } catch (e) {
      debugPrint('[VitaScale Wi-Fi] Info fetch cloud (fallback local): $e');
    }

    final list = mergedBySsid.values.toList();
    list.sort((a, b) {
      final activeA = a['is_active'] == true ? 1 : 0;
      final activeB = b['is_active'] == true ? 1 : 0;
      if (activeA != activeB) return activeB.compareTo(activeA);
      final tsA = (a['last_connected_at'] ?? '').toString();
      final tsB = (b['last_connected_at'] ?? '').toString();
      return tsB.compareTo(tsA);
    });
    return list;
  }

  /// Mengambil profil perangkat IoT terbaru milik Puskesmas dari Supabase / Cache Lokal
  Future<Map<String, dynamic>?> fetchIotDeviceProfile({
    required String faskesCode,
    required String deviceId,
    String? facilityId,
  }) async {
    final normalizedCode = faskesCode.trim().isEmpty ? 'PUSKESMAS-001' : faskesCode.trim();
    final normalizedDev = deviceId.trim().isEmpty ? 'VTS-001' : deviceId.trim();
    final cacheKey = _deviceCfgCacheKey(normalizedCode, normalizedDev);

    try {
      var query = SupabaseService.client
          .schema(schemaName)
          .from('vitascale_iot_devices')
          .select();

      if (_isValidUuid(facilityId)) {
        query = query.or('facility_id.eq.$facilityId,faskes_code.eq.$normalizedCode');
      } else {
        query = query.eq('faskes_code', normalizedCode);
      }

      final row = await query
          .order('updated_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (row != null) {
        final map = Map<String, dynamic>.from(row);
        WebStorageHelper.setItem(cacheKey, jsonEncode(map));
        return map;
      }
    } catch (e) {
      debugPrint('[VitaScale IoT Device] Info fetch cloud (fallback local): $e');
    }

    try {
      final raw = WebStorageHelper.getItem(cacheKey);
      if (raw != null && raw.isNotEmpty) {
        return Map<String, dynamic>.from(jsonDecode(raw) as Map);
      }
    } catch (_) {}
    return null;
  }

  /// Menyimpan Wi-Fi & konfigurasi alat: langsung ke cache lokal + antrean sync,
  /// lalu otomatis upsert ke Supabase jika internet tersedia.
  Future<Map<String, dynamic>> saveWifiAndDeviceProfile({
    String? facilityId,
    required String faskesCode,
    required String deviceId,
    required String ssid,
    String? password,
    bool savePassword = true,
    bool isSecure = true,
    int? rssiDbm,
    double calFactor = 25.75,
    double tripodHeightCm = 166.0,
    String brokerHost = 'broker.hivemq.com',
    int brokerPort = 8884,
  }) async {
    final normalizedCode = faskesCode.trim().isEmpty ? 'PUSKESMAS-001' : faskesCode.trim();
    final normalizedDev = deviceId.trim().isEmpty ? 'VTS-001' : deviceId.trim();
    final cleanSsid = ssid.trim();
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final validFacilityUuid = _isValidUuid(facilityId) ? facilityId!.trim() : null;

    // 1. Update cache profil perangkat lokal
    final devicePayload = <String, dynamic>{
      'facility_id': ?validFacilityUuid,
      'faskes_code': normalizedCode,
      'device_id': normalizedDev,
      'broker_host': brokerHost,
      'broker_port': brokerPort,
      'tripod_height_cm': tripodHeightCm,
      'cal_factor': calFactor,
      'active_wifi_ssid': cleanSsid,
      'last_rssi_dbm': ?rssiDbm,
      'last_status': 'configured',
      'updated_at': nowIso,
    };
    WebStorageHelper.setItem(
      _deviceCfgCacheKey(normalizedCode, normalizedDev),
      jsonEncode(devicePayload),
    );

    // 2. Update cache daftar Wi-Fi tersimpan lokal
    final cacheKey = _savedWifiCacheKey(normalizedCode);
    final localList = _readLocalJsonList(cacheKey)
        .map((e) => {...e, 'is_active': false})
        .toList();
    localList.removeWhere((e) => (e['ssid'] ?? '') == cleanSsid);
    final wifiRecord = <String, dynamic>{
      'facility_id': ?validFacilityUuid,
      'faskes_code': normalizedCode,
      'device_id': normalizedDev,
      'ssid': cleanSsid,
      'saved_password': savePassword && password != null && password.isNotEmpty
          ? password
          : null,
      'security_type': isSecure ? 'WPA2' : 'OPEN',
      'last_rssi_dbm': ?rssiDbm,
      'is_active': true,
      'last_connected_at': nowIso,
      'pending_sync': true,
    };
    localList.insert(0, wifiRecord);
    _writeLocalJsonList(cacheKey, localList);

    // 3. Antrekan di pending sync queue (berguna saat HP masih di hotspot ESP32 tanpa internet)
    final pendingList = _readLocalJsonList(_kPendingWifiSyncKey);
    pendingList.removeWhere(
      (e) => e['faskes_code'] == normalizedCode && e['ssid'] == cleanSsid,
    );
    pendingList.add({
      'device': devicePayload,
      'wifi': Map<String, dynamic>.from(wifiRecord)..remove('pending_sync'),
      'faskes_code': normalizedCode,
      'ssid': cleanSsid,
    });
    _writeLocalJsonList(_kPendingWifiSyncKey, pendingList);

    // 4. Coba langsung sinkronkan ke Supabase (jika internet tersedia)
    final syncedCount = await syncPendingIotWifiToSupabase();
    return {
      'saved_local': true,
      'synced_cloud': syncedCount > 0 && getPendingWifiSyncCount() == 0,
      'pending_count': getPendingWifiSyncCount(),
    };
  }

  /// Mengirim seluruh antrean profil Wi-Fi & perangkat yang tertunda ke Supabase
  Future<int> syncPendingIotWifiToSupabase() async {
    final pendingList = _readLocalJsonList(_kPendingWifiSyncKey);
    if (pendingList.isEmpty) return 0;

    final remaining = <Map<String, dynamic>>[];
    int syncedCount = 0;

    for (final item in pendingList) {
      final ok = await _upsertDeviceAndWifiToSupabase(item);
      if (ok) {
        syncedCount++;
        final faskesCode = (item['faskes_code'] ?? '').toString();
        final ssid = (item['ssid'] ?? '').toString();
        if (faskesCode.isNotEmpty && ssid.isNotEmpty) {
          final cacheKey = _savedWifiCacheKey(faskesCode);
          final cached = _readLocalJsonList(cacheKey).map((e) {
            if (e['ssid'] == ssid) {
              return {...e, 'pending_sync': false, 'synced_cloud': true};
            }
            return e;
          }).toList();
          _writeLocalJsonList(cacheKey, cached);
        }
      } else {
        remaining.add(item);
      }
    }

    _writeLocalJsonList(_kPendingWifiSyncKey, remaining);
    return syncedCount;
  }

  Future<bool> _upsertDeviceAndWifiToSupabase(Map<String, dynamic> entry) async {
    try {
      final client = SupabaseService.client;
      final device = Map<String, dynamic>.from(entry['device'] as Map);
      final wifi = Map<String, dynamic>.from(entry['wifi'] as Map);
      final faskesCode = (wifi['faskes_code'] ?? 'PUSKESMAS-001').toString();

      await client
          .schema(schemaName)
          .from('vitascale_iot_devices')
          .upsert(device, onConflict: 'faskes_code,device_id');

      await client
          .schema(schemaName)
          .from('vitascale_saved_wifi')
          .update({'is_active': false})
          .eq('faskes_code', faskesCode);

      await client
          .schema(schemaName)
          .from('vitascale_saved_wifi')
          .upsert(wifi, onConflict: 'faskes_code,ssid');

      return true;
    } catch (e) {
      debugPrint('[VitaScale Wi-Fi Sync] Belum bisa sync ke Supabase (ditahan di antrean lokal): $e');
      return false;
    }
  }

  /// Menghapus jaringan Wi-Fi tersimpan ("Lupakan Jaringan")
  Future<void> deleteSavedWifi({
    required String faskesCode,
    required String ssid,
  }) async {
    final normalizedCode = faskesCode.trim().isEmpty ? 'PUSKESMAS-001' : faskesCode.trim();
    final cleanSsid = ssid.trim();

    final cacheKey = _savedWifiCacheKey(normalizedCode);
    final updatedCache = _readLocalJsonList(cacheKey)
      ..removeWhere((e) => (e['ssid'] ?? '') == cleanSsid);
    _writeLocalJsonList(cacheKey, updatedCache);

    final updatedPending = _readLocalJsonList(_kPendingWifiSyncKey)
      ..removeWhere(
        (e) => e['faskes_code'] == normalizedCode && e['ssid'] == cleanSsid,
      );
    _writeLocalJsonList(_kPendingWifiSyncKey, updatedPending);

    try {
      await SupabaseService.client
          .schema(schemaName)
          .from('vitascale_saved_wifi')
          .delete()
          .eq('faskes_code', normalizedCode)
          .eq('ssid', cleanSsid);
    } catch (e) {
      debugPrint('[VitaScale Wi-Fi] Info delete cloud: $e');
    }
  }

  static String _userMqttCfgCacheKey(String scopeKey) =>
      'vitascale_user_mqtt_cfg_${scopeKey.trim()}';

  /// Mengambil konfigurasi MQTT Puskesmas langsung berdasarkan `public.user.id`
  /// (`facilityId`) beserta verifikasi akun di `public.user` & `user_detail_public_health_center`.
  Future<Map<String, dynamic>?> fetchMqttDeviceConfigForUser({
    String? facilityId,
    String? fallbackFaskesCode,
    String? fallbackDeviceId,
  }) async {
    final cleanFacilityId = facilityId?.trim();
    final hasValidUuid = _isValidUuid(cleanFacilityId);
    final normalizedFallbackCode =
        (fallbackFaskesCode != null && fallbackFaskesCode.trim().isNotEmpty)
            ? fallbackFaskesCode.trim()
            : 'PUSKESMAS-001';
    final normalizedFallbackDevice =
        (fallbackDeviceId != null && fallbackDeviceId.trim().isNotEmpty)
            ? fallbackDeviceId.trim()
            : 'timbangan-01';
    final cacheScope = hasValidUuid ? cleanFacilityId! : normalizedFallbackCode;

    if (hasValidUuid) {
      try {
        final rpcRes = await SupabaseService.client.rpc(
          'get_puskesmas_mqtt_config',
          params: {
            'p_user_id': cleanFacilityId,
            if (fallbackDeviceId != null && fallbackDeviceId.trim().isNotEmpty)
              'p_device_id': fallbackDeviceId.trim(),
          },
        );
        if (rpcRes is Map && rpcRes.isNotEmpty) {
          final map = Map<String, dynamic>.from(rpcRes);
          _writeLocalJsonList(_userMqttCfgCacheKey(cacheScope), [map]);
          return map;
        }
      } catch (e) {
        debugPrint('[VitaScale MQTT] Info RPC get_puskesmas_mqtt_config: $e');
      }

      try {
        final client = SupabaseService.client;
        final userRows = await client
            .schema('public')
            .from('user')
            .select('id, name, role, username')
            .eq('id', cleanFacilityId!)
            .limit(1);
        final detailRows = await client
            .schema('public')
            .from('user_detail_public_health_center')
            .select('id, nama_faskes')
            .eq('id', cleanFacilityId)
            .limit(1);
        final deviceRows = await client
            .schema(schemaName)
            .from('vitascale_iot_devices')
            .select()
            .eq('facility_id', cleanFacilityId)
            .order('updated_at', ascending: false)
            .limit(1);

        final userMap = userRows.isNotEmpty
            ? Map<String, dynamic>.from(userRows.first)
            : null;
        final detailMap = detailRows.isNotEmpty
            ? Map<String, dynamic>.from(detailRows.first)
            : null;

        if (deviceRows.isNotEmpty) {
          final deviceMap = Map<String, dynamic>.from(deviceRows.first);
          if (userMap != null) {
            deviceMap['user_name'] ??= userMap['name'];
            deviceMap['user_role'] ??= userMap['role'];
          }
          if (detailMap != null) {
            deviceMap['facility_name'] ??= detailMap['nama_faskes'];
          }
          _writeLocalJsonList(_userMqttCfgCacheKey(cacheScope), [deviceMap]);
          return deviceMap;
        }

        // Jika belum ada row device di cloud tapi cache lokal user sudah ada, gunakan cache lokal user
        final localUserCfg = _readLocalJsonList(_userMqttCfgCacheKey(cacheScope));
        if (localUserCfg.isNotEmpty) {
          return {
            ...localUserCfg.first,
            if (userMap != null) 'user_name': userMap['name'],
            if (userMap != null) 'user_role': userMap['role'],
            if (detailMap != null) 'facility_name': detailMap['nama_faskes'],
          };
        }

        if (userMap != null || detailMap != null) {
          return {
            'facility_id': cleanFacilityId,
            'faskes_code': normalizedFallbackCode,
            'device_id': normalizedFallbackDevice,
            'user_name': userMap?['name'],
            'user_role': userMap?['role'],
            'facility_name': detailMap?['nama_faskes'] ?? userMap?['name'],
          };
        }
      } catch (e) {
        debugPrint('[VitaScale MQTT] Error query user MQTT config: $e');
      }
    }

    final localCfg = _readLocalJsonList(_userMqttCfgCacheKey(cacheScope));
    if (localCfg.isNotEmpty) return localCfg.first;

    final legacyCfg = _readLocalJsonList(
      _deviceCfgCacheKey(normalizedFallbackCode, normalizedFallbackDevice),
    );
    return legacyCfg.isNotEmpty ? legacyCfg.first : null;
  }

  /// Menyimpan pengaturan MQTT Puskesmas (`broker`, `port`, `ws_path`, `faskes_code`,
  /// `device_id`, `cloud_gateway_url`, `tripod_height_cm`, `use_wildcard`) ke cache lokal
  /// dan Supabase dengan `facility_id` mengarah langsung ke `public.user.id`.
  Future<bool> saveMqttDeviceConfig({
    String? facilityId,
    required String faskesCode,
    required String deviceId,
    required String brokerHost,
    required int brokerPort,
    String wsPath = '/mqtt',
    String cloudGatewayUrl = 'https://mapotechiotmqtt.vercel.app',
    required double tripodHeightCm,
    bool useWildcard = true,
    String? activeWifiSsid,
  }) async {
    final cleanFacilityId = facilityId?.trim();
    final hasValidUuid = _isValidUuid(cleanFacilityId);
    final cleanCode =
        faskesCode.trim().isEmpty ? 'PUSKESMAS-001' : faskesCode.trim();
    final cleanDevice =
        deviceId.trim().isEmpty ? 'timbangan-01' : deviceId.trim();
    final cleanBroker =
        brokerHost.trim().isEmpty ? 'broker.emqx.io' : brokerHost.trim();
    final cleanWsPath = wsPath.trim().isEmpty ? '/mqtt' : wsPath.trim();
    final cleanGateway = cloudGatewayUrl.trim().isEmpty
        ? 'https://mapotechiotmqtt.vercel.app'
        : cloudGatewayUrl.trim();
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final cacheScope = hasValidUuid ? cleanFacilityId! : cleanCode;

    final record = <String, dynamic>{
      if (hasValidUuid) 'facility_id': cleanFacilityId,
      'faskes_code': cleanCode,
      'device_id': cleanDevice,
      'broker_host': cleanBroker,
      'broker_port': brokerPort,
      'ws_path': cleanWsPath,
      'cloud_gateway_url': cleanGateway,
      'tripod_height_cm': tripodHeightCm,
      'use_wildcard': useWildcard,
      if (activeWifiSsid != null && activeWifiSsid.trim().isNotEmpty)
        'active_wifi_ssid': activeWifiSsid.trim(),
      'updated_at': nowIso,
    };

    _writeLocalJsonList(_userMqttCfgCacheKey(cacheScope), [record]);
    _writeLocalJsonList(_deviceCfgCacheKey(cleanCode, cleanDevice), [record]);

    if (hasValidUuid) {
      try {
        await SupabaseService.client.rpc(
          'save_puskesmas_mqtt_config',
          params: {
            'p_user_id': cleanFacilityId,
            'p_faskes_code': cleanCode,
            'p_device_id': cleanDevice,
            'p_broker_host': cleanBroker,
            'p_broker_port': brokerPort,
            'p_ws_path': cleanWsPath,
            'p_cloud_gateway_url': cleanGateway,
            'p_tripod_height_cm': tripodHeightCm,
            'p_use_wildcard': useWildcard,
            if (activeWifiSsid != null && activeWifiSsid.trim().isNotEmpty)
              'p_active_wifi_ssid': activeWifiSsid.trim(),
          },
        );
        return true;
      } catch (e) {
        debugPrint('[VitaScale MQTT] Info RPC save_puskesmas_mqtt_config: $e');
      }
    }

    Future<void> writeDirect(Map<String, dynamic> payload) async {
      final table =
          SupabaseService.client.schema(schemaName).from('vitascale_iot_devices');
      Map<String, dynamic>? existing;
      if (hasValidUuid) {
        existing = await table
            .select('id')
            .eq('facility_id', cleanFacilityId!)
            .eq('device_id', cleanDevice)
            .maybeSingle();
      }
      if (existing != null && existing['id'] != null) {
        await table.update(payload).eq('id', existing['id']);
      } else {
        await table.upsert(payload, onConflict: 'faskes_code,device_id');
      }
    }

    try {
      await writeDirect(record);
      return true;
    } catch (e) {
      // Kompatibilitas mundur bila kolom migrasi terbaru belum dijalankan di Supabase
      try {
        final legacyRecord = Map<String, dynamic>.from(record)
          ..remove('ws_path')
          ..remove('cloud_gateway_url')
          ..remove('use_wildcard');
        await writeDirect(legacyRecord);
        return true;
      } catch (innerError) {
        debugPrint('[VitaScale MQTT] Gagal sync ke Supabase: $innerError');
        return false;
      }
    }
  }
}
