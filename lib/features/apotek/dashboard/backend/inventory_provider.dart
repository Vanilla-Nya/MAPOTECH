import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapotech/shared/supabase_service.dart';

class ApotekBatchModel {
  final String id;
  String batchNo;
  String expDate;
  int stock;
  double buyPrice;
  double sellPrice;
  String? rackLocation;
  String? supplier;

  ApotekBatchModel({
    required this.id,
    required this.batchNo,
    required this.expDate,
    required this.stock,
    required this.buyPrice,
    required this.sellPrice,
    this.rackLocation,
    this.supplier,
  });

  ApotekBatchModel copyWith({
    String? id,
    String? batchNo,
    String? expDate,
    int? stock,
    double? buyPrice,
    double? sellPrice,
    String? rackLocation,
    String? supplier,
  }) {
    return ApotekBatchModel(
      id: id ?? this.id,
      batchNo: batchNo ?? this.batchNo,
      expDate: expDate ?? this.expDate,
      stock: stock ?? this.stock,
      buyPrice: buyPrice ?? this.buyPrice,
      sellPrice: sellPrice ?? this.sellPrice,
      rackLocation: rackLocation ?? this.rackLocation,
      supplier: supplier ?? this.supplier,
    );
  }
}

class ApotekInventoryItem {
  final String id;
  String name;
  String sku;
  String brandName;
  String genericName;
  String form; // 'Tablet', 'Kaplet', 'Kapsul', 'Sirup', 'Salep', 'Injeksi', 'Drop'
  int stock;
  String unit; // 'Strip', 'Botol', 'Box', 'Tube', 'Ampul', 'Tablet'
  double buyPrice;
  double sellPrice;
  String rackName;
  String? kfaCode;
  String? manufacturer;
  String? description;
  String? imageUrl;
  bool isArchived;
  List<ApotekBatchModel> batches;

  ApotekInventoryItem({
    required this.id,
    required this.name,
    required this.sku,
    required this.brandName,
    required this.genericName,
    required this.form,
    required this.stock,
    required this.unit,
    required this.buyPrice,
    required this.sellPrice,
    required this.rackName,
    this.kfaCode,
    this.manufacturer,
    this.description,
    this.imageUrl,
    this.isArchived = false,
    this.batches = const [],
  });

  String get status {
    if (stock == 0) return 'habis';
    if (stock < 20) return 'menipis';
    return 'aman';
  }

  ApotekInventoryItem copyWith({
    String? id,
    String? name,
    String? sku,
    String? brandName,
    String? genericName,
    String? form,
    int? stock,
    String? unit,
    double? buyPrice,
    double? sellPrice,
    String? rackName,
    String? kfaCode,
    String? manufacturer,
    String? description,
    String? imageUrl,
    bool? isArchived,
    List<ApotekBatchModel>? batches,
  }) {
    return ApotekInventoryItem(
      id: id ?? this.id,
      name: name ?? this.name,
      sku: sku ?? this.sku,
      brandName: brandName ?? this.brandName,
      genericName: genericName ?? this.genericName,
      form: form ?? this.form,
      stock: stock ?? this.stock,
      unit: unit ?? this.unit,
      buyPrice: buyPrice ?? this.buyPrice,
      sellPrice: sellPrice ?? this.sellPrice,
      rackName: rackName ?? this.rackName,
      kfaCode: kfaCode ?? this.kfaCode,
      manufacturer: manufacturer ?? this.manufacturer,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      isArchived: isArchived ?? this.isArchived,
      batches: batches ?? this.batches,
    );
  }
}

class ApotekInventoryNotifier extends StateNotifier<List<ApotekInventoryItem>> {
  final SupabaseService _db = SupabaseService();
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  ApotekInventoryNotifier() : super([]) {
    loadInventory();
  }

  String _generateBatchCode() {
    final now = DateTime.now();
    final y = now.year.toString();
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    const chars = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    final rand = List.generate(5, (_) => chars[Random().nextInt(chars.length)]).join();
    return 'BT-$y$m$d-$rand';
  }

  Future<void> loadInventory() async {
    _isLoading = true;
    try {
      final List<ApotekInventoryItem> loaded = [];
      final rawMedicines = await _db.fetchMedicinesWithBatches();

      for (final m in rawMedicines) {
        final String id = m['id'] ?? '';
        final String name = m['medicine_name'] ?? 'Obat';
        final String brand = m['brand_name'] ?? name;
        final String generic = m['generic_name'] ?? '-';
        final String form = m['medicine_form'] ?? 'Tablet';
        final String sku = m['sku'] ?? 'SKU-${id.substring(0, id.length > 6 ? 6 : id.length).toUpperCase()}';
        final String rack = m['rack_name'] ?? 'RAK A-01';
        final String? kfa = m['kfa_code'];
        final String? mfg = m['manufacturer'] ?? 'Kimia Farma';
        final String? desc = m['description'] ?? 'Catatan dosis, efek samping, dll...';
        final String? img = m['image_url'];

        final batchesRaw = m['medicine_batches'] as List<dynamic>? ?? [];
        final List<ApotekBatchModel> parsedBatches = [];
        int totalStock = 0;
        double buyP = 3500;
        double sellP = 5000;

        for (final b in batchesRaw) {
          final int bStock = int.tryParse(b['quantity_in_stock']?.toString() ?? '0') ?? 0;
          final double bBuy = double.tryParse(b['purchase_price']?.toString() ?? '3500') ?? 3500;
          final double bSell = double.tryParse(b['selling_price']?.toString() ?? '5000') ?? 5000;
          totalStock += bStock;
          buyP = bBuy;
          sellP = bSell;

          parsedBatches.add(ApotekBatchModel(
            id: b['id'] ?? '',
            batchNo: b['batch_number'] ?? _generateBatchCode(),
            expDate: b['expiration_date']?.toString().split('T').first ?? '2028-12-31',
            stock: bStock,
            buyPrice: bBuy,
            sellPrice: bSell,
            rackLocation: b['rack_location'] ?? rack,
            supplier: b['supplier_name'] ?? 'PBF Enseval Putera',
          ));
        }

        loaded.add(ApotekInventoryItem(
          id: id,
          name: name,
          sku: sku,
          brandName: brand,
          genericName: generic,
          form: form,
          stock: totalStock,
          unit: 'Strip',
          buyPrice: buyP,
          sellPrice: sellP,
          rackName: rack,
          kfaCode: kfa,
          manufacturer: mfg,
          description: desc,
          imageUrl: img,
          batches: parsedBatches,
        ));
      }

      if (loaded.isEmpty) {
        state = _getSampleMockData();
      } else {
        state = loaded;
      }
    } catch (e) {
      debugPrint('Error loading apotek inventory from DB: $e');
      if (state.isEmpty) {
        state = _getSampleMockData();
      }
    } finally {
      _isLoading = false;
      if (mounted) {
        state = List.from(state);
      }
    }
  }

  /// Automatically deducts stock from inventory when a POS sale is executed.
  /// Deducts both from the specific batch and parent medicine, and syncs to Supabase.
  Future<void> deductStockAfterSale(List<Map<String, dynamic>> items) async {
    final updatedList = <ApotekInventoryItem>[];

    for (final medItem in state) {
      final updatedBatches = <ApotekBatchModel>[];
      int medDeductionTotal = 0;

      for (final b in medItem.batches) {
        // Find if this batch was sold
        Map<String, dynamic>? soldItem;
        for (final it in items) {
          if (it['batchId'] == b.id) {
            soldItem = it;
            break;
          }
        }

        if (soldItem != null && soldItem.isNotEmpty) {
          final int soldQty = int.tryParse(soldItem['qty']?.toString() ?? '0') ?? 0;
          final int newBatchStock = max(0, b.stock - soldQty);
          medDeductionTotal += soldQty;

          updatedBatches.add(b.copyWith(stock: newBatchStock));

          // Sync to database
          if (!b.id.startsWith('b-') && b.id.length > 10) {
            try {
              _db.adjustBatchStock(b.id, newBatchStock);
            } catch (e) {
              debugPrint('Notice syncing batch stock deduction to DB: $e');
            }
          }
        } else {
          updatedBatches.add(b);
        }
      }

      // Check if medicine was matched by medicine ID directly (when no batchId provided)
      if (medDeductionTotal == 0) {
        Map<String, dynamic>? soldByMed;
        for (final it in items) {
          if (it['medicineId'] == medItem.id || it['batchId'] == medItem.id) {
            soldByMed = it;
            break;
          }
        }

        if (soldByMed != null && soldByMed.isNotEmpty) {
          final int soldQty = int.tryParse(soldByMed['qty']?.toString() ?? '0') ?? 0;
          medDeductionTotal = soldQty;

          // Deduct from first available batch if any
          if (updatedBatches.isNotEmpty) {
            final firstBatch = updatedBatches.first;
            final newBStock = max(0, firstBatch.stock - soldQty);
            updatedBatches[0] = firstBatch.copyWith(stock: newBStock);
            if (!firstBatch.id.startsWith('b-') && firstBatch.id.length > 10) {
              try {
                _db.adjustBatchStock(firstBatch.id, newBStock);
              } catch (e) {
                debugPrint('Notice syncing batch stock deduction to DB: $e');
              }
            }
          }
        }
      }

      final int newTotalStock = updatedBatches.isNotEmpty
          ? updatedBatches.fold(0, (sum, b) => sum + b.stock)
          : max(0, medItem.stock - medDeductionTotal);

      updatedList.add(medItem.copyWith(
        stock: newTotalStock,
        batches: updatedBatches,
      ));
    }

    state = updatedList;
  }

  /// Adjust a single batch stock (e.g. Stock Opname / Physical Count Correction)
  Future<void> adjustBatchStock(String batchId, int newQuantity, {String? medicineId}) async {
    final updatedList = <ApotekInventoryItem>[];

    for (final med in state) {
      if (med.batches.any((b) => b.id == batchId) || (medicineId != null && med.id == medicineId)) {
        final updatedBatches = med.batches.map((b) {
          if (b.id == batchId) {
            return b.copyWith(stock: newQuantity);
          }
          return b;
        }).toList();

        final totalStock = updatedBatches.fold(0, (sum, b) => sum + b.stock);
        updatedList.add(med.copyWith(stock: totalStock, batches: updatedBatches));
      } else {
        updatedList.add(med);
      }
    }

    state = updatedList;

    if (!batchId.startsWith('b-') && batchId.length > 10) {
      try {
        await _db.adjustBatchStock(batchId, newQuantity);
      } catch (e) {
        debugPrint('Error adjusting batch stock in DB: $e');
      }
    }
  }

  /// Add a new batch to a medicine
  Future<void> addBatch(String medicineId, ApotekBatchModel newBatch) async {
    final updatedList = <ApotekInventoryItem>[];

    for (final med in state) {
      if (med.id == medicineId) {
        final nextBatches = [...med.batches, newBatch];
        final totalStock = nextBatches.fold(0, (sum, b) => sum + b.stock);
        updatedList.add(med.copyWith(stock: totalStock, batches: nextBatches));
      } else {
        updatedList.add(med);
      }
    }

    state = updatedList;
  }

  /// Delete a batch from a medicine
  Future<void> deleteBatch(String medicineId, String batchId) async {
    final updatedList = <ApotekInventoryItem>[];

    for (final med in state) {
      if (med.id == medicineId) {
        final nextBatches = med.batches.where((b) => b.id != batchId).toList();
        final totalStock = nextBatches.fold(0, (sum, b) => sum + b.stock);
        updatedList.add(med.copyWith(stock: totalStock, batches: nextBatches));
      } else {
        updatedList.add(med);
      }
    }

    state = updatedList;

    if (!batchId.startsWith('b-') && batchId.length > 10) {
      try {
        await _db.deleteMedicineBatch(batchId);
      } catch (e) {
        debugPrint('Error deleting batch from DB: $e');
      }
    }
  }

  /// Add new medicine
  void addMedicine(ApotekInventoryItem item) {
    state = [item, ...state];
  }

  /// Update medicine details
  void updateMedicine(ApotekInventoryItem updatedItem) {
    state = [
      for (final it in state)
        if (it.id == updatedItem.id) updatedItem else it,
    ];
  }

  /// Delete medicine
  void deleteMedicine(String medicineId) {
    state = state.where((it) => it.id != medicineId).toList();
  }

  List<ApotekInventoryItem> _getSampleMockData() {
    return [
      ApotekInventoryItem(
        id: 'med-001',
        name: 'Paracetamol 500mg',
        sku: 'SKU-PCT-500',
        brandName: 'Paracetamol',
        genericName: 'Paracetamol',
        form: 'Tablet',
        stock: 140,
        unit: 'Strip',
        buyPrice: 3500,
        sellPrice: 4500,
        rackName: 'RAK A-02',
        kfaCode: '93001030',
        manufacturer: 'Kimia Farma',
        description: 'Pereda demam dan nyeri ringan.',
        batches: [
          ApotekBatchModel(
            id: 'b-pct-1',
            batchNo: 'BT-20260512-PCT01',
            expDate: '2028-05-31',
            stock: 140,
            buyPrice: 3500,
            sellPrice: 4500,
            rackLocation: 'RAK A-02',
            supplier: 'Kimia Farma Trading',
          ),
        ],
      ),
      ApotekInventoryItem(
        id: 'med-002',
        name: 'Amoxicillin Trihydrate 500mg',
        sku: 'SKU-AMX-500',
        brandName: 'Amoxicillin',
        genericName: 'Amoxicillin 500mg',
        form: 'Kaplet',
        stock: 65,
        unit: 'Strip',
        buyPrice: 6500,
        sellPrice: 9500,
        rackName: 'RAK A-01 (Antibiotik)',
        kfaCode: '93001029',
        manufacturer: 'Sanbe Farma',
        description: 'Antibiotik broad spectrum untuk infeksi bakteri.',
        batches: [
          ApotekBatchModel(
            id: 'b-1',
            batchNo: 'BT-20260815-99AMX',
            expDate: '2027-08-15',
            stock: 45,
            buyPrice: 6500,
            sellPrice: 9500,
            rackLocation: 'RAK A-01',
            supplier: 'PBF Enseval Putera',
          ),
          ApotekBatchModel(
            id: 'b-2',
            batchNo: 'BT-20260420-11AMX',
            expDate: '2026-11-20',
            stock: 20,
            buyPrice: 6500,
            sellPrice: 9500,
            rackLocation: 'RAK A-01',
            supplier: 'PBF Mensa Bina',
          ),
        ],
      ),
      ApotekInventoryItem(
        id: 'med-003',
        name: 'Cetirizine HCl 10mg',
        sku: 'SKU-CTZ-010',
        brandName: 'Cetirizine',
        genericName: 'Cetirizine Hydrochloride',
        form: 'Tablet',
        stock: 24,
        unit: 'Strip',
        buyPrice: 4500,
        sellPrice: 7000,
        rackName: 'RAK B-01 (Antihistamin)',
        kfaCode: '93001045',
        manufacturer: 'Dexa Medica',
        description: 'Antihistamin pereda alergi dan gatal.',
        batches: [
          ApotekBatchModel(
            id: 'b-4',
            batchNo: 'BT-20260312-CTZ88',
            expDate: '2026-09-12',
            stock: 24,
            buyPrice: 4500,
            sellPrice: 7000,
            rackLocation: 'RAK B-01',
            supplier: 'PBF Anugrah',
          ),
        ],
      ),
      ApotekInventoryItem(
        id: 'med-004',
        name: 'OBH Tropica Plus Anak 60ml',
        sku: 'SKU-OBH-060',
        brandName: 'OBH Tropica',
        genericName: 'Succus Liquiritiae',
        form: 'Sirup',
        stock: 28,
        unit: 'Botol',
        buyPrice: 18000,
        sellPrice: 24000,
        rackName: 'RAK C-01 (Sirup Batuk)',
        kfaCode: '93001088',
        manufacturer: 'Tropica Mas',
        description: 'Sirup obat batuk dan flu anak.',
        batches: [
          ApotekBatchModel(
            id: 'b-6',
            batchNo: 'BT-20260710-OBH02',
            expDate: '2027-07-10',
            stock: 28,
            buyPrice: 18000,
            sellPrice: 24000,
            rackLocation: 'RAK C-01',
            supplier: 'PBF Enseval Putera',
          ),
        ],
      ),
      ApotekInventoryItem(
        id: 'med-005',
        name: 'Vitamin C 500mg IPI',
        sku: 'SKU-VTC-500',
        brandName: 'Vitamin C IPI',
        genericName: 'Ascorbic Acid',
        form: 'Tablet',
        stock: 85,
        unit: 'Botol',
        buyPrice: 8000,
        sellPrice: 11000,
        rackName: 'RAK D-01 (Vitamin)',
        kfaCode: '93001031',
        manufacturer: 'Supra Ferbindo Farma',
        description: 'Suplemen vitamin C harian daya tahan tubuh.',
        batches: [
          ApotekBatchModel(
            id: 'b-7',
            batchNo: 'BT-20260901-VTC55',
            expDate: '2028-09-01',
            stock: 85,
            buyPrice: 8000,
            sellPrice: 11000,
            rackLocation: 'RAK D-01',
            supplier: 'PBF Mensa Bina',
          ),
        ],
      ),
      ApotekInventoryItem(
        id: 'med-006',
        name: 'Metformin HCl 500mg',
        sku: 'SKU-MTF-500',
        brandName: 'Metformin',
        genericName: 'Metformin Hydrochloride',
        form: 'Tablet',
        stock: 18,
        unit: 'Strip',
        buyPrice: 3200,
        sellPrice: 5000,
        rackName: 'RAK B-03 (Diabetes)',
        kfaCode: '93001052',
        manufacturer: 'Hexpharm Jaya',
        description: 'Obat antidiabetes oral.',
        batches: [
          ApotekBatchModel(
            id: 'b-5',
            batchNo: 'BT-20251130-MTF05',
            expDate: '2026-06-30',
            stock: 18,
            buyPrice: 3200,
            sellPrice: 5000,
            rackLocation: 'RAK B-03',
            supplier: 'PBF Mensa Bina',
          ),
        ],
      ),
    ];
  }
}

final apotekInventoryProvider =
    StateNotifierProvider<ApotekInventoryNotifier, List<ApotekInventoryItem>>((ref) {
  return ApotekInventoryNotifier();
});
