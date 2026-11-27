import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapotech/shared/session_connection_service.dart';

/// Persistent post-login banner shown inside DashboardShell when the connection drops.
class SessionConnectionBanner extends StatelessWidget {
  final SessionConnectionState connectionState;
  final bool isEnglish;
  final bool isDark;
  final VoidCallback onReconnect;
  final VoidCallback onDismiss;

  const SessionConnectionBanner({
    super.key,
    required this.connectionState,
    required this.isEnglish,
    required this.isDark,
    required this.onReconnect,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final isReconnecting = connectionState.isReconnecting;
    final accentColor = isReconnecting
        ? const Color(0xFFF59E0B)
        : const Color(0xFFEF4444);
    final bgColor = isDark
        ? (isReconnecting ? const Color(0xFF2B2212) : const Color(0xFF2B1619))
        : (isReconnecting ? const Color(0xFFFFFBEB) : const Color(0xFFFEF2F2));
    final borderColor = accentColor.withValues(alpha: isDark ? 0.45 : 0.35);
    final textColor = isDark ? Colors.white : const Color(0xFF1F2937);
    final subTextColor = isDark
        ? Colors.white.withValues(alpha: 0.78)
        : const Color(0xFF4B5563);

    final title = isReconnecting
        ? (isEnglish ? 'Reconnecting...' : 'Menghubungkan ulang...')
        : (isEnglish ? 'You are disconnected' : 'Anda terputus dari koneksi');
    final subtitle = isReconnecting
        ? (isEnglish
              ? 'Restoring your connection without logging in from the start.'
              : 'Memulihkan koneksi tanpa perlu login dari awal lagi.')
        : (isEnglish
              ? 'Your login session is preserved. Click Reconnect without logging in again.'
              : 'Sesi login Anda tetap tersimpan. Klik Hubungkan Ulang tanpa login dari awal.');
    final reconnectLabel = isReconnecting
        ? (isEnglish ? 'Reconnecting...' : 'Menyambung...')
        : (isEnglish ? 'Reconnect' : 'Hubungkan Ulang');

    return Material(
      color: bgColor,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: borderColor, width: 1)),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 640;
            final messageBlock = Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: isReconnecting
                      ? Padding(
                          padding: const EdgeInsets.all(8),
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              accentColor,
                            ),
                          ),
                        )
                      : Icon(Icons.wifi_off_rounded, color: accentColor, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        subtitle,
                        style: GoogleFonts.outfit(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: subTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );

            final actions = Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton.icon(
                  onPressed: isReconnecting ? null : onReconnect,
                  icon: isReconnecting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.refresh_rounded, size: 16),
                  label: Text(
                    reconnectLabel,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: accentColor.withValues(alpha: 0.6),
                    disabledForegroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    minimumSize: const Size(0, 34),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: onDismiss,
                  icon: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: subTextColor,
                  ),
                  tooltip: isEnglish ? 'Minimize' : 'Sembunyikan',
                  visualDensity: VisualDensity.compact,
                ),
              ],
            );

            if (isCompact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  messageBlock,
                  const SizedBox(height: 8),
                  Align(alignment: Alignment.centerRight, child: actions),
                ],
              );
            }

            return Row(
              children: [
                Expanded(child: messageBlock),
                const SizedBox(width: 12),
                actions,
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Compact indicator pill in the Top Bar when disconnected or reconnecting.
class SessionConnectionTopBarPill extends StatelessWidget {
  final SessionConnectionState connectionState;
  final bool isEnglish;
  final bool isCompact;
  final VoidCallback onReconnect;

  const SessionConnectionTopBarPill({
    super.key,
    required this.connectionState,
    required this.isEnglish,
    required this.isCompact,
    required this.onReconnect,
  });

  @override
  Widget build(BuildContext context) {
    final isReconnecting = connectionState.isReconnecting;
    final color = isReconnecting
        ? const Color(0xFFF59E0B)
        : const Color(0xFFEF4444);

    final label = isReconnecting
        ? (isEnglish ? 'Reconnecting...' : 'Menyambung...')
        : (isEnglish ? 'Disconnected • Reconnect' : 'Terputus • Sambungkan');

    return Tooltip(
      message: isEnglish
          ? 'You are disconnected. Click to reconnect without logging in again.'
          : 'Anda terputus. Klik untuk menghubungkan ulang tanpa login ulang.',
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        child: InkWell(
          onTap: isReconnecting ? null : onReconnect,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 28,
            padding: EdgeInsets.symmetric(horizontal: isCompact ? 8 : 10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withValues(alpha: 0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isReconnecting)
                  SizedBox(
                    width: 13,
                    height: 13,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  )
                else
                  Icon(Icons.wifi_off_rounded, size: 14, color: color),
                if (!isCompact) ...[
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
