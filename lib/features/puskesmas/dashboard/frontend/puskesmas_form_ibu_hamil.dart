import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapotech/features/landing/landing_page_data.dart';
import 'package:mapotech/features/puskesmas/dashboard/frontend/puskesmas_pantauan_ibu_hamil.dart';
import 'package:mapotech/shared/widgets/revgeo_wilayah_map_widget.dart';

class PuskesmasFormIbuHamil extends ConsumerStatefulWidget {
  const PuskesmasFormIbuHamil({super.key});

  @override
  ConsumerState<PuskesmasFormIbuHamil> createState() => _PuskesmasFormIbuHamilState();
}

class _PuskesmasFormIbuHamilState extends ConsumerState<PuskesmasFormIbuHamil> {
  final _formKey = GlobalKey<FormState>();

  int _step = 1; // 1: Select Patient & Map, 2: Patient Info & History Table, 3: Form ANC 10T
  IbuHamilModel? _selectedPatient;
  String _searchQuery = '';

  // Controllers
  final TextEditingController _nikController = TextEditingController(text: '3511084205940001');
  final TextEditingController _namaController = TextEditingController(text: 'Siti Rahmawati');
  final TextEditingController _tbController = TextEditingController(text: '158');
  final TextEditingController _bbController = TextEditingController(text: '62');
  final TextEditingController _lilaController = TextEditingController(text: '24.5');
  final TextEditingController _sistoleController = TextEditingController(text: '120');
  final TextEditingController _diastoleController = TextEditingController(text: '80');
  final TextEditingController _tfuController = TextEditingController(text: '26');
  final TextEditingController _djjController = TextEditingController(text: '142');
  final TextEditingController _hbController = TextEditingController(text: '11.5');
  final TextEditingController _catatanController = TextEditingController(text: 'Janin tunggal hidup, presentasi kepala, DJJ teratur 142x/mnt.');

  String _trimester = 'Trimester 3';
  String _kunjungan = 'K4';
  bool _ttdDiberikan = true;
  bool _tripleEliminasiNonReaktif = true;

  // Master Sample Patient Dataset
  final List<IbuHamilModel> _patientList = [
    IbuHamilModel(
      id: 'KIA-001',
      nama: 'Siti Rahmawati',
      nik: '3511084205940001',
      umur: 27,
      namaSuami: 'Budi Santoso',
      usiaKehamilan: '28 Minggu',
      trimester: 'Trimester 3',
      hpl: '14 Agustus 2026',
      ksprStatus: 'Risiko Rendah (KRR)',
      ksprColor: Color(0xFF2ECC71),
      ancStatus: 'K4 Terpenuhi',
      hb: '11.5 g/dL',
      lila: '24.5 cm',
      latitude: -7.9582,
      longitude: 113.9123,
      alamat: 'Dusun Krajan, RT 02/RW 01, Sumber Wringin',
      noTelepon: '0812-3456-7890',
      jumlahKunjungan: 4,
      waktuKunjunganTerakhir: '28 Juli 2026, 09:30 WIB',
      riwayatKunjungan: [
        {
          'kunjungan': 'K1 (Trimester 1)',
          'date': '15 Jan 2026',
          'time': '09:00 WIB',
          'pemeriksa': 'Bidan Anita',
          'catatan': 'Pemeriksaan awal kehamilan trimester 1. Skrining laboratorium dasar lengkap, kondisi fisik ibu dan Janin sangat sehat.'
        },
        {
          'kunjungan': 'K2 (Trimester 2)',
          'date': '20 Mar 2026',
          'time': '10:15 WIB',
          'pemeriksa': 'Bidan Anita',
          'catatan': 'Skrining USG awal trimester 2, detak jantung janin (+) normal, tensi normal, keluhan mual berkurang.'
        },
        {
          'kunjungan': 'K3 (Trimester 2)',
          'date': '18 Mei 2026',
          'time': '08:45 WIB',
          'pemeriksa': 'dr. Hendra Sp.OG',
          'catatan': 'Konsultasi rujukan USG fetomaternal trimester 2. Perkembangan organ janin lengkap, posisi plasenta di fundus.'
        },
        {
          'kunjungan': 'K4 (Trimester 3)',
          'date': '28 Jul 2026',
          'time': '09:30 WIB',
          'pemeriksa': 'Bidan Anita',
          'catatan': 'Evaluasi letak janin (presentasi kepala sudah di bawah). Pemantauan tanda bahaya persalinan & edukasi donor darah keluarga.'
        },
      ],
    ),
    IbuHamilModel(
      id: 'KIA-002',
      nama: 'Dewi Lestari',
      nik: '3511085112960003',
      umur: 34,
      namaSuami: 'Ahmad Fauzi',
      usiaKehamilan: '32 Minggu',
      trimester: 'Trimester 3',
      hpl: '18 Juli 2026',
      ksprStatus: 'Risiko Tinggi (KRT)',
      ksprColor: Color(0xFFE67E22),
      ancStatus: 'K5 Terpenuhi',
      hb: '10.2 g/dL (Anemia Ringan)',
      lila: '22.0 cm (Kek)',
      latitude: -7.9645,
      longitude: 113.9056,
      alamat: 'Dusun Tengah, RT 05/RW 02, Sukorejo',
      noTelepon: '0852-9876-5432',
      jumlahKunjungan: 5,
      waktuKunjunganTerakhir: '25 Juli 2026, 11:15 WIB',
      riwayatKunjungan: [
        {
          'kunjungan': 'K1 (Trimester 1)',
          'date': '10 Des 2025',
          'time': '08:30 WIB',
          'pemeriksa': 'Bidan Rina',
          'catatan': 'Pemeriksaan pertama, Hb 10.5 g/dL (anemia ringan), LILA 22.0 cm (KEK), resep sirup Fe & rujukan PMT.'
        },
        {
          'kunjungan': 'K2 (Trimester 1)',
          'date': '12 Feb 2026',
          'time': '09:45 WIB',
          'pemeriksa': 'dr. Sugeng',
          'catatan': 'Evaluasi gizi LILA 22.0 cm (KEK), rujukan pemantauan nutrisi ketat Puskesmas.'
        },
        {
          'kunjungan': 'K3 (Trimester 2)',
          'date': '15 Apr 2026',
          'time': '10:00 WIB',
          'pemeriksa': 'Bidan Rina',
          'catatan': 'Pemeriksaan berkala, TD 120/80 mmHg, denyut jantung janin normal.'
        },
        {
          'kunjungan': 'K4 (Trimester 2)',
          'date': '20 Mei 2026',
          'time': '09:00 WIB',
          'pemeriksa': 'dr. Hendra Sp.OG',
          'catatan': 'USG Trimester 2, perkiraan BBJ 1.8 kg, posisi melintang.'
        },
        {
          'kunjungan': 'K5 (Trimester 3)',
          'date': '25 Jul 2026',
          'time': '11:15 WIB',
          'pemeriksa': 'Bidan Rina',
          'catatan': 'Monitoring ketat faktor risiko KRT & persiapan P4K (persalinan di RSUD).'
        },
      ],
    ),
    IbuHamilModel(
      id: 'KIA-003',
      nama: 'Anisa Putri',
      nik: '3511086307990002',
      umur: 22,
      namaSuami: 'Rian Pratama',
      usiaKehamilan: '14 Minggu',
      trimester: 'Trimester 2',
      hpl: '20 November 2026',
      ksprStatus: 'Risiko Rendah (KRR)',
      ksprColor: Color(0xFF2ECC71),
      ancStatus: 'K2 Terpenuhi',
      hb: '12.1 g/dL',
      lila: '25.0 cm',
      latitude: -7.9512,
      longitude: 113.9210,
      alamat: 'Dusun Barat, RT 01/RW 03, Tlogosari',
      noTelepon: '0813-1122-3344',
      jumlahKunjungan: 2,
      waktuKunjunganTerakhir: '19 Juli 2026, 08:30 WIB',
      riwayatKunjungan: [
        {
          'kunjungan': 'K1 (Trimester 1)',
          'date': '05 Mei 2026',
          'time': '09:10 WIB',
          'pemeriksa': 'Bidan Anita',
          'catatan': 'Pemeriksaan kehamilan pertama, HPHT 13 Feb 2026, kondisi sangat baik.'
        },
        {
          'kunjungan': 'K2 (Trimester 2)',
          'date': '19 Jul 2026',
          'time': '08:30 WIB',
          'pemeriksa': 'Bidan Anita',
          'catatan': 'Memasuki trimester 2, keluhan mual berkurang, DJJ teratur.'
        },
      ],
    ),
    IbuHamilModel(
      id: 'KIA-004',
      nama: 'Maria Ulfa',
      nik: '3511084903910005',
      umur: 38,
      namaSuami: 'Hendra Wijaya',
      usiaKehamilan: '36 Minggu',
      trimester: 'Trimester 3',
      hpl: '02 Juni 2026',
      ksprStatus: 'Risiko Sangat Tinggi (KRST)',
      ksprColor: Color(0xFFE74C3C),
      ancStatus: 'K6 Terpenuhi',
      hb: '9.8 g/dL',
      lila: '21.5 cm (Kek)',
      latitude: -7.9698,
      longitude: 113.8990,
      alamat: 'Dusun Selatan, RT 04/RW 01, Rejoagung',
      noTelepon: '0877-6543-2100',
      jumlahKunjungan: 6,
      waktuKunjunganTerakhir: '29 Juli 2026, 14:00 WIB',
      riwayatKunjungan: [
        {
          'kunjungan': 'K1 (Trimester 1)',
          'date': '02 Nov 2025',
          'time': '08:15 WIB',
          'pemeriksa': 'dr. Sugeng',
          'catatan': 'Deteksi KRST usia >35 thn, riwayat hipertensi & anemia (Hb 9.5 g/dL).'
        },
        {
          'kunjungan': 'K2 (Trimester 1)',
          'date': '15 Des 2025',
          'time': '09:30 WIB',
          'pemeriksa': 'Bidan Anita',
          'catatan': 'Monitoring tensi 130/80 mmHg & pemberian suplemen asam folat.'
        },
        {
          'kunjungan': 'K3 (Trimester 2)',
          'date': '20 Feb 2026',
          'time': '10:00 WIB',
          'pemeriksa': 'dr. Hendra Sp.OG',
          'catatan': 'Rujukan USG fetomaternal RSUD, kondisi plasenta normal.'
        },
        {
          'kunjungan': 'K4 (Trimester 2)',
          'date': '10 Apr 2026',
          'time': '08:45 WIB',
          'pemeriksa': 'Bidan Anita',
          'catatan': 'Evaluasi Hb (9.8 g/dL), terapi suplemen kombi & PMT ibu hamil.'
        },
        {
          'kunjungan': 'K5 (Trimester 3)',
          'date': '18 Jun 2026',
          'time': '11:30 WIB',
          'pemeriksa': 'dr. Sugeng',
          'catatan': 'Konsultasi rujukan terencana persalinan di RSUD Bondowoso.'
        },
        {
          'kunjungan': 'K6 (Trimester 3)',
          'date': '29 Jul 2026',
          'time': '14:00 WIB',
          'pemeriksa': 'Bidan Anita',
          'catatan': 'Kunjungan rumah pemantauan persiapan persalinan & donor darah.'
        },
      ],
    ),
  ];

  @override
  void dispose() {
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
    super.dispose();
  }

  void _selectPatient(IbuHamilModel patient) {
    setState(() {
      _selectedPatient = patient;
      _nikController.text = patient.nik;
      _namaController.text = patient.nama;
      _trimester = patient.trimester;
      _kunjungan = patient.ancStatus.startsWith('K') ? patient.ancStatus.split(' ').first : 'K4';
      _lilaController.text = patient.lila.replaceAll(RegExp(r'[^0-9.]'), '');
      _hbController.text = patient.hb.replaceAll(RegExp(r'[^0-9.]'), '');
      _step = 2; // Proceed to Step 2: Patient Info & History Table
    });
  }

  void _simpanForm() {
    final state = ref.read(landingPageProvider);
    final themeAccent = ref.read(landingPageProvider.notifier).getPrimaryColor();
    final isEn = state.language == 'en';

    final nikVal = _nikController.text.trim();
    if (nikVal.isNotEmpty && (nikVal.length != 16 || !RegExp(r'^\d{16}$').hasMatch(nikVal))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('NIK Ibu Hamil harus 16 digit angka numerik!'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isEn
              ? 'Form Pemeriksaan Ibu Hamil (ANC 10T) berhasil disimpan & disinkronkan ke SatuSehat RME!'
              : 'Form Pemeriksaan Ibu Hamil (ANC 10T) berhasil disimpan & disinkronkan ke SatuSehat RME!',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        backgroundColor: themeAccent,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(landingPageProvider);
    final notifier = ref.read(landingPageProvider.notifier);

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
                  child: Icon(Icons.assignment_rounded, size: 28, color: themeAccent),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                            style: GoogleFonts.outfit(fontSize: 9, color: subtitleColor, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Form Pemeriksaan Ibu Hamil',
                        style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w900, color: textColor),
                      ),
                      Text(
                        'Pengisian rekam medis digital antenatal care (ANC 10T) otomatis terkoneksi RME SatuSehat & BPJS P-Care.',
                        style: GoogleFonts.outfit(fontSize: 10, color: subtitleColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Render Step based on _step
          if (_step == 1)
            _buildStep1SelectPatient(context, isDark, cardBgColor, textColor, subtitleColor, borderColor, themeAccent, isMobile)
          else if (_step == 2)
            _buildStep2ConfirmInfo(context, isDark, cardBgColor, textColor, subtitleColor, borderColor, themeAccent, isMobile)
          else
            _buildStep3FillForm(context, isDark, cardBgColor, textColor, subtitleColor, borderColor, themeAccent),
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
    final filteredList = _patientList.where((p) {
      final q = _searchQuery.toLowerCase();
      return p.nama.toLowerCase().contains(q) || p.nik.contains(q) || p.id.toLowerCase().contains(q);
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
                        child: Icon(Icons.my_location_rounded, size: 20, color: themeAccent),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PETA GEOTAGGING & LOKASI SAAT INI (LIVE LOCATION)',
                            style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: textColor, letterSpacing: 0.5),
                          ),
                          Text(
                            'Pemetaan posisi lokasi nakes/petugas & titik rumah pasien ibu hamil terdekat',
                            style: GoogleFonts.outfit(fontSize: 10, color: subtitleColor),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2ECC71).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      'GPS Aktif 🟢',
                      style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w900, color: const Color(0xFF2ECC71)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              RevGeoWilayahMapWidget(
                initialProvince: 'JAWA TIMUR',
                initialDistrict: 'KABUPATEN BONDOWOSO',
                initialSubDistrict: 'SUMBER WRINGIN',
                fieldBg: isDark ? const Color(0xFF141824) : const Color(0xFFF1F5F9),
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
                    'color': '#${item.ksprColor.value.toRadixString(16).substring(2)}',
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
                    child: Icon(Icons.person_search_rounded, size: 20, color: themeAccent),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'LANGKAH 1: PILIH PASIEN IBU HAMIL UNTUK PEMERIKSAAN',
                        style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w900, color: textColor),
                      ),
                      Text(
                        'Pilih pasien yang akan diperiksa dari daftar di bawah untuk memuat data & riwayat pemeriksaan.',
                        style: GoogleFonts.outfit(fontSize: 10, color: subtitleColor),
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
                        color: isDark ? const Color(0xFF161B26) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: borderColor),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.search_rounded, size: 18, color: subtitleColor),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              onChanged: (v) => setState(() => _searchQuery = v),
                              style: GoogleFonts.outfit(fontSize: 12, color: textColor),
                              decoration: InputDecoration(
                                hintText: 'Cari NIK, Nama Ibu Hamil, atau ID Kohort...',
                                hintStyle: GoogleFonts.outfit(fontSize: 11, color: subtitleColor),
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                            setState(() {
                              _patientList.insert(0, newPatient);
                              _selectPatient(newPatient); // Auto select new patient!
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Pasien ${newPatient.nama} berhasil ditambahkan & dipilih!'),
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
                      style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold),
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
            return Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => _selectPatient(item),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: cardBgColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: borderColor),
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
                        child: Icon(Icons.face_3_rounded, size: 24, color: themeAccent),
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
                                  style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w900, color: textColor),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: item.ksprColor.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(100),
                                  ),
                                  child: Text(
                                    item.ksprStatus,
                                    style: GoogleFonts.outfit(fontSize: 8, fontWeight: FontWeight.w900, color: item.ksprColor),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'NIK: ${item.nik} • ${item.umur} th • Suami: ${item.namaSuami}',
                              style: GoogleFonts.outfit(fontSize: 10, color: subtitleColor),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '📍 ${item.alamat}',
                              style: GoogleFonts.outfit(fontSize: 9.5, color: subtitleColor, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: themeAccent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                        onPressed: () => _selectPatient(item),
                        icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                        label: Text(
                          'Pilih Pasien',
                          style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
              onPressed: () => setState(() => _step = 1),
              icon: Icon(Icons.arrow_back_rounded, size: 16, color: textColor),
              label: Text('Pilih Pasien Lain', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: textColor)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'LANGKAH 2: KONFIRMASI DATA PASIEN & RIWAYAT KUNJUNGAN',
                style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w900, color: textColor),
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
                          child: Icon(Icons.face_3_rounded, size: 26, color: item.ksprColor),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.nama,
                                style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900, color: textColor),
                              ),
                              const SizedBox(height: 2),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: item.ksprColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(100),
                                ),
                                child: Text(
                                  item.ksprStatus,
                                  style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w900, color: item.ksprColor),
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

                    _buildInfoRow('ID Kohort Pasien', item.id, textColor, subtitleColor),
                    const SizedBox(height: 10),
                    _buildInfoRow('NIK Ibu Hamil', item.nik, textColor, subtitleColor),
                    const SizedBox(height: 10),
                    _buildInfoRow('Usia / Suami', '${item.umur} Thn • ${item.namaSuami}', textColor, subtitleColor),
                    const SizedBox(height: 10),
                    _buildInfoRow('Usia Kehamilan', '${item.usiaKehamilan} (${item.trimester})', themeAccent, subtitleColor),
                    const SizedBox(height: 10),
                    _buildInfoRow('Taksiran Persalinan (HPL)', item.hpl, textColor, subtitleColor),
                    const SizedBox(height: 10),
                    _buildInfoRow('Kadar Hb / LiLA', '${item.hb} | ${item.lila}', textColor, subtitleColor),
                    const SizedBox(height: 10),
                    _buildInfoRow('Nomor Telepon / WA', item.noTelepon, textColor, subtitleColor),
                    const SizedBox(height: 10),
                    _buildInfoRow('Alamat Domisili', item.alamat, textColor, subtitleColor),
                    const SizedBox(height: 10),
                    _buildInfoRow('Koordinat GPS', 'Lat ${item.latitude}, Lng ${item.longitude}', subtitleColor, subtitleColor),
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
                            Icon(Icons.history_rounded, size: 18, color: themeAccent),
                            const SizedBox(width: 8),
                            Text(
                              'JUMLAH & RIWAYAT KUNJUNGAN ANC (${item.jumlahKunjungan}x)',
                              style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: textColor),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: themeAccent.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            item.ancStatus,
                            style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.bold, color: themeAccent),
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
                            color: isDark ? const Color(0xFF161B26) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: borderColor),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: themeAccent.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  r['kunjungan'] ?? 'ANC',
                                  style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: themeAccent),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          '📅 ${r['date']} • 🕒 ${r['time']}',
                                          style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: textColor),
                                        ),
                                        Text(
                                          '👨‍⚕️ ${r['pemeriksa']}',
                                          style: GoogleFonts.outfit(fontSize: 10, color: subtitleColor, fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      r['catatan'] ?? '-',
                                      style: GoogleFonts.outfit(fontSize: 10, color: subtitleColor),
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
                    style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: textColor),
                  ),
                  Text(
                    'Data pasien & riwayat kunjungan akan otomatis terhubung ke Form ANC 10T.',
                    style: GoogleFonts.outfit(fontSize: 10, color: subtitleColor),
                  ),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  elevation: 3,
                ),
                onPressed: () => setState(() => _step = 3),
                icon: const Icon(Icons.edit_note_rounded, size: 20),
                label: Text(
                  'Memulai Pemeriksaan (ANC 10T) ➔',
                  style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w900),
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
              Row(
                children: [
                  Icon(Icons.face_3_rounded, size: 20, color: themeAccent),
                  const SizedBox(width: 10),
                  Text(
                    'Sedang Memeriksa Pasien: ${_selectedPatient?.nama ?? 'Siti Rahmawati'} (NIK: ${_selectedPatient?.nik ?? '3511084205940001'})',
                    style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: textColor),
                  ),
                ],
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: themeAccent),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
                onPressed: () => setState(() => _step = 2),
                icon: Icon(Icons.arrow_back_rounded, size: 14, color: themeAccent),
                label: Text('← Ganti Pasien / Riwayat', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: themeAccent)),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Form Body
        Form(
          key: _formKey,
          child: Column(
            children: [
              // 1. Identitas & Kunjungan
              _buildFormSection(
                '1. Identitas & Status Kunjungan ANC',
                Icons.person_rounded,
                themeAccent,
                cardBgColor,
                borderColor,
                textColor,
                [
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          'NIK Ibu Hamil (16 Digit)',
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
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField('Nama Lengkap Pasien', _namaController, textColor, subtitleColor, borderColor, cardBgColor),
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
                        child: _buildDropdown('Kontak Kunjungan (ANC)', _kunjungan, ['K1', 'K2', 'K3', 'K4', 'K5', 'K6'], (v) {
                          if (v != null) setState(() => _kunjungan = v);
                        }, textColor, cardBgColor, borderColor),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // 2. Pemeriksaan Antropometri & Tensi (1T - 3T)
              _buildFormSection(
                '2. Timbang, Tinggi Badan, Tensi & LiLA (1T - 3T)',
                Icons.monitor_weight_rounded,
                themeAccent,
                cardBgColor,
                borderColor,
                textColor,
                [
                  Row(
                    children: [
                      Expanded(child: _buildTextField('Tinggi Badan (cm)', _tbController, textColor, subtitleColor, borderColor, cardBgColor)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildTextField('Berat Badan (kg)', _bbController, textColor, subtitleColor, borderColor, cardBgColor)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildTextField('LiLA (cm)', _lilaController, textColor, subtitleColor, borderColor, cardBgColor)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildTextField('Sistole (mmHg)', _sistoleController, textColor, subtitleColor, borderColor, cardBgColor)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildTextField('Diastole (mmHg)', _diastoleController, textColor, subtitleColor, borderColor, cardBgColor)),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // 3. Pemeriksaan Janin & TFU (4T - 6T)
              _buildFormSection(
                '3. Tentukan TFU, Presentasi Janin & DJJ (4T - 6T)',
                Icons.child_care_rounded,
                themeAccent,
                cardBgColor,
                borderColor,
                textColor,
                [
                  Row(
                    children: [
                      Expanded(child: _buildTextField('Tinggi Fundus Uteri (TFU) cm', _tfuController, textColor, subtitleColor, borderColor, cardBgColor)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildTextField('Denyut Jantung Janin (DJJ) x/mnt', _djjController, textColor, subtitleColor, borderColor, cardBgColor)),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // 4. Lab & Tablet Tambah Darah (7T - 10T)
              _buildFormSection(
                '4. Lab Hb, TTD, Triple Eliminasi & Temu Wicara (7T - 10T)',
                Icons.science_rounded,
                themeAccent,
                cardBgColor,
                borderColor,
                textColor,
                [
                  Row(
                    children: [
                      Expanded(child: _buildTextField('Kadar Hemoglobin (Hb) g/dL', _hbController, textColor, subtitleColor, borderColor, cardBgColor)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SwitchListTile(
                          activeColor: themeAccent,
                          title: Text('Pemberian TTD (90 Tablet)', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: textColor)),
                          value: _ttdDiberikan,
                          onChanged: (v) => setState(() => _ttdDiberikan = v),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    activeColor: themeAccent,
                    title: Text('Skrining Triple Eliminasi (HIV/Syphilis/Hepatitis B) Non-Reaktif', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: textColor)),
                    value: _tripleEliminasiNonReaktif,
                    onChanged: (v) => setState(() => _tripleEliminasiNonReaktif = v),
                  ),
                  const SizedBox(height: 12),
                  _buildTextField('Catatan Konseling & Temu Wicara Bidan/Dokter', _catatanController, textColor, subtitleColor, borderColor, cardBgColor, maxLines: 3),
                ],
              ),

              const SizedBox(height: 24),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    ),
                    onPressed: () => setState(() => _step = 2),
                    child: Text('Kembali', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: subtitleColor)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: themeAccent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    ),
                    onPressed: _simpanForm,
                    icon: const Icon(Icons.cloud_upload_rounded, color: Colors.white, size: 18),
                    label: Text(
                      'Simpan Form ANC & Sync SatuSehat',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, Color txtColor, Color subColor) {
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
            style: GoogleFonts.outfit(fontSize: 10.5, fontWeight: FontWeight.bold, color: txtColor),
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
    List<Widget> children,
  ) {
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
            children: [
              Icon(icon, size: 18, color: accentColor),
              const SizedBox(width: 10),
              Text(
                title,
                style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w900, color: textColor),
              ),
            ],
          ),
          const Divider(height: 24),
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
        Text(label, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: subColor)),
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
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: ref.read(landingPageProvider.notifier).getPrimaryColor())),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
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
              value: value,
              style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: textColor),
              items: items.map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
