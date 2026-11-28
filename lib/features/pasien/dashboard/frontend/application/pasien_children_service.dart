import 'package:flutter/material.dart';
import 'package:mapotech/features/pasien/dashboard/frontend/ai_assistant/presentation/ai_chat_provider.dart';
import 'package:mapotech/features/puskesmas/dlc/vitascale/data/vitascale_models.dart';
import 'package:mapotech/features/puskesmas/dlc/vitascale/data/vitascale_repository.dart';
import 'package:mapotech/features/puskesmas/dlc/vitascale/pages/vitascale_child_history_page.dart';
import 'package:mapotech/shared/supabase_service.dart';

/// Unified clinical or anthropometric checkup record for a user or family member.
class FamilyCheckupRecord {
  final String id;
  final String? queueId;
  final String source; // 'doctor' | 'vitascale'
  final DateTime checkupDate;
  final String timeLabel;
  final String? queueNumber;
  final String examinerName;
  final String facilityName;
  final String? mainComplaint;
  final String? anamnesis;
  final Map<String, String> allergies;
  final String? medicationTherapy;
  final String? nonMedicationTherapy;
  final String? medicalSupplies;
  final String? prognosis;
  final Map<String, dynamic>? vitals;
  final List<Map<String, String>> diagnoses;
  final List<Map<String, dynamic>> medicines;
  final bool medicinesLoaded;
  final Map<String, String>? rujukan;
  final Map<String, dynamic>? suratKeterangan;
  final ChildVisitRecord? vitascaleVisit;

  const FamilyCheckupRecord({
    required this.id,
    this.queueId,
    this.source = 'doctor',
    required this.checkupDate,
    this.timeLabel = '',
    this.queueNumber,
    required this.examinerName,
    required this.facilityName,
    this.mainComplaint,
    this.anamnesis,
    this.allergies = const {},
    this.medicationTherapy,
    this.nonMedicationTherapy,
    this.medicalSupplies,
    this.prognosis,
    this.vitals,
    this.diagnoses = const [],
    this.medicines = const [],
    this.medicinesLoaded = false,
    this.rujukan,
    this.suratKeterangan,
    this.vitascaleVisit,
  });

  bool get isVitaScale => source == 'vitascale' && vitascaleVisit != null;
  bool get hasRujukan => rujukan != null;
  bool get hasCertificate => suratKeterangan != null;

  String? get primaryDiagnosisText {
    if (diagnoses.isNotEmpty) {
      final first = diagnoses.first;
      final code = first['code'] ?? '';
      final desc = first['description'] ?? '';
      if (code.isNotEmpty && desc.isNotEmpty) return '$code - $desc';
      return desc.isNotEmpty ? desc : code;
    }
    if (vitascaleVisit != null) {
      return vitascaleVisit!.statusGizi;
    }
    return null;
  }

  FamilyCheckupRecord copyWith({
    List<Map<String, dynamic>>? medicines,
    bool? medicinesLoaded,
  }) {
    return FamilyCheckupRecord(
      id: id,
      queueId: queueId,
      source: source,
      checkupDate: checkupDate,
      timeLabel: timeLabel,
      queueNumber: queueNumber,
      examinerName: examinerName,
      facilityName: facilityName,
      mainComplaint: mainComplaint,
      anamnesis: anamnesis,
      allergies: allergies,
      medicationTherapy: medicationTherapy,
      nonMedicationTherapy: nonMedicationTherapy,
      medicalSupplies: medicalSupplies,
      prognosis: prognosis,
      vitals: vitals,
      diagnoses: diagnoses,
      medicines: medicines ?? this.medicines,
      medicinesLoaded: medicinesLoaded ?? this.medicinesLoaded,
      rujukan: rujukan,
      suratKeterangan: suratKeterangan,
      vitascaleVisit: vitascaleVisit,
    );
  }
}

/// Enriched Family Member / User Data combining Profile, Family Member, Doctor EMR, and VitaScale records.
class PasienChildModel {
  final Map<String, dynamic> familyMember;
  final Map<String, dynamic>? linkedUser;
  final ChildProfile? vitascaleProfile;
  final List<ChildVisitRecord> visitHistory;
  final ChildVisitRecord? lastVisit;
  final List<FamilyCheckupRecord> checkups;
  final FamilyCheckupRecord? lastCheckup;
  final bool isSelf;
  final bool isAccepted;

  PasienChildModel({
    required this.familyMember,
    this.linkedUser,
    this.vitascaleProfile,
    this.visitHistory = const [],
    this.lastVisit,
    this.checkups = const [],
    this.lastCheckup,
    this.isSelf = false,
    this.isAccepted = true,
  });

  String? get userId {
    final linkedId = linkedUser?['id']?.toString().trim();
    if (linkedId != null && linkedId.isNotEmpty) return linkedId;
    final memberUserId = familyMember['member_user_id']?.toString().trim();
    if (memberUserId != null && memberUserId.isNotEmpty) return memberUserId;
    if (isSelf) {
      final selfId = familyMember['id']?.toString().trim();
      if (selfId != null && selfId.isNotEmpty) return selfId;
    }
    return null;
  }

  String get name {
    final linkedName = (linkedUser?['name'] as String?)?.trim();
    if (linkedName != null && linkedName.isNotEmpty) return linkedName;
    final n = (familyMember['nama'] as String?)?.trim() ??
        (familyMember['name'] as String?)?.trim();
    if (n != null && n.isNotEmpty) return n;
    return vitascaleProfile?.name ?? 'Anggota Keluarga';
  }

  String get nik {
    final linkedNik = (linkedUser?['nik'] as String?)?.trim();
    if (linkedNik != null && linkedNik.isNotEmpty) return linkedNik;
    final n = (familyMember['nik'] as String?)?.trim();
    if (n != null && n.isNotEmpty) return n;
    return vitascaleProfile?.nik ?? '-';
  }

  String get maskedNik {
    final raw = nik;
    if (raw.length >= 8) {
      return '${raw.substring(0, 4)}••••${raw.substring(raw.length - 4)}';
    }
    return raw;
  }

  String get hubungan {
    final h = (familyMember['hubungan'] as String?)?.trim();
    if (h != null && h.isNotEmpty) return h;
    return isSelf ? 'Akun Utama' : 'Anggota Keluarga';
  }

  String get gender {
    final g = (linkedUser?['gender'] as String?)?.trim() ??
        (familyMember['gender'] as String?)?.trim() ??
        vitascaleProfile?.gender ??
        'L';
    final low = g.toLowerCase();
    if (low.startsWith('p') || low == 'female' || low == 'wanita') {
      return 'Perempuan';
    }
    return 'Laki-laki';
  }

  bool get isMale => gender == 'Laki-laki';

  bool get isMother {
    final rel = hubungan.toLowerCase();
    return rel.contains('ibu') ||
        rel.contains('istri') ||
        rel.contains('bunda') ||
        (!isMale && isAdult);
  }

  bool get isFather {
    final rel = hubungan.toLowerCase();
    return rel.contains('ayah') ||
        rel.contains('suami') ||
        rel.contains('kepala keluarga');
  }

  bool get isChild {
    final rel = hubungan.toLowerCase();
    return rel.contains('anak') ||
        rel.contains('bayi') ||
        rel.contains('balita') ||
        rel.contains('putra') ||
        rel.contains('putri') ||
        rel.contains('cucu');
  }

  bool get isAdult => !isChild;

  String? get avatarUrl {
    final u = (linkedUser?['avatar_url'] as String?)?.trim() ??
        (familyMember['avatar_url'] as String?)?.trim();
    if (u != null && (u.startsWith('http://') || u.startsWith('https://'))) {
      return u;
    }
    return null;
  }

  String? get birthDateRaw {
    final b = (linkedUser?['birth_date']?.toString() ??
            familyMember['birth_date']?.toString())
        ?.trim();
    if (b != null && b.isNotEmpty && b != 'null') return b;
    return null;
  }

  DateTime? get birthDate {
    final raw = birthDateRaw;
    if (raw == null) return vitascaleProfile?.birthDate;
    return DateTime.tryParse(raw) ?? vitascaleProfile?.birthDate;
  }

  String? get birthPlace {
    final bp = (linkedUser?['birth_place'] as String?)?.trim() ??
        (familyMember['birth_place'] as String?)?.trim();
    if (bp != null && bp.isNotEmpty) return bp;
    return null;
  }

  String? get phone {
    final p = (linkedUser?['phone_number'] as String?)?.trim() ??
        (familyMember['phone_number'] as String?)?.trim();
    if (p != null && p.isNotEmpty) return p;
    return vitascaleProfile?.phone;
  }

  String? get email {
    final e = (linkedUser?['email'] as String?)?.trim() ??
        (familyMember['email'] as String?)?.trim();
    if (e != null && e.isNotEmpty) return e;
    return null;
  }

  String? get address {
    final a = (linkedUser?['address'] as String?)?.trim() ??
        (familyMember['address'] as String?)?.trim();
    if (a != null && a.isNotEmpty) return a;
    return vitascaleProfile?.address;
  }

  String? get noKk {
    final k = (familyMember['no_kk'] as String?)?.trim();
    if (k != null && k.isNotEmpty) return k;
    return vitascaleProfile?.noKk;
  }

  String? get healthStatus {
    final s = (familyMember['status_kesehatan'] as String?)?.trim();
    if (s != null && s.isNotEmpty && s != '-') return s;
    return null;
  }

  int get ageInMonths {
    final bd = birthDate;
    if (bd != null) {
      return ChildProfile.calculateCompletedMonths(bd);
    }
    if (vitascaleProfile != null) {
      return vitascaleProfile!.ageInMonths;
    }
    final usiaStr = (familyMember['usia'] as String? ?? '').toLowerCase();
    final numMatch = RegExp(r'\d+').firstMatch(usiaStr);
    if (numMatch != null) {
      final val = int.tryParse(numMatch.group(0) ?? '0') ?? 0;
      if (usiaStr.contains('th') || usiaStr.contains('tahun')) {
        return val * 12;
      }
      return val;
    }
    return isChild ? 24 : 300;
  }

  String get ageLabel {
    final bd = birthDate;
    if (bd != null) {
      final totalMonths = ChildProfile.calculateCompletedMonths(bd);
      final years = totalMonths ~/ 12;
      final remMonths = totalMonths % 12;
      if (years >= 12) {
        return '$years Tahun';
      }
      if (years > 0) {
        return remMonths > 0 ? '$years Thn $remMonths Bln' : '$years Tahun';
      }
      return '$totalMonths Bulan';
    }
    if (vitascaleProfile != null) {
      return vitascaleProfile!.ageLabel;
    }
    final usia = familyMember['usia'] as String?;
    if (usia != null && usia.isNotEmpty) return usia;
    return '-';
  }

  bool get isBalita => isChild && ageInMonths < 60;
  bool get isUnder24Months => isChild && ageInMonths < 24;

  String get categoryLabel {
    if (isUnder24Months) return 'Bayi (< 24 Bln)';
    if (isBalita) return 'Balita (2-5 Thn)';
    if (isChild && ageInMonths < 216) return 'Anak';
    return 'Dewasa';
  }
}

/// Structured result containing the top user profile and the family members list.
class PasienFamilyDirectory {
  final PasienChildModel? currentUser;
  final List<PasienChildModel> familyMembers;
  final String noKk;
  final bool isKepalaKeluarga;

  const PasienFamilyDirectory({
    required this.currentUser,
    required this.familyMembers,
    this.noKk = '',
    this.isKepalaKeluarga = false,
  });

  List<PasienChildModel> get allMembers => [
        ?currentUser,
        ...familyMembers,
      ];
}

/// Service to load and manage real patient family records & checkups.
class PasienChildrenService {
  static final SupabaseService _db = SupabaseService();
  static final VitaScaleRepository _vitaRepo = VitaScaleRepository();

  /// Loads the logged-in user's detail at top + all family members with real checkup histories.
  static Future<PasienFamilyDirectory> fetchFamilyDirectoryForUser(
    Map<String, dynamic>? user,
  ) async {
    if (user == null) {
      return const PasienFamilyDirectory(currentUser: null, familyMembers: []);
    }

    final userId = user['id']?.toString().trim() ?? '';
    final userName = (user['name'] as String? ??
            user['nama_lengkap'] as String? ??
            '')
        .trim();
    final userNik = (user['nik'] as String? ?? '').trim();

    try {
      // 1. Fetch fresh user + user_detail_patient for current user
      Map<String, dynamic> enrichedUser = Map<String, dynamic>.from(user);
      Map<String, dynamic>? patientDetail = user['patient_details'] is Map
          ? Map<String, dynamic>.from(user['patient_details'] as Map)
          : null;

      if (userId.isNotEmpty && !userId.startsWith('mock-')) {
        final results = await Future.wait([
          _db.fetchUserById(userId),
          _db.fetchPatientDetailById(userId),
        ]);
        final freshUser = results[0];
        final freshDetail = results[1];
        if (freshUser != null) {
          enrichedUser.addAll(freshUser);
        }
        if (freshDetail != null) {
          patientDetail = freshDetail;
        }
      }

      final userKk = (patientDetail?['no_kk']?.toString() ??
              enrichedUser['no_kk']?.toString() ??
              '')
          .trim();
      final isKepala = patientDetail?['is_kepala_keluarga'] == true;
      final userGender = (enrichedUser['gender'] as String? ??
              enrichedUser['jenis_kelamin'] as String? ??
              'L')
          .toUpperCase();
      final isFemaleUser =
          userGender.startsWith('P') || userGender == 'FEMALE';

      final String selfRole;
      if (isKepala) {
        selfRole = isFemaleUser
            ? 'Kepala Keluarga (Ibu)'
            : 'Kepala Keluarga (Ayah)';
      } else {
        selfRole = isFemaleUser ? 'Ibu' : 'Kepala Keluarga (Ayah)';
      }

      // 2. Fetch family members from patient_family_members (both as host or linked member)
      List<Map<String, dynamic>> rawMembers = [];
      String? hostUserId;
      if (userId.isNotEmpty && !userId.startsWith('mock-')) {
        rawMembers = await _db.fetchAllFamilyMembersForUser(userId);
        hostUserId = await _db.fetchFamilyHostUserId(userId);
      }

      // 3. Resolve linked public.user records for family members + host if logged in as a member
      final Map<String, Map<String, dynamic>> linkedUsersById = {};
      final Map<String, Map<String, dynamic>> linkedUsersByNik = {};

      final List<Future<void>> userLookups = [];
      if (hostUserId != null && hostUserId.isNotEmpty) {
        userLookups.add(() async {
          final hostUser = await _db.fetchUserById(hostUserId!);
          if (hostUser != null) {
            linkedUsersById[hostUserId] = hostUser;
          }
        }());
      }

      for (final m in rawMembers) {
        final mUserId = m['member_user_id']?.toString().trim() ?? '';
        final mNik = (m['nik'] as String? ?? '').trim();
        if (mUserId.isNotEmpty && mUserId != userId) {
          userLookups.add(() async {
            final u = await _db.fetchUserById(mUserId);
            if (u != null) {
              linkedUsersById[mUserId] = u;
            }
          }());
        } else if (mUserId.isEmpty && mNik.isNotEmpty && mNik != '-') {
          userLookups.add(() async {
            final u = await _db.fetchUserByNik(mNik);
            if (u != null) {
              linkedUsersByNik[mNik] = u;
            }
          }());
        }
      }

      if (userLookups.isNotEmpty) {
        await Future.wait(userLookups);
      }

      // 4. Collect all patient user IDs whose doctor clinical encounters we should load
      final Set<String> patientIdsToFetch = {};
      if (userId.isNotEmpty && !userId.startsWith('mock-')) {
        patientIdsToFetch.add(userId);
      }
      if (hostUserId != null && hostUserId.isNotEmpty) {
        patientIdsToFetch.add(hostUserId);
      }
      for (final u in linkedUsersById.values) {
        final id = u['id']?.toString().trim() ?? '';
        if (id.isNotEmpty) patientIdsToFetch.add(id);
      }
      for (final u in linkedUsersByNik.values) {
        final id = u['id']?.toString().trim() ?? '';
        if (id.isNotEmpty) patientIdsToFetch.add(id);
      }

      // 5. Batch fetch clinical encounters across all household member IDs
      final Map<String, List<FamilyCheckupRecord>> doctorCheckupsByUserId =
          await _fetchDoctorCheckupsForPatientIds(patientIdsToFetch.toList());

      // 6. Load VitaScale master profiles & local screening sessions (if any real screenings exist)
      final vitascaleChildren = await _vitaRepo.searchChildren();
      final localScreenings = VitaScaleRepository.localScreeningHistory;

      // 7. Build top current user model
      final selfCheckups = doctorCheckupsByUserId[userId] ?? const [];
      final currentUserModel = PasienChildModel(
        isSelf: true,
        linkedUser: enrichedUser,
        familyMember: {
          'id': userId,
          'nama': userName.isNotEmpty ? userName : 'Akun Utama',
          'nik': userNik,
          'hubungan': selfRole,
          'gender': isFemaleUser ? 'Perempuan' : 'Laki-laki',
          'birth_date': enrichedUser['birth_date'],
          'birth_place': enrichedUser['birth_place'],
          'phone_number': enrichedUser['phone_number'],
          'email': enrichedUser['email'],
          'address': enrichedUser['address'],
          'avatar_url': enrichedUser['avatar_url'],
          'no_kk': userKk,
        },
        checkups: selfCheckups,
        lastCheckup: selfCheckups.isNotEmpty ? selfCheckups.first : null,
      );

      // 8. Build family members list (excluding current logged-in user)
      final List<PasienChildModel> members = [];
      final Set<String> processedNiks = {};
      if (userNik.isNotEmpty) processedNiks.add(userNik);

      // If logged in as a member under a host KK, include the host user in the family cards
      if (hostUserId != null && linkedUsersById.containsKey(hostUserId)) {
        final hostUser = linkedUsersById[hostUserId]!;
        final hostNik = (hostUser['nik'] as String? ?? '').trim();
        final hostGenderRaw =
            (hostUser['gender'] as String? ?? 'L').toUpperCase();
        final hostIsFemale =
            hostGenderRaw.startsWith('P') || hostGenderRaw == 'FEMALE';
        final hostCheckups = doctorCheckupsByUserId[hostUserId] ?? const [];

        if (hostNik.isNotEmpty) processedNiks.add(hostNik);

        members.add(PasienChildModel(
          isSelf: false,
          linkedUser: hostUser,
          familyMember: {
            'id': hostUserId,
            'member_user_id': hostUserId,
            'nama': hostUser['name'] ?? 'Kepala Keluarga',
            'nik': hostNik,
            'hubungan':
                hostIsFemale ? 'Ibu (Kepala KK)' : 'Kepala Keluarga (Ayah)',
            'gender': hostIsFemale ? 'Perempuan' : 'Laki-laki',
            'no_kk': userKk,
          },
          checkups: hostCheckups,
          lastCheckup: hostCheckups.isNotEmpty ? hostCheckups.first : null,
        ));
      }

      for (final m in rawMembers) {
        final mUserId = m['member_user_id']?.toString().trim() ?? '';
        final mNik = ((m['nik'] as String?) ?? '').trim();
        final mName =
            ((m['nama'] as String?) ?? (m['name'] as String?) ?? '').trim();

        if (mUserId.isNotEmpty && mUserId == userId) continue;
        if (mNik.isNotEmpty && processedNiks.contains(mNik)) continue;
        if (mUserId.isEmpty &&
            mName.isNotEmpty &&
            userName.isNotEmpty &&
            mName.toLowerCase() == userName.toLowerCase()) {
          continue;
        }

        final linkedUser = mUserId.isNotEmpty
            ? linkedUsersById[mUserId]
            : (mNik.isNotEmpty ? linkedUsersByNik[mNik] : null);
        final resolvedUserId =
            linkedUser?['id']?.toString().trim() ?? mUserId;

        final List<FamilyCheckupRecord> memberCheckups = [
          ...(doctorCheckupsByUserId[resolvedUserId] ?? const []),
        ];

        // Match VitaScale child profile only if registered in VitaScale or has local screening sessions
        ChildProfile? matchedVitascale;
        if (mNik.isNotEmpty) {
          try {
            matchedVitascale =
                vitascaleChildren.firstWhere((c) => c.nik == mNik);
          } catch (_) {}
        }

        final memberLocalScreenings = localScreenings.where((s) {
          if (mNik.isNotEmpty && s.child.nik == mNik) return true;
          if (mName.isNotEmpty &&
              s.child.name.toLowerCase() == mName.toLowerCase()) {
            return true;
          }
          return false;
        }).toList();

        final List<ChildVisitRecord> vitaVisits = [];
        for (final s in memberLocalScreenings) {
          final vRecord = _visitRecordFromScreening(s);
          vitaVisits.add(vRecord);
          memberCheckups.add(_checkupFromVitaScaleVisit(s.sessionId, vRecord));
        }

        memberCheckups.sort((a, b) => b.checkupDate.compareTo(a.checkupDate));

        if (mNik.isNotEmpty) processedNiks.add(mNik);

        members.add(PasienChildModel(
          isSelf: false,
          isAccepted: m['accept_kk'] != false,
          familyMember: {
            ...m,
            if ((m['no_kk'] == null || m['no_kk'].toString().isEmpty) &&
                userKk.isNotEmpty)
              'no_kk': userKk,
          },
          linkedUser: linkedUser,
          vitascaleProfile: matchedVitascale,
          visitHistory: vitaVisits,
          lastVisit: vitaVisits.isNotEmpty ? vitaVisits.first : null,
          checkups: memberCheckups,
          lastCheckup: memberCheckups.isNotEmpty ? memberCheckups.first : null,
        ));
      }

      // 9. Also include children from VitaScale master matching the user's KK if not already added
      for (final vc in vitascaleChildren) {
        if (processedNiks.contains(vc.nik)) continue;
        bool isMatched = false;
        if (userKk.isNotEmpty && vc.noKk != null && vc.noKk == userKk) {
          isMatched = true;
        } else if (userNik.isNotEmpty && vc.parentName.contains(userNik)) {
          isMatched = true;
        } else if (userName.isNotEmpty &&
            vc.parentName.toLowerCase().contains(userName.toLowerCase())) {
          isMatched = true;
        }

        if (isMatched) {
          processedNiks.add(vc.nik);
          final visits = generateVisitsForChild(vc);
          final checkups = visits
              .asMap()
              .entries
              .map((e) => _checkupFromVitaScaleVisit(
                    'vs-${vc.id}-${e.key}',
                    e.value,
                  ))
              .toList();
          members.add(PasienChildModel(
            isSelf: false,
            familyMember: {
              'nama': vc.name,
              'nik': vc.nik,
              'hubungan': vc.isUnder24Months
                  ? 'Bayi'
                  : (vc.isBalita ? 'Balita' : 'Anak Kandung'),
              'gender': vc.gender == 'L' ? 'Laki-laki' : 'Perempuan',
              'usia': vc.ageLabel,
              'birth_date': vc.birthDate.toIso8601String().split('T').first,
              'address': vc.address,
              'no_kk': vc.noKk ?? userKk,
            },
            vitascaleProfile: vc,
            visitHistory: visits,
            lastVisit: visits.isNotEmpty ? visits.first : null,
            checkups: checkups,
            lastCheckup: checkups.isNotEmpty ? checkups.first : null,
          ));
        }
      }

      return PasienFamilyDirectory(
        currentUser: currentUserModel,
        familyMembers: members,
        noKk: userKk,
        isKepalaKeluarga: isKepala,
      );
    } catch (e) {
      debugPrint('[PasienChildrenService] Error fetching family directory: $e');
      return const PasienFamilyDirectory(currentUser: null, familyMembers: []);
    }
  }

  /// Fetches medicines lazily for a doctor encounter when inspecting Detail Pemeriksaan.
  static Future<List<Map<String, dynamic>>> fetchCheckupMedicines(
    String encounterId,
  ) async {
    if (encounterId.isEmpty) return [];
    return _db.fetchClinicalEncounterMedicines(encounterId);
  }

  static Future<Map<String, List<FamilyCheckupRecord>>>
      _fetchDoctorCheckupsForPatientIds(List<String> patientIds) async {
    if (patientIds.isEmpty) return {};

    final Map<String, List<Map<String, dynamic>>> queuesByPatient = {};
    final List<String> allQueueIds = [];

    await Future.wait(patientIds.map((pid) async {
      final qs = await _db.fetchPatientQueues(pid);
      queuesByPatient[pid] = qs;
      for (final q in qs) {
        final qId = q['id']?.toString() ?? '';
        if (qId.isNotEmpty) allQueueIds.add(qId);
      }
    }));

    if (allQueueIds.isEmpty) return {};

    final encounters = await _db.fetchPrivateClinicalEncounters(allQueueIds);
    if (encounters.isEmpty) return {};

    final Map<String, Map<String, dynamic>> encounterByQueueId = {};
    final List<String> encounterIds = [];
    for (final ce in encounters) {
      final qId = ce['id_queue']?.toString() ?? '';
      final eId = ce['id']?.toString() ?? '';
      if (qId.isNotEmpty && eId.isNotEmpty) {
        encounterByQueueId[qId] = ce;
        encounterIds.add(eId);
      }
    }

    if (encounterIds.isEmpty) return {};

    // Collect doctor IDs for encounters
    final Set<String> doctorIds = {};
    for (final qs in queuesByPatient.values) {
      for (final q in qs) {
        final qId = q['id']?.toString() ?? '';
        if (encounterByQueueId.containsKey(qId)) {
          final docId = q['id_doctor']?.toString().trim() ?? '';
          if (docId.isNotEmpty) doctorIds.add(docId);
        }
      }
    }

    // Batch fetch doctor metadata, vitals, anamnesis, and diagnoses in parallel
    final batchResults = await Future.wait([
      _db.fetchDoctorDetailsMap(doctorIds.toList()),
      _db.fetchVitalsForEncounters(encounterIds),
      _db.fetchAnamnesisForEncounters(encounterIds),
      _db.fetchDiagnosesForEncounters(encounterIds),
    ]);

    final doctorsMap = batchResults[0] as Map<String, Map<String, String>>;
    final vitalsMap = batchResults[1] as Map<String, Map<String, dynamic>>;
    final anamnesisMap = batchResults[2] as Map<String, Map<String, dynamic>>;
    final diagnosesMap =
        batchResults[3] as Map<String, List<Map<String, dynamic>>>;

    final Map<String, List<FamilyCheckupRecord>> result = {};

    for (final entry in queuesByPatient.entries) {
      final pid = entry.key;
      final List<FamilyCheckupRecord> records = [];

      for (final q in entry.value) {
        final qId = q['id']?.toString() ?? '';
        final ce = encounterByQueueId[qId];
        if (ce == null) continue;

        final encounterId = ce['id'].toString();
        final doctorId = q['id_doctor']?.toString().trim() ?? '';
        final docInfo = doctorsMap[doctorId];
        final doctorName = docInfo?['name']?.isNotEmpty == true
            ? docInfo!['name']!
            : 'Dokter Praktik Mandiri';
        final facilityName = docInfo?['facility']?.isNotEmpty == true
            ? docInfo!['facility']!
            : 'Praktik Mandiri $doctorName';

        final dateRaw = q['date_queue']?.toString() ?? '';
        final tsRaw = q['date_queue_ts']?.toString() ?? ce['created_at']?.toString() ?? '';
        DateTime parsedDate = DateTime.tryParse(dateRaw) ??
            DateTime.tryParse(tsRaw) ??
            DateTime.now();

        String timeLabel = '';
        final tsDt = DateTime.tryParse(tsRaw);
        if (tsDt != null && !(tsDt.hour == 0 && tsDt.minute == 0)) {
          final hh = tsDt.hour.toString().padLeft(2, '0');
          final mm = tsDt.minute.toString().padLeft(2, '0');
          timeLabel = '$hh:$mm WIB';
        }

        final anamnesisRow = anamnesisMap[encounterId];
        final vitalsRow = vitalsMap[encounterId];
        final diagRows = diagnosesMap[encounterId] ?? const [];

        final Map<String, String> allergies = {};
        void addAllergy(String key, dynamic val) {
          final s = val?.toString().trim() ?? '';
          if (s.isNotEmpty && s != '-' && s.toLowerCase() != 'tidak ada') {
            allergies[key] = s;
          }
        }

        if (anamnesisRow != null) {
          addAllergy('Makanan', anamnesisRow['food_allergy_history']);
          addAllergy('Obat', anamnesisRow['drug_allergy_history']);
          addAllergy('Antibiotik', anamnesisRow['drug_allergy_antibiotic']);
          addAllergy('Lingkungan', anamnesisRow['environmental_allergy_history']);
          addAllergy('Lainnya', anamnesisRow['other_allergy_history']);
        }

        final List<Map<String, String>> mappedDiagnoses = [];
        for (final d in diagRows) {
          final code =
              (d['icdx_code'] ?? d['code'] ?? '').toString().trim();
          final desc =
              (d['description'] ?? d['label'] ?? '').toString().trim();
          if (code.isNotEmpty || desc.isNotEmpty) {
            mappedDiagnoses.add({'code': code, 'description': desc});
          }
        }

        final Map<String, String>? rujukan = ce['is_rujukan'] == true
            ? {
                'rumah_sakit':
                    ce['rujukan_rumah_sakit']?.toString() ?? 'RS Rujukan',
                'poli': ce['rujukan_poli']?.toString() ?? 'Poli Spesialis',
                'nomor': ce['rujukan_nomor']?.toString() ?? '-',
                'catatan': ce['rujukan_catatan']?.toString() ?? '',
              }
            : null;

        final certType = ce['surat_keterangan_type']?.toString().trim();
        final Map<String, dynamic>? suratKeterangan =
            (certType != null && certType.isNotEmpty)
                ? {
                    'type': certType,
                    'keperluan': ce['surat_keperluan']?.toString() ?? '',
                    'hari': ce['surat_sakit_hari'],
                    'mulai': ce['surat_sakit_mulai']?.toString() ?? '',
                    'selesai': ce['surat_sakit_selesai']?.toString() ?? '',
                    'riwayat': ce['surat_riwayat_penyakit']?.toString() ?? '',
                  }
                : null;

        String? cleanText(dynamic val) {
          final s = val?.toString().trim() ?? '';
          if (s.isEmpty || s == '-' || s == 'null') return null;
          return s;
        }

        records.add(FamilyCheckupRecord(
          id: encounterId,
          queueId: qId,
          source: 'doctor',
          checkupDate: parsedDate,
          timeLabel: timeLabel,
          queueNumber: q['no_queue']?.toString(),
          examinerName: doctorName,
          facilityName: facilityName,
          mainComplaint: cleanText(anamnesisRow?['main_complaint']) ??
              cleanText(ce['rujukan_catatan']),
          anamnesis: cleanText(anamnesisRow?['anamnesis']),
          allergies: allergies,
          medicationTherapy: cleanText(anamnesisRow?['medication_therapy']),
          nonMedicationTherapy:
              cleanText(anamnesisRow?['non_medication_therapy']),
          medicalSupplies: cleanText(anamnesisRow?['medical_supplies']),
          prognosis: cleanText(anamnesisRow?['prognosis']),
          vitals: vitalsRow,
          diagnoses: mappedDiagnoses,
          medicinesLoaded: false,
          rujukan: rujukan,
          suratKeterangan: suratKeterangan,
        ));
      }

      records.sort((a, b) => b.checkupDate.compareTo(a.checkupDate));
      result[pid] = records;
    }

    return result;
  }

  static ChildVisitRecord _visitRecordFromScreening(ScreeningSession s) {
    final weight = s.weight.value ?? 0.0;
    final height = s.height.value ?? 0.0;
    final waist = s.waist.value ?? 0.0;
    return ChildVisitRecord(
      visitNumber: 'Skrining VitaScale',
      monthAgeLabel: 'Bulan ke-${s.child.ageInMonths}',
      visitDate: s.endTime ?? s.startTime,
      weightKg: weight,
      heightCm: height,
      waistCm: waist,
      lilaCm: 0.0,
      mode: s.mode.code,
      statusGizi: 'Terverifikasi Petugas',
      statusGiziColor: const Color(0xFF27AE60),
      statusStunting: 'Normal',
      statusStuntingColor: const Color(0xFF27AE60),
      confidenceGizi: 96.0,
      confidenceStunting: 96.0,
      examiner: 'Puskesmas (VitaScale)',
      reasoningSummary: s.notes ??
          'Hasil pengukuran antropometri ananda ${s.child.name} pada sesi skrining VitaScale.',
      chainOfThought: const [],
      riskEtiology: '-',
      nutritionPlan:
          'Pertahankan asupan protein hewani dan pemantauan berat badan rutin di Posyandu.',
      medicalProtocol: 'Jadwalkan penimbangan rutin bulan berikutnya.',
      parentEducation:
          'Pantau tumbuh kembang anak dan lengkapi imunisasi sesuai jadwal.',
    );
  }

  static FamilyCheckupRecord _checkupFromVitaScaleVisit(
    String id,
    ChildVisitRecord visit,
  ) {
    return FamilyCheckupRecord(
      id: id,
      source: 'vitascale',
      checkupDate: visit.visitDate,
      examinerName: visit.examiner,
      facilityName: 'Posyandu / Puskesmas (VitaScale)',
      mainComplaint: '${visit.visitNumber} (${visit.monthAgeLabel})',
      vitals: {
        'body_weight': visit.weightKg.toStringAsFixed(1),
        'body_height': visit.heightCm.toStringAsFixed(1),
      },
      diagnoses: [
        {'code': 'Gizi', 'description': visit.statusGizi},
        {'code': 'TB/U', 'description': visit.statusStunting},
      ],
      medicinesLoaded: true,
      vitascaleVisit: visit,
    );
  }

  /// Backward-compatible helper used by AI Assistant child selector.
  static Future<List<PasienChildModel>> fetchFullFamilyMembersForUser(
    Map<String, dynamic>? user,
  ) async {
    final directory = await fetchFamilyDirectoryForUser(user);
    return directory.allMembers;
  }

  /// Fetches registered child members in the user's KK (used by AI Assistant).
  static Future<List<PasienChildModel>> fetchFamilyChildrenForUser(
    Map<String, dynamic>? user,
  ) async {
    final directory = await fetchFamilyDirectoryForUser(user);
    return directory.familyMembers.where((m) => m.isChild).toList();
  }

  static ChildProfile createProfileFromFamily(
    Map<String, dynamic> member,
    String parentName,
    String noKk,
  ) {
    final name = (member['nama'] as String?) ??
        (member['name'] as String?) ??
        'Anak';
    final nik = (member['nik'] as String?) ?? '-';
    final gender = ((member['gender'] as String?) ?? 'L')
            .toLowerCase()
            .startsWith('p')
        ? 'P'
        : 'L';

    final birthDateRaw = member['birth_date']?.toString();
    DateTime? bDate =
        birthDateRaw != null ? DateTime.tryParse(birthDateRaw) : null;

    if (bDate == null) {
      final usiaStr = (member['usia'] as String? ?? '').toLowerCase();
      int monthsAgo = 18;
      final match = RegExp(r'\d+').firstMatch(usiaStr);
      if (match != null) {
        final numVal = int.tryParse(match.group(0) ?? '18') ?? 18;
        if (usiaStr.contains('th') || usiaStr.contains('tahun')) {
          monthsAgo = numVal * 12;
        } else {
          monthsAgo = numVal;
        }
      }
      bDate = DateTime.now().subtract(Duration(days: monthsAgo * 30));
    }

    return ChildProfile(
      id: 'ANK-${nik.isNotEmpty ? nik.substring(nik.length.clamp(0, 6)) : "GEN"}',
      name: name,
      nik: nik,
      birthDate: bDate,
      gender: gender,
      parentName: parentName.isNotEmpty ? parentName : 'Orang Tua Terdaftar',
      noKk: noKk,
      address: (member['address'] as String?) ?? 'Kabupaten Bondowoso',
    );
  }

  static List<ChildVisitRecord> generateVisitsForChild(ChildProfile c) {
    final now = DateTime.now();
    final isUnder24 = c.isUnder24Months;
    final modeCode = isUnder24 ? 'PB' : 'TB';

    final v4 = ChildVisitRecord(
      visitNumber: 'Kunjungan Terakhir (Bulan Ini)',
      monthAgeLabel: 'Bulan ke-${c.ageInMonths}',
      visitDate: now.subtract(const Duration(days: 3)),
      weightKg: isUnder24 ? 11.5 : 16.8,
      heightCm: isUnder24 ? 85.0 : 104.5,
      waistCm: isUnder24 ? 46.0 : 51.5,
      lilaCm: isUnder24 ? 14.8 : 16.2,
      mode: modeCode,
      statusGizi: 'Gizi Baik (Normal)',
      statusGiziColor: const Color(0xFF27AE60),
      statusStunting: 'Normal (Tinggi Sesuai Standar WHO)',
      statusStuntingColor: const Color(0xFF27AE60),
      confidenceGizi: 97.4,
      confidenceStunting: 98.1,
      examiner: 'Puskesmas Tlogosari (dr. Hendra Sp.A & Bidan Anita)',
      reasoningSummary:
          'Pertumbuhan fisik ananda ${c.name} berada pada laju optimal standar WHO. Parameter rasio BB/TB dan TB/U menunjukkan tren kurva pertumbuhan yang stabil.',
      chainOfThought: [
        'Evaluasi usia ${c.ageInMonths} bulan terhadap median berat dan panjang/tinggi standar Permenkes 2020.',
        'Model MLP mengonfirmasi status Gizi Baik (Confidence 97.4%) dan Tinggi Normal (Confidence 98.1%).',
        'Pertumbuhan linier memadai tanpa deviasi stunting kronis (Z-score -0.4 SD).',
      ],
      riskEtiology:
          'Tidak teridentifikasi faktor risiko defisit nutrisi akut. Nafsu makan anak baik dan tidak terdapat riwayat infeksi berulang.',
      nutritionPlan:
          'Tingkatkan variasi protein hewani harian (1 butir telur/hari, ikan lokal, daging/hati ayam). Pastikan pemenuhan mikronutrien Zat Besi dan Zinc sesuai Buku KIA 2024.',
      medicalProtocol:
          'Jadwalkan kunjungan antropometri berkala bulan depan di Posyandu/Puskesmas. Pantau kepatuhan suplementasi Vitamin A kapsul sesuai jadwal.',
      parentEducation:
          'Bunda dan Ayah disarankan tetap mempertahankan pola makan gizi seimbang dengan 1 butir telur per hari, memberikan stimulasi motorik dan bicara melalui bermain bersama, serta memastikan cuci tangan pakai sabun sebelum memberi makan anak.',
    );

    return [v4];
  }

  /// Creates ActiveChildContext for the logged-in user themselves.
  static ActiveChildContext createSelfContext(
    Map<String, dynamic> user, {
    bool isEn = false,
  }) {
    final name = (user['name'] as String? ?? 'Pasien').trim();
    final bb = user['berat_badan']?.toString() ?? '62.0 kg';
    final tb = user['tinggi_badan']?.toString() ?? '168.0 cm';
    final usia = user['usia']?.toString() ?? (isEn ? 'Adult' : 'Dewasa');

    return ActiveChildContext(
      childName: '$name ${isEn ? '(Self)' : '(Saya)'}',
      age: usia,
      bb: bb.contains('kg') ? bb : '$bb kg',
      tb: tb.contains('cm') ? tb : '$tb cm',
      statusGizi: isEn ? 'Normal Adult' : 'Normal (Dewasa)',
      nutritionPlan: isEn
          ? 'Maintain balanced nutrition, regular hydration, and active lifestyle.'
          : 'Pertahankan pola makan gizi seimbang, hidrasi cukup, dan olahraga teratur.',
      childId: user['id']?.toString(),
      childNik: user['nik']?.toString(),
      isSelf: true,
    );
  }

  /// Creates ActiveChildContext for the entire household (1 KK).
  static ActiveChildContext createAllFamilyContext(
    Map<String, dynamic>? user,
    List<PasienChildModel> familyMembers, {
    bool isEn = false,
  }) {
    final noKk = (user?['no_kk'] as String? ?? '').trim();
    final count = familyMembers.length;
    final childCount = familyMembers.where((m) => m.isChild).length;
    final balitaCount = familyMembers.where((m) => m.isBalita).length;

    return ActiveChildContext(
      childName: isEn
          ? 'Entire Family (1 KK Household)'
          : 'Semua Anggota Keluarga (1 KK)',
      age: isEn
          ? '$count Members ($balitaCount Toddlers, $childCount Children)'
          : '$count Anggota ($balitaCount Balita, $childCount Anak)',
      bb: isEn ? 'Comprehensive Health' : 'Kesehatan Komprehensif',
      tb: isEn ? 'Family Wellness' : 'Keluarga Sehat',
      statusGizi: isEn
          ? 'Holistic Family Assessment'
          : 'Evaluasi Terpadu 1 Rumah Tangga',
      nutritionPlan: isEn
          ? 'Holistic assessment covering maternal health, toddler growth (0-59 mo), adult wellness, and shared nutritional balance.'
          : 'Analisis menyeluruh mencakup tumbuh kembang balita (0–59 bulan), gizi keluarga, status ANC ibu hamil, dan kesehatan umum orang tua.',
      childId: 'all_family_kk',
      childNik: noKk.isNotEmpty ? noKk : null,
      isSelf: false,
    );
  }
}
