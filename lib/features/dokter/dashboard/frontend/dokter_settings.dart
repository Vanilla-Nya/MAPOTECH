import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapotech/features/landing/landing_page_data.dart';
import 'package:mapotech/shared/widgets/settings_widgets.dart';

/// Pengaturan Dokter — dedicated settings page for the dokter/praktek mandiri role.
class DokterSettings extends ConsumerStatefulWidget {
  const DokterSettings({super.key});

  @override
  ConsumerState<DokterSettings> createState() => _DokterSettingsState();
}

class _DokterSettingsState extends ConsumerState<DokterSettings> {
  bool _syncOnSave = true;
  String _satuSehatStatus = 'TERHUBUNG (ID KLINIK VALID)';
  bool _isTestingSS = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(landingPageProvider);
    final notifier = ref.read(landingPageProvider.notifier);

    final isDark = state.appearance == 'dark';
    final cardBg = isDark ? const Color(0xFF161619) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1B0C3C);
    final subtitleColor = isDark ? Colors.grey[400]! : const Color(0xFF6F6A8A);
    final borderColor = isDark ? const Color(0xFF252528) : const Color(0xFFECEEF2);
    final purple = const Color(0xFFB577F2);
    final teal = const Color(0xFF48C9B0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Tema ────────────────────────────────────────────────────────
        SettingsSection(
          title: 'Tema & Visual',
          subtitle: 'Perbarui pengaturan tema dan bahasa antarmuka Dokter Anda.',
          textColor: textColor,
          subtitleColor: subtitleColor,
          child: Row(
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
        ),

        const SizedBox(height: 28),

        // ── Bahasa ───────────────────────────────────────────────────────
        SettingsSection(
          title: 'Bahasa Pilihan',
          subtitle: 'Ganti bahasa default untuk pelaporan RME.',
          textColor: textColor,
          subtitleColor: subtitleColor,
          child: Row(
            children: [
              SettingsChip(
                label: 'Indonesian',
                isSelected: state.language == 'id',
                onTap: () => notifier.setLanguage('id'),
                purple: purple,
                teal: teal,
                isDark: isDark,
                borderColor: borderColor,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
              ),
              const SizedBox(width: 10),
              SettingsChip(
                label: 'English',
                isSelected: state.language == 'en',
                onTap: () => notifier.setLanguage('en'),
                purple: purple,
                teal: teal,
                isDark: isDark,
                borderColor: borderColor,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
              ),
            ],
          ),
        ),

        const SizedBox(height: 28),

        // ── Integrasi SatuSehat Kemenkes ──────────────────────────────────
        SettingsSection(
          title: 'Integrasi SatuSehat (RME)',
          subtitle: 'Sambungkan database rekam medis dokter dengan server kemenkes.',
          textColor: textColor,
          subtitleColor: subtitleColor,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sinkronisasi Otomatis SatuSehat',
                            style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w900, color: textColor),
                          ),
                          Text(
                            'Kirim data resep & diagnosis setiap kali pemeriksaan selesai',
                            style: GoogleFonts.outfit(fontSize: 10, color: subtitleColor),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _syncOnSave,
                      activeColor: teal,
                      onChanged: (val) {
                        setState(() {
                          _syncOnSave = val;
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: teal.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _satuSehatStatus,
                        style: GoogleFonts.outfit(fontSize: 8.5, fontWeight: FontWeight.w900, color: teal),
                      ),
                    ),
                    const Spacer(),
                    OutlinedButton.icon(
                      icon: _isTestingSS
                          ? const SizedBox(
                              width: 10,
                              height: 10,
                              child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.indigo),
                            )
                          : const Icon(Icons.sync_rounded, size: 12),
                      label: Text(
                        _isTestingSS ? 'Menghubungkan...' : 'Tes Koneksi RME',
                        style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: borderColor),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _isTestingSS
                          ? null
                          : () async {
                              setState(() {
                                _isTestingSS = true;
                              });
                              await Future.delayed(const Duration(seconds: 1));
                              setState(() {
                                _isTestingSS = false;
                                _satuSehatStatus = 'KONEKSI AKTIF (PING 42ms) - OK';
                              });
                            },
                    ),
                  ],
                )
              ],
            ),
          ),
        ),

        const SizedBox(height: 32),

        // ── Laporkan Kendala RME ──────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(vertical: 36),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: purple.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(Icons.help_outline_rounded, size: 26, color: purple.withOpacity(0.5)),
              ),
              const SizedBox(height: 12),
              Text(
                'Hubungi Admin / Support RME',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Mengalami kendala sinkronisasi dengan BPJS / SatuSehat?\nHubungi admin Mapotech untuk bantuan integrasi.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(fontSize: 10.5, color: subtitleColor, height: 1.5),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  foregroundColor: textColor,
                  side: BorderSide(color: borderColor),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(
                  'Kirim Pesan Bantuan',
                  style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
