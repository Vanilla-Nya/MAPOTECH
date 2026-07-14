import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapotech/features/landing/landing_page_data.dart';
import 'package:mapotech/shared/widgets/settings_widgets.dart';

class PonkesdesSettings extends ConsumerWidget {
  const PonkesdesSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(landingPageProvider);
    final notifier = ref.read(landingPageProvider.notifier);

    final isEn = state.language == 'en';
    final isDark = state.appearance == 'dark';
    final textColor = notifier.getTextColor();
    final subtitleColor = notifier.getBodyTextColor();
    final borderColor = notifier.getBorderColor();
    final primaryColor = notifier.getPrimaryColor();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Theme & Language Settings Section
        SettingsSection(
          title: isEn ? 'Theme & Visual' : 'Tema & Visual',
          subtitle: isEn ? 'Update theme and language settings for Ponkesdes clinic interface' : 'Perbarui pengaturan tema dan bahasa antarmuka Ponkesdes Anda',
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
                    purple: primaryColor,
                    teal: primaryColor,
                    isDark: isDark,
                    borderColor: borderColor,
                  ),
                  const SizedBox(width: 10),
                  SettingsChip(
                    label: 'Dark',
                    icon: Icons.nightlight_round,
                    isSelected: state.appearance == 'dark',
                    onTap: () => notifier.updateAppearance('dark'),
                    purple: primaryColor,
                    teal: primaryColor,
                    isDark: isDark,
                    borderColor: borderColor,
                  ),
                  const SizedBox(width: 10),
                  SettingsChip(
                    label: 'REV',
                    icon: Icons.palette_rounded,
                    isSelected: state.appearance == 'rev',
                    onTap: () => notifier.updateAppearance('rev'),
                    purple: primaryColor,
                    teal: primaryColor,
                    isDark: isDark,
                    borderColor: borderColor,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 16),
              Row(
                children: [
                  SettingsChip(
                    label: 'Indonesian',
                    isSelected: state.language == 'id',
                    onTap: () => notifier.setLanguage('id'),
                    purple: primaryColor,
                    teal: primaryColor,
                    isDark: isDark,
                    borderColor: borderColor,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                  ),
                  const SizedBox(width: 10),
                  SettingsChip(
                    label: 'English',
                    isSelected: state.language == 'en',
                    onTap: () => notifier.setLanguage('en'),
                    purple: primaryColor,
                    teal: primaryColor,
                    isDark: isDark,
                    borderColor: borderColor,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
      ],
    );
  }
}
