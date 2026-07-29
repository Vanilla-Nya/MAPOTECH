import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class GeoBoundaryResult {
  final List<List<LatLng>> polygons;
  final LatLng? centerPoint;
  final String displayName;

  const GeoBoundaryResult({
    required this.polygons,
    this.centerPoint,
    this.displayName = '',
  });
}

class GeoBoundaryService {
  /// Default fallback polygon coordinates specifically for Kecamatan SUMBER WRINGIN, BONDOWOSO
  static const List<LatLng> sumberWringinPolygon = [
    LatLng(-7.9420, 113.8850),
    LatLng(-7.9650, 113.9100),
    LatLng(-7.9900, 113.9250),
    LatLng(-8.0300, 113.9450),
    LatLng(-8.0750, 113.9600),
    LatLng(-8.1100, 113.9450),
    LatLng(-8.0700, 113.9150),
    LatLng(-8.0200, 113.8950),
    LatLng(-7.9800, 113.8750),
    LatLng(-7.9550, 113.8650),
  ];

  static String _cleanName(String raw) {
    return raw
        .replaceAll(RegExp(r'^(PROVINSI|PROV\.?|KABUPATEN|KAB\.?|KOTA|KECAMATAN|KEC\.?|KELURAHAN|KEL\.?|DESA)\s+', caseSensitive: false), '')
        .trim()
        .toUpperCase();
  }

  /// Fetches real administrative boundary polygon coordinates for a specific Kecamatan
  /// using RevGeo API (Relvastudio Indonesian Wilayah GeoJSON) and OpenStreetMap Nominatim fallback.
  static Future<GeoBoundaryResult> fetchKecamatanBoundary({
    required String province,
    required String regency,
    required String subDistrict,
    double? latitude,
    double? longitude,
  }) async {
    final cleanProv = _cleanName(province);
    final cleanReg = _cleanName(regency);
    final cleanDist = _cleanName(subDistrict);

    // 1. Try RevGeo API (relvastudio.com) for exact Indonesian Kecamatan boundaries
    try {
      final provRes = await http
          .get(Uri.parse('https://revgeo.relvastudio.com/provinces.json'))
          .timeout(const Duration(seconds: 4));

      if (provRes.statusCode == 200) {
        final List provList = jsonDecode(provRes.body);
        dynamic targetProv;
        for (final p in provList) {
          if (_cleanName(p['name']?.toString() ?? '') == cleanProv) {
            targetProv = p;
            break;
          }
        }

        if (targetProv != null && targetProv['folderName'] != null) {
          final String provFolder = targetProv['folderName'].toString();
          final regRes = await http
              .get(Uri.parse('https://revgeo.relvastudio.com/provinces/$provFolder.json'))
              .timeout(const Duration(seconds: 4));

          if (regRes.statusCode == 200) {
            final Map<String, dynamic> regData = jsonDecode(regRes.body);
            final List dists = regData['districts'] ?? [];
            dynamic targetReg;
            for (final r in dists) {
              if (_cleanName(r['name']?.toString() ?? '') == cleanReg) {
                targetReg = r;
                break;
              }
            }

            if (targetReg != null && targetReg['folderName'] != null) {
              final String regFolder = targetReg['folderName'].toString();
              final dataRes = await http
                  .get(Uri.parse('https://revgeo.relvastudio.com/provinces/$provFolder/$regFolder/data.json'))
                  .timeout(const Duration(seconds: 4));

              if (dataRes.statusCode == 200) {
                final Map<String, dynamic> geoJsonData = jsonDecode(dataRes.body);
                if (geoJsonData['type'] == 'FeatureCollection' && geoJsonData['features'] != null) {
                  final List features = geoJsonData['features'];
                  dynamic matchedFeature;
                  for (final f in features) {
                    final props = f['properties'] ?? {};
                    final dName = props['district'] ?? props['NAMOBJ'] ?? props['WADMKC'] ?? f['name'] ?? '';
                    if (_cleanName(dName.toString()) == cleanDist) {
                      matchedFeature = f;
                      break;
                    }
                  }

                  if (matchedFeature != null) {
                    final polys = _extractPolygonsFromGeoJson(matchedFeature as Map<String, dynamic>);
                    if (polys.isNotEmpty) {
                      final center = _calculateCentroid(polys.first);
                      return GeoBoundaryResult(
                        polygons: polys,
                        centerPoint: center,
                        displayName: 'Kecamatan $cleanDist, $cleanReg',
                      );
                    }
                  }
                }
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('RevGeo API fetch error: $e');
    }

    // 2. Try Nominatim Search targeting subdistrict level specifically
    try {
      final query = 'Kecamatan $cleanDist, $cleanReg, $cleanProv, Indonesia';
      final encodedQuery = Uri.encodeComponent(query);
      final searchUrl = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=$encodedQuery&format=json&polygon_geojson=1&limit=3',
      );

      final response = await http.get(
        searchUrl,
        headers: {'User-Agent': 'MAPOTECH-HealthApp/1.0 (contact@mapotech.app)'},
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        for (final item in data) {
          final String disp = (item['display_name'] ?? '').toString();
          if (disp.toLowerCase().contains(cleanDist.toLowerCase()) && item['geojson'] != null) {
            final polys = _extractPolygonsFromGeoJson(item['geojson'] as Map<String, dynamic>);
            if (polys.isNotEmpty) {
              LatLng? center;
              if (item['lat'] != null && item['lon'] != null) {
                final lat = double.tryParse(item['lat'].toString());
                final lon = double.tryParse(item['lon'].toString());
                if (lat != null && lon != null) center = LatLng(lat, lon);
              }
              return GeoBoundaryResult(
                polygons: polys,
                centerPoint: center ?? _calculateCentroid(polys.first),
                displayName: 'Kecamatan $cleanDist, $cleanReg',
              );
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Nominatim subdistrict search error: $e');
    }

    // 3. Fallback to default Kecamatan SUMBER WRINGIN polygon
    return GeoBoundaryResult(
      polygons: [sumberWringinPolygon],
      centerPoint: latitude != null && longitude != null ? LatLng(latitude, longitude) : const LatLng(-7.9797, 113.8228),
      displayName: 'Kecamatan $subDistrict, $regency',
    );
  }

  static LatLng _calculateCentroid(List<LatLng> points) {
    if (points.isEmpty) return const LatLng(-7.9797, 113.8228);
    double sumLat = 0;
    double sumLng = 0;
    for (final p in points) {
      sumLat += p.latitude;
      sumLng += p.longitude;
    }
    return LatLng(sumLat / points.length, sumLng / points.length);
  }

  static List<List<LatLng>> _extractPolygonsFromGeoJson(Map<String, dynamic> geojson) {
    List<List<LatLng>> results = [];
    final type = geojson['type'];
    final coords = geojson['coordinates'];

    if (coords == null) return results;

    if (type == 'Polygon' && coords is List) {
      if (coords.isNotEmpty && coords.first is List) {
        final List<LatLng> ring = [];
        for (final pt in coords.first) {
          if (pt is List && pt.length >= 2) {
            final double lng = (pt[0] as num).toDouble();
            final double lat = (pt[1] as num).toDouble();
            ring.add(LatLng(lat, lng));
          }
        }
        if (ring.isNotEmpty) results.add(ring);
      }
    } else if (type == 'MultiPolygon' && coords is List) {
      for (final poly in coords) {
        if (poly is List && poly.isNotEmpty && poly.first is List) {
          final List<LatLng> ring = [];
          for (final pt in poly.first) {
            if (pt is List && pt.length >= 2) {
              final double lng = (pt[0] as num).toDouble();
              final double lat = (pt[1] as num).toDouble();
              ring.add(LatLng(lat, lng));
            }
          }
          if (ring.isNotEmpty) results.add(ring);
        }
      }
    } else if (type == 'Feature' && geojson['geometry'] != null) {
      return _extractPolygonsFromGeoJson(geojson['geometry'] as Map<String, dynamic>);
    }
    return results;
  }
}
