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

  // Patient detail from database (bpjs/qr_token)
  Map<String, dynamic>? _patientDetail;

  // Controllers for editing
  late TextEditingController _nameController;
  late TextEditingController _nikController;
  late TextEditingController _phoneController;
  late TextEditingController _birthDateController;
  late TextEditingController _addressDetailController;
  late TextEditingController _provinceController;
  late TextEditingController _districtController;
  late TextEditingController _subDistrictController;
  late TextEditingController _villageController;

  String _gender = 'male';

  @override
  void initState() {
    super.initState();
    final user = ref.read(landingPageProvider).loggedInUser;
    
    _nameController = TextEditingController(text: user?['name'] ?? 'Alvin');
    _nikController = TextEditingController(text: user?['nik'] ?? '3511081208000003');
    _phoneController = TextEditingController(text: user?['phone_number'] ?? '08XXXXXXXXXX');
    _birthDateController = TextEditingController(text: user?['birth_date'] ?? '2000-12-08');
    _addressDetailController = TextEditingController(text: user?['address'] ?? 'Kel. KEJAYAN, Kec. PUER, KABUPATEN BONDOWOSO, Prov. JAWA TIMUR');
    _provinceController = TextEditingController(text: user?['province'] ?? 'JAWA TIMUR');
    _districtController = TextEditingController(text: user?['district'] ?? 'KABUPATEN BONDOWOSO');
    _subDistrictController = TextEditingController(text: user?['sub_district'] ?? 'PUER');
    _villageController = TextEditingController(text: user?['village'] ?? 'KEJAYAN');
    _gender = user?['gender'] ?? 'male';

    _loadPatientDetails();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nikController.dispose();
    _phoneController.dispose();
    _birthDateController.dispose();
    _addressDetailController.dispose();
    _provinceController.dispose();
    _districtController.dispose();
    _subDistrictController.dispose();
    _villageController.dispose();
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
        _provinceController.text = syncedUser?['province'] ?? '';
        _districtController.text = syncedUser?['district'] ?? '';
        _subDistrictController.text = syncedUser?['sub_district'] ?? '';
        _villageController.text = syncedUser?['village'] ?? '';
        _gender = syncedUser?['gender'] ?? 'male';

        setState(() {
          final detailRaw = profile['patient_details'];
          _patientDetail = detailRaw is Map
              ? Map<String, dynamic>.from(detailRaw)
              : null;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfileChanges() async {
    final user = ref.read(landingPageProvider).loggedInUser;
    if (user == null) return;

    setState(() => _isSaving = true);
    final updatedData = {
      'name': _nameController.text.trim(),
      'nik': _nikController.text.trim(),
      'phone_number': _phoneController.text.trim(),
      'birth_date': _birthDateController.text.trim(),
      'address': _addressDetailController.text.trim(),
      'gender': _gender,
      'province': _provinceController.text.trim(),
      'district': _districtController.text.trim(),
      'sub_district': _subDistrictController.text.trim(),
      'village': _villageController.text.trim(),
    };

    try {
      await _db.updatePatientProfile(user['id'], updatedData);
      
      // Update local state
      ref.read(landingPageProvider.notifier).updateUser(updatedData);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Profil Anda berhasil diperbarui di database!', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
          backgroundColor: const Color(0xFF27AE60),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memperbarui profil: $e', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(landingPageProvider);
    final user = state.loggedInUser;

    final isDark = state.appearance == 'dark';
    final isRev = state.appearance == 'rev';
    final cardBg = isDark ? const Color(0xFF161619) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1B0C3C);
    final subtitleColor = isDark ? Colors.grey[400]! : const Color(0xFF6F6A8A);
    final borderColor = isDark ? const Color(0xFF252528) : const Color(0xFFECEEF2);
    final inputBg = isDark ? const Color(0xFF1E1E22) : const Color(0xFFF3F0FA);
    final purple = const Color(0xFFB577F2);
    final orange = const Color(0xFFF39C12);
    final blue = const Color(0xFF3498DB);

    // Retrieve subscription state from user
    final subStatus = (user?['subscription_status'] ?? 'inactive').toString().toUpperCase();
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

    // Retrieve patient detail columns
    final bpjsNumber = _patientDetail?['no_bpjs'] ?? 'Belum dihubungkan';
    final qrToken = _patientDetail?['qr_token'] ?? user?['id'] ?? 'TOKEN-MOCK-123';

    return _isLoading
        ? const SkeletonScope(
            child: SkeletonProfile(isDoctor: false),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Hero Banner ───────────────────────────────────────────────────
              _buildHeroBanner(isDark, isRev, textColor, subtitleColor, purple, cardBg, user),

              const SizedBox(height: 20),

              // ── Status Langganan ─────────────────────────────────────────────
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
                      valueColor: subStatus == 'ACTIVE' ? const Color(0xFF27AE60) : orange,
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

              // ── Informasi Pribadi ─────────────────────────────────────────────
              ProfileSectionCard(
                icon: Icons.person_outline_rounded,
                title: 'Informasi Pribadi',
                cardBg: cardBg,
                border: borderColor,
                textColor: textColor,
                trailing: TextButton.icon(
                  icon: Icon(_isSaving ? Icons.hourglass_top_rounded : Icons.save_rounded, size: 13, color: purple),
                  label: Text(
                    _isSaving ? 'Menyimpan...' : 'Simpan Profil',
                    style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w700, color: purple),
                  ),
                  onPressed: _isSaving ? null : _saveProfileChanges,
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildEditableField('Nama Lengkap', _nameController, inputBg, textColor, subtitleColor, Icons.person_outline_rounded),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildEditableField('NIK', _nikController, inputBg, textColor, subtitleColor, Icons.badge_outlined),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildEditableField('Nomor Telepon', _phoneController, inputBg, textColor, subtitleColor, Icons.phone_outlined),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildEditableField('Tanggal Lahir (YYYY-MM-DD)', _birthDateController, inputBg, textColor, subtitleColor, Icons.cake_outlined),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Jenis Kelamin',
                          style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w700, color: subtitleColor),
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
                              style: GoogleFonts.outfit(fontSize: 12, color: textColor, fontWeight: FontWeight.bold),
                              items: const [
                                DropdownMenuItem(value: 'male', child: Text('Laki-laki')),
                                DropdownMenuItem(value: 'female', child: Text('Perempuan')),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _gender = val);
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ProfileInfoRow(
                      label: 'No. BPJS:',
                      value: bpjsNumber,
                      subtitleColor: subtitleColor,
                      valueColor: textColor,
                      inputBg: inputBg,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── Alamat ───────────────────────────────────────────────────────
              ProfileSectionCard(
                icon: Icons.location_on_outlined,
                title: 'Alamat Pasien',
                cardBg: cardBg,
                border: borderColor,
                textColor: textColor,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildEditableField('Provinsi', _provinceController, inputBg, textColor, subtitleColor, Icons.map_outlined),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildEditableField('Kota/Kabupaten', _districtController, inputBg, textColor, subtitleColor, Icons.location_city_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildEditableField('Kecamatan', _subDistrictController, inputBg, textColor, subtitleColor, Icons.landscape_outlined),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildEditableField('Kelurahan/Desa', _villageController, inputBg, textColor, subtitleColor, Icons.home_work_outlined),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Alamat Detail Jalan',
                      style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w700, color: subtitleColor),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      decoration: BoxDecoration(
                        color: inputBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderColor),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      child: TextField(
                        controller: _addressDetailController,
                        maxLines: 2,
                        style: GoogleFonts.outfit(fontSize: 12, color: textColor, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          hintText: 'Masukkan alamat tinggal detail...',
                          hintStyle: GoogleFonts.outfit(fontSize: 11, color: subtitleColor.withOpacity(0.5)),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── Informasi Medis Tambahan ──────────────────────────────────────
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

              // ── QR Pasien (Identitas) ─────────────────────────────────────────
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
                      style: GoogleFonts.outfit(fontSize: 9, color: subtitleColor, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    // Large QR mockup
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
                      child: (user?['avatar_url'] != null && (user!['avatar_url'] as String).isNotEmpty)
                          ? Image.network(
                              user['avatar_url'] as String,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Center(
                                child: Text(
                                  initial,
                                  style: GoogleFonts.outfit(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                    color: purple,
                                  ),
                                ),
                              ),
                              loadingBuilder: (_, child, progress) => progress == null
                                  ? child
                                  : Center(
                                      child: SizedBox(
                                        width: 20, height: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: purple),
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
                    child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 11),
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
                  color: (isDark ? Colors.white : const Color(0xFF3D1A6E)).withOpacity(0.6),
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
    IconData icon,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w700, color: subtitle),
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
                  style: GoogleFonts.outfit(fontSize: 12, color: text, fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
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

// ─── Large QR Painter ─────────────────────────────────────────────────────────

class _LargeQrPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1B0C3C)
      ..style = PaintingStyle.fill;

    final cell = size.width / 11;

    // A more detailed QR-like pattern
    const grid = [
      [1,1,1,1,1,1,1,0,1,0,1],
      [1,0,0,0,0,0,1,0,0,1,0],
      [1,0,1,1,1,0,1,0,1,1,1],
      [1,0,1,1,1,0,1,0,0,0,1],
      [1,0,1,1,1,0,1,0,1,0,0],
      [1,0,0,0,0,0,1,0,1,1,0],
      [1,1,1,1,1,1,1,0,1,0,1],
      [0,0,0,0,0,0,0,0,0,1,0],
      [1,0,1,1,0,1,1,0,1,1,1],
      [0,1,0,0,1,0,0,0,0,0,1],
      [1,1,0,1,1,0,1,0,1,1,1],
    ];

    for (int r = 0; r < 11; r++) {
      for (int c = 0; c < 11; c++) {
        if (grid[r][c] == 1) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(r * cell + 0.8, c * cell + 0.8, cell - 1.6, cell - 1.6),
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
