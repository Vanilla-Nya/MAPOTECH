import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapotech/features/landing/landing_page_data.dart';
import 'package:mapotech/features/puskesmas/dashboard/backend/puskesmas_satusehat_bookkeeping_service.dart';
import 'package:mapotech/features/puskesmas/dashboard/frontend/puskesmas_pantauan_ibu_hamil.dart';
import 'package:mapotech/shared/widgets/ui.dart';

/// Halaman Pembukuan & Pengiriman SATUSEHAT khusus portal Puskesmas (CL-1).
/// Terpisah dari Pembukuan Praktik Mandiri (`DokterPembukuan`), menggunakan data
/// kunjungan dan kredensial SATUSEHAT milik Puskesmas sendiri.
class PuskesmasPembukuan extends ConsumerStatefulWidget {
  const PuskesmasPembukuan({super.key});

  @override
  ConsumerState<PuskesmasPembukuan> createState() => _PuskesmasPembukuanState();
}

class _PuskesmasPembukuanState extends ConsumerState<PuskesmasPembukuan> {
  final PuskesmasSatuSehatBookkeepingService _service =
      PuskesmasSatuSehatBookkeepingService();

  // Default langsung ke tab Pengiriman SATUSEHAT; tab Keuangan menampilkan Coming Soon
  String _activeTab = 'satusehat'; // 'satusehat' | 'overview'

  bool _isLoading = true;
  bool _isSavingBulk = false;
  bool _isSyncingIndividual = false;
  bool _isRegisteringPatient = false;
  String _individualSyncStep = 'Connecting';
  double _syncProgressValue = 0.15;

  PuskesmasSatuSehatConfig? _config;
  List<PuskesmasEncounterRecord> _encounters = [];

  // Filter, search, & pagination state
  String _searchQuery = '';
  String _statusFilter = 'All'; // 'All' | 'Sent' | 'Unsent' | 'Failed'
  String _moduleFilter = 'all'; // 'all' | 'momicare' | 'vitascale' | 'umum'
  DateTimeRange? _selectedDateRange;
  int _currentPage = 1;
  int _itemsPerPage = 10;

  // Bulk sync state
  bool _isBulkSyncMode = false;
  final Set<String> _selectedEncounterIds = {};

  // Active detail modal record
  PuskesmasEncounterRecord? _selectedRecord;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (mounted) setState(() => _isLoading = true);

    try {
      final appState = ref.read(landingPageProvider);
      final facilityId = appState.activePuskesmasId ?? 'PUSKESMAS-001';
      final facilityName = appState.loggedInName ?? 'Puskesmas';
      final momicarePatients = ref.read(ibuHamilListProvider);

      final cfg = await _service.loadConfig(
        facilityId: facilityId,
        fallbackFacilityName: facilityName,
      );

      final records = await _service.loadEncounters(
        facilityId: facilityId,
        facilityName: cfg.facilityName,
        momicarePatients: momicarePatients,
      );

      if (!mounted) return;
      setState(() {
        _config = cfg;
        _encounters = records;
        if (_selectedRecord != null) {
          final updated = records.where((r) => r.id == _selectedRecord!.id);
          _selectedRecord = updated.isNotEmpty ? updated.first : null;
        }
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('[PuskesmasPembukuan] Error loading data: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
      final isEn = ref.read(isEnglishProvider);
      CustomSnackbar.error(
        context,
        isEn
            ? 'Failed to load Puskesmas SATUSEHAT records: $e'
            : 'Gagal memuat data rekam medis SATUSEHAT Puskesmas: $e',
      );
    }
  }

  Future<void> _registerPatient(PuskesmasEncounterRecord record) async {
    final cfg = _config;
    if (cfg == null) return;
    final isEn = ref.read(isEnglishProvider);

    setState(() => _isRegisteringPatient = true);
    try {
      final res = await _service.registerPatientToSatuSehat(
        record: record,
        config: cfg,
      );
      final ihsId = res['satusehat_id']?.toString() ?? '';
      final isLive = res['is_live_verified'] == true;

      await _loadData();
      if (!mounted) return;
      setState(() {
        _isRegisteringPatient = false;
      });

      CustomSnackbar.success(
        context,
        isLive
            ? (isEn
                  ? 'Patient verified in SATUSEHAT with IHS ID: $ihsId'
                  : 'Pasien berhasil diverifikasi di SATUSEHAT dengan IHS ID: $ihsId')
            : (isEn
                  ? 'Sandbox IHS ID prepared for patient: $ihsId'
                  : 'IHS ID Sandbox pasien berhasil disiapkan: $ihsId'),
        title: isEn ? 'SATUSEHAT Patient Registered' : 'Pasien Terdaftar SATUSEHAT',
      );
    } on PuskesmasSatuSehatConfigException catch (e) {
      if (!mounted) return;
      setState(() => _isRegisteringPatient = false);
      CustomSnackbar.warning(
        context,
        e.message,
        title: isEn ? 'Incomplete SATUSEHAT Config' : 'Konfigurasi Belum Lengkap',
      );
      _openConfigDialog();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isRegisteringPatient = false);
      CustomSnackbar.error(
        context,
        isEn
            ? 'Registration failed: ${e.toString().replaceAll('Exception: ', '')}'
            : 'Registrasi gagal: ${e.toString().replaceAll('Exception: ', '')}',
      );
    }
  }

  Future<void> _syncSingleRecord(PuskesmasEncounterRecord record) async {
    final cfg = _config;
    if (cfg == null) return;
    final isEn = ref.read(isEnglishProvider);
    final staffName =
        ref.read(landingPageProvider).loggedInName ?? cfg.facilityName;

    setState(() {
      _selectedRecord = record;
      _isSyncingIndividual = true;
      _individualSyncStep = 'Connecting';
      _syncProgressValue = 0.25;
    });

    try {
      final updated = await _service.syncEncounterToSatuSehat(
        record: record,
        config: cfg,
        staffName: staffName,
        onStepChanged: (step) {
          if (!mounted) return;
          double p = 0.25;
          if (step == 'SendingEMR') p = 0.55;
          if (step == 'SendingObservations' ||
              step == 'GeneratingPrescription') {
            p = 0.80;
          }
          if (step == 'Success') p = 1.0;
          setState(() {
            _individualSyncStep = step;
            _syncProgressValue = p;
          });
        },
      );

      await _loadData();
      if (!mounted) return;
      setState(() {
        _isSyncingIndividual = false;
        _selectedRecord = updated;
      });

      CustomSnackbar.success(
        context,
        isEn
            ? '${record.patientName}\'s record has been synced to SATUSEHAT (Encounter: ${updated.satusehatEncounterId ?? '-'}).'
            : 'Rekam medis ${record.patientName} berhasil dikirim ke SATUSEHAT (Encounter: ${updated.satusehatEncounterId ?? '-'}).',
        title: isEn ? 'SATUSEHAT Sync Success' : 'Sinkronisasi Berhasil',
      );
    } on PuskesmasSatuSehatConfigException catch (e) {
      if (!mounted) return;
      setState(() => _isSyncingIndividual = false);
      CustomSnackbar.warning(
        context,
        e.message,
        title: isEn ? 'SATUSEHAT Configuration Required' : 'Konfigurasi SATUSEHAT Diperlukan',
      );
      _openConfigDialog();
    } catch (e) {
      await _loadData();
      if (!mounted) return;
      setState(() => _isSyncingIndividual = false);
      CustomSnackbar.error(
        context,
        isEn
            ? 'Sync failed: ${e.toString().replaceAll('Exception: ', '')}'
            : 'Sinkronisasi gagal: ${e.toString().replaceAll('Exception: ', '')}',
      );
    }
  }

  Future<void> _triggerBulkSync() async {
    if (_selectedEncounterIds.isEmpty) return;
    final cfg = _config;
    if (cfg == null) return;

    final isEn = ref.read(isEnglishProvider);
    final staffName =
        ref.read(landingPageProvider).loggedInName ?? cfg.facilityName;

    final targets = _encounters
        .where((e) => _selectedEncounterIds.contains(e.id))
        .toList();
    if (targets.isEmpty) return;

    final confirmed = await CustomConfirmDialog.show(
      context: context,
      title: isEn ? 'Confirm Bulk SATUSEHAT Sync' : 'Konfirmasi Sinkronisasi Massal',
      message: isEn
          ? 'Send ${targets.length} selected Puskesmas patient encounter(s) to Kemenkes SATUSEHAT?'
          : 'Kirim ${targets.length} data kunjungan pasien Puskesmas terpilih ke SATUSEHAT Kemenkes?',
      confirmText: isEn ? 'Sync Now' : 'Kirim Sekarang',
      cancelText: AppTranslations.commonCancel(isEn),
      icon: Icons.cloud_upload_rounded,
    );

    if (!confirmed || !mounted) return;

    setState(() => _isSavingBulk = true);
    try {
      final result = await _service.bulkSyncEncounters(
        targets: targets,
        config: cfg,
        staffName: staffName,
      );

      final successCount = result['success_count'] as int? ?? 0;
      final failedCount = result['failed_count'] as int? ?? 0;
      final lastErr = result['last_error']?.toString() ?? '';

      await _loadData();
      if (!mounted) return;
      setState(() {
        _isSavingBulk = false;
        _isBulkSyncMode = false;
        _selectedEncounterIds.clear();
      });

      if (failedCount == 0) {
        CustomSnackbar.success(
          context,
          isEn
              ? 'Successfully synced $successCount record(s) to SATUSEHAT.'
              : 'Berhasil mensinkronkan $successCount data kunjungan ke SATUSEHAT.',
        );
      } else {
        CustomSnackbar.warning(
          context,
          isEn
              ? 'Completed with warnings: $successCount succeeded, $failedCount failed. Last error: $lastErr'
              : 'Selesai dengan catatan: $successCount berhasil, $failedCount gagal. Error terakhir: $lastErr',
        );
      }
    } on PuskesmasSatuSehatConfigException catch (e) {
      if (!mounted) return;
      setState(() => _isSavingBulk = false);
      CustomSnackbar.warning(context, e.message);
      _openConfigDialog();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSavingBulk = false);
      CustomSnackbar.error(
        context,
        isEn
            ? 'Bulk sync failed: ${e.toString().replaceAll('Exception: ', '')}'
            : 'Sinkronisasi massal gagal: ${e.toString().replaceAll('Exception: ', '')}',
      );
    }
  }

  Future<void> _openConfigDialog() async {
    final cfg = _config;
    if (cfg == null) return;

    final orgCtrl = TextEditingController(text: cfg.organizationId);
    final clientCtrl = TextEditingController(text: cfg.clientId);
    final secretCtrl = TextEditingController(text: cfg.clientSecret);
    final locCtrl = TextEditingController(text: cfg.locationId);
    final pracCtrl = TextEditingController(text: cfg.practitionerId);
    String selectedEnv = cfg.isStaging ? 'staging' : 'production';
    bool autoSync = cfg.autoSync;
    bool saving = false;

    await CustomDialog.show(
      context: context,
      maxWidth: 540,
      icon: Icons.vpn_key_rounded,
      title: ref.tr(
        id: 'Konfigurasi SATUSEHAT Puskesmas',
        en: 'Puskesmas SATUSEHAT Configuration',
      ),
      content: StatefulBuilder(
        builder: (ctx, setModalState) {
          final isEn = ref.read(isEnglishProvider);
          final notifier = ref.read(landingPageProvider.notifier);
          final textColor = notifier.getTextColor();
          final subtitleColor = notifier.getBodyTextColor();
          final borderColor = notifier.getBorderColor();
          final primaryColor = notifier.getPrimaryColor();

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                isEn
                    ? 'Dedicated SATUSEHAT credentials for ${cfg.facilityName}. Saved directly to your Puskesmas profile.'
                    : 'Kredensial SATUSEHAT mandiri milik ${cfg.facilityName}. Tersimpan langsung pada profil Puskesmas Anda.',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: subtitleColor,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              CustomDropdown<String>(
                label: isEn ? 'Environment' : 'Lingkungan Server',
                value: selectedEnv,
                items: [
                  CustomDropdownItem(
                    value: 'production',
                    label: isEn ? 'Production (Live Kemenkes)' : 'Production (Live Kemenkes)',
                  ),
                  CustomDropdownItem(
                    value: 'staging',
                    label: isEn ? 'Staging / Sandbox' : 'Staging / Uji Coba',
                  ),
                ],
                onChanged: (val) {
                  if (val != null) setModalState(() => selectedEnv = val);
                },
              ),
              const SizedBox(height: 12),
              CustomTextField(
                controller: orgCtrl,
                label: 'Organization ID *',
                hintText: 'e.g. 100062510',
                prefixIcon: Icons.apartment_rounded,
              ),
              const SizedBox(height: 12),
              CustomTextField(
                controller: clientCtrl,
                label: 'Client ID *',
                hintText: isEn ? 'Enter SATUSEHAT client_id' : 'Masukkan client_id SATUSEHAT',
                prefixIcon: Icons.badge_outlined,
              ),
              const SizedBox(height: 12),
              CustomTextField(
                controller: secretCtrl,
                label: 'Client Secret *',
                hintText: isEn ? 'Enter SATUSEHAT client_secret' : 'Masukkan client_secret SATUSEHAT',
                isPassword: true,
                prefixIcon: Icons.lock_outline_rounded,
              ),
              const SizedBox(height: 12),
              CustomTextField(
                controller: locCtrl,
                label: isEn ? 'Location ID (Puskesmas Poli) *' : 'Location ID (Lokasi Faskes) *',
                hintText: 'e.g. b017aa54-f1df-4ec2-9529-81788148b1d9',
                prefixIcon: Icons.location_on_outlined,
              ),
              const SizedBox(height: 12),
              CustomTextField(
                controller: pracCtrl,
                label: isEn
                    ? 'Practitioner ID (IHS Nakes) *'
                    : 'Practitioner ID (IHS Nakes Penanggung Jawab) *',
                hintText: 'e.g. 10009880728',
                prefixIcon: Icons.medical_services_outlined,
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeThumbColor: primaryColor,
                  title: Text(
                    isEn ? 'Auto-Sync Mode Indicator' : 'Mode Sinkronisasi Otomatis',
                    style: GoogleFonts.outfit(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                  subtitle: Text(
                    isEn
                        ? 'Mark Puskesmas SATUSEHAT gateway as System Online'
                        : 'Tandai gateway SATUSEHAT Puskesmas berstatus System Online',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      color: subtitleColor,
                    ),
                  ),
                  value: autoSync,
                  onChanged: (v) => setModalState(() => autoSync = v),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  CustomButton(
                    text: AppTranslations.commonCancel(isEn),
                    isSecondary: true,
                    height: 40,
                    onPressed: saving ? null : () => Navigator.of(ctx).pop(),
                  ),
                  const SizedBox(width: 10),
                  CustomButton(
                    text: saving
                        ? (isEn ? 'Saving...' : 'Menyimpan...')
                        : AppTranslations.commonSave(isEn),
                    icon: Icons.save_rounded,
                    height: 40,
                    primaryColor: primaryColor,
                    onPressed: saving
                        ? null
                        : () async {
                            setModalState(() => saving = true);
                            final nextCfg = cfg.copyWith(
                              organizationId: orgCtrl.text.trim(),
                              clientId: clientCtrl.text.trim(),
                              clientSecret: secretCtrl.text.trim(),
                              locationId: locCtrl.text.trim(),
                              practitionerId: pracCtrl.text.trim(),
                              env: selectedEnv,
                              autoSync: autoSync,
                            );
                            try {
                              await _service.saveConfig(nextCfg);
                              ref
                                  .read(landingPageProvider.notifier)
                                  .setSatusehatAutoSync(autoSync);
                              if (ctx.mounted) Navigator.of(ctx).pop();
                              await _loadData();
                              if (mounted) {
                                CustomSnackbar.success(
                                  context,
                                  isEn
                                      ? 'Puskesmas SATUSEHAT settings saved.'
                                      : 'Konfigurasi SATUSEHAT Puskesmas berhasil disimpan.',
                                );
                              }
                            } catch (e) {
                              setModalState(() => saving = false);
                              if (mounted) {
                                CustomSnackbar.error(
                                  context,
                                  isEn
                                      ? 'Failed to save config: $e'
                                      : 'Gagal menyimpan konfigurasi: $e',
                                );
                              }
                            }
                          },
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    orgCtrl.dispose();
    clientCtrl.dispose();
    secretCtrl.dispose();
    locCtrl.dispose();
    pracCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(landingPageProvider);
    final isEn = ref.watch(isEnglishProvider);
    final notifier = ref.read(landingPageProvider.notifier);

    // Dengarkan perubahan live dari daftar ibu hamil (MomiCare) agar kunjungan baru langsung terlihat
    ref.listen<List<IbuHamilModel>>(ibuHamilListProvider, (prev, next) {
      if (!_isLoading && mounted) {
        _loadData();
      }
    });

    final isDark = state.appearance == 'dark';
    final isRev = state.appearance == 'rev';
    final cardBg = notifier.getCardColor();
    final textColor = notifier.getTextColor();
    final subtitleColor = notifier.getBodyTextColor();
    final borderColor = notifier.getBorderColor();
    final inputBg = isDark
        ? const Color(0xFF1E1E22)
        : (isRev ? const Color(0xFFF3E8FF).withValues(alpha: 0.45) : const Color(0xFFF6F8FA));

    final primaryAccent = notifier.getPrimaryColor();
    final activeGreen = isRev
        ? const Color(0xFFB577F2)
        : (isDark ? const Color(0xFF48C9B0) : primaryAccent);
    final bpjsColor = isRev ? const Color(0xFF3B82F6) : Colors.blueAccent;
    final warningColor = isRev ? const Color(0xFFEC4899) : Colors.orangeAccent;
    final errorColor = isRev ? const Color(0xFFEC4899) : Colors.redAccent;
    final isMobile = MediaQuery.of(context).size.width < 768;

    // KPI computations
    final totalEncounters = _encounters.length;
    final totalUniquePatients = _encounters
        .map((e) => e.patientNik.isNotEmpty && e.patientNik != '-' ? e.patientNik : e.patientName)
        .toSet()
        .length;
    final sentCount =
        _encounters.where((e) => e.syncStatus == 'success').length;
    final unsentCount =
        _encounters.where((e) => e.syncStatus == 'unsent').length;
    final failedCount =
        _encounters.where((e) => e.syncStatus == 'failed').length;
    final bpjsPatientCount = _encounters
        .where((e) => e.patientType == 'BPJS')
        .map((e) => e.patientNik.isNotEmpty && e.patientNik != '-' ? e.patientNik : e.patientName)
        .toSet()
        .length;
    final generalPatientCount =
        (totalUniquePatients - bpjsPatientCount).clamp(0, totalUniquePatients);

    final syncRatePct = totalEncounters > 0
        ? ((sentCount / totalEncounters) * 100).round()
        : 0;

    final isAutoSync = _config?.autoSync ?? state.satusehatAutoSync;
    final isConfigured = _config?.isComplete ?? false;

    return CustomLazyLoader(
      isLoading: _isLoading,
      loadingText: isEn
          ? 'Loading Puskesmas Bookkeeping & SATUSEHAT...'
          : 'Memuat Pembukuan & Sinkronisasi SATUSEHAT Puskesmas...',
      loadingSubtext: isEn
          ? 'Aggregating MomiCare ANC, VitaScale, and Puskesmas records...'
          : 'Menghimpun data layanan MomiCare, VitaScale, dan rekam medis Puskesmas...',
      skeleton: const SkeletonPembukuan(),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ==================== HEADER BANNER ====================
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                margin: const EdgeInsets.only(bottom: 20),
                child: Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  alignment: WrapAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: activeGreen.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.account_balance_wallet_rounded,
                            color: activeGreen,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  isEn
                                      ? 'Puskesmas Bookkeeping'
                                      : 'Pembukuan Puskesmas',
                                  style: GoogleFonts.outfit(
                                    fontSize: isMobile ? 18 : 21,
                                    fontWeight: FontWeight.w900,
                                    color: textColor,
                                  ),
                                ),
                                StatusBadge(
                                  label: isAutoSync
                                      ? 'SYSTEM ONLINE'
                                      : (isEn
                                            ? 'MANUAL SYNC'
                                            : 'SINKRONISASI MANUAL'),
                                  color: isAutoSync ? activeGreen : warningColor,
                                  fontSize: 9,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 9,
                                    vertical: 3,
                                  ),
                                ),
                                InkWell(
                                  onTap: _openConfigDialog,
                                  borderRadius: BorderRadius.circular(100),
                                  child: StatusBadge(
                                    label: isConfigured
                                        ? (isEn
                                              ? 'PUSKESMAS CREDENTIALS READY'
                                              : 'KREDENSIAL PUSKESMAS SIAP')
                                        : (isEn
                                              ? 'SETUP SATUSEHAT API'
                                              : 'ATUR API SATUSEHAT'),
                                    color: isConfigured
                                        ? bpjsColor
                                        : warningColor,
                                    icon: isConfigured
                                        ? Icons.verified_user_rounded
                                        : Icons.settings_rounded,
                                    fontSize: 9,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 9,
                                      vertical: 3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: isMobile ? 310 : 540,
                              ),
                              child: Text(
                                isEn
                                    ? 'Dedicated Puskesmas SATUSEHAT FHIR R4 record dispatch & upcoming financial ledger.'
                                    : 'Pengiriman rekam medis Puskesmas ke SATUSEHAT Kemenkes & pembukuan keuangan Puskesmas.',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  color: subtitleColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        CustomButton(
                          text: AppTranslations.commonRefresh(isEn),
                          icon: Icons.refresh_rounded,
                          isSecondary: true,
                          height: 40,
                          textColor: textColor,
                          borderColor: borderColor,
                          onPressed: _loadData,
                        ),
                        CustomButton(
                          text: isEn ? 'SATUSEHAT Config' : 'Konfigurasi SATUSEHAT',
                          icon: Icons.vpn_key_rounded,
                          height: 40,
                          primaryColor: activeGreen,
                          onPressed: _openConfigDialog,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ==================== TOP 4 METRIC CARDS ====================
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: isMobile ? 2 : 4,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: isMobile ? 1.35 : 1.75,
                children: [
                  _buildKpiCard(
                    icon: Icons.people_alt_rounded,
                    label: isEn ? 'TOTAL PATIENTS' : 'TOTAL PASIEN',
                    value: totalUniquePatients.toString(),
                    accentColor: textColor,
                    cardBg: cardBg,
                    borderColor: borderColor,
                    subtitleColor: subtitleColor,
                    subtitle: isEn ? 'Puskesmas Registered' : 'Sasaran Puskesmas',
                    chips: [
                      'BPJS $bpjsPatientCount',
                      '${isEn ? 'General' : 'Umum'} $generalPatientCount',
                    ],
                    bpjsColor: bpjsColor,
                    activeGreen: activeGreen,
                  ),
                  _buildKpiCard(
                    icon: Icons.cloud_done_rounded,
                    label: isEn ? 'SENT TO SATUSEHAT' : 'TERKIRIM SATUSEHAT',
                    value: sentCount.toString(),
                    accentColor: activeGreen,
                    cardBg: cardBg,
                    borderColor: borderColor,
                    subtitleColor: subtitleColor,
                    subtitle: isEn
                        ? '$syncRatePct% sync completion'
                        : '$syncRatePct% rasio terkirim',
                  ),
                  _buildKpiCard(
                    icon: Icons.schedule_send_rounded,
                    label: isEn ? 'UNSENT RECORDS' : 'BELUM TERKIRIM',
                    value: unsentCount.toString(),
                    accentColor: warningColor,
                    cardBg: cardBg,
                    borderColor: borderColor,
                    subtitleColor: subtitleColor,
                    subtitle: isEn
                        ? 'Ready for FHIR R4 sync'
                        : 'Siap dikirim ke SATUSEHAT',
                  ),
                  _buildKpiCard(
                    icon: Icons.error_outline_rounded,
                    label: isEn ? 'SYNC FAILED' : 'GAGAL SINKRONISASI',
                    value: failedCount.toString(),
                    accentColor: errorColor,
                    cardBg: cardBg,
                    borderColor: borderColor,
                    subtitleColor: subtitleColor,
                    subtitle: isEn
                        ? 'Requires attention / retry'
                        : 'Perlu pengecekan & kirim ulang',
                  ),
                ],
              ),

              const SizedBox(height: 22),

              // ==================== 2 TAB TOGGLES ====================
              Wrap(
                spacing: 12,
                runSpacing: 10,
                children: [
                  _buildTabButton(
                    tabId: 'satusehat',
                    title: isEn
                        ? 'Patient List & SATUSEHAT'
                        : 'Daftar Pasien & SATUSEHAT',
                    icon: Icons.cloud_sync_rounded,
                    activeColor: activeGreen,
                    cardBg: cardBg,
                    borderColor: borderColor,
                    textColor: textColor,
                  ),
                  _buildTabButton(
                    tabId: 'overview',
                    title: isEn
                        ? 'Financial Bookkeeping (Coming Soon)'
                        : 'Pembukuan Keuangan (Segera Hadir)',
                    icon: Icons.analytics_outlined,
                    activeColor: activeGreen,
                    cardBg: cardBg,
                    borderColor: borderColor,
                    textColor: textColor,
                    trailingBadge: isEn ? 'SOON' : 'SEGERA',
                    trailingColor: warningColor,
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // ==================== TAB CONTENT ====================
              if (_activeTab == 'satusehat')
                _buildSatuSehatTab(
                  state: state,
                  isEn: isEn,
                  isDark: isDark,
                  isMobile: isMobile,
                  cardBg: cardBg,
                  borderColor: borderColor,
                  inputBg: inputBg,
                  textColor: textColor,
                  subtitleColor: subtitleColor,
                  activeGreen: activeGreen,
                  bpjsColor: bpjsColor,
                  warningColor: warningColor,
                  errorColor: errorColor,
                )
              else
                _buildFinancialComingSoonTab(
                  isEn: isEn,
                  cardBg: cardBg,
                  borderColor: borderColor,
                  textColor: textColor,
                  subtitleColor: subtitleColor,
                  activeGreen: activeGreen,
                ),
            ],
          ),

          // ==================== DETAIL & SYNC MODAL ====================
          ViewportOverlay(
            show: _selectedRecord != null,
            builder: (context) => _buildPatientSyncModal(
              state: state,
              isEn: isEn,
              isDark: isDark,
              cardBg: cardBg,
              textColor: textColor,
              subtitleColor: subtitleColor,
              borderColor: borderColor,
              inputBg: inputBg,
              activeGreen: activeGreen,
              bpjsColor: bpjsColor,
              warningColor: warningColor,
              errorColor: errorColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard({
    required IconData icon,
    required String label,
    required String value,
    required Color accentColor,
    required Color cardBg,
    required Color borderColor,
    required Color subtitleColor,
    required String subtitle,
    List<String>? chips,
    Color? bpjsColor,
    Color? activeGreen,
  }) {
    return CustomCard(
      color: cardBg,
      borderColor: borderColor,
      borderRadius: 20,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 14, color: accentColor),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                    color: subtitleColor,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: accentColor,
            ),
          ),
          const SizedBox(height: 4),
          if (chips != null && chips.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: chips.map((c) {
                final isBpjs = c.toUpperCase().startsWith('BPJS');
                final col = isBpjs
                    ? (bpjsColor ?? Colors.blueAccent)
                    : (activeGreen ?? const Color(0xFF48C9B0));
                return StatusBadge(
                  label: c,
                  color: col,
                  showDot: false,
                  fontSize: 8.5,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                );
              }).toList(),
            )
          else
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                fontSize: 9.5,
                color: subtitleColor,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required String tabId,
    required String title,
    required IconData icon,
    required Color activeColor,
    required Color cardBg,
    required Color borderColor,
    required Color textColor,
    String? trailingBadge,
    Color? trailingColor,
  }) {
    final isSelected = _activeTab == tabId;
    return InkWell(
      onTap: () => setState(() => _activeTab = tabId),
      borderRadius: BorderRadius.circular(100),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : cardBg,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: isSelected ? activeColor : borderColor,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? Colors.white : activeColor,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: isSelected ? Colors.white : textColor,
              ),
            ),
            if (trailingBadge != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: (isSelected
                          ? Colors.white
                          : (trailingColor ?? Colors.orangeAccent))
                      .withValues(alpha: isSelected ? 0.25 : 0.14),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  trailingBadge,
                  style: GoogleFonts.outfit(
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    color: isSelected
                        ? Colors.white
                        : (trailingColor ?? Colors.orangeAccent),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFinancialComingSoonTab({
    required bool isEn,
    required Color cardBg,
    required Color borderColor,
    required Color textColor,
    required Color subtitleColor,
    required Color activeGreen,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CustomCard(
          color: cardBg,
          borderColor: borderColor,
          borderRadius: 18,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: activeGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.account_balance_rounded,
                  color: activeGreen,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEn
                          ? 'Puskesmas Financial Bookkeeping (BLUD / Operational Ledger)'
                          : 'Pembukuan Keuangan Puskesmas (Kas & Operasional BLUD)',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isEn
                          ? 'Financial cashflow & expenditure ledger for Puskesmas is coming soon. You can already use the Patient List & SATUSEHAT tab for clinical record submission.'
                          : 'Fitur pencatatan arus kas dan anggaran keuangan Puskesmas akan segera hadir. Sementara ini Anda sudah dapat menggunakan tab Daftar Pasien & SATUSEHAT untuk pengiriman rekam medis.',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        color: subtitleColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              CustomButton(
                text: isEn ? 'Open SATUSEHAT Tab' : 'Buka Tab SATUSEHAT',
                icon: Icons.cloud_sync_rounded,
                height: 38,
                primaryColor: activeGreen,
                onPressed: () => setState(() => _activeTab = 'satusehat'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const SegeraHadirMockup(portalPath: 'PUSKESMAS/pembukuan-keuangan'),
      ],
    );
  }

  Widget _buildSatuSehatTab({
    required LandingPageState state,
    required bool isEn,
    required bool isDark,
    required bool isMobile,
    required Color cardBg,
    required Color borderColor,
    required Color inputBg,
    required Color textColor,
    required Color subtitleColor,
    required Color activeGreen,
    required Color bpjsColor,
    required Color warningColor,
    required Color errorColor,
  }) {
    final bool hasGeneralRecords =
        _encounters.any((e) => e.sourceModule == 'umum');

    final filteredEncounters = _encounters.where((e) {
      final q = _searchQuery.trim().toLowerCase();
      final matchesSearch = q.isEmpty ||
          e.patientName.toLowerCase().contains(q) ||
          e.patientNik.toLowerCase().contains(q) ||
          e.clusterLabel.toLowerCase().contains(q) ||
          e.visitLabel.toLowerCase().contains(q);

      bool matchesStatus = true;
      if (_statusFilter == 'Sent') {
        matchesStatus = e.syncStatus == 'success';
      } else if (_statusFilter == 'Unsent') {
        matchesStatus = e.syncStatus == 'unsent';
      } else if (_statusFilter == 'Failed') {
        matchesStatus = e.syncStatus == 'failed';
      }

      final matchesModule =
          _moduleFilter == 'all' || e.sourceModule == _moduleFilter;

      bool matchesDate = true;
      if (_selectedDateRange != null) {
        final start = DateTime(
          _selectedDateRange!.start.year,
          _selectedDateRange!.start.month,
          _selectedDateRange!.start.day,
        );
        final end = DateTime(
          _selectedDateRange!.end.year,
          _selectedDateRange!.end.month,
          _selectedDateRange!.end.day,
          23,
          59,
          59,
        );
        matchesDate = !e.visitDate.isBefore(start) && !e.visitDate.isAfter(end);
      }

      return matchesSearch && matchesStatus && matchesModule && matchesDate;
    }).toList();

    final totalItems = filteredEncounters.length;
    final totalPages = max(1, (totalItems / _itemsPerPage).ceil());
    final safePage = _currentPage.clamp(1, totalPages);
    final startIdx = totalItems == 0 ? 0 : (safePage - 1) * _itemsPerPage;
    final endIdx = min(totalItems, startIdx + _itemsPerPage);
    final paginated = totalItems == 0
        ? <PuskesmasEncounterRecord>[]
        : filteredEncounters.sublist(startIdx, endIdx);

    final momicareCount =
        _encounters.where((e) => e.sourceModule == 'momicare').length;
    final vitascaleCount =
        _encounters.where((e) => e.sourceModule == 'vitascale').length;
    final umumCount = _encounters.where((e) => e.sourceModule == 'umum').length;

    final isStaging = _config?.isStaging ?? false;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Panel Header & Controls
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        isEn
                            ? 'Patient Sync Status'
                            : 'Status Sinkronisasi Pasien',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: textColor,
                        ),
                      ),
                      StatusBadge(
                        label: isStaging
                            ? 'DEVELOPMENT / STAGING'
                            : 'PRODUCTION KEMENKES',
                        color: isStaging ? bpjsColor : activeGreen,
                        showDot: false,
                        fontSize: 8.5,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isEn
                        ? 'Monitor and submit Puskesmas encounter data (MomiCare ANC, VitaScale, Clinic) to SATUSEHAT.'
                        : 'Pantau & kirim data kunjungan Puskesmas (MomiCare KIA, VitaScale Anak, Layanan) ke platform SATUSEHAT Kemenkes.',
                    style: GoogleFonts.outfit(
                      fontSize: 10.5,
                      color: subtitleColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: isMobile ? double.infinity : 230,
                    child: CustomSearchBar(
                      height: 40,
                      borderRadius: 10,
                      backgroundColor: inputBg,
                      borderColor: borderColor,
                      textColor: textColor,
                      hintColor: subtitleColor,
                      hintText: isEn
                          ? 'Search name or NIK...'
                          : 'Cari nama atau NIK...',
                      onChanged: (val) => setState(() {
                        _searchQuery = val;
                        _currentPage = 1;
                      }),
                    ),
                  ),
                  InkWell(
                    onTap: () async {
                      final picked = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                        initialDateRange: _selectedDateRange,
                      );
                      if (picked != null) {
                        setState(() {
                          _selectedDateRange = picked;
                          _currentPage = 1;
                        });
                      }
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: inputBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: borderColor),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.calendar_today_rounded,
                            size: 14,
                            color: subtitleColor,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _selectedDateRange == null
                                ? (isEn ? 'Select Date' : 'Pilih Tanggal')
                                : '${AppTranslations.formatDate(_selectedDateRange!.start, lang: state.language, includeDay: false)} - ${AppTranslations.formatDate(_selectedDateRange!.end, lang: state.language, includeDay: false)}',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: textColor,
                            ),
                          ),
                          if (_selectedDateRange != null) ...[
                            const SizedBox(width: 6),
                            InkWell(
                              onTap: () => setState(() {
                                _selectedDateRange = null;
                                _currentPage = 1;
                              }),
                              child: Icon(
                                Icons.close_rounded,
                                size: 15,
                                color: errorColor,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                    width: isMobile ? double.infinity : 215,
                    child: CustomDropdown<String>(
                      value: _statusFilter,
                      backgroundColor: inputBg,
                      borderColor: borderColor,
                      textColor: textColor,
                      borderRadius: 10,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 0,
                      ),
                      items: [
                        CustomDropdownItem(
                          value: 'All',
                          label: isEn ? 'All Status' : 'Semua Status',
                        ),
                        CustomDropdownItem(
                          value: 'Sent',
                          label: isEn ? 'Sent' : 'Terkirim',
                        ),
                        CustomDropdownItem(
                          value: 'Unsent',
                          label: isEn ? 'Unsent' : 'Belum Terkirim',
                        ),
                        CustomDropdownItem(
                          value: 'Failed',
                          label: isEn ? 'Failed' : 'Gagal',
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _statusFilter = val;
                            _currentPage = 1;
                          });
                        }
                      },
                    ),
                  ),
                  CustomButton(
                    text: _isBulkSyncMode
                        ? (_isSavingBulk
                              ? (isEn ? 'Syncing...' : 'Mengirim...')
                              : (isEn
                                    ? 'Sync Selected (${_selectedEncounterIds.length})'
                                    : 'Kirim Terpilih (${_selectedEncounterIds.length})'))
                        : (isEn
                              ? 'Select for Bulk Sync'
                              : 'Pilih Sinkronisasi Massal'),
                    icon: _isBulkSyncMode
                        ? Icons.cloud_upload_rounded
                        : Icons.checklist_rounded,
                    height: 40,
                    isSecondary: !_isBulkSyncMode,
                    primaryColor: activeGreen,
                    textColor: _isBulkSyncMode ? Colors.white : textColor,
                    borderColor: _isBulkSyncMode ? activeGreen : borderColor,
                    onPressed: _isSavingBulk
                        ? null
                        : () {
                            if (_isBulkSyncMode) {
                              _triggerBulkSync();
                            } else {
                              setState(() {
                                _isBulkSyncMode = true;
                                _selectedEncounterIds.clear();
                              });
                            }
                          },
                  ),
                  if (_isBulkSyncMode)
                    IconButton(
                      tooltip: AppTranslations.commonCancel(isEn),
                      icon: Icon(Icons.close_rounded, color: errorColor),
                      onPressed: _isSavingBulk
                          ? null
                          : () => setState(() {
                              _isBulkSyncMode = false;
                              _selectedEncounterIds.clear();
                            }),
                    ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Module Filter Chips (MomiCare, VitaScale, General)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              CustomFilterChip<String>(
                label: AppTranslations.commonAll(isEn),
                value: 'all',
                selectedValue: _moduleFilter,
                count: _encounters.length,
                activeColor: activeGreen,
                inactiveBgColor: inputBg,
                borderColor: borderColor,
                onSelected: (v) => setState(() {
                  _moduleFilter = v;
                  _currentPage = 1;
                }),
              ),
              CustomFilterChip<String>(
                label: 'MomiCare (KIA)',
                icon: Icons.pregnant_woman_rounded,
                value: 'momicare',
                selectedValue: _moduleFilter,
                count: momicareCount,
                activeColor: activeGreen,
                inactiveBgColor: inputBg,
                borderColor: borderColor,
                onSelected: (v) => setState(() {
                  _moduleFilter = v;
                  _currentPage = 1;
                }),
              ),
              CustomFilterChip<String>(
                label: isEn ? 'VitaScale (Child)' : 'VitaScale (Anak)',
                icon: Icons.child_care_rounded,
                value: 'vitascale',
                selectedValue: _moduleFilter,
                count: vitascaleCount,
                activeColor: activeGreen,
                inactiveBgColor: inputBg,
                borderColor: borderColor,
                onSelected: (v) => setState(() {
                  _moduleFilter = v;
                  _currentPage = 1;
                }),
              ),
              if (hasGeneralRecords)
                CustomFilterChip<String>(
                  label: isEn ? 'General Clinic' : 'Poli Umum',
                  icon: Icons.local_hospital_rounded,
                  value: 'umum',
                  selectedValue: _moduleFilter,
                  count: umumCount,
                  activeColor: activeGreen,
                  inactiveBgColor: inputBg,
                  borderColor: borderColor,
                  onSelected: (v) => setState(() {
                    _moduleFilter = v;
                    _currentPage = 1;
                  }),
                ),
            ],
          ),

          const SizedBox(height: 16),

          // Table or Empty State
          if (filteredEncounters.isEmpty)
            EmptyStateWidget(
              icon: Icons.cloud_off_rounded,
              title: isEn
                  ? 'No Puskesmas Encounter Records Found'
                  : 'Tidak Ada Data Kunjungan Ditemukan',
              subtitle: isEn
                  ? 'Try clearing the search query, date filter, or record a new MomiCare / VitaScale visit.'
                  : 'Coba ubah filter pencarian/tanggal atau catat pemeriksaan baru di MomiCare / VitaScale.',
              cardBg: inputBg,
              border: borderColor,
              textColor: textColor,
              subtitleColor: subtitleColor,
            )
          else
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: borderColor),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final tableMinWidth = max(constraints.maxWidth, 760.0);
                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            width: tableMinWidth,
                            child: Table(
                              columnWidths: _isBulkSyncMode
                                  ? const {
                                      0: FlexColumnWidth(0.55),
                                      1: FlexColumnWidth(1.2),
                                      2: FlexColumnWidth(2.2),
                                      3: FlexColumnWidth(1.6),
                                      4: FlexColumnWidth(0.9),
                                      5: FlexColumnWidth(1.3),
                                    }
                                  : const {
                                      0: FlexColumnWidth(1.2),
                                      1: FlexColumnWidth(2.2),
                                      2: FlexColumnWidth(1.6),
                                      3: FlexColumnWidth(0.9),
                                      4: FlexColumnWidth(1.3),
                                    },
                              defaultVerticalAlignment:
                                  TableCellVerticalAlignment.middle,
                              children: [
                                TableRow(
                                  decoration: BoxDecoration(
                                    color: inputBg,
                                    border: Border(
                                      bottom: BorderSide(color: borderColor),
                                    ),
                                  ),
                                  children: [
                                    if (_isBulkSyncMode)
                                      Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Checkbox(
                                          value:
                                              _selectedEncounterIds.length ==
                                                  filteredEncounters.length &&
                                              filteredEncounters.isNotEmpty,
                                          activeColor: activeGreen,
                                          onChanged: (val) {
                                            setState(() {
                                              if (val == true) {
                                                _selectedEncounterIds.addAll(
                                                  filteredEncounters.map(
                                                    (e) => e.id,
                                                  ),
                                                );
                                              } else {
                                                _selectedEncounterIds.clear();
                                              }
                                            });
                                          },
                                        ),
                                      ),
                                    _tableHeader(
                                      isEn ? 'DATE' : 'TANGGAL',
                                      subtitleColor,
                                    ),
                                    _tableHeader(
                                      isEn ? 'PATIENT' : 'PASIEN',
                                      subtitleColor,
                                    ),
                                    _tableHeader(
                                      isEn ? 'MODULE / VISIT' : 'MODUL / KUNJUNGAN',
                                      subtitleColor,
                                    ),
                                    _tableHeader(
                                      isEn ? 'TYPE' : 'TIPE',
                                      subtitleColor,
                                    ),
                                    _tableHeader(
                                      isEn ? 'SYNC STATUS' : 'STATUS SYNC',
                                      subtitleColor,
                                    ),
                                  ],
                                ),
                                ...paginated.map((rec) {
                                  final isSelected =
                                      _selectedEncounterIds.contains(rec.id);
                                  final Color statusColor;
                                  final String statusLabel;
                                  if (rec.syncStatus == 'success') {
                                    statusColor = activeGreen;
                                    statusLabel = isEn ? 'Sent' : 'Terkirim';
                                  } else if (rec.syncStatus == 'failed') {
                                    statusColor = errorColor;
                                    statusLabel = isEn ? 'Failed' : 'Gagal';
                                  } else {
                                    statusColor = warningColor;
                                    statusLabel = isEn
                                        ? 'Unsent'
                                        : 'Belum Terkirim';
                                  }

                                  void onTapRow() {
                                    setState(() => _selectedRecord = rec);
                                  }

                                  return TableRow(
                                    decoration: BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(color: borderColor),
                                      ),
                                      color: isSelected
                                          ? activeGreen.withValues(alpha: 0.05)
                                          : Colors.transparent,
                                    ),
                                    children: [
                                      if (_isBulkSyncMode)
                                        Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Checkbox(
                                            value: isSelected,
                                            activeColor: activeGreen,
                                            onChanged: (val) {
                                              setState(() {
                                                if (val == true) {
                                                  _selectedEncounterIds.add(
                                                    rec.id,
                                                  );
                                                } else {
                                                  _selectedEncounterIds.remove(
                                                    rec.id,
                                                  );
                                                }
                                              });
                                            },
                                          ),
                                        ),
                                      _tableCellClickable(
                                        Text(
                                          AppTranslations.formatDate(
                                            rec.visitDate,
                                            lang: state.language,
                                            includeDay: false,
                                          ),
                                          style: GoogleFonts.outfit(
                                            fontSize: 10.5,
                                            color: textColor,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        onTapRow,
                                      ),
                                      _tableCellClickable(
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              rec.patientName,
                                              style: GoogleFonts.outfit(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w900,
                                                color: textColor,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'NIK: ${rec.patientNik}${(rec.satusehatPatientId != null && rec.satusehatPatientId!.isNotEmpty) ? ' • IHS: ${rec.satusehatPatientId}' : ''}',
                                              style: GoogleFonts.outfit(
                                                fontSize: 9.5,
                                                color: subtitleColor,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                        onTapRow,
                                      ),
                                      _tableCellClickable(
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            StatusBadge(
                                              label: rec.clusterLabel,
                                              color: rec.sourceModule == 'momicare'
                                                  ? bpjsColor
                                                  : activeGreen,
                                              icon: rec.sourceModule == 'momicare'
                                                  ? Icons.pregnant_woman_rounded
                                                  : (rec.sourceModule == 'vitascale'
                                                        ? Icons.child_care_rounded
                                                        : Icons.local_hospital_rounded),
                                              showDot: false,
                                              fontSize: 9,
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 3,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              rec.visitLabel,
                                              style: GoogleFonts.outfit(
                                                fontSize: 9.5,
                                                color: subtitleColor,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                        onTapRow,
                                      ),
                                      _tableCellClickable(
                                        StatusBadge(
                                          label: rec.patientType.toUpperCase(),
                                          color: rec.patientType == 'BPJS'
                                              ? bpjsColor
                                              : activeGreen,
                                          showDot: false,
                                          fontSize: 8.5,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                        ),
                                        onTapRow,
                                      ),
                                      _tableCellClickable(
                                        StatusBadge(
                                          label: statusLabel,
                                          color: statusColor,
                                          fontSize: 9.5,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                        ),
                                        onTapRow,
                                      ),
                                    ],
                                  );
                                }),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    ReusablePagination(
                      totalItems: totalItems,
                      itemsPerPage: _itemsPerPage,
                      currentPage: safePage,
                      onPageChanged: (page) =>
                          setState(() => _currentPage = page),
                      onItemsPerPageChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _itemsPerPage = val;
                            _currentPage = 1;
                          });
                        }
                      },
                      textColor: textColor,
                      subtitleColor: subtitleColor,
                      borderColor: borderColor,
                      inputBg: inputBg,
                      activeColor: activeGreen,
                      languageCode: state.language,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPatientSyncModal({
    required LandingPageState state,
    required bool isEn,
    required bool isDark,
    required Color cardBg,
    required Color textColor,
    required Color subtitleColor,
    required Color borderColor,
    required Color inputBg,
    required Color activeGreen,
    required Color bpjsColor,
    required Color warningColor,
    required Color errorColor,
  }) {
    final rec = _selectedRecord!;
    final ssId = rec.satusehatPatientId?.trim() ?? '';
    final hasSatuSehatId = ssId.isNotEmpty;
    final lastError = rec.syncError?.trim() ?? '';

    return Positioned.fill(
      child: GestureDetector(
        onTap: _isSyncingIndividual
            ? null
            : () => setState(() => _selectedRecord = null),
        child: Container(
          color: Colors.black.withValues(alpha: 0.4),
          child: GestureDetector(
            onTap: () {},
            child: Center(
              child: Container(
                width: 540,
                constraints: BoxConstraints(
                  maxHeight: min(680, MediaQuery.of(context).size.height - 40),
                ),
                margin: const EdgeInsets.symmetric(
                  vertical: 20,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: borderColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Modal Header
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: activeGreen,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(25),
                          topRight: Radius.circular(25),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Colors.white24,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              rec.sourceModule == 'momicare'
                                  ? Icons.pregnant_woman_rounded
                                  : (rec.sourceModule == 'vitascale'
                                        ? Icons.child_care_rounded
                                        : Icons.person_outline_rounded),
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  rec.patientName,
                                  style: GoogleFonts.outfit(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  '${rec.patientType.toUpperCase()} • NIK: ${rec.patientNik} • ${rec.clusterLabel}',
                                  style: GoogleFonts.outfit(
                                    fontSize: 10,
                                    color: Colors.white.withValues(alpha: 0.9),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            onPressed: _isSyncingIndividual
                                ? null
                                : () => setState(() => _selectedRecord = null),
                          ),
                        ],
                      ),
                    ),

                    // Modal Body
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(22),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _modalSectionHeader(
                              Icons.insights_rounded,
                              isEn
                                  ? 'VITAL SIGNS & ANTHROPOMETRY'
                                  : 'TANDA VITAL & ANTROPOMETRI',
                              activeGreen,
                            ),
                            const SizedBox(height: 10),
                            _buildVitalsGrid(
                              rec: rec,
                              isEn: isEn,
                              borderColor: borderColor,
                              textColor: textColor,
                              subtitleColor: subtitleColor,
                            ),
                            const SizedBox(height: 18),

                            _modalSectionHeader(
                              Icons.assignment_outlined,
                              isEn
                                  ? 'MAIN COMPLAINT / VISIT NOTES'
                                  : 'KELUHAN & CATATAN KUNJUNGAN',
                              activeGreen,
                            ),
                            const SizedBox(height: 6),
                            _buildInfoBox(
                              rec.mainComplaint,
                              subtitleColor,
                              borderColor,
                            ),
                            const SizedBox(height: 18),

                            _modalSectionHeader(
                              Icons.assignment_turned_in_outlined,
                              'DIAGNOSIS (ICD-10)',
                              activeGreen,
                            ),
                            const SizedBox(height: 6),
                            _buildDiagnosisCard(
                              rec.diagnoses,
                              isEn: isEn,
                              borderColor: borderColor,
                              subtitleColor: subtitleColor,
                              activeGreen: activeGreen,
                            ),
                            const SizedBox(height: 18),

                            _modalSectionHeader(
                              Icons.medical_services_outlined,
                              isEn
                                  ? 'PHYSICAL EXAM & CLINICAL SUMMARY'
                                  : 'PEMERIKSAAN FISIK & RINGKASAN KLINIS',
                              activeGreen,
                            ),
                            const SizedBox(height: 6),
                            _buildInfoBox(
                              rec.physicalExam,
                              subtitleColor,
                              borderColor,
                            ),
                            const SizedBox(height: 18),

                            _modalSectionHeader(
                              Icons.healing_outlined,
                              isEn
                                  ? 'THERAPY, MEDICATIONS & INTERVENTIONS'
                                  : 'TERAPI, OBAT & TINDAKAN PUSKESMAS',
                              activeGreen,
                            ),
                            const SizedBox(height: 6),
                            _buildTherapyTable(
                              rec.therapies,
                              isEn: isEn,
                              borderColor: borderColor,
                              subtitleColor: subtitleColor,
                              textColor: textColor,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Modal Footer (Sync controls & Status)
                    if (_isSyncingIndividual)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: inputBg,
                          border: Border(top: BorderSide(color: borderColor)),
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(26),
                            bottomRight: Radius.circular(26),
                          ),
                        ),
                        child: CustomProgressBar(
                          value: _syncProgressValue,
                          label: _getSyncStepLabel(isEn),
                          sublabel: isEn
                              ? 'Communicating via Puskesmas SATUSEHAT FHIR R4 Gateway...'
                              : 'Menghubungi Gateway FHIR R4 SATUSEHAT Puskesmas...',
                          primaryColor: activeGreen,
                          secondaryColor: bpjsColor,
                          height: 7.5,
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: inputBg,
                          border: Border(top: BorderSide(color: borderColor)),
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(26),
                            bottomRight: Radius.circular(26),
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (rec.syncStatus == 'failed' &&
                                lastError.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.all(12),
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: errorColor.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: errorColor.withValues(alpha: 0.25),
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.error_outline_rounded,
                                      color: errorColor,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            isEn
                                                ? 'LAST ERROR'
                                                : 'ERROR TERAKHIR',
                                            style: GoogleFonts.outfit(
                                              fontSize: 8.5,
                                              fontWeight: FontWeight.w900,
                                              color: errorColor,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            lastError,
                                            style: GoogleFonts.outfit(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w700,
                                              color: textColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            if (rec.syncStatus == 'success' &&
                                (rec.satusehatEncounterId ?? '').isNotEmpty)
                              Container(
                                padding: const EdgeInsets.all(10),
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: activeGreen.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: activeGreen.withValues(alpha: 0.25),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.verified_rounded,
                                      size: 16,
                                      color: activeGreen,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        isEn
                                            ? 'SATUSEHAT Encounter ID: ${rec.satusehatEncounterId}'
                                            : 'ID Encounter SATUSEHAT: ${rec.satusehatEncounterId}',
                                        style: GoogleFonts.outfit(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w800,
                                          color: activeGreen,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            if (!hasSatuSehatId)
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: warningColor.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: warningColor.withValues(alpha: 0.25),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.person_add_alt_1_outlined,
                                      color: warningColor,
                                      size: 20,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      isEn
                                          ? 'Patient Not Registered in SATUSEHAT'
                                          : 'Pasien Belum Terdaftar di SATUSEHAT',
                                      style: GoogleFonts.outfit(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w900,
                                        color: textColor,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      isEn
                                          ? 'Register or verify patient IHS ID by NIK before sending encounter data.'
                                          : 'Verifikasi atau daftarkan IHS ID pasien via NIK sebelum mengirim rekam medis.',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.outfit(
                                        fontSize: 10.5,
                                        color: subtitleColor,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    CustomButton(
                                      text: _isRegisteringPatient
                                          ? (isEn
                                                ? 'Verifying NIK...'
                                                : 'Memverifikasi NIK...')
                                          : (isEn
                                                ? 'Register Patient to SATUSEHAT'
                                                : 'Daftarkan Pasien ke SATUSEHAT'),
                                      icon: Icons.send_rounded,
                                      height: 42,
                                      primaryColor: warningColor,
                                      onPressed: _isRegisteringPatient
                                          ? null
                                          : () => _registerPatient(rec),
                                    ),
                                  ],
                                ),
                              )
                            else
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        StatusBadge(
                                          label: 'IHS Pasien: $ssId',
                                          color: activeGreen,
                                          icon: Icons.fingerprint_rounded,
                                          fontSize: 9.5,
                                        ),
                                        Text(
                                          rec.examinerName,
                                          style: GoogleFonts.outfit(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: subtitleColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  CustomButton(
                                    text: rec.syncStatus == 'success'
                                        ? (isEn
                                              ? 'Resend Encounter Data'
                                              : 'Kirim Ulang Data Kunjungan')
                                        : (isEn
                                              ? 'Send Encounter Data Now'
                                              : 'Kirim Data Kunjungan Sekarang'),
                                    icon: Icons.send_rounded,
                                    height: 46,
                                    primaryColor: activeGreen,
                                    onPressed: () => _syncSingleRecord(rec),
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
          ),
        ),
      ),
    );
  }

  String _getSyncStepLabel(bool isEn) {
    switch (_individualSyncStep) {
      case 'Connecting':
        return isEn
            ? 'Connecting to Kemenkes SATUSEHAT endpoint...'
            : 'Menghubungkan ke server SATUSEHAT Kemenkes...';
      case 'SendingEMR':
        return isEn
            ? 'Uploading clinical Encounter resource (FHIR R4)...'
            : 'Mengirim resource Encounter FHIR R4...';
      case 'SendingObservations':
        return isEn
            ? 'Sending clinical Observations & ICD-10 Conditions...'
            : 'Mengirim Observasi klinis & Diagnosis ICD-10...';
      case 'GeneratingPrescription':
        return isEn
            ? 'Submitting MedicationRequest & clinical summary...'
            : 'Mengirim MedicationRequest & ringkasan klinis...';
      case 'Success':
        return isEn
            ? 'Synced successfully! Updating Puskesmas log...'
            : 'Berhasil terkirim! Memperbarui log Puskesmas...';
      default:
        return isEn
            ? 'Processing synchronization...'
            : 'Memproses sinkronisasi...';
    }
  }

  Widget _modalSectionHeader(IconData icon, String title, Color accent) {
    return Row(
      children: [
        Icon(icon, color: accent, size: 13),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 9.5,
            fontWeight: FontWeight.w900,
            color: accent,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildVitalsGrid({
    required PuskesmasEncounterRecord rec,
    required bool isEn,
    required Color borderColor,
    required Color textColor,
    required Color subtitleColor,
  }) {
    final v = rec.vitals;
    final List<Map<String, String>> tiles = [];

    if (rec.sourceModule == 'momicare') {
      tiles.addAll([
        {'label': isEn ? 'BLOOD PRESSURE' : 'TEKANAN DARAH', 'val': v['blood_pressure'] ?? '-'},
        {'label': isEn ? 'WEIGHT' : 'BERAT BADAN', 'val': v['body_weight'] != null && v['body_weight'] != '-' ? '${v['body_weight']} kg' : '-'},
        {'label': 'LILA', 'val': v['lila'] != null && v['lila'] != '-' ? '${v['lila']} cm' : '-'},
        {'label': isEn ? 'FETAL HR / HB' : 'DJJ / HB', 'val': v['djj'] != null && v['djj'] != '-' ? v['djj']! : (v['hb'] ?? '-')},
      ]);
    } else if (rec.sourceModule == 'vitascale') {
      tiles.addAll([
        {'label': isEn ? 'WEIGHT' : 'BERAT BADAN', 'val': v['body_weight'] != null && v['body_weight'] != '-' ? '${v['body_weight']} kg' : '-'},
        {'label': v['mode'] == 'PB' ? (isEn ? 'LENGTH (PB)' : 'PANJANG (PB)') : (isEn ? 'HEIGHT (TB)' : 'TINGGI (TB)'), 'val': v['body_height'] != null && v['body_height'] != '-' ? '${v['body_height']} cm' : '-'},
        {'label': isEn ? 'WAIST CIRC.' : 'LINGKAR PERUT', 'val': v['waist'] != null && v['waist'] != '-' ? '${v['waist']} cm' : '-'},
        {'label': 'LILA', 'val': v['lila'] != null && v['lila'] != '-' ? '${v['lila']} cm' : '-'},
      ]);
    } else {
      tiles.addAll([
        {'label': isEn ? 'BLOOD PRESSURE' : 'TEKANAN DARAH', 'val': v['blood_pressure'] ?? '-'},
        {'label': isEn ? 'TEMP' : 'SUHU', 'val': v['body_temperature'] != null && v['body_temperature'] != '-' ? '${v['body_temperature']}°C' : '-'},
        {'label': isEn ? 'WEIGHT' : 'BERAT BADAN', 'val': v['body_weight'] != null && v['body_weight'] != '-' ? '${v['body_weight']} kg' : '-'},
        {'label': 'SPO2', 'val': v['spo2'] != null && v['spo2'] != '-' ? '${v['spo2']}%' : '-'},
      ]);
    }

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 4,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: 1.45,
      children: tiles
          .map(
            (t) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: borderColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    t['label']!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontSize: 7,
                      fontWeight: FontWeight.w900,
                      color: subtitleColor,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    t['val']!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w900,
                      color: textColor,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildInfoBox(String text, Color subtitleColor, Color borderColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: borderColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        text.trim().isNotEmpty ? text : '-',
        style: GoogleFonts.outfit(
          fontSize: 11,
          color: subtitleColor,
          fontWeight: FontWeight.w600,
          height: 1.35,
        ),
      ),
    );
  }

  Widget _buildDiagnosisCard(
    List<Map<String, String>> diagnoses, {
    required bool isEn,
    required Color borderColor,
    required Color subtitleColor,
    required Color activeGreen,
  }) {
    if (diagnoses.isEmpty) {
      return _buildInfoBox(
        isEn ? 'No diagnosis data' : 'Belum ada data diagnosis',
        subtitleColor,
        borderColor,
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: borderColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: diagnoses.map((d) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StatusBadge(
                  label: d['code'] ?? 'Z00',
                  color: activeGreen,
                  showDot: false,
                  fontSize: 8.5,
                  borderRadius: 6,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    d['description'] ?? '-',
                    style: GoogleFonts.outfit(
                      fontSize: 10.5,
                      color: subtitleColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTherapyTable(
    List<Map<String, String>> therapies, {
    required bool isEn,
    required Color borderColor,
    required Color subtitleColor,
    required Color textColor,
  }) {
    if (therapies.isEmpty) {
      return _buildInfoBox(
        isEn ? 'No therapy / medication data' : 'Belum ada data terapi / obat',
        subtitleColor,
        borderColor,
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: borderColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(2.0),
          1: FlexColumnWidth(0.8),
          2: FlexColumnWidth(1.5),
        },
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          TableRow(
            decoration: BoxDecoration(
              color: borderColor.withValues(alpha: 0.18),
              border: Border(bottom: BorderSide(color: borderColor)),
            ),
            children: [
              _tableHeader(isEn ? 'THERAPY / ITEM' : 'TERAPI / OBAT', subtitleColor),
              _tableHeader(isEn ? 'QTY' : 'JML', subtitleColor),
              _tableHeader(isEn ? 'DOSAGE / NOTE' : 'ATURAN / CATATAN', subtitleColor),
            ],
          ),
          ...therapies.map(
            (item) => TableRow(
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: borderColor)),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Text(
                    item['name'] ?? '-',
                    style: GoogleFonts.outfit(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Text(
                    item['qty'] ?? '-',
                    style: GoogleFonts.outfit(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                      color: textColor,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Text(
                    item['dosage'] ?? '-',
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      color: subtitleColor,
                      fontWeight: FontWeight.w600,
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

  Widget _tableHeader(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Text(
        text,
        style: GoogleFonts.outfit(
          fontSize: 8.5,
          fontWeight: FontWeight.w900,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _tableCellClickable(Widget child, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Align(alignment: Alignment.centerLeft, child: child),
      ),
    );
  }
}
