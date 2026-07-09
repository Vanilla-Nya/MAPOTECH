import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapotech/features/landing/landing_page_data.dart';
import 'package:mapotech/shared/layouts/responsive_layout.dart';
import 'package:mapotech/shared/widgets/custom_button.dart';
import 'package:mapotech/shared/widgets/three_dimensional_device_wrapper.dart';
import 'package:mapotech/shared/widgets/custom_card.dart';
import 'package:mapotech/shared/widgets/entity_chip.dart';

class ApotekPortal extends ConsumerWidget {
  const ApotekPortal({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(landingPageProvider);
    final notifier = ref.read(landingPageProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeroSection(context, state, notifier),
        const SizedBox(height: 80),
        _buildEcosystemSection(context, state, notifier),
      ],
    );
  }

  // --- HERO SECTION ---
  Widget _buildHeroSection(BuildContext context, LandingPageState state,
      LandingPageNotifier notifier) {
    final isMobile = ResponsiveLayout.isMobile(context);
    final activeColor = notifier.getPrimaryColor();
    final darkGreenColor = notifier.getSecondaryColor();
    final textColor = notifier.getTextColor();
    final bodyTextColor = notifier.getBodyTextColor();
    final cardColor = notifier.getCardColor();
    final borderColor = notifier.getBorderColor();
    final isDark = state.appearance == 'dark';

    final simulatorData = notifier.getSimulatorData();

    Widget heroText = Column(
      crossAxisAlignment:
          isMobile ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: activeColor.withOpacity(0.2),
            ),
            boxShadow: [
              BoxShadow(
                color: activeColor.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.favorite_rounded,
                color: activeColor,
                size: 14,
              ),
              const SizedBox(width: 8),
              Text(
                notifier.getHeroTagline(),
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  color: textColor.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        Text(
          notifier.getHeroTitle(),
          textAlign: isMobile ? TextAlign.center : TextAlign.start,
          style: GoogleFonts.outfit(
            fontSize: isMobile ? 48 : 72,
            fontWeight: FontWeight.w900,
            letterSpacing: -2.0,
            height: 0.9,
            color: textColor,
          ),
        ),
        const SizedBox(height: 16),

        Text(
          notifier.getHeroDescription(),
          textAlign: isMobile ? TextAlign.center : TextAlign.start,
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            height: 1.5,
            color: bodyTextColor,
          ),
        ),
        const SizedBox(height: 32),

        Row(
          mainAxisAlignment:
              isMobile ? MainAxisAlignment.center : MainAxisAlignment.start,
          children: [
            CustomButton(
              text: notifier.t('learn_more'),
              isSecondary: true,
              primaryColor: Colors.transparent,
              textColor: textColor,
              borderColor: borderColor,
              onPressed: () {},
            ),
          ],
        ),
        const SizedBox(height: 32),

        Row(
          mainAxisAlignment:
              isMobile ? MainAxisAlignment.center : MainAxisAlignment.start,
          children: [
            SizedBox(
              width: 100,
              height: 36,
              child: Stack(
                children: List.generate(4, (index) {
                  return Positioned(
                    left: index * 20.0,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                            width: 2),
                        color: isDark ? const Color(0xFF222222) : Colors.grey[200],
                      ),
                      child: ClipOval(
                        child: Image.network(
                          'https://api.dicebear.com/7.x/avataaars/png?seed=${index + 12}',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
            Text(
              '2,000+ ${notifier.t('trusted_providers')}',
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: bodyTextColor,
              ),
            ),
          ],
        ),
      ],
    );

    Widget heroVisual = Container(
      height: 480,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: darkGreenColor.withOpacity(0.03),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: borderColor),
      ),
      child: Center(
        child: Container(
          width: 250,
          height: 440,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1C1E) : Colors.black,
            borderRadius: BorderRadius.circular(36),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.4 : 0.2),
                blurRadius: 30,
                offset: const Offset(0, 15),
              ),
            ],
          ),
          padding: const EdgeInsets.all(10),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF161616) : const Color(0xFFFDFDFC),
              borderRadius: BorderRadius.circular(28),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 28,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '9:41',
                          style: GoogleFonts.outfit(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black),
                        ),
                        Row(
                          children: [
                            Icon(Icons.signal_cellular_4_bar_rounded,
                                size: 9, color: isDark ? Colors.white : Colors.black),
                            const SizedBox(width: 4),
                            Icon(Icons.battery_5_bar_rounded,
                                size: 9, color: isDark ? Colors.white : Colors.black),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 36, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Image.asset(
                            'assets/images/logo.png',
                            width: 28,
                            height: 28,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) => Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: activeColor,
                              ),
                              child: const Icon(Icons.healing_rounded,
                                  size: 14, color: Colors.white),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'MAPOTECH',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: textColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: activeColor.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: activeColor,
                              child: Text(
                                simulatorData.avatarLabel,
                                style: GoogleFonts.outfit(
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.black : Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    simulatorData.statusText,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.outfit(
                                        fontSize: 6,
                                        fontWeight: FontWeight.w800,
                                        color: activeColor),
                                  ),
                                  Text(
                                    simulatorData.welcomeText,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.outfit(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900,
                                        color: textColor),
                                  ),
                                  Text(
                                    simulatorData.infoText,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.outfit(
                                        fontSize: 6,
                                        fontWeight: FontWeight.w500,
                                        color: isDark ? Colors.grey[400]! : Colors.grey[600]!),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      Expanded(
                        child: ListView(
                          physics: const NeverScrollableScrollPhysics(),
                          children: simulatorData.cards.map((card) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: _buildAppSimulatorCard(
                                card.icon,
                                card.title,
                                card.subtitle,
                                isDark,
                                activeColor,
                                textColor,
                              ),
                            );
                          }).toList(),
                        ),
                      ),

                      Container(
                        height: 38,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF222222) : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Icon(Icons.home_rounded,
                                size: 16, color: activeColor),
                            Icon(Icons.assignment_rounded,
                                size: 16, color: isDark ? Colors.grey[600] : Colors.grey),
                            Icon(Icons.notifications_rounded,
                                size: 16, color: isDark ? Colors.grey[600] : Colors.grey),
                            Icon(Icons.settings_rounded,
                                size: 16, color: isDark ? Colors.grey[600] : Colors.grey),
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
      ),
    );

    heroVisual = ThreeDimensionalDeviceWrapper(child: heroVisual);

    if (isMobile) {
      return Column(
        children: [
          heroText,
          const SizedBox(height: 48),
          heroVisual,
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: heroText),
        const SizedBox(width: 60),
        Expanded(child: heroVisual),
      ],
    );
  }

  Widget _buildAppSimulatorCard(IconData icon, String title, String subtitle,
      bool isDark, Color activeColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF222222) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF333333) : Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: activeColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 12, color: textColor),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.outfit(
                      fontSize: 7,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.grey[400]! : Colors.grey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- ECOSYSTEM SECTION ---
  Widget _buildEcosystemSection(BuildContext context, LandingPageState state,
      LandingPageNotifier notifier) {
    final activeColor = notifier.getPrimaryColor();
    final textColor = notifier.getTextColor();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Column(
            children: [
              Text(
                notifier.t('features_title'),
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.0,
                  color: activeColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                notifier.t('features_desc'),
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 36),

        Center(
          child: Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            alignment: WrapAlignment.center,
            children: notifier.getEntities().map((entity) {
              return EntityChip(
                label: entity.label,
                icon: entity.icon,
                isSelected: state.activeTab == entity.id,
                isSoon: entity.isSoon,
                onTap: () {
                  notifier.setActiveTab(entity.id);
                },
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 40),

        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _buildEntityPortalContent(context, state, notifier),
        ),
      ],
    );
  }

  Widget _buildEntityPortalContent(BuildContext context,
      LandingPageState state, LandingPageNotifier notifier) {
    final updates = notifier.getUpdatesForActiveTab();
    final activeColor = notifier.getPrimaryColor();
    final textColor = notifier.getTextColor();
    final bodyTextColor = notifier.getBodyTextColor();
    final cardColor = notifier.getCardColor();
    final borderColor = notifier.getBorderColor();
    final isDark = state.appearance == 'dark';

    if (updates.isEmpty) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        child: Text(
          'No updates available',
          style: GoogleFonts.outfit(color: bodyTextColor),
        ),
      );
    }

    return Column(
      key: ValueKey(state.activeTab),
      children: updates.map((update) {
        final isFeature = update.type == 'feature';
        return Padding(
          padding: const EdgeInsets.only(bottom: 20.0),
          child: CustomCard(
            padding: const EdgeInsets.all(24),
            color: cardColor,
            borderColor: borderColor,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isFeature
                        ? activeColor.withOpacity(0.12)
                        : Colors.orange.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isFeature ? Icons.star_rounded : Icons.trending_up_rounded,
                    color: isFeature ? (isDark ? Colors.white : activeColor) : Colors.orange,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 20),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              update.title,
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF222222) : Colors.grey[100],
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Text(
                              update.date,
                              style: GoogleFonts.outfit(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.grey[400]! : Colors.grey[600]!,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        update.description,
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          height: 1.5,
                          color: bodyTextColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
