import 'package:flutter/services.dart';
import 'dart:ui' show ImageFilter;
import 'dart:io' as io;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mapotech/features/landing/landing_page_data.dart';
import 'package:mapotech/shared/supabase_service.dart';
import 'package:mapotech/features/pasien/dashboard/frontend/pasien_dokter_search.dart';
import 'package:mapotech/shared/widgets/skeleton_loading.dart';
import 'package:mapotech/shared/widgets/location_selector_widget.dart';
import 'package:mapotech/features/dokter/dashboard/frontend/web_map_widget.dart';
import 'package:mapotech/shared/widgets/animated_transitions.dart';
import 'package:mapotech/shared/widgets/revgeo_wilayah_map_widget.dart';
import 'package:image/image.dart' as img;
import 'package:mapotech/features/puskesmas/dlc/vitascale/vitascale_dlc_gate.dart';

class PuskesmasProfile extends ConsumerStatefulWidget {
  final ValueChanged<String>? onNavigate;
  const PuskesmasProfile({super.key, this.onNavigate});

  @override
  ConsumerState<PuskesmasProfile> createState() => _PuskesmasProfileState();
}

class _PuskesmasProfileState extends ConsumerState<PuskesmasProfile> {
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploadingPhoto = false;
  int _activeTab = 0; // 0 = Profile & Info, 1 = Praktik & Layanan, 2 = API & Integrasi, 3 = Modul DLC
  int _activeApiSubTab = 0; // 0 = SatuSehat, 1 = BPJS, 2 = Mobile JKN

  // Profile data state
  String _avatarUrl = '';

  // Controllers
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _faskesController;
  late TextEditingController _aboutController;
  late TextEditingController _addressDetailController;
  late TextEditingController _mapsLinkController;

  // RevGeo API Controller & Territory Map state
  late TextEditingController _revgeoApiUrlController;

  // API Controllers
  late TextEditingController _ssOrgIdController;
  late TextEditingController _ssClientIdController;
  late TextEditingController _ssClientSecretController;
  late TextEditingController _bpjsApiKeyController;
  late TextEditingController _jknApiKeyController;

  // Selected dropdown states
  String _selectedGender = 'Male';
  String _selectedProvinsi = 'JAWA TIMUR';
  String _selectedKabupaten = 'KABUPATEN BONDOWOSO';
  String _selectedKecamatan = 'PUJER';
  String _selectedKelurahan = 'KEJAYAN';
  bool _showProfileInSearch = true;
  bool _serveBPJSPatients = true;
  bool _ssAutoSync = true;

  // Subscription state
  String _subStatus = 'INACTIVE';
  DateTime? _subExpiryDate;
  String _subExpiry = '-';
  int _subDaysRemaining = 0;

  // Schedule operational hours
  final List<Map<String, dynamic>> _scheduleDays = [
    {
      'day': 'Monday',
      'initial': 'M',
      'active': true,
      'start': '08:00 AM',
      'end': '04:00 PM',
    },
    {
      'day': 'Tuesday',
      'initial': 'T',
      'active': true,
      'start': '08:00 AM',
      'end': '04:00 PM',
    },
    {
      'day': 'Wednesday',
      'initial': 'W',
      'active': true,
      'start': '08:00 AM',
      'end': '04:00 PM',
    },
    {
      'day': 'Thursday',
      'initial': 'T',
      'active': true,
      'start': '08:00 AM',
      'end': '04:00 PM',
    },
    {
      'day': 'Friday',
      'initial': 'F',
      'active': true,
      'start': '08:00 AM',
      'end': '02:00 PM',
    },
    {
      'day': 'Saturday',
      'initial': 'S',
      'active': true,
      'start': '08:00 AM',
      'end': '12:00 PM',
    },
    {
      'day': 'Sunday',
      'initial': 'S',
      'active': false,
      'start': '08:00 AM',
      'end': '12:00 PM',
    },
  ];

  final double _zoomLevel = 15.0;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _emailController = TextEditingController();
    _faskesController = TextEditingController();
    _aboutController = TextEditingController();
    _addressDetailController = TextEditingController();
    _mapsLinkController = TextEditingController();
    _revgeoApiUrlController = TextEditingController(
      text: 'https://revgeo.relvastudio.com/',
    );

    _ssOrgIdController = TextEditingController();
    _ssClientIdController = TextEditingController();
    _ssClientSecretController = TextEditingController();
    _bpjsApiKeyController = TextEditingController();
    _jknApiKeyController = TextEditingController();

    _loadProfileData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _faskesController.dispose();
    _aboutController.dispose();
    _addressDetailController.dispose();
    _mapsLinkController.dispose();
    _revgeoApiUrlController.dispose();

    _ssOrgIdController.dispose();
    _ssClientIdController.dispose();
    _ssClientSecretController.dispose();
    _bpjsApiKeyController.dispose();
    _jknApiKeyController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileData() async {
    final state = ref.read(landingPageProvider);
    final userId = state.loggedInUser?['id'];
    if (userId == null) return;

    try {
      final phoneVal = _phoneController.text.trim();
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

      final db = SupabaseService();
      final detail = await db.fetchPuskesmasDetail(userId);

      final user = await SupabaseService.client
          .from('user')
          .select(
            'email, avatar_url, gender, subscription_status, subscription_expires_at',
          )
          .eq('id', userId)
          .maybeSingle();

      // Fetch weekly schedules
      final schedules = await SupabaseService.client
          .from('public_health_center_schedules')
          .select('id, day, open_time, close_time, is_off')
          .eq('id_puskesmas', userId);

      if (schedules.isNotEmpty) {
        for (var dayMap in _scheduleDays) {
          final matchedList = schedules.where(
            (s) =>
                s['day'].toString().toLowerCase() ==
                dayMap['day'].toString().toLowerCase(),
          );
          if (matchedList.isNotEmpty) {
            final matched = matchedList.first;
            dayMap['id'] = matched['id'];
            dayMap['active'] = !(matched['is_off'] as bool? ?? false);
            dayMap['start'] = _parseTimeFromDb(matched['open_time'] as String?);
            dayMap['end'] = _parseTimeFromDb(matched['close_time'] as String?);
          }
        }
      }

      if (mounted) {
        setState(() {
          _nameController.text =
              detail?['facility_name'] ?? state.loggedInName ?? '';
          _faskesController.text =
              detail?['facility_name'] ?? state.loggedInName ?? '';
          _phoneController.text = detail?['phone'] ?? '';
          _emailController.text = user?['email'] ?? '';
          _avatarUrl = user?['avatar_url'] ?? '';
          _selectedGender =
              (user?['gender'] == 'female' || user?['gender'] == 'Female')
              ? 'Female'
              : 'Male';

          _aboutController.text = detail?['about'] ?? '';
          _addressDetailController.text = detail?['address'] ?? '';
          _selectedProvinsi = detail?['province'] ?? 'JAWA TIMUR';
          _selectedKabupaten = detail?['district'] ?? 'KABUPATEN BONDOWOSO';
          _selectedKecamatan = detail?['sub_district'] ?? 'PUJER';
          _selectedKelurahan = detail?['village'] ?? 'KEJAYAN';

          _bpjsApiKeyController.text = detail?['bpjs_api_key'] ?? '';
          _jknApiKeyController.text = detail?['jkn_api_key'] ?? '';
          _ssClientIdController.text = detail?['satusehat_client_id'] ?? '';
          _ssClientSecretController.text =
              detail?['satusehat_client_secret'] ?? '';
          _ssOrgIdController.text = detail?['satusehat_org_id'] ?? '';
          _ssAutoSync = detail?['satusehat_auto_sync'] as bool? ?? true;
          _showProfileInSearch = detail?['is_visible'] as bool? ?? true;
          _serveBPJSPatients = detail?['is_bpjs'] as bool? ?? true;
          _mapsLinkController.text = detail?['google_maps_link'] ?? '';

          if (user != null) {
            _subStatus = (user['subscription_status'] ?? 'INACTIVE')
                .toString()
                .toUpperCase();
            if (user['subscription_expires_at'] != null) {
              try {
                final expiryDate = DateTime.parse(
                  user['subscription_expires_at'].toString(),
                );
                _subExpiryDate = expiryDate;
                const months = [
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
                _subExpiry =
                    '${expiryDate.day.toString().padLeft(2, '0')} ${months[expiryDate.month - 1]} ${expiryDate.year}';

                final now = DateTime.now();
                final diff = expiryDate.difference(now);
                if (diff.isNegative) {
                  _subDaysRemaining = 0;
                } else {
                  _subDaysRemaining = diff.inDays;
                }
              } catch (_) {
                _subExpiry = '-';
                _subExpiryDate = null;
                _subDaysRemaining = 0;
              }
            } else {
              _subExpiry = '-';
              _subExpiryDate = null;
              _subDaysRemaining = 0;
            }
          }
          final bool isSubActive =
              _subStatus == 'ACTIVE' &&
              _subExpiryDate != null &&
              _subExpiryDate!.isAfter(DateTime.now());
          ref.read(landingPageProvider.notifier).setSubscribed(isSubActive);

          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _parseTimeFromDb(String? dbTime) {
    if (dbTime == null || dbTime.isEmpty) return '08:00 AM';
    try {
      final parts = dbTime.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);

      final period = hour >= 12 ? 'PM' : 'AM';
      var displayHour = hour % 12;
      if (displayHour == 0) displayHour = 12;

      final minStr = minute.toString().padLeft(2, '0');
      final hourStr = displayHour.toString().padLeft(2, '0');

      return '$hourStr:$minStr $period';
    } catch (e) {
      return '08:00 AM';
    }
  }

  String _formatTimeToDb(String displayTime) {
    try {
      final clean = displayTime.trim();
      final parts = clean.split(' ');
      if (parts.length != 2) return '08:00:00';

      final timeParts = parts[0].split(':');
      if (timeParts.length != 2) return '08:00:00';

      var hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);
      final period = parts[1].toUpperCase();

      if (period == 'PM' && hour < 12) {
        hour += 12;
      } else if (period == 'AM' && hour == 12) {
        hour = 0;
      }

      final hourStr = hour.toString().padLeft(2, '0');
      final minStr = minute.toString().padLeft(2, '0');

      return '$hourStr:$minStr:00';
    } catch (e) {
      return '08:00:00';
    }
  }

  Future<void> _saveProfileData() async {
    final state = ref.read(landingPageProvider);
    final notifier = ref.read(landingPageProvider.notifier);
    final userId = state.loggedInUser?['id'];
    if (userId == null) return;

    setState(() => _isSaving = true);

    try {
      final phoneVal = _phoneController.text.trim();
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

      final db = SupabaseService();

      final detailData = {
        'facility_name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'about': _aboutController.text.trim(),
        'address': _addressDetailController.text.trim(),
        'province': _selectedProvinsi,
        'district': _selectedKabupaten,
        'sub_district': _selectedKecamatan,
        'village': _selectedKelurahan,
        'google_maps_link': _mapsLinkController.text.trim(),
        'bpjs_api_key': _bpjsApiKeyController.text.trim(),
        'jkn_api_key': _jknApiKeyController.text.trim(),
        'satusehat_client_id': _ssClientIdController.text.trim(),
        'satusehat_client_secret': _ssClientSecretController.text.trim(),
        'satusehat_org_id': _ssOrgIdController.text.trim(),
        'satusehat_auto_sync': _ssAutoSync,
        'is_visible': _showProfileInSearch,
        'is_bpjs': _serveBPJSPatients,
      };

      await db.savePuskesmasDetail(userId, detailData);

      // Update user table
      await SupabaseService.client
          .from('user')
          .update({
            'name': _nameController.text.trim(),
            'gender': _selectedGender.toLowerCase(),
          })
          .eq('id', userId);

      notifier.updateUser({'name': _nameController.text.trim()});

      // Save schedules
      final schedulesToUpsert = <Map<String, dynamic>>[];
      for (var dayMap in _scheduleDays) {
        final item = <String, dynamic>{
          'id_puskesmas': userId,
          'day': dayMap['day'],
          'open_time': dayMap['active'] == true
              ? _formatTimeToDb(dayMap['start'] as String)
              : null,
          'close_time': dayMap['active'] == true
              ? _formatTimeToDb(dayMap['end'] as String)
              : null,
          'is_off': !(dayMap['active'] as bool),
        };
        if (dayMap['id'] != null) {
          item['id'] = dayMap['id'];
        }
        schedulesToUpsert.add(item);
      }

      bool hasAllIds = _scheduleDays.every((d) => d['id'] != null);
      if (hasAllIds) {
        await SupabaseService.client
            .from('public_health_center_schedules')
            .upsert(schedulesToUpsert);
      } else {
        await SupabaseService.client
            .from('public_health_center_schedules')
            .delete()
            .eq('id_puskesmas', userId);

        final freshInsert = schedulesToUpsert.map((item) {
          final copy = Map<String, dynamic>.from(item);
          copy.remove('id');
          return copy;
        }).toList();

        await SupabaseService.client
            .from('public_health_center_schedules')
            .insert(freshInsert);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: notifier.getPrimaryColor(),
            content: Text(
              state.language == 'id'
                  ? 'Profil berhasil disimpan!'
                  : 'Profile saved successfully!',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text(
              state.language == 'id'
                  ? 'Gagal menyimpan profil: $e'
                  : 'Failed to save profile: $e',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Uint8List _cropImageToSquare(Uint8List originalBytes) {
    try {
      final image = img.decodeImage(originalBytes);
      if (image == null) return originalBytes;
      final size = image.width < image.height ? image.width : image.height;
      final x = (image.width - size) ~/ 2;
      final y = (image.height - size) ~/ 2;
      final cropped = img.copyCrop(
        image,
        x: x,
        y: y,
        width: size,
        height: size,
      );
      return Uint8List.fromList(img.encodeJpg(cropped, quality: 85));
    } catch (e) {
      return originalBytes;
    }
  }

  Future<void> _uploadProfilePhoto() async {
    final state = ref.read(landingPageProvider);
    final userId = state.loggedInUser?['id'];
    if (userId == null) return;

    final TextEditingController urlController = TextEditingController();
    Uint8List? selectedFileBytes;
    String? selectedFileName;
    String activeUploadTab = 'upload'; // 'upload' or 'link'
    bool isProcessingImage = false;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final Color tealColor = themeAccentColor();
            final Color cardBg = const Color(0xFF1E1E22);
            final Color inputBg = const Color(0xFF2A2A30);

            return AlertDialog(
              backgroundColor: cardBg,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Icon(Icons.add_a_photo_rounded, color: tealColor),
                  const SizedBox(width: 8),
                  Text(
                    state.language == 'id'
                        ? 'Update Foto Profil'
                        : 'Update Profile Photo',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Current Profile Photo Display
                    Center(
                      child: Column(
                        children: [
                          Text(
                            state.language == 'id'
                                ? 'Foto Profil Saat Ini:'
                                : 'Current Profile Photo:',
                            style: GoogleFonts.outfit(
                              color: Colors.grey[400],
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white24,
                                width: 2,
                              ),
                            ),
                            child: ClipOval(
                              child: _avatarUrl.isNotEmpty
                                  ? Image.network(
                                      _avatarUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) =>
                                          const Center(
                                            child: Icon(
                                              Icons.person_rounded,
                                              color: Colors.grey,
                                            ),
                                          ),
                                    )
                                  : const Center(
                                      child: Icon(
                                        Icons.person_rounded,
                                        color: Colors.grey,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Divider(color: Colors.white10),
                    const SizedBox(height: 12),

                    // Tab Bar switcher
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setStateDialog(
                              () => activeUploadTab = 'upload',
                            ),
                            child: Container(
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: activeUploadTab == 'upload'
                                        ? tealColor
                                        : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                              ),
                              child: Text(
                                state.language == 'id'
                                    ? 'Upload File'
                                    : 'Upload File',
                                style: GoogleFonts.outfit(
                                  color: activeUploadTab == 'upload'
                                      ? Colors.white
                                      : Colors.grey[400],
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () =>
                                setStateDialog(() => activeUploadTab = 'link'),
                            child: Container(
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: activeUploadTab == 'link'
                                        ? tealColor
                                        : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                              ),
                              child: Text(
                                state.language == 'id'
                                    ? 'Input Link URL'
                                    : 'Input Link URL',
                                style: GoogleFonts.outfit(
                                  color: activeUploadTab == 'link'
                                      ? Colors.white
                                      : Colors.grey[400],
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    if (activeUploadTab == 'upload') ...[
                      Center(
                        child: Column(
                          children: [
                            Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: inputBg,
                                border: Border.all(
                                  color: tealColor.withValues(alpha: 0.5),
                                  width: 2,
                                ),
                              ),
                              child: ClipOval(
                                child: isProcessingImage
                                    ? Center(
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: tealColor,
                                        ),
                                      )
                                    : selectedFileBytes != null
                                    ? Image.memory(
                                        selectedFileBytes!,
                                        fit: BoxFit.cover,
                                      )
                                    : Center(
                                        child: Icon(
                                          Icons.person_rounded,
                                          size: 60,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: isProcessingImage
                                  ? null
                                  : () async {
                                      try {
                                        final pickerResult = await FilePicker
                                            .platform
                                            .pickFiles(
                                              type: FileType.image,
                                              withData: true,
                                            );
                                        if (pickerResult != null &&
                                            pickerResult.files.isNotEmpty) {
                                          setStateDialog(
                                            () => isProcessingImage = true,
                                          );
                                          await Future.delayed(
                                            const Duration(milliseconds: 100),
                                          );
                                          final pickedFile =
                                              pickerResult.files.first;
                                          Uint8List? bytes = pickedFile.bytes;
                                          if (bytes == null &&
                                              !kIsWeb &&
                                              pickedFile.path != null) {
                                            bytes = io.File(
                                              pickedFile.path!,
                                            ).readAsBytesSync();
                                          }
                                          setStateDialog(() {
                                            selectedFileBytes = bytes;
                                            selectedFileName = pickedFile.name;
                                            isProcessingImage = false;
                                          });
                                        }
                                      } catch (err) {
                                        setStateDialog(
                                          () => isProcessingImage = false,
                                        );
                                      }
                                    },
                              icon: const Icon(
                                Icons.photo_library_rounded,
                                size: 16,
                              ),
                              label: Text(
                                selectedFileBytes == null
                                    ? (state.language == 'id'
                                          ? 'Pilih Gambar'
                                          : 'Choose Image')
                                    : (state.language == 'id'
                                          ? 'Ganti Gambar'
                                          : 'Change Image'),
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2E4053),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                            ),
                            if (selectedFileName != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                selectedFileName!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(
                                  color: Colors.grey[400],
                                  fontSize: 11,
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            Text(
                              state.language == 'id'
                                  ? 'Pilih file gambar lokal Anda untuk menyesuaikan foto profil.'
                                  : 'Select your local image file to adjust your profile photo.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(
                                color: Colors.grey[400],
                                fontSize: 11,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      Text(
                        state.language == 'id'
                            ? 'Masukkan URL link gambar foto profil:'
                            : 'Enter profile photo image URL:',
                        style: GoogleFonts.outfit(
                          color: Colors.grey[300],
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: urlController,
                        onChanged: (val) => setStateDialog(() {}),
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                        decoration: InputDecoration(
                          hintText: 'https://...',
                          hintStyle: GoogleFonts.outfit(
                            color: Colors.grey[600],
                            fontSize: 13,
                          ),
                          filled: true,
                          fillColor: inputBg,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (urlController.text.trim().isNotEmpty) ...[
                        Center(
                          child: Column(
                            children: [
                              Text(
                                'Preview Gambar Link:',
                                style: GoogleFonts.outfit(
                                  color: Colors.grey[400],
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: inputBg,
                                  border: Border.all(
                                    color: tealColor.withValues(alpha: 0.5),
                                    width: 2,
                                  ),
                                ),
                                child: ClipOval(
                                  child: Image.network(
                                    urlController.text.trim(),
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => const Icon(
                                      Icons.broken_image_rounded,
                                      color: Colors.redAccent,
                                      size: 30,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(null),
                  child: Text(
                    state.language == 'id' ? 'Batal' : 'Cancel',
                    style: GoogleFonts.outfit(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  onPressed: isProcessingImage
                      ? null
                      : () {
                          if (activeUploadTab == 'upload') {
                            if (selectedFileBytes != null) {
                              Navigator.of(ctx).pop({
                                'type': 'upload',
                                'bytes': selectedFileBytes,
                                'fileName': selectedFileName,
                              });
                            }
                          } else {
                            final url = urlController.text.trim();
                            if (url.isNotEmpty) {
                              Navigator.of(
                                ctx,
                              ).pop({'type': 'link', 'url': url});
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tealColor,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(
                    state.language == 'id' ? 'Simpan' : 'Save',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null) return;
    setState(() => _isUploadingPhoto = true);

    try {
      final String finalUrl;
      if (result['type'] == 'upload') {
        final Uint8List originalBytes = result['bytes'] as Uint8List;
        final String fileName = result['fileName'] as String;

        final Uint8List croppedBytes = _cropImageToSquare(originalBytes);

        final storagePath =
            'avatars/$userId/${DateTime.now().millisecondsSinceEpoch}_$fileName';
        await SupabaseService.client.storage
            .from('profiles')
            .uploadBinary(storagePath, croppedBytes);

        finalUrl = SupabaseService.client.storage
            .from('profiles')
            .getPublicUrl(storagePath);
      } else {
        finalUrl = result['url'] as String;
      }

      if (finalUrl.isNotEmpty) {
        await SupabaseService.client
            .from('user')
            .update({'avatar_url': finalUrl})
            .eq('id', userId);

        ref.read(landingPageProvider.notifier).updateUser({
          'avatar_url': finalUrl,
        });

        setState(() {
          _avatarUrl = finalUrl;
        });
      }
    } catch (e) {
      debugPrint('Error uploading profile photo: $e');
    } finally {
      setState(() => _isUploadingPhoto = false);
    }
  }

  Color themeAccentColor() {
    return ref.read(landingPageProvider.notifier).getPrimaryColor();
  }

  void _viewPatientPerspective() async {
    bool loaderDismissed = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final userId = ref.read(landingPageProvider).loggedInUser?['id'] ?? '';

      if (mounted) {
        Navigator.of(context).pop();
        loaderDismissed = true;
      }

      final Map<String, dynamic> faskesMap = {
        'id': userId,
        'name': _nameController.text.isNotEmpty
            ? _nameController.text
            : 'Puskesmas Sumbersari',
        'email': _emailController.text.isNotEmpty
            ? _emailController.text
            : 'puskesmas@company.com',
        'avatar_url': _avatarUrl.isNotEmpty ? _avatarUrl : null,
        'nama_faskes': _faskesController.text.isNotEmpty
            ? _faskesController.text
            : 'Puskesmas Sumbersari',
        'profession': 'Puskesmas',
        'is_visible': _showProfileInSearch,
        'is_bpjs': _serveBPJSPatients,
        'about': _aboutController.text,
        'whatsapp_number': _phoneController.text.isNotEmpty
            ? _phoneController.text
            : '085259930755',
        'address': _addressDetailController.text,
        'province': _selectedProvinsi,
        'district': _selectedKabupaten,
        'sub_district': _selectedKecamatan,
        'village': _selectedKelurahan,
        'practice_licenses': <String>[],
        'google_maps_link': _mapsLinkController.text,
      };

      if (!mounted) return;
      showDialog(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.45),
        builder: (ctx) => DoctorDetailDialog(
          dokter: faskesMap,
          isDark: ref.read(landingPageProvider).appearance == 'dark',
          isPreview: true,
        ),
      );
    } catch (e) {
      if (mounted && !loaderDismissed) {
        Navigator.of(context).pop();
      }
    }
  }

  void _selectTime(
    BuildContext context,
    Map<String, dynamic> dayMap,
    bool isStart,
  ) async {
    final timeStr = isStart
        ? dayMap['start'] as String
        : dayMap['end'] as String;

    // Parse time display string back to TimeOfDay
    TimeOfDay initialTime = const TimeOfDay(hour: 8, minute: 0);
    try {
      final parts = timeStr.split(' ');
      final timeParts = parts[0].split(':');
      var hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);
      final period = parts[1].toUpperCase();
      if (period == 'PM' && hour < 12) hour += 12;
      if (period == 'AM' && hour == 12) hour = 0;
      initialTime = TimeOfDay(hour: hour, minute: minute);
    } catch (_) {}

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (picked != null) {
      final period = picked.period == DayPeriod.am ? 'AM' : 'PM';
      var hour = picked.hourOfPeriod;
      if (hour == 0) hour = 12;
      final minStr = picked.minute.toString().padLeft(2, '0');
      final hourStr = hour.toString().padLeft(2, '0');
      final formatted = '$hourStr:$minStr $period';

      setState(() {
        if (isStart) {
          dayMap['start'] = formatted;
        } else {
          dayMap['end'] = formatted;
        }
      });
    }
  }

  String _getMapEmbedUrl(String inputLink) {
    String query = '';

    if (inputLink.isNotEmpty) {
      if (inputLink.contains('output=embed') || inputLink.contains('/embed/')) {
        return inputLink;
      }

      // Try extracting coordinates if available in URL e.g. @-8.0276,113.7764
      final coordRegexp = RegExp(r'@(-?\d+\.\d+),(-?\d+\.\d+)');
      final match = coordRegexp.firstMatch(inputLink);
      if (match != null) {
        final lat = match.group(1);
        final lng = match.group(2);
        query = '$lat,$lng';
      } else {
        // Try extracting place name from /place/Name+Here/
        final placeRegexp = RegExp(r'/place/([^/@]+)');
        final placeMatch = placeRegexp.firstMatch(inputLink);
        if (placeMatch != null) {
          query = Uri.decodeComponent(placeMatch.group(1)!.replaceAll('+', ' '));
        }
      }
    }

    // Fallback to facility name + address details for pinpointing exact location
    if (query.isEmpty) {
      final parts = <String>[];
      if (_faskesController.text.trim().isNotEmpty) {
        parts.add(_faskesController.text.trim());
      }
      if (_addressDetailController.text.trim().isNotEmpty) {
        parts.add(_addressDetailController.text.trim());
      }
      if (_selectedKecamatan.isNotEmpty) parts.add(_selectedKecamatan);
      if (_selectedKabupaten.isNotEmpty) parts.add(_selectedKabupaten);
      if (_selectedProvinsi.isNotEmpty) parts.add(_selectedProvinsi);

      query = parts.isNotEmpty ? parts.join(', ') : 'Puskesmas Sumber Wringin, Bondowoso';
    }

    return 'https://maps.google.com/maps?q=${Uri.encodeComponent(query)}&t=&z=${_zoomLevel.toInt()}&ie=UTF8&iwloc=&output=embed';
  }

  Widget _buildMapContent(bool isDark) {
    final mapsLink = _mapsLinkController.text.trim();
    if (kIsWeb) {
      final embedUrl = _getMapEmbedUrl(mapsLink);
      return buildWebMapWidget(mapUrl: embedUrl, isDark: isDark);
    }
    return Container(
      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.map_rounded, size: 48, color: Colors.grey),
          const SizedBox(height: 12),
          Text(
            isDark
                ? 'Interactive Map active on Web'
                : 'Peta Interaktif aktif di Web',
            style: GoogleFonts.outfit(
              color: Colors.grey[500],
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(landingPageProvider);
    final notifier = ref.read(landingPageProvider.notifier);

    final isDark = state.appearance == 'dark';
    final cardBgColor = notifier.getCardColor();
    final textColor = notifier.getTextColor();
    final subtitleColor = notifier.getBodyTextColor();
    final borderColor = notifier.getBorderColor();
    final themeAccent = notifier.getPrimaryColor();
    final inputBg = isDark ? const Color(0xFF1E1E22) : const Color(0xFFF8FAFC);
    final isEn = state.language == 'en';

    if (_isLoading) {
      return const Column(
        children: [
          SkeletonLoading(
            height: 120,
            width: double.infinity,
            borderRadius: 20,
          ),
          SizedBox(height: 20),
          SkeletonLoading(height: 48, width: double.infinity, borderRadius: 30),
          SizedBox(height: 20),
          SkeletonLoading(
            height: 300,
            width: double.infinity,
            borderRadius: 20,
          ),
        ],
      );
    }

    String avatarInitials = 'PK';
    if (_nameController.text.isNotEmpty) {
      final parts = _nameController.text.split(' ');
      if (parts.length > 1) {
        avatarInitials = (parts[0][0] + parts[1][0]).toUpperCase();
      } else {
        avatarInitials = _nameController.text[0].toUpperCase();
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── 1. Hero Profile Header Card ─────────────────────────────────────
        AnimatedEntrance(
          delay: Duration.zero,
          type: EntranceAnimationType.slideUp,
          child: Container(
            decoration: BoxDecoration(
              color: cardBgColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                  blurRadius: 15,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // Banner Background with Blur
                Container(
                  height: 120,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                    gradient: LinearGradient(
                      colors: isDark
                          ? [const Color(0xFF1E1E22), const Color(0xFF2A2A30)]
                          : [const Color(0xFFE8F6F3), const Color(0xFFD0ECE7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.bottomCenter,
                    children: [
                      if (_avatarUrl.isNotEmpty &&
                          state.blurProfileEffectEnabled)
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(20),
                              topRight: Radius.circular(20),
                            ),
                            child: ImageFiltered(
                              imageFilter: ImageFilter.blur(
                                sigmaX: 15.0,
                                sigmaY: 15.0,
                              ),
                              child: Image.network(
                                _avatarUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => const SizedBox(),
                              ),
                            ),
                          ),
                        ),
                      if (_avatarUrl.isNotEmpty &&
                          state.blurProfileEffectEnabled)
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(20),
                              topRight: Radius.circular(20),
                            ),
                            child: Container(
                              color: isDark
                                  ? Colors.black.withValues(alpha: 0.4)
                                  : themeAccent.withValues(alpha: 0.15),
                            ),
                          ),
                        ),
                      // Profile Avatar Sticking out
                      Positioned(
                        bottom: -40,
                        child: GestureDetector(
                          onTap: _uploadProfilePhoto,
                          child: Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              Container(
                                width: 90,
                                height: 90,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isDark
                                      ? const Color(0xFF252528)
                                      : Colors.white,
                                  border: Border.all(
                                    color: cardBgColor,
                                    width: 4,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.1),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ClipOval(
                                  child: _isUploadingPhoto
                                      ? Center(
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: themeAccent,
                                          ),
                                        )
                                      : _avatarUrl.isNotEmpty
                                      ? Image.network(
                                          _avatarUrl,
                                          fit: BoxFit.cover,
                                          width: 90,
                                          height: 90,
                                          errorBuilder: (_, _, _) => Center(
                                            child: Text(
                                              avatarInitials,
                                              style: GoogleFonts.outfit(
                                                fontSize: 28,
                                                fontWeight: FontWeight.w900,
                                                color: themeAccent,
                                              ),
                                            ),
                                          ),
                                        )
                                      : Center(
                                          child: Text(
                                            avatarInitials,
                                            style: GoogleFonts.outfit(
                                              fontSize: 28,
                                              fontWeight: FontWeight.w900,
                                              color: themeAccent,
                                            ),
                                          ),
                                        ),
                                ),
                              ),
                              // Camera Icon Badge
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF3B82F6),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: cardBgColor,
                                    width: 2,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.camera_alt_rounded,
                                  color: Colors.white,
                                  size: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 50),
                Text(
                  _nameController.text.isNotEmpty
                      ? _nameController.text
                      : 'Puskesmas Sumbersari',
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _emailController.text.isNotEmpty
                      ? _emailController.text
                      : 'puskesmas@company.com',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: subtitleColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),

                // Button View Patient Perspective
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: _viewPatientPerspective,
                        icon: const Icon(Icons.visibility_outlined, size: 16),
                        label: Text(
                          isEn
                              ? 'View Patient Perspective'
                              : 'Lihat Perspektif Pasien',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: themeAccent,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(100),
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

        const SizedBox(height: 20),

        // ── 2. Pill Tab Bar ──────────────────────────────────────────────────
        AnimatedEntrance(
          delay: const Duration(milliseconds: 100),
          type: EntranceAnimationType.slideUp,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: cardBgColor,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildTabItem(
                    0,
                    isEn ? 'Profile & Info' : 'Profil & Info',
                    Icons.domain_rounded,
                    themeAccent,
                    isDark,
                  ),
                ),
                Expanded(
                  child: _buildTabItem(
                    1,
                    isEn ? 'Practice & Service' : 'Praktik & Layanan',
                    Icons.home_repair_service_rounded,
                    themeAccent,
                    isDark,
                  ),
                ),
                Expanded(
                  child: _buildTabItem(
                    2,
                    isEn ? 'API & Integration' : 'API & Integrasi',
                    Icons.integration_instructions_rounded,
                    themeAccent,
                    isDark,
                  ),
                ),
                Expanded(
                  child: _buildTabItem(
                    3,
                    isEn ? 'DLC Modules' : 'Modul DLC',
                    Icons.extension_rounded,
                    themeAccent,
                    isDark,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        // ── 3. Tab Body ─────────────────────────────────────────────────────
        AnimatedEntrance(
          delay: const Duration(milliseconds: 150),
          type: EntranceAnimationType.slideUp,
          child: _activeTab == 0
              ? _buildProfileAndStatusTab(
                  cardBgColor,
                  textColor,
                  subtitleColor,
                  borderColor,
                  inputBg,
                  themeAccent,
                  isEn,
                  isDark,
                )
              : _activeTab == 1
              ? _buildPracticeAndServiceTab(
                  cardBgColor,
                  textColor,
                  subtitleColor,
                  borderColor,
                  inputBg,
                  themeAccent,
                  isEn,
                  isDark,
                )
              : _activeTab == 2
              ? _buildApiAndIntegrationTab(
                  cardBgColor,
                  textColor,
                  subtitleColor,
                  borderColor,
                  themeAccent,
                  isEn,
                  isDark,
                )
              : _buildDlcModulesTab(
                  cardBgColor,
                  textColor,
                  subtitleColor,
                  borderColor,
                  inputBg,
                  themeAccent,
                  isEn,
                  isDark,
                ),
        ),
      ],
    );
  }

  Widget _buildTabItem(
    int index,
    String label,
    IconData icon,
    Color activeColor,
    bool isDark,
  ) {
    final isSelected = _activeTab == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _activeTab = index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? Colors.white
                  : (isDark ? Colors.grey[400] : const Color(0xFF64748B)),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.grey[400] : const Color(0xFF64748B)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileAndStatusTab(
    Color cardBgColor,
    Color textColor,
    Color subtitleColor,
    Color borderColor,
    Color inputBg,
    Color themeAccent,
    bool isEn,
    bool isDark,
  ) {
    return Column(
      children: [
        // Card 1: Edit Profile details
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: cardBgColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.person_outline_rounded,
                    color: themeAccent,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isEn ? 'Edit Profile' : 'Edit Profil',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: textColor,
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Password reset link sent to your email!',
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.lock_outline, size: 12),
                    label: Text(isEn ? 'Reset Password' : 'Reset Sandi'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: themeAccent,
                      side: BorderSide(color: themeAccent),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      textStyle: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 20),

              // Name & Phone
              Row(
                children: [
                  Expanded(
                    child: _buildInputLabelAndField(
                      'Full Name',
                      _nameController,
                      inputBg,
                      textColor,
                      subtitleColor,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildInputLabelAndField(
                      'Phone Number (11-13 Digit)',
                      _phoneController,
                      inputBg,
                      textColor,
                      subtitleColor,
                      keyboardType: TextInputType.phone,
                      maxLength: 13,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(13),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Email & Gender
              Row(
                children: [
                  Expanded(
                    child: _buildInputLabelAndField(
                      'Email Address',
                      _emailController,
                      inputBg,
                      textColor,
                      subtitleColor,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildDropdownField(
                      'GENDER',
                      _selectedGender,
                      ['Male', 'Female'],
                      (val) => setState(() => _selectedGender = val!),
                      inputBg,
                      textColor,
                      subtitleColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Faskes Name
              _buildInputLabelAndField(
                'Faskes / Clinic Name',
                _faskesController,
                inputBg,
                textColor,
                subtitleColor,
              ),
              const SizedBox(height: 16),

              // About
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ABOUT',
                    style: GoogleFonts.outfit(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: subtitleColor,
                      letterSpacing: 1.0,
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
                      horizontal: 14,
                      vertical: 8,
                    ),
                    child: TextField(
                      controller: _aboutController,
                      maxLines: 4,
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 20),

              // Address dropdowns (using LocationSelectorWidget)
              Text(
                'ADDRESS',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: textColor,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 12),
              LocationSelectorWidget(
                initialProvince: _selectedProvinsi,
                initialDistrict: _selectedKabupaten,
                initialSubDistrict: _selectedKecamatan,
                initialVillage: _selectedKelurahan,
                fieldBg: inputBg,
                textColor: textColor,
                subtitleColor: subtitleColor,
                borderColor: borderColor,
                dropdownColor: inputBg,
                fontSize: 12,
                onChanged: (province, district, subDistrict, village) {
                  setState(() {
                    _selectedProvinsi = province;
                    _selectedKabupaten = district;
                    _selectedKecamatan = subDistrict;
                    _selectedKelurahan = village;
                  });
                },
              ),
              const SizedBox(height: 16),

              // Detail Alamat text field
              _buildInputLabelAndField(
                'DETAIL ALAMAT',
                _addressDetailController,
                inputBg,
                textColor,
                subtitleColor,
                maxLines: 3,
              ),

              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 20),

              Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                  width: 140,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveProfileData,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: themeAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            isEn ? 'SAVE CHANGES' : 'SIMPAN PROFIL',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Card 2: Subscription Status
        _buildSubscriptionStatusCard(
          cardBgColor,
          textColor,
          subtitleColor,
          borderColor,
          inputBg,
          themeAccent,
          const Color(0xFF8A2BE2),
          isEn,
          isDark,
        ),
      ],
    );
  }

  Widget _buildPracticeAndServiceTab(
    Color cardBgColor,
    Color textColor,
    Color subtitleColor,
    Color borderColor,
    Color inputBg,
    Color themeAccent,
    bool isEn,
    bool isDark,
  ) {
    return Column(
      children: [
        // Card 1: Weekly Operational Schedule
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: cardBgColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    color: themeAccent,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    isEn
                        ? 'Weekly Operational Schedule'
                        : 'Jadwal Operasional Mingguan',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: textColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                isEn
                    ? 'Set your operational hours for each day. Mark as HOLIDAY if not open.'
                    : 'Tentukan jam operasional Puskesmas Anda. Beri tanda HOLIDAY jika tutup.',
                style: GoogleFonts.outfit(fontSize: 11, color: subtitleColor),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),

              ..._scheduleDays.map(
                (dayMap) => _buildScheduleDayRow(
                  dayMap,
                  isDark,
                  false,
                  inputBg,
                  borderColor,
                  themeAccent,
                  subtitleColor,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Card 2: Clinic Location
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: cardBgColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    color: themeAccent,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isEn ? 'Clinic Location' : 'Lokasi Praktik',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: textColor,
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.search, size: 12),
                    label: const Text('Search SatuSehat'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: textColor,
                      side: BorderSide(color: borderColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      textStyle: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.edit, size: 12),
                    label: const Text('Edit Location'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: textColor,
                      side: BorderSide(color: borderColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      textStyle: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF221F2E)
                      : const Color(0xFFF5F0FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: themeAccent.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _faskesController.text.isNotEmpty
                                ? _faskesController.text
                                : 'Puskesmas Sumbersari',
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF3F1B85),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _addressDetailController.text.isNotEmpty
                                ? _addressDetailController.text
                                : 'Dusun Krajan RT 01 RW 03 Pujer',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              color: isDark
                                  ? Colors.grey[300]
                                  : const Color(0xFF5F439E),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'ID: ',
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.grey[400]
                                  : const Color(0xFF7E64BA),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final urlStr = _mapsLinkController.text.trim();
                        if (urlStr.isNotEmpty) {
                          final uri = Uri.parse(urlStr);
                          if (await canLaunchUrl(uri)) await launchUrl(uri);
                        }
                      },
                      icon: const Icon(Icons.map_outlined, size: 12),
                      label: const Text('MAP'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2EC4B6),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        textStyle: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              Text(
                'Clinic Google Maps Link',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: subtitleColor,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      height: 38,
                      decoration: BoxDecoration(
                        color: inputBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: borderColor),
                      ),
                      child: TextField(
                        controller: _mapsLinkController,
                        onChanged: (_) {
                          setState(() {});
                        },
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          color: textColor,
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () async {
                      setState(() {});
                      final urlStr = _mapsLinkController.text.trim();
                      if (urlStr.isNotEmpty) {
                        final uri = Uri.parse(urlStr);
                        if (await canLaunchUrl(uri)) await launchUrl(uri);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE8D7FF),
                      foregroundColor: const Color(0xFF8A2BE2),
                    ),
                    child: Text(
                      'Show',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Open Google Maps -> search clinic -> click Share -> select Copy link -> paste here.',
                style: GoogleFonts.outfit(fontSize: 10, color: subtitleColor),
              ),

              const SizedBox(height: 20),

              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        size: 14,
                        color: Colors.redAccent,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _faskesController.text.isNotEmpty
                            ? _faskesController.text
                            : 'Puskesmas Sumbersari',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 220,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child: _buildMapContent(isDark),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Card 3: Wilayah Kerja & Batas Geografis Puskesmas (RevGeo API Integration)
        _buildWilayahKerjaMapCard(
          cardBgColor,
          textColor,
          subtitleColor,
          borderColor,
          inputBg,
          themeAccent,
          isEn,
          isDark,
        ),

        const SizedBox(height: 20),

        // Card 4: Search & Registration Settings
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: cardBgColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.search_rounded, color: themeAccent, size: 18),
                  const SizedBox(width: 10),
                  Text(
                    isEn
                        ? 'Search & Registration Settings'
                        : 'Pengaturan Pencarian & Pendaftaran',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: textColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Show Profile in Search',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        Text(
                          'If active, your profile can be searched by the public in the "Search Private Practice" menu.',
                          style: GoogleFonts.outfit(
                            fontSize: 9,
                            color: subtitleColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _showProfileInSearch,
                    activeThumbColor: themeAccent,
                    onChanged: (val) =>
                        setState(() => _showProfileInSearch = val),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Serve BPJS Patients',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        Text(
                          'If active, patients can register using their BPJS Health card number.',
                          style: GoogleFonts.outfit(
                            fontSize: 9,
                            color: subtitleColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _serveBPJSPatients,
                    activeThumbColor: themeAccent,
                    onChanged: (val) =>
                        setState(() => _serveBPJSPatients = val),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                  width: 140,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveProfileData,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: themeAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            isEn ? 'SAVE CHANGES' : 'SIMPAN PROFIL',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSubscriptionStatusCard(
    Color cardBg,
    Color textColor,
    Color subtitleColor,
    Color borderColor,
    Color inputBg,
    Color activeColor,
    Color premiumColor,
    bool isEn,
    bool isDark,
  ) {
    final isActive = _subStatus == 'ACTIVE';
    final statusColor = isActive ? activeColor : Colors.orangeAccent;
    final progress = _subDaysRemaining > 0
        ? (_subDaysRemaining / 30.0).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive
              ? activeColor.withValues(alpha: 0.35)
              : Colors.orangeAccent.withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: statusColor.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isActive
                      ? Icons.verified_rounded
                      : Icons.calendar_month_outlined,
                  color: statusColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEn
                          ? 'Portal Subscription Status'
                          : 'Status Langganan Portal',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: textColor,
                      ),
                    ),
                    Text(
                      isActive
                          ? (isEn
                                ? 'Your portal subscription is active'
                                : 'Langganan portal Anda aktif')
                          : (isEn
                                ? 'Portal subscription is inactive/expired'
                                : 'Langganan portal tidak aktif/kedaluwarsa'),
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: subtitleColor,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  _subStatus,
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: statusColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          if (isActive && _subDaysRemaining > 0) ...[
            Row(
              children: [
                Expanded(
                  child: _buildTimeBox('', isEn ? 'Days' : 'Hari', statusColor),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildTimeBox('', isEn ? 'Hours' : 'Jam', statusColor),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildTimeBox(
                    '',
                    isEn ? 'Minutes' : 'Menit',
                    statusColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isEn ? 'Time Remaining' : 'Sisa Waktu',
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: subtitleColor,
                      ),
                    ),
                    Text(
                      '%',
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(100),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: statusColor.withValues(alpha: 0.12),
                    valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                    minHeight: 8,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ] else if (!isActive) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              decoration: BoxDecoration(
                color: Colors.orangeAccent.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.orangeAccent.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: Colors.orangeAccent,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isEn
                          ? 'Subscribe to unlock all features, search visibility, and integrations.'
                          : 'Berlangganan untuk membuka semua fitur, visibilitas pencarian, dan integrasi.',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: Colors.orangeAccent,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          Container(
            decoration: BoxDecoration(
              color: inputBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: [
                _buildSubStatusRow(
                  isEn ? 'Expiry Date:' : 'Tanggal Kedaluwarsa:',
                  _subExpiry,
                  textColor,
                  isDark,
                ),
                const Divider(height: 1),
                _buildSubStatusRow(
                  isEn ? 'Days Left:' : 'Sisa Hari:',
                  isActive ? ' ' : 'N/A',
                  isActive ? activeColor : Colors.orangeAccent,
                  isDark,
                  showBold: true,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── DLC Add-on License & Unlock Section in Renew Card ──
          Consumer(
            builder: (context, ref, _) {
              final isVitaScaleUnlocked = ref.watch(vitascaleDlcUnlockedProvider);
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isVitaScaleUnlocked
                      ? const Color(0xFF1ABC9C).withValues(alpha: 0.08)
                      : Colors.orange.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isVitaScaleUnlocked
                        ? const Color(0xFF1ABC9C).withValues(alpha: 0.3)
                        : Colors.orange.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isVitaScaleUnlocked
                                ? const Color(0xFF1ABC9C).withValues(alpha: 0.15)
                                : Colors.orange.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.monitor_weight_rounded,
                            size: 20,
                            color: isVitaScaleUnlocked
                                ? const Color(0xFF1ABC9C)
                                : Colors.orange,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'DLC: VITASCALE By MAPOTECH',
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                              Text(
                                'Skrining Antropometri IoT & CV (0–12 Thn)',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  color: subtitleColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isVitaScaleUnlocked
                                ? const Color(0xFF27AE60).withValues(alpha: 0.15)
                                : Colors.orange.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isVitaScaleUnlocked ? 'DLC AKTIF' : 'TERKUNCI',
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: isVitaScaleUnlocked
                                  ? const Color(0xFF27AE60)
                                  : Colors.orange,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            isVitaScaleUnlocked
                                ? 'Akses modul VitaScale telah aktif. Anda dapat langsung membuka skrining antropometri anak.'
                                : 'Buka akses ekspansi DLC VitaScale untuk menghubungkan timbangan IoT dan Computer Vision.',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              color: subtitleColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: () {
                            final nextState = !isVitaScaleUnlocked;
                            ref.read(vitascaleDlcUnlockedProvider.notifier).state = nextState;
                            if (nextState) {
                              ref.read(landingPageProvider.notifier).addFavoriteMenuItem('dlc_vitascale_data_anak');
                              ref.read(landingPageProvider.notifier).addFavoriteMenuItem('dlc_vitascale_screening');
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('DLC VITASCALE By MAPOTECH Berhasil Di-Unlock!'),
                                  backgroundColor: Color(0xFF1ABC9C),
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('DLC VITASCALE Dikunci Kembali.'),
                                  backgroundColor: Colors.grey,
                                ),
                              );
                            }
                          },
                          icon: Icon(
                            isVitaScaleUnlocked
                                ? Icons.lock_outline_rounded
                                : Icons.lock_open_rounded,
                            size: 14,
                          ),
                          label: Text(
                            isVitaScaleUnlocked ? 'Kunci' : 'Unlock DLC',
                            style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isVitaScaleUnlocked
                                ? (isDark ? const Color(0xFF2C2C30) : const Color(0xFFECEEF2))
                                : const Color(0xFF1ABC9C),
                            foregroundColor: isVitaScaleUnlocked ? textColor : Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 16),

          ElevatedButton.icon(
            onPressed: _isSaving ? null : _renewSubscription,
            icon: Icon(
              _isSaving ? Icons.hourglass_top_rounded : Icons.sync,
              size: 16,
            ),
            label: Text(
              _isSaving
                  ? (isEn ? 'Renewing...' : 'Memperbarui...')
                  : (isEn ? 'Renew 30 Days' : 'Perbarui 30 Hari'),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: premiumColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              textStyle: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubStatusRow(
    String label,
    String value,
    Color valColor,
    bool isDark, {
    bool showBold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: showBold ? FontWeight.w900 : FontWeight.w700,
              color: valColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeBox(String value, String label, Color accentColor) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(
            value.padLeft(2, '0'),
            style: GoogleFonts.outfit(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: accentColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label.toUpperCase(),
            style: GoogleFonts.outfit(
              fontSize: 9,
              fontWeight: FontWeight.w900,
              color: accentColor.withValues(alpha: 0.8),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _renewSubscription() async {
    final state = ref.read(landingPageProvider);
    final userId = state.loggedInUser?['id'];
    if (userId == null) return;

    setState(() => _isSaving = true);

    try {
      final client = SupabaseService.client;

      final res = await client
          .from('user')
          .select('subscription_expires_at')
          .eq('id', userId)
          .maybeSingle();

      DateTime currentExpiry = DateTime.now();
      if (res != null && res['subscription_expires_at'] != null) {
        try {
          final parsed = DateTime.parse(res['subscription_expires_at']);
          if (parsed.isAfter(DateTime.now())) {
            currentExpiry = parsed;
          }
        } catch (_) {}
      }

      final newExpiry = currentExpiry.add(const Duration(days: 30));
      final newExpiryStr = newExpiry.toIso8601String();

      await client
          .from('user')
          .update({
            'subscription_status': 'active',
            'subscription_expires_at': newExpiryStr,
          })
          .eq('id', userId);

      await _loadProfileData();

      // Pastikan DLC VitaScale juga diaktifkan saat perpanjangan berhasil
      ref.read(vitascaleDlcUnlockedProvider.notifier).state = true;
      ref.read(landingPageProvider.notifier).addFavoriteMenuItem('dlc_vitascale_data_anak');
      ref.read(landingPageProvider.notifier).addFavoriteMenuItem('dlc_vitascale_screening');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ref.read(landingPageProvider).language == 'en'
                ? 'Puskesmas Portal Subscription successfully renewed for 30 Days! New expiry: '
                : 'Langganan Portal Puskesmas berhasil diperpanjang selama 30 Hari! Kedaluwarsa baru: ',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to renew subscription: '),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Widget _buildScheduleDayRow(
    Map<String, dynamic> dayMap,
    bool isDark,
    bool isRev,
    Color inputBg,
    Color borderColor,
    Color themeAccent,
    Color subtitleColor,
  ) {
    final bool isActive = dayMap['active'] as bool;
    final String dayName = dayMap['day'] as String;
    final String dayInitial = dayMap['initial'] as String;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isActive
            ? Colors.transparent
            : (isDark
                  ? const Color(0xFF1B1B1F)
                  : const Color(0xFFF1F5F9).withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? borderColor : borderColor.withValues(alpha: 0.5),
        ),
      ),
      child: Opacity(
        opacity: isActive ? 1.0 : 0.5,
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive
                    ? themeAccent.withValues(alpha: 0.12)
                    : const Color(0xFFE2E8F0),
              ),
              alignment: Alignment.center,
              child: Text(
                dayInitial,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isActive ? themeAccent : Colors.grey,
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 90,
              child: Text(
                dayName,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF1B0C3C),
                ),
              ),
            ),
            const Icon(Icons.access_time, size: 14, color: Colors.grey),
            const SizedBox(width: 8),

            // Start Time picker
            GestureDetector(
              onTap: isActive ? () => _selectTime(context, dayMap, true) : null,
              child: Container(
                width: 90,
                height: 34,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: inputBg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: borderColor),
                ),
                child: Center(
                  child: Text(
                    dayMap['start'] as String,
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? (isActive ? Colors.white : Colors.grey)
                          : (isActive ? Colors.black87 : Colors.grey),
                    ),
                  ),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text('s/d'),
            ),

            // End Time picker
            GestureDetector(
              onTap: isActive
                  ? () => _selectTime(context, dayMap, false)
                  : null,
              child: Container(
                width: 90,
                height: 34,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: inputBg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: borderColor),
                ),
                child: Center(
                  child: Text(
                    dayMap['end'] as String,
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? (isActive ? Colors.white : Colors.grey)
                          : (isActive ? Colors.black87 : Colors.grey),
                    ),
                  ),
                ),
              ),
            ),
            const Spacer(),

            // Holiday toggle
            Switch(
              value: isActive,
              activeThumbColor: themeAccent,
              onChanged: (val) {
                setState(() {
                  dayMap['active'] = val;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApiAndIntegrationTab(
    Color cardBgColor,
    Color textColor,
    Color subtitleColor,
    Color borderColor,
    Color themeAccent,
    bool isEn,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Card with Tabs like in Doctor Linkage Settings
          Row(
            children: [
              Icon(Icons.vpn_key_outlined, color: themeAccent, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isEn ? 'API Linkage Settings' : 'Pengaturan Integrasi API',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: textColor,
                  ),
                ),
              ),
              // Pill Selector for SatuSehat, BPJS, Mobile JKN
              Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF252528)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(30),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    _buildSubTabItem(0, 'SatuSehat'),
                    _buildSubTabItem(1, 'BPJS'),
                    _buildSubTabItem(2, 'Mobile JKN'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 20),

          if (_activeApiSubTab == 0) ...[
            Text(
              'SATUSEHAT CREDENTIALS',
              style: GoogleFonts.outfit(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: themeAccent,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F6F3),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'PRODUCTION ENVIRONMENT',
                style: GoogleFonts.outfit(
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF00A67E),
                ),
              ),
            ),
            const SizedBox(height: 20),

            _buildInputLabel('Organization ID', subtitleColor),
            _buildTextField(
              _ssOrgIdController,
              'e.g. 100062510',
              textColor,
              borderColor,
            ),
            const SizedBox(height: 16),

            _buildInputLabel('Client ID', subtitleColor),
            _buildTextField(
              _ssClientIdController,
              'Enter client_id',
              textColor,
              borderColor,
            ),
            const SizedBox(height: 16),

            _buildInputLabel('Client Secret', subtitleColor),
            _buildTextField(
              _ssClientSecretController,
              'Enter client_secret',
              textColor,
              borderColor,
              obscureText: true,
            ),
          ] else if (_activeApiSubTab == 1) ...[
            Text(
              'BPJS KESEHATAN CREDENTIALS',
              style: GoogleFonts.outfit(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: themeAccent,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 20),
            _buildInputLabel('BPJS API KEY / AUTH TOKEN', subtitleColor),
            _buildTextField(
              _bpjsApiKeyController,
              'Enter BPJS cons_id',
              textColor,
              borderColor,
            ),
          ] else ...[
            Text(
              'MOBILE JKN CREDENTIALS',
              style: GoogleFonts.outfit(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: themeAccent,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 20),
            _buildInputLabel('MOBILE JKN KEY', subtitleColor),
            _buildTextField(
              _jknApiKeyController,
              'Enter JKN api_key',
              textColor,
              borderColor,
            ),
          ],

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 20),

          // Save button
          Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: 150,
              height: 44,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveProfileData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: themeAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(100),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        isEn ? 'Save API Settings' : 'Simpan API',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubTabItem(int index, String label) {
    final isSelected = _activeApiSubTab == index;
    final themeAccent = themeAccentColor();
    final isDark = ref.read(landingPageProvider).appearance == 'dark';

    return GestureDetector(
      onTap: () => setState(() => _activeApiSubTab = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? themeAccent : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSelected
                ? Colors.white
                : (isDark ? Colors.grey[400] : const Color(0xFF64748B)),
          ),
        ),
      ),
    );
  }

  Widget _buildInputLabel(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: GoogleFonts.outfit(
          fontSize: 9,
          fontWeight: FontWeight.w900,
          color: color,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildInputLabelAndField(
    String label,
    TextEditingController controller,
    Color fieldBg,
    Color textColor,
    Color subtitleColor, {
    int maxLines = 1,
    TextInputType? keyboardType,
    int? maxLength,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.outfit(
            fontSize: 9,
            fontWeight: FontWeight.w900,
            color: subtitleColor,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: maxLines > 1 ? null : 38,
          decoration: BoxDecoration(
            color: fieldBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: ref.read(landingPageProvider.notifier).getBorderColor(),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: TextField(
            controller: controller,
            maxLines: maxLines,
            keyboardType: keyboardType,
            maxLength: maxLength,
            inputFormatters: inputFormatters,
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
            decoration: const InputDecoration(
              border: InputBorder.none,
              counterText: '',
              isDense: true,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField(
    String label,
    String currentValue,
    List<String> items,
    ValueChanged<String?> onChanged,
    Color fieldBg,
    Color textColor,
    Color subtitleColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: GoogleFonts.outfit(
            fontSize: 9,
            fontWeight: FontWeight.w900,
            color: subtitleColor,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 38,
          decoration: BoxDecoration(
            color: fieldBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: ref.read(landingPageProvider.notifier).getBorderColor(),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: currentValue,
              items: items.map((val) {
                return DropdownMenuItem<String>(
                  value: val,
                  child: Text(
                    val,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                );
              }).toList(),
              onChanged: onChanged,
              dropdownColor: fieldBg,
              icon: Icon(Icons.arrow_drop_down, color: subtitleColor),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint,
    Color textColor,
    Color borderColor, {
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: ref.read(landingPageProvider.notifier).getBackgroundColor(),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        maxLines: maxLines,
        keyboardType: keyboardType,
        style: GoogleFonts.outfit(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.outfit(
            fontSize: 13,
            color: textColor.withValues(alpha: 0.4),
          ),
          border: InputBorder.none,
          isDense: true,
        ),
      ),
    );
  }

  Widget _buildWilayahKerjaMapCard(
    Color cardBgColor,
    Color textColor,
    Color subtitleColor,
    Color borderColor,
    Color inputBg,
    Color themeAccent,
    bool isEn,
    bool isDark,
  ) {
    return RevGeoWilayahMapWidget(
      initialProvince: _selectedProvinsi,
      initialDistrict: _selectedKabupaten,
      initialSubDistrict: _selectedKecamatan,
      initialVillage: _selectedKelurahan,
      revgeoApiUrl: _revgeoApiUrlController.text.trim(),
      fieldBg: inputBg,
      textColor: textColor,
      subtitleColor: subtitleColor,
      borderColor: borderColor,
      dropdownColor: cardBgColor,
      themeAccent: themeAccent,
      isDark: isDark,
      isEn: isEn,
      onChanged: (prov, dist, subDist, vill) {
        setState(() {
          _selectedProvinsi = prov;
          _selectedKabupaten = dist;
          _selectedKecamatan = subDist;
          _selectedKelurahan = vill;
        });
      },
    );
  }

  // ── Tab 3: Manajemen Modul DLC (Add-Ons) ───────────────────────────────────

  Widget _buildDlcModulesTab(
    Color cardBgColor,
    Color textColor,
    Color subtitleColor,
    Color borderColor,
    Color inputBg,
    Color themeAccent,
    bool isEn,
    bool isDark,
  ) {
    final isVitaScaleUnlocked = ref.watch(vitascaleDlcUnlockedProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header Banner
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: cardBgColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF1ABC9C).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.extension_rounded,
                  color: Color(0xFF1ABC9C),
                  size: 26,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEn ? 'DLC Modules Management (Add-Ons)' : 'Manajemen Modul DLC (Digital Laboratory & Clinic)',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isEn
                          ? 'Manage optional clinic add-ons, IoT hardware integrations, and clinical expansions.'
                          : 'Kelola modul ekspansi faskes, integrasi perangkat keras IoT, dan computer vision skrining antropometri.',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: subtitleColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // CARD 1: VITASCALE By MAPOTECH
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: cardBgColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isVitaScaleUnlocked
                  ? const Color(0xFF1ABC9C).withValues(alpha: 0.4)
                  : borderColor,
              width: isVitaScaleUnlocked ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1ABC9C).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.monitor_weight_rounded,
                      color: Color(0xFF1ABC9C),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'VITASCALE By MAPOTECH',
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isVitaScaleUnlocked
                                    ? const Color(0xFF27AE60).withValues(alpha: 0.15)
                                    : Colors.orange.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isVitaScaleUnlocked
                                      ? const Color(0xFF27AE60).withValues(alpha: 0.4)
                                      : Colors.orange.withValues(alpha: 0.4),
                                ),
                              ),
                              child: Text(
                                isVitaScaleUnlocked ? 'AKTIF / TERBUKA' : 'TERKUNCI (ADD-ON)',
                                style: GoogleFonts.outfit(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: isVitaScaleUnlocked
                                      ? const Color(0xFF27AE60)
                                      : Colors.orange,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Modul Skrining Antropometri Anak & Bayi (0–12 Tahun) Berbasis IoT & Computer Vision Zero-Install',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: subtitleColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                'Fitur & Kemampuan Modul:',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildDlcTag('4x Load Cell HX711 (Timbangan Digital)', Icons.scale_rounded, const Color(0xFF1ABC9C)),
                  _buildDlcTag('AS5600 12-Bit Magnetik (Lingkar & Panjang)', Icons.straighten_rounded, const Color(0xFF3498DB)),
                  _buildDlcTag('Homography OpenCV.js (Webcam Panjang/Tinggi)', Icons.camera_alt_rounded, const Color(0xFF9B59B6)),
                  _buildDlcTag('Standar WHO & Kemenkes 2020 (<24 Bln vs ≥24 Bln)', Icons.health_and_safety_rounded, const Color(0xFFE67E22)),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(height: 1),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 10,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      final next = !isVitaScaleUnlocked;
                      ref.read(vitascaleDlcUnlockedProvider.notifier).state = next;
                      if (next) {
                        ref.read(landingPageProvider.notifier).addFavoriteMenuItem('dlc_vitascale_data_anak');
                        ref.read(landingPageProvider.notifier).addFavoriteMenuItem('dlc_vitascale_screening');
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Modul DLC VitaScale Berhasil Diaktifkan!'),
                            backgroundColor: Color(0xFF1ABC9C),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Modul DLC VitaScale Dikunci Kembali.'),
                            backgroundColor: Colors.grey,
                          ),
                        );
                      }
                    },
                    icon: Icon(
                      isVitaScaleUnlocked ? Icons.lock_outline_rounded : Icons.lock_open_rounded,
                      size: 16,
                    ),
                    label: Text(
                      isVitaScaleUnlocked ? 'Kunci Kembali Modul' : 'Buka Kunci DLC VitaScale',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isVitaScaleUnlocked
                          ? (isDark ? const Color(0xFF2C2C30) : const Color(0xFFECEEF2))
                          : const Color(0xFF1ABC9C),
                      foregroundColor: isVitaScaleUnlocked ? textColor : Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      widget.onNavigate?.call('dlc_vitascale_data_anak');
                    },
                    icon: const Icon(Icons.child_care_rounded, size: 16),
                    label: const Text('Buka Data Anak/Bayi'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1ABC9C),
                      side: const BorderSide(color: Color(0xFF1ABC9C)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      widget.onNavigate?.call('dlc_vitascale_screening');
                    },
                    icon: const Icon(Icons.monitor_weight_rounded, size: 16),
                    label: const Text('Mulai Screening Anak/Bayi'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF27AE60),
                      side: const BorderSide(color: Color(0xFF27AE60)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // CARD 2: DLC KIA (Kesehatan Ibu & Anak)
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: cardBgColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE91E63).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.pregnant_woman_rounded,
                      color: Color(0xFFE91E63),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'DLC KIA (Kesehatan Ibu & Anak)',
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF27AE60).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'AKTIF',
                                style: GoogleFonts.outfit(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFF27AE60),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Pemantauan Kohort Ibu Hamil, Deteksi Risiko Tinggi, dan Form Pemeriksaan Standar Kemenkes',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: subtitleColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 10,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      widget.onNavigate?.call('dlc_pantauan_ibu_hamil');
                    },
                    icon: const Icon(Icons.pregnant_woman_rounded, size: 16),
                    label: const Text('Buka Pantauan Ibu Hamil'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFE91E63),
                      side: const BorderSide(color: Color(0xFFE91E63)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      widget.onNavigate?.call('dlc_form_ibu_hamil');
                    },
                    icon: const Icon(Icons.assignment_rounded, size: 16),
                    label: const Text('Buka Form Pemeriksaan'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFEC407A),
                      side: const BorderSide(color: Color(0xFFEC407A)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDlcTag(String text, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
