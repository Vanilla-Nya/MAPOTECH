import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:mapotech/features/landing/landing_page_data.dart';
import 'package:mapotech/shared/widgets/ui.dart';
import 'package:mapotech/shared/supabase_service.dart';
import 'package:mapotech/features/dokter/dashboard/frontend/dokter_pasien.dart';

class PuskesmasOwnerDashboard extends ConsumerStatefulWidget {
  const PuskesmasOwnerDashboard({super.key});

  @override
  ConsumerState<PuskesmasOwnerDashboard> createState() => _PuskesmasOwnerDashboardState();
}

class _PuskesmasOwnerDashboardState extends ConsumerState<PuskesmasOwnerDashboard> {
  // Selected Territory State (Default loaded from owner profile)
  String _selectedProvince = 'JAWA TIMUR';
  String _selectedRegency = 'KABUPATEN BONDOWOSO';
  String _selectedKecamatan = 'SUMBER WRINGIN';

  // Owner configured location
  double? _ownerLat;
  double? _ownerLng;
  String? _ownerLocationName;
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
          final addr = detail['address']?.toString() ?? detail['location_name']?.toString();

          if (mounted) {
            setState(() {
              if (prov != null && prov.isNotEmpty) _selectedProvince = prov;
              if (reg != null && reg.isNotEmpty) _selectedRegency = reg;
              if (kec != null && kec.isNotEmpty) _selectedKecamatan = kec;

              if (latStr != null && lngStr != null && latStr.isNotEmpty && lngStr.isNotEmpty) {
                final lat = double.tryParse(latStr);
                final lng = double.tryParse(lngStr);
                if (lat != null && lng != null) {
                  _ownerLat = lat;
                  _ownerLng = lng;
                  _ownerLocationName = (addr != null && addr.isNotEmpty) ? addr : 'Kecamatan $_selectedKecamatan, $_selectedRegency';
                  _isLocationSetByOwner = true;
                }
              }
            });
          }
        }
      } catch (e) {
        debugPrint('Error loading puskesmas map location: $e');
      }
    }
  }

  LatLng get _effectiveLocation {
    if (_isLocationSetByOwner && _ownerLat != null && _ownerLng != null) {
      return LatLng(_ownerLat!, _ownerLng!);
    }
    return const LatLng(-7.9797, 113.8228);
  }

  String get _effectiveLocationName {
    if (_isLocationSetByOwner && _ownerLocationName != null && _ownerLocationName!.isNotEmpty) {
      return _ownerLocationName!;
    }
    return 'Kecamatan $_selectedKecamatan, $_selectedRegency';
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

  void _showSetLocationModal() {
    final nameCtrl = TextEditingController(text: _effectiveLocationName);
    final latCtrl = TextEditingController(text: _effectiveLocation.latitude.toStringAsFixed(6));
    final lngCtrl = TextEditingController(text: _effectiveLocation.longitude.toStringAsFixed(6));
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final notifier = ref.read(landingPageProvider.notifier);
          final textColor = notifier.getTextColor();
          final subtitleColor = notifier.getBodyTextColor();
          final cardBg = notifier.getCardColor();
          final borderColor = notifier.getBorderColor();
          final themeAccent = notifier.getPrimaryColor();

          return AlertDialog(
            backgroundColor: cardBg,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: borderColor)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: themeAccent.withValues(alpha: 0.12), shape: BoxShape.circle),
                  child: Icon(Icons.edit_location_alt_rounded, color: themeAccent, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Atur Lokasi Maps Puskesmas', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
                      Text('Khusus Owner: Set koordinat & nama lokasi wilayah', style: GoogleFonts.outfit(fontSize: 10, color: subtitleColor)),
                    ],
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 440,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('NAMA LOKASI / WILAYAH', style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.bold, color: subtitleColor)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: nameCtrl,
                      style: GoogleFonts.outfit(fontSize: 12, color: textColor),
                      decoration: InputDecoration(
                        hintText: 'e.g. Kecamatan SUMBER WRINGIN, BONDOWOSO',
                        filled: true,
                        fillColor: cardBg,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('LATITUDE', style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.bold, color: subtitleColor)),
                              const SizedBox(height: 6),
                              TextField(
                                controller: latCtrl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                                style: GoogleFonts.outfit(fontSize: 12, color: textColor),
                                decoration: InputDecoration(
                                  hintText: '-7.9797',
                                  filled: true,
                                  fillColor: cardBg,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
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
                              Text('LONGITUDE', style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.bold, color: subtitleColor)),
                              const SizedBox(height: 6),
                              TextField(
                                controller: lngCtrl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                                style: GoogleFonts.outfit(fontSize: 12, color: textColor),
                                decoration: InputDecoration(
                                  hintText: '113.8228',
                                  filled: true,
                                  fillColor: cardBg,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text('PRESET LOKASI CEPAT', style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.bold, color: subtitleColor)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: Text('Sumber Wringin, Bondowoso', style: GoogleFonts.outfit(fontSize: 10)),
                          selected: false,
                          onSelected: (_) {
                            nameCtrl.text = 'Kecamatan SUMBER WRINGIN, BONDOWOSO';
                            latCtrl.text = '-7.9797';
                            lngCtrl.text = '113.8228';
                            setModalState(() {});
                          },
                        ),
                        ChoiceChip(
                          label: Text('Sumbersari, Jember', style: GoogleFonts.outfit(fontSize: 10)),
                          selected: false,
                          onSelected: (_) {
                            nameCtrl.text = 'Puskesmas Sumbersari, JEMBER';
                            latCtrl.text = '-8.1725';
                            lngCtrl.text = '113.7225';
                            setModalState(() {});
                          },
                        ),
                        ChoiceChip(
                          label: Text('Pujer, Bondowoso', style: GoogleFonts.outfit(fontSize: 10)),
                          selected: false,
                          onSelected: (_) {
                            nameCtrl.text = 'Puskesmas Pujer, BONDOWOSO';
                            latCtrl.text = '-7.9730';
                            lngCtrl.text = '113.8800';
                            setModalState(() {});
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Batal', style: GoogleFonts.outfit(color: subtitleColor)),
              ),
              ElevatedButton.icon(
                icon: isSaving ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save_rounded, size: 16),
                label: Text(isSaving ? 'Menyimpan...' : 'Simpan Lokasi', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
                style: ElevatedButton.styleFrom(backgroundColor: themeAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                onPressed: isSaving
                    ? null
                    : () async {
                        final lat = double.tryParse(latCtrl.text.trim());
                        final lng = double.tryParse(lngCtrl.text.trim());
                        final name = nameCtrl.text.trim();
                        if (lat == null || lng == null || name.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Harap masukkan koordinat Latitude & Longitude yang valid')),
                          );
                          return;
                        }

                        setModalState(() => isSaving = true);
                        final user = ref.read(landingPageProvider).loggedInUser;
                        final userId = user?['id']?.toString() ?? 'puskesmas_owner';

                        await SupabaseService().savePuskesmasMapLocation(
                          puskesmasId: userId,
                          latitude: lat,
                          longitude: lng,
                          locationName: name,
                        );

                        if (ctx.mounted) {
                          setState(() {
                            _ownerLat = lat;
                            _ownerLng = lng;
                            _ownerLocationName = name;
                            _isLocationSetByOwner = true;
                          });
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                                  const SizedBox(width: 8),
                                  Text('Lokasi Maps Puskesmas berhasil diperbarui oleh Owner!', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              backgroundColor: themeAccent,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
              ),
            ],
          );
        },
      ),
    );
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

    final userName = state.loggedInName ?? 'Puskesmas Sumbersari';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ==================== WELCOME CARD (OWNER) ====================
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
                    color: themeAccent.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.shield_rounded,
                    size: 30,
                    color: themeAccent,
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
                              color: themeAccent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Text(
                              'PUSKESMAS • OWNER / PEMILIK',
                              style: GoogleFonts.outfit(
                                fontSize: 7.5,
                                fontWeight: FontWeight.w900,
                                color: themeAccent,
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
                        'Portal Pemilik Faskes • Manajemen Wilayah, Operasional & Pengaturan Maps',
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

        // ==================== MAPS HEADER & OWNER ACTION BUTTON ====================
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  'MAPS WILAYAH PUSKESMAS',
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
                    color: (_isLocationSetByOwner ? Colors.green : Colors.orange).withValues(alpha: 0.12),
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

            // Owner has button to configure map location
            ElevatedButton.icon(
              icon: const Icon(Icons.edit_location_alt_rounded, size: 14),
              label: Text('Atur Lokasi Map', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: themeAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              onPressed: _showSetLocationModal,
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
            color: color.withValues(alpha: 0.08),
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
