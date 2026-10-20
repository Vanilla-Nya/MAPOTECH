import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum CustomSnackbarType { success, error, warning, info }

/// Standard floating notification / toast for MAPOTECH applications.
class CustomSnackbar {
  static void show(
    BuildContext context, {
    required String message,
    String? title,
    CustomSnackbarType type = CustomSnackbarType.info,
    Duration duration = const Duration(seconds: 3),
    VoidCallback? onAction,
    String? actionLabel,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    messenger.hideCurrentSnackBar();

    Color accentColor;
    IconData iconData;
    String defaultTitle;

    switch (type) {
      case CustomSnackbarType.success:
        accentColor = const Color(0xFF10B981);
        iconData = Icons.check_circle_rounded;
        defaultTitle = 'Berhasil';
        break;
      case CustomSnackbarType.error:
        accentColor = const Color(0xFFEF4444);
        iconData = Icons.error_rounded;
        defaultTitle = 'Terjadi Kesalahan';
        break;
      case CustomSnackbarType.warning:
        accentColor = const Color(0xFFF59E0B);
        iconData = Icons.warning_rounded;
        defaultTitle = 'Perhatian';
        break;
      case CustomSnackbarType.info:
        accentColor = const Color(0xFF3B82F6);
        iconData = Icons.info_rounded;
        defaultTitle = 'Informasi';
        break;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E1E26) : Colors.white;
    final textCol = isDark ? Colors.white : const Color(0xFF191924);
    final borderCol = isDark ? const Color(0xFF2E2E38) : const Color(0xFFE5E7EB);

    messenger.showSnackBar(
      SnackBar(
        duration: duration,
        elevation: 0,
        backgroundColor: Colors.transparent,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        padding: EdgeInsets.zero,
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderCol, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.1),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(iconData, color: accentColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title ?? defaultTitle,
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: textCol,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      message,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: textCol.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () {
                    messenger.hideCurrentSnackBar();
                    onAction();
                  },
                  child: Text(
                    actionLabel,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: accentColor,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static void success(BuildContext context, String message, {String? title}) {
    show(context, message: message, title: title, type: CustomSnackbarType.success);
  }

  static void error(BuildContext context, String message, {String? title}) {
    show(context, message: message, title: title, type: CustomSnackbarType.error);
  }

  static void warning(BuildContext context, String message, {String? title}) {
    show(context, message: message, title: title, type: CustomSnackbarType.warning);
  }

  static void info(BuildContext context, String message, {String? title}) {
    show(context, message: message, title: title, type: CustomSnackbarType.info);
  }
}
