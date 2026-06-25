import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapotech/shared/widgets/skeleton_loading.dart';
import 'package:mapotech/features/landing/landing_page_data.dart';
import 'package:mapotech/shared/supabase_service.dart';

class SalesTransaction {
  final String receiptNumber;
  final String buyerName;
  final String date;
  final double totalAmount;
  final String paymentMethod;
  final String status;
  final String? transactionDate;

  const SalesTransaction({
    required this.receiptNumber,
    required this.buyerName,
    required this.date,
    required this.totalAmount,
    required this.paymentMethod,
    required this.status,
    this.transactionDate,
  });
}

class ApotekLaporan extends ConsumerStatefulWidget {
  const ApotekLaporan({super.key});

  @override
  ConsumerState<ApotekLaporan> createState() => _ApotekLaporanState();
}

class _ApotekLaporanState extends ConsumerState<ApotekLaporan> {
  final SupabaseService _db = SupabaseService();
  bool _isLoading = true;
  List<SalesTransaction> _transactions = [];

  @override
  void initState() {
    super.initState();
    _loadTransactionsFromDatabase();
  }

  String _formatDateTime(String? isoString) {
    if (isoString == null || isoString.isEmpty) return 'Baru saja';
    try {
      final dt = DateTime.parse(isoString).toLocal();
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 
        'Jul', 'Agt', 'Sep', 'Okt', 'Nov', 'Des'
      ];
      final monthStr = months[dt.month - 1];
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      return '${dt.day} $monthStr ${dt.year}, $hour:$minute';
    } catch (_) {
      return isoString;
    }
  }

  Future<void> _loadTransactionsFromDatabase() async {
    setState(() => _isLoading = true);
    try {
      final rawTxs = await _db.fetchFinancialTransactions();
      final List<SalesTransaction> loaded = [];
      for (final tx in rawTxs) {
        final String id = tx['id'] ?? '';
        final String receipt = id.length > 8 ? 'TX-${id.substring(0, 8).toUpperCase()}' : 'TX-$id';
        final String buyer = tx['buyer_name'] ?? 'Umum / Walk-in';
        final double amount = double.tryParse(tx['amount'] ?? '0') ?? 0.0;
        final String method = tx['payment_method'] ?? 'Tunai';
        final String status = tx['status'] ?? 'Sukses';
        final String? rawDate = tx['transaction_date'];
        
        loaded.add(SalesTransaction(
          receiptNumber: receipt,
          buyerName: buyer,
          date: _formatDateTime(rawDate),
          totalAmount: amount,
          paymentMethod: method,
          status: status,
          transactionDate: rawDate,
        ));
      }
      
      setState(() {
        _transactions = loaded;
        _isLoading = false;
      });
    } catch (e) {
      // Offline fallback
      setState(() {
        _transactions = [
          SalesTransaction(
            receiptNumber: 'TX-20260527-0491',
            buyerName: 'Alvin (Pasien BPJS) [Offline]',
            date: '27 Mei 2026, 12:50',
            totalAmount: 46000,
            paymentMethod: 'Tunai',
            status: 'Sukses',
            transactionDate: '2026-05-27T12:50:00Z',
          ),
          SalesTransaction(
            receiptNumber: 'TX-20260527-0312',
            buyerName: 'Dewi Lestari [Offline]',
            date: '27 Mei 2026, 11:15',
            totalAmount: 34500,
            paymentMethod: 'QRIS',
            status: 'Sukses',
            transactionDate: '2026-05-27T11:15:00Z',
          ),
          SalesTransaction(
            receiptNumber: 'TX-20260527-0205',
            buyerName: 'Joko Widodo [Offline]',
            date: '27 Mei 2026, 09:30',
            totalAmount: 8000,
            paymentMethod: 'Tunai',
            status: 'Sukses',
            transactionDate: '2026-05-27T09:30:00Z',
          ),
          SalesTransaction(
            receiptNumber: 'TX-20260526-1182',
            buyerName: 'Umum / Walk-in [Offline]',
            date: '26 Mei 2026, 16:20',
            totalAmount: 15000,
            paymentMethod: 'Debit',
            status: 'Sukses',
            transactionDate: '2026-05-26T16:20:00Z',
          ),
        ];
        _isLoading = false;
      });
    }
  }

  String _formatPrice(double value) {
    return value.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(landingPageProvider);
    final isDark = state.appearance == 'dark';
    final isRev = state.appearance == 'rev';

    final themeAccent = isRev ? const Color(0xFFB577F2) : const Color(0xFF48C9B0);
    final cardBgColor = isDark ? const Color(0xFF161619) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1B0C3C);
    final subtitleColor = isDark ? Colors.grey[400]! : const Color(0xFF6F6A8A);
    final borderColor = isDark ? const Color(0xFF252528) : const Color(0xFFECEEF2);

    double totalRevenue = _transactions.fold(0, (sum, tx) => sum + tx.totalAmount);
    double estimatedProfit = totalRevenue * 0.4; // assume 40% margin

    // Calculate dynamic 7-day trend
    final now = DateTime.now();
    final List<String> dayLabels = [];
    final List<double> dayValues = [];
    final weekdayNames = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

    for (int i = 6; i >= 0; i--) {
      final d = now.subtract(Duration(days: i));
      dayLabels.add(weekdayNames[d.weekday - 1]);
      dayValues.add(0.0);
    }

    for (final tx in _transactions) {
      if (tx.transactionDate != null) {
        try {
          final txDate = DateTime.parse(tx.transactionDate!).toLocal();
          final difference = now.difference(txDate).inDays;
          if (difference >= 0 && difference < 7) {
            final idx = 6 - difference;
            if (idx >= 0 && idx < 7) {
              dayValues[idx] += tx.totalAmount;
            }
          }
        } catch (_) {}
      }
    }

    double maxDaily = dayValues.reduce((a, b) => a > b ? a : b);
    if (maxDaily == 0) maxDaily = 1.0;

    return _isLoading
        ? const SkeletonScope(
            child: SkeletonApotekDashboard(type: 'report'),
          )
        : RefreshIndicator(
            onRefresh: _loadTransactionsFromDatabase,
            color: themeAccent,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                // Metric card totals
                Row(
                  children: [
                    Expanded(
                      child: _buildFinancialCard('PENDAPATAN KOTOR', 'Rp ${_formatPrice(totalRevenue)}', themeAccent, cardBgColor, borderColor),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildFinancialCard('ESTIMASI LABA BERSIH', 'Rp ${_formatPrice(estimatedProfit)}', const Color(0xFF48C9B0), cardBgColor, borderColor),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildFinancialCard('TOTAL TRANSAKSI', '${_transactions.length}', Colors.amber, cardBgColor, borderColor),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildFinancialCard('TINGKAT SUKSES', '100%', Colors.blueAccent, cardBgColor, borderColor),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Beautiful glassmorphic sales trendline visual container
                Container(
                  height: 160,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: cardBgColor,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Tren Penjualan Mingguan',
                            style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: textColor),
                          ),
                          Text(
                            '7 Hari Terakhir',
                            style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.bold, color: subtitleColor),
                          ),
                        ],
                      ),
                      const Spacer(),
                      // Simulated modern chart drawing bars
                      SizedBox(
                        height: 70,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: List.generate(7, (i) {
                            final fraction = dayValues[i] / maxDaily;
                            final displayFraction = fraction > 0 ? (fraction * 0.85 + 0.15) : 0.05;
                            return _buildChartBar(dayLabels[i], displayFraction, themeAccent, isDark);
                          }),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Journal Transaction Logs header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Jurnal Transaksi Penjualan',
                      style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: textColor),
                    ),
                    IconButton(
                      icon: Icon(Icons.refresh_rounded, size: 18, color: themeAccent),
                      onPressed: _loadTransactionsFromDatabase,
                      tooltip: 'Muat Ulang Jurnal',
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // List representation of transactions
                if (_transactions.isEmpty)
                  Container(
                    height: 200,
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long_rounded, size: 40, color: themeAccent.withOpacity(0.3)),
                        const SizedBox(height: 8),
                        Text(
                          'Belum ada transaksi',
                          style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: textColor),
                        ),
                      ],
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _transactions.length,
                    itemBuilder: (context, index) {
                      final tx = _transactions[index];

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cardBgColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: borderColor),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: const Color(0xFF48C9B0).withOpacity(0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF48C9B0), size: 18),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          tx.receiptNumber,
                                          style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: textColor),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF48C9B0).withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(100),
                                        ),
                                        child: Text(
                                          tx.status,
                                          style: GoogleFonts.outfit(fontSize: 7, fontWeight: FontWeight.bold, color: const Color(0xFF48C9B0)),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Pembeli: ${tx.buyerName} • ${tx.paymentMethod}',
                                    style: GoogleFonts.outfit(fontSize: 9, color: subtitleColor),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    tx.date,
                                    style: GoogleFonts.outfit(fontSize: 8, color: subtitleColor.withOpacity(0.8)),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 14),
                            Text(
                              'Rp ${_formatPrice(tx.totalAmount)}',
                              style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: textColor),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          );
  }

  Widget _buildFinancialCard(String label, String value, Color color, Color bg, Color border) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.outfit(fontSize: 7, fontWeight: FontWeight.bold, color: const Color(0xFF6F6A8A)),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildChartBar(String day, double fraction, Color accentColor, bool isDark) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              heightFactor: fraction,
              child: Container(
                width: 10,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [accentColor, accentColor.withOpacity(0.3)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          day,
          style: GoogleFonts.outfit(fontSize: 8, fontWeight: FontWeight.bold, color: isDark ? Colors.grey[500] : const Color(0xFF6F6A8A)),
        ),
      ],
    );
  }
}
