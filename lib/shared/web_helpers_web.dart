import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

class WebStorageHelper {
  static void setItem(String key, String value) {
    web.window.localStorage.setItem(key, value);
  }

  static String? getItem(String key) {
    return web.window.localStorage.getItem(key);
  }

  static void removeItem(String key) {
    web.window.localStorage.removeItem(key);
  }

  static Future<void> openBlobUrl(String url, List<int> bytes, String mimeType) async {
    try {
      final jsBytes = Uint8List.fromList(bytes).toJS;
      final blob = web.Blob([jsBytes].toJS, web.BlobPropertyBag(type: mimeType));
      final blobUrl = web.URL.createObjectURL(blob);
      web.window.open(blobUrl, '_blank');
      Future.delayed(const Duration(seconds: 60), () {
        web.URL.revokeObjectURL(blobUrl);
      });
    } catch (_) {
      web.window.open(url, '_blank');
    }
  }
}
