import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapotech/features/landing/landing_page_data.dart';
import 'package:mapotech/shared/widgets/empty_state_widget.dart';
import 'package:mapotech/shared/supabase_service.dart';

// ─── Data Models ─────────────────────────────────────────────────────────────

class RiwayatDokterEntry {
  final String id;
  final String date;
  final String time;
  final String doctorName;
  final String clinic;
  final String keluhan;
  final List<ObatDiberikan> obatDiberikan;
  final List<ResepDigital> resepDigital;
  final SuratRujukan? suratRujukan;
  final bool hasQrResep;

  const RiwayatDokterEntry({
    required this.id,
    required this.date,
    required this.time,
    required this.doctorName,
    required this.clinic,
    required this.keluhan,
    this.obatDiberikan = const [],
    this.resepDigital = const [],
    this.suratRujukan,
    this.hasQrResep = false,
  });
}

class ObatDiberikan {
  final String nama;
  final String aturan;
  final int jumlah;

  const ObatDiberikan({required this.nama, required this.aturan, required this.jumlah});
}

class ResepDigital {
  final String nama;
  final String aturan;
  final int jumlah;

  const ResepDigital({required this.nama, required this.aturan, required this.jumlah});
}

class SuratRujukan {
  final String namaRs;
  final String poli;
  final String noSurat;

  const SuratRujukan({required this.namaRs, required this.poli, required this.noSurat});
}

class RiwayatApotekEntry {
  final String id;
  final String date;
  final String time;
  final String apotekName;
  final String address;
  final String noStruk;
  final String metodeBayar;
  final String total;
  final List<ItemPembelian> items;

  const RiwayatApotekEntry({
    required this.id,
    required this.date,
    required this.time,
    required this.apotekName,
    required this.address,
    required this.noStruk,
    required this.metodeBayar,
    required this.total,
    required this.items,
  });
}

class ItemPembelian {
  final String nama;
  final String qty; // "10 x Rp 500"
  final String subtotal;

  const ItemPembelian({required this.nama, required this.qty, required this.subtotal});
}

// ─── Riwayat Page ────────────────────────────────────────────────────────────

class PasienHistory extends ConsumerStatefulWidget {
  const PasienHistory({super.key});

  @override
  ConsumerState<PasienHistory> createState() => _PasienHistoryState();
}

class _PasienHistoryState extends ConsumerState<PasienHistory>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final SupabaseService _db = SupabaseService();
  bool _isLoading = true;

  List<RiwayatDokterEntry> _riwayatDokter = [];
  List<RiwayatApotekEntry> _riwayatApotek = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadHistoryFromDatabase();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _formatDate(String rawDate) {
    if (rawDate.isEmpty) return 'Hari ini';
    try {
      final dt = DateTime.parse(rawDate);
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
        'Jul', 'Agt', 'Sep', 'Okt', 'Nov', 'Des'
      ];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return rawDate;
    }
  }

  String _formatPrice(double value) {
    return value.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        );
  }

  Future<void> _loadHistoryFromDatabase() async {
    final user = ref.read(landingPageProvider).loggedInUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }
    setState(() => _isLoading = true);
    try {
      final String patientName = user['name'] ?? '';

      // 1. Load Pharmacy Transactions
      final rawTxs = await _db.fetchFinancialTransactions();
      final List<RiwayatApotekEntry> loadedApotek = [];

      for (final tx in rawTxs) {
        final buyer = tx['buyer_name'] ?? 'Umum';
        if (buyer.toLowerCase().contains(patientName.toLowerCase())) {
          final id = tx['id'] ?? '';
          final dateRaw = tx['transaction_date'] ?? '';
          final amount = double.tryParse(tx['amount'] ?? '0') ?? 0.0;
          final method = tx['payment_method'] ?? 'Tunai';
          final dateFormatted = _formatDate(dateRaw);
          final receipt = id.length > 8 ? 'TX-${id.substring(0, 8).toUpperCase()}' : 'TX-$id';

          loadedApotek.add(RiwayatApotekEntry(
            id: id,
            date: dateFormatted,
            time: '08:00',
            apotekName: 'MAPOTECH KASIR APOTEK',
            address: 'Jl. Raya Bondowoso, Jawa Timur',
            noStruk: receipt,
            metodeBayar: method,
            total: 'Rp ${_formatPrice(amount)}',
            items: const [
              ItemPembelian(nama: 'Paracetamol 500mg', qty: '10 Strip x Rp 1.500', subtotal: 'Rp 15.000'),
            ],
          ));
        }
      }

      // 2. Load Doctor Clinical Encounters
      final rawQueues = await _db.fetchPatientQueues(user['id']);
      final List<RiwayatDokterEntry> loadedDokter = [];

      final queueIds = rawQueues.map((q) => q['id'] as String).toList();
      final rawEncounters = await _db.fetchClinicalEncounters(queueIds);

      for (final q in rawQueues) {
        final qId = q['id'];
        final doctorId = q['id_doctor'] ?? '';

        final encounter = rawEncounters.firstWhere((e) => e['id_queue'] == qId, orElse: () => <String, dynamic>{});
        final hasRujukan = encounter['is_rujukan'] ?? false;

        String doctorName = 'dr. Agoes Soetanto';
        if (doctorId.isNotEmpty) {
          final docUser = await _db.fetchUserById(doctorId);
          if (docUser != null) {
            doctorName = docUser['name'] ?? doctorName;
          }
        }

        final dateRaw = q['date_queue'] ?? '';
        final dateFormatted = _formatDate(dateRaw);

        loadedDokter.add(RiwayatDokterEntry(
          id: qId,
          date: dateFormatted,
          time: '09:00',
          doctorName: doctorName,
          clinic: 'Praktek Mandiri Dokter $doctorName',
          keluhan: encounter['rujukan_catatan'] ?? 'Pemeriksaan Rutin',
          suratRujukan: hasRujukan
              ? SuratRujukan(
                  namaRs: encounter['rujukan_rumah_sakit'] ?? 'RSUD dr. H. Koesnadi',
                  poli: encounter['rujukan_poli'] ?? 'Spesialis Penyakit Dalam',
                  noSurat: encounter['rujukan_nomor'] ?? 'REF-MOCK-123',
                )
              : null,
          hasQrResep: false,
        ));
      }

      setState(() {
        _riwayatApotek = loadedApotek;
        _riwayatDokter = loadedDokter;
        _isLoading = false;
      });
    } catch (_) {
      // offline fallback
      setState(() {
        _riwayatDokter = [
          const RiwayatDokterEntry(
            id: 'rd1',
            date: '23 Mei 2026',
            time: '18:54',
            doctorName: 'dr. Agoes Soetanto [Offline]',
            clinic: 'Dokter Praktek Mandiri Dokter Agoes Soetanto, dr',
            keluhan: '"Sakit perut, lehernya tegang"',
            suratRujukan: SuratRujukan(
              namaRs: 'RSUD dr.H Koesnadi',
              poli: 'Poli Dalam',
              noSurat: 'REF/2026/05/0001',
            ),
            hasQrResep: false,
          ),
          const RiwayatDokterEntry(
            id: 'rd2',
            date: '14 Mei 2026',
            time: '12:02',
            doctorName: 'dr. Agoes Soetanto [Offline]',
            clinic: 'Dokter Praktek Mandiri Dokter Agoes Soetanto, dr',
            keluhan: 'Kontrol rutin tekanan darah',
            obatDiberikan: [
              ObatDiberikan(nama: 'Paracetamol', aturan: '3 x 1', jumlah: 10),
            ],
            resepDigital: [
              ResepDigital(nama: 'Prednison', aturan: '3 x 1', jumlah: 10),
            ],
            hasQrResep: true,
          ),
        ];

        _riwayatApotek = [
          const RiwayatApotekEntry(
            id: 'ra1',
            date: '23 Mei 2026',
            time: '19:12',
            apotekName: 'MAPOTECH KASIR APOTEK [Offline]',
            address: 'Jl. Raya Bondowoso, Jawa Timur',
            noStruk: 'TX-20260523-0491',
            metodeBayar: 'Tunai',
            total: 'Rp 45.000',
            items: [
              ItemPembelian(nama: 'Paracetamol 500mg', qty: '10 Strip x Rp 1.500', subtotal: 'Rp 15.000'),
              ItemPembelian(nama: 'Amoxicillin 500mg', qty: '10 Strip x Rp 3.000', subtotal: 'Rp 30.000'),
            ],
          ),
        ];
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(landingPageProvider);
    final isDark = state.appearance == 'dark';
    final textColor = isDark ? Colors.white : const Color(0xFF1B0C3C);
    final subtitleColor = isDark ? Colors.grey[400]! : const Color(0xFF6F6A8A);
    final themeAccent = const Color(0xFFB577F2);
    final tabBgColor = isDark ? const Color(0xFF161619) : const Color(0xFFF3F0FA);

    return _isLoading
        ? Center(child: CircularProgressIndicator(color: themeAccent))
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Tab Bar ───────────────────────────────────────────────────────
              Container(
                height: 48,
                decoration: BoxDecoration(
                  color: tabBgColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(4),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  labelColor: const Color(0xFF1B0C3C),
                  unselectedLabelColor: subtitleColor,
                  labelStyle: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900),
                  unselectedLabelStyle: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold),
                  tabs: const [
                    Tab(text: 'Riwayat Dokter'),
                    Tab(text: 'Riwayat Apotek'),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // ── Tab View Content ──────────────────────────────────────────────
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab 1: Doctor Checkups
                    RefreshIndicator(
                      onRefresh: _loadHistoryFromDatabase,
                      color: themeAccent,
                      child: _riwayatDokter.isEmpty
                          ? Center(
                              child: EmptyStateWidget(
                                icon: Icons.medical_services_outlined,
                                title: 'Belum Ada Riwayat',
                                subtitle: 'Belum ada riwayat kunjungan dokter.',
                                cardBg: isDark ? const Color(0xFF161619) : Colors.white,
                                border: isDark ? const Color(0xFF252528) : const Color(0xFFECEEF2),
                                textColor: textColor,
                                subtitleColor: subtitleColor,
                              ),
                            )
                          : ListView.builder(
                              itemCount: _riwayatDokter.length,
                              itemBuilder: (context, index) {
                                final rd = _riwayatDokter[index];
                                return _buildDoctorCard(context, rd, isDark, textColor, subtitleColor, themeAccent);
                              },
                            ),
                    ),

                    // Tab 2: Pharmacy Purchases
                    RefreshIndicator(
                      onRefresh: _loadHistoryFromDatabase,
                      color: themeAccent,
                      child: _riwayatApotek.isEmpty
                          ? Center(
                              child: EmptyStateWidget(
                                icon: Icons.receipt_long_rounded,
                                title: 'Belum Ada Transaksi',
                                subtitle: 'Belum ada riwayat transaksi apotek.',
                                cardBg: isDark ? const Color(0xFF161619) : Colors.white,
                                border: isDark ? const Color(0xFF252528) : const Color(0xFFECEEF2),
                                textColor: textColor,
                                subtitleColor: subtitleColor,
                              ),
                            )
                          : ListView.builder(
                              itemCount: _riwayatApotek.length,
                              itemBuilder: (context, index) {
                                final ra = _riwayatApotek[index];
                                return _buildApotekCard(context, ra, isDark, textColor, subtitleColor, themeAccent);
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ],
          );
  }

  Widget _buildDoctorCard(
    BuildContext context,
    RiwayatDokterEntry rd,
    bool isDark,
    Color text,
    Color subtitle,
    Color purple,
  ) {
    final cardBg = isDark ? const Color(0xFF161619) : Colors.white;
    final border = isDark ? const Color(0xFF252528) : const Color(0xFFECEEF2);
    final blue = const Color(0xFF3498DB);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: purple.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.medical_services_outlined, color: purple, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rd.doctorName,
                      style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w900, color: text),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${rd.date} • ${rd.time}',
                      style: GoogleFonts.outfit(fontSize: 9, color: subtitle),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            rd.clinic,
            style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: subtitle),
          ),
          const SizedBox(height: 6),
          Text(
            'Keluhan: ${rd.keluhan}',
            style: GoogleFonts.outfit(fontSize: 11, color: text, fontStyle: FontStyle.italic),
          ),
          if (rd.suratRujukan != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: blue.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: blue.withOpacity(0.15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SURAT RUJUKAN ELEKTRONIK',
                    style: GoogleFonts.outfit(fontSize: 8, fontWeight: FontWeight.w900, color: blue, letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Dirujuk Ke: ${rd.suratRujukan!.namaRs}',
                    style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: text),
                  ),
                  Text(
                    'Spesialis / Poli: ${rd.suratRujukan!.poli} • No. Rujukan: ${rd.suratRujukan!.noSurat}',
                    style: GoogleFonts.outfit(fontSize: 10, color: subtitle),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildApotekCard(
    BuildContext context,
    RiwayatApotekEntry ra,
    bool isDark,
    Color text,
    Color subtitle,
    Color purple,
  ) {
    final cardBg = isDark ? const Color(0xFF161619) : Colors.white;
    final border = isDark ? const Color(0xFF252528) : const Color(0xFFECEEF2);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFF27AE60).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF27AE60), size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ra.noStruk,
                      style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w900, color: text),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${ra.date} • ${ra.time}',
                      style: GoogleFonts.outfit(fontSize: 9, color: subtitle),
                    ),
                  ],
                ),
              ),
              Text(
                ra.total,
                style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w900, color: purple),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${ra.apotekName} • ${ra.metodeBayar}',
            style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: subtitle),
          ),
          Text(
            ra.address,
            style: GoogleFonts.outfit(fontSize: 9, color: subtitle),
          ),
        ],
      ),
    );
  }
}
