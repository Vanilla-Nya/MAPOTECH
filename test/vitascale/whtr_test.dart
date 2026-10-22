import 'package:flutter_test/flutter_test.dart';
import 'package:mapotech/features/puskesmas/dlc/vitascale/logic/whtr.dart';

void main() {
  group('WHtR Calculator Tests', () {
    test('Returns null when height or waist is null or non-positive', () {
      expect(WHtRCalculator.calculate(waistCm: null, heightCm: 100, ageInMonths: 48), isNull);
      expect(WHtRCalculator.calculate(waistCm: 50, heightCm: null, ageInMonths: 48), isNull);
      expect(WHtRCalculator.calculate(waistCm: 0, heightCm: 100, ageInMonths: 48), isNull);
      expect(WHtRCalculator.calculate(waistCm: 50, heightCm: -10, ageInMonths: 48), isNull);
    });

    test('Correctly computes ratio with waist / height in cm', () {
      final res = WHtRCalculator.calculate(waistCm: 45.0, heightCm: 90.0, ageInMonths: 36);
      expect(res, isNotNull);
      expect(res!.ratio, closeTo(0.50, 0.001));
      expect(res.formattedRatio, equals('0.50'));
    });

    test('Child under 5 years (< 60 months) does not apply adult 0.5 cutoff', () {
      final infantRes = WHtRCalculator.calculate(waistCm: 48.0, heightCm: 75.0, ageInMonths: 12);
      expect(infantRes, isNotNull);
      // Ratio is 0.64 (common physiologically in infants)
      expect(infantRes!.ratio, closeTo(0.64, 0.01));
      expect(infantRes.informationalNote, contains('tidak berlaku pada balita'));
      expect(infantRes.informationalNote, contains('Indikator Tambahan'));
    });

    test('Older child (>= 60 months) indicates ratio note', () {
      final schoolChild = WHtRCalculator.calculate(waistCm: 65.0, heightCm: 120.0, ageInMonths: 84);
      expect(schoolChild, isNotNull);
      expect(schoolChild!.ratio, greaterThan(0.50));
      expect(schoolChild.informationalNote, contains('adipositas sentral'));
    });
  });
}
