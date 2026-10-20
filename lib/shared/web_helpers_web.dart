// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

class WebStorageHelper {
  static void setItem(String key, String value) {
    html.window.localStorage[key] = value;
  }

  static String? getItem(String key) {
    return html.window.localStorage[key];
  }

  static void removeItem(String key) {
    html.window.localStorage.remove(key);
  }

  static Future<void> openBlobUrl(String url, List<int> bytes, String mimeType) async {
    try {
      final blob = html.Blob([bytes], mimeType);
      final blobUrl = html.Url.createObjectUrlFromBlob(blob);
      html.window.open(blobUrl, '_blank');
      Future.delayed(const Duration(seconds: 60), () {
        html.Url.revokeObjectUrl(blobUrl);
      });
    } catch (_) {
      html.window.open(url, '_blank');
    }
  }
}
