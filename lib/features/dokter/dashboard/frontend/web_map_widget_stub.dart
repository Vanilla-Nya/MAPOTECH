import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

Widget buildPlatformWebMap({
  required String mapUrl,
  required bool isDark,
}) {
  LatLng center = const LatLng(-7.973, 113.880); // Default East Java / Bondowoso center

  try {
    // Attempt to extract lat,lng from data URI or google maps link
    final regex = RegExp(r'(-?\d+\.\d{3,}),\s*(-?\d+\.\d{3,})');
    final match = regex.firstMatch(mapUrl);
    if (match != null) {
      final lat = double.tryParse(match.group(1)!);
      final lng = double.tryParse(match.group(2)!);
      if (lat != null && lng != null) {
        center = LatLng(lat, lng);
      }
    }
  } catch (_) {}

  return ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: FlutterMap(
      options: MapOptions(
        initialCenter: center,
        initialZoom: 13.5,
      ),
      children: [
        TileLayer(
          urlTemplate: isDark
              ? 'https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Dark_Gray_Base/MapServer/tile/{z}/{y}/{x}'
              : 'https://tile.openstreetmap.de/{z}/{x}/{y}.png',
        ),
        MarkerLayer(
          markers: [
            Marker(
              point: center,
              width: 40,
              height: 40,
              child: const Icon(
                Icons.location_on_rounded,
                color: Color(0xFFE74C3C),
                size: 34,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
