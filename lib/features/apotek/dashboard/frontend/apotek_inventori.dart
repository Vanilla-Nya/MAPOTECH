import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapotech/features/landing/landing_page_data.dart';
import 'package:mapotech/shared/widgets/ui.dart';
import 'package:mapotech/shared/supabase_service.dart';
import 'package:mapotech/features/apotek/dashboard/backend/inventory_provider.dart';

class ApotekInventori extends ConsumerStatefulWidget {
  const ApotekInventori({super.key});

  @override
  ConsumerState<ApotekInventori> createState() => _ApotekInventoriState();
}

class _ApotekInventoriState extends ConsumerState<ApotekInventori> {
  final SupabaseService _db = SupabaseService();
  String _searchQuery = '';
  String _activeFilter = 'semua'; // 'semua', 'aman', 'menipis', 'habis', 'kadaluarsa'
  bool _isGridView = false;
  bool get isEn => ref.read(isEnglishProvider);

  @override
  void initState() {
    super.initState();
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

  Future<void> _loadInventoryFromDatabase() async {
    await ref.read(apotekInventoryProvider.notifier).loadInventory();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 1. MAIN DETAIL & EDIT MODAL (Info Obat & Batch/Stok Tabs)
  // ═══════════════════════════════════════════════════════════════════════════
  void _showMedicineDetailModal(BuildContext context, ApotekInventoryItem item, bool isDark, Color themeAccent, Color textColor, Color subtitleColor, Color cardBgColor, Color borderColor) {
    int activeTab = 0; // 0: Info Obat, 1: Batch & Stok (N)

    final nameCtrl = TextEditingController(text: item.name);
    final brandCtrl = TextEditingController(text: item.brandName);
    final genericCtrl = TextEditingController(text: item.genericName);
    final skuCtrl = TextEditingController(text: item.sku);
    final descCtrl = TextEditingController(text: item.description ?? 'Catatan dosis, efek samping, dll...');
    String selectedForm = item.form;

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final batchesCount = item.batches.length;

          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Container(
              width: 780,
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.90),
              decoration: BoxDecoration(
                color: cardBgColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: borderColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.28),
                    blurRadius: 28,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ─── Header ──────────────────────────────────
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      decoration: BoxDecoration(
                        color: cardBgColor,
                        border: Border(bottom: BorderSide(color: borderColor)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFF27AE60).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(Icons.inventory_2_outlined, color: Color(0xFF27AE60), size: 24),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  style: GoogleFonts.outfit(fontSize: 16.5, fontWeight: FontWeight.w900, color: textColor),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '- · ${item.form}',
                                  style: GoogleFonts.outfit(fontSize: 11, color: subtitleColor),
                                ),
                              ],
                            ),
                          ),

                          // Pill Tab Switcher: [ Info Obat ] [ Batch & Stok (N) ]
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF242429) : const Color(0xFFF1F4F8),
                              borderRadius: BorderRadius.circular(100),
                              border: Border.all(color: borderColor),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                InkWell(
                                  onTap: () => setModalState(() => activeTab = 0),
                                  borderRadius: BorderRadius.circular(100),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: activeTab == 0
                                          ? (isDark ? const Color(0xFF161619) : Colors.white)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(100),
                                      boxShadow: activeTab == 0
                                          ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4, offset: const Offset(0, 1))]
                                          : null,
                                    ),
                                    child: Text(
                                      'Info Obat',
                                      style: GoogleFonts.outfit(
                                        fontSize: 11.5,
                                        fontWeight: activeTab == 0 ? FontWeight.w900 : FontWeight.w600,
                                        color: activeTab == 0 ? (const Color(0xFF27AE60)) : subtitleColor,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                InkWell(
                                  onTap: () => setModalState(() => activeTab = 1),
                                  borderRadius: BorderRadius.circular(100),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: activeTab == 1
                                          ? (isDark ? const Color(0xFF161619) : Colors.white)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(100),
                                      boxShadow: activeTab == 1
                                          ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4, offset: const Offset(0, 1))]
                                          : null,
                                    ),
                                    child: Text(
                                      'Batch & Stok ($batchesCount)',
                                      style: GoogleFonts.outfit(
                                        fontSize: 11.5,
                                        fontWeight: activeTab == 1 ? FontWeight.w900 : FontWeight.w600,
                                        color: activeTab == 1 ? const Color(0xFF27AE60) : subtitleColor,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          IconButton(
                            icon: Icon(Icons.close_rounded, color: subtitleColor, size: 20),
                            onPressed: () => Navigator.pop(ctx),
                            splashRadius: 18,
                          ),
                        ],
                      ),
                    ),

                    // ─── Modal Content (Tab 0 or Tab 1) ───────────
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: activeTab == 0
                            ? _buildInfoObatTab(item, nameCtrl, brandCtrl, genericCtrl, skuCtrl, descCtrl, selectedForm, (f) => setModalState(() => selectedForm = f), isDark, themeAccent, textColor, subtitleColor, cardBgColor, borderColor, ctx)
                            : _buildBatchStokTab(item, isDark, themeAccent, textColor, subtitleColor, cardBgColor, borderColor, setModalState),
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

  // ───────────────────────────────────────────────────────────────────────────
  // TAB 0: INFO OBAT
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildInfoObatTab(
    ApotekInventoryItem item,
    TextEditingController nameCtrl,
    TextEditingController brandCtrl,
    TextEditingController genericCtrl,
    TextEditingController skuCtrl,
    TextEditingController descCtrl,
    String selectedForm,
    ValueChanged<String> onFormChanged,
    bool isDark,
    Color themeAccent,
    Color textColor,
    Color subtitleColor,
    Color cardBgColor,
    Color borderColor,
    BuildContext ctx,
  ) {
    final messenger = ScaffoldMessenger.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Foto Obat Box
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF27AE60).withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF27AE60).withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF27AE60).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.add_photo_alternate_outlined, color: Color(0xFF27AE60), size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Foto obat (opsional)', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: textColor)),
                    const SizedBox(height: 2),
                    Text(
                      'Upload dengan crop/zoom atau gunakan URL agar foto produk tampil rapi di POS.',
                      style: GoogleFonts.outfit(fontSize: 10.5, color: subtitleColor),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Fitur upload & crop foto obat siap digunakan.', style: GoogleFonts.outfit(fontSize: 11)),
                    ),
                  );
                },
                icon: const Icon(Icons.add_photo_alternate_rounded, size: 14, color: Color(0xFF27AE60)),
                label: Text('Atur Foto', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF27AE60))),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF27AE60)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // Nama Obat
        _buildFieldLabel('Nama Obat', textColor),
        _buildStyledTextField(nameCtrl, 'Nama obat...', isDark, borderColor, textColor, subtitleColor),

        const SizedBox(height: 14),

        // Merek / Brand & Nama Generik
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFieldLabel('Merek / Brand', textColor),
                  _buildStyledTextField(brandCtrl, 'Merek dagang...', isDark, borderColor, textColor, subtitleColor),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFieldLabel('Nama Generik', textColor),
                  _buildStyledTextField(genericCtrl, 'Nama generik / zat aktif...', isDark, borderColor, textColor, subtitleColor),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 14),

        // Bentuk Sediaan & Barcode / SKU
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFieldLabel('Bentuk Sediaan', textColor),
                  Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1E22) : const Color(0xFFF8FAFD),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedForm,
                        isExpanded: true,
                        dropdownColor: cardBgColor,
                        style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: textColor),
                        items: ['Tablet', 'Kaplet', 'Kapsul', 'Sirup', 'Salep', 'Injeksi', 'Drop', 'Botol', 'Tube', 'Pcs'].map((f) {
                          return DropdownMenuItem(value: f, child: Text(f));
                        }).toList(),
                        onChanged: (v) {
                          if (v != null) onFormChanged(v);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFieldLabel('Barcode / SKU', textColor),
                  Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1E22) : const Color(0xFFF8FAFD),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: skuCtrl,
                            style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: textColor),
                            decoration: InputDecoration(
                              hintText: 'SKU atau scan barcode...',
                              hintStyle: GoogleFonts.outfit(fontSize: 11, color: subtitleColor.withValues(alpha: 0.6)),
                              border: InputBorder.none,
                              isDense: true,
                            ),
                          ),
                        ),
                        Icon(Icons.qr_code_scanner_rounded, size: 20, color: const Color(0xFF27AE60)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 14),

        // Deskripsi / Catatan
        _buildFieldLabel('Deskripsi / Catatan', textColor),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E22) : const Color(0xFFF8FAFD),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: TextField(
            controller: descCtrl,
            maxLines: 3,
            style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: textColor),
            decoration: InputDecoration(
              hintText: 'Catatan dosis, efek samping, dll...',
              hintStyle: GoogleFonts.outfit(fontSize: 11, color: subtitleColor.withValues(alpha: 0.6)),
              border: InputBorder.none,
              isDense: true,
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Action Buttons: Arsipkan Obat (Left) & Simpan Perubahan (Right)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            OutlinedButton.icon(
              onPressed: () async {
                Navigator.pop(ctx);
                item.isArchived = true;
                ref.read(apotekInventoryProvider.notifier).deleteMedicine(item.id);
                try {
                  await _db.deleteMedicine(item.id);
                  if (mounted) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Obat ${item.name} berhasil diarsipkan dari database.', style: GoogleFonts.outfit(fontSize: 11)),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  }
                } catch (e) {
                  debugPrint('Error archiving medicine: $e');
                }
              },
              icon: const Icon(Icons.archive_outlined, size: 16, color: Colors.orange),
              label: Text('Arsipkan Obat', style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.orange)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.orange),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(ctx);
                final updatedName = nameCtrl.text.trim().isNotEmpty ? nameCtrl.text.trim() : item.name;
                final updatedBrand = brandCtrl.text.trim();
                final updatedGeneric = genericCtrl.text.trim();
                final updatedSku = skuCtrl.text.trim();
                final updatedDesc = descCtrl.text.trim();

                setState(() {
                  item.name = updatedName;
                  item.brandName = updatedBrand;
                  item.genericName = updatedGeneric;
                  item.sku = updatedSku;
                  item.form = selectedForm;
                  item.description = updatedDesc;
                });

                try {
                  if (item.id.startsWith('med-') && item.id.length > 10) {
                    final created = await _db.createMedicine({
                      'medicine_name': updatedName,
                      'brand_name': updatedBrand,
                      'generic_name': updatedGeneric,
                      'sku': updatedSku,
                      'medicine_form': selectedForm,
                      'description': updatedDesc,
                      'rack_name': item.rackName,
                    });
                    if (created['id'] != null) {
                      await _loadInventoryFromDatabase();
                    }
                  } else {
                    await _db.updateMedicine(item.id, {
                      'medicine_name': updatedName,
                      'brand_name': updatedBrand,
                      'generic_name': updatedGeneric,
                      'sku': updatedSku,
                      'medicine_form': selectedForm,
                      'description': updatedDesc,
                    });
                  }

                  if (mounted) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Data obat $updatedName berhasil disimpan ke database!', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold)),
                        backgroundColor: const Color(0xFF27AE60),
                      ),
                    );
                  }
                } catch (e) {
                  debugPrint('Error updating medicine: $e');
                }
              },
              icon: const Icon(Icons.save_rounded, size: 16, color: Colors.white),
              label: Text('Simpan Perubahan', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF27AE60),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // TAB 1: BATCH & STOK
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildBatchStokTab(
    ApotekInventoryItem item,
    bool isDark,
    Color themeAccent,
    Color textColor,
    Color subtitleColor,
    Color cardBgColor,
    Color borderColor,
    StateSetter setModalState,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Subheader with RINCIAN BATCH AKTIF and + Batch Baru Button
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'RINCIAN BATCH AKTIF',
              style: GoogleFonts.outfit(
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
                color: subtitleColor,
                letterSpacing: 1.0,
              ),
            ),
            OutlinedButton.icon(
              onPressed: () {
                _showAddBatchModal(context, item, isDark, themeAccent, textColor, subtitleColor, cardBgColor, borderColor, setModalState);
              },
              icon: const Icon(Icons.add_rounded, size: 16, color: Color(0xFF27AE60)),
              label: Text('+ Batch Baru', style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.w900, color: const Color(0xFF27AE60))),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF27AE60), width: 1.2),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),

        const SizedBox(height: 14),

        // Table Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: borderColor)),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 5,
                child: Text('NO. BATCH', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: subtitleColor, letterSpacing: 0.5)),
              ),
              Expanded(
                flex: 3,
                child: Text('STOK', textAlign: TextAlign.right, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: subtitleColor, letterSpacing: 0.5)),
              ),
              Expanded(
                flex: 3,
                child: Text('TGL. EXP', textAlign: TextAlign.center, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: subtitleColor, letterSpacing: 0.5)),
              ),
              Expanded(
                flex: 3,
                child: Text('STATUS', textAlign: TextAlign.center, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: subtitleColor, letterSpacing: 0.5)),
              ),
            ],
          ),
        ),

        // Table Rows
        if (item.batches.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 40),
            alignment: Alignment.center,
            child: Column(
              children: [
                Icon(Icons.inventory_2_outlined, size: 36, color: subtitleColor.withValues(alpha: 0.5)),
                const SizedBox(height: 8),
                Text('Belum ada batch persediaan aktif.', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: subtitleColor)),
              ],
            ),
          )
        else
          ...item.batches.map((batch) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: borderColor.withValues(alpha: 0.6))),
              ),
              child: Row(
                children: [
                  // Expand arrow & Batch Code & Location
                  Expanded(
                    flex: 5,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.chevron_right_rounded, size: 18, color: subtitleColor),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                batch.batchNo,
                                style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w900, color: textColor),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Icon(Icons.location_on_outlined, size: 12, color: subtitleColor),
                                  const SizedBox(width: 3),
                                  Text(
                                    batch.rackLocation ?? '-',
                                    style: GoogleFonts.outfit(fontSize: 10.5, color: subtitleColor),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Stock
                  Expanded(
                    flex: 3,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          _formatPrice(batch.stock.toDouble()),
                          style: GoogleFonts.outfit(fontSize: 13.5, fontWeight: FontWeight.w900, color: textColor),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          item.unit.toUpperCase(),
                          style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.bold, color: subtitleColor),
                        ),
                      ],
                    ),
                  ),

                  // Expiration Date
                  Expanded(
                    flex: 3,
                    child: Text(
                      _formatExpDate(batch.expDate),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.w600, color: textColor),
                    ),
                  ),

                  // Status & Action buttons (Pencil Edit & Opname Checklist)
                  Expanded(
                    flex: 3,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF27AE60).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(
                            'OK',
                            style: GoogleFonts.outfit(fontSize: 9.5, fontWeight: FontWeight.w900, color: const Color(0xFF27AE60)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: Icon(Icons.edit_outlined, size: 16, color: subtitleColor),
                          tooltip: 'Edit Batch',
                          splashRadius: 16,
                          onPressed: () {
                            _showEditBatchModal(context, item, batch, isDark, themeAccent, textColor, subtitleColor, cardBgColor, borderColor, setModalState);
                          },
                        ),
                        IconButton(
                          icon: Icon(Icons.assignment_turned_in_outlined, size: 16, color: subtitleColor),
                          tooltip: 'Stok Opname Cepat',
                          splashRadius: 16,
                          onPressed: () {
                            _showQuickOpnameModal(context, item, batch, isDark, themeAccent, textColor, subtitleColor, cardBgColor, borderColor, setModalState);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  String _formatExpDate(String dateStr) {
    try {
      final parts = dateStr.split('-');
      if (parts.length >= 3) {
        final year = parts[0];
        final monthIdx = int.tryParse(parts[1]) ?? 1;
        final day = parts[2];
        const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        return '$day ${months[monthIdx]} $year';
      }
    } catch (_) {}
    return dateStr;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 2. MODAL: EDIT BATCH PERSEDIAAN
  // ═══════════════════════════════════════════════════════════════════════════
  void _showEditBatchModal(
    BuildContext context,
    ApotekInventoryItem item,
    ApotekBatchModel batch,
    bool isDark,
    Color themeAccent,
    Color textColor,
    Color subtitleColor,
    Color cardBgColor,
    Color borderColor,
    StateSetter parentSetState,
  ) {
    final messenger = ScaffoldMessenger.of(context);
    final batchNoCtrl = TextEditingController(text: batch.batchNo);
    final expCtrl = TextEditingController(text: batch.expDate);
    final rackCtrl = TextEditingController(text: batch.rackLocation ?? item.rackName);
    final stockCtrl = TextEditingController(text: batch.stock.toString());
    final buyPriceCtrl = TextEditingController(text: batch.buyPrice.toStringAsFixed(0));
    final sellPriceCtrl = TextEditingController(text: batch.sellPrice.toStringAsFixed(0));

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Container(
              width: 520,
              decoration: BoxDecoration(
                color: cardBgColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: borderColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: borderColor)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: const Color(0xFF27AE60).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(Icons.edit_outlined, color: Color(0xFF27AE60), size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Edit Batch Persediaan', style: GoogleFonts.outfit(fontSize: 15.5, fontWeight: FontWeight.w900, color: textColor)),
                                Text('${item.name} - ${batch.batchNo}', style: GoogleFonts.outfit(fontSize: 11, color: subtitleColor)),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close_rounded, color: subtitleColor, size: 20),
                            onPressed: () => Navigator.pop(ctx),
                            splashRadius: 18,
                          ),
                        ],
                      ),
                    ),

                    // Body
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Section A: INFORMASI BATCH
                            Text('A - INFORMASI BATCH', style: GoogleFonts.outfit(fontSize: 9.5, fontWeight: FontWeight.w900, color: subtitleColor, letterSpacing: 0.8)),
                            const SizedBox(height: 10),

                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildRequiredLabel('No. Batch', textColor),
                                      Container(
                                        height: 44,
                                        padding: const EdgeInsets.symmetric(horizontal: 12),
                                        decoration: BoxDecoration(
                                          color: isDark ? const Color(0xFF1E1E22) : const Color(0xFFF8FAFD),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: const Color(0xFF27AE60), width: 1.5),
                                        ),
                                        child: TextField(
                                          controller: batchNoCtrl,
                                          style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: const Color(0xFF27AE60)),
                                          decoration: const InputDecoration(border: InputBorder.none, isDense: true),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildRequiredLabel('Tanggal Kadaluwarsa', textColor),
                                      Container(
                                        height: 44,
                                        padding: const EdgeInsets.symmetric(horizontal: 12),
                                        decoration: BoxDecoration(
                                          color: isDark ? const Color(0xFF1E1E22) : const Color(0xFFF8FAFD),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: borderColor),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(Icons.calendar_today_outlined, size: 16, color: subtitleColor),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: TextField(
                                                controller: expCtrl,
                                                style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: textColor),
                                                decoration: const InputDecoration(hintText: 'YYYY-MM-DD', border: InputBorder.none, isDense: true),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),

                            _buildFieldLabel('Lokasi Rak', textColor),
                            _buildStyledTextField(rackCtrl, 'Pilih atau tambah rak...', isDark, borderColor, textColor, subtitleColor),

                            const SizedBox(height: 20),

                            // Section B: KUANTITAS & HARGA
                            Text('B - KUANTITAS & HARGA', style: GoogleFonts.outfit(fontSize: 9.5, fontWeight: FontWeight.w900, color: subtitleColor, letterSpacing: 0.8)),
                            const SizedBox(height: 10),

                            _buildRequiredLabel('Kuantitas (Stok Fisik)', textColor),
                            _buildStyledTextField(stockCtrl, '0', isDark, borderColor, textColor, subtitleColor, isNumber: true),

                            const SizedBox(height: 12),

                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildRequiredLabel('Harga Beli / Unit (HPP)', textColor),
                                      _buildCurrencyField(buyPriceCtrl, isDark, borderColor, textColor, subtitleColor),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildRequiredLabel('Harga Jual / Unit Batch', textColor),
                                      _buildCurrencyField(sellPriceCtrl, isDark, borderColor, textColor, subtitleColor),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Footer Buttons
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border(top: BorderSide(color: borderColor)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton.icon(
                            onPressed: () async {
                              Navigator.pop(ctx);
                              setState(() {
                                item.batches.removeWhere((b) => b.id == batch.id);
                                item.stock = item.batches.fold(0, (sum, b) => sum + b.stock);
                              });
                              parentSetState(() {});

                              try {
                                await _db.deleteMedicineBatch(batch.id);
                                if (mounted) {
                                  messenger.showSnackBar(
                                    const SnackBar(content: Text('Batch berhasil dihapus dari database.'), backgroundColor: Colors.redAccent),
                                  );
                                }
                              } catch (e) {
                                debugPrint('Error deleting batch: $e');
                              }
                            },
                            icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Colors.redAccent),
                            label: Text('Hapus Batch', style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                          ),
                          Row(
                            children: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: Text('Batal', style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.bold, color: subtitleColor)),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                onPressed: () async {
                                  final updatedBatchNo = batchNoCtrl.text.trim();
                                  final updatedExp = expCtrl.text.trim();
                                  final updatedRack = rackCtrl.text.trim();
                                  final updatedStock = int.tryParse(stockCtrl.text) ?? batch.stock;
                                  final updatedBuy = double.tryParse(buyPriceCtrl.text) ?? batch.buyPrice;
                                  final updatedSell = double.tryParse(sellPriceCtrl.text) ?? batch.sellPrice;

                                  Navigator.pop(ctx);

                                  setState(() {
                                    batch.batchNo = updatedBatchNo;
                                    batch.expDate = updatedExp;
                                    batch.rackLocation = updatedRack;
                                    batch.stock = updatedStock;
                                    batch.buyPrice = updatedBuy;
                                    batch.sellPrice = updatedSell;
                                    item.stock = item.batches.fold(0, (sum, b) => sum + b.stock);
                                  });
                                  parentSetState(() {});

                                  try {
                                    await _db.updateMedicineBatch(batch.id, {
                                      'batch_number': updatedBatchNo,
                                      'expiration_date': updatedExp,
                                      'rack_location': updatedRack,
                                      'quantity_in_stock': updatedStock.toString(),
                                      'purchase_price': updatedBuy.toString(),
                                      'selling_price': updatedSell.toString(),
                                    });

                                    if (mounted) {
                                      messenger.showSnackBar(
                                        SnackBar(content: Text('Batch $updatedBatchNo berhasil diperbarui di database!'), backgroundColor: const Color(0xFF27AE60)),
                                      );
                                    }
                                  } catch (e) {
                                    debugPrint('Error updating batch: $e');
                                  }
                                },
                                icon: const Icon(Icons.save_rounded, size: 16, color: Colors.white),
                                label: Text('Simpan', style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.w900, color: Colors.white)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF27AE60),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  elevation: 0,
                                ),
                              ),
                            ],
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

  // ═══════════════════════════════════════════════════════════════════════════
  // 3. MODAL: STOK OPNAME CEPAT
  // ═══════════════════════════════════════════════════════════════════════════
  void _showQuickOpnameModal(
    BuildContext context,
    ApotekInventoryItem item,
    ApotekBatchModel batch,
    bool isDark,
    Color themeAccent,
    Color textColor,
    Color subtitleColor,
    Color cardBgColor,
    Color borderColor,
    StateSetter parentSetState,
  ) {
    final messenger = ScaffoldMessenger.of(context);
    int currentPhysical = batch.stock;
    final reasonCtrl = TextEditingController(text: 'Opname rutin');

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Container(
              width: 460,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: cardBgColor,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: borderColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Stok Opname Cepat', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900, color: textColor)),
                          const SizedBox(height: 2),
                          Text('Sesuaikan stok fisik untuk batch ${batch.batchNo}', style: GoogleFonts.outfit(fontSize: 11, color: subtitleColor)),
                        ],
                      ),
                      IconButton(
                        icon: Icon(Icons.close_rounded, color: subtitleColor, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                        splashRadius: 18,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  Row(
                    children: [
                      // Stok Sistem
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFieldLabel('Stok Sistem', textColor),
                            Container(
                              height: 44,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E1E22) : const Color(0xFFF1F4F8),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: borderColor),
                              ),
                              alignment: Alignment.centerLeft,
                              child: Text(
                                batch.stock.toString(),
                                style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: subtitleColor),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Stok Fisik (Aktual)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildFieldLabel('Stok Fisik (Aktual)', textColor),
                            Container(
                              height: 44,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E1E22) : const Color(0xFFF8FAFD),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFF27AE60), width: 1.5),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      keyboardType: TextInputType.number,
                                      controller: TextEditingController(text: currentPhysical.toString()),
                                      style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w900, color: textColor),
                                      decoration: const InputDecoration(border: InputBorder.none, isDense: true),
                                      onChanged: (val) {
                                        final p = int.tryParse(val);
                                        if (p != null) currentPhysical = p;
                                      },
                                    ),
                                  ),
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      InkWell(
                                        onTap: () => setModalState(() => currentPhysical++),
                                        child: const Icon(Icons.arrow_drop_up_rounded, size: 18),
                                      ),
                                      InkWell(
                                        onTap: () => setModalState(() {
                                          if (currentPhysical > 0) currentPhysical--;
                                        }),
                                        child: const Icon(Icons.arrow_drop_down_rounded, size: 18),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  _buildFieldLabel('Catatan / Alasan', textColor),
                  _buildStyledTextField(reasonCtrl, 'Contoh: Opname rutin', isDark, borderColor, textColor, subtitleColor),

                  const SizedBox(height: 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text('Batal', style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.bold, color: subtitleColor)),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          setState(() {
                            batch.stock = currentPhysical;
                            item.stock = item.batches.fold(0, (sum, b) => sum + b.stock);
                          });
                          parentSetState(() {});

                          try {
                            await _db.adjustBatchStock(batch.id, currentPhysical);
                            if (mounted) {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text('Stok fisik batch ${batch.batchNo} berhasil disesuaikan menjadi $currentPhysical ${item.unit} di database.'),
                                  backgroundColor: const Color(0xFF27AE60),
                                ),
                              );
                            }
                          } catch (e) {
                            debugPrint('Error adjusting stock: $e');
                          }
                        },
                        icon: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                        label: Text('Simpan Hasil', style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.w900, color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF27AE60),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 4. MODAL: TAMBAH BATCH BARU (WITH AUTO-GENERATED CODE)
  // ═══════════════════════════════════════════════════════════════════════════
  void _showAddBatchModal(
    BuildContext context,
    ApotekInventoryItem item,
    bool isDark,
    Color themeAccent,
    Color textColor,
    Color subtitleColor,
    Color cardBgColor,
    Color borderColor,
    StateSetter parentSetState,
  ) {
    final messenger = ScaffoldMessenger.of(context);
    final generatedCode = _generateBatchCode();
    final batchNoCtrl = TextEditingController(text: generatedCode);
    final expCtrl = TextEditingController(text: '${DateTime.now().year + 3}-12-31');
    final rackCtrl = TextEditingController(text: item.rackName);
    final qtyCtrl = TextEditingController(text: '0');
    final modalTotalCtrl = TextEditingController(text: '0');
    final sellPriceCtrl = TextEditingController(text: item.sellPrice.toStringAsFixed(0));

    double calculatedHpp = 0;

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Container(
              width: 520,
              decoration: BoxDecoration(
                color: cardBgColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: borderColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: borderColor)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: const Color(0xFF27AE60).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(Icons.inventory_2_outlined, color: Color(0xFF27AE60), size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Tambah Batch Baru', style: GoogleFonts.outfit(fontSize: 15.5, fontWeight: FontWeight.w900, color: textColor)),
                                Text('${item.name} · harga jual dapat berbeda untuk batch ini.', style: GoogleFonts.outfit(fontSize: 10.5, color: subtitleColor)),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close_rounded, color: subtitleColor, size: 20),
                            onPressed: () => Navigator.pop(ctx),
                            splashRadius: 18,
                          ),
                        ],
                      ),
                    ),

                    // Form Body
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Section A: INFORMASI BATCH
                            Text('A - INFORMASI BATCH', style: GoogleFonts.outfit(fontSize: 9.5, fontWeight: FontWeight.w900, color: subtitleColor, letterSpacing: 0.8)),
                            const SizedBox(height: 10),

                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildRequiredLabel('No. Batch', textColor),
                                      Container(
                                        height: 44,
                                        padding: const EdgeInsets.symmetric(horizontal: 12),
                                        decoration: BoxDecoration(
                                          color: isDark ? const Color(0xFF1E1E22) : const Color(0xFFF8FAFD),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: const Color(0xFF27AE60), width: 1.5),
                                        ),
                                        child: TextField(
                                          controller: batchNoCtrl,
                                          style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: const Color(0xFF27AE60)),
                                          decoration: const InputDecoration(border: InputBorder.none, isDense: true),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildRequiredLabel('Tanggal Kadaluwarsa', textColor),
                                      Container(
                                        height: 44,
                                        padding: const EdgeInsets.symmetric(horizontal: 12),
                                        decoration: BoxDecoration(
                                          color: isDark ? const Color(0xFF1E1E22) : const Color(0xFFF8FAFD),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: borderColor),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(Icons.calendar_today_outlined, size: 16, color: subtitleColor),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: TextField(
                                                controller: expCtrl,
                                                style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: textColor),
                                                decoration: const InputDecoration(hintText: 'mm/dd/yyyy', border: InputBorder.none, isDense: true),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),

                            _buildFieldLabel('Lokasi Rak', textColor),
                            _buildStyledTextField(rackCtrl, 'Pilih atau tambah rak...', isDark, borderColor, textColor, subtitleColor),

                            const SizedBox(height: 20),

                            // Section B: KUANTITAS & HARGA
                            Text('B - KUANTITAS & HARGA', style: GoogleFonts.outfit(fontSize: 9.5, fontWeight: FontWeight.w900, color: subtitleColor, letterSpacing: 0.8)),
                            const SizedBox(height: 10),

                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildRequiredLabel('Stok Masuk (Qty)', textColor),
                                      Container(
                                        height: 44,
                                        padding: const EdgeInsets.symmetric(horizontal: 12),
                                        decoration: BoxDecoration(
                                          color: isDark ? const Color(0xFF1E1E22) : const Color(0xFFF8FAFD),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: borderColor),
                                        ),
                                        child: TextField(
                                          controller: qtyCtrl,
                                          keyboardType: TextInputType.number,
                                          style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: textColor),
                                          decoration: const InputDecoration(hintText: '0', border: InputBorder.none, isDense: true),
                                          onChanged: (val) {
                                            final q = double.tryParse(val) ?? 0;
                                            final m = double.tryParse(modalTotalCtrl.text) ?? 0;
                                            setModalState(() {
                                              calculatedHpp = q > 0 ? (m / q) : 0;
                                            });
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildRequiredLabel('Modal Awal (Total)', textColor),
                                      Container(
                                        height: 44,
                                        padding: const EdgeInsets.symmetric(horizontal: 12),
                                        decoration: BoxDecoration(
                                          color: isDark ? const Color(0xFF1E1E22) : const Color(0xFFF8FAFD),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: borderColor),
                                        ),
                                        child: Row(
                                          children: [
                                            Text('Rp', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: subtitleColor)),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: TextField(
                                                controller: modalTotalCtrl,
                                                keyboardType: TextInputType.number,
                                                style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: textColor),
                                                decoration: const InputDecoration(hintText: '0', border: InputBorder.none, isDense: true),
                                                onChanged: (val) {
                                                  final q = double.tryParse(qtyCtrl.text) ?? 0;
                                                  final m = double.tryParse(val) ?? 0;
                                                  setModalState(() {
                                                    calculatedHpp = q > 0 ? (m / q) : 0;
                                                  });
                                                },
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),

                            // Auto HPP Calculation Banner
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F4F8),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                                    child: Icon(Icons.sell_outlined, size: 16, color: subtitleColor),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('HARGA BELI / UNIT (HPP)', style: GoogleFonts.outfit(fontSize: 9.5, fontWeight: FontWeight.bold, color: subtitleColor)),
                                        Text(
                                          calculatedHpp > 0 ? 'Rp ${_formatPrice(calculatedHpp)}' : 'Dihitung otomatis dari modal awal ÷ qty',
                                          style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: calculatedHpp > 0 ? textColor : subtitleColor),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    calculatedHpp > 0 ? '' : 'Isi qty & modal dahulu',
                                    style: GoogleFonts.outfit(fontSize: 10, fontStyle: FontStyle.italic, color: subtitleColor),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 14),

                            _buildRequiredLabel('Harga Jual / Unit Batch', textColor),
                            Text('terisi dari harga batch terakhir, bisa diubah', style: GoogleFonts.outfit(fontSize: 10, color: subtitleColor)),
                            const SizedBox(height: 4),
                            _buildCurrencyField(sellPriceCtrl, isDark, borderColor, textColor, subtitleColor),
                          ],
                        ),
                      ),
                    ),

                    // Footer
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border(top: BorderSide(color: borderColor)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: Text('Batal', style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.bold, color: subtitleColor)),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton.icon(
                            onPressed: () async {
                              final bCode = batchNoCtrl.text.trim().isNotEmpty ? batchNoCtrl.text.trim() : _generateBatchCode();
                              final exp = expCtrl.text.trim();
                              final rk = rackCtrl.text.trim();
                              final qty = int.tryParse(qtyCtrl.text) ?? 0;
                              final buyP = calculatedHpp > 0 ? calculatedHpp : (double.tryParse(modalTotalCtrl.text) ?? 100);
                              final sellP = double.tryParse(sellPriceCtrl.text) ?? item.sellPrice;

                              Navigator.pop(ctx);

                              try {
                                final created = await _db.createMedicineBatch({
                                  'id_medicine': item.id,
                                  'batch_number': bCode,
                                  'expiration_date': exp,
                                  'rack_location': rk,
                                  'quantity_in_stock': qty.toString(),
                                  'purchase_price': buyP.toString(),
                                  'selling_price': sellP.toString(),
                                  'supplier_name': 'PBF Distributor',
                                });

                                final batchId = created['id'] ?? 'b-${DateTime.now().millisecondsSinceEpoch}';
                                final newBatch = ApotekBatchModel(
                                  id: batchId,
                                  batchNo: bCode,
                                  expDate: exp,
                                  rackLocation: rk,
                                  stock: qty,
                                  buyPrice: buyP,
                                  sellPrice: sellP,
                                  supplier: 'PBF Distributor',
                                );

                                setState(() {
                                  item.batches.add(newBatch);
                                  item.stock = item.batches.fold(0, (sum, b) => sum + b.stock);
                                });
                                parentSetState(() {});

                                if (mounted) {
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text('Batch baru $bCode berhasil disimpan ke database!'),
                                      backgroundColor: const Color(0xFF27AE60),
                                    ),
                                  );
                                }
                              } catch (e) {
                                debugPrint('Error creating batch: $e');
                                final newBatch = ApotekBatchModel(
                                  id: 'b-${DateTime.now().millisecondsSinceEpoch}',
                                  batchNo: bCode,
                                  expDate: exp,
                                  rackLocation: rk,
                                  stock: qty,
                                  buyPrice: buyP,
                                  sellPrice: sellP,
                                  supplier: 'PBF Distributor',
                                );
                                setState(() {
                                  item.batches.add(newBatch);
                                  item.stock = item.batches.fold(0, (sum, b) => sum + b.stock);
                                });
                                parentSetState(() {});
                              }
                            },
                            icon: const Icon(Icons.save_rounded, size: 16, color: Colors.white),
                            label: Text('Simpan Batch', style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.w900, color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF27AE60),
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              elevation: 0,
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
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // HELPER WIDGETS
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildFieldLabel(String text, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Text(text, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: textColor)),
    );
  }

  Widget _buildRequiredLabel(String text, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          Text(text, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(width: 3),
          const Text('*', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.redAccent)),
        ],
      ),
    );
  }

  Widget _buildStyledTextField(TextEditingController ctrl, String hint, bool isDark, Color borderColor, Color textColor, Color subtitleColor, {bool isNumber = false}) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E22) : const Color(0xFFF8FAFD),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: TextField(
        controller: ctrl,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: textColor),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.outfit(fontSize: 11, color: subtitleColor.withValues(alpha: 0.6)),
          border: InputBorder.none,
          isDense: true,
        ),
      ),
    );
  }

  Widget _buildCurrencyField(TextEditingController ctrl, bool isDark, Color borderColor, Color textColor, Color subtitleColor) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E22) : const Color(0xFFF8FAFD),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Text('Rp', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: subtitleColor)),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: textColor),
              decoration: const InputDecoration(border: InputBorder.none, isDense: true),
            ),
          ),
        ],
      ),
    );
  }

  String _formatPrice(double value) {
    return value.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD MAIN INVENTORY VIEW
  // ═══════════════════════════════════════════════════════════════════════════
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

    final items = ref.watch(apotekInventoryProvider);
    final isLoading = ref.watch(apotekInventoryProvider.notifier).isLoading;

    // KPI Aggregations
    final totalCatalog = items.length;
    final totalAssets = items.fold(0.0, (sum, i) => sum + (i.sellPrice * i.stock));
    final amanCount = items.where((i) => i.status == 'aman').length;
    final menipisCount = items.where((i) => i.status == 'menipis').length;
    final habisCount = items.where((i) => i.status == 'habis').length;

    // Filter and search
    final filtered = items.where((item) {
      final q = _searchQuery.toLowerCase();
      final matchQ = item.name.toLowerCase().contains(q) ||
          item.genericName.toLowerCase().contains(q) ||
          item.sku.toLowerCase().contains(q) ||
          item.rackName.toLowerCase().contains(q);

      if (!matchQ) return false;

      if (_activeFilter == 'aman') return item.status == 'aman';
      if (_activeFilter == 'menipis') return item.status == 'menipis';
      if (_activeFilter == 'habis') return item.status == 'habis';
      if (_activeFilter == 'kadaluarsa') {
        return item.batches.any((b) => b.expDate.contains('2026'));
      }
      return true;
    }).toList();

    if (isLoading && items.isEmpty) {
      return CustomPageLoader(
        message: isEn ? 'Loading medicine inventory...' : 'Memuat data inventori obat...',
        skeleton: const SkeletonApotekDashboard(type: 'inventory'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ─── Header Banner ───────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
          decoration: BoxDecoration(
            color: cardBgColor,
            borderRadius: BorderRadius.circular(22),
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
                      isEn ? 'Medicine & Pharmacy Inventory' : 'Inventori Obat & Farmasi',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isEn ? 'Manage medicine catalog, track shelf stock, batch numbers, and monitor expiration dates' : 'Kelola katalog obat, lacak stok rak, nomor batch, dan pantau tanggal kedaluwarsa',
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
                onPressed: () {
                  final newItem = ApotekInventoryItem(
                    id: 'med-${DateTime.now().millisecondsSinceEpoch}',
                    name: 'Obat Baru',
                    sku: 'SKU-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
                    brandName: 'Obat Baru',
                    genericName: 'Zat Aktif',
                    form: 'Tablet',
                    stock: 0,
                    unit: 'Tablet',
                    buyPrice: 1000,
                    sellPrice: 1500,
                    rackName: 'RAK A-01',
                    batches: [],
                  );
                  ref.read(apotekInventoryProvider.notifier).addMedicine(newItem);
                  _showMedicineDetailModal(context, newItem, isDark, themeAccent, textColor, subtitleColor, cardBgColor, borderColor);
                },
                icon: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
                label: Text(
                  isEn ? 'Add New Medicine' : 'Tambah Obat Baru',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF27AE60),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ─── KPI Summary Cards Bar ───────────────────────────
        Row(
          children: [
            Expanded(child: _buildKpiCard(isEn ? 'TOTAL CATALOG' : 'TOTAL KATALOG', isEn ? '$totalCatalog Meds' : '$totalCatalog Obat', Icons.medication_rounded, themeAccent, cardBgColor, borderColor, textColor, subtitleColor)),
            const SizedBox(width: 10),
            Expanded(child: _buildKpiCard(isEn ? 'ASSET VALUATION' : 'VALUASI ASET', 'Rp ${_formatPrice(totalAssets)}', Icons.account_balance_wallet_rounded, const Color(0xFF27AE60), cardBgColor, borderColor, textColor, subtitleColor)),
            const SizedBox(width: 10),
            Expanded(child: _buildKpiCard(isEn ? 'LOW STOCK' : 'STOK MENIPIS', isEn ? '$menipisCount Meds' : '$menipisCount Obat', Icons.warning_amber_rounded, Colors.amber, cardBgColor, borderColor, textColor, subtitleColor)),
            const SizedBox(width: 10),
            Expanded(child: _buildKpiCard(isEn ? 'OUT OF STOCK' : 'HABIS / KRITIS', isEn ? '$habisCount Meds' : '$habisCount Obat', Icons.cancel_outlined, Colors.redAccent, cardBgColor, borderColor, textColor, subtitleColor)),
          ],
        ),

        const SizedBox(height: 16),

        // ─── Search, Filters & View Toggle ───────────────────
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardBgColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 42,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E1E22) : const Color(0xFFF6F8FB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderColor),
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
                                hintText: isEn ? 'Search medicine, active formula, SKU, or rack location...' : 'Cari obat, formula zat aktif, SKU, atau lokasi rak...',
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
                  // View mode toggle (List vs Grid)
                  Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1E22) : const Color(0xFFF6F8FB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.view_list_rounded, size: 18, color: !_isGridView ? const Color(0xFF27AE60) : subtitleColor),
                          onPressed: () => setState(() => _isGridView = false),
                          splashRadius: 18,
                          tooltip: isEn ? 'List View' : 'Tampilan Daftar',
                        ),
                        IconButton(
                          icon: Icon(Icons.grid_view_rounded, size: 18, color: _isGridView ? const Color(0xFF27AE60) : subtitleColor),
                          onPressed: () => setState(() => _isGridView = true),
                          splashRadius: 18,
                          tooltip: isEn ? 'Grid View' : 'Tampilan Grid',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip(isEn ? 'All ($totalCatalog)' : 'Semua ($totalCatalog)', 'semua', const Color(0xFF27AE60)),
                    const SizedBox(width: 8),
                    _buildFilterChip(isEn ? 'Healthy Stock ($amanCount)' : 'Stok Aman ($amanCount)', 'aman', const Color(0xFF27AE60)),
                    const SizedBox(width: 8),
                    _buildFilterChip(isEn ? 'Low Stock ($menipisCount)' : 'Stok Menipis ($menipisCount)', 'menipis', Colors.amber),
                    const SizedBox(width: 8),
                    _buildFilterChip(isEn ? 'Out of Stock ($habisCount)' : 'Habis ($habisCount)', 'habis', Colors.redAccent),
                    const SizedBox(width: 8),
                    _buildFilterChip(isEn ? 'Expiring Soon' : 'Hampir Kadaluarsa', 'kadaluarsa', Colors.orangeAccent),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ─── Inventory Catalog Content List/Grid ─────────────
        if (filtered.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 60),
            alignment: Alignment.center,
            child: Column(
              children: [
                Icon(Icons.inventory_2_outlined, size: 48, color: themeAccent.withValues(alpha: 0.3)),
                const SizedBox(height: 12),
                Text(isEn ? 'No Medicines Found' : 'Tidak Ada Obat Ditemukan', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w900, color: textColor)),
                const SizedBox(height: 4),
                Text(isEn ? 'Try changing your search keywords or add a new medicine.' : 'Ubah kata kunci pencarian atau tambahkan obat baru.', style: GoogleFonts.outfit(fontSize: 11, color: subtitleColor)),
              ],
            ),
          )
        else if (_isGridView)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filtered.length,
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 360,
              mainAxisExtent: 260,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
            ),
            itemBuilder: (context, index) {
              final item = filtered[index];
              return _buildGridCard(item, isDark, themeAccent, textColor, subtitleColor, cardBgColor, borderColor);
            },
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final item = filtered[index];
              return _buildListRow(item, isDark, themeAccent, textColor, subtitleColor, cardBgColor, borderColor);
            },
          ),
      ],
    );
  }

  Widget _buildKpiCard(String label, String value, IconData icon, Color color, Color cardBg, Color border, Color textColor, Color subColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: GoogleFonts.outfit(fontSize: 8.5, fontWeight: FontWeight.bold, color: subColor, letterSpacing: 0.5)),
                const SizedBox(height: 2),
                Text(value, style: GoogleFonts.outfit(fontSize: 13.5, fontWeight: FontWeight.w900, color: textColor), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String filterKey, Color activeColor) {
    final active = _activeFilter == filterKey;
    return InkWell(
      onTap: () => setState(() => _activeFilter = filterKey),
      borderRadius: BorderRadius.circular(100),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? activeColor.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: active ? activeColor : Colors.grey.withValues(alpha: 0.25)),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 11,
            fontWeight: active ? FontWeight.w900 : FontWeight.w600,
            color: active ? activeColor : const Color(0xFF6F6A8A),
          ),
        ),
      ),
    );
  }

  Widget _buildListRow(ApotekInventoryItem item, bool isDark, Color themeAccent, Color textColor, Color subtitleColor, Color cardBg, Color border) {
    Color statusColor = const Color(0xFF27AE60);
    String statusLabel = isEn ? 'In Stock' : 'Tersedia';
    if (item.status == 'habis') {
      statusColor = Colors.redAccent;
      statusLabel = isEn ? 'Out of Stock' : 'Habis';
    } else if (item.status == 'menipis') {
      statusColor = Colors.amber;
      statusLabel = isEn ? 'Low Stock' : 'Stok Menipis';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showMedicineDetailModal(context, item, isDark, themeAccent, textColor, subtitleColor, cardBg, border),
          borderRadius: BorderRadius.circular(20),
          splashColor: const Color(0xFF27AE60).withValues(alpha: 0.1),
          highlightColor: const Color(0xFF27AE60).withValues(alpha: 0.05),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                // Icon Form Badge
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Icon(Icons.medication_rounded, color: statusColor, size: 24),
                ),
                const SizedBox(width: 16),

                // Main Info
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              item.name,
                              style: GoogleFonts.outfit(fontSize: 13.5, fontWeight: FontWeight.w900, color: textColor),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF27AE60).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Text(item.form, style: GoogleFonts.outfit(fontSize: 8.5, fontWeight: FontWeight.bold, color: const Color(0xFF27AE60))),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${item.genericName} • ${item.sku} • ${item.rackName}',
                        style: GoogleFonts.outfit(fontSize: 10, color: subtitleColor),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 16),

                // Stock & Status
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('${_formatPrice(item.stock.toDouble())} ${item.unit}', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w900, color: statusColor)),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Text(statusLabel, style: GoogleFonts.outfit(fontSize: 8, fontWeight: FontWeight.w900, color: statusColor)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(100),
                        child: LinearProgressIndicator(
                          value: (item.stock / 100).clamp(0.0, 1.0),
                          minHeight: 4,
                          backgroundColor: isDark ? Colors.white12 : Colors.grey[200],
                          valueColor: AlwaysStoppedAnimation(statusColor),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 16),

                // Pricing
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Rp ${_formatPrice(item.sellPrice)}', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w900, color: textColor)),
                      Text('${isEn ? "Buy: " : "Beli: "}Rp ${_formatPrice(item.buyPrice)}', style: GoogleFonts.outfit(fontSize: 9.5, color: subtitleColor)),
                    ],
                  ),
                ),

                const SizedBox(width: 16),

                // Actions
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 20, color: Color(0xFF27AE60)),
                      tooltip: isEn ? 'Edit & Batches' : 'Edit & Batch',
                      onPressed: () => _showMedicineDetailModal(context, item, isDark, themeAccent, textColor, subtitleColor, cardBg, border),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGridCard(ApotekInventoryItem item, bool isDark, Color themeAccent, Color textColor, Color subtitleColor, Color cardBg, Color border) {
    Color statusColor = const Color(0xFF27AE60);
    String statusLabel = isEn ? 'In Stock' : 'Tersedia';
    if (item.status == 'habis') {
      statusColor = Colors.redAccent;
      statusLabel = isEn ? 'Out of Stock' : 'Habis';
    } else if (item.status == 'menipis') {
      statusColor = Colors.amber;
      statusLabel = isEn ? 'Low Stock' : 'Menipis';
    }

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showMedicineDetailModal(context, item, isDark, themeAccent, textColor, subtitleColor, cardBg, border),
          borderRadius: BorderRadius.circular(20),
          splashColor: const Color(0xFF27AE60).withValues(alpha: 0.1),
          highlightColor: const Color(0xFF27AE60).withValues(alpha: 0.05),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(statusLabel, style: GoogleFonts.outfit(fontSize: 8.5, fontWeight: FontWeight.w900, color: statusColor)),
                    ),
                    Text(item.form, style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.bold, color: subtitleColor)),
                  ],
                ),
                const SizedBox(height: 10),
                Text(item.name, style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w900, color: textColor), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(item.genericName, style: GoogleFonts.outfit(fontSize: 10, color: subtitleColor), maxLines: 1, overflow: TextOverflow.ellipsis),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(isEn ? 'STOCK' : 'STOK', style: GoogleFonts.outfit(fontSize: 8.5, fontWeight: FontWeight.bold, color: subtitleColor)),
                        Text('${_formatPrice(item.stock.toDouble())} ${item.unit}', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: statusColor)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(isEn ? 'SELL PRICE' : 'HARGA JUAL', style: GoogleFonts.outfit(fontSize: 8.5, fontWeight: FontWeight.bold, color: subtitleColor)),
                        Text('Rp ${_formatPrice(item.sellPrice)}', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: textColor)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
