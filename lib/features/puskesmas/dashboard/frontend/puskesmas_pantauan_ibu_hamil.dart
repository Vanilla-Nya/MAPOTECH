import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapotech/features/landing/landing_page_data.dart';
import 'package:mapotech/shared/widgets/ui.dart';

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

  final List<IbuHamilModel> _dummyData = const [
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
    final themeAccent = const Color(0xFFE91E63);
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

        const SizedBox(height: 20),

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
            return Container(
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
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'NIK: ${item.nik} • ${item.umur} th • Suami: ${item.namaSuami}',
                              style: GoogleFonts.outfit(fontSize: 10, color: subtitleColor),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: themeAccent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        onPressed: () {
                          if (widget.onNavigateToForm != null) {
                            widget.onNavigateToForm!('dlc_form_ibu_hamil');
                          }
                        },
                        icon: const Icon(Icons.edit_document, size: 14, color: Colors.white),
                        label: Text(
                          'Form ANC 10T',
                          style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
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
            );
          },
        ),
      ],
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
}
