import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'pcv_camera_capture_types.dart';

/// Opens the native device camera on mobile platforms (Android/iOS).
Future<PcvCapturedPhoto?> capturePcvCameraSnapshot(BuildContext context) async {
  final isMobileNative =
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  if (!isMobileNative) {
    throw UnsupportedError(
      'Kamera lokal langsung hanya tersedia di browser Web (Chrome/Edge/Firefox) atau perangkat Android/iOS.',
    );
  }

  final picker = ImagePicker();
  final photo = await picker.pickImage(
    source: ImageSource.camera,
    maxWidth: 1920,
    maxHeight: 1080,
    imageQuality: 92,
  );
  if (photo == null) return null;

  final bytes = await photo.readAsBytes();
  final fileName = photo.name.isNotEmpty
      ? photo.name
      : 'kamera_${DateTime.now().millisecondsSinceEpoch}.jpg';

  return PcvCapturedPhoto(bytes: bytes, fileName: fileName);
}
