import 'package:flutter/material.dart';

import 'web_map_widget_stub.dart'
    if (dart.library.js_util) 'web_map_widget_web.dart'
    if (dart.library.html) 'web_map_widget_web.dart';

Widget buildWebMapWidget({
  required String mapUrl,
  required bool isDark,
}) {
  return buildPlatformWebMap(mapUrl: mapUrl, isDark: isDark);
}
