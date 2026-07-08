import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapotech/features/landing/landing_page_data.dart';
import 'package:mapotech/shared/widgets/animated_transitions.dart';

/// Shows the premium role selection modal dialog.
void showSelectionModal(BuildContext context, WidgetRef ref) {
  final state = ref.read(landingPageProvider);
  final notifier = ref.read(landingPageProvider.notifier);
  final isDark = state.appearance == 'dark';

  showAnimatedDialog(
    context: context,
    barrierColor: Colors.black.withOpacity(0.65),
    barrierDismissible: true,
    builder: (context) {
      return Dialog(
        backgroundColor: Colors.transparent,
        shadowColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: _SelectionModalContent(
          notifier: notifier,
          state: state,
          isDark: isDark,
        ),
      );
    },
  );
}

class _SelectionModalContent extends StatelessWidget {
  final LandingPageNotifier notifier;
  final LandingPageState state;
  final bool isDark;

  const _SelectionModalContent({
    required this.notifier,
    required this.state,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final isRev = state.appearance == 'rev';
    final bgColor = notifier.getBackgroundColor();
    final textColor = notifier.getTextColor(); // Deep dark purple/indigo or white/silver
    final subtitleColor = notifier.getBodyTextColor();
    final cardColor = isDark ? const Color(0xFF1E1E22) : (isRev ? const Color(0xFFF7F2FE) : const Color(0xFFF7F5FC));
    final iconBoxBg = isDark ? const Color(0xFF2C2C32) : Colors.white;
    final accentPurple = notifier.getPrimaryColor(); // Dynamic theme seed color

    final isMobile = MediaQuery.of(context).size.width < 768;

    final roles = [
      {
        'id': 'pasien',
        'label': 'MASYARAKAT',
        'icon': Icons.person_rounded,
        'isSoon': false,
      },
      {
        'id': 'dokter',
        'label': 'PRAKTIK MANDIRI',
        'icon': Icons.medical_services_rounded,
        'isSoon': false,
      },
      {
        'id': 'apotek',
        'label': 'APOTEK',
        'icon': Icons.local_pharmacy_rounded,
        'isSoon': false,
      },
      {
        'id': 'klinik',
        'label': 'KLINIK',
        'icon': Icons.local_hospital_rounded,
        'isSoon': true,
      },
      {
        'id': 'puskesmas',
        'label': 'PUSKESMAS',
        'icon': Icons.domain_rounded,
        'isSoon': true,
      },
      {
        'id': 'rumahsakit',
        'label': 'RUMAH SAKIT',
        'icon': Icons.corporate_fare_rounded,
        'isSoon': true,
      },
      {
        'id': 'ponkesdes',
        'label': 'PONKESDES',
        'icon': Icons.home_work_rounded,
        'isSoon': true,
      },
      {
        'id': 'posyandu',
        'label': 'POSYANDU',
        'icon': Icons.favorite_rounded,
        'isSoon': true,
      },
    ];

    return Container(
      width: 760,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: isDark ? const Color(0xFF2C2C2C) : Colors.transparent),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.5 : 0.08),
            blurRadius: 40,
            offset: const Offset(0, 20),
          )
        ],
      ),
      padding: EdgeInsets.all(isMobile ? 20 : 36),
      child: Stack(
        children: [
          // Close button
          Positioned(
            top: 0,
            right: 0,
            child: IconButton(
              icon: Icon(Icons.close_rounded, color: subtitleColor, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              
              // Capsule Selection tag
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: accentPurple.withOpacity(isDark ? 0.15 : 0.08),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: accentPurple.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome_rounded, size: 10, color: accentPurple),
                    const SizedBox(width: 6),
                    Text(
                      'SELECTION',
                      style: GoogleFonts.outfit(
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        color: accentPurple,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              
              // Title
              Text(
                state.language == 'id' ? 'Siapa Anda?' : 'Who Are You?',
                style: GoogleFonts.outfit(
                  fontSize: isMobile ? 32 : 44,
                  fontWeight: FontWeight.w900,
                  color: textColor,
                  letterSpacing: -1.0,
                ),
              ),
              const SizedBox(height: 8),
              
              // Subtitle
              Text(
                state.language == 'id'
                    ? 'Pilih peran Anda untuk menyesuaikan pengalaman Anda.'
                    : 'Select your role to customize your portal experience.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: subtitleColor,
                ),
              ),
              const SizedBox(height: 36),
              
              // Grid of roles
              Flexible(
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: isMobile ? 2 : 4,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: 1.15,
                  ),
                  itemCount: roles.length,
                  itemBuilder: (context, index) {
                    final role = roles[index];
                    final isSoon = role['isSoon'] as bool;
                    
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Stack(
                        children: [
                          Material(
                            color: cardColor,
                            child: InkWell(
                              onTap: isSoon
                                  ? null
                                  : () {
                                      notifier.setActiveTab(role['id'] as String);
                                      Navigator.pop(context);
                                    },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isDark ? const Color(0xFF2C2C2C) : Colors.grey[200]!.withOpacity(0.5),
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    // Icon Box
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: iconBoxBg,
                                        borderRadius: BorderRadius.circular(14),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(isDark ? 0.15 : 0.04),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          )
                                        ],
                                      ),
                                      child: Icon(
                                        role['icon'] as IconData,
                                        color: isSoon ? accentPurple.withOpacity(0.5) : accentPurple,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    
                                    // Text label
                                    Text(
                                      role['label'] as String,
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.outfit(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.5,
                                        color: isSoon ? textColor.withOpacity(0.4) : textColor.withOpacity(0.8),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          
                          // Diagonal ribbon
                          if (isSoon)
                            Positioned(
                              top: -16,
                              right: -28,
                              child: Transform.rotate(
                                angle: 0.785398, // 45 degrees
                                child: Container(
                                  width: 80,
                                  height: 48,
                                  padding: const EdgeInsets.only(bottom: 2),
                                  alignment: Alignment.bottomCenter,
                                  color: accentPurple,
                                  child: Text(
                                    'SEGERA',
                                    style: GoogleFonts.outfit(
                                      fontSize: 6.5,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 36),
              
              // Bottom action: Kembali ke Beranda
              TextButton(
                onPressed: () {
                  notifier.setActiveTab('mapotek');
                  Navigator.pop(context);
                },
                child: Text(
                  state.language == 'id' ? 'KEMBALI KE BERANDA' : 'RETURN TO HOME',
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: subtitleColor,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ],
      ),
    );
  }
}
