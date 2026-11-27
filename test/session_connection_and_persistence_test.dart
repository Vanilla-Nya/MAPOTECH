import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapotech/features/dashboard/dashboard_shell.dart';
import 'package:mapotech/features/landing/landing_page_data.dart';
import 'package:mapotech/features/landing/landing_page_layout.dart';
import 'package:mapotech/shared/session_connection_service.dart';
import 'package:mapotech/shared/web_helpers.dart';
import 'package:mapotech/shared/widgets/session_connection_banner.dart';

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

  group('LandingPageNotifier session persistence', () {
    test(
      'persists sanitized login session and active menu across notifier restarts',
      () {
        final container1 = ProviderContainer();
        addTearDown(container1.dispose);

        final notifier1 = container1.read(landingPageProvider.notifier);
        expect(container1.read(landingPageProvider).isLoggedIn, isFalse);

        notifier1.login(
          'pasien',
          user: {
            'id': 'mock-user-42',
            'name': 'Alvin Tester',
            'email': 'alvin@mapotech.id',
            'role': 'pasien',
            'password': r'$2a$10$secret_bcrypt_hash_should_not_persist',
          },
          language: 'en',
        );
        notifier1.setDashboardMenu('settings');

        final rawStored = WebStorageHelper.getItem(
          LandingPageNotifier.sessionStorageKey,
        );
        expect(rawStored, isNotNull);
        expect(rawStored, isNot(contains('secret_bcrypt_hash')));

        final decoded = jsonDecode(rawStored!) as Map<String, dynamic>;
        expect(decoded['isLoggedIn'], isTrue);
        expect(decoded['loggedInRole'], 'pasien');
        expect(decoded['activeDashboardMenu'], 'settings');
        expect(
          (decoded['loggedInUser'] as Map<String, dynamic>).containsKey(
            'password',
          ),
          isFalse,
        );

        // Simulate a fresh app/browser reload reading from persistent storage.
        final container2 = ProviderContainer();
        addTearDown(container2.dispose);
        final restored = container2.read(landingPageProvider);

        expect(restored.isLoggedIn, isTrue);
        expect(restored.loggedInRole, 'pasien');
        expect(restored.loggedInName, 'Alvin Tester');
        expect(restored.language, 'en');
        expect(restored.activeDashboardMenu, 'settings');
        expect(restored.loggedInUser?['id'], 'mock-user-42');
        expect(restored.loggedInUser?.containsKey('password'), isFalse);
      },
    );

    test('logout clears stored session and resets state cleanly', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(landingPageProvider.notifier);

      notifier.login(
        'pasien',
        user: {
          'id': 'mock-user-99',
          'name': 'User Logout',
          'role': 'pasien',
        },
      );
      notifier.setDashboardMenu('history');
      expect(
        WebStorageHelper.getItem(LandingPageNotifier.sessionStorageKey),
        isNotNull,
      );

      notifier.logout();
      final state = container.read(landingPageProvider);
      expect(state.isLoggedIn, isFalse);
      expect(state.loggedInRole, isNull);
      expect(state.loggedInName, isNull);
      expect(state.loggedInUser, isNull);
      expect(state.activeDashboardMenu, 'dashboard');
      expect(
        WebStorageHelper.getItem(LandingPageNotifier.sessionStorageKey),
        isNull,
      );
    });

    test('handles corrupted stored session JSON gracefully', () {
      WebStorageHelper.setItem(
        LandingPageNotifier.sessionStorageKey,
        '{not-valid-json',
      );
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(landingPageProvider);
      expect(state.isLoggedIn, isFalse);
      expect(
        WebStorageHelper.getItem(LandingPageNotifier.sessionStorageKey),
        isNull,
      );
    });
  });

  group('SessionConnectionNotifier', () {
    test(
      'detects disconnect via platform events & probe and reconnects cleanly',
      () async {
        bool serverReachable = true;
        bool platformOnline = true;
        final onlineCtrl = StreamController<bool>.broadcast();
        addTearDown(onlineCtrl.close);

        final notifier = SessionConnectionNotifier(
          probeReachability: () async => serverReachable,
          isPlatformOnline: () => platformOnline,
          onlineStream: onlineCtrl.stream,
          connectedCheckInterval: const Duration(minutes: 5),
          disconnectedRetryInterval: const Duration(minutes: 5),
        );
        addTearDown(notifier.dispose);

        notifier.setMonitoringActive(true);
        await Future<void>.delayed(Duration.zero);
        expect(notifier.state.isConnected, isTrue);
        expect(notifier.state.disconnectCount, 0);

        // Simulate platform going offline.
        platformOnline = false;
        onlineCtrl.add(false);
        await Future<void>.delayed(Duration.zero);

        expect(notifier.state.isDisconnected, isTrue);
        expect(notifier.state.disconnectCount, 1);
        expect(notifier.state.disconnectedAt, isNotNull);

        // User dismisses banner; a failed reconnect keeps disconnectCount unchanged.
        notifier.dismissBanner();
        expect(notifier.state.isBannerDismissed, isTrue);

        final failedAttempt = await notifier.reconnect();
        expect(failedAttempt, isFalse);
        expect(notifier.state.isDisconnected, isTrue);
        expect(notifier.state.disconnectCount, 1);

        // Network returns and user clicks Reconnect.
        platformOnline = true;
        serverReachable = true;
        final reconnected = await notifier.reconnect();
        expect(reconnected, isTrue);
        expect(notifier.state.isConnected, isTrue);
        expect(notifier.state.reconnectVersion, 1);
        expect(notifier.state.disconnectedAt, isNull);
        expect(notifier.state.isBannerDismissed, isFalse);
      },
    );
  });

  group('Post-login disconnect & reconnect UI integration', () {
    testWidgets(
      'restored session opens DashboardShell directly, shows disconnect notification, and reconnects without logging in again',
      (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        // Seed a persisted logged-in patient session on the 'settings' menu.
        final seedContainer = ProviderContainer();
        seedContainer.read(landingPageProvider.notifier).login(
          'pasien',
          user: {
            'id': 'mock-patient-1',
            'name': 'Alvin',
            'email': 'alvin@mapotech.id',
            'role': 'pasien',
          },
          language: 'en',
        );
        seedContainer
            .read(landingPageProvider.notifier)
            .setDashboardMenu('settings');
        seedContainer.dispose();

        bool isOnline = true;
        final onlineCtrl = StreamController<bool>.broadcast();
        addTearDown(onlineCtrl.close);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sessionConnectionProvider.overrideWith((ref) {
                final notifier = SessionConnectionNotifier(
                  probeReachability: () async => isOnline,
                  isPlatformOnline: () => isOnline,
                  onlineStream: onlineCtrl.stream,
                  connectedCheckInterval: const Duration(minutes: 5),
                  disconnectedRetryInterval: const Duration(minutes: 5),
                );
                notifier.setMonitoringActive(
                  ref.read(landingPageProvider).isLoggedIn,
                );
                ref.listen<bool>(
                  landingPageProvider.select((s) => s.isLoggedIn),
                  (_, next) => notifier.setMonitoringActive(next),
                );
                return notifier;
              }),
            ],
            child: const MaterialApp(home: LandingPageLayout()),
          ),
        );
        await tester.pumpAndSettle();

        // Restored session skips login screen and opens DashboardShell on SETTINGS.
        expect(find.byType(DashboardShell), findsOneWidget);
        expect(find.text('SETTINGS'), findsOneWidget);
        expect(find.byType(SessionConnectionBanner), findsNothing);

        // Drop connection after login.
        isOnline = false;
        onlineCtrl.add(false);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump(const Duration(milliseconds: 300));

        // Notification toast + persistent banner + reconnect action appear, user stays logged in!
        expect(find.byType(DashboardShell), findsOneWidget);
        expect(find.byType(SessionConnectionBanner), findsOneWidget);
        expect(find.text('You Are Disconnected'), findsOneWidget);
        expect(find.text('You are disconnected'), findsOneWidget);
        expect(find.text('Reconnect'), findsWidgets);
        expect(find.text('SETTINGS'), findsOneWidget);

        // Tap Reconnect while still offline -> shows "Still Disconnected", stays logged in.
        await tester.tap(
          find.descendant(
            of: find.byType(SessionConnectionBanner),
            matching: find.text('Reconnect'),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Still Disconnected'), findsOneWidget);
        expect(find.byType(SessionConnectionBanner), findsOneWidget);
        expect(find.byType(DashboardShell), findsOneWidget);

        // Restore connection and tap Reconnect -> banner disappears, success notice shown, still on SETTINGS!
        isOnline = true;
        await tester.tap(
          find.descendant(
            of: find.byType(SessionConnectionBanner),
            matching: find.text('Reconnect'),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump(const Duration(milliseconds: 350));

        expect(find.text('Reconnected'), findsOneWidget);
        expect(find.byType(SessionConnectionBanner), findsNothing);
        expect(find.byType(DashboardShell), findsOneWidget);
        expect(find.text('SETTINGS'), findsOneWidget);
      },
    );

    testWidgets(
      'default sessionConnectionProvider starts with disconnect notification visible first for UI inspection and reconnects on tap',
      (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final seedContainer = ProviderContainer();
        seedContainer.read(landingPageProvider.notifier).login(
          'pasien',
          user: {
            'id': 'mock-patient-preview',
            'name': 'Alvin',
            'email': 'alvin@mapotech.id',
            'role': 'pasien',
          },
          language: 'en',
        );
        seedContainer
            .read(landingPageProvider.notifier)
            .setDashboardMenu('settings');
        seedContainer.dispose();

        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(home: LandingPageLayout()),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(DashboardShell), findsOneWidget);
        expect(find.byType(SessionConnectionBanner), findsOneWidget);
        expect(find.text('You Are Disconnected'), findsOneWidget);
        expect(find.text('You are disconnected'), findsOneWidget);
        expect(find.text('Disconnected • Reconnect'), findsOneWidget);
      },
    );
  });
}
