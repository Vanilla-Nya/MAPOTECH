import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapotech/features/landing/landing_page_data.dart';
import 'package:mapotech/shared/widgets/ui.dart';


class DokterDashboard extends ConsumerWidget {
  const DokterDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(landingPageProvider);
    final notifier = ref.read(landingPageProvider.notifier);

    final isDark = state.appearance == 'dark';
    final isRev = state.appearance == 'rev';
    final cardBgColor = isDark ? const Color(0xFF161619) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1B0C3C);
    final subtitleColor = isDark ? Colors.grey[400]! : const Color(0xFF6F6A8A);
    final borderColor = isDark ? const Color(0xFF252528) : const Color(0xFFECEEF2);

    final themeAccent = isRev ? const Color(0xFFB577F2) : const Color(0xFF48C9B0);
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Doctor profile card welcome banner
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardBgColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  color: Color(0xFFEAB7EE),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  'VN',
                  style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF48C9B0).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(
                            notifier.t('SEDANG BERTUGAS'),
                            style: GoogleFonts.outfit(fontSize: 6.5, fontWeight: FontWeight.w900, color: const Color(0xFF48C9B0)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          notifier.t('Selasa, 26 Mei 2026'),
                          style: GoogleFonts.outfit(fontSize: 9, color: subtitleColor, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'dr. Agoes Soetanto',
                      style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w900, color: textColor),
                    ),
                    Text(
                      'Dokter Praktek Mandiri dr. Agoes Soetanto, dr',
                      style: GoogleFonts.outfit(fontSize: 10, color: subtitleColor),
                    ),
                  ],
                ),
              ),
              if (!isMobile)
                CustomButton(
                  text: notifier.t('Lihat Profil'),
                  icon: Icons.person_outline_rounded,
                  height: 38,
                  onPressed: () {},
                ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Indikator Kinerja Utama Cards Grid (metrics)
        Text(
          notifier.t('INDIKATOR KINERJA UTAMA'),
          style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: subtitleColor, letterSpacing: 0.5),
        ),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: isMobile ? 2 : 4,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.6,
          children: [
            MetricCard(
              icon: Icons.people_rounded,
              label: notifier.t('TOTAL PASIEN'),
              count: '3',
              subtitleColor: subtitleColor,
              countColor: textColor,
              cardBgColor: cardBgColor,
              borderColor: borderColor,
            ),
            MetricCard(
              icon: Icons.calendar_today_rounded,
              label: notifier.t('ANTREAN HARI INI'),
              count: '0',
              subtitleColor: subtitleColor,
              countColor: textColor,
              cardBgColor: cardBgColor,
              borderColor: borderColor,
            ),
            MetricCard(
              icon: Icons.warning_amber_rounded,
              label: notifier.t('OBAT KEDALUWARSA'),
              count: '00',
              subtitleColor: subtitleColor,
              countColor: Colors.redAccent,
              cardBgColor: cardBgColor,
              borderColor: borderColor,
            ),
            MetricCard(
              icon: Icons.inventory_rounded,
              label: notifier.t('STOK MENIPIS'),
              count: '0',
              subtitleColor: subtitleColor,
              countColor: Colors.amber,
              cardBgColor: cardBgColor,
              borderColor: borderColor,
            ),
          ],
        ),

        const SizedBox(height: 28),

        // Row housing Line Chart (Tren Pemasukan) & Bar Chart (Pasien per Hari)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tren Pemasukan line chart mockup
            Expanded(
              flex: 6,
              child: Container(
                height: 360,
                decoration: BoxDecoration(
                  color: cardBgColor,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: borderColor),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notifier.t('TREN PEMASUKAN'),
                      style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: subtitleColor),
                    ),
                    Text(
                      notifier.t('+0% dari bulan lalu'),
                      style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: const Color(0xFF48C9B0)),
                    ),
                    const Spacer(),
                    
                    // Simple custom line vector drawing simulation
                    Container(
                      height: 180,
                      width: double.infinity,
                      alignment: Alignment.center,
                      child: Stack(
                        children: [
                          // Dotted grid lines
                          Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: List.generate(4, (index) => const Divider(color: Colors.grey, height: 1, thickness: 0.2)),
                          ),
                          // Curved income shape
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _IncomeTrendLinePainter(themeAccent),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: (state.language == 'en'
                              ? ['Wed', 'Thu', 'Fri', 'Sat', 'Sun', 'Mon', 'Tue']
                              : ['Rab', 'Kam', 'Jum', 'Sab', 'Min', 'Sen', 'Sel'])
                          .map((day) => Text(day, style: TextStyle(color: subtitleColor, fontSize: 9)))
                          .toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 20),

            // Pasien per Hari bar chart mockup
            Expanded(
              flex: 4,
              child: Container(
                height: 360,
                decoration: BoxDecoration(
                  color: cardBgColor,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: borderColor),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notifier.t('PASIEN PER HARI'),
                      style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: subtitleColor),
                    ),
                    Text(
                      notifier.t('7 hari terakhir'),
                      style: GoogleFonts.outfit(fontSize: 11, color: subtitleColor),
                    ),
                    const Spacer(),
                    
                    // Column Bar visual
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _buildChartBar(state.language == 'en' ? 'Wed' : 'Rab', 0.0, themeAccent, subtitleColor),
                        _buildChartBar(state.language == 'en' ? 'Thu' : 'Kam', 0.0, themeAccent, subtitleColor),
                        _buildChartBar(state.language == 'en' ? 'Fri' : 'Jum', 0.0, themeAccent, subtitleColor),
                        _buildChartBar(state.language == 'en' ? 'Sat' : 'Sab', 0.8, themeAccent, subtitleColor), // Alvin logged in
                        _buildChartBar(state.language == 'en' ? 'Sun' : 'Min', 0.0, themeAccent, subtitleColor),
                        _buildChartBar(state.language == 'en' ? 'Mon' : 'Sen', 0.0, themeAccent, subtitleColor),
                        _buildChartBar(state.language == 'en' ? 'Tue' : 'Sel', 0.0, themeAccent, subtitleColor),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 28),

        // Bottom Patients Queue List Table
        Container(
          decoration: BoxDecoration(
            color: cardBgColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: borderColor),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notifier.t('Daftar Antrean'),
                        style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900, color: textColor),
                      ),
                      Text(
                        notifier.t('Status konsultasi secara real-time'),
                        style: GoogleFonts.outfit(fontSize: 10, color: subtitleColor),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        notifier.t('TOTAL ANTREAN'),
                        style: GoogleFonts.outfit(fontSize: 8, fontWeight: FontWeight.bold, color: subtitleColor),
                      ),
                      Text(
                        notifier.t('0 pasien'),
                        style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w900, color: textColor),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 48),
              Center(
                child: Text(
                  notifier.t('Belum ada pasien dalam antrean hari ini.'),
                  style: GoogleFonts.outfit(fontSize: 12, color: subtitleColor, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChartBar(String day, double percent, Color barColor, Color subtitleColor) {
    return Column(
      children: [
        Container(
          width: 24,
          height: 180,
          decoration: BoxDecoration(
            color: barColor.withOpacity(0.05),
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.bottomCenter,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 600),
            width: 24,
            height: 180 * percent,
            decoration: BoxDecoration(
              color: barColor,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(day, style: TextStyle(color: subtitleColor, fontSize: 9)),
      ],
    );
  }
}

// Income Trend Line Custom Painter
class _IncomeTrendLinePainter extends CustomPainter {
  final Color lineColor;

  _IncomeTrendLinePainter(this.lineColor);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = lineColor.withOpacity(0.08)
      ..style = PaintingStyle.fill;

    final path = Path();
    final fillPath = Path();

    // Standard smooth bezier curve simulation
    path.moveTo(0, size.height);
    fillPath.moveTo(0, size.height);

    final controlPoint1 = Offset(size.width * 0.35, size.height);
    final controlPoint2 = Offset(size.width * 0.42, size.height * 0.15);
    final endPoint = Offset(size.width * 0.5, size.height * 0.15);

    path.cubicTo(
      controlPoint1.dx, controlPoint1.dy,
      controlPoint2.dx, controlPoint2.dy,
      endPoint.dx, endPoint.dy,
    );
    fillPath.cubicTo(
      controlPoint1.dx, controlPoint1.dy,
      controlPoint2.dx, controlPoint2.dy,
      endPoint.dx, endPoint.dy,
    );

    final controlPoint3 = Offset(size.width * 0.58, size.height * 0.15);
    final controlPoint4 = Offset(size.width * 0.65, size.height);
    final endPoint2 = Offset(size.width, size.height);

    path.cubicTo(
      controlPoint3.dx, controlPoint3.dy,
      controlPoint4.dx, controlPoint4.dy,
      endPoint2.dx, endPoint2.dy,
    );
    fillPath.cubicTo(
      controlPoint3.dx, controlPoint3.dy,
      controlPoint4.dx, controlPoint4.dy,
      endPoint2.dx, endPoint2.dy,
    );

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
