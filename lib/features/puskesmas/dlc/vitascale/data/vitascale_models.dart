import 'package:flutter/material.dart';

/// Mode antropometri pengukuran panjang/tinggi badan
enum AnthropometryMode {
  /// Usia < 24 bulan: panjang badan telentang (recumbent length)
  recumbentLength('Panjang Badan Telentang (< 24 Bln)', 'PB'),

  /// Usia 24 bulan s/d 12 tahun: tinggi badan berdiri (standing height)
  standingHeight('Tinggi Badan Berdiri (≥ 24 Bln)', 'TB');

  final String label;
  final String code;
  const AnthropometryMode(this.label, this.code);
}

/// Status kualitas dan stabilitas pembacaan sensor/kamera
enum MeasurementStatus {
  empty('Belum Diukur', Colors.grey),
  measuring('Sedang Mengukur...', Color(0xFFF39C12)),
  stable('Stabil & Siap Verifikasi', Color(0xFF27AE60)),
  failed('Pengukuran Gagal', Color(0xFFE74C3C)),
  verified('Terverifikasi Petugas', Color(0xFF2980B9));

  final String label;
  final Color color;
  const MeasurementStatus(this.label, this.color);
}

/// Jenis pengukuran antropometri VitaScale
enum MeasurementType {
  weight('Berat Badan', 'kg'),
  height('Panjang / Tinggi Badan', 'cm'),
  waist('Lingkar Perut', 'cm');

  final String label;
  final String unit;
  const MeasurementType(this.label, this.unit);
}

/// Status koneksi perangkat keras ESP32
enum DeviceConnectionStatus {
  disconnected('Terputus', Color(0xFFE74C3C)),
  connecting('Menghubungkan...', Color(0xFFF39C12)),
  connected('Terhubung (Online)', Color(0xFF27AE60));

  final String label;
  final Color color;
  const DeviceConnectionStatus(this.label, this.color);
}

/// Model profil data anak/bayi (usia 0-12 tahun)
class ChildProfile {
  final String id;
  final String name;
  final String nik;
  final DateTime birthDate;
  final String gender; // 'L' (Laki-laki) atau 'P' (Perempuan)
  final String parentName;
  final String? noKk;
  final String? phone;
  final String address;
  final String? photoUrl;

  const ChildProfile({
    required this.id,
    required this.name,
    required this.nik,
    required this.birthDate,
    required this.gender,
    required this.parentName,
    this.noKk,
    this.phone,
    required this.address,
    this.photoUrl,
  });

  /// Menghitung usia anak dalam bulan secara presisi
  int get ageInMonths {
    final now = DateTime.now();
    int months = (now.year - birthDate.year) * 12 + now.month - birthDate.month;
    if (now.day < birthDate.day) {
      months--;
    }
    return months < 0 ? 0 : months;
  }

  /// Menghitung usia dalam format teks (misal: "1 Tahun 4 Bulan" atau "8 Bulan")
  String get ageLabel {
    final totalMonths = ageInMonths;
    final years = totalMonths ~/ 12;
    final remainingMonths = totalMonths % 12;
    if (years > 0) {
      return remainingMonths > 0 ? '$years Thn $remainingMonths Bln' : '$years Tahun';
    }
    return '$totalMonths Bulan';
  }

  /// Apakah anak masuk kategori bayi di bawah 24 bulan (< 2 tahun)
  bool get isUnder24Months => ageInMonths < 24;

  /// Mode antropometri default berdasarkan usia WHO
  AnthropometryMode get defaultMode =>
      isUnder24Months ? AnthropometryMode.recumbentLength : AnthropometryMode.standingHeight;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'nik': nik,
        'birth_date': birthDate.toIso8601String(),
        'gender': gender,
        'parent_name': parentName,
        'no_kk': noKk,
        'phone': phone,
        'address': address,
        'photo_url': photoUrl,
      };

  factory ChildProfile.fromJson(Map<String, dynamic> json) {
    return ChildProfile(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Tanpa Nama',
      nik: json['nik']?.toString() ?? '-',
      birthDate: json['birth_date'] != null
          ? DateTime.tryParse(json['birth_date'].toString()) ?? DateTime.now()
          : DateTime.now(),
      gender: (json['gender']?.toString().toLowerCase().startsWith('l') ?? true) ? 'L' : 'P',
      parentName: json['parent_name']?.toString() ?? '-',
      noKk: json['no_kk']?.toString(),
      phone: json['phone']?.toString(),
      address: json['address']?.toString() ?? 'Puskesmas',
      photoUrl: json['photo_url']?.toString(),
    );
  }
}

/// Data nilai pembacaan sensor/kamera sementara
class MeasurementItem {
  final MeasurementType type;
  final double? value;
  final MeasurementStatus status;
  final DateTime? capturedAt;
  final String? errorMessage;
  final String source; // 'esp32_hx711', 'opencv_web', 'esp32_as5600', 'manual'
  final String? idempotencyKey;

  const MeasurementItem({
    required this.type,
    this.value,
    this.status = MeasurementStatus.empty,
    this.capturedAt,
    this.errorMessage,
    this.source = 'simulator',
    this.idempotencyKey,
  });

  bool get hasValue => value != null && value! > 0;

  MeasurementItem copyWith({
    MeasurementType? type,
    double? value,
    MeasurementStatus? status,
    DateTime? capturedAt,
    String? errorMessage,
    String? source,
    String? idempotencyKey,
  }) {
    return MeasurementItem(
      type: type ?? this.type,
      value: value ?? this.value,
      status: status ?? this.status,
      capturedAt: capturedAt ?? this.capturedAt,
      errorMessage: errorMessage ?? this.errorMessage,
      source: source ?? this.source,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
    );
  }
}

/// Sesi Skrining Aktif VitaScale
class ScreeningSession {
  final String sessionId;
  final String facilityId;
  final ChildProfile child;
  final DateTime startTime;
  final DateTime? endTime;
  final AnthropometryMode mode;
  final bool isModeManualOverride;
  final MeasurementItem weight;
  final MeasurementItem height;
  final MeasurementItem waist;
  final bool isDemo;
  final bool isFinalized;
  final String? notes;

  const ScreeningSession({
    required this.sessionId,
    required this.facilityId,
    required this.child,
    required this.startTime,
    this.endTime,
    required this.mode,
    this.isModeManualOverride = false,
    this.weight = const MeasurementItem(type: MeasurementType.weight),
    this.height = const MeasurementItem(type: MeasurementType.height),
    this.waist = const MeasurementItem(type: MeasurementType.waist),
    this.isDemo = true,
    this.isFinalized = false,
    this.notes,
  });

  /// Menghitung WHtR (Waist-to-Height Ratio) jika tinggi dan lingkar perut valid
  double? get calculatedWHtR {
    if (height.value != null && height.value! > 0 && waist.value != null && waist.value! > 0) {
      return waist.value! / height.value!;
    }
    return null;
  }

  /// Apakah semua 3 parameter sudah stabil dan siap diverifikasi oleh petugas
  bool get isReadyForVerification =>
      weight.status == MeasurementStatus.stable &&
      height.status == MeasurementStatus.stable &&
      waist.status == MeasurementStatus.stable;

  ScreeningSession copyWith({
    String? sessionId,
    String? facilityId,
    ChildProfile? child,
    DateTime? startTime,
    DateTime? endTime,
    AnthropometryMode? mode,
    bool? isModeManualOverride,
    MeasurementItem? weight,
    MeasurementItem? height,
    MeasurementItem? waist,
    bool? isDemo,
    bool? isFinalized,
    String? notes,
  }) {
    return ScreeningSession(
      sessionId: sessionId ?? this.sessionId,
      facilityId: facilityId ?? this.facilityId,
      child: child ?? this.child,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      mode: mode ?? this.mode,
      isModeManualOverride: isModeManualOverride ?? this.isModeManualOverride,
      weight: weight ?? this.weight,
      height: height ?? this.height,
      waist: waist ?? this.waist,
      isDemo: isDemo ?? this.isDemo,
      isFinalized: isFinalized ?? this.isFinalized,
      notes: notes ?? this.notes,
    );
  }
}
