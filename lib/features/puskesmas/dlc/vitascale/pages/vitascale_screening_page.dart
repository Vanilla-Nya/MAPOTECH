import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapotech/features/landing/landing_page_data.dart';
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

  const VitaScaleScreeningPage({
    super.key,
    this.selectedChild,
  });

  @override
  ConsumerState<VitaScaleScreeningPage> createState() => _VitaScaleScreeningPageState();
}

class _VitaScaleScreeningPageState extends ConsumerState<VitaScaleScreeningPage> {
  // Mode Tab: 0 = Input Manual & AI Reasoning (Uji Ukur), 1 = Perangkat IoT & Webcam CV
  int _activeTab = 0;

  // Simulator & Repo untuk Mode IoT
  late final VitaScaleDeviceSimulator _simulator;
  final VitaScaleRepository _repository = VitaScaleRepository();
  final TextEditingController _notesController = TextEditingController();

  List<ChildProfile> _availableChildren = [];
  ChildProfile? _activeChild;

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

  // Input Longitudinal (2 Bulan)
  bool _useLongitudinal = false;
  final TextEditingController _prevWeightController = TextEditingController(text: '11.0');
  final TextEditingController _prevHeightController = TextEditingController(text: '83.5');
  final TextEditingController _prevZsTbuController = TextEditingController(text: '-0.8');
  final TextEditingController _prevZsBbtbController = TextEditingController(text: '-0.4');
  String _naikBbCurr = 'Ya';

  int _selectedGender = 0; // 0 = Laki-laki, 1 = Perempuan
  double _ageMonths = 24.0;

  // Server health state
  bool _isCheckingServer = false;
  Map<String, dynamic>? _serverStatus;

  // Prediction & Reasoning State
  bool _isLoadingClassification = false;
  HasilSmartGrowthBalita? _smartGrowthResult;
  HasilPrediksiLongitudinal? _longitudinalResult;

  bool _isLoadingReasoning = false;
  VitaScaleReasoningResult? _reasoningResult;
  int _activeReasoningTab = 0;

  @override
  void initState() {
    super.initState();
    _simulator = VitaScaleDeviceSimulator(
      stateMachine: ref.read(screeningStateProvider.notifier),
    );

    _initSession();
    _checkServer();
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
        _activeChild = widget.selectedChild ?? (list.isNotEmpty ? list.first : null);
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
      _nameController.text = child.name;
      _nikController.text = child.nik;
      _selectedGender = child.gender == 'L' ? 0 : 1;
      _ageMonths = child.ageInMonths.toDouble();
      _ageController.text = child.ageInMonths.toString();

      // Estimasi default BB & TB realistis jika baru pertama diinput
      if (child.isUnder24Months) {
        _weightController.text = '9.5';
        _heightController.text = '76.0';
      } else {
        _weightController.text = '12.0';
        _heightController.text = '88.0';
      }
    });
  }

  @override
  void dispose() {
    _simulator.dispose();
    _notesController.dispose();
    _nameController.dispose();
    _nikController.dispose();
    _ageController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _waistController.dispose();
    _lilaController.dispose();
    _prevWeightController.dispose();
    _prevHeightController.dispose();
    _prevZsTbuController.dispose();
    _prevZsBbtbController.dispose();
    super.dispose();
  }

  // ===========================================================================
  // PRESET UJI CEPAT
  // ===========================================================================
  void _applyPreset(String label, {required int jk, required double usia, required double bb, required double tb}) {
    setState(() {
      _selectedGender = jk;
      _ageMonths = usia;
      _ageController.text = usia.toStringAsFixed(0);
      _weightController.text = bb.toStringAsFixed(1);
      _heightController.text = tb.toStringAsFixed(1);
    });

    CustomSnackbar.info(
      context,
      'Data preset "$label" telah dimuat: JK ${jk == 0 ? "L" : "P"}, Usia $usia bln, BB $bb kg, TB $tb cm.',
      title: 'Preset Uji Dimuat',
    );
  }

  // ===========================================================================
  // EKSEKUSI KLASIFIKASI MODEL MLP & REASONING MODEL
  // ===========================================================================
  Future<void> _runClassification() async {
    final bb = double.tryParse(_weightController.text.trim());
    final tb = double.tryParse(_heightController.text.trim());

    if (bb == null || bb <= 0 || tb == null || tb <= 0) {
      CustomSnackbar.warning(
        context,
        'Harap masukkan angka Berat Badan dan Tinggi Badan yang valid.',
        title: 'Input Tidak Lengkap',
      );
      return;
    }

    setState(() {
      _isLoadingClassification = true;
      _smartGrowthResult = null;
      _longitudinalResult = null;
      _reasoningResult = null;
    });

    try {
      if (_useLongitudinal) {
        // Model Longitudinal (2 Bulan)
        final prevBb = double.tryParse(_prevWeightController.text.trim()) ?? (bb - 0.3);
        final prevTb = double.tryParse(_prevHeightController.text.trim()) ?? (tb - 1.0);
        final prevZsTbu = double.tryParse(_prevZsTbuController.text.trim()) ?? -1.0;
        final prevZsBbtb = double.tryParse(_prevZsBbtbController.text.trim()) ?? -0.5;
        final lila = double.tryParse(_lilaController.text.trim()) ?? 14.0;

        final inputLong = InputPrediksiLongitudinal(
          beratPrev: prevBb,
          tinggiPrev: prevTb,
          zsTbuPrev: prevZsTbu,
          zsBbtbPrev: prevZsBbtb,
          jk: _selectedGender == 0 ? 'L' : 'P',
          usiaBulanCurr: _ageMonths,
          beratCurr: bb,
          tinggiCurr: tb,
          lilaCurr: lila,
          zsTbuCurr: prevZsTbu + 0.1,
          zsBbtbCurr: prevZsBbtb + 0.1,
          naikBbCurr: _naikBbCurr,
        );

        final result = await VitaScaleApiService.prediksiLongitudinal(inputLong);
        setState(() {
          _longitudinalResult = result;
          _isLoadingClassification = false;
        });

        // Buat dummy SmartGrowth adapter untuk reasoning
        final adapter = HasilSmartGrowthBalita(
          kategoriGiziBbtb: result.statusGizi,
          kategoriStuntingTbu: result.statusStunting,
          confidenceBbtb: result.confidenceGizi,
          confidenceTbu: result.confidenceStunting,
          probabilitasBbtb: {'Gizi Buruk/Kurang': result.probabilitasGiziBuruk, 'Gizi Normal': 1 - result.probabilitasGiziBuruk},
          probabilitasTbu: {'Stunting': result.probabilitasStunting, 'Normal': 1 - result.probabilitasStunting},
          isStunting: result.risikoStunting,
          isGiziBurukAtauKurang: result.risikoGiziBuruk,
          inputDiproses: result.inputDiproses,
        );

        _runReasoning(adapter, bb, tb);
      } else {
        // Model Smart Growth (4 Fitur Antropometri Utama)
        final inputSG = InputSmartGrowthBalita(
          jk: _selectedGender,
          usiaBulan: _ageMonths,
          berat: bb,
          tinggi: tb,
        );

        final result = await VitaScaleApiService.prediksiSmartGrowth(inputSG);
        setState(() {
          _smartGrowthResult = result;
          _isLoadingClassification = false;
        });

        _runReasoning(result, bb, tb);
      }

      if (mounted) {
        CustomSnackbar.success(
          context,
          'Klasifikasi model MLP selesai! Reasoning model sedang memproses penalaran klinis...',
          title: 'Prediksi Berhasil',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingClassification = false);
        CustomSnackbar.error(
          context,
          'Gagal menghubungkan ke backend FastAPI: $e\nPastikan python main.py berjalan di ${VitaScaleApiConfig.baseUrl}',
          title: 'Koneksi API Gagal',
        );
      }
    }
  }

  Future<void> _runReasoning(HasilSmartGrowthBalita mlpResult, double bb, double tb) async {
    setState(() => _isLoadingReasoning = true);

    final waist = double.tryParse(_waistController.text.trim());
    final lila = double.tryParse(_lilaController.text.trim());

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
      );

      if (mounted) {
        setState(() {
          _reasoningResult = reasoning;
          _isLoadingReasoning = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingReasoning = false);
      }
    }
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
              hintText: 'http://127.0.0.1:8000',
              controller: urlCtrl,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
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
                  setState(() => _activeChild = child);
                  _fillFormWithChild(child);

                  final state = ref.read(landingPageProvider);
                  final facilityId = state.activePuskesmasId ?? 'PUSKESMAS-001';
                  ref.read(screeningStateProvider.notifier).startSession(
                        child: child,
                        facilityId: facilityId,
                        isDemo: true,
                      );
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
    if (_smartGrowthResult == null && _longitudinalResult == null) return;

    final bb = _weightController.text;
    final tb = _heightController.text;
    final name = _nameController.text;
    final age = _ageMonths.toStringAsFixed(0);
    final gender = _selectedGender == 0 ? 'Laki-laki' : 'Perempuan';

    final gizi = _smartGrowthResult?.kategoriGiziBbtb ?? _longitudinalResult?.statusGizi ?? '-';
    final stunting = _smartGrowthResult?.kategoriStuntingTbu ?? _longitudinalResult?.statusStunting ?? '-';
    final confGizi = _smartGrowthResult?.confidenceBbtb ?? _longitudinalResult?.confidenceGizi ?? 0.0;
    final confStunt = _smartGrowthResult?.confidenceTbu ?? _longitudinalResult?.confidenceStunting ?? 0.0;

    final reasoning = _reasoningResult;

    final report = '''
==================================================
LAPORAN SKRINING VITASCALE AI & CLINICAL REASONING
==================================================
Nama Balita   : $name
NIK           : ${_nikController.text}
Jenis Kelamin : $gender
Usia          : $age Bulan
Berat Badan   : $bb kg
Tinggi Badan  : $tb cm

[HASIL KLASIFIKASI MODEL MLP KERAS]
Status Gizi (BB/TB)     : $gizi (Confidence: ${confGizi.toStringAsFixed(1)}%)
Status Stunting (TB/U)  : $stunting (Confidence: ${confStunt.toStringAsFixed(1)}%)
Indikasi Stunting       : ${_smartGrowthResult?.isStunting == true ? 'YA' : 'TIDAK'}
Indikasi Gizi Kurang    : ${_smartGrowthResult?.isGiziBurukAtauKurang == true ? 'YA' : 'TIDAK'}

[CLINICAL AI REASONING - GEMINI]
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
''';

    Clipboard.setData(ClipboardData(text: report));
    CustomSnackbar.success(
      context,
      'Laporan klinis lengkap dan alur reasoning berhasil disalin ke clipboard.',
      title: 'Tersalin ke Clipboard',
    );
  }

  @override
  Widget build(BuildContext context) {
    final screeningState = ref.watch(screeningStateProvider);
    final notifier = ref.read(landingPageProvider.notifier);

    final cardBgColor = notifier.getCardColor();
    final textColor = notifier.getTextColor();
    final subtitleColor = notifier.getBodyTextColor();
    final borderColor = notifier.getBorderColor();
    final isMobile = MediaQuery.of(context).size.width < 900;

    final session = screeningState.session;

    return VitaScaleDlcGate(
      menuTitle: 'Screening Anak & Bayi',
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
                                'MODUL SKRINING ANTROPOMETRI & AI',
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
                          'Uji Ukur & Skrining Antropometri Balita',
                          style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w900, color: textColor),
                        ),
                        Text(
                          'Klasifikasi Machine Learning (Keras MLP) & Clinical AI Reasoning Dokter Spesialis Anak.',
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
            // KONTEN TAB 0: UJI UKUR MANUAL & REASONING AI
            // =================================================================
            if (_activeTab == 0) ...[
              _buildServerStatusBar(cardBgColor, borderColor, textColor, subtitleColor),
              const SizedBox(height: 16),
              _buildManualInputForm(cardBgColor, borderColor, textColor, subtitleColor, isMobile),
              const SizedBox(height: 20),

              // Hasil Klasifikasi MLP
              if (_smartGrowthResult != null || _longitudinalResult != null) ...[
                _buildMlpClassificationResult(cardBgColor, borderColor, textColor, subtitleColor, isMobile),
                const SizedBox(height: 20),
              ],

              // Hasil Reasoning Model
              if (_isLoadingReasoning || _reasoningResult != null) ...[
                _buildReasoningSection(cardBgColor, borderColor, textColor, subtitleColor, isMobile),
                const SizedBox(height: 20),
              ],
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
                            height: 180,
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
                            height: 180,
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
                      isOnline ? 'FastAPI VitaScale Backend: TERHUBUNG' : 'FastAPI VitaScale Backend: TIDAK TERHUBUNG',
                      style: GoogleFonts.outfit(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: statusColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '(${VitaScaleApiConfig.baseUrl})',
                      style: GoogleFonts.outfit(fontSize: 10.5, color: sub),
                    ),
                  ],
                ),
                Text(
                  isOnline
                      ? 'Model Keras MLP stunting, gizi buruk, & Smart Growth siap melakukan inferensi real-time.'
                      : 'Jalankan server lokal dengan: python main.py di folder backend (Port 8000).',
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
  // FORM INPUT MANUAL UJI UKUR
  // ===========================================================================
  Widget _buildManualInputForm(Color cardBg, Color border, Color text, Color sub, bool isMobile) {
    final isUnder24 = _ageMonths < 24;

    return CustomCard(
      color: cardBg,
      borderColor: border,
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Card Input & Presets
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1ABC9C).withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.edit_note_rounded, size: 20, color: Color(0xFF1ABC9C)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Input Antropometri Sasaran (Pengujian Manual)',
                      style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w800, color: text),
                    ),
                    Text(
                      'Uji coba klasifikasi stunting & status gizi balita tanpa menunggu sensor fisik terpasang.',
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

          // Preset Cepat Bar
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('Preset Uji Cepat:', style: GoogleFonts.outfit(fontSize: 10.5, fontWeight: FontWeight.bold, color: sub)),
              _buildPresetChip('Balita Normal (24 bln)', () => _applyPreset('Normal', jk: 0, usia: 24, bb: 11.5, tb: 85.0)),
              _buildPresetChip('Risiko Stunting (24 bln)', () => _applyPreset('Stunting', jk: 0, usia: 24, bb: 9.2, tb: 76.0)),
              _buildPresetChip('Gizi Kurang (18 bln)', () => _applyPreset('Gizi Kurang', jk: 1, usia: 18, bb: 7.8, tb: 79.0)),
              _buildPresetChip('Bayi Telentang (8 bln)', () => _applyPreset('Bayi 8 Bln', jk: 0, usia: 8, bb: 8.2, tb: 70.0)),
            ],
          ),

          const Divider(height: 24),

          // Baris 1: Nama & NIK
          Row(
            children: [
              Expanded(
                flex: 2,
                child: CustomTextField(
                  label: 'Nama Lengkap Balita',
                  hintText: 'Nama anak',
                  controller: _nameController,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: CustomTextField(
                  label: 'NIK (Opsional)',
                  hintText: '16 digit NIK',
                  controller: _nikController,
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
                          label: isUnder24 ? 'PB Telentang (<24 Bln)' : 'TB Berdiri (≥24 Bln)',
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
                                setState(() => _ageMonths = numVal);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildStepperBtn(Icons.add, () {
                          setState(() {
                            _ageMonths += 1;
                            _ageController.text = _ageMonths.toStringAsFixed(0);
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

          // Baris 3: Berat Badan & Tinggi Badan
          Row(
            children: [
              // Berat Badan (kg)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Berat Badan Saat Ini (kg)',
                      style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700, color: text),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _buildStepperBtn(Icons.remove, () {
                          final current = double.tryParse(_weightController.text) ?? 10.0;
                          if (current > 1.0) {
                            setState(() => _weightController.text = (current - 0.1).toStringAsFixed(1));
                          }
                        }),
                        const SizedBox(width: 8),
                        Expanded(
                          child: CustomTextField(
                            label: '',
                            hintText: 'Contoh: 11.5',
                            controller: _weightController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildStepperBtn(Icons.add, () {
                          final current = double.tryParse(_weightController.text) ?? 10.0;
                          setState(() => _weightController.text = (current + 0.1).toStringAsFixed(1));
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
                    Text(
                      isUnder24 ? 'Panjang Badan Telentang (cm)' : 'Tinggi Badan Berdiri (cm)',
                      style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700, color: text),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _buildStepperBtn(Icons.remove, () {
                          final current = double.tryParse(_heightController.text) ?? 80.0;
                          if (current > 30.0) {
                            setState(() => _heightController.text = (current - 0.5).toStringAsFixed(1));
                          }
                        }),
                        const SizedBox(width: 8),
                        Expanded(
                          child: CustomTextField(
                            label: '',
                            hintText: 'Contoh: 85.0',
                            controller: _heightController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildStepperBtn(Icons.add, () {
                          final current = double.tryParse(_heightController.text) ?? 80.0;
                          setState(() => _heightController.text = (current + 0.5).toStringAsFixed(1));
                        }),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Baris 4: Parameter Tambahan (Lingkar Perut & LiLA)
          Row(
            children: [
              Expanded(
                child: CustomTextField(
                  label: 'Lingkar Perut (cm) — Opsional',
                  hintText: 'Contoh: 46.0',
                  controller: _waistController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: CustomTextField(
                  label: 'LiLA / Lingkar Lengan Atas (cm) — Opsional',
                  hintText: 'Contoh: 14.5',
                  controller: _lilaController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Toggle Mode Longitudinal
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: border.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: border),
            ),
            child: Row(
              children: [
                Checkbox(
                  value: _useLongitudinal,
                  activeColor: const Color(0xFF1ABC9C),
                  onChanged: (val) => setState(() => _useLongitudinal = val ?? false),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Uji Model Longitudinal (Data Riwayat Bulan Lalu)',
                        style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.bold, color: text),
                      ),
                      Text(
                        'Aktifkan jika ingin menguji endpoint /prediksi dengan fitur 2 bulan berurutan (Prev & Curr).',
                        style: GoogleFonts.outfit(fontSize: 9.5, color: sub),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Field Tambahan Longitudinal Jika Aktif
          if (_useLongitudinal) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF3498DB).withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF3498DB).withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Data Pengukuran Bulan Sebelumnya (Prev)',
                    style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF3498DB)),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: CustomTextField(
                          label: 'Berat Lalu (kg)',
                          hintText: '11.0',
                          controller: _prevWeightController,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: CustomTextField(
                          label: 'Tinggi Lalu (cm)',
                          hintText: '83.5',
                          controller: _prevHeightController,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: CustomTextField(
                          label: 'ZS TB/U Lalu',
                          hintText: '-0.8',
                          controller: _prevZsTbuController,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: CustomTextField(
                          label: 'ZS BB/TB Lalu',
                          hintText: '-0.4',
                          controller: _prevZsBbtbController,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Naik BB?', style: GoogleFonts.outfit(fontSize: 10.5, color: sub)),
                            const SizedBox(height: 4),
                            DropdownButton<String>(
                              value: _naikBbCurr,
                              isExpanded: true,
                              items: const [
                                DropdownMenuItem(value: 'Ya', child: Text('Ya')),
                                DropdownMenuItem(value: 'Tidak', child: Text('Tidak')),
                              ],
                              onChanged: (val) => setState(() => _naikBbCurr = val ?? 'Ya'),
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

          const SizedBox(height: 20),

          // Tombol Jalankan Prediksi MLP
          CustomButton(
            text: _isLoadingClassification
                ? 'Model MLP Sedang Melakukan Inferensi...'
                : 'Jalankan Klasifikasi VitaScale AI (MLP)',
            icon: Icons.psychology_rounded,
            height: 48,
            primaryColor: const Color(0xFF1ABC9C),
            onPressed: () {
              if (!_isLoadingClassification) {
                _runClassification();
              }
            },
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

  // ===========================================================================
  // HASIL KLASIFIKASI MODEL MLP
  // ===========================================================================
  Widget _buildMlpClassificationResult(Color cardBg, Color border, Color text, Color sub, bool isMobile) {
    final sg = _smartGrowthResult;
    final lg = _longitudinalResult;

    final kategoriGizi = sg?.kategoriGiziBbtb ?? lg?.statusGizi ?? 'Gizi Normal';
    final kategoriStunting = sg?.kategoriStuntingTbu ?? lg?.statusStunting ?? 'Normal';
    final confGizi = sg?.confidenceBbtb ?? lg?.confidenceGizi ?? 0.0;
    final confStunt = sg?.confidenceTbu ?? lg?.confidenceStunting ?? 0.0;

    final isStunting = sg?.isStunting ?? lg?.risikoStunting ?? false;
    final isGiziKurang = sg?.isGiziBurukAtauKurang ?? lg?.risikoGiziBuruk ?? false;

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
    if (_isLoadingReasoning) {
      return CustomCard(
        color: cardBg,
        borderColor: border,
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            const CircularProgressIndicator(color: Color(0xFF1ABC9C), strokeWidth: 3),
            const SizedBox(height: 18),
            Text(
              'Clinical Reasoning Engine Sedang Bekerja...',
              style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: text),
            ),
            const SizedBox(height: 4),
            Text(
              'Model Penalaran Klinis AI (Gemini 2.5 Flash) sedang menyusun alur berpikir medis, '
              'analisis faktor risiko, dan rencana intervensi nutrisi sesuai standar WHO/Kemenkes RI.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(fontSize: 11, color: sub),
            ),
          ],
        ),
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
                text: 'Analisis Ulang',
                icon: Icons.refresh_rounded,
                height: 34,
                primaryColor: const Color(0xFF1ABC9C),
                isSecondary: true,
                onPressed: () {
                  final bb = double.tryParse(_weightController.text) ?? 10.0;
                  final tb = double.tryParse(_heightController.text) ?? 80.0;
                  if (_smartGrowthResult != null) {
                    _runReasoning(_smartGrowthResult!, bb, tb);
                  }
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
                  child: Text(
                    reasoning.reasoningSummary,
                    style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.w600, color: text, height: 1.4),
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
                    child: Text(
                      stepText,
                      style: GoogleFonts.outfit(fontSize: 11.5, color: text, height: 1.4),
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
              Text(
                r.riskAndEtiology,
                style: GoogleFonts.outfit(fontSize: 11.5, color: text, height: 1.5),
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
              Text(
                r.nutritionalIntervention,
                style: GoogleFonts.outfit(fontSize: 11.5, color: text, height: 1.5),
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
              Text(
                r.medicalProtocol,
                style: GoogleFonts.outfit(fontSize: 11.5, color: text, height: 1.5),
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
              Text(
                r.parentEducation,
                style: GoogleFonts.outfit(fontSize: 11.5, color: text, height: 1.5),
              ),
            ],
          ),
        );
    }
  }
}
