import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapotech/shared/widgets/skeleton_loading.dart';
import 'package:mapotech/features/landing/landing_page_data.dart';
import 'package:mapotech/shared/supabase_service.dart';
import 'package:mapotech/features/apotek/dashboard/backend/prescription_provider.dart';
import 'widgets/web_qr_scanner.dart';

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
  final String? kfaCode;

  const RxItem({
    required this.name,
    required this.dosage,
    required this.qty,
    required this.unit,
    this.kfaCode,
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
        String doctor = 'Praktik Mandiri Dokter';
        List<RxItem> parsedItems = [];

        try {
          if (notes.startsWith('{')) {
            final decoded = jsonDecode(notes);
            patient = decoded['patientName'] ?? patient;
            doctor = decoded['doctorName'] ?? doctor;
            final itemsList = decoded['items'] as List<dynamic>?;
            if (itemsList != null && itemsList.isNotEmpty) {
              for (final it in itemsList) {
                parsedItems.add(RxItem(
                  name: it['name'] ?? 'Obat',
                  dosage: it['dosage'] ?? 'Sesuai Petunjuk',
                  qty: int.tryParse(it['qty']?.toString() ?? '1') ?? 1,
                  unit: it['unit'] ?? 'Tablet',
                  kfaCode: it['kfa_code'],
                ));
              }
            }
          } else if (notes.contains('|')) {
            patient = notes.split('|').first.trim();
          } else if (notes.isNotEmpty) {
            patient = notes;
          }
        } catch (_) {}

        if (parsedItems.isEmpty) {
          parsedItems = const [
            RxItem(name: 'Paracetamol 500mg', dosage: '3x1 Sehari', qty: 10, unit: 'Tablet', kfaCode: '93001030'),
            RxItem(name: 'Amoxicillin 500mg', dosage: '3x1 Sehari (Habiskan)', qty: 10, unit: 'Kaplet', kfaCode: '93001029'),
          ];
        }

        String displayStatus = 'pending';
        if (status == 'pending_checkout') {
          displayStatus = 'ready';
        } else if (status == 'checked_out') {
          displayStatus = 'completed';
        } else {
          displayStatus = status; // e.g. compounding
        }

        loaded.add(IncomingPrescription(
          id: id.isNotEmpty ? id : 'RX-8827',
          sessionNumber: loaded.length + 1,
          patientName: patient,
          doctorName: doctor,
          date: 'Hari ini',
          status: displayStatus,
          items: parsedItems,
        ));
      }

      if (loaded.isEmpty) {
        loaded.addAll([
          IncomingPrescription(
            id: 'RX-7721',
            sessionNumber: 12,
            patientName: 'Ahmad Fauzi',
            doctorName: 'dr. Agoes Soetanto, Sp.PD',
            date: 'Hari ini, 10:15',
            status: 'pending',
            items: const [
              RxItem(name: 'Amoxicillin 500mg', dosage: '3x1 Sehari (Habiskan)', qty: 10, unit: 'Tablet', kfaCode: '93001029'),
              RxItem(name: 'Paracetamol 500mg', dosage: '3x1 Sehari Jika Demam', qty: 10, unit: 'Tablet', kfaCode: '93001030'),
            ],
          ),
          IncomingPrescription(
            id: 'RX-8827',
            sessionNumber: 14,
            patientName: 'Budi Santoso',
            doctorName: 'dr. Agoes Soetanto, Sp.PD',
            date: 'Hari ini, 12:30',
            status: 'compounding',
            items: const [
              RxItem(name: 'Cetirizine 10mg', dosage: '1x1 Malam', qty: 5, unit: 'Tablet', kfaCode: '93001045'),
              RxItem(name: 'Vitamin C 500mg', dosage: '1x1 Pagi', qty: 10, unit: 'Tablet', kfaCode: '93001031'),
            ],
          ),
        ]);
      }

      setState(() {
        _orders = loaded;
        _isLoading = false;
      });
    } catch (e) {
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
    if (order.status == 'ready') {
      final rxOrder = ApotekPrescriptionOrder(
        id: order.id,
        sessionNumber: order.sessionNumber,
        patientName: order.patientName,
        doctorName: order.doctorName,
        date: order.date,
        status: 'ready',
        items: order.items.map((it) => ApotekRxItem(
          name: it.name,
          dosage: it.dosage,
          qty: it.qty,
          unit: it.unit,
          kfaCode: it.kfaCode,
        )).toList(),
      );

      ref.read(activePosPrescriptionProvider.notifier).state = rxOrder;
      ref.read(landingPageProvider.notifier).setActiveTab('penjualan');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Resep ${order.patientName} dialihkan ke Kasir (POS). Silakan selesaikan pembayaran.', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600)),
            backgroundColor: const Color(0xFF27AE60),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    setState(() => _isLoading = true);
    try {
      String dbStatus = 'pending';
      if (order.status == 'pending') {
        dbStatus = 'compounding';
        _activeTab = 'compounding';
      } else if (order.status == 'compounding') {
        dbStatus = 'pending_checkout';
        _activeTab = 'ready';
      }

      // Update status in database and provider
      await _db.updatePrescriptionStatus(order.id, dbStatus);
      await ref.read(apotekPrescriptionProvider.notifier).updateStatus(order.id, order.status == 'pending' ? 'compounding' : 'ready');
      await _loadOrdersFromDatabase();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              order.status == 'pending'
                  ? 'Resep ${order.patientName} mulai diracik.'
                  : 'Resep ${order.patientName} selesai diracik dan siap diproses di Kasir!',
              style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            backgroundColor: const Color(0xFF48C9B0),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memperbarui status antrian: $e', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600)),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _showQrScannerModal(BuildContext context, bool isDark, Color themeAccent, Color textColor, Color subtitleColor, Color cardBgColor, Color borderColor) {
    final user = ref.read(landingPageProvider).loggedInUser;
    final apotekId = user?['id']?.toString() ?? 'APOTEK-VERIFIED-001';
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (ctx) => _ApotekQrResepScannerDialog(
        apotekId: apotekId,
        isDark: isDark,
        themeAccent: themeAccent,
        textColor: textColor,
        subtitleColor: subtitleColor,
        cardBgColor: cardBgColor,
        borderColor: borderColor,
        onPrescriptionAccepted: (prescriptionData) async {
          Navigator.pop(ctx);
          setState(() => _isLoading = true);

          // Add to database
          await _db.ingestElectronicPrescriptionToPharmacyOrder(
            prescriptionData: prescriptionData,
            apotekId: apotekId,
          );

          await _loadOrdersFromDatabase();

          setState(() {
            _activeTab = 'pending';
            _isLoading = false;
          });

          if (!mounted) return;
          messenger.showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Resep digital untuk ${prescriptionData['patient_name'] ?? 'Pasien'} berhasil dibuka & disimpan ke database!',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF27AE60),
              duration: const Duration(seconds: 3),
            ),
          );
        },
      ),
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
              // Header action card with Scan QR Resep Dokter button
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: cardBgColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pesanan Masuk & Resep Digital',
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Validasi QR resep terkunci dari dokter dan kelola tahapan peracikan obat',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              color: subtitleColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => _showQrScannerModal(
                        context,
                        isDark,
                        themeAccent,
                        textColor,
                        subtitleColor,
                        cardBgColor,
                        borderColor,
                      ),
                      icon: const Icon(Icons.qr_code_scanner_rounded, size: 16, color: Colors.white),
                      label: Text(
                        'Scan QR Resep Dokter',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: themeAccent,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

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
              if (filteredOrders.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 60),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.assignment_turned_in_rounded, size: 48, color: themeAccent.withValues(alpha: 0.3)),
                      const SizedBox(height: 12),
                      Text(
                        'Tidak Ada Antrian',
                        style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w900, color: textColor),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Antrian resep untuk kategori ini kosong. Scan QR resep dokter untuk menambahkan.',
                        style: GoogleFonts.outfit(fontSize: 10, color: subtitleColor),
                      ),
                    ],
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
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
                      statusColor = const Color(0xFF27AE60);
                      statusLabel = 'Siap Diambil / Kasir';
                      actionLabel = 'PROSES DI KASIR (POS)';
                      actionIcon = Icons.point_of_sale_rounded;
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
                                  color: statusColor.withValues(alpha: 0.12),
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
          color: active ? color.withValues(alpha: 0.12) : Colors.transparent,
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

/// Modal QR Scanner & Decoder for Apotek with Live Camera Viewfinder & Locked QR Security Gate
class _ApotekQrResepScannerDialog extends StatefulWidget {
  final String apotekId;
  final bool isDark;
  final Color themeAccent;
  final Color textColor;
  final Color subtitleColor;
  final Color cardBgColor;
  final Color borderColor;
  final Function(Map<String, dynamic> prescriptionData) onPrescriptionAccepted;

  const _ApotekQrResepScannerDialog({
    required this.apotekId,
    required this.isDark,
    required this.themeAccent,
    required this.textColor,
    required this.subtitleColor,
    required this.cardBgColor,
    required this.borderColor,
    required this.onPrescriptionAccepted,
  });

  @override
  State<_ApotekQrResepScannerDialog> createState() => _ApotekQrResepScannerDialogState();
}

class _ApotekQrResepScannerDialogState extends State<_ApotekQrResepScannerDialog>
    with SingleTickerProviderStateMixin {
  final SupabaseService _db = SupabaseService();
  final TextEditingController _qrInputController = TextEditingController();

  late AnimationController _laserController;
  late Animation<double> _laserAnimation;

  bool _isApotekMode = true; // True = Authorized Apotek, False = General Public / Unauthorized
  bool _scanModeIsCamera = true; // True = Camera Scanner Viewfinder, False = Manual Token Input
  bool _isTorchOn = false;
  bool _isFrontCamera = false;
  bool _isProcessing = false;
  bool _isCameraReady = false;
  String? _cameraStatusMessage;
  Map<String, dynamic>? _scanResult;

  final List<Map<String, String>> _samplePrescriptions = [
    {
      'label': 'dr. Agoes Soetanto (Umum)',
      'token': 'MAPOTECH-SECURE-RX:RX-8827-AGOES',
    },
    {
      'label': 'dr. Maria Susanti (Sp.A)',
      'token': 'MAPOTECH-SECURE-RX:RX-9910-MARIA',
    },
    {
      'label': 'dr. Hendra Wijaya (Sp.PD)',
      'token': 'MAPOTECH-SECURE-RX:RX-4412-HENDRA',
    },
  ];

  @override
  void initState() {
    super.initState();
    _qrInputController.text = 'MAPOTECH-SECURE-RX:RX-8827-AGOES';

    _laserController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _laserAnimation = CurvedAnimation(
      parent: _laserController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _laserController.dispose();
    _qrInputController.dispose();
    super.dispose();
  }

  Future<void> _showConfirmationModal(Map<String, dynamic> data) async {
    final isDark = widget.isDark;
    final cardBgColor = widget.cardBgColor;
    final textColor = widget.textColor;
    final subtitleColor = widget.subtitleColor;
    final borderColor = widget.borderColor;
    final themeAccent = widget.themeAccent;

    final doctorName = data['doctor_name']?.toString() ?? 'dr. Agoes Soetanto, Sp.PD';
    final doctorSip = data['doctor_sip']?.toString() ?? 'SIP. 446/128/DINKES/2024';
    final patientName = data['patient_name']?.toString() ?? 'Pasien';
    final patientNik = data['patient_nik']?.toString() ?? '-';
    final items = (data['items'] as List<dynamic>? ?? []);

    await showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (modalCtx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Container(
            width: 520,
            constraints: const BoxConstraints(maxHeight: 680),
            decoration: BoxDecoration(
              color: cardBgColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Top Banner
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [const Color(0xFF1E3A34), const Color(0xFF132723)]
                            : [const Color(0xFF7BE5D3), const Color(0xFF48C9B0)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: const Icon(Icons.assignment_turned_in_rounded, color: Color(0xFF27AE60), size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Konfirmasi Penerimaan Resep',
                                style: GoogleFonts.outfit(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Apakah Anda yakin ingin menerima resep dokter ini?',
                                style: GoogleFonts.outfit(
                                  fontSize: 10.5,
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white),
                          onPressed: () => Navigator.pop(modalCtx),
                          splashRadius: 18,
                        ),
                      ],
                    ),
                  ),

                  // Content Body
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Doctor & Patient Info Cards
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E1E22) : const Color(0xFFF8FAFD),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: borderColor),
                            ),
                            child: Column(
                              children: [
                                // Doctor Row
                                Row(
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: themeAccent.withValues(alpha: 0.15),
                                        shape: BoxShape.circle,
                                      ),
                                      alignment: Alignment.center,
                                      child: Icon(Icons.medical_services_rounded, size: 18, color: themeAccent),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'DARI DOKTER:',
                                            style: GoogleFonts.outfit(fontSize: 8.5, fontWeight: FontWeight.w800, color: subtitleColor),
                                          ),
                                          Text(
                                            doctorName,
                                            style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: textColor),
                                          ),
                                          Text(
                                            doctorSip,
                                            style: GoogleFonts.outfit(fontSize: 9.5, color: subtitleColor),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),

                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  child: Divider(height: 1, color: borderColor),
                                ),

                                // Patient Row
                                Row(
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                                        shape: BoxShape.circle,
                                      ),
                                      alignment: Alignment.center,
                                      child: const Icon(Icons.person_rounded, size: 18, color: Color(0xFF3B82F6)),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'UNTUK PASIEN:',
                                            style: GoogleFonts.outfit(fontSize: 8.5, fontWeight: FontWeight.w800, color: subtitleColor),
                                          ),
                                          Text(
                                            patientName,
                                            style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: textColor),
                                          ),
                                          Text(
                                            'NIK: $patientNik',
                                            style: GoogleFonts.outfit(fontSize: 9.5, color: subtitleColor),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Prescription Items Section
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'DAFTAR OBAT & ATURAN PAKAI:',
                                style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: textColor),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF27AE60).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(100),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.verified_rounded, size: 11, color: Color(0xFF27AE60)),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${items.length} Macam Obat',
                                      style: GoogleFonts.outfit(fontSize: 8.5, fontWeight: FontWeight.w900, color: const Color(0xFF27AE60)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          Container(
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E1E22) : const Color(0xFFF8FAFD),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: borderColor),
                            ),
                            child: ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              padding: const EdgeInsets.all(10),
                              itemCount: items.length,
                              separatorBuilder: (_, _) => Divider(height: 12, color: borderColor),
                              itemBuilder: (context, index) {
                                final it = items[index];
                                return Row(
                                  children: [
                                    Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        color: themeAccent.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      alignment: Alignment.center,
                                      child: Icon(Icons.medication_rounded, size: 14, color: themeAccent),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            it['name']?.toString() ?? 'Obat',
                                            style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.bold, color: textColor),
                                          ),
                                          Text(
                                            '${it['dosage'] ?? '-'} ${it['instructions'] != null && it['instructions'].toString().isNotEmpty ? '• ${it['instructions']}' : ''}',
                                            style: GoogleFonts.outfit(fontSize: 9.5, color: subtitleColor),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: cardBgColor,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: borderColor),
                                      ),
                                      child: Text(
                                        '${it['qty']} ${it['unit']}',
                                        style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w800, color: themeAccent),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Bottom Action Buttons
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF18181B) : const Color(0xFFFAFAFC),
                      border: Border(top: BorderSide(color: borderColor)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(modalCtx),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: borderColor),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text(
                              'Batal',
                              style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.w600, color: subtitleColor),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(modalCtx);
                              widget.onPrescriptionAccepted(data);
                            },
                            icon: const Icon(Icons.check_circle_rounded, size: 16, color: Colors.white),
                            label: Text(
                              'Ya, Terima Resep Ini',
                              style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF27AE60),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _processScan({String? customPayload}) async {
    final rawText = (customPayload ?? _qrInputController.text).trim();
    if (rawText.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Arahkan QR Code E-Resep ke kamera atau gunakan sampel resep di bawah.'),
            duration: Duration(seconds: 2),
            backgroundColor: Color(0xFF1E293B),
          ),
        );
      }
      return;
    }

    if (customPayload != null) {
      _qrInputController.text = customPayload;
    }

    setState(() {
      _isProcessing = true;
      _scanResult = null;
    });

    // Brief processing delay for responsive UI feedback
    await Future.delayed(const Duration(milliseconds: 300));

    if (!_isApotekMode) {
      // Simulate general public / unauthorized scanner
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _scanResult = {
            'is_locked': true,
            'is_verified': false,
            'error': 'Akses Dibatasi: QR Resep Digital Terkunci. Hanya Apotek resmi dengan ID & Kunci Apotek terverifikasi yang dapat membuka resep medis ini.',
          };
        });
      }
      return;
    }

    // Authorized Apotek decryption
    final result = await _db.unlockAndVerifyPrescriptionQr(
      qrPayload: rawText,
      apotekId: widget.apotekId,
    );

    if (mounted) {
      setState(() {
        _isProcessing = false;
      });

      if (result['is_verified'] == true) {
        _showConfirmationModal(result);
      } else {
        setState(() {
          _scanResult = result;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final cardBgColor = widget.cardBgColor;
    final textColor = widget.textColor;
    final subtitleColor = widget.subtitleColor;
    final borderColor = widget.borderColor;
    final themeAccent = widget.themeAccent;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Container(
        width: 620,
        constraints: const BoxConstraints(maxHeight: 780),
        decoration: BoxDecoration(
          color: cardBgColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF1E3A34), const Color(0xFF132723)]
                        : [const Color(0xFF7BE5D3), const Color(0xFF48C9B0)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Icon(Icons.qr_code_scanner_rounded, color: themeAccent, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Scan & Validasi QR Resep Dokter',
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Kamera Scanner & Dekripsi Resep Digital Terkunci',
                            style: GoogleFonts.outfit(
                              fontSize: 10.5,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                      splashRadius: 18,
                    ),
                  ],
                ),
              ),

              // Content Body
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Scanner authorization simulator toggle
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E1E22) : const Color(0xFFF8FAFD),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: borderColor),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  _isApotekMode ? Icons.verified_user_rounded : Icons.lock_outline_rounded,
                                  color: _isApotekMode ? const Color(0xFF27AE60) : Colors.redAccent,
                                  size: 18,
                                ),
                                const SizedBox(width: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _isApotekMode ? 'Otorisasi: Apotek Terdaftar' : 'Simulasi: Publik / Tidak Terdaftar',
                                      style: GoogleFonts.outfit(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.bold,
                                        color: textColor,
                                      ),
                                    ),
                                    Text(
                                      _isApotekMode ? 'ID Apotek: ${widget.apotekId}' : 'Akses scanner tanpa Kunci Apotek',
                                      style: GoogleFonts.outfit(
                                        fontSize: 9.5,
                                        color: subtitleColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Switch.adaptive(
                              value: _isApotekMode,
                              activeTrackColor: themeAccent,
                              onChanged: (val) {
                                setState(() {
                                  _isApotekMode = val;
                                  _scanResult = null;
                                });
                              },
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Mode Switcher Tabs (Camera Scanner vs Manual Token)
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF18181B) : const Color(0xFFF0F3F8),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: borderColor),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildModeTabButton(
                                label: 'Kamera Scanner',
                                icon: Icons.camera_alt_rounded,
                                isSelected: _scanModeIsCamera,
                                onTap: () => setState(() => _scanModeIsCamera = true),
                                themeAccent: themeAccent,
                                textColor: textColor,
                                isDark: isDark,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: _buildModeTabButton(
                                label: 'Input Manual Token',
                                icon: Icons.keyboard_alt_rounded,
                                isSelected: !_scanModeIsCamera,
                                onTap: () => setState(() => _scanModeIsCamera = false),
                                themeAccent: themeAccent,
                                textColor: textColor,
                                isDark: isDark,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      // ─── 1. CAMERA SCANNER VIEWFINDER ───
                      if (_scanModeIsCamera) ...[
                        Container(
                          width: double.infinity,
                          height: 250,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F141C),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: themeAccent.withValues(alpha: 0.4), width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.4),
                                blurRadius: 15,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Live Camera Feed from PC webcam
                              Positioned.fill(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: buildWebQrScannerWidget(
                                    onScanned: (scannedCode) {
                                      _processScan(customPayload: scannedCode);
                                    },
                                    isFrontCamera: _isFrontCamera,
                                    isTorchOn: _isTorchOn,
                                    onCameraStatusChanged: (isReady, msg) {
                                      if (mounted) {
                                        setState(() {
                                          _isCameraReady = isReady;
                                          _cameraStatusMessage = msg;
                                        });
                                      }
                                    },
                                    onCameraSwitch: () {
                                      setState(() {
                                        _isFrontCamera = !_isFrontCamera;
                                      });
                                    },
                                  ),
                                ),
                              ),

                              // Viewfinder Target Box in the middle
                              AnimatedBuilder(
                                animation: _laserAnimation,
                                builder: (context, child) {
                                  return SizedBox(
                                    width: 170,
                                    height: 170,
                                    child: CustomPaint(
                                      painter: _ScannerTargetPainter(
                                        laserProgress: _laserAnimation.value,
                                        accentColor: themeAccent,
                                      ),
                                      child: Center(
                                        child: Icon(
                                          Icons.qr_code_2_rounded,
                                          size: 70,
                                          color: Colors.white.withValues(alpha: 0.08),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),

                              // Live Status Pill & Controls on top of camera
                              Positioned(
                                top: 12,
                                left: 14,
                                right: 14,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.65),
                                        borderRadius: BorderRadius.circular(100),
                                        border: Border.all(
                                          color: _isCameraReady
                                              ? const Color(0xFF27AE60).withValues(alpha: 0.6)
                                              : Colors.amber.withValues(alpha: 0.6),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 7,
                                            height: 7,
                                            decoration: BoxDecoration(
                                              color: _isCameraReady ? const Color(0xFF2ECC71) : Colors.amber,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            _isCameraReady
                                                ? (_cameraStatusMessage?.toUpperCase() ?? 'KAMERA AKTIF')
                                                : 'MENDETEKSI KAMERA...',
                                            style: GoogleFonts.outfit(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w900,
                                              color: _isCameraReady ? const Color(0xFF2ECC71) : Colors.amber,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        // Flashlight toggle
                                        InkWell(
                                          onTap: () => setState(() => _isTorchOn = !_isTorchOn),
                                          borderRadius: BorderRadius.circular(100),
                                          child: Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: _isTorchOn
                                                  ? Colors.amber.withValues(alpha: 0.25)
                                                  : Colors.black.withValues(alpha: 0.6),
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: _isTorchOn ? Colors.amber : Colors.white24,
                                              ),
                                            ),
                                            child: Icon(
                                              _isTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                                              color: _isTorchOn ? Colors.amber : Colors.white70,
                                              size: 16,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        // Flip camera
                                        InkWell(
                                          onTap: () => setState(() => _isFrontCamera = !_isFrontCamera),
                                          borderRadius: BorderRadius.circular(100),
                                          child: Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withValues(alpha: 0.6),
                                              shape: BoxShape.circle,
                                              border: Border.all(color: Colors.white24),
                                            ),
                                            child: const Icon(
                                              Icons.flip_camera_ios_rounded,
                                              color: Colors.white70,
                                              size: 16,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              // Bottom guide instruction text
                              Positioned(
                                bottom: 10,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.65),
                                    borderRadius: BorderRadius.circular(100),
                                  ),
                                  child: Text(
                                    _isProcessing
                                        ? 'Memindai & mendekripsi E-Resep...'
                                        : 'Arahkan QR Code E-Resep pasien ke dalam kotak pemindai',
                                    style: GoogleFonts.outfit(
                                      fontSize: 9.5,
                                      color: Colors.white.withValues(alpha: 0.85),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Shutter / Manual Capture Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isProcessing ? null : () => _processScan(),
                            icon: _isProcessing
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.qr_code_scanner_rounded, size: 18, color: Colors.white),
                            label: Text(
                              _isProcessing ? 'Memindai & Mendekripsi...' : 'Scan & Dekripsi QR Code',
                              style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: themeAccent,
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ] else ...[
                        // ─── 2. MANUAL TOKEN INPUT ───
                        Text(
                          'Payload / Token QR Code',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 46,
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E1E22) : const Color(0xFFF8FAFD),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: borderColor),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 14),
                                child: TextField(
                                  controller: _qrInputController,
                                  style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: textColor),
                                  decoration: InputDecoration(
                                    hintText: 'Masukkan token QR resep...',
                                    hintStyle: GoogleFonts.outfit(fontSize: 11, color: subtitleColor),
                                    border: InputBorder.none,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: _isProcessing ? null : () => _processScan(),
                              icon: _isProcessing
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Icon(Icons.check_circle_outline_rounded, size: 16, color: Colors.white),
                              label: Text(
                                _isProcessing ? 'Memproses...' : 'Dekripsi',
                                style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: themeAccent,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                elevation: 0,
                              ),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 12),

                      // Quick Sample Prescriptions Chips
                      Text(
                        'Uji Coba Cepat Resep Dokter:',
                        style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: subtitleColor),
                      ),
                      const SizedBox(height: 6),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _samplePrescriptions.map((sample) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: InkWell(
                                onTap: () {
                                  _qrInputController.text = sample['token']!;
                                  _processScan(customPayload: sample['token']);
                                },
                                borderRadius: BorderRadius.circular(100),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: themeAccent.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(100),
                                    border: Border.all(color: themeAccent.withValues(alpha: 0.3)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.local_hospital_rounded, size: 11, color: themeAccent),
                                      const SizedBox(width: 4),
                                      Text(
                                        sample['label']!,
                                        style: GoogleFonts.outfit(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.bold,
                                          color: themeAccent,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Scan Result Panel
                      if (_scanResult != null) ...[
                        if (_scanResult!['is_locked'] == true) ...[
                          // ─── LOCKED STATE ───
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
                            ),
                            child: Column(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: Colors.red.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: const Icon(Icons.lock_rounded, size: 24, color: Colors.redAccent),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  '🔒 AKSES DIBATASI - RESEP TERKUNCI',
                                  style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.redAccent,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _scanResult!['error'] ?? 'Resep medis ini terkunci. Hanya Apotek resmi yang dapat membuka resep.',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    color: subtitleColor,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else if (_scanResult!['error'] != null) ...[
                          // ─── UNRECOGNIZED / INVALID QR STATE ───
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                            ),
                            child: Column(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: const Icon(Icons.warning_amber_rounded, size: 24, color: Colors.amber),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'QR CODE BUKAN E-RESEP VALID',
                                  style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.amber.shade700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _scanResult!['error'] ?? 'QR Code tidak dikenali sebagai E-Resep MAPOTECH.',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    color: subtitleColor,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeTabButton({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required Color themeAccent,
    required Color textColor,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF27272A) : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? themeAccent : textColor.withValues(alpha: 0.5),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                color: isSelected ? textColor : textColor.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom painter for camera scanner target box with corner brackets and laser line
class _ScannerTargetPainter extends CustomPainter {
  final double laserProgress;
  final Color accentColor;

  _ScannerTargetPainter({
    required this.laserProgress,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const cornerLength = 22.0;
    const cornerRadius = 8.0;

    final cornerPaint = Paint()
      ..color = const Color(0xFF2ECC71)
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final glowBorderPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.25)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(16),
    );

    // Subtle outline border
    canvas.drawRRect(rect, glowBorderPaint);

    // Top-Left Corner
    final tlPath = Path()
      ..moveTo(0, cornerLength)
      ..lineTo(0, cornerRadius)
      ..arcToPoint(const Offset(cornerRadius, 0), radius: const Radius.circular(cornerRadius))
      ..lineTo(cornerLength, 0);
    canvas.drawPath(tlPath, cornerPaint);

    // Top-Right Corner
    final trPath = Path()
      ..moveTo(size.width - cornerLength, 0)
      ..lineTo(size.width - cornerRadius, 0)
      ..arcToPoint(Offset(size.width, cornerRadius), radius: const Radius.circular(cornerRadius))
      ..lineTo(size.width, cornerLength);
    canvas.drawPath(trPath, cornerPaint);

    // Bottom-Left Corner
    final blPath = Path()
      ..moveTo(0, size.height - cornerLength)
      ..lineTo(0, size.height - cornerRadius)
      ..arcToPoint(Offset(cornerRadius, size.height), radius: const Radius.circular(cornerRadius))
      ..lineTo(cornerLength, size.height);
    canvas.drawPath(blPath, cornerPaint);

    // Bottom-Right Corner
    final brPath = Path()
      ..moveTo(size.width - cornerLength, size.height)
      ..lineTo(size.width - cornerRadius, size.height)
      ..arcToPoint(Offset(size.width, size.height - cornerRadius), radius: const Radius.circular(cornerRadius))
      ..lineTo(size.width, size.height - cornerLength);
    canvas.drawPath(brPath, cornerPaint);

    // Animated Laser Scanning Line
    final laserY = laserProgress * (size.height - 16) + 8;
    final laserPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          const Color(0xFF2ECC71).withValues(alpha: 0.5),
          const Color(0xFF2ECC71),
          const Color(0xFF2ECC71).withValues(alpha: 0.5),
          Colors.transparent,
        ],
        stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
      ).createShader(Rect.fromLTWH(0, laserY - 2, size.width, 4))
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(8, laserY), Offset(size.width - 8, laserY), laserPaint);
  }

  @override
  bool shouldRepaint(covariant _ScannerTargetPainter oldDelegate) {
    return oldDelegate.laserProgress != laserProgress || oldDelegate.accentColor != accentColor;
  }
}

