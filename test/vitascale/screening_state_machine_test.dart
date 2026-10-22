import 'package:flutter_test/flutter_test.dart';
import 'package:mapotech/features/puskesmas/dlc/vitascale/data/vitascale_models.dart';
import 'package:mapotech/features/puskesmas/dlc/vitascale/logic/screening_state_machine.dart';

void main() {
  group('ScreeningStateMachine Tests', () {
    late ScreeningStateMachine sm;
    final testChild = ChildProfile(
      id: 'ANK-TEST',
      name: 'Ananda Test',
      nik: '3511000000000001',
      birthDate: DateTime.now().subtract(const Duration(days: 400)), // ~13 bulan
      gender: 'L',
      parentName: 'Orang Tua Test',
      address: 'Puskesmas Test',
    );

    setUp(() {
      sm = ScreeningStateMachine();
    });

    test('Initial state has no active session', () {
      expect(sm.state.session, isNull);
      expect(sm.state.hasActiveSession, isFalse);
    });

    test('startSession initializes child with WHO recommended mode', () {
      sm.startSession(child: testChild, facilityId: 'FASKES-01');

      expect(sm.state.hasActiveSession, isTrue);
      expect(sm.state.session!.child.name, equals('Ananda Test'));
      expect(sm.state.session!.mode, equals(AnthropometryMode.recumbentLength));
      expect(sm.state.session!.weight.status, equals(MeasurementStatus.empty));
      expect(sm.state.session!.height.status, equals(MeasurementStatus.empty));
      expect(sm.state.session!.waist.status, equals(MeasurementStatus.empty));
    });

    test('update measurements updates items and validates ranges', () {
      sm.startSession(child: testChild, facilityId: 'FASKES-01');

      // Valid weight
      sm.updateWeight(value: 9.85, status: MeasurementStatus.stable);
      expect(sm.state.session!.weight.value, equals(9.85));
      expect(sm.state.session!.weight.status, equals(MeasurementStatus.stable));

      // Out of range weight (< 1.0 kg)
      sm.updateWeight(value: 0.2);
      expect(sm.state.session!.weight.status, equals(MeasurementStatus.failed));
      expect(sm.state.session!.weight.errorMessage, contains('di luar rentang'));

      // Valid height and waist
      sm.updateHeight(value: 76.5, status: MeasurementStatus.stable);
      sm.updateWaist(value: 45.0, status: MeasurementStatus.stable);

      expect(sm.state.session!.height.value, equals(76.5));
      expect(sm.state.session!.waist.value, equals(45.0));
      expect(sm.state.session!.isReadyForVerification, isFalse); // weight was failed
    });

    test('verifyAndFinalize prevents incomplete verification and double submit', () async {
      sm.startSession(child: testChild, facilityId: 'FASKES-01');

      // Incomplete measurements
      sm.updateWeight(value: 10.0, status: MeasurementStatus.stable);
      final failedOk = await sm.verifyAndFinalize(verifiedBy: 'Bidan Uji');
      expect(failedOk, isFalse);
      expect(sm.state.errorMessage, contains('harus terisi'));

      // Complete all measurements
      sm.updateHeight(value: 75.0, status: MeasurementStatus.stable);
      sm.updateWaist(value: 44.0, status: MeasurementStatus.stable);

      final successOk = await sm.verifyAndFinalize(verifiedBy: 'Bidan Uji', notes: 'Kondisi anak tenang');
      expect(successOk, isTrue);
      expect(sm.state.session!.isFinalized, isTrue);
      expect(sm.state.session!.weight.status, equals(MeasurementStatus.verified));

      // Double submit prevention
      final secondTry = await sm.verifyAndFinalize(verifiedBy: 'Bidan Uji');
      expect(secondTry, isFalse);
      expect(sm.state.errorMessage, contains('sudah pernah diverifikasi'));
    });
  });
}
