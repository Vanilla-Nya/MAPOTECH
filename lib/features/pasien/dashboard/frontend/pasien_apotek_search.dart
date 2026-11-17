import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapotech/features/landing/landing_page_data.dart';
import 'package:mapotech/shared/supabase_service.dart';
import 'package:mapotech/shared/widgets/empty_state_widget.dart';
import 'package:mapotech/features/pasien/dashboard/frontend/widgets/pasien_qr_scanner_dialog.dart';
import 'package:mapotech/features/pasien/dashboard/frontend/widgets/pasien_apotek_pos_dialog.dart';
import 'package:mapotech/features/pasien/dashboard/frontend/pasien_dokter_search.dart';

/// Cari Apotek - Pasien Dashboard Page
class PasienApotekSearch extends ConsumerStatefulWidget {
  const PasienApotekSearch({super.key});

  @override
  ConsumerState<PasienApotekSearch> createState() => _PasienApotekSearchState();
}

class _PasienApotekSearchState extends ConsumerState<PasienApotekSearch> {
  final SupabaseService _db = SupabaseService();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isLoading = true;

  // List of pharmacies
  List<Map<String, dynamic>> _allApotek = [];

  @override
  void initState() {
    super.initState();
    _loadPharmacies();
  }

  Future<void> _loadPharmacies() async {
    setState(() => _isLoading = true);
    try {
      final fetched = await _db.fetchAllPharmacies();
      if (fetched.isNotEmpty) {
        final List<Map<String, dynamic>> list = fetched.map((p) {
          final name = p['nama_faskes'] ?? p['name'] ?? 'Apotek';
          final address = p['address'] ?? '';
          return {
            'id': p['id'],
            'name': name,
            'address': address,
            'fullAddress': address.isNotEmpty ? address : 'Bondowoso, Jawa Timur',
            'jamBuka': p['jam_kerja'] ?? '08:00 - 21:00',
            'isOpen': true,
            'verified': p['is_visible'] ?? true,
            'imageUrl': p['avatar_url'],
            'initials': name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'AP',
            'avatarBg': const Color(0xFF0F9D58),
            'raw': p,
          };
        }).toList();
        if (mounted) {
          setState(() {
            _allApotek = list;
            _isLoading = false;
          });
        }
        return;
      }
    } catch (_) {}

    // Fallback data
    if (mounted) {
      setState(() {
        _allApotek = [
          {
            'id': '1',
            'name': 'CyrenElysia~♪',
            'address': 'Kel. KEJAYAN, Kec. PUJER...',
            'fullAddress':
                'Kel. KEJAYAN, Kec. PUJER, KABUPATEN BONDOWOSO, Jawa Timur',
            'jamBuka': '08:00 - 21:00',
            'isOpen': true,
            'verified': true,
            'imageUrl': 'https://api.dicebear.com/7.x/shapes/png?seed=apotek1',
            'initials': 'CE',
            'avatarBg': const Color(0xFFFFB5E8),
          },
          {
            'id': '2',
            'name': 'Apotek Dani Medika',
            'address': 'Kel. LENGGONG, Kec. PASREPAN...',
            'fullAddress':
                'Kel. LENGGONG, Kec. PASREPAN, KABUPATEN PASURUAN, Jawa Timur',
            'jamBuka': '08:00 - 20:00',
            'isOpen': true,
            'verified': true,
            'imageUrl': null,
            'initials': 'DA',
            'avatarBg': const Color(0xFFE74C3C),
          },
        ];
        _isLoading = false;
      });
    }
  }

  void _openQrScanner(BuildContext context) {
    final state = ref.read(landingPageProvider);
    final isDark = state.appearance == 'dark';
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (ctx) => PasienQrScannerDialog(
        onApotekScanned: (apotek) {
          _showApotekPos(context, apotek);
        },
        onDoctorScanned: (doctor) {
          showDialog(
            context: context,
            barrierColor: Colors.black.withOpacity(0.45),
            builder: (dCtx) => DoctorDetailDialog(
              dokter: doctor,
              isDark: isDark,
              initialTabIndex: 1,
            ),
          );
        },
      ),
    );
  }

  void _showApotekPos(BuildContext context, Map<String, dynamic> apotek) {
    final state = ref.read(landingPageProvider);
    final isDark = state.appearance == 'dark';
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (ctx) => PasienApotekPosDialog(
        pharmacy: apotek['raw'] ?? apotek,
        isDark: isDark,
      ),
    );
  }

  List<Map<String, dynamic>> get _filteredApotek {
    return _allApotek.where((a) {
      final q = _searchQuery.toLowerCase();
      final nameMatch = a['name'].toString().toLowerCase().contains(q);
      final addressMatch = a['fullAddress'].toString().toLowerCase().contains(q);
      return q.isEmpty || nameMatch || addressMatch;
    }).toList();
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
    final isRev = state.appearance == 'rev';
    final notifier = ref.read(landingPageProvider.notifier);
    final bgColor = notifier.getBackgroundColor();
    final cardBgColor = notifier.getCardColor();
    final textColor = notifier.getTextColor();
    final subtitleColor = notifier.getBodyTextColor();
    final borderColor = notifier.getBorderColor();
    final inputBg = isDark ? const Color(0xFF1E1E22) : const Color(0xFFF8FAFD);
    final themeAccent = notifier.getPrimaryColor();
    final purpleAccent = notifier.getPrimaryColor();

    final isMobile = MediaQuery.of(context).size.width < 768;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ─── Hero Header ──────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF1E1E22), const Color(0xFF161619)]
                  : [const Color(0xFFF0F5FF), const Color(0xFFEAF9F6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            children: [
              // Icon
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: themeAccent.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.local_pharmacy_rounded,
                  color: themeAccent,
                  size: 28,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                isEn ? 'Find Nearby Pharmacies' : 'Cari Apotek Terdekat',
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                isEn
                    ? 'Redeem your digital prescriptions at Mapotech network pharmacies'
                    : 'Tebus resep digital Anda di apotek jejaring Mapotek',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(fontSize: 12, color: subtitleColor),
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: () => _openQrScanner(context),
                icon: const Icon(Icons.qr_code_scanner_rounded, size: 16),
                label: Text(
                  isEn ? 'Scan Pharmacy / POS QR' : 'Scan QR Apotek / POS',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeAccent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // ─── Search Field ─────────────────────────────────────────
        Container(
          height: 56,
          decoration: BoxDecoration(
            color: cardBgColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            children: [
              Icon(
                Icons.search_rounded,
                size: 22,
                color: subtitleColor.withOpacity(0.7),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                  decoration: InputDecoration(
                    hintText: isEn
                        ? 'Search pharmacy name, street, or area...'
                        : 'Cari nama apotek, jalan, atau daerah...',
                    hintStyle: GoogleFonts.outfit(
                      fontSize: 13,
                      color: subtitleColor.withOpacity(0.5),
                    ),
                    border: InputBorder.none,
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
              ),
              if (_searchQuery.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: subtitleColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.close_rounded,
                      size: 14,
                      color: subtitleColor,
                    ),
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // ─── Results Area ─────────────────────────────────────────
        if (_searchQuery.isNotEmpty && _filteredApotek.isEmpty)
          EmptyStateWidget(
            icon: Icons.local_pharmacy_outlined,
            title: isEn ? 'Pharmacy Not Found' : 'Apotek tidak ditemukan',
            subtitle: isEn
                ? 'Try searching with another pharmacy name or district'
                : 'Coba nama apotek atau kelurahan lain',
            cardBg: cardBgColor,
            border: borderColor,
            textColor: textColor,
            subtitleColor: subtitleColor,
          )
        else ...[
          if (_searchQuery.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                isEn ? 'Results for "$_searchQuery"' : 'Hasil untuk "$_searchQuery"',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: subtitleColor,
                ),
              ),
            ),

          // Grid / List of Apotek Cards
          isMobile
              ? Column(
                  children: _filteredApotek.map((apotek) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _buildApotekCard(
                        apotek,
                        cardBgColor,
                        borderColor,
                        textColor,
                        subtitleColor,
                        themeAccent,
                      ),
                    );
                  }).toList(),
                )
              : GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 340,
                    mainAxisExtent: 170,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: _filteredApotek.length,
                  itemBuilder: (context, index) {
                    return _buildApotekCard(
                      _filteredApotek[index],
                      cardBgColor,
                      borderColor,
                      textColor,
                      subtitleColor,
                      themeAccent,
                    );
                  },
                ),
        ],
      ],
    );
  }

  Widget _buildApotekCard(
    Map<String, dynamic> apotek,
    Color cardBg,
    Color border,
    Color text,
    Color subtitle,
    Color accent,
  ) {
    final Color avatarBg = apotek['avatarBg'] as Color;
    final bool isOpen = apotek['isOpen'] as bool;
    final bool verified = apotek['verified'] as bool;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _showApotekPos(context, apotek),
        child: Container(
          padding: const EdgeInsets.all(16),
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
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: avatarBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: apotek['imageUrl'] != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.network(
                          apotek['imageUrl'],
                          width: 52,
                          height: 52,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Text(
                            apotek['initials'],
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      )
                    : Text(
                        apotek['initials'],
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
              ),
              const SizedBox(width: 14),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Open/Closed indicator
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(right: 6, top: 1),
                          decoration: BoxDecoration(
                            color: isOpen
                                ? const Color(0xFF27AE60)
                                : const Color(0xFF95A5A6),
                            shape: BoxShape.circle,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            apotek['jamBuka'],
                            style: GoogleFonts.outfit(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: isOpen
                                  ? const Color(0xFF27AE60)
                                  : subtitle,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      apotek['name'],
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: text,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 11,
                          color: subtitle,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            apotek['address'],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              color: subtitle,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (verified)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF27AE60).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(
                            color: const Color(0xFF27AE60).withOpacity(0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.verified_rounded,
                              size: 10,
                              color: Color(0xFF27AE60),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Mapotek Verified',
                              style: GoogleFonts.outfit(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF27AE60),
                              ),
                            ),
                          ],
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
}
