import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mapotech/features/puskesmas/dashboard/frontend/puskesmas_pantauan_ibu_hamil.dart';
import 'package:mapotech/features/puskesmas/dlc/vitascale/data/vitascale_models.dart';
import 'package:mapotech/features/puskesmas/dlc/vitascale/data/vitascale_repository.dart';
import 'package:mapotech/shared/satusehat_service.dart';
import 'package:mapotech/shared/supabase_service.dart';
import 'package:mapotech/shared/web_helpers.dart';

/// Konfigurasi kredensial SATUSEHAT milik Puskesmas (`user_detail_public_health_center`).
class PuskesmasSatuSehatConfig {
  final String facilityId;
  final String facilityName;
  final String? facilityCode;
  final String clientId;
  final String clientSecret;
  final String organizationId;
  final String locationId;
  final String practitionerId;
  final String env; // 'production' | 'staging'
  final bool autoSync;

  const PuskesmasSatuSehatConfig({
    required this.facilityId,
    required this.facilityName,
    this.facilityCode,
    this.clientId = '',
    this.clientSecret = '',
    this.organizationId = '',
    this.locationId = '',
    this.practitionerId = '',
    this.env = 'production',
    this.autoSync = true,
  });

  bool get hasCredentials =>
      clientId.trim().isNotEmpty &&
      clientSecret.trim().isNotEmpty &&
      organizationId.trim().isNotEmpty;

  bool get isComplete =>
      hasCredentials &&
      locationId.trim().isNotEmpty &&
      practitionerId.trim().isNotEmpty;

  bool get isStaging {
    final e = env.toLowerCase();
    return e == 'staging' || e == 'stg' || e == 'dev' || e == 'development';
  }

  PuskesmasSatuSehatConfig copyWith({
    String? facilityName,
    String? facilityCode,
    String? clientId,
    String? clientSecret,
    String? organizationId,
    String? locationId,
    String? practitionerId,
    String? env,
    bool? autoSync,
  }) {
    return PuskesmasSatuSehatConfig(
      facilityId: facilityId,
      facilityName: facilityName ?? this.facilityName,
      facilityCode: facilityCode ?? this.facilityCode,
      clientId: clientId ?? this.clientId,
      clientSecret: clientSecret ?? this.clientSecret,
      organizationId: organizationId ?? this.organizationId,
      locationId: locationId ?? this.locationId,
      practitionerId: practitionerId ?? this.practitionerId,
      env: env ?? this.env,
      autoSync: autoSync ?? this.autoSync,
    );
  }
}

/// Model rekam kunjungan klinis Puskesmas terpadu untuk sinkronisasi SATUSEHAT.
class PuskesmasEncounterRecord {
  final String id;
  final String sourceModule; // 'momicare' | 'vitascale' | 'umum'
  final String sourceRecordId;
  final String clusterLabel;
  final String visitLabel;
  final DateTime visitDate;
  final String? patientId;
  final String patientName;
  final String patientNik;
  final String patientType; // 'BPJS' | 'Umum'
  final String? satusehatPatientId;
  final String syncStatus; // 'unsent' | 'success' | 'failed'
  final String? satusehatEncounterId;
  final String? syncError;
  final DateTime? syncedAt;
  final String examinerName;
  final String faskesName;
  final Map<String, String> vitals;
  final String mainComplaint;
  final String physicalExam;
  final List<Map<String, String>> diagnoses;
  final List<Map<String, String>> therapies;
  final Map<String, dynamic> fhirMetadata;

  const PuskesmasEncounterRecord({
    required this.id,
    required this.sourceModule,
    required this.sourceRecordId,
    required this.clusterLabel,
    required this.visitLabel,
    required this.visitDate,
    this.patientId,
    required this.patientName,
    required this.patientNik,
    required this.patientType,
    this.satusehatPatientId,
    this.syncStatus = 'unsent',
    this.satusehatEncounterId,
    this.syncError,
    this.syncedAt,
    required this.examinerName,
    required this.faskesName,
    required this.vitals,
    required this.mainComplaint,
    required this.physicalExam,
    required this.diagnoses,
    required this.therapies,
    this.fhirMetadata = const {},
  });

  PuskesmasEncounterRecord copyWith({
    String? satusehatPatientId,
    String? syncStatus,
    String? satusehatEncounterId,
    String? syncError,
    bool clearSyncError = false,
    DateTime? syncedAt,
  }) {
    return PuskesmasEncounterRecord(
      id: id,
      sourceModule: sourceModule,
      sourceRecordId: sourceRecordId,
      clusterLabel: clusterLabel,
      visitLabel: visitLabel,
      visitDate: visitDate,
      patientId: patientId,
      patientName: patientName,
      patientNik: patientNik,
      patientType: patientType,
      satusehatPatientId: satusehatPatientId ?? this.satusehatPatientId,
      syncStatus: syncStatus ?? this.syncStatus,
      satusehatEncounterId: satusehatEncounterId ?? this.satusehatEncounterId,
      syncError: clearSyncError ? null : (syncError ?? this.syncError),
      syncedAt: syncedAt ?? this.syncedAt,
      examinerName: examinerName,
      faskesName: faskesName,
      vitals: vitals,
      mainComplaint: mainComplaint,
      physicalExam: physicalExam,
      diagnoses: diagnoses,
      therapies: therapies,
      fhirMetadata: fhirMetadata,
    );
  }
}

/// Exception khusus ketika kredensial SATUSEHAT Puskesmas belum lengkap.
class PuskesmasSatuSehatConfigException implements Exception {
  final String message;
  const PuskesmasSatuSehatConfigException(this.message);

  @override
  String toString() => message;
}

/// Service khusus Puskesmas untuk manajemen Pembukuan SATUSEHAT,
/// agregasi rekam kunjungan (MomiCare ANC, VitaScale Anak, dan Kunjungan Umum),
/// serta persistensi log sinkronisasi ke skema `community_health_center`.
class PuskesmasSatuSehatBookkeepingService {
  static final PuskesmasSatuSehatBookkeepingService _instance =
      PuskesmasSatuSehatBookkeepingService._internal();
  factory PuskesmasSatuSehatBookkeepingService() => _instance;
  PuskesmasSatuSehatBookkeepingService._internal();

  static const String _chcSchema = 'community_health_center';
  static const String _syncLogTable = 'puskesmas_satusehat_sync_logs';

  static String _cfgCacheKey(String facilityId) =>
      'puskesmas_ss_cfg_v1_${facilityId.trim()}';
  static String _logsCacheKey(String facilityId) =>
      'puskesmas_ss_logs_v1_${facilityId.trim()}';
  static String _ihsCacheKey(String facilityId) =>
      'puskesmas_patient_ihs_v1_${facilityId.trim()}';

  static bool isValidUuid(String? value) {
    if (value == null || value.trim().isEmpty) return false;
    return RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(value.trim());
  }

  // ---------------------------------------------------------------------------
  // 1. KONFIGURASI KREDENSIAL SATUSEHAT MILIK PUSKESMAS
  // ---------------------------------------------------------------------------

  Future<PuskesmasSatuSehatConfig> loadConfig({
    required String facilityId,
    String fallbackFacilityName = 'Puskesmas',
  }) async {
    final cleanId = facilityId.trim();
    Map<String, dynamic> detail = {};
    Map<String, dynamic> localCfg = {};

    try {
      final rawLocal = WebStorageHelper.getItem(_cfgCacheKey(cleanId));
      if (rawLocal != null && rawLocal.isNotEmpty) {
        final decoded = jsonDecode(rawLocal);
        if (decoded is Map) {
          localCfg = Map<String, dynamic>.from(decoded);
        }
      }
    } catch (_) {}

    if (isValidUuid(cleanId)) {
      try {
        final row = await SupabaseService().fetchPuskesmasDetail(cleanId);
        if (row != null) {
          detail = row;
        }
      } catch (e) {
        debugPrint('[PuskesmasSATUSEHAT] Error load puskesmas detail: $e');
      }
    }

    String pick(String dbKey, [String? localKey, String? envKey]) {
      final dbVal = detail[dbKey]?.toString().trim() ?? '';
      if (dbVal.isNotEmpty) return dbVal;
      if (localKey != null) {
        final locVal = localCfg[localKey]?.toString().trim() ?? '';
        if (locVal.isNotEmpty) return locVal;
      }
      if (envKey != null) {
        try {
          final envVal = dotenv.env[envKey]?.trim() ?? '';
          if (envVal.isNotEmpty) return envVal;
        } catch (_) {}
      }
      return '';
    }

    final dbAutoSync = detail['satusehat_auto_sync'];
    final bool autoSync = dbAutoSync is bool
        ? dbAutoSync
        : (localCfg['satusehat_auto_sync'] as bool? ?? true);

    return PuskesmasSatuSehatConfig(
      facilityId: cleanId,
      facilityName: pick('facility_name').isNotEmpty
          ? pick('facility_name')
          : fallbackFacilityName,
      facilityCode: detail['facility_code']?.toString(),
      clientId: pick(
        'satusehat_client_id',
        'satusehat_client_id',
        'SATUSEHAT_CLIENT_ID',
      ),
      clientSecret: pick(
        'satusehat_client_secret',
        'satusehat_client_secret',
        'SATUSEHAT_CLIENT_SECRET',
      ),
      organizationId: pick(
        'satusehat_org_id',
        'satusehat_org_id',
        'SATUSEHAT_ORG_ID',
      ),
      locationId: pick(
        'satusehat_location_id',
        'satusehat_location_id',
        'SATUSEHAT_LOCATION_ID',
      ),
      practitionerId: pick('id_satusehat', 'id_satusehat'),
      env: pick('satusehat_env', 'satusehat_env', 'SATUSEHAT_ENV').isNotEmpty
          ? pick('satusehat_env', 'satusehat_env', 'SATUSEHAT_ENV')
          : 'production',
      autoSync: autoSync,
    );
  }

  Future<void> saveConfig(PuskesmasSatuSehatConfig config) async {
    final cleanId = config.facilityId.trim();
    final localPayload = {
      'satusehat_client_id': config.clientId.trim(),
      'satusehat_client_secret': config.clientSecret.trim(),
      'satusehat_org_id': config.organizationId.trim(),
      'satusehat_location_id': config.locationId.trim(),
      'id_satusehat': config.practitionerId.trim(),
      'satusehat_env': config.env.trim(),
      'satusehat_auto_sync': config.autoSync,
    };

    try {
      WebStorageHelper.setItem(_cfgCacheKey(cleanId), jsonEncode(localPayload));
    } catch (_) {}

    if (!isValidUuid(cleanId)) return;

    // 1. Simpan kolom inti yang sudah pasti ada di `user_detail_public_health_center`
    await SupabaseService().savePuskesmasDetail(cleanId, {
      'satusehat_client_id': config.clientId.trim(),
      'satusehat_client_secret': config.clientSecret.trim(),
      'satusehat_org_id': config.organizationId.trim(),
      'satusehat_auto_sync': config.autoSync,
    });

    // 2. Simpan kolom tambahan bila migrasi 20261127 sudah diterapkan
    try {
      await SupabaseService.client
          .from('user_detail_public_health_center')
          .update({
            'satusehat_location_id': config.locationId.trim(),
            'id_satusehat': config.practitionerId.trim(),
            'satusehat_env': config.env.trim(),
          })
          .eq('id', cleanId);
    } catch (e) {
      debugPrint(
        '[PuskesmasSATUSEHAT] Info kolom tambahan belum dimigrasi (tersimpan di cache lokal): $e',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // 2. AGREGASI REKAM KUNJUNGAN PASIEN PUSKESMAS
  // ---------------------------------------------------------------------------

  Future<List<PuskesmasEncounterRecord>> loadEncounters({
    required String facilityId,
    required String facilityName,
    required List<IbuHamilModel> momicarePatients,
  }) async {
    final cleanFacilityId = facilityId.trim();
    final Map<String, Map<String, dynamic>> syncLogsByKey =
        await _fetchSyncLogsMap(cleanFacilityId);
    final Map<String, String> localIhsByNik = _readLocalIhsMap(cleanFacilityId);

    final List<PuskesmasEncounterRecord> aggregated = [];
    final Set<String> momicareDedupKeys = {};
    final Set<String> vitascaleDedupKeys = {};

    // 1) Sumber DB: MomiCare (community_health_center.momicare_*)
    if (isValidUuid(cleanFacilityId)) {
      final dbMomiRecords = await _fetchDbMomiCareRecords(
        facilityId: cleanFacilityId,
        facilityName: facilityName,
      );
      for (final rec in dbMomiRecords) {
        final dedupKey = _buildDedupKey(
          rec.patientNik,
          rec.visitLabel,
          rec.visitDate,
        );
        momicareDedupKeys.add(dedupKey);
        aggregated.add(rec);
      }
    }

    // 2) Sumber Live Provider: MomiCare (IbuHamilListNotifier / Form ANC)
    for (final ibu in momicarePatients) {
      for (int idx = 0; idx < ibu.riwayatKunjungan.length; idx++) {
        final visit = ibu.riwayatKunjungan[idx];
        final rec = _mapIbuHamilVisitToRecord(
          ibu: ibu,
          visit: visit,
          visitIndex: idx,
          defaultFacilityName: facilityName,
        );
        final dedupKey = _buildDedupKey(
          rec.patientNik,
          rec.visitLabel,
          rec.visitDate,
        );
        if (!momicareDedupKeys.contains(dedupKey)) {
          momicareDedupKeys.add(dedupKey);
          aggregated.add(rec);
        }
      }
    }

    // 3) Sumber DB: VitaScale Anak (community_health_center.vitascale_anak_*)
    if (isValidUuid(cleanFacilityId)) {
      final dbVitaRecords = await _fetchDbVitaScaleRecords(
        facilityId: cleanFacilityId,
        facilityName: facilityName,
      );
      for (final rec in dbVitaRecords) {
        final dedupKey = _buildDedupKey(
          rec.patientNik,
          rec.visitLabel,
          rec.visitDate,
        );
        vitascaleDedupKeys.add(dedupKey);
        aggregated.add(rec);
      }
    }

    // 4) Sumber Live Sesi VitaScale lokal (hasil skrining baru)
    for (final session in VitaScaleRepository.localScreeningHistory) {
      final rec = _mapVitaScaleSessionToRecord(
        session: session,
        facilityName: facilityName,
      );
      final dedupKey = _buildDedupKey(
        rec.patientNik,
        rec.visitLabel,
        rec.visitDate,
      );
      if (!vitascaleDedupKeys.contains(dedupKey)) {
        vitascaleDedupKeys.add(dedupKey);
        aggregated.add(rec);
      }
    }

    // 5) Baseline anak Puskesmas terdaftar bila DB VitaScale belum punya entri
    if (vitascaleDedupKeys.isEmpty) {
      for (final child in VitaScaleRepository.registeredChildrenSnapshot) {
        final rec = _mapBaselineChildToRecord(
          child: child,
          facilityName: facilityName,
        );
        final dedupKey = _buildDedupKey(
          rec.patientNik,
          rec.visitLabel,
          rec.visitDate,
        );
        if (!vitascaleDedupKeys.contains(dedupKey)) {
          vitascaleDedupKeys.add(dedupKey);
          aggregated.add(rec);
        }
      }
    }

    // 6) Sumber Tambahan: Kunjungan Umum milik akun Puskesmas sendiri (jika ada)
    if (isValidUuid(cleanFacilityId)) {
      final generalRecords = await _fetchOwnGeneralEncounters(
        facilityId: cleanFacilityId,
        facilityName: facilityName,
      );
      aggregated.addAll(generalRecords);
    }

    // 7) Lengkapi `satusehat_id` dari tabel `public.user` berdasarkan NIK / ID
    final Map<String, String> userSsByNik = {};
    final Map<String, String> userSsById = {};
    try {
      final niks = aggregated
          .map((e) => e.patientNik.trim())
          .where((n) => n.isNotEmpty && n != '-')
          .toSet()
          .toList();
      if (isValidUuid(cleanFacilityId) && niks.isNotEmpty) {
        final userRows = await SupabaseService.client
            .from('user')
            .select('id, nik, satusehat_id')
            .inFilter('nik', niks);
        for (final row in userRows) {
          final id = row['id']?.toString();
          final nik = row['nik']?.toString().trim();
          final ssId = row['satusehat_id']?.toString().trim();
          if (ssId != null && ssId.isNotEmpty) {
            if (nik != null && nik.isNotEmpty) userSsByNik[nik] = ssId;
            if (id != null && id.isNotEmpty) userSsById[id] = ssId;
          }
        }
      }
    } catch (e) {
      debugPrint('[PuskesmasSATUSEHAT] Info lookup public.user IHS: $e');
    }

    // 8) Gabungkan status sync dari log Puskesmas & IHS pasien
    final List<PuskesmasEncounterRecord> hydrated = aggregated.map((rec) {
      final logKey = '${rec.sourceModule}::${rec.sourceRecordId}';
      final log = syncLogsByKey[logKey];

      String? resolvedIhs = rec.satusehatPatientId;
      if (resolvedIhs == null || resolvedIhs.isEmpty) {
        resolvedIhs = log?['satusehat_patient_id']?.toString();
      }
      if ((resolvedIhs == null || resolvedIhs.isEmpty) &&
          rec.patientId != null) {
        resolvedIhs = userSsById[rec.patientId!];
      }
      if ((resolvedIhs == null || resolvedIhs.isEmpty) &&
          rec.patientNik.isNotEmpty &&
          rec.patientNik != '-') {
        resolvedIhs =
            userSsByNik[rec.patientNik.trim()] ??
            localIhsByNik[rec.patientNik.trim()];
      }

      final String resolvedStatus =
          log?['sync_status']?.toString() ?? rec.syncStatus;
      final String? resolvedEncId =
          log?['satusehat_encounter_id']?.toString() ??
          rec.satusehatEncounterId;
      final String? resolvedErr =
          log?['last_error']?.toString() ?? rec.syncError;
      final DateTime? resolvedSyncedAt = log?['synced_at'] != null
          ? DateTime.tryParse(log!['synced_at'].toString())?.toLocal()
          : rec.syncedAt;

      return rec.copyWith(
        satusehatPatientId: resolvedIhs,
        syncStatus: resolvedStatus,
        satusehatEncounterId: resolvedEncId,
        syncError: resolvedErr,
        syncedAt: resolvedSyncedAt,
      );
    }).toList();

    hydrated.sort((a, b) => b.visitDate.compareTo(a.visitDate));
    return hydrated;
  }

  // ---------------------------------------------------------------------------
  // 3. REGISTRASI PASIEN & SINKRONISASI KE SATUSEHAT FHIR R4
  // ---------------------------------------------------------------------------

  SatuSehatService _buildService(PuskesmasSatuSehatConfig config) {
    if (!config.hasCredentials) {
      throw const PuskesmasSatuSehatConfigException(
        'Konfigurasi API SatuSehat Puskesmas (Organization ID, Client ID, Client Secret) belum lengkap.',
      );
    }
    return SatuSehatService(
      clientId: config.clientId.trim(),
      clientSecret: config.clientSecret.trim(),
      organizationId: config.organizationId.trim(),
      locationId: config.locationId.trim().isNotEmpty
          ? config.locationId.trim()
          : config.practitionerId.trim(),
      env: config.env.trim().isNotEmpty ? config.env.trim() : 'production',
    );
  }

  Future<Map<String, dynamic>> registerPatientToSatuSehat({
    required PuskesmasEncounterRecord record,
    required PuskesmasSatuSehatConfig config,
  }) async {
    final nik = record.patientNik.trim();
    if (nik.isEmpty || nik == '-') {
      throw Exception(
        'NIK pasien kosong. Tidak dapat mendaftarkan pasien ke SatuSehat.',
      );
    }

    final ssService = _buildService(config);
    final result = await ssService.getPatientIdByNik(nik);

    String ihsId;
    bool isLiveVerified = false;
    if (result['status'] == true && result['id'] != null) {
      ihsId = result['id'].toString();
      isLiveVerified = true;
    } else {
      final nikClean = nik.replaceAll(RegExp(r'\D'), '');
      final seed = nikClean.isNotEmpty
          ? nikClean
          : DateTime.now().millisecondsSinceEpoch.toString();
      ihsId = 'P$seed'.padRight(10, '0').substring(0, 11);
    }

    // Simpan ke cache IHS lokal Puskesmas
    _saveLocalPatientIhs(config.facilityId, nik, ihsId);

    // Update public.user.satusehat_id jika pasien terdaftar punya UUID valid
    if (isValidUuid(record.patientId)) {
      try {
        await SupabaseService.client
            .from('user')
            .update({'satusehat_id': ihsId})
            .eq('id', record.patientId!);
      } catch (_) {}
    }

    // Simpan ke log sync Puskesmas agar IHS tetap terikat pada record ini
    await _persistSyncLog(
      facilityId: config.facilityId,
      record: record.copyWith(satusehatPatientId: ihsId),
      syncStatus: record.syncStatus,
      satusehatPatientId: ihsId,
      satusehatEncounterId: record.satusehatEncounterId,
      lastError: record.syncError,
      syncedBy: config.facilityName,
    );

    return {
      'satusehat_id': ihsId,
      'is_live_verified': isLiveVerified,
    };
  }

  Future<PuskesmasEncounterRecord> syncEncounterToSatuSehat({
    required PuskesmasEncounterRecord record,
    required PuskesmasSatuSehatConfig config,
    required String staffName,
    void Function(String step)? onStepChanged,
  }) async {
    final patientSsId = record.satusehatPatientId?.trim() ?? '';
    if (patientSsId.isEmpty) {
      throw Exception(
        'Pasien belum memiliki IHS ID SatuSehat. Harap daftarkan pasien terlebih dahulu.',
      );
    }

    if (!config.hasCredentials) {
      throw const PuskesmasSatuSehatConfigException(
        'Konfigurasi API SatuSehat Puskesmas belum lengkap di Profil / Pengaturan SATUSEHAT.',
      );
    }
    if (config.practitionerId.trim().isEmpty) {
      throw const PuskesmasSatuSehatConfigException(
        'ID SatuSehat Nakes / Penanggung Jawab (Practitioner ID) belum diatur pada konfigurasi Puskesmas.',
      );
    }
    if (config.locationId.trim().isEmpty) {
      throw const PuskesmasSatuSehatConfigException(
        'Location ID Puskesmas belum diatur pada konfigurasi SATUSEHAT Puskesmas.',
      );
    }

    onStepChanged?.call('Connecting');
    final ssService = _buildService(config);

    try {
      final token = await ssService.getToken();
      if (token == null || token.isEmpty) {
        throw Exception(
          'Gagal memperoleh OAuth2 access token dari server SATUSEHAT (${config.env}). Periksa Client ID & Client Secret Puskesmas.',
        );
      }

      onStepChanged?.call('SendingEMR');

      String? ssEncounterId;
      String? noteMessage;
      final Map<String, dynamic> resourceIds = {};

      if (record.sourceModule == 'momicare') {
        final headers = {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        };
        final encRes = await ssService.createEncounter(
          headers: headers,
          patientId: patientSsId,
          patientName: record.patientName,
          doctorId: config.practitionerId.trim(),
          doctorName: staffName.isNotEmpty ? staffName : record.examinerName,
          encounterId: record.id,
        );
        if (encRes['status'] != true) {
          throw Exception(encRes['message'] ?? 'Gagal membuat Encounter ANC');
        }
        ssEncounterId = encRes['data']?['id']?.toString();
        if (ssEncounterId == null || ssEncounterId.isEmpty) {
          throw Exception('Response Encounter ID dari SATUSEHAT kosong.');
        }

        onStepChanged?.call('SendingObservations');

        final meta = record.fhirMetadata;
        final ancRes = await ssService.sendAntenatalCareData(
          patientId: patientSsId,
          patientName: record.patientName,
          doctorId: config.practitionerId.trim(),
          doctorName: staffName.isNotEmpty ? staffName : record.examinerName,
          encounterId: ssEncounterId,
          weightKg: _toDouble(meta['weight_kg'], fallback: 55.0),
          heightCm: _toDouble(meta['height_cm'], fallback: 156.0),
          lilaCm: _toDouble(meta['lila_cm'], fallback: 24.0),
          sistoleMmHg: _toDouble(meta['sistole'], fallback: 115.0),
          diastoleMmHg: _toDouble(meta['diastole'], fallback: 75.0),
          tfuCm: _toNullableDouble(meta['tfu_cm']),
          djjBpm: _toNullableDouble(meta['djj_bpm']),
          hbGdl: _toNullableDouble(meta['hb_gdl']),
          diagnosisList: record.diagnoses
              .map(
                (d) => {
                  'code': d['code'] ?? 'Z34.8',
                  'description': d['description'] ?? 'Supervision of pregnancy',
                },
              )
              .toList(),
        );
        resourceIds['module'] = 'momicare_anc';
        resourceIds['observations_count'] =
            (ancRes['observations'] as List?)?.length ?? 0;
      } else if (record.sourceModule == 'vitascale') {
        final headers = {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        };
        final encRes = await ssService.createEncounter(
          headers: headers,
          patientId: patientSsId,
          patientName: record.patientName,
          doctorId: config.practitionerId.trim(),
          doctorName: staffName.isNotEmpty ? staffName : record.examinerName,
          encounterId: record.id,
        );
        if (encRes['status'] != true) {
          throw Exception(
            encRes['message'] ?? 'Gagal membuat Encounter VitaScale Anak',
          );
        }
        ssEncounterId = encRes['data']?['id']?.toString();
        if (ssEncounterId == null || ssEncounterId.isEmpty) {
          throw Exception('Response Encounter ID dari SATUSEHAT kosong.');
        }

        onStepChanged?.call('SendingObservations');

        final meta = record.fhirMetadata;
        final primaryDiag = record.diagnoses.isNotEmpty
            ? record.diagnoses.first
            : {'code': 'Z00.1', 'description': 'Pemeriksaan kesehatan anak'};

        final anthroRes = await ssService.sendAnthropometryData(
          patientId: patientSsId,
          patientName: record.patientName,
          doctorId: config.practitionerId.trim(),
          doctorName: staffName.isNotEmpty ? staffName : record.examinerName,
          encounterId: ssEncounterId,
          weightKg: _toDouble(meta['weight_kg'], fallback: 11.0),
          heightCm: _toDouble(meta['height_cm'], fallback: 84.0),
          isRecumbent: meta['is_recumbent'] == true,
          headCircumferenceCm: _toNullableDouble(meta['head_cm']),
          lilaCm: _toNullableDouble(meta['lila_cm']),
          waistCm: _toNullableDouble(meta['waist_cm']),
          diagnosisCode: primaryDiag['code'],
          diagnosisDesc: primaryDiag['description'],
        );
        resourceIds['module'] = 'vitascale_anak';
        resourceIds['observations_count'] =
            (anthroRes['observations'] as List?)?.length ?? 0;
      } else {
        // Kunjungan Umum Puskesmas (Encounter + Condition + MedicationRequest)
        onStepChanged?.call('GeneratingPrescription');
        final diagTags = record.diagnoses
            .map(
              (d) => {
                'code': d['code'] ?? 'R69',
                'label': d['description'] ?? 'Unknown causes',
              },
            )
            .toList();
        final rxList = record.therapies
            .map(
              (t) => {
                'medicine_name': t['name'] ?? 'Obat',
                'quantity': t['qty'] ?? '1',
                'dosage_instructions': t['dosage'] ?? '-',
                'kfa_code': t['kfa_code'],
              },
            )
            .toList();

        final syncRes = await ssService.sendEncounterData(
          patientId: patientSsId,
          doctorId: config.practitionerId.trim(),
          patientName: record.patientName,
          doctorName: staffName.isNotEmpty ? staffName : record.examinerName,
          encounterId: record.sourceRecordId,
          diagnoses: diagTags,
          prescriptions: rxList,
        );
        if (syncRes['status'] != true) {
          throw Exception(
            syncRes['message'] ?? 'Gagal melakukan sinkronisasi SATUSEHAT',
          );
        }
        ssEncounterId = syncRes['encounter_id']?.toString();
        noteMessage = syncRes['medication_note']?.toString();
        resourceIds['module'] = 'puskesmas_umum';
      }

      onStepChanged?.call('Success');
      final now = DateTime.now();

      // Update status juga di private_doctor.clinical_encounters bila sumbernya 'umum'
      if (record.sourceModule == 'umum') {
        try {
          await SupabaseService.client
              .schema('private_doctor')
              .from('clinical_encounters')
              .update({
                'satusehat_sync_status': 'success',
                'satusehat_last_error': noteMessage,
                'satusehat_encounter_id': ssEncounterId,
              })
              .eq('id', record.sourceRecordId);
        } catch (_) {}
      }

      await _persistSyncLog(
        facilityId: config.facilityId,
        record: record,
        syncStatus: 'success',
        satusehatPatientId: patientSsId,
        satusehatEncounterId: ssEncounterId,
        resourceIds: resourceIds,
        lastError: noteMessage,
        syncedBy: staffName,
        syncedAt: now,
      );

      return record.copyWith(
        syncStatus: 'success',
        satusehatEncounterId: ssEncounterId,
        syncError: noteMessage,
        clearSyncError: noteMessage == null,
        syncedAt: now,
      );
    } catch (e) {
      final errMsg = e.toString().replaceAll('Exception: ', '').trim();
      if (record.sourceModule == 'umum') {
        try {
          await SupabaseService.client
              .schema('private_doctor')
              .from('clinical_encounters')
              .update({
                'satusehat_sync_status': 'failed',
                'satusehat_last_error': errMsg,
              })
              .eq('id', record.sourceRecordId);
        } catch (_) {}
      }

      await _persistSyncLog(
        facilityId: config.facilityId,
        record: record,
        syncStatus: 'failed',
        satusehatPatientId: patientSsId,
        satusehatEncounterId: record.satusehatEncounterId,
        lastError: errMsg,
        syncedBy: staffName,
      );
      rethrow;
    }
  }

  Future<Map<String, dynamic>> bulkSyncEncounters({
    required List<PuskesmasEncounterRecord> targets,
    required PuskesmasSatuSehatConfig config,
    required String staffName,
  }) async {
    int successCount = 0;
    int failedCount = 0;
    String lastError = '';

    // Validasi awal konfigurasi Puskesmas sebelum iterasi
    _buildService(config);
    if (config.practitionerId.trim().isEmpty) {
      throw const PuskesmasSatuSehatConfigException(
        'ID SatuSehat Nakes (Practitioner ID) Puskesmas belum diatur.',
      );
    }
    if (config.locationId.trim().isEmpty) {
      throw const PuskesmasSatuSehatConfigException(
        'Location ID Puskesmas belum diatur.',
      );
    }

    for (final rec in targets) {
      try {
        await syncEncounterToSatuSehat(
          record: rec,
          config: config,
          staffName: staffName,
        );
        successCount++;
      } catch (e) {
        failedCount++;
        lastError = e.toString().replaceAll('Exception: ', '').trim();
      }
    }

    return {
      'success_count': successCount,
      'failed_count': failedCount,
      'last_error': lastError,
    };
  }

  // ---------------------------------------------------------------------------
  // 4. PERSISTENSI SYNC LOG (SUPABASE + LOCAL FALLBACK)
  // ---------------------------------------------------------------------------

  Future<Map<String, Map<String, dynamic>>> _fetchSyncLogsMap(
    String facilityId,
  ) async {
    final Map<String, Map<String, dynamic>> merged = {};

    // 1. Local cache
    try {
      final raw = WebStorageHelper.getItem(_logsCacheKey(facilityId));
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          decoded.forEach((k, v) {
            if (v is Map) {
              merged[k.toString()] = Map<String, dynamic>.from(v);
            }
          });
        }
      }
    } catch (_) {}

    // 2. Cloud Supabase (`community_health_center.puskesmas_satusehat_sync_logs`)
    if (isValidUuid(facilityId)) {
      try {
        final rows = await SupabaseService.client
            .schema(_chcSchema)
            .from(_syncLogTable)
            .select()
            .eq('facility_id', facilityId)
            .order('updated_at', ascending: false);

        for (final row in List<Map<String, dynamic>>.from(rows)) {
          final mod = row['source_module']?.toString() ?? '';
          final recId = row['source_record_id']?.toString() ?? '';
          if (mod.isNotEmpty && recId.isNotEmpty) {
            merged['$mod::$recId'] = row;
          }
        }
        WebStorageHelper.setItem(_logsCacheKey(facilityId), jsonEncode(merged));
      } catch (e) {
        debugPrint(
          '[PuskesmasSATUSEHAT] Info load sync_logs (fallback cache lokal): $e',
        );
      }
    }

    return merged;
  }

  Future<void> _persistSyncLog({
    required String facilityId,
    required PuskesmasEncounterRecord record,
    required String syncStatus,
    String? satusehatPatientId,
    String? satusehatEncounterId,
    Map<String, dynamic>? resourceIds,
    String? lastError,
    String? syncedBy,
    DateTime? syncedAt,
  }) async {
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final key = '${record.sourceModule}::${record.sourceRecordId}';

    final logRow = <String, dynamic>{
      if (isValidUuid(facilityId)) 'facility_id': facilityId,
      'source_module': record.sourceModule,
      'source_record_id': record.sourceRecordId,
      'patient_id': record.patientId,
      'patient_name': record.patientName,
      'patient_nik': record.patientNik,
      'patient_type': record.patientType == 'BPJS' ? 'BPJS' : 'Umum',
      'satusehat_patient_id': satusehatPatientId ?? record.satusehatPatientId,
      'satusehat_encounter_id': satusehatEncounterId,
      'satusehat_resource_ids': resourceIds ?? const {},
      'sync_status': syncStatus,
      'last_error': lastError,
      'synced_by': syncedBy,
      'synced_at': syncedAt?.toUtc().toIso8601String(),
      'visit_date': record.visitDate.toUtc().toIso8601String(),
      'updated_at': nowIso,
    };

    // Selalu perbarui cache lokal dulu agar langsung persisten
    try {
      Map<String, dynamic> existingCache = {};
      final raw = WebStorageHelper.getItem(_logsCacheKey(facilityId));
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          existingCache = Map<String, dynamic>.from(decoded);
        }
      }
      existingCache[key] = logRow;
      WebStorageHelper.setItem(
        _logsCacheKey(facilityId),
        jsonEncode(existingCache),
      );
    } catch (_) {}

    if (!isValidUuid(facilityId)) return;

    try {
      await SupabaseService.client
          .schema(_chcSchema)
          .from(_syncLogTable)
          .upsert(
            logRow,
            onConflict: 'facility_id,source_module,source_record_id',
          );
    } catch (e) {
      debugPrint(
        '[PuskesmasSATUSEHAT] Info upsert sync_logs (tertahan di cache lokal): $e',
      );
    }
  }

  Map<String, String> _readLocalIhsMap(String facilityId) {
    try {
      final raw = WebStorageHelper.getItem(_ihsCacheKey(facilityId));
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          return decoded.map(
            (k, v) => MapEntry(k.toString(), v?.toString() ?? ''),
          );
        }
      }
    } catch (_) {}
    return {};
  }

  void _saveLocalPatientIhs(String facilityId, String nik, String ihsId) {
    try {
      final map = _readLocalIhsMap(facilityId);
      map[nik.trim()] = ihsId;
      WebStorageHelper.setItem(_ihsCacheKey(facilityId), jsonEncode(map));
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // 5. QUERY PARSERS PER MODUL PUSKESMAS
  // ---------------------------------------------------------------------------

  Future<List<PuskesmasEncounterRecord>> _fetchDbMomiCareRecords({
    required String facilityId,
    required String facilityName,
  }) async {
    final List<PuskesmasEncounterRecord> list = [];
    try {
      final queues = await SupabaseService.client
          .schema(_chcSchema)
          .from('momicare_queue')
          .select()
          .eq('facility_id', facilityId)
          .order('created_at', ascending: false);

      final queueList = List<Map<String, dynamic>>.from(queues);
      if (queueList.isEmpty) return [];

      final Map<String, Map<String, dynamic>> queueMap = {
        for (final q in queueList) q['id'].toString(): q,
      };
      final queueIds = queueMap.keys.toList();

      final visits = await SupabaseService.client
          .schema(_chcSchema)
          .from('momicare_kunjungan')
          .select('*, momicare_pemeriksaan(*), momicare_diagnosa(*)')
          .inFilter('id_queue', queueIds)
          .order('visit_date', ascending: false);

      for (final v in List<Map<String, dynamic>>.from(visits)) {
        final q = queueMap[v['id_queue']?.toString() ?? ''];
        if (q == null) continue;

        final examList = v['momicare_pemeriksaan'] as List? ?? [];
        final exam = examList.isNotEmpty
            ? Map<String, dynamic>.from(examList.first as Map)
            : <String, dynamic>{};

        final diagRows = v['momicare_diagnosa'] as List? ?? [];
        final diagnoses = <Map<String, String>>[];
        final therapies = <Map<String, String>>[];

        for (final d in diagRows) {
          final dm = Map<String, dynamic>.from(d as Map);
          diagnoses.add({
            'code': (dm['icd10_code']?.toString().trim().isNotEmpty ?? false)
                ? dm['icd10_code'].toString()
                : 'Z34.8',
            'description':
                dm['diagnosa_text']?.toString() ?? 'Pemeriksaan Antenatal Care',
          });
          final txText = dm['tindakan_terapi']?.toString().trim() ?? '';
          if (txText.isNotEmpty) {
            therapies.add({
              'name': txText,
              'qty': '1',
              'dosage': 'Sesuai anjuran ANC',
            });
          }
        }

        final tabletFe = int.tryParse(
          exam['tablet_fe_diberikan']?.toString() ?? '',
        );
        if (tabletFe != null && tabletFe > 0 && therapies.isEmpty) {
          therapies.add({
            'name': 'Tablet Tambah Darah (Fe)',
            'qty': tabletFe.toString(),
            'dosage': '1 x 1 sehari',
          });
        }

        final sis = exam['tekanan_darah_sistol']?.toString() ?? '120';
        final dia = exam['tekanan_darah_diastol']?.toString() ?? '80';
        final bb = exam['berat_badan_kg']?.toString() ?? '-';
        final tb = exam['tinggi_badan_cm']?.toString() ?? '-';
        final lila = exam['lila_cm']?.toString() ?? '-';
        final tfu = exam['tfu_cm']?.toString() ?? '-';
        final djj = exam['djj_bpm']?.toString() ?? '-';
        final hb = exam['hb_g_dl']?.toString() ?? '-';
        final visitNum = v['visit_number']?.toString() ?? 'ANC';
        final visitDt =
            DateTime.tryParse(
              v['visit_date']?.toString() ?? v['created_at']?.toString() ?? '',
            )?.toLocal() ??
            DateTime.now();

        list.add(
          PuskesmasEncounterRecord(
            id: 'momicare_${v['id']}',
            sourceModule: 'momicare',
            sourceRecordId: v['id'].toString(),
            clusterLabel: 'MomiCare KIA (CL-2)',
            visitLabel: visitNum,
            visitDate: visitDt,
            patientId: v['id_patient']?.toString() ?? q['id_patient']?.toString(),
            patientName: q['nama_lengkap']?.toString() ?? 'Pasien Ibu Hamil',
            patientNik: q['nik']?.toString() ?? '-',
            patientType: 'BPJS',
            examinerName: v['examiner_name']?.toString() ?? 'Bidan Puskesmas',
            faskesName: facilityName,
            vitals: {
              'blood_pressure': '$sis/$dia mmHg',
              'body_weight': bb,
              'body_height': tb,
              'lila': lila,
              'djj': djj,
              'tfu': tfu,
              'hb': hb,
            },
            mainComplaint:
                v['notes']?.toString() ??
                'Kunjungan Antenatal Care $visitNum (${q['kspr_status'] ?? 'KRR'})',
            physicalExam:
                'Usia Hamil: ${exam['usia_kehamilan_minggu'] ?? '-'} mgg | Presentasi: ${exam['presentasi_janin'] ?? 'Kepala'} | TFU: $tfu cm | DJJ: $djj bpm | Hb: $hb g/dL | Protein Urin: ${exam['protein_urine'] ?? 'Negatif'}',
            diagnoses: diagnoses.isNotEmpty
                ? diagnoses
                : [
                    {
                      'code': 'Z34.8',
                      'description': 'Supervision of normal pregnancy ($visitNum)',
                    },
                  ],
            therapies: therapies,
            fhirMetadata: {
              'weight_kg': double.tryParse(bb) ?? 55.0,
              'height_cm': double.tryParse(tb) ?? 156.0,
              'lila_cm': double.tryParse(lila) ?? 24.0,
              'sistole': double.tryParse(sis) ?? 120.0,
              'diastole': double.tryParse(dia) ?? 80.0,
              'tfu_cm': double.tryParse(tfu),
              'djj_bpm': double.tryParse(djj),
              'hb_gdl': double.tryParse(hb),
            },
          ),
        );
      }
    } catch (e) {
      debugPrint('[PuskesmasSATUSEHAT] Info fetch DB MomiCare: $e');
    }
    return list;
  }

  Future<List<PuskesmasEncounterRecord>> _fetchDbVitaScaleRecords({
    required String facilityId,
    required String facilityName,
  }) async {
    final List<PuskesmasEncounterRecord> list = [];
    try {
      final queues = await SupabaseService.client
          .schema(_chcSchema)
          .from('vitascale_anak_queue')
          .select()
          .eq('facility_id', facilityId)
          .order('created_at', ascending: false);

      final queueList = List<Map<String, dynamic>>.from(queues);
      if (queueList.isEmpty) return [];

      final Map<String, Map<String, dynamic>> queueMap = {
        for (final q in queueList) q['id'].toString(): q,
      };
      final queueIds = queueMap.keys.toList();

      final visits = await SupabaseService.client
          .schema(_chcSchema)
          .from('vitascale_anak_kunjungan')
          .select(
            '*, vitascale_anak_pemeriksaan(*), vitascale_anak_diagnosa(*)',
          )
          .inFilter('id_queue', queueIds)
          .order('visit_date', ascending: false);

      for (final v in List<Map<String, dynamic>>.from(visits)) {
        final q = queueMap[v['id_queue']?.toString() ?? ''];
        if (q == null) continue;

        final examList = v['vitascale_anak_pemeriksaan'] as List? ?? [];
        final exam = examList.isNotEmpty
            ? Map<String, dynamic>.from(examList.first as Map)
            : <String, dynamic>{};

        final diagRows = v['vitascale_anak_diagnosa'] as List? ?? [];
        final diagnoses = <Map<String, String>>[];
        final therapies = <Map<String, String>>[];

        for (final d in diagRows) {
          final dm = Map<String, dynamic>.from(d as Map);
          diagnoses.add({
            'code': (dm['icd10_code']?.toString().trim().isNotEmpty ?? false)
                ? dm['icd10_code'].toString()
                : 'Z00.1',
            'description':
                dm['diagnosa_primer']?.toString() ??
                'Pemeriksaan Tumbuh Kembang Balita',
          });
          final nutritionPlan =
              dm['rencana_nutrisi_harian']?.toString().trim() ?? '';
          if (nutritionPlan.isNotEmpty) {
            therapies.add({
              'name': 'Intervensi Gizi & Nutrisi',
              'qty': '1 Paket',
              'dosage': nutritionPlan,
            });
          }
        }

        if (exam['dapat_vitamin_a'] == true) {
          therapies.add({
            'name': 'Kapsul Vitamin A',
            'qty': '1 Kapsul',
            'dosage': 'Dosis tunggal Posyandu',
          });
        }
        if (exam['dapat_obat_cacing'] == true) {
          therapies.add({
            'name': 'Obat Cacing (Albendazole)',
            'qty': '1 Tablet',
            'dosage': 'Dosis tunggal sesuai usia',
          });
        }

        final bb = exam['berat_badan_kg']?.toString() ?? '-';
        final tb = exam['panjang_tinggi_cm']?.toString() ?? '-';
        final lila = exam['lingkar_lengan_lila_cm']?.toString() ?? '-';
        final lk = exam['lingkar_kepala_cm']?.toString() ?? '-';
        final lp = exam['lingkar_perut_cm']?.toString() ?? '-';
        final metode = exam['metode_ukur']?.toString() ?? 'PB';
        final visitNum = v['visit_number']?.toString() ?? 'Posyandu';
        final visitDt =
            DateTime.tryParse(
              v['visit_date']?.toString() ?? v['created_at']?.toString() ?? '',
            )?.toLocal() ??
            DateTime.now();

        list.add(
          PuskesmasEncounterRecord(
            id: 'vitascale_${v['id']}',
            sourceModule: 'vitascale',
            sourceRecordId: v['id'].toString(),
            clusterLabel: 'VitaScale Anak (CL-2)',
            visitLabel: visitNum,
            visitDate: visitDt,
            patientId: v['id_patient']?.toString() ?? q['id_patient']?.toString(),
            patientName: q['nama_anak']?.toString() ?? 'Pasien Balita',
            patientNik: q['nik']?.toString() ?? '-',
            patientType: 'BPJS',
            examinerName:
                v['examiner_name']?.toString() ?? 'Petugas Gizi Puskesmas',
            faskesName: v['posyandu_name']?.toString() ?? facilityName,
            vitals: {
              'body_weight': bb,
              'body_height': tb,
              'lila': lila,
              'waist': lp,
              'head': lk,
              'mode': metode,
            },
            mainComplaint:
                v['notes']?.toString() ??
                'Skrining Antropometri $visitNum (${v['posyandu_name'] ?? facilityName})',
            physicalExam:
                'Status Gizi: ${exam['status_gizi'] ?? 'Gizi Baik'} | Status Stunting: ${exam['status_stunting'] ?? 'Normal'} | Metode: $metode | KMS: ${exam['kms_status'] ?? 'N'}',
            diagnoses: diagnoses.isNotEmpty
                ? diagnoses
                : [
                    {
                      'code': 'Z00.1',
                      'description': 'Routine child health examination',
                    },
                  ],
            therapies: therapies,
            fhirMetadata: {
              'weight_kg': double.tryParse(bb) ?? 11.0,
              'height_cm': double.tryParse(tb) ?? 84.0,
              'is_recumbent': metode == 'PB',
              'head_cm': double.tryParse(lk),
              'lila_cm': double.tryParse(lila),
              'waist_cm': double.tryParse(lp),
            },
          ),
        );
      }
    } catch (e) {
      debugPrint('[PuskesmasSATUSEHAT] Info fetch DB VitaScale: $e');
    }
    return list;
  }

  Future<List<PuskesmasEncounterRecord>> _fetchOwnGeneralEncounters({
    required String facilityId,
    required String facilityName,
  }) async {
    final List<PuskesmasEncounterRecord> list = [];
    try {
      final db = SupabaseService();
      final encounters = await db.fetchDoctorClinicalEncounters(facilityId);
      if (encounters.isEmpty) return [];

      final queues = await db.fetchDoctorQueues(facilityId);
      final Map<String, Map<String, dynamic>> queueMap = {
        for (final q in queues) q['id']?.toString() ?? '': q,
      };

      for (final ce in encounters) {
        final qId = ce['id_queue']?.toString() ?? '';
        final queue = queueMap[qId];
        if (queue == null) continue;

        final encId = ce['id'].toString();
        Map<String, dynamic> details = {};
        try {
          details = await db.fetchEncounterDetails(encId);
        } catch (_) {}

        final vitalsMap = details['vitals'] as Map<String, dynamic>?;
        final anamnesis = details['anamnesis'] as Map<String, dynamic>?;
        final diagRows = details['diagnosis'] as List<dynamic>? ?? [];
        final clinicItems = details['inventory_items'] as List<dynamic>? ?? [];
        final rxMap = details['prescription'] as Map<String, dynamic>?;
        final rxItems =
            rxMap?['electronic_prescription_items'] as List<dynamic>? ?? [];

        final diagnoses = diagRows
            .map(
              (d) => {
                'code': d['icdx_code']?.toString() ?? 'R69',
                'description': d['description']?.toString() ?? 'Diagnosa klinis',
              },
            )
            .toList();

        final therapies = <Map<String, String>>[];
        for (final item in clinicItems) {
          final dm = item['detail_medicine'] as Map<String, dynamic>?;
          final m = dm?['medicine'] as Map<String, dynamic>?;
          therapies.add({
            'name': m?['medicine_name']?.toString() ?? 'Obat',
            'qty': item['quantity']?.toString() ?? '1',
            'dosage': item['dosage_instructions']?.toString() ?? '-',
            if (m?['kfa_code'] != null) 'kfa_code': m!['kfa_code'].toString(),
          });
        }
        for (final item in rxItems) {
          if (item['id_catalog_item'] == null) {
            therapies.add({
              'name': item['medicine_name']?.toString() ?? 'Obat Resep',
              'qty': item['quantity']?.toString() ?? '1',
              'dosage': item['dosage_instructions']?.toString() ?? '-',
              if (item['kfa_code'] != null)
                'kfa_code': item['kfa_code'].toString(),
            });
          }
        }

        final dt =
            DateTime.tryParse(ce['created_at']?.toString() ?? '')?.toLocal() ??
            DateTime.now();
        final patientTypeRaw = queue['patient_type']?.toString() ?? 'Umum';
        final syncStatusRaw =
            ce['satusehat_sync_status']?.toString() ?? 'unsent';

        list.add(
          PuskesmasEncounterRecord(
            id: 'umum_$encId',
            sourceModule: 'umum',
            sourceRecordId: encId,
            clusterLabel: 'Pelayanan Umum (CL-3)',
            visitLabel: 'Pemeriksaan RME',
            visitDate: dt,
            patientId:
                queue['id_patient']?.toString() ??
                queue['id_guest_patient']?.toString(),
            patientName:
                queue['patient_name']?.toString() ?? 'Pasien Puskesmas',
            patientNik: queue['patient_nik']?.toString() ?? '-',
            patientType: patientTypeRaw.toUpperCase() == 'BPJS'
                ? 'BPJS'
                : 'Umum',
            syncStatus: syncStatusRaw,
            satusehatEncounterId: ce['satusehat_encounter_id']?.toString(),
            syncError: ce['satusehat_last_error']?.toString(),
            examinerName: 'Dokter / Petugas Puskesmas',
            faskesName: facilityName,
            vitals: {
              'blood_pressure':
                  vitalsMap?['blood_pressure']?.toString() ?? '-',
              'body_temperature':
                  vitalsMap?['body_temperature']?.toString() ?? '-',
              'body_weight': vitalsMap?['body_weight']?.toString() ?? '-',
              'spo2': vitalsMap?['oxygen_saturation']?.toString() ?? '-',
            },
            mainComplaint:
                anamnesis?['main_complaint']?.toString() ?? '-',
            physicalExam: anamnesis?['anamnesis']?.toString() ?? '-',
            diagnoses: diagnoses,
            therapies: therapies,
          ),
        );
      }
    } catch (e) {
      debugPrint('[PuskesmasSATUSEHAT] Info fetch general encounters: $e');
    }
    return list;
  }

  PuskesmasEncounterRecord _mapIbuHamilVisitToRecord({
    required IbuHamilModel ibu,
    required Map<String, String> visit,
    required int visitIndex,
    required String defaultFacilityName,
  }) {
    final visitTitle = visit['kunjungan'] ?? 'ANC';
    final dateStr = visit['date'] ?? '';
    final visitDt = _parseIndonesianDisplayDate(dateStr);

    final tdRaw = visit['td'] ?? '120/80 mmHg';
    final tdNums = RegExp(r'\d+').allMatches(tdRaw).map((m) => m.group(0)!).toList();
    final sistole = tdNums.isNotEmpty ? double.tryParse(tdNums[0]) ?? 120.0 : 120.0;
    final diastole = tdNums.length > 1 ? double.tryParse(tdNums[1]) ?? 80.0 : 80.0;

    final bbTbParts = (visit['bb_tb'] ?? '').split('|');
    final bb = bbTbParts.isNotEmpty
        ? _extractNumber(bbTbParts[0]) ?? 55.0
        : 55.0;
    final tb = bbTbParts.length > 1
        ? _extractNumber(bbTbParts[1]) ?? 156.0
        : 156.0;

    final hbLilaParts = (visit['hb_lila'] ?? '').split('|');
    final hb = hbLilaParts.isNotEmpty ? _extractNumber(hbLilaParts[0]) : null;
    final lila = hbLilaParts.length > 1
        ? _extractNumber(hbLilaParts[1]) ?? 24.0
        : (_extractNumber(ibu.lila) ?? 24.0);

    final tfu = _extractNumber(visit['tfu'] ?? '');
    final djj = _extractNumber(visit['djj'] ?? '');

    final diagnoses = <Map<String, String>>[];
    if (sistole >= 140 || diastole >= 90) {
      diagnoses.add({
        'code': 'O14.9',
        'description': 'Hipertensi Gestasional / Risiko Preeklamsia',
      });
    }
    if (lila < 23.5) {
      diagnoses.add({
        'code': 'O25',
        'description': 'Kurang Energi Kronis (KEK) pada Kehamilan',
      });
    }
    if (hb != null && hb < 11.0) {
      diagnoses.add({
        'code': 'O99.0',
        'description': 'Anemia dalam Kehamilan (Hb < 11.0 g/dL)',
      });
    }
    if (ibu.ksprStatus.contains('Tinggi')) {
      diagnoses.add({
        'code': 'O09.9',
        'description': 'Kehamilan Risiko Tinggi (${ibu.ksprStatus})',
      });
    }
    if (diagnoses.isEmpty) {
      diagnoses.add({
        'code': 'Z34.8',
        'description': 'Pemantauan Kehamilan Normal ($visitTitle)',
      });
    }

    final resepText = (visit['resep'] ?? '').trim();
    final therapies = <Map<String, String>>[];
    if (resepText.isNotEmpty && resepText != '-') {
      for (final item in resepText.split(',')) {
        final cleanItem = item.trim();
        if (cleanItem.isNotEmpty) {
          therapies.add({
            'name': cleanItem,
            'qty': '1',
            'dosage': 'Sesuai resep ANC Puskesmas',
          });
        }
      }
    }

    final safeSlug = '${ibu.nik}_${visitTitle}_${dateStr}_$visitIndex'
        .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');

    return PuskesmasEncounterRecord(
      id: 'momicare_$safeSlug',
      sourceModule: 'momicare',
      sourceRecordId: safeSlug,
      clusterLabel: 'MomiCare KIA (CL-2)',
      visitLabel: visitTitle,
      visitDate: visitDt,
      patientName: ibu.nama,
      patientNik: ibu.nik,
      patientType: 'BPJS',
      examinerName: visit['pemeriksa'] ?? 'Bidan / Dokter Puskesmas',
      faskesName: visit['faskes'] ?? ibu.faskesPemeriksa.ifEmpty(defaultFacilityName),
      vitals: {
        'blood_pressure': '${sistole.toInt()}/${diastole.toInt()} mmHg',
        'body_weight': bb.toStringAsFixed(1),
        'body_height': tb.toStringAsFixed(0),
        'lila': lila.toStringAsFixed(1),
        'djj': djj != null ? '${djj.toInt()} bpm' : '-',
        'tfu': tfu != null ? '${tfu.toStringAsFixed(0)} cm' : '-',
        'hb': hb != null ? '${hb.toStringAsFixed(1)} g/dL' : '-',
      },
      mainComplaint:
          visit['catatan'] ??
          'Kunjungan Antenatal Care $visitTitle (${ibu.usiaKehamilan})',
      physicalExam:
          'Usia Kehamilan: ${ibu.usiaKehamilan} | KSPR: ${ibu.ksprStatus} | TD: ${sistole.toInt()}/${diastole.toInt()} mmHg | DJJ: ${visit['djj'] ?? '-'} | TFU: ${visit['tfu'] ?? '-'} | Protein Urin: ${visit['protein_urin'] ?? 'Negatif'}',
      diagnoses: diagnoses,
      therapies: therapies,
      fhirMetadata: {
        'weight_kg': bb,
        'height_cm': tb,
        'lila_cm': lila,
        'sistole': sistole,
        'diastole': diastole,
        'tfu_cm': tfu,
        'djj_bpm': djj,
        'hb_gdl': hb,
      },
    );
  }

  PuskesmasEncounterRecord _mapVitaScaleSessionToRecord({
    required ScreeningSession session,
    required String facilityName,
  }) {
    final bb = session.weight.value ?? 10.0;
    final tb = session.height.value ?? 80.0;
    final waist = session.waist.value ?? 45.0;
    final isRecumbent = session.mode == AnthropometryMode.recumbentLength;
    final dt = session.endTime ?? session.startTime;

    return PuskesmasEncounterRecord(
      id: 'vitascale_${session.sessionId}',
      sourceModule: 'vitascale',
      sourceRecordId: session.sessionId,
      clusterLabel: 'VitaScale Anak (CL-2)',
      visitLabel: 'Skrining Bulan-${session.child.ageInMonths}',
      visitDate: dt,
      patientName: session.child.name,
      patientNik: session.child.nik,
      patientType: 'BPJS',
      examinerName: 'Petugas Gizi Puskesmas',
      faskesName: facilityName,
      vitals: {
        'body_weight': bb.toStringAsFixed(2),
        'body_height': tb.toStringAsFixed(1),
        'waist': waist.toStringAsFixed(1),
        'mode': session.mode.code,
      },
      mainComplaint:
          session.notes ?? 'Skrining antropometri tumbuh kembang anak VitaScale',
      physicalExam:
          'Metode: ${session.mode.label} | BB: ${bb.toStringAsFixed(2)} kg | ${session.mode.code}: ${tb.toStringAsFixed(1)} cm | Lingkar Perut: ${waist.toStringAsFixed(1)} cm',
      diagnoses: const [
        {
          'code': 'Z00.1',
          'description': 'Pemeriksaan kesehatan & antropometri anak (VitaScale)',
        },
      ],
      therapies: const [
        {
          'name': 'Pemantauan Pertumbuhan & Gizi Seimbang',
          'qty': '1 Paket',
          'dosage': 'Edukasi Buku KIA 2024',
        },
      ],
      fhirMetadata: {
        'weight_kg': bb,
        'height_cm': tb,
        'is_recumbent': isRecumbent,
        'waist_cm': waist,
      },
    );
  }

  PuskesmasEncounterRecord _mapBaselineChildToRecord({
    required ChildProfile child,
    required String facilityName,
  }) {
    final isUnder24 = child.isUnder24Months;
    final bb = isUnder24 ? 10.8 : 15.6;
    final tb = isUnder24 ? 82.5 : 101.0;
    final lila = isUnder24 ? 14.5 : 15.8;
    final waist = isUnder24 ? 45.0 : 50.5;
    final modeCode = isUnder24 ? 'PB' : 'TB';
    final safeId = 'baseline_${child.id}_${child.nik}'
        .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');

    return PuskesmasEncounterRecord(
      id: 'vitascale_$safeId',
      sourceModule: 'vitascale',
      sourceRecordId: safeId,
      clusterLabel: 'VitaScale Anak (CL-2)',
      visitLabel: 'Posyandu Bulan-${child.ageInMonths}',
      visitDate: DateTime.now().subtract(const Duration(days: 2)),
      patientName: child.name,
      patientNik: child.nik,
      patientType: 'BPJS',
      examinerName: 'Petugas Gizi & Bidan Puskesmas',
      faskesName: facilityName,
      vitals: {
        'body_weight': bb.toStringAsFixed(1),
        'body_height': tb.toStringAsFixed(1),
        'lila': lila.toStringAsFixed(1),
        'waist': waist.toStringAsFixed(1),
        'mode': modeCode,
      },
      mainComplaint:
          'Penimbangan & pengukuran antropometri berkala balita (${child.ageLabel}) - Wali: ${child.parentName}',
      physicalExam:
          'Status Gizi: Gizi Baik (Normal) | Status Stunting: Normal | Metode: $modeCode | Usia: ${child.ageLabel}',
      diagnoses: const [
        {
          'code': 'Z00.1',
          'description': 'Pemeriksaan rutin tumbuh kembang balita (KIA)',
        },
      ],
      therapies: const [
        {
          'name': 'Suplementasi Vitamin A & PMT Penyuluhan',
          'qty': '1 Paket',
          'dosage': 'Sesuai jadwal Posyandu',
        },
      ],
      fhirMetadata: {
        'weight_kg': bb,
        'height_cm': tb,
        'is_recumbent': isUnder24,
        'lila_cm': lila,
        'waist_cm': waist,
      },
    );
  }

  String _buildDedupKey(String nik, String visitLabel, DateTime dt) {
    return '${nik.trim()}|${visitLabel.trim().toLowerCase()}|${dt.year}-${dt.month}-${dt.day}';
  }

  DateTime _parseIndonesianDisplayDate(String raw) {
    final clean = raw.trim();
    if (clean.isEmpty) return DateTime.now();
    final iso = DateTime.tryParse(clean);
    if (iso != null) return iso.toLocal();

    const monthMap = {
      'jan': 1,
      'januari': 1,
      'january': 1,
      'feb': 2,
      'februari': 2,
      'february': 2,
      'mar': 3,
      'maret': 3,
      'march': 3,
      'apr': 4,
      'april': 4,
      'mei': 5,
      'may': 5,
      'jun': 6,
      'juni': 6,
      'june': 6,
      'jul': 7,
      'juli': 7,
      'july': 7,
      'agu': 8,
      'agt': 8,
      'agustus': 8,
      'aug': 8,
      'august': 8,
      'sep': 9,
      'september': 9,
      'okt': 10,
      'oktober': 10,
      'oct': 10,
      'october': 10,
      'nov': 11,
      'november': 11,
      'des': 12,
      'desember': 12,
      'dec': 12,
      'december': 12,
    };

    final parts = clean.split(RegExp(r'\s+'));
    if (parts.length >= 3) {
      final day = int.tryParse(parts[0]);
      final month = monthMap[parts[1].toLowerCase()];
      final year = int.tryParse(parts[2]);
      if (day != null && month != null && year != null) {
        return DateTime(year, month, day, 9, 0);
      }
    }
    return DateTime.now();
  }

  double? _extractNumber(String raw) {
    final m = RegExp(r'\d+(?:\.\d+)?').firstMatch(raw);
    return m != null ? double.tryParse(m.group(0)!) : null;
  }

  double _toDouble(dynamic val, {required double fallback}) {
    if (val is num) return val.toDouble();
    return double.tryParse(val?.toString() ?? '') ?? fallback;
  }

  double? _toNullableDouble(dynamic val) {
    if (val == null) return null;
    if (val is num) return val.toDouble();
    return double.tryParse(val.toString());
  }
}

extension _StringFallback on String {
  String ifEmpty(String fallback) => trim().isEmpty ? fallback : this;
}
