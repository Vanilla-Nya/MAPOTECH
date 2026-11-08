import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapotech/features/landing/landing_page_data.dart';
import 'package:mapotech/shared/widgets/ui.dart';
import '../data/vitascale_models.dart';
import '../vitascale_dlc_gate.dart';
import 'vitascale_screening_page.dart';

/// Model Rekam Data Kunjungan & Pemeriksaan Antropometri Balita
class ChildVisitRecord {
  final String visitNumber;
  final String monthAgeLabel;
  final DateTime visitDate;
  final double weightKg;
  final double heightCm;
  final double waistCm;
  final double lilaCm;
  final String mode; // 'PB' (Telentang) atau 'TB' (Berdiri)
  final String statusGizi;
  final Color statusGiziColor;
  final String statusStunting;
  final Color statusStuntingColor;
  final double confidenceGizi;
  final double confidenceStunting;
  final String examiner;
  final String reasoningSummary;
  final List<String> chainOfThought;
  final String riskEtiology;
  final String nutritionPlan;
  final String medicalProtocol;
  final String parentEducation;

  const ChildVisitRecord({
    required this.visitNumber,
    required this.monthAgeLabel,
    required this.visitDate,
    required this.weightKg,
    required this.heightCm,
    required this.waistCm,
    required this.lilaCm,
    required this.mode,
    required this.statusGizi,
    required this.statusGiziColor,
    required this.statusStunting,
    required this.statusStuntingColor,
    required this.confidenceGizi,
    required this.confidenceStunting,
    required this.examiner,
    required this.reasoningSummary,
    required this.chainOfThought,
    required this.riskEtiology,
    required this.nutritionPlan,
    required this.medicalProtocol,
    required this.parentEducation,
  });

  double get whtr => waistCm / heightCm;
}

/// Halaman Detail Riwayat Kunjungan & Pemeriksaan Pasien Balita / Anak
/// 
/// Memenuhi instruksi:
/// 1. Tabel pemeriksaan per bulan / kunjungan balita.
/// 2. Klik pada baris tabel memunculkan detail skrining lengkap & penalaran AI klinis terakhir.
/// 3. Footer sticky/persistent di bagian bawah yang selalu muncul saat scroll dengan tombol "Mulai Skrining".
/// 4. Navigasi "Mulai Skrining" masuk ke halaman skrining dengan nama balita dan tombol kembali.
class VitaScaleChildHistoryPage extends ConsumerStatefulWidget {
  final ChildProfile child;
  final VoidCallback? onBack;
  final ValueChanged<ChildProfile>? onStartScreening;

  const VitaScaleChildHistoryPage({
    super.key,
    required this.child,
    this.onBack,
    this.onStartScreening,
  });

  @override
  ConsumerState<VitaScaleChildHistoryPage> createState() => _VitaScaleChildHistoryPageState();
}

class _VitaScaleChildHistoryPageState extends ConsumerState<VitaScaleChildHistoryPage> {
  late final List<ChildVisitRecord> _visits;

  @override
  void initState() {
    super.initState();
    _visits = _generateVisitsForChild(widget.child);
  }

  /// Menghasilkan riwayat kunjungan berkala per bulan untuk balita
  List<ChildVisitRecord> _generateVisitsForChild(ChildProfile c) {
    final now = DateTime.now();
    final isUnder24 = c.isUnder24Months;
    final modeCode = isUnder24 ? 'PB' : 'TB';

    // Kunjungan 4 (Terakhir / Bulan Ini)
    final v4 = ChildVisitRecord(
      visitNumber: 'Kunjungan 4 (Terbaru)',
      monthAgeLabel: 'Bulan ke-${c.ageInMonths}',
      visitDate: now.subtract(const Duration(days: 3)),
      weightKg: isUnder24 ? 11.5 : 16.8,
      heightCm: isUnder24 ? 85.0 : 104.5,
      waistCm: isUnder24 ? 46.0 : 51.5,
      lilaCm: isUnder24 ? 14.8 : 16.2,
      mode: modeCode,
      statusGizi: 'Gizi Baik (Normal)',
      statusGiziColor: const Color(0xFF2ECC71),
      statusStunting: 'Normal (Tinggi Sesuai)',
      statusStuntingColor: const Color(0xFF2ECC71),
      confidenceGizi: 97.4,
      confidenceStunting: 98.1,
      examiner: 'dr. Hendra Sp.A & Bidan Anita',
      reasoningSummary:
          'Pertumbuhan fisik balita ${c.name} berada pada laju optimal standar WHO. Parameter rasio BB/TB dan TB/U menunjukkan tren kurva pertumbuhan yang stabil.',
      chainOfThought: [
        'Evaluasi usia ${c.ageInMonths} bulan terhadap median berat dan panjang/tinggi standar Permenkes 2020.',
        'Model MLP mengonfirmasi status Gizi Baik (Confidence 97.4%) dan Tinggi Normal (Confidence 98.1%).',
        'Pertumbuhan linier memadai tanpa deviasi stunting kronis (Z-score -0.4 SD).',
      ],
      riskEtiology:
          'Tidak teridentifikasi faktor risiko defisit nutrisi akut. Riwayat nafsu makan baik dan tidak ada infeksi diare/ISPA berulang.',
      nutritionPlan:
          'Pertahankan variasi protein hewani harian (1 butir telur/hari, ikan air tawar/laut, daging ayam). Pastikan pemenuhan mikronutrien Zinc dan Zat Besi.',
      medicalProtocol:
          'Jadwalkan kunjungan antropometri berkala bulan berikutnya di Puskesmas/Posyandu. Lanjutkan suplementasi Vitamin A kapsul sesuai jadwal.',
      parentEducation:
          'Berikan apresiasi kepada orang tua (${c.parentName}) atas kepatuhan pemantauan gizi anak. Tingkatkan stimulasi motorik kasar dan bahasa.',
    );

    // Kunjungan 3 (~3 bulan lalu)
    final v3 = ChildVisitRecord(
      visitNumber: 'Kunjungan 3',
      monthAgeLabel: 'Bulan ke-${(c.ageInMonths - 3).clamp(1, 144)}',
      visitDate: now.subtract(const Duration(days: 90)),
      weightKg: isUnder24 ? 10.4 : 15.6,
      heightCm: isUnder24 ? 80.5 : 100.0,
      waistCm: isUnder24 ? 44.5 : 50.0,
      lilaCm: isUnder24 ? 14.2 : 15.8,
      mode: modeCode,
      statusGizi: 'Gizi Baik (Normal)',
      statusGiziColor: const Color(0xFF2ECC71),
      statusStunting: 'Normal (Tinggi Sesuai)',
      statusStuntingColor: const Color(0xFF2ECC71),
      confidenceGizi: 96.2,
      confidenceStunting: 96.8,
      examiner: 'Bidan Anita (Puskesmas)',
      reasoningSummary:
          'Evaluasi antropometri triwulanan menunjukkan kenaikan berat badan adekuat sesuai grafik KMS.',
      chainOfThought: [
        'Kenaikan berat badan bulanan melampaui KBM (Kenaikan Berat Minimal).',
        'Status stunting terpantau aman pada rentang hijau median WHO.',
      ],
      riskEtiology: 'Pemberian MP-ASI/makanan keluarga adekuat, sanitasi lingkungan rumah tangga bersih.',
      nutritionPlan: 'Lanjutkan pemberian makanan gizi seimbang kaya serat dan zat besi.',
      medicalProtocol: 'Imunisasi lanjutan terverifikasi lengkap sesuai usia.',
      parentEducation: 'Jaga kebersihan tangan sebelum menyiapkan makanan anak.',
    );

    // Kunjungan 2 (~6 bulan lalu)
    final v2 = ChildVisitRecord(
      visitNumber: 'Kunjungan 2',
      monthAgeLabel: 'Bulan ke-${(c.ageInMonths - 6).clamp(1, 144)}',
      visitDate: now.subtract(const Duration(days: 180)),
      weightKg: isUnder24 ? 9.2 : 14.5,
      heightCm: isUnder24 ? 75.0 : 96.0,
      waistCm: isUnder24 ? 43.0 : 49.0,
      lilaCm: isUnder24 ? 13.8 : 15.2,
      mode: modeCode,
      statusGizi: 'Gizi Baik (Normal)',
      statusGiziColor: const Color(0xFF2ECC71),
      statusStunting: 'Normal (Tinggi Sesuai)',
      statusStuntingColor: const Color(0xFF2ECC71),
      confidenceGizi: 95.0,
      confidenceStunting: 95.5,
      examiner: 'Bidan Rina (Puskesmas Pembantu)',
      reasoningSummary:
          'Skrining rutin semesteran. Tidak terdapat indikasi kegagalan tumbuh kembang.',
      chainOfThought: [
        'Pengukuran panjang/tinggi badan dilakukan dengan kalibrasi papan ukur terstandar.',
        'Indeks antropometri BB/TB berada di kisaran 0 SD.',
      ],
      riskEtiology: 'Tidak ada riwayat alergi makanan atau gangguan penyerapan nutrisi.',
      nutritionPlan: 'Tingkatkan asupan kalsium dari susu dan produk olahan hewani.',
      medicalProtocol: 'Pemantauan berkala Posyandu setempat setiap bulan.',
      parentEducation: 'Cukupi kebutuhan tidur malam balita minimal 10-12 jam.',
    );

    // Kunjungan 1 (~9 bulan lalu)
    final v1 = ChildVisitRecord(
      visitNumber: 'Kunjungan 1 (Awal)',
      monthAgeLabel: 'Bulan ke-${(c.ageInMonths - 9).clamp(1, 144)}',
      visitDate: now.subtract(const Duration(days: 270)),
      weightKg: isUnder24 ? 8.1 : 13.2,
      heightCm: isUnder24 ? 70.0 : 92.0,
      waistCm: isUnder24 ? 41.5 : 47.5,
      lilaCm: isUnder24 ? 13.2 : 14.6,
      mode: modeCode,
      statusGizi: 'Gizi Baik (Normal)',
      statusGiziColor: const Color(0xFF2ECC71),
      statusStunting: 'Normal (Tinggi Sesuai)',
      statusStuntingColor: const Color(0xFF2ECC71),
      confidenceGizi: 94.8,
      confidenceStunting: 94.2,
      examiner: 'Bidan Anita',
      reasoningSummary:
          'Registrasi awal sasaran balita faskes. Kondisi dasar vital dan fisik anak sangat baik.',
      chainOfThought: [
        'Pendaftaran data master antropometri awal ke sistem e-Kohort Puskesmas.',
      ],
      riskEtiology: 'Riwayat berat lahir normal (BBLN), ASI eksklusif terpenuhi.',
      nutritionPlan: 'Lanjutkan panduan gizi seimbang Kementerian Kesehatan.',
      medicalProtocol: 'Pemberian vitamin A dan obat cacing sesuai petunjuk petugas.',
      parentEducation: 'Bawa buku KIA setiap kali jadwal penimbangan di Posyandu.',
    );

    return [v4, v3, v2, v1];
  }

  String _formatDate(DateTime d, {bool shortMonth = false}) {
    const monthsFull = [
      '', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    const monthsShort = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Ags', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    final m = shortMonth ? monthsShort[d.month] : monthsFull[d.month];
    return '${d.day.toString().padLeft(2, '0')} $m ${d.year}';
  }

  void _showVisitDetailModal(ChildVisitRecord visit) {
    final notifier = ref.read(landingPageProvider.notifier);
    final textColor = notifier.getTextColor();
    final subtitleColor = notifier.getBodyTextColor();
    final borderColor = notifier.getBorderColor();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMobile = MediaQuery.of(context).size.width < 768;

    showDialog(
      context: context,
      builder: (ctx) => CustomDialog(
        title: 'Detail Pemeriksaan: ${widget.child.name}',
        icon: Icons.assignment_turned_in_rounded,
        iconColor: const Color(0xFF1ABC9C),
        maxWidth: 680,
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Info Bar
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1ABC9C).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF1ABC9C).withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1ABC9C).withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.event_available_rounded, size: 20, color: Color(0xFF1ABC9C)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  visit.visitNumber,
                                  style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                StatusBadge(
                                  label: visit.monthAgeLabel,
                                  color: const Color(0xFF1ABC9C),
                                  fontSize: 9,
                                  showDot: false,
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Tanggal: ${_formatDate(visit.visitDate)} • Pemeriksa: ${visit.examiner}',
                              style: GoogleFonts.outfit(fontSize: 10.5, color: subtitleColor),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Parameter Antropometri Grid
                Text(
                  'HASIL PENGUKURAN ANTROPOMETRI',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: subtitleColor,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: isMobile ? 2 : 4,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.5,
                  children: [
                    _buildMetricBox('Berat Badan (BB)', '${visit.weightKg} kg', Icons.monitor_weight_rounded, const Color(0xFF3498DB), isDark, borderColor, textColor, subtitleColor),
                    _buildMetricBox('Panjang/Tinggi (${visit.mode})', '${visit.heightCm} cm', Icons.straighten_rounded, const Color(0xFFE67E22), isDark, borderColor, textColor, subtitleColor),
                    _buildMetricBox('Lingkar Lengan (LiLA)', '${visit.lilaCm} cm', Icons.circle_outlined, const Color(0xFF9B59B6), isDark, borderColor, textColor, subtitleColor),
                    _buildMetricBox('Lingkar Perut (LP)', '${visit.waistCm} cm', Icons.trip_origin_rounded, const Color(0xFF1ABC9C), isDark, borderColor, textColor, subtitleColor),
                  ],
                ),

                const SizedBox(height: 18),

                // Prediksi Model Machine Learning Keras MLP
                Text(
                  'KLASIFIKASI MODEL MACHINE LEARNING (KERAS MLP)',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: subtitleColor,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: visit.statusGiziColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: visit.statusGiziColor.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Status Gizi (BB/TB)',
                              style: GoogleFonts.outfit(fontSize: 10, color: subtitleColor, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              visit.statusGizi,
                              style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w900, color: visit.statusGiziColor),
                            ),
                            Text(
                              'Keyakinan Model: ${visit.confidenceGizi.toStringAsFixed(1)}%',
                              style: GoogleFonts.outfit(fontSize: 9.5, color: subtitleColor),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: visit.statusStuntingColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: visit.statusStuntingColor.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Status Stunting (TB/U)',
                              style: GoogleFonts.outfit(fontSize: 10, color: subtitleColor, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              visit.statusStunting,
                              style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w900, color: visit.statusStuntingColor),
                            ),
                            Text(
                              'Keyakinan Model: ${visit.confidenceStunting.toStringAsFixed(1)}%',
                              style: GoogleFonts.outfit(fontSize: 9.5, color: subtitleColor),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // Clinical Reasoning AI (Gemini Dokter Spesialis Anak)
                Text(
                  'CLINICAL AI REASONING & PENALARAN KLINIS DOKTER',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: subtitleColor,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1B1B26) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.psychology_rounded, size: 18, color: Color(0xFF1ABC9C)),
                          const SizedBox(width: 8),
                          Text(
                            'Ringkasan Penalaran Klinis',
                            style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.bold, color: textColor),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        visit.reasoningSummary,
                        style: GoogleFonts.outfit(fontSize: 11, color: textColor.withValues(alpha: 0.9), height: 1.4),
                      ),
                      const Divider(height: 20),
                      Text(
                        'Rantai Penalaran (Chain of Thought):',
                        style: GoogleFonts.outfit(fontSize: 10.5, fontWeight: FontWeight.bold, color: subtitleColor),
                      ),
                      const SizedBox(height: 6),
                      ...visit.chainOfThought.map(
                        (step) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('• ', style: TextStyle(color: Color(0xFF1ABC9C), fontWeight: FontWeight.bold)),
                              Expanded(
                                child: Text(step, style: GoogleFonts.outfit(fontSize: 10.5, color: textColor)),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Divider(height: 20),
                      _buildAdviceTile('Rencana Intervensi Gizi', visit.nutritionPlan, Icons.restaurant_rounded, const Color(0xFFE67E22), textColor, subtitleColor),
                      const SizedBox(height: 8),
                      _buildAdviceTile('Protokol Tindak Lanjut Faskes', visit.medicalProtocol, Icons.medical_services_rounded, const Color(0xFF3498DB), textColor, subtitleColor),
                      const SizedBox(height: 8),
                      _buildAdviceTile('Pesan Edukasi Orang Tua', visit.parentEducation, Icons.family_restroom_rounded, const Color(0xFF2ECC71), textColor, subtitleColor),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          CustomButton(
            text: 'Tutup Detail',
            isSecondary: true,
            height: 40,
            onPressed: () => Navigator.pop(ctx),
          ),
          CustomButton(
            text: 'Mulai Skrining Sesi Ini',
            icon: Icons.play_arrow_rounded,
            height: 40,
            primaryColor: const Color(0xFF1ABC9C),
            onPressed: () {
              Navigator.pop(ctx);
              _navigateToScreeningPage();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMetricBox(
    String label,
    String value,
    IconData icon,
    Color color,
    bool isDark,
    Color borderColor,
    Color textColor,
    Color subtitleColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161622) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.bold, color: subtitleColor),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w900, color: textColor),
          ),
        ],
      ),
    );
  }

  Widget _buildAdviceTile(
    String title,
    String desc,
    IconData icon,
    Color color,
    Color textColor,
    Color subtitleColor,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.outfit(fontSize: 10.5, fontWeight: FontWeight.bold, color: color),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: GoogleFonts.outfit(fontSize: 10, color: subtitleColor, height: 1.3),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _navigateToScreeningPage() {
    if (widget.onStartScreening != null) {
      widget.onStartScreening!(widget.child);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VitaScaleScreeningPage(
          selectedChild: widget.child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(landingPageProvider);
    final notifier = ref.read(landingPageProvider.notifier);

    final cardBgColor = notifier.getCardColor();
    final textColor = notifier.getTextColor();
    final subtitleColor = notifier.getBodyTextColor();
    final borderColor = notifier.getBorderColor();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMobile = MediaQuery.of(context).size.width < 768;

    final child = widget.child;
    final isUnder24 = child.isUnder24Months;

    return VitaScaleDlcGate(
      menuTitle: 'Pemeriksaan & Kunjungan Anak',
      child: Container(
        color: notifier.getBackgroundColor(),
        child: Column(
          children: [
            // =================================================================
            // SCROLLABLE CONTENT BODY (HEADER + PROFILE + VISIT TABLE)
            // =================================================================
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Top Navigation Bar (Back Button + Page Title)
                    Row(
                      children: [
                        InkWell(
                          onTap: () {
                            if (widget.onBack != null) {
                              widget.onBack!();
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
                                  'Kembali',
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
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Rekam Pemeriksaan & Kunjungan Berkala',
                                style: GoogleFonts.outfit(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: textColor,
                                ),
                              ),
                              Text(
                                'Buku pemantauan antropometri digital & riwayat skrining AI Puskesmas',
                                style: GoogleFonts.outfit(fontSize: 10.5, color: subtitleColor),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // =========================================================
                    // CHILD PROFILE OVERVIEW CARD
                    // =========================================================
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: cardBgColor,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: borderColor),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Avatar Icon
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: (child.gender == 'L' ? const Color(0xFF3498DB) : const Color(0xFFE91E63))
                                      .withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Icon(
                                  isUnder24 ? Icons.child_friendly_rounded : Icons.face_rounded,
                                  color: child.gender == 'L' ? const Color(0xFF3498DB) : const Color(0xFFE91E63),
                                  size: 30,
                                ),
                              ),
                              const SizedBox(width: 16),
                              // Name & Badges
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            child.name,
                                            style: GoogleFonts.outfit(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w900,
                                              color: textColor,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        StatusBadge(
                                          label: child.gender == 'L' ? 'Laki-laki' : 'Perempuan',
                                          color: child.gender == 'L' ? const Color(0xFF3498DB) : const Color(0xFFE91E63),
                                          fontSize: 9.5,
                                          showDot: false,
                                        ),
                                        const SizedBox(width: 6),
                                        if (child.isBalita)
                                          Padding(
                                            padding: const EdgeInsets.only(right: 6),
                                            child: StatusBadge(
                                              label: 'BALITA < 5 THN',
                                              color: const Color(0xFF1ABC9C),
                                              fontSize: 9,
                                              showDot: false,
                                            ),
                                          ),
                                        StatusBadge(
                                          label: isUnder24 ? 'PB (TELENTANG)' : 'TB (BERDIRI)',
                                          color: isUnder24 ? const Color(0xFF3498DB) : const Color(0xFFE67E22),
                                          fontSize: 9,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'NIK: ${child.nik} • Usia: ${child.ageLabel} (${child.ageInMonths} Bulan) • Wali: ${child.parentName}',
                                      style: GoogleFonts.outfit(fontSize: 11, color: subtitleColor),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Alamat: ${child.address} • Telp/WA: ${child.phone?.isNotEmpty == true ? child.phone : "-"}',
                                      style: GoogleFonts.outfit(
                                        fontSize: 10.5,
                                        color: subtitleColor.withValues(alpha: 0.85),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),
                          const Divider(height: 1),
                          const SizedBox(height: 14),

                          // Quick Metric Summary Row
                          Row(
                            children: [
                              _buildProfileSummaryBadge(
                                'Total Kunjungan',
                                '${_visits.length}x Terdata',
                                Icons.calendar_month_rounded,
                                const Color(0xFF1ABC9C),
                                isDark,
                                textColor,
                                subtitleColor,
                              ),
                              const SizedBox(width: 10),
                              _buildProfileSummaryBadge(
                                'Status Gizi Terkini',
                                _visits.first.statusGizi,
                                Icons.verified_user_rounded,
                                _visits.first.statusGiziColor,
                                isDark,
                                textColor,
                                subtitleColor,
                              ),
                              const SizedBox(width: 10),
                              _buildProfileSummaryBadge(
                                'Status Stunting',
                                _visits.first.statusStunting,
                                Icons.height_rounded,
                                _visits.first.statusStuntingColor,
                                isDark,
                                textColor,
                                subtitleColor,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // =========================================================
                    // TABLE CARD: PEMERIKSAAN PER BULAN / KUNJUNGAN
                    // =========================================================
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: cardBgColor,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: borderColor),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Table Header Title & Hint
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1ABC9C).withValues(alpha: 0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.table_chart_rounded,
                                      size: 20,
                                      color: Color(0xFF1ABC9C),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'TABEL PEMERIKSAAN & ANTROPOMETRI PER BULAN',
                                        style: GoogleFonts.outfit(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w900,
                                          color: textColor,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      Text(
                                        'Rekam jejak pertumbuhan berkala sasaran balita & pemantauan KMS',
                                        style: GoogleFonts.outfit(fontSize: 10, color: subtitleColor),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              if (!isMobile)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1ABC9C).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(100),
                                    border: Border.all(color: const Color(0xFF1ABC9C).withValues(alpha: 0.3)),
                                  ),
                                  child: Text(
                                    '💡 Klik baris untuk detail skrining',
                                    style: GoogleFonts.outfit(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF1ABC9C),
                                    ),
                                  ),
                                ),
                            ],
                          ),

                          const SizedBox(height: 18),

                          // Responsive Table of Visits
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minWidth: isMobile ? 700 : 980,
                              ),
                              child: Table(
                                columnWidths: const {
                                  0: FlexColumnWidth(1.6), // Kunjungan
                                  1: FlexColumnWidth(1.2), // Tanggal
                                  2: FlexColumnWidth(1.0), // Usia
                                  3: FlexColumnWidth(1.1), // BB
                                  4: FlexColumnWidth(1.3), // TB / PB
                                  5: FlexColumnWidth(1.6), // Status Gizi (BB/TB)
                                  6: FlexColumnWidth(1.8), // Status Stunting (TB/U)
                                  7: FlexColumnWidth(1.0), // Aksi
                                },
                                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                                children: [
                                  // Table Header Row
                                  TableRow(
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF1E2130) : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    children: [
                                      _buildTh('Kunjungan'),
                                      _buildTh('Tanggal'),
                                      _buildTh('Usia'),
                                      _buildTh('Berat (BB)'),
                                      _buildTh('Tinggi/PB'),
                                      _buildTh('Gizi (BB/TB)'),
                                      _buildTh('Stunting (TB/U)'),
                                      _buildTh('Detail'),
                                    ],
                                  ),
                                  // Spacer row
                                  const TableRow(
                                    children: [
                                      SizedBox(height: 8),
                                      SizedBox(height: 8),
                                      SizedBox(height: 8),
                                      SizedBox(height: 8),
                                      SizedBox(height: 8),
                                      SizedBox(height: 8),
                                      SizedBox(height: 8),
                                      SizedBox(height: 8),
                                    ],
                                  ),
                                  // Table Data Rows (Clickable!)
                                  ..._visits.map((visit) {
                                    final isLatest = visit == _visits.first;
                                    return TableRow(
                                      decoration: BoxDecoration(
                                        color: isLatest
                                            ? const Color(0xFF1ABC9C).withValues(alpha: 0.05)
                                            : (isDark ? const Color(0xFF181B26) : Colors.white),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: isLatest
                                              ? const Color(0xFF1ABC9C).withValues(alpha: 0.3)
                                              : borderColor,
                                        ),
                                      ),
                                      children: [
                                        // Kunjungan
                                        _buildTableCell(
                                          InkWell(
                                            onTap: () => _showVisitDetailModal(visit),
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                              child: Row(
                                                children: [
                                                  Container(
                                                    width: 8,
                                                    height: 8,
                                                    decoration: BoxDecoration(
                                                      color: isLatest ? const Color(0xFF1ABC9C) : Colors.grey,
                                                      shape: BoxShape.circle,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Flexible(
                                                    child: Text(
                                                      visit.visitNumber,
                                                      style: GoogleFonts.outfit(
                                                        fontSize: 11.5,
                                                        fontWeight: FontWeight.bold,
                                                        color: textColor,
                                                      ),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        // Tanggal
                                        _buildTableCell(
                                          InkWell(
                                            onTap: () => _showVisitDetailModal(visit),
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                                              child: Text(
                                                _formatDate(visit.visitDate, shortMonth: true),
                                                style: GoogleFonts.outfit(fontSize: 11, color: textColor),
                                              ),
                                            ),
                                          ),
                                        ),
                                        // Usia
                                        _buildTableCell(
                                          InkWell(
                                            onTap: () => _showVisitDetailModal(visit),
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                                              child: Text(
                                                visit.monthAgeLabel,
                                                style: GoogleFonts.outfit(fontSize: 11, color: subtitleColor),
                                              ),
                                            ),
                                          ),
                                        ),
                                        // BB
                                        _buildTableCell(
                                          InkWell(
                                            onTap: () => _showVisitDetailModal(visit),
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                                              child: Text(
                                                '${visit.weightKg} kg',
                                                style: GoogleFonts.outfit(
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.bold,
                                                  color: const Color(0xFF3498DB),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        // TB / PB
                                        _buildTableCell(
                                          InkWell(
                                            onTap: () => _showVisitDetailModal(visit),
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                                              child: Text(
                                                '${visit.heightCm} cm (${visit.mode})',
                                                style: GoogleFonts.outfit(
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.bold,
                                                  color: const Color(0xFFE67E22),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        // Status Gizi
                                        _buildTableCell(
                                          InkWell(
                                            onTap: () => _showVisitDetailModal(visit),
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                                              child: StatusBadge(
                                                label: visit.statusGizi,
                                                color: visit.statusGiziColor,
                                                fontSize: 9,
                                              ),
                                            ),
                                          ),
                                        ),
                                        // Status Stunting
                                        _buildTableCell(
                                          InkWell(
                                            onTap: () => _showVisitDetailModal(visit),
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                                              child: StatusBadge(
                                                label: visit.statusStunting,
                                                color: visit.statusStuntingColor,
                                                fontSize: 9,
                                              ),
                                            ),
                                          ),
                                        ),
                                        // Tombol Detail
                                        _buildTableCell(
                                          Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                                            child: InkWell(
                                              onTap: () => _showVisitDetailModal(visit),
                                              borderRadius: BorderRadius.circular(8),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF1ABC9C).withValues(alpha: 0.12),
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(color: const Color(0xFF1ABC9C).withValues(alpha: 0.3)),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    const Icon(Icons.remove_red_eye_rounded, size: 13, color: Color(0xFF1ABC9C)),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      'Lihat',
                                                      style: GoogleFonts.outfit(
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.bold,
                                                        color: const Color(0xFF1ABC9C),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  }),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Additional bottom padding to ensure content is never obscured by sticky footer
                    const SizedBox(height: 90),
                  ],
                ),
              ),
            ),

            // =================================================================
            // STICKY / FIXED BOTTOM FOOTER (SELALU MUNCUL SAAT DI-SCROLL)
            // =================================================================
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: BoxDecoration(
                color: cardBgColor,
                border: Border(
                  top: BorderSide(color: borderColor, width: 1.5),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    // Left Side: Child Avatar & Prompt info
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1ABC9C).withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.monitor_weight_rounded,
                        size: 22,
                        color: Color(0xFF1ABC9C),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  'Siap Skrining Baru: ${child.name}',
                                  style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                    color: textColor,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              StatusBadge(
                                label: isUnder24 ? 'Mode PB (< 24 Bln)' : 'Mode TB (≥ 24 Bln)',
                                color: isUnder24 ? const Color(0xFF3498DB) : const Color(0xFFE67E22),
                                fontSize: 8.5,
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Sesi baru akan memuat data otomatis ke Reasoning Model & Klasifikasi MLP Keras',
                            style: GoogleFonts.outfit(fontSize: 10, color: subtitleColor),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Right Side: Main "Mulai Skrining" Action Button
                    CustomButton(
                      text: 'Mulai Skrining',
                      icon: Icons.play_arrow_rounded,
                      height: 44,
                      primaryColor: const Color(0xFF1ABC9C),
                      onPressed: _navigateToScreeningPage,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileSummaryBadge(
    String label,
    String value,
    IconData icon,
    Color color,
    bool isDark,
    Color textColor,
    Color subtitleColor,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1B1B26) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.outfit(fontSize: 9, color: subtitleColor, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    value,
                    style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: textColor),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTh(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Text(
        title,
        style: GoogleFonts.outfit(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: const Color(0xFF1ABC9C),
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _buildTableCell(Widget child) {
    return TableCell(
      verticalAlignment: TableCellVerticalAlignment.middle,
      child: child,
    );
  }
}
