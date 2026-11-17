import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapotech/features/landing/landing_page_data.dart';
import 'package:mapotech/features/puskesmas/dashboard/frontend/puskesmas_pantauan_ibu_hamil.dart';
import 'package:mapotech/shared/satusehat_service.dart';
import 'package:mapotech/shared/widgets/ui.dart';

class PuskesmasFormIbuHamil extends ConsumerStatefulWidget {
  const PuskesmasFormIbuHamil({super.key});

  @override
  ConsumerState<PuskesmasFormIbuHamil> createState() =>
      _PuskesmasFormIbuHamilState();
}

class _PuskesmasFormIbuHamilState extends ConsumerState<PuskesmasFormIbuHamil> {
  final _formKey = GlobalKey<FormState>();

  int _step =
      1; // 1: Select Patient & Map, 2: Patient Info & History Table, 3: Form ANC 10T
  int _formStep = 1; // 1 to 6 inside Step 3 Form Stepper (1 card per step)
  IbuHamilModel? _selectedPatient;
  String _searchQuery = '';

  // Controllers Dasar ANC 10T
  final TextEditingController _nikController = TextEditingController(
    text: '3511084205940001',
  );
  final TextEditingController _namaController = TextEditingController(
    text: 'Siti Rahmawati',
  );
  final TextEditingController _tbController = TextEditingController(
    text: '158',
  );
  final TextEditingController _bbController = TextEditingController(text: '62');
  final TextEditingController _lilaController = TextEditingController(
    text: '24.5',
  );
  final TextEditingController _sistoleController = TextEditingController(
    text: '120',
  );
  final TextEditingController _diastoleController = TextEditingController(
    text: '80',
  );
  final TextEditingController _tfuController = TextEditingController(
    text: '26',
  );
  final TextEditingController _djjController = TextEditingController(
    text: '142',
  );
  final TextEditingController _hbController = TextEditingController(
    text: '11.5',
  );
  final TextEditingController _catatanController = TextEditingController(
    text: 'Janin tunggal hidup, presentasi kepala, DJJ teratur 142x/mnt.',
  );

  // Parameter Tambahan Buku KIA 2024 & SATUSEHAT RME
  String _trimester = 'Trimester 3';
  String _kunjungan = 'K4';
  bool _ttdDiberikan = true;
  bool _tripleEliminasiNonReaktif = true;
  bool _pemeriksaanDokterUsg =
      true; // Buku KIA 2024: Minimal 2x dokter (K1 & K5)

  String _golDarah = 'O+';
  String _proteinUrin = 'Negatif';
  String _glukosaUrin = 'Negatif';
  String _presentasiJanin = 'Kepala (Normal)';
  String _statusImunisasiT = 'T5 (Lengkap)';
  bool _imunisasiTdDiberikan = false;
  String _skorKspr = 'Risiko Rendah (KRR)';

  static const List<String> _ksprOptions = [
    'Risiko Rendah (KRR)',
    'Risiko Tinggi (KRT)',
    'Risiko Sangat Tinggi (KRST)',
  ];

  String _normalizeKspr(String? val) {
    if (val == null || val.isEmpty) return 'Risiko Rendah (KRR)';
    if (val.contains('Sangat') || val.contains('KRST'))
      return 'Risiko Sangat Tinggi (KRST)';
    if (val.contains('Tinggi') || val.contains('KRT'))
      return 'Risiko Tinggi (KRT)';
    return 'Risiko Rendah (KRR)';
  }

  // P4K (Program Perencanaan Persalinan dan Pencegahan Komplikasi - Buku KIA)
  final TextEditingController _p4kDonorController = TextEditingController(
    text: 'Budi Santoso (Gol. O+)',
  );
  String _p4kTempatBersalin = 'Puskesmas';
  String _p4kPenolong = 'Bidan & Dokter Puskesmas';
  String _p4kRencanaKb = 'IUD Pasca Persalinan';

  // SATUSEHAT RME State
  bool _isCheckingSatuSehat = false;
  String? _satuSehatPatientId;
  bool _isSyncingSatuSehat = false;
  Map<String, dynamic>? _satuSehatSyncResult;

  void _onFieldChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _tbController.addListener(_onFieldChanged);
    _bbController.addListener(_onFieldChanged);
    _lilaController.addListener(_onFieldChanged);
    _sistoleController.addListener(_onFieldChanged);
    _diastoleController.addListener(_onFieldChanged);
    _tfuController.addListener(_onFieldChanged);
    _djjController.addListener(_onFieldChanged);
    _hbController.addListener(_onFieldChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final preselected = ref.read(selectedIbuHamilProvider);
      if (preselected != null && mounted) {
        _selectPatient(preselected, targetStep: 2);
      }
    });
  }

  @override
  void dispose() {
    _tbController.removeListener(_onFieldChanged);
    _bbController.removeListener(_onFieldChanged);
    _lilaController.removeListener(_onFieldChanged);
    _sistoleController.removeListener(_onFieldChanged);
    _diastoleController.removeListener(_onFieldChanged);
    _tfuController.removeListener(_onFieldChanged);
    _djjController.removeListener(_onFieldChanged);
    _hbController.removeListener(_onFieldChanged);

    _nikController.dispose();
    _namaController.dispose();
    _tbController.dispose();
    _bbController.dispose();
    _lilaController.dispose();
    _sistoleController.dispose();
    _diastoleController.dispose();
    _tfuController.dispose();
    _djjController.dispose();
    _hbController.dispose();
    _catatanController.dispose();
    _p4kDonorController.dispose();
    super.dispose();
  }

  void _selectPatient(IbuHamilModel patient, {int targetStep = 2}) {
    setState(() {
      _selectedPatient = patient;
      _nikController.text = patient.nik;
      _namaController.text = patient.nama;
      _trimester = patient.trimester;
      _kunjungan = patient.ancStatus.startsWith('K')
          ? patient.ancStatus.split(' ').first
          : 'K4';
      _lilaController.text = patient.lila.replaceAll(RegExp(r'[^0-9.]'), '');
      _hbController.text = patient.hb.replaceAll(RegExp(r'[^0-9.]'), '');
      _skorKspr = _normalizeKspr(patient.ksprStatus);
      _satuSehatPatientId = null;
      _satuSehatSyncResult = null;
      _formStep = 1;
      _step = targetStep; // Proceed to target step (default 2)
    });
    ref.read(selectedIbuHamilProvider.notifier).state = patient;
  }

  void _clearSelectedPatient() {
    setState(() {
      _selectedPatient = null;
      _step = 1;
      _formStep = 1;
      _satuSehatPatientId = null;
      _satuSehatSyncResult = null;
    });
    ref.read(selectedIbuHamilProvider.notifier).state = null;
    CustomSnackbar.info(
      context,
      'Pilihan pasien telah dihapus. Silakan pilih pasien dari peta geotagging atau daftar.',
      title: 'Pilihan Dihapus',
    );
  }

  // ===========================================================================
  // HELPER KALKULASI KLINIS BUKU KIA 2024
  // ===========================================================================
  double? get _calculatedImt {
    final bb = double.tryParse(_bbController.text.trim());
    final tb = double.tryParse(_tbController.text.trim());
    if (bb != null && tb != null && tb > 0 && bb > 0) {
      final hMeter = tb / 100.0;
      return bb / (hMeter * hMeter);
    }
    return null;
  }

  double? get _calculatedTbj {
    final tfu = double.tryParse(_tfuController.text.trim());
    if (tfu != null && tfu > 12) {
      // Rumus Johnson-Toshack Buku KIA (kepala belum masuk PAP n=12, masuk PAP n=11)
      final n = _presentasiJanin.contains('Kepala') ? 12 : 12;
      return (tfu - n) * 155.0;
    }
    return null;
  }

  bool get _isKek {
    final lila = double.tryParse(_lilaController.text.trim());
    return lila != null && lila > 0 && lila < 23.5;
  }

  bool get _isAnemia {
    final hb = double.tryParse(_hbController.text.trim());
    return hb != null && hb > 0 && hb < 11.0;
  }

  bool get _isPreeklamsiaRisk {
    final sis = double.tryParse(_sistoleController.text.trim()) ?? 0;
    final dia = double.tryParse(_diastoleController.text.trim()) ?? 0;
    final hasProteinUrin = _proteinUrin != 'Negatif';
    return sis >= 140 || dia >= 90 || hasProteinUrin;
  }

  // ===========================================================================
  // CLINICAL CHIP / BADGE BUILDERS (STANDAR BUKU KIA 2024 - TOP CHIPS)
  // ===========================================================================
  Widget? get _lilaStatusBadge {
    final lila = double.tryParse(_lilaController.text.trim());
    if (lila == null || lila <= 0) return null;

    final String text;
    final Color color;
    final IconData icon;
    final String tooltip;

    if (lila < 23.5) {
      text = 'Status Gizi: KEK (${lila.toStringAsFixed(1)} cm)';
      color = const Color(0xFFE74C3C); // 🔴 Merah / KEK
      icon = Icons.warning_rounded;
      tooltip =
          'Kurang Energi Kronis (LiLA < 23.5 cm - ICD-10 O25). Berisiko BBLR & Stunting. Wajib PMT & rujukan Ahli Gizi.';
    } else if (lila < 24.5) {
      text = 'Status Gizi: Waspada (${lila.toStringAsFixed(1)} cm)';
      color = const Color(0xFFF39C12); // 🟡 Kuning / Ambang Batas
      icon = Icons.warning_amber_rounded;
      tooltip =
          'Ambang Batas KEK (LiLA 23.5 - 24.4 cm). Waspadai penurunan asupan gizi, pantau konsumsi protein hewani.';
    } else {
      text = 'Status Gizi: Normal (${lila.toStringAsFixed(1)} cm)';
      color = const Color(0xFF27AE60); // 🟢 Hijau / Baik
      icon = Icons.check_circle_rounded;
      tooltip =
          'Status Gizi Baik / Normal (LiLA ≥ 24.5 cm). Pertahankan asupan gizi seimbang.';
    }

    return Tooltip(
      message: tooltip,
      child: StatusBadge(
        label: text,
        color: color,
        icon: icon,
        fontSize: 10.5,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),
    );
  }

  Widget? get _imtStatusBadge {
    final imt = _calculatedImt;
    if (imt == null || imt <= 0) return null;

    final String text;
    final Color color;
    final IconData icon;
    final String tooltip;

    if (imt < 18.5) {
      text = 'IMT: ${imt.toStringAsFixed(1)} (Kurus)';
      color = const Color(0xFFF39C12); // 🟡 Kuning / Underweight
      icon = Icons.warning_amber_rounded;
      tooltip =
          'IMT < 18.5 kg/m²: Underweight. Kebutuhan peningkatan asupan nutrisi.';
    } else if (imt < 25.0) {
      text = 'IMT: ${imt.toStringAsFixed(1)} (Normal)';
      color = const Color(0xFF27AE60); // 🟢 Hijau / Normal
      icon = Icons.check_circle_rounded;
      tooltip = 'IMT 18.5 - 24.9 kg/m²: Status Gizi Normal.';
    } else if (imt < 30.0) {
      text = 'IMT: ${imt.toStringAsFixed(1)} (Overweight)';
      color = const Color(0xFFF39C12); // 🟡 Kuning / Overweight
      icon = Icons.warning_amber_rounded;
      tooltip = 'IMT 25.0 - 29.9 kg/m²: Kelebihan Berat Badan.';
    } else {
      text = 'IMT: ${imt.toStringAsFixed(1)} (Obesitas)';
      color = const Color(0xFFE74C3C); // 🔴 Merah / Obesitas
      icon = Icons.warning_rounded;
      tooltip =
          'IMT ≥ 30.0 kg/m²: Obesitas. Waspada diabetes gestasional & preeklamsia.';
    }

    return Tooltip(
      message: tooltip,
      child: StatusBadge(
        label: text,
        color: color,
        icon: icon,
        fontSize: 10.5,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),
    );
  }

  Widget? get _tdStatusBadge {
    final sis = double.tryParse(_sistoleController.text.trim());
    final dia = double.tryParse(_diastoleController.text.trim());
    if (sis == null || dia == null || sis <= 0 || dia <= 0) return null;

    final hasProteinUrin = _proteinUrin != 'Negatif';
    final String text;
    final Color color;
    final IconData icon;
    final String tooltip;

    if (sis >= 140 || dia >= 90 || hasProteinUrin) {
      text =
          'TD: ${sis.toInt()}/${dia.toInt()} mmHg (${hasProteinUrin ? "Preeklamsia" : "Hipertensi"})';
      color = const Color(0xFFE74C3C); // 🔴 Merah / Bahaya
      icon = Icons.warning_rounded;
      tooltip =
          'Hipertensi Gestasional / Preeklamsia (TD ≥ 140/90 atau Protein Urin Positif - ICD-10 O14.9). Evaluasi segera!';
    } else if (sis >= 120 || dia >= 80) {
      text = 'TD: ${sis.toInt()}/${dia.toInt()} mmHg (Pre-Hipertensi)';
      color = const Color(0xFFF39C12); // 🟡 Kuning / Warning
      icon = Icons.warning_amber_rounded;
      tooltip =
          'Pre-Hipertensi (Sistole 120-139 atau Diastole 80-89 mmHg). Perlu pemantauan berkala & istirahat cukup.';
    } else {
      text = 'TD: ${sis.toInt()}/${dia.toInt()} mmHg (Normal)';
      color = const Color(0xFF27AE60); // 🟢 Hijau / Normal
      icon = Icons.check_circle_rounded;
      tooltip = 'Tekanan Darah Normal (< 120/80 mmHg).';
    }

    return Tooltip(
      message: tooltip,
      child: StatusBadge(
        label: text,
        color: color,
        icon: icon,
        fontSize: 10.5,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),
    );
  }

  Widget? get _hbStatusBadge {
    final hb = double.tryParse(_hbController.text.trim());
    if (hb == null || hb <= 0) return null;

    final String text;
    final Color color;
    final IconData icon;
    final String tooltip;

    if (hb < 11.0) {
      text = 'Hb: ${hb.toStringAsFixed(1)} g/dL (Anemia)';
      color = const Color(0xFFE74C3C); // 🔴 Merah / Anemia
      icon = Icons.warning_rounded;
      tooltip =
          'Anemia Kehamilan (Hb < 11.0 g/dL - ICD-10 O99.0). Tingkatkan 2 tab TTD/hari & makanan tinggi zat besi.';
    } else if (hb < 12.0) {
      text = 'Hb: ${hb.toStringAsFixed(1)} g/dL (Waspada)';
      color = const Color(0xFFF39C12); // 🟡 Kuning / Ambang Batas
      icon = Icons.warning_amber_rounded;
      tooltip =
          'Kadar Hb Ambang Batas (11.0 - 11.9 g/dL). Teruskan minum rutin 1 tablet tambah darah/hari.';
    } else {
      text = 'Hb: ${hb.toStringAsFixed(1)} g/dL (Normal)';
      color = const Color(0xFF27AE60); // 🟢 Hijau / Normal
      icon = Icons.check_circle_rounded;
      tooltip = 'Kadar Hemoglobin Normal (Hb ≥ 12.0 g/dL).';
    }

    return Tooltip(
      message: tooltip,
      child: StatusBadge(
        label: text,
        color: color,
        icon: icon,
        fontSize: 10.5,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),
    );
  }

  Widget? get _djjStatusBadge {
    final djj = double.tryParse(_djjController.text.trim());
    if (djj == null || djj <= 0) return null;

    final bool isAbnormal = djj < 120 || djj > 160;
    return Tooltip(
      message: isAbnormal
          ? 'DJJ di luar batas normal (120 - 160 bpm). Waspada gawat janin!'
          : 'Denyut Jantung Janin Normal (120 - 160 bpm).',
      child: StatusBadge(
        label:
            'DJJ: ${djj.toInt()} bpm (${isAbnormal ? "Abnormal" : "Normal"})',
        color: isAbnormal ? const Color(0xFFE74C3C) : const Color(0xFF27AE60),
        icon: isAbnormal ? Icons.warning_rounded : Icons.favorite_rounded,
        fontSize: 10.5,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),
    );
  }

  Widget? get _tbjStatusBadge {
    final tbj = _calculatedTbj;
    if (tbj == null || tbj <= 0) return null;

    return Tooltip(
      message: 'Taksiran Berat Janin Rumus Johnson-Toshack Buku KIA',
      child: StatusBadge(
        label: 'TBJ: ~${tbj.toStringAsFixed(0)} gram',
        color: const Color(0xFF8E44AD),
        icon: Icons.child_care_rounded,
        fontSize: 10.5,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),
    );
  }

  SatuSehatService _getSatuSehatService() {
    final state = ref.read(landingPageProvider);
    return SatuSehatService(
      clientId:
          dotenv.env['SATUSEHAT_CLIENT_ID'] ?? dotenv.env['SATUSEHAT_CLIENTID'],
      clientSecret:
          dotenv.env['SATUSEHAT_CLIENT_SECRET'] ??
          dotenv.env['SATUSEHAT_CLIENTSECRET'],
      organizationId:
          dotenv.env['SATUSEHAT_ORG_ID'] ??
          state.activePuskesmasId ??
          '10000004',
      locationId:
          dotenv.env['SATUSEHAT_LOCATION_ID'] ??
          'b017aa54-f1df-4ec2-9529-81788148b1d9',
      env: dotenv.env['SATUSEHAT_ENV'] ?? 'stg',
    );
  }

  Future<void> _checkSatuSehatPatient() async {
    final nik = _nikController.text.trim();
    if (nik.length != 16) {
      CustomSnackbar.warning(
        context,
        'Harap masukkan 16 digit NIK Ibu Hamil yang valid.',
        title: 'NIK Tidak Valid',
      );
      return;
    }

    setState(() => _isCheckingSatuSehat = true);

    try {
      final ss = _getSatuSehatService();
      if (!ss.isConfigured()) {
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) {
          setState(() {
            _satuSehatPatientId = 'P${nik.substring(nik.length - 10)}';
            _isCheckingSatuSehat = false;
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
          _isCheckingSatuSehat = false;
          if (res['status'] == true && res['id'] != null) {
            _satuSehatPatientId = res['id'].toString();
          } else {
            _satuSehatPatientId = 'P${nik.substring(nik.length - 10)}';
          }
        });

        if (res['status'] == true) {
          CustomSnackbar.success(
            context,
            'Pasien Ibu Hamil terverifikasi di SATUSEHAT! IHS Number: $_satuSehatPatientId',
            title: 'SATUSEHAT Terhubung',
          );
        } else {
          CustomSnackbar.info(
            context,
            'Ibu Hamil belum terdaftar live (${res['message']}). Mode simulasi IHS diaktifkan: $_satuSehatPatientId',
            title: 'SATUSEHAT Sandbox',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCheckingSatuSehat = false;
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

  // ===========================================================================
  // VALIDASI FORM ANC 10T & REVIEW DIALOG (PRAKTIK DOKTER / PRIVATE PRACTICE MODEL)
  // ===========================================================================
  List<Map<String, dynamic>> _validateAncForm() {
    final issues = <Map<String, dynamic>>[];

    // --- STEP 1: IDENTITAS & ANC ---
    final nikVal = _nikController.text.trim();
    if (nikVal.isEmpty) {
      issues.add({
        'step': 1,
        'stepName': '1. Identitas & ANC',
        'field': 'NIK Ibu Hamil',
        'message': 'NIK Wajib Diisi (16 Digit)',
        'isError': true, // 🔴 Red Wajib
      });
    } else if (nikVal.length != 16 || !RegExp(r'^\d{16}$').hasMatch(nikVal)) {
      issues.add({
        'step': 1,
        'stepName': '1. Identitas & ANC',
        'field': 'NIK Ibu Hamil',
        'message': 'NIK Harus 16 Digit Angka Valid',
        'isError': true, // 🔴 Red Wajib
      });
    }

    if (_namaController.text.trim().isEmpty) {
      issues.add({
        'step': 1,
        'stepName': '1. Identitas & ANC',
        'field': 'Nama Pasien',
        'message': 'Nama Pasien Belum Diisi',
        'isError': true, // 🔴 Red Wajib
      });
    }

    if (_satuSehatPatientId == null) {
      issues.add({
        'step': 1,
        'stepName': '1. Identitas & ANC',
        'field': 'SATUSEHAT',
        'message': 'IHS SATUSEHAT Belum Diverifikasi',
        'isError': false, // 🟡 Yellow Opsional
      });
    }

    // --- STEP 2: ANTROPOMETRI & TENSI (1T-3T) ---
    final tb = double.tryParse(_tbController.text.trim());
    if (tb == null || tb <= 0) {
      issues.add({
        'step': 2,
        'stepName': '2. Antropometri & TD',
        'field': 'Tinggi Badan',
        'message': 'Tinggi Badan Belum Diisi',
        'isError': true, // 🔴 Red Wajib
      });
    }

    final bb = double.tryParse(_bbController.text.trim());
    if (bb == null || bb <= 0) {
      issues.add({
        'step': 2,
        'stepName': '2. Antropometri & TD',
        'field': 'Berat Badan',
        'message': 'Berat Badan Belum Diisi',
        'isError': true, // 🔴 Red Wajib
      });
    }

    final lila = double.tryParse(_lilaController.text.trim());
    if (lila == null || lila <= 0) {
      issues.add({
        'step': 2,
        'stepName': '2. Antropometri & TD',
        'field': 'LiLA',
        'message': 'Ukuran LiLA Belum Diisi',
        'isError': true, // 🔴 Red Wajib
      });
    }

    final sis = double.tryParse(_sistoleController.text.trim());
    final dia = double.tryParse(_diastoleController.text.trim());
    if (sis == null || sis <= 0 || dia == null || dia <= 0) {
      issues.add({
        'step': 2,
        'stepName': '2. Antropometri & TD',
        'field': 'Tekanan Darah',
        'message': 'Tekanan Darah (TD) Belum Lengkap',
        'isError': true, // 🔴 Red Wajib
      });
    }

    // --- STEP 3: JANIN & DJJ (4T-6T) ---
    final tfu = double.tryParse(_tfuController.text.trim());
    if (tfu == null || tfu <= 0) {
      issues.add({
        'step': 3,
        'stepName': '3. Janin & DJJ',
        'field': 'Tinggi Fundus Uteri',
        'message': 'TFU Belum Diisi',
        'isError': true, // 🔴 Red Wajib
      });
    }

    final djj = double.tryParse(_djjController.text.trim());
    if (djj == null || djj <= 0) {
      issues.add({
        'step': 3,
        'stepName': '3. Janin & DJJ',
        'field': 'Detak Jantung Janin',
        'message': 'DJJ Janin Belum Diisi',
        'isError': true, // 🔴 Red Wajib
      });
    }

    // --- STEP 4: LABORATORIUM & TTD (7T-8T) ---
    final hb = double.tryParse(_hbController.text.trim());
    if (hb == null || hb <= 0) {
      issues.add({
        'step': 4,
        'stepName': '4. Laboratorium',
        'field': 'Hemoglobin',
        'message': 'Kadar Hb Belum Diisi',
        'isError': true, // 🔴 Red Wajib
      });
    }

    if (!_tripleEliminasiNonReaktif) {
      issues.add({
        'step': 4,
        'stepName': '4. Laboratorium',
        'field': 'Triple Eliminasi',
        'message': 'Triple Eliminasi Belum Diverifikasi',
        'isError': false, // 🟡 Yellow Opsional
      });
    }

    // --- STEP 6: P4K & KONSELING (10T) ---
    if (_p4kDonorController.text.trim().isEmpty) {
      issues.add({
        'step': 6,
        'stepName': '6. P4K & Konseling',
        'field': 'Calon Pendonor',
        'message': 'Calon Pendonor Darah Belum Dicatat',
        'isError': false, // 🟡 Yellow Opsional
      });
    }

    if (_catatanController.text.trim().isEmpty) {
      issues.add({
        'step': 6,
        'stepName': '6. P4K & Konseling',
        'field': 'Temu Wicara',
        'message': 'Catatan Konseling Masih Kosong',
        'isError': false, // 🟡 Yellow Opsional
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
    final issues = _validateAncForm();
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
                  'Review & Validasi Form ANC 10T',
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
                          ? const Color(0xFF27AE60).withOpacity(0.1)
                          : const Color(0xFFE74C3C).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isFormLengkap
                            ? const Color(0xFF27AE60).withOpacity(0.3)
                            : const Color(0xFFE74C3C).withOpacity(0.3),
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
                                        ? '✅ Form Lengkap (Semua Data 10T Terpenuhi)'
                                        : '✅ Data Wajib Lengkap (${yellowWarnings.length} Saran Opsional)')
                                    : '❌ Form Belum Lengkap (${redErrors.length} Data Wajib Kurang)',
                                style: GoogleFonts.outfit(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: isFormLengkap ? const Color(0xFF27AE60) : const Color(0xFFE74C3C),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isFormLengkap
                                    ? 'Seluruh parameter klinis siap disimpan & disinkronkan ke SATUSEHAT RME.'
                                    : 'Klik chip merah di bawah untuk langsung menuju step yang belum lengkap.',
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
                      'Data Wajib Belum Diisi (Klik chip untuk menuju form):',
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
                          backgroundColor: const Color(0xFFE74C3C).withOpacity(0.08),
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
                      'Peringatan / Data Opsional (Klik chip untuk melengkapi):',
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
                          backgroundColor: const Color(0xFFF39C12).withOpacity(0.08),
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

                  // Ringkasan Data Pemeriksaan
                  _buildReviewSectionTitle('1. Pasien & ANC', textColor),
                  _buildReviewRow('Nama Pasien', _namaController.text, subtitleColor, textColor),
                  _buildReviewRow('NIK', _nikController.text, subtitleColor, textColor),
                  _buildReviewRow('Kunjungan', '$_kunjungan ($_trimester)', subtitleColor, textColor),

                  const SizedBox(height: 8),
                  _buildReviewSectionTitle('2. Antropometri & Tensi', textColor),
                  _buildReviewRow('Tinggi / Berat', '${_tbController.text} cm / ${_bbController.text} kg', subtitleColor, textColor),
                  _buildReviewRow('LiLA (Status Gizi)', '${_lilaController.text} cm (${_isKek ? "KEK" : "Normal"})', subtitleColor, textColor),
                  _buildReviewRow('Tekanan Darah', '${_sistoleController.text}/${_diastoleController.text} mmHg', subtitleColor, textColor),

                  const SizedBox(height: 8),
                  _buildReviewSectionTitle('3. Janin & Kebidanan', textColor),
                  _buildReviewRow('TFU / TBJ', '${_tfuController.text} cm / ~${_calculatedTbj?.toStringAsFixed(0) ?? "-"} g', subtitleColor, textColor),
                  _buildReviewRow('DJJ / Presentasi', '${_djjController.text} bpm / $_presentasiJanin', subtitleColor, textColor),

                  const SizedBox(height: 8),
                  _buildReviewSectionTitle('4. Laboratorium & Terapi', textColor),
                  _buildReviewRow('Hemoglobin (Hb)', '${_hbController.text} g/dL (${_isAnemia ? "Anemia" : "Normal"})', subtitleColor, textColor),
                  _buildReviewRow('Gol. Darah / Urin', '$_golDarah / Protein: $_proteinUrin', subtitleColor, textColor),
                  _buildReviewRow('Suplemen TTD', _ttdDiberikan ? 'Diberikan (90 Tab)' : 'Tidak', subtitleColor, textColor),

                  const SizedBox(height: 8),
                  _buildReviewSectionTitle('5. Skrining Risiko (KSPR)', textColor),
                  _buildReviewRow('Kategori KSPR', _skorKspr, subtitleColor, textColor, isBold: true),

                  const SizedBox(height: 8),
                  _buildReviewSectionTitle('6. Perencanaan P4K', textColor),
                  _buildReviewRow('Tempat / Penolong', '$_p4kTempatBersalin / $_p4kPenolong', subtitleColor, textColor),
                  _buildReviewRow('Rencana KB', _p4kRencanaKb, subtitleColor, textColor),
                  if (_catatanController.text.isNotEmpty)
                    _buildReviewRow('Catatan', _catatanController.text, subtitleColor, textColor),
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
                  _executeSaveForm();
                },
                icon: _isSyncingSatuSehat
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.cloud_upload_rounded, size: 16, color: Colors.white),
                label: Text(
                  'Konfirmasi & Simpan SatuSehat',
                  style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
          ],
        );
      },
    );
  }

  void _simpanForm() {
    _showReviewAndSubmitDialog();
  }

  Future<void> _executeSaveForm() async {
    final nikVal = _nikController.text.trim();
    if (nikVal.isNotEmpty &&
        (nikVal.length != 16 || !RegExp(r'^\d{16}$').hasMatch(nikVal))) {
      CustomSnackbar.error(
        context,
        'NIK Ibu Hamil harus 16 digit angka numerik valid.',
        title: 'Validasi NIK Gagal',
      );
      return;
    }

    final bb = double.tryParse(_bbController.text.trim()) ?? 0.0;
    final tb = double.tryParse(_tbController.text.trim()) ?? 0.0;
    final lila = double.tryParse(_lilaController.text.trim()) ?? 0.0;
    final sis = double.tryParse(_sistoleController.text.trim()) ?? 0.0;
    final dia = double.tryParse(_diastoleController.text.trim()) ?? 0.0;
    final tfu = double.tryParse(_tfuController.text.trim());
    final djj = double.tryParse(_djjController.text.trim());
    final hb = double.tryParse(_hbController.text.trim());

    if (bb <= 0 || tb <= 0 || lila <= 0 || sis <= 0 || dia <= 0) {
      CustomSnackbar.warning(
        context,
        'Harap lengkapi pengukuran wajib: BB, TB, LiLA, dan Tekanan Darah.',
        title: 'Data Belum Lengkap',
      );
      return;
    }

    setState(() => _isSyncingSatuSehat = true);

    final patientId =
        _satuSehatPatientId ??
        (nikVal.length == 16
            ? 'P${nikVal.substring(nikVal.length - 10)}'
            : 'P351108420594');
    final patientName = _namaController.text.trim().isEmpty
        ? 'Siti Rahmawati'
        : _namaController.text.trim();
    final encounterUuid = 'ENC-ANC-${DateTime.now().millisecondsSinceEpoch}';

    // Daftar Diagnosis Maternal ICD-10 berdasar hasil pemeriksaan Buku KIA
    final diagList = <Map<String, String>>[];
    if (_isPreeklamsiaRisk) {
      diagList.add({
        'code': 'O14.9',
        'description':
            'Preeclampsia, unspecified (Hipertensi Gestasional & Proteinuria)',
      });
    }
    if (_isKek) {
      diagList.add({
        'code': 'O25',
        'description':
            'Malnutrition in pregnancy (Kurang Energi Kronis - LiLA < 23.5 cm)',
      });
    }
    if (_isAnemia) {
      diagList.add({
        'code': 'O99.0',
        'description':
            'Anemia complicating pregnancy, childbirth and the puerperium (Hb < 11.0 g/dL)',
      });
    }
    if (_skorKspr.contains('Tinggi')) {
      diagList.add({
        'code': 'O09.9',
        'description':
            'Supervision of high-risk pregnancy, unspecified (KSPR KRT/KRST)',
      });
    }
    if (diagList.isEmpty) {
      diagList.add({
        'code': 'Z34.8',
        'description':
            'Supervision of other normal pregnancy (Kehamilan Normal $_kunjungan)',
      });
    }

    // Catat riwayat kunjungan ke Shared State Provider (Real-Time Sync Ponkesdes ↔ Puskesmas)
    final currentRole = ref.read(landingPageProvider).loggedInRole;
    final currentUserName =
        ref.read(landingPageProvider).loggedInName ?? 'Bidan Desa';
    final faskesName = currentRole == 'ponkesdes'
        ? (currentUserName.contains('Ponkesdes')
              ? currentUserName
              : 'Ponkesdes Sumber Wringin')
        : 'Puskesmas Sumber Wringin';

    final now = DateTime.now();
    final monthNamesId = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    final visitDateStr =
        '${now.day} ${monthNamesId[now.month - 1]} ${now.year}';
    final visitTimeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} WIB';

    final newVisitEntry = {
      'kunjungan': '$_kunjungan ($_trimester)',
      'date': visitDateStr,
      'time': visitTimeStr,
      'pemeriksa': '$currentUserName ($faskesName)',
      'td': '${sis.toInt()}/${dia.toInt()} mmHg',
      'djj': djj != null ? '${djj.toInt()} bpm (Normal)' : '140 bpm',
      'tfu': tfu != null ? '${tfu.toStringAsFixed(0)} cm' : '-',
      'bb_tb': '${bb.toStringAsFixed(1)} kg | ${tb.toStringAsFixed(0)} cm',
      'hb_lila':
          '${hb?.toStringAsFixed(1) ?? "-"} g/dL | ${lila.toStringAsFixed(1)} cm',
      'protein_urin': '$_proteinUrin | $_golDarah',
      'resep': _ttdDiberikan
          ? 'Tablet Tambah Darah (Fe 30 Tab), Kalsium 500mg'
          : 'Vitamin ANC',
      'catatan': _catatanController.text.trim().isEmpty
          ? 'Pemeriksaan antenatal care lengkap standar Buku KIA 2024.'
          : _catatanController.text.trim(),
      'faskes': faskesName,
    };

    ref
        .read(ibuHamilListProvider.notifier)
        .recordAncVisit(
          nik: nikVal,
          newVisit: newVisitEntry,
          newHb: hb != null ? '${hb.toStringAsFixed(1)} g/dL' : null,
          newLila: '${lila.toStringAsFixed(1)} cm',
          newAncStatus: '$_kunjungan Terpenuhi',
          newTrimester: _trimester,
          faskesPemeriksa: faskesName,
        );

    try {
      final ss = _getSatuSehatService();

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
              'kunjungan': _kunjungan,
              'diagnoses': diagList.map((d) => d['code']).join(', '),
            };
          });
          CustomSnackbar.success(
            context,
            'Pemeriksaan ANC 10T berhasil disimpan & divalidasi ke format FHIR R4 SATUSEHAT!',
            title: 'Tersimpan & Terverifikasi RME',
          );
        }
        return;
      }

      // Live SatuSehat call
      final headers = {'Content-Type': 'application/json'};
      final encRes = await ss.createEncounter(
        headers: headers,
        patientId: patientId,
        patientName: patientName,
        doctorId: '10000001',
        doctorName: 'Bidan / Dokter Puskesmas',
        encounterId: encounterUuid,
      );

      final ssEncounterId = encRes['data']?['id']?.toString() ?? encounterUuid;

      await ss.sendAntenatalCareData(
        patientId: patientId,
        patientName: patientName,
        doctorId: '10000001',
        doctorName: 'Bidan / Dokter Puskesmas',
        encounterId: ssEncounterId,
        weightKg: bb,
        heightCm: tb,
        lilaCm: lila,
        sistoleMmHg: sis,
        diastoleMmHg: dia,
        tfuCm: tfu,
        djjBpm: djj,
        hbGdl: hb,
        diagnosisList: diagList,
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
            'kunjungan': _kunjungan,
            'diagnoses': diagList.map((d) => d['code']).join(', '),
          };
        });
        CustomSnackbar.success(
          context,
          'Pemeriksaan ANC 10T berhasil terkirim ke SATUSEHAT RME Kemenkes RI!',
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
            'encounter_id': encounterUuid,
            'patient_id': patientId,
            'synced_at': DateTime.now().toIso8601String(),
            'kunjungan': _kunjungan,
            'diagnoses': diagList.map((d) => d['code']).join(', '),
            'note': e.toString(),
          };
        });
        CustomSnackbar.info(
          context,
          'Data ANC 10T berhasil disimpan dalam format standar FHIR R4.',
          title: 'Format RME Siap',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(landingPageProvider);
    final notifier = ref.read(landingPageProvider.notifier);

    // Sync from provider if newly selected or changed
    ref.listen<IbuHamilModel?>(selectedIbuHamilProvider, (previous, next) {
      if (next != null && next != _selectedPatient) {
        _selectPatient(next, targetStep: 2);
      } else if (next == null && _selectedPatient != null) {
        setState(() {
          _selectedPatient = null;
          _step = 1;
        });
      }
    });

    // Check if initial selection from provider exists and hasn't been set yet
    final currentSelectedInProvider = ref.watch(selectedIbuHamilProvider);
    if (currentSelectedInProvider != null && _selectedPatient == null) {
      _selectedPatient = currentSelectedInProvider;
      _nikController.text = currentSelectedInProvider.nik;
      _namaController.text = currentSelectedInProvider.nama;
      _trimester = currentSelectedInProvider.trimester;
      _kunjungan = currentSelectedInProvider.ancStatus.startsWith('K')
          ? currentSelectedInProvider.ancStatus.split(' ').first
          : 'K4';
      _lilaController.text = currentSelectedInProvider.lila.replaceAll(
        RegExp(r'[^0-9.]'),
        '',
      );
      _hbController.text = currentSelectedInProvider.hb.replaceAll(
        RegExp(r'[^0-9.]'),
        '',
      );
      _skorKspr = _normalizeKspr(currentSelectedInProvider.ksprStatus);
      _step = 2;
    }

    final isDark = state.appearance == 'dark';
    final cardBgColor = notifier.getCardColor();
    final textColor = notifier.getTextColor();
    final subtitleColor = notifier.getBodyTextColor();
    final borderColor = notifier.getBorderColor();
    final themeAccent = notifier.getPrimaryColor();
    final isMobile = MediaQuery.of(context).size.width < 768;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner Header
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cardBgColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: themeAccent.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.assignment_rounded,
                    size: 28,
                    color: themeAccent,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: themeAccent.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Text(
                              'DLC INOVASI STANDAR KEMENKES',
                              style: GoogleFonts.outfit(
                                fontSize: 7,
                                fontWeight: FontWeight.w900,
                                color: themeAccent,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Form Digital Standar ANC 10T',
                            style: GoogleFonts.outfit(
                              fontSize: 9,
                              color: subtitleColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Form Pemeriksaan Ibu Hamil',
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: textColor,
                        ),
                      ),
                      Text(
                        'Pengisian rekam medis digital antenatal care (ANC 10T) otomatis terkoneksi RME SatuSehat & BPJS P-Care.',
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          color: subtitleColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Card Pasien Terpilih (jika ada pasien yang dipilih dari Pantauan atau Daftar)
          if (_selectedPatient != null)
            _buildSelectedPatientCard(
              context: context,
              isDark: isDark,
              cardBgColor: cardBgColor,
              textColor: textColor,
              subtitleColor: subtitleColor,
              borderColor: borderColor,
              themeAccent: themeAccent,
              isMobile: isMobile,
            ),

          // Render Step based on _step
          if (_step == 1)
            _buildStep1SelectPatient(
              context,
              isDark,
              cardBgColor,
              textColor,
              subtitleColor,
              borderColor,
              themeAccent,
              isMobile,
            )
          else if (_step == 2)
            _buildStep2ConfirmInfo(
              context,
              isDark,
              cardBgColor,
              textColor,
              subtitleColor,
              borderColor,
              themeAccent,
              isMobile,
            )
          else
            _buildStep3FillForm(
              context,
              isDark,
              cardBgColor,
              textColor,
              subtitleColor,
              borderColor,
              themeAccent,
            ),
        ],
      ),
    );
  }

  Widget _buildMiniInfoPill({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.outfit(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepNavButton({
    required int stepIndex,
    required String label,
    required IconData icon,
    required bool isActive,
    required Color themeAccent,
    bool isPrimary = false,
  }) {
    if (isActive) {
      return ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: themeAccent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          elevation: 1,
        ),
        onPressed: () => setState(() => _step = stepIndex),
        icon: Icon(icon, size: 14),
        label: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 10.5,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        side: BorderSide(
          color: isPrimary ? themeAccent : Colors.grey.withOpacity(0.4),
        ),
        foregroundColor: isPrimary ? themeAccent : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      onPressed: () => setState(() => _step = stepIndex),
      icon: Icon(icon, size: 14),
      label: Text(
        label,
        style: GoogleFonts.outfit(
          fontSize: 10.5,
          fontWeight: isPrimary ? FontWeight.bold : FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildSelectedPatientCard({
    required BuildContext context,
    required bool isDark,
    required Color cardBgColor,
    required Color textColor,
    required Color subtitleColor,
    required Color borderColor,
    required Color themeAccent,
    required bool isMobile,
  }) {
    final patient = _selectedPatient!;
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16202A) : const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFF27AE60).withOpacity(0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF27AE60).withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Baris Atas: Badge Pasien Terpilih & Tombol Hapus Pasien
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF27AE60).withOpacity(0.18),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                    color: const Color(0xFF27AE60).withOpacity(0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      size: 14,
                      color: Color(0xFF27AE60),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'PASIEN TERPILIH UNTUK PEMERIKSAAN ANC 10T',
                      style: GoogleFonts.outfit(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF27AE60),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              // Tombol Hapus / Batal Pilih Pasien
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFE74C3C), width: 1.2),
                  foregroundColor: const Color(0xFFE74C3C),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                ),
                onPressed: _clearSelectedPatient,
                icon: const Icon(Icons.delete_outline_rounded, size: 14),
                label: Text(
                  'Hapus Pasien',
                  style: GoogleFonts.outfit(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Baris Tengah: Avatar, Nama, NIK, Status
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: patient.ksprColor.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: patient.ksprColor.withOpacity(0.35),
                    width: 1.5,
                  ),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.face_3_rounded,
                  size: 28,
                  color: patient.ksprColor,
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
                            patient.nama,
                            style: GoogleFonts.outfit(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: textColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: patient.ksprColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(100),
                            border: Border.all(
                              color: patient.ksprColor.withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            patient.ksprStatus,
                            style: GoogleFonts.outfit(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: patient.ksprColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'NIK: ${patient.nik} • ${patient.umur} Tahun • ${patient.trimester} (${patient.usiaKehamilan}) • HPL: ${patient.hpl}',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        color: subtitleColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        _buildMiniInfoPill(
                          icon: Icons.monitor_weight_outlined,
                          text: 'LiLA: ${patient.lila} • Hb: ${patient.hb}',
                          color: patient.isKek
                              ? Colors.deepOrange
                              : const Color(0xFF27AE60),
                        ),
                        _buildMiniInfoPill(
                          icon: Icons.event_available_rounded,
                          text: 'Status: ${patient.ancStatus}',
                          color: themeAccent,
                        ),
                        _buildMiniInfoPill(
                          icon: Icons.location_on_outlined,
                          text: patient.faskesPemeriksa,
                          color: const Color(0xFF3498DB),
                        ),
                        if (_satuSehatPatientId != null)
                          _buildMiniInfoPill(
                            icon: Icons.verified_rounded,
                            text: 'IHS: $_satuSehatPatientId',
                            color: const Color(0xFF009688),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          Divider(height: 1, color: const Color(0xFF27AE60).withOpacity(0.2)),
          const SizedBox(height: 12),

          // Baris Bawah: Navigasi Langkah (Aksi Cepat)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Langkah Pengisian:',
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: subtitleColor,
                ),
              ),
              _buildStepNavButton(
                stepIndex: 1,
                label: '1. Peta & Info Lokasi',
                icon: Icons.map_rounded,
                isActive: _step == 1,
                themeAccent: themeAccent,
              ),
              _buildStepNavButton(
                stepIndex: 2,
                label: '2. Riwayat Kunjungan ANC',
                icon: Icons.history_edu_rounded,
                isActive: _step == 2,
                themeAccent: themeAccent,
              ),
              _buildStepNavButton(
                stepIndex: 3,
                label: '3. Form Pemeriksaan ANC 10T ➔',
                icon: Icons.edit_note_rounded,
                isActive: _step == 3,
                themeAccent: themeAccent,
                isPrimary: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== STEP 1: SELECT PATIENT & LIVE GEOTAGGING MAP ====================
  Widget _buildStep1SelectPatient(
    BuildContext context,
    bool isDark,
    Color cardBgColor,
    Color textColor,
    Color subtitleColor,
    Color borderColor,
    Color themeAccent,
    bool isMobile,
  ) {
    final masterPatients = ref.watch(ibuHamilListProvider);
    final filteredList = masterPatients.where((p) {
      final q = _searchQuery.toLowerCase();
      return p.nama.toLowerCase().contains(q) ||
          p.nik.contains(q) ||
          p.id.toLowerCase().contains(q);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Live Geotagging Map of Health Worker & Patient Locations
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardBgColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: borderColor),
          ),
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
                        child: Icon(
                          Icons.my_location_rounded,
                          size: 20,
                          color: themeAccent,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PETA GEOTAGGING & LOKASI SAAT INI (LIVE LOCATION)',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: textColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            'Pemetaan posisi lokasi nakes/petugas & titik rumah pasien ibu hamil terdekat',
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              color: subtitleColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2ECC71).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      'GPS Aktif 🟢',
                      style: GoogleFonts.outfit(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF2ECC71),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              RevGeoWilayahMapWidget(
                initialProvince: 'JAWA TIMUR',
                initialDistrict: 'KABUPATEN BONDOWOSO',
                initialSubDistrict: 'SUMBER WRINGIN',
                fieldBg: isDark
                    ? const Color(0xFF141824)
                    : const Color(0xFFF1F5F9),
                textColor: textColor,
                subtitleColor: subtitleColor,
                borderColor: borderColor,
                dropdownColor: isDark ? const Color(0xFF1B1B1E) : Colors.white,
                themeAccent: themeAccent,
                isDark: isDark,
                isEn: false,
                height: 380,
                showOnlyMap: true,
                markers: filteredList.map((item) {
                  return {
                    'lat': item.latitude,
                    'lng': item.longitude,
                    'title': '🤰 ${item.nama} (${item.umur} th)',
                    'subtitle': item.ksprStatus,
                    'info': 'NIK: ${item.nik}<br/>• HPL: ${item.hpl}',
                    'details': '📍 ${item.alamat}',
                    'color':
                        '#${item.ksprColor.value.toRadixString(16).substring(2)}',
                  };
                }).toList(),
                onChanged: (_, __, ___, ____) {},
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Step 1 Header & Search
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardBgColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: themeAccent.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.person_search_rounded,
                      size: 20,
                      color: themeAccent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'LANGKAH 1: PILIH PASIEN IBU HAMIL UNTUK PEMERIKSAAN',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: textColor,
                        ),
                      ),
                      Text(
                        'Pilih pasien yang akan diperiksa dari daftar di bawah untuk memuat data & riwayat pemeriksaan.',
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          color: subtitleColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 44,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF161B26)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: borderColor),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.search_rounded,
                            size: 18,
                            color: subtitleColor,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              onChanged: (v) =>
                                  setState(() => _searchQuery = v),
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                color: textColor,
                              ),
                              decoration: InputDecoration(
                                hintText:
                                    'Cari NIK, Nama Ibu Hamil, atau ID Kohort...',
                                hintStyle: GoogleFonts.outfit(
                                  fontSize: 11,
                                  color: subtitleColor,
                                ),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: themeAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AddPatientModalDialog(
                          cardBgColor: cardBgColor,
                          textColor: textColor,
                          subtitleColor: subtitleColor,
                          borderColor: borderColor,
                          themeAccent: themeAccent,
                          isDark: isDark,
                          onPatientAdded: (newPatient) {
                            ref
                                .read(ibuHamilListProvider.notifier)
                                .addPatient(newPatient);
                            setState(() {
                              _selectPatient(
                                newPatient,
                              ); // Auto select new patient!
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Pasien ${newPatient.nama} berhasil ditambahkan & dipilih!',
                                ),
                                backgroundColor: const Color(0xFF2ECC71),
                              ),
                            );
                          },
                        ),
                      );
                    },
                    icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                    label: Text(
                      '+ Tambah Pasien Baru',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // List of Selectable Patient Cards
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: filteredList.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, idx) {
            final item = filteredList[idx];
            final isCurrentSelected = _selectedPatient?.nik == item.nik;
            return Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => _selectPatient(item),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: isCurrentSelected
                        ? (isDark
                              ? const Color(0xFF1B2B20)
                              : const Color(0xFFE8F8F0))
                        : cardBgColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isCurrentSelected
                          ? const Color(0xFF27AE60)
                          : borderColor,
                      width: isCurrentSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: themeAccent.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.face_3_rounded,
                          size: 24,
                          color: themeAccent,
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
                                  item.nama,
                                  style: GoogleFonts.outfit(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                    color: textColor,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: item.ksprColor.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(100),
                                  ),
                                  child: Text(
                                    item.ksprStatus,
                                    style: GoogleFonts.outfit(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w900,
                                      color: item.ksprColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'NIK: ${item.nik} • ${item.umur} th • Suami: ${item.namaSuami}',
                              style: GoogleFonts.outfit(
                                fontSize: 10,
                                color: subtitleColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '📍 ${item.alamat}',
                              style: GoogleFonts.outfit(
                                fontSize: 9.5,
                                color: subtitleColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isCurrentSelected
                              ? const Color(0xFF27AE60)
                              : themeAccent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                        onPressed: () => _selectPatient(item),
                        icon: Icon(
                          isCurrentSelected
                              ? Icons.check_circle_rounded
                              : Icons.arrow_forward_rounded,
                          size: 14,
                        ),
                        label: Text(
                          isCurrentSelected
                              ? 'Terpilih (Lanjut)'
                              : 'Pilih Pasien',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // ==================== STEP 2: CONFIRM PATIENT INFO & HISTORY TABLE ====================
  Widget _buildStep2ConfirmInfo(
    BuildContext context,
    bool isDark,
    Color cardBgColor,
    Color textColor,
    Color subtitleColor,
    Color borderColor,
    Color themeAccent,
    bool isMobile,
  ) {
    final item = _selectedPatient!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Navigation Bar & Header
        Row(
          children: [
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: borderColor),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
              ),
              onPressed: () => setState(() => _step = 1),
              icon: Icon(Icons.arrow_back_rounded, size: 16, color: textColor),
              label: Text(
                'Pilih Pasien Lain',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFFE74C3C)),
                foregroundColor: const Color(0xFFE74C3C),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              onPressed: _clearSelectedPatient,
              icon: const Icon(Icons.delete_outline_rounded, size: 16),
              label: Text(
                'Hapus Pilihan',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'LANGKAH 2: KONFIRMASI DATA PASIEN & RIWAYAT KUNJUNGAN',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: textColor,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // 2-Column Responsive Layout (Left: Patient Info, Right: Visit History Table)
        Flex(
          direction: isMobile ? Axis.vertical : Axis.horizontal,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Column: Patient Information Card
            Expanded(
              flex: isMobile ? 0 : 5,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardBgColor,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: item.ksprColor.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.face_3_rounded,
                            size: 26,
                            color: item.ksprColor,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.nama,
                                style: GoogleFonts.outfit(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: item.ksprColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(100),
                                ),
                                child: Text(
                                  item.ksprStatus,
                                  style: GoogleFonts.outfit(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    color: item.ksprColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Divider(height: 1),
                    ),

                    _buildInfoRow(
                      'ID Kohort Pasien',
                      item.id,
                      textColor,
                      subtitleColor,
                    ),
                    const SizedBox(height: 10),
                    _buildInfoRow(
                      'NIK Ibu Hamil',
                      item.nik,
                      textColor,
                      subtitleColor,
                    ),
                    const SizedBox(height: 10),
                    _buildInfoRow(
                      'Usia / Suami',
                      '${item.umur} Thn • ${item.namaSuami}',
                      textColor,
                      subtitleColor,
                    ),
                    const SizedBox(height: 10),
                    _buildInfoRow(
                      'Usia Kehamilan',
                      '${item.usiaKehamilan} (${item.trimester})',
                      themeAccent,
                      subtitleColor,
                    ),
                    const SizedBox(height: 10),
                    _buildInfoRow(
                      'Taksiran Persalinan (HPL)',
                      item.hpl,
                      textColor,
                      subtitleColor,
                    ),
                    const SizedBox(height: 10),
                    _buildInfoRow(
                      'Kadar Hb / LiLA',
                      '${item.hb} | ${item.lila}',
                      textColor,
                      subtitleColor,
                    ),
                    const SizedBox(height: 10),
                    _buildInfoRow(
                      'Nomor Telepon / WA',
                      item.noTelepon,
                      textColor,
                      subtitleColor,
                    ),
                    const SizedBox(height: 10),
                    _buildInfoRow(
                      'Alamat Domisili',
                      item.alamat,
                      textColor,
                      subtitleColor,
                    ),
                    const SizedBox(height: 10),
                    _buildInfoRow(
                      'Koordinat GPS',
                      'Lat ${item.latitude}, Lng ${item.longitude}',
                      subtitleColor,
                      subtitleColor,
                    ),
                  ],
                ),
              ),
            ),

            if (!isMobile) const SizedBox(width: 16),
            if (isMobile) const SizedBox(height: 16),

            // Right Column: Visit History Table / List
            Expanded(
              flex: isMobile ? 0 : 7,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardBgColor,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.history_rounded,
                              size: 18,
                              color: themeAccent,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'JUMLAH & RIWAYAT KUNJUNGAN ANC (${item.jumlahKunjungan}x)',
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                color: textColor,
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
                            color: themeAccent.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            item.ancStatus,
                            style: GoogleFonts.outfit(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: themeAccent,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Visit items list
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: item.riwayatKunjungan.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, idx) {
                        final r = item.riwayatKunjungan[idx];
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF161B26)
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: borderColor),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: themeAccent.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  r['kunjungan'] ?? 'ANC',
                                  style: GoogleFonts.outfit(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: themeAccent,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          '📅 ${r['date']} • 🕒 ${r['time']}',
                                          style: GoogleFonts.outfit(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: textColor,
                                          ),
                                        ),
                                        Text(
                                          '👨‍⚕️ ${r['pemeriksa']}',
                                          style: GoogleFonts.outfit(
                                            fontSize: 10,
                                            color: subtitleColor,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      r['catatan'] ?? '-',
                                      style: GoogleFonts.outfit(
                                        fontSize: 10,
                                        color: subtitleColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Prominent Bottom Action Button ("Memulai Pemeriksaan")
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBgColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Siap Memeriksa Pasien: ${item.nama}',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  Text(
                    'Data pasien & riwayat kunjungan akan otomatis terhubung ke Form ANC 10T.',
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      color: subtitleColor,
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  elevation: 3,
                ),
                onPressed: () => setState(() => _step = 3),
                icon: const Icon(Icons.edit_note_rounded, size: 20),
                label: Text(
                  'Memulai Pemeriksaan (ANC 10T) ➔',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==================== STEP 3: FILL ANC 10T EXAMINATION FORM ====================
  Widget _buildStep3FillForm(
    BuildContext context,
    bool isDark,
    Color cardBgColor,
    Color textColor,
    Color subtitleColor,
    Color borderColor,
    Color themeAccent,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Step 3 Header Banner with Active Patient Info & Change Patient button
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: themeAccent.withOpacity(0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: themeAccent.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(Icons.face_3_rounded, size: 22, color: themeAccent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Sedang Memeriksa Pasien: ${_selectedPatient?.nama ?? _namaController.text}',
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: textColor,
                                ),
                              ),
                              if (_satuSehatPatientId != null) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF2ECC71,
                                    ).withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(100),
                                    border: Border.all(
                                      color: const Color(
                                        0xFF2ECC71,
                                      ).withOpacity(0.4),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.verified_rounded,
                                        size: 11,
                                        color: Color(0xFF2ECC71),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'IHS: $_satuSehatPatientId',
                                        style: GoogleFonts.firaCode(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF2ECC71),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                          Text(
                            'NIK: ${_selectedPatient?.nik ?? _nikController.text} • Buku KIA 2024 & Standar RME SATUSEHAT Kemenkes RI',
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              color: subtitleColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: themeAccent),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    onPressed: () => setState(() => _step = 2),
                    icon: Icon(
                      Icons.arrow_back_rounded,
                      size: 14,
                      color: themeAccent,
                    ),
                    label: Text(
                      '← Riwayat Pasien',
                      style: GoogleFonts.outfit(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: themeAccent,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFE74C3C)),
                      foregroundColor: const Color(0xFFE74C3C),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                    ),
                    onPressed: _clearSelectedPatient,
                    icon: const Icon(Icons.delete_outline_rounded, size: 14),
                    label: Text(
                      'Hapus Pasien',
                      style: GoogleFonts.outfit(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Stepper Navigation Header (Buku KIA 2024 - 1 Card Per Step)
        Builder(
          builder: (context) {
            final issues = _validateAncForm();
            final redErrors = issues.where((i) => i['isError'] == true).toList();
            final yellowWarnings = issues.where((i) => i['isError'] == false).toList();
            final stepHasError = <int, bool>{};
            final stepHasWarning = <int, bool>{};
            for (final issue in issues) {
              final step = issue['step'] as int;
              if (issue['isError'] == true) {
                stepHasError[step] = true;
              } else {
                stepHasWarning[step] = true;
              }
            }

            final stepperItems = [
              FormStepItem(
                step: 1,
                label: '1. Identitas & ANC',
                icon: Icons.person_pin_rounded,
                hasError: stepHasError[1] == true,
                hasWarning: stepHasWarning[1] == true,
                isCompleted: _formStep > 1 && stepHasError[1] != true,
              ),
              FormStepItem(
                step: 2,
                label: '2. Antropometri & TD',
                icon: Icons.monitor_weight_rounded,
                hasError: stepHasError[2] == true,
                hasWarning: stepHasWarning[2] == true,
                isCompleted: _formStep > 2 && stepHasError[2] != true,
              ),
              FormStepItem(
                step: 3,
                label: '3. Janin & DJJ',
                icon: Icons.child_care_rounded,
                hasError: stepHasError[3] == true,
                hasWarning: stepHasWarning[3] == true,
                isCompleted: _formStep > 3 && stepHasError[3] != true,
              ),
              FormStepItem(
                step: 4,
                label: '4. Lab & TTD',
                icon: Icons.science_rounded,
                hasError: stepHasError[4] == true,
                hasWarning: stepHasWarning[4] == true,
                isCompleted: _formStep > 4 && stepHasError[4] != true,
              ),
              FormStepItem(
                step: 5,
                label: '5. Risiko KSPR',
                icon: Icons.assignment_turned_in_rounded,
                hasError: stepHasError[5] == true,
                hasWarning: stepHasWarning[5] == true,
                isCompleted: _formStep > 5 && stepHasError[5] != true,
              ),
              FormStepItem(
                step: 6,
                label: '6. P4K & Konseling',
                icon: Icons.record_voice_over_rounded,
                hasError: stepHasError[6] == true,
                hasWarning: stepHasWarning[6] == true,
                isCompleted: _formStep == 6 && issues.isEmpty,
              ),
            ];

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CustomFormStepper(
                  steps: stepperItems,
                  currentStep: _formStep,
                  onStepTapped: (step) => setState(() => _formStep = step),
                  themeAccent: themeAccent,
                  textColor: textColor,
                  subtitleColor: subtitleColor,
                  borderColor: borderColor,
                  cardBgColor: cardBgColor,
                  isDark: isDark,
                ),

                const SizedBox(height: 16),

                // Form Body: Only 1 Active Card per Step
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      if (_formStep == 1)
                        _buildFormSection1(context, isDark, cardBgColor, textColor, subtitleColor, borderColor, themeAccent)
                      else if (_formStep == 2)
                        _buildFormSection2(context, isDark, cardBgColor, textColor, subtitleColor, borderColor, themeAccent)
                      else if (_formStep == 3)
                        _buildFormSection3(context, isDark, cardBgColor, textColor, subtitleColor, borderColor, themeAccent)
                      else if (_formStep == 4)
                        _buildFormSection4(context, isDark, cardBgColor, textColor, subtitleColor, borderColor, themeAccent)
                      else if (_formStep == 5)
                        _buildFormSection5(context, isDark, cardBgColor, textColor, subtitleColor, borderColor, themeAccent)
                      else if (_formStep == 6)
                        _buildFormSection6(context, isDark, cardBgColor, textColor, subtitleColor, borderColor, themeAccent),

                      const SizedBox(height: 16),

                      // 7. SATUSEHAT FHIR R4 Integration Status Card (If Synced)
                      if (_satuSehatSyncResult != null) ...[
                        _buildSatuSehatSyncCard(cardBgColor, borderColor, textColor, subtitleColor, themeAccent),
                        const SizedBox(height: 16),
                      ],

                      // Stepper Navigation Footer & Real-Time Validation Pill
                      _buildStepperFooter(
                        context,
                        isDark,
                        cardBgColor,
                        textColor,
                        subtitleColor,
                        borderColor,
                        themeAccent,
                        redErrors,
                        yellowWarnings,
                      ),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  // ==================== SECTION 1: IDENTITAS & ANC ====================
  Widget _buildFormSection1(
    BuildContext context,
    bool isDark,
    Color cardBgColor,
    Color textColor,
    Color subtitleColor,
    Color borderColor,
    Color themeAccent,
  ) {
    return _buildFormSection(
      '1. Identitas Pasien & Kontak Kunjungan ANC (Buku KIA 2024)',
      Icons.person_pin_rounded,
      themeAccent,
      cardBgColor,
      borderColor,
      textColor,
      [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              flex: 3,
              child: _buildTextField(
                'NIK Ibu Hamil (16 Digit Wajib Kemenkes)',
                _nikController,
                textColor,
                subtitleColor,
                borderColor,
                cardBgColor,
                keyboardType: TextInputType.number,
                maxLength: 16,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(16),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF009688)),
                  backgroundColor: const Color(0xFF009688).withOpacity(0.08),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                onPressed: _isCheckingSatuSehat ? null : _checkSatuSehatPatient,
                icon: _isCheckingSatuSehat
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF009688)))
                    : const Icon(Icons.verified_user_rounded, size: 16, color: Color(0xFF009688)),
                label: Text(
                  _isCheckingSatuSehat ? 'Memeriksa...' : 'Cek SATUSEHAT',
                  style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF009688)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 4,
              child: _buildTextField('Nama Lengkap Ibu Hamil', _namaController, textColor, subtitleColor, borderColor, cardBgColor),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildDropdown('Trimester Kehamilan', _trimester, ['Trimester 1', 'Trimester 2', 'Trimester 3'], (v) {
                if (v != null) setState(() => _trimester = v);
              }, textColor, cardBgColor, borderColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildDropdown('Kontak Kunjungan (ANC Standar 6x)', _kunjungan, ['K1', 'K2', 'K3', 'K4', 'K5', 'K6'], (v) {
                if (v != null) setState(() => _kunjungan = v);
              }, textColor, cardBgColor, borderColor),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Banner Edukasi Standar ANC 6x & USG Buku KIA 2024
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: themeAccent.withOpacity(0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: themeAccent.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 18, color: themeAccent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Standar Buku KIA 2024: ANC minimal 6x (K1-K6). Wajib minimal 2x diperiksa Dokter & USG: 1x di Trimester 1 (K1) dan 1x di Trimester 3 (K5) untuk deteksi dini risiko kehamilan.',
                  style: GoogleFonts.outfit(fontSize: 10, color: textColor, height: 1.3),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          activeColor: themeAccent,
          title: Text(
            'Pemeriksaan Dokter Umum/Spesialis & Skrining USG Terpenuhi (Wajib di K1 & K5)',
            style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: textColor),
          ),
          subtitle: Text(
            'Konfirmasi skrining USG kehamilan trimester 1 / 3 telah dilaksanakan oleh dokter',
            style: GoogleFonts.outfit(fontSize: 9.5, color: subtitleColor),
          ),
          value: _pemeriksaanDokterUsg,
          onChanged: (v) => setState(() => _pemeriksaanDokterUsg = v),
        ),
      ],
    );
  }

  // ==================== SECTION 2: ANTROPOMETRI & TENSI ====================
  Widget _buildFormSection2(
    BuildContext context,
    bool isDark,
    Color cardBgColor,
    Color textColor,
    Color subtitleColor,
    Color borderColor,
    Color themeAccent,
  ) {
    return _buildFormSection(
      '2. Timbang BB, Tinggi Badan, Tekanan Darah & Ukur LiLA (1T - 3T)',
      Icons.monitor_weight_rounded,
      themeAccent,
      cardBgColor,
      borderColor,
      textColor,
      topChips: [
        ?_lilaStatusBadge,
        ?_imtStatusBadge,
        ?_tdStatusBadge,
      ],
      [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTextField('Tinggi Badan (cm)', _tbController, textColor, subtitleColor, borderColor, cardBgColor, keyboardType: TextInputType.number),
                  const SizedBox(height: 4),
                  _buildLoincBadge('LOINC: 8302-2 (Body height)'),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTextField('Berat Badan (kg)', _bbController, textColor, subtitleColor, borderColor, cardBgColor, keyboardType: TextInputType.number),
                  const SizedBox(height: 4),
                  _buildLoincBadge('LOINC: 29463-7 (Body weight)'),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTextField('LiLA (cm)', _lilaController, textColor, subtitleColor, borderColor, cardBgColor, keyboardType: TextInputType.number),
                  const SizedBox(height: 4),
                  _buildLoincBadge('LOINC: 56072-2 (Mid upper arm circ)'),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTextField('Tekanan Darah Sistole (mmHg)', _sistoleController, textColor, subtitleColor, borderColor, cardBgColor, keyboardType: TextInputType.number),
                  const SizedBox(height: 4),
                  _buildLoincBadge('LOINC: 8480-6 (Systolic BP)'),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTextField('Tekanan Darah Diastole (mmHg)', _diastoleController, textColor, subtitleColor, borderColor, cardBgColor, keyboardType: TextInputType.number),
                  const SizedBox(height: 4),
                  _buildLoincBadge('LOINC: 8462-4 (Diastolic BP)'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ==================== SECTION 3: JANIN & DJJ ====================
  Widget _buildFormSection3(
    BuildContext context,
    bool isDark,
    Color cardBgColor,
    Color textColor,
    Color subtitleColor,
    Color borderColor,
    Color themeAccent,
  ) {
    return _buildFormSection(
      '3. Tentukan TFU, Presentasi Janin, DJJ & Imunisasi Td (4T - 6T)',
      Icons.child_care_rounded,
      themeAccent,
      cardBgColor,
      borderColor,
      textColor,
      topChips: [
        ?_tbjStatusBadge,
        ?_djjStatusBadge,
      ],
      [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTextField('Tinggi Fundus Uteri (TFU) cm', _tfuController, textColor, subtitleColor, borderColor, cardBgColor, keyboardType: TextInputType.number),
                  const SizedBox(height: 4),
                  _buildLoincBadge('LOINC: 11881-0 (Uterus Fundal height)'),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTextField('Denyut Jantung Janin (DJJ) x/mnt', _djjController, textColor, subtitleColor, borderColor, cardBgColor, keyboardType: TextInputType.number),
                  const SizedBox(height: 4),
                  _buildLoincBadge('LOINC: 55283-6 (Fetal Heart rate)'),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: _buildDropdown(
                'Presentasi Janin (Letak Janin)',
                _presentasiJanin,
                ['Kepala (Normal)', 'Bokong (Sungsang)', 'Lintang (Transverse)'],
                (v) {
                  if (v != null) setState(() => _presentasiJanin = v);
                },
                textColor,
                cardBgColor,
                borderColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildDropdown(
                'Status Imunisasi Tetanus (T)',
                _statusImunisasiT,
                ['T1 (Awal)', 'T2 (3 Tahun)', 'T3 (5 Tahun)', 'T4 (10 Tahun)', 'T5 (Lengkap)'],
                (v) {
                  if (v != null) setState(() => _statusImunisasiT = v);
                },
                textColor,
                cardBgColor,
                borderColor,
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          activeColor: themeAccent,
          title: Text(
            'Pemberian Imunisasi Td (Tetanus Difteri) pada Kunjungan Ini',
            style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: textColor),
          ),
          subtitle: Text(
            'Diberikan jika status imunisasi T belum lengkap sesuai interval Buku KIA',
            style: GoogleFonts.outfit(fontSize: 9.5, color: subtitleColor),
          ),
          value: _imunisasiTdDiberikan,
          onChanged: (v) => setState(() => _imunisasiTdDiberikan = v),
        ),
      ],
    );
  }

  // ==================== SECTION 4: LAB & TTD ====================
  Widget _buildFormSection4(
    BuildContext context,
    bool isDark,
    Color cardBgColor,
    Color textColor,
    Color subtitleColor,
    Color borderColor,
    Color themeAccent,
  ) {
    return _buildFormSection(
      '4. Skrining Laboratorium, Triple Eliminasi & Suplemen TTD (7T - 8T)',
      Icons.science_rounded,
      themeAccent,
      cardBgColor,
      borderColor,
      textColor,
      topChips: [
        ?_hbStatusBadge,
      ],
      [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTextField('Kadar Hemoglobin (Hb) g/dL', _hbController, textColor, subtitleColor, borderColor, cardBgColor, keyboardType: TextInputType.number),
                  const SizedBox(height: 4),
                  _buildLoincBadge('LOINC: 718-7 (Hemoglobin blood)'),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildDropdown('Golongan Darah & Rhesus', _golDarah, ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'], (v) {
                if (v != null) setState(() => _golDarah = v);
              }, textColor, cardBgColor, borderColor),
            ),
          ],
        ),

        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: _buildDropdown(
                'Protein Urin (Deteksi Preeklamsia)',
                _proteinUrin,
                ['Negatif', 'Positif 1 (+1)', 'Positif 2 (+2)', 'Positif 3 (+3)', 'Positif 4 (+4)'],
                (v) {
                  if (v != null) setState(() => _proteinUrin = v);
                },
                textColor,
                cardBgColor,
                borderColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildDropdown(
                'Glukosa Urin (Deteksi DM Gestasional)',
                _glukosaUrin,
                ['Negatif', 'Positif 1 (+1)', 'Positif 2 (+2)', 'Positif 3 (+3)'],
                (v) {
                  if (v != null) setState(() => _glukosaUrin = v);
                },
                textColor,
                cardBgColor,
                borderColor,
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          activeColor: themeAccent,
          title: Text('Pemberian Tablet Tambah Darah (TTD minimal 90 Tablet selama Hamil)', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: textColor)),
          value: _ttdDiberikan,
          onChanged: (v) => setState(() => _ttdDiberikan = v),
        ),

        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          activeColor: themeAccent,
          title: Text('Skrining Triple Eliminasi (HIV / Sifilis / Hepatitis B Non-Reaktif)', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: textColor)),
          subtitle: Text('Wajib dilakukan 1 kali pada Trimester 1 (K1) di Puskesmas', style: GoogleFonts.outfit(fontSize: 9.5, color: subtitleColor)),
          value: _tripleEliminasiNonReaktif,
          onChanged: (v) => setState(() => _tripleEliminasiNonReaktif = v),
        ),
      ],
    );
  }

  // ==================== SECTION 5: KSPR ====================
  Widget _buildFormSection5(
    BuildContext context,
    bool isDark,
    Color cardBgColor,
    Color textColor,
    Color subtitleColor,
    Color borderColor,
    Color themeAccent,
  ) {
    return _buildFormSection(
      '5. Tata Laksana Kasus & Skrining Risiko KSPR (9T)',
      Icons.assignment_turned_in_rounded,
      themeAccent,
      cardBgColor,
      borderColor,
      textColor,
      [
        _buildDropdown(
          'Kategori Risiko Kehamilan (Kartu Skor Poedji Rochjati - KSPR)',
          _skorKspr,
          _ksprOptions,
          (v) {
            if (v != null) setState(() => _skorKspr = _normalizeKspr(v));
          },
          textColor,
          cardBgColor,
          borderColor,
        ),
        const SizedBox(height: 10),
        // Banner Rujukan Standar Buku KIA 2024
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _skorKspr.contains('Sangat Tinggi')
                ? const Color(0xFFE74C3C).withOpacity(0.12)
                : (_skorKspr.contains('Tinggi') ? const Color(0xFFE67E22).withOpacity(0.12) : const Color(0xFF2ECC71).withOpacity(0.12)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _skorKspr.contains('Sangat Tinggi')
                  ? const Color(0xFFE74C3C).withOpacity(0.3)
                  : (_skorKspr.contains('Tinggi') ? const Color(0xFFE67E22).withOpacity(0.3) : const Color(0xFF2ECC71).withOpacity(0.3)),
            ),
          ),
          child: Row(
            children: [
              Icon(
                _skorKspr.contains('Sangat Tinggi')
                    ? Icons.dangerous_rounded
                    : (_skorKspr.contains('Tinggi') ? Icons.warning_rounded : Icons.check_circle_rounded),
                size: 20,
                color: _skorKspr.contains('Sangat Tinggi')
                    ? const Color(0xFFE74C3C)
                    : (_skorKspr.contains('Tinggi') ? const Color(0xFFE67E22) : const Color(0xFF27AE60)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _skorKspr.contains('Sangat Tinggi')
                      ? '🔴 KRST (Risiko Sangat Tinggi): Persalinan wajib direncanakan di Rumah Sakit rujukan komprehensif (PONEK) dengan penanganan Dokter Spesialis Obgyn.'
                      : (_skorKspr.contains('Tinggi')
                          ? '🟠 KRT (Risiko Tinggi): Rujukan berencana untuk konsultasi Dokter Spesialis Obgyn di RS. Penolong persalinan dapat Dokter Puskesmas / RS.'
                          : '🟢 KRR (Risiko Rendah): Antenatal care dan persalinan normal dapat ditolong oleh Bidan / Dokter di Fasilitas Pelayanan Kesehatan Primer (Puskesmas).'),
                  style: GoogleFonts.outfit(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: _skorKspr.contains('Sangat Tinggi')
                        ? const Color(0xFFE74C3C)
                        : (_skorKspr.contains('Tinggi') ? const Color(0xFFE67E22) : const Color(0xFF27AE60)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==================== SECTION 6: P4K & KONSELING ====================
  Widget _buildFormSection6(
    BuildContext context,
    bool isDark,
    Color cardBgColor,
    Color textColor,
    Color subtitleColor,
    Color borderColor,
    Color themeAccent,
  ) {
    return _buildFormSection(
      '6. Temu Wicara, Konseling & Program Perencanaan Persalinan (P4K) (10T)',
      Icons.record_voice_over_rounded,
      themeAccent,
      cardBgColor,
      borderColor,
      textColor,
      [
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                'Calon Pendonor Darah Keluarga (Nama & Golongan Darah)',
                _p4kDonorController,
                textColor,
                subtitleColor,
                borderColor,
                cardBgColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildDropdown(
                'Rencana Tempat Persalinan (P4K)',
                _p4kTempatBersalin,
                ['Puskesmas', 'Rumah Sakit (RSUD)', 'Klinik Pratama'],
                (v) {
                  if (v != null) setState(() => _p4kTempatBersalin = v);
                },
                textColor,
                cardBgColor,
                borderColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildDropdown(
                'Rencana Penolong Persalinan',
                _p4kPenolong,
                ['Bidan & Dokter Puskesmas', 'Dokter Spesialis Kebidanan (Sp.OG)', 'Bidan Praktik Mandiri'],
                (v) {
                  if (v != null) setState(() => _p4kPenolong = v);
                },
                textColor,
                cardBgColor,
                borderColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildDropdown(
                'Rencana KB Pasca Persalinan',
                _p4kRencanaKb,
                ['IUD Pasca Persalinan', 'Implan / Susuk KB', 'Suntik Progestin', 'Tubektomi (MOW)', 'Kondom'],
                (v) {
                  if (v != null) setState(() => _p4kRencanaKb = v);
                },
                textColor,
                cardBgColor,
                borderColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildTextField(
          'Catatan Konseling, Temu Wicara & Tanda Bahaya Kehamilan',
          _catatanController,
          textColor,
          subtitleColor,
          borderColor,
          cardBgColor,
          maxLines: 3,
        ),
      ],
    );
  }

  // ==================== SATUSEHAT SYNC CARD ====================
  Widget _buildSatuSehatSyncCard(
    Color cardBgColor,
    Color borderColor,
    Color textColor,
    Color subtitleColor,
    Color themeAccent,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF009688).withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF009688).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_rounded, size: 20, color: Color(0xFF009688)),
              const SizedBox(width: 8),
              Text(
                'Sinkronisasi RME SATUSEHAT Berhasil',
                style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w900, color: const Color(0xFF009688)),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF009688).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  _satuSehatSyncResult!['mode'] ?? 'FHIR R4',
                  style: GoogleFonts.outfit(fontSize: 9.5, fontWeight: FontWeight.bold, color: const Color(0xFF009688)),
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMiniInfo('Encounter ID', _satuSehatSyncResult!['encounter_id'] ?? '-', subtitleColor, textColor),
              _buildMiniInfo('IHS Pasien', _satuSehatSyncResult!['patient_id'] ?? '-', subtitleColor, textColor),
              _buildMiniInfo('Kode ICD-10', _satuSehatSyncResult!['diagnoses'] ?? '-', subtitleColor, themeAccent),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== STEPPER FOOTER (NO PREVIEW FHIR BUTTON) ====================
  Widget _buildStepperFooter(
    BuildContext context,
    bool isDark,
    Color cardBgColor,
    Color textColor,
    Color subtitleColor,
    Color borderColor,
    Color themeAccent,
    List<Map<String, dynamic>> redErrors,
    List<Map<String, dynamic>> yellowWarnings,
  ) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    if (isMobile) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBgColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildValidationStatusPill(redErrors, yellowWarnings, subtitleColor),
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
                  )
                else
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: borderColor),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () => setState(() => _step = 2),
                      icon: const Icon(Icons.arrow_back_rounded, size: 14),
                      label: Text('Riwayat', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: textColor)),
                    ),
                  ),
                const SizedBox(width: 8),
                if (_formStep < 6)
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: themeAccent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () => setState(() => _formStep++),
                      icon: const Icon(Icons.arrow_forward_rounded, size: 14, color: Colors.white),
                      label: Text('Selanjutnya', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  )
                else
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: redErrors.isNotEmpty ? const Color(0xFFE74C3C) : const Color(0xFF27AE60),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: _isSyncingSatuSehat ? null : _simpanForm,
                      icon: _isSyncingSatuSehat
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.cloud_upload_rounded, size: 14, color: Colors.white),
                      label: Text(
                        _isSyncingSatuSehat ? 'Sinkronisasi...' : 'Simpan SatuSehat',
                        style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
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
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: borderColor),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
              onPressed: () => setState(() => _step = 2),
              icon: const Icon(Icons.arrow_back_rounded, size: 16),
              label: Text(
                '← Riwayat Pasien',
                style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: textColor),
              ),
            ),

          // Center: Real-time Form Completeness Status Chip (Clickable to open Review Dialog)
          _buildValidationStatusPill(redErrors, yellowWarnings, subtitleColor),

          // Right: Action Buttons (Review Validasi + Next / Simpan SatuSehat)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: themeAccent),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                onPressed: _showReviewAndSubmitDialog,
                icon: Icon(Icons.fact_check_rounded, size: 16, color: themeAccent),
                label: Text(
                  'Review Validasi',
                  style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: themeAccent),
                ),
              ),
              const SizedBox(width: 8),
              if (_formStep < 6)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: themeAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    elevation: 2,
                  ),
                  onPressed: () => setState(() => _formStep++),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.white),
                  label: Text(
                    'Selanjutnya ➔',
                    style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                )
              else
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: redErrors.isNotEmpty ? const Color(0xFFE74C3C) : const Color(0xFF27AE60),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                    elevation: 2,
                  ),
                  onPressed: _isSyncingSatuSehat ? null : _simpanForm,
                  icon: _isSyncingSatuSehat
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.cloud_upload_rounded, color: Colors.white, size: 16),
                  label: Text(
                    _isSyncingSatuSehat ? 'Menyinkronkan...' : 'Simpan Form ANC & Sync SatuSehat',
                    style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== VALIDATION STATUS PILL ====================
  Widget _buildValidationStatusPill(
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
      badgeText = '✅ Form 10T Lengkap (Siap Simpan)';
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
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: badgeColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoincBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF009688).withOpacity(0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFF009688).withOpacity(0.2)),
      ),
      child: Text(
        label,
        style: GoogleFonts.firaCode(
          fontSize: 8.5,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF009688),
        ),
      ),
    );
  }

  Widget _buildMiniInfo(
    String label,
    String val,
    Color subColor,
    Color mainColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 8.5,
            color: subColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          val,
          style: GoogleFonts.outfit(
            fontSize: 11,
            color: mainColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(
    String label,
    String value,
    Color txtColor,
    Color subColor,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.outfit(fontSize: 10.5, color: subColor)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: GoogleFonts.outfit(
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
              color: txtColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFormSection(
    String title,
    IconData icon,
    Color accentColor,
    Color bgColor,
    Color borderColor,
    Color textColor,
    List<Widget> children, {
    List<Widget>? topChips,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: accentColor),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: textColor,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          if (topChips != null && topChips.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 6, children: topChips),
          ],
          const Divider(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    Color textColor,
    Color subColor,
    Color borderColor,
    Color bgColor, {
    int maxLines = 1,
    TextInputType? keyboardType,
    int? maxLength,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: subColor,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          maxLength: maxLength,
          inputFormatters: inputFormatters,
          style: GoogleFonts.outfit(fontSize: 12, color: textColor),
          decoration: InputDecoration(
            isDense: true,
            counterText: '',
            filled: true,
            fillColor: bgColor,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: ref.read(landingPageProvider.notifier).getPrimaryColor(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown(
    String label,
    String value,
    List<String> items,
    ValueChanged<String?> onChanged,
    Color textColor,
    Color bgColor,
    Color borderColor,
  ) {
    final uniqueItems = items.toSet().toList();
    final effectiveValue = uniqueItems.contains(value)
        ? value
        : (uniqueItems.isNotEmpty ? uniqueItems.first : null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: effectiveValue,
              dropdownColor: bgColor,
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
              items: uniqueItems
                  .map((i) => DropdownMenuItem(value: i, child: Text(i)))
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
