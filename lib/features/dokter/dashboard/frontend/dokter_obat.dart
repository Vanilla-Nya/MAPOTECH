import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapotech/features/landing/landing_page_data.dart';
import 'package:mapotech/shared/widgets/custom_button.dart';
import 'package:mapotech/shared/supabase_service.dart';
import 'package:mapotech/shared/satusehat_service.dart';
import 'package:mapotech/shared/widgets/common_pagination.dart';
import 'package:http/http.dart' as http;
import 'package:mapotech/shared/thousands_formatter.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:math';


// ─── Data Models ─────────────────────────────────────────────────────────────

class BatchModel {
  final String? id;
  final String batchNo;
  final int stok;
  final String expDate;
  final String lokasi;
  final double hargaBeli;
  final double hargaJual;

  const BatchModel({
    this.id,
    required this.batchNo,
    required this.stok,
    required this.expDate,
    required this.lokasi,
    required this.hargaBeli,
    required this.hargaJual,
  });

  BatchModel copyWith({
    String? id,
    String? batchNo,
    int? stok,
    String? expDate,
    String? lokasi,
    double? hargaBeli,
    double? hargaJual,
  }) {
    return BatchModel(
      id: id ?? this.id,
      batchNo: batchNo ?? this.batchNo,
      stok: stok ?? this.stok,
      expDate: expDate ?? this.expDate,
      lokasi: lokasi ?? this.lokasi,
      hargaBeli: hargaBeli ?? this.hargaBeli,
      hargaJual: hargaJual ?? this.hargaJual,
    );
  }
}

class OpnameLog {
  final String batchNo;
  final int stokSistem;
  final int stokFisik;
  final int selisih;
  final String date;

  const OpnameLog({
    required this.batchNo,
    required this.stokSistem,
    required this.stokFisik,
    required this.selisih,
    required this.date,
  });
}

class ObatModel {
  final String id;
  final String nama;
  final String jenis;
  final String sku;
  final double hargaSatuan;
  final int totalStok;
  final String status; // 'Tersedia' or 'Stok Minim'
  final Color avatarBg;
  final List<BatchModel> batches;
  final List<OpnameLog> opnameLogs;
  final String? kfaCode;

  const ObatModel({
    required this.id,
    required this.nama,
    required this.jenis,
    required this.sku,
    required this.hargaSatuan,
    required this.totalStok,
    required this.status,
    required this.avatarBg,
    required this.batches,
    this.opnameLogs = const [],
    this.kfaCode,
  });

  ObatModel copyWith({
    String? id,
    String? nama,
    String? jenis,
    String? sku,
    double? hargaSatuan,
    int? totalStok,
    String? status,
    Color? avatarBg,
    List<BatchModel>? batches,
    List<OpnameLog>? opnameLogs,
    String? kfaCode,
  }) {
    return ObatModel(
      id: id ?? this.id,
      nama: nama ?? this.nama,
      jenis: jenis ?? this.jenis,
      sku: sku ?? this.sku,
      hargaSatuan: hargaSatuan ?? this.hargaSatuan,
      totalStok: totalStok ?? this.totalStok,
      status: status ?? this.status,
      avatarBg: avatarBg ?? this.avatarBg,
      batches: batches ?? this.batches,
      opnameLogs: opnameLogs ?? this.opnameLogs,
      kfaCode: kfaCode ?? this.kfaCode,
    );
  }
}

// ─── Helpers & Mapping Functions ──────────────────────────────────────────────

String _generateUuidV4() {
  final random = Random.secure();
  final values = List<int>.generate(16, (i) => random.nextInt(256));
  values[6] = (values[6] & 0x0f) | 0x40; // version 4
  values[8] = (values[8] & 0x3f) | 0x80; // variant
  final buffer = StringBuffer();
  for (var i = 0; i < 16; i++) {
    if (i == 4 || i == 6 || i == 8 || i == 10) buffer.write('-');
    buffer.write(values[i].toRadixString(16).padLeft(2, '0'));
  }
  return buffer.toString();
}

String _formatUiDateToDb(String uiDate) {
  try {
    final parts = uiDate.split('/').map((p) => p.trim()).toList();
    if (parts.length == 3) {
      final day = parts[0].padLeft(2, '0');
      final month = parts[1].padLeft(2, '0');
      final year = parts[2];
      return '$year-$month-$day';
    }
  } catch (_) {}
  return uiDate;
}

ObatModel _mapDbToObatModel(Map<String, dynamic> m) {
  final id = m['id']?.toString() ?? '';
  final nama = m['medicine_name']?.toString() ?? '';
  final jenis = m['medicine_form']?.toString() ?? '';
  final sku = m['barcode']?.toString() ?? m['id']?.toString() ?? '';
  
  final dbBatches = m['detail_medicine'] as List<dynamic>? ?? [];
  final List<BatchModel> batches = [];
  int totalStok = 0;
  double latestSellPrice = 0.0;
  
  for (final b in dbBatches) {
    final batchMap = b as Map<String, dynamic>;
    final batchNo = batchMap['batch_no']?.toString() ?? '';
    final stok = int.tryParse(batchMap['stock_batch']?.toString() ?? '0') ?? 0;
    
    String expDate = batchMap['expierd_date']?.toString() ?? '';
    if (expDate.isNotEmpty && expDate.contains('-')) {
      final parts = expDate.split('-');
      if (parts.length == 3) {
        expDate = '${parts[2]} / ${parts[1]} / ${parts[0]}';
      }
    }
    
    final lokasi = batchMap['location']?.toString() ?? 'Shelf A-01';
    final hargaBeli = double.tryParse(batchMap['buy_price']?.toString() ?? '0') ?? 0.0;
    final hargaJual = double.tryParse(batchMap['sell_price']?.toString() ?? '0') ?? 0.0;
    final batchId = batchMap['id']?.toString();
    
    batches.add(BatchModel(
      id: batchId,
      batchNo: batchNo,
      stok: stok,
      expDate: expDate,
      lokasi: lokasi,
      hargaBeli: hargaBeli,
      hargaJual: hargaJual,
    ));
    totalStok += stok;
    if (hargaJual > 0) {
      latestSellPrice = hargaJual;
    }
  }
  
  if (latestSellPrice == 0.0) {
    latestSellPrice = double.tryParse(m['het_price']?.toString() ?? '0') ?? 0.0;
  }
  
  return ObatModel(
    id: id,
    nama: nama,
    jenis: jenis,
    sku: sku,
    hargaSatuan: latestSellPrice,
    totalStok: totalStok,
    status: totalStok <= 5 ? 'Stok Minim' : 'Tersedia',
    avatarBg: jenis.toLowerCase().contains('generik') ? const Color(0xFF48C9B0) : const Color(0xFFB577F2),
    batches: batches,
    kfaCode: m['kfa_code']?.toString(),
  );
}

// ─── Riverpod State Provider ──────────────────────────────────────────────────


class DokterObatListNotifier extends StateNotifier<List<ObatModel>> {
  final _db = SupabaseService();
  String? _currentDoctorId;

  DokterObatListNotifier() : super([]);

  Future<void> loadMedicines(String doctorId) async {
    _currentDoctorId = doctorId;
    try {
      final dbMedicines = await _db.fetchDoctorMedicinesWithBatches(doctorId);
      final List<ObatModel> loaded = [];
      for (final m in dbMedicines) {
        loaded.add(_mapDbToObatModel(m));
      }
      state = loaded;
    } catch (e) {
      print('Error loading doctor medicines: $e');
    }
  }

  Future<void> addDrug(ObatModel drug) async {
    final doctorId = _currentDoctorId ?? '8f93471a-74f8-486b-8e85-4002dc44c11c';
    try {
      final initialBatch = drug.batches.isNotEmpty
          ? {
              'batch_no': drug.batches.first.batchNo,
              'stock_batch': drug.batches.first.stok.toString(),
              'buy_price': drug.batches.first.hargaBeli.toString(),
              'sell_price': drug.batches.first.hargaJual.toString(),
              'location': drug.batches.first.lokasi,
              'expierd_date': _formatUiDateToDb(drug.batches.first.expDate),
            }
          : {
              'batch_no': 'B260526-656',
              'stock_batch': '0',
              'buy_price': '0',
              'sell_price': '0',
              'location': 'Shelf A-01',
              'expierd_date': '2028-05-26',
            };

      await _db.addDoctorMedicine(
        doctorId: doctorId,
        medicineId: drug.id,
        name: drug.nama,
        form: drug.jenis,
        barcode: drug.sku,
        sellPrice: drug.hargaSatuan,
        initialBatch: initialBatch,
      );
      state = [...state, drug];
    } catch (e) {
      print('Error adding medicine to DB: $e');
      state = [...state, drug];
    }
  }

  Future<void> updateDrug(ObatModel updated) async {
    try {
      final dbBatches = updated.batches.map((b) => {
        'batch_no': b.batchNo,
        'stock_batch': b.stok.toString(),
        'buy_price': b.hargaBeli.toString(),
        'sell_price': b.hargaJual.toString(),
        'location': b.lokasi,
        'expierd_date': _formatUiDateToDb(b.expDate),
      }).toList();

      await _db.updateDoctorMedicine(
        medicineId: updated.id,
        sellPrice: updated.hargaSatuan,
        batches: dbBatches,
      );

      state = [
        for (final drug in state)
          if (drug.id == updated.id) updated else drug
      ];
    } catch (e) {
      print('Error updating medicine in DB: $e');
      state = [
        for (final drug in state)
          if (drug.id == updated.id) updated else drug
      ];
    }
  }

  Future<void> deleteDrug(String id) async {
    try {
      await _db.deleteDoctorMedicine(id);
      state = state.where((drug) => drug.id != id).toList();
    } catch (e) {
      print('Error deleting medicine in DB: $e');
      state = state.where((drug) => drug.id != id).toList();
    }
  }
}

final dokterObatListProvider =
    StateNotifierProvider<DokterObatListNotifier, List<ObatModel>>((ref) {
  return DokterObatListNotifier();
});

// ─── Dokter Obat View ────────────────────────────────────────────────────────

class DokterObat extends ConsumerStatefulWidget {
  const DokterObat({super.key});

  @override
  ConsumerState<DokterObat> createState() => _DokterObatState();
}

class _DokterObatState extends ConsumerState<DokterObat> {
  String _searchQuery = '';
  String _activeFilter = 'Semua'; // 'Semua', 'Stok Minim', 'Hampir Kadaluarsa'
  int _currentPage = 1;
  int _rowsPerPage = 10;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userState = ref.read(landingPageProvider);
      final userId = userState.activeDoctorId;
      final doctorId = (userId == 'mock-id-1234567890' || userId == null)
          ? '8f93471a-74f8-486b-8e85-4002dc44c11c'
          : userId;
      ref.read(dokterObatListProvider.notifier).loadMedicines(doctorId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(landingPageProvider);
    final allDrugs = ref.watch(dokterObatListProvider);

    final isDark = state.appearance == 'dark';
    final isRev = state.appearance == 'rev';
    final cardBgColor = isDark ? const Color(0xFF161619) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1B0C3C);
    final subtitleColor = isDark ? Colors.grey[400]! : const Color(0xFF6F6A8A);
    final borderColor = isDark ? const Color(0xFF252528) : const Color(0xFFECEEF2);
    final themeAccent = isRev ? const Color(0xFFB577F2) : const Color(0xFF48C9B0);
    final purpleAccent = themeAccent;
    final inputBg = isDark ? const Color(0xFF1E1E22) : const Color(0xFFF6F8FA);

    // Apply Filter & Search
    List<ObatModel> filteredDrugs = allDrugs.where((o) {
      final query = _searchQuery.toLowerCase();
      final matchQuery = o.nama.toLowerCase().contains(query) ||
          o.sku.toLowerCase().contains(query) ||
          o.jenis.toLowerCase().contains(query) ||
          o.batches.any((b) => b.batchNo.toLowerCase().contains(query));

      if (!matchQuery) return false;

      if (_activeFilter == 'Stok Minim') {
        return o.status == 'Stok Minim';
      } else if (_activeFilter == 'Hampir Kadaluarsa') {
        // Mock nearly expired logic
        return o.batches.any((b) => b.expDate.contains('2027'));
      }
      return true;
    }).toList();

    // Counts for filters
    final stokMinimCount = allDrugs.where((o) => o.status == 'Stok Minim').length;
    final hampirExpCount = allDrugs.where((o) => o.batches.any((b) => b.expDate.contains('2027'))).length;

    // Pagination
    final totalDataCount = filteredDrugs.length;
    final totalPages = (totalDataCount / _rowsPerPage).ceil();
    final startIndex = (_currentPage - 1) * _rowsPerPage;
    final endIndex = (startIndex + _rowsPerPage) > totalDataCount ? totalDataCount : (startIndex + _rowsPerPage);
    final paginatedDrugs = filteredDrugs.sublist(startIndex, endIndex);

    final isMobile = MediaQuery.of(context).size.width < 768;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ─── Header Banner ───────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Data Obat'.tr(state),
                    style: GoogleFonts.outfit(
                      fontSize: isMobile ? 22 : 28,
                      fontWeight: FontWeight.w900,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Kelola stok, lacak batch, dan pantau tanggal kedaluwarsa.'.tr(state),
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: subtitleColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            CustomButton(
              text: 'Tambah Obat'.tr(state),
              icon: Icons.add_rounded,
              primaryColor: purpleAccent,
              textColor: Colors.white,
              height: 44,
              onPressed: () => _showAddDrugModal(context, isDark),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // ─── Controls (Search & Filters) ───────────────────────
        isMobile
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSearchField(isDark, textColor, subtitleColor, borderColor),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('Semua Obat', _activeFilter == 'Semua', () => setState(() { _activeFilter = 'Semua'; _currentPage = 1; }), purpleAccent, subtitleColor, cardBgColor, borderColor, count: allDrugs.length),
                        const SizedBox(width: 8),
                        _buildFilterChip('Stok Minim', _activeFilter == 'Stok Minim', () => setState(() { _activeFilter = 'Stok Minim'; _currentPage = 1; }), Colors.redAccent, subtitleColor, cardBgColor, borderColor, count: stokMinimCount, icon: Icons.warning_amber_rounded),
                        const SizedBox(width: 8),
                        _buildFilterChip('Hampir Kedaluwarsa', _activeFilter == 'Hampir Kadaluarsa', () => setState(() { _activeFilter = 'Hampir Kadaluarsa'; _currentPage = 1; }), Colors.amber[700]!, subtitleColor, cardBgColor, borderColor, count: hampirExpCount, icon: Icons.access_time_rounded),
                      ],
                    ),
                  ),
                ],
              )
            : Row(
                children: [
                  Expanded(
                    child: _buildSearchField(isDark, textColor, subtitleColor, borderColor),
                  ),
                  const SizedBox(width: 16),
                  _buildFilterChip('Semua Obat', _activeFilter == 'Semua', () => setState(() { _activeFilter = 'Semua'; _currentPage = 1; }), purpleAccent, subtitleColor, cardBgColor, borderColor, count: allDrugs.length),
                  const SizedBox(width: 8),
                  _buildFilterChip('Stok Minim', _activeFilter == 'Stok Minim', () => setState(() { _activeFilter = 'Stok Minim'; _currentPage = 1; }), Colors.redAccent, subtitleColor, cardBgColor, borderColor, count: stokMinimCount, icon: Icons.warning_amber_rounded),
                  const SizedBox(width: 8),
                  _buildFilterChip('Hampir Kedaluwarsa', _activeFilter == 'Hampir Kadaluarsa', () => setState(() { _activeFilter = 'Hampir Kadaluarsa'; _currentPage = 1; }), Colors.amber[700]!, subtitleColor, cardBgColor, borderColor, count: hampirExpCount, icon: Icons.access_time_rounded),
                ],
              ),

        const SizedBox(height: 20),

        // ─── Table Container ───────────────────────────────────
        Container(
          decoration: BoxDecoration(
            color: cardBgColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.01),
                blurRadius: 12,
                offset: const Offset(0, 4),
              )
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Table Headers
              Container(
                color: isDark ? const Color(0xFF1E1E22) : const Color(0xFFF8FAFC),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Row(
                  children: [
                    Expanded(flex: 3, child: _buildTableHeaderText('NAMA OBAT', subtitleColor)),
                    Expanded(flex: 2, child: _buildTableHeaderText('SKU / BARCODE', subtitleColor)),
                    Expanded(flex: 2, child: _buildTableHeaderText('HARGA SATUAN', subtitleColor)),
                    Expanded(flex: 2, child: _buildTableHeaderText('TOTAL STOK', subtitleColor)),
                    Expanded(flex: 2, child: _buildTableHeaderText('STATUS', subtitleColor)),
                  ],
                ),
              ),

              // Rows
              filteredDrugs.isEmpty
                  ? _buildEmptyState(isDark, cardBgColor, borderColor, textColor, subtitleColor)
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: paginatedDrugs.length,
                      separatorBuilder: (context, index) => Divider(color: borderColor, height: 1),
                      itemBuilder: (context, index) {
                        final drug = paginatedDrugs[index];
                        return _buildDrugRow(context, drug, isDark, cardBgColor, borderColor, textColor, subtitleColor, themeAccent);
                      },
                    ),

              // Pagination Footer
              ReusablePagination(
                totalItems: totalDataCount,
                itemsPerPage: _rowsPerPage,
                currentPage: _currentPage,
                onPageChanged: (page) {
                  setState(() {
                    _currentPage = page;
                  });
                },
                onItemsPerPageChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _rowsPerPage = val;
                      _currentPage = 1;
                    });
                  }
                },
                textColor: textColor,
                subtitleColor: subtitleColor,
                borderColor: borderColor,
                inputBg: inputBg,
                activeColor: purpleAccent,
                languageCode: state.language,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── UI Helper Methods ─────────────────────────────────────────────────────

  Widget _buildSearchField(
      bool isDark, Color textColor, Color subtitleColor, Color borderColor) {
    final state = ref.read(landingPageProvider);
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E22) : const Color(0xFFF1EEFA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 18, color: subtitleColor),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                  _currentPage = 1;
                });
              },
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
              decoration: InputDecoration(
                hintText: 'Cari nama, SKU, atau ID batch...'.tr(state),
                hintStyle: GoogleFonts.outfit(
                  fontSize: 12,
                  color: subtitleColor.withOpacity(0.5),
                ),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    String label,
    bool isSelected,
    VoidCallback onTap,
    Color activeColor,
    Color subtitleColor,
    Color cardBg,
    Color border, {
    int count = 0,
    IconData? icon,
  }) {
    final state = ref.read(landingPageProvider);
    final bg = isSelected ? activeColor.withOpacity(0.12) : cardBg;
    final fg = isSelected ? activeColor : subtitleColor;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isSelected ? activeColor : border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: fg),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                  color: fg,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected ? activeColor.withOpacity(0.2) : border,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  count.toString(),
                  style: GoogleFonts.outfit(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: fg,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTableHeaderText(String title, Color col) {
    return Text(
      title,
      style: GoogleFonts.outfit(
        fontSize: 9,
        fontWeight: FontWeight.w900,
        color: col,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildDrugRow(
    BuildContext context,
    ObatModel drug,
    bool isDark,
    Color cardBg,
    Color border,
    Color text,
    Color subtitle,
    Color accent,
  ) {
    final initials = drug.nama.isNotEmpty ? drug.nama[0].toUpperCase() : 'O';
    final String formattedPrice = drug.hargaSatuan == 0 ? 'Rp 0' : 'Rp ${_formatPrice(drug.hargaSatuan)}';

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _showDrugDetailModal(context, drug, isDark),
        child: Container(
          color: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              // Drug Name + Avatar
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: drug.avatarBg.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        initials,
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: drug.avatarBg,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            drug.nama,
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: text,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            drug.jenis,
                            style: GoogleFonts.outfit(
                              fontSize: 9.5,
                              color: subtitle,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // SKU
              Expanded(
                flex: 2,
                child: Text(
                  drug.sku,
                  style: GoogleFonts.outfit(fontSize: 11, color: subtitle, fontWeight: FontWeight.bold),
                ),
              ),

              // Price
              Expanded(
                flex: 2,
                child: Text(
                  formattedPrice,
                  style: GoogleFonts.outfit(fontSize: 12, color: text, fontWeight: FontWeight.w900),
                ),
              ),

              // Stock
              Expanded(
                flex: 2,
                child: Text(
                  '${_formatStock(drug.totalStok)} Tablet',
                  style: GoogleFonts.outfit(fontSize: 12, color: text, fontWeight: FontWeight.w900),
                ),
              ),

              // Status Badge
              Expanded(
                flex: 2,
                child: Row(
                  children: [
                    _buildStatusBadge(drug.status),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final isMinim = status == 'Stok Minim';
    final bg = isMinim ? Colors.redAccent.withOpacity(0.1) : const Color(0xFFB577F2).withOpacity(0.1);
    final fg = isMinim ? Colors.redAccent : const Color(0xFFB577F2);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        status,
        style: GoogleFonts.outfit(
          fontSize: 8.5,
          fontWeight: FontWeight.w900,
          color: fg,
        ),
      ),
    );
  }

  Widget _buildEmptyState(
      bool isDark, Color cardBg, Color border, Color text, Color subtitle) {
    final state = ref.read(landingPageProvider);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 64),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: subtitle.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(Icons.medication_liquid_rounded, size: 20, color: subtitle),
          ),
          const SizedBox(height: 12),
          Text(
            'Obat tidak ditemukan'.tr(state),
            style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w900, color: text),
          ),
          const SizedBox(height: 3),
          Text(
            'Sesuaikan kata kunci pencarian Anda.'.tr(state),
            style: GoogleFonts.outfit(fontSize: 10.5, color: subtitle, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  String _generateBatchNo({int offset = 0}) {
    final now = DateTime.now();
    final yy = now.year.toString().substring(2);
    final mm = now.month.toString().padLeft(2, '0');
    final dd = now.day.toString().padLeft(2, '0');
    final random = Random().nextInt(900) + 100 + offset; // 100 to 999
    return 'B$yy$mm$dd-$random';
  }

  // ─── Modal: Detail Obat & Stock Opname ──────────────────────────────────────

  void _showDrugDetailModal(BuildContext context, ObatModel drug, bool isDark) {
    final state = ref.read(landingPageProvider);
    final purple = ref.read(landingPageProvider.notifier).getPrimaryColor();
    final green = const Color(0xFF27AE60);
    final cardBg = isDark ? const Color(0xFF161619) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1B0C3C);
    final subtitleColor = isDark ? Colors.grey[400]! : const Color(0xFF6F6A8A);
    final borderColor = isDark ? const Color(0xFF252528) : const Color(0xFFECEEF2);
    final sectionBg = isDark ? const Color(0xFF1E1E22) : const Color(0xFFFBF9FF);
    final itemBg = isDark ? const Color(0xFF252528) : const Color(0xFFF1EEFA);

    // Form inputs for Stock Opname (indexed by batchNo)
    final Map<String, TextEditingController> opnameControllers = {};
    for (final batch in drug.batches) {
      opnameControllers[batch.batchNo] = TextEditingController();
    }

    // Barcode controller (editable SKU / BARCODE field)
    final barcodeController = TextEditingController(text: drug.sku);
    bool isSavingBarcode = false;

    final isMobile = MediaQuery.of(context).size.width < 650;

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.4),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return Dialog(
            insetPadding: EdgeInsets.symmetric(
              horizontal: isMobile ? 12 : (MediaQuery.of(context).size.width - 550) / 2,
              vertical: 36,
            ),
            backgroundColor: Colors.transparent,
            child: Container(
              width: 550,
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 40,
                    offset: const Offset(0, 16),
                  )
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // --- Header ---
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
                    color: isDark ? const Color(0xFF1A1A1E) : const Color(0xFFF8F5FF),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: purple.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Icon(Icons.info_outline_rounded, color: purple, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Detail Obat'.tr(state),
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: textColor,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                  ),

                  // --- Scrollable Content ---
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 1. INFORMASI OBAT Card
                          _buildModalSectionHeader('INFORMASI OBAT'.tr(state), purple),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: sectionBg,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: borderColor),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: drug.avatarBg.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    drug.nama.isNotEmpty ? drug.nama[0] : 'O',
                                    style: GoogleFonts.outfit(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color: drug.avatarBg,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        drug.nama,
                                        style: GoogleFonts.outfit(
                                            fontSize: 15, fontWeight: FontWeight.w900, color: textColor),
                                      ),
                                      Text(
                                        drug.jenis,
                                        style: GoogleFonts.outfit(
                                            fontSize: 10, color: subtitleColor, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // ── Editable Barcode Field ──
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'SKU / BARCODE'.tr(state),
                                                style: GoogleFonts.outfit(fontSize: 7.5, fontWeight: FontWeight.w900, color: subtitleColor, letterSpacing: 0.5),
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  Container(
                                                    width: 160,
                                                    height: 30,
                                                    decoration: BoxDecoration(
                                                      color: itemBg,
                                                      borderRadius: BorderRadius.circular(6),
                                                      border: Border.all(color: borderColor),
                                                    ),
                                                    child: TextField(
                                                      controller: barcodeController,
                                                      autofocus: false,
                                                      style: GoogleFonts.outfit(fontSize: 10.5, color: textColor, fontWeight: FontWeight.bold),
                                                      decoration: InputDecoration(
                                                        hintText: 'Scan / ketik barcode...',
                                                        hintStyle: GoogleFonts.outfit(fontSize: 9.5, color: subtitleColor.withOpacity(0.5)),
                                                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                                        border: InputBorder.none,
                                                        prefixIcon: Icon(Icons.qr_code_scanner_rounded, size: 14, color: subtitleColor),
                                                        prefixIconConstraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                                      ),
                                                      onSubmitted: (val) async {
                                                        final trimmed = val.trim();
                                                        if (trimmed.isEmpty || trimmed == drug.sku) return;
                                                        setDialogState(() => isSavingBarcode = true);
                                                        try {
                                                          await SupabaseService().updateMedicineBarcode(
                                                            medicineId: drug.id,
                                                            barcode: trimmed,
                                                          );
                                                          final updatedDrug = drug.copyWith(sku: trimmed);
                                                          setDialogState(() {
                                                            drug = updatedDrug;
                                                            isSavingBarcode = false;
                                                          });
                                                          ref.read(dokterObatListProvider.notifier).updateDrug(updatedDrug);
                                                          setState(() => _searchQuery = trimmed);
                                                          _showSuccessSnackBar(context, 'Barcode berhasil diperbarui!');
                                                        } catch (_) {
                                                          setDialogState(() => isSavingBarcode = false);
                                                          barcodeController.text = drug.sku;
                                                        }
                                                      },
                                                    ),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  isSavingBarcode
                                                      ? const SizedBox(
                                                          width: 20,
                                                          height: 20,
                                                          child: CircularProgressIndicator(strokeWidth: 2),
                                                        )
                                                      : InkWell(
                                                          borderRadius: BorderRadius.circular(6),
                                                          onTap: () async {
                                                            final trimmed = barcodeController.text.trim();
                                                            if (trimmed.isEmpty || trimmed == drug.sku) return;
                                                            setDialogState(() => isSavingBarcode = true);
                                                            try {
                                                              await SupabaseService().updateMedicineBarcode(
                                                                medicineId: drug.id,
                                                                barcode: trimmed,
                                                              );
                                                              final updatedDrug = drug.copyWith(sku: trimmed);
                                                              setDialogState(() {
                                                                drug = updatedDrug;
                                                                isSavingBarcode = false;
                                                              });
                                                              ref.read(dokterObatListProvider.notifier).updateDrug(updatedDrug);
                                                              setState(() => _searchQuery = trimmed);
                                                              _showSuccessSnackBar(context, 'Barcode berhasil diperbarui!');
                                                            } catch (_) {
                                                              setDialogState(() => isSavingBarcode = false);
                                                              barcodeController.text = drug.sku;
                                                            }
                                                          },
                                                          child: Container(
                                                            width: 28,
                                                            height: 28,
                                                            decoration: BoxDecoration(
                                                              color: purple.withOpacity(0.12),
                                                              borderRadius: BorderRadius.circular(6),
                                                            ),
                                                            child: Icon(Icons.check_rounded, size: 14, color: purple),
                                                          ),
                                                        ),
                                                ],
                                              ),
                                            ],
                                          ),
                                          const SizedBox(width: 20),
                                          _buildDetailGridCell('HARGA SATUAN'.tr(state), drug.hargaSatuan == 0 ? 'Rp 0' : 'Rp ${_formatPrice(drug.hargaSatuan)}', subtitleColor, textColor),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          _buildDetailGridCell('TOTAL STOK'.tr(state), '${_formatStock(drug.totalStok)} Tablet', subtitleColor, textColor),
                                          const SizedBox(width: 20),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text('STATUS'.tr(state), style: GoogleFonts.outfit(fontSize: 7.5, fontWeight: FontWeight.w900, color: subtitleColor, letterSpacing: 0.5)),
                                              const SizedBox(height: 3),
                                              _buildStatusBadge(drug.status),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // 2. BATCH & STOK section
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildModalSectionHeader('BATCH & STOK'.tr(state), purple),
                              TextButton.icon(
                                icon: const Icon(Icons.add_rounded, size: 12),
                                label: Text(
                                  'TAMBAH BATCH BARU'.tr(state),
                                  style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w900, color: purple),
                                ),
                                onPressed: () {
                                  _showRestockModal(context, drug, isDark, onRestockSuccess: (updatedDrug) {
                                    setDialogState(() {
                                      drug = updatedDrug;
                                      // Reinitialize opname controller for new batches
                                      for (final batch in drug.batches) {
                                        opnameControllers.putIfAbsent(batch.batchNo, () => TextEditingController());
                                      }
                                    });
                                    // Refresh parent
                                    ref.read(dokterObatListProvider.notifier).updateDrug(drug);
                                  });
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: drug.batches.length,
                            itemBuilder: (context, i) {
                              final batch = drug.batches[i];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: cardBg,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: borderColor),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('BATCH NO.'.tr(state), style: GoogleFonts.outfit(fontSize: 7.5, fontWeight: FontWeight.w900, color: subtitleColor)),
                                        Text(batch.batchNo, style: GoogleFonts.outfit(fontSize: 10.5, fontWeight: FontWeight.bold, color: textColor)),
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('LOKASI'.tr(state), style: GoogleFonts.outfit(fontSize: 7.5, fontWeight: FontWeight.w900, color: subtitleColor)),
                                        Text(batch.lokasi.isEmpty ? '-' : batch.lokasi, style: GoogleFonts.outfit(fontSize: 10.5, fontWeight: FontWeight.bold, color: textColor)),
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('KEDALUWARSA'.tr(state), style: GoogleFonts.outfit(fontSize: 7.5, fontWeight: FontWeight.w900, color: subtitleColor)),
                                        Text(batch.expDate, style: GoogleFonts.outfit(fontSize: 10.5, fontWeight: FontWeight.bold, color: textColor)),
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text('STOK'.tr(state), style: GoogleFonts.outfit(fontSize: 7.5, fontWeight: FontWeight.w900, color: subtitleColor)),
                                        Text('${_formatStock(batch.stok)} Tab', style: GoogleFonts.outfit(fontSize: 10.5, fontWeight: FontWeight.w900, color: textColor)),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),

                          const SizedBox(height: 20),

                          // 3. OPNAME STOK form
                          _buildModalSectionHeader('OPNAME STOK'.tr(state), purple),
                          const SizedBox(height: 4),
                          Text(
                            'Masukkan jumlah stok fisik hasil penghitungan di lapangan.'.tr(state),
                            style: GoogleFonts.outfit(fontSize: 10.5, color: subtitleColor, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: borderColor),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(flex: 3, child: _buildOpnameHeader('BATCH NO.'.tr(state), subtitleColor)),
                                    Expanded(flex: 2, child: _buildOpnameHeader('STOK SISTEM'.tr(state), subtitleColor)),
                                    Expanded(flex: 2, child: _buildOpnameHeader('STOK FISIK'.tr(state), subtitleColor)),
                                    Expanded(flex: 2, child: _buildOpnameHeader('SELISIH'.tr(state), subtitleColor)),
                                  ],
                                ),
                                const Divider(height: 16),
                                ...drug.batches.map((batch) {
                                  final controller = opnameControllers.putIfAbsent(batch.batchNo, () => TextEditingController());
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 6),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          flex: 3,
                                          child: Text(batch.batchNo, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: textColor)),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Text('${batch.stok}', style: GoogleFonts.outfit(fontSize: 11, color: textColor, fontWeight: FontWeight.bold)),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Container(
                                            height: 32,
                                            margin: const EdgeInsets.only(right: 8),
                                            child: TextField(
                                              controller: controller,
                                              keyboardType: TextInputType.number,
                                              onChanged: (val) {
                                                setDialogState(() {});
                                              },
                                              style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: textColor),
                                              decoration: InputDecoration(
                                                hintText: '0',
                                                hintStyle: GoogleFonts.outfit(fontSize: 11, color: subtitleColor.withOpacity(0.4)),
                                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                                filled: true,
                                                fillColor: itemBg,
                                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: borderColor)),
                                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: borderColor)),
                                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: purple)),
                                              ),
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: Builder(
                                            builder: (context) {
                                              final inputVal = int.tryParse(controller.text) ?? batch.stok;
                                              final difference = inputVal - batch.stok;
                                              final Color diffCol = difference == 0 ? textColor : (difference > 0 ? green : Colors.redAccent);
                                              final prefix = difference > 0 ? '+' : '';
                                              return Text(
                                                '$prefix$difference',
                                                style: GoogleFonts.outfit(fontSize: 11, color: diffCol, fontWeight: FontWeight.w900),
                                              );
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    ElevatedButton.icon(
                                      icon: const Icon(Icons.check_rounded, size: 14),
                                      label: Text('Simpan Opname'.tr(state), style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: purple,
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      ),
                                      onPressed: () {
                                        // Process Opname
                                        List<BatchModel> updatedBatches = [];
                                        List<OpnameLog> newLogs = List.from(drug.opnameLogs);
                                        int totalNewStock = 0;

                                        for (final batch in drug.batches) {
                                          final controller = opnameControllers.putIfAbsent(batch.batchNo, () => TextEditingController());
                                          final parsedFisik = int.tryParse(controller.text) ?? batch.stok;
                                          final selisih = parsedFisik - batch.stok;

                                          updatedBatches.add(batch.copyWith(stok: parsedFisik));
                                          totalNewStock += parsedFisik;

                                          if (selisih != 0) {
                                            newLogs.add(OpnameLog(
                                              batchNo: batch.batchNo,
                                              stokSistem: batch.stok,
                                              stokFisik: parsedFisik,
                                              selisih: selisih,
                                              date: '26 Mei 2026',
                                            ));
                                          }
                                        }

                                        final updatedDrug = drug.copyWith(
                                          batches: updatedBatches,
                                          totalStok: totalNewStock,
                                          status: totalNewStock <= 5 ? 'Stok Minim' : 'Tersedia',
                                          opnameLogs: newLogs,
                                        );

                                        setDialogState(() {
                                          drug = updatedDrug;
                                          // Clear controllers inputs
                                          for (final controller in opnameControllers.values) {
                                            controller.clear();
                                          }
                                        });

                                        ref.read(dokterObatListProvider.notifier).updateDrug(drug);
                                        _showSuccessSnackBar(context, 'Hasil stok opname berhasil disimpan!'.tr(state));
                                      },
                                    ),
                                    const SizedBox(width: 8),
                                    OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        side: BorderSide(color: borderColor),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      ),
                                      child: Text('Reset'.tr(state), style: GoogleFonts.outfit(fontSize: 10, color: subtitleColor, fontWeight: FontWeight.bold)),
                                      onPressed: () {
                                        setDialogState(() {
                                          for (final controller in opnameControllers.values) {
                                            controller.clear();
                                          }
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // 4. RIWAYAT OPNAME section
                          _buildModalSectionHeader('RIWAYAT OPNAME'.tr(state), purple),
                          const SizedBox(height: 8),
                          drug.opnameLogs.isEmpty
                              ? Text(
                                  'Belum ada riwayat opname untuk obat ini.'.tr(state),
                                  style: GoogleFonts.outfit(fontSize: 11, color: subtitleColor, fontStyle: FontStyle.italic, fontWeight: FontWeight.w500),
                                )
                              : ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: drug.opnameLogs.length,
                                  itemBuilder: (context, idx) {
                                    final log = drug.opnameLogs[idx];
                                    final Color diffCol = log.selisih > 0 ? green : Colors.redAccent;
                                    final sign = log.selisih > 0 ? '+' : '';
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 6),
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: itemBg,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(log.date, style: GoogleFonts.outfit(fontSize: 10, color: subtitleColor, fontWeight: FontWeight.bold)),
                                          Text('Batch ${log.batchNo}', style: GoogleFonts.outfit(fontSize: 10, color: textColor, fontWeight: FontWeight.bold)),
                                          Text('Sistem: ${log.stokSistem} | Fisik: ${log.stokFisik}', style: GoogleFonts.outfit(fontSize: 10, color: subtitleColor)),
                                          Text(
                                            'Selisih: $sign${log.selisih}',
                                            style: GoogleFonts.outfit(fontSize: 10, color: diffCol, fontWeight: FontWeight.w900),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),

                          const SizedBox(height: 20),

                          // 5. AKSI section
                          _buildModalSectionHeader('AKSI'.tr(state), purple),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              ElevatedButton.icon(
                                icon: const Icon(Icons.sync_rounded, size: 14),
                                label: Text('Restock'.tr(state), style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: purple,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                                onPressed: () {
                                  _showRestockModal(context, drug, isDark, onRestockSuccess: (updatedDrug) {
                                    setDialogState(() {
                                      drug = updatedDrug;
                                      // Reinitialize opname controller for new batches
                                      for (final batch in drug.batches) {
                                        opnameControllers.putIfAbsent(batch.batchNo, () => TextEditingController());
                                      }
                                    });
                                    ref.read(dokterObatListProvider.notifier).updateDrug(drug);
                                  });
                                },
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                icon: const Icon(Icons.sell_outlined, size: 14),
                                label: Text('Ubah Harga'.tr(state), style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900)),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: borderColor),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                                onPressed: () {
                                  _showPriceUpdateDialog(context, drug, isDark, onPriceUpdate: (updatedDrug) {
                                    setDialogState(() {
                                      drug = updatedDrug;
                                    });
                                    ref.read(dokterObatListProvider.notifier).updateDrug(drug);
                                  });
                                },
                              ),
                              const Spacer(),
                              OutlinedButton.icon(
                                icon: const Icon(Icons.delete_outline_rounded, size: 14),
                                label: Text('Hapus Obat'.tr(state), style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900)),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.redAccent,
                                  side: const BorderSide(color: Colors.redAccent),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                                onPressed: () {
                                  _showDeleteConfirm(context, drug);
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // --- Footer ---
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: borderColor)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: borderColor),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                          child: Text(
                            'Tutup'.tr(state),
                            style: GoogleFonts.outfit(fontSize: 11, color: subtitleColor, fontWeight: FontWeight.w900),
                          ),
                          onPressed: () => Navigator.of(ctx).pop(),
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
    );
  }

  Widget _buildModalSectionHeader(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 12,
          margin: const EdgeInsets.only(right: 6),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
        ),
        Text(
          label,
          style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w900, color: color, letterSpacing: 0.5),
        ),
      ],
    );
  }

  Widget _buildDetailGridCell(String label, String value, Color subtitleCol, Color textCol) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(fontSize: 7.5, fontWeight: FontWeight.w900, color: subtitleCol, letterSpacing: 0.5),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.outfit(fontSize: 11.5, color: textCol, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildOpnameHeader(String text, Color col) {
    return Text(
      text,
      style: GoogleFonts.outfit(fontSize: 7.5, fontWeight: FontWeight.w900, color: col),
    );
  }

  // ─── Sub-Modal: Restock ───────────────────────────────────────────────────

  void _showRestockModal(
    BuildContext context,
    ObatModel drug,
    bool isDark, {
    required Function(ObatModel) onRestockSuccess,
  }) {
    final state = ref.read(landingPageProvider);
    final isEn = state.language == 'en';
    final purple = ref.read(landingPageProvider.notifier).getPrimaryColor();
    final cardBg = isDark ? const Color(0xFF161619) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1B0C3C);
    final subtitleColor = isDark ? Colors.grey[400]! : const Color(0xFF6F6A8A);
    final borderColor = isDark ? const Color(0xFF252528) : const Color(0xFFECEEF2);
    final inputBg = isDark ? const Color(0xFF1E1E22) : const Color(0xFFF6F8FA);

    final formKey = GlobalKey<FormState>();
    final stockController = TextEditingController(text: '0');
    final batchController = TextEditingController(text: _generateBatchNo(offset: drug.batches.length * 12));
    final expController = TextEditingController();
    final locationController = TextEditingController();
    final totalBuyController = TextEditingController();
    final sellPriceController = TextEditingController(text: formatPrice(drug.hargaSatuan));

    double hargaBeliSatuanVal = 0.0;

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.4),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return Dialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
            backgroundColor: Colors.transparent,
            child: Container(
              width: 440,
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 40,
                    offset: const Offset(0, 16),
                  )
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // --- Header ---
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      color: isDark ? const Color(0xFF1A1A1E) : const Color(0xFFF8F5FF),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: purple.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: Icon(Icons.sync_rounded, color: purple, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Restock'.tr(state),
                                  style: GoogleFonts.outfit(
                                      fontSize: 15, fontWeight: FontWeight.w900, color: textColor),
                                ),
                                Text(
                                  'Tambah batch kedaluwarsa baru untuk ${drug.nama}.'.tr(state),
                                  style: GoogleFonts.outfit(fontSize: 10, color: subtitleColor),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () => Navigator.of(ctx).pop(),
                          ),
                        ],
                      ),
                    ),

                    // --- Scrollable Form ---
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildFormFieldLabel('Jumlah Stok Masuk (Tablet)'.tr(state), textColor),
                                      _buildTextInput(
                                        stockController,
                                        '0',
                                        Icons.add_box_outlined,
                                        inputBg,
                                        borderColor,
                                        textColor,
                                        subtitleColor,
                                        keyboardType: TextInputType.number,
                                        onChanged: (val) {
                                          final stock = double.tryParse(val) ?? 0;
                                          final total = double.tryParse(totalBuyController.text) ?? 0;
                                          setDialogState(() {
                                            hargaBeliSatuanVal = stock > 0 ? (total / stock) : 0.0;
                                          });
                                        },
                                        validator: (v) => (int.tryParse(v ?? '') ?? 0) <= 0
                                            ? (isEn ? 'Required (> 0)' : 'Wajib diisi (> 0)')
                                            : null,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildFormFieldLabel('Tanggal Kedaluwarsa'.tr(state), textColor),
                                      _buildDateInput(
                                        ctx,
                                        expController,
                                        'Pilih tanggal...'.tr(state),
                                        inputBg,
                                        borderColor,
                                        textColor,
                                        subtitleColor,
                                        setDialogState,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFormFieldLabel('Nomor Batch'.tr(state), textColor),
                                _buildTextInput(
                                  batchController,
                                  'Bxxxxxx...'.tr(state),
                                  Icons.tag_rounded,
                                  inputBg,
                                  borderColor,
                                  textColor,
                                  subtitleColor,
                                  validator: (v) => v!.isEmpty ? (isEn ? 'Batch number required' : 'Nomor batch wajib') : null,
                                  readOnly: true,
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFormFieldLabel('Lokasi Penyimpanan'.tr(state), textColor),
                                _buildTextInput(
                                  locationController,
                                  'cth. Rak A-1'.tr(state),
                                  Icons.location_on_outlined,
                                  inputBg,
                                  borderColor,
                                  textColor,
                                  subtitleColor,
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildFormFieldLabel('Total Harga Beli'.tr(state), textColor),
                                      _buildTextInput(
                                        totalBuyController,
                                        'Rp 0',
                                        Icons.attach_money_rounded,
                                        inputBg,
                                        borderColor,
                                        textColor,
                                        subtitleColor,
                                        keyboardType: TextInputType.number,
                                        onChanged: (val) {
                                          final total = double.tryParse(val) ?? 0;
                                          final stock = double.tryParse(stockController.text) ?? 0;
                                          setDialogState(() {
                                            hargaBeliSatuanVal = stock > 0 ? (total / stock) : 0.0;
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildFormFieldLabel('Harga Beli Satuan (Hasil Kalkulasi)'.tr(state), textColor),
                                      Container(
                                        height: 44,
                                        padding: const EdgeInsets.symmetric(horizontal: 12),
                                        decoration: BoxDecoration(
                                          color: isDark ? const Color(0xFF1E1E22) : const Color(0xFFECEEF2),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: borderColor),
                                        ),
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          'Rp ${hargaBeliSatuanVal.toInt()}',
                                          style: GoogleFonts.outfit(
                                              fontSize: 12, fontWeight: FontWeight.w900, color: subtitleColor),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFormFieldLabel('Harga Jual Satuan'.tr(state), textColor),
                                _buildTextInput(
                                  sellPriceController,
                                  'Rp 0',
                                  Icons.attach_money_rounded,
                                  inputBg,
                                  borderColor,
                                  textColor,
                                  subtitleColor,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [ThousandsFormatter()],
                                  validator: (v) => v!.isEmpty ? (isEn ? 'Sale price is required' : 'Harga jual wajib diisi') : null,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    // --- Bottom Actions ---
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        border: Border(top: BorderSide(color: borderColor)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: borderColor),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            ),
                            child: Text('Batal'.tr(state), style: GoogleFonts.outfit(fontSize: 11, color: subtitleColor, fontWeight: FontWeight.bold)),
                            onPressed: () => Navigator.of(ctx).pop(),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: purple,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                            ),
                            child: Text('Tambah Stok'.tr(state), style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900)),
                            onPressed: () {
                              if (formKey.currentState!.validate()) {
                                final priceSell = parseFormattedPrice(sellPriceController.text);
                                final priceBuyTotal = parseFormattedPrice(totalBuyController.text);
                                final stockIn = int.parse(stockController.text);
                                final buyUnitPrice = stockIn > 0 ? (priceBuyTotal / stockIn) : 0.0;

                                final newBatch = BatchModel(
                                  batchNo: batchController.text,
                                  stok: stockIn,
                                  expDate: expController.text.isEmpty ? '26 / 05 / 2028' : expController.text,
                                  lokasi: locationController.text.isEmpty ? 'Rak A-1' : locationController.text,
                                  hargaBeli: buyUnitPrice,
                                  hargaJual: priceSell,
                                );

                                final updatedBatches = List<BatchModel>.from(drug.batches)..add(newBatch);
                                final newTotalStock = drug.totalStok + stockIn;

                                final updatedDrug = drug.copyWith(
                                  batches: updatedBatches,
                                  totalStok: newTotalStock,
                                  hargaSatuan: priceSell,
                                  status: newTotalStock <= 5 ? 'Stok Minim' : 'Tersedia',
                                );

                                Navigator.of(ctx).pop();
                                onRestockSuccess(updatedDrug);
                                _showSuccessSnackBar(context, 'Stok obat berhasil ditambahkan!'.tr(state));
                              }
                            },
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
      ),
    );
  }

  // ─── Modal: Tambah Obat Baru ──────────────────────────────────────────────

  void _showAddDrugModal(BuildContext context, bool isDark) {
    final state = ref.read(landingPageProvider);
    final isEn = state.language == 'en';
    final purple = ref.read(landingPageProvider.notifier).getPrimaryColor();
    final cardBg = isDark ? const Color(0xFF161619) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1B0C3C);
    final subtitleColor = isDark ? Colors.grey[400]! : const Color(0xFF6F6A8A);
    final borderColor = isDark ? const Color(0xFF252528) : const Color(0xFFECEEF2);
    final inputBg = isDark ? const Color(0xFF1E1E22) : const Color(0xFFF6F8FA);

    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final skuController = TextEditingController();
    final batchController = TextEditingController(text: _generateBatchNo());
    final initialStockController = TextEditingController(text: '0');
    final buyPriceController = TextEditingController(text: '0');
    final sellPriceController = TextEditingController(text: '0');
    final expController = TextEditingController();
    final locationController = TextEditingController();

    String typeSelection = 'Pilih Jenis / Generic';
    String unitSelection = 'Pilih Satuan';
    double hargaBeliSatuanVal = 0.0;
    String? selectedKfaCode;

    final isMobile = MediaQuery.of(context).size.width < 650;

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.4),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return Dialog(
            insetPadding: EdgeInsets.symmetric(
              horizontal: isMobile ? 12 : (MediaQuery.of(context).size.width - 600) / 2,
              vertical: 24,
            ),
            backgroundColor: Colors.transparent,
            child: Container(
              width: 600,
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 40,
                    offset: const Offset(0, 16),
                  )
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // --- Header ---
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      color: isDark ? const Color(0xFF1A1A1E) : const Color(0xFFF8F5FF),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: purple.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: Icon(Icons.add_box_outlined, color: purple, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Tambah Obat Baru'.tr(state),
                                  style: GoogleFonts.outfit(
                                      fontSize: 15, fontWeight: FontWeight.w900, color: textColor),
                                ),
                                Text(
                                  'Isi data obat beserta informasi batch awal.'.tr(state),
                                  style: GoogleFonts.outfit(fontSize: 10, color: subtitleColor),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () => Navigator.of(ctx).pop(),
                          ),
                        ],
                      ),
                    ),

                    // --- Form Scroll Panel ---
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // CARI DARI KATALOG SATUSEHAT KFA
                            _buildModalSectionHeader('CARI DARI KATALOG SATUSEHAT KFA'.tr(state), purple),
                            const SizedBox(height: 3),
                            Text(
                              'Opsional — isi otomatis nama, bentuk & kode KFA'.tr(state),
                              style: GoogleFonts.outfit(fontSize: 9, color: subtitleColor, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 10),

                            // Badge shown when a KFA product is selected
                            if (selectedKfaCode != null)
                              Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: purple.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: purple.withOpacity(0.3)),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.verified_rounded, size: 14, color: purple),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '${nameController.text}  •  KFA: $selectedKfaCode',
                                        style: GoogleFonts.outfit(fontSize: 10.5, color: purple, fontWeight: FontWeight.w700),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () => setDialogState(() {
                                        selectedKfaCode = null;
                                        nameController.clear();
                                        skuController.clear();
                                      }),
                                      child: Icon(Icons.close_rounded, size: 14, color: purple),
                                    ),
                                  ],
                                ),
                              ),

                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                icon: Icon(Icons.search_rounded, size: 16, color: purple),
                                label: Text(
                                  selectedKfaCode != null
                                      ? 'Ganti dari Katalog KFA'.tr(state)
                                      : 'Cari dari Katalog KFA'.tr(state),
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    color: purple,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: BorderSide(color: purple.withOpacity(0.5)),
                                  backgroundColor: purple.withOpacity(0.05),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                ),
                                onPressed: () async {
                                  final result = await _showKfaSearchModal(context, isDark);
                                  if (result != null) {
                                    setDialogState(() {
                                      nameController.text = result['nama'] ?? '';
                                      skuController.text = 'KFA-${result['code'] ?? ''}';
                                      selectedKfaCode = result['code'];
                                      final typeStr = (result['jenis'] ?? '').toLowerCase();
                                      if (typeStr.contains('generik') || typeStr.contains('generic')) {
                                        typeSelection = 'Generik';
                                      } else if (typeStr.contains('paten')) {
                                        typeSelection = 'Paten';
                                      } else {
                                        typeSelection = 'Umum';
                                      }
                                      final uomStr = (result['satuan'] ?? '').toLowerCase();
                                      if (uomStr.contains('tablet') || uomStr.contains('tab')) {
                                        unitSelection = 'Tablet';
                                      } else if (uomStr.contains('kapsul') || uomStr.contains('cap')) {
                                        unitSelection = 'Kapsul';
                                      } else if (uomStr.contains('botol') || uomStr.contains('btl')) {
                                        unitSelection = 'Botol';
                                      } else if (uomStr.contains('tube') || uomStr.contains('tub')) {
                                        unitSelection = 'Tube';
                                      } else if (uomStr.contains('pcs') || uomStr.contains('pieces')) {
                                        unitSelection = 'Pcs';
                                      } else {
                                        unitSelection = 'Tablet';
                                      }
                                    });
                                  }
                                },
                              ),
                            ),

                            const SizedBox(height: 20),

                            // INFORMASI UMUM
                            _buildModalSectionHeader('INFORMASI UMUM'.tr(state), purple),
                            const SizedBox(height: 10),

                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFormFieldLabel('Nama Obat'.tr(state), textColor),
                                _buildTextInput(
                                  nameController,
                                  'cth. Paracetamol 500mg'.tr(state),
                                  Icons.medication_outlined,
                                  inputBg,
                                  borderColor,
                                  textColor,
                                  subtitleColor,
                                  validator: (v) => v!.isEmpty ? (isEn ? 'Drug name is required' : 'Nama obat wajib diisi') : null,
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildFormFieldLabel('SKU / Barcode'.tr(state), textColor),
                                      _buildTextInput(
                                        skuController,
                                        'cth. 8993601452'.tr(state),
                                        Icons.qr_code_scanner_rounded,
                                        inputBg,
                                        borderColor,
                                        textColor,
                                        subtitleColor,
                                        validator: (v) => v!.isEmpty ? (isEn ? 'SKU required' : 'SKU wajib') : null,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildFormFieldLabel('Jenis'.tr(state), textColor),
                                      Container(
                                        height: 44,
                                        padding: const EdgeInsets.symmetric(horizontal: 12),
                                        decoration: BoxDecoration(
                                          color: inputBg,
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: borderColor),
                                        ),
                                        child: DropdownButtonHideUnderline(
                                          child: DropdownButton<String>(
                                            value: typeSelection == 'Pilih Jenis / Generic' ? null : typeSelection,
                                            hint: Text(typeSelection, style: GoogleFonts.outfit(fontSize: 12, color: subtitleColor.withOpacity(0.5))),
                                            dropdownColor: cardBg,
                                            icon: Icon(Icons.arrow_drop_down_rounded, color: subtitleColor),
                                            isExpanded: true,
                                            style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: textColor),
                                            items: ['Generik', 'Paten', 'Umum'].map((g) => DropdownMenuItem(value: g, child: Text(g.tr(state)))).toList(),
                                            onChanged: (val) {
                                              if (val != null) {
                                                setDialogState(() {
                                                  typeSelection = val;
                                                });
                                              }
                                            },
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFormFieldLabel('Satuan'.tr(state), textColor),
                                Container(
                                  height: 44,
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: inputBg,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: borderColor),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: unitSelection == 'Pilih Satuan' ? null : unitSelection,
                                      hint: Text(unitSelection, style: GoogleFonts.outfit(fontSize: 12, color: subtitleColor.withOpacity(0.5))),
                                      dropdownColor: cardBg,
                                      icon: Icon(Icons.arrow_drop_down_rounded, color: subtitleColor),
                                      isExpanded: true,
                                      style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: textColor),
                                      items: ['Tablet', 'Kapsul', 'Botol', 'Tube', 'Pcs'].map((u) => DropdownMenuItem(value: u, child: Text(u.tr(state)))).toList(),
                                      onChanged: (val) {
                                        if (val != null) {
                                          setDialogState(() {
                                            unitSelection = val;
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 20),

                            // BATCH AWAL
                            _buildModalSectionHeader('BATCH AWAL'.tr(state), purple),
                            const SizedBox(height: 10),

                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildFormFieldLabel('Nomor Batch'.tr(state), textColor),
                                      _buildTextInput(
                                        batchController,
                                        'Bxxxxxx...'.tr(state),
                                        Icons.tag_rounded,
                                        inputBg,
                                        borderColor,
                                        textColor,
                                        subtitleColor,
                                        validator: (v) => v!.isEmpty ? (isEn ? 'Batch number required' : 'Nomor batch wajib') : null,
                                        readOnly: true,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildFormFieldLabel('Stok Awal'.tr(state), textColor),
                                      _buildTextInput(
                                        initialStockController,
                                        '0',
                                        Icons.add_box_outlined,
                                        inputBg,
                                        borderColor,
                                        textColor,
                                        subtitleColor,
                                        keyboardType: TextInputType.number,
                                        onChanged: (val) {
                                          final stock = double.tryParse(val) ?? 0;
                                          final total = parseFormattedPrice(buyPriceController.text);
                                          setDialogState(() {
                                            hargaBeliSatuanVal = stock > 0 ? (total / stock) : 0.0;
                                          });
                                        },
                                        validator: (v) => v!.isEmpty ? (isEn ? 'Required' : 'Wajib') : null,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildFormFieldLabel('Total Harga Beli (Modal)'.tr(state), textColor),
                                      _buildTextInput(
                                        buyPriceController,
                                        'Rp 0',
                                        Icons.attach_money_rounded,
                                        inputBg,
                                        borderColor,
                                        textColor,
                                        subtitleColor,
                                        keyboardType: TextInputType.number,
                                        inputFormatters: [ThousandsFormatter()],
                                        onChanged: (val) {
                                          final total = parseFormattedPrice(val);
                                          final stock = double.tryParse(initialStockController.text) ?? 0;
                                          setDialogState(() {
                                            hargaBeliSatuanVal = stock > 0 ? (total / stock) : 0.0;
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildFormFieldLabel('Harga Beli Satuan (Hasil Kalkulasi)'.tr(state), textColor),
                                      Container(
                                        height: 44,
                                        padding: const EdgeInsets.symmetric(horizontal: 12),
                                        decoration: BoxDecoration(
                                          color: isDark ? const Color(0xFF1E1E22) : const Color(0xFFECEEF2),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: borderColor),
                                        ),
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          'Rp ${formatPrice(hargaBeliSatuanVal)}',
                                          style: GoogleFonts.outfit(
                                              fontSize: 12, fontWeight: FontWeight.w900, color: subtitleColor),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildFormFieldLabel('Harga Jual Satuan'.tr(state), textColor),
                                      _buildTextInput(
                                        sellPriceController,
                                        'Rp 0',
                                        Icons.attach_money_rounded,
                                        inputBg,
                                        borderColor,
                                        textColor,
                                        subtitleColor,
                                        keyboardType: TextInputType.number,
                                        inputFormatters: [ThousandsFormatter()],
                                        validator: (v) => v!.isEmpty ? (isEn ? 'Selling price is required' : 'Harga jual wajib diisi') : null,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildFormFieldLabel('Tanggal Kedaluwarsa'.tr(state), textColor),
                                      _buildDateInput(
                                        ctx,
                                        expController,
                                        'Pilih tanggal...'.tr(state),
                                        inputBg,
                                        borderColor,
                                        textColor,
                                        subtitleColor,
                                        setDialogState,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFormFieldLabel('Lokasi Penyimpanan', textColor),
                                _buildTextInput(
                                  locationController,
                                  'cth. Shelf A-01',
                                  Icons.location_on_outlined,
                                  inputBg,
                                  borderColor,
                                  textColor,
                                  subtitleColor,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    // --- Bottom Actions ---
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        border: Border(top: BorderSide(color: borderColor)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: borderColor),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            ),
                            child: Text('Batal'.tr(state), style: GoogleFonts.outfit(fontSize: 11, color: subtitleColor, fontWeight: FontWeight.bold)),
                            onPressed: () => Navigator.of(ctx).pop(),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: purple,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                            ),
                            child: Text('Simpan Obat'.tr(state), style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900)),
                            onPressed: () {
                              if (formKey.currentState!.validate()) {
                                if (typeSelection == 'Pilih Jenis / Generic' || unitSelection == 'Pilih Satuan') {
                                  _showSuccessSnackBar(context, isEn ? 'Please select drug type and unit!' : 'Harap pilih jenis dan satuan obat!');
                                  return;
                                }

                                final priceSell = parseFormattedPrice(sellPriceController.text);
                                final priceBuyTotal = parseFormattedPrice(buyPriceController.text);
                                final stok = int.parse(initialStockController.text);
                                final unitCost = stok > 0 ? (priceBuyTotal / stok) : 0.0;

                                final initialBatch = BatchModel(
                                  batchNo: batchController.text,
                                  stok: stok,
                                  expDate: expController.text.isEmpty ? '26 / 05 / 2028' : expController.text,
                                  lokasi: locationController.text.isEmpty ? 'Shelf A-01' : locationController.text,
                                  hargaBeli: unitCost,
                                  hargaJual: priceSell,
                                );

                                final randomId = _generateUuidV4();
                                final newDrug = ObatModel(
                                  id: randomId,
                                  nama: nameController.text,
                                  jenis: typeSelection,
                                  sku: skuController.text,
                                  hargaSatuan: priceSell,
                                  totalStok: stok,
                                  status: stok <= 5 ? (isEn ? 'Low Stock' : 'Stok Minim') : (isEn ? 'Available' : 'Tersedia'),
                                  avatarBg: typeSelection == 'Generik' ? const Color(0xFF48C9B0) : const Color(0xFFB577F2),
                                  batches: [initialBatch],
                                );

                                Navigator.of(ctx).pop();
                                ref.read(dokterObatListProvider.notifier).addDrug(newDrug);
                                _showSuccessSnackBar(context, isEn ? 'New drug successfully saved!' : 'Obat baru berhasil disimpan!');
                              }
                            },
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
      ),
    );
  }

  // ─── Modal Sub-Actions (Price Update & Delete Confirm) ─────────────────────

  void _showPriceUpdateDialog(
    BuildContext context,
    ObatModel drug,
    bool isDark, {
    required Function(ObatModel) onPriceUpdate,
  }) {
    final purple = ref.read(landingPageProvider.notifier).getPrimaryColor();
    final cardBg = isDark ? const Color(0xFF161619) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1B0C3C);
    final subtitleColor = isDark ? Colors.grey[400]! : const Color(0xFF6F6A8A);
    final borderColor = isDark ? const Color(0xFF252528) : const Color(0xFFECEEF2);
    final inputBg = isDark ? const Color(0xFF1E1E22) : const Color(0xFFF6F8FA);

    final formKey = GlobalKey<FormState>();
    final controller = TextEditingController(text: formatPrice(drug.hargaSatuan));

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.3),
      builder: (ctx) => AlertDialog(
        backgroundColor: cardBg,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Ubah Harga Satuan',
          style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w900, color: textColor),
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Perbarui harga jual eceran satuan untuk ${drug.nama}.',
                style: GoogleFonts.outfit(fontSize: 11, color: subtitleColor, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 14),
              _buildTextInput(
                controller,
                'Rp 0',
                Icons.attach_money_rounded,
                inputBg,
                borderColor,
                textColor,
                subtitleColor,
                keyboardType: TextInputType.number,
                inputFormatters: [ThousandsFormatter()],
                validator: (v) => v!.isEmpty ? 'Harga wajib diisi' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Batal', style: GoogleFonts.outfit(fontSize: 11, color: subtitleColor, fontWeight: FontWeight.w900)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: purple,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                final newPrice = parseFormattedPrice(controller.text);
                final updatedDrug = drug.copyWith(hargaSatuan: newPrice);
                Navigator.of(ctx).pop();
                onPriceUpdate(updatedDrug);
                _showSuccessSnackBar(context, 'Harga obat berhasil diperbarui!');
              }
            },
            child: Text('Simpan', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirm(BuildContext context, ObatModel drug) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.3),
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Hapus Data Obat',
          style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w900, color: const Color(0xFF1B0C3C)),
        ),
        content: Text(
          'Apakah Anda yakin ingin menghapus data obat ${drug.nama}? Tindakan ini tidak dapat dibatalkan.',
          style: GoogleFonts.outfit(fontSize: 11.5, color: const Color(0xFF6F6A8A), fontWeight: FontWeight.w500),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Batal', style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFF6F6A8A), fontWeight: FontWeight.w900)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              // Delete drug
              ref.read(dokterObatListProvider.notifier).deleteDrug(drug.id);
              // Pop confirm dialog
              Navigator.of(ctx).pop();
              // Pop detail modal
              Navigator.of(context).pop();
              _showSuccessSnackBar(context, 'Data obat berhasil dihapus.');
            },
            child: Text('Ya, Hapus', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  // ─── Input Helper Widgets ──────────────────────────────────────────────────

  Widget _buildFormFieldLabel(String title, Color textCol) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 4),
      child: Text(
        title,
        style: GoogleFonts.outfit(
          fontSize: 9.5,
          fontWeight: FontWeight.w900,
          color: textCol.withOpacity(0.85),
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _buildTextInput(
    TextEditingController controller,
    String hint,
    IconData icon,
    Color bg,
    Color border,
    Color text,
    Color subtitle, {
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? Function(String?)? validator,
    Function(String)? onChanged,
    bool readOnly = false,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      onChanged: onChanged,
      readOnly: readOnly,
      inputFormatters: inputFormatters,
      style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: readOnly ? text.withOpacity(0.6) : text),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.outfit(fontSize: 11.5, color: subtitle.withOpacity(0.4)),
        prefixIcon: Icon(icon, size: 16, color: subtitle),
        filled: true,
        fillColor: bg,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: text.withOpacity(0.3), width: 1.5),
        ),
        errorStyle: GoogleFonts.outfit(fontSize: 9, height: 0.8),
      ),
    );
  }

  Widget _buildDateInput(
    BuildContext context,
    TextEditingController controller,
    String hint,
    Color bg,
    Color border,
    Color text,
    Color subtitle,
    StateSetter setDialogState,
  ) {
    return InkWell(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: DateTime.now().add(const Duration(days: 365)),
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 3650)),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: const ColorScheme.light(
                  primary: Color(0xFFB577F2),
                  onPrimary: Colors.white,
                  onSurface: Color(0xFF1B0C3C),
                ),
              ),
              child: child!,
            );
          },
        );
        if (date != null) {
          setDialogState(() {
            controller.text = '${date.day.toString().padLeft(2, '0')} / ${date.month.toString().padLeft(2, '0')} / ${date.year}';
          });
        }
      },
      child: IgnorePointer(
        child: _buildTextInput(
          controller,
          hint,
          Icons.calendar_month_outlined,
          bg,
          border,
          text,
          subtitle,
          validator: (v) => v!.isEmpty ? 'Wajib' : null,
        ),
      ),
    );
  }

  void _showSuccessSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF27AE60),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Text(
              message,
              style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  String _formatPrice(double value) {
    final str = value.toInt().toString();
    final buffer = StringBuffer();
    int count = 0;
    for (int i = str.length - 1; i >= 0; i--) {
      buffer.write(str[i]);
      count++;
      if (count % 3 == 0 && i > 0) {
        buffer.write('.');
      }
    }
    return buffer.toString().split('').reversed.join('');
  }

  String _formatStock(int stock) {
    final str = stock.toString();
    final buffer = StringBuffer();
    int count = 0;
    for (int i = str.length - 1; i >= 0; i--) {
      buffer.write(str[i]);
      count++;
      if (count % 3 == 0 && i > 0) {
        buffer.write('.');
      }
    }
    return buffer.toString().split('').reversed.join('');
  }

  // ─── KFA Search Modal ────────────────────────────────────────────────────────

  /// Opens a dedicated KFA search dialog. Returns the selected product map
  /// (keys: nama, code, jenis, satuan) or null if dismissed.
  Future<Map<String, dynamic>?> _showKfaSearchModal(
    BuildContext context,
    bool isDark,
  ) async {
    final state = ref.read(landingPageProvider);
    final purple = ref.read(landingPageProvider.notifier).getPrimaryColor();
    final cardBg = isDark ? const Color(0xFF161619) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1B0C3C);
    final subtitleColor = isDark ? Colors.grey[400]! : const Color(0xFF6F6A8A);
    final borderColor = isDark ? const Color(0xFF252528) : const Color(0xFFECEEF2);
    final inputBg = isDark ? const Color(0xFF1E1E22) : const Color(0xFFF6F8FA);

    final searchController = TextEditingController();
    List<Map<String, dynamic>> results = [];
    bool isLoading = false;
    String? errorMsg;

    return showDialog<Map<String, dynamic>>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          Future<void> doSearch() async {
            final keyword = searchController.text.trim();
            if (keyword.isEmpty) return;
            setState(() { isLoading = true; errorMsg = null; results = []; });

            try {
              final doctorId = ref.read(landingPageProvider).activeDoctorId ?? '';
              final docDetail = await SupabaseService.client
                  .from('user_detail_doctor')
                  .select('satu_sehat_api, id_satusehat')
                  .eq('id', doctorId)
                  .maybeSingle();

              final ssConfig = docDetail?['satu_sehat_api'] as Map<String, dynamic>?;
              if (ssConfig == null || ssConfig['client_id'] == null) {
                setState(() { errorMsg = 'Konfigurasi API SatuSehat belum lengkap.'; isLoading = false; });
                return;
              }

              // Get search results using the centralized searchKfaProducts method
              // which automatically handles direct/proxy fallback, CORS, and geo-blocking.
              final ssService = SatuSehatService(
                clientId: ssConfig['client_id']?.toString(),
                clientSecret: ssConfig['client_secret']?.toString(),
                organizationId: ssConfig['organization_id']?.toString(),
                locationId: ssConfig['location_id']?.toString() ?? docDetail?['id_satusehat']?.toString(),
                env: ssConfig['env']?.toString(),
              );

              final searchRes = await ssService.searchKfaProducts(keyword: keyword);
              if (searchRes['status'] != true) {
                setState(() { errorMsg = searchRes['message']?.toString() ?? 'Gagal mengambil data KFA.'; isLoading = false; });
                return;
              }

              final searchData = searchRes['data'];
              List<dynamic> dataList = [];
              if (searchData is Map) {
                if (searchData['items'] is Map && searchData['items']['data'] is List) {
                  dataList = searchData['items']['data'] as List;
                } else if (searchData['items'] is List) {
                  dataList = searchData['items'] as List;
                } else if (searchData['data'] is List) {
                  dataList = searchData['data'] as List;
                }
              } else if (searchData is List) {
                dataList = searchData;
              }

              final mapped = dataList.map<Map<String, dynamic>>((e) => {
                'nama': e['name']?.toString() ?? '',
                'code': e['kfa_code']?.toString() ?? '',
                'jenis': e['farmalkes_type']?['name']?.toString() ?? 'Generik',
                'satuan': e['uom']?['name']?.toString() ?? 'Tablet',
              }).toList();

              setState(() {
                results = mapped;
                errorMsg = mapped.isEmpty ? 'Produk tidak ditemukan.' : null;
                isLoading = false;
              });
            } catch (e) {
              setState(() { errorMsg = 'Error: $e'; isLoading = false; });
            }
          }

          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Container(
              width: 560,
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.82,
              ),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 40,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [purple.withOpacity(0.12), purple.withOpacity(0.04)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: purple.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Icon(Icons.medication_liquid_rounded, color: purple, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Katalog KFA SatuSehat'.tr(state),
                                style: GoogleFonts.outfit(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  color: textColor,
                                ),
                              ),
                              Text(
                                'Cari obat dari database resmi Kemenkes'.tr(state),
                                style: GoogleFonts.outfit(fontSize: 10, color: subtitleColor),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                  ),

                  // Search bar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 44,
                            decoration: BoxDecoration(
                              color: inputBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: borderColor),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Row(
                              children: [
                                Icon(Icons.search_rounded, size: 18, color: subtitleColor),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextField(
                                    controller: searchController,
                                    autofocus: true,
                                    style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: textColor,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'cth. Paracetamol, Amoxicillin...'.tr(state),
                                      hintStyle: GoogleFonts.outfit(
                                        fontSize: 12,
                                        color: subtitleColor.withOpacity(0.5),
                                      ),
                                      border: InputBorder.none,
                                      isDense: true,
                                    ),
                                    onSubmitted: (_) => doSearch(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: purple,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                          ),
                          onPressed: isLoading ? null : doSearch,
                          child: isLoading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  'Cari'.tr(state),
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),

                  // Divider
                  Divider(height: 1, color: borderColor),

                  // Results
                  Flexible(
                    child: errorMsg != null
                        ? Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.search_off_rounded, size: 40, color: subtitleColor.withOpacity(0.4)),
                                const SizedBox(height: 12),
                                Text(
                                  errorMsg!,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.outfit(fontSize: 12, color: subtitleColor),
                                ),
                              ],
                            ),
                          )
                        : results.isEmpty && !isLoading
                            ? Padding(
                                padding: const EdgeInsets.all(32),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.medication_liquid_rounded, size: 40, color: subtitleColor.withOpacity(0.25)),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Ketik nama obat lalu tekan Cari'.tr(state),
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.outfit(fontSize: 12, color: subtitleColor.withOpacity(0.6)),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.all(12),
                                shrinkWrap: true,
                                itemCount: results.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 8),
                                itemBuilder: (_, idx) {
                                  final item = results[idx];
                                  return InkWell(
                                    onTap: () => Navigator.of(ctx).pop(item),
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: inputBg,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: borderColor),
                                      ),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          Container(
                                            width: 38,
                                            height: 38,
                                            decoration: BoxDecoration(
                                              color: purple.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(9),
                                            ),
                                            alignment: Alignment.center,
                                            child: Icon(Icons.medication_rounded, color: purple, size: 20),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  item['nama'] ?? '',
                                                  style: GoogleFonts.outfit(
                                                    fontSize: 12.5,
                                                    fontWeight: FontWeight.w800,
                                                    color: textColor,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Row(
                                                  children: [
                                                    _kfaChip(item['jenis'] ?? '', purple.withOpacity(0.12), purple),
                                                    const SizedBox(width: 6),
                                                    _kfaChip(item['satuan'] ?? '', subtitleColor.withOpacity(0.1), subtitleColor),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  'KFA: ${item['code'] ?? '-'}',
                                                  style: GoogleFonts.outfit(
                                                    fontSize: 9.5,
                                                    color: subtitleColor,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Icon(
                                            Icons.arrow_forward_ios_rounded,
                                            size: 13,
                                            color: subtitleColor.withOpacity(0.5),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                  ),

                  const SizedBox(height: 8),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _kfaChip(String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: GoogleFonts.outfit(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}
