import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapotech/features/landing/landing_page_data.dart';
import 'package:mapotech/shared/widgets/settings_widgets.dart';
import 'package:mapotech/features/pasien/dashboard/frontend/ai_assistant/presentation/ai_chat_provider.dart';

/// Pengaturan Pasien — dedicated settings page for the masyarakat/pasien role.
class PasienSettings extends ConsumerWidget {
  const PasienSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(landingPageProvider);
    final notifier = ref.read(landingPageProvider.notifier);

    final isEn = state.language == 'en';
    final isDark = state.appearance == 'dark';
    final cardBg = notifier.getCardColor();
    final textColor = notifier.getTextColor();
    final subtitleColor = notifier.getBodyTextColor();
    final borderColor = notifier.getBorderColor();
    final purple = notifier.getPrimaryColor();
    final teal = notifier.getPrimaryColor();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Tema ────────────────────────────────────────────────────────
        SettingsSection(
          title: isEn ? 'Theme' : 'Tema',
          subtitle: isEn
              ? 'Update theme and language settings for your Patient account.'
              : 'Perbarui pengaturan tema dan bahasa akun Pasien Anda.',
          textColor: textColor,
          subtitleColor: subtitleColor,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SettingsChip(
                    label: 'Light',
                    icon: Icons.sunny,
                    isSelected: state.appearance == 'light',
                    onTap: () => notifier.updateAppearance('light'),
                    purple: purple,
                    teal: teal,
                    isDark: isDark,
                    borderColor: borderColor,
                  ),
                  const SizedBox(width: 10),
                  SettingsChip(
                    label: 'Dark',
                    icon: Icons.nightlight_round,
                    isSelected: state.appearance == 'dark',
                    onTap: () => notifier.updateAppearance('dark'),
                    purple: purple,
                    teal: teal,
                    isDark: isDark,
                    borderColor: borderColor,
                  ),
                  const SizedBox(width: 10),
                  SettingsChip(
                    label: 'REV',
                    icon: Icons.palette_rounded,
                    isSelected: state.appearance == 'rev',
                    onTap: () => notifier.updateAppearance('rev'),
                    purple: purple,
                    teal: teal,
                    isDark: isDark,
                    borderColor: borderColor,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEn
                              ? 'Profile Photo Blur Effect'
                              : 'Efek Blur Foto Profil',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: textColor,
                          ),
                        ),
                        Text(
                          isEn
                              ? 'Display blurred profile photo as background in Profile, App Bar, and Drawer'
                              : 'Tampilkan foto profil yang diblur sebagai latar belakang di Profil, App Bar, dan Drawer',
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            color: subtitleColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: state.blurProfileEffectEnabled,
                    activeThumbColor: purple,
                    onChanged: (val) {
                      notifier.setBlurProfileEffect(val);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 28),

        // ── Bahasa ───────────────────────────────────────────────────────
        SettingsSection(
          title: isEn ? 'Language' : 'Bahasa',
          subtitle: isEn
              ? 'Select your preferred language'
              : 'Pilih bahasa pilihan Anda',
          textColor: textColor,
          subtitleColor: subtitleColor,
          child: Row(
            children: [
              SettingsChip(
                label: 'Indonesian',
                isSelected: state.language == 'id',
                onTap: () {
                  notifier.setLanguage('id');
                  ref.read(aiChatProvider.notifier).onLanguageChanged('id');
                },
                purple: purple,
                teal: teal,
                isDark: isDark,
                borderColor: borderColor,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 9,
                ),
              ),
              const SizedBox(width: 10),
              SettingsChip(
                label: 'English',
                isSelected: state.language == 'en',
                onTap: () {
                  notifier.setLanguage('en');
                  ref.read(aiChatProvider.notifier).onLanguageChanged('en');
                },
                purple: purple,
                teal: teal,
                isDark: isDark,
                borderColor: borderColor,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 9,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 28),

        // ── Pengaturan Premium ────────────────────────────────────────────
        SettingsSection(
          title: isEn ? 'Premium Settings' : 'Pengaturan Premium',
          subtitle: isEn
              ? 'Customize your profile with exclusive premium features.'
              : 'Sesuaikan profil Anda dengan fitur premium eksklusif.',
          textColor: textColor,
          subtitleColor: subtitleColor,
          child: _buildPremiumCard(
            isEn,
            isDark,
            textColor,
            subtitleColor,
            borderColor,
            cardBg,
            purple,
          ),
        ),

        const SizedBox(height: 40),

        // ── Laporkan Bug ──────────────────────────────────────────────────
        _buildBugReportSection(
          isEn,
          cardBg,
          borderColor,
          textColor,
          subtitleColor,
          purple,
        ),

        const SizedBox(height: 24),
      ],
    );
  }

  // ─── Premium Card ─────────────────────────────────────────────────────────
  Widget _buildPremiumCard(
    bool isEn,
    bool isDark,
    Color textColor,
    Color subtitleColor,
    Color borderColor,
    Color cardBg,
    Color purple,
  ) {
    final orange = const Color(0xFFF39C12);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 540;

        final leftContent = Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Orange badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: orange.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: orange.withValues(alpha: 0.25)),
                ),
                child: Text(
                  isEn
                      ? 'This feature is only available for Premium members.'
                      : 'Fitur ini hanya tersedia untuk anggota Premium.',
                  style: GoogleFonts.outfit(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: orange,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              Text(
                isEn ? 'Upgrade to Premium' : 'Ayo Jadi Premium',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                isEn
                    ? 'Unlock exclusive customization features including custom GIF backgrounds and theme colors.'
                    : 'Buka fitur kustomisasi eksklusif termasuk latar belakang GIF kustom dan warna tema.',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  color: subtitleColor,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 14),

              // Feature bullets
              Row(
                children: [
                  _premiumFeatureBullet(
                    Icons.color_lens_outlined,
                    isEn ? 'Theme Color' : 'Warna Tema',
                    subtitleColor,
                  ),
                  const SizedBox(width: 16),
                  _premiumFeatureBullet(
                    Icons.image_outlined,
                    isEn ? 'Header Effect' : 'Efek Header',
                    subtitleColor,
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // Upgrade button
              ElevatedButton.icon(
                icon: const Icon(Icons.star_rounded, size: 16),
                label: Text(
                  isEn ? 'Upgrade Now' : 'Upgrade Sekarang',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                onPressed: () {},
              ),
            ],
          ),
        );

        final rightVisual = Container(
          width: isWide ? 140 : double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E22) : const Color(0xFFF9F5FF),
            border: isWide
                ? Border(left: BorderSide(color: borderColor))
                : Border(top: BorderSide(color: borderColor)),
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2A2A30) : Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: purple.withValues(alpha: 0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.star_rounded,
                  color: Color(0xFFF1C40F),
                  size: 36,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'EXCLUSIVE',
                style: GoogleFonts.outfit(
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  color: purple.withValues(alpha: 0.6),
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        );

        return Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor),
          ),
          clipBehavior: Clip.antiAlias,
          child: isWide
              ? IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: leftContent),
                      rightVisual,
                    ],
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    leftContent,
                    rightVisual,
                  ],
                ),
        );
      },
    );
  }

  Widget _premiumFeatureBullet(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 5),
        Text(label, style: GoogleFonts.outfit(fontSize: 11, color: color)),
      ],
    );
  }

  // ─── Laporkan Bug ─────────────────────────────────────────────────────────
  Widget _buildBugReportSection(
    bool isEn,
    Color cardBg,
    Color border,
    Color textColor,
    Color subtitleColor,
    Color purple,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: purple.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.bug_report_outlined,
              size: 26,
              color: purple.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            isEn ? 'Report a Bug' : 'Laporkan Bug',
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: textColor,
            ),
          ),
          const SizedBox(height: 4),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: GoogleFonts.outfit(fontSize: 11, color: subtitleColor),
              children: [
                TextSpan(
                  text: isEn
                      ? 'Found an issue? Report it to our\n'
                      : 'Menemukan masalah? Laporkan ke tim\n',
                ),
                TextSpan(
                  text: isEn ? 'team.' : 'kami.',
                  style: GoogleFonts.outfit(fontSize: 11, color: subtitleColor),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () {},
            style: OutlinedButton.styleFrom(
              foregroundColor: textColor,
              side: BorderSide(color: border),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              isEn ? 'Report Bug' : 'Laporkan Bug',
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
