import 'dart:ui_web' as ui_web;
import 'dart:html' as html;
import 'package:flutter/material.dart';

class WebPlatformMapWidget extends StatefulWidget {
  final String mapUrl;
  final bool isDark;

  const WebPlatformMapWidget({
    super.key,
    required this.mapUrl,
    required this.isDark,
  });

  @override
  State<WebPlatformMapWidget> createState() => _WebPlatformMapWidgetState();
}

class _WebPlatformMapWidgetState extends State<WebPlatformMapWidget> {
  late String _elementId;
  html.IFrameElement? _iframeElement;

  @override
  void initState() {
    super.initState();
    _elementId = 'leaflet-iframe-${widget.mapUrl.hashCode}-${widget.isDark ? "dark" : "light"}';
  }

  void _updatePointerEvents(bool isCurrentRoute) {
    final pointerEvents = isCurrentRoute ? 'auto' : 'none';
    if (_iframeElement != null) {
      _iframeElement!.style.pointerEvents = pointerEvents;
    }
    try {
      final elem = html.document.getElementById(_elementId);
      if (elem != null) {
        elem.style.pointerEvents = pointerEvents;
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final route = ModalRoute.of(context);
    final isCurrentRoute = route?.isCurrent ?? true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updatePointerEvents(isCurrentRoute);
    });

    final String viewType = 'iframe-map-${widget.mapUrl.hashCode}-${widget.isDark ? "dark" : "light"}';

    ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
      final iframe = html.IFrameElement()
        ..id = _elementId
        ..src = widget.mapUrl
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..setAttribute('allowfullscreen', 'true');

      if (widget.isDark) {
        iframe.style.filter = 'invert(90%) hue-rotate(180deg) contrast(1.1) brightness(0.9)';
      }

      _iframeElement = iframe;
      return iframe;
    });

    return Stack(
      children: [
        HtmlElementView(viewType: viewType),
        if (!isCurrentRoute)
          Positioned.fill(
            child: Container(
              color: Colors.transparent,
            ),
          ),
      ],
    );
  }
}

Widget buildPlatformWebMap({
  required String mapUrl,
  required bool isDark,
}) {
  return WebPlatformMapWidget(mapUrl: mapUrl, isDark: isDark);
}
