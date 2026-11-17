import 'dart:ui';
import 'dart:io' as io;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapotech/features/landing/landing_page_data.dart';
import 'package:mapotech/shared/supabase_service.dart';
import 'package:mapotech/shared/widgets/empty_state_widget.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mapotech/features/dokter/dashboard/frontend/web_map_widget.dart';
import 'package:mapotech/features/pasien/dashboard/frontend/widgets/pasien_qr_scanner_dialog.dart';
import 'package:mapotech/features/pasien/dashboard/frontend/widgets/pasien_apotek_pos_dialog.dart';
import 'package:mapotech/shared/duitku_payment_service.dart';
import 'package:mapotech/shared/widgets/custom_dialog.dart';

/// Cari Praktik Mandiri, Puskesmas & Pustu/Ponkesdes - Pasien Dashboard Page
class PasienDokterSearch extends ConsumerStatefulWidget {
  final String? initialFilter;
  final String? customTitle;

  const PasienDokterSearch({
    super.key,
    this.initialFilter,
    this.customTitle,
  });

  @override
  ConsumerState<PasienDokterSearch> createState() => _PasienDokterSearchState();
}

class _PasienDokterSearchState extends ConsumerState<PasienDokterSearch> {
  final SupabaseService _db = SupabaseService();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  late String _selectedFilter;

  List<Map<String, dynamic>> _allDokters = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedFilter = widget.initialFilter ?? 'semua';
    _loadDoctors();
  }

  @override
  void didUpdateWidget(covariant PasienDokterSearch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialFilter != oldWidget.initialFilter && widget.initialFilter != null) {
      setState(() {
        _selectedFilter = widget.initialFilter!;
      });
    }
  }

  Future<void> _loadDoctors() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      final docs = await _db.fetchAllDoctors();
      // Filter out invisible doctors
      final visibleDocs = docs.where((d) => d['is_visible'] == true).toList();
      if (visibleDocs.isEmpty) {
        _allDokters = [
          {
            'id': 'pusk-1',
            'name': 'Puskesmas Pasrepan',
            'email': 'puskesmas.pasrepan@pasuruankab.go.id',
            'avatar_url': '',
            'nama_faskes': 'Puskesmas Pasrepan',
            'profession': 'Puskesmas',
            'is_visible': true,
            'is_bpjs': true,
            'about': 'Puskesmas Pembina Kecamatan Pasrepan melayani BPJS & Umum 24 jam dengan fasilitas Rawat Inap & UGD.',
            'whatsapp_number': '081234567890',
            'latitude': -7.7475,
            'longitude': 112.9463,
            'default_service_fee': 0.0,
            'address': 'Jl. Raya Pasrepan No. 45, Kecamatan Pasrepan, Kab. Pasuruan',
            'province': 'Jawa Timur',
            'district': 'Kabupaten Pasuruan',
            'sub_district': 'Pasrepan',
            'village': 'Pasrepan',
            'active_today': 12,
            'finished_total': 148,
            'practice_licenses': [],
            'google_maps_link': 'https://maps.google.com/?q=-7.7475,112.9463',
          },
          {
            'id': 'pusk-2',
            'name': 'Puskesmas Kejayan',
            'email': 'puskesmas.kejayan@pasuruankab.go.id',
            'avatar_url': '',
            'nama_faskes': 'Puskesmas Kejayan',
            'profession': 'Puskesmas',
            'is_visible': true,
            'is_bpjs': true,
            'about': 'Puskesmas Kejayan melayani rawat jalan, laboratorium, poli KIA, poli gigi, dan konsultasi gizi.',
            'whatsapp_number': '081234567891',
            'latitude': -7.7025,
            'longitude': 112.9015,
            'default_service_fee': 0.0,
            'address': 'Jl. Raya Kejayan No. 12, Kec. Kejayan, Kab. Pasuruan',
            'province': 'Jawa Timur',
            'district': 'Kabupaten Pasuruan',
            'sub_district': 'Kejayan',
            'village': 'Kejayan',
            'active_today': 8,
            'finished_total': 95,
            'practice_licenses': [],
            'google_maps_link': 'https://maps.google.com/?q=-7.7025,112.9015',
          },
          {
            'id': 'ponk-1',
            'name': 'Pustu Lenggong',
            'email': 'pustu.lenggong@pasuruankab.go.id',
            'avatar_url': '',
            'nama_faskes': 'Pustu Lenggong (Puskesmas Pembantu)',
            'profession': 'Ponkesdes',
            'is_visible': true,
            'is_bpjs': true,
            'about': 'Puskesmas Pembantu desa Lenggong melayani pemeriksaan dasar, posyandu lansia & balita.',
            'whatsapp_number': '081234567892',
            'latitude': -7.7510,
            'longitude': 112.9510,
            'default_service_fee': 0.0,
            'address': 'Dusun Lenggong, Desa Lenggong, Kec. Pasrepan, Kab. Pasuruan',
            'province': 'Jawa Timur',
            'district': 'Kabupaten Pasuruan',
            'sub_district': 'Pasrepan',
            'village': 'Lenggong',
            'active_today': 5,
            'finished_total': 62,
            'practice_licenses': [],
            'google_maps_link': 'https://maps.google.com/?q=-7.7510,112.9510',
          },
          {
            'id': 'ponk-2',
            'name': 'Ponkesdes Plososari',
            'email': 'ponkesdes.plososari@pasuruankab.go.id',
            'avatar_url': '',
            'nama_faskes': 'Ponkesdes Plososari',
            'profession': 'Ponkesdes',
            'is_visible': true,
            'is_bpjs': false,
            'about': 'Pondok Kesehatan Desa Plososari melayani pemeriksaan ibu hamil, Imunisasi, dan perawat desa.',
            'whatsapp_number': '081234567893',
            'latitude': -7.7600,
            'longitude': 112.9600,
            'default_service_fee': 0.0,
            'address': 'Desa Plososari, Kec. Grati, Kab. Pasuruan',
            'province': 'Jawa Timur',
            'district': 'Kabupaten Pasuruan',
            'sub_district': 'Grati',
            'village': 'Plososari',
            'active_today': 3,
            'finished_total': 41,
            'practice_licenses': [],
            'google_maps_link': 'https://maps.google.com/?q=-7.7600,112.9600',
          },
          {
            'id': 'doc-1',
            'name': 'dr. Agoes Soetanto',
            'email': 'agoes.soetanto@gmail.com',
            'avatar_url': '',
            'nama_faskes': 'Klinik dr. Agoes Soetanto',
            'profession': 'Dokter Spesialis Anak',
            'is_visible': true,
            'is_bpjs': false,
            'about': 'Praktik dokter spesialis anak berpengalaman 15+ tahun.',
            'whatsapp_number': '081298765432',
            'latitude': -7.7450,
            'longitude': 112.9400,
            'default_service_fee': 150000.0,
            'address': 'Jl. Raya Pasrepan No. 100, Kab. Pasuruan',
            'province': 'Jawa Timur',
            'district': 'Kabupaten Pasuruan',
            'sub_district': 'Pasrepan',
            'village': 'Pasrepan',
            'active_today': 20,
            'finished_total': 310,
            'practice_licenses': [],
            'google_maps_link': 'https://maps.google.com/?q=-7.7450,112.9400',
          },
        ];
      } else {
        _allDokters = visibleDocs;
      }
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredDokters {
    return _allDokters.where((d) {
      // 1. Text Search
      final q = _searchQuery.toLowerCase();
      final nameMatch = d['name'].toString().toLowerCase().contains(q);
      final clinicMatch = d['nama_faskes'].toString().toLowerCase().contains(q);
      final addressMatch = d['address'].toString().toLowerCase().contains(q);
      final textMatches = q.isEmpty || nameMatch || clinicMatch || addressMatch;

      // 2. Chip Filter (Semua, Dokter, Bidan, Puskesmas, Ponkesdes)
      bool filterMatches = true;
      if (_selectedFilter == 'dokter') {
        final prof = d['profession']?.toString().toLowerCase() ?? '';
        final faskes = d['nama_faskes']?.toString().toLowerCase() ?? '';
        filterMatches = (prof.contains('doc') || prof.contains('dok') || prof.isEmpty) &&
            !prof.contains('pusk') &&
            !prof.contains('ponk') &&
            !prof.contains('pustu') &&
            !faskes.contains('pusk') &&
            !faskes.contains('ponk');
      } else if (_selectedFilter == 'bidan') {
        final prof = d['profession']?.toString().toLowerCase() ?? '';
        filterMatches = prof.contains('bid') || prof.contains('mid') || prof.contains('nurse') || prof.contains('perawat');
      } else if (_selectedFilter == 'puskesmas') {
        final prof = d['profession']?.toString().toLowerCase() ?? '';
        final faskes = d['nama_faskes']?.toString().toLowerCase() ?? '';
        filterMatches = prof.contains('pusk') || faskes.contains('pusk');
      } else if (_selectedFilter == 'ponkesdes') {
        final prof = d['profession']?.toString().toLowerCase() ?? '';
        final faskes = d['nama_faskes']?.toString().toLowerCase() ?? '';
        filterMatches = prof.contains('ponk') ||
            prof.contains('village') ||
            prof.contains('clinic') ||
            prof.contains('pustu') ||
            faskes.contains('ponk') ||
            faskes.contains('pustu');
      }

      return textMatches && filterMatches;
    }).toList();
  }

  void _showDoctorDetail(BuildContext context, Map<String, dynamic> dokter, {int initialTabIndex = 0}) {
    final state = ref.read(landingPageProvider);
    final isDark = state.appearance == 'dark';
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (ctx) => DoctorDetailDialog(
        dokter: dokter,
        isDark: isDark,
        initialTabIndex: initialTabIndex,
      ),
    );
  }

  void _openQrScanner(BuildContext context) {
    final state = ref.read(landingPageProvider);
    final isDark = state.appearance == 'dark';
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (ctx) => PasienQrScannerDialog(
        onDoctorScanned: (doctor) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Dokter terdeteksi: ${doctor["name"] ?? "Dokter"}. Membuka pendaftaran...',
                style: GoogleFonts.outfit(),
              ),
              backgroundColor: const Color(0xFF0F9D58),
              duration: const Duration(seconds: 2),
            ),
          );
          _showDoctorDetail(context, doctor, initialTabIndex: 1);
        },
        onApotekScanned: (apotek) {
          showDialog(
            context: context,
            barrierColor: Colors.black.withOpacity(0.55),
            builder: (dCtx) => PasienApotekPosDialog(
              pharmacy: apotek,
              isDark: isDark,
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(landingPageProvider);
    final isEn = state.language == 'en';

    final isDark = state.appearance == 'dark';
    final notifier = ref.read(landingPageProvider.notifier);
    final cardBgColor = notifier.getCardColor();
    final textColor = notifier.getTextColor();
    final subtitleColor = notifier.getBodyTextColor();
    final borderColor = notifier.getBorderColor();
    final inputBg = isDark ? const Color(0xFF1E1E22) : const Color(0xFFF8FAFD);
    final themeAccent = notifier.getPrimaryColor();
    final purpleAccent = notifier.getPrimaryColor();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ──────────────────────────────────────────────────────────────────
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
              // Search Field
              Container(
                height: 52,
                decoration: BoxDecoration(
                  color: inputBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderColor),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(Icons.search_rounded, size: 20, color: subtitleColor),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                        decoration: InputDecoration(
                          hintText: _selectedFilter == 'puskesmas'
                              ? (isEn
                                  ? 'Search public health center, clinic, or area...'
                                  : 'Cari nama puskesmas, poli, atau daerah...')
                              : _selectedFilter == 'ponkesdes'
                                  ? (isEn
                                      ? 'Search village health post, pustu, or village...'
                                      : 'Cari nama pustu, ponkesdes, atau desa...')
                                  : _selectedFilter == 'bidan'
                                      ? (isEn
                                          ? 'Search midwife, nurse, or clinic...'
                                          : 'Cari bidan, perawat, atau tempat praktik...')
                                      : (isEn
                                          ? 'Search private practice or specialist...'
                                          : 'Cari praktik mandiri atau spesialis...'),
                          hintStyle: GoogleFonts.outfit(
                            fontSize: 13,
                            color: subtitleColor.withOpacity(0.6),
                          ),
                          border: InputBorder.none,
                        ),
                        onChanged: (val) => setState(() => _searchQuery = val),
                      ),
                    ),
                    if (_searchQuery.isNotEmpty)
                      IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: subtitleColor,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Action & Filter Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _openQrScanner(context),
                    icon: const Icon(Icons.qr_code_scanner_rounded, size: 16),
                    label: Text(
                      isEn ? 'Scan Doctor QR' : 'Scan QR Dokter',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 11.5,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: themeAccent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      _buildFilterChip(
                        isEn ? 'All' : 'Semua',
                        'semua',
                        subtitleColor,
                        purpleAccent,
                        borderColor,
                        cardBgColor,
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        isEn ? 'Doctors' : 'Dokter',
                        'dokter',
                        subtitleColor,
                        purpleAccent,
                        borderColor,
                        cardBgColor,
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        isEn ? 'Midwives' : 'Bidan',
                        'bidan',
                        subtitleColor,
                        purpleAccent,
                        borderColor,
                        cardBgColor,
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: subtitleColor,
                      ),
                      Text(
                        isEn ? 'Sort Filter' : 'Filter Urutan',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: subtitleColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // ──────────────────────────────────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.customTitle ??
                      (_selectedFilter == 'puskesmas'
                          ? (isEn ? 'Available Public Health Centers' : 'Faskes Puskesmas Tersedia')
                          : _selectedFilter == 'ponkesdes'
                              ? (isEn ? 'Available Village Health Posts' : 'Faskes Pustu & Ponkesdes Tersedia')
                              : _selectedFilter == 'bidan'
                                  ? (isEn ? 'Available Midwife Practices' : 'Praktik Bidan Tersedia')
                                  : (isEn ? 'Available Private Practices' : 'Praktik Mandiri Tersedia')),
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _searchQuery.isEmpty
                      ? (isEn ? 'Showing the best healthcare search results for you' : 'Menampilkan hasil pencarian terbaik untuk Anda')
                      : (isEn ? 'Search results for "$_searchQuery"' : 'Hasil pencarian untuk "$_searchQuery"'),
                  style: GoogleFonts.outfit(fontSize: 11, color: subtitleColor),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: purpleAccent.withOpacity(0.10),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                _isLoading
                    ? '...'
                    : (isEn ? '${_filteredDokters.length} Results' : '${_filteredDokters.length} Hasil'),
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: purpleAccent,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬ Dokter List Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
        if (_isLoading)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 60),
              child: CircularProgressIndicator(color: themeAccent),
            ),
          )
        else if (_errorMessage != null)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  Icon(Icons.error_outline_rounded, color: Colors.red[400], size: 48),
                  const SizedBox(height: 12),
                  Text(
                    'Gagal memuat data dokter',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      color: subtitleColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadDoctors,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: themeAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Coba Lagi',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
        else if (_filteredDokters.isEmpty)
          EmptyStateWidget(
            icon: Icons.search_off_rounded,
            title: 'Tidak ada hasil ditemukan',
            subtitle: 'Coba kata kunci lain atau hapus filter',
            cardBg: cardBgColor,
            border: borderColor,
            textColor: textColor,
            subtitleColor: subtitleColor,
          )
        else
          Column(
            children: _filteredDokters.map((dokter) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _buildDokterCard(
                  dokter,
                  cardBgColor,
                  borderColor,
                  textColor,
                  subtitleColor,
                  themeAccent,
                  purpleAccent,
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildFilterChip(
    String label,
    String value,
    Color subtitleColor,
    Color accentColor,
    Color borderColor,
    Color cardBg,
  ) {
    final isSelected = _selectedFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? accentColor.withOpacity(0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: isSelected ? accentColor : borderColor),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: isSelected ? accentColor : subtitleColor,
          ),
        ),
      ),
    );
  }

  Widget _buildDokterCard(
    Map<String, dynamic> dokter,
    Color cardBg,
    Color border,
    Color text,
    Color subtitle,
    Color accent,
    Color purple,
  ) {
    // Extract initials
    final nameParts = (dokter['name'] as String).trim().split(' ');
    String initials = '';
    if (nameParts.isNotEmpty) {
      if (nameParts.length >= 2) {
        initials = (nameParts[0].isNotEmpty ? nameParts[0][0] : '') +
            (nameParts[1].isNotEmpty ? nameParts[1][0] : '');
      } else {
        initials = nameParts[0].isNotEmpty ? nameParts[0][0] : '';
      }
    }
    initials = initials.toUpperCase();
    if (initials.isEmpty) initials = 'DR';

    return InkWell(
      onTap: () => _showDoctorDetail(context, dokter),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: accent.withOpacity(0.12),
                shape: BoxShape.circle,
                border: Border.all(color: accent.withOpacity(0.3), width: 2),
              ),
              alignment: Alignment.center,
              child: ClipOval(
                child: dokter['avatar_url'] != null
                    ? Image.network(
                        dokter['avatar_url']!,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Text(
                          initials,
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: accent,
                          ),
                        ),
                      )
                    : Text(
                        initials,
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: accent,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 16),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dokter['name'],
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.medical_services_outlined,
                        size: 12,
                        color: accent,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        dokter['profession'] ?? 'Dokter',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          color: accent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined, size: 12, color: subtitle),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          dokter['nama_faskes'] ?? 'Praktek Mandiri',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            color: subtitle,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Chips row
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _buildInfoChip(
                        '${dokter['finished_total']} Pasien Ã‚Â· ${dokter['active_today']} antrian',
                        Icons.people_outline_rounded,
                        accent,
                      ),
                      _buildInfoChip(
                        dokter['profession'] ?? 'Dokter',
                        Icons.person_outline_rounded,
                        purple,
                      ),
                      if (dokter['is_bpjs'] == true)
                        _buildInfoChip(
                          'Melayani BPJS',
                          Icons.verified_rounded,
                          const Color(0xFF27AE60),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // Arrow
            Container(
              margin: const EdgeInsets.only(left: 8, top: 4),
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: purple.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: purple,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Detailed profile modal dialog for Doctors
class DoctorDetailDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic> dokter;
  final bool isDark;
  final bool isPreview;
  final int initialTabIndex;
  final bool autoSelectNow;

  const DoctorDetailDialog({
    required this.dokter,
    required this.isDark,
    this.isPreview = false,
    this.initialTabIndex = 0,
    this.autoSelectNow = false,
  });

  @override
  ConsumerState<DoctorDetailDialog> createState() => _DoctorDetailDialogState();
}

class _DoctorDetailDialogState extends ConsumerState<DoctorDetailDialog>
    with SingleTickerProviderStateMixin {
  final SupabaseService _db = SupabaseService();
  List<Map<String, dynamic>> _schedules = [];
  bool _loadingSchedules = true;
  String? _scheduleError;

  double _zoomLevel = 15.0;

  String _getMapEmbedUrl(String inputLink) {
    if (inputLink.isEmpty) {
      final faskes = widget.dokter['nama_faskes']?.toString() ?? '';
      final address = widget.dokter['address']?.toString() ?? '';
      final village = widget.dokter['village']?.toString() ?? '';
      final subDistrict = widget.dokter['sub_district']?.toString() ?? '';
      final district = widget.dokter['district']?.toString() ?? '';
      final province = widget.dokter['province']?.toString() ?? '';

      final queryParts = [
        if (faskes.isNotEmpty) faskes,
        if (address.isNotEmpty && address != faskes) address,
        if (village.isNotEmpty) village,
        if (subDistrict.isNotEmpty) subDistrict,
        if (district.isNotEmpty) district,
        if (province.isNotEmpty) province,
      ];
      final query = queryParts.join(', ');
      return 'https://maps.google.com/maps?q=${Uri.encodeComponent(query.isNotEmpty ? query : "Panggungan, Bondowoso")}&t=&z=${_zoomLevel.toInt()}&ie=UTF8&iwloc=&output=embed';
    }

    // Check if coordinates exist in the URL
    final atRegex = RegExp(r'@(-?\d+\.\d+),(-?\d+\.\d+)');
    var match = atRegex.firstMatch(inputLink);
    if (match != null) {
      final lat = match.group(1);
      final lng = match.group(2);
      return 'https://maps.google.com/maps?q=$lat,$lng&t=&z=${_zoomLevel.toInt()}&ie=UTF8&iwloc=&output=embed';
    }

    final qRegex = RegExp(r'[?&]q=(-?\d+\.\d+),(-?\d+\.\d+)');
    match = qRegex.firstMatch(inputLink);
    if (match != null) {
      final lat = match.group(1);
      final lng = match.group(2);
      return 'https://maps.google.com/maps?q=$lat,$lng&t=&z=${_zoomLevel.toInt()}&ie=UTF8&iwloc=&output=embed';
    }

    // Extract place name from /place/Name+Of+Place/
    final placeRegex = RegExp(r'/maps/place/([^/]+)');
    match = placeRegex.firstMatch(inputLink);
    if (match != null) {
      final placeName = Uri.decodeComponent(
        match.group(1)!.replaceAll('+', ' '),
      );
      return 'https://maps.google.com/maps?q=${Uri.encodeComponent(placeName)}&t=&z=${_zoomLevel.toInt()}&ie=UTF8&iwloc=&output=embed';
    }

    if (inputLink.startsWith('http://') || inputLink.startsWith('https://')) {
      if (inputLink.contains('output=embed') || inputLink.contains('/embed/')) {
        return inputLink;
      }
      return 'https://maps.google.com/maps?q=${Uri.encodeComponent(inputLink)}&t=&z=${_zoomLevel.toInt()}&ie=UTF8&iwloc=&output=embed';
    }

    return 'https://maps.google.com/maps?q=${Uri.encodeComponent(inputLink)}&t=&z=${_zoomLevel.toInt()}&ie=UTF8&iwloc=&output=embed';
  }

  Widget _buildZoomButton(IconData icon, VoidCallback onTap) {
    final isDark = ref.read(landingPageProvider).appearance == 'dark';
    return Material(
      color: isDark ? const Color(0xFF334155) : Colors.white,
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          child: Icon(icon, size: 16, color: isDark ? Colors.white : Colors.black87),
        ),
      ),
    );
  }

  Widget _buildMapContent(bool isDark) {
    final mapsLink = widget.dokter['google_maps_link']?.toString() ?? '';
    if (kIsWeb) {
      final embedUrl = _getMapEmbedUrl(mapsLink);
      return buildWebMapWidget(mapUrl: embedUrl, isDark: isDark);
    }

    // Non-web fallback
    final village = widget.dokter['village']?.toString() ?? '';
    return Stack(
      children: [
        // Map background canvas
        Container(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        ),
        // Custom Painter or Mock Vector Map Graphics
        Positioned.fill(
          child: CustomPaint(
            painter: MapGraphicsPainter(isDark: isDark, zoomLevel: _zoomLevel),
          ),
        ),
        // Center Pin Marker
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  village.isNotEmpty ? village : 'Panggungan',
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              const Icon(
                Icons.location_on_rounded,
                color: Color(0xFF8DC63F),
                size: 32,
              ),
            ],
          ),
        ),
        // Zoom controls (+ / -)
        Positioned(
          right: 12,
          top: 40,
          child: Column(
            children: [
              _buildZoomButton(Icons.add, () {
                setState(() {
                  if (_zoomLevel < 18) _zoomLevel += 1;
                });
              }),
              const SizedBox(height: 4),
              _buildZoomButton(Icons.remove, () {
                setState(() {
                  if (_zoomLevel > 12) _zoomLevel -= 1;
                });
              }),
            ],
          ),
        ),
        // Bottom OSM attribution footer
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            color: Colors.white.withOpacity(0.9),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Report a problem | © OpenStreetMap contributors',
                  style: GoogleFonts.outfit(
                    fontSize: 8.5,
                    color: Colors.black54,
                  ),
                ),
                Text(
                  'Map displayed via OpenStreetMap',
                  style: GoogleFonts.outfit(
                    fontSize: 8.5,
                    color: Colors.black54,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _getAboutText() {
    final about = widget.dokter['about']?.toString().trim() ?? '';
    if (about.isNotEmpty) {
      return about;
    }
    return 'Selamat datang di praktik mandiri ${widget.dokter['name']}. Kami berkomitmen untuk memberikan pelayanan kesehatan terbaik, ramah, dan profesional untuk Anda dan keluarga.';
  }

  // Background Customization State
  String _bgType = 'gradient';
  late TextEditingController _customBgUrlController;
  bool _isSavingBg = false;
  bool _isUploadingBgImage = false;

  // Font & Tagline Promotion Customization State
  String _nameFontFamily = 'Outfit';
  late TextEditingController _promoTaglineController;
  String _taglineFontFamily = 'Outfit';
  String _taglineColor = 'white';

  // Advanced Background Style Customization State
  String _gradientTheme = 'theme';
  double _blurAmount = 15.0;
  double _overlayOpacity = 0.35;
  String _blurStyle = 'full';

  // Plan/Subscription States
  bool _isSubscribed = false;
  bool _isPremium = false;
  String? _subscriptionExpiredAt;

  // Booking state
  DateTime? _selectedDate;
  String? _selectedTimeSlot;
  bool _isBooking = false;
  bool _bookingSuccess = false;
  String _bookedForPatientName = '';
  String _bookedForRelationship = '';
  late TabController _tabController;

  // Clock picker state
  int _clockHour = -1;    // -1 = not yet selected
  int _clockMinute = -1;  // -1 = not yet selected
  bool _pickingHour = true;        // true = picking hour, false = picking minute
  List<String> _clockOpenSlots = []; // valid "HH:mm" slots from schedule
  late TextEditingController _hourController;
  late TextEditingController _minuteController;
  late FocusNode _hourFocus;
  late FocusNode _minuteFocus;


  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 2),
    );
    _hourController = TextEditingController();
    _minuteController = TextEditingController();
    _hourFocus = FocusNode();
    _minuteFocus = FocusNode();

    // Initialize background settings
    final bgSettings = widget.dokter['header_bg_settings'];
    final Map<String, dynamic> settings = bgSettings is Map
        ? Map<String, dynamic>.from(bgSettings)
        : <String, dynamic>{};
    _bgType = settings['bg_type']?.toString() ?? 'gradient';
    _customBgUrlController = TextEditingController(
      text: settings['image_url']?.toString() ?? '',
    );
    _nameFontFamily = settings['name_font_family']?.toString() ?? 'Outfit';
    _promoTaglineController = TextEditingController(
      text: settings['promo_tagline']?.toString() ?? '',
    );
    _taglineFontFamily = settings['tagline_font_family']?.toString() ?? 'Outfit';
    _taglineColor = settings['tagline_color']?.toString() ?? 'white';
    _gradientTheme = settings['gradient_theme']?.toString() ?? 'theme';
    _blurAmount = double.tryParse(settings['blur_amount']?.toString() ?? '') ?? 15.0;
    _overlayOpacity = double.tryParse(settings['overlay_opacity']?.toString() ?? '') ?? 0.35;
    _blurStyle = settings['blur_style']?.toString() ?? 'full';

    // Initialize plan/subscription states
    _isSubscribed = widget.dokter['subscription_status']?.toString().toUpperCase() == 'ACTIVE';
    _subscriptionExpiredAt = widget.dokter['subscription_expired_at']?.toString();
    final isPremiumField = settings['is_premium'] == true;
    final expAt = settings['premium_expired_at'];
    if (isPremiumField) {
      if (expAt == 'lifetime') {
        _isPremium = true;
      } else if (expAt != null) {
        try {
          final expDate = DateTime.parse(expAt.toString());
          _isPremium = expDate.isAfter(DateTime.now());
        } catch (_) {
          _isPremium = false;
        }
      } else {
        _isPremium = true;
      }
    } else {
      _isPremium = false;
    }

    _loadSchedules();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _hourController.dispose();
    _minuteController.dispose();
    _hourFocus.dispose();
    _minuteFocus.dispose();
    _customBgUrlController.dispose();
    _promoTaglineController.dispose();
    super.dispose();
  }

  Future<void> _loadSchedules() async {
    try {
      final scheds = await _db.fetchDoctorSchedules(widget.dokter['id']);
      final daysOrder = {
        'monday': 1, 'senin': 1,
        'tuesday': 2, 'selasa': 2,
        'wednesday': 3, 'rabu': 3,
        'thursday': 4, 'kamis': 4,
        'friday': 5, 'jumat': 5,
        'saturday': 6, 'sabtu': 6,
        'sunday': 7, 'minggu': 7,
      };
      scheds.sort((a, b) {
        final dayA = a['day']?.toString().toLowerCase() ?? '';
        final dayB = b['day']?.toString().toLowerCase() ?? '';
        final orderA = daysOrder[dayA] ?? 99;
        final orderB = daysOrder[dayB] ?? 99;
        return orderA.compareTo(orderB);
      });

      if (mounted) {
        setState(() {
          _schedules = scheds;
          _loadingSchedules = false;
        });
        if (widget.autoSelectNow) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _setBookingToNow();
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _scheduleError = e.toString();
          _loadingSchedules = false;
        });
      }
    }
  }

  Widget _buildInitialsAvatar(Color accent) {
    final nameParts = (widget.dokter['name'] as String).trim().split(' ');
    String initials = '';
    if (nameParts.isNotEmpty) {
      if (nameParts.length >= 2) {
        initials = (nameParts[0].isNotEmpty ? nameParts[0][0] : '') +
            (nameParts[1].isNotEmpty ? nameParts[1][0] : '');
      } else {
        initials = nameParts[0].isNotEmpty ? nameParts[0][0] : '';
      }
    }
    initials = initials.toUpperCase();
    if (initials.isEmpty) initials = 'DR';
    return Text(
      initials,
      style: GoogleFonts.outfit(
        fontSize: 24,
        fontWeight: FontWeight.w900,
        color: Colors.white,
      ),
    );
  }

  bool _hasMapsLink() {
    final lat = widget.dokter['latitude'];
    final lng = widget.dokter['longitude'];
    final mapsLink = widget.dokter['google_maps_link']?.toString() ?? '';
    return mapsLink.isNotEmpty || (lat != null && lng != null);
  }

  void _launchWhatsApp() async {
    final phone = widget.dokter['whatsapp_number']?.toString() ?? '';
    if (phone.isNotEmpty) {
      var clean = phone.replaceAll(RegExp(r'\D'), '');
      if (clean.startsWith('0')) {
        clean = '62${clean.substring(1)}';
      } else if (clean.startsWith('8')) {
        clean = '62$clean';
      }
      final uri = Uri.parse("https://wa.me/$clean");
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  void _launchMaps() async {
    final lat = widget.dokter['latitude'];
    final lng = widget.dokter['longitude'];
    final mapsLink = widget.dokter['google_maps_link']?.toString() ?? '';
    Uri? mapUri;
    if (mapsLink.isNotEmpty) {
      mapUri = Uri.parse(mapsLink);
    } else if (lat != null && lng != null) {
      mapUri = Uri.parse("https://www.google.com/maps/search/?api=1&query=$lat,$lng");
    }
    if (mapUri != null) {
      if (await canLaunchUrl(mapUri)) {
        await launchUrl(mapUri, mode: LaunchMode.externalApplication);
      }
    }
  }

  String _formatFullAddress() {
    final List<String> parts = [];
    if (widget.dokter['address'] != null && widget.dokter['address'].toString().isNotEmpty) {
      parts.add(widget.dokter['address'].toString());
    }
    if (widget.dokter['village'] != null && widget.dokter['village'].toString().isNotEmpty) {
      parts.add(widget.dokter['village'].toString());
    }
    if (widget.dokter['sub_district'] != null && widget.dokter['sub_district'].toString().isNotEmpty) {
      parts.add('Kec. ${widget.dokter['sub_district']}');
    }
    if (widget.dokter['district'] != null && widget.dokter['district'].toString().isNotEmpty) {
      parts.add(widget.dokter['district'].toString());
    }
    if (widget.dokter['province'] != null && widget.dokter['province'].toString().isNotEmpty) {
      parts.add(widget.dokter['province'].toString());
    }
    return parts.join(', ');
  }

  Widget _buildSectionHeader(String label, IconData icon, Color themeAccent, Color textColor) {
    return Row(
      children: [
        Icon(icon, size: 16, color: themeAccent),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: textColor,
          ),
        ),
      ],
    );
  }

  Widget _buildSchedulesWidget(Color textColor, Color subtitleColor, Color themeAccent) {
    if (_loadingSchedules) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: themeAccent),
              ),
              const SizedBox(height: 8),
              Text(
                'Memuat jadwal...',
                style: GoogleFonts.outfit(fontSize: 11, color: subtitleColor),
              ),
            ],
          ),
        ),
      );
    }

    if (_scheduleError != null) {
      return Center(
        child: Text(
          'Gagal memuat jadwal: ${_scheduleError}',
          style: GoogleFonts.outfit(fontSize: 11, color: Colors.red[400]),
        ),
      );
    }

    if (_schedules.isEmpty) {
      return Center(
        child: Text(
          'Jadwal praktek belum diatur.',
          style: GoogleFonts.outfit(fontSize: 11, color: subtitleColor, fontWeight: FontWeight.w600),
        ),
      );
    }

    return Column(
      children: _schedules.map((sched) {
        final day = sched['day']?.toString() ?? '';
        final openTime = sched['open_time']?.toString() ?? '';
        final closeTime = sched['close_time']?.toString() ?? '';
        final isOff = sched['is_off'] == true;

        String formattedHours = 'Tutup';
        if (!isOff && openTime.isNotEmpty && closeTime.isNotEmpty) {
          final openPart = openTime.length > 5 ? openTime.substring(0, 5) : openTime;
          final closePart = closeTime.length > 5 ? closeTime.substring(0, 5) : closeTime;
          formattedHours = '$openPart - $closePart';
        }

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _translateDay(day),
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isOff ? Colors.red.withOpacity(0.08) : themeAccent.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  formattedHours,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isOff ? Colors.red[400] : themeAccent,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ── CLOCK PICKER ─────────────────────────────────────────────────
  bool _isTimeValid(int hour, int minute) {
    if (_selectedDate == null) return false;
    final sched = _scheduleForDate(_selectedDate!);
    if (sched == null) return false;
    final open = (sched['open_time']?.toString() ?? '').substring(0, 5).split(':');
    final close = (sched['close_time']?.toString() ?? '').substring(0, 5).split(':');
    if (open.length < 2 || close.length < 2) return false;

    int openMin = int.parse(open[0]) * 60 + int.parse(open[1]);
    int closeMin = int.parse(close[0]) * 60 + int.parse(close[1]);
    if (closeMin <= openMin) closeMin += 24 * 60; // overnight

    int selectedMin = hour * 60 + minute;
    if (selectedMin < openMin && (selectedMin + 24 * 60) < closeMin) {
      selectedMin += 24 * 60;
    }

    return selectedMin >= openMin && selectedMin <= closeMin;
  }

  void _updateSelectedTime() {
    if (_clockHour >= 0 && _clockMinute >= 0) {
      if (_isTimeValid(_clockHour, _clockMinute)) {
        final slot = '${_clockHour.toString().padLeft(2, '0')}:${_clockMinute.toString().padLeft(2, '0')}';
        setState(() {
          _selectedTimeSlot = slot;
        });
      } else {
        setState(() {
          _selectedTimeSlot = null;
        });
      }
    } else {
      setState(() {
        _selectedTimeSlot = null;
      });
    }
  }

  void _onClockHourTap(int h) {
    final hasSlot = _clockOpenSlots.any((s) {
      final parts = s.split(':');
      return int.tryParse(parts[0]) == h;
    });
    if (!hasSlot) return;
    setState(() {
      _clockHour = h;
      _clockMinute = -1;
      _pickingHour = false;
      _selectedTimeSlot = null;
      _hourController.text = h.toString().padLeft(2, '0');
      _minuteController.text = '';
    });
    _minuteFocus.requestFocus();
  }

  void _onClockMinuteTap(int m) {
    setState(() {
      _clockMinute = m;
      _minuteController.text = m.toString().padLeft(2, '0');
      _updateSelectedTime();
    });
  }

  static double _mySin(double rad) {
    double r = rad;
    while (r > 3.14159265) r -= 2 * 3.14159265;
    while (r < -3.14159265) r += 2 * 3.14159265;
    final x = r;
    return x - (x*x*x)/6 + (x*x*x*x*x)/120 - (x*x*x*x*x*x*x)/5040;
  }

  static double _myCos(double rad) => _mySin(rad + 3.14159265 / 2);

  Widget _buildClockPicker({
    required Color themeAccent,
    required Color textColor,
    required Color subtitleColor,
    required Color sectionBg,
    required Color borderColor,
  }) {
    final isHourMode = _pickingHour;
    final availableHours = _clockOpenSlots
        .map((s) => int.tryParse(s.split(':')[0]) ?? -1)
        .toSet()
        .toList()
      ..sort();
    final availableMinutes = [0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55];

    const double clockSize = 220;
    const double outerR = 86.0;
    const double innerR = 54.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Focus(
              onFocusChange: (hasFocus) {
                if (hasFocus) {
                  setState(() => _pickingHour = true);
                } else {
                  if (_clockHour >= 0) {
                    _hourController.text = _clockHour.toString().padLeft(2, '0');
                  }
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 76,
                height: 58,
                decoration: BoxDecoration(
                  color: isHourMode ? themeAccent : sectionBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isHourMode ? themeAccent : borderColor, width: 2),
                ),
                alignment: Alignment.center,
                child: TextField(
                  controller: _hourController,
                  focusNode: _hourFocus,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    color: isHourMode ? Colors.white : textColor,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                    counterText: "",
                    hintText: '--',
                    hintStyle: GoogleFonts.outfit(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      color: isHourMode ? Colors.white.withOpacity(0.5) : subtitleColor,
                    ),
                  ),
                  maxLength: 2,
                  onChanged: (val) {
                    final h = int.tryParse(val);
                    if (h != null && h >= 0 && h <= 23) {
                      setState(() {
                        _clockHour = h;
                        _updateSelectedTime();
                      });
                      if (val.length == 2) {
                        _minuteFocus.requestFocus();
                      }
                    } else if (val.isEmpty) {
                      setState(() {
                        _clockHour = -1;
                        _selectedTimeSlot = null;
                      });
                    }
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                ':',
                style: GoogleFonts.outfit(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: textColor,
                ),
              ),
            ),
            Focus(
              onFocusChange: (hasFocus) {
                if (hasFocus) {
                  setState(() => _pickingHour = false);
                } else {
                  if (_clockMinute >= 0) {
                    _minuteController.text = _clockMinute.toString().padLeft(2, '0');
                  }
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 76,
                height: 58,
                decoration: BoxDecoration(
                  color: !isHourMode ? themeAccent : sectionBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: !isHourMode ? themeAccent : borderColor, width: 2),
                ),
                alignment: Alignment.center,
                child: TextField(
                  controller: _minuteController,
                  focusNode: _minuteFocus,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    color: !isHourMode ? Colors.white : textColor,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                    counterText: "",
                    hintText: '--',
                    hintStyle: GoogleFonts.outfit(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      color: !isHourMode ? Colors.white.withOpacity(0.5) : subtitleColor,
                    ),
                  ),
                  maxLength: 2,
                  enabled: _clockHour != -1,
                  onChanged: (val) {
                    final m = int.tryParse(val);
                    if (m != null && m >= 0 && m <= 59) {
                      setState(() {
                        _clockMinute = m;
                        _updateSelectedTime();
                      });
                    } else if (val.isEmpty) {
                      setState(() {
                        _clockMinute = -1;
                        _selectedTimeSlot = null;
                      });
                    }
                  },
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (_clockHour >= 0 && _clockMinute >= 0 && !_isTimeValid(_clockHour, _clockMinute))
          Text(
            'Waktu booking di luar jam kerja dokter.',
            style: GoogleFonts.outfit(fontSize: 10, color: Colors.redAccent, fontWeight: FontWeight.bold),
          )
        else
          Text(
            isHourMode ? 'Ketuk/ketik untuk memilih jam' : 'Ketuk/ketik untuk memilih menit',
            style: GoogleFonts.outfit(fontSize: 10, color: subtitleColor, fontWeight: FontWeight.w600),
          ),
        const SizedBox(height: 16),
        SizedBox(
          width: clockSize,
          height: clockSize,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: clockSize,
                height: clockSize,
                decoration: BoxDecoration(
                  color: sectionBg,
                  shape: BoxShape.circle,
                  border: Border.all(color: borderColor, width: 1.5),
                ),
              ),
              if (isHourMode)
                Container(
                  width: clockSize * 0.55,
                  height: clockSize * 0.55,
                  decoration: BoxDecoration(
                    color: borderColor.withOpacity(0.35),
                    shape: BoxShape.circle,
                  ),
                ),
              if (isHourMode)
                ...availableHours.map((h) {
                  final h12 = h % 12 == 0 ? 12 : h % 12;
                  final rad = (h12 / 12.0) * 2 * 3.14159265 - (3.14159265 / 2);
                  final r = h < 12 ? innerR : outerR;
                  final dx = r * _myCos(rad);
                  final dy = r * _mySin(rad);
                  final isSel = _clockHour == h;
                  return Positioned(
                    left: clockSize / 2 + dx - 22,
                    top: clockSize / 2 + dy - 22,
                    child: GestureDetector(
                      onTap: () => _onClockHourTap(h),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          color: isSel ? themeAccent : Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text('$h',
                            style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w900,
                                color: isSel ? Colors.white : textColor)),
                      ),
                    ),
                  );
                })
              else
                ...availableMinutes.map((m) {
                  final rad = (m / 60.0) * 2 * 3.14159265 - (3.14159265 / 2);
                  final dx = outerR * _myCos(rad);
                  final dy = outerR * _mySin(rad);
                  final isSel = _clockMinute == m;
                  return Positioned(
                    left: clockSize / 2 + dx - 22,
                    top: clockSize / 2 + dy - 22,
                    child: GestureDetector(
                      onTap: () => _onClockMinuteTap(m),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          color: isSel ? themeAccent : Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(m.toString().padLeft(2, '0'),
                            style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w900,
                                color: isSel ? Colors.white : textColor)),
                      ),
                    ),
                  );
                }),
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(color: themeAccent, shape: BoxShape.circle),
              ),
            ],
          ),
        ),
        if (isHourMode && availableHours.any((h) => h >= 12)) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(width: 10, height: 10,
                  decoration: BoxDecoration(color: borderColor.withOpacity(0.5), shape: BoxShape.circle,
                      border: Border.all(color: borderColor))),
              const SizedBox(width: 6),
              Text('AM (dalam)', style: GoogleFonts.outfit(fontSize: 9, color: subtitleColor)),
              const SizedBox(width: 14),
              Container(width: 10, height: 10,
                  decoration: BoxDecoration(color: sectionBg, shape: BoxShape.circle,
                      border: Border.all(color: borderColor))),
              const SizedBox(width: 6),
              Text('PM (luar)', style: GoogleFonts.outfit(fontSize: 9, color: subtitleColor)),
            ],
          ),
        ],
      ],
    );
  }

  // Ã¢â€â‚¬Ã¢â€â‚¬ BOOKING TAB Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
  // Returns a list of open day indices (1=Mon..7=Sun) for this doctor
  List<int> _getOpenWeekdays() {
    final daysOrder = {
      'monday': 1, 'senin': 1,
      'tuesday': 2, 'selasa': 2,
      'wednesday': 3, 'rabu': 3,
      'thursday': 4, 'kamis': 4,
      'friday': 5, 'jumat': 5,
      'saturday': 6, 'sabtu': 6,
      'sunday': 7, 'minggu': 7,
    };
    return _schedules
        .where((s) => s['is_off'] != true)
        .map((s) => daysOrder[s['day']?.toString().toLowerCase() ?? ''] ?? 0)
        .where((d) => d > 0)
        .toList();
  }

  // Returns the schedule record for a given DateTime
  Map<String, dynamic>? _scheduleForDate(DateTime date) {
    // weekday: 1=Mon..7=Sun
    final weekday = date.weekday;
    final dayNames = {
      1: ['monday', 'senin'],
      2: ['tuesday', 'selasa'],
      3: ['wednesday', 'rabu'],
      4: ['thursday', 'kamis'],
      5: ['friday', 'jumat'],
      6: ['saturday', 'sabtu'],
      7: ['sunday', 'minggu'],
    };
    final names = dayNames[weekday] ?? [];
    for (final sched in _schedules) {
      final d = sched['day']?.toString().toLowerCase() ?? '';
      if (names.contains(d) && sched['is_off'] != true) {
        return sched;
      }
    }
    return null;
  }

  List<String> _buildTimeSlots(String openTime, String closeTime) {
    try {
      final open = openTime.substring(0, 5).split(':');
      final close = closeTime.substring(0, 5).split(':');
      int openMin = int.parse(open[0]) * 60 + int.parse(open[1]);
      int closeMin = int.parse(close[0]) * 60 + int.parse(close[1]);
      if (closeMin <= openMin) closeMin += 24 * 60; // overnight
      final slots = <String>[];
      for (int m = openMin; m < closeMin; m += 30) {
        final h = (m ~/ 60) % 24;
        final min = m % 60;
        slots.add('${h.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')}');
      }
      return slots;
    } catch (_) {
      return [];
    }
  }

  void _setBookingToNow() {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final openWeekdays = _getOpenWeekdays();

    if (openWeekdays.isEmpty) return;

    DateTime targetDate = todayDate;
    if (!openWeekdays.contains(today.weekday)) {
      // Find first upcoming open date
      for (int i = 0; i <= 27; i++) {
        final d = todayDate.add(Duration(days: i));
        if (openWeekdays.contains(d.weekday)) {
          targetDate = d;
          break;
        }
      }
    }

    final sched = _scheduleForDate(targetDate);
    if (sched == null) return;

    final openStr = (sched['open_time']?.toString() ?? '08:00').substring(0, 5);
    final closeStr = (sched['close_time']?.toString() ?? '20:00').substring(0, 5);
    final openParts = openStr.split(':');
    final closeParts = closeStr.split(':');
    final openH = int.tryParse(openParts[0]) ?? 8;
    final openM = int.tryParse(openParts[1]) ?? 0;
    final closeH = int.tryParse(closeParts[0]) ?? 20;
    final closeM = int.tryParse(closeParts[1]) ?? 0;

    final openTotalMin = openH * 60 + openM;
    final closeTotalMin = closeH * 60 + closeM;
    final nowTotalMin = today.hour * 60 + today.minute;

    int chosenH = today.hour;
    int chosenM = today.minute;

    if (targetDate.year == todayDate.year &&
        targetDate.month == todayDate.month &&
        targetDate.day == todayDate.day) {
      if (nowTotalMin < openTotalMin) {
        // Before open time -> default to open time
        chosenH = openH;
        chosenM = openM;
      } else if (nowTotalMin > closeTotalMin) {
        // After close time -> default to close time
        chosenH = closeH;
        chosenM = closeM;
      } else {
        // Current open hours -> exact current hour and minute
        chosenH = today.hour;
        chosenM = today.minute;
      }
    } else {
      chosenH = openH;
      chosenM = openM;
    }

    final timeSlots = _buildTimeSlots(openStr, closeStr);

    setState(() {
      _selectedDate = targetDate;
      _clockOpenSlots = timeSlots;
      _clockHour = chosenH;
      _clockMinute = chosenM;
      _pickingHour = false;
      _hourController.text = chosenH.toString().padLeft(2, '0');
      _minuteController.text = chosenM.toString().padLeft(2, '0');
      _selectedTimeSlot =
          '${chosenH.toString().padLeft(2, '0')}:${chosenM.toString().padLeft(2, '0')}';
    });
  }

  Widget _buildBookingTab(
    Color textColor,
    Color subtitleColor,
    Color themeAccent,
    Color sectionBg,
    Color borderColor,
  ) {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final openWeekdays = _getOpenWeekdays();

    final user = ref.read(landingPageProvider).loggedInUser;
    final isSelfPreview = widget.isPreview || (user != null && user['id'] == widget.dokter['id']);
    final isDark = ref.read(landingPageProvider).appearance == 'dark';

    if (_bookingSuccess) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: themeAccent.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check_circle_rounded, size: 40, color: themeAccent),
              ),
              const SizedBox(height: 16),
              Text(
                'Booking Berhasil!',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _bookedForPatientName.isNotEmpty
                    ? 'Janji temu untuk $_bookedForPatientName${_bookedForRelationship.isNotEmpty ? " ($_bookedForRelationship)" : ""} telah dibuat.\nSilakan datang sesuai jadwal yang dipilih.'
                    : 'Janji temu Anda telah dibuat.\nSilakan datang sesuai jadwal yang dipilih.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: subtitleColor,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _bookingSuccess = false;
                    _selectedDate = null;
                    _selectedTimeSlot = null;
                    _bookedForPatientName = '';
                    _bookedForRelationship = '';
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: Text(
                  'Buat Booking Lain',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_loadingSchedules) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: CircularProgressIndicator(color: themeAccent),
        ),
      );
    }

    if (openWeekdays.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Dokter ini belum memiliki jadwal praktek.',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(fontSize: 12, color: subtitleColor),
          ),
        ),
      );
    }

    // Build 14 upcoming days, only those matching open weekdays
    final List<DateTime> availableDates = [];
    for (int i = 0; i <= 27; i++) {
      final d = todayDate.add(Duration(days: i));
      if (openWeekdays.contains(d.weekday)) {
        availableDates.add(d);
        if (availableDates.length >= 14) break;
      }
    }

    // Time slots for selected date
    List<String> timeSlots = [];
    if (_selectedDate != null) {
      final sched = _scheduleForDate(_selectedDate!);
      if (sched != null) {
        final open = sched['open_time']?.toString() ?? '';
        final close = sched['close_time']?.toString() ?? '';
        if (open.isNotEmpty && close.isNotEmpty) {
          timeSlots = _buildTimeSlots(open, close);
          // Keep _clockOpenSlots in sync when date changes
          if (_clockOpenSlots.join() != timeSlots.join()) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() {
                _clockOpenSlots = timeSlots;
                _clockHour = -1;
                _clockMinute = -1;
                _pickingHour = true;
                _selectedTimeSlot = null;
                _hourController.text = '';
                _minuteController.text = '';
              });
            });
          }
        }
      }
    }

    final dayLabels = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    final monthNames = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Ags', 'Sep', 'Okt', 'Nov', 'Des'
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isSelfPreview) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF2C94C).withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFF2C94C).withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: Color(0xFFF2C94C), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Pratinjau Perspektif Pasien: Anda tidak dapat membuat janji temu dengan diri sendiri.',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFFF2C94C) : const Color(0xFFD3A106),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        // ── Quick Set "Sekarang / Hari Ini" Action Banner ──
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _setBookingToNow,
              borderRadius: BorderRadius.circular(14),
              child: Ink(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      themeAccent.withOpacity(isDark ? 0.22 : 0.12),
                      themeAccent.withOpacity(isDark ? 0.10 : 0.04),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: themeAccent.withOpacity(isDark ? 0.45 : 0.35),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: themeAccent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.bolt_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PILIH HARI INI & JAM SEKARANG',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                              color: themeAccent,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Otomatis atur tanggal ke hari ini & waktu ke saat ini',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: subtitleColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: themeAccent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.flash_on, size: 13, color: Colors.white),
                          const SizedBox(width: 3),
                          Text(
                            'Set Sekarang',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Date picker
        _buildSectionHeader('Pilih Tanggal', Icons.calendar_today_rounded, themeAccent, textColor),
        const SizedBox(height: 10),
        SizedBox(
          height: 76,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemCount: availableDates.length,
            itemBuilder: (ctx, i) {
              final d = availableDates[i];
              final isSelected = _selectedDate != null &&
                  _selectedDate!.year == d.year &&
                  _selectedDate!.month == d.month &&
                  _selectedDate!.day == d.day;
              final isToday = d.year == todayDate.year &&
                  d.month == todayDate.month &&
                  d.day == todayDate.day;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedDate = d;
                    _selectedTimeSlot = null;
                    // Reset clock when date changes
                    _clockHour = -1;
                    _clockMinute = -1;
                    _pickingHour = true;
                    _clockOpenSlots = [];
                    _hourController.text = '';
                    _minuteController.text = '';
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 52,
                  decoration: BoxDecoration(
                    color: isSelected ? themeAccent : sectionBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? themeAccent : borderColor,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        dayLabels[d.weekday - 1],
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? Colors.white.withOpacity(0.8) : subtitleColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${d.day}',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: isSelected ? Colors.white : textColor,
                        ),
                      ),
                      Text(
                        monthNames[d.month - 1],
                        style: GoogleFonts.outfit(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? Colors.white.withOpacity(0.7) : subtitleColor,
                        ),
                      ),
                      if (isToday)
                        Container(
                          margin: const EdgeInsets.only(top: 2),
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.white : themeAccent,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        if (_selectedDate != null) ...[
          const SizedBox(height: 20),
          _buildSectionHeader('Pilih Jam', Icons.schedule_rounded, themeAccent, textColor),
          const SizedBox(height: 8),
          (() {
            final sched = _scheduleForDate(_selectedDate!);
            if (sched != null && sched['open_time'] != null && sched['close_time'] != null) {
              final openPart = sched['open_time'].toString().substring(0, 5);
              final closePart = sched['close_time'].toString().substring(0, 5);
              return Padding(
                padding: const EdgeInsets.only(left: 24, bottom: 8),
                child: Text(
                  'Jam Kerja Dokter: $openPart - $closePart',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: themeAccent,
                  ),
                ),
              );
            }
            return const SizedBox.shrink();
          })(),
          const SizedBox(height: 4),
          if (timeSlots.isEmpty)
            Center(
              child: Text(
                'Tidak ada slot waktu tersedia.',
                style: GoogleFonts.outfit(fontSize: 11, color: subtitleColor),
              ),
            )
          else
            Center(
              child: _buildClockPicker(
                themeAccent: themeAccent,
                textColor: textColor,
                subtitleColor: subtitleColor,
                sectionBg: sectionBg,
                borderColor: borderColor,
              ),
            ),
        ],

        if (_selectedDate != null && _selectedTimeSlot != null) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: themeAccent.withOpacity(0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: themeAccent.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.event_available_rounded, size: 18, color: themeAccent),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ringkasan Janji',
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: subtitleColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_selectedDate!.day} ${['Jan','Feb','Mar','Apr','Mei','Jun','Jul','Ags','Sep','Okt','Nov','Des'][_selectedDate!.month - 1]} ${_selectedDate!.year} pukul $_selectedTimeSlot',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isSelfPreview ? null : (_isBooking ? null : _onBookingConfirmPressed),
              icon: _isBooking
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : (isSelfPreview
                      ? const Icon(Icons.block_rounded, size: 16, color: Colors.white70)
                      : const Icon(Icons.check_circle_rounded, size: 16, color: Colors.white)),
              label: Text(
                isSelfPreview
                    ? 'Tidak Dapat Booking Diri Sendiri'
                    : (_isBooking ? 'Memproses...' : 'Konfirmasi Booking'),
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: isSelfPreview ? Colors.white70 : Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: themeAccent,
                disabledBackgroundColor: isDark ? Colors.grey[800] : Colors.grey[300],
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _onBookingConfirmPressed() async {
    final user = ref.read(landingPageProvider).loggedInUser;
    final isSelfPreview = widget.isPreview || (user != null && user['id'] == widget.dokter['id']);
    if (isSelfPreview) return;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Silakan login terlebih dahulu.',
            style: GoogleFonts.outfit(),
          ),
          backgroundColor: Colors.red[400],
        ),
      );
      return;
    }

    if (_selectedDate == null || _selectedTimeSlot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Silakan pilih tanggal dan jam terlebih dahulu.',
            style: GoogleFonts.outfit(),
          ),
          backgroundColor: Colors.orange[400],
        ),
      );
      return;
    }

    // Open Patient Selection Modal (Self or Family Member from KK)
    await showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (modalCtx) => _PatientBookingSelectionDialog(
        user: user,
        dokter: widget.dokter,
        selectedDate: _selectedDate!,
        selectedTimeSlot: _selectedTimeSlot!,
        isDark: widget.isDark,
        onConfirmed: (patientId, patientName, relationship) async {
          Navigator.pop(modalCtx);
          await _executeBooking(
            patientId: patientId,
            patientName: patientName,
            relationship: relationship,
          );
        },
      ),
    );
  }

  Future<void> _executeBooking({
    required String patientId,
    required String patientName,
    required String relationship,
  }) async {
    setState(() => _isBooking = true);
    try {
      DateTime bookingDateTime = _selectedDate!;
      if (_selectedTimeSlot != null) {
        final parts = _selectedTimeSlot!.split(':');
        if (parts.length == 2) {
          final hour = int.tryParse(parts[0]) ?? 0;
          final minute = int.tryParse(parts[1]) ?? 0;
          bookingDateTime = DateTime(
            _selectedDate!.year,
            _selectedDate!.month,
            _selectedDate!.day,
            hour,
            minute,
          );
        }
      }
      await _db.createBooking(
        doctorId: widget.dokter['id'] as String,
        patientId: patientId,
        date: bookingDateTime,
      );
      if (mounted) {
        setState(() {
          _isBooking = false;
          _bookingSuccess = true;
          _bookedForPatientName = patientName;
          _bookedForRelationship = relationship;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isBooking = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Gagal membuat booking: $e',
              style: GoogleFonts.outfit(),
            ),
            backgroundColor: Colors.red[400],
          ),
        );
      }
    }
  }

  // ── DOKUMEN TAB ──────────────────────────────────────────────────
  void _showFileViewer(
    BuildContext context,
    String url,
    String name,
    bool isPdf, {
    required Color themeAccent,
    required Color textColor,
    required Color subtitleColor,
    required Color cardBg,
    required Color borderColor,
  }) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.85),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          width: 480,
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Custom Header Bar (shows ONLY the clean filename, no URL)
              Container(
                padding: const EdgeInsets.fromLTRB(18, 16, 12, 16),
                color: themeAccent,
                child: Row(
                  children: [
                    Icon(
                      isPdf ? Icons.picture_as_pdf_rounded : Icons.image_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
                      onPressed: () => Navigator.of(ctx).pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              // Main content preview
              if (!isPdf)
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.6,
                  ),
                  child: InteractiveViewer(
                    maxScale: 3.5,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Image.network(
                        url,
                        fit: BoxFit.contain,
                        loadingBuilder: (_, child, prog) {
                          if (prog == null) return child;
                          return SizedBox(
                            height: 200,
                            child: Center(
                              child: CircularProgressIndicator(
                                color: themeAccent,
                                strokeWidth: 2,
                              ),
                            ),
                          );
                        },
                        errorBuilder: (_, __, ___) => SizedBox(
                          height: 160,
                          child: Center(
                            child: Icon(
                              Icons.broken_image_rounded,
                              size: 48,
                              color: subtitleColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                )
              else
                // PDF: clean descriptive preview box with open/download actions
                Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(
                          Icons.picture_as_pdf_rounded,
                          color: Colors.red,
                          size: 38,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        name,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Dokumen PDF Resmi',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          color: subtitleColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final uri = Uri.parse(url);
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                            }
                          },
                          icon: const Icon(Icons.open_in_new_rounded, size: 16, color: Colors.white),
                          label: Text(
                            'Buka Dokumen PDF',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red[600],
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDocumentsTab(
    Color textColor,
    Color subtitleColor,
    Color themeAccent,
    Color sectionBg,
    Color borderColor,
  ) {
    final rawLicenses = widget.dokter['practice_licenses'];
    List<String> licenses = [];
    if (rawLicenses is List) {
      licenses = rawLicenses.map((e) => e.toString()).toList();
    }

    if (licenses.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.folder_open_rounded, size: 40, color: subtitleColor.withOpacity(0.4)),
              const SizedBox(height: 12),
              Text(
                'Belum ada dokumen yang diunggah.',
                style: GoogleFonts.outfit(fontSize: 12, color: subtitleColor),
              ),
            ],
          ),
        ),
      );
    }

    // Determine current card bg for dialog preview
    final isDark = ref.read(landingPageProvider).appearance == 'dark';
    final cardBg = isDark ? const Color(0xFF161619) : Colors.white;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          'Dokumen & Lisensi Praktek',
          Icons.verified_user_rounded,
          themeAccent,
          textColor,
        ),
        const SizedBox(height: 12),
        ...licenses.asMap().entries.map((entry) {
          final url = entry.value;
          final idx = entry.key + 1;
          final isPdf = url.toLowerCase().contains('.pdf');
          final rawFilename = url.split('/').last.split('?').first;
          final decodedName = Uri.decodeFull(rawFilename);

          // Strip the prefix timestamp (e.g. "1782268418920_") if present
          final cleanName = decodedName.replaceFirst(RegExp(r'^\d+_'), '');

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GestureDetector(
              onTap: () => _showFileViewer(
                context,
                url,
                cleanName,
                isPdf,
                themeAccent: themeAccent,
                textColor: textColor,
                subtitleColor: subtitleColor,
                cardBg: cardBg,
                borderColor: borderColor,
              ),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: sectionBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isPdf
                            ? Colors.red.withOpacity(0.08)
                            : themeAccent.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isPdf ? Icons.picture_as_pdf_rounded : Icons.image_rounded,
                        color: isPdf ? Colors.red : themeAccent,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cleanName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isPdf ? 'PDF · Dokumen $idx' : 'Gambar · Dokumen $idx',
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              color: subtitleColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      isPdf ? Icons.open_in_new_rounded : Icons.zoom_in_rounded,
                      size: 16,
                      color: themeAccent,
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  String _translateDay(String day) {
    switch (day.toLowerCase()) {
      case 'monday': return 'Senin';
      case 'tuesday': return 'Selasa';
      case 'wednesday': return 'Rabu';
      case 'thursday': return 'Kamis';
      case 'friday': return 'Jumat';
      case 'saturday': return 'Sabtu';
      case 'sunday': return 'Minggu';
      default: return day;
    }
  }

  Widget _buildHeaderBackground(
    String appearance,
    bool isDark,
    Color themeAccent,
  ) {
    if (_bgType == 'blurred_pp' && widget.dokter['avatar_url'] != null && widget.dokter['avatar_url'].toString().isNotEmpty) {
      return _buildImageBackground(widget.dokter['avatar_url']!);
    } else if (_bgType == 'custom_image' && _customBgUrlController.text.trim().isNotEmpty) {
      return _buildImageBackground(_customBgUrlController.text.trim());
    }

    // Default gradient background
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _getGradientColors(appearance, isDark, themeAccent),
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );
  }

  List<Color> _getGradientColors(String appearance, bool isDark, Color themeAccent) {
    final selectedTheme = _isPremium ? _gradientTheme : 'theme';
    switch (selectedTheme.toLowerCase()) {
      case 'teal':
        return [Colors.teal, const Color(0xFF004D40)];
      case 'violet':
        return [const Color(0xFF8E2DE2), const Color(0xFF4A00E0)];
      case 'coral':
        return [const Color(0xFFF857A6), const Color(0xFFFF5858)];
      case 'sunset':
        return [const Color(0xFFF9D423), const Color(0xFFFF4E50)];
      case 'emerald':
        return [const Color(0xFF11998E), const Color(0xFF38EF7D)];
      case 'slate':
        return [const Color(0xFF434343), const Color(0xFF000000)];
      case 'theme':
      default:
        return appearance == 'rev'
            ? const [Color(0xFFCB8FFF), Color(0xFFB577F2)]
            : (isDark
                ? const [Color(0xFF3A3A40), Color(0xFF252528)]
                : [themeAccent, themeAccent.withOpacity(0.8)]);
    }
  }

  Widget _buildImageBackground(String imageUrl) {
    final effectiveBlurAmount = _isPremium ? _blurAmount : 15.0;
    final effectiveBlurStyle = _isPremium ? _blurStyle : 'full';
    final effectiveOverlayOpacity = _isPremium ? _overlayOpacity : 0.35;

    final imageWidget = Image.network(
      imageUrl,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        color: Colors.red[300],
      ),
    );

    Widget blurredLayer = ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: effectiveBlurAmount, sigmaY: effectiveBlurAmount),
      child: Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          color: Colors.red[300],
        ),
      ),
    );

    // Apply Mask based on effectiveBlurStyle
    if (effectiveBlurAmount > 0 && effectiveBlurStyle != 'none') {
      if (effectiveBlurStyle == 'radial') {
        blurredLayer = ShaderMask(
          shaderCallback: (rect) {
            return const RadialGradient(
              center: Alignment.center,     // Center the gradient globally
              radius: 1.5,                  // Expand radius significantly to blend over the wide header
              colors: [
                Colors.transparent, // Center is clear (shows sharp image)
                Colors.black,       // Borders are blurred
              ],
              stops: [0.0, 1.0],            // Smooth linear transition from center to border
            ).createShader(rect);
          },
          blendMode: BlendMode.dstIn,
          child: blurredLayer,
        );
      } else if (effectiveBlurStyle == 'bottom') {
        blurredLayer = ShaderMask(
          shaderCallback: (rect) {
            return const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent, // Top is clear
                Colors.black,       // Bottom is blurred
              ],
              stops: [0.0, 1.0],
            ).createShader(rect);
          },
          blendMode: BlendMode.dstIn,
          child: blurredLayer,
        );
      }
    }

    return ClipRect(
      child: Transform.scale(
        scale: 1.15, // Scale slightly up to push the blurry edge pixels outside the clip bounds
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Base sharp image
            imageWidget,
            // Blurred overlay (either full, radial, or bottom)
            if (effectiveBlurAmount > 0 && effectiveBlurStyle != 'none') blurredLayer,
            // Dimming overlay for readability
            Container(
              color: Colors.black.withOpacity(effectiveOverlayOpacity),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewSettingsPanel(
    bool isDark,
    Color textColor,
    Color subtitleColor,
    Color themeAccent,
    Color borderColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: borderColor)),
          ),
          child: Row(
            children: [
              Icon(Icons.palette_outlined, size: 20, color: themeAccent),
              const SizedBox(width: 10),
              Text(
                'Customize Design',
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
        
        // Scrollable Options
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Header Background Style',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 10),
                
                // Radio Option: Gradient
                _buildBgTypeRadio(
                  value: 'gradient',
                  title: 'Default Gradient',
                  icon: Icons.gradient_rounded,
                  textColor: textColor,
                  themeAccent: themeAccent,
                ),
                const SizedBox(height: 8),
                
                // Radio Option: Blurred Profile Photo
                _buildBgTypeRadio(
                  value: 'blurred_pp',
                  title: 'Blurred Profile Photo',
                  icon: Icons.blur_on_rounded,
                  textColor: textColor,
                  themeAccent: themeAccent,
                ),
                const SizedBox(height: 8),
                
                // Radio Option: Custom Image
                _buildBgTypeRadio(
                  value: 'custom_image',
                  title: 'Custom Image / GIF',
                  icon: Icons.image_outlined,
                  textColor: textColor,
                  themeAccent: themeAccent,
                ),
                
                if (_bgType == 'custom_image') ...[
                  const SizedBox(height: 16),
                  Text(
                    'Background Image URL / GIF',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: subtitleColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _customBgUrlController,
                    style: GoogleFonts.outfit(fontSize: 12, color: textColor),
                    decoration: InputDecoration(
                      hintText: 'https://example.com/image.gif',
                      hintStyle: GoogleFonts.outfit(fontSize: 11, color: subtitleColor),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF161619) : Colors.white,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: borderColor),
                      ),
                    ),
                    onChanged: (val) {
                      setState(() {});
                    },
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isUploadingBgImage ? null : _pickAndUploadHeaderBg,
                      icon: const Icon(Icons.upload_file_rounded, size: 14),
                      label: Text(
                        _isUploadingBgImage ? 'Uploading...' : 'Upload Image / GIF',
                        style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: themeAccent,
                        side: BorderSide(color: themeAccent),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ],
                if (_isPremium) ...[
                  if (_bgType == 'gradient') ...[
                    const SizedBox(height: 16),
                    Text(
                      'Gradient Palette',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildGradientOption('theme', const [Colors.blue, Colors.blueAccent], isDark),
                        _buildGradientOption('teal', const [Colors.teal, Color(0xFF004D40)], isDark),
                        _buildGradientOption('violet', const [Color(0xFF8E2DE2), Color(0xFF4A00E0)], isDark),
                        _buildGradientOption('coral', const [Color(0xFFF857A6), Color(0xFFFF5858)], isDark),
                        _buildGradientOption('sunset', const [Color(0xFFF9D423), Color(0xFFFF4E50)], isDark),
                        _buildGradientOption('emerald', const [Color(0xFF11998E), Color(0xFF38EF7D)], isDark),
                        _buildGradientOption('slate', const [Color(0xFF434343), Color(0xFF000000)], isDark),
                      ],
                    ),
                  ],
                  if (_bgType == 'blurred_pp' || _bgType == 'custom_image') ...[
                    const SizedBox(height: 20),
                    Text(
                      'Image Blur Level: ${_blurAmount.toStringAsFixed(0)}',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    SliderTheme(
                      data: SliderThemeData(
                        activeTrackColor: themeAccent,
                        inactiveTrackColor: themeAccent.withOpacity(0.2),
                        thumbColor: themeAccent,
                        overlayColor: themeAccent.withOpacity(0.1),
                        valueIndicatorColor: themeAccent,
                        valueIndicatorTextStyle: const TextStyle(color: Colors.white),
                      ),
                      child: Slider(
                        value: _blurAmount,
                        min: 0.0,
                        max: 30.0,
                        divisions: 30,
                        label: _blurAmount.toStringAsFixed(0),
                        onChanged: (val) {
                          setState(() {
                            _blurAmount = val;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Dark Overlay Opacity: ${(_overlayOpacity * 100).toStringAsFixed(0)}%',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    SliderTheme(
                      data: SliderThemeData(
                        activeTrackColor: themeAccent,
                        inactiveTrackColor: themeAccent.withOpacity(0.2),
                        thumbColor: themeAccent,
                        overlayColor: themeAccent.withOpacity(0.1),
                        valueIndicatorColor: themeAccent,
                        valueIndicatorTextStyle: const TextStyle(color: Colors.white),
                      ),
                      child: Slider(
                        value: _overlayOpacity,
                        min: 0.0,
                        max: 0.8,
                        divisions: 16,
                        label: '${(_overlayOpacity * 100).toStringAsFixed(0)}%',
                        onChanged: (val) {
                          setState(() {
                            _overlayOpacity = val;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Blur Style & Vignette',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF161619) : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: borderColor),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _blurStyle,
                          dropdownColor: isDark ? const Color(0xFF1E1E22) : Colors.white,
                          style: GoogleFonts.outfit(fontSize: 12, color: textColor),
                          isExpanded: true,
                          items: const [
                            DropdownMenuItem(
                              value: 'none',
                              child: Text('No Blur (Original Image)'),
                            ),
                            DropdownMenuItem(
                              value: 'full',
                              child: Text('All Blurred'),
                            ),
                            DropdownMenuItem(
                              value: 'radial',
                              child: Text('Sharp Center, Blurred Borders (Vignette)'),
                            ),
                            DropdownMenuItem(
                              value: 'bottom',
                              child: Text('Sharp Top, Blurred Bottom'),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _blurStyle = val;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),
                  Text(
                    'Name Font Family',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF161619) : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: borderColor),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _nameFontFamily,
                        dropdownColor: isDark ? const Color(0xFF1E1E22) : Colors.white,
                        style: GoogleFonts.outfit(fontSize: 12, color: textColor),
                        isExpanded: true,
                        items: ['Outfit', 'Playfair Display', 'Montserrat', 'Caveat', 'Cinzel', 'Inter']
                            .map((font) => DropdownMenuItem(
                                  value: font,
                                  child: Text(font, style: GoogleFonts.getFont(font, fontSize: 13, color: textColor)),
                                ))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _nameFontFamily = val;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Promotional Tagline',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _promoTaglineController,
                    style: GoogleFonts.outfit(fontSize: 12, color: textColor),
                    decoration: InputDecoration(
                      hintText: 'e.g., 🩺 Spesialis Bedah 10+ Thn',
                      hintStyle: GoogleFonts.outfit(fontSize: 11, color: subtitleColor),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF161619) : Colors.white,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: borderColor),
                      ),
                    ),
                    onChanged: (val) {
                      setState(() {});
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Tagline Font Family',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF161619) : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: borderColor),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _taglineFontFamily,
                        dropdownColor: isDark ? const Color(0xFF1E1E22) : Colors.white,
                        style: GoogleFonts.outfit(fontSize: 12, color: textColor),
                        isExpanded: true,
                        items: ['Outfit', 'Playfair Display', 'Montserrat', 'Caveat', 'Cinzel', 'Inter']
                            .map((font) => DropdownMenuItem(
                                  value: font,
                                  child: Text(font, style: GoogleFonts.getFont(font, fontSize: 13, color: textColor)),
                                ))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _taglineFontFamily = val;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Tagline Theme Style',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildTaglineColorOption('white', Colors.white, isDark),
                      _buildTaglineColorOption('amber', Colors.amber, isDark),
                      _buildTaglineColorOption('cyan', Colors.cyanAccent, isDark),
                      _buildTaglineColorOption('green', Colors.green, isDark),
                      _buildTaglineColorOption('rose', Colors.pink, isDark),
                    ],
                  ),
                ] else ...[
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 24),
                  _buildPremiumLockCard(themeAccent, textColor, subtitleColor, borderColor),
                ],
              ],
            ),
          ),
        ),
        
        // Footer: Save Button
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: borderColor)),
          ),
          child: ElevatedButton.icon(
            onPressed: _isSavingBg ? null : _saveHeaderBgSettings,
            icon: _isSavingBg
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.save_rounded, size: 16, color: Colors.white),
            label: Text(
              _isSavingBg ? 'Saving...' : 'Save Settings',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: themeAccent,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPremiumLockCard(Color themeAccent, Color textColor, Color subtitleColor, Color borderColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF1E1E22) : Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: themeAccent.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.lock_rounded, size: 28, color: themeAccent),
          ),
          const SizedBox(height: 16),
          Text(
            'Fitur Desain Profil Premium',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Upgrade ke Premium untuk membuka font nama, tagline promosi, kustomisasi blur level, vignette & gradient palette.',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 11,
              color: subtitleColor,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _showUpgradePlansModal,
              icon: const Icon(Icons.flash_on_rounded, size: 14, color: Colors.white),
              label: Text(
                'Pilih Paket Layanan',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: themeAccent,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showUpgradePlansModal() {
    showDialog(
      context: context,
      builder: (ctx) {
        final isDarkTheme = widget.isDark;
        final bg = isDarkTheme ? const Color(0xFF18181B) : Colors.white;
        final cardBg = isDarkTheme ? const Color(0xFF242427) : const Color(0xFFF9FAFB);
        final text = isDarkTheme ? Colors.white : const Color(0xFF1E1E22);
        final subText = isDarkTheme ? Colors.white70 : Colors.black54;
        final border = isDarkTheme ? Colors.white12 : Colors.black12;

        int subDaysRemaining = 0;
        if (_subscriptionExpiredAt != null) {
          try {
            final parsed = DateTime.parse(_subscriptionExpiredAt!);
            final diff = parsed.difference(DateTime.now());
            if (!diff.isNegative) {
              subDaysRemaining = diff.inDays;
            }
          } catch (_) {}
        }

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 1100),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: border, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDarkTheme ? 0.5 : 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Header Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(width: 32), // spacer to match close button width
                    Expanded(
                      child: Text(
                        'Pilih Paket Layanan',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: text,
                        ),
                      ),
                    ),
                    IconButton(
                      hoverColor: Colors.transparent,
                      splashColor: Colors.transparent,
                      highlightColor: Colors.transparent,
                      icon: Icon(Icons.close_rounded, color: text.withOpacity(0.7), size: 24),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Pilih paket yang sesuai untuk menunjang praktik Anda',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    color: subText,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 28),

                // Subscription Cards
                Flexible(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final syncUnits = (subDaysRemaining / 30).ceil();
                          final syncCalculatedDays = syncUnits * 30;
                          final syncAmount = syncUnits * 15000;
                          final syncPriceStr =
                              'Rp ${syncAmount.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';

                          final List<Widget> cards = [
                            _buildPlanCard(
                              title: 'Standard Subscription (30 Days)',
                              description: 'Akses penuh ke semua fitur dashboard praktik mandiri & booking pasien selama 30 hari.',
                              price: 'Rp 150.000',
                              priceSuffix: '/ 30 Hari',
                              isPopular: false,
                              accentColor: const Color(0xFF00BFA6),
                              textColor: text,
                              subTextColor: subText,
                              borderColor: border,
                              cardBg: cardBg,
                              features: [
                                'Akses fitur praktik mandiri',
                                'Sistem booking & antrean pasien',
                                'Dashboard statistik dokter',
                                'Durasi aktif 30 hari',
                              ],
                              onTap: () {
                                Navigator.of(ctx).pop();
                                Future.delayed(const Duration(milliseconds: 150), () {
                                  if (mounted) _buyPackageWithQris('subscription_30', 150000, 'Standard Subscription (30 Hari)');
                                });
                              },
                            ),
                            _buildPlanCard(
                              title: 'Premium Customizer (30 Days)',
                              description: 'Buka kustomisasi desain profil lengkap (font nama, tagline, blur level, vignette, custom gradients) selama 30 hari.',
                              price: 'Rp 20.000',
                              priceSuffix: '/ 30 Hari',
                              isPopular: false,
                              accentColor: const Color(0xFFFFB300),
                              textColor: text,
                              subTextColor: subText,
                              borderColor: border,
                              cardBg: cardBg,
                              features: [
                                'Ubah font nama & tagline profil',
                                'Kustomisasi background & gradient',
                                'Efek vignette & blur level',
                                'Tampilan profil premium',
                              ],
                              onTap: () {
                                Navigator.of(ctx).pop();
                                Future.delayed(const Duration(milliseconds: 150), () {
                                  if (mounted) _buyPackageWithQris('premium_30', 20000, 'Premium Customizer (30 Hari)');
                                });
                              },
                            ),
                            if (subDaysRemaining > 0)
                              _buildPlanCard(
                                title: 'Premium Customizer (Sync $subDaysRemaining Days)',
                                description: 'Sesuaikan durasi Premium Customizer dengan sisa langganan ($subDaysRemaining hari, dihitung $syncCalculatedDays hari @ Rp 15.000/30 hari).',
                                price: syncPriceStr,
                                priceSuffix: '/ $subDaysRemaining Hari',
                                isPopular: false,
                                accentColor: const Color(0xFFFFB300),
                                textColor: text,
                                subTextColor: subText,
                                borderColor: border,
                                cardBg: cardBg,
                                features: [
                                  'Durasi sinkron dengan langganan',
                                  'Semua fitur kustomisasi premium',
                                  'Lebih hemat & efisien',
                                ],
                                onTap: () {
                                  Navigator.of(ctx).pop();
                                  Future.delayed(const Duration(milliseconds: 150), () {
                                    if (mounted) _buyPackageWithQris('premium_sync', syncAmount, 'Premium Customizer (Sync $subDaysRemaining Hari)');
                                  });
                                },
                              ),
                            _buildPlanCard(
                              title: 'Premium Customizer (Lifetime)',
                              description: 'Buka kustomisasi desain profil premium. Aktif selama langganan Anda aktif. (Kehilangan status jika langganan dibiarkan kedaluwarsa).',
                              price: 'Rp 100.000',
                              priceSuffix: '/ Selamanya',
                              isPopular: true,
                              accentColor: const Color(0xFFFFB300),
                              textColor: text,
                              subTextColor: subText,
                              borderColor: border,
                              cardBg: cardBg,
                              features: [
                                'Akses customizer selamanya',
                                'Bebas perpanjangan bulanan',
                                'Semua fitur premium terbuka',
                                'Terikat status langganan',
                              ],
                              onTap: () {
                                Navigator.of(ctx).pop();
                                Future.delayed(const Duration(milliseconds: 150), () {
                                  if (mounted) _buyPackageWithQris('premium_lifetime', 100000, 'Premium Customizer (Lifetime)');
                                });
                              },
                            ),
                            _buildPlanCard(
                              title: 'Mega Bundle (30 Days)',
                              description: 'Gabungan akses Layanan Praktik & Kustomisasi Profil Premium selama 30 hari.',
                              price: 'Rp 160.000',
                              priceSuffix: '/ 30 Hari',
                              isPopular: false,
                              accentColor: const Color(0xFFCB8FFF),
                              textColor: text,
                              subTextColor: subText,
                              borderColor: border,
                              cardBg: cardBg,
                              features: [
                                'Semua fitur Standard Subscription',
                                'Semua fitur Premium Customizer',
                                'Lebih hemat dibanding beli terpisah',
                                'Satu kali pembayaran terpadu',
                              ],
                              onTap: () {
                                Navigator.of(ctx).pop();
                                Future.delayed(const Duration(milliseconds: 150), () {
                                  if (mounted) _buyPackageWithQris('bundle_30', 160000, 'Mega Bundle (30 Hari)');
                                });
                              },
                            ),
                          ];

                          return Center(
                            child: ScrollConfiguration(
                              behavior: ScrollConfiguration.of(context).copyWith(
                                dragDevices: {
                                  PointerDeviceKind.touch,
                                  PointerDeviceKind.mouse,
                                  PointerDeviceKind.trackpad,
                                },
                              ),
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: IntrinsicHeight(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: cards.map((card) {
                                      return SizedBox(
                                        width: 255,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                                          child: card,
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlanCard({
    required String title,
    required String description,
    required String price,
    required String priceSuffix,
    required bool isPopular,
    required Color accentColor,
    required Color textColor,
    required Color subTextColor,
    required Color borderColor,
    required Color cardBg,
    required List<String> features,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isPopular ? accentColor : borderColor,
          width: isPopular ? 2.5 : 1,
        ),
        boxShadow: isPopular
            ? [
                BoxShadow(
                  color: accentColor.withOpacity(0.15),
                  blurRadius: 16,
                  spreadRadius: 2,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                      ),
                    ),
                  ),
                  if (isPopular) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: accentColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'POPULER',
                        style: GoogleFonts.outfit(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 4,
                runSpacing: 4,
                children: [
                  Text(
                    price,
                    style: GoogleFonts.outfit(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: textColor,
                    ),
                  ),
                  Text(
                    priceSuffix,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: subTextColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: subTextColor,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: onTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Pilih Paket',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Divider(color: borderColor, height: 1),
              const SizedBox(height: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: features.map((feat) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          size: 16,
                          color: accentColor,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            feat,
                            style: GoogleFonts.outfit(
                              fontSize: 11.5,
                              color: textColor.withOpacity(0.85),
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _buyPackageWithQris(String packageType, int amount, String packageTitle) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF00BFA6)),
      ),
    );

    try {
      final userState = ref.read(landingPageProvider).loggedInUser;
      final email = userState?['email'] ?? 'customer@mapotech.app';
      final name = userState?['name'] ?? userState?['full_name'] ?? 'Pengguna';
      final doctorId = widget.dokter['id'] as String;

      Map<String, dynamic> res;
      try {
        res = await DuitkuPaymentService.createPayment(
          packageType: packageType,
          amount: amount,
          customerEmail: email,
          customerName: name,
        );
      } finally {
        if (mounted) Navigator.of(context, rootNavigator: true).pop(); // Dismiss loading
      }

      final orderId = res['orderId']?.toString() ?? '';
      final paymentUrl = res['paymentUrl']?.toString() ?? '';
      final qrString = res['qrString']?.toString() ?? '';
      final qrisAmount = (res['amount'] as num?)?.toInt() ?? amount;

      await Future.delayed(const Duration(milliseconds: 120));

      if (mounted) {
        CustomQrisDialog.show(
          context: context,
          orderId: orderId,
          paymentUrl: paymentUrl,
          qrString: qrString,
          amount: qrisAmount,
          packageType: packageType,
          packageTitle: packageTitle,
          userId: doctorId,
          isResume: false,
          onPaymentSuccess: () {
            _applyPackageSuccess(packageType, qrisAmount);
          },
          onResetPayment: () {
            DuitkuPaymentService.clearPendingPayment();
          },
        );
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memulai pembayaran: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _applyPackageSuccess(String packageType, int amount) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF00BFA6)),
      ),
    );

    try {
      final client = SupabaseService.client;
      final userId = widget.dokter['id'] as String;

      final res = await client
          .from('user_detail_doctor')
          .select('subscription_expired_at, subscription_status, header_bg_settings')
          .eq('id', userId)
          .maybeSingle();

      DateTime currentSubExpiry = DateTime.now();
      if (res != null && res['subscription_expired_at'] != null) {
        try {
          final parsed = DateTime.parse(res['subscription_expired_at'].toString());
          if (parsed.isAfter(DateTime.now())) {
            currentSubExpiry = parsed;
          }
        } catch (_) {}
      }

      final bgSettings = res?['header_bg_settings'];
      final Map<String, dynamic> settings = bgSettings is Map
          ? Map<String, dynamic>.from(bgSettings)
          : <String, dynamic>{};

      DateTime currentPremExpiry = DateTime.now();
      if (settings['is_premium'] == true && settings['premium_expired_at'] != 'lifetime' && settings['premium_expired_at'] != null) {
        try {
          final parsed = DateTime.parse(settings['premium_expired_at'].toString());
          if (parsed.isAfter(DateTime.now())) {
            currentPremExpiry = parsed;
          }
        } catch (_) {}
      }

      String newSubExpiryStr = res?['subscription_expired_at']?.toString() ?? '';
      String newSubStatus = res?['subscription_status']?.toString() ?? 'inactive';

      if (packageType == 'subscription_30') {
        final newExpiry = currentSubExpiry.add(const Duration(days: 30));
        newSubExpiryStr = newExpiry.toIso8601String();
        newSubStatus = 'active';
      } else if (packageType == 'premium_30') {
        settings['is_premium'] = true;
        if (settings['premium_expired_at'] == 'lifetime') {
          // Keep lifetime
        } else {
          final newExpiry = currentPremExpiry.add(const Duration(days: 30));
          settings['premium_expired_at'] = newExpiry.toIso8601String();
        }
      } else if (packageType == 'premium_sync') {
        settings['is_premium'] = true;
        settings['premium_expired_at'] = newSubExpiryStr;
      } else if (packageType == 'premium_lifetime') {
        settings['is_premium'] = true;
        settings['premium_expired_at'] = 'lifetime';
      } else if (packageType == 'bundle_30') {
        final newSubExpiry = currentSubExpiry.add(const Duration(days: 30));
        newSubExpiryStr = newSubExpiry.toIso8601String();
        newSubStatus = 'active';
        settings['is_premium'] = true;
        if (settings['premium_expired_at'] == 'lifetime') {
          // Keep lifetime
        } else {
          final newPremExpiry = currentPremExpiry.add(const Duration(days: 30));
          settings['premium_expired_at'] = newPremExpiry.toIso8601String();
        }
      }

      await client
          .from('user_detail_doctor')
          .update({
            'subscription_status': newSubStatus,
            'subscription_expired_at': newSubExpiryStr,
            'header_bg_settings': settings,
          })
          .eq('id', userId);

      String packageDesc = 'Pembelian Paket Layanan';
      if (packageType == 'subscription_30') packageDesc = 'Perpanjangan Langganan Praktik Mandiri 30 Hari';
      if (packageType == 'premium_30') packageDesc = 'Pembelian Kustomisasi Profil Premium 30 Hari';
      if (packageType == 'premium_sync') packageDesc = 'Pembelian Premium Customizer (Sinkronisasi Durasi)';
      if (packageType == 'premium_lifetime') packageDesc = 'Pembelian Kustomisasi Profil Premium Lifetime';
      if (packageType == 'bundle_30') packageDesc = 'Pembelian Paket Mega Bundle 30 Hari';

      try {
        final txData = {
          'id_user': userId,
          'transaction_type': 'expense',
          'source_type': 'manual',
          'amount': amount.toDouble(),
          'description': packageDesc,
          'category': 'Operasional',
          'status': 'active',
        };
        await client
            .schema('private_doctor')
            .from('financial_transactions')
            .insert(txData);
      } catch (dbErr) {
        debugPrint('Failed to auto-record package expense: $dbErr');
      }

      setState(() {
        _isSubscribed = newSubStatus == 'active';
        _subscriptionExpiredAt = newSubExpiryStr;

        final isPremiumField = settings['is_premium'] == true;
        final expAt = settings['premium_expired_at'];
        if (isPremiumField) {
          if (expAt == 'lifetime') {
            _isPremium = true;
          } else if (expAt != null) {
            try {
              final expDate = DateTime.parse(expAt.toString());
              _isPremium = expDate.isAfter(DateTime.now());
            } catch (_) {
              _isPremium = false;
            }
          } else {
            _isPremium = true;
          }
        } else {
          _isPremium = false;
        }
      });

      if (mounted) Navigator.of(context).pop();
      _showPurchaseSuccessDialog(packageType);
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Pembelian gagal: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _renewPackage(String packageType, int amount) async {
    Navigator.of(context).pop(); // Close bottom sheet first
    
    // Show Loading Dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF00BFA6)),
      ),
    );

    try {
      final client = SupabaseService.client;
      final userId = widget.dokter['id'] as String;

      // 1. Fetch current database record
      final res = await client
          .from('user_detail_doctor')
          .select('subscription_expired_at, subscription_status, header_bg_settings')
          .eq('id', userId)
          .maybeSingle();

      DateTime currentSubExpiry = DateTime.now();
      if (res != null && res['subscription_expired_at'] != null) {
        try {
          final parsed = DateTime.parse(res['subscription_expired_at'].toString());
          if (parsed.isAfter(DateTime.now())) {
            currentSubExpiry = parsed;
          }
        } catch (_) {}
      }

      final bgSettings = res?['header_bg_settings'];
      final Map<String, dynamic> settings = bgSettings is Map
          ? Map<String, dynamic>.from(bgSettings)
          : <String, dynamic>{};

      DateTime currentPremExpiry = DateTime.now();
      if (settings['is_premium'] == true && settings['premium_expired_at'] != 'lifetime' && settings['premium_expired_at'] != null) {
        try {
          final parsed = DateTime.parse(settings['premium_expired_at'].toString());
          if (parsed.isAfter(DateTime.now())) {
            currentPremExpiry = parsed;
          }
        } catch (_) {}
      }

      String newSubExpiryStr = res?['subscription_expired_at']?.toString() ?? '';
      String newSubStatus = res?['subscription_status']?.toString() ?? 'inactive';

      // 2. Determine changes based on packageType
      if (packageType == 'subscription_30') {
        final newExpiry = currentSubExpiry.add(const Duration(days: 30));
        newSubExpiryStr = newExpiry.toIso8601String();
        newSubStatus = 'active';
      } else if (packageType == 'subscription_lifetime') {
        newSubExpiryStr = DateTime(2099, 12, 31, 23, 59, 59).toIso8601String();
        newSubStatus = 'active';
      } else if (packageType == 'premium_30') {
        settings['is_premium'] = true;
        if (settings['premium_expired_at'] == 'lifetime') {
          // If already lifetime, keep it lifetime
        } else {
          final newExpiry = currentPremExpiry.add(const Duration(days: 30));
          settings['premium_expired_at'] = newExpiry.toIso8601String();
        }
      } else if (packageType == 'premium_sync') {
        settings['is_premium'] = true;
        settings['premium_expired_at'] = newSubExpiryStr;
      } else if (packageType == 'premium_lifetime') {
        settings['is_premium'] = true;
        settings['premium_expired_at'] = 'lifetime';
      } else if (packageType == 'bundle_30') {
        // Subs 30
        final newSubExpiry = currentSubExpiry.add(const Duration(days: 30));
        newSubExpiryStr = newSubExpiry.toIso8601String();
        newSubStatus = 'active';
        // Premium 30
        settings['is_premium'] = true;
        if (settings['premium_expired_at'] == 'lifetime') {
          // Keep lifetime
        } else {
          final newPremExpiry = currentPremExpiry.add(const Duration(days: 30));
          settings['premium_expired_at'] = newPremExpiry.toIso8601String();
        }
      } else if (packageType == 'bundle_lifetime') {
        // Subs lifetime
        newSubExpiryStr = DateTime(2099, 12, 31, 23, 59, 59).toIso8601String();
        newSubStatus = 'active';
        // Premium lifetime
        settings['is_premium'] = true;
        settings['premium_expired_at'] = 'lifetime';
      }

      // 3. Perform database update
      await client
          .from('user_detail_doctor')
          .update({
            'subscription_status': newSubStatus,
            'subscription_expired_at': newSubExpiryStr,
            'header_bg_settings': settings,
          })
          .eq('id', userId);

      // Record financial expense
      String packageDesc = 'Pembelian Paket Layanan';
      if (packageType == 'subscription_30') packageDesc = 'Perpanjangan Langganan Praktik Mandiri 30 Hari';
      if (packageType == 'subscription_lifetime') packageDesc = 'Langganan Praktik Mandiri Lifetime';
      if (packageType == 'premium_30') packageDesc = 'Pembelian Kustomisasi Profil Premium 30 Hari';
      if (packageType == 'premium_sync') packageDesc = 'Pembelian Premium Customizer (Sinkronisasi Durasi)';
      if (packageType == 'premium_lifetime') packageDesc = 'Pembelian Kustomisasi Profil Premium Lifetime';
      if (packageType == 'bundle_30') packageDesc = 'Pembelian Paket Mega Bundle 30 Hari';
      if (packageType == 'bundle_lifetime') packageDesc = 'Pembelian Paket Mega Bundle Lifetime';

      try {
        final txData = {
          'id_user': userId,
          'transaction_type': 'expense',
          'source_type': 'manual',
          'amount': amount.toDouble(),
          'description': packageDesc,
          'category': 'Operasional',
          'status': 'active',
        };
        await client
            .schema('private_doctor')
            .from('financial_transactions')
            .insert(txData);
      } catch (dbErr) {
        debugPrint('Failed to auto-record package expense: $dbErr');
      }

      // 4. Update local state
      setState(() {
        _isSubscribed = newSubStatus == 'active';
        _subscriptionExpiredAt = newSubExpiryStr;

        final isPremiumField = settings['is_premium'] == true;
        final expAt = settings['premium_expired_at'];
        if (isPremiumField) {
          if (expAt == 'lifetime') {
            _isPremium = true;
          } else if (expAt != null) {
            try {
              final expDate = DateTime.parse(expAt.toString());
              _isPremium = expDate.isAfter(DateTime.now());
            } catch (_) {
              _isPremium = false;
            }
          } else {
            _isPremium = true;
          }
        } else {
          _isPremium = false;
        }
      });

      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

      // Show Success Dialog
      _showPurchaseSuccessDialog(packageType);

    } catch (e) {
      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

      // Show Error Snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Pembelian gagal: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _showPurchaseSuccessDialog(String packageType) {
    showDialog(
      context: context,
      builder: (ctx) {
        final isDarkTheme = widget.isDark;
        final bg = isDarkTheme ? const Color(0xFF1E1E22) : Colors.white;
        final text = isDarkTheme ? Colors.white : const Color(0xFF1E1E22);
        final subText = isDarkTheme ? Colors.white60 : Colors.black54;

        String packageName = '';
        if (packageType == 'subscription_30') packageName = 'Standard Subscription (30 Hari)';
        if (packageType == 'subscription_lifetime') packageName = 'Standard Subscription (Lifetime)';
        if (packageType == 'premium_30') packageName = 'Premium Customizer (30 Hari)';
        if (packageType == 'premium_sync') packageName = 'Premium Customizer (Sync Durasi)';
        if (packageType == 'premium_lifetime') packageName = 'Premium Customizer (Lifetime)';
        if (packageType == 'bundle_30') packageName = 'Mega Bundle (30 Hari)';
        if (packageType == 'bundle_lifetime') packageName = 'Mega Bundle (Lifetime)';

        return Dialog(
          backgroundColor: bg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Color(0xFF00BFA6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Pembelian Sukses!',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: text,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Paket $packageName Anda telah berhasil diaktifkan. Terima kasih telah menggunakan MAPOTECH!',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: subText,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00BFA6),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    child: Text(
                      'Selesai',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBgTypeRadio({
    required String value,
    required String title,
    required IconData icon,
    required Color textColor,
    required Color themeAccent,
  }) {
    final isSelected = _bgType == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _bgType = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? themeAccent.withOpacity(0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? themeAccent : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? themeAccent : textColor.withOpacity(0.6),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: textColor,
                ),
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded, size: 16, color: themeAccent),
          ],
        ),
      ),
    );
  }

  Widget _buildTaglineColorOption(String colorName, Color color, bool isDark) {
    final isSelected = _taglineColor.toLowerCase() == colorName.toLowerCase();
    return GestureDetector(
      onTap: () {
        setState(() {
          _taglineColor = colorName;
        });
      },
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected
                ? (isDark ? Colors.white : Colors.black)
                : color.withOpacity(0.6),
            width: isSelected ? 2.5 : 1,
          ),
        ),
        alignment: Alignment.center,
        child: Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }

  Widget _buildGradientOption(String name, List<Color> colors, bool isDark) {
    final isSelected = _gradientTheme.toLowerCase() == name.toLowerCase();
    return GestureDetector(
      onTap: () {
        setState(() {
          _gradientTheme = name;
        });
      },
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected
                ? (isDark ? Colors.white : Colors.black)
                : Colors.transparent,
            width: isSelected ? 2.5 : 0,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 4,
                spreadRadius: 1,
              ),
          ],
        ),
        padding: const EdgeInsets.all(2),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickAndUploadHeaderBg() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      setState(() => _isUploadingBgImage = true);

      final file = result.files.first;
      Uint8List? bytes = file.bytes;
      if (bytes == null && !kIsWeb && file.path != null) {
        bytes = io.File(file.path!).readAsBytesSync();
      }

      if (bytes == null) {
        throw Exception('Could not read file bytes.');
      }

      final fileName = file.name;
      final userId = widget.dokter['id'] as String;
      final storagePath = 'practice_backgrounds/$userId/${DateTime.now().millisecondsSinceEpoch}_$fileName';

      // Upload to Supabase Storage
      await SupabaseService.client.storage
          .from('profiles')
          .uploadBinary(storagePath, bytes);

      // Get public URL
      final publicUrl = SupabaseService.client.storage
          .from('profiles')
          .getPublicUrl(storagePath);

      if (mounted) {
        setState(() {
          _customBgUrlController.text = publicUrl;
          _isUploadingBgImage = false;
        });
      }
    } catch (e) {
      print('Upload bg failed: $e');
      if (mounted) {
        setState(() => _isUploadingBgImage = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal upload gambar: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  TextStyle _getNameStyle(Color color) {
    final font = _isPremium ? _nameFontFamily : 'Outfit';
    try {
      return GoogleFonts.getFont(
        font,
        fontSize: 20,
        fontWeight: FontWeight.w900,
        color: color,
      );
    } catch (_) {
      return GoogleFonts.outfit(
        fontSize: 20,
        fontWeight: FontWeight.w900,
        color: color,
      );
    }
  }

  TextStyle _getTaglineStyle(Color color) {
    final font = _isPremium ? _taglineFontFamily : 'Outfit';
    try {
      return GoogleFonts.getFont(
        font,
        fontSize: 10,
        fontWeight: FontWeight.bold,
        color: color,
      );
    } catch (_) {
      return GoogleFonts.outfit(
        fontSize: 10,
        fontWeight: FontWeight.bold,
        color: color,
      );
    }
  }

  Color _getTaglineBgColor() {
    switch (_taglineColor.toLowerCase()) {
      case 'amber':
        return Colors.amber.withOpacity(0.15);
      case 'cyan':
        return Colors.cyan.withOpacity(0.15);
      case 'green':
        return Colors.green.withOpacity(0.15);
      case 'rose':
        return Colors.pink.withOpacity(0.15);
      case 'white':
      default:
        return Colors.white.withOpacity(0.15);
    }
  }

  Color _getTaglineBorderColor() {
    switch (_taglineColor.toLowerCase()) {
      case 'amber':
        return Colors.amber.withOpacity(0.3);
      case 'cyan':
        return Colors.cyan.withOpacity(0.3);
      case 'green':
        return Colors.green.withOpacity(0.3);
      case 'rose':
        return Colors.pink.withOpacity(0.3);
      case 'white':
      default:
        return Colors.white.withOpacity(0.3);
    }
  }

  Color _getTaglineIconColor() {
    switch (_taglineColor.toLowerCase()) {
      case 'amber':
        return Colors.amberAccent;
      case 'cyan':
        return Colors.cyanAccent;
      case 'green':
        return Colors.greenAccent;
      case 'rose':
        return Colors.pinkAccent;
      case 'white':
      default:
        return Colors.amber;
    }
  }

  Color _getTaglineTextColor() {
    switch (_taglineColor.toLowerCase()) {
      case 'amber':
        return Colors.amberAccent;
      case 'cyan':
        return Colors.cyanAccent;
      case 'green':
        return Colors.greenAccent;
      case 'rose':
        return Colors.pinkAccent;
      case 'white':
      default:
        return Colors.white;
    }
  }

  Future<void> _saveHeaderBgSettings() async {
    setState(() => _isSavingBg = true);
    try {
      final client = SupabaseService.client;
      final settings = {
        'bg_type': _bgType,
        'image_url': _customBgUrlController.text.trim(),
        'name_font_family': _nameFontFamily,
        'promo_tagline': _promoTaglineController.text.trim(),
        'tagline_font_family': _taglineFontFamily,
        'tagline_color': _taglineColor,
        'gradient_theme': _gradientTheme,
        'blur_amount': _blurAmount,
        'overlay_opacity': _overlayOpacity,
        'blur_style': _blurStyle,
        'is_premium': _isPremium,
      };
      await client
          .from('user_detail_doctor')
          .update({'header_bg_settings': settings})
          .eq('id', widget.dokter['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Header background settings saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving background settings: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingBg = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(landingPageProvider);
    final appearance = state.appearance;
    final isDark = appearance == 'dark';
    final notifier = ref.read(landingPageProvider.notifier);

    final themeAccent = notifier.getPrimaryColor();
    final cardBg = isDark ? const Color(0xFF161619) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1B0C3C);
    final subtitleColor = isDark ? Colors.grey[400]! : const Color(0xFF6F6A8A);
    final borderColor = isDark ? const Color(0xFF252528) : const Color(0xFFECEEF2);
    final sectionBg = isDark ? const Color(0xFF1E1E22) : const Color(0xFFF8FAFD);

    final isMobile = MediaQuery.of(context).size.width < 600;
    final dialogWidth = isMobile ? double.infinity : 520.0;
    final showSettings = widget.isPreview && !isMobile;

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : (MediaQuery.of(context).size.width - (dialogWidth + (showSettings ? 320 : 0))) / 2,
        vertical: 40,
      ),
      backgroundColor: Colors.transparent,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Main Dialog Card
          Container(
            width: dialogWidth,
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: showSettings
                  ? const BorderRadius.only(
                      topLeft: Radius.circular(28),
                      bottomLeft: Radius.circular(28),
                    )
                  : BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 40,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Header ──────────────────────────────────────────────────
                ClipRect(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: _buildHeaderBackground(appearance, isDark, themeAccent),
                      ),
                      Container(
                        padding: const EdgeInsets.fromLTRB(24, 24, 16, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(100),
                                  ),
                                  child: Text(
                                    widget.dokter['profession']?.toString().toUpperCase() ?? 'DOKTER',
                                    style: GoogleFonts.outfit(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                                  onPressed: () => Navigator.of(context).pop(),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Container(
                                  width: 72,
                                  height: 72,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.25),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white.withOpacity(0.6), width: 2),
                                  ),
                                  alignment: Alignment.center,
                                  child: ClipOval(
                                    child: widget.dokter['avatar_url'] != null
                                        ? Image.network(
                                            widget.dokter['avatar_url']!,
                                            width: 72,
                                            height: 72,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => _buildInitialsAvatar(themeAccent),
                                          )
                                        : _buildInitialsAvatar(themeAccent),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        widget.dokter['name'],
                                        style: _getNameStyle(Colors.white),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        widget.dokter['nama_faskes'] ?? 'Praktek Mandiri',
                                        style: GoogleFonts.outfit(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white.withOpacity(0.9),
                                        ),
                                      ),
                                      if (_isPremium && _promoTaglineController.text.trim().isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: _getTaglineBgColor(),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: _getTaglineBorderColor(),
                                              width: 1,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.stars_rounded,
                                                size: 11,
                                                color: _getTaglineIconColor(),
                                              ),
                                              const SizedBox(width: 4),
                                              Flexible(
                                                child: Text(
                                                  _promoTaglineController.text.trim(),
                                                  style: _getTaglineStyle(_getTaglineTextColor()),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            TabBar(
                              controller: _tabController,
                              indicatorColor: Colors.white,
                              indicatorWeight: 3,
                              labelColor: Colors.white,
                              unselectedLabelColor: Colors.white.withOpacity(0.55),
                              labelStyle: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w800),
                              unselectedLabelStyle: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600),
                              tabs: const [
                                Tab(text: 'Detail'),
                                Tab(text: 'Booking'),
                                Tab(text: 'Dokumen'),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Tab Content ──────────────────────────────────────────────
                Flexible(
                  child: TabBarView(
                    controller: _tabController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      // TAB 1 — Detail
                      SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Action buttons
                            Row(
                              children: [
                                if (widget.dokter['whatsapp_number'] != null &&
                                    widget.dokter['whatsapp_number'].toString().isNotEmpty)
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: _launchWhatsApp,
                                      icon: const Icon(Icons.chat_bubble_outline_rounded,
                                          size: 16, color: Colors.white),
                                      label: Text(
                                        'Chat WhatsApp',
                                        style: GoogleFonts.outfit(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF27AE60),
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(14)),
                                        elevation: 0,
                                      ),
                                    ),
                                  ),
                                if (widget.dokter['whatsapp_number'] != null &&
                                    widget.dokter['whatsapp_number'].toString().isNotEmpty &&
                                    widget.dokter['google_maps_link'] != null &&
                                    widget.dokter['google_maps_link'].toString().isNotEmpty)
                                  const SizedBox(width: 12),
                                if (widget.dokter['google_maps_link'] != null &&
                                    widget.dokter['google_maps_link'].toString().isNotEmpty)
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: _launchMaps,
                                      icon: Icon(Icons.map_outlined, size: 16, color: themeAccent),
                                      label: Text(
                                        'Buka Peta',
                                        style: GoogleFonts.outfit(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: themeAccent,
                                        ),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: themeAccent,
                                        side: BorderSide(color: themeAccent, width: 1.5),
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(14)),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            if ((widget.dokter['whatsapp_number'] != null &&
                                    widget.dokter['whatsapp_number'].toString().isNotEmpty) ||
                                (widget.dokter['google_maps_link'] != null &&
                                    widget.dokter['google_maps_link'].toString().isNotEmpty))
                              const SizedBox(height: 24),

                            // Tentang Praktik
                            _buildSectionHeader(
                                'Tentang Praktik',
                                Icons.info_outline_rounded,
                                themeAccent,
                                textColor),
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: sectionBg,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: borderColor),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _getAboutText(),
                                    style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: textColor,
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),

                        // Jadwal Praktik
                        _buildSectionHeader(
                            'Jadwal Praktik',
                            Icons.calendar_month_outlined,
                            themeAccent,
                            textColor),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: sectionBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: borderColor),
                          ),
                          child: _buildSchedulesWidget(textColor, subtitleColor, themeAccent),
                        ),

                        const SizedBox(height: 24),

                        // Lokasi Praktik
                        _buildSectionHeader(
                            'Lokasi Praktik',
                            Icons.location_on_outlined,
                            themeAccent,
                            textColor),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: sectionBg,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: borderColor),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _formatFullAddress().isNotEmpty
                                    ? _formatFullAddress()
                                    : 'Alamat praktik tidak tersedia.',
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: textColor,
                                  height: 1.5,
                                ),
                              ),
                              if (_hasMapsLink()) ...[
                                const SizedBox(height: 12),
                                Container(
                                  height: 220,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: borderColor),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(11),
                                    child: _buildMapContent(isDark),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),
                        // Quick book button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _tabController.animateTo(1),
                            icon: const Icon(Icons.event_rounded, size: 16, color: Colors.white),
                            label: Text(
                              'Buat Janji Temu',
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: themeAccent,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // TAB 2 Ã¢â‚¬â€ Booking
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: _buildBookingTab(
                        textColor, subtitleColor, themeAccent, sectionBg, borderColor),
                  ),

                  // TAB 3 Ã¢â‚¬â€ Dokumen
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: _buildDocumentsTab(
                        textColor, subtitleColor, themeAccent, sectionBg, borderColor),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      
      // Settings Card on the Right (Customization Panel)
      if (showSettings)
        Container(
          width: 320,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E22) : const Color(0xFFF3F4F6),
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(28),
              bottomRight: Radius.circular(28),
            ),
            border: Border(
              left: BorderSide(color: borderColor),
            ),
          ),
          child: _buildPreviewSettingsPanel(
            isDark,
            textColor,
            subtitleColor,
            themeAccent,
            borderColor,
          ),
        ),
        ],
      ),
    );
  }
}

class MapGraphicsPainter extends CustomPainter {
  final bool isDark;
  final double zoomLevel;

  MapGraphicsPainter({required this.isDark, required this.zoomLevel});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint landPaint = Paint()
      ..color = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
    final Paint roadPaint = Paint()
      ..color = isDark ? const Color(0xFF334155) : Colors.white
      ..strokeWidth = 6 * (zoomLevel / 15.0)
      ..style = PaintingStyle.stroke;
    final Paint secondaryRoadPaint = Paint()
      ..color = isDark
          ? const Color(0xFF475569).withOpacity(0.5)
          : const Color(0xFFE2E8F0)
      ..strokeWidth = 3 * (zoomLevel / 15.0)
      ..style = PaintingStyle.stroke;
    final Paint parkPaint = Paint()
      ..color = isDark
          ? const Color(0xFF14532D).withOpacity(0.3)
          : const Color(0xFFDCFCE7);
    final Paint waterPaint = Paint()
      ..color = isDark
          ? const Color(0xFF1E3A8A).withOpacity(0.5)
          : const Color(0xFFE0F2FE);
    final Paint buildingPaint = Paint()
      ..color = isDark
          ? const Color(0xFF334155).withOpacity(0.4)
          : const Color(0xFFE2E8F0).withOpacity(0.8);

    // Land
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), landPaint);

    final double cx = size.width / 2;
    final double cy = size.height / 2;

    // Scale spacing based on zoom level
    final double spacing = 80.0 * (zoomLevel / 15.0);

    // Parks (zooms relative to center)
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx - spacing * 2, cy - spacing),
        width: 180 * (zoomLevel / 15.0),
        height: 100 * (zoomLevel / 15.0),
      ),
      parkPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx + spacing * 2, cy + spacing),
        width: 150 * (zoomLevel / 15.0),
        height: 120 * (zoomLevel / 15.0),
      ),
      parkPaint,
    );

    // Water channel (river)
    final Path waterPath = Path();
    waterPath.moveTo(0, size.height - 40 * (zoomLevel / 15.0));
    waterPath.quadraticBezierTo(
      cx - spacing,
      size.height - 60 * (zoomLevel / 15.0),
      cx,
      size.height - 20 * (zoomLevel / 15.0),
    );
    waterPath.quadraticBezierTo(
      cx + spacing,
      size.height + 20 * (zoomLevel / 15.0),
      size.width,
      size.height - 10 * (zoomLevel / 15.0),
    );
    waterPath.lineTo(size.width, size.height);
    waterPath.lineTo(0, size.height);
    waterPath.close();
    canvas.drawPath(waterPath, waterPaint);

    // Draw some mock building blocks
    final double buildingSize = 25.0 * (zoomLevel / 15.0);
    for (double x = cx - spacing * 3; x < size.width + spacing; x += spacing) {
      for (
        double y = cy - spacing * 2;
        y < size.height + spacing;
        y += spacing
      ) {
        if ((x - cx).abs() > 10 && (y - cy).abs() > 10) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(
                x + 10 * (zoomLevel / 15.0),
                y + 10 * (zoomLevel / 15.0),
                buildingSize,
                buildingSize,
              ),
              const Radius.circular(4),
            ),
            buildingPaint,
          );
        }
      }
    }

    // Roads layout grid (relative to center to avoid horizontal stretching)
    // Vertical secondary roads
    for (double x = cx; x < size.width + spacing; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), secondaryRoadPaint);
    }
    for (double x = cx - spacing; x > -spacing; x -= spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), secondaryRoadPaint);
    }

    // Horizontal secondary roads
    for (double y = cy; y < size.height + spacing; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), secondaryRoadPaint);
    }
    for (double y = cy - spacing; y > -spacing; y -= spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), secondaryRoadPaint);
    }

    // Main Diagonal Road
    canvas.drawLine(
      Offset(cx - size.width, cy - size.width * 0.5),
      Offset(cx + size.width, cy + size.width * 0.5),
      roadPaint,
    );

    // Crossing Main Road
    canvas.drawLine(
      Offset(cx - size.width, cy + size.width * 0.3),
      Offset(cx + size.width, cy - size.width * 0.3),
      roadPaint,
    );
  }

  @override
  bool shouldRepaint(covariant MapGraphicsPainter oldDelegate) {
    return oldDelegate.isDark != isDark || oldDelegate.zoomLevel != zoomLevel;
  }
}

/// Modal Dialog to select patient (Self vs Family Member via KK)
class _PatientBookingSelectionDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic> user;
  final Map<String, dynamic> dokter;
  final DateTime selectedDate;
  final String selectedTimeSlot;
  final bool isDark;
  final Function(String patientId, String patientName, String relationship) onConfirmed;

  const _PatientBookingSelectionDialog({
    required this.user,
    required this.dokter,
    required this.selectedDate,
    required this.selectedTimeSlot,
    required this.isDark,
    required this.onConfirmed,
  });

  @override
  ConsumerState<_PatientBookingSelectionDialog> createState() => _PatientBookingSelectionDialogState();
}

class _PatientBookingSelectionDialogState extends ConsumerState<_PatientBookingSelectionDialog> {
  final SupabaseService _db = SupabaseService();
  String _selectedType = 'self'; // 'self' or 'family'
  Map<String, dynamic>? _selectedFamilyMember;
  List<Map<String, dynamic>> _familyMembers = [];
  bool _isLoadingFamily = true;

  @override
  void initState() {
    super.initState();
    _loadFamilyMembers();
  }

  Future<void> _loadFamilyMembers() async {
    try {
      final userId = widget.user['id']?.toString() ?? '';
      if (userId.isNotEmpty) {
        final list = await _db.fetchAllFamilyMembersForUser(userId);
        if (mounted) {
          setState(() {
            _familyMembers = list;
            if (list.isNotEmpty) {
              _selectedFamilyMember = list.first;
            }
            _isLoadingFamily = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoadingFamily = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingFamily = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(landingPageProvider.notifier);
    final cardBgColor = notifier.getCardColor();
    final textColor = notifier.getTextColor();
    final subtitleColor = notifier.getBodyTextColor();
    final borderColor = notifier.getBorderColor();
    final themeAccent = notifier.getPrimaryColor();
    final isDark = widget.isDark;

    final userName = widget.user['name']?.toString() ?? 'Saya Sendiri';
    final userNik = widget.user['nik']?.toString() ?? '-';

    final monthNames = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Ags', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    final dateFormatted = '${widget.selectedDate.day} ${monthNames[widget.selectedDate.month - 1]} ${widget.selectedDate.year} pukul ${widget.selectedTimeSlot}';

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: 520,
        constraints: const BoxConstraints(maxHeight: 700),
        decoration: BoxDecoration(
          color: cardBgColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 25,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF2D1B4E), const Color(0xFF1B0C3C)]
                        : [const Color(0xFFF3E8FF), const Color(0xFFE9D5FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border(bottom: BorderSide(color: borderColor)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: themeAccent.withOpacity(0.18),
                        shape: BoxShape.circle,
                        border: Border.all(color: themeAccent.withOpacity(0.4)),
                      ),
                      alignment: Alignment.center,
                      child: Icon(Icons.people_alt_rounded, color: themeAccent, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pilih Pasien Berobat',
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Janji temu untuk diri sendiri atau keluarga di KK',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              color: subtitleColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: subtitleColor, size: 20),
                      onPressed: () => Navigator.pop(context),
                      splashRadius: 18,
                    ),
                  ],
                ),
              ),

              // Content Body
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Appointment summary mini card
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E1E22) : const Color(0xFFF8FAFD),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: borderColor),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today_rounded, size: 16, color: themeAccent),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    dateFormatted,
                                    style: GoogleFonts.outfit(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: textColor,
                                    ),
                                  ),
                                  Text(
                                    widget.dokter['name']?.toString() ?? 'Dokter',
                                    style: GoogleFonts.outfit(
                                      fontSize: 11,
                                      color: subtitleColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 18),

                      // Segmented type selector
                      Row(
                        children: [
                          Expanded(
                            child: _buildTypeSegmentButton(
                              label: 'Diri Sendiri',
                              icon: Icons.person_rounded,
                              isSelected: _selectedType == 'self',
                              onTap: () => setState(() => _selectedType = 'self'),
                              themeAccent: themeAccent,
                              borderColor: borderColor,
                              isDark: isDark,
                              textColor: textColor,
                              subtitleColor: subtitleColor,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildTypeSegmentButton(
                              label: 'Keluarga (KK)',
                              icon: Icons.family_restroom_rounded,
                              isSelected: _selectedType == 'family',
                              onTap: () => setState(() => _selectedType = 'family'),
                              themeAccent: themeAccent,
                              borderColor: borderColor,
                              isDark: isDark,
                              textColor: textColor,
                              subtitleColor: subtitleColor,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Selection Details
                      if (_selectedType == 'self') ...[
                        _buildPatientOptionCard(
                          isSelected: true,
                          title: userName,
                          subtitle: userNik.isNotEmpty && userNik != '-' ? 'NIK: $userNik' : 'Akun Utama',
                          badge: 'Saya Sendiri',
                          icon: Icons.person_rounded,
                          accentColor: themeAccent,
                          borderColor: borderColor,
                          isDark: isDark,
                          textColor: textColor,
                          subtitleColor: subtitleColor,
                          onTap: () {},
                        ),
                      ] else ...[
                        if (_isLoadingFamily)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: CircularProgressIndicator(color: themeAccent),
                            ),
                          )
                        else if (_familyMembers.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E1E22) : const Color(0xFFF8FAFD),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: borderColor),
                            ),
                            child: Column(
                              children: [
                                Icon(Icons.family_restroom_rounded, size: 36, color: subtitleColor.withOpacity(0.5)),
                                const SizedBox(height: 8),
                                Text(
                                  'Belum Ada Anggota Keluarga',
                                  style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Tidak ada anggota keluarga yang terhubung pada KK akun Anda. Tambahkan anggota keluarga melalui menu Profil.',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    color: subtitleColor,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.person_rounded, size: 14),
                                  label: Text('Gunakan Diri Sendiri', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold)),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: themeAccent,
                                    side: BorderSide(color: themeAccent),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  onPressed: () => setState(() => _selectedType = 'self'),
                                ),
                              ],
                            ),
                          )
                        else
                          Column(
                            children: _familyMembers.map((member) {
                              final name = member['nama']?.toString() ?? 'Anggota Keluarga';
                              final hubungan = member['hubungan']?.toString() ?? 'Keluarga';
                              final nik = member['nik']?.toString() ?? '-';
                              final isSelected = _selectedFamilyMember == member;

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _buildPatientOptionCard(
                                  isSelected: isSelected,
                                  title: name,
                                  subtitle: nik.isNotEmpty && nik != '-' ? 'NIK: $nik' : hubungan,
                                  badge: hubungan,
                                  icon: Icons.family_restroom_rounded,
                                  accentColor: themeAccent,
                                  borderColor: borderColor,
                                  isDark: isDark,
                                  textColor: textColor,
                                  subtitleColor: subtitleColor,
                                  onTap: () => setState(() => _selectedFamilyMember = member),
                                ),
                              );
                            }).toList(),
                          ),
                      ],
                    ],
                  ),
                ),
              ),

              // Bottom Actions
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBgColor,
                  border: Border(top: BorderSide(color: borderColor)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: subtitleColor,
                          side: BorderSide(color: borderColor),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          'Batal',
                          style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          if (_selectedType == 'self') {
                            widget.onConfirmed(
                              widget.user['id']?.toString() ?? '',
                              userName,
                              'Diri Sendiri',
                            );
                          } else {
                            if (_selectedFamilyMember != null) {
                              final memberId = _selectedFamilyMember!['member_user_id']?.toString();
                              final patientId = (memberId != null && memberId.isNotEmpty)
                                  ? memberId
                                  : (widget.user['id']?.toString() ?? '');
                              final memberName = _selectedFamilyMember!['nama']?.toString() ?? 'Keluarga';
                              final relationship = _selectedFamilyMember!['hubungan']?.toString() ?? 'Keluarga';
                              widget.onConfirmed(
                                patientId,
                                memberName,
                                relationship,
                              );
                            } else {
                              widget.onConfirmed(
                                widget.user['id']?.toString() ?? '',
                                userName,
                                'Diri Sendiri',
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.check_circle_rounded, size: 16),
                        label: Text(
                          _selectedType == 'self'
                              ? 'Booking Untuk Saya'
                              : 'Booking Untuk ${_selectedFamilyMember?['nama'] ?? "Keluarga"}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 12, color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: themeAccent,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeSegmentButton({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required Color themeAccent,
    required Color borderColor,
    required bool isDark,
    required Color textColor,
    required Color subtitleColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? themeAccent.withOpacity(0.12)
              : (isDark ? const Color(0xFF1E1E22) : const Color(0xFFF8FAFD)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? themeAccent : borderColor,
            width: isSelected ? 1.8 : 1.0,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? themeAccent : subtitleColor,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? themeAccent : textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientOptionCard({
    required bool isSelected,
    required String title,
    required String subtitle,
    required String badge,
    required IconData icon,
    required Color accentColor,
    required Color borderColor,
    required bool isDark,
    required Color textColor,
    required Color subtitleColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? accentColor.withOpacity(0.08)
              : (isDark ? const Color(0xFF1E1E22) : const Color(0xFFF8FAFD)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? accentColor : borderColor,
            width: isSelected ? 1.8 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 18, color: accentColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: textColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: accentColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          badge,
                          style: GoogleFonts.outfit(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: accentColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      color: subtitleColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? accentColor : Colors.transparent,
                border: Border.all(
                  color: isSelected ? accentColor : borderColor,
                  width: 1.5,
                ),
              ),
              alignment: Alignment.center,
              child: isSelected
                  ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

