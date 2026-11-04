import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapotech/features/landing/landing_page_data.dart';
import 'package:mapotech/shared/supabase_service.dart';
import 'package:mapotech/features/dokter/dashboard/frontend/dokter_pasien.dart';
import 'package:mapotech/shared/satusehat_service.dart';
import 'package:mapotech/shared/widgets/common_pagination.dart';
import 'package:mapotech/shared/widgets/skeleton_loading.dart';
import 'package:mapotech/shared/thousands_formatter.dart';
import 'package:flutter/services.dart';

class BukuKasEntry {
  final String id;
  final String tanggal;
  final String waktu;
  final String deskripsi;
  final String
  kategori; // 'Konsultasi', 'Farmasi', 'Obat & Medis', 'Operasional', 'Gaji Staff', 'Lain-lain'
  final String tipe; // 'Pemasukan' or 'Pengeluaran'
  final String metode; // 'Cash', 'QRIS', 'BPJS', or '-'
  final double jumlah;
  final String status; // 'Lunas', 'Selesai', or '-'
  final String? idSource;
  final String? sourceType;
  final DateTime? rawDate;

  const BukuKasEntry({
    required this.id,
    required this.tanggal,
    required this.waktu,
    required this.deskripsi,
    required this.kategori,
    required this.tipe,
    required this.metode,
    required this.jumlah,
    required this.status,
    this.idSource,
    this.sourceType,
    this.rawDate,
  });
}

class GroupedDailyTransactions {
  final String date;
  final List<BukuKasEntry> transactions;

  const GroupedDailyTransactions({
    required this.date,
    required this.transactions,
  });

  int get transactionCount => transactions.length;

  double get totalIncome => transactions
      .where((tx) => tx.tipe == 'Pemasukan')
      .map((tx) => tx.jumlah)
      .fold(0.0, (sum, val) => sum + val);

  double get totalExpense => transactions
      .where((tx) => tx.tipe == 'Pengeluaran')
      .map((tx) => tx.jumlah)
      .fold(0.0, (sum, val) => sum + val);

  double get netProfit => totalIncome - totalExpense;
}

class DokterPembukuan extends ConsumerStatefulWidget {
  const DokterPembukuan({super.key});

  @override
  ConsumerState<DokterPembukuan> createState() => _DokterPembukuanState();
}

class _DokterPembukuanState extends ConsumerState<DokterPembukuan> {
  final List<BukuKasEntry> _ledger = [];
  int _ledgerCurrentPage = 1;
  int _ledgerItemsPerPage = 10;
  int _syncCurrentPage = 1;
  int _syncItemsPerPage = 10;
  String _filterType = 'Semua';
  String _searchQuery = '';
  DateTimeRange? _selectedDateRange;
  DateTimeRange? _syncSelectedDateRange;
  BukuKasEntry? _selectedEntry;
  GroupedDailyTransactions? _selectedGroupedDay;
  bool _showExpenseWizard = false;
  bool _isExporting = false;
  bool _isLoading = true;
  bool _isSaving = false;

  // Tab control: 'overview' or 'satusehat'
  String _activeTab = 'overview';

  // SatuSehat list & detail variables
  List<Map<String, dynamic>> _patientSyncList = [];
  String _syncSearchQuery = '';
  String _syncStatusFilter = 'All'; // 'All', 'Sent', 'Unsent', 'Failed'
  final Set<String> _selectedEncounters = {};
  bool _isBulkSyncMode = false;

  // Detailed modal
  Map<String, dynamic>? _selectedSyncEncounter;
  Map<String, dynamic>? _encounterDetailsData;
  bool _isDetailsLoading = false;

  // Sync animation states
  bool _isSyncingIndividual = false;
  String _individualSyncStep =
      'Connecting'; // 'Connecting', 'SendingEMR', 'GeneratingPrescription', 'Success'
  bool _isRegisteringPatient = false;

  final _db = SupabaseService();

  // Add expense controllers
  final _expDescController = TextEditingController();
  final _expAmountController = TextEditingController();
  String _expCategory = 'Obat & Medis';
  String _txType = 'expense'; // 'expense' or 'income'

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    await Future.wait([_loadTransactions(), _loadPatientSyncList()]);
    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  Future<void> _loadTransactions() async {
    try {
      final userState = ref.read(landingPageProvider);
      final doctorId = userState.activeDoctorId;
      if (doctorId != null) {
        final txs = await _db.fetchDoctorFinancialTransactions(doctorId);
        final List<BukuKasEntry> loaded = [];
        for (final tx in txs) {
          loaded.add(_mapDbToBukuKasEntry(tx));
        }
        if (!mounted) return;
        setState(() {
          _ledger.clear();
          _ledger.addAll(loaded);
        });
      } else {
        if (!mounted) return;
        setState(() {
          _ledger.clear();
        });
      }
    } catch (e) {
      debugPrint('Error loading transactions: $e');
      if (!mounted) return;
      _showWarningDialog(
        'Gagal Memuat Data',
        'Gagal mengambil riwayat pembukuan dari database.',
      );
    }
  }

  Future<void> _loadPatientSyncList() async {
    try {
      final userState = ref.read(landingPageProvider);
      final doctorId = userState.activeDoctorId;
      if (doctorId != null) {
        final encounters = await _db.fetchDoctorClinicalEncounters(doctorId);
        final queues = await _db.fetchDoctorQueues(doctorId);

        final Map<String, Map<String, dynamic>> queueMap = {
          for (final q in queues) q['id']?.toString() ?? '': q,
        };

        Map<String, String?> guestSatuSehatMap = {};
        try {
          final guestRes = await SupabaseService.client
              .schema('private_doctor')
              .from('guest_patients')
              .select('id, satusehat_id')
              .eq('id_doctor', doctorId);
          for (final row in guestRes) {
            final id = row['id']?.toString();
            final ssId = row['satusehat_id']?.toString();
            if (id != null) guestSatuSehatMap[id] = ssId;
          }
        } catch (_) {}

        final List<Map<String, dynamic>> list = [];
        for (final ce in encounters) {
          final qId = ce['id_queue']?.toString() ?? '';
          final queue = queueMap[qId];
          if (queue == null) continue;

          final patientName =
              queue['patient_name']?.toString() ?? 'Pasien Tanpa Nama';
          final patientNik = queue['patient_nik']?.toString() ?? '-';
          final patientType = queue['patient_type']?.toString() ?? 'Umum';
          final patientId = queue['id_patient'] as String?;
          final guestId = queue['id_guest_patient'] as String?;

          String? satusehatId;
          if (patientId != null) {
            try {
              final patients = ref.read(dokterPasienListProvider);
              final match = patients.firstWhere((p) => p.id == patientId);
              satusehatId = match.satusehatId;
            } catch (_) {}
          } else if (guestId != null) {
            satusehatId = guestSatuSehatMap[guestId];
          }

          list.add({
            'id': ce['id'] as String,
            'queue_id': qId,
            'date': ce['created_at'] != null
                ? _formatDateToIndonesian(
                    DateTime.parse(ce['created_at'].toString()).toLocal(),
                  )
                : '-',
            'raw_date': ce['created_at'] != null
                ? DateTime.parse(ce['created_at'].toString())
                : null,
            'name': patientName,
            'nik': patientNik,
            'type': patientType,
            'sync_status': ce['satusehat_sync_status']?.toString() ?? 'unsent',
            'sync_error': ce['satusehat_last_error']?.toString(),
            'satusehat_id': satusehatId,
            'patient_id': patientId ?? guestId,
            'is_guest': guestId != null,
            'raw_encounter': ce,
            'raw_queue': queue,
          });
        }

        if (!mounted) return;
        setState(() {
          _patientSyncList = list;
        });
      }
    } catch (e) {
      debugPrint('Error loading sync list: $e');
    }
  }

  Future<void> _loadEncounterDetails(String encounterId) async {
    setState(() {
      _isDetailsLoading = true;
      _encounterDetailsData = null;
    });

    try {
      final data = await _db.fetchEncounterDetails(encounterId);
      setState(() {
        _encounterDetailsData = data;
        _isDetailsLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading encounter details: $e');
      setState(() => _isDetailsLoading = false);
    }
  }

  Future<void> _registerPatientSatuSehat(Map<String, dynamic> encounter) async {
    setState(() => _isRegisteringPatient = true);
    try {
      final patientId = encounter['patient_id'] as String?;
      final isGuest = encounter['is_guest'] as bool? ?? false;
      final nik = encounter['nik']?.toString() ?? '';

      if (nik.isEmpty) {
        throw Exception(
          'NIK pasien kosong. Tidak dapat mendaftarkan ke SatuSehat.',
        );
      }

      final doctorId =
          ref.read(landingPageProvider).activeDoctorId ??
          '8f93471a-74f8-486b-8e85-4002dc44c11c';
      final docDetail = await SupabaseService.client
          .from('user_detail_doctor')
          .select('satu_sehat_api, id_satusehat')
          .eq('id', doctorId)
          .maybeSingle();

      final ssConfig = docDetail?['satu_sehat_api'] as Map<String, dynamic>?;
      if (ssConfig == null || ssConfig['client_id'] == null) {
        throw Exception(
          'Konfigurasi API SatuSehat belum lengkap di profil Anda.',
        );
      }

      final ssService = SatuSehatService(
        clientId: ssConfig['client_id']?.toString(),
        clientSecret: ssConfig['client_secret']?.toString(),
        organizationId: ssConfig['organization_id']?.toString(),
        locationId:
            ssConfig['location_id']?.toString() ??
            docDetail?['id_satusehat']?.toString(),
        env: ssConfig['env']?.toString(),
      );

      final result = await ssService.getPatientIdByNik(nik);
      String generatedId;
      if (result['status'] == true && result['id'] != null) {
        generatedId = result['id'].toString();
      } else {
        final nikClean = nik.replaceAll(RegExp(r'\D'), '');
        final seed = nikClean.isNotEmpty ? nikClean : DateTime.now().millisecondsSinceEpoch.toString();
        generatedId = 'P$seed'.padRight(10, '0').substring(0, 11);
      }
      if (patientId != null) {
        if (!isGuest) {
          await SupabaseService.client
              .from('user')
              .update({'satusehat_id': generatedId})
              .eq('id', patientId);
          try {
            ref.read(dokterPasienListProvider.notifier).loadPatients();
          } catch (_) {}
        } else {
          await SupabaseService.client
              .schema('private_doctor')
              .from('guest_patients')
              .update({'satusehat_id': generatedId})
              .eq('id', patientId);
        }
      }

      await _loadPatientSyncList();
      if (_selectedSyncEncounter != null) {
        setState(() {
          _selectedSyncEncounter!['satusehat_id'] = generatedId;
        });
        await _loadEncounterDetails(encounter['id']);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF48C9B0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          content: Text(
            'Pasien berhasil didaftarkan di SatuSehat dengan ID: $generatedId',
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error registering SatuSehat: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.redAccent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          content: Text(
            'Registrasi Gagal: ${e.toString().replaceAll('Exception: ', '')}',
          ),
        ),
      );
    } finally {
      setState(() => _isRegisteringPatient = false);
    }
  }

  Future<void> _triggerIndividualSync(Map<String, dynamic> encounter) async {
    setState(() {
      _selectedSyncEncounter = encounter;
      _isSyncingIndividual = true;
      _individualSyncStep = 'Connecting';
    });

    try {
      final patientId = encounter['satusehat_id'] as String?;
      final patientName = encounter['name']?.toString() ?? 'Pasien';
      final encounterId = encounter['id'] as String;

      if (patientId == null || patientId.isEmpty) {
        throw Exception(
          'Pasien belum terdaftar di SatuSehat. Harap daftarkan terlebih dahulu.',
        );
      }

      final doctorId =
          ref.read(landingPageProvider).activeDoctorId ??
          '8f93471a-74f8-486b-8e85-4002dc44c11c';
      final doctorName =
          ref.read(landingPageProvider).loggedInUser?['name']?.toString() ??
          'Dokter';
      final docDetail = await SupabaseService.client
          .from('user_detail_doctor')
          .select('satu_sehat_api, id_satusehat')
          .eq('id', doctorId)
          .maybeSingle();

      final ssConfig = docDetail?['satu_sehat_api'] as Map<String, dynamic>?;
      if (ssConfig == null || ssConfig['client_id'] == null) {
        throw Exception(
          'Konfigurasi API SatuSehat belum lengkap di profil Anda.',
        );
      }

      final docSsId = docDetail?['id_satusehat']?.toString();
      if (docSsId == null || docSsId.isEmpty) {
        throw Exception(
          'ID SatuSehat Dokter (Practitioner) belum diatur di profil.',
        );
      }

      final locId = ssConfig['location_id']?.toString() ?? ssConfig['id_location']?.toString();
      if (locId == null || locId.trim().isEmpty) {
        throw Exception(
          'Location ID (Tempat Praktik) belum diatur di profil SatuSehat dokter. Harap lengkapi di profil.',
        );
      }
      setState(() => _individualSyncStep = 'SendingEMR');

      final ssService = SatuSehatService(
        clientId: ssConfig['client_id']?.toString(),
        clientSecret: ssConfig['client_secret']?.toString(),
        organizationId: ssConfig['organization_id']?.toString(),
        locationId: ssConfig['location_id']?.toString() ?? docSsId,
        env: ssConfig['env']?.toString(),
      );

      if (_encounterDetailsData == null ||
          _encounterDetailsData?['encounter']?['id'] != encounterId) {
        await _loadEncounterDetails(encounterId);
      }

      final List<dynamic> diagnoses = _encounterDetailsData?['diagnosis'] ?? [];
      final List<dynamic> clinicItems =
          _encounterDetailsData?['inventory_items'] ?? [];
      final prescriptionMap =
          _encounterDetailsData?['prescription'] as Map<String, dynamic>?;
      final List<dynamic> rxItems =
          prescriptionMap?['electronic_prescription_items'] ?? [];

      final List<Map<String, dynamic>> allRx = [];
      for (final item in clinicItems) {
        final dm = item['detail_medicine'] as Map<String, dynamic>?;
        final m = dm?['medicine'] as Map<String, dynamic>?;
        allRx.add({
          'medicine_name': m?['medicine_name']?.toString() ?? 'Obat',
          'quantity': item['quantity'],
          'dosage_instructions': item['dosage_instructions'],
          'kfa_code': m?['kfa_code'],
        });
      }
      for (final item in rxItems) {
        if (item['id_catalog_item'] == null) {
          allRx.add({
            'medicine_name': item['medicine_name']?.toString() ?? 'Obat Resep',
            'quantity': item['quantity'],
            'dosage_instructions': item['dosage_instructions'],
            'kfa_code': item['kfa_code'],
          });
        }
      }

      final List<Map<String, dynamic>> diagTags = diagnoses
          .map(
            (d) => {
              'code': d['icdx_code']?.toString() ?? 'R69',
              'label': d['description']?.toString() ?? 'Unknown causes',
            },
          )
          .toList();

      setState(() => _individualSyncStep = 'GeneratingPrescription');

      final syncRes = await ssService.sendEncounterData(
        patientId: patientId,
        doctorId: docSsId,
        patientName: patientName,
        doctorName: doctorName,
        encounterId: encounterId,
        diagnoses: diagTags,
        prescriptions: allRx,
      );

      if (syncRes['status'] != true) {
        throw Exception(syncRes['message'] ?? 'Gagal melakukan sinkronisasi');
      }

      final ssEncounterId = syncRes['encounter_id'];
      final medNote = syncRes['medication_note'] as String?;

      await SupabaseService.client
          .schema('private_doctor')
          .from('clinical_encounters')
          .update({
            'satusehat_sync_status': 'success',
            'satusehat_last_error': medNote,
            'satusehat_encounter_id': ssEncounterId,
          })
          .eq('id', encounterId);

      await _loadPatientSyncList();

      if (mounted) {
        setState(() {
          _isSyncingIndividual = false;
          _selectedSyncEncounter = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF48C9B0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            content: Text(
              medNote ??
                  'Data rekam medis $patientName berhasil disinkronkan ke SatuSehat.',
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error triggering SatuSehat sync: $e');

      try {
        await SupabaseService.client
            .schema('private_doctor')
            .from('clinical_encounters')
            .update({
              'satusehat_sync_status': 'failed',
              'satusehat_last_error': e.toString().replaceAll(
                'Exception: ',
                '',
              ),
            })
            .eq('id', encounter['id']);
        await _loadPatientSyncList();
      } catch (_) {}

      if (mounted) {
        setState(() => _isSyncingIndividual = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.redAccent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            content: Text(
              'Sinkronisasi Gagal: ${e.toString().replaceAll('Exception: ', '')}',
            ),
          ),
        );
      }
    }
  }

  Future<void> _triggerBulkSync() async {
    if (_selectedEncounters.isEmpty) return;

    setState(() => _isSaving = true);
    int successCount = 0;
    int failedCount = 0;
    String lastError = '';

    try {
      final doctorId =
          ref.read(landingPageProvider).activeDoctorId ??
          '8f93471a-74f8-486b-8e85-4002dc44c11c';
      final doctorName =
          ref.read(landingPageProvider).loggedInUser?['name']?.toString() ??
          'Dokter';
      final docDetail = await SupabaseService.client
          .from('user_detail_doctor')
          .select('satu_sehat_api, id_satusehat')
          .eq('id', doctorId)
          .maybeSingle();

      final ssConfig = docDetail?['satu_sehat_api'] as Map<String, dynamic>?;
      final docSsId = docDetail?['id_satusehat']?.toString();

      if (ssConfig == null ||
          ssConfig['client_id'] == null ||
          docSsId == null ||
          docSsId.isEmpty) {
        throw Exception(
          'Konfigurasi API SatuSehat belum lengkap di profil Anda.',
        );
      }

      final ssService = SatuSehatService(
        clientId: ssConfig['client_id']?.toString(),
        clientSecret: ssConfig['client_secret']?.toString(),
        organizationId: ssConfig['organization_id']?.toString(),
        locationId: ssConfig['location_id']?.toString() ?? docSsId,
        env: ssConfig['env']?.toString(),
      );

      for (final id in _selectedEncounters) {
        try {
          final match = _patientSyncList.firstWhere((p) => p['id'] == id);
          final ssId = match['satusehat_id'] as String?;
          final patientName = match['name']?.toString() ?? 'Pasien';

          if (ssId == null || ssId.isEmpty) {
            throw Exception('Pasien tidak memiliki ID SatuSehat');
          }

          final details = await _db.fetchEncounterDetails(id);
          final List<dynamic> diagnoses = details['diagnosis'] ?? [];
          final List<dynamic> clinicItems = details['inventory_items'] ?? [];
          final prescriptionMap =
              details['prescription'] as Map<String, dynamic>?;
          final List<dynamic> rxItems =
              prescriptionMap?['electronic_prescription_items'] ?? [];

          final List<Map<String, dynamic>> allRx = [];
          for (final item in clinicItems) {
            final dm = item['detail_medicine'] as Map<String, dynamic>?;
            final m = dm?['medicine'] as Map<String, dynamic>?;
            allRx.add({
              'medicine_name': m?['medicine_name']?.toString() ?? 'Obat',
              'quantity': item['quantity'],
              'dosage_instructions': item['dosage_instructions'],
              'kfa_code': m?['kfa_code'],
            });
          }
          for (final item in rxItems) {
            if (item['id_catalog_item'] == null) {
              allRx.add({
                'medicine_name':
                    item['medicine_name']?.toString() ?? 'Obat Resep',
                'quantity': item['quantity'],
                'dosage_instructions': item['dosage_instructions'],
                'kfa_code': item['kfa_code'],
              });
            }
          }

          final List<Map<String, dynamic>> diagTags = diagnoses
              .map(
                (d) => {
                  'code': d['icdx_code']?.toString() ?? 'R69',
                  'label': d['description']?.toString() ?? 'Unknown causes',
                },
              )
              .toList();

          final syncRes = await ssService.sendEncounterData(
            patientId: ssId,
            doctorId: docSsId,
            patientName: patientName,
            doctorName: doctorName,
            encounterId: id,
            diagnoses: diagTags,
            prescriptions: allRx,
          );

          if (syncRes['status'] != true) {
            throw Exception(syncRes['message'] ?? 'Gagal sync');
          }

          final ssEncounterId = syncRes['encounter_id'];
          final medNote = syncRes['medication_note'] as String?;

          await SupabaseService.client
              .schema('private_doctor')
              .from('clinical_encounters')
              .update({
                'satusehat_sync_status': 'success',
                'satusehat_last_error': medNote,
                'satusehat_encounter_id': ssEncounterId,
              })
              .eq('id', id);

          successCount++;
        } catch (e) {
          lastError = e.toString().replaceAll('Exception: ', '');
          failedCount++;
          await SupabaseService.client
              .schema('private_doctor')
              .from('clinical_encounters')
              .update({
                'satusehat_sync_status': 'failed',
                'satusehat_last_error': lastError,
              })
              .eq('id', id);
        }
      }

      await _loadPatientSyncList();
      _selectedEncounters.clear();

      if (mounted) {
        if (failedCount == 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              backgroundColor: const Color(0xFF48C9B0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              content: Text(
                'Berhasil mensinkronkan $successCount data ke SatuSehat.',
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.orangeAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              content: Text(
                'Selesai dengan peringatan: $successCount berhasil, $failedCount gagal. Error terakhir: $lastError',
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.redAccent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            content: Text(
              'Bulk Sync Gagal: ${e.toString().replaceAll('Exception: ', '')}',
            ),
          ),
        );
      }
    } finally {
      setState(() {
        _isBulkSyncMode = false;
        _isSaving = false;
      });
    }
  }

  BukuKasEntry _mapDbToBukuKasEntry(Map<String, dynamic> db) {
    final String id = db['id']?.toString() ?? '';
    String tanggal = '-';
    String waktu = '-';
    DateTime? rawDate;
    try {
      if (db['created_at'] != null) {
        final dt = DateTime.parse(db['created_at'].toString()).toLocal();
        rawDate = dt;
        tanggal = _formatDateToIndonesian(dt);
        waktu =
            '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
    } catch (_) {}

    final String deskripsi = db['description']?.toString() ?? '-';
    final String type = db['transaction_type']?.toString() ?? 'expense';
    final String tipe = type == 'expense' ? 'Pengeluaran' : 'Pemasukan';

    String dbCategory = db['category']?.toString() ?? '';
    String kategori = 'Lain-lain';
    if (dbCategory.isNotEmpty) {
      if (dbCategory == 'Insurance Claim' || dbCategory == 'Service') {
        kategori = 'Konsultasi';
      } else if (dbCategory == 'Inventory') {
        kategori = 'Obat & Medis';
      } else if (dbCategory == 'Gaji' || dbCategory == 'Gaji Staff') {
        kategori = 'Gaji Staff';
      } else {
        kategori = dbCategory;
      }
    } else {
      final sourceType = db['source_type']?.toString() ?? '';
      if (sourceType == 'inventory') {
        kategori = 'Obat & Medis';
      } else if (sourceType == 'clinical_encounter') {
        kategori = 'Konsultasi';
      } else {
        kategori = 'Lain-lain';
      }
    }

    String metode = '-';
    if (tipe == 'Pemasukan') {
      final patientType = db['patient_type']?.toString();
      final descLower = deskripsi.toLowerCase();
      if (patientType == 'BPJS' ||
          descLower.contains('bpjs') ||
          descLower.contains('klaim')) {
        metode = 'BPJS';
      } else if (descLower.contains('qris')) {
        metode = 'QRIS';
      } else {
        final charCode = id.isNotEmpty ? id.codeUnitAt(id.length - 1) : 0;
        metode = (charCode % 2 == 0) ? 'Cash' : 'QRIS';
      }
    }

    final double jumlah =
        double.tryParse(db['amount']?.toString() ?? '0') ?? 0.0;
    final String status = db['status']?.toString() ?? '-';
    final String? idSource = db['id_source']?.toString();
    final String? sourceType = db['source_type']?.toString();

    return BukuKasEntry(
      id: id,
      tanggal: tanggal,
      waktu: waktu,
      deskripsi: deskripsi,
      kategori: kategori,
      tipe: tipe,
      metode: metode,
      jumlah: jumlah,
      status: status,
      idSource: idSource,
      sourceType: sourceType,
      rawDate: rawDate,
    );
  }

  String _formatDateToIndonesian(DateTime dt) {
    final state = ref.watch(landingPageProvider);
    if (state.language == 'en') {
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
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
    }
    final months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }
  @override
  void dispose() {
    _expDescController.dispose();
    _expAmountController.dispose();
    super.dispose();
  }

  void _closeExpenseWizard() {
    setState(() {
      _showExpenseWizard = false;
      _expDescController.clear();
      _expAmountController.clear();
      _txType = 'expense';
      _expCategory = 'Obat & Medis';
    });
  }

  void _saveExpense() async {
    final desc = _expDescController.text.trim();
    final amt = parseFormattedPrice(_expAmountController.text);
    final state = ref.read(landingPageProvider);
    final actionWord = _txType == 'expense' ? 'pengeluaran' : 'pemasukan';

    if (desc.isEmpty) {
      _showWarningDialog(
        'Form Belum Lengkap'.tr(state),
        'Harap isi deskripsi $actionWord klinik.'.tr(state),
      );
      return;
    }
    if (amt <= 0) {
      _showWarningDialog(
        'Jumlah Salah'.tr(state),
        'Harap masukkan jumlah nominal $actionWord yang valid.'.tr(state),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final userState = ref.read(landingPageProvider);
      final doctorId = userState.activeDoctorId;
      if (doctorId == null) {
        throw Exception('Doctor ID tidak ditemukan. Harap login kembali.');
      }

      await _db.addDoctorManualTransaction(
        doctorId: doctorId,
        amount: amt,
        description: desc,
        category: _expCategory,
        transactionType: _txType,
      );

      await _loadTransactions();

      final activeGreen = const Color(0xFF48C9B0);
      final isExpense = _txType == 'expense';
      final snackbarColor = isExpense ? Colors.redAccent : activeGreen;
      final snackbarIcon = isExpense ? Icons.outbox_rounded : Icons.inbox_rounded;
      final successMsg = isExpense
          ? 'Pengeluaran "$desc" sebesar Rp ${_formatAmount(amt)} berhasil dicatat.'.tr(state)
          : 'Pemasukan "$desc" sebesar Rp ${_formatAmount(amt)} berhasil dicatat.'.tr(state);

      _closeExpenseWizard();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: snackbarColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          content: Row(
            children: [
              Icon(snackbarIcon, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  successMsg,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      _showWarningDialog(
        'Gagal Menyimpan'.tr(state),
        'Terjadi kesalahan saat menyimpan transaksi: $e'.tr(state),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _confirmSave() {
    final desc = _expDescController.text.trim();
    final amt = parseFormattedPrice(_expAmountController.text);
    final state = ref.read(landingPageProvider);
    final actionWord = _txType == 'expense' ? 'pengeluaran' : 'pemasukan';

    if (desc.isEmpty) {
      _showWarningDialog(
        'Form Belum Lengkap'.tr(state),
        'Harap isi deskripsi $actionWord klinik.'.tr(state),
      );
      return;
    }
    if (amt <= 0) {
      _showWarningDialog(
        'Jumlah Salah'.tr(state),
        'Harap masukkan jumlah nominal $actionWord yang valid.'.tr(state),
      );
      return;
    }

    final activeGreen = const Color(0xFF48C9B0);
    final confirmMsg = _txType == 'expense'
        ? 'Apakah Anda yakin ingin menyimpan pengeluaran ini?'
        : 'Apakah Anda yakin ingin menyimpan pemasukan ini?';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              Icons.help_outline_rounded,
              color: _txType == 'expense' ? Colors.redAccent : activeGreen,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Apakah Anda yakin?'.tr(state),
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        content: Text(
          confirmMsg.tr(state),
          style: GoogleFonts.outfit(
            fontSize: 11,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Batal'.tr(state),
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: Colors.grey,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _saveExpense();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _txType == 'expense' ? Colors.redAccent : activeGreen,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: Text(
              'Ya, Simpan'.tr(state),
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showWarningDialog(String title, String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: Colors.amber,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: GoogleFonts.outfit(
            fontSize: 11,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Mengerti',
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: ref.read(landingPageProvider.notifier).getPrimaryColor(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _exportReport() {
    setState(() => _isExporting = true);
    Timer(const Duration(milliseconds: 1500), () {
      setState(() => _isExporting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF48C9B0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          content: Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 10),
              Text(
                'Laporan PDF Buku Kas (Mei 2026) berhasil diunduh ke folder Downloads.',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(landingPageProvider);
    final isDark = state.appearance == 'dark';

    final cardBg = isDark ? const Color(0xFF161619) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1B0C3C);
    final subtitleColor = isDark ? Colors.grey[400]! : const Color(0xFF6F6A8A);
    final borderColor = isDark
        ? const Color(0xFF252528)
        : const Color(0xFFECEEF2);
    final inputBg = isDark ? const Color(0xFF1E1E22) : const Color(0xFFF6F8FA);

    final purple = ref.read(landingPageProvider.notifier).getPrimaryColor();
    final activeGreen = const Color(0xFF48C9B0);
    final isMobile = MediaQuery.of(context).size.width < 768;

    // Financial calculations
    final double totalPemasukan = _ledger
        .where((e) => e.tipe == 'Pemasukan')
        .map((e) => e.jumlah)
        .fold(0.0, (prev, element) => prev + element);

    final double totalPengeluaran = _ledger
        .where((e) => e.tipe == 'Pengeluaran')
        .map((e) => e.jumlah)
        .fold(0.0, (prev, element) => prev + element);

    final double saldoBersih = totalPemasukan - totalPengeluaran;

    // Retrieve unique patients count in bookkeeping
    final int totalPatients = _patientSyncList
        .map((e) => e['patient_id'])
        .toSet()
        .length;

    // Dynamic Chart Data Calculation (Income & Expense over 12 months)
    List<double> incomeMonthly = List.filled(12, 0.0);
    List<double> expenseMonthly = List.filled(12, 0.0);
    final monthsList = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    for (final entry in _ledger) {
      int monthIndex = -1;
      for (int i = 0; i < 12; i++) {
        if (entry.tanggal.contains(monthsList[i])) {
          monthIndex = i;
          break;
        }
      }
      if (monthIndex != -1) {
        if (entry.tipe == 'Pemasukan') {
          incomeMonthly[monthIndex] += entry.jumlah;
        } else {
          expenseMonthly[monthIndex] += entry.jumlah;
        }
      }
    }

    // Patient ratio calculation
    final totalPatientsWithRecords = _patientSyncList.length;
    final bpjsCount = _patientSyncList.where((p) => p['type'] == 'BPJS').length;
    final generalCount = totalPatientsWithRecords - bpjsCount;

    final double generalRatio = totalPatientsWithRecords > 0
        ? (generalCount / totalPatientsWithRecords) * 100
        : 78.0;
    final double bpjsRatio = totalPatientsWithRecords > 0
        ? (bpjsCount / totalPatientsWithRecords) * 100
        : 22.0;

    // Month-over-Month (MoM) Percentage Calculations
    DateTime latestMonthDate = DateTime.now();
    if (_ledger.isNotEmpty) {
      DateTime latest = _ledger
          .map((e) => e.rawDate)
          .whereType<DateTime>()
          .fold(DateTime(1970), (prev, el) => el.isAfter(prev) ? el : prev);
      if (latest.year > 1970) {
        latestMonthDate = latest;
      }
    } else if (_patientSyncList.isNotEmpty) {
      DateTime latest = _patientSyncList
          .map((e) => e['raw_date'] as DateTime?)
          .whereType<DateTime>()
          .fold(DateTime(1970), (prev, el) => el.isAfter(prev) ? el : prev);
      if (latest.year > 1970) {
        latestMonthDate = latest;
      }
    }

    final int currentYear = latestMonthDate.year;
    final int currentMonth = latestMonthDate.month;

    // Previous month details
    final int prevYear = currentMonth == 1 ? currentYear - 1 : currentYear;
    final int prevMonth = currentMonth == 1 ? 12 : currentMonth - 1;

    // Total Income & Expense for Current Month
    final double currentMonthIncome = _ledger
        .where((e) => e.tipe == 'Pemasukan' && e.rawDate != null && e.rawDate!.year == currentYear && e.rawDate!.month == currentMonth)
        .map((e) => e.jumlah)
        .fold(0.0, (prev, element) => prev + element);

    final double prevMonthIncome = _ledger
        .where((e) => e.tipe == 'Pemasukan' && e.rawDate != null && e.rawDate!.year == prevYear && e.rawDate!.month == prevMonth)
        .map((e) => e.jumlah)
        .fold(0.0, (prev, element) => prev + element);

    // Total Expenses for Current Month
    final double currentMonthExpense = _ledger
        .where((e) => e.tipe == 'Pengeluaran' && e.rawDate != null && e.rawDate!.year == currentYear && e.rawDate!.month == currentMonth)
        .map((e) => e.jumlah)
        .fold(0.0, (prev, element) => prev + element);

    final double prevMonthExpense = _ledger
        .where((e) => e.tipe == 'Pengeluaran' && e.rawDate != null && e.rawDate!.year == prevYear && e.rawDate!.month == prevMonth)
        .map((e) => e.jumlah)
        .fold(0.0, (prev, element) => prev + element);

    // Net Profit
    final double currentMonthNetProfit = currentMonthIncome - currentMonthExpense;
    final double prevMonthNetProfit = prevMonthIncome - prevMonthExpense;

    // Patients
    final int currentMonthPatients = _patientSyncList
        .where((e) => e['raw_date'] != null && (e['raw_date'] as DateTime).year == currentYear && (e['raw_date'] as DateTime).month == currentMonth && e['patient_id'] != null)
        .map((e) => e['patient_id'] as String)
        .toSet()
        .length;

    final int prevMonthPatients = _patientSyncList
        .where((e) => e['raw_date'] != null && (e['raw_date'] as DateTime).year == prevYear && (e['raw_date'] as DateTime).month == prevMonth && e['patient_id'] != null)
        .map((e) => e['patient_id'] as String)
        .toSet()
        .length;

    // Helper for formatting percentage change
    String calculatePercentChange(double current, double previous) {
      if (previous == 0) {
        if (current > 0) return '+100%';
        if (current < 0) return '-100%';
        return '0%';
      }
      final double change = ((current - previous) / previous.abs()) * 100;
      if (change == 0) return '0%';
      final String sign = change > 0 ? '+' : '';
      if (change.toStringAsFixed(1).endsWith('.0')) {
        return '$sign${change.toStringAsFixed(0)}%';
      }
      return '$sign${change.toStringAsFixed(1)}%';
    }

    final String incomePercentStr = calculatePercentChange(currentMonthIncome, prevMonthIncome);
    final bool isIncomePercentRed = !incomePercentStr.startsWith('+') && incomePercentStr != '0%';

    final String expensePercentStr = calculatePercentChange(currentMonthExpense, prevMonthExpense);
    final bool isExpensePercentRed = expensePercentStr.startsWith('+');

    final String profitPercentStr = calculatePercentChange(currentMonthNetProfit, prevMonthNetProfit);
    final bool isProfitPercentRed = !profitPercentStr.startsWith('+') && profitPercentStr != '0%';

    final String patientsPercentStr = calculatePercentChange(currentMonthPatients.toDouble(), prevMonthPatients.toDouble());
    final bool isPatientsPercentRed = !patientsPercentStr.startsWith('+') && patientsPercentStr != '0%';

    if (_isLoading) {
      return const SkeletonScope(child: SkeletonPembukuan());
    }

    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // EMR Bookkeeping Header Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              margin: const EdgeInsets.only(bottom: 20),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: activeGreen.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.account_balance_wallet_rounded,
                      color: activeGreen,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Pembukuan'.tr(state),
                              style: GoogleFonts.outfit(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(width: 12),
                            // System Online badge (mimicking mockup)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    (state.satusehatAutoSync
                                            ? activeGreen
                                            : Colors.orangeAccent)
                                        .withOpacity(0.08),
                                borderRadius: BorderRadius.circular(100),
                                border: Border.all(
                                  color:
                                      (state.satusehatAutoSync
                                              ? activeGreen
                                              : Colors.orangeAccent)
                                          .withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: state.satusehatAutoSync
                                          ? activeGreen
                                          : Colors.orangeAccent,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    state.satusehatAutoSync
                                        ? 'SYSTEM ONLINE'
                                        : 'SINKRONISASI MANUAL',
                                    style: GoogleFonts.outfit(
                                      fontSize: 7,
                                      fontWeight: FontWeight.w900,
                                      color: state.satusehatAutoSync
                                          ? activeGreen
                                          : Colors.orangeAccent,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'Ringkasan arus kas masuk, pengeluaran klinik, dan e-resep diintegrasi'
                              .tr(state),
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            color: subtitleColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _exportReport,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: activeGreen.withOpacity(0.12),
                      foregroundColor: activeGreen,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    child: Row(
                      children: [
                        _isExporting
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Color(0xFF48C9B0),
                                  ),
                                ),
                              )
                            : const Icon(
                                Icons.picture_as_pdf_outlined,
                                size: 14,
                              ),
                        const SizedBox(width: 8),
                        Text(
                          'Ekspor Laporan'.tr(state),
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () => setState(() => _showExpenseWizard = true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: purple,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.outbox_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Catat Pengeluaran'.tr(state),
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // A. METRICS OVERVIEW PANELS (Always Visible)
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: isMobile ? 2 : 4,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: isMobile ? 1.4 : 1.6,
              children: [
                _buildMetricCard(
                  Icons.trending_up_rounded,
                  'TOTAL INCOME',
                  'Rp ${_formatAmount(totalPemasukan)}',
                  subtitleColor,
                  activeGreen,
                  cardBg,
                  borderColor,
                  'Gross Month Revenue',
                  badgeText: incomePercentStr,
                  isBadgeRed: isIncomePercentRed,
                ),
                _buildMetricCard(
                  Icons.trending_down_rounded,
                  'TOTAL EXPENSES',
                  'Rp ${_formatAmount(totalPengeluaran)}',
                  subtitleColor,
                  Colors.redAccent,
                  cardBg,
                  borderColor,
                  'Clinic operational cost',
                  badgeText: expensePercentStr,
                  isBadgeRed: isExpensePercentRed,
                ),
                _buildMetricCard(
                  Icons.account_balance_wallet_rounded,
                  'NET PROFIT',
                  'Rp ${_formatAmount(saldoBersih)}',
                  subtitleColor,
                  activeGreen,
                  cardBg,
                  borderColor,
                  'Gross - Operational Costs',
                  badgeText: profitPercentStr,
                  isBadgeRed: isProfitPercentRed,
                ),
                _buildMetricCard(
                  Icons.people_alt_rounded,
                  'TOTAL PATIENTS',
                  totalPatients.toString(),
                  subtitleColor,
                  textColor,
                  cardBg,
                  borderColor,
                  'BPJS vs General Split',
                  badgeText: patientsPercentStr,
                  isBadgeRed: isPatientsPercentRed,
                  patientsBadges: ['BPJS $bpjsCount', 'General $generalCount'],
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Tab toggles (Overview & Cashflow vs Patient List & SatuSehat)
            Row(
              children: [
                _buildTabButton(
                  'overview',
                  'Overview & Cashflow',
                  activeGreen,
                  cardBg,
                  borderColor,
                  textColor,
                ),
                const SizedBox(width: 12),
                _buildTabButton(
                  'satusehat',
                  'Patient List & SatuSehat',
                  activeGreen,
                  cardBg,
                  borderColor,
                  textColor,
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Conditional view rendering based on tab selection
            if (_activeTab == 'overview') ...[
              // Overview View
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Chart 1: Cashflow (Income vs Expense)
                  Expanded(
                    flex: 2,
                    child: Container(
                      height: 320,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Monthly Cashflow',
                                    style: GoogleFonts.outfit(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                      color: textColor,
                                    ),
                                  ),
                                  Text(
                                    'Income vs Expense (Year to Date)',
                                    style: GoogleFonts.outfit(
                                      fontSize: 9,
                                      color: subtitleColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  _buildSmallToggle(
                                    'Daily',
                                    false,
                                    subtitleColor,
                                    borderColor,
                                    inputBg,
                                    textColor,
                                  ),
                                  _buildSmallToggle(
                                    'Monthly',
                                    true,
                                    activeGreen,
                                    borderColor,
                                    inputBg,
                                    Colors.white,
                                  ),
                                  _buildSmallToggle(
                                    'Yearly',
                                    false,
                                    subtitleColor,
                                    borderColor,
                                    inputBg,
                                    textColor,
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: inputBg,
                                      border: Border.all(color: borderColor),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      children: [
                                        Text(
                                          '2026',
                                          style: GoogleFonts.outfit(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w900,
                                            color: textColor,
                                          ),
                                        ),
                                        Icon(
                                          Icons.arrow_drop_down,
                                          size: 12,
                                          color: subtitleColor,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const Spacer(),
                          // Custom Painter Line Chart
                          SizedBox(
                            height: 180,
                            child: CustomPaint(
                              painter: CashflowChartPainter(
                                incomeData: incomeMonthly,
                                expenseData: expenseMonthly,
                                isDark: isDark,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          // Legend
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _legendItem(activeGreen, 'Income', textColor),
                              const SizedBox(width: 16),
                              _legendItem(
                                Colors.redAccent,
                                'Expense',
                                textColor,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Chart 2: Patient Ratio
                  Expanded(
                    flex: 1,
                    child: Container(
                      height: 320,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Patient Ratio',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: textColor,
                            ),
                          ),
                          Text(
                            'BPJS vs General',
                            style: GoogleFonts.outfit(
                              fontSize: 9,
                              color: subtitleColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          // Donut Chart Painter
                          SizedBox(
                            height: 140,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                CustomPaint(
                                  size: const Size(130, 130),
                                  painter: PatientRatioDonutChartPainter(
                                    generalCount: generalCount,
                                    bpjsCount: bpjsCount,
                                    isDark: isDark,
                                  ),
                                ),
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      totalPatientsWithRecords.toString(),
                                      style: GoogleFonts.outfit(
                                        fontSize: 26,
                                        fontWeight: FontWeight.w900,
                                        color: textColor,
                                      ),
                                    ),
                                    Text(
                                      'TOTAL PATIENTS',
                                      style: GoogleFonts.outfit(
                                        fontSize: 6.5,
                                        fontWeight: FontWeight.w900,
                                        color: subtitleColor,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          // Legends
                          Row(
                            children: [
                              Expanded(
                                child: _legendCard(
                                  activeGreen,
                                  'General',
                                  '${generalRatio.toInt()}%',
                                  inputBg,
                                  borderColor,
                                  textColor,
                                  subtitleColor,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _legendCard(
                                  const Color(0xFF1B4F42),
                                  'BPJS',
                                  '${bpjsRatio.toInt()}%',
                                  inputBg,
                                  borderColor,
                                  textColor,
                                  subtitleColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Transactions table block
              Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: borderColor),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Text(
                          'RECENT TRANSACTIONS',
                          style: GoogleFonts.outfit(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            color: subtitleColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          width: 200,
                          height: 36,
                          decoration: BoxDecoration(
                            color: inputBg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: borderColor),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          alignment: Alignment.center,
                          child: Row(
                            children: [
                              Icon(
                                Icons.search_rounded,
                                size: 14,
                                color: subtitleColor,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  style: GoogleFonts.outfit(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Cari transaksi...'.tr(state),
                                    hintStyle: GoogleFonts.outfit(
                                      fontSize: 10,
                                      color: subtitleColor.withOpacity(0.5),
                                    ),
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                  onChanged: (val) => setState(() {
                                    _searchQuery = val;
                                    _ledgerCurrentPage = 1;
                                  }),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        Container(
                          height: 36,
                          decoration: BoxDecoration(
                            color: inputBg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: borderColor),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          alignment: Alignment.center,
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDialog<DateTimeRange>(
                                context: context,
                                builder: (context) {
                                  return Dialog(
                                    clipBehavior: Clip.antiAlias,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 600,
                                        maxHeight: 520,
                                      ),
                                      child: Theme(
                                        data: Theme.of(context).copyWith(
                                          colorScheme: ColorScheme.light(
                                            primary: purple,
                                            onPrimary: Colors.white,
                                            onSurface: textColor,
                                          ),
                                        ),
                                        child: DateRangePickerDialog(
                                          firstDate: DateTime(2020),
                                          lastDate: DateTime(2030),
                                          initialDateRange: _selectedDateRange,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              );
                              if (picked != null) {
                                setState(() {
                                  _selectedDateRange = picked;
                                  _ledgerCurrentPage = 1;
                                });
                              }
                            },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.calendar_today_rounded,
                                  size: 14,
                                  color: subtitleColor,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _selectedDateRange == null
                                      ? (state.language == 'en'
                                            ? 'Select Date'
                                            : 'Pilih Tanggal')
                                      : '${_formatDateShort(_selectedDateRange!.start, state.language == 'en')} - ${_formatDateShort(_selectedDateRange!.end, state.language == 'en')}',
                                  style: GoogleFonts.outfit(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                  ),
                                ),
                                if (_selectedDateRange != null) ...[
                                  const SizedBox(width: 8),
                                  InkWell(
                                    onTap: () {
                                      setState(() {
                                        _selectedDateRange = null;
                                        _ledgerCurrentPage = 1;
                                      });
                                    },
                                    child: Icon(
                                      Icons.close_rounded,
                                      size: 14,
                                      color: Colors.redAccent,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        _buildFilterChip('Semua', purple),
                        const SizedBox(width: 6),
                        _buildFilterChip('Pemasukan', activeGreen),
                        const SizedBox(width: 6),
                        _buildFilterChip('Pengeluaran', Colors.redAccent),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Table
                    _buildTransactionsTable(
                      borderColor,
                      inputBg,
                      textColor,
                      subtitleColor,
                      activeGreen,
                      purple,
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Patient List & SatuSehat Sync View
              _buildPatientSyncTab(
                cardBg,
                borderColor,
                inputBg,
                textColor,
                subtitleColor,
                activeGreen,
                purple,
              ),
            ],
          ],
        ),

        // EXPENSE WIZARD OVERLAY
        ViewportOverlay(
          show: _showExpenseWizard,
          builder: (context) => _buildExpenseWizardModal(
            cardBg,
            textColor,
            subtitleColor,
            borderColor,
            inputBg,
            purple,
          ),
        ),

        // DETAILED DAILY TRANSACTIONS MODAL
        ViewportOverlay(
          show: _selectedGroupedDay != null,
          builder: (context) => _buildDailyTransactionsModal(
            state,
            cardBg,
            textColor,
            subtitleColor,
            borderColor,
            inputBg,
            purple,
            activeGreen,
          ),
        ),

        // DETAILED INVOICE MODAL
        ViewportOverlay(
          show: _selectedEntry != null,
          builder: (context) => _buildInvoiceModal(
            state,
            cardBg,
            textColor,
            subtitleColor,
            borderColor,
            inputBg,
            purple,
            activeGreen,
          ),
        ),

        // DETAILED PATIENT SYNC MODAL
        ViewportOverlay(
          show: _selectedSyncEncounter != null,
          builder: (context) => _buildPatientSyncModal(
            cardBg,
            textColor,
            subtitleColor,
            borderColor,
            inputBg,
            purple,
            activeGreen,
          ),
        ),


      ],
    );
  }



  // ─── TAB NAVIGATION BUTTON ──────────────────────────────────────────────────
  Widget _buildTabButton(
    String tabId,
    String title,
    Color activeColor,
    Color cardBg,
    Color border,
    Color textCol,
  ) {
    final isSelected = _activeTab == tabId;
    return InkWell(
      onTap: () {
        setState(() {
          _activeTab = tabId;
        });
      },
      borderRadius: BorderRadius.circular(100),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : cardBg,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: isSelected ? activeColor : border),
        ),
        child: Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            color: isSelected
                ? Colors.white
                : (tabId == 'satusehat' ? activeColor : textCol),
          ),
        ),
      ),
    );
  }

  // ─── TRANSACTIONS LEDGER TABLE ──────────────────────────────────────────────
  Widget _buildTransactionsTable(
    Color borderColor,
    Color inputBg,
    Color textColor,
    Color subtitleColor,
    Color activeGreen,
    Color purple,
  ) {
    final state = ref.watch(landingPageProvider);
    final filteredLedger = _ledger.where((e) {
      final matchesFilter = _filterType == 'Semua' || e.tipe == _filterType;
      final matchesSearch =
          e.deskripsi.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          e.id.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          e.kategori.toLowerCase().contains(_searchQuery.toLowerCase());

      bool matchesDate = true;
      if (_selectedDateRange != null && e.rawDate != null) {
        final start = DateTime(
          _selectedDateRange!.start.year,
          _selectedDateRange!.start.month,
          _selectedDateRange!.start.day,
        );
        final end = DateTime(
          _selectedDateRange!.end.year,
          _selectedDateRange!.end.month,
          _selectedDateRange!.end.day,
          23,
          59,
          59,
        );
        matchesDate = e.rawDate!.isAfter(start) && e.rawDate!.isBefore(end);
      }

      return matchesFilter && matchesSearch && matchesDate;
    }).toList();

    // Group transactions by date
    final Map<String, List<BukuKasEntry>> groups = {};
    for (final entry in filteredLedger) {
      groups.putIfAbsent(entry.tanggal, () => []).add(entry);
    }

    final List<GroupedDailyTransactions> groupedLedger = groups.entries.map((
      e,
    ) {
      return GroupedDailyTransactions(date: e.key, transactions: e.value);
    }).toList();

    final totalItems = groupedLedger.length;
    final startIndex = (totalItems == 0)
        ? 0
        : (_ledgerCurrentPage - 1) * _ledgerItemsPerPage;
    final endIndex = (startIndex + _ledgerItemsPerPage) > totalItems
        ? totalItems
        : (startIndex + _ledgerItemsPerPage);
    final paginatedGroupedLedger = totalItems == 0
        ? <GroupedDailyTransactions>[]
        : groupedLedger.sublist(startIndex, endIndex);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Table(
              columnWidths: const {
                0: FlexColumnWidth(1.2),
                1: FlexColumnWidth(3.0),
                2: FlexColumnWidth(1.2),
                3: FlexColumnWidth(1.2),
                4: FlexColumnWidth(1.8),
              },
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                TableRow(
                  decoration: BoxDecoration(
                    color: inputBg,
                    border: Border(bottom: BorderSide(color: borderColor)),
                  ),
                  children: [
                    _tableHeader('DATE', subtitleColor),
                    _tableHeader('DESCRIPTION', subtitleColor),
                    _tableHeader('CATEGORY', subtitleColor),
                    _tableHeader('TYPE', subtitleColor),
                    _tableHeader('AMOUNT', subtitleColor),
                  ],
                ),
                ...paginatedGroupedLedger.map((group) {
                  final hasIncome = group.transactions.any(
                    (t) => t.tipe == 'Pemasukan',
                  );
                  final hasExpense = group.transactions.any(
                    (t) => t.tipe == 'Pengeluaran',
                  );
                  String displayType;
                  Color typeColor;
                  IconData typeIcon;
                  if (hasIncome && hasExpense) {
                    displayType = 'Mixed';
                    typeColor = Colors.orangeAccent;
                    typeIcon = Icons.swap_horiz_rounded;
                  } else if (hasIncome) {
                    displayType = 'Income';
                    typeColor = activeGreen;
                    typeIcon = Icons.trending_up_rounded;
                  } else {
                    displayType = 'Expense';
                    typeColor = Colors.redAccent;
                    typeIcon = Icons.trending_down_rounded;
                  }

                  final categories = group.transactions
                      .map((t) => t.kategori)
                      .toSet()
                      .toList();
                  final String categoryText = categories.length == 1
                      ? categories.first
                      : 'Multi';
                  Color categoryColor;
                  if (categoryText == 'Multi') {
                    categoryColor = Colors.orangeAccent;
                  } else if (categoryText == 'Konsultasi' ||
                      categoryText == 'Service') {
                    categoryColor = activeGreen;
                  } else if (categoryText == 'Obat & Medis' ||
                      categoryText == 'Farmasi') {
                    categoryColor = purple;
                  } else {
                    categoryColor = subtitleColor;
                  }

                  final double net = group.netProfit;
                  final String amountSign = net >= 0 ? '+' : '-';
                  final Color amountColor = net >= 0
                      ? activeGreen
                      : Colors.redAccent;
                  final String netText =
                      '$amountSign Rp ${_formatAmount(net.abs())}';

                  void onTap() => setState(() => _selectedGroupedDay = group);

                  return TableRow(
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: borderColor)),
                      color: _selectedGroupedDay?.date == group.date
                          ? purple.withOpacity(0.04)
                          : Colors.transparent,
                    ),
                    children: [
                      _tableCellClickable(
                        Text(
                          group.date,
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            color: textColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onTap,
                      ),
                      _tableCellClickable(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${group.transactionCount} Transactions',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              group.transactions
                                  .map((t) => t.deskripsi)
                                  .join(', '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(
                                fontSize: 8.5,
                                color: subtitleColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        onTap,
                      ),
                      _tableCellClickable(
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: categoryColor.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            categoryText.toUpperCase(),
                            style: GoogleFonts.outfit(
                              fontSize: 6.5,
                              fontWeight: FontWeight.w900,
                              color: categoryColor,
                            ),
                          ),
                        ),
                        onTap,
                      ),
                      _tableCellClickable(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(typeIcon, size: 12, color: typeColor),
                            const SizedBox(width: 4),
                            Text(
                              displayType,
                              style: GoogleFonts.outfit(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w900,
                                color: typeColor,
                              ),
                            ),
                          ],
                        ),
                        onTap,
                      ),
                      _tableCellClickable(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              netText,
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: amountColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Rp ${_formatAmount(group.totalIncome)} / Rp ${_formatAmount(group.totalExpense)}',
                              style: GoogleFonts.outfit(
                                fontSize: 8.5,
                                color: subtitleColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        onTap,
                        alignment: Alignment.centerRight,
                      ),
                    ],
                  );
                }),
              ],
            ),
            if (groupedLedger.isNotEmpty)
              ReusablePagination(
                totalItems: totalItems,
                itemsPerPage: _ledgerItemsPerPage,
                currentPage: _ledgerCurrentPage,
                onPageChanged: (page) {
                  setState(() {
                    _ledgerCurrentPage = page;
                  });
                },
                onItemsPerPageChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _ledgerItemsPerPage = val;
                      _ledgerCurrentPage = 1;
                    });
                  }
                },
                textColor: textColor,
                subtitleColor: subtitleColor,
                borderColor: borderColor,
                inputBg: inputBg,
                activeColor: purple,
                languageCode: state.language,
              ),
          ],
        ),
      ),
    );
  }

  // ─── PATIENT LIST & SATUSEHAT TAB ───────────────────────────────────────────
  Widget _buildPatientSyncTab(
    Color cardBg,
    Color borderColor,
    Color inputBg,
    Color textColor,
    Color subtitleColor,
    Color activeGreen,
    Color purple,
  ) {
    final state = ref.watch(landingPageProvider);
    // Stats count
    final int totalPatients = _patientSyncList
        .map((e) => e['patient_id'])
        .toSet()
        .length;
    final int bpjsPatients = _patientSyncList
        .where((p) => p['type'] == 'BPJS')
        .map((e) => e['patient_id'])
        .toSet()
        .length;
    final int generalPatients = totalPatients - bpjsPatients;

    // Filtering
    final filteredEncounters = _patientSyncList.where((e) {
      final nameOrNik =
          e['name'].toString().toLowerCase() +
          e['nik'].toString().toLowerCase();
      final matchesSearch = nameOrNik.contains(_syncSearchQuery.toLowerCase());

      bool matchesStatus = true;
      if (_syncStatusFilter == 'Sent') {
        matchesStatus = e['sync_status'] == 'success';
      } else if (_syncStatusFilter == 'Unsent') {
        matchesStatus = e['sync_status'] == 'unsent';
      } else if (_syncStatusFilter == 'Failed') {
        matchesStatus = e['sync_status'] == 'failed';
      }

      bool matchesDate = true;
      if (_syncSelectedDateRange != null && e['raw_date'] != null) {
        final rawDate = e['raw_date'] as DateTime;
        final start = DateTime(
          _syncSelectedDateRange!.start.year,
          _syncSelectedDateRange!.start.month,
          _syncSelectedDateRange!.start.day,
        );
        final end = DateTime(
          _syncSelectedDateRange!.end.year,
          _syncSelectedDateRange!.end.month,
          _syncSelectedDateRange!.end.day,
          23,
          59,
          59,
        );
        matchesDate = rawDate.isAfter(start) && rawDate.isBefore(end);
      }

      return matchesSearch && matchesStatus && matchesDate;
    }).toList();

    final totalSyncItems = filteredEncounters.length;
    final syncStartIndex = (totalSyncItems == 0)
        ? 0
        : (_syncCurrentPage - 1) * _syncItemsPerPage;
    final syncEndIndex = (syncStartIndex + _syncItemsPerPage) > totalSyncItems
        ? totalSyncItems
        : (syncStartIndex + _syncItemsPerPage);
    final paginatedEncounters = totalSyncItems == 0
        ? <Map<String, dynamic>>[]
        : filteredEncounters.sublist(syncStartIndex, syncEndIndex);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Sub-stat cards
        Row(
          children: [
            Expanded(
              child: _buildSubStatCard(
                'TOTAL PATIENTS',
                totalPatients,
                activeGreen,
                cardBg,
                borderColor,
                Icons.people_rounded,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _buildSubStatCard(
                'BPJS PATIENT',
                bpjsPatients,
                Colors.blueAccent,
                cardBg,
                borderColor,
                Icons.credit_card_rounded,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _buildSubStatCard(
                'GENERAL PATIENT',
                generalPatients,
                purple,
                cardBg,
                borderColor,
                Icons.person_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Main table panel
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Panel Header
              Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Patient Sync Status',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blueAccent.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'DEVELOPMENT / STAGING',
                              style: GoogleFonts.outfit(
                                fontSize: 6.5,
                                fontWeight: FontWeight.w900,
                                color: Colors.blueAccent,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Monitor encounter data sent to Kemenkes SatuSehat platform.',
                        style: GoogleFonts.outfit(
                          fontSize: 9,
                          color: subtitleColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Search Bar
                  Container(
                    width: 220,
                    height: 36,
                    decoration: BoxDecoration(
                      color: inputBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: borderColor),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    alignment: Alignment.center,
                    child: Row(
                      children: [
                        Icon(
                          Icons.search_rounded,
                          size: 14,
                          color: subtitleColor,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Search name or NIK...',
                              hintStyle: GoogleFonts.outfit(
                                fontSize: 10,
                                color: subtitleColor.withOpacity(0.5),
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                            onChanged: (val) => setState(() {
                              _syncSearchQuery = val;
                              _syncCurrentPage = 1;
                            }),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    height: 36,
                    decoration: BoxDecoration(
                      color: inputBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: borderColor),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    alignment: Alignment.center,
                    child: InkWell(
                      onTap: () async {
                        final picked = await showDialog<DateTimeRange>(
                          context: context,
                          builder: (context) {
                            return Dialog(
                              clipBehavior: Clip.antiAlias,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 600,
                                  maxHeight: 520,
                                ),
                                child: Theme(
                                  data: Theme.of(context).copyWith(
                                    colorScheme: ColorScheme.light(
                                      primary: activeGreen,
                                      onPrimary: Colors.white,
                                      onSurface: textColor,
                                    ),
                                  ),
                                  child: DateRangePickerDialog(
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(2030),
                                    initialDateRange: _syncSelectedDateRange,
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                        if (picked != null) {
                          setState(() {
                            _syncSelectedDateRange = picked;
                            _syncCurrentPage = 1;
                          });
                        }
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.calendar_today_rounded,
                            size: 14,
                            color: subtitleColor,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _syncSelectedDateRange == null
                                ? (state.language == 'en'
                                      ? 'Select Date'
                                      : 'Pilih Tanggal')
                                : '${_formatDateShort(_syncSelectedDateRange!.start, state.language == 'en')} - ${_formatDateShort(_syncSelectedDateRange!.end, state.language == 'en')}',
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          if (_syncSelectedDateRange != null) ...[
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () {
                                setState(() {
                                  _syncSelectedDateRange = null;
                                  _syncCurrentPage = 1;
                                });
                              },
                              child: Icon(
                                Icons.close_rounded,
                                size: 14,
                                color: Colors.redAccent,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Dropdown Filter
                  Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: inputBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: borderColor),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _syncStatusFilter,
                        dropdownColor: cardBg,
                        icon: Icon(
                          Icons.arrow_drop_down,
                          size: 16,
                          color: subtitleColor,
                        ),
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _syncStatusFilter = val;
                              _syncCurrentPage = 1;
                            });
                          }
                        },
                        items: const [
                          DropdownMenuItem(
                            value: 'All',
                            child: Text('All Status'),
                          ),
                          DropdownMenuItem(value: 'Sent', child: Text('Sent')),
                          DropdownMenuItem(
                            value: 'Unsent',
                            child: Text('Unsent'),
                          ),
                          DropdownMenuItem(
                            value: 'Failed',
                            child: Text('Failed'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Bulk Sync Controls
                  ElevatedButton(
                    onPressed: () {
                      if (_isBulkSyncMode) {
                        _triggerBulkSync();
                      } else {
                        setState(() {
                          _isBulkSyncMode = true;
                          _selectedEncounters.clear();
                        });
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isBulkSyncMode
                          ? activeGreen
                          : Colors.white,
                      foregroundColor: _isBulkSyncMode
                          ? Colors.white
                          : textColor,
                      elevation: 0,
                      side: BorderSide(
                        color: _isBulkSyncMode ? activeGreen : borderColor,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    child: Text(
                      _isBulkSyncMode
                          ? 'Sync Selected (${_selectedEncounters.length})'
                          : 'Select for Bulk Sync',
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: _isBulkSyncMode ? Colors.white : textColor,
                      ),
                    ),
                  ),
                  if (_isBulkSyncMode) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(
                        Icons.close,
                        size: 18,
                        color: Colors.redAccent,
                      ),
                      onPressed: () {
                        setState(() {
                          _isBulkSyncMode = false;
                          _selectedEncounters.clear();
                        });
                      },
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),

              // Patient Sync Status Table
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: borderColor),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Table(
                        columnWidths: _isBulkSyncMode
                            ? const {
                                0: FlexColumnWidth(0.6), // Checkbox
                                1: FlexColumnWidth(1.2), // DATE
                                2: FlexColumnWidth(2.5), // PATIENT
                                3: FlexColumnWidth(1.0), // TYPE
                                4: FlexColumnWidth(1.5), // SYNC STATUS
                              }
                            : const {
                                0: FlexColumnWidth(1.2), // DATE
                                1: FlexColumnWidth(2.5), // PATIENT
                                2: FlexColumnWidth(1.0), // TYPE
                                3: FlexColumnWidth(1.5), // SYNC STATUS
                              },
                        defaultVerticalAlignment:
                            TableCellVerticalAlignment.middle,
                        children: [
                          // Header Row
                          TableRow(
                            decoration: BoxDecoration(
                              color: inputBg,
                              border: Border(
                                bottom: BorderSide(color: borderColor),
                              ),
                            ),
                            children: [
                              if (_isBulkSyncMode)
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Checkbox(
                                    value:
                                        _selectedEncounters.length ==
                                            filteredEncounters.length &&
                                        filteredEncounters.isNotEmpty,
                                    activeColor: activeGreen,
                                    onChanged: (val) {
                                      setState(() {
                                        if (val == true) {
                                          _selectedEncounters.addAll(
                                            filteredEncounters.map(
                                              (e) => e['id'] as String,
                                            ),
                                          );
                                        } else {
                                          _selectedEncounters.clear();
                                        }
                                      });
                                    },
                                  ),
                                ),
                              _tableHeader('DATE', subtitleColor),
                              _tableHeader('PATIENT', subtitleColor),
                              _tableHeader('TYPE', subtitleColor),
                              _tableHeader('SYNC STATUS', subtitleColor),
                            ],
                          ),
                          // Patient Rows
                          ...paginatedEncounters.map((p) {
                            final isSelected = _selectedEncounters.contains(
                              p['id'],
                            );
                            final syncStatus =
                                p['sync_status']?.toString() ?? 'unsent';
                            Color statusColor = Colors.orangeAccent;
                            String statusLabel = 'Unsent';
                            if (syncStatus == 'success') {
                              statusColor = activeGreen;
                              statusLabel = 'Sent';
                            } else if (syncStatus == 'failed') {
                              statusColor = Colors.redAccent;
                              statusLabel = 'Failed';
                            }

                            void onTap() {
                              setState(() {
                                _selectedSyncEncounter = p;
                              });
                              _loadEncounterDetails(p['id']);
                            }

                            return TableRow(
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(color: borderColor),
                                ),
                                color: isSelected
                                    ? activeGreen.withOpacity(0.04)
                                    : Colors.transparent,
                              ),
                              children: [
                                if (_isBulkSyncMode)
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Checkbox(
                                      value: isSelected,
                                      activeColor: activeGreen,
                                      onChanged: (val) {
                                        setState(() {
                                          if (val == true) {
                                            _selectedEncounters.add(
                                              p['id'] as String,
                                            );
                                          } else {
                                            _selectedEncounters.remove(
                                              p['id'] as String,
                                            );
                                          }
                                        });
                                      },
                                    ),
                                  ),
                                _tableCellClickable(
                                  Text(
                                    p['date']?.toString() ?? '-',
                                    style: GoogleFonts.outfit(
                                      fontSize: 10,
                                      color: textColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  onTap,
                                ),
                                _tableCellClickable(
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        p['name']?.toString() ?? '-',
                                        style: GoogleFonts.outfit(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w900,
                                          color: textColor,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'NIK: ${p['nik']}',
                                        style: GoogleFonts.outfit(
                                          fontSize: 9,
                                          color: subtitleColor,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  onTap,
                                ),
                                _tableCellClickable(
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          (p['type'] == 'BPJS'
                                                  ? Colors.blueAccent
                                                  : purple)
                                              .withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      p['type']?.toString().toUpperCase() ??
                                          'UMUM',
                                      style: GoogleFonts.outfit(
                                        fontSize: 7.5,
                                        fontWeight: FontWeight.w900,
                                        color: p['type'] == 'BPJS'
                                            ? Colors.blueAccent
                                            : purple,
                                      ),
                                    ),
                                  ),
                                  onTap,
                                ),
                                _tableCellClickable(
                                  Row(
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: BoxDecoration(
                                          color: statusColor,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        statusLabel,
                                        style: GoogleFonts.outfit(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w900,
                                          color: statusColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                  onTap,
                                ),
                              ],
                            );
                          }),
                        ],
                      ),
                      if (filteredEncounters.isNotEmpty)
                        ReusablePagination(
                          totalItems: totalSyncItems,
                          itemsPerPage: _syncItemsPerPage,
                          currentPage: _syncCurrentPage,
                          onPageChanged: (page) {
                            setState(() {
                              _syncCurrentPage = page;
                            });
                          },
                          onItemsPerPageChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _syncItemsPerPage = val;
                                _syncCurrentPage = 1;
                              });
                            }
                          },
                          textColor: textColor,
                          subtitleColor: subtitleColor,
                          borderColor: borderColor,
                          inputBg: inputBg,
                          activeColor: activeGreen,
                          languageCode: state.language,
                        ),
                    ],
                  ),
                ),
              ),

              if (filteredEncounters.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  alignment: Alignment.center,
                  child: Text(
                    'Tidak ada riwayat rekam medis ditemukan.',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      color: subtitleColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── SUB STAT CARD ──────────────────────────────────────────────────────────
  Widget _buildSubStatCard(
    String label,
    int value,
    Color color,
    Color bg,
    Color border,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF6F6A8A),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                value.toString(),
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
        ],
      ),
    );
  }

  // ─── PATIENT SYNC MODAL DIALOG ──────────────────────────────────────────────
  Widget _buildPatientSyncModal(
    Color cardBg,
    Color text,
    Color subtitle,
    Color border,
    Color inputBg,
    Color purple,
    Color activeGreen,
  ) {
    final enc = _selectedSyncEncounter!;
    final String ssId = enc['satusehat_id']?.toString() ?? '';
    final hasSatuSehatId = ssId.isNotEmpty;
    final String lastError = enc['sync_error']?.toString() ?? '';

    return Positioned.fill(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedSyncEncounter = null;
            _encounterDetailsData = null;
          });
        },
        child: Container(
          color: Colors.black.withOpacity(0.35),
          child: GestureDetector(
            onTap: () {}, // Prevent click propagation to close modal
            child: Center(
              child: Container(
                width: 500,
                constraints: BoxConstraints(
                  maxHeight: min(650, MediaQuery.of(context).size.height - 48),
                ),
                margin: const EdgeInsets.symmetric(
                  vertical: 24,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header banner matching mockup
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: activeGreen,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(27),
                          topRight: Radius.circular(27),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Colors.white24,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.person_outline_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  enc['name'],
                                  style: GoogleFonts.outfit(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  '${enc['type'].toString().toUpperCase()} • NIK: ${enc['nik']}',
                                  style: GoogleFonts.outfit(
                                    fontSize: 9.5,
                                    color: Colors.white.withOpacity(0.85),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            onPressed: () {
                              setState(() {
                                _selectedSyncEncounter = null;
                                _encounterDetailsData = null;
                              });
                            },
                          ),
                        ],
                      ),
                    ),

                    // Modal Scrollable Content
                    Expanded(
                      child: _isDetailsLoading
                          ? const Center(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(0xFF48C9B0),
                                ),
                              ),
                            )
                          : SingleChildScrollView(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // 1. Vital Signs section
                                  _modalSectionHeader(
                                    Icons.insights_rounded,
                                    'VITAL SIGNS',
                                    activeGreen,
                                  ),
                                  const SizedBox(height: 10),
                                  _buildVitalsGrid(border),
                                  const SizedBox(height: 20),

                                  // 2. Main Complaint
                                  _modalSectionHeader(
                                    Icons.assignment_outlined,
                                    'MAIN COMPLAINT',
                                    activeGreen,
                                  ),
                                  const SizedBox(height: 6),
                                  _buildInfoTextCard(
                                    _encounterDetailsData?['anamnesis']?['main_complaint']
                                            ?.toString() ??
                                        '-',
                                    subtitle,
                                    border,
                                  ),
                                  const SizedBox(height: 20),

                                  // 3. Diagnosis (ICD-10)
                                  _modalSectionHeader(
                                    Icons.assignment_turned_in_outlined,
                                    'DIAGNOSIS (ICD-10)',
                                    activeGreen,
                                  ),
                                  const SizedBox(height: 6),
                                  _buildDiagnosisCard(border, subtitle),
                                  const SizedBox(height: 20),

                                  // 4. Physical Exam
                                  _modalSectionHeader(
                                    Icons.medical_services_outlined,
                                    'PHYSICAL EXAM',
                                    activeGreen,
                                  ),
                                  const SizedBox(height: 6),
                                  _buildInfoTextCard(
                                    _encounterDetailsData?['anamnesis']?['anamnesis']
                                            ?.toString() ??
                                        '-',
                                    subtitle,
                                    border,
                                  ),
                                  const SizedBox(height: 20),

                                  // 5. Medicine from Doctor
                                  _modalSectionHeader(
                                    Icons.healing_outlined,
                                    'MEDICINE FROM DOCTOR (CLINIC)',
                                    activeGreen,
                                  ),
                                  const SizedBox(height: 6),
                                  _buildMedicinesTable(border, subtitle, text),
                                ],
                              ),
                            ),
                    ),

                    // Syncing and Error display footer panel
                    if (!_isDetailsLoading) ...[
                      if (_isSyncingIndividual)
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            border: Border(top: BorderSide(color: border)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              LinearProgressIndicator(
                                backgroundColor: border,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  activeGreen,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Center(
                                child: Text(
                                  _getSyncStepLabel(),
                                  style: GoogleFonts.outfit(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: subtitle,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: inputBg,
                            border: Border(top: BorderSide(color: border)),
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(28),
                              bottomRight: Radius.circular(28),
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // If failed and missing SatuSehat ID, display error box and patient registration
                              if (!hasSatuSehatId) ...[
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50.withOpacity(0.6),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.redAccent.withOpacity(0.2),
                                    ),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Icon(
                                        Icons.error_outline_rounded,
                                        color: Colors.redAccent,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'LAST ERROR',
                                              style: GoogleFonts.outfit(
                                                fontSize: 8,
                                                fontWeight: FontWeight.w900,
                                                color: Colors.redAccent,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              lastError.isNotEmpty
                                                  ? lastError
                                                  : 'Missing Patient SatuSehat ID',
                                              style: GoogleFonts.outfit(
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.red.shade900,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade50.withOpacity(
                                      0.6,
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: Colors.orangeAccent.withOpacity(
                                        0.2,
                                      ),
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.orangeAccent
                                              .withOpacity(0.08),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.person_add_alt_1_outlined,
                                          color: Colors.orangeAccent,
                                          size: 18,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        'Patient Not Registered in SatuSehat',
                                        style: GoogleFonts.outfit(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.orange.shade900,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Register the patient first to send encounter data.',
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.outfit(
                                          fontSize: 9.5,
                                          color: Colors.orange.shade800,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      _isRegisteringPatient
                                          ? const SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                      Color
                                                    >(Colors.orangeAccent),
                                              ),
                                            )
                                          : ElevatedButton.icon(
                                              icon: const Icon(
                                                Icons.send_rounded,
                                                size: 12,
                                                color: Colors.white,
                                              ),
                                              label: Text(
                                                'Register Patient to SatuSehat',
                                                style: GoogleFonts.outfit(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w900,
                                                  color: Colors.white,
                                                ),
                                              ),
                                              onPressed: () =>
                                                  _registerPatientSatuSehat(
                                                    enc,
                                                  ),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    Colors.orangeAccent,
                                                foregroundColor: Colors.white,
                                                elevation: 0,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 20,
                                                      vertical: 12,
                                                    ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                              ),
                                            ),
                                    ],
                                  ),
                                ),
                              ] else ...[
                                // Ready to sync manually
                                ElevatedButton.icon(
                                  icon: const Icon(
                                    Icons.send_rounded,
                                    size: 12,
                                    color: Colors.white,
                                  ),
                                  label: Text(
                                    enc['sync_status'] == 'success'
                                        ? 'Resend Encounter Data'
                                        : 'Send Encounter Data Now',
                                    style: GoogleFonts.outfit(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                    ),
                                  ),
                                  onPressed: () => _triggerIndividualSync(enc),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: activeGreen,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _getSyncStepLabel() {
    switch (_individualSyncStep) {
      case 'Connecting':
        return 'Connecting to Kemenkes SATUSEHAT endpoint...';
      case 'SendingEMR':
        return 'Uploading clinical encounter data (FHIR R4)...';
      case 'GeneratingPrescription':
        return 'Submitting prescription and medicine dispatch...';
      case 'Success':
        return 'Data synced successfully! Syncing ledger...';
      default:
        return 'Processing synchronization...';
    }
  }

  Widget _modalSectionHeader(IconData icon, String title, Color activeGreen) {
    return Row(
      children: [
        Icon(icon, color: activeGreen, size: 12),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 8.5,
            fontWeight: FontWeight.w900,
            color: activeGreen,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildVitalsGrid(Color border) {
    final vitals = _encounterDetailsData?['vitals'];
    final bp = vitals?['blood_pressure']?.toString() ?? '-';
    final temp = vitals?['body_temperature']?.toString() ?? '-';
    final weight = vitals?['body_weight']?.toString() ?? '-';
    final spo2 = vitals?['oxygen_saturation']?.toString() ?? '-';

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 4,
      crossAxisSpacing: 10,
      childAspectRatio: 1.5,
      children: [
        _vitalCard('BLOOD PRESSURE', bp, border),
        _vitalCard(
          'BODY TEMPERATURE',
          temp.isNotEmpty && temp != '-' ? '$temp°C' : '-',
          border,
        ),
        _vitalCard(
          'BODY WEIGHT',
          weight.isNotEmpty && weight != '-' ? '$weight kg' : '-',
          border,
        ),
        _vitalCard(
          'SPO2',
          spo2.isNotEmpty && spo2 != '-' ? '$spo2%' : '-',
          border,
        ),
      ],
    );
  }

  Widget _vitalCard(String label, String value, Color border) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: border.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 6,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF6F6A8A),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF1B0C3C),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTextCard(String text, Color subtitle, Color border) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: border.withOpacity(0.02),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Text(
        text.isNotEmpty ? text : '-',
        style: GoogleFonts.outfit(
          fontSize: 10.5,
          color: subtitle,
          fontWeight: FontWeight.bold,
          height: 1.3,
        ),
      ),
    );
  }

  Widget _buildDiagnosisCard(Color border, Color subtitle) {
    final List<dynamic> diags = _encounterDetailsData?['diagnosis'] ?? [];
    if (diags.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: border.withOpacity(0.02),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
        ),
        child: Text(
          'No diagnosis data',
          style: GoogleFonts.outfit(
            fontSize: 10.5,
            color: subtitle.withOpacity(0.5),
            fontStyle: FontStyle.italic,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: border.withOpacity(0.02),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: diags.map((d) {
          final code = d['icdx_code']?.toString() ?? '';
          final desc = d['description']?.toString() ?? '';
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF48C9B0).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    code,
                    style: GoogleFonts.outfit(
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF48C9B0),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    desc,
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      color: subtitle,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMedicinesTable(Color border, Color subtitle, Color textCol) {
    final List<dynamic> clinicItems =
        _encounterDetailsData?['inventory_items'] ?? [];

    // Prescription manual items
    final prescriptionMap =
        _encounterDetailsData?['prescription'] as Map<String, dynamic>?;
    final List<dynamic> rxItems =
        prescriptionMap?['electronic_prescription_items'] ?? [];

    final List<Map<String, dynamic>> combined = [];

    // Map inventory items
    for (final item in clinicItems) {
      final dm = item['detail_medicine'] as Map<String, dynamic>?;
      final m = dm?['medicine'] as Map<String, dynamic>?;
      final name = m?['medicine_name']?.toString() ?? 'Obat';
      combined.add({
        'name': name,
        'qty': item['quantity']?.toString() ?? '0',
        'dosage': item['dosage_instructions']?.toString() ?? '-',
      });
    }

    // Map rx items
    for (final item in rxItems) {
      combined.add({
        'name': item['medicine_name']?.toString() ?? 'Obat Resep',
        'qty': item['quantity']?.toString() ?? '0',
        'dosage': item['dosage_instructions']?.toString() ?? '-',
      });
    }

    if (combined.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: border.withOpacity(0.02),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
        ),
        child: Text(
          'No therapy data',
          style: GoogleFonts.outfit(
            fontSize: 10.5,
            color: subtitle.withOpacity(0.5),
            fontStyle: FontStyle.italic,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: border.withOpacity(0.01),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(2.0),
          1: FlexColumnWidth(0.8),
          2: FlexColumnWidth(1.5),
        },
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          TableRow(
            decoration: BoxDecoration(
              color: border.withOpacity(0.04),
              border: Border(bottom: BorderSide(color: border)),
            ),
            children: [
              _tableHeader('INVENTORY', subtitle),
              _tableHeader('QTY', subtitle),
              _tableHeader('SIGNATURE', subtitle),
            ],
          ),
          ...combined.map(
            (item) => TableRow(
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: border)),
              ),
              children: [
                _tableCell(
                  Text(
                    item['name'],
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: textCol,
                    ),
                  ),
                ),
                _tableCell(
                  Text(
                    item['qty'],
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: textCol,
                    ),
                  ),
                ),
                _tableCell(
                  Text(
                    item['dosage'],
                    style: GoogleFonts.outfit(
                      fontSize: 9.5,
                      color: subtitle,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Component Helper: Metric Card ─────────────────────────────────────────
  Widget _buildMetricCard(
    IconData icon,
    String label,
    String value,
    Color subCol,
    Color valueCol,
    Color bg,
    Color border,
    String subtitleDesc, {
    String? badgeText,
    bool isBadgeRed = false,
    List<String>? patientsBadges,
  }) {
    // Elegant theme-based dynamic color scheme for background glow and icon tint
    final Color primaryColor = valueCol;
    final Color iconBg = primaryColor.withOpacity(0.08);

    // Dynamic badge coloring
    final Color badgeBg = isBadgeRed 
        ? Colors.redAccent.withOpacity(0.08) 
        : const Color(0xFF48C9B0).withOpacity(0.08);
    final Color badgeBorder = isBadgeRed 
        ? Colors.redAccent.withOpacity(0.2) 
        : const Color(0xFF48C9B0).withOpacity(0.2);
    final Color badgeTextCol = isBadgeRed 
        ? Colors.redAccent 
        : const Color(0xFF48C9B0);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Top Row: Icon + Label (left), Badge (right)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: iconBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        icon,
                        size: 13,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        label,
                        style: GoogleFonts.outfit(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: subCol,
                          letterSpacing: 0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              if (badgeText != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: badgeBorder, width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        badgeText == '0%' 
                            ? Icons.trending_flat_rounded
                            : (isBadgeRed ? Icons.trending_down_rounded : Icons.trending_up_rounded),
                        size: 9,
                        color: badgeText == '0%' ? subCol : badgeTextCol,
                      ),
                      const SizedBox(width: 1.5),
                      Text(
                        badgeText,
                        style: GoogleFonts.outfit(
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          color: badgeText == '0%' ? subCol : badgeTextCol,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          
          const SizedBox(height: 10),
          
          // Value Row
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              color: valueCol,
              letterSpacing: -0.5,
            ),
          ),
          
          const SizedBox(height: 4),

          // Bottom Row: Patient Badges or Subtitle Description
          if (patientsBadges != null)
            Row(
              children: patientsBadges.map((b) {
                final isBpjs = b.startsWith('BPJS');
                final badgeColor = isBpjs ? Colors.blueAccent : const Color(0xFF48C9B0);
                return Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1.5,
                  ),
                  decoration: BoxDecoration(
                    color: badgeColor.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                      color: badgeColor.withOpacity(0.18),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    b,
                    style: GoogleFonts.outfit(
                      fontSize: 7.5,
                      fontWeight: FontWeight.w900,
                      color: badgeColor,
                    ),
                  ),
                );
              }).toList(),
            )
          else
            Text(
              subtitleDesc,
              style: GoogleFonts.outfit(
                fontSize: 8.5,
                color: subCol.withOpacity(0.8),
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
    );
  }

  // ─── Component Helper: Small Toggle Button ───────────────────────────────
  Widget _buildSmallToggle(
    String text,
    bool isSelected,
    Color activeColor,
    Color border,
    Color bg,
    Color textCol,
  ) {
    return Container(
      margin: const EdgeInsets.only(left: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected ? activeColor : bg,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: GoogleFonts.outfit(
          fontSize: 8.5,
          fontWeight: FontWeight.w900,
          color: textCol,
        ),
      ),
    );
  }

  Widget _legendItem(Color color, String text, Color textCol) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: GoogleFonts.outfit(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: textCol,
          ),
        ),
      ],
    );
  }

  Widget _legendCard(
    Color color,
    String text,
    String value,
    Color bg,
    Color border,
    Color textCol,
    Color subCol,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  text,
                  style: GoogleFonts.outfit(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: subCol,
                  ),
                ),
                Text(
                  value,
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: textCol,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String type, Color activeColor) {
    final state = ref.read(landingPageProvider);
    final isSelected = _filterType == type;
    return InkWell(
      onTap: () => setState(() {
        _filterType = type;
        _ledgerCurrentPage = 1;
      }),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withOpacity(0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? activeColor : Colors.transparent,
          ),
        ),
        child: Text(
          type.tr(state),
          style: GoogleFonts.outfit(
            fontSize: 9.5,
            fontWeight: FontWeight.w900,
            color: isSelected ? activeColor : const Color(0xFF6F6A8A),
          ),
        ),
      ),
    );
  }

  Widget _tableHeader(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Text(
        text,
        style: GoogleFonts.outfit(
          fontSize: 8,
          fontWeight: FontWeight.w900,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _tableCell(Widget child) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: child,
    );
  }

  Widget _tableCellClickable(
    Widget child,
    VoidCallback onTap, {
    Alignment alignment = Alignment.centerLeft,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Align(alignment: alignment, child: child),
      ),
    );
  }

  String _formatAmount(double amt) {
    String s = amt.toInt().toString();
    RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return s.replaceAllMapped(reg, (Match m) => '${m[1]}.');
  }

  String _formatDateShort(DateTime dt, bool isEnglish) {
    return '${dt.day} ${_getMonthNameShort(dt.month, isEnglish)} ${dt.year}';
  }

  String _getMonthNameShort(int month, bool isEnglish) {
    const monthsId = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agt',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    const monthsEn = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    if (month >= 1 && month <= 12) {
      return isEnglish ? monthsEn[month - 1] : monthsId[month - 1];
    }
    return '';
  }

  Widget _buildExpenseWizardModal(
    Color cardBg,
    Color text,
    Color subtitle,
    Color border,
    Color inputBg,
    Color purple,
  ) {
    final state = ref.read(landingPageProvider);
    final activeGreen = const Color(0xFF48C9B0);
    final isExpense = _txType == 'expense';
    final accentColor = isExpense ? Colors.redAccent : activeGreen;
    final wizardIcon = isExpense ? Icons.outbox_rounded : Icons.inbox_rounded;

    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.3),
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              width: 440,
              margin: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: accentColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              wizardIcon,
                              color: accentColor,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            isExpense
                                ? 'Catat Pengeluaran Baru'.tr(state)
                                : 'Catat Pemasukan Baru'.tr(state),
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: text,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: _isSaving ? null : _closeExpenseWizard,
                      ),
                    ],
                  ),
                  const Divider(height: 24),

                  // Segmented Choice Toggle between Pemasukan & Pengeluaran
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: _isSaving
                              ? null
                              : () {
                                  setState(() {
                                    _txType = 'income';
                                    _expCategory = 'Konsultasi';
                                  });
                                },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: !isExpense
                                  ? activeGreen.withOpacity(0.15)
                                  : inputBg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: !isExpense
                                    ? activeGreen
                                    : border,
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.inbox_rounded,
                                  size: 14,
                                  color: !isExpense
                                      ? activeGreen
                                      : subtitle,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Pemasukan'.tr(state),
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    color: !isExpense
                                        ? activeGreen
                                        : subtitle,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: _isSaving
                              ? null
                              : () {
                                  setState(() {
                                    _txType = 'expense';
                                    _expCategory = 'Obat & Medis';
                                  });
                                },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: isExpense
                                  ? Colors.redAccent.withOpacity(0.15)
                                  : inputBg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isExpense
                                    ? Colors.redAccent
                                    : border,
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.outbox_rounded,
                                  size: 14,
                                  color: isExpense
                                      ? Colors.redAccent
                                      : subtitle,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Pengeluaran'.tr(state),
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    color: isExpense
                                        ? Colors.redAccent
                                        : subtitle,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  Text(
                    isExpense
                        ? 'Deskripsi Pengeluaran *'.tr(state)
                        : 'Deskripsi Pemasukan *'.tr(state),
                    style: GoogleFonts.outfit(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                      color: text,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _expDescController,
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: text,
                    ),
                    decoration: InputDecoration(
                      hintText: isExpense
                          ? 'cth. Pembelian Reagen Golongan Darah & Syringe'.tr(state)
                          : 'cth. Pendapatan Tambahan / Klaim'.tr(state),
                      hintStyle: GoogleFonts.outfit(
                        fontSize: 11,
                        color: subtitle.withOpacity(0.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                      ),
                      filled: true,
                      fillColor: inputBg,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: accentColor),
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isExpense
                                  ? 'Kategori Pengeluaran *'.tr(state)
                                  : 'Kategori Pemasukan *'.tr(state),
                              style: GoogleFonts.outfit(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w900,
                                color: text,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                color: inputBg,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: border),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _expCategory,
                                  isExpanded: true,
                                  icon: Icon(
                                    Icons.arrow_drop_down,
                                    color: subtitle,
                                  ),
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: text,
                                  ),
                                  dropdownColor: cardBg,
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() => _expCategory = val);
                                    }
                                  },
                                  items: (isExpense
                                          ? [
                                              'Obat & Medis',
                                              'Operasional',
                                              'Gaji Staff',
                                              'Lain-lain',
                                            ]
                                          : [
                                              'Konsultasi',
                                              'Farmasi',
                                              'Lain-lain',
                                            ])
                                      .map(
                                        (c) => DropdownMenuItem(
                                          value: c,
                                          child: Text(c.tr(state)),
                                        ),
                                      )
                                      .toList(),
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
                            Text(
                              'Jumlah Nominal (Rp) *'.tr(state),
                              style: GoogleFonts.outfit(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w900,
                                color: text,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _expAmountController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [ThousandsFormatter()],
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: text,
                              ),
                              decoration: InputDecoration(
                                hintText: 'cth. 150.000'.tr(state),
                                hintStyle: GoogleFonts.outfit(
                                  fontSize: 11,
                                  color: subtitle.withOpacity(0.5),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                ),
                                filled: true,
                                fillColor: inputBg,
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(color: border),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide(color: accentColor),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _isSaving ? null : _closeExpenseWizard,
                        child: Text(
                          'Batal'.tr(state),
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: subtitle,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      ElevatedButton(
                        onPressed: _isSaving ? null : _confirmSave,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Text(
                                isExpense
                                    ? 'Simpan Pengeluaran'.tr(state)
                                    : 'Simpan Pemasukan'.tr(state),
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDailyTransactionsModal(
    LandingPageState state,
    Color cardBg,
    Color text,
    Color subtitle,
    Color border,
    Color inputBg,
    Color purple,
    Color activeGreen,
  ) {
    final group = _selectedGroupedDay!;
    final double totalIncome = group.totalIncome;
    final double totalExpense = group.totalExpense;
    final double net = group.netProfit;
    final Color netColor = net >= 0 ? activeGreen : Colors.redAccent;

    return Positioned.fill(
      child: GestureDetector(
        onTap: () => setState(() => _selectedGroupedDay = null),
        child: Container(
          color: Colors.black.withOpacity(0.3),
          child: GestureDetector(
            onTap: () {}, // Prevent click propagation to close modal
            child: Center(
              child: SingleChildScrollView(
                child: Container(
                  width: 520,
                  margin: const EdgeInsets.symmetric(
                    vertical: 24,
                    horizontal: 16,
                  ),
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 25,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header Row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.calendar_today_rounded,
                            color: activeGreen,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  group.date,
                                  style: GoogleFonts.outfit(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: text,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Daily Transaction Detail',
                                  style: GoogleFonts.outfit(
                                    fontSize: 10,
                                    color: subtitle,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                "TODAY'S BALANCE",
                                style: GoogleFonts.outfit(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w900,
                                  color: subtitle,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Rp ${_formatAmount(net)}',
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: netColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () =>
                                setState(() => _selectedGroupedDay = null),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Income / Expense Summary Row
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: activeGreen.withOpacity(0.04),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: activeGreen.withOpacity(0.2),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'INCOME',
                                    style: GoogleFonts.outfit(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w900,
                                      color: activeGreen,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Rp ${_formatAmount(totalIncome)}',
                                    style: GoogleFonts.outfit(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      color: activeGreen,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.redAccent.withOpacity(0.04),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.redAccent.withOpacity(0.2),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'EXPENSE',
                                    style: GoogleFonts.outfit(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.redAccent,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Rp ${_formatAmount(totalExpense)}',
                                    style: GoogleFonts.outfit(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.redAccent,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Scrollable list of transactions
                      Container(
                        constraints: const BoxConstraints(maxHeight: 320),
                        child: SingleChildScrollView(
                          child: Column(
                            children: group.transactions.map((tx) {
                              final isIncome = tx.tipe == 'Pemasukan';
                              final Color txColor = isIncome
                                  ? activeGreen
                                  : Colors.redAccent;

                              // Check for clinical encounter & sync status
                              Map<String, dynamic>? matchedEncounter;
                              if (tx.sourceType == 'clinical_encounter' &&
                                  tx.idSource != null) {
                                try {
                                  matchedEncounter = _patientSyncList
                                      .firstWhere(
                                        (enc) => enc['id'] == tx.idSource,
                                      );
                                } catch (_) {}
                              }

                              return InkWell(
                                onTap: () =>
                                    setState(() => _selectedEntry = tx),
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: inputBg,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: border),
                                  ),
                                  child: Row(
                                    children: [
                                      // Icon container
                                      Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: txColor.withOpacity(0.08),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          isIncome
                                              ? Icons.trending_up_rounded
                                              : Icons.trending_down_rounded,
                                          color: txColor,
                                          size: 18,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      // Middle details
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              tx.deskripsi,
                                              style: GoogleFonts.outfit(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: text,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 2,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: txColor.withOpacity(
                                                      0.08,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          4,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    tx.kategori.toUpperCase(),
                                                    style: GoogleFonts.outfit(
                                                      fontSize: 6.5,
                                                      fontWeight:
                                                          FontWeight.w900,
                                                      color: txColor,
                                                    ),
                                                  ),
                                                ),
                                                if (tx.sourceType != null) ...[
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    tx.sourceType!,
                                                    style: GoogleFonts.outfit(
                                                      fontSize: 8,
                                                      color: subtitle,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      // Right details
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            '${isIncome ? '+' : '-'} Rp ${_formatAmount(tx.jumlah)}',
                                            style: GoogleFonts.outfit(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w900,
                                              color: txColor,
                                            ),
                                          ),
                                          if (matchedEncounter != null) ...[
                                            const SizedBox(height: 6),
                                            _buildSatuSehatSyncBadge(
                                              matchedEncounter,
                                              activeGreen,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Close Button
                      ElevatedButton(
                        onPressed: () =>
                            setState(() => _selectedGroupedDay = null),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: activeGreen,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(
                          'Close',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSatuSehatSyncBadge(
    Map<String, dynamic> encounter,
    Color activeGreen,
  ) {
    final String syncStatus = encounter['sync_status'] ?? 'unsent';
    final bool isSyncingThis =
        _isSyncingIndividual &&
        _selectedSyncEncounter?['id'] == encounter['id'];

    if (syncStatus == 'success') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: activeGreen.withOpacity(0.08),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: activeGreen.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.check_circle_outline_rounded,
              size: 10,
              color: activeGreen,
            ),
            const SizedBox(width: 4),
            Text(
              'Sync Success',
              style: GoogleFonts.outfit(
                fontSize: 7.5,
                fontWeight: FontWeight.w900,
                color: activeGreen,
              ),
            ),
          ],
        ),
      );
    } else if (syncStatus == 'failed') {
      return InkWell(
        onTap: isSyncingThis ? null : () => _triggerIndividualSync(encounter),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.redAccent.withOpacity(0.08),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: Colors.redAccent.withOpacity(0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isSyncingThis)
                const SizedBox(
                  width: 10,
                  height: 10,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.redAccent),
                  ),
                )
              else
                const Icon(
                  Icons.error_outline_rounded,
                  size: 10,
                  color: Colors.redAccent,
                ),
              const SizedBox(width: 4),
              Text(
                'Sync Failed (Retry)',
                style: GoogleFonts.outfit(
                  fontSize: 7.5,
                  fontWeight: FontWeight.w900,
                  color: Colors.redAccent,
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      // Unsent
      return InkWell(
        onTap: isSyncingThis ? null : () => _triggerIndividualSync(encounter),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: activeGreen.withOpacity(0.08),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: activeGreen.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isSyncingThis)
                const SizedBox(
                  width: 10,
                  height: 10,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFF48C9B0),
                    ),
                  ),
                )
              else
                Icon(Icons.send_rounded, size: 10, color: activeGreen),
              const SizedBox(width: 4),
              Text(
                'Sync SatuSehat',
                style: GoogleFonts.outfit(
                  fontSize: 7.5,
                  fontWeight: FontWeight.w900,
                  color: activeGreen,
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildInvoiceModal(
    LandingPageState state,
    Color cardBg,
    Color text,
    Color subtitle,
    Color border,
    Color inputBg,
    Color purple,
    Color activeGreen,
  ) {
    final entry = _selectedEntry!;
    final isPemasukan = entry.tipe == 'Pemasukan';
    final isRme =
        isPemasukan && entry.deskripsi.startsWith('Pemeriksaan RME - ');

    final consultFee = isPemasukan ? min(entry.jumlah, 100000.0) : 0.0;
    final drugFee = isPemasukan ? (entry.jumlah - consultFee) : 0.0;

    return Positioned.fill(
      child: GestureDetector(
        onTap: () => setState(() => _selectedEntry = null),
        child: Container(
          color: Colors.black.withOpacity(0.3),
          child: GestureDetector(
            onTap: () {}, // Prevent click propagation to close modal
            child: Center(
              child: SingleChildScrollView(
                child: Container(
                  width: 440,
                  margin: const EdgeInsets.symmetric(
                    vertical: 24,
                    horizontal: 16,
                  ),
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 25,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Detail Kwitansi Pembayaran',
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: text,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () =>
                                setState(() => _selectedEntry = null),
                          ),
                        ],
                      ),
                      const Divider(height: 20),

                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: border.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'MAPOTEK CLINIC',
                                      style: GoogleFonts.outfit(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w900,
                                        color: text,
                                      ),
                                    ),
                                    Text(
                                      'Praktek Mandiri dr. Agoes Soetanto',
                                      style: GoogleFonts.outfit(
                                        fontSize: 7.5,
                                        color: subtitle,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        (isPemasukan
                                                ? activeGreen
                                                : Colors.redAccent)
                                            .withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(100),
                                  ),
                                  child: Text(
                                    entry.tipe.toUpperCase(),
                                    style: GoogleFonts.outfit(
                                      fontSize: 7,
                                      fontWeight: FontWeight.w900,
                                      color: isPemasukan
                                          ? activeGreen
                                          : Colors.redAccent,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 10),
                              child: Divider(height: 1),
                            ),

                            _invoiceMetaRow(
                              'Kode Transaksi',
                              entry.id,
                              text,
                              subtitle,
                            ),
                            const SizedBox(height: 6),
                            _invoiceMetaRow(
                              'Tanggal & Waktu',
                              '${entry.tanggal} • ${entry.waktu}',
                              text,
                              subtitle,
                            ),
                            if (isPemasukan) ...[
                              const SizedBox(height: 6),
                              _invoiceMetaRow(
                                'Pasien',
                                entry.deskripsi.replaceFirst(
                                  'Pemeriksaan RME - ',
                                  '',
                                ),
                                text,
                                subtitle,
                              ),
                              const SizedBox(height: 6),
                              _invoiceMetaRow(
                                'Metode Pembayaran',
                                entry.metode,
                                text,
                                subtitle,
                              ),
                            ] else ...[
                              const SizedBox(height: 6),
                              _invoiceMetaRow(
                                'Kategori Biaya',
                                entry.kategori,
                                text,
                                subtitle,
                              ),
                            ],

                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 10),
                              child: Divider(height: 1),
                            ),

                            Text(
                              isPemasukan
                                  ? 'RINCIAN TRANSAKSI KLINIK'
                                  : 'RINCIAN PENGELUARAN KLINIK',
                              style: GoogleFonts.outfit(
                                fontSize: 7.5,
                                fontWeight: FontWeight.w900,
                                color: subtitle,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 10),

                            if (isPemasukan) ...[
                              _invoiceItemRow(
                                'Jasa Pemeriksaan & Konsultasi Medis',
                                'Rp ${_formatAmount(consultFee)}',
                                text,
                              ),
                              if (drugFee > 0) ...[
                                const SizedBox(height: 6),
                                _invoiceItemRow(
                                  'Resep Digital & Terapi Obat',
                                  'Rp ${_formatAmount(drugFee)}',
                                  text,
                                ),
                              ],
                            ] else ...[
                              _invoiceItemRow(
                                entry.deskripsi,
                                'Rp ${_formatAmount(entry.jumlah)}',
                                text,
                              ),
                            ],

                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Divider(height: 1),
                            ),

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'TOTAL BAYAR',
                                  style: GoogleFonts.outfit(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    color: text,
                                  ),
                                ),
                                Text(
                                  'Rp ${_formatAmount(entry.jumlah)}',
                                  style: GoogleFonts.outfit(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    color: isPemasukan
                                        ? activeGreen
                                        : Colors.redAccent,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      if (isRme)
                        _buildSatuSehatSection(
                          entry,
                          state,
                          cardBg,
                          text,
                          subtitle,
                          border,
                          inputBg,
                          purple,
                          activeGreen,
                        ),

                      const SizedBox(height: 24),

                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                setState(() => _selectedEntry = null);
                              },
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: border),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                'Tutup',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  color: subtitle,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                setState(() => _selectedEntry = null);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    behavior: SnackBarBehavior.floating,
                                    backgroundColor: activeGreen,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    content: Row(
                                      children: [
                                        const Icon(
                                          Icons.print_rounded,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          'Perintah cetak kwitansi ${entry.id} dikirim ke printer thermal.',
                                          style: GoogleFonts.outfit(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: purple,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.print_rounded,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Cetak Kwitansi',
                                    style: GoogleFonts.outfit(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSatuSehatSection(
    BukuKasEntry entry,
    LandingPageState state,
    Color cardBg,
    Color text,
    Color subtitle,
    Color border,
    Color inputBg,
    Color purple,
    Color activeGreen,
  ) {
    final isSynced =
        state.satusehatAutoSync || state.syncedTransactions.contains(entry.id);

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: inputBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.cloud_sync_rounded,
                    color: ref.read(landingPageProvider.notifier).getPrimaryColor(),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'SATUSEHAT Kemenkes',
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: text,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (isSynced ? activeGreen : Colors.amber).withOpacity(
                    0.12,
                  ),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isSynced
                          ? Icons.check_circle_rounded
                          : Icons.access_time_filled_rounded,
                      size: 10,
                      color: isSynced ? activeGreen : Colors.amber,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isSynced ? 'SYNCED' : 'PENDING',
                      style: GoogleFonts.outfit(
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        color: isSynced ? activeGreen : Colors.amber,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isSynced) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'STATUS SINKRONISASI',
                        style: GoogleFonts.outfit(
                          fontSize: 7.5,
                          fontWeight: FontWeight.w900,
                          color: subtitle,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Data RME berhasil terkirim ke platform SATUSEHAT Kemenkes RI.',
                        style: GoogleFonts.outfit(
                          fontSize: 9,
                          color: text,
                          height: 1.3,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'TRANSACTION HASH / ID',
                        style: GoogleFonts.outfit(
                          fontSize: 7.5,
                          fontWeight: FontWeight.w900,
                          color: subtitle,
                        ),
                      ),
                      const SizedBox(height: 4),
                      SelectableText(
                        'ss-tx-${entry.id.hashCode.abs().toRadixString(16).toUpperCase()}-${entry.id.substring(0, min(entry.id.length, 4))}',
                        style: GoogleFonts.outfit(
                          fontSize: 8.5,
                          color: purple,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: border),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Image.network(
                    'https://api.qrserver.com/v1/create-qr-code/?size=100x100&data=https://satusehat.kemkes.go.id/verification/tx/${entry.id}',
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.qr_code_rounded,
                      size: 40,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            Text(
              'Data pemeriksaan RME belum disinkronkan ke platform SATUSEHAT Kemenkes.',
              style: GoogleFonts.outfit(
                fontSize: 9,
                color: subtitle,
                height: 1.3,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _isSyncingIndividual
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(purple),
                        ),
                      ),
                    ),
                  )
                : ElevatedButton(
                    onPressed: () {
                      setState(() => _isSyncingIndividual = true);
                      Timer(const Duration(milliseconds: 1500), () {
                        if (!mounted) return;
                        ref
                            .read(landingPageProvider.notifier)
                            .markTransactionSynced(entry.id);
                        setState(() => _isSyncingIndividual = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: activeGreen,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            content: Row(
                              children: [
                                const Icon(
                                  Icons.cloud_done_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Data rekam medis ${entry.id} berhasil disinkronkan ke SATUSEHAT.',
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: purple,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.cloud_upload_rounded,
                          size: 12,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Kirim SatuSehat (Manual)',
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
          ],
        ],
      ),
    );
  }

  Widget _invoiceMetaRow(
    String label,
    String value,
    Color textCol,
    Color subCol,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 8.5,
            fontWeight: FontWeight.bold,
            color: subCol,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 8.5,
            fontWeight: FontWeight.w900,
            color: textCol,
          ),
        ),
      ],
    );
  }

  Widget _invoiceItemRow(String name, String price, Color textCol) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            name,
            style: GoogleFonts.outfit(
              fontSize: 9.5,
              fontWeight: FontWeight.bold,
              color: textCol,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Text(
          price,
          style: GoogleFonts.outfit(
            fontSize: 9.5,
            fontWeight: FontWeight.w900,
            color: textCol,
          ),
        ),
      ],
    );
  }
}

// ─── CUSTOM CHALFLOW Bezier LINE CHART PAINTER ──────────────────────────────
class CashflowChartPainter extends CustomPainter {
  final List<double> incomeData;
  final List<double> expenseData;
  final bool isDark;

  CashflowChartPainter({
    required this.incomeData,
    required this.expenseData,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = isDark ? const Color(0xFF252528) : const Color(0xFFECEEF2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final labelStyle = GoogleFonts.outfit(
      fontSize: 7.5,
      fontWeight: FontWeight.bold,
      color: isDark ? Colors.grey[500] : const Color(0xFF6F6A8A),
    );

    double maxVal = 100000.0;
    for (final val in incomeData) {
      if (val > maxVal) maxVal = val;
    }
    for (final val in expenseData) {
      if (val > maxVal) maxVal = val;
    }

    maxVal = maxVal * 1.1;

    final heightStep = size.height / 4;
    for (int i = 0; i <= 4; i++) {
      final y = size.height - (i * heightStep);
      canvas.drawLine(Offset(35, y), Offset(size.width, y), gridPaint);

      final double gridVal = (maxVal / 4) * i;
      final valStr = _formatYLabel(gridVal);
      final tp = TextPainter(
        text: TextSpan(text: valStr, style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(5, y - tp.height / 2));
    }

    final widthStep = (size.width - 35) / 11;
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    for (int i = 0; i < 12; i++) {
      final x = 35 + (i * widthStep);
      final tp = TextPainter(
        text: TextSpan(text: months[i], style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, size.height + 6));
    }

    _drawBezierCurve(canvas, size, incomeData, const Color(0xFF48C9B0), maxVal);
    _drawBezierCurve(canvas, size, expenseData, Colors.redAccent, maxVal);
  }

  void _drawBezierCurve(
    Canvas canvas,
    Size size,
    List<double> values,
    Color color,
    double maxVal,
  ) {
    if (values.isEmpty) return;
    final widthStep = (size.width - 35) / 11;

    final path = Path();
    final fillPath = Path();

    final points = <Offset>[];
    for (int i = 0; i < 12; i++) {
      final val = i < values.length ? values[i] : 0.0;
      final pct = (val / maxVal).clamp(0.0, 1.0);
      final x = 35 + (i * widthStep);
      final y = size.height - (pct * size.height);
      points.add(Offset(x, y));
    }

    path.moveTo(points[0].dx, points[0].dy);
    fillPath.moveTo(points[0].dx, size.height);
    fillPath.lineTo(points[0].dx, points[0].dy);

    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final controlPointX = (p0.dx + p1.dx) / 2;

      path.cubicTo(controlPointX, p0.dy, controlPointX, p1.dy, p1.dx, p1.dy);
      fillPath.cubicTo(
        controlPointX,
        p0.dy,
        controlPointX,
        p1.dy,
        p1.dx,
        p1.dy,
      );
    }

    fillPath.lineTo(points.last.dx, size.height);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withOpacity(0.18), color.withOpacity(0.0)],
      ).createShader(Rect.fromLTWH(35, 0, size.width - 35, size.height))
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, linePaint);

    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (int i = 0; i < points.length; i++) {
      if (values[i] > 0) {
        canvas.drawCircle(points[i], 4, dotPaint);
        canvas.drawCircle(points[i], 4, borderPaint);
      }
    }
  }

  String _formatYLabel(double val) {
    if (val >= 10000000) {
      return '${(val / 10000000).toStringAsFixed(1).replaceAll('.0', '')}puluh jt';
    } else if (val >= 1000000) {
      return '${(val / 1000000).toStringAsFixed(1).replaceAll('.0', '')}jt';
    } else if (val >= 1000) {
      return '${(val / 1000).toStringAsFixed(0)}rb';
    }
    return val.toStringAsFixed(0);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ─── PATIENT RATIO DONUT CHART PAINTER ────────────────────────────────────────
class PatientRatioDonutChartPainter extends CustomPainter {
  final int generalCount;
  final int bpjsCount;
  final bool isDark;

  PatientRatioDonutChartPainter({
    required this.generalCount,
    required this.bpjsCount,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2;
    const strokeWidth = 14.0;

    final total = generalCount + bpjsCount;
    if (total == 0) {
      final paint = Paint()
        ..color = isDark ? const Color(0xFF252528) : const Color(0xFFECEEF2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;
      canvas.drawCircle(center, radius - strokeWidth / 2, paint);
      return;
    }

    final generalPct = generalCount / total;
    final bpjsPct = bpjsCount / total;

    final generalPaint = Paint()
      ..color = const Color(0xFF48C9B0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final bpjsPaint = Paint()
      ..color = const Color(0xFF1B4F42)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromCircle(
      center: center,
      radius: radius - strokeWidth / 2,
    );

    const startAngle = -pi / 2;
    final generalAngle = 2 * pi * generalPct;
    final bpjsAngle = 2 * pi * bpjsPct;

    canvas.drawArc(rect, startAngle, generalAngle, false, generalPaint);

    if (bpjsCount > 0) {
      canvas.drawArc(
        rect,
        startAngle + generalAngle,
        bpjsAngle,
        false,
        bpjsPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class ViewportOverlay extends StatefulWidget {
  final bool show;
  final WidgetBuilder builder;

  const ViewportOverlay({super.key, required this.show, required this.builder});

  @override
  State<ViewportOverlay> createState() => _ViewportOverlayState();
}

class _ViewportOverlayState extends State<ViewportOverlay> {
  final _controller = OverlayPortalController();

  @override
  void initState() {
    super.initState();
    if (widget.show) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.show) {
          _controller.show();
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant ViewportOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.show != oldWidget.show) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          if (widget.show) {
            _controller.show();
          } else {
            _controller.hide();
          }
        }
      });
    }
  }

  @override
  void dispose() {
    if (_controller.isShowing) {
      _controller.hide();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return OverlayPortal(
      controller: _controller,
      overlayChildBuilder: (context) {
        if (!widget.show) {
          return const SizedBox.shrink();
        }
        return widget.builder(context);
      },
      child: const SizedBox.shrink(),
    );
  }
}
