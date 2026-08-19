import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mapotech/features/landing/landing_page_data.dart';
import 'package:mapotech/shared/supabase_service.dart';
import 'package:mapotech/features/apotek/dashboard/backend/inventory_provider.dart';
import 'package:mapotech/features/apotek/dashboard/backend/prescription_provider.dart';

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

class ApotekPenjualan extends ConsumerStatefulWidget {
  const ApotekPenjualan({super.key});

  @override
  ConsumerState<ApotekPenjualan> createState() => _ApotekPenjualanState();
}

class _ApotekPenjualanState extends ConsumerState<ApotekPenjualan> {
  final SupabaseService _db = SupabaseService();
  bool _isLoading = false;

  // Shopping Cart & POS States
  final List<CartItem> _cart = [];
  String _searchQuery = '';
  String _selectedForm = 'all';
  String _selectedBuyer = '';
  Map<String, dynamic>? _connectedPatient;
  bool _isSearchOpen = false;
  final TextEditingController _patientSearchCtrl = TextEditingController();
  List<Map<String, dynamic>> _patientSearchResults = [];
  bool _isSearchingPatients = false;
  late final String _posSessionId;
  BuildContext? _activeQrDialogCtx;
  RealtimeChannel? _posChannel;
  bool _isGridView = true;
  bool _hasLoadedActiveRx = false;

  final List<Map<String, dynamic>> _registeredPatients = [
    {
      'id': 'pat-001',
      'name': 'Ahmad Fauzi',
      'nik': '3509012304950002',
      'bpjs_number': '0001928472910',
      'gender': 'Laki-laki',
      'phone': '0856-7890-1234',
      'address': 'Jl. Mastrip Timur No. 12, Jember',
      'has_prescription': true,
    },
    {
      'id': 'pat-002',
      'name': 'Budi Santoso',
      'nik': '3509011405880001',
      'bpjs_number': '0001827364521',
      'gender': 'Laki-laki',
      'phone': '0812-3456-7890',
      'address': 'Jl. Kalimantan No. 45, Jember',
      'has_prescription': true,
    },
    {
      'id': 'pat-003',
      'name': 'Siti Aminah',
      'nik': '3509015509920003',
      'bpjs_number': '0002019283746',
      'gender': 'Perempuan',
      'phone': '0813-9876-5432',
      'address': 'Jl. Jawa No. 8, Jember',
      'has_prescription': false,
    },
    {
      'id': 'pat-004',
      'name': 'Dewi Lestari',
      'nik': '3509016102900004',
      'bpjs_number': '0002138475920',
      'gender': 'Perempuan',
      'phone': '0878-1234-5678',
      'address': 'Jl. Riau No. 19, Jember',
      'has_prescription': false,
    },
    {
      'id': 'pat-005',
      'name': 'Hendra Wijaya',
      'nik': '3509010811850005',
      'bpjs_number': '0001748291038',
      'gender': 'Laki-laki',
      'phone': '0821-4567-8901',
      'address': 'Jl. Gajah Mada No. 102, Jember',
      'has_prescription': false,
    },
    {
      'id': 'pat-006',
      'name': 'Rina Kartika',
      'nik': '3509014703970006',
      'bpjs_number': '0002248591024',
      'gender': 'Perempuan',
      'phone': '0896-2345-6789',
      'address': 'Jl. Trunojoyo No. 33, Jember',
      'has_prescription': false,
    },
  ];

  @override
  void initState() {
    super.initState();
    _posSessionId = 'POS-${DateTime.now().millisecondsSinceEpoch.toRadixString(36).toUpperCase()}';
    _patientSearchResults = List.from(_registeredPatients);
    _initRealtimePosChannel();

    // Preload inventory if empty
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndLoadActiveRx();
    });
  }

  void _initRealtimePosChannel() {
    try {
      _posChannel = Supabase.instance.client.channel('pos_apotek_sync');
      _posChannel?.onBroadcast(
        event: 'patient_connected',
        callback: (payload) {
          debugPrint('Realtime POS broadcast received: $payload');
          final patient = Map<String, dynamic>.from(payload);
          if (mounted) {
            final inventoryList = ref.read(apotekInventoryProvider);
            final prescriptionList = ref.read(apotekPrescriptionProvider);
            final allMeds = _buildPosMedicines(inventoryList);
            final pendingPrescriptions = prescriptionList.where((p) => p.status == 'ready' || p.status == 'compounding' || p.status == 'pending').toList();

            _connectPatient(patient, pendingPrescriptions, allMeds);

            if (_activeQrDialogCtx != null) {
              try {
                Navigator.of(_activeQrDialogCtx!).pop();
              } catch (_) {}
              _activeQrDialogCtx = null;
            }
          }
        },
      ).onBroadcast(
        event: 'patient_disconnected',
        callback: (payload) {
          if (mounted) {
            _disconnectPatient();
          }
        },
      );
      _posChannel?.subscribe();
    } catch (e) {
      debugPrint('Realtime channel init error: $e');
    }
  }

  @override
  void dispose() {
    _patientSearchCtrl.dispose();
    try {
      _posChannel?.unsubscribe();
    } catch (_) {}
    super.dispose();
  }

  Future<void> _performPatientSearch(String query) async {
    final clean = query.trim().toLowerCase();
    setState(() => _isSearchingPatients = true);

    try {
      final List<Map<String, dynamic>> results = _registeredPatients.where((p) {
        if (clean.isEmpty) return true;
        final name = (p['name'] ?? '').toString().toLowerCase();
        final nik = (p['nik'] ?? '').toString().toLowerCase();
        final bpjs = (p['bpjs_number'] ?? '').toString().toLowerCase();
        final phone = (p['phone'] ?? '').toString().toLowerCase();
        return name.contains(clean) || nik.contains(clean) || bpjs.contains(clean) || phone.contains(clean);
      }).toList();

      // Query database patients
      try {
        final dbPatients = await _db.fetchAllPatients();
        for (final p in dbPatients) {
          final pName = p['name'] ?? '';
          final pNik = p['nik'] ?? '';
          if (clean.isEmpty || pName.toLowerCase().contains(clean) || pNik.toLowerCase().contains(clean)) {
            if (!results.any((r) => r['nik'] == pNik || r['name'] == pName)) {
              results.add({
                'id': p['id'] ?? 'db-${results.length}',
                'name': pName,
                'nik': pNik.isNotEmpty ? pNik : '350901${results.length}0000',
                'bpjs_number': '000199${pNik.length >= 6 ? pNik.substring(0, 6) : "827364"}',
                'gender': p['gender'] ?? 'Laki-laki',
                'phone': p['phone_number'] ?? p['phone'] ?? '-',
                'address': p['address'] ?? '-',
                'has_prescription': false,
              });
            }
          }
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _patientSearchResults = results;
          _isSearchingPatients = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isSearchingPatients = false);
    }
  }

  void _connectPatient(
    Map<String, dynamic> patient,
    List<ApotekPrescriptionOrder> pendingPrescriptions,
    List<PosMedicine> availableMeds,
  ) {
    ref.read(connectedPosPatientProvider.notifier).state = patient;

    setState(() {
      _connectedPatient = patient;
      _selectedBuyer = patient['name'] ?? 'Pasien Terhubung';
      _isSearchOpen = false;
    });

    final patientName = (patient['name'] ?? '').toString().toLowerCase();
    final matchingRx = pendingPrescriptions.where((rx) =>
      rx.patientName.toLowerCase().contains(patientName) ||
      patientName.contains(rx.patientName.toLowerCase())
    ).toList();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.verified_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Pasien ${patient['name']} berhasil terhubung ke POS!',
                style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1B4F42),
        duration: const Duration(seconds: 3),
        action: matchingRx.isNotEmpty
            ? SnackBarAction(
                label: 'MUAT RESEP',
                textColor: const Color(0xFF48C9B0),
                onPressed: () {
                  _loadPrescriptionToCart(matchingRx.first, availableMeds);
                },
              )
            : null,
      ),
    );
  }

  void _disconnectPatient() {
    ref.read(connectedPosPatientProvider.notifier).state = null;

    setState(() {
      _connectedPatient = null;
      _selectedBuyer = '';
      _isSearchOpen = false;
      _patientSearchCtrl.clear();
      _patientSearchResults = List.from(_registeredPatients);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Koneksi pasien diputuskan. Mode pembeli umum (walk-in).', style: GoogleFonts.outfit(fontSize: 12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _checkAndLoadActiveRx() {
    final activeRx = ref.read(activePosPrescriptionProvider);
    if (activeRx != null && !_hasLoadedActiveRx) {
      _hasLoadedActiveRx = true;
      final inventory = ref.read(apotekInventoryProvider);
      final meds = _buildPosMedicines(inventory);
      _loadPrescriptionToCart(activeRx, meds);
      ref.read(activePosPrescriptionProvider.notifier).state = null;
    }
  }

  List<PosMedicine> _buildPosMedicines(List<ApotekInventoryItem> items) {
    final List<PosMedicine> loadedMedicines = [];
    for (final item in items) {
      if (item.batches.isEmpty) {
        loadedMedicines.add(PosMedicine(
          id: item.id,
          batchId: item.id,
          name: item.name,
          genericName: item.genericName,
          form: item.form,
          sku: item.sku,
          sellPrice: item.sellPrice,
          stock: item.stock,
          sellUnit: item.unit,
          description: item.description ?? '',
        ));
      } else {
        for (final b in item.batches) {
          loadedMedicines.add(PosMedicine(
            id: item.id,
            batchId: b.id,
            name: item.name,
            genericName: item.genericName,
            form: item.form,
            sku: b.batchNo,
            sellPrice: b.sellPrice,
            stock: b.stock,
            sellUnit: item.unit,
            description: item.description ?? '',
          ));
        }
      }
    }
    return loadedMedicines;
  }

  void _addToCart(PosMedicine medicine, {int qty = 1, String? rxId}) {
    if (medicine.stock <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Stok ${medicine.name} habis!', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold)),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

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
        content: Text('${medicine.name} ditambahkan ke keranjang.', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600)),
        duration: const Duration(milliseconds: 900),
        backgroundColor: const Color(0xFF27AE60),
      ),
    );
  }

  void _loadPrescriptionToCart(ApotekPrescriptionOrder rx, List<PosMedicine> availableMeds) {
    if (rx.status != 'ready' && rx.status != 'pending_checkout') {
      // If it's loaded directly from Pesanan, proceed
    }

    for (final item in rx.items) {
      final matchedMed = availableMeds.firstWhere(
        (m) => m.name.toLowerCase() == item.name.toLowerCase() ||
               m.name.toLowerCase().contains(item.name.toLowerCase()) ||
               item.name.toLowerCase().contains(m.name.toLowerCase()),
        orElse: () => availableMeds.firstWhere(
          (m) => m.stock > 0,
          orElse: () => availableMeds.isNotEmpty
              ? availableMeds.first
              : PosMedicine(
                  id: 'rx-med-${rx.id}',
                  batchId: 'rx-batch-${rx.id}',
                  name: item.name,
                  genericName: item.name,
                  form: 'Tablet',
                  sku: 'SKU-RX',
                  sellPrice: item.price,
                  stock: item.qty,
                  sellUnit: item.unit,
                  description: item.dosage,
                ),
        ),
      );

      _addToCart(matchedMed, qty: item.qty, rxId: rx.id);
    }

    setState(() {
      _selectedBuyer = rx.patientName;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Resep ${rx.patientName} (${rx.items.length} item) berhasil dimuat ke kasir!', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600)),
        backgroundColor: const Color(0xFF27AE60),
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

  void _showCartDetailsModal(Color themeAccent, bool isDark, Color textColor, Color subtitleColor, Color cardBgColor, Color borderColor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            double total = _cart.fold(0, (sum, item) => sum + (item.medicine.sellPrice * item.qty));
            int totalItems = _cart.fold(0, (sum, item) => sum + item.qty);

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.8,
              ),
              decoration: BoxDecoration(
                color: cardBgColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(color: borderColor),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 30, offset: const Offset(0, -8)),
                ],
              ),
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[800] : Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Modal Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: themeAccent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: Icon(Icons.shopping_bag_rounded, color: themeAccent, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Keranjang Belanja Kasir', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900, color: textColor)),
                              Text('$totalItems item dalam keranjang', style: GoogleFonts.outfit(fontSize: 11, color: subtitleColor)),
                            ],
                          ),
                        ],
                      ),
                      if (_cart.isNotEmpty)
                        TextButton.icon(
                          onPressed: () {
                            setState(() => _cart.clear());
                            setModalState(() {});
                            Navigator.pop(ctx);
                          },
                          icon: const Icon(Icons.delete_sweep_rounded, size: 16, color: Colors.redAccent),
                          label: Text('Kosongkan', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                        ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  Divider(color: borderColor),
                  const SizedBox(height: 10),

                  // Cart Items List
                  if (_cart.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Column(
                        children: [
                          Icon(Icons.remove_shopping_cart_rounded, size: 48, color: subtitleColor.withValues(alpha: 0.4)),
                          const SizedBox(height: 12),
                          Text('Keranjang Masih Kosong', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w900, color: textColor)),
                          const SizedBox(height: 4),
                          Text('Klik pada kartu obat untuk menambahkan ke keranjang.', style: GoogleFonts.outfit(fontSize: 11, color: subtitleColor)),
                        ],
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: _cart.length,
                        separatorBuilder: (ctx, i) => Divider(color: borderColor.withValues(alpha: 0.5), height: 16),
                        itemBuilder: (context, index) {
                          final item = _cart[index];
                          final isOverStock = item.qty > item.medicine.stock;
                          final isAtMaxStock = item.qty >= item.medicine.stock;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: themeAccent.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    alignment: Alignment.center,
                                    child: Icon(Icons.medication_rounded, size: 18, color: themeAccent),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(item.medicine.name, style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.w900, color: textColor)),
                                        Row(
                                          children: [
                                            Text('Rp ${_formatPrice(item.medicine.sellPrice)} / ${item.medicine.sellUnit}', style: GoogleFonts.outfit(fontSize: 10, color: subtitleColor)),
                                            const SizedBox(width: 6),
                                            Text('• Stok: ${item.medicine.stock}', style: GoogleFonts.outfit(fontSize: 9.5, fontWeight: FontWeight.bold, color: isAtMaxStock ? Colors.orangeAccent : subtitleColor)),
                                            if (item.externalPrescriptionId != null) ...[
                                              const SizedBox(width: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(4)),
                                                child: Text('Resep Dokter', style: GoogleFonts.outfit(fontSize: 7.5, fontWeight: FontWeight.bold, color: Colors.blue)),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Keyboard editable quantity controls
                                  Row(
                                    children: [
                                      IconButton(
                                        onPressed: () {
                                          setState(() => _updateCartQty(item, -1));
                                          setModalState(() {});
                                        },
                                        icon: const Icon(Icons.remove_circle_outline_rounded, size: 20),
                                        color: item.qty == 1 ? Colors.redAccent : subtitleColor,
                                        splashRadius: 16,
                                      ),
                                      Container(
                                        width: 52,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: isDark ? const Color(0xFF1E1E22) : const Color(0xFFF6F8FB),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: isOverStock ? Colors.redAccent : (isAtMaxStock ? Colors.orangeAccent : borderColor),
                                            width: (isOverStock || isAtMaxStock) ? 1.5 : 1.0,
                                          ),
                                        ),
                                        alignment: Alignment.center,
                                        child: TextFormField(
                                          key: ValueKey('cart_qty_${item.id}_${item.qty}'),
                                          initialValue: '${item.qty}',
                                          textAlign: TextAlign.center,
                                          keyboardType: TextInputType.number,
                                          style: GoogleFonts.outfit(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w900,
                                            color: isOverStock ? Colors.redAccent : textColor,
                                          ),
                                          decoration: const InputDecoration(
                                            border: InputBorder.none,
                                            isDense: true,
                                            contentPadding: EdgeInsets.zero,
                                          ),
                                          onChanged: (val) {
                                            final parsed = int.tryParse(val.trim());
                                            if (parsed != null) {
                                              if (parsed > item.medicine.stock) {
                                                // Exceeds stock limit
                                                setState(() {
                                                  item.qty = item.medicine.stock;
                                                });
                                                setModalState(() {});
                                              } else if (parsed > 0) {
                                                setState(() {
                                                  item.qty = parsed;
                                                });
                                                setModalState(() {});
                                              }
                                            }
                                          },
                                          onFieldSubmitted: (val) {
                                            final parsed = int.tryParse(val.trim());
                                            if (parsed == null || parsed <= 0) {
                                              setState(() => item.qty = 1);
                                              setModalState(() {});
                                            } else if (parsed > item.medicine.stock) {
                                              setState(() => item.qty = item.medicine.stock);
                                              setModalState(() {});
                                            }
                                          },
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: item.qty < item.medicine.stock
                                            ? () {
                                                setState(() => _updateCartQty(item, 1));
                                                setModalState(() {});
                                              }
                                            : null,
                                        icon: Icon(Icons.add_circle_outline_rounded, size: 20, color: item.qty < item.medicine.stock ? themeAccent : Colors.grey[400]),
                                        splashRadius: 16,
                                      ),
                                    ],
                                  ),

                                  const SizedBox(width: 10),
                                  Text('Rp ${_formatPrice(item.medicine.sellPrice * item.qty)}', style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.w900, color: textColor)),
                                ],
                              ),
                              if (isAtMaxStock)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4, left: 50),
                                  child: Text(
                                    '⚠️ Jumlah mencapai batas maksimal stok tersedia (${item.medicine.stock} ${item.medicine.sellUnit})',
                                    style: GoogleFonts.outfit(fontSize: 9.5, fontWeight: FontWeight.bold, color: Colors.orangeAccent[700]),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),

                  const SizedBox(height: 16),
                  Divider(color: borderColor),
                  const SizedBox(height: 12),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('TOTAL TAGIHAN', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: subtitleColor)),
                      Text('Rp ${_formatPrice(total)}', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w900, color: themeAccent)),
                    ],
                  ),

                  const SizedBox(height: 18),

                  if (_cart.isNotEmpty)
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _openCheckoutModal(themeAccent, isDark, textColor, subtitleColor, cardBgColor, borderColor);
                      },
                      icon: const Icon(Icons.payment_rounded, size: 18, color: Colors.white),
                      label: Text('LANJUT KE PEMBAYARAN', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.5)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: themeAccent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
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

  void _openCheckoutModal(Color themeAccent, bool isDark, Color textColor, Color subtitleColor, Color cardBgColor, Color borderColor) {
    if (_cart.isEmpty) return;

    double subtotal = _cart.fold(0, (sum, item) => sum + (item.medicine.sellPrice * item.qty));
    String paymentMethod = 'cash'; // 'cash', 'qris', 'card'
    final cashCtrl = TextEditingController(text: subtotal.toStringAsFixed(0));
    double cashGiven = subtotal;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            double change = cashGiven - subtotal;
            if (change < 0) change = 0;

            return Container(
              decoration: BoxDecoration(
                color: cardBgColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(color: borderColor),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 30, offset: const Offset(0, -8)),
                ],
              ),
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[800] : Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Checkout / Pembayaran POS', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900, color: textColor)),
                          Text(
                            _selectedBuyer.isEmpty ? 'Pembeli: Umum / Walk-in' : 'Pembeli: $_selectedBuyer',
                            style: GoogleFonts.outfit(fontSize: 11, color: subtitleColor),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: Icon(Icons.close_rounded, color: subtitleColor),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Payment Method Selector Tabs
                  Row(
                    children: [
                      Expanded(
                        child: _buildPayOption(
                          label: 'Tunai / Cash',
                          icon: Icons.payments_rounded,
                          selected: paymentMethod == 'cash',
                          onTap: () => setModalState(() => paymentMethod = 'cash'),
                          accent: themeAccent,
                          isDark: isDark,
                          textColor: textColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildPayOption(
                          label: 'QRIS',
                          icon: Icons.qr_code_2_rounded,
                          selected: paymentMethod == 'qris',
                          onTap: () => setModalState(() => paymentMethod = 'qris'),
                          accent: themeAccent,
                          isDark: isDark,
                          textColor: textColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildPayOption(
                          label: 'Debit / EDC',
                          icon: Icons.credit_card_rounded,
                          selected: paymentMethod == 'card',
                          onTap: () => setModalState(() => paymentMethod = 'card'),
                          accent: themeAccent,
                          isDark: isDark,
                          textColor: textColor,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // Payment Method Body Details
                  if (paymentMethod == 'cash') ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E1E22) : const Color(0xFFF8FAFD),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Uang Tunai Diterima:', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: textColor)),
                          const SizedBox(height: 6),
                          Container(
                            height: 46,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF121214) : Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: themeAccent, width: 1.5),
                            ),
                            child: TextField(
                              controller: cashCtrl,
                              keyboardType: TextInputType.number,
                              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900, color: textColor),
                              decoration: const InputDecoration(border: InputBorder.none, prefixText: 'Rp '),
                              onChanged: (val) {
                                final p = double.tryParse(val) ?? 0;
                                setModalState(() => cashGiven = p);
                              },
                            ),
                          ),
                          const SizedBox(height: 10),
                          // Quick cash shortcut chips
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _buildCashChip('Uang Pas', () {
                                  cashCtrl.text = subtotal.toStringAsFixed(0);
                                  setModalState(() => cashGiven = subtotal);
                                }, themeAccent),
                                const SizedBox(width: 6),
                                _buildCashChip('Rp 20.000', () {
                                  cashCtrl.text = '20000';
                                  setModalState(() => cashGiven = 20000);
                                }, themeAccent),
                                const SizedBox(width: 6),
                                _buildCashChip('Rp 50.000', () {
                                  cashCtrl.text = '50000';
                                  setModalState(() => cashGiven = 50000);
                                }, themeAccent),
                                const SizedBox(width: 6),
                                _buildCashChip('Rp 100.000', () {
                                  cashCtrl.text = '100000';
                                  setModalState(() => cashGiven = 100000);
                                }, themeAccent),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Kembalian:', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: subtitleColor)),
                        Text('Rp ${_formatPrice(change)}', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900, color: const Color(0xFF27AE60))),
                      ],
                    ),
                  ] else if (paymentMethod == 'qris') ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E1E22) : const Color(0xFFF8FAFD),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 130,
                            height: 130,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: borderColor),
                            ),
                            alignment: Alignment.center,
                            child: Icon(Icons.qr_code_2_rounded, size: 100, color: Colors.grey[800]),
                          ),
                          const SizedBox(height: 10),
                          Text('NMID: ID102003928192 - MAPOTEK FARMASI', style: GoogleFonts.outfit(fontSize: 9.5, fontWeight: FontWeight.bold, color: subtitleColor)),
                          Text('Scan QRIS di atas dengan aplikasi BCA, Mandiri, GoPay, OVO, ShopeePay', style: GoogleFonts.outfit(fontSize: 9, color: subtitleColor)),
                        ],
                      ),
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E1E22) : const Color(0xFFF8FAFD),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.credit_card_rounded, size: 28, color: Colors.blueAccent),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Mesin EDC Siap', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: textColor)),
                                Text('Gesek atau masukkan kartu Debit/Kredit pada mesin EDC kasir.', style: GoogleFonts.outfit(fontSize: 10, color: subtitleColor)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 18),
                  Divider(color: borderColor),
                  const SizedBox(height: 12),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total Tagihan', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: subtitleColor)),
                      Text('Rp ${_formatPrice(subtotal)}', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w900, color: themeAccent)),
                    ],
                  ),

                  const SizedBox(height: 20),

                  ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await _submitCheckout(subtotal, paymentMethod, themeAccent, isDark, textColor, subtitleColor, cardBgColor, borderColor);
                    },
                    icon: const Icon(Icons.check_circle_rounded, size: 18, color: Colors.white),
                    label: Text(
                      'SELESAIKAN & CETAK STRUK',
                      style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 0.5, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: themeAccent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
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

  Widget _buildPayOption({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
    required Color accent,
    required bool isDark,
    required Color textColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: 0.12)
              : (isDark ? const Color(0xFF1E1E22) : const Color(0xFFF8FAFD)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? accent : Colors.transparent, width: 1.5),
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? accent : Colors.grey[500], size: 20),
            const SizedBox(height: 4),
            Text(label, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: selected ? accent : textColor)),
          ],
        ),
      ),
    );
  }

  Widget _buildCashChip(String label, VoidCallback onTap, Color accent) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: accent.withValues(alpha: 0.25)),
        ),
        child: Text(label, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: accent)),
      ),
    );
  }

  Future<void> _submitCheckout(
    double total,
    String paymentMethod,
    Color themeAccent,
    bool isDark,
    Color textColor,
    Color subtitleColor,
    Color cardBgColor,
    Color borderColor,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isLoading = true);
    final cartCopy = List<CartItem>.from(_cart);
    final buyer = _selectedBuyer.isEmpty ? 'Umum / Walk-in' : _selectedBuyer;
    final userId = ref.read(landingPageProvider).loggedInUser?['id']?.toString();

    String receiptNo = 'STR-${DateTime.now().year}${DateTime.now().month.toString().padLeft(2, '0')}${DateTime.now().day.toString().padLeft(2, '0')}-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

    try {
      final List<Map<String, dynamic>> itemsList = cartCopy.map((c) => {
        'medicineId': c.medicine.id,
        'batchId': c.medicine.batchId,
        'qty': c.qty,
        'price': c.medicine.sellPrice,
        'subtotal': c.medicine.sellPrice * c.qty,
        'stock': c.medicine.stock,
      }).toList();

      final res = await _db.submitCheckoutTransaction(
        total: total,
        paymentMethod: paymentMethod == 'cash' ? 'Tunai' : (paymentMethod == 'qris' ? 'QRIS' : 'Debit/EDC'),
        buyerName: buyer,
        items: itemsList,
        idUser: userId,
      );

      if (res['receipt_number'] != null) {
        receiptNo = res['receipt_number'];
      }

      // Automatically deduct from unified inventory provider (instant sync to Inventory tab)
      await ref.read(apotekInventoryProvider.notifier).deductStockAfterSale(itemsList);

      for (final item in cartCopy) {
        if (item.externalPrescriptionId != null) {
          await ref.read(apotekPrescriptionProvider.notifier).markCompleted(item.externalPrescriptionId!);
          await _db.updatePrescriptionStatus(item.externalPrescriptionId!, 'checked_out');
        }
      }

      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Transaksi POS $receiptNo berhasil! Stok di Inventori otomatis terpotong & sinkron.'),
            backgroundColor: const Color(0xFF27AE60),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error during checkout: $e');
    } finally {
      setState(() => _isLoading = false);
    }

    setState(() {
      _cart.clear();
      _selectedBuyer = '';
    });

    if (!mounted) return;
    _showReceiptDialog(cartCopy, total, paymentMethod, buyer, receiptNo, themeAccent, isDark, textColor, subtitleColor, cardBgColor, borderColor);
  }

  void _showReceiptDialog(
    List<CartItem> items,
    double total,
    String paymentMethod,
    String buyer,
    String receiptNo,
    Color themeAccent,
    bool isDark,
    Color textColor,
    Color subtitleColor,
    Color cardBgColor,
    Color borderColor,
  ) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Container(
            width: 440,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cardBgColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: borderColor),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 25, offset: const Offset(0, 8)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Thermal Receipt Header
                Container(
                  width: 50,
                  height: 50,
                  decoration: const BoxDecoration(color: Color(0xFF27AE60), shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: const Icon(Icons.check_rounded, color: Colors.white, size: 30),
                ),
                const SizedBox(height: 12),
                Text('TRANSAKSI BERHASIL', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900, color: const Color(0xFF27AE60), letterSpacing: 0.5)),
                Text('APOTEK MAPOTECH FARMA', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: textColor)),
                Text('SIPA: 446/182/DINKES/2024 • Jl. Kesehatan No. 12', style: GoogleFonts.outfit(fontSize: 9.5, color: subtitleColor)),
                const SizedBox(height: 14),
                Divider(color: borderColor, thickness: 1),
                const SizedBox(height: 8),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('No. Struk: $receiptNo', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: textColor)),
                    Text('Hari ini, ${TimeOfDay.now().format(context)}', style: GoogleFonts.outfit(fontSize: 10, color: subtitleColor)),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Pelanggan: $buyer', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: textColor)),
                    Text('Kasir: Apoteker', style: GoogleFonts.outfit(fontSize: 10, color: subtitleColor)),
                  ],
                ),
                const SizedBox(height: 12),
                Divider(color: borderColor, thickness: 1),
                const SizedBox(height: 8),

                // Items list
                ...items.map((it) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text('${it.qty}x ${it.medicine.name}', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: textColor)),
                        ),
                        Text('Rp ${_formatPrice(it.medicine.sellPrice * it.qty)}', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: textColor)),
                      ],
                    ),
                  );
                }),

                const SizedBox(height: 12),
                Divider(color: borderColor, thickness: 1),
                const SizedBox(height: 8),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('TOTAL BAYAR', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w900, color: textColor)),
                    Text('Rp ${_formatPrice(total)}', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w900, color: themeAccent)),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Metode Pembayaran', style: GoogleFonts.outfit(fontSize: 10, color: subtitleColor)),
                    Text(paymentMethod.toUpperCase(), style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: textColor)),
                  ],
                ),

                const SizedBox(height: 20),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Mencetak struk ke printer thermal...'), duration: Duration(seconds: 1)),
                          );
                        },
                        icon: const Icon(Icons.print_rounded, size: 16),
                        label: Text('CETAK STRUK', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: BorderSide(color: borderColor),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: themeAccent,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: Text('SELESAI', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white)),
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

  void _showPosQrModal({
    required BuildContext context,
    required Color themeAccent,
    required bool isDark,
    required Color textColor,
    required Color subtitleColor,
    required Color cardBgColor,
    required Color borderColor,
    required List<ApotekPrescriptionOrder> pendingPrescriptions,
    required List<PosMedicine> allMeds,
  }) {
    final user = ref.read(landingPageProvider).loggedInUser;
    final pharmacyId = user?['id'] ?? 'apotek-01';
    final pharmacyName = user?['name'] ?? 'Apotek MAPOTECH';

    final qrPayload =
        'https://mapotek.relvastudio.com/pos-apotek/$pharmacyId?pos_session=$_posSessionId&pharmacy_name=${Uri.encodeComponent(pharmacyName)}&role=apotek';

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (dCtx) {
        _activeQrDialogCtx = dCtx;
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 480),
            decoration: BoxDecoration(
              color: cardBgColor,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Modal Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: themeAccent.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.qr_code_scanner_rounded,
                            color: themeAccent,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'QR Code Kasir POS',
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: textColor,
                              ),
                            ),
                            Text(
                              'Pindai dari Aplikasi Pasien MAPOTECH',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                color: subtitleColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () => Navigator.pop(dCtx),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // QR Code Container
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: themeAccent.withValues(alpha: 0.4),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: themeAccent.withValues(alpha: 0.15),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: QrImageView(
                      data: qrPayload,
                      version: QrVersions.auto,
                      size: 210.0,
                      backgroundColor: Colors.white,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: Color(0xFF1B4F42),
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: Color(0xFF1B4F42),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Live waiting indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF27AE60).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(
                      color: const Color(0xFF27AE60).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF27AE60),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Sesi: $_posSessionId • Menunggu Scan Pasien...',
                        style: GoogleFonts.outfit(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF27AE60),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Demo Simulation Quick Connect
                Text(
                  'Simulasikan Scan Pasien (Demo Mode):',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: subtitleColor,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final p in _registeredPatients.take(3))
                      ActionChip(
                        avatar: const Icon(
                          Icons.phone_android_rounded,
                          size: 14,
                          color: Color(0xFF48C9B0),
                        ),
                        label: Text(
                          p['name'] + (p['has_prescription'] == true ? ' (Ada Resep)' : ''),
                          style: GoogleFonts.outfit(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        backgroundColor: isDark
                            ? const Color(0xFF252528)
                            : const Color(0xFFF1F5F9),
                        onPressed: () {
                          Navigator.pop(dCtx);
                          _connectPatient(p, pendingPrescriptions, allMeds);
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    ).then((_) {
      if (_activeQrDialogCtx == context) {
        _activeQrDialogCtx = null;
      }
    });
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

    final inventoryList = ref.watch(apotekInventoryProvider);
    final prescriptionList = ref.watch(apotekPrescriptionProvider);
    final allMeds = _buildPosMedicines(inventoryList);

    final filteredMedicines = allMeds.where((med) {
      final matchesSearch = med.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          med.genericName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          med.sku.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesForm = _selectedForm == 'all' || med.form.toLowerCase() == _selectedForm.toLowerCase();
      return matchesSearch && matchesForm;
    }).toList();

    final pendingPrescriptions = prescriptionList.where((p) => p.status == 'ready' || p.status == 'compounding' || p.status == 'pending').toList();

    // Listen to real-time connected patient updates from patient app QR scan
    ref.listen<Map<String, dynamic>?>(connectedPosPatientProvider, (prev, next) {
      if (next != null && next != _connectedPatient) {
        setState(() {
          _connectedPatient = next;
          _selectedBuyer = next['name'] ?? 'Pasien Terhubung';
          _isSearchOpen = false;
        });

        // Close POS QR modal if it is currently open
        if (_activeQrDialogCtx != null) {
          try {
            Navigator.of(_activeQrDialogCtx!).pop();
          } catch (_) {}
          _activeQrDialogCtx = null;
        }

        final pName = (next['name'] ?? '').toString().toLowerCase();
        final matchingRx = pendingPrescriptions.where((rx) =>
          rx.patientName.toLowerCase().contains(pName) ||
          pName.contains(rx.patientName.toLowerCase())
        ).toList();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.verified_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Pasien ${next['name']} berhasil terhubung ke POS via QR Scan!',
                    style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF1B4F42),
            duration: const Duration(seconds: 4),
            action: matchingRx.isNotEmpty
                ? SnackBarAction(
                    label: 'MUAT RESEP',
                    textColor: const Color(0xFF48C9B0),
                    onPressed: () {
                      _loadPrescriptionToCart(matchingRx.first, allMeds);
                    },
                  )
                : null,
          ),
        );
      } else if (next == null && _connectedPatient != null) {
        setState(() {
          _connectedPatient = null;
          _selectedBuyer = '';
        });
      }
    });

    final isMobile = MediaQuery.of(context).size.width < 768;

    if (_isLoading) {
      return Container(
        height: 300,
        alignment: Alignment.center,
        child: CircularProgressIndicator(color: themeAccent),
      );
    }

    // Check if connected patient has pending prescriptions ready
    ApotekPrescriptionOrder? connectedPatientRx;
    if (_connectedPatient != null) {
      final pName = (_connectedPatient!['name'] ?? '').toString().toLowerCase();
      final matches = pendingPrescriptions.where((rx) =>
        rx.patientName.toLowerCase().contains(pName) ||
        pName.contains(rx.patientName.toLowerCase())
      ).toList();
      if (matches.isNotEmpty) {
        connectedPatientRx = matches.first;
      }
    }

    return Stack(
      children: [
        // Scrollable content area
        SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            isMobile ? 16 : 28,
            isMobile ? 16 : 28,
            isMobile ? 16 : 28,
            _cart.isNotEmpty ? 110 : (isMobile ? 16 : 28),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ─── 1. BUYER SEARCH & LINK PANEL ─────────────────
              Container(
                decoration: BoxDecoration(
                  color: cardBgColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _connectedPatient != null
                        ? const Color(0xFF27AE60).withValues(alpha: 0.5)
                        : borderColor,
                    width: _connectedPatient != null ? 1.5 : 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _connectedPatient != null
                          ? const Color(0xFF27AE60).withValues(alpha: 0.06)
                          : Colors.black.withValues(alpha: 0.02),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Main Patient Identity Row
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: _connectedPatient != null
                                  ? const Color(0xFF27AE60).withValues(alpha: 0.15)
                                  : themeAccent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              _connectedPatient != null
                                  ? Icons.verified_user_rounded
                                  : Icons.person_search_rounded,
                              color: _connectedPatient != null
                                  ? const Color(0xFF27AE60)
                                  : themeAccent,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      _connectedPatient != null
                                          ? _connectedPatient!['name']
                                          : 'Identitas Pembeli / Pasien',
                                      style: GoogleFonts.outfit(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w900,
                                        color: textColor,
                                      ),
                                    ),
                                    if (_connectedPatient != null) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF27AE60).withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          'TERHUBUNG',
                                          style: GoogleFonts.outfit(
                                            fontSize: 8,
                                            fontWeight: FontWeight.w900,
                                            color: const Color(0xFF27AE60),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _connectedPatient != null
                                      ? 'NIK: ${_connectedPatient!['nik'] ?? '-'} • BPJS: ${_connectedPatient!['bpjs_number'] ?? 'Aktif'} • Telp: ${_connectedPatient!['phone'] ?? _connectedPatient!['phone_number'] ?? '-'}'
                                      : 'Pembeli Umum (Walk-in) • Hubungkan dengan Pasien Terdaftar / BPJS',
                                  style: GoogleFonts.outfit(
                                    fontSize: 10,
                                    color: subtitleColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (_connectedPatient == null) ...[
                            // Search Patient Button
                            OutlinedButton.icon(
                              onPressed: () {
                                setState(() {
                                  _isSearchOpen = !_isSearchOpen;
                                  if (_isSearchOpen) {
                                    _patientSearchResults = List.from(_registeredPatients);
                                  }
                                });
                              },
                              icon: Icon(
                                _isSearchOpen
                                    ? Icons.keyboard_arrow_up_rounded
                                    : Icons.search_rounded,
                                size: 15,
                                color: themeAccent,
                              ),
                              label: Text(
                                _isSearchOpen ? 'Tutup' : 'Cari Pasien',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: themeAccent,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                  color: themeAccent.withValues(alpha: 0.4),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),

                            // QR Scan Connect Button
                            ElevatedButton.icon(
                              onPressed: () {
                                _showPosQrModal(
                                  context: context,
                                  themeAccent: themeAccent,
                                  isDark: isDark,
                                  textColor: textColor,
                                  subtitleColor: subtitleColor,
                                  cardBgColor: cardBgColor,
                                  borderColor: borderColor,
                                  pendingPrescriptions: pendingPrescriptions,
                                  allMeds: allMeds,
                                );
                              },
                              icon: const Icon(
                                Icons.qr_code_2_rounded,
                                size: 16,
                                color: Colors.white,
                              ),
                              label: Text(
                                'QR Kasir',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: themeAccent,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                elevation: 0,
                              ),
                            ),
                          ] else ...[
                            // Disconnect Patient Button
                            TextButton.icon(
                              onPressed: _disconnectPatient,
                              icon: const Icon(
                                Icons.link_off_rounded,
                                size: 16,
                                color: Colors.redAccent,
                              ),
                              label: Text(
                                'Putus',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.redAccent,
                                ),
                              ),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Active prescription banner for connected patient
                    if (connectedPatientRx != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF27AE60).withValues(alpha: 0.1),
                          border: Border(
                            top: BorderSide(
                              color: const Color(0xFF27AE60).withValues(alpha: 0.2),
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.receipt_long_rounded,
                              size: 16,
                              color: Color(0xFF27AE60),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Pasien memiliki resep digital siap checkout (${connectedPatientRx.items.length} obat)',
                                style: GoogleFonts.outfit(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF27AE60),
                                ),
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () => _loadPrescriptionToCart(connectedPatientRx!, allMeds),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF27AE60),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                elevation: 0,
                              ),
                              child: Text(
                                'Muat ke Kasir',
                                style: GoogleFonts.outfit(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Search Bar Dropdown Panel
                    if (_isSearchOpen && _connectedPatient == null) ...[
                      Container(
                        padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(color: borderColor),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 14),

                            // Search TextField
                            Container(
                              height: 42,
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF1E1E22)
                                    : const Color(0xFFF6F8FB),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: borderColor),
                              ),
                              child: TextField(
                                controller: _patientSearchCtrl,
                                autofocus: true,
                                style: GoogleFonts.outfit(
                                  fontSize: 12.5,
                                  color: textColor,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Cari nama pasien, NIK (16 digit), atau No. BPJS...',
                                  hintStyle: GoogleFonts.outfit(
                                    fontSize: 11.5,
                                    color: subtitleColor.withValues(alpha: 0.7),
                                  ),
                                  prefixIcon: Icon(
                                    Icons.search_rounded,
                                    size: 18,
                                    color: themeAccent,
                                  ),
                                  suffixIcon: _patientSearchCtrl.text.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(
                                            Icons.clear_rounded,
                                            size: 16,
                                          ),
                                          onPressed: () {
                                            _patientSearchCtrl.clear();
                                            _performPatientSearch('');
                                          },
                                        )
                                      : null,
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 11,
                                    horizontal: 8,
                                  ),
                                ),
                                onChanged: (val) => _performPatientSearch(val),
                              ),
                            ),

                            const SizedBox(height: 10),

                            // Patient Search Results List
                            if (_isSearchingPatients)
                              Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: themeAccent,
                                    ),
                                  ),
                                ),
                              )
                            else if (_patientSearchResults.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                child: Text(
                                  'Pasien tidak ditemukan dengan kata kunci "${_patientSearchCtrl.text}".',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    color: subtitleColor,
                                  ),
                                ),
                              )
                            else ...[
                              Text(
                                'Pilih Pasien Terdaftar (${_patientSearchResults.length} hasil):',
                                style: GoogleFonts.outfit(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: subtitleColor,
                                ),
                              ),
                              const SizedBox(height: 6),
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxHeight: 180),
                                child: ListView.separated(
                                  shrinkWrap: true,
                                  itemCount: _patientSearchResults.length,
                                  separatorBuilder: (ctx, i) =>
                                      Divider(color: borderColor, height: 8),
                                  itemBuilder: (ctx, i) {
                                    final p = _patientSearchResults[i];
                                    final hasRx = p['has_prescription'] == true;

                                    return InkWell(
                                      onTap: () => _connectPatient(
                                        p,
                                        pendingPrescriptions,
                                        allMeds,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 6,
                                        ),
                                        child: Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 16,
                                              backgroundColor: themeAccent.withValues(alpha: 0.15),
                                              child: Text(
                                                (p['name'] as String).substring(0, 1).toUpperCase(),
                                                style: GoogleFonts.outfit(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w900,
                                                  color: themeAccent,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Text(
                                                        p['name'],
                                                        style: GoogleFonts.outfit(
                                                          fontSize: 12,
                                                          fontWeight: FontWeight.bold,
                                                          color: textColor,
                                                        ),
                                                      ),
                                                      if (hasRx) ...[
                                                        const SizedBox(width: 6),
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(
                                                            horizontal: 5,
                                                            vertical: 1,
                                                          ),
                                                          decoration: BoxDecoration(
                                                            color: const Color(0xFF27AE60).withValues(alpha: 0.12),
                                                            borderRadius: BorderRadius.circular(4),
                                                          ),
                                                          child: Text(
                                                            'Ada Resep',
                                                            style: GoogleFonts.outfit(
                                                              fontSize: 7.5,
                                                              fontWeight: FontWeight.bold,
                                                              color: const Color(0xFF27AE60),
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                  Text(
                                                    'NIK: ${p['nik']} • BPJS: ${p['bpjs_number']} • ${p['phone']}',
                                                    style: GoogleFonts.outfit(
                                                      fontSize: 9.5,
                                                      color: subtitleColor,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            ElevatedButton(
                                              onPressed: () => _connectPatient(
                                                p,
                                                pendingPrescriptions,
                                                allMeds,
                                              ),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: themeAccent,
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 10,
                                                  vertical: 4,
                                                ),
                                                minimumSize: Size.zero,
                                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                elevation: 0,
                                              ),
                                              child: Text(
                                                'Hubungkan',
                                                style: GoogleFonts.outfit(
                                                  fontSize: 9.5,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
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
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // ─── 2. PENDING RX QUEUE SECTION ─────────────────
              if (pendingPrescriptions.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.assignment_turned_in_rounded, size: 14, color: themeAccent),
                        const SizedBox(width: 6),
                        Text(
                          'Antrian Resep Digital Siap Checkout',
                          style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: textColor),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: themeAccent, borderRadius: BorderRadius.circular(100)),
                      child: Text(
                        '${pendingPrescriptions.length} RESEP',
                        style: GoogleFonts.outfit(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 105,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: pendingPrescriptions.length,
                    itemBuilder: (context, index) {
                      final rx = pendingPrescriptions[index];
                      final isRxReady = rx.status == 'ready';

                      return Container(
                        width: 270,
                        margin: const EdgeInsets.only(right: 12, bottom: 4),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isRxReady ? themeAccent.withValues(alpha: 0.05) : Colors.amber.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isRxReady ? themeAccent.withValues(alpha: 0.3) : Colors.amber.withValues(alpha: 0.3),
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
                                    color: isRxReady ? const Color(0xFF27AE60).withValues(alpha: 0.15) : Colors.amber.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(100),
                                  ),
                                  child: Text(
                                    isRxReady ? 'SIAP CHECKOUT' : (rx.status == 'compounding' ? 'SEDANG DIRACIK' : 'ANTRIAN'),
                                    style: GoogleFonts.outfit(
                                      fontSize: 7.5,
                                      fontWeight: FontWeight.w900,
                                      color: isRxReady ? const Color(0xFF27AE60) : Colors.amber[800],
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
                                  '${rx.items.length} item • ${rx.doctorName}',
                                  style: GoogleFonts.outfit(fontSize: 9, color: subtitleColor),
                                ),
                                ElevatedButton(
                                  onPressed: isRxReady ? () => _loadPrescriptionToCart(rx, allMeds) : null,
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    backgroundColor: isRxReady ? themeAccent : Colors.grey[300],
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  child: Text('LOAD KE KASIR', style: GoogleFonts.outfit(fontSize: 8.5, fontWeight: FontWeight.w900)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // ─── 3. SEARCH & FORM FILTER BAR ─────────────────
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
                          color: isDark ? const Color(0xFF1E1E22) : const Color(0xFFF6F8FB),
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
                                style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: textColor),
                                decoration: InputDecoration(
                                  hintText: 'Cari obat, formula, atau SKU...',
                                  hintStyle: GoogleFonts.outfit(fontSize: 11, color: subtitleColor.withValues(alpha: 0.6)),
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
                        DropdownMenuItem(value: 'kaplet', child: Text('Kaplet')),
                        DropdownMenuItem(value: 'kapsul', child: Text('Kapsul')),
                        DropdownMenuItem(value: 'sirup', child: Text('Sirup')),
                      ],
                      onChanged: (val) => setState(() => _selectedForm = val ?? 'all'),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      icon: Icon(_isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded, size: 20, color: themeAccent),
                      onPressed: () => setState(() => _isGridView = !_isGridView),
                      tooltip: 'Ganti Tampilan',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ─── 4. MEDICINE CATALOG (GRID OR LIST) ───────────
              if (filteredMedicines.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 60),
                  alignment: Alignment.center,
                  child: Column(
                    children: [
                      Icon(Icons.medication_outlined, size: 48, color: themeAccent.withValues(alpha: 0.3)),
                      const SizedBox(height: 12),
                      Text('Tidak Ada Obat Ditemukan', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w900, color: textColor)),
                      const SizedBox(height: 4),
                      Text('Ubah kata kunci pencarian Anda.', style: GoogleFonts.outfit(fontSize: 11, color: subtitleColor)),
                    ],
                  ),
                )
              else if (_isGridView)
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 320,
                    mainAxisExtent: 210,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: filteredMedicines.length,
                  itemBuilder: (context, index) {
                    final med = filteredMedicines[index];
                    return _buildMedicineGridCard(med, isDark, themeAccent, textColor, subtitleColor, cardBgColor, borderColor);
                  },
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredMedicines.length,
                  itemBuilder: (context, index) {
                    final med = filteredMedicines[index];
                    return _buildMedicineListRow(med, isDark, themeAccent, textColor, subtitleColor, cardBgColor, borderColor);
                  },
                ),
            ],
          ),
        ),

        // ─── 5. FIXED STICKY BOTTOM FLOATING CART BAR ─────────────
        if (_cart.isNotEmpty)
          Positioned(
            left: isMobile ? 12 : 24,
            right: isMobile ? 12 : 24,
            bottom: isMobile ? 12 : 18,
            child: _buildFloatingCartBar(themeAccent, isDark, textColor, subtitleColor, cardBgColor, borderColor),
          ),
      ],
    );
  }

  Widget _buildFloatingCartBar(
    Color themeAccent,
    bool isDark,
    Color textColor,
    Color subtitleColor,
    Color cardBgColor,
    Color borderColor,
  ) {
    final totalBill = _cart.fold(0.0, (sum, item) => sum + (item.medicine.sellPrice * item.qty));
    final totalQty = _cart.fold(0, (sum, item) => sum + item.qty);
    final topItemName = _cart.first.medicine.name;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161619) : const Color(0xFF1B0C3C),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 22, offset: const Offset(0, 8)),
        ],
        border: isDark ? Border.all(color: const Color(0xFF252528), width: 1.5) : null,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Shopping cart icon button that triggers the Cart details modal
          InkWell(
            onTap: () => _showCartDetailsModal(themeAccent, isDark, textColor, subtitleColor, cardBgColor, borderColor),
            borderRadius: BorderRadius.circular(100),
            child: Row(
              children: [
                Stack(
                  alignment: Alignment.topRight,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(color: themeAccent, shape: BoxShape.circle),
                      alignment: Alignment.center,
                      child: const Icon(Icons.shopping_cart_rounded, size: 18, color: Colors.white),
                    ),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                      child: Text(
                        '$totalQty',
                        style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      topItemName,
                      style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.white),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      _cart.length > 1 ? '+$totalQty item • Klik lihat keranjang' : '1 jenis obat • Klik lihat keranjang',
                      style: GoogleFonts.outfit(fontSize: 9.5, color: Colors.white.withValues(alpha: 0.7)),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Spacer(),

          // Total Price Info
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'TOTAL TAGIHAN',
                style: GoogleFonts.outfit(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white.withValues(alpha: 0.6)),
              ),
              Text(
                'Rp ${_formatPrice(totalBill)}',
                style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white),
              ),
            ],
          ),

          const SizedBox(width: 14),

          // Direct Checkout Button
          ElevatedButton.icon(
            onPressed: () => _openCheckoutModal(themeAccent, isDark, textColor, subtitleColor, cardBgColor, borderColor),
            icon: const Icon(Icons.payment_rounded, size: 16, color: Colors.white),
            label: Text(
              'BAYAR',
              style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.w900, color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: themeAccent,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicineGridCard(
    PosMedicine med,
    bool isDark,
    Color themeAccent,
    Color textColor,
    Color subtitleColor,
    Color cardBgColor,
    Color borderColor,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: med.stock > 0 ? () => _addToCart(med) : null,
        borderRadius: BorderRadius.circular(18),
        splashColor: themeAccent.withValues(alpha: 0.15),
        highlightColor: themeAccent.withValues(alpha: 0.08),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardBgColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: med.stock > 0 ? const Color(0xFF27AE60).withValues(alpha: 0.12) : Colors.redAccent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      med.stock > 0 ? 'Stok: ${med.stock}' : 'Habis',
                      style: GoogleFonts.outfit(fontSize: 8.5, fontWeight: FontWeight.w900, color: med.stock > 0 ? const Color(0xFF27AE60) : Colors.redAccent),
                    ),
                  ),
                  Text(med.form, style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.bold, color: subtitleColor)),
                ],
              ),
              const SizedBox(height: 8),
              Text(med.name, style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.w900, color: textColor), maxLines: 2, overflow: TextOverflow.ellipsis),
              Text(med.genericName, style: GoogleFonts.outfit(fontSize: 9.5, color: subtitleColor), maxLines: 1, overflow: TextOverflow.ellipsis),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Rp ${_formatPrice(med.sellPrice)}', style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.w900, color: textColor)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: med.stock > 0 ? themeAccent : Colors.grey[300],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '+ TAMBAH',
                      style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMedicineListRow(
    PosMedicine med,
    bool isDark,
    Color themeAccent,
    Color textColor,
    Color subtitleColor,
    Color cardBgColor,
    Color borderColor,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: med.stock > 0 ? () => _addToCart(med) : null,
        borderRadius: BorderRadius.circular(18),
        splashColor: themeAccent.withValues(alpha: 0.15),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardBgColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: themeAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(Icons.medication_rounded, color: themeAccent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(med.name, style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.w900, color: textColor)),
                    Text('${med.genericName} • ${med.form} • Stok: ${med.stock}', style: GoogleFonts.outfit(fontSize: 9.5, color: subtitleColor)),
                  ],
                ),
              ),
              Text('Rp ${_formatPrice(med.sellPrice)}', style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.w900, color: textColor)),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: med.stock > 0 ? themeAccent : Colors.grey[300],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '+ TAMBAH',
                  style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
