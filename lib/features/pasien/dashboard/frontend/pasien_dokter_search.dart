import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapotech/features/landing/landing_page_data.dart';
import 'package:mapotech/shared/supabase_service.dart';
import 'package:mapotech/shared/widgets/empty_state_widget.dart';
import 'package:url_launcher/url_launcher.dart';

/// Cari Praktik Mandiri - Pasien Dashboard Page
class PasienDokterSearch extends ConsumerStatefulWidget {
  const PasienDokterSearch({super.key});

  @override
  ConsumerState<PasienDokterSearch> createState() => _PasienDokterSearchState();
}

class _PasienDokterSearchState extends ConsumerState<PasienDokterSearch> {
  final SupabaseService _db = SupabaseService();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'semua';

  List<Map<String, dynamic>> _allDokters = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadDoctors();
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
      setState(() {
        _allDokters = visibleDocs;
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

      // 2. Chip Filter (Semua, Dokter, Bidan)
      bool filterMatches = true;
      if (_selectedFilter == 'dokter') {
        final prof = d['profession']?.toString().toLowerCase() ?? '';
        filterMatches = prof.contains('doc') || prof.contains('dok') || prof.isEmpty;
      } else if (_selectedFilter == 'bidan') {
        final prof = d['profession']?.toString().toLowerCase() ?? '';
        filterMatches = prof.contains('bid') || prof.contains('mid') || prof.contains('nurse') || prof.contains('perawat');
      }

      return textMatches && filterMatches;
    }).toList();
  }

  void _showDoctorDetail(BuildContext context, Map<String, dynamic> dokter) {
    final state = ref.read(landingPageProvider);
    final isDark = state.appearance == 'dark';
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (ctx) => _DoctorDetailDialog(
        dokter: dokter,
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
        // Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬ Search Card Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
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
                          hintText: 'Cari praktik mandiri atau spesialis...',
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

              // Filter Row
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _buildFilterChip(
                    'Semua',
                    'semua',
                    subtitleColor,
                    purpleAccent,
                    borderColor,
                    cardBgColor,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    'Dokter',
                    'dokter',
                    subtitleColor,
                    purpleAccent,
                    borderColor,
                    cardBgColor,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    'Bidan',
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
                    'Filter Urutan',
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
        ),

        const SizedBox(height: 24),

        // Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬ Results Header Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Praktik Mandiri Tersedia',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _searchQuery.isEmpty
                      ? 'Menampilkan hasil pencarian terbaik untuk Anda'
                      : 'Hasil pencarian untuk "$_searchQuery"',
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
                    : '${_filteredDokters.length} Hasil',
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
class _DoctorDetailDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic> dokter;
  final bool isDark;

  const _DoctorDetailDialog({
    required this.dokter,
    required this.isDark,
  });

  @override
  ConsumerState<_DoctorDetailDialog> createState() => _DoctorDetailDialogState();
}

class _DoctorDetailDialogState extends ConsumerState<_DoctorDetailDialog>
    with SingleTickerProviderStateMixin {
  final SupabaseService _db = SupabaseService();
  List<Map<String, dynamic>> _schedules = [];
  bool _loadingSchedules = true;
  String? _scheduleError;

  // Booking state
  DateTime? _selectedDate;
  String? _selectedTimeSlot;
  bool _isBooking = false;
  bool _bookingSuccess = false;
  late TabController _tabController;

  // Clock picker state
  int _clockHour = -1;    // -1 = not yet selected
  int _clockMinute = -1;  // -1 = not yet selected
  bool _pickingHour = true;        // true = picking hour, false = picking minute
  List<String> _clockOpenSlots = []; // valid "HH:mm" slots from schedule


  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadSchedules();
  }

  @override
  void dispose() {
    _tabController.dispose();
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
    });
  }

  void _onClockMinuteTap(int m) {
    final slot = '${_clockHour.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
    setState(() {
      _clockMinute = m;
      _selectedTimeSlot = slot;
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
    final availableMinutes = _clockOpenSlots
        .where((s) => int.tryParse(s.split(':')[0]) == _clockHour)
        .map((s) => int.tryParse(s.split(':')[1]) ?? -1)
        .toList()
      ..sort();

    const double clockSize = 220;
    const double outerR = 86.0;
    const double innerR = 54.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: () => setState(() => _pickingHour = true),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: isHourMode ? themeAccent : sectionBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isHourMode ? themeAccent : borderColor, width: 2),
                ),
                child: Text(
                  _clockHour == -1 ? '--' : _clockHour.toString().padLeft(2, '0'),
                  style: GoogleFonts.outfit(fontSize: 30, fontWeight: FontWeight.w900,
                      color: isHourMode ? Colors.white : textColor),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(':',
                  style: GoogleFonts.outfit(fontSize: 30, fontWeight: FontWeight.w900, color: textColor)),
            ),
            GestureDetector(
              onTap: _clockHour == -1 ? null : () => setState(() => _pickingHour = false),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: !isHourMode ? themeAccent : sectionBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: !isHourMode ? themeAccent : borderColor, width: 2),
                ),
                child: Text(
                  _clockMinute == -1 ? '--' : _clockMinute.toString().padLeft(2, '0'),
                  style: GoogleFonts.outfit(fontSize: 30, fontWeight: FontWeight.w900,
                      color: !isHourMode ? Colors.white : textColor),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          isHourMode ? 'Ketuk untuk memilih jam' : 'Ketuk untuk memilih menit',
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
                'Janji temu Anda telah dibuat.\nSilakan datang sesuai jadwal yang dipilih.',
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
          const SizedBox(height: 12),
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
              onPressed: _isBooking ? null : _submitBooking,
              icon: _isBooking
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check_circle_rounded, size: 16, color: Colors.white),
              label: Text(
                _isBooking ? 'Memproses...' : 'Konfirmasi Booking',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: themeAccent,
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

  Future<void> _submitBooking() async {
    final user = ref.read(landingPageProvider).loggedInUser;
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

    setState(() => _isBooking = true);
    try {
      await _db.createBooking(
        doctorId: widget.dokter['id'] as String,
        patientId: user['id'] as String,
        date: _selectedDate!,
      );
      if (mounted) {
        setState(() {
          _isBooking = false;
          _bookingSuccess = true;
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

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : (MediaQuery.of(context).size.width - dialogWidth) / 2,
        vertical: 40,
      ),
      backgroundColor: Colors.transparent,
      child: Container(
        width: dialogWidth,
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(28),
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
            // Ã¢â€â‚¬Ã¢â€â‚¬ Header Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
            Container(
              padding: const EdgeInsets.fromLTRB(24, 24, 16, 0),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: appearance == 'rev'
                      ? const [Color(0xFFCB8FFF), Color(0xFFB577F2)]
                      : (isDark
                          ? const [Color(0xFF3A3A40), Color(0xFF252528)]
                          : [themeAccent, themeAccent.withOpacity(0.8)]),
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
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
                              style: GoogleFonts.outfit(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
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
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Ã¢â€â‚¬Ã¢â€â‚¬ Tab Bar Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
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

            // Ã¢â€â‚¬Ã¢â€â‚¬ Tab Content Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬Ã¢â€â‚¬
            Flexible(
              child: TabBarView(
                controller: _tabController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  // TAB 1 Ã¢â‚¬â€ Detail
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
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                        color: Colors.white),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF27AE60),
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12)),
                                    elevation: 0,
                                  ),
                                ),
                              ),
                            if (widget.dokter['whatsapp_number'] != null &&
                                widget.dokter['whatsapp_number'].toString().isNotEmpty &&
                                _hasMapsLink())
                              const SizedBox(width: 12),
                            if (_hasMapsLink())
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _launchMaps,
                                  icon: Icon(Icons.map_outlined, size: 16, color: themeAccent),
                                  label: Text(
                                    'Buka Peta',
                                    style: GoogleFonts.outfit(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                        color: themeAccent),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(color: themeAccent, width: 1.5),
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if ((widget.dokter['whatsapp_number'] != null &&
                                widget.dokter['whatsapp_number'].toString().isNotEmpty) ||
                            _hasMapsLink())
                          const SizedBox(height: 24),

                        // Tentang Praktik
                        _buildSectionHeader(
                            'Tentang Praktik', Icons.info_outline_rounded, themeAccent, textColor),
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
                                widget.dokter['about'] != null &&
                                        widget.dokter['about'].toString().trim().isNotEmpty
                                    ? widget.dokter['about']
                                    : 'Praktik Mandiri ${widget.dokter['name']} siap melayani konsultasi dan pemeriksaan medis umum.',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  color: subtitleColor,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.location_on_outlined, size: 16, color: themeAccent),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _formatFullAddress(),
                                      style: GoogleFonts.outfit(
                                        fontSize: 11,
                                        color: subtitleColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Informasi Layanan (BPJS only, no tarif)
                        _buildSectionHeader(
                            'Informasi Layanan',
                            Icons.medical_services_outlined,
                            themeAccent,
                            textColor),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: sectionBg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: borderColor),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                widget.dokter['is_bpjs'] == true
                                    ? Icons.verified_rounded
                                    : Icons.info_outline_rounded,
                                size: 18,
                                color: widget.dokter['is_bpjs'] == true
                                    ? const Color(0xFF27AE60)
                                    : subtitleColor,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                widget.dokter['is_bpjs'] == true
                                    ? 'Melayani BPJS'
                                    : 'Pasien Umum',
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  color: widget.dokter['is_bpjs'] == true
                                      ? const Color(0xFF27AE60)
                                      : textColor,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Statistik Pasien
                        _buildSectionHeader(
                            'Statistik Pasien',
                            Icons.people_alt_outlined,
                            themeAccent,
                            textColor),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: sectionBg,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: borderColor),
                                ),
                                child: Column(
                                  children: [
                                    Icon(Icons.how_to_reg_rounded, size: 22, color: themeAccent),
                                    const SizedBox(height: 6),
                                    Text(
                                      '${widget.dokter['finished_total'] ?? 0}',
                                      style: GoogleFonts.outfit(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w900,
                                        color: textColor,
                                      ),
                                    ),
                                    Text(
                                      'Total Diperiksa',
                                      style: GoogleFonts.outfit(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: subtitleColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: sectionBg,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: borderColor),
                                ),
                                child: Column(
                                  children: [
                                    Icon(Icons.today_rounded, size: 22, color: const Color(0xFF27AE60)),
                                    const SizedBox(height: 6),
                                    Text(
                                      '${widget.dokter['active_today'] ?? 0}',
                                      style: GoogleFonts.outfit(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w900,
                                        color: textColor,
                                      ),
                                    ),
                                    Text(
                                      'Pasien Hari Ini',
                                      style: GoogleFonts.outfit(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: subtitleColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
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

                        const SizedBox(height: 20),
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
    );
  }
}

