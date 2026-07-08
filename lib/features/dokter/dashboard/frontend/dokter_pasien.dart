import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapotech/shared/widgets/skeleton_loading.dart';
import 'package:mapotech/features/landing/landing_page_data.dart';
import 'package:mapotech/shared/widgets/custom_button.dart';
import 'package:mapotech/shared/supabase_service.dart';
import 'dart:ui' show ImageFilter;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:typed_data';
import 'dart:io' as io;

// ─── Data Models ─────────────────────────────────────────────────────────────

class PasienModel {
  final String id;
  final String nama;
  final String email;
  final String nik;
  final String tempatLahir;
  final String tanggalLahir;
  final String jenisKelamin; // 'Laki-laki' or 'Perempuan'
  final String telepon;
  final String alamat;
  final String umur;
  final Color avatarBg;
  final List<String> history;
  final String? satusehatId;
  final String? avatarUrl;

  const PasienModel({
    required this.id,
    required this.nama,
    required this.email,
    required this.nik,
    required this.tempatLahir,
    required this.tanggalLahir,
    required this.jenisKelamin,
    required this.telepon,
    required this.alamat,
    required this.umur,
    required this.avatarBg,
    required this.history,
    this.satusehatId,
    this.avatarUrl,
  });

  PasienModel copyWith({
    String? id,
    String? nama,
    String? email,
    String? nik,
    String? tempatLahir,
    String? tanggalLahir,
    String? jenisKelamin,
    String? telepon,
    String? alamat,
    String? umur,
    Color? avatarBg,
    List<String>? history,
    String? satusehatId,
    String? avatarUrl,
  }) {
    return PasienModel(
      id: id ?? this.id,
      nama: nama ?? this.nama,
      email: email ?? this.email,
      nik: nik ?? this.nik,
      tempatLahir: tempatLahir ?? this.tempatLahir,
      tanggalLahir: tanggalLahir ?? this.tanggalLahir,
      jenisKelamin: jenisKelamin ?? this.jenisKelamin,
      telepon: telepon ?? this.telepon,
      alamat: alamat ?? this.alamat,
      umur: umur ?? this.umur,
      avatarBg: avatarBg ?? this.avatarBg,
      history: history ?? this.history,
      satusehatId: satusehatId ?? this.satusehatId,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }
}

// ─── Riverpod State Provider ──────────────────────────────────────────────────

class DokterPasienListNotifier extends StateNotifier<List<PasienModel>> {
  DokterPasienListNotifier() : super([]) {
    loadPatients();
  }

  final SupabaseService _db = SupabaseService();
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Future<void> loadPatients() async {
    _isLoading = true;
    try {
      final dbPatients = await _db.fetchAllPatients();
      final dbQueues = await _db.fetchAllQueues();
      final dbEncounters = await _db.fetchAllClinicalEncounters();

      final encounterQueueIds = dbEncounters
          .map((e) => e['id_queue'] as String?)
          .toSet();

      final Map<String, List<String>> patientHistories = {};
      for (final q in dbQueues) {
        final patientId = q['id_patient'] as String?;
        final queueId = q['id'] as String?;
        final dateQueueStr = q['date_queue'] as String?;

        if (patientId != null && queueId != null && dateQueueStr != null) {
          if (encounterQueueIds.contains(queueId)) {
            patientHistories.putIfAbsent(patientId, () => []);
            final formattedDate = _formatQueueDate(dateQueueStr);
            patientHistories[patientId]!.add('$queueId|$formattedDate');
          }
        }
      }

      final mapped = dbPatients.map((p) {
        final birthDateStr = p['birth_date'] as String? ?? '2000-01-01';
        final ageStr = _calculateAgeStr(birthDateStr);
        final genderIndo =
            (p['gender'] == 'female' || p['gender'] == 'Perempuan')
            ? 'Perempuan'
            : 'Laki-laki';
        final patientId = p['id'] as String? ?? '';
        final historyList = patientHistories[patientId] ?? [];
        final uniqueHistory = historyList.toSet().toList();

        return PasienModel(
          id: patientId,
          nama: p['name'] as String? ?? '',
          email: p['email'] as String? ?? '',
          nik: p['nik'] as String? ?? '',
          tempatLahir: p['birth_place'] as String? ?? 'Bondowoso',
          tanggalLahir: birthDateStr,
          jenisKelamin: genderIndo,
          telepon: p['phone_number'] as String? ?? '-',
          alamat: p['address'] as String? ?? '-',
          umur: ageStr,
          avatarBg: _getAvatarColor(p['name'] as String? ?? ''),
          history: uniqueHistory,
          satusehatId: p['satusehat_id'] as String?,
          avatarUrl: p['avatar_url'] as String?,
        );
      }).toList();

      state = mapped;
    } catch (e) {
      debugPrint('Error loading patients from Supabase: $e');
    } finally {
      _isLoading = false;
    }
  }

  String _formatQueueDate(String dateStr) {
    try {
      final parts = dateStr.split('-');
      if (parts.length == 3) {
        final monthNum = int.parse(parts[1]);
        final day = parts[2];

        final months = [
          'Jan',
          'Feb',
          'Mar',
          'Apr',
          'May',
          'Jun',
          'Jul',
          'Aug',
          'Sep',
          'Oct',
          'Nov',
          'Dec',
        ];
        if (monthNum >= 1 && monthNum <= 12) {
          return '${months[monthNum - 1]} $day';
        }
      }
    } catch (_) {}
    return dateStr;
  }

  String _calculateAgeStr(String birthDateStr) {
    try {
      final birthDate = DateTime.parse(birthDateStr);
      final today = DateTime.now();
      int age = today.year - birthDate.year;
      if (today.month < birthDate.month ||
          (today.month == birthDate.month && today.day < birthDate.day)) {
        age--;
      }
      return '$age th';
    } catch (_) {
      return '24 th';
    }
  }

  Color _getAvatarColor(String name) {
    final colors = [
      const Color(0xFFF1948A), // Light red/pink
      const Color(0xFFC39BD3), // Purple
      const Color(0xFF7FB3D5), // Blue
      const Color(0xFF76D7C4), // Greenish
      const Color(0xFFF7DC6F), // Yellow/amber
      const Color(0xFFF5B041), // Orange
      const Color(0xFF85929E), // Greyish blue
    ];
    if (name.isEmpty) return colors[0];
    int hash = 0;
    for (int i = 0; i < name.length; i++) {
      hash = name.codeUnitAt(i) + ((hash << 5) - hash);
    }
    return colors[hash.abs() % colors.length];
  }

  void addPasien(PasienModel pasien) {
    state = [...state, pasien];
  }

  void deletePasien(String id) {
    state = state.where((p) => p.id != id).toList();
  }
}

final dokterPasienListProvider =
    StateNotifierProvider<DokterPasienListNotifier, List<PasienModel>>((ref) {
      return DokterPasienListNotifier();
    });

// ─── Dokter Pasien View ───────────────────────────────────────────────────────

class DokterPasien extends ConsumerStatefulWidget {
  const DokterPasien({super.key});

  @override
  ConsumerState<DokterPasien> createState() => _DokterPasienState();
}

class _DokterPasienState extends ConsumerState<DokterPasien> {
  String _searchQuery = '';
  String _sortOption = 'nama'; // 'nama', 'id'
  bool _sortAscending = true;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(landingPageProvider);
    final allPatients = ref.watch(dokterPasienListProvider);

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

    // Filter patients based on query
    List<PasienModel> filteredPatients = allPatients.where((p) {
      final query = _searchQuery.toLowerCase();
      return p.nama.toLowerCase().contains(query) ||
          p.id.toLowerCase().contains(query) ||
          p.nik.contains(query);
    }).toList();

    // Sort patients
    filteredPatients.sort((a, b) {
      int comparison = 0;
      if (_sortOption == 'nama') {
        comparison = a.nama.compareTo(b.nama);
      } else {
        comparison = a.id.compareTo(b.id);
      }
      return _sortAscending ? comparison : -comparison;
    });

    final isMobile = MediaQuery.of(context).size.width < 768;
    final isTablet =
        MediaQuery.of(context).size.width >= 768 &&
        MediaQuery.of(context).size.width < 1100;
    final int crossAxisCount = isMobile ? 1 : (isTablet ? 2 : 4);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ─── Header Section ───────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Daftar Pasien'.tr(state),
                    style: GoogleFonts.outfit(
                      fontSize: isMobile ? 22 : 28,
                      fontWeight: FontWeight.w900,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Kelola konsultasi aktif dan riwayat pasien'.tr(state),
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: subtitleColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // ─── Control Bar (Search, Sort, Add) ───────────────────
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
                  Row(
                    children: [
                      Expanded(
                        child: _buildSortButton(
                          isDark,
                          textColor,
                          subtitleColor,
                          borderColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      CustomButton(
                        text: 'Tambah Pasien'.tr(state),
                        icon: Icons.add_rounded,
                        primaryColor: purpleAccent,
                        textColor: Colors.white,
                        height: 46,
                        onPressed: () => _showAddPatientDialog(context, isDark),
                      ),
                    ],
                  ),
                ],
              )
            : Row(
                children: [
                  Expanded(
                    child: _buildSearchField(
                      isDark,
                      textColor,
                      subtitleColor,
                      borderColor,
                    ),
                  ),
                  const SizedBox(width: 16),
                  _buildSortButton(
                    isDark,
                    textColor,
                    subtitleColor,
                    borderColor,
                  ),
                  const SizedBox(width: 16),
                  CustomButton(
                    text: 'Tambah Pasien'.tr(state),
                    icon: Icons.add_rounded,
                    primaryColor: purpleAccent,
                    textColor: Colors.white,
                    height: 46,
                    onPressed: () => _showAddPatientDialog(context, isDark),
                  ),
                ],
              ),

        const SizedBox(height: 24),

        // ─── Patient Card Grid ─────────────────────────────────
        ref.watch(dokterPasienListProvider.notifier).isLoading &&
                allPatients.isEmpty
            ? const SkeletonScope(child: SkeletonPatientGrid())
            : filteredPatients.isEmpty
            ? _buildEmptyState(
                Icons.people_outline_rounded,
                'Pasien tidak ditemukan'.tr(state),
                'Coba gunakan kata kunci pencarian yang berbeda.'.tr(state),
                subtitleColor,
                textColor,
                cardBgColor,
                borderColor,
              )
            : GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredPatients.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 18,
                  mainAxisSpacing: 18,
                  childAspectRatio: isMobile ? 1.15 : 0.85,
                ),
                itemBuilder: (context, index) {
                  final patient = filteredPatients[index];
                  return PasienCard(
                    patient: patient,
                    cardBg: cardBgColor,
                    border: borderColor,
                    text: textColor,
                    subtitle: subtitleColor,
                    accent: themeAccent,
                    purple: purpleAccent,
                    onTap: () {
                      _showDetailDialog(
                        context,
                        patient,
                        cardBgColor,
                        textColor,
                        subtitleColor,
                        borderColor,
                        themeAccent,
                      );
                    },
                  );
                },
              ),
      ],
    );
  }

  // ─── UI Helper Components ──────────────────────────────────────────────────

  Widget _buildSearchField(
    bool isDark,
    Color textColor,
    Color subtitleColor,
    Color borderColor,
  ) {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E22) : const Color(0xFFF1EEFA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 20, color: subtitleColor),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                });
              },
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
              decoration: InputDecoration(
                hintText: 'Cari nama, NIK, atau ID...'.tr(
                  ref.read(landingPageProvider),
                ),
                hintStyle: GoogleFonts.outfit(
                  fontSize: 13,
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

  Widget _buildSortButton(
    bool isDark,
    Color textColor,
    Color subtitleColor,
    Color borderColor,
  ) {
    final state = ref.read(landingPageProvider);
    final isEn = state.language == 'en';
    final sortLabel = _sortOption == 'nama'
        ? (isEn
              ? 'Name (${_sortAscending ? 'A-Z' : 'Z-A'})'
              : 'Nama (${_sortAscending ? 'A-Z' : 'Z-A'})')
        : (_sortAscending
              ? (isEn ? 'ID (Oldest)' : 'ID (Terlama)')
              : (isEn ? 'ID (Newest)' : 'ID (Terbaru)'));

    return InkWell(
      onTap: () {
        setState(() {
          if (_sortOption == 'nama') {
            if (_sortAscending) {
              _sortAscending = false;
            } else {
              _sortOption = 'id';
              _sortAscending = false; // Terbaru
            }
          } else {
            if (!_sortAscending) {
              _sortAscending = true; // Terlama
            } else {
              _sortOption = 'nama';
              _sortAscending = true; // A-Z
            }
          }
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF161619) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.swap_vert_rounded, size: 18, color: subtitleColor),
            const SizedBox(width: 8),
            Text(
              sortLabel,
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Classes HeartbeatPainter and PasienCard moved to top-level scope at the bottom of the file

  Widget _buildEmptyState(
    IconData icon,
    String title,
    String desc,
    Color subCol,
    Color textCol,
    Color cardBg,
    Color border,
  ) {
    return Container(
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: subCol.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 24, color: subCol),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: textCol,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            desc,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 11,
              color: subCol,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Dialogs and Actions ───────────────────────────────────────────────────

  void _showAddPatientDialog(BuildContext context, bool isDark) {
    final state = ref.read(landingPageProvider);
    final isRev = state.appearance == 'rev';
    final purple = ref.read(landingPageProvider.notifier).getPrimaryColor();
    final cardBg = isDark ? const Color(0xFF161619) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1B0C3C);
    final subtitleColor = isDark ? Colors.grey[400]! : const Color(0xFF6F6A8A);
    final borderColor = isDark
        ? const Color(0xFF252528)
        : const Color(0xFFECEEF2);
    final inputBg = isDark ? const Color(0xFF1E1E22) : const Color(0xFFF6F8FA);
    final headerBgColor = isDark
        ? const Color(0xFF1A1A1E)
        : (isRev ? const Color(0xFFF8F5FF) : const Color(0xFFE8F8F5));

    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final nikController = TextEditingController();
    final birthplaceController = TextEditingController();
    final dobController = TextEditingController();
    final phoneController = TextEditingController();
    final addressController = TextEditingController();
    String genderSelection = 'Laki-laki';
    String? uploadedAvatarUrl;
    bool isUploadingPhoto = false;

    final isMobile = MediaQuery.of(context).size.width < 600;

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.4),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return Dialog(
            insetPadding: EdgeInsets.symmetric(
              horizontal: isMobile
                  ? 12
                  : (MediaQuery.of(context).size.width - 650) / 2,
              vertical: 24,
            ),
            backgroundColor: Colors.transparent,
            child: Container(
              width: 650,
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
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // --- Dialog Header ---
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      color: headerBgColor,
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
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Registrasi Pasien Baru'.tr(state),
                                  style: GoogleFonts.outfit(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                    color: textColor,
                                  ),
                                ),
                                Text(
                                  'Daftarkan rekam medis pasien di bawah ini'
                                      .tr(state),
                                  style: GoogleFonts.outfit(
                                    fontSize: 10,
                                    color: subtitleColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () => Navigator.of(ctx).pop(),
                          ),
                        ],
                      ),
                    ),

                    // --- Scrollable Form Fields ---
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Photo upload placeholder
                            Center(
                              child: Stack(
                                children: [
                                  InkWell(
                                    onTap: isUploadingPhoto
                                        ? null
                                        : () async {
                                            try {
                                              final pickerResult =
                                                  await FilePicker.platform
                                                      .pickFiles(
                                                type: FileType.image,
                                                withData: true,
                                              );
                                              if (pickerResult != null &&
                                                  pickerResult.files.isNotEmpty) {
                                                setDialogState(() {
                                                  isUploadingPhoto = true;
                                                });
                                                final pickedFile =
                                                    pickerResult.files.first;
                                                Uint8List? bytes =
                                                    pickedFile.bytes;
                                                if (bytes == null &&
                                                    !kIsWeb &&
                                                    pickedFile.path != null) {
                                                  bytes = io.File(
                                                    pickedFile.path!,
                                                  ).readAsBytesSync();
                                                }
                                                if (bytes != null) {
                                                  final fileName = pickedFile.name;
                                                  final storagePath =
                                                      'avatars/patients/${DateTime.now().millisecondsSinceEpoch}_$fileName';
                                                  await SupabaseService.client.storage
                                                      .from('profiles')
                                                      .uploadBinary(storagePath, bytes);

                                                  final finalUrl = SupabaseService.client.storage
                                                      .from('profiles')
                                                      .getPublicUrl(storagePath);
                                                  
                                                  setDialogState(() {
                                                    uploadedAvatarUrl = finalUrl;
                                                  });
                                                }
                                              }
                                            } catch (e) {
                                              debugPrint('Error picking/uploading patient photo: $e');
                                            } finally {
                                              setDialogState(() {
                                                isUploadingPhoto = false;
                                              });
                                            }
                                          },
                                    borderRadius: BorderRadius.circular(40),
                                    child: Container(
                                      width: 80,
                                      height: 80,
                                      decoration: BoxDecoration(
                                        color: inputBg,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: borderColor,
                                          style: BorderStyle.solid,
                                        ),
                                      ),
                                      alignment: Alignment.center,
                                      child: isUploadingPhoto
                                          ? SizedBox(
                                              width: 24,
                                              height: 24,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: purple,
                                              ),
                                            )
                                          : uploadedAvatarUrl != null
                                              ? ClipOval(
                                                  child: Image.network(
                                                    uploadedAvatarUrl!,
                                                    width: 80,
                                                    height: 80,
                                                    fit: BoxFit.cover,
                                                  ),
                                                )
                                              : Column(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Icon(
                                                      Icons.add_a_photo_outlined,
                                                      size: 20,
                                                      color: subtitleColor,
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      'Unggah Foto'.tr(state),
                                                      style: GoogleFonts.outfit(
                                                        fontSize: 7.5,
                                                        fontWeight: FontWeight.bold,
                                                        color: subtitleColor,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                    ),
                                  ),
                                  if (uploadedAvatarUrl != null && !isUploadingPhoto)
                                    Positioned(
                                      right: 0,
                                      top: 0,
                                      child: GestureDetector(
                                        onTap: () {
                                          setDialogState(() {
                                            uploadedAvatarUrl = null;
                                          });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: const BoxDecoration(
                                            color: Colors.redAccent,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.close_rounded,
                                            size: 12,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Fields Grid layout
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _buildFormFieldLabel(
                                        'Nama Lengkap Pasien'.tr(state),
                                        textColor,
                                      ),
                                      _buildTextInput(
                                        nameController,
                                        'Masukkan nama...'.tr(state),
                                        Icons.person_outline,
                                        inputBg,
                                        borderColor,
                                        textColor,
                                        subtitleColor,
                                        validator: (v) => v!.isEmpty
                                            ? 'Nama wajib diisi'
                                            : null,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _buildFormFieldLabel(
                                        'Nomor Induk Kependudukan (NIK)'.tr(
                                          state,
                                        ),
                                        textColor,
                                      ),
                                      _buildTextInput(
                                        nikController,
                                        'Masukkan 16 digit NIK...'.tr(state),
                                        Icons.fingerprint_rounded,
                                        inputBg,
                                        borderColor,
                                        textColor,
                                        subtitleColor,
                                        keyboardType: TextInputType.number,
                                        validator: (v) => v!.length != 16
                                            ? 'NIK harus 16 digit'
                                            : null,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _buildFormFieldLabel(
                                        'Alamat Email'.tr(state),
                                        textColor,
                                      ),
                                      _buildTextInput(
                                        emailController,
                                        'contoh@email.com'.tr(state),
                                        Icons.mail_outline_rounded,
                                        inputBg,
                                        borderColor,
                                        textColor,
                                        subtitleColor,
                                        keyboardType:
                                            TextInputType.emailAddress,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _buildFormFieldLabel(
                                        'Kata Sandi Default'.tr(state),
                                        textColor,
                                      ),
                                      _buildTextInput(
                                        passwordController,
                                        'Buat sandi...'.tr(state),
                                        Icons.lock_outline_rounded,
                                        inputBg,
                                        borderColor,
                                        textColor,
                                        subtitleColor,
                                        obscureText: true,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _buildFormFieldLabel(
                                        'Tempat Lahir'.tr(state),
                                        textColor,
                                      ),
                                      _buildTextInput(
                                        birthplaceController,
                                        'Kota tempat lahir...'.tr(state),
                                        Icons.location_city_rounded,
                                        inputBg,
                                        borderColor,
                                        textColor,
                                        subtitleColor,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _buildFormFieldLabel(
                                        'Tanggal Lahir'.tr(state),
                                        textColor,
                                      ),
                                      _buildDateInput(
                                        ctx,
                                        dobController,
                                        'Pilih tanggal...'.tr(state),
                                        inputBg,
                                        borderColor,
                                        textColor,
                                        subtitleColor,
                                        setDialogState,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _buildFormFieldLabel(
                                        'Jenis Kelamin'.tr(state),
                                        textColor,
                                      ),
                                      Container(
                                        height: 44,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          color: inputBg,
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          border: Border.all(
                                            color: borderColor,
                                          ),
                                        ),
                                        child: DropdownButtonHideUnderline(
                                          child: DropdownButton<String>(
                                            value: genderSelection,
                                            dropdownColor: cardBg,
                                            icon: Icon(
                                              Icons.arrow_drop_down_rounded,
                                              color: subtitleColor,
                                            ),
                                            isExpanded: true,
                                            style: GoogleFonts.outfit(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: textColor,
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
                                                setDialogState(() {
                                                  genderSelection = val;
                                                });
                                              }
                                            },
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _buildFormFieldLabel(
                                        'No. Telepon Aktif'.tr(state),
                                        textColor,
                                      ),
                                      _buildTextInput(
                                        phoneController,
                                        '08xxxxxxxxxx'.tr(state),
                                        Icons.phone_android_rounded,
                                        inputBg,
                                        borderColor,
                                        textColor,
                                        subtitleColor,
                                        keyboardType: TextInputType.phone,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFormFieldLabel(
                                  'Alamat Lengkap Domisili'.tr(state),
                                  textColor,
                                ),
                                _buildTextInput(
                                  addressController,
                                  'Tulis nama jalan, kelurahan, kecamatan, kota...'
                                      .tr(state),
                                  Icons.home_outlined,
                                  inputBg,
                                  borderColor,
                                  textColor,
                                  subtitleColor,
                                  maxLines: 2,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    // --- Bottom Actions ---
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        border: Border(top: BorderSide(color: borderColor)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            onPressed: () => Navigator.of(ctx).pop(),
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
                              'Batal'.tr(state),
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: subtitleColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: () {
                              if (formKey.currentState!.validate()) {
                                // Add patient to riverpod state
                                final randomId =
                                    'PAS-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
                                final newPatient = PasienModel(
                                  id: randomId,
                                  nama: nameController.text,
                                  email: emailController.text.isEmpty
                                      ? '${nameController.text.toLowerCase().replaceAll(' ', '')}@gmail.com'
                                      : emailController.text,
                                  nik: nikController.text,
                                  tempatLahir: birthplaceController.text.isEmpty
                                      ? 'Bondowoso'
                                      : birthplaceController.text,
                                  tanggalLahir: dobController.text.isEmpty
                                      ? '26 Mei 2026'
                                      : dobController.text,
                                  jenisKelamin: genderSelection,
                                  telepon: phoneController.text.isEmpty
                                      ? '081234567890'
                                      : phoneController.text,
                                  alamat: addressController.text.isEmpty
                                      ? 'KABUPATEN BONDOWOSO'
                                      : addressController.text,
                                  umur: '24 th',
                                  avatarBg: genderSelection == 'Laki-laki'
                                      ? const Color(0xFF48C9B0)
                                      : const Color(0xFFEAB7EE),
                                  history: const [],
                                  avatarUrl: uploadedAvatarUrl,
                                );

                                ref
                                    .read(dokterPasienListProvider.notifier)
                                    .addPasien(newPatient);

                                Navigator.of(ctx).pop();

                                // Show success confirmation
                                _showSuccessSnackBar(
                                  context,
                                  'Pasien baru berhasil didaftarkan!',
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: purple,
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
                            child: Text(
                              'Daftarkan Pasien'.tr(state),
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
            ),
          );
        },
      ),
    );
  }

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
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
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
          firstDate: DateTime(1920),
          lastDate: DateTime.now(),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: ColorScheme.light(
                  primary: const Color(0xFFB577F2),
                  onPrimary: Colors.white,
                  onSurface: text,
                ),
              ),
              child: child!,
            );
          },
        );
        if (date != null) {
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
          setDialogState(() {
            controller.text =
                '${date.day} ${months[date.month - 1]} ${date.year}';
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
          validator: (v) => v!.isEmpty ? 'Tanggal lahir wajib diisi' : null,
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

  void _showDetailDialog(
    BuildContext context,
    PasienModel patient,
    Color cardBg,
    Color text,
    Color subtitle,
    Color border,
    Color colorTheme,
  ) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.4),
      builder: (dialogCtx) {
        int activeTab = 0; // 0: OVERVIEW, 1: MEDICAL HISTORY
        bool verified = patient.satusehatId != null;

        return StatefulBuilder(
          builder: (context, setModalState) {
            final initials = patient.nama.isNotEmpty
                ? patient.nama
                      .split(' ')
                      .map((e) => e[0])
                      .take(2)
                      .join('')
                      .toUpperCase()
                : 'P';

            String? avatarUrl = (patient.avatarUrl != null && patient.avatarUrl!.isNotEmpty)
                ? patient.avatarUrl
                : null;

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              backgroundColor: cardBg,
              clipBehavior: Clip.antiAlias,
              child: SizedBox(
                width: 520,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        SizedBox(
                          height: 140,
                          width: double.infinity,
                          child: avatarUrl != null
                              ? ImageFiltered(
                                  imageFilter: ImageFilter.blur(
                                    sigmaX: 12,
                                    sigmaY: 12,
                                  ),
                                  child: Image.network(
                                    avatarUrl,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : Container(color: patient.avatarBg),
                        ),
                        Container(
                          height: 140,
                          color: Colors.black.withOpacity(0.15),
                        ),
                        Positioned(
                          right: 16,
                          top: 16,
                          child: GestureDetector(
                            onTap: () => Navigator.of(dialogCtx).pop(),
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.4),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 24,
                          bottom: -32,
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: cardBg,
                              shape: BoxShape.circle,
                              border: Border.all(color: cardBg, width: 4),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: avatarUrl != null
                                  ? Image.network(
                                      avatarUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              Container(
                                                color: patient.avatarBg
                                                    .withOpacity(0.15),
                                                alignment: Alignment.center,
                                                child: Text(
                                                  initials,
                                                  style: GoogleFonts.outfit(
                                                    fontSize: 24,
                                                    fontWeight: FontWeight.w900,
                                                    color: patient.avatarBg,
                                                  ),
                                                ),
                                              ),
                                    )
                                  : Container(
                                      color: patient.avatarBg.withOpacity(0.15),
                                      alignment: Alignment.center,
                                      child: Text(
                                        initials,
                                        style: GoogleFonts.outfit(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w900,
                                          color: patient.avatarBg,
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 36),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  patient.nama,
                                  style: GoogleFonts.outfit(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: text,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: colorTheme.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 5,
                                      height: 5,
                                      decoration: BoxDecoration(
                                        color: colorTheme,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'PATIENT',
                                      style: GoogleFonts.outfit(
                                        fontSize: 8,
                                        fontWeight: FontWeight.w900,
                                        color: colorTheme,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'ID: ${patient.nik}',
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: subtitle.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => setModalState(() => activeTab = 0),
                            child: Container(
                              padding: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: activeTab == 0
                                        ? colorTheme
                                        : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                              ),
                              child: Text(
                                'OVERVIEW',
                                style: GoogleFonts.outfit(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: activeTab == 0
                                      ? colorTheme
                                      : subtitle.withOpacity(0.5),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 20),
                          GestureDetector(
                            onTap: () => setModalState(() => activeTab = 1),
                            child: Container(
                              padding: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: activeTab == 1
                                        ? colorTheme
                                        : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                              ),
                              child: Text(
                                'MEDICAL HISTORY',
                                style: GoogleFonts.outfit(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: activeTab == 1
                                      ? colorTheme
                                      : subtitle.withOpacity(0.5),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, indent: 24, endIndent: 24),
                    Container(
                      constraints: const BoxConstraints(
                        minHeight: 220,
                        maxHeight: 300,
                      ),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: activeTab == 0
                            ? _buildOverviewTabContent(
                                patient,
                                text,
                                subtitle,
                                border,
                                colorTheme,
                                verified,
                                setModalState,
                                context,
                              )
                            : _buildHistoryTabContent(
                                patient,
                                text,
                                subtitle,
                                border,
                                colorTheme,
                              ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        border: Border(top: BorderSide(color: border)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton.icon(
                            onPressed: () {
                              _showDeleteConfirmDialog(
                                context,
                                patient,
                                dialogCtx,
                              );
                            },
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              color: Colors.redAccent,
                              size: 16,
                            ),
                            label: Text(
                              'Hapus Rekam Medis',
                              style: GoogleFonts.outfit(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: Colors.redAccent,
                              ),
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.redAccent,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                            ),
                          ),
                          OutlinedButton(
                            onPressed: () => Navigator.of(dialogCtx).pop(),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: border),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 14,
                              ),
                            ),
                            child: Text(
                              'Close',
                              style: GoogleFonts.outfit(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: subtitle,
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
        );
      },
    );
  }

  Widget _buildOverviewTabContent(
    PasienModel patient,
    Color text,
    Color subtitle,
    Color border,
    Color colorTheme,
    bool verified,
    StateSetter setModalState,
    BuildContext context,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailItemCol(
                    'EMAIL ADDRESS',
                    patient.email,
                    text,
                    subtitle,
                  ),
                  const SizedBox(height: 12),
                  _buildDetailItemCol('PHONE', patient.telepon, text, subtitle),
                  const SizedBox(height: 12),
                  _buildDetailItemCol(
                    'GENDER',
                    patient.jenisKelamin,
                    text,
                    subtitle,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailItemCol(
                    'ADDRESS',
                    patient.alamat,
                    text,
                    subtitle,
                    isMultiLine: true,
                  ),
                  const SizedBox(height: 12),
                  _buildDetailItemCol(
                    'DATE OF BIRTH',
                    '${patient.tempatLahir}, ${patient.tanggalLahir} (${patient.umur})',
                    text,
                    subtitle,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: verified
                ? const Color(0xFF27AE60).withOpacity(0.06)
                : Colors.amber.withOpacity(0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: verified
                  ? const Color(0xFF27AE60).withOpacity(0.2)
                  : Colors.amber.withOpacity(0.2),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: verified
                      ? const Color(0xFF27AE60).withOpacity(0.12)
                      : Colors.amber.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  verified
                      ? Icons.check_circle_outline_rounded
                      : Icons.info_outline_rounded,
                  color: verified ? const Color(0xFF27AE60) : Colors.amber[800],
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      verified
                          ? 'Terdaftar di SATUSEHAT'
                          : 'SATUSEHAT Integration',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: verified
                            ? const Color(0xFF27AE60)
                            : Colors.amber[900],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      verified
                          ? (patient.satusehatId ?? '')
                          : 'NIK Pasien belum terverifikasi sistem pusat',
                      style: GoogleFonts.outfit(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color:
                            (verified
                                    ? const Color(0xFF27AE60)
                                    : Colors.amber[900])!
                                .withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
              if (!verified)
                ElevatedButton(
                  onPressed: () {
                    setModalState(() {
                      _showSuccessSnackBar(
                        context,
                        'NIK Pasien berhasil terverifikasi di SATUSEHAT!',
                      );
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.amber[900],
                    elevation: 0,
                    side: BorderSide(color: Colors.amber.withOpacity(0.3)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_rounded, size: 10),
                      const SizedBox(width: 4),
                      Text(
                        'Verifikasi',
                        style: GoogleFonts.outfit(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
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

  Widget _buildDetailItemCol(
    String label,
    String value,
    Color textCol,
    Color subtitleCol, {
    bool isMultiLine = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.outfit(
            fontSize: 7.5,
            fontWeight: FontWeight.w900,
            color: subtitleCol.withOpacity(0.6),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: textCol,
          ),
          maxLines: isMultiLine ? 4 : 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Future<Map<String, dynamic>> _fetchEncounterDetails(String queueId) async {
    final db = SupabaseService();
    // 1. Fetch queue to get doctorId & date_queue
    final queue = await SupabaseService.client
        .from('v_queues')
        .select('*')
        .eq('id', queueId)
        .maybeSingle();

    final doctorId = queue?['id_doctor'] as String?;
    String doctorName = 'dr. Agoes Soetanto';
    if (doctorId != null && doctorId.isNotEmpty) {
      final docUser = await db.fetchUserById(doctorId);
      if (docUser != null) {
        doctorName = docUser['name'] ?? doctorName;
      }
    }

    // 2. Fetch clinical encounter
    final ce = await SupabaseService.client
        .schema('private_doctor')
        .from('clinical_encounters')
        .select('*')
        .eq('id_queue', queueId)
        .maybeSingle();

    if (ce == null) {
      return {
        'doctorName': doctorName,
        'date': queue?['date_queue'] ?? '-',
        'encounter': null,
      };
    }

    final encounterId = ce['id'] as String;

    // 3. Fetch anamnesis
    final anamnesis = await SupabaseService.client
        .schema('private_doctor')
        .from('anamnesis_ecounter')
        .select('*')
        .eq('id_clinical_ecounter', encounterId)
        .maybeSingle();

    // 4. Fetch vitals
    final vitals = await SupabaseService.client
        .schema('private_doctor')
        .from('vital_signs')
        .select('*')
        .eq('id_clinical_ecounter', encounterId)
        .maybeSingle();

    // 5. Fetch diagnoses
    final diagnoses = await SupabaseService.client
        .schema('private_doctor')
        .from('icdx_ecounter')
        .select('*')
        .eq('id_clinical_ecounters', encounterId);

    // 6. Fetch medicines
    final List<Map<String, dynamic>> medicinesList = [];
    final medicinesRes = await SupabaseService.client
        .schema('private_doctor')
        .from('medicine_ecounter')
        .select('quantity, id_detail_medicine')
        .eq('id_clinical_encounters', encounterId);

    for (final medRow in medicinesRes) {
      final qty = double.tryParse(medRow['quantity']?.toString() ?? '0') ?? 0.0;
      final detailMedId = medRow['id_detail_medicine'];
      if (detailMedId != null) {
        final dmRes = await SupabaseService.client
            .schema('private_doctor')
            .from('detail_medicine')
            .select('id_medicine')
            .eq('id', detailMedId)
            .maybeSingle();

        if (dmRes != null) {
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
          medicinesList.add({
            'name': medicineName,
            'quantity': qty,
          });
        }
      }
    }

    // 7. Fetch manual prescriptions
    try {
      final epRes = await SupabaseService.client
          .schema('private_doctor')
          .from('electronic_prescriptions')
          .select('*, electronic_prescription_items(*)')
          .eq('id_clinical_encounter', encounterId)
          .maybeSingle();

      if (epRes != null) {
        final items = epRes['electronic_prescription_items'] as List<dynamic>?;
        if (items != null) {
          for (final item in items) {
            if (item['id_catalog_item'] == null) {
              final qty = double.tryParse(item['quantity']?.toString() ?? '1') ?? 1.0;
              medicinesList.add({
                'name': item['medicine_name']?.toString() ?? 'Obat Resep',
                'quantity': qty,
              });
            }
          }
        }
      }
    } catch (_) {}

    return {
      'doctorName': doctorName,
      'date': queue?['date_queue'] ?? '-',
      'encounter': ce,
      'anamnesis': anamnesis,
      'vitals': vitals,
      'diagnoses': diagnoses,
      'medicines': medicinesList,
    };
  }

  void _showEncounterDetailDialog(BuildContext context, String queueId, String formattedDate, PasienModel patient, bool isDark) {
    final themeAccent = ref.read(landingPageProvider.notifier).getPrimaryColor();
    final cardBg = isDark ? const Color(0xFF161619) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1B0C3C);
    final subtitleColor = isDark ? Colors.grey[400]! : const Color(0xFF6F6A8A);
    final borderColor = isDark ? const Color(0xFF252528) : const Color(0xFFECEEF2);
    final inputBg = isDark ? const Color(0xFF1E1E22) : const Color(0xFFF6F8FA);

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.4),
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          backgroundColor: cardBg,
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            width: 480,
            child: FutureBuilder<Map<String, dynamic>>(
              future: _fetchEncounterDetails(queueId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Container(
                    padding: const EdgeInsets.all(24),
                    child: SkeletonScope(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SkeletonBox(height: 14, width: 100),
                          const SizedBox(height: 8),
                          const SkeletonBox(height: 50, width: double.infinity),
                          const SizedBox(height: 20),
                          const SkeletonBox(height: 14, width: 140),
                          const SizedBox(height: 8),
                          const SkeletonBox(height: 60, width: double.infinity),
                          const SizedBox(height: 20),
                          const SkeletonBox(height: 14, width: 120),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(child: const SkeletonBox(height: 30)),
                              const SizedBox(width: 8),
                              Expanded(child: const SkeletonBox(height: 30)),
                              const SizedBox(width: 8),
                              Expanded(child: const SkeletonBox(height: 30)),
                            ],
                          ),
                          const SizedBox(height: 20),
                          const SkeletonBox(height: 14, width: 80),
                          const SizedBox(height: 8),
                          const SkeletonBox(height: 40, width: double.infinity),
                        ],
                      ),
                    ),
                  );
                }

                if (snapshot.hasError || !snapshot.hasData) {
                  return Container(
                    height: 200,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Gagal memuat detail pemeriksaan.',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.redAccent,
                      ),
                    ),
                  );
                }

                final data = snapshot.data!;
                final ce = data['encounter'];
                final doctorName = data['doctorName'] as String;

                if (ce == null) {
                  return Container(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Pemeriksaan Rutin',
                          style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Pemeriksaan pada tanggal $formattedDate oleh $doctorName tidak memiliki catatan EMR terperinci.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(fontSize: 12, color: subtitleColor),
                        ),
                        const SizedBox(height: 16),
                        CustomButton(
                          text: 'Tutup',
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  );
                }

                final anamnesis = data['anamnesis'];
                final vitals = data['vitals'];
                final diagnoses = data['diagnoses'] as List<dynamic>;
                final medicines = data['medicines'] as List<dynamic>;
                final isRujukan = ce['is_rujukan'] == true;

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      color: isDark ? const Color(0xFF1A1A1E) : const Color(0xFFF8F5FF),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: themeAccent.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.assignment_turned_in_rounded,
                              color: themeAccent,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Hasil Pemeriksaan Medis',
                                  style: GoogleFonts.outfit(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    color: textColor,
                                  ),
                                ),
                                Text(
                                  '$formattedDate • Pasien: ${patient.nama}',
                                  style: GoogleFonts.outfit(
                                    fontSize: 10,
                                    color: subtitleColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () => Navigator.of(ctx).pop(),
                          ),
                        ],
                      ),
                    ),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildDetailSectionTitle('Dokter Pemeriksa', textColor),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: inputBg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: borderColor),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: themeAccent.withOpacity(0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(Icons.person_rounded, color: themeAccent, size: 16),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          doctorName,
                                          style: GoogleFonts.outfit(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: textColor,
                                          ),
                                        ),
                                        Text(
                                          'Dokter Pemeriksa',
                                          style: GoogleFonts.outfit(
                                            fontSize: 9,
                                            color: subtitleColor.withOpacity(0.8),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (anamnesis != null) ...[
                              _buildDetailSectionTitle('Keluhan & Anamnesis', textColor),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: inputBg,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: borderColor),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (anamnesis['main_complaint'] != null && anamnesis['main_complaint'].toString().isNotEmpty) ...[
                                      Text(
                                        'Keluhan Utama:',
                                        style: GoogleFonts.outfit(fontSize: 9.5, fontWeight: FontWeight.bold, color: subtitleColor),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        anamnesis['main_complaint'],
                                        style: GoogleFonts.outfit(fontSize: 11.5, color: textColor),
                                      ),
                                      const SizedBox(height: 10),
                                    ],
                                    if (anamnesis['anamnesis'] != null && anamnesis['anamnesis'].toString().isNotEmpty) ...[
                                      Text(
                                        'Catatan Anamnesis:',
                                        style: GoogleFonts.outfit(fontSize: 9.5, fontWeight: FontWeight.bold, color: subtitleColor),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        anamnesis['anamnesis'],
                                        style: GoogleFonts.outfit(fontSize: 11.5, color: textColor),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                            if (vitals != null) ...[
                              _buildDetailSectionTitle('Tanda-tanda Vital', textColor),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  if (vitals['blood_pressure'] != null && vitals['blood_pressure'].toString().isNotEmpty)
                                    _buildVitalChip('Tensi', '${vitals['blood_pressure']} mmHg', Icons.speed_rounded, themeAccent, isDark),
                                  if (vitals['body_temperature'] != null && vitals['body_temperature'].toString().isNotEmpty)
                                    _buildVitalChip('Suhu', '${vitals['body_temperature']} °C', Icons.thermostat_rounded, themeAccent, isDark),
                                  if (vitals['heart_rate'] != null && vitals['heart_rate'].toString().isNotEmpty)
                                    _buildVitalChip('Nadi', '${vitals['heart_rate']} bpm', Icons.favorite_rounded, themeAccent, isDark),
                                  if (vitals['oxygen_saturation'] != null && vitals['oxygen_saturation'].toString().isNotEmpty)
                                    _buildVitalChip('SpO2', '${vitals['oxygen_saturation']} %', Icons.bubble_chart_rounded, themeAccent, isDark),
                                  if (vitals['body_weight'] != null && vitals['body_weight'].toString().isNotEmpty)
                                    _buildVitalChip('Berat', '${vitals['body_weight']} kg', Icons.monitor_weight_rounded, themeAccent, isDark),
                                  if (vitals['body_height'] != null && vitals['body_height'].toString().isNotEmpty)
                                    _buildVitalChip('Tinggi', '${vitals['body_height']} cm', Icons.height_rounded, themeAccent, isDark),
                                ],
                              ),
                              const SizedBox(height: 16),
                            ],
                            if (diagnoses.isNotEmpty) ...[
                              _buildDetailSectionTitle('Diagnosis (ICD-10)', textColor),
                              Column(
                                children: diagnoses.map((diag) {
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 6),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF1E1E22) : const Color(0xFFF9F9FB),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: borderColor),
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.redAccent.withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            diag['icdx_code'] ?? '',
                                            style: GoogleFonts.outfit(
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.redAccent,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            diag['description'] ?? '',
                                            style: GoogleFonts.outfit(fontSize: 11, color: textColor, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 16),
                            ],
                            if (medicines.isNotEmpty) ...[
                              _buildDetailSectionTitle('Resep Obat', textColor),
                              Column(
                                children: medicines.map((med) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: Row(
                                      children: [
                                        Icon(Icons.medication_rounded, size: 14, color: themeAccent),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            med['name'],
                                            style: GoogleFonts.outfit(fontSize: 11.5, color: textColor, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        Text(
                                          '${med['quantity'].toString().replaceAll('.0', '')} unit',
                                          style: GoogleFonts.outfit(fontSize: 11, color: subtitleColor, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 16),
                            ],
                            if (isRujukan) ...[
                              _buildDetailSectionTitle('Surat Rujukan', textColor),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.blueAccent.withOpacity(0.06),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.blueAccent.withOpacity(0.15)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.launch_rounded, size: 14, color: Colors.blueAccent),
                                        const SizedBox(width: 8),
                                        Text(
                                          'RUJUKAN OUT PATIENT',
                                          style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'RS Rujukan: ${ce['rujukan_rumah_sakit'] ?? '-'}',
                                      style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: textColor),
                                    ),
                                    Text(
                                      'Poli Rujukan: ${ce['rujukan_poli'] ?? '-'}',
                                      style: GoogleFonts.outfit(fontSize: 10, color: subtitleColor, fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      'Nomor Rujukan: ${ce['rujukan_nomor'] ?? '-'}',
                                      style: GoogleFonts.outfit(fontSize: 10, color: subtitleColor, fontWeight: FontWeight.bold),
                                    ),
                                    if (ce['rujukan_catatan'] != null && ce['rujukan_catatan'].toString().isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Text(
                                        'Catatan Rujukan: ${ce['rujukan_catatan']}',
                                        style: GoogleFonts.outfit(fontSize: 10.5, fontStyle: FontStyle.italic, color: textColor),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailSectionTitle(String title, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 2),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.outfit(
          fontSize: 8.5,
          fontWeight: FontWeight.w900,
          color: textColor.withOpacity(0.5),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildVitalChip(String label, String value, IconData icon, Color accent, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E22) : const Color(0xFFF5F6F8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? const Color(0xFF252528) : const Color(0xFFECEEF2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: accent),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: GoogleFonts.outfit(fontSize: 10, color: isDark ? Colors.grey[400] : const Color(0xFF6F6A8A)),
          ),
          Text(
            value,
            style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF1B0C3C)),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTabContent(
    PasienModel patient,
    Color text,
    Color subtitle,
    Color border,
    Color colorTheme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'CHECKUP HISTORY',
              style: GoogleFonts.outfit(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: text,
                letterSpacing: 0.5,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: colorTheme.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${patient.history.length} Records',
                style: GoogleFonts.outfit(
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                  color: colorTheme,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (patient.history.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Text(
                'Belum ada riwayat pemeriksaan medis.',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  color: subtitle,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: patient.history.length,
            itemBuilder: (context, index) {
              final historyItem = patient.history[index];
              final parts = historyItem.split('|');
              final queueId = parts[0];
              final formattedDate = parts.length > 1 ? parts[1] : parts[0];

              final isDark = ref.read(landingPageProvider).appearance == 'dark';

              return HistoryItemCard(
                formattedDate: formattedDate,
                queueId: queueId,
                border: border,
                text: text,
                subtitle: subtitle,
                colorTheme: colorTheme,
                isDark: isDark,
                onTap: () => _showEncounterDetailDialog(context, queueId, formattedDate, patient, isDark),
              );
            },
          ),
      ],
    );
  }

  void _showDeleteConfirmDialog(
    BuildContext context,
    PasienModel patient,
    BuildContext dialogCtx,
  ) {
    final state = ref.read(landingPageProvider);
    final isDark = state.appearance == 'dark';
    final cardBg = isDark ? const Color(0xFF161619) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1B0C3C);
    final subtitleColor = isDark ? Colors.grey[400]! : const Color(0xFF6F6A8A);

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.4),
      builder: (ctx) => AlertDialog(
        backgroundColor: cardBg,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: Colors.redAccent,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Hapus Rekam Medis?',
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: textColor,
              ),
            ),
          ],
        ),
        content: Text(
          'Apakah Anda yakin ingin menghapus seluruh berkas rekam medis dan data pasien ${patient.nama}? Tindakan ini tidak dapat dibatalkan.',
          style: GoogleFonts.outfit(
            fontSize: 11,
            color: subtitleColor,
            fontWeight: FontWeight.w500,
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
            onPressed: () {
              ref
                  .read(dokterPasienListProvider.notifier)
                  .deletePasien(patient.id);
              Navigator.of(ctx).pop();
              Navigator.of(dialogCtx).pop();
              _showSuccessSnackBar(
                context,
                'Rekam medis pasien ${patient.nama} berhasil dihapus.',
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Hapus',
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

  void _showPemeriksaanDialog(
    BuildContext context,
    PasienModel patient,
    Color cardBg,
    Color text,
    Color subtitle,
    Color border,
    Color themeColor,
  ) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.3),
      builder: (ctx) => AlertDialog(
        backgroundColor: cardBg,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Mulai Pemeriksaan Pasien',
          style: GoogleFonts.outfit(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: text,
          ),
        ),
        content: Text(
          'Apakah Anda ingin memulai pemeriksaan RME (Rekam Medis Elektronik) aktif untuk pasien ${patient.nama} (${patient.id})?',
          style: GoogleFonts.outfit(
            fontSize: 12,
            color: subtitle,
            fontWeight: FontWeight.w500,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Batal',
              style: GoogleFonts.outfit(
                fontSize: 11,
                color: subtitle,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _showSuccessSnackBar(
                context,
                'Sesi pemeriksaan RME ${patient.nama} dimulai.',
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: themeColor,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Ya, Mulai',
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
}

class HeartbeatPainter extends CustomPainter {
  final Color color;

  HeartbeatPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    final h = size.height;
    final w = size.width;

    path.moveTo(0, h * 0.5);
    path.lineTo(w * 0.3, h * 0.5);
    path.lineTo(w * 0.35, h * 0.3);
    path.lineTo(w * 0.4, h * 0.7);
    path.lineTo(w * 0.45, h * 0.1);
    path.lineTo(w * 0.5, h * 0.85);
    path.lineTo(w * 0.55, h * 0.4);
    path.lineTo(w * 0.6, h * 0.5);
    path.lineTo(w * 1.0, h * 0.5);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class PasienCard extends StatefulWidget {
  final PasienModel patient;
  final Color cardBg;
  final Color border;
  final Color text;
  final Color subtitle;
  final Color accent;
  final Color purple;
  final VoidCallback onTap;

  const PasienCard({
    super.key,
    required this.patient,
    required this.cardBg,
    required this.border,
    required this.text,
    required this.subtitle,
    required this.accent,
    required this.purple,
    required this.onTap,
  });

  @override
  State<PasienCard> createState() => _PasienCardState();
}

class _PasienCardState extends State<PasienCard> {
  int _activeTab = 0; // 0: HISTORY, 1: INFORMATION

  @override
  Widget build(BuildContext context) {
    final initials = widget.patient.nama.isNotEmpty
        ? widget.patient.nama
              .split(' ')
              .map((e) => e[0])
              .take(2)
              .join('')
              .toUpperCase()
        : 'P';

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          decoration: BoxDecoration(
            color: widget.cardBg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: widget.border, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      widget.patient.avatarBg.withOpacity(0.25),
                      widget.patient.avatarBg.withOpacity(0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: 16,
                      bottom: -24,
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: widget.cardBg,
                          shape: BoxShape.circle,
                          border: Border.all(color: widget.cardBg, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: _buildAvatarWidget(widget.patient, initials),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 16,
                      top: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: widget.accent.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                color: widget.accent,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'PATIENT',
                              style: GoogleFonts.outfit(
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                                color: widget.accent,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.patient.nama,
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: widget.text,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'ID: ${widget.patient.nik}',
                      style: GoogleFonts.outfit(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: widget.subtitle.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    _buildTabItem(0, 'HISTORY'),
                    const SizedBox(width: 16),
                    _buildTabItem(1, 'INFORMATION'),
                  ],
                ),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _activeTab == 0
                      ? _buildHistoryTab()
                      : _buildInformationTab(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarWidget(PasienModel patient, String initials) {
    final url = (patient.avatarUrl != null && patient.avatarUrl!.isNotEmpty)
        ? patient.avatarUrl
        : null;

    if (url != null && url.isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            _buildInitialsAvatar(initials),
      );
    }
    return _buildInitialsAvatar(initials);
  }

  Widget _buildInitialsAvatar(String initials) {
    return Container(
      color: widget.patient.avatarBg.withOpacity(0.15),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: GoogleFonts.outfit(
          fontSize: 16,
          fontWeight: FontWeight.w900,
          color: widget.patient.avatarBg,
        ),
      ),
    );
  }

  Widget _buildTabItem(int index, String label) {
    final isActive = _activeTab == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _activeTab = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isActive ? widget.accent : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 9,
            fontWeight: FontWeight.w900,
            color: isActive ? widget.accent : widget.subtitle.withOpacity(0.6),
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryTab() {
    if (widget.patient.history.isEmpty) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CustomPaint(
            size: const Size(120, 40),
            painter: HeartbeatPainter(color: widget.subtitle.withOpacity(0.2)),
          ),
          const SizedBox(height: 8),
          Text(
            'NO HISTORY',
            style: GoogleFonts.outfit(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              color: widget.subtitle.withOpacity(0.4),
              letterSpacing: 0.5,
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: widget.patient.history.take(3).length,
      itemBuilder: (context, idx) {
        final historyItem = widget.patient.history[idx];
        final parts = historyItem.split('|');
        final date = parts.length > 1 ? parts[1] : parts[0];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: widget.subtitle.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                date,
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: widget.subtitle,
                ),
              ),
              const Spacer(),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: widget.accent,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInformationTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoRow(Icons.phone_android_rounded, widget.patient.telepon),
        const SizedBox(height: 8),
        _buildInfoRow(Icons.mail_outline_rounded, widget.patient.email),
        const SizedBox(height: 8),
        Expanded(
          child: _buildInfoRow(
            Icons.location_on_outlined,
            widget.patient.alamat,
            maxLines: 2,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String value, {int maxLines = 1}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 12, color: widget.subtitle.withOpacity(0.6)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: widget.text.withOpacity(0.8),
            ),
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class HistoryItemCard extends StatefulWidget {
  final String formattedDate;
  final String queueId;
  final Color border;
  final Color text;
  final Color subtitle;
  final Color colorTheme;
  final bool isDark;
  final VoidCallback onTap;

  const HistoryItemCard({
    super.key,
    required this.formattedDate,
    required this.queueId,
    required this.border,
    required this.text,
    required this.subtitle,
    required this.colorTheme,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<HistoryItemCard> createState() => _HistoryItemCardState();
}

class _HistoryItemCardState extends State<HistoryItemCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final translationOffset = _isHovered ? const Offset(-2, -2) : Offset.zero;
    final hoverShadow = _isHovered
        ? [
            BoxShadow(
              color: widget.colorTheme.withOpacity(0.15),
              blurRadius: 8,
              offset: const Offset(2, 4),
            )
          ]
        : <BoxShadow>[];

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(
          translationOffset.dx,
          translationOffset.dy,
          0,
        ),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: widget.isDark ? const Color(0xFF1E1E22) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isHovered ? widget.colorTheme : widget.border,
            width: _isHovered ? 1.5 : 1.0,
          ),
          boxShadow: hoverShadow,
        ),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: widget.colorTheme.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.calendar_month_rounded,
                    color: widget.colorTheme,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.formattedDate,
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: widget.text,
                        ),
                      ),
                      Text(
                        'KUNJUNGAN KLINIK',
                        style: GoogleFonts.outfit(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color: widget.subtitle.withOpacity(0.5),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF27AE60).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'DETAIL',
                        style: GoogleFonts.outfit(
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF27AE60),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 8,
                        color: Color(0xFF27AE60),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
