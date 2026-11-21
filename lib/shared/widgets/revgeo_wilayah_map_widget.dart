import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mapotech/shared/widgets/location_selector_widget.dart';
import 'package:mapotech/shared/geo_boundary_service.dart';
import 'package:mapotech/shared/widgets/custom_lazy_loader.dart';
import 'package:mapotech/shared/widgets/skeleton_loading.dart';
import 'package:mapotech/features/dokter/dashboard/frontend/web_map_widget.dart';

/// Reusable Wilayah Kerja & Batas Geografis Map Widget.
/// Uses Flutter Searchable Dropdowns for Location Selection,
/// and renders a clean Leaflet Street Map Canvas (No headers/duplicate form dropdowns)
/// with automatic boundary polygon highlighting for the selected subdistrict (Kecamatan).
class RevGeoWilayahMapWidget extends StatefulWidget {
  final String initialProvince;
  final String initialDistrict; // Kota/Kabupaten
  final String initialSubDistrict; // Kecamatan
  final String initialVillage; // Kelurahan/Desa
  final String revgeoApiUrl;
  final double height;
  final Color fieldBg;
  final Color textColor;
  final Color subtitleColor;
  final Color borderColor;
  final Color dropdownColor;
  final Color themeAccent;
  final bool isDark;
  final bool isEn;
  final bool showOnlyMap;
  final List<Map<String, dynamic>>? markers;
  final void Function(Map<String, dynamic> markerData)? onMarkerTap;
  final Function(String province, String district, String subDistrict, String village) onChanged;

  const RevGeoWilayahMapWidget({
    super.key,
    this.initialProvince = '',
    this.initialDistrict = '',
    this.initialSubDistrict = '',
    this.initialVillage = '',
    this.revgeoApiUrl = 'https://revgeo.relvastudio.com/',
    this.height = 380,
    required this.fieldBg,
    required this.textColor,
    required this.subtitleColor,
    required this.borderColor,
    required this.dropdownColor,
    required this.themeAccent,
    required this.isDark,
    required this.isEn,
    this.showOnlyMap = false,
    this.markers,
    this.onMarkerTap,
    required this.onChanged,
  });

  @override
  State<RevGeoWilayahMapWidget> createState() => _RevGeoWilayahMapWidgetState();
}

class _RevGeoWilayahMapWidgetState extends State<RevGeoWilayahMapWidget> {
  late String _selectedProvince;
  late String _selectedRegency;
  late String _selectedDistrict;
  late String _selectedVillage;

  String _highlightColorHex = '#E91E63'; // Crimson/Pink default highlight
  int _refreshKey = 0;

  final MapController _nativeMapController = MapController();
  List<List<LatLng>> _nativeBoundaryPolygons = [];
  LatLng? _nativeCentroid;
  bool _isLoadingBoundary = false;

  bool _isMapLazyReady = false;
  double _lazyProgress = 0.05;
  Timer? _lazyProgressTimer;
  Map<String, dynamic>? _activeSelectedMarker;

  @override
  void initState() {
    super.initState();
    _selectedProvince = widget.initialProvince;
    _selectedRegency = widget.initialDistrict;
    _selectedDistrict = widget.initialSubDistrict;
    _selectedVillage = widget.initialVillage;
    _startLazyLoading();
    if (!kIsWeb) {
      _fetchRevGeoBoundary();
    }
  }

  @override
  void dispose() {
    _lazyProgressTimer?.cancel();
    super.dispose();
  }

  void _startLazyLoading() {
    _lazyProgressTimer?.cancel();
    _lazyProgress = 0.08;
    _isMapLazyReady = false;

    const totalTicks = 14;
    int tick = 0;
    _lazyProgressTimer = Timer.periodic(const Duration(milliseconds: 25), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      tick++;
      final double progress = (tick / totalTicks).clamp(0.08, 1.0);
      setState(() {
        _lazyProgress = progress;
      });
      if (tick >= totalTicks) {
        timer.cancel();
        Future.delayed(const Duration(milliseconds: 90), () {
          if (mounted) {
            setState(() {
              _isMapLazyReady = true;
            });
          }
        });
      }
    });
  }

  @override
  void didUpdateWidget(covariant RevGeoWilayahMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialProvince != oldWidget.initialProvince ||
        widget.initialDistrict != oldWidget.initialDistrict ||
        widget.initialSubDistrict != oldWidget.initialSubDistrict ||
        widget.initialVillage != oldWidget.initialVillage) {
      setState(() {
        _selectedProvince = widget.initialProvince;
        _selectedRegency = widget.initialDistrict;
        _selectedDistrict = widget.initialSubDistrict;
        _selectedVillage = widget.initialVillage;
      });
      if (!kIsWeb) {
        _fetchRevGeoBoundary();
      }
    }
  }

  Color _hexToColor(String hex) {
    final clean = hex.replaceAll('#', '');
    if (clean.length == 6) {
      return Color(int.parse('0xFF$clean'));
    }
    return const Color(0xFFE91E63);
  }

  Future<void> _fetchRevGeoBoundary() async {
    final cleanDist = _cleanRegion(_selectedDistrict);
    if (cleanDist.isEmpty) {
      if (mounted) {
        setState(() {
          _nativeBoundaryPolygons = [];
          _nativeCentroid = null;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isLoadingBoundary = true;
      });
    }

    try {
      final result = await GeoBoundaryService.fetchKecamatanBoundary(
        province: _selectedProvince.isNotEmpty ? _selectedProvince : 'Jawa Timur',
        regency: _selectedRegency.isNotEmpty ? _selectedRegency : 'Bondowoso',
        subDistrict: _selectedDistrict.isNotEmpty ? _selectedDistrict : 'Sumber Wringin',
      );

      if (mounted) {
        setState(() {
          _nativeBoundaryPolygons = result.polygons;
          _nativeCentroid = result.centerPoint;
          _isLoadingBoundary = false;
        });

        if (result.polygons.isNotEmpty) {
          final allPoints = result.polygons.expand((p) => p).toList();
          if (allPoints.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              try {
                _nativeMapController.fitCamera(
                  CameraFit.bounds(
                    bounds: LatLngBounds.fromPoints(allPoints),
                    padding: const EdgeInsets.all(40),
                  ),
                );
              } catch (_) {}
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingBoundary = false;
        });
      }
    }
  }

  Widget _buildNativeFlutterMap() {
    final targetColor = _hexToColor(_highlightColorHex);
    final center = _nativeCentroid ?? const LatLng(-7.973, 113.880);

    final List<Marker> flutterMarkers = [];

    // Sub-district centroid marker
    flutterMarkers.add(
      Marker(
        point: center,
        width: 44,
        height: 44,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: targetColor.withValues(alpha: 0.4),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Icon(
            Icons.location_on_rounded,
            color: targetColor,
            size: 40,
          ),
        ),
      ),
    );

    // Patient pins from widget.markers
    if (widget.markers != null && widget.markers!.isNotEmpty) {
      for (final m in widget.markers!) {
        final lat = double.tryParse(m['lat']?.toString() ?? '');
        final lng = double.tryParse(m['lng']?.toString() ?? '');
        if (lat != null && lng != null) {
          final pinColor = m['color'] != null
              ? _hexToColor(m['color'].toString())
              : targetColor;

          final cleanInfo = (m['info'] ?? '')
              .toString()
              .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
              .trim();
          final titleStr = (m['title'] ?? 'Pasien').toString();
          final tooltipMsg = '$titleStr\n$cleanInfo\n👉 Klik untuk detail pasien';

          flutterMarkers.add(
            Marker(
              point: LatLng(lat, lng),
              width: 42,
              height: 42,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _activeSelectedMarker = m;
                  });
                  widget.onMarkerTap?.call(m);
                },
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Tooltip(
                    message: tooltipMsg,
                    preferBelow: false,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B).withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    textStyle: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: pinColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2.5),
                        boxShadow: [
                          BoxShadow(
                            color: pinColor.withValues(alpha: 0.4),
                            blurRadius: 8,
                            spreadRadius: 2,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.person_pin_circle_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }
      }
    }

    return Stack(
      children: [
        FlutterMap(
          mapController: _nativeMapController,
          options: MapOptions(
            initialCenter: center,
            initialZoom: 13.0,
            minZoom: 4.0,
            maxZoom: 18.0,
          ),
          children: [
            TileLayer(
              urlTemplate: widget.isDark
                  ? 'https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Dark_Gray_Base/MapServer/tile/{z}/{y}/{x}'
                  : 'https://tile.openstreetmap.de/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.mapotech.app',
            ),
            if (_nativeBoundaryPolygons.isNotEmpty)
              PolygonLayer(
                polygons: _nativeBoundaryPolygons.map((polyPoints) {
                  return Polygon(
                    points: polyPoints,
                    color: targetColor.withValues(alpha: 0.25),
                    borderColor: targetColor,
                    borderStrokeWidth: 3.5,
                    isFilled: true,
                  );
                }).toList(),
              ),
            MarkerLayer(markers: flutterMarkers),
          ],
        ),

        // Floating Patient Callout Mini-Card if pin selected
        if (_activeSelectedMarker != null)
          Positioned(
            top: 50,
            left: 14,
            right: 14,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: (widget.isDark ? const Color(0xFF1B1B22) : Colors.white)
                      .withValues(alpha: 0.96),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _hexToColor(_activeSelectedMarker!['color']?.toString() ?? '#E91E63'),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _hexToColor(_activeSelectedMarker!['color']?.toString() ?? '#E91E63')
                            .withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.pregnant_woman_rounded,
                        color: _hexToColor(_activeSelectedMarker!['color']?.toString() ?? '#E91E63'),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  (_activeSelectedMarker!['title'] ?? 'Pasien')
                                      .toString()
                                      .replaceAll('🤰', '')
                                      .trim(),
                                  style: GoogleFonts.outfit(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                    color: widget.textColor,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (_activeSelectedMarker!['subtitle'] != null) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _hexToColor(_activeSelectedMarker!['color']?.toString() ?? '#E91E63')
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    _activeSelectedMarker!['subtitle'].toString(),
                                    style: GoogleFonts.outfit(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.bold,
                                      color: _hexToColor(_activeSelectedMarker!['color']?.toString() ?? '#E91E63'),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            (_activeSelectedMarker!['info'] ?? '')
                                .toString()
                                .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '  •  ')
                                .trim(),
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              color: widget.subtitleColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.themeAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      onPressed: () {
                        widget.onMarkerTap?.call(_activeSelectedMarker!);
                      },
                      icon: const Icon(Icons.open_in_new_rounded, size: 12),
                      label: Text(
                        widget.isEn ? 'Open ANC Data' : 'Buka Detail',
                        style: GoogleFonts.outfit(fontSize: 10.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 16),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                      onPressed: () {
                        setState(() {
                          _activeSelectedMarker = null;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),

        if (_isLoadingBoundary)
          Positioned(
            bottom: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: (widget.isDark ? Colors.black87 : Colors.white)
                    .withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(100),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(targetColor),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Loading Batas RevGeo...',
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: widget.textColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  String _cleanRegion(String raw) {
    return raw
        .replaceAll(RegExp(r'^(PROVINSI|PROV\.?|KABUPATEN|KAB\.?|KOTA|KECAMATAN|KEC\.?|KELURAHAN|KEL\.?|DESA)\s+', caseSensitive: false), '')
        .trim();
  }

  /// Builds a clean HTML document string that loads ONLY Leaflet map canvas (no header, no form controls)
  /// and automatically fetches & draws the GeoJSON boundary highlight for the selected district,
  /// as well as any custom patient location pins.
  String _buildCleanLeafletHtmlDataUri() {
    final cleanProv = _cleanRegion(_selectedProvince);
    final cleanReg = _cleanRegion(_selectedRegency);
    final cleanDist = _cleanRegion(_selectedDistrict);
    final colorHex = _highlightColorHex;
    final isDark = widget.isDark;

    final markersJson = jsonEncode(widget.markers ?? []);

    final htmlContent = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Batas Wilayah Map</title>
  <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" />
  <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
  <style>
    html, body, #map {
      width: 100%;
      height: 100%;
      margin: 0;
      padding: 0;
      background: ${isDark ? '#0f172a' : '#f8fafc'};
      overflow: hidden;
    }
    .leaflet-container {
      background: ${isDark ? '#1e293b' : '#e2e8f0'};
    }
    @keyframes pinPulse {
      0% { transform: scale(0.6); opacity: 0.8; }
      100% { transform: scale(1.7); opacity: 0; }
    }
    .custom-pin-container {
      position: relative;
      width: 32px;
      height: 32px;
    }
    .custom-pin-pulse {
      position: absolute;
      width: 32px;
      height: 32px;
      border-radius: 50%;
      animation: pinPulse 2s infinite ease-out;
    }
    .custom-pin-body {
      position: absolute;
      top: 4px;
      left: 4px;
      width: 24px;
      height: 24px;
      border-radius: 50% 50% 50% 0;
      transform: rotate(-45deg);
      border: 2px solid #ffffff;
      box-shadow: 0 4px 10px rgba(0,0,0,0.35);
      display: flex;
      align-items: center;
      justify-content: center;
    }
    .custom-pin-dot {
      width: 8px;
      height: 8px;
      background: #ffffff;
      border-radius: 50%;
    }
  </style>
</head>
<body>
  <div id="map"></div>
  <script>
    const map = L.map('map', { zoomControl: true }).setView([-7.96, 113.91], 13);
    const isDark = ${isDark ? 'true' : 'false'};

    const osmDeLayer = L.tileLayer('https://tile.openstreetmap.de/{z}/{x}/{y}.png', {
      maxZoom: 19,
      attribution: '&copy; <a href="https://www.openstreetmap.org/copyright" target="_blank">OpenStreetMap</a> contributors'
    });

    const osmHotLayer = L.tileLayer('https://{s}.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png', {
      maxZoom: 19,
      subdomains: 'abc',
      attribution: '&copy; <a href="https://www.openstreetmap.org/copyright" target="_blank">OpenStreetMap</a> contributors, Tiles &copy; <a href="https://www.hotosm.org/" target="_blank">HOT</a>'
    });

    const esriStreetLayer = L.tileLayer('https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}', {
      maxZoom: 19,
      attribution: 'Tiles &copy; <a href="https://www.esri.com/" target="_blank">Esri</a>'
    });

    const esriDarkLayer = L.tileLayer('https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Dark_Gray_Base/MapServer/tile/{z}/{y}/{x}', {
      maxZoom: 16,
      attribution: 'Tiles &copy; <a href="https://www.esri.com/" target="_blank">Esri</a>'
    });

    if (isDark) {
      esriDarkLayer.addTo(map);
    } else {
      osmDeLayer.addTo(map);
    }

    const baseMaps = {
      "OpenStreetMap": osmDeLayer,
      "Humanitarian (HOT)": osmHotLayer,
      "Esri Street": esriStreetLayer,
      "Dark Canvas": esriDarkLayer
    };
    L.control.layers(baseMaps, null, { position: 'topright' }).addTo(map);

    let currentLayer = null;

    function cleanName(str) {
      if (!str) return '';
      return str.toString().toUpperCase()
        .replace(/^(PROVINSI|PROV|KABUPATEN|KAB|KOTA|KECAMATAN|KEC|KELURAHAN|DESA)\\\\.?\\\\s+/i, '')
        .trim();
    }

    async function loadDistrictBoundary(provName, regName, distName, hexColor) {
      if (!provName || !regName || !distName) return;

      const targetColor = hexColor || '#E91E63';

      try {
        const provRes = await fetch('https://revgeo.relvastudio.com/provinces.json');
        const provList = await provRes.json();
        
        const targetProv = provList.find(p => cleanName(p.name) === cleanName(provName));
        if (!targetProv) {
          return searchNominatimFallback(distName + ', ' + regName);
        }

        const regRes = await fetch('https://revgeo.relvastudio.com/provinces/' + targetProv.folderName + '.json');
        const regData = await regRes.json();
        
        const targetReg = regData.districts.find(r => cleanName(r.name) === cleanName(regName));
        if (!targetReg) {
          return searchNominatimFallback(distName + ', ' + regName);
        }

        const dataRes = await fetch('https://revgeo.relvastudio.com/provinces/' + targetProv.folderName + '/' + targetReg.folderName + '/data.json');
        const geoJsonData = await dataRes.json();

        let districtData = null;
        if (geoJsonData.type === 'FeatureCollection' && geoJsonData.features) {
          const matchedFeature = geoJsonData.features.find(f => {
            const props = f.properties || (f.features && f.features[0] && f.features[0].properties) || {};
            const dName = props.district || props.NAMOBJ || props.WADMKC || f.name || '';
            return cleanName(dName) === cleanName(distName);
          });
          if (matchedFeature) {
            districtData = matchedFeature;
          }
        }

        if (!districtData) {
          districtData = geoJsonData;
        }

        if (currentLayer) map.removeLayer(currentLayer);

        currentLayer = L.geoJSON(districtData, {
          style: {
            color: targetColor,
            weight: 3.5,
            fillColor: targetColor,
            fillOpacity: 0.25
          }
        }).addTo(map);

        if (!window.hasMarkerBounds) {
          map.fitBounds(currentLayer.getBounds(), { padding: [30, 30] });
        }

      } catch (err) {
        console.warn('RevGeo fetch fallback:', err);
        searchNominatimFallback(distName + ', ' + regName);
      }
    }

    async function searchNominatimFallback(query) {
      try {
        const res = await fetch('https://nominatim.openstreetmap.org/search?q=' + encodeURIComponent(query) + '&format=geojson&polygon_geojson=1');
        const data = await res.json();
        if (data && data.features && data.features.length > 0) {
          if (currentLayer) map.removeLayer(currentLayer);
          currentLayer = L.geoJSON(data.features[0], {
            style: {
              color: '${colorHex}',
              weight: 3.5,
              fillColor: '${colorHex}',
              fillOpacity: 0.25
            }
          }).addTo(map);
          if (!window.hasMarkerBounds) {
            map.fitBounds(currentLayer.getBounds(), { padding: [30, 30] });
          }
        }
      } catch (e) {}
    }

    loadDistrictBoundary("${cleanProv.replaceAll('"', '')}", "${cleanReg.replaceAll('"', '')}", "${cleanDist.replaceAll('"', '')}", "${colorHex}");

    // Render Patient Pins
    const rawMarkersData = ${markersJson};
    window.hasMarkerBounds = false;
    if (Array.isArray(rawMarkersData) && rawMarkersData.length > 0) {
      const markerBounds = [];
      rawMarkersData.forEach(m => {
        if (m.lat && m.lng) {
          const lat = parseFloat(m.lat);
          const lng = parseFloat(m.lng);
          const color = m.color || '#E91E63';
          markerBounds.push([lat, lng]);

          const pinIcon = L.divIcon({
            className: 'custom-patient-pin',
            html: \`
              <div class="custom-pin-container">
                <div class="custom-pin-pulse" style="background-color: \${color};"></div>
                <div class="custom-pin-body" style="background-color: \${color};">
                  <div class="custom-pin-dot"></div>
                </div>
              </div>
            \`,
            iconSize: [32, 32],
            iconAnchor: [16, 32],
            popupAnchor: [0, -32]
          });

          const popupHtml = \`
            <div style="font-family: system-ui, -apple-system, sans-serif; padding: 6px 8px; min-width: 190px;">
              <div style="font-size: 13px; font-weight: 800; color: #0f172a; margin-bottom: 2px;">\${m.title || 'Pasien'}</div>
              \${m.subtitle ? \`<div style="display: inline-block; padding: 2px 8px; border-radius: 12px; background-color: \${color}22; color: \${color}; font-size: 10px; font-weight: 700; margin-bottom: 6px;">\${m.subtitle}</div>\` : ''}
              \${m.info ? \`<div style="font-size: 11px; color: #475569; line-height: 1.4;">\${m.info}</div>\` : ''}
              \${m.details ? \`<div style="font-size: 10px; color: #64748b; margin-top: 6px; border-top: 1px dashed #cbd5e1; padding-top: 4px;">\${m.details}</div>\` : ''}
            </div>
          \`;

          L.marker([lat, lng], { icon: pinIcon })
            .addTo(map)
            .bindPopup(popupHtml);
        }
      });

      if (markerBounds.length > 0) {
        window.hasMarkerBounds = true;
        map.fitBounds(markerBounds, { padding: [50, 50], maxZoom: 15 });
      }
    }
  </script>
</body>
</html>
''';

    return Uri.dataFromString(
      htmlContent,
      mimeType: 'text/html',
      encoding: Encoding.getByName('utf-8'),
    ).toString();
  }

  @override
  Widget build(BuildContext context) {
    final cleanDistName = _cleanRegion(_selectedDistrict);
    final isDistrictSelected = cleanDistName.isNotEmpty;

    final mapDisplayWidget = Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: widget.fieldBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: widget.borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // ── Map Canvas (Mounted & Faded in only after lazy progress is ready) ──
          if (_isMapLazyReady)
            AnimatedOpacity(
              opacity: _isMapLazyReady ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
              child: KeyedSubtree(
                key: ValueKey('map_key_${_selectedProvince}_${_selectedRegency}_${_selectedDistrict}_${_highlightColorHex}_${widget.markers?.length ?? 0}_${widget.markers.hashCode}_$_refreshKey'),
                child: kIsWeb
                    ? buildWebMapWidget(
                        mapUrl: _buildCleanLeafletHtmlDataUri(),
                        isDark: widget.isDark,
                      )
                    : _buildNativeFlutterMap(),
              ),
            ),

          // ── Lazy Loading Skeleton & 1-100% Progress Bar (Eliminates Initial Open Lag) ──
          if (!_isMapLazyReady)
            Positioned.fill(
              child: Stack(
                children: [
                  SkeletonMap(
                    height: widget.height,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  Positioned(
                    top: 14,
                    left: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: (widget.isDark ? const Color(0xFF1B1B22) : Colors.white)
                            .withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: widget.borderColor),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: CustomProgressBar(
                        value: _lazyProgress,
                        label: widget.isEn
                            ? 'Loading Territory Boundary & Geotagging Map...'
                            : 'Memuat Peta Wilayah & Geotagging Pasien...',
                        primaryColor: widget.themeAccent,
                        height: 6.0,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Floating Overlay Badge for Active District Location
          if (_isMapLazyReady)
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: (widget.isDark ? Colors.black : Colors.white).withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(100),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.pin_drop_rounded, size: 14, color: widget.themeAccent),
                    const SizedBox(width: 6),
                    Text(
                      isDistrictSelected
                          ? 'Kecamatan $cleanDistName, ${_cleanRegion(_selectedRegency)}'
                          : 'Peta Wilayah Puskesmas',
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: widget.textColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Floating Action Control to Refresh Map
          Positioned(
            bottom: 12,
            right: 12,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.themeAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    elevation: 3,
                  ),
                  onPressed: () {
                    setState(() {
                      _refreshKey++;
                    });
                    _startLazyLoading();
                    if (!kIsWeb) {
                      _fetchRevGeoBoundary();
                    }
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 14),
                  label: Text(
                    'Refresh Map',
                    style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: widget.isDark ? const Color(0xFF2B2B32) : Colors.white,
                    foregroundColor: widget.textColor,
                  ),
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  onPressed: () async {
                    final uri = Uri.parse(widget.revgeoApiUrl);
                    if (await canLaunchUrl(uri)) await launchUrl(uri);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (widget.showOnlyMap) {
      return mapDisplayWidget;
    }

    return Container(
      decoration: BoxDecoration(
        color: widget.fieldBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: widget.borderColor),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header Title & API Badge ─────────────────────────────────────
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: widget.themeAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.map_rounded, color: widget.themeAccent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.isEn ? 'Territory Boundary & Location Selector' : 'Seleksi Wilayah Kerja & Batas Geografis',
                      style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w900, color: widget.textColor),
                    ),
                    Text(
                      widget.isEn
                          ? 'Search location. Selecting district automatically highlights its boundary.'
                          : 'Cari lokasi. Pemilihan Kecamatan otomatis menyorot garis batas wilayah di peta.',
                      style: GoogleFonts.outfit(fontSize: 10, color: widget.subtitleColor),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1ABC9C).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF1ABC9C)),
                    const SizedBox(width: 4),
                    Text(
                      'RevGeo API Active',
                      style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFF1ABC9C)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 14),

          // ── Searchable Location Selector Component ───────────────────────
          LocationSelectorWidget(
            initialProvince: _selectedProvince,
            initialDistrict: _selectedRegency,
            initialSubDistrict: _selectedDistrict,
            initialVillage: _selectedVillage,
            showVillage: false,
            fieldBg: widget.isDark ? const Color(0xFF1B1B1E) : Colors.white,
            textColor: widget.textColor,
            subtitleColor: widget.subtitleColor,
            borderColor: widget.borderColor,
            dropdownColor: widget.isDark ? const Color(0xFF222228) : Colors.white,
            fontSize: 11,
            onChanged: (prov, reg, dist, vill) {
              setState(() {
                _selectedProvince = prov;
                _selectedRegency = reg;
                _selectedDistrict = dist;
                _selectedVillage = vill;
                _refreshKey++;
              });
              if (!kIsWeb) {
                _fetchRevGeoBoundary();
              }
              widget.onChanged(prov, reg, dist, vill);
            },
          ),

          const SizedBox(height: 16),

          // ── Territory Highlight & Color Controls Bar ─────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: widget.isDark ? const Color(0xFF1E1E24) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: widget.borderColor),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        isDistrictSelected ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                        size: 14,
                        color: isDistrictSelected ? const Color(0xFF1ABC9C) : Colors.orangeAccent,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          isDistrictSelected
                              ? 'Sorot Batas Kecamatan: ${cleanDistName.toUpperCase()}'
                              : 'Pilih Kecamatan untuk sorotan otomatis garis batas wilayah',
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: isDistrictSelected ? FontWeight.w900 : FontWeight.w600,
                            color: isDistrictSelected ? widget.textColor : widget.subtitleColor,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Batas Color:',
                  style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: widget.subtitleColor),
                ),
                const SizedBox(width: 6),
                ...[
                  {'hex': '#E91E63', 'color': const Color(0xFFE91E63)},
                  {'hex': '#1ABC9C', 'color': const Color(0xFF1ABC9C)},
                  {'hex': '#3498DB', 'color': const Color(0xFF3498DB)},
                  {'hex': '#F39C12', 'color': const Color(0xFFF39C12)},
                  {'hex': '#9B59B6', 'color': const Color(0xFF9B59B6)},
                ].map((item) {
                  final hex = item['hex'] as String;
                  final c = item['color'] as Color;
                  final isSel = _highlightColorHex == hex;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _highlightColorHex = hex;
                        _refreshKey++;
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.only(left: 5),
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSel ? widget.textColor : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: isSel ? const Icon(Icons.check, size: 10, color: Colors.white) : null,
                    ),
                  );
                }),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Clean Street Map Display (No headers, no duplicate select boxes) ─
          mapDisplayWidget,
        ],
      ),
    );
  }
}
