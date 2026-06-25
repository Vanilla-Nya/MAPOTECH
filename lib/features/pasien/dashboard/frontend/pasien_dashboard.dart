import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapotech/shared/widgets/skeleton_loading.dart';
import 'package:mapotech/features/landing/landing_page_data.dart';
import 'package:mapotech/shared/widgets/custom_button.dart';
import 'package:mapotech/shared/supabase_service.dart';

class PasienDashboard extends ConsumerStatefulWidget {
  final Function(String menu)? onNavigate;
  const PasienDashboard({super.key, this.onNavigate});

  @override
  ConsumerState<PasienDashboard> createState() => _PasienDashboardState();
}

class _PasienDashboardState extends ConsumerState<PasienDashboard> {
  final SupabaseService _db = SupabaseService();
  bool _isLoading = true;
  int _activePrescriptionsCount = 0;
  Map<String, dynamic>? _nextAppointment;
  String _doctorName = '';

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    await Future.wait([
      _loadPrescriptionCount(),
      _loadNextAppointment(),
    ]);
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  String _calculateAge(String? birthDateStr) {
    if (birthDateStr == null || birthDateStr.isEmpty) return '25 tahun';
    try {
      final birthDate = DateTime.parse(birthDateStr);
      final today = DateTime.now();
      int age = today.year - birthDate.year;
      if (today.month < birthDate.month || (today.month == birthDate.month && today.day < birthDate.day)) {
        age--;
      }
      return '$age tahun';
    } catch (_) {
      return '25 tahun';
    }
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

  Future<void> _loadPrescriptionCount() async {
    final user = ref.read(landingPageProvider).loggedInUser;
    if (user == null) return;
    try {
      final String patientName = user['name'] ?? '';
      final rawRx = await _db.fetchAllPrescriptions();
      int count = 0;
      for (final rx in rawRx) {
        final notes = rx['notes'] ?? '';
        String pName = '';
        try {
          if (notes.startsWith('{')) {
            final decoded = jsonDecode(notes);
            pName = decoded['patientName'] ?? '';
          } else if (notes.contains('|')) {
            pName = notes.split('|').first.trim();
          } else {
            pName = notes;
          }
        } catch (_) {}
        if (pName.toLowerCase().contains(patientName.toLowerCase())) {
          if (rx['status'] != 'checked_out') {
            count++;
          }
        }
      }
      if (mounted) {
        setState(() {
          _activePrescriptionsCount = count;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _activePrescriptionsCount = 1; // fallback mock
        });
      }
    }
  }

  Future<void> _loadNextAppointment() async {
    final user = ref.read(landingPageProvider).loggedInUser;
    if (user == null) return;
    try {
      final rawQueues = await _db.fetchPatientQueues(user['id']);
      if (rawQueues.isNotEmpty) {
        // Sort queues by date_queue desc to get latest
        rawQueues.sort((a, b) {
          final da = a['date_queue'] ?? '';
          final db = b['date_queue'] ?? '';
          return db.compareTo(da);
        });
        final nextQ = rawQueues.first;
        final docId = nextQ['id_doctor'] ?? '';
        String docName = 'dr. Agoes Soetanto';
        if (docId.isNotEmpty) {
          final docUser = await _db.fetchUserById(docId);
          if (docUser != null) {
            docName = docUser['name'] ?? docName;
          }
        }
        if (mounted) {
          setState(() {
            _nextAppointment = nextQ;
            _doctorName = docName;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _nextAppointment = null;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _nextAppointment = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(landingPageProvider);
    final user = state.loggedInUser;

    final isDark = state.appearance == 'dark';
    final cardBgColor = isDark ? const Color(0xFF161619) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1B0C3C);
    final subtitleColor = isDark ? Colors.grey[400]! : const Color(0xFF6F6A8A);
    final borderColor = isDark ? const Color(0xFF252528) : const Color(0xFFECEEF2);

    final isMobile = MediaQuery.of(context).size.width < 768;

    final name = user?['name'] ?? 'Alvin';
    final initials = name.isNotEmpty
        ? name.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase()
        : 'AL';
    final ageStr = _calculateAge(user?['birth_date']);
    final village = user?['village'] ?? 'KEJAYAN';
    final domisili = 'Kel. ${village.toUpperCase()}';
    final nik = user?['nik'] ?? '3511081208000003';

    return _isLoading
        ? const SkeletonScope(
            child: SkeletonDashboard(),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Card User Profile (Alvin 25 tahun, domisili, NIK)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: cardBgColor,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    // Profile circle
                    Container(
                      width: 70,
                      height: 70,
                      decoration: const BoxDecoration(
                        color: Color(0xFF48C9B0),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        initials.isEmpty ? 'AL' : initials,
                        style: GoogleFonts.outfit(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),

                    // Patient details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: GoogleFonts.outfit(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              _buildProfileSubInfo('USIA', ageStr, subtitleColor, textColor),
                              const SizedBox(width: 14),
                              _buildProfileSubInfo('DOMISILI', domisili, subtitleColor, textColor),
                              const SizedBox(width: 14),
                              _buildProfileSubInfo('NIK', nik, subtitleColor, textColor),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Edit profile action button
                    if (!isMobile)
                      CustomButton(
                        text: 'Edit Profil',
                        icon: Icons.edit_rounded,
                        height: 38,
                        onPressed: () {
                          widget.onNavigate?.call('profile');
                        },
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Main booking cards (dr. Agoes Soetanto quick link, prescription QR card)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left link: Booking Dokter
                  Expanded(
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () {
                          widget.onNavigate?.call('dokter_search');
                        },
                        child: Container(
                          height: 120,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: cardBgColor,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: borderColor),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFB577F2).withOpacity(0.12),
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: const Icon(Icons.sync_rounded, color: Color(0xFFB577F2)),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'BOOKING LAGI',
                                      style: GoogleFonts.outfit(fontSize: 8, fontWeight: FontWeight.bold, color: subtitleColor, letterSpacing: 0.5),
                                    ),
                                    Text(
                                      'dr. Agoes Soetanto',
                                      style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900, color: textColor),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right_rounded, color: Color(0xFFB577F2)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),

                  // Right link: QR Prescription
                  Expanded(
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () {
                          if (_activePrescriptionsCount > 0) {
                            widget.onNavigate?.call('prescription');
                          } else {
                            widget.onNavigate?.call('dokter_search');
                          }
                        },
                        child: Container(
                          height: 120,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: cardBgColor,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: borderColor),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFB577F2).withOpacity(0.12),
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: const Icon(Icons.qr_code_rounded, color: Color(0xFFB577F2)),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'QR RESEP',
                                      style: GoogleFonts.outfit(fontSize: 8, color: subtitleColor, fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      _activePrescriptionsCount > 0
                                          ? 'Ada $_activePrescriptionsCount resep aktif yang belum tebus'
                                          : 'Konsultasi dulu untuk mendapatkan resep',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.outfit(fontSize: 10, color: subtitleColor),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _activePrescriptionsCount > 0
                                          ? 'LIHAT RESEP SEKARANG >'
                                          : 'BOOKING SEKARANG >',
                                      style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w900, color: const Color(0xFFB577F2)),
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
                ],
              ),

              const SizedBox(height: 28),

              // Row containing Map Location Mockup Card and Next Consultation Card
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left: Next Consultation Status
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '🗓️  Janji Temu',
                          style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w900, color: textColor),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          height: 280,
                          decoration: BoxDecoration(
                            color: cardBgColor,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: borderColor),
                          ),
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'JANJI TEMU BERIKUTNYA',
                                style: GoogleFonts.outfit(fontSize: 8, fontWeight: FontWeight.w900, color: const Color(0xFFB577F2), letterSpacing: 0.5),
                              ),
                              const SizedBox(height: 20),
                              if (_nextAppointment != null) ...[
                                Row(
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFB577F2).withOpacity(0.12),
                                        shape: BoxShape.circle,
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        _doctorName.isNotEmpty && _doctorName.length > 3
                                            ? _doctorName.split(' ').where((e) => e != 'dr.').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase()
                                            : 'DR',
                                        style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: const Color(0xFFB577F2)),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _doctorName,
                                            style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w900, color: textColor),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Tanggal: ${_formatDate(_nextAppointment!['date_queue'] ?? '')}',
                                            style: GoogleFonts.outfit(fontSize: 11, color: subtitleColor),
                                          ),
                                          if (_nextAppointment!['queue_number'] != null) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              'Nomor Antrian: #${_nextAppointment!['queue_number']}',
                                              style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFFB577F2)),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 18),
                                CustomButton(
                                  text: 'Lihat Riwayat Medis',
                                  icon: Icons.history_rounded,
                                  height: 38,
                                  onPressed: () {
                                    widget.onNavigate?.call('history');
                                  },
                                ),
                              ] else ...[
                                Row(
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFB577F2).withOpacity(0.12),
                                        shape: BoxShape.circle,
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        'DR',
                                        style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: const Color(0xFFB577F2)),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Text(
                                        'Belum ada janji temu',
                                        style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w900, color: textColor),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 18),
                                CustomButton(
                                  text: 'Buat Janji Temu',
                                  icon: Icons.add_rounded,
                                  height: 38,
                                  onPressed: () {
                                    widget.onNavigate?.call('dokter_search');
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),

                  // Right: Map Mockup (Lokasi Anda)
                  Expanded(
                    flex: 6,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '📍  Lokasi Anda',
                              style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w900, color: textColor),
                            ),
                            MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: GestureDetector(
                                onTap: () {
                                  widget.onNavigate?.call('profile');
                                },
                                child: Text(
                                  'PERBARUI DATA',
                                  style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w900, color: const Color(0xFFB577F2)),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Container(
                            height: 280,
                            decoration: BoxDecoration(
                              color: cardBgColor,
                              border: Border.all(color: borderColor),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Stack(
                              children: [
                                // Map Simulator Background grid/image
                                Image.network(
                                  'https://images.unsplash.com/photo-1524661135-423995f22d0b?q=80&w=800',
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: double.infinity,
                                ),
                                // Dark Overlay for map aesthetics
                                Container(color: Colors.white.withOpacity(0.65)),
                                
                                // Pin Icon Mockup
                                Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 32,
                                        height: 32,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF48C9B0),
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.white, width: 2.0),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.2),
                                              blurRadius: 8,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: const Icon(Icons.add_rounded, color: Colors.white, size: 16),
                                      ),
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.indigo,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          domisili.toUpperCase(),
                                          style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
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
              ),
            ],
          );
  }

  Widget _buildProfileSubInfo(String title, String val, Color subCol, Color textCol) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.outfit(fontSize: 8, fontWeight: FontWeight.bold, color: subCol, letterSpacing: 0.5),
        ),
        const SizedBox(height: 2),
        Text(
          val,
          style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: textCol),
        ),
      ],
    );
  }
}
