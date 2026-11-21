import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapotech/features/landing/landing_page_data.dart';
import 'package:mapotech/shared/supabase_service.dart';
import 'package:mapotech/shared/widgets/ui.dart';

class ApotekDashboard extends ConsumerStatefulWidget {
  const ApotekDashboard({super.key});

  @override
  ConsumerState<ApotekDashboard> createState() => _ApotekDashboardState();
}

class _ApotekDashboardState extends ConsumerState<ApotekDashboard> {
  final SupabaseService _db = SupabaseService();
  bool _isLoading = true;

  double _todayRevenue = 0;
  double _revenueTrend = 0;
  int _pendingPrescriptionsCount = 0;
  int _lowStockCount = 0;
  int _expiringCount = 0;

  List<Map<String, dynamic>> _chartSeries = [];
  List<Map<String, dynamic>> _inventoryAlerts = [];

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    setState(() => _isLoading = true);
    try {
      final now = DateTime.now();
      final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final yesterday = now.subtract(const Duration(days: 1));
      final yesterdayStr = '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';

      // 1. Fetch Financial Transactions from Supabase
      double todayRev = 0;
      double yesterdayRev = 0;
      final List<Map<String, dynamic>> allTx = await _db.fetchFinancialTransactions();

      for (var tx in allTx) {
        final txDate = tx['transaction_date']?.toString() ?? tx['created_at']?.toString() ?? '';
        final amount = double.tryParse(tx['amount']?.toString() ?? '0') ?? 0.0;
        final type = (tx['transaction_type'] ?? 'income').toString().toLowerCase();
        final status = (tx['status'] ?? 'Sukses').toString().toLowerCase();

        if (status != 'void' && status != 'voided' && type == 'income') {
          if (txDate.startsWith(todayStr)) {
            todayRev += amount;
          } else if (txDate.startsWith(yesterdayStr)) {
            yesterdayRev += amount;
          }
        }
      }

      double revTrend = 0;
      if (yesterdayRev > 0) {
        revTrend = ((todayRev - yesterdayRev) / yesterdayRev) * 100;
      } else if (todayRev > 0) {
        revTrend = 100.0;
      }

      // If starter mock needed for fresh installation
      if (todayRev == 0 && allTx.isEmpty) {
        todayRev = 485000;
        revTrend = 12.5;
      }

      // 2. Fetch Pending Prescriptions
      int pendingRx = 0;
      try {
        final rxList = await _db.fetchPendingPrescriptions();
        pendingRx = rxList.length;
      } catch (_) {}

      // 3. Fetch Medicines and Batches for Stock & Expiry Alerts
      int lowStock = 0;
      int expiring = 0;
      final List<Map<String, dynamic>> alerts = [];

      try {
        final medicines = await _db.fetchMedicinesWithBatches();
        for (var m in medicines) {
          final batches = m['medicine_batches'] as List<dynamic>? ?? [];
          final medName = m['medicine_name'] ?? 'Obat';

          for (var b in batches) {
            final stock = int.tryParse(b['quantity_in_stock']?.toString() ?? '0') ?? 0;
            final expStr = b['expiration_date']?.toString().split('T').first ?? '';

            bool isLow = stock <= 10;
            bool isExpiring = false;

            if (expStr.isNotEmpty) {
              try {
                final expDate = DateTime.parse(expStr);
                final diff = expDate.difference(now).inDays;
                if (diff >= 0 && diff <= 60) {
                  isExpiring = true;
                }
              } catch (_) {}
            }

            if (isLow) lowStock++;
            if (isExpiring) expiring++;

            if (isLow || isExpiring) {
              alerts.add({
                'name': medName,
                'batchNo': b['batch_number'] ?? '-',
                'stock': stock,
                'expiry': expStr,
                'isLow': isLow,
                'isExpiring': isExpiring,
              });
            }
          }
        }
      } catch (_) {}

      // 4. Build chart series
      final List<Map<String, dynamic>> series = [];
      const dayNames = ['Min', 'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab'];
      for (int i = 6; i >= 0; i--) {
        final d = now.subtract(Duration(days: i));
        final dStr = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
        double dayRev = 0;

        for (var tx in allTx) {
          final txDate = tx['transaction_date']?.toString() ?? tx['created_at']?.toString() ?? '';
          final amount = double.tryParse(tx['amount']?.toString() ?? '0') ?? 0.0;
          final type = (tx['transaction_type'] ?? 'income').toString().toLowerCase();
          final status = (tx['status'] ?? 'Sukses').toString().toLowerCase();

          if (status != 'void' && status != 'voided' && type == 'income' && txDate.startsWith(dStr)) {
            dayRev += amount;
          }
        }

        if (dayRev == 0 && allTx.isEmpty) {
          dayRev = (i == 0 ? todayRev : (250000.0 + (i * 45000)));
        }

        series.add({
          'label': dayNames[d.weekday % 7],
          'weekday': d.weekday,
          'date': dStr,
          'revenue': dayRev,
          'profit': dayRev * 0.35,
        });
      }

      if (!mounted) return;

      setState(() {
        _todayRevenue = todayRev;
        _revenueTrend = revTrend;
        _pendingPrescriptionsCount = pendingRx;
        _lowStockCount = lowStock;
        _expiringCount = expiring;
        _chartSeries = series;
        _inventoryAlerts = alerts.take(5).toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching apotek dashboard data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatPrice(double value) {
    return value.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        );
  }

  String _getFormattedDate(String lang) {
    return AppTranslations.formatDate(DateTime.now(), lang: lang);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(landingPageProvider);
    final isEn = state.language == 'en';

    final isDark = state.appearance == 'dark';
    final isRev = state.appearance == 'rev';
    final cardBgColor = isDark ? const Color(0xFF161619) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1B0C3C);
    final subtitleColor = isDark ? Colors.grey[400]! : const Color(0xFF6F6A8A);
    final borderColor = isDark ? const Color(0xFF252528) : const Color(0xFFECEEF2);

    final themeAccent = isRev ? const Color(0xFFB577F2) : const Color(0xFF00875A);
    final isMobile = MediaQuery.of(context).size.width < 768;

    final userName = state.loggedInName ?? (isEn ? 'Pharmacist' : 'Apoteker');

    if (_isLoading) {
      return CustomPageLoader(
        message: isEn ? 'Loading pharmacy metrics...' : 'Memuat ringkasan apotek...',
        skeleton: const SkeletonApotekDashboard(type: 'dashboard'),
      );
    }

    final maxChartRev = _chartSeries.fold(0.0, (max, item) {
      final r = (item['revenue'] as num).toDouble();
      return r > max ? r : max;
    });
    final scale = maxChartRev > 0 ? (120.0 / maxChartRev) : 1.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ─── 1. Welcome Header Banner ─────────────────────────
        AnimatedEntrance(
          delay: Duration.zero,
          type: EntranceAnimationType.slideUp,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
            decoration: BoxDecoration(
              color: cardBgColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEn ? 'Welcome back, $userName' : 'Selamat datang, $userName',
                      style: GoogleFonts.outfit(fontSize: 19, fontWeight: FontWeight.w900, color: textColor),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _getFormattedDate(state.language),
                      style: GoogleFonts.outfit(fontSize: 11, color: subtitleColor),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: _fetchDashboardData,
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  color: themeAccent,
                  tooltip: isEn ? 'Sync Database Data' : 'Sinkronisasi Data Database',
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),

        // ─── 2. Top 4 KPI Metrics Grid ────────────────────────
        AnimatedEntrance(
          delay: const Duration(milliseconds: 100),
          type: EntranceAnimationType.scale,
          child: GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: isMobile ? 2 : 4,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: 1.55,
            children: [
              MetricCard(
                icon: Icons.monetization_on_rounded,
                label: isEn ? 'TODAY SALES' : 'PENJUALAN HARI INI',
                count: 'Rp ${_formatPrice(_todayRevenue)}',
                subtitleColor: subtitleColor,
                countColor: textColor,
                cardBgColor: cardBgColor,
                borderColor: borderColor,
              ),
              MetricCard(
                icon: Icons.receipt_long_rounded,
                label: isEn ? 'PENDING PRESCRIPTIONS' : 'RESEP PENDING',
                count: _pendingPrescriptionsCount > 0
                    ? '$_pendingPrescriptionsCount ${isEn ? "PRESCRIPTIONS" : "RESEP"}'
                    : (isEn ? '0 PRESCRIPTION' : '0 RESEP'),
                subtitleColor: subtitleColor,
                countColor: _pendingPrescriptionsCount > 0 ? Colors.amber[800]! : themeAccent,
                cardBgColor: cardBgColor,
                borderColor: borderColor,
              ),
              MetricCard(
                icon: Icons.warning_amber_rounded,
                label: isEn ? 'LOW STOCK' : 'STOK MENIPIS',
                count: isEn ? '$_lowStockCount MEDICINES' : '$_lowStockCount OBAT',
                subtitleColor: subtitleColor,
                countColor: Colors.amber,
                cardBgColor: cardBgColor,
                borderColor: borderColor,
              ),
              MetricCard(
                icon: Icons.hourglass_empty_rounded,
                label: isEn ? 'NEAR EXPIRY' : 'HAMPIR EXPIRED',
                count: isEn ? '$_expiringCount BATCHES' : '$_expiringCount BATCH',
                subtitleColor: subtitleColor,
                countColor: Colors.redAccent,
                cardBgColor: cardBgColor,
                borderColor: borderColor,
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // ─── 3. Aksi Cepat Row (Quick Action Cards) ───────────
        AnimatedEntrance(
          delay: const Duration(milliseconds: 200),
          type: EntranceAnimationType.slideUp,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                isEn ? 'Quick Actions' : 'Aksi Cepat',
                style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.w900, color: textColor),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _buildQuickActionCard(
                    isEn ? 'POS Cashier' : 'Kasir POS',
                    Icons.point_of_sale_rounded,
                    const Color(0xFF00875A),
                    cardBgColor,
                    borderColor,
                    textColor,
                    () => ref.read(landingPageProvider.notifier).setActiveTab('penjualan'),
                  ),
                  const SizedBox(width: 12),
                  _buildQuickActionCard(
                    isEn ? 'Incoming Orders' : 'Resep Masuk',
                    Icons.receipt_long_rounded,
                    const Color(0xFF0052CC),
                    cardBgColor,
                    borderColor,
                    textColor,
                    () => ref.read(landingPageProvider.notifier).setActiveTab('pesanan'),
                  ),
                  const SizedBox(width: 12),
                  _buildQuickActionCard(
                    isEn ? 'Medicine Inventory' : 'Inventori Obat',
                    Icons.inventory_2_outlined,
                    const Color(0xFF6554C0),
                    cardBgColor,
                    borderColor,
                    textColor,
                    () => ref.read(landingPageProvider.notifier).setActiveTab('inventori'),
                  ),
                  const SizedBox(width: 12),
                  _buildQuickActionCard(
                    isEn ? 'Cash Reports' : 'Laporan Kas',
                    Icons.assessment_outlined,
                    const Color(0xFFFF8B00),
                    cardBgColor,
                    borderColor,
                    textColor,
                    () => ref.read(landingPageProvider.notifier).setActiveTab('laporan'),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // ─── 4. Visual Chart & Inventory Alerts Row ───────────
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Chart: Revenue vs Estimated Profit
            Expanded(
              flex: 3,
              child: AnimatedEntrance(
                delay: const Duration(milliseconds: 300),
                type: EntranceAnimationType.slideUp,
                child: Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: cardBgColor,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isEn
                                ? 'Revenue vs Estimated Profit (Last 7 Days)'
                                : 'Revenue vs Estimated Profit (7 Hari Terakhir)',
                            style: GoogleFonts.outfit(fontSize: 13.5, fontWeight: FontWeight.w900, color: textColor),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E1E22) : const Color(0xFFF1F4F8),
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.trending_up_rounded, size: 13, color: Color(0xFF00875A)),
                                const SizedBox(width: 4),
                                Text(
                                  '+${_revenueTrend.toStringAsFixed(1)}%',
                                  style: GoogleFonts.outfit(fontSize: 10.5, fontWeight: FontWeight.w900, color: const Color(0xFF00875A)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Chart Proportional Height Bars
                      SizedBox(
                        height: 160,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: _chartSeries.map((s) {
                            final rev = (s['revenue'] as num).toDouble();
                            final profit = (s['profit'] as num).toDouble();
                            final revH = (rev * scale).clamp(16.0, 120.0);
                            final profitH = (profit * scale).clamp(8.0, 60.0);

                            return Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Container(
                                      width: 12,
                                      height: profitH,
                                      decoration: BoxDecoration(color: const Color(0xFF57D9A3), borderRadius: BorderRadius.circular(3)),
                                    ),
                                    const SizedBox(width: 3),
                                    Container(
                                      width: 12,
                                      height: revH,
                                      decoration: BoxDecoration(color: const Color(0xFF00875A), borderRadius: BorderRadius.circular(3)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  s['weekday'] != null
                                      ? AppTranslations.getShortWeekday(s['weekday'] as int, lang: state.language)
                                      : (s['label']?.toString() ?? ''),
                                  style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: subtitleColor),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Legend
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(width: 9, height: 9, decoration: BoxDecoration(color: const Color(0xFF57D9A3), borderRadius: BorderRadius.circular(2))),
                          const SizedBox(width: 6),
                          Text('Profit', style: GoogleFonts.outfit(fontSize: 10.5, color: subtitleColor)),
                          const SizedBox(width: 16),
                          Container(width: 9, height: 9, decoration: BoxDecoration(color: const Color(0xFF00875A), borderRadius: BorderRadius.circular(2))),
                          const SizedBox(width: 6),
                          Text('Revenue', style: GoogleFonts.outfit(fontSize: 10.5, color: subtitleColor)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(width: 16),

            // Right Box: Urgent Alerts & Real-time Activity
            Expanded(
              flex: 2,
              child: AnimatedEntrance(
                delay: const Duration(milliseconds: 350),
                type: EntranceAnimationType.slideUp,
                child: Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: cardBgColor,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEn ? 'Stock & Expiry Alerts' : 'Peringatan Stok & Expired',
                        style: GoogleFonts.outfit(fontSize: 13.5, fontWeight: FontWeight.w900, color: textColor),
                      ),
                      const SizedBox(height: 14),

                      if (_inventoryAlerts.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 36),
                          child: Center(
                            child: Column(
                              children: [
                                const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF00875A), size: 32),
                                const SizedBox(height: 6),
                                Text(
                                  isEn
                                      ? 'All stock and expiry dates are healthy'
                                      : 'Semua stok & masa berlaku aman',
                                  style: GoogleFonts.outfit(fontSize: 11.5, color: subtitleColor),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ..._inventoryAlerts.map((a) {
                          final isLow = a['isLow'] as bool;
                          final badgeColor = isLow ? Colors.amber[800]! : Colors.redAccent;
                          final badgeBg = isLow ? const Color(0xFFFFF0B3) : const Color(0xFFFFEBE6);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E1E22) : const Color(0xFFF8FAFD),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: borderColor),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(8)),
                                  child: Icon(isLow ? Icons.warning_amber_rounded : Icons.timer_outlined, size: 14, color: badgeColor),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        a['name']?.toString() ?? '',
                                        style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.bold, color: textColor),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        isLow
                                            ? (isEn ? 'Remaining Stock: ${a['stock']}' : 'Sisa Stok: ${a['stock']}')
                                            : 'Exp: ${a['expiry']}',
                                        style: GoogleFonts.outfit(fontSize: 10, color: subtitleColor),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActionCard(
    String label,
    IconData icon,
    Color iconColor,
    Color cardBg,
    Color border,
    Color text,
    VoidCallback onTap,
  ) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: text),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
