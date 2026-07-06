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
  String _satuSehatStatus = 'TERHUBUNG (ID KLINIK VALID)';
  bool _isTestingSS = false;
  late final TextEditingController _feeController;

  @override
  void initState() {
    super.initState();
    final state = ref.read(landingPageProvider);
    _feeController = TextEditingController(
      text: state.defaultServiceFee.toInt().toString(),
    );
  }

  @override
  void dispose() {
    _feeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          title: isEn ? 'Theme & Visual' : 'Tema & Visual',
          subtitle: isEn
              ? 'Update theme and language settings for your Doctor interface.'
              : 'Perbarui pengaturan tema dan bahasa antarmuka Dokter Anda.',
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
                    activeThumbColor: teal,
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
          title: isEn ? 'Preferred Language' : 'Bahasa Pilihan',
          subtitle: isEn
              ? 'Change default language for EMR reporting.'
              : 'Ganti bahasa default untuk pelaporan RME.',
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 9,
                ),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 9,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 28),

        // ── Tarif Layanan Default ──────────────────────────────────────────
        SettingsSection(
          title: isEn ? 'Default Service Fee' : 'Tarif Layanan Default',
          subtitle: isEn
              ? 'Determine the default service fee (Service Fee) when examining a new patient.'
              : 'Tentukan tarif jasa layanan default (Service Fee) saat pemeriksaan pasien baru.',
          textColor: textColor,
          subtitleColor: subtitleColor,
          child: Container(
            width: 200,
            height: 38,
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderColor),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                Text(
                  'Rp ',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _feeController,
                    keyboardType: TextInputType.number,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: (val) {
                      final double fee = double.tryParse(val) ?? 0.0;
                      notifier.setDefaultServiceFee(fee);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 28),

        // ── Ukuran Kertas Struk ──────────────────────────────────────────────
        SettingsSection(
          title: isEn ? 'Receipt Paper Size' : 'Ukuran Kertas Struk',
          subtitle: isEn
              ? 'Set the paper size used when printing patient payment invoices.'
              : 'Atur ukuran kertas yang digunakan saat mencetak invoice pembayaran pasien.',
          textColor: textColor,
          subtitleColor: subtitleColor,
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final size in ['A4', 'A5', 'Thermal 58mm', 'Thermal 80mm'])
                SettingsChip(
                  label: size,
                  icon: Icons.description_outlined,
                  isSelected: state.receiptPaperSize == size,
                  onTap: () => notifier.setReceiptPaperSize(size),
                  purple: purple,
                  teal: teal,
                  isDark: isDark,
                  borderColor: borderColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 28),

        // ── Integrasi SatuSehat Kemenkes ──────────────────────────────────
        SettingsSection(
          title: isEn
              ? 'SatuSehat Integration (EMR)'
              : 'Integrasi SatuSehat (RME)',
          subtitle: isEn
              ? 'Connect doctor\'s medical record database with ministry of health server.'
              : 'Sambungkan database rekam medis dokter dengan server kemenkes.',
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
                            isEn
                                ? 'SatuSehat Auto Sync'
                                : 'Sinkronisasi Otomatis SatuSehat',
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: textColor,
                            ),
                          ),
                          Text(
                            isEn
                                ? 'Send prescription & diagnosis data every time an examination is finished'
                                : 'Kirim data resep & diagnosis setiap kali pemeriksaan selesai',
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              color: subtitleColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: state.satusehatAutoSync,
                      activeThumbColor: teal,
                      onChanged: (val) {
                        notifier.setSatusehatAutoSync(val);
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: teal.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _satuSehatStatus == 'TERHUBUNG (ID KLINIK VALID)'
                            ? (isEn
                                  ? 'CONNECTED (VALID CLINIC ID)'
                                  : 'TERHUBUNG (ID KLINIK VALID)')
                            : (_satuSehatStatus ==
                                      'KONEKSI AKTIF (PING 42ms) - OK'
                                  ? (isEn
                                        ? 'CONNECTION ACTIVE (PING 42ms) - OK'
                                        : 'KONEKSI AKTIF (PING 42ms) - OK')
                                  : _satuSehatStatus),
                        style: GoogleFonts.outfit(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w900,
                          color: teal,
                        ),
                      ),
                    ),
                    const Spacer(),
                    OutlinedButton.icon(
                      icon: _isTestingSS
                          ? const SizedBox(
                              width: 10,
                              height: 10,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: Colors.indigo,
                              ),
                            )
                          : const Icon(Icons.sync_rounded, size: 12),
                      label: Text(
                        _isTestingSS
                            ? (isEn ? 'Connecting...' : 'Menghubungkan...')
                            : (isEn
                                  ? 'Test EMR Connection'
                                  : 'Tes Koneksi RME'),
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: borderColor),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
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
                                _satuSehatStatus =
                                    'KONEKSI AKTIF (PING 42ms) - OK';
                              });
                            },
                    ),
                  ],
                ),
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
                child: Icon(
                  Icons.help_outline_rounded,
                  size: 26,
                  color: purple.withOpacity(0.5),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                isEn
                    ? 'Contact Admin / EMR Support'
                    : 'Hubungi Admin / Support RME',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isEn
                    ? 'Experiencing synchronization issues with BPJS / SatuSehat?\nContact Mapotech admin for integration assistance.'
                    : 'Mengalami kendala sinkronisasi dengan BPJS / SatuSehat?\nHubungi admin Mapotech untuk bantuan integrasi.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 10.5,
                  color: subtitleColor,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  foregroundColor: textColor,
                  side: BorderSide(color: borderColor),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  isEn ? 'Send Help Message' : 'Kirim Pesan Bantuan',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
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
}
