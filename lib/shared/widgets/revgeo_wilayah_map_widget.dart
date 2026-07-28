import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mapotech/shared/widgets/location_selector_widget.dart';
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

  @override
  void initState() {
    super.initState();
    _selectedProvince = widget.initialProvince;
    _selectedRegency = widget.initialDistrict;
    _selectedDistrict = widget.initialSubDistrict;
    _selectedVillage = widget.initialVillage;
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
    }
  }

  String _cleanRegion(String raw) {
    return raw
        .replaceAll(RegExp(r'^(PROVINSI|PROV\.?|KABUPATEN|KAB\.?|KOTA|KECAMATAN|KEC\.?|KELURAHAN|KEL\.?|DESA)\s+', caseSensitive: false), '')
        .trim();
  }

  /// Builds a clean HTML document string that loads ONLY Leaflet map canvas (no header, no form controls)
  /// and automatically fetches & draws the GeoJSON boundary highlight for the selected district.
  String _buildCleanLeafletHtmlDataUri() {
    final cleanProv = _cleanRegion(_selectedProvince);
    final cleanReg = _cleanRegion(_selectedRegency);
    final cleanDist = _cleanRegion(_selectedDistrict);
    final colorHex = _highlightColorHex;
    final isDark = widget.isDark;

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
  </style>
</head>
<body>
  <div id="map"></div>
  <script>
    const map = L.map('map', { zoomControl: true }).setView([-2.5489, 118.0149], 5);
    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      maxZoom: 19,
      attribution: '&copy; OpenStreetMap contributors'
    }).addTo(map);

    let currentLayer = null;

    function cleanName(str) {
      if (!str) return '';
      return str.toString().toUpperCase()
        .replace(/^(PROVINSI|PROV|KABUPATEN|KAB|KOTA|KECAMATAN|KEC|KELURAHAN|DESA)\\.?\\s+/i, '')
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
            fillOpacity: 0.35
          }
        }).addTo(map);

        map.fitBounds(currentLayer.getBounds(), { padding: [30, 30] });

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
              fillOpacity: 0.35
            }
          }).addTo(map);
          map.fitBounds(currentLayer.getBounds(), { padding: [30, 30] });
        }
      } catch (e) {}
    }

    loadDistrictBoundary("${cleanProv.replaceAll('"', '')}", "${cleanReg.replaceAll('"', '')}", "${cleanDist.replaceAll('"', '')}", "${colorHex}");
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
                  color: widget.themeAccent.withOpacity(0.12),
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
                  color: const Color(0xFF1ABC9C).withOpacity(0.15),
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
          Container(
            height: widget.height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: widget.borderColor),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                KeyedSubtree(
                  key: ValueKey('map_key_${_selectedProvince}_${_selectedRegency}_${_selectedDistrict}_${_highlightColorHex}_$_refreshKey'),
                  child: buildWebMapWidget(
                    mapUrl: _buildCleanLeafletHtmlDataUri(),
                    isDark: widget.isDark,
                  ),
                ),

                // Floating Overlay Badge for Active District Location
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: (widget.isDark ? Colors.black : Colors.white).withOpacity(0.9),
                      borderRadius: BorderRadius.circular(100),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
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
          ),
        ],
      ),
    );
  }
}
