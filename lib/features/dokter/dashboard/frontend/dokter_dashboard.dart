import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mapotech/features/landing/landing_page_data.dart';
import 'package:mapotech/shared/widgets/ui.dart';
import 'package:mapotech/features/dokter/dashboard/frontend/dokter_pasien.dart';
import 'package:mapotech/features/dokter/dashboard/frontend/dokter_obat.dart';
import 'package:mapotech/features/dokter/dashboard/frontend/dokter_antrian.dart';
import 'package:mapotech/shared/supabase_service.dart';

class DokterDashboard extends ConsumerStatefulWidget {
  const DokterDashboard({super.key});

  @override
  ConsumerState<DokterDashboard> createState() => _DokterDashboardState();
}

class _DokterDashboardState extends ConsumerState<DokterDashboard> {
  List<Map<String, dynamic>> _rawTransactions = [];
  String _qrToken = '';
  String _namaFaskes = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchData();
    });
  }

  Future<void> _fetchData() async {
    final userState = ref.read(landingPageProvider);
    final doctorId = userState.activeDoctorId ?? '8f93471a-74f8-486b-8e85-4002dc44c11c';
    
    // Load medicines (since it's not automatically loaded)
    try {
      ref.read(dokterObatListProvider.notifier).loadMedicines(doctorId);
    } catch (e) {
      debugPrint('Error triggering loadMedicines: $e');
    }
    
    // Load queues (to ensure latest data)
    try {
      ref.read(dokterAntrianListProvider.notifier).loadQueues();
    } catch (e) {
      debugPrint('Error triggering loadQueues: $e');
    }

    // Load patients
    try {
      ref.read(dokterPasienListProvider.notifier).loadPatients();
    } catch (e) {
      debugPrint('Error triggering loadPatients: $e');
    }

    try {
      final txs = await SupabaseService().fetchDoctorFinancialTransactions(doctorId);
      if (mounted) {
        setState(() {
          _rawTransactions = txs;
        });
      }
    } catch (e) {
      debugPrint('Error fetching dashboard transactions: $e');
    }

    try {
      final detail = await SupabaseService.client
          .from('user_detail_doctor')
          .select('qr_token, nama_faskes')
          .eq('id', doctorId)
          .maybeSingle();
      if (mounted && detail != null) {
        setState(() {
          _qrToken = detail['qr_token']?.toString() ?? '';
          _namaFaskes = detail['nama_faskes']?.toString() ?? '';
        });
      }
    } catch (e) {
      debugPrint('Error fetching doctor qr detail: $e');
    }
  }

  DateTime? _parseExpDate(String expDate) {
    try {
      if (expDate.contains('/')) {
        final parts = expDate.split('/').map((p) => p.trim()).toList();
        if (parts.length == 3) {
          final day = int.parse(parts[0]);
          final month = int.parse(parts[1]);
          final year = int.parse(parts[2]);
          return DateTime(year, month, day);
        }
      } else if (expDate.contains('-')) {
        return DateTime.tryParse(expDate);
      }
    } catch (_) {}
    return null;
  }

  String _getDayName(DateTime dt, String lang) {
    final weekday = dt.weekday;
    if (lang == 'en') {
      switch (weekday) {
        case 1: return 'Mon';
        case 2: return 'Tue';
        case 3: return 'Wed';
        case 4: return 'Thu';
        case 5: return 'Fri';
        case 6: return 'Sat';
        case 7: return 'Sun';
      }
    } else {
      switch (weekday) {
        case 1: return 'Sen';
        case 2: return 'Sel';
        case 3: return 'Rab';
        case 4: return 'Kam';
        case 5: return 'Jum';
        case 6: return 'Sab';
        case 7: return 'Min';
      }
    }
    return '';
  }

  String _formatToday(String lang) {
    final now = DateTime.now();
    final dayNamesEn = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final dayNamesId = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
    final monthNamesEn = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final monthNamesId = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];

    final dayName = lang == 'en' ? dayNamesEn[now.weekday - 1] : dayNamesId[now.weekday - 1];
    final monthName = lang == 'en' ? monthNamesEn[now.month - 1] : monthNamesId[now.month - 1];

    return '$dayName, ${now.day} $monthName ${now.year}';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(landingPageProvider);
    final notifier = ref.read(landingPageProvider.notifier);

    final isDark = state.appearance == 'dark';
    final cardBgColor = notifier.getCardColor();
    final textColor = notifier.getTextColor();
    final subtitleColor = notifier.getBodyTextColor();
    final borderColor = notifier.getBorderColor();

    final themeAccent = notifier.getPrimaryColor();
    final isMobile = MediaQuery.of(context).size.width < 768;

    // ─── Watch Providers ───
    final allPatients = ref.watch(dokterPasienListProvider);
    final allQueues = ref.watch(dokterAntrianListProvider);
    final allDrugs = ref.watch(dokterObatListProvider);

    // ─── Calculate Stats ───
    final totalPatients = allPatients.length;

    final now = DateTime.now();
    final todayQueues = allQueues.where((q) {
      if (q.dateQueue == null) return false;
      return q.dateQueue!.year == now.year &&
             q.dateQueue!.month == now.month &&
             q.dateQueue!.day == now.day;
    }).toList();

    int expiredObatCount = 0;
    int stokMinimCount = 0;

    for (final drug in allDrugs) {
      if (drug.totalStok <= 5) {
        stokMinimCount++;
      }
      for (final batch in drug.batches) {
        final exp = _parseExpDate(batch.expDate);
        if (exp != null && exp.isBefore(now)) {
          expiredObatCount++;
        }
      }
    }

    // ─── Calculate Patients Per Day Bar Chart (Last 7 Days) ───
    final last7Days = List.generate(7, (index) => now.subtract(Duration(days: 6 - index)));
    final List<double> barPercents = [];
    final List<int> barCounts = [];
    int maxQueueCount = 0;

    for (final day in last7Days) {
      final count = allQueues.where((q) {
        if (q.dateQueue == null) return false;
        return q.dateQueue!.year == day.year &&
               q.dateQueue!.month == day.month &&
               q.dateQueue!.day == day.day;
      }).length;
      barCounts.add(count);
      if (count > maxQueueCount) maxQueueCount = count;
    }

    for (final count in barCounts) {
      if (maxQueueCount == 0) {
        barPercents.add(0.0);
      } else {
        barPercents.add(count / maxQueueCount);
      }
    }

    // ─── Calculate Income Trend (Last 7 Days) ───
    final List<double> dailyIncomes = [];
    double maxIncome = 0.0;

    for (final day in last7Days) {
      double totalIncomeOfDay = 0.0;
      for (final tx in _rawTransactions) {
        if (tx['transaction_type'] != 'expense') {
          try {
            final txDate = DateTime.tryParse(tx['created_at'].toString());
            if (txDate != null &&
                txDate.year == day.year &&
                txDate.month == day.month &&
                txDate.day == day.day) {
              final amount = double.tryParse(tx['amount']?.toString() ?? '0') ?? 0.0;
              totalIncomeOfDay += amount;
            }
          } catch (_) {}
        }
      }
      dailyIncomes.add(totalIncomeOfDay);
      if (totalIncomeOfDay > maxIncome) {
        maxIncome = totalIncomeOfDay;
      }
    }

    final List<double> normalizedIncomes = [];
    for (final income in dailyIncomes) {
      if (maxIncome == 0.0) {
        normalizedIncomes.add(0.0);
      } else {
        normalizedIncomes.add(income / maxIncome);
      }
    }

    // ─── Calculate Weekly Income Comparison ───
    double thisWeekIncome = 0.0;
    double lastWeekIncome = 0.0;
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    final fourteenDaysAgo = now.subtract(const Duration(days: 14));

    for (final tx in _rawTransactions) {
      if (tx['transaction_type'] != 'expense') {
        try {
          final txDate = DateTime.tryParse(tx['created_at'].toString());
          if (txDate != null) {
            final amount = double.tryParse(tx['amount']?.toString() ?? '0') ?? 0.0;
            if (txDate.isAfter(sevenDaysAgo)) {
              thisWeekIncome += amount;
            } else if (txDate.isAfter(fourteenDaysAgo)) {
              lastWeekIncome += amount;
            }
          }
        } catch (_) {}
      }
    }

    String percentChangeText = '+0% ${state.language == 'en' ? 'from last week' : 'dari minggu lalu'}';
    Color percentColor = const Color(0xFF48C9B0);
    if (lastWeekIncome > 0) {
      final change = ((thisWeekIncome - lastWeekIncome) / lastWeekIncome) * 100;
      final prefix = change >= 0 ? '+' : '';
      percentChangeText = '$prefix${change.toStringAsFixed(1)}% ${state.language == 'en' ? 'from last week' : 'dari minggu lalu'}';
      percentColor = change >= 0 ? const Color(0xFF48C9B0) : Colors.redAccent;
    } else if (thisWeekIncome > 0) {
      percentChangeText = '+100% ${state.language == 'en' ? 'from last week' : 'dari minggu lalu'}';
      percentColor = const Color(0xFF48C9B0);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Doctor profile card welcome banner
        AnimatedEntrance(
          delay: Duration.zero,
          type: EntranceAnimationType.slideUp,
          child: Container(
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
                  child: ClipOval(
                    child: (state.loggedInUser?['avatar_url'] != null &&
                            (state.loggedInUser!['avatar_url'] as String).isNotEmpty &&
                            ((state.loggedInUser!['avatar_url'] as String).startsWith('http://') ||
                             (state.loggedInUser!['avatar_url'] as String).startsWith('https://')))
                        ? Image.network(
                            state.loggedInUser!['avatar_url'] as String,
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Center(
                              child: Text(
                                state.loggedInName != null && state.loggedInName!.isNotEmpty
                                    ? state.loggedInName!.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase()
                                    : 'DR',
                                style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white),
                              ),
                            ),
                          )
                        : Center(
                            child: Text(
                              state.loggedInName != null && state.loggedInName!.isNotEmpty
                                  ? state.loggedInName!.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase()
                                  : 'DR',
                              style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white),
                            ),
                          ),
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
                              color: themeAccent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Text(
                              notifier.t('SEDANG BERTUGAS'),
                              style: GoogleFonts.outfit(fontSize: 6.5, fontWeight: FontWeight.w900, color: themeAccent),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatToday(state.language),
                            style: GoogleFonts.outfit(fontSize: 9, color: subtitleColor, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        state.loggedInName ?? 'dr. Agoes Soetanto',
                        style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w900, color: textColor),
                      ),
                      Text(
                        state.isAssistant
                            ? 'Asisten Praktik dr. Agoes Soetanto'
                            : 'Dokter Praktek Mandiri ${state.loggedInName ?? "dr. Agoes Soetanto"}',
                        style: GoogleFonts.outfit(fontSize: 10, color: subtitleColor),
                      ),
                    ],
                  ),
                ),
                // QR Code Quick Access Card
                if (_qrToken.isNotEmpty) ...[
                  const SizedBox(width: 16),
                  InkWell(
                    onTap: () => _showZoomQrDialog(
                      context,
                      themeAccent,
                      textColor,
                      subtitleColor,
                      cardBgColor,
                      borderColor,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1E1E22)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: borderColor),
                            ),
                            child: QrImageView(
                              data: _qrToken,
                              version: QrVersions.auto,
                              size: 44,
                              backgroundColor: Colors.white,
                              errorCorrectionLevel: QrErrorCorrectLevel.M,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'QR Antrean',
                                    style: GoogleFonts.outfit(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: textColor,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(
                                    Icons.zoom_in_rounded,
                                    size: 14,
                                    color: themeAccent,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Klik untuk perbesar',
                                style: GoogleFonts.outfit(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w600,
                                  color: subtitleColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Indikator Kinerja Utama Cards Grid (metrics)
        AnimatedEntrance(
          delay: const Duration(milliseconds: 100),
          type: EntranceAnimationType.scale,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
                    count: '$totalPatients',
                    subtitleColor: subtitleColor,
                    countColor: textColor,
                    cardBgColor: cardBgColor,
                    borderColor: borderColor,
                  ),
                  MetricCard(
                    icon: Icons.calendar_today_rounded,
                    label: notifier.t('ANTREAN HARI INI'),
                    count: '${todayQueues.length}',
                    subtitleColor: subtitleColor,
                    countColor: textColor,
                    cardBgColor: cardBgColor,
                    borderColor: borderColor,
                  ),
                  MetricCard(
                    icon: Icons.warning_amber_rounded,
                    label: notifier.t('OBAT KEDALUWARSA'),
                    count: expiredObatCount.toString().padLeft(2, '0'),
                    subtitleColor: subtitleColor,
                    countColor: expiredObatCount > 0 ? Colors.redAccent : textColor,
                    cardBgColor: cardBgColor,
                    borderColor: borderColor,
                  ),
                  MetricCard(
                    icon: Icons.inventory_rounded,
                    label: notifier.t('STOK MENIPIS'),
                    count: '$stokMinimCount',
                    subtitleColor: subtitleColor,
                    countColor: stokMinimCount > 0 ? Colors.amber : textColor,
                    cardBgColor: cardBgColor,
                    borderColor: borderColor,
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 28),

        // Row housing Line Chart (Tren Pemasukan) & Bar Chart (Pasien per Hari)
        AnimatedEntrance(
          delay: const Duration(milliseconds: 200),
          type: EntranceAnimationType.slideUp,
          child: Row(
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
                        percentChangeText,
                        style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: percentColor),
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
                                painter: _IncomeTrendLinePainter(themeAccent, normalizedIncomes),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: last7Days
                            .map((day) => Text(_getDayName(day, state.language), style: TextStyle(color: subtitleColor, fontSize: 9)))
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
                        children: List.generate(7, (i) {
                          final d = last7Days[i];
                          final label = _getDayName(d, state.language);
                          final percent = barPercents[i];
                          final count = barCounts[i];
                          return _buildChartBar(label, percent, themeAccent, subtitleColor, count: count);
                        }),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 28),

        // Bottom Patients Queue List Table
        AnimatedEntrance(
          delay: const Duration(milliseconds: 300),
          type: EntranceAnimationType.slideUp,
          child: Container(
            decoration: BoxDecoration(
              color: cardBgColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: borderColor),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      notifier.t('DAFTAR ANTRIAN HARI INI'),
                      style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: textColor),
                    ),
                    Text(
                      notifier.t('${todayQueues.length} pasien'),
                      style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w900, color: textColor),
                    ),
                  ],
                ),
                const Divider(),
                if (todayQueues.isEmpty) ...[
                  const SizedBox(height: 48),
                  Center(
                    child: Text(
                      notifier.t('Belum ada pasien dalam antrean hari ini.'),
                      style: GoogleFonts.outfit(fontSize: 12, color: subtitleColor, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 48),
                ] else ...[
                  const SizedBox(height: 16),
                  // Table header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1E22) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(
                            notifier.t('NO.'),
                            style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w900, color: subtitleColor),
                          ),
                        ),
                        Expanded(
                          flex: 5,
                          child: Text(
                            notifier.t('NAMA PASIEN'),
                            style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w900, color: subtitleColor),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                            notifier.t('TIPE'),
                            style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w900, color: subtitleColor),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                            notifier.t('WAKTU'),
                            style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w900, color: subtitleColor),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                            notifier.t('STATUS'),
                            style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w900, color: subtitleColor),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: todayQueues.length,
                    separatorBuilder: (context, index) => Divider(color: borderColor, height: 1),
                    itemBuilder: (context, index) {
                      final antrian = todayQueues[index];
                      Color statusColor = Colors.grey;
                      if (antrian.status == 'Menunggu') {
                        statusColor = Colors.amber[700]!;
                      } else if (antrian.status == 'Memproses...') {
                        statusColor = themeAccent;
                      } else if (antrian.status == 'Pembayaran') {
                        statusColor = Colors.indigo;
                      } else if (antrian.status == 'Selesai') {
                        statusColor = const Color(0xFF27AE60);
                      }

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(
                                antrian.no,
                                style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: textColor),
                              ),
                            ),
                            Expanded(
                              flex: 5,
                              child: Row(
                                children: [
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: antrian.avatarBg.withValues(alpha: 0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      antrian.nama.isNotEmpty ? antrian.nama[0] : 'P',
                                      style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: antrian.avatarBg),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      antrian.nama,
                                      style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: textColor),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                antrian.tipe,
                                style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: subtitleColor),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                antrian.waktu,
                                style: GoogleFonts.outfit(fontSize: 10, color: subtitleColor),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Row(
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: statusColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    antrian.status,
                                    style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChartBar(String day, double percent, Color barColor, Color subtitleColor, {int count = 0}) {
    return Column(
      children: [
        Text(
          count > 0 ? '$count' : '',
          style: GoogleFonts.outfit(fontSize: 8, fontWeight: FontWeight.bold, color: barColor),
        ),
        const SizedBox(height: 4),
        Container(
          width: 24,
          height: 160,
          decoration: BoxDecoration(
            color: barColor.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.bottomCenter,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 600),
            width: 24,
            height: 160 * percent,
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

  void _showZoomQrDialog(
    BuildContext context,
    Color themeAccent,
    Color textColor,
    Color subtitleColor,
    Color cardBgColor,
    Color borderColor,
  ) {
    final state = ref.read(landingPageProvider);
    final isDark = state.appearance == 'dark';
    final doctorName = state.loggedInName ?? 'dr. Agoes Soetanto';
    final clinicName = _namaFaskes.isNotEmpty
        ? _namaFaskes
        : 'Dokter Praktek Mandiri $doctorName';

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Container(
            width: 440,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cardBgColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 25,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header: Title & Close Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: themeAccent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.qr_code_2_rounded,
                            color: themeAccent,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'QR Code Antrean Praktek',
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: textColor,
                              ),
                            ),
                            Text(
                              'Praktek Mandiri Terdaftar',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: subtitleColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: const Icon(Icons.close_rounded),
                      color: subtitleColor,
                      splashRadius: 18,
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // Doctor Info Box
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: themeAccent.withValues(alpha: isDark ? 0.15 : 0.07),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: themeAccent.withValues(alpha: 0.25)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        doctorName,
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: textColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        clinicName,
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: subtitleColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // Big Zoomed QR Box
                Center(
                  child: Container(
                    width: 250,
                    height: 250,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: borderColor, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: QrImageView(
                      data: _qrToken,
                      version: QrVersions.auto,
                      size: 218,
                      backgroundColor: Colors.white,
                      errorCorrectionLevel: QrErrorCorrectLevel.H,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: Color(0xFF1B0C3C),
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: Color(0xFF1B0C3C),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // Instruction / Subtitle
                Text(
                  'Pasien dapat memindai QR Code ini menggunakan Portal Pasien Mapotech untuk langsung mendaftar antrean saat ini.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: subtitleColor,
                    height: 1.4,
                  ),
                ),

                const SizedBox(height: 20),

                // Action Buttons: Download & Print
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final uri = Uri.parse(
                            'https://api.qrserver.com/v1/create-qr-code/?size=500x500&data=$_qrToken',
                          );
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          }
                        },
                        icon: const Icon(Icons.download_rounded, size: 16),
                        label: const Text('Download'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: textColor,
                          side: BorderSide(color: borderColor),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          textStyle: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final uri = Uri.parse(
                            'https://api.qrserver.com/v1/create-qr-code/?size=600x600&data=$_qrToken',
                          );
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          }
                        },
                        icon: const Icon(Icons.print_rounded, size: 16, color: Colors.white),
                        label: const Text('Cetak Standee'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: themeAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          textStyle: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Income Trend Line Custom Painter
class _IncomeTrendLinePainter extends CustomPainter {
  final Color lineColor;
  final List<double> dataPoints;

  _IncomeTrendLinePainter(this.lineColor, this.dataPoints);

  @override
  void paint(Canvas canvas, Size size) {
    if (dataPoints.isEmpty) return;

    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = lineColor.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;

    final path = Path();
    final fillPath = Path();

    final stepX = size.width / (dataPoints.length - 1);

    // Map each data point to its corresponding (x, y) coordinates
    final points = <Offset>[];
    for (int i = 0; i < dataPoints.length; i++) {
      final x = i * stepX;
      final y = size.height - (size.height * 0.8 * dataPoints[i]) - (size.height * 0.1);
      points.add(Offset(x, y));
    }

    path.moveTo(points[0].dx, points[0].dy);
    fillPath.moveTo(0, size.height);
    fillPath.lineTo(points[0].dx, points[0].dy);

    // Draw smooth bezier curve
    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final controlPoint1 = Offset(p0.dx + stepX / 2, p0.dy);
      final controlPoint2 = Offset(p1.dx - stepX / 2, p1.dy);

      path.cubicTo(
        controlPoint1.dx, controlPoint1.dy,
        controlPoint2.dx, controlPoint2.dy,
        p1.dx, p1.dy,
      );
      fillPath.cubicTo(
        controlPoint1.dx, controlPoint1.dy,
        controlPoint2.dx, controlPoint2.dy,
        p1.dx, p1.dy,
      );
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _IncomeTrendLinePainter oldDelegate) {
    return oldDelegate.lineColor != lineColor || oldDelegate.dataPoints != dataPoints;
  }
}
