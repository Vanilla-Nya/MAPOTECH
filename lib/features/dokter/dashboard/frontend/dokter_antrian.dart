import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapotech/features/landing/landing_page_data.dart';
import 'package:mapotech/features/dokter/dashboard/frontend/dokter_pasien.dart'; // To access registered patients
import 'package:mapotech/shared/widgets/custom_button.dart';
import 'package:mapotech/shared/supabase_service.dart';

// ─── Data Models ─────────────────────────────────────────────────────────────

class AntrianModel {
  final String id;
  final String no;
  final String nama;
  final String nik;
  final String tipe; // 'Umum' or 'BPJS'
  final String waktu;
  final String status; // 'Menunggu', 'Memproses...', 'Pembayaran', 'Selesai'
  final Color avatarBg;
  final DateTime? dateQueue;
  final String? patientId;
  final String? guestPatientId;
  final String? guestPhone;
  final DateTime? guestBirthDate;
  final String? guestGender;
  final String? guestAddress;

  const AntrianModel({
    this.id = '',
    required this.no,
    required this.nama,
    required this.nik,
    required this.tipe,
    required this.waktu,
    required this.status,
    required this.avatarBg,
    this.dateQueue,
    this.patientId,
    this.guestPatientId,
    this.guestPhone,
    this.guestBirthDate,
    this.guestGender,
    this.guestAddress,
  });

  AntrianModel copyWith({
    String? id,
    String? no,
    String? nama,
    String? nik,
    String? tipe,
    String? waktu,
    String? status,
    Color? avatarBg,
    DateTime? dateQueue,
    String? patientId,
    String? guestPatientId,
    String? guestPhone,
    DateTime? guestBirthDate,
    String? guestGender,
    String? guestAddress,
  }) {
    return AntrianModel(
      id: id ?? this.id,
      no: no ?? this.no,
      nama: nama ?? this.nama,
      nik: nik ?? this.nik,
      tipe: tipe ?? this.tipe,
      waktu: waktu ?? this.waktu,
      status: status ?? this.status,
      avatarBg: avatarBg ?? this.avatarBg,
      dateQueue: dateQueue ?? this.dateQueue,
      patientId: patientId ?? this.patientId,
      guestPatientId: guestPatientId ?? this.guestPatientId,
      guestPhone: guestPhone ?? this.guestPhone,
      guestBirthDate: guestBirthDate ?? this.guestBirthDate,
      guestGender: guestGender ?? this.guestGender,
      guestAddress: guestAddress ?? this.guestAddress,
    );
  }
}

// ─── Riverpod State Provider ──────────────────────────────────────────────────

class DokterAntrianListNotifier extends StateNotifier<List<AntrianModel>> {
  final String doctorId;
  final SupabaseService _db = SupabaseService();
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Color _getAvatarColor(String name) {
    final colors = [
      const Color(0xFFB577F2), // Purple
      const Color(0xFF48C9B0), // Teal
      const Color(0xFFF39C12), // Orange
      const Color(0xFF3498DB), // Blue
      const Color(0xFFE74C3C), // Red
    ];
    if (name.isEmpty) return colors[0];
    return colors[name.codeUnitAt(0) % colors.length];
  }

  String _formatTime(DateTime dt) {
    final hr = dt.hour;
    final min = dt.minute.toString().padLeft(2, '0');
    final period = hr >= 12 ? 'PM' : 'AM';
    final displayHr = hr > 12 ? hr - 12 : (hr == 0 ? 12 : hr);
    return '${displayHr.toString().padLeft(2, '0')}:$min $period';
  }

  DokterAntrianListNotifier(this.doctorId) : super([]) {
    loadQueues();
  }

  Future<void> loadQueues() async {
    _isLoading = true;
    try {
      final dbQueues = await _db.fetchDoctorQueues(doctorId);
      
      state = dbQueues.where((q) => q['status'] != 'cancelled').map((q) {
        String uiStatus = 'Menunggu';
        final dbStatus = q['status']?.toString() ?? 'waiting';
        if (dbStatus == 'processing') {
          uiStatus = 'Memproses...';
        } else if (dbStatus == 'payment') {
          uiStatus = 'Pembayaran';
        } else if (dbStatus == 'done') {
          uiStatus = 'Selesai';
        }

        DateTime? parsedDate;
        if (q['date_queue'] != null) {
          parsedDate = DateTime.tryParse(q['date_queue'].toString());
        }

        DateTime? createdAt;
        if (q['created_at'] != null) {
          createdAt = DateTime.tryParse(q['created_at'].toString())?.toLocal();
        }

        final patientName = q['patient_name']?.toString() ?? 'Pasien Tanpa Nama';

        return AntrianModel(
          id: q['id'] as String,
          no: q['no_queue']?.toString() ?? '-',
          nama: patientName,
          nik: q['patient_nik']?.toString() ?? '-',
          tipe: q['patient_type']?.toString() ?? 'Umum',
          waktu: createdAt != null ? _formatTime(createdAt) : (q['created_at']?.toString() ?? '-'),
          status: uiStatus,
          avatarBg: _getAvatarColor(patientName),
          dateQueue: parsedDate,
          patientId: q['id_patient'] as String?,
          guestPatientId: q['id_guest_patient'] as String?,
        );
      }).toList();
    } catch (e) {
      debugPrint('Error loading queues: $e');
    } finally {
      _isLoading = false;
      if (mounted) {
        state = List.from(state);
      }
    }
  }

  Future<void> addAntrian(AntrianModel antrian) async {
    try {
      await _db.addDoctorQueue(
        doctorId: doctorId,
        patientId: antrian.patientId,
        noQueue: antrian.no,
        patientType: antrian.tipe,
        dateQueue: antrian.dateQueue ?? DateTime.now(),
        guestName: antrian.patientId == null ? antrian.nama : null,
        guestNik: antrian.patientId == null ? antrian.nik : null,
        guestPhone: antrian.guestPhone ?? '-',
        guestBirthDate: antrian.guestBirthDate,
        guestGender: antrian.guestGender ?? 'Laki-laki',
        guestAddress: antrian.guestAddress ?? 'Walk-in',
      );
      await loadQueues();
    } catch (e) {
      debugPrint('Error adding queue: $e');
      rethrow;
    }
  }

  Future<void> updateAntrianStatus(String queueId, String newStatus) async {
    try {
      String dbStatus = 'waiting';
      if (newStatus == 'Memproses...') {
        dbStatus = 'processing';
      } else if (newStatus == 'Pembayaran') {
        dbStatus = 'payment';
      } else if (newStatus == 'Selesai') {
        dbStatus = 'done';
      }

      state = [
        for (final item in state)
          if (item.id == queueId) item.copyWith(status: newStatus) else item
      ];

      await _db.updateQueueStatus(queueId, dbStatus);
    } catch (e) {
      debugPrint('Error updating queue status: $e');
      await loadQueues();
    }
  }

  Future<void> deleteAntrian(String queueId) async {
    try {
      state = state.where((item) => item.id != queueId).toList();
      await _db.deleteQueue(queueId);
    } catch (e) {
      debugPrint('Error deleting queue: $e');
      await loadQueues();
    }
  }
}

final dokterAntrianListProvider =
    StateNotifierProvider<DokterAntrianListNotifier, List<AntrianModel>>((ref) {
  final userState = ref.watch(landingPageProvider).loggedInUser;
  final doctorId = userState?['id']?.toString() ?? '8f93471a-74f8-486b-8e85-4002dc44c11c';
  return DokterAntrianListNotifier(doctorId);
});

// ─── Dokter Antrian View ──────────────────────────────────────────────────────

class DokterAntrian extends ConsumerStatefulWidget {
  const DokterAntrian({super.key});

  @override
  ConsumerState<DokterAntrian> createState() => _DokterAntrianState();
}

class _DokterAntrianState extends ConsumerState<DokterAntrian> {
  String _searchQuery = '';
  String _activeFilter = 'Semua'; // 'Semua', 'Menunggu', 'Memproses...', 'Pembayaran', 'Selesai'
  int _quota = 20;
  DateTime _selectedDate = DateTime(2026, 5, 26);
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _fetchQueues());
  }

  Future<void> _fetchQueues() async {
    if (mounted) setState(() => _isLoading = true);
    await ref.read(dokterAntrianListProvider.notifier).loadQueues();
    if (mounted) setState(() => _isLoading = false);
  }

  String _formatDateToIndonesian(DateTime dt) {
    final months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(landingPageProvider);
    final queues = ref.watch(dokterAntrianListProvider);

    final isDark = state.appearance == 'dark';
    final isRev = state.appearance == 'rev';
    final cardBgColor = isDark ? const Color(0xFF161619) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1B0C3C);
    final subtitleColor = isDark ? Colors.grey[400]! : const Color(0xFF6F6A8A);
    final borderColor = isDark ? const Color(0xFF252528) : const Color(0xFFECEEF2);
    final themeAccent = isRev ? const Color(0xFFB577F2) : const Color(0xFF48C9B0);
    final purpleAccent = const Color(0xFFB577F2);

    // Filter
    List<AntrianModel> filteredQueues = queues.where((q) {
      final qDate = q.dateQueue;
      final matchDate = qDate != null &&
          qDate.year == _selectedDate.year &&
          qDate.month == _selectedDate.month &&
          qDate.day == _selectedDate.day;
      if (!matchDate) return false;

      final query = _searchQuery.toLowerCase();
      final matchQuery = q.nama.toLowerCase().contains(query) ||
          q.no.toLowerCase().contains(query) ||
          q.nik.contains(query);

      if (!matchQuery) return false;

      if (_activeFilter != 'Semua') {
        return q.status == _activeFilter;
      }
      return true;
    }).toList();

    // Metric Counts
    final dateQueues = queues.where((q) {
      final qDate = q.dateQueue;
      return qDate != null &&
          qDate.year == _selectedDate.year &&
          qDate.month == _selectedDate.month &&
          qDate.day == _selectedDate.day;
    }).toList();

    final activeQueue = dateQueues.firstWhere(
      (q) => q.status == 'Memproses...',
      orElse: () => const AntrianModel(no: '', nama: '— Memproses...', nik: '', tipe: '', waktu: '', status: '', avatarBg: Colors.grey),
    );
    final waitingCount = dateQueues.where((q) => q.status == 'Menunggu').length;
    final estimatedWait = waitingCount * 15;
    final remainingQuota = _quota - dateQueues.length;

    final isMobile = MediaQuery.of(context).size.width < 768;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ─── Header ──────────────────────────────────────────
        isMobile
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Antrian Pasien',
                    style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w900, color: textColor),
                  ),
                  Text(
                    'Data untuk tanggal: ${_formatDateToIndonesian(_selectedDate)}',
                    style: GoogleFonts.outfit(fontSize: 11, color: purpleAccent, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildDatePickerBtn(isDark, textColor, borderColor),
                      const SizedBox(width: 8),
                      _buildQuotaConfigBtn(isDark, textColor, borderColor),
                    ],
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Antrian Pasien',
                        style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.w900, color: textColor),
                      ),
                      const SizedBox(height: 4),
                      RichText(
                        text: TextSpan(
                          style: GoogleFonts.outfit(fontSize: 12, color: subtitleColor, fontWeight: FontWeight.w500),
                          children: [
                            const TextSpan(text: 'Data untuk tanggal: '),
                            TextSpan(
                              text: _formatDateToIndonesian(_selectedDate),
                              style: GoogleFonts.outfit(fontSize: 12, color: purpleAccent, fontWeight: FontWeight.w900),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      _buildDatePickerBtn(isDark, textColor, borderColor),
                      const SizedBox(width: 12),
                      _buildQuotaConfigBtn(isDark, textColor, borderColor),
                    ],
                  ),
                ],
              ),

        const SizedBox(height: 24),

        // ─── Metrics Dashboard Cards ─────────────────────────
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: isMobile ? 2 : 4,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: isMobile ? 1.4 : 1.7,
          children: [
            // CARD 1: ANTRIAN AKTIF
            _buildMetricCard(
              'ANTRIAN AKTIF',
              activeQueue.nama,
              subtitleColor: subtitleColor,
              textColor: textColor,
              cardBg: cardBgColor,
              border: borderColor,
              accentColor: purpleAccent,
              child: activeQueue.no.isNotEmpty
                  ? Text(
                      'No: ${activeQueue.no}',
                      style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: purpleAccent),
                    )
                  : const SizedBox(),
            ),
            // CARD 2: TOTAL HARI INI
            _buildMetricCard(
              'TOTAL HARI INI',
              '$waitingCount',
              subtitleColor: subtitleColor,
              textColor: textColor,
              cardBg: cardBgColor,
              border: borderColor,
              caption: 'Menunggu',
            ),
            // CARD 3: EST. TUNGGU
            _buildMetricCard(
              'EST. TUNGGU',
              '$estimatedWait',
              subtitleColor: subtitleColor,
              textColor: textColor,
              cardBg: cardBgColor,
              border: borderColor,
              unit: 'menit',
              caption: '15 menit/pasien',
              accentColor: Colors.amber[700]!,
            ),
            // CARD 4: SISA KUOTA
            _buildMetricCard(
              'SISA KUOTA',
              '$remainingQuota',
              subtitleColor: subtitleColor,
              textColor: textColor,
              cardBg: cardBgColor,
              border: borderColor,
              unit: '/ $_quota',
              accentColor: purpleAccent,
            ),
          ],
        ),

        const SizedBox(height: 24),

        // ─── Tambah Antrian Walk-in Banner ───────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: cardBgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: isMobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: purpleAccent.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.people_outline_rounded, size: 18, color: purpleAccent),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Tambah Antrian Walk-in',
                                style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: textColor),
                              ),
                              Text(
                                'Daftarkan pasien langsung di loket klinik.',
                                style: GoogleFonts.outfit(fontSize: 9.5, color: subtitleColor, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildOnlineSystemIndicator(purpleAccent),
                        CustomButton(
                          text: 'Tambah Antrian',
                          icon: Icons.add_rounded,
                          primaryColor: purpleAccent,
                          textColor: Colors.white,
                          height: 38,
                          onPressed: () => _showAddQueueWizard(context, isDark),
                        ),
                      ],
                    ),
                  ],
                )
              : Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: purpleAccent.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Icon(Icons.people_outline_rounded, color: purpleAccent, size: 20),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tambah Antrian Walk-in',
                            style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w900, color: textColor),
                          ),
                          Text(
                            'Daftarkan pasien langsung di loket klinik.',
                            style: GoogleFonts.outfit(fontSize: 10.5, color: subtitleColor, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    _buildOnlineSystemIndicator(purpleAccent),
                    const SizedBox(width: 16),
                    CustomButton(
                      text: 'Tambah Antrian',
                      icon: Icons.add_rounded,
                      primaryColor: purpleAccent,
                      textColor: Colors.white,
                      height: 38,
                      onPressed: () => _showAddQueueWizard(context, isDark),
                    ),
                  ],
                ),
        ),

        const SizedBox(height: 24),

        // ─── Filter & Search Control Bar ─────────────────────
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
                        _buildFilterChip('Semua', _activeFilter == 'Semua', () => setState(() => _activeFilter = 'Semua'), subtitleColor, cardBgColor, borderColor),
                        const SizedBox(width: 8),
                        _buildFilterChip('Menunggu', _activeFilter == 'Menunggu', () => setState(() => _activeFilter = 'Menunggu'), subtitleColor, cardBgColor, borderColor, dotColor: Colors.amber[600]!),
                        const SizedBox(width: 8),
                        _buildFilterChip('Memproses...', _activeFilter == 'Memproses...', () => setState(() => _activeFilter = 'Memproses...'), subtitleColor, cardBgColor, borderColor, dotColor: purpleAccent),
                        const SizedBox(width: 8),
                        _buildFilterChip('Pembayaran', _activeFilter == 'Pembayaran', () => setState(() => _activeFilter = 'Pembayaran'), subtitleColor, cardBgColor, borderColor, dotColor: Colors.indigo),
                        const SizedBox(width: 8),
                        _buildFilterChip('Selesai', _activeFilter == 'Selesai', () => setState(() => _activeFilter = 'Selesai'), subtitleColor, cardBgColor, borderColor, dotColor: const Color(0xFF27AE60)),
                      ],
                    ),
                  ),
                ],
              )
            : Row(
                children: [
                  _buildFilterChip('Semua', _activeFilter == 'Semua', () => setState(() => _activeFilter = 'Semua'), subtitleColor, cardBgColor, borderColor),
                  const SizedBox(width: 8),
                  _buildFilterChip('Menunggu', _activeFilter == 'Menunggu', () => setState(() => _activeFilter = 'Menunggu'), subtitleColor, cardBgColor, borderColor, dotColor: Colors.amber[600]!),
                  const SizedBox(width: 8),
                  _buildFilterChip('Memproses...', _activeFilter == 'Memproses...', () => setState(() => _activeFilter = 'Memproses...'), subtitleColor, cardBgColor, borderColor, dotColor: purpleAccent),
                  const SizedBox(width: 8),
                  _buildFilterChip('Pembayaran', _activeFilter == 'Pembayaran', () => setState(() => _activeFilter = 'Pembayaran'), subtitleColor, cardBgColor, borderColor, dotColor: Colors.indigo),
                  const SizedBox(width: 8),
                  _buildFilterChip('Selesai', _activeFilter == 'Selesai', () => setState(() => _activeFilter = 'Selesai'), subtitleColor, cardBgColor, borderColor, dotColor: const Color(0xFF27AE60)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildSearchField(isDark, textColor, subtitleColor, borderColor),
                  ),
                ],
              ),

        const SizedBox(height: 18),

        // ─── Data List Table ──────────────────────────────────
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
              // Table Header
              Container(
                color: isDark ? const Color(0xFF1E1E22) : const Color(0xFFF8FAFC),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Row(
                  children: [
                    Expanded(flex: 2, child: _buildTableHeaderText('NO.', subtitleColor)),
                    Expanded(flex: 3, child: _buildTableHeaderText('NAMA PASIEN', subtitleColor)),
                    Expanded(flex: 2, child: _buildTableHeaderText('TIPE', subtitleColor)),
                    Expanded(flex: 2, child: _buildTableHeaderText('WAKTU', subtitleColor)),
                    Expanded(flex: 2, child: _buildTableHeaderText('STATUS', subtitleColor)),
                  ],
                ),
              ),

              // Rows / Empty State / Loading State
              _isLoading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(48.0),
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFB577F2)),
                        ),
                      ),
                    )
                  : filteredQueues.isEmpty
                      ? _buildEmptyState(cardBgColor, borderColor, textColor, subtitleColor)
                      : ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: filteredQueues.length,
                          separatorBuilder: (context, index) => Divider(color: borderColor, height: 1),
                          itemBuilder: (context, index) {
                            final antrian = filteredQueues[index];
                            return _buildQueueRow(context, antrian, isDark, cardBgColor, borderColor, textColor, subtitleColor);
                          },
                        ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── UI Widgets Helper ─────────────────────────────────────────────────────

  Widget _buildDatePickerBtn(bool isDark, Color textColor, Color borderColor) {
    return InkWell(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: _selectedDate,
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: ColorScheme.light(
                  primary: const Color(0xFFB577F2),
                  onPrimary: Colors.white,
                  onSurface: textColor,
                ),
              ),
              child: child!,
            );
          },
        );
        if (date != null) {
          setState(() {
            _selectedDate = date;
          });
        }
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E22) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Text(
              '${_selectedDate.day.toString().padLeft(2, '0')} / ${_selectedDate.month.toString().padLeft(2, '0')} / ${_selectedDate.year}',
              style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: textColor),
            ),
            const SizedBox(width: 8),
            Icon(Icons.calendar_month_outlined, size: 14, color: textColor.withOpacity(0.6)),
          ],
        ),
      ),
    );
  }

  Widget _buildQuotaConfigBtn(bool isDark, Color textColor, Color borderColor) {
    return InkWell(
      onTap: () {
        // Quick modal to change quota
        _showQuotaConfigDialog(context, isDark);
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E22) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Icon(Icons.settings_outlined, size: 14, color: textColor.withOpacity(0.6)),
            const SizedBox(width: 6),
            Text(
              'Atur Kuota',
              style: GoogleFonts.outfit(fontSize: 10.5, fontWeight: FontWeight.bold, color: textColor.withOpacity(0.85)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(
    String label,
    String count, {
    required Color subtitleColor,
    required Color textColor,
    required Color cardBg,
    required Color border,
    String unit = '',
    String caption = '',
    Color accentColor = Colors.grey,
    Widget? child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.outfit(fontSize: 7.5, fontWeight: FontWeight.w900, color: subtitleColor, letterSpacing: 0.5),
          ),
          const Spacer(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  count,
                  style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w900, color: textColor),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 4),
                Text(
                  unit,
                  style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: subtitleColor),
                ),
              ]
            ],
          ),
          if (caption.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              caption,
              style: GoogleFonts.outfit(fontSize: 9.5, color: accentColor == Colors.grey ? subtitleColor : accentColor, fontWeight: FontWeight.bold),
            ),
          ],
          if (child != null) ...[
            const SizedBox(height: 2),
            child,
          ]
        ],
      ),
    );
  }

  Widget _buildOnlineSystemIndicator(Color purple) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF27AE60).withOpacity(0.1),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: const BoxDecoration(color: Color(0xFF27AE60), shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            'SISTEM ONLINE',
            style: GoogleFonts.outfit(fontSize: 7.5, fontWeight: FontWeight.w900, color: const Color(0xFF27AE60)),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField(
      bool isDark, Color textColor, Color subtitleColor, Color borderColor) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E22) : const Color(0xFFF1EEFA),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 18, color: subtitleColor),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                });
              },
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
              decoration: InputDecoration(
                hintText: 'Cari Pasien...',
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
    Color subtitleColor,
    Color cardBg,
    Color border, {
    Color? dotColor,
  }) {
    final bg = isSelected ? const Color(0xFFB577F2).withOpacity(0.12) : cardBg;
    final fg = isSelected ? const Color(0xFFB577F2) : subtitleColor;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isSelected ? const Color(0xFFB577F2) : border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (dotColor != null) ...[
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 10.5,
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                  color: fg,
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

  Widget _buildQueueRow(
    BuildContext context,
    AntrianModel queue,
    bool isDark,
    Color cardBg,
    Color border,
    Color text,
    Color subtitle,
  ) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _showQueueTransitionDialog(context, queue, isDark),
        child: Container(
          color: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              // No.
              Expanded(
                flex: 2,
                child: Text(
                  queue.no,
                  style: GoogleFonts.outfit(fontSize: 11, color: text, fontWeight: FontWeight.w900),
                ),
              ),
              // Nama Pasien
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(color: queue.avatarBg.withOpacity(0.12), shape: BoxShape.circle),
                      alignment: Alignment.center,
                      child: Text(
                        queue.nama.isNotEmpty ? queue.nama[0] : 'P',
                        style: GoogleFonts.outfit(fontSize: 10.5, fontWeight: FontWeight.w900, color: queue.avatarBg),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            queue.nama,
                            style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: text),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'NIK: ${queue.nik}',
                            style: GoogleFonts.outfit(fontSize: 9, color: subtitle, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Tipe
              Expanded(
                flex: 2,
                child: Text(
                  queue.tipe,
                  style: GoogleFonts.outfit(fontSize: 11, color: text, fontWeight: FontWeight.w900),
                ),
              ),
              // Waktu
              Expanded(
                flex: 2,
                child: Text(
                  queue.waktu,
                  style: GoogleFonts.outfit(fontSize: 11, color: subtitle, fontWeight: FontWeight.bold),
                ),
              ),
              // Status
              Expanded(
                flex: 2,
                child: Row(
                  children: [
                    _buildQueueStatusBadge(queue.status),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQueueStatusBadge(String status) {
    Color bg;
    Color fg;

    switch (status) {
      case 'Menunggu':
        bg = Colors.amber[600]!.withOpacity(0.1);
        fg = Colors.amber[700]!;
        break;
      case 'Memproses...':
        bg = const Color(0xFFB577F2).withOpacity(0.1);
        fg = const Color(0xFFB577F2);
        break;
      case 'Pembayaran':
        bg = Colors.indigo.withOpacity(0.1);
        fg = Colors.indigo;
        break;
      case 'Selesai':
      default:
        bg = const Color(0xFF27AE60).withOpacity(0.1);
        fg = const Color(0xFF27AE60);
        break;
    }

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

  Widget _buildEmptyState(Color cardBg, Color border, Color text, Color subtitle) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 72),
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
            child: Icon(Icons.people_outline_rounded, size: 20, color: subtitle),
          ),
          const SizedBox(height: 12),
          Text(
            'Tidak ada antrian ditemukan.',
            style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w900, color: text),
          ),
        ],
      ),
    );
  }

  // ─── Modal Wizard: Tambah Antrian Baru ─────────────────────────────────────

  void _showAddQueueWizard(BuildContext context, bool isDark) {
    final purple = const Color(0xFFB577F2);
    final cardBg = isDark ? const Color(0xFF161619) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1B0C3C);
    final subtitleColor = isDark ? Colors.grey[400]! : const Color(0xFF6F6A8A);
    final borderColor = isDark ? const Color(0xFF252528) : const Color(0xFFECEEF2);
    final inputBg = isDark ? const Color(0xFF1E1E22) : const Color(0xFFF6F8FA);

    int currentStep = 1; // Step 1 or Step 2
    String selectedTab = 'Cari'; // 'Cari' or 'Spesial'

    // Form inputs for Step 1
    final searchController = TextEditingController();
    final List<PasienModel> registeredPatients = ref.read(dokterPasienListProvider);
    PasienModel? foundPatient;
    bool searched = false;

    // Special Walk-in form fields
    final specNameController = TextEditingController();
    final specNikController = TextEditingController();
    final specPhoneController = TextEditingController();
    final specDobController = TextEditingController();
    String specGender = '— Pilih —';
    bool specVerified = false;

    // Form inputs for Step 2
    String patientType = 'Umum'; // 'Umum' or 'BPJS'
    final dateController = TextEditingController(text: '05 / 26 / 2026');
    final timeController = TextEditingController(text: '08:03 PM');
    final queueNoController = TextEditingController(text: '2605001');

    final isMobile = MediaQuery.of(context).size.width < 600;

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.4),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setWizardState) {
          // Pre-generate queue number automatically in Step 2
          if (currentStep == 2) {
            final queues = ref.read(dokterAntrianListProvider);
            final nextNum = queues.length + 1;
            queueNoController.text = '2605${nextNum.toString().padLeft(3, '0')}';
          }

          final bool step1CariValid = foundPatient != null;
          final bool step1SpesialValid = specNameController.text.isNotEmpty && specNikController.text.length == 16;
          final bool isStep1Valid = selectedTab == 'Cari' ? step1CariValid : step1SpesialValid;

          return Dialog(
            insetPadding: EdgeInsets.symmetric(
              horizontal: isMobile ? 12 : (MediaQuery.of(context).size.width - 520) / 2,
              vertical: 40,
            ),
            backgroundColor: Colors.transparent,
            child: Container(
              width: 520,
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
                          child: Icon(Icons.person_add_alt_1_rounded, color: purple, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Tambah Antrian Baru',
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

                  // --- Step Progress Bar ---
                  Container(
                    height: 4,
                    color: borderColor,
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            color: purple,
                          ),
                        ),
                        Expanded(
                          child: Container(
                            color: currentStep == 2 ? purple : Colors.transparent,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // --- Body ---
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: currentStep == 1
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Tab Switcher (Capsule Switcher)
                                Container(
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: inputBg,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.all(4),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: () {
                                            setWizardState(() {
                                              selectedTab = 'Cari';
                                            });
                                          },
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: selectedTab == 'Cari' ? cardBg : Colors.transparent,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            alignment: Alignment.center,
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(Icons.search_rounded, size: 14, color: selectedTab == 'Cari' ? purple : subtitleColor),
                                                const SizedBox(width: 6),
                                                Text(
                                                  'Cari Pasien',
                                                  style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: selectedTab == 'Cari' ? purple : subtitleColor),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: () {
                                            setWizardState(() {
                                              selectedTab = 'Spesial';
                                            });
                                          },
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: selectedTab == 'Spesial' ? cardBg : Colors.transparent,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            alignment: Alignment.center,
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(Icons.star_outline_rounded, size: 14, color: selectedTab == 'Spesial' ? purple : subtitleColor),
                                                const SizedBox(width: 6),
                                                Text(
                                                  'Pasien Spesial',
                                                  style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: selectedTab == 'Spesial' ? purple : subtitleColor),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 20),

                                // Tab Content
                                selectedTab == 'Cari'
                                    ? _buildCariPasienTabContent(
                                        isDark,
                                        textColor,
                                        subtitleColor,
                                        borderColor,
                                        inputBg,
                                        searchController,
                                        registeredPatients,
                                        foundPatient,
                                        searched,
                                        setWizardState,
                                      )
                                    : _buildPasienSpesialTabContent(
                                        context,
                                        isDark,
                                        textColor,
                                        subtitleColor,
                                        borderColor,
                                        inputBg,
                                        specNameController,
                                        specNikController,
                                        specPhoneController,
                                        specDobController,
                                        specGender,
                                        specVerified,
                                        setWizardState,
                                      ),
                              ],
                            )
                          : _buildWizardStep2Content(
                              isDark,
                              textColor,
                              subtitleColor,
                              borderColor,
                              inputBg,
                              purple,
                              foundPatient ?? PasienModel(id: '', nama: specNameController.text, email: '', nik: specNikController.text, tempatLahir: '', tanggalLahir: '', jenisKelamin: specGender, telepon: specPhoneController.text, alamat: '', umur: 'Walk-in', avatarBg: purple, history: const []),
                              patientType,
                              dateController,
                              timeController,
                              queueNoController,
                              setWizardState,
                            ),
                    ),
                  ),

                  // --- Footer ---
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
                          child: Text(
                            currentStep == 1 ? 'Batal' : 'Kembali',
                            style: GoogleFonts.outfit(fontSize: 11, color: subtitleColor, fontWeight: FontWeight.bold),
                          ),
                          onPressed: () {
                            if (currentStep == 1) {
                              Navigator.of(ctx).pop();
                            } else {
                              setWizardState(() {
                                currentStep = 1;
                              });
                            }
                          },
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isStep1Valid || currentStep == 2 ? purple : borderColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          ),
                          onPressed: (currentStep == 1 && !isStep1Valid)
                              ? null
                              : () {
                                  if (currentStep == 1) {
                                    setWizardState(() {
                                      currentStep = 2;
                                    });
                                  } else {
                                    // Save queue!
                                    final currentName = foundPatient != null ? foundPatient!.nama : specNameController.text;
                                    final currentNik = foundPatient != null ? foundPatient!.nik : specNikController.text;
                                    final currentAvatar = foundPatient != null ? foundPatient!.avatarBg : purple;

                                    DateTime? specDob;
                                    try {
                                      if (specDobController.text.isNotEmpty) {
                                        final parts = specDobController.text.split('/');
                                        if (parts.length == 3) {
                                          final month = int.parse(parts[0].trim());
                                          final day = int.parse(parts[1].trim());
                                          final year = int.parse(parts[2].trim());
                                          specDob = DateTime(year, month, day);
                                        }
                                      }
                                    } catch (_) {}

                                    final newAntrian = AntrianModel(
                                      no: queueNoController.text,
                                      nama: currentName,
                                      nik: currentNik,
                                      tipe: patientType,
                                      waktu: timeController.text,
                                      status: 'Menunggu',
                                      avatarBg: currentAvatar,
                                      dateQueue: _selectedDate,
                                      patientId: foundPatient?.id,
                                      guestPhone: specPhoneController.text.isNotEmpty ? specPhoneController.text : null,
                                      guestBirthDate: specDob,
                                      guestGender: specGender != '— Pilih —' ? specGender : null,
                                      guestAddress: 'Walk-in',
                                    );

                                    ref.read(dokterAntrianListProvider.notifier).addAntrian(newAntrian);
                                    Navigator.of(ctx).pop();
                                    _showSuccessSnackBar(context, 'Pasien $currentName berhasil dimasukkan ke antrean!');
                                  }
                                },
                          child: Text(
                            currentStep == 1 ? 'Lanjut →' : 'Simpan Antrian',
                            style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900),
                          ),
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

  // --- Step 1 Tab A Content ---
  Widget _buildCariPasienTabContent(
    bool isDark,
    Color textCol,
    Color subCol,
    Color borderCol,
    Color inputBg,
    TextEditingController controller,
    List<PasienModel> patients,
    PasienModel? found,
    bool searched,
    StateSetter setWizardState,
  ) {
    final purple = const Color(0xFFB577F2);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFormFieldLabel('Cari Pasien *', textCol),
        Row(
          children: [
            Expanded(
              child: _buildTextInput(
                controller,
                'Ketik nama / NIK...',
                Icons.search_rounded,
                inputBg,
                borderCol,
                textCol,
                subCol,
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: purple,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded, size: 14),
                  const SizedBox(width: 6),
                  Text('search', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900)),
                ],
              ),
              onPressed: () {
                final query = controller.text.toLowerCase();
                PasienModel? match;
                if (query.isNotEmpty) {
                  match = patients.firstWhere(
                    (p) => p.nama.toLowerCase().contains(query) || p.nik.contains(query),
                    orElse: () => const PasienModel(id: '', nama: '', email: '', nik: '', tempatLahir: '', tanggalLahir: '', jenisKelamin: '', telepon: '', alamat: '', umur: '', avatarBg: Colors.grey, history: []),
                  );
                }
                setWizardState(() {
                  found = match?.id.isNotEmpty == true ? match : null;
                  searched = true;
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text('Ketik minimal 3 karakter', style: GoogleFonts.outfit(fontSize: 9, color: subCol, fontWeight: FontWeight.w600)),
        const SizedBox(height: 20),
        if (searched) ...[
          if (found != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: purple.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: purple.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(color: found!.avatarBg, shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: Text(
                      found!.nama[0],
                      style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(found!.nama, style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w900, color: textCol)),
                        Text('NIK: ${found!.nik} • PASIEN TERDAFTAR', style: GoogleFonts.outfit(fontSize: 9.5, color: subCol, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Center(
              child: Text(
                'Pasien tidak terdaftar. Gunakan tab Pasien Spesial untuk walk-in.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(fontSize: 11, color: Colors.redAccent, fontWeight: FontWeight.bold),
              ),
            ),
          ]
        ],
      ],
    );
  }

  // --- Step 1 Tab B Content ---
  Widget _buildPasienSpesialTabContent(
    BuildContext context,
    bool isDark,
    Color textCol,
    Color subCol,
    Color borderCol,
    Color inputBg,
    TextEditingController nameCtrl,
    TextEditingController nikCtrl,
    TextEditingController phoneCtrl,
    TextEditingController dobCtrl,
    String gender,
    bool verified,
    StateSetter setWizardState,
  ) {
    final purple = const Color(0xFFB577F2);
    final orange = const Color(0xFFF39C12);
    final isChecking = false; // Simulated state

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildFormFieldLabel('Nama Pasien (Wajib)', textCol),
        _buildTextInput(nameCtrl, 'Nama Lengkap', Icons.person_outline_rounded, inputBg, borderCol, textCol, subCol, onChanged: (v) => setWizardState(() {})),
        const SizedBox(height: 14),

        _buildFormFieldLabel('NIK (Wajib)', textCol),
        _buildTextInput(nikCtrl, 'Masukkan NIK', Icons.fingerprint_rounded, inputBg, borderCol, textCol, subCol, keyboardType: TextInputType.number, onChanged: (v) => setWizardState(() {})),
        const SizedBox(height: 14),

        _buildFormFieldLabel('Nomor Telepon (Opsional)', textCol),
        _buildTextInput(phoneCtrl, '08...', Icons.phone_android_rounded, inputBg, borderCol, textCol, subCol, keyboardType: TextInputType.phone),
        const SizedBox(height: 14),

        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFormFieldLabel('Tanggal Lahir', textCol),
                  _buildDateInput(context, dobCtrl, 'mm / dd / yyyy', inputBg, borderCol, textCol, subCol, setWizardState),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFormFieldLabel('Jenis Kelamin', textCol),
                  Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: inputBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: borderCol),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: gender == '— Pilih —' ? null : gender,
                        hint: Text(gender, style: GoogleFonts.outfit(fontSize: 12, color: subCol.withOpacity(0.5))),
                        dropdownColor: isDark ? const Color(0xFF161619) : Colors.white,
                        icon: Icon(Icons.arrow_drop_down_rounded, color: subCol),
                        isExpanded: true,
                        style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: textCol),
                        items: ['Laki-laki', 'Perempuan'].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setWizardState(() {
                              gender = val;
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

        const SizedBox(height: 16),

        // SatuSehat NIK verification button
        OutlinedButton.icon(
          icon: const Icon(Icons.search_rounded, size: 14),
          label: Text('Cek & Verifikasi NIK (SatuSehat)', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900)),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: borderCol),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () {
            if (nikCtrl.text.length == 16) {
              setWizardState(() {
                verified = true;
              });
              _showSuccessSnackBar(context, 'NIK terverifikasi di SatuSehat Kemenkes!');
            } else {
              _showSuccessSnackBar(context, 'Harap isi NIK 16 digit dengan valid.');
            }
          },
        ),

        const SizedBox(height: 16),

        // Warning Alert Box
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: orange.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: orange.withOpacity(0.15)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, size: 16, color: orange),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Catatan: Pasien ini hanya terdaftar untuk antrian hari ini dan tidak tersimpan di database pasien permanen.',
                  style: GoogleFonts.outfit(fontSize: 9.5, height: 1.4, color: orange, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- Step 2 Content ---
  Widget _buildWizardStep2Content(
    bool isDark,
    Color textCol,
    Color subCol,
    Color borderCol,
    Color inputBg,
    Color purple,
    PasienModel patient,
    String type,
    TextEditingController dateCtrl,
    TextEditingController timeCtrl,
    TextEditingController noCtrl,
    StateSetter setWizardState,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Selected Patient Details Summary Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: purple.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: purple.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: patient.avatarBg, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Text(
                  patient.nama.isNotEmpty ? patient.nama[0] : 'P',
                  style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(patient.nama, style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w900, color: textCol)),
                    Text('NIK: ${patient.nik} • PASIEN TERDAFTAR', style: GoogleFonts.outfit(fontSize: 9.5, color: subCol, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Tipe Pasien Radio Switch
        _buildFormFieldLabel('Tipe Pasien *', textCol),
        Row(
          children: [
            Radio<String>(
              value: 'BPJS',
              groupValue: type,
              activeColor: purple,
              onChanged: (val) {
                if (val != null) setWizardState(() => type = val);
              },
            ),
            Text('BPJS', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: textCol)),
            const SizedBox(width: 24),
            Radio<String>(
              value: 'Umum',
              groupValue: type,
              activeColor: purple,
              onChanged: (val) {
                if (val != null) setWizardState(() => type = val);
              },
            ),
            Text('Umum', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: textCol)),
          ],
        ),
        const SizedBox(height: 14),

        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFormFieldLabel('Tanggal Antrian *', textCol),
                  _buildTextInput(dateCtrl, 'Pilih Tanggal', Icons.calendar_month_outlined, inputBg, borderCol, textCol, subCol),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFormFieldLabel('Waktu Antrian *', textCol),
                  _buildTextInput(timeCtrl, '08:03 PM', Icons.access_time_rounded, inputBg, borderCol, textCol, subCol),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        _buildFormFieldLabel('Nomor Antrian (Otomatis)', textCol),
        Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E22) : const Color(0xFFECEEF2),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderCol),
          ),
          alignment: Alignment.centerLeft,
          child: Text(
            noCtrl.text,
            style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: subCol),
          ),
        ),
        const SizedBox(height: 6),
        Text('Format: DDMM-NNN (Contoh: 1212-001)', style: GoogleFonts.outfit(fontSize: 8.5, color: subCol, fontWeight: FontWeight.bold)),
      ],
    );
  }

  // ─── Modal: Status Transition / Operations ─────────────────────────────────

  void _showQueueTransitionDialog(BuildContext context, AntrianModel queue, bool isDark) {
    final purple = const Color(0xFFB577F2);
    final cardBg = isDark ? const Color(0xFF161619) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1B0C3C);
    final subtitleColor = isDark ? Colors.grey[400]! : const Color(0xFF6F6A8A);
    final borderColor = isDark ? const Color(0xFF252528) : const Color(0xFFECEEF2);

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.3),
      builder: (ctx) => AlertDialog(
        backgroundColor: cardBg,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Kelola Antrian Pasien',
          style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w900, color: textColor),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'No. Antrean: ${queue.no}\nNama Pasien: ${queue.nama}\nStatus Saat Ini: ${queue.status}',
              style: GoogleFonts.outfit(fontSize: 12, color: textColor, fontWeight: FontWeight.bold, height: 1.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Perbarui status antrean pasien di bawah ini:',
              style: GoogleFonts.outfit(fontSize: 11, color: subtitleColor, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.spaceAround,
        actions: [
          if (queue.status == 'Menunggu')
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: purple, foregroundColor: Colors.white, elevation: 0),
              onPressed: () {
                ref.read(dokterAntrianListProvider.notifier).updateAntrianStatus(queue.id, 'Memproses...');
                Navigator.of(ctx).pop();
                _showSuccessSnackBar(context, 'Sesi pemeriksaan ${queue.nama} dimulai.');
              },
              child: Text('Proses', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900)),
            ),
          if (queue.status == 'Memproses...')
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white, elevation: 0),
              onPressed: () {
                ref.read(dokterAntrianListProvider.notifier).updateAntrianStatus(queue.id, 'Pembayaran');
                Navigator.of(ctx).pop();
                _showSuccessSnackBar(context, 'Pemeriksaan selesai, pasien diarahkan ke pembayaran.');
              },
              child: Text('Selesai Periksa', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900)),
            ),
          if (queue.status == 'Pembayaran')
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF27AE60), foregroundColor: Colors.white, elevation: 0),
              onPressed: () {
                ref.read(dokterAntrianListProvider.notifier).updateAntrianStatus(queue.id, 'Selesai');
                Navigator.of(ctx).pop();
                _showSuccessSnackBar(context, 'Pembayaran berhasil, transaksi ditutup.');
              },
              child: Text('Selesaikan', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900)),
            ),
          OutlinedButton(
            style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent, side: const BorderSide(color: Colors.redAccent)),
            onPressed: () {
              ref.read(dokterAntrianListProvider.notifier).deleteAntrian(queue.id);
              Navigator.of(ctx).pop();
              _showSuccessSnackBar(context, 'Antrean pasien dihapus.');
            },
            child: Text('Hapus Antrean', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  // --- Quota Config dialog ---
  void _showQuotaConfigDialog(BuildContext context, bool isDark) {
    final purple = const Color(0xFFB577F2);
    final cardBg = isDark ? const Color(0xFF161619) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1B0C3C);
    final subtitleColor = isDark ? Colors.grey[400]! : const Color(0xFF6F6A8A);
    final borderColor = isDark ? const Color(0xFF252528) : const Color(0xFFECEEF2);
    final inputBg = isDark ? const Color(0xFF1E1E22) : const Color(0xFFF6F8FA);

    final formKey = GlobalKey<FormState>();
    final controller = TextEditingController(text: _quota.toString());

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.3),
      builder: (ctx) => AlertDialog(
        backgroundColor: cardBg,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Atur Kuota Antrian',
          style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w900, color: textColor),
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sesuaikan batas maksimal kuota antrean harian klinik.',
                style: GoogleFonts.outfit(fontSize: 11, color: subtitleColor, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 14),
              _buildTextInput(
                controller,
                '20',
                Icons.people_outline_rounded,
                inputBg,
                borderColor,
                textColor,
                subtitleColor,
                keyboardType: TextInputType.number,
                validator: (v) => (int.tryParse(v ?? '') ?? 0) <= 0 ? 'Harus > 0' : null,
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
                setState(() {
                  _quota = int.parse(controller.text);
                });
                Navigator.of(ctx).pop();
                _showSuccessSnackBar(context, 'Kuota antrean berhasil disesuaikan!');
              }
            },
            child: Text('Simpan', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  // ─── Input widgets helper ──────────────────────────────────────────────────

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
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      onChanged: onChanged,
      style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: text),
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
          initialDate: DateTime(2000),
          firstDate: DateTime(1900),
          lastDate: DateTime.now(),
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
            controller.text = '${date.month.toString().padLeft(2, '0')} / ${date.day.toString().padLeft(2, '0')} / ${date.year}';
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
          validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
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
}
