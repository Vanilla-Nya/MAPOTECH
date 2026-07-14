import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapotech/features/landing/landing_page_data.dart';
import 'package:mapotech/shared/widgets/ui.dart';
import 'package:mapotech/features/dokter/dashboard/frontend/dokter_pasien.dart'; // We reuse patient list notifier

class PonkesdesDashboard extends ConsumerStatefulWidget {
  const PonkesdesDashboard({super.key});

  @override
  ConsumerState<PonkesdesDashboard> createState() => _PonkesdesDashboardState();
}

class _PonkesdesDashboardState extends ConsumerState<PonkesdesDashboard> {
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
                    color: Colors.green.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.home_work_rounded, size: 28, color: Colors.green),
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
                              color: Colors.green.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Text(
                              'PONKESDES AKTIF',
                              style: GoogleFonts.outfit(fontSize: 6.5, fontWeight: FontWeight.w900, color: Colors.green),
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
                        state.loggedInName ?? 'Ponkesdes Sukowono',
                        style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w900, color: textColor),
                      ),
                      Text(
                        'Pondok Kesehatan Desa - Pelayanan Kesehatan Tingkat Desa & RT/RW',
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
                label: 'PASIEN DI WILAYAH BINAAN',
                count: '$totalPatients',
                subtitleColor: subtitleColor,
                countColor: textColor,
                cardBgColor: cardBgColor,
                borderColor: borderColor,
              ),
              MetricCard(
                icon: Icons.pregnant_woman_rounded,
                label: 'IBU HAMIL DIPANTAU',
                count: '3',
                subtitleColor: subtitleColor,
                countColor: Colors.pink,
                cardBgColor: cardBgColor,
                borderColor: borderColor,
              ),
              MetricCard(
                icon: Icons.child_care_rounded,
                label: 'BALITA (POSYANDU)',
                count: '15',
                subtitleColor: subtitleColor,
                countColor: Colors.orange,
                cardBgColor: cardBgColor,
                borderColor: borderColor,
              ),
              MetricCard(
                icon: Icons.home_rounded,
                label: 'KUNJUNGAN RUMAH',
                count: '8',
                subtitleColor: subtitleColor,
                countColor: themeAccent,
                cardBgColor: cardBgColor,
                borderColor: borderColor,
              ),
            ],
          ),
        ),

        const SizedBox(height: 28),

        // Custom list of Coverage Areas / Home visits
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
                        'JADWAL KUNJUNGAN RUMAH (RT/RW)',
                        style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: subtitleColor),
                      ),
                      const SizedBox(height: 16),
                      _buildVisitItem('Bu Ratna (68) - Pemeriksaan Tensi Darah', 'Selesai', Colors.green),
                      const SizedBox(height: 12),
                      _buildVisitItem('Pak Heru (72) - Monitoring Pasca Rawat', 'Aktif', Colors.orange),
                      const SizedBox(height: 12),
                      _buildVisitItem('Ibu Siti (28) - ANC Kehamilan 2nd Trimester', 'Rencana', Colors.blue),
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
                          'STATUS LAYANAN OFFLINE-ONLINE',
                          style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: subtitleColor),
                        ),
                        const Spacer(),
                        const Center(
                          child: Icon(Icons.wifi_rounded, size: 80, color: Colors.green),
                        ),
                        const Spacer(),
                        Center(
                          child: Text(
                            'Koneksi Database Aktif',
                            style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: textColor),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Center(
                          child: Text(
                            'Data ter-sync dengan Puskesmas Utama',
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

  Widget _buildVisitItem(String desc, String status, Color color) {
    final subtitleColor = ref.read(landingPageProvider.notifier).getBodyTextColor();
    final textColor = ref.read(landingPageProvider.notifier).getTextColor();
    final borderColor = ref.read(landingPageProvider.notifier).getBorderColor();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: ref.read(landingPageProvider.notifier).getBackgroundColor(),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              desc,
              style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: textColor),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(100),
            ),
            child: Text(
              status,
              style: GoogleFonts.outfit(fontSize: 8, fontWeight: FontWeight.w900, color: color),
            ),
          ),
        ],
      ),
    );
  }
}
