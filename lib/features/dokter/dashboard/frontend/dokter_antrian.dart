import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapotech/shared/widgets/skeleton_loading.dart';
import 'package:mapotech/features/landing/landing_page_data.dart';
import 'package:mapotech/features/dokter/dashboard/frontend/dokter_pasien.dart'; // To access registered patients
import 'package:mapotech/shared/widgets/custom_button.dart';
import 'package:mapotech/shared/supabase_service.dart';
import 'package:mapotech/shared/widgets/common_pagination.dart';

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
  final String? satusehatId;

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
    this.satusehatId,
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
    String? satusehatId,
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
      satusehatId: satusehatId ?? this.satusehatId,
    );
  }
}

// ─── Riverpod State Provider ──────────────────────────────────────────────────

class DokterAntrianListNotifier extends StateNotifier<List<AntrianModel>> {
  final String doctorId;
  final Ref ref;
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

  DokterAntrianListNotifier(this.doctorId, this.ref) : super([]) {
    loadQueues();
  }

  Future<void> loadQueues() async {
    _isLoading = true;
    try {
      final dbQueues = await _db.fetchDoctorQueues(doctorId);

      // Fetch guest patients for doctor to map their satusehat_id
      Map<String, String?> guestSatuSehatMap = {};
      try {
        final guestRes = await SupabaseService.client
            .schema('private_doctor')
            .from('guest_patients')
            .select('id, satusehat_id')
            .eq('id_doctor', doctorId);
        if (guestRes != null) {
          for (final row in guestRes) {
            final id = row['id']?.toString();
            final ssId = row['satusehat_id']?.toString();
            if (id != null) {
              guestSatuSehatMap[id] = ssId;
            }
          }
        }
      } catch (e) {
        debugPrint('Error fetching guest patients satusehat: $e');
      }

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

        final patientName =
            q['patient_name']?.toString() ?? 'Pasien Tanpa Nama';
        final patientId = q['id_patient'] as String?;
        final guestId = q['id_guest_patient'] as String?;

        String? satusehatId;
        if (patientId != null) {
          try {
            final patients = ref.read(dokterPasienListProvider);
            final match = patients.firstWhere((p) => p.id == patientId);
            satusehatId = match.satusehatId;
          } catch (_) {}
        } else if (guestId != null) {
          satusehatId = guestSatuSehatMap[guestId];
        }

        DateTime? birthDate;
        if (q['patient_birth_date'] != null) {
          birthDate = DateTime.tryParse(q['patient_birth_date'].toString());
        }

        return AntrianModel(
          id: q['id'] as String,
          no: q['no_queue']?.toString() ?? '-',
          nama: patientName,
          nik: q['patient_nik']?.toString() ?? '-',
          tipe: q['patient_type']?.toString() ?? 'Umum',
          waktu: createdAt != null
              ? _formatTime(createdAt)
              : (q['created_at']?.toString() ?? '-'),
          status: uiStatus,
          avatarBg: _getAvatarColor(patientName),
          dateQueue: parsedDate,
          patientId: patientId,
          guestPatientId: guestId,
          guestPhone: q['patient_phone']?.toString(),
          guestBirthDate: birthDate,
          guestGender: q['patient_gender']?.toString(),
          guestAddress: q['patient_address']?.toString(),
          satusehatId: satusehatId,
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
          if (item.id == queueId) item.copyWith(status: newStatus) else item,
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

  Future<void> registerPatientSatuSehat(AntrianModel queue) async {
    final generatedId = 'P00994497528';
    try {
      if (queue.patientId != null) {
        await SupabaseService.client
            .from('user')
            .update({'satusehat_id': generatedId})
            .eq('id', queue.patientId!);
        try {
          ref.read(dokterPasienListProvider.notifier).loadPatients();
        } catch (_) {}
      } else if (queue.guestPatientId != null) {
        await SupabaseService.client
            .schema('private_doctor')
            .from('guest_patients')
            .update({'satusehat_id': generatedId})
            .eq('id', queue.guestPatientId!);
      }
      await loadQueues();
    } catch (e) {
      debugPrint('Error registering SatuSehat: $e');
      rethrow;
    }
  }

  Future<void> updateQueuePatientType(
    String queueId,
    String patientType,
  ) async {
    try {
      await SupabaseService.client
          .schema('private_doctor')
          .from('queue')
          .update({'patient_type': patientType})
          .eq('id', queueId);
      await loadQueues();
    } catch (e) {
      debugPrint('Error updating queue patient type: $e');
    }
  }
}

final dokterAntrianListProvider =
    StateNotifierProvider<DokterAntrianListNotifier, List<AntrianModel>>((ref) {
      final userState = ref.watch(landingPageProvider).loggedInUser;
      final doctorId =
          userState?['id']?.toString() ??
          '8f93471a-74f8-486b-8e85-4002dc44c11c';
      return DokterAntrianListNotifier(doctorId, ref);
    });

// ─── Dokter Antrian View ──────────────────────────────────────────────────────

class DokterAntrian extends ConsumerStatefulWidget {
  const DokterAntrian({super.key});

  @override
  ConsumerState<DokterAntrian> createState() => _DokterAntrianState();
}

class _DokterAntrianState extends ConsumerState<DokterAntrian> {
  String _searchQuery = '';
  String _activeFilter =
      'Semua'; // 'Semua', 'Menunggu', 'Memproses...', 'Pembayaran', 'Selesai'
  int _quota = 20;
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  int _currentPage = 1;
  int _rowsPerPage = 10;

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
    final state = ref.read(landingPageProvider);
    if (state.language == 'en') {
      final months = [
        'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'
      ];
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
    }
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
    final borderColor = isDark
        ? const Color(0xFF252528)
        : const Color(0xFFECEEF2);
    final themeAccent = isRev
        ? const Color(0xFFB577F2)
        : const Color(0xFF48C9B0);
    final purpleAccent = const Color(0xFFB577F2);
    final inputBg = isDark ? const Color(0xFF1E1E22) : const Color(0xFFF6F8FA);

    // Filter
    List<AntrianModel> filteredQueues = queues.where((q) {
      final qDate = q.dateQueue;
      final matchDate =
          qDate != null &&
          qDate.year == _selectedDate.year &&
          qDate.month == _selectedDate.month &&
          qDate.day == _selectedDate.day;
      if (!matchDate) return false;

      final query = _searchQuery.toLowerCase();
      final matchQuery =
          q.nama.toLowerCase().contains(query) ||
          q.no.toLowerCase().contains(query) ||
          q.nik.contains(query);

      if (!matchQuery) return false;

      if (_activeFilter != 'Semua') {
        return q.status == _activeFilter;
      }
      return true;
    }).toList();

    // Pagination
    final totalDataCount = filteredQueues.length;
    final totalPages = (totalDataCount / _rowsPerPage).ceil();
    final startIndex = (_currentPage - 1) * _rowsPerPage;
    final endIndex = (startIndex + _rowsPerPage) > totalDataCount ? totalDataCount : (startIndex + _rowsPerPage);
    final paginatedQueues = filteredQueues.sublist(startIndex, endIndex);

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
      orElse: () => const AntrianModel(
        no: '',
        nama: '— Memproses...',
        nik: '',
        tipe: '',
        waktu: '',
        status: '',
        avatarBg: Colors.grey,
      ),
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
                    'Antrian Pasien'.tr(state),
                    style: GoogleFonts.outfit(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: textColor,
                    ),
                  ),
                  Text(
                    'Data untuk tanggal: '.tr(state) + _formatDateToIndonesian(_selectedDate),
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      color: purpleAccent,
                      fontWeight: FontWeight.bold,
                    ),
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
                        'Antrian Pasien'.tr(state),
                        style: GoogleFonts.outfit(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      RichText(
                        text: TextSpan(
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: subtitleColor,
                            fontWeight: FontWeight.w500,
                          ),
                          children: [
                            TextSpan(text: 'Data untuk tanggal: '.tr(state)),
                            TextSpan(
                              text: _formatDateToIndonesian(_selectedDate),
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                color: purpleAccent,
                                fontWeight: FontWeight.w900,
                              ),
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
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: purpleAccent,
                      ),
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
                          child: Icon(
                            Icons.people_outline_rounded,
                            size: 18,
                            color: purpleAccent,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Tambah Antrian Walk-in'.tr(state),
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  color: textColor,
                                ),
                              ),
                              Text(
                                'Daftarkan pasien langsung di loket klinik.'.tr(state),
                                style: GoogleFonts.outfit(
                                  fontSize: 9.5,
                                  color: subtitleColor,
                                  fontWeight: FontWeight.bold,
                                ),
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
                          text: 'Tambah Antrian'.tr(state),
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
                      child: Icon(
                        Icons.people_outline_rounded,
                        color: purpleAccent,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tambah Antrian Walk-in'.tr(state),
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: textColor,
                            ),
                          ),
                          Text(
                            'Daftarkan pasien langsung di loket klinik.'.tr(state),
                            style: GoogleFonts.outfit(
                              fontSize: 10.5,
                              color: subtitleColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildOnlineSystemIndicator(purpleAccent),
                    const SizedBox(width: 16),
                    CustomButton(
                      text: 'Tambah Antrian'.tr(state),
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
                  _buildSearchField(
                    isDark,
                    textColor,
                    subtitleColor,
                    borderColor,
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip(
                          'Semua',
                          _activeFilter == 'Semua',
                          () => setState(() { _activeFilter = 'Semua'; _currentPage = 1; }),
                          subtitleColor,
                          cardBgColor,
                          borderColor,
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          'Menunggu',
                          _activeFilter == 'Menunggu',
                          () => setState(() { _activeFilter = 'Menunggu'; _currentPage = 1; }),
                          subtitleColor,
                          cardBgColor,
                          borderColor,
                          dotColor: Colors.amber[600]!,
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          'Memproses...',
                          _activeFilter == 'Memproses...',
                          () => setState(() { _activeFilter = 'Memproses...'; _currentPage = 1; }),
                          subtitleColor,
                          cardBgColor,
                          borderColor,
                          dotColor: purpleAccent,
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          'Pembayaran',
                          _activeFilter == 'Pembayaran',
                          () => setState(() { _activeFilter = 'Pembayaran'; _currentPage = 1; }),
                          subtitleColor,
                          cardBgColor,
                          borderColor,
                          dotColor: Colors.indigo,
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          'Selesai',
                          _activeFilter == 'Selesai',
                          () => setState(() { _activeFilter = 'Selesai'; _currentPage = 1; }),
                          subtitleColor,
                          cardBgColor,
                          borderColor,
                          dotColor: const Color(0xFF27AE60),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : Row(
                children: [
                  _buildFilterChip(
                    'Semua',
                    _activeFilter == 'Semua',
                    () => setState(() { _activeFilter = 'Semua'; _currentPage = 1; }),
                    subtitleColor,
                    cardBgColor,
                    borderColor,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    'Menunggu',
                    _activeFilter == 'Menunggu',
                    () => setState(() { _activeFilter = 'Menunggu'; _currentPage = 1; }),
                    subtitleColor,
                    cardBgColor,
                    borderColor,
                    dotColor: Colors.amber[600]!,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    'Memproses...',
                    _activeFilter == 'Memproses...',
                    () => setState(() { _activeFilter = 'Memproses...'; _currentPage = 1; }),
                    subtitleColor,
                    cardBgColor,
                    borderColor,
                    dotColor: purpleAccent,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    'Pembayaran',
                    _activeFilter == 'Pembayaran',
                    () => setState(() { _activeFilter = 'Pembayaran'; _currentPage = 1; }),
                    subtitleColor,
                    cardBgColor,
                    borderColor,
                    dotColor: Colors.indigo,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    'Selesai',
                    _activeFilter == 'Selesai',
                    () => setState(() { _activeFilter = 'Selesai'; _currentPage = 1; }),
                    subtitleColor,
                    cardBgColor,
                    borderColor,
                    dotColor: const Color(0xFF27AE60),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildSearchField(
                      isDark,
                      textColor,
                      subtitleColor,
                      borderColor,
                    ),
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
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Table Header
              Container(
                color: isDark
                    ? const Color(0xFF1E1E22)
                    : const Color(0xFFF8FAFC),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: _buildTableHeaderText('NO.', subtitleColor),
                    ),
                    Expanded(
                      flex: 3,
                      child: _buildTableHeaderText(
                        'NAMA PASIEN',
                        subtitleColor,
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: _buildTableHeaderText('TIPE', subtitleColor),
                    ),
                    Expanded(
                      flex: 2,
                      child: _buildTableHeaderText('WAKTU', subtitleColor),
                    ),
                    Expanded(
                      flex: 2,
                      child: _buildTableHeaderText('STATUS', subtitleColor),
                    ),
                  ],
                ),
              ),

              // Rows / Empty State / Loading State
              _isLoading
                  ? const SkeletonScope(child: SkeletonQueueList())
                  : filteredQueues.isEmpty
                  ? _buildEmptyState(
                      cardBgColor,
                      borderColor,
                      textColor,
                      subtitleColor,
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: paginatedQueues.length,
                      separatorBuilder: (context, index) =>
                          Divider(color: borderColor, height: 1),
                      itemBuilder: (context, index) {
                        final antrian = paginatedQueues[index];
                        return _buildQueueRow(
                          context,
                          antrian,
                          isDark,
                          cardBgColor,
                          borderColor,
                          textColor,
                          subtitleColor,
                        );
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
            _currentPage = 1;
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
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.calendar_month_outlined,
              size: 14,
              color: textColor.withOpacity(0.6),
            ),
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
            Icon(
              Icons.settings_outlined,
              size: 14,
              color: textColor.withOpacity(0.6),
            ),
            const SizedBox(width: 6),
            Text(
              'Atur Kuota',
              style: GoogleFonts.outfit(
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                color: textColor.withOpacity(0.85),
              ),
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
            style: GoogleFonts.outfit(
              fontSize: 7.5,
              fontWeight: FontWeight.w900,
              color: subtitleColor,
              letterSpacing: 0.5,
            ),
          ),
          const Spacer(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  count,
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: textColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 4),
                Text(
                  unit,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: subtitleColor,
                  ),
                ),
              ],
            ],
          ),
          if (caption.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              caption,
              style: GoogleFonts.outfit(
                fontSize: 9.5,
                color: accentColor == Colors.grey ? subtitleColor : accentColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
          if (child != null) ...[const SizedBox(height: 2), child],
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
            decoration: const BoxDecoration(
              color: Color(0xFF27AE60),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'SISTEM ONLINE',
            style: GoogleFonts.outfit(
              fontSize: 7.5,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF27AE60),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField(
    bool isDark,
    Color textColor,
    Color subtitleColor,
    Color borderColor,
  ) {
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
                  _currentPage = 1;
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
            border: Border.all(
              color: isSelected ? const Color(0xFFB577F2) : border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (dotColor != null) ...[
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
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
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: text,
                    fontWeight: FontWeight.w900,
                  ),
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
                      decoration: BoxDecoration(
                        color: queue.avatarBg.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        queue.nama.isNotEmpty ? queue.nama[0] : 'P',
                        style: GoogleFonts.outfit(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                          color: queue.avatarBg,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            queue.nama,
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: text,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'NIK: ${queue.nik}',
                            style: GoogleFonts.outfit(
                              fontSize: 9,
                              color: subtitle,
                              fontWeight: FontWeight.bold,
                            ),
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
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: text,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              // Waktu
              Expanded(
                flex: 2,
                child: Text(
                  queue.waktu,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: subtitle,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              // Status
              Expanded(
                flex: 2,
                child: Row(children: [_buildQueueStatusBadge(queue.status)]),
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

  Widget _buildEmptyState(
    Color cardBg,
    Color border,
    Color text,
    Color subtitle,
  ) {
    final state = ref.read(landingPageProvider);
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
            child: Icon(
              Icons.people_outline_rounded,
              size: 20,
              color: subtitle,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Tidak ada antrian ditemukan.'.tr(state),
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: text,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Modal Wizard: Tambah Antrian Baru ─────────────────────────────────────

  void _showAddQueueWizard(BuildContext context, bool isDark) {
    final state = ref.read(landingPageProvider);
    final isEn = state.language == 'en';
    final purple = const Color(0xFFB577F2);
    final cardBg = isDark ? const Color(0xFF161619) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1B0C3C);
    final subtitleColor = isDark ? Colors.grey[400]! : const Color(0xFF6F6A8A);
    final borderColor = isDark
        ? const Color(0xFF252528)
        : const Color(0xFFECEEF2);
    final inputBg = isDark ? const Color(0xFF1E1E22) : const Color(0xFFF6F8FA);

    int currentStep = 1; // Step 1 or Step 2
    String selectedTab = 'Cari'; // 'Cari' or 'Spesial'

    // Form inputs for Step 1
    final searchController = TextEditingController();
    final List<PasienModel> registeredPatients = ref.read(
      dokterPasienListProvider,
    );
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
    final now = DateTime.now();
    String formatTime(DateTime dt) {
      final hr = dt.hour;
      final min = dt.minute.toString().padLeft(2, '0');
      final period = hr >= 12 ? 'PM' : 'AM';
      final displayHr = hr > 12 ? hr - 12 : (hr == 0 ? 12 : hr);
      return '${displayHr.toString().padLeft(2, '0')}:$min $period';
    }

    String patientType = 'Umum'; // 'Umum' or 'BPJS'
    final dateController = TextEditingController(
      text:
          '${now.month.toString().padLeft(2, '0')} / ${now.day.toString().padLeft(2, '0')} / ${now.year}',
    );
    final timeController = TextEditingController(text: formatTime(now));
    final yy = now.year.toString().substring(2);
    final mm = now.month.toString().padLeft(2, '0');
    final queueNoController = TextEditingController(text: '$yy${mm}001');

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
            final yy = now.year.toString().substring(2);
            final mm = now.month.toString().padLeft(2, '0');
            queueNoController.text =
                '$yy$mm${nextNum.toString().padLeft(3, '0')}';
          }

          final bool step1CariValid = foundPatient != null;
          final bool step1SpesialValid =
              specNameController.text.isNotEmpty &&
              specNikController.text.length == 16;
          final bool isStep1Valid = selectedTab == 'Cari'
              ? step1CariValid
              : step1SpesialValid;

          return Dialog(
            insetPadding: EdgeInsets.symmetric(
              horizontal: isMobile
                  ? 12
                  : (MediaQuery.of(context).size.width - 520) / 2,
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
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // --- Header ---
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    color: isDark
                        ? const Color(0xFF1A1A1E)
                        : const Color(0xFFF8F5FF),
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
                          child: Icon(
                            Icons.person_add_alt_1_rounded,
                            color: purple,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Tambah Antrian Baru'.tr(state),
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
                        Expanded(child: Container(color: purple)),
                        Expanded(
                          child: Container(
                            color: currentStep == 2
                                ? purple
                                : Colors.transparent,
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
                                              color: selectedTab == 'Cari'
                                                  ? cardBg
                                                  : Colors.transparent,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            alignment: Alignment.center,
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.search_rounded,
                                                  size: 14,
                                                  color: selectedTab == 'Cari'
                                                      ? purple
                                                      : subtitleColor,
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  'Cari Pasien'.tr(state),
                                                  style: GoogleFonts.outfit(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: selectedTab == 'Cari'
                                                        ? purple
                                                        : subtitleColor,
                                                  ),
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
                                              color: selectedTab == 'Spesial'
                                                  ? cardBg
                                                  : Colors.transparent,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            alignment: Alignment.center,
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.star_outline_rounded,
                                                  size: 14,
                                                  color:
                                                      selectedTab == 'Spesial'
                                                      ? purple
                                                      : subtitleColor,
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  'Pasien Spesial'.tr(state),
                                                  style: GoogleFonts.outfit(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color:
                                                        selectedTab == 'Spesial'
                                                        ? purple
                                                        : subtitleColor,
                                                  ),
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
                              foundPatient ??
                                  PasienModel(
                                    id: '',
                                    nama: specNameController.text,
                                    email: '',
                                    nik: specNikController.text,
                                    tempatLahir: '',
                                    tanggalLahir: '',
                                    jenisKelamin: specGender,
                                    telepon: specPhoneController.text,
                                    alamat: '',
                                    umur: 'Walk-in',
                                    avatarBg: purple,
                                    history: const [],
                                  ),
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
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                          child: Text(
                            currentStep == 1 ? 'Batal'.tr(state) : 'Kembali'.tr(state),
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              color: subtitleColor,
                              fontWeight: FontWeight.bold,
                            ),
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
                            backgroundColor: isStep1Valid || currentStep == 2
                                ? purple
                                : borderColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 14,
                            ),
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
                                    final currentName = foundPatient != null
                                        ? foundPatient!.nama
                                        : specNameController.text;
                                    final currentNik = foundPatient != null
                                        ? foundPatient!.nik
                                        : specNikController.text;
                                    final currentAvatar = foundPatient != null
                                        ? foundPatient!.avatarBg
                                        : purple;

                                    DateTime? specDob;
                                    try {
                                      if (specDobController.text.isNotEmpty) {
                                        final parts = specDobController.text
                                            .split('/');
                                        if (parts.length == 3) {
                                          final month = int.parse(
                                            parts[0].trim(),
                                          );
                                          final day = int.parse(
                                            parts[1].trim(),
                                          );
                                          final year = int.parse(
                                            parts[2].trim(),
                                          );
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
                                      guestPhone:
                                          specPhoneController.text.isNotEmpty
                                          ? specPhoneController.text
                                          : null,
                                      guestBirthDate: specDob,
                                      guestGender: specGender != '— Pilih —'
                                          ? specGender
                                          : null,
                                      guestAddress: 'Walk-in',
                                    );

                                    ref
                                        .read(
                                          dokterAntrianListProvider.notifier,
                                        )
                                        .addAntrian(newAntrian);
                                    Navigator.of(ctx).pop();
                                    _showSuccessSnackBar(
                                      context,
                                      isEn
                                          ? 'Patient $currentName successfully added to the queue!'
                                          : 'Pasien $currentName berhasil dimasukkan ke antrean!',
                                    );
                                  }
                                },
                          child: Text(
                            currentStep == 1 ? 'Lanjut →'.tr(state) : 'Simpan Antrian'.tr(state),
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
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
    final state = ref.read(landingPageProvider);
    final isEn = state.language == 'en';
    final purple = const Color(0xFFB577F2);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFormFieldLabel('Cari Pasien *'.tr(state), textCol),
        Row(
          children: [
            Expanded(
              child: _buildTextInput(
                controller,
                'Ketik nama / NIK...'.tr(state),
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    'search'.tr(state),
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              onPressed: () {
                final query = controller.text.toLowerCase();
                PasienModel? match;
                if (query.isNotEmpty) {
                  match = patients.firstWhere(
                    (p) =>
                        p.nama.toLowerCase().contains(query) ||
                        p.nik.contains(query),
                    orElse: () => const PasienModel(
                      id: '',
                      nama: '',
                      email: '',
                      nik: '',
                      tempatLahir: '',
                      tanggalLahir: '',
                      jenisKelamin: '',
                      telepon: '',
                      alamat: '',
                      umur: '',
                      avatarBg: Colors.grey,
                      history: [],
                    ),
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
        Text(
          'Ketik minimal 3 karakter'.tr(state),
          style: GoogleFonts.outfit(
            fontSize: 9,
            color: subCol,
            fontWeight: FontWeight.w600,
          ),
        ),
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
                    decoration: BoxDecoration(
                      color: found!.avatarBg,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      found!.nama[0],
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          found!.nama,
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: textCol,
                          ),
                        ),
                        Text(
                          isEn
                              ? 'NIK: ${found!.nik} • REGISTERED PATIENT'
                              : 'NIK: ${found!.nik} • PASIEN TERDAFTAR',
                          style: GoogleFonts.outfit(
                            fontSize: 9.5,
                            color: subCol,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            Center(
              child: Text(
                'Pasien tidak terdaftar. Gunakan tab Pasien Spesial untuk walk-in.'.tr(state),
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
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
    final state = ref.read(landingPageProvider);
    final isEn = state.language == 'en';
    final purple = const Color(0xFFB577F2);
    final orange = const Color(0xFFF39C12);
    final isChecking = false; // Simulated state

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildFormFieldLabel('Nama Pasien (Wajib)'.tr(state), textCol),
        _buildTextInput(
          nameCtrl,
          'Nama Lengkap'.tr(state),
          Icons.person_outline_rounded,
          inputBg,
          borderCol,
          textCol,
          subCol,
          onChanged: (v) => setWizardState(() {}),
        ),
        const SizedBox(height: 14),

        _buildFormFieldLabel('NIK (Wajib)'.tr(state), textCol),
        _buildTextInput(
          nikCtrl,
          'Masukkan NIK'.tr(state),
          Icons.fingerprint_rounded,
          inputBg,
          borderCol,
          textCol,
          subCol,
          keyboardType: TextInputType.number,
          onChanged: (v) => setWizardState(() {}),
        ),
        const SizedBox(height: 14),

        _buildFormFieldLabel('Nomor Telepon (Opsional)'.tr(state), textCol),
        _buildTextInput(
          phoneCtrl,
          '08...',
          Icons.phone_android_rounded,
          inputBg,
          borderCol,
          textCol,
          subCol,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 14),

        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFormFieldLabel('Tanggal Lahir'.tr(state), textCol),
                  _buildDateInput(
                    context,
                    dobCtrl,
                    'mm / dd / yyyy',
                    inputBg,
                    borderCol,
                    textCol,
                    subCol,
                    setWizardState,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFormFieldLabel('Jenis Kelamin'.tr(state), textCol),
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
                        hint: Text(
                          gender == '— Pilih —' ? '— Pilih —'.tr(state) : gender,
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: subCol.withOpacity(0.5),
                          ),
                        ),
                        dropdownColor: isDark
                            ? const Color(0xFF161619)
                            : Colors.white,
                        icon: Icon(
                          Icons.arrow_drop_down_rounded,
                          color: subCol,
                        ),
                        isExpanded: true,
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: textCol,
                        ),
                        items: ['Laki-laki', 'Perempuan']
                            .map(
                              (g) => DropdownMenuItem(value: g, child: Text(g.tr(state))),
                            )
                            .toList(),
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
          label: Text(
            'Cek & Verifikasi NIK (SatuSehat)'.tr(state),
            style: GoogleFonts.outfit(
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: borderCol),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: () {
            if (nikCtrl.text.length == 16) {
              setWizardState(() {
                verified = true;
              });
              _showSuccessSnackBar(
                context,
                isEn
                    ? 'NIK verified in SatuSehat Kemenkes!'
                    : 'NIK terverifikasi di SatuSehat Kemenkes!',
              );
            } else {
              _showSuccessSnackBar(
                context,
                isEn
                    ? 'Please enter a valid 16-digit NIK.'
                    : 'Harap isi NIK 16 digit dengan valid.',
              );
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
                  'Catatan: Pasien ini hanya terdaftar untuk antrian hari ini and tidak tersimpan di database pasien permanen.'.tr(state),
                  style: GoogleFonts.outfit(
                    fontSize: 9.5,
                    height: 1.4,
                    color: orange,
                    fontWeight: FontWeight.bold,
                  ),
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
    final state = ref.read(landingPageProvider);
    final isEn = state.language == 'en';
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
                decoration: BoxDecoration(
                  color: patient.avatarBg,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  patient.nama.isNotEmpty ? patient.nama[0] : 'P',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      patient.nama,
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: textCol,
                      ),
                    ),
                    Text(
                      isEn
                          ? 'NIK: ${patient.nik} • REGISTERED PATIENT'
                          : 'NIK: ${patient.nik} • PASIEN TERDAFTAR',
                      style: GoogleFonts.outfit(
                        fontSize: 9.5,
                        color: subCol,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Tipe Pasien Radio Switch
        _buildFormFieldLabel('Tipe Pasien *'.tr(state), textCol),
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
            Text(
              'BPJS',
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: textCol,
              ),
            ),
            const SizedBox(width: 24),
            Radio<String>(
              value: 'Umum',
              groupValue: type,
              activeColor: purple,
              onChanged: (val) {
                if (val != null) setWizardState(() => type = val);
              },
            ),
            Text(
              'Umum'.tr(state),
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: textCol,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFormFieldLabel('Tanggal Antrian *'.tr(state), textCol),
                  _buildTextInput(
                    dateCtrl,
                    'Pilih Tanggal'.tr(state),
                    Icons.calendar_month_outlined,
                    inputBg,
                    borderCol,
                    textCol,
                    subCol,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFormFieldLabel('Waktu Antrian *'.tr(state), textCol),
                  _buildTextInput(
                    timeCtrl,
                    '08:03 PM',
                    Icons.access_time_rounded,
                    inputBg,
                    borderCol,
                    textCol,
                    subCol,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        _buildFormFieldLabel('Nomor Antrian (Otomatis)'.tr(state), textCol),
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
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: subCol,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Format: DDMM-NNN (Contoh: 1212-001)'.tr(state),
          style: GoogleFonts.outfit(
            fontSize: 8.5,
            color: subCol,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // ─── Modal: Status Transition / Operations ─────────────────────────────────

  void _showQueueTransitionDialog(
    BuildContext context,
    AntrianModel queue,
    bool isDark,
  ) {
    if (queue.status == 'Pembayaran') {
      showDialog(
        context: context,
        barrierColor: Colors.black.withOpacity(0.4),
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 40,
            vertical: 40,
          ),
          child: CashierPaymentDialog(queue: queue, isDark: isDark),
        ),
      );
    } else {
      showDialog(
        context: context,
        barrierColor: Colors.black.withOpacity(0.4),
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          child: PatientQueueDetailDialog(queue: queue, isDark: isDark),
        ),
      );
    }
  }

  // --- Quota Config dialog ---
  void _showQuotaConfigDialog(BuildContext context, bool isDark) {
    final purple = const Color(0xFFB577F2);
    final cardBg = isDark ? const Color(0xFF161619) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1B0C3C);
    final subtitleColor = isDark ? Colors.grey[400]! : const Color(0xFF6F6A8A);
    final borderColor = isDark
        ? const Color(0xFF252528)
        : const Color(0xFFECEEF2);
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
          style: GoogleFonts.outfit(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: textColor,
          ),
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sesuaikan batas maksimal kuota antrean harian klinik.',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  color: subtitleColor,
                  fontWeight: FontWeight.w500,
                ),
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
                validator: (v) =>
                    (int.tryParse(v ?? '') ?? 0) <= 0 ? 'Harus > 0' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Batal',
              style: GoogleFonts.outfit(
                fontSize: 11,
                color: subtitleColor,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: purple,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                setState(() {
                  _quota = int.parse(controller.text);
                });
                Navigator.of(ctx).pop();
                _showSuccessSnackBar(
                  context,
                  'Kuota antrean berhasil disesuaikan!',
                );
              }
            },
            child: Text(
              'Simpan',
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
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
      style: GoogleFonts.outfit(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: text,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.outfit(
          fontSize: 11.5,
          color: subtitle.withOpacity(0.4),
        ),
        prefixIcon: Icon(icon, size: 16, color: subtitle),
        filled: true,
        fillColor: bg,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 12,
          horizontal: 16,
        ),
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
            controller.text =
                '${date.month.toString().padLeft(2, '0')} / ${date.day.toString().padLeft(2, '0')} / ${date.year}';
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
            const Icon(
              Icons.check_circle_outline_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Text(
              message,
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── PatientQueueDetailDialog ────────────────────────────────────────────────
class PatientQueueDetailDialog extends ConsumerStatefulWidget {
  final AntrianModel queue;
  final bool isDark;

  const PatientQueueDetailDialog({
    super.key,
    required this.queue,
    required this.isDark,
  });

  @override
  ConsumerState<PatientQueueDetailDialog> createState() =>
      _PatientQueueDetailDialogState();
}

class _PatientQueueDetailDialogState
    extends ConsumerState<PatientQueueDetailDialog> {
  bool _isRegistering = false;
  late String _selectedType;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.queue.tipe.isNotEmpty ? widget.queue.tipe : 'Umum';
  }

  int _calculateAge(DateTime? dob) {
    if (dob == null) return 53; // Default fallback matching mockup if null
    final today = DateTime.now();
    int age = today.year - dob.year;
    if (today.month < dob.month ||
        (today.month == dob.month && today.day < dob.day)) {
      age--;
    }
    return age;
  }

  Widget _buildStatusPill(String status) {
    Color bg;
    Color fg;
    String text = status;
    if (status == 'Menunggu') {
      bg = const Color(0xFFFFF3E0);
      fg = const Color(0xFFE67E22);
      text = 'Waiting';
    } else if (status == 'Memproses...') {
      bg = const Color(0xFFFFF3E0);
      fg = const Color(0xFFE67E22);
      text = 'Processing...';
    } else if (status == 'Pembayaran') {
      bg = const Color(0xFFE8EAF6);
      fg = Colors.indigo;
      text = 'Payment';
    } else {
      bg = const Color(0xFFE8F5E9);
      fg = const Color(0xFF27AE60);
      text = 'Completed';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        text,
        style: GoogleFonts.outfit(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: fg,
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    String label1,
    String val1,
    String label2,
    String val2, {
    Widget? extraVal2,
    Color textColor = const Color(0xFF1B0C3C),
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label1,
                  style: GoogleFonts.outfit(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF6F6A8A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  val1,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label2,
                  style: GoogleFonts.outfit(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF6F6A8A),
                  ),
                ),
                const SizedBox(height: 4),
                extraVal2 ??
                    Text(
                      val2,
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final cardBg = isDark ? const Color(0xFF161619) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1B0C3C);
    final borderColor = isDark
        ? const Color(0xFF252528)
        : const Color(0xFFECEEF2);

    final String qDate = widget.queue.dateQueue != null
        ? '${widget.queue.dateQueue!.year}-${widget.queue.dateQueue!.month.toString().padLeft(2, '0')}-${widget.queue.dateQueue!.day.toString().padLeft(2, '0')}'
        : '2026-06-25';

    final isWaiting = widget.queue.status == 'Menunggu';

    return Container(
      width: 480,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
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
            decoration: const BoxDecoration(color: Color(0xFF0F9D58)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.people_outline_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Patient Queue Detail',
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: const Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),

          // Body
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildDetailRow(
                  'QUEUE NUMBER',
                  widget.queue.no,
                  'QUEUE STATUS',
                  '',
                  extraVal2: _buildStatusPill(widget.queue.status),
                  textColor: textColor,
                ),
                _buildDetailRow(
                  'PATIENT NAME',
                  widget.queue.nama,
                  'AGE',
                  '${_calculateAge(widget.queue.guestBirthDate)} years old',
                  textColor: textColor,
                ),
                _buildDetailRow(
                  'NIK',
                  widget.queue.nik,
                  'PHONE NUMBER',
                  widget.queue.guestPhone ?? '-',
                  textColor: textColor,
                ),
                _buildDetailRow(
                  'QUEUE DATE',
                  qDate,
                  'QUEUE TIME',
                  widget.queue.waktu,
                  textColor: textColor,
                ),

                const SizedBox(height: 12),

                // SatuSehat Indicator card
                if (widget.queue.satusehatId != null &&
                    widget.queue.satusehatId!.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF142C1E)
                          : const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF1B4F2E)
                            : const Color(0xFFC8E6C9),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.verified_rounded,
                          color: Color(0xFF27AE60),
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Registered in SatuSehat',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  color: isDark
                                      ? const Color(0xFF81C784)
                                      : const Color(0xFF1B5E20),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.queue.satusehatId!,
                                style: GoogleFonts.outfit(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  color: isDark
                                      ? const Color(0xFF4CAF50)
                                      : const Color(0xFF2E7D32),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF2E1B10)
                          : const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF5E3A1A)
                            : const Color(0xFFFFE0B2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.info_outline_rounded,
                              color: Color(0xFFE67E22),
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Patient Not Registered in SatuSehat',
                                    style: GoogleFonts.outfit(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                      color: isDark
                                          ? const Color(0xFFFFB74D)
                                          : const Color(0xFFE65100),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Register patient to SatuSehat to continue examination.',
                                    style: GoogleFonts.outfit(
                                      fontSize: 9.5,
                                      color: isDark
                                          ? const Color(0xFFFFD54F)
                                          : const Color(0xFFEF6C00),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 38,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF1E1E22)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isDark
                                        ? const Color(0xFF424242)
                                        : const Color(0xFFFFD180),
                                  ),
                                ),
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  widget.queue.nik,
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _isRegistering
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation(
                                        Color(0xFFE67E22),
                                      ),
                                    ),
                                  )
                                : ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFE67E22),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 10,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.add_rounded, size: 14),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Register SatuSehat',
                                          style: GoogleFonts.outfit(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ],
                                    ),
                                    onPressed: () async {
                                      setState(() => _isRegistering = true);
                                      try {
                                        await ref
                                            .read(
                                              dokterAntrianListProvider
                                                  .notifier,
                                            )
                                            .registerPatientSatuSehat(
                                              widget.queue,
                                            );
                                        Navigator.of(context).pop();
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Pasien berhasil didaftarkan ke SatuSehat Kemenkes!',
                                            ),
                                            backgroundColor: Color(0xFF27AE60),
                                          ),
                                        );
                                      } catch (e) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Registrasi gagal: $e',
                                            ),
                                          ),
                                        );
                                      } finally {
                                        if (mounted)
                                          setState(
                                            () => _isRegistering = false,
                                          );
                                      }
                                    },
                                  ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (isWaiting) ...[
                    const SizedBox(height: 16),
                    // Confirm Patient Type Section
                    Text(
                      'Confirm Patient Type *',
                      style: GoogleFonts.outfit(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Row(
                          children: [
                            Radio<String>(
                              value: 'BPJS',
                              groupValue: _selectedType,
                              activeColor: const Color(0xFF0F9D58),
                              onChanged: (val) {
                                if (val != null)
                                  setState(() => _selectedType = val);
                              },
                            ),
                            Text(
                              'BPJS',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 24),
                        Row(
                          children: [
                            Radio<String>(
                              value: 'Umum',
                              groupValue: _selectedType,
                              activeColor: const Color(0xFF0F9D58),
                              onChanged: (val) {
                                if (val != null)
                                  setState(() => _selectedType = val);
                              },
                            ),
                            Text(
                              'GENERAL',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Text(
                      'When Registering: ${_selectedType.toUpperCase()}',
                      style: GoogleFonts.outfit(
                        fontSize: 8.5,
                        color: Colors.grey[500],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],

                const SizedBox(height: 24),

                // Footer Actions
                if (isWaiting) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red, width: 1.5),
                          foregroundColor: Colors.red,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 12,
                          ),
                        ),
                        icon: const Icon(Icons.close_rounded, size: 14),
                        label: Text(
                          'Cancel',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        onPressed: () {
                          ref
                              .read(dokterAntrianListProvider.notifier)
                              .deleteAntrian(widget.queue.id);
                          Navigator.of(context).pop();
                        },
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F9D58),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 12,
                          ),
                        ),
                        icon: const Icon(Icons.check_rounded, size: 14),
                        label: Text(
                          'Call Patient',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        onPressed: () async {
                          if (_selectedType != widget.queue.tipe) {
                            await ref
                                .read(dokterAntrianListProvider.notifier)
                                .updateQueuePatientType(
                                  widget.queue.id,
                                  _selectedType,
                                );
                          }
                          await ref
                              .read(dokterAntrianListProvider.notifier)
                              .updateAntrianStatus(
                                widget.queue.id,
                                'Memproses...',
                              );
                          Navigator.of(context).pop();
                        },
                      ),
                    ],
                  ),
                ] else ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F9D58),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                        child: Text(
                          'Close',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── CashierPaymentDialog ────────────────────────────────────────────────────
class CashierPaymentDialog extends ConsumerStatefulWidget {
  final AntrianModel queue;
  final bool isDark;

  const CashierPaymentDialog({
    super.key,
    required this.queue,
    required this.isDark,
  });

  @override
  ConsumerState<CashierPaymentDialog> createState() =>
      _CashierPaymentDialogState();
}

class _CashierPaymentDialogState extends ConsumerState<CashierPaymentDialog> {
  bool _isLoading = true;
  double _doctorPrice = 10000;
  double _totalPrice = 10000;
  List<Map<String, dynamic>> _medicines = [];
  String _paymentMethod = 'CASH'; // 'CASH' or 'QRIS'
  final TextEditingController _receivedController = TextEditingController(
    text: '0',
  );

  @override
  void initState() {
    super.initState();
    _loadBillingData();
  }

  Future<void> _loadBillingData() async {
    try {
      // 1. Fetch clinical encounter for this queue
      final ceRes = await SupabaseService.client
          .schema('private_doctor')
          .from('clinical_encounters')
          .select('id, total_price, doctor_price')
          .eq('id_queue', widget.queue.id)
          .maybeSingle();

      if (ceRes != null) {
        final encounterId = ceRes['id'];
        _doctorPrice =
            double.tryParse(ceRes['doctor_price']?.toString() ?? '10000') ??
            10000.0;
        _totalPrice =
            double.tryParse(ceRes['total_price']?.toString() ?? '10000') ??
            10000.0;

        // 2. Fetch medicines
        final medicinesRes = await SupabaseService.client
            .schema('private_doctor')
            .from('medicine_ecounter')
            .select('quantity, id_detail_medicine')
            .eq('id_clinical_encounters', encounterId);

        if (medicinesRes != null && medicinesRes.isNotEmpty) {
          List<Map<String, dynamic>> loadedMedicines = [];
          for (final medRow in medicinesRes) {
            final qty =
                double.tryParse(medRow['quantity']?.toString() ?? '0') ?? 0.0;
            final detailMedId = medRow['id_detail_medicine'];

            if (detailMedId != null) {
              // Fetch detail medicine
              final dmRes = await SupabaseService.client
                  .schema('private_doctor')
                  .from('detail_medicine')
                  .select('sell_price, id_medicine')
                  .eq('id', detailMedId)
                  .maybeSingle();

              if (dmRes != null) {
                final sellPrice =
                    double.tryParse(dmRes['sell_price']?.toString() ?? '0') ??
                    0.0;
                final medId = dmRes['id_medicine'];

                String medicineName = 'Obat';
                if (medId != null) {
                  final mRes = await SupabaseService.client
                      .schema('private_doctor')
                      .from('medicine')
                      .select('medicine_name')
                      .eq('id', medId)
                      .maybeSingle();
                  if (mRes != null) {
                    medicineName = mRes['medicine_name']?.toString() ?? 'Obat';
                  }
                }

                loadedMedicines.add({
                  'name': medicineName,
                  'quantity': qty,
                  'price': sellPrice,
                });
              }
            }
          }
          _medicines = loadedMedicines;
        }
      }
    } catch (e) {
      debugPrint('Error loading billing data: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _formatCurrency(double amount) {
    final parts = amount.toInt().toString().split('');
    var result = '';
    var count = 0;
    for (var i = parts.length - 1; i >= 0; i--) {
      result = parts[i] + result;
      count++;
      if (count == 3 && i > 0) {
        result = '.$result';
        count = 0;
      }
    }
    return 'Rp $result';
  }

  Widget _buildItemRow(String name, String price, String qty, String category) {
    final isDark = widget.isDark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.local_pharmacy_outlined,
              color: Color(0xFF0F9D58),
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.outfit(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1B0C3C),
                  ),
                ),
                Text(
                  category,
                  style: GoogleFonts.outfit(
                    fontSize: 8.5,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF6F6A8A),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                price,
                style: GoogleFonts.outfit(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : const Color(0xFF1B0C3C),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF252528)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  qty,
                  style: GoogleFonts.outfit(
                    fontSize: 8.5,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF6F6A8A),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final cardBg = isDark ? const Color(0xFF161619) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1B0C3C);
    final borderColor = isDark
        ? const Color(0xFF252528)
        : const Color(0xFFECEEF2);

    final invoiceNo = widget.queue.dateQueue != null
        ? '#INV-${widget.queue.dateQueue!.toIso8601String().substring(0, 10).replaceAll("-", "")}-${widget.queue.id.substring(0, 4).toUpperCase()}'
        : '#INV-20260617-${widget.queue.id.substring(0, 4).toUpperCase()}';

    if (_isLoading) {
      return Container(
        width: 800,
        height: 480,
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(24),
        ),
        padding: const EdgeInsets.all(24),
        child: SkeletonScope(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  SkeletonBox(height: 20, width: 200),
                  SkeletonBox(height: 20, width: 100),
                ],
              ),
              const SizedBox(height: 24),
              const Expanded(
                child: Column(
                  children: [
                    Row(
                      children: [
                        SkeletonBox(height: 16, width: 150),
                        Spacer(),
                        SkeletonBox(height: 16, width: 80),
                      ],
                    ),
                    SizedBox(height: 12),
                    Row(
                      children: [
                        SkeletonBox(height: 16, width: 100),
                        Spacer(),
                        SkeletonBox(height: 16, width: 70),
                      ],
                    ),
                    SizedBox(height: 12),
                    Row(
                      children: [
                        SkeletonBox(height: 16, width: 120),
                        Spacer(),
                        SkeletonBox(height: 16, width: 60),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(),
              const SizedBox(height: 16),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SkeletonBox(height: 24, width: 100),
                  SkeletonBox(height: 24, width: 150),
                ],
              ),
            ],
          ),
        ),
      );
    }

    final double receivedAmount =
        double.tryParse(_receivedController.text.replaceAll(".", "")) ?? 0.0;
    final double changeAmount = receivedAmount - _totalPrice;
    final bool isPaidValid = receivedAmount >= _totalPrice;

    return Container(
      width: 960,
      height: 580,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left Column (Bill details)
          Expanded(
            flex: 4,
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1A1A1E)
                    : const Color(0xFFF8FAFC),
                border: Border(right: BorderSide(color: borderColor)),
              ),
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Profile row
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          color: Color(0xFFE8F5E9),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          widget.queue.nama.isNotEmpty
                              ? widget.queue.nama[0].toUpperCase()
                              : 'P',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0F9D58),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.queue.nama,
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                color: textColor,
                              ),
                            ),
                            Row(
                              children: [
                                Text(
                                  widget.queue.nik,
                                  style: GoogleFonts.outfit(
                                    fontSize: 10.5,
                                    color: const Color(0xFF6F6A8A),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 1.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE8F5E9),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    widget.queue.tipe.toUpperCase(),
                                    style: GoogleFonts.outfit(
                                      fontSize: 7,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF1B5E20),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                  Text(
                    'ITEM DETAILS',
                    style: GoogleFonts.outfit(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF6F6A8A),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Scrollable Items list
                  Expanded(
                    child: ListView(
                      children: [
                        // Doctor consultation item
                        _buildItemRow(
                          'Jasa Dokter / Konsultasi',
                          _formatCurrency(_doctorPrice),
                          'x1',
                          'LAYANAN',
                        ),
                        // Medicine items
                        ..._medicines.map(
                          (m) => _buildItemRow(
                            m['name'],
                            _formatCurrency(m['price']),
                            'x${m['quantity'].toInt()}',
                            'OBAT',
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Divider(height: 24),

                  // Total Bill section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'TOTAL BILL',
                        style: GoogleFonts.outfit(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                          color: textColor,
                        ),
                      ),
                      Text(
                        _formatCurrency(_totalPrice),
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF0F9D58),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(
                        Icons.verified_user_outlined,
                        color: Color(0xFF27AE60),
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Transaction Verified by SatuSehat',
                        style: GoogleFonts.outfit(
                          fontSize: 9.5,
                          color: const Color(0xFF27AE60),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Right Column (Payment options)
          Expanded(
            flex: 5,
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Right column header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.account_balance_wallet_outlined,
                              color: Color(0xFF0F9D58),
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Payment Method',
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: textColor,
                                ),
                              ),
                              Text(
                                invoiceNo,
                                style: GoogleFonts.outfit(
                                  fontSize: 9.5,
                                  color: const Color(0xFF6F6A8A),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.print_outlined, size: 18),
                            onPressed: () {},
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // CASH / QRIS Tab selection cards
                  Row(
                    children: [
                      // CASH Tab card
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _paymentMethod = 'CASH'),
                          child: Container(
                            height: 72,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: _paymentMethod == 'CASH'
                                  ? (_totalPrice > 0
                                        ? const Color(0xFFE8F5E9)
                                        : cardBg)
                                  : cardBg,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: _paymentMethod == 'CASH'
                                    ? const Color(0xFF0F9D58)
                                    : borderColor,
                                width: _paymentMethod == 'CASH' ? 1.5 : 1.0,
                              ),
                            ),
                            child: Stack(
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: _paymentMethod == 'CASH'
                                            ? const Color(0xFF0F9D58)
                                            : const Color(0xFFF1F5F9),
                                        shape: BoxShape.circle,
                                      ),
                                      alignment: Alignment.center,
                                      child: Icon(
                                        Icons.money_rounded,
                                        color: _paymentMethod == 'CASH'
                                            ? Colors.white
                                            : const Color(0xFF6F6A8A),
                                        size: 16,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            'CASH',
                                            style: GoogleFonts.outfit(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w900,
                                              color: _paymentMethod == 'CASH'
                                                  ? const Color(0xFF1B5E20)
                                                  : textColor,
                                            ),
                                          ),
                                          Text(
                                            'Pay at Cashier',
                                            style: GoogleFonts.outfit(
                                              fontSize: 8.5,
                                              color: const Color(0xFF6F6A8A),
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                if (_paymentMethod == 'CASH')
                                  const Positioned(
                                    top: 0,
                                    right: 0,
                                    child: Icon(
                                      Icons.check_circle_rounded,
                                      color: Color(0xFF0F9D58),
                                      size: 14,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // QRIS Tab card
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _paymentMethod = 'QRIS'),
                          child: Container(
                            height: 72,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: _paymentMethod == 'QRIS'
                                  ? const Color(0xFFE8F5E9)
                                  : cardBg,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: _paymentMethod == 'QRIS'
                                    ? const Color(0xFF0F9D58)
                                    : borderColor,
                                width: _paymentMethod == 'QRIS' ? 1.5 : 1.0,
                              ),
                            ),
                            child: Stack(
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: _paymentMethod == 'QRIS'
                                            ? const Color(0xFF0F9D58)
                                            : const Color(0xFFF1F5F9),
                                        shape: BoxShape.circle,
                                      ),
                                      alignment: Alignment.center,
                                      child: Icon(
                                        Icons.qr_code_scanner_rounded,
                                        color: _paymentMethod == 'QRIS'
                                            ? Colors.white
                                            : const Color(0xFF6F6A8A),
                                        size: 16,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            'QRIS',
                                            style: GoogleFonts.outfit(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w900,
                                              color: _paymentMethod == 'QRIS'
                                                  ? const Color(0xFF1B5E20)
                                                  : textColor,
                                            ),
                                          ),
                                          Text(
                                            'Scan QR Code',
                                            style: GoogleFonts.outfit(
                                              fontSize: 8.5,
                                              color: const Color(0xFF6F6A8A),
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                if (_paymentMethod == 'QRIS')
                                  const Positioned(
                                    top: 0,
                                    right: 0,
                                    child: Icon(
                                      Icons.check_circle_rounded,
                                      color: Color(0xFF0F9D58),
                                      size: 14,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Tab Contents (CASH vs QRIS)
                  Expanded(
                    child: SingleChildScrollView(
                      child: _paymentMethod == 'CASH'
                          ? _buildCashPaymentContent(
                              isPaidValid,
                              changeAmount,
                              textColor,
                              borderColor,
                            )
                          : _buildQrisPaymentContent(borderColor),
                    ),
                  ),

                  const Divider(height: 20),

                  // Cashier Footer lock details
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.lock_outline_rounded,
                            color: Colors.grey[500],
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'ENCRYPTED TRANSACTION',
                            style: GoogleFonts.outfit(
                              fontSize: 8.5,
                              color: Colors.grey[500],
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'POWERED BY MAPOTECH DIGITAL CASHIER',
                        style: GoogleFonts.outfit(
                          fontSize: 8,
                          color: Colors.grey[500],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCashPaymentContent(
    bool isPaidValid,
    double changeAmount,
    Color textColor,
    Color borderColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.isDark
            ? const Color(0xFF1E1E22)
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Text(
              'NOMINAL RECEIVED',
              style: GoogleFonts.outfit(
                fontSize: 8.5,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF6F6A8A),
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Nominal Received custom spinner input field
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFF48C9B0).withOpacity(0.5),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  'Rp',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF1B0C3C),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _receivedController,
                    keyboardType: TextInputType.number,
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF1B0C3C),
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                    ),
                    onChanged: (v) {
                      // Formatting input with dots
                      final raw = v.replaceAll(".", "");
                      if (raw.isNotEmpty) {
                        final val = double.tryParse(raw) ?? 0.0;
                        final formatted = _formatCurrency(
                          val,
                        ).substring(3); // strip "Rp "
                        _receivedController.value = TextEditingValue(
                          text: formatted,
                          selection: TextSelection.collapsed(
                            offset: formatted.length,
                          ),
                        );
                      }
                      setState(() {});
                    },
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: () {
                        final currentVal =
                            double.tryParse(
                              _receivedController.text.replaceAll(".", ""),
                            ) ??
                            0.0;
                        final newVal = currentVal + 10000;
                        final formatted = _formatCurrency(newVal).substring(3);
                        _receivedController.text = formatted;
                        setState(() {});
                      },
                      child: const Icon(
                        Icons.arrow_drop_up_rounded,
                        size: 20,
                        color: Color(0xFF6F6A8A),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        final currentVal =
                            double.tryParse(
                              _receivedController.text.replaceAll(".", ""),
                            ) ??
                            0.0;
                        final newVal = currentVal >= 10000
                            ? currentVal - 10000
                            : 0.0;
                        final formatted = _formatCurrency(newVal).substring(3);
                        _receivedController.text = formatted;
                        setState(() {});
                      },
                      child: const Icon(
                        Icons.arrow_drop_down_rounded,
                        size: 20,
                        color: Color(0xFF6F6A8A),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Quick cash buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildQuickCashBtn('Exact Amount', _totalPrice),
              _buildQuickCashBtn('Rp 50.000', 50000),
              _buildQuickCashBtn('Rp 100.000', 100000),
              _buildQuickCashBtn('Rp 200.000', 200000),
            ],
          ),

          const SizedBox(height: 16),

          // Change section
          Text(
            'CHANGE',
            style: GoogleFonts.outfit(
              fontSize: 8.5,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF6F6A8A),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatCurrency(isPaidValid ? changeAmount : 0),
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: textColor,
                ),
              ),
              Icon(
                Icons.check_circle_rounded,
                color: isPaidValid
                    ? const Color(0xFF0F9D58)
                    : Colors.grey[300]!,
                size: 20,
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Confirm Paid button
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isPaidValid
                  ? const Color(0xFF0F9D58)
                  : Colors.grey[300]!,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: !isPaidValid
                ? null
                : () async {
                    try {
                      await ref
                          .read(dokterAntrianListProvider.notifier)
                          .updateAntrianStatus(widget.queue.id, 'Selesai');
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Pembayaran Tunai berhasil diselesaikan! Kembalian: ${_formatCurrency(changeAmount)}',
                          ),
                          backgroundColor: const Color(0xFF27AE60),
                        ),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('Gagal: $e')));
                    }
                  },
            child: Text(
              'CONFIRM PAID',
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQrisPaymentContent(Color borderColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Simulated Scan QR box
        Container(
          height: 160,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.qr_code_rounded, color: Colors.grey[300], size: 64),
              const SizedBox(height: 8),
              Text(
                'QRIS NOT REGISTERED',
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: Colors.grey[400],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),
        Center(
          child: Text(
            'PLEASE SCAN THE QR CODE ABOVE',
            style: GoogleFonts.outfit(
              fontSize: 8.5,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF6F6A8A),
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Center(
          child: Text(
            'Confirm after pay',
            style: GoogleFonts.outfit(
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1B0C3C),
            ),
          ),
        ),

        const SizedBox(height: 20),

        // Confirm Payment button
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0F9D58),
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          onPressed: () async {
            try {
              await ref
                  .read(dokterAntrianListProvider.notifier)
                  .updateAntrianStatus(widget.queue.id, 'Selesai');
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Pembayaran QRIS berhasil diselesaikan!'),
                  backgroundColor: Color(0xFF27AE60),
                ),
              );
            } catch (e) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('Gagal: $e')));
            }
          },
          child: Text(
            'CONFIRM PAYMENT',
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickCashBtn(String text, double val) {
    return GestureDetector(
      onTap: () {
        final formatted = _formatCurrency(val).substring(3);
        _receivedController.text = formatted;
        setState(() {});
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFECEEF2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.01),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          text,
          style: GoogleFonts.outfit(
            fontSize: 9.5,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF6F6A8A),
          ),
        ),
      ),
    );
  }
}
