import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mapotech/features/landing/landing_page_data.dart';
import 'package:mapotech/features/pasien/dashboard/frontend/pasien_dokter_search.dart';
import 'package:mapotech/shared/letter_models.dart';
import 'package:mapotech/shared/supabase_service.dart';
import 'package:mapotech/shared/widgets/custom_button.dart';
import 'package:mapotech/shared/widgets/custom_card.dart';
import 'package:mapotech/shared/widgets/custom_lazy_loader.dart';
import 'package:mapotech/shared/widgets/custom_snackbar.dart';
import 'package:mapotech/shared/widgets/medical_letter_preview_dialog.dart';
import 'package:mapotech/shared/widgets/skeleton_loading.dart';
import 'package:mapotech/shared/widgets/status_badge.dart';
import 'package:mapotech/shared/l10n/app_translations.dart';

/// Public web verification page opened when scanning the QR signature on a
/// Referral Letter, Health Certificate, or Sick Leave Certificate.
/// Mirrors Laravel's `rujukan_verify.blade.php` layout & functionality.
class LetterVerificationPage extends ConsumerStatefulWidget {
  final String encounterId;
  final MedicalLetterType? expectedType;
  final VoidCallback? onBackToPortal;
  final bool isEmbeddedModal;

  const LetterVerificationPage({
    super.key,
    required this.encounterId,
    this.expectedType,
    this.onBackToPortal,
    this.isEmbeddedModal = false,
  });

  @override
  ConsumerState<LetterVerificationPage> createState() =>
      _LetterVerificationPageState();
}

class _LetterVerificationPageState
    extends ConsumerState<LetterVerificationPage> {
  final SupabaseService _db = SupabaseService();
  bool _isLoading = true;
  MedicalLetterData? _data;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadVerificationData();
  }

  Future<void> _loadVerificationData() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }
    try {
      final result = await _db.fetchMedicalLetterByEncounterId(
        widget.encounterId,
        preferredType: widget.expectedType,
        forPublicVerification: true,
      );
      if (!mounted) return;
      setState(() {
        _data = result;
        if (result == null) {
          _errorMessage = 'Dokumen surat tidak ditemukan atau ID tidak valid.';
        }
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _openWhatsApp(MedicalLetterData data, bool isEn) async {
    final raw = (data.doctorWhatsapp.isNotEmpty
            ? data.doctorWhatsapp
            : data.doctorPhone)
        .replaceAll(RegExp(r'\D'), '');
    if (raw.isEmpty) {
      CustomSnackbar.warning(
        context,
        isEn
            ? 'Doctor WhatsApp number is not available.'
            : 'Nomor WhatsApp dokter belum tersedia.',
      );
      return;
    }
    var normalized = raw;
    if (normalized.startsWith('0')) {
      normalized = '62${normalized.substring(1)}';
    } else if (normalized.startsWith('8')) {
      normalized = '62$normalized';
    }
    final text = Uri.encodeComponent(
      isEn
          ? 'Hello Dr. ${data.displayDoctorName}, I would like to confirm regarding letter ${data.letterNumber}.'
          : 'Halo Dokter ${data.displayDoctorName}, saya ingin mengonfirmasi surat medis nomor ${data.letterNumber}.',
    );
    final uri = Uri.parse('https://wa.me/$normalized?text=$text');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openGoogleMaps(MedicalLetterData data) async {
    Uri? uri;
    if (data.doctorMapsLink.trim().isNotEmpty) {
      uri = Uri.tryParse(data.doctorMapsLink.trim());
    } else if (data.doctorLatitude != null && data.doctorLongitude != null) {
      uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${data.doctorLatitude},${data.doctorLongitude}',
      );
    }
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _openDoctorBooking(MedicalLetterData data, bool isDark) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (_) => DoctorDetailDialog(
        dokter: data.toDoctorDetailMap(),
        isDark: isDark,
        initialTabIndex: 1,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(landingPageProvider);
    final isEn = ref.watch(isEnglishProvider);
    final isDark = state.appearance == 'dark';
    final isRev = state.appearance == 'rev';
    final emerald = isRev ? const Color(0xFFB577F2) : const Color(0xFF10B981);
    final emeraldDark =
        isRev ? const Color(0xFF8B5CF6) : const Color(0xFF059669);
    final textCol = isDark ? Colors.white : const Color(0xFF0F172A);
    final subCol = isDark ? Colors.grey[400]! : const Color(0xFF475569);
    final borderCol =
        isDark ? const Color(0xFF252528) : const Color(0xFFE2E8F0);
    final cardBg = isDark ? const Color(0xFF161619) : Colors.white;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? const [Color(0xFF0B0E11), Color(0xFF12181B)]
                : isRev
                    ? const [Color(0xFFFBF7FF), Color(0xFFF2F6FF)]
                    : const [
                        Color(0xFFF4FBF7),
                        Color(0xFFEEFCF3),
                        Color(0xFFF6FAF7),
                      ],
          ),
        ),
        child: SafeArea(
          child: CustomLazyLoader(
            isLoading: _isLoading,
            loadingText: isEn
                ? 'Verifying electronic signature & doctor profile...'
                : 'Memverifikasi tanda tangan elektronik & profil dokter...',
            loadingSubtext: isEn
                ? 'Checking MAPOTECH hash chain records...'
                : 'Memeriksa integritas catatan hash chain MAPOTECH...',
            skeleton: const Padding(
              padding: EdgeInsets.all(24),
              child: SkeletonGenericPage(),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1020),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeaderBar(
                        emerald: emerald,
                        textCol: textCol,
                        subCol: subCol,
                        borderCol: borderCol,
                        cardBg: cardBg,
                        isEn: isEn,
                      ),
                      const SizedBox(height: 22),
                      if (_data == null)
                        _buildNotFoundCard(
                          cardBg: cardBg,
                          borderCol: borderCol,
                          textCol: textCol,
                          subCol: subCol,
                          emerald: emerald,
                          isEn: isEn,
                        )
                      else
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isWide = constraints.maxWidth >= 868;
                            final leftCard = _buildLeftDocumentCard(
                              data: _data!,
                              lang: state.language,
                              isEn: isEn,
                              isDark: isDark,
                              emerald: emerald,
                              emeraldDark: emeraldDark,
                              cardBg: cardBg,
                              borderCol: borderCol,
                              textCol: textCol,
                              subCol: subCol,
                            );
                            final rightCard = _buildRightDoctorCard(
                              data: _data!,
                              isEn: isEn,
                              isDark: isDark,
                              emerald: emerald,
                              emeraldDark: emeraldDark,
                              cardBg: cardBg,
                              borderCol: borderCol,
                              textCol: textCol,
                              subCol: subCol,
                            );
                            if (isWide) {
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(flex: 11, child: leftCard),
                                  const SizedBox(width: 24),
                                  Expanded(flex: 9, child: rightCard),
                                ],
                              );
                            }
                            return Column(
                              children: [
                                leftCard,
                                const SizedBox(height: 20),
                                rightCard,
                              ],
                            );
                          },
                        ),
                      const SizedBox(height: 26),
                      Center(
                        child: RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            style: GoogleFonts.outfit(
                              fontSize: 11.5,
                              color: subCol,
                              fontWeight: FontWeight.w500,
                            ),
                            children: [
                              TextSpan(
                                text: isEn
                                    ? 'Digital Medical Letter Verification • Powered by '
                                    : 'Sistem Verifikasi Surat Digital • Powered by ',
                              ),
                              TextSpan(
                                text: 'MAPOTECH',
                                style: GoogleFonts.outfit(
                                  color: emerald,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderBar({
    required Color emerald,
    required Color textCol,
    required Color subCol,
    required Color borderCol,
    required Color cardBg,
    required bool isEn,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        InkWell(
          onTap: widget.onBackToPortal,
          borderRadius: BorderRadius.circular(12),
          child: Row(
            children: [
              Image.asset(
                'assets/images/logo.png',
                height: 34,
                errorBuilder: (_, _, _) => Icon(
                  Icons.local_hospital_rounded,
                  color: emerald,
                  size: 30,
                ),
              ),
              const SizedBox(width: 8),
              RichText(
                text: TextSpan(
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: textCol,
                  ),
                  children: [
                    const TextSpan(text: 'MAPO'),
                    TextSpan(
                      text: 'TECH',
                      style: TextStyle(color: emerald),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: borderCol),
              ),
              child: Text(
                isEn ? 'Public Verification' : 'Verifikasi Publik',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: subCol,
                ),
              ),
            ),
            if (widget.onBackToPortal != null) ...[
              const SizedBox(width: 10),
              CustomButton(
                text: widget.isEmbeddedModal
                    ? (isEn ? 'Close' : 'Tutup')
                    : (isEn ? 'Portal' : 'Beranda'),
                icon: widget.isEmbeddedModal
                    ? Icons.close_rounded
                    : Icons.home_rounded,
                isSecondary: true,
                borderColor: emerald,
                textColor: emerald,
                height: 36,
                onPressed: widget.onBackToPortal,
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildNotFoundCard({
    required Color cardBg,
    required Color borderCol,
    required Color textCol,
    required Color subCol,
    required Color emerald,
    required bool isEn,
  }) {
    return CustomCard(
      color: cardBg,
      borderColor: borderCol,
      borderRadius: 24,
      padding: const EdgeInsets.all(36),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.redAccent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.gpp_bad_rounded,
              color: Colors.redAccent,
              size: 34,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            isEn ? 'Document Not Found' : 'Dokumen Tidak Ditemukan',
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: textCol,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage ??
                (isEn
                    ? 'The scanned QR signature could not be matched with an active MAPOTECH clinical record.'
                    : 'QR tanda tangan yang dipindai tidak cocok dengan catatan rekam medis aktif di MAPOTECH.'),
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(fontSize: 13, color: subCol),
          ),
          const SizedBox(height: 22),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              CustomButton(
                text: isEn ? 'Retry' : 'Coba Lagi',
                icon: Icons.refresh_rounded,
                primaryColor: emerald,
                height: 44,
                onPressed: _loadVerificationData,
              ),
              if (widget.onBackToPortal != null)
                CustomButton(
                  text: isEn ? 'Back to MAPOTECH' : 'Kembali ke MAPOTECH',
                  isSecondary: true,
                  borderColor: emerald,
                  textColor: emerald,
                  height: 44,
                  onPressed: widget.onBackToPortal,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLeftDocumentCard({
    required MedicalLetterData data,
    required String lang,
    required bool isEn,
    required bool isDark,
    required Color emerald,
    required Color emeraldDark,
    required Color cardBg,
    required Color borderCol,
    required Color textCol,
    required Color subCol,
  }) {
    final badgeBg =
        isDark ? emerald.withValues(alpha: 0.16) : const Color(0xFFD1FAE5);
    final badgeFg = isDark ? const Color(0xFF6EE7B7) : const Color(0xFF065F46);
    final hashDisplay = (data.currentHash != null && data.currentHash!.length >= 16)
        ? '${data.currentHash!.substring(0, 12)}...${data.currentHash!.substring(data.currentHash!.length - 8)}'
        : (data.encounterId ?? '-');

    return CustomCard(
      color: cardBg.withValues(alpha: isDark ? 0.96 : 0.94),
      borderColor: borderCol,
      borderRadius: 24,
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
              decoration: BoxDecoration(
                color: badgeBg,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: emerald.withValues(alpha: 0.35)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.verified_rounded, size: 18, color: badgeFg),
                  const SizedBox(width: 8),
                  Text(
                    isEn
                        ? 'VALID ELECTRONIC SIGNATURE'
                        : 'TANDA TANGAN ELEKTRONIK SAH',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                      color: badgeFg,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            data.type.verificationTitle(isEn: isEn),
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: textCol,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isEn
                ? 'This medical document is digitally signed and registered in the MAPOTECH hash chain system.'
                : 'Dokumen medis ini sah secara digital, ditandatangani dokter praktik mandiri, dan terdaftar dalam sistem hash chain MAPOTECH.',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 12.5,
              color: subCol,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 24),

          // Section 1: Letter Details + Signature Timestamp
          _sectionHeader(
            icon: Icons.description_outlined,
            title: isEn ? 'Document Details' : 'Detail Surat Medis',
            emerald: emerald,
            textCol: textCol,
            borderCol: borderCol,
          ),
          _detailRow(
            isEn ? 'Letter Number' : 'Nomor Surat',
            data.letterNumber,
            textCol: textCol,
            subCol: subCol,
            borderCol: borderCol,
            mono: true,
            valueColor: emeraldDark,
          ),
          _detailRow(
            isEn ? 'Signed At' : 'Ditandatangani Pada',
            data.formattedSignedDateTime(lang: lang),
            textCol: textCol,
            subCol: subCol,
            borderCol: borderCol,
            valueColor: emeraldDark,
          ),
          if (data.type == MedicalLetterType.rujukan) ...[
            _detailRow(
              isEn ? 'Referred To' : 'Dirujuk Ke',
              data.rujukanRumahSakit,
              textCol: textCol,
              subCol: subCol,
              borderCol: borderCol,
              valueColor: emeraldDark,
            ),
            _detailRow(
              isEn ? 'Clinic / Department' : 'Poli / Bagian',
              data.rujukanPoli,
              textCol: textCol,
              subCol: subCol,
              borderCol: borderCol,
            ),
            if (data.rujukanCatatan.trim().isNotEmpty)
              _detailRow(
                isEn ? 'Referral Notes' : 'Catatan Rujukan',
                data.rujukanCatatan,
                textCol: textCol,
                subCol: subCol,
                borderCol: borderCol,
              ),
          ] else ...[
            _detailRow(
              isEn ? 'Result / Status' : 'Hasil Pemeriksaan',
              data.type == MedicalLetterType.suratSehat
                  ? (isEn
                      ? 'Physically & Mentally Healthy'
                      : 'Sehat Jasmani & Rohani')
                  : (isEn
                      ? 'Medical Rest ${data.suratSakitHari} Days'
                      : 'Istirahat Sakit ${data.suratSakitHari} Hari'),
              textCol: textCol,
              subCol: subCol,
              borderCol: borderCol,
              valueColor: emeraldDark,
            ),
            if (data.type == MedicalLetterType.suratSakit)
              _detailRow(
                isEn ? 'Rest Period' : 'Periode Istirahat',
                '${MedicalLetterData.formatSimpleDate(data.suratSakitMulai, lang: lang)} s/d ${MedicalLetterData.formatSimpleDate(data.suratSakitSelesai, lang: lang)}',
                textCol: textCol,
                subCol: subCol,
                borderCol: borderCol,
              ),
            _detailRow(
              isEn ? 'Purpose' : 'Keperluan',
              data.suratKeperluan,
              textCol: textCol,
              subCol: subCol,
              borderCol: borderCol,
            ),
          ],

          const SizedBox(height: 20),

          // Section 2: Patient Identity (masked NIK for public privacy)
          _sectionHeader(
            icon: Icons.person_outline_rounded,
            title: isEn ? 'Patient Identity' : 'Identitas Pasien',
            emerald: emerald,
            textCol: textCol,
            borderCol: borderCol,
          ),
          _detailRow(
            isEn ? 'Full Name' : 'Nama Lengkap',
            data.patientName,
            textCol: textCol,
            subCol: subCol,
            borderCol: borderCol,
          ),
          _detailRow(
            'NIK / KTP',
            data.maskedNik,
            textCol: textCol,
            subCol: subCol,
            borderCol: borderCol,
          ),
          _detailRow(
            isEn ? 'Medical Record No.' : 'Nomor Rekam Medis',
            data.patientId,
            textCol: textCol,
            subCol: subCol,
            borderCol: borderCol,
            mono: true,
          ),

          const SizedBox(height: 20),

          // Section 3: Clinical Diagnoses / Physical Exam
          if (data.type == MedicalLetterType.rujukan) ...[
            _sectionHeader(
              icon: Icons.medical_information_outlined,
              title: isEn ? 'Working Diagnosis (ICD-10)' : 'Diagnosa Kerja (ICD-10)',
              emerald: emerald,
              textCol: textCol,
              borderCol: borderCol,
            ),
            if (data.diagnoses.isEmpty)
              Text(
                '-',
                style: GoogleFonts.outfit(fontSize: 12, color: subCol),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: data.diagnoses
                    .map(
                      (d) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1E1E22)
                              : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: borderCol),
                        ),
                        child: RichText(
                          text: TextSpan(
                            style: GoogleFonts.outfit(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: textCol,
                            ),
                            children: [
                              TextSpan(
                                text: d['code'] ?? '',
                                style: TextStyle(
                                  color: emeraldDark,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              TextSpan(text: ' - ${d['description'] ?? ''}'),
                            ],
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
          ] else ...[
            _sectionHeader(
              icon: Icons.monitor_heart_outlined,
              title: isEn
                  ? 'Physical & Clinical Findings'
                  : 'Pemeriksaan Fisik & Klinis',
              emerald: emerald,
              textCol: textCol,
              borderCol: borderCol,
            ),
            _detailRow(
              isEn ? 'Blood Pressure' : 'Tekanan Darah',
              data.bloodPressure.isEmpty ? '-' : '${data.bloodPressure} mmHg',
              textCol: textCol,
              subCol: subCol,
              borderCol: borderCol,
            ),
            _detailRow(
              isEn ? 'Heart Rate' : 'Nadi',
              data.heartRate.isEmpty ? '-' : '${data.heartRate} x/menit',
              textCol: textCol,
              subCol: subCol,
              borderCol: borderCol,
            ),
            _detailRow(
              isEn ? 'Past Medical History' : 'Riwayat Penyakit Dahulu',
              data.suratRiwayatPenyakit.trim().isEmpty
                  ? (isEn ? 'None' : 'Tidak Ada')
                  : data.suratRiwayatPenyakit,
              textCol: textCol,
              subCol: subCol,
              borderCol: borderCol,
            ),
          ],

          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: emerald.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: emerald.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.shield_outlined, size: 18, color: emeraldDark),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEn
                            ? 'Hash Chain Integrity Record'
                            : 'Rekam Jejak Hash Chain',
                        style: GoogleFonts.outfit(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: emeraldDark,
                        ),
                      ),
                      Text(
                        'Hash: $hashDisplay',
                        style: GoogleFonts.robotoMono(
                          fontSize: 10,
                          color: subCol,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          CustomButton(
            text: isEn ? 'View & Print Copy' : 'Lihat & Cetak Salinan Surat',
            icon: Icons.print_rounded,
            isSecondary: true,
            borderColor: emerald,
            textColor: emerald,
            height: 44,
            onPressed: () => MedicalLetterPreviewDialog.show(
              context,
              initialData: data,
              maskPatientNik: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRightDoctorCard({
    required MedicalLetterData data,
    required bool isEn,
    required bool isDark,
    required Color emerald,
    required Color emeraldDark,
    required Color cardBg,
    required Color borderCol,
    required Color textCol,
    required Color subCol,
  }) {
    const daysOrder = [
      ('Monday', 'Senin', 'Monday'),
      ('Tuesday', 'Selasa', 'Tuesday'),
      ('Wednesday', 'Rabu', 'Wednesday'),
      ('Thursday', 'Kamis', 'Thursday'),
      ('Friday', 'Jumat', 'Friday'),
      ('Saturday', 'Sabtu', 'Saturday'),
      ('Sunday', 'Minggu', 'Sunday'),
    ];

    final schedulesByDay = <String, Map<String, dynamic>>{};
    for (final s in data.doctorSchedules) {
      final d = (s['day'] ?? '').toString().trim().toLowerCase();
      if (d.isNotEmpty) schedulesByDay[d] = s;
    }

    String formatHm(dynamic raw) {
      final str = (raw ?? '').toString().trim();
      if (str.length >= 5) return str.substring(0, 5);
      return str.isEmpty ? '-' : str;
    }

    final hasMaps = data.doctorMapsLink.trim().isNotEmpty ||
        (data.doctorLatitude != null && data.doctorLongitude != null);

    return CustomCard(
      color: cardBg,
      borderColor: borderCol,
      borderRadius: 24,
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Avatar + Verified badge
          Center(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: emerald, width: 2.5),
                    color: cardBg,
                  ),
                  child: ClipOval(
                    child: (data.doctorAvatarUrl != null &&
                            data.doctorAvatarUrl!.trim().isNotEmpty)
                        ? Image.network(
                            data.doctorAvatarUrl!.trim(),
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                _initialsAvatar(data.displayDoctorName, emerald),
                          )
                        : _initialsAvatar(data.displayDoctorName, emerald),
                  ),
                ),
                Positioned(
                  right: 2,
                  bottom: 2,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: emerald,
                      shape: BoxShape.circle,
                      border: Border.all(color: cardBg, width: 2),
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            data.displayDoctorName,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: textCol,
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: emerald.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                data.doctorProfession.toUpperCase(),
                style: GoogleFonts.outfit(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: emeraldDark,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            data.doctorFaskesName,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: subCol,
            ),
          ),

          if (data.doctorAbout.trim().isNotEmpty) ...[
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: emerald.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: emerald.withValues(alpha: 0.14)),
              ),
              child: Text(
                '"${data.doctorAbout.trim()}"',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: subCol,
                  height: 1.5,
                ),
              ),
            ),
          ],

          const SizedBox(height: 20),
          _sectionHeader(
            icon: Icons.location_on_outlined,
            title: isEn
                ? 'Contact & Practice Address'
                : 'Hubungi & Alamat Praktik',
            emerald: emerald,
            textCol: textCol,
            borderCol: borderCol,
          ),
          Text(
            data.displayPracticeAddress,
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textCol,
              height: 1.45,
            ),
          ),
          if (data.primarySip != '-') ...[
            const SizedBox(height: 10),
            _detailRow(
              'SIP / Izin Praktik',
              data.primarySip,
              textCol: textCol,
              subCol: subCol,
              borderCol: borderCol,
            ),
          ],

          const SizedBox(height: 20),
          _sectionHeader(
            icon: Icons.access_time_rounded,
            title: isEn ? 'Weekly Practice Schedule' : 'Jadwal Praktik Mingguan',
            emerald: emerald,
            textCol: textCol,
            borderCol: borderCol,
          ),
          Column(
            children: daysOrder.map((entry) {
              final enKey = entry.$1.toLowerCase();
              final idKey = entry.$2.toLowerCase();
              final sched = schedulesByDay[enKey] ?? schedulesByDay[idKey];
              final isActive = sched != null && sched['is_off'] != true;
              final label = isEn ? entry.$3 : entry.$2;
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isActive
                      ? (isDark
                          ? const Color(0xFF1E1E22)
                          : const Color(0xFFF8FAFC))
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isActive ? borderCol : Colors.transparent,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isActive ? textCol : subCol,
                      ),
                    ),
                    if (isActive)
                      Text(
                        '${formatHm(sched['open_time'])} - ${formatHm(sched['close_time'])}',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: textCol,
                        ),
                      )
                    else
                      StatusBadge(
                        label: isEn ? 'Closed' : 'Tutup',
                        color: Colors.grey,
                      ),
                  ],
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 18),
          if (data.doctorWhatsapp.trim().isNotEmpty ||
              (data.doctorPhone.trim().isNotEmpty && data.doctorPhone != '-')) ...[
            CustomButton(
              text: isEn ? 'Contact via WhatsApp' : 'Hubungi via WhatsApp',
              icon: Icons.chat_rounded,
              primaryColor: const Color(0xFF25D366),
              height: 46,
              onPressed: () => _openWhatsApp(data, isEn),
            ),
            const SizedBox(height: 10),
          ],
          if (hasMaps) ...[
            CustomButton(
              text: isEn
                  ? 'Google Maps Directions'
                  : 'Petunjuk Arah Google Maps',
              icon: Icons.map_outlined,
              isSecondary: true,
              borderColor: borderCol,
              textColor: textCol,
              height: 46,
              onPressed: () => _openGoogleMaps(data),
            ),
            const SizedBox(height: 10),
          ],
          CustomButton(
            text: isEn
                ? 'Online Queue / Booking'
                : 'Daftar Antrian Online / Booking',
            icon: Icons.calendar_month_rounded,
            primaryColor: emerald,
            height: 46,
            onPressed: () => _openDoctorBooking(data, isDark),
          ),
        ],
      ),
    );
  }

  Widget _initialsAvatar(String name, Color emerald) {
    final parts = name.trim().split(RegExp(r'\s+'));
    final initials = parts.length >= 2
        ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
        : (name.isNotEmpty ? name[0].toUpperCase() : 'DR');
    return Container(
      color: emerald,
      alignment: Alignment.center,
      child: Text(
        initials,
        style: GoogleFonts.outfit(
          fontSize: 28,
          fontWeight: FontWeight.w900,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _sectionHeader({
    required IconData icon,
    required String title,
    required Color emerald,
    required Color textCol,
    required Color borderCol,
  }) {
    return Container(
      padding: const EdgeInsets.only(bottom: 8),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: borderCol)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: emerald),
          const SizedBox(width: 8),
          Text(
            title.toUpperCase(),
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: textCol,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(
    String label,
    String value, {
    required Color textCol,
    required Color subCol,
    required Color borderCol,
    bool mono = false,
    Color? valueColor,
  }) {
    final cleanVal = value.trim().isEmpty ? '-' : value.trim();
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: borderCol.withValues(alpha: 0.6))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: subCol,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 6,
            child: Text(
              cleanVal,
              textAlign: TextAlign.right,
              style: mono
                  ? GoogleFonts.robotoMono(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: valueColor ?? textCol,
                    )
                  : GoogleFonts.outfit(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: valueColor ?? textCol,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
