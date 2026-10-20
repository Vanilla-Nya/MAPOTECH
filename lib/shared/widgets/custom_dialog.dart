import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
