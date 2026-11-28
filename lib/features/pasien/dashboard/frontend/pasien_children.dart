import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapotech/features/landing/landing_page_data.dart';
import 'package:mapotech/features/pasien/dashboard/frontend/ai_assistant/presentation/ai_chat_provider.dart';
import 'package:mapotech/features/pasien/dashboard/frontend/application/pasien_children_service.dart';
import 'package:mapotech/features/puskesmas/dlc/vitascale/pages/vitascale_child_history_page.dart';
import 'package:mapotech/shared/widgets/ui.dart';

export 'package:mapotech/features/pasien/dashboard/frontend/application/pasien_children_service.dart';

// ─── Main Screen Widget ───────────────────────────────────────────────────────

class PasienChildren extends ConsumerStatefulWidget {
  final Function(String menu)? onNavigate;
  final Future<PasienFamilyDirectory> Function(Map<String, dynamic>? user)?
      directoryLoader;
  final Future<List<Map<String, dynamic>>> Function(String encounterId)?
      medicinesLoader;

  const PasienChildren({
    super.key,
    this.onNavigate,
    this.directoryLoader,
    this.medicinesLoader,
  });

  @override
  ConsumerState<PasienChildren> createState() => _PasienChildrenState();
}

class _PasienChildrenState extends ConsumerState<PasienChildren> {
  bool _isLoading = true;
  String? _errorMessage;
  PasienChildModel? _currentUser;
  List<PasienChildModel> _familyMembers = [];
  String _noKk = '';
  String _selectedCategoryFilter = 'Semua';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadFamilyData();
  }

  Future<void> _loadFamilyData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = ref.read(landingPageProvider).loggedInUser;
      final loader =
          widget.directoryLoader ?? PasienChildrenService.fetchFamilyDirectoryForUser;
      final directory = await loader(user);

      if (mounted) {
        setState(() {
          _currentUser = directory.currentUser;
          _familyMembers = directory.familyMembers;
          _noKk = directory.noKk.isNotEmpty
              ? directory.noKk
              : ((user?['no_kk'] as String? ?? '').trim());
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
    const colors = [
      Color(0xFFF1948A),
      Color(0xFFC39BD3),
      Color(0xFF7FB3D5),
      Color(0xFF76D7C4),
      Color(0xFFF7DC6F),
      Color(0xFFF5B041),
      Color(0xFF85929E),
    ];
    if (name.isEmpty) return colors[0];
    int hash = 0;
    for (int i = 0; i < name.length; i++) {
      hash = name.codeUnitAt(i) + ((hash << 5) - hash);
    }
    return colors[hash.abs() % colors.length];
  }

  void _openMemberDetailModal(
    BuildContext context,
    PasienChildModel member, {
    int initialTab = 0,
  }) {
    final state = ref.read(landingPageProvider);
    final notifier = ref.read(landingPageProvider.notifier);
    final isEn = state.language == 'en';
    final isDark = state.appearance == 'dark';
    final isRev = state.appearance == 'rev';

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.48),
      builder: (ctx) => _MemberDetailDialog(
        member: member,
        isEn: isEn,
        isDark: isDark,
        isRev: isRev,
        lang: state.language,
        themeAccent: notifier.getPrimaryColor(),
        cardBg: notifier.getCardColor(),
        textColor: notifier.getTextColor(),
        bodyText: notifier.getBodyTextColor(),
        borderColor: notifier.getBorderColor(),
        avatarColor: _getAvatarColor(member.name),
        initialTab: initialTab,
        onAskAi: () {
          Navigator.of(ctx).pop();
          _askAiAboutMember(member, isEn: isEn);
        },
        onNavigate: (menu) {
          Navigator.of(ctx).pop();
          widget.onNavigate?.call(menu);
        },
        medicinesLoader: widget.medicinesLoader,
      ),
    );
  }

  void _askAiAboutMember(PasienChildModel member, {required bool isEn}) {
    final user = ref.read(landingPageProvider).loggedInUser;
    final ownerName = (user?['name'] as String?) ??
        (user?['nama_lengkap'] as String?) ??
        (isEn ? 'Parent' : 'Bunda/Ayah');

    final last = member.lastCheckup;
    final vitals = last?.vitals;
    final bbRaw = vitals?['body_weight']?.toString() ??
        (member.lastVisit != null
            ? '${member.lastVisit!.weightKg}'
            : (member.isAdult ? '65.0' : '12.0'));
    final tbRaw = vitals?['body_height']?.toString() ??
        (member.lastVisit != null
            ? '${member.lastVisit!.heightCm}'
            : (member.isAdult ? '168.0' : '85.0'));

    final statusSummary = last?.primaryDiagnosisText ??
        (member.isAdult
            ? (isEn
                ? 'Adult Health Profile (${member.hubungan})'
                : 'Profil Kesehatan Dewasa (${member.hubungan})')
            : 'Gizi Baik (Normal)');

    final planSummary = member.lastVisit?.nutritionPlan ??
        last?.medicationTherapy ??
        (member.isAdult
            ? (isEn
                ? 'Balanced nutrition, routine checkups, and healthy lifestyle.'
                : 'Pola hidup seimbang, pemeriksaan berkala, dan nutrisi keluarga.')
            : 'Tingkatkan variasi protein hewani harian sesuai kebutuhan usia.');

    final ctx = ActiveChildContext(
      childName: member.isSelf
          ? '${member.name} ${isEn ? '(Self)' : '(Saya)'}'
          : member.name,
      age: member.ageLabel,
      bb: bbRaw.contains('kg') ? bbRaw : '$bbRaw kg',
      tb: tbRaw.contains('cm') ? tbRaw : '$tbRaw cm',
      statusGizi: statusSummary,
      nutritionPlan: planSummary,
      childId: member.vitascaleProfile?.id ??
          member.userId ??
          member.familyMember['id']?.toString(),
      childNik: member.nik,
      isSelf: member.isSelf,
    );

    ref.read(aiChatProvider.notifier).selectChildContext(
          childContext: ctx,
          accountOwnerName: ownerName,
        );
    widget.onNavigate?.call('ai_assistant');
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
    final hasKk = _noKk.isNotEmpty;
    final totalHousehold = (_currentUser != null ? 1 : 0) + _familyMembers.length;

    final filteredMembers = _familyMembers.where((c) {
      if (_selectedCategoryFilter == 'Balita' && !c.isBalita) return false;
      if (_selectedCategoryFilter == 'Bayi' && !c.isUnder24Months) return false;
      if (_selectedCategoryFilter == 'Anak' && (!c.isChild || c.isBalita)) {
        return false;
      }
      if (_selectedCategoryFilter == 'Dewasa' && !c.isAdult) return false;

      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchName = c.name.toLowerCase().contains(q);
        final matchNik = c.nik.toLowerCase().contains(q);
        final matchRel = c.hubungan.toLowerCase().contains(q);
        return matchName || matchNik || matchRel;
      }
      return true;
    }).toList();

    return CustomLazyLoader(
      isLoading: _isLoading,
      loadingText: isEn
          ? 'Loading family health records...'
          : 'Memuat data rekam medis keluarga...',
      loadingSubtext: isEn
          ? 'Syncing family profiles & latest clinical checkups...'
          : 'Sinkronisasi profil keluarga & pemeriksaan terakhir...',
      skeleton: const SkeletonChildrenList(itemCount: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Top Header Banner ───────────────────────────────────────────
          _buildHeaderBanner(
            isEn: isEn,
            isDark: isDark,
            isRev: isRev,
            themeAccent: themeAccent,
            textColor: textColor,
            bodyText: bodyText,
            cardBg: cardBg,
            borderColor: borderColor,
            noKk: _noKk,
            hasKk: hasKk,
            totalHousehold: totalHousehold,
          ),

          const SizedBox(height: 18),

          // ── Top User Detail Card (Logged-in User) ───────────────────────
          if (_currentUser != null) ...[
            _buildSectionHeader(
              icon: Icons.account_circle_rounded,
              title: isEn ? 'MY PROFILE (USER DETAIL)' : 'DETAIL PENGGUNA (AKUN SAYA)',
              hint: isEn
                  ? 'Tap card for profile & last checkup'
                  : 'Klik kartu untuk profil & pemeriksaan terakhir',
              themeAccent: themeAccent,
              textColor: textColor,
              bodyText: bodyText,
            ),
            const SizedBox(height: 10),
            _FamilyProfileCard(
              member: _currentUser!,
              isUserCard: true,
              isEn: isEn,
              isDark: isDark,
              isRev: isRev,
              lang: lang,
              themeAccent: themeAccent,
              cardBg: cardBg,
              textColor: textColor,
              bodyText: bodyText,
              borderColor: borderColor,
              avatarColor: _getAvatarColor(_currentUser!.name),
              onTap: () => _openMemberDetailModal(context, _currentUser!),
              onCheckupTap: () => _openMemberDetailModal(
                context,
                _currentUser!,
                initialTab: 1,
              ),
              onAskAi: () => _askAiAboutMember(_currentUser!, isEn: isEn),
              onNavigate: widget.onNavigate,
            ),
            const SizedBox(height: 18),
          ],

          // ── KK Warning or AI Family Consultation Banner ─────────────────
          if (!hasKk && _familyMembers.isEmpty) ...[
            _buildNoKkWarningCard(
              isEn: isEn,
              textColor: textColor,
            ),
            const SizedBox(height: 18),
          ] else ...[
            _buildAiFamilyBanner(
              isEn: isEn,
              themeAccent: themeAccent,
              textColor: textColor,
              bodyText: bodyText,
              user: user,
              allMembers: [
                ?_currentUser,
                ..._familyMembers,
              ],
            ),
            const SizedBox(height: 18),
          ],

          // ── Family Members Section Header & Controls ────────────────────
          _buildSectionHeader(
            icon: Icons.groups_rounded,
            title: isEn
                ? 'FAMILY MEMBERS (${_familyMembers.length})'
                : 'ANGGOTA KELUARGA (${_familyMembers.length})',
            hint: isEn
                ? 'Tap any member card to inspect profile & checkups'
                : 'Klik kartu anggota untuk lihat profil & detail pemeriksaan',
            themeAccent: themeAccent,
            textColor: textColor,
            bodyText: bodyText,
          ),
          const SizedBox(height: 12),

          _buildControls(
            isEn: isEn,
            themeAccent: themeAccent,
            textColor: textColor,
            bodyText: bodyText,
            cardBg: cardBg,
            borderColor: borderColor,
          ),

          const SizedBox(height: 16),

          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFE74C3C).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFE74C3C).withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                _errorMessage!,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: const Color(0xFFE74C3C),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── Family Member Cards Grid / List ─────────────────────────────
          if (filteredMembers.isEmpty)
            _buildEmptyState(
              isEn: isEn,
              hasMembers: _familyMembers.isNotEmpty,
              themeAccent: themeAccent,
              textColor: textColor,
              bodyText: bodyText,
              cardBg: cardBg,
              borderColor: borderColor,
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final useTwoColumns = constraints.maxWidth >= 820;
                if (!useTwoColumns) {
                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredMembers.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      final member = filteredMembers[index];
                      return _FamilyProfileCard(
                        member: member,
                        isUserCard: false,
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
                        onTap: () => _openMemberDetailModal(context, member),
                        onCheckupTap: () => _openMemberDetailModal(
                          context,
                          member,
                          initialTab: 1,
                        ),
                        onAskAi: () => _askAiAboutMember(member, isEn: isEn),
                        onNavigate: widget.onNavigate,
                      );
                    },
                  );
                }

                // Responsive 2-column rows preserving natural intrinsic card height
                final List<Widget> rows = [];
                for (int i = 0; i < filteredMembers.length; i += 2) {
                  final left = filteredMembers[i];
                  final right =
                      i + 1 < filteredMembers.length ? filteredMembers[i + 1] : null;
                  rows.add(
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _FamilyProfileCard(
                              member: left,
                              isUserCard: false,
                              isEn: isEn,
                              isDark: isDark,
                              isRev: isRev,
                              lang: lang,
                              themeAccent: themeAccent,
                              cardBg: cardBg,
                              textColor: textColor,
                              bodyText: bodyText,
                              borderColor: borderColor,
                              avatarColor: _getAvatarColor(left.name),
                              onTap: () => _openMemberDetailModal(context, left),
                              onCheckupTap: () => _openMemberDetailModal(
                                context,
                                left,
                                initialTab: 1,
                              ),
                              onAskAi: () => _askAiAboutMember(left, isEn: isEn),
                              onNavigate: widget.onNavigate,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: right != null
                                ? _FamilyProfileCard(
                                    member: right,
                                    isUserCard: false,
                                    isEn: isEn,
                                    isDark: isDark,
                                    isRev: isRev,
                                    lang: lang,
                                    themeAccent: themeAccent,
                                    cardBg: cardBg,
                                    textColor: textColor,
                                    bodyText: bodyText,
                                    borderColor: borderColor,
                                    avatarColor: _getAvatarColor(right.name),
                                    onTap: () =>
                                        _openMemberDetailModal(context, right),
                                    onCheckupTap: () => _openMemberDetailModal(
                                      context,
                                      right,
                                      initialTab: 1,
                                    ),
                                    onAskAi: () =>
                                        _askAiAboutMember(right, isEn: isEn),
                                    onNavigate: widget.onNavigate,
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ),
                  );
                  if (i + 2 < filteredMembers.length) {
                    rows.add(const SizedBox(height: 16));
                  }
                }
                return Column(children: rows);
              },
            ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required String hint,
    required Color themeAccent,
    required Color textColor,
    required Color bodyText,
  }) {
    return Row(
      children: [
        Icon(icon, size: 17, color: themeAccent),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: textColor,
              letterSpacing: 0.7,
            ),
          ),
        ),
        Flexible(
          child: Text(
            hint,
            style: GoogleFonts.outfit(
              fontSize: 10.5,
              color: bodyText.withValues(alpha: 0.8),
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
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
    required int totalHousehold,
  }) {
    return Container(
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
                child: Icon(
                  Icons.family_restroom_rounded,
                  color: themeAccent,
                  size: 24,
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
                            isEn
                                ? 'My Family (Family Records)'
                                : 'My Family (Keluarga Saya)',
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: textColor,
                              letterSpacing: -0.2,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
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
                          ? 'View your profile, registered family members, and latest medical checkup details in one place.'
                          : 'Pantau profil Anda, anggota keluarga terdaftar, dan detail pemeriksaan medis terakhir dalam satu tampilan.',
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
                onPressed: _loadFamilyData,
              ),
            ],
          ),
          const SizedBox(height: 14),
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
                            ? 'Family Card No: $noKk • $totalHousehold Household Profiles'
                            : 'No. Kartu Keluarga: $noKk • $totalHousehold Profil Keluarga')
                        : (isEn
                            ? 'No Family Card (KK) connected yet. Connect your KK in Profile to sync family members.'
                            : 'Nomor Kartu Keluarga (KK) belum terhubung. Lengkapi KK di Profil untuk sinkronisasi keluarga.'),
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
                    hasKk
                        ? (isEn ? 'Manage KK' : 'Kelola KK')
                        : (isEn ? 'Connect KK' : 'Hubungkan KK'),
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
    required Color textColor,
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
            child: const Icon(
              Icons.assignment_ind_rounded,
              color: Color(0xFFE67E22),
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEn
                      ? 'Family Card (KK) Required'
                      : 'Kartu Keluarga (KK) Diperlukan',
                  style: GoogleFonts.outfit(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFE67E22),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isEn
                      ? 'To connect and monitor your family members and checkups, please add your Family Card (KK) number in Profile.'
                      : 'Untuk menghubungkan dan memantau anggota keluarga beserta hasil periksanya, silakan lengkapi nomor KK di Profil.',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: textColor.withValues(alpha: 0.8),
                  ),
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
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
    required Color themeAccent,
    required Color textColor,
    required Color bodyText,
    required Map<String, dynamic>? user,
    required List<PasienChildModel> allMembers,
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
        border: Border.all(
          color: const Color(0xFF8E44AD).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF8E44AD).withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Color(0xFF8E44AD),
              size: 22,
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
                        isEn
                            ? 'Ask Mapotech AI for Entire Family'
                            : 'Tanya Mapotech AI untuk Seluruh Keluarga',
                        style: GoogleFonts.outfit(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: textColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1.5,
                      ),
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
                      ? 'Consult holistic nutrition, toddler milestones, and checkup results for your whole household.'
                      : 'Konsultasikan gizi, tumbuh kembang, dan hasil pemeriksaan seluruh anggota keluarga di 1 KK.',
                  style: GoogleFonts.outfit(fontSize: 11, color: bodyText),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: () {
              final allCtx = PasienChildrenService.createAllFamilyContext(
                user,
                allMembers,
                isEn: isEn,
              );
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: const Icon(Icons.forum_rounded, size: 15),
            label: Text(
              isEn ? 'Ask AI (All)' : 'Tanya AI (Semua)',
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Filter & Search Controls ──────────────────────────────────────────────
  Widget _buildControls({
    required bool isEn,
    required Color themeAccent,
    required Color textColor,
    required Color bodyText,
    required Color cardBg,
    required Color borderColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
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
                        onChanged: (val) =>
                            setState(() => _searchQuery = val.trim()),
                        style: GoogleFonts.outfit(fontSize: 12, color: textColor),
                        decoration: InputDecoration(
                          hintText: isEn
                              ? 'Search family member name or NIK...'
                              : 'Cari nama anggota keluarga atau NIK...',
                          hintStyle: GoogleFonts.outfit(
                            fontSize: 12,
                            color: bodyText.withValues(alpha: 0.6),
                          ),
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
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip(
                'Semua',
                isEn
                    ? 'All Members (${_familyMembers.length})'
                    : 'Semua Anggota (${_familyMembers.length})',
                themeAccent,
                textColor,
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                'Balita',
                isEn ? 'Toddlers (0-59 Mo)' : 'Balita (0-59 Bln)',
                themeAccent,
                textColor,
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                'Bayi',
                isEn ? 'Infants (< 24 Mo)' : 'Bayi (< 24 Bln)',
                themeAccent,
                textColor,
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                'Anak',
                isEn ? 'Children' : 'Anak',
                themeAccent,
                textColor,
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                'Dewasa',
                isEn ? 'Adults / Parents' : 'Orang Tua / Dewasa',
                themeAccent,
                textColor,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(
    String key,
    String label,
    Color accent,
    Color textColor,
  ) {
    final isSelected = _selectedCategoryFilter == key;
    return InkWell(
      onTap: () => setState(() => _selectedCategoryFilter = key),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? accent : accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? accent : accent.withValues(alpha: 0.2),
          ),
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
    required bool hasMembers,
    required Color themeAccent,
    required Color textColor,
    required Color bodyText,
    required Color cardBg,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: themeAccent.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              hasMembers ? Icons.filter_list_off_rounded : Icons.groups_rounded,
              size: 32,
              color: themeAccent,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            hasMembers
                ? (isEn
                    ? 'No Matching Family Member'
                    : 'Anggota Keluarga Tidak Ditemukan')
                : (isEn
                    ? 'No Family Members Registered Yet'
                    : 'Belum Ada Anggota Keluarga Terdaftar'),
            style: GoogleFonts.outfit(
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hasMembers
                ? (isEn
                    ? 'Try clearing your search or switching to "All Members".'
                    : 'Coba ubah kata kunci pencarian atau pilih filter "Semua Anggota".')
                : (isEn
                    ? 'Register your family members in the Family Information (KK) section under Profile.'
                    : 'Daftarkan anggota keluarga Anda di menu Profil pada tab Informasi Keluarga (KK).'),
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: bodyText,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          if (!hasMembers)
            ElevatedButton.icon(
              onPressed: () => widget.onNavigate?.call('profile'),
              style: ElevatedButton.styleFrom(
                backgroundColor: themeAccent,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.person_add_rounded, size: 16),
              label: Text(
                isEn
                    ? 'Open Profile to Add Member'
                    : 'Buka Profil untuk Tambah Anggota',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            )
          else
            OutlinedButton.icon(
              onPressed: () => setState(() {
                _selectedCategoryFilter = 'Semua';
                _searchQuery = '';
              }),
              style: OutlinedButton.styleFrom(
                foregroundColor: themeAccent,
                side: BorderSide(color: themeAccent.withValues(alpha: 0.4)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: Text(
                isEn ? 'Reset Filter' : 'Reset Filter',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Unified Clickable Family / User Profile Card ────────────────────────────

class _FamilyProfileCard extends StatefulWidget {
  final PasienChildModel member;
  final bool isUserCard;
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
  final VoidCallback onTap;
  final VoidCallback onCheckupTap;
  final VoidCallback onAskAi;
  final Function(String menu)? onNavigate;

  const _FamilyProfileCard({
    required this.member,
    required this.isUserCard,
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
    required this.onTap,
    required this.onCheckupTap,
    required this.onAskAi,
    this.onNavigate,
  });

  @override
  State<_FamilyProfileCard> createState() => _FamilyProfileCardState();
}

class _FamilyProfileCardState extends State<_FamilyProfileCard> {
  bool _showFullNik = false;
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final m = widget.member;
    final isEn = widget.isEn;
    final last = m.lastCheckup;

    final roleColor = m.isSelf
        ? widget.themeAccent
        : (m.isChild
            ? const Color(0xFF1ABC9C)
            : (m.isMother
                ? const Color(0xFFE91E63)
                : const Color(0xFF2980B9)));

    final borderHighlight = _isHovered
        ? widget.themeAccent.withValues(alpha: 0.7)
        : (widget.isUserCard
            ? widget.themeAccent.withValues(alpha: 0.45)
            : widget.borderColor);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: widget.cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: borderHighlight,
                width: widget.isUserCard || _isHovered ? 1.5 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: widget.isDark
                        ? (_isHovered ? 0.35 : 0.25)
                        : (_isHovered ? 0.08 : 0.04),
                  ),
                  blurRadius: _isHovered ? 20 : 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header: Avatar + Name + Badges ───────────────────
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _MemberAvatar(
                          name: m.name,
                          avatarUrl: m.avatarUrl,
                          avatarColor: widget.avatarColor,
                          size: widget.isUserCard ? 56 : 50,
                          isMale: m.isMale,
                          isChild: m.isChild,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    m.name,
                                    style: GoogleFonts.outfit(
                                      fontSize: widget.isUserCard ? 17 : 15.5,
                                      fontWeight: FontWeight.w900,
                                      color: widget.textColor,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2.5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: roleColor.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: roleColor.withValues(alpha: 0.3),
                                      ),
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
                                  if (widget.isUserCard)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 2.5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: widget.themeAccent,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        isEn ? 'YOU' : 'SAYA',
                                        style: GoogleFonts.outfit(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                          letterSpacing: 0.4,
                                        ),
                                      ),
                                    ),
                                  if (!m.isAccepted)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 2.5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        isEn ? 'PENDING KK' : 'MENUNGGU KK',
                                        style: GoogleFonts.outfit(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.amber[800],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 10,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  InkWell(
                                    onTap: () =>
                                        setState(() => _showFullNik = !_showFullNik),
                                    borderRadius: BorderRadius.circular(6),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 1,
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'NIK: ${_showFullNik ? m.nik : m.maskedNik}',
                                            style: GoogleFonts.outfit(
                                              fontSize: 11,
                                              color: widget.bodyText,
                                              fontFeatures: const [
                                                FontFeature.tabularFigures(),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Icon(
                                            _showFullNik
                                                ? Icons.visibility_off_rounded
                                                : Icons.visibility_rounded,
                                            size: 13,
                                            color: widget.bodyText
                                                .withValues(alpha: 0.75),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  _inlineInfo(
                                    m.isMale
                                        ? Icons.male_rounded
                                        : Icons.female_rounded,
                                    m.gender,
                                    m.isMale
                                        ? const Color(0xFF3498DB)
                                        : const Color(0xFFE91E63),
                                  ),
                                  _inlineInfo(
                                    Icons.cake_rounded,
                                    m.ageLabel,
                                    widget.bodyText,
                                  ),
                                ],
                              ),
                              if (widget.isUserCard &&
                                  m.address != null &&
                                  m.address!.isNotEmpty) ...[
                                const SizedBox(height: 5),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.location_on_outlined,
                                      size: 13,
                                      color: widget.bodyText.withValues(alpha: 0.75),
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        m.address!,
                                        style: GoogleFonts.outfit(
                                          fontSize: 11,
                                          color: widget.bodyText,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: widget.themeAccent.withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: widget.themeAccent,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // ── Compact Last Checkup Preview Bar ─────────────────
                    InkWell(
                      onTap: widget.onCheckupTap,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 13,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: widget.isDark
                              ? const Color(0xFF1E1E24)
                              : const Color(0xFFF8F9FB),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: last != null
                                ? widget.themeAccent.withValues(alpha: 0.25)
                                : widget.borderColor,
                          ),
                        ),
                        child: last != null
                            ? _buildLastCheckupSummaryRow(last, m.checkups.length)
                            : Row(
                                children: [
                                  Icon(
                                    Icons.event_note_outlined,
                                    size: 16,
                                    color: widget.bodyText.withValues(alpha: 0.7),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      isEn
                                          ? 'No medical checkup recorded yet'
                                          : 'Belum ada riwayat pemeriksaan medis',
                                      style: GoogleFonts.outfit(
                                        fontSize: 11,
                                        color: widget.bodyText,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    isEn ? 'Profile →' : 'Profil →',
                                    style: GoogleFonts.outfit(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: widget.themeAccent,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // ── Card Footer Actions ──────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (m.isMother)
                            ElevatedButton.icon(
                              onPressed: () =>
                                  widget.onNavigate?.call('momicare_pregnancy'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFE91E63),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              icon: const Icon(
                                Icons.pregnant_woman_rounded,
                                size: 15,
                              ),
                              label: Text(
                                isEn ? 'MomiCare' : 'MomiCare',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          OutlinedButton.icon(
                            onPressed: widget.onAskAi,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: widget.themeAccent,
                              side: BorderSide(
                                color:
                                    widget.themeAccent.withValues(alpha: 0.35),
                              ),
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: const Icon(
                              Icons.chat_bubble_outline_rounded,
                              size: 14,
                            ),
                            label: Text(
                              isEn ? 'Ask AI' : 'Tanya AI',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      onPressed: widget.onTap,
                      style: TextButton.styleFrom(
                        foregroundColor: widget.themeAccent,
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                      ),
                      icon: const Icon(Icons.open_in_new_rounded, size: 14),
                      label: Text(
                        isEn ? 'Detail & Checkup' : 'Detail & Periksa',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLastCheckupSummaryRow(
    FamilyCheckupRecord last,
    int totalCount,
  ) {
    final isEn = widget.isEn;
    final formattedDate =
        AppTranslations.formatDate(last.checkupDate, lang: widget.lang);
    final vitals = last.vitals;
    final List<String> quickVitals = [];
    if (vitals != null) {
      final bp = vitals['blood_pressure']?.toString().trim() ?? '';
      final temp = vitals['body_temperature']?.toString().trim() ?? '';
      final weight = vitals['body_weight']?.toString().trim() ?? '';
      if (bp.isNotEmpty) quickVitals.add('TD $bp');
      if (temp.isNotEmpty) quickVitals.add('$temp°C');
      if (weight.isNotEmpty) quickVitals.add('$weight kg');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.assignment_turned_in_rounded,
              size: 14,
              color: widget.themeAccent,
            ),
            const SizedBox(width: 6),
            Text(
              isEn ? 'Last Checkup' : 'Pemeriksaan Terakhir',
              style: GoogleFonts.outfit(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: widget.themeAccent,
              ),
            ),
            const Spacer(),
            Text(
              formattedDate,
              style: GoogleFonts.outfit(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: widget.bodyText,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '${last.examinerName} • ${last.facilityName}',
          style: GoogleFonts.outfit(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: widget.textColor,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (last.primaryDiagnosisText != null || quickVitals.isNotEmpty) ...[
          const SizedBox(height: 5),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              if (last.primaryDiagnosisText != null)
                _miniPill(
                  last.primaryDiagnosisText!,
                  const Color(0xFF27AE60),
                ),
              if (quickVitals.isNotEmpty)
                _miniPill(quickVitals.join(' • '), widget.themeAccent),
              if (totalCount > 1)
                _miniPill(
                  isEn ? '$totalCount visits' : '$totalCount riwayat',
                  widget.bodyText,
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _miniPill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: GoogleFonts.outfit(
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _inlineInfo(IconData icon, String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: GoogleFonts.outfit(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: widget.bodyText,
          ),
        ),
      ],
    );
  }
}

// ─── Unified Tabbed Profile & Last Checkup Modal ─────────────────────────────

class _MemberDetailDialog extends StatefulWidget {
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
  final int initialTab;
  final VoidCallback onAskAi;
  final Function(String menu) onNavigate;
  final Future<List<Map<String, dynamic>>> Function(String encounterId)?
      medicinesLoader;

  const _MemberDetailDialog({
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
    this.initialTab = 0,
    required this.onAskAi,
    required this.onNavigate,
    this.medicinesLoader,
  });

  @override
  State<_MemberDetailDialog> createState() => _MemberDetailDialogState();
}

class _MemberDetailDialogState extends State<_MemberDetailDialog> {
  late int _activeTab; // 0: Detail Profil, 1: Pemeriksaan Terakhir
  bool _showFullNik = false;

  // In-modal selected checkup for inline Detail Pemeriksaan inspection
  FamilyCheckupRecord? _selectedCheckup;
  bool _isLoadingMedicines = false;
  final Map<String, List<Map<String, dynamic>>> _medicinesCache = {};

  @override
  void initState() {
    super.initState();
    _activeTab = widget.initialTab.clamp(0, 1);
  }

  Future<void> _openCheckupDetailInModal(FamilyCheckupRecord record) async {
    setState(() {
      _selectedCheckup = record;
    });

    if (record.source == 'doctor' &&
        !record.medicinesLoaded &&
        !_medicinesCache.containsKey(record.id)) {
      setState(() => _isLoadingMedicines = true);
      final loader = widget.medicinesLoader ??
          PasienChildrenService.fetchCheckupMedicines;
      final meds = await loader(record.id);
      if (!mounted) return;
      setState(() {
        _medicinesCache[record.id] = meds;
        _isLoadingMedicines = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.member;
    final isEn = widget.isEn;
    final maxH = MediaQuery.of(context).size.height * 0.86;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: widget.cardBg,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 640, maxHeight: maxH),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Modal Hero Banner & Overlapping Avatar ────────────────────
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  height: 84,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        widget.avatarColor.withValues(alpha: 0.35),
                        widget.themeAccent.withValues(alpha: 0.22),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
                Positioned(
                  right: 14,
                  top: 12,
                  child: InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 17,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 24,
                  bottom: -24,
                  child: Container(
                    padding: const EdgeInsets.all(3.5),
                    decoration: BoxDecoration(
                      color: widget.cardBg,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: _MemberAvatar(
                      name: m.name,
                      avatarUrl: m.avatarUrl,
                      avatarColor: widget.avatarColor,
                      size: 62,
                      isMale: m.isMale,
                      isChild: m.isChild,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 30),

            // ── Identity Header ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        m.name,
                        style: GoogleFonts.outfit(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                          color: widget.textColor,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: widget.themeAccent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          m.hubungan.toUpperCase(),
                          style: GoogleFonts.outfit(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            color: widget.themeAccent,
                          ),
                        ),
                      ),
                      if (m.isSelf)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: widget.themeAccent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isEn ? 'MY ACCOUNT' : 'AKUN SAYA',
                            style: GoogleFonts.outfit(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      InkWell(
                        onTap: () =>
                            setState(() => _showFullNik = !_showFullNik),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'NIK: ${_showFullNik ? m.nik : m.maskedNik}',
                              style: GoogleFonts.outfit(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: widget.bodyText,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Icon(
                              _showFullNik
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                              size: 14,
                              color: widget.bodyText,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '•  ${m.gender}  •  ${m.ageLabel}',
                        style: GoogleFonts.outfit(
                          fontSize: 11.5,
                          color: widget.bodyText,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Tabbed Pane Header ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: widget.isDark
                      ? const Color(0xFF1E1E24)
                      : const Color(0xFFF3F4F8),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: widget.borderColor),
                ),
                child: Row(
                  children: [
                    _buildModalTabButton(
                      index: 0,
                      icon: Icons.person_rounded,
                      label: isEn ? 'Profile Detail' : 'Detail Profil',
                    ),
                    const SizedBox(width: 4),
                    _buildModalTabButton(
                      index: 1,
                      icon: Icons.assignment_turned_in_rounded,
                      label: isEn ? 'Last Checkup' : 'Pemeriksaan Terakhir',
                      badgeCount: m.checkups.length,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),
            Divider(height: 1, color: widget.borderColor),

            // ── Tabbed Pane Body ──────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(22),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _activeTab == 0
                      ? _buildProfileTab(m)
                      : _buildCheckupTab(m),
                ),
              ),
            ),

            // ── Modal Footer ──────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: widget.borderColor)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  OutlinedButton.icon(
                    onPressed: widget.onAskAi,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: widget.themeAccent,
                      side: BorderSide(
                        color: widget.themeAccent.withValues(alpha: 0.4),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.auto_awesome_rounded, size: 15),
                    label: Text(
                      isEn ? 'Consult AI' : 'Konsultasi AI',
                      style: GoogleFonts.outfit(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.themeAccent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                    ),
                    child: Text(
                      isEn ? 'Close' : 'Tutup',
                      style: GoogleFonts.outfit(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModalTabButton({
    required int index,
    required IconData icon,
    required String label,
    int badgeCount = 0,
  }) {
    final isSelected = _activeTab == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _activeTab = index),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
          decoration: BoxDecoration(
            color: isSelected ? widget.themeAccent : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : widget.bodyText,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: GoogleFonts.outfit(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: isSelected ? Colors.white : widget.bodyText,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (badgeCount > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1.5,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.25)
                        : widget.themeAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$badgeCount',
                    style: GoogleFonts.outfit(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                      color: isSelected ? Colors.white : widget.themeAccent,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── TAB 0: PROFILE DETAIL (NO BPJS, NO GOLONGAN DARAH) ────────────────────

  Widget _buildProfileTab(PasienChildModel m) {
    final isEn = widget.isEn;
    final birthDateDisplay = m.birthDate != null
        ? AppTranslations.formatDate(
            m.birthDate!,
            lang: widget.lang,
            includeDay: false,
          )
        : (m.birthDateRaw ?? '-');
    final birthLine = (m.birthPlace != null && m.birthPlace!.isNotEmpty)
        ? '${m.birthPlace}, $birthDateDisplay'
        : birthDateDisplay;

    return Column(
      key: const ValueKey('profile_tab'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: widget.isDark
                ? const Color(0xFF1E1E24)
                : const Color(0xFFF8F9FC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: widget.borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _profileField(
                      isEn ? 'FULL NAME' : 'NAMA LENGKAP',
                      m.name,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _profileField(
                      isEn ? 'FAMILY ROLE' : 'HUBUNGAN KELUARGA',
                      m.hubungan,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _profileField(
                      isEn ? 'GENDER' : 'JENIS KELAMIN',
                      m.gender,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _profileField(
                      isEn ? 'AGE / CATEGORY' : 'USIA / KATEGORI',
                      '${m.ageLabel} (${m.categoryLabel})',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _profileField(
                      isEn ? 'BIRTH PLACE & DATE' : 'TEMPAT, TANGGAL LAHIR',
                      birthLine,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _profileField(
                      'NIK',
                      _showFullNik ? m.nik : m.maskedNik,
                    ),
                  ),
                ],
              ),
              if (m.phone != null || m.email != null) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _profileField(
                        isEn ? 'PHONE NUMBER' : 'NO. TELEPON',
                        m.phone ?? '-',
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _profileField(
                        'EMAIL',
                        m.email ?? '-',
                      ),
                    ),
                  ],
                ),
              ],
              if (m.noKk != null && m.noKk!.isNotEmpty) ...[
                const SizedBox(height: 14),
                _profileField(
                  isEn ? 'FAMILY CARD NO. (KK)' : 'NO. KARTU KELUARGA (KK)',
                  m.noKk!,
                ),
              ],
              if (m.address != null && m.address!.isNotEmpty) ...[
                const SizedBox(height: 14),
                _profileField(
                  isEn ? 'DOMICILE ADDRESS' : 'ALAMAT DOMISILI',
                  m.address!,
                  multiLine: true,
                ),
              ],
              if (m.healthStatus != null) ...[
                const SizedBox(height: 14),
                _profileField(
                  isEn ? 'HEALTH NOTES' : 'CATATAN KESEHATAN',
                  m.healthStatus!,
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Quick jump to Last Checkup tab inside the same modal
        InkWell(
          onTap: () => setState(() => _activeTab = 1),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: widget.themeAccent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: widget.themeAccent.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.assignment_turned_in_rounded,
                  color: widget.themeAccent,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEn
                            ? 'Inspect Last Checkup & Details'
                            : 'Cek Pemeriksaan Terakhir & Detail',
                        style: GoogleFonts.outfit(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: widget.themeAccent,
                        ),
                      ),
                      Text(
                        m.lastCheckup != null
                            ? (isEn
                                ? '${m.checkups.length} record(s) available • Latest: ${AppTranslations.formatDate(m.lastCheckup!.checkupDate, lang: widget.lang)}'
                                : '${m.checkups.length} rekam tersedia • Terbaru: ${AppTranslations.formatDate(m.lastCheckup!.checkupDate, lang: widget.lang)}')
                            : (isEn
                                ? 'No checkup record yet'
                                : 'Belum ada catatan pemeriksaan'),
                        style: GoogleFonts.outfit(
                          fontSize: 10.5,
                          color: widget.bodyText,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_rounded,
                  size: 18,
                  color: widget.themeAccent,
                ),
              ],
            ),
          ),
        ),

        if (m.isMother) ...[
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => widget.onNavigate('momicare_pregnancy'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE91E63),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.pregnant_woman_rounded, size: 17),
            label: Text(
              isEn
                  ? 'Open Maternal Care (MomiCare)'
                  : 'Buka Pantauan Kandungan (MomiCare)',
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _profileField(String label, String value, {bool multiLine = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 9,
            fontWeight: FontWeight.w900,
            color: widget.bodyText.withValues(alpha: 0.75),
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: widget.textColor,
            height: 1.35,
          ),
          maxLines: multiLine ? 4 : 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  // ── TAB 1: LAST CHECKUP & IN-MODAL DETAIL PEMERIKSAAN ─────────────────────

  Widget _buildCheckupTab(PasienChildModel m) {
    final isEn = widget.isEn;

    if (m.checkups.isEmpty) {
      return Container(
        key: const ValueKey('checkup_empty'),
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: widget.themeAccent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.medical_information_outlined,
                size: 30,
                color: widget.themeAccent,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              isEn
                  ? 'No Checkup Record Found'
                  : 'Belum Ada Riwayat Pemeriksaan',
              style: GoogleFonts.outfit(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: widget.textColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              isEn
                  ? '${m.name} does not have a completed medical examination yet.'
                  : '${m.name} belum memiliki catatan hasil pemeriksaan dokter atau puskesmas.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 11.5,
                color: widget.bodyText,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () => widget.onNavigate('dokter_search'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: widget.themeAccent,
                    side: BorderSide(
                      color: widget.themeAccent.withValues(alpha: 0.4),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.medical_services_rounded, size: 15),
                  label: Text(
                    isEn ? 'Find Doctor' : 'Cari Dokter',
                    style: GoogleFonts.outfit(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => widget.onNavigate('puskesmas_search'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: widget.themeAccent,
                    side: BorderSide(
                      color: widget.themeAccent.withValues(alpha: 0.4),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.domain_rounded, size: 15),
                  label: Text(
                    isEn ? 'Find Puskesmas' : 'Cari Puskesmas',
                    style: GoogleFonts.outfit(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    if (_selectedCheckup != null) {
      return _buildInlineCheckupDetailView(
        _selectedCheckup!,
        isLatest: _selectedCheckup!.id == m.checkups.first.id,
      );
    }

    final latest = m.checkups.first;
    final previous = m.checkups.skip(1).toList();

    return Column(
      key: const ValueKey('checkup_summary'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Highlighted Last Checkup Card ─────────────────────────────────
        InkWell(
          onTap: () => _openCheckupDetailInModal(latest),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  widget.themeAccent.withValues(alpha: widget.isDark ? 0.16 : 0.08),
                  widget.themeAccent.withValues(alpha: 0.02),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: widget.themeAccent.withValues(alpha: 0.4),
                width: 1.2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: widget.themeAccent,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isEn ? 'LAST CHECKUP' : 'PEMERIKSAAN TERAKHIR',
                        style: GoogleFonts.outfit(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      AppTranslations.formatDate(
                        latest.checkupDate,
                        lang: widget.lang,
                      ),
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: widget.textColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  latest.examinerName,
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: widget.textColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  latest.facilityName +
                      (latest.queueNumber != null
                          ? ' • Antrian ${latest.queueNumber}'
                          : ''),
                  style: GoogleFonts.outfit(
                    fontSize: 11.5,
                    color: widget.bodyText,
                  ),
                ),
                if (latest.mainComplaint != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: widget.cardBg.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: widget.borderColor),
                    ),
                    child: Text(
                      '${isEn ? "Complaint" : "Keluhan"}: ${latest.mainComplaint}',
                      style: GoogleFonts.outfit(
                        fontSize: 11.5,
                        color: widget.textColor,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
                if (latest.diagnoses.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: latest.diagnoses.map((d) {
                      final label = (d['code']?.isNotEmpty == true)
                          ? '${d['code']} - ${d['description']}'
                          : (d['description'] ?? '-');
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF27AE60).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          label,
                          style: GoogleFonts.outfit(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF27AE60),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
                if (latest.vitals != null) ...[
                  const SizedBox(height: 12),
                  _buildVitalsChipsWrap(latest.vitals!),
                ],
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _openCheckupDetailInModal(latest),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.themeAccent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(11),
                      ),
                    ),
                    icon: const Icon(Icons.visibility_rounded, size: 16),
                    label: Text(
                      isEn
                          ? 'Check Full Examination Detail'
                          : 'Cek Detail Pemeriksaan',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Previous Checkups List (Click opens detail in THIS modal!) ────
        if (previous.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text(
            isEn
                ? 'PREVIOUS CHECKUPS (${previous.length})'
                : 'RIWAYAT PEMERIKSAAN SEBELUMNYA (${previous.length})',
            style: GoogleFonts.outfit(
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
              color: widget.bodyText,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 8),
          ...previous.map((item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () => _openCheckupDetailInModal(item),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: widget.isDark
                        ? const Color(0xFF1E1E24)
                        : const Color(0xFFF8F9FC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: widget.borderColor),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: widget.themeAccent.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          item.isVitaScale
                              ? Icons.child_care_rounded
                              : Icons.medical_services_outlined,
                          size: 17,
                          color: widget.themeAccent,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.examinerName,
                              style: GoogleFonts.outfit(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: widget.textColor,
                              ),
                            ),
                            Text(
                              '${AppTranslations.formatDate(item.checkupDate, lang: widget.lang)}'
                              '${item.primaryDiagnosisText != null ? ' • ${item.primaryDiagnosisText}' : (item.mainComplaint != null ? ' • ${item.mainComplaint}' : '')}',
                              style: GoogleFonts.outfit(
                                fontSize: 10.5,
                                color: widget.bodyText,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isEn ? 'Detail' : 'Cek Detail',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: widget.themeAccent,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 16,
                        color: widget.themeAccent,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ],
    );
  }

  // ── IN-MODAL DETAIL PEMERIKSAAN VIEW (NO SECOND MODAL) ────────────────────

  Widget _buildInlineCheckupDetailView(
    FamilyCheckupRecord record, {
    required bool isLatest,
  }) {
    final isEn = widget.isEn;
    final meds = _medicinesCache[record.id] ?? record.medicines;

    return Column(
      key: ValueKey('checkup_detail_${record.id}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Back Bar inside the same modal
        Row(
          children: [
            InkWell(
              onTap: () => setState(() => _selectedCheckup = null),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: widget.themeAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: widget.themeAccent.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.arrow_back_rounded,
                      size: 15,
                      color: widget.themeAccent,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isEn ? 'Back to Summary' : 'Kembali ke Ringkasan',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: widget.themeAccent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: (isLatest ? widget.themeAccent : widget.bodyText)
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                isLatest
                    ? (isEn ? 'LAST CHECKUP' : 'PEMERIKSAAN TERAKHIR')
                    : AppTranslations.formatDate(
                        record.checkupDate,
                        lang: widget.lang,
                      ),
                style: GoogleFonts.outfit(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w900,
                  color: isLatest ? widget.themeAccent : widget.bodyText,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Examiner & Facility Card
        _detailSectionTitle(
          isEn ? 'EXAMINER & FACILITY' : 'PEMERIKSA & FASKES',
        ),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: widget.isDark
                ? const Color(0xFF1E1E24)
                : const Color(0xFFF8F9FC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: widget.borderColor),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: widget.themeAccent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  record.isVitaScale
                      ? Icons.child_care_rounded
                      : Icons.medical_services_rounded,
                  size: 18,
                  color: widget.themeAccent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.examinerName,
                      style: GoogleFonts.outfit(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: widget.textColor,
                      ),
                    ),
                    Text(
                      record.facilityName,
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        color: widget.bodyText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      AppTranslations.formatDate(
                            record.checkupDate,
                            lang: widget.lang,
                          ) +
                          (record.timeLabel.isNotEmpty
                              ? ' • ${record.timeLabel}'
                              : '') +
                          (record.queueNumber != null
                              ? ' • No. ${record.queueNumber}'
                              : ''),
                      style: GoogleFonts.outfit(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: widget.themeAccent,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        if (record.isVitaScale && record.vitascaleVisit != null) ...[
          const SizedBox(height: 16),
          _buildVitaScaleDetailSection(record.vitascaleVisit!),
        ] else ...[
          // Vital Signs
          if (record.vitals != null) ...[
            const SizedBox(height: 16),
            _detailSectionTitle(isEn ? 'VITAL SIGNS' : 'TANDA-TANDA VITAL'),
            _buildVitalsChipsWrap(record.vitals!),
          ],

          // Complaint & Anamnesis
          if (record.mainComplaint != null ||
              record.anamnesis != null ||
              record.allergies.isNotEmpty ||
              record.medicationTherapy != null ||
              record.nonMedicationTherapy != null ||
              record.prognosis != null) ...[
            const SizedBox(height: 16),
            _detailSectionTitle(
              isEn ? 'COMPLAINT & ANAMNESIS' : 'KELUHAN & ANAMNESIS',
            ),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: widget.isDark
                    ? const Color(0xFF1E1E24)
                    : const Color(0xFFF8F9FC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: widget.borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (record.mainComplaint != null) ...[
                    _kvBlock(
                      isEn ? 'Chief Complaint' : 'Keluhan Utama',
                      record.mainComplaint!,
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (record.anamnesis != null) ...[
                    _kvBlock(
                      isEn ? 'Anamnesis Notes' : 'Catatan Anamnesis',
                      record.anamnesis!,
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (record.allergies.isNotEmpty) ...[
                    _kvBlock(
                      isEn ? 'Allergy History' : 'Riwayat Alergi',
                      record.allergies.entries
                          .map((e) => '${e.key}: ${e.value}')
                          .join(' • '),
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (record.medicationTherapy != null) ...[
                    _kvBlock(
                      isEn ? 'Medication Therapy' : 'Terapi Obat',
                      record.medicationTherapy!,
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (record.nonMedicationTherapy != null) ...[
                    _kvBlock(
                      isEn ? 'Non-Medication Therapy' : 'Terapi Non-Obat',
                      record.nonMedicationTherapy!,
                    ),
                    const SizedBox(height: 10),
                  ],
                  if (record.prognosis != null)
                    _kvBlock('Prognosis', record.prognosis!),
                ],
              ),
            ),
          ],

          // Diagnoses
          if (record.diagnoses.isNotEmpty) ...[
            const SizedBox(height: 16),
            _detailSectionTitle(
              isEn ? 'DIAGNOSIS (ICD-10)' : 'DIAGNOSIS (ICD-10)',
            ),
            ...record.diagnoses.map((diag) {
              final code = diag['code'] ?? '';
              final desc = diag['description'] ?? '-';
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: widget.isDark
                      ? const Color(0xFF1E1E24)
                      : const Color(0xFFF8F9FC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: widget.borderColor),
                ),
                child: Row(
                  children: [
                    if (code.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2.5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          code,
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Colors.redAccent,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: Text(
                        desc,
                        style: GoogleFonts.outfit(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: widget.textColor,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],

          // Medicines / Prescriptions
          const SizedBox(height: 16),
          _detailSectionTitle(
            isEn ? 'PRESCRIPTION / MEDICATION' : 'RESEP OBAT / MEDIKASI',
          ),
          if (_isLoadingMedicines)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: widget.isDark
                    ? const Color(0xFF1E1E24)
                    : const Color(0xFFF8F9FC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: widget.borderColor),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: widget.themeAccent,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    isEn ? 'Loading medication list...' : 'Memuat daftar obat...',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      color: widget.bodyText,
                    ),
                  ),
                ],
              ),
            )
          else if (meds.isEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: widget.isDark
                    ? const Color(0xFF1E1E24)
                    : const Color(0xFFF8F9FC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: widget.borderColor),
              ),
              child: Text(
                isEn
                    ? 'No medication prescribed in this visit.'
                    : 'Tidak ada resep obat tercatat pada pemeriksaan ini.',
                style: GoogleFonts.outfit(fontSize: 11, color: widget.bodyText),
              ),
            )
          else
            ...meds.map((med) {
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: widget.isDark
                      ? const Color(0xFF1E1E24)
                      : const Color(0xFFF8F9FC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: widget.borderColor),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.medication_rounded,
                      size: 16,
                      color: widget.themeAccent,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        med['name']?.toString() ?? 'Obat',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: widget.textColor,
                        ),
                      ),
                    ),
                    Text(
                      '${med['quantity'] ?? 1} Unit (${med['rules'] ?? 'Sesuai petunjuk'})',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: widget.bodyText,
                      ),
                    ),
                  ],
                ),
              );
            }),

          // Referral Letter (inline inside the same modal)
          if (record.rujukan != null) ...[
            const SizedBox(height: 16),
            _detailSectionTitle(
              isEn ? 'REFERRAL LETTER' : 'SURAT RUJUKAN ELEKTRONIK',
            ),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF3498DB).withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF3498DB).withValues(alpha: 0.25),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _kvBlock(
                    isEn ? 'Referral Number' : 'No. Rujukan',
                    record.rujukan!['nomor'] ?? '-',
                  ),
                  const SizedBox(height: 6),
                  _kvBlock(
                    isEn ? 'Referred Hospital' : 'Rumah Sakit Tujuan',
                    record.rujukan!['rumah_sakit'] ?? '-',
                  ),
                  const SizedBox(height: 6),
                  _kvBlock(
                    isEn ? 'Specialist Clinic' : 'Poli Tujuan',
                    record.rujukan!['poli'] ?? '-',
                  ),
                  if ((record.rujukan!['catatan'] ?? '').isNotEmpty) ...[
                    const SizedBox(height: 6),
                    _kvBlock(
                      isEn ? 'Notes' : 'Catatan Rujukan',
                      record.rujukan!['catatan']!,
                    ),
                  ],
                ],
              ),
            ),
          ],

          // Medical Certificate (inline inside the same modal)
          if (record.suratKeterangan != null) ...[
            const SizedBox(height: 16),
            _detailSectionTitle(
              record.suratKeterangan!['type'] == 'sehat'
                  ? (isEn ? 'HEALTH CERTIFICATE' : 'SURAT KETERANGAN SEHAT')
                  : (isEn ? 'SICK LEAVE CERTIFICATE' : 'SURAT KETERANGAN SAKIT'),
            ),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF27AE60).withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF27AE60).withValues(alpha: 0.25),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (record.suratKeterangan!['type'] == 'sehat') ...[
                    _kvBlock(
                      isEn ? 'Condition' : 'Kondisi',
                      isEn ? 'Physically Healthy' : 'Sehat Jasmani & Rohani',
                    ),
                    if ((record.suratKeterangan!['keperluan'] ?? '')
                        .toString()
                        .isNotEmpty) ...[
                      const SizedBox(height: 6),
                      _kvBlock(
                        isEn ? 'Purpose' : 'Keperluan',
                        record.suratKeterangan!['keperluan'].toString(),
                      ),
                    ],
                  ] else ...[
                    _kvBlock(
                      isEn ? 'Rest Duration' : 'Durasi Istirahat',
                      '${record.suratKeterangan!['hari'] ?? 3} ${isEn ? 'Days' : 'Hari'}',
                    ),
                    if ((record.suratKeterangan!['riwayat'] ?? '')
                        .toString()
                        .isNotEmpty) ...[
                      const SizedBox(height: 6),
                      _kvBlock(
                        isEn ? 'Medical Notes' : 'Riwayat / Diagnosis',
                        record.suratKeterangan!['riwayat'].toString(),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildVitaScaleDetailSection(ChildVisitRecord v) {
    final isEn = widget.isEn;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _detailSectionTitle(
          isEn ? 'ANTHROPOMETRY MEASUREMENTS' : 'HASIL PENGUKURAN ANTROPOMETRI',
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _vitalChip(
              isEn ? 'Weight (BB)' : 'Berat Badan',
              '${v.weightKg.toStringAsFixed(1)} kg',
              Icons.monitor_weight_rounded,
            ),
            _vitalChip(
              '${isEn ? 'Height' : 'Tinggi'} (${v.mode})',
              '${v.heightCm.toStringAsFixed(1)} cm',
              Icons.height_rounded,
            ),
            _vitalChip(
              isEn ? 'Waist' : 'Lingkar Perut',
              '${v.waistCm.toStringAsFixed(1)} cm',
              Icons.straighten_rounded,
            ),
            if (v.lilaCm > 0)
              _vitalChip(
                'LiLA',
                '${v.lilaCm.toStringAsFixed(1)} cm',
                Icons.circle_outlined,
              ),
            _vitalChip(
              'WHtR',
              v.heightCm > 0 ? v.whtr.toStringAsFixed(2) : '-',
              Icons.analytics_outlined,
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: v.statusGiziColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: v.statusGiziColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEn ? 'Nutritional Status' : 'Status Gizi',
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        color: widget.bodyText,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      v.statusGizi,
                      style: GoogleFonts.outfit(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                        color: v.statusGiziColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: v.statusStuntingColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: v.statusStuntingColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEn ? 'Stunting Status' : 'Status Stunting',
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        color: widget.bodyText,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      v.statusStunting,
                      style: GoogleFonts.outfit(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                        color: v.statusStuntingColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _detailSectionTitle(
          isEn ? 'CLINICAL GUIDANCE & NUTRITION PLAN' : 'REKOMENDASI & RENCANA GIZI',
        ),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: widget.isDark
                ? const Color(0xFF1E1E24)
                : const Color(0xFFF8F9FC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: widget.borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _kvBlock(
                isEn ? 'Summary' : 'Ringkasan',
                v.reasoningSummary,
              ),
              const SizedBox(height: 10),
              _kvBlock(
                isEn ? 'Nutrition Plan' : 'Rencana Nutrisi',
                v.nutritionPlan,
              ),
              const SizedBox(height: 10),
              _kvBlock(
                isEn ? 'Medical Protocol' : 'Protokol Tindak Lanjut',
                v.medicalProtocol,
              ),
              const SizedBox(height: 10),
              _kvBlock(
                isEn ? 'Parent Guidance' : 'Edukasi Orang Tua',
                v.parentEducation,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVitalsChipsWrap(Map<String, dynamic> vitals) {
    final isEn = widget.isEn;
    final List<Widget> chips = [];

    void addIfValid(String key, String label, String unit, IconData icon) {
      final val = vitals[key]?.toString().trim() ?? '';
      if (val.isNotEmpty && val != '-' && val != 'null') {
        chips.add(_vitalChip(label, '$val $unit'.trim(), icon));
      }
    }

    addIfValid(
      'blood_pressure',
      isEn ? 'BP' : 'Tensi',
      'mmHg',
      Icons.speed_rounded,
    );
    addIfValid(
      'body_temperature',
      isEn ? 'Temp' : 'Suhu',
      '°C',
      Icons.thermostat_rounded,
    );
    addIfValid(
      'heart_rate',
      isEn ? 'Pulse' : 'Nadi',
      'bpm',
      Icons.favorite_rounded,
    );
    addIfValid(
      'oxygen_saturation',
      'SpO2',
      '%',
      Icons.bubble_chart_rounded,
    );
    addIfValid(
      'respiratory_rate',
      isEn ? 'Resp' : 'Napas',
      'x/mnt',
      Icons.air_rounded,
    );
    addIfValid(
      'body_weight',
      isEn ? 'Weight' : 'Berat',
      'kg',
      Icons.monitor_weight_rounded,
    );
    addIfValid(
      'body_height',
      isEn ? 'Height' : 'Tinggi',
      'cm',
      Icons.height_rounded,
    );

    if (chips.isEmpty) {
      return Text(
        isEn ? 'No vital signs recorded.' : 'Tidak ada catatan tanda vital.',
        style: GoogleFonts.outfit(fontSize: 11, color: widget.bodyText),
      );
    }

    return Wrap(spacing: 8, runSpacing: 8, children: chips);
  }

  Widget _vitalChip(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: widget.isDark
            ? const Color(0xFF1E1E24)
            : const Color(0xFFF6F8FA),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: widget.borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: widget.themeAccent),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: GoogleFonts.outfit(
              fontSize: 10.5,
              color: widget.bodyText,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: widget.textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7, left: 2),
      child: Text(
        title,
        style: GoogleFonts.outfit(
          fontSize: 9.5,
          fontWeight: FontWeight.w900,
          color: widget.bodyText.withValues(alpha: 0.75),
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  Widget _kvBlock(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: widget.bodyText,
          ),
        ),
        const SizedBox(height: 2),
        FormattedMarkdownText(
          text: value,
          style: GoogleFonts.outfit(
            fontSize: 11.5,
            color: widget.textColor,
            height: 1.4,
          ),
          boldStyle: GoogleFonts.outfit(
            fontSize: 11.5,
            fontWeight: FontWeight.bold,
            color: widget.themeAccent,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

// ─── Shared Avatar Helper ────────────────────────────────────────────────────

class _MemberAvatar extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final Color avatarColor;
  final double size;
  final bool isMale;
  final bool isChild;

  const _MemberAvatar({
    required this.name,
    this.avatarUrl,
    required this.avatarColor,
    required this.size,
    required this.isMale,
    required this.isChild,
  });

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'A';
    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: avatarColor.withValues(alpha: 0.18),
        shape: BoxShape.circle,
        border: Border.all(
          color: avatarColor.withValues(alpha: 0.45),
          width: 1.5,
        ),
      ),
      child: Center(
        child: isChild
            ? Text(
                initial,
                style: GoogleFonts.outfit(
                  fontSize: size * 0.42,
                  fontWeight: FontWeight.w900,
                  color: avatarColor,
                ),
              )
            : Icon(
                isMale ? Icons.male_rounded : Icons.female_rounded,
                color: avatarColor,
                size: size * 0.54,
              ),
      ),
    );

    if (avatarUrl == null || avatarUrl!.isEmpty) {
      return fallback;
    }

    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(
        child: Image.network(
          avatarUrl!,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => fallback,
        ),
      ),
    );
  }
}
