import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';
import 'dart:ui';

import 'package:web/web.dart' as web;

import 'pcv_photo.dart';

Future<Uint8List> encodePcvCanvasJpeg(
  web.HTMLCanvasElement canvas, {
  double quality = 0.93,
}) async {
  final completion = Completer<web.Blob?>();
  canvas.toBlob(
    ((web.Blob? blob) => completion.complete(blob)).toJS,
    'image/jpeg',
    quality.toJS,
  );
  final blob = await completion.future;
  if (blob == null) throw StateError('Could not encode PCV photo');
  return (await blob.arrayBuffer().toDart).toDart.asUint8List();
}

Future<web.ImageBitmap> _openBitmap(Uint8List bytes) {
  return web.window.createImageBitmap(web.Blob([bytes.toJS].toJS)).toDart;
}

Future<PcvFrame?> preparePcvPhoto(Uint8List bytes) async {
  final bitmap = await _openBitmap(bytes);
  try {
    return (bytes: bytes, width: bitmap.width, height: bitmap.height);
  } finally {
    bitmap.close();
  }
}

Future<Uint8List> cropPcvPhoto(PcvFrame frame, Rect area) async {
  final crop = pcvPixelCrop(frame, area);
  final bitmap = await _openBitmap(frame.bytes);
  final canvas = web.HTMLCanvasElement()
    ..width = crop.width
    ..height = crop.height;
  try {
    final context = canvas.getContext('2d') as web.CanvasRenderingContext2D?;
    if (context == null) throw StateError('Could not open PCV crop canvas');
    context.drawImage(
      bitmap,
      crop.left,
      crop.top,
      crop.width,
      crop.height,
      0,
      0,
      crop.width,
      crop.height,
    );
  } finally {
    bitmap.close();
  }
  return encodePcvCanvasJpeg(canvas);
}
