import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapotech/features/landing/landing_page_data.dart';
import 'package:mapotech/shared/widgets/ui.dart';
import 'package:mapotech/features/puskesmas/dashboard/frontend/puskesmas_owner_dashboard.dart';
import 'package:mapotech/features/puskesmas/dashboard/frontend/puskesmas_pekerja_dashboard.dart';

class PuskesmasDashboard extends ConsumerStatefulWidget {
  const PuskesmasDashboard({super.key});

  @override
  ConsumerState<PuskesmasDashboard> createState() => _PuskesmasDashboardState();
}

class _PuskesmasDashboardState extends ConsumerState<PuskesmasDashboard> {
  // Sub-dashboard view mode switcher: 'owner' vs 'pekerja'
  String _subDashboardMode = 'owner';

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(landingPageProvider.notifier);
    final cardBgColor = notifier.getCardColor();
    final subtitleColor = notifier.getBodyTextColor();
    final borderColor = notifier.getBorderColor();
    final themeAccent = notifier.getPrimaryColor();

    final isOwnerMode = _subDashboardMode == 'owner';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ==================== SUB-DASHBOARD SWITCHER TABS ====================
        AnimatedEntrance(
          delay: Duration.zero,
          type: EntranceAnimationType.slideUp,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: cardBgColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () {
                      setState(() => _subDashboardMode = 'owner');
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: isOwnerMode ? themeAccent : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.shield_rounded, size: 18, color: isOwnerMode ? Colors.white : subtitleColor),
                          const SizedBox(width: 8),
                          Text(
                            '👑 DASHBOARD OWNER',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: isOwnerMode ? Colors.white : subtitleColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: InkWell(
                    onTap: () {
                      setState(() => _subDashboardMode = 'pekerja');
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: !isOwnerMode ? themeAccent : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.badge_rounded, size: 18, color: !isOwnerMode ? Colors.white : subtitleColor),
                          const SizedBox(width: 8),
                          Text(
                            '👷 DASHBOARD PEKERJA',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: !isOwnerMode ? Colors.white : subtitleColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // ==================== ACTIVE DASHBOARD VIEW (OWNER or PEKERJA) ====================
        if (isOwnerMode)
          const PuskesmasOwnerDashboard()
        else
          const PuskesmasPekerjaDashboard(),
      ],
    );
  }
}
