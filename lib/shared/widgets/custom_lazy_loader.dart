import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapotech/features/landing/landing_page_data.dart';
import 'package:mapotech/shared/widgets/skeleton_loading.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// MAPOTECH CUSTOM PROGRESS BAR
/// A sleek, customizable animated progress bar (1% -> 100%, left-to-right)
/// with a glowing gradient track, percentage badge, and smooth easing.
/// ─────────────────────────────────────────────────────────────────────────────
class CustomProgressBar extends StatefulWidget {
  final double value; // 0.0 to 1.0
  final String? label;
  final String? sublabel;
  final bool showPercentage;
  final double height;
  final Color? primaryColor;
  final Color? secondaryColor;
  final Color? trackColor;
  final BorderRadius? borderRadius;
  final bool isIndeterminate;

  const CustomProgressBar({
    super.key,
    required this.value,
    this.label,
    this.sublabel,
    this.showPercentage = true,
    this.height = 7.0,
    this.primaryColor,
    this.secondaryColor,
    this.trackColor,
    this.borderRadius,
    this.isIndeterminate = false,
  });

  @override
  State<CustomProgressBar> createState() => _CustomProgressBarState();
}

class _CustomProgressBarState extends State<CustomProgressBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = widget.primaryColor ?? const Color(0xFF00BFA6);
    final secondary = widget.secondaryColor ?? const Color(0xFFB577F2);
    final track = widget.trackColor ??
        (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06));
    final radius = widget.borderRadius ?? BorderRadius.circular(100);

    final clampedVal = widget.value.clamp(0.0, 1.0);
    final percentInt = (clampedVal * 100).toInt();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null || widget.showPercentage)
          Padding(
            padding: const EdgeInsets.only(bottom: 6.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (widget.label != null)
                  Expanded(
                    child: Text(
                      widget.label!,
                      style: GoogleFonts.outfit(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white70 : const Color(0xFF475569),
                        letterSpacing: 0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                if (widget.showPercentage) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: primary.withValues(alpha: 0.25), width: 1),
                    ),
                    child: Text(
                      '$percentInt%',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: primary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        Container(
          height: widget.height,
          width: double.infinity,
          decoration: BoxDecoration(
            color: track,
            borderRadius: radius,
          ),
          clipBehavior: Clip.antiAlias,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxWidth = constraints.maxWidth;
              final targetWidth = (maxWidth * clampedVal).clamp(0.0, maxWidth);

              return Stack(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    width: targetWidth,
                    height: widget.height,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [secondary, primary],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: radius,
                      boxShadow: [
                        BoxShadow(
                          color: primary.withValues(alpha: 0.35),
                          blurRadius: 6,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                  // Animated shimmer flare passing across progress bar
                  if (clampedVal > 0.05)
                    AnimatedBuilder(
                      animation: _shimmerController,
                      builder: (context, child) {
                        final shimmerPos =
                            (_shimmerController.value * targetWidth * 1.5) -
                                (targetWidth * 0.25);
                        return Positioned(
                          left: shimmerPos,
                          top: 0,
                          bottom: 0,
                          width: 40,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white.withValues(alpha: 0.0),
                                  Colors.white.withValues(alpha: 0.45),
                                  Colors.white.withValues(alpha: 0.0),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              );
            },
          ),
        ),
        if (widget.sublabel != null)
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              widget.sublabel!,
              style: GoogleFonts.outfit(
                fontSize: 10,
                color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
              ),
            ),
          ),
      ],
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────────
/// MAPOTECH CUSTOM LAZY LOADER
/// Wraps page or section contents. When [isLoading] is true:
/// 1. Simulates or displays a smooth 1% - 100% progress bar (left to right).
/// 2. Displays the specified [skeleton] or a modern generic skeleton.
/// 3. When [isLoading] finishes, the loader smoothly FADES OUT and the UI
///    smoothly FADES IN (with subtle micro-scale / slide-up).
/// ─────────────────────────────────────────────────────────────────────────────
class CustomLazyLoader extends ConsumerStatefulWidget {
  final bool isLoading;
  final Widget child;
  final Widget? skeleton;
  final String? loadingText;
  final String? loadingSubtext;
  final double? progress;
  final Duration transitionDuration;
  final bool showProgressBar;
  final bool fullPage;
  final EdgeInsetsGeometry padding;

  const CustomLazyLoader({
    super.key,
    required this.isLoading,
    required this.child,
    this.skeleton,
    this.loadingText,
    this.loadingSubtext,
    this.progress,
    this.transitionDuration = const Duration(milliseconds: 400),
    this.showProgressBar = true,
    this.fullPage = false,
    this.padding = EdgeInsets.zero,
  });

  @override
  ConsumerState<CustomLazyLoader> createState() => _CustomLazyLoaderState();
}

class _CustomLazyLoaderState extends ConsumerState<CustomLazyLoader>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  double _simulatedProgress = 0.05;
  Timer? _progressTimer;
  bool _hasCompleted = false;

  @override
  void initState() {
    super.initState();
    _hasCompleted = !widget.isLoading;

    _fadeController = AnimationController(
      vsync: this,
      duration: widget.transitionDuration,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOutCubic,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.015),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    ));

    if (widget.isLoading) {
      _startSimulatedProgress();
    } else {
      _simulatedProgress = 1.0;
      _fadeController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(covariant CustomLazyLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isLoading != widget.isLoading) {
      if (widget.isLoading) {
        _hasCompleted = false;
        _fadeController.reset();
        _startSimulatedProgress();
      } else {
        _completeAndTransition();
      }
    }
  }

  void _startSimulatedProgress() {
    _progressTimer?.cancel();
    _simulatedProgress = 0.05;
    // Stepwise increment from 5% to 92% smoothly
    _progressTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_hasCompleted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_simulatedProgress < 0.88) {
          _simulatedProgress += 0.035;
        } else if (_simulatedProgress < 0.96) {
          _simulatedProgress += 0.008;
        }
      });
    });
  }

  void _completeAndTransition() {
    _progressTimer?.cancel();
    setState(() {
      _simulatedProgress = 1.0;
    });

    // Small delay so 100% is visible for a moment, then fade out loader & fade in UI
    Future.delayed(const Duration(milliseconds: 140), () {
      if (!mounted) return;
      _fadeController.forward().then((_) {
        if (mounted) {
          setState(() {
            _hasCompleted = true;
          });
        }
      });
    });
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasCompleted && !widget.isLoading) {
      return Padding(
        padding: widget.padding,
        child: widget.child,
      );
    }

    final state = ref.watch(landingPageProvider);
    final notifier = ref.read(landingPageProvider.notifier);
    final primaryColor = notifier.getPrimaryColor();
    final secondaryColor = notifier.getSecondaryColor();
    final isEn = state.language == 'en';

    final effectiveProgress = widget.progress ?? _simulatedProgress;
    final defaultText = isEn ? 'Loading content...' : 'Memuat konten...';
    final displayText = widget.loadingText ?? defaultText;

    final loaderWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.showProgressBar)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: notifier.getCardColor(),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: notifier.getBorderColor()),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: state.appearance == 'dark' ? 0.2 : 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: CustomProgressBar(
              value: effectiveProgress,
              label: displayText,
              sublabel: widget.loadingSubtext,
              primaryColor: primaryColor,
              secondaryColor: secondaryColor,
              height: 6.5,
            ),
          ),
        SkeletonScope(
          child: widget.skeleton ?? const SkeletonGenericPage(),
        ),
      ],
    );

    return Padding(
      padding: widget.padding,
      child: Stack(
        children: [
          // Loader View (Fades out)
          if (!widget.isLoading || _fadeController.value < 1.0)
            FadeTransition(
              opacity: Tween<double>(begin: 1.0, end: 0.0).animate(_fadeAnimation),
              child: IgnorePointer(
                ignoring: !widget.isLoading,
                child: loaderWidget,
              ),
            ),

          // Real Content View (Fades and slides in)
          if (!widget.isLoading || _fadeController.value > 0.0)
            FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: widget.child,
              ),
            ),
        ],
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────────
/// MAPOTECH CUSTOM PAGE LOADER (STANDALONE)
/// Use directly as a return widget inside `build` when loading:
/// ```dart
/// if (_isLoading) {
///   return CustomPageLoader(
///     message: 'Memuat data...',
///     skeleton: const SkeletonChildrenList(),
///   );
/// }
/// ```
/// ─────────────────────────────────────────────────────────────────────────────
class CustomPageLoader extends ConsumerStatefulWidget {
  final String? message;
  final String? submessage;
  final Widget? skeleton;
  final bool showProgressBar;
  final double? progress;
  final EdgeInsetsGeometry padding;

  const CustomPageLoader({
    super.key,
    this.message,
    this.submessage,
    this.skeleton,
    this.showProgressBar = true,
    this.progress,
    this.padding = EdgeInsets.zero,
  });

  @override
  ConsumerState<CustomPageLoader> createState() => _CustomPageLoaderState();
}

class _CustomPageLoaderState extends ConsumerState<CustomPageLoader> {
  double _simulated = 0.08;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.progress == null) {
      _timer = Timer.periodic(const Duration(milliseconds: 60), (t) {
        if (!mounted) {
          t.cancel();
          return;
        }
        setState(() {
          if (_simulated < 0.85) {
            _simulated += 0.04;
          } else if (_simulated < 0.95) {
            _simulated += 0.006;
          }
        });
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(landingPageProvider);
    final notifier = ref.read(landingPageProvider.notifier);
    final primaryColor = notifier.getPrimaryColor();
    final secondaryColor = notifier.getSecondaryColor();
    final isEn = state.language == 'en';

    final text = widget.message ?? (isEn ? 'Loading data...' : 'Memuat data...');
    final val = widget.progress ?? _simulated;

    return Padding(
      padding: widget.padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.showProgressBar)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: notifier.getCardColor(),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: notifier.getBorderColor()),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: state.appearance == 'dark' ? 0.2 : 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: CustomProgressBar(
                value: val,
                label: text,
                sublabel: widget.submessage,
                primaryColor: primaryColor,
                secondaryColor: secondaryColor,
                height: 6.5,
              ),
            ),
          SkeletonScope(
            child: widget.skeleton ?? const SkeletonGenericPage(),
          ),
        ],
      ),
    );
  }
}
