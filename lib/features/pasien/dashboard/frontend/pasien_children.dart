import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapotech/features/landing/landing_page_data.dart';
import 'package:mapotech/shared/widgets/ui.dart';
import 'package:mapotech/features/puskesmas/dlc/vitascale/pages/vitascale_child_history_page.dart';
import 'package:mapotech/features/pasien/dashboard/frontend/ai_assistant/presentation/ai_chat_provider.dart';
import 'package:mapotech/features/pasien/dashboard/frontend/application/pasien_children_service.dart';

export 'package:mapotech/features/pasien/dashboard/frontend/application/pasien_children_service.dart';

// ─── Main Screen Widget ───────────────────────────────────────────────────────

class PasienChildren extends ConsumerStatefulWidget {
  final Function(String menu)? onNavigate;
  const PasienChildren({super.key, this.onNavigate});

  @override
  ConsumerState<PasienChildren> createState() => _PasienChildrenState();
}

class _PasienChildrenState extends ConsumerState<PasienChildren> {
  bool _isLoading = true;
  String? _errorMessage;
  List<PasienChildModel> _allChildren = [];
  String _selectedCategoryFilter = 'Semua';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadChildrenData();
  }

  Future<void> _loadChildrenData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = ref.read(landingPageProvider).loggedInUser;
      final enriched = await PasienChildrenService.fetchFullFamilyMembersForUser(user);

      if (mounted) {
        setState(() {
          _allChildren = enriched;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }
  Color _getAvatarColor(String name) {
    final colors = [
      const Color(0xFFF1948A), // Pink
      const Color(0xFFC39BD3), // Purple
      const Color(0xFF7FB3D5), // Soft Blue
      const Color(0xFF76D7C4), // Soft Teal
      const Color(0xFFF7DC6F), // Soft Yellow
      const Color(0xFFF5B041), // Soft Orange
      const Color(0xFF85929E), // Greyish Blue
    ];
    if (name.isEmpty) return colors[0];
    int hash = 0;
    for (int i = 0; i < name.length; i++) {
      hash = name.codeUnitAt(i) + ((hash << 5) - hash);
    }
    return colors[hash.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(landingPageProvider);
    final notifier = ref.read(landingPageProvider.notifier);
    final isEn = state.language == 'en';
    final isDark = state.appearance == 'dark';
    final isRev = state.appearance == 'rev';
    final lang = state.language;

    final themeAccent = notifier.getPrimaryColor();
    final cardBg = notifier.getCardColor();
    final bodyText = notifier.getBodyTextColor();
    final borderColor = notifier.getBorderColor();
    final textColor = isDark ? Colors.white : const Color(0xFF1B0C3C);

    final user = state.loggedInUser;
    final noKk = (user?['no_kk'] as String? ?? '').trim();
    final hasKk = noKk.isNotEmpty;

    // Filter list
    final filteredChildren = _allChildren.where((c) {
      // Filter kategori
      if (_selectedCategoryFilter == 'Balita' && !c.isBalita) return false;
      if (_selectedCategoryFilter == 'Bayi' && !c.isUnder24Months) return false;
      if (_selectedCategoryFilter == 'Anak' && (!c.isChild || c.isBalita)) return false;
      if (_selectedCategoryFilter == 'Dewasa' && !c.isAdult) return false;

      // Filter pencarian
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchName = c.name.toLowerCase().contains(q);
        final matchNik = c.nik.contains(q);
        return matchName || matchNik;
      }
      return true;
    }).toList();

    return CustomLazyLoader(
      isLoading: _isLoading,
      loadingText: isEn ? 'Loading family health records...' : 'Memuat data rekam medis keluarga...',
      loadingSubtext: isEn
          ? 'Syncing with SatuSehat & Family Card records...'
          : 'Sinkronisasi data Buku KIA & Kartu Keluarga...',
      skeleton: const SkeletonChildrenList(itemCount: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Top Header Banner ───────────────────────────────────
          _buildHeaderBanner(
            isEn: isEn,
            isDark: isDark,
            isRev: isRev,
            themeAccent: themeAccent,
            textColor: textColor,
            bodyText: bodyText,
            cardBg: cardBg,
            borderColor: borderColor,
            noKk: noKk,
            hasKk: hasKk,
          ),

          const SizedBox(height: 18),

          // ── KK Check Warning if user has NO KK ──────────────────
          if (!hasKk) ...[
            _buildNoKkWarningCard(
              isEn: isEn,
              isDark: isDark,
              themeAccent: themeAccent,
              textColor: textColor,
              bodyText: bodyText,
              cardBg: cardBg,
              borderColor: borderColor,
            ),
            const SizedBox(height: 16),
          ] else ...[
            // ── AI Consultation for Entire Family (1 KK) ───────────
            _buildAiFamilyBanner(
              isEn: isEn,
              isDark: isDark,
              themeAccent: themeAccent,
              textColor: textColor,
              bodyText: bodyText,
              cardBg: cardBg,
              borderColor: borderColor,
              user: user,
            ),
            const SizedBox(height: 16),
          ],

          // ── Search & Category Filter Chips ──────────────────────
          _buildControls(
            isEn: isEn,
            isDark: isDark,
            themeAccent: themeAccent,
            textColor: textColor,
            bodyText: bodyText,
            cardBg: cardBg,
            borderColor: borderColor,
          ),

          const SizedBox(height: 16),

          // ── Error Message if any ────────────────────────────────
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFE74C3C).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE74C3C).withValues(alpha: 0.3)),
              ),
              child: Text(
                _errorMessage!,
                style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFFE74C3C)),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── List of Family Cards or Empty State ─────────────────
          if (filteredChildren.isEmpty)
            _buildEmptyState(
              isEn: isEn,
              isDark: isDark,
              themeAccent: themeAccent,
              textColor: textColor,
              bodyText: bodyText,
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredChildren.length,
              separatorBuilder: (_, _) => const SizedBox(height: 18),
              itemBuilder: (context, index) {
                final member = filteredChildren[index];
                if (member.isAdult) {
                  return _AdultMemberCardItem(
                    member: member,
                    isEn: isEn,
                    isDark: isDark,
                    isRev: isRev,
                    lang: lang,
                    themeAccent: themeAccent,
                    cardBg: cardBg,
                    textColor: textColor,
                    bodyText: bodyText,
                    borderColor: borderColor,
                    avatarColor: _getAvatarColor(member.name),
                    onNavigate: widget.onNavigate,
                  );
                }
                return _ChildCardItem(
                  child: member,
                  isEn: isEn,
                  isDark: isDark,
                  isRev: isRev,
                  lang: lang,
                  themeAccent: themeAccent,
                  cardBg: cardBg,
                  textColor: textColor,
                  bodyText: bodyText,
                  borderColor: borderColor,
                  avatarColor: _getAvatarColor(member.name),
                  onNavigate: widget.onNavigate,
                );
              },
            ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── Header Banner ─────────────────────────────────────────────────────────
  Widget _buildHeaderBanner({
    required bool isEn,
    required bool isDark,
    required bool isRev,
    required Color themeAccent,
    required Color textColor,
    required Color bodyText,
    required Color cardBg,
    required Color borderColor,
    required String noKk,
    required bool hasKk,
  }) {
    return Container(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: themeAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.family_restroom_rounded, color: themeAccent, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          isEn ? 'My Family (Family Records)' : 'My Family (Keluarga Saya)',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: textColor,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF27AE60).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isEn ? 'FAMILY CARD' : 'KARTU KELUARGA',
                            style: GoogleFonts.outfit(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF27AE60),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isEn
                          ? 'Holistic health inspection for entire family, maternal care (MomiCare), and toddler growth (VitaScale 0-59 mo)'
                          : 'Pemantauan terpadu seluruh anggota keluarga, pemantauan kehamilan (MomiCare), dan tumbuh kembang balita (VitaScale 0–59 bulan)',
                      style: GoogleFonts.outfit(
                        fontSize: 11.5,
                        color: bodyText,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.refresh_rounded, color: themeAccent, size: 20),
                tooltip: isEn ? 'Refresh Data' : 'Muat Ulang',
                onPressed: _loadChildrenData,
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Shortcut bar to Profile
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1E1E24)
                  : (isRev ? const Color(0xFFF9F5FF) : const Color(0xFFF0FDF8)),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: themeAccent.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.badge_rounded, color: themeAccent, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    hasKk
                        ? (isEn
                            ? 'Family Card No: $noKk • ${_allChildren.length} Registered Members'
                            : 'No. Kartu Keluarga: $noKk • Terdaftar ${_allChildren.length} Anggota Keluarga')
                        : (isEn
                            ? 'No Family Card (KK) connected yet. Connect your KK to access family records.'
                            : 'Nomor Kartu Keluarga (KK) belum terhubung. Daftarkan KK untuk membuka akses keluarga.'),
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => widget.onNavigate?.call('profile'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: themeAccent,
                  ),
                  child: Text(
                    hasKk ? (isEn ? 'Manage KK' : 'Kelola KK') : (isEn ? 'Connect KK' : 'Hubungkan KK'),
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── No KK Warning Card ────────────────────────────────────────────────────
  Widget _buildNoKkWarningCard({
    required bool isEn,
    required bool isDark,
    required Color themeAccent,
    required Color textColor,
    required Color bodyText,
    required Color cardBg,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE67E22).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE67E22).withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFE67E22).withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.assignment_ind_rounded, color: Color(0xFFE67E22), size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEn ? 'Family Card (KK) Required' : 'Kartu Keluarga (KK) Diperlukan',
                  style: GoogleFonts.outfit(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFE67E22),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isEn
                      ? 'To inspect all family members and toddler records (0-59 months), please complete your KK number in Profile.'
                      : 'Untuk mengakses seluruh data keluarga dan rekam medis balita (0–59 bulan), silakan lengkapi nomor Kartu Keluarga di Profil.',
                  style: GoogleFonts.outfit(fontSize: 11, color: textColor.withValues(alpha: 0.8)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: () => widget.onNavigate?.call('profile'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE67E22),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(
              isEn ? 'Update KK' : 'Lengkapi KK',
              style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // ── AI Family Consultation Banner ─────────────────────────────────────────
  Widget _buildAiFamilyBanner({
    required bool isEn,
    required bool isDark,
    required Color themeAccent,
    required Color textColor,
    required Color bodyText,
    required Color cardBg,
    required Color borderColor,
    required Map<String, dynamic>? user,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF8E44AD).withValues(alpha: 0.12),
            themeAccent.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF8E44AD).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF8E44AD).withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF8E44AD), size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      isEn ? 'Ask Mapotech AI for Entire Family' : 'Tanya Mapotech AI untuk Seluruh Keluarga',
                      style: GoogleFonts.outfit(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8E44AD).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '1 KK',
                        style: GoogleFonts.outfit(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF8E44AD),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  isEn
                      ? 'Consult holistic nutrition, toddler milestones, and maternal health for all members in your Family Card.'
                      : 'Konsultasikan gizi balita, jadwal kontrol ibu hamil, dan gaya hidup sehat untuk seluruh anggota di 1 KK.',
                  style: GoogleFonts.outfit(fontSize: 11, color: bodyText),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: () {
              final allCtx = PasienChildrenService.createAllFamilyContext(user, _allChildren, isEn: isEn);
              final ownerName = (user?['name'] as String?) ??
                  (user?['nama_lengkap'] as String?) ??
                  (isEn ? 'Parent' : 'Bunda/Ayah');
              ref.read(aiChatProvider.notifier).selectChildContext(
                    childContext: allCtx,
                    accountOwnerName: ownerName,
                  );
              widget.onNavigate?.call('ai_assistant');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8E44AD),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.forum_rounded, size: 15),
            label: Text(
              isEn ? 'Ask AI (All)' : 'Tanya AI (Semua)',
              style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // ── Filter & Search Controls ──────────────────────────────────────────────
  Widget _buildControls({
    required bool isEn,
    required bool isDark,
    required Color themeAccent,
    required Color textColor,
    required Color bodyText,
    required Color cardBg,
    required Color borderColor,
  }) {
    return Padding(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Icon(Icons.search_rounded, size: 18, color: bodyText),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          onChanged: (val) => setState(() => _searchQuery = val.trim()),
                          style: GoogleFonts.outfit(fontSize: 12, color: textColor),
                          decoration: InputDecoration(
                            hintText: isEn ? 'Search family member name or NIK...' : 'Cari nama anggota keluarga atau NIK...',
                            hintStyle: GoogleFonts.outfit(fontSize: 12, color: bodyText.withValues(alpha: 0.6)),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              CustomButton(
                text: isEn ? 'Add Member' : 'Tambah Anggota',
                icon: Icons.person_add_alt_1_rounded,
                primaryColor: themeAccent,
                textColor: Colors.white,
                height: 42,
                onPressed: () => widget.onNavigate?.call('profile'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Category chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('Semua', isEn ? 'All Members (${_allChildren.length})' : 'Semua Anggota (${_allChildren.length})', themeAccent, textColor),
                const SizedBox(width: 8),
                _buildFilterChip('Balita', isEn ? 'Toddlers (0-59 Mo)' : 'Balita (0-59 Bln)', themeAccent, textColor),
                const SizedBox(width: 8),
                _buildFilterChip('Bayi', isEn ? 'Infants (< 24 Mo)' : 'Bayi (< 24 Bln)', themeAccent, textColor),
                const SizedBox(width: 8),
                _buildFilterChip('Anak', isEn ? 'Children' : 'Anak', themeAccent, textColor),
                const SizedBox(width: 8),
                _buildFilterChip('Dewasa', isEn ? 'Adults / Parents' : 'Orang Tua / Dewasa', themeAccent, textColor),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label, Color accent, Color textColor) {
    final isSelected = _selectedCategoryFilter == key;
    return InkWell(
      onTap: () => setState(() => _selectedCategoryFilter = key),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? accent : accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? accent : accent.withValues(alpha: 0.2)),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : textColor,
          ),
        ),
      ),
    );
  }

  // ── Empty State ───────────────────────────────────────────────────────────
  Widget _buildEmptyState({
    required bool isEn,
    required bool isDark,
    required Color themeAccent,
    required Color textColor,
    required Color bodyText,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: themeAccent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.child_care_rounded, size: 36, color: themeAccent),
            ),
            const SizedBox(height: 18),
            Text(
              isEn ? 'No Children Data Found' : 'Belum Ada Data Anak',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isEn
                  ? 'Register your children in the Family Information (KK) section under your Profile to monitor their growth and checkups.'
                  : 'Daftarkan putra/putri Anda di menu Profil pada tab Informasi Keluarga (KK) untuk memantau tumbuh kembang dan hasil periksa balita.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: bodyText,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => widget.onNavigate?.call('profile'),
              style: ElevatedButton.styleFrom(
                backgroundColor: themeAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.person_rounded, size: 16),
              label: Text(
                isEn ? 'Open Profile to Add Child' : 'Buka Profil untuk Tambah Anak',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Adult Family Member Card Item ───────────────────────────────────────────

class _AdultMemberCardItem extends ConsumerStatefulWidget {
  final PasienChildModel member;
  final bool isEn;
  final bool isDark;
  final bool isRev;
  final String lang;
  final Color themeAccent;
  final Color cardBg;
  final Color textColor;
  final Color bodyText;
  final Color borderColor;
  final Color avatarColor;
  final Function(String menu)? onNavigate;

  const _AdultMemberCardItem({
    required this.member,
    required this.isEn,
    required this.isDark,
    required this.isRev,
    required this.lang,
    required this.themeAccent,
    required this.cardBg,
    required this.textColor,
    required this.bodyText,
    required this.borderColor,
    required this.avatarColor,
    this.onNavigate,
  });

  @override
  ConsumerState<_AdultMemberCardItem> createState() => _AdultMemberCardItemState();
}

class _AdultMemberCardItemState extends ConsumerState<_AdultMemberCardItem> {
  bool _showFullNik = false;

  @override
  Widget build(BuildContext context) {
    final m = widget.member;
    final isEn = widget.isEn;
    final isMother = m.isMother;
    final isFather = m.isFather;

    final roleColor = isMother
        ? const Color(0xFFE91E63)
        : (isFather ? const Color(0xFF2980B9) : const Color(0xFF8E44AD));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: widget.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: widget.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: widget.isDark ? 0.25 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: widget.avatarColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: widget.avatarColor.withValues(alpha: 0.4), width: 1.5),
                ),
                child: Center(
                  child: Icon(
                    isMother
                        ? Icons.female_rounded
                        : (isFather ? Icons.male_rounded : Icons.person_rounded),
                    color: widget.avatarColor,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            m.name,
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: widget.textColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: roleColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: roleColor.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            m.hubungan.toUpperCase(),
                            style: GoogleFonts.outfit(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: roleColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        InkWell(
                          onTap: () => setState(() => _showFullNik = !_showFullNik),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'NIK: ${_showFullNik ? m.nik : m.maskedNik}',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  color: widget.bodyText,
                                  fontFeatures: const [FontFeature.tabularFigures()],
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                _showFullNik ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                size: 12,
                                color: widget.bodyText.withValues(alpha: 0.7),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text('•', style: TextStyle(color: widget.bodyText, fontSize: 10)),
                        const SizedBox(width: 10),
                        Text(
                          '${m.gender} • ${m.ageLabel}',
                          style: GoogleFonts.outfit(fontSize: 11, color: widget.bodyText),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Info Chips Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: widget.isDark
                  ? const Color(0xFF1E1E24)
                  : const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: widget.borderColor),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.bloodtype_rounded, size: 16, color: Colors.red.shade400),
                      const SizedBox(width: 6),
                      Text(
                        'Gol. Darah: ${m.bloodType}',
                        style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600, color: widget.textColor),
                      ),
                    ],
                  ),
                ),
                Container(height: 18, width: 1, color: widget.borderColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.verified_user_rounded, size: 16, color: Color(0xFF27AE60)),
                      const SizedBox(width: 6),
                      Text(
                        'BPJS: ${m.bpjsNumber}',
                        style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600, color: widget.textColor),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Action Buttons
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (isMother)
                ElevatedButton.icon(
                  onPressed: () => widget.onNavigate?.call('momicare_pregnancy'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE91E63),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.pregnant_woman_rounded, size: 16),
                  label: Text(
                    isEn ? 'Maternal Care (MomiCare)' : 'Pantau Kandungan (MomiCare)',
                    style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              OutlinedButton.icon(
                onPressed: () {
                  final adultCtx = ActiveChildContext(
                    childName: m.name,
                    age: m.ageLabel,
                    bb: '65 kg',
                    tb: '168 cm',
                    statusGizi: isEn ? 'Adult Health Profile' : 'Profil Kesehatan Dewasa (${m.hubungan})',
                    nutritionPlan: isEn
                        ? 'Adult balanced lifestyle, periodic checkups, and routine hydration.'
                        : 'Pola hidup seimbang, pemeriksaan berkala, dan nutrisi keluarga.',
                    childNik: m.nik,
                    isSelf: false,
                  );
                  final user = ref.read(landingPageProvider).loggedInUser;
                  final ownerName = (user?['name'] as String?) ?? (isEn ? 'Parent' : 'Bunda/Ayah');
                  ref.read(aiChatProvider.notifier).selectChildContext(
                        childContext: adultCtx,
                        accountOwnerName: ownerName,
                      );
                  widget.onNavigate?.call('ai_assistant');
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: widget.themeAccent,
                  side: BorderSide(color: widget.themeAccent.withValues(alpha: 0.4)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 15),
                label: Text(
                  isEn ? 'Ask AI About ${m.name}' : 'Tanya AI Tentang ${m.name}',
                  style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Child Card Item Component ────────────────────────────────────────────────

class _ChildCardItem extends ConsumerStatefulWidget {
  final PasienChildModel child;
  final bool isEn;
  final bool isDark;
  final bool isRev;
  final String lang;
  final Color themeAccent;
  final Color cardBg;
  final Color textColor;
  final Color bodyText;
  final Color borderColor;
  final Color avatarColor;
  final Function(String menu)? onNavigate;

  const _ChildCardItem({
    required this.child,
    required this.isEn,
    required this.isDark,
    required this.isRev,
    required this.lang,
    required this.themeAccent,
    required this.cardBg,
    required this.textColor,
    required this.bodyText,
    required this.borderColor,
    required this.avatarColor,
    this.onNavigate,
  });

  @override
  ConsumerState<_ChildCardItem> createState() => _ChildCardItemState();
}

class _ChildCardItemState extends ConsumerState<_ChildCardItem> {
  bool _isExpanded = false;
  bool _showFullNik = false;

  void _showAllVisitsDialog(BuildContext context) {
    final visits = widget.child.visitHistory;
    final isEn = widget.isEn;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: widget.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: 580,
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.history_edu_rounded, color: widget.themeAccent, size: 22),
                      const SizedBox(width: 10),
                      Text(
                        isEn ? 'Checkup History' : 'Riwayat Pemeriksaan Balita',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: widget.textColor,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: Icon(Icons.close_rounded, color: widget.bodyText),
                  ),
                ],
              ),
              Text(
                '${widget.child.name} • ${widget.child.ageLabel}',
                style: GoogleFonts.outfit(fontSize: 11.5, color: widget.bodyText),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: visits.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final v = visits[i];
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: widget.isDark
                            ? const Color(0xFF1E1E24)
                            : const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: widget.borderColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                v.visitNumber,
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: widget.textColor,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: v.statusGiziColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  v.statusGizi,
                                  style: GoogleFonts.outfit(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: v.statusGiziColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${AppTranslations.formatDate(v.visitDate, lang: widget.lang)} • ${v.examiner}',
                            style: GoogleFonts.outfit(fontSize: 10.5, color: widget.bodyText),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              _miniMetric('BB', '${v.weightKg} kg'),
                              const SizedBox(width: 14),
                              _miniMetric('TB/PB', '${v.heightCm} cm'),
                              const SizedBox(width: 14),
                              _miniMetric('Lingkar Perut', '${v.waistCm} cm'),
                              const SizedBox(width: 14),
                              _miniMetric('LiLA', '${v.lilaCm} cm'),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: widget.themeAccent.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.psychology_rounded, size: 14, color: widget.themeAccent),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: FormattedMarkdownText(
                                    text: v.parentEducation,
                                    style: GoogleFonts.outfit(
                                      fontSize: 10.5,
                                      color: widget.textColor,
                                      height: 1.4,
                                    ),
                                    boldStyle: GoogleFonts.outfit(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                      color: widget.themeAccent,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniMetric(String label, String val) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.outfit(fontSize: 9.5, color: widget.bodyText)),
        Text(val, style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: widget.textColor)),
      ],
    );
  }

  void _openAiFoodConsultationModal(
    BuildContext context,
    PasienChildModel child,
    ChildVisitRecord? last,
  ) {
    final isEn = widget.isEn;
    final themeAccent = widget.themeAccent;
    final cardBg = widget.cardBg;
    final textColor = widget.textColor;
    final bodyText = widget.bodyText;
    final borderColor = widget.borderColor;
    final isDark = widget.isDark;

    final questionController = TextEditingController();

    final presetQuestions = [
      {
        'icon': Icons.restaurant_menu_rounded,
        'title': isEn ? 'Daily Healthy Meal & Feeding Schedule' : 'Menu Makanan Harian & Jadwal Makan',
        'desc': isEn
            ? 'Get meal ideas for breakfast, lunch, and dinner tailored to ${child.name}\'s age.'
            : 'Rekomendasi porsi sarapan, makan siang, & malam sesuai usia ${child.name}.',
        'prompt': isEn
            ? 'What is the ideal daily healthy meal schedule and menu for ${child.name} (${child.ageLabel}, BB: ${last?.weightKg ?? '-'} kg, TB: ${last?.heightCm ?? '-'} cm)? Please suggest breakfast, lunch, dinner, and healthy snacks.'
            : 'Apa saja rekomendasi menu makanan harian, jadwal makan, dan porsi gizi seimbang untuk ananda ${child.name} (Usia: ${child.ageLabel}, BB: ${last?.weightKg ?? '-'} kg, TB: ${last?.heightCm ?? '-'} cm)? Mohon berikan ide menu sarapan, makan siang, dan makan malam bergizi.',
      },
      {
        'icon': Icons.egg_alt_rounded,
        'title': isEn ? 'Animal Protein Variation (Telur, Ikan, Daging)' : 'Variasi Protein Hewani Sesuai Buku KIA',
        'desc': isEn
            ? 'Guidance on local fish, eggs, poultry, and meat portions per day.'
            : 'Panduan takaran telur, ikan lokal, daging ayam, dan hati ayam per hari.',
        'prompt': isEn
            ? 'Based on the Indonesian Maternal & Child Health (KIA) handbook, what are the best local animal protein sources and portions for ${child.name} (${child.ageLabel}) to prevent growth faltering and stunting?'
            : 'Berdasarkan panduan Buku KIA Kemenkes 2024, bagaimana variasi sumber protein hewani lokal (seperti telur, ikan kembung/lele, hati ayam, daging) yang optimal untuk ${child.name} (${child.ageLabel})?',
      },
      {
        'icon': Icons.sentiment_dissatisfied_rounded,
        'title': isEn ? 'Overcoming Picky Eating (GTM)' : 'Solusi & Trik Mengatasi Anak Susah Makan (GTM)',
        'desc': isEn
            ? 'Practical tips to address food refusal and boost child appetite.'
            : 'Tips praktis menangani gerakan tutup mulut dan meningkatkan nafsu makan.',
        'prompt': isEn
            ? 'My child ${child.name} (${child.ageLabel}) is currently having trouble eating / picky eating (GTM). What are pediatrician-approved strategies and creative feeding tips to overcome this?'
            : 'Anak saya ${child.name} (${child.ageLabel}) saat ini sedang susah makan / GTM (Gerakan Tutup Mulut). Apa saja strategi dari dokter spesialis anak dan trik kreatif pemberian makan yang aman dan efektif?',
      },
      {
        'icon': Icons.fastfood_rounded,
        'title': isEn ? 'Healthy Calorie-Dense Snacks' : 'Cemilan Sehat Padat Gizi & Penambah Berat',
        'desc': isEn
            ? 'Healthy homemade snack recipes to support optimal weight gain.'
            : 'Ide camilan rumahan kaya kalori, lemak sehat, zat besi, dan zinc.',
        'prompt': isEn
            ? 'What are healthy, calorie-dense snack recipes and fruits that can support healthy weight gain for ${child.name} (${child.ageLabel}, BB: ${last?.weightKg ?? '-'} kg)?'
            : 'Apa saja resep cemilan sehat padat gizi (kaya kalori, lemak sehat, zat besi) yang aman dan cocok untuk meningkatkan berat badan ${child.name} (${child.ageLabel}, BB: ${last?.weightKg ?? '-'} kg)?',
      },
    ];

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: Container(
          width: 580,
          padding: const EdgeInsets.all(22),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: themeAccent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.auto_awesome_rounded, color: themeAccent, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEn ? 'Consult AI: Child Food & Nutrition' : 'Konsultasi AI: Gizi & Makanan Anak',
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: textColor,
                            ),
                          ),
                          Text(
                            isEn ? 'Personalized guidance based on latest checkup' : 'Panduan disesuaikan dengan rekam medis periksa terakhir',
                            style: GoogleFonts.outfit(fontSize: 10.5, color: bodyText),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: Icon(Icons.close_rounded, color: bodyText, size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Child summary pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E24) : const Color(0xFFF6F8FA),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.child_care_rounded, size: 16, color: themeAccent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${child.name} • ${child.ageLabel} • BB: ${last?.weightKg ?? '-'} kg • TB: ${last?.heightCm ?? '-'} cm • ${last?.statusGizi ?? 'Normal'}',
                          style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700, color: textColor),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Direct Chat button without consuming prompt tokens
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    onTap: () {
                      Navigator.pop(ctx);
                      _openDirectAiChat(child: child, last: last);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: themeAccent.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: themeAccent.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.chat_bubble_outline_rounded, size: 18, color: themeAccent),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              isEn
                                  ? 'Open AI Chat with ${child.name}\'s Data (0 Tokens)'
                                  : 'Buka Chat AI dengan Data ${child.name} (0 Token)',
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: themeAccent,
                              ),
                            ),
                          ),
                          Icon(Icons.arrow_forward_ios_rounded, size: 12, color: themeAccent),
                        ],
                      ),
                    ),
                  ),
                ),

                Text(
                  isEn ? 'Or select a topic / ask a custom question:' : 'Atau pilih topik / ajukan pertanyaan langsung:',
                  style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.bold, color: bodyText),
                ),
                const SizedBox(height: 10),

                // Preset options list
                ...presetQuestions.map((q) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      onTap: () {
                        Navigator.pop(ctx);
                        _sendToAiChat(
                          child: child,
                          last: last,
                          question: q['prompt'] as String,
                        );
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: borderColor),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: themeAccent.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(q['icon'] as IconData, size: 18, color: themeAccent),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    q['title'] as String,
                                    style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: textColor),
                                  ),
                                  Text(
                                    q['desc'] as String,
                                    style: GoogleFonts.outfit(fontSize: 10, color: bodyText),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.arrow_forward_ios_rounded, size: 12, color: bodyText.withValues(alpha: 0.5)),
                          ],
                        ),
                      ),
                    ),
                  );
                }),

                const SizedBox(height: 10),

                // Custom question input
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E24) : const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: questionController,
                          style: GoogleFonts.outfit(fontSize: 12, color: textColor),
                          decoration: InputDecoration(
                            hintText: isEn ? 'Write your own question about food/nutrition...' : 'Tulis pertanyaan makanan / gizi anak Anda...',
                            hintStyle: GoogleFonts.outfit(fontSize: 11, color: bodyText.withValues(alpha: 0.6)),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          final text = questionController.text.trim();
                          if (text.isNotEmpty) {
                            Navigator.pop(ctx);
                            _sendToAiChat(
                              child: child,
                              last: last,
                              question: text,
                            );
                          }
                        },
                        icon: Icon(Icons.send_rounded, color: themeAccent, size: 18),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openDirectAiChat({
    required PasienChildModel child,
    required ChildVisitRecord? last,
  }) {
    final user = ref.read(landingPageProvider).loggedInUser;
    final isEn = ref.read(landingPageProvider).language == 'en';
    final ownerName = (user?['name'] as String?) ??
        (user?['nama_lengkap'] as String?) ??
        (isEn ? 'Parent' : 'Bunda/Ayah');

    final childCtx = ActiveChildContext(
      childName: child.name,
      age: child.ageLabel,
      bb: '${last?.weightKg ?? 12.0} kg',
      tb: '${last?.heightCm ?? 85.0} cm',
      statusGizi: last?.statusGizi ?? 'Gizi Baik (Normal)',
      nutritionPlan: last?.nutritionPlan ?? 'Tingkatkan asupan protein hewani harian.',
      childId: child.vitascaleProfile?.id ??
          child.familyMember['id']?.toString(),
      childNik: child.nik,
      isSelf: false,
    );

    ref.read(aiChatProvider.notifier).selectChildContext(
      childContext: childCtx,
      accountOwnerName: ownerName,
    );

    widget.onNavigate?.call('ai_assistant');
  }

  void _sendToAiChat({
    required PasienChildModel child,
    required ChildVisitRecord? last,
    required String question,
  }) {
    final user = ref.read(landingPageProvider).loggedInUser;
    final isEn = ref.read(landingPageProvider).language == 'en';
    final ownerName = (user?['name'] as String?) ??
        (user?['nama_lengkap'] as String?) ??
        (isEn ? 'Parent' : 'Bunda/Ayah');

    final childCtx = ActiveChildContext(
      childName: child.name,
      age: child.ageLabel,
      bb: '${last?.weightKg ?? 12.0} kg',
      tb: '${last?.heightCm ?? 85.0} cm',
      statusGizi: last?.statusGizi ?? 'Gizi Baik (Normal)',
      nutritionPlan: last?.nutritionPlan ?? 'Tingkatkan asupan protein hewani harian.',
      childId: child.vitascaleProfile?.id ??
          child.familyMember['id']?.toString(),
      childNik: child.nik,
      isSelf: false,
    );

    ref.read(aiChatProvider.notifier).selectChildContext(
      childContext: childCtx,
      accountOwnerName: ownerName,
    );

    ref.read(aiChatProvider.notifier).sendMessage(question);

    widget.onNavigate?.call('ai_assistant');
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.child;
    final last = c.lastVisit;
    final isEn = widget.isEn;

    return Container(
      decoration: BoxDecoration(
        color: widget.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isExpanded ? widget.themeAccent.withValues(alpha: 0.5) : widget.borderColor,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: widget.isDark ? 0.3 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header Profile Row ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar circle
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: widget.avatarColor,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      c.name.isNotEmpty ? c.name[0].toUpperCase() : 'A',
                      style: GoogleFonts.outfit(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                // Detail Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              c.name,
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: widget.textColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: (c.isMale ? const Color(0xFF3498DB) : const Color(0xFFE91E63))
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  c.isMale ? Icons.male_rounded : Icons.female_rounded,
                                  size: 13,
                                  color: c.isMale ? const Color(0xFF3498DB) : const Color(0xFFE91E63),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  c.gender,
                                  style: GoogleFonts.outfit(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: c.isMale ? const Color(0xFF3498DB) : const Color(0xFFE91E63),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          _badgeText(Icons.cake_rounded, c.ageLabel),
                          _badgeText(Icons.category_rounded, c.categoryLabel),
                          _badgeText(Icons.bloodtype_rounded, 'Gol. ${c.bloodType}'),
                          _badgeText(Icons.health_and_safety_rounded, 'BPJS: ${c.bpjsNumber}'),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            'NIK: ${_showFullNik ? c.nik : c.maskedNik}',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              color: widget.bodyText,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 4),
                          InkWell(
                            onTap: () => setState(() => _showFullNik = !_showFullNik),
                            child: Icon(
                              _showFullNik ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                              size: 14,
                              color: widget.bodyText,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Divider ──────────────────────────────────────────────────────
          Divider(color: widget.borderColor, height: 1),

          // ── Last Check Summary Banner ────────────────────────────────────
          if (last != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              color: widget.themeAccent.withValues(alpha: 0.04),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.location_on_rounded, size: 16, color: widget.themeAccent),
                          const SizedBox(width: 6),
                          Text(
                            isEn ? 'Last Checkup Location:' : 'Lokasi & Faskes Periksa Terakhir:',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: widget.themeAccent,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: last.statusGiziColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          last.statusGizi,
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: last.statusGiziColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    last.examiner,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: widget.textColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${AppTranslations.formatDate(last.visitDate, lang: widget.lang)} • ${last.monthAgeLabel}',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      color: widget.bodyText,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Antropometri Metric Badges ────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: _metricBox(
                          icon: Icons.monitor_weight_rounded,
                          label: isEn ? 'Weight (BB)' : 'Berat (BB)',
                          value: '${last.weightKg.toStringAsFixed(1)} kg',
                          subValue: isEn ? 'Normal Range' : 'Kategori Baik',
                          accent: const Color(0xFF27AE60),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _metricBox(
                          icon: Icons.height_rounded,
                          label: isEn ? 'Height (TB/PB)' : 'Tinggi (TB/PB)',
                          value: '${last.heightCm.toStringAsFixed(1)} cm',
                          subValue: last.mode == 'PB' ? 'PB Telentang' : 'TB Berdiri',
                          accent: widget.themeAccent,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _metricBox(
                          icon: Icons.straighten_rounded,
                          label: isEn ? 'Waist & LiLA' : 'Perut & LiLA',
                          value: '${last.waistCm} / ${last.lilaCm} cm',
                          subValue: 'WHtR: ${(last.whtr).toStringAsFixed(2)}',
                          accent: const Color(0xFF3498DB),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: widget.bodyText, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    isEn ? 'No checkup record yet for this child.' : 'Belum ada rekam pemeriksaan antropometri untuk anak ini.',
                    style: GoogleFonts.outfit(fontSize: 12, color: widget.bodyText),
                  ),
                ],
              ),
            ),

          // ── LLM / AI Clinical Reasoning Section for Parents ───────────────
          if (last != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: widget.isDark
                        ? [const Color(0xFF1F1C28), const Color(0xFF18181E)]
                        : (widget.isRev
                            ? [const Color(0xFFF9F5FF), const Color(0xFFF2E9FF)]
                            : [const Color(0xFFF0FDF8), const Color(0xFFE6FAF2)]),
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: widget.themeAccent.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: widget.themeAccent.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.psychology_rounded, size: 18, color: widget.themeAccent),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isEn ? 'AI RECOMMENDATION FOR PARENTS' : 'REKOMENDASI AI UNTUK ORANG TUA',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  color: widget.themeAccent,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              Text(
                                isEn ? 'Saved guidance from clinical reasoning model' : 'Panduan praktis orang tua dari penalaran klinis dokter anak',
                                style: GoogleFonts.outfit(fontSize: 10, color: widget.bodyText),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: widget.themeAccent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Gemini 2.5 Flash',
                            style: GoogleFonts.outfit(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: widget.themeAccent,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // 1. Rekomendasi Orang Tua (Parent Action Plan)
                    _reasoningBlock(
                      icon: Icons.checklist_rounded,
                      title: isEn ? 'What Parents Should Do at Home' : 'Hal Yang Perlu Dilakukan Orang Tua di Rumah',
                      content: last.parentEducation,
                      accentColor: widget.themeAccent,
                    ),

                    const SizedBox(height: 10),

                    // 2. Rencana Nutrisi & MP-ASI
                    _reasoningBlock(
                      icon: Icons.restaurant_rounded,
                      title: isEn ? 'Nutrition & Daily Protein Plan' : 'Panduan Gizi & Protein Hewani Harian',
                      content: last.nutritionPlan,
                      accentColor: const Color(0xFF27AE60),
                    ),

                    const SizedBox(height: 10),

                    // 3. Protokol & Jadwal Kunjungan
                    _reasoningBlock(
                      icon: Icons.schedule_rounded,
                      title: isEn ? 'Next Checkup & Medical Protocol' : 'Jadwal Kontrol & Protokol Medis',
                      content: last.medicalProtocol,
                      accentColor: const Color(0xFF3498DB),
                    ),

                    if (_isExpanded) ...[
                      const SizedBox(height: 10),
                      // 4. Analisis Pertumbuhan (Expanded view)
                      _reasoningBlock(
                        icon: Icons.analytics_rounded,
                        title: isEn ? 'Growth Curve Analysis (WHO Standards)' : 'Analisis Kurva Pertumbuhan (Standar WHO)',
                        content: last.reasoningSummary,
                        accentColor: const Color(0xFFE67E22),
                      ),
                    ],

                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton.icon(
                          onPressed: () => setState(() => _isExpanded = !_isExpanded),
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            foregroundColor: widget.themeAccent,
                            padding: EdgeInsets.zero,
                          ),
                          icon: Icon(
                            _isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                            size: 18,
                          ),
                          label: Text(
                            _isExpanded
                                ? (isEn ? 'Hide Full Reasoning' : 'Sembunyikan Detail Analisis')
                                : (isEn ? 'Show Full Clinical Reasoning' : 'Lihat Analisis Lengkap'),
                            style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => _showAllVisitsDialog(context),
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            foregroundColor: widget.themeAccent,
                            padding: EdgeInsets.zero,
                          ),
                          icon: const Icon(Icons.history_rounded, size: 16),
                          label: Text(
                            isEn ? 'View All Visits (${widget.child.visitHistory.length})' : 'Riwayat Semua Periksa (${widget.child.visitHistory.length})',
                            style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // ── Chat with AI about Food & Nutrition Button ──
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            widget.themeAccent,
                            widget.themeAccent.withValues(alpha: 0.85),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: widget.themeAccent.withValues(alpha: 0.25),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: () => _openAiFoodConsultationModal(context, c, last),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                        label: Text(
                          isEn
                              ? 'Chat with AI: Ask About ${c.name}\'s Food & Nutrition'
                              : 'Chat dengan AI: Tanya Menu Makanan & Gizi ${c.name}',
                          style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Bottom Action Buttons ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => widget.onNavigate?.call('puskesmas_search'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: widget.textColor,
                      side: BorderSide(color: widget.borderColor),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    icon: Icon(Icons.location_on_rounded, size: 15, color: widget.themeAccent),
                    label: Text(
                      isEn ? 'Puskesmas' : 'Cari Puskesmas',
                      style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _openAiFoodConsultationModal(context, c, last),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.themeAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    icon: const Icon(Icons.auto_awesome_rounded, size: 15),
                    label: Text(
                      isEn ? 'Chat AI Food' : 'Chat AI Gizi',
                      style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => widget.onNavigate?.call('dokter_search'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: widget.textColor,
                      side: BorderSide(color: widget.borderColor),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    icon: Icon(Icons.medical_services_rounded, size: 15, color: widget.themeAccent),
                    label: Text(
                      isEn ? 'Pediatrician' : 'Dokter Anak',
                      style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _badgeText(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: widget.bodyText),
        const SizedBox(width: 4),
        Text(
          text,
          style: GoogleFonts.outfit(
            fontSize: 11,
            color: widget.bodyText,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _metricBox({
    required IconData icon,
    required String label,
    required String value,
    required String subValue,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: widget.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: widget.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: accent),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.outfit(fontSize: 9.5, color: widget.bodyText),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: widget.textColor,
            ),
          ),
          Text(
            subValue,
            style: GoogleFonts.outfit(
              fontSize: 9,
              color: accent,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _reasoningBlock({
    required IconData icon,
    required String title,
    required String content,
    required Color accentColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: widget.cardBg.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accentColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: accentColor),
              const SizedBox(width: 6),
              Text(
                title,
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: accentColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          FormattedMarkdownText(
            text: content,
            style: GoogleFonts.outfit(
              fontSize: 11,
              color: widget.textColor,
              height: 1.45,
            ),
            boldStyle: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: accentColor,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
