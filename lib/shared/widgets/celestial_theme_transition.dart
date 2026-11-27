import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

/// Visual mode for a theme transition between `light`, `dark`, and `rev`.
enum CelestialTransitionKind {
  /// Light <-> Dark: bottom-middle pivoted 180° rotating Day/Night disc.
  circularDayNight,

  /// Light/Dark -> Relva (`rev`): upward bottom-to-top reveal with soft
  /// frosted blur until standby while Earth-to-space ascent animates.
  galaxyAscend,

  /// Relva (`rev`) -> Light/Dark: downward top-to-bottom reveal with soft
  /// frosted blur until standby while space-to-sky descent animates.
  galaxyDescend,
}

/// Pose snapshot for a celestial orb or emblem at a moment in time.
class CelestialOrbPose {
  final Offset center;
  final double opacity;
  final double scale;
  final double rippleProgress;

  const CelestialOrbPose({
    required this.center,
    this.opacity = 1.0,
    this.scale = 1.0,
    this.rippleProgress = 0.0,
  });
}

/// Pure geometric calculator for Sun, Moon, Earth horizon, and Relva (`♪`)
/// positions and transition paths across Light, Dark, and Relva (`rev`) modes.
class CelestialOrbitGeometry {
  CelestialOrbitGeometry._();

  /// Base radius of the crisp Sun / Moon orb disc.
  static const double orbRadius = 24.0;

  /// Normalized timeline fraction when orbital / celestial movement settles.
  static const double arrivalProgress = 0.50;

  /// Normalized timeline fraction when showcase overlays start fading out.
  static const double fadeOutStartProgress = 0.78;

  /// Classifies which visual transition choreography applies.
  static CelestialTransitionKind transitionKind({
    required String fromAppearance,
    required String toAppearance,
  }) {
    if (toAppearance == 'rev' && fromAppearance != 'rev') {
      return CelestialTransitionKind.galaxyAscend;
    }
    if (fromAppearance == 'rev' && toAppearance != 'rev') {
      return CelestialTransitionKind.galaxyDescend;
    }
    return CelestialTransitionKind.circularDayNight;
  }

  /// Top-middle resting position for Light (Sun) and Dark (Moon).
  static Offset centerTop(Rect skyBounds, {bool isDashboard = false}) {
    final topY = skyBounds.top + (isDashboard ? 40.0 : 96.0);
    return Offset(skyBounds.left + skyBounds.width * 0.5, topY);
  }

  /// Lower position above the curved Earth horizon where the previous Sun/Moon
  /// stays behind ("tetap tertinggal di bawah") when ascending into `rev`.
  static Offset leftBehindBottomTarget(Rect skyBounds, {bool isDashboard = false}) {
    final topY = centerTop(skyBounds, isDashboard: isDashboard).dy;
    final earthHoverY = (skyBounds.top + skyBounds.height * 0.76)
        .clamp(topY + 60.0, skyBounds.bottom - 110.0);
    return Offset(skyBounds.left + skyBounds.width * 0.5, earthHoverY);
  }

  /// Center position of the glowing `♪` emblem inside the Relva space animation.
  static Offset galaxyLogoCenter(Rect skyBounds) {
    return Offset(
      skyBounds.left + skyBounds.width * 0.5,
      skyBounds.top + skyBounds.height * 0.34,
    );
  }

  /// Vertical peak Y of Earth's curved horizon as the camera climbs from Earth
  /// into outer space (`luar angkasa`): starts around 62% height and sinks
  /// down to 88% height as altitude increases.
  static double earthHorizonPeakY(Rect skyBounds, double progress) {
    final climb = Curves.easeOutCubic.transform((progress / 0.65).clamp(0.0, 1.0));
    final startY = skyBounds.top + skyBounds.height * 0.62;
    final endY = skyBounds.top + skyBounds.height * 0.88;
    return ui.lerpDouble(startY, endY, climb)!;
  }

  /// Bottom-middle pivot ("titik pusat") of the rotating Day/Night sky disc.
  static Offset discPivot(Rect skyBounds, Size viewportSize) {
    return Offset(skyBounds.left + skyBounds.width * 0.5, viewportSize.height);
  }

  /// Point along the bottom-middle pivoted rotating Day/Night disc orbit
  /// (`angle = -pi/2` is middle-top, `-pi` is bottom-left, `0` is bottom-right).
  static Offset bottomPivotOrbPoint({
    required Offset pivot,
    required Rect skyBounds,
    required double topY,
    required double angle,
  }) {
    final rx = math.max(40.0, skyBounds.width * 0.5 - 38.0);
    final ry = math.max(60.0, pivot.dy - topY);
    return Offset(
      pivot.dx + rx * math.cos(angle),
      pivot.dy + ry * math.sin(angle),
    );
  }

  /// Bottom-left corner target where outgoing celestial orbs set.
  static Offset bottomLeftExit(Rect skyBounds, Size viewportSize) {
    return Offset(skyBounds.left + 38.0, viewportSize.height);
  }

  /// Bottom-right corner origin where incoming celestial orbs rise.
  static Offset bottomRightEntry(Rect skyBounds, Size viewportSize) {
    return Offset(skyBounds.right - 38.0, viewportSize.height);
  }

  /// Computes a point along an exact geometric circular arc from [start] to [end],
  /// bowing toward [preferredBowDirection] with sagitta `chord * sagittaRatio`.
  static Offset circularArcPoint(
    Offset start,
    Offset end,
    double t, {
    double sagittaRatio = 0.28,
    Offset preferredBowDirection = const Offset(0, -1),
  }) {
    final clampedT = t.clamp(0.0, 1.0);
    final delta = end - start;
    final dist = delta.distance;
    if (dist < 1.0) {
      return Offset.lerp(start, end, clampedT) ?? end;
    }

    final nA = Offset(-delta.dy / dist, delta.dx / dist);
    final nB = Offset(delta.dy / dist, -delta.dx / dist);
    final dotA =
        nA.dx * preferredBowDirection.dx + nA.dy * preferredBowDirection.dy;
    final dotB =
        nB.dx * preferredBowDirection.dx + nB.dy * preferredBowDirection.dy;
    final unitBow = dotA >= dotB ? nA : nB;

    final h = (dist * sagittaRatio).clamp(1.0, dist * 0.45);
    final rCircle = (dist * dist) / (8.0 * h) + h * 0.5;
    final mid = (start + end) * 0.5;
    final peak = mid + unitBow * h;
    final circleCenter = mid - unitBow * (rCircle - h);

    final aStart = math.atan2(
      start.dy - circleCenter.dy,
      start.dx - circleCenter.dx,
    );
    final aEnd = math.atan2(
      end.dy - circleCenter.dy,
      end.dx - circleCenter.dx,
    );
    final aPeak = math.atan2(
      peak.dy - circleCenter.dy,
      peak.dx - circleCenter.dx,
    );

    final daPeak = _normalizeSignedAngle(aPeak - aStart);
    var da = _normalizeSignedAngle(aEnd - aStart);
    if (daPeak != 0 && da != 0 && daPeak.sign != da.sign) {
      da = da > 0 ? da - 2 * math.pi : da + 2 * math.pi;
    }

    final angle = aStart + da * clampedT;
    return Offset(
      circleCenter.dx + rCircle * math.cos(angle),
      circleCenter.dy + rCircle * math.sin(angle),
    );
  }

  static double _normalizeSignedAngle(double angle) {
    var result = angle % (2 * math.pi);
    if (result > math.pi) result -= 2 * math.pi;
    if (result < -math.pi) result += 2 * math.pi;
    return result;
  }

  /// Computes the fade-out factor `[1.0 -> 0.0]` during `[fadeOutStartProgress, 1.0]`.
  static double globalFadeOutAt(double progress) {
    final t = progress.clamp(0.0, 1.0);
    final fadeOutT =
        ((t - fadeOutStartProgress) / (1.0 - fadeOutStartProgress))
            .clamp(0.0, 1.0);
    return 1.0 - Curves.easeInOut.transform(fadeOutT);
  }

  /// Computes the `♪` emblem pose during ascent (`toAppearance == 'rev'`) or
  /// downward recession when leaving Relva (`fromAppearance == 'rev'`).
  static CelestialOrbPose? galaxyLogoPose({
    required String fromAppearance,
    required String toAppearance,
    required double progress,
    required Rect skyBounds,
  }) {
    final t = progress.clamp(0.0, 1.0);

    if (toAppearance == 'rev' && fromAppearance != 'rev') {
      final sweepT =
          Curves.easeOutCubic.transform((t / arrivalProgress).clamp(0.0, 1.0));
      final fadeIn =
          Curves.easeOut.transform(((t - 0.12) / 0.24).clamp(0.0, 1.0));
      final fadeOut = globalFadeOutAt(t);
      final opacity = (fadeIn * fadeOut).clamp(0.0, 1.0);
      if (opacity <= 0.001) return null;

      final target = galaxyLogoCenter(skyBounds);
      final start = Offset(target.dx, skyBounds.top + skyBounds.height * 0.62);
      final center = Offset.lerp(start, target, sweepT)!;
      final scale = ui.lerpDouble(0.68, 1.0, sweepT)! *
          ui.lerpDouble(1.0, 0.90, 1.0 - fadeOut)!;

      return CelestialOrbPose(
        center: center,
        opacity: opacity,
        scale: scale,
        rippleProgress: t,
      );
    }

    if (fromAppearance == 'rev' && toAppearance != 'rev') {
      final descendT = Curves.easeInCubic.transform((t / 0.38).clamp(0.0, 1.0));
      final opacity = (1.0 - descendT).clamp(0.0, 1.0);
      if (opacity <= 0.001) return null;

      // As we descend from outer space back to Earth's sky, the ♪ crest
      // recedes upward out of view while the Sun/Moon awaits below.
      final start = galaxyLogoCenter(skyBounds);
      final end = Offset(start.dx, skyBounds.top + skyBounds.height * 0.10);
      return CelestialOrbPose(
        center: Offset.lerp(start, end, descendT)!,
        opacity: opacity,
        scale: ui.lerpDouble(1.0, 0.72, descendT)!,
        rippleProgress: t,
      );
    }

    return null;
  }

  /// Computes animated Sun & Moon poses at normalized transition [progress] in `[0, 1]`.
  static ({CelestialOrbPose? sun, CelestialOrbPose? moon}) transitionPoses({
    required String fromAppearance,
    required String toAppearance,
    required double progress,
    required Rect skyBounds,
    required Size viewportSize,
    bool isDashboard = false,
    CelestialOrbPose? interruptedSunStart,
    CelestialOrbPose? interruptedMoonStart,
  }) {
    final t = progress.clamp(0.0, 1.0);
    final kind = transitionKind(
      fromAppearance: fromAppearance,
      toAppearance: toAppearance,
    );

    final travelT = (t / arrivalProgress).clamp(0.0, 1.0);
    final orbitT = Curves.easeInOutCubic.transform(travelT);
    final enterOpacity =
        Curves.easeOut.transform((travelT / 0.25).clamp(0.0, 1.0));
    final exitOpacity =
        1.0 - Curves.easeIn.transform(((travelT - 0.58) / 0.38).clamp(0.0, 1.0));
    final enterScale =
        ui.lerpDouble(0.54, 1.0, Curves.easeOutCubic.transform(travelT))!;
    final exitScale =
        ui.lerpDouble(1.0, 0.54, Curves.easeInOut.transform(travelT))!;

    final globalFadeOut = globalFadeOutAt(t);
    final globalFadeScale = ui.lerpDouble(1.0, 0.88, 1.0 - globalFadeOut)!;

    final topMid = centerTop(skyBounds, isDashboard: isDashboard);
    final pivot = discPivot(skyBounds, viewportSize);
    final earthHover = leftBehindBottomTarget(skyBounds, isDashboard: isDashboard);
    final botLeft = bottomLeftExit(skyBounds, viewportSize);

    // 1. Descending from Relva (`rev`) -> Light or Dark:
    // Sun (for Light) or Moon (for Dark) is ALREADY positioned at top-middle!
    if (kind == CelestialTransitionKind.galaxyDescend &&
        interruptedSunStart == null &&
        interruptedMoonStart == null) {
      final revealAppear = Curves.easeOut.transform((t / 0.16).clamp(0.0, 1.0));
      final opacity = (revealAppear * globalFadeOut).clamp(0.0, 1.0);
      final scale = ui.lerpDouble(0.88, 1.0, revealAppear)! * globalFadeScale;
      if (opacity <= 0.001) return (sun: null, moon: null);

      final topPose = CelestialOrbPose(
        center: topMid,
        opacity: opacity,
        scale: scale,
        rippleProgress: travelT,
      );
      return toAppearance == 'dark'
          ? (sun: null, moon: topPose)
          : (sun: topPose, moon: null);
    }

    // 2. Ascending into Relva (`rev`) from Light/Dark:
    // The previous Sun/Moon drops down and stays left behind at the bottom
    // above the Earth horizon as the space animation rises into the sky.
    if (kind == CelestialTransitionKind.galaxyAscend &&
        interruptedSunStart == null &&
        interruptedMoonStart == null) {
      if (globalFadeOut <= 0.001) return (sun: null, moon: null);
      final pos = Offset.lerp(topMid, earthHover, orbitT)!;
      final scale = ui.lerpDouble(1.0, 0.82, orbitT)! * globalFadeScale;

      final leftBehindPose = CelestialOrbPose(
        center: pos,
        opacity: globalFadeOut,
        scale: scale,
        rippleProgress: travelT,
      );
      return fromAppearance == 'dark'
          ? (sun: null, moon: leftBehindPose)
          : (sun: leftBehindPose, moon: null);
    }

    // 3. Light <-> Dark rotating Day/Night sky disc around bottom-middle pivot
    //    (Sun/Moon stay on their respective Light/Dark halves of the rotating disc).
    CelestialOrbPose? sunPose;
    CelestialOrbPose? moonPose;

    final hadSun = fromAppearance == 'light';
    final wantsSun = toAppearance == 'light';

    if (hadSun || wantsSun || interruptedSunStart != null) {
      Offset sunCenter;
      double opacity;
      double scale;

      if (interruptedSunStart != null) {
        final sunStart = interruptedSunStart.center;
        if (wantsSun) {
          sunCenter = circularArcPoint(
            sunStart,
            topMid,
            orbitT,
            sagittaRatio: 0.22,
            preferredBowDirection: const Offset(1, -1),
          );
          opacity = ui.lerpDouble(
            interruptedSunStart.opacity,
            1.0,
            enterOpacity,
          )! * globalFadeOut;
          scale = ui.lerpDouble(interruptedSunStart.scale, 1.0, orbitT)! *
              globalFadeScale;
        } else if (toAppearance == 'rev') {
          sunCenter = Offset.lerp(sunStart, earthHover, orbitT)!;
          opacity = interruptedSunStart.opacity * globalFadeOut;
          scale = ui.lerpDouble(interruptedSunStart.scale, 0.82, orbitT)! *
              globalFadeScale;
        } else {
          sunCenter = circularArcPoint(
            sunStart,
            botLeft,
            orbitT,
            sagittaRatio: 0.28,
            preferredBowDirection: const Offset(-1, -1),
          );
          opacity = interruptedSunStart.opacity * exitOpacity * globalFadeOut;
          scale = ui.lerpDouble(interruptedSunStart.scale, 0.54, orbitT)!;
        }
      } else if (fromAppearance == 'light' && toAppearance == 'dark') {
        // Rotating counter-clockwise around bottom-middle pivot:
        // Sun moves from middle-top (-pi/2) down to bottom-left (-pi).
        final angle = -math.pi * 0.5 - (math.pi * 0.5) * orbitT;
        sunCenter = bottomPivotOrbPoint(
          pivot: pivot,
          skyBounds: skyBounds,
          topY: topMid.dy,
          angle: angle,
        );
        opacity = exitOpacity * globalFadeOut;
        scale = exitScale;
      } else if (fromAppearance == 'dark' && toAppearance == 'light') {
        // Rotating counter-clockwise around bottom-middle pivot:
        // Sun rises from bottom-right (0) up to middle-top (-pi/2).
        final angle = -(math.pi * 0.5) * orbitT;
        sunCenter = bottomPivotOrbPoint(
          pivot: pivot,
          skyBounds: skyBounds,
          topY: topMid.dy,
          angle: angle,
        );
        opacity = enterOpacity * globalFadeOut;
        scale = enterScale * globalFadeScale;
      } else {
        sunCenter = topMid;
        opacity = wantsSun ? globalFadeOut : 0.0;
        scale = globalFadeScale;
      }

      if (opacity > 0.001) {
        sunPose = CelestialOrbPose(
          center: sunCenter,
          opacity: opacity.clamp(0.0, 1.0),
          scale: scale,
          rippleProgress: travelT,
        );
      }
    }

    final hadMoon = fromAppearance == 'dark';
    final wantsMoon = toAppearance == 'dark';

    if (hadMoon || wantsMoon || interruptedMoonStart != null) {
      Offset moonCenter;
      double opacity;
      double scale;

      if (interruptedMoonStart != null) {
        final moonStart = interruptedMoonStart.center;
        if (wantsMoon) {
          moonCenter = circularArcPoint(
            moonStart,
            topMid,
            orbitT,
            sagittaRatio: 0.22,
            preferredBowDirection: const Offset(1, -1),
          );
          opacity = ui.lerpDouble(
            interruptedMoonStart.opacity,
            1.0,
            enterOpacity,
          )! * globalFadeOut;
          scale = ui.lerpDouble(interruptedMoonStart.scale, 1.0, orbitT)! *
              globalFadeScale;
        } else if (toAppearance == 'rev') {
          moonCenter = Offset.lerp(moonStart, earthHover, orbitT)!;
          opacity = interruptedMoonStart.opacity * globalFadeOut;
          scale = ui.lerpDouble(interruptedMoonStart.scale, 0.82, orbitT)! *
              globalFadeScale;
        } else {
          moonCenter = circularArcPoint(
            moonStart,
            botLeft,
            orbitT,
            sagittaRatio: 0.28,
            preferredBowDirection: const Offset(-1, -1),
          );
          opacity = interruptedMoonStart.opacity * exitOpacity * globalFadeOut;
          scale = ui.lerpDouble(interruptedMoonStart.scale, 0.54, orbitT)!;
        }
      } else if (fromAppearance == 'light' && toAppearance == 'dark') {
        // Rotating counter-clockwise around bottom-middle pivot:
        // Moon rises from bottom-right (0) up to middle-top (-pi/2).
        final angle = -(math.pi * 0.5) * orbitT;
        moonCenter = bottomPivotOrbPoint(
          pivot: pivot,
          skyBounds: skyBounds,
          topY: topMid.dy,
          angle: angle,
        );
        opacity = enterOpacity * globalFadeOut;
        scale = enterScale * globalFadeScale;
      } else if (fromAppearance == 'dark' && toAppearance == 'light') {
        // Rotating counter-clockwise around bottom-middle pivot:
        // Moon sets from middle-top (-pi/2) down to bottom-left (-pi).
        final angle = -math.pi * 0.5 - (math.pi * 0.5) * orbitT;
        moonCenter = bottomPivotOrbPoint(
          pivot: pivot,
          skyBounds: skyBounds,
          topY: topMid.dy,
          angle: angle,
        );
        opacity = exitOpacity * globalFadeOut;
        scale = exitScale;
      } else {
        moonCenter = topMid;
        opacity = wantsMoon ? globalFadeOut : 0.0;
        scale = globalFadeScale;
      }

      if (opacity > 0.001) {
        moonPose = CelestialOrbPose(
          center: moonCenter,
          opacity: opacity.clamp(0.0, 1.0),
          scale: scale,
          rippleProgress: travelT,
        );
      }
    }

    return (sun: sunPose, moon: moonPose);
  }
}

/// Coordinates theme change animations, screen snapshots, and sky bounds
/// between `LandingPageNotifier`, `CelestialThemeTransitionHost`, and `CelestialSkyBackdrop`.
class CelestialThemeCoordinator {
  CelestialThemeCoordinator._();
  static final CelestialThemeCoordinator instance = CelestialThemeCoordinator._();

  final ValueNotifier<bool> isTransitioning = ValueNotifier<bool>(false);

  _CelestialThemeTransitionHostState? _host;
  final List<_CelestialSkyAnchor> _skyAnchors = [];

  /// Helper to obtain the global center of a tapped widget [context].
  static Offset? globalCenterOf(BuildContext context) {
    final renderObject = context.findRenderObject();
    if (renderObject is RenderBox && renderObject.hasSize) {
      return renderObject.localToGlobal(renderObject.size.center(Offset.zero));
    }
    return null;
  }

  void _attachHost(_CelestialThemeTransitionHostState host) {
    _host = host;
  }

  void _detachHost(_CelestialThemeTransitionHostState host) {
    if (_host == host) {
      _host = null;
      isTransitioning.value = false;
    }
  }

  void _registerSkyAnchor(_CelestialSkyAnchor anchor) {
    _skyAnchors.removeWhere((a) => a.key == anchor.key);
    _skyAnchors.add(anchor);
  }

  void _unregisterSkyAnchor(GlobalKey key) {
    _skyAnchors.removeWhere((a) => a.key == key);
  }

  ({Rect skyBounds, bool isDashboard}) resolveActiveSkyBounds(Size viewportSize) {
    for (var i = _skyAnchors.length - 1; i >= 0; i--) {
      final anchor = _skyAnchors[i];
      final ctx = anchor.key.currentContext;
      if (ctx != null) {
        final ro = ctx.findRenderObject();
        if (ro is RenderBox && ro.hasSize && ro.attached) {
          final origin = ro.localToGlobal(Offset.zero);
          final size = ro.size;
          if (size.width > 0 && size.height > 0) {
            return (
              skyBounds: origin & size,
              isDashboard: anchor.isDashboard,
            );
          }
        }
      }
    }
    return (
      skyBounds: Offset.zero & viewportSize,
      isDashboard: false,
    );
  }

  /// Requests an animated theme transition from [currentAppearance] to
  /// [targetAppearance], invoking [commitState] once the old frame is captured.
  void requestAppearanceChange({
    required String currentAppearance,
    required String targetAppearance,
    required VoidCallback commitState,
    Offset? origin,
  }) {
    if (currentAppearance == targetAppearance) return;
    final host = _host;
    if (host != null && host.mounted) {
      host.beginTransition(
        fromAppearance: currentAppearance,
        toAppearance: targetAppearance,
        commitState: commitState,
        origin: origin,
      );
    } else {
      commitState();
    }
  }
}

class _CelestialSkyAnchor {
  final GlobalKey key;
  final bool isDashboard;

  const _CelestialSkyAnchor({
    required this.key,
    required this.isDashboard,
  });
}

/// Root host widget (installed via `MaterialApp.builder`) that captures the old
/// theme, executes a smooth circular reveal across all modes (`light`, `dark`,
/// `rev`), and animates either the Day/Night circular Sun & Moon swap or the
/// upward-to-space (`rev`) / downward-from-space (`rev -> light/dark`) animation.
class CelestialThemeTransitionHost extends StatefulWidget {
  final Widget child;
  final String appearance;

  const CelestialThemeTransitionHost({
    super.key,
    required this.child,
    required this.appearance,
  });

  @override
  State<CelestialThemeTransitionHost> createState() =>
      _CelestialThemeTransitionHostState();
}

class _CelestialThemeTransitionHostState
    extends State<CelestialThemeTransitionHost>
    with SingleTickerProviderStateMixin {
  final GlobalKey _contentBoundaryKey = GlobalKey();
  late final AnimationController _controller;

  ui.Image? _previousSnapshot;
  bool _isAnimating = false;
  String _fromAppearance = 'light';
  String _toAppearance = 'light';
  Offset? _revealOrigin;
  Rect _activeSkyBounds = Rect.zero;
  bool _activeIsDashboard = false;
  CelestialOrbPose? _interruptedSunStart;
  CelestialOrbPose? _interruptedMoonStart;
  int _pendingRequestToken = 0;

  @override
  void initState() {
    super.initState();
    _fromAppearance = widget.appearance;
    _toAppearance = widget.appearance;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2100),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _finishTransition();
        }
      });
    CelestialThemeCoordinator.instance._attachHost(this);
  }

  @override
  void didUpdateWidget(covariant CelestialThemeTransitionHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.appearance != widget.appearance &&
        !_isAnimating &&
        _toAppearance != widget.appearance) {
      _startVisualOnlyTransition(
        fromAppearance: oldWidget.appearance,
        toAppearance: widget.appearance,
      );
    }
  }

  @override
  void dispose() {
    CelestialThemeCoordinator.instance._detachHost(this);
    _disposeSnapshot();
    _controller.dispose();
    super.dispose();
  }

  void _disposeSnapshot() {
    _previousSnapshot?.dispose();
    _previousSnapshot = null;
  }

  void _finishTransition() {
    if (!mounted) return;
    _disposeSnapshot();
    setState(() {
      _isAnimating = false;
      _fromAppearance = _toAppearance;
      _interruptedSunStart = null;
      _interruptedMoonStart = null;
    });
    CelestialThemeCoordinator.instance.isTransitioning.value = false;
  }

  void _startVisualOnlyTransition({
    required String fromAppearance,
    required String toAppearance,
    Offset? origin,
  }) {
    final viewportSize = MediaQuery.sizeOf(context);
    final skyInfo =
        CelestialThemeCoordinator.instance.resolveActiveSkyBounds(viewportSize);
    _disposeSnapshot();
    setState(() {
      _fromAppearance = fromAppearance;
      _toAppearance = toAppearance;
      _revealOrigin = origin;
      _activeSkyBounds = skyInfo.skyBounds;
      _activeIsDashboard = skyInfo.isDashboard;
      _interruptedSunStart = null;
      _interruptedMoonStart = null;
      _isAnimating = true;
    });
    CelestialThemeCoordinator.instance.isTransitioning.value = true;
    _controller.forward(from: 0.0);
  }

  void beginTransition({
    required String fromAppearance,
    required String toAppearance,
    required VoidCallback commitState,
    Offset? origin,
  }) {
    final requestToken = ++_pendingRequestToken;
    final boundaryObject =
        _contentBoundaryKey.currentContext?.findRenderObject();

    if (boundaryObject is RenderRepaintBoundary &&
        boundaryObject.attached &&
        boundaryObject.hasSize &&
        !boundaryObject.debugNeedsPaint) {
      _captureAndStart(
        boundary: boundaryObject,
        fromAppearance: fromAppearance,
        toAppearance: toAppearance,
        commitState: commitState,
        origin: origin,
      );
      return;
    }

    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted || requestToken != _pendingRequestToken) return;
      final ro = _contentBoundaryKey.currentContext?.findRenderObject();
      final RenderRepaintBoundary? boundary =
          (ro is RenderRepaintBoundary &&
                  ro.attached &&
                  ro.hasSize &&
                  !ro.debugNeedsPaint)
              ? ro
              : null;
      _captureAndStart(
        boundary: boundary,
        fromAppearance: fromAppearance,
        toAppearance: toAppearance,
        commitState: commitState,
        origin: origin,
      );
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  void _captureAndStart({
    required RenderRepaintBoundary? boundary,
    required String fromAppearance,
    required String toAppearance,
    required VoidCallback commitState,
    Offset? origin,
  }) {
    final viewportSize = MediaQuery.sizeOf(context);
    final skyInfo =
        CelestialThemeCoordinator.instance.resolveActiveSkyBounds(viewportSize);

    CelestialOrbPose? currentSun;
    CelestialOrbPose? currentMoon;
    if (_isAnimating) {
      final midPoses = CelestialOrbitGeometry.transitionPoses(
        fromAppearance: _fromAppearance,
        toAppearance: _toAppearance,
        progress: _controller.value,
        skyBounds: _activeSkyBounds == Rect.zero
            ? skyInfo.skyBounds
            : _activeSkyBounds,
        viewportSize: viewportSize,
        isDashboard: _activeIsDashboard,
        interruptedSunStart: _interruptedSunStart,
        interruptedMoonStart: _interruptedMoonStart,
      );
      currentSun = midPoses.sun;
      currentMoon = midPoses.moon;
    }

    ui.Image? snapshot;
    if (boundary != null) {
      try {
        final dpr = MediaQuery.devicePixelRatioOf(context).clamp(1.0, 1.5);
        snapshot = boundary.toImageSync(pixelRatio: dpr);
      } catch (_) {
        snapshot = null;
      }
    }

    _disposeSnapshot();
    _previousSnapshot = snapshot;

    setState(() {
      _fromAppearance = fromAppearance;
      _toAppearance = toAppearance;
      _revealOrigin = origin;
      _activeSkyBounds = skyInfo.skyBounds;
      _activeIsDashboard = skyInfo.isDashboard;
      _interruptedSunStart = currentSun;
      _interruptedMoonStart = currentMoon;
      _isAnimating = true;
    });

    CelestialThemeCoordinator.instance.isTransitioning.value = true;
    commitState();
    _controller.forward(from: 0.0);
  }

  Offset _resolvedRevealOrigin(Size viewportSize) {
    if (_revealOrigin != null) {
      return _revealOrigin!;
    }
    return Offset(viewportSize.width * 0.5, viewportSize.height * 0.5);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        RepaintBoundary(
          key: _contentBoundaryKey,
          child: widget.child,
        ),
        if (_isAnimating)
          Positioned.fill(
            child: IgnorePointer(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final viewportSize = Size(
                    constraints.maxWidth,
                    constraints.maxHeight,
                  );
                  final revealOrigin = _resolvedRevealOrigin(viewportSize);
                  final skyBounds = _activeSkyBounds == Rect.zero
                      ? (Offset.zero & viewportSize)
                      : _activeSkyBounds;
                  final kind = CelestialOrbitGeometry.transitionKind(
                    fromAppearance: _fromAppearance,
                    toAppearance: _toAppearance,
                  );

                  return AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) {
                      final revealProgress = const Interval(
                        0.0,
                        0.50,
                        curve: Curves.easeInOutCubic,
                      ).transform(_controller.value);

                      if (kind == CelestialTransitionKind.circularDayNight) {
                        final bottomPivot = CelestialOrbitGeometry.discPivot(
                          skyBounds,
                          viewportSize,
                        );
                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            if (_previousSnapshot != null &&
                                revealProgress < 1.0)
                              ClipPath(
                                clipper: _BottomPivotDayNightDiscClipper(
                                  pivot: bottomPivot,
                                  progress: revealProgress,
                                ),
                                child: RawImage(
                                  image: _previousSnapshot,
                                  fit: BoxFit.fill,
                                ),
                              ),
                            CustomPaint(
                              painter: _CelestialTransitionPainter(
                                kind: kind,
                                fromAppearance: _fromAppearance,
                                toAppearance: _toAppearance,
                                progress: _controller.value,
                                revealProgress: revealProgress,
                                revealOrigin: revealOrigin,
                                skyBounds: skyBounds,
                                isDashboard: _activeIsDashboard,
                                hasSnapshot: _previousSnapshot != null,
                                interruptedSunStart: _interruptedSunStart,
                                interruptedMoonStart: _interruptedMoonStart,
                              ),
                            ),
                          ],
                        );
                      }

                      // Relva (`rev`) transitions keep the UI preview stationary
                      // in place:
                      // - Reveal goes UP (bottom -> top) when entering `rev`,
                      //   and DOWN (top -> bottom) when leaving `rev`.
                      // - Soft frosted BackdropFilter blur stays over the
                      //   revealed background (never black) until standby, then
                      //   sharpens cleanly back to crisp focus.
                      final isAscend =
                          kind == CelestialTransitionKind.galaxyAscend;
                      final blurSigma = _computeStandbyBlurSigma(_controller.value);
                      final sweepY = isAscend
                          ? ui.lerpDouble(viewportSize.height, 0.0, revealProgress)!
                          : ui.lerpDouble(0.0, viewportSize.height, revealProgress)!;

                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          if (blurSigma > 0.05 && revealProgress > 0.005)
                            ClipRect(
                              clipper: _VerticalSweepClipper(
                                sweepY: sweepY,
                                keepTop: !isAscend,
                              ),
                              child: BackdropFilter(
                                filter: ui.ImageFilter.blur(
                                  sigmaX: blurSigma,
                                  sigmaY: blurSigma,
                                ),
                                child: Container(
                                  color: (_toAppearance == 'dark'
                                          ? const Color(0xFF1E1B4B)
                                          : const Color(0xFFF0F5FA))
                                      .withValues(
                                    alpha: (blurSigma / 7.5) * 0.14,
                                  ),
                                ),
                              ),
                            ),
                          if (_previousSnapshot != null && revealProgress < 1.0)
                            ClipRect(
                              clipper: _VerticalSweepClipper(
                                sweepY: sweepY,
                                keepTop: isAscend,
                              ),
                              child: RawImage(
                                image: _previousSnapshot,
                                fit: BoxFit.fill,
                              ),
                            ),
                          CustomPaint(
                            painter: _CelestialTransitionPainter(
                              kind: kind,
                              fromAppearance: _fromAppearance,
                              toAppearance: _toAppearance,
                              progress: _controller.value,
                              revealProgress: revealProgress,
                              revealOrigin: revealOrigin,
                              skyBounds: skyBounds,
                              isDashboard: _activeIsDashboard,
                              hasSnapshot: _previousSnapshot != null,
                              interruptedSunStart: _interruptedSunStart,
                              interruptedMoonStart: _interruptedMoonStart,
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}

/// Smooth frosted blur sigma (`0 -> 7.5 -> 0`) so the background stays
/// softly blurred instead of black while the camera ascends/descends until
/// reaching standby near the end of the ~2s transition.
double _computeStandbyBlurSigma(double progress) {
  final t = progress.clamp(0.0, 1.0);
  final rampIn = Curves.easeOut.transform((t / 0.25).clamp(0.0, 1.0));
  final rampOut =
      1.0 - Curves.easeInOut.transform(((t - 0.60) / 0.36).clamp(0.0, 1.0));
  return (7.5 * rampIn * rampOut).clamp(0.0, 7.5);
}

/// Vertical sweep rect clipper used to wipe stationary previews cleanly
/// upward (`bottom -> top`) or downward (`top -> bottom`).
class _VerticalSweepClipper extends CustomClipper<Rect> {
  final double sweepY;
  final bool keepTop;

  const _VerticalSweepClipper({
    required this.sweepY,
    required this.keepTop,
  });

  @override
  Rect getClip(Size size) {
    final y = sweepY.clamp(0.0, size.height);
    return keepTop
        ? Rect.fromLTRB(0, 0, size.width, y)
        : Rect.fromLTRB(0, y, size.width, size.height);
  }

  @override
  bool shouldReclip(covariant _VerticalSweepClipper oldClipper) {
    return oldClipper.sweepY != sweepY || oldClipper.keepTop != keepTop;
  }
}

/// Clips the old-theme snapshot to the receding half of a giant Day/Night sky
/// disc pivoted at [pivot] (bottom-middle of screen). As [progress] goes 0 -> 1,
/// the dividing horizon diameter rotates 180° counter-clockwise (`0 -> -pi`),
/// revealing the opposite Light/Dark half smoothly without a circle in the middle.
class _BottomPivotDayNightDiscClipper extends CustomClipper<Path> {
  final Offset pivot;
  final double progress;

  const _BottomPivotDayNightDiscClipper({
    required this.pivot,
    required this.progress,
  });

  @override
  Path getClip(Size size) {
    final p = progress.clamp(0.0, 1.0);
    if (p <= 0.001) {
      return Path()..addRect(Offset.zero & size);
    }
    if (p >= 0.995) {
      return Path();
    }

    final maxRadius = _farthestCornerDistance(pivot, size) * 1.15;
    final remainingSweep = math.pi * (1.0 - p);
    return Path()
      ..moveTo(pivot.dx, pivot.dy)
      ..arcTo(
        Rect.fromCircle(center: pivot, radius: maxRadius),
        -math.pi,
        remainingSweep,
        false,
      )
      ..close();
  }

  @override
  bool shouldReclip(covariant _BottomPivotDayNightDiscClipper oldClipper) {
    return oldClipper.progress != progress || oldClipper.pivot != pivot;
  }
}

double _farthestCornerDistance(Offset origin, Size size) {
  final corners = [
    Offset.zero,
    Offset(size.width, 0),
    Offset(0, size.height),
    Offset(size.width, size.height),
  ];
  var maxDist = 0.0;
  for (final corner in corners) {
    final d = (corner - origin).distance;
    if (d > maxDist) maxDist = d;
  }
  return maxDist;
}

/// Lightweight layout anchor placed in `LandingPageLayout` and `DashboardShell`
/// so `CelestialThemeTransitionHost` always knows the active sky viewport bounds.
class CelestialSkyBackdrop extends StatefulWidget {
  final String appearance;
  final bool isDashboard;

  const CelestialSkyBackdrop({
    super.key,
    required this.appearance,
    this.isDashboard = false,
  });

  @override
  State<CelestialSkyBackdrop> createState() => _CelestialSkyBackdropState();
}

class _CelestialSkyBackdropState extends State<CelestialSkyBackdrop> {
  final GlobalKey _anchorKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    CelestialThemeCoordinator.instance._registerSkyAnchor(
      _CelestialSkyAnchor(key: _anchorKey, isDashboard: widget.isDashboard),
    );
  }

  @override
  void didUpdateWidget(covariant CelestialSkyBackdrop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isDashboard != widget.isDashboard) {
      CelestialThemeCoordinator.instance._registerSkyAnchor(
        _CelestialSkyAnchor(key: _anchorKey, isDashboard: widget.isDashboard),
      );
    }
  }

  @override
  void dispose() {
    CelestialThemeCoordinator.instance._unregisterSkyAnchor(_anchorKey);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(key: _anchorKey);
  }
}

class _CelestialTransitionPainter extends CustomPainter {
  final CelestialTransitionKind kind;
  final String fromAppearance;
  final String toAppearance;
  final double progress;
  final double revealProgress;
  final Offset revealOrigin;
  final Rect skyBounds;
  final bool isDashboard;
  final bool hasSnapshot;
  final CelestialOrbPose? interruptedSunStart;
  final CelestialOrbPose? interruptedMoonStart;

  const _CelestialTransitionPainter({
    required this.kind,
    required this.fromAppearance,
    required this.toAppearance,
    required this.progress,
    required this.revealProgress,
    required this.revealOrigin,
    required this.skyBounds,
    required this.isDashboard,
    required this.hasSnapshot,
    this.interruptedSunStart,
    this.interruptedMoonStart,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final maxRadius = _farthestCornerDistance(revealOrigin, size);
    final fadeOut = CelestialOrbitGeometry.globalFadeOutAt(progress);

    if (kind == CelestialTransitionKind.circularDayNight) {
      _paintRotatingDiscRevealEffects(canvas, size, maxRadius, fadeOut);
      _paintDayNightOrbsAndStars(canvas, size, fadeOut);
      return;
    }

    // 2. Mode-specific vertical sweep ("goes up" for rev, "goes down" for return)
    //    with luminous horizon sweep edge (no center circle wipe).
    if (kind == CelestialTransitionKind.galaxyAscend) {
      _paintGalaxyAscend(canvas, size, fadeOut);
      return;
    }

    _paintGalaxyDescend(canvas, size, fadeOut);
  }

  void _paintRotatingDiscRevealEffects(
    Canvas canvas,
    Size size,
    double maxRadius,
    double fadeOut,
  ) {
    final p = revealProgress.clamp(0.0, 1.0);
    final pivot = CelestialOrbitGeometry.discPivot(skyBounds, size);
    final pivotRadius = _farthestCornerDistance(pivot, size) * 1.15;
    final horizonAngle = -math.pi * p;
    final ringColor = _ringGlowColor(toAppearance);
    final skyTint = _skyTransitionColor(toAppearance);

    // 1. Subtle sky tint swept across the newly rotated Day/Night half (`[-pi*p, 0]`).
    final veilBell = math.sin(progress * math.pi).clamp(0.0, 1.0);
    if (veilBell > 0.005 && p > 0.005) {
      final veilAlpha = (hasSnapshot ? 0.12 : 0.22) * veilBell;
      if (p >= 0.995) {
        canvas.drawRect(
          Offset.zero & size,
          Paint()..color = skyTint.withValues(alpha: veilAlpha),
        );
      } else {
        final newHalf = Path()
          ..moveTo(pivot.dx, pivot.dy)
          ..arcTo(
            Rect.fromCircle(center: pivot, radius: pivotRadius),
            0.0,
            horizonAngle,
            false,
          )
          ..close();
        canvas.save();
        canvas.clipPath(newHalf);
        canvas.drawRect(
          Offset.zero & size,
          Paint()..color = skyTint.withValues(alpha: veilAlpha),
        );
        canvas.restore();
      }
    }

    // 2. Luminous terminator / horizon beam rotating 180° around the bottom-middle
    //    pivot separating the Day half and Night half (no circle in the middle).
    if (p > 0.005 && p < 0.995) {
      final edgeAlpha = math.sin(p * math.pi).clamp(0.18, 1.0);
      final beamEnd = pivot +
          Offset(math.cos(horizonAngle), math.sin(horizonAngle)) * pivotRadius;

      // Soft twilight glow band trailing just behind the rotating terminator.
      const trailWidth = 0.20;
      final trailSweep = math.min(trailWidth, math.pi * p);
      final trailPath = Path()
        ..moveTo(pivot.dx, pivot.dy)
        ..arcTo(
          Rect.fromCircle(center: pivot, radius: pivotRadius),
          horizonAngle,
          trailSweep,
          false,
        )
        ..close();
      canvas.drawPath(
        trailPath,
        Paint()
          ..shader = ui.Gradient.radial(
            pivot,
            pivotRadius * 0.85,
            [
              ringColor.withValues(alpha: 0.20 * edgeAlpha),
              skyTint.withValues(alpha: 0.08 * edgeAlpha),
              ringColor.withValues(alpha: 0.0),
            ],
            const [0.0, 0.55, 1.0],
          ),
      );

      // Glowing horizon line from bottom-middle pivot across the sky.
      canvas.drawLine(
        pivot,
        beamEnd,
        Paint()
          ..strokeWidth = 12.0
          ..color = ringColor.withValues(alpha: 0.26 * edgeAlpha)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9.0),
      );
      canvas.drawLine(
        pivot,
        beamEnd,
        Paint()
          ..strokeWidth = 2.4
          ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.88 * edgeAlpha),
      );
    }
  }

  void _paintGalaxyAscend(
    Canvas canvas,
    Size size,
    double fadeOut,
  ) {
    if (fadeOut <= 0.005) return;

    final sweepY = ui.lerpDouble(size.height, 0.0, revealProgress)!;

    // Revealed bottom-up area (`sweepY .. height`): Earth shrinks & sinks below
    // as clouds rush down, vertical launch streaks climb out into outer space,
    // curved galaxy trails bloom, and the ♪ emblem ascends.
    if (revealProgress > 0.005) {
      canvas.save();
      canvas.clipRect(Rect.fromLTRB(0, sweepY, size.width, size.height));

      _GalaxyCosmosRenderer.paintEarthHorizon(
        canvas: canvas,
        size: size,
        skyBounds: skyBounds,
        progress: progress,
        opacity: fadeOut,
      );

      _GalaxyCosmosRenderer.paintAtmosphereClouds(
        canvas: canvas,
        size: size,
        progress: progress,
        isAscending: true,
        opacity: fadeOut,
      );

      _GalaxyCosmosRenderer.paintAscentLaunchStreaks(
        canvas: canvas,
        size: size,
        progress: progress,
        opacity: fadeOut,
      );

      _GalaxyCosmosRenderer.paintCurvedStarTrails(
        canvas: canvas,
        size: size,
        progress: progress,
        opacity: fadeOut,
      );

      final logoPose = CelestialOrbitGeometry.galaxyLogoPose(
        fromAppearance: fromAppearance,
        toAppearance: toAppearance,
        progress: progress,
        skyBounds: skyBounds,
      );
      if (logoPose != null) {
        _GalaxyCosmosRenderer.paintMusicNoteLogo(
          canvas: canvas,
          pose: logoPose,
          phase: progress,
        );
      }

      canvas.restore();
    }

    // Luminous rising sweep beam going UP (`bottom -> top`).
    if (revealProgress > 0.005 && revealProgress < 0.995) {
      _paintVerticalSweepLine(
        canvas: canvas,
        width: size.width,
        y: sweepY,
        color: _ringGlowColor(toAppearance),
        opacity: math.sin(revealProgress * math.pi).clamp(0.2, 1.0),
      );
    }

    // Previous Sun/Moon drops downward toward the lower Earth horizon and stays
    // left behind below ("tetap tertinggal di bawah") while fading out by ~2s.
    final poses = CelestialOrbitGeometry.transitionPoses(
      fromAppearance: fromAppearance,
      toAppearance: toAppearance,
      progress: progress,
      skyBounds: skyBounds,
      viewportSize: size,
      isDashboard: isDashboard,
      interruptedSunStart: interruptedSunStart,
      interruptedMoonStart: interruptedMoonStart,
    );
    if (poses.sun != null) {
      _CelestialOrbRenderer.paintSun(
        canvas: canvas,
        pose: poses.sun!,
        baseOpacity: 1.0,
        phase: progress,
        drawTravelRipples: true,
      );
    }
    if (poses.moon != null) {
      _CelestialOrbRenderer.paintMoon(
        canvas: canvas,
        pose: poses.moon!,
        baseOpacity: 1.0,
        phase: progress,
        drawTravelRipples: true,
      );
    }
  }

  void _paintGalaxyDescend(
    Canvas canvas,
    Size size,
    double fadeOut,
  ) {
    final sweepY = ui.lerpDouble(0.0, size.height, revealProgress)!;

    // Receding ♪ emblem drifting upward out of space as we descend to sky.
    final logoPose = CelestialOrbitGeometry.galaxyLogoPose(
      fromAppearance: fromAppearance,
      toAppearance: toAppearance,
      progress: progress,
      skyBounds: skyBounds,
    );
    if (logoPose != null) {
      _GalaxyCosmosRenderer.paintMusicNoteLogo(
        canvas: canvas,
        pose: logoPose,
        phase: progress,
      );
    }

    if (revealProgress > 0.005) {
      // Revealed top-down area (`0 .. sweepY`): passing clouds lift upward and
      // Sun or Moon is ALREADY waiting at top-middle as you return from space.
      canvas.save();
      canvas.clipRect(Rect.fromLTRB(0, 0, size.width, sweepY));

      _GalaxyCosmosRenderer.paintAtmosphereClouds(
        canvas: canvas,
        size: size,
        progress: progress,
        isAscending: false,
        opacity: fadeOut,
      );

      if (toAppearance == 'dark') {
        final starAlpha =
            Curves.easeOut.transform((progress / 0.35).clamp(0.0, 1.0)) *
                fadeOut *
                0.82;
        if (starAlpha > 0.01) {
          _paintStarfield(
            canvas,
            skyBounds,
            opacity: starAlpha,
            phase: progress * 0.5,
            tint: const Color(0xFFE2E8F0),
          );
        }
      }

      final poses = CelestialOrbitGeometry.transitionPoses(
        fromAppearance: fromAppearance,
        toAppearance: toAppearance,
        progress: progress,
        skyBounds: skyBounds,
        viewportSize: size,
        isDashboard: isDashboard,
        interruptedSunStart: interruptedSunStart,
        interruptedMoonStart: interruptedMoonStart,
      );
      if (poses.sun != null) {
        _CelestialOrbRenderer.paintSun(
          canvas: canvas,
          pose: poses.sun!,
          baseOpacity: 1.0,
          phase: progress,
          drawTravelRipples: true,
        );
      }
      if (poses.moon != null) {
        _CelestialOrbRenderer.paintMoon(
          canvas: canvas,
          pose: poses.moon!,
          baseOpacity: 1.0,
          phase: progress,
          drawTravelRipples: true,
        );
      }

      canvas.restore();
    }

    if (revealProgress > 0.005 && revealProgress < 0.995) {
      _paintVerticalSweepLine(
        canvas: canvas,
        width: size.width,
        y: sweepY,
        color: _ringGlowColor(toAppearance),
        opacity: math.sin(revealProgress * math.pi).clamp(0.2, 1.0),
      );
    }
  }

  void _paintVerticalSweepLine({
    required Canvas canvas,
    required double width,
    required double y,
    required Color color,
    required double opacity,
  }) {
    canvas.drawLine(
      Offset(0, y),
      Offset(width, y),
      Paint()
        ..strokeWidth = 14.0
        ..color = color.withValues(alpha: 0.28 * opacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9.0),
    );
    canvas.drawLine(
      Offset(0, y),
      Offset(width, y),
      Paint()
        ..strokeWidth = 2.4
        ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.85 * opacity),
    );
  }

  void _paintDayNightOrbsAndStars(
    Canvas canvas,
    Size size,
    double fadeOut,
  ) {
    final arriveRamp = Curves.easeOut.transform(
      (progress / CelestialOrbitGeometry.arrivalProgress).clamp(0.0, 1.0),
    );
    if (toAppearance == 'dark') {
      final starAlpha = arriveRamp * fadeOut * 0.85;
      if (starAlpha > 0.01) {
        _paintStarfield(
          canvas,
          skyBounds,
          opacity: starAlpha,
          phase: progress * 0.5,
          tint: const Color(0xFFE2E8F0),
        );
      }
    } else if (fromAppearance == 'dark') {
      final starFadeOut = (1.0 - arriveRamp) * 0.7;
      if (starFadeOut > 0.01) {
        _paintStarfield(
          canvas,
          skyBounds,
          opacity: starFadeOut,
          phase: progress * 0.5,
          tint: const Color(0xFFE2E8F0),
        );
      }
    }

    final poses = CelestialOrbitGeometry.transitionPoses(
      fromAppearance: fromAppearance,
      toAppearance: toAppearance,
      progress: progress,
      skyBounds: skyBounds,
      viewportSize: size,
      isDashboard: isDashboard,
      interruptedSunStart: interruptedSunStart,
      interruptedMoonStart: interruptedMoonStart,
    );

    if (poses.sun != null) {
      _CelestialOrbRenderer.paintSun(
        canvas: canvas,
        pose: poses.sun!,
        baseOpacity: 1.0,
        phase: progress,
        drawTravelRipples: true,
      );
    }

    if (poses.moon != null) {
      _CelestialOrbRenderer.paintMoon(
        canvas: canvas,
        pose: poses.moon!,
        baseOpacity: 1.0,
        phase: progress,
        drawTravelRipples: true,
      );
    }
  }

  Color _skyTransitionColor(String target) {
    switch (target) {
      case 'dark':
        return const Color(0xFF1E1B4B);
      case 'rev':
        return const Color(0xFFB577F2);
      case 'light':
      default:
        return const Color(0xFFFFD166);
    }
  }

  Color _ringGlowColor(String target) {
    switch (target) {
      case 'dark':
        return const Color(0xFF48C9B0);
      case 'rev':
        return const Color(0xFFB577F2);
      case 'light':
      default:
        return const Color(0xFFFFB703);
    }
  }

  @override
  bool shouldRepaint(covariant _CelestialTransitionPainter oldDelegate) {
    return oldDelegate.kind != kind ||
        oldDelegate.progress != progress ||
        oldDelegate.revealProgress != revealProgress ||
        oldDelegate.fromAppearance != fromAppearance ||
        oldDelegate.toAppearance != toAppearance ||
        oldDelegate.revealOrigin != revealOrigin ||
        oldDelegate.skyBounds != skyBounds;
  }
}

/// Renders the curved galaxy meteor star-trails, the sleek bottom Earth horizon
/// visualization (ocean, continents, clouds, cyan-blue atmospheric limb), and
/// the glowing `♪` emblem over the clean Relva theme UI.
class _GalaxyCosmosRenderer {
  _GalaxyCosmosRenderer._();

  static void paintEarthHorizon({
    required Canvas canvas,
    required Size size,
    required Rect skyBounds,
    required double progress,
    required double opacity,
  }) {
    if (opacity <= 0.005) return;

    final w = size.width;
    final h = size.height;

    // As altitude climbs from Earth into outer space ("luar angkasa"), the
    // horizon sinks lower and curves tighter to suggest gaining orbital height.
    final climb =
        Curves.easeOutCubic.transform((progress / 0.65).clamp(0.0, 1.0));
    final startRadius = math.max(w * 1.35, h * 1.65);
    final endRadius = math.max(w * 0.85, h * 1.05);
    final earthRadius = ui.lerpDouble(startRadius, endRadius, climb)!;
    final horizonPeakY = CelestialOrbitGeometry.earthHorizonPeakY(
      skyBounds,
      progress,
    );
    final earthCenter = Offset(w * 0.5, horizonPeakY + earthRadius);
    final earthCircle =
        Path()..addOval(Rect.fromCircle(center: earthCenter, radius: earthRadius));

    // 1. Atmospheric cyan-lavender limb halo rising above Earth's curve.
    canvas.drawCircle(
      earthCenter,
      earthRadius + 28.0,
      Paint()
        ..shader = ui.Gradient.radial(
          earthCenter,
          earthRadius + 28.0,
          [
            const Color(0xFF38BDF8).withValues(alpha: 0.0),
            const Color(0xFF38BDF8).withValues(alpha: 0.24 * opacity),
            const Color(0xFFB577F2).withValues(alpha: 0.14 * opacity),
            const Color(0xFF38BDF8).withValues(alpha: 0.0),
          ],
          const [0.955, 0.985, 0.994, 1.0],
        ),
    );

    // 2. Clipped Earth surface: deep ocean blues, emerald continents, cloud wisps.
    canvas.save();
    canvas.clipPath(earthCircle);

    final oceanPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(w * 0.5, horizonPeakY),
        Offset(w * 0.5, h),
        [
          const Color(0xFF38BDF8).withValues(alpha: 0.85 * opacity),
          const Color(0xFF0284C7).withValues(alpha: 0.88 * opacity),
          const Color(0xFF1E3A8A).withValues(alpha: 0.92 * opacity),
        ],
        const [0.0, 0.35, 1.0],
      );
    canvas.drawRect(
      Rect.fromLTRB(0, horizonPeakY - 10, w, h),
      oceanPaint,
    );

    final landDriftX = progress * 14.0;
    final landPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(w * 0.2, horizonPeakY),
        Offset(w * 0.8, h),
        [
          const Color(0xFF34D399).withValues(alpha: 0.72 * opacity),
          const Color(0xFF059669).withValues(alpha: 0.78 * opacity),
        ],
      );

    final leftContinent = Path()
      ..moveTo(w * 0.08 + landDriftX, h * 0.90)
      ..quadraticBezierTo(w * 0.18 + landDriftX, h * 0.86, w * 0.29 + landDriftX, h * 0.89)
      ..quadraticBezierTo(w * 0.37 + landDriftX, h * 0.93, w * 0.28 + landDriftX, h * 1.02)
      ..lineTo(w * 0.05 + landDriftX, h * 1.02)
      ..close();
    canvas.drawPath(leftContinent, landPaint);

    final centerArchipelago = Path()
      ..moveTo(w * 0.44 + landDriftX * 0.7, h * 0.88)
      ..quadraticBezierTo(w * 0.53 + landDriftX * 0.7, h * 0.855, w * 0.61 + landDriftX * 0.7, h * 0.89)
      ..quadraticBezierTo(w * 0.55 + landDriftX * 0.7, h * 0.95, w * 0.45 + landDriftX * 0.7, h * 0.94)
      ..close();
    canvas.drawPath(centerArchipelago, landPaint);

    final rightContinent = Path()
      ..moveTo(w * 0.71 + landDriftX * 0.8, h * 0.89)
      ..quadraticBezierTo(w * 0.83 + landDriftX * 0.8, h * 0.865, w * 0.95 + landDriftX * 0.8, h * 0.92)
      ..lineTo(w * 0.96 + landDriftX * 0.8, h * 1.02)
      ..lineTo(w * 0.74 + landDriftX * 0.8, h * 1.02)
      ..close();
    canvas.drawPath(rightContinent, landPaint);

    final cloudDriftX = progress * 26.0;
    final cloudPaint = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.46 * opacity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9.0);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.24 + cloudDriftX, h * 0.91),
        width: w * 0.16,
        height: 18,
      ),
      cloudPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.56 + cloudDriftX * 0.8, h * 0.89),
        width: w * 0.20,
        height: 16,
      ),
      cloudPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.82 + cloudDriftX * 0.6, h * 0.93),
        width: w * 0.14,
        height: 16,
      ),
      cloudPaint,
    );

    canvas.restore();

    // 3. Crisp glowing blue-cyan-white Earth atmospheric rim.
    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = const Color(0xFFE0F2FE).withValues(alpha: 0.92 * opacity);
    final rimGlowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10.0
      ..color = const Color(0xFF38BDF8).withValues(alpha: 0.48 * opacity)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7.0);

    final startAngle =
        -math.pi * 0.5 - math.asin((w * 0.52 / earthRadius).clamp(0.0, 0.95));
    final sweepAngle = (-math.pi * 0.5 - startAngle) * 2;
    final rimRect = Rect.fromCircle(center: earthCenter, radius: earthRadius);
    canvas.drawArc(rimRect, startAngle, sweepAngle, false, rimGlowPaint);
    canvas.drawArc(rimRect, startAngle, sweepAngle, false, rimPaint);
  }

  /// Soft translucent cloud wisps rushing downward as we climb out of Earth's
  /// sky into space (or rushing upward when descending back to Earth).
  static void paintAtmosphereClouds({
    required Canvas canvas,
    required Size size,
    required double progress,
    required bool isAscending,
    required double opacity,
  }) {
    final cloudWindow = (progress / 0.48).clamp(0.0, 1.0);
    if (cloudWindow >= 1.0) return;

    final envelope =
        math.sin(cloudWindow * math.pi).clamp(0.0, 1.0) * opacity;
    if (envelope <= 0.01) return;

    const specs = <({double xFrac, double yFrac, double wFrac, double speed})>[
      (xFrac: 0.18, yFrac: 0.34, wFrac: 0.22, speed: 1.0),
      (xFrac: 0.78, yFrac: 0.28, wFrac: 0.24, speed: 1.15),
      (xFrac: 0.35, yFrac: 0.54, wFrac: 0.28, speed: 0.9),
      (xFrac: 0.68, yFrac: 0.58, wFrac: 0.20, speed: 1.25),
    ];

    final travelY = size.height * 0.36 * cloudWindow;
    final dir = isAscending ? 1.0 : -1.0;

    for (final c in specs) {
      final cx = size.width * c.xFrac;
      final cy = size.height * c.yFrac + dir * travelY * c.speed;
      final cw = size.width * c.wFrac;
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, cy), width: cw, height: 26.0),
        Paint()
          ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.34 * envelope)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14.0),
      );
    }
  }

  /// Vertical launch streaks rushing downward past the viewer during the climb
  /// from Earth into outer space ("luar angkasa").
  static void paintAscentLaunchStreaks({
    required Canvas canvas,
    required Size size,
    required double progress,
    required double opacity,
  }) {
    final climbWindow = ((progress - 0.06) / 0.56).clamp(0.0, 1.0);
    if (climbWindow <= 0.0 || climbWindow >= 1.0) return;

    final envelope = math.sin(climbWindow * math.pi).clamp(0.0, 1.0) * opacity;
    if (envelope <= 0.01) return;

    const streaks = <({double xFrac, double startY, double len, double speed})>[
      (xFrac: 0.10, startY: 0.12, len: 54.0, speed: 1.15),
      (xFrac: 0.22, startY: 0.24, len: 42.0, speed: 0.95),
      (xFrac: 0.34, startY: 0.08, len: 64.0, speed: 1.25),
      (xFrac: 0.66, startY: 0.10, len: 60.0, speed: 1.20),
      (xFrac: 0.78, startY: 0.22, len: 46.0, speed: 1.00),
      (xFrac: 0.90, startY: 0.14, len: 52.0, speed: 1.10),
    ];

    for (var i = 0; i < streaks.length; i++) {
      final s = streaks[i];
      final x = size.width * s.xFrac;
      final topY = size.height * s.startY +
          size.height * 0.55 * climbWindow * s.speed;
      final botY = topY + s.len;
      if (topY > size.height * 0.85) continue;

      final tint = i.isEven ? const Color(0xFF93C5FD) : const Color(0xFFE879F9);
      canvas.drawLine(
        Offset(x, topY),
        Offset(x, botY),
        Paint()
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 2.0
          ..shader = ui.Gradient.linear(
            Offset(x, topY),
            Offset(x, botY),
            [
              tint.withValues(alpha: 0.0),
              tint.withValues(alpha: 0.55 * envelope),
              const Color(0xFFFFFFFF).withValues(alpha: 0.85 * envelope),
            ],
            const [0.0, 0.55, 1.0],
          ),
      );
    }
  }

  static void paintCurvedStarTrails({
    required Canvas canvas,
    required Size size,
    required double progress,
    required double opacity,
  }) {
    final vortex = Offset(size.width * 0.50, size.height * 0.34);
    final maxDim = math.max(size.width, size.height);
    // Subtle upward climb in sky coordinates as we ascend into space.
    final climbOffset = Offset(0, -18.0 * progress);

    const trailSpecs = <({double rFrac, double startAngle, double sweep, double speed, bool isPink})>[
      (rFrac: 0.14, startAngle: 0.35, sweep: 0.14, speed: 0.25, isPink: false),
      (rFrac: 0.18, startAngle: 1.45, sweep: 0.12, speed: 0.22, isPink: true),
      (rFrac: 0.22, startAngle: 2.35, sweep: 0.18, speed: 0.28, isPink: false),
      (rFrac: 0.24, startAngle: 3.65, sweep: 0.15, speed: 0.24, isPink: true),
      (rFrac: 0.27, startAngle: 4.55, sweep: 0.20, speed: 0.30, isPink: false),
      (rFrac: 0.31, startAngle: 5.45, sweep: 0.17, speed: 0.26, isPink: true),
      (rFrac: 0.33, startAngle: 0.85, sweep: 0.16, speed: 0.21, isPink: false),
      (rFrac: 0.36, startAngle: 2.05, sweep: 0.21, speed: 0.27, isPink: false),
      (rFrac: 0.38, startAngle: 2.85, sweep: 0.15, speed: 0.23, isPink: true),
      (rFrac: 0.41, startAngle: 4.05, sweep: 0.19, speed: 0.29, isPink: false),
      (rFrac: 0.43, startAngle: 5.05, sweep: 0.14, speed: 0.22, isPink: true),
      (rFrac: 0.46, startAngle: 5.95, sweep: 0.22, speed: 0.31, isPink: false),
      (rFrac: 0.48, startAngle: 1.15, sweep: 0.16, speed: 0.24, isPink: true),
      (rFrac: 0.51, startAngle: 2.55, sweep: 0.18, speed: 0.26, isPink: false),
      (rFrac: 0.53, startAngle: 3.35, sweep: 0.14, speed: 0.20, isPink: true),
      (rFrac: 0.56, startAngle: 4.35, sweep: 0.21, speed: 0.28, isPink: false),
    ];

    final shiftedVortex = vortex + climbOffset;
    for (var i = 0; i < trailSpecs.length; i++) {
      final spec = trailSpecs[i];
      final radius = maxDim * spec.rFrac;
      final a0 = spec.startAngle + progress * spec.speed;
      final a1 = a0 + spec.sweep;
      final tail = Offset(
        shiftedVortex.dx + math.cos(a0) * radius,
        shiftedVortex.dy + math.sin(a0) * radius,
      );
      final head = Offset(
        shiftedVortex.dx + math.cos(a1) * radius,
        shiftedVortex.dy + math.sin(a1) * radius,
      );

      if (head.dy > size.height * 0.82 && tail.dy > size.height * 0.82) {
        continue;
      }

      final tailColor = spec.isPink
          ? const Color(0xFFEC4899)
          : const Color(0xFF7C3AED);
      final headColor = spec.isPink
          ? const Color(0xFFFDF2F8)
          : const Color(0xFF818CF8);
      final arcRect = Rect.fromCircle(center: shiftedVortex, radius: radius);

      final trailPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 2.2 + (i % 2) * 0.6
        ..shader = ui.Gradient.linear(
          tail,
          head,
          [
            tailColor.withValues(alpha: 0.0),
            tailColor.withValues(alpha: 0.65 * opacity),
            headColor.withValues(alpha: 0.92 * opacity),
          ],
          const [0.0, 0.55, 1.0],
        );

      canvas.drawArc(arcRect, a0, spec.sweep, false, trailPaint);

      canvas.drawCircle(
        head,
        2.0,
        Paint()..color = tailColor.withValues(alpha: 0.85 * opacity),
      );
    }

    const stars = <Offset>[
      Offset(0.14, 0.14),
      Offset(0.28, 0.25),
      Offset(0.41, 0.12),
      Offset(0.56, 0.18),
      Offset(0.71, 0.14),
      Offset(0.84, 0.24),
      Offset(0.21, 0.44),
      Offset(0.77, 0.46),
      Offset(0.36, 0.55),
      Offset(0.65, 0.52),
    ];
    for (var i = 0; i < stars.length; i++) {
      final pos = Offset(size.width * stars[i].dx, size.height * stars[i].dy) +
          climbOffset * 0.6;
      final twinkle =
          0.45 + 0.55 * math.sin(progress * 4 * math.pi + i * 1.1);
      canvas.drawCircle(
        pos,
        1.8 + (i % 2) * 0.8,
        Paint()
          ..color = const Color(0xFF9333EA)
              .withValues(alpha: (0.60 * twinkle * opacity).clamp(0.0, 1.0)),
      );
    }
  }

  /// Renders the stylized glowing `♪` emblem for Relva (`rev`) mode.
  static void paintMusicNoteLogo({
    required Canvas canvas,
    required CelestialOrbPose pose,
    required double phase,
  }) {
    final op = pose.opacity.clamp(0.0, 1.0);
    if (op <= 0.005) return;

    final c = pose.center;
    final r = 34.0 * pose.scale;

    canvas.drawCircle(
      c,
      r * 2.0,
      Paint()
        ..shader = ui.Gradient.radial(
          c,
          r * 2.0,
          [
            const Color(0xFFB577F2).withValues(alpha: 0.34 * op),
            const Color(0xFFFFB5E8).withValues(alpha: 0.20 * op),
            const Color(0xFF8B5CF6).withValues(alpha: 0.0),
          ],
          const [0.0, 0.55, 1.0],
        ),
    );

    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = ui.Gradient.radial(
          c - Offset(r * 0.25, r * 0.25),
          r * 1.25,
          [
            const Color(0xFFD946EF).withValues(alpha: 0.88 * op),
            const Color(0xFF9333EA).withValues(alpha: 0.90 * op),
            const Color(0xFF6D28D9).withValues(alpha: 0.92 * op),
          ],
          const [0.0, 0.58, 1.0],
        ),
    );

    final pulse = 0.5 + 0.5 * math.sin(phase * 3 * math.pi);
    canvas.drawCircle(
      c,
      r * (1.16 + pulse * 0.14),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..color = const Color(0xFFB577F2).withValues(alpha: 0.70 * op),
    );
    canvas.drawCircle(
      c,
      r * 1.44,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0xFFFFB5E8).withValues(alpha: 0.55 * op),
    );

    canvas.save();
    canvas.translate(c.dx, c.dy);

    final notePath = Path();
    final headCenter = Offset(-r * 0.20, r * 0.30);
    final headRect = Rect.fromCenter(
      center: Offset.zero,
      width: r * 0.54,
      height: r * 0.38,
    );
    final headMatrix = Matrix4.identity()
      ..translateByDouble(headCenter.dx, headCenter.dy, 0.0, 1.0)
      ..rotateZ(-0.42);
    notePath.addPath(
      Path()..addOval(headRect),
      Offset.zero,
      matrix4: headMatrix.storage,
    );

    final stemX = r * 0.02;
    final stemTopY = -r * 0.50;
    final stemBottomY = r * 0.30;
    final stemWidth = r * 0.11;
    notePath.addRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(
          stemX - stemWidth * 0.5,
          stemTopY,
          stemX + stemWidth * 0.5,
          stemBottomY,
        ),
        Radius.circular(stemWidth * 0.5),
      ),
    );

    final flagPath = Path()
      ..moveTo(stemX - stemWidth * 0.1, stemTopY)
      ..cubicTo(
        stemX + r * 0.24,
        stemTopY + r * 0.12,
        stemX + r * 0.52,
        stemTopY + r * 0.32,
        stemX + r * 0.32,
        stemTopY + r * 0.66,
      )
      ..cubicTo(
        stemX + r * 0.36,
        stemTopY + r * 0.40,
        stemX + r * 0.15,
        stemTopY + r * 0.30,
        stemX,
        stemTopY + r * 0.24,
      )
      ..close();
    notePath.addPath(flagPath, Offset.zero);

    canvas.drawPath(
      notePath,
      Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: op),
    );

    canvas.restore();

    _paintFourPointStar(
      canvas: canvas,
      center: c + Offset(r * 0.72, -r * 0.54),
      radius: (r * 0.16).clamp(3.0, 6.5),
      color: const Color(0xFFB577F2).withValues(alpha: 0.90 * op),
    );
    _paintFourPointStar(
      canvas: canvas,
      center: c + Offset(-r * 0.72, -r * 0.28),
      radius: (r * 0.12).clamp(2.5, 5.0),
      color: const Color(0xFFEC4899).withValues(alpha: 0.85 * op),
    );
  }
}

class _CelestialOrbRenderer {
  _CelestialOrbRenderer._();

  static void paintSun({
    required Canvas canvas,
    required CelestialOrbPose pose,
    required double baseOpacity,
    required double phase,
    bool drawTravelRipples = false,
  }) {
    final effectiveOpacity = (pose.opacity * baseOpacity).clamp(0.0, 1.0);
    if (effectiveOpacity <= 0.005) return;

    final r = CelestialOrbitGeometry.orbRadius * pose.scale;
    final center = pose.center;

    const coreInner = Color(0xFFFFFBE6);
    const coreMid = Color(0xFFFFC93C);
    const coreOuter = Color(0xFFFF9500);
    const haloColor = Color(0xFFFFC83D);

    final haloPaint = Paint()
      ..shader = ui.Gradient.radial(
        center,
        r * 2.25,
        [
          haloColor.withValues(alpha: 0.44 * effectiveOpacity),
          coreOuter.withValues(alpha: 0.16 * effectiveOpacity),
          haloColor.withValues(alpha: 0.0),
        ],
        const [0.25, 0.62, 1.0],
      );
    canvas.drawCircle(center, r * 2.25, haloPaint);

    if (drawTravelRipples) {
      _paintExpandingCircleRipples(
        canvas: canvas,
        center: center,
        baseRadius: r,
        progress: pose.rippleProgress,
        color: coreMid,
        opacity: effectiveOpacity,
      );
    }

    final rayAngleOffset = phase * 2 * math.pi;
    final rayPaint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = (2.2 * pose.scale).clamp(1.2, 3.0)
      ..color = coreMid.withValues(alpha: 0.68 * effectiveOpacity);
    const rayCount = 10;
    for (var i = 0; i < rayCount; i++) {
      final a = rayAngleOffset + (i * 2 * math.pi / rayCount);
      final inner = Offset(
        center.dx + math.cos(a) * (r * 1.15),
        center.dy + math.sin(a) * (r * 1.15),
      );
      final outer = Offset(
        center.dx + math.cos(a) * (r * 1.42),
        center.dy + math.sin(a) * (r * 1.42),
      );
      canvas.drawLine(inner, outer, rayPaint);
    }

    final sunPaint = Paint()
      ..shader = ui.Gradient.radial(
        center - Offset(r * 0.22, r * 0.22),
        r * 1.25,
        [
          coreInner.withValues(alpha: effectiveOpacity),
          coreMid.withValues(alpha: effectiveOpacity),
          coreOuter.withValues(alpha: effectiveOpacity),
        ],
        const [0.0, 0.58, 1.0],
      );
    canvas.drawCircle(center, r, sunPaint);
  }

  static void paintMoon({
    required Canvas canvas,
    required CelestialOrbPose pose,
    required double baseOpacity,
    required double phase,
    bool drawTravelRipples = false,
  }) {
    final effectiveOpacity = (pose.opacity * baseOpacity).clamp(0.0, 1.0);
    if (effectiveOpacity <= 0.005) return;

    final r = CelestialOrbitGeometry.orbRadius * pose.scale;
    final center = pose.center;

    const auraColor = Color(0xFF48C9B0);
    const rimColor = Color(0xFFE2E8F0);
    const faceLight = Color(0xFFFFFFFF);
    const faceShadow = Color(0xFF94A3B8);

    final haloPaint = Paint()
      ..shader = ui.Gradient.radial(
        center,
        r * 2.2,
        [
          auraColor.withValues(alpha: 0.34 * effectiveOpacity),
          rimColor.withValues(alpha: 0.14 * effectiveOpacity),
          auraColor.withValues(alpha: 0.0),
        ],
        const [0.22, 0.60, 1.0],
      );
    canvas.drawCircle(center, r * 2.2, haloPaint);

    if (drawTravelRipples) {
      _paintExpandingCircleRipples(
        canvas: canvas,
        center: center,
        baseRadius: r,
        progress: pose.rippleProgress,
        color: auraColor,
        opacity: effectiveOpacity,
      );
    }

    canvas.drawCircle(
      center,
      r,
      Paint()..color = auraColor.withValues(alpha: 0.10 * effectiveOpacity),
    );

    final outerCircle = Path()
      ..addOval(Rect.fromCircle(center: center, radius: r));
    final cutoutCircle = Path()
      ..addOval(
        Rect.fromCircle(
          center: center + Offset(r * 0.42, -r * 0.24),
          radius: r * 0.86,
        ),
      );
    final crescentPath = Path.combine(
      PathOperation.difference,
      outerCircle,
      cutoutCircle,
    );

    final crescentPaint = Paint()
      ..shader = ui.Gradient.linear(
        center - Offset(r, r),
        center + Offset(r, r),
        [
          faceLight.withValues(alpha: effectiveOpacity),
          rimColor.withValues(alpha: effectiveOpacity),
          faceShadow.withValues(alpha: effectiveOpacity),
        ],
        const [0.0, 0.55, 1.0],
      );
    canvas.drawPath(crescentPath, crescentPaint);

    final twinkle = 0.65 + 0.35 * math.sin(phase * 4 * math.pi);
    _paintFourPointStar(
      canvas: canvas,
      center: center + Offset(r * 0.36, -r * 0.22),
      radius: (r * 0.22).clamp(2.5, 6.0),
      color: faceLight.withValues(alpha: effectiveOpacity * twinkle),
    );
  }

  static void _paintExpandingCircleRipples({
    required Canvas canvas,
    required Offset center,
    required double baseRadius,
    required double progress,
    required Color color,
    required double opacity,
  }) {
    for (var i = 0; i < 2; i++) {
      final p = (progress + i * 0.35) % 1.0;
      final ringRadius = baseRadius * (1.1 + p * 1.65);
      final ringAlpha = (1.0 - p) * 0.55 * opacity;
      if (ringAlpha <= 0.01) continue;
      canvas.drawCircle(
        center,
        ringRadius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0
          ..color = color.withValues(alpha: ringAlpha),
      );
    }
  }
}

void _paintStarfield(
  Canvas canvas,
  Rect bounds, {
  required double opacity,
  required double phase,
  required Color tint,
}) {
  if (opacity <= 0.01) return;

  const starPositions = <Offset>[
    Offset(0.12, 0.09),
    Offset(0.24, 0.16),
    Offset(0.37, 0.07),
    Offset(0.64, 0.08),
    Offset(0.76, 0.15),
    Offset(0.88, 0.11),
    Offset(0.18, 0.28),
    Offset(0.82, 0.27),
    Offset(0.45, 0.19),
    Offset(0.56, 0.22),
  ];

  for (var i = 0; i < starPositions.length; i++) {
    final norm = starPositions[i];
    final pos = Offset(
      bounds.left + bounds.width * norm.dx,
      bounds.top + bounds.height * norm.dy,
    );
    final twinkle =
        0.35 + 0.65 * (0.5 + 0.5 * math.sin(phase * 2 * math.pi + i * 1.3));
    final starOpacity = (opacity * twinkle).clamp(0.0, 1.0);
    if (i.isEven) {
      _paintFourPointStar(
        canvas: canvas,
        center: pos,
        radius: 3.5 + (i % 3) * 1.1,
        color: tint.withValues(alpha: starOpacity),
      );
    } else {
      canvas.drawCircle(
        pos,
        1.6 + (i % 2) * 0.8,
        Paint()..color = tint.withValues(alpha: starOpacity),
      );
    }
  }
}

void _paintFourPointStar({
  required Canvas canvas,
  required Offset center,
  required double radius,
  required Color color,
}) {
  final inner = radius * 0.30;
  final path = Path()
    ..moveTo(center.dx, center.dy - radius)
    ..lineTo(center.dx + inner, center.dy - inner)
    ..lineTo(center.dx + radius, center.dy)
    ..lineTo(center.dx + inner, center.dy + inner)
    ..lineTo(center.dx, center.dy + radius)
    ..lineTo(center.dx - inner, center.dy + inner)
    ..lineTo(center.dx - radius, center.dy)
    ..lineTo(center.dx - inner, center.dy - inner)
    ..close();
  canvas.drawPath(path, Paint()..color = color);
}
