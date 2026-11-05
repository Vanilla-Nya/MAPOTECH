import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapotech/shared/widgets/skeleton_loading.dart';
import 'package:mapotech/features/landing/landing_page_data.dart';
import 'package:mapotech/shared/widgets/profile_widgets.dart';
import 'package:mapotech/shared/supabase_service.dart';

/// Profil Pasien — dedicated profile page for the masyarakat/pasien role.
class PasienProfile extends ConsumerStatefulWidget {
  const PasienProfile({super.key});

  @override
  ConsumerState<PasienProfile> createState() => _PasienProfileState();
}

class _PasienProfileState extends ConsumerState<PasienProfile> {
  final SupabaseService _db = SupabaseService();
  bool _isLoading = true;
  bool _isSaving = false;
  int _activeTab =
      0; // 0: Profil & Identitas Pasien, 1: Informasi Keluarga (KK)

  // Patient detail from database (bpjs/qr_token/no_kk/accept_kk/is_kepala_keluarga)
  Map<String, dynamic>? _patientDetail;
  bool _isKepalaKeluarga = false;

  // Controllers for editing
  late TextEditingController _nameController;
  late TextEditingController _nikController;
  late TextEditingController _kkController;
  late TextEditingController _phoneController;
  late TextEditingController _birthDateController;
  late TextEditingController _addressDetailController;

  String _gender = 'male';

  // Family Members Dataset loaded live from Supabase
  List<Map<String, dynamic>> _familyMembers = [];

  @override
  void initState() {
    super.initState();
    final user = ref.read(landingPageProvider).loggedInUser;

    _nameController = TextEditingController(text: user?['name'] ?? 'Alvin');
    _nikController = TextEditingController(
      text: user?['nik'] ?? '3511081208000003',
    );
    _kkController = TextEditingController(
      text: user?['no_kk'] ?? '3511081208009999',
    );
    _phoneController = TextEditingController(
      text: user?['phone_number'] ?? '08XXXXXXXXXX',
    );
    _birthDateController = TextEditingController(
      text: user?['birth_date'] ?? '2000-12-08',
    );
    _addressDetailController = TextEditingController(
      text:
          user?['address'] ??
          'Kel. KEJAYAN, Kec. PUJER, KABUPATEN BONDOWOSO, Prov. JAWA TIMUR',
    );
    _gender = user?['gender'] ?? 'male';

    _loadPatientDetails();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nikController.dispose();
    _kkController.dispose();
    _phoneController.dispose();
    _birthDateController.dispose();
    _addressDetailController.dispose();
    super.dispose();
  }

  Future<void> _loadPatientDetails() async {
    final user = ref.read(landingPageProvider).loggedInUser;
    if (user == null || user['email'] == null) {
      setState(() => _isLoading = false);
      return;
    }
    setState(() => _isLoading = true);
    try {
      final profile = await _db.fetchPatientProfileByEmail(user['email']);
      if (profile != null) {
        // Sync app state
        ref.read(landingPageProvider.notifier).updateUser(profile);

        final syncedUser = ref.read(landingPageProvider).loggedInUser;
        _nameController.text = syncedUser?['name'] ?? '';
        _nikController.text = syncedUser?['nik'] ?? '';
        _phoneController.text = syncedUser?['phone_number'] ?? '';
        _birthDateController.text = syncedUser?['birth_date'] ?? '';
        _addressDetailController.text = syncedUser?['address'] ?? '';
        _gender = syncedUser?['gender'] ?? 'male';

        final detailRaw = profile['patient_details'];
        _patientDetail = detailRaw is Map
            ? Map<String, dynamic>.from(detailRaw)
            : null;

        _isKepalaKeluarga = _patientDetail?['is_kepala_keluarga'] == true;

        if (_patientDetail?['no_kk'] != null &&
            _patientDetail!['no_kk'].toString().isNotEmpty) {
          _kkController.text = _patientDetail!['no_kk'].toString();
        }

        // Fetch real family members from database
        if (syncedUser?['id'] != null) {
          final familyData = await _db.fetchFamilyMembers(
            syncedUser!['id'].toString(),
          );
          _familyMembers = familyData;
        }

        setState(() => _isLoading = false);
      } else {
        setState(() => _isLoading = false);
      }
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleKepalaKeluargaStatus(bool val) async {
    final user = ref.read(landingPageProvider).loggedInUser;
    if (user == null || user['id'] == null) return;
    final userId = user['id'].toString();

    if (val) {
      // Confirm turning ON Kepala Keluarga status
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              const Icon(
                Icons.family_restroom_rounded,
                color: Color(0xFF27AE60),
              ),
              const SizedBox(width: 10),
              Text(
                'Daftar Sebagai Kepala Keluarga',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Text(
            'Apakah Anda yakin ingin mendaftar sebagai Kepala Keluarga? Setelah diaktifkan, Anda dapat menentukan dan mengelola Nomor KK untuk seluruh anggota keluarga Anda.',
            style: GoogleFonts.outfit(fontSize: 12, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                'Batal',
                style: GoogleFonts.outfit(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF27AE60),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(
                'Ya, Saya Kepala Keluarga',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );

      if (confirm == true) {
        await _db.updateKepalaKeluargaStatus(
          userId,
          true,
          noKk: _kkController.text.trim(),
        );
        setState(() {
          _isKepalaKeluarga = true;
          _patientDetail ??= {};
          _patientDetail!['is_kepala_keluarga'] = true;
          _patientDetail!['accept_kk'] = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Status Kepala Keluarga diaktifkan! Silakan masukkan Nomor KK dan tambah anggota keluarga.',
            ),
            backgroundColor: Color(0xFF27AE60),
          ),
        );
      }
    } else {
      // Warning dialog when turning OFF Kepala Keluarga status (Disbanding KK)
      final confirmDisband = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
              const SizedBox(width: 10),
              Text(
                'Peringatan Pembubaran KK (Disband)',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Text(
            'Apakah Anda yakin ingin menonaktifkan status Kepala Keluarga?\n\nTindakan ini akan MEMBUBARKAN (Disband) grup KK ini dan melepaskan semua anggota keluarga yang terhubung dari database!',
            style: GoogleFonts.outfit(
              fontSize: 12,
              height: 1.5,
              color: Colors.red[900],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(
                'Batal',
                style: GoogleFonts.outfit(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(
                'Ya, Bubarkan KK',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );

      if (confirmDisband == true) {
        await _db.disbandKkGroup(userId);
        setState(() {
          _isKepalaKeluarga = false;
          _familyMembers = [];
          _patientDetail ??= {};
          _patientDetail!['is_kepala_keluarga'] = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Grup Kartu Keluarga (KK) telah dibubarkan.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _saveKkNumberOnly() async {
    final user = ref.read(landingPageProvider).loggedInUser;
    if (user == null || user['id'] == null) return;

    try {
      await _db.updatePatientProfile(
        user['id'].toString(),
        {},
        patientDetailData: {
          'no_kk': _kkController.text.trim(),
          'is_kepala_keluarga': _isKepalaKeluarga,
        },
      );
      setState(() {
        _patientDetail ??= {};
        _patientDetail!['no_kk'] = _kkController.text.trim();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Nomor KK (${_kkController.text}) berhasil disimpan ke Supabase!',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          backgroundColor: const Color(0xFF27AE60),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menyimpan No. KK: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Future<void> _saveProfileChanges() async {
    final user = ref.read(landingPageProvider).loggedInUser;
    if (user == null) return;

    final nikVal = _nikController.text.trim();
    if (nikVal.isNotEmpty && (nikVal.length != 16 || !RegExp(r'^\d{16}$').hasMatch(nikVal))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('NIK harus 16 digit angka numerik!'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final phoneVal = _phoneController.text.trim();
    if (phoneVal.isNotEmpty && (phoneVal.length < 11 || phoneVal.length > 13 || !RegExp(r'^\d{11,13}$').hasMatch(phoneVal))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nomor telepon harus angka numerik antara 11 - 13 digit!'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    final updatedData = {
      'name': _nameController.text.trim(),
      'nik': _nikController.text.trim(),
      'phone_number': _phoneController.text.trim(),
      'birth_date': _birthDateController.text.trim(),
      'address': _addressDetailController.text.trim(),
      'gender': _gender,
    };

    final patientDetailData = {
      'no_kk': _kkController.text.trim(),
      'is_kepala_keluarga': _isKepalaKeluarga,
    };

    try {
      await _db.updatePatientProfile(
        user['id'],
        updatedData,
        patientDetailData: patientDetailData,
      );

      // Update local state
      ref.read(landingPageProvider.notifier).updateUser(updatedData);
      setState(() {
        _patientDetail ??= {};
        _patientDetail!['no_kk'] = _kkController.text.trim();
        _patientDetail!['is_kepala_keluarga'] = _isKepalaKeluarga;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Profil & Nomor KK Anda berhasil disimpan ke Supabase!',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          backgroundColor: const Color(0xFF27AE60),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Gagal memperbarui profil: $e',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  // ── MODAL: GABUNG KK (JOIN KK) ─────────────────────────────────────────────
  void _showJoinKkModal(
    Color cardBg,
    Color textColor,
    Color subtitleColor,
    Color borderColor,
    Color purple,
    Color inputBg,
  ) {
    final joinKkCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: 440,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.link_rounded, color: purple, size: 24),
                      const SizedBox(width: 10),
                      Text(
                        'GABUNG KARTU KELUARGA (KK)',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    icon: Icon(Icons.close_rounded, color: subtitleColor),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Masukkan 16-Digit Nomor KK milik keluarga terdaftar. Permintaan bergabung akan dikirim dan membutuhkan persetujuan (Accept) dari Kepala Keluarga.',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  color: subtitleColor,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              _buildModalInput(
                'Nomor KK Yang Ingin Diikuti (16 Digit) *',
                joinKkCtrl,
                textColor,
                subtitleColor,
                borderColor,
                inputBg,
                hint: 'Masukkan 16 Digit No. KK...',
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: purple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () async {
                    final targetKk = joinKkCtrl.text.trim();
                    if (targetKk.isEmpty) return;

                    final user = ref.read(landingPageProvider).loggedInUser;
                    if (user == null || user['id'] == null) return;

                    final success = await _db.joinKkByNumber(
                      patientId: user['id'].toString(),
                      patientName: user['name'] ?? 'Pasien',
                      patientNik: user['nik'] ?? '-',
                      noKk: targetKk,
                    );

                    Navigator.of(ctx).pop();

                    if (success) {
                      _kkController.text = targetKk;
                      setState(() {
                        _patientDetail ??= {};
                        _patientDetail!['no_kk'] = targetKk;
                        _patientDetail!['accept_kk'] = false;
                        _isKepalaKeluarga = false;
                      });
                      _loadPatientDetails();

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Permintaan bergabung ke No. KK ($targetKk) berhasil dikirim! Menunggu persetujuan (Accept) dari Kepala Keluarga.',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          backgroundColor: Colors.amber[800],
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Gagal mengirim permintaan gabung KK.'),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.send_rounded, size: 16),
                  label: Text(
                    'Kirim Permintaan Gabung KK',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── MODAL: TAMBAH ANGGOTA KELUARGA (SEARCH PATIENT / MANUAL) ─────────────
  void _showAddFamilyMemberModal(
    Color cardBg,
    Color textColor,
    Color subtitleColor,
    Color borderColor,
    Color purple,
    Color inputBg,
    bool isDark,
  ) {
    final searchCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final nikCtrl = TextEditingController();
    final hubunganCtrl = TextEditingController(text: 'Anak');
    final usiaCtrl = TextEditingController(text: '5 Thn');
    final bpjsCtrl = TextEditingController(text: '0001234567894 (Aktif)');
    final statusCtrl = TextEditingController(text: 'Sehat');
    String genderVal = 'Laki-laki';
    String golDarahVal = 'O+';

    List<Map<String, dynamic>> searchedPatients = [];
    Map<String, dynamic>? selectedUserPatient;
    bool isSearching = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Dialog(
            backgroundColor: cardBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Container(
              width: 540,
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.person_add_alt_1_rounded,
                              color: purple,
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'TAMBAH ANGGOTA KELUARGA BARU',
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                color: textColor,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          icon: Icon(Icons.close_rounded, color: subtitleColor),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Section 1: Search Registered Patient User
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: purple.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: purple.withOpacity(0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.search_rounded,
                                size: 16,
                                color: purple,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Pilih Dari Pasien Terdaftar di Mapotech:',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: purple,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: searchCtrl,
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              color: textColor,
                            ),
                            decoration: InputDecoration(
                              isDense: true,
                              hintText:
                                  'Cari Nama atau NIK pasien terdaftar...',
                              filled: true,
                              fillColor: inputBg,
                              prefixIcon: const Icon(
                                Icons.person_search_rounded,
                                size: 16,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 10,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: borderColor),
                              ),
                            ),
                            onChanged: (val) async {
                              if (val.trim().length < 2) {
                                setModalState(() {
                                  searchedPatients = [];
                                  isSearching = false;
                                });
                                return;
                              }
                              setModalState(() => isSearching = true);
                              final res = await _db.searchPatients(val.trim());
                              setModalState(() {
                                searchedPatients = res;
                                isSearching = false;
                              });
                            },
                          ),
                          if (isSearching)
                            const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: LinearProgressIndicator(),
                            ),
                          if (searchedPatients.isNotEmpty)
                            Container(
                              height: 120,
                              margin: const EdgeInsets.only(top: 6),
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: borderColor),
                              ),
                              child: ListView.builder(
                                shrinkWrap: true,
                                itemCount: searchedPatients.length,
                                itemBuilder: (context, i) {
                                  final p = searchedPatients[i];
                                  return ListTile(
                                    dense: true,
                                    title: Text(
                                      p['name'] ?? '-',
                                      style: GoogleFonts.outfit(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: textColor,
                                      ),
                                    ),
                                    subtitle: Text(
                                      'NIK: ${p['nik'] ?? '-'} • ${p['gender'] ?? '-'}',
                                      style: GoogleFonts.outfit(
                                        fontSize: 10,
                                        color: subtitleColor,
                                      ),
                                    ),
                                    trailing: const Icon(
                                      Icons.check_circle_outline_rounded,
                                      size: 16,
                                      color: Colors.green,
                                    ),
                                    onTap: () {
                                      setModalState(() {
                                        selectedUserPatient = p;
                                        nameCtrl.text = p['name'] ?? '';
                                        nikCtrl.text = p['nik'] ?? '';
                                        if (p['gender'] == 'male' ||
                                            p['gender'] == 'Laki-laki') {
                                          genderVal = 'Laki-laki';
                                        } else {
                                          genderVal = 'Perempuan';
                                        }
                                        searchedPatients = [];
                                      });
                                    },
                                  );
                                },
                              ),
                            ),
                          if (selectedUserPatient != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    size: 14,
                                    color: Colors.green,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Terhubung: ${selectedUserPatient!['name']} (${selectedUserPatient!['nik']})',
                                    style: GoogleFonts.outfit(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    _buildModalInput(
                      'Nama Lengkap *',
                      nameCtrl,
                      textColor,
                      subtitleColor,
                      borderColor,
                      inputBg,
                      hint: 'Nama Anggota Keluarga',
                    ),
                    const SizedBox(height: 10),
                    _buildModalInput(
                      'NIK (16 Digit)',
                      nikCtrl,
                      textColor,
                      subtitleColor,
                      borderColor,
                      inputBg,
                      hint: 'Contoh: 351108...',
                      keyboardType: TextInputType.number,
                      maxLength: 16,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(16),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _buildModalInput(
                            'Hubungan Keluarga',
                            hubunganCtrl,
                            textColor,
                            subtitleColor,
                            borderColor,
                            inputBg,
                            hint: 'Suami/Istri/Anak/Orang Tua',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildModalInput(
                            'Usia',
                            usiaCtrl,
                            textColor,
                            subtitleColor,
                            borderColor,
                            inputBg,
                            hint: 'Contoh: 5 Thn',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Jenis Kelamin',
                                style: GoogleFonts.outfit(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: subtitleColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: inputBg,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: borderColor),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    isExpanded: true,
                                    value: genderVal,
                                    style: GoogleFonts.outfit(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: textColor,
                                    ),
                                    dropdownColor: cardBg,
                                    items: ['Laki-laki', 'Perempuan']
                                        .map(
                                          (g) => DropdownMenuItem(
                                            value: g,
                                            child: Text(g),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (v) {
                                      if (v != null)
                                        setModalState(() => genderVal = v);
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Golongan Darah',
                                style: GoogleFonts.outfit(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: subtitleColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: inputBg,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: borderColor),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    isExpanded: true,
                                    value: golDarahVal,
                                    style: GoogleFonts.outfit(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: textColor,
                                    ),
                                    dropdownColor: cardBg,
                                    items:
                                        [
                                              'A+',
                                              'A-',
                                              'B+',
                                              'B-',
                                              'AB+',
                                              'AB-',
                                              'O+',
                                              'O-',
                                            ]
                                            .map(
                                              (g) => DropdownMenuItem(
                                                value: g,
                                                child: Text(g),
                                              ),
                                            )
                                            .toList(),
                                    onChanged: (v) {
                                      if (v != null)
                                        setModalState(() => golDarahVal = v);
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _buildModalInput(
                      'No. Kartu BPJS / JKN',
                      bpjsCtrl,
                      textColor,
                      subtitleColor,
                      borderColor,
                      inputBg,
                      hint: 'Nomor BPJS',
                    ),
                    const SizedBox(height: 10),
                    _buildModalInput(
                      'Status Kesehatan / Catatan Risk',
                      statusCtrl,
                      textColor,
                      subtitleColor,
                      borderColor,
                      inputBg,
                      hint: 'Sehat / Risiko...',
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: purple,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () async {
                          if (nameCtrl.text.trim().isEmpty) return;
                          final nikVal = nikCtrl.text.trim();
                          if (nikVal.isNotEmpty && (nikVal.length != 16 || !RegExp(r'^\d{16}$').hasMatch(nikVal))) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('NIK harus 16 digit angka numerik!'),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                            return;
                          }
                          final user = ref
                              .read(landingPageProvider)
                              .loggedInUser;
                          final newMember = {
                            'patient_id': user?['id'],
                            'member_user_id': selectedUserPatient?['id'],
                            'nama': nameCtrl.text.trim(),
                            'nik': nikCtrl.text.trim().isEmpty
                                ? '351108${DateTime.now().millisecondsSinceEpoch}'
                                : nikCtrl.text.trim(),
                            'hubungan': hubunganCtrl.text.trim(),
                            'usia': usiaCtrl.text.trim(),
                            'gender': genderVal,
                            'gol_darah': golDarahVal,
                            'no_bpjs': bpjsCtrl.text.trim(),
                            'status_kesehatan': statusCtrl.text.trim(),
                            'accept_kk': true,
                          };

                          final inserted = await _db.addFamilyMember(newMember);
                          if (inserted != null) {
                            setState(() {
                              _familyMembers.add(inserted);
                            });
                            Navigator.of(ctx).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Anggota keluarga ${nameCtrl.text.trim()} berhasil disimpan ke Supabase!',
                                ),
                                backgroundColor: const Color(0xFF27AE60),
                              ),
                            );
                          } else {
                            setState(() {
                              _familyMembers.add(newMember);
                            });
                            Navigator.of(ctx).pop();
                          }
                        },
                        icon: const Icon(Icons.check_circle_rounded, size: 16),
                        label: Text(
                          'Simpan Anggota Keluarga',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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

  void _handleAcceptOrRejectMember(
    String memberId,
    String? memberUserId,
    bool accept,
    int index,
  ) async {
    final success = await _db.updateFamilyMemberAcceptStatus(
      memberId,
      accept: accept,
      memberUserId: memberUserId,
    );

    if (success) {
      if (accept) {
        setState(() {
          _familyMembers[index]['accept_kk'] = true;
          _familyMembers[index]['status_kesehatan'] = 'Disetujui / Aktif';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Anggota keluarga berhasil disetujui (Accepted)!'),
            backgroundColor: Color(0xFF27AE60),
          ),
        );
      } else {
        setState(() {
          _familyMembers.removeAt(index);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permintaan gabung KK berhasil ditolak.'),
            backgroundColor: Colors.orangeAccent,
          ),
        );
      }
    }
  }

  void _deleteFamilyMemberRow(int idx, String? id) async {
    if (id != null) {
      await _db.deleteFamilyMember(id);
    }
    setState(() {
      _familyMembers.removeAt(idx);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Anggota keluarga dihapus dari database Supabase.'),
        backgroundColor: Colors.orangeAccent,
      ),
    );
  }

  Widget _buildModalInput(
    String label,
    TextEditingController controller,
    Color textColor,
    Color subColor,
    Color borderColor,
    Color inputBg, {
    String? hint,
    TextInputType? keyboardType,
    int? maxLength,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: subColor,
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLength: maxLength,
          inputFormatters: inputFormatters,
          style: GoogleFonts.outfit(fontSize: 11, color: textColor),
          decoration: InputDecoration(
            isDense: true,
            counterText: '',
            hintText: hint,
            hintStyle: GoogleFonts.outfit(
              fontSize: 10,
              color: subColor.withOpacity(0.6),
            ),
            filled: true,
            fillColor: inputBg,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: borderColor),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(landingPageProvider);
    final user = state.loggedInUser;

    final isDark = state.appearance == 'dark';
    final isRev = state.appearance == 'rev';
    final notifier = ref.read(landingPageProvider.notifier);
    final cardBg = notifier.getCardColor();
    final textColor = notifier.getTextColor();
    final subtitleColor = notifier.getBodyTextColor();
    final borderColor = notifier.getBorderColor();
    final inputBg = isDark ? const Color(0xFF1E1E22) : const Color(0xFFF3F0FA);
    final purple = notifier.getPrimaryColor();
    final orange = const Color(0xFFF39C12);
    final blue = const Color(0xFF3498DB);

    // Retrieve patient detail columns
    final bpjsNumber = _patientDetail?['no_bpjs'] ?? 'Belum dihubungkan';
    final qrToken =
        _patientDetail?['qr_token'] ?? user?['id'] ?? 'TOKEN-MOCK-123';

    // Subscription details
    final subStatus = (user?['subscription_status'] ?? 'inactive')
        .toString()
        .toUpperCase();
    final subExpiry = user?['subscription_expires_at'] != null
        ? user!['subscription_expires_at'].toString().split('T').first
        : '-';
    int sisaHari = 0;
    if (user?['subscription_expires_at'] != null) {
      try {
        final expiryDate = DateTime.parse(user!['subscription_expires_at']);
        final diff = expiryDate.difference(DateTime.now()).inDays;
        sisaHari = diff > 0 ? diff : 0;
      } catch (_) {}
    }

    return _isLoading
        ? const SkeletonScope(child: SkeletonProfile(isDoctor: false))
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Hero Banner ───────────────────────────────────────────────────
              _buildHeroBanner(
                isDark,
                isRev,
                textColor,
                subtitleColor,
                purple,
                cardBg,
                user,
              ),

              const SizedBox(height: 20),

              // ── Tabbed Selector ────────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _activeTab = 0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _activeTab == 0
                                ? purple
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.person_rounded,
                                size: 16,
                                color: _activeTab == 0
                                    ? Colors.white
                                    : subtitleColor,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Profil & Identitas Pasien',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: _activeTab == 0
                                      ? Colors.white
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
                        onTap: () => setState(() => _activeTab = 1),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _activeTab == 1
                                ? purple
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.family_restroom_rounded,
                                size: 16,
                                color: _activeTab == 1
                                    ? Colors.white
                                    : subtitleColor,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Informasi Keluarga (KK)',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: _activeTab == 1
                                      ? Colors.white
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

              // TAB CONTENT RENDER
              if (_activeTab == 0)
                _buildProfileTab(
                  cardBg,
                  textColor,
                  subtitleColor,
                  borderColor,
                  inputBg,
                  purple,
                  subStatus,
                  subExpiry,
                  sisaHari,
                  orange,
                  bpjsNumber,
                  qrToken,
                  blue,
                  user,
                )
              else
                _buildFamilyTab(
                  cardBg,
                  textColor,
                  subtitleColor,
                  borderColor,
                  inputBg,
                  purple,
                  isDark,
                ),
            ],
          );
  }

  // ── TAB 1: INFORMASI PRIBADI & PROFILE ─────────────────────────────────────
  Widget _buildProfileTab(
    Color cardBg,
    Color textColor,
    Color subtitleColor,
    Color borderColor,
    Color inputBg,
    Color purple,
    String subStatus,
    String subExpiry,
    int sisaHari,
    Color orange,
    String bpjsNumber,
    String qrToken,
    Color blue,
    Map<String, dynamic>? user,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Status Langganan
        ProfileSectionCard(
          icon: Icons.credit_card_rounded,
          title: 'Status Langganan',
          cardBg: cardBg,
          border: borderColor,
          textColor: textColor,
          child: Column(
            children: [
              ProfileInfoRow(
                label: 'Status:',
                value: subStatus,
                subtitleColor: subtitleColor,
                valueColor: subStatus == 'ACTIVE'
                    ? const Color(0xFF27AE60)
                    : orange,
                rightBold: true,
                inputBg: inputBg,
              ),
              const SizedBox(height: 8),
              ProfileInfoRow(
                label: 'Tanggal Berakhir:',
                value: subExpiry,
                subtitleColor: subtitleColor,
                valueColor: textColor,
                inputBg: inputBg,
              ),
              const SizedBox(height: 8),
              ProfileInfoRow(
                label: 'Sisa Hari:',
                value: '$sisaHari Hari',
                subtitleColor: subtitleColor,
                valueColor: textColor,
                icon: Icons.hourglass_empty_rounded,
                inputBg: inputBg,
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Informasi Pribadi
        ProfileSectionCard(
          icon: Icons.person_outline_rounded,
          title: 'Informasi Pribadi',
          cardBg: cardBg,
          border: borderColor,
          textColor: textColor,
          trailing: TextButton.icon(
            icon: Icon(
              _isSaving ? Icons.hourglass_top_rounded : Icons.save_rounded,
              size: 13,
              color: purple,
            ),
            label: Text(
              _isSaving ? 'Menyimpan...' : 'Simpan Profil',
              style: GoogleFonts.outfit(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: purple,
              ),
            ),
            onPressed: _isSaving ? null : _saveProfileChanges,
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildEditableField(
                      'Nama Lengkap',
                      _nameController,
                      inputBg,
                      textColor,
                      subtitleColor,
                      Icons.person_outline_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildEditableField(
                      'NIK (16 Digit)',
                      _nikController,
                      inputBg,
                      textColor,
                      subtitleColor,
                      Icons.badge_outlined,
                      keyboardType: TextInputType.number,
                      maxLength: 16,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(16),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildEditableField(
                      'Nomor Telepon (11-13 Digit)',
                      _phoneController,
                      inputBg,
                      textColor,
                      subtitleColor,
                      Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      maxLength: 13,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(13),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildEditableField(
                      'Tanggal Lahir (YYYY-MM-DD)',
                      _birthDateController,
                      inputBg,
                      textColor,
                      subtitleColor,
                      Icons.cake_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Jenis Kelamin',
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: subtitleColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: inputBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _gender,
                        dropdownColor: cardBg,
                        isExpanded: true,
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: textColor,
                          fontWeight: FontWeight.bold,
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'male',
                            child: Text('Laki-laki'),
                          ),
                          DropdownMenuItem(
                            value: 'female',
                            child: Text('Perempuan'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _gender = val);
                        },
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildEditableField(
                      'No. KK (Kartu Keluarga)',
                      _kkController,
                      inputBg,
                      textColor,
                      subtitleColor,
                      Icons.family_restroom_outlined,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ProfileInfoRow(
                      label: 'No. BPJS:',
                      value: bpjsNumber,
                      subtitleColor: subtitleColor,
                      valueColor: textColor,
                      inputBg: inputBg,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Alamat Pasien
        ProfileSectionCard(
          icon: Icons.location_on_outlined,
          title: 'Alamat Pasien',
          cardBg: cardBg,
          border: borderColor,
          textColor: textColor,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Alamat Lengkap Domisili Pasien',
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: subtitleColor,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  color: inputBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                child: TextField(
                  controller: _addressDetailController,
                  maxLines: 2,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: textColor,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Masukkan alamat tinggal detail...',
                    hintStyle: GoogleFonts.outfit(
                      fontSize: 11,
                      color: subtitleColor.withOpacity(0.5),
                    ),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Informasi Medis Tambahan
        ProfileSectionCard(
          icon: Icons.favorite_border_rounded,
          title: 'Informasi Medis Tambahan',
          cardBg: cardBg,
          border: borderColor,
          textColor: textColor,
          child: ProfileFieldGrid(
            children: [
              ProfileField(
                label: 'Golongan Darah',
                value: user?['blood_type'] ?? 'A+',
                inputBg: inputBg,
                valueColor: textColor,
                subtitleColor: subtitleColor,
                icon: Icons.water_drop_outlined,
              ),
              ProfileField(
                label: 'Alergi',
                value: 'Tidak ada',
                inputBg: inputBg,
                valueColor: textColor,
                subtitleColor: subtitleColor,
                icon: Icons.warning_amber_outlined,
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // QR Pasien (Identitas)
        ProfileSectionCard(
          icon: Icons.qr_code_2_rounded,
          title: 'QR Pasien (Identitas)',
          cardBg: cardBg,
          border: borderColor,
          textColor: textColor,
          child: Column(
            children: [
              Text(
                'Tunjukkan QR ini ke Apotek (POS Kasir) untuk menghubungkan\ntransaksi pembelian dengan riwayat medis Anda.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: blue,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Token QR: $qrToken',
                style: GoogleFonts.outfit(
                  fontSize: 9,
                  color: subtitleColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: purple.withOpacity(0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(10),
                child: CustomPaint(painter: _LargeQrPainter()),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),
      ],
    );
  }

  // ── TAB 2: INFORMASI KELUARGA (KK & ANGGOTA KELUARGA REAL DB) ─────────────
  Widget _buildFamilyTab(
    Color cardBg,
    Color textColor,
    Color subtitleColor,
    Color borderColor,
    Color inputBg,
    Color purple,
    bool isDark,
  ) {
    final bool isMyKkPending = _patientDetail?['accept_kk'] == false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Summary Header Card for KK & Direct Input
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: purple.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.family_restroom_rounded,
                          size: 24,
                          color: purple,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'DATA KARTU KELUARGA (KK)',
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: textColor,
                            ),
                          ),
                          Text(
                            'Terdaftar ${_familyMembers.length} anggota keluarga dalam database Supabase.',
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              color: subtitleColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      // Toggle Switch: Saya Kepala Keluarga
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: inputBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _isKepalaKeluarga
                                ? const Color(0xFF27AE60)
                                : borderColor,
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(
                              'Saya Kepala Keluarga',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _isKepalaKeluarga
                                    ? const Color(0xFF27AE60)
                                    : textColor,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Switch(
                              value: _isKepalaKeluarga,
                              activeColor: const Color(0xFF27AE60),
                              onChanged: (val) =>
                                  _toggleKepalaKeluargaStatus(val),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 10),

                      if (!_isKepalaKeluarga)
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: purple,
                            side: BorderSide(color: purple, width: 1.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                          ),
                          onPressed: () => _showJoinKkModal(
                            cardBg,
                            textColor,
                            subtitleColor,
                            borderColor,
                            purple,
                            inputBg,
                          ),
                          icon: const Icon(Icons.link_rounded, size: 16),
                          label: Text(
                            'Gabung KK',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),

                      if (_isKepalaKeluarga) ...[
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: purple,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          onPressed: () => _showAddFamilyMemberModal(
                            cardBg,
                            textColor,
                            subtitleColor,
                            borderColor,
                            purple,
                            inputBg,
                            isDark,
                          ),
                          icon: const Icon(Icons.person_add_rounded, size: 16),
                          label: Text(
                            '+ Tambah Anggota',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),

              if (_isKepalaKeluarga) ...[
                const SizedBox(height: 16),
                // Single No. KK Input & Save Row (Only visible when is_kepala_keluarga is true)
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Nomor KK (16 Digit)',
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: subtitleColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          TextField(
                            controller: _kkController,
                            keyboardType: TextInputType.number,
                            maxLength: 16,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(16),
                            ],
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                            decoration: InputDecoration(
                              isDense: true,
                              counterText: '',
                              hintText: 'Masukkan 16 Digit No. KK...',
                              filled: true,
                              fillColor: inputBg,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: borderColor),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: borderColor),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(color: purple),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF27AE60),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                          ),
                          onPressed: _saveKkNumberOnly,
                          icon: const Icon(Icons.save_rounded, size: 14),
                          label: Text(
                            'Simpan No. KK',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],

              if (isMyKkPending)
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber[800]!),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.hourglass_top_rounded,
                        size: 16,
                        color: Colors.amber[900],
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Permintaan bergabung Anda ke Nomor KK (${_kkController.text}) sedang menunggu persetujuan (Accept) dari Kepala Keluarga.',
                          style: GoogleFonts.outfit(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber[900],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Table of Family Members
        ProfileSectionCard(
          icon: Icons.groups_rounded,
          title: 'Tabel Anggota Keluarga',
          cardBg: cardBg,
          border: borderColor,
          textColor: textColor,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_familyMembers.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: inputBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.people_outline_rounded,
                        size: 36,
                        color: subtitleColor.withOpacity(0.5),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Belum Ada Anggota Keluarga Terdaftar',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Aktifkan switch "Saya Kepala Keluarga" untuk menambah anggota, atau klik "Gabung KK" untuk mengikuti grup KK terdaftar.',
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          color: subtitleColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              else
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columnSpacing: 18,
                    headingRowColor: WidgetStateProperty.all(inputBg),
                    columns: [
                      DataColumn(
                        label: Text(
                          'NO',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: textColor,
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'NAMA LENGKAP & NIK',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: textColor,
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'HUBUNGAN KELUARGA',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: textColor,
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'USIA / GENDER',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: textColor,
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'GOL. DARAH',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: textColor,
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'NO. BPJS / JKN',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: textColor,
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'STATUS PERSETUJUAN',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: textColor,
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'AKSI',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: textColor,
                          ),
                        ),
                      ),
                    ],
                    rows: _familyMembers.asMap().entries.map((entry) {
                      final idx = entry.key + 1;
                      final m = entry.value;
                      final String? memberId = m['id']?.toString();
                      final String? memberUserId = m['member_user_id']
                          ?.toString();
                      final bool isAccepted = m['accept_kk'] != false;

                      return DataRow(
                        cells: [
                          DataCell(
                            Text(
                              '$idx',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: subtitleColor,
                              ),
                            ),
                          ),
                          DataCell(
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  m['nama'] ?? '-',
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                  ),
                                ),
                                Text(
                                  'NIK: ${m['nik'] ?? '-'}',
                                  style: GoogleFonts.outfit(
                                    fontSize: 9.5,
                                    color: subtitleColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: purple.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                m['hubungan'] ?? 'Anggota',
                                style: GoogleFonts.outfit(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: purple,
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              '${m['usia'] ?? '-'} (${m['gender'] ?? '-'})',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                color: textColor,
                              ),
                            ),
                          ),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.redAccent.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                m['gol_darah'] ?? m['golDarah'] ?? 'O+',
                                style: GoogleFonts.outfit(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.redAccent,
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              m['no_bpjs'] ?? m['noBpjs'] ?? '-',
                              style: GoogleFonts.outfit(
                                fontSize: 10.5,
                                color: subtitleColor,
                              ),
                            ),
                          ),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: isAccepted
                                    ? const Color(0xFF27AE60).withOpacity(0.12)
                                    : Colors.amber.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                isAccepted
                                    ? 'Disetujui (Accept) ✅'
                                    : 'Menunggu Approval ⏳',
                                style: GoogleFonts.outfit(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isAccepted
                                      ? const Color(0xFF27AE60)
                                      : Colors.amber[900],
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                            isAccepted
                                ? IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline_rounded,
                                      size: 18,
                                      color: Colors.redAccent,
                                    ),
                                    onPressed: () => _deleteFamilyMemberRow(
                                      entry.key,
                                      memberId,
                                    ),
                                  )
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        tooltip: 'Setujui (Accept)',
                                        icon: const Icon(
                                          Icons.check_circle_rounded,
                                          size: 20,
                                          color: Color(0xFF27AE60),
                                        ),
                                        onPressed: () =>
                                            _handleAcceptOrRejectMember(
                                              memberId ?? '',
                                              memberUserId,
                                              true,
                                              entry.key,
                                            ),
                                      ),
                                      IconButton(
                                        tooltip: 'Tolak (Reject)',
                                        icon: const Icon(
                                          Icons.cancel_rounded,
                                          size: 20,
                                          color: Colors.redAccent,
                                        ),
                                        onPressed: () =>
                                            _handleAcceptOrRejectMember(
                                              memberId ?? '',
                                              memberUserId,
                                              false,
                                              entry.key,
                                            ),
                                      ),
                                    ],
                                  ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 24),
      ],
    );
  }

  // ─── Hero Banner ──────────────────────────────────────────────────────────
  Widget _buildHeroBanner(
    bool isDark,
    bool isRev,
    Color textColor,
    Color subtitleColor,
    Color purple,
    Color cardBg,
    Map<String, dynamic>? user,
  ) {
    final name = user?['name'] ?? 'Alvin';
    final email = user?['email'] ?? 'alvinmhs289@gmail.com';
    final String initial = name.isNotEmpty ? name[0].toUpperCase() : 'A';

    return Container(
      height: 160,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E1E22), const Color(0xFF161619)]
              : [const Color(0xFFEDE7FB), const Color(0xFFDDD0F9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Decorative blobs
          Positioned(
            left: -30,
            top: -30,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: purple.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            right: -20,
            bottom: -20,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: purple.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),

          // Content
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Avatar
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2E2E35) : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child:
                          (user?['avatar_url'] != null &&
                              (user!['avatar_url'] as String).isNotEmpty)
                          ? Image.network(
                              user['avatar_url'] as String,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Center(
                                child: Text(
                                  initial,
                                  style: GoogleFonts.outfit(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                    color: purple,
                                  ),
                                ),
                              ),
                              loadingBuilder: (_, child, progress) =>
                                  progress == null
                                  ? child
                                  : Center(
                                      child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: purple,
                                        ),
                                      ),
                                    ),
                            )
                          : Center(
                              child: Text(
                                initial,
                                style: GoogleFonts.outfit(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  color: purple,
                                ),
                              ),
                            ),
                    ),
                  ),
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: purple,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.camera_alt_rounded,
                      color: Colors.white,
                      size: 11,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              Text(
                name,
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : const Color(0xFF3D1A6E),
                ),
              ),
              Text(
                email,
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  color: (isDark ? Colors.white : const Color(0xFF3D1A6E))
                      .withOpacity(0.6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEditableField(
    String label,
    TextEditingController controller,
    Color bg,
    Color text,
    Color subtitle,
    IconData icon, {
    TextInputType? keyboardType,
    int? maxLength,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: subtitle,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFECEEF2)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Icon(icon, size: 16, color: subtitle),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: keyboardType,
                  maxLength: maxLength,
                  inputFormatters: inputFormatters,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: text,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    counterText: '',
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Large Qr Painter ─────────────────────────────────────────────────────────

class _LargeQrPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1B0C3C)
      ..style = PaintingStyle.fill;

    final cell = size.width / 11;

    // A more detailed QR-like pattern
    const grid = [
      [1, 1, 1, 1, 1, 1, 1, 0, 1, 0, 1],
      [1, 0, 0, 0, 0, 0, 1, 0, 0, 1, 0],
      [1, 0, 1, 1, 1, 0, 1, 0, 1, 1, 1],
      [1, 0, 1, 1, 1, 0, 1, 0, 0, 0, 1],
      [1, 0, 1, 1, 1, 0, 1, 0, 1, 0, 0],
      [1, 0, 0, 0, 0, 0, 1, 0, 1, 1, 0],
      [1, 1, 1, 1, 1, 1, 1, 0, 1, 0, 1],
      [0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0],
      [1, 0, 1, 1, 0, 1, 1, 0, 1, 1, 1],
      [0, 1, 0, 0, 1, 0, 0, 0, 0, 0, 1],
      [1, 1, 0, 1, 1, 0, 1, 0, 1, 1, 1],
    ];

    for (int r = 0; r < 11; r++) {
      for (int c = 0; c < 11; c++) {
        if (grid[r][c] == 1) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(
                r * cell + 0.8,
                c * cell + 0.8,
                cell - 1.6,
                cell - 1.6,
              ),
              const Radius.circular(1.5),
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
