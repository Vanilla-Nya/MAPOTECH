import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapotech/features/landing/landing_page_data.dart';
import 'package:mapotech/shared/widgets/ui.dart';
import 'package:mapotech/shared/widgets/revgeo_wilayah_map_widget.dart';
import 'package:url_launcher/url_launcher.dart';

class IbuHamilModel {
  final String id;
  final String nama;
  final String nik;
  final int umur;
  final String namaSuami;
  final String usiaKehamilan; // e.g. "28 Minggu"
  final String trimester; // "Trimester 1", "Trimester 2", "Trimester 3"
  final String hpl; // Taksiran Persalinan
  final String ksprStatus; // "Risiko Rendah (KRR)", "Risiko Tinggi (KRT)", "Risiko Sangat Tinggi (KRST)"
  final Color ksprColor;
  final String ancStatus; // "K1", "K2", "K3", "K4", "K5", "K6"
  final String hb;
  final String lila;
  final double latitude;
  final double longitude;
  final String alamat;
  final String noTelepon;
  final int jumlahKunjungan;
  final String waktuKunjunganTerakhir;
  final List<Map<String, String>> riwayatKunjungan;

  const IbuHamilModel({
    required this.id,
    required this.nama,
    required this.nik,
    required this.umur,
    required this.namaSuami,
    required this.usiaKehamilan,
    required this.trimester,
    required this.hpl,
    required this.ksprStatus,
    required this.ksprColor,
    required this.ancStatus,
    required this.hb,
    required this.lila,
    this.latitude = -7.9582,
    this.longitude = 113.9123,
    this.alamat = 'Desa Sumber Wringin',
    this.noTelepon = '0812-3456-7890',
    this.jumlahKunjungan = 4,
    this.waktuKunjunganTerakhir = '28 Juli 2026, 09:30 WIB',
    this.riwayatKunjungan = const [],
  });
}

class PuskesmasPantauanIbuHamil extends ConsumerStatefulWidget {
  final ValueChanged<String>? onNavigateToForm;

  const PuskesmasPantauanIbuHamil({
    super.key,
    this.onNavigateToForm,
  });

  @override
  ConsumerState<PuskesmasPantauanIbuHamil> createState() => _PuskesmasPantauanIbuHamilState();
}

class _PuskesmasPantauanIbuHamilState extends ConsumerState<PuskesmasPantauanIbuHamil> {
  String _searchQuery = '';
  String _selectedFilter = 'Semua';

  final List<IbuHamilModel> _dummyData = [
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
          'td': '110/70 mmHg',
          'djj': '140 bpm (Normal)',
          'tfu': '18 cm',
          'bb_tb': '52 kg | 158 cm',
          'hb_lila': '11.8 g/dL | 24.0 cm',
          'protein_urin': 'Negatif | O+',
          'resep': 'Tablet Tambah Darah (Fe 30 Tab), Asam Folat, Kalsium 500mg',
          'catatan': 'Pemeriksaan awal kehamilan trimester 1. Skrining laboratorium dasar lengkap, kondisi fisik ibu dan Janin sangat sehat.',
        },
        {
          'kunjungan': 'K2 (Trimester 2)',
          'date': '20 Mar 2026',
          'time': '10:15 WIB',
          'pemeriksa': 'Bidan Anita',
          'td': '115/75 mmHg',
          'djj': '144 bpm (Teratur)',
          'tfu': '20 cm',
          'bb_tb': '53.5 kg | 158 cm',
          'hb_lila': '11.6 g/dL | 24.2 cm',
          'protein_urin': 'Negatif | O+',
          'resep': 'Suplemen Fe (Tablet Tambah Darah 30 Tab), Kalk Kalsium',
          'catatan': 'Skrining USG awal trimester 2, detak jantung janin (+) normal, tensi normal, keluhan mual muntah sudah berkurang.',
        },
        {
          'kunjungan': 'K3 (Trimester 2)',
          'date': '18 Mei 2026',
          'time': '08:45 WIB',
          'pemeriksa': 'dr. Hendra Sp.OG',
          'catatan': 'Konsultasi rujukan USG fetomaternal trimester 2. Perkembangan organ janin lengkap, posisi plasenta di fundus.',
          'td': '110/70 mmHg',
          'djj': '142 bpm',
          'tfu': '22 cm',
          'bb_tb': '54 kg | 158 cm',
          'hb_lila': '11.5 g/dL | 24.5 cm',
          'protein_urin': 'Negatif',
          'resep': 'Fe 30 hari, Kalsium 500mg, Vitamin C',
        },
        {
          'kunjungan': 'K4 (Trimester 3)',
          'date': '28 Jul 2026',
          'time': '09:30 WIB',
          'pemeriksa': 'Bidan Anita',
          'td': '110/70 mmHg',
          'djj': '145 bpm',
          'tfu': '26 cm',
          'bb_tb': '55 kg | 158 cm',
          'hb_lila': '11.5 g/dL | 24.5 cm',
          'protein_urin': 'Negatif',
          'resep': 'Fe 30 Tab, Suplemen Kalsium, Edukasi P4K',
          'catatan': 'Evaluasi letak janin (presentasi kepala sudah di bawah). Pemantauan tanda bahaya persalinan & edukasi donor darah keluarga.',
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
          'td': '120/80 mmHg',
          'djj': '138 bpm',
          'tfu': '16 cm',
          'bb_tb': '48 kg | 154 cm',
          'hb_lila': '10.5 g/dL | 22.0 cm',
          'protein_urin': 'Negatif',
          'resep': 'Sirup Tambah Darah Fe, PMT Biskuit Ibu Hamil',
          'catatan': 'Pemeriksaan pertama, Hb 10.5 g/dL (anemia ringan), LILA 22.0 cm (KEK), resep sirup Fe & rujukan konseling gizi.',
        },
        {
          'kunjungan': 'K2 (Trimester 1)',
          'date': '12 Feb 2026',
          'time': '09:45 WIB',
          'pemeriksa': 'dr. Sugeng',
          'td': '118/78 mmHg',
          'djj': '140 bpm',
          'tfu': '18 cm',
          'bb_tb': '48.5 kg | 154 cm',
          'hb_lila': '10.3 g/dL | 22.0 cm',
          'protein_urin': 'Negatif',
          'resep': 'Tablet Fe 60 Tab, Suplemen Protein Multi-gizi',
          'catatan': 'Evaluasi gizi KEK & rujukan pemantauan nutrisi ketat Puskesmas.',
        },
        {
          'kunjungan': 'K3 (Trimester 2)',
          'date': '15 Apr 2026',
          'time': '10:00 WIB',
          'pemeriksa': 'Bidan Rina',
          'td': '120/80 mmHg',
          'djj': '142 bpm',
          'tfu': '22 cm',
          'bb_tb': '50 kg | 154 cm',
          'hb_lila': '10.4 g/dL | 22.2 cm',
          'protein_urin': 'Negatif',
          'resep': 'Fe Tablet 30 Tab, Kalsium',
          'catatan': 'Pemeriksaan berkala, TD 120/80 mmHg, denyut jantung janin normal.',
        },
        {
          'kunjungan': 'K4 (Trimester 2)',
          'date': '20 Mei 2026',
          'time': '09:00 WIB',
          'pemeriksa': 'dr. Hendra Sp.OG',
          'td': '122/82 mmHg',
          'djj': '144 bpm',
          'tfu': '24 cm',
          'bb_tb': '51 kg | 154 cm',
          'hb_lila': '10.2 g/dL | 22.0 cm',
          'protein_urin': 'Negatif',
          'resep': 'Tablet Fe Dosis Ganda, Multivitamin',
          'catatan': 'USG Trimester 2, perkiraan BBJ 1.8 kg, posisi melintang.',
        },
        {
          'kunjungan': 'K5 (Trimester 3)',
          'date': '25 Jul 2026',
          'time': '11:15 WIB',
          'pemeriksa': 'Bidan Rina',
          'td': '120/80 mmHg',
          'djj': '140 bpm',
          'tfu': '28 cm',
          'bb_tb': '52 kg | 154 cm',
          'hb_lila': '10.2 g/dL | 22.0 cm',
          'protein_urin': 'Negatif',
          'resep': 'Fe Tablet, Persiapan Stiker P4K',
          'catatan': 'Monitoring ketat faktor risiko KRT & persiapan P4K (persalinan di RSUD).',
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
          'td': '110/70 mmHg',
          'djj': '138 bpm',
          'tfu': '12 cm',
          'bb_tb': '50 kg | 160 cm',
          'hb_lila': '12.3 g/dL | 25.0 cm',
          'protein_urin': 'Negatif',
          'resep': 'Asam Folat 400mcg, Fe 30 Tab',
          'catatan': 'Pemeriksaan kehamilan pertama, HPHT 13 Feb 2026, kondisi sangat baik.',
        },
        {
          'kunjungan': 'K2 (Trimester 2)',
          'date': '19 Jul 2026',
          'time': '08:30 WIB',
          'pemeriksa': 'Bidan Anita',
          'td': '112/72 mmHg',
          'djj': '142 bpm',
          'tfu': '14 cm',
          'bb_tb': '51.5 kg | 160 cm',
          'hb_lila': '12.1 g/dL | 25.0 cm',
          'protein_urin': 'Negatif',
          'resep': 'Fe 30 Tab, Kalsium 500mg',
          'catatan': 'Memasuki trimester 2, keluhan mual berkurang, DJJ teratur.',
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
          'td': '135/85 mmHg',
          'djj': '140 bpm',
          'tfu': '14 cm',
          'bb_tb': '58 kg | 152 cm',
          'hb_lila': '9.5 g/dL | 21.0 cm',
          'protein_urin': 'Trace',
          'resep': 'Antihipertensi Aman Hamil, Fe Sirup, Asam Folat',
          'catatan': 'Deteksi KRST usia >35 thn, riwayat hipertensi & anemia (Hb 9.5 g/dL).',
        },
        {
          'kunjungan': 'K2 (Trimester 1)',
          'date': '15 Des 2025',
          'time': '09:30 WIB',
          'pemeriksa': 'Bidan Anita',
          'td': '130/80 mmHg',
          'djj': '142 bpm',
          'tfu': '16 cm',
          'bb_tb': '58.5 kg | 152 cm',
          'hb_lila': '9.6 g/dL | 21.2 cm',
          'protein_urin': 'Negatif',
          'resep': 'Fe 60 Tab, Kalsium',
          'catatan': 'Monitoring tensi 130/80 mmHg & pemberian suplemen asam folat.',
        },
        {
          'kunjungan': 'K3 (Trimester 2)',
          'date': '20 Feb 2026',
          'time': '10:00 WIB',
          'pemeriksa': 'dr. Hendra Sp.OG',
          'td': '128/82 mmHg',
          'djj': '145 bpm',
          'tfu': '20 cm',
          'bb_tb': '59 kg | 152 cm',
          'hb_lila': '9.7 g/dL | 21.5 cm',
          'protein_urin': 'Negatif',
          'resep': 'Rujukan Konsultasi RSUD Bondowoso',
          'catatan': 'Rujukan USG fetomaternal RSUD, kondisi plasenta normal.',
        },
        {
          'kunjungan': 'K4 (Trimester 2)',
          'date': '10 Apr 2026',
          'time': '08:45 WIB',
          'pemeriksa': 'Bidan Anita',
          'td': '125/80 mmHg',
          'djj': '140 bpm',
          'tfu': '24 cm',
          'bb_tb': '60 kg | 152 cm',
          'hb_lila': '9.8 g/dL | 21.5 cm',
          'protein_urin': 'Negatif',
          'resep': 'Fe Kombi, PMT Susu Ibu Hamil',
          'catatan': 'Evaluasi Hb (9.8 g/dL), terapi suplemen kombi & PMT ibu hamil.',
        },
        {
          'kunjungan': 'K5 (Trimester 3)',
          'date': '18 Jun 2026',
          'time': '11:30 WIB',
          'pemeriksa': 'dr. Sugeng',
          'td': '130/85 mmHg',
          'djj': '142 bpm',
          'tfu': '28 cm',
          'bb_tb': '61 kg | 152 cm',
          'hb_lila': '9.8 g/dL | 21.5 cm',
          'protein_urin': 'Negatif',
          'resep': 'Surat Rujukan Terencana RSUD',
          'catatan': 'Konsultasi rujukan terencana persalinan di RSUD Bondowoso.',
        },
        {
          'kunjungan': 'K6 (Trimester 3)',
          'date': '29 Jul 2026',
          'time': '14:00 WIB',
          'pemeriksa': 'Bidan Anita',
          'td': '128/80 mmHg',
          'djj': '144 bpm',
          'tfu': '32 cm',
          'bb_tb': '62 kg | 152 cm',
          'hb_lila': '9.8 g/dL | 21.5 cm',
          'protein_urin': 'Negatif',
          'resep': 'Persiapan Ambulance & Donor Darah Siaga',
          'catatan': 'Kunjungan rumah (home visit) pemantauan persiapan persalinan & donor darah.',
        },
      ],
    ),
  ];

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

    final filteredList = _dummyData.where((item) {
      final q = _searchQuery.toLowerCase();
      final matchesQuery = item.nama.toLowerCase().contains(q) ||
          item.nik.contains(q) ||
          item.id.toLowerCase().contains(q);

      if (_selectedFilter == 'Risiko Tinggi') {
        return matchesQuery && (item.ksprStatus.contains('Tinggi'));
      } else if (_selectedFilter == 'Trimester 3') {
        return matchesQuery && item.trimester == 'Trimester 3';
      }
      return matchesQuery;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top Banner Header
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
                child: Icon(Icons.pregnant_woman_rounded, size: 30, color: themeAccent),
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
                            'DLC INOVASI KIA - PUSKESMAS',
                            style: GoogleFonts.outfit(
                              fontSize: 7,
                              fontWeight: FontWeight.w900,
                              color: themeAccent,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'SatuSehat & e-Kohort KIA',
                          style: GoogleFonts.outfit(fontSize: 9, color: subtitleColor, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Modul Pantauan Ibu Hamil (ANC)',
                      style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w900, color: textColor),
                    ),
                    Text(
                      'Pemantauan status kehamilan, estimasi persalinan (HPL), dan pemetaan risiko tinggi KSPR Puskesmas.',
                      style: GoogleFonts.outfit(fontSize: 10, color: subtitleColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Summary Metric Cards
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: isMobile ? 2 : 4,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.6,
          children: [
            MetricCard(
              icon: Icons.pregnant_woman_rounded,
              label: 'TOTAL IBU HAMIL TERDATA',
              count: '42 Pasien',
              subtitleColor: subtitleColor,
              countColor: textColor,
              cardBgColor: cardBgColor,
              borderColor: borderColor,
            ),
            MetricCard(
              icon: Icons.warning_rounded,
              label: 'RISIKO TINGGI (KRT/KRST)',
              count: '6 Pasien',
              subtitleColor: subtitleColor,
              countColor: const Color(0xFFE74C3C),
              cardBgColor: cardBgColor,
              borderColor: borderColor,
            ),
            MetricCard(
              icon: Icons.calendar_month_rounded,
              label: 'HPL BULAN INI',
              count: '8 Persalinan',
              subtitleColor: subtitleColor,
              countColor: const Color(0xFF3498DB),
              cardBgColor: cardBgColor,
              borderColor: borderColor,
            ),
            MetricCard(
              icon: Icons.verified_user_rounded,
              label: 'CAPAIAN K6 ANC',
              count: '94.2%',
              subtitleColor: subtitleColor,
              countColor: const Color(0xFF2ECC71),
              cardBgColor: cardBgColor,
              borderColor: borderColor,
            ),
          ],
        ),

        const SizedBox(height: 24),

        // ==================== MAP SECTION WITH PATIENT PINS ====================
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
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: themeAccent.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.location_on_rounded, size: 20, color: themeAccent),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'PETA LOKASI PASIEN IBU HAMIL (ANC)',
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: textColor,
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              'Pemetaan geotagging domisili tempat tinggal pasien & status krisikoan kehamilan (KSPR)',
                              style: GoogleFonts.outfit(fontSize: 10, color: subtitleColor),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (!isMobile)
                    Row(
                      children: [
                        _buildLegendBadge('🟢 KRR (Rendah)', const Color(0xFF2ECC71)),
                        const SizedBox(width: 8),
                        _buildLegendBadge('🟠 KRT (Tinggi)', const Color(0xFFE67E22)),
                        const SizedBox(width: 8),
                        _buildLegendBadge('🔴 KRST (Sgt Tinggi)', const Color(0xFFE74C3C)),
                      ],
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
                isEn: state.language == 'en',
                height: 420,
                showOnlyMap: true,
                markers: filteredList.map((item) {
                  final colorHex = '#${item.ksprColor.value.toRadixString(16).substring(2)}';
                  return {
                    'lat': item.latitude,
                    'lng': item.longitude,
                    'title': '🤰 ${item.nama} (${item.umur} th)',
                    'subtitle': item.ksprStatus,
                    'info': '• Usia Hamil: ${item.usiaKehamilan}<br/>• HPL: ${item.hpl}<br/>• Suami: ${item.namaSuami}',
                    'details': '📍 ${item.alamat}',
                    'color': colorHex,
                  };
                }).toList(),
                onChanged: (_, __, ___, ____) {},
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Search & Filter controls
        Row(
          children: [
            Expanded(
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: cardBgColor,
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
                          hintText: 'Cari NIK, Nama Ibu Hamil, atau No. Kohort...',
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              height: 44,
              decoration: BoxDecoration(
                color: cardBgColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedFilter,
                  icon: Icon(Icons.filter_list_rounded, size: 18, color: themeAccent),
                  style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: textColor),
                  dropdownColor: cardBgColor,
                  items: ['Semua', 'Risiko Tinggi', 'Trimester 3'].map((f) {
                    return DropdownMenuItem(value: f, child: Text(f));
                  }).toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _selectedFilter = v);
                  },
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
                        _dummyData.insert(0, newPatient);
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Pasien ${newPatient.nama} berhasil ditambahkan!'),
                          backgroundColor: const Color(0xFF2ECC71),
                        ),
                      );
                    },
                  ),
                );
              },
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
              label: Text(
                '+ Tambah Pasien',
                style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // List of Ibu Hamil Cards
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: filteredList.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final item = filteredList[index];
            return Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  _showPatientDetailModal(
                    context,
                    item,
                    cardBgColor,
                    textColor,
                    subtitleColor,
                    borderColor,
                    themeAccent,
                    isDark,
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardBgColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: themeAccent.withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Icon(Icons.face_3_rounded, size: 22, color: themeAccent),
                          ),
                          const SizedBox(width: 12),
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
                                    const SizedBox(width: 6),
                                    Icon(Icons.touch_app_rounded, size: 12, color: themeAccent.withOpacity(0.7)),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'NIK: ${item.nik} • ${item.umur} th • Suami: ${item.namaSuami}',
                                  style: GoogleFonts.outfit(fontSize: 10, color: subtitleColor),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.pin_drop_rounded, size: 12, color: themeAccent),
                                    const SizedBox(width: 4),
                                    Text(
                                      item.alamat,
                                      style: GoogleFonts.outfit(fontSize: 9.5, color: subtitleColor, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Divider(height: 1),
                      ),

                      // Data Grid Info
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildMiniInfo('Usia Kehamilan', item.usiaKehamilan, subtitleColor, textColor),
                          _buildMiniInfo('Taksiran Persalinan', item.hpl, subtitleColor, textColor),
                          _buildMiniInfo('Status Kunjungan', item.ancStatus, subtitleColor, themeAccent),
                          _buildMiniInfo('Kadar Hb / LiLA', '${item.hb} | ${item.lila}', subtitleColor, textColor),
                        ],
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

  Widget _buildLegendBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  Widget _buildMiniInfo(String label, String val, Color subColor, Color mainColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.outfit(fontSize: 8, color: subColor, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(val, style: GoogleFonts.outfit(fontSize: 10, color: mainColor, fontWeight: FontWeight.bold)),
      ],
    );
  }

  void _showPatientDetailModal(
    BuildContext context,
    IbuHamilModel item,
    Color cardBgColor,
    Color textColor,
    Color subtitleColor,
    Color borderColor,
    Color themeAccent,
    bool isDark,
  ) {
    showDialog(
      context: context,
      builder: (ctx) {
        return PatientAncDetailModal(
          item: item,
          cardBgColor: cardBgColor,
          textColor: textColor,
          subtitleColor: subtitleColor,
          borderColor: borderColor,
          themeAccent: themeAccent,
          isDark: isDark,
          onNavigateToForm: widget.onNavigateToForm,
        );
      },
    );
  }
}

// ─── REUSABLE PATIENT ANC DETAIL MODAL ────────────────────────────────────────

class PatientAncDetailModal extends StatefulWidget {
  final IbuHamilModel item;
  final Color cardBgColor;
  final Color textColor;
  final Color subtitleColor;
  final Color borderColor;
  final Color themeAccent;
  final bool isDark;
  final ValueChanged<String>? onNavigateToForm;

  const PatientAncDetailModal({
    super.key,
    required this.item,
    required this.cardBgColor,
    required this.textColor,
    required this.subtitleColor,
    required this.borderColor,
    required this.themeAccent,
    required this.isDark,
    this.onNavigateToForm,
  });

  @override
  State<PatientAncDetailModal> createState() => _PatientAncDetailModalState();
}

class _PatientAncDetailModalState extends State<PatientAncDetailModal> {
  Map<String, String>? _selectedVisitDetail;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: widget.cardBgColor,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        constraints: const BoxConstraints(maxWidth: 750, maxHeight: 850),
        child: _selectedVisitDetail != null
            ? _buildSingleVisitDetailView(context)
            : _buildMainTabView(context),
      ),
    );
  }

  // Main 2-Tab View (Informasi & Pemeriksaan)
  Widget _buildMainTabView(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            decoration: BoxDecoration(
              color: widget.isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(bottom: BorderSide(color: widget.borderColor)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: widget.item.ksprColor.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Icon(Icons.face_3_rounded, size: 26, color: widget.item.ksprColor),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                widget.item.nama,
                                style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900, color: widget.textColor),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(
                                  color: widget.item.ksprColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(100),
                                  border: Border.all(color: widget.item.ksprColor.withOpacity(0.3)),
                                ),
                                child: Text(
                                  widget.item.ksprStatus,
                                  style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w900, color: widget.item.ksprColor),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'ID Kohort: ${widget.item.id} • NIK: ${widget.item.nik} • ${widget.item.umur} Tahun',
                            style: GoogleFonts.outfit(fontSize: 11, color: widget.subtitleColor),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                      color: widget.subtitleColor,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  height: 42,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: widget.isDark ? const Color(0xFF161B26) : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TabBar(
                    indicator: BoxDecoration(
                      color: widget.themeAccent,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    labelColor: Colors.white,
                    unselectedLabelColor: widget.subtitleColor,
                    labelStyle: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.bold),
                    unselectedLabelStyle: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.w600),
                    dividerColor: Colors.transparent,
                    indicatorSize: TabBarIndicatorSize.tab,
                    tabs: const [
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.person_pin_rounded, size: 16),
                            SizedBox(width: 6),
                            Text('Informasi Pasien & Lokasi'),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.analytics_rounded, size: 16),
                            SizedBox(width: 6),
                            Text('Pemeriksaan & Statistik'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Tab Content Body
          Expanded(
            child: TabBarView(
              children: [
                // TAB 1: INFORMASI PASIEN & LOKASI
                SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 2.3,
                        children: [
                          _buildModalMetricTile('Usia Kehamilan', '${widget.item.usiaKehamilan} (${widget.item.trimester})', Icons.pregnant_woman_rounded, widget.themeAccent, widget.cardBgColor, widget.borderColor, widget.textColor, widget.subtitleColor),
                          _buildModalMetricTile('Taksiran Persalinan', widget.item.hpl, Icons.calendar_month_rounded, const Color(0xFF3498DB), widget.cardBgColor, widget.borderColor, widget.textColor, widget.subtitleColor),
                          _buildModalMetricTile('Kadar Hb / LiLA', '${widget.item.hb} | ${widget.item.lila}', Icons.monitor_heart_rounded, const Color(0xFFE67E22), widget.cardBgColor, widget.borderColor, widget.textColor, widget.subtitleColor),
                          _buildModalMetricTile('Status Kunjungan', '${widget.item.jumlahKunjungan}x Kunjungan (${widget.item.ancStatus})', Icons.event_available_rounded, const Color(0xFF2ECC71), widget.cardBgColor, widget.borderColor, widget.textColor, widget.subtitleColor),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _buildModalSectionHeader('DATA PASIEN & KELUARGA', Icons.person_pin_rounded, widget.themeAccent, widget.textColor),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: widget.isDark ? const Color(0xFF161B26) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: widget.borderColor),
                        ),
                        child: Column(
                          children: [
                            _buildDetailRow('Nama Suami', widget.item.namaSuami, widget.textColor, widget.subtitleColor),
                            const Divider(height: 16),
                            _buildDetailRow('Nomor HP / WA', widget.item.noTelepon, widget.textColor, widget.subtitleColor),
                            const Divider(height: 16),
                            _buildDetailRow('Waktu Kunjungan Terakhir', widget.item.waktuKunjunganTerakhir, widget.themeAccent, widget.subtitleColor),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildModalSectionHeader('LOKASI TEMPAT TINGGAL & GEOTAGGING', Icons.map_rounded, widget.themeAccent, widget.textColor),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: widget.isDark ? const Color(0xFF161B26) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: widget.borderColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.location_on_rounded, size: 18, color: widget.themeAccent),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        widget.item.alamat,
                                        style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: widget.textColor),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Koordinat GPS: Lat ${widget.item.latitude}, Lng ${widget.item.longitude}',
                                        style: GoogleFonts.outfit(fontSize: 10, color: widget.subtitleColor),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            RevGeoWilayahMapWidget(
                              initialProvince: 'JAWA TIMUR',
                              initialDistrict: 'KABUPATEN BONDOWOSO',
                              initialSubDistrict: 'SUMBER WRINGIN',
                              fieldBg: widget.isDark ? const Color(0xFF141824) : const Color(0xFFF1F5F9),
                              textColor: widget.textColor,
                              subtitleColor: widget.subtitleColor,
                              borderColor: widget.borderColor,
                              dropdownColor: widget.isDark ? const Color(0xFF1B1B1E) : Colors.white,
                              themeAccent: widget.themeAccent,
                              isDark: widget.isDark,
                              isEn: false,
                              height: 200,
                              showOnlyMap: true,
                              markers: [
                                {
                                  'lat': widget.item.latitude,
                                  'lng': widget.item.longitude,
                                  'title': '🤰 ${widget.item.nama}',
                                  'subtitle': widget.item.ksprStatus,
                                  'info': 'No. HP: ${widget.item.noTelepon}',
                                  'details': '📍 ${widget.item.alamat}',
                                  'color': '#${widget.item.ksprColor.value.toRadixString(16).substring(2)}',
                                }
                              ],
                              onChanged: (_, __, ___, ____) {},
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // TAB 2: PEMERIKSAAN & STATISTIK
                SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildModalSectionHeader('STATISTIK CAPAIAN KUNJUNGAN & DETEKSI DINI (K1 ≤ 16 WEEKS)', Icons.pie_chart_rounded, widget.themeAccent, widget.textColor),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: widget.isDark ? const Color(0xFF161B26) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: widget.borderColor),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 120,
                              height: 120,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  CustomPaint(
                                    size: const Size(110, 110),
                                    painter: PieChartPainter(
                                      segments: [
                                        PieChartSegment('Kunjungan Selesai', widget.item.jumlahKunjungan.toDouble(), const Color(0xFF2ECC71)),
                                        PieChartSegment('Sisa Target ANC', (6 - widget.item.jumlahKunjungan).clamp(0, 6).toDouble(), const Color(0xFF3498DB).withOpacity(0.3)),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        '${((widget.item.jumlahKunjungan / 6) * 100).toStringAsFixed(0)}%',
                                        style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900, color: widget.textColor),
                                      ),
                                      Text(
                                        'ANC K6',
                                        style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.bold, color: widget.subtitleColor),
                                      ),
                                    ],
                                  ),
                                ],
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
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF2ECC71).withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          'K1 ≤ 16 Minggu: Tepat Waktu ✅',
                                          style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: const Color(0xFF2ECC71)),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Target Skrining Awal K1 Kemenkes Maksimal 16 Minggu Usia Kehamilan.',
                                    style: GoogleFonts.outfit(fontSize: 9.5, color: widget.subtitleColor),
                                  ),
                                  const SizedBox(height: 8),
                                  _buildLegendItem('🟢 Capaian Kunjungan', '${widget.item.jumlahKunjungan} / 6 Selesai', widget.textColor),
                                  const SizedBox(height: 4),
                                  _buildLegendItem('🔵 Usia Kehamilan Terdeteksi', '${widget.item.usiaKehamilan} (Maks 16 Mgg)', widget.textColor),
                                  const SizedBox(height: 4),
                                  _buildLegendItem('🟠 Estimasi Hari Lahir (HPL)', widget.item.hpl, widget.textColor),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Notification Action Button
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: widget.themeAccent.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: widget.themeAccent.withOpacity(0.3)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: widget.themeAccent.withOpacity(0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.send_rounded, size: 20, color: widget.themeAccent),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'NOTIFIKASI JADWAL KUNJUNGAN PASIEN',
                                        style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: widget.textColor),
                                      ),
                                      Text(
                                        'Ingatkan pasien jadwal kunjungan ulang via WhatsApp, SMS, atau Panggilan Telepon.',
                                        style: GoogleFonts.outfit(fontSize: 9.5, color: widget.subtitleColor),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF25D366),
                                foregroundColor: Colors.white,
                                minimumSize: const Size(double.infinity, 44),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 2,
                              ),
                              onPressed: () {
                                _showNotifyPatientModal(context, widget.item, widget.isDark, widget.cardBgColor, widget.textColor, widget.subtitleColor, widget.borderColor);
                              },
                              icon: const Icon(Icons.mark_chat_read_rounded, size: 18),
                              label: Text(
                                'Beritahu Kunjungan ke Pasien (WA / SMS / Telp)',
                                style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Interactive History of Visits List (Clickable!)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildModalSectionHeader('JUMLAH & RIWAYAT KUNJUNGAN ANC (${widget.item.jumlahKunjungan}x)', Icons.history_rounded, widget.themeAccent, widget.textColor),
                          Text(
                            '💡 Klik item untuk detail lengkap & foto',
                            style: GoogleFonts.outfit(fontSize: 9.5, color: widget.themeAccent, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: widget.item.riwayatKunjungan.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, idx) {
                          final r = widget.item.riwayatKunjungan[idx];
                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () {
                                setState(() {
                                  _selectedVisitDetail = r;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: widget.isDark ? const Color(0xFF161B26) : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: widget.borderColor),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: widget.themeAccent.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        r['kunjungan'] ?? 'ANC',
                                        style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: widget.themeAccent),
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
                                                style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: widget.textColor),
                                              ),
                                              Text(
                                                '👨‍⚕️ ${r['pemeriksa']}',
                                                style: GoogleFonts.outfit(fontSize: 10, color: widget.subtitleColor, fontWeight: FontWeight.w600),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            r['catatan'] ?? '-',
                                            style: GoogleFonts.outfit(fontSize: 10, color: widget.subtitleColor),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Icon(Icons.arrow_forward_ios_rounded, size: 14, color: widget.themeAccent),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Footer Actions
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: widget.isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
              border: Border(top: BorderSide(color: widget.borderColor)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, size: 16),
                  label: Text('Tutup', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: TextButton.styleFrom(foregroundColor: widget.subtitleColor),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.themeAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    elevation: 2,
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    if (widget.onNavigateToForm != null) {
                      widget.onNavigateToForm!('dlc_form_ibu_hamil');
                    }
                  },
                  icon: const Icon(Icons.edit_document, size: 16, color: Colors.white),
                  label: Text(
                    'Form ANC 10T',
                    style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Nested Detailed Visit Report View (Within the Same Modal!)
  Widget _buildSingleVisitDetailView(BuildContext context) {
    final v = _selectedVisitDetail!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Sub-view Header with Back Button
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: widget.isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(bottom: BorderSide(color: widget.borderColor)),
          ),
          child: Row(
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: widget.themeAccent),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                onPressed: () {
                  setState(() {
                    _selectedVisitDetail = null;
                  });
                },
                icon: Icon(Icons.arrow_back_rounded, size: 16, color: widget.themeAccent),
                label: Text(
                  'Kembali',
                  style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: widget.themeAccent),
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
                          'Detail Pemeriksaan ${v['kunjungan']}',
                          style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w900, color: widget.textColor),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2ECC71).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(
                            'Home Visit Valid ✅',
                            style: GoogleFonts.outfit(fontSize: 8, fontWeight: FontWeight.w900, color: const Color(0xFF2ECC71)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Tanggal: ${v['date']} • Jam: ${v['time']} • Pemeriksa: ${v['pemeriksa']}',
                      style: GoogleFonts.outfit(fontSize: 10, color: widget.subtitleColor),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
                color: widget.subtitleColor,
              ),
            ],
          ),
        ),

        // Scrollable Detail Report Content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Evidence Photo & Geotagging Card
                _buildModalSectionHeader('BUKTI FOTO KUNJUNGAN LAPANGAN & GEOTAGGING', Icons.photo_camera_rounded, widget.themeAccent, widget.textColor),
                const SizedBox(height: 10),
                Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: widget.isDark ? const Color(0xFF161B26) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: widget.borderColor),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stack(
                        children: [
                          // Photo container
                          SizedBox(
                            height: 220,
                            width: double.infinity,
                            child: Image.asset(
                              'assets/images/anc_home_visit_evidence.png',
                              fit: BoxFit.cover,
                              errorBuilder: (ctx, err, stack) {
                                return Container(
                                  color: widget.themeAccent.withOpacity(0.1),
                                  alignment: Alignment.center,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.camera_alt_rounded, size: 40, color: widget.themeAccent),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Dokumentasi Kunjungan Lapangan',
                                        style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: widget.textColor),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                          // Geotagging Badge Overlay
                          Positioned(
                            bottom: 12,
                            left: 12,
                            right: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.75),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.location_on_rounded, color: Color(0xFF2ECC71), size: 16),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '📍 ${widget.item.alamat}',
                                          style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          'GPS: Lat ${widget.item.latitude}, Lng ${widget.item.longitude} • Waktu: ${v['date']} ${v['time']}',
                                          style: GoogleFonts.outfit(fontSize: 8.5, color: Colors.white70),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Icon(Icons.verified_user_rounded, size: 16, color: widget.themeAccent),
                            const SizedBox(width: 8),
                            Text(
                              'Dokumentasi Resmi Pemeriksaan Kunjungan Rumah (Home Visit)',
                              style: GoogleFonts.outfit(fontSize: 10.5, fontWeight: FontWeight.bold, color: widget.textColor),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // 2. Clinical Vitals & Screening Grid
                _buildModalSectionHeader('HASIL SKRINING & VITAL SIGN KLINIS', Icons.monitor_heart_rounded, widget.themeAccent, widget.textColor),
                const SizedBox(height: 10),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 2.3,
                  children: [
                    _buildModalMetricTile('Tekanan Darah', v['td'] ?? '110/70 mmHg', Icons.speed_rounded, const Color(0xFF3498DB), widget.cardBgColor, widget.borderColor, widget.textColor, widget.subtitleColor),
                    _buildModalMetricTile('Denyut Jantung Janin', v['djj'] ?? '142 bpm (Normal)', Icons.favorite_rounded, widget.themeAccent, widget.cardBgColor, widget.borderColor, widget.textColor, widget.subtitleColor),
                    _buildModalMetricTile('Tinggi Fundus (TFU)', v['tfu'] ?? '24 cm', Icons.straighten_rounded, const Color(0xFFE67E22), widget.cardBgColor, widget.borderColor, widget.textColor, widget.subtitleColor),
                    _buildModalMetricTile('Berat & Tinggi Badan', v['bb_tb'] ?? '54 kg | 158 cm', Icons.fitness_center_rounded, const Color(0xFF9B59B6), widget.cardBgColor, widget.borderColor, widget.textColor, widget.subtitleColor),
                    _buildModalMetricTile('Kadar Hb & LiLA', v['hb_lila'] ?? '${widget.item.hb} | ${widget.item.lila}', Icons.bloodtype_rounded, const Color(0xFF2ECC71), widget.cardBgColor, widget.borderColor, widget.textColor, widget.subtitleColor),
                    _buildModalMetricTile('Protein Urin & Gol. Darah', v['protein_urin'] ?? 'Negatif | O+', Icons.science_rounded, const Color(0xFF1ABC9C), widget.cardBgColor, widget.borderColor, widget.textColor, widget.subtitleColor),
                  ],
                ),

                const SizedBox(height: 20),

                // 3. Treatment & Clinical Diagnosis Notes
                _buildModalSectionHeader('RESEP OBAT & CATATAN MEDIS BIDAN', Icons.medication_rounded, widget.themeAccent, widget.textColor),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: widget.isDark ? const Color(0xFF161B26) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: widget.borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.local_pharmacy_rounded, size: 16, color: widget.themeAccent),
                          const SizedBox(width: 8),
                          Text('Resep / Suplemen Diberikan:', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: widget.textColor)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        v['resep'] ?? 'Tablet Tambah Darah (Fe) 30 Tablet, Kalsium 500mg, Suplemen Asam Folat',
                        style: GoogleFonts.outfit(fontSize: 10.5, color: widget.subtitleColor),
                      ),
                      const Divider(height: 20),
                      Row(
                        children: [
                          Icon(Icons.note_alt_rounded, size: 16, color: widget.themeAccent),
                          const SizedBox(width: 8),
                          Text('Catatan Hasil Pemeriksaan:', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: widget.textColor)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        v['catatan'] ?? 'Pemeriksaan kehamilan rutin berjalan baik. Kondisi kesehatan ibu dan janin dalam batas normal.',
                        style: GoogleFonts.outfit(fontSize: 10.5, color: widget.textColor, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Sub-view Action Footer
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: widget.isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03),
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
            border: Border(top: BorderSide(color: widget.borderColor)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: widget.borderColor),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  setState(() {
                    _selectedVisitDetail = null;
                  });
                },
                icon: const Icon(Icons.arrow_back_rounded, size: 16),
                label: Text('Kembali ke List', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.themeAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  elevation: 2,
                ),
                onPressed: () {
                  Navigator.pop(context);
                  if (widget.onNavigateToForm != null) {
                    widget.onNavigateToForm!('dlc_form_ibu_hamil');
                  }
                },
                icon: const Icon(Icons.edit_document, size: 16, color: Colors.white),
                label: Text(
                  'Form ANC 10T',
                  style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showNotifyPatientModal(
    BuildContext context,
    IbuHamilModel item,
    bool isDark,
    Color cardBgColor,
    Color textColor,
    Color subtitleColor,
    Color borderColor,
  ) {
    String cleanPhone = item.noTelepon.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanPhone.startsWith('0')) {
      cleanPhone = '62${cleanPhone.substring(1)}';
    }

    final rawMessage =
        'Halo Ibu ${item.nama}, salam hangat dari Puskesmas.\n\n'
        'Mengingatkan jadwal kunjungan ulang pemeriksaan kehamilan (ANC) Anda (${item.ancStatus}).\n'
        'Usia kehamilan Anda saat ini: ${item.usiaKehamilan}. Mohon untuk melakukan kunjungan sesuai jadwal.\n\n'
        'Terima Kasih, Salam Sehat.';

    final messageText = Uri.encodeComponent(rawMessage);

    showDialog(
      context: context,
      builder: (nCtx) {
        return Dialog(
          backgroundColor: cardBgColor,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            width: 440,
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                            color: const Color(0xFF25D366).withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.mark_chat_read_rounded, size: 22, color: Color(0xFF25D366)),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Beritahu Kunjungan Pasien',
                          style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold, color: textColor),
                        ),
                      ],
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(nCtx),
                      icon: const Icon(Icons.close_rounded, size: 18),
                      color: subtitleColor,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Pilih kanal komunikasi untuk menghubungi ${item.nama} (${item.noTelepon}):',
                  style: GoogleFonts.outfit(fontSize: 11, color: subtitleColor),
                ),
                const SizedBox(height: 16),
                // WhatsApp Option
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: borderColor)),
                  tileColor: isDark ? const Color(0xFF161B26) : const Color(0xFFF8FAFC),
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFF25D366),
                    child: Icon(Icons.chat_rounded, color: Colors.white, size: 18),
                  ),
                  title: Text('Kirim WhatsApp', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: textColor)),
                  subtitle: Text('Direct link WhatsApp dengan pesan otomatis', style: GoogleFonts.outfit(fontSize: 10, color: subtitleColor)),
                  trailing: const Icon(Icons.chevron_right_rounded, size: 18),
                  onTap: () async {
                    Navigator.pop(nCtx);
                    final waUrl = Uri.parse('https://wa.me/$cleanPhone?text=$messageText');
                    if (await canLaunchUrl(waUrl)) {
                      await launchUrl(waUrl, mode: LaunchMode.externalApplication);
                    } else {
                      await launchUrl(waUrl);
                    }
                  },
                ),
                const SizedBox(height: 8),
                // SMS Option
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: borderColor)),
                  tileColor: isDark ? const Color(0xFF161B26) : const Color(0xFFF8FAFC),
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFF3498DB),
                    child: Icon(Icons.sms_rounded, color: Colors.white, size: 18),
                  ),
                  title: Text('Kirim Pesan SMS', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: textColor)),
                  subtitle: Text('Buka aplikasi Pesan SMS di HP', style: GoogleFonts.outfit(fontSize: 10, color: subtitleColor)),
                  trailing: const Icon(Icons.chevron_right_rounded, size: 18),
                  onTap: () async {
                    Navigator.pop(nCtx);
                    final smsUrl = Uri.parse('sms:$cleanPhone?body=$messageText');
                    if (await canLaunchUrl(smsUrl)) {
                      await launchUrl(smsUrl, mode: LaunchMode.externalApplication);
                    } else {
                      await launchUrl(smsUrl);
                    }
                  },
                ),
                const SizedBox(height: 8),
                // Phone Call Option
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: borderColor)),
                  tileColor: isDark ? const Color(0xFF161B26) : const Color(0xFFF8FAFC),
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFF9B59B6),
                    child: Icon(Icons.phone_rounded, color: Colors.white, size: 18),
                  ),
                  title: Text('Panggil Telepon Direct', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: textColor)),
                  subtitle: Text('Hubungi via TeleponSeluler (${item.noTelepon})', style: GoogleFonts.outfit(fontSize: 10, color: subtitleColor)),
                  trailing: const Icon(Icons.chevron_right_rounded, size: 18),
                  onTap: () async {
                    Navigator.pop(nCtx);
                    final telUrl = Uri.parse('tel:$cleanPhone');
                    if (await canLaunchUrl(telUrl)) {
                      await launchUrl(telUrl, mode: LaunchMode.externalApplication);
                    } else {
                      await launchUrl(telUrl);
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildModalMetricTile(
    String label,
    String value,
    IconData icon,
    Color accentColor,
    Color bg,
    Color border,
    Color txtColor,
    Color subColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: accentColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label, style: GoogleFonts.outfit(fontSize: 8.5, color: subColor, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.outfit(fontSize: 10.5, fontWeight: FontWeight.bold, color: txtColor),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModalSectionHeader(String title, IconData icon, Color accent, Color txtColor) {
    return Row(
      children: [
        Icon(icon, size: 16, color: accent),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.w900, color: txtColor, letterSpacing: 0.5),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, Color txtColor, Color subColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.outfit(fontSize: 11, color: subColor)),
        Text(value, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: txtColor)),
      ],
    );
  }

  Widget _buildLegendItem(String label, String val, Color txtColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w600, color: txtColor)),
        Text(val, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: txtColor)),
      ],
    );
  }
}

// ─── Custom Canvas Pie Chart Painter ──────────────────────────────────────────

class PieChartPainter extends CustomPainter {
  final List<PieChartSegment> segments;

  PieChartPainter({required this.segments});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final strokeWidth = radius * 0.35;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    double total = segments.fold(0, (sum, item) => sum + item.value);
    if (total == 0) return;

    double startAngle = -1.5707963267948966; // -pi / 2

    for (final segment in segments) {
      final sweepAngle = (segment.value / total) * 6.283185307179586; // 2 * pi
      paint.color = segment.color;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
        startAngle,
        sweepAngle,
        false,
        paint,
      );

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant PieChartPainter oldDelegate) => true;
}

class PieChartSegment {
  final String label;
  final double value;
  final Color color;

  const PieChartSegment(this.label, this.value, this.color);
}

class AddPatientModalDialog extends StatefulWidget {
  final Color cardBgColor;
  final Color textColor;
  final Color subtitleColor;
  final Color borderColor;
  final Color themeAccent;
  final bool isDark;
  final Function(IbuHamilModel) onPatientAdded;

  const AddPatientModalDialog({
    super.key,
    required this.cardBgColor,
    required this.textColor,
    required this.subtitleColor,
    required this.borderColor,
    required this.themeAccent,
    required this.isDark,
    required this.onPatientAdded,
  });

  @override
  State<AddPatientModalDialog> createState() => _AddPatientModalDialogState();
}

class _AddPatientModalDialogState extends State<AddPatientModalDialog> {
  int _tabIndex = 0; // 0: Mapotech Database Import, 1: Manual Input

  // Manual Form Controllers
  final TextEditingController _nikController = TextEditingController();
  final TextEditingController _namaController = TextEditingController();
  final TextEditingController _umurController = TextEditingController(text: '26');
  final TextEditingController _suamiController = TextEditingController();
  final TextEditingController _hpController = TextEditingController();
  final TextEditingController _usiaKehamilanController = TextEditingController(text: '16 Minggu');
  final TextEditingController _hplController = TextEditingController(text: '20 Oktober 2026');
  final TextEditingController _hbController = TextEditingController(text: '12.0');
  final TextEditingController _lilaController = TextEditingController(text: '24.0');
  final TextEditingController _alamatController = TextEditingController(text: 'Dusun Krajan, RT 01/RW 02');

  String _trimester = 'Trimester 2';
  String _ksprStatus = 'Risiko Rendah (KRR)';

  final List<Map<String, String>> _mapotechRegisteredPatients = const [
    {
      'nama': 'Fitri Handayani',
      'nik': '3511085409970008',
      'umur': '25',
      'suami': 'Bagus Prasetyo',
      'hp': '0812-9988-7766',
      'alamat': 'Dusun Krajan, RT 03/RW 01, Tlogosari',
      'usiaKehamilan': '16 Minggu',
      'trimester': 'Trimester 2',
      'hpl': '10 November 2026',
      'kspr': 'Risiko Rendah (KRR)',
      'hb': '12.2 g/dL',
      'lila': '25.0 cm',
    },
    {
      'nama': 'Nurul Aini',
      'nik': '3511086811950004',
      'umur': '30',
      'suami': 'Dedi Kurniawan',
      'hp': '0857-4455-6677',
      'alamat': 'Dusun Timuran, RT 01/RW 04, Sukorejo',
      'usiaKehamilan': '24 Minggu',
      'trimester': 'Trimester 2',
      'hpl': '15 September 2026',
      'kspr': 'Risiko Tinggi (KRT)',
      'hb': '10.5 g/dL',
      'lila': '22.5 cm',
    },
    {
      'nama': 'Ratna Juwita',
      'nik': '3511084501980002',
      'umur': '28',
      'suami': 'Eko Saputra',
      'hp': '0878-1122-3344',
      'alamat': 'Dusun Krajan, RT 04/RW 02, Sumber Wringin',
      'usiaKehamilan': '10 Minggu',
      'trimester': 'Trimester 1',
      'hpl': '28 Desember 2026',
      'kspr': 'Risiko Rendah (KRR)',
      'hb': '11.9 g/dL',
      'lila': '24.5 cm',
    },
  ];

  @override
  void dispose() {
    _nikController.dispose();
    _namaController.dispose();
    _umurController.dispose();
    _suamiController.dispose();
    _hpController.dispose();
    _usiaKehamilanController.dispose();
    _hplController.dispose();
    _hbController.dispose();
    _lilaController.dispose();
    _alamatController.dispose();
    super.dispose();
  }

  void _submitManual() {
    if (_namaController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nama lengkap pasien wajib diisi!'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

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

    final hpVal = _hpController.text.trim();
    if (hpVal.isNotEmpty && (hpVal.length < 11 || hpVal.length > 13 || !RegExp(r'^\d{11,13}$').hasMatch(hpVal))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nomor HP / WhatsApp harus angka numerik antara 11 - 13 digit!'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final newPatient = IbuHamilModel(
      id: 'KIA-00${DateTime.now().millisecondsSinceEpoch % 1000}',
      nama: _namaController.text.trim(),
      nik: _nikController.text.trim().isEmpty ? '351108${DateTime.now().millisecondsSinceEpoch}' : _nikController.text.trim(),
      umur: int.tryParse(_umurController.text.trim()) ?? 26,
      namaSuami: _suamiController.text.trim().isEmpty ? 'Suami Pasien' : _suamiController.text.trim(),
      usiaKehamilan: _usiaKehamilanController.text.trim(),
      trimester: _trimester,
      hpl: _hplController.text.trim(),
      ksprStatus: _ksprStatus,
      ksprColor: _ksprStatus.contains('Sangat')
          ? const Color(0xFFE74C3C)
          : _ksprStatus.contains('Tinggi')
              ? const Color(0xFFE67E22)
              : const Color(0xFF2ECC71),
      ancStatus: 'K1 Baru',
      hb: '${_hbController.text.trim()} g/dL',
      lila: '${_lilaController.text.trim()} cm',
      latitude: -7.9550 + (DateTime.now().second * 0.0002),
      longitude: 113.9100 + (DateTime.now().second * 0.0002),
      alamat: _alamatController.text.trim().isEmpty ? 'Bondowoso, Jawa Timur' : _alamatController.text.trim(),
      noTelepon: _hpController.text.trim().isEmpty ? '0812-0000-0000' : _hpController.text.trim(),
      jumlahKunjungan: 1,
      waktuKunjunganTerakhir: 'Hari Ini',
      riwayatKunjungan: [
        {
          'kunjungan': 'K1 (Trimester 1)',
          'date': 'Hari Ini',
          'time': '09:00 WIB',
          'pemeriksa': 'Bidan (Praktek Mandiri)',
          'td': '120/80 mmHg',
          'djj': '140 bpm',
          'tfu': '16 cm',
          'bb_tb': '55 kg | 158 cm',
          'hb_lila': '${_hbController.text.trim()} g/dL | ${_lilaController.text.trim()} cm',
          'protein_urin': 'Negatif',
          'resep': 'Suplemen Asam Folat & Fe',
          'catatan': 'Registrasi pasien baru praktek mandiri & pemeriksaan awal kehamilan.',
        }
      ],
    );

    widget.onPatientAdded(newPatient);
    Navigator.of(context).pop();
  }

  void _importPatient(Map<String, String> m) {
    final newPatient = IbuHamilModel(
      id: 'KIA-00${DateTime.now().millisecondsSinceEpoch % 1000}',
      nama: m['nama']!,
      nik: m['nik']!,
      umur: int.tryParse(m['umur']!) ?? 25,
      namaSuami: m['suami']!,
      usiaKehamilan: m['usiaKehamilan']!,
      trimester: m['trimester']!,
      hpl: m['hpl']!,
      ksprStatus: m['kspr']!,
      ksprColor: m['kspr']!.contains('Tinggi') ? const Color(0xFFE67E22) : const Color(0xFF2ECC71),
      ancStatus: 'K1 Terdaftar',
      hb: m['hb']!,
      lila: m['lila']!,
      latitude: -7.9570 + (DateTime.now().second * 0.0003),
      longitude: 113.9150 + (DateTime.now().second * 0.0003),
      alamat: m['alamat']!,
      noTelepon: m['hp']!,
      jumlahKunjungan: 1,
      waktuKunjunganTerakhir: 'Hari Ini',
      riwayatKunjungan: [
        {
          'kunjungan': 'K1 (Trimester 1)',
          'date': 'Hari Ini',
          'time': '09:30 WIB',
          'pemeriksa': 'Bidan Registrasi',
          'td': '115/75 mmHg',
          'djj': '142 bpm',
          'tfu': '18 cm',
          'bb_tb': '54 kg | 157 cm',
          'hb_lila': '${m['hb']} | ${m['lila']}',
          'protein_urin': 'Negatif',
          'resep': 'Tablet Tambah Darah Fe',
          'catatan': 'Impor data pasien terdaftar Mapotech & pemeriksaan awal.',
        }
      ],
    );

    widget.onPatientAdded(newPatient);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: widget.cardBgColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        width: 650,
        constraints: const BoxConstraints(maxHeight: 700),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Modal Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: widget.themeAccent.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.person_add_rounded, size: 22, color: widget.themeAccent),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TAMBAH PASIEN IBU HAMIL BARU',
                          style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w900, color: widget.textColor),
                        ),
                        Text(
                          'Pencatatan pasien baru praktek mandiri bidan atau impor database Mapotech',
                          style: GoogleFonts.outfit(fontSize: 10, color: widget.subtitleColor),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close_rounded, color: widget.subtitleColor),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Tab Selector
            Container(
              decoration: BoxDecoration(
                color: widget.isDark ? const Color(0xFF161B26) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _tabIndex = 0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _tabIndex == 0 ? widget.themeAccent : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '🏥 Impor Database Mapotech',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _tabIndex == 0 ? Colors.white : widget.subtitleColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _tabIndex = 1),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _tabIndex == 1 ? widget.themeAccent : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '✍️ Input Manual Pasien Baru',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _tabIndex == 1 ? Colors.white : widget.subtitleColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Tab Body
            Expanded(
              child: SingleChildScrollView(
                child: _tabIndex == 0 ? _buildMapotechImportTab() : _buildManualFormTab(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapotechImportTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Daftar Pasien Terdaftar di System Mapotech / SatuSehat RME:',
          style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: widget.subtitleColor),
        ),
        const SizedBox(height: 12),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _mapotechRegisteredPatients.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, idx) {
            final m = _mapotechRegisteredPatients[idx];
            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: widget.isDark ? const Color(0xFF161B26) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: widget.borderColor),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: widget.themeAccent.withOpacity(0.12),
                    child: Icon(Icons.face_3_rounded, size: 20, color: widget.themeAccent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${m['nama']} (${m['umur']} th)',
                          style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w900, color: widget.textColor),
                        ),
                        Text(
                          'NIK: ${m['nik']} • Suami: ${m['suami']} • ${m['hp']}',
                          style: GoogleFonts.outfit(fontSize: 10, color: widget.subtitleColor),
                        ),
                        Text(
                          '📍 ${m['alamat']}',
                          style: GoogleFonts.outfit(fontSize: 9.5, color: widget.subtitleColor),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.themeAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onPressed: () => _importPatient(m),
                    icon: const Icon(Icons.download_rounded, size: 14),
                    label: Text('Impor & Tambah', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildManualFormTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildInput(
                'NIK Ibu Hamil (16 Digit)',
                _nikController,
                hint: 'Contoh: 351108...',
                keyboardType: TextInputType.number,
                maxLength: 16,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(16),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: _buildInput('Nama Lengkap Pasien *', _namaController, hint: 'Nama Lengkap')),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildInput('Umur Pasien (Tahun)', _umurController, hint: '26')),
            const SizedBox(width: 12),
            Expanded(child: _buildInput('Nama Suami / Penanggung Jawab', _suamiController, hint: 'Nama Suami')),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildInput(
                'Nomor HP / WhatsApp',
                _hpController,
                hint: '08xxxxxxxxxx',
                keyboardType: TextInputType.phone,
                maxLength: 13,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(13),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: _buildInput('Usia Kehamilan', _usiaKehamilanController, hint: '16 Minggu')),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Trimester Kehamilan', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: widget.subtitleColor)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: widget.isDark ? const Color(0xFF161B26) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: widget.borderColor),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _trimester,
                        style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: widget.textColor),
                        dropdownColor: widget.cardBgColor,
                        items: ['Trimester 1', 'Trimester 2', 'Trimester 3'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _trimester = v);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Status Skrining KSPR', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: widget.subtitleColor)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: widget.isDark ? const Color(0xFF161B26) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: widget.borderColor),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _ksprStatus,
                        style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: widget.textColor),
                        dropdownColor: widget.cardBgColor,
                        items: ['Risiko Rendah (KRR)', 'Risiko Tinggi (KRT)', 'Risiko Sangat Tinggi (KRST)'].map((k) => DropdownMenuItem(value: k, child: Text(k))).toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _ksprStatus = v);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildInput('Taksiran Persalinan (HPL)', _hplController, hint: 'Contoh: 20 Oktober 2026')),
            const SizedBox(width: 12),
            Expanded(child: _buildInput('Hb (g/dL)', _hbController, hint: '12.0')),
            const SizedBox(width: 12),
            Expanded(child: _buildInput('LiLA (cm)', _lilaController, hint: '24.0')),
          ],
        ),
        const SizedBox(height: 12),
        _buildInput('Alamat Lengkap & Dusun Domisili', _alamatController, hint: 'Alamat lengkap pasien...'),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.themeAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: _submitManual,
            icon: const Icon(Icons.check_circle_rounded, size: 18),
            label: Text('Simpan & Tambahkan Pasien Baru ➔', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildInput(String label, TextEditingController ctrl, {String? hint, TextInputType? keyboardType, int? maxLength, List<TextInputFormatter>? inputFormatters}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: widget.subtitleColor)),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          keyboardType: keyboardType,
          maxLength: maxLength,
          inputFormatters: inputFormatters,
          style: GoogleFonts.outfit(fontSize: 11, color: widget.textColor),
          decoration: InputDecoration(
            isDense: true,
            counterText: '',
            hintText: hint,
            hintStyle: GoogleFonts.outfit(fontSize: 10, color: widget.subtitleColor),
            filled: true,
            fillColor: widget.isDark ? const Color(0xFF161B26) : const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: widget.borderColor)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: widget.borderColor)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: widget.themeAccent)),
          ),
        ),
      ],
    );
  }
}
