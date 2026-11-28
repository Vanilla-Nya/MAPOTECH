import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapotech/features/landing/landing_page_data.dart';
import 'package:mapotech/shared/widgets/celestial_theme_transition.dart';
import 'package:mapotech/shared/widgets/floating_settings.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('CelestialOrbitGeometry', () {
    const skyBounds = Rect.fromLTWH(0, 0, 1200, 800);
    const viewportSize = Size(1200, 800);

    test('classifies circularDayNight, galaxyAscend, and galaxyDescend properly', () {
      expect(
        CelestialOrbitGeometry.transitionKind(
          fromAppearance: 'light',
          toAppearance: 'dark',
        ),
        CelestialTransitionKind.circularDayNight,
      );
      expect(
        CelestialOrbitGeometry.transitionKind(
          fromAppearance: 'dark',
          toAppearance: 'light',
        ),
        CelestialTransitionKind.circularDayNight,
      );
      expect(
        CelestialOrbitGeometry.transitionKind(
          fromAppearance: 'light',
          toAppearance: 'rev',
        ),
        CelestialTransitionKind.galaxyAscend,
      );
      expect(
        CelestialOrbitGeometry.transitionKind(
          fromAppearance: 'dark',
          toAppearance: 'rev',
        ),
        CelestialTransitionKind.galaxyAscend,
      );
      expect(
        CelestialOrbitGeometry.transitionKind(
          fromAppearance: 'rev',
          toAppearance: 'light',
        ),
        CelestialTransitionKind.galaxyDescend,
      );
      expect(
        CelestialOrbitGeometry.transitionKind(
          fromAppearance: 'rev',
          toAppearance: 'dark',
        ),
        CelestialTransitionKind.galaxyDescend,
      );
    });

    test('light -> dark moves Sun from middle down-left, Moon from bottom-right to middle-top, then disappears by end', () {
      final start = CelestialOrbitGeometry.transitionPoses(
        fromAppearance: 'light',
        toAppearance: 'dark',
        progress: 0.0,
        skyBounds: skyBounds,
        viewportSize: viewportSize,
      );
      expect(start.sun, isNotNull);
      expect(start.sun!.center.dx, closeTo(600, 0.001));

      final midOrbit = CelestialOrbitGeometry.transitionPoses(
        fromAppearance: 'light',
        toAppearance: 'dark',
        progress: CelestialOrbitGeometry.arrivalProgress * 0.5,
        skyBounds: skyBounds,
        viewportSize: viewportSize,
      );
      expect(midOrbit.sun, isNotNull);
      expect(midOrbit.moon, isNotNull);

      final topMid = CelestialOrbitGeometry.centerTop(skyBounds);
      final botLeft = CelestialOrbitGeometry.bottomLeftExit(skyBounds, viewportSize);
      final botRight = CelestialOrbitGeometry.bottomRightEntry(skyBounds, viewportSize);
      final pivot = CelestialOrbitGeometry.discPivot(skyBounds, viewportSize);

      expect(pivot, const Offset(600, 800));
      expect(midOrbit.sun!.center.dx, lessThan(topMid.dx));
      expect(midOrbit.sun!.center.dy, greaterThan(topMid.dy));
      final straightSunMid = Offset.lerp(topMid, botLeft, 0.5)!;
      expect((midOrbit.sun!.center - straightSunMid).distance, greaterThan(20.0));

      expect(midOrbit.moon!.center.dx, greaterThan(topMid.dx));
      expect(midOrbit.moon!.center.dy, lessThan(botRight.dy));
      final straightMoonMid = Offset.lerp(botRight, topMid, 0.5)!;
      expect((midOrbit.moon!.center - straightMoonMid).distance, greaterThan(20.0));

      // Outgoing Sun stays strictly on the left/day half while incoming Moon stays on right/night half.
      expect(midOrbit.sun!.center.dx, lessThan(pivot.dx));
      expect(midOrbit.moon!.center.dx, greaterThan(pivot.dx));

      final hold = CelestialOrbitGeometry.transitionPoses(
        fromAppearance: 'light',
        toAppearance: 'dark',
        progress: 0.65,
        skyBounds: skyBounds,
        viewportSize: viewportSize,
      );
      expect(hold.sun, isNull);
      expect(hold.moon, isNotNull);
      expect(hold.moon!.opacity, closeTo(1.0, 0.001));
      expect(hold.moon!.center.dx, closeTo(600, 0.001));
      expect(hold.moon!.center.dy, closeTo(topMid.dy, 0.001));

      final end = CelestialOrbitGeometry.transitionPoses(
        fromAppearance: 'light',
        toAppearance: 'dark',
        progress: 1.0,
        skyBounds: skyBounds,
        viewportSize: viewportSize,
      );
      expect(end.sun, isNull);
      expect(end.moon, isNull);
    });

    test('dark -> light moves Moon from middle down-left, Sun from bottom-right to middle-top, then disappears', () {
      final midOrbit = CelestialOrbitGeometry.transitionPoses(
        fromAppearance: 'dark',
        toAppearance: 'light',
        progress: CelestialOrbitGeometry.arrivalProgress * 0.5,
        skyBounds: skyBounds,
        viewportSize: viewportSize,
      );
      final topMid = CelestialOrbitGeometry.centerTop(skyBounds);
      expect(midOrbit.moon!.center.dx, lessThan(topMid.dx));
      expect(midOrbit.moon!.center.dy, greaterThan(topMid.dy));
      expect(midOrbit.sun!.center.dx, greaterThan(topMid.dx));

      final hold = CelestialOrbitGeometry.transitionPoses(
        fromAppearance: 'dark',
        toAppearance: 'light',
        progress: 0.65,
        skyBounds: skyBounds,
        viewportSize: viewportSize,
      );
      expect(hold.moon, isNull);
      expect(hold.sun, isNotNull);
      expect(hold.sun!.opacity, closeTo(1.0, 0.001));
      expect(hold.sun!.center.dx, closeTo(600, 0.001));

      final end = CelestialOrbitGeometry.transitionPoses(
        fromAppearance: 'dark',
        toAppearance: 'light',
        progress: 1.0,
        skyBounds: skyBounds,
        viewportSize: viewportSize,
      );
      expect(end.sun, isNull);
      expect(end.moon, isNull);
    });

    test('ascend to Relva (rev) leaves previous Sun/Moon behind near bottom Earth horizon while rising ♪ logo, then fades out', () {
      final topMid = CelestialOrbitGeometry.centerTop(skyBounds);
      final bottomTarget = CelestialOrbitGeometry.leftBehindBottomTarget(skyBounds);

      final sunHold = CelestialOrbitGeometry.transitionPoses(
        fromAppearance: 'light',
        toAppearance: 'rev',
        progress: 0.65,
        skyBounds: skyBounds,
        viewportSize: viewportSize,
      );
      expect(sunHold.sun, isNotNull);
      expect(sunHold.moon, isNull);
      expect(sunHold.sun!.center.dy, greaterThan(topMid.dy));
      expect(sunHold.sun!.center.dy, closeTo(bottomTarget.dy, 0.001));
      expect(sunHold.sun!.opacity, closeTo(1.0, 0.001));

      final moonHold = CelestialOrbitGeometry.transitionPoses(
        fromAppearance: 'dark',
        toAppearance: 'rev',
        progress: 0.65,
        skyBounds: skyBounds,
        viewportSize: viewportSize,
      );
      expect(moonHold.moon, isNotNull);
      expect(moonHold.sun, isNull);
      expect(moonHold.moon!.center.dy, greaterThan(topMid.dy));
      expect(moonHold.moon!.center.dy, closeTo(bottomTarget.dy, 0.001));
      expect(moonHold.moon!.opacity, closeTo(1.0, 0.001));

      final logoEarly = CelestialOrbitGeometry.galaxyLogoPose(
        fromAppearance: 'light',
        toAppearance: 'rev',
        progress: 0.25,
        skyBounds: skyBounds,
      );
      final logoHold = CelestialOrbitGeometry.galaxyLogoPose(
        fromAppearance: 'light',
        toAppearance: 'rev',
        progress: 0.65,
        skyBounds: skyBounds,
      );
      final logoEnd = CelestialOrbitGeometry.galaxyLogoPose(
        fromAppearance: 'light',
        toAppearance: 'rev',
        progress: 1.0,
        skyBounds: skyBounds,
      );

      expect(logoEarly, isNotNull);
      expect(logoHold, isNotNull);
      expect(logoHold!.opacity, closeTo(1.0, 0.001));
      expect(logoEarly!.center.dy, greaterThan(logoHold.center.dy));
      expect(logoEnd, isNull);

      // Earth horizon visibly sinks lower as altitude climbs from Earth to space.
      final earthStartY = CelestialOrbitGeometry.earthHorizonPeakY(skyBounds, 0.0);
      final earthSpaceY = CelestialOrbitGeometry.earthHorizonPeakY(skyBounds, 0.65);
      expect(earthSpaceY, greaterThan(earthStartY));

      final end = CelestialOrbitGeometry.transitionPoses(
        fromAppearance: 'light',
        toAppearance: 'rev',
        progress: 1.0,
        skyBounds: skyBounds,
        viewportSize: viewportSize,
      );
      expect(end.sun, isNull);
      expect(end.moon, isNull);
    });

    test('descend from Relva (rev) -> light/dark recedes ♪ upward out of space and keeps Sun or Moon already at top-middle, then fades out', () {
      final topMid = CelestialOrbitGeometry.centerTop(skyBounds);

      final logoStart = CelestialOrbitGeometry.galaxyLogoPose(
        fromAppearance: 'rev',
        toAppearance: 'light',
        progress: 0.0,
        skyBounds: skyBounds,
      );
      final logoReceding = CelestialOrbitGeometry.galaxyLogoPose(
        fromAppearance: 'rev',
        toAppearance: 'light',
        progress: 0.18,
        skyBounds: skyBounds,
      );
      expect(logoStart, isNotNull);
      expect(logoReceding, isNotNull);
      expect(logoReceding!.center.dy, lessThan(logoStart!.center.dy));
      expect(logoReceding.opacity, lessThan(logoStart.opacity));

      final toLightEarly = CelestialOrbitGeometry.transitionPoses(
        fromAppearance: 'rev',
        toAppearance: 'light',
        progress: 0.20,
        skyBounds: skyBounds,
        viewportSize: viewportSize,
      );
      expect(toLightEarly.sun, isNotNull);
      expect(toLightEarly.moon, isNull);
      expect(toLightEarly.sun!.center, topMid);
      expect(toLightEarly.sun!.opacity, closeTo(1.0, 0.001));

      final toLightEnd = CelestialOrbitGeometry.transitionPoses(
        fromAppearance: 'rev',
        toAppearance: 'light',
        progress: 1.0,
        skyBounds: skyBounds,
        viewportSize: viewportSize,
      );
      expect(toLightEnd.sun, isNull);

      final toDarkEarly = CelestialOrbitGeometry.transitionPoses(
        fromAppearance: 'rev',
        toAppearance: 'dark',
        progress: 0.20,
        skyBounds: skyBounds,
        viewportSize: viewportSize,
      );
      expect(toDarkEarly.moon, isNotNull);
      expect(toDarkEarly.sun, isNull);
      expect(toDarkEarly.moon!.center, topMid);
      expect(toDarkEarly.moon!.opacity, closeTo(1.0, 0.001));

      final toDarkEnd = CelestialOrbitGeometry.transitionPoses(
        fromAppearance: 'rev',
        toAppearance: 'dark',
        progress: 1.0,
        skyBounds: skyBounds,
        viewportSize: viewportSize,
      );
      expect(toDarkEnd.moon, isNull);
    });
  });

  group('CelestialThemeTransitionHost widget integration', () {
    testWidgets('switches light -> dark -> rev (circular + space ascent) -> light (circular + descent), auto-hides after ~2s, and handles rapid switches', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1024, 768));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          child: Consumer(
            builder: (context, ref, _) {
              final state = ref.watch(landingPageProvider);
              return MaterialApp(
                themeAnimationDuration: Duration.zero,
                builder: (context, child) {
                  return CelestialThemeTransitionHost(
                    appearance: state.appearance,
                    child: child ?? const SizedBox.shrink(),
                  );
                },
                home: Scaffold(
                  body: Stack(
                    children: [
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CelestialSkyBackdrop(
                            appearance: state.appearance,
                          ),
                        ),
                      ),
                      const FloatingSettings(),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pump();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(FloatingSettings)),
      );
      expect(container.read(landingPageProvider).appearance, 'light');
      expect(CelestialThemeCoordinator.instance.isTransitioning.value, isFalse);

      // Open floating settings menu.
      await tester.tap(find.byIcon(Icons.settings_rounded));
      await tester.pump(const Duration(milliseconds: 400));

      // 1. Light -> Dark (circular reveal).
      await tester.tap(find.byIcon(Icons.nightlight_round));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(container.read(landingPageProvider).appearance, 'dark');
      expect(CelestialThemeCoordinator.instance.isTransitioning.value, isTrue);

      await tester.pump(const Duration(milliseconds: 1300));
      expect(CelestialThemeCoordinator.instance.isTransitioning.value, isTrue);

      await tester.pump(const Duration(milliseconds: 800));
      expect(CelestialThemeCoordinator.instance.isTransitioning.value, isFalse);

      // 2. Dark -> REV (vertical goes-up reveal with frosted BackdropFilter blur until standby).
      await tester.tap(find.byIcon(Icons.palette_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));
      expect(container.read(landingPageProvider).appearance, 'rev');
      expect(CelestialThemeCoordinator.instance.isTransitioning.value, isTrue);
      expect(find.byType(BackdropFilter), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 1750));
      expect(CelestialThemeCoordinator.instance.isTransitioning.value, isFalse);
      expect(find.byType(BackdropFilter), findsNothing);

      // 3. REV -> Light (vertical descent, Sun + drifting daylight clouds) through completion.
      await tester.tap(find.byIcon(Icons.sunny));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(container.read(landingPageProvider).appearance, 'light');
      expect(CelestialThemeCoordinator.instance.isTransitioning.value, isTrue);

      await tester.pump(const Duration(milliseconds: 1700));
      expect(CelestialThemeCoordinator.instance.isTransitioning.value, isFalse);

      // 4. Light -> Dark interrupted mid-flight back to Light (tests Dark -> Light clouds + rapid switch).
      await tester.tap(find.byIcon(Icons.nightlight_round));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 450));
      expect(container.read(landingPageProvider).appearance, 'dark');
      expect(CelestialThemeCoordinator.instance.isTransitioning.value, isTrue);

      await tester.tap(find.byIcon(Icons.sunny));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 550));
      expect(container.read(landingPageProvider).appearance, 'light');
      expect(CelestialThemeCoordinator.instance.isTransitioning.value, isTrue);

      await tester.pump(const Duration(milliseconds: 1650));
      expect(CelestialThemeCoordinator.instance.isTransitioning.value, isFalse);
    });
  });
}
