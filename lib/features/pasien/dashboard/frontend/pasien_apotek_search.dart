import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapotech/features/landing/landing_page_data.dart';
import 'package:mapotech/shared/widgets/empty_state_widget.dart';

/// Cari Apotek - Pasien Dashboard Page
class PasienApotekSearch extends ConsumerStatefulWidget {
  const PasienApotekSearch({super.key});

  @override
  ConsumerState<PasienApotekSearch> createState() => _PasienApotekSearchState();
}

class _PasienApotekSearchState extends ConsumerState<PasienApotekSearch> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Mock data matching the screenshot
  final List<Map<String, dynamic>> _allApotek = [
    {
      'id': '1',
      'name': 'CyrenElysia~♪',
      'address': 'Kel. KEJAYAN, Kec. PUER...',
      'fullAddress':
          'Kel. KEJAYAN, Kec. PUERPO, KABUPATEN PASURUAN, Jawa Timur',
      'jamBuka': 'Jam buka tidak diatur',
      'isOpen': false,
      'verified': true,
      'imageUrl': 'https://api.dicebear.com/7.x/shapes/png?seed=apotek1',
      'initials': 'CE',
      'avatarBg': const Color(0xFFFFB5E8),
    },
    {
      'id': '2',
      'name': 'Dani',
      'address': 'Kel. LENGGONG, Kec...',
      'fullAddress':
          'Kel. LENGGONG, Kec. PASREPAN, KABUPATEN PASURUAN, Jawa Timur',
      'jamBuka': 'Jam buka tidak diatur',
      'isOpen': false,
      'verified': true,
      'imageUrl': null,
      'initials': 'DA',
      'avatarBg': const Color(0xFFE74C3C),
    },
  ];

  List<Map<String, dynamic>> get _filteredApotek {
    return _allApotek.where((a) {
      final q = _searchQuery.toLowerCase();
      final nameMatch = a['name'].toString().toLowerCase().contains(q);
      final addressMatch = a['fullAddress'].toString().toLowerCase().contains(
        q,
      );
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
                'Cari Apotek Terdekat',
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Tebus resep digital Anda di apotek jejaring Mapotek',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(fontSize: 12, color: subtitleColor),
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
                    hintText: 'Cari nama apotek, jalan, atau daerah...',
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
            title: 'Apotek tidak ditemukan',
            subtitle: 'Coba nama apotek atau kelurahan lain',
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
                'Hasil untuk "$_searchQuery"',
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
        onTap: () {},
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
