import 'dart:typed_data';
import 'dart:ui';

typedef PcvFrame = ({Uint8List bytes, int width, int height});

({int left, int top, int width, int height}) pcvPixelCrop(
  PcvFrame frame,
  Rect area,
) {
  final left = (area.left * frame.width).round().clamp(0, frame.width - 1);
  final top = (area.top * frame.height).round().clamp(0, frame.height - 1);
  final right = (area.right * frame.width).round().clamp(left + 1, frame.width);
  final bottom = (area.bottom * frame.height).round().clamp(
    top + 1,
    frame.height,
  );
  return (left: left, top: top, width: right - left, height: bottom - top);
}
