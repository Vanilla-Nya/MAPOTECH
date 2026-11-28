import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapotech/features/landing/landing_page_data.dart';
import 'package:mapotech/features/pasien/dashboard/frontend/pasien_children.dart';
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

  PasienFamilyDirectory buildSampleDirectory() {
    final userCheckup = FamilyCheckupRecord(
      id: 'enc-user-1',
      queueId: 'q-user-1',
      source: 'doctor',
      checkupDate: DateTime(2026, 6, 3),
      timeLabel: '09:30 WIB',
      queueNumber: 'A-003',
      examinerName: 'dr. Agoes Soetanto',
      facilityName: 'Dokter Praktek Mandiri dr. Agoes Soetanto',
      mainComplaint: 'Pusing dan lemas ringan',
      anamnesis: 'Riwayat kurang tidur 3 hari terakhir',
      medicationTherapy: 'Istirahat cukup & vitamin B kompleks',
      prognosis: 'Baik',
      vitals: const {
        'blood_pressure': '119/79',
        'body_temperature': '36',
        'heart_rate': '100',
        'oxygen_saturation': '100',
        'respiratory_rate': '20',
        'body_weight': '66',
        'body_height': '163',
      },
      diagnoses: const [
        {'code': 'R51', 'description': 'Headache'},
      ],
    );

    final childLatest = FamilyCheckupRecord(
      id: 'enc-child-2',
      queueId: 'q-child-2',
      source: 'doctor',
      checkupDate: DateTime(2026, 6, 18),
      timeLabel: '19:15 WIB',
      queueNumber: 'A-001',
      examinerName: 'dr. Agoes Soetanto',
      facilityName: 'Dokter Praktek Mandiri dr. Agoes Soetanto',
      mainComplaint: 'Kontrol rutin kesehatan',
      anamnesis: 'Kondisi stabil, nafsu makan baik',
      vitals: const {
        'blood_pressure': '119/79',
        'body_temperature': '36',
        'heart_rate': '92',
        'oxygen_saturation': '99',
        'body_weight': '72',
        'body_height': '172',
      },
      diagnoses: const [
        {'code': 'Z00.0', 'description': 'General medical examination'},
      ],
    );

    final childPrevious = FamilyCheckupRecord(
      id: 'enc-child-1',
      queueId: 'q-child-1',
      source: 'doctor',
      checkupDate: DateTime(2026, 5, 23),
      timeLabel: '10:00 WIB',
      queueNumber: 'A-002',
      examinerName: 'dr. Agoes Soetanto',
      facilityName: 'Dokter Praktek Mandiri dr. Agoes Soetanto',
      mainComplaint: 'Sakit perut, lehernya tegang',
      anamnesis: 'Asma ringan',
      vitals: const {
        'blood_pressure': '124/83',
        'body_temperature': '36.5',
        'heart_rate': '67',
        'oxygen_saturation': '98',
        'body_weight': '83',
        'body_height': '172',
      },
      diagnoses: const [
        {'code': 'K29.7', 'description': 'Gastritis, tidak spesifik'},
      ],
      rujukan: const {
        'rumah_sakit': 'RSUD dr. H. Koesnadi',
        'poli': 'Poli Penyakit Dalam',
        'nomor': 'REF/2026/05/0001',
        'catatan': 'Evaluasi lanjutan',
      },
    );

    final currentUser = PasienChildModel(
      isSelf: true,
      familyMember: {
        'id': 'user-alfon',
        'nama': 'Alfon Soetanto',
        'nik': '3511111307050005',
        'hubungan': 'Kepala Keluarga (Ayah)',
        'gender': 'Laki-laki',
        'birth_date': '2005-07-13',
        'birth_place': 'Bondowoso',
        'address': 'Kel. Kejayan, Kec. Pujer, Bondowoso',
        'no_kk': '3511081208009999',
        // Deliberately present in map to prove UI ignores BPJS & Gol. Darah
        'gol_darah': 'O+',
        'no_bpjs': '000999888777',
      },
      checkups: [userCheckup],
      lastCheckup: userCheckup,
    );

    final memberAlvin = PasienChildModel(
      isSelf: false,
      familyMember: {
        'id': 'fam-alvin',
        'member_user_id': 'user-alvin',
        'nama': 'Alvin',
        'nik': '3511081208000003',
        'hubungan': 'Anak',
        'gender': 'Laki-laki',
        'birth_date': '2000-08-12',
        'birth_place': 'Surabaya',
        'phone_number': '08121638225',
        'address': 'Kel. Kejayan, Kec. Pujer, Bondowoso',
        'no_kk': '3511081208009999',
        'gol_darah': 'AB+',
        'no_bpjs': '0001234567894',
      },
      checkups: [childLatest, childPrevious],
      lastCheckup: childLatest,
    );

    return PasienFamilyDirectory(
      currentUser: currentUser,
      familyMembers: [memberAlvin],
      noKk: '3511081208009999',
      isKepalaKeluarga: true,
    );
  }

  Widget buildTestHarness(
    ProviderContainer container,
    PasienFamilyDirectory directory,
  ) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: PasienChildren(
              directoryLoader: (_) async => directory,
              medicinesLoader: (encounterId) async {
                if (encounterId == 'enc-user-1') {
                  return const [
                    {
                      'name': 'Paracetamol 500mg',
                      'quantity': 10,
                      'rules': '3 x 1 Sesudah Makan',
                    },
                  ];
                }
                return const [
                  {
                    'name': 'Antasida Doen',
                    'quantity': 10,
                    'rules': '3 x 1 Sebelum Makan',
                  },
                ];
              },
            ),
          ),
        ),
      ),
    );
  }

  group('My Family page and tabbed modal', () {
    testWidgets(
      'renders user detail at top, family cards below, without BPJS or blood type',
      (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final container = ProviderContainer();
        addTearDown(container.dispose);
        container.read(landingPageProvider.notifier).login(
          'pasien',
          user: {
            'id': 'mock-user-alfon',
            'name': 'Alfon Soetanto',
            'nik': '3511111307050005',
            'no_kk': '3511081208009999',
          },
          language: 'en',
        );

        final directory = buildSampleDirectory();
        await tester.pumpWidget(buildTestHarness(container, directory));
        await tester.pumpAndSettle();

        expect(find.text('MY PROFILE (USER DETAIL)'), findsOneWidget);
        expect(find.text('Alfon Soetanto'), findsOneWidget);
        expect(find.text('FAMILY MEMBERS (1)'), findsOneWidget);
        expect(find.text('Alvin'), findsOneWidget);

        // User detail card appears above family member cards
        final alfonTop = tester.getTopLeft(find.text('Alfon Soetanto')).dy;
        final alvinTop = tester.getTopLeft(find.text('Alvin')).dy;
        expect(alfonTop, lessThan(alvinTop));

        // BPJS and Golongan Darah must NOT appear anywhere
        expect(find.textContaining('BPJS'), findsNothing);
        expect(find.textContaining('Gol.'), findsNothing);
        expect(find.textContaining('Golongan Darah'), findsNothing);
        expect(find.textContaining('000999888777'), findsNothing);
        expect(find.textContaining('0001234567894'), findsNothing);
      },
    );

    testWidgets(
      'clicking user card opens tabbed modal and checks examination detail in the same modal',
      (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final container = ProviderContainer();
        addTearDown(container.dispose);
        container.read(landingPageProvider.notifier).login(
          'pasien',
          user: {
            'id': 'mock-user-alfon',
            'name': 'Alfon Soetanto',
            'nik': '3511111307050005',
            'no_kk': '3511081208009999',
          },
          language: 'en',
        );

        await tester.pumpWidget(
          buildTestHarness(container, buildSampleDirectory()),
        );
        await tester.pumpAndSettle();

        // Click the user detail card
        await tester.tap(find.text('Alfon Soetanto'));
        await tester.pumpAndSettle();

        // Single modal open with tabbed pane
        final modalFinder = find.byType(Dialog);
        expect(modalFinder, findsOneWidget);
        expect(
          find.descendant(of: modalFinder, matching: find.text('Profile Detail')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: modalFinder, matching: find.text('Last Checkup')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: modalFinder, matching: find.text('DOMICILE ADDRESS')),
          findsOneWidget,
        );
        expect(find.textContaining('BPJS'), findsNothing);
        expect(find.textContaining('Gol.'), findsNothing);

        // Switch to Last Checkup tab inside the modal
        await tester.tap(
          find.descendant(of: modalFinder, matching: find.text('Last Checkup')),
        );
        await tester.pumpAndSettle();

        expect(modalFinder, findsOneWidget);
        expect(
          find.descendant(of: modalFinder, matching: find.text('LAST CHECKUP')),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: modalFinder,
            matching: find.text('Check Full Examination Detail'),
          ),
          findsOneWidget,
        );

        // Inspect examination detail INSIDE the same modal (no second modal!)
        final detailBtnFinder = find.descendant(
          of: modalFinder,
          matching: find.text('Check Full Examination Detail'),
        );
        await tester.ensureVisible(detailBtnFinder);
        await tester.pumpAndSettle();
        await tester.tap(detailBtnFinder);
        await tester.pumpAndSettle();

        expect(modalFinder, findsOneWidget);
        expect(
          find.descendant(of: modalFinder, matching: find.text('Back to Summary')),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: modalFinder,
            matching: find.text('EXAMINER & FACILITY'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: modalFinder,
            matching: find.text('COMPLAINT & ANAMNESIS'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: modalFinder,
            matching: find.text('Pusing dan lemas ringan'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: modalFinder,
            matching: find.text('Paracetamol 500mg'),
          ),
          findsOneWidget,
        );

        // Navigate back inside the same modal
        final backBtnFinder = find.descendant(
          of: modalFinder,
          matching: find.text('Back to Summary'),
        );
        await tester.ensureVisible(backBtnFinder);
        await tester.pumpAndSettle();
        await tester.tap(backBtnFinder);
        await tester.pumpAndSettle();
        expect(modalFinder, findsOneWidget);
        expect(
          find.descendant(
            of: modalFinder,
            matching: find.text('Check Full Examination Detail'),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'clicking family member card opens tabbed modal and checks previous checkup in same modal',
      (WidgetTester tester) async {
        await tester.binding.setSurfaceSize(const Size(1280, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final container = ProviderContainer();
        addTearDown(container.dispose);
        container.read(landingPageProvider.notifier).login(
          'pasien',
          user: {
            'id': 'mock-user-alfon',
            'name': 'Alfon Soetanto',
            'nik': '3511111307050005',
            'no_kk': '3511081208009999',
          },
          language: 'en',
        );

        await tester.pumpWidget(
          buildTestHarness(container, buildSampleDirectory()),
        );
        await tester.pumpAndSettle();

        // Click family member card
        await tester.tap(find.text('Alvin'));
        await tester.pumpAndSettle();

        final modalFinder = find.byType(Dialog);
        expect(modalFinder, findsOneWidget);
        expect(
          find.descendant(of: modalFinder, matching: find.text('Profile Detail')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: modalFinder, matching: find.text('Last Checkup')),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: modalFinder,
            matching: find.text('Surabaya, 12 August 2000'),
          ),
          findsOneWidget,
        );
        expect(find.textContaining('BPJS'), findsNothing);
        expect(find.textContaining('Gol.'), findsNothing);

        // Switch to Last Checkup tab inside the modal
        await tester.tap(
          find.descendant(of: modalFinder, matching: find.text('Last Checkup')),
        );
        await tester.pumpAndSettle();

        expect(
          find.descendant(
            of: modalFinder,
            matching: find.text('PREVIOUS CHECKUPS (1)'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: modalFinder,
            matching: find.textContaining('K29.7'),
          ),
          findsOneWidget,
        );

        // Tap the previous checkup item — opens detail in the SAME modal
        final prevFinder = find.descendant(
          of: modalFinder,
          matching: find.textContaining('K29.7'),
        );
        await tester.ensureVisible(prevFinder);
        await tester.pumpAndSettle();
        await tester.tap(prevFinder);
        await tester.pumpAndSettle();

        expect(modalFinder, findsOneWidget);
        expect(
          find.descendant(
            of: modalFinder,
            matching: find.text('Sakit perut, lehernya tegang'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: modalFinder,
            matching: find.text('REFERRAL LETTER'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: modalFinder,
            matching: find.text('RSUD dr. H. Koesnadi'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(of: modalFinder, matching: find.text('Antasida Doen')),
          findsOneWidget,
        );
      },
    );
  });
}
