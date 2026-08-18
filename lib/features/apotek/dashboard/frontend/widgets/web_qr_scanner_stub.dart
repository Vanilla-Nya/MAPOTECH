import 'package:flutter/material.dart';

Widget buildPlatformWebQrScanner({
  required Function(String code) onScanned,
  required bool isFrontCamera,
  required bool isTorchOn,
  required Function(bool isReady, String? statusMessage) onCameraStatusChanged,
  required VoidCallback? onCameraSwitch,
}) {
  return Container(
    color: const Color(0xFF0F141C),
    alignment: Alignment.center,
    child: const Text(
      'Kamera scanner hanya tersedia di platform Web / Perangkat berkamera.',
      style: TextStyle(color: Colors.white70, fontSize: 11),
      textAlign: TextAlign.center,
    ),
  );
}
