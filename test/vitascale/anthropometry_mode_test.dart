import 'package:flutter_test/flutter_test.dart';
import 'package:mapotech/features/puskesmas/dlc/vitascale/data/vitascale_models.dart';
import 'package:mapotech/features/puskesmas/dlc/vitascale/logic/anthropometry_mode.dart';

void main() {
  group('AnthropometryModeHelper Tests (WHO & Kemenkes)', () {
    test('Child under 24 months recommends recumbent length', () {
      final mode0 = AnthropometryModeHelper.getRecommendedMode(0);
      final mode12 = AnthropometryModeHelper.getRecommendedMode(12);
      final mode23 = AnthropometryModeHelper.getRecommendedMode(23);

      expect(mode0, equals(AnthropometryMode.recumbentLength));
      expect(mode12, equals(AnthropometryMode.recumbentLength));
      expect(mode23, equals(AnthropometryMode.recumbentLength));
    });

    test('Child 24 months and older recommends standing height', () {
      final mode24 = AnthropometryModeHelper.getRecommendedMode(24);
      final mode60 = AnthropometryModeHelper.getRecommendedMode(60);
      final mode144 = AnthropometryModeHelper.getRecommendedMode(144);

      expect(mode24, equals(AnthropometryMode.standingHeight));
      expect(mode60, equals(AnthropometryMode.standingHeight));
      expect(mode144, equals(AnthropometryMode.standingHeight));
    });

    test('Warning returned when infant is manually measured standing', () {
      final warning = AnthropometryModeHelper.getOverrideWarning(
        ageInMonths: 10,
        chosenMode: AnthropometryMode.standingHeight,
      );

      expect(warning, isNotNull);
      expect(warning, contains('bawah usia 24 bulan'));
    });

    test('Warning returned when older child is manually measured recumbent', () {
      final warning = AnthropometryModeHelper.getOverrideWarning(
        ageInMonths: 36,
        chosenMode: AnthropometryMode.recumbentLength,
      );

      expect(warning, isNotNull);
      expect(warning, contains('0,7 cm'));
    });

    test('No warning when recommended mode is chosen', () {
      final warningInfant = AnthropometryModeHelper.getOverrideWarning(
        ageInMonths: 8,
        chosenMode: AnthropometryMode.recumbentLength,
      );
      final warningOlder = AnthropometryModeHelper.getOverrideWarning(
        ageInMonths: 48,
        chosenMode: AnthropometryMode.standingHeight,
      );

      expect(warningInfant, isNull);
      expect(warningOlder, isNull);
    });
  });
}
