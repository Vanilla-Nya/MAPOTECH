import 'package:flutter/material.dart';

/// Hasil kalkulasi rasio lingkar perut terhadap tinggi badan (Waist-to-Height Ratio / WHtR).
///
/// PERINGATAN KLINIS & BATASAN:
/// 1. WHtR adalah indikator tambahan (adipositas/lemak viseral sentral), BUKAN penentu stunting.
/// 2. Batas acuan universal 0,5 (cut-off dewasa) TIDAK BERLAKU untuk bayi & anak balita (< 5 tahun)
///    karena balita memiliki rasio lingkar perut fisiologis yang lebih besar secara alami.
/// 3. Sebelum ada referensi tabel Kemenkes/WHO terverifikasi khusus untuk kelompok umur ini,
///    nilai hanya disajikan sebagai angka rasio objektif dengan catatan penjelas.
class WHtRResult {
  final double ratio;
  final double waistCm;
  final double heightCm;
  final int ageInMonths;
  final String informationalNote;
  final Color indicatorColor;

  const WHtRResult({
    required this.ratio,
    required this.waistCm,
    required this.heightCm,
    required this.ageInMonths,
    required this.informationalNote,
    required this.indicatorColor,
  });

  /// Format rasio dengan 2 desimal (misal: "0.48")
  String get formattedRatio => ratio.toStringAsFixed(2);
}

class WHtRCalculator {
  /// Menghitung WHtR dari lingkar perut (cm) dan tinggi badan (cm).
  /// Mengembalikan null bila salah satu input tidak valid (<= 0).
  static WHtRResult? calculate({
    required double? waistCm,
    required double? heightCm,
    required int ageInMonths,
  }) {
    if (waistCm == null || waistCm <= 0 || heightCm == null || heightCm <= 0) {
      return null;
    }

    final ratio = waistCm / heightCm;

    // Evaluasi kontekstual berdasarkan usia tanpa memaksakan cut-off 0.5 pada balita
    String note;
    Color color;

    if (ageInMonths < 60) {
      // Bayi & Balita (< 5 tahun): fisiologis rasio lebih tinggi
      note = 'Indikator Tambahan: Rasio lingkar perut/panjang badan balita. '
          'Batas acuan 0.5 dewasa tidak berlaku pada balita; evaluasi gizi utama harus mengacu '
          'pada kurva pertumbuhan baku WHO/Kemenkes (BB/U, TB/U, BB/TB).';
      color = const Color(0xFF3498DB); // Netral informatif
    } else {
      // Anak Usia Sekolah (5–12 tahun)
      if (ratio > 0.50) {
        note = 'Indikator Tambahan: Rasio lingkar perut terhadap tinggi badan > 0.50. '
            'Merupakan indikasi awal perhatian terhadap distribusi adipositas sentral pada anak usia sekolah.';
        color = const Color(0xFFE67E22); // Perhatian
      } else {
        note = 'Indikator Tambahan: Rasio lingkar perut terhadap tinggi badan berada dalam rentang proporsional.';
        color = const Color(0xFF27AE60); // Sehat
      }
    }

    return WHtRResult(
      ratio: ratio,
      waistCm: waistCm,
      heightCm: heightCm,
      ageInMonths: ageInMonths,
      informationalNote: note,
      indicatorColor: color,
    );
  }
}
