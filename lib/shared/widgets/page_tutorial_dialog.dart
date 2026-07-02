import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapotech/features/landing/landing_page_data.dart';
import 'package:mapotech/shared/widgets/page_tutorial_data.dart';

class PageTutorialDialog extends ConsumerWidget {
  final String role;
  final String menuId;
  final String menuLabel;
  final VoidCallback onStartInteractiveGuide;

  const PageTutorialDialog({
    super.key,
    required this.role,
    required this.menuId,
    required this.menuLabel,
    required this.onStartInteractiveGuide,
  });

  static void show(
    BuildContext context, {
    required String role,
    required String menuId,
    required String menuLabel,
    required VoidCallback onStartInteractiveGuide,
  }) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: PageTutorialDialog(
            role: role,
            menuId: menuId,
            menuLabel: menuLabel,
            onStartInteractiveGuide: onStartInteractiveGuide,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(landingPageProvider);
    final notifier = ref.read(landingPageProvider.notifier);
    final isEn = state.language.toLowerCase() == 'en';
    final tutorial = getTutorialData(role, menuId, menuLabel, state.language);

    // Theme Variables
    final isDark = state.appearance == 'dark';
    final isRev = state.appearance == 'rev';

    final themeAccent = notifier.getPrimaryColor();

    final dialogBg = notifier.getCardColor();
    final textColor = notifier.getTextColor();
    final secondaryTextColor = notifier.getBodyTextColor();
    final cardBg = isDark ? const Color(0xFF252528) : (isRev ? const Color(0xFFF7F2FE) : const Color(0xFFF8FAFC));
    final borderColor = notifier.getBorderColor();
    final shadowColor = isDark ? Colors.black.withOpacity(0.4) : Colors.black.withOpacity(0.06);

    // Responsive design flag
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 800;

    // Translations
    final labelKb = isEn ? 'KNOWLEDGE BASE' : 'BASIS PENGETAHUAN';
    final labelHowToUse = isEn ? 'HOW TO USE' : 'CARA PENGGUNAAN';
    final btnStart = isEn ? 'START INTERACTIVE GUIDE' : 'MULAI PANDUAN INTERAKTIF';
    final btnContinue = isEn ? 'CONTINUE EXPLORING' : 'LANJUTKAN MENELUSURI';
    final labelPlay = isEn ? 'PLAY TUTORIAL' : 'PUTAR TUTORIAL';

    // Video Player Placeholder Widget
    Widget buildVideoPlayer() {
      return Container(
        height: isCompact ? 180 : 250,
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: shadowColor,
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0xFF2E2E32), const Color(0xFF1F1F23)]
                : [const Color(0xFFF1F5F9), const Color(0xFFE2E8F0)],
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Styled visual mesh background
            Positioned(
              right: -30,
              bottom: -30,
              child: Opacity(
                opacity: isDark ? 0.08 : 0.12,
                child: Icon(
                  Icons.help_outline_rounded,
                  size: 200,
                  color: themeAccent,
                ),
              ),
            ),
            // Floating Brand / Watermark Text
            Positioned(
              bottom: 16,
              child: Column(
                children: [
                  Text(
                    labelPlay.toUpperCase(),
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                      color: secondaryTextColor.withOpacity(0.5),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'MAPOTECH STUDIO',
                    style: GoogleFonts.outfit(
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.0,
                      color: secondaryTextColor.withOpacity(0.3),
                    ),
                  ),
                ],
              ),
            ),
            // Play Button Wrapper
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: isDark ? Colors.black.withOpacity(0.5) : Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 12,
                    spreadRadius: 2,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () {
                    // Quick placeholder video playback notification
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isEn
                              ? 'Opening tutorial video for ${tutorial.title}...'
                              : 'Membuka video tutorial untuk ${tutorial.title}...',
                        ),
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  child: Icon(
                    Icons.play_arrow_rounded,
                    size: 32,
                    color: isDark ? themeAccent : const Color(0xFF1B0C3C),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Content Block (Left side on desktop, bottom on mobile)
    Widget buildContentBlock() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Knowledge Base Badge Chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isDark
                  ? themeAccent.withOpacity(0.12)
                  : themeAccent.withOpacity(0.08),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: themeAccent.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Text(
              labelKb,
              style: GoogleFonts.outfit(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.0,
                color: themeAccent,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Title
          Text(
            tutorial.title,
            style: GoogleFonts.outfit(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: textColor,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          // Description
          Text(
            tutorial.description,
            style: GoogleFonts.outfit(
              fontSize: 13,
              color: secondaryTextColor,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          // Section Divider & Label "CARA PENGGUNAAN"
          Text(
            labelHowToUse,
            style: GoogleFonts.outfit(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
              color: themeAccent,
            ),
          ),
          const SizedBox(height: 12),
          // Cards Layout
          if (tutorial.steps.isEmpty)
            const SizedBox()
          else if (isCompact)
            // Mobile: Vertical List of steps
            Column(
              children: tutorial.steps.map((step) => _buildStepCard(step, cardBg, borderColor, textColor, secondaryTextColor)).toList(),
            )
          else
            // Desktop: Grid of steps (Row)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: tutorial.steps.map((step) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: _buildStepCard(step, cardBg, borderColor, textColor, secondaryTextColor),
                  ),
                );
              }).toList(),
            ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: dialogBg,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Stack(
        children: [
          // Dialog Content Scroll Area
          SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 16), // space for close button
                if (isCompact) ...[
                  // Mobile: Video player on top, content below
                  buildVideoPlayer(),
                  const SizedBox(height: 24),
                  buildContentBlock(),
                ] else ...[
                  // Desktop: 2 Column Side-by-side Row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 11,
                        child: buildContentBlock(),
                      ),
                      const SizedBox(width: 32),
                      Expanded(
                        flex: 8,
                        child: Column(
                          children: [
                            const SizedBox(height: 8),
                            buildVideoPlayer(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 36),
                const Divider(height: 1, thickness: 1, color: Colors.transparent),
                // Footer buttons
                Row(
                  mainAxisAlignment: isCompact ? MainAxisAlignment.center : MainAxisAlignment.start,
                  children: [
                    // Start Interactive Guide
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        onStartInteractiveGuide();
                      },
                      icon: const Icon(Icons.auto_awesome_rounded, size: 16, color: Colors.white),
                      label: Text(
                        btnStart,
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? themeAccent : const Color(0xFF0F0F11),
                        foregroundColor: Colors.white,
                        shadowColor: Colors.black.withOpacity(0.15),
                        elevation: 4,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Continue Exploring
                    TextButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const SizedBox(),
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            btnContinue,
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white.withOpacity(0.7) : const Color(0xFF1B0C3C).withOpacity(0.7),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: 14,
                            color: isDark ? Colors.white.withOpacity(0.7) : const Color(0xFF1B0C3C).withOpacity(0.7),
                          ),
                        ],
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Close button at top right
          Positioned(
            right: 0,
            top: 0,
            child: IconButton(
              icon: Icon(Icons.close_rounded, color: textColor.withOpacity(0.5)),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepCard(
    TutorialStep step,
    Color cardBg,
    Color borderColor,
    Color textColor,
    Color secondaryTextColor,
  ) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            step.title,
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            step.description,
            style: GoogleFonts.outfit(
              fontSize: 11.5,
              color: secondaryTextColor,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
