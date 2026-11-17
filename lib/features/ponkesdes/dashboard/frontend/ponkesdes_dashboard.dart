import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapotech/features/landing/landing_page_data.dart';
import 'package:mapotech/features/puskesmas/dashboard/frontend/puskesmas_pantauan_ibu_hamil.dart';
import 'package:mapotech/shared/widgets/ui.dart';
import 'package:mapotech/features/dokter/dashboard/frontend/dokter_pasien.dart'; // We reuse patient list notifier

class PonkesdesDashboard extends ConsumerStatefulWidget {
  final ValueChanged<String>? onNavigate;

  const PonkesdesDashboard({super.key, this.onNavigate});

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
    final isEn = state.language == 'en';
    final notifier = ref.read(landingPageProvider.notifier);

    final cardBgColor = notifier.getCardColor();
    final textColor = notifier.getTextColor();
    final subtitleColor = notifier.getBodyTextColor();
    final borderColor = notifier.getBorderColor();
    final themeAccent = notifier.getPrimaryColor();
    final isMobile = MediaQuery.of(context).size.width < 768;

    final allPatients = ref.watch(dokterPasienListProvider);
    final totalPatients = allPatients.length;

    final bumilList = ref.watch(ibuHamilListProvider);
    final totalBumil = bumilList.length;
    final totalKek = bumilList.where((b) => b.isKek).length;
    final totalKrt = bumilList.where((b) => b.ksprStatus.contains('Tinggi')).length;

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
                              isEn ? 'VILLAGE HEALTH POST ACTIVE' : 'PONKESDES SUMBER WRINGIN AKTIF',
                              style: GoogleFonts.outfit(fontSize: 7.5, fontWeight: FontWeight.w900, color: Colors.green),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: themeAccent.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(100),
                              border: Border.all(color: themeAccent.withOpacity(0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.hub_rounded, size: 10, color: themeAccent),
                                const SizedBox(width: 4),
                                Text(
                                  'UPTD PUSKESMAS SUMBER WRINGIN',
                                  style: GoogleFonts.outfit(fontSize: 7.5, fontWeight: FontWeight.bold, color: themeAccent),
                                ),
                              ],
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
                        state.loggedInName ?? (isEn ? 'Sumber Wringin Health Post' : 'Ponkesdes Sumber Wringin'),
                        style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w900, color: textColor),
                      ),
                      Text(
                        isEn
                            ? 'Village Health Post • Healthcare Services & Maternal Care in Sumber Wringin'
                            : 'Pondok Kesehatan Desa • Pelayanan Kesehatan & Pemantauan Maternal Desa Sumber Wringin',
                        style: GoogleFonts.outfit(fontSize: 10, color: subtitleColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Quick Actions Banner (DLC Bumil & Posyandu)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF27AE60).withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF27AE60).withOpacity(0.25)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.flash_on_rounded, size: 18, color: Color(0xFF27AE60)),
                        const SizedBox(width: 6),
                        Text(
                          isEn ? 'QUICK ACTIONS: MATERNAL & PUSKESMAS DLC' : 'MENU CEPAT DLC BUMIL & PUSKESMAS',
                          style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: textColor),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isEn
                          ? 'Puskesmas directly tracks screening results & ANC 10T data you submit for this village.'
                          : 'Puskesmas memantau langsung hasil skrining & ANC 10T yang Anda input di desa ini.',
                      style: GoogleFonts.outfit(fontSize: 9.5, color: subtitleColor),
                    ),
                  ],
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.pink,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    onPressed: () => widget.onNavigate?.call('dlc_pantauan_ibu_hamil'),
                    icon: const Icon(Icons.pregnant_woman_rounded, size: 16),
                    label: Text(
                      isEn ? 'Maternal Care ($totalBumil)' : 'Pantauan Bumil ($totalBumil)',
                      style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: themeAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    onPressed: () => widget.onNavigate?.call('dlc_form_ibu_hamil'),
                    icon: const Icon(Icons.edit_note_rounded, size: 16),
                    label: Text(
                      isEn ? '+ ANC 10T Form' : '+ Form ANC 10T',
                      style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF27AE60)),
                      foregroundColor: const Color(0xFF27AE60),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    onPressed: () => widget.onNavigate?.call('dlc_vitascale_data_anak'),
                    icon: const Icon(Icons.child_care_rounded, size: 16),
                    label: Text(
                      isEn ? 'VitaScale Children' : 'VitaScale Balita',
                      style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

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
                label: isEn ? 'VILLAGE REGISTERED PATIENTS' : 'PASIEN DI WILAYAH BINAAN',
                count: '$totalPatients',
                subtitleColor: subtitleColor,
                countColor: textColor,
                cardBgColor: cardBgColor,
                borderColor: borderColor,
              ),
              InkWell(
                onTap: () => widget.onNavigate?.call('dlc_pantauan_ibu_hamil'),
                borderRadius: BorderRadius.circular(20),
                child: MetricCard(
                  icon: Icons.pregnant_woman_rounded,
                  label: isEn ? 'MONITORED PREGNANCIES' : 'IBU HAMIL DIPANTAU (BINAAN)',
                  count: isEn ? '$totalBumil Patients' : '$totalBumil Pasien',
                  subtitleColor: subtitleColor,
                  countColor: Colors.pink,
                  cardBgColor: cardBgColor,
                  borderColor: borderColor,
                ),
              ),
              InkWell(
                onTap: () => widget.onNavigate?.call('dlc_vitascale_data_anak'),
                borderRadius: BorderRadius.circular(20),
                child: MetricCard(
                  icon: Icons.child_care_rounded,
                  label: isEn ? 'TODDLERS (POSYANDU)' : 'BALITA (POSYANDU)',
                  count: isEn ? '15 Children' : '15 Anak',
                  subtitleColor: subtitleColor,
                  countColor: Colors.orange,
                  cardBgColor: cardBgColor,
                  borderColor: borderColor,
                ),
              ),
              InkWell(
                onTap: () => widget.onNavigate?.call('dlc_pantauan_ibu_hamil'),
                borderRadius: BorderRadius.circular(20),
                child: MetricCard(
                  icon: Icons.warning_amber_rounded,
                  label: isEn ? 'HIGH-RISK PREGNANCIES' : 'RISIKO BUMIL (KRT/KEK)',
                  count: '$totalKrt KRT / $totalKek KEK',
                  subtitleColor: subtitleColor,
                  countColor: Colors.deepOrange,
                  cardBgColor: cardBgColor,
                  borderColor: borderColor,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

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
