import 'package:flutter_test/flutter_test.dart';
import 'package:mapotech/shared/letter_models.dart';

void main() {
  group('MedicalLetterVerificationRequest', () {
    test('parses query parameter URL format', () {
      final req = MedicalLetterVerificationRequest.parseUri(
        Uri.parse(
          'https://mapotek.relvastudio.com/?verify=rujukan&id=enc-12345',
        ),
      );
      expect(req, isNotNull);
      expect(req!.encounterId, 'enc-12345');
      expect(req.expectedType, MedicalLetterType.rujukan);
    });

    test('parses Laravel-style path URL format', () {
      final req = MedicalLetterVerificationRequest.parseUri(
        Uri.parse('https://mapotek.relvastudio.com/rujukan/abc-999/verifikasi'),
      );
      expect(req, isNotNull);
      expect(req!.encounterId, 'abc-999');
      expect(req.expectedType, MedicalLetterType.rujukan);
    });

    test('parses hash fragment route format', () {
      final req = MedicalLetterVerificationRequest.parseUri(
        Uri.parse(
          'https://mapotek.relvastudio.com/#/surat-sakit/xyz-777/verifikasi',
        ),
      );
      expect(req, isNotNull);
      expect(req!.encounterId, 'xyz-777');
      expect(req.expectedType, MedicalLetterType.suratSakit);
    });

    test('ignores preview or mock IDs', () {
      expect(
        MedicalLetterVerificationRequest.parseUri(
          Uri.parse('https://mapotech.kemenkes.go.id/rujukan/preview'),
        ),
        isNull,
      );
      expect(
        MedicalLetterVerificationRequest.parseUri(
          Uri.parse('https://mapotek.relvastudio.com/?verify=rujukan&id=draft'),
        ),
        isNull,
      );
    });

    test('builds dynamic verification URL', () {
      final url = MedicalLetterVerificationRequest.buildVerificationUrl(
        encounterId: 'uuid-111',
        type: MedicalLetterType.suratSehat,
        originOverride: 'https://app.example.com/',
      );
      expect(url, 'https://app.example.com/?verify=surat-sehat&id=uuid-111');
    });
  });

  group('MedicalLetterData', () {
    test('masks NIK and parses mixed practice licenses', () {
      final licenses = MedicalLetterData.parseLicenses([
        'SIP. 503/446/2026',
        {'type': 'SIP', 'url': 'SIP. 999/001/2026'},
      ]);
      expect(licenses, ['SIP. 503/446/2026', 'SIP. 999/001/2026']);

      final data = MedicalLetterData(
        encounterId: 'enc-1234',
        type: MedicalLetterType.rujukan,
        letterNumber: 'REF/2026/11/1001',
        signedAt: DateTime(2026, 11, 26, 21, 30),
        patientName: 'Budi Santoso',
        patientNik: '3511050812000001',
        doctorId: 'doc-1',
        doctorName: 'dr. Agoes Soetanto',
        doctorLicenses: licenses,
      );
      expect(data.maskedNik, '351105******0001');
      expect(data.primarySip, 'SIP. 503/446/2026');
      expect(
        data.verificationUrl,
        'https://mapotek.relvastudio.com/?verify=rujukan&id=enc-1234',
      );
    });

    test('generates SVG QR and HTML templates for Rujukan, Sehat, Sakit', () {
      final svg = MedicalLetterData.buildQrSvg(
        'https://mapotek.relvastudio.com/?verify=rujukan&id=enc-1234',
      );
      expect(svg, contains('<svg'));
      expect(svg, contains('<path'));

      final rujukanHtml = MedicalLetterData.buildPrintableHtml(
        MedicalLetterData(
          encounterId: 'enc-1234',
          type: MedicalLetterType.rujukan,
          letterNumber: 'REF/2026/11/1001',
          signedAt: DateTime(2026, 11, 26, 21, 30),
          rujukanRumahSakit: 'RSUD dr. H. Koesnadi',
          rujukanPoli: 'Penyakit Dalam',
          patientName: 'Siti <script>alert(1)</script>',
          doctorId: 'doc-1',
          doctorName: 'dr. Agoes Soetanto',
          doctorFaskesName: 'Klinik Pratama Sehat',
          doctorLicenses: const ['SIP. 446/2026'],
          diagnoses: const [
            {'code': 'I10', 'description': 'Essential hypertension'},
          ],
        ),
      );
      expect(rujukanHtml, contains('SURAT RUJUKAN PASIEN'));
      expect(rujukanHtml, contains('RSUD dr. H. Koesnadi'));
      expect(rujukanHtml, contains('KLINIK PRATAMA SEHAT'));
      expect(rujukanHtml, contains('&lt;script&gt;alert(1)&lt;&#47;script&gt;'));
      expect(rujukanHtml, isNot(contains('<script>alert(1)</script>')));

      final sakitHtml = MedicalLetterData.buildPrintableHtml(
        MedicalLetterData(
          encounterId: 'enc-5678',
          type: MedicalLetterType.suratSakit,
          letterNumber: 'SK-SAKIT/2026/ENC5',
          signedAt: DateTime(2026, 11, 26, 10, 15),
          suratSakitHari: 3,
          suratSakitMulai: DateTime(2026, 11, 26),
          suratSakitSelesai: DateTime(2026, 11, 28),
          suratKeperluan: 'Izin tidak masuk kerja',
          patientName: 'Andi Wijaya',
          doctorId: 'doc-1',
          doctorName: 'dr. Agoes Soetanto',
        ),
      );
      expect(sakitHtml, contains('SURAT KETERANGAN SAKIT'));
      expect(sakitHtml, contains('3 hari'));
      expect(sakitHtml, contains('Izin tidak masuk kerja'));
    });
  });
}
