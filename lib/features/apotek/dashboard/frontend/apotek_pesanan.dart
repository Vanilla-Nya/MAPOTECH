import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapotech/shared/widgets/skeleton_loading.dart';
import 'package:mapotech/features/landing/landing_page_data.dart';
import 'package:mapotech/shared/supabase_service.dart';

class IncomingPrescription {
  final String id;
  final int sessionNumber;
  final String patientName;
  final String doctorName;
  final String date;
  String status; // 'pending', 'compounding', 'ready', 'completed'
  final List<RxItem> items;

  IncomingPrescription({
    required this.id,
    required this.sessionNumber,
    required this.patientName,
    required this.doctorName,
    required this.date,
    required this.status,
    required this.items,
  });
}

class RxItem {
  final String name;
  final String dosage;
  final int qty;
  final String unit;

  const RxItem({
    required this.name,
    required this.dosage,
    required this.qty,
    required this.unit,
  });
}

class ApotekPesanan extends ConsumerStatefulWidget {
  const ApotekPesanan({super.key});

  @override
  ConsumerState<ApotekPesanan> createState() => _ApotekPesananState();
}

class _ApotekPesananState extends ConsumerState<ApotekPesanan> {
  final SupabaseService _db = SupabaseService();
  bool _isLoading = true;

  // Mock / database incoming prescriptions queue
  List<IncomingPrescription> _orders = [];
  String _activeTab = 'pending'; // 'pending', 'compounding', 'ready', 'completed'

  @override
  void initState() {
    super.initState();
    _loadOrdersFromDatabase();
  }

  Future<void> _loadOrdersFromDatabase() async {
    setState(() => _isLoading = true);
    try {
      final List<IncomingPrescription> loaded = [];
      final rawRx = await _db.fetchPendingPrescriptions();

      for (final rx in rawRx) {
        final String id = rx['id'] ?? '';
        final String status = rx['status'] ?? 'pending';
        final notes = rx['notes'] ?? '';
        String patient = 'Umum / Walk-in';
        String doctor = 'Resep Manual';
        try {
          if (notes.startsWith('{')) {
            final decoded = jsonDecode(notes);
            patient = decoded['patientName'] ?? patient;
            doctor = decoded['doctorName'] ?? doctor;
          } else if (notes.contains('|')) {
            patient = notes.split('|').first.trim();
          } else {
            patient = notes;
          }
        } catch (_) {}

        String displayStatus = 'pending';
        if (status == 'pending_checkout') {
          displayStatus = 'ready';
        } else if (status == 'checked_out') {
          displayStatus = 'completed';
        } else {
          displayStatus = status; // e.g. compounding
        }

        loaded.add(IncomingPrescription(
          id: id,
          sessionNumber: 1,
          patientName: patient,
          doctorName: doctor,
          date: '27 Mei 2026',
          status: displayStatus,
          items: const [
            RxItem(name: 'Paracetamol 500mg', dosage: '3x1 Sehari', qty: 2, unit: 'Strip'),
          ],
        ));
      }

      setState(() {
        _orders = loaded;
        _isLoading = false;
      });
    } catch (e) {
      // Offline fallback
      setState(() {
        _orders = [
          IncomingPrescription(
            id: 'RX-8827',
            sessionNumber: 14,
            patientName: 'Budi Santoso (Local)',
            doctorName: 'dr. Agoes Soetanto',
            date: 'Hari ini, 12:30',
            status: 'compounding',
            items: const [
              RxItem(name: 'Paracetamol 500mg', dosage: '3x1 Sehari', qty: 2, unit: 'Strip'),
            ],
          ),
        ];
        _isLoading = false;
      });
    }
  }

  Future<void> _advanceOrderStatus(IncomingPrescription order) async {
    setState(() => _isLoading = true);
    try {
      String dbStatus = 'pending';
      if (order.status == 'pending') {
        dbStatus = 'compounding';
        _activeTab = 'compounding';
      } else if (order.status == 'compounding') {
        dbStatus = 'pending_checkout';
        _activeTab = 'ready';
      } else if (order.status == 'ready') {
        dbStatus = 'checked_out';
        _activeTab = 'completed';
      }

      // Update status row in database
      await _db.updatePrescriptionStatus(order.id, dbStatus);
      await _loadOrdersFromDatabase();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Status resep ${order.patientName} berhasil diperbarui di database.', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600)),
          backgroundColor: const Color(0xFF48C9B0),
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memperbarui status antrian: $e', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600)),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
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

    // Count states
    int pendingCount = _orders.where((o) => o.status == 'pending').length;
    int compoundingCount = _orders.where((o) => o.status == 'compounding').length;
    int readyCount = _orders.where((o) => o.status == 'ready').length;
    int completedCount = _orders.where((o) => o.status == 'completed').length;

    final filteredOrders = _orders.where((o) => o.status == _activeTab).toList();

    return _isLoading
        ? const SkeletonScope(
            child: SkeletonApotekDashboard(type: 'orders'),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Tabs tracking columns
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: cardBgColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: borderColor),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildTabButton('Antrian', 'pending', pendingCount, Colors.orangeAccent),
                      const SizedBox(width: 8),
                      _buildTabButton('Diracik', 'compounding', compoundingCount, Colors.amber),
                      const SizedBox(width: 8),
                      _buildTabButton('Siap', 'ready', readyCount, themeAccent),
                      const SizedBox(width: 8),
                      _buildTabButton('Selesai', 'completed', completedCount, const Color(0xFF6F6A8A)),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // List of Active Order Tickets
              Expanded(
                child: filteredOrders.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.assignment_turned_in_rounded, size: 48, color: themeAccent.withOpacity(0.3)),
                            const SizedBox(height: 12),
                            Text(
                              'Tidak Ada Antrian',
                              style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w900, color: textColor),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Antrian resep untuk kategori ini kosong.',
                              style: GoogleFonts.outfit(fontSize: 10, color: subtitleColor),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 24),
                        itemCount: filteredOrders.length,
                        itemBuilder: (context, index) {
                          final rx = filteredOrders[index];

                          Color statusColor = Colors.orangeAccent;
                          String statusLabel = 'Dalam Antrian';
                          String actionLabel = 'MULAI MERACIK';
                          IconData actionIcon = Icons.hourglass_top_rounded;

                          if (rx.status == 'compounding') {
                            statusColor = Colors.amber;
                            statusLabel = 'Sedang Diracik';
                            actionLabel = 'SELESAIKAN RACIKAN';
                            actionIcon = Icons.check_circle_outline_rounded;
                          } else if (rx.status == 'ready') {
                            statusColor = themeAccent;
                            statusLabel = 'Siap Diambil / Checkout';
                            actionLabel = 'SELESAIKAN TRANSAKSI';
                            actionIcon = Icons.shopping_bag_rounded;
                          } else if (rx.status == 'completed') {
                            statusColor = const Color(0xFF6F6A8A);
                            statusLabel = 'Selesai';
                          }

                          return Container(
                            margin: const EdgeInsets.only(bottom: 14),
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: cardBgColor,
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(color: borderColor),
                            ),
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
                                          rx.patientName,
                                          style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w900, color: textColor),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Sesi ${rx.sessionNumber} • ${rx.date}',
                                          style: GoogleFonts.outfit(fontSize: 9, color: subtitleColor),
                                        ),
                                      ],
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: statusColor.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(100),
                                      ),
                                      child: Text(
                                        statusLabel,
                                        style: GoogleFonts.outfit(fontSize: 8, fontWeight: FontWeight.w900, color: statusColor),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Resep dari: ${rx.doctorName}',
                                  style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: subtitleColor),
                                ),
                                const SizedBox(height: 10),
                                Divider(color: borderColor),
                                const SizedBox(height: 10),
                                ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: rx.items.length,
                                  itemBuilder: (context, itemIdx) {
                                    final item = rx.items[itemIdx];
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 4),
                                      child: Row(
                                        children: [
                                          Icon(Icons.circle, size: 5, color: themeAccent),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              item.name,
                                              style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: textColor),
                                            ),
                                          ),
                                          Text(
                                            '${item.qty} ${item.unit} • ${item.dosage}',
                                            style: GoogleFonts.outfit(fontSize: 10, color: subtitleColor),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                                if (rx.status != 'completed') ...[
                                  const SizedBox(height: 18),
                                  ElevatedButton.icon(
                                    onPressed: () => _advanceOrderStatus(rx),
                                    icon: Icon(actionIcon, size: 14),
                                    label: Text(actionLabel, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: statusColor,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
  }

  Widget _buildTabButton(String label, String tabId, int count, Color color) {
    final active = _activeTab == tabId;
    return InkWell(
      onTap: () => setState(() => _activeTab = tabId),
      borderRadius: BorderRadius.circular(100),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? color.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: active ? color : Colors.transparent),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: active ? FontWeight.w900 : FontWeight.bold,
                color: active ? color : const Color(0xFF6F6A8A),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: active ? color : Colors.grey[200],
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
