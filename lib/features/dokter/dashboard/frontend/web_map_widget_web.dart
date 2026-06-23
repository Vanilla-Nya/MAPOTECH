import 'dart:ui_web' as ui_web;
import 'dart:html' as html;
import 'package:flutter/material.dart';

Widget buildPlatformWebMap({
  required String mapUrl,
  required bool isDark,
}) {
  // Use a unique view type per URL and theme to force iframe reload when changed
  final String viewType = 'iframe-map-${mapUrl.hashCode}-${isDark ? "dark" : "light"}';
  
  // Register the view factory
  ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
    final iframe = html.IFrameElement()
      ..src = mapUrl
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%'
      ..setAttribute('allowfullscreen', 'true');
      
    // Apply CSS filter for premium dark mode look if active
    if (isDark) {
      iframe.style.filter = 'invert(90%) hue-rotate(180deg) contrast(1.1) brightness(0.9)';
    }
    
    return iframe;
  });

  return HtmlElementView(viewType: viewType);
}
