import 'package:flutter/material.dart';

import 'web_qr_scanner_stub.dart'
    if (dart.library.js_util) 'web_qr_scanner_web.dart'
    if (dart.library.html) 'web_qr_scanner_web.dart';

Widget buildWebQrScannerWidget({
  required Function(String code) onScanned,
  required bool isFrontCamera,
  required bool isTorchOn,
  required Function(bool isReady, String? statusMessage) onCameraStatusChanged,
  VoidCallback? onCameraSwitch,
}) {
  return buildPlatformWebQrScanner(
    onScanned: onScanned,
    isFrontCamera: isFrontCamera,
    isTorchOn: isTorchOn,
    onCameraStatusChanged: onCameraStatusChanged,
    onCameraSwitch: onCameraSwitch,
  );
}
