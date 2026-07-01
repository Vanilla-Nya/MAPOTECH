import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapotech/features/landing/landing_page_data.dart';
import 'package:mapotech/shared/widgets/ui.dart';


class ApotekDashboard extends ConsumerWidget {
  const ApotekDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(landingPageProvider);

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
        // Welcome Header
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardBgColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Selamat datang, CyrenElysia~♪',
                style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w900, color: textColor),
              ),
              const SizedBox(height: 4),
              Text(
                'Selasa, 26 Mei 2026',
                style: GoogleFonts.outfit(fontSize: 10, color: subtitleColor),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Metrics Grid Penjualan Hari Ini, Resep Pending, Stok Menipis, Expiring
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: isMobile ? 2 : 4,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.6,
          children: [
            MetricCard(
              icon: Icons.monetization_on_rounded,
              label: 'PENJUALAN HARI INI',
              count: 'Rp 0',
              subtitleColor: subtitleColor,
              countColor: textColor,
              cardBgColor: cardBgColor,
              borderColor: borderColor,
            ),
            MetricCard(
              icon: Icons.receipt_long_rounded,
              label: 'RESEP PENDING',
              count: 'SEGERA',
              subtitleColor: subtitleColor,
              countColor: themeAccent,
              cardBgColor: cardBgColor,
              borderColor: borderColor,
            ),
            MetricCard(
              icon: Icons.warning_amber_rounded,
              label: 'STOK MENIPIS',
              count: '0',
              subtitleColor: subtitleColor,
              countColor: Colors.amber,
              cardBgColor: cardBgColor,
              borderColor: borderColor,
            ),
            MetricCard(
              icon: Icons.hourglass_empty_rounded,
              label: 'OBAT HAMPIR EXPIRED',
              count: '0',
              subtitleColor: subtitleColor,
              countColor: Colors.redAccent,
              cardBgColor: cardBgColor,
              borderColor: borderColor,
            ),
          ],
        ),

        const SizedBox(height: 28),

        // Aksi Cepat Row (Quick Action links: Tambah Obat, Cetak Laporan, Data Pelanggan)
        Text(
          'Aksi Cepat',
          style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: textColor),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildQuickActionCard('Tambah Obat', Icons.add_circle_outline_rounded, cardBgColor, borderColor, textColor),
            const SizedBox(width: 14),
            _buildQuickActionCard('Cetak Laporan', Icons.print_outlined, cardBgColor, borderColor, textColor),
            const SizedBox(width: 14),
            _buildQuickActionCard('Data Pelanggan', Icons.people_outline_rounded, cardBgColor, borderColor, textColor),
          ],
        ),

        const SizedBox(height: 28),

        // Revenue vs Estimated Profit Visual Chart
        Container(
          height: 300,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: cardBgColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Revenue vs Estimated Profit',
                style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: textColor),
              ),
              const Spacer(),
              Center(
                child: Text(
                  'Belum ada data transaksi hari ini.',
                  style: GoogleFonts.outfit(fontSize: 12, color: subtitleColor, fontWeight: FontWeight.bold),
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionCard(String label, IconData icon, Color cardBg, Color border, Color text) {
    return Expanded(
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Icon(icon, size: 18, color: const Color(0xFFB577F2)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: text),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
