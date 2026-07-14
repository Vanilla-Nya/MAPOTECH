import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapotech/shared/widgets/skeleton_loading.dart';
import 'package:mapotech/features/landing/landing_page_data.dart';
import 'package:mapotech/shared/widgets/animated_transitions.dart';
import 'package:mapotech/shared/widgets/custom_button.dart';
import 'package:mapotech/shared/supabase_service.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong2.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mapotech/features/pasien/dashboard/frontend/pasien_dokter_search.dart';

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
  LatLng? _currentLocation;
  List<Map<String, dynamic>> _doctors = [];
  List<Map<String, dynamic>> _pharmacies = [];

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
      _fetchCurrentLocation(),
      _loadMapMarkers(),
    ]);
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchCurrentLocation() async {
    try {
      bool serviceEnabled;
      LocationPermission permission;

      // On web we can check permission or ask directly
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      if (permission == LocationPermission.deniedForever) return;

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (mounted) {
        setState(() {
          _currentLocation = LatLng(position.latitude, position.longitude);
        });
      }
    } catch (e) {
      debugPrint('Error fetching device location: $e');
    }
  }

  Future<void> _loadMapMarkers() async {
    try {
      final docs = await _db.fetchAllDoctors();
      final pharms = await _db.fetchAllPharmacies();
      if (mounted) {
        setState(() {
          _doctors = docs
              .where((d) => d['latitude'] != null && d['longitude'] != null)
              .toList();
          _pharmacies = pharms
              .where((p) => p['latitude'] != null && p['longitude'] != null)
              .toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading map markers: $e');
    }
  }

  String _calculateAge(String? birthDateStr) {
    if (birthDateStr == null || birthDateStr.isEmpty) return '25 tahun';
    try {
      final birthDate = DateTime.parse(birthDateStr);
      final today = DateTime.now();
      int age = today.year - birthDate.year;
      if (today.month < birthDate.month ||
          (today.month == birthDate.month && today.day < birthDate.day)) {
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
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'Mei',
        'Jun',
        'Jul',
        'Agt',
        'Sep',
        'Okt',
        'Nov',
        'Des',
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
    final notifier = ref.read(landingPageProvider.notifier);
    final user = state.loggedInUser;

    final isDark = state.appearance == 'dark';
    final cardBgColor = notifier.getCardColor();
    final textColor = notifier.getTextColor();
    final subtitleColor = notifier.getBodyTextColor();
    final borderColor = notifier.getBorderColor();
    final themeAccent = notifier.getPrimaryColor();

    final isMobile = MediaQuery.of(context).size.width < 768;

    final name = user?['name'] ?? 'Alvin';
    final initials = name.isNotEmpty
        ? name
              .split(' ')
              .map((e) => e.isNotEmpty ? e[0] : '')
              .take(2)
              .join()
              .toUpperCase()
        : 'AL';
    final ageStr = _calculateAge(user?['birth_date']);
    final village = user?['village'] ?? 'KEJAYAN';
    final domisili = 'Kel. ${village.toUpperCase()}';
    final nik = user?['nik'] ?? '3511081208000003';

    return _isLoading
        ? const SkeletonScope(child: SkeletonDashboard())
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Card User Profile (Alvin 25 tahun, domisili, NIK)
              AnimatedEntrance(
                delay: Duration.zero,
                type: EntranceAnimationType.slideUp,
                child: Container(
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
                        decoration: BoxDecoration(
                          color: notifier.getPrimaryColor(),
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
                                _buildProfileSubInfo(
                                  'USIA',
                                  ageStr,
                                  subtitleColor,
                                  textColor,
                                ),
                                const SizedBox(width: 14),
                                _buildProfileSubInfo(
                                  'DOMISILI',
                                  domisili,
                                  subtitleColor,
                                  textColor,
                                ),
                                const SizedBox(width: 14),
                                _buildProfileSubInfo(
                                  'NIK',
                                  nik,
                                  subtitleColor,
                                  textColor,
                                ),
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
              ),

              const SizedBox(height: 20),

              // Main booking cards (dr. Agoes Soetanto quick link, prescription QR card)
              AnimatedEntrance(
                delay: const Duration(milliseconds: 100),
                type: EntranceAnimationType.scale,
                child: Row(
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
                                    color: themeAccent.withOpacity(0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: Icon(
                                    Icons.sync_rounded,
                                    color: themeAccent,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'BOOKING LAGI',
                                        style: GoogleFonts.outfit(
                                          fontSize: 8,
                                          fontWeight: FontWeight.bold,
                                          color: subtitleColor,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      Text(
                                        'dr. Agoes Soetanto',
                                        style: GoogleFonts.outfit(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w900,
                                          color: textColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  color: themeAccent,
                                ),
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
                                    color: themeAccent.withOpacity(0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: Icon(
                                    Icons.qr_code_rounded,
                                    color: themeAccent,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'QR RESEP',
                                        style: GoogleFonts.outfit(
                                          fontSize: 8,
                                          color: subtitleColor,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        _activePrescriptionsCount > 0
                                            ? 'Ada $_activePrescriptionsCount resep aktif yang belum tebus'
                                            : 'Konsultasi dulu untuk mendapatkan resep',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.outfit(
                                          fontSize: 10,
                                          color: subtitleColor,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        _activePrescriptionsCount > 0
                                            ? 'LIHAT RESEP SEKARANG >'
                                            : 'BOOKING SEKARANG >',
                                        style: GoogleFonts.outfit(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w900,
                                          color: themeAccent,
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
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Row containing Map Location Mockup Card and Next Consultation Card
              AnimatedEntrance(
                delay: const Duration(milliseconds: 200),
                type: EntranceAnimationType.slideUp,
                child: Row(
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
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: textColor,
                            ),
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
                                  style: GoogleFonts.outfit(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w900,
                                    color: themeAccent,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                if (_nextAppointment != null) ...[
                                  Row(
                                    children: [
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: themeAccent.withOpacity(0.12),
                                          shape: BoxShape.circle,
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          _doctorName.isNotEmpty &&
                                                  _doctorName.length > 3
                                              ? _doctorName
                                                    .split(' ')
                                                    .where((e) => e != 'dr.')
                                                    .map(
                                                      (e) => e.isNotEmpty
                                                          ? e[0]
                                                          : '',
                                                    )
                                                    .take(2)
                                                    .join()
                                                    .toUpperCase()
                                              : 'DR',
                                          style: GoogleFonts.outfit(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w900,
                                            color: themeAccent,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _doctorName,
                                              style: GoogleFonts.outfit(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w900,
                                                color: textColor,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Tanggal: ${_formatDate(_nextAppointment!['date_queue'] ?? '')}',
                                              style: GoogleFonts.outfit(
                                                fontSize: 11,
                                                color: subtitleColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? const Color(0xFF1E1E22)
                                          : const Color(0xFFF7F5FC),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'NOMOR ANTRIAN',
                                          style: GoogleFonts.outfit(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: subtitleColor,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        Text(
                                          _nextAppointment!['no_queue']
                                                  ?.toString() ??
                                              'A01',
                                          style: GoogleFonts.outfit(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w900,
                                            color: themeAccent,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  CustomButton(
                                    text: 'Detail Janji Temu',
                                    height: 38,
                                    onPressed: () {
                                      widget.onNavigate?.call('history');
                                    },
                                  ),
                                ] else ...[
                                  Center(
                                    child: Column(
                                      children: [
                                        Icon(
                                          Icons.calendar_today_rounded,
                                          size: 28,
                                          color: subtitleColor.withOpacity(0.5),
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          state.language == 'id'
                                              ? 'Belum ada janji temu'
                                              : 'No upcoming appointments',
                                          style: GoogleFonts.outfit(
                                            fontSize: 12,
                                            color: subtitleColor,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 20),
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
                                style: GoogleFonts.outfit(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  color: textColor,
                                ),
                              ),
                              MouseRegion(
                                cursor: SystemMouseCursors.click,
                                child: GestureDetector(
                                  onTap: () {
                                    widget.onNavigate?.call('profile');
                                  },
                                  child: Text(
                                    'PERBARUI DATA',
                                    style: GoogleFonts.outfit(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                      color: themeAccent,
                                    ),
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
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(24),
                                child: FlutterMap(
                                  options: MapOptions(
                                    initialCenter:
                                        _currentLocation ??
                                        const LatLng(
                                          -7.973,
                                          113.880,
                                        ), // Center on Pujer by default
                                    initialZoom: 14.0,
                                  ),
                                  children: [
                                    TileLayer(
                                      urlTemplate: isDark
                                          ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
                                          : 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                                      subdomains: const ['a', 'b', 'c', 'd'],
                                    ),
                                    MarkerLayer(
                                      markers:
                                          [
                                                // Current location marker (blue pulse)
                                                if (_currentLocation != null)
                                                  Marker(
                                                    point: _currentLocation!,
                                                    width: 40,
                                                    height: 40,
                                                    child: Container(
                                                      decoration: BoxDecoration(
                                                        color: themeAccent
                                                            .withOpacity(0.2),
                                                        shape: BoxShape.circle,
                                                      ),
                                                      alignment:
                                                          Alignment.center,
                                                      child: Container(
                                                        width: 14,
                                                        height: 14,
                                                        decoration:
                                                            BoxDecoration(
                                                              color:
                                                                  themeAccent,
                                                              shape: BoxShape
                                                                  .circle,
                                                              border: Border.all(
                                                                color: Colors
                                                                    .white,
                                                                width: 2.0,
                                                              ),
                                                            ),
                                                      ),
                                                    ),
                                                  ),

                                                // Doctor pins
                                                ..._doctors.map((doc) {
                                                  final lat = double.tryParse(
                                                    doc['latitude']
                                                            ?.toString() ??
                                                        '',
                                                  );
                                                  final lng = double.tryParse(
                                                    doc['longitude']
                                                            ?.toString() ??
                                                        '',
                                                  );
                                                  if (lat == null ||
                                                      lng == null) {
                                                    return const Marker(
                                                      point: LatLng(0, 0),
                                                      child: SizedBox.shrink(),
                                                    );
                                                  }
                                                  return Marker(
                                                    point: LatLng(lat, lng),
                                                    width: 40,
                                                    height: 40,
                                                    child: MouseRegion(
                                                      cursor: SystemMouseCursors
                                                          .click,
                                                      child: GestureDetector(
                                                        onTap: () {
                                                          showDialog(
                                                            context: context,
                                                            barrierColor: Colors
                                                                .black
                                                                .withOpacity(
                                                                  0.45,
                                                                ),
                                                            builder: (ctx) =>
                                                                DoctorDetailDialog(
                                                                  dokter: doc,
                                                                  isDark:
                                                                      isDark,
                                                                ),
                                                          );
                                                        },
                                                        child: Container(
                                                          decoration: BoxDecoration(
                                                            color: Colors
                                                                .redAccent,
                                                            shape:
                                                                BoxShape.circle,
                                                            border: Border.all(
                                                              color:
                                                                  Colors.white,
                                                              width: 2.0,
                                                            ),
                                                            boxShadow: [
                                                              BoxShadow(
                                                                color: Colors
                                                                    .black
                                                                    .withOpacity(
                                                                      0.2,
                                                                    ),
                                                                blurRadius: 6,
                                                                offset:
                                                                    const Offset(
                                                                      0,
                                                                      3,
                                                                    ),
                                                              ),
                                                            ],
                                                          ),
                                                          child: const Icon(
                                                            Icons
                                                                .medical_services_rounded,
                                                            color: Colors.white,
                                                            size: 14,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  );
                                                }),

                                                // Pharmacy pins
                                                ..._pharmacies.map((pharm) {
                                                  final lat = double.tryParse(
                                                    pharm['latitude']
                                                            ?.toString() ??
                                                        '',
                                                  );
                                                  final lng = double.tryParse(
                                                    pharm['longitude']
                                                            ?.toString() ??
                                                        '',
                                                  );
                                                  if (lat == null ||
                                                      lng == null) {
                                                    return const Marker(
                                                      point: LatLng(0, 0),
                                                      child: SizedBox.shrink(),
                                                    );
                                                  }
                                                  return Marker(
                                                    point: LatLng(lat, lng),
                                                    width: 40,
                                                    height: 40,
                                                    child: MouseRegion(
                                                      cursor: SystemMouseCursors
                                                          .click,
                                                      child: GestureDetector(
                                                        onTap: () {
                                                          showDialog(
                                                            context: context,
                                                            barrierColor: Colors
                                                                .black
                                                                .withOpacity(
                                                                  0.45,
                                                                ),
                                                            builder: (ctx) =>
                                                                PharmacyDetailDialog(
                                                                  pharmacy:
                                                                      pharm,
                                                                  isDark:
                                                                      isDark,
                                                                ),
                                                          );
                                                        },
                                                        child: Container(
                                                          decoration: BoxDecoration(
                                                            color: const Color(
                                                              0xFF2EC4B6,
                                                            ),
                                                            shape:
                                                                BoxShape.circle,
                                                            border: Border.all(
                                                              color:
                                                                  Colors.white,
                                                              width: 2.0,
                                                            ),
                                                            boxShadow: [
                                                              BoxShadow(
                                                                color: Colors
                                                                    .black
                                                                    .withOpacity(
                                                                      0.2,
                                                                    ),
                                                                blurRadius: 6,
                                                                offset:
                                                                    const Offset(
                                                                      0,
                                                                      3,
                                                                    ),
                                                              ),
                                                            ],
                                                          ),
                                                          child: const Icon(
                                                            Icons
                                                                .local_pharmacy_rounded,
                                                            color: Colors.white,
                                                            size: 14,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  );
                                                }),
                                              ]
                                              .where(
                                                (m) =>
                                                    m.point.latitude != 0.0 &&
                                                    m.point.longitude != 0.0,
                                              )
                                              .toList(),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
  }

  Widget _buildProfileSubInfo(
    String title,
    String val,
    Color subCol,
    Color textCol,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 8,
            fontWeight: FontWeight.bold,
            color: subCol,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          val,
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.w900,
            color: textCol,
          ),
        ),
      ],
    );
  }
}

class PharmacyDetailDialog extends StatelessWidget {
  final Map<String, dynamic> pharmacy;
  final bool isDark;

  const PharmacyDetailDialog({
    super.key,
    required this.pharmacy,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? const Color(0xFF161619) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1B0C3C);
    final subtitleColor = isDark ? Colors.grey[400]! : const Color(0xFF6F6A8A);
    final borderColor = isDark
        ? const Color(0xFF252528)
        : const Color(0xFFECEEF2);
    final sectionBg = isDark
        ? const Color(0xFF1E1E22)
        : const Color(0xFFF8FAFD);
    final green = const Color(0xFF27AE60);
    final themeAccent = const Color(0xFF48C9B0);

    final faskes = pharmacy['nama_faskes'] ?? 'Apotek Mandiri';
    final name = pharmacy['name'] ?? '';
    final address = pharmacy['address'] ?? '';
    final about =
        pharmacy['about'] ??
        'Selamat datang di apotek kami. Kami berkomitmen untuk menyediakan obat-obatan berkualitas tinggi dan layanan kefarmasian terbaik bagi Anda.';
    final phone = pharmacy['whatsapp_number'] ?? '';
    final bool verified = pharmacy['is_visible'] ?? true;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor: cardBg,
      child: Container(
        width: 480,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: themeAccent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.local_pharmacy_rounded,
                    color: themeAccent,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        faskes,
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: textColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (name.isNotEmpty && name != faskes)
                        Text(
                          'Apoteker: $name',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: subtitleColor,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                  color: subtitleColor,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Verified Badge
            if (verified)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: green.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: green.withOpacity(0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified_rounded, size: 14, color: green),
                    const SizedBox(width: 6),
                    Text(
                      'Mapotek Verified Pharmacy',
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: green,
                      ),
                    ),
                  ],
                ),
              ),

            // Details section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: sectionBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow(
                    Icons.location_on_outlined,
                    'Alamat',
                    address,
                    textColor,
                    subtitleColor,
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    Icons.access_time_rounded,
                    'Jam Operasional',
                    pharmacy['jam_kerja'] ?? '08:00 - 21:00',
                    textColor,
                    subtitleColor,
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    Icons.info_outline_rounded,
                    'Tentang Apotek',
                    about,
                    textColor,
                    subtitleColor,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      if (phone.isNotEmpty) {
                        var clean = phone.replaceAll(RegExp(r'\D'), '');
                        if (clean.startsWith('0')) {
                          clean = '62${clean.substring(1)}';
                        } else if (clean.startsWith('8')) {
                          clean = '62$clean';
                        }
                        final uri = Uri.parse("https://wa.me/$clean");
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(
                            uri,
                            mode: LaunchMode.externalApplication,
                          );
                        }
                      }
                    },
                    icon: const Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 16,
                    ),
                    label: const Text('Hubungi Apotek'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: green,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                if (pharmacy['google_maps_link'] != null &&
                    pharmacy['google_maps_link'].toString().isNotEmpty)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final uri = Uri.parse(pharmacy['google_maps_link']);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(
                            uri,
                            mode: LaunchMode.externalApplication,
                          );
                        }
                      },
                      icon: const Icon(Icons.map_outlined, size: 16),
                      label: const Text('Petunjuk Arah'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: themeAccent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    IconData icon,
    String label,
    String value,
    Color textColor,
    Color subtitleColor,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: subtitleColor),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: subtitleColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
