import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mapotech/features/landing/landing_page_data.dart';
import 'package:mapotech/shared/letter_models.dart';
import 'package:mapotech/shared/letter_printer.dart';
import 'package:mapotech/shared/supabase_service.dart';
import 'package:mapotech/shared/widgets/custom_button.dart';
import 'package:mapotech/shared/widgets/custom_lazy_loader.dart';
import 'package:mapotech/shared/widgets/custom_snackbar.dart';
import 'package:mapotech/shared/widgets/letter_verification_page.dart';
import 'package:mapotech/shared/widgets/skeleton_loading.dart';
import 'package:mapotech/shared/widgets/status_badge.dart';
import 'package:mapotech/shared/l10n/app_translations.dart';

/// Unified preview & A4 print dialog for Surat Rujukan, Surat Keterangan Sehat,
/// and Surat Keterangan Sakit matching the Laravel `rujukan_print` template.
class MedicalLetterPreviewDialog extends ConsumerStatefulWidget {
  final MedicalLetterData? initialData;
  final String? encounterId;
  final MedicalLetterType? preferredType;
  final bool maskPatientNik;

  const MedicalLetterPreviewDialog({
    super.key,
    this.initialData,
    this.encounterId,
    this.preferredType,
    this.maskPatientNik = false,
  });

  static Future<void> show(
    BuildContext context, {
    MedicalLetterData? initialData,
    String? encounterId,
    MedicalLetterType? preferredType,
    bool maskPatientNik = false,
  }) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => MedicalLetterPreviewDialog(
        initialData: initialData,
        encounterId: encounterId,
        preferredType: preferredType,
        maskPatientNik: maskPatientNik,
      ),
    );
  }

  @override
  ConsumerState<MedicalLetterPreviewDialog> createState() =>
      _MedicalLetterPreviewDialogState();
}

class _MedicalLetterPreviewDialogState
    extends ConsumerState<MedicalLetterPreviewDialog> {
  final SupabaseService _db = SupabaseService();
  MedicalLetterData? _data;
  bool _isLoading = true;
  bool _isPrinting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (widget.initialData != null && widget.encounterId == null) {
      final initial = widget.initialData!;
      if (initial.doctorId.isNotEmpty &&
          (initial.doctorLicenses.isEmpty ||
              initial.doctorFaskesAddress.isEmpty ||
              initial.doctorFaskesAddress == '-')) {
        final doc = await _db.fetchDoctorPublicHeader(initial.doctorId);
        if (!mounted) return;
        if (doc != null) {
          setState(() {
            _data = _mergeDoctorHeader(initial, doc);
            _isLoading = false;
          });
          return;
        }
      }
      if (mounted) {
        setState(() {
          _data = initial;
          _isLoading = false;
        });
      }
      return;
    }

    final encId = widget.encounterId ?? widget.initialData?.encounterId;
    if (encId != null && encId.isNotEmpty) {
      final fetched = await _db.fetchMedicalLetterByEncounterId(
        encId,
        preferredType: widget.preferredType ?? widget.initialData?.type,
      );
      if (!mounted) return;
      if (fetched != null) {
        setState(() {
          _data = fetched;
          _isLoading = false;
        });
        return;
      }
    }

    if (mounted) {
      setState(() {
        _data = widget.initialData;
        _error = widget.initialData == null
            ? 'Data surat medis tidak ditemukan.'
            : null;
        _isLoading = false;
      });
    }
  }

  MedicalLetterData _mergeDoctorHeader(
    MedicalLetterData base,
    Map<String, dynamic> doc,
  ) {
    final addrParts = <String>[];
    for (final key in ['address', 'village', 'district', 'province']) {
      final v = (doc[key] ?? '').toString().trim();
      if (v.isNotEmpty && !addrParts.contains(v)) addrParts.add(v);
    }
    final subDist = (doc['sub_district'] ?? '').toString().trim();
    if (subDist.isNotEmpty && !addrParts.contains(subDist)) {
      addrParts.add('Kec. $subDist');
    }
    return MedicalLetterData(
      encounterId: base.encounterId,
      type: base.type,
      letterNumber: base.letterNumber,
      signedAt: base.signedAt,
      isDraft: base.isDraft,
      currentHash: base.currentHash,
      previousHash: base.previousHash,
      isHashVerified: base.isHashVerified,
      rujukanRumahSakit: base.rujukanRumahSakit,
      rujukanPoli: base.rujukanPoli,
      rujukanCatatan: base.rujukanCatatan,
      suratKeperluan: base.suratKeperluan,
      suratRiwayatPenyakit: base.suratRiwayatPenyakit,
      suratSakitHari: base.suratSakitHari,
      suratSakitMulai: base.suratSakitMulai,
      suratSakitSelesai: base.suratSakitSelesai,
      patientId: base.patientId,
      patientName: base.patientName,
      patientNik: base.patientNik,
      patientGender: base.patientGender,
      patientBirthDate: base.patientBirthDate,
      patientBirthPlace: base.patientBirthPlace,
      patientAgeLabel: base.patientAgeLabel,
      patientAddress: base.patientAddress,
      complaint: base.complaint,
      anamnesis: base.anamnesis,
      bloodPressure: base.bloodPressure,
      temperature: base.temperature,
      heartRate: base.heartRate,
      respiration: base.respiration,
      weight: base.weight,
      height: base.height,
      spo2: base.spo2,
      diagnoses: base.diagnoses,
      doctorId: base.doctorId,
      doctorName: (doc['name'] ?? base.doctorName).toString(),
      doctorAvatarUrl: doc['avatar_url']?.toString() ?? base.doctorAvatarUrl,
      doctorProfession:
          (doc['profession'] ?? base.doctorProfession).toString(),
      doctorFaskesName:
          (doc['nama_faskes'] ?? base.doctorFaskesName).toString(),
      doctorFaskesAddress:
          addrParts.isNotEmpty ? addrParts.join(', ') : base.doctorFaskesAddress,
      doctorAddress: (doc['address'] ?? base.doctorAddress).toString(),
      doctorPhone: (doc['whatsapp_number'] ?? base.doctorPhone).toString(),
      doctorWhatsapp:
          (doc['whatsapp_number'] ?? base.doctorWhatsapp).toString(),
      doctorAbout: (doc['about'] ?? base.doctorAbout).toString(),
      doctorMapsLink:
          (doc['google_maps_link'] ?? base.doctorMapsLink).toString(),
      doctorLatitude: doc['latitude'] ?? base.doctorLatitude,
      doctorLongitude: doc['longitude'] ?? base.doctorLongitude,
      doctorQrToken: (doc['qr_token'] ?? base.doctorQrToken).toString(),
      doctorLicenses: base.doctorLicenses.isNotEmpty
          ? base.doctorLicenses
          : MedicalLetterData.parseLicenses(doc['practice_licenses']),
      doctorSchedules: base.doctorSchedules,
    );
  }

  Future<void> _handlePrint(MedicalLetterData data, bool isEn) async {
    setState(() => _isPrinting = true);
    final printed = await printMedicalLetter(data);
    if (!mounted) return;
    setState(() => _isPrinting = false);
    if (printed) {
      CustomSnackbar.success(
        context,
        isEn
            ? 'Print / Save PDF dialog opened.'
            : 'Dialog Cetak / Simpan PDF dibuka.',
      );
    } else {
      CustomSnackbar.info(
        context,
        isEn
            ? 'Direct browser print is available on Web builds.'
            : 'Cetak langsung tersedia pada versi Web browser.',
      );
    }
  }

  void _openVerificationModal(MedicalLetterData data) {
    final encId = data.encounterId;
    if (encId == null || encId.isEmpty || data.isDraft) return;
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: SizedBox(
          width: 1060,
          height: MediaQuery.of(context).size.height * 0.9,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: LetterVerificationPage(
              encounterId: encId,
              expectedType: data.type,
              isEmbeddedModal: true,
              onBackToPortal: () => Navigator.of(context).pop(),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(landingPageProvider);
    final isEn = ref.watch(isEnglishProvider);
    final isDark = state.appearance == 'dark';
    final isRev = state.appearance == 'rev';
    final activeGreen = isRev
        ? const Color(0xFFB577F2)
        : const Color(0xFF10B981);
    final headerBg = isDark ? const Color(0xFF161619) : Colors.white;
    final sheetBg = isDark ? const Color(0xFF0E1117) : const Color(0xFFF1F5F9);
    final textCol = isDark ? Colors.white : const Color(0xFF1B0C3C);
    final borderCol =
        isDark ? const Color(0xFF252528) : const Color(0xFFE2E8F0);

    final data = _data;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Container(
        width: 820,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.92,
        ),
        decoration: BoxDecoration(
          color: sheetBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderCol),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            // Top Control Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: headerBg,
                border: Border(bottom: BorderSide(color: borderCol)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: activeGreen.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.assignment_turned_in_rounded,
                      color: activeGreen,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data != null
                              ? '${data.type.documentTitle(isEn: isEn)} — ${data.patientName}'
                              : (isEn ? 'Medical Document' : 'Dokumen Medis'),
                          style: GoogleFonts.outfit(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w900,
                            color: textCol,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (data != null)
                          Text(
                            '${data.letterNumber} • ${data.formattedSignedDateTime(lang: state.language)}',
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              color: isDark
                                  ? Colors.grey[400]
                                  : const Color(0xFF64748B),
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  if (data != null)
                    Flexible(
                      flex: 0,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            StatusBadge(
                              label: data.isDraft
                                  ? (isEn ? 'Draft' : 'Draft')
                                  : (isEn ? 'QR Signed' : 'TTD QR Sah'),
                              color: data.isDraft ? Colors.orange : activeGreen,
                            ),
                            const SizedBox(width: 8),
                            if (!data.isDraft && data.verificationUrl != null) ...[
                              Tooltip(
                                message: isEn
                                    ? 'Copy Verification URL'
                                    : 'Salin Link Verifikasi',
                                child: IconButton(
                                  icon: Icon(
                                    Icons.link_rounded,
                                    size: 18,
                                    color: textCol,
                                  ),
                                  onPressed: () {
                                    Clipboard.setData(
                                      ClipboardData(
                                          text: data.verificationUrl!),
                                    );
                                    CustomSnackbar.success(
                                      context,
                                      isEn
                                          ? 'Verification link copied!'
                                          : 'Link verifikasi QR berhasil disalin!',
                                    );
                                  },
                                ),
                              ),
                              CustomButton(
                                text: isEn ? 'Verify Web' : 'Web Verifikasi',
                                icon: Icons.verified_user_outlined,
                                isSecondary: true,
                                borderColor: activeGreen,
                                textColor: activeGreen,
                                height: 36,
                                onPressed: () => _openVerificationModal(data),
                              ),
                              const SizedBox(width: 8),
                            ],
                            CustomButton(
                              text: _isPrinting
                                  ? (isEn ? 'Printing...' : 'Mencetak...')
                                  : (isEn ? 'Print / PDF' : 'Cetak / PDF'),
                              icon: Icons.print_rounded,
                              primaryColor: activeGreen,
                              height: 36,
                              onPressed: _isPrinting
                                  ? null
                                  : () => _handlePrint(data, isEn),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: Icon(Icons.close_rounded, size: 20, color: textCol),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Body
            Expanded(
              child: CustomLazyLoader(
                isLoading: _isLoading,
                loadingText: isEn
                    ? 'Preparing official document template...'
                    : 'Menyiapkan template surat resmi...',
                loadingSubtext: isEn
                    ? 'Generating digital signature QR code...'
                    : 'Membuat QR Code tanda tangan digital...',
                skeleton: const Padding(
                  padding: EdgeInsets.all(24),
                  child: SkeletonGenericPage(),
                ),
                child: _error != null || data == null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            _error ??
                                (isEn
                                    ? 'Unable to load document.'
                                    : 'Gagal memuat dokumen.'),
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.redAccent,
                            ),
                          ),
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: _PaperLetterSheet(
                            data: data,
                            accent: activeGreen,
                            maskPatientNik: widget.maskPatientNik,
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaperLetterSheet extends StatelessWidget {
  final MedicalLetterData data;
  final Color accent;
  final bool maskPatientNik;

  const _PaperLetterSheet({
    required this.data,
    required this.accent,
    this.maskPatientNik = false,
  });

  @override
  Widget build(BuildContext context) {
    const paperText = Color(0xFF1E293B);
    const paperSub = Color(0xFF475569);
    const emerald = Color(0xFF10B981);

    final qrPayload = data.verificationUrl ??
        '${MedicalLetterVerificationRequest.resolveWebOrigin()}/?preview=${data.type.routeSlug}';

    return Container(
      width: 720,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Kop Surat (matches rujukan_print.blade.php)
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: emerald.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: emerald.withValues(alpha: 0.25)),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.local_hospital_rounded,
                  color: emerald,
                  size: 30,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      data.displayFaskesHeader,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      data.displayPracticeAddress,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: paperSub,
                      ),
                    ),
                    Text(
                      'Telepon: ${data.doctorPhone}',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: paperSub,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 54,
                height: 54,
                child: (data.doctorAvatarUrl != null &&
                        data.doctorAvatarUrl!.trim().isNotEmpty)
                    ? ClipOval(
                        child: Image.network(
                          data.doctorAvatarUrl!.trim(),
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const SizedBox.shrink(),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),

          // Double Separator
          const SizedBox(height: 12),
          const Divider(color: Colors.black, height: 1, thickness: 2),
          const SizedBox(height: 2),
          const Divider(color: Colors.black, height: 1, thickness: 0.7),
          const SizedBox(height: 16),

          // Title & Number
          Center(
            child: Column(
              children: [
                Text(
                  data.type.documentTitle(),
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF0F172A),
                    decoration: TextDecoration.underline,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Nomor: ${data.letterNumber}',
                  style: GoogleFonts.robotoMono(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: paperSub,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Body by Letter Type
          if (data.type == MedicalLetterType.rujukan) ...[
            _row('Kepada Yth. Sejawat Dokter Di', data.rujukanRumahSakit,
                bold: true),
            _row('Poli / Bagian', data.rujukanPoli),
            const SizedBox(height: 10),
            Text(
              'Mohon pemeriksaan dan penanganan lebih lanjut terhadap pasien berikut:',
              style: GoogleFonts.outfit(fontSize: 9.5, color: paperText),
            ),
            const SizedBox(height: 12),
            _sectionTitle('Identitas Pasien', emerald),
            _row('Nama Pasien', data.patientName, bold: true),
            _row('Nomor Rekam Medis (RM)', data.patientId),
            _row(
              'Nomor NIK',
              maskPatientNik ? data.maskedNik : data.patientNik,
            ),
            _row('Jenis Kelamin', data.normalizedGenderId),
            _row(
              'Tanggal Lahir',
              '${data.patientBirthDate} (Usia: ${data.patientAgeLabel})',
            ),
            _row('Alamat', data.patientAddress),
            const SizedBox(height: 12),
            _sectionTitle('Hasil Pemeriksaan Klinis', emerald),
            _vitalsGrid(),
            const SizedBox(height: 10),
            _row(
              'Keluhan / Anamnesis',
              data.anamnesis.trim().isNotEmpty && data.anamnesis != '-'
                  ? data.anamnesis
                  : data.complaint,
            ),
            _row(
              'Diagnosa Kerja / ICD-10',
              data.diagnoses.isEmpty
                  ? '-'
                  : data.diagnoses
                      .map((d) => '${d['code']} - ${d['description']}')
                      .join('\n'),
            ),
            if (data.rujukanCatatan.trim().isNotEmpty)
              _row('Catatan Rujukan / Terapi', data.rujukanCatatan),
            const SizedBox(height: 14),
            Text(
              'Demikian surat rujukan ini kami sampaikan, atas kerja samanya kami ucapkan terima kasih.',
              style: GoogleFonts.outfit(fontSize: 9.5, color: paperText),
            ),
          ] else ...[
            Text(
              'Yang bertanda tangan di bawah ini:',
              style: GoogleFonts.outfit(fontSize: 9.5, color: paperText),
            ),
            const SizedBox(height: 6),
            _row('Nama Dokter', data.displayDoctorName, bold: true),
            _row('Jabatan / Profesi', data.doctorProfession),
            _row('Faskes Praktik', data.doctorFaskesName),
            const SizedBox(height: 12),
            Text(
              'Menerangkan dengan sesungguhnya bahwa penderita dengan identitas:',
              style: GoogleFonts.outfit(fontSize: 9.5, color: paperText),
            ),
            const SizedBox(height: 8),
            _sectionTitle('Identitas Pasien', emerald),
            _row('Nama Pasien', data.patientName, bold: true),
            _row('Nomor Rekam Medis (RM)', data.patientId),
            _row(
              'Nomor NIK',
              maskPatientNik ? data.maskedNik : data.patientNik,
            ),
            _row(
              'Umur / Jenis Kelamin',
              '${data.patientAgeLabel} / ${data.normalizedGenderId}',
            ),
            _row('Alamat', data.patientAddress),
            const SizedBox(height: 12),
            Text(
              data.type == MedicalLetterType.suratSehat
                  ? 'Pada tanggal : ${AppTranslations.formatDate(data.signedAt.toLocal(), lang: 'id', includeDay: true)} telah diperiksa kesehatannya dan dinyatakan BERBADAN SEHAT baik jasmani maupun rohaninya.'
                  : 'Pada tanggal : ${AppTranslations.formatDate(data.signedAt.toLocal(), lang: 'id', includeDay: true)} telah diperiksa kesehatannya dan dinyatakan dalam keadaan KURANG SEHAT / SAKIT sehingga memerlukan istirahat selama ${data.suratSakitHari} hari, terhitung mulai tanggal ${MedicalLetterData.formatSimpleDate(data.suratSakitMulai)} s/d ${MedicalLetterData.formatSimpleDate(data.suratSakitSelesai)}.',
              style: GoogleFonts.outfit(
                fontSize: 10,
                height: 1.55,
                color: paperText,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            _row('Keperluan', data.suratKeperluan),
            const SizedBox(height: 10),
            _sectionTitle('Pemeriksaan Fisik & Klinis', emerald),
            _vitalsGrid(compact: true),
            const SizedBox(height: 6),
            _row(
              'Riwayat Penyakit Dahulu',
              data.suratRiwayatPenyakit.trim().isEmpty
                  ? 'Tidak Ada'
                  : data.suratRiwayatPenyakit,
            ),
            const SizedBox(height: 14),
            Text(
              'Demikian surat keterangan ini dibuat dengan sebenarnya untuk dipergunakan sebagaimana mestinya.',
              style: GoogleFonts.outfit(fontSize: 9.5, color: paperText),
            ),
          ],

          // Signature Footer with Scannable QR Code
          const SizedBox(height: 26),
          Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: 240,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    '${data.cityLabel}, ${data.formattedSignedDate(lang: 'id')}',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: paperText,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    data.type == MedicalLetterType.rujukan
                        ? 'Dokter Pengirim,'
                        : 'Dokter Pemeriksa,',
                    style: GoogleFonts.outfit(
                      fontSize: 9.5,
                      color: paperText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: QrImageView(
                      data: qrPayload,
                      version: QrVersions.auto,
                      size: 84,
                      backgroundColor: Colors.white,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: Color(0xFF0F172A),
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    data.isDraft
                        ? 'DRAFT — QR aktif setelah EMR disimpan'
                        : 'Scan QR untuk verifikasi keaslian',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 7.5,
                      fontWeight: FontWeight.w600,
                      color: data.isDraft ? Colors.orange[800] : paperSub,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    data.displayDoctorName,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF0F172A),
                      decoration: TextDecoration.underline,
                    ),
                  ),
                  if (data.primarySip != '-')
                    Text(
                      'SIP: ${data.primarySip}',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 8.5,
                        color: paperSub,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, Color emerald) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        border: Border(left: BorderSide(color: emerald, width: 3)),
      ),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.outfit(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          color: const Color(0xFF1E293B),
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false}) {
    final cleanVal = value.trim().isEmpty ? '-' : value.trim();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 195,
            child: Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF475569),
              ),
            ),
          ),
          Text(
            ':  ',
            style: GoogleFonts.outfit(
              fontSize: 9.5,
              color: const Color(0xFF475569),
            ),
          ),
          Expanded(
            child: Text(
              cleanVal,
              style: GoogleFonts.outfit(
                fontSize: 9.5,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
                color: const Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _vitalsGrid({bool compact = false}) {
    final items = <(String, String)>[
      ('Tekanan Darah', '${data.bloodPressure.isEmpty ? '-' : data.bloodPressure} mmHg'),
      ('Nadi', '${data.heartRate.isEmpty ? '-' : data.heartRate} bpm'),
      ('Suhu Tubuh', '${data.temperature.isEmpty ? '-' : data.temperature} °C'),
      if (!compact) ...[
        ('Nafas', '${data.respiration.isEmpty ? '-' : data.respiration} x/mnt'),
        ('Berat Badan', '${data.weight.isEmpty ? '-' : data.weight} kg'),
        ('Tinggi Badan', '${data.height.isEmpty ? '-' : data.height} cm'),
        ('Saturasi O2', '${data.spo2.isEmpty ? '-' : data.spo2} %'),
      ] else
        (
          'Berat / Tinggi',
          '${data.weight.isEmpty ? '-' : data.weight} kg / ${data.height.isEmpty ? '-' : data.height} cm'
        ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Wrap(
        spacing: 18,
        runSpacing: 10,
        children: items
            .map(
              (item) => SizedBox(
                width: 132,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.$1.toUpperCase(),
                      style: GoogleFonts.outfit(
                        fontSize: 7.5,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      item.$2,
                      style: GoogleFonts.outfit(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}
