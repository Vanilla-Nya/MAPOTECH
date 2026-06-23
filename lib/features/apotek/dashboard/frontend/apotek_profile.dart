import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapotech/features/landing/landing_page_data.dart';
import 'package:mapotech/shared/widgets/profile_widgets.dart';

/// Profil Apotek — dedicated profile page for the apotek role.
class ApotekProfile extends ConsumerWidget {
  const ApotekProfile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Hero Banner ───────────────────────────────────────────────────
        _buildHeroBanner(isDark, isRev, textColor, subtitleColor, purple, green, cardBg),

        const SizedBox(height: 20),

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
            ],
          ),
        ),

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
      onPressed: () {},
    );
  }
}
