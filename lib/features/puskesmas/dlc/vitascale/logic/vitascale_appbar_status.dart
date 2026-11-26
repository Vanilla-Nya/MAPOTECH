import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

/// Immutable snapshot of VitaScale connectivity/telemetry status surfaced
/// as compact interactive icons in the top AppBar when the user scrolls down
/// past the in-page status strip beneath the stepper.
class VitaScaleAppBarStatus {
  final Object ownerToken;
  final bool showInAppBar;
  final int activeTab;
  final bool isCloudOnline;
  final bool isCheckingCloud;
  final String cloudBaseUrl;
  final bool isMqttConnected;
  final bool isMqttConnecting;
  final String iotStatusLabel;
  final String iotStatusDetail;
  final IconData iotStatusIcon;
  final Color iotStatusColor;
  final int? wifiRssiDbm;
  final double poleHeightCm;
  final bool isGatewayHealthy;
  final double pcvScalePxPerCm;
  final VoidCallback? onPingCloud;
  final VoidCallback? onOpenApiHost;
  final VoidCallback? onToggleMqtt;
  final VoidCallback? onOpenIotSettings;
  final VoidCallback? onSendTare;
  final VoidCallback? onScrollToStatus;

  const VitaScaleAppBarStatus({
    required this.ownerToken,
    required this.showInAppBar,
    required this.activeTab,
    required this.isCloudOnline,
    required this.isCheckingCloud,
    required this.cloudBaseUrl,
    required this.isMqttConnected,
    required this.isMqttConnecting,
    required this.iotStatusLabel,
    required this.iotStatusDetail,
    required this.iotStatusIcon,
    required this.iotStatusColor,
    this.wifiRssiDbm,
    required this.poleHeightCm,
    required this.isGatewayHealthy,
    required this.pcvScalePxPerCm,
    this.onPingCloud,
    this.onOpenApiHost,
    this.onToggleMqtt,
    this.onOpenIotSettings,
    this.onSendTare,
    this.onScrollToStatus,
  });

  bool sameSnapshotAs(VitaScaleAppBarStatus? other) {
    if (other == null) return false;
    return identical(ownerToken, other.ownerToken) &&
        showInAppBar == other.showInAppBar &&
        activeTab == other.activeTab &&
        isCloudOnline == other.isCloudOnline &&
        isCheckingCloud == other.isCheckingCloud &&
        cloudBaseUrl == other.cloudBaseUrl &&
        isMqttConnected == other.isMqttConnected &&
        isMqttConnecting == other.isMqttConnecting &&
        iotStatusLabel == other.iotStatusLabel &&
        iotStatusDetail == other.iotStatusDetail &&
        iotStatusIcon == other.iotStatusIcon &&
        iotStatusColor == other.iotStatusColor &&
        wifiRssiDbm == other.wifiRssiDbm &&
        poleHeightCm == other.poleHeightCm &&
        isGatewayHealthy == other.isGatewayHealthy &&
        pcvScalePxPerCm == other.pcvScalePxPerCm;
  }
}

/// Holds the active VitaScale status snapshot for the top AppBar.
final vitaScaleAppBarStatusProvider = StateProvider<VitaScaleAppBarStatus?>(
  (ref) => null,
);

/// Compact status icon strip rendered in the AppBar when scrolled past
/// the status bar below the stepper.
class VitaScaleAppBarStatusIcons extends StatelessWidget {
  final VitaScaleAppBarStatus status;
  final bool isCompact;
  final Color textColor;
  final Color borderColor;

  const VitaScaleAppBarStatusIcons({
    super.key,
    required this.status,
    required this.isCompact,
    required this.textColor,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final cloudColor = status.isCloudOnline
        ? const Color(0xFF27AE60)
        : const Color(0xFFE74C3C);
    final wifiColor = _resolveWifiColor(status.wifiRssiDbm, status.isMqttConnected);
    final wifiIcon = _resolveWifiIcon(status.wifiRssiDbm, status.isMqttConnected);
    final gatewayColor = status.isGatewayHealthy
        ? const Color(0xFF9B59B6)
        : const Color(0xFF64748B);

    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: borderColor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor.withValues(alpha: 0.7)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StatusIconPill(
            icon: status.isCheckingCloud
                ? Icons.sync_rounded
                : (status.isCloudOnline
                      ? Icons.cloud_done_rounded
                      : Icons.cloud_off_rounded),
            color: cloudColor,
            dotColor: cloudColor,
            label: isCompact ? null : (status.isCloudOnline ? 'Cloud' : 'Offline'),
            tooltip:
                'Cloud AI: ${status.isCloudOnline ? "Terhubung" : "Terputus"} (${status.cloudBaseUrl})\nKlik untuk Ping ulang',
            textColor: textColor,
            onTap: status.onPingCloud,
          ),
          if (status.activeTab == 1) ...[
            const SizedBox(width: 4),
            _StatusIconPill(
              icon: status.iotStatusIcon,
              color: status.iotStatusColor,
              dotColor: status.iotStatusColor,
              label: isCompact ? null : status.iotStatusLabel,
              tooltip:
                  'Status Alat IoT: ${status.iotStatusLabel}\n${status.iotStatusDetail}\nKlik untuk ${status.isMqttConnected ? "Putuskan" : "Hubungkan"} MQTT',
              textColor: textColor,
              onTap: status.onToggleMqtt,
            ),
            const SizedBox(width: 4),
            _StatusIconPill(
              icon: wifiIcon,
              color: wifiColor,
              label: isCompact
                  ? null
                  : (status.wifiRssiDbm != null
                        ? '${status.wifiRssiDbm} dBm'
                        : '-- dBm'),
              tooltip:
                  'Wi-Fi Alat (RSSI): ${status.wifiRssiDbm != null ? "${status.wifiRssiDbm} dBm" : "Offline"}\nGateway Vercel: ${status.isGatewayHealthy ? "Online" : "Siap"}\nTiang Acuan: ${status.poleHeightCm.toStringAsFixed(1)} cm\nKlik untuk Ubah Parameter',
              textColor: textColor,
              onTap: status.onOpenIotSettings,
            ),
            if (!isCompact) ...[
              const SizedBox(width: 4),
              _StatusIconPill(
                icon: Icons.height_rounded,
                color: const Color(0xFF16A085),
                label: '${status.poleHeightCm.toStringAsFixed(0)}cm',
                tooltip:
                    'Tiang Acuan Ultrasonik: ${status.poleHeightCm.toStringAsFixed(1)} cm\nGateway: ${status.isGatewayHealthy ? "Online" : "Siap"}\nKlik untuk Ubah Parameter',
                textColor: textColor,
                onTap: status.onOpenIotSettings,
              ),
              const SizedBox(width: 4),
              _StatusIconPill(
                icon: Icons.public_rounded,
                color: gatewayColor,
                dotColor: gatewayColor,
                tooltip:
                    'Cloud Gateway Vercel: ${status.isGatewayHealthy ? "Online" : "Siap"}\nKlik untuk Pengaturan Gateway & Wi-Fi',
                textColor: textColor,
                onTap: status.onOpenIotSettings,
              ),
            ],
            if (status.isMqttConnected && status.onSendTare != null) ...[
              const SizedBox(width: 4),
              _StatusIconPill(
                icon: Icons.scale_rounded,
                color: const Color(0xFF3498DB),
                tooltip: 'Nol-kan Timbangan (Tare)',
                textColor: textColor,
                onTap: status.onSendTare,
              ),
            ],
          ] else if (status.activeTab == 2) ...[
            const SizedBox(width: 4),
            _StatusIconPill(
              icon: Icons.camera_enhance_rounded,
              color: const Color(0xFF1ABC9C),
              dotColor: const Color(0xFF2ECC71),
              label: isCompact ? null : 'PCV API',
              tooltip:
                  'PCV Vision Cloud API: Online (${status.pcvScalePxPerCm.toStringAsFixed(2)} px/cm)',
              textColor: textColor,
              onTap: status.onScrollToStatus,
            ),
          ],
          if (status.onScrollToStatus != null) ...[
            const SizedBox(width: 4),
            _StatusIconPill(
              icon: Icons.vertical_align_top_rounded,
              color: textColor.withValues(alpha: 0.7),
              tooltip: 'Kembali ke Status Bar & Stepper',
              textColor: textColor,
              onTap: status.onScrollToStatus,
            ),
          ],
        ],
      ),
    );
  }

  static IconData _resolveWifiIcon(int? rssi, bool isConnected) {
    if (!isConnected && rssi == null) return Icons.wifi_off_rounded;
    if (rssi == null || rssi == 0) return Icons.wifi_rounded;
    if (rssi >= -55) return Icons.signal_wifi_4_bar_rounded;
    if (rssi >= -70) return Icons.network_wifi_3_bar_rounded;
    if (rssi >= -82) return Icons.network_wifi_2_bar_rounded;
    return Icons.network_wifi_1_bar_rounded;
  }

  static Color _resolveWifiColor(int? rssi, bool isConnected) {
    if (!isConnected && rssi == null) return const Color(0xFF94A3B8);
    if (rssi == null || rssi == 0) return const Color(0xFF3498DB);
    if (rssi >= -55) return const Color(0xFF27AE60);
    if (rssi >= -70) return const Color(0xFF1ABC9C);
    if (rssi >= -82) return const Color(0xFFF39C12);
    return const Color(0xFFE74C3C);
  }
}

class _StatusIconPill extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color? dotColor;
  final String? label;
  final String tooltip;
  final Color textColor;
  final VoidCallback? onTap;

  const _StatusIconPill({
    required this.icon,
    required this.color,
    this.dotColor,
    this.label,
    required this.tooltip,
    required this.textColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 26,
          padding: EdgeInsets.symmetric(horizontal: label != null ? 7 : 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(icon, size: 15, color: color),
                  if (dotColor != null)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: dotColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1),
                        ),
                      ),
                    ),
                ],
              ),
              if (label != null) ...[
                const SizedBox(width: 5),
                Text(
                  label!,
                  style: GoogleFonts.outfit(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: textColor,
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
