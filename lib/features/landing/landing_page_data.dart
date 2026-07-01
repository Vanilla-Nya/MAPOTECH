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
  }) {
    state = state.copyWith(
      isLoggedIn: true,
      loggedInRole: role,
      loggedInName: user?['name'] ?? (role == 'pasien' ? 'Alvin' : (role == 'dokter' ? 'dr. Agoes Soetanto' : 'CyrenElysia~♪')),
      loggedInUser: user,
      blurProfileEffectEnabled: blurProfileEffectEnabled ?? state.blurProfileEffectEnabled,
      defaultServiceFee: defaultServiceFee ?? state.defaultServiceFee,
      satusehatAutoSync: satusehatAutoSync ?? state.satusehatAutoSync,
    );
  }

  void logout() {
    state = state.copyWith(isLoggedIn: false, loggedInRole: null, loggedInName: null, loggedInUser: null, drawerSize: 1);
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

  void setLanguage(String lang) {
    state = state.copyWith(language: lang);
  }

  void toggleLanguage() {
    state = state.copyWith(language: state.language == 'id' ? 'en' : 'id');
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
          {'label': isId ? 'Pasyandu' : 'Family Health', 'tab': 'posyandu'},
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
        'Medical Application Platform for Operation Technology and Connected Health Care. Ekosistem kesehatan digital modern yang menghubungkan Dokter, Pasien, Apotek, dan Fasilitas Kesehatan dalam satu platform terintegrasi SatuSehat Kemenkes.',
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
        'Medical Application Platform for Operation Technology and Connected Health Care. A modern digital health ecosystem connecting Doctors, Patients, Pharmacies, and Healthcare Facilities into a single SatuSehat Kemenkes integrated platform.',
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
  }
};

// --- DATA LISTS (INDONESIAN) ---

const _updatesDataId = {
  'mapotek': [
    UpdateItem(
      id: '1',
      title: 'Lahirnya MAPOTECH Baru',
      description:
          'Transformasi besar MAPOTEK dengan reposisi makna nama menjadi Medical Application Platform for Operation Technology and Connected Health Care. Disertai integrasi Manajemen Apotek, fitur E-Resep lintas entitas, dan pengiriman RME manual ke SatuSehat.',
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
          'Major transformation of MAPOTEK with repositioning of the name meaning to Medical Application Platform for Operation Technology and Connected Health Care. Includes Pharmacy Management integration, cross-entity E-Prescription, and manual EMR submission to SatuSehat.',
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
