import 'dart:typed_data';

/// Snapshot image returned from local camera capture.
class PcvCapturedPhoto {
  final Uint8List bytes;
  final String fileName;

  const PcvCapturedPhoto({
    required this.bytes,
    required this.fileName,
  });
}
