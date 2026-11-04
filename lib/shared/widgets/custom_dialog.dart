import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mapotech/shared/duitku_payment_service.dart';
import 'custom_button.dart';

/// Standard custom modal dialog for MAPOTECH applications.
/// Replaces ad-hoc AlertDialog implementations with unified aesthetics.
class CustomDialog extends StatelessWidget {
  final String? title;
  final Widget? titleWidget;
  final IconData? icon;
  final Color? iconColor;
  final Widget? content;
  final String? message;
  final List<Widget>? actions;
  final double maxWidth;
  final double borderRadius;
  final bool showCloseButton;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;

  const CustomDialog({
    super.key,
    this.title,
    this.titleWidget,
    this.icon,
    this.iconColor,
    this.content,
    this.message,
    this.actions,
    this.maxWidth = 460.0,
    this.borderRadius = 20.0,
    this.showCloseButton = true,
    this.padding = const EdgeInsets.all(24.0),
    this.backgroundColor,
  });

  /// Helper to show a generic CustomDialog with animation
  static Future<T?> show<T>({
    required BuildContext context,
    String? title,
    Widget? titleWidget,
    IconData? icon,
    Color? iconColor,
    Widget? content,
    String? message,
    List<Widget>? actions,
    double maxWidth = 460.0,
    bool barrierDismissible = true,
  }) {
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (ctx, anim1, anim2) {
        return CustomDialog(
          title: title,
          titleWidget: titleWidget,
          icon: icon,
          iconColor: iconColor,
          content: content,
          message: message,
          actions: actions,
          maxWidth: maxWidth,
        );
      },
      transitionBuilder: (ctx, anim1, anim2, child) {
        final curved = CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic);
        return ScaleTransition(
          scale: Tween<double>(begin: 0.92, end: 1.0).animate(curved),
          child: FadeTransition(
            opacity: curved,
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bg = backgroundColor ??
        (isDark ? const Color(0xFF1E1E24) : Colors.white);
    final textCol = isDark ? Colors.white : const Color(0xFF1A1A24);
    final subCol = isDark ? const Color(0xFF9E9EAF) : const Color(0xFF6B7280);
    final borderCol = isDark ? const Color(0xFF2E2E38) : const Color(0xFFECEEF2);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: borderCol, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 14, 14),
                child: Row(
                  children: [
                    if (icon != null) ...[
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: (iconColor ?? theme.colorScheme.primary)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          icon,
                          size: 20,
                          color: iconColor ?? theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: titleWidget ??
                          (title != null
                              ? Text(
                                  title!,
                                  style: GoogleFonts.outfit(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: textCol,
                                  ),
                                )
                              : const SizedBox.shrink()),
                    ),
                    if (showCloseButton)
                      IconButton(
                        icon: Icon(Icons.close_rounded, size: 20, color: subCol),
                        onPressed: () => Navigator.of(context).pop(),
                        splashRadius: 20,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1, thickness: 1),
              // Body
              Flexible(
                child: SingleChildScrollView(
                  padding: padding,
                  child: content ??
                      (message != null
                          ? Text(
                              message!,
                              style: GoogleFonts.outfit(
                                fontSize: 13.5,
                                color: textCol.withValues(alpha: 0.9),
                                height: 1.5,
                              ),
                            )
                          : const SizedBox.shrink()),
                ),
              ),
              // Actions
              if (actions != null && actions!.isNotEmpty) ...[
                const Divider(height: 1, thickness: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 14.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: actions!,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Specialized confirmation dialog (e.g. Delete, Confirm Action, Logout)
class CustomConfirmDialog {
  static Future<bool> show({
    required BuildContext context,
    required String title,
    required String message,
    String confirmText = 'Konfirmasi',
    String cancelText = 'Batal',
    bool isDanger = false,
    IconData? icon,
  }) async {
    final result = await CustomDialog.show<bool>(
      context: context,
      title: title,
      icon: icon ?? (isDanger ? Icons.warning_amber_rounded : Icons.info_outline_rounded),
      iconColor: isDanger ? Colors.redAccent : null,
      message: message,
      actions: [
        CustomButton(
          text: cancelText,
          isSecondary: true,
          height: 38,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        const SizedBox(width: 10),
        CustomButton(
          text: confirmText,
          height: 38,
          primaryColor: isDanger ? Colors.redAccent : null,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
    return result ?? false;
  }
}

/// Standard custom QRIS payment dialog for MAPOTECH applications.
/// Displays high-resolution QR code, payment URL, real dynamic amount, and live status verification.
class CustomQrisDialog extends StatefulWidget {
  final String orderId;
  final String paymentUrl;
  final String qrString;
  final int amount;
  final String packageType;
  final String packageTitle;
  final String userId;
  final bool isResume;
  final VoidCallback onPaymentSuccess;
  final VoidCallback? onResetPayment;

  const CustomQrisDialog({
    super.key,
    required this.orderId,
    required this.paymentUrl,
    required this.qrString,
    required this.amount,
    required this.packageType,
    required this.packageTitle,
    required this.userId,
    this.isResume = false,
    required this.onPaymentSuccess,
    this.onResetPayment,
  });

  static Future<void> show({
    required BuildContext context,
    required String orderId,
    required String paymentUrl,
    required String qrString,
    required int amount,
    required String packageType,
    required String packageTitle,
    required String userId,
    bool isResume = false,
    required VoidCallback onPaymentSuccess,
    VoidCallback? onResetPayment,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => CustomQrisDialog(
        orderId: orderId,
        paymentUrl: paymentUrl,
        qrString: qrString,
        amount: amount,
        packageType: packageType,
        packageTitle: packageTitle,
        userId: userId,
        isResume: isResume,
        onPaymentSuccess: onPaymentSuccess,
        onResetPayment: onResetPayment,
      ),
    );
  }

  @override
  State<CustomQrisDialog> createState() => _CustomQrisDialogState();
}

class _CustomQrisDialogState extends State<CustomQrisDialog> {
  bool _isChecking = false;
  String? _statusMessage;
  bool _isError = false;

  String _formatCurrency(int val) {
    return 'Rp ${val.toString().replaceAllMapped(RegExp(r"(\d)(?=(\d{3})+(?!\d))"), (m) => "${m[1]}.")}';
  }

  Future<void> _checkStatus() async {
    if (_isChecking) return;

    setState(() {
      _isChecking = true;
      _statusMessage = null;
      _isError = false;
    });

    try {
      final isPaid = await DuitkuPaymentService.checkPaymentStatus(widget.orderId);

      if (!mounted) return;

      if (isPaid) {
        DuitkuPaymentService.clearPendingPayment();
        Navigator.of(context).pop();
        widget.onPaymentSuccess();
      } else {
        setState(() {
          _isChecking = false;
          _isError = false;
          _statusMessage = 'Pembayaran belum terdeteksi. Silakan selesaikan scan QRIS lalu tekan cek lagi.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isChecking = false;
        _isError = true;
        _statusMessage = 'Gagal memeriksa status: $e';
      });
    }
  }

  Future<void> _launchPaymentUrl() async {
    final uri = Uri.tryParse(widget.paymentUrl);
    if (uri != null) {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri);
      }
    }
  }

  void _copyPaymentUrl() {
    Clipboard.setData(ClipboardData(text: widget.paymentUrl));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tautan pembayaran berhasil disalin!'),
        backgroundColor: Color(0xFF00A67E),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _handleReset() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 22),
            const SizedBox(width: 8),
            Text(
              'Reset Pembayaran?',
              style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        content: Text(
          'Batalkan QRIS saat ini dan buat transaksi baru?',
          style: GoogleFonts.outfit(color: Colors.grey[300], fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Kembali', style: GoogleFonts.outfit(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Ya, Reset', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      DuitkuPaymentService.clearPendingPayment();
      if (mounted) Navigator.of(context).pop();
      widget.onResetPayment?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bg = isDark ? const Color(0xFF1E1E24) : Colors.white;
    final textCol = isDark ? Colors.white : const Color(0xFF1A1A24);
    final subCol = isDark ? Colors.white70 : const Color(0xFF6B7280);
    final borderCol = isDark ? const Color(0xFF2E2E38) : const Color(0xFFECEEF2);

    const tealAccent = Color(0xFF00A67E);
    final formattedPrice = _formatCurrency(widget.amount);
    final hasQr = widget.qrString.isNotEmpty;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: borderCol, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.15),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Header Row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: tealAccent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.qr_code_scanner_rounded, color: tealAccent, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.isResume ? 'Lanjutkan Pembayaran QRIS' : 'Scan & Bayar via QRIS',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w900,
                              color: textCol,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            widget.packageTitle,
                            style: GoogleFonts.outfit(
                              color: subCol,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: subCol, size: 22),
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: 'Tutup',
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Real Price Badge Card
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: tealAccent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: tealAccent.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total Pembayaran',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: subCol,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            formattedPrice,
                            style: GoogleFonts.outfit(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: tealAccent,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: tealAccent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'REAL HARGA',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // QR Code Display
                if (hasQr)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: tealAccent.withValues(alpha: 0.2),
                            blurRadius: 20,
                            spreadRadius: 2,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: QrImageView(
                        data: widget.qrString,
                        version: QrVersions.auto,
                        size: 210,
                        backgroundColor: Colors.white,
                        errorCorrectionLevel: QrErrorCorrectLevel.M,
                      ),
                    ),
                  )
                else
                  Container(
                    height: 180,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: borderCol.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.link_rounded, size: 40, color: tealAccent),
                        const SizedBox(height: 8),
                        Text(
                          'Gunakan tombol tautan untuk membayar',
                          style: GoogleFonts.outfit(fontSize: 12, color: subCol),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 12),

                // Notice & Expiry
                Center(
                  child: Text(
                    'Bisa di-scan dengan ShopeePay, BCA, Mandiri, GoPay, OVO, Dana\nBerlaku 60 menit • Order ID: ${widget.orderId}',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      color: subCol,
                      height: 1.4,
                    ),
                  ),
                ),

                if (_statusMessage != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: (_isError ? Colors.redAccent : Colors.amber).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: (_isError ? Colors.redAccent : Colors.amber).withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _isError ? Icons.error_outline_rounded : Icons.info_outline_rounded,
                          color: _isError ? Colors.redAccent : Colors.amber,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _statusMessage!,
                            style: GoogleFonts.outfit(
                              color: _isError ? Colors.redAccent : Colors.amber,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // Primary Action: Cek Status Pembayaran
                SizedBox(
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: _isChecking ? null : _checkStatus,
                    icon: _isChecking
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.refresh_rounded, size: 18, color: Colors.white),
                    label: Text(
                      _isChecking ? 'Memeriksa Pembayaran...' : 'Saya Sudah Bayar (Cek Status)',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: tealAccent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // Secondary Action: Buka Link & Salin Link
                Row(
                  children: [
                    if (widget.paymentUrl.isNotEmpty) ...[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _launchPaymentUrl,
                          icon: const Icon(Icons.open_in_new_rounded, size: 14),
                          label: const Text('Buka Tautan'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: tealAccent,
                            side: BorderSide(color: tealAccent.withValues(alpha: 0.5)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            textStyle: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: _copyPaymentUrl,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: subCol,
                          side: BorderSide(color: borderCol),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Icon(Icons.copy_rounded, size: 16),
                      ),
                      const SizedBox(width: 8),
                    ],
                    OutlinedButton(
                      onPressed: _handleReset,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.4)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Icon(Icons.delete_outline_rounded, size: 16),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
