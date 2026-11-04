import 'dart:math';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapotech/shared/widgets/skeleton_loading.dart';
import 'package:mapotech/features/landing/landing_page_data.dart';
import 'package:mapotech/features/dokter/dashboard/frontend/dokter_pasien.dart'; // To access registered patients
import 'package:mapotech/shared/widgets/custom_button.dart';
import 'package:mapotech/shared/supabase_service.dart';
import 'package:mapotech/shared/widgets/common_pagination.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mapotech/shared/satusehat_service.dart';
import 'package:mapotech/shared/thousands_formatter.dart';
import 'package:flutter/services.dart';
import 'invoice_printer.dart';

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
        for (final row in guestRes) {
          final id = row['id']?.toString();
          final ssId = row['satusehat_id']?.toString();
          if (id != null) {
            guestSatuSehatMap[id] = ssId;
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
        patientType: antrian.tipe,
        dateQueue: antrian.dateQueue ?? DateTime.now(),
        guestName: antrian.patientId == null ? antrian.nama : null,
        guestNik: antrian.patientId == null ? antrian.nik : null,
        guestPhone: antrian.guestPhone,
        guestBirthDate: antrian.guestBirthDate,
        guestGender: antrian.guestGender,
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

  Future<String> registerPatientSatuSehat(AntrianModel queue) async {
    try {
      final userState = ref.read(landingPageProvider);
      final doctorId = userState.activeDoctorId ?? this.doctorId;

      final docDetail = await SupabaseService.client
          .from('user_detail_doctor')
          .select('satu_sehat_api, id_satusehat')
          .eq('id', doctorId)
          .maybeSingle();

      final ssConfig = docDetail?['satu_sehat_api'] as Map<String, dynamic>?;
      String generatedId = '';

      if (ssConfig != null &&
          ssConfig['client_id'] != null &&
          queue.nik.isNotEmpty &&
          queue.nik != '-') {
        try {
          final ssService = SatuSehatService(
            clientId: ssConfig['client_id']?.toString(),
            clientSecret: ssConfig['client_secret']?.toString(),
            organizationId: ssConfig['organization_id']?.toString(),
            locationId: ssConfig['location_id']?.toString() ??
                docDetail?['id_satusehat']?.toString(),
            env: ssConfig['env']?.toString(),
          );
          final res = await ssService.getPatientIdByNik(queue.nik);
          if (res['status'] == true && res['id'] != null) {
            generatedId = res['id'].toString();
          }
        } catch (_) {}
      }

      if (generatedId.isEmpty) {
        final nikClean = queue.nik.replaceAll(RegExp(r'\D'), '');
        final seed = nikClean.isNotEmpty
            ? nikClean
            : DateTime.now().millisecondsSinceEpoch.toString();
        generatedId = 'P$seed'.padRight(10, '0').substring(0, 11);
      }

      // Update regular patient in user table
      if (queue.patientId != null) {
        await SupabaseService.client
            .from('user')
            .update({'satusehat_id': generatedId})
            .eq('id', queue.patientId!);
        try {
          ref.read(dokterPasienListProvider.notifier).loadPatients();
        } catch (_) {}
      }

      // Update guest patient in guest_patients table
      if (queue.guestPatientId != null) {
        await SupabaseService.client
            .schema('private_doctor')
            .from('guest_patients')
            .update({'satusehat_id': generatedId})
            .eq('id', queue.guestPatientId!);
      } else if (queue.nik.isNotEmpty && queue.nik != '-') {
        try {
          await SupabaseService.client
              .schema('private_doctor')
              .from('guest_patients')
              .update({'satusehat_id': generatedId})
              .eq('id_doctor', doctorId)
              .eq('nik', queue.nik);
        } catch (_) {}
      }

      // Update in-memory state immediately so UI updates reactively
      state = [
        for (final item in state)
          if (item.id == queue.id)
            item.copyWith(satusehatId: generatedId)
          else
            item,
      ];

      // Refresh in background
      try {
        await loadQueues();
      } catch (_) {}

      return generatedId;
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
      await _db.updateQueuePatientType(queueId, patientType);
      await loadQueues();
    } catch (e) {
      debugPrint('Error updating queue patient type: $e');
    }
  }
}

final dokterAntrianListProvider =
    StateNotifierProvider<DokterAntrianListNotifier, List<AntrianModel>>((ref) {
      final userState = ref.watch(landingPageProvider);
      final doctorId =
          userState.activeDoctorId ?? '8f93471a-74f8-486b-8e85-4002dc44c11c';
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
    final state = ref.watch(landingPageProvider);
    if (state.language == 'en') {
      final months = [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
      ];
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
    }
    final months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
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
    final purpleAccent = themeAccent;
    final inputBg = isDark ? const Color(0xFF1E1E22) : const Color(0xFFF6F8FA);

    // Filter
    List<AntrianModel> filteredQueues = queues.where((q) {
      final qDate = q.dateQueue;
      final matchDate =
          qDate != null &&
          qDate.year == _selectedDate.year &&
          qDate.month == _selectedDate.month &&
          qDate.day == _selectedDate.day;

      // Show pending payments if the selected date is today (so cashiers don't miss them)
      final now = DateTime.now();
      final isTodaySelected =
          _selectedDate.year == now.year &&
          _selectedDate.month == now.month &&
          _selectedDate.day == now.day;
      final isPendingPayment = q.status == 'Pembayaran';

      if (!matchDate && !(isTodaySelected && isPendingPayment)) return false;

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
    final endIndex = (startIndex + _rowsPerPage) > totalDataCount
        ? totalDataCount
        : (startIndex + _rowsPerPage);
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
                    'Data untuk tanggal: '.tr(state) +
                        _formatDateToIndonesian(_selectedDate),
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
                                'Daftarkan pasien langsung di loket klinik.'.tr(
                                  state,
                                ),
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
                            'Daftarkan pasien langsung di loket klinik.'.tr(
                              state,
                            ),
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
                          () => setState(() {
                            _activeFilter = 'Semua';
                            _currentPage = 1;
                          }),
                          subtitleColor,
                          cardBgColor,
                          borderColor,
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          'Menunggu',
                          _activeFilter == 'Menunggu',
                          () => setState(() {
                            _activeFilter = 'Menunggu';
                            _currentPage = 1;
                          }),
                          subtitleColor,
                          cardBgColor,
                          borderColor,
                          dotColor: Colors.amber[600]!,
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          'Memproses...',
                          _activeFilter == 'Memproses...',
                          () => setState(() {
                            _activeFilter = 'Memproses...';
                            _currentPage = 1;
                          }),
                          subtitleColor,
                          cardBgColor,
                          borderColor,
                          dotColor: purpleAccent,
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          'Pembayaran',
                          _activeFilter == 'Pembayaran',
                          () => setState(() {
                            _activeFilter = 'Pembayaran';
                            _currentPage = 1;
                          }),
                          subtitleColor,
                          cardBgColor,
                          borderColor,
                          dotColor: Colors.indigo,
                        ),
                        const SizedBox(width: 8),
                        _buildFilterChip(
                          'Selesai',
                          _activeFilter == 'Selesai',
                          () => setState(() {
                            _activeFilter = 'Selesai';
                            _currentPage = 1;
                          }),
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
                    () => setState(() {
                      _activeFilter = 'Semua';
                      _currentPage = 1;
                    }),
                    subtitleColor,
                    cardBgColor,
                    borderColor,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    'Menunggu',
                    _activeFilter == 'Menunggu',
                    () => setState(() {
                      _activeFilter = 'Menunggu';
                      _currentPage = 1;
                    }),
                    subtitleColor,
                    cardBgColor,
                    borderColor,
                    dotColor: Colors.amber[600]!,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    'Memproses...',
                    _activeFilter == 'Memproses...',
                    () => setState(() {
                      _activeFilter = 'Memproses...';
                      _currentPage = 1;
                    }),
                    subtitleColor,
                    cardBgColor,
                    borderColor,
                    dotColor: purpleAccent,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    'Pembayaran',
                    _activeFilter == 'Pembayaran',
                    () => setState(() {
                      _activeFilter = 'Pembayaran';
                      _currentPage = 1;
                    }),
                    subtitleColor,
                    cardBgColor,
                    borderColor,
                    dotColor: Colors.indigo,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    'Selesai',
                    _activeFilter == 'Selesai',
                    () => setState(() {
                      _activeFilter = 'Selesai';
                      _currentPage = 1;
                    }),
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
    final purple = ref.read(landingPageProvider.notifier).getPrimaryColor();
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
    List<PasienModel> searchResults = [];

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

    final isMobile = MediaQuery.of(context).size.width < 600;

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.4),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setWizardState) {
          // Queue number is now auto-generated by the database (A-NNN format, resets daily)

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
                                        searchResults,
                                        setWizardState,
                                        onSelectedChanged: (val) =>
                                            setWizardState(
                                              () => foundPatient = val,
                                            ),
                                        onSearchedChanged: (val) =>
                                            setWizardState(
                                              () => searched = val,
                                            ),
                                        onResultsChanged: (val) =>
                                            setWizardState(
                                              () => searchResults = val,
                                            ),
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
                                        onGenderChanged: (val) =>
                                            setWizardState(
                                              () => specGender = val,
                                            ),
                                        onVerifiedChanged: (val) =>
                                            setWizardState(
                                              () => specVerified = val,
                                            ),
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
                              setWizardState,
                              onTypeChanged: (val) =>
                                  setWizardState(() => patientType = val),
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
                            currentStep == 1
                                ? 'Batal'.tr(state)
                                : 'Kembali'.tr(state),
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
                                    final currentName = specNameController.text;
                                    final currentNik = specNikController.text;
                                    final currentAvatar = purple;

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
                                      no: '', // Auto-generated by DB as A-NNN
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
                            currentStep == 1
                                ? 'Lanjut →'.tr(state)
                                : 'Simpan Antrian'.tr(state),
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
    PasienModel? selectedPatient,
    bool searched,
    List<PasienModel> searchResults,
    StateSetter setWizardState, {
    required ValueChanged<PasienModel?> onSelectedChanged,
    required ValueChanged<bool> onSearchedChanged,
    required ValueChanged<List<PasienModel>> onResultsChanged,
  }) {
    final state = ref.read(landingPageProvider);
    final isEn = state.language == 'en';
    final purple = ref.read(landingPageProvider.notifier).getPrimaryColor();
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
                List<PasienModel> matches = [];
                if (query.isNotEmpty) {
                  matches = patients
                      .where(
                        (p) =>
                            p.nama.toLowerCase().contains(query) ||
                            p.nik.contains(query),
                      )
                      .toList();
                }
                setWizardState(() {
                  onResultsChanged(matches);
                  onSearchedChanged(true);
                  // Auto-select the first one if there's exactly one match, otherwise let them choose
                  if (matches.length == 1) {
                    onSelectedChanged(matches.first);
                  } else {
                    onSelectedChanged(null);
                  }
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
          if (searchResults.isNotEmpty) ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: searchResults.map((p) {
                final isSelected = p.id == selectedPatient?.id;
                return GestureDetector(
                  onTap: () {
                    setWizardState(() {
                      onSelectedChanged(isSelected ? null : p);
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? purple.withOpacity(0.08)
                          : (isDark
                                ? const Color(0xFF1E1E22)
                                : const Color(0xFFF6F8FA)),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected ? purple : borderCol,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: p.avatarBg,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            p.nama.isNotEmpty ? p.nama[0] : 'P',
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
                                p.nama,
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: textCol,
                                ),
                              ),
                              Text(
                                isEn
                                    ? 'NIK: ${p.nik} • REGISTERED PATIENT'
                                    : 'NIK: ${p.nik} • PASIEN TERDAFTAR',
                                style: GoogleFonts.outfit(
                                  fontSize: 9.5,
                                  color: subCol,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          Icon(
                            Icons.check_circle_rounded,
                            color: purple,
                            size: 20,
                          ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ] else ...[
            Center(
              child: Text(
                'Pasien tidak terdaftar. Gunakan tab Pasien Spesial untuk walk-in.'
                    .tr(state),
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
    StateSetter setWizardState, {
    required ValueChanged<String> onGenderChanged,
    required ValueChanged<bool> onVerifiedChanged,
  }) {
    final state = ref.read(landingPageProvider);
    final isEn = state.language == 'en';
    final purple = ref.read(landingPageProvider.notifier).getPrimaryColor();
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
                          gender == '— Pilih —'
                              ? '— Pilih —'.tr(state)
                              : gender,
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
                              (g) => DropdownMenuItem(
                                value: g,
                                child: Text(g.tr(state)),
                              ),
                            )
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setWizardState(() {
                              onGenderChanged(val);
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
                onVerifiedChanged(true);
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
                  'Catatan: Pasien ini hanya terdaftar untuk antrian hari ini and tidak tersimpan di database pasien permanen.'
                      .tr(state),
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
    StateSetter setWizardState, {
    required ValueChanged<String> onTypeChanged,
  }) {
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
                if (val != null) setWizardState(() => onTypeChanged(val));
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
                if (val != null) setWizardState(() => onTypeChanged(val));
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

        // Queue Number — auto-generated by server
        _buildFormFieldLabel('Nomor Antrian'.tr(state), textCol),
        Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E22) : const Color(0xFFECEEF2),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderCol),
          ),
          child: Row(
            children: [
              Icon(Icons.auto_awesome_rounded, size: 14, color: purple),
              const SizedBox(width: 8),
              Text(
                'A-NNN (Dibuat otomatis oleh server)'.tr(state),
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: subCol,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Format A-001, A-002, ... mereset setiap hari.'.tr(state),
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
    final purple = ref.read(landingPageProvider.notifier).getPrimaryColor();
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
                                        if (mounted) {
                                          setState(
                                            () => _isRegistering = false,
                                          );
                                        }
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
                                if (val != null) {
                                  setState(() => _selectedType = val);
                                }
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
                                if (val != null) {
                                  setState(() => _selectedType = val);
                                }
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
  String? _encounterId;
  String? _electronicPrescriptionId;
  String? _doctorQrisPath;
  final TextEditingController _receivedController = TextEditingController(
    text: '0',
  );

  // Clinical encounter details for certificates & referrals
  bool _isRujukan = false;
  String? _rujukanRs;
  String? _rujukanPoli;
  String? _rujukanNo;
  String? _rujukanCatatan;
  String? _suratKeteranganType;
  String? _suratKeperluan;
  String? _suratRiwayatPenyakit;
  int? _suratSakitHari;
  DateTime? _suratSakitMulai;
  DateTime? _suratSakitSelesai;
  String? _bloodPressure;
  String? _heartRate;

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
          .select(
            'id, total_price, doctor_price, is_rujukan, rujukan_rumah_sakit, rujukan_poli, rujukan_nomor, rujukan_catatan, surat_keterangan_type, surat_keperluan, surat_riwayat_penyakit, surat_sakit_hari, surat_sakit_mulai, surat_sakit_selesai',
          )
          .eq('id_queue', widget.queue.id)
          .maybeSingle();

      if (ceRes != null) {
        final encounterId = ceRes['id'] as String;
        _encounterId = encounterId;
        _doctorPrice =
            double.tryParse(ceRes['doctor_price']?.toString() ?? '10000') ??
            10000.0;
        _totalPrice =
            double.tryParse(ceRes['total_price']?.toString() ?? '10000') ??
            10000.0;

        _isRujukan = ceRes['is_rujukan'] == true;
        _rujukanRs = ceRes['rujukan_rumah_sakit']?.toString();
        _rujukanPoli = ceRes['rujukan_poli']?.toString();
        _rujukanNo = ceRes['rujukan_nomor']?.toString();
        _rujukanCatatan = ceRes['rujukan_catatan']?.toString();
        _suratKeteranganType = ceRes['surat_keterangan_type']?.toString();
        _suratKeperluan = ceRes['surat_keperluan']?.toString();
        _suratRiwayatPenyakit = ceRes['surat_riwayat_penyakit']?.toString();
        _suratSakitHari = ceRes['surat_sakit_hari'] != null
            ? int.tryParse(ceRes['surat_sakit_hari'].toString())
            : null;
        _suratSakitMulai = ceRes['surat_sakit_mulai'] != null
            ? DateTime.tryParse(ceRes['surat_sakit_mulai'].toString())
            : null;
        _suratSakitSelesai = ceRes['surat_sakit_selesai'] != null
            ? DateTime.tryParse(ceRes['surat_sakit_selesai'].toString())
            : null;

        // Fetch vitals
        try {
          final vitalRes = await SupabaseService.client
              .schema('private_doctor')
              .from('vital_signs')
              .select('blood_pressure, heart_rate')
              .eq('id_clinical_ecounter', encounterId)
              .maybeSingle();
          if (vitalRes != null) {
            _bloodPressure = vitalRes['blood_pressure']?.toString();
            _heartRate = vitalRes['heart_rate']?.toString();
          }
        } catch (ev) {
          debugPrint('Error loading vitals: $ev');
        }

        List<Map<String, dynamic>> loadedMedicines = [];

        // 2. Fetch medicines
        final medicinesRes = await SupabaseService.client
            .schema('private_doctor')
            .from('medicine_ecounter')
            .select('quantity, id_detail_medicine')
            .eq('id_clinical_encounters', encounterId);

        if (medicinesRes.isNotEmpty) {
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
                  'isManual': false,
                });
              }
            }
          }
        }

        // 3. Fetch manual prescriptions
        try {
          final epRes = await SupabaseService.client
              .schema('private_doctor')
              .from('electronic_prescriptions')
              .select('*, electronic_prescription_items(*)')
              .eq('id_clinical_encounter', encounterId)
              .maybeSingle();

          if (epRes != null) {
            _electronicPrescriptionId = epRes['id']?.toString();
            final items =
                epRes['electronic_prescription_items'] as List<dynamic>?;
            if (items != null) {
              for (final item in items) {
                if (item['id_catalog_item'] == null) {
                  final qty =
                      double.tryParse(item['quantity']?.toString() ?? '1') ??
                      1.0;
                  loadedMedicines.add({
                    'name': item['medicine_name']?.toString() ?? 'Obat Resep',
                    'quantity': qty,
                    'price': 0.0,
                    'isManual': true,
                  });
                }
              }
            }
          }
        } catch (e) {
          debugPrint('Error loading manual prescriptions: $e');
        }

        _medicines = loadedMedicines;
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

    final double receivedAmount = parseFormattedPrice(_receivedController.text);
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
                            m['isManual'] == true ? 'RESEP MANUAL' : 'OBAT',
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
                  if (_isRujukan || _suratKeteranganType != null) ...[
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    Text(
                      'DOKUMEN MEDIS',
                      style: GoogleFonts.outfit(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF6F6A8A),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (_isRujukan) ...[
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                final purple = ref
                                    .read(landingPageProvider.notifier)
                                    .getPrimaryColor();
                                _showRujukanPreviewDialog(
                                  isDark
                                      ? Colors.white
                                      : const Color(0xFF1B0C3C),
                                  const Color(0xFF6F6A8A),
                                  isDark
                                      ? const Color(0xFF252528)
                                      : const Color(0xFFECEEF2),
                                  isDark
                                      ? const Color(0xFF1E1E22)
                                      : const Color(0xFFF6F8FA),
                                  purple,
                                  const Color(0xFF0F9D58),
                                );
                              },
                              icon: const Icon(
                                Icons.send_rounded,
                                size: 12,
                                color: Colors.white,
                              ),
                              label: Text(
                                'Rujukan',
                                style: GoogleFonts.outfit(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blueAccent,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                          if (_suratKeteranganType != null)
                            const SizedBox(width: 8),
                        ],
                        if (_suratKeteranganType != null) ...[
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                final purple = ref
                                    .read(landingPageProvider.notifier)
                                    .getPrimaryColor();
                                _showSuratKeteranganPreviewDialog(
                                  isDark
                                      ? Colors.white
                                      : const Color(0xFF1B0C3C),
                                  const Color(0xFF6F6A8A),
                                  isDark
                                      ? const Color(0xFF252528)
                                      : const Color(0xFFECEEF2),
                                  isDark
                                      ? const Color(0xFF1E1E22)
                                      : const Color(0xFFF6F8FA),
                                  purple,
                                  const Color(0xFF0F9D58),
                                );
                              },
                              icon: const Icon(
                                Icons.description_rounded,
                                size: 12,
                                color: Colors.white,
                              ),
                              label: Text(
                                _suratKeteranganType == 'sehat'
                                    ? 'Surat Sehat'
                                    : 'Surat Sakit',
                                style: GoogleFonts.outfit(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
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
                            tooltip: 'Print Invoice',
                            onPressed: () {
                              showDialog(
                                context: context,
                                barrierColor: Colors.black54,
                                builder: (_) => Dialog(
                                  backgroundColor: Colors.transparent,
                                  insetPadding: const EdgeInsets.all(24),
                                  child: InvoicePrintPreviewDialog(
                                    queue: widget.queue,
                                    encounterId: _encounterId,
                                    electronicPrescriptionId:
                                        _electronicPrescriptionId,
                                    doctorPrice: _doctorPrice,
                                    totalPrice: _totalPrice,
                                    medicines: _medicines,
                                    invoiceNo: invoiceNo,
                                    isDark: widget.isDark,
                                  ),
                                ),
                              );
                            },
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
                    inputFormatters: [ThousandsFormatter()],
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
                      setState(() {});
                    },
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: () {
                        final currentVal = parseFormattedPrice(
                          _receivedController.text,
                        );
                        final newVal = currentVal + 10000;
                        final formatted = formatPrice(newVal);
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
                        final currentVal = parseFormattedPrice(
                          _receivedController.text,
                        );
                        final newVal = currentVal >= 10000
                            ? currentVal - 10000
                            : 0.0;
                        final formatted = formatPrice(newVal);
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
        final formatted = formatPrice(val);
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

  // --- Start of Medical Certificate & Referral Helpers for Cashier ---
  void _showRujukanPreviewDialog(
    Color textCol,
    Color subtitleCol,
    Color borderCol,
    Color inputBg,
    Color purple,
    Color activeGreen,
  ) {
    final now = DateTime.now();
    final dayName = [
      'Minggu',
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
    ][now.weekday % 7];
    final monthName = [
      '',
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ][now.month];
    final formattedDate = '$dayName, ${now.day} $monthName ${now.year}';

    final patients = ref.read(dokterPasienListProvider);
    final patient = patients.firstWhere(
      (p) =>
          p.nik == widget.queue.nik ||
          p.nama.toLowerCase() == widget.queue.nama.toLowerCase(),
      orElse: () => PasienModel(
        id: 'PAS-${widget.queue.no.split('-').last}',
        nama: widget.queue.nama,
        email:
            '${widget.queue.nama.toLowerCase().replaceAll(' ', '')}@gmail.com',
        nik: widget.queue.nik,
        tempatLahir: 'Bondowoso',
        tanggalLahir: '08 / 12 / 2000',
        jenisKelamin: 'Laki-laki',
        telepon: '08XXXXXXXXXX',
        alamat:
            widget.queue.guestAddress ??
            'Kel. KEJAYAN, Kec. PUJER, KABUPATEN BONDOWOSO',
        umur: widget.queue.guestBirthDate != null
            ? '${DateTime.now().year - widget.queue.guestBirthDate!.year} tahun'
            : '25 tahun',
        avatarBg: widget.queue.avatarBg,
        history: const [],
      ),
    );

    // Doctor details
    String doctorName =
        ref.read(landingPageProvider).loggedInUser?['name']?.toString() ??
        'dr. Agoes Soetanto';
    if (!doctorName.toLowerCase().startsWith('dr.')) {
      doctorName = 'dr. $doctorName';
    }

    String doctorSip = ref.read(landingPageProvider).loggedInUser?['sip']?.toString() ?? '503/446/430.10.2/2026';
    if (!doctorSip.toLowerCase().startsWith('sip')) {
      doctorSip = 'SIP: $doctorSip';
    }

    String docLocation = 'Pujer';
    final userMap = ref.read(landingPageProvider).loggedInUser;
    if (userMap != null && userMap['sub_district'] != null) {
      final rawSub = userMap['sub_district'].toString();
      if (rawSub.isNotEmpty) {
        docLocation = rawSub[0].toUpperCase() + rawSub.substring(1).toLowerCase();
      }
    }

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 40,
            vertical: 24,
          ),
          child: Container(
            width: 720,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Control Bar
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                    border: Border(bottom: BorderSide(color: borderCol)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: activeGreen.withOpacity(0.08),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.assignment_rounded,
                          color: activeGreen,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Surat Rujukan — ${patient.nama}',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: textCol,
                        ),
                      ),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Mencetak Surat Rujukan...'),
                              backgroundColor: Colors.teal,
                            ),
                          );
                        },
                        icon: const Icon(
                          Icons.print_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                        label: Text(
                          'Cetak Surat Rujukan',
                          style: GoogleFonts.outfit(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: activeGreen,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),

                // Paper Preview Area
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Container(
                        width: 640,
                        padding: const EdgeInsets.all(40),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Kop Surat / Header
                            Row(
                              children: [
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: activeGreen.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  alignment: Alignment.center,
                                  child: Icon(
                                    Icons.local_hospital_rounded,
                                    color: activeGreen,
                                    size: 32,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Text(
                                        'DOKTER PRAKTEK MANDIRI ${doctorName.toUpperCase()}',
                                        style: GoogleFonts.outfit(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w900,
                                          color: const Color(0xFF1B0C3C),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Jl. Diponegoro No. 123, Bondowoso',
                                        style: GoogleFonts.outfit(
                                          fontSize: 8.5,
                                          fontWeight: FontWeight.bold,
                                          color: subtitleCol,
                                        ),
                                      ),
                                      Text(
                                        'Telepon: 085259930755',
                                        style: GoogleFonts.outfit(
                                          fontSize: 8.5,
                                          fontWeight: FontWeight.bold,
                                          color: subtitleCol,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 60),
                              ],
                            ),

                            // Double Separator
                            const SizedBox(height: 12),
                            Column(
                              children: [
                                const Divider(
                                  color: Colors.black,
                                  height: 1,
                                  thickness: 1.5,
                                ),
                                const SizedBox(height: 2),
                                const Divider(
                                  color: Colors.black,
                                  height: 1,
                                  thickness: 0.5,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Title Section
                            Center(
                              child: Column(
                                children: [
                                  Text(
                                    'SURAT RUJUKAN PASIEN',
                                    style: GoogleFonts.outfit(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                      color: const Color(0xFF1B0C3C),
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Nomor: ${_rujukanNo ?? "REF/PREVIEW/MOCK"}',
                                    style: GoogleFonts.outfit(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: subtitleCol,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Recipient Info
                            _rujukanPreviewRow(
                              'Kepada Yth. Sejawat Dokter Di',
                              _rujukanRs ?? '—',
                              true,
                            ),
                            const SizedBox(height: 6),
                            _rujukanPreviewRow(
                              'Poli / Bagian',
                              _rujukanPoli ?? '—',
                              false,
                            ),

                            const SizedBox(height: 16),
                            Text(
                              'Mohon pemeriksaan dan penanganan lebih lanjut terhadap pasien berikut:',
                              style: GoogleFonts.outfit(
                                fontSize: 9.5,
                                color: textCol,
                                fontWeight: FontWeight.w500,
                              ),
                            ),

                            const SizedBox(height: 14),
                            // Identitas Pasien
                            _rujukanSectionTitle(
                              'Identitas Pasien',
                              activeGreen,
                            ),
                            const SizedBox(height: 8),
                            _rujukanPreviewRow(
                              'Nama Pasien',
                              patient.nama,
                              true,
                            ),
                            _rujukanPreviewRow(
                              'Nomor Rekam Medis (RM)',
                              patient.id,
                              false,
                            ),
                            _rujukanPreviewRow(
                              'Nomor NIK',
                              patient.nik.isNotEmpty ? patient.nik : '—',
                              false,
                            ),
                            _rujukanPreviewRow(
                              'Tempat, Tanggal Lahir',
                              '${patient.tempatLahir}, ${patient.tanggalLahir}',
                              false,
                            ),
                            _rujukanPreviewRow(
                              'Jenis Kelamin',
                              patient.jenisKelamin,
                              false,
                            ),
                            _rujukanPreviewRow('Alamat', patient.alamat, false),

                            const SizedBox(height: 16),
                            _rujukanSectionTitle(
                              'Pemeriksaan Fisik & Klinis',
                              activeGreen,
                            ),
                            const SizedBox(height: 8),
                            _rujukanPreviewRow(
                              'Tensi / Tekanan Darah',
                              _bloodPressure ?? '—',
                              false,
                            ),
                            _rujukanPreviewRow(
                              'Nadi',
                              _heartRate != null ? '$_heartRate x/menit' : '—',
                              false,
                            ),

                            if (_rujukanCatatan != null &&
                                _rujukanCatatan!.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              _rujukanSectionTitle(
                                'Catatan Tambahan Dokter',
                                activeGreen,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _rujukanCatatan!,
                                style: GoogleFonts.outfit(
                                  fontSize: 9.5,
                                  color: textCol,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],

                            const SizedBox(height: 24),
                            Text(
                              'Demikian surat rujukan ini kami sampaikan, atas kerja samanya kami ucapkan terima kasih.',
                              style: GoogleFonts.outfit(
                                fontSize: 9.5,
                                color: textCol,
                                fontWeight: FontWeight.w500,
                              ),
                            ),

                            const SizedBox(height: 32),
                            // Signature area
                            Align(
                              alignment: Alignment.centerRight,
                              child: SizedBox(
                                width: 200,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text(
                                      '$docLocation, $formattedDate',
                                      style: GoogleFonts.outfit(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.bold,
                                        color: textCol,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: const Color(0xFFECEEF2),
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Image.network(
                                        'https://api.qrserver.com/v1/create-qr-code/?size=80x80&data=https%3A%2F%2Fmapotech.kemenkes.go.id%2Frujukan%2Fpreview',
                                        width: 50,
                                        height: 50,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      doctorName,
                                      style: GoogleFonts.outfit(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w900,
                                        color: textCol,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                    Text(
                                      doctorSip,
                                      style: GoogleFonts.outfit(
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold,
                                        color: subtitleCol,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
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

  void _showSuratKeteranganPreviewDialog(
    Color textCol,
    Color subtitleCol,
    Color borderCol,
    Color inputBg,
    Color purple,
    Color activeGreen,
  ) {
    final now = DateTime.now();
    final dayName = [
      'Minggu',
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
    ][now.weekday % 7];
    final monthName = [
      '',
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ][now.month];
    final formattedDate = '$dayName, ${now.day} $monthName ${now.year}';
    final simpleDate = '${now.day} $monthName ${now.year}';

    final patients = ref.read(dokterPasienListProvider);
    final patient = patients.firstWhere(
      (p) =>
          p.nik == widget.queue.nik ||
          p.nama.toLowerCase() == widget.queue.nama.toLowerCase(),
      orElse: () => PasienModel(
        id: 'PAS-${widget.queue.no.split('-').last}',
        nama: widget.queue.nama,
        email:
            '${widget.queue.nama.toLowerCase().replaceAll(' ', '')}@gmail.com',
        nik: widget.queue.nik,
        tempatLahir: 'Bondowoso',
        tanggalLahir: '08 / 12 / 2000',
        jenisKelamin: 'Laki-laki',
        telepon: '08XXXXXXXXXX',
        alamat:
            widget.queue.guestAddress ??
            'Kel. KEJAYAN, Kec. PUJER, KABUPATEN BONDOWOSO',
        umur: widget.queue.guestBirthDate != null
            ? '${DateTime.now().year - widget.queue.guestBirthDate!.year} tahun'
            : '25 tahun',
        avatarBg: widget.queue.avatarBg,
        history: const [],
      ),
    );

    // Doctor details
    String doctorName =
        ref.read(landingPageProvider).loggedInUser?['name']?.toString() ??
        'dr. Agoes Soetanto';
    if (!doctorName.toLowerCase().startsWith('dr.')) {
      doctorName = 'dr. $doctorName';
    }

    String doctorSip = ref.read(landingPageProvider).loggedInUser?['sip']?.toString() ?? '503/446/430.10.2/2026';
    if (!doctorSip.toLowerCase().startsWith('sip')) {
      doctorSip = 'SIP: $doctorSip';
    }

    String docLocation = 'Pujer';
    final userMap = ref.read(landingPageProvider).loggedInUser;
    if (userMap != null && userMap['sub_district'] != null) {
      final rawSub = userMap['sub_district'].toString();
      if (rawSub.isNotEmpty) {
        docLocation = rawSub[0].toUpperCase() + rawSub.substring(1).toLowerCase();
      }
    }

    final isSehat = _suratKeteranganType == 'sehat';
    final title = isSehat ? 'SURAT KETERANGAN SEHAT' : 'SURAT KETERANGAN SAKIT';

    String startStr = '—';
    String endStr = '—';
    if (_suratSakitMulai != null) {
      startStr =
          '${_suratSakitMulai!.day} ' +
          [
            "Januari",
            "Februari",
            "Maret",
            "April",
            "Mei",
            "Juni",
            "Juli",
            "Agustus",
            "September",
            "Oktober",
            "November",
            "Desember",
          ][_suratSakitMulai!.month - 1] +
          " ${_suratSakitMulai!.year}";
    }
    if (_suratSakitSelesai != null) {
      endStr =
          '${_suratSakitSelesai!.day} ' +
          [
            "Januari",
            "Februari",
            "Maret",
            "April",
            "Mei",
            "Juni",
            "Juli",
            "Agustus",
            "September",
            "Oktober",
            "November",
            "Desember",
          ][_suratSakitSelesai!.month - 1] +
          " ${_suratSakitSelesai!.year}";
    }

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 40,
            vertical: 24,
          ),
          child: Container(
            width: 720,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Control Bar
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                    border: Border(bottom: BorderSide(color: borderCol)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: activeGreen.withOpacity(0.08),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.assignment_rounded,
                          color: activeGreen,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '$title — ${patient.nama}',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: textCol,
                        ),
                      ),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Mencetak ${isSehat ? "Surat Sehat" : "Surat Sakit"}...',
                              ),
                              backgroundColor: Colors.teal,
                            ),
                          );
                        },
                        icon: const Icon(
                          Icons.print_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                        label: Text(
                          'Cetak Surat',
                          style: GoogleFonts.outfit(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: activeGreen,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),

                // Paper Preview Area
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Container(
                        width: 640,
                        padding: const EdgeInsets.all(40),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Kop Surat / Header
                            Row(
                              children: [
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: activeGreen.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  alignment: Alignment.center,
                                  child: Icon(
                                    Icons.local_hospital_rounded,
                                    color: activeGreen,
                                    size: 32,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Text(
                                        'DOKTER PRAKTEK MANDIRI ${doctorName.toUpperCase()}',
                                        style: GoogleFonts.outfit(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w900,
                                          color: const Color(0xFF1B0C3C),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Jl. Diponegoro No. 123, Bondowoso',
                                        style: GoogleFonts.outfit(
                                          fontSize: 8.5,
                                          fontWeight: FontWeight.bold,
                                          color: subtitleCol,
                                        ),
                                      ),
                                      Text(
                                        'Telepon: 085259930755',
                                        style: GoogleFonts.outfit(
                                          fontSize: 8.5,
                                          fontWeight: FontWeight.bold,
                                          color: subtitleCol,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 60),
                              ],
                            ),

                            // Double Separator
                            const SizedBox(height: 12),
                            Column(
                              children: [
                                const Divider(
                                  color: Colors.black,
                                  height: 1,
                                  thickness: 1.5,
                                ),
                                const SizedBox(height: 2),
                                const Divider(
                                  color: Colors.black,
                                  height: 1,
                                  thickness: 0.5,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Title Section
                            Center(
                              child: Column(
                                children: [
                                  Text(
                                    title,
                                    style: GoogleFonts.outfit(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                      color: const Color(0xFF1B0C3C),
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    isSehat
                                        ? 'Nomor: SK-SEHAT/${now.year}/${100 + Random().nextInt(900)}'
                                        : 'Nomor: SK-SAKIT/${now.year}/${100 + Random().nextInt(900)}',
                                    style: GoogleFonts.outfit(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: subtitleCol,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Introductory
                            Text(
                              'Yang bertanda tangan dibawah ini :',
                              style: GoogleFonts.outfit(
                                fontSize: 9.5,
                                color: textCol,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Doctor details
                            _rujukanPreviewRow('Nama Dokter', doctorName, true),
                            _rujukanPreviewRow(
                              'Jabatan / Status',
                              'Dokter Praktek Umum Swasta',
                              false,
                            ),

                            const SizedBox(height: 16),
                            Text(
                              'Menerangkan dengan sesungguhnya bahwa, penderita dengan :',
                              style: GoogleFonts.outfit(
                                fontSize: 9.5,
                                color: textCol,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Patient details
                            _rujukanPreviewRow(
                              'Nama Pasien',
                              patient.nama,
                              true,
                            ),
                            _rujukanPreviewRow(
                              'Umur',
                              '${patient.umur}',
                              false,
                            ),
                            _rujukanPreviewRow('Alamat', patient.alamat, false),

                            const SizedBox(height: 16),
                            // Certificate details
                            if (isSehat) ...[
                              Text(
                                'Pada tanggal : $formattedDate telah diperiksa kesehatannya dan dinyatakan berbadan sehat baik jasmani maupun rohaninya.',
                                style: GoogleFonts.outfit(
                                  fontSize: 9.5,
                                  color: textCol,
                                  height: 1.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ] else ...[
                              Text(
                                'Pada tanggal : $formattedDate telah diperiksa kesehatannya dan dinyatakan dalam keadaan kurang sehat / sakit sehingga memerlukan istirahat selama ${_suratSakitHari ?? 3} hari, terhitung mulai tanggal $startStr s/d $endStr .',
                                style: GoogleFonts.outfit(
                                  fontSize: 9.5,
                                  color: textCol,
                                  height: 1.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
                            _rujukanPreviewRow(
                              'Keperluan',
                              _suratKeperluan?.isNotEmpty == true
                                  ? _suratKeperluan!
                                  : '—',
                              false,
                            ),

                            const SizedBox(height: 16),
                            _rujukanSectionTitle(
                              'Pemeriksaan Fisik & Klinis',
                              activeGreen,
                            ),
                            const SizedBox(height: 8),
                            _rujukanPreviewRow(
                              'Tensi / Tekanan Darah',
                              _bloodPressure?.isNotEmpty == true
                                  ? '$_bloodPressure mmHg'
                                  : '—',
                              false,
                            ),
                            _rujukanPreviewRow(
                              'Nadi',
                              _heartRate?.isNotEmpty == true
                                  ? '$_heartRate x/menit'
                                  : '—',
                              false,
                            ),
                            _rujukanPreviewRow(
                              'Riwayat Penyakit Dahulu',
                              _suratRiwayatPenyakit?.isNotEmpty == true
                                  ? _suratRiwayatPenyakit!
                                  : 'Tidak Ada',
                              false,
                            ),

                            const SizedBox(height: 24),
                            Text(
                              'Demikian surat keterangan ini dibuat untuk digunakan sebagaimana mestinya.',
                              style: GoogleFonts.outfit(
                                fontSize: 9.5,
                                color: textCol,
                                fontWeight: FontWeight.w500,
                              ),
                            ),

                            const SizedBox(height: 32),
                            // Signature area
                            Align(
                              alignment: Alignment.centerRight,
                              child: SizedBox(
                                width: 200,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text(
                                      '$docLocation, $simpleDate',
                                      style: GoogleFonts.outfit(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.bold,
                                        color: textCol,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: const Color(0xFFECEEF2),
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Image.network(
                                        'https://api.qrserver.com/v1/create-qr-code/?size=80x80&data=https%3A%2F%2Fmapotech.kemenkes.go.id%2F${isSehat ? "surat-sehat" : "surat-sakit"}%2Fpreview',
                                        width: 50,
                                        height: 50,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      doctorName,
                                      style: GoogleFonts.outfit(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w900,
                                        color: textCol,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                    Text(
                                      doctorSip,
                                      style: GoogleFonts.outfit(
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold,
                                        color: subtitleCol,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
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

  Widget _rujukanSectionTitle(String title, Color activeGreen) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: activeGreen.withOpacity(0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border(left: BorderSide(color: activeGreen, width: 3)),
      ),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.outfit(
          fontSize: 8.5,
          fontWeight: FontWeight.w900,
          color: activeGreen,
        ),
      ),
    );
  }

  Widget _rujukanPreviewRow(String label, String value, bool isBoldVal) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 180,
          child: Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF6F6A8A),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          ': ',
          style: GoogleFonts.outfit(
            fontSize: 9,
            color: const Color(0xFF6F6A8A),
            fontWeight: FontWeight.bold,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 9,
              fontWeight: isBoldVal ? FontWeight.w900 : FontWeight.bold,
              color: const Color(0xFF1B0C3C),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── InvoicePrintPreviewDialog ────────────────────────────────────────────────
class InvoicePrintPreviewDialog extends ConsumerStatefulWidget {
  final AntrianModel queue;
  final String? encounterId;
  final String? electronicPrescriptionId;
  final double doctorPrice;
  final double totalPrice;
  final List<Map<String, dynamic>> medicines;
  final String invoiceNo;
  final bool isDark;

  const InvoicePrintPreviewDialog({
    super.key,
    required this.queue,
    required this.encounterId,
    required this.electronicPrescriptionId,
    required this.doctorPrice,
    required this.totalPrice,
    required this.medicines,
    required this.invoiceNo,
    required this.isDark,
  });

  @override
  ConsumerState<InvoicePrintPreviewDialog> createState() =>
      _InvoicePrintPreviewDialogState();
}

class _InvoicePrintPreviewDialogState
    extends ConsumerState<InvoicePrintPreviewDialog> {
  bool _isPrinting = false;

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

  String _formatDate(DateTime? dt) {
    if (dt == null) return '-';
    const months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  void _triggerPrint(String paperSize) async {
    setState(() => _isPrinting = true);

    final state = ref.read(landingPageProvider);
    final doctorName = state.loggedInUser?['name']?.toString() ?? 'Dr. -';
    final doctorSpecialty =
        state.loggedInUser?['specialty']?.toString() ?? 'Dokter Umum';
    final avatarUrl = state.loggedInUser?['avatar_url']?.toString() ??
        state.loggedInUser?['photo_url']?.toString() ??
        state.loggedInUser?['satusehat_photo_url']?.toString() ??
        state.loggedInUser?['avatarUrl']?.toString() ??
        '';
    final dateStr = _formatDate(widget.queue.dateQueue ?? DateTime.now());
    final hasEResep = widget.electronicPrescriptionId != null;
    final qrData = hasEResep
        ? 'https://mapotek.relvastudio.com/resep/${widget.electronicPrescriptionId}'
        : '';

    final invoiceData = {
      'paperSize': paperSize,
      'doctorName': doctorName,
      'doctorSpecialty': doctorSpecialty,
      'avatarUrl': avatarUrl,
      'invoiceNo': widget.invoiceNo,
      'date': dateStr,
      'patientName': widget.queue.nama,
      'patientNik': widget.queue.nik,
      'patientType': widget.queue.tipe,
      'doctorPrice': _formatCurrency(widget.doctorPrice),
      'totalPrice': _formatCurrency(widget.totalPrice),
      'hasEResep': hasEResep,
      'qrData': qrData,
      'electronicPrescriptionId': widget.electronicPrescriptionId ?? '',
      'medicines': widget.medicines.map((m) => {
        'name': m['name']?.toString() ?? 'Obat',
        'isManual': m['isManual'] == true,
        'price': m['isManual'] == true
            ? 'Lihat Resep'
            : _formatCurrency((m['price'] as num?)?.toDouble() ?? 0.0),
        'qty': 'x${((m['quantity'] as num?)?.toDouble() ?? 1.0).toInt()}',
      }).toList(),
    };

    final jsonData = jsonEncode(invoiceData);
    printInvoice(jsonData);

    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) setState(() => _isPrinting = false);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(landingPageProvider);
    final notifier = ref.read(landingPageProvider.notifier);
    final paperSize = state.receiptPaperSize;
    final isDark = widget.isDark;
    final cardBg = isDark ? const Color(0xFF1A1A1D) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1B0C3C);
    final subtitleColor = isDark
        ? const Color(0xFF9E9EB0)
        : const Color(0xFF6F6A8A);
    final borderColor = isDark
        ? const Color(0xFF2D2D32)
        : const Color(0xFFECEEF2);
    final green = const Color(0xFF0F9D58);

    final hasEResep = widget.electronicPrescriptionId != null;
    final qrData = hasEResep
        ? 'https://mapotek.relvastudio.com/resep/${widget.electronicPrescriptionId}'
        : null;

    // Determine paper width for preview
    double previewWidth;
    switch (paperSize) {
      case 'A5':
        previewWidth = 420;
        break;
      case 'Thermal 58mm':
        previewWidth = 220;
        break;
      case 'Thermal 80mm':
        previewWidth = 300;
        break;
      default: // A4
        previewWidth = 560;
    }

    final bool isThermal =
        paperSize == 'Thermal 58mm' || paperSize == 'Thermal 80mm';

    final doctorName = state.loggedInUser?['name']?.toString() ?? 'Dr. -';
    final doctorSpecialty =
        state.loggedInUser?['specialty']?.toString() ?? 'Dokter Umum';

    return Container(
      constraints: const BoxConstraints(maxWidth: 860, maxHeight: 680),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 40,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Dialog Toolbar ──────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(24, 16, 16, 16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: borderColor)),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: green.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Icon(Icons.print_outlined, color: green, size: 16),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Print Preview Invoice',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: textColor,
                        ),
                      ),
                      Text(
                        widget.invoiceNo,
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          color: subtitleColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                // Paper size chips
                Row(
                  children: [
                    Text(
                      'Kertas: ',
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        color: subtitleColor,
                      ),
                    ),
                    for (final sz in [
                      'A4',
                      'A5',
                      'Thermal 58mm',
                      'Thermal 80mm',
                    ])
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: GestureDetector(
                          onTap: () => notifier.setReceiptPaperSize(sz),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: paperSize == sz
                                  ? green.withOpacity(0.12)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: paperSize == sz ? green : borderColor,
                              ),
                            ),
                            child: Text(
                              sz,
                              style: GoogleFonts.outfit(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: paperSize == sz ? green : subtitleColor,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(width: 12),

                // Print button
                ElevatedButton.icon(
                  icon: _isPrinting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.print_rounded, size: 14),
                  label: Text(
                    _isPrinting ? 'Mencetak...' : 'Cetak',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: green,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: _isPrinting
                      ? null
                      : () => _triggerPrint(paperSize),
                ),

                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          // ── Preview Area ────────────────────────────────────────────────
          Expanded(
            child: Container(
              color: isDark ? const Color(0xFF111114) : const Color(0xFFF4F6FA),
              alignment: Alignment.topCenter,
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: SingleChildScrollView(
                child: Center(
                  child: Container(
                    width: previewWidth,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: isThermal
                          ? BorderRadius.circular(4)
                          : BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.10),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    padding: EdgeInsets.all(isThermal ? 12 : 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Clinic Header ───────────────────────────────
                        Center(
                          child: Column(
                            children: [
                              if ((state.loggedInUser?['avatar_url'] ??
                                      state.loggedInUser?['photo_url'] ??
                                      state.loggedInUser?['satusehat_photo_url'] ??
                                      state.loggedInUser?['avatarUrl']) != null &&
                                  (state.loggedInUser?['avatar_url'] ??
                                          state.loggedInUser?['photo_url'] ??
                                          state.loggedInUser?['satusehat_photo_url'] ??
                                          state.loggedInUser?['avatarUrl'])
                                      .toString()
                                      .isNotEmpty)
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: Image.network(
                                    (state.loggedInUser?['avatar_url'] ??
                                            state.loggedInUser?['photo_url'] ??
                                            state.loggedInUser?['satusehat_photo_url'] ??
                                            state.loggedInUser?['avatarUrl'])
                                        .toString(),
                                    width: 44,
                                    height: 44,
                                    fit: BoxFit.cover,
                                    errorBuilder: (ctx, err, stack) => Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: green.withOpacity(0.12),
                                        shape: BoxShape.circle,
                                      ),
                                      alignment: Alignment.center,
                                      child: Icon(
                                        Icons.local_hospital_rounded,
                                        color: green,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                )
                              else
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: green.withOpacity(0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: Icon(
                                    Icons.local_hospital_rounded,
                                    color: green,
                                    size: 20,
                                  ),
                                ),
                              const SizedBox(height: 6),
                              Text(
                                'Praktik Mandiri',
                                style: GoogleFonts.outfit(
                                  fontSize: isThermal ? 10 : 14,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFF1B0C3C),
                                ),
                              ),
                              Text(
                                doctorName,
                                style: GoogleFonts.outfit(
                                  fontSize: isThermal ? 8 : 11,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF6F6A8A),
                                ),
                              ),
                              Text(
                                doctorSpecialty,
                                style: GoogleFonts.outfit(
                                  fontSize: isThermal ? 7 : 9,
                                  color: const Color(0xFF9E9EB0),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),
                        Divider(color: const Color(0xFFECEEF2), thickness: 1),
                        const SizedBox(height: 8),

                        // ── Invoice Meta ────────────────────────────────
                        _invoiceRow('No. Invoice', widget.invoiceNo, isThermal),
                        _invoiceRow(
                          'Tanggal',
                          _formatDate(widget.queue.dateQueue ?? DateTime.now()),
                          isThermal,
                        ),
                        _invoiceRow(
                          'Nama Pasien',
                          widget.queue.nama,
                          isThermal,
                        ),
                        _invoiceRow('NIK', widget.queue.nik, isThermal),
                        _invoiceRow('Jenis', widget.queue.tipe, isThermal),

                        const SizedBox(height: 10),
                        Divider(color: const Color(0xFFECEEF2), thickness: 1),
                        const SizedBox(height: 8),

                        // ── Section Label ───────────────────────────────
                        Text(
                          'RINCIAN TAGIHAN',
                          style: GoogleFonts.outfit(
                            fontSize: isThermal ? 7 : 8.5,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF6F6A8A),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // ── Consultation fee ────────────────────────────
                        _billRow(
                          'Jasa Dokter / Konsultasi',
                          _formatCurrency(widget.doctorPrice),
                          'x1',
                          isThermal,
                          isManual: false,
                        ),

                        // ── Medicines ────────────────────────────────────
                        ...widget.medicines.map(
                          (m) => _billRow(
                            m['name']?.toString() ?? 'Obat',
                            m['isManual'] == true
                                ? 'Lihat Resep'
                                : _formatCurrency((m['price'] as double?) ?? 0),
                            'x${((m['quantity'] as double?) ?? 1).toInt()}',
                            isThermal,
                            isManual: m['isManual'] == true,
                          ),
                        ),

                        const SizedBox(height: 8),
                        Divider(color: const Color(0xFFECEEF2), thickness: 1),
                        const SizedBox(height: 8),

                        // ── Total ────────────────────────────────────────
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'TOTAL',
                              style: GoogleFonts.outfit(
                                fontSize: isThermal ? 9 : 12,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF1B0C3C),
                              ),
                            ),
                            Text(
                              _formatCurrency(widget.totalPrice),
                              style: GoogleFonts.outfit(
                                fontSize: isThermal ? 10 : 14,
                                fontWeight: FontWeight.w900,
                                color: green,
                              ),
                            ),
                          ],
                        ),

                        // ── E-Resep QR Section ───────────────────────────
                        if (hasEResep) ...[
                          const SizedBox(height: 16),
                          Divider(color: const Color(0xFFECEEF2), thickness: 1),
                          const SizedBox(height: 12),

                          Center(
                            child: Column(
                              children: [
                                Text(
                                  'E-RESEP / ELECTRONIC PRESCRIPTION',
                                  style: GoogleFonts.outfit(
                                    fontSize: isThermal ? 7 : 8.5,
                                    fontWeight: FontWeight.w900,
                                    color: const Color(0xFF6F6A8A),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 10),

                                // Clean scannable QR — access control is handled
                                // server-side: non-apotek users see "No Permission"
                                Stack(
                                  alignment: Alignment.topRight,
                                  children: [
                                    QrImageView(
                                      data: qrData!,
                                      version: QrVersions.auto,
                                      size: isThermal ? 80 : 120,
                                      eyeStyle: const QrEyeStyle(
                                        eyeShape: QrEyeShape.square,
                                        color: Color(0xFF1B0C3C),
                                      ),
                                      dataModuleStyle: const QrDataModuleStyle(
                                        dataModuleShape:
                                            QrDataModuleShape.square,
                                        color: Color(0xFF1B0C3C),
                                      ),
                                    ),
                                    // Small badge: apotek-only indicator
                                    Container(
                                      margin: const EdgeInsets.only(
                                        top: 2,
                                        right: 2,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1B0C3C),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'APOTEK',
                                        style: GoogleFonts.outfit(
                                          fontSize: isThermal ? 4.5 : 6,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 8),
                                Text(
                                  'Scan dengan aplikasi Apotek untuk membuka resep',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.outfit(
                                    fontSize: isThermal ? 6.5 : 8.5,
                                    color: const Color(0xFF9E9EB0),
                                  ),
                                ),
                                Text(
                                  'ID: ${widget.electronicPrescriptionId ?? "-"}',
                                  style: GoogleFonts.outfit(
                                    fontSize: isThermal ? 6 : 7.5,
                                    color: const Color(0xFFBBBBCC),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),

                                // List manual prescription items
                                if (widget.medicines.any(
                                  (m) => m['isManual'] == true,
                                )) ...[
                                  const SizedBox(height: 10),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8F9FF),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: const Color(0xFFE8E8F0),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'DAFTAR RESEP MANUAL',
                                          style: GoogleFonts.outfit(
                                            fontSize: isThermal ? 6.5 : 8,
                                            fontWeight: FontWeight.w900,
                                            color: const Color(0xFF6F6A8A),
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        ...widget.medicines
                                            .where((m) => m['isManual'] == true)
                                            .map(
                                              (m) => Padding(
                                                padding: const EdgeInsets.only(
                                                  bottom: 4,
                                                ),
                                                child: Row(
                                                  children: [
                                                    const Icon(
                                                      Icons.circle,
                                                      size: 4,
                                                      color: Color(0xFF9E9EB0),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Expanded(
                                                      child: Text(
                                                        '${m['name']} × ${((m['quantity'] as double?) ?? 1).toInt()}',
                                                        style:
                                                            GoogleFonts.outfit(
                                                              fontSize:
                                                                  isThermal
                                                                  ? 6.5
                                                                  : 9,
                                                              color:
                                                                  const Color(
                                                                    0xFF3D3D5C,
                                                                  ),
                                                            ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 16),
                        Divider(color: const Color(0xFFECEEF2), thickness: 1),
                        const SizedBox(height: 8),

                        // ── Footer ───────────────────────────────────────
                        Center(
                          child: Column(
                            children: [
                              Text(
                                'Terima kasih atas kepercayaan Anda.',
                                style: GoogleFonts.outfit(
                                  fontSize: isThermal ? 7 : 9,
                                  color: const Color(0xFF9E9EB0),
                                ),
                              ),
                              Text(
                                'Powered by MAPOTECH',
                                style: GoogleFonts.outfit(
                                  fontSize: isThermal ? 6 : 8,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFFBBBBCC),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _invoiceRow(String label, String value, bool isThermal) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: isThermal ? 60 : 110,
            child: Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: isThermal ? 7 : 9,
                color: const Color(0xFF9E9EB0),
              ),
            ),
          ),
          Text(
            ': ',
            style: GoogleFonts.outfit(
              fontSize: isThermal ? 7 : 9,
              color: const Color(0xFF9E9EB0),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.outfit(
                fontSize: isThermal ? 7 : 9,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1B0C3C),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _billRow(
    String name,
    String price,
    String qty,
    bool isThermal, {
    required bool isManual,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.outfit(
                    fontSize: isThermal ? 7.5 : 10,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1B0C3C),
                  ),
                ),
                if (isManual)
                  Text(
                    'RESEP MANUAL',
                    style: GoogleFonts.outfit(
                      fontSize: isThermal ? 6 : 7.5,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF9B59B6),
                      letterSpacing: 0.3,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                price,
                style: GoogleFonts.outfit(
                  fontSize: isThermal ? 8 : 10,
                  fontWeight: FontWeight.w900,
                  color: isManual
                      ? const Color(0xFF9B59B6)
                      : const Color(0xFF1B0C3C),
                ),
              ),
              Text(
                qty,
                style: GoogleFonts.outfit(
                  fontSize: isThermal ? 6 : 8,
                  color: const Color(0xFF9E9EB0),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
