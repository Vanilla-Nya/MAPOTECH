import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapotech/features/landing/landing_page_data.dart';
import 'package:mapotech/shared/widgets/ui.dart';

/// Halaman Khusus Ibu Hamil (MomiCare) — Terintegrasi dengan Skema community_health_center
class PasienMomicareView extends ConsumerStatefulWidget {
  final Function(String menu)? onNavigate;

  const PasienMomicareView({super.key, this.onNavigate});

  @override
  ConsumerState<PasienMomicareView> createState() => _PasienMomicareViewState();
}

class _PasienMomicareViewState extends ConsumerState<PasienMomicareView> {
  // Data simulasi kehamilan aktif pasien (Buku KIA 2024 / MomiCare)
  final int _currentGestasiWeeks = 28;
  final int _totalWeeks = 40;
  final String _hplDate = '14 Agustus 2026';
  final int _daysRemaining = 84;
  final String _hphtDate = '7 November 2025';
  final String _ksprStatus = 'KRR'; // KRR, KRT, KRST
  final int _ksprScore = 2;
  final String _puskesmasName = 'Puskesmas Sumber Wringin, Bondowoso';
  final String _bidanName = 'Bdn. Siti Aminah, S.Tr.Keb';

  int _selectedTab = 0; // 0 = Ringkasan & ANC, 1 = Grafik Perkembangan, 2 = Tips & Edukasi

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(landingPageProvider);
    final notifier = ref.read(landingPageProvider.notifier);

    final isDark = state.appearance == 'dark';
    final isEn = state.language == 'en';
    final primaryColor = notifier.getPrimaryColor();
    final textColor = notifier.getTextColor();
    final bodyTextColor = notifier.getBodyTextColor();
    final cardColor = notifier.getCardColor();
    final borderColor = notifier.getBorderColor();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── 1. HEADER BANNER MOMICARE ─────────────────────────────────────
          _buildHeaderBanner(
            isEn: isEn,
            isDark: isDark,
            primaryColor: primaryColor,
            textColor: textColor,
            bodyTextColor: bodyTextColor,
            cardColor: cardColor,
            borderColor: borderColor,
          ),

          const SizedBox(height: 20),

          // ── 2. PREGNANCY PROGRESS HERO CARD ───────────────────────────────
          _buildHeroProgressCard(
            isEn: isEn,
            isDark: isDark,
            primaryColor: primaryColor,
            textColor: textColor,
            bodyTextColor: bodyTextColor,
            cardColor: cardColor,
            borderColor: borderColor,
          ),

          const SizedBox(height: 20),

          // ── 3. TAB NAVIGATOR ──────────────────────────────────────────────
          _buildTabNavigator(
            isEn: isEn,
            isDark: isDark,
            primaryColor: primaryColor,
            textColor: textColor,
            cardColor: cardColor,
            borderColor: borderColor,
          ),

          const SizedBox(height: 20),

          // ── 4. TAB CONTENTS ───────────────────────────────────────────────
          if (_selectedTab == 0) ...[
            // Riwayat Kontrol Kunjungan ANC 10T & Jadwal Kontrol Mendatang
            _buildNextVisitCard(
              isEn: isEn,
              isDark: isDark,
              primaryColor: primaryColor,
              textColor: textColor,
              bodyTextColor: bodyTextColor,
              cardColor: cardColor,
              borderColor: borderColor,
            ),
            const SizedBox(height: 20),
            _buildAncTimeline(
              isEn: isEn,
              isDark: isDark,
              primaryColor: primaryColor,
              textColor: textColor,
              bodyTextColor: bodyTextColor,
              cardColor: cardColor,
              borderColor: borderColor,
            ),
          ] else if (_selectedTab == 1) ...[
            _buildGrowthMetrics(
              isEn: isEn,
              isDark: isDark,
              primaryColor: primaryColor,
              textColor: textColor,
              bodyTextColor: bodyTextColor,
              cardColor: cardColor,
              borderColor: borderColor,
            ),
          ] else ...[
            _buildEducationSection(
              isEn: isEn,
              isDark: isDark,
              primaryColor: primaryColor,
              textColor: textColor,
              bodyTextColor: bodyTextColor,
              cardColor: cardColor,
              borderColor: borderColor,
            ),
          ],

          const SizedBox(height: 24),

          // ── 5. TRANSISI KE VITASCALE ANAK (0-59 BULAN) BANNER ─────────────
          _buildTransitionBanner(
            isEn: isEn,
            isDark: isDark,
            textColor: textColor,
            bodyTextColor: bodyTextColor,
            borderColor: borderColor,
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // WIDGET BUILDERS
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildHeaderBanner({
    required bool isEn,
    required bool isDark,
    required Color primaryColor,
    required Color textColor,
    required Color bodyTextColor,
    required Color cardColor,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        gradient: LinearGradient(
          colors: [
            const Color(0xFFE91E63).withValues(alpha: isDark ? 0.15 : 0.08),
            primaryColor.withValues(alpha: isDark ? 0.08 : 0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: const Color(0xFFE91E63).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.pregnant_woman_rounded,
              color: Color(0xFFE91E63),
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'MomiCare',
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE91E63).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFE91E63).withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        '0–9 BULAN (ANC)',
                        style: GoogleFonts.outfit(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFFE91E63),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  isEn
                    ? 'Maternal Health & Pregnancy Journey tracker synced with Community Health Center records.'
                    : 'Pemantauan kesehatan ibu hamil & janin terpadu sesuai standar Buku KIA Kementerian Kesehatan RI.',
                  style: GoogleFonts.outfit(fontSize: 12, color: bodyTextColor),
                ),
              ],
            ),
          ),
          if (widget.onNavigate != null)
            ElevatedButton.icon(
              onPressed: () => widget.onNavigate!('ai_assistant'),
              icon: const Icon(Icons.smart_toy_rounded, size: 16),
              label: Text(
                isEn ? 'Consult AI' : 'Tanya AI Kehamilan',
                style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE91E63),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeroProgressCard({
    required bool isEn,
    required bool isDark,
    required Color primaryColor,
    required Color textColor,
    required Color bodyTextColor,
    required Color cardColor,
    required Color borderColor,
  }) {
    final progress = _currentGestasiWeeks / _totalWeeks;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isEn ? 'GESTATIONAL AGE' : 'USIA KEHAMILAN',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                      color: bodyTextColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '$_currentGestasiWeeks',
                        style: GoogleFonts.outfit(
                          fontSize: 38,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFFE91E63),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isEn ? 'Weeks (Trimester 3)' : 'Minggu (Trimester 3)',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              // KSPR Risk Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF27AE60).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF27AE60).withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.shield_rounded, size: 14, color: Color(0xFF27AE60)),
                        const SizedBox(width: 6),
                        Text(
                          'KSPR: $_ksprStatus (Skor $_ksprScore)',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF27AE60),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isEn ? 'Low Risk Pregnancy' : 'Risiko Rendah (Normal)',
                      style: GoogleFonts.outfit(fontSize: 10, color: const Color(0xFF27AE60)),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: borderColor,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFE91E63)),
            ),
          ),

          const SizedBox(height: 14),

          // Key Metrics: HPL, HPHT, Sisa Hari
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildProgressStat(
                label: isEn ? 'Est. Due Date (HPL)' : 'Taksiran Persalinan (HPL)',
                value: _hplDate,
                textColor: textColor,
                subTextColor: bodyTextColor,
              ),
              _buildProgressStat(
                label: isEn ? 'Countdown' : 'Sisa Waktu',
                value: isEn ? '$_daysRemaining Days (~12 Wks)' : '$_daysRemaining Hari (~12 Mgg)',
                textColor: const Color(0xFFE91E63),
                subTextColor: bodyTextColor,
              ),
              _buildProgressStat(
                label: isEn ? 'LMP (HPHT)' : 'Awal Haid (HPHT)',
                value: _hphtDate,
                textColor: textColor,
                subTextColor: bodyTextColor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressStat({
    required String label,
    required String value,
    required Color textColor,
    required Color subTextColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(fontSize: 10, color: subTextColor, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w800, color: textColor),
        ),
      ],
    );
  }

  Widget _buildTabNavigator({
    required bool isEn,
    required bool isDark,
    required Color primaryColor,
    required Color textColor,
    required Color cardColor,
    required Color borderColor,
  }) {
    final tabs = [
      {'icon': Icons.assignment_rounded, 'label': isEn ? 'ANC 10T & Visits' : 'Riwayat ANC 10T & Kontrol'},
      {'icon': Icons.insights_rounded, 'label': isEn ? 'Growth Metrics' : 'Grafik Ibu & Janin'},
      {'icon': Icons.menu_book_rounded, 'label': isEn ? 'KIA Education' : 'Edukasi Buku KIA'},
    ];

    return Row(
      children: List.generate(tabs.length, (i) {
        final isSelected = _selectedTab == i;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i < tabs.length - 1 ? 10 : 0),
            child: InkWell(
              onTap: () => setState(() => _selectedTab = i),
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFE91E63) : cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? const Color(0xFFE91E63) : borderColor,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      tabs[i]['icon'] as IconData,
                      size: 16,
                      color: isSelected ? Colors.white : textColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      tabs[i]['label'] as String,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isSelected ? Colors.white : textColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildNextVisitCard({
    required bool isEn,
    required bool isDark,
    required Color primaryColor,
    required Color textColor,
    required Color bodyTextColor,
    required Color cardColor,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF27AE60).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF27AE60).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF27AE60),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.event_available_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF27AE60),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'KONTROL BERIKUTNYA: K5',
                        style: GoogleFonts.outfit(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '15 Desember 2026',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Faskes: $_puskesmasName • Penanggung Jawab: $_bidanName',
                  style: GoogleFonts.outfit(fontSize: 11, color: bodyTextColor),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              CustomSnackbar.info(
                context,
                'Pengingat jadwal kontrol ANC telah disinkronkan ke kalender lokal Anda.',
                title: 'Pengingat Aktif',
              );
            },
            icon: const Icon(Icons.notification_add_rounded, color: Color(0xFF27AE60)),
            tooltip: 'Pasang Pengingat',
          ),
        ],
      ),
    );
  }

  Widget _buildAncTimeline({
    required bool isEn,
    required bool isDark,
    required Color primaryColor,
    required Color textColor,
    required Color bodyTextColor,
    required Color cardColor,
    required Color borderColor,
  }) {
    final visits = [
      {
        'step': 'K1',
        'trimester': 'Trimester 1 (Usia 10 Mgg)',
        'date': '12 Jan 2026',
        'provider': 'Dokter Puskesmas (USG)',
        'bb': '54.2 kg',
        'td': '110/70',
        'tfu': '-',
        'djj': '145 bpm',
        'hb': '12.4 g/dL',
        'done': true,
      },
      {
        'step': 'K2',
        'trimester': 'Trimester 2 (Usia 16 Mgg)',
        'date': '24 Feb 2026',
        'provider': 'Bidan Desa',
        'bb': '56.0 kg',
        'td': '115/75',
        'tfu': '16 cm',
        'djj': '142 bpm',
        'hb': '-',
        'done': true,
      },
      {
        'step': 'K3',
        'trimester': 'Trimester 2 (Usia 22 Mgg)',
        'date': '10 Apr 2026',
        'provider': 'Bidan Desa',
        'bb': '58.5 kg',
        'td': '120/80',
        'tfu': '21 cm',
        'djj': '140 bpm',
        'hb': '12.1 g/dL',
        'done': true,
      },
      {
        'step': 'K4',
        'trimester': 'Trimester 3 (Usia 28 Mgg)',
        'date': '22 Mei 2026',
        'provider': 'Bidan Desa & Lab',
        'bb': '61.0 kg',
        'td': '110/70',
        'tfu': '26 cm',
        'djj': '148 bpm',
        'hb': '11.8 g/dL',
        'done': true,
      },
      {
        'step': 'K5',
        'trimester': 'Trimester 3 (Usia 32 Mgg)',
        'date': '15 Des 2026 (Mendatang)',
        'provider': 'Dokter Spesialis / Bidan',
        'bb': '-',
        'td': '-',
        'tfu': '-',
        'djj': '-',
        'hb': '-',
        'done': false,
      },
      {
        'step': 'K6',
        'trimester': 'Trimester 3 (Usia 36 Mgg)',
        'date': 'Januari 2027 (Rencana Persalinan)',
        'provider': 'Faskes Rujukan / Pusk',
        'bb': '-',
        'td': '-',
        'tfu': '-',
        'djj': '-',
        'hb': '-',
        'done': false,
      },
    ];

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isEn ? 'ANC 10T CLINICAL TIMELINE (IMMUTABLE)' : 'RIWAYAT KUNJUNGAN ANC 10T (BERANTAI)',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: textColor,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF1ABC9C).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.link_rounded, size: 12, color: Color(0xFF1ABC9C)),
                    const SizedBox(width: 4),
                    Text(
                      'Hash Chain Verified',
                      style: GoogleFonts.outfit(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1ABC9C),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: visits.length,
            separatorBuilder: (_, _) => const Divider(height: 24),
            itemBuilder: (context, i) {
              final v = visits[i];
              final isDone = v['done'] == true;

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: isDone
                          ? const Color(0xFFE91E63)
                          : borderColor.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      v['step'] as String,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: isDone ? Colors.white : bodyTextColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              v['trimester'] as String,
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: textColor,
                              ),
                            ),
                            Text(
                              v['date'] as String,
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                color: isDone ? const Color(0xFF27AE60) : bodyTextColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Pemeriksa: ${v['provider']}',
                          style: GoogleFonts.outfit(fontSize: 11, color: bodyTextColor),
                        ),
                        if (isDone) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              _buildMetricChip('BB', v['bb'] as String, borderColor, textColor),
                              _buildMetricChip('TD', v['td'] as String, borderColor, textColor),
                              _buildMetricChip('TFU', v['tfu'] as String, borderColor, textColor),
                              _buildMetricChip('DJJ', v['djj'] as String, borderColor, textColor),
                              _buildMetricChip('Hb', v['hb'] as String, borderColor, textColor),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMetricChip(String label, String value, Color border, Color text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: border.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border),
      ),
      child: Text(
        '$label: $value',
        style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w700, color: text),
      ),
    );
  }

  Widget _buildGrowthMetrics({
    required bool isEn,
    required bool isDark,
    required Color primaryColor,
    required Color textColor,
    required Color bodyTextColor,
    required Color cardColor,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isEn ? 'Maternal & Fetal Health Indicators' : 'Indikator Pertumbuhan Ibu & Janin',
            style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w800, color: textColor),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildHealthCard(
                  title: 'Kenaikan Berat Badan',
                  value: '+7.0 kg',
                  status: 'Normal (Rekomendasi 11-16 kg)',
                  color: const Color(0xFF27AE60),
                  icon: Icons.monitor_weight_rounded,
                  cardBg: cardColor,
                  borderColor: borderColor,
                  textColor: textColor,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildHealthCard(
                  title: 'Lingkar Lengan Atas (LiLA)',
                  value: '26.5 cm',
                  status: 'Bebas KEK (>23.5 cm)',
                  color: const Color(0xFF27AE60),
                  icon: Icons.straighten_rounded,
                  cardBg: cardColor,
                  borderColor: borderColor,
                  textColor: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildHealthCard(
                  title: 'Denyut Jantung Janin (DJJ)',
                  value: '148 bpm',
                  status: 'Normal (120 - 160 bpm)',
                  color: const Color(0xFFE91E63),
                  icon: Icons.favorite_rounded,
                  cardBg: cardColor,
                  borderColor: borderColor,
                  textColor: textColor,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _buildHealthCard(
                  title: 'Kadar Hemoglobin (Hb)',
                  value: '11.8 g/dL',
                  status: 'Bebas Anemia (≥11.0 g/dL)',
                  color: const Color(0xFF1ABC9C),
                  icon: Icons.water_drop_rounded,
                  cardBg: cardColor,
                  borderColor: borderColor,
                  textColor: textColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHealthCard({
    required String title,
    required String value,
    required String status,
    required Color color,
    required IconData icon,
    required Color cardBg,
    required Color borderColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700, color: textColor),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w900, color: color),
          ),
          const SizedBox(height: 4),
          Text(
            status,
            style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildEducationSection({
    required bool isEn,
    required bool isDark,
    required Color primaryColor,
    required Color textColor,
    required Color bodyTextColor,
    required Color cardColor,
    required Color borderColor,
  }) {
    final tips = [
      {
        'title': 'Gizi Trimester 3: Persiapan Persalinan',
        'desc': 'Tingkatkan asupan zat besi (Fe), kalsium, dan asam folat. Konsumsi tablet tambah darah rutin setiap malam sebelum tidur.',
        'icon': Icons.restaurant_rounded,
      },
      {
        'title': 'Kenali Tanda Bahaya Kehamilan Trimester 3',
        'desc': 'Waspadai perdarahan, sakit kepala hebat, pandangan kabur, bengkak pada muka/tangan, atau gerakan janin berkurang (<10 kali per 12 jam).',
        'icon': Icons.warning_amber_rounded,
      },
      {
        'title': 'Perencanaan Persalinan dan Pencegahan Komplikasi (P4K)',
        'desc': 'Siapkan penolong persalinan (bidan/dokter), tempat bersalin, calon donor darah keluarga, dan transportasi rujukan.',
        'icon': Icons.local_hospital_rounded,
      },
    ];

    return Column(
      children: tips.map((t) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFE91E63).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(t['icon'] as IconData, color: const Color(0xFFE91E63), size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t['title'] as String,
                      style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w800, color: textColor),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      t['desc'] as String,
                      style: GoogleFonts.outfit(fontSize: 11.5, color: bodyTextColor, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTransitionBanner({
    required bool isEn,
    required bool isDark,
    required Color textColor,
    required Color bodyTextColor,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF3498DB).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF3498DB).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF3498DB),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.sync_alt_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Transisi Otomatis: Ibu Hamil 9 Bulan ➔ VitaScale Anak (0–59 Bulan)',
                  style: GoogleFonts.outfit(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF2980B9),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  isEn
                    ? 'Upon delivery, MomiCare records become permanent archive and your baby profile automatically connects to VitaScale Anak in My Family menu.'
                    : 'Setelah masa kehamilan 9 bulan selesai dan persalinan dicatat, riwayat MomiCare tersimpan aman sebagai arsip dan profil bayi Anda otomatis terhubung ke pemantauan VitaScale Anak (0-59 bulan) di menu My Family.',
                  style: GoogleFonts.outfit(fontSize: 11, color: bodyTextColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
