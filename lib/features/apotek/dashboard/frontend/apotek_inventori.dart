import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapotech/features/landing/landing_page_data.dart';
import 'package:mapotech/shared/supabase_service.dart';

class InventoryItem {
  final String id; // Represents the Batch ID in the database
  final String name;
  final String sku;
  final String genericName;
  final String form;
  int stock;
  final String unit;
  final double sellPrice;
  final String rackName;
  final String status; // 'aman', 'menipis', 'habis'

  InventoryItem({
    required this.id,
    required this.name,
    required this.sku,
    required this.genericName,
    required this.form,
    required this.stock,
    required this.unit,
    required this.sellPrice,
    required this.rackName,
    required this.status,
  });
}

class ApotekInventori extends ConsumerStatefulWidget {
  const ApotekInventori({super.key});

  @override
  ConsumerState<ApotekInventori> createState() => _ApotekInventoriState();
}

class _ApotekInventoriState extends ConsumerState<ApotekInventori> {
  final SupabaseService _db = SupabaseService();
  bool _isLoading = true;

  // Mock Inventory Catalog
  List<InventoryItem> _items = [];
  String _searchQuery = '';
  String _activeTab = 'semua'; // 'semua', 'aman', 'menipis', 'habis'

  @override
  void initState() {
    super.initState();
    _loadInventoryFromDatabase();
  }

  Future<void> _loadInventoryFromDatabase() async {
    setState(() => _isLoading = true);
    try {
      final List<InventoryItem> loadedItems = [];
      final rawMedicines = await _db.fetchMedicinesWithBatches();

      for (final m in rawMedicines) {
        final String id = m['id'] ?? '';
        final String name = m['medicine_name'] ?? 'Obat';
        final String generic = m['generic_name'] ?? 'Generic';
        final String form = m['medicine_form'] ?? 'Tablet';
        final batches = m['medicine_batches'] as List<dynamic>? ?? [];

        if (batches.isEmpty) {
          loadedItems.add(InventoryItem(
            id: id,
            name: name,
            sku: 'SKU-PCT-500',
            genericName: generic,
            form: form,
            stock: 0,
            unit: 'Strip',
            sellPrice: 5000,
            rackName: 'RAK-A1',
            status: 'habis',
          ));
        } else {
          for (final b in batches) {
            final int stock = int.tryParse(b['quantity_in_stock']?.toString() ?? '0') ?? 0;
            String status = 'aman';
            if (stock == 0) {
              status = 'habis';
            } else if (stock < 20) {
              status = 'menipis';
            }

            loadedItems.add(InventoryItem(
              id: b['id'] ?? '', // Batch ID used so adjustment patches the correct record
              name: name,
              sku: b['batch_number'] ?? 'BATCH-00',
              genericName: generic,
              form: form,
              stock: stock,
              unit: 'Strip',
              sellPrice: double.tryParse(b['selling_price']?.toString() ?? '5000') ?? 5000,
              rackName: 'RAK-A1',
              status: status,
            ));
          }
        }
      }

      setState(() {
        _items = loadedItems;
        _isLoading = false;
      });
    } catch (e) {
      // Offline fallback
      setState(() {
        _items = [
          InventoryItem(
            id: 'med1',
            name: 'Paracetamol 500mg (Local)',
            sku: 'SKU-PCT-500',
            genericName: 'Paracetamol',
            form: 'Tablet',
            stock: 120,
            unit: 'Strip',
            sellPrice: 5000,
            rackName: 'RAK-A1',
            status: 'aman',
          ),
        ];
        _isLoading = false;
      });
    }
  }

  void _showAdjustStockDialog(InventoryItem item, Color themeAccent, bool isDark) {
    final textController = TextEditingController(text: item.stock.toString());

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              return Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF161619) : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: isDark ? const Color(0xFF252528) : const Color(0xFFECEEF2)),
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Sesuaikan Stok Obat',
                      style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900, color: isDark ? Colors.white : const Color(0xFF1B0C3C)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.name,
                      style: GoogleFonts.outfit(fontSize: 11, color: isDark ? Colors.grey[400] : const Color(0xFF6F6A8A)),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: () {
                            int current = int.tryParse(textController.text) ?? 0;
                            if (current > 0) {
                              setDialogState(() {
                                textController.text = (current - 1).toString();
                              });
                            }
                          },
                          icon: Icon(Icons.remove_circle_outline_rounded, size: 28, color: themeAccent),
                        ),
                        const SizedBox(width: 16),
                        SizedBox(
                          width: 80,
                          child: TextField(
                            controller: textController,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900, color: isDark ? Colors.white : const Color(0xFF1B0C3C)),
                            decoration: InputDecoration(
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        IconButton(
                          onPressed: () {
                            int current = int.tryParse(textController.text) ?? 0;
                            setDialogState(() {
                              textController.text = (current + 1).toString();
                            });
                          },
                          icon: Icon(Icons.add_circle_outline_rounded, size: 28, color: themeAccent),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: isDark ? const Color(0xFF252528) : const Color(0xFFECEEF2)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text(
                              'BATAL',
                              style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.grey[400] : const Color(0xFF1B0C3C)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              final int nextStock = int.tryParse(textController.text) ?? item.stock;
                              Navigator.pop(context);
                              await _saveStockAdjustmentToDatabase(item, nextStock);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: themeAccent,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text(
                              'SIMPAN',
                              style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _saveStockAdjustmentToDatabase(InventoryItem item, int nextStock) async {
    setState(() => _isLoading = true);
    try {
      // Patch database directly
      await _db.adjustBatchStock(item.id, nextStock);
      await _loadInventoryFromDatabase();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Stok ${item.name} berhasil diperbarui di database.', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600)),
          backgroundColor: const Color(0xFF48C9B0),
        ),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menyimpan penyesuaian stok: $e', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600)),
          backgroundColor: Colors.redAccent,
        ),
      );
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

    // Calculate dynamic stats
    double totalAsset = _items.fold(0.0, (sum, item) => sum + (item.sellPrice * item.stock));
    int amanCount = _items.where((i) => i.stock >= 20).length;
    int menipisCount = _items.where((i) => i.stock > 0 && i.stock < 20).length;
    int habisCount = _items.where((i) => i.stock == 0).length;

    final filteredItems = _items.where((item) {
      final matchesSearch = item.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item.sku.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item.genericName.toLowerCase().contains(_searchQuery.toLowerCase());

      if (_activeTab == 'aman') {
        return matchesSearch && item.stock >= 20;
      } else if (_activeTab == 'menipis') {
        return matchesSearch && item.stock > 0 && item.stock < 20;
      } else if (_activeTab == 'habis') {
        return matchesSearch && item.stock == 0;
      }
      return matchesSearch;
    }).toList();

    return _isLoading
        ? Center(child: CircularProgressIndicator(color: themeAccent))
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Summary statistics bar
              Row(
                children: [
                  Expanded(
                    child: _buildStatMiniCard('NILAI ASET', 'Rp ${_formatPrice(totalAsset)}', Icons.wallet_rounded, themeAccent, cardBgColor, borderColor),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildStatMiniCard('STOK AMAN', '$amanCount OBAT', Icons.check_circle_outline_rounded, const Color(0xFF48C9B0), cardBgColor, borderColor),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildStatMiniCard('STOK MENIPIS', '$menipisCount OBAT', Icons.warning_amber_rounded, Colors.amber, cardBgColor, borderColor),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildStatMiniCard('HABIS/KRITIS', '$habisCount OBAT', Icons.cancel_outlined, Colors.redAccent, cardBgColor, borderColor),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Filter and Search Header
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cardBgColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
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
                                hintText: 'Cari obat, formula, SKU, atau rak...',
                                hintStyle: GoogleFonts.outfit(fontSize: 12, color: subtitleColor.withOpacity(0.5)),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildTabButton('Semua', 'semua', themeAccent),
                          const SizedBox(width: 8),
                          _buildTabButton('Tersedia (Aman)', 'aman', themeAccent),
                          const SizedBox(width: 8),
                          _buildTabButton('Menipis', 'menipis', themeAccent),
                          const SizedBox(width: 8),
                          _buildTabButton('Habis', 'habis', themeAccent),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Inventory Stock Catalog List
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: filteredItems.length,
                  itemBuilder: (context, index) {
                    final item = filteredItems[index];

                    Color statusColor = const Color(0xFF48C9B0);
                    String statusLabel = 'Tersedia';
                    if (item.stock == 0) {
                      statusColor = Colors.redAccent;
                      statusLabel = 'Habis';
                    } else if (item.stock < 20) {
                      statusColor = Colors.amber;
                      statusLabel = 'Menipis';
                    }

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
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.inventory_2_rounded, color: statusColor, size: 20),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item.name,
                                        style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: textColor),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: statusColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(100),
                                      ),
                                      child: Text(
                                        statusLabel,
                                        style: GoogleFonts.outfit(fontSize: 7, fontWeight: FontWeight.bold, color: statusColor),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'SKU: ${item.sku} • Lokasi: ${item.rackName}',
                                  style: GoogleFonts.outfit(fontSize: 9, color: subtitleColor),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Rp ${_formatPrice(item.sellPrice)} / ${item.unit}',
                                  style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: textColor),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${item.stock}',
                                style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900, color: textColor),
                              ),
                              Text(
                                item.unit,
                                style: GoogleFonts.outfit(fontSize: 8, color: subtitleColor),
                              ),
                              const SizedBox(height: 4),
                              TextButton(
                                onPressed: () => _showAdjustStockDialog(item, themeAccent, isDark),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  backgroundColor: themeAccent.withOpacity(0.12),
                                  foregroundColor: themeAccent,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                ),
                                child: Text(
                                  'UPDATE',
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
            ],
          );
  }

  Widget _buildStatMiniCard(String label, String value, IconData icon, Color color, Color bg, Color border) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.outfit(fontSize: 7, fontWeight: FontWeight.bold, color: const Color(0xFF6F6A8A)),
                ),
                Text(
                  value,
                  style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: color),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, String tabId, Color themeAccent) {
    final active = _activeTab == tabId;
    return InkWell(
      onTap: () => setState(() => _activeTab = tabId),
      borderRadius: BorderRadius.circular(100),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? themeAccent.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: active ? themeAccent : Colors.transparent),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 10,
            fontWeight: active ? FontWeight.w900 : FontWeight.bold,
            color: active ? themeAccent : const Color(0xFF6F6A8A),
          ),
        ),
      ),
    );
  }
}
