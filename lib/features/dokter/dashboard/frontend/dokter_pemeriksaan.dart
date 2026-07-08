import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapotech/features/landing/landing_page_data.dart';
import 'package:mapotech/features/dokter/dashboard/frontend/dokter_antrian.dart';
import 'package:mapotech/features/dokter/dashboard/frontend/dokter_pasien.dart';
import 'package:mapotech/features/dokter/dashboard/frontend/dokter_obat.dart';
import 'package:mapotech/shared/icd_codes.dart';
import 'package:mapotech/shared/supabase_service.dart';
import 'package:mapotech/shared/satusehat_service.dart';
import 'package:mapotech/shared/thousands_formatter.dart';
import 'package:mapotech/shared/widgets/skeleton_loading.dart';
import 'package:mapotech/shared/widgets/custom_button.dart';

class DokterPemeriksaan extends ConsumerStatefulWidget {
  const DokterPemeriksaan({super.key});

  @override
  ConsumerState<DokterPemeriksaan> createState() => _DokterPemeriksaanState();
}

class _DokterPemeriksaanState extends ConsumerState<DokterPemeriksaan> {
  AntrianModel? _activeQueue;
  PasienModel? _activePatient;

  // Stepper state
  int _currentStep = 1;

  // SatuSehat Sync States
  bool _isSyncing = false;
  bool _syncSuccess = false;
  String _syncStep = 'Connecting';
  String _txHash = '';
  String? _lastSavedEncounterId;

  // Vital Signs (Step 4)
  final _tensiController = TextEditingController();
  final _tensiSysController = TextEditingController();
  final _tensiDiaController = TextEditingController();
  final _nadiController = TextEditingController();
  final _respirasiController = TextEditingController();
  final _suhuController = TextEditingController();
  final _beratController = TextEditingController();
  final _tinggiController = TextEditingController();
  final _spo2Controller = TextEditingController();

  // Anamnesis & Diagnosis (Step 2)
  final _keluhanController = TextEditingController();
  final _anamnesisController = TextEditingController();
  final _diagnosisSearchController = TextEditingController();
  final _diagnosisIcd9SearchController = TextEditingController();
  final List<IcdCode> _selectedDiagnoses = [];
  final Map<String, String> _diagnosisTypes =
      {}; // Key: code, Value: 'Primary' or 'Secondary'
  String _selectedDiagnosisType = 'Primary'; // Default selection
  String _diagnosisSearchQuery = '';
  bool _showDiagnosisDropdown = false;
  String _diagnosisIcd9SearchQuery = '';
  bool _showDiagnosisIcd9Dropdown = false;

  // Allergies & Conditions (Step 3)
  String _foodAllergy = 'Tidak Ada';
  String _airAllergy = 'Tidak Ada';
  String _drugAllergy = 'Tidak Ada';
  String _antibioticAllergy = 'Tidak Ada';
  final _antibioticDetailController = TextEditingController();
  final _medTherapyController = TextEditingController();
  final _nonMedTherapyController = TextEditingController();
  String _prognosis = 'Sembuh';
  final _bmhpController = TextEditingController();

  // Prescriptions (Step 5)
  final List<Map<String, dynamic>> _addedPrescriptions = [];
  final List<Map<String, dynamic>> _manualPrescriptions = [];
  String? _selectedApotek;
  final _serviceFeeController = TextEditingController();
  ObatModel? _selectedDrug;
  final _qtyController = TextEditingController(text: '1');
  final _instructionController = TextEditingController();
  final bool _showDrugDropdown = false;
  final String _drugSearchQuery = '';
  int _step5TabIndex = 0; // 0=Resep Katalog, 1=Resep Manual+Apotek, 2=Rujukan
  bool _queueCardExpanded = true; // collapsible queue sidebar card

  // Referral (Step 5)
  bool _wantReferral = false;
  final _referralRsController = TextEditingController();
  final _referralPoliController = TextEditingController();
  final _referralNotesController = TextEditingController();
  String _generatedReferralNo = '';

  // Surat Sakit / Surat Sehat (Step 5)
  bool _wantSuratKeterangan = false;
  String _suratKeteranganType = 'sehat'; // 'sehat' or 'sakit'
  final _suratKeperluanController = TextEditingController();
  final _suratRiwayatPenyakitController = TextEditingController();
  final _suratSakitHariController = TextEditingController(text: '3');
  DateTime? _suratSakitStartDate = DateTime.now();
  DateTime? _suratSakitEndDate = DateTime.now().add(const Duration(days: 2));


  @override
  void initState() {
    super.initState();
    _serviceFeeController.text = formatPrice(
      ref.read(landingPageProvider).defaultServiceFee,
    );
    _tensiSysController.addListener(_updateTensiController);
    _tensiDiaController.addListener(_updateTensiController);
    _serviceFeeController.addListener(() {
      setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userState = ref.read(landingPageProvider);
      final userId = userState.activeDoctorId;
      final doctorId = (userId == 'mock-id-1234567890' || userId == null)
          ? '8f93471a-74f8-486b-8e85-4002dc44c11c'
          : userId;
      ref.read(dokterObatListProvider.notifier).loadMedicines(doctorId);
    });
  }

  void _updateTensiController() {
    if (_tensiSysController.text.isEmpty && _tensiDiaController.text.isEmpty) {
      _tensiController.text = '';
    } else {
      _tensiController.text =
          '${_tensiSysController.text}/${_tensiDiaController.text}';
    }
    setState(() {});
  }

  VitalWarning? getBPWarning(String sysStr, String diaStr) {
    final s = int.tryParse(sysStr);
    final d = int.tryParse(diaStr);
    if (s == null || d == null) return null;

    if (s >= 180 || d >= 110) {
      return VitalWarning(
        label: 'Severe Hypertension (Crisis)',
        category: 'bp',
        color: const Color(0xFFC0392B),
        bgColor: const Color(0xFFFDEDEC),
        borderColor: const Color(0xFFF5B7B1),
        isCritical: true,
      );
    }
    if (s < 90 || d < 60) {
      return VitalWarning(
        label: 'Severe Hypotension (Shock)',
        category: 'bp',
        color: const Color(0xFFC0392B),
        bgColor: const Color(0xFFFDEDEC),
        borderColor: const Color(0xFFF5B7B1),
        isCritical: true,
      );
    }
    if (s <= 100 || d <= 70) {
      return VitalWarning(
        label: 'Hypotension',
        category: 'bp',
        color: const Color(0xFFD35400),
        bgColor: const Color(0xFFFDF2E9),
        borderColor: const Color(0xFFF5CBA7),
        isCritical: false,
      );
    }
    if (s < 120 && d < 80) {
      return null; // Normal
    }
    if (s >= 160 || d >= 100) {
      return VitalWarning(
        label: 'Hypertension Stage 2',
        category: 'bp',
        color: const Color(0xFFE74C3C),
        bgColor: const Color(0xFFFDEDEC),
        borderColor: const Color(0xFFFADBD8),
        isCritical: true,
      );
    }
    if (s >= 140 || d >= 90) {
      return VitalWarning(
        label: 'Hypertension Stage 1',
        category: 'bp',
        color: const Color(0xFFE67E22),
        bgColor: const Color(0xFFFEF9E7),
        borderColor: const Color(0xFFF9E79F),
        isCritical: false,
      );
    }
    return VitalWarning(
      label: 'Pre-hypertension',
      category: 'bp',
      color: const Color(0xFFF1C40F),
      bgColor: const Color(0xFFFEF9E7),
      borderColor: const Color(0xFFFCF3CF),
      isCritical: false,
    );
  }

  VitalWarning? getHRWarning(String hrStr) {
    final hr = int.tryParse(hrStr);
    if (hr == null) return null;

    if (hr < 50) {
      return VitalWarning(
        label: 'Severe Bradycardia',
        category: 'hr',
        color: const Color(0xFFC0392B),
        bgColor: const Color(0xFFFDEDEC),
        borderColor: const Color(0xFFF5B7B1),
        isCritical: true,
      );
    }
    if (hr < 60) {
      return VitalWarning(
        label: 'Bradycardia',
        category: 'hr',
        color: const Color(0xFFD35400),
        bgColor: const Color(0xFFFDF2E9),
        borderColor: const Color(0xFFF5CBA7),
        isCritical: false,
      );
    }
    if (hr <= 100) {
      return null;
    }
    return VitalWarning(
      label: 'Tachycardia',
      category: 'hr',
      color: const Color(0xFFE74C3C),
      bgColor: const Color(0xFFFDEDEC),
      borderColor: const Color(0xFFFADBD8),
      isCritical: false,
    );
  }

  VitalWarning? getRRWarning(String rrStr) {
    final rr = int.tryParse(rrStr);
    if (rr == null) return null;

    if (rr < 10) {
      return VitalWarning(
        label: 'Severe Bradypnea',
        category: 'rr',
        color: const Color(0xFFC0392B),
        bgColor: const Color(0xFFFDEDEC),
        borderColor: const Color(0xFFF5B7B1),
        isCritical: true,
      );
    }
    if (rr < 12) {
      return VitalWarning(
        label: 'Bradypnea',
        category: 'rr',
        color: const Color(0xFFD35400),
        bgColor: const Color(0xFFFDF2E9),
        borderColor: const Color(0xFFF5CBA7),
        isCritical: false,
      );
    }
    if (rr <= 20) {
      return null;
    }
    if (rr <= 30) {
      return VitalWarning(
        label: 'Tachypnea',
        category: 'rr',
        color: const Color(0xFFE67E22),
        bgColor: const Color(0xFFFEF9E7),
        borderColor: const Color(0xFFF9E79F),
        isCritical: false,
      );
    }
    return VitalWarning(
      label: 'Respiratory Distress',
      category: 'rr',
      color: const Color(0xFFC0392B),
      bgColor: const Color(0xFFFDEDEC),
      borderColor: const Color(0xFFF5B7B1),
      isCritical: true,
    );
  }

  VitalWarning? getTempWarning(String tempStr) {
    final temp = double.tryParse(tempStr.replaceAll(',', '.'));
    if (temp == null) return null;

    if (temp < 35) {
      return VitalWarning(
        label: 'Severe Hypothermia',
        category: 'temp',
        color: const Color(0xFFC0392B),
        bgColor: const Color(0xFFFDEDEC),
        borderColor: const Color(0xFFF5B7B1),
        isCritical: true,
      );
    }
    if (temp < 36) {
      return VitalWarning(
        label: 'Hypothermia',
        category: 'temp',
        color: const Color(0xFFD35400),
        bgColor: const Color(0xFFFDF2E9),
        borderColor: const Color(0xFFF5CBA7),
        isCritical: false,
      );
    }
    if (temp <= 37.5) {
      return null;
    }
    if (temp <= 38.5) {
      return VitalWarning(
        label: 'Mild Fever',
        category: 'temp',
        color: const Color(0xFFF1C40F),
        bgColor: const Color(0xFFFEF9E7),
        borderColor: const Color(0xFFFCF3CF),
        isCritical: false,
      );
    }
    if (temp < 40) {
      return VitalWarning(
        label: 'High Fever',
        category: 'temp',
        color: const Color(0xFFE67E22),
        bgColor: const Color(0xFFFEF9E7),
        borderColor: const Color(0xFFF9E79F),
        isCritical: false,
      );
    }
    return VitalWarning(
      label: 'Hyperthermia (Danger)',
      category: 'temp',
      color: const Color(0xFFC0392B),
      bgColor: const Color(0xFFFDEDEC),
      borderColor: const Color(0xFFF5B7B1),
      isCritical: true,
    );
  }

  VitalWarning? getSpO2Warning(String spo2Str) {
    final spo2 = int.tryParse(spo2Str);
    if (spo2 == null) return null;

    if (spo2 >= 95) {
      return null;
    }
    if (spo2 >= 90) {
      return VitalWarning(
        label: 'Mild Hypoxia',
        category: 'spo2',
        color: const Color(0xFFE67E22),
        bgColor: const Color(0xFFFEF9E7),
        borderColor: const Color(0xFFF9E79F),
        isCritical: false,
      );
    }
    return VitalWarning(
      label: 'Severe Hypoxia',
      category: 'spo2',
      color: const Color(0xFFC0392B),
      bgColor: const Color(0xFFFDEDEC),
      borderColor: const Color(0xFFF5B7B1),
      isCritical: true,
    );
  }

  VitalWarning? getBmiWarning(String weightStr, String heightStr) {
    final weight = double.tryParse(weightStr.replaceAll(',', '.'));
    final height = double.tryParse(heightStr.replaceAll(',', '.'));
    if (weight == null || height == null || height <= 0) return null;

    final bmi = weight / ((height / 100) * (height / 100));
    if (bmi < 18.5) {
      return VitalWarning(
        label: 'BMI Underweight',
        category: 'bmi',
        color: const Color(0xFF3498DB),
        bgColor: const Color(0xFFEBF5FB),
        borderColor: const Color(0xFFA9CCE3),
        isCritical: false,
      );
    }
    if (bmi < 25) {
      return null;
    }
    if (bmi < 30) {
      return VitalWarning(
        label: 'BMI Overweight',
        category: 'bmi',
        color: const Color(0xFFF1C40F),
        bgColor: const Color(0xFFFEF9E7),
        borderColor: const Color(0xFFFCF3CF),
        isCritical: false,
      );
    }
    return VitalWarning(
      label: 'BMI Obese',
      category: 'bmi',
      color: const Color(0xFFE74C3C),
      bgColor: const Color(0xFFFDEDEC),
      borderColor: const Color(0xFFFADBD8),
      isCritical: true,
    );
  }

  List<String> _validateVitalSigns() {
    final errors = <String>[];
    if (_tensiSysController.text.isNotEmpty) {
      final val = int.tryParse(_tensiSysController.text);
      if (val == null || val < 50 || val > 260) {
        errors.add(
          'Tekanan Darah Systolic harus berada di rentang 50 - 260 mmHg.',
        );
      }
    }
    if (_tensiDiaController.text.isNotEmpty) {
      final val = int.tryParse(_tensiDiaController.text);
      if (val == null || val < 30 || val > 150) {
        errors.add(
          'Tekanan Darah Diastolic harus berada di rentang 30 - 150 mmHg.',
        );
      }
    }
    if (_nadiController.text.isNotEmpty) {
      final val = int.tryParse(_nadiController.text);
      if (val == null || val < 30 || val > 220) {
        errors.add(
          'Detak Jantung (Heart Rate) harus berada di rentang 30 - 220 bpm.',
        );
      }
    }
    if (_respirasiController.text.isNotEmpty) {
      final val = int.tryParse(_respirasiController.text);
      if (val == null || val < 8 || val > 60) {
        errors.add(
          'Laju Pernafasan (Respiration Rate) harus berada di rentang 8 - 60 rpm.',
        );
      }
    }
    if (_suhuController.text.isNotEmpty) {
      final val = double.tryParse(_suhuController.text.replaceAll(',', '.'));
      if (val == null || val < 30.0 || val > 45.0) {
        errors.add(
          'Suhu Tubuh (Body Temp) harus berada di rentang 30.0 - 45.0 °C.',
        );
      }
    }
    if (_beratController.text.isNotEmpty) {
      final val = double.tryParse(_beratController.text.replaceAll(',', '.'));
      if (val == null || val < 1.0 || val > 300.0) {
        errors.add(
          'Berat Badan (Weight) harus berada di rentang 1.0 - 300.0 kg.',
        );
      }
    }
    if (_tinggiController.text.isNotEmpty) {
      final val = double.tryParse(_tinggiController.text.replaceAll(',', '.'));
      if (val == null || val < 30.0 || val > 250.0) {
        errors.add(
          'Tinggi Badan (Height) harus berada di rentang 30.0 - 250.0 cm.',
        );
      }
    }
    if (_spo2Controller.text.isNotEmpty) {
      final val = int.tryParse(_spo2Controller.text);
      if (val == null || val < 0 || val > 100) {
        errors.add(
          'Saturasi Oksigen (SPO2) harus berada di rentang 0 - 100 %.',
        );
      }
    }
    return errors;
  }

  List<VitalWarning> get _activeWarnings {
    final list = <VitalWarning>[];
    final bp = getBPWarning(_tensiSysController.text, _tensiDiaController.text);
    if (bp != null) list.add(bp);

    final hr = getHRWarning(_nadiController.text);
    if (hr != null) list.add(hr);

    final rr = getRRWarning(_respirasiController.text);
    if (rr != null) list.add(rr);

    final temp = getTempWarning(_suhuController.text);
    if (temp != null) list.add(temp);

    final spo2 = getSpO2Warning(_spo2Controller.text);
    if (spo2 != null) list.add(spo2);

    final bmi = getBmiWarning(_beratController.text, _tinggiController.text);
    if (bmi != null) list.add(bmi);

    return list;
  }

  @override
  void dispose() {
    _tensiController.dispose();
    _tensiSysController.dispose();
    _tensiDiaController.dispose();
    _nadiController.dispose();
    _respirasiController.dispose();
    _suhuController.dispose();
    _beratController.dispose();
    _tinggiController.dispose();
    _spo2Controller.dispose();
    _keluhanController.dispose();
    _anamnesisController.dispose();
    _diagnosisSearchController.dispose();
    _diagnosisIcd9SearchController.dispose();
    _qtyController.dispose();
    _instructionController.dispose();
    _referralRsController.dispose();
    _referralPoliController.dispose();
    _antibioticDetailController.dispose();
    _medTherapyController.dispose();
    _nonMedTherapyController.dispose();
    _bmhpController.dispose();
    _referralNotesController.dispose();
    _serviceFeeController.dispose();
    _suratKeperluanController.dispose();
    _suratRiwayatPenyakitController.dispose();
    _suratSakitHariController.dispose();
    super.dispose();
  }

  void _loadPatientFromQueue(AntrianModel queue) {
    setState(() {
      _activeQueue = queue;

      // Attempt to look up the full PasienModel from the doctorPatientListProvider
      final patients = ref.read(dokterPasienListProvider);
      final match = patients.firstWhere(
        (p) =>
            p.nik == queue.nik ||
            p.nama.toLowerCase() == queue.nama.toLowerCase(),
        orElse: () => PasienModel(
          id: 'PAS-${queue.no.split('-').last}',
          nama: queue.nama,
          email: '${queue.nama.toLowerCase().replaceAll(' ', '')}@gmail.com',
          nik: queue.nik,
          tempatLahir: 'Bondowoso',
          tanggalLahir: '08 / 12 / 2000',
          jenisKelamin: 'Laki-laki',
          telepon: '08XXXXXXXXXX',
          alamat: 'Kel. KEJAYAN, Kec. PUJER, KABUPATEN BONDOWOSO',
          umur: '25 tahun',
          avatarBg: queue.avatarBg,
          history: const [],
        ),
      );

      _activePatient = match;
      _keluhanController.text = '';
      _anamnesisController.text = '';
      _selectedDiagnoses.clear();
      _diagnosisTypes.clear();
      _selectedDiagnosisType = 'Primary';
      _diagnosisSearchController.clear();
      _diagnosisIcd9SearchController.clear();
      _addedPrescriptions.clear();
      _manualPrescriptions.clear();
      _selectedApotek = null;
      _serviceFeeController.text = formatPrice(
        ref.read(landingPageProvider).defaultServiceFee,
      );
      _wantReferral = false;
      _generatedReferralNo = 'REF/2026/05/${1000 + Random().nextInt(9000)}';

      _currentStep = 1;
      _step5TabIndex = 0;
      _foodAllergy = 'Tidak Ada';
      _airAllergy = 'Tidak Ada';
      _drugAllergy = 'Tidak Ada';
      _antibioticAllergy = 'Tidak Ada';
      _antibioticDetailController.text = '';
      _medTherapyController.text = '';
      _nonMedTherapyController.text = '';
      _prognosis = 'Sembuh';
      _bmhpController.text = '';
      _referralNotesController.text = '';

      _tensiController.text = '';
      _tensiSysController.text = '';
      _tensiDiaController.text = '';
      _nadiController.text = '';
      _respirasiController.text = '';
      _suhuController.text = '';
      _beratController.text = '';
      _tinggiController.text = '';
      _spo2Controller.text = '';
    });

    // Also update the queue status to 'Memproses...' in the state notifier if it is 'Menunggu'
    if (queue.status == 'Menunggu') {
      ref
          .read(dokterAntrianListProvider.notifier)
          .updateAntrianStatus(queue.id, 'Memproses...');
    }
  }

  Future<void> _startSatuSehatSync({bool bypassValidation = false}) async {
    if (!bypassValidation) {
      if (_keluhanController.text.trim().isEmpty) {
        _showWarningDialog(
          'Form Belum Lengkap',
          'Harap isi bagian Anamnesis / Keluhan Pasien sebelum menyimpan.',
        );
        return;
      }
      final hasIcd10 = _selectedDiagnoses.any(
        (d) => RegExp(r'^[A-Z]').hasMatch(d.code),
      );
      if (!hasIcd10) {
        _showWarningDialog(
          'Form Belum Lengkap',
          'Harap tentukan Diagnosis klinis (ICD-10) untuk pasien.',
        );
        return;
      }
    }

    setState(() {
      _isSyncing = true;
      _syncSuccess = false;
      _syncStep = 'Connecting';
    });

    try {
      final queue = _activeQueue;
      final patient = _activePatient;
      final encounterId = _lastSavedEncounterId;

      if (queue == null || patient == null || encounterId == null) {
        throw Exception(
          'Antrian aktif, pasien, atau ID Rekam Medis tidak valid.',
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

      setState(() => _syncStep = 'SendingEMR');

      final ssService = SatuSehatService(
        clientId: ssConfig['client_id']?.toString(),
        clientSecret: ssConfig['client_secret']?.toString(),
        organizationId: ssConfig['organization_id']?.toString(),
        locationId: ssConfig['location_id']?.toString() ?? docSsId,
        env: ssConfig['env']?.toString(),
      );

      String? patientSsId = patient.satusehatId;
      if (patientSsId == null || patientSsId.isEmpty) {
        final nik = patient.nik;
        if (nik.isEmpty) {
          throw Exception(
            'Pasien tidak memiliki NIK yang valid untuk pendaftaran SatuSehat.',
          );
        }

        final lookup = await ssService.getPatientIdByNik(nik);
        if (lookup['status'] == true) {
          patientSsId = lookup['id'] as String;
          await SupabaseService.client
              .from('user')
              .update({'satusehat_id': patientSsId})
              .eq('id', patient.id);
          try {
            ref.read(dokterPasienListProvider.notifier).loadPatients();
          } catch (_) {}
        } else {
          throw Exception(
            'NIK Pasien tidak ditemukan di database SatuSehat Kemenkes: ${lookup['message']}',
          );
        }
      }

      setState(() => _syncStep = 'GeneratingPrescription');

      final List<Map<String, dynamic>> allRx = [];
      for (final item in _addedPrescriptions) {
        final obat = item['obat'] as ObatModel;
        allRx.add({
          'medicine_name': obat.nama,
          'quantity': item['jumlah'],
          'dosage_instructions': item['aturan'] ?? '',
          'kfa_code': obat.kfaCode,
        });
      }
      for (final item in _manualPrescriptions) {
        allRx.add({
          'medicine_name': item['nama'] ?? 'Obat Resep',
          'quantity': item['jumlah'],
          'dosage_instructions': item['aturan'] ?? '',
          'kfa_code': item['kfa_code'],
        });
      }

      final List<Map<String, dynamic>> diagTags = _selectedDiagnoses
          .map((d) => {'code': d.code, 'label': d.description})
          .toList();

      final syncRes = await ssService.sendEncounterData(
        patientId: patientSsId,
        doctorId: docSsId,
        patientName: patient.nama,
        doctorName: doctorName,
        encounterId: encounterId,
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
          .eq('id', encounterId);

      setState(() {
        _syncStep = 'Success';
        _syncSuccess = true;
        _txHash =
            ssEncounterId ?? 'TX-EMR-${Random().nextInt(900000) + 100000}';
      });
    } catch (e) {
      debugPrint('Error during SatuSehat sync: $e');
      final errorMsg = e.toString().replaceAll('Exception: ', '');

      try {
        if (_lastSavedEncounterId != null) {
          await SupabaseService.client
              .schema('private_doctor')
              .from('clinical_encounters')
              .update({
                'satusehat_sync_status': 'failed',
                'satusehat_last_error': errorMsg,
              })
              .eq('id', _lastSavedEncounterId!);
        }
      } catch (_) {}

      setState(() {
        _syncStep = 'Failed';
        _syncSuccess = false;
      });

      _showWarningDialog('Sinkronisasi SatuSehat Gagal', errorMsg);
    }
  }

  void _completeSyncAndRedirect() {
    final queue = _activeQueue;
    final patient = _activePatient;
    if (queue != null && patient != null) {
      // Transition queue status to 'Pembayaran' (since it goes to cashier next)
      ref
          .read(dokterAntrianListProvider.notifier)
          .updateAntrianStatus(queue.id, 'Pembayaran');

      // Show beautiful success toast
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF48C9B0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          content: Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Sesi EMR ${patient.nama} berhasil disimpan & disinkronkan ke SatuSehat. Pasien diarahkan ke Loket Pembayaran.',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Reset page states
    setState(() {
      _isSyncing = false;
      _syncSuccess = false;
      _activeQueue = null;
      _activePatient = null;
      _keluhanController.clear();
      _anamnesisController.clear();
      _selectedDiagnoses.clear();
      _diagnosisSearchController.clear();
      _diagnosisIcd9SearchController.clear();
      _addedPrescriptions.clear();
      _manualPrescriptions.clear();
      _selectedApotek = null;
      _serviceFeeController.text = formatPrice(
        ref.read(landingPageProvider).defaultServiceFee,
      );
      _wantReferral = false;
      _currentStep = 1;
      _step5TabIndex = 0;
      _foodAllergy = 'Tidak Ada';
      _airAllergy = 'Tidak Ada';
      _drugAllergy = 'Tidak Ada';
      _antibioticAllergy = 'Tidak Ada';
      _antibioticDetailController.clear();
      _medTherapyController.clear();
      _nonMedTherapyController.clear();
      _prognosis = 'Sembuh';
      _bmhpController.clear();
      _referralNotesController.clear();
      _wantSuratKeterangan = false;
      _suratKeteranganType = 'sehat';
      _suratKeperluanController.clear();
      _suratRiwayatPenyakitController.clear();
      _suratSakitHariController.text = '3';
      _suratSakitStartDate = DateTime.now();
      _suratSakitEndDate = DateTime.now().add(const Duration(days: 2));
    });
  }

  void _saveManualAndRedirect() {
    final queue = _activeQueue;
    final patient = _activePatient;
    if (queue != null && patient != null) {
      // Transition queue status to 'Pembayaran'
      ref
          .read(dokterAntrianListProvider.notifier)
          .updateAntrianStatus(queue.id, 'Pembayaran');

      // Show beautiful success toast
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF48C9B0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          content: Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Sesi EMR ${patient.nama} berhasil disimpan. Pasien diarahkan ke Loket Pembayaran (Kirim ke SatuSehat secara manual di Pembukuan).',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Reset page states
    setState(() {
      _isSyncing = false;
      _syncSuccess = false;
      _activeQueue = null;
      _activePatient = null;
      _keluhanController.clear();
      _anamnesisController.clear();
      _selectedDiagnoses.clear();
      _diagnosisSearchController.clear();
      _diagnosisIcd9SearchController.clear();
      _addedPrescriptions.clear();
      _manualPrescriptions.clear();
      _selectedApotek = null;
      _serviceFeeController.text = formatPrice(
        ref.read(landingPageProvider).defaultServiceFee,
      );
      _wantReferral = false;
      _currentStep = 1;
      _step5TabIndex = 0;
      _foodAllergy = 'Tidak Ada';
      _airAllergy = 'Tidak Ada';
      _drugAllergy = 'Tidak Ada';
      _antibioticAllergy = 'Tidak Ada';
      _antibioticDetailController.clear();
      _medTherapyController.clear();
      _nonMedTherapyController.clear();
      _prognosis = 'Sembuh';
      _bmhpController.clear();
      _referralNotesController.clear();
      _wantSuratKeterangan = false;
      _suratKeteranganType = 'sehat';
      _suratKeperluanController.clear();
      _suratRiwayatPenyakitController.clear();
      _suratSakitHariController.text = '3';
      _suratSakitStartDate = DateTime.now();
      _suratSakitEndDate = DateTime.now().add(const Duration(days: 2));
    });
  }

  Future<String?> _getApotekIdByName(String name) async {
    try {
      final res = await SupabaseService.client
          .from('user')
          .select('id')
          .eq('name', name)
          .eq('role', 'apotek')
          .maybeSingle();
      if (res != null) {
        return res['id'] as String;
      }
    } catch (_) {}
    return null;
  }

  Future<bool> _saveEMRToDatabase() async {
    final queue = _activeQueue;
    if (queue == null) return false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Row(
          children: [
            CircularProgressIndicator(color: ref.read(landingPageProvider.notifier).getPrimaryColor()),
            const SizedBox(width: 20),
            Text(
              'Menyimpan EMR ke database...',
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );

    try {
      final userState = ref.read(landingPageProvider);
      final userId = userState.activeDoctorId;
      final doctorId = (userId == 'mock-id-1234567890' || userId == null)
          ? '8f93471a-74f8-486b-8e85-4002dc44c11c'
          : userId;

      final double subtotalObat = _addedPrescriptions.fold<double>(
        0,
        (sum, item) =>
            sum + ((item["obat"] as ObatModel).hargaSatuan * item["jumlah"]),
      );
      final double serviceFee = _serviceFeeController.text.isEmpty
          ? ref.read(landingPageProvider).defaultServiceFee
          : parseFormattedPrice(_serviceFeeController.text);
      final double totalBill = serviceFee + subtotalObat;

      String? recommendedApotekId;
      if (_selectedApotek != null) {
        recommendedApotekId = await _getApotekIdByName(_selectedApotek!);
      }

      final db = SupabaseService();
      _lastSavedEncounterId = await db.saveClinicalEncounter(
        queueId: queue.id,
        doctorId: doctorId,
        serviceFee: serviceFee,
        totalBill: totalBill,
        complaint: _keluhanController.text,
        anamnesis: _anamnesisController.text,
        foodAllergy: _foodAllergy,
        airAllergy: _airAllergy,
        drugAllergy: _drugAllergy,
        antibioticAllergy: _antibioticAllergy,
        medTherapy: _medTherapyController.text,
        nonMedTherapy: _nonMedTherapyController.text,
        prognosis: _prognosis,
        bmhp: _bmhpController.text,
        weight: _beratController.text,
        height: _tinggiController.text,
        spo2: _spo2Controller.text,
        temperature: _suhuController.text,
        bloodPressure: _tensiController.text,
        heartRate: _nadiController.text,
        respiration: _respirasiController.text,
        diagnoses: _selectedDiagnoses
            .map((d) => {'code': d.code, 'description': d.description})
            .toList(),
        prescriptions: _addedPrescriptions,
        manualPrescriptions: _manualPrescriptions,
        recommendedApotekId: recommendedApotekId,
        isReferral: _wantReferral,
        referralRs: _referralRsController.text,
        referralPoli: _referralPoliController.text,
        referralNotes: _referralNotesController.text,
        referralNo: _generatedReferralNo,
        suratKeteranganType: _wantSuratKeterangan ? _suratKeteranganType : null,
        suratKeperluan: _wantSuratKeterangan ? _suratKeperluanController.text : null,
        suratRiwayatPenyakit: _wantSuratKeterangan ? _suratRiwayatPenyakitController.text : null,
        suratSakitHari: _wantSuratKeterangan && _suratKeteranganType == 'sakit' ? (int.tryParse(_suratSakitHariController.text) ?? 3) : null,
        suratSakitMulai: _wantSuratKeterangan && _suratKeteranganType == 'sakit' && _suratSakitStartDate != null ? _suratSakitStartDate!.toUtc().toIso8601String() : null,
        suratSakitSelesai: _wantSuratKeterangan && _suratKeteranganType == 'sakit' && _suratSakitEndDate != null ? _suratSakitEndDate!.toUtc().toIso8601String() : null,
      );

      Navigator.pop(context);
      return true;
    } catch (e) {
      Navigator.pop(context);
      _showWarningDialog('Gagal Menyimpan EMR', e.toString());
      return false;
    }
  }

  void _showWarningDialog(String title, String message) {
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
              size: 22,
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: GoogleFonts.outfit(
            fontSize: 12,
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

  void _showVitalValidationDialog({
    required String title,
    required List<String> errors,
    required VoidCallback onLanjutkan,
  }) {
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
              size: 22,
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 450,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Beberapa input vital sign berada di luar rentang normal/sehat:',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: Colors.grey[800],
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ...errors.map(
                (error) => Padding(
                  padding: const EdgeInsets.only(bottom: 6.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '• ',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                      ),
                      Expanded(
                        child: Text(
                          error,
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Tetap lanjutkan?',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              onLanjutkan();
            },
            child: Text(
              'Lanjutkan',
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: Colors.grey[600],
              ),
            ),
          ),
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

  void _showReviewAndSubmitDialog(bool autoSyncEnabled) {
    final patient = _activePatient;
    if (patient == null) return;

    final hasIcd10 = _selectedDiagnoses.any(
      (d) => RegExp(r'^[A-Z]').hasMatch(d.code),
    );
    final vitalErrors = _validateVitalSigns();

    final warningChips = <Widget>[];
    if (_keluhanController.text.trim().isEmpty) {
      warningChips.add(
        ActionChip(
          avatar: const Icon(
            Icons.warning_amber_rounded,
            size: 12,
            color: Colors.orange,
          ),
          label: Text(
            'Anamnesis Kosong',
            style: GoogleFonts.outfit(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.orange[800],
            ),
          ),
          backgroundColor: Colors.orange[50],
          side: const BorderSide(color: Colors.orange),
          onPressed: () {
            Navigator.pop(context);
            setState(() {
              _currentStep = 2;
            });
          },
        ),
      );
    }

    if (!hasIcd10) {
      warningChips.add(
        ActionChip(
          avatar: const Icon(
            Icons.warning_amber_rounded,
            size: 12,
            color: Colors.red,
          ),
          label: Text(
            'Diagnosis ICD-10 Kosong',
            style: GoogleFonts.outfit(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.red[800],
            ),
          ),
          backgroundColor: Colors.red[50],
          side: const BorderSide(color: Colors.red),
          onPressed: () {
            Navigator.pop(context);
            setState(() {
              _currentStep = 4;
            });
          },
        ),
      );
    }

    if (vitalErrors.isNotEmpty) {
      warningChips.add(
        ActionChip(
          avatar: const Icon(
            Icons.warning_amber_rounded,
            size: 12,
            color: Colors.red,
          ),
          label: Text(
            'Vital Sign Tidak Valid',
            style: GoogleFonts.outfit(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.red[800],
            ),
          ),
          backgroundColor: Colors.red[50],
          side: const BorderSide(color: Colors.red),
          onPressed: () {
            Navigator.pop(context);
            setState(() {
              _currentStep = 4;
            });
          },
        ),
      );
    }

    showDialog(
      context: context,
      builder: (ctx) {
        final double subtotalObat = _addedPrescriptions.fold<double>(
          0,
          (sum, item) =>
              sum + ((item["obat"] as ObatModel).hargaSatuan * item["jumlah"]),
        );
        final double serviceFee = _serviceFeeController.text.isEmpty
            ? ref.read(landingPageProvider).defaultServiceFee
            : parseFormattedPrice(_serviceFeeController.text);
        final double totalBill = serviceFee + subtotalObat;

        return AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Review & Simpan EMR',
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: Container(
            width: 500,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.6,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Identitas Pasien
                  _buildReviewSectionTitle('Identitas Pasien'),
                  _buildReviewRow('Nama Pasien', patient.nama),
                  _buildReviewRow('Umur', patient.umur),
                  const Divider(height: 20),

                  // 2. Anamnesa
                  _buildReviewSectionTitle('Anamnesis / Keluhan'),
                  Text(
                    _keluhanController.text.isNotEmpty
                        ? _keluhanController.text
                        : '—',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      color: Colors.grey[700],
                    ),
                  ),
                  const Divider(height: 20),

                  // 3. Vital Signs
                  _buildReviewSectionTitle('Vital Signs'),
                  _buildReviewRow(
                    'Tekanan Darah',
                    _tensiController.text.isNotEmpty
                        ? '${_tensiController.text} mmHg'
                        : '— mmHg',
                  ),
                  _buildReviewRow(
                    'Suhu Tubuh',
                    _suhuController.text.isNotEmpty
                        ? '${_suhuController.text} °C'
                        : '— °C',
                  ),
                  _buildReviewRow(
                    'Detak Jantung',
                    _nadiController.text.isNotEmpty
                        ? '${_nadiController.text} bpm'
                        : '— bpm',
                  ),
                  _buildReviewRow(
                    'Laju Pernafasan',
                    _respirasiController.text.isNotEmpty
                        ? '${_respirasiController.text} x/menit'
                        : '— x/menit',
                  ),
                  _buildReviewRow(
                    'Berat / Tinggi',
                    '${_beratController.text.isNotEmpty ? _beratController.text : '—'} kg / ${_tinggiController.text.isNotEmpty ? _tinggiController.text : '—'} cm',
                  ),
                  _buildReviewRow(
                    'Saturasi O2',
                    _spo2Controller.text.isNotEmpty
                        ? '${_spo2Controller.text} %'
                        : '— %',
                  ),
                  const Divider(height: 20),

                  // 4. Diagnosis
                  _buildReviewSectionTitle('Diagnosis (ICD-10)'),
                  Text(
                    _selectedDiagnoses.isNotEmpty
                        ? _selectedDiagnoses
                              .map((d) => '${d.code} - ${d.description}')
                              .join('\n')
                        : '—',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      color: Colors.grey[700],
                    ),
                  ),
                  const Divider(height: 20),

                  // 5. Resep & Terapi
                  _buildReviewSectionTitle('Resep & Terapi'),
                  if (_addedPrescriptions.isEmpty &&
                      _manualPrescriptions.isEmpty &&
                      !_wantReferral)
                    Text(
                      '—',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        color: Colors.grey[700],
                      ),
                    )
                  else ...[
                    ..._addedPrescriptions.map((item) {
                      final obat = item["obat"] as ObatModel;
                      return _buildReviewRow(
                        obat.nama,
                        '${item["jumlah"]} unit (${item["aturan"]})',
                      );
                    }),
                    ..._manualPrescriptions.map((item) {
                      return _buildReviewRow(
                        item["nama"] ?? 'Obat Manual',
                        '${item["jumlah"]} unit (${item["aturan"]})',
                      );
                    }),
                    if (_wantReferral) ...[
                      const SizedBox(height: 4),
                      _buildReviewRow(
                        'Rujukan Ke',
                        '${_referralRsController.text} (${_referralPoliController.text})',
                        isBold: true,
                      ),
                    ],
                  ],
                  const Divider(height: 20),

                  // 6. Billing
                  _buildReviewSectionTitle('Total Tagihan'),
                  _buildReviewRow('Jasa Layanan', 'Rp ${formatPrice(serviceFee)}'),
                  _buildReviewRow(
                    'Subtotal Obat',
                    'Rp ${formatPrice(subtotalObat)}',
                  ),
                  _buildReviewRow(
                    'Total Tagihan',
                    'Rp ${formatPrice(totalBill)}',
                    isBold: true,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (warningChips.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 8.0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Peringatan Validasi (Klik chip untuk lompat ke form):',
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.red[700],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(spacing: 8, runSpacing: 6, children: warningChips),
                      ],
                    ),
                  ),
                  const Divider(),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        final success = await _saveEMRToDatabase();
                        if (success) {
                          if (autoSyncEnabled) {
                            _startSatuSehatSync(bypassValidation: true);
                          } else {
                            _saveManualAndRedirect();
                          }
                        }
                      },
                      child: Text(
                        'Lanjutkan dan Kirim',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
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
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildReviewSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.outfit(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF48C9B0),
        ),
      ),
    );
  }

  Widget _buildReviewRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey[600]),
          ),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: isBold ? const Color(0xFF1B0C3C) : Colors.grey[800],
            ),
          ),
        ],
      ),
    );
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

    final queueList = ref.watch(dokterAntrianListProvider);
    final drugList = ref.watch(dokterObatListProvider);

    final isMobile = MediaQuery.of(context).size.width < 768;

    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // EMR Header Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              margin: const EdgeInsets.only(bottom: 20),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: purple.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.assignment_rounded,
                      color: purple,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pemeriksaan & RME'.tr(state),
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: textColor,
                          ),
                        ),
                        Text(
                          'Sesi pencatatan rekam medis elektronik aktif dr. Agoes Soetanto'
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
                ],
              ),
            ),

            // Main Two Column Layout
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. LEFT COLUMN: Active Session Console (EMR fields)
                Expanded(
                  flex: 7,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Patient selection bar — shown above the card when active
                      if (_activeQueue != null)
                        _buildPatientSelectionBar(
                          cardBg,
                          textColor,
                          subtitleColor,
                          borderColor,
                          purple,
                          activeGreen,
                          inputBg,
                          queueList,
                        ),
                      if (_activeQueue != null) const SizedBox(height: 12),

                      _activeQueue == null
                          ? _buildEmptyState(
                              cardBg,
                              textColor,
                              subtitleColor,
                              borderColor,
                              purple,
                              queueList,
                            )
                          : _buildActiveSessionConsole(
                              cardBg,
                              textColor,
                              subtitleColor,
                              borderColor,
                              inputBg,
                              purple,
                              activeGreen,
                              drugList,
                            ),
                    ],
                  ),
                ),

                if (!isMobile) const SizedBox(width: 24),

                // 2. RIGHT COLUMN: Today's Queue Sidebar
                if (!isMobile)
                  SizedBox(
                    width: 320,
                    child: _buildQueueSidebar(
                      cardBg,
                      textColor,
                      subtitleColor,
                      borderColor,
                      purple,
                      activeGreen,
                      queueList,
                    ),
                  ),
              ],
            ),
          ],
        ),

        // 3. SATUSEHAT SYNCHRONIZATION GLASS-MODAL OVERLAY
        if (_isSyncing)
          _buildSatuSehatSyncModal(
            cardBg,
            textColor,
            subtitleColor,
            borderColor,
            purple,
            activeGreen,
          ),
      ],
    );
  }

  // ─── Component: Empty State Panel ──────────────────────────────────────────

  Widget _buildEmptyState(
    Color cardBg,
    Color text,
    Color subtitle,
    Color border,
    Color purple,
    List<AntrianModel> queues,
  ) {
    final waitingQueues = queues.where((q) => q.status == 'Menunggu').toList();

    return Container(
      height: 600,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 60),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Graphic Circle pulsing
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: purple.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(Icons.assignment_ind_outlined, size: 36, color: purple),
          ),
          const SizedBox(height: 24),
          Text(
            'Belum Ada Sesi Pemeriksaan Aktif',
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: text,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Pilih salah satu pasien di antrean sebelah kanan untuk memulai diagnosa RME.',
            style: GoogleFonts.outfit(
              fontSize: 11,
              color: subtitle,
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          if (waitingQueues.isNotEmpty)
            ElevatedButton(
              onPressed: () => _loadPatientFromQueue(waitingQueues.first),
              style: ElevatedButton.styleFrom(
                backgroundColor: purple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.play_circle_outline_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Panggil Pasien Berikutnya (${waitingQueues.first.no})',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: subtitle.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Semua antrean hari ini telah diproses.',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  color: subtitle,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─── Component: Patient Selection Bar (above card) ─────────────────────────

  Widget _buildPatientSelectionBar(
    Color cardBg,
    Color text,
    Color subtitle,
    Color border,
    Color purple,
    Color activeGreen,
    Color inputBg,
    List<AntrianModel> queueList,
  ) {
    final patient = _activePatient!;
    final queue = _activeQueue!;

    // Other waiting queues (excluding active)
    final otherQueues = queueList
        .where((q) => q.status == 'Menunggu' && q.id != queue.id)
        .toList();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: purple.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: patient.avatarBg.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              patient.nama
                  .substring(0, min(patient.nama.length, 2))
                  .toUpperCase(),
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: patient.avatarBg,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Patient info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text(
                      patient.nama,
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: text,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color:
                            (patient.id.startsWith('PAS-SS-')
                                    ? activeGreen
                                    : Colors.amber)
                                .withOpacity(0.12),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            patient.id.startsWith('PAS-SS-')
                                ? Icons.verified_rounded
                                : Icons.warning_amber_rounded,
                            size: 8,
                            color: patient.id.startsWith('PAS-SS-')
                                ? activeGreen
                                : Colors.amber[700],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            patient.id.startsWith('PAS-SS-')
                                ? 'SATUSEHAT VERIFIED'
                                : 'BELUM TERINTEGRASI',
                            style: GoogleFonts.outfit(
                              fontSize: 6,
                              fontWeight: FontWeight.w900,
                              color: patient.id.startsWith('PAS-SS-')
                                  ? activeGreen
                                  : Colors.amber[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                    ..._activeWarnings.map((w) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: w.bgColor,
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(color: w.borderColor),
                        ),
                        child: Text(
                          w.label,
                          style: GoogleFonts.outfit(
                            fontSize: 7.5,
                            fontWeight: FontWeight.w900,
                            color: w.color,
                          ),
                        ),
                      );
                    }),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'No. Antrean: ${queue.no}  •  NIK: ${patient.nik}  •  ${patient.jenisKelamin}  •  ${patient.umur}',
                  style: GoogleFonts.outfit(
                    fontSize: 9.5,
                    color: subtitle,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          // Switch patient dropdown (if others waiting)
          if (otherQueues.isNotEmpty) ...[
            const SizedBox(width: 8),
            PopupMenuButton<AntrianModel>(
              tooltip: 'Ganti Pasien',
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              offset: const Offset(0, 40),
              itemBuilder: (ctx) => otherQueues
                  .map(
                    (q) => PopupMenuItem<AntrianModel>(
                      value: q,
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: q.avatarBg.withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              q.nama
                                  .substring(0, min(q.nama.length, 2))
                                  .toUpperCase(),
                              style: GoogleFonts.outfit(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                color: q.avatarBg,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  q.nama,
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    color: text,
                                  ),
                                ),
                                Text(
                                  '${q.no}  •  ${q.tipe}',
                                  style: GoogleFonts.outfit(
                                    fontSize: 9,
                                    color: subtitle,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
              onSelected: (q) => _loadPatientFromQueue(q),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: purple.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: purple.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.swap_horiz_rounded, size: 14, color: purple),
                    const SizedBox(width: 4),
                    Text(
                      'Ganti (${otherQueues.length})',
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: purple,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(width: 6),
          // Close / End session
          IconButton(
            icon: Icon(Icons.close_rounded, size: 18, color: subtitle),
            tooltip: 'Akhiri Sesi',
            onPressed: () {
              setState(() {
                _activeQueue = null;
                _activePatient = null;
              });
            },
          ),
        ],
      ),
    );
  }

  // ─── Component: Active Session Console EMR Form ────────────────────────────

  Widget _buildActiveSessionConsole(
    Color cardBg,
    Color text,
    Color subtitle,
    Color border,
    Color inputBg,
    Color purple,
    Color activeGreen,
    List<ObatModel> drugList,
  ) {
    final state = ref.watch(landingPageProvider);
    final criticalWarnings = _activeWarnings
        .where((w) => w.isCritical)
        .toList();
    final hasCritical = criticalWarnings.isNotEmpty;

    return Container(
      height: 620,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: border),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stepper indicator header
          _buildStepperHeader(
            text,
            subtitle,
            purple,
            border,
            state.appearance == 'dark',
          ),
          const SizedBox(height: 16),

          if (hasCritical) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFC0392B),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFC0392B).withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.gpp_bad_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'PERINGATAN KRITIS: ${criticalWarnings.map((w) => w.label).join(", ")} terdeteksi. Harap segera lakukan penanganan medis!',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Stepper form body
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: _buildCurrentStepContent(
                text,
                subtitle,
                border,
                inputBg,
                purple,
                activeGreen,
                drugList,
              ),
            ),
          ),

          // Pinned Billing Bar (Step 5 only)
          if (_currentStep == 5) ...[
            const SizedBox(height: 12),
            _buildBillingSummaryBar(text, subtitle, border, inputBg),
          ],

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(),
          ),

          // Stepper Navigation Footer
          _buildStepNavigation(
            text,
            subtitle,
            border,
            purple,
            activeGreen,
            state.satusehatAutoSync,
          ),
        ],
      ),
    );
  }

  Widget _buildStepperHeader(
    Color textCol,
    Color subtitleCol,
    Color purple,
    Color borderCol,
    bool isDark,
  ) {
    final state = ref.read(landingPageProvider);
    final steps = [
      {'label': 'Pasien', 'icon': Icons.person_rounded},
      {'label': 'Anamnesa', 'icon': Icons.assignment_rounded},
      {'label': 'Kondisi', 'icon': Icons.info_outline_rounded},
      {'label': 'Vital', 'icon': Icons.favorite_rounded},
      {'label': 'Resep', 'icon': Icons.medication_rounded},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: borderCol.withOpacity(0.02),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderCol),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(steps.length, (idx) {
          final stepNum = idx + 1;
          final isDone = stepNum < _currentStep;
          final isActive = stepNum == _currentStep;
          final step = steps[idx];

          return Expanded(
            child: Row(
              children: [
                // Circle
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isDone
                        ? purple
                        : (isActive
                              ? purple.withOpacity(0.12)
                              : borderCol.withOpacity(0.05)),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDone || isActive ? purple : borderCol,
                      width: 1.5,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: isDone
                      ? const Icon(Icons.check, color: Colors.white, size: 12)
                      : Text(
                          '$stepNum',
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: isDone
                                ? Colors.white
                                : (isActive ? purple : subtitleCol),
                          ),
                        ),
                ),
                const SizedBox(width: 6),
                // Label
                Text(
                  (step['label'] as String).tr(state),
                  style: GoogleFonts.outfit(
                    fontSize: 9,
                    fontWeight: isActive || isDone
                        ? FontWeight.w900
                        : FontWeight.bold,
                    color: isActive ? purple : (isDone ? textCol : subtitleCol),
                  ),
                ),
                // Connector line
                if (idx < steps.length - 1)
                  Expanded(
                    child: Container(
                      height: 1.5,
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      color: isDone ? purple : borderCol,
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCurrentStepContent(
    Color text,
    Color subtitle,
    Color border,
    Color inputBg,
    Color purple,
    Color activeGreen,
    List<ObatModel> drugList,
  ) {
    switch (_currentStep) {
      case 1:
        return _buildStep1(
          text,
          subtitle,
          border,
          inputBg,
          activeGreen,
          purple,
        );
      case 2:
        return _buildStep2(text, subtitle, border, inputBg, purple);
      case 3:
        return _buildStep3(text, subtitle, border, inputBg, purple);
      case 4:
        return _buildStep4(
          text,
          subtitle,
          border,
          inputBg,
          purple,
          activeGreen,
        );
      case 5:
      default:
        return _buildStep5(
          text,
          subtitle,
          border,
          inputBg,
          purple,
          activeGreen,
          drugList,
        );
    }
  }

  Future<Map<String, dynamic>> _fetchEncounterDetails(String queueId) async {
    final db = SupabaseService();
    // 1. Fetch queue to get doctorId & date_queue
    final queue = await SupabaseService.client
        .from('v_queues')
        .select('*')
        .eq('id', queueId)
        .maybeSingle();

    final doctorId = queue?['id_doctor'] as String?;
    String doctorName = 'dr. Agoes Soetanto';
    if (doctorId != null && doctorId.isNotEmpty) {
      final docUser = await db.fetchUserById(doctorId);
      if (docUser != null) {
        doctorName = docUser['name'] ?? doctorName;
      }
    }

    // 2. Fetch clinical encounter
    final ce = await SupabaseService.client
        .schema('private_doctor')
        .from('clinical_encounters')
        .select('*')
        .eq('id_queue', queueId)
        .maybeSingle();

    if (ce == null) {
      return {
        'doctorName': doctorName,
        'date': queue?['date_queue'] ?? '-',
        'encounter': null,
      };
    }

    final encounterId = ce['id'] as String;

    // 3. Fetch anamnesis
    final anamnesis = await SupabaseService.client
        .schema('private_doctor')
        .from('anamnesis_ecounter')
        .select('*')
        .eq('id_clinical_ecounter', encounterId)
        .maybeSingle();

    // 4. Fetch vitals
    final vitals = await SupabaseService.client
        .schema('private_doctor')
        .from('vital_signs')
        .select('*')
        .eq('id_clinical_ecounter', encounterId)
        .maybeSingle();

    // 5. Fetch diagnoses
    final diagnoses = await SupabaseService.client
        .schema('private_doctor')
        .from('icdx_ecounter')
        .select('*')
        .eq('id_clinical_ecounters', encounterId);

    // 6. Fetch medicines
    final List<Map<String, dynamic>> medicinesList = [];
    final medicinesRes = await SupabaseService.client
        .schema('private_doctor')
        .from('medicine_ecounter')
        .select('quantity, id_detail_medicine')
        .eq('id_clinical_encounters', encounterId);

    for (final medRow in medicinesRes) {
      final qty = double.tryParse(medRow['quantity']?.toString() ?? '0') ?? 0.0;
      final detailMedId = medRow['id_detail_medicine'];
      if (detailMedId != null) {
        final dmRes = await SupabaseService.client
            .schema('private_doctor')
            .from('detail_medicine')
            .select('id_medicine')
            .eq('id', detailMedId)
            .maybeSingle();

        if (dmRes != null) {
          final medId = dmRes['id_medicine'];
          String medicineName = 'Obat';
          if (medId != null) {
            final mRes = await SupabaseService.client
                .schema('private_doctor')
                .from('medicine')
                .select('medicine_name')
                .eq('id', medId)
                .maybeSingle();
            if (mRes != null) {
              medicineName = mRes['medicine_name']?.toString() ?? 'Obat';
            }
          }
          medicinesList.add({
            'name': medicineName,
            'quantity': qty,
          });
        }
      }
    }

    // 7. Fetch manual prescriptions
    try {
      final epRes = await SupabaseService.client
          .schema('private_doctor')
          .from('electronic_prescriptions')
          .select('*, electronic_prescription_items(*)')
          .eq('id_clinical_encounter', encounterId)
          .maybeSingle();

      if (epRes != null) {
        final items = epRes['electronic_prescription_items'] as List<dynamic>?;
        if (items != null) {
          for (final item in items) {
            if (item['id_catalog_item'] == null) {
              final qty = double.tryParse(item['quantity']?.toString() ?? '1') ?? 1.0;
              medicinesList.add({
                'name': item['medicine_name']?.toString() ?? 'Obat Resep',
                'quantity': qty,
              });
            }
          }
        }
      }
    } catch (_) {}

    return {
      'doctorName': doctorName,
      'date': queue?['date_queue'] ?? '-',
      'encounter': ce,
      'anamnesis': anamnesis,
      'vitals': vitals,
      'diagnoses': diagnoses,
      'medicines': medicinesList,
    };
  }

  void _showEncounterDetailDialog(BuildContext context, String queueId, String formattedDate, PasienModel patient, bool isDark) {
    final themeAccent = ref.read(landingPageProvider.notifier).getPrimaryColor();
    final cardBg = isDark ? const Color(0xFF161619) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1B0C3C);
    final subtitleColor = isDark ? Colors.grey[400]! : const Color(0xFF6F6A8A);
    final borderColor = isDark ? const Color(0xFF252528) : const Color(0xFFECEEF2);
    final inputBg = isDark ? const Color(0xFF1E1E22) : const Color(0xFFF6F8FA);

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.4),
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          backgroundColor: cardBg,
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            width: 480,
            child: FutureBuilder<Map<String, dynamic>>(
              future: _fetchEncounterDetails(queueId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Container(
                    padding: const EdgeInsets.all(24),
                    child: SkeletonScope(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SkeletonBox(height: 14, width: 100),
                          const SizedBox(height: 8),
                          const SkeletonBox(height: 50, width: double.infinity),
                          const SizedBox(height: 20),
                          const SkeletonBox(height: 14, width: 140),
                          const SizedBox(height: 8),
                          const SkeletonBox(height: 60, width: double.infinity),
                          const SizedBox(height: 20),
                          const SkeletonBox(height: 14, width: 120),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(child: const SkeletonBox(height: 30)),
                              const SizedBox(width: 8),
                              Expanded(child: const SkeletonBox(height: 30)),
                              const SizedBox(width: 8),
                              Expanded(child: const SkeletonBox(height: 30)),
                            ],
                          ),
                          const SizedBox(height: 20),
                          const SkeletonBox(height: 14, width: 80),
                          const SizedBox(height: 8),
                          const SkeletonBox(height: 40, width: double.infinity),
                        ],
                      ),
                    ),
                  );
                }

                if (snapshot.hasError || !snapshot.hasData) {
                  return Container(
                    height: 200,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Gagal memuat detail pemeriksaan.',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.redAccent,
                      ),
                    ),
                  );
                }

                final data = snapshot.data!;
                final ce = data['encounter'];
                final doctorName = data['doctorName'] as String;

                if (ce == null) {
                  return Container(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Pemeriksaan Rutin',
                          style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Pemeriksaan pada tanggal $formattedDate oleh $doctorName tidak memiliki catatan EMR terperinci.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(fontSize: 12, color: subtitleColor),
                        ),
                        const SizedBox(height: 16),
                        CustomButton(
                          text: 'Tutup',
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  );
                }

                final anamnesis = data['anamnesis'];
                final vitals = data['vitals'];
                final diagnoses = data['diagnoses'] as List<dynamic>;
                final medicines = data['medicines'] as List<dynamic>;
                final isRujukan = ce['is_rujukan'] == true;

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      color: isDark ? const Color(0xFF1A1A1E) : const Color(0xFFF8F5FF),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: themeAccent.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.assignment_turned_in_rounded,
                              color: themeAccent,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Hasil Pemeriksaan Medis',
                                  style: GoogleFonts.outfit(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    color: textColor,
                                  ),
                                ),
                                Text(
                                  '$formattedDate • Pasien: ${patient.nama}',
                                  style: GoogleFonts.outfit(
                                    fontSize: 10,
                                    color: subtitleColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () => Navigator.of(ctx).pop(),
                          ),
                        ],
                      ),
                    ),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildDetailSectionTitle('Dokter Pemeriksa', textColor),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: inputBg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: borderColor),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: themeAccent.withOpacity(0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(Icons.person_rounded, color: themeAccent, size: 16),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          doctorName,
                                          style: GoogleFonts.outfit(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: textColor,
                                          ),
                                        ),
                                        Text(
                                          'Dokter Pemeriksa',
                                          style: GoogleFonts.outfit(
                                            fontSize: 9,
                                            color: subtitleColor.withOpacity(0.8),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (anamnesis != null) ...[
                              _buildDetailSectionTitle('Keluhan & Anamnesis', textColor),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: inputBg,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: borderColor),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (anamnesis['main_complaint'] != null && anamnesis['main_complaint'].toString().isNotEmpty) ...[
                                      Text(
                                        'Keluhan Utama:',
                                        style: GoogleFonts.outfit(fontSize: 9.5, fontWeight: FontWeight.bold, color: subtitleColor),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        anamnesis['main_complaint'],
                                        style: GoogleFonts.outfit(fontSize: 11.5, color: textColor),
                                      ),
                                      const SizedBox(height: 10),
                                    ],
                                    if (anamnesis['anamnesis'] != null && anamnesis['anamnesis'].toString().isNotEmpty) ...[
                                      Text(
                                        'Catatan Anamnesis:',
                                        style: GoogleFonts.outfit(fontSize: 9.5, fontWeight: FontWeight.bold, color: subtitleColor),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        anamnesis['anamnesis'],
                                        style: GoogleFonts.outfit(fontSize: 11.5, color: textColor),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                            if (vitals != null) ...[
                              _buildDetailSectionTitle('Tanda-tanda Vital', textColor),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  if (vitals['blood_pressure'] != null && vitals['blood_pressure'].toString().isNotEmpty)
                                    _buildVitalChip('Tensi', '${vitals['blood_pressure']} mmHg', Icons.speed_rounded, themeAccent, isDark),
                                  if (vitals['body_temperature'] != null && vitals['body_temperature'].toString().isNotEmpty)
                                    _buildVitalChip('Suhu', '${vitals['body_temperature']} °C', Icons.thermostat_rounded, themeAccent, isDark),
                                  if (vitals['heart_rate'] != null && vitals['heart_rate'].toString().isNotEmpty)
                                    _buildVitalChip('Nadi', '${vitals['heart_rate']} bpm', Icons.favorite_rounded, themeAccent, isDark),
                                  if (vitals['oxygen_saturation'] != null && vitals['oxygen_saturation'].toString().isNotEmpty)
                                    _buildVitalChip('SpO2', '${vitals['oxygen_saturation']} %', Icons.bubble_chart_rounded, themeAccent, isDark),
                                  if (vitals['body_weight'] != null && vitals['body_weight'].toString().isNotEmpty)
                                    _buildVitalChip('Berat', '${vitals['body_weight']} kg', Icons.monitor_weight_rounded, themeAccent, isDark),
                                  if (vitals['body_height'] != null && vitals['body_height'].toString().isNotEmpty)
                                    _buildVitalChip('Tinggi', '${vitals['body_height']} cm', Icons.height_rounded, themeAccent, isDark),
                                ],
                              ),
                              const SizedBox(height: 16),
                            ],
                            if (diagnoses.isNotEmpty) ...[
                              _buildDetailSectionTitle('Diagnosis (ICD-10)', textColor),
                              Column(
                                children: diagnoses.map((diag) {
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 6),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF1E1E22) : const Color(0xFFF9F9FB),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: borderColor),
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.redAccent.withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            diag['icdx_code'] ?? '',
                                            style: GoogleFonts.outfit(
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.redAccent,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            diag['description'] ?? '',
                                            style: GoogleFonts.outfit(fontSize: 11, color: textColor, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 16),
                            ],
                            if (medicines.isNotEmpty) ...[
                              _buildDetailSectionTitle('Resep Obat', textColor),
                              Column(
                                children: medicines.map((med) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: Row(
                                      children: [
                                        Icon(Icons.medication_rounded, size: 14, color: themeAccent),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            med['name'],
                                            style: GoogleFonts.outfit(fontSize: 11.5, color: textColor, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        Text(
                                          '${med['quantity'].toString().replaceAll('.0', '')} unit',
                                          style: GoogleFonts.outfit(fontSize: 11, color: subtitleColor, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 16),
                            ],
                            if (isRujukan) ...[
                              _buildDetailSectionTitle('Surat Rujukan', textColor),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.blueAccent.withOpacity(0.06),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.blueAccent.withOpacity(0.15)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.launch_rounded, size: 14, color: Colors.blueAccent),
                                        const SizedBox(width: 8),
                                        Text(
                                          'RUJUKAN OUT PATIENT',
                                          style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'RS Rujukan: ${ce['rujukan_rumah_sakit'] ?? '-'}',
                                      style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: textColor),
                                    ),
                                    Text(
                                      'Poli Rujukan: ${ce['rujukan_poli'] ?? '-'}',
                                      style: GoogleFonts.outfit(fontSize: 10, color: subtitleColor, fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      'Nomor Rujukan: ${ce['rujukan_nomor'] ?? '-'}',
                                      style: GoogleFonts.outfit(fontSize: 10, color: subtitleColor, fontWeight: FontWeight.bold),
                                    ),
                                    if (ce['rujukan_catatan'] != null && ce['rujukan_catatan'].toString().isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        'Catatan Rujukan: ${ce['rujukan_catatan']}',
                                        style: GoogleFonts.outfit(fontSize: 10.5, fontStyle: FontStyle.italic, color: textColor),
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
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailSectionTitle(String title, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 2),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.outfit(
          fontSize: 8.5,
          fontWeight: FontWeight.w900,
          color: textColor.withOpacity(0.5),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildVitalChip(String label, String value, IconData icon, Color accent, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E22) : const Color(0xFFF5F6F8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? const Color(0xFF252528) : const Color(0xFFECEEF2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: accent),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: GoogleFonts.outfit(fontSize: 10, color: isDark ? Colors.grey[400] : const Color(0xFF6F6A8A)),
          ),
          Text(
            value,
            style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF1B0C3C)),
          ),
        ],
      ),
    );
  }

  Widget _buildStep1(
    Color textCol,
    Color subtitleCol,
    Color borderCol,
    Color inputBg,
    Color activeGreen,
    Color purple,
  ) {
    final patient = _activePatient!;
    final isDark = ref.read(landingPageProvider).appearance == 'dark';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // SatuSehat ID check panel
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: patient.id.startsWith('PAS-SS-')
                ? activeGreen.withOpacity(0.08)
                : Colors.amber.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: patient.id.startsWith('PAS-SS-')
                  ? activeGreen
                  : Colors.amber,
            ),
          ),
          child: Row(
            children: [
              Icon(
                patient.id.startsWith('PAS-SS-')
                    ? Icons.verified_user_rounded
                    : Icons.warning_amber_rounded,
                color: patient.id.startsWith('PAS-SS-')
                    ? activeGreen
                    : Colors.amber,
                size: 18,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      patient.id.startsWith('PAS-SS-')
                          ? 'SatuSehat Terhubung'
                          : 'Belum Terhubung ke SatuSehat',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: patient.id.startsWith('PAS-SS-')
                            ? activeGreen
                            : Colors.amber[800]!,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      patient.id.startsWith('PAS-SS-')
                          ? 'ID SatuSehat pasien valid: ${patient.id}'
                          : 'Gunakan tombol Ambil ID untuk mensinkronkan pasien dengan NIK.',
                      style: GoogleFonts.outfit(
                        fontSize: 9.5,
                        color: subtitleCol,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              if (!patient.id.startsWith('PAS-SS-'))
                ElevatedButton(
                  onPressed: () {
                    // Simulate fetching EMR ID
                    setState(() {
                      _activePatient = patient.copyWith(
                        id: 'PAS-SS-${100000 + Random().nextInt(900000)}',
                      );
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('ID SatuSehat berhasil disinkronkan!'),
                        backgroundColor: activeGreen,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  child: Text(
                    'Ambil ID',
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Patient Details Card Grid
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: borderCol.withOpacity(0.02),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderCol),
          ),
          child: Column(
            children: [
              _buildPatientRow(
                'Nama Lengkap',
                patient.nama,
                textCol,
                subtitleCol,
              ),
              const Divider(height: 12),
              _buildPatientRow(
                'No. Rekam Medis',
                patient.id,
                textCol,
                subtitleCol,
              ),
              const Divider(height: 12),
              _buildPatientRow('NIK Pasien', patient.nik, textCol, subtitleCol),
              const Divider(height: 12),
              _buildPatientRow(
                'Jenis Kelamin',
                patient.jenisKelamin,
                textCol,
                subtitleCol,
              ),
              const Divider(height: 12),
              _buildPatientRow(
                'Umur / Tanggal Lahir',
                '${patient.umur} / ${patient.tanggalLahir}',
                textCol,
                subtitleCol,
              ),
              const Divider(height: 12),
              _buildPatientRow(
                'No. Telepon',
                patient.telepon,
                textCol,
                subtitleCol,
              ),
              const Divider(height: 12),
              _buildPatientRow(
                'Golongan Darah',
                patient.id.length % 2 == 0 ? 'O' : 'A',
                textCol,
                subtitleCol,
              ),
              const Divider(height: 12),
              _buildPatientRow(
                'Alamat Lengkap',
                patient.alamat,
                textCol,
                subtitleCol,
              ),
            ],
          ),
        ),
        if (patient.history.isNotEmpty) ...[
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'RIWAYAT PEMERIKSAAN SEBELUMNYA',
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: textCol.withOpacity(0.5),
                  letterSpacing: 0.5,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: purple.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${patient.history.length} Record${patient.history.length > 1 ? 's' : ''}',
                  style: GoogleFonts.outfit(
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    color: purple,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: patient.history.take(2).length,
            itemBuilder: (context, index) {
              final historyItem = patient.history[index];
              final parts = historyItem.split('|');
              final queueId = parts[0];
              final formattedDate = parts.length > 1 ? parts[1] : parts[0];

              return HistoryItemCard(
                formattedDate: formattedDate,
                queueId: queueId,
                border: borderCol,
                text: textCol,
                subtitle: subtitleCol,
                colorTheme: purple,
                isDark: isDark,
                onTap: () => _showEncounterDetailDialog(context, queueId, formattedDate, patient, isDark),
              );
            },
          ),
        ],
      ],
    );
  }

  Widget _buildPatientRow(
    String label,
    String value,
    Color textCol,
    Color subtitleCol,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label.toUpperCase(),
            style: GoogleFonts.outfit(
              fontSize: 8,
              fontWeight: FontWeight.w900,
              color: subtitleCol,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
              color: textCol,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStep2(
    Color textCol,
    Color subtitleCol,
    Color borderCol,
    Color inputBg,
    Color purple,
  ) {
    final state = ref.read(landingPageProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Keluhan Utama *'.tr(state),
          style: GoogleFonts.outfit(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            color: textCol,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _keluhanController,
          maxLines: 3,
          onTap: () {
            setState(() {
              _showDiagnosisDropdown = false;
              _showDiagnosisIcd9Dropdown = false;
            });
          },
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: textCol,
          ),
          decoration: InputDecoration(
            hintText:
                'Tulis keluhan utama pasien, misal: Sakit kepala hebat disertai mual sejak kemarin malam...'
                    .tr(state),
            hintStyle: GoogleFonts.outfit(
              fontSize: 11,
              color: subtitleCol.withOpacity(0.5),
            ),
            contentPadding: const EdgeInsets.all(14),
            filled: true,
            fillColor: inputBg,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderCol),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: purple, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Anamnesa'.tr(state),
          style: GoogleFonts.outfit(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            color: textCol,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _anamnesisController,
          maxLines: 3,
          onTap: () {
            setState(() {
              _showDiagnosisDropdown = false;
              _showDiagnosisIcd9Dropdown = false;
            });
          },
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: textCol,
          ),
          decoration: InputDecoration(
            hintText:
                'Tulis riwayat penyakit atau anamnesis tambahan (opsional)...'
                    .tr(state),
            hintStyle: GoogleFonts.outfit(
              fontSize: 11,
              color: subtitleCol.withOpacity(0.5),
            ),
            contentPadding: const EdgeInsets.all(14),
            filled: true,
            fillColor: inputBg,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderCol),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: purple, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStep3(
    Color textCol,
    Color subtitleCol,
    Color borderCol,
    Color inputBg,
    Color purple,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Row for Food and Air Allergies
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ALERGI MAKANAN',
                    style: GoogleFonts.outfit(
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      color: subtitleCol,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _buildDropdown(
                    value: _foodAllergy,
                    items: ['Tidak Ada', 'Ada'],
                    onChanged: (val) => setState(() => _foodAllergy = val!),
                    bg: inputBg,
                    borderCol: borderCol,
                    textCol: textCol,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ALERGI UDARA',
                    style: GoogleFonts.outfit(
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      color: subtitleCol,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _buildDropdown(
                    value: _airAllergy,
                    items: ['Tidak Ada', 'Ada'],
                    onChanged: (val) => setState(() => _airAllergy = val!),
                    bg: inputBg,
                    borderCol: borderCol,
                    textCol: textCol,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Row for Drug Allergy
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ALERGI OBAT',
                    style: GoogleFonts.outfit(
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      color: subtitleCol,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _buildDropdown(
                    value: _drugAllergy,
                    items: ['Tidak Ada', 'Ada'],
                    onChanged: (val) => setState(() => _drugAllergy = val!),
                    bg: inputBg,
                    borderCol: borderCol,
                    textCol: textCol,
                  ),
                ],
              ),
            ),
            if (_drugAllergy == 'Ada') ...[
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ALERGI ANTIBIOTIK',
                      style: GoogleFonts.outfit(
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        color: subtitleCol,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _buildDropdown(
                      value: _antibioticAllergy,
                      items: ['Tidak Ada', 'Ada'],
                      onChanged: (val) =>
                          setState(() => _antibioticAllergy = val!),
                      bg: inputBg,
                      borderCol: borderCol,
                      textCol: textCol,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        if (_drugAllergy == 'Ada' && _antibioticAllergy == 'Ada') ...[
          const SizedBox(height: 12),
          Text(
            'DETAIL ALERGI ANTIBIOTIK',
            style: GoogleFonts.outfit(
              fontSize: 8,
              fontWeight: FontWeight.w900,
              color: subtitleCol,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _antibioticDetailController,
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: textCol,
            ),
            decoration: InputDecoration(
              hintText:
                  'Tulis jenis antibiotik (misal: Penisilin, Amoksisilin...)',
              hintStyle: GoogleFonts.outfit(
                fontSize: 10,
                color: subtitleCol.withOpacity(0.5),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              filled: true,
              fillColor: inputBg,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: borderCol),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: purple, width: 1.2),
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        // Therapies Row
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TERAPI OBAT RME',
                    style: GoogleFonts.outfit(
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      color: subtitleCol,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _medTherapyController,
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: textCol,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Terapi farmakologis...',
                      hintStyle: GoogleFonts.outfit(
                        fontSize: 10,
                        color: subtitleCol.withOpacity(0.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      filled: true,
                      fillColor: inputBg,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: borderCol),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: purple, width: 1.2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TERAPI NON-OBAT',
                    style: GoogleFonts.outfit(
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      color: subtitleCol,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _nonMedTherapyController,
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: textCol,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Edukasi / fisioterapi...',
                      hintStyle: GoogleFonts.outfit(
                        fontSize: 10,
                        color: subtitleCol.withOpacity(0.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      filled: true,
                      fillColor: inputBg,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: borderCol),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: purple, width: 1.2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Prognosis and BMHP
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PROGNOSA PASIEN',
                    style: GoogleFonts.outfit(
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      color: subtitleCol,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _buildDropdown(
                    value: _prognosis,
                    items: [
                      'Sembuh',
                      'Membaik',
                      'Rujukan',
                      'Terminal',
                      'Dubia ad Bonam',
                      'Dubia ad Malam',
                    ],
                    onChanged: (val) => setState(() => _prognosis = val!),
                    bg: inputBg,
                    borderCol: borderCol,
                    textCol: textCol,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'BMHP (ALAT MEDIS)',
                    style: GoogleFonts.outfit(
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      color: subtitleCol,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _bmhpController,
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: textCol,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Detail spuit, kassa...',
                      hintStyle: GoogleFonts.outfit(
                        fontSize: 10,
                        color: subtitleCol.withOpacity(0.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      filled: true,
                      fillColor: inputBg,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: borderCol),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: purple, width: 1.2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required void Function(String?) onChanged,
    required Color bg,
    required Color borderCol,
    required Color textCol,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderCol),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          onChanged: onChanged,
          items: items.map((i) {
            return DropdownMenuItem<String>(
              value: i,
              child: Text(
                i,
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: textCol,
                ),
              ),
            );
          }).toList(),
          isExpanded: true,
          dropdownColor: bg,
          icon: const Icon(Icons.arrow_drop_down, size: 18),
        ),
      ),
    );
  }

  Widget _buildStep4(
    Color textCol,
    Color subtitleCol,
    Color borderCol,
    Color inputBg,
    Color purple,
    Color activeGreen,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderCol),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: Icon + Title
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: purple.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.favorite_rounded, color: purple, size: 16),
              ),
              const SizedBox(width: 10),
              Text(
                'Vital Signs',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: textCol,
                ),
              ),
            ],
          ),
          const Divider(height: 30),

          // Vital Signs Inputs: Row 1
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildBloodPressureField(
                  bg: inputBg,
                  textCol: textCol,
                  subtitleCol: subtitleCol,
                  borderCol: borderCol,
                  purple: purple,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildVitalField(
                  label: 'HEART RATE (BPM)',
                  suffix: 'bpm',
                  controller: _nadiController,
                  bg: inputBg,
                  textCol: textCol,
                  subtitleCol: subtitleCol,
                  borderCol: borderCol,
                  purple: purple,
                  hintText: '80',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildVitalField(
                  label: 'RESPIRATION (RPM)',
                  suffix: 'rpm',
                  controller: _respirasiController,
                  bg: inputBg,
                  textCol: textCol,
                  subtitleCol: subtitleCol,
                  borderCol: borderCol,
                  purple: purple,
                  hintText: '20',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Vital Signs Inputs: Row 2
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildVitalField(
                  label: 'BODY TEMP (°C)',
                  suffix: '°C',
                  controller: _suhuController,
                  bg: inputBg,
                  textCol: textCol,
                  subtitleCol: subtitleCol,
                  borderCol: borderCol,
                  purple: purple,
                  hintText: '36.5',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildVitalField(
                  label: 'WEIGHT (KG)',
                  suffix: 'kg',
                  controller: _beratController,
                  bg: inputBg,
                  textCol: textCol,
                  subtitleCol: subtitleCol,
                  borderCol: borderCol,
                  purple: purple,
                  hintText: '65',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildVitalField(
                  label: 'HEIGHT (CM)',
                  suffix: 'cm',
                  controller: _tinggiController,
                  bg: inputBg,
                  textCol: textCol,
                  subtitleCol: subtitleCol,
                  borderCol: borderCol,
                  purple: purple,
                  hintText: '170',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Vital Signs Inputs: Row 3
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildVitalField(
                  label: 'SPO2 (%)',
                  suffix: '%',
                  controller: _spo2Controller,
                  bg: inputBg,
                  textCol: textCol,
                  subtitleCol: subtitleCol,
                  borderCol: borderCol,
                  purple: purple,
                  hintText: '98',
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(child: SizedBox()),
              const SizedBox(width: 16),
              const Expanded(child: SizedBox()),
            ],
          ),
          const SizedBox(height: 24),

          // BMI Card
          _buildBmiDisplayCard(textCol, subtitleCol, borderCol, inputBg),
          const SizedBox(height: 30),

          // ICD diagnosis selection
          _buildIcdSelectionSection(
            textCol,
            subtitleCol,
            borderCol,
            inputBg,
            purple,
            activeGreen,
          ),
        ],
      ),
    );
  }

  Widget _buildBloodPressureField({
    required Color bg,
    required Color textCol,
    required Color subtitleCol,
    required Color borderCol,
    required Color purple,
  }) {
    final bpWarning = getBPWarning(
      _tensiSysController.text,
      _tensiDiaController.text,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'BLOOD PRESSURE (MMHG)',
              style: GoogleFonts.outfit(
                fontSize: 8.5,
                fontWeight: FontWeight.w900,
                color: subtitleCol,
              ),
            ),
            if (bpWarning != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: bpWarning.bgColor,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: bpWarning.borderColor),
                ),
                child: Text(
                  bpWarning.label.toUpperCase(),
                  style: GoogleFonts.outfit(
                    fontSize: 7,
                    fontWeight: FontWeight.w900,
                    color: bpWarning.color,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Container(
              width: 50,
              height: 38,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderCol),
              ),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: TextField(
                controller: _tensiSysController,
                keyboardType: TextInputType.number,
                inputFormatters: [VitalInputFormatter(isDecimal: false)],
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: textCol,
                ),
                decoration: InputDecoration(
                  hintText: 'Sys',
                  hintStyle: GoogleFonts.outfit(
                    fontSize: 12,
                    color: subtitleCol.withOpacity(0.4),
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                '/',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: subtitleCol,
                ),
              ),
            ),
            Container(
              width: 50,
              height: 38,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderCol),
              ),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: TextField(
                controller: _tensiDiaController,
                keyboardType: TextInputType.number,
                inputFormatters: [VitalInputFormatter(isDecimal: false)],
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: textCol,
                ),
                decoration: InputDecoration(
                  hintText: 'Dia',
                  hintStyle: GoogleFonts.outfit(
                    fontSize: 12,
                    color: subtitleCol.withOpacity(0.4),
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'mmHg',
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: subtitleCol,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildVitalField({
    required String label,
    required String suffix,
    required TextEditingController controller,
    required Color bg,
    required Color textCol,
    required Color subtitleCol,
    required Color borderCol,
    required Color purple,
    String? hintText,
  }) {
    VitalWarning? warning;
    if (label.contains('HEART RATE')) {
      warning = getHRWarning(controller.text);
    } else if (label.contains('RESPIRATION')) {
      warning = getRRWarning(controller.text);
    } else if (label.contains('BODY TEMP')) {
      warning = getTempWarning(controller.text);
    } else if (label.contains('SPO2')) {
      warning = getSpO2Warning(controller.text);
    }

    final isSPO2 = label.toUpperCase().contains('SPO2');
    final isDecimalField =
        label.toUpperCase().contains('TEMP') ||
        label.toUpperCase().contains('WEIGHT') ||
        label.toUpperCase().contains('HEIGHT');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label.toUpperCase(),
              style: GoogleFonts.outfit(
                fontSize: 8.5,
                fontWeight: FontWeight.w900,
                color: subtitleCol,
              ),
            ),
            if (warning != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: warning.bgColor,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: warning.borderColor),
                ),
                child: Text(
                  warning.label.toUpperCase(),
                  style: GoogleFonts.outfit(
                    fontSize: 7,
                    fontWeight: FontWeight.w900,
                    color: warning.color,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Container(
              width: 100,
              height: 38,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderCol),
              ),
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: TextField(
                controller: controller,
                keyboardType: TextInputType.numberWithOptions(
                  decimal: isDecimalField,
                ),
                inputFormatters: [
                  VitalInputFormatter(
                    isDecimal: isDecimalField,
                    maxVal: isSPO2 ? 100.0 : null,
                  ),
                ],
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: textCol,
                ),
                decoration: InputDecoration(
                  hintText: hintText,
                  hintStyle: GoogleFonts.outfit(
                    fontSize: 12,
                    color: subtitleCol.withOpacity(0.5),
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: (val) {
                  setState(() {});
                },
              ),
            ),
            const SizedBox(width: 8),
            Text(
              suffix,
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: subtitleCol,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBmiDisplayCard(
    Color textCol,
    Color subtitleCol,
    Color borderCol,
    Color inputBg,
  ) {
    final double? weight = double.tryParse(
      _beratController.text.replaceAll(',', '.'),
    );
    final double? height = double.tryParse(
      _tinggiController.text.replaceAll(',', '.'),
    );
    double? bmi;
    String bmiCat = '—';
    Color bmiColor = subtitleCol;

    if (weight != null && height != null && height > 0) {
      bmi = weight / ((height / 100) * (height / 100));
      if (bmi < 18.5) {
        bmiCat = 'Underweight';
        bmiColor = const Color(0xFF3498DB);
      } else if (bmi < 25) {
        bmiCat = 'Normal';
        bmiColor = const Color(0xFF2ECC71);
      } else if (bmi < 30) {
        bmiCat = 'Overweight';
        bmiColor = const Color(0xFFF1C40F);
      } else {
        bmiCat = 'Obese';
        bmiColor = const Color(0xFFE74C3C);
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: inputBg.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderCol),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'BMI (BODY MASS INDEX)',
                  style: GoogleFonts.outfit(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w900,
                    color: subtitleCol,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  bmi != null ? bmi.toStringAsFixed(1) : '—',
                  style: GoogleFonts.outfit(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: textCol,
                  ),
                ),
                if (bmi != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    bmiCat,
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: bmiColor,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(height: 80, width: 1, color: borderCol),
          const SizedBox(width: 16),
          Expanded(
            flex: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'KATEGORI',
                  style: GoogleFonts.outfit(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w900,
                    color: subtitleCol,
                  ),
                ),
                const SizedBox(height: 8),
                _buildBmiLegendItem(
                  '< 18.5',
                  'Underweight',
                  const Color(0xFF3498DB),
                  bmiCat == 'Underweight',
                ),
                _buildBmiLegendItem(
                  '18.5 - 24.9',
                  'Normal',
                  const Color(0xFF2ECC71),
                  bmiCat == 'Normal',
                ),
                _buildBmiLegendItem(
                  '25 - 29.9',
                  'Overweight',
                  const Color(0xFFF1C40F),
                  bmiCat == 'Overweight',
                ),
                _buildBmiLegendItem(
                  '≥ 30',
                  'Obese',
                  const Color(0xFFE74C3C),
                  bmiCat == 'Obese',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBmiLegendItem(
    String range,
    String label,
    Color color,
    bool isActive,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            '$range ➔ $label',
            style: GoogleFonts.outfit(
              fontSize: 9.5,
              fontWeight: isActive ? FontWeight.w900 : FontWeight.bold,
              color: isActive ? color : color.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIcdSelectionSection(
    Color textCol,
    Color subtitleCol,
    Color borderCol,
    Color inputBg,
    Color purple,
    Color activeGreen,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.search_rounded, color: subtitleCol, size: 14),
            const SizedBox(width: 8),
            Text(
              'KODE DIAGNOSA STANDAR',
              style: GoogleFonts.outfit(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: textCol,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DIAGNOSIS CODE (ICD-10) *',
                    style: GoogleFonts.outfit(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w900,
                      color: subtitleCol,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _diagnosisSearchController,
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: textCol,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search ICD-10 code...',
                      hintStyle: GoogleFonts.outfit(
                        fontSize: 11,
                        color: subtitleCol.withOpacity(0.5),
                        fontWeight: FontWeight.normal,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        size: 14,
                        color: subtitleCol,
                      ),
                      suffixIcon: _diagnosisSearchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 14),
                              onPressed: () => setState(() {
                                _diagnosisSearchController.clear();
                                _diagnosisSearchQuery = '';
                              }),
                            )
                          : const Icon(Icons.arrow_drop_down, size: 16),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                      filled: true,
                      fillColor: inputBg,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: borderCol),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: purple, width: 1.2),
                      ),
                    ),
                    onTap: () {
                      setState(() {
                        _showDiagnosisDropdown = true;
                        _showDiagnosisIcd9Dropdown = false;
                        _diagnosisSearchQuery = _diagnosisSearchController.text;
                      });
                    },
                    onChanged: (val) {
                      setState(() {
                        _showDiagnosisDropdown = true;
                        _diagnosisSearchQuery = val;
                      });
                    },
                  ),
                  if (_showDiagnosisDropdown) ...[
                    const SizedBox(height: 6),
                    Container(
                      height: 180,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: borderCol),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: ListView(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          children: icd10Codes
                              .where(
                                (diag) =>
                                    diag.code.toLowerCase().contains(
                                      _diagnosisSearchQuery.toLowerCase(),
                                    ) ||
                                    diag.description.toLowerCase().contains(
                                      _diagnosisSearchQuery.toLowerCase(),
                                    ),
                              )
                              .map(
                                (diag) => ListTile(
                                  dense: true,
                                  title: Text(
                                    diag.description,
                                    style: GoogleFonts.outfit(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: textCol,
                                    ),
                                  ),
                                  subtitle: Text(
                                    diag.code,
                                    style: GoogleFonts.outfit(
                                      fontSize: 9,
                                      color: subtitleCol,
                                    ),
                                  ),
                                  hoverColor: purple.withOpacity(0.08),
                                  onTap: () {
                                    if (!_selectedDiagnoses.any(
                                      (element) => element.code == diag.code,
                                    )) {
                                      setState(() {
                                        _selectedDiagnoses.add(diag);
                                        _diagnosisTypes[diag.code] =
                                            _selectedDiagnosisType;
                                        _diagnosisSearchController.clear();
                                        _diagnosisSearchQuery = '';
                                        _showDiagnosisDropdown = false;
                                      });
                                    } else {
                                      setState(() {
                                        _showDiagnosisDropdown = false;
                                      });
                                    }
                                  },
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DIAGNOSIS CODE (ICD-9)',
                    style: GoogleFonts.outfit(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w900,
                      color: subtitleCol,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _diagnosisIcd9SearchController,
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: textCol,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search ICD-9 code...',
                      hintStyle: GoogleFonts.outfit(
                        fontSize: 11,
                        color: subtitleCol.withOpacity(0.5),
                        fontWeight: FontWeight.normal,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        size: 14,
                        color: subtitleCol,
                      ),
                      suffixIcon: _diagnosisIcd9SearchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 14),
                              onPressed: () => setState(() {
                                _diagnosisIcd9SearchController.clear();
                                _diagnosisIcd9SearchQuery = '';
                              }),
                            )
                          : const Icon(Icons.arrow_drop_down, size: 16),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                      filled: true,
                      fillColor: inputBg,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: borderCol),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: purple, width: 1.2),
                      ),
                    ),
                    onTap: () {
                      setState(() {
                        _showDiagnosisIcd9Dropdown = true;
                        _showDiagnosisDropdown = false;
                        _diagnosisIcd9SearchQuery =
                            _diagnosisIcd9SearchController.text;
                      });
                    },
                    onChanged: (val) {
                      setState(() {
                        _showDiagnosisIcd9Dropdown = true;
                        _diagnosisIcd9SearchQuery = val;
                      });
                    },
                  ),
                  if (_showDiagnosisIcd9Dropdown) ...[
                    const SizedBox(height: 6),
                    Container(
                      height: 180,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: borderCol),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: ListView(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          children: icd9Codes
                              .where(
                                (diag) =>
                                    diag.code.toLowerCase().contains(
                                      _diagnosisIcd9SearchQuery.toLowerCase(),
                                    ) ||
                                    diag.description.toLowerCase().contains(
                                      _diagnosisIcd9SearchQuery.toLowerCase(),
                                    ),
                              )
                              .map(
                                (diag) => ListTile(
                                  dense: true,
                                  title: Text(
                                    diag.description,
                                    style: GoogleFonts.outfit(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: textCol,
                                    ),
                                  ),
                                  subtitle: Text(
                                    diag.code,
                                    style: GoogleFonts.outfit(
                                      fontSize: 9,
                                      color: subtitleCol,
                                    ),
                                  ),
                                  hoverColor: purple.withOpacity(0.08),
                                  onTap: () {
                                    if (!_selectedDiagnoses.any(
                                      (element) => element.code == diag.code,
                                    )) {
                                      setState(() {
                                        _selectedDiagnoses.add(diag);
                                        _diagnosisTypes[diag.code] =
                                            _selectedDiagnosisType;
                                        _diagnosisIcd9SearchController.clear();
                                        _diagnosisIcd9SearchQuery = '';
                                        _showDiagnosisIcd9Dropdown = false;
                                      });
                                    } else {
                                      setState(() {
                                        _showDiagnosisIcd9Dropdown = false;
                                      });
                                    }
                                  },
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Diagnosis Type',
              style: GoogleFonts.outfit(
                fontSize: 8.5,
                fontWeight: FontWeight.w900,
                color: subtitleCol,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildDiagnosisTypeButton(
                  label: 'Primary Diagnosis',
                  type: 'Primary',
                  activeGreen: activeGreen,
                  borderCol: borderCol,
                  subtitleCol: subtitleCol,
                ),
                const SizedBox(width: 12),
                _buildDiagnosisTypeButton(
                  label: 'Secondary Diagnosis',
                  type: 'Secondary',
                  activeGreen: activeGreen,
                  borderCol: borderCol,
                  subtitleCol: subtitleCol,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_selectedDiagnoses.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _selectedDiagnoses.map((diag) {
              final isIcd10 = RegExp(r'^[A-Z]').hasMatch(diag.code);
              final Color chipThemeColor = isIcd10
                  ? purple
                  : const Color(0xFF48C9B0);
              final type = _diagnosisTypes[diag.code] ?? 'Primary';

              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: chipThemeColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: chipThemeColor.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: chipThemeColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isIcd10 ? 'ICD-10' : 'ICD-9',
                        style: GoogleFonts.outfit(
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          color: chipThemeColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: type == 'Primary'
                            ? activeGreen.withOpacity(0.15)
                            : subtitleCol.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        type.toUpperCase(),
                        style: GoogleFonts.outfit(
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          color: type == 'Primary' ? activeGreen : subtitleCol,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${diag.description} (${diag.code})',
                      style: GoogleFonts.outfit(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: textCol,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedDiagnoses.remove(diag);
                          _diagnosisTypes.remove(diag.code);
                        });
                      },
                      child: Icon(
                        Icons.close_rounded,
                        size: 14,
                        color: subtitleCol,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildDiagnosisTypeButton({
    required String label,
    required String type,
    required Color activeGreen,
    required Color borderCol,
    required Color subtitleCol,
  }) {
    final bool isSelected = _selectedDiagnosisType == type;
    final Color bg = isSelected ? const Color(0xFFE8F8F5) : Colors.white;
    final Color border = isSelected ? activeGreen : borderCol;
    final Color text = isSelected ? activeGreen : subtitleCol;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedDiagnosisType = type;
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: border, width: isSelected ? 1.5 : 1),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: text,
          ),
        ),
      ),
    );
  }

  Widget _buildStep5(
    Color textCol,
    Color subtitleCol,
    Color borderCol,
    Color inputBg,
    Color purple,
    Color activeGreen,
    List<ObatModel> drugList,
  ) {
    final double subtotalObat = _addedPrescriptions.fold<double>(
      0,
      (sum, item) =>
          sum + ((item["obat"] as ObatModel).hargaSatuan * item["jumlah"]),
    );
    final double serviceFee = _serviceFeeController.text.isEmpty
        ? ref.read(landingPageProvider).defaultServiceFee
        : parseFormattedPrice(_serviceFeeController.text);
    final double totalBill = serviceFee + subtotalObat;

    final tabs = [
      {'icon': Icons.medication_rounded, 'label': 'Resep Katalog'},
      {'icon': Icons.note_alt_outlined, 'label': 'Resep Manual + Apotek'},
      {'icon': Icons.send_rounded, 'label': 'Rujukan'},
      {'icon': Icons.description_rounded, 'label': 'Surat Keterangan'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Tab Bar ──
        Container(
          decoration: BoxDecoration(
            color: borderCol.withOpacity(0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderCol),
          ),
          padding: const EdgeInsets.all(4),
          child: Row(
            children: List.generate(tabs.length, (i) {
              final isActive = _step5TabIndex == i;
              final tab = tabs[i];
              // Badge for rujukan or surat keterangan
              final hasBadge = (i == 2 && _wantReferral) || (i == 3 && _wantSuratKeterangan);
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _step5TabIndex = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isActive ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(9),
                      boxShadow: isActive
                          ? [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.06),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          tab['icon'] as IconData,
                          size: 13,
                          color: isActive ? purple : subtitleCol,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          tab['label'] as String,
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: isActive
                                ? FontWeight.w900
                                : FontWeight.bold,
                            color: isActive ? purple : subtitleCol,
                          ),
                        ),
                        if (hasBadge) ...[
                          const SizedBox(width: 4),
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: activeGreen,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 16),

        // ── Tab Content ──
        if (_step5TabIndex == 0) ...[
          // ── Card 1: Prescription (Katalog Obat) ──
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderCol),
            ),
            padding: const EdgeInsets.all(20),
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
                          'Prescription',
                          style: GoogleFonts.outfit(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w900,
                            color: textCol,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Input obat dari stok katalog',
                          style: GoogleFonts.outfit(
                            fontSize: 9.5,
                            color: subtitleCol,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _showAddMedicineDialog(
                        drugList,
                        textCol,
                        subtitleCol,
                        borderCol,
                        inputBg,
                        purple,
                        activeGreen,
                      ),
                      icon: const Icon(
                        Icons.add,
                        size: 14,
                        color: Colors.white,
                      ),
                      label: Text(
                        'Add Medicine',
                        style: GoogleFonts.outfit(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: activeGreen,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Prescription Catalogue Table
                Table(
                  columnWidths: const {
                    0: FlexColumnWidth(0.6), // #
                    1: FlexColumnWidth(2.5), // MEDICINE NAME
                    2: FlexColumnWidth(2.2), // DOSAGE
                    3: FlexColumnWidth(0.8), // QTY
                    4: FlexColumnWidth(1.2), // PRICE
                    5: FlexColumnWidth(1.2), // SUBTOTAL
                    6: FlexColumnWidth(0.6), // ACTIONS
                  },
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  children: [
                    TableRow(
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: borderCol, width: 1.5),
                        ),
                      ),
                      children: [
                        _tableHeader('#', subtitleCol),
                        _tableHeader('MEDICINE NAME', subtitleCol),
                        _tableHeader('DOSAGE / INSTRUCTIONS', subtitleCol),
                        _tableHeader('QTY', subtitleCol),
                        _tableHeader('PRICE', subtitleCol),
                        _tableHeader('SUBTOTAL', subtitleCol),
                        _tableHeader('', subtitleCol),
                      ],
                    ),
                    if (_addedPrescriptions.isEmpty)
                      TableRow(
                        children: [
                          const TableCell(child: SizedBox()),
                          TableCell(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              child: Text(
                                'No prescriptions added',
                                style: GoogleFonts.outfit(
                                  fontSize: 11.5,
                                  color: subtitleCol,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const TableCell(child: SizedBox()),
                          const TableCell(child: SizedBox()),
                          const TableCell(child: SizedBox()),
                          const TableCell(child: SizedBox()),
                          const TableCell(child: SizedBox()),
                        ],
                      )
                    else
                      ..._addedPrescriptions.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final item = entry.value;
                        final ObatModel drug = item["obat"];
                        final itemPrice = drug.hargaSatuan;
                        final itemSubtotal = itemPrice * item["jumlah"];

                        return TableRow(
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: borderCol),
                            ),
                          ),
                          children: [
                            _tableCellText('${idx + 1}', textCol),
                            _tableCellText(drug.nama, textCol, isBold: true),
                            _tableCellText(item["aturan"], textCol),
                            _tableCellText('${item["jumlah"]}', textCol),
                            _tableCellText('Rp ${formatPrice(itemPrice)}', textCol),
                            _tableCellText(
                              'Rp ${formatPrice(itemSubtotal)}',
                              textCol,
                            ),
                            TableCell(
                              child: IconButton(
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  color: Colors.redAccent,
                                  size: 16,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _addedPrescriptions.removeAt(idx);
                                  });
                                },
                              ),
                            ),
                          ],
                        );
                      }),
                  ],
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'Subtotal Obat  Rp ${formatPrice(subtotalObat)}',
                    style: GoogleFonts.outfit(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                      color: activeGreen,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ], // end tab 0
        // ── Tab 1: Manual Prescription ──
        if (_step5TabIndex == 1) ...[
          // ── Card 2: Manual Prescription ──
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderCol),
            ),
            padding: const EdgeInsets.all(20),
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
                          'Manual Prescription',
                          style: GoogleFonts.outfit(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w900,
                            color: textCol,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Untuk dibeli di apotek — tidak masuk tagihan',
                          style: GoogleFonts.outfit(
                            fontSize: 9.5,
                            color: subtitleCol,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _showAddManualPrescriptionDialog(
                        textCol,
                        subtitleCol,
                        borderCol,
                        inputBg,
                        purple,
                        activeGreen,
                      ),
                      icon: const Icon(
                        Icons.add,
                        size: 14,
                        color: Colors.white,
                      ),
                      label: Text(
                        'Add Prescription',
                        style: GoogleFonts.outfit(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: activeGreen,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Info box: QR resep manual
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: activeGreen.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: activeGreen.withOpacity(0.15)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.qr_code_2_rounded,
                        size: 16,
                        color: activeGreen,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'QR resep ini akan otomatis tersimpan ke akun pasien saat pemeriksaan disimpan. Pasien dapat membawanya ke apotek.',
                          style: GoogleFonts.outfit(
                            fontSize: 8.5,
                            fontWeight: FontWeight.bold,
                            color: activeGreen,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Manual Table
                Table(
                  columnWidths: const {
                    0: FlexColumnWidth(0.6), // #
                    1: FlexColumnWidth(3.5), // MEDICINE NAME
                    2: FlexColumnWidth(3.0), // DOSAGE
                    3: FlexColumnWidth(1.0), // QTY
                    4: FlexColumnWidth(0.6), // ACTIONS
                  },
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  children: [
                    TableRow(
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: borderCol, width: 1.5),
                        ),
                      ),
                      children: [
                        _tableHeader('#', subtitleCol),
                        _tableHeader('MEDICINE NAME', subtitleCol),
                        _tableHeader('DOSAGE / INSTRUCTIONS', subtitleCol),
                        _tableHeader('QTY', subtitleCol),
                        _tableHeader('', subtitleCol),
                      ],
                    ),
                    if (_manualPrescriptions.isEmpty)
                      TableRow(
                        children: [
                          const TableCell(child: SizedBox()),
                          TableCell(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.note_alt_outlined,
                                    size: 24,
                                    color: subtitleCol.withOpacity(0.5),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'No manual prescriptions',
                                    style: GoogleFonts.outfit(
                                      fontSize: 11.5,
                                      color: subtitleCol,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'Klik "Add Prescription" untuk menambah resep manual',
                                    style: GoogleFonts.outfit(
                                      fontSize: 9.5,
                                      color: subtitleCol.withOpacity(0.7),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const TableCell(child: SizedBox()),
                          const TableCell(child: SizedBox()),
                          const TableCell(child: SizedBox()),
                        ],
                      )
                    else
                      ..._manualPrescriptions.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final item = entry.value;

                        return TableRow(
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: borderCol),
                            ),
                          ),
                          children: [
                            _tableCellText('${idx + 1}', textCol),
                            _tableCellText(item["nama"], textCol, isBold: true),
                            _tableCellText(item["aturan"], textCol),
                            _tableCellText('${item["jumlah"]}', textCol),
                            TableCell(
                              child: IconButton(
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  color: Colors.redAccent,
                                  size: 16,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _manualPrescriptions.removeAt(idx);
                                  });
                                },
                              ),
                            ),
                          ],
                        );
                      }),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Apotek Picker (inline below manual prescription) ──
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderCol),
            ),
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: activeGreen.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.local_pharmacy_outlined,
                    color: activeGreen,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Rekomendasi Ambil di Apotek',
                        style: GoogleFonts.outfit(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w900,
                          color: textCol,
                        ),
                      ),
                      Text(
                        'Berikan rekomendasi apotek terdekat untuk pasien',
                        style: GoogleFonts.outfit(
                          fontSize: 9.5,
                          color: subtitleCol,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            _selectedApotek != null
                                ? 'STATUS RECOMMENDED: '
                                : 'STATUS DEFAULT: ',
                            style: GoogleFonts.outfit(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w900,
                              color: subtitleCol,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              _selectedApotek != null
                                  ? 'Direkomendasikan ambil di $_selectedApotek'
                                  : 'Bebas di apotek mana saja',
                              style: GoogleFonts.outfit(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                color: _selectedApotek != null
                                    ? activeGreen
                                    : subtitleCol,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (_selectedApotek != null) ...[
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: () =>
                                  setState(() => _selectedApotek = null),
                              child: Icon(
                                Icons.cancel_rounded,
                                size: 14,
                                color: subtitleCol,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                ElevatedButton.icon(
                  onPressed: () => _showPilihApotekDialog(
                    textCol,
                    subtitleCol,
                    borderCol,
                    inputBg,
                    purple,
                    activeGreen,
                  ),
                  icon: const Icon(Icons.add, size: 14, color: Colors.white),
                  label: Text(
                    _selectedApotek != null ? 'Ubah Apotek' : 'Pilih Apotek',
                    style: GoogleFonts.outfit(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: activeGreen,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ], // end tab 1
        // ── Tab 2: Rujukan ──
        if (_step5TabIndex == 2) ...[
          // ── Card 3: Rujukan Pasien (Surat Rujukan) ──
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderCol),
            ),
            padding: const EdgeInsets.all(20),
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
                          'Rujukan Pasien (Surat Rujukan)',
                          style: GoogleFonts.outfit(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w900,
                            color: textCol,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Buat surat rujukan ke Rumah Sakit tujuan',
                          style: GoogleFonts.outfit(
                            fontSize: 9.5,
                            color: subtitleCol,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    // Segmented Switch / ToggleButtons style
                    Container(
                      height: 32,
                      decoration: BoxDecoration(
                        color: inputBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: borderCol),
                      ),
                      padding: const EdgeInsets.all(2),
                      child: Row(
                        children: [
                          _buildSegmentButton(
                            label: 'Tidak',
                            isActive: !_wantReferral,
                            onTap: () => setState(() => _wantReferral = false),
                            borderCol: borderCol,
                            subtitleCol: subtitleCol,
                            textCol: textCol,
                          ),
                          _buildSegmentButton(
                            label: 'Rujuk',
                            isActive: _wantReferral,
                            onTap: () => setState(() => _wantReferral = true),
                            borderCol: borderCol,
                            subtitleCol: subtitleCol,
                            textCol: textCol,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (_wantReferral) ...[
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Nama Rumah Sakit Tujuan',
                              style: GoogleFonts.outfit(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w900,
                                color: textCol,
                              ),
                            ),
                            const SizedBox(height: 4),
                            TextField(
                              controller: _referralRsController,
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: textCol,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Contoh: RSUD Dr. Soetomo',
                                hintStyle: GoogleFonts.outfit(
                                  fontSize: 11,
                                  color: subtitleCol.withOpacity(0.5),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                isDense: true,
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: borderCol),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: purple),
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
                              'Poli / Bagian Rujukan',
                              style: GoogleFonts.outfit(
                                fontSize: 8.5,
                                fontWeight: FontWeight.w900,
                                color: textCol,
                              ),
                            ),
                            const SizedBox(height: 4),
                            TextField(
                              controller: _referralPoliController,
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: textCol,
                              ),
                              decoration: InputDecoration(
                                hintText:
                                    'Contoh: Poli Jantung / Penyakit Dalam',
                                hintStyle: GoogleFonts.outfit(
                                  fontSize: 11,
                                  color: subtitleCol.withOpacity(0.5),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                isDense: true,
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: borderCol),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: purple),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Catatan / Terapi Rujukan (Opsional)',
                    style: GoogleFonts.outfit(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w900,
                      color: textCol,
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _referralNotesController,
                    maxLines: 2,
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: textCol,
                    ),
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.all(8),
                      hintText:
                          'Catatan tambahan dokter untuk rumah sakit rujukan...',
                      hintStyle: GoogleFonts.outfit(
                        fontSize: 9.5,
                        color: subtitleCol.withOpacity(0.5),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: borderCol),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: purple),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _showRujukanPreviewDialog(
                          textCol,
                          subtitleCol,
                          borderCol,
                          inputBg,
                          purple,
                          activeGreen,
                        ),
                        icon: const Icon(
                          Icons.print_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                        label: Text(
                          'Cetak Draft Rujukan',
                          style: GoogleFonts.outfit(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: activeGreen,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
        ], // end tab 2
        if (_step5TabIndex == 3) ...[
          _buildSuratKeteranganTab(textCol, subtitleCol, borderCol, inputBg, purple, activeGreen),
          const SizedBox(height: 20),
        ], // end tab 3
      ],
    );
  }

  Widget _buildBillingSummaryBar(
    Color textCol,
    Color subtitleCol,
    Color borderCol,
    Color inputBg,
  ) {
    final double subtotalObat = _addedPrescriptions.fold<double>(
      0,
      (sum, item) =>
          sum + ((item["obat"] as ObatModel).hargaSatuan * item["jumlah"]),
    );
    final double serviceFee = _serviceFeeController.text.isEmpty
        ? ref.read(landingPageProvider).defaultServiceFee
        : parseFormattedPrice(_serviceFeeController.text);
    final double totalBill = serviceFee + subtotalObat;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderCol),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left side: Service Fee + Subtotal
          Row(
            children: [
              Text(
                'Service Fee (Rp)',
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: subtitleCol,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 100,
                height: 36,
                decoration: BoxDecoration(
                  color: inputBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: borderCol),
                ),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    Text(
                      'Rp',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: subtitleCol,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: TextField(
                        controller: _serviceFeeController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [ThousandsFormatter()],
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: textCol,
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text('•', style: GoogleFonts.outfit(color: borderCol)),
              const SizedBox(width: 12),
              Text(
                'Subtotal Obat: Rp ${formatPrice(subtotalObat)}',
                style: GoogleFonts.outfit(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: textCol,
                ),
              ),
            ],
          ),

          // Right side: TOTAL BILL
          Row(
            children: [
              Text(
                'TOTAL BILL  ',
                style: GoogleFonts.outfit(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                  color: subtitleCol,
                ),
              ),
              Text(
                'Rp ${formatPrice(totalBill)}',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: textCol,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tableHeader(String title, Color subtitleCol) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: GoogleFonts.outfit(
          fontSize: 8.5,
          fontWeight: FontWeight.w900,
          color: subtitleCol,
        ),
      ),
    );
  }

  Widget _tableCellText(String text, Color textCol, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        text,
        style: GoogleFonts.outfit(
          fontSize: 11,
          fontWeight: isBold ? FontWeight.w900 : FontWeight.bold,
          color: textCol,
        ),
      ),
    );
  }

  Widget _buildSegmentButton({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
    required Color borderCol,
    required Color subtitleCol,
    required Color textCol,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 10.5,
            fontWeight: FontWeight.w900,
            color: isActive ? textCol : subtitleCol,
          ),
        ),
      ),
    );
  }

  void _showAddMedicineDialog(
    List<ObatModel> drugList,
    Color textCol,
    Color subtitleCol,
    Color borderCol,
    Color inputBg,
    Color purple,
    Color activeGreen,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        ObatModel? localSelectedDrug;
        final localDoseController = TextEditingController();
        final localQtyController = TextEditingController(text: '1');
        String localSearchQuery = '';

        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              final filteredDrugs = drugList
                  .where(
                    (d) => d.nama.toLowerCase().contains(
                      localSearchQuery.toLowerCase(),
                    ),
                  )
                  .toList();

              final bool isValid =
                  localSelectedDrug != null &&
                  localDoseController.text.trim().isNotEmpty &&
                  (int.tryParse(localQtyController.text) ?? 0) > 0;

              return Container(
                width: 500,
                height: 600,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Add Medicine',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: textCol,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      onChanged: (val) {
                        setDialogState(() {
                          localSearchQuery = val;
                        });
                      },
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Cari nama obat...',
                        hintStyle: GoogleFonts.outfit(
                          fontSize: 11,
                          color: subtitleCol.withOpacity(0.5),
                        ),
                        prefixIcon: const Icon(Icons.search, size: 16),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 10,
                        ),
                        filled: true,
                        fillColor: inputBg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: borderCol),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: borderCol),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: filteredDrugs.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Text(
                                    'Tidak ada obat tersedia.\nPastikan farmasi sudah mengisi stok.',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.outfit(
                                      fontSize: 11,
                                      color: subtitleCol,
                                    ),
                                  ),
                                ),
                              )
                            : ListView.separated(
                                itemCount: filteredDrugs.length,
                                separatorBuilder: (c, i) =>
                                    const Divider(height: 1),
                                itemBuilder: (context, idx) {
                                  final d = filteredDrugs[idx];
                                  final isSelected = localSelectedDrug == d;
                                  return ListTile(
                                    dense: true,
                                    tileColor: isSelected
                                        ? activeGreen.withOpacity(0.06)
                                        : null,
                                    title: Text(
                                      d.nama,
                                      style: GoogleFonts.outfit(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w900,
                                        color: textCol,
                                      ),
                                    ),
                                    subtitle: Text(
                                      '${d.jenis} — ${d.totalStok} Tersedia',
                                      style: GoogleFonts.outfit(
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.bold,
                                        color: activeGreen,
                                      ),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'Rp ${formatPrice(d.hargaSatuan)}',
                                          style: GoogleFonts.outfit(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w900,
                                            color: textCol,
                                          ),
                                        ),
                                        if (isSelected) ...[
                                          const SizedBox(width: 8),
                                          Icon(
                                            Icons.check_circle_rounded,
                                            color: activeGreen,
                                            size: 18,
                                          ),
                                        ],
                                      ],
                                    ),
                                    onTap: () {
                                      setDialogState(() {
                                        localSelectedDrug = d;
                                      });
                                    },
                                  );
                                },
                              ),
                      ),
                    ),
                    // ── Selected drug info card ──
                    if (localSelectedDrug != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: activeGreen.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: activeGreen.withOpacity(0.25),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.medication_rounded,
                              color: activeGreen,
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    localSelectedDrug!.nama,
                                    style: GoogleFonts.outfit(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                      color: textCol,
                                    ),
                                  ),
                                  Text(
                                    '${localSelectedDrug!.jenis}  ·  Stok: ${localSelectedDrug!.totalStok}',
                                    style: GoogleFonts.outfit(
                                      fontSize: 9,
                                      color: subtitleCol,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              'Rp ${formatPrice(localSelectedDrug!.hargaSatuan)} / unit',
                              style: GoogleFonts.outfit(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: activeGreen,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),
                    Text(
                      'DETAIL RESEP',
                      style: GoogleFonts.outfit(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w900,
                        color: subtitleCol,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'DOSIS / ATURAN PAKAI *',
                                style: GoogleFonts.outfit(
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  color: subtitleCol,
                                ),
                              ),
                              const SizedBox(height: 4),
                              TextField(
                                controller: localDoseController,
                                enabled: localSelectedDrug != null,
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                                decoration: InputDecoration(
                                  hintText: localSelectedDrug == null
                                      ? 'Pilih obat dahulu'
                                      : 'mis: 3×1 sesudah makan',
                                  hintStyle: GoogleFonts.outfit(
                                    fontSize: 11,
                                    color: subtitleCol.withOpacity(0.5),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  isDense: true,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: borderCol),
                                  ),
                                ),
                                onChanged: (val) => setDialogState(() {}),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 1,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'JUMLAH *',
                                style: GoogleFonts.outfit(
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  color: subtitleCol,
                                ),
                              ),
                              const SizedBox(height: 4),
                              TextField(
                                controller: localQtyController,
                                keyboardType: TextInputType.number,
                                enabled: localSelectedDrug != null,
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                                decoration: InputDecoration(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  isDense: true,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: borderCol),
                                  ),
                                ),
                                onChanged: (val) => setDialogState(() {}),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: isValid
                          ? () {
                              setState(() {
                                _addedPrescriptions.add({
                                  "obat": localSelectedDrug,
                                  "aturan": localDoseController.text,
                                  "jumlah":
                                      int.tryParse(localQtyController.text) ??
                                      1,
                                });
                              });
                              Navigator.pop(context);
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isValid
                            ? activeGreen
                            : activeGreen.withOpacity(0.3),
                        disabledBackgroundColor: activeGreen.withOpacity(0.3),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        isValid ? '+ Tambah ke Resep' : '+ Isi Dosis Dahulu',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _showAddManualPrescriptionDialog(
    Color textCol,
    Color subtitleCol,
    Color borderCol,
    Color inputBg,
    Color purple,
    Color activeGreen,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        final localSearchController = TextEditingController();
        final localDoseController = TextEditingController();
        final localQtyController = TextEditingController(text: '1');
        String? selectedKfaCode;
        String? selectedKfaName;
        int selectedTab = 0; // 0 = KFA, 1 = Manual

        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              final bool isValid =
                  (selectedTab == 0 ? selectedKfaName != null : localSearchController.text.trim().isNotEmpty) &&
                  localDoseController.text.trim().isNotEmpty &&
                  (int.tryParse(localQtyController.text) ?? 0) > 0;

              return Container(
                width: 450,
                height: 480,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Resep Manual (Luar Apotek)',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: textCol,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Tab Selector
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: inputBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setDialogState(() { selectedTab = 0; }),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: selectedTab == 0 ? Colors.white : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: selectedTab == 0
                                      ? [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.05),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          )
                                        ]
                                      : null,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.medication_rounded,
                                      size: 14,
                                      color: selectedTab == 0 ? activeGreen : subtitleCol,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Cari KFA',
                                      style: GoogleFonts.outfit(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: selectedTab == 0 ? activeGreen : subtitleCol,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setDialogState(() { selectedTab = 1; }),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: selectedTab == 1 ? Colors.white : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: selectedTab == 1
                                      ? [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.05),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          )
                                        ]
                                      : null,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.edit_note_rounded,
                                      size: 14,
                                      color: selectedTab == 1 ? activeGreen : subtitleCol,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Tulis Manual',
                                      style: GoogleFonts.outfit(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: selectedTab == 1 ? activeGreen : subtitleCol,
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

                    if (selectedTab == 0) ...[
                      // KFA SEARCH TAB
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          icon: Icon(Icons.search_rounded, size: 16, color: activeGreen),
                          label: Text(
                            selectedKfaCode != null
                                ? 'Ganti dari Katalog KFA'
                                : 'Cari dari Katalog KFA',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: activeGreen,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: activeGreen.withOpacity(0.5)),
                            backgroundColor: activeGreen.withOpacity(0.05),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: () async {
                            final result = await _showKfaSearchModal(
                              context,
                              Theme.of(context).brightness == Brightness.dark,
                            );
                            if (result != null) {
                              setDialogState(() {
                                selectedKfaName = result['nama'];
                                selectedKfaCode = result['code'];
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (selectedKfaCode != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: activeGreen.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: activeGreen.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.verified_rounded, size: 14, color: activeGreen),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '$selectedKfaName  •  KFA: $selectedKfaCode',
                                  style: GoogleFonts.outfit(fontSize: 10.5, color: activeGreen, fontWeight: FontWeight.w700),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              GestureDetector(
                                onTap: () => setDialogState(() {
                                  selectedKfaCode = null;
                                  selectedKfaName = null;
                                }),
                                child: Icon(Icons.close_rounded, size: 14, color: activeGreen),
                              ),
                            ],
                          ),
                        ),
                      const Spacer(),
                    ] else ...[
                      // MANUAL TAB
                      Text(
                        'NAMA OBAT MANUAL *',
                        style: GoogleFonts.outfit(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w900,
                          color: subtitleCol,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: localSearchController,
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                        decoration: InputDecoration(
                          hintText: 'cth. Paracetamol 500mg (Tulis manual)...',
                          hintStyle: GoogleFonts.outfit(
                            fontSize: 11,
                            color: subtitleCol.withOpacity(0.4),
                          ),
                          prefixIcon: const Icon(
                            Icons.medication_outlined,
                            size: 16,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 8,
                          ),
                          isDense: true,
                          filled: true,
                          fillColor: inputBg,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: borderCol),
                          ),
                        ),
                        onChanged: (val) => setDialogState(() {}),
                      ),
                      const Spacer(),
                    ],
                    Text(
                      'DOSIS / ATURAN PAKAI *',
                      style: GoogleFonts.outfit(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w900,
                        color: subtitleCol,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: localDoseController,
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        hintText: 'mis: 3×1 sesudah makan',
                        hintStyle: GoogleFonts.outfit(
                          fontSize: 11,
                          color: subtitleCol.withOpacity(0.5),
                        ),
                        contentPadding: const EdgeInsets.all(10),
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: borderCol),
                        ),
                      ),
                      onChanged: (val) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'JUMLAH *',
                      style: GoogleFonts.outfit(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w900,
                        color: subtitleCol,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: localQtyController,
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.all(10),
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: borderCol),
                        ),
                      ),
                      onChanged: (val) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: isValid
                          ? () {
                              setState(() {
                                _manualPrescriptions.add({
                                  "nama": selectedTab == 0 ? selectedKfaName : localSearchController.text,
                                  "aturan": localDoseController.text,
                                  "jumlah":
                                      int.tryParse(localQtyController.text) ??
                                      1,
                                  "kfa_code": selectedTab == 0 ? selectedKfaCode : null,
                                });
                              });
                              Navigator.pop(context);
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isValid
                            ? activeGreen
                            : activeGreen.withOpacity(0.3),
                        disabledBackgroundColor: activeGreen.withOpacity(0.3),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        isValid
                            ? '+ Tambah ke Resep'
                            : '+ Dosis & Aturan Harus Diisi',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _showPilihApotekDialog(
    Color textCol,
    Color subtitleCol,
    Color borderCol,
    Color inputBg,
    Color purple,
    Color activeGreen,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        String searchQuery = '';
        bool isLoading = true;
        List<String> apotekList = [];

        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              if (isLoading) {
                _getApotekList().then((list) {
                  if (context.mounted) {
                    setDialogState(() {
                      apotekList = list;
                      isLoading = false;
                    });
                  }
                });
              }

              final filteredApoteks = apotekList
                  .where(
                    (a) => a.toLowerCase().contains(searchQuery.toLowerCase()),
                  )
                  .toList();

              return Container(
                width: 450,
                height: 450,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Pilih Apotek',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: textCol,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      onChanged: (val) {
                        setDialogState(() {
                          searchQuery = val;
                        });
                      },
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Cari nama apotek...',
                        hintStyle: GoogleFonts.outfit(
                          fontSize: 11,
                          color: subtitleCol.withOpacity(0.5),
                        ),
                        prefixIcon: const Icon(Icons.search, size: 16),
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                        isDense: true,
                        filled: true,
                        fillColor: inputBg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: borderCol),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: isLoading
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 28,
                                  height: 28,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      activeGreen,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Mencari apotek...',
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: subtitleCol,
                                  ),
                                ),
                              ],
                            )
                          : ListView(
                              children: [
                                ListTile(
                                  dense: true,
                                  leading: Icon(
                                    Icons.local_pharmacy_outlined,
                                    color: activeGreen,
                                    size: 18,
                                  ),
                                  title: Text(
                                    'Bisa ambil di mana saja (Bebas)',
                                    style: GoogleFonts.outfit(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                      color: textCol,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'Pasien dibebaskan memilih apotek luar',
                                    style: GoogleFonts.outfit(
                                      fontSize: 8.5,
                                      color: subtitleCol,
                                    ),
                                  ),
                                  trailing: _selectedApotek == null
                                      ? Icon(
                                          Icons.check_circle_rounded,
                                          color: activeGreen,
                                          size: 18,
                                        )
                                      : null,
                                  onTap: () {
                                    setState(() {
                                      _selectedApotek = null;
                                    });
                                    Navigator.pop(context);
                                  },
                                ),
                                const Divider(height: 1),
                                ...filteredApoteks.map((name) {
                                  final isSelected = _selectedApotek == name;
                                  return Column(
                                    children: [
                                      ListTile(
                                        dense: true,
                                        leading: Icon(
                                          Icons.storefront_outlined,
                                          color: purple,
                                          size: 18,
                                        ),
                                        title: Text(
                                          name,
                                          style: GoogleFonts.outfit(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: textCol,
                                          ),
                                        ),
                                        subtitle: Text(
                                          'Terdaftar di MAPOTECH',
                                          style: GoogleFonts.outfit(
                                            fontSize: 8.5,
                                            color: activeGreen,
                                          ),
                                        ),
                                        trailing: isSelected
                                            ? Icon(
                                                Icons.check_circle_rounded,
                                                color: activeGreen,
                                                size: 18,
                                              )
                                            : null,
                                        onTap: () {
                                          setState(() {
                                            _selectedApotek = name;
                                          });
                                          Navigator.pop(context);
                                        },
                                      ),
                                      const Divider(height: 1),
                                    ],
                                  );
                                }),
                              ],
                            ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<List<String>> _getApotekList() async {
    try {
      final res = await SupabaseService.client
          .from('user')
          .select('name')
          .eq('role', 'apotek');
      final list = (res as List).map((u) => u['name'].toString()).toList();
      if (list.isEmpty) {
        return [
          'Apotek K-24 Bondowoso',
          'Apotek Kimia Farma Ahmad Yani',
          'Apotek Medika Bondowoso',
          'Apotek Sehat Sentosa',
          'Apotek Jaya Abadi',
        ];
      }
      return list;
    } catch (_) {
      return [
        'Apotek K-24 Bondowoso',
        'Apotek Kimia Farma Ahmad Yani',
        'Apotek Medika Bondowoso',
        'Apotek Sehat Sentosa',
        'Apotek Jaya Abadi',
      ];
    }
  }

  Widget _buildStepNavigation(
    Color textCol,
    Color subtitleCol,
    Color borderCol,
    Color purple,
    Color activeGreen,
    bool autoSyncEnabled,
  ) {
    final state = ref.read(landingPageProvider);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (_currentStep > 1)
          OutlinedButton.icon(
            icon: const Icon(Icons.arrow_back_rounded, size: 14),
            label: Text(
              'Sebelumnya'.tr(state),
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
            onPressed: () {
              setState(() {
                _currentStep--;
              });
            },
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: borderCol),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          )
        else
          TextButton(
            onPressed: () {
              setState(() {
                _activeQueue = null;
                _activePatient = null;
              });
            },
            child: Text(
              'Batal'.tr(state),
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: subtitleCol,
              ),
            ),
          ),

        if (_currentStep < 5)
          ElevatedButton.icon(
            icon: const Icon(
              Icons.arrow_forward_rounded,
              size: 14,
              color: Colors.white,
            ),
            label: Text(
              'Selanjutnya'.tr(state),
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            onPressed: () {
              // Validate Step 2: Keluhan & Diagnosis
              if (_currentStep == 2) {
                if (_keluhanController.text.trim().isEmpty) {
                  _showWarningDialog(
                    'Keluhan Kosong',
                    'Harap isi keluhan pasien terlebih dahulu.',
                  );
                  return;
                }
              }
              // Validate Step 4: Vital & Diagnosis
              if (_currentStep == 4) {
                final hasIcd10 = _selectedDiagnoses.any(
                  (d) => RegExp(r'^[A-Z]').hasMatch(d.code),
                );
                final vitalErrors = _validateVitalSigns();
                final errors = <String>[];
                if (!hasIcd10) {
                  errors.add('Diagnosis ICD-10 belum dipilih.');
                }
                errors.addAll(vitalErrors);

                if (errors.isNotEmpty) {
                  String title = 'Peringatan Validasi';
                  if (errors.length == 1) {
                    title = !hasIcd10
                        ? 'Diagnosis Kosong'
                        : 'Vital Sign Tidak Valid';
                  } else {
                    title = 'Pemeriksaan Belum Lengkap';
                  }

                  _showVitalValidationDialog(
                    title: title,
                    errors: errors,
                    onLanjutkan: () {
                      setState(() {
                        _currentStep++;
                      });
                    },
                  );
                  return;
                }
              }
              setState(() {
                _currentStep++;
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: purple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
          )
        else
          ElevatedButton.icon(
            icon: Icon(
              autoSyncEnabled
                  ? Icons.cloud_upload_outlined
                  : Icons.check_circle_outline_rounded,
              size: 14,
              color: Colors.white,
            ),
            label: Text(
              autoSyncEnabled ? 'Simpan & Kirim SatuSehat' : 'Simpan & Selesai',
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
            onPressed: () {
              _showReviewAndSubmitDialog(autoSyncEnabled);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: activeGreen,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
          ),
      ],
    );
  }

  Widget _sectionTitle(String title, Color color) {
    return Text(
      title,
      style: GoogleFonts.outfit(
        fontSize: 10,
        fontWeight: FontWeight.w900,
        color: color,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildVitalInput(
    String label,
    String unit,
    TextEditingController controller,
    IconData icon,
    Color bg,
    Color text,
    Color subtitle,
    Color border,
  ) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 11, color: subtitle),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: GoogleFonts.outfit(
                    fontSize: 7.5,
                    fontWeight: FontWeight.w900,
                    color: subtitle,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    textAlign: TextAlign.start,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: text,
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                Text(
                  unit,
                  style: GoogleFonts.outfit(
                    fontSize: 8.5,
                    fontWeight: FontWeight.bold,
                    color: subtitle,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Component: Right Sidebar (Antrian Pasien) ─────────────────────────────

  Widget _buildQueueSidebar(
    Color cardBg,
    Color text,
    Color subtitle,
    Color border,
    Color purple,
    Color activeGreen,
    List<AntrianModel> queues,
  ) {
    final state = ref.read(landingPageProvider);
    final waitingOrProcessing = queues
        .where((q) => q.status == 'Menunggu' || q.status == 'Memproses...')
        .toList();

    return CollapsibleCard(
      title: 'Antrean Hari Ini',
      cardBg: cardBg,
      border: border,
      subtitle: subtitle,
      initiallyExpanded: _queueCardExpanded,
      onToggle: (val) {
        setState(() {
          _queueCardExpanded = val;
        });
      },
      content: SizedBox(
        height: 560,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (waitingOrProcessing.isEmpty)
              Expanded(
                child: Center(
                  child: Text(
                    'Tidak ada antrean tersisa.',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      color: subtitle,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  itemCount: waitingOrProcessing.length,
                  separatorBuilder: (c, i) => const SizedBox(height: 10),
                  itemBuilder: (context, idx) {
                    final q = waitingOrProcessing[idx];
                    final isCurrentActive = _activeQueue?.no == q.no;

                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isCurrentActive
                            ? purple.withOpacity(0.06)
                            : border.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isCurrentActive ? purple : border,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                q.no,
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  color: purple,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      (q.status == 'Menunggu'
                                              ? Colors.amber
                                              : purple)
                                          .withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(100),
                                ),
                                child: Text(
                                  q.status.toUpperCase(),
                                  style: GoogleFonts.outfit(
                                    fontSize: 6,
                                    fontWeight: FontWeight.w900,
                                    color: q.status == 'Menunggu'
                                        ? Colors.amber[700]!
                                        : purple,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            q.nama,
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: text,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'NIK: ${q.nik} • ${q.tipe}',
                            style: GoogleFonts.outfit(
                              fontSize: 9,
                              color: subtitle,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (isCurrentActive)
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              decoration: BoxDecoration(
                                color: purple,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'SEDANG DIPERIKSA'.tr(state),
                                style: GoogleFonts.outfit(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                            )
                          else
                            ElevatedButton(
                              onPressed: () => _loadPatientFromQueue(q),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: border.withOpacity(0.08),
                                foregroundColor: text,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: Text(
                                q.status == 'Menunggu'
                                    ? 'Mulai Periksa'
                                    : 'Lanjutkan',
                                style: GoogleFonts.outfit(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ─── Component: SatuSehat Sync Overlay Modal ────────────────────────────────

  Widget _buildSatuSehatSyncModal(
    Color cardBg,
    Color text,
    Color subtitle,
    Color border,
    Color purple,
    Color activeGreen,
  ) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.4),
        alignment: Alignment.center,
        child: Container(
          width: 480,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 30,
                offset: const Offset(0, 15),
              ),
            ],
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: !_syncSuccess
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Loading pulse
                      SizedBox(
                        width: 70,
                        height: 70,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(purple),
                          strokeWidth: 4,
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        'SINKRONISASI SATUSEHAT',
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: purple,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _syncStep == 'Connecting'
                            ? 'Menghubungkan ke platform SATUSEHAT Kemenkes...'
                            : (_syncStep == 'SendingEMR'
                                  ? 'Mengirim data Rekam Medis Elektronik (RME) terenkripsi...'
                                  : 'Menerbitkan E-Resep digital di apotek jejaring...'),
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: text,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Harap tunggu sebentar, data dienkripsi dengan standar SatuSehat FHIR.',
                        style: GoogleFonts.outfit(
                          fontSize: 9,
                          color: subtitle,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Giant Sparkling Checkmark
                      Center(
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: activeGreen.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.check_circle_rounded,
                            size: 36,
                            color: activeGreen,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'SINKRONISASI BERHASIL!',
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: text,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Data Rekam Medis Elektronik telah dikirim secara aman.',
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          color: subtitle,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 20),

                      // Receipt Panel
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: border.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _receiptRow(
                              'Transaction ID',
                              _txHash,
                              text,
                              subtitle,
                            ),
                            const Divider(height: 16),
                            _receiptRow(
                              'Pasien',
                              _activePatient?.nama ?? '',
                              text,
                              subtitle,
                            ),
                            const Divider(height: 16),
                            _receiptRow(
                              'Diagnosis',
                              _selectedDiagnoses
                                      .where(
                                        (d) =>
                                            RegExp(r'^[A-Z]').hasMatch(d.code),
                                      )
                                      .map((d) => d.description)
                                      .join(', ')
                                      .isNotEmpty
                                  ? _selectedDiagnoses
                                        .where(
                                          (d) => RegExp(
                                            r'^[A-Z]',
                                          ).hasMatch(d.code),
                                        )
                                        .map((d) => d.description)
                                        .join(', ')
                                  : '-',
                              text,
                              subtitle,
                            ),
                            if (_selectedDiagnoses.any(
                              (d) => RegExp(r'^[0-9]').hasMatch(d.code),
                            )) ...[
                              const Divider(height: 16),
                              _receiptRow(
                                'Prosedur (ICD-9)',
                                _selectedDiagnoses
                                    .where(
                                      (d) => RegExp(r'^[0-9]').hasMatch(d.code),
                                    )
                                    .map((d) => d.description)
                                    .join(', '),
                                text,
                                subtitle,
                              ),
                            ],
                            const Divider(height: 16),
                            _receiptRow(
                              'Resep',
                              '${_addedPrescriptions.length} Jenis Obat',
                              text,
                              subtitle,
                            ),
                            if (_wantReferral) ...[
                              const Divider(height: 16),
                              _receiptRow(
                                'Rujukan Rs',
                                _referralRsController.text,
                                text,
                                subtitle,
                              ),
                            ],
                            const Divider(height: 16),
                            _receiptRow(
                              'SatuSehat status',
                              'FHIR STAGING OK',
                              activeGreen,
                              subtitle,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Verification QR Code
                      Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            'https://api.qrserver.com/v1/create-qr-code/?size=100x100&data=${Uri.encodeComponent('https://mapotech.kemenkes.go.id/receipt/$_txHash')}',
                            width: 70,
                            height: 70,
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Actions
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _completeSyncAndRedirect,
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: border),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                'Tutup',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  color: subtitle,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _completeSyncAndRedirect,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: purple,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                'Cetak Slip EMR',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
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
    );
  }

  Widget _receiptRow(String label, String value, Color textCol, Color subCol) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: subCol,
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: GoogleFonts.outfit(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              color: textCol,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  void _showRujukanPreviewDialog(
    Color textCol,
    Color subtitleCol,
    Color borderCol,
    Color inputBg,
    Color purple,
    Color activeGreen,
  ) {
    final patient = _activePatient;
    if (patient == null) return;

    // Doctor details
    String doctorName = ref.read(landingPageProvider).loggedInUser?['name']?.toString() ?? 'dr. Agoes Soetanto';
    if (!doctorName.toLowerCase().startsWith('dr.')) {
      doctorName = 'dr. $doctorName';
    }

    String doctorSip = ref.read(landingPageProvider).loggedInUser?['sip']?.toString() ?? '503/446/430.10.2/2026';
    if (!doctorSip.toLowerCase().startsWith('sip')) {
      doctorSip = 'SIP: $doctorSip';
    }

    String docLocation = 'Pujer';
    final userMap = ref.read(landingPageProvider).loggedInUser;
    if (userMap != null && userMap['sub_district'] != null) {
      final rawSub = userMap['sub_district'].toString();
      if (rawSub.isNotEmpty) {
        docLocation = rawSub[0].toUpperCase() + rawSub.substring(1).toLowerCase();
      }
    }

    final now = DateTime.now();
    final dayName = [
      'Minggu',
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
    ][now.weekday % 7];
    final monthName = [
      '',
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
    ][now.month];
    final formattedDate = '$dayName, ${now.day} $monthName ${now.year}';

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 40,
            vertical: 24,
          ),
          child: Container(
            width: 720,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Control Bar
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                    border: Border(bottom: BorderSide(color: borderCol)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: activeGreen.withOpacity(0.08),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.assignment_rounded,
                          color: activeGreen,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Surat Rujukan — ${patient.nama}',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: textCol,
                        ),
                      ),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Mencetak Surat Rujukan...'),
                              backgroundColor: Colors.teal,
                            ),
                          );
                        },
                        icon: const Icon(
                          Icons.print_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                        label: Text(
                          'Cetak Surat Rujukan',
                          style: GoogleFonts.outfit(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: activeGreen,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),

                // Paper Preview Area
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Container(
                        width: 640,
                        padding: const EdgeInsets.all(40),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Kop Surat / Header
                            Row(
                              children: [
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: activeGreen.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  alignment: Alignment.center,
                                  child: Icon(
                                    Icons.local_hospital_rounded,
                                    color: activeGreen,
                                    size: 32,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Text(
                                        'DOKTER PRAKTEK MANDIRI ${doctorName.toUpperCase()}',
                                        style: GoogleFonts.outfit(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w900,
                                          color: const Color(0xFF1B0C3C),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Jl. Diponegoro No. 123, Bondowoso',
                                        style: GoogleFonts.outfit(
                                          fontSize: 8.5,
                                          fontWeight: FontWeight.bold,
                                          color: subtitleCol,
                                        ),
                                      ),
                                      Text(
                                        'Telepon: 085259930755',
                                        style: GoogleFonts.outfit(
                                          fontSize: 8.5,
                                          fontWeight: FontWeight.bold,
                                          color: subtitleCol,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 60),
                              ],
                            ),

                            // Double Separator
                            const SizedBox(height: 12),
                            Column(
                              children: [
                                const Divider(
                                  color: Colors.black,
                                  height: 1,
                                  thickness: 1.5,
                                ),
                                const SizedBox(height: 2),
                                const Divider(
                                  color: Colors.black,
                                  height: 1,
                                  thickness: 0.5,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Title Section
                            Center(
                              child: Column(
                                children: [
                                  Text(
                                    'SURAT RUJUKAN PASIEN',
                                    style: GoogleFonts.outfit(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                      color: const Color(0xFF1B0C3C),
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Nomor: REF/DRAFT/PREVIEW',
                                    style: GoogleFonts.outfit(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: subtitleCol,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Recipient Info
                            _rujukanPreviewRow(
                              'Kepada Yth. Sejawat Dokter Di',
                              _referralRsController.text.isNotEmpty
                                  ? _referralRsController.text
                                  : '—',
                              true,
                            ),
                            const SizedBox(height: 6),
                            _rujukanPreviewRow(
                              'Poli / Bagian',
                              _referralPoliController.text.isNotEmpty
                                  ? _referralPoliController.text
                                  : '—',
                              false,
                            ),

                            const SizedBox(height: 16),
                            Text(
                              'Mohon pemeriksaan dan penanganan lebih lanjut terhadap pasien berikut:',
                              style: GoogleFonts.outfit(
                                fontSize: 9.5,
                                color: textCol,
                                fontWeight: FontWeight.w500,
                              ),
                            ),

                            const SizedBox(height: 14),
                            // Identitas Pasien
                            _rujukanSectionTitle(
                              'Identitas Pasien',
                              activeGreen,
                            ),
                            const SizedBox(height: 8),
                            _rujukanPreviewRow(
                              'Nama Pasien',
                              patient.nama,
                              true,
                            ),
                            _rujukanPreviewRow(
                              'Nomor Rekam Medis (RM)',
                              patient.id,
                              false,
                            ),
                            _rujukanPreviewRow(
                              'Nomor NIK',
                              patient.nik.isNotEmpty ? patient.nik : '—',
                              false,
                            ),
                            _rujukanPreviewRow(
                              'Jenis Kelamin',
                              patient.jenisKelamin,
                              false,
                            ),
                            _rujukanPreviewRow(
                              'Tanggal Lahir',
                              '${patient.tanggalLahir} (Usia: ${patient.umur})',
                              false,
                            ),
                            _rujukanPreviewRow('Alamat', patient.alamat, false),

                            const SizedBox(height: 14),
                            // Hasil Pemeriksaan Klinis
                            _rujukanSectionTitle(
                              'Hasil Pemeriksaan Klinis',
                              activeGreen,
                            ),
                            const SizedBox(height: 10),

                            Wrap(
                              spacing: 12,
                              runSpacing: 10,
                              children: [
                                _rujukanVitalItem(
                                  'Tekanan Darah',
                                  _tensiController.text.isNotEmpty
                                      ? '${_tensiController.text} mmHg'
                                      : '— mmHg',
                                  textCol,
                                  subtitleCol,
                                ),
                                _rujukanVitalItem(
                                  'Suhu Tubuh',
                                  _suhuController.text.isNotEmpty
                                      ? '${_suhuController.text} °C'
                                      : '— °C',
                                  textCol,
                                  subtitleCol,
                                ),
                                _rujukanVitalItem(
                                  'Detak Jantung',
                                  _nadiController.text.isNotEmpty
                                      ? '${_nadiController.text} bpm'
                                      : '— bpm',
                                  textCol,
                                  subtitleCol,
                                ),
                                _rujukanVitalItem(
                                  'Nafas',
                                  _respirasiController.text.isNotEmpty
                                      ? '${_respirasiController.text} x/menit'
                                      : '— x/menit',
                                  textCol,
                                  subtitleCol,
                                ),
                                _rujukanVitalItem(
                                  'Berat Badan',
                                  _beratController.text.isNotEmpty
                                      ? '${_beratController.text} kg'
                                      : '— kg',
                                  textCol,
                                  subtitleCol,
                                ),
                                _rujukanVitalItem(
                                  'Tinggi Badan',
                                  _tinggiController.text.isNotEmpty
                                      ? '${_tinggiController.text} cm'
                                      : '— cm',
                                  textCol,
                                  subtitleCol,
                                ),
                                _rujukanVitalItem(
                                  'Saturasi O2',
                                  _spo2Controller.text.isNotEmpty
                                      ? '${_spo2Controller.text} %'
                                      : '— %',
                                  textCol,
                                  subtitleCol,
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),
                            _rujukanPreviewRow(
                              'Keluhan Utama',
                              _keluhanController.text.isNotEmpty
                                  ? _keluhanController.text
                                  : '—',
                              false,
                            ),
                            const SizedBox(height: 6),
                            _rujukanPreviewRow(
                              'Anamnesis',
                              _anamnesisController.text.isNotEmpty
                                  ? _anamnesisController.text
                                  : '—',
                              false,
                            ),
                            const SizedBox(height: 6),
                            _rujukanPreviewRow(
                              'Diagnosa Kerja / ICD-10',
                              _selectedDiagnoses.isEmpty
                                  ? '—'
                                  : _selectedDiagnoses
                                        .map(
                                          (d) => '${d.code} - ${d.description}',
                                        )
                                        .join(', '),
                              false,
                            ),
                            if (_referralNotesController.text.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              _rujukanPreviewRow(
                                'Catatan Rujukan / Terapi',
                                _referralNotesController.text,
                                false,
                              ),
                            ],

                            const SizedBox(height: 16),
                            Text(
                              'Demikian surat rujukan ini kami sampaikan, atas kerja samanya kami ucapkan terima kasih.',
                              style: GoogleFonts.outfit(
                                fontSize: 9.5,
                                color: textCol,
                                fontWeight: FontWeight.w500,
                              ),
                            ),

                            // Signature
                            const SizedBox(height: 24),
                            Align(
                              alignment: Alignment.centerRight,
                              child: SizedBox(
                                width: 220,
                                child: Column(
                                  children: [
                                    Text(
                                      '$docLocation, $formattedDate',
                                      style: GoogleFonts.outfit(
                                        fontSize: 9,
                                        color: textCol,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Dokter Pengirim,',
                                      style: GoogleFonts.outfit(
                                        fontSize: 9,
                                        color: textCol,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: const Color(0xFFECEEF2),
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Image.network(
                                        'https://api.qrserver.com/v1/create-qr-code/?size=80x80&data=https%3A%2F%2Fmapotech.kemenkes.go.id%2Frujukan%2Fpreview',
                                        width: 50,
                                        height: 50,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      doctorName,
                                      style: GoogleFonts.outfit(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w900,
                                        color: textCol,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                    Text(
                                      doctorSip,
                                      style: GoogleFonts.outfit(
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold,
                                        color: subtitleCol,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSuratKeteranganTab(
    Color textCol,
    Color subtitleCol,
    Color borderCol,
    Color inputBg,
    Color purple,
    Color activeGreen,
  ) {
    final patient = _activePatient;
    if (patient == null) {
      return const SizedBox.shrink();
    }

    final isSehat = _suratKeteranganType == 'sehat';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderCol),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Surat Keterangan Dokter',
                      style: GoogleFonts.outfit(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                        color: textCol,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Buat surat keterangan sehat atau surat sakit untuk pasien',
                      style: GoogleFonts.outfit(
                        fontSize: 9.5,
                        color: subtitleCol,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Segmented switch for Sehat vs Sakit
              Container(
                height: 32,
                decoration: BoxDecoration(
                  color: inputBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: borderCol),
                ),
                padding: const EdgeInsets.all(2),
                child: Row(
                  children: [
                    _buildSegmentButton(
                      label: 'Surat Sehat',
                      isActive: isSehat,
                      onTap: () => setState(() {
                        _suratKeteranganType = 'sehat';
                        _wantSuratKeterangan = true;
                      }),
                      borderCol: borderCol,
                      subtitleCol: subtitleCol,
                      textCol: textCol,
                    ),
                    _buildSegmentButton(
                      label: 'Surat Sakit',
                      isActive: !isSehat,
                      onTap: () => setState(() {
                        _suratKeteranganType = 'sakit';
                        _wantSuratKeterangan = true;
                      }),
                      borderCol: borderCol,
                      subtitleCol: subtitleCol,
                      textCol: textCol,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          
          // Form fields
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Keperluan Surat',
                      style: GoogleFonts.outfit(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w900,
                        color: textCol,
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _suratKeperluanController,
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: textCol,
                      ),
                      onChanged: (v) {
                        if (!_wantSuratKeterangan && v.isNotEmpty) {
                          setState(() => _wantSuratKeterangan = true);
                        }
                      },
                      decoration: InputDecoration(
                        hintText: isSehat ? 'Contoh: Melamar Pekerjaan' : 'Contoh: Izin Kerja / Izin Sekolah',
                        hintStyle: GoogleFonts.outfit(
                          fontSize: 11,
                          color: subtitleCol.withOpacity(0.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        isDense: true,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: borderCol),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: purple),
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
                      'Riwayat Penyakit Dahulu (Opsional)',
                      style: GoogleFonts.outfit(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w900,
                        color: textCol,
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _suratRiwayatPenyakitController,
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: textCol,
                      ),
                      onChanged: (v) {
                        if (!_wantSuratKeterangan && v.isNotEmpty) {
                          setState(() => _wantSuratKeterangan = true);
                        }
                      },
                      decoration: InputDecoration(
                        hintText: 'Contoh: Hipertensi, Asma (jika ada)',
                        hintStyle: GoogleFonts.outfit(
                          fontSize: 11,
                          color: subtitleCol.withOpacity(0.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        isDense: true,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: borderCol),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: purple),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Custom fields for Surat Sakit (Rest Duration, Start Date, End Date)
          if (!isSehat) ...[
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Lama Istirahat (Hari)',
                        style: GoogleFonts.outfit(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w900,
                          color: textCol,
                        ),
                      ),
                      const SizedBox(height: 4),
                      TextField(
                        controller: _suratSakitHariController,
                        keyboardType: TextInputType.number,
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: textCol,
                        ),
                        onChanged: (v) {
                          final days = int.tryParse(v) ?? 0;
                          if (_suratSakitStartDate != null) {
                            setState(() {
                              _suratSakitEndDate = _suratSakitStartDate!.add(Duration(days: max(0, days - 1)));
                              _wantSuratKeterangan = true;
                            });
                          }
                        },
                        decoration: InputDecoration(
                          hintText: 'Contoh: 3',
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          isDense: true,
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: borderCol),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: purple),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                // Start Date Picker
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tanggal Mulai Istirahat',
                        style: GoogleFonts.outfit(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w900,
                          color: textCol,
                        ),
                      ),
                      const SizedBox(height: 4),
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _suratSakitStartDate ?? DateTime.now(),
                            firstDate: DateTime.now().subtract(const Duration(days: 30)),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: ColorScheme.light(
                                    primary: purple,
                                    onPrimary: Colors.white,
                                    onSurface: textCol,
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (picked != null) {
                            final days = int.tryParse(_suratSakitHariController.text) ?? 1;
                            setState(() {
                              _suratSakitStartDate = picked;
                              _suratSakitEndDate = picked.add(Duration(days: max(0, days - 1)));
                              _wantSuratKeterangan = true;
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            border: Border.all(color: borderCol),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _suratSakitStartDate != null
                                    ? "${_suratSakitStartDate!.day}/${_suratSakitStartDate!.month}/${_suratSakitStartDate!.year}"
                                    : 'Pilih Tanggal',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: textCol,
                                ),
                              ),
                              Icon(Icons.calendar_today_rounded, size: 14, color: subtitleCol),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                // End Date Display
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tanggal Selesai Istirahat',
                        style: GoogleFonts.outfit(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w900,
                          color: textCol,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: inputBg,
                          border: Border.all(color: borderCol),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _suratSakitEndDate != null
                              ? "${_suratSakitEndDate!.day}/${_suratSakitEndDate!.month}/${_suratSakitEndDate!.year}"
                              : '-',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: textCol.withOpacity(0.8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
          
          const SizedBox(height: 16),
          // Actions: Active/Deactivate or preview draft
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Segmented Button to include or not include Surat Keterangan in the session
              Container(
                height: 32,
                decoration: BoxDecoration(
                  color: inputBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: borderCol),
                ),
                padding: const EdgeInsets.all(2),
                child: Row(
                  children: [
                    _buildSegmentButton(
                      label: 'Tidak Perlu',
                      isActive: !_wantSuratKeterangan,
                      onTap: () => setState(() => _wantSuratKeterangan = false),
                      borderCol: borderCol,
                      subtitleCol: subtitleCol,
                      textCol: textCol,
                    ),
                    _buildSegmentButton(
                      label: 'Terbitkan',
                      isActive: _wantSuratKeterangan,
                      onTap: () => setState(() => _wantSuratKeterangan = true),
                      borderCol: borderCol,
                      subtitleCol: subtitleCol,
                      textCol: textCol,
                    ),
                  ],
                ),
              ),
              
              ElevatedButton.icon(
                onPressed: () {
                  // Make sure _wantSuratKeterangan is activated
                  setState(() => _wantSuratKeterangan = true);
                  _showSuratKeteranganPreviewDialog(
                    textCol,
                    subtitleCol,
                    borderCol,
                    inputBg,
                    purple,
                    activeGreen,
                  );
                },
                icon: const Icon(
                  Icons.print_rounded,
                  size: 14,
                  color: Colors.white,
                ),
                label: Text(
                  isSehat ? 'Cetak Draft Surat Sehat' : 'Cetak Draft Surat Sakit',
                  style: GoogleFonts.outfit(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: activeGreen,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showSuratKeteranganPreviewDialog(
    Color textCol,
    Color subtitleCol,
    Color borderCol,
    Color inputBg,
    Color purple,
    Color activeGreen,
  ) {
    final patient = _activePatient;
    if (patient == null) return;

    final now = DateTime.now();
    final dayName = [
      'Minggu',
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
    ][now.weekday % 7];
    final monthName = [
      '',
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
    ][now.month];
    final formattedDate = '$dayName, ${now.day} $monthName ${now.year}';
    final simpleDate = '${now.day} $monthName ${now.year}';

    // Doctor details
    String doctorName = ref.read(landingPageProvider).loggedInUser?['name']?.toString() ?? 'dr. Agoes Soetanto';
    if (!doctorName.toLowerCase().startsWith('dr.')) {
      doctorName = 'dr. $doctorName';
    }

    String doctorSip = ref.read(landingPageProvider).loggedInUser?['sip']?.toString() ?? '503/446/430.10.2/2026';
    if (!doctorSip.toLowerCase().startsWith('sip')) {
      doctorSip = 'SIP: $doctorSip';
    }

    String docLocation = 'Pujer';
    final userMap = ref.read(landingPageProvider).loggedInUser;
    if (userMap != null && userMap['sub_district'] != null) {
      final rawSub = userMap['sub_district'].toString();
      if (rawSub.isNotEmpty) {
        docLocation = rawSub[0].toUpperCase() + rawSub.substring(1).toLowerCase();
      }
    }

    final isSehat = _suratKeteranganType == 'sehat';
    final title = isSehat ? 'SURAT KETERANGAN SEHAT' : 'SURAT KETERANGAN SAKIT';

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 40,
            vertical: 24,
          ),
          child: Container(
            width: 720,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Control Bar
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                    border: Border(bottom: BorderSide(color: borderCol)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: activeGreen.withOpacity(0.08),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.assignment_rounded,
                          color: activeGreen,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '$title — ${patient.nama}',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: textCol,
                        ),
                      ),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Mencetak ${isSehat ? "Surat Sehat" : "Surat Sakit"}...'),
                              backgroundColor: Colors.teal,
                            ),
                          );
                        },
                        icon: const Icon(
                          Icons.print_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                        label: Text(
                          'Cetak Surat',
                          style: GoogleFonts.outfit(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: activeGreen,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),

                // Paper Preview Area
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Container(
                        width: 640,
                        padding: const EdgeInsets.all(40),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Kop Surat / Header
                            Row(
                              children: [
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: activeGreen.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  alignment: Alignment.center,
                                  child: Icon(
                                    Icons.local_hospital_rounded,
                                    color: activeGreen,
                                    size: 32,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Text(
                                        'DOKTER PRAKTEK MANDIRI ${doctorName.toUpperCase()}',
                                        style: GoogleFonts.outfit(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w900,
                                          color: const Color(0xFF1B0C3C),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Jl. Diponegoro No. 123, Bondowoso',
                                        style: GoogleFonts.outfit(
                                          fontSize: 8.5,
                                          fontWeight: FontWeight.bold,
                                          color: subtitleCol,
                                        ),
                                      ),
                                      Text(
                                        'Telepon: 085259930755',
                                        style: GoogleFonts.outfit(
                                          fontSize: 8.5,
                                          fontWeight: FontWeight.bold,
                                          color: subtitleCol,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 60),
                              ],
                            ),

                            // Double Separator
                            const SizedBox(height: 12),
                            Column(
                              children: [
                                const Divider(
                                  color: Colors.black,
                                  height: 1,
                                  thickness: 1.5,
                                ),
                                const SizedBox(height: 2),
                                const Divider(
                                  color: Colors.black,
                                  height: 1,
                                  thickness: 0.5,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Title Section
                            Center(
                              child: Column(
                                children: [
                                  Text(
                                    title,
                                    style: GoogleFonts.outfit(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                      color: const Color(0xFF1B0C3C),
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    isSehat ? 'Nomor: SK-SEHAT/${now.year}/${100 + Random().nextInt(900)}'
                                            : 'Nomor: SK-SAKIT/${now.year}/${100 + Random().nextInt(900)}',
                                    style: GoogleFonts.outfit(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: subtitleCol,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Introductory
                            Text(
                              'Yang bertanda tangan dibawah ini :',
                              style: GoogleFonts.outfit(
                                fontSize: 9.5,
                                color: textCol,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Doctor details
                            _rujukanPreviewRow('Nama Dokter', doctorName, true),
                            _rujukanPreviewRow('Jabatan / Status', 'Dokter Praktek Umum Swasta', false),
                            
                            const SizedBox(height: 16),
                            Text(
                              'Menerangkan dengan sesungguhnya bahwa, penderita dengan :',
                              style: GoogleFonts.outfit(
                                fontSize: 9.5,
                                color: textCol,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Patient details
                            _rujukanPreviewRow('Nama Pasien', patient.nama, true),
                            _rujukanPreviewRow('Umur', '${patient.umur}', false),
                            _rujukanPreviewRow('Alamat', patient.alamat, false),

                            const SizedBox(height: 16),
                            // Certificate details
                            if (isSehat) ...[
                              Text(
                                'Pada tanggal : $formattedDate telah diperiksa kesehatannya dan dinyatakan berbadan sehat baik jasmani maupun rohaninya.',
                                style: GoogleFonts.outfit(
                                  fontSize: 9.5,
                                  color: textCol,
                                  height: 1.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ] else ...[
                              Text(
                                'Pada tanggal : $formattedDate telah diperiksa kesehatannya dan dinyatakan dalam keadaan kurang sehat / sakit sehingga memerlukan istirahat selama ${_suratSakitHariController.text} hari, terhitung mulai tanggal ${_suratSakitStartDate != null ? "${_suratSakitStartDate!.day} " + ["Januari", "Februari", "Maret", "April", "Mei", "Juni", "Juli", "Agustus", "September", "Oktober", "November", "Desember"][_suratSakitStartDate!.month - 1] + " ${_suratSakitStartDate!.year}" : "-"} s/d ${_suratSakitEndDate != null ? "${_suratSakitEndDate!.day} " + ["Januari", "Februari", "Maret", "April", "Mei", "Juni", "Juli", "Agustus", "September", "Oktober", "November", "Desember"][_suratSakitEndDate!.month - 1] + " ${_suratSakitEndDate!.year}" : "-"} .',
                                style: GoogleFonts.outfit(
                                  fontSize: 9.5,
                                  color: textCol,
                                  height: 1.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
                            _rujukanPreviewRow(
                              'Keperluan', 
                              _suratKeperluanController.text.isNotEmpty 
                                  ? _suratKeperluanController.text 
                                  : '—', 
                              false
                            ),

                            const SizedBox(height: 16),
                            _rujukanSectionTitle('Pemeriksaan Fisik & Klinis', activeGreen),
                            const SizedBox(height: 8),
                            _rujukanPreviewRow(
                              'Tensi / Tekanan Darah', 
                              _tensiController.text.isNotEmpty 
                                  ? '${_tensiController.text} mmHg' 
                                  : '—', 
                              false
                            ),
                            _rujukanPreviewRow(
                              'Nadi', 
                              _nadiController.text.isNotEmpty 
                                  ? '${_nadiController.text} x/menit' 
                                  : '—', 
                              false
                            ),
                            _rujukanPreviewRow(
                              'Riwayat Penyakit Dahulu', 
                              _suratRiwayatPenyakitController.text.isNotEmpty 
                                  ? _suratRiwayatPenyakitController.text 
                                  : 'Tidak Ada', 
                              false
                            ),

                            const SizedBox(height: 24),
                            Text(
                              'Demikian surat keterangan ini dibuat untuk digunakan sebagaimana mestinya.',
                              style: GoogleFonts.outfit(
                                fontSize: 9.5,
                                color: textCol,
                                fontWeight: FontWeight.w500,
                              ),
                            ),

                            const SizedBox(height: 32),
                            // Signature area
                            Align(
                              alignment: Alignment.centerRight,
                              child: SizedBox(
                                width: 200,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text(
                                      '$docLocation, $simpleDate',
                                      style: GoogleFonts.outfit(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.bold,
                                        color: textCol,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: const Color(0xFFECEEF2),
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Image.network(
                                        'https://api.qrserver.com/v1/create-qr-code/?size=80x80&data=https%3A%2F%2Fmapotech.kemenkes.go.id%2F${isSehat ? "surat-sehat" : "surat-sakit"}%2Fpreview',
                                        width: 50,
                                        height: 50,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      doctorName,
                                      style: GoogleFonts.outfit(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w900,
                                        color: textCol,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                    Text(
                                      doctorSip,
                                      style: GoogleFonts.outfit(
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold,
                                        color: subtitleCol,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                ],
              ),
            ),
          );
        },
      );
    }

  Widget _rujukanSectionTitle(String title, Color activeGreen) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: activeGreen.withOpacity(0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border(left: BorderSide(color: activeGreen, width: 3)),
      ),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.outfit(
          fontSize: 8.5,
          fontWeight: FontWeight.w900,
          color: activeGreen,
        ),
      ),
    );
  }

  Widget _rujukanPreviewRow(String label, String value, bool isBoldVal) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 180,
          child: Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF6F6A8A),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          ': ',
          style: GoogleFonts.outfit(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF6F6A8A),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 9.5,
              fontWeight: isBoldVal ? FontWeight.w900 : FontWeight.bold,
              color: const Color(0xFF1B0C3C),
            ),
          ),
        ),
      ],
    );
  }

  Widget _rujukanVitalItem(
    String label,
    String value,
    Color textCol,
    Color subtitleCol,
  ) {
    return Container(
      width: 120,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        border: Border.all(color: const Color(0xFFECEEF2)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: GoogleFonts.outfit(
              fontSize: 7.5,
              fontWeight: FontWeight.bold,
              color: subtitleCol,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              color: textCol,
            ),
          ),
        ],
      ),
    );
  }

  // ─── KFA Search Modal ────────────────────────────────────────────────────────

  /// Opens a dedicated KFA search dialog. Returns the selected product map
  /// (keys: nama, code, jenis, satuan) or null if dismissed.
  Future<Map<String, dynamic>?> _showKfaSearchModal(
    BuildContext context,
    bool isDark,
  ) async {
    final state = ref.read(landingPageProvider);
    final purple = ref.read(landingPageProvider.notifier).getPrimaryColor();
    final cardBg = isDark ? const Color(0xFF161619) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1B0C3C);
    final subtitleColor = isDark ? Colors.grey[400]! : const Color(0xFF6F6A8A);
    final borderColor = isDark ? const Color(0xFF252528) : const Color(0xFFECEEF2);
    final inputBg = isDark ? const Color(0xFF1E1E22) : const Color(0xFFF6F8FA);

    final searchController = TextEditingController();
    List<Map<String, dynamic>> results = [];
    bool isLoading = false;
    String? errorMsg;

    return showDialog<Map<String, dynamic>>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          Future<void> doSearch() async {
            final keyword = searchController.text.trim();
            if (keyword.isEmpty) return;
            setState(() { isLoading = true; errorMsg = null; results = []; });

            try {
              final doctorId = ref.read(landingPageProvider).activeDoctorId ?? '';
              final docDetail = await SupabaseService.client
                  .from('user_detail_doctor')
                  .select('satu_sehat_api, id_satusehat')
                  .eq('id', doctorId)
                  .maybeSingle();

              final ssConfig = docDetail?['satu_sehat_api'] as Map<String, dynamic>?;
              if (ssConfig == null || ssConfig['client_id'] == null) {
                setState(() { errorMsg = 'Konfigurasi API SatuSehat belum lengkap.'; isLoading = false; });
                return;
              }

              final ssService = SatuSehatService(
                clientId: ssConfig['client_id']?.toString(),
                clientSecret: ssConfig['client_secret']?.toString(),
                organizationId: ssConfig['organization_id']?.toString(),
                locationId: ssConfig['location_id']?.toString() ?? docDetail?['id_satusehat']?.toString(),
                env: ssConfig['env']?.toString(),
              );

              final searchRes = await ssService.searchKfaProducts(keyword: keyword);
              if (searchRes['status'] != true) {
                setState(() { errorMsg = searchRes['message']?.toString() ?? 'Gagal mengambil data KFA.'; isLoading = false; });
                return;
              }

              final searchData = searchRes['data'];
              List<dynamic> dataList = [];
              if (searchData is Map && searchData['items'] is Map) {
                final items = searchData['items'];
                if (items['data'] is List) dataList = items['data'] as List;
              } else if (searchData is Map && searchData['items'] is List) {
                dataList = searchData['items'] as List;
              }

              final mapped = dataList.map<Map<String, dynamic>>((e) => {
                'nama': e['name']?.toString() ?? '',
                'code': e['kfa_code']?.toString() ?? '',
                'jenis': e['farmalkes_type']?['name']?.toString() ?? 'Generik',
                'satuan': e['uom']?['name']?.toString() ?? 'Tablet',
              }).toList();

              setState(() {
                results = mapped;
                errorMsg = mapped.isEmpty ? 'Produk tidak ditemukan.' : null;
                isLoading = false;
              });
            } catch (e) {
              setState(() { errorMsg = 'Error: $e'; isLoading = false; });
            }
          }

          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Container(
              width: 560,
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.82,
              ),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 40,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [purple.withOpacity(0.12), purple.withOpacity(0.04)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: purple.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Icon(Icons.medication_liquid_rounded, color: purple, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Katalog KFA SatuSehat'.tr(state),
                                style: GoogleFonts.outfit(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  color: textColor,
                                ),
                              ),
                              Text(
                                'Cari obat dari database resmi Kemenkes'.tr(state),
                                style: GoogleFonts.outfit(fontSize: 10, color: subtitleColor),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                  ),

                  // Search bar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 44,
                            decoration: BoxDecoration(
                              color: inputBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: borderColor),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Row(
                              children: [
                                Icon(Icons.search_rounded, size: 18, color: subtitleColor),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextField(
                                    controller: searchController,
                                    autofocus: true,
                                    style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: textColor,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'cth. Paracetamol, Amoxicillin...'.tr(state),
                                      hintStyle: GoogleFonts.outfit(
                                        fontSize: 12,
                                        color: subtitleColor.withOpacity(0.5),
                                      ),
                                      border: InputBorder.none,
                                      isDense: true,
                                    ),
                                    onSubmitted: (_) => doSearch(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: purple,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                          ),
                          onPressed: isLoading ? null : doSearch,
                          child: isLoading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  'Cari'.tr(state),
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),

                  // Divider
                  Divider(height: 1, color: borderColor),

                  // Results
                  Flexible(
                    child: errorMsg != null
                        ? Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.search_off_rounded, size: 40, color: subtitleColor.withOpacity(0.4)),
                                const SizedBox(height: 12),
                                Text(
                                  errorMsg!,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.outfit(fontSize: 12, color: subtitleColor),
                                ),
                              ],
                            ),
                          )
                        : results.isEmpty && !isLoading
                            ? Padding(
                                padding: const EdgeInsets.all(32),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.medication_liquid_rounded, size: 40, color: subtitleColor.withOpacity(0.25)),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Ketik nama obat lalu tekan Cari'.tr(state),
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.outfit(fontSize: 12, color: subtitleColor.withOpacity(0.6)),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.all(12),
                                shrinkWrap: true,
                                itemCount: results.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 8),
                                itemBuilder: (_, idx) {
                                  final item = results[idx];
                                  return InkWell(
                                    onTap: () => Navigator.of(ctx).pop(item),
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: inputBg,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: borderColor),
                                      ),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          Container(
                                            width: 38,
                                            height: 38,
                                            decoration: BoxDecoration(
                                              color: purple.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(9),
                                            ),
                                            alignment: Alignment.center,
                                            child: Icon(Icons.medication_rounded, color: purple, size: 20),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  item['nama'] ?? '',
                                                  style: GoogleFonts.outfit(
                                                    fontSize: 12.5,
                                                    fontWeight: FontWeight.w800,
                                                    color: textColor,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Row(
                                                  children: [
                                                    _kfaChip(item['jenis'] ?? '', purple.withOpacity(0.12), purple),
                                                    const SizedBox(width: 6),
                                                    _kfaChip(item['satuan'] ?? '', subtitleColor.withOpacity(0.1), subtitleColor),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'KFA: ${item['code'] ?? '-'}',
                                                  style: GoogleFonts.outfit(
                                                    fontSize: 9.5,
                                                    color: subtitleColor,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Icon(
                                            Icons.arrow_forward_ios_rounded,
                                            size: 13,
                                            color: subtitleColor.withOpacity(0.5),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                  ),

                  const SizedBox(height: 8),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _kfaChip(String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: GoogleFonts.outfit(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}

class CollapsibleCard extends StatefulWidget {
  final String title;
  final Widget content;
  final bool initiallyExpanded;
  final Color cardBg;
  final Color border;
  final Color subtitle;
  final ValueChanged<bool>? onToggle;

  const CollapsibleCard({
    super.key,
    required this.title,
    required this.content,
    required this.cardBg,
    required this.border,
    required this.subtitle,
    this.initiallyExpanded = true,
    this.onToggle,
  });

  @override
  State<CollapsibleCard> createState() => _CollapsibleCardState();
}

class _CollapsibleCardState extends State<CollapsibleCard> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: widget.cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: widget.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
              if (widget.onToggle != null) {
                widget.onToggle!(_isExpanded);
              }
            },
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.title.toUpperCase(),
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: widget.subtitle,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: widget.subtitle,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
              child: widget.content,
            ),
            crossFadeState: _isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }
}

class VitalWarning {
  final String label;
  final String category; // 'bp', 'hr', 'rr', 'temp', 'spo2', 'bmi'
  final Color color;
  final Color bgColor;
  final Color borderColor;
  final bool isCritical;

  VitalWarning({
    required this.label,
    required this.category,
    required this.color,
    required this.bgColor,
    required this.borderColor,
    required this.isCritical,
  });
}

class VitalInputFormatter extends TextInputFormatter {
  final bool isDecimal;
  final double? maxVal;

  VitalInputFormatter({required this.isDecimal, this.maxVal});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    // Allow only digits and at most one dot or comma if decimal
    final pattern = isDecimal ? r'^[0-9]*[.,]?[0-9]*$' : r'^[0-9]*$';
    final regExp = RegExp(pattern);
    if (!regExp.hasMatch(newValue.text)) {
      return oldValue;
    }

    if (maxVal != null) {
      final normalizedText = newValue.text.replaceAll(',', '.');
      final val = double.tryParse(normalizedText);
      if (val != null && val > maxVal!) {
        return oldValue;
      }
    }

    return newValue;
  }
}
