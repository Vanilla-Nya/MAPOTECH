import '../data/vitascale_models.dart';

/// Helper logika mode antropometri berdasarkan pedoman standar Kemenkes & WHO:
/// - Usia < 24 bulan (< 2 tahun): Panjang Badan Telentang (Infantometer / Recumbent Length Board)
/// - Usia ≥ 24 bulan s/d 12 tahun: Tinggi Badan Berdiri (Stadiometer / Standing Height)
class AnthropometryModeHelper {
  /// Menentukan mode pengukuran default berdasarkan usia anak
  static AnthropometryMode getRecommendedMode(int ageInMonths) {
    if (ageInMonths < 24) {
      return AnthropometryMode.recumbentLength;
    }
    return AnthropometryMode.standingHeight;
  }

  /// Catatan edukasi klinis sesuai pedoman standar Kemenkes
  static String getModeDescription(AnthropometryMode mode) {
    switch (mode) {
      case AnthropometryMode.recumbentLength:
        return 'Pengukuran panjang badan anak telentang menggunakan papan ukur datar (Infantometer). '
            'Posisi kepala menempel pada batas tetap dan kaki lurus menyentuh pembatas geser.';
      case AnthropometryMode.standingHeight:
        return 'Pengukuran tinggi badan anak berdiri tegak membelakangi dinding/tiang ukur (Stadiometer). '
            'Tumit, pantat, punggung, dan kepala menempel pada bidang vertikal.';
    }
  }

  /// Validasi apakah penyesuaian manual diperbolehkan dengan peringatan klinis
  static String? getOverrideWarning({
    required int ageInMonths,
    required AnthropometryMode chosenMode,
  }) {
    final recommended = getRecommendedMode(ageInMonths);
    if (chosenMode == recommended) return null;

    if (ageInMonths < 24 && chosenMode == AnthropometryMode.standingHeight) {
      return 'Perhatian Klinis: Anak di bawah usia 24 bulan umumnya belum dapat berdiri stabil '
          'dengan postur anatomis lurus. Pengukuran berdiri pada bayi berisiko menghasilkan deviasi tinggi badan.';
    }

    if (ageInMonths >= 24 && chosenMode == AnthropometryMode.recumbentLength) {
      return 'Perhatian Klinis: Anak usia ≥ 24 bulan diukur telentang bila anak sakit, lemas, atau tidak mampu berdiri. '
          'Menurut standar WHO, panjang badan telentang pada kelompok ini rata-rata sekitar 0,7 cm lebih panjang dari tinggi berdiri.';
    }

    return null;
  }
}
