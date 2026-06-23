import 'package:flutter/material.dart';

Widget buildPlatformWebMap({
  required String mapUrl,
  required bool isDark,
}) {
  // Return a dummy widget since iframe is web-only.
  // The caller will handle showing the fallback vector map.
  return const SizedBox.shrink();
}
