import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapotech/features/apotek/dashboard/frontend/widgets/web_qr_scanner.dart';
import 'package:mapotech/features/landing/landing_page_data.dart';
import 'package:mapotech/shared/supabase_service.dart';

/// Modal dialog for patients to scan QR codes for Doctor Registration or Apotek POS
class PasienQrScannerDialog extends ConsumerStatefulWidget {
  final Function(Map<String, dynamic> doctor)? onDoctorScanned;
  final Function(Map<String, dynamic> apotek)? onApotekScanned;

  const PasienQrScannerDialog({
    super.key,
    this.onDoctorScanned,
    this.onApotekScanned,
  });

  @override
  ConsumerState<PasienQrScannerDialog> createState() =>
      _PasienQrScannerDialogState();
}

class _PasienQrScannerDialogState extends ConsumerState<PasienQrScannerDialog>
    with SingleTickerProviderStateMixin {
  final SupabaseService _db = SupabaseService();
  final TextEditingController _inputController = TextEditingController();

  late AnimationController _laserAnimationController;
  late Animation<double> _laserAnimation;

  bool _isProcessing = false;
  bool _isFrontCamera = false;
  bool _isTorchOn = false;
  bool _isCameraReady = false;
  String? _cameraStatusMessage;
  String? _scanErrorMessage;

  @override
  void initState() {
    super.initState();
    _laserAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _laserAnimation = Tween<double>(begin: 0.05, end: 0.95).animate(
      CurvedAnimation(
        parent: _laserAnimationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _laserAnimationController.dispose();
    _inputController.dispose();
    super.dispose();
  }

  /// Parse the scanned QR text or production URL
  Future<void> _handleScanPayload(String rawCode) async {
    final payload = rawCode.trim();
    if (payload.isEmpty || _isProcessing) return;

    setState(() {
      _isProcessing = true;
      _scanErrorMessage = null;
    });

    try {
      // 1. Analyze payload format
      // Production URL: https://mapotek.relvastudio.com/...
      // Or local/kemenkes links: https://mapotech.kemenkes.go.id/..., https://mapotech.id/...
      String targetType = ''; // 'doctor', 'apotek', 'prescription'
      String targetIdentifier = '';

      final lower = payload.toLowerCase();

      if (lower.contains('/dokter/') ||
          lower.contains('/doctor/') ||
          lower.contains('/pendaftaran/') ||
          lower.contains('/booking/') ||
          lower.startsWith('dokter:') ||
          lower.startsWith('doctor:') ||
          lower.contains('type=dokter') ||
          lower.contains('role=dokter')) {
        targetType = 'doctor';
        targetIdentifier = _extractIdentifier(payload, [
          '/dokter/',
          '/doctor/',
          '/pendaftaran/',
          '/booking/',
          'dokter:',
          'doctor:',
        ]);
      } else if (lower.contains('/apotek/') ||
          lower.contains('/pharmacy/') ||
          lower.contains('/pos/') ||
          lower.contains('/pos-apotek/') ||
          lower.startsWith('apotek:') ||
          lower.startsWith('pharmacy:') ||
          lower.contains('type=apotek') ||
          lower.contains('role=apotek')) {
        targetType = 'apotek';
        targetIdentifier = _extractIdentifier(payload, [
          '/apotek/',
          '/pharmacy/',
          '/pos/',
          '/pos-apotek/',
          'apotek:',
          'pharmacy:',
        ]);
      } else if (payload.startsWith('{') && payload.endsWith('}')) {
        try {
          final decoded = jsonDecode(payload);
          final role =
              (decoded['role'] ??
                      decoded['type'] ??
                      decoded['entity'] ??
                      '')
                  .toString()
                  .toLowerCase();
          final id =
              decoded['id'] ??
              decoded['doctor_id'] ??
              decoded['apotek_id'] ??
              '';
          if (role.contains('dok') || role.contains('doc')) {
            targetType = 'doctor';
            targetIdentifier = id.toString();
          } else if (role.contains('apo') || role.contains('pharm')) {
            targetType = 'apotek';
            targetIdentifier = id.toString();
          }
        } catch (_) {}
      }

      // If not yet categorized, try looking up in doctors first then pharmacies
      final doctors = await _db.fetchAllDoctors();
      final pharmacies = await _db.fetchAllPharmacies();

      Map<String, dynamic>? matchedDoctor;
      Map<String, dynamic>? matchedApotek;

      if (targetType == 'doctor') {
        matchedDoctor = _findDoctor(doctors, targetIdentifier.isNotEmpty ? targetIdentifier : payload);
      } else if (targetType == 'apotek') {
        matchedApotek = _findPharmacy(pharmacies, targetIdentifier.isNotEmpty ? targetIdentifier : payload);
      } else {
        // Broad search: test against doctor identifiers
        matchedDoctor = _findDoctor(doctors, payload);
        if (matchedDoctor == null) {
          // test against pharmacy identifiers
          matchedApotek = _findPharmacy(pharmacies, payload);
        }
      }

      if (matchedDoctor != null) {
        if (mounted) {
          Navigator.pop(context);
          widget.onDoctorScanned?.call(matchedDoctor);
        }
        return;
      }

      if (matchedApotek != null) {
        if (mounted) {
          Navigator.pop(context);
          widget.onApotekScanned?.call(matchedApotek);
        }
        return;
      }

      // Fallback: If no direct doctor or apotek matched, show helpful message
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _scanErrorMessage =
              'QR Code tidak dikenali sebagai Dokter atau Apotek Mapotech terdaftar.\nPayload: $payload';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _scanErrorMessage = 'Gagal memproses QR Code: $e';
        });
      }
    }
  }

  String _extractIdentifier(String payload, List<String> patterns) {
    for (final pat in patterns) {
      if (payload.toLowerCase().contains(pat)) {
        final idx = payload.toLowerCase().indexOf(pat);
        final sub = payload.substring(idx + pat.length);
        final clean = sub.split('?').first.split('#').first.split('/').first.trim();
        if (clean.isNotEmpty) return clean;
      }
    }
    return payload.trim();
  }

  Map<String, dynamic>? _findDoctor(List<Map<String, dynamic>> doctors, String query) {
    final q = query.toLowerCase().replaceAll('-', ' ').trim();
    if (q.isEmpty) return null;

    for (final doc in doctors) {
      final id = (doc['id'] ?? '').toString().toLowerCase();
      final name = (doc['name'] ?? '').toString().toLowerCase();
      final faskes = (doc['nama_faskes'] ?? '').toString().toLowerCase();
      final phone = (doc['whatsapp_number'] ?? '').toString().replaceAll(RegExp(r'\D'), '');

      if (id == query.toLowerCase() ||
          name.contains(q) ||
          q.contains(name) ||
          faskes.contains(q) ||
          (phone.isNotEmpty && query.contains(phone))) {
        return doc;
      }
    }

    // Default fallback to first doctor if demo test
    if (doctors.isNotEmpty && (query.contains('dokter') || query.contains('doctor') || query.contains('agoes'))) {
      return doctors.first;
    }
    return null;
  }

  Map<String, dynamic>? _findPharmacy(List<Map<String, dynamic>> pharmacies, String query) {
    final q = query.toLowerCase().replaceAll('-', ' ').trim();
    if (q.isEmpty) return null;

    for (final ph in pharmacies) {
      final id = (ph['id'] ?? '').toString().toLowerCase();
      final name = (ph['name'] ?? '').toString().toLowerCase();
      final faskes = (ph['nama_faskes'] ?? '').toString().toLowerCase();
      final phone = (ph['whatsapp_number'] ?? '').toString().replaceAll(RegExp(r'\D'), '');

      if (id == query.toLowerCase() ||
          name.contains(q) ||
          q.contains(name) ||
          faskes.contains(q) ||
          (phone.isNotEmpty && query.contains(phone))) {
        return ph;
      }
    }

    // Default fallback to first pharmacy if demo test
    if (pharmacies.isNotEmpty && (query.contains('apotek') || query.contains('cyren') || query.contains('pos'))) {
      return pharmacies.first;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(landingPageProvider);
    final isDark = state.appearance == 'dark';
    final cardBg = isDark ? const Color(0xFF18181B) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1B0C3C);
    final subtitleColor = isDark
        ? const Color(0xFF9E9EB0)
        : const Color(0xFF6F6A8A);
    final borderColor = isDark
        ? const Color(0xFF2D2D32)
        : const Color(0xFFECEEF2);
    final sectionBg = isDark
        ? const Color(0xFF1F1F24)
        : const Color(0xFFF8FAFD);
    const themeAccent = Color(0xFF48C9B0);
    const purple = Color(0xFFB577F2);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor: cardBg,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: 500,
        constraints: const BoxConstraints(maxHeight: 740),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Dialog Header ──────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(24, 18, 16, 18),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: borderColor)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: themeAccent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.qr_code_scanner_rounded,
                      color: themeAccent,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Scan QR Dokter / Apotek',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: textColor,
                          ),
                        ),
                        Text(
                          'Arahkan kamera ke QR Dokter atau QR Apotek',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            color: subtitleColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                    color: subtitleColor,
                  ),
                ],
              ),
            ),

            // ── Scanner Viewfinder Area ─────────────────────────────────
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Camera Viewport Box
                    Center(
                      child: Container(
                        width: 280,
                        height: 280,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: themeAccent.withValues(alpha: 0.5),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: themeAccent.withValues(alpha: 0.2),
                              blurRadius: 20,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Live Webcam/Camera
                              Positioned.fill(
                                child: buildWebQrScannerWidget(
                                  onScanned: (scannedCode) {
                                    _handleScanPayload(scannedCode);
                                  },
                                  isFrontCamera: _isFrontCamera,
                                  isTorchOn: _isTorchOn,
                                  onCameraStatusChanged: (isReady, msg) {
                                    if (mounted) {
                                      setState(() {
                                        _isCameraReady = isReady;
                                        _cameraStatusMessage = msg;
                                      });
                                    }
                                  },
                                  onCameraSwitch: () {
                                    setState(() {
                                      _isFrontCamera = !_isFrontCamera;
                                    });
                                  },
                                ),
                              ),

                              // Viewfinder Target Frame
                              AnimatedBuilder(
                                animation: _laserAnimation,
                                builder: (context, child) {
                                  return SizedBox(
                                    width: 190,
                                    height: 190,
                                    child: CustomPaint(
                                      painter: _PasienScannerPainter(
                                        laserProgress: _laserAnimation.value,
                                        accentColor: themeAccent,
                                      ),
                                    ),
                                  );
                                },
                              ),

                              // Processing Indicator Overlay
                              if (_isProcessing)
                                Container(
                                  color: Colors.black.withValues(alpha: 0.65),
                                  alignment: Alignment.center,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const CircularProgressIndicator(
                                        color: themeAccent,
                                        strokeWidth: 3,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Menganalisis QR Code...',
                                        style: GoogleFonts.outfit(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Camera Controls & Hint
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildControlChip(
                          icon: _isFrontCamera
                              ? Icons.camera_front_rounded
                              : Icons.camera_rear_rounded,
                          label: _isFrontCamera ? 'Kamera Depan' : 'Kamera Belakang',
                          onTap: () =>
                              setState(() => _isFrontCamera = !_isFrontCamera),
                          isDark: isDark,
                          themeAccent: themeAccent,
                        ),
                        const SizedBox(width: 10),
                        _buildControlChip(
                          icon: _isTorchOn
                              ? Icons.flash_on_rounded
                              : Icons.flash_off_rounded,
                          label: _isTorchOn ? 'Flash Menyala' : 'Flash',
                          onTap: () => setState(() => _isTorchOn = !_isTorchOn),
                          isDark: isDark,
                          themeAccent: themeAccent,
                        ),
                      ],
                    ),

                    if (_scanErrorMessage != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.red.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              color: Colors.redAccent,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _scanErrorMessage!,
                                style: GoogleFonts.outfit(
                                  color: Colors.redAccent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 18),

                    // ── Manual Input / Production Link Test Area ───────────────
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: sectionBg,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.link_rounded,
                                size: 16,
                                color: themeAccent,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Input / Tempel Link atau Kode QR',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: textColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: cardBg,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: borderColor),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  alignment: Alignment.center,
                                  child: TextField(
                                    controller: _inputController,
                                    style: GoogleFonts.outfit(
                                      fontSize: 12,
                                      color: textColor,
                                    ),
                                    decoration: InputDecoration(
                                      hintText:
                                          'https://mapotek.relvastudio.com/dokter/...',
                                      hintStyle: GoogleFonts.outfit(
                                        fontSize: 11,
                                        color: subtitleColor.withValues(
                                          alpha: 0.6,
                                        ),
                                      ),
                                      border: InputBorder.none,
                                      isDense: true,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: _isProcessing
                                    ? null
                                    : () => _handleScanPayload(
                                        _inputController.text,
                                      ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: themeAccent,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  'Buka',
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Quick Sample Test Buttons
                          Text(
                            'Sampel Uji Cepat Production Link:',
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: subtitleColor,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              _buildSampleChip(
                                label: 'QR Dokter Agoes (Pendaftaran)',
                                icon: Icons.person_search_rounded,
                                color: purple,
                                onTap: () {
                                  _inputController.text =
                                      'https://mapotek.relvastudio.com/dokter/dr-agoes-soetanto';
                                  _handleScanPayload(_inputController.text);
                                },
                              ),
                              _buildSampleChip(
                                label: 'QR Apotek CyrenElysia (POS)',
                                icon: Icons.local_pharmacy_rounded,
                                color: const Color(0xFF0F9D58),
                                onTap: () {
                                  _inputController.text =
                                      'https://mapotek.relvastudio.com/apotek/cyren-elysia-pujer';
                                  _handleScanPayload(_inputController.text);
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isDark,
    required Color themeAccent,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: themeAccent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: themeAccent.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: themeAccent),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: themeAccent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSampleChip({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom Viewfinder Painter with Animated Laser
class _PasienScannerPainter extends CustomPainter {
  final double laserProgress;
  final Color accentColor;

  _PasienScannerPainter({
    required this.laserProgress,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cornerPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    const cornerLength = 22.0;
    const r = 8.0;

    // Top-Left corner
    final tlPath = Path()
      ..moveTo(0, cornerLength)
      ..lineTo(0, r)
      ..arcToPoint(const Offset(r, 0), radius: const Radius.circular(r))
      ..lineTo(cornerLength, 0);
    canvas.drawPath(tlPath, cornerPaint);

    // Top-Right corner
    final trPath = Path()
      ..moveTo(size.width - cornerLength, 0)
      ..lineTo(size.width - r, 0)
      ..arcToPoint(Offset(size.width, r), radius: const Radius.circular(r))
      ..lineTo(size.width, cornerLength);
    canvas.drawPath(trPath, cornerPaint);

    // Bottom-Left corner
    final blPath = Path()
      ..moveTo(0, size.height - cornerLength)
      ..lineTo(0, size.height - r)
      ..arcToPoint(Offset(r, size.height), radius: const Radius.circular(r))
      ..lineTo(cornerLength, size.height);
    canvas.drawPath(blPath, cornerPaint);

    // Bottom-Right corner
    final brPath = Path()
      ..moveTo(size.width - cornerLength, size.height)
      ..lineTo(size.width - r, size.height)
      ..arcToPoint(
        Offset(size.width, size.height - r),
        radius: const Radius.circular(r),
      )
      ..lineTo(size.width, size.height - cornerLength);
    canvas.drawPath(brPath, cornerPaint);

    // Animated Laser Scan Line
    final laserY = size.height * laserProgress;
    final laserPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          accentColor.withValues(alpha: 0.0),
          accentColor,
          accentColor.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(0, laserY, size.width, 2.5))
      ..strokeWidth = 2.5;

    canvas.drawLine(Offset(8, laserY), Offset(size.width - 8, laserY), laserPaint);
  }

  @override
  bool shouldRepaint(covariant _PasienScannerPainter oldDelegate) {
    return oldDelegate.laserProgress != laserProgress ||
        oldDelegate.accentColor != accentColor;
  }
}
