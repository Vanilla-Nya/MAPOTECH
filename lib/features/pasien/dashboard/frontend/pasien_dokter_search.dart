import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapotech/features/landing/landing_page_data.dart';
import 'package:mapotech/shared/widgets/empty_state_widget.dart';

/// Cari Praktik Mandiri - Pasien Dashboard Page
class PasienDokterSearch extends ConsumerStatefulWidget {
  const PasienDokterSearch({super.key});

  @override
  ConsumerState<PasienDokterSearch> createState() => _PasienDokterSearchState();
}

class _PasienDokterSearchState extends ConsumerState<PasienDokterSearch> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'semua';

  // Mock data matching the screenshot
  final List<Map<String, dynamic>> _allDokters = [
    {
      'id': '1',
      'name': 'dr. Agoes Soetanto',
      'role': 'Dokter',
      'clinic': 'Dokter Praktek Mandiri Dokter Agoes Soetanto, dr. KEJAYAN...',
      'address': 'Kec. KEJAYAN, Kab. PASURUAN, Jawa Timur',
      'totalPasien': 6,
      'totalAntrian': 0,
      'menerimaBpjs': true,
      'initials': 'AS',
      'verified': true,
    },
  ];

  List<Map<String, dynamic>> get _filteredDokters {
    return _allDokters.where((d) {
      final q = _searchQuery.toLowerCase();
      final nameMatch = d['name'].toString().toLowerCase().contains(q);
      final clinicMatch = d['clinic'].toString().toLowerCase().contains(q);
      return q.isEmpty || nameMatch || clinicMatch;
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

    final isDark = state.appearance == 'dark';
    final isRev = state.appearance == 'rev';
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
        // ─── Search Card ───────────────────────────────────────────
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

        // ─── Results Header ─────────────────────────────────────────
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
                '${_filteredDokters.length} Hasil',
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

        // ─── Dokter List ─────────────────────────────────────────────
        if (_filteredDokters.isEmpty)
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
    return Container(
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
              child: Image.network(
                'https://api.dicebear.com/7.x/avataaars/png?seed=agoes',
                width: 56,
                height: 56,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Text(
                  dokter['initials'],
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: accent,
                  ),
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
                      dokter['role'],
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
                        dokter['clinic'],
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
                      '${dokter['totalPasien']} Pasien · ${dokter['totalAntrian']} antrian',
                      Icons.people_outline_rounded,
                      accent,
                    ),
                    _buildInfoChip(
                      dokter['role'],
                      Icons.person_outline_rounded,
                      purple,
                    ),
                    if (dokter['menerimaBpjs'] == true)
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
