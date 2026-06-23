import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapotech/features/landing/landing_page_data.dart';

class BukuKasEntry {
  final String id;
  final String tanggal;
  final String waktu;
  final String deskripsi;
  final String kategori; // 'Konsultasi', 'Farmasi', 'Obat & Medis', 'Operasional', 'Gaji', 'Lain-lain'
  final String tipe; // 'Pemasukan' or 'Pengeluaran'
  final String metode; // 'Cash', 'QRIS', 'BPJS', or '-'
  final double jumlah;
  final String status; // 'Lunas', 'Selesai', or '-'

  const BukuKasEntry({
    required this.id,
    required this.tanggal,
    required this.waktu,
    required this.deskripsi,
    required this.kategori,
    required this.tipe,
    required this.metode,
    required this.jumlah,
    required this.status,
  });
}

class DokterPembukuan extends ConsumerStatefulWidget {
  const DokterPembukuan({super.key});

  @override
  ConsumerState<DokterPembukuan> createState() => _DokterPembukuanState();
}

class _DokterPembukuanState extends ConsumerState<DokterPembukuan> {
  final List<BukuKasEntry> _ledger = [];
  String _filterType = 'Semua';
  String _searchQuery = '';
  BukuKasEntry? _selectedEntry;
  bool _showExpenseWizard = false;
  bool _isExporting = false;

  // Add expense controllers
  final _expDescController = TextEditingController();
  final _expAmountController = TextEditingController();
  String _expCategory = 'Obat & Medis';

  @override
  void initState() {
    super.initState();
    // Pre-populate with premium initial mock ledger entries
    _ledger.addAll([
      const BukuKasEntry(
        id: 'TRX-2026-0501',
        tanggal: '26 Mei 2026',
        waktu: '19:42',
        deskripsi: 'Pemeriksaan RME - Agus Afdholi Umar',
        kategori: 'Konsultasi',
        tipe: 'Pemasukan',
        metode: 'Cash',
        jumlah: 150000,
        status: 'Lunas',
      ),
      const BukuKasEntry(
        id: 'TRX-2026-0502',
        tanggal: '26 Mei 2026',
        waktu: '14:15',
        deskripsi: 'Pemeriksaan RME - Alfon Soetanto',
        kategori: 'Konsultasi',
        tipe: 'Pemasukan',
        metode: 'QRIS',
        jumlah: 220000,
        status: 'Lunas',
      ),
      const BukuKasEntry(
        id: 'TRX-2026-0503',
        tanggal: '25 Mei 2026',
        waktu: '11:30',
        deskripsi: 'Pemeriksaan RME - Alvin',
        kategori: 'Konsultasi',
        tipe: 'Pemasukan',
        metode: 'BPJS',
        jumlah: 120000,
        status: 'Selesai',
      ),
      const BukuKasEntry(
        id: 'OUT-2026-0501',
        tanggal: '24 Mei 2026',
        waktu: '09:00',
        deskripsi: 'Restock Batch Paracetamol & Prednison',
        kategori: 'Obat & Medis',
        tipe: 'Pengeluaran',
        metode: '-',
        jumlah: 450000,
        status: '-',
      ),
      const BukuKasEntry(
        id: 'OUT-2026-0502',
        tanggal: '22 Mei 2026',
        waktu: '17:00',
        deskripsi: 'Pembayaran Utilitas Listrik & Wifi Klinik',
        kategori: 'Operasional',
        tipe: 'Pengeluaran',
        metode: '-',
        jumlah: 350000,
        status: '-',
      ),
      const BukuKasEntry(
        id: 'TRX-2026-0504',
        tanggal: '20 Mei 2026',
        waktu: '10:00',
        deskripsi: 'Pemeriksaan RME - Belinda Anastasia Jenifer',
        kategori: 'Konsultasi',
        tipe: 'Pemasukan',
        metode: 'Cash',
        jumlah: 180000,
        status: 'Lunas',
      ),
      const BukuKasEntry(
        id: 'OUT-2026-0503',
        tanggal: '18 Mei 2026',
        waktu: '08:30',
        deskripsi: 'Pembelian Syringe, Jarum & Alcohol Swab',
        kategori: 'Obat & Medis',
        tipe: 'Pengeluaran',
        metode: '-',
        jumlah: 150000,
        status: '-',
      ),
    ]);
  }

  @override
  void dispose() {
    _expDescController.dispose();
    _expAmountController.dispose();
    super.dispose();
  }

  void _saveExpense() {
    final desc = _expDescController.text.trim();
    final amt = double.tryParse(_expAmountController.text) ?? 0.0;
    if (desc.isEmpty) {
      _showWarningDialog('Form Belum Lengkap', 'Harap isi deskripsi pengeluaran klinik.');
      return;
    }
    if (amt <= 0) {
      _showWarningDialog('Jumlah Salah', 'Harap masukkan jumlah nominal pengeluaran yang valid.');
      return;
    }

    final randNo = Random().nextInt(900) + 100;
    final now = DateTime.now();
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    setState(() {
      _ledger.insert(
        0,
        BukuKasEntry(
          id: 'OUT-2026-05$randNo',
          tanggal: '26 Mei 2026',
          waktu: timeStr,
          deskripsi: desc,
          kategori: _expCategory,
          tipe: 'Pengeluaran',
          metode: '-',
          jumlah: amt,
          status: '-',
        ),
      );
      _showExpenseWizard = false;
      _expDescController.clear();
      _expAmountController.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.redAccent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          children: [
            const Icon(Icons.outbox_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Text(
              'Pengeluaran "$desc" sebesar Rp ${amt.toInt()} berhasil dicatat.',
              style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  void _showWarningDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 20),
            const SizedBox(width: 8),
            Text(title, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w900)),
          ],
        ),
        content: Text(message, style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w500)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Mengerti', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: const Color(0xFFB577F2))),
          )
        ],
      ),
    );
  }

  void _exportReport() {
    setState(() => _isExporting = true);
    Timer(const Duration(milliseconds: 1500), () {
      setState(() => _isExporting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF48C9B0),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Text(
                'Laporan PDF Buku Kas (Mei 2026) berhasil diunduh ke folder Downloads.',
                style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(landingPageProvider);
    final isDark = state.appearance == 'dark';

    final cardBg = isDark ? const Color(0xFF161619) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1B0C3C);
    final subtitleColor = isDark ? Colors.grey[400]! : const Color(0xFF6F6A8A);
    final borderColor = isDark ? const Color(0xFF252528) : const Color(0xFFECEEF2);
    final inputBg = isDark ? const Color(0xFF1E1E22) : const Color(0xFFF6F8FA);
    
    final purple = const Color(0xFFB577F2);
    final activeGreen = const Color(0xFF48C9B0);
    final isMobile = MediaQuery.of(context).size.width < 768;

    // Financial calculations
    final double totalPemasukan = _ledger
        .where((e) => e.tipe == 'Pemasukan')
        .map((e) => e.jumlah)
        .fold(0.0, (prev, element) => prev + element);

    final double totalPengeluaran = _ledger
        .where((e) => e.tipe == 'Pengeluaran')
        .map((e) => e.jumlah)
        .fold(0.0, (prev, element) => prev + element);

    final double saldoBersih = totalPemasukan - totalPengeluaran;
    final int totalTransaksi = _ledger.where((e) => e.tipe == 'Pemasukan').length;

    // Cash splits calculations
    final double cashTotal = _ledger
        .where((e) => e.tipe == 'Pemasukan' && e.metode == 'Cash')
        .map((e) => e.jumlah)
        .fold(0.0, (p, el) => p + el);
    final double qrisTotal = _ledger
        .where((e) => e.tipe == 'Pemasukan' && e.metode == 'QRIS')
        .map((e) => e.jumlah)
        .fold(0.0, (p, el) => p + el);
    final double bpjsTotal = _ledger
        .where((e) => e.tipe == 'Pemasukan' && e.metode == 'BPJS')
        .map((e) => e.jumlah)
        .fold(0.0, (p, el) => p + el);

    final double cashSplit = totalPemasukan > 0 ? (cashTotal / totalPemasukan) : 0.0;
    final double qrisSplit = totalPemasukan > 0 ? (qrisTotal / totalPemasukan) : 0.0;
    final double bpjsSplit = totalPemasukan > 0 ? (bpjsTotal / totalPemasukan) : 0.0;

    // Ledger filtered list
    final filteredLedger = _ledger.where((e) {
      final matchesFilter = _filterType == 'Semua' || e.tipe == _filterType;
      final matchesSearch = e.deskripsi.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          e.id.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          e.kategori.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesFilter && matchesSearch;
    }).toList();

    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // EMR Bookkeeping Header Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              margin: const EdgeInsets.only(bottom: 20),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: activeGreen.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Icon(Icons.account_balance_wallet_rounded, color: activeGreen, size: 18),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pembukuan & Billing',
                          style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w900, color: textColor),
                        ),
                        Text(
                          'Ringkasan arus kas masuk, pengeluaran klinik, dan e-resep diintegrasi',
                          style: GoogleFonts.outfit(fontSize: 10, color: subtitleColor, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _exportReport,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: activeGreen.withOpacity(0.12),
                      foregroundColor: activeGreen,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    child: Row(
                      children: [
                        _isExporting
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF48C9B0))))
                            : const Icon(Icons.picture_as_pdf_outlined, size: 14),
                        const SizedBox(width: 8),
                        Text('Ekspor Laporan', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () => setState(() => _showExpenseWizard = true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: purple,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.outbox_rounded, size: 14, color: Colors.white),
                        const SizedBox(width: 8),
                        Text('Catat Pengeluaran', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // A. METRICS OVERVIEW PANELS
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: isMobile ? 2 : 4,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.6,
              children: [
                _buildMetricCard(Icons.trending_up_rounded, 'TOTAL PEMASUKAN', 'Rp ${totalPemasukan.toInt()}', subtitleColor, activeGreen, cardBg, borderColor, 'Gross Month Revenue'),
                _buildMetricCard(Icons.assignment_turned_in_rounded, 'TOTAL TRANSAKSI', '$totalTransaksi Transaksi', subtitleColor, textColor, cardBg, borderColor, 'Completed Billable visits'),
                _buildMetricCard(Icons.trending_down_rounded, 'TOTAL PENGELUARAN', 'Rp ${totalPengeluaran.toInt()}', subtitleColor, Colors.redAccent, cardBg, borderColor, 'Clinic operational cost'),
                _buildMetricCard(Icons.account_balance_wallet_rounded, 'SALDO BERSIH (NET)', 'Rp ${saldoBersih.toInt()}', subtitleColor, purple, cardBg, borderColor, 'Gross - Operational Costs'),
              ],
            ),

            const SizedBox(height: 24),

            // B. SPLIT PAYMENT METHOD PROGRESS METERS
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PERSENTASE METODE PEMBAYARAN',
                    style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w900, color: subtitleColor, letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildProgressMeter('Umum / Cash', 'Rp ${cashTotal.toInt()}', cashSplit, Colors.amber, subtitleColor, textColor),
                      ),
                      const SizedBox(width: 32),
                      Expanded(
                        child: _buildProgressMeter('Transfer / QRIS', 'Rp ${qrisTotal.toInt()}', qrisSplit, purple, subtitleColor, textColor),
                      ),
                      const SizedBox(width: 32),
                      Expanded(
                        child: _buildProgressMeter('Klaim BPJS', 'Rp ${bpjsTotal.toInt()}', bpjsSplit, activeGreen, subtitleColor, textColor),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // C. TRANSACTIONS LEDGER BLOCK
            Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: borderColor),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Title + filters row
                  Row(
                    children: [
                      Text(
                        'BUKU KAS & RIWAYAT TRANSAKSI',
                        style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w900, color: subtitleColor, letterSpacing: 0.5),
                      ),
                      const Spacer(),
                      
                      // Search bar
                      Container(
                        width: 200,
                        height: 36,
                        decoration: BoxDecoration(
                          color: inputBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: borderColor),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        alignment: Alignment.center,
                        child: Row(
                          children: [
                            Icon(Icons.search_rounded, size: 14, color: subtitleColor),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: textColor),
                                decoration: InputDecoration(
                                  hintText: 'Cari transaksi...',
                                  hintStyle: GoogleFonts.outfit(fontSize: 10, color: subtitleColor.withOpacity(0.5)),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                                onChanged: (val) => setState(() => _searchQuery = val),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(width: 14),

                      // Filter chips
                      _buildFilterChip('Semua', purple),
                      const SizedBox(width: 6),
                      _buildFilterChip('Pemasukan', activeGreen),
                      const SizedBox(width: 6),
                      _buildFilterChip('Pengeluaran', Colors.redAccent),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Ledger Data Table
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: borderColor),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Table(
                        columnWidths: const {
                          0: FlexColumnWidth(1.2),
                          1: FlexColumnWidth(1.2),
                          2: FlexColumnWidth(3.0),
                          3: FlexColumnWidth(1.2),
                          4: FlexColumnWidth(1.0),
                          5: FlexColumnWidth(1.4),
                          6: FlexColumnWidth(1.0),
                        },
                        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                        children: [
                          // Table Header
                          TableRow(
                            decoration: BoxDecoration(
                              color: inputBg,
                              border: Border(bottom: BorderSide(color: borderColor)),
                            ),
                            children: [
                              _tableHeader('KODE TRX', subtitleColor),
                              _tableHeader('TANGGAL', subtitleColor),
                              _tableHeader('KATEGORI / DESKRIPSI', subtitleColor),
                              _tableHeader('TIPE', subtitleColor),
                              _tableHeader('METODE', subtitleColor),
                              _tableHeader('JUMLAH', subtitleColor),
                              _tableHeader('STATUS', subtitleColor),
                            ],
                          ),
                          // Table Rows
                          ...filteredLedger.map((entry) => TableRow(
                                decoration: BoxDecoration(
                                  border: Border(bottom: BorderSide(color: borderColor)),
                                  color: _selectedEntry?.id == entry.id ? purple.withOpacity(0.04) : Colors.transparent,
                                ),
                                children: [
                                  _tableCell(
                                    InkWell(
                                      onTap: () => setState(() => _selectedEntry = entry),
                                      child: Text(entry.id, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: purple)),
                                    ),
                                  ),
                                  _tableCell(Text('${entry.tanggal}\n${entry.waktu}', style: GoogleFonts.outfit(fontSize: 9, color: subtitleColor, fontWeight: FontWeight.bold))),
                                  _tableCell(
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: (entry.tipe == 'Pemasukan' ? activeGreen : Colors.redAccent).withOpacity(0.08),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(entry.kategori.toUpperCase(), style: GoogleFonts.outfit(fontSize: 6.5, fontWeight: FontWeight.w900, color: entry.tipe == 'Pemasukan' ? activeGreen : Colors.redAccent)),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(entry.deskripsi, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: textColor)),
                                      ],
                                    ),
                                  ),
                                  _tableCell(Text(entry.tipe, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: entry.tipe == 'Pemasukan' ? activeGreen : Colors.redAccent))),
                                  _tableCell(Text(entry.metode, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: textColor))),
                                  _tableCell(
                                    Text(
                                      '${entry.tipe == 'Pemasukan' ? '+' : '-'} Rp ${entry.jumlah.toInt()}',
                                      style: GoogleFonts.outfit(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w900,
                                        color: entry.tipe == 'Pemasukan' ? activeGreen : Colors.redAccent,
                                      ),
                                    ),
                                  ),
                                  _tableCell(
                                    entry.status == '-'
                                        ? Text('-', style: GoogleFonts.outfit(fontSize: 11, color: subtitleColor))
                                        : Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: (entry.status == 'Lunas' ? activeGreen : purple).withOpacity(0.12),
                                              borderRadius: BorderRadius.circular(100),
                                            ),
                                            alignment: Alignment.center,
                                            child: Text(
                                              entry.status,
                                              style: GoogleFonts.outfit(fontSize: 8, fontWeight: FontWeight.w900, color: entry.status == 'Lunas' ? activeGreen : purple),
                                            ),
                                          ),
                                  ),
                                ],
                              )),
                        ],
                      ),
                    ),
                  ),

                  if (filteredLedger.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      alignment: Alignment.center,
                      child: Text('Tidak ada catatan keuangan ditemukan.', style: GoogleFonts.outfit(fontSize: 11, color: subtitleColor, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
            ),
          ],
        ),

        // D. EXPENSE WIZARD OVERLAY MODAL
        if (_showExpenseWizard)
          _buildExpenseWizardModal(cardBg, textColor, subtitleColor, borderColor, inputBg, purple),

        // E. DETAILED INVOICE MODAL
        if (_selectedEntry != null)
          _buildInvoiceModal(cardBg, textColor, subtitleColor, borderColor, inputBg, purple, activeGreen),
      ],
    );
  }

  // ─── Component Helper: Metric Card ─────────────────────────────────────────

  Widget _buildMetricCard(
    IconData icon,
    String label,
    String value,
    Color subCol,
    Color valueCol,
    Color bg,
    Color border,
    String subtitleDesc,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: border),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: GoogleFonts.outfit(fontSize: 8, fontWeight: FontWeight.w900, color: subCol, letterSpacing: 0.5),
              ),
              Icon(icon, size: 14, color: subCol.withOpacity(0.5)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900, color: valueCol),
          ),
          Text(
            subtitleDesc,
            style: GoogleFonts.outfit(fontSize: 7.5, color: subCol, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // ─── Component Helper: Split Progress Meter ────────────────────────────────

  Widget _buildProgressMeter(
    String label,
    String value,
    double pct,
    Color color,
    Color subCol,
    Color valCol,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: valCol)),
            Text(value, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: color)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(100),
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: subCol.withOpacity(0.08),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 4),
        Text('${(pct * 100).toInt()}% dari total pemasukan', style: GoogleFonts.outfit(fontSize: 8, color: subCol, fontWeight: FontWeight.bold)),
      ],
    );
  }

  // ─── Component Helper: Filter Chips ────────────────────────────────────────

  Widget _buildFilterChip(String type, Color activeColor) {
    final isSelected = _filterType == type;
    return InkWell(
      onTap: () => setState(() => _filterType = type),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? activeColor : Colors.transparent),
        ),
        child: Text(
          type,
          style: GoogleFonts.outfit(
            fontSize: 9.5,
            fontWeight: FontWeight.w900,
            color: isSelected ? activeColor : const Color(0xFF6F6A8A),
          ),
        ),
      ),
    );
  }

  // ─── Component Helper: Tables cells ────────────────────────────────────────

  Widget _tableHeader(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Text(text, style: GoogleFonts.outfit(fontSize: 8, fontWeight: FontWeight.w900, color: color, letterSpacing: 0.5)),
    );
  }

  Widget _tableCell(Widget child) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: child,
    );
  }

  // ─── Component: Expense Recorder Modal ─────────────────────────────────────

  Widget _buildExpenseWizardModal(
    Color cardBg,
    Color text,
    Color subtitle,
    Color border,
    Color inputBg,
    Color purple,
  ) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.3),
        alignment: Alignment.center,
        child: Container(
          width: 440,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: border),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                        alignment: Alignment.center,
                        child: const Icon(Icons.outbox_rounded, color: Colors.redAccent, size: 16),
                      ),
                      const SizedBox(width: 12),
                      Text('Catat Pengeluaran Baru', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w900, color: text)),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () => setState(() => _showExpenseWizard = false),
                  ),
                ],
              ),
              const Divider(height: 24),
              
              Text('Deskripsi Pengeluaran *', style: GoogleFonts.outfit(fontSize: 9.5, fontWeight: FontWeight.w900, color: text)),
              const SizedBox(height: 6),
              TextField(
                controller: _expDescController,
                style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: text),
                decoration: InputDecoration(
                  hintText: 'cth. Pembelian Reagen Golongan Darah & Syringe',
                  hintStyle: GoogleFonts.outfit(fontSize: 11, color: subtitle.withOpacity(0.5)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                  filled: true,
                  fillColor: inputBg,
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: border)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: purple)),
                ),
              ),

              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Kategori Pengeluaran *', style: GoogleFonts.outfit(fontSize: 9.5, fontWeight: FontWeight.w900, color: text)),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: inputBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: border),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _expCategory,
                              isExpanded: true,
                              icon: Icon(Icons.arrow_drop_down, color: subtitle),
                              style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: text),
                              dropdownColor: cardBg,
                              onChanged: (val) {
                                if (val != null) setState(() => _expCategory = val);
                              },
                              items: ['Obat & Medis', 'Operasional', 'Gaji Staff', 'Lain-lain']
                                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                                  .toList(),
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
                        Text('Jumlah Nominal (Rp) *', style: GoogleFonts.outfit(fontSize: 9.5, fontWeight: FontWeight.w900, color: text)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _expAmountController,
                          keyboardType: TextInputType.number,
                          style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: text),
                          decoration: InputDecoration(
                            hintText: 'cth. 150000',
                            hintStyle: GoogleFonts.outfit(fontSize: 11, color: subtitle.withOpacity(0.5)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                            filled: true,
                            fillColor: inputBg,
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: border)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: purple)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => setState(() => _showExpenseWizard = false),
                    child: Text('Batal', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: subtitle)),
                  ),
                  const SizedBox(width: 14),
                  ElevatedButton(
                    onPressed: _saveExpense,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: purple,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    ),
                    child: Text('Simpan Pengeluaran', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Component: Detailed Invoice Popup ─────────────────────────────────────

  Widget _buildInvoiceModal(
    Color cardBg,
    Color text,
    Color subtitle,
    Color border,
    Color inputBg,
    Color purple,
    Color activeGreen,
  ) {
    final entry = _selectedEntry!;
    final isPemasukan = entry.tipe == 'Pemasukan';

    // Calculate invoice itemized splits
    final consultFee = isPemasukan ? min(entry.jumlah, 100000.0) : 0.0;
    final drugFee = isPemasukan ? (entry.jumlah - consultFee) : 0.0;

    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.3),
        alignment: Alignment.center,
        child: Container(
          width: 440,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: border),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 25, offset: const Offset(0, 8)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Detail Kwitansi Pembayaran', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w900, color: text)),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () => setState(() => _selectedEntry = null),
                  ),
                ],
              ),
              const Divider(height: 20),

              // Invoice Card Visual
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: border.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Invoice Clinic Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('MAPOTEK CLINIC', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: text)),
                            Text('Praktek Mandiri dr. Agoes Soetanto', style: GoogleFonts.outfit(fontSize: 7.5, color: subtitle, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: (isPemasukan ? activeGreen : Colors.redAccent).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(
                            entry.tipe.toUpperCase(),
                            style: GoogleFonts.outfit(fontSize: 7, fontWeight: FontWeight.w900, color: isPemasukan ? activeGreen : Colors.redAccent),
                          ),
                        ),
                      ],
                    ),
                    const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider(height: 1)),

                    // Metadata details
                    _invoiceMetaRow('Kode Transaksi', entry.id, text, subtitle),
                    const SizedBox(height: 6),
                    _invoiceMetaRow('Tanggal & Waktu', '${entry.tanggal} • ${entry.waktu}', text, subtitle),
                    if (isPemasukan) ...[
                      const SizedBox(height: 6),
                      _invoiceMetaRow('Pasien', entry.deskripsi.replaceFirst('Pemeriksaan RME - ', ''), text, subtitle),
                      const SizedBox(height: 6),
                      _invoiceMetaRow('Metode Pembayaran', entry.metode, text, subtitle),
                    ] else ...[
                      const SizedBox(height: 6),
                      _invoiceMetaRow('Kategori Biaya', entry.kategori, text, subtitle),
                    ],

                    const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider(height: 1)),
                    
                    // Rincian item
                    Text(
                      isPemasukan ? 'RINCIAN TRANSAKSI KLINIK' : 'RINCIAN PENGELUARAN KLINIK',
                      style: GoogleFonts.outfit(fontSize: 7.5, fontWeight: FontWeight.w900, color: subtitle, letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 10),
                    
                    if (isPemasukan) ...[
                      _invoiceItemRow('Jasa Pemeriksaan & Konsultasi Medis', 'Rp ${consultFee.toInt()}', text),
                      if (drugFee > 0) ...[
                        const SizedBox(height: 6),
                        _invoiceItemRow('Resep Digital & Terapi Obat', 'Rp ${drugFee.toInt()}', text),
                      ],
                    ] else ...[
                      _invoiceItemRow(entry.deskripsi, 'Rp ${entry.jumlah.toInt()}', text),
                    ],

                    const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1)),

                    // Total Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'TOTAL BAYAR',
                          style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: text),
                        ),
                        Text(
                          'Rp ${entry.jumlah.toInt()}',
                          style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w900, color: isPemasukan ? activeGreen : Colors.redAccent),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() => _selectedEntry = null);
                      },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: border),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('Tutup', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: subtitle)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() => _selectedEntry = null);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: activeGreen,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            content: Row(
                              children: [
                                const Icon(Icons.print_rounded, color: Colors.white, size: 18),
                                const SizedBox(width: 10),
                                Text(
                                  'Perintah cetak kwitansi ${entry.id} dikirim ke printer thermal.',
                                  style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: purple,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.print_rounded, size: 14, color: Colors.white),
                          const SizedBox(width: 8),
                          Text('Cetak Kwitansi', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white)),
                        ],
                      ),
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

  Widget _invoiceMetaRow(String label, String value, Color textCol, Color subCol) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.outfit(fontSize: 8.5, fontWeight: FontWeight.bold, color: subCol)),
        Text(value, style: GoogleFonts.outfit(fontSize: 8.5, fontWeight: FontWeight.w900, color: textCol)),
      ],
    );
  }

  Widget _invoiceItemRow(String name, String price, Color textCol) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: Text(name, style: GoogleFonts.outfit(fontSize: 9.5, fontWeight: FontWeight.bold, color: textCol))),
        const SizedBox(width: 14),
        Text(price, style: GoogleFonts.outfit(fontSize: 9.5, fontWeight: FontWeight.w900, color: textCol)),
      ],
    );
  }
}
