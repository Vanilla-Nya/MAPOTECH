import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapotech/features/landing/landing_page_data.dart';
import 'package:mapotech/shared/supabase_service.dart';
import 'package:mapotech/shared/widgets/ui.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mapotech/features/dokter/dashboard/frontend/web_map_widget.dart';

/// Cari Puskesmas & Faskes Publik - Pasien Dashboard Page
class PasienPuskesmasSearch extends ConsumerStatefulWidget {
  const PasienPuskesmasSearch({super.key});

  @override
  ConsumerState<PasienPuskesmasSearch> createState() => _PasienPuskesmasSearchState();
}

class _PasienPuskesmasSearchState extends ConsumerState<PasienPuskesmasSearch> {
  final SupabaseService _db = SupabaseService();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'semua';

  List<Map<String, dynamic>> _allPuskesmas = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPuskesmas();
  }

  Future<void> _loadPuskesmas() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      final list = await _db.fetchAllPuskesmas();
      setState(() {
        _allPuskesmas = list.where((p) => p['is_visible'] != false).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredPuskesmas {
    return _allPuskesmas.where((p) {
      // 1. Text Search
      final q = _searchQuery.toLowerCase();
      final nameMatch = p['name'].toString().toLowerCase().contains(q);
      final facilityMatch = (p['facility_name'] ?? '').toString().toLowerCase().contains(q);
      final addressMatch = (p['address'] ?? '').toString().toLowerCase().contains(q);
      final subDistrictMatch = (p['sub_district'] ?? '').toString().toLowerCase().contains(q);
      final villageMatch = (p['village'] ?? '').toString().toLowerCase().contains(q);
      final textMatches = q.isEmpty || nameMatch || facilityMatch || addressMatch || subDistrictMatch || villageMatch;

      // 2. Chip Filter (Semua, Puskesmas, Ponkesdes, Pustu)
      bool filterMatches = true;
      final type = (p['type'] ?? p['profession'] ?? '').toString().toLowerCase();
      if (_selectedFilter == 'puskesmas') {
        filterMatches = type.contains('pusk') || type == 'puskesmas';
      } else if (_selectedFilter == 'ponkesdes') {
        filterMatches = type.contains('ponk') || type == 'ponkesdes' || type.contains('village');
      } else if (_selectedFilter == 'pustu') {
        filterMatches = type.contains('pustu') || type == 'pustu';
      }

      return textMatches && filterMatches;
    }).toList();
  }

  void _showPuskesmasDetail(BuildContext context, Map<String, dynamic> puskesmas) {
    final state = ref.read(landingPageProvider);
    final isDark = state.appearance == 'dark';
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) => PuskesmasDetailDialog(
        puskesmas: puskesmas,
        isDark: isDark,
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
    final themeAccent = const Color(0xFF48C9B0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ─── Hero Header / Search Card ─────────────────────────────
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
              CustomSearchBar(
                controller: _searchController,
                hintText: isEn
                    ? 'Search nearby health centers, ponkesdes, or pustu...'
                    : 'Cari puskesmas, ponkesdes, atau pustu terdekat...',
                backgroundColor: inputBg,
                borderColor: borderColor,
                textColor: textColor,
                hintColor: subtitleColor,
                iconColor: subtitleColor,
                height: 52,
                onChanged: (val) => setState(() => _searchQuery = val),
                onClear: () => setState(() => _searchQuery = ''),
              ),

              const SizedBox(height: 14),

              // Filter Row
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  CustomFilterChip<String>(
                    label: isEn ? 'All' : 'Semua',
                    value: 'semua',
                    selectedValue: _selectedFilter,
                    activeColor: themeAccent,
                    inactiveBgColor: cardBgColor,
                    inactiveTextColor: subtitleColor,
                    borderColor: borderColor,
                    onSelected: (val) => setState(() => _selectedFilter = val),
                  ),
                  const SizedBox(width: 8),
                  CustomFilterChip<String>(
                    label: 'Puskesmas',
                    value: 'puskesmas',
                    selectedValue: _selectedFilter,
                    activeColor: themeAccent,
                    inactiveBgColor: cardBgColor,
                    inactiveTextColor: subtitleColor,
                    borderColor: borderColor,
                    onSelected: (val) => setState(() => _selectedFilter = val),
                  ),
                  const SizedBox(width: 8),
                  CustomFilterChip<String>(
                    label: 'Ponkesdes',
                    value: 'ponkesdes',
                    selectedValue: _selectedFilter,
                    activeColor: themeAccent,
                    inactiveBgColor: cardBgColor,
                    inactiveTextColor: subtitleColor,
                    borderColor: borderColor,
                    onSelected: (val) => setState(() => _selectedFilter = val),
                  ),
                  const SizedBox(width: 8),
                  CustomFilterChip<String>(
                    label: 'Pustu',
                    value: 'pustu',
                    selectedValue: _selectedFilter,
                    activeColor: themeAccent,
                    inactiveBgColor: cardBgColor,
                    inactiveTextColor: subtitleColor,
                    borderColor: borderColor,
                    onSelected: (val) => setState(() => _selectedFilter = val),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // ─── Results Header ────────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEn
                      ? 'Community Healthcare Facilities'
                      : 'Fasilitas Pelayanan Kesehatan Masyarakat',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _searchQuery.isEmpty
                      ? (isEn
                          ? 'Nearby government healthcare network'
                          : 'Puskesmas, Ponkesdes, dan Pustu jejaring pemerintah terdekat')
                      : (isEn ? 'Search results for "$_searchQuery"' : 'Hasil pencarian untuk "$_searchQuery"'),
                  style: GoogleFonts.outfit(fontSize: 11, color: subtitleColor),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: themeAccent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                _isLoading
                    ? '...'
                    : (isEn ? '${_filteredPuskesmas.length} Results' : '${_filteredPuskesmas.length} Hasil'),
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: themeAccent,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // ─── Puskesmas List ────────────────────────────────────────
        if (_isLoading)
          CustomPageLoader(
            message: state.language == 'en'
                ? 'Loading Puskesmas & Clinic directory...'
                : 'Memuat data faskes Puskesmas & Klinik...',
            skeleton: const SkeletonPatientGrid(),
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
                    'Gagal memuat data puskesmas',
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
                    onPressed: _loadPuskesmas,
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
        else if (_filteredPuskesmas.isEmpty)
          EmptyStateWidget(
            icon: Icons.domain_disabled_rounded,
            title: 'Tidak ada puskesmas ditemukan',
            subtitle: 'Coba kata kunci lain atau pilih filter Semua',
            cardBg: cardBgColor,
            border: borderColor,
            textColor: textColor,
            subtitleColor: subtitleColor,
          )
        else
          Column(
            children: _filteredPuskesmas.map((puskesmas) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _buildPuskesmasCard(
                  puskesmas,
                  cardBgColor,
                  borderColor,
                  textColor,
                  subtitleColor,
                  themeAccent,
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildPuskesmasCard(
    Map<String, dynamic> puskesmas,
    Color cardBg,
    Color border,
    Color text,
    Color subtitle,
    Color accent,
  ) {
    final name = (puskesmas['name'] ?? puskesmas['facility_name'] ?? 'Puskesmas').toString();
    final type = (puskesmas['type'] ?? puskesmas['profession'] ?? 'Puskesmas').toString();
    final address = (puskesmas['address'] ?? '').toString();
    final isBpjs = puskesmas['is_bpjs'] == true;

    // Initials logic
    String initials = 'PS';
    if (type.toLowerCase().contains('ponk')) {
      initials = 'PK';
    } else if (type.toLowerCase().contains('pustu')) {
      initials = 'PU';
    } else {
      final parts = name.split(' ').where((p) => p.isNotEmpty).toList();
      if (parts.length >= 2) {
        initials = (parts[0][0] + parts[1][0]).toUpperCase();
      } else if (parts.isNotEmpty) {
        initials = parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
      }
    }

    final Color typeColor = type.toLowerCase().contains('ponk')
        ? const Color(0xFF1ABC9C)
        : (type.toLowerCase().contains('pustu')
            ? const Color(0xFF3498DB)
            : const Color(0xFF48C9B0));

    return InkWell(
      onTap: () => _showPuskesmasDetail(context, puskesmas),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
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
                color: typeColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(color: typeColor.withValues(alpha: 0.3), width: 2),
              ),
              alignment: Alignment.center,
              child: ClipOval(
                child: (puskesmas['avatar_url'] != null &&
                        (puskesmas['avatar_url'] as String).isNotEmpty)
                    ? Image.network(
                        puskesmas['avatar_url']!,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Text(
                          initials,
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: typeColor,
                          ),
                        ),
                      )
                    : Text(
                        initials,
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: typeColor,
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
                    name,
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
                        Icons.domain_rounded,
                        size: 12,
                        color: typeColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        type,
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          color: typeColor,
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
                          address.isNotEmpty ? address : 'Kecamatan Pujer, Kabupaten Bondowoso',
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
                        type,
                        Icons.local_hospital_rounded,
                        typeColor,
                      ),
                      if (isBpjs)
                        _buildInfoChip(
                          'Melayani BPJS',
                          Icons.verified_rounded,
                          const Color(0xFF27AE60),
                        ),
                      _buildInfoChip(
                        'Integrasi ILP',
                        Icons.hub_rounded,
                        const Color(0xFF3498DB),
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
                color: typeColor.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: typeColor,
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
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: color.withValues(alpha: 0.2)),
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

/// Puskesmas Detail Modal Dialog
class PuskesmasDetailDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic> puskesmas;
  final bool isDark;

  const PuskesmasDetailDialog({
    super.key,
    required this.puskesmas,
    required this.isDark,
  });

  @override
  ConsumerState<PuskesmasDetailDialog> createState() => _PuskesmasDetailDialogState();
}

class _PuskesmasDetailDialogState extends ConsumerState<PuskesmasDetailDialog> {
  final double _zoomLevel = 15.0;

  String _getMapEmbedUrl(String inputLink) {
    if (inputLink.isEmpty) {
      final name = widget.puskesmas['name']?.toString() ?? '';
      final address = widget.puskesmas['address']?.toString() ?? '';
      final village = widget.puskesmas['village']?.toString() ?? '';
      final subDistrict = widget.puskesmas['sub_district']?.toString() ?? '';
      final district = widget.puskesmas['district']?.toString() ?? '';
      final province = widget.puskesmas['province']?.toString() ?? '';

      final queryParts = [
        if (name.isNotEmpty) name,
        if (address.isNotEmpty && address != name) address,
        if (village.isNotEmpty) village,
        if (subDistrict.isNotEmpty) subDistrict,
        if (district.isNotEmpty) district,
        if (province.isNotEmpty) province,
      ];
      final query = queryParts.join(', ');
      return 'https://maps.google.com/maps?q=${Uri.encodeComponent(query.isNotEmpty ? query : "Puskesmas, Bondowoso")}&t=&z=${_zoomLevel.toInt()}&ie=UTF8&iwloc=&output=embed';
    }

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

    if (inputLink.startsWith('http://') || inputLink.startsWith('https://')) {
      if (inputLink.contains('output=embed') || inputLink.contains('/embed/')) {
        return inputLink;
      }
      return 'https://maps.google.com/maps?q=${Uri.encodeComponent(inputLink)}&t=&z=${_zoomLevel.toInt()}&ie=UTF8&iwloc=&output=embed';
    }

    return 'https://maps.google.com/maps?q=${Uri.encodeComponent(inputLink)}&t=&z=${_zoomLevel.toInt()}&ie=UTF8&iwloc=&output=embed';
  }

  void _launchWhatsApp(String phone) async {
    if (phone.isEmpty) return;
    String cleanNumber = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanNumber.startsWith('0')) {
      cleanNumber = '62${cleanNumber.substring(1)}';
    }
    final url = Uri.parse('https://wa.me/$cleanNumber');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  void _launchPhoneCall(String phone) async {
    if (phone.isEmpty) return;
    final url = Uri.parse('tel:$phone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  void _openGoogleMaps(String mapsLink) async {
    if (mapsLink.isNotEmpty) {
      final url = Uri.parse(mapsLink);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
        return;
      }
    }
    final name = widget.puskesmas['name']?.toString() ?? 'Puskesmas';
    final fallbackUrl = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(name)}');
    if (await canLaunchUrl(fallbackUrl)) {
      await launchUrl(fallbackUrl, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final notifier = ref.read(landingPageProvider.notifier);
    final cardBgColor = notifier.getCardColor();
    final textColor = notifier.getTextColor();
    final subtitleColor = notifier.getBodyTextColor();
    final borderColor = notifier.getBorderColor();
    final themeAccent = const Color(0xFF48C9B0);

    final name = (widget.puskesmas['name'] ?? widget.puskesmas['facility_name'] ?? 'Puskesmas').toString();
    final type = (widget.puskesmas['type'] ?? widget.puskesmas['profession'] ?? 'Puskesmas').toString();
    final address = (widget.puskesmas['address'] ?? '').toString();
    final phone = (widget.puskesmas['whatsapp_number'] ?? '').toString();
    final mapsLink = (widget.puskesmas['google_maps_link'] ?? '').toString();
    final about = (widget.puskesmas['about'] ?? '').toString();
    final isBpjs = widget.puskesmas['is_bpjs'] == true;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        width: 700,
        constraints: const BoxConstraints(maxHeight: 780),
        decoration: BoxDecoration(
          color: cardBgColor,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Column(
            children: [
              // Header Banner
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF1E3A34), const Color(0xFF132723)]
                        : [const Color(0xFF7BE5D3), const Color(0xFF48C9B0)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.domain_rounded,
                        color: Color(0xFF48C9B0),
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            type.toUpperCase(),
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Colors.white.withValues(alpha: 0.8),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                      splashRadius: 20,
                    ),
                  ],
                ),
              ),

              // Content Body
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Badge info row
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (isBpjs)
                            _buildDetailBadge(
                              'Melayani BPJS Kesehatan',
                              Icons.verified_rounded,
                              const Color(0xFF27AE60),
                              isDark,
                            ),
                          _buildDetailBadge(
                            'Integrasi SatuSehat & ILP',
                            Icons.cloud_done_rounded,
                            const Color(0xFF3498DB),
                            isDark,
                          ),
                          _buildDetailBadge(
                            'Jejaring Dinkes',
                            Icons.security_rounded,
                            const Color(0xFFE67E22),
                            isDark,
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // About Section
                      Text(
                        'Tentang Fasilitas Pelayanan',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E1E22) : const Color(0xFFF8FAFD),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: borderColor),
                        ),
                        child: Text(
                          about.isNotEmpty
                              ? about
                              : '$name merupakan Pusat Kesehatan Masyarakat yang siap memberikan pelayanan kesehatan tingkat pertama yang komprehensif, bermutu, dan terjangkau untuk seluruh masyarakat.',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: subtitleColor,
                            height: 1.5,
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Clusters / Services Section
                      Text(
                        'Cluster & Layanan Terintegrasi',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 10),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 3.2,
                        children: [
                          _buildClusterTile('Cluster 1: Manajemen & Tata Kelola', Icons.business_center_rounded, const Color(0xFF3498DB), isDark),
                          _buildClusterTile('Cluster 2: Ibu, Anak & Remaja (KIA)', Icons.child_care_rounded, const Color(0xFFE91E63), isDark),
                          _buildClusterTile('Cluster 3: Usia Dewasa & Lansia (PTM)', Icons.elderly_rounded, const Color(0xFF9B59B6), isDark),
                          _buildClusterTile('Lintas Cluster: UGD, Lab & Farmasi', Icons.hub_rounded, const Color(0xFFE67E22), isDark),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Location & Map Section
                      Text(
                        'Lokasi & Peta',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.location_on_outlined, size: 16, color: themeAccent),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              address.isNotEmpty ? address : 'Kecamatan Pujer, Kabupaten Bondowoso, Jawa Timur',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                color: subtitleColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          height: 180,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: borderColor),
                          ),
                          child: kIsWeb
                              ? buildWebMapWidget(
                                  mapUrl: _getMapEmbedUrl(mapsLink),
                                  isDark: isDark,
                                )
                              : Container(
                                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                  alignment: Alignment.center,
                                  child: Text(
                                    name,
                                    style: GoogleFonts.outfit(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: textColor,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom Action Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                decoration: BoxDecoration(
                  color: cardBgColor,
                  border: Border(top: BorderSide(color: borderColor)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (phone.isNotEmpty) ...[
                      OutlinedButton.icon(
                        icon: const Icon(Icons.phone_rounded, size: 16),
                        label: Text('Telepon', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: themeAccent,
                          side: BorderSide(color: themeAccent),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => _launchPhoneCall(phone),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.chat_rounded, size: 16),
                        label: Text('WhatsApp', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => _launchWhatsApp(phone),
                      ),
                      const SizedBox(width: 8),
                    ],
                    ElevatedButton.icon(
                      icon: const Icon(Icons.directions_rounded, size: 16),
                      label: Text('Petunjuk Arah', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: themeAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => _openGoogleMaps(mapsLink),
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

  Widget _buildDetailBadge(String text, IconData icon, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.18 : 0.1),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            text,
            style: GoogleFonts.outfit(
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClusterTile(String title, IconData icon, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white70 : const Color(0xFF1B0C3C),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
