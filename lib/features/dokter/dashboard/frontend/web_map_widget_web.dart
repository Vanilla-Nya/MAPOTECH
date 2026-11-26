import 'dart:js_interop';
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

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
  web.HTMLIFrameElement? _iframeElement;

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
      final elem = web.document.getElementById(_elementId);
      if (elem != null && elem.isA<web.HTMLElement>()) {
        (elem as web.HTMLElement).style.pointerEvents = pointerEvents;
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
      final iframe = web.HTMLIFrameElement()
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
