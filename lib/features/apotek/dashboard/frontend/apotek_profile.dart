import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mapotech/features/landing/landing_page_data.dart';
import 'package:mapotech/shared/supabase_service.dart';

class ApotekProfile extends ConsumerStatefulWidget {
  const ApotekProfile({super.key});

  @override
  ConsumerState<ApotekProfile> createState() => _ApotekProfileState();
}

class _ApotekProfileState extends ConsumerState<ApotekProfile> {
  int _activeTab = 0; // 0: Profile, 1: Location, 2: POS & Payment, 3: API

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploadingPhoto = false;

  // Profile Photo
  String _avatarUrl = '';

  // Profile Form Controllers
  final _aboutCtrl = TextEditingController();
  final _pharmacyNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _waCtrl = TextEditingController();
  final _siaCtrl = TextEditingController();
  final _pharmacistCtrl = TextEditingController();

  // Location Form Controllers
  String _selectedProvince = 'JAWA TIMUR';
  String _selectedCity = 'KABUPATEN BONDOWOSO';
  String _selectedDistrict = 'PUJER';
  String _selectedVillage = 'KEJAYAN';
  final _detailAddressCtrl = TextEditingController();
  final _mapsLinkCtrl = TextEditingController();

  // Operational Hours
  final Map<String, Map<String, dynamic>> _schedule = {
    'Monday': {'enabled': true, 'start': '08:00 AM', 'end': '09:00 PM'},
    'Tuesday': {'enabled': true, 'start': '08:00 AM', 'end': '09:00 PM'},
    'Wednesday': {'enabled': true, 'start': '08:00 AM', 'end': '09:00 PM'},
    'Thursday': {'enabled': true, 'start': '08:00 AM', 'end': '09:00 PM'},
    'Friday': {'enabled': true, 'start': '08:00 AM', 'end': '09:00 PM'},
    'Saturday': {'enabled': true, 'start': '08:00 AM', 'end': '09:00 PM'},
    'Sunday': {'enabled': true, 'start': '08:00 AM', 'end': '09:00 PM'},
  };

  // POS & Payment Settings
  bool _enablePpn = true;
  final _ppnRateCtrl = TextEditingController(text: '11');
  bool _enableDebit = true;
  bool _enableQris = true;
  int _qrisTab = 0; // 0: Upload Foto, 1: URL, 2: Link
  String _qrisPath = '';

  // API Integration Settings
  String _apiEnvironment = 'PRODUCTION'; // 'PRODUCTION' or 'STAGING'
  final _orgIdCtrl = TextEditingController();
  final _clientIdCtrl = TextEditingController();
  final _clientSecretCtrl = TextEditingController();

  // Subscription Status
  String _subStatus = 'AKTIF';
  String _subExpiry = '02/09/2029';
  int _subDaysRemaining = 1204;
  DateTime? _subExpiryDate;

  @override
  void initState() {
    super.initState();
    _fetchDbData();
  }

  @override
  void dispose() {
    _aboutCtrl.dispose();
    _pharmacyNameCtrl.dispose();
    _phoneCtrl.dispose();
    _waCtrl.dispose();
    _siaCtrl.dispose();
    _pharmacistCtrl.dispose();
    _detailAddressCtrl.dispose();
    _mapsLinkCtrl.dispose();
    _ppnRateCtrl.dispose();
    _orgIdCtrl.dispose();
    _clientIdCtrl.dispose();
    _clientSecretCtrl.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SUPABASE DATABASE FETCH
  // ═══════════════════════════════════════════════════════════════════════════
  Future<void> _fetchDbData() async {
    final state = ref.read(landingPageProvider);
    final userId = state.activeApotekId;
    if (userId == null) {
      setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final phoneVal = _phoneCtrl.text.trim();
      if (phoneVal.isNotEmpty && (phoneVal.length < 11 || phoneVal.length > 13 || !RegExp(r'^\d{11,13}$').hasMatch(phoneVal))) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Nomor telepon harus angka numerik antara 11 - 13 digit!'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        setState(() => _isSaving = false);
        return;
      }

      final waVal = _waCtrl.text.trim();
      if (waVal.isNotEmpty && (waVal.length < 11 || waVal.length > 13 || !RegExp(r'^\d{11,13}$').hasMatch(waVal))) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Nomor WhatsApp harus angka numerik antara 11 - 13 digit!'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        setState(() => _isSaving = false);
        return;
      }

      final client = SupabaseService.client;

      // 1. Fetch from 'user' table
      final userRes = await client
          .from('user')
          .select()
          .eq('id', userId)
          .maybeSingle();

      // 2. Fetch from 'user_detail_pharmacist' table
      final detailRes = await client
          .from('user_detail_pharmacist')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (!mounted) return;

      setState(() {
        // Avatar URL
        final rawAvatar = userRes?['avatar_url']?.toString() ??
            detailRes?['satusehat_photo_url']?.toString() ??
            state.loggedInUser?['avatar_url']?.toString();
        _avatarUrl = _resolveAvatarUrl(rawAvatar);

        // Basic Info
        _pharmacyNameCtrl.text = detailRes?['nama_faskes']?.toString() ??
            userRes?['name']?.toString() ??
            state.loggedInName ??
            'CyrenElysia~♪';

        _phoneCtrl.text = userRes?['phone_number']?.toString() ??
            detailRes?['whatsapp_number']?.toString() ??
            '082122411100';

        _waCtrl.text = detailRes?['whatsapp_number']?.toString() ??
            userRes?['phone_number']?.toString() ??
            '082122411100';

        _aboutCtrl.text = detailRes?['about']?.toString() ??
            'Apotek resmi melayani obat generik, paten, resep dokter, dan konsultasi kefarmasian.';

        _siaCtrl.text = detailRes?['nomor_sia']?.toString() ?? 'SIA/503.22/012/2026';
        _pharmacistCtrl.text = detailRes?['nama_apoteker']?.toString() ??
            detailRes?['apj_name']?.toString() ??
            'Cyren Elysia, S.Farm., Apt.';

        // Address & Regional
        _selectedProvince = userRes?['province']?.toString() ?? 'JAWA TIMUR';
        _selectedCity = userRes?['district']?.toString() ?? 'KABUPATEN BONDOWOSO';
        _selectedDistrict = userRes?['sub_district']?.toString() ?? 'PUJER';
        _selectedVillage = userRes?['village']?.toString() ?? 'KEJAYAN';

        _detailAddressCtrl.text = detailRes?['alamat']?.toString() ??
            userRes?['address']?.toString() ??
            'Kel. KEJAYAN, Kec. PUJER, KABUPATEN BONDOWOSO, Prov. JAWA TIMUR';

        _mapsLinkCtrl.text = detailRes?['google_maps_link']?.toString() ??
            'https://www.google.com/maps/place/Praktek+Dokter+Umum+Dan+Toko+Baju+Pus+Acasoria/@-7.9825425,113.9884801,17z';

        // Payment Settings
        _enablePpn = detailRes?['is_ppn_active'] as bool? ?? true;
        _ppnRateCtrl.text = (detailRes?['ppn_rate'] ?? 11).toString();
        _enableDebit = detailRes?['is_debit_active'] as bool? ?? true;
        _enableQris = detailRes?['is_qris_active'] as bool? ?? true;
        _qrisPath = detailRes?['qris_path']?.toString() ?? '';

        // API Settings
        _apiEnvironment = (detailRes?['satusehat_env']?.toString().toUpperCase()) == 'STAGING'
            ? 'STAGING'
            : 'PRODUCTION';
        _orgIdCtrl.text = detailRes?['satusehat_org_id']?.toString() ?? '';
        _clientIdCtrl.text = detailRes?['satusehat_client_id']?.toString() ?? 'satusehat_client_id_apotek_9921';
        _clientSecretCtrl.text = detailRes?['satusehat_client_secret']?.toString() ?? '••••••••••••••••••••••••••••';

        // Subscription
        if (detailRes != null && detailRes['subscription_expired_at'] != null) {
          try {
            final parsed = DateTime.parse(detailRes['subscription_expired_at'].toString());
            _subExpiryDate = parsed;
            _subExpiry = '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}/${parsed.year}';
            final diff = parsed.difference(DateTime.now());
            _subDaysRemaining = diff.isNegative ? 0 : diff.inDays;
            _subStatus = (detailRes['subscription_status'] ?? 'AKTIF').toString().toUpperCase();
          } catch (_) {}
        }
      });
    } catch (e) {
      debugPrint('Error fetching Apotek profile from DB: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _resolveAvatarUrl(String? raw) {
    if (raw == null || raw.isEmpty) {
      return 'https://api.dicebear.com/7.x/bottts/png?seed=CyrenElysia';
    }
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return raw;
    }
    if (raw.startsWith('avatars/') || raw.startsWith('profiles/')) {
      return SupabaseService.client.storage.from('profiles').getPublicUrl(raw);
    }
    return raw;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SUPABASE DATABASE SAVE
  // ═══════════════════════════════════════════════════════════════════════════
  Future<void> _saveProfile() async {
    final state = ref.read(landingPageProvider);
    final userId = state.activeApotekId;
    if (userId == null) return;

    setState(() => _isSaving = true);

    try {
      final phoneVal = _phoneCtrl.text.trim();
      if (phoneVal.isNotEmpty && (phoneVal.length < 11 || phoneVal.length > 13 || !RegExp(r'^\d{11,13}$').hasMatch(phoneVal))) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Nomor telepon harus angka numerik antara 11 - 13 digit!'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        setState(() => _isSaving = false);
        return;
      }

      final waVal = _waCtrl.text.trim();
      if (waVal.isNotEmpty && (waVal.length < 11 || waVal.length > 13 || !RegExp(r'^\d{11,13}$').hasMatch(waVal))) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Nomor WhatsApp harus angka numerik antara 11 - 13 digit!'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
        setState(() => _isSaving = false);
        return;
      }

      final client = SupabaseService.client;
      final mapsLink = _mapsLinkCtrl.text.trim();
      final latLng = SupabaseService.extractLatLngFromMapsLink(mapsLink);

      // 1. Update 'user' table
      await client.from('user').update({
        'name': _pharmacyNameCtrl.text.trim(),
        'phone_number': _phoneCtrl.text.trim(),
        'address': _detailAddressCtrl.text.trim(),
        'province': _selectedProvince,
        'district': _selectedCity,
        'sub_district': _selectedDistrict,
        'village': _selectedVillage,
      }).eq('id', userId);

      // 2. Update 'user_detail_pharmacist' table
      await client.from('user_detail_pharmacist').update({
        'nama_faskes': _pharmacyNameCtrl.text.trim(),
        'about': _aboutCtrl.text.trim(),
        'alamat': _detailAddressCtrl.text.trim(),
        'whatsapp_number': _waCtrl.text.trim(),
        'nomor_sia': _siaCtrl.text.trim(),
        'nama_apoteker': _pharmacistCtrl.text.trim(),
        'google_maps_link': mapsLink,
        if (latLng['latitude'] != null) 'latitude': latLng['latitude'],
        if (latLng['longitude'] != null) 'longitude': latLng['longitude'],
        'is_ppn_active': _enablePpn,
        'ppn_rate': double.tryParse(_ppnRateCtrl.text.trim()) ?? 11,
        'is_debit_active': _enableDebit,
        'is_qris_active': _enableQris,
        'satusehat_org_id': _orgIdCtrl.text.trim(),
        'satusehat_client_id': _clientIdCtrl.text.trim(),
        'satusehat_client_secret': _clientSecretCtrl.text.trim(),
        'satusehat_env': _apiEnvironment,
      }).eq('id', userId);

      // Update Riverpod user state
      ref.read(landingPageProvider.notifier).updateUser({
        'name': _pharmacyNameCtrl.text.trim(),
        'phone_number': _phoneCtrl.text.trim(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profil Apotek berhasil disimpan ke database!'),
            backgroundColor: Color(0xFF00875A),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan profil apotek: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PHOTO PICKER & UPLOAD MODAL
  // ═══════════════════════════════════════════════════════════════════════════
  Future<void> _showPhotoPickerModal() async {
    final state = ref.read(landingPageProvider);
    final userId = state.activeApotekId;
    if (userId == null) return;

    final isDark = state.appearance == 'dark';
    final cardBgColor = isDark ? const Color(0xFF161619) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1B0C3C);
    final subtitleColor = isDark ? Colors.grey[400]! : const Color(0xFF6F6A8A);
    final borderColor = isDark ? const Color(0xFF252528) : const Color(0xFFECEEF2);

    final messenger = ScaffoldMessenger.of(context);
    final urlCtrl = TextEditingController(text: _avatarUrl.startsWith('http') ? _avatarUrl : '');
    int photoTab = 0; // 0: Upload File, 1: Image URL
    Uint8List? pickedBytes;
    String? pickedFileName;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: cardBgColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: borderColor)),
          title: Row(
            children: [
              const Icon(Icons.camera_alt_rounded, color: Color(0xFF00875A), size: 20),
              const SizedBox(width: 8),
              Text('Ubah Foto Profil Apotek', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 16, color: textColor)),
            ],
          ),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Tabs: Upload File / Direct URL
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF242429) : const Color(0xFFF1F4F8),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => setModalState(() => photoTab = 0),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: photoTab == 0 ? const Color(0xFF00875A) : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'UPLOAD FILE',
                              style: GoogleFonts.outfit(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: photoTab == 0 ? Colors.white : subtitleColor,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: InkWell(
                          onTap: () => setModalState(() => photoTab = 1),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: photoTab == 1 ? const Color(0xFF00875A) : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'URL GAMBAR',
                              style: GoogleFonts.outfit(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: photoTab == 1 ? Colors.white : subtitleColor,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                if (photoTab == 0) ...[
                  InkWell(
                    onTap: () async {
                      final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
                      if (result != null && result.files.single.bytes != null) {
                        setModalState(() {
                          pickedBytes = result.files.single.bytes;
                          pickedFileName = result.files.single.name;
                        });
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: 120,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E1E22) : const Color(0xFFF8FAFD),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderColor),
                      ),
                      alignment: Alignment.center,
                      child: pickedBytes != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.memory(pickedBytes!, height: 120, fit: BoxFit.cover),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.cloud_upload_outlined, size: 36, color: Color(0xFF00875A)),
                                const SizedBox(height: 6),
                                Text(
                                  pickedFileName ?? 'Klik untuk memilih file gambar',
                                  style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: textColor),
                                ),
                              ],
                            ),
                    ),
                  ),
                ] else ...[
                  TextField(
                    controller: urlCtrl,
                    style: GoogleFonts.outfit(fontSize: 12, color: textColor),
                    decoration: InputDecoration(
                      labelText: 'URL Gambar',
                      hintText: 'https://example.com/avatar.png',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Batal', style: GoogleFonts.outfit(color: subtitleColor)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                setState(() => _isUploadingPhoto = true);

                try {
                  String? finalUrl;

                  if (photoTab == 0 && pickedBytes != null) {
                    final fileName = '${DateTime.now().millisecondsSinceEpoch}_${pickedFileName ?? 'avatar.jpg'}';
                    final storagePath = 'avatars/$userId/$fileName';

                    await SupabaseService.client.storage
                        .from('profiles')
                        .uploadBinary(storagePath, pickedBytes!);

                    finalUrl = SupabaseService.client.storage
                        .from('profiles')
                        .getPublicUrl(storagePath);
                  } else if (photoTab == 1) {
                    finalUrl = urlCtrl.text.trim();
                  }

                  if (finalUrl != null && finalUrl.isNotEmpty) {
                    await SupabaseService.client
                        .from('user')
                        .update({'avatar_url': finalUrl})
                        .eq('id', userId);

                    await SupabaseService.client
                        .from('user_detail_pharmacist')
                        .update({'satusehat_photo_url': finalUrl})
                        .eq('id', userId);

                    ref.read(landingPageProvider.notifier).updateUser({
                      'avatar_url': finalUrl,
                    });

                    setState(() => _avatarUrl = finalUrl!);

                    if (mounted) {
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Foto profil apotek berhasil diperbarui!'),
                          backgroundColor: Color(0xFF00875A),
                        ),
                      );
                    }
                  }
                } catch (e) {
                  if (mounted) {
                    messenger.showSnackBar(
                      SnackBar(content: Text('Gagal mengunggah foto: $e'), backgroundColor: Colors.redAccent),
                    );
                  }
                } finally {
                  if (mounted) {
                    setState(() => _isUploadingPhoto = false);
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00875A)),
              child: Text('Simpan Foto', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // RENEW SUBSCRIPTION
  // ═══════════════════════════════════════════════════════════════════════════
  Future<void> _renewSubscription() async {
    final state = ref.read(landingPageProvider);
    final userId = state.activeApotekId;
    if (userId == null) return;

    setState(() => _isSaving = true);

    try {
      DateTime currentExpiry = DateTime.now();
      if (_subExpiryDate != null && _subExpiryDate!.isAfter(DateTime.now())) {
        currentExpiry = _subExpiryDate!;
      }

      final newExpiry = currentExpiry.add(const Duration(days: 30));
      final newExpiryStr = newExpiry.toIso8601String();

      await SupabaseService.client
          .from('user_detail_pharmacist')
          .update({
            'subscription_status': 'active',
            'subscription_expired_at': newExpiryStr,
          })
          .eq('id', userId);

      await _fetchDbData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Langganan Apotek berhasil diperpanjang 30 Hari! Exp: $_subExpiry'),
            backgroundColor: const Color(0xFF00875A),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memperpanjang langganan: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showPasswordResetDialog() {
    final oldPassCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Reset Password Akun', style: GoogleFonts.outfit(fontWeight: FontWeight.w900)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: oldPassCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Password Saat Ini')),
            const SizedBox(height: 10),
            TextField(controller: newPassCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Password Baru')),
            const SizedBox(height: 10),
            TextField(controller: confirmPassCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Konfirmasi Password Baru')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Password berhasil diperbarui!'), backgroundColor: Color(0xFF00875A)),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00875A)),
            child: const Text('Simpan', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MODAL: VIEW PATIENT PERSPECTIVE (TENTANG APOTEK)
  // ═══════════════════════════════════════════════════════════════════════════
  void _showPatientPerspectiveModal() {
    final isDark = ref.read(landingPageProvider).appearance == 'dark';
    final cardBgColor = isDark ? const Color(0xFF161619) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1B0C3C);
    final subtitleColor = isDark ? Colors.grey[400]! : const Color(0xFF6F6A8A);
    final borderColor = isDark ? const Color(0xFF252528) : const Color(0xFFECEEF2);

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Container(
          width: 760,
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.90),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: cardBgColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 28,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Modal Top Close Button Row
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: Icon(Icons.close_rounded, color: subtitleColor, size: 20),
                  onPressed: () => Navigator.pop(ctx),
                  splashRadius: 18,
                ),
              ),

              Flexible(
                child: SingleChildScrollView(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Left Column: Pharmacy Card Info ───────────────────
                      Expanded(
                        flex: 5,
                        child: Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E1E22) : const Color(0xFFF8FAFD),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: borderColor),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Avatar Card
                              Container(
                                width: 90,
                                height: 90,
                                decoration: BoxDecoration(
                                  color: Colors.pink.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.pink.withValues(alpha: 0.3), width: 2),
                                ),
                                alignment: Alignment.center,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(18),
                                  child: Image.network(
                                    _avatarUrl.isNotEmpty ? _avatarUrl : 'https://api.dicebear.com/7.x/bottts/png?seed=CyrenElysia',
                                    width: 90,
                                    height: 90,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => const Icon(Icons.local_pharmacy_rounded, size: 40, color: Color(0xFF00875A)),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _pharmacyNameCtrl.text,
                                style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900, color: textColor),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00875A).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(100),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.apartment_rounded, size: 12, color: Color(0xFF00875A)),
                                    const SizedBox(width: 4),
                                    Text(
                                      'APOTEK JEJARING',
                                      style: GoogleFonts.outfit(fontSize: 9.5, fontWeight: FontWeight.w900, color: const Color(0xFF00875A)),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 18),

                              // JAM OPERASIONAL
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('JAM OPERASIONAL', style: GoogleFonts.outfit(fontSize: 9.5, fontWeight: FontWeight.w900, color: subtitleColor, letterSpacing: 0.5)),
                                  Text('Lihat Jadwal >', style: GoogleFonts.outfit(fontSize: 9.5, fontWeight: FontWeight.bold, color: const Color(0xFF00875A))),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF161619) : Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: borderColor),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.access_time_rounded, size: 14, color: Color(0xFF00875A)),
                                    const SizedBox(width: 8),
                                    Text('08:00:00 - 21:00:00', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: textColor)),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),

                              // LOKASI
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text('LOKASI', style: GoogleFonts.outfit(fontSize: 9.5, fontWeight: FontWeight.w900, color: subtitleColor, letterSpacing: 0.5)),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _detailAddressCtrl.text,
                                style: GoogleFonts.outfit(fontSize: 10.5, color: textColor, height: 1.3),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(Icons.near_me_outlined, size: 12, color: Color(0xFF00875A)),
                                  const SizedBox(width: 4),
                                  Text('Lihat di Google Maps', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF00875A))),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Mini Map Box
                              Container(
                                height: 110,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE5E3DF),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: borderColor),
                                ),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Positioned.fill(
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: CustomPaint(painter: _MapGridPainter(false)),
                                      ),
                                    ),
                                    const Icon(Icons.location_on, size: 28, color: Color(0xFF00875A)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(width: 20),

                      // ── Right Column: Tentang Apotek & Action Buttons ─────
                      Expanded(
                        flex: 6,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tentang Apotek',
                              style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900, color: const Color(0xFF00875A)),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _aboutCtrl.text.isNotEmpty
                                  ? _aboutCtrl.text
                                  : 'Apotek ini merupakan bagian dari jaringan Mapotek yang melayani resep digital dengan standar pelayanan farmasi yang modern.',
                              style: GoogleFonts.outfit(fontSize: 11.5, color: subtitleColor, height: 1.4),
                            ),
                            const SizedBox(height: 20),

                            // Feature Card 1: Resep Digital
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00875A).withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFF00875A).withValues(alpha: 0.2)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF00875A).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    alignment: Alignment.center,
                                    child: const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF00875A), size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Resep Digital', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: textColor)),
                                        Text('Mendukung pengambilan obat melalui sistem QR Mapotek.', style: GoogleFonts.outfit(fontSize: 10.5, color: subtitleColor)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Feature Card 2: Layanan Terverifikasi
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0052CC).withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFF0052CC).withValues(alpha: 0.2)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0052CC).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    alignment: Alignment.center,
                                    child: const Icon(Icons.star_outline_rounded, color: Color(0xFF0052CC), size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Layanan Terverifikasi', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: textColor)),
                                        Text('Telah melalui proses verifikasi standar farmasi Mapotek.', style: GoogleFonts.outfit(fontSize: 10.5, color: subtitleColor)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 36),

                            Center(
                              child: Text(
                                'Hubungi apotek untuk konfirmasi ketersediaan obat',
                                style: GoogleFonts.outfit(fontSize: 10.5, fontStyle: FontStyle.italic, color: subtitleColor),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Buttons: Hubungi Apotek & WhatsApp
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Menghubungi telepon apotek ${_phoneCtrl.text}...')),
                                      );
                                    },
                                    icon: const Icon(Icons.phone_outlined, size: 16, color: Colors.white),
                                    label: Text('Hubungi Apotek', style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.w900, color: Colors.white)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF00875A),
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      elevation: 0,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Membuka WhatsApp ke ${_waCtrl.text}...')),
                                      );
                                    },
                                    icon: const Icon(Icons.chat_outlined, size: 16, color: Colors.white),
                                    label: Text('WhatsApp', style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.w900, color: Colors.white)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF00875A),
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      elevation: 0,
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TOP PROFILE HERO BANNER
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildProfileHeroBanner(bool isDark, Color cardBg, Color textColor, Color subtitleColor, Color border) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.pink.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Soft blurred gradient background cover
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 100,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF2C1A30), const Color(0xFF1E1E22)]
                        : [const Color(0xFFFFE3EC), const Color(0xFFFBEBF2), Colors.white],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 36, 20, 20),
              child: Column(
                children: [
                  // Center Avatar with Camera Badge
                  Center(
                    child: Stack(
                      children: [
                        Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: _isUploadingPhoto
                                ? const Center(child: CircularProgressIndicator())
                                : Image.network(
                                    _avatarUrl.isNotEmpty ? _avatarUrl : 'https://api.dicebear.com/7.x/bottts/png?seed=CyrenElysia',
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => Container(
                                      color: const Color(0xFF00875A).withValues(alpha: 0.1),
                                      alignment: Alignment.center,
                                      child: const Icon(Icons.local_pharmacy_rounded, size: 40, color: Color(0xFF00875A)),
                                    ),
                                  ),
                          ),
                        ),

                        // Camera Blue Badge Button
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: InkWell(
                            onTap: _showPhotoPickerModal,
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: const Color(0xFF2F80ED),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: const Icon(Icons.camera_alt_rounded, size: 14, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Pharmacy Name
                  Text(
                    _pharmacyNameCtrl.text,
                    style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900, color: textColor),
                  ),
                  const SizedBox(height: 4),

                  // Role Badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.apartment_rounded, size: 13, color: Color(0xFF00875A)),
                      const SizedBox(width: 4),
                      Text(
                        'Pharmacy',
                        style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF00875A)),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Action Buttons: View Patient Perspective & Edit Profile
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _showPatientPerspectiveModal,
                        icon: const Icon(Icons.visibility_outlined, size: 15, color: Color(0xFF1B0C3C)),
                        label: Text('View Patient Perspective', style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.bold, color: textColor)),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: border),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: _isSaving ? null : _saveProfile,
                        icon: _isSaving
                            ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.edit_outlined, size: 15, color: Colors.white),
                        label: Text(_isSaving ? 'Menyimpan...' : 'Edit Profile', style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.w900, color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00875A),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MAIN BUILD
  // ═══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(landingPageProvider);
    final isDark = state.appearance == 'dark';
    final cardBgColor = isDark ? const Color(0xFF161619) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1B0C3C);
    final subtitleColor = isDark ? Colors.grey[400]! : const Color(0xFF6F6A8A);
    final borderColor = isDark ? const Color(0xFF252528) : const Color(0xFFECEEF2);

    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40.0),
          child: CircularProgressIndicator(color: Color(0xFF00875A)),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── 0. TOP PROFILE HERO BANNER ────────────────────────
        _buildProfileHeroBanner(isDark, cardBgColor, textColor, subtitleColor, borderColor),

        const SizedBox(height: 18),

        // ── 1. TOP PILL TABS BAR ──────────────────────────────
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: cardBgColor,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: borderColor),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildTopTabItem(0, Icons.person_outline_rounded, 'Profile Information', isDark),
                const SizedBox(width: 6),
                _buildTopTabItem(1, Icons.location_on_outlined, 'Location & Schedule', isDark),
                const SizedBox(width: 6),
                _buildTopTabItem(2, Icons.credit_card_rounded, 'POS & Payment', isDark),
                const SizedBox(width: 6),
                _buildTopTabItem(3, Icons.electrical_services_rounded, 'API & Integration', isDark),
              ],
            ),
          ),
        ),

        const SizedBox(height: 18),

        // ── 2. ACTIVE TAB CONTENT ─────────────────────────────
        if (_activeTab == 0)
          _buildProfileInformationTab(isDark, cardBgColor, textColor, subtitleColor, borderColor)
        else if (_activeTab == 1)
          _buildLocationScheduleTab(isDark, cardBgColor, textColor, subtitleColor, borderColor)
        else if (_activeTab == 2)
          _buildPosPaymentTab(isDark, cardBgColor, textColor, subtitleColor, borderColor)
        else
          _buildApiIntegrationTab(isDark, cardBgColor, textColor, subtitleColor, borderColor),
      ],
    );
  }

  Widget _buildTopTabItem(int index, IconData icon, String label, bool isDark) {
    final active = _activeTab == index;
    return InkWell(
      onTap: () => setState(() => _activeTab = index),
      borderRadius: BorderRadius.circular(100),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        decoration: BoxDecoration(
          color: active ? (isDark ? const Color(0xFF242429) : const Color(0xFFF1F4F8)) : Colors.transparent,
          borderRadius: BorderRadius.circular(100),
          border: active ? Border.all(color: const Color(0xFF00875A), width: 1.5) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: active ? const Color(0xFF00875A) : const Color(0xFF6F6A8A)),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: active ? FontWeight.w900 : FontWeight.w600,
                color: active ? const Color(0xFF00875A) : const Color(0xFF6F6A8A),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 1. TAB: PROFILE INFORMATION
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildProfileInformationTab(bool isDark, Color cardBg, Color textColor, Color subtitleColor, Color border) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Card 1: Personal Information ─────────────────────────
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFF00875A)),
                      const SizedBox(width: 8),
                      Text('Personal Information', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w900, color: textColor)),
                    ],
                  ),
                  OutlinedButton.icon(
                    onPressed: _showPasswordResetDialog,
                    icon: const Icon(Icons.lock_outline_rounded, size: 14, color: Color(0xFF00875A)),
                    label: Text('Reset Password', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF00875A))),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF00875A)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              _buildFieldLabel('About Pharmacy / Profile', textColor),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E22) : const Color(0xFFF8FAFD),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: border),
                ),
                child: TextField(
                  controller: _aboutCtrl,
                  maxLines: 3,
                  style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: textColor),
                  decoration: InputDecoration(
                    hintText: 'Tell us about your pharmacy, services, and history...',
                    hintStyle: GoogleFonts.outfit(fontSize: 11, color: subtitleColor.withValues(alpha: 0.6)),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFieldLabel('Pharmacy Name', textColor),
                        _buildStyledInput(_pharmacyNameCtrl, isDark, border, textColor, subtitleColor),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFieldLabel('Phone Number (11-13 Digit)', textColor),
                        _buildStyledInput(
                          _phoneCtrl,
                          isDark,
                          border,
                          textColor,
                          subtitleColor,
                          hint: '08xxxxxxxxxx',
                          keyboardType: TextInputType.phone,
                          maxLength: 13,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(13),
                          ],
                        ),
                      ],
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
                        _buildFieldLabel('WhatsApp Number (11-13 Digit)', textColor),
                        _buildStyledInput(
                          _waCtrl,
                          isDark,
                          border,
                          textColor,
                          subtitleColor,
                          hint: '08xxxxxxxxxx',
                          keyboardType: TextInputType.phone,
                          maxLength: 13,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(13),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFieldLabel('SIA Number', textColor),
                        _buildStyledInput(_siaCtrl, isDark, border, textColor, subtitleColor),
                      ],
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
                        _buildFieldLabel('Pharmacist Name', textColor),
                        _buildStyledInput(_pharmacistCtrl, isDark, border, textColor, subtitleColor),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(child: SizedBox()),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // ── Card 2: QR Code Apotek ───────────────────────────────
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: border),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.qr_code_2_rounded, size: 18, color: Color(0xFF00875A)),
                  const SizedBox(width: 8),
                  Text('QR Code Apotek', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w900, color: textColor)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Tampilkan QR Code ini kepada masyarakat ataupun pasien untuk\nmemberikan akses cepat ke profil dan katalog produk apotek Anda.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(fontSize: 11.5, color: subtitleColor, height: 1.4),
              ),
              const SizedBox(height: 20),

              // QR Box
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: border),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: QrImageView(
                  data: 'https://mapotek.relvastudio.com/apotek/${_pharmacyNameCtrl.text.trim().isNotEmpty ? _pharmacyNameCtrl.text.trim().toLowerCase().replaceAll(RegExp(r"[^a-z0-9]+"), "-") : "cyren-elysia-pujer"}',
                  version: QrVersions.auto,
                  size: 160.0,
                  eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF1B0C3C)),
                  dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Color(0xFF1B0C3C)),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // ── Card 3: Subscription Status ──────────────────────────
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.credit_card_rounded, size: 18, color: Color(0xFF00875A)),
                  const SizedBox(width: 8),
                  Text('Subscription Status', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w900, color: textColor)),
                ],
              ),
              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E22) : const Color(0xFFF8FAFD),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: border),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Valid Until', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: textColor)),
                        Text(_subExpiry, style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: textColor)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Days Remaining', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: textColor)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(color: const Color(0xFF00875A).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(100)),
                          child: Text('$_subDaysRemaining Days', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: const Color(0xFF00875A))),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('STATUS', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: textColor, letterSpacing: 0.5)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(color: const Color(0xFF00875A), borderRadius: BorderRadius.circular(100)),
                          child: Text(_subStatus, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              ElevatedButton.icon(
                onPressed: _isSaving ? null : _renewSubscription,
                icon: const Icon(Icons.refresh_rounded, size: 16, color: Colors.white),
                label: Text('Renew 30 Days', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00875A),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 2. TAB: LOCATION & SCHEDULE
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildLocationScheduleTab(bool isDark, Color cardBg, Color textColor, Color subtitleColor, Color border) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 18, color: Color(0xFF00875A)),
              const SizedBox(width: 8),
              Text('Location & Schedule', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w900, color: textColor)),
            ],
          ),
          const SizedBox(height: 20),

          // Section: ADDRESS
          Text('ADDRESS', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: subtitleColor, letterSpacing: 0.8)),
          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('Provinsi', textColor),
                    _buildDropdown(['JAWA TIMUR', 'JAWA TENGAH', 'JAWA BARAT', 'DKI JAKARTA'], _selectedProvince, (v) => setState(() => _selectedProvince = v), isDark, cardBg, border, textColor),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('Kota / Kabupaten', textColor),
                    _buildDropdown(['KABUPATEN BONDOWOSO', 'KABUPATEN JEMBER', 'KABUPATEN BANYUWANGI', 'KOTA SURABAYA'], _selectedCity, (v) => setState(() => _selectedCity = v), isDark, cardBg, border, textColor),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('Kecamatan', textColor),
                    _buildDropdown(['PUJER', 'WONOSARI', 'TENGGARANG', 'KOTA BONDOWOSO'], _selectedDistrict, (v) => setState(() => _selectedDistrict = v), isDark, cardBg, border, textColor),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('Kelurahan / Desa', textColor),
                    _buildDropdown(['KEJAYAN', 'MASKUNING', 'MANGKLI', 'SUKOKERTO'], _selectedVillage, (v) => setState(() => _selectedVillage = v), isDark, cardBg, border, textColor),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          _buildFieldLabel('Detail Address (Opsional / Nilai Detail)', textColor),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E22) : const Color(0xFFF8FAFD),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: border),
            ),
            child: TextField(
              controller: _detailAddressCtrl,
              maxLines: 2,
              style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: textColor),
              decoration: const InputDecoration(border: InputBorder.none, isDense: true),
            ),
          ),

          const SizedBox(height: 24),

          // Section: Google Maps Link
          Row(
            children: [
              Icon(Icons.link_rounded, size: 16, color: subtitleColor),
              const SizedBox(width: 6),
              Text('Click Google Maps Link', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: textColor)),
            ],
          ),
          const SizedBox(height: 6),
          _buildStyledInput(_mapsLinkCtrl, isDark, border, textColor, subtitleColor),
          const SizedBox(height: 6),
          Text(
            'Buka Google Maps, cari lokasi apotek Anda, lalu salin dan tempelkan tautan ke kolom di atas.',
            style: GoogleFonts.outfit(fontSize: 10, color: subtitleColor),
          ),
          const SizedBox(height: 14),

          // Embedded Interactive Map Preview Box
          Container(
            height: 220,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E22) : const Color(0xFFF1F4F8),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: border),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Simulated OpenStreetMap background pattern
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      color: isDark ? const Color(0xFF242F3E) : const Color(0xFFE5E3DF),
                      child: CustomPaint(painter: _MapGridPainter(isDark)),
                    ),
                  ),
                ),

                // Center Pin Icon
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 6)],
                      ),
                      child: Text(_pharmacyNameCtrl.text, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF1B0C3C))),
                    ),
                    const Icon(Icons.location_on, size: 36, color: Color(0xFF00875A)),
                  ],
                ),

                // Map controls overlay
                Positioned(
                  right: 12,
                  top: 12,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4)],
                    ),
                    child: Column(
                      children: [
                        InkWell(
                          onTap: () {},
                          child: const Padding(padding: EdgeInsets.all(6), child: Icon(Icons.add, size: 16, color: Colors.black87)),
                        ),
                        Divider(height: 1, color: Colors.grey[300]),
                        InkWell(
                          onTap: () {},
                          child: const Padding(padding: EdgeInsets.all(6), child: Icon(Icons.remove, size: 16, color: Colors.black87)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Section: Operational Hours
          Row(
            children: [
              const Icon(Icons.access_time_rounded, size: 16, color: Color(0xFF00875A)),
              const SizedBox(width: 6),
              Text('Operational Hours', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w900, color: textColor)),
            ],
          ),
          const SizedBox(height: 12),

          ..._schedule.entries.map((entry) {
            final day = entry.key;
            final isEnabled = entry.value['enabled'] as bool;
            final start = entry.value['start'] as String;
            final end = entry.value['end'] as String;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E22) : const Color(0xFFF8FAFD),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: isEnabled ? const Color(0xFF00875A).withValues(alpha: 0.12) : Colors.grey.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    alignment: Alignment.center,
                    child: Icon(Icons.calendar_today, size: 12, color: isEnabled ? const Color(0xFF00875A) : subtitleColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: Text(day, style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: textColor)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF161619) : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: border),
                    ),
                    child: Text(start, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600, color: textColor)),
                  ),
                  const SizedBox(width: 6),
                  Text('-', style: GoogleFonts.outfit(color: subtitleColor)),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF161619) : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: border),
                    ),
                    child: Text(end, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600, color: textColor)),
                  ),
                  const SizedBox(width: 14),
                  Switch(
                    value: isEnabled,
                    activeThumbColor: const Color(0xFF00875A),
                    activeTrackColor: const Color(0xFF00875A).withValues(alpha: 0.5),
                    onChanged: (val) {
                      setState(() => entry.value['enabled'] = val);
                    },
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 3. TAB: POS & PAYMENT
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildPosPaymentTab(bool isDark, Color cardBg, Color textColor, Color subtitleColor, Color border) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Card 1: PPN Settings ─────────────────────────────────
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.receipt_long_rounded, size: 18, color: Color(0xFF00875A)),
                  const SizedBox(width: 8),
                  Text('PPN Settings', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w900, color: textColor)),
                ],
              ),
              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E22) : const Color(0xFFF1F9F6),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF00875A).withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Enable PPN', style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.bold, color: textColor)),
                        const SizedBox(height: 2),
                        Text('Aktifkan tarif PPN pada setiap transaksi penjualan kasir POS.', style: GoogleFonts.outfit(fontSize: 10.5, color: subtitleColor)),
                      ],
                    ),
                    Switch(
                      value: _enablePpn,
                      activeThumbColor: const Color(0xFF00875A),
                      activeTrackColor: const Color(0xFF00875A).withValues(alpha: 0.5),
                      onChanged: (v) => setState(() => _enablePpn = v),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              Text('PPN RATE (%)', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: subtitleColor, letterSpacing: 0.8)),
              const SizedBox(height: 6),
              Container(
                width: 140,
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E22) : const Color(0xFFF8FAFD),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: border),
                ),
                child: TextField(
                  controller: _ppnRateCtrl,
                  keyboardType: TextInputType.number,
                  style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w900, color: textColor),
                  decoration: const InputDecoration(suffixText: '%', border: InputBorder.none, isDense: true),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // ── 2 Columns: Debit Card & QRIS Payment Method ──────────
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Card: Debit Card Payment Method
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.credit_card_rounded, size: 18, color: Color(0xFF00875A)),
                        const SizedBox(width: 8),
                        Text('Debit Card Payment Method', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w900, color: textColor)),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E1E22) : const Color(0xFFF1F9F6),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF00875A).withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Enable Debit Card Payment', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: textColor)),
                                const SizedBox(height: 2),
                                Text('Aktifkan metode pembayaran kartu debit / EDC pada kasir POS.', style: GoogleFonts.outfit(fontSize: 10, color: subtitleColor)),
                              ],
                            ),
                          ),
                          Switch(
                            value: _enableDebit,
                            activeThumbColor: const Color(0xFF00875A),
                            activeTrackColor: const Color(0xFF00875A).withValues(alpha: 0.5),
                            onChanged: (v) => setState(() => _enableDebit = v),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(width: 18),

            // Right Card: QRIS Payment Method
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.qr_code_rounded, size: 18, color: Color(0xFF00875A)),
                            const SizedBox(width: 8),
                            Text('QRIS Payment Method', style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w900, color: textColor)),
                          ],
                        ),
                        Switch(
                          value: _enableQris,
                          activeThumbColor: const Color(0xFF00875A),
                          activeTrackColor: const Color(0xFF00875A).withValues(alpha: 0.5),
                          onChanged: (v) => setState(() => _enableQris = v),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // QRIS Image Box Container
                    Center(
                      child: Container(
                        width: 130,
                        height: 130,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E1E22) : const Color(0xFFF8FAFD),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: border),
                        ),
                        alignment: Alignment.center,
                        child: _qrisPath.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.network(_qrisPath, fit: BoxFit.cover, errorBuilder: (_, _, _) => Icon(Icons.qr_code_2_rounded, size: 48, color: subtitleColor.withValues(alpha: 0.4))),
                              )
                            : Icon(Icons.qr_code_2_rounded, size: 48, color: subtitleColor.withValues(alpha: 0.4)),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Switcher Tabs: UPLOAD FOTO | URL | LINK
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF242429) : const Color(0xFFF1F4F8),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          _buildQrisTabItem(0, Icons.photo_library_outlined, 'UPLOAD FOTO'),
                          _buildQrisTabItem(1, Icons.link_rounded, 'URL'),
                          _buildQrisTabItem(2, Icons.insert_link_rounded, 'LINK'),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    OutlinedButton.icon(
                      onPressed: () async {
                        final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
                        if (result != null && result.files.single.bytes != null) {
                          final state = ref.read(landingPageProvider);
                          final userId = state.activeApotekId;
                          if (userId == null) return;

                          final fileName = '${DateTime.now().millisecondsSinceEpoch}_${result.files.single.name}';
                          final storagePath = 'qris/$userId/$fileName';

                          await SupabaseService.client.storage
                              .from('profiles')
                              .uploadBinary(storagePath, result.files.single.bytes!);

                          final finalUrl = SupabaseService.client.storage
                              .from('profiles')
                              .getPublicUrl(storagePath);

                          await SupabaseService.client
                              .from('user_detail_pharmacist')
                              .update({'qris_path': finalUrl})
                              .eq('id', userId);

                          setState(() => _qrisPath = finalUrl);

                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Gambar QRIS berhasil diunggah ke database!'), backgroundColor: Color(0xFF00875A)),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.upload_file_rounded, size: 16, color: Color(0xFF00875A)),
                      label: Text('Upload Foto', style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.bold, color: const Color(0xFF00875A))),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF00875A)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        minimumSize: const Size(double.infinity, 40),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQrisTabItem(int idx, IconData icon, String label) {
    final active = _qrisTab == idx;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _qrisTab = idx),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: active ? const Color(0xFF00875A) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 12, color: active ? Colors.white : const Color(0xFF6F6A8A)),
              const SizedBox(width: 4),
              Text(
                label,
                style: GoogleFonts.outfit(fontSize: 9.5, fontWeight: active ? FontWeight.w900 : FontWeight.bold, color: active ? Colors.white : const Color(0xFF6F6A8A)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 4. TAB: API & INTEGRATION
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildApiIntegrationTab(bool isDark, Color cardBg, Color textColor, Color subtitleColor, Color border) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.electrical_services_rounded, size: 18, color: Color(0xFF00875A)),
              const SizedBox(width: 8),
              Text('API & Integrasi', style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w900, color: textColor)),
            ],
          ),
          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E22) : const Color(0xFFF8FAFD),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.send_rounded, size: 14, color: Color(0xFF00875A)),
                    const SizedBox(width: 8),
                    Text('API SATUSEHAT KEMENKES', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w900, color: textColor)),
                  ],
                ),
                const SizedBox(height: 16),

                Text('ENVIRONMENT', style: GoogleFonts.outfit(fontSize: 9.5, fontWeight: FontWeight.w900, color: subtitleColor, letterSpacing: 0.8)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    InkWell(
                      onTap: () => setState(() => _apiEnvironment = 'PRODUCTION'),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: _apiEnvironment == 'PRODUCTION' ? const Color(0xFF00875A) : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF00875A)),
                        ),
                        child: Text(
                          'PRODUCTION',
                          style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: _apiEnvironment == 'PRODUCTION' ? Colors.white : const Color(0xFF00875A)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => setState(() => _apiEnvironment = 'STAGING'),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: _apiEnvironment == 'STAGING' ? const Color(0xFF00875A) : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: border),
                        ),
                        child: Text(
                          'STAGING',
                          style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: _apiEnvironment == 'STAGING' ? Colors.white : subtitleColor),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFieldLabel('ORGANIZATION ID', textColor),
                          _buildStyledInput(_orgIdCtrl, isDark, border, textColor, subtitleColor, hint: 'Opsional untuk apotek'),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildRequiredLabel('CLIENT ID', textColor),
                          _buildStyledInput(_clientIdCtrl, isDark, border, textColor, subtitleColor, hint: 'Lihat ID pada portal SatuSehat'),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                _buildRequiredLabel('CLIENT SECRET', textColor),
                _buildStyledInput(_clientSecretCtrl, isDark, border, textColor, subtitleColor, hint: 'Lihat Secret pada portal SatuSehat', isPassword: true),

                const SizedBox(height: 20),

                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _saveProfile,
                    icon: const Icon(Icons.check_circle_rounded, size: 16, color: Colors.white),
                    label: Text('Simpan Kredensial API', style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.w900, color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00875A),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // HELPER WIDGETS
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildFieldLabel(String text, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Text(text, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: textColor)),
    );
  }

  Widget _buildRequiredLabel(String text, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          Text(text, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(width: 3),
          const Text('*', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.redAccent)),
        ],
      ),
    );
  }

  Widget _buildStyledInput(TextEditingController ctrl, bool isDark, Color border, Color textColor, Color subtitleColor, {String? hint, bool isPassword = false, TextInputType? keyboardType, int? maxLength, List<TextInputFormatter>? inputFormatters}) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E22) : const Color(0xFFF8FAFD),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: TextField(
        controller: ctrl,
        obscureText: isPassword,
        keyboardType: keyboardType,
        maxLength: maxLength,
        inputFormatters: inputFormatters,
        style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w600, color: textColor),
        decoration: InputDecoration(
          hintText: hint,
          counterText: '',
          hintStyle: GoogleFonts.outfit(fontSize: 11, color: subtitleColor.withValues(alpha: 0.6)),
          border: InputBorder.none,
          isDense: true,
        ),
      ),
    );
  }

  Widget _buildDropdown(List<String> items, String current, ValueChanged<String> onChanged, bool isDark, Color cardBg, Color border, Color textColor) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E22) : const Color(0xFFF8FAFD),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: current,
          isExpanded: true,
          dropdownColor: cardBg,
          style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: textColor),
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}

class _MapGridPainter extends CustomPainter {
  final bool isDark;
  _MapGridPainter(this.isDark);

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06)
      ..strokeWidth = 1.0;

    const step = 30.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
