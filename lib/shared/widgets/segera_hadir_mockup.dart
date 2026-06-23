import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapotech/features/landing/landing_page_data.dart';

/// A premium browser window mockup that displays a gorgeous
/// "Segera Hadir" (Coming Soon) placeholder for portals under development.
class SegeraHadirMockup extends ConsumerWidget {
  final String portalPath;

  const SegeraHadirMockup({
    super.key,
    required this.portalPath,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(landingPageProvider);
    final notifier = ref.read(landingPageProvider.notifier);

    final isDark = state.appearance == 'dark';
    final borderColor = notifier.getBorderColor();
    final cardColor = notifier.getCardColor();
    final textColor = notifier.getTextColor();
    final bodyTextColor = notifier.getBodyTextColor();
    final lang = state.language;

    final browserBg = isDark ? const Color(0xFF16161A) : Colors.white;
    final addressBarBg = isDark ? const Color(0xFF24242B) : const Color(0xFFF1F3F5);
    final iconBoxBg = isDark ? const Color(0xFF2C2C35) : const Color(0xFFF3EEFC);
    const accentPurple = Color(0xFFB577F2);

    return Container(
      height: 480,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor),
        color: cardColor,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Browser Window Header
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E24) : const Color(0xFFF8F9FA),
              border: Border(bottom: BorderSide(color: borderColor)),
            ),
            child: Row(
              children: [
                // 3 dots (red, yellow, green window controls)
                Row(
                  children: [
                    Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFFFF5F56), shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFFFFBD2E), shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF27C93F), shape: BoxShape.circle)),
                  ],
                ),
                const SizedBox(width: 24),
                
                // Address bar
                Expanded(
                  child: Container(
                    height: 28,
                    decoration: BoxDecoration(
                      color: addressBarBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: borderColor.withOpacity(0.4)),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'HTTPS://MAPOTECH.DIGITAL/APP/$portalPath',
                      style: GoogleFonts.outfit(
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        color: bodyTextColor.withOpacity(0.6),
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
          ),
          
          // Browser Content Body
          Expanded(
            child: Container(
              color: browserBg,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Icon Box
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: iconBoxBg,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                          blurRadius: 15,
                          offset: const Offset(0, 6),
                        )
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        const Icon(
                          Icons.access_time_rounded,
                          color: accentPurple,
                          size: 32,
                        ),
                        Positioned(
                          top: 18,
                          right: 18,
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: accentPurple,
                              shape: BoxShape.circle,
                            ),
                          ),
                        )
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  
                  // Segera Hadir title
                  Text(
                    lang == 'id' ? 'Segera Hadir.' : 'Coming Soon.',
                    style: GoogleFonts.outfit(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: textColor,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Description
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 320),
                    child: Text(
                      lang == 'id'
                          ? 'KAMI SEDANG MEMBANGUN PORTAL INI UNTUK MEMBERIKAN PENGALAMAN KESEHATAN DIGITAL TERBAIK. NANTIKAN KABAR SELANJUTNYA.'
                          : 'WE ARE BUILDING THIS PORTAL TO PROVIDE THE BEST DIGITAL HEALTH EXPERIENCE. STAY TUNED FOR UPDATES.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: bodyTextColor.withOpacity(0.7),
                        height: 1.6,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Capsule badge: Dalam Pengembangan
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF201A2B) : const Color(0xFFF9F5FE),
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(color: accentPurple.withOpacity(0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.auto_awesome_rounded,
                          size: 11,
                          color: accentPurple,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          lang == 'id' ? 'DALAM PENGEMBANGAN' : 'UNDER DEVELOPMENT',
                          style: GoogleFonts.outfit(
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            color: accentPurple,
                            letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
}
