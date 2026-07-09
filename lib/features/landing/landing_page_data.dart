import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:ui' as ui;
import 'package:mapotech/shared/supabase_service.dart';


// --- MODELS ---

class AchievementItem {
  final String id;
  final String title;
  final String description;
  final String image;
  final String link;
  final IconData icon;

  const AchievementItem({
    required this.id,
    required this.title,
    required this.description,
    required this.image,
    required this.link,
    required this.icon,
  });
}

class UpdateItem {
  final String id;
  final String title;
  final String description;
  final String date;
  final String type; // 'feature' or 'improvement'

  const UpdateItem({
    required this.id,
    required this.title,
    required this.description,
    required this.date,
    required this.type,
  });
}

class EntityItem {
  final String id;
  final String label;
  final IconData icon;
  final bool isSoon;

  const EntityItem({
    required this.id,
    required this.label,
    required this.icon,
    this.isSoon = false,
  });
}

class SimulatorCardData {
  final IconData icon;
  final String title;
  final String subtitle;

  const SimulatorCardData({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
}

class SimulatorData {
  final String welcomeText;
  final String avatarLabel;
  final String statusText;
  final String infoText;
  final List<SimulatorCardData> cards;

  const SimulatorData({
    required this.welcomeText,
    required this.avatarLabel,
    required this.statusText,
    required this.infoText,
    required this.cards,
  });
}

// --- STATE MANAGEMENT ---

class LandingPageState {
  final String activeTab;
  final String language; // 'id' or 'en'
  final String appearance; // 'light', 'dark', 'rev'
  final bool isLoggedIn;
  final String? loggedInRole;
  final String? loggedInName;
  final Map<String, dynamic>? loggedInUser;
  final int drawerSize; // 0: Collapsed, 1: Expanded, 2: Full-screen
  final bool blurProfileEffectEnabled;
  final bool satusehatAutoSync;
  final Set<String> syncedTransactions;
  final double defaultServiceFee;
  final String receiptPaperSize; // 'A4', 'A5', 'Thermal 58mm', 'Thermal 80mm'
  final bool isSubscribed;

  bool get isAssistant =>
      loggedInUser?['role'] == 'asisten_dokter' ||
      loggedInUser?['role'] == 'asisten_apotek';

  String? get activeDoctorId {
    if (loggedInUser?['role'] == 'asisten_dokter') {
      return loggedInUser?['doctor_id'] as String?;
    }
    return loggedInUser?['id'] as String?;
  }

  String? get activeApotekId {
    if (loggedInUser?['role'] == 'asisten_apotek') {
      return loggedInUser?['apotek_id'] as String?;
    }
    return loggedInUser?['id'] as String?;
  }

  const LandingPageState({
    required this.activeTab,
    required this.language,
    required this.appearance,
    this.isLoggedIn = false,
    this.loggedInRole,
    this.loggedInName,
    this.loggedInUser,
    this.drawerSize = 1,
    this.blurProfileEffectEnabled = true,
    this.satusehatAutoSync = true,
    this.syncedTransactions = const {},
    this.defaultServiceFee = 0.0,
    this.receiptPaperSize = 'A4',
    this.isSubscribed = true,
  });

  LandingPageState copyWith({
    String? activeTab,
    String? language,
    String? appearance,
    bool? isLoggedIn,
    String? loggedInRole,
    String? loggedInName,
    Map<String, dynamic>? loggedInUser,
    int? drawerSize,
    bool? blurProfileEffectEnabled,
    bool? satusehatAutoSync,
    Set<String>? syncedTransactions,
    double? defaultServiceFee,
    String? receiptPaperSize,
    bool? isSubscribed,
  }) {
    return LandingPageState(
      activeTab: activeTab ?? this.activeTab,
      language: language ?? this.language,
      appearance: appearance ?? this.appearance,
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      loggedInRole: loggedInRole ?? this.loggedInRole,
      loggedInName: loggedInName ?? this.loggedInName,
      loggedInUser: loggedInUser ?? this.loggedInUser,
      drawerSize: drawerSize ?? this.drawerSize,
      blurProfileEffectEnabled: blurProfileEffectEnabled ?? this.blurProfileEffectEnabled,
      satusehatAutoSync: satusehatAutoSync ?? this.satusehatAutoSync,
      syncedTransactions: syncedTransactions ?? this.syncedTransactions,
      defaultServiceFee: defaultServiceFee ?? this.defaultServiceFee,
      receiptPaperSize: receiptPaperSize ?? this.receiptPaperSize,
      isSubscribed: isSubscribed ?? this.isSubscribed,
    );
  }
}

class LandingPageNotifier extends StateNotifier<LandingPageState> {
  LandingPageNotifier()
      : super(LandingPageState(
            activeTab: 'mapotek',
            language: _detectSystemLanguage(),
            appearance: 'light',
            isLoggedIn: false,
            loggedInRole: null,
            loggedInName: null,
            loggedInUser: null,
            drawerSize: 1,
            blurProfileEffectEnabled: true,
            satusehatAutoSync: true,
            syncedTransactions: const {}));

  static String _detectSystemLanguage() {
    try {
      final localeCode = ui.PlatformDispatcher.instance.locale.languageCode.toLowerCase();
      if (localeCode == 'id' || localeCode == 'in') {
        return 'id';
      }
    } catch (_) {}
    return 'en'; // Default to English if system/browser is not Indonesian
  }

  void login(
    String role, {
    Map<String, dynamic>? user,
    bool? blurProfileEffectEnabled,
    double? defaultServiceFee,
    bool? satusehatAutoSync,
    String? language,
  }) {
    state = state.copyWith(
      isLoggedIn: true,
      loggedInRole: role,
      loggedInName: user?['name'] ?? (role == 'pasien' ? 'Alvin' : (role == 'dokter' ? 'dr. Agoes Soetanto' : 'CyrenElysia~♪')),
      loggedInUser: user,
      blurProfileEffectEnabled: blurProfileEffectEnabled ?? state.blurProfileEffectEnabled,
      defaultServiceFee: defaultServiceFee ?? state.defaultServiceFee,
      satusehatAutoSync: satusehatAutoSync ?? state.satusehatAutoSync,
      language: language ?? state.language,
    );
  }

  void logout() {
    state = state.copyWith(isLoggedIn: false, loggedInRole: null, loggedInName: null, loggedInUser: null, drawerSize: 1, isSubscribed: true);
  }

  void setSubscribed(bool val) {
    state = state.copyWith(isSubscribed: val);
  }

  void updateUser(Map<String, dynamic> updatedFields) {
    if (state.loggedInUser != null) {
      final nextUser = Map<String, dynamic>.from(state.loggedInUser!);
      nextUser.addAll(updatedFields);
      state = state.copyWith(
        loggedInUser: nextUser,
        loggedInName: nextUser['name'],
      );
    }
  }

  void setDrawerSize(int size) {
    state = state.copyWith(drawerSize: size);
  }

  void toggleDrawerSize() {
    // Cycles: 0 -> 1 -> 0
    state = state.copyWith(drawerSize: state.drawerSize == 0 ? 1 : 0);
  }

  void toggleFullScreenDrawer() {
    // Toggles between full-screen (2) and expanded (1)
    state = state.copyWith(drawerSize: state.drawerSize == 2 ? 1 : 2);
  }

  void setActiveTab(String tab) {
    state = state.copyWith(activeTab: tab);
  }

  void setLanguage(String lang) async {
    state = state.copyWith(language: lang);
    final userId = state.loggedInUser?['id'];
    if (userId != null) {
      try {
        await SupabaseService.client
            .from('user')
            .update({'language': lang})
            .eq('id', userId);
      } catch (e) {
        debugPrint('Failed to save language: $e');
      }
    }
  }

  void toggleLanguage() {
    setLanguage(state.language == 'id' ? 'en' : 'id');
  }

  void updateAppearance(String value) {
    state = state.copyWith(appearance: value);
  }

  void setBlurProfileEffect(bool enabled) async {
    state = state.copyWith(blurProfileEffectEnabled: enabled);
    final userId = state.loggedInUser?['id'];
    if (userId != null) {
      try {
        await SupabaseService.client
            .from('user')
            .update({'is_blur_enabled': enabled})
            .eq('id', userId);
      } catch (e) {
        debugPrint('Failed to save is_blur_enabled: $e');
      }
    }
  }

  void setSatusehatAutoSync(bool val) async {
    state = state.copyWith(satusehatAutoSync: val);
    final userId = state.loggedInUser?['id'];
    if (userId != null && state.loggedInRole == 'dokter') {
      try {
        await SupabaseService.client
            .from('user_detail_doctor')
            .update({'satusehat_auto_sync': val})
            .eq('id', userId);
      } catch (e) {
        debugPrint('Failed to save satusehat_auto_sync: $e');
      }
    }
  }

  void setDefaultServiceFee(double val) async {
    state = state.copyWith(defaultServiceFee: val);
    final userId = state.loggedInUser?['id'];
    if (userId != null && state.loggedInRole == 'dokter') {
      try {
        await SupabaseService.client
            .from('user_detail_doctor')
            .update({'default_service_fee': val})
            .eq('id', userId);
      } catch (e) {
        debugPrint('Failed to save default_service_fee: $e');
      }
    }
  }

  void setReceiptPaperSize(String val) async {
    state = state.copyWith(receiptPaperSize: val);
    final userId = state.loggedInUser?['id'];
    if (userId != null && state.loggedInRole == 'dokter') {
      try {
        await SupabaseService.client
            .from('user_detail_doctor')
            .update({'receipt_paper_size': val})
            .eq('id', userId);
      } catch (e) {
        debugPrint('Failed to save receipt_paper_size: $e');
      }
    }
  }

  void markTransactionSynced(String id) {
    state = state.copyWith(syncedTransactions: {...state.syncedTransactions, id});
  }

  // --- THEME COLOR GETTERS ---

  Color getPrimaryColor() {
    switch (state.appearance) {
      case 'dark':
        return const Color(0xFFFAFAFA);
      case 'rev':
        return const Color(0xFFB577F2); // Lavender purple
      case 'light':
      default:
        return const Color(0xFF48C9B0); // Turquoise
    }
  }

  Color getSecondaryColor() {
    switch (state.appearance) {
      case 'dark':
        return const Color(0xFF333333);
      case 'rev':
        return const Color(0xFFFFB5E8); // Light pink
      case 'light':
      default:
        return const Color(0xFF1B4F42); // Dark green
    }
  }

  Color getBackgroundColor() {
    switch (state.appearance) {
      case 'dark':
        return const Color(0xFF0A0A0A);
      case 'rev':
        return const Color(0xFFF0F5FA); // Ice blue/white
      case 'light':
      default:
        return const Color(0xFFFDFDFC);
    }
  }

  Color getTextColor() {
    switch (state.appearance) {
      case 'dark':
        return const Color(0xFFFAFAFA);
      case 'rev':
        return const Color(0xFF5E1B8C); // Deep purple
      case 'light':
      default:
        return const Color(0xFF1B4F42); // Dark green
    }
  }

  Color getBodyTextColor() {
    switch (state.appearance) {
      case 'dark':
        return const Color(0xFFB0B0B0);
      case 'rev':
        return const Color(0xFF7E4A9E); // Medium purple
      case 'light':
      default:
        return const Color(0xFF666666); // Gray
    }
  }

  Color getCardColor() {
    switch (state.appearance) {
      case 'dark':
        return const Color(0xFF161616);
      case 'rev':
        return Colors.white;
      case 'light':
      default:
        return Colors.white;
    }
  }

  Color getBorderColor() {
    switch (state.appearance) {
      case 'dark':
        return const Color(0xFF2C2C2C);
      case 'rev':
        return const Color(0xFFE2C4F9); // Soft lavender border
      case 'light':
      default:
        return const Color(0xFFECECEC);
    }
  }

  // --- LOCALIZED DATA GETTERS ---

  String t(String key) {
    final lang = state.language;
    if (_translations.containsKey(lang) &&
        _translations[lang]!.containsKey(key)) {
      return _translations[lang]![key]!;
    }
    return _translations['id']?[key] ?? key;
  }

  List<EntityItem> getEntities() {
    return [
      EntityItem(
          id: 'pasien',
          label: t('selection_public'),
          icon: Icons.person_rounded),
      EntityItem(
          id: 'dokter',
          label: t('selection_dokter'),
          icon: Icons.medical_services_rounded),
      EntityItem(
          id: 'apotek',
          label: t('selection_apotek'),
          icon: Icons.local_pharmacy_rounded),
      EntityItem(
          id: 'klinik',
          label: t('selection_klinik'),
          icon: Icons.local_hospital_rounded,
          isSoon: true),
      EntityItem(
          id: 'puskesmas',
          label: t('selection_puskesmas'),
          icon: Icons.domain_rounded,
          isSoon: true),
      EntityItem(
          id: 'rumahsakit',
          label: t('selection_rumahsakit'),
          icon: Icons.corporate_fare_rounded,
          isSoon: true),
      EntityItem(
          id: 'ponkesdes',
          label: t('selection_ponkesdes'),
          icon: Icons.home_work_rounded,
          isSoon: true),
      EntityItem(
          id: 'posyandu',
          label: t('selection_posyandu'),
          icon: Icons.favorite_rounded,
          isSoon: true),
    ];
  }

  List<UpdateItem> getUpdatesForActiveTab() {
    final tab = state.activeTab;
    final lang = state.language;

    final updatesMap = lang == 'id' ? _updatesDataId : _updatesDataEn;
    return updatesMap[tab] ?? [];
  }

  List<AchievementItem> getAchievements() {
    final lang = state.language;
    return [
      AchievementItem(
        id: '1',
        title: lang == 'id'
            ? 'Juara 1 Pengembangan Aplikasi'
            : '1st Winner Application Development',
        description: lang == 'id'
            ? 'Penghargaan atas inovasi dalam pengembangan aplikasi kesehatan pada Semester 3.'
            : 'Award for innovation in health application development in Semester 3.',
        image: 'https://images.unsplash.com/photo-1505751172876-fa1923c5c528?q=80&w=600', // Premium health tech photo as placeholder/asset
        link:
            'https://drive.google.com/file/d/1pRlRavbSIAJ_EqMwYRSWX4Cs2KqrFvbM/view?usp=drive_link',
        icon: Icons.emoji_events_rounded,
      ),
      AchievementItem(
        id: '2',
        title: lang == 'id'
            ? 'Juara 1 Desain Poster'
            : '1st Winner Poster Design',
        description: lang == 'id'
            ? 'Prestasi dalam kompetisi desain poster medis pada Semester 1 & 2.'
            : 'Achievement in medical poster design competition in Semester 1 & 2.',
        image: 'https://images.unsplash.com/photo-1584515979956-d9f6e5d09982?q=80&w=600', // Premium medical design photo
        link:
            'https://drive.google.com/file/d/1OXRAVNAVlxDPreVEWFRI7IcamIfrb2bu/view?usp=drive_link',
        icon: Icons.workspace_premium_rounded,
      ),
    ];
  }

  // --- HERO DYNAMIC TEXT GETTERS ---

  String getHeroTagline() {
    final lang = state.language;
    final tab = state.activeTab;
    
    if (tab == 'mapotek') {
      return t('hero_tagline');
    }
    
    switch (tab) {
      case 'pasien':
        return lang == 'id' ? 'PINTU MASUK MASYARAKAT' : 'COMMUNITY / PATIENT GATEWAY';
      case 'dokter':
        return lang == 'id' ? 'PINTU MASUK PRAKTIK MANDIRI' : 'PRIVATE PRACTICE GATEWAY';
      case 'apotek':
        return lang == 'id' ? 'PINTU MASUK JEJARING APOTEK' : 'PHARMACY NETWORK GATEWAY';
      case 'klinik':
        return lang == 'id' ? 'PINTU MASUK KLINIK KESEHATAN' : 'CLINIC GATEWAY';
      case 'puskesmas':
        return lang == 'id' ? 'PINTU MASUK PUSKESMAS' : 'PUBLIC HEALTH CENTER GATEWAY';
      case 'rumahsakit':
        return lang == 'id' ? 'PINTU MASUK RUMAH SAKIT' : 'HOSPITAL GATEWAY';
      case 'ponkesdes':
        return lang == 'id' ? 'PINTU MASUK PONKESDES' : 'VILLAGE HEALTH GATEWAY';
      case 'posyandu':
        return lang == 'id' ? 'PINTU MASUK POSYANDU' : 'FAMILY HEALTH GATEWAY';
      default:
        return t('hero_tagline');
    }
  }

  String getHeroTitle() {
    final lang = state.language;
    final tab = state.activeTab;
    
    if (tab == 'mapotek') {
      return t('hero_title');
    }
    
    switch (tab) {
      case 'pasien':
        return lang == 'id' ? 'Sehat Itu Sederhana.' : 'Health is Simple.';
      case 'dokter':
        return lang == 'id' ? 'Efisiensi Praktik.' : 'Practice Efficiency.';
      case 'apotek':
        return lang == 'id' ? 'Manajemen Apotek Modern.' : 'Modern Pharmacy Management.';
      case 'klinik':
        return lang == 'id' ? 'Sistem Klinik Cerdas.' : 'Smart Clinic System.';
      case 'puskesmas':
        return lang == 'id' ? 'Kesehatan Masyarakat Terpadu.' : 'Integrated Public Health.';
      case 'rumahsakit':
        return lang == 'id' ? 'Sinergi Layanan RS.' : 'Hospital Service Synergy.';
      case 'ponkesdes':
        return lang == 'id' ? 'Kesehatan Desa Digital.' : 'Digital Village Health.';
      case 'posyandu':
        return lang == 'id' ? 'Tumbuh Kembang Prima.' : 'Prime Growth Monitoring.';
      default:
        return t('hero_title');
    }
  }

  String getHeroDescription() {
    final lang = state.language;
    final tab = state.activeTab;
    
    if (tab == 'mapotek') {
      return t('hero_desc');
    }
    
    switch (tab) {
      case 'pasien':
        return lang == 'id'
            ? 'Akses dokter, resep, dan riwayat medismu dimanapun, kapanpun.'
            : 'Access doctors, prescriptions, and your medical history anywhere, anytime.';
      case 'dokter':
        return lang == 'id'
            ? 'Digitalisasi catatan medis masyarakat dan atur jadwal konsultasi secara instan.'
            : 'Digitize community medical records and organize consultation schedules instantly.';
      case 'apotek':
        return lang == 'id'
            ? 'Kelola persediaan obat terintegrasi SatuSehat, terima resep digital langsung dari klinik/dokter, serta kasir pos yang handal.'
            : 'Manage SatuSehat integrated drug inventory, receive digital prescriptions directly from clinics/doctors, and reliable POS cashier.';
      case 'klinik':
        return lang == 'id'
            ? 'Sistem Rekam Medis Elektronik (RME) mandiri dengan manajemen pasien, antrean, dan billing kasir klinik yang intuitif.'
            : 'Independent EMR system with intuitive patient, queue, and clinic billing management.';
      case 'puskesmas':
        return lang == 'id'
            ? 'Pusat pelayanan kesehatan masyarakat terpadu dengan integrasi antrean faskes rujukan SatuSehat secara seamless.'
            : 'Integrated public health service center with seamless SatuSehat referral health facility queue integration.';
      case 'rumahsakit':
        return lang == 'id'
            ? 'Sistem ERP Rumah Sakit kelas enterprise untuk manajemen bangsal, rawat inap/jalan, dan laboratorium farmasi lengkap.'
            : 'Enterprise-grade Hospital ERP system for ward, inpatient/outpatient, and laboratory pharmacy management.';
      case 'ponkesdes':
        return lang == 'id'
            ? 'Layanan kesehatan tingkat desa dengan pencatatan kunjungan rumah dan integrasi bidan desa secara digital.'
            : 'Village-level health service with digital home visit tracking and village midwife integration.';
      case 'posyandu':
        return lang == 'id'
            ? 'Pemantauan tumbuh kembang balita, imunisasi anak, dan edukasi gizi ibu hamil secara berkala di pos pelayanan terdekat.'
            : 'Regular monitoring of toddler growth, child immunization, and maternal nutrition education at the nearest post.';
      default:
        return t('hero_desc');
    }
  }

  // --- DYNAMIC SIMULATOR DEVICE GETTER ---

  SimulatorData getSimulatorData() {
    final lang = state.language;
    final tab = state.activeTab;

    switch (tab) {
      case 'dokter':
        return SimulatorData(
          welcomeText: 'Dr. Vanillanyan',
          avatarLabel: 'VN',
          statusText: lang == 'id' ? 'SEDANG BERTUGAS' : 'ON DUTY',
          infoText: lang == 'id' ? 'Dokter Umum' : 'General Practitioner',
          cards: [
            SimulatorCardData(
              icon: Icons.people_rounded,
              title: lang == 'id' ? 'Total Pasien' : 'Total Patients',
              subtitle: '6',
            ),
            SimulatorCardData(
              icon: Icons.pending_actions_rounded,
              title: lang == 'id' ? 'Antrean Hari Ini' : 'Today\'s Queues',
              subtitle: '2',
            ),
            SimulatorCardData(
              icon: Icons.warning_amber_rounded,
              title: lang == 'id' ? 'Obat Kedaluwarsa' : 'Expired Meds',
              subtitle: '00',
            ),
          ],
        );
      case 'apotek':
        return SimulatorData(
          welcomeText: 'Apotek Mandiri',
          avatarLabel: 'AP',
          statusText: lang == 'id' ? 'BUKA 24 JAM' : 'OPEN 24 HOURS',
          infoText: lang == 'id' ? 'Apoteker: Ratih, S.Farm' : 'Pharmacist: Ratih',
          cards: [
            SimulatorCardData(
              icon: Icons.inventory_rounded,
              title: lang == 'id' ? 'Stok Menipis' : 'Low Stock Items',
              subtitle: '3 ${lang == 'id' ? 'Obat' : 'Medicines'}',
            ),
            SimulatorCardData(
              icon: Icons.point_of_sale_rounded,
              title: lang == 'id' ? 'Transaksi Hari Ini' : 'Today Transactions',
              subtitle: 'Rp 1.250.000',
            ),
            SimulatorCardData(
              icon: Icons.description_rounded,
              title: lang == 'id' ? 'Penebusan Resep' : 'Rx Redemptions',
              subtitle: '8 ${lang == 'id' ? 'Resep' : 'Prescriptions'}',
            ),
          ],
        );
      case 'pasien':
      case 'mapotek':
      default:
        return SimulatorData(
          welcomeText: 'Elysia-♪',
          avatarLabel: 'EL',
          statusText: lang == 'id' ? 'AKTIF SatuSehat' : 'ACTIVE SatuSehat',
          infoText: '20 TH | RT 01/RW 02',
          cards: [
            SimulatorCardData(
              icon: Icons.calendar_today_rounded,
              title: lang == 'id' ? 'Booking Antrean' : 'Queue Booking',
              subtitle: lang == 'id' ? 'Antrean No. 12' : 'Queue No. 12',
            ),
            SimulatorCardData(
              icon: Icons.receipt_long_rounded,
              title: lang == 'id' ? 'E-Resep Digital' : 'E-Prescription',
              subtitle: lang == 'id' ? '2 Resep Aktif' : '2 Active Rx',
            ),
            SimulatorCardData(
              icon: Icons.sync_rounded,
              title: lang == 'id' ? 'SatuSehat Sync' : 'SatuSehat Synced',
              subtitle: lang == 'id' ? 'Data Terkirim' : 'Data Synced',
            ),
          ],
        );
    }
  }

  List<Map<String, dynamic>> getSitemap() {
    final lang = state.language;
    final isId = lang == 'id';
    return [
      {
        'title': isId ? 'ENTITAS' : 'ENTITIES',
        'items': [
          {'label': isId ? 'MASYARAKAT' : 'COMMUNITY', 'tab': 'pasien'},
          {'label': isId ? 'Praktik Mandiri' : 'Private Practice', 'tab': 'dokter'},
          {'label': isId ? 'Apotek' : 'Pharmacy', 'tab': 'apotek'},
          {'label': isId ? 'Klinik' : 'Clinic', 'tab': 'klinik'},
        ]
      },
      {
        'title': isId ? 'INFRASTRUKTUR' : 'INFRASTRUCTURE',
        'items': [
          {'label': isId ? 'Puskesmas' : 'Health Center', 'tab': 'puskesmas'},
          {'label': isId ? 'Rumah Sakit' : 'Hospital', 'tab': 'rumahsakit'},
          {'label': isId ? 'PONKESDES' : 'Village Clinic', 'tab': 'ponkesdes'},
          {'label': isId ? 'Posyandu' : 'Family Health', 'tab': 'posyandu'},
        ]
      },
      {
        'title': isId ? 'SUMBER DAYA' : 'RESOURCES',
        'items': [
          {'label': isId ? 'Dokumentasi' : 'Documentation', 'tab': ''},
          {'label': isId ? 'Standar Keamanan' : 'Security Standards', 'tab': ''},
          {'label': isId ? 'Referensi API' : 'API Reference', 'tab': ''},
        ]
      },
      {
        'title': isId ? 'PROYEK' : 'PROJECT',
        'items': [
          {'label': isId ? 'Visi Kami' : 'Our Vision', 'tab': 'mapotek'},
          {'label': isId ? 'Kebijakan Privasi' : 'Privacy Policy', 'tab': ''},
          {'label': isId ? 'Ketentuan Layanan' : 'Terms of Service', 'tab': ''},
        ]
      },
    ];
  }
}

// --- PROVIDER ---

final landingPageProvider =
    StateNotifierProvider<LandingPageNotifier, LandingPageState>((ref) {
  return LandingPageNotifier();
});

// --- TRANSLATIONS DICTIONARY ---

const _translations = {
  'id': {
    'portal_title': 'PORTAL',
    'entities': 'ENTITAS KESEHATAN',
    'soon': 'SEGERA',
    'dashboard': 'DASHBOARD',
    'login': 'MASUK',
    'register': 'DAFTAR',
    'welcome_back': 'Selamat Datang Kembali',
    'welcome_back_user': 'SELAMAT DATANG KEMBALI',
    'start_access': 'MULAI AKSES',
    'learn_more': 'PELAJARI SELENGKAPNYA',
    'trusted_providers': 'Penyedia Layanan Terpercaya',
    'securely_integrated': 'Terintegrasi SatuSehat',
    'hero_tagline': 'PORTAL KESEHATAN DIGITAL INTEGRATIF',
    'hero_title': 'MAPOTECH',
    'hero_desc':
        'Medical Application Platform for Operational Technology and Connected Healthcare. Ekosistem kesehatan digital modern yang menghubungkan Dokter, Pasien, Apotek, dan Fasilitas Kesehatan dalam satu platform terintegrasi SatuSehat Kemenkes.',
    'selection_public': 'Masyarakat',
    'selection_dokter': 'Praktik Mandiri',
    'selection_apotek': 'Apotek',
    'selection_klinik': 'Klinik',
    'selection_puskesmas': 'Puskesmas',
    'selection_rumahsakit': 'Rumah Sakit',
    'selection_ponkesdes': 'PONKESDES',
    'selection_posyandu': 'Posyandu',
    'why_choose_us': 'MENGAPA MEMILIH KAMI?',
    'achievements': 'PENCAPAIAN',
    'achievements_desc':
        'Inovasi dan dedikasi kami dalam menghadirkan solusi teknologi kesehatan terbaik yang telah diakui secara akademis and profesional.',
    'footer_text': '© 2026 MAPOTECH. All rights reserved. Built with Flutter & Riverpod.',
    'features_title': 'FITUR LAYANAN EKOSISTEM',
    'features_desc': 'Manfaat nyata untuk mempermudah operasional dan pelayanan kesehatan digital Anda.',
    'vision_badge': 'VISI KAMI',
    'vision_title': 'Transformasi Digital dalam Layanan Kesehatan.',
    'vision_desc': 'MAPOTECH bertujuan menjadi platform manajemen kesehatan terpadu, terukur, dan terjangkau yang menjembatani penyedia layanan dan pasien demi transformasi digital kesehatan.',
    'vision_btn': 'GABUNG KE EKOSISTEM',
    'timeline_badge': 'PROGRES SISTEM',
    'timeline_title': 'Apa yang Baru di MAPOTECH',
    'timeline_desc': 'Jelajahi perkembangan terbaru dan peta jalan masa depan ekosistem kesehatan digital kami.',
    'version_badge_title': 'VERSI SAAT INI',
    'version_badge_value': 'Alpha 0.2.1',
    'github_capsule_title': 'TETAP TERUPDATE',
    'github_capsule_desc': 'Ikuti sumber di GitHub',
    'lihat_sertifikat': 'LIHAT SERTIFIKAT',
    'masyarakat_portal_badge': 'PINTU MASUK MASYARAKAT',
    'masyarakat_features_title': 'FITUR UNGGULAN',
    'masyarakat_timeline_title': 'Apa yang Baru di MASYARAKAT',
  },
  'en': {
    'portal_title': 'PORTAL',
    'entities': 'HEALTH ENTITIES',
    'soon': 'SOON',
    'dashboard': 'DASHBOARD',
    'login': 'LOGIN',
    'register': 'REGISTER',
    'welcome_back': 'Welcome Back',
    'welcome_back_user': 'WELCOME BACK',
    'start_access': 'START ACCESS',
    'learn_more': 'LEARN MORE',
    'trusted_providers': 'Trusted Providers',
    'securely_integrated': 'SatuSehat Integrated',
    'hero_tagline': 'INTEGRATIVE DIGITAL HEALTH PORTAL',
    'hero_title': 'MAPOTECH',
    'hero_desc':
        'Medical Application Platform for Operational Technology and Connected Healthcare. A modern digital health ecosystem connecting Doctors, Patients, Pharmacies, and Healthcare Facilities into a single SatuSehat Kemenkes integrated platform.',
    'selection_public': 'Community',
    'selection_dokter': 'Private Practice',
    'selection_apotek': 'Pharmacy',
    'selection_klinik': 'Clinic',
    'selection_puskesmas': 'Health Center',
    'selection_rumahsakit': 'Hospital',
    'selection_ponkesdes': 'Village Clinic',
    'selection_posyandu': 'Family Health',
    'why_choose_us': 'WHY CHOOSE US?',
    'achievements': 'ACHIEVEMENTS',
    'achievements_desc':
        'Our innovation and dedication in delivering the best health technology solutions that are academically and professionally recognized.',
    'footer_text': '© 2026 MAPOTECH. All rights reserved. Built with Flutter & Riverpod.',
    'features_title': 'ECOSYSTEM FEATURES',
    'features_desc': 'Real benefits to ease your digital health operations and services.',
    'vision_badge': 'OUR VISION',
    'vision_title': 'Digital Transformation in Healthcare.',
    'vision_desc': 'MAPOTECH aims to be an integrated, scalable, and affordable health management platform that bridges service providers and patients for digital health transformation.',
    'vision_btn': 'JOIN THE ECOSYSTEM',
    'timeline_badge': 'SYSTEM PROGRESS',
    'timeline_title': 'What\'s New in MAPOTECH',
    'timeline_desc': 'Explore the latest developments and future roadmap of our digital health ecosystem.',
    'version_badge_title': 'CURRENT VERSION',
    'version_badge_value': 'Alpha 0.2.1',
    'github_capsule_title': 'STAY UPDATED',
    'github_capsule_desc': 'Follow sources on GitHub',
    'lihat_sertifikat': 'VIEW CERTIFICATE',
    'masyarakat_portal_badge': 'COMMUNITY PORTAL',
    'masyarakat_features_title': 'KEY FEATURES',
    'masyarakat_timeline_title': 'What\'s New in COMMUNITY',
    // General
    'Batal': 'Cancel',
    'Simpan': 'Save',
    'Keluar': 'Logout',
    'Pengaturan': 'Settings',
    'Cari': 'Search',
    'Semua': 'All',
    // Dashboard
    'INDIKATOR KINERJA UTAMA': 'KEY PERFORMANCE INDICATORS',
    'TOTAL PASIEN': 'TOTAL PATIENTS',
    'ANTREAN HARI INI': 'TODAY\'S QUEUES',
    'OBAT KEDALUWARSA': 'EXPIRED MEDS',
    'STOK MENIPIS': 'LOW STOCK',
    'TREN PEMASUKAN': 'INCOME TREND',
    '+0% dari bulan lalu': '+0% from last month',
    'PASIEN PER HARI': 'PATIENTS PER DAY',
    '7 hari terakhir': 'last 7 days',
    'Daftar Antrean': 'Queue List',
    'Status konsultasi secara real-time': 'Real-time consultation status',
    'TOTAL ANTREAN': 'TOTAL QUEUES',
    '0 pasien': '0 patients',
    'Belum ada pasien dalam antrean hari ini.': 'No patients in queue today.',
    'Lihat Profil': 'View Profile',
    'SEDANG BERTUGAS': 'ON DUTY',
    'Selasa, 26 Mei 2026': 'Tuesday, May 26, 2026',
    // Patients
    'Daftar Pasien': 'Patient List',
    'Kelola konsultasi aktif dan riwayat pasien': 'Manage active consultations and patient history',
    'Cari nama, NIK, No. Rekam Medis...': 'Search name, NIK, Medical Record No...',
    '+ Tambah Pasien Baru': '+ Add New Patient',
    'Tambah Pasien': 'Add Patient',
    'Cari nama, NIK, atau ID...': 'Search name, NIK, or ID...',
    'Pasien tidak ditemukan': 'Patient not found',
    'Coba gunakan kata kunci pencarian yang berbeda.': 'Try using different search keywords.',
    'Belum ada data pasien terdaftar.': 'No registered patient data yet.',
    // Medicines
    'Data Obat': 'Medicine Data',
    'Tambah Obat': 'Add Medicine',
    'Daftar Katalog Obat': 'Medicine Catalog List',
    'Stok Minim': 'Low Stock',
    'Hampir Kadaluarsa': 'Near Expired',
    'Kelola stok, lacak batch, dan pantau tanggal kedaluwarsa.': 'Manage stock, track batches, and monitor expiration dates.',
    'Semua Obat': 'All Medicines',
    'Hampir Kedaluwarsa': 'Near Expired',
    'Cari nama, SKU, atau ID batch...': 'Search name, SKU, or batch ID...',
    'Tambah Obat Baru': 'Add New Medicine',
    'Isi data obat beserta informasi batch awal.': 'Fill in drug data along with initial batch info.',
    'CARI DARI KATALOG SATUSEHAT KFA': 'SEARCH FROM SATUSEHAT KFA CATALOG',
    'Opsional — isi otomatis nama, bentuk & kode KFA': 'Optional — auto-fill name, form & KFA code',
    'cth. Paracetamol, Amoxicillin...': 'e.g. Paracetamol, Amoxicillin...',
    'Cari KFA': 'Search KFA',
    'INFORMASI UMUM': 'GENERAL INFORMATION',
    'Nama Obat': 'Drug Name',
    'cth. Paracetamol 500mg': 'e.g. Paracetamol 500mg',
    'SKU / Barcode': 'SKU / Barcode',
    'cth. 8993601452': 'e.g. 8993601452',
    'Jenis': 'Type',
    'Pilih Jenis / Generic': 'Select Type / Generic',
    'Generik': 'Generic',
    'Paten': 'Patent',
    'Satuan': 'Unit',
    'Pilih Satuan': 'Select Unit',
    'Tablet': 'Tablet',
    'Kapsul': 'Capsule',
    'Botol': 'Bottle',
    'Tube': 'Tube',
    'Pcs': 'Pcs',
    'BATCH AWAL': 'INITIAL BATCH',
    'Nomor Batch': 'Batch Number',
    'Stok Awal': 'Initial Stock',
    'Total Harga Beli (Modal)': 'Total Buy Price (Cost)',
    'Harga Beli Satuan (Hasil Kalkulasi)': 'Unit Buy Price (Calculated)',
    'Harga Jual Satuan': 'Unit Selling Price',
    'Tanggal Kedaluwarsa': 'Expiration Date',
    'Lokasi Penyimpanan': 'Storage Location',
    'cth. Shelf A-01': 'e.g. Shelf A-01',
    'Simpan Obat': 'Save Medicine',
    'INFORMASI OBAT': 'DRUG INFORMATION',
    'SKU / BARCODE': 'SKU / BARCODE',
    'HARGA SATUAN': 'UNIT PRICE',
    'STATUS': 'STATUS',
    'TAMBAH BATCH BARU': 'ADD NEW BATCH',
    'Masukkan jumlah stok fisik hasil penghitungan di lapangan.': 'Enter physical stock count from actual inventory.',
    'BATCH NO.': 'BATCH NO.',
    'STOK SISTEM': 'SYSTEM STOCK',
    'STOK FISIK': 'PHYSICAL STOCK',
    'SELISIH': 'DIFFERENCE',
    'Simpan Opname': 'Save Opname',
    'Reset': 'Reset',
    'RIWAYAT OPNAME': 'OPNAME HISTORY',
    'Belum ada riwayat opname untuk obat ini.': 'No opname history for this medicine yet.',
    'LOKASI': 'LOCATION',
    'KEDALUWARSA': 'EXPIRATION',
    'STOK': 'STOCK',
    'Restock': 'Restock',
    'Jumlah Stok Masuk (Tablet)': 'Incoming Stock Qty (Tablet)',
    'Total Harga Beli': 'Total Buy Price',
    'Tambah Stok': 'Add Stock',
    'cth. Rak A-1': 'e.g. Rack A-1',
    'NAMA OBAT': 'DRUG NAME',
    'KATEGORI': 'CATEGORY',
    'TOTAL STOK': 'TOTAL STOCK',
    'TIPE': 'TYPE',
    'SATUAN': 'UNIT',
    'AKSI': 'ACTION',
    'DETAIL OBAT': 'MEDICINE DETAILS',
    'BATCH & STOK': 'BATCH & STOCK',
    'OPNAME STOK': 'STOCK OPNAME',
    // Queues
    'Antrian Pasien': 'Patient Queues',
    'Data untuk tanggal: ': 'Data for date: ',
    'Daftar Antrean Hari Ini': 'Today\'s Queue List',
    'BATAS KUOTA ANTREAN': 'QUEUE LIMIT',
    '+ Daftarkan Pasien': '+ Register Patient',
    'Ubah Kuota': 'Change Limit',
    'Panggil': 'Call',
    'Layani': 'Serve',
    'Lewati': 'Skip',
    'Tambah Antrian Baru': 'Add New Queue',
    'Cari Pasien': 'Search Patient',
    'Pasien Spesial': 'Special Patient',
    'Cari Pasien *': 'Search Patient *',
    'Ketik nama / NIK...': 'Type name / NIK...',
    'search': 'Search',
    'Ketik minimal 3 karakter': 'Type at least 3 characters',
    'Tidak ada antrian ditemukan.': 'No queues found.',
    'Pasien tidak terdaftar. Gunakan tab Pasien Spesial untuk walk-in.': 'Patient is not registered. Use the Special Patient tab for walk-in.',
    'PASIEN TERDAFTAR': 'REGISTERED PATIENT',
    'Tambah Antrian': 'Add Queue',
    'Tambah Antrian Walk-in': 'Add Walk-in Queue',
    'Daftarkan pasien langsung di loket klinik.': 'Register patients directly at the clinic counter.',
    'Kembali': 'Back',
    'Simpan Antrian': 'Save Queue',
    'Lanjut →': 'Continue →',
    'Nama Pasien (Wajib)': 'Patient Name (Required)',
    'Nama Lengkap': 'Full Name',
    'NIK (Wajib)': 'NIK (Required)',
    'Masukkan NIK': 'Enter NIK',
    'Nomor Telepon (Opsional)': 'Phone Number (Optional)',
    '— Pilih —': '— Choose —',
    'Laki-laki': 'Male',
    'Perempuan': 'Female',
    'Cek & Verifikasi NIK (SatuSehat)': 'Check & Verify NIK (SatuSehat)',
    'Catatan: Pasien ini hanya terdaftar untuk antrian hari ini and tidak tersimpan di database pasien permanen.': 'Note: This patient is only registered for today\'s queue and is not saved in the permanent patient database.',
    'Tipe Pasien *': 'Patient Type *',
    'Umum': 'General',
    'Tanggal Antrian *': 'Queue Date *',
    'Pilih Tanggal': 'Select Date',
    'Waktu Antrian *': 'Queue Time *',
    'Nomor Antrian (Otomatis)': 'Queue Number (Automatic)',
    'Format: DDMM-NNN (Contoh: 1212-001)': 'Format: DDMM-NNN (Example: 1212-001)',
    // Examinations
    'Pemeriksaan & RME': 'Examinations & EMR',
    'Sesi pencatatan rekam medis elektronik aktif dr. Agoes Soetanto': 'Active electronic medical record recording session for dr. Agoes Soetanto',
    'PEMERIKSAAN FISIK & VITAL': 'PHYSICAL & VITAL EXAMINATIONS',
    'DIAGNOSA MEDIS (ICD-10)': 'MEDICAL DIAGNOSIS (ICD-10)',
    'RESEP OBAT & TERAPI': 'PRESCRIPTIONS & THERAPY',
    'Simpan & Kirim SatuSehat': 'Save & Send SatuSehat',
    'Selesai Pemeriksaan': 'Complete Examination',
    // Bookkeeping
    'Pembukuan': 'Bookkeeping',
    'Ringkasan arus kas masuk, pengeluaran klinik, dan e-resep diintegrasi': 'Summary of cash inflows, clinic expenses, and integrated e-prescriptions',
    'Ringkasan Keuangan': 'Financial Summary',
    'TOTAL PEMASUKAN': 'TOTAL INCOME',
    'TOTAL PENGELUARAN': 'TOTAL EXPENSE',
    'SALDO BERSIH': 'NET BALANCE',
    'Buku Kas': 'Ledger',
    'Catat Pengeluaran Baru': 'Record New Expense',
    'Pemasukan': 'Income',
    'Pengeluaran': 'Expense',
    'Cari transaksi...': 'Search transactions...',
    'Catat Pengeluaran': 'Record Expense',
    // Assistants
    'Daftar Asisten Praktik': 'Practice Assistant List',
    'TOTAL ASISTEN': 'TOTAL ASSISTANTS',
    'BERTUGAS HARI INI': 'ON DUTY TODAY',
    'PERAWAT KLINIK': 'CLINIC NURSES',
    'ADMIN / FRONT DESK': 'ADMIN / FRONT DESK',
    'Cari nama, NIK, atau peran asisten...': 'Search name, NIK, or assistant role...',
    '+ Tambah Asisten': '+ Add Assistant',
    'Registrasi Asisten Baru': 'Register New Assistant',
    // Photo 1: Assistant Form
    'NAMA LENGKAP & GELAR': 'FULL NAME & TITLE',
    'Contoh: Siti Aminah, A.Md.Kep.': 'Example: Siti Aminah, A.Md.Kep.',
    'NIK (KTP 16-DIGIT)': 'NIK (16-DIGIT ID)',
    'PERAN / JABATAN': 'ROLE / POSITION',
    'Perawat': 'Nurse',
    'SURAT IZIN PRAKTEK (SIP) PERAWAT': 'NURSE PRACTICE LICENSE (SIP)',
    'Contoh: 503/1204/SIP.P/...': 'Example: 503/1204/SIP.P/...',
    'NOMOR TELEPON': 'PHONE NUMBER',
    'EMAIL KLINIK': 'CLINIC EMAIL',
    'IZIN AKSES UTAMA': 'PRIMARY ACCESS PERMISSIONS',
    'Rekam Medis (EMR)': 'Medical Records (EMR)',
    'Pemeriksaan Awal': 'Initial Examination',
    'Registrasi & Antrian': 'Registration & Queue',
    'Billing / Kasir': 'Billing / Cashier',
    'Stok Obat': 'Drug Stock',
    'Simpan Asisten': 'Save Assistant',
    // Photo 2 & 3: Bookkeeping Form & Export
    'Deskripsi Pengeluaran *': 'Expense Description *',
    'cth. Pembelian Reagen Golongan Darah & Syringe': 'e.g. Purchase of Blood Type Reagents & Syringe',
    'Kategori Pengeluaran *': 'Expense Category *',
    'Obat & Medis': 'Meds & Medical',
    'Jumlah Nominal (Rp) *': 'Nominal Amount (Rp) *',
    'cth. 150000': 'e.g. 150000',
    'Simpan Pengeluaran': 'Save Expense',
    'Ekspor Laporan': 'Export Report',
    // Photo 4: EMR Step 2 (Anamnesis)
    'SEDANG DIPERIKSA': 'UNDER EXAMINATION',
    'Pasien': 'Patient',
    'Anamnesa': 'Anamnesis',
    'Kondisi': 'Condition',
    'Vital': 'Vitals',
    'Resep': 'Prescription',
    'Keluhan Utama *': 'Chief Complaint *',
    'Tulis keluhan utama pasien, misal: Sakit kepala hebat disertai mual sejak kemarin malam...': 'Write patient\'s chief complaint, e.g. Severe headache with nausea since last night...',
    'Tulis riwayat penyakit atau anamnesis tambahan (opsional)...': 'Write medical history or additional anamnesis (optional)...',
    'Sebelumnya': 'Previous',
    'Selanjutnya': 'Next',
    // Photo 5: Register Patient Form
    'Daftarkan rekam medis pasien di bawah ini': 'Register patient medical record below',
    'Unggah Foto': 'Upload Photo',
    'Nama Lengkap Pasien': 'Patient Full Name',
    'Masukkan nama...': 'Enter name...',
    'Nomor Induk Kependudukan (NIK)': 'National Identity Number (NIK)',
    'Masukkan 16 digit NIK...': 'Enter 16 digit NIK...',
    'Alamat Email': 'Email Address',
    'contoh@email.com': 'example@email.com',
    'Kata Sandi Default': 'Default Password',
    'Buat sandi...': 'Create password...',
    'Tempat Lahir': 'Place of Birth',
    'Kota tempat lahir...': 'City of birth...',
    'Tanggal Lahir': 'Date of Birth',
    'Pilih tanggal...': 'Select date...',
    'Jenis Kelamin': 'Gender',
    'No. Telepon Aktif': 'Active Phone No.',
    '08xxxxxxxxxx': '08xxxxxxxxxx',
    'Alamat Lengkap Domisili': 'Complete Residence Address',
    'Tulis nama jalan, kelurahan, kecamatan, kota...': 'Write street name, village, sub-district, city...',
    'Daftarkan Pasien': 'Register Patient',
    // Profile
    'Profil Dokter': 'Doctor Profile',
    'Jadwal Praktik': 'Practice Schedules',
    'QRIS & Pembayaran': 'QRIS & Payments',
    'Kredensial SatuSehat': 'SatuSehat Credentials',
    'Integrasi BPJS': 'BPJS Integration',
    'Simpan Perubahan': 'Save Changes'
  }
};

// --- DATA LISTS (INDONESIAN) ---

const _updatesDataId = {
  'mapotek': [
    UpdateItem(
      id: '1',
      title: 'Lahirnya MAPOTECH Baru',
      description:
          'Transformasi besar MAPOTEK dengan reposisi makna nama menjadi Medical Application Platform for Operational Technology and Connected Healthcare. Disertai integrasi Manajemen Apotek, fitur E-Resep lintas entitas, dan pengiriman RME manual ke SatuSehat.',
      date: 'Februari 2026',
      type: 'feature',
    ),
    UpdateItem(
      id: '2',
      title: 'Ekosistem Web & Mobile',
      description:
          'Ekspansi MAPOTEK ke platform Web (Dokter) dan Mobile (Pasien) dengan integrasi SatuSehat, booking antrean, dan riwayat medis. Langkah krusial dalam memperluas jangkauan layanan digital MAPOTEK.',
      date: 'Agustus 2025',
      type: 'feature',
    ),
    UpdateItem(
      id: '3',
      title: 'MAPOTEK Desktop Pro',
      description:
          'Peningkatan besar aplikasi Desktop MAPOTEK dengan integrasi print thermal, scan barcode, optimasi loading, serta manajemen Kartu Stok dan Stok Opname yang lebih advance.',
      date: 'Februari 2025',
      type: 'improvement',
    ),
    UpdateItem(
      id: '4',
      title: 'Awal Mula MAPOTEK',
      description:
          'Peluncuran perdana aplikasi Desktop MAPOTEK — Management Application Patient Oriented Teknologi — khusus praktik mandiri untuk manajemen pasien dan pemeriksaan dasar.',
      date: 'Agustus 2024',
      type: 'feature',
    ),
  ],
  'pasien': [
    UpdateItem(
      id: 'p1',
      title: 'Monitoring & Reminder',
      description:
          'Lihat apotek terdaftar, akses E-Resep digital, dan pengingat konsumsi obat otomatis dari dokter.',
      date: 'Februari 2026',
      type: 'feature',
    ),
    UpdateItem(
      id: 'p2',
      title: 'Antrean & Riwayat Online',
      description:
          'Booking antrean dari rumah dan pantau riwayat pemeriksaan medis langsung dari aplikasi mobile.',
      date: 'Agustus 2025',
      type: 'feature',
    ),
  ],
  'dokter': [
    UpdateItem(
      id: 'd1',
      title: 'E-Resep & Manajemen Luar',
      description:
          'Fitur resep elektronik yang terhubung ke Apotek MAPOTECH dan kemampuan input pasien di luar aplikasi.',
      date: 'Februari 2026',
      type: 'feature',
    ),
    UpdateItem(
      id: 'd2',
      title: 'RME & SatuSehat Advance',
      description:
          'Pengiriman data obat terperinci dan fitur kirim manual ke SatuSehat jika terjadi kendala sinkronisasi.',
      date: 'Februari 2026',
      type: 'improvement',
    ),
    UpdateItem(
      id: 'd3',
      title: 'Integrasi SatuSehat Web',
      description:
          'Transisi ke platform web dengan sistem RME yang terstandarisasi SatuSehat Kemenkes.',
      date: 'Agustus 2025',
      type: 'feature',
    ),
    UpdateItem(
      id: 'd4',
      title: 'Sistem Inventori Desktop',
      description:
          'Manajemen stok tingkat lanjut dengan Kartu Stok dan Stok Opname menggunakan aplikasi desktop Java.',
      date: 'Februari 2025',
      type: 'improvement',
    ),
  ],
  'apotek': [
    UpdateItem(
      id: 'a1',
      title: 'Pusat Jejaring Apotek',
      description:
          'Integrasi manajemen apotek modern yang mendukung penebusan (redeem) E-Resep dari dokter MAPOTECH.',
      date: 'Februari 2026',
      type: 'feature',
    ),
  ],
  'puskesmas': [
    UpdateItem(
      id: 'pus1',
      title: 'Analitik Kesehatan Masyarakat',
      description:
          'Pantau tren kesehatan masyarakat dengan dasbor data agregat baru kami.',
      date: 'April 2026',
      type: 'feature',
    ),
    UpdateItem(
      id: 'pus2',
      title: 'Manajemen Antrian v2',
      description:
          'Waktu tunggu yang berkurang dengan algoritma alur pasien yang ditingkatkan.',
      date: 'Maret 2026',
      type: 'improvement',
    ),
    UpdateItem(
      id: 'pus3',
      title: 'Jembatan Data SatuSehat',
      description:
          'Sinkronisasi data tanpa hambatan dengan platform kesehatan regional dan nasional.',
      date: 'Februari 2026',
      type: 'feature',
    ),
  ],
  'klinik': [
    UpdateItem(
      id: 'k1',
      title: 'Manajemen Klinik v1',
      description:
          'Kelola klinik Anda dengan mudah menggunakan dasbor baru kami.',
      date: 'April 2026',
      type: 'feature',
    ),
  ],
  'rumahsakit': [
    UpdateItem(
      id: 'rs1',
      title: 'Sistem RS Terintegrasi',
      description: 'Menghubungkan semua departemen dalam satu platform.',
      date: 'April 2026',
      type: 'feature',
    ),
  ],
  'ponkesdes': [
    UpdateItem(
      id: 'pk1',
      title: 'Layanan Desa Digital',
      description: 'Membawa kesehatan digital ke tingkat desa.',
      date: 'April 2026',
      type: 'feature',
    ),
  ],
  'posyandu': [
    UpdateItem(
      id: 'py1',
      title: 'Monitoring Tumbuh Kembang',
      description: 'Pantau tumbuh kembang anak secara digital.',
      date: 'April 2026',
      type: 'feature',
    ),
  ]
};

// --- DATA LISTS (ENGLISH) ---

const _updatesDataEn = {
  'mapotek': [
    UpdateItem(
      id: '1',
      title: 'Birth of New MAPOTECH',
      description:
          'Major transformation of MAPOTEK with repositioning of the name meaning to Medical Application Platform for Operational Technology and Connected Healthcare. Includes Pharmacy Management integration, cross-entity E-Prescription, and manual EMR submission to SatuSehat.',
      date: 'February 2026',
      type: 'feature',
    ),
    UpdateItem(
      id: '2',
      title: 'Web & Mobile Ecosystem',
      description:
          'Expansion of MAPOTEK to Web (Doctor) and Mobile (Patient) platforms with SatuSehat integration, queue booking, and medical history. A crucial step in expanding the reach of MAPOTEK\'s digital health services.',
      date: 'August 2025',
      type: 'feature',
    ),
    UpdateItem(
      id: '3',
      title: 'MAPOTEK Desktop Pro',
      description:
          'Major upgrade to the MAPOTEK Desktop application with thermal print integration, barcode scanning, loading optimization, and advanced Stock Card & Stock Opname management.',
      date: 'February 2025',
      type: 'improvement',
    ),
    UpdateItem(
      id: '4',
      title: 'MAPOTEK First Launch',
      description:
          'First launch of the MAPOTEK Desktop application — Management Application Patient Oriented Technology — specifically for private practices for patient management and basic examinations.',
      date: 'August 2024',
      type: 'feature',
    ),
  ],
  'pasien': [
    UpdateItem(
      id: 'p1',
      title: 'Monitoring & Reminder',
      description:
          'View registered pharmacies, access digital E-Prescriptions, and automated medication reminders from doctors.',
      date: 'February 2026',
      type: 'feature',
    ),
    UpdateItem(
      id: 'p2',
      title: 'Online Queue & History',
      description:
          'Book queues from home and monitor medical examination history directly from the mobile application.',
      date: 'August 2025',
      type: 'feature',
    ),
  ],
  'dokter': [
    UpdateItem(
      id: 'd1',
      title: 'E-Prescription & External Mgmt',
      description:
          'Electronic prescription feature connected to MAPOTECH Pharmacies and external patient input capability.',
      date: 'February 2026',
      type: 'feature',
    ),
    UpdateItem(
      id: 'd2',
      title: 'EMR & Advanced SatuSehat',
      description:
          'Detailed medication data submission and manual send feature to SatuSehat in case of synchronization issues.',
      date: 'February 2026',
      type: 'improvement',
    ),
    UpdateItem(
      id: 'd3',
      title: 'Web SatuSehat Integration',
      description:
          'Transition to the web platform with a SatuSehat Kemenkes standardized EMR system.',
      date: 'August 2025',
      type: 'feature',
    ),
    UpdateItem(
      id: 'd4',
      title: 'Desktop Inventory System',
      description:
          'Advanced stock management with Stock Cards and Stock Opname using Java desktop application.',
      date: 'February 2025',
      type: 'improvement',
    ),
  ],
  'apotek': [
    UpdateItem(
      id: 'a1',
      title: 'Pharmacy Network Hub',
      description:
          'Modern pharmacy management integration supporting E-Prescription redemption from MAPOTECH doctors.',
      date: 'February 2026',
      type: 'feature',
    ),
  ],
  'puskesmas': [
    UpdateItem(
      id: 'pus1',
      title: 'Public Health Analytics',
      description:
          'Monitor community health trends with our new aggregated data dashboard.',
      date: 'April 2026',
      type: 'feature',
    ),
    UpdateItem(
      id: 'pus2',
      title: 'Queue Management v2',
      description:
          'Reduced wait times with improved patient flow algorithms.',
      date: 'March 2026',
      type: 'improvement',
    ),
    UpdateItem(
      id: 'pus3',
      title: 'SatuSehat Data Bridge',
      description:
          'Seamless data synchronization with regional and national health platforms.',
      date: 'February 2026',
      type: 'feature',
    ),
  ],
  'klinik': [
    UpdateItem(
      id: 'k1',
      title: 'Clinic Management v1',
      description:
          'Manage your clinic easily with our new dashboard.',
      date: 'April 2026',
      type: 'feature',
    ),
  ],
  'rumahsakit': [
    UpdateItem(
      id: 'rs1',
      title: 'Integrated Hospital System',
      description: 'Connect all departments in one platform.',
      date: 'April 2026',
      type: 'feature',
    ),
  ],
  'ponkesdes': [
    UpdateItem(
      id: 'pk1',
      title: 'Digital Village Services',
      description: 'Bringing digital health to the village level.',
      date: 'April 2026',
      type: 'feature',
    ),
  ],
  'posyandu': [
    UpdateItem(
      id: 'py1',
      title: 'Growth Monitoring',
      description: 'Monitor child growth digitally.',
      date: 'April 2026',
      type: 'feature',
    ),
  ]
};

extension StringTranslateExtension on String {
  String tr(LandingPageState state) {
    final lang = state.language;
    if (_translations.containsKey(lang) &&
        _translations[lang]!.containsKey(this)) {
      return _translations[lang]![this]!;
    }
    return this;
  }
}

