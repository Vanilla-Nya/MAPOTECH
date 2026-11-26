import 'package:flutter_test/flutter_test.dart';
import 'package:mapotech/features/puskesmas/dlc/vitascale/data/vitascale_models.dart';

void main() {
  group('ChildProfile.calculateCompletedMonths Tests', () {
    test('Counts exact 1 completed month when day matches', () {
      final birth = DateTime(2026, 10, 26);
      final ref = DateTime(2026, 11, 26);
      expect(ChildProfile.calculateCompletedMonths(birth, ref), equals(1));
    });

    test('Does not add 1 month before exact day of month is reached', () {
      final birth = DateTime(2026, 10, 27);
      final ref = DateTime(2026, 11, 26);
      expect(ChildProfile.calculateCompletedMonths(birth, ref), equals(0));
    });

    test('Handles 12-month boundary accurately', () {
      final birthReached = DateTime(2025, 11, 26);
      final birthNotReached = DateTime(2025, 11, 27);
      final ref = DateTime(2026, 11, 26);

      expect(ChildProfile.calculateCompletedMonths(birthReached, ref), equals(12));
      expect(ChildProfile.calculateCompletedMonths(birthNotReached, ref), equals(11));
    });

    test('Returns 0 when birthDate is in the future', () {
      final birth = DateTime(2026, 12, 1);
      final ref = DateTime(2026, 11, 26);
      expect(ChildProfile.calculateCompletedMonths(birth, ref), equals(0));
    });

    test('Computes multi-year age in months accurately', () {
      final birth = DateTime(2024, 5, 10);
      final ref = DateTime(2026, 11, 26);
      expect(ChildProfile.calculateCompletedMonths(birth, ref), equals(30));
    });
  });
}
