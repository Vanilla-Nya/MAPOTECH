import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Item data model for [CustomFormStepper].
class FormStepItem {
  final int step;
  final String label;
  final IconData? icon;
  final bool hasError;
  final bool hasWarning;
  final bool isCompleted;

  const FormStepItem({
    required this.step,
    required this.label,
    this.icon,
    this.hasError = false,
    this.hasWarning = false,
    this.isCompleted = false,
  });
}

/// A responsive, clickable horizontal form stepper widget designed for Mapotech.
/// Adheres to REV Mode color compliance, uniform borders, and modular structure.
class CustomFormStepper extends StatelessWidget {
  final List<FormStepItem> steps;
  final int currentStep;
  final ValueChanged<int>? onStepTapped;
  final Color themeAccent;
  final Color textColor;
  final Color subtitleColor;
  final Color borderColor;
  final Color cardBgColor;
  final bool isDark;

  const CustomFormStepper({
    super.key,
    required this.steps,
    required this.currentStep,
    this.onStepTapped,
    required this.themeAccent,
    required this.textColor,
    required this.subtitleColor,
    required this.borderColor,
    required this.cardBgColor,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 640;

          if (isCompact) {
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: List.generate(steps.length, (idx) {
                  final item = steps[idx];
                  final isLast = idx == steps.length - 1;
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildStepItem(item, isCompact: true),
                      if (!isLast) _buildConnector(item, steps[idx + 1], width: 24),
                    ],
                  );
                }),
              ),
            );
          }

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(steps.length, (idx) {
              final item = steps[idx];
              final isLast = idx == steps.length - 1;

              return Expanded(
                child: Row(
                  children: [
                    Expanded(child: _buildStepItem(item, isCompact: false)),
                    if (!isLast) _buildConnector(item, steps[idx + 1]),
                  ],
                ),
              );
            }),
          );
        },
      ),
    );
  }

  Widget _buildStepItem(FormStepItem item, {required bool isCompact}) {
    final isActive = item.step == currentStep;
    final isDone = item.isCompleted || item.step < currentStep;
    final hasError = item.hasError;
    final hasWarning = item.hasWarning;

    // Color resolution
    Color circleBg;
    Color circleBorder;
    Widget contentInside;

    if (hasError) {
      circleBg = const Color(0xFFE74C3C).withOpacity(0.15);
      circleBorder = const Color(0xFFE74C3C);
      contentInside = const Icon(Icons.priority_high_rounded, size: 14, color: Color(0xFFE74C3C));
    } else if (isActive) {
      circleBg = themeAccent;
      circleBorder = themeAccent;
      contentInside = Text(
        '${item.step}',
        style: GoogleFonts.outfit(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: Colors.white,
        ),
      );
    } else if (isDone) {
      if (hasWarning) {
        circleBg = const Color(0xFFF39C12).withOpacity(0.15);
        circleBorder = const Color(0xFFF39C12);
        contentInside = const Icon(Icons.info_outline_rounded, size: 13, color: Color(0xFFD68910));
      } else {
        circleBg = const Color(0xFF27AE60).withOpacity(0.18);
        circleBorder = const Color(0xFF27AE60);
        contentInside = const Icon(Icons.check_rounded, size: 14, color: Color(0xFF27AE60));
      }
    } else {
      circleBg = borderColor.withOpacity(0.06);
      circleBorder = borderColor;
      contentInside = Text(
        '${item.step}',
        style: GoogleFonts.outfit(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: subtitleColor,
        ),
      );
    }

    return InkWell(
      onTap: onStepTapped != null ? () => onStepTapped!(item.step) : null,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Row(
          mainAxisSize: isCompact ? MainAxisSize.min : MainAxisSize.max,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: circleBg,
                shape: BoxShape.circle,
                border: Border.all(color: circleBorder, width: isActive ? 2 : 1.5),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: themeAccent.withOpacity(0.35),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              alignment: Alignment.center,
              child: contentInside,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontSize: 10.5,
                      fontWeight: isActive ? FontWeight.w900 : (isDone ? FontWeight.bold : FontWeight.w600),
                      color: isActive
                          ? themeAccent
                          : (hasError
                              ? const Color(0xFFE74C3C)
                              : (hasWarning ? const Color(0xFFD68910) : (isDone ? textColor : subtitleColor))),
                    ),
                  ),
                  if (isActive)
                    Text(
                      'Aktif',
                      style: GoogleFonts.outfit(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w800,
                        color: themeAccent,
                        letterSpacing: 0.3,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnector(FormStepItem current, FormStepItem next, {double? width}) {
    final isDone = current.step < currentStep;
    final color = isDone ? themeAccent.withOpacity(0.6) : borderColor.withOpacity(0.4);

    if (width != null) {
      return Container(
        width: width,
        height: 2,
        color: color,
        margin: const EdgeInsets.symmetric(horizontal: 4),
      );
    }

    return Container(
      width: 18,
      height: 2,
      color: color,
      margin: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}
