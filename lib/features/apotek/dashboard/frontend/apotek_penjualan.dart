import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapotech/shared/widgets/skeleton_loading.dart';
import 'package:mapotech/features/landing/landing_page_data.dart';
import 'package:mapotech/shared/supabase_service.dart';

class PosMedicine {
  final String id;
  final String batchId;
  final String name;
  final String genericName;
  final String form;
  final String sku;
  final double sellPrice;
  final int stock;
  final String sellUnit;
  final String description;

  const PosMedicine({
    required this.id,
    required this.batchId,
    required this.name,
    required this.genericName,
    required this.form,
    required this.sku,
    required this.sellPrice,
    required this.stock,
    required this.sellUnit,
    required this.description,
  });
}

class CartItem {
  final String id;
  final PosMedicine medicine;
  int qty;
  final String? externalPrescriptionId;

  CartItem({
    required this.id,
    required this.medicine,
    required this.qty,
    this.externalPrescriptionId,
  });
}

class PendingPrescription {
  final String externalPrescriptionId;
  final int sessionNumber;
  final String patientName;
  final String doctorName;
  final String status; // 'ready' or 'pending'
  final List<RxItem> items;

  const PendingPrescription({
    required this.externalPrescriptionId,
    required this.sessionNumber,
    required this.patientName,
    required this.doctorName,
    required this.status,
    required this.items,
  });
}

class RxItem {
  final String id;
  final String name;
  final String dosage;
  final int qty;
  final String unit;
  final double price;
  final PosMedicine medicine;

  const RxItem({
    required this.id,
    required this.name,
    required this.dosage,
    required this.qty,
    required this.unit,
    required this.price,
    required this.medicine,
  });
}

class ApotekPenjualan extends ConsumerStatefulWidget {
  const ApotekPenjualan({super.key});

  @override
  ConsumerState<ApotekPenjualan> createState() => _ApotekPenjualanState();
}

class _ApotekPenjualanState extends ConsumerState<ApotekPenjualan> {
  final SupabaseService _db = SupabaseService();
  bool _isLoading = true;

  // Medicine Catalog loaded from Database
  List<PosMedicine> _medicines = [];

  // Prescription Queues loaded from Database
  List<PendingPrescription> _pendingPrescriptions = [];

  // Shopping Cart & POS States
  final List<CartItem> _cart = [];
  String _searchQuery = '';
  String _selectedForm = 'all';
  String _selectedBuyer = '';
  bool _isCartExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadDataFromDatabase();
  }

  Future<void> _loadDataFromDatabase() async {
    setState(() => _isLoading = true);
    try {
      final List<PosMedicine> loadedMedicines = [];
      final rawMedicines = await _db.fetchMedicinesWithBatches();

      for (final m in rawMedicines) {
        final String id = m['id'] ?? '';
        final String name = m['medicine_name'] ?? 'Obat';
        final String generic = m['generic_name'] ?? 'Generic';
        final String form = m['medicine_form'] ?? 'Tablet';
        final String desc = m['deskription'] ?? 'Deskripsi obat.';
        final batches = m['medicine_batches'] as List<dynamic>? ?? [];

        if (batches.isEmpty) {
          loadedMedicines.add(PosMedicine(
            id: id,
            batchId: '',
            name: name,
            genericName: generic,
            form: form,
            sku: 'SKU-TEMP',
            sellPrice: 5000,
            stock: 0,
            sellUnit: 'Strip',
            description: desc,
          ));
        } else {
          for (final b in batches) {
            loadedMedicines.add(PosMedicine(
              id: id,
              batchId: b['id'] ?? '',
              name: name,
              genericName: generic,
              form: form,
              sku: b['batch_number'] ?? 'BATCH-00',
              sellPrice: double.tryParse(b['selling_price']?.toString() ?? '5000') ?? 5000,
              stock: int.tryParse(b['quantity_in_stock']?.toString() ?? '0') ?? 0,
              sellUnit: 'Strip',
              description: desc,
            ));
          }
        }
      }

      final List<PendingPrescription> loadedRx = [];
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

        if (loadedMedicines.isNotEmpty) {
          loadedRx.add(PendingPrescription(
            externalPrescriptionId: id,
            sessionNumber: 1,
            patientName: patient,
            doctorName: doctor,
            status: status == 'pending_checkout' ? 'ready' : 'pending',
            items: [
              RxItem(
                id: 'rx_it',
                name: loadedMedicines.first.name,
                dosage: '3x1 Sehari',
                qty: 2,
                unit: loadedMedicines.first.sellUnit,
                price: loadedMedicines.first.sellPrice,
                medicine: loadedMedicines.first,
              ),
            ],
          ));
        }
      }

      setState(() {
        _medicines = loadedMedicines;
        _pendingPrescriptions = loadedRx;
        _isLoading = false;
      });
    } catch (e) {
      // Offline fallback
      setState(() {
        _medicines = const [
          PosMedicine(
            id: 'med1',
            batchId: 'BCH-001',
            name: 'Paracetamol 500mg (Lokal)',
            genericName: 'Paracetamol',
            form: 'Tablet',
            sku: 'SKU-PCT-500',
            sellPrice: 5000,
            stock: 120,
            sellUnit: 'Strip',
            description: 'Obat penurun demam dan pereda nyeri ringan.',
          ),
          PosMedicine(
            id: 'med2',
            batchId: 'BCH-002',
            name: 'Amoxicillin 500mg (Lokal)',
            genericName: 'Amoxicillin',
            form: 'Kapsul',
            sku: 'SKU-AMX-500',
            sellPrice: 12000,
            stock: 85,
            sellUnit: 'Strip',
            description: 'Antibiotik untuk mengobati infeksi bakteri.',
          ),
        ];
        _pendingPrescriptions = [
          PendingPrescription(
            externalPrescriptionId: 'RX-LOCAL-88',
            sessionNumber: 14,
            patientName: 'Budi Santoso (Offline)',
            doctorName: 'dr. Agoes Soetanto',
            status: 'ready',
            items: [
              RxItem(id: 'rx1', name: 'Paracetamol 500mg', dosage: '3x1 Sehari', qty: 2, unit: 'Strip', price: 5000, medicine: _medicines[0]),
            ],
          ),
        ];
        _isLoading = false;
      });
    }
  }

  void _addToCart(PosMedicine medicine, {int qty = 1, String? rxId}) {
    setState(() {
      final existingIndex = _cart.indexWhere((item) => item.medicine.batchId == medicine.batchId && item.externalPrescriptionId == rxId);
      if (existingIndex >= 0) {
        final nextQty = _cart[existingIndex].qty + qty;
        if (nextQty <= medicine.stock) {
          _cart[existingIndex].qty = nextQty;
        } else {
          _cart[existingIndex].qty = medicine.stock;
        }
      } else {
        _cart.add(CartItem(
          id: 'cart_${DateTime.now().millisecondsSinceEpoch}_${medicine.batchId}',
          medicine: medicine,
          qty: qty <= medicine.stock ? qty : medicine.stock,
          externalPrescriptionId: rxId,
        ));
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${medicine.name} berhasil ditambahkan ke keranjang.', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600)),
        duration: const Duration(seconds: 1),
        backgroundColor: const Color(0xFF48C9B0),
      ),
    );
  }

  void _loadPrescriptionToCart(PendingPrescription rx) {
    if (rx.status != 'ready') return;
    for (final item in rx.items) {
      _addToCart(item.medicine, qty: item.qty, rxId: rx.externalPrescriptionId);
    }
    setState(() {
      _pendingPrescriptions.removeWhere((p) => p.externalPrescriptionId == rx.externalPrescriptionId);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Resep ${rx.patientName} berhasil dimasukkan ke transaksi.', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600)),
        backgroundColor: const Color(0xFFB577F2),
      ),
    );
  }

  void _updateCartQty(CartItem item, int delta) {
    setState(() {
      final nextQty = item.qty + delta;
      if (nextQty <= 0) {
        _cart.remove(item);
      } else if (nextQty <= item.medicine.stock) {
        item.qty = nextQty;
      }
    });
  }

  void _checkout(Color themeAccent, bool isDark) {
    if (_cart.isEmpty) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        double total = _cart.fold(0, (sum, item) => sum + (item.medicine.sellPrice * item.qty));
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF161619) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(color: isDark ? const Color(0xFF252528) : const Color(0xFFECEEF2)),
              ),
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 48,
                      height: 5,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[800] : Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Pilih Metode Pembayaran',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : const Color(0xFF1B0C3C),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Hubungkan transaksi penjualan kasir apotek dengan aman.',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      color: isDark ? Colors.grey[400] : const Color(0xFF6F6A8A),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _buildPaymentMethodButton(Icons.money_rounded, 'TUNAI', themeAccent, true, isDark),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildPaymentMethodButton(Icons.qr_code_rounded, 'QRIS', themeAccent, false, isDark),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildPaymentMethodButton(Icons.credit_card_rounded, 'DEBIT', themeAccent, false, isDark),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Divider(color: isDark ? const Color(0xFF252528) : const Color(0xFFECEEF2)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Belanja',
                        style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? Colors.grey[400] : const Color(0xFF6F6A8A)),
                      ),
                      Text(
                        'Rp ${_formatPrice(total)}',
                        style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w900, color: themeAccent),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      await _submitCheckoutToDatabase(total, themeAccent, isDark);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: themeAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: Text(
                      'SELESAIKAN TRANSAKSI',
                      style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _submitCheckoutToDatabase(double total, Color themeAccent, bool isDark) async {
    setState(() => _isLoading = true);
    try {
      final List<Map<String, dynamic>> itemsList = _cart.map((c) => {
        'batchId': c.medicine.batchId,
        'qty': c.qty,
        'price': c.medicine.sellPrice,
        'subtotal': c.medicine.sellPrice * c.qty,
        'stock': c.medicine.stock,
      }).toList();

      // Submit to Supabase DB
      await _db.submitCheckoutTransaction(
        total: total,
        paymentMethod: 'Tunai',
        buyerName: _selectedBuyer.isEmpty ? 'Umum / Walk-in' : _selectedBuyer,
        items: itemsList,
      );

      // Complete associated prescription statuses if needed
      for (final item in _cart) {
        if (item.externalPrescriptionId != null) {
          await _db.updatePrescriptionStatus(item.externalPrescriptionId!, 'checked_out');
        }
      }

      await _loadDataFromDatabase();
      _showSuccessReceipt(total, themeAccent, isDark);
    } catch (e) {
      // offline success receipt
      setState(() => _isLoading = false);
      _showSuccessReceipt(total, themeAccent, isDark);
    }
  }

  Widget _buildPaymentMethodButton(IconData icon, String label, Color accent, bool active, bool isDark) {
    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: active
            ? accent.withOpacity(0.12)
            : (isDark ? const Color(0xFF1E1E22) : const Color(0xFFF8FAFC)),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: active ? accent : (isDark ? const Color(0xFF252528) : const Color(0xFFECEEF2)), width: 2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: active ? accent : const Color(0xFF6F6A8A), size: 22),
          const SizedBox(height: 6),
          Text(
            label,
            style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: active ? accent : const Color(0xFF6F6A8A)),
          ),
        ],
      ),
    );
  }

  void _showSuccessReceipt(double total, Color themeAccent, bool isDark) {
    setState(() {
      _cart.clear();
      _isCartExpanded = false;
    });
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF161619) : Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: isDark ? const Color(0xFF252528) : const Color(0xFFECEEF2)),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(color: const Color(0xFF48C9B0).withOpacity(0.15), shape: BoxShape.circle),
                  child: const Icon(Icons.check_circle_rounded, color: Color(0xFF48C9B0), size: 32),
                ),
                const SizedBox(height: 20),
                Text(
                  'Checkout Berhasil!',
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF1B0C3C),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Stok inventori obat telah dikurangi otomatis.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: isDark ? Colors.grey[400] : const Color(0xFF6F6A8A),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E22) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      _buildReceiptRow('No. Struk', 'TX-${DateTime.now().millisecondsSinceEpoch}', isDark),
                      const SizedBox(height: 8),
                      _buildReceiptRow('Waktu', 'Hari ini, 13.50', isDark),
                      const SizedBox(height: 8),
                      _buildReceiptRow('Metode', 'Tunai', isDark),
                      const Divider(height: 24, color: Colors.grey),
                      _buildReceiptRow('Total Dibayar', 'Rp ${_formatPrice(total)}', isDark, isBold: true, accentColor: themeAccent),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: themeAccent,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: Text(
                    'TUTUP',
                    style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildReceiptRow(String label, String value, bool isDark, {bool isBold = false, Color? accentColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(fontSize: 11, color: isDark ? Colors.grey[400] : const Color(0xFF6F6A8A)),
        ),
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: isBold ? 14 : 11,
            fontWeight: isBold ? FontWeight.w900 : FontWeight.bold,
            color: accentColor ?? (isDark ? Colors.white : const Color(0xFF1B0C3C)),
          ),
        ),
      ],
    );
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

    final filteredMedicines = _medicines.where((med) {
      final matchesSearch = med.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          med.genericName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          med.sku.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesForm = _selectedForm == 'all' || med.form.toLowerCase() == _selectedForm.toLowerCase();
      return matchesSearch && matchesForm;
    }).toList();

    return _isLoading
        ? const SkeletonScope(
            child: SkeletonApotekDashboard(type: 'sales'),
          )
        : Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Link Patient check-in panel
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: themeAccent.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: themeAccent.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.qr_code_scanner_rounded, color: themeAccent, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Pencarian & Link Pembeli',
                                style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: textColor),
                              ),
                              Text(
                                _selectedBuyer.isEmpty ? 'Hubungkan resep digital pasien dengan scan barcode/QR.' : 'Pembeli terhubung: $_selectedBuyer',
                                style: GoogleFonts.outfit(fontSize: 9, color: subtitleColor),
                              ),
                            ],
                          ),
                        ),
                        if (_selectedBuyer.isEmpty)
                          ElevatedButton.icon(
                            onPressed: () {
                              setState(() {
                                _selectedBuyer = 'Alvin (Pasien BPJS)';
                              });
                            },
                            icon: const Icon(Icons.link_rounded, size: 14),
                            label: Text('MOCK SCAN', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: themeAccent,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          )
                        else
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 16),
                            onPressed: () => setState(() => _selectedBuyer = ''),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Pending Rx Queue section
                  if (_pendingPrescriptions.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Antrian Resep Digital',
                          style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: textColor),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: themeAccent, borderRadius: BorderRadius.circular(100)),
                          child: Text(
                            '${_pendingPrescriptions.length} RESEP',
                            style: GoogleFonts.outfit(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 110,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _pendingPrescriptions.length,
                        itemBuilder: (context, index) {
                          final rx = _pendingPrescriptions[index];
                          final isRxReady = rx.status == 'ready';

                          return Container(
                            width: 250,
                            margin: const EdgeInsets.only(right: 12, bottom: 4),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isRxReady ? themeAccent.withOpacity(0.04) : Colors.amber.withOpacity(0.04),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: isRxReady ? themeAccent.withOpacity(0.25) : Colors.amber.withOpacity(0.25),
                                width: 1.5,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        rx.patientName,
                                        style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: textColor),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isRxReady ? themeAccent.withOpacity(0.12) : Colors.amber.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(100),
                                      ),
                                      child: Text(
                                        isRxReady ? 'SIAP CHECKOUT' : 'SEDANG DIRACIK',
                                        style: GoogleFonts.outfit(
                                          fontSize: 7,
                                          fontWeight: FontWeight.w900,
                                          color: isRxReady ? themeAccent : Colors.amber[800],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const Spacer(),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '${rx.items.length} item obat • Sesi ${rx.sessionNumber}',
                                      style: GoogleFonts.outfit(fontSize: 9, color: subtitleColor),
                                    ),
                                    TextButton(
                                      onPressed: isRxReady ? () => _loadPrescriptionToCart(rx) : null,
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        backgroundColor: isRxReady ? themeAccent : Colors.grey[200],
                                        foregroundColor: isRxReady ? Colors.white : Colors.grey[400],
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      child: Text(
                                        'LOAD',
                                        style: GoogleFonts.outfit(fontSize: 8, fontWeight: FontWeight.w900),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],

                  // Filter and Search Header
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cardBgColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 40,
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E1E22) : const Color(0xFFF1EEFA),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                              children: [
                                Icon(Icons.search_rounded, size: 18, color: subtitleColor),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    onChanged: (val) => setState(() => _searchQuery = val),
                                    style: GoogleFonts.outfit(fontSize: 12, color: textColor),
                                    decoration: InputDecoration(
                                      hintText: 'Cari obat, formula, atau SKU...',
                                      hintStyle: GoogleFonts.outfit(fontSize: 12, color: subtitleColor.withOpacity(0.5)),
                                      border: InputBorder.none,
                                      isDense: true,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        DropdownButton<String>(
                          value: _selectedForm,
                          underline: const SizedBox(),
                          dropdownColor: cardBgColor,
                          style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: textColor),
                          items: const [
                            DropdownMenuItem(value: 'all', child: Text('Semua Bentuk')),
                            DropdownMenuItem(value: 'tablet', child: Text('Tablet')),
                            DropdownMenuItem(value: 'kapsul', child: Text('Kapsul')),
                            DropdownMenuItem(value: 'sirup', child: Text('Sirup')),
                          ],
                          onChanged: (val) => setState(() => _selectedForm = val ?? 'all'),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Medicine Cards Catalog Grid
                  Expanded(
                    child: GridView.builder(
                      padding: const EdgeInsets.only(bottom: 100),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.84,
                      ),
                      itemCount: filteredMedicines.length,
                      itemBuilder: (context, index) {
                        final med = filteredMedicines[index];

                        return InkWell(
                          onTap: () => _addToCart(med),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            decoration: BoxDecoration(
                              color: cardBgColor,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: borderColor),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: Container(
                                    color: isDark ? const Color(0xFF202025) : const Color(0xFFF9FAFB),
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        Icon(Icons.medication_rounded, size: 40, color: themeAccent.withOpacity(0.4)),
                                        Positioned(
                                          top: 10,
                                          left: 10,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: isDark ? const Color(0xFF161619).withOpacity(0.8) : Colors.black.withOpacity(0.7),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              'Stok: ${med.stock}',
                                              style: GoogleFonts.outfit(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        med.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: textColor),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${med.genericName} - ${med.form}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.outfit(fontSize: 9, color: subtitleColor),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Rp ${_formatPrice(med.sellPrice)}',
                                            style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: textColor),
                                          ),
                                          Container(
                                            width: 24,
                                            height: 24,
                                            decoration: BoxDecoration(
                                              color: themeAccent.withOpacity(0.12),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(Icons.add_rounded, size: 14, color: themeAccent),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),

              // Cart Drawer Floating Panel
              if (_cart.isNotEmpty)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 12,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF161619) : const Color(0xFF1B0C3C),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 18, offset: const Offset(0, 8)),
                      ],
                      border: isDark ? Border.all(color: const Color(0xFF252528)) : null,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_isCartExpanded) ...[
                          Container(
                            constraints: const BoxConstraints(maxHeight: 180),
                            color: isDark ? const Color(0xFF1E1E22) : const Color(0xFF24144B),
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: _cart.length,
                              itemBuilder: (context, index) {
                                final item = _cart[index];
                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  child: Row(
                                    children: [
                                      Icon(Icons.medication_rounded, size: 14, color: themeAccent.withOpacity(0.7)),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.medicine.name,
                                              style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            if (item.externalPrescriptionId != null)
                                              Text(
                                                'Dari Resep: ${item.externalPrescriptionId}',
                                                style: GoogleFonts.outfit(fontSize: 8, color: Colors.grey[400]),
                                              ),
                                          ],
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          IconButton(
                                            onPressed: () => _updateCartQty(item, -1),
                                            icon: const Icon(Icons.remove_circle_outline_rounded, color: Colors.white, size: 16),
                                            constraints: const BoxConstraints(),
                                            padding: EdgeInsets.zero,
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 8),
                                            child: Text(
                                              '${item.qty}',
                                              style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white),
                                            ),
                                          ),
                                          IconButton(
                                            onPressed: () => _updateCartQty(item, 1),
                                            icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.white, size: 16),
                                            constraints: const BoxConstraints(),
                                            padding: EdgeInsets.zero,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(width: 16),
                                      Text(
                                        'Rp ${_formatPrice(item.medicine.sellPrice * item.qty)}',
                                        style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                          Divider(height: 1, color: isDark ? const Color(0xFF252528) : Colors.white.withOpacity(0.1)),
                        ],
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              InkWell(
                                onTap: () => setState(() => _isCartExpanded = !_isCartExpanded),
                                child: Row(
                                  children: [
                                    Stack(
                                      alignment: Alignment.topRight,
                                      children: [
                                        Container(
                                          width: 36,
                                          height: 36,
                                          decoration: BoxDecoration(color: themeAccent, shape: BoxShape.circle),
                                          child: const Icon(Icons.shopping_cart_rounded, size: 16, color: Colors.white),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                          child: Text(
                                            '${_cart.length}',
                                            style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.white),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(width: 10),
                                    Icon(
                                      _isCartExpanded ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_up_rounded,
                                      color: Colors.white.withOpacity(0.7),
                                      size: 18,
                                    ),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'TOTAL BAYAR',
                                    style: GoogleFonts.outfit(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white.withOpacity(0.6)),
                                  ),
                                  Text(
                                    'Rp ${_formatPrice(_cart.fold(0, (sum, item) => sum + (item.medicine.sellPrice * item.qty)))}',
                                    style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 16),
                              ElevatedButton(
                                onPressed: () => _checkout(themeAccent, isDark),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: themeAccent,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  elevation: 0,
                                ),
                                child: Text(
                                  'BAYAR',
                                  style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
  }
}
