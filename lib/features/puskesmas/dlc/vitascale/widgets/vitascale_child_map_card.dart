import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapotech/shared/widgets/revgeo_wilayah_map_widget.dart';
import '../data/vitascale_models.dart';

/// Custom Map Card for VitaScale Child & Infant Geotagging.
/// 
/// Integrates RevGeo API and Leaflet Map for spatial distribution of
/// pediatric patients and anthropometric screening targets.
/// 
/// Adheres to:
/// - Rule 1 (Custom UI Mandiri)
/// - Rule 2 (Custom Map & RevGeo API)
/// - Rule 5 (DLC Modular Component)
/// - Rule 6 (Uniformity with Maternal Monitoring)
class VitaScaleChildMapCard extends StatelessWidget {
  final List<ChildProfile> children;
  final Color cardBgColor;
  final Color borderColor;
  final Color textColor;
  final Color subtitleColor;
  final Color themeAccent;
  final bool isDark;
  final bool isMobile;
  final bool isEn;

  const VitaScaleChildMapCard({
    super.key,
    required this.children,
    required this.cardBgColor,
    required this.borderColor,
    required this.textColor,
    required this.subtitleColor,
    required this.themeAccent,
    required this.isDark,
    required this.isMobile,
    this.isEn = false,
  });

  Widget _buildLegendBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: GoogleFonts.outfit(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final markers = children.map((c) {
      final colorHex = c.isUnder24Months
          ? '#3498DB'
          : (c.isBalita ? '#1ABC9C' : '#E67E22');

      return {
        'lat': c.latitude,
        'lng': c.longitude,
        'title': '${c.gender == 'L' ? '👦' : '👧'} ${c.name} (${c.ageLabel})',
        'subtitle': c.isUnder24Months
            ? 'Bayi < 24 Bln (PB Telentang)'
            : 'Anak ≥ 24 Bln (TB Berdiri)',
        'info': '• Mode Antropometri: ${c.defaultMode.code} (${c.defaultMode.label})<br/>• Wali: ${c.parentName}<br/>• NIK: ${c.nik}<br/>• Kategori: ${c.isBalita ? 'Balita (< 5 Thn)' : 'Anak (≥ 5 Thn)'}',
        'details': '📍 ${c.address}',
        'color': colorHex,
      };
    }).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar with Icon, Title, and Legend Badges
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: themeAccent.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.location_on_rounded,
                        size: 20,
                        color: themeAccent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PETA LOKASI PASIEN ANAK & BALITA',
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: textColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Pemetaan geotagging domisili tempat tinggal balita/anak & sebaran pemantauan antropometri Puskesmas',
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              color: subtitleColor,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (!isMobile) ...[
                const SizedBox(width: 12),
                Row(
                  children: [
                    _buildLegendBadge('🔵 Bayi < 24 Bln (PB)', const Color(0xFF3498DB)),
                    const SizedBox(width: 8),
                    _buildLegendBadge('🟠 Anak ≥ 24 Bln (TB)', const Color(0xFFE67E22)),
                    const SizedBox(width: 8),
                    _buildLegendBadge('🟢 Balita Sasaran', const Color(0xFF1ABC9C)),
                  ],
                ),
              ],
            ],
          ),

          // Mobile Legend Badges Row
          if (isMobile) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _buildLegendBadge('🔵 Bayi < 24 Bln (PB)', const Color(0xFF3498DB)),
                _buildLegendBadge('🟠 Anak ≥ 24 Bln (TB)', const Color(0xFFE67E22)),
                _buildLegendBadge('🟢 Balita Sasaran', const Color(0xFF1ABC9C)),
              ],
            ),
          ],

          const SizedBox(height: 16),

          // RevGeo Wilayah Map Widget with Interactive Boundary & Child Pins
          RevGeoWilayahMapWidget(
            initialProvince: 'JAWA TIMUR',
            initialDistrict: 'KABUPATEN BONDOWOSO',
            initialSubDistrict: 'SUMBER WRINGIN',
            fieldBg: isDark ? const Color(0xFF141824) : const Color(0xFFF1F5F9),
            textColor: textColor,
            subtitleColor: subtitleColor,
            borderColor: borderColor,
            dropdownColor: isDark ? const Color(0xFF1B1B1E) : Colors.white,
            themeAccent: themeAccent,
            isDark: isDark,
            isEn: isEn,
            height: 420,
            showOnlyMap: true,
            markers: markers,
            onChanged: (_, _, _, _) {},
          ),
        ],
      ),
    );
  }
}
