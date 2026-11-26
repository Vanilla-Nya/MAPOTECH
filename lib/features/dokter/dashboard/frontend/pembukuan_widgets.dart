import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class BukuKasMetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color subCol;
  final Color valueCol;
  final Color bg;
  final Color border;
  final String subtitleDesc;
  final String? badgeText;
  final bool isBadgeRed;
  final List<String>? patientsBadges;

  const BukuKasMetricCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.subCol,
    required this.valueCol,
    required this.bg,
    required this.border,
    required this.subtitleDesc,
    this.badgeText,
    this.isBadgeRed = false,
    this.patientsBadges,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: border),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                  color: subCol,
                  letterSpacing: 0.5,
                ),
              ),
              if (badgeText != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: (isBadgeRed
                            ? Colors.redAccent
                            : const Color(0xFF48C9B0))
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    badgeText!,
                    style: GoogleFonts.outfit(
                      fontSize: 7,
                      fontWeight: FontWeight.w900,
                      color: isBadgeRed
                          ? Colors.redAccent
                          : const Color(0xFF48C9B0),
                    ),
                  ),
                )
              else
                Icon(icon, size: 14, color: subCol.withValues(alpha: 0.5)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: valueCol,
            ),
          ),
          const SizedBox(height: 2),
          if (patientsBadges != null)
            Row(
              children: patientsBadges!.map((b) {
                final isBpjs = b.startsWith('BPJS');
                return Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: (isBpjs ? Colors.blueAccent : const Color(0xFF48C9B0))
                        .withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: (isBpjs ? Colors.blueAccent : const Color(0xFF48C9B0))
                          .withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    b,
                    style: GoogleFonts.outfit(
                      fontSize: 6.5,
                      fontWeight: FontWeight.w900,
                      color: isBpjs
                          ? Colors.blueAccent
                          : const Color(0xFF48C9B0),
                    ),
                  ),
                );
              }).toList(),
            )
          else
            Text(
              subtitleDesc,
              style: GoogleFonts.outfit(
                fontSize: 7.5,
                color: subCol,
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
    );
  }
}

class BukuKasSmallToggle extends StatelessWidget {
  final String text;
  final bool isSelected;
  final Color activeColor;
  final Color border;
  final Color bg;
  final Color textCol;

  const BukuKasSmallToggle({
    super.key,
    required this.text,
    required this.isSelected,
    required this.activeColor,
    required this.border,
    required this.bg,
    required this.textCol,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected ? activeColor : bg,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: GoogleFonts.outfit(
          fontSize: 8.5,
          fontWeight: FontWeight.w900,
          color: textCol,
        ),
      ),
    );
  }
}

class BukuKasLegendItem extends StatelessWidget {
  final Color color;
  final String text;
  final Color textCol;

  const BukuKasLegendItem({
    super.key,
    required this.color,
    required this.text,
    required this.textCol,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: GoogleFonts.outfit(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: textCol,
          ),
        ),
      ],
    );
  }
}

class BukuKasLegendCard extends StatelessWidget {
  final Color color;
  final String text;
  final String value;
  final Color bg;
  final Color border;
  final Color textCol;
  final Color subCol;

  const BukuKasLegendCard({
    super.key,
    required this.color,
    required this.text,
    required this.value,
    required this.bg,
    required this.border,
    required this.textCol,
    required this.subCol,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  text,
                  style: GoogleFonts.outfit(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: subCol,
                  ),
                ),
                Text(
                  value,
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: textCol,
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

class BukuKasFilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color activeColor;
  final VoidCallback onTap;

  const BukuKasFilterChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? activeColor : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 9.5,
            fontWeight: FontWeight.w900,
            color: isSelected ? activeColor : const Color(0xFF6F6A8A),
          ),
        ),
      ),
    );
  }
}

class CashflowChartPainter extends CustomPainter {
  final List<double> incomeData;
  final List<double> expenseData;
  final bool isDark;

  CashflowChartPainter({
    required this.incomeData,
    required this.expenseData,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = isDark ? const Color(0xFF252528) : const Color(0xFFECEEF2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final labelStyle = GoogleFonts.outfit(
      fontSize: 7.5,
      fontWeight: FontWeight.bold,
      color: isDark ? Colors.grey[500] : const Color(0xFF6F6A8A),
    );

    double maxVal = 100000.0;
    for (final val in incomeData) {
      if (val > maxVal) maxVal = val;
    }
    for (final val in expenseData) {
      if (val > maxVal) maxVal = val;
    }

    maxVal = maxVal * 1.1;

    final heightStep = size.height / 4;
    for (int i = 0; i <= 4; i++) {
      final y = size.height - (i * heightStep);
      canvas.drawLine(Offset(35, y), Offset(size.width, y), gridPaint);

      final double gridVal = (maxVal / 4) * i;
      final valStr = _formatYLabel(gridVal);
      final tp = TextPainter(
        text: TextSpan(text: valStr, style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(5, y - tp.height / 2));
    }

    final widthStep = (size.width - 35) / 11;
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    for (int i = 0; i < 12; i++) {
      final x = 35 + (i * widthStep);
      final tp = TextPainter(
        text: TextSpan(text: months[i], style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, size.height + 6));
    }

    _drawBezierCurve(canvas, size, incomeData, const Color(0xFF48C9B0), maxVal);
    _drawBezierCurve(canvas, size, expenseData, Colors.redAccent, maxVal);
  }

  void _drawBezierCurve(
    Canvas canvas,
    Size size,
    List<double> values,
    Color color,
    double maxVal,
  ) {
    if (values.isEmpty) return;
    final widthStep = (size.width - 35) / 11;

    final path = Path();
    final fillPath = Path();

    final points = <Offset>[];
    for (int i = 0; i < 12; i++) {
      final val = i < values.length ? values[i] : 0.0;
      final pct = (val / maxVal).clamp(0.0, 1.0);
      final x = 35 + (i * widthStep);
      final y = size.height - (pct * size.height);
      points.add(Offset(x, y));
    }

    path.moveTo(points[0].dx, points[0].dy);
    fillPath.moveTo(points[0].dx, size.height);
    fillPath.lineTo(points[0].dx, points[0].dy);

    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final controlPointX = (p0.dx + p1.dx) / 2;

      path.cubicTo(controlPointX, p0.dy, controlPointX, p1.dy, p1.dx, p1.dy);
      fillPath.cubicTo(
        controlPointX,
        p0.dy,
        controlPointX,
        p1.dy,
        p1.dx,
        p1.dy,
      );
    }

    fillPath.lineTo(points.last.dx, size.height);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.18), color.withValues(alpha: 0.0)],
      ).createShader(Rect.fromLTWH(35, 0, size.width - 35, size.height))
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, linePaint);

    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (int i = 0; i < points.length; i++) {
      if (values[i] > 0) {
        canvas.drawCircle(points[i], 4, dotPaint);
        canvas.drawCircle(points[i], 4, borderPaint);
      }
    }
  }

  String _formatYLabel(double val) {
    if (val >= 10000000) {
      return '${(val / 10000000).toStringAsFixed(1).replaceAll('.0', '')}puluh jt';
    } else if (val >= 1000000) {
      return '${(val / 1000000).toStringAsFixed(1).replaceAll('.0', '')}jt';
    } else if (val >= 1000) {
      return '${(val / 1000).toStringAsFixed(0)}rb';
    }
    return val.toStringAsFixed(0);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class PatientRatioDonutChartPainter extends CustomPainter {
  final int generalCount;
  final int bpjsCount;
  final bool isDark;

  PatientRatioDonutChartPainter({
    required this.generalCount,
    required this.bpjsCount,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2;
    const strokeWidth = 14.0;

    final total = generalCount + bpjsCount;
    if (total == 0) {
      final paint = Paint()
        ..color = isDark ? const Color(0xFF252528) : const Color(0xFFECEEF2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;
      canvas.drawCircle(center, radius - strokeWidth / 2, paint);
      return;
    }

    final generalPct = generalCount / total;
    final bpjsPct = bpjsCount / total;

    final generalPaint = Paint()
      ..color = const Color(0xFF48C9B0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final bpjsPaint = Paint()
      ..color = const Color(0xFF1B4F42)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromCircle(
      center: center,
      radius: radius - strokeWidth / 2,
    );

    const startAngle = -pi / 2;
    final generalAngle = 2 * pi * generalPct;
    final bpjsAngle = 2 * pi * bpjsPct;

    canvas.drawArc(rect, startAngle, generalAngle, false, generalPaint);

    if (bpjsCount > 0) {
      canvas.drawArc(
        rect,
        startAngle + generalAngle,
        bpjsAngle,
        false,
        bpjsPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
