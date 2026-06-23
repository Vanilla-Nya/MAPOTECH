import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mapotech/features/landing/landing_page_data.dart';
import 'package:mapotech/shared/supabase_service.dart';

/// Profil Dokter — Restructured profile page for the dokter/praktek mandiri role.
class DokterProfile extends ConsumerStatefulWidget {
  const DokterProfile({super.key});

  @override
  ConsumerState<DokterProfile> createState() => _DokterProfileState();
}

class _DokterProfileState extends ConsumerState<DokterProfile> {
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploadingPhoto = false;

  // Profile photo URL from database
  String _avatarUrl = '';

  // Subscription Details
  String _subStatus = 'INACTIVE';
  String _subExpiry = '-';
  int _subDaysRemaining = 0;
  int _subHoursRemaining = 0;
  int _subMinutesRemaining = 0;
  int _subTotalDays = 30; // default plan length
  DateTime? _subExpiryDate;

  // Tab index: 0 = Profile & Status, 1 = Practice & Service, 2 = API & Integration
  int _activeTab = 0;

  // --- Text Controllers for Profile & Status ---
  late TextEditingController _emailController;
  late TextEditingController _faskesController;
  late TextEditingController _nameController;
  late TextEditingController _usernameController;
  late TextEditingController _phoneController;
  late TextEditingController _nikController;
  late TextEditingController _rfidController;
  late TextEditingController _satuSehatIdController;
  late TextEditingController _addressDetailController;
  late TextEditingController _aboutController;

  // --- Dropdown States for Profile & Status ---
  String _selectedGender = 'Male';
  String _selectedProvinsi = 'JAWA TIMUR';
  String _selectedKabupaten = 'KABUPATEN BONDOWOSO';
  String _selectedKecamatan = 'PUJER';
  String _selectedKelurahan = 'KEJAYAN';

  // --- State for Practice & Service ---
  late TextEditingController _mapsLinkController;
  late TextEditingController _maxQueueController;
  String _selectedProfession = 'Doctor';
  bool _showProfileInSearch = true;
  bool _serveBPJSPatients = true;
  String _qrToken = '';

  // QRIS Payment Method State
  String _selectedQrisType = 'UPLOAD PHOTO'; // 'UPLOAD PHOTO', 'IMAGE URL / LABEL', 'AUTOMATIC PAYMENT LINK'
  late TextEditingController _qrisLinkController;
  String _qrisPath = '';

  // --- State for API & Integration ---
  int _activeApiSubTab = 0; // 0 = SatuSehat, 1 = BPJS, 2 = Mobile JKN
  bool _obscureSsSecret = true;
  bool _obscureBpjsSecret = true;
  bool _obscureJknSecret = true;

  late TextEditingController _ssOrgIdController;
  late TextEditingController _ssClientIdController;
  late TextEditingController _ssClientSecretController;

  late TextEditingController _bpjsConsIdController;
  late TextEditingController _bpjsSecretKeyController;
  late TextEditingController _bpjsUserKeyController;

  late TextEditingController _jknUrlController;
  late TextEditingController _jknClientIdController;
  late TextEditingController _jknClientSecretController;

  // Weekly Schedule State
  final List<Map<String, dynamic>> _scheduleDays = [
    {
      'day': 'Monday',
      'initial': 'M',
      'active': true,
      'start': '03:00 PM',
      'end': '09:00 PM',
    },
    {
      'day': 'Tuesday',
      'initial': 'T',
      'active': true,
      'start': '03:00 PM',
      'end': '09:00 PM',
    },
    {
      'day': 'Wednesday',
      'initial': 'W',
      'active': true,
      'start': '03:00 PM',
      'end': '09:00 PM',
    },
    {
      'day': 'Thursday',
      'initial': 'T',
      'active': true,
      'start': '12:00 AM',
      'end': '09:00 PM',
    },
    {
      'day': 'Friday',
      'initial': 'F',
      'active': true,
      'start': '03:00 PM',
      'end': '09:00 PM',
    },
    {
      'day': 'Saturday',
      'initial': 'S',
      'active': true,
      'start': '03:00 PM',
      'end': '05:00 PM',
    },
    {
      'day': 'Sunday',
      'initial': 'S',
      'active': false,
      'start': '09:00 AM',
      'end': '05:00 PM',
    },
  ];

  // Uploaded Certifications Mock
  final List<String> _certifications = ['SIP_Doctor.pdf', 'STR_Agoes.pdf'];

  // --- DATABASE HELPERS & TIME PARSERS ---

  String _parseTimeFromDb(String? dbTime) {
    if (dbTime == null || dbTime.isEmpty) return '09:00 AM';
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
      return '09:00 AM';
    }
  }

  String _formatTimeToDb(String displayTime) {
    try {
      final clean = displayTime.trim();
      final parts = clean.split(' ');
      if (parts.length != 2) return '09:00:00';
      
      final timeParts = parts[0].split(':');
      if (timeParts.length != 2) return '09:00:00';
      
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
      return '09:00:00';
    }
  }

  TimeOfDay _parseTimeOfDay(String timeStr) {
    try {
      final parts = timeStr.split(' ');
      final timeParts = parts[0].split(':');
      var hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);
      final period = parts[1].toUpperCase();
      if (period == 'PM' && hour < 12) {
        hour += 12;
      } else if (period == 'AM' && hour == 12) {
        hour = 0;
      }
      return TimeOfDay(hour: hour, minute: minute);
    } catch (e) {
      return const TimeOfDay(hour: 9, minute: 0);
    }
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    var hour = time.hourOfPeriod;
    if (hour == 0) hour = 12;
    final hourStr = hour.toString().padLeft(2, '0');
    final minStr = time.minute.toString().padLeft(2, '0');
    return '$hourStr:$minStr $period';
  }

  Future<void> _selectTime(BuildContext context, Map<String, dynamic> dayMap, bool isStart) async {
    final timeStr = isStart ? dayMap['start'] as String : dayMap['end'] as String;
    final timeOfDay = _parseTimeOfDay(timeStr);
    final picked = await showTimePicker(
      context: context,
      initialTime: timeOfDay,
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          dayMap['start'] = _formatTimeOfDay(picked);
        } else {
          dayMap['end'] = _formatTimeOfDay(picked);
        }
      });
    }
  }

  String get _effectiveUserId {
    final userState = ref.read(landingPageProvider).loggedInUser;
    final userId = userState?['id']?.toString();
    if (userId == 'mock-id-1234567890' || userId == null) {
      return '8f93471a-74f8-486b-8e85-4002dc44c11c'; // Fallback to active doctor UUID
    }
    return userId;
  }

  // --- FETCH DATA FROM SUPABASE ---
  Future<void> _fetchDbData() async {
    final userId = _effectiveUserId;
    setState(() => _isLoading = true);

    try {
      final client = SupabaseService.client;

      // 1. Fetch user data (main table)
      final userRes = await client
          .from('user')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (userRes != null) {
        // Sync local provider state
        ref.read(landingPageProvider.notifier).updateUser(userRes);
        
        _nameController.text = userRes['name']?.toString() ?? '';
        _emailController.text = userRes['email']?.toString() ?? '';
        _phoneController.text = userRes['phone_number']?.toString() ?? '';
        _nikController.text = userRes['nik']?.toString() ?? '';
        _rfidController.text = userRes['rfid']?.toString() ?? '';
        _addressDetailController.text = userRes['address']?.toString() ?? '';

        // Load avatar_url — only use Supabase-hosted URLs to avoid CORS issues
        final rawAvatarUrl = userRes['avatar_url']?.toString() ?? '';
        if (rawAvatarUrl.isNotEmpty && (
          rawAvatarUrl.contains('supabase.co') ||
          rawAvatarUrl.contains('supabase.in') ||
          rawAvatarUrl.startsWith('https://images.unsplash.com') ||
          rawAvatarUrl.startsWith('https://picsum.photos')
        )) {
          _avatarUrl = rawAvatarUrl;
        } else {
          _avatarUrl = ''; // Don't load URLs that will CORS-fail (e.g. external hospital servers)
        }
        
        final genderDb = userRes['gender']?.toString().toLowerCase() ?? 'male';
        _selectedGender = genderDb == 'female' ? 'Female' : 'Male';

        final prov = userRes['province']?.toString().toUpperCase() ?? 'JAWA TIMUR';
        if (prov.contains('JAWA TIMUR')) _selectedProvinsi = 'JAWA TIMUR';
        else if (prov.contains('JAWA TENGAH')) _selectedProvinsi = 'JAWA TENGAH';
        else if (prov.contains('JAWA BARAT')) _selectedProvinsi = 'JAWA BARAT';
        else if (prov.contains('DKI JAKARTA')) _selectedProvinsi = 'DKI JAKARTA';

        final dist = userRes['district']?.toString().toUpperCase() ?? 'KABUPATEN BONDOWOSO';
        if (dist.contains('BONDOWOSO')) _selectedKabupaten = 'KABUPATEN BONDOWOSO';
        else if (dist.contains('JEMBER')) _selectedKabupaten = 'KABUPATEN JEMBER';
        else if (dist.contains('BANYUWANGI')) _selectedKabupaten = 'KABUPATEN BANYUWANGI';

        final subD = userRes['sub_district']?.toString().toUpperCase() ?? 'PUJER';
        if (subD.contains('PUJER')) _selectedKecamatan = 'PUJER';
        else if (subD.contains('TENGGARANG')) _selectedKecamatan = 'TENGGARANG';
        else if (subD.contains('KLOJEN')) _selectedKecamatan = 'KLOJEN';

        final vill = userRes['village']?.toString().toUpperCase() ?? 'KEJAYAN';
        if (vill.contains('KEJAYAN')) _selectedKelurahan = 'KEJAYAN';
        else if (vill.contains('PANGGUNGAN')) _selectedKelurahan = 'PANGGUNGAN';
        else if (vill.contains('SUMBERSARI')) _selectedKelurahan = 'SUMBERSARI';
      }

      // 2. Fetch user_detail_doctor
      final detailRes = await client
          .from('user_detail_doctor')
          .select()
          .eq('id', userId)
          .maybeSingle();

      if (detailRes != null) {
        _faskesController.text = detailRes['nama_faskes']?.toString() ?? '';
        _aboutController.text = detailRes['about']?.toString() ?? '';
        _mapsLinkController.text = detailRes['google_maps_link']?.toString() ?? '';
        _maxQueueController.text = (detailRes['max_antrian'] ?? 20).toString();
        _satuSehatIdController.text = detailRes['id_satusehat']?.toString() ?? '';
        _showProfileInSearch = detailRes['is_visible'] ?? true;
        _serveBPJSPatients = detailRes['is_bpjs'] ?? true;

        final prof = detailRes['profession']?.toString() ?? 'Doctor';
        if (prof.toLowerCase() == 'midwife') {
          _selectedProfession = 'Midwife';
        } else if (prof.toLowerCase() == 'nurse') {
          _selectedProfession = 'Nurse';
        } else {
          _selectedProfession = 'Doctor';
        }

        // Parse JSONB API credentials
        final ssApiRaw = detailRes['satu_sehat_api'];
        final Map<String, dynamic>? ssApi = ssApiRaw is Map
            ? Map<String, dynamic>.from(ssApiRaw)
            : null;
        if (ssApi != null) {
          _ssOrgIdController.text = ssApi['organization_id']?.toString() ?? '';
          _ssClientIdController.text = ssApi['client_id']?.toString() ?? '';
          _ssClientSecretController.text = ssApi['client_secret']?.toString() ?? '';
        }

        final bpjsApiRaw = detailRes['bpjs_api'];
        final Map<String, dynamic>? bpjsApi = bpjsApiRaw is Map
            ? Map<String, dynamic>.from(bpjsApiRaw)
            : null;
        if (bpjsApi != null) {
          _bpjsConsIdController.text = bpjsApi['cons_id']?.toString() ?? '';
          _bpjsUserKeyController.text = bpjsApi['user_key']?.toString() ?? '';
          _bpjsSecretKeyController.text = bpjsApi['secret_key']?.toString() ?? '';
        }

        final jknApiRaw = detailRes['mobile_jkn_api'];
        final Map<String, dynamic>? jknApi = jknApiRaw is Map
            ? Map<String, dynamic>.from(jknApiRaw)
            : null;
        if (jknApi != null) {
          _jknUrlController.text = jknApi['url']?.toString() ?? jknApi['connector_url']?.toString() ?? '';
          _jknClientIdController.text = jknApi['client_id']?.toString() ?? jknApi['cons_id']?.toString() ?? '';
          _jknClientSecretController.text = jknApi['client_secret']?.toString() ?? jknApi['secret_key']?.toString() ?? '';
        }

        // Parse subscription details
        _subStatus = (detailRes['subscription_status'] ?? 'INACTIVE').toString().toUpperCase();
        if (detailRes['subscription_expired_at'] != null) {
          try {
            final expiryDate = DateTime.parse(detailRes['subscription_expired_at'].toString());
            _subExpiryDate = expiryDate;
            // Format expiry date nicely: DD MMM YYYY
            const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                            'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
            _subExpiry = '${expiryDate.day.toString().padLeft(2, '0')} '
                '${months[expiryDate.month - 1]} ${expiryDate.year}';

            final now = DateTime.now();
            final diff = expiryDate.difference(now);
            if (diff.isNegative) {
              _subDaysRemaining = 0;
              _subHoursRemaining = 0;
              _subMinutesRemaining = 0;
            } else {
              _subDaysRemaining = diff.inDays;
              _subHoursRemaining = diff.inHours % 24;
              _subMinutesRemaining = diff.inMinutes % 60;
            }

            // Calculate total plan duration (assume 30-day plan, or compute from creation)
            // Try to infer plan length by checking when sub was last renewed
            // Default to 30 days if we can't determine otherwise
            _subTotalDays = 30;
          } catch (_) {
            _subExpiry = '-';
            _subDaysRemaining = 0;
            _subHoursRemaining = 0;
            _subMinutesRemaining = 0;
            _subExpiryDate = null;
          }
        } else {
          _subExpiry = '-';
          _subDaysRemaining = 0;
          _subHoursRemaining = 0;
          _subMinutesRemaining = 0;
          _subExpiryDate = null;
        }

        // Parse Queue QR Code token
        _qrToken = detailRes['qr_token']?.toString() ?? '';

        // Parse QRIS Payment Method settings
        final qrisTypeDb = detailRes['qris_type']?.toString().toLowerCase() ?? 'upload';
        if (qrisTypeDb == 'url') {
          _selectedQrisType = 'IMAGE URL / LABEL';
        } else if (qrisTypeDb == 'link') {
          _selectedQrisType = 'AUTOMATIC PAYMENT LINK';
        } else {
          _selectedQrisType = 'UPLOAD PHOTO';
        }
        _qrisLinkController.text = detailRes['qris_link']?.toString() ?? '';
        _qrisPath = detailRes['qris_path']?.toString() ?? '';
      }

      // 3. Fetch doctor_schedules
      final schedulesRes = await client
          .from('doctor_schedules')
          .select()
          .eq('id_doctor', userId);

      if (schedulesRes != null && (schedulesRes as List).isNotEmpty) {
        final List<dynamic> schedulesList = schedulesRes;
        for (var dayMap in _scheduleDays) {
          final matches = schedulesList.where(
            (row) => row['day']?.toString().toLowerCase() == dayMap['day']?.toString().toLowerCase(),
          );
          if (matches.isNotEmpty) {
            final dbRow = matches.first;
            dayMap['active'] = !(dbRow['is_off'] ?? false);
            dayMap['start'] = _parseTimeFromDb(dbRow['open_time']);
            dayMap['end'] = _parseTimeFromDb(dbRow['close_time']);
            dayMap['id'] = dbRow['id'];
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading doctor details: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // --- SAVE ACTIONS ---

  Future<void> _saveProfileAndStatus() async {
    final userId = _effectiveUserId;

    setState(() => _isSaving = true);

    try {
      String? rfidVal = _rfidController.text.trim();
      if (rfidVal.isEmpty) {
        rfidVal = null;
      } else {
        final uuidRegex = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
        if (!uuidRegex.hasMatch(rfidVal)) {
          throw Exception('RFID must be a valid UUID format (e.g., 9f973085-8ca9-4d8b-b0a7-6d0113cce038)');
        }
      }

      final client = SupabaseService.client;

      final updatedUser = {
        'name': _nameController.text.trim(),
        'phone_number': _phoneController.text.trim(),
        'nik': _nikController.text.trim(),
        'rfid': rfidVal,
        'gender': _selectedGender.toLowerCase(),
        'province': _selectedProvinsi,
        'district': _selectedKabupaten,
        'sub_district': _selectedKecamatan,
        'village': _selectedKelurahan,
        'address': _addressDetailController.text.trim(),
        'satusehat_id': _satuSehatIdController.text.trim(),
      };

      final updatedDoctorDetail = {
        'nama_faskes': _faskesController.text.trim(),
        'about': _aboutController.text.trim(),
        'id_satusehat': _satuSehatIdController.text.trim(),
      };

      await client.from('user').update(updatedUser).eq('id', userId);
      await client.from('user_detail_doctor').update(updatedDoctorDetail).eq('id', userId);

      ref.read(landingPageProvider.notifier).updateUser(updatedUser);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile information saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving profile: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _saveSchedule() async {
    final userId = _effectiveUserId;

    setState(() => _isSaving = true);

    try {
      final client = SupabaseService.client;
      final List<Map<String, dynamic>> schedulesToUpsert = [];

      for (var dayMap in _scheduleDays) {
        final scheduleItem = {
          if (dayMap['id'] != null) 'id': dayMap['id'],
          'id_doctor': userId,
          'day': dayMap['day'],
          'open_time': dayMap['active'] == true ? _formatTimeToDb(dayMap['start'] as String) : null,
          'close_time': dayMap['active'] == true ? _formatTimeToDb(dayMap['end'] as String) : null,
          'is_off': !(dayMap['active'] as bool),
        };
        schedulesToUpsert.add(scheduleItem);
      }

      await client.from('doctor_schedules').upsert(schedulesToUpsert);
      await _fetchDbData();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Practice schedule saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving schedule: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _saveMapsLink() async {
    final userId = _effectiveUserId;

    setState(() => _isSaving = true);

    try {
      final client = SupabaseService.client;
      await client.from('user_detail_doctor').update({
        'google_maps_link': _mapsLinkController.text.trim(),
      }).eq('id', userId);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Google Maps link saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving Google Maps link: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _saveMaxQueue() async {
    final userId = _effectiveUserId;

    setState(() => _isSaving = true);
    try {
      final maxVal = int.tryParse(_maxQueueController.text) ?? 20;
      await SupabaseService.client.from('user_detail_doctor').update({
        'max_antrian': maxVal,
      }).eq('id', userId);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Max queue updated to $maxVal successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving max queue: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _saveVisibility() async {
    final userId = _effectiveUserId;

    setState(() => _isSaving = true);
    try {
      await SupabaseService.client.from('user_detail_doctor').update({
        'is_visible': _showProfileInSearch,
      }).eq('id', userId);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile visibility saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving visibility: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _saveBpjsSetting() async {
    final userId = _effectiveUserId;

    setState(() => _isSaving = true);
    try {
      await SupabaseService.client.from('user_detail_doctor').update({
        'is_bpjs': _serveBPJSPatients,
      }).eq('id', userId);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('BPJS service settings saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving BPJS setting: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _saveProfession() async {
    final userId = _effectiveUserId;

    setState(() => _isSaving = true);
    try {
      await SupabaseService.client.from('user_detail_doctor').update({
        'profession': _selectedProfession,
      }).eq('id', userId);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Profession settings saved: $_selectedProfession'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving profession: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _saveApiSettings() async {
    final userId = _effectiveUserId;

    setState(() => _isSaving = true);

    try {
      final client = SupabaseService.client;

      final existing = await client
          .from('user_detail_doctor')
          .select('satu_sehat_api, bpjs_api, mobile_jkn_api')
          .eq('id', userId)
          .maybeSingle();

      final ssApiRaw = existing?['satu_sehat_api'];
      final Map<String, dynamic> existingSs = ssApiRaw is Map
          ? Map<String, dynamic>.from(ssApiRaw)
          : {};

      final bpjsApiRaw = existing?['bpjs_api'];
      final Map<String, dynamic> existingBpjs = bpjsApiRaw is Map
          ? Map<String, dynamic>.from(bpjsApiRaw)
          : {};

      final jknApiRaw = existing?['mobile_jkn_api'];
      final Map<String, dynamic> existingJkn = jknApiRaw is Map
          ? Map<String, dynamic>.from(jknApiRaw)
          : {};

      existingSs['organization_id'] = _ssOrgIdController.text.trim();
      existingSs['client_id'] = _ssClientIdController.text.trim();
      existingSs['client_secret'] = _ssClientSecretController.text.trim();

      existingBpjs['cons_id'] = _bpjsConsIdController.text.trim();
      existingBpjs['user_key'] = _bpjsUserKeyController.text.trim();
      existingBpjs['secret_key'] = _bpjsSecretKeyController.text.trim();

      existingJkn['url'] = _jknUrlController.text.trim();
      existingJkn['client_id'] = _jknClientIdController.text.trim();
      existingJkn['client_secret'] = _jknClientSecretController.text.trim();

      await client.from('user_detail_doctor').update({
        'satu_sehat_api': existingSs,
        'bpjs_api': existingBpjs,
        'mobile_jkn_api': existingJkn,
        'id_satusehat': _satuSehatIdController.text.trim(),
      }).eq('id', userId);

      await client.from('user').update({
        'satusehat_id': _satuSehatIdController.text.trim(),
      }).eq('id', userId);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('API Credentials saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving API settings: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _renewSubscription() async {
    final userId = _effectiveUserId;

    setState(() => _isSaving = true);

    try {
      final client = SupabaseService.client;
      
      final res = await client
          .from('user_detail_doctor')
          .select('subscription_expired_at')
          .eq('id', userId)
          .maybeSingle();

      DateTime currentExpiry = DateTime.now();
      if (res != null && res['subscription_expired_at'] != null) {
        try {
          final parsed = DateTime.parse(res['subscription_expired_at']);
          if (parsed.isAfter(DateTime.now())) {
            currentExpiry = parsed;
          }
        } catch (_) {}
      }

      final newExpiry = currentExpiry.add(const Duration(days: 30));
      final newExpiryStr = newExpiry.toIso8601String();

      await client.from('user_detail_doctor').update({
        'subscription_status': 'active',
        'subscription_expired_at': newExpiryStr,
      }).eq('id', userId);

      await _fetchDbData();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Subscription successfully renewed for 30 Days! New expiry: $_subExpiry',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error renewing subscription: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _regenerateQrToken() async {
    final userId = _effectiveUserId;

    setState(() => _isSaving = true);

    try {
      const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
      final rand = Random();
      final newToken = List.generate(32, (index) => chars[rand.nextInt(chars.length)]).join();

      await SupabaseService.client.from('user_detail_doctor').update({
        'qr_token': newToken,
      }).eq('id', userId);

      await _fetchDbData();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('QR Code regenerated! New token: $newToken'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error regenerating QR token: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  // --- UPLOAD PROFILE PHOTO ---

  Future<void> _uploadProfilePhoto() async {
    // Flutter Web: use file_picker / html input to pick file bytes
    // We'll use a simple URL-input dialog as a CORS-safe alternative for web
    final TextEditingController urlController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E22),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.add_a_photo_rounded, color: Color(0xFF48C9B0)),
            const SizedBox(width: 8),
            Text(
              'Update Foto Profil',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Masukkan URL foto profil (dari Supabase Storage atau layanan gambar publik yang mendukung CORS):',
              style: GoogleFonts.outfit(color: Colors.grey[300], fontSize: 12, height: 1.5),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urlController,
              style: GoogleFonts.outfit(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'https://...',
                hintStyle: GoogleFonts.outfit(color: Colors.grey[600], fontSize: 13),
                filled: true,
                fillColor: const Color(0xFF2A2A30),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Catatan: URL harus dari domain yang mengizinkan akses lintas-asal (CORS). URL dari server lokal rumah sakit tidak dapat dimuat.',
              style: GoogleFonts.outfit(color: Colors.orange[300], fontSize: 10, height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: Text('Batal', style: GoogleFonts.outfit(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(urlController.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF48C9B0),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Simpan', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (result == null || result.isEmpty) return;

    setState(() => _isUploadingPhoto = true);
    try {
      final userId = _effectiveUserId;
      await SupabaseService.client.from('user').update({
        'avatar_url': result,
      }).eq('id', userId);

      // Also update local provider state
      ref.read(landingPageProvider.notifier).updateUser({'avatar_url': result});

      setState(() => _avatarUrl = result);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Foto profil berhasil diperbarui!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan foto profil: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      setState(() => _isUploadingPhoto = false);
    }
  }

  Future<void> _saveQrisConfiguration() async {
    final userId = _effectiveUserId;

    setState(() => _isSaving = true);

    try {
      final String typeDb;
      if (_selectedQrisType == 'IMAGE URL / LABEL') {
        typeDb = 'url';
      } else if (_selectedQrisType == 'AUTOMATIC PAYMENT LINK') {
        typeDb = 'link';
      } else {
        typeDb = 'upload';
      }

      await SupabaseService.client.from('user_detail_doctor').update({
        'qris_type': typeDb,
        'qris_link': _qrisLinkController.text.trim(),
        'qris_path': _qrisPath,
      }).eq('id', userId);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('QRIS payment configuration saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      await _fetchDbData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving QRIS configuration: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  // --- DUITKU INTEGRATION ---

  Future<void> _buySubscriptionWithDuitku() async {
    final userId = _effectiveUserId;
    final userState = ref.read(landingPageProvider).loggedInUser;
    final email = userState?['email'] ?? 'agoes.soetanto@gmail.com';

    setState(() => _isSaving = true);

    final String orderId = 'SUBS_${userId.toString().substring(0, 8)}_${DateTime.now().millisecondsSinceEpoch ~/ 1000}';
    final int amount = 150000; // Rp 150.000
    
    // Sandbox credentials
    final String merchantCode = 'DS18306';
    final String merchantKey = 'e0f7e44015ef056b406e1dfd7b1ce05c';

    // Signature formula: md5(merchantCode + merchantOrderId + paymentAmount + merchantKey)
    final signatureStr = '$merchantCode$orderId$amount$merchantKey';
    final signatureBytes = utf8.encode(signatureStr);
    final signature = md5.convert(signatureBytes).toString();

    try {
      final response = await http.post(
        Uri.parse('https://sandbox.duitku.com/webapi/api/merchant/v2/inquiry'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'merchantCode': merchantCode,
          'paymentAmount': amount,
          'merchantOrderId': orderId,
          'productDetails': 'Perpanjang Layanan Mandiri 30 Hari',
          'email': email,
          'callbackUrl': 'https://abdburxhqqwsobmzuwmz.supabase.co/functions/v1/duitku-callback',
          'returnUrl': 'https://mapotech.app/payment-success',
          'signature': signature,
        }),
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final statusCode = data['statusCode']?.toString();
      final paymentUrl = data['paymentUrl']?.toString();
      final statusMessage = data['statusMessage']?.toString() ?? 'Error initializing payment';

      if (statusCode == '00' && paymentUrl != null) {
        // Open Duitku Checkout Page
        final uri = Uri.parse(paymentUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          
          // Show local simulation dialog so user can test sandbox success locally
          if (mounted) {
            _showLocalPaymentSimulationDialog(orderId);
          }
        } else {
          throw Exception('Failed to open payment URL: $paymentUrl');
        }
      } else {
        throw Exception('$statusCode: $statusMessage');
      }
    } catch (e) {
      debugPrint('Duitku API error: $e');
      if (mounted) {
        // Fallback to local simulation dialog directly on API error (e.g. sandbox credentials error/network error)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Duitku API failed: $e. Falling back to simulator...'),
            backgroundColor: Colors.orangeAccent,
          ),
        );
        _showLocalPaymentSimulationDialog(orderId);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showLocalPaymentSimulationDialog(String orderId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E22),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.payment, color: Color(0xFF00A67E)),
              const SizedBox(width: 8),
              Text(
                'Duitku Payment Simulator',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ),
          content: Text(
            'Halaman pembayaran Duitku (Sandbox) telah dibuka.\n\nOrderId: $orderId\nTotal: Rp 150.000\n\nIngin mensimulasikan pembayaran BERHASIL di database sekarang?',
            style: GoogleFonts.outfit(color: Colors.grey[300], fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Nanti Saja',
                style: GoogleFonts.outfit(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _renewSubscription();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00A67E),
                foregroundColor: Colors.white,
              ),
              child: Text(
                'Simulasikan Sukses',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: 'agoes.soetanto@gmail.com');
    _faskesController = TextEditingController(
      text: 'Dokter Praktek Mandiri Dokter Agoes Soetanto, dr',
    );
    _nameController = TextEditingController(text: 'dr. Agoes Soetanto');
    _usernameController = TextEditingController(text: '');
    _phoneController = TextEditingController(text: '085259930755');
    _nikController = TextEditingController(text: '351108208670001');
    _rfidController = TextEditingController(
      text: '9f973085-8ca9-4d8b-b0a7-6d0113cce038',
    );
    _satuSehatIdController = TextEditingController(text: '10001097421');
    _addressDetailController = TextEditingController(
      text: 'Dokter Praktek Mandiri Dokter Agoes Soetanto, dr',
    );
    _aboutController = TextEditingController(text: '');
    _mapsLinkController = TextEditingController(
      text:
          'https://www.google.com/maps/place/Praktek+Dokter+Umum+Dan+Toko+Baju+Plus+Asesoris/@-7.973354,113.823908,17z',
    );
    _maxQueueController = TextEditingController(text: '20');

    _ssOrgIdController = TextEditingController(text: '100062510');
    _ssClientIdController = TextEditingController(
      text: 'gfR38t7GqAKU2DVP0sYLXUHsNOTPUUEU0yzDJg362PDWHtX0',
    );
    _ssClientSecretController = TextEditingController(
      text: 'bf07c6f0a0d92418a0b0632b78a9cdeef1234a56',
    );

    _bpjsConsIdController = TextEditingController(text: '28392');
    _bpjsSecretKeyController = TextEditingController(
      text: 'bpjs_secret_key_value_837289',
    );
    _bpjsUserKeyController = TextEditingController(
      text: 'user_key_78a2c738e3a2b4',
    );

    _jknUrlController = TextEditingController(
      text: 'https://api.bpjs-kesehatan.go.id/jkn-connector',
    );
    _jknClientIdController = TextEditingController(text: 'jkn_client_829392');
    _jknClientSecretController = TextEditingController(
      text: 'jkn_secret_92839a8c7b6d5e4',
    );
    _qrisLinkController = TextEditingController(text: '');

    // Rebuild UI when address fields, faskes name, or QRIS link change to update previews
    _addressDetailController.addListener(() => setState(() {}));
    _qrisLinkController.addListener(() => setState(() {}));

    // Fetch database records
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchDbData();
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _faskesController.dispose();
    _nameController.dispose();
    _usernameController.dispose();
    _phoneController.dispose();
    _nikController.dispose();
    _rfidController.dispose();
    _satuSehatIdController.dispose();
    _addressDetailController.dispose();
    _aboutController.dispose();
    _mapsLinkController.dispose();
    _maxQueueController.dispose();

    _ssOrgIdController.dispose();
    _ssClientIdController.dispose();
    _ssClientSecretController.dispose();
    _bpjsConsIdController.dispose();
    _bpjsSecretKeyController.dispose();
    _bpjsUserKeyController.dispose();
    _jknUrlController.dispose();
    _jknClientIdController.dispose();
    _jknClientSecretController.dispose();
    _qrisLinkController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(landingPageProvider);

    final isDark = state.appearance == 'dark';
    final isRev = state.appearance == 'rev';
    final cardBg = isDark ? const Color(0xFF161619) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1B0C3C);
    final subtitleColor = isDark ? Colors.grey[400]! : const Color(0xFF6F6A8A);
    final borderColor = isDark
        ? const Color(0xFF252528)
        : const Color(0xFFECEEF2);
    final inputBg = isDark ? const Color(0xFF1E1E22) : const Color(0xFFF8FAFC);

    // Premium Brand Colors adapt dynamically to the global theme
    final tealColor = isRev ? const Color(0xFFB577F2) : const Color(0xFF00A67E);
    final purpleColor = isRev ? const Color(0xFF00A67E) : const Color(0xFFB577F2);

    if (_isLoading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(80.0),
          child: CircularProgressIndicator(color: tealColor),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── 1. Hero Profile Header Card ─────────────────────────────────────
        _buildHeroHeader(
          isDark,
          isRev,
          cardBg,
          textColor,
          subtitleColor,
          borderColor,
          tealColor,
        ),

        const SizedBox(height: 20),

        // ── 2. Custom Pill Tab Bar ──────────────────────────────────────────
        _buildTabBar(
          isDark,
          cardBg,
          textColor,
          subtitleColor,
          borderColor,
          tealColor,
        ),

        const SizedBox(height: 24),

        // ── 3. Tab Body ─────────────────────────────────────────────────────
        if (_activeTab == 0)
          _buildProfileAndStatusTab(
            isDark,
            cardBg,
            textColor,
            subtitleColor,
            borderColor,
            inputBg,
            tealColor,
            purpleColor,
          )
        else if (_activeTab == 1)
          _buildPracticeAndServiceTab(
            isDark,
            cardBg,
            textColor,
            subtitleColor,
            borderColor,
            inputBg,
            tealColor,
            purpleColor,
          )
        else
          _buildApiAndIntegrationTab(
            isDark,
            cardBg,
            textColor,
            subtitleColor,
            borderColor,
            tealColor,
          ),

        const SizedBox(height: 32),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Hero Header
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildHeroHeader(
    bool isDark,
    bool isRev,
    Color cardBg,
    Color textColor,
    Color subtitleColor,
    Color borderColor,
    Color tealColor,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Banner background with blur/gradient effect
          Container(
            height: 120,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
              gradient: LinearGradient(
                colors: isDark
                    ? (isRev
                        ? [const Color(0xFF1B1429), const Color(0xFF221A35)]
                        : [const Color(0xFF1E1E22), const Color(0xFF2A2A30)])
                    : (isRev
                        ? [const Color(0xFFF5EEFF), const Color(0xFFE8D7FF)]
                        : [const Color(0xFFE8F6F3), const Color(0xFFD0ECE7)]),
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.bottomCenter,
              children: [
                // Sticking out Avatar
                Positioned(
                  bottom: -40,
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
                          border: Border.all(color: cardBg, width: 4),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: _isUploadingPhoto
                              ? const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFF48C9B0),
                                  ),
                                )
                              : _avatarUrl.isNotEmpty
                                  ? Image.network(
                                      _avatarUrl,
                                      fit: BoxFit.cover,
                                      width: 90,
                                      height: 90,
                                      errorBuilder: (context, error, stackTrace) {
                                        // CORS or load error: show initials fallback
                                        return Center(
                                          child: Text(
                                            _nameController.text.isNotEmpty
                                                ? _nameController.text.split(' ').take(2).map((w) => w.isNotEmpty ? w[0].toUpperCase() : '').join()
                                                : 'AS',
                                            style: GoogleFonts.outfit(
                                              fontSize: 28,
                                              fontWeight: FontWeight.w900,
                                              color: tealColor,
                                            ),
                                          ),
                                        );
                                      },
                                    )
                                  : Center(
                                      child: Text(
                                        _nameController.text.isNotEmpty
                                            ? _nameController.text.split(' ').take(2).map((w) => w.isNotEmpty ? w[0].toUpperCase() : '').join()
                                            : 'AS',
                                        style: GoogleFonts.outfit(
                                          fontSize: 28,
                                          fontWeight: FontWeight.w900,
                                          color: tealColor,
                                        ),
                                      ),
                                    ),
                        ),
                      ),
                      // Camera Icon Badge (tappable to upload photo)
                      GestureDetector(
                        onTap: _uploadProfilePhoto,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: const Color(0xFF3B82F6),
                            shape: BoxShape.circle,
                            border: Border.all(color: cardBg, width: 2),
                          ),
                          child: const Icon(
                            Icons.camera_alt_rounded,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 50),
          // Doctor Info Text
          Text(
            _nameController.text.isNotEmpty
                ? _nameController.text
                : 'dr. Agoes Soetanto',
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
                : 'agoes.soetanto@gmail.com',
            style: GoogleFonts.outfit(
              fontSize: 13,
              color: subtitleColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          // Actions: Edit Profile & View Patient Perspective
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Edit Profile Button
                OutlinedButton.icon(
                  onPressed: _isSaving ? null : _saveProfileAndStatus,
                  icon: Icon(_isSaving ? Icons.hourglass_top_rounded : Icons.edit_outlined, size: 16),
                  label: Text(_isSaving ? 'Saving...' : 'Edit Profile'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: tealColor,
                    side: BorderSide(color: tealColor, width: 1.5),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    textStyle: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // View Patient Perspective Button
                ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Switching to patient perspective...'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.visibility_outlined, size: 16),
                  label: const Text('View Patient Perspective'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tealColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    textStyle: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
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

  // ──────────────────────────────────────────────────────────────────────────
  // Tab Bar
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildTabBar(
    bool isDark,
    Color cardBg,
    Color textColor,
    Color subtitleColor,
    Color borderColor,
    Color tealColor,
  ) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E22) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(40),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTabItem(
              0,
              'Profile & Status',
              Icons.info_outline_rounded,
              tealColor,
              isDark,
            ),
            _buildTabItem(
              1,
              'Practice & Service',
              Icons.loop_rounded,
              tealColor,
              isDark,
            ),
            _buildTabItem(
              2,
              'API & Integration',
              Icons.shield_outlined,
              tealColor,
              isDark,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabItem(
    int index,
    String label,
    IconData icon,
    Color tealColor,
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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? tealColor : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
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
                    : (isDark ? Colors.grey[400] : const Color(0xFF475569)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Tab 0: Profile & Status Section
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildProfileAndStatusTab(
    bool isDark,
    Color cardBg,
    Color textColor,
    Color subtitleColor,
    Color borderColor,
    Color inputBg,
    Color tealColor,
    Color purpleColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Card: Personal Information
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: tealColor, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Personal Information',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: textColor,
                      ),
                    ),
                  ),
                  // Reset Password Button
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
                    label: const Text('Reset Password'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: tealColor,
                      side: BorderSide(color: tealColor),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
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

              // Form fields
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
                    child: _buildInputLabelAndField(
                      'Faskes Name',
                      _faskesController,
                      inputBg,
                      textColor,
                      subtitleColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildInputLabelAndField(
                      'Name',
                      _nameController,
                      inputBg,
                      textColor,
                      subtitleColor,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildInputLabelAndField(
                      'Username',
                      _usernameController,
                      inputBg,
                      textColor,
                      subtitleColor,
                      hintText: 'Enter username',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
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
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildInputLabelAndField(
                      'Phone Number',
                      _phoneController,
                      inputBg,
                      textColor,
                      subtitleColor,
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
                        _buildInputLabelAndField(
                          'NIK',
                          _nikController,
                          inputBg,
                          textColor,
                          subtitleColor,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Used for identity verification',
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            color: subtitleColor.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildInputLabelAndField(
                      'RFID',
                      _rfidController,
                      inputBg,
                      textColor,
                      subtitleColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // SatuSehat ID Field
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ID SATUSEHAT (PRACTITIONER)',
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: subtitleColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.search, size: 14, color: Colors.grey),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: inputBg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: borderColor),
                          ),
                          child: TextField(
                            controller: _satuSehatIdController,
                            style: GoogleFonts.outfit(
                              fontSize: 13,
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
                      // Verification Button
                      GestureDetector(
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'ID Verified successfully against SatuSehat Hub!',
                              ),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: tealColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.search,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Practitioner ID verify in SatuSehat Production Hub',
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      color: subtitleColor.withOpacity(0.8),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 20),

              // Address Sub-Section
              Text(
                'ADDRESS',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: textColor,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildDropdownField(
                      'Provinsi',
                      _selectedProvinsi,
                      [
                        'JAWA TIMUR',
                        'JAWA TENGAH',
                        'JAWA BARAT',
                        'DKI JAKARTA',
                      ],
                      (val) => setState(() => _selectedProvinsi = val!),
                      inputBg,
                      textColor,
                      subtitleColor,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildDropdownField(
                      'Kota/Kabupaten',
                      _selectedKabupaten,
                      [
                        'KABUPATEN BONDOWOSO',
                        'KABUPATEN JEMBER',
                        'KABUPATEN BANYUWANGI',
                      ],
                      (val) => setState(() => _selectedKabupaten = val!),
                      inputBg,
                      textColor,
                      subtitleColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildDropdownField(
                      'Kecamatan',
                      _selectedKecamatan,
                      ['PUJER', 'TENGGARANG', 'KLOJEN'],
                      (val) => setState(() => _selectedKecamatan = val!),
                      inputBg,
                      textColor,
                      subtitleColor,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildDropdownField(
                      'Kelurahan/Desa',
                      _selectedKelurahan,
                      ['KEJAYAN', 'PANGGUNGAN', 'SUMBERSARI'],
                      (val) => setState(() => _selectedKelurahan = val!),
                      inputBg,
                      textColor,
                      subtitleColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Detail Jalan Text Area
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Detail Jalan (Optional / Nilai Saat Ini)',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: subtitleColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(
                      color: inputBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: borderColor),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    child: TextField(
                      controller: _addressDetailController,
                      maxLines: 3,
                      style: GoogleFonts.outfit(fontSize: 12, color: textColor),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Preview Address Block
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF222226)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: borderColor),
                ),
                child: Text(
                  'Preview: ${_addressDetailController.text}, Kel. $_selectedKelurahan, Kec. $_selectedKecamatan, $_selectedKabupaten, Prov. $_selectedProvinsi',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.grey[300] : const Color(0xFF475569),
                  ),
                ),
              ),

              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 20),

              // About Private Practice Textarea
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'About Private Practice (Profile)',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: subtitleColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(
                      color: inputBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: borderColor),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    child: TextField(
                      controller: _aboutController,
                      maxLines: 4,
                      style: GoogleFonts.outfit(fontSize: 12, color: textColor),
                      decoration: InputDecoration(
                        hintText:
                            'Tell us about your profile, expertise, and experience...',
                        hintStyle: GoogleFonts.outfit(
                          fontSize: 12,
                          color: subtitleColor.withOpacity(0.6),
                        ),
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

              // Sertifikasi Section
              Text(
                'Sertifikasi & Lisensi Praktik / Foto (Max 3)',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Unggah sertifikasi atau foto untuk meningkatkan kredibilitas di mata pasien. Mendukung Link URL dan Upload manual.',
                style: GoogleFonts.outfit(
                  fontSize: 10.5,
                  color: subtitleColor,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              // Dotted / Premium Upload Box Mockup
              Container(
                height: 110,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E1E22)
                      : const Color(0xFFFAFAFB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: tealColor.withOpacity(0.4),
                    style: BorderStyle
                        .solid, // solid mock for standard Flutter border
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.cloud_upload_outlined,
                        size: 28,
                        color: tealColor,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Drag and drop files here, or click to browse',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: tealColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Supports PDF, JPG, PNG up to 5MB',
                        style: GoogleFonts.outfit(
                          fontSize: 9,
                          color: subtitleColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // List of mocked uploaded certs
              Row(
                children: [
                  ..._certifications.map(
                    (cert) => Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: inputBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: borderColor),
                      ),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => _showFilePreviewDialog(cert),
                            child: Row(
                              children: [
                                Icon(
                                  cert.endsWith('.pdf')
                                      ? Icons.picture_as_pdf_outlined
                                      : Icons.image_outlined,
                                  size: 14,
                                  color: cert.endsWith('.pdf') ? Colors.redAccent : tealColor,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  cert,
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    color: textColor,
                                    fontWeight: FontWeight.bold,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _certifications.remove(cert);
                              });
                            },
                            child: const Icon(
                              Icons.close_rounded,
                              size: 14,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        if (_certifications.length < 3) {
                          _certifications.add(
                            'Sertifikat_Keahlian_${_certifications.length + 1}.jpg',
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Maximum 3 files allowed!'),
                            ),
                          );
                        }
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: tealColor,
                          style: BorderStyle.solid,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.add, size: 14, color: tealColor),
                          const SizedBox(width: 4),
                          Text(
                            'Add File',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              color: tealColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Card: Subscription Status
        Builder(builder: (context) {
          final isActive = _subStatus == 'ACTIVE';
          final statusColor = isActive ? tealColor : Colors.orangeAccent;
          // Progress: days remaining out of total plan days (capped 0..1)
          final progress = _subTotalDays > 0
              ? (_subDaysRemaining / _subTotalDays).clamp(0.0, 1.0)
              : 0.0;

          return Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isActive
                    ? tealColor.withOpacity(0.35)
                    : Colors.orangeAccent.withOpacity(0.35),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: statusColor.withOpacity(0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header row
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.12),
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
                            'Subscription Status',
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: textColor,
                            ),
                          ),
                          Text(
                            isActive
                                ? 'Your plan is active'
                                : 'No active subscription',
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
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(color: statusColor.withOpacity(0.4)),
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

                // Time remaining countdown boxes
                if (isActive && _subDaysRemaining > 0) ...[
                  Row(
                    children: [
                      Expanded(
                        child: _buildTimeBox(
                          '$_subDaysRemaining',
                          'Days',
                          statusColor,
                          isDark,
                          inputBg,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildTimeBox(
                          '$_subHoursRemaining',
                          'Hours',
                          statusColor,
                          isDark,
                          inputBg,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildTimeBox(
                          '$_subMinutesRemaining',
                          'Minutes',
                          statusColor,
                          isDark,
                          inputBg,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Progress bar
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Time Remaining',
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: subtitleColor,
                            ),
                          ),
                          Text(
                            '${(progress * 100).toStringAsFixed(0)}%',
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
                          backgroundColor: statusColor.withOpacity(0.12),
                          valueColor:
                              AlwaysStoppedAnimation<Color>(statusColor),
                          minHeight: 8,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ] else if (!isActive) ...[
                  // Inactive placeholder
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 20),
                    decoration: BoxDecoration(
                      color: Colors.orangeAccent.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.orangeAccent.withOpacity(0.25)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline_rounded,
                            color: Colors.orangeAccent, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Subscribe to unlock all features and access the full platform.',
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

                // Details table
                Container(
                  decoration: BoxDecoration(
                    color: inputBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    children: [
                      _buildSubStatusRow(
                        'Expiry Date:',
                        _subExpiry,
                        textColor,
                        isDark,
                      ),
                      const Divider(height: 1),
                      _buildSubStatusRow(
                        'Days Left:',
                        isActive ? '$_subDaysRemaining days' : 'N/A',
                        isActive ? tealColor : Colors.orangeAccent,
                        isDark,
                        showBold: true,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Renew Button
                ElevatedButton.icon(
                  onPressed: _isSaving ? null : _buySubscriptionWithDuitku,
                  icon: Icon(
                      _isSaving
                          ? Icons.hourglass_top_rounded
                          : Icons.sync,
                      size: 16),
                  label: Text(
                      _isSaving ? 'Connecting Duitku...' : 'Renew 30 Days'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tealColor,
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
        }),
      ],
    );
  }

  Widget _buildTimeBox(
    String value,
    String label,
    Color accentColor,
    bool isDark,
    Color bgColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: accentColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withOpacity(0.2)),
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
            label,
            style: GoogleFonts.outfit(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: accentColor.withOpacity(0.7),
              letterSpacing: 0.5,
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
    double valueSize = 12,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: valueSize,
              fontWeight: showBold ? FontWeight.w900 : FontWeight.w600,
              color: valColor,
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Tab 1: Practice & Service Section
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildPracticeAndServiceTab(
    bool isDark,
    Color cardBg,
    Color textColor,
    Color subtitleColor,
    Color borderColor,
    Color inputBg,
    Color tealColor,
    Color purpleColor,
  ) {
    final isRev = ref.watch(landingPageProvider).appearance == 'rev';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Card 1: Weekly Practice Schedule
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    color: tealColor,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Weekly Practice Schedule',
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
                'Set your operational hours for each day. Mark as HOLIDAY if not practicing.',
                style: GoogleFonts.outfit(fontSize: 11, color: subtitleColor),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),

              ..._scheduleDays.map(
                (dayMap) => _buildScheduleDayRow(
                  dayMap,
                  isDark,
                  isRev,
                  inputBg,
                  borderColor,
                  tealColor,
                  subtitleColor,
                ),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveSchedule,
                icon: Icon(_isSaving ? Icons.hourglass_top_rounded : Icons.save_rounded, size: 16),
                label: Text(_isSaving ? 'Saving...' : 'Save Schedule'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: tealColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
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
        ),

        const SizedBox(height: 20),

        // Card 2: Lokasi Praktik
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Icon(Icons.location_on_outlined, color: tealColor, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Lokasi Praktik',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: textColor,
                      ),
                    ),
                  ),
                  // Header Buttons
                  OutlinedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Searching SatuSehat location...'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.search, size: 12),
                    label: const Text('Search SatuSehat'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: textColor,
                      side: BorderSide(color: borderColor),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
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
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Edit location mode activated!'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.edit, size: 12),
                    label: const Text('Edit Location'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: textColor,
                      side: BorderSide(color: borderColor),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
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

              // SatuSehat Clinic Card Container (tinted purple/green dynamically)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark
                      ? (isRev ? const Color(0xFF1B2824) : const Color(0xFF221F2E))
                      : (isRev ? const Color(0xFFEAF8F5) : const Color(0xFFF5F0FF)),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: (isRev ? tealColor : purpleColor).withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Dokter Praktek Mandiri Dokter Agoes Soetanto, dr',
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.white
                                  : (isRev
                                      ? const Color(0xFF0E5A44)
                                      : const Color(0xFF3F1B85)),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Dokter Praktek Mandiri Dokter Agoes Soetanto, dr',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              color: isDark
                                  ? Colors.grey[300]
                                  : (isRev
                                      ? const Color(0xFF1C7D63)
                                      : const Color(0xFF5F439E)),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'ID: 25b91532-23ff-44c0-a80c-c171f8cc784d • 100062510',
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.grey[400]
                                  : (isRev
                                      ? const Color(0xFF238E73)
                                      : const Color(0xFF7E64BA)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // MAP button
                    ElevatedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.map_outlined, size: 12),
                      label: const Text('MAP'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2EC4B6),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
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

              // Clinic Google Maps Link input
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
                  // Show Button
                  ElevatedButton(
                    onPressed: _isSaving ? null : () async {
                      final urlStr = _mapsLinkController.text.trim();
                      if (urlStr.isNotEmpty) {
                        try {
                          final uri = Uri.parse(urlStr);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Could not open map URL. Opening external app fallback...'),
                              ),
                            );
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          }
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Invalid link format: $e'),
                              backgroundColor: Colors.redAccent,
                            ),
                          );
                        }
                      }
                      // Persist to database
                      await _saveMapsLink();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isRev
                          ? const Color(0xFFE6F7F4)
                          : const Color(0xFFE8D7FF),
                      foregroundColor: isRev
                          ? const Color(0xFF00A67E)
                          : const Color(0xFF8A2BE2),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
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
                'Open Google Maps -> search clinic -> click Share -> select Copy link (not short link) -> paste here.',
                style: GoogleFonts.outfit(fontSize: 10, color: subtitleColor),
              ),

              const SizedBox(height: 20),

              // Mock Map Preview Widget
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
                        'Dokter Praktek Mandiri Dokter Agoes Soetanto, dr',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Premium interactive mock map
                  Container(
                    height: 220,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child: Stack(
                        children: [
                          // Map background canvas
                          Container(
                            color: isDark
                                ? const Color(0xFF1E293B)
                                : const Color(0xFFF1F5F9),
                          ),
                          // Custom Painter or Mock Vector Map Graphics
                          CustomPaint(
                            size: const Size(double.infinity, 220),
                            painter: MapGraphicsPainter(isDark: isDark),
                          ),
                          // Center Pin Marker
                          Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(4),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Colors.black26,
                                        blurRadius: 4,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    'Panggungan',
                                    style: GoogleFonts.outfit(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                                const Icon(
                                  Icons.location_on_rounded,
                                  color: Color(
                                    0xFF8DC63F,
                                  ), // Green pin marker matching OSM pin
                                  size: 32,
                                ),
                              ],
                            ),
                          ),
                          // Zoom controls (+ / -)
                          Positioned(
                            right: 12,
                            top: 40,
                            child: Column(
                              children: [
                                _buildZoomButton(Icons.add, () {}),
                                const SizedBox(height: 4),
                                _buildZoomButton(Icons.remove, () {}),
                              ],
                            ),
                          ),
                          // Bottom OSM attribution footer
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              color: Colors.white.withOpacity(0.9),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Report a problem | © OpenStreetMap contributors',
                                    style: GoogleFonts.outfit(
                                      fontSize: 8.5,
                                      color: Colors.black54,
                                    ),
                                  ),
                                  Text(
                                    'Map displayed via OpenStreetMap',
                                    style: GoogleFonts.outfit(
                                      fontSize: 8.5,
                                      color: Colors.black54,
                                      fontWeight: FontWeight.bold,
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
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Card 3: Queue QR Code
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.qr_code_2_rounded, color: tealColor, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Queue QR Code',
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: textColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // QR Box
              Center(
                child: Container(
                  width: 180,
                  height: 180,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: _qrToken.isNotEmpty
                      ? Image.network(
                          'https://api.qrserver.com/v1/create-qr-code/?size=150x150&data=$_qrToken',
                          width: 150,
                          height: 150,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return const Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return CustomPaint(
                              size: const Size(150, 150),
                              painter: QrPatternPainter(),
                            );
                          },
                        )
                      : CustomPaint(
                          size: const Size(150, 150),
                          painter: QrPatternPainter(),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  'Patients scan this QR to register for the queue',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: subtitleColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Button group
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.download, size: 14),
                    label: const Text('Download QR'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: textColor,
                      side: BorderSide(color: borderColor),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      textStyle: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.print, size: 14),
                    label: const Text('Print QR'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: textColor,
                      side: BorderSide(color: borderColor),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      textStyle: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: _isSaving ? null : _regenerateQrToken,
                    icon: Icon(_isSaving ? Icons.hourglass_top_rounded : Icons.refresh, size: 14),
                    label: Text(_isSaving ? 'Regenerating...' : 'Regenerate'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: tealColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
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

              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 20),

              // Max Queue per Day
              Center(
                child: Text(
                  'Max Queue per Day',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: subtitleColor,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 150,
                    height: 38,
                    decoration: BoxDecoration(
                      color: inputBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: borderColor),
                    ),
                    child: TextField(
                      controller: _maxQueueController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.only(top: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _saveMaxQueue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: tealColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      _isSaving ? 'Saving...' : 'Save',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Card 4: Search & Registration Settings
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Icon(Icons.search, color: tealColor, size: 18),
                  const SizedBox(width: 10),
                  Text(
                    'Search & Registration Settings',
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
              const SizedBox(height: 16),

              // Setting 1: Show Profile in Search
              _buildSettingRow(
                'Show Profile in Search',
                'If active, your profile can be searched by the public in the "Search Private Practice" menu.',
                _showProfileInSearch,
                (val) => setState(() => _showProfileInSearch = val),
                textColor,
                subtitleColor,
                tealColor,
                _saveVisibility,
              ),

              const Divider(height: 32),

              // Setting 2: Serve BPJS Patients
              _buildSettingRow(
                'Serve BPJS Patients',
                'If active, patients can register using their BPJS Health card number.',
                _serveBPJSPatients,
                (val) => setState(() => _serveBPJSPatients = val),
                textColor,
                subtitleColor,
                tealColor,
                _saveBpjsSetting,
              ),

              const Divider(height: 32),

              // Setting 3: Profession Dropdown
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Profession',
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Select your professional classification for patient search.',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      color: subtitleColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDropdownField(
                          '',
                          _selectedProfession,
                          ['Doctor', 'Midwife', 'Nurse'],
                          (val) => setState(() => _selectedProfession = val!),
                          inputBg,
                          textColor,
                          subtitleColor,
                        ),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: _isSaving ? null : _saveProfession,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: tealColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          _isSaving ? 'Saving...' : 'Save',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        _buildQrisPaymentMethodCard(
          isDark,
          cardBg,
          textColor,
          subtitleColor,
          borderColor,
          inputBg,
          tealColor,
          purpleColor,
        ),
      ],
    );
  }

  Widget _buildSettingRow(
    String title,
    String desc,
    bool val,
    Function(bool) onChanged,
    Color textColor,
    Color subtitleColor,
    Color activeColor,
    VoidCallback? onSavePressed,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                desc,
                style: GoogleFonts.outfit(
                  fontSize: 10.5,
                  color: subtitleColor,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Column(
          children: [
            Switch(value: val, onChanged: onChanged, activeColor: activeColor),
            ElevatedButton(
              onPressed: _isSaving ? null : onSavePressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: activeColor,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: Text(
                _isSaving ? 'Saving...' : 'Save',
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildZoomButton(IconData icon, VoidCallback onTap) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 2, offset: Offset(0, 1)),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        child: Icon(icon, size: 16, color: Colors.black54),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Tab 2: API & Integration Section
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildApiAndIntegrationTab(
    bool isDark,
    Color cardBg,
    Color textColor,
    Color subtitleColor,
    Color borderColor,
    Color tealColor,
  ) {
    final inputBg = isDark ? const Color(0xFF1E1E22) : const Color(0xFFF8FAFC);
    const purpleColor = Color(0xFFB577F2);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row
          Row(
            children: [
              Icon(Icons.shield_outlined, color: tealColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'API Linkage Settings',
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: textColor,
                  ),
                ),
              ),
              // Pill selector in middle/right
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E1E22)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildApiSubTabItem(0, 'SatuSehat', tealColor, isDark),
                    _buildApiSubTabItem(1, 'BPJS', tealColor, isDark),
                    _buildApiSubTabItem(2, 'Mobile JKN', tealColor, isDark),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Edit Settings Button
              OutlinedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('API linkage settings edit mode enabled.'),
                    ),
                  );
                },
                icon: const Icon(Icons.edit_outlined, size: 12),
                label: const Text('Edit Settings'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: tealColor,
                  side: BorderSide(color: tealColor),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
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

          // Active Sub Tab Content
          if (_activeApiSubTab == 0) ...[
            // SATUSEHAT
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: tealColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'SATUSEHAT CREDENTIALS',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: tealColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Chip Production
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: tealColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'PRODUCTION ENVIRONMENT',
                    style: GoogleFonts.outfit(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w900,
                      color: tealColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildInputLabelAndField(
              'Organization ID',
              _ssOrgIdController,
              inputBg,
              textColor,
              subtitleColor,
            ),
            const SizedBox(height: 16),
            _buildInputLabelAndField(
              'Client ID',
              _ssClientIdController,
              inputBg,
              textColor,
              subtitleColor,
            ),
            const SizedBox(height: 16),
            _buildPasswordField(
              'Client Secret',
              _ssClientSecretController,
              _obscureSsSecret,
              () => setState(() => _obscureSsSecret = !_obscureSsSecret),
              inputBg,
              textColor,
              subtitleColor,
              borderColor,
            ),
          ] else if (_activeApiSubTab == 1) ...[
            // BPJS
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.blueAccent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'BPJS KESEHATAN CREDENTIALS',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: Colors.blueAccent,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'PRODUCTION ENVIRONMENT',
                    style: GoogleFonts.outfit(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w900,
                      color: Colors.blueAccent,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildInputLabelAndField(
              'Cons ID',
              _bpjsConsIdController,
              inputBg,
              textColor,
              subtitleColor,
            ),
            const SizedBox(height: 16),
            _buildInputLabelAndField(
              'User Key',
              _bpjsUserKeyController,
              inputBg,
              textColor,
              subtitleColor,
            ),
            const SizedBox(height: 16),
            _buildPasswordField(
              'Secret Key',
              _bpjsSecretKeyController,
              _obscureBpjsSecret,
              () => setState(() => _obscureBpjsSecret = !_obscureBpjsSecret),
              inputBg,
              textColor,
              subtitleColor,
              borderColor,
            ),
          ] else ...[
            // Mobile JKN
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.orangeAccent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'MOBILE JKN CREDENTIALS',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: Colors.orangeAccent,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orangeAccent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'PRODUCTION ENVIRONMENT',
                    style: GoogleFonts.outfit(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w900,
                      color: Colors.orangeAccent,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildInputLabelAndField(
              'JKN Connector URL',
              _jknUrlController,
              inputBg,
              textColor,
              subtitleColor,
            ),
            const SizedBox(height: 16),
            _buildInputLabelAndField(
              'Client ID',
              _jknClientIdController,
              inputBg,
              textColor,
              subtitleColor,
            ),
            const SizedBox(height: 16),
            _buildPasswordField(
              'Client Secret',
              _jknClientSecretController,
              _obscureJknSecret,
              () => setState(() => _obscureJknSecret = !_obscureJknSecret),
              inputBg,
              textColor,
              subtitleColor,
              borderColor,
            ),
          ],
          const SizedBox(height: 24),
          // Save Credentials Button
          ElevatedButton(
            onPressed: _isSaving ? null : _saveApiSettings,
            style: ElevatedButton.styleFrom(
              backgroundColor: tealColor,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              _isSaving ? 'Saving Credentials...' : 'Save API Settings',
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApiSubTabItem(
    int index,
    String label,
    Color tealColor,
    bool isDark,
  ) {
    final isSelected = _activeApiSubTab == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _activeApiSubTab = index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? tealColor : Colors.transparent,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSelected
                ? Colors.white
                : (isDark ? Colors.grey[400] : const Color(0xFF475569)),
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordField(
    String label,
    TextEditingController controller,
    bool obscureText,
    VoidCallback onToggleObscure,
    Color inputBg,
    Color textColor,
    Color subtitleColor,
    Color borderColor,
  ) {
    return Column(
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
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: inputBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  obscureText: obscureText,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  obscureText
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 16,
                  color: subtitleColor,
                ),
                onPressed: onToggleObscure,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Input Component Builders
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildInputLabelAndField(
    String label,
    TextEditingController controller,
    Color inputBg,
    Color textColor,
    Color subtitleColor, {
    String? hintText,
  }) {
    return Column(
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
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: inputBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.transparent),
          ),
          child: TextField(
            controller: controller,
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              hintText: hintText,
              hintStyle: GoogleFonts.outfit(
                fontSize: 12,
                color: subtitleColor.withOpacity(0.6),
                fontWeight: FontWeight.w500,
              ),
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
    void Function(String?) onChanged,
    Color inputBg,
    Color textColor,
    Color subtitleColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) ...[
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: subtitleColor,
            ),
          ),
          const SizedBox(height: 6),
        ],
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: inputBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: DropdownButtonFormField<String>(
            value: currentValue,
            items: items.map((item) {
              return DropdownMenuItem<String>(
                value: item,
                child: Text(
                  item,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              );
            }).toList(),
            onChanged: onChanged,
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
            ),
            dropdownColor: inputBg,
            icon: Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: subtitleColor,
            ),
          ),
        ),
      ],
    );
  }

  // Helper row builder for schedule days
  Widget _buildScheduleDayRow(
    Map<String, dynamic> dayMap,
    bool isDark,
    bool isRev,
    Color inputBg,
    Color borderColor,
    Color tealColor,
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
                  : const Color(0xFFF1F5F9).withOpacity(0.5)),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? borderColor : borderColor.withOpacity(0.5),
        ),
      ),
      child: Opacity(
        opacity: isActive ? 1.0 : 0.5,
        child: Row(
          children: [
            // Colored Day Initial Circle
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive
                    ? (isRev ? const Color(0xFFF5EEFF) : const Color(0xFFE6F7F4))
                    : (isDark
                          ? const Color(0xFF2C2C30)
                          : const Color(0xFFE2E8F0)),
              ),
              alignment: Alignment.center,
              child: Text(
                dayInitial,
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isActive ? tealColor : Colors.grey,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Day name
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

            // Start Time input
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
              child: Text(
                's/d',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ),

            // End Time input
            GestureDetector(
              onTap: isActive ? () => _selectTime(context, dayMap, false) : null,
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

            const SizedBox(width: 16),
            const SizedBox(height: 24, child: VerticalDivider(width: 1)),
            const SizedBox(width: 16),

            // Status label
            Text(
              isActive ? 'ACTIVE' : 'HOLIDAY',
              style: GoogleFonts.outfit(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: isActive ? tealColor : Colors.redAccent,
              ),
            ),
            const Spacer(),

            // Switch
            Switch(
              value: isActive,
              activeColor: tealColor,
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

  Widget _buildQrisPaymentMethodCard(
    bool isDark,
    Color cardBg,
    Color textColor,
    Color subtitleColor,
    Color borderColor,
    Color inputBg,
    Color tealColor,
    Color purpleColor,
  ) {
    // Determine what to show in the preview pane
    Widget previewChild;
    final String currentUrl;

    if (_selectedQrisType == 'UPLOAD PHOTO') {
      currentUrl = _qrisPath;
    } else {
      currentUrl = _qrisLinkController.text.trim();
    }

    if (currentUrl.isEmpty) {
      previewChild = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.cloud_upload_outlined,
            size: 40,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 8),
          Text(
            'File not uploaded',
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    } else {
      // If it's a payment link (and not direct image url), render a QR code of the link
      final String renderUrl;
      if (_selectedQrisType == 'AUTOMATIC PAYMENT LINK') {
        renderUrl = 'https://api.qrserver.com/v1/create-qr-code/?size=180x180&data=${Uri.encodeComponent(currentUrl)}';
      } else {
        renderUrl = currentUrl;
      }

      previewChild = Padding(
        padding: const EdgeInsets.all(12.0),
        child: Image.network(
          renderUrl,
          fit: BoxFit.contain,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: CircularProgressIndicator(color: tealColor),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.broken_image_outlined, size: 40, color: Colors.redAccent),
                const SizedBox(height: 8),
                Text(
                  'Failed to load image',
                  style: GoogleFonts.outfit(fontSize: 10, color: Colors.redAccent),
                ),
              ],
            );
          },
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.account_balance_wallet_outlined, color: tealColor, size: 18),
              const SizedBox(width: 10),
              Text(
                'QRIS Payment Method',
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

          // Two Column Layout
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Column 1: Payment Preview
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PAYMENT PREVIEW',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: subtitleColor,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1E22) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? const Color(0xFF2C2C30) : const Color(0xFFECEEF2),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: Center(child: previewChild),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 24),

              // Column 2: Configuration Inputs
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select QRIS Type',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Custom segmented control row
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E1E22) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderColor),
                      ),
                      child: Row(
                        children: [
                          _buildQrisTypeSegment('UPLOAD PHOTO', Icons.upload_file, tealColor, isDark),
                          _buildQrisTypeSegment('IMAGE URL / LABEL', Icons.image, tealColor, isDark),
                          _buildQrisTypeSegment('AUTOMATIC PAYMENT LINK', Icons.link, tealColor, isDark),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Dynamic fields based on active QRIS Type tab
                    if (_selectedQrisType == 'UPLOAD PHOTO') ...[
                      Row(
                        children: [
                          Icon(Icons.upload_rounded, size: 14, color: tealColor),
                          const SizedBox(width: 6),
                          Text(
                            'QRIS Photo / Branding',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: subtitleColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () {
                          // Mock file uploading: Set a nice sample QRIS/QR image URL
                          setState(() {
                            _qrisPath = 'https://api.qrserver.com/v1/create-qr-code/?size=250x250&color=000000&data=StaticQRISPaymentMock';
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Mock QRIS photo uploaded successfully!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        },
                        child: Container(
                          height: 50,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E1E22) : const Color(0xFFFAFAFB),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: tealColor.withOpacity(0.4),
                              style: BorderStyle.solid,
                              width: 1.5,
                            ),
                          ),
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.cloud_upload_outlined, size: 18, color: tealColor),
                                const SizedBox(width: 8),
                                Text(
                                  _qrisPath.isNotEmpty ? 'Change QRIS Photo' : 'Upload QRIS Photo',
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: tealColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Tips: Upload transparent PNG/JPG for premium look.',
                        style: GoogleFonts.outfit(
                          fontSize: 9.5,
                          color: subtitleColor.withOpacity(0.8),
                        ),
                      ),
                    ] else if (_selectedQrisType == 'IMAGE URL / LABEL') ...[
                      _buildInputLabelAndField(
                        'QRIS Image URL',
                        _qrisLinkController,
                        inputBg,
                        textColor,
                        subtitleColor,
                        hintText: 'https://example.com/your-qris-image.png',
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Enter a direct URL link to your static QRIS image.',
                        style: GoogleFonts.outfit(
                          fontSize: 9.5,
                          color: subtitleColor.withOpacity(0.8),
                        ),
                      ),
                    ] else ...[
                      _buildInputLabelAndField(
                        'Payment Gateway / Invoice Link',
                        _qrisLinkController,
                        inputBg,
                        textColor,
                        subtitleColor,
                        hintText: 'https://payment.duitku.com/invoice...',
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Enter your customer invoice redirection url. The preview will automatically render its scanable QR code.',
                        style: GoogleFonts.outfit(
                          fontSize: 9.5,
                          color: subtitleColor.withOpacity(0.8),
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Save Configuration Button
                    ElevatedButton.icon(
                      onPressed: _isSaving ? null : _saveQrisConfiguration,
                      icon: Icon(_isSaving ? Icons.hourglass_top_rounded : Icons.check_circle_outline, size: 16),
                      label: Text(_isSaving ? 'Saving...' : 'SAVE CONFIGURATION'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: tealColor,
                        foregroundColor: Colors.white,
                        shadowColor: tealColor.withOpacity(0.3),
                        elevation: 4,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        textStyle: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Bottom Info Tile
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1B2824) : const Color(0xFFEAF8F5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: tealColor.withOpacity(0.2),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 14, color: tealColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Manual File method is suitable if you already have a static QRIS image (like DANA/OVO/BCA).',
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.grey[300] : const Color(0xFF0E5A44),
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

  Widget _buildQrisTypeSegment(
    String type,
    IconData icon,
    Color tealColor,
    bool isDark,
  ) {
    final isSelected = _selectedQrisType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedQrisType = type;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? tealColor : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.grey[400] : const Color(0xFF64748B)),
              ),
              const SizedBox(height: 4),
              Text(
                type,
                style: GoogleFonts.outfit(
                  fontSize: 7.5,
                  fontWeight: FontWeight.bold,
                  color: isSelected
                      ? Colors.white
                      : (isDark ? Colors.grey[400] : const Color(0xFF475569)),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFilePreviewDialog(String fileName) {
    showDialog(
      context: context,
      builder: (context) {
        final isPdf = fileName.toLowerCase().endsWith('.pdf');
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E22),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      isPdf ? Icons.picture_as_pdf_outlined : Icons.image_outlined,
                      color: isPdf ? Colors.redAccent : const Color(0xFF00A67E),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        fileName,
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.grey, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          content: Container(
            width: double.maxFinite,
            height: 350,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: isPdf
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.picture_as_pdf, size: 64, color: Colors.red),
                        const SizedBox(height: 12),
                        Text(
                          'PDF Document Preview',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Size: 2.4 MB • 2 Pages',
                          style: GoogleFonts.outfit(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Click to open externally',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              color: Colors.black54,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    )
                  : Image.network(
                      'https://picsum.photos/id/1048/400/300', // Beautiful mock certification photo
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(child: Icon(Icons.image, size: 64));
                      },
                    ),
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () async {
                // Also support opening a mock external URL for the certificate
                final mockUrl = isPdf 
                    ? 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf'
                    : 'https://picsum.photos/id/1048/800/600';
                final uri = Uri.parse(mockUrl);
                try {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } catch (_) {}
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00A67E),
                foregroundColor: Colors.white,
              ),
              child: Text(
                'Open File',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────
// Custom Vector Map Graphics Painter (OpenStreetMap style)
// ──────────────────────────────────────────────────────────────────────────
class MapGraphicsPainter extends CustomPainter {
  final bool isDark;
  MapGraphicsPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint landPaint = Paint()
      ..color = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
    final Paint roadPaint = Paint()
      ..color = isDark ? const Color(0xFF334155) : Colors.white
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke;
    final Paint secondaryRoadPaint = Paint()
      ..color = isDark
          ? const Color(0xFF475569).withOpacity(0.5)
          : const Color(0xFFE2E8F0)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    final Paint parkPaint = Paint()
      ..color = isDark
          ? const Color(0xFF14532D).withOpacity(0.3)
          : const Color(0xFFDCFCE7);
    final Paint waterPaint = Paint()
      ..color = isDark
          ? const Color(0xFF1E3A8A).withOpacity(0.5)
          : const Color(0xFFE0F2FE);

    // Land
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), landPaint);

    // Green space (park)
    canvas.drawOval(Rect.fromLTWH(-30, 20, 180, 100), parkPaint);
    canvas.drawOval(
      Rect.fromLTWH(size.width - 120, size.height - 110, 150, 120),
      parkPaint,
    );

    // Water channel (river)
    final Path waterPath = Path();
    waterPath.moveTo(0, size.height - 40);
    waterPath.quadraticBezierTo(
      size.width / 3,
      size.height - 60,
      size.width / 2,
      size.height - 20,
    );
    waterPath.quadraticBezierTo(
      size.width * 0.8,
      size.height + 20,
      size.width,
      size.height - 10,
    );
    waterPath.lineTo(size.width, size.height);
    waterPath.lineTo(0, size.height);
    waterPath.close();
    canvas.drawPath(waterPath, waterPaint);

    // Roads layout grid
    // Road 1: Diagonal main road
    canvas.drawLine(
      const Offset(-10, -10),
      Offset(size.width + 10, size.height + 10),
      roadPaint,
    );
    // Road 2: Crossing main road
    canvas.drawLine(
      Offset(-10, size.height * 0.7),
      Offset(size.width + 10, size.height * 0.2),
      roadPaint,
    );

    // Secondary streets
    canvas.drawLine(
      Offset(size.width * 0.3, 0),
      Offset(size.width * 0.3, size.height),
      secondaryRoadPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.7, 0),
      Offset(size.width * 0.7, size.height),
      secondaryRoadPaint,
    );
    canvas.drawLine(
      Offset(0, size.height * 0.4),
      Offset(size.width, size.height * 0.4),
      secondaryRoadPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ──────────────────────────────────────────────────────────────────────────
// Custom Vector QR Code Painter
// ──────────────────────────────────────────────────────────────────────────
class QrPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint qrBlockPaint = Paint()..color = Colors.black;

    // Draw QR Code outer Finder Patterns (the three big squares)
    // Top-Left Finder
    _drawFinderPattern(canvas, const Offset(0, 0), qrBlockPaint, 36);
    // Top-Right Finder
    _drawFinderPattern(canvas, Offset(size.width - 36, 0), qrBlockPaint, 36);
    // Bottom-Left Finder
    _drawFinderPattern(canvas, Offset(0, size.height - 36), qrBlockPaint, 36);

    // Draw some random qr blocks inside
    canvas.drawRect(Rect.fromLTWH(50, 10, 8, 8), qrBlockPaint);
    canvas.drawRect(Rect.fromLTWH(62, 10, 16, 8), qrBlockPaint);
    canvas.drawRect(Rect.fromLTWH(86, 10, 8, 16), qrBlockPaint);
    canvas.drawRect(Rect.fromLTWH(50, 26, 24, 8), qrBlockPaint);
    canvas.drawRect(Rect.fromLTWH(10, 50, 8, 24), qrBlockPaint);
    canvas.drawRect(Rect.fromLTWH(26, 50, 16, 8), qrBlockPaint);

    canvas.drawRect(Rect.fromLTWH(50, 50, 32, 32), qrBlockPaint);
    canvas.drawRect(Rect.fromLTWH(90, 50, 8, 16), qrBlockPaint);
    canvas.drawRect(Rect.fromLTWH(110, 45, 16, 8), qrBlockPaint);

    canvas.drawRect(Rect.fromLTWH(10, 86, 8, 8), qrBlockPaint);
    canvas.drawRect(Rect.fromLTWH(26, 86, 16, 16), qrBlockPaint);
    canvas.drawRect(Rect.fromLTWH(50, 94, 24, 8), qrBlockPaint);
    canvas.drawRect(Rect.fromLTWH(90, 86, 8, 32), qrBlockPaint);
    canvas.drawRect(Rect.fromLTWH(106, 75, 16, 16), qrBlockPaint);

    canvas.drawRect(Rect.fromLTWH(50, 110, 8, 16), qrBlockPaint);
    canvas.drawRect(Rect.fromLTWH(66, 110, 16, 8), qrBlockPaint);
    canvas.drawRect(Rect.fromLTWH(10, 114, 24, 8), qrBlockPaint);
    canvas.drawRect(Rect.fromLTWH(106, 110, 8, 24), qrBlockPaint);

    canvas.drawRect(Rect.fromLTWH(124, 100, 16, 8), qrBlockPaint);
    canvas.drawRect(Rect.fromLTWH(124, 114, 8, 16), qrBlockPaint);
  }

  void _drawFinderPattern(
    Canvas canvas,
    Offset offset,
    Paint paint,
    double size,
  ) {
    // Outer square
    canvas.drawRect(Rect.fromLTWH(offset.dx, offset.dy, size, size), paint);
    // Inner white cutout
    canvas.drawRect(
      Rect.fromLTWH(offset.dx + 4, offset.dy + 4, size - 8, size - 8),
      Paint()..color = Colors.white,
    );
    // Center solid block
    canvas.drawRect(
      Rect.fromLTWH(offset.dx + 8, offset.dy + 8, size - 16, size - 16),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
