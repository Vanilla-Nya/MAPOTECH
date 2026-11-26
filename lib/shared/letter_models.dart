import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mapotech/shared/l10n/app_translations.dart';

enum MedicalLetterType { rujukan, suratSehat, suratSakit }

extension MedicalLetterTypeX on MedicalLetterType {
  String get routeSlug {
    switch (this) {
      case MedicalLetterType.rujukan:
        return 'rujukan';
      case MedicalLetterType.suratSehat:
        return 'surat-sehat';
      case MedicalLetterType.suratSakit:
        return 'surat-sakit';
    }
  }

  String documentTitle({bool isEn = false}) {
    switch (this) {
      case MedicalLetterType.rujukan:
        return isEn ? 'PATIENT REFERRAL LETTER' : 'SURAT RUJUKAN PASIEN';
      case MedicalLetterType.suratSehat:
        return isEn ? 'MEDICAL HEALTH CERTIFICATE' : 'SURAT KETERANGAN SEHAT';
      case MedicalLetterType.suratSakit:
        return isEn ? 'MEDICAL SICK LEAVE CERTIFICATE' : 'SURAT KETERANGAN SAKIT';
    }
  }

  String verificationTitle({bool isEn = false}) {
    switch (this) {
      case MedicalLetterType.rujukan:
        return isEn ? 'Referral Letter Verification' : 'Verifikasi Surat Rujukan';
      case MedicalLetterType.suratSehat:
        return isEn
            ? 'Health Certificate Verification'
            : 'Verifikasi Surat Keterangan Sehat';
      case MedicalLetterType.suratSakit:
        return isEn
            ? 'Sick Leave Verification'
            : 'Verifikasi Surat Keterangan Sakit';
    }
  }
}

class MedicalLetterVerificationRequest {
  final String encounterId;
  final MedicalLetterType? expectedType;

  const MedicalLetterVerificationRequest({
    required this.encounterId,
    this.expectedType,
  });

  static const String defaultProductionOrigin = 'https://mapotek.relvastudio.com';

  static String resolveWebOrigin({String? originOverride}) {
    if (originOverride != null && originOverride.trim().isNotEmpty) {
      final cleaned = originOverride.trim();
      return cleaned.endsWith('/')
          ? cleaned.substring(0, cleaned.length - 1)
          : cleaned;
    }
    if (kIsWeb) {
      final base = Uri.base;
      if (base.scheme == 'http' || base.scheme == 'https') {
        return base.origin;
      }
    }
    return defaultProductionOrigin;
  }

  /// Generates the verification URL encoded inside the letter's signature QR code.
  static String buildVerificationUrl({
    required String encounterId,
    required MedicalLetterType type,
    String? originOverride,
  }) {
    final origin = resolveWebOrigin(originOverride: originOverride);
    return '$origin/?verify=${type.routeSlug}&id=${Uri.encodeComponent(encounterId)}';
  }

  static MedicalLetterType? _parseType(String? raw) {
    final value = (raw ?? '').trim().toLowerCase();
    if (value == 'rujukan' || value == 'referral') {
      return MedicalLetterType.rujukan;
    }
    if (value == 'surat-sehat' || value == 'sehat' || value == 'health') {
      return MedicalLetterType.suratSehat;
    }
    if (value == 'surat-sakit' || value == 'sakit' || value == 'sick') {
      return MedicalLetterType.suratSakit;
    }
    return null;
  }

  static bool _isValidEncounterId(String id) {
    final clean = id.trim();
    if (clean.isEmpty) return false;
    final lower = clean.toLowerCase();
    return lower != 'preview' && lower != 'mock' && lower != 'draft';
  }

  /// Parses incoming web URLs in query format (`?verify=rujukan&id=...`),
  /// path format (`/rujukan/{id}/verifikasi`, `/surat/{id}/verifikasi`),
  /// or hash fragment format (`#/rujukan/{id}/verifikasi`).
  static MedicalLetterVerificationRequest? parseUri(Uri uri) {
    final fromMain = _parseSingleUri(uri);
    if (fromMain != null) return fromMain;

    if (uri.fragment.isNotEmpty) {
      final frag = uri.fragment.startsWith('/')
          ? uri.fragment
          : '/${uri.fragment}';
      final fragUri = Uri.tryParse(frag);
      if (fragUri != null) {
        return _parseSingleUri(fragUri);
      }
    }
    return null;
  }

  static MedicalLetterVerificationRequest? _parseSingleUri(Uri uri) {
    final verifyParam = uri.queryParameters['verify'];
    final idParam =
        uri.queryParameters['id'] ?? uri.queryParameters['encounter_id'];
    if (verifyParam != null && idParam != null && _isValidEncounterId(idParam)) {
      return MedicalLetterVerificationRequest(
        encounterId: idParam.trim(),
        expectedType: _parseType(verifyParam) ??
            _parseType(uri.queryParameters['type']),
      );
    }

    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.length >= 2) {
      final first = segments[0].toLowerCase();
      final second = segments[1];
      if ((first == 'rujukan' ||
              first == 'surat' ||
              first == 'surat-sehat' ||
              first == 'surat-sakit') &&
          _isValidEncounterId(second)) {
        final hasSuffix = segments.length == 2 ||
            (segments.length >= 3 &&
                (segments[2].toLowerCase() == 'verifikasi' ||
                    segments[2].toLowerCase() == 'verify'));
        if (hasSuffix) {
          return MedicalLetterVerificationRequest(
            encounterId: second.trim(),
            expectedType: _parseType(first) ??
                _parseType(uri.queryParameters['type']),
          );
        }
      }
    }
    return null;
  }
}

class MedicalLetterData {
  final String? encounterId;
  final MedicalLetterType type;
  final String letterNumber;
  final DateTime signedAt;
  final bool isDraft;

  // Hash chain metadata
  final String? currentHash;
  final String? previousHash;
  final bool isHashVerified;

  // Referral details
  final String rujukanRumahSakit;
  final String rujukanPoli;
  final String rujukanCatatan;

  // Certificate details
  final String suratKeperluan;
  final String suratRiwayatPenyakit;
  final int suratSakitHari;
  final DateTime? suratSakitMulai;
  final DateTime? suratSakitSelesai;

  // Patient details
  final String patientId;
  final String patientName;
  final String patientNik;
  final String patientGender;
  final String patientBirthDate;
  final String patientBirthPlace;
  final String patientAgeLabel;
  final String patientAddress;

  // Clinical exam details
  final String complaint;
  final String anamnesis;
  final String bloodPressure;
  final String temperature;
  final String heartRate;
  final String respiration;
  final String weight;
  final String height;
  final String spo2;
  final List<Map<String, String>> diagnoses;

  // Doctor profile details
  final String doctorId;
  final String doctorName;
  final String? doctorAvatarUrl;
  final String doctorProfession;
  final String doctorFaskesName;
  final String doctorFaskesAddress;
  final String doctorAddress;
  final String doctorPhone;
  final String doctorWhatsapp;
  final String doctorAbout;
  final String doctorMapsLink;
  final dynamic doctorLatitude;
  final dynamic doctorLongitude;
  final String doctorQrToken;
  final List<String> doctorLicenses;
  final List<Map<String, dynamic>> doctorSchedules;

  const MedicalLetterData({
    required this.encounterId,
    required this.type,
    required this.letterNumber,
    required this.signedAt,
    this.isDraft = false,
    this.currentHash,
    this.previousHash,
    this.isHashVerified = false,
    this.rujukanRumahSakit = '',
    this.rujukanPoli = '',
    this.rujukanCatatan = '',
    this.suratKeperluan = '',
    this.suratRiwayatPenyakit = '',
    this.suratSakitHari = 3,
    this.suratSakitMulai,
    this.suratSakitSelesai,
    this.patientId = '-',
    required this.patientName,
    this.patientNik = '-',
    this.patientGender = '-',
    this.patientBirthDate = '-',
    this.patientBirthPlace = '',
    this.patientAgeLabel = '-',
    this.patientAddress = '-',
    this.complaint = '-',
    this.anamnesis = '-',
    this.bloodPressure = '',
    this.temperature = '',
    this.heartRate = '',
    this.respiration = '',
    this.weight = '',
    this.height = '',
    this.spo2 = '',
    this.diagnoses = const [],
    required this.doctorId,
    required this.doctorName,
    this.doctorAvatarUrl,
    this.doctorProfession = 'Dokter Praktik Mandiri',
    this.doctorFaskesName = 'Praktik Dokter Mandiri',
    this.doctorFaskesAddress = '',
    this.doctorAddress = '',
    this.doctorPhone = '-',
    this.doctorWhatsapp = '',
    this.doctorAbout = '',
    this.doctorMapsLink = '',
    this.doctorLatitude,
    this.doctorLongitude,
    this.doctorQrToken = '',
    this.doctorLicenses = const [],
    this.doctorSchedules = const [],
  });

  String? get verificationUrl {
    final id = encounterId?.trim();
    if (id == null || id.isEmpty || isDraft) return null;
    return MedicalLetterVerificationRequest.buildVerificationUrl(
      encounterId: id,
      type: type,
    );
  }

  String get displayDoctorName {
    final clean = doctorName.trim();
    if (clean.isEmpty) return 'Dokter';
    return clean;
  }

  String get displayFaskesHeader {
    final faskes = doctorFaskesName.trim();
    if (faskes.isNotEmpty) return faskes.toUpperCase();
    return 'DOKTER PRAKTEK MANDIRI ${displayDoctorName.toUpperCase()}';
  }

  String get displayPracticeAddress {
    if (doctorFaskesAddress.trim().isNotEmpty) {
      return doctorFaskesAddress.trim();
    }
    if (doctorAddress.trim().isNotEmpty) {
      return doctorAddress.trim();
    }
    return '-';
  }

  String get cityLabel {
    final source = displayPracticeAddress;
    if (source.isNotEmpty && source != '-') {
      final firstPart = source.split(',').first.trim();
      if (firstPart.isNotEmpty) return firstPart;
    }
    return 'Bondowoso';
  }

  String get primarySip {
    if (doctorLicenses.isEmpty) return '-';
    for (final raw in doctorLicenses) {
      final clean = raw.trim();
      if (clean.isNotEmpty) return clean;
    }
    return '-';
  }

  String get maskedNik {
    final clean = patientNik.trim();
    if (clean.isEmpty || clean == '-') return '-';
    if (clean.length <= 10) return clean;
    return '${clean.substring(0, 6)}******${clean.substring(clean.length - 4)}';
  }

  String get normalizedGenderId {
    final g = patientGender.trim().toLowerCase();
    if (g == 'male' || g == 'l' || g == 'laki-laki') return 'Laki-laki';
    if (g == 'female' || g == 'p' || g == 'perempuan') return 'Perempuan';
    return patientGender.trim().isEmpty ? '-' : patientGender.trim();
  }

  String formattedSignedDate({String lang = 'id'}) {
    return AppTranslations.formatDate(
      signedAt.toLocal(),
      lang: lang,
      includeDay: false,
    );
  }

  String formattedSignedDateTime({String lang = 'id'}) {
    final local = signedAt.toLocal();
    final datePart = AppTranslations.formatDate(
      local,
      lang: lang,
      includeDay: false,
    );
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$datePart, $hh:$mm WIB';
  }

  static String formatSimpleDate(DateTime? dt, {String lang = 'id'}) {
    if (dt == null) return '-';
    return AppTranslations.formatDate(dt.toLocal(), lang: lang, includeDay: false);
  }

  static String generateDeterministicCertNumber(
    MedicalLetterType type,
    String? encounterId,
    DateTime date,
  ) {
    final prefix = type == MedicalLetterType.suratSehat ? 'SK-SEHAT' : 'SK-SAKIT';
    final year = date.year;
    final clean = (encounterId ?? '').replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    final suffix = clean.length >= 4
        ? clean.substring(0, 4).toUpperCase()
        : 'DRFT';
    return '$prefix/$year/$suffix';
  }

  /// Extracts readable license / SIP strings from both Flutter `List<String>`
  /// and Laravel `List<Map<String, dynamic>>` representations.
  static List<String> parseLicenses(dynamic rawLicenses) {
    if (rawLicenses is! List) return const [];
    final results = <String>[];
    for (final item in rawLicenses) {
      if (item is Map) {
        final val = (item['url'] ?? item['number'] ?? item['type'] ?? '')
            .toString()
            .trim();
        if (val.isNotEmpty) results.add(val);
      } else if (item != null) {
        final text = item.toString().trim();
        if (text.isNotEmpty) results.add(text);
      }
    }
    return results;
  }

  Map<String, dynamic> toDoctorDetailMap() {
    return {
      'id': doctorId,
      'name': doctorName,
      'avatar_url': doctorAvatarUrl,
      'nama_faskes': doctorFaskesName,
      'profession': doctorProfession,
      'about': doctorAbout,
      'whatsapp_number': doctorWhatsapp.isNotEmpty ? doctorWhatsapp : doctorPhone,
      'address': displayPracticeAddress,
      'practice_licenses': doctorLicenses,
      'google_maps_link': doctorMapsLink,
      'latitude': doctorLatitude,
      'longitude': doctorLongitude,
      'qr_token': doctorQrToken,
      'is_visible': true,
      'is_bpjs': false,
    };
  }

  /// Renders a crisp inline vector SVG QR code without requiring external image requests.
  static String buildQrSvg(String data, {double sizePx = 88}) {
    final qrCode = QrCode.fromData(
      data: data,
      errorCorrectLevel: QrErrorCorrectLevel.M,
    );
    final qrImage = QrImage(qrCode);
    final count = qrImage.moduleCount;
    final buffer = StringBuffer();
    buffer.write(
      '<svg xmlns="http://www.w3.org/2000/svg" '
      'width="${sizePx.toInt()}" height="${sizePx.toInt()}" '
      'viewBox="-2 -2 ${count + 4} ${count + 4}" '
      'shape-rendering="crispEdges">'
      '<rect x="-2" y="-2" width="${count + 4}" height="${count + 4}" fill="#ffffff"/>'
      '<path fill="#0f172a" d="',
    );
    for (var r = 0; r < count; r++) {
      for (var c = 0; c < count; c++) {
        if (qrImage.isDark(r, c)) {
          buffer.write('M$c,${r}h1v1h-1z');
        }
      }
    }
    buffer.write('"/></svg>');
    return buffer.toString();
  }

  /// Builds self-contained A4 HTML matching Laravel's `rujukan_print.blade.php` template
  /// for Referral, Health Certificate, and Sick Leave Certificate.
  static String buildPrintableHtml(
    MedicalLetterData data, {
    bool showPrintBar = false,
  }) {
    const esc = HtmlEscape();
    String e(String val) => esc.convert(val.isEmpty ? '-' : val);

    final qrTarget = data.verificationUrl ??
        '${MedicalLetterVerificationRequest.resolveWebOrigin()}/?preview=${data.type.routeSlug}';
    final qrSvg = buildQrSvg(qrTarget, sizePx: 84);
    final signedDateStr = data.formattedSignedDate(lang: 'id');
    final signedDateFull = AppTranslations.formatDate(
      data.signedAt.toLocal(),
      lang: 'id',
      includeDay: true,
    );
    final sipDisplay = data.primarySip;

    final avatarHtml = (data.doctorAvatarUrl != null &&
            data.doctorAvatarUrl!.trim().isNotEmpty)
        ? '<img src="${esc.convert(data.doctorAvatarUrl!.trim())}" alt="Doctor" style="width:52px;height:52px;object-fit:cover;border-radius:50%;border:1px solid #cbd5e1;" />'
        : '';

    final logoSvg = '''
<div style="width:58px;height:58px;border-radius:10px;background:#ecfdf5;border:1px solid #a7f3d0;display:flex;align-items:center;justify-content:center;">
  <svg width="30" height="30" viewBox="0 0 24 24" fill="none">
    <path d="M12 5v14M5 12h14" stroke="#10b981" stroke-width="3" stroke-linecap="round"/>
  </svg>
</div>
''';

    final bodyHtml = StringBuffer();

    if (data.type == MedicalLetterType.rujukan) {
      final diagHtml = data.diagnoses.isNotEmpty
          ? '<ul class="diagnosis-list">${data.diagnoses.map((d) => '<li><strong>${e(d['code'] ?? '')}</strong> - ${e(d['description'] ?? '')}</li>').join()}</ul>'
          : '-';

      final anamnesisText = data.anamnesis.trim().isNotEmpty && data.anamnesis != '-'
          ? data.anamnesis
          : data.complaint;

      bodyHtml.write('''
        <table class="info-table">
          <tr>
            <td class="label">Kepada Yth. Sejawat Dokter Di</td>
            <td class="separator">:</td>
            <td style="font-weight:bold;">${e(data.rujukanRumahSakit)}</td>
          </tr>
          <tr>
            <td class="label">Poli / Bagian</td>
            <td class="separator">:</td>
            <td>${e(data.rujukanPoli)}</td>
          </tr>
        </table>

        <p style="font-size:9pt;margin:8px 0;">Mohon pemeriksaan dan penanganan lebih lanjut terhadap pasien berikut:</p>

        <div class="section-title">Identitas Pasien</div>
        <table class="info-table">
          <tr><td class="label">Nama Pasien</td><td class="separator">:</td><td style="font-weight:bold;">${e(data.patientName)}</td></tr>
          <tr><td class="label">Nomor Rekam Medis (RM)</td><td class="separator">:</td><td>${e(data.patientId)}</td></tr>
          <tr><td class="label">Nomor NIK</td><td class="separator">:</td><td>${e(data.patientNik)}</td></tr>
          <tr><td class="label">Jenis Kelamin</td><td class="separator">:</td><td>${e(data.normalizedGenderId)}</td></tr>
          <tr><td class="label">Tanggal Lahir</td><td class="separator">:</td><td>${e(data.patientBirthDate)} (Usia: ${e(data.patientAgeLabel)})</td></tr>
          <tr><td class="label">Alamat</td><td class="separator">:</td><td>${e(data.patientAddress)}</td></tr>
        </table>

        <div class="section-title">Hasil Pemeriksaan Klinis</div>
        <div class="vitals-grid">
          <div class="vital-item"><span>Tekanan Darah</span>${e(data.bloodPressure)} mmHg</div>
          <div class="vital-item"><span>Suhu Tubuh</span>${e(data.temperature)} &deg;C</div>
          <div class="vital-item"><span>Detak Jantung</span>${e(data.heartRate)} bpm</div>
          <div class="vital-item"><span>Nafas</span>${e(data.respiration)} x/mnt</div>
          <div class="vital-item"><span>Berat Badan</span>${e(data.weight)} kg</div>
          <div class="vital-item"><span>Tinggi Badan</span>${e(data.height)} cm</div>
          <div class="vital-item"><span>Saturasi O2</span>${e(data.spo2)} %</div>
        </div>

        <table class="info-table">
          <tr><td class="label">Keluhan / Anamnesis</td><td class="separator">:</td><td>${e(anamnesisText)}</td></tr>
          <tr><td class="label">Diagnosa Kerja / ICD-10</td><td class="separator">:</td><td>$diagHtml</td></tr>
          ${data.rujukanCatatan.trim().isNotEmpty ? '<tr><td class="label">Catatan Rujukan / Terapi</td><td class="separator">:</td><td>${e(data.rujukanCatatan)}</td></tr>' : ''}
        </table>

        <p style="font-size:9pt;margin:10px 0;">Demikian surat rujukan ini kami sampaikan, atas kerja samanya kami ucapkan terima kasih.</p>
      ''');
    } else {
      final isSehat = data.type == MedicalLetterType.suratSehat;
      final statementText = isSehat
          ? 'Pada tanggal : <strong>${e(signedDateFull)}</strong> telah diperiksa kesehatannya dan dinyatakan <strong>berbadan sehat</strong> baik jasmani maupun rohaninya.'
          : 'Pada tanggal : <strong>${e(signedDateFull)}</strong> telah diperiksa kesehatannya dan dinyatakan dalam keadaan <strong>kurang sehat / sakit</strong> sehingga memerlukan istirahat selama <strong>${data.suratSakitHari} hari</strong>, terhitung mulai tanggal <strong>${e(formatSimpleDate(data.suratSakitMulai))}</strong> s/d <strong>${e(formatSimpleDate(data.suratSakitSelesai))}</strong>.';

      bodyHtml.write('''
        <p style="font-size:9pt;margin:8px 0;">Yang bertanda tangan di bawah ini:</p>
        <table class="info-table">
          <tr><td class="label">Nama Dokter</td><td class="separator">:</td><td style="font-weight:bold;">${e(data.displayDoctorName)}</td></tr>
          <tr><td class="label">Jabatan / Profesi</td><td class="separator">:</td><td>${e(data.doctorProfession)}</td></tr>
          <tr><td class="label">Faskes Praktik</td><td class="separator">:</td><td>${e(data.doctorFaskesName)}</td></tr>
        </table>

        <p style="font-size:9pt;margin:10px 0 6px 0;">Menerangkan dengan sesungguhnya bahwa penderita dengan identitas:</p>
        <div class="section-title">Identitas Pasien</div>
        <table class="info-table">
          <tr><td class="label">Nama Pasien</td><td class="separator">:</td><td style="font-weight:bold;">${e(data.patientName)}</td></tr>
          <tr><td class="label">Nomor Rekam Medis (RM)</td><td class="separator">:</td><td>${e(data.patientId)}</td></tr>
          <tr><td class="label">Nomor NIK</td><td class="separator">:</td><td>${e(data.patientNik)}</td></tr>
          <tr><td class="label">Umur / Jenis Kelamin</td><td class="separator">:</td><td>${e(data.patientAgeLabel)} / ${e(data.normalizedGenderId)}</td></tr>
          <tr><td class="label">Alamat</td><td class="separator">:</td><td>${e(data.patientAddress)}</td></tr>
        </table>

        <p style="font-size:9.5pt;line-height:1.55;margin:12px 0;">$statementText</p>

        <table class="info-table">
          <tr><td class="label">Keperluan</td><td class="separator">:</td><td>${e(data.suratKeperluan)}</td></tr>
        </table>

        <div class="section-title">Pemeriksaan Fisik &amp; Klinis</div>
        <div class="vitals-grid">
          <div class="vital-item"><span>Tekanan Darah</span>${e(data.bloodPressure)} mmHg</div>
          <div class="vital-item"><span>Nadi</span>${e(data.heartRate)} x/mnt</div>
          <div class="vital-item"><span>Suhu Tubuh</span>${e(data.temperature)} &deg;C</div>
          <div class="vital-item"><span>Berat / Tinggi</span>${e(data.weight)} kg / ${e(data.height)} cm</div>
        </div>
        <table class="info-table">
          <tr><td class="label">Riwayat Penyakit Dahulu</td><td class="separator">:</td><td>${e(data.suratRiwayatPenyakit.trim().isEmpty ? 'Tidak Ada' : data.suratRiwayatPenyakit)}</td></tr>
        </table>

        <p style="font-size:9pt;margin:10px 0;">Demikian surat keterangan ini dibuat dengan sebenarnya untuk dipergunakan sebagaimana mestinya.</p>
      ''');
    }

    final signerRoleLabel = data.type == MedicalLetterType.rujukan
        ? 'Dokter Pengirim,'
        : 'Dokter Pemeriksa,';

    final draftWarningHtml = data.isDraft
        ? '<p style="font-size:7.5pt;color:#b45309;margin:2px 0 0 0;">[DRAFT - Belum Tersimpan]</p>'
        : '<p style="font-size:7pt;color:#64748b;margin:2px 0 0 0;">Scan QR untuk verifikasi keaslian</p>';

    final printBarHtml = showPrintBar
        ? '<div class="btn-print-container"><button class="btn-print" onclick="window.print()">Cetak Dokumen</button></div>'
        : '';

    return '''
<!DOCTYPE html>
<html lang="id">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>${e(data.type.documentTitle())} - ${e(data.patientName)}</title>
  <style>
    body {
      font-family: Arial, Helvetica, sans-serif;
      color: #222;
      line-height: 1.4;
      margin: 0;
      padding: 15px;
      background-color: #f1f5f9;
      -webkit-print-color-adjust: exact;
      print-color-adjust: exact;
    }
    .page {
      max-width: 800px;
      margin: 0 auto;
      border: 1px solid #e2e8f0;
      padding: 40px;
      background-color: #fff;
      box-shadow: 0 10px 15px -3px rgba(0,0,0,0.05), 0 4px 6px -2px rgba(0,0,0,0.03);
      position: relative;
      box-sizing: border-box;
    }
    .header {
      border-bottom: 2.5px double #000;
      padding-bottom: 10px;
      margin-bottom: 15px;
    }
    .header-table {
      width: 100%;
      border-collapse: collapse;
    }
    .header-logo {
      width: 70px;
      vertical-align: middle;
    }
    .header-info {
      text-align: center;
      vertical-align: middle;
    }
    .header-info h1 {
      margin: 0 0 4px 0;
      font-size: 13.5pt;
      font-weight: bold;
      text-transform: uppercase;
    }
    .header-info p {
      margin: 2px 0;
      font-size: 9pt;
      color: #444;
    }
    .title-section {
      text-align: center;
      margin-bottom: 15px;
    }
    .title-section h2 {
      margin: 0 0 3px 0;
      font-size: 12pt;
      text-decoration: underline;
      font-weight: bold;
    }
    .title-section p {
      margin: 0;
      font-size: 9pt;
      font-family: monospace;
    }
    .section-title {
      font-size: 9.5pt;
      font-weight: bold;
      background-color: #f3f4f6;
      padding: 4px 8px;
      margin-top: 12px;
      margin-bottom: 8px;
      border-left: 3px solid #10b981;
      text-transform: uppercase;
    }
    .info-table {
      width: 100%;
      border-collapse: collapse;
      margin-bottom: 10px;
    }
    .info-table td {
      padding: 3px 6px;
      font-size: 9pt;
      vertical-align: top;
    }
    .info-table td.label {
      width: 30%;
      font-weight: bold;
      color: #444;
    }
    .info-table td.separator {
      width: 2%;
    }
    .diagnosis-list {
      margin: 0;
      padding-left: 15px;
    }
    .diagnosis-list li {
      margin-bottom: 2px;
      font-size: 9pt;
    }
    .vitals-grid {
      display: grid;
      grid-template-columns: repeat(4, 1fr);
      gap: 8px;
      margin-bottom: 10px;
      padding: 8px;
      border: 1px solid #e5e7eb;
      border-radius: 6px;
      background-color: #fafafa;
    }
    .vital-item {
      font-size: 8.5pt;
    }
    .vital-item span {
      font-weight: bold;
      display: block;
      color: #666;
      font-size: 7.5pt;
      text-transform: uppercase;
      margin-bottom: 1px;
    }
    .footer-section {
      margin-top: 22px;
      width: 100%;
    }
    .signature-table {
      width: 100%;
      border-collapse: collapse;
    }
    .signature-table td {
      font-size: 9pt;
      vertical-align: top;
    }
    .btn-print-container {
      text-align: center;
      margin-bottom: 15px;
    }
    .btn-print {
      background-color: #10b981;
      color: #fff;
      border: none;
      padding: 8px 18px;
      font-size: 9.5pt;
      font-weight: bold;
      border-radius: 6px;
      cursor: pointer;
    }
    @media print {
      @page {
        size: A4;
        margin: 10mm 12mm 10mm 12mm;
      }
      body {
        background-color: #fff;
        padding: 0;
        margin: 0;
        font-size: 9pt;
      }
      .page {
        border: none;
        box-shadow: none;
        padding: 0;
        max-width: 100%;
        width: 100%;
        margin: 0;
      }
      .btn-print-container {
        display: none;
      }
      .vitals-grid {
        background-color: transparent;
      }
      .section-title {
        background-color: #f3f4f6 !important;
      }
    }
  </style>
</head>
<body>
  $printBarHtml
  <div class="page">
    <div class="header">
      <table class="header-table">
        <tr>
          <td class="header-logo">$logoSvg</td>
          <td class="header-info">
            <h1>${e(data.displayFaskesHeader)}</h1>
            <p>${e(data.displayPracticeAddress)}</p>
            <p>Telepon: ${e(data.doctorPhone)}</p>
          </td>
          <td style="width:70px;text-align:right;vertical-align:middle;">$avatarHtml</td>
        </tr>
      </table>
    </div>

    <div class="title-section">
      <h2>${e(data.type.documentTitle())}</h2>
      <p>Nomor: ${e(data.letterNumber)}</p>
    </div>

    ${bodyHtml.toString()}

    <div class="footer-section">
      <table class="signature-table">
        <tr>
          <td style="width:62%;"></td>
          <td style="text-align:center;width:38%;">
            <p style="margin:0 0 2px 0;">${e(data.cityLabel)}, ${e(signedDateStr)}</p>
            <p style="margin:0 0 6px 0;">$signerRoleLabel</p>
            <div style="margin:4px auto;display:inline-block;padding:4px;border:1px solid #e2e8f0;border-radius:6px;background:#fff;">
              $qrSvg
            </div>
            $draftWarningHtml
            <p style="font-weight:bold;text-decoration:underline;margin:6px 0 2px 0;">${e(data.displayDoctorName)}</p>
            ${sipDisplay != '-' ? '<p style="font-size:8pt;color:#555;margin:0;">SIP: ${e(sipDisplay)}</p>' : ''}
          </td>
        </tr>
      </table>
    </div>
  </div>
</body>
</html>
''';
  }
}
