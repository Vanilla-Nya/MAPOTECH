import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mapotech/features/landing/landing_page_data.dart';

/// Provider for active language ('id' | 'en').
/// Uses `select` so widgets watching this ONLY rebuild when `language` changes,
/// ensuring zero lag and maximum performance.
final appLanguageProvider = Provider<String>((ref) {
  return ref.watch(landingPageProvider.select((s) => s.language));
});

/// Boolean provider indicating whether active language is English.
final isEnglishProvider = Provider<bool>((ref) {
  return ref.watch(landingPageProvider.select((s) => s.language == 'en'));
});

/// Extension on [WidgetRef] for convenient, fast, lag-free translation lookups in widgets.
extension AppTranslationRefExtension on WidgetRef {
  /// Returns [en] if current language is 'en', otherwise [id].
  /// Reacts smoothly to language updates without re-evaluating unrelated state.
  String tr({required String id, required String en}) {
    final isEn = watch(isEnglishProvider);
    return isEn ? en : id;
  }

  /// Whether English is currently active.
  bool get isEn => watch(isEnglishProvider);

  /// Current language code ('id' or 'en').
  String get lang => watch(appLanguageProvider);
}

/// Central Localization and Translation Helper for MAPOTECH.
class AppTranslations {
  AppTranslations._();

  /// Quick helper function returning [en] if [lang] == 'en', else [id].
  static String tr(String lang, {required String id, required String en}) {
    return lang.toLowerCase() == 'en' ? en : id;
  }

  /// Helper returning [en] if [isEn] is true, else [id].
  static String trBool(bool isEn, {required String id, required String en}) {
    return isEn ? en : id;
  }

  // ── Date Formatting ────────────────────────────────────────────────────────

  static const List<String> _daysId = [
    '',
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
    'Minggu'
  ];

  static const List<String> _daysEn = [
    '',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday'
  ];

  static const List<String> _monthsId = [
    '',
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
    'Desember'
  ];

  static const List<String> _monthsEn = [
    '',
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December'
  ];

  static const List<String> _shortDaysId = [
    'Min',
    'Sen',
    'Sel',
    'Rab',
    'Kam',
    'Jum',
    'Sab'
  ];

  static const List<String> _shortDaysEn = [
    'Sun',
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat'
  ];

  /// Format DateTime into localized string.
  /// Example (ID): "Selasa, 26 Mei 2026"
  /// Example (EN): "Tuesday, 26 May 2026"
  static String formatDate(
    DateTime? date, {
    String lang = 'id',
    bool includeDay = true,
  }) {
    if (date == null) return '';
    final isEn = lang.toLowerCase() == 'en';
    final dayName = isEn ? _daysEn[date.weekday] : _daysId[date.weekday];
    final monthName = isEn ? _monthsEn[date.month] : _monthsId[date.month];

    if (includeDay) {
      return '$dayName, ${date.day} $monthName ${date.year}';
    }
    return '${date.day} $monthName ${date.year}';
  }

  /// Short weekday name: Min/Sun, Sen/Mon, etc. (0 = Sunday, 1 = Monday ...)
  static String getShortWeekday(int weekdayIndex, {String lang = 'id'}) {
    final idx = weekdayIndex % 7;
    return lang.toLowerCase() == 'en' ? _shortDaysEn[idx] : _shortDaysId[idx];
  }

  // ── Common UI Dictionaries ─────────────────────────────────────────────────

  static String commonSave(bool isEn) => isEn ? 'Save' : 'Simpan';
  static String commonCancel(bool isEn) => isEn ? 'Cancel' : 'Batal';
  static String commonDelete(bool isEn) => isEn ? 'Delete' : 'Hapus';
  static String commonEdit(bool isEn) => isEn ? 'Edit' : 'Ubah';
  static String commonAdd(bool isEn) => isEn ? 'Add' : 'Tambah';
  static String commonSearch(bool isEn) => isEn ? 'Search' : 'Cari';
  static String commonClose(bool isEn) => isEn ? 'Close' : 'Tutup';
  static String commonBack(bool isEn) => isEn ? 'Back' : 'Kembali';
  static String commonNext(bool isEn) => isEn ? 'Next' : 'Lanjut';
  static String commonConfirm(bool isEn) => isEn ? 'Confirm' : 'Konfirmasi';
  static String commonRefresh(bool isEn) => isEn ? 'Refresh' : 'Segarkan';
  static String commonAll(bool isEn) => isEn ? 'All' : 'Semua';
  static String commonStatus(bool isEn) => isEn ? 'Status' : 'Status';
  static String commonAction(bool isEn) => isEn ? 'Action' : 'Aksi';
  static String commonDetail(bool isEn) => isEn ? 'Detail' : 'Detail';
  static String commonSuccess(bool isEn) => isEn ? 'Success' : 'Berhasil';
  static String commonError(bool isEn) => isEn ? 'Error' : 'Terjadi Kesalahan';
  static String commonWarning(bool isEn) => isEn ? 'Warning' : 'Peringatan';
  static String commonLoading(bool isEn) => isEn ? 'Loading...' : 'Memuat...';
  static String commonNoData(bool isEn) => isEn ? 'No data available' : 'Belum ada data';
  static String commonSettings(bool isEn) => isEn ? 'Settings' : 'Pengaturan';
  static String commonLogout(bool isEn) => isEn ? 'Logout' : 'Keluar';

  // ── Navigation & Role Labels ───────────────────────────────────────────────

  static String roleLabel(String? role, {required bool isEn, String? profession}) {
    switch (role) {
      case 'pasien':
        return isEn ? 'PATIENT' : 'PASIEN';
      case 'dokter':
        final prof = profession?.toLowerCase() ?? '';
        if (prof.contains('midwife') || prof.contains('bidan')) {
          return isEn ? 'MIDWIFE' : 'BIDAN';
        } else if (prof.contains('nurse') || prof.contains('perawat')) {
          return isEn ? 'NURSE' : 'PERAWAT';
        }
        return isEn ? 'DOCTOR' : 'DOKTER';
      case 'apotek':
        return isEn ? 'PHARMACY' : 'APOTEK';
      case 'puskesmas':
        return isEn ? 'PUBLIC HEALTH CENTER' : 'PUSKESMAS';
      case 'ponkesdes':
        return isEn ? 'VILLAGE HEALTH POST' : 'PONKESDES';
      default:
        return (role ?? 'USER').toUpperCase();
    }
  }

  // ── Drawer & Search Texts ──────────────────────────────────────────────────

  static String searchDrawerHint(bool isEn) =>
      isEn ? 'What are you looking for today?' : 'Apa yang ingin Anda cari hari ini?';

  static String puskesmasClusterFilterHeader(bool isEn) =>
      isEn ? 'PUSKESMAS CLUSTER LEVEL FILTER' : 'FILTER TINGKAT CLUSTER PUSKESMAS';
}
