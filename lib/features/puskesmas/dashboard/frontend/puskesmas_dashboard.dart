import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapotech/features/landing/landing_page_data.dart';
import 'package:mapotech/shared/widgets/ui.dart';
import 'package:mapotech/features/dokter/dashboard/frontend/dokter_pasien.dart'; // We reuse patient list notifier

class PuskesmasDashboard extends ConsumerStatefulWidget {
  const PuskesmasDashboard({super.key});

  @override
  ConsumerState<PuskesmasDashboard> createState() => _PuskesmasDashboardState();
}

class _PuskesmasDashboardState extends ConsumerState<PuskesmasDashboard> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(dokterPasienListProvider.notifier).loadPatients();
    });
  }

  String _formatToday(String lang) {
    final now = DateTime.now();
    final dayNamesEn = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final dayNamesId = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
    final monthNamesEn = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final monthNamesId = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];

    final dayName = lang == 'en' ? dayNamesEn[now.weekday - 1] : dayNamesId[now.weekday - 1];
    final monthName = lang == 'en' ? monthNamesEn[now.month - 1] : monthNamesId[now.month - 1];

    return '$dayName, ${now.day} $monthName ${now.year}';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(landingPageProvider);
    final notifier = ref.read(landingPageProvider.notifier);

    final cardBgColor = notifier.getCardColor();
    final textColor = notifier.getTextColor();
    final subtitleColor = notifier.getBodyTextColor();
    final borderColor = notifier.getBorderColor();
    final themeAccent = notifier.getPrimaryColor();
    final isMobile = MediaQuery.of(context).size.width < 768;

    final allPatients = ref.watch(dokterPasienListProvider);
    final totalPatients = allPatients.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Welcome Banner Card
        AnimatedEntrance(
          delay: Duration.zero,
          type: EntranceAnimationType.slideUp,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cardBgColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: themeAccent.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(Icons.domain_rounded, size: 28, color: themeAccent),
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
                              color: themeAccent.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Text(
                              'PUSKESMAS AKTIF',
                              style: GoogleFonts.outfit(fontSize: 6.5, fontWeight: FontWeight.w900, color: themeAccent),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatToday(state.language),
                            style: GoogleFonts.outfit(fontSize: 9, color: subtitleColor, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        state.loggedInName ?? 'Puskesmas Sumbersari',
                        style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w900, color: textColor),
                      ),
                      Text(
                        'Pusat Kesehatan Masyarakat Terintegrasi SatuSehat & BPJS',
                        style: GoogleFonts.outfit(fontSize: 10, color: subtitleColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Key stats indicators
        AnimatedEntrance(
          delay: const Duration(milliseconds: 100),
          type: EntranceAnimationType.scale,
          child: GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: isMobile ? 2 : 4,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.6,
            children: [
              MetricCard(
                icon: Icons.people_rounded,
                label: 'TOTAL PASIEN TERDAFTAR',
                count: '$totalPatients',
                subtitleColor: subtitleColor,
                countColor: textColor,
                cardBgColor: cardBgColor,
                borderColor: borderColor,
              ),
              MetricCard(
                icon: Icons.verified_user_rounded,
                label: 'SINKRONISASI SATUSEHAT',
                count: '100%',
                subtitleColor: subtitleColor,
                countColor: themeAccent,
                cardBgColor: cardBgColor,
                borderColor: borderColor,
              ),
              MetricCard(
                icon: Icons.account_balance_wallet_rounded,
                label: 'KLAIM BPJS BULAN INI',
                count: '24',
                subtitleColor: subtitleColor,
                countColor: Colors.blue,
                cardBgColor: cardBgColor,
                borderColor: borderColor,
              ),
              MetricCard(
                icon: Icons.sync_rounded,
                label: 'AUTO SYNC DATA JKN',
                count: 'AKTIF',
                subtitleColor: subtitleColor,
                countColor: Colors.green,
                cardBgColor: cardBgColor,
                borderColor: borderColor,
              ),
            ],
          ),
        ),

        const SizedBox(height: 28),

        // Custom charts / mock visuals for public health monitoring
        AnimatedEntrance(
          delay: const Duration(milliseconds: 200),
          type: EntranceAnimationType.slideUp,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 6,
                child: Container(
                  height: 300,
                  decoration: BoxDecoration(
                    color: cardBgColor,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: borderColor),
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'STATISTIK PENYAKIT BULANAN (ICD-10)',
                        style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: subtitleColor),
                      ),
                      const SizedBox(height: 16),
                      _buildDiseaseBar('A90 - Dengue Fever', 0.8, themeAccent, totalPatients > 0 ? (totalPatients * 0.4).round() : 12),
                      const SizedBox(height: 12),
                      _buildDiseaseBar('J06 - Acute Upper Respiratory Infection', 0.6, Colors.blue, totalPatients > 0 ? (totalPatients * 0.3).round() : 9),
                      const SizedBox(height: 12),
                      _buildDiseaseBar('K30 - Dyspepsia', 0.3, Colors.orange, totalPatients > 0 ? (totalPatients * 0.15).round() : 4),
                    ],
                  ),
                ),
              ),
              if (!isMobile) ...[
                const SizedBox(width: 20),
                Expanded(
                  flex: 4,
                  child: Container(
                    height: 300,
                    decoration: BoxDecoration(
                      color: cardBgColor,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: borderColor),
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SINKRONISASI SATUSEHAT KEMENKES',
                          style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: subtitleColor),
                        ),
                        const Spacer(),
                        Center(
                          child: Icon(Icons.cloud_done_rounded, size: 80, color: themeAccent),
                        ),
                        const Spacer(),
                        Center(
                          child: Text(
                            'Sistem Terhubung ke Server SatuSehat',
                            style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: textColor),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Center(
                          child: Text(
                            'Semua Rekam Medis Elektronik Terkirim Otomatis',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(fontSize: 9, color: subtitleColor),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDiseaseBar(String code, double percent, Color color, int count) {
    final subtitleColor = ref.read(landingPageProvider.notifier).getBodyTextColor();
    final textColor = ref.read(landingPageProvider.notifier).getTextColor();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(code, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: textColor)),
            Text('$count pasien', style: GoogleFonts.outfit(fontSize: 10, color: subtitleColor)),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          height: 10,
          width: double.infinity,
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: percent,
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
