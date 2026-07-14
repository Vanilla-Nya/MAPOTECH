import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapotech/features/landing/landing_page_data.dart';
import 'package:mapotech/shared/supabase_service.dart';
import 'package:mapotech/shared/widgets/profile_widgets.dart';

/// Profil Apotek — dedicated profile page for the apotek role with subscription checks.
class ApotekProfile extends ConsumerStatefulWidget {
  const ApotekProfile({super.key});

  @override
  ConsumerState<ApotekProfile> createState() => _ApotekProfileState();
}

class _ApotekProfileState extends ConsumerState<ApotekProfile> {
  bool _isLoading = true;
  bool _isSaving = false;

  // Subscription Details
  String _subStatus = 'INACTIVE';
  String _subExpiry = '-';
  int _subDaysRemaining = 0;
  int _subHoursRemaining = 0;
  int _subMinutesRemaining = 0;
  int _subTotalDays = 30; // default plan length
  DateTime? _subExpiryDate;

  late TextEditingController _addressController;
  late TextEditingController _mapsLinkController;

  @override
  void initState() {
    super.initState();
    _addressController = TextEditingController();
    _mapsLinkController = TextEditingController();
    _fetchDbData();
  }

  @override
  void dispose() {
    _addressController.dispose();
    _mapsLinkController.dispose();
    super.dispose();
  }

  Future<void> _fetchDbData() async {
    final state = ref.read(landingPageProvider);
    final userId = state.activeApotekId;
    if (userId == null) return;

    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final client = SupabaseService.client;

      final detailRes = await client
          .from('user_detail_pharmacist')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (!mounted) return;
      if (detailRes != null) {
        _addressController.text = detailRes['alamat']?.toString() ??
            'Apotek CyrenElysia Cabang Utama Pujer, Jl. Raya Pujer No. 45, Kel. KEJAYAN, Kec. PUJER, KABUPATEN BONDOWOSO';
        _mapsLinkController.text = detailRes['google_maps_link']?.toString() ?? '';

        // Parse subscription details
        _subStatus = (detailRes['subscription_status'] ?? 'INACTIVE')
            .toString()
            .toUpperCase();
        if (detailRes['subscription_expired_at'] != null) {
          try {
            final expiryDate = DateTime.parse(
              detailRes['subscription_expired_at'].toString(),
            );
            _subExpiryDate = expiryDate;
            const months = [
              'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
              'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
            ];
            _subExpiry =
                '${expiryDate.day.toString().padLeft(2, '0')} '
                '${months[expiryDate.month - 1]} ${expiryDate.year}';

            final now = DateTime.now();
            final diff = expiryDate.difference(now);
            if (diff.isNegative) {
              _subDaysRemaining = 0;
              _subHoursRemaining = 0;
              _subMinutesRemaining = 0;
            } else {
              _subDaysRemaining = diff.inDays;
              _subHoursRemaining = diff.inHours % 24;
              _subMinutesRemaining = diff.inMinutes % 60;
            }
          } catch (_) {
            _subExpiry = '-';
            _subExpiryDate = null;
            _subDaysRemaining = 0;
            _subHoursRemaining = 0;
            _subMinutesRemaining = 0;
          }
        } else {
          _subExpiry = '-';
          _subExpiryDate = null;
          _subDaysRemaining = 0;
          _subHoursRemaining = 0;
          _subMinutesRemaining = 0;
        }
      }

      final bool isSubActive = _subStatus == 'ACTIVE' && _subExpiryDate != null && _subExpiryDate!.isAfter(DateTime.now());
      ref.read(landingPageProvider.notifier).setSubscribed(isSubActive);
    } catch (e) {
      debugPrint('Error fetching apotek profile: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _renewSubscription() async {
    final state = ref.read(landingPageProvider);
    final userId = state.activeApotekId;
    if (userId == null) return;

    setState(() => _isSaving = true);

    try {
      final client = SupabaseService.client;

      final res = await client
          .from('user_detail_pharmacist')
          .select('subscription_expired_at')
          .eq('id', userId)
          .maybeSingle();

      DateTime currentExpiry = DateTime.now();
      if (res != null && res['subscription_expired_at'] != null) {
        try {
          final parsed = DateTime.parse(res['subscription_expired_at']);
          if (parsed.isAfter(DateTime.now())) {
            currentExpiry = parsed;
          }
        } catch (_) {}
      }

      final newExpiry = currentExpiry.add(const Duration(days: 30));
      final newExpiryStr = newExpiry.toIso8601String();

      await client
          .from('user_detail_pharmacist')
          .update({
            'subscription_status': 'active',
            'subscription_expired_at': newExpiryStr,
          })
          .eq('id', userId);

      await _fetchDbData();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Apotek Subscription successfully renewed for 30 Days! New expiry: $_subExpiry',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error renewing apotek subscription: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _saveApotekLocation() async {
    final state = ref.read(landingPageProvider);
    final userId = state.activeApotekId;
    if (userId == null) return;

    setState(() => _isSaving = true);

    try {
      final client = SupabaseService.client;
      final mapsLink = _mapsLinkController.text.trim();
      final latLng = SupabaseService.extractLatLngFromMapsLink(mapsLink);

      await client
          .from('user_detail_pharmacist')
          .update({
            'alamat': _addressController.text.trim(),
            'google_maps_link': mapsLink,
            'latitude': latLng['latitude'],
            'longitude': latLng['longitude'],
          })
          .eq('id', userId);

      await _fetchDbData();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lokasi & alamat apotek berhasil disimpan!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menyimpan lokasi apotek: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(landingPageProvider);

    final isDark = state.appearance == 'dark';
    final isRev = state.appearance == 'rev';
    final cardBg = isDark ? const Color(0xFF161619) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1B0C3C);
    final subtitleColor = isDark ? Colors.grey[400]! : const Color(0xFF6F6A8A);
    final borderColor = isDark ? const Color(0xFF252528) : const Color(0xFFECEEF2);
    final inputBg = isDark ? const Color(0xFF1E1E22) : const Color(0xFFF3F0FA);
    final purple = const Color(0xFFB577F2);
    final green = const Color(0xFF48C9B0);

    final bool isSubActive = _subStatus == 'ACTIVE' && _subExpiryDate != null && _subExpiryDate!.isAfter(DateTime.now());

    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Hero Banner ───────────────────────────────────────────────────
        _buildHeroBanner(isDark, isRev, textColor, subtitleColor, purple, green, cardBg),

        const SizedBox(height: 20),

        // AbsorbPointer blocks modifications if subscription is not active
        AbsorbPointer(
          absorbing: !isSubActive,
          child: Opacity(
            opacity: isSubActive ? 1.0 : 0.6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Kredensial Apotek & Izin Operasional ─────────────────────────
                ProfileSectionCard(
                  icon: Icons.assignment_ind_rounded,
                  title: 'Kredensial Apotek & Izin Operasional',
                  cardBg: cardBg,
                  border: borderColor,
                  textColor: textColor,
                  iconColor: purple,
                  child: Column(
                    children: [
                      ProfileInfoRow(
                        label: 'Nomor SIA (Surat Izin Apotek):',
                        value: 'SIA/503.22/012/2026',
                        subtitleColor: subtitleColor,
                        valueColor: textColor,
                        inputBg: inputBg,
                      ),
                      const SizedBox(height: 8),
                      ProfileInfoRow(
                        label: 'Apoteker Penanggung Jawab (APJ):',
                        value: 'Cyren Elysia, S.Farm., Apt.',
                        subtitleColor: subtitleColor,
                        valueColor: textColor,
                        inputBg: inputBg,
                      ),
                      const SizedBox(height: 8),
                      ProfileInfoRow(
                        label: 'Nomor SIPA (Apoteker):',
                        value: 'SIPA/3511/2026/2001',
                        subtitleColor: subtitleColor,
                        valueColor: textColor,
                        inputBg: inputBg,
                      ),
                      const SizedBox(height: 8),
                      ProfileInfoRow(
                        label: 'Integrasi Kemenkes SatuSehat:',
                        value: 'TERHUBUNG (SIMONA INTEGRATED)',
                        subtitleColor: subtitleColor,
                        valueColor: green,
                        rightBold: true,
                        inputBg: inputBg,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── Jadwal Operasional Apotek ─────────────────────────────────────
                ProfileSectionCard(
                  icon: Icons.calendar_today_rounded,
                  title: 'Jadwal Operasional Apotek',
                  cardBg: cardBg,
                  border: borderColor,
                  textColor: textColor,
                  iconColor: purple,
                  child: Column(
                    children: [
                      ProfileInfoRow(
                        label: 'Senin - Minggu:',
                        value: 'BUKA 24 JAM',
                        subtitleColor: subtitleColor,
                        valueColor: green,
                        rightBold: true,
                        inputBg: inputBg,
                      ),
                      const SizedBox(height: 8),
                      ProfileInfoRow(
                        label: 'Pelayanan Resep Dokter:',
                        value: 'Tersedia 24 Jam (Apoteker Standby)',
                        subtitleColor: subtitleColor,
                        valueColor: textColor,
                        inputBg: inputBg,
                      ),
                      const SizedBox(height: 8),
                      ProfileInfoRow(
                        label: 'Shift Pagi:',
                        value: '07:00 - 15:00 WIB',
                        subtitleColor: subtitleColor,
                        valueColor: textColor,
                        inputBg: inputBg,
                      ),
                      const SizedBox(height: 8),
                      ProfileInfoRow(
                        label: 'Shift Sore:',
                        value: '15:00 - 22:00 WIB',
                        subtitleColor: subtitleColor,
                        valueColor: textColor,
                        inputBg: inputBg,
                      ),
                      const SizedBox(height: 8),
                      ProfileInfoRow(
                        label: 'Shift Malam:',
                        value: '22:00 - 07:00 WIB',
                        subtitleColor: subtitleColor,
                        valueColor: textColor,
                        inputBg: inputBg,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── Informasi Bisnis & Perusahaan ─────────────────────────────────
                ProfileSectionCard(
                  icon: Icons.business_center_rounded,
                  title: 'Informasi Bisnis & Perusahaan',
                  cardBg: cardBg,
                  border: borderColor,
                  textColor: textColor,
                  iconColor: purple,
                  trailing: _buildResetPasswordButton(subtitleColor),
                  child: Column(
                    children: [
                      ProfileFieldGrid(
                        children: [
                          ProfileField(
                            label: 'Nama Perusahaan',
                            value: 'Apotek CyrenElysia Group',
                            inputBg: inputBg,
                            valueColor: textColor,
                            subtitleColor: subtitleColor,
                            icon: Icons.business_outlined,
                          ),
                          ProfileField(
                            label: 'NIB (No. Induk Berusaha)',
                            value: '9120003445566',
                            inputBg: inputBg,
                            valueColor: textColor,
                            subtitleColor: subtitleColor,
                            icon: Icons.badge_outlined,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ProfileFieldGrid(
                        children: [
                          ProfileField(
                            label: 'NPWP Badan Usaha',
                            value: '01.234.567.8-009.000',
                            inputBg: inputBg,
                            valueColor: textColor,
                            subtitleColor: subtitleColor,
                            icon: Icons.receipt_long_outlined,
                          ),
                          ProfileField(
                            label: 'Tanggal Berdiri',
                            value: '12 / 08 / 2020',
                            inputBg: inputBg,
                            valueColor: textColor,
                            subtitleColor: subtitleColor,
                            icon: Icons.cake_outlined,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ProfileField(
                        label: 'Jenis Kepemilikan',
                        value: 'Swasta / Badan Hukum Mandiri',
                        inputBg: inputBg,
                        valueColor: textColor,
                        subtitleColor: subtitleColor,
                        icon: Icons.apartment_rounded,
                        fullWidth: true,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── Alamat & Cabang Apotek ─────────────────────────────────────────
                ProfileSectionCard(
                  icon: Icons.location_on_outlined,
                  title: 'Lokasi & Cabang Utama Apotek',
                  cardBg: cardBg,
                  border: borderColor,
                  textColor: textColor,
                  iconColor: purple,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ProfileFieldGrid(
                        children: [
                          ProfileDropdownField(
                            label: 'Provinsi',
                            value: 'JAWA TIMUR',
                            inputBg: inputBg,
                            textColor: textColor,
                            subtitleColor: subtitleColor,
                            borderTint: purple,
                          ),
                          ProfileDropdownField(
                            label: 'Kota/Kabupaten',
                            value: 'KABUPATEN BONDOWOSO',
                            inputBg: inputBg,
                            textColor: textColor,
                            subtitleColor: subtitleColor,
                            borderTint: purple,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ProfileFieldGrid(
                        children: [
                          ProfileDropdownField(
                            label: 'Kecamatan',
                            value: 'PUJER',
                            inputBg: inputBg,
                            textColor: textColor,
                            subtitleColor: subtitleColor,
                            borderTint: purple,
                          ),
                          ProfileDropdownField(
                            label: 'Kelurahan/Desa',
                            value: 'KEJAYAN',
                            inputBg: inputBg,
                            textColor: textColor,
                            subtitleColor: subtitleColor,
                            borderTint: purple,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Alamat Lengkap Apotek (Rincian Surat)',
                        style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w700, color: subtitleColor),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        decoration: BoxDecoration(
                          color: inputBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: borderColor),
                        ),
                        padding: const EdgeInsets.all(12),
                        child: TextField(
                          controller: _addressController,
                          maxLines: 2,
                          style: GoogleFonts.outfit(fontSize: 12, color: textColor),
                          decoration: InputDecoration(
                            hintText: 'Apotek CyrenElysia Cabang Utama Pujer, Jl. Raya Pujer No. 45, Kel. KEJAYAN, Kec. PUJER, KABUPATEN BONDOWOSO',
                            hintStyle: GoogleFonts.outfit(fontSize: 11, color: subtitleColor.withOpacity(0.6)),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Google Maps Link Apotek',
                        style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w700, color: subtitleColor),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        decoration: BoxDecoration(
                          color: inputBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: borderColor),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: TextField(
                          controller: _mapsLinkController,
                          style: GoogleFonts.outfit(fontSize: 12, color: textColor),
                          decoration: InputDecoration(
                            hintText: 'https://www.google.com/maps/place/...',
                            hintStyle: GoogleFonts.outfit(fontSize: 11, color: subtitleColor.withOpacity(0.6)),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _isSaving ? null : _saveApotekLocation,
                            icon: _isSaving
                                ? const SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.save_rounded, size: 14),
                            label: const Text('SIMPAN LOKASI'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: purple,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              textStyle: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
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
        ),

        const SizedBox(height: 20),

        // ── Card: Subscription Status (Always Active / Editable) ──
        _buildSubscriptionStatusCard(isDark, cardBg, textColor, subtitleColor, borderColor, inputBg, green, purple),

        const SizedBox(height: 24),
      ],
    );
  }

  // ─── Hero Banner ──────────────────────────────────────────────────────────
  Widget _buildHeroBanner(
    bool isDark,
    bool isRev,
    Color textColor,
    Color subtitleColor,
    Color purple,
    Color green,
    Color cardBg,
  ) {
    return Container(
      height: 170,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E1E22), const Color(0xFF161619)]
              : [const Color(0xFFEAFAF1), const Color(0xFFD4EFDF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: -30,
            top: -30,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: green.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            right: -20,
            bottom: -20,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: green.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),

          // Content
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Avatar
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2E2E35) : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'CE',
                      style: GoogleFonts.outfit(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: green,
                      ),
                    ),
                  ),
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: green,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 11),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              Text(
                'Apotek CyrenElysia',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : const Color(0xFF196F3D),
                ),
              ),
              Text(
                'Apotek Terstandarisasi • SIA Aktif',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: (isDark ? Colors.white : const Color(0xFF196F3D)).withOpacity(0.6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResetPasswordButton(Color subtitle) {
    return TextButton.icon(
      icon: Icon(Icons.lock_reset_rounded, size: 13, color: subtitle),
      label: Text(
        'Reset Sandi',
        style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w700, color: subtitle),
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password reset link sent to your email!'),
            backgroundColor: Colors.purple,
          ),
        );
      },
    );
  }

  Widget _buildSubscriptionStatusCard(
    bool isDark,
    Color cardBg,
    Color textColor,
    Color subtitleColor,
    Color borderColor,
    Color inputBg,
    Color activeColor,
    Color premiumColor,
  ) {
    final isActive = _subStatus == 'ACTIVE';
    final statusColor = isActive ? activeColor : Colors.orangeAccent;
    final progress = _subTotalDays > 0 ? (_subDaysRemaining / _subTotalDays).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive ? activeColor.withOpacity(0.35) : Colors.orangeAccent.withOpacity(0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isActive ? Icons.verified_rounded : Icons.calendar_month_outlined,
                  color: statusColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Apotek Subscription Status',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: textColor,
                      ),
                    ),
                    Text(
                      isActive ? 'Your apotek subscription is active' : 'Apotek subscription is inactive/expired',
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: subtitleColor,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: statusColor.withOpacity(0.4)),
                ),
                child: Text(
                  _subStatus,
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: statusColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          if (isActive && _subDaysRemaining > 0) ...[
            Row(
              children: [
                Expanded(child: _buildTimeBox('$_subDaysRemaining', 'Days', statusColor)),
                const SizedBox(width: 8),
                Expanded(child: _buildTimeBox('$_subHoursRemaining', 'Hours', statusColor)),
                const SizedBox(width: 8),
                Expanded(child: _buildTimeBox('$_subMinutesRemaining', 'Minutes', statusColor)),
              ],
            ),
            const SizedBox(height: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Time Remaining',
                      style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w600, color: subtitleColor),
                    ),
                    Text(
                      '${(progress * 100).toStringAsFixed(0)}%',
                      style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: statusColor),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(100),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: statusColor.withOpacity(0.12),
                    valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                    minHeight: 8,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ] else if (!isActive) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              decoration: BoxDecoration(
                color: Colors.orangeAccent.withOpacity(0.07),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orangeAccent.withOpacity(0.25)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: Colors.orangeAccent, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Subscribe to unlock all features, POS sales, and inventory management.',
                      style: GoogleFonts.outfit(fontSize: 12, color: Colors.orangeAccent, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          Container(
            decoration: BoxDecoration(
              color: inputBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: [
                _buildSubStatusRow('Expiry Date:', _subExpiry, textColor, isDark),
                const Divider(height: 1),
                _buildSubStatusRow('Days Left:', isActive ? '$_subDaysRemaining days' : 'N/A', isActive ? activeColor : Colors.orangeAccent, isDark, showBold: true),
              ],
            ),
          ),

          const SizedBox(height: 16),

          ElevatedButton.icon(
            onPressed: _isSaving ? null : _renewSubscription,
            icon: Icon(_isSaving ? Icons.hourglass_top_rounded : Icons.sync, size: 16),
            label: Text(_isSaving ? 'Renewing...' : 'Renew 30 Days'),
            style: ElevatedButton.styleFrom(
              backgroundColor: premiumColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              textStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeBox(String value, String label, Color accentColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: accentColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(
            value.padLeft(2, '0'),
            style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.w900, color: accentColor),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w700, color: accentColor.withOpacity(0.7), letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }

  Widget _buildSubStatusRow(
    String label,
    String value,
    Color valColor,
    bool isDark, {
    bool showBold = false,
    double valueSize = 12,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: valueSize,
              fontWeight: showBold ? FontWeight.w900 : FontWeight.w600,
              color: valColor,
            ),
          ),
        ],
      ),
    );
  }
}
