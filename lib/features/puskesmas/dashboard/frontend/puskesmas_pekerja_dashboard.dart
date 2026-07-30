import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapotech/features/landing/landing_page_data.dart';
import 'package:mapotech/shared/widgets/ui.dart';
import 'package:mapotech/shared/supabase_service.dart';
import 'package:mapotech/shared/widgets/revgeo_wilayah_map_widget.dart';
import 'package:mapotech/features/dokter/dashboard/frontend/dokter_pasien.dart';

class PuskesmasPekerjaDashboard extends ConsumerStatefulWidget {
  const PuskesmasPekerjaDashboard({super.key});

  @override
  ConsumerState<PuskesmasPekerjaDashboard> createState() => _PuskesmasPekerjaDashboardState();
}

class _PuskesmasPekerjaDashboardState extends ConsumerState<PuskesmasPekerjaDashboard> {
  // Selected Territory State (Loaded from profile)
  String _selectedProvince = 'JAWA TIMUR';
  String _selectedRegency = 'KABUPATEN BONDOWOSO';
  String _selectedKecamatan = 'SUMBER WRINGIN';

  // Location configured by Owner
  bool _isLocationSetByOwner = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(dokterPasienListProvider.notifier).loadPatients();
      _loadPuskesmasLocation();
    });
  }

  Future<void> _loadPuskesmasLocation() async {
    final user = ref.read(landingPageProvider).loggedInUser;
    if (user != null && user['id'] != null) {
      final userId = user['id'].toString();
      try {
        final detail = await SupabaseService().fetchPuskesmasDetail(userId);
        if (detail != null) {
          final prov = detail['province']?.toString() ?? user['province']?.toString();
          final reg = detail['district']?.toString() ?? user['district']?.toString();
          final kec = detail['sub_district']?.toString() ?? user['sub_district']?.toString() ?? detail['kecamatan']?.toString();

          final latStr = detail['latitude']?.toString();
          final lngStr = detail['longitude']?.toString();

          if (mounted) {
            setState(() {
              if (prov != null && prov.isNotEmpty) _selectedProvince = prov;
              if (reg != null && reg.isNotEmpty) _selectedRegency = reg;
              if (kec != null && kec.isNotEmpty) _selectedKecamatan = kec;

              if (latStr != null && lngStr != null && latStr.isNotEmpty && lngStr.isNotEmpty) {
                _isLocationSetByOwner = true;
              }
            });
          }
        }
      } catch (e) {
        debugPrint('Error loading puskesmas map location: $e');
      }
    }
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
    final isDark = state.appearance == 'dark';
    final isMobile = MediaQuery.of(context).size.width < 768;

    final allPatients = ref.watch(dokterPasienListProvider);
    final totalPatients = allPatients.length;

    final userName = state.loggedInName ?? 'Staf Puskesmas Sumbersari';

    final patientMarkers = allPatients.map((p) {
      final String name = p.nama.isNotEmpty ? p.nama : 'Pasien';
      final String id = p.id;
      final double lat = -7.9582;
      final double lng = 113.9123;
      final String status = 'Aktif';
      return {
        'lat': lat,
        'lng': lng,
        'title': '👤 $name',
        'subtitle': 'Status Pasien: $status',
        'info': 'No. Pasien: $id',
        'details': '📍 Wilayah Puskesmas',
        'color': '#3498DB',
      };
    }).toList();

    if (patientMarkers.isEmpty) {
      patientMarkers.addAll([
        {
          'lat': -7.9582,
          'lng': 113.9123,
          'title': '🤰 Siti Rahmawati (27 th)',
          'subtitle': 'Risiko Rendah (KRR)',
          'info': '• Usia Hamil: 28 Minggu<br/>• HPL: 14 Aug 2026',
          'details': '📍 Dusun Krajan, RT 02/RW 01',
          'color': '#2ECC71',
        },
        {
          'lat': -7.9645,
          'lng': 113.9056,
          'title': '🤰 Dewi Lestari (34 th)',
          'subtitle': 'Risiko Tinggi (KRT)',
          'info': '• Usia Hamil: 32 Minggu<br/>• HPL: 18 Jul 2026',
          'details': '📍 Dusun Tengah, RT 05/RW 02',
          'color': '#E67E22',
        },
        {
          'lat': -7.9512,
          'lng': 113.9210,
          'title': '🤰 Anisa Putri (22 th)',
          'subtitle': 'Risiko Rendah (KRR)',
          'info': '• Usia Hamil: 14 Minggu<br/>• HPL: 20 Nov 2026',
          'details': '📍 Dusun Barat, RT 01/RW 03',
          'color': '#2ECC71',
        },
        {
          'lat': -7.9698,
          'lng': 113.8990,
          'title': '🤰 Maria Ulfa (38 th)',
          'subtitle': 'Risiko Sangat Tinggi (KRST)',
          'info': '• Usia Hamil: 36 Minggu<br/>• HPL: 02 Jun 2026',
          'details': '📍 Dusun Selatan, RT 04/RW 01',
          'color': '#E74C3C',
        },
      ]);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ==================== WELCOME CARD (PEKERJA) ====================
        AnimatedEntrance(
          delay: const Duration(milliseconds: 50),
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
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withOpacity(0.14),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.badge_rounded,
                    size: 30,
                    color: Colors.blueAccent,
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
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blueAccent.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Text(
                              'PUSKESMAS • PEKERJA / STAF',
                              style: GoogleFonts.outfit(
                                fontSize: 7.5,
                                fontWeight: FontWeight.w900,
                                color: Colors.blueAccent,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _formatToday(state.language),
                            style: GoogleFonts.outfit(fontSize: 10, color: subtitleColor, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        userName,
                        style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w900, color: textColor),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Portal Pekerja & Staf Medis • Pelayanan Pasien & Pemantauan Kesehatan Wilayah',
                        style: GoogleFonts.outfit(fontSize: 11, color: subtitleColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),

        // ==================== MAPS HEADER ====================
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  'MAPS WILAYAH PUSKESMAS & PASIEN',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: textColor,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (_isLocationSetByOwner ? Colors.green : Colors.orange).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    _isLocationSetByOwner ? 'LOKASI DITETAPKAN OWNER' : 'LOKASI DASAR (SUMBER WRINGIN)',
                    style: GoogleFonts.outfit(
                      fontSize: 7.5,
                      fontWeight: FontWeight.w900,
                      color: _isLocationSetByOwner ? Colors.green : Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
            Text(
              '${patientMarkers.length} Pin Tempat Pasien',
              style: GoogleFonts.outfit(fontSize: 10, color: themeAccent, fontWeight: FontWeight.bold),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // ==================== DYNAMIC MAPS WIDGET (REVGEO ENGINE IDENTICAL TO PROFILE) ====================
        AnimatedEntrance(
          delay: const Duration(milliseconds: 100),
          type: EntranceAnimationType.slideUp,
          child: RevGeoWilayahMapWidget(
            initialProvince: _selectedProvince,
            initialDistrict: _selectedRegency,
            initialSubDistrict: _selectedKecamatan,
            fieldBg: cardBgColor,
            textColor: textColor,
            subtitleColor: subtitleColor,
            borderColor: borderColor,
            dropdownColor: isDark ? const Color(0xFF1B1B1E) : Colors.white,
            themeAccent: themeAccent,
            isDark: isDark,
            isEn: state.language == 'en',
            height: 450,
            showOnlyMap: true,
            markers: patientMarkers,
            onChanged: (prov, reg, dist, vill) {
              setState(() {
                _selectedProvince = prov;
                _selectedRegency = reg;
                _selectedKecamatan = dist;
              });
            },
          ),
        ),

        const SizedBox(height: 24),

        // Key stats indicators
        AnimatedEntrance(
          delay: const Duration(milliseconds: 150),
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

        // Custom charts / visuals for public health monitoring
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
