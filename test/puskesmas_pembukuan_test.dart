import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapotech/features/landing/landing_page_data.dart';
import 'package:mapotech/features/puskesmas/dashboard/backend/puskesmas_satusehat_bookkeeping_service.dart';
import 'package:mapotech/features/puskesmas/dashboard/frontend/puskesmas_pembukuan.dart';
import 'package:mapotech/shared/web_helpers.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('PuskesmasSatuSehatConfig & PuskesmasEncounterRecord', () {
    test('credential completeness and staging environment flags', () {
      const incomplete = PuskesmasSatuSehatConfig(
        facilityId: 'PUSKESMAS-001',
        facilityName: 'Puskesmas Melati',
        clientId: 'cid-1',
        clientSecret: 'csec-1',
        organizationId: 'org-1',
      );
      expect(incomplete.hasCredentials, isTrue);
      expect(incomplete.isComplete, isFalse);
      expect(incomplete.isStaging, isFalse);

      final completeStaging = incomplete.copyWith(
        locationId: 'loc-1',
        practitionerId: 'N100001',
        env: 'staging',
        autoSync: false,
      );
      expect(completeStaging.isComplete, isTrue);
      expect(completeStaging.isStaging, isTrue);
      expect(completeStaging.autoSync, isFalse);
      expect(completeStaging.facilityName, 'Puskesmas Melati');
    });

    test('PuskesmasEncounterRecord.copyWith updates and clears syncError', () {
      final base = PuskesmasEncounterRecord(
        id: 'rec-1',
        sourceModule: 'momicare',
        sourceRecordId: 'kunjungan-1',
        clusterLabel: 'MomiCare ANC (CL-2)',
        visitLabel: 'K1 Trimester 1',
        visitDate: DateTime(2026, 11, 20, 9, 0),
        patientName: 'Ny. Sari',
        patientNik: '3515000000000001',
        patientType: 'BPJS',
        examinerName: 'Bidan Rina',
        faskesName: 'Puskesmas Melati',
        vitals: const {'blood_pressure': '115/75'},
        mainComplaint: 'Kontrol kehamilan trimester 1',
        physicalExam: 'KU Baik',
        diagnoses: const [
          {'code': 'Z34.0', 'description': 'Supervision of normal pregnancy'},
        ],
        therapies: const [
          {'name': 'Tablet Tambah Darah', 'qty': '30 Tab', 'dosage': '1x1'},
        ],
      );

      final failed = base.copyWith(
        syncStatus: 'failed',
        syncError: 'Timeout SATUSEHAT',
      );
      expect(failed.syncStatus, 'failed');
      expect(failed.syncError, 'Timeout SATUSEHAT');

      final succeeded = failed.copyWith(
        syncStatus: 'success',
        satusehatPatientId: 'P1234567890',
        satusehatEncounterId: 'enc-fh-1',
        clearSyncError: true,
      );
      expect(succeeded.syncStatus, 'success');
      expect(succeeded.syncError, isNull);
      expect(succeeded.satusehatPatientId, 'P1234567890');
      expect(succeeded.satusehatEncounterId, 'enc-fh-1');
    });
  });

  group('PuskesmasSatuSehatBookkeepingService', () {
    final service = PuskesmasSatuSehatBookkeepingService();

    test('isValidUuid validates UUID format properly', () {
      expect(
        PuskesmasSatuSehatBookkeepingService.isValidUuid(
          '123e4567-e89b-12d3-a456-426614174000',
        ),
        isTrue,
      );
      expect(
        PuskesmasSatuSehatBookkeepingService.isValidUuid('PUSKESMAS-001'),
        isFalse,
      );
      expect(PuskesmasSatuSehatBookkeepingService.isValidUuid(null), isFalse);
    });

    test('saveConfig and loadConfig round-trip via local storage', () async {
      const facilityId = 'PUSKESMAS-TEST-CFG';
      addTearDown(
        () => WebStorageHelper.removeItem('puskesmas_ss_cfg_v1_$facilityId'),
      );

      const savedCfg = PuskesmasSatuSehatConfig(
        facilityId: facilityId,
        facilityName: 'Puskesmas Test Kota',
        clientId: 'test-client-id',
        clientSecret: 'test-client-secret',
        organizationId: 'test-org-id',
        locationId: 'test-loc-id',
        practitionerId: 'test-prac-id',
        env: 'staging',
        autoSync: false,
      );

      await service.saveConfig(savedCfg);
      final loaded = await service.loadConfig(
        facilityId: facilityId,
        fallbackFacilityName: 'Puskesmas Test Kota',
      );

      expect(loaded.facilityName, 'Puskesmas Test Kota');
      expect(loaded.clientId, 'test-client-id');
      expect(loaded.clientSecret, 'test-client-secret');
      expect(loaded.organizationId, 'test-org-id');
      expect(loaded.locationId, 'test-loc-id');
      expect(loaded.practitionerId, 'test-prac-id');
      expect(loaded.env, 'staging');
      expect(loaded.autoSync, isFalse);
      expect(loaded.isComplete, isTrue);
    });

    test('loadEncounters aggregates VitaScale records and hydrates local logs', () async {
      const facilityId = 'PUSKESMAS-TEST-LOGS';
      addTearDown(() {
        WebStorageHelper.removeItem('puskesmas_ss_logs_v1_$facilityId');
        WebStorageHelper.removeItem('puskesmas_patient_ihs_v1_$facilityId');
      });

      final initialRecords = await service.loadEncounters(
        facilityId: facilityId,
        facilityName: 'Puskesmas Test Kota',
        momicarePatients: const [],
      );

      expect(initialRecords, isNotEmpty);
      final target = initialRecords.first;

      WebStorageHelper.setItem(
        'puskesmas_ss_logs_v1_$facilityId',
        jsonEncode({
          '${target.sourceModule}::${target.sourceRecordId}': {
            'sync_status': 'success',
            'satusehat_patient_id': 'P9988776655',
            'satusehat_encounter_id': 'enc-cached-99',
            'synced_at': '2026-11-27T08:00:00Z',
          },
        }),
      );

      final hydrated = await service.loadEncounters(
        facilityId: facilityId,
        facilityName: 'Puskesmas Test Kota',
        momicarePatients: const [],
      );

      final matched = hydrated.firstWhere((r) => r.id == target.id);
      expect(matched.syncStatus, 'success');
      expect(matched.satusehatPatientId, 'P9988776655');
      expect(matched.satusehatEncounterId, 'enc-cached-99');
      expect(matched.syncedAt, isNotNull);
    });

    test('syncEncounterToSatuSehat enforces patient IHS and Puskesmas config', () async {
      final noIhsRecord = PuskesmasEncounterRecord(
        id: 'enc-no-ihs',
        sourceModule: 'vitascale',
        sourceRecordId: 'vs-1',
        clusterLabel: 'VitaScale Anak (CL-2)',
        visitLabel: 'Skrining',
        visitDate: DateTime(2026, 11, 25),
        patientName: 'An. Budi',
        patientNik: '3515000000000002',
        patientType: 'BPJS',
        examinerName: 'Petugas Gizi',
        faskesName: 'Puskesmas Test',
        vitals: const {},
        mainComplaint: 'Kontrol',
        physicalExam: 'Normal',
        diagnoses: const [],
        therapies: const [],
      );

      await expectLater(
        service.syncEncounterToSatuSehat(
          record: noIhsRecord,
          config: const PuskesmasSatuSehatConfig(
            facilityId: 'PUSKESMAS-001',
            facilityName: 'Puskesmas Test',
          ),
          staffName: 'Bidan Test',
        ),
        throwsException,
      );

      final withIhs = noIhsRecord.copyWith(satusehatPatientId: 'P100000001');
      await expectLater(
        service.syncEncounterToSatuSehat(
          record: withIhs,
          config: const PuskesmasSatuSehatConfig(
            facilityId: 'PUSKESMAS-001',
            facilityName: 'Puskesmas Test',
          ),
          staffName: 'Bidan Test',
        ),
        throwsA(isA<PuskesmasSatuSehatConfigException>()),
      );
    });
  });

  group('PuskesmasPembukuan Widget', () {
    testWidgets('renders SATUSEHAT tab by default and switches to Coming Soon tab', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                padding: EdgeInsets.all(24),
                child: PuskesmasPembukuan(),
              ),
            ),
          ),
        ),
      );

      final container = ProviderScope.containerOf(
        tester.element(find.byType(PuskesmasPembukuan)),
      );
      container.read(landingPageProvider.notifier).setLanguage('id');
      await tester.pumpAndSettle();

      // Default tab in ID: SATUSEHAT & KPI header
      expect(find.text('Pembukuan Puskesmas'), findsOneWidget);
      expect(find.text('TOTAL PASIEN'), findsOneWidget);
      expect(find.text('TERKIRIM SATUSEHAT'), findsOneWidget);
      expect(find.text('BELUM TERKIRIM'), findsOneWidget);
      expect(find.text('GAGAL SINKRONISASI'), findsOneWidget);
      expect(find.text('Daftar Pasien & SATUSEHAT'), findsOneWidget);
      expect(find.text('Pembukuan Keuangan (Segera Hadir)'), findsOneWidget);

      // Switch to Financial Bookkeeping Coming Soon tab
      await tester.tap(find.text('Pembukuan Keuangan (Segera Hadir)'));
      await tester.pumpAndSettle();

      expect(
        find.text('Pembukuan Keuangan Puskesmas (Kas & Operasional BLUD)'),
        findsOneWidget,
      );
      expect(find.text('Buka Tab SATUSEHAT'), findsOneWidget);

      // Switch back via quick action button
      await tester.tap(find.text('Buka Tab SATUSEHAT'));
      await tester.pumpAndSettle();

      expect(find.text('Daftar Pasien & SATUSEHAT'), findsOneWidget);

      // Toggle bilingual mode to English
      container.read(landingPageProvider.notifier).setLanguage('en');
      await tester.pumpAndSettle();

      expect(find.text('Puskesmas Bookkeeping'), findsOneWidget);
      expect(find.text('Patient List & SATUSEHAT'), findsOneWidget);
      expect(find.text('TOTAL PATIENTS'), findsOneWidget);
    });
  });
}
