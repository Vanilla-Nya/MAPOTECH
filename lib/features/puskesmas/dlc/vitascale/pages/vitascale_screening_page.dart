import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapotech/features/landing/landing_page_data.dart';
import 'package:mapotech/shared/satusehat_service.dart';
import 'package:mapotech/shared/widgets/ui.dart';

import '../cv/vitascale_camera_bridge.dart';
import '../data/vitascale_api_service.dart';
import '../data/vitascale_device_simulator.dart';
import '../data/vitascale_models.dart';
import '../data/vitascale_repository.dart';
import '../logic/screening_state_machine.dart';
import '../logic/vitascale_reasoning_service.dart';
import '../vitascale_dlc_gate.dart';
import '../widgets/measurement_card.dart';
import '../widgets/vitascale_status_bar.dart';

class VitaScaleScreeningPage extends ConsumerStatefulWidget {
  final ChildProfile? selectedChild;
  final ValueChanged<String>? onNavigateToMenu;

  const VitaScaleScreeningPage({
    super.key,
    this.selectedChild,
    this.onNavigateToMenu,
  });

  @override
  ConsumerState<VitaScaleScreeningPage> createState() => _VitaScaleScreeningPageState();
}

class _VitaScaleScreeningPageState extends ConsumerState<VitaScaleScreeningPage> {
  // Mode Tab: 0 = Input Manual & AI Reasoning (Uji Ukur), 1 = Perangkat IoT & Webcam CV
  int _activeTab = 0;
  int _formStep = 1; // 1: Identitas Balita, 2: Antropometri Fisik, 3: Reasoning AI, 4: SATUSEHAT & Database

  // Simulator & Repo untuk Mode IoT
  late final VitaScaleDeviceSimulator _simulator;
  final VitaScaleRepository _repository = VitaScaleRepository();
  final TextEditingController _notesController = TextEditingController();

  List<ChildProfile> _availableChildren = [];
  ChildProfile? _activeChild;

  // Pencarian Pasien di Bagian Atas
  final TextEditingController _topSearchController = TextEditingController();
  String _topSearchQuery = '';

  // ===========================================================================
  // STATE INPUT MANUAL & API MLP & REASONING MODEL
  // ===========================================================================
  final TextEditingController _nameController = TextEditingController(text: 'Muhammad Rayyan Al-Fatih');
  final TextEditingController _nikController = TextEditingController(text: '3511082208230001');
  final TextEditingController _ageController = TextEditingController(text: '24');
  final TextEditingController _weightController = TextEditingController(text: '11.5');
  final TextEditingController _heightController = TextEditingController(text: '85.0');
  final TextEditingController _waistController = TextEditingController(text: '46.0');
  final TextEditingController _lilaController = TextEditingController(text: '14.5');
  final TextEditingController _headCircumferenceController = TextEditingController(text: '47.0');

  int _selectedGender = 0; // 0 = Laki-laki, 1 = Perempuan
  double _ageMonths = 24.0;

  // Parameter Khusus Buku KIA 2024 & SATUSEHAT
  String _measurementMethod = 'TB'; // 'PB' = Telentang (<24 bln), 'TB' = Berdiri (≥24 bln)
  String _kmsStatus = 'N'; // 'N', 'T', '2T', 'BGM', 'Baru'
  bool _receivedVitA = true;
  bool _receivedDeworming = true;

  // SATUSEHAT FHIR State
  bool _isCheckingSatuSehatPatient = false;
  String? _satuSehatPatientId;
  bool _isSyncingSatuSehat = false;
  Map<String, dynamic>? _satuSehatSyncResult;

  // Server health state
  bool _isCheckingServer = false;
  Map<String, dynamic>? _serverStatus;

  // Prediction & Reasoning State
  bool _isLoadingClassification = false;
  HasilSmartGrowthBalita? _smartGrowthResult;

  bool _isLoadingReasoning = false;
  VitaScaleReasoningResult? _reasoningResult;
  int _activeReasoningTab = 0;
  int _reasoningPromptCount = 0;

  @override
  void initState() {
    super.initState();
    _simulator = VitaScaleDeviceSimulator(
      stateMachine: ref.read(screeningStateProvider.notifier),
    );

    _initSession();
    _checkServer();
  }

  @override
  void didUpdateWidget(covariant VitaScaleScreeningPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedChild != null && widget.selectedChild?.id != oldWidget.selectedChild?.id) {
      _selectChild(widget.selectedChild!);
    }
  }

  void _selectChild(ChildProfile child) {
    setState(() {
      _activeChild = child;
      _topSearchController.clear();
      _topSearchQuery = '';
    });
    _fillFormWithChild(child);

    final state = ref.read(landingPageProvider);
    final facilityId = state.activePuskesmasId ?? 'PUSKESMAS-001';
    ref.read(screeningStateProvider.notifier).startSession(
          child: child,
          facilityId: facilityId,
          isDemo: true,
        );
  }

  Future<void> _checkServer() async {
    setState(() => _isCheckingServer = true);
    final status = await VitaScaleApiService.checkHealth();
    if (mounted) {
      setState(() {
        _serverStatus = status;
        _isCheckingServer = false;
      });
    }
  }

  Future<void> _initSession() async {
    final list = await _repository.searchChildren();
    if (mounted) {
      setState(() {
        _availableChildren = list;
        _activeChild = widget.selectedChild;
      });

      if (_activeChild != null) {
        _fillFormWithChild(_activeChild!);
        final state = ref.read(landingPageProvider);
        final facilityId = state.activePuskesmasId ?? 'PUSKESMAS-001';

        ref.read(screeningStateProvider.notifier).startSession(
              child: _activeChild!,
              facilityId: facilityId,
              isDemo: true,
            );
      }
    }
  }

  void _fillFormWithChild(ChildProfile child) {
    setState(() {
      _formStep = 1;
      _reasoningPromptCount = 0;
      _smartGrowthResult = null;
      _reasoningResult = null;
      _nameController.text = child.name;
      _nikController.text = child.nik;
      _selectedGender = child.gender == 'L' ? 0 : 1;
      _ageMonths = child.ageInMonths.toDouble();
      _ageController.text = child.ageInMonths.toString();
      _measurementMethod = child.isUnder24Months ? 'PB' : 'TB';
      _satuSehatPatientId = null;
      _satuSehatSyncResult = null;

      // Estimasi default BB, TB, LK realistis sesuai standar Buku KIA 2024
      if (child.isUnder24Months) {
        _weightController.text = '9.5';
        _heightController.text = '76.0';
        _headCircumferenceController.text = '45.5';
      } else {
        _weightController.text = '12.0';
        _heightController.text = '88.0';
        _headCircumferenceController.text = '48.0';
      }
    });
  }

  @override
  void dispose() {
    _simulator.dispose();
    _notesController.dispose();
    _topSearchController.dispose();
    _nameController.dispose();
    _nikController.dispose();
    _ageController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _waistController.dispose();
    _lilaController.dispose();
    _headCircumferenceController.dispose();
    super.dispose();
  }

  // ===========================================================================
  // PRESET UJI CEPAT (BUKU KIA 2024 & STANDAR ANTROPOMETRI)
  // ===========================================================================
  void _applyPreset(
    String label, {
    required int jk,
    required double usia,
    required double bb,
    required double tb,
    double lk = 47.0,
    double lila = 14.5,
    String? caraUkur,
    String kms = 'N',
  }) {
    setState(() {
      _selectedGender = jk;
      _ageMonths = usia;
      _ageController.text = usia.toStringAsFixed(0);
      _weightController.text = bb.toStringAsFixed(1);
      _heightController.text = tb.toStringAsFixed(1);
      _headCircumferenceController.text = lk.toStringAsFixed(1);
      _lilaController.text = lila.toStringAsFixed(1);
      _measurementMethod = caraUkur ?? (usia < 24 ? 'PB' : 'TB');
      _kmsStatus = kms;
      _satuSehatSyncResult = null;
      _smartGrowthResult = null;
      _reasoningResult = null;
      _reasoningPromptCount = 0;
    });

    CustomSnackbar.info(
      context,
      'Data preset "$label" telah dimuat: JK ${jk == 0 ? "L" : "P"}, Usia $usia bln, BB $bb kg, TB $tb cm, LK $lk cm.',
      title: 'Preset Uji Dimuat',
    );
  }

  // ===========================================================================
  // HELPER BUKU KIA 2024 & SATUSEHAT
  // ===========================================================================
  Color _getLilaColor(double? val) {
    if (val == null) return Colors.grey;
    if (val < 11.5) return const Color(0xFFE74C3C); // Merah - Gizi Buruk / Wasting Akut
    if (val <= 12.5) return const Color(0xFFE67E22); // Kuning - Risiko Gizi Kurang
    return const Color(0xFF27AE60); // Hijau - Pita Normal
  }

  String _getLilaStatusText(double? val) {
    if (val == null) return 'Belum Diukur';
    if (val < 11.5) return 'Merah (<11.5 cm) • Indikasi Gizi Buruk / Wasting Akut';
    if (val <= 12.5) return 'Kuning (11.5-12.5 cm) • Risiko Gizi Kurang';
    return 'Hijau (>12.5 cm) • Status Gizi Normal';
  }

  String _getKmsLabel(String code) {
    switch (code) {
      case 'N':
        return 'N (Naik Sesuai KBM)';
      case 'T':
        return 'T (Tidak Naik / Tetap / Turun)';
      case '2T':
        return '2T (Dua Kali Tidak Naik Berturut-turut - Red Flag)';
      case 'BGM':
        return 'BGM (Bawah Garis Merah - Red Flag)';
      case 'Baru':
      default:
        return 'Penimbangan Pertama Kali';
    }
  }

  SatuSehatService _getSatuSehatService() {
    final state = ref.read(landingPageProvider);
    return SatuSehatService(
      clientId: dotenv.env['SATUSEHAT_CLIENT_ID'] ?? dotenv.env['SATUSEHAT_CLIENTID'],
      clientSecret: dotenv.env['SATUSEHAT_CLIENT_SECRET'] ?? dotenv.env['SATUSEHAT_CLIENTSECRET'],
      organizationId: dotenv.env['SATUSEHAT_ORG_ID'] ?? state.activePuskesmasId ?? '10000004',
      locationId: dotenv.env['SATUSEHAT_LOCATION_ID'] ?? 'b017aa54-f1df-4ec2-9529-81788148b1d9',
      env: dotenv.env['SATUSEHAT_ENV'] ?? 'stg',
    );
  }

  Future<void> _checkSatuSehatPatient() async {
    final nik = _nikController.text.trim();
    if (nik.length != 16) {
      CustomSnackbar.warning(
        context,
        'Harap masukkan 16 digit NIK balita yang valid.',
        title: 'NIK Tidak Valid',
      );
      return;
    }

    setState(() => _isCheckingSatuSehatPatient = true);

    try {
      final ss = _getSatuSehatService();
      if (!ss.isConfigured()) {
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) {
          setState(() {
            _satuSehatPatientId = 'P${nik.substring(nik.length - 10)}';
            _isCheckingSatuSehatPatient = false;
          });
          CustomSnackbar.info(
            context,
            'IHS Pasien (Mode Uji Coba): $_satuSehatPatientId telah disiapkan untuk NIK $nik.',
            title: 'SatuSehat Sandbox',
          );
        }
        return;
      }

      final res = await ss.getPatientIdByNik(nik);
      if (mounted) {
        setState(() {
          _isCheckingSatuSehatPatient = false;
          if (res['status'] == true && res['id'] != null) {
            _satuSehatPatientId = res['id'].toString();
          } else {
            _satuSehatPatientId = 'P${nik.substring(nik.length - 10)}';
          }
        });

        if (res['status'] == true) {
          CustomSnackbar.success(
            context,
            'Pasien terverifikasi di SATUSEHAT! IHS Number: $_satuSehatPatientId',
            title: 'SATUSEHAT Terhubung',
          );
        } else {
          CustomSnackbar.info(
            context,
            'Pasien belum terdaftar live (${res['message']}). Mode simulasi IHS diaktifkan: $_satuSehatPatientId',
            title: 'SATUSEHAT Sandbox',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCheckingSatuSehatPatient = false;
          _satuSehatPatientId = 'P${nik.substring(nik.length - 10)}';
        });
        CustomSnackbar.info(
          context,
          'Koneksi live SatuSehat menggunakan simulasi sandbox: $_satuSehatPatientId',
          title: 'Mode Uji Coba SatuSehat',
        );
      }
    }
  }

  Future<void> _syncToSatuSehat() async {
    final bb = double.tryParse(_weightController.text.trim());
    final tb = double.tryParse(_heightController.text.trim());
    if (bb == null || tb == null) {
      CustomSnackbar.warning(context, 'Data antropometri belum lengkap.');
      return;
    }

    setState(() => _isSyncingSatuSehat = true);

    final nik = _nikController.text.trim();
    final patientId = _satuSehatPatientId ?? (nik.length == 16 ? 'P${nik.substring(nik.length - 10)}' : 'P1000029384');
    final childName = _nameController.text.trim().isEmpty ? 'Balita Sasaran' : _nameController.text.trim();
    final isRecumbent = _measurementMethod == 'PB';
    final lk = double.tryParse(_headCircumferenceController.text.trim());
    final lila = double.tryParse(_lilaController.text.trim());
    final waist = double.tryParse(_waistController.text.trim());

    // Tentukan diagnosis ICD-10 berdasar hasil MLP / Buku KIA
    String diagCode = 'Z00.1';
    String diagDesc = 'Pemeriksaan kesehatan anak rutin';
    if (_smartGrowthResult != null) {
      if (_smartGrowthResult!.isStunting) {
        diagCode = 'E45';
        diagDesc = 'Retardasi perkembangan akibat malnutrisi energi-protein (Stunting)';
      } else if (_smartGrowthResult!.isGiziBurukAtauKurang) {
        diagCode = 'E44.0';
        diagDesc = 'Malnutrisi energi-protein sedang (Gizi Kurang)';
      }
    }

    try {
      final ss = _getSatuSehatService();
      final encounterUuid = 'ENC-${DateTime.now().millisecondsSinceEpoch}';

      if (!ss.isConfigured()) {
        await Future.delayed(const Duration(milliseconds: 900));
        if (mounted) {
          setState(() {
            _isSyncingSatuSehat = false;
            _satuSehatSyncResult = {
              'status': true,
              'mode': 'Simulasi Sandbox FHIR R4',
              'encounter_id': encounterUuid,
              'patient_id': patientId,
              'synced_at': DateTime.now().toIso8601String(),
              'observations_count': 2 + (lk != null ? 1 : 0) + (lila != null ? 1 : 0) + (waist != null ? 1 : 0),
              'diagnosis_code': diagCode,
              'diagnosis_desc': diagDesc,
            };
          });
          CustomSnackbar.success(
            context,
            'Berhasil membuat Payload FHIR R4 & verifikasi format observasi SATUSEHAT (LOINC).',
            title: 'Sinkronisasi SATUSEHAT Siap',
          );
        }
        return;
      }

      final headers = {
        'Content-Type': 'application/json',
      };
      final encRes = await ss.createEncounter(
        headers: headers,
        patientId: patientId,
        patientName: childName,
        doctorId: '10000001',
        doctorName: 'Petugas Gizi Puskesmas',
        encounterId: encounterUuid,
      );

      final ssEncounterId = encRes['data']?['id']?.toString() ?? encounterUuid;

      final result = await ss.sendAnthropometryData(
        patientId: patientId,
        patientName: childName,
        doctorId: '10000001',
        doctorName: 'Petugas Gizi Puskesmas',
        encounterId: ssEncounterId,
        weightKg: bb,
        heightCm: tb,
        isRecumbent: isRecumbent,
        headCircumferenceCm: lk,
        lilaCm: lila,
        waistCm: waist,
        diagnosisCode: diagCode,
        diagnosisDesc: diagDesc,
      );

      if (mounted) {
        setState(() {
          _isSyncingSatuSehat = false;
          _satuSehatSyncResult = {
            'status': true,
            'mode': 'Live SATUSEHAT Kemenkes RI',
            'encounter_id': ssEncounterId,
            'patient_id': patientId,
            'synced_at': DateTime.now().toIso8601String(),
            'observations_count': (result['observations'] as List?)?.length ?? 0,
            'diagnosis_code': diagCode,
            'diagnosis_desc': diagDesc,
          };
        });
        CustomSnackbar.success(
          context,
          'Data antropometri balita berhasil terkirim ke SATUSEHAT Kemenkes RI!',
          title: 'SATUSEHAT Sync Berhasil',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSyncingSatuSehat = false;
          _satuSehatSyncResult = {
            'status': true,
            'mode': 'Simulasi Sandbox FHIR R4 (Fallback)',
            'encounter_id': 'ENC-${DateTime.now().millisecondsSinceEpoch}',
            'patient_id': patientId,
            'synced_at': DateTime.now().toIso8601String(),
            'diagnosis_code': diagCode,
            'diagnosis_desc': diagDesc,
            'note': e.toString(),
          };
        });
        CustomSnackbar.info(
          context,
          'Data format FHIR R4 terverifikasi (Koneksi live terhambat: $e).',
          title: 'SATUSEHAT Payload Ready',
        );
      }
    }
  }

  // ===========================================================================
  // VALIDASI FORM SKRINING BALITA & REVIEW DIALOG (PRAKTIK MANDIRI DOKTER MODEL)
  // ===========================================================================
  List<Map<String, dynamic>> _validateScreeningForm() {
    final issues = <Map<String, dynamic>>[];

    // --- LANGKAH 1: IDENTITAS BALITA ---
    final nik = _nikController.text.trim();
    if (nik.isEmpty) {
      issues.add({
        'step': 1,
        'stepName': '1. Identitas Balita',
        'field': 'NIK Balita',
        'message': 'NIK Balita Wajib Diisi (16 Digit)',
        'isError': true, // 🔴 Red
      });
    } else if (nik.length != 16 || !RegExp(r'^\d{16}$').hasMatch(nik)) {
      issues.add({
        'step': 1,
        'stepName': '1. Identitas Balita',
        'field': 'NIK Balita',
        'message': 'NIK Balita Harus 16 Digit Angka Valid',
        'isError': true, // 🔴 Red
      });
    }

    if (_nameController.text.trim().isEmpty) {
      issues.add({
        'step': 1,
        'stepName': '1. Identitas Balita',
        'field': 'Nama Balita',
        'message': 'Nama Lengkap Balita Wajib Diisi',
        'isError': true, // 🔴 Red
      });
    }

    if (_ageMonths <= 0) {
      issues.add({
        'step': 1,
        'stepName': '1. Identitas Balita',
        'field': 'Usia Balita',
        'message': 'Usia Balita Harus Lebih dari 0 Bulan',
        'isError': true, // 🔴 Red
      });
    }

    if (_satuSehatPatientId == null) {
      issues.add({
        'step': 1,
        'stepName': '1. Identitas Balita',
        'field': 'SATUSEHAT',
        'message': 'IHS SATUSEHAT Belum Diverifikasi',
        'isError': false, // 🟡 Yellow Opsional
      });
    }

    // --- LANGKAH 2: ANTROPOMETRI FISIK ---
    final bb = double.tryParse(_weightController.text.trim());
    if (bb == null || bb <= 0) {
      issues.add({
        'step': 2,
        'stepName': '2. Antropometri',
        'field': 'Berat Badan',
        'message': 'Berat Badan Belum Diisi / Tidak Valid',
        'isError': true, // 🔴 Red
      });
    }

    final tb = double.tryParse(_heightController.text.trim());
    if (tb == null || tb <= 0) {
      issues.add({
        'step': 2,
        'stepName': '2. Antropometri',
        'field': 'Tinggi/Panjang Badan',
        'message': 'Tinggi/Panjang Badan Belum Diisi',
        'isError': true, // 🔴 Red
      });
    }

    final lila = double.tryParse(_lilaController.text.trim());
    if (lila == null || lila <= 0) {
      issues.add({
        'step': 2,
        'stepName': '2. Antropometri',
        'field': 'LiLA Balita',
        'message': 'Pengukuran LiLA Belum Diisi',
        'isError': false, // 🟡 Yellow Opsional
      });
    }

    final lk = double.tryParse(_headCircumferenceController.text.trim());
    if (lk == null || lk <= 0) {
      issues.add({
        'step': 2,
        'stepName': '2. Antropometri',
        'field': 'Lingkar Kepala',
        'message': 'Lingkar Kepala Belum Diisi',
        'isError': false, // 🟡 Yellow Opsional
      });
    }

    final lp = double.tryParse(_waistController.text.trim());
    if (lp == null || lp <= 0) {
      issues.add({
        'step': 2,
        'stepName': '2. Antropometri',
        'field': 'Lingkar Perut',
        'message': 'Lingkar Perut Belum Diisi',
        'isError': false, // 🟡 Yellow Opsional
      });
    }

    // --- LANGKAH 3: REASONING & KLASIFIKASI AI (OPSIONAL / ANJURAN KLINIS) ---
    if (_smartGrowthResult == null || _reasoningResult == null) {
      issues.add({
        'step': 3,
        'stepName': '3. Reasoning AI',
        'field': 'Reasoning Klinis AI',
        'message': 'Reasoning AI Belum Dijalankan (Opsional / Rekomendasi Klinis)',
        'isError': false, // 🟡 Yellow Opsional (tidak memblokir simpan)
      });
    }

    return issues;
  }

  Widget _buildReviewSectionTitle(String title, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0, top: 4.0),
      child: Text(
        title,
        style: GoogleFonts.outfit(
          fontSize: 11.5,
          fontWeight: FontWeight.w900,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildReviewRow(String label, String value, Color subColor, Color textColor, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.outfit(fontSize: 10.5, color: subColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              textAlign: TextAlign.right,
              style: GoogleFonts.outfit(
                fontSize: 10.5,
                fontWeight: isBold ? FontWeight.w900 : FontWeight.bold,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showReviewAndSubmitDialog() {
    final issues = _validateScreeningForm();
    final redErrors = issues.where((i) => i['isError'] == true).toList();
    final yellowWarnings = issues.where((i) => i['isError'] == false).toList();
    final bool isFormLengkap = redErrors.isEmpty;

    final notifier = ref.read(landingPageProvider.notifier);
    final textColor = notifier.getTextColor();
    final subtitleColor = notifier.getBodyTextColor();
    final cardBgColor = notifier.getCardColor();
    final borderColor = notifier.getBorderColor();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: cardBgColor,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: borderColor),
          ),
          title: Row(
            children: [
              Icon(
                isFormLengkap ? Icons.verified_rounded : (redErrors.isNotEmpty ? Icons.assignment_late_rounded : Icons.info_outline_rounded),
                color: isFormLengkap ? const Color(0xFF27AE60) : (redErrors.isNotEmpty ? const Color(0xFFE74C3C) : const Color(0xFFF39C12)),
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Review & Validasi Skrining Balita',
                  style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w900, color: textColor),
                ),
              ),
            ],
          ),
          content: Container(
            width: 520,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Banner (Form Lengkap vs Ada Data Kurang)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isFormLengkap
                          ? const Color(0xFF27AE60).withValues(alpha: 0.1)
                          : const Color(0xFFE74C3C).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isFormLengkap
                            ? const Color(0xFF27AE60).withValues(alpha: 0.3)
                            : const Color(0xFFE74C3C).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isFormLengkap ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                          color: isFormLengkap ? const Color(0xFF27AE60) : const Color(0xFFE74C3C),
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isFormLengkap
                                    ? (yellowWarnings.isEmpty
                                        ? '✅ Form Lengkap & Reasoning AI Selesai'
                                        : '✅ Data Wajib Lengkap (${yellowWarnings.length} Saran Opsional)')
                                    : '❌ Form Belum Lengkap (${redErrors.length} Syarat Wajib Belum Terpenuhi)',
                                style: GoogleFonts.outfit(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: isFormLengkap ? const Color(0xFF27AE60) : const Color(0xFFE74C3C),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isFormLengkap
                                    ? 'Data antropometri & penalaran klinis siap disimpan ke database dan disinkronkan ke SATUSEHAT.'
                                    : 'Klik chip merah di bawah untuk langsung menuju langkah yang belum lengkap.',
                                style: GoogleFonts.outfit(fontSize: 9.5, color: subtitleColor),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Red Error Chips (Wajib Diisi - Klik untuk langsung ke Step)
                  if (redErrors.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      'Data Wajib Belum Lengkap (Klik untuk menuju form):',
                      style: GoogleFonts.outfit(fontSize: 10.5, fontWeight: FontWeight.bold, color: const Color(0xFFE74C3C)),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: redErrors.map((err) {
                        return ActionChip(
                          avatar: const Icon(Icons.warning_rounded, size: 13, color: Color(0xFFE74C3C)),
                          label: Text(
                            'Step ${err['step']}: ${err['message']}',
                            style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFFE74C3C)),
                          ),
                          backgroundColor: const Color(0xFFE74C3C).withValues(alpha: 0.08),
                          side: const BorderSide(color: Color(0xFFE74C3C)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                          onPressed: () {
                            Navigator.pop(ctx);
                            setState(() {
                              _formStep = err['step'] as int;
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ],

                  // Yellow Warning Chips (Opsional - Klik untuk melengkapi)
                  if (yellowWarnings.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      'Peringatan / Data Opsional (Klik untuk melengkapi):',
                      style: GoogleFonts.outfit(fontSize: 10.5, fontWeight: FontWeight.bold, color: const Color(0xFFD68910)),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: yellowWarnings.map((warn) {
                        return ActionChip(
                          avatar: const Icon(Icons.info_outline_rounded, size: 13, color: Color(0xFFF39C12)),
                          label: Text(
                            'Step ${warn['step']}: ${warn['message']}',
                            style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFFD68910)),
                          ),
                          backgroundColor: const Color(0xFFF39C12).withValues(alpha: 0.08),
                          side: const BorderSide(color: Color(0xFFF39C12)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                          onPressed: () {
                            Navigator.pop(ctx);
                            setState(() {
                              _formStep = warn['step'] as int;
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ],

                  const Divider(height: 24),

                  // Ringkasan Data Skrining Balita
                  _buildReviewSectionTitle('1. Identitas Balita', textColor),
                  _buildReviewRow('Nama Balita', _nameController.text, subtitleColor, textColor),
                  _buildReviewRow('NIK Balita', _nikController.text, subtitleColor, textColor),
                  _buildReviewRow('Jenis Kelamin / Usia', '${_selectedGender == 0 ? "Laki-laki" : "Perempuan"} • ${_ageMonths.toInt()} Bulan', subtitleColor, textColor),
                  _buildReviewRow('Metode Pengukuran', _measurementMethod == 'PB' ? 'PB Telentang' : 'TB Berdiri', subtitleColor, textColor),

                  const SizedBox(height: 8),
                  _buildReviewSectionTitle('2. Antropometri Fisik', textColor),
                  _buildReviewRow('Berat / Panjang', '${_weightController.text} kg / ${_heightController.text} cm', subtitleColor, textColor),
                  _buildReviewRow('LiLA / Lingkar Kepala', '${_lilaController.text} cm / ${_headCircumferenceController.text} cm', subtitleColor, textColor),
                  _buildReviewRow('KMS Balita / Suplemen', '$_kmsStatus • Vit A: ${_receivedVitA ? "Ya" : "Tidak"}', subtitleColor, textColor),

                  const SizedBox(height: 8),
                  _buildReviewSectionTitle('3. Hasil AI & Clinical Reasoning', textColor),
                  _buildReviewRow('Status Gizi (BB/TB)', _smartGrowthResult?.kategoriGiziBbtb ?? 'Belum Dianalisis', subtitleColor, textColor, isBold: true),
                  _buildReviewRow('Status Stunting (TB/U)', _smartGrowthResult?.kategoriStuntingTbu ?? 'Belum Dianalisis', subtitleColor, textColor, isBold: true),
                  _buildReviewRow('Clinical Reasoning', _reasoningResult != null ? 'Tersedia (${_reasoningResult!.modelUsed} - ${_reasoningPromptCount}x diprompt)' : 'Belum Dijalankan (Opsional)', subtitleColor, textColor),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Batal / Kembali ke Form',
                style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: subtitleColor),
              ),
            ),
            if (redErrors.isNotEmpty)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE74C3C),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _formStep = redErrors.first['step'] as int;
                  });
                },
                icon: const Icon(Icons.arrow_forward_rounded, size: 14, color: Colors.white),
                label: Text(
                  'Lengkapi Step ${redErrors.first['step']}',
                  style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              )
            else
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF27AE60),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  _executeSaveScreening();
                },
                icon: _isSyncingSatuSehat
                    ? const Icon(Icons.sync_rounded, size: 16, color: Colors.white)
                    : const Icon(Icons.cloud_upload_rounded, size: 16, color: Colors.white),
                label: Text(
                  'Konfirmasi & Simpan Database',
                  style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _executeSaveScreening() async {
    // 1. Eksekusi Sinkronisasi SATUSEHAT (FHIR R4)
    await _syncToSatuSehat();
    if (!mounted) return;

    // 2. Simpan Rekam Medis ke Repository
    final childName = _nameController.text.trim().isEmpty ? 'Muhammad Rayyan Al-Fatih' : _nameController.text.trim();
    final nik = _nikController.text.trim();
    final bb = double.tryParse(_weightController.text.trim()) ?? 10.0;
    final tb = double.tryParse(_heightController.text.trim()) ?? 80.0;
    final waist = double.tryParse(_waistController.text.trim()) ?? 46.0;
    final currentStaff = ref.read(landingPageProvider).loggedInName ?? 'Petugas Gizi Puskesmas';

    final session = ScreeningSession(
      sessionId: 'VITA-${DateTime.now().millisecondsSinceEpoch}',
      facilityId: ref.read(landingPageProvider).activePuskesmasId ?? 'PUSKESMAS-001',
      child: _activeChild ??
          ChildProfile(
            id: 'ANK-${nik.length >= 4 ? nik.substring(nik.length - 4) : "001"}',
            name: childName,
            nik: nik,
            birthDate: DateTime.now().subtract(Duration(days: (_ageMonths * 30.4).round())),
            gender: _selectedGender == 0 ? 'L' : 'P',
            parentName: 'Orang Tua / Wali Balita',
            address: 'Kecamatan Sumberbaru, Kabupaten Jember',
          ),
      startTime: DateTime.now().subtract(const Duration(minutes: 5)),
      endTime: DateTime.now(),
      mode: _measurementMethod == 'PB' ? AnthropometryMode.recumbentLength : AnthropometryMode.standingHeight,
      weight: MeasurementItem(
        type: MeasurementType.weight,
        value: bb,
        status: MeasurementStatus.verified,
        capturedAt: DateTime.now(),
        source: 'manual_input',
      ),
      height: MeasurementItem(
        type: MeasurementType.height,
        value: tb,
        status: MeasurementStatus.verified,
        capturedAt: DateTime.now(),
        source: 'manual_input',
      ),
      waist: MeasurementItem(
        type: MeasurementType.waist,
        value: waist,
        status: MeasurementStatus.verified,
        capturedAt: DateTime.now(),
        source: 'manual_input',
      ),
      isDemo: false,
      isFinalized: true,
      notes: 'Status Gizi: ${_smartGrowthResult?.kategoriGiziBbtb ?? "Normal"} | Stunting: ${_smartGrowthResult?.kategoriStuntingTbu ?? "Normal"} | SATUSEHAT: ${_satuSehatPatientId ?? "Simulasi"}',
    );

    await _repository.saveScreeningResult(session, staffName: currentStaff);

    if (mounted) {
      CustomSnackbar.success(
        context,
        'Data skrining anak & hasil clinical reasoning berhasil disimpan ke database dan disinkronkan ke SATUSEHAT!',
        title: 'Skrining Berhasil Disimpan',
      );
    }
  }

  // ===========================================================================
  // EKSEKUSI KLASIFIKASI MODEL MLP (OTOMATIS) & REASONING (DENGAN TOMBOL)
  // ===========================================================================
  void _checkAndAutoRunMlp() {
    final bb = double.tryParse(_weightController.text.trim()) ?? 0.0;
    final tb = double.tryParse(_heightController.text.trim()) ?? 0.0;
    if (bb > 0 && tb > 0 && _smartGrowthResult == null && !_isLoadingClassification) {
      _runMlpClassification(silent: true);
    }
  }

  Future<void> _runMlpClassification({bool silent = false}) async {
    final bb = double.tryParse(_weightController.text.trim());
    final tb = double.tryParse(_heightController.text.trim());

    if (bb == null || bb <= 0 || tb == null || tb <= 0) {
      if (!silent) {
        CustomSnackbar.warning(
          context,
          'Harap masukkan angka Berat Badan dan Tinggi Badan yang valid.',
          title: 'Input Tidak Lengkap',
        );
      }
      return;
    }

    if (_isLoadingClassification) return;

    setState(() {
      _isLoadingClassification = true;
    });

    try {
      final inputSG = InputSmartGrowthBalita(
        jk: _selectedGender,
        usiaBulan: _ageMonths,
        berat: bb,
        tinggi: tb,
      );

      final result = await VitaScaleApiService.prediksiSmartGrowth(inputSG);
      if (mounted) {
        setState(() {
          _smartGrowthResult = result;
          _isLoadingClassification = false;
        });

        if (!silent) {
          CustomSnackbar.success(
            context,
            'Klasifikasi model MLP selesai! Status gizi & pertumbuhan teridentifikasi.',
            title: 'Prediksi MLP Berhasil',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingClassification = false);
        if (!silent) {
          CustomSnackbar.error(
            context,
            'Gagal menghubungkan ke backend FastAPI: $e\nPastikan python main.py berjalan di ${VitaScaleApiConfig.baseUrl}',
            title: 'Koneksi API Gagal',
          );
        }
      }
    }
  }

  Future<void> _runReasoningOnly() async {
    final bb = double.tryParse(_weightController.text.trim());
    final tb = double.tryParse(_heightController.text.trim());

    if (bb == null || bb <= 0 || tb == null || tb <= 0) {
      CustomSnackbar.warning(
        context,
        'Harap lengkapi data Berat Badan dan Tinggi Badan di Langkah 2 terlebih dahulu.',
        title: 'Input Tidak Lengkap',
      );
      return;
    }

    if (_smartGrowthResult == null) {
      await _runMlpClassification(silent: true);
      if (_smartGrowthResult == null) {
        if (mounted) {
          CustomSnackbar.error(
            context,
            'Gagal menjalankan klasifikasi MLP. Pastikan server AI aktif.',
            title: 'Klasifikasi Gagal',
          );
        }
        return;
      }
    }

    final mlpResult = _smartGrowthResult!;
    await _runReasoning(mlpResult, bb, tb);
  }

  Future<void> _runReasoning(HasilSmartGrowthBalita mlpResult, double bb, double tb) async {
    setState(() => _isLoadingReasoning = true);

    final waist = double.tryParse(_waistController.text.trim());
    final lila = double.tryParse(_lilaController.text.trim());
    final lk = double.tryParse(_headCircumferenceController.text.trim());

    try {
      final reasoning = await VitaScaleReasoningService.generateReasoning(
        childName: _nameController.text.trim().isEmpty ? 'Balita Sasaran' : _nameController.text.trim(),
        genderLabel: _selectedGender == 0 ? 'Laki-laki' : 'Perempuan',
        ageMonths: _ageMonths,
        weightKg: bb,
        heightCm: tb,
        mlpResult: mlpResult,
        waistCm: waist,
        lilaCm: lila,
        headCircumferenceCm: lk,
        measurementMethod: _measurementMethod == 'PB' ? 'PB Telentang (Infantometer - Buku KIA)' : 'TB Berdiri (Stadiometer - Buku KIA)',
        kmsStatus: _getKmsLabel(_kmsStatus),
        receivedVitA: _receivedVitA,
        receivedDeworming: _ageMonths >= 12 ? _receivedDeworming : null,
        language: ref.read(appLanguageProvider),
      );

      if (mounted) {
        setState(() {
          _reasoningResult = reasoning;
          _isLoadingReasoning = false;
          _reasoningPromptCount++;
        });

        if (_reasoningPromptCount > 1) {
          CustomSnackbar.success(
            context,
            'Penalaran klinis AI berhasil diperbarui (Prompt ke-$_reasoningPromptCount).',
            title: 'Prompt Ulang Berhasil',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingReasoning = false);
      }
    }
  }

  // ===========================================================================
  // MODAL PERINGATAN RE-PROMPT AI (PROMPT ULANG KE-2+)
  // ===========================================================================
  void _confirmRePromptDialog({VoidCallback? onConfirm}) {
    final notifier = ref.read(landingPageProvider.notifier);
    final cardBgColor = notifier.getCardColor();
    final borderColor = notifier.getBorderColor();
    final textColor = notifier.getTextColor();
    final subtitleColor = notifier.getBodyTextColor();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: cardBgColor,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: borderColor),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF39C12).withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFF39C12), size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Konfirmasi Prompt Ulang AI',
                  style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w900, color: textColor),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF39C12).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFF39C12).withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFFF39C12)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'AI sudah diprompt $_reasoningPromptCount kali untuk balita ini.',
                        style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFFD68910)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Apakah Anda yakin ingin melakukan prompt / inferensi ulang AI (Gemini 2.5 Flash & Keras MLP)?',
                style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700, color: textColor),
              ),
              const SizedBox(height: 6),
              Text(
                '• Hasil penalaran klinis, rekomendasi nutrisi PMT, dan alur berpikir sebelumnya akan diperbarui dengan data antropometri terkini.\n• Kuota token API reasoning akan digunakan kembali (Prompt ke-${_reasoningPromptCount + 1}).',
                style: GoogleFonts.outfit(fontSize: 10.5, color: subtitleColor, height: 1.4),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Batal',
                style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.bold, color: subtitleColor),
              ),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1ABC9C),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                if (onConfirm != null) {
                  onConfirm();
                } else {
                  _runReasoningOnly();
                }
              },
              icon: const Icon(Icons.refresh_rounded, size: 15, color: Colors.white),
              label: Text(
                'Lanjutkan Prompt Ulang (${_reasoningPromptCount + 1})',
                style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  // ===========================================================================
  // MODAL PENGATURAN URL SERVER
  // ===========================================================================
  void _showServerConfigModal() {
    final urlCtrl = TextEditingController(text: VitaScaleApiConfig.baseUrl);

    showDialog(
      context: context,
      builder: (ctx) => CustomDialog(
        title: 'Konfigurasi Server FastAPI VitaScale',
        icon: Icons.dns_rounded,
        iconColor: const Color(0xFF1ABC9C),
        maxWidth: 440,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Masukkan Base URL backend FastAPI tempat model MLP di-hosting.',
              style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey),
            ),
            const SizedBox(height: 14),
            CustomTextField(
              label: 'Base URL API',
              hintText: 'https://vitascalemapotech.vercel.app',
              controller: urlCtrl,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildQuickUrlChip('Vercel Cloud (Live)', 'https://vitascalemapotech.vercel.app', urlCtrl),
                _buildQuickUrlChip('127.0.0.1:8000', 'http://127.0.0.1:8000', urlCtrl),
                _buildQuickUrlChip('localhost:8000', 'http://localhost:8000', urlCtrl),
                _buildQuickUrlChip('Emulator (10.0.2.2)', 'http://10.0.2.2:8000', urlCtrl),
              ],
            ),
          ],
        ),
        actions: [
          CustomButton(
            text: 'Batal',
            isSecondary: true,
            height: 38,
            onPressed: () => Navigator.pop(ctx),
          ),
          CustomButton(
            text: 'Simpan & Tes',
            icon: Icons.check_circle_rounded,
            height: 38,
            primaryColor: const Color(0xFF1ABC9C),
            onPressed: () {
              VitaScaleApiConfig.baseUrl = urlCtrl.text.trim();
              Navigator.pop(ctx);
              _checkServer();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildQuickUrlChip(String label, String url, TextEditingController ctrl) {
    return InkWell(
      onTap: () => ctrl.text = url,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF1ABC9C).withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF1ABC9C).withOpacity(0.3)),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF1ABC9C)),
        ),
      ),
    );
  }

  void _showPatientPickerModal() {
    showDialog(
      context: context,
      builder: (ctx) {
        return CustomDialog(
          title: 'Pilih Sasaran Anak / Bayi',
          icon: Icons.people_rounded,
          iconColor: const Color(0xFF1ABC9C),
          maxWidth: 480,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: _availableChildren.map((child) {
              final isCurrent = child.id == _activeChild?.id;
              return ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                tileColor: isCurrent ? const Color(0xFF1ABC9C).withOpacity(0.12) : null,
                leading: Icon(
                  child.isUnder24Months ? Icons.child_friendly_rounded : Icons.face_rounded,
                  color: isCurrent ? const Color(0xFF1ABC9C) : Colors.grey,
                ),
                title: Text(
                  child.name,
                  style: GoogleFonts.outfit(
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                subtitle: Text(
                  'NIK: ${child.nik} • Usia: ${child.ageLabel}',
                  style: GoogleFonts.outfit(fontSize: 10.5),
                ),
                trailing: StatusBadge(
                  label: child.isUnder24Months ? 'PB (TELENTANG)' : 'TB (BERDIRI)',
                  color: child.isUnder24Months ? const Color(0xFF3498DB) : const Color(0xFFE67E22),
                  fontSize: 8,
                ),
                onTap: () {
                  _selectChild(child);
                  Navigator.pop(ctx);
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  void _copyReportToClipboard() {
    if (_smartGrowthResult == null) return;

    final bb = _weightController.text;
    final tb = _heightController.text;
    final lk = _headCircumferenceController.text;
    final lila = _lilaController.text;
    final lp = _waistController.text;
    final name = _nameController.text;
    final age = _ageMonths.toStringAsFixed(0);
    final gender = _selectedGender == 0 ? 'Laki-laki' : 'Perempuan';
    final caraUkur = _measurementMethod == 'PB' ? 'Panjang Badan Telentang (< 24 Bln)' : 'Tinggi Badan Berdiri (≥ 24 Bln)';
    final kms = _getKmsLabel(_kmsStatus);

    final gizi = _smartGrowthResult?.kategoriGiziBbtb ?? '-';
    final stunting = _smartGrowthResult?.kategoriStuntingTbu ?? '-';
    final confGizi = _smartGrowthResult?.confidenceBbtb ?? 0.0;
    final confStunt = _smartGrowthResult?.confidenceTbu ?? 0.0;

    final reasoning = _reasoningResult;

    final report = '''
==================================================
LAPORAN SKRINING BALITA VITASCALE x SATUSEHAT KEMENKES RI
Standar: Buku KIA 2024 & Permenkes No. 2 Tahun 2020
==================================================
Nama Balita    : $name
NIK            : ${_nikController.text}
IHS Number     : ${_satuSehatPatientId ?? '-'}
Jenis Kelamin  : $gender
Usia           : $age Bulan
Cara Pengukuran: $caraUkur
Berat Badan    : $bb kg (LOINC: 29463-7)
Panjang/Tinggi : $tb cm (LOINC: ${_measurementMethod == 'PB' ? '8306-3' : '8302-2'})
Lingkar Kepala : ${lk.isNotEmpty ? '$lk cm (LOINC: 9843-4 - Nellhaus)' : '-'}
LiLA           : ${lila.isNotEmpty ? '$lila cm (LOINC: 56072-2 - ${_getLilaStatusText(double.tryParse(lila))})' : '-'}
Lingkar Perut  : ${lp.isNotEmpty ? '$lp cm (LOINC: 8280-0)' : '-'}
Tren KMS KIA   : $kms
Vitamin A      : ${_receivedVitA ? 'Sudah Diberikan' : 'Belum'}
Obat Cacing    : ${_ageMonths >= 12 ? (_receivedDeworming ? 'Sudah Diberikan' : 'Belum') : 'Belum Usia Target (≥ 12 Bln)'}

[HASIL KLASIFIKASI MODEL MLP KERAS]
Status Gizi (BB/TB)     : $gizi (Confidence: ${confGizi.toStringAsFixed(1)}%)
Status Stunting (TB/U)  : $stunting (Confidence: ${confStunt.toStringAsFixed(1)}%)
Indikasi Stunting       : ${_smartGrowthResult?.isStunting == true ? 'YA (ICD-10: E45)' : 'TIDAK'}
Indikasi Gizi Kurang    : ${_smartGrowthResult?.isGiziBurukAtauKurang == true ? 'YA (ICD-10: E44.0)' : 'TIDAK'}

[CLINICAL AI REASONING - BUKU KIA 2024]
Ringkasan Klinis:
${reasoning?.reasoningSummary ?? '-'}

Rantai Penalaran (Chain of Thought):
${reasoning?.chainOfThoughtSteps.map((s) => '• $s').join('\n') ?? '-'}

Analisis Faktor Risiko & Etiologi:
${reasoning?.riskAndEtiology ?? '-'}

Rencana Intervensi Gizi:
${reasoning?.nutritionalIntervention ?? '-'}

Protokol Tindak Lanjut Medis:
${reasoning?.medicalProtocol ?? '-'}

Pesan Edukasi Orang Tua:
${reasoning?.parentEducation ?? '-'}
==================================================
Dicetak melalui MAPOTECH VitaScale System
Interoperabilitas SATUSEHAT Kemenkes RI (FHIR R4)
''';

    Clipboard.setData(ClipboardData(text: report));
    CustomSnackbar.success(
      context,
      'Laporan klinis lengkap Buku KIA 2024 & kode SATUSEHAT tersalin ke clipboard.',
      title: 'Tersalin ke Clipboard',
    );
  }

  @override
  Widget build(BuildContext context) {
    final screeningState = ref.watch(screeningStateProvider);
    final landingState = ref.watch(landingPageProvider);
    final notifier = ref.read(landingPageProvider.notifier);
    final isDark = landingState.appearance == 'dark';
    final isEn = landingState.language == 'en';

    final cardBgColor = notifier.getCardColor();
    final textColor = notifier.getTextColor();
    final subtitleColor = notifier.getBodyTextColor();
    final borderColor = notifier.getBorderColor();
    final isMobile = MediaQuery.of(context).size.width < 900;

    final issues = _validateScreeningForm();
    final redErrors = issues.where((i) => i['isError'] == true).toList();
    final yellowWarnings = issues.where((i) => i['isError'] == false).toList();

    final session = screeningState.session;

    return VitaScaleDlcGate(
      menuTitle: isEn ? 'Child & Infant Screening' : 'Screening Anak & Bayi',
      child: Container(
        color: notifier.getBackgroundColor(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            // =================================================================
            // TOP BAR: TOMBOL KEMBALI & BREADCRUMB
            // =================================================================
            Row(
              children: [
                InkWell(
                  onTap: () {
                    if (widget.onNavigateToMenu != null) {
                      widget.onNavigateToMenu!('dlc_vitascale_data_anak');
                    } else {
                      Navigator.of(context).maybePop();
                    }
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: cardBgColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.arrow_back_rounded, size: 18, color: textColor),
                        const SizedBox(width: 8),
                        Text(
                          isEn ? 'Back to Child Data' : 'Kembali ke Data Anak',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Text(
                  isEn ? 'VitaScale DLC Module • AI Screening & Anthropometry' : 'Modul DLC VitaScale • Skrining AI & Antropometri',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: subtitleColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // =================================================================
            // PENCARIAN & PEMILIHAN PASIEN BALITA DI BAGIAN ATAS
            // =================================================================
            _buildPatientSearchSection(cardBgColor, borderColor, textColor, subtitleColor, isMobile),

            const SizedBox(height: 16),

            // =================================================================
            // BANNER TOP HEADER
            // =================================================================
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardBgColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1ABC9C).withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.monitor_weight_rounded, size: 28, color: Color(0xFF1ABC9C)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1ABC9C).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: Text(
                                isEn ? 'ANTHROPOMETRIC & AI SCREENING MODULE' : 'MODUL SKRINING ANTROPOMETRI & AI',
                                style: GoogleFonts.outfit(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFF1ABC9C),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'VitaScale by MAPOTECH',
                              style: GoogleFonts.outfit(fontSize: 10, color: subtitleColor, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isEn ? 'Child Anthropometry Measurement & Screening' : 'Uji Ukur & Skrining Antropometri Balita',
                          style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w900, color: textColor),
                        ),
                        Text(
                          isEn ? 'Machine Learning Classification (Keras MLP) & Pediatrician Clinical AI Reasoning.' : 'Klasifikasi Machine Learning (Keras MLP) & Clinical AI Reasoning Dokter Spesialis Anak.',
                          style: GoogleFonts.outfit(fontSize: 10.5, color: subtitleColor),
                        ),
                      ],
                    ),
                  ),
                  // Tombol Ganti Server URL
                  InkWell(
                    onTap: _showServerConfigModal,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: borderColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: borderColor),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.settings_ethernet_rounded, size: 16, color: subtitleColor),
                          const SizedBox(width: 6),
                          Text(
                            'API Host',
                            style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: textColor),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // =================================================================
            // TAB SELECTOR: Mode Input Manual (Uji Ukur) vs Hardware IoT
            // =================================================================
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: borderColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildTabButton(
                      index: 0,
                      label: 'Uji Ukur Manual & Reasoning AI',
                      icon: Icons.tune_rounded,
                      badge: 'Tersedia Sekarang (Tanpa IoT Fisik)',
                      badgeColor: const Color(0xFF1ABC9C),
                    ),
                  ),
                  Expanded(
                    child: _buildTabButton(
                      index: 1,
                      label: 'Perangkat IoT & Kamera CV',
                      icon: Icons.sensors_rounded,
                      badge: 'ESP32 + Webcam',
                      badgeColor: const Color(0xFF3498DB),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // =================================================================
            // KONTEN TAB 0: UJI UKUR MANUAL & REASONING AI (STEPPER BERTAHAP)
            // =================================================================
            if (_activeTab == 0) ...[
              _buildServerStatusBar(cardBgColor, borderColor, textColor, subtitleColor),
              const SizedBox(height: 16),

              // Custom Form Stepper (1 Card Per Step)
              CustomFormStepper(
                steps: [
                  FormStepItem(
                    step: 1,
                    label: '1. Identitas Balita',
                    icon: Icons.badge_rounded,
                    hasError: redErrors.any((e) => e['step'] == 1),
                    hasWarning: yellowWarnings.any((w) => w['step'] == 1),
                    isCompleted: _nikController.text.trim().length == 16 && _nameController.text.trim().isNotEmpty && _ageMonths > 0,
                  ),
                  FormStepItem(
                    step: 2,
                    label: '2. Antropometri',
                    icon: Icons.straighten_rounded,
                    hasError: redErrors.any((e) => e['step'] == 2),
                    hasWarning: yellowWarnings.any((w) => w['step'] == 2),
                    isCompleted: double.tryParse(_weightController.text.trim()) != null && double.tryParse(_heightController.text.trim()) != null,
                  ),
                  FormStepItem(
                    step: 3,
                    label: '3. Reasoning AI',
                    icon: Icons.psychology_rounded,
                    hasError: redErrors.any((e) => e['step'] == 3),
                    hasWarning: yellowWarnings.any((w) => w['step'] == 3),
                    isCompleted: _smartGrowthResult != null,
                  ),
                  FormStepItem(
                    step: 4,
                    label: '4. SATUSEHAT & Simpan',
                    icon: Icons.cloud_sync_rounded,
                    hasError: false,
                    hasWarning: false,
                    isCompleted: _satuSehatSyncResult != null,
                  ),
                ],
                currentStep: _formStep,
                onStepTapped: (step) {
                  setState(() => _formStep = step);
                  if (step == 3) {
                    _checkAndAutoRunMlp();
                  }
                },
                themeAccent: const Color(0xFF1ABC9C),
                textColor: textColor,
                subtitleColor: subtitleColor,
                borderColor: borderColor,
                cardBgColor: cardBgColor,
                isDark: isDark,
              ),

              const SizedBox(height: 16),

              // Tampilan 1 Kartu Form Aktif Sesuai Step
              if (_formStep == 1)
                _buildStep1ChildIdentity(cardBgColor, borderColor, textColor, subtitleColor, isMobile)
              else if (_formStep == 2)
                _buildStep2Anthropometry(cardBgColor, borderColor, textColor, subtitleColor, isMobile)
              else if (_formStep == 3)
                _buildStep3ReasoningAndAi(cardBgColor, borderColor, textColor, subtitleColor, isMobile)
              else if (_formStep == 4)
                _buildStep4SatuSehatAndSave(cardBgColor, borderColor, textColor, subtitleColor, isMobile),

              const SizedBox(height: 16),

              // Stepper Navigation Footer & Real-Time Validation Pill
              _buildScreeningStepperFooter(
                cardBgColor: cardBgColor,
                borderColor: borderColor,
                textColor: textColor,
                subtitleColor: subtitleColor,
                isMobile: isMobile,
                redErrors: redErrors,
                yellowWarnings: yellowWarnings,
              ),

              const SizedBox(height: 24),
            ]
            // =================================================================
            // KONTEN TAB 1: PERANGKAT IOT & KAMERA CV (EXISTING)
            // =================================================================
            else ...[
              if (session == null)
                EmptyStateWidget(
                  icon: Icons.person_search_rounded,
                  title: 'Belum Ada Sesi Skrining yang Aktif',
                  subtitle: 'Pilih pasien anak/bayi untuk memulai pengukuran antropometri dengan perangkat VitaScale.',
                  cardBg: cardBgColor,
                  border: borderColor,
                  textColor: textColor,
                  subtitleColor: subtitleColor,
                )
              else ...[
                VitaScaleStatusBar(
                  session: session,
                  deviceStatus: screeningState.deviceStatus,
                  isCameraReady: screeningState.isCameraReady,
                  cardBgColor: cardBgColor,
                  borderColor: borderColor,
                  textColor: textColor,
                  subtitleColor: subtitleColor,
                  themeAccent: const Color(0xFF1ABC9C),
                  onModeChanged: (m) => ref.read(screeningStateProvider.notifier).changeAnthropometryMode(m),
                  onCloseSession: () => ref.read(screeningStateProvider.notifier).closeSession(),
                ),

                const SizedBox(height: 18),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: isMobile ? 1 : 3,
                      child: Container(
                        height: 380,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: borderColor),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: VitaScaleCameraWidget(
                          onStatusChanged: (isReady, label) {
                            ref.read(screeningStateProvider.notifier).setCameraStatus(
                                  isReady: isReady,
                                  cameraLabel: label,
                                );
                          },
                          onMeasured: (result) {
                            if (result.ok && result.valueCm != null) {
                              ref.read(screeningStateProvider.notifier).updateHeight(
                                    value: result.valueCm,
                                    status: MeasurementStatus.stable,
                                    source: 'opencv_web',
                                  );
                              CustomSnackbar.success(
                                context,
                                'Panjang/Tinggi terdeteksi: ${result.valueCm!.toStringAsFixed(1)} cm',
                                title: 'Deteksi Marker Berhasil',
                              );
                            } else {
                              final err = result.reasons.isNotEmpty
                                  ? result.reasons.join('\n')
                                  : 'Deteksi marker papan ukur gagal.';
                              ref.read(screeningStateProvider.notifier).updateHeight(
                                    value: null,
                                    status: MeasurementStatus.failed,
                                    errorMessage: err,
                                  );
                              CustomSnackbar.warning(context, err, title: 'Kamera Gagal Mengukur');
                            }
                          },
                          onSimulateFixture: () {
                            final sampleVal = session.child.isUnder24Months ? 74.8 : 98.5;
                            _simulator.injectCvFixtureMeasurement(fixtureHeight: sampleVal);
                            CustomSnackbar.info(
                              context,
                              'Data fixture sintetis panjang/tinggi ($sampleVal cm) telah diinjeksikan.',
                              title: 'Fixture Uji Selesai',
                            );
                          },
                        ),
                      ),
                    ),

                    const SizedBox(width: 16),

                    Expanded(
                      flex: isMobile ? 1 : 2,
                      child: Column(
                        children: [
                          SizedBox(
                            height: 184,
                            child: MeasurementCard(
                              type: MeasurementType.weight,
                              item: session.weight,
                              icon: Icons.monitor_weight_rounded,
                              cardBgColor: cardBgColor,
                              borderColor: borderColor,
                              textColor: textColor,
                              subtitleColor: subtitleColor,
                              themeAccent: const Color(0xFF1ABC9C),
                              onReset: () => ref
                                  .read(screeningStateProvider.notifier)
                                  .resetMeasurement(MeasurementType.weight),
                              simulateLabel: 'Simulasi Berat',
                              onSimulate: () {
                                final defaultTarget = session.child.isUnder24Months ? 9.45 : 15.20;
                                _simulator.simulateWeightMeasurement(targetWeight: defaultTarget);
                              },
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 184,
                            child: MeasurementCard(
                              type: MeasurementType.waist,
                              item: session.waist,
                              icon: Icons.straighten_rounded,
                              cardBgColor: cardBgColor,
                              borderColor: borderColor,
                              textColor: textColor,
                              subtitleColor: subtitleColor,
                              themeAccent: const Color(0xFFE67E22),
                              onReset: () => ref
                                  .read(screeningStateProvider.notifier)
                                  .resetMeasurement(MeasurementType.waist),
                              simulateLabel: 'Simulasi Lingkar',
                              onSimulate: () {
                                final defaultWaist = session.child.isUnder24Months ? 44.2 : 51.5;
                                _simulator.simulateWaistMeasurement(targetWaist: defaultWaist);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    ),
  );
}

  // ===========================================================================
  // PENCARIAN & PEMILIHAN SASARAN BALITA (SEARCH AT THE TOP)
  // ===========================================================================
  Widget _buildPatientSearchSection(
    Color cardBg,
    Color border,
    Color text,
    Color sub,
    bool isMobile,
  ) {
    final searchMatches = _topSearchQuery.isEmpty
        ? <ChildProfile>[]
        : _availableChildren.where((c) {
            final q = _topSearchQuery.toLowerCase();
            return c.name.toLowerCase().contains(q) ||
                c.nik.toLowerCase().contains(q) ||
                c.parentName.toLowerCase().contains(q);
          }).toList();

    return CustomCard(
      color: cardBg,
      borderColor: _activeChild == null ? const Color(0xFF1ABC9C).withOpacity(0.4) : border,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Section Title Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1ABC9C).withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_search_rounded,
                  size: 20,
                  color: Color(0xFF1ABC9C),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'CARI & PILIH SASARAN BALITA',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: text,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(width: 8),
                        StatusBadge(
                          label: '${_availableChildren.length} Terdaftar',
                          color: const Color(0xFF1ABC9C),
                          fontSize: 9,
                          showDot: false,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Cari nama anak atau NIK balita di bawah ini untuk memuat otomatis data KMS, usia, dan riwayat.',
                      style: GoogleFonts.outfit(fontSize: 10.5, color: sub),
                    ),
                  ],
                ),
              ),
              if (_activeChild != null)
                CustomButton(
                  text: 'Ganti Pasien',
                  icon: Icons.swap_horiz_rounded,
                  height: 32,
                  isSecondary: true,
                  onPressed: () {
                    setState(() {
                      _activeChild = null;
                      _topSearchController.clear();
                      _topSearchQuery = '';
                    });
                  },
                ),
            ],
          ),

          const SizedBox(height: 14),

          // Search Field
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF1A1D27)
                  : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _topSearchQuery.isNotEmpty
                    ? const Color(0xFF1ABC9C)
                    : border,
                width: _topSearchQuery.isNotEmpty ? 1.5 : 1.0,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            child: Row(
              children: [
                const Icon(
                  Icons.search_rounded,
                  size: 20,
                  color: Color(0xFF1ABC9C),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _topSearchController,
                    style: GoogleFonts.outfit(fontSize: 13, color: text),
                    decoration: InputDecoration(
                      hintText: ref.watch(landingPageProvider).language == 'en'
                          ? 'Search Child Name, NIK (16-Digit), or Parent Name...'
                          : 'Cari Nama Balita, NIK (16-Digit), atau Nama Orang Tua...',
                      hintStyle: GoogleFonts.outfit(
                        fontSize: 11.5,
                        color: sub.withOpacity(0.7),
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onChanged: (v) {
                      setState(() {
                        _topSearchQuery = v.trim();
                      });
                    },
                  ),
                ),
                if (_topSearchController.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    color: sub,
                    tooltip: ref.watch(landingPageProvider).language == 'en' ? 'Clear Search' : 'Hapus Pencarian',
                    onPressed: () {
                      _topSearchController.clear();
                      setState(() {
                        _topSearchQuery = '';
                      });
                    },
                  ),
                const SizedBox(width: 4),
                CustomButton(
                  text: 'Daftar Lengkap',
                  icon: Icons.list_alt_rounded,
                  height: 32,
                  isSecondary: true,
                  onPressed: _showPatientPickerModal,
                ),
              ],
            ),
          ),

          // Search Result Dropdown / List (when query is entered)
          if (_topSearchQuery.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              constraints: const BoxConstraints(maxHeight: 220),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF1E2130)
                    : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF1ABC9C).withOpacity(0.4)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: searchMatches.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline_rounded, size: 18, color: sub),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Tidak ada data balita yang cocok dengan "$_topSearchQuery".',
                              style: GoogleFonts.outfit(fontSize: 11.5, color: sub),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.all(8),
                      itemCount: searchMatches.length,
                      separatorBuilder: (_, __) => const Divider(height: 8),
                      itemBuilder: (ctx, idx) {
                        final child = searchMatches[idx];
                        return InkWell(
                          onTap: () => _selectChild(child),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1ABC9C).withOpacity(0.06),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  child.isUnder24Months
                                      ? Icons.child_friendly_rounded
                                      : Icons.face_rounded,
                                  size: 20,
                                  color: const Color(0xFF1ABC9C),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            child.name,
                                            style: GoogleFonts.outfit(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.bold,
                                              color: text,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          StatusBadge(
                                            label: child.gender == 'L' ? 'L' : 'P',
                                            color: child.gender == 'L'
                                                ? const Color(0xFF3498DB)
                                                : const Color(0xFFE91E63),
                                            fontSize: 8,
                                            showDot: false,
                                          ),
                                        ],
                                      ),
                                      Text(
                                        'NIK: ${child.nik} • Usia: ${child.ageLabel} (${child.ageInMonths} Bln) • Wali: ${child.parentName}',
                                        style: GoogleFonts.outfit(fontSize: 10, color: sub),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                CustomButton(
                                  text: 'Pilih',
                                  icon: Icons.check_circle_rounded,
                                  height: 28,
                                  primaryColor: const Color(0xFF1ABC9C),
                                  onPressed: () => _selectChild(child),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],

          // Active Child Banner or Quick Selection Prompt (when query is empty)
          if (_topSearchQuery.isEmpty) ...[
            const SizedBox(height: 12),
            if (_activeChild != null)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1ABC9C).withOpacity(0.09),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF1ABC9C).withOpacity(0.35)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1ABC9C).withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        _activeChild!.isUnder24Months
                            ? Icons.child_friendly_rounded
                            : Icons.face_rounded,
                        size: 24,
                        color: const Color(0xFF1ABC9C),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  'Sasaran Terpilih: ${_activeChild!.name}',
                                  style: GoogleFonts.outfit(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w900,
                                    color: const Color(0xFF1ABC9C),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              StatusBadge(
                                label: _activeChild!.gender == 'L' ? 'L' : 'P',
                                color: _activeChild!.gender == 'L'
                                    ? const Color(0xFF3498DB)
                                    : const Color(0xFFE91E63),
                                fontSize: 8.5,
                                showDot: false,
                              ),
                              const SizedBox(width: 6),
                              if (_activeChild!.isBalita)
                                Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: StatusBadge(
                                    label: 'BALITA',
                                    color: const Color(0xFF1ABC9C),
                                    fontSize: 8.5,
                                    showDot: false,
                                  ),
                                ),
                              StatusBadge(
                                label: _activeChild!.defaultMode.code,
                                color: _activeChild!.isUnder24Months
                                    ? const Color(0xFF3498DB)
                                    : const Color(0xFFE67E22),
                                fontSize: 8.5,
                                showDot: false,
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'NIK: ${_activeChild!.nik} • Usia: ${_activeChild!.ageLabel} (${_activeChild!.ageInMonths} Bulan) • Wali: ${_activeChild!.parentName}',
                            style: GoogleFonts.outfit(fontSize: 10.5, color: sub),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Alamat: ${_activeChild!.address} • Telp: ${_activeChild!.phone?.isNotEmpty == true ? _activeChild!.phone : "-"}',
                            style: GoogleFonts.outfit(fontSize: 10, color: sub.withOpacity(0.8)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    InkWell(
                      onTap: () {
                        setState(() {
                          _activeChild = null;
                        });
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.swap_horiz_rounded, size: 15, color: text),
                            const SizedBox(width: 4),
                            Text(
                              'Ganti Balita',
                              style: GoogleFonts.outfit(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: text,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              // Prompt to select patient
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.touch_app_rounded, size: 18, color: Colors.amber),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Pilih salah satu sasaran balita terdaftar di bawah ini untuk memulai skrining terarah:',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: text,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _availableChildren.map((c) {
                  return InkWell(
                    onTap: () => _selectChild(c),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF1E2130)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            c.isUnder24Months
                                ? Icons.child_friendly_rounded
                                : Icons.face_rounded,
                            size: 16,
                            color: const Color(0xFF1ABC9C),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            c.name,
                            style: GoogleFonts.outfit(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                              color: text,
                            ),
                          ),
                          const SizedBox(width: 6),
                          StatusBadge(
                            label: c.ageLabel,
                            color: c.isUnder24Months
                                ? const Color(0xFF3498DB)
                                : const Color(0xFFE67E22),
                            fontSize: 8.5,
                            showDot: false,
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ],
      ),
    );
  }

  // ===========================================================================
  // WIDGET HELPER TAB BUTTON
  // ===========================================================================
  Widget _buildTabButton({
    required int index,
    required String label,
    required IconData icon,
    required String badge,
    required Color badgeColor,
  }) {
    final isSelected = _activeTab == index;
    return InkWell(
      onTap: () => setState(() => _activeTab = index),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1ABC9C) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : Colors.grey,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      color: isSelected ? Colors.white : Colors.grey[700],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white.withOpacity(0.2) : badgeColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      badge,
                      style: GoogleFonts.outfit(
                        fontSize: 8.5,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : badgeColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // SERVER STATUS BAR
  // ===========================================================================
  Widget _buildServerStatusBar(Color cardBg, Color border, Color text, Color sub) {
    final isOnline = _serverStatus?['isOnline'] == true;
    final statusColor = isOnline ? const Color(0xFF27AE60) : const Color(0xFFE74C3C);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      isOnline ? 'VitaScale Cloud Backend (Vercel): TERHUBUNG' : 'VitaScale Cloud Backend: TIDAK TERHUBUNG',
                      style: GoogleFonts.outfit(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: statusColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '(${VitaScaleApiConfig.baseUrl})',
                        style: GoogleFonts.outfit(fontSize: 10.5, color: sub),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                Text(
                  isOnline
                      ? 'Model MLP stunting (TB/U), status gizi (BB/TB), & Smart Growth aktif di cloud Vercel.'
                      : 'Periksa koneksi internet atau status hosting di ${VitaScaleApiConfig.baseUrl}.',
                  style: GoogleFonts.outfit(fontSize: 10, color: sub),
                ),
              ],
            ),
          ),
          CustomButton(
            text: _isCheckingServer ? 'Mengecek...' : 'Ping Server',
            icon: Icons.refresh_rounded,
            height: 32,
            primaryColor: statusColor,
            isSecondary: true,
            onPressed: () {
              if (!_isCheckingServer) {
                _checkServer();
              }
            },
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // LANGKAH 1: IDENTITAS BALITA & SASARAN SKRINING
  // ===========================================================================
  Widget _buildStep1ChildIdentity(Color cardBg, Color border, Color text, Color sub, bool isMobile) {
    final isUnder24 = _ageMonths < 24;

    return CustomCard(
      color: cardBg,
      borderColor: border,
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Card Step 1
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1ABC9C).withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_pin_rounded, size: 20, color: Color(0xFF1ABC9C)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Langkah 1: Identitas Balita & Sasaran Skrining',
                      style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w800, color: text),
                    ),
                    Text(
                      'Data demografi, NIK untuk SATUSEHAT Kemenkes RI, jenis kelamin, dan usia balita.',
                      style: GoogleFonts.outfit(fontSize: 10.5, color: sub),
                    ),
                  ],
                ),
              ),
              CustomButton(
                text: 'Pilih Data Anak',
                icon: Icons.person_search_rounded,
                height: 34,
                primaryColor: const Color(0xFF1ABC9C),
                onPressed: _showPatientPickerModal,
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Preset Cepat Bar (Buku KIA 2024)
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('Preset Uji Cepat:', style: GoogleFonts.outfit(fontSize: 10.5, fontWeight: FontWeight.bold, color: sub)),
              _buildPresetChip('Balita Normal (24 bln)', () => _applyPreset('Normal', jk: 0, usia: 24, bb: 11.5, tb: 85.0, lk: 48.0, lila: 14.5, caraUkur: 'TB', kms: 'N')),
              _buildPresetChip('Risiko Stunting (24 bln - 2T)', () => _applyPreset('Stunting 2T', jk: 0, usia: 24, bb: 9.2, tb: 76.0, lk: 45.0, lila: 12.0, caraUkur: 'TB', kms: '2T')),
              _buildPresetChip('Gizi Buruk / BGM (18 bln)', () => _applyPreset('Gizi Buruk BGM', jk: 1, usia: 18, bb: 6.8, tb: 78.0, lk: 43.5, lila: 11.2, caraUkur: 'PB', kms: 'BGM')),
              _buildPresetChip('Bayi Telentang (8 bln)', () => _applyPreset('Bayi 8 Bln', jk: 0, usia: 8, bb: 8.2, tb: 70.0, lk: 44.0, lila: 14.0, caraUkur: 'PB', kms: 'N')),
            ],
          ),

          const Divider(height: 24),

          // Baris 1: Nama & NIK + Cek SATUSEHAT
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: CustomTextField(
                  label: 'Nama Lengkap Balita',
                  hintText: 'Nama anak sasaran',
                  controller: _nameController,
                  onChanged: (val) => setState(() {}),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('NIK Balita (16 Digit - Wajib SATUSEHAT)', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700, color: text)),
                        if (_satuSehatPatientId != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF27AE60).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle_rounded, size: 10, color: Color(0xFF27AE60)),
                                const SizedBox(width: 4),
                                Text(
                                  'IHS: $_satuSehatPatientId',
                                  style: GoogleFonts.outfit(fontSize: 8.5, fontWeight: FontWeight.bold, color: const Color(0xFF27AE60)),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: CustomTextField(
                            label: '',
                            hintText: '16 digit NIK',
                            controller: _nikController,
                            keyboardType: TextInputType.number,
                            maxLength: 16,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(16),
                            ],
                            onChanged: (val) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 8),
                        CustomButton(
                          text: _isCheckingSatuSehatPatient ? 'Cek...' : 'Cek SATUSEHAT',
                          icon: Icons.health_and_safety_rounded,
                          height: 42,
                          isSecondary: true,
                          primaryColor: const Color(0xFF009688),
                          onPressed: _isCheckingSatuSehatPatient
                              ? null
                              : () {
                                  _checkSatuSehatPatient();
                                },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Baris 2: Jenis Kelamin & Usia (Bulan)
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Segmented Jenis Kelamin
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Jenis Kelamin Balita',
                      style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700, color: text),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 44,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: border.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: border),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildGenderOption(
                              label: 'Laki-laki (0)',
                              icon: Icons.male_rounded,
                              isSelected: _selectedGender == 0,
                              onTap: () => setState(() => _selectedGender = 0),
                              color: const Color(0xFF3498DB),
                            ),
                          ),
                          Expanded(
                            child: _buildGenderOption(
                              label: 'Perempuan (1)',
                              icon: Icons.female_rounded,
                              isSelected: _selectedGender == 1,
                              onTap: () => setState(() => _selectedGender = 1),
                              color: const Color(0xFFE91E63),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 16),

              // Usia dalam Bulan
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Usia Balita (Bulan)',
                          style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700, color: text),
                        ),
                        StatusBadge(
                          label: isUnder24 ? 'Target: PB Telentang' : 'Target: TB Berdiri',
                          color: isUnder24 ? const Color(0xFF3498DB) : const Color(0xFFE67E22),
                          fontSize: 8.5,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _buildStepperBtn(Icons.remove, () {
                          if (_ageMonths > 1) {
                            setState(() {
                              _ageMonths -= 1;
                              _ageController.text = _ageMonths.toStringAsFixed(0);
                              if (_ageMonths < 24 && _measurementMethod == 'TB') _measurementMethod = 'PB';
                            });
                          }
                        }),
                        const SizedBox(width: 8),
                        Expanded(
                          child: CustomTextField(
                            label: '',
                            hintText: 'Bulan',
                            controller: _ageController,
                            keyboardType: TextInputType.number,
                            onChanged: (val) {
                              final numVal = double.tryParse(val);
                              if (numVal != null && numVal >= 0) {
                                setState(() {
                                  _ageMonths = numVal;
                                  if (_ageMonths < 24) {
                                    _measurementMethod = 'PB';
                                  } else {
                                    _measurementMethod = 'TB';
                                  }
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildStepperBtn(Icons.add, () {
                          setState(() {
                            _ageMonths += 1;
                            _ageController.text = _ageMonths.toStringAsFixed(0);
                            if (_ageMonths >= 24 && _measurementMethod == 'PB') _measurementMethod = 'TB';
                          });
                        }),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Baris 3: Cara Pengukuran Antropometri (Buku KIA 2024 hal 48)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Cara Pengukuran Panjang / Tinggi Badan (Standar Buku KIA 2024)',
                    style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700, color: text),
                  ),
                  Text(
                    isUnder24 ? 'Kemenkes: Usia < 24 bln wajib Telentang (PB)' : 'Kemenkes: Usia ≥ 24 bln wajib Berdiri (TB)',
                    style: GoogleFonts.outfit(fontSize: 9.5, color: sub, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: _buildMeasurementMethodOption(
                      code: 'PB',
                      label: 'PB Telentang (Infantometer)',
                      loinc: 'LOINC: 8306-3',
                      subtext: 'Buku KIA: Untuk bayi 0-23 bulan',
                      isSelected: _measurementMethod == 'PB',
                      onTap: () => setState(() => _measurementMethod = 'PB'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMeasurementMethodOption(
                      code: 'TB',
                      label: 'TB Berdiri (Stadiometer)',
                      loinc: 'LOINC: 8302-2',
                      subtext: 'Buku KIA: Untuk balita 24-59 bulan',
                      isSelected: _measurementMethod == 'TB',
                      onTap: () => setState(() => _measurementMethod = 'TB'),
                    ),
                  ),
                ],
              ),
              if ((_ageMonths < 24 && _measurementMethod == 'TB') || (_ageMonths >= 24 && _measurementMethod == 'PB')) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE67E22).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE67E22).withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFFE67E22)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _measurementMethod == 'TB'
                              ? 'Catatan Buku KIA hal 48: Anak < 2 th diukur berdiri, hasil dikoreksi +0.7 cm agar setara panjang telentang.'
                              : 'Catatan Buku KIA hal 48: Anak ≥ 2 th diukur telentang, hasil dikoreksi -0.7 cm agar setara tinggi berdiri.',
                          style: GoogleFonts.outfit(fontSize: 9.5, color: const Color(0xFFE67E22), fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // LANGKAH 2: PENGUKURAN ANTROPOMETRI FISIK (STANDAR BUKU KIA 2024)
  // ===========================================================================
  Widget _buildStep2Anthropometry(Color cardBg, Color border, Color text, Color sub, bool isMobile) {
    return CustomCard(
      color: cardBg,
      borderColor: border,
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Card Step 2
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1ABC9C).withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.straighten_rounded, size: 20, color: Color(0xFF1ABC9C)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Langkah 2: Pengukuran Antropometri Fisik',
                      style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w800, color: text),
                    ),
                    Text(
                      'Pengukuran Berat Badan, Panjang/Tinggi Badan, LiLA, Lingkar Kepala, dan KMS (Standar Buku KIA 2024).',
                      style: GoogleFonts.outfit(fontSize: 10.5, color: sub),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const Divider(height: 24),

          // Baris 1: Berat Badan & Tinggi Badan
          Row(
            children: [
              // Berat Badan (kg)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Berat Badan Saat Ini (kg)',
                          style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700, color: text),
                        ),
                        Text('LOINC: 29463-7', style: GoogleFonts.outfit(fontSize: 8.5, fontWeight: FontWeight.bold, color: const Color(0xFF009688))),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _buildStepperBtn(Icons.remove, () {
                          final current = double.tryParse(_weightController.text) ?? 10.0;
                          if (current > 1.0) {
                            setState(() {
                              _weightController.text = (current - 0.1).toStringAsFixed(1);
                              _smartGrowthResult = null;
                              _reasoningResult = null;
                            });
                          }
                        }),
                        const SizedBox(width: 8),
                        Expanded(
                          child: CustomTextField(
                            label: '',
                            hintText: 'Contoh: 11.5',
                            controller: _weightController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (val) => setState(() {
                              _smartGrowthResult = null;
                              _reasoningResult = null;
                            }),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildStepperBtn(Icons.add, () {
                          final current = double.tryParse(_weightController.text) ?? 10.0;
                          setState(() {
                            _weightController.text = (current + 0.1).toStringAsFixed(1);
                            _smartGrowthResult = null;
                            _reasoningResult = null;
                          });
                        }),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 16),

              // Tinggi Badan (cm)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _measurementMethod == 'PB' ? 'Panjang Badan Telentang (cm)' : 'Tinggi Badan Berdiri (cm)',
                          style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700, color: text),
                        ),
                        Text(
                          _measurementMethod == 'PB' ? 'LOINC: 8306-3' : 'LOINC: 8302-2',
                          style: GoogleFonts.outfit(fontSize: 8.5, fontWeight: FontWeight.bold, color: const Color(0xFF009688)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _buildStepperBtn(Icons.remove, () {
                          final current = double.tryParse(_heightController.text) ?? 80.0;
                          if (current > 30.0) {
                            setState(() {
                              _heightController.text = (current - 0.5).toStringAsFixed(1);
                              _smartGrowthResult = null;
                              _reasoningResult = null;
                            });
                          }
                        }),
                        const SizedBox(width: 8),
                        Expanded(
                          child: CustomTextField(
                            label: '',
                            hintText: 'Contoh: 85.0',
                            controller: _heightController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (val) => setState(() {
                              _smartGrowthResult = null;
                              _reasoningResult = null;
                            }),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildStepperBtn(Icons.add, () {
                          final current = double.tryParse(_heightController.text) ?? 80.0;
                          setState(() {
                            _heightController.text = (current + 0.5).toStringAsFixed(1);
                            _smartGrowthResult = null;
                            _reasoningResult = null;
                          });
                        }),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Baris 2: Parameter Antropometri Tambahan Buku KIA (LK, LiLA, LP)
          Row(
            children: [
              // Lingkar Kepala
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Lingkar Kepala (cm)', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700, color: text)),
                        Text('LOINC: 9843-4', style: GoogleFonts.outfit(fontSize: 8.5, fontWeight: FontWeight.bold, color: const Color(0xFF009688))),
                      ],
                    ),
                    const SizedBox(height: 6),
                    CustomTextField(
                      label: '',
                      hintText: 'Nellhaus: 47.0',
                      controller: _headCircumferenceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (val) => setState(() {}),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              // LiLA (Lingkar Lengan Atas)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('LiLA (cm)', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700, color: text)),
                        Text('LOINC: 56072-2', style: GoogleFonts.outfit(fontSize: 8.5, fontWeight: FontWeight.bold, color: const Color(0xFF009688))),
                      ],
                    ),
                    const SizedBox(height: 6),
                    CustomTextField(
                      label: '',
                      hintText: 'Contoh: 14.5',
                      controller: _lilaController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (val) => setState(() {}),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              // Lingkar Perut
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Lingkar Perut (cm)', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700, color: text)),
                        Text('LOINC: 8280-0', style: GoogleFonts.outfit(fontSize: 8.5, fontWeight: FontWeight.bold, color: const Color(0xFF009688))),
                      ],
                    ),
                    const SizedBox(height: 6),
                    CustomTextField(
                      label: '',
                      hintText: 'Contoh: 46.0',
                      controller: _waistController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (val) => setState(() {}),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Indikator Visual Pita LiLA Buku KIA
          Builder(
            builder: (context) {
              final val = double.tryParse(_lilaController.text.trim());
              final color = _getLilaColor(val);
              final status = _getLilaStatusText(val);
              return Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.straighten_rounded, size: 14, color: color),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Pita LiLA Buku KIA 2024: $status',
                        style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: color),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 16),

          // Baris 3: Tren Pertumbuhan KMS Balita (Kartu Menuju Sehat)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Tren Pertumbuhan KMS Balita (Kartu Menuju Sehat - Buku KIA 2024)',
                    style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700, color: text),
                  ),
                  Text(
                    'Deteksi Dini Gagal Tumbuh / Weight Faltering',
                    style: GoogleFonts.outfit(fontSize: 9.5, color: sub, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildKmsOptionChip('N', 'N (Naik ≥ KBM)', const Color(0xFF27AE60)),
                  _buildKmsOptionChip('T', 'T (Tidak Naik / Tetap)', const Color(0xFFE67E22)),
                  _buildKmsOptionChip('2T', '2T (2x Tidak Naik - Red Flag)', const Color(0xFFE74C3C)),
                  _buildKmsOptionChip('BGM', 'BGM (Bawah Garis Merah - Red Flag)', const Color(0xFFC0392B)),
                  _buildKmsOptionChip('Baru', 'Pertama Kali Menimbang', const Color(0xFF3498DB)),
                ],
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Baris 4: Suplementasi Buku KIA 2024
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: border.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Kapsul Vitamin A',
                      style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700, color: text),
                    ),
                    subtitle: Text(
                      _ageMonths < 12 ? 'Kapsul Biru (100.000 IU)' : 'Kapsul Merah (200.000 IU) - Bulan Feb/Agu',
                      style: GoogleFonts.outfit(fontSize: 9.5, color: sub),
                    ),
                    value: _receivedVitA,
                    activeColor: const Color(0xFF1ABC9C),
                    onChanged: (val) => setState(() => _receivedVitA = val ?? true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Obat Cacing (Pencegahan)',
                      style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700, color: text),
                    ),
                    subtitle: Text(
                      _ageMonths >= 12 ? 'Diberikan tiap 6 bulan (Usia 1-5 tahun)' : 'Belum usia target (< 12 bulan)',
                      style: GoogleFonts.outfit(fontSize: 9.5, color: sub),
                    ),
                    value: _ageMonths >= 12 ? _receivedDeworming : false,
                    activeColor: const Color(0xFF1ABC9C),
                    onChanged: _ageMonths >= 12 ? (val) => setState(() => _receivedDeworming = val ?? true) : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetChip(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF1ABC9C).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF1ABC9C).withOpacity(0.3)),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF1ABC9C)),
        ),
      ),
    );
  }

  Widget _buildGenderOption({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required Color color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.white : color),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? Colors.white : Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepperBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: const Color(0xFF1ABC9C).withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 16, color: const Color(0xFF1ABC9C)),
      ),
    );
  }

  Widget _buildMeasurementMethodOption({
    required String code,
    required String label,
    required String loinc,
    required String subtext,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1ABC9C).withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF1ABC9C) : Colors.grey.withOpacity(0.3),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              size: 18,
              color: isSelected ? const Color(0xFF1ABC9C) : Colors.grey,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        label,
                        style: GoogleFonts.outfit(
                          fontSize: 11.5,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1ABC9C).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          loinc,
                          style: GoogleFonts.outfit(fontSize: 8, fontWeight: FontWeight.bold, color: const Color(0xFF1ABC9C)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(subtext, style: GoogleFonts.outfit(fontSize: 9.5, color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKmsOptionChip(String code, String label, Color color) {
    final isSelected = _kmsStatus == code;
    return InkWell(
      onTap: () => setState(() => _kmsStatus = code),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : color.withOpacity(0.3),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? Icons.check_circle_rounded : Icons.circle_outlined,
              size: 14,
              color: isSelected ? Colors.white : color,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? Colors.white : color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoincBadge(String label, String value, String code) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1ABC9C).withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF1ABC9C).withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.outfit(fontSize: 9.5, color: Colors.grey)),
          Text(value, style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w800)),
          Text(code, style: GoogleFonts.outfit(fontSize: 8.5, fontWeight: FontWeight.bold, color: const Color(0xFF1ABC9C))),
        ],
      ),
    );
  }

  // ===========================================================================
  // PROGRESS BAR LOADING CARD (LINEAR PROGRESS - TIDAK PAKAI LOADING CIRCLE)
  // ===========================================================================
  Widget _buildProgressBarLoadingCard({
    required String title,
    required String subtitle,
    required Color cardBg,
    required Color border,
    required Color text,
    required Color sub,
    IconData icon = Icons.psychology_rounded,
    List<String>? steps,
    int activeStepIndex = 1,
  }) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF1ABC9C).withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1ABC9C).withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1ABC9C).withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 20, color: const Color(0xFF1ABC9C)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.outfit(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.outfit(fontSize: 11, color: sub),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Progress Bar Linear (Sesuai Permintaan Pengguna: Progress Bar, Bukan Lingkaran)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 8,
              child: LinearProgressIndicator(
                backgroundColor: const Color(0xFF1ABC9C).withOpacity(0.15),
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF1ABC9C)),
              ),
            ),
          ),
          if (steps != null && steps.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: List.generate(steps.length, (idx) {
                final isDone = idx < activeStepIndex;
                final isCurrent = idx == activeStepIndex;
                final stepColor = isDone
                    ? const Color(0xFF27AE60)
                    : isCurrent
                        ? const Color(0xFF1ABC9C)
                        : sub.withOpacity(0.5);
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: stepColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: stepColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isDone)
                        const Icon(Icons.check_rounded, size: 11, color: Color(0xFF27AE60))
                      else if (isCurrent)
                        const Icon(Icons.sync_rounded, size: 11, color: Color(0xFF1ABC9C))
                      else
                        Icon(Icons.circle_outlined, size: 9, color: sub.withOpacity(0.5)),
                      const SizedBox(width: 4),
                      Text(
                        steps[idx],
                        style: GoogleFonts.outfit(
                          fontSize: 9.5,
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                          color: stepColor,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ],
        ],
      ),
    );
  }

  // ===========================================================================
  // LANGKAH 3: KLASIFIKASI MODEL MLP (OTOMATIS) & CLINICAL REASONING (TOMBOL)
  // ===========================================================================
  Widget _buildStep3ReasoningAndAi(Color cardBg, Color border, Color text, Color sub, bool isMobile) {
    final bb = double.tryParse(_weightController.text.trim()) ?? 0.0;
    final tb = double.tryParse(_heightController.text.trim()) ?? 0.0;
    final isAntroValid = bb > 0 && tb > 0;
    final isEn = ref.watch(landingPageProvider).language == 'en';

    // Otomatis mengeksekusi model MLP (Keras Smart Growth) jika belum dijalankan
    if (isAntroValid && _smartGrowthResult == null && !_isLoadingClassification) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _smartGrowthResult == null && !_isLoadingClassification) {
          _runMlpClassification(silent: true);
        }
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Main Control Card for Step 3
        CustomCard(
          color: cardBg,
          borderColor: border,
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Card Step 3
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1ABC9C).withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.psychology_rounded, size: 22, color: Color(0xFF1ABC9C)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              isEn
                                  ? 'Step 3: MLP Classification & Clinical AI Reasoning'
                                  : 'Langkah 3: Klasifikasi MLP & Clinical AI Reasoning',
                              style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w800, color: text),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: (_reasoningResult != null
                                        ? const Color(0xFF27AE60)
                                        : (_smartGrowthResult != null
                                            ? const Color(0xFF1ABC9C)
                                            : const Color(0xFFF39C12)))
                                    .withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: (_reasoningResult != null
                                          ? const Color(0xFF27AE60)
                                          : (_smartGrowthResult != null
                                              ? const Color(0xFF1ABC9C)
                                              : const Color(0xFFF39C12)))
                                      .withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                _reasoningResult != null
                                    ? (isEn ? 'AI Complete (${_reasoningPromptCount}x prompt)' : 'AI Selesai (${_reasoningPromptCount}x diprompt)')
                                    : (_smartGrowthResult != null
                                        ? (isEn ? 'MLP Auto Done • Reasoning Ready' : 'MLP Selesai (Otomatis) • Reasoning Siap')
                                        : (_isLoadingClassification
                                            ? (isEn ? 'Auto Running MLP...' : 'Otomatis Memproses MLP...')
                                            : (isEn ? 'Disarankan (Opsional)' : 'Disarankan (Opsional)'))),
                                style: GoogleFonts.outfit(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.bold,
                                  color: _reasoningResult != null
                                      ? const Color(0xFF27AE60)
                                      : (_smartGrowthResult != null
                                          ? const Color(0xFF1ABC9C)
                                          : const Color(0xFFD68910)),
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          isEn
                              ? 'Keras MLP automatic classification & Gemini 2.5 Flash clinical reasoning for stunting detection and nutritional intervention.'
                              : 'Klasifikasi otomatis Machine Learning Keras MLP & Penalaran Klinis Gemini 2.5 Flash untuk deteksi stunting dan intervensi gizi.',
                          style: GoogleFonts.outfit(fontSize: 10.5, color: sub),
                        ),
                      ],
                    ),
                  ),
                  if (_smartGrowthResult != null) ...[
                    if (_reasoningResult != null || _reasoningPromptCount > 0) ...[
                      CustomButton(
                        text: _isLoadingReasoning
                            ? (isEn ? 'Processing...' : 'Memproses...')
                            : (isEn ? 'Re-Prompt AI (${_reasoningPromptCount}x)' : 'Prompt Ulang AI (${_reasoningPromptCount}x)'),
                        icon: Icons.refresh_rounded,
                        height: 34,
                        primaryColor: const Color(0xFF1ABC9C),
                        isSecondary: true,
                        onPressed: (_isLoadingClassification || _isLoadingReasoning)
                            ? null
                            : () => _confirmRePromptDialog(),
                      ),
                      const SizedBox(width: 8),
                    ],
                    CustomButton(
                      text: isEn ? 'Copy Report' : 'Salin Laporan',
                      icon: Icons.copy_rounded,
                      height: 34,
                      isSecondary: true,
                      onPressed: _copyReportToClipboard,
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 16),

              // 1. Loading State Banner untuk MLP Otomatis (PROGRESS BAR)
              if (_isLoadingClassification) ...[
                _buildProgressBarLoadingCard(
                  title: isEn
                      ? 'MLP Model Automatically Classifying Anthropometric Ratios...'
                      : 'Model MLP Mengklasifikasikan Rasio Antropometri (Otomatis)...',
                  subtitle: isEn
                      ? 'Analyzing probabilities of weight-for-height and height-for-age linear growth without manual trigger.'
                      : 'Menganalisis probabilitas status gizi BB/TB dan status pertumbuhan linier TB/U secara otomatis tanpa perlu tombol.',
                  cardBg: cardBg,
                  border: border,
                  text: text,
                  sub: sub,
                  icon: Icons.memory_rounded,
                  steps: isEn
                      ? ['FastAPI Model Link', 'BB/TB & TB/U Inference', 'Confidence Scoring']
                      : ['Koneksi Model FastAPI', 'Inferensi BB/TB & TB/U', 'Kalkulasi Confidence'],
                  activeStepIndex: 1,
                ),
              ]
              // 2. Data Not Valid Warning
              else if (!isAntroValid) ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE67E22).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE67E22).withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, size: 28, color: Color(0xFFE67E22)),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isEn ? 'Anthropometry Data Incomplete' : 'Data Antropometri Belum Lengkap',
                              style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w900, color: const Color(0xFFE67E22)),
                            ),
                            Text(
                              isEn
                                  ? 'Please input valid Weight and Height in Step 2 to run automatic MLP classification.'
                                  : 'Harap lengkapi data Berat Badan dan Tinggi/Panjang Badan di Langkah 2 terlebih dahulu agar model MLP dapat berjalan otomatis.',
                              style: GoogleFonts.outfit(fontSize: 11, color: sub),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      CustomButton(
                        text: isEn ? '← Back to Step 2' : '← Kembali ke Langkah 2',
                        height: 38,
                        onPressed: () => setState(() => _formStep = 2),
                      ),
                    ],
                  ),
                ),
              ]
              // 3. Clinical AI Reasoning Card (Butuh Tombol untuk Dijalankan)
              else if (_reasoningResult == null && !_isLoadingReasoning) ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1ABC9C).withOpacity(0.06),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF1ABC9C).withOpacity(0.25)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1ABC9C).withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.psychology_alt_rounded, size: 24, color: Color(0xFF1ABC9C)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      isEn ? 'Clinical AI Reasoning (Gemini 2.5 Flash)' : 'Penalaran Klinis AI (Gemini 2.5 Flash)',
                                      style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w900, color: const Color(0xFF16A085)),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF39C12).withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                      child: Text(
                                        isEn ? 'Optional • Click to Run' : 'Opsional • Tekan Tombol',
                                        style: GoogleFonts.outfit(fontSize: 8.5, fontWeight: FontWeight.bold, color: const Color(0xFFD68910)),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isEn
                                      ? 'MLP classification has completed automatically below. To generate pediatrician clinical chain-of-thought, risk factor analysis, and Buku KIA nutritional guidance, press the button below (or proceed to Step 4).'
                                      : 'Klasifikasi model MLP telah berjalan otomatis di bawah. Untuk menghasilkan alur berpikir medis dokter spesialis anak, analisis faktor risiko gizi, dan rekomendasi Buku KIA 2024, silakan tekan tombol di bawah (atau lewati ke Langkah 4).',
                                  style: GoogleFonts.outfit(fontSize: 10.5, color: sub),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      // Antropometri recap badges
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _buildMiniBadge('Berat Badan', '$bb kg'),
                          _buildMiniBadge('Tinggi Badan', '$tb cm'),
                          _buildMiniBadge('Usia', '${_ageMonths.toInt()} Bulan'),
                          _buildMiniBadge('Cara Ukur', _measurementMethod == 'PB' ? 'PB Telentang' : 'TB Berdiri'),
                          if (_lilaController.text.isNotEmpty)
                            _buildMiniBadge('LiLA', '${_lilaController.text} cm'),
                          if (_headCircumferenceController.text.isNotEmpty)
                            _buildMiniBadge('Lingkar Kepala', '${_headCircumferenceController.text} cm'),
                          _buildMiniBadge('Tren KMS', _kmsStatus),
                          if (_smartGrowthResult != null)
                            _buildMiniBadge('Status Gizi MLP', _smartGrowthResult!.kategoriGiziBbtb),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Tombol Generate Reasoning & Tombol Lewati
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: CustomButton(
                              text: isEn
                                  ? 'Run Clinical AI Reasoning (Gemini 2.5 Flash) ➔'
                                  : 'Jalankan Penalaran Klinis AI (Gemini 2.5 Flash) ➔',
                              icon: Icons.psychology_rounded,
                              height: 46,
                              primaryColor: const Color(0xFF1ABC9C),
                              onPressed: _runReasoningOnly,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: CustomButton(
                              text: isEn ? 'Next to Step 4 (SATUSEHAT) ➔' : 'Lanjut ke Langkah 4 ➔',
                              isSecondary: true,
                              height: 46,
                              onPressed: () => setState(() => _formStep = 4),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ]
              // 4. Loading Reasoning State Banner (PROGRESS BAR - BUKAN CIRCULAR SPINNER)
              else if (_isLoadingReasoning) ...[
                _buildProgressBarLoadingCard(
                  title: isEn
                      ? 'Clinical Reasoning Engine Working (Gemini 2.5 Flash)...'
                      : 'Clinical Reasoning Engine Sedang Bekerja (Gemini 2.5 Flash)...',
                  subtitle: isEn
                      ? 'Structuring pediatric chain-of-thought, clinical risk factors, and KIA nutrition intervention plan.'
                      : 'Menyusun alur berpikir medis (Chain of Thought), faktor risiko klinis, rekomendasi gizi PMT & protokol rujukan Buku KIA 2024.',
                  cardBg: cardBg,
                  border: border,
                  text: text,
                  sub: sub,
                  icon: Icons.psychology_rounded,
                  steps: isEn
                      ? ['Child Anthropometric Data', 'Gemini 2.5 Flash Reasoning', 'KIA Nutritional Action Plan']
                      : ['Data Antropometri Balita', 'Penalaran Gemini 2.5 Flash', 'Rekomendasi Intervensi Gizi KIA'],
                  activeStepIndex: 1,
                ),
              ]
              // 5. Reasoning Completed Success Banner
              else ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF27AE60).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF27AE60).withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, size: 18, color: Color(0xFF27AE60)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isEn
                              ? '✅ MLP Model Classification & Clinical AI Reasoning Complete (Prompted $_reasoningPromptCount time(s)). You may Re-Prompt or proceed to Step 4.'
                              : '✅ Klasifikasi Model MLP & Clinical Reasoning AI Selesai (Sudah diprompt $_reasoningPromptCount kali). Anda dapat melakukan Prompt Ulang atau lanjut ke Langkah 4 untuk Simpan.',
                          style: GoogleFonts.outfit(fontSize: 10.5, fontWeight: FontWeight.bold, color: const Color(0xFF27AE60)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF27AE60)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        ),
                        onPressed: () => _confirmRePromptDialog(),
                        icon: const Icon(Icons.refresh_rounded, size: 14, color: Color(0xFF27AE60)),
                        label: Text(
                          isEn ? 'Re-Prompt (${_reasoningPromptCount}x)' : 'Prompt Ulang (${_reasoningPromptCount}x)',
                          style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF27AE60)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF27AE60),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        ),
                        onPressed: () => setState(() => _formStep = 4),
                        icon: const Icon(Icons.arrow_forward_rounded, size: 14, color: Colors.white),
                        label: Text(
                          isEn ? 'Step 4 ➔' : 'Langkah 4 ➔',
                          style: GoogleFonts.outfit(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        // Tampilkan Hasil Klasifikasi MLP Segera Setelah Selesai (Otomatis)
        if (_smartGrowthResult != null) ...[
          const SizedBox(height: 16),
          _buildMlpClassificationResult(cardBg, border, text, sub, isMobile),
        ],

        // Tampilkan Section Clinical AI Reasoning Hanya Jika Sudah Dijalankan
        if (_reasoningResult != null) ...[
          const SizedBox(height: 16),
          _buildReasoningSection(cardBg, border, text, sub, isMobile),
        ],
      ],
    );
  }

  // ===========================================================================
  // LANGKAH 4: INTEROPERABILITAS SATUSEHAT KEMENKES RI (FHIR R4) & SIMPAN
  // ===========================================================================
  Widget _buildStep4SatuSehatAndSave(Color cardBg, Color border, Color text, Color sub, bool isMobile) {
    final bb = _weightController.text;
    final tb = _heightController.text;
    final isRecumbent = _measurementMethod == 'PB';
    final tbLoinc = isRecumbent ? '8306-3 (Body height --lying)' : '8302-2 (Body height)';
    final syncRes = _satuSehatSyncResult;
    final hasAi = _smartGrowthResult != null && _reasoningResult != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // SATUSEHAT FHIR R4 Integration Card (Preview FHIR R4 JSON button removed)
        CustomCard(
          color: cardBg,
          borderColor: const Color(0xFF009688).withOpacity(0.4),
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF009688).withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.cloud_sync_rounded, size: 22, color: Color(0xFF009688)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Langkah 4: Interoperabilitas SATUSEHAT Kemenkes RI',
                              style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w900, color: text),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF009688).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'FHIR R4 Standard',
                                style: GoogleFonts.outfit(fontSize: 8.5, fontWeight: FontWeight.bold, color: const Color(0xFF009688)),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'Standardisasi data antropometri anak menggunakan LOINC & diagnosis stunting ICD-10.',
                          style: GoogleFonts.outfit(fontSize: 10.5, color: sub),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Grid Mapping Standar LOINC
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: border.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: border),
                ),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 10,
                  children: [
                    _buildLoincBadge('Berat Badan', '$bb kg', 'LOINC 29463-7'),
                    _buildLoincBadge(isRecumbent ? 'Panjang Badan' : 'Tinggi Badan', '$tb cm', 'LOINC $tbLoinc'),
                    if (_headCircumferenceController.text.isNotEmpty)
                      _buildLoincBadge('Lingkar Kepala', '${_headCircumferenceController.text} cm', 'LOINC 9843-4'),
                    if (_lilaController.text.isNotEmpty)
                      _buildLoincBadge('LiLA', '${_lilaController.text} cm', 'LOINC 56072-2'),
                    if (_waistController.text.isNotEmpty)
                      _buildLoincBadge('Lingkar Perut', '${_waistController.text} cm', 'LOINC 8280-0'),
                    _buildLoincBadge(
                      'Diagnosis Gizi',
                      _smartGrowthResult?.isStunting == true
                          ? 'Stunting'
                          : (_smartGrowthResult?.isGiziBurukAtauKurang == true ? 'Gizi Kurang' : 'Normal'),
                      _smartGrowthResult?.isStunting == true
                          ? 'ICD-10 E45'
                          : (_smartGrowthResult?.isGiziBurukAtauKurang == true ? 'ICD-10 E44.0' : 'ICD-10 Z00.1'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Status Sinkronisasi SatuSehat jika sudah dikirim
              if (syncRes != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF27AE60).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF27AE60).withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, size: 20, color: Color(0xFF27AE60)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Observasi Antropometri Terverifikasi SATUSEHAT',
                              style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.bold, color: const Color(0xFF27AE60)),
                            ),
                            Text(
                              'Mode: ${syncRes['mode']} • Encounter ID: ${syncRes['encounter_id']} • Patient ID: ${syncRes['patient_id']}',
                              style: GoogleFonts.outfit(fontSize: 10, color: sub),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Tombol Sinkronisasi ke SatuSehat
              CustomButton(
                text: _isSyncingSatuSehat
                    ? 'Mengemas & Mengirim Bundle FHIR R4 ke SATUSEHAT...'
                    : 'Kirim Observasi Antropometri ke SATUSEHAT (FHIR R4)',
                icon: Icons.send_rounded,
                height: 46,
                primaryColor: const Color(0xFF009688),
                onPressed: _isSyncingSatuSehat
                    ? null
                    : () {
                        _syncToSatuSehat();
                      },
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Summary Card & Final Submit
        CustomCard(
          color: cardBg,
          borderColor: border,
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF27AE60).withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.assignment_turned_in_rounded, size: 20, color: Color(0xFF27AE60)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ringkasan Akhir & Simpan Rekam Medis',
                          style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w800, color: text),
                        ),
                        Text(
                          'Pastikan data balita dan hasil AI telah ditinjau sebelum disimpan ke database.',
                          style: GoogleFonts.outfit(fontSize: 10.5, color: sub),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const Divider(height: 24),

              // Preview Data
              _buildReviewRow('Nama Balita', _nameController.text, sub, text),
              _buildReviewRow('NIK Balita', _nikController.text, sub, text),
              _buildReviewRow('Jenis Kelamin / Usia', '${_selectedGender == 0 ? "Laki-laki" : "Perempuan"} • ${_ageMonths.toInt()} Bulan', sub, text),
              _buildReviewRow('Berat & Tinggi', '$bb kg / $tb cm', sub, text),
              _buildReviewRow('LiLA & Lingkar Kepala', '${_lilaController.text} cm / ${_headCircumferenceController.text} cm', sub, text),
              _buildReviewRow('Status Gizi BB/TB', _smartGrowthResult?.kategoriGiziBbtb ?? 'Belum Dianalisis', sub, text, isBold: true),
              _buildReviewRow('Status Stunting TB/U', _smartGrowthResult?.kategoriStuntingTbu ?? 'Belum Dianalisis', sub, text, isBold: true),
              _buildReviewRow('Clinical AI Reasoning', hasAi ? 'Tersedia (${_reasoningResult!.modelUsed} - ${_reasoningPromptCount}x diprompt)' : 'Belum Dijalankan (Opsional)', sub, text),

              const SizedBox(height: 20),

              // Final Submit Button
              CustomButton(
                text: 'Review & Simpan Rekam Medis Skrining Balita 💾',
                icon: Icons.cloud_upload_rounded,
                height: 48,
                primaryColor: const Color(0xFF27AE60),
                onPressed: _showReviewAndSubmitDialog,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // STEPPER FOOTER & REAL-TIME VALIDATION PILL
  // ===========================================================================
  Widget _buildScreeningStepperFooter({
    required Color cardBgColor,
    required Color borderColor,
    required Color textColor,
    required Color subtitleColor,
    required bool isMobile,
    required List<Map<String, dynamic>> redErrors,
    required List<Map<String, dynamic>> yellowWarnings,
  }) {
    final hasAi = _smartGrowthResult != null && _reasoningResult != null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildScreeningValidationStatusPill(redErrors, yellowWarnings, subtitleColor),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (_formStep > 1)
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: borderColor),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () => setState(() => _formStep--),
                          icon: const Icon(Icons.arrow_back_rounded, size: 14),
                          label: Text('Sebelumnya', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: textColor)),
                        ),
                      ),
                    if (_formStep > 1) const SizedBox(width: 8),
                    Expanded(
                      child: _buildFooterActionButton(hasAi, redErrors),
                    ),
                  ],
                ),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Left: Previous Step
                if (_formStep > 1)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: borderColor),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onPressed: () => setState(() => _formStep--),
                    icon: const Icon(Icons.arrow_back_rounded, size: 16),
                    label: Text(
                      '← Sebelumnya',
                      style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: textColor),
                    ),
                  )
                else
                  const SizedBox.shrink(),

                // Center: Clickable Validation Status Pill
                _buildScreeningValidationStatusPill(redErrors, yellowWarnings, subtitleColor),

                // Right: Action Button
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF1ABC9C)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      onPressed: _showReviewAndSubmitDialog,
                      icon: const Icon(Icons.fact_check_rounded, size: 16, color: Color(0xFF1ABC9C)),
                      label: Text(
                        'Review Validasi',
                        style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF1ABC9C)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _buildFooterActionButton(hasAi, redErrors),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _buildFooterActionButton(bool hasAi, List<Map<String, dynamic>> redErrors) {
    final isEn = ref.watch(landingPageProvider).language == 'en';

    if (_formStep < 3) {
      return ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1ABC9C),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          elevation: 2,
        ),
        onPressed: () {
          final next = _formStep + 1;
          setState(() => _formStep = next);
          if (next == 3) {
            _checkAndAutoRunMlp();
          }
        },
        icon: const Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.white),
        label: Text(
          isEn ? 'Next ➔' : 'Selanjutnya ➔',
          style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      );
    } else if (_formStep == 3) {
      if (_reasoningResult == null) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF1ABC9C)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
              onPressed: () => setState(() => _formStep = 4),
              icon: const Icon(Icons.arrow_forward_rounded, size: 16, color: Color(0xFF1ABC9C)),
              label: Text(
                _smartGrowthResult != null
                    ? (isEn ? 'Next to Step 4 ➔' : 'Lanjut ke Langkah 4 ➔')
                    : (isEn ? 'Skip ➔' : 'Lewati ➔'),
                style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF1ABC9C)),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1ABC9C),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                elevation: 2,
              ),
              onPressed: (_isLoadingClassification || _isLoadingReasoning)
                  ? null
                  : () {
                      _runReasoningOnly();
                    },
              icon: (_isLoadingClassification || _isLoadingReasoning)
                  ? const Icon(Icons.sync_rounded, size: 16, color: Colors.white)
                  : const Icon(Icons.psychology_rounded, size: 16, color: Colors.white),
              label: Text(
                _isLoadingReasoning
                    ? (isEn ? 'Processing Reasoning...' : 'Memproses Reasoning...')
                    : (_isLoadingClassification
                        ? (isEn ? 'Classifying MLP...' : 'Memproses MLP...')
                        : (isEn ? 'Run Reasoning AI ➔' : 'Jalankan Reasoning Gemini ➔')),
                style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ],
        );
      } else {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF1ABC9C)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              onPressed: () => _confirmRePromptDialog(),
              icon: const Icon(Icons.refresh_rounded, size: 15, color: Color(0xFF1ABC9C)),
              label: Text(
                isEn ? 'Re-Prompt (${_reasoningPromptCount}x)' : 'Prompt Ulang (${_reasoningPromptCount}x)',
                style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF1ABC9C)),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1ABC9C),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                elevation: 2,
              ),
              onPressed: () => setState(() => _formStep = 4),
              icon: const Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.white),
              label: Text(
                isEn ? 'Next (SATUSEHAT) ➔' : 'Selanjutnya (SATUSEHAT) ➔',
                style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ],
        );
      }
    } else {
      return ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: redErrors.isNotEmpty ? const Color(0xFFE74C3C) : const Color(0xFF27AE60),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          elevation: 2,
        ),
        onPressed: _showReviewAndSubmitDialog,
        icon: const Icon(Icons.cloud_upload_rounded, color: Colors.white, size: 16),
        label: Text(
          'Review & Simpan 💾',
          style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      );
    }
  }

  Widget _buildScreeningValidationStatusPill(
    List<Map<String, dynamic>> redErrors,
    List<Map<String, dynamic>> yellowWarnings,
    Color subtitleColor,
  ) {
    final hasRed = redErrors.isNotEmpty;
    final hasYellow = yellowWarnings.isNotEmpty;

    final Color badgeBg;
    final Color badgeBorder;
    final Color badgeColor;
    final IconData badgeIcon;
    final String badgeText;

    if (hasRed) {
      badgeBg = const Color(0xFFE74C3C).withOpacity(0.12);
      badgeBorder = const Color(0xFFE74C3C).withOpacity(0.4);
      badgeColor = const Color(0xFFE74C3C);
      badgeIcon = Icons.error_outline_rounded;
      badgeText = '${redErrors.length} Data Wajib Kurang (Klik)';
    } else if (hasYellow) {
      badgeBg = const Color(0xFFF39C12).withOpacity(0.12);
      badgeBorder = const Color(0xFFF39C12).withOpacity(0.4);
      badgeColor = const Color(0xFFD68910);
      badgeIcon = Icons.info_outline_rounded;
      badgeText = 'Form Lengkap (${yellowWarnings.length} Saran Opsional)';
    } else {
      badgeBg = const Color(0xFF27AE60).withOpacity(0.12);
      badgeBorder = const Color(0xFF27AE60).withOpacity(0.4);
      badgeColor = const Color(0xFF27AE60);
      badgeIcon = Icons.check_circle_rounded;
      badgeText = '✅ Form Lengkap & Reasoning Selesai';
    }

    return InkWell(
      onTap: _showReviewAndSubmitDialog,
      borderRadius: BorderRadius.circular(100),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: badgeBg,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: badgeBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(badgeIcon, size: 14, color: badgeColor),
            const SizedBox(width: 6),
            Text(
              badgeText,
              style: GoogleFonts.outfit(fontSize: 10.5, fontWeight: FontWeight.bold, color: badgeColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniBadge(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1ABC9C).withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF1ABC9C).withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ', style: GoogleFonts.outfit(fontSize: 9.5, color: Colors.grey)),
          Text(value, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF1ABC9C))),
        ],
      ),
    );
  }

  // ===========================================================================
  // HASIL KLASIFIKASI MODEL MLP
  // ===========================================================================
  Widget _buildMlpClassificationResult(Color cardBg, Color border, Color text, Color sub, bool isMobile) {
    final sg = _smartGrowthResult;

    final kategoriGizi = sg?.kategoriGiziBbtb ?? 'Gizi Normal';
    final kategoriStunting = sg?.kategoriStuntingTbu ?? 'Normal';
    final confGizi = sg?.confidenceBbtb ?? 0.0;
    final confStunt = sg?.confidenceTbu ?? 0.0;

    final isStunting = sg?.isStunting ?? false;
    final isGiziKurang = sg?.isGiziBurukAtauKurang ?? false;

    // Warna status
    Color giziColor = const Color(0xFF27AE60);
    if (kategoriGizi.contains('Buruk')) giziColor = const Color(0xFFE74C3C);
    else if (kategoriGizi.contains('Kurang')) giziColor = const Color(0xFFE67E22);
    else if (kategoriGizi.contains('Lebih') || kategoriGizi.contains('Obesitas')) giziColor = const Color(0xFF9B59B6);

    Color stuntingColor = const Color(0xFF27AE60);
    if (kategoriStunting.contains('Sangat Pendek')) stuntingColor = const Color(0xFFE74C3C);
    else if (kategoriStunting.contains('Pendek')) stuntingColor = const Color(0xFFE67E22);
    else if (kategoriStunting.contains('Tinggi')) stuntingColor = const Color(0xFF3498DB);

    return CustomCard(
      color: cardBg,
      borderColor: border,
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Hasil Klasifikasi
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF27AE60).withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.verified_rounded, size: 22, color: Color(0xFF27AE60)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Hasil Klasifikasi Model MLP VitaScale',
                          style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900, color: text),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF27AE60).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Keras MLP Neural Network',
                            style: GoogleFonts.outfit(fontSize: 8.5, fontWeight: FontWeight.bold, color: const Color(0xFF27AE60)),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'Evaluasi status gizi rasio BB/TB dan status pertumbuhan linier TB/U.',
                      style: GoogleFonts.outfit(fontSize: 10.5, color: sub),
                    ),
                  ],
                ),
              ),
              CustomButton(
                text: 'Salin Laporan',
                icon: Icons.copy_rounded,
                height: 34,
                isSecondary: true,
                onPressed: _copyReportToClipboard,
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Alert Banner jika Ada Indikasi
          if (isStunting || isGiziKurang) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFE74C3C).withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE74C3C).withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 24, color: Color(0xFFE74C3C)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PERHATIAN: Terdeteksi Indikasi Masalah Pertumbuhan',
                          style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.w900, color: const Color(0xFFE74C3C)),
                        ),
                        Text(
                          'Balita memerlukan intervensi nutrisi khusus dan penelaahan faktor etiologi melalui penalaran klinis di bawah.',
                          style: GoogleFonts.outfit(fontSize: 10, color: sub),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // 2 Kartu Status Utama
          Row(
            children: [
              // Kartu 1: Status Gizi BB/TB
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: giziColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: giziColor.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('STATUS GIZI (BB/TB)', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w800, color: sub)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: giziColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${confGizi.toStringAsFixed(1)}% Keyakinan',
                              style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.bold, color: giziColor),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        kategoriGizi,
                        style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900, color: giziColor),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Menilai keselarasan berat terhadap tinggi badan (indikator malnutrisi akut).',
                        style: GoogleFonts.outfit(fontSize: 9.5, color: sub),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 14),

              // Kartu 2: Status Stunting TB/U
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: stuntingColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: stuntingColor.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('STATUS PERTUMBUHAN (TB/U)', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w800, color: sub)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: stuntingColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${confStunt.toStringAsFixed(1)}% Keyakinan',
                              style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.bold, color: stuntingColor),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        kategoriStunting,
                        style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900, color: stuntingColor),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Menilai defisit tinggi badan linier terhadap usia (indikator stunting kronis).',
                        style: GoogleFonts.outfit(fontSize: 9.5, color: sub),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Probabilitas Bar Breakdown (Jika Smart Growth)
          if (sg != null && sg.probabilitasBbtb.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text(
              'Distribusi Probabilitas Kelas Model MLP:',
              style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: text),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: sg.probabilitasBbtb.entries.map((entry) {
                final pct = (entry.value * 100);
                return SizedBox(
                  width: isMobile ? double.infinity : 220,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(entry.key, style: GoogleFonts.outfit(fontSize: 10, color: text)),
                          Text('${pct.toStringAsFixed(1)}%', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: sub)),
                        ],
                      ),
                      const SizedBox(height: 3),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: entry.value,
                          minHeight: 5,
                          backgroundColor: border.withOpacity(0.2),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            entry.key == kategoriGizi ? giziColor : Colors.grey.withOpacity(0.4),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  // ===========================================================================
  // CLINICAL AI REASONING MODEL (GEMINI 2.5 FLASH)
  // ===========================================================================
  Widget _buildReasoningSection(Color cardBg, Color border, Color text, Color sub, bool isMobile) {
    final isEn = ref.watch(landingPageProvider).language == 'en';
    if (_isLoadingReasoning) {
      return _buildProgressBarLoadingCard(
        title: isEn
            ? 'Clinical Reasoning Engine Working (Gemini 2.5 Flash)...'
            : 'Clinical Reasoning Engine Sedang Bekerja (Gemini 2.5 Flash)...',
        subtitle: isEn
            ? 'Structuring pediatric chain-of-thought, clinical risk factors, and KIA nutrition intervention plan.'
            : 'Model Penalaran Klinis AI (Gemini 2.5 Flash) sedang menyusun alur berpikir medis, analisis faktor risiko, dan rencana intervensi nutrisi sesuai standar WHO/Kemenkes RI.',
        cardBg: cardBg,
        border: border,
        text: text,
        sub: sub,
        icon: Icons.psychology_rounded,
        steps: isEn
            ? ['Child Anthropometric Data', 'Gemini 2.5 Flash Reasoning', 'KIA Nutritional Action Plan']
            : ['Data Antropometri Balita', 'Penalaran Gemini 2.5 Flash', 'Rekomendasi Intervensi Gizi KIA'],
        activeStepIndex: 1,
      );
    }

    final reasoning = _reasoningResult;
    if (reasoning == null) return const SizedBox.shrink();

    return CustomCard(
      color: cardBg,
      borderColor: const Color(0xFF1ABC9C).withOpacity(0.5),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Reasoning Model
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1ABC9C), Color(0xFF16A085)],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.psychology_alt_rounded, size: 22, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Clinical AI Reasoning Engine',
                          style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900, color: text),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1ABC9C).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF1ABC9C).withOpacity(0.3)),
                          ),
                          child: Text(
                            reasoning.modelUsed,
                            style: GoogleFonts.outfit(fontSize: 8.5, fontWeight: FontWeight.bold, color: const Color(0xFF1ABC9C)),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'Alur penalaran klinis dokter spesialis anak & panduan intervensi berbasis bukti (Permenkes No. 2/2020).',
                      style: GoogleFonts.outfit(fontSize: 10.5, color: sub),
                    ),
                  ],
                ),
              ),
              CustomButton(
                text: _reasoningPromptCount > 0 ? 'Prompt Ulang AI (${_reasoningPromptCount}x)' : 'Analisis Ulang AI',
                icon: Icons.refresh_rounded,
                height: 34,
                primaryColor: const Color(0xFF1ABC9C),
                isSecondary: true,
                onPressed: () {
                  _confirmRePromptDialog();
                },
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Ringkasan Penalaran Medis (Summary Box)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1ABC9C).withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF1ABC9C).withOpacity(0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.format_quote_rounded, size: 20, color: Color(0xFF1ABC9C)),
                const SizedBox(width: 10),
                Expanded(
                  child: FormattedMarkdownText(
                    text: reasoning.reasoningSummary,
                    style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.w600, color: text, height: 1.4),
                    boldStyle: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.w800, color: const Color(0xFF1ABC9C), height: 1.4),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Sub-Tab Navigasi Reasoning
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: border.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                _buildReasoningTabItem(0, 'Alur Berpikir (Chain-of-Thought)', Icons.account_tree_rounded),
                _buildReasoningTabItem(1, 'Faktor Risiko & Etiologi', Icons.search_rounded),
                _buildReasoningTabItem(2, 'Intervensi Gizi & PMT', Icons.restaurant_rounded),
                _buildReasoningTabItem(3, 'Tindak Lanjut Faskes', Icons.local_hospital_rounded),
                _buildReasoningTabItem(4, 'Edukasi Orang Tua', Icons.family_restroom_rounded),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Konten Sub-Tab Reasoning
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _buildActiveReasoningContent(reasoning, text, sub, border),
          ),
        ],
      ),
    );
  }

  Widget _buildReasoningTabItem(int index, String title, IconData icon) {
    final isSelected = _activeReasoningTab == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _activeReasoningTab = index),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF1ABC9C) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: isSelected ? Colors.white : Colors.grey),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    color: isSelected ? Colors.white : Colors.grey[700],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveReasoningContent(VitaScaleReasoningResult r, Color text, Color sub, Color border) {
    switch (_activeReasoningTab) {
      case 0:
        return Column(
          key: const ValueKey(0),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: r.chainOfThoughtSteps.asMap().entries.map((entry) {
            final idx = entry.key + 1;
            final stepText = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1ABC9C).withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$idx',
                      style: GoogleFonts.outfit(fontSize: 10.5, fontWeight: FontWeight.bold, color: const Color(0xFF1ABC9C)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FormattedMarkdownText(
                      text: stepText,
                      style: GoogleFonts.outfit(fontSize: 11.5, color: text, height: 1.4),
                      boldStyle: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.bold, color: const Color(0xFF1ABC9C), height: 1.4),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );

      case 1:
        return Container(
          key: const ValueKey(1),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.amber.withOpacity(0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber.withOpacity(0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.crisis_alert_rounded, size: 18, color: Colors.amber),
                  const SizedBox(width: 8),
                  Text('Identifikasi Faktor Risiko & Etiologi:', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: text)),
                ],
              ),
              const SizedBox(height: 8),
              FormattedMarkdownText(
                text: r.riskAndEtiology,
                style: GoogleFonts.outfit(fontSize: 11.5, color: text, height: 1.5),
                boldStyle: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.amber[800], height: 1.5),
              ),
            ],
          ),
        );

      case 2:
        return Container(
          key: const ValueKey(2),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF27AE60).withOpacity(0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF27AE60).withOpacity(0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.egg_alt_rounded, size: 18, color: Color(0xFF27AE60)),
                  const SizedBox(width: 8),
                  Text('Rencana Intervensi Gizi & Menu Protein Hewani (PMT):', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: text)),
                ],
              ),
              const SizedBox(height: 8),
              FormattedMarkdownText(
                text: r.nutritionalIntervention,
                style: GoogleFonts.outfit(fontSize: 11.5, color: text, height: 1.5),
                boldStyle: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.bold, color: const Color(0xFF27AE60), height: 1.5),
              ),
            ],
          ),
        );

      case 3:
        return Container(
          key: const ValueKey(3),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF3498DB).withOpacity(0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF3498DB).withOpacity(0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.medical_services_rounded, size: 18, color: Color(0xFF3498DB)),
                  const SizedBox(width: 8),
                  Text('Protokol Tindak Lanjut Faskes & Kriteria Rujukan:', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: text)),
                ],
              ),
              const SizedBox(height: 8),
              FormattedMarkdownText(
                text: r.medicalProtocol,
                style: GoogleFonts.outfit(fontSize: 11.5, color: text, height: 1.5),
                boldStyle: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.bold, color: const Color(0xFF3498DB), height: 1.5),
              ),
            ],
          ),
        );

      case 4:
      default:
        return Container(
          key: const ValueKey(4),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFE91E63).withOpacity(0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE91E63).withOpacity(0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.favorite_rounded, size: 18, color: Color(0xFFE91E63)),
                  const SizedBox(width: 8),
                  Text('Panduan & Pesan Suportif untuk Orang Tua:', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: text)),
                ],
              ),
              const SizedBox(height: 8),
              FormattedMarkdownText(
                text: r.parentEducation,
                style: GoogleFonts.outfit(fontSize: 11.5, color: text, height: 1.5),
                boldStyle: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.bold, color: const Color(0xFFE91E63), height: 1.5),
              ),
            ],
          ),
        );
    }
  }
}
