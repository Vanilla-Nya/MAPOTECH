import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../data/vitascale_models.dart';
import 'anthropometry_mode.dart';

/// State lengkap dari Sesi Skrining VitaScale
class ScreeningState {
  final ScreeningSession? session;
  final DeviceConnectionStatus deviceStatus;
  final String? lastDeviceHeartbeat;
  final bool isSubmitting;
  final String? errorMessage;
  final String? successMessage;
  final bool isCameraReady;
  final String? activeCameraLabel;

  const ScreeningState({
    this.session,
    this.deviceStatus = DeviceConnectionStatus.connected,
    this.lastDeviceHeartbeat,
    this.isSubmitting = false,
    this.errorMessage,
    this.successMessage,
    this.isCameraReady = false,
    this.activeCameraLabel,
  });

  bool get hasActiveSession => session != null && !session!.isFinalized;

  ScreeningState copyWith({
    ScreeningSession? session,
    DeviceConnectionStatus? deviceStatus,
    String? lastDeviceHeartbeat,
    bool? isSubmitting,
    String? errorMessage,
    String? successMessage,
    bool? isCameraReady,
    String? activeCameraLabel,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return ScreeningState(
      session: session ?? this.session,
      deviceStatus: deviceStatus ?? this.deviceStatus,
      lastDeviceHeartbeat: lastDeviceHeartbeat ?? this.lastDeviceHeartbeat,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearSuccess ? null : (successMessage ?? this.successMessage),
      isCameraReady: isCameraReady ?? this.isCameraReady,
      activeCameraLabel: activeCameraLabel ?? this.activeCameraLabel,
    );
  }
}

/// Notifier Pengendali State Machine Skrining VitaScale
class ScreeningStateMachine extends StateNotifier<ScreeningState> {
  ScreeningStateMachine() : super(const ScreeningState());

  static const _uuid = Uuid();

  /// Memulai sesi baru untuk anak terpilih
  void startSession({
    required ChildProfile child,
    required String facilityId,
    AnthropometryMode? overrideMode,
    bool isDemo = true,
  }) {
    final mode = overrideMode ?? AnthropometryModeHelper.getRecommendedMode(child.ageInMonths);
    final isOverride = overrideMode != null && overrideMode != child.defaultMode;

    final newSession = ScreeningSession(
      sessionId: 'VTS-${DateTime.now().year}-${_uuid.v4().substring(0, 8).toUpperCase()}',
      facilityId: facilityId,
      child: child,
      startTime: DateTime.now(),
      mode: mode,
      isModeManualOverride: isOverride,
      isDemo: isDemo,
      weight: const MeasurementItem(type: MeasurementType.weight),
      height: const MeasurementItem(type: MeasurementType.height),
      waist: const MeasurementItem(type: MeasurementType.waist),
    );

    state = state.copyWith(
      session: newSession,
      clearError: true,
      clearSuccess: true,
      successMessage: 'Sesi skrining aktif untuk ${child.name}.',
    );
  }

  /// Menyesuaikan mode antropometri oleh petugas
  void changeAnthropometryMode(AnthropometryMode mode) {
    if (state.session == null || state.session!.isFinalized) return;
    final isOverride = mode != state.session!.child.defaultMode;
    state = state.copyWith(
      session: state.session!.copyWith(
        mode: mode,
        isModeManualOverride: isOverride,
      ),
    );
  }

  /// Memperbarui status koneksi perangkat
  void setDeviceStatus(DeviceConnectionStatus status, {String? heartbeat}) {
    state = state.copyWith(
      deviceStatus: status,
      lastDeviceHeartbeat: heartbeat ?? DateTime.now().toIso8601String(),
    );
  }

  /// Memperbarui status kamera browser
  void setCameraStatus({required bool isReady, String? cameraLabel}) {
    state = state.copyWith(
      isCameraReady: isReady,
      activeCameraLabel: cameraLabel,
    );
  }

  /// Memperbarui hasil pembacaan berat badan (HX711)
  void updateWeight({
    required double? value,
    MeasurementStatus status = MeasurementStatus.stable,
    String source = 'esp32_hx711',
    String? errorMessage,
  }) {
    if (state.session == null || state.session!.isFinalized) return;

    // Validasi range klinis yang wajar untuk anak 0-12 tahun (1.0 kg - 120 kg)
    if (value != null && (value < 1.0 || value > 150.0)) {
      status = MeasurementStatus.failed;
      errorMessage = 'Nilai berat ($value kg) di luar rentang wajar (1.0 - 150 kg).';
    }

    final item = state.session!.weight.copyWith(
      value: value,
      status: status,
      capturedAt: DateTime.now(),
      source: source,
      errorMessage: errorMessage,
      idempotencyKey: _uuid.v4(),
    );

    state = state.copyWith(
      session: state.session!.copyWith(weight: item),
      clearError: true,
    );
  }

  /// Memperbarui hasil pembacaan panjang/tinggi badan (OpenCV.js marker-based)
  void updateHeight({
    required double? value,
    MeasurementStatus status = MeasurementStatus.stable,
    String source = 'opencv_web',
    String? errorMessage,
  }) {
    if (state.session == null || state.session!.isFinalized) return;

    // Validasi range klinis wajar untuk anak 0-12 tahun (30 cm - 190 cm)
    if (value != null && (value < 30.0 || value > 200.0)) {
      status = MeasurementStatus.failed;
      errorMessage = 'Nilai panjang/tinggi ($value cm) di luar rentang wajar (30 - 200 cm).';
    }

    final item = state.session!.height.copyWith(
      value: value,
      status: status,
      capturedAt: DateTime.now(),
      source: source,
      errorMessage: errorMessage,
      idempotencyKey: _uuid.v4(),
    );

    state = state.copyWith(
      session: state.session!.copyWith(height: item),
      clearError: true,
    );
  }

  /// Memperbarui hasil pembacaan lingkar perut (AS5600)
  void updateWaist({
    required double? value,
    MeasurementStatus status = MeasurementStatus.stable,
    String source = 'esp32_as5600',
    String? errorMessage,
  }) {
    if (state.session == null || state.session!.isFinalized) return;

    // Validasi range wajar (25 cm - 140 cm)
    if (value != null && (value < 25.0 || value > 140.0)) {
      status = MeasurementStatus.failed;
      errorMessage = 'Nilai lingkar perut ($value cm) di luar rentang wajar (25 - 140 cm).';
    }

    final item = state.session!.waist.copyWith(
      value: value,
      status: status,
      capturedAt: DateTime.now(),
      source: source,
      errorMessage: errorMessage,
      idempotencyKey: _uuid.v4(),
    );

    state = state.copyWith(
      session: state.session!.copyWith(waist: item),
      clearError: true,
    );
  }

  /// Mengulang pengukuran parameter tertentu
  void resetMeasurement(MeasurementType type) {
    if (state.session == null || state.session!.isFinalized) return;

    final emptyItem = MeasurementItem(type: type, status: MeasurementStatus.empty);
    switch (type) {
      case MeasurementType.weight:
        state = state.copyWith(session: state.session!.copyWith(weight: emptyItem));
        break;
      case MeasurementType.height:
        state = state.copyWith(session: state.session!.copyWith(height: emptyItem));
        break;
      case MeasurementType.waist:
        state = state.copyWith(session: state.session!.copyWith(waist: emptyItem));
        break;
    }
  }

  /// Verifikasi oleh petugas dan finalisasi penyimpanan hasil
  Future<bool> verifyAndFinalize({
    required String verifiedBy,
    String? notes,
  }) async {
    final curr = state.session;
    if (curr == null) {
      state = state.copyWith(errorMessage: 'Tidak ada sesi skrining aktif.');
      return false;
    }

    if (curr.isFinalized) {
      state = state.copyWith(errorMessage: 'Sesi ini sudah pernah diverifikasi & ditutup.');
      return false;
    }

    if (!curr.weight.hasValue || !curr.height.hasValue || !curr.waist.hasValue) {
      state = state.copyWith(
        errorMessage: 'Semua pengukuran (Berat, Panjang/Tinggi, Lingkar Perut) harus terisi sebelum verifikasi final.',
      );
      return false;
    }

    state = state.copyWith(isSubmitting: true, clearError: true);

    try {
      // Tandai semua item sebagai verified
      final finalizedWeight = curr.weight.copyWith(status: MeasurementStatus.verified);
      final finalizedHeight = curr.height.copyWith(status: MeasurementStatus.verified);
      final finalizedWaist = curr.waist.copyWith(status: MeasurementStatus.verified);

      final finalizedSession = curr.copyWith(
        endTime: DateTime.now(),
        isFinalized: true,
        weight: finalizedWeight,
        height: finalizedHeight,
        waist: finalizedWaist,
        notes: notes,
      );

      state = state.copyWith(
        isSubmitting: false,
        session: finalizedSession,
        successMessage: 'Hasil skrining berhasil diverifikasi dan disimpan oleh $verifiedBy.',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'Gagal memfinalisasi skrining: $e',
      );
      return false;
    }
  }

  /// Menutup sesi skrining aktif
  void closeSession() {
    state = state.copyWith(
      session: null,
      clearError: true,
      clearSuccess: true,
    );
  }
}

final screeningStateProvider = StateNotifierProvider<ScreeningStateMachine, ScreeningState>((ref) {
  return ScreeningStateMachine();
});
