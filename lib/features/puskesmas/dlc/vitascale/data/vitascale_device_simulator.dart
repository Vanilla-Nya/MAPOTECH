import 'dart:async';
import 'dart:math';
import '../logic/screening_state_machine.dart';
import 'vitascale_models.dart';

/// Simulator Perangkat Keras VitaScale ESP32 & Fixture CV
///
/// PERINGATAN INTEGRASI:
/// Sesuai Kriteria Pengujian Milestone:
/// Seluruh data yang dihasilkan simulator ini diberi label tegas "SIMULASI"
/// dan TIDAK BOLEH diklaim sebagai data sensor hardware atau hasil klinis fisik asli.
class VitaScaleDeviceSimulator {
  final ScreeningStateMachine stateMachine;
  Timer? _streamTimer;
  final Random _random = Random();

  bool _isSimulatingWeight = false;
  bool _isSimulatingWaist = false;

  VitaScaleDeviceSimulator({required this.stateMachine});

  /// Mengalirkan simulasi kestabilan berat badan (HX711 4x50kg Load Cell)
  void simulateWeightMeasurement({
    double targetWeight = 14.85,
    Duration duration = const Duration(seconds: 3),
  }) {
    if (_isSimulatingWeight) return;
    _isSimulatingWeight = true;

    stateMachine.updateWeight(
      value: null,
      status: MeasurementStatus.measuring,
      source: 'simulator_hx711',
    );

    int step = 0;
    const totalSteps = 6;
    Timer.periodic(const Duration(milliseconds: 500), (t) {
      step++;
      if (step < totalSteps) {
        // Simulasi fluktuasi/noise saat anak bergerak di atas timbangan
        final noise = (_random.nextDouble() - 0.5) * 0.8;
        stateMachine.updateWeight(
          value: double.parse((targetWeight + noise).toStringAsFixed(2)),
          status: MeasurementStatus.measuring,
          source: 'simulator_hx711',
        );
      } else {
        // Data mencapai kondisi stabil (steady state)
        t.cancel();
        _isSimulatingWeight = false;
        stateMachine.updateWeight(
          value: targetWeight,
          status: MeasurementStatus.stable,
          source: 'simulator_hx711',
        );
      }
    });
  }

  /// Mengalirkan simulasi sensor lingkar perut AS5600
  void simulateWaistMeasurement({
    double targetWaist = 48.5,
  }) {
    if (_isSimulatingWaist) return;
    _isSimulatingWaist = true;

    stateMachine.updateWaist(
      value: null,
      status: MeasurementStatus.measuring,
      source: 'simulator_as5600',
    );

    int step = 0;
    const totalSteps = 5;
    Timer.periodic(const Duration(milliseconds: 400), (t) {
      step++;
      if (step < totalSteps) {
        final noise = (_random.nextDouble() - 0.5) * 1.5;
        stateMachine.updateWaist(
          value: double.parse((targetWaist + noise).toStringAsFixed(1)),
          status: MeasurementStatus.measuring,
          source: 'simulator_as5600',
        );
      } else {
        t.cancel();
        _isSimulatingWaist = false;
        stateMachine.updateWaist(
          value: targetWaist,
          status: MeasurementStatus.stable,
          source: 'simulator_as5600',
        );
      }
    });
  }

  /// Menginjeksikan hasil pengujian fixture Computer Vision sintetis
  void injectCvFixtureMeasurement({
    double fixtureHeight = 92.4,
  }) {
    stateMachine.updateHeight(
      value: fixtureHeight,
      status: MeasurementStatus.stable,
      source: 'fixture_cv_synthetic',
    );
  }

  /// Simulasi putusnya dan pulihnya koneksi ESP32
  void simulateConnectionToggle(bool isOnline) {
    stateMachine.setDeviceStatus(
      isOnline ? DeviceConnectionStatus.connected : DeviceConnectionStatus.disconnected,
    );
  }

  void dispose() {
    _streamTimer?.cancel();
  }
}
