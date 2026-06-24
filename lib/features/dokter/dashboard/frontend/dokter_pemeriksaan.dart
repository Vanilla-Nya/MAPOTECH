import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapotech/features/landing/landing_page_data.dart';
import 'package:mapotech/features/dokter/dashboard/frontend/dokter_antrian.dart';
import 'package:mapotech/features/dokter/dashboard/frontend/dokter_pasien.dart';
import 'package:mapotech/features/dokter/dashboard/frontend/dokter_obat.dart';

final List<String> mockDiagnoses = [
  'Hipertensi Primer (ICD-10 I10)',
  'Dyspepsia / Sakit Lambung (ICD-10 K30)',
  'Gastroenteritis Akut / Diare (ICD-10 A09)',
  'Common Cold / Influenza (ICD-10 J00)',
  'Faringitis Akut / Radang Tenggorokan (ICD-10 J02)',
  'Diabetes Melitus Tipe 2 (ICD-10 E11)',
  'Asma Bronkial (ICD-10 J45)',
  'Cephalgia / Sakit Kepala (ICD-10 R51)',
  'Artritis Reumatoid (ICD-10 M06)',
  'Dermatitis Alergi (ICD-10 L23)',
];

class DokterPemeriksaan extends ConsumerStatefulWidget {
  const DokterPemeriksaan({super.key});

  @override
  ConsumerState<DokterPemeriksaan> createState() => _DokterPemeriksaanState();
}

class _DokterPemeriksaanState extends ConsumerState<DokterPemeriksaan> {
  AntrianModel? _activeQueue;
  PasienModel? _activePatient;

  // SatuSehat Sync States
  bool _isSyncing = false;
  bool _syncSuccess = false;
  String _syncStep = 'Connecting';
  String _txHash = '';

  // Vital Signs
  final _tensiController = TextEditingController(text: '120/80');
  final _nadiController = TextEditingController(text: '80');
  final _suhuController = TextEditingController(text: '36.5');
  final _beratController = TextEditingController(text: '65');
  final _tinggiController = TextEditingController(text: '170');

  // Anamnesis & Diagnosis
  final _keluhanController = TextEditingController();
  String? _selectedDiagnosis;
  String _diagnosisSearchQuery = '';
  bool _showDiagnosisDropdown = false;

  // Prescriptions
  final List<Map<String, dynamic>> _addedPrescriptions = [];
  ObatModel? _selectedDrug;
  final _qtyController = TextEditingController(text: '10');
  final _instructionController = TextEditingController(text: '3 x 1 tablet sesudah makan');
  bool _showDrugDropdown = false;
  String _drugSearchQuery = '';

  // Referral
  bool _wantReferral = false;
  final _referralRsController = TextEditingController(text: 'RSUD dr.H Koesnadi');
  final _referralPoliController = TextEditingController(text: 'Poli Jantung');
  String _generatedReferralNo = '';

  @override
  void dispose() {
    _tensiController.dispose();
    _nadiController.dispose();
    _suhuController.dispose();
    _beratController.dispose();
    _tinggiController.dispose();
    _keluhanController.dispose();
    _qtyController.dispose();
    _instructionController.dispose();
    _referralRsController.dispose();
    _referralPoliController.dispose();
    super.dispose();
  }

  void _loadPatientFromQueue(AntrianModel queue) {
    setState(() {
      _activeQueue = queue;
      
      // Attempt to look up the full PasienModel from the doctorPatientListProvider
      final patients = ref.read(dokterPasienListProvider);
      final match = patients.firstWhere(
        (p) => p.nik == queue.nik || p.nama.toLowerCase() == queue.nama.toLowerCase(),
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
      _selectedDiagnosis = null;
      _addedPrescriptions.clear();
      _wantReferral = false;
      _generatedReferralNo = 'REF/2026/05/${1000 + Random().nextInt(9000)}';
    });

    // Also update the queue status to 'Memproses...' in the state notifier if it is 'Menunggu'
    if (queue.status == 'Menunggu') {
      ref.read(dokterAntrianListProvider.notifier).updateAntrianStatus(queue.id, 'Memproses...');
    }
  }

  void _startSatuSehatSync() {
    if (_keluhanController.text.trim().isEmpty) {
      _showWarningDialog('Form Belum Lengkap', 'Harap isi bagian Anamnesis / Keluhan Pasien sebelum menyimpan.');
      return;
    }
    if (_selectedDiagnosis == null) {
      _showWarningDialog('Form Belum Lengkap', 'Harap tentukan Diagnosis klinis (ICD-10) untuk pasien.');
      return;
    }

    setState(() {
      _isSyncing = true;
      _syncSuccess = false;
      _syncStep = 'Connecting';
    });

    // Animate through sync steps
    Timer(const Duration(milliseconds: 1000), () {
      setState(() => _syncStep = 'SendingEMR');
      Timer(const Duration(milliseconds: 1200), () {
        setState(() => _syncStep = 'GeneratingPrescription');
        Timer(const Duration(milliseconds: 1000), () {
          final hashInt = Random().nextInt(900000) + 100000;
          setState(() {
            _syncStep = 'Success';
            _syncSuccess = true;
            _txHash = 'TX-EMR-2605-$hashInt';
          });
        });
      });
    });
  }

  void _completeSyncAndRedirect() {
    final queue = _activeQueue;
    final patient = _activePatient;
    if (queue != null && patient != null) {
      // Transition queue status to 'Pembayaran' (since it goes to cashier next)
      ref.read(dokterAntrianListProvider.notifier).updateAntrianStatus(queue.id, 'Pembayaran');

      // Show beautiful success toast
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF48C9B0),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Sesi EMR ${patient.nama} berhasil disimpan & disinkronkan ke SatuSehat. Pasien diarahkan ke Loket Pembayaran.',
                  style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
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
      _selectedDiagnosis = null;
      _addedPrescriptions.clear();
      _wantReferral = false;
    });
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
            const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 22),
            const SizedBox(width: 10),
            Text(title, style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w900)),
          ],
        ),
        content: Text(message, style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Mengerti', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: const Color(0xFFB577F2))),
          )
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
    final borderColor = isDark ? const Color(0xFF252528) : const Color(0xFFECEEF2);
    final inputBg = isDark ? const Color(0xFF1E1E22) : const Color(0xFFF6F8FA);
    final purple = const Color(0xFFB577F2);
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
                    child: Icon(Icons.assignment_rounded, color: purple, size: 18),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pemeriksaan & RME',
                          style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w900, color: textColor),
                        ),
                        Text(
                          'Sesi pencatatan rekam medis elektronik aktif dr. Agoes Soetanto',
                          style: GoogleFonts.outfit(fontSize: 10, color: subtitleColor, fontWeight: FontWeight.bold),
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
                  child: _activeQueue == null
                      ? _buildEmptyState(cardBg, textColor, subtitleColor, borderColor, purple, queueList)
                      : _buildActiveSessionConsole(
                          cardBg, textColor, subtitleColor, borderColor, inputBg, purple, activeGreen, drugList),
                ),

                if (!isMobile) const SizedBox(width: 24),

                // 2. RIGHT COLUMN: Today's Queue Sidebar
                if (!isMobile)
                  SizedBox(
                    width: 320,
                    child: _buildQueueSidebar(cardBg, textColor, subtitleColor, borderColor, purple, activeGreen, queueList),
                  ),
              ],
            ),
          ],
        ),

        // 3. SATUSEHAT SYNCHRONIZATION GLASS-MODAL OVERLAY
        if (_isSyncing)
          _buildSatuSehatSyncModal(cardBg, textColor, subtitleColor, borderColor, purple, activeGreen),
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
            style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900, color: text),
          ),
          const SizedBox(height: 8),
          Text(
            'Pilih salah satu pasien di antrean sebelah kanan untuk memulai diagnosa RME.',
            style: GoogleFonts.outfit(fontSize: 11, color: subtitle, height: 1.5, fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          if (waitingQueues.isNotEmpty)
            ElevatedButton(
              onPressed: () => _loadPatientFromQueue(waitingQueues.first),
              style: ElevatedButton.styleFrom(
                backgroundColor: purple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.play_circle_outline_rounded, size: 16, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    'Panggil Pasien Berikutnya (${waitingQueues.first.no})',
                    style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white),
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
                style: GoogleFonts.outfit(fontSize: 11, color: subtitle, fontWeight: FontWeight.bold),
              ),
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
    final patient = _activePatient!;
    final queue = _activeQueue!;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: border),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // A. PATIENT HEADER BAR
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: patient.avatarBg.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  patient.nama.substring(0, min(patient.nama.length, 2)).toUpperCase(),
                  style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w900, color: patient.avatarBg),
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
                          patient.nama,
                          style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w900, color: text),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: activeGreen.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.verified_rounded, size: 8, color: activeGreen),
                              const SizedBox(width: 4),
                              Text(
                                'SATUSEHAT VERIFIED',
                                style: GoogleFonts.outfit(fontSize: 6, fontWeight: FontWeight.w900, color: activeGreen),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'No. Antrean: ${queue.no} • NIK: ${patient.nik} • ${patient.jenisKelamin} • ${patient.umur}',
                      style: GoogleFonts.outfit(fontSize: 10, color: subtitle, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: () {
                  setState(() {
                    _activeQueue = null;
                    _activePatient = null;
                  });
                },
              ),
            ],
          ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(),
          ),

          // B. STEP 1: PHYSICAL EXAM (Vital Signs Grid)
          _sectionTitle('I. PEMERIKSAAN FISIK & TANDA VITAL', purple),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 5,
            shrinkWrap: true,
            crossAxisSpacing: 10,
            childAspectRatio: 1.25,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildVitalInput('Tekanan Darah', 'mmHg', _tensiController, Icons.favorite_border_rounded, inputBg, text, subtitle, border),
              _buildVitalInput('Detak Nadi', 'BPM', _nadiController, Icons.heart_broken_rounded, inputBg, text, subtitle, border),
              _buildVitalInput('Suhu Tubuh', '°C', _suhuController, Icons.thermostat_outlined, inputBg, text, subtitle, border),
              _buildVitalInput('Berat Badan', 'kg', _beratController, Icons.monitor_weight_outlined, inputBg, text, subtitle, border),
              _buildVitalInput('Tinggi Badan', 'cm', _tinggiController, Icons.height_outlined, inputBg, text, subtitle, border),
            ],
          ),

          const SizedBox(height: 24),

          // C. STEP 2: ANAMNESIS & DIAGNOSIS
          _sectionTitle('II. ANAMNESIS & DIAGNOSIS KLINIS (ICD-10)', purple),
          const SizedBox(height: 12),
          Text(
            'Keluhan Pasien / Anamnesis *',
            style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: text),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _keluhanController,
            maxLines: 2,
            style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: text),
            decoration: InputDecoration(
              hintText: 'Tulis keluhan subjektif pasien, misal: Sakit kepala hebat disertai mual sejak kemarin malam...',
              hintStyle: GoogleFonts.outfit(fontSize: 11, color: subtitle.withOpacity(0.5)),
              contentPadding: const EdgeInsets.all(14),
              filled: true,
              fillColor: inputBg,
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: purple, width: 1.5)),
            ),
          ),
          
          const SizedBox(height: 16),
          
          Text(
            'Diagnosis Utama (ICD-10) *',
            style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: text),
          ),
          const SizedBox(height: 6),
          
          // Searchable Diagnosis Field with Dropdown
          Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: text),
                    decoration: InputDecoration(
                      hintText: _selectedDiagnosis ?? 'Cari atau pilih kode diagnosa ICD-10...',
                      hintStyle: GoogleFonts.outfit(
                        fontSize: 11, 
                        color: _selectedDiagnosis != null ? text : subtitle.withOpacity(0.5),
                        fontWeight: _selectedDiagnosis != null ? FontWeight.bold : FontWeight.normal,
                      ),
                      prefixIcon: Icon(Icons.search_rounded, size: 16, color: subtitle),
                      suffixIcon: _selectedDiagnosis != null 
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: () => setState(() => _selectedDiagnosis = null),
                            )
                          : const Icon(Icons.arrow_drop_down, size: 18),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                      filled: true,
                      fillColor: inputBg,
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: border)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: purple, width: 1.5)),
                    ),
                    onTap: () {
                      setState(() {
                        _showDiagnosisDropdown = true;
                        _diagnosisSearchQuery = '';
                      });
                    },
                    onChanged: (val) {
                      setState(() {
                        _showDiagnosisDropdown = true;
                        _diagnosisSearchQuery = val;
                      });
                    },
                  ),
                ],
              ),
              if (_showDiagnosisDropdown)
                Positioned(
                  top: 50,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 200,
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: border),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 10, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: ListView(
                        children: mockDiagnoses
                            .where((diag) => diag.toLowerCase().contains(_diagnosisSearchQuery.toLowerCase()))
                            .map((diag) => ListTile(
                                  dense: true,
                                  title: Text(diag, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: text)),
                                  hoverColor: purple.withOpacity(0.08),
                                  onTap: () {
                                    setState(() {
                                      _selectedDiagnosis = diag;
                                      _showDiagnosisDropdown = false;
                                    });
                                  },
                                ))
                            .toList(),
                      ),
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 24),

          // D. STEP 3: THERAPY & PRESCRIPTION
          _sectionTitle('III. DIAGNOSA TERAPI & E-RESEP OBAT', purple),
          const SizedBox(height: 12),
          
          // Added Drugs list table
          if (_addedPrescriptions.isNotEmpty) ...[
            Container(
              decoration: BoxDecoration(
                color: inputBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: border),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _addedPrescriptions.length,
                separatorBuilder: (c, i) => const Divider(height: 1),
                itemBuilder: (context, idx) {
                  final item = _addedPrescriptions[idx];
                  final ObatModel drug = item["obat"];
                  return ListTile(
                    dense: true,
                    leading: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(color: drug.avatarBg.withOpacity(0.15), shape: BoxShape.circle),
                      alignment: Alignment.center,
                      child: Text(drug.nama.substring(0, 1), style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: drug.avatarBg)),
                    ),
                    title: Text(drug.nama, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: text)),
                    subtitle: Text(item["aturan"], style: GoogleFonts.outfit(fontSize: 9, color: subtitle, fontWeight: FontWeight.bold)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${item["jumlah"]} Tablet', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: text)),
                        const SizedBox(width: 12),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 16),
                          onPressed: () {
                            setState(() {
                              _addedPrescriptions.removeAt(idx);
                            });
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Prescription Adder Bar
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search Drug Input
              Expanded(
                flex: 4,
                child: Stack(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: text),
                          decoration: InputDecoration(
                            hintText: _selectedDrug?.nama ?? 'Cari resep obat dari data obat...',
                            hintStyle: GoogleFonts.outfit(
                              fontSize: 11, 
                              color: _selectedDrug != null ? text : subtitle.withOpacity(0.5),
                              fontWeight: _selectedDrug != null ? FontWeight.bold : FontWeight.normal,
                            ),
                            prefixIcon: Icon(Icons.medication_outlined, size: 16, color: subtitle),
                            suffixIcon: _selectedDrug != null 
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 14),
                                    onPressed: () => setState(() => _selectedDrug = null),
                                  )
                                : const Icon(Icons.arrow_drop_down, size: 16),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                            filled: true,
                            fillColor: inputBg,
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: border)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: purple, width: 1.2)),
                          ),
                          onTap: () {
                            setState(() {
                              _showDrugDropdown = true;
                              _drugSearchQuery = '';
                            });
                          },
                          onChanged: (val) {
                            setState(() {
                              _showDrugDropdown = true;
                              _drugSearchQuery = val;
                            });
                          },
                        ),
                      ],
                    ),
                    if (_showDrugDropdown)
                      Positioned(
                        top: 45,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 180,
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: border),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 3)),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: ListView(
                              children: drugList
                                  .where((d) => d.nama.toLowerCase().contains(_drugSearchQuery.toLowerCase()))
                                  .map((d) => ListTile(
                                        dense: true,
                                        title: Text(d.nama, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: text)),
                                        subtitle: Text('Sisa Stok: ${d.totalStok} • Rp ${d.hargaSatuan.toInt()}', style: GoogleFonts.outfit(fontSize: 8, color: subtitle)),
                                        hoverColor: purple.withOpacity(0.06),
                                        onTap: () {
                                          setState(() {
                                            _selectedDrug = d;
                                            _showDrugDropdown = false;
                                          });
                                        },
                                      ))
                                  .toList(),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Qty Input
              Expanded(
                flex: 1,
                child: TextField(
                  controller: _qtyController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: text),
                  decoration: InputDecoration(
                    hintText: 'Jml',
                    hintStyle: GoogleFonts.outfit(fontSize: 11, color: subtitle.withOpacity(0.5)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                    filled: true,
                    fillColor: inputBg,
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: border)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: purple, width: 1.2)),
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Directions Input
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _instructionController,
                  style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: text),
                  decoration: InputDecoration(
                    hintText: 'Dosis & Aturan Pakai',
                    hintStyle: GoogleFonts.outfit(fontSize: 11, color: subtitle.withOpacity(0.5)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    filled: true,
                    fillColor: inputBg,
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: border)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: purple, width: 1.2)),
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Add Button
              ElevatedButton(
                onPressed: () {
                  final drug = _selectedDrug;
                  final qty = int.tryParse(_qtyController.text) ?? 10;
                  final instr = _instructionController.text;
                  if (drug != null) {
                    setState(() {
                      _addedPrescriptions.add({
                        "obat": drug,
                        "aturan": instr,
                        "jumlah": qty,
                      });
                      _selectedDrug = null;
                    });
                  } else {
                    _showWarningDialog('Obat Belum Dipilih', 'Pilih jenis obat dari dropdown data obat terlebih dahulu.');
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: purple,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(40, 40),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                  padding: EdgeInsets.zero,
                ),
                child: const Icon(Icons.add, size: 18),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // E. STEP 4: REFERRAL (Surat Rujukan)
          _sectionTitle('IV. SURAT RUJUKAN PASIEN (OPSIONAL)', purple),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Aktifkan Surat Rujukan',
                    style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: text),
                  ),
                  Text(
                    'Buat rujukan rumah sakit ke RSUD / poli spesialis lanjutan.',
                    style: GoogleFonts.outfit(fontSize: 9, color: subtitle, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Switch(
                value: _wantReferral,
                activeColor: purple,
                onChanged: (val) {
                  setState(() {
                    _wantReferral = val;
                  });
                },
              ),
            ],
          ),
          
          if (_wantReferral) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: inputBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Rumah Sakit Rujukan *', style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w900, color: text)),
                        const SizedBox(height: 4),
                        TextField(
                          controller: _referralRsController,
                          style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: text),
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            isDense: true,
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: border)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: purple)),
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
                        Text('Poli / Bagian Rujukan *', style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w900, color: text)),
                        const SizedBox(height: 4),
                        TextField(
                          controller: _referralPoliController,
                          style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: text),
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            isDense: true,
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: border)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: purple)),
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
                        Text('No. Rujukan (Otomatis)', style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.bold, color: subtitle)),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            border: Border.all(color: border),
                            borderRadius: BorderRadius.circular(8),
                            color: border.withOpacity(0.05),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.link_rounded, size: 10, color: subtitle),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _generatedReferralNo,
                                  style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: subtitle),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Divider(),
          ),

          // F. EMR CONSOLE FOOTER ACTIONS
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {
                  setState(() {
                    _activeQueue = null;
                    _activePatient = null;
                  });
                },
                child: Text(
                  'Batal',
                  style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: subtitle),
                ),
              ),
              const SizedBox(width: 14),
              ElevatedButton(
                onPressed: _startSatuSehatSync,
                style: ElevatedButton.styleFrom(
                  backgroundColor: activeGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.cloud_upload_outlined, size: 16, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      'Simpan & Kirim SatuSehat',
                      style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, Color color) {
    return Text(
      title,
      style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: color, letterSpacing: 0.5),
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
                  style: GoogleFonts.outfit(fontSize: 7.5, fontWeight: FontWeight.w900, color: subtitle),
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
                    style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w900, color: text),
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                Text(
                  unit,
                  style: GoogleFonts.outfit(fontSize: 8.5, fontWeight: FontWeight.bold, color: subtitle),
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
    final waitingOrProcessing = queues.where((q) => q.status == 'Menunggu' || q.status == 'Memproses...').toList();

    return Container(
      height: 600,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: border),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'ANTREAN HARI INI',
            style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: subtitle, letterSpacing: 0.5),
          ),
          const SizedBox(height: 12),
          
          if (waitingOrProcessing.isEmpty)
            Expanded(
              child: Center(
                child: Text(
                  'Tidak ada antrean tersisa.',
                  style: GoogleFonts.outfit(fontSize: 11, color: subtitle, fontWeight: FontWeight.bold),
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
                      color: isCurrentActive ? purple.withOpacity(0.06) : border.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isCurrentActive ? purple : border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              q.no,
                              style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: purple),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: (q.status == 'Menunggu' ? Colors.amber : purple).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: Text(
                                q.status.toUpperCase(),
                                style: GoogleFonts.outfit(
                                  fontSize: 6, 
                                  fontWeight: FontWeight.w900, 
                                  color: q.status == 'Menunggu' ? Colors.amber[700]! : purple,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          q.nama,
                          style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: text),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'NIK: ${q.nik} • ${q.tipe}',
                          style: GoogleFonts.outfit(fontSize: 9, color: subtitle, fontWeight: FontWeight.bold),
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
                              'SEDANG DIPERIKSA',
                              style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white),
                            ),
                          )
                        else
                          ElevatedButton(
                            onPressed: () => _loadPatientFromQueue(q),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: border.withOpacity(0.08),
                              foregroundColor: text,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: Text(
                              q.status == 'Menunggu' ? 'Mulai Periksa' : 'Lanjutkan',
                              style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w900),
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
                        style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: purple, letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _syncStep == 'Connecting'
                            ? 'Menghubungkan ke platform SATUSEHAT Kemenkes...'
                            : (_syncStep == 'SendingEMR'
                                ? 'Mengirim data Rekam Medis Elektronik (RME) terenkripsi...'
                                : 'Menerbitkan E-Resep digital di apotek jejaring...'),
                        style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: text),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Harap tunggu sebentar, data dienkripsi dengan standar SatuSehat FHIR.',
                        style: GoogleFonts.outfit(fontSize: 9, color: subtitle, fontWeight: FontWeight.bold),
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
                          child: Icon(Icons.check_circle_rounded, size: 36, color: activeGreen),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'SINKRONISASI BERHASIL!',
                        style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w900, color: text),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Data Rekam Medis Elektronik telah dikirim secara aman.',
                        style: GoogleFonts.outfit(fontSize: 10, color: subtitle, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      
                      const SizedBox(height: 24),
                      
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
                            _receiptRow('Transaction ID', _txHash, text, subtitle),
                            const Divider(height: 16),
                            _receiptRow('Pasien', _activePatient?.nama ?? '', text, subtitle),
                            const Divider(height: 16),
                            _receiptRow('Diagnosis', _selectedDiagnosis?.split(' (').first ?? '', text, subtitle),
                            const Divider(height: 16),
                            _receiptRow('Resep', '${_addedPrescriptions.length} Jenis Obat', text, subtitle),
                            if (_wantReferral) ...[
                              const Divider(height: 16),
                              _receiptRow('Rujukan Rs', _referralRsController.text, text, subtitle),
                            ],
                            const Divider(height: 16),
                            _receiptRow('SatuSehat status', 'FHIR STAGING OK', activeGreen, subtitle),
                          ],
                        ),
                      ),

                      const SizedBox(height: 28),

                      // Actions
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _completeSyncAndRedirect,
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: border),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: Text(
                                'Tutup',
                                style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: subtitle),
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
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: Text(
                                'Cetak Slip EMR',
                                style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.white),
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
        Text(label, style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.bold, color: subCol)),
        const SizedBox(width: 20),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w900, color: textCol),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
