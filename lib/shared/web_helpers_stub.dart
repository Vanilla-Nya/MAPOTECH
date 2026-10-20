class WebStorageHelper {
  static final Map<String, String> _memoryStorage = {};

  static void setItem(String key, String value) {
    _memoryStorage[key] = value;
  }

  static String? getItem(String key) {
    return _memoryStorage[key];
  }

  static void removeItem(String key) {
    _memoryStorage.remove(key);
  }

  static Future<void> openBlobUrl(String url, List<int> bytes, String mimeType) async {
    // Non-web platforms use url_launcher directly
  }
}
