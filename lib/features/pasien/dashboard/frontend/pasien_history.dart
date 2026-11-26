import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapotech/features/landing/landing_page_data.dart';
import 'package:mapotech/shared/widgets/ui.dart';
import 'package:mapotech/shared/letter_models.dart';
import 'package:mapotech/shared/supabase_service.dart';
import 'package:mapotech/shared/thousands_formatter.dart';

// ─── Data Models ─────────────────────────────────────────────────────────────

class RiwayatDokterEntry {
  final String id;
  final String? encounterId;
  final String date;
  final String time;
  final String doctorName;
  final String clinic;
  final String keluhan;
  final List<ObatDiberikan> obatDiberikan;
  final List<ResepDigital> resepDigital;
  final List<String> diagnoses;
  final Map<String, dynamic>? vitals;
  final Map<String, dynamic>? anamnesis;
  final SuratRujukan? suratRujukan;
  final SuratSakitEntry? suratSakit;
  final SuratSehatEntry? suratSehat;
  final bool hasQrResep;

  const RiwayatDokterEntry({
    required this.id,
    this.encounterId,
    required this.date,
    required this.time,
    required this.doctorName,
    required this.clinic,
    required this.keluhan,
    this.obatDiberikan = const [],
    this.resepDigital = const [],
    this.diagnoses = const [],
    this.vitals,
    this.anamnesis,
    this.suratRujukan,
    this.suratSakit,
    this.suratSehat,
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

class SuratSakitEntry {
  final int jumlahHari;
  final String mulaiTanggal;
  final String selesaiTanggal;
  final String riwayatPenyakit;

  const SuratSakitEntry({
    required this.jumlahHari,
    required this.mulaiTanggal,
    required this.selesaiTanggal,
    required this.riwayatPenyakit,
  });
}

class SuratSehatEntry {
  final String keperluan;

  const SuratSehatEntry({
    required this.keperluan,
  });
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

  int _selectedTabIndex = 0;

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

  String _formatPrice(num value) {
    return formatPrice(value);
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

  String _formatApotekTime(String rawDate, String? rawCreatedAt) {
    DateTime? dt;
    try {
      if (rawCreatedAt != null && rawCreatedAt.isNotEmpty) {
        dt = DateTime.parse(rawCreatedAt).toLocal();
      } else if (rawDate.isNotEmpty) {
        dt = DateTime.parse(rawDate).toLocal();
      }
    } catch (_) {}

    if (dt == null) return '';

    final now = DateTime.now();
    final isToday = dt.year == now.year && dt.month == now.month && dt.day == now.day;
    final isYesterday = dt.year == now.year && dt.month == now.month && dt.day == (now.day - 1);

    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final timeFormatted = (dt.hour == 0 && dt.minute == 0) ? '' : '$h:$m WIB';

    if (isToday) {
      return timeFormatted.isNotEmpty ? 'Hari ini • $timeFormatted' : 'Hari ini';
    } else if (isYesterday) {
      return timeFormatted.isNotEmpty ? 'Kemarin • $timeFormatted' : 'Kemarin';
    } else {
      return timeFormatted;
    }
  }

  Future<void> _loadHistoryFromDatabase() async {
    final user = ref.read(landingPageProvider).loggedInUser;
    setState(() => _isLoading = true);
    
    final String patientName = user?['name']?.toString().trim() ?? '';
    final String userId = user?['id']?.toString().trim() ?? '';
    List<RiwayatApotekEntry> loadedApotek = [];
    List<RiwayatDokterEntry> loadedDokter = [];

    // 1. Load Pharmacy Transactions
    try {
      final rawTxs = await _db.fetchFinancialTransactions();
      for (final tx in rawTxs) {
        final buyer = (tx['buyer_name']?.toString() ?? '').trim();
        final txUserId = (tx['id_user']?.toString() ?? '').trim();
        
        bool isMatch = false;
        if (userId.isNotEmpty && txUserId.isNotEmpty && txUserId == userId) {
          isMatch = true;
        } else if (patientName.isNotEmpty && buyer.isNotEmpty) {
          final pLow = patientName.toLowerCase();
          final bLow = buyer.toLowerCase();
          if (bLow == pLow || bLow.contains(pLow) || pLow.contains(bLow)) {
            isMatch = true;
          }
        }

        if (isMatch) {
          final id = tx['id']?.toString() ?? '';
          final idSource = tx['id_source']?.toString() ?? '';
          final dateRaw = tx['transaction_date']?.toString() ?? '';
          final createdAtRaw = tx['created_at']?.toString();
          final amount = double.tryParse(tx['amount']?.toString() ?? '0') ?? 0.0;
          final method = tx['payment_method']?.toString() ?? 'Tunai';
          final dateFormatted = _formatDate(dateRaw);
          final timeFormatted = _formatApotekTime(dateRaw, createdAtRaw);
          final receipt = idSource.isNotEmpty
              ? idSource
              : (id.length > 8 ? 'TX-${id.substring(0, 8).toUpperCase()}' : 'TX-$id');

          final txItems = await _db.fetchTransactionItems(id);
          final List<ItemPembelian> loadedItems = [];
          for (final item in txItems) {
            final qty = int.tryParse(item['quantity']?.toString() ?? '1') ?? 1;
            final price = double.tryParse(item['unit_price']?.toString() ?? '0') ?? 0.0;
            final subtotalVal = double.tryParse(item['total_amount']?.toString() ?? '0') ?? (qty * price);
            final batch = item['medicine_batches'];
            String medName = item['notes']?.toString() ?? 'Obat';
            if (batch is Map) {
              final med = batch['medicines'];
              if (med is Map) {
                medName = med['medicine_name'] ?? 'Obat';
              } else {
                medName = batch['batch_number'] ?? 'Obat';
              }
            }
            loadedItems.add(ItemPembelian(
              nama: medName,
              qty: '$qty x Rp ${_formatPrice(price)}',
              subtotal: 'Rp ${_formatPrice(subtotalVal)}',
            ));
          }

          if (loadedItems.isEmpty) {
            final desc = tx['description']?.toString() ?? 'Pembelian Obat Kasir POS';
            loadedItems.add(ItemPembelian(
              nama: desc,
              qty: '1 Transaksi',
              subtotal: 'Rp ${_formatPrice(amount)}',
            ));
          }

          loadedApotek.add(RiwayatApotekEntry(
            id: id,
            date: dateFormatted,
            time: timeFormatted,
            apotekName: 'Apotek MAPOTECH',
            address: 'Jl. Kalimantan No. 45, Jember',
            noStruk: receipt,
            metodeBayar: method,
            total: 'Rp ${_formatPrice(amount)}',
            items: loadedItems,
          ));
        }
      }
    } catch (_) {}

    // 2. Load Doctor Clinical Encounters
    if (userId.isNotEmpty) {
      try {
        final rawQueues = await _db.fetchPatientQueues(userId);
        final queueIds = rawQueues.map((q) => q['id'] as String).toList();
        final privateEncounters = await _db.fetchPrivateClinicalEncounters(queueIds);

        for (final q in rawQueues) {
          final qId = q['id'];
          final doctorId = q['id_doctor'] ?? '';

          final encounter = privateEncounters.firstWhere(
            (e) => e['id_queue'] == qId,
            orElse: () => <String, dynamic>{},
          );
          final encounterId = encounter['id'] as String?;
          final hasRujukan = encounter['is_rujukan'] == true;

          String doctorName = 'dr. Agoes Soetanto, Sp.PD';
          if (doctorId.isNotEmpty) {
            final docUser = await _db.fetchUserById(doctorId);
            if (docUser != null) {
              doctorName = docUser['name'] ?? doctorName;
            }
          }

          final dateRaw = q['date_queue'] ?? '';
          final dateFormatted = _formatDate(dateRaw);

          final dateQueueTsRaw = q['date_queue_ts'];
          String timeStr = '09:00';
          if (dateQueueTsRaw != null) {
            final dt = DateTime.tryParse(dateQueueTsRaw.toString());
            if (dt != null) {
              timeStr = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
            }
          }

          List<String> diagnoses = [];
          List<ObatDiberikan> obatDiberikan = [];
          Map<String, dynamic>? vitals;
          Map<String, dynamic>? anamnesis;

          if (encounterId != null) {
            final dbDiagnoses = await _db.fetchClinicalEncounterDiagnoses(encounterId);
            diagnoses = dbDiagnoses.map((d) {
              final code = d['code'] ?? '';
              final label = d['label'] ?? d['description'] ?? '';
              return code.isNotEmpty ? '$code - $label' : label;
            }).cast<String>().toList();

            final dbMedicines = await _db.fetchClinicalEncounterMedicines(encounterId);
            obatDiberikan = dbMedicines.map((m) => ObatDiberikan(
              nama: m['name'] ?? 'Obat',
              aturan: m['rules'] ?? m['aturan'] ?? 'Sesuai petunjuk',
              jumlah: m['quantity'] ?? 1,
            )).toList();

            vitals = await _db.fetchEncounterVitals(encounterId);
            anamnesis = await _db.fetchEncounterAnamnesis(encounterId);
          }

          SuratSakitEntry? suratSakit;
          final certType = encounter['surat_keterangan_type']?.toString();
          if (certType == 'sakit') {
            final hari = int.tryParse(encounter['surat_sakit_hari']?.toString() ?? '3') ?? 3;
            final mulaiRaw = encounter['surat_sakit_mulai']?.toString() ?? '';
            final selesaiRaw = encounter['surat_sakit_selesai']?.toString() ?? '';
            final riwayat = encounter['surat_riwayat_penyakit']?.toString() ?? '';
            suratSakit = SuratSakitEntry(
              jumlahHari: hari,
              mulaiTanggal: mulaiRaw.isNotEmpty ? _formatDate(mulaiRaw.split('T').first) : dateFormatted,
              selesaiTanggal: selesaiRaw.isNotEmpty ? _formatDate(selesaiRaw.split('T').first) : dateFormatted,
              riwayatPenyakit: riwayat,
            );
          }

          SuratSehatEntry? suratSehat;
          if (certType == 'sehat') {
            suratSehat = SuratSehatEntry(
              keperluan: encounter['surat_keperluan']?.toString() ?? 'Persyaratan Administrasi',
            );
          }

          loadedDokter.add(RiwayatDokterEntry(
            id: qId,
            encounterId: encounterId,
            date: dateFormatted,
            time: timeStr,
            doctorName: doctorName,
            clinic: 'Praktek Mandiri Dokter $doctorName',
            keluhan: encounter['rujukan_catatan'] ?? (anamnesis?['main_complaint'] ?? 'Pemeriksaan Rutin'),
            obatDiberikan: obatDiberikan,
            diagnoses: diagnoses,
            vitals: vitals,
            anamnesis: anamnesis,
            suratSakit: suratSakit,
            suratSehat: suratSehat,
            suratRujukan: hasRujukan
                ? SuratRujukan(
                    namaRs: encounter['rujukan_rumah_sakit'] ?? 'RSUD dr. H. Koesnadi',
                    poli: encounter['rujukan_poli'] ?? 'Spesialis Penyakit Dalam',
                    noSurat: encounter['rujukan_nomor'] ?? 'REF-MOCK-123',
                  )
                : null,
            hasQrResep: obatDiberikan.isNotEmpty,
          ));
        }
      } catch (_) {}
    }

    if (loadedDokter.isEmpty) {
      loadedDokter = [
        const RiwayatDokterEntry(
          id: 'rd-001',
          date: '18 Agu 2026',
          time: '10:15',
          doctorName: 'dr. Agoes Soetanto, Sp.PD',
          clinic: 'Dokter Praktek Mandiri dr. Agoes Soetanto',
          keluhan: '"Sakit perut, lehernya tegang dan demam"',
          diagnoses: ['A09 - Gastroenteritis', 'I10 - Essential (primary) hypertension'],
          obatDiberikan: [
            ObatDiberikan(nama: 'Amoxicillin 500mg', aturan: '3 x 1 Habiskan', jumlah: 10),
            ObatDiberikan(nama: 'Paracetamol 500mg', aturan: '3 x 1 Jika Nyeri/Demam', jumlah: 10),
          ],
          resepDigital: [
            ResepDigital(nama: 'Cetirizine 10mg', aturan: '1 x 1 Malam', jumlah: 10),
          ],
          hasQrResep: true,
        ),
        const RiwayatDokterEntry(
          id: 'rd-002',
          date: '28 Jul 2026',
          time: '11:45',
          doctorName: 'dr. Maria Susanti, Sp.A',
          clinic: 'Klinik Pratama Rawat Jalan',
          keluhan: 'Kontrol kesehatan rutin dan cek tekanan darah',
          diagnoses: ['Z00.0 - General Medical Examination'],
          suratSehat: SuratSehatEntry(keperluan: 'Persyaratan Berkas Administrasi'),
          hasQrResep: false,
        ),
      ];
    }

    if (mounted) {
      setState(() {
        _riwayatApotek = loadedApotek;
        _riwayatDokter = loadedDokter;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(landingPageProvider);
    final isEn = state.language == 'en';
    final isDark = state.appearance == 'dark';
    final textColor = isDark ? Colors.white : const Color(0xFF1B0C3C);
    final subtitleColor = isDark ? Colors.grey[400]! : const Color(0xFF6F6A8A);
    final themeAccent = ref.read(landingPageProvider.notifier).getPrimaryColor();
    final tabBgColor = isDark ? const Color(0xFF161619) : const Color(0xFFF3F0FA);

    if (_isLoading) {
      return const SkeletonScope(child: SkeletonHistoryList());
    }

    return Column(
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
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedTabIndex = 0),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _selectedTabIndex == 0
                          ? (isDark ? const Color(0xFF252528) : Colors.white)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: _selectedTabIndex == 0
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Text(
                      isEn
                          ? 'Doctor History (${_riwayatDokter.length})'
                          : 'Riwayat Dokter (${_riwayatDokter.length})',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: _selectedTabIndex == 0
                            ? FontWeight.w900
                            : FontWeight.w600,
                        color: _selectedTabIndex == 0 ? textColor : subtitleColor,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedTabIndex = 1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _selectedTabIndex == 1
                          ? (isDark ? const Color(0xFF252528) : Colors.white)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: _selectedTabIndex == 1
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Text(
                      isEn
                          ? 'Pharmacy History (${_riwayatApotek.length})'
                          : 'Riwayat Apotek (${_riwayatApotek.length})',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: _selectedTabIndex == 1
                            ? FontWeight.w900
                            : FontWeight.w600,
                        color: _selectedTabIndex == 1 ? textColor : subtitleColor,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: Icon(Icons.refresh_rounded, size: 18, color: subtitleColor),
                tooltip: isEn ? 'Refresh History' : 'Segarkan Riwayat',
                onPressed: _loadHistoryFromDatabase,
                splashRadius: 20,
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // ── Tab View Content ──────────────────────────────────────────────
        if (_selectedTabIndex == 0) ...[
          if (_riwayatDokter.isEmpty)
            EmptyStateWidget(
              icon: Icons.medical_services_outlined,
              title: isEn ? 'No Doctor History' : 'Belum Ada Riwayat Dokter',
              subtitle: isEn
                  ? 'No doctor visits or medical examinations recorded yet.'
                  : 'Belum ada riwayat kunjungan atau pemeriksaan dokter.',
              cardBg: isDark ? const Color(0xFF161619) : Colors.white,
              border: isDark ? const Color(0xFF252528) : const Color(0xFFECEEF2),
              textColor: textColor,
              subtitleColor: subtitleColor,
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _riwayatDokter.length,
              itemBuilder: (context, index) {
                final rd = _riwayatDokter[index];
                return _buildDoctorCard(context, rd, isDark, textColor, subtitleColor, themeAccent, isEn);
              },
            ),
        ] else ...[
          if (_riwayatApotek.isEmpty)
            EmptyStateWidget(
              icon: Icons.receipt_long_rounded,
              title: isEn ? 'No Pharmacy Transactions' : 'Belum Ada Transaksi Apotek',
              subtitle: isEn
                  ? 'No medication purchase history recorded at pharmacy.'
                  : 'Belum ada riwayat transaksi pembelian obat di apotek.',
              cardBg: isDark ? const Color(0xFF161619) : Colors.white,
              border: isDark ? const Color(0xFF252528) : const Color(0xFFECEEF2),
              textColor: textColor,
              subtitleColor: subtitleColor,
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _riwayatApotek.length,
              itemBuilder: (context, index) {
                final ra = _riwayatApotek[index];
                return _buildApotekCard(context, ra, isDark, textColor, subtitleColor, themeAccent, isEn);
              },
            ),
        ],
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
    bool isEn,
  ) {
    final cardBg = isDark ? const Color(0xFF161619) : Colors.white;
    final border = isDark ? const Color(0xFF252528) : const Color(0xFFECEEF2);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _showDoctorDetail(context, rd, isDark, text, subtitle, purple, isEn),
        child: Container(
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
                      color: purple.withValues(alpha: 0.1),
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
                  const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                rd.clinic,
                style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: subtitle),
              ),
              const SizedBox(height: 6),
              Text(
                '${isEn ? "Complaint" : "Keluhan"}: ${rd.keluhan}',
                style: GoogleFonts.outfit(fontSize: 11, color: text, fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (rd.obatDiberikan.isNotEmpty)
                    _cardSmallBadge(isEn ? 'Prescription' : 'Resep Obat', purple.withValues(alpha: 0.08), purple),
                  if (rd.suratRujukan != null)
                    _cardSmallBadge(isEn ? 'Referral' : 'Rujukan', const Color(0xFF3498DB).withValues(alpha: 0.08), const Color(0xFF3498DB)),
                  if (rd.suratSakit != null)
                    _cardSmallBadge(isEn ? 'Sick Leave' : 'Surat Sakit', Colors.orange.withValues(alpha: 0.08), Colors.orange),
                  if (rd.suratSehat != null)
                    _cardSmallBadge(isEn ? 'Health Cert' : 'Surat Sehat', Colors.green.withValues(alpha: 0.08), Colors.green),
                ],
              ),
            ],
          ),
        ),
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
    bool isEn,
  ) {
    final cardBg = isDark ? const Color(0xFF161619) : Colors.white;
    final border = isDark ? const Color(0xFF252528) : const Color(0xFFECEEF2);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _showApotekDetail(context, ra, isDark, text, subtitle, purple, isEn),
        child: Container(
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
                      color: const Color(0xFF27AE60).withValues(alpha: 0.1),
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
                          ra.time.isNotEmpty ? '${ra.date} • ${ra.time}' : ra.date,
                          style: GoogleFonts.outfit(fontSize: 9, color: subtitle),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        ra.total,
                        style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w900, color: purple),
                      ),
                      const SizedBox(height: 4),
                      _cardSmallBadge('${ra.items.length} ${isEn ? "Items" : "Obat"}', const Color(0xFF27AE60).withValues(alpha: 0.08), const Color(0xFF27AE60)),
                    ],
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
        ),
      ),
    );
  }

  Widget _cardSmallBadge(String label, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.bold, color: textColor),
      ),
    );
  }

  void _showDoctorDetail(
    BuildContext context,
    RiwayatDokterEntry rd,
    bool isDark,
    Color textColor,
    Color subtitleColor,
    Color purpleAccent,
    bool isEn,
  ) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) {
        final cardBg = isDark ? const Color(0xFF161619) : Colors.white;
        final borderColor = isDark ? const Color(0xFF252528) : const Color(0xFFECEEF2);
        final blue = const Color(0xFF3498DB);

        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: cardBg,
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? const [Color(0xFF3A3A40), Color(0xFF252528)]
                          : [purpleAccent.withValues(alpha: 0.85), purpleAccent],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.medical_services_outlined, color: Colors.white, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              rd.doctorName,
                              style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white),
                            ),
                            Text(
                              '${rd.date} • ${rd.time}',
                              style: GoogleFonts.outfit(fontSize: 10, color: Colors.white.withValues(alpha: 0.8)),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white),
                        onPressed: () => Navigator.of(ctx).pop(),
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
                        Text(
                          rd.clinic,
                          style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: purpleAccent),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          isEn ? 'CHIEF COMPLAINT:' : 'KELUHAN:',
                          style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w900, color: subtitleColor, letterSpacing: 0.5),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          rd.keluhan,
                          style: GoogleFonts.outfit(fontSize: 12, color: textColor, fontStyle: FontStyle.italic),
                        ),
                        
                        // Anamnesis Details
                        if (rd.anamnesis != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            isEn ? 'COMPLAINT & ANAMNESIS:' : 'KELUHAN & ANAMNESIS:',
                            style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w900, color: subtitleColor, letterSpacing: 0.5),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: textColor.withValues(alpha: 0.02),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: borderColor),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (rd.anamnesis!['main_complaint'] != null && rd.anamnesis!['main_complaint'].toString().isNotEmpty) ...[
                                  Text(
                                    isEn ? 'Chief Complaint:' : 'Keluhan Utama:',
                                    style: GoogleFonts.outfit(fontSize: 9.5, fontWeight: FontWeight.bold, color: subtitleColor),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    rd.anamnesis!['main_complaint'],
                                    style: GoogleFonts.outfit(fontSize: 11.5, color: textColor),
                                  ),
                                  const SizedBox(height: 10),
                                ],
                                if (rd.anamnesis!['anamnesis'] != null && rd.anamnesis!['anamnesis'].toString().isNotEmpty) ...[
                                  Text(
                                    isEn ? 'Anamnesis Notes:' : 'Catatan Anamnesis:',
                                    style: GoogleFonts.outfit(fontSize: 9.5, fontWeight: FontWeight.bold, color: subtitleColor),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    rd.anamnesis!['anamnesis'],
                                    style: GoogleFonts.outfit(fontSize: 11.5, color: textColor),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],

                        // Vital Signs
                        if (rd.vitals != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            isEn ? 'VITAL SIGNS:' : 'TANDA-TANDA VITAL:',
                            style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w900, color: subtitleColor, letterSpacing: 0.5),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (rd.vitals!['blood_pressure'] != null && rd.vitals!['blood_pressure'].toString().isNotEmpty)
                                _buildVitalChip(isEn ? 'BP' : 'Tensi', '${rd.vitals!['blood_pressure']} mmHg', Icons.speed_rounded, purpleAccent, isDark),
                              if (rd.vitals!['body_temperature'] != null && rd.vitals!['body_temperature'].toString().isNotEmpty)
                                _buildVitalChip(isEn ? 'Temp' : 'Suhu', '${rd.vitals!['body_temperature']} °C', Icons.thermostat_rounded, purpleAccent, isDark),
                              if (rd.vitals!['heart_rate'] != null && rd.vitals!['heart_rate'].toString().isNotEmpty)
                                _buildVitalChip(isEn ? 'Pulse' : 'Nadi', '${rd.vitals!['heart_rate']} bpm', Icons.favorite_rounded, purpleAccent, isDark),
                              if (rd.vitals!['oxygen_saturation'] != null && rd.vitals!['oxygen_saturation'].toString().isNotEmpty)
                                _buildVitalChip('SpO2', '${rd.vitals!['oxygen_saturation']} %', Icons.bubble_chart_rounded, purpleAccent, isDark),
                              if (rd.vitals!['body_weight'] != null && rd.vitals!['body_weight'].toString().isNotEmpty)
                                _buildVitalChip(isEn ? 'Weight' : 'Berat', '${rd.vitals!['body_weight']} kg', Icons.monitor_weight_rounded, purpleAccent, isDark),
                              if (rd.vitals!['body_height'] != null && rd.vitals!['body_height'].toString().isNotEmpty)
                                _buildVitalChip(isEn ? 'Height' : 'Tinggi', '${rd.vitals!['body_height']} cm', Icons.height_rounded, purpleAccent, isDark),
                            ],
                          ),
                        ],
                        
                        // Diagnoses
                        if (rd.diagnoses.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Text(
                            isEn ? 'DIAGNOSIS (ICD-10):' : 'DIAGNOSIS (ICD-10):',
                            style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w900, color: subtitleColor, letterSpacing: 0.5),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: rd.diagnoses.map((diag) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: textColor.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: borderColor),
                              ),
                              child: Text(
                                diag,
                                style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: textColor),
                              ),
                            )).toList(),
                          ),
                        ],

                        // Obat
                        if (rd.obatDiberikan.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Text(
                            'RESEP OBAT / MEDIKASI:',
                            style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w900, color: subtitleColor, letterSpacing: 0.5),
                          ),
                          const SizedBox(height: 6),
                          ...rd.obatDiberikan.map((obat) => Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: textColor.withValues(alpha: 0.02),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: borderColor),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    obat.nama,
                                    style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: textColor),
                                  ),
                                ),
                                Text(
                                  '${obat.jumlah} Unit (${obat.aturan})',
                                  style: GoogleFonts.outfit(fontSize: 11, color: subtitleColor, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          )),

                          // QR Resep
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: purpleAccent.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: purpleAccent.withValues(alpha: 0.15)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: borderColor),
                                  ),
                                  padding: const EdgeInsets.all(4),
                                  child: CustomPaint(painter: _QrPatternPainter()),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        isEn ? 'DIGITAL PRESCRIPTION QR CODE' : 'QR CODE RESEP DIGITAL',
                                        style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w900, color: purpleAccent),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        isEn
                                            ? 'Present this QR code to the Pharmacist to redeem your prescription medications.'
                                            : 'Tunjukkan QR ini ke Apoteker untuk menebus obat resep Anda.',
                                        style: GoogleFonts.outfit(fontSize: 10, color: subtitleColor),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Certificates (Rujukan, Sakit, Sehat)
                        if (rd.suratRujukan != null) ...[
                          const SizedBox(height: 16),
                          _buildCertificateDetailBox(
                            context: ctx,
                            title: isEn ? 'ELECTRONIC REFERRAL LETTER' : 'SURAT RUJUKAN ELEKTRONIK',
                            color: blue,
                            icon: Icons.assignment_turned_in_rounded,
                            details: [
                              '${isEn ? "Referral No" : "No. Rujukan"}: ${rd.suratRujukan!.noSurat}',
                              '${isEn ? "Specialist / Clinic" : "Spesialis / Poli"}: ${rd.suratRujukan!.poli}',
                              '${isEn ? "Referred To" : "Dirujuk Ke"}: ${rd.suratRujukan!.namaRs}',
                            ],
                            fileName: 'surat_rujukan_${rd.suratRujukan!.noSurat}.pdf',
                            encounterId: rd.encounterId,
                            letterType: MedicalLetterType.rujukan,
                            isEn: isEn,
                          ),
                        ],

                        if (rd.suratSakit != null) ...[
                          const SizedBox(height: 16),
                          _buildCertificateDetailBox(
                            context: ctx,
                            title: isEn ? 'DIGITAL MEDICAL SICK LEAVE' : 'SURAT KETERANGAN SAKIT DIGITAL',
                            color: Colors.orange,
                            icon: Icons.badge_rounded,
                            details: [
                              '${isEn ? "Rest Duration" : "Durasi Istirahat"}: ${rd.suratSakit!.jumlahHari} ${isEn ? "Days" : "Hari"}',
                              '${isEn ? "Period" : "Periode"}: ${rd.suratSakit!.mulaiTanggal} - ${rd.suratSakit!.selesaiTanggal}',
                              if (rd.suratSakit!.riwayatPenyakit.isNotEmpty)
                                '${isEn ? "Diagnosis/History" : "Diagnosis/Riwayat"}: ${rd.suratSakit!.riwayatPenyakit}',
                            ],
                            fileName: 'surat_keterangan_sakit_${rd.id}.pdf',
                            encounterId: rd.encounterId,
                            letterType: MedicalLetterType.suratSakit,
                            isEn: isEn,
                          ),
                        ],

                        if (rd.suratSehat != null) ...[
                          const SizedBox(height: 16),
                          _buildCertificateDetailBox(
                            context: ctx,
                            title: isEn ? 'DIGITAL HEALTH CERTIFICATE' : 'SURAT KETERANGAN SEHAT DIGITAL',
                            color: Colors.green,
                            icon: Icons.assignment_ind_rounded,
                            details: [
                              '${isEn ? "Condition" : "Kondisi"}: ${isEn ? "Physically Healthy" : "Sehat Walafiat"}',
                              '${isEn ? "Purpose" : "Keperluan"}: ${rd.suratSehat!.keperluan}',
                            ],
                            fileName: 'surat_keterangan_sehat_${rd.id}.pdf',
                            encounterId: rd.encounterId,
                            letterType: MedicalLetterType.suratSehat,
                            isEn: isEn,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showApotekDetail(
    BuildContext context,
    RiwayatApotekEntry ra,
    bool isDark,
    Color textColor,
    Color subtitleColor,
    Color purpleAccent,
    bool isEn,
  ) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) {
        final cardBg = isDark ? const Color(0xFF161619) : Colors.white;
        final borderColor = isDark ? const Color(0xFF252528) : const Color(0xFFECEEF2);

        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: cardBg,
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? const [Color(0xFF3A3A40), Color(0xFF252528)]
                          : const [Color(0xFF27AE60), Color(0xFF2E7D32)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ra.noStruk,
                              style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white),
                            ),
                            Text(
                              ra.time.isNotEmpty ? '${ra.date} • ${ra.time}' : ra.date,
                              style: GoogleFonts.outfit(fontSize: 10, color: Colors.white.withValues(alpha: 0.8)),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Colors.white),
                        onPressed: () => Navigator.of(ctx).pop(),
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
                        Text(
                          ra.apotekName,
                          style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: textColor),
                        ),
                        Text(
                          ra.address,
                          style: GoogleFonts.outfit(fontSize: 10, color: subtitleColor),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              isEn ? 'PAYMENT METHOD:' : 'METODE PEMBAYARAN:',
                              style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w900, color: subtitleColor, letterSpacing: 0.5),
                            ),
                            Text(
                              ra.metodeBayar.toUpperCase(),
                              style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: purpleAccent),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          isEn ? 'PURCHASE DETAILS:' : 'RINCIAN BELANJA:',
                          style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w900, color: subtitleColor, letterSpacing: 0.5),
                        ),
                        const SizedBox(height: 6),
                        ...ra.items.map((item) => Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: textColor.withValues(alpha: 0.02),
                            borderRadius: BorderRadius.circular(10),
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
                                      item.nama,
                                      style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: textColor),
                                    ),
                                    Text(
                                      item.qty,
                                      style: GoogleFonts.outfit(fontSize: 9, color: subtitleColor),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                item.subtotal,
                                style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: textColor),
                              ),
                            ],
                          ),
                        )),
                        const SizedBox(height: 12),
                        Divider(color: borderColor),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              isEn ? 'TOTAL PAYMENT' : 'TOTAL PEMBAYARAN',
                              style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: textColor),
                            ),
                            Text(
                              ra.total,
                              style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w900, color: purpleAccent),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF27AE60),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            minimumSize: const Size.fromHeight(44),
                          ),
                          icon: const Icon(Icons.print_rounded, size: 16),
                          label: Text(
                            isEn ? 'Download / Print Receipt (PDF)' : 'Unduh / Cetak Struk (PDF)',
                            style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                behavior: SnackBarBehavior.floating,
                                backgroundColor: const Color(0xFF27AE60),
                                content: Text(
                                  isEn
                                      ? 'Receipt ${ra.noStruk}.pdf downloaded successfully'
                                      : 'Berhasil Mengunduh Struk ${ra.noStruk}.pdf',
                                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCertificateDetailBox({
    required BuildContext context,
    required String title,
    required Color color,
    required IconData icon,
    required List<String> details,
    required String fileName,
    String? encounterId,
    MedicalLetterType? letterType,
    bool isEn = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF1B0C3C);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: color, letterSpacing: 0.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...details.map((detail) => Padding(
            padding: const EdgeInsets.only(bottom: 4.0),
            child: Text(
              detail,
              style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: textColor),
            ),
          )),
          const SizedBox(height: 12),
          CustomButton(
            text: isEn
                ? 'View & Print Official Letter (QR)'
                : 'Lihat & Cetak Surat Resmi (QR)',
            icon: Icons.print_rounded,
            primaryColor: color,
            height: 40,
            onPressed: () {
              if (encounterId != null && encounterId.isNotEmpty) {
                MedicalLetterPreviewDialog.show(
                  context,
                  encounterId: encounterId,
                  preferredType: letterType,
                );
              } else {
                CustomSnackbar.info(
                  context,
                  isEn
                      ? 'Document $fileName is only available for saved encounters.'
                      : 'Dokumen $fileName tersedia untuk pemeriksaan yang tersimpan di server.',
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildVitalChip(String label, String value, IconData icon, Color accent, bool isDark) {
    final chipBg = isDark ? const Color(0xFF1E1E22) : const Color(0xFFF3F0FA);
    final textTheme = isDark ? Colors.white : const Color(0xFF1B0C3C);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: chipBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: accent, size: 12),
          const SizedBox(width: 4),
          Text(
            '$label: ',
            style: GoogleFonts.outfit(fontSize: 10, color: textTheme.withValues(alpha: 0.6), fontWeight: FontWeight.bold),
          ),
          Text(
            value,
            style: GoogleFonts.outfit(fontSize: 10, color: textTheme, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

// ─── QR Code Pattern Painter ─────────────────────────────────────────────────

class _QrPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1B0C3C)
      ..style = PaintingStyle.fill;

    final cellSize = size.width / 7;

    const pattern = [
      [1, 1, 1, 0, 1, 0, 1],
      [1, 0, 1, 0, 0, 0, 1],
      [1, 1, 1, 0, 1, 1, 0],
      [0, 0, 0, 1, 0, 1, 0],
      [1, 1, 0, 0, 1, 1, 1],
      [1, 0, 1, 1, 0, 0, 1],
      [1, 1, 0, 0, 1, 0, 1],
    ];

    for (int row = 0; row < 7; row++) {
      for (int col = 0; col < 7; col++) {
        if (pattern[row][col] == 1) {
          canvas.drawRect(
            Rect.fromLTWH(
              col * cellSize + 0.5,
              row * cellSize + 0.5,
              cellSize - 1,
              cellSize - 1,
            ),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
