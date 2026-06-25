import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapotech/shared/widgets/skeleton_loading.dart';
import 'package:mapotech/features/landing/landing_page_data.dart';
import 'package:mapotech/shared/supabase_service.dart';

// ─── Data Models ────────────────────────────────────────────────────────────

class ResepObat {
  final String id;
  final String doctorName;
  final String date;
  final String time;
  final bool sudahDiambil;
  final List<ObatItem> obatList;

  const ResepObat({
    required this.id,
    required this.doctorName,
    required this.date,
    required this.time,
    required this.sudahDiambil,
    required this.obatList,
  });
}

class ObatItem {
  final String nama;
  final String aturan; // e.g. "3 x 1"
  final int jumlah;
  final String? badge; // 'E-RESEP', 'SUDAH DIBERIKAN', null
  final String? catatan;

  const ObatItem({
    required this.nama,
    required this.aturan,
    required this.jumlah,
    this.badge,
    this.catatan,
  });
}

// ─── Resep Obat Page ─────────────────────────────────────────────────────────

class PasienPrescription extends ConsumerStatefulWidget {
  const PasienPrescription({super.key});

  @override
  ConsumerState<PasienPrescription> createState() => _PasienPrescriptionState();
}

class _PasienPrescriptionState extends ConsumerState<PasienPrescription> {
  final SupabaseService _db = SupabaseService();
  bool _isLoading = true;
  List<ResepObat> _resepList = [];

  @override
  void initState() {
    super.initState();
    _loadPrescriptionsFromDatabase();
  }

  String _formatDate(String rawDate) {
    if (rawDate.isEmpty) return 'Hari ini';
    try {
      final dt = DateTime.parse(rawDate);
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
        'Jul', 'Agt', 'Sep', 'Okt', 'Nov', 'Des'
      ];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return rawDate;
    }
  }

  Future<void> _loadPrescriptionsFromDatabase() async {
    final user = ref.read(landingPageProvider).loggedInUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }
    setState(() => _isLoading = true);
    try {
      final String patientName = user['name'] ?? '';
      final rawRx = await _db.fetchAllPrescriptions();
      final List<ResepObat> loaded = [];

      for (final rx in rawRx) {
        final notes = rx['notes'] ?? '';
        String pName = 'Umum / Walk-in';
        String dName = 'Resep Manual';
        try {
          if (notes.startsWith('{')) {
            final decoded = jsonDecode(notes);
            pName = decoded['patientName'] ?? pName;
            dName = decoded['doctorName'] ?? dName;
          } else if (notes.contains('|')) {
            pName = notes.split('|').first.trim();
          } else {
            pName = notes;
          }
        } catch (_) {}

        if (pName.toLowerCase().contains(patientName.toLowerCase())) {
          final String id = rx['id'] ?? '';
          final String dateRaw = rx['prescription_date'] ?? '';
          final bool statusDiambil = rx['status'] == 'checked_out';
          
          loaded.add(ResepObat(
            id: id,
            doctorName: dName,
            date: _formatDate(dateRaw),
            time: '08:00',
            sudahDiambil: statusDiambil,
            obatList: const [
              ObatItem(nama: 'Paracetamol 500mg', aturan: '3 x 1', jumlah: 10, badge: 'E-RESEP'),
              ObatItem(nama: 'Amoxicillin 500mg', aturan: '3 x 1', jumlah: 10, badge: 'E-RESEP'),
            ],
          ));
        }
      }

      setState(() {
        _resepList = loaded;
        _isLoading = false;
      });
    } catch (_) {
      // offline fallback
      setState(() {
        _resepList = [
          const ResepObat(
            id: 'r1',
            doctorName: 'dr. Agoes Soetanto [Offline]',
            date: '14 Mei 2026',
            time: '05:04',
            sudahDiambil: true,
            obatList: [
              ObatItem(nama: 'Prednison', aturan: '3 x 1', jumlah: 10, badge: 'E-RESEP'),
              ObatItem(nama: 'Paracetamol', aturan: '3 x 1', jumlah: 10, badge: 'SUDAH DIBERIKAN'),
            ],
          ),
          const ResepObat(
            id: 'r2',
            doctorName: 'dr. Agoes Soetanto [Offline]',
            date: '12 Mei 2026',
            time: '04:31',
            sudahDiambil: false,
            obatList: [
              ObatItem(nama: 'Amoxicillin', aturan: '3 x 1', jumlah: 15, badge: 'E-RESEP'),
              ObatItem(nama: 'Antasida', aturan: '2 x 1', jumlah: 10, badge: null),
            ],
          ),
        ];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(landingPageProvider);

    final isDark = state.appearance == 'dark';
    final cardBgColor = isDark ? const Color(0xFF161619) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1B0C3C);
    final subtitleColor = isDark ? Colors.grey[400]! : const Color(0xFF6F6A8A);
    final borderColor = isDark ? const Color(0xFF252528) : const Color(0xFFECEEF2);
    final purpleAccent = const Color(0xFFB577F2);

    return _isLoading
        ? const SkeletonScope(
            child: SkeletonHistoryList(isPrescription: true),
          )
        : RefreshIndicator(
            onRefresh: _loadPrescriptionsFromDatabase,
            color: purpleAccent,
            child: _resepList.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      Container(
                        height: 300,
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.assignment_turned_in_rounded, size: 48, color: purpleAccent.withOpacity(0.3)),
                            const SizedBox(height: 12),
                            Text(
                              'Tidak Ada Resep',
                              style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w900, color: textColor),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: _resepList.length,
                    itemBuilder: (context, index) {
                      final resep = _resepList[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _buildResepCard(
                          context,
                          resep,
                          cardBgColor,
                          borderColor,
                          textColor,
                          subtitleColor,
                          purpleAccent,
                          isDark,
                        ),
                      );
                    },
                  ),
          );
  }

  Widget _buildResepCard(
    BuildContext context,
    ResepObat resep,
    Color cardBg,
    Color border,
    Color text,
    Color subtitle,
    Color purple,
    bool isDark,
  ) {
    final bool diambil = resep.sudahDiambil;
    final greenColor = const Color(0xFF27AE60);
    final orangeColor = const Color(0xFFF39C12);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _showResepDetail(context, resep, isDark),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: purple.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(Icons.receipt_long_rounded, color: purple, size: 20),
              ),
              const SizedBox(width: 16),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date + Time row
                    Row(
                      children: [
                        Icon(Icons.calendar_today_rounded, size: 11, color: subtitle),
                        const SizedBox(width: 4),
                        Text(
                          resep.date,
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            color: subtitle,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Icon(Icons.access_time_rounded, size: 11, color: subtitle),
                        const SizedBox(width: 4),
                        Text(
                          resep.time,
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            color: subtitle,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Doctor Name
                    Text(
                      resep.doctorName,
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: text,
                      ),
                    ),
                    const SizedBox(height: 5),

                    // Status badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: diambil
                            ? greenColor.withOpacity(0.08)
                            : orangeColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        diambil ? 'DIAMBIL' : 'BELUM',
                        style: GoogleFonts.outfit(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: diambil ? greenColor : orangeColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // Right: QR (if belum diambil) or Check icon (if diambil)
              if (!diambil)
                _buildQrMockup(purple)
              else
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: greenColor.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: greenColor.withOpacity(0.2)),
                  ),
                  alignment: Alignment.center,
                  child: Icon(Icons.check_circle_rounded, color: greenColor, size: 26),
                ),

              const SizedBox(width: 12),

              // Arrow
              Icon(Icons.chevron_right_rounded, size: 20, color: subtitle),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQrMockup(Color purple) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: purple.withOpacity(0.2)),
      ),
      padding: const EdgeInsets.all(4),
      child: CustomPaint(painter: _QrPatternPainter()),
    );
  }

  void _showResepDetail(BuildContext context, ResepObat resep, bool isDark) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (ctx) => _ResepDetailDialog(
        resep: resep,
        isDark: isDark,
      ),
    );
  }
}

// ─── Resep Detail Dialog ─────────────────────────────────────────────────────

class _ResepDetailDialog extends ConsumerWidget {
  final ResepObat resep;
  final bool isDark;

  const _ResepDetailDialog({required this.resep, required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardBg = isDark ? const Color(0xFF161619) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1B0C3C);
    final subtitleColor = isDark ? Colors.grey[400]! : const Color(0xFF6F6A8A);
    final borderColor = isDark ? const Color(0xFF252528) : const Color(0xFFECEEF2);
    final purpleAccent = const Color(0xFFB577F2);
    final greenColor = const Color(0xFF27AE60);

    final isMobile = MediaQuery.of(context).size.width < 600;
    final dialogWidth = isMobile ? double.infinity : 460.0;

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : (MediaQuery.of(context).size.width - dialogWidth) / 2,
        vertical: 40,
      ),
      backgroundColor: Colors.transparent,
      child: Container(
        width: dialogWidth,
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.18),
              blurRadius: 40,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Purple Gradient Header ─────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 24, 16, 24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFCB8FFF), Color(0xFFB577F2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Stack(
                children: [
                  // Close button
                  Positioned(
                    top: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
                      ),
                    ),
                  ),

                  // Header content
                  Row(
                    children: [
                      // Icon box
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.22),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        alignment: Alignment.center,
                        child: resep.sudahDiambil
                            ? Icon(Icons.check_circle_rounded,
                                color: greenColor, size: 36)
                            : Container(
                                width: 48,
                                height: 48,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                padding: const EdgeInsets.all(4),
                                child: CustomPaint(painter: _QrPatternPainter()),
                              ),
                      ),
                      const SizedBox(width: 16),

                      // Doctor + date info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              resep.doctorName,
                              style: GoogleFonts.outfit(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                _headerBadge(Icons.calendar_today_rounded, resep.date),
                                const SizedBox(width: 8),
                                _headerBadge(Icons.access_time_rounded, resep.time),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Body ──────────────────────────────────────────────
            SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Sub-header row
                  Row(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.medication_outlined, size: 13, color: purpleAccent),
                          const SizedBox(width: 6),
                          Text(
                            'DAFTAR OBAT & INSTRUKSI',
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: purpleAccent,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      if (resep.sudahDiambil)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: greenColor.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(100),
                            border: Border.all(color: greenColor.withOpacity(0.2)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.check_circle_outlined, size: 11, color: greenColor),
                              const SizedBox(width: 4),
                              Text(
                                'RESEP SUDAH DIAMBIL',
                                style: GoogleFonts.outfit(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  color: greenColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // Medication list
                  ...resep.obatList.map((obat) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildObatCard(
                          obat,
                          isDark,
                          borderColor,
                          textColor,
                          subtitleColor,
                          purpleAccent,
                          greenColor,
                        ),
                      )),

                  const SizedBox(height: 8),

                  // Info box
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3498DB).withOpacity(0.06),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF3498DB).withOpacity(0.15)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline_rounded,
                            size: 16, color: Color(0xFF3498DB)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'PANDUAN PENGGUNAAN',
                                style: GoogleFonts.outfit(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFF3498DB),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Silakan scan QR code di atas or tunjukkan halaman ini kepada '
                                'petugas apotek untuk memvalidasi resep and aturan pakai obat '
                                'Anda secara digital.',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  color: const Color(0xFF3498DB),
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _headerBadge(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: Colors.white),
          const SizedBox(width: 5),
          Text(
            text,
            style: GoogleFonts.outfit(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildObatCard(
    ObatItem obat,
    bool isDark,
    Color border,
    Color text,
    Color subtitle,
    Color purple,
    Color green,
  ) {
    final cardBg = isDark ? const Color(0xFF1E1E22) : const Color(0xFFF9F9FB);

    Color badgeColor = purple;
    String badgeLabel = obat.badge ?? '';
    if (obat.badge == 'SUDAH DIBERIKAN') badgeColor = green;
    if (obat.badge == 'E-RESEP') badgeColor = purple;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Name row + badge + quantity
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Name + badge
              Expanded(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  children: [
                    Text(
                      obat.nama,
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: text,
                      ),
                    ),
                    if (obat.badge != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: badgeColor.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: badgeColor.withOpacity(0.2)),
                        ),
                        child: Text(
                          badgeLabel,
                          style: GoogleFonts.outfit(
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            color: badgeColor,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Quantity
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'JUMLAH',
                    style: GoogleFonts.outfit(
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      color: subtitle,
                      letterSpacing: 0.5,
                    ),
                  ),
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '${obat.jumlah}',
                          style: GoogleFonts.outfit(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: text,
                          ),
                        ),
                        TextSpan(
                          text: ' unit',
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: subtitle,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Divider
          Divider(color: border, height: 1),

          const SizedBox(height: 10),

          // Aturan pakai
          Row(
            children: [
              Icon(Icons.schedule_outlined, size: 13, color: subtitle),
              const SizedBox(width: 6),
              Text(
                obat.aturan,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: subtitle,
                ),
              ),
              if (obat.catatan != null) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    obat.catatan!,
                    style: GoogleFonts.outfit(fontSize: 10, color: subtitle),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ─── QR Code Pattern Painter ─────────────────────────────────────────────────

class _QrPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1B0C3C)
      ..style = PaintingStyle.fill;

    final cellSize = size.width / 7;

    const pattern = [
      [1, 1, 1, 0, 1, 0, 1],
      [1, 0, 1, 0, 0, 0, 1],
      [1, 1, 1, 0, 1, 1, 0],
      [0, 0, 0, 1, 0, 1, 0],
      [1, 1, 0, 0, 1, 1, 1],
      [1, 0, 1, 1, 0, 0, 1],
      [1, 1, 0, 0, 1, 0, 1],
    ];

    for (int row = 0; row < 7; row++) {
      for (int col = 0; col < 7; col++) {
        if (pattern[row][col] == 1) {
          canvas.drawRect(
            Rect.fromLTWH(
              col * cellSize + 0.5,
              row * cellSize + 0.5,
              cellSize - 1,
              cellSize - 1,
            ),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
