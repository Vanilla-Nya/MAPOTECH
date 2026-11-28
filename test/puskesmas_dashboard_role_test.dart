import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapotech/features/landing/landing_page_data.dart';
import 'package:mapotech/features/puskesmas/dashboard/frontend/puskesmas_dashboard.dart';
import 'package:mapotech/features/puskesmas/dashboard/frontend/puskesmas_owner_dashboard.dart';
import 'package:mapotech/features/puskesmas/dashboard/frontend/puskesmas_pekerja_dashboard.dart';
import 'package:mapotech/shared/web_helpers.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    WebStorageHelper.removeItem(LandingPageNotifier.sessionStorageKey);
  });

  tearDown(() {
    WebStorageHelper.removeItem(LandingPageNotifier.sessionStorageKey);
  });

  group('PuskesmasDashboard role-based view without tabbed pane', () {
    testWidgets('shows PuskesmasOwnerDashboard directly for puskesmas owner without owner/worker tabs', (
      WidgetTester tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(landingPageProvider.notifier).login(
        'puskesmas',
        user: {
          'id': 'mock-puskesmas-owner',
          'name': 'Puskesmas Sumber Wringin',
          'role': 'puskesmas',
        },
        language: 'en',
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(child: PuskesmasDashboard()),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.textContaining('OWNER DASHBOARD'), findsNothing);
      expect(find.textContaining('WORKER DASHBOARD'), findsNothing);
      expect(find.textContaining('DASHBOARD OWNER'), findsNothing);
      expect(find.textContaining('DASHBOARD PEKERJA'), findsNothing);
      expect(find.byType(PuskesmasOwnerDashboard), findsOneWidget);
      expect(find.byType(PuskesmasPekerjaDashboard), findsNothing);
      expect(find.text('PUSKESMAS • OWNER / PEMILIK'), findsOneWidget);
    });

    testWidgets('shows PuskesmasPekerjaDashboard directly for worker role without owner/worker tabs', (
      WidgetTester tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1280, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(landingPageProvider.notifier).login(
        'puskesmas',
        user: {
          'id': 'mock-puskesmas-worker',
          'owner_id': 'mock-puskesmas-owner',
          'name': 'Budi Staf',
          'role': 'pekerja_puskesmas',
        },
        language: 'en',
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(child: PuskesmasDashboard()),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.textContaining('OWNER DASHBOARD'), findsNothing);
      expect(find.textContaining('WORKER DASHBOARD'), findsNothing);
      expect(find.byType(PuskesmasPekerjaDashboard), findsOneWidget);
      expect(find.byType(PuskesmasOwnerDashboard), findsNothing);
      expect(find.text('PUSKESMAS • PEKERJA / STAF'), findsOneWidget);
    });
  });
}
