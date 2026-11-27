import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import 'pcv_photo.dart';

Future<PcvFrame?> preparePcvPhoto(Uint8List bytes) => compute(_decode, bytes);

Future<Uint8List> cropPcvPhoto(PcvFrame frame, Rect area) =>
    compute(_crop, (frame, area));

PcvFrame? _decode(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  final image = img.bakeOrientation(decoded);
  return (
    bytes: img.encodeJpg(image, quality: 93),
    width: image.width,
    height: image.height,
  );
}

Uint8List _crop((PcvFrame, Rect) input) {
  final (frame, area) = input;
  final image = img.decodeJpg(frame.bytes);
  if (image == null) throw StateError('Could not decode PCV image');
  final crop = pcvPixelCrop(frame, area);
  return img.encodeJpg(
    img.copyCrop(
      image,
      x: crop.left,
      y: crop.top,
      width: crop.width,
      height: crop.height,
    ),
    quality: 93,
  );
}
