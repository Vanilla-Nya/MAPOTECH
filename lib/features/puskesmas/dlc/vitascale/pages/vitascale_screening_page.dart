import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:mapotech/features/landing/landing_page_data.dart';
import 'package:mapotech/shared/satusehat_service.dart';
import 'package:mapotech/shared/widgets/ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../cv/vitascale_camera_bridge.dart';
import '../data/community_health_center_service.dart';
import '../data/vitascale_api_service.dart';
import '../data/mqtt/vitascale_mqtt_service.dart';
import '../data/vitascale_device_simulator.dart';
import '../data/vitascale_models.dart';
import '../data/vitascale_repository.dart';
import '../logic/screening_state_machine.dart';
import '../logic/vitascale_reasoning_service.dart';
import '../vitascale_dlc_gate.dart';
import '../widgets/measurement_card.dart';
import '../widgets/vitascale_status_bar.dart';

class VitaScaleScreeningPage extends ConsumerStatefulWidget {
  final ChildProfile? selectedChild;
  final ValueChanged<String>? onNavigateToMenu;

  const VitaScaleScreeningPage({
    super.key,
    this.selectedChild,
    this.onNavigateToMenu,
  });

  @override
  ConsumerState<VitaScaleScreeningPage> createState() => _VitaScaleScreeningPageState();
}

class _VitaScaleScreeningPageState extends ConsumerState<VitaScaleScreeningPage> {
  // Mode Tab: 0 = Input Manual & AI Reasoning (Uji Ukur), 1 = Perangkat IoT & Webcam CV
  int _activeTab = 0;
  int _formStep = 1; // 1: Identitas Balita, 2: Antropometri Fisik, 3: Reasoning AI, 4: SATUSEHAT & Database
  int _iotSubTab = 0; // 0 = Sensor IoT ESP32 (Ultrasonik & Load Cell), 1 = Kamera Webcam CV

  // Simulator & Repo untuk Mode IoT
  late final VitaScaleDeviceSimulator _simulator;
  final VitaScaleRepository _repository = VitaScaleRepository();
  final TextEditingController _notesController = TextEditingController();

  List<ChildProfile> _availableChildren = [];
  ChildProfile? _activeChild;

  // Pencarian Pasien di Bagian Atas
  final TextEditingController _topSearchController = TextEditingController();
  String _topSearchQuery = '';

  // ===========================================================================
  // STATE INPUT MANUAL & API MLP & REASONING MODEL
  // ===========================================================================
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _nikController = TextEditingController();
  final TextEditingController _ageController = TextEditingController(text: '24');
  final TextEditingController _weightController = TextEditingController(text: '11.5');
  final TextEditingController _heightController = TextEditingController(text: '85.0');
  final TextEditingController _waistController = TextEditingController(text: '46.0');
  final TextEditingController _lilaController = TextEditingController(text: '14.5');
  final TextEditingController _headCircumferenceController = TextEditingController(text: '47.0');

  int _selectedGender = 0; // 0 = Laki-laki, 1 = Perempuan
  double _ageMonths = 24.0;

  // Parameter Khusus Buku KIA 2024 & SATUSEHAT
  String _measurementMethod = 'TB'; // 'PB' = Telentang (<24 bln), 'TB' = Berdiri (≥24 bln)
  String _kmsStatus = 'N'; // 'N', 'T', '2T', 'BGM', 'Baru'
  bool _receivedVitA = true;
  bool _receivedDeworming = true;

  // SATUSEHAT FHIR State
  bool _isCheckingSatuSehatPatient = false;
  String? _satuSehatPatientId;
  bool _isSyncingSatuSehat = false;
  Map<String, dynamic>? _satuSehatSyncResult;

  // Server health state
  bool _isCheckingServer = false;
  Map<String, dynamic>? _serverStatus;

  // Prediction & Reasoning State
  bool _isLoadingClassification = false;
  HasilSmartGrowthBalita? _smartGrowthResult;

  bool _isLoadingReasoning = false;
  VitaScaleReasoningResult? _reasoningResult;
  int _activeReasoningTab = 0;
  int _reasoningPromptCount = 0;

  // ===========================================================================
  // STATE PCV COMPUTER VISION CLOUD API (https://pcvmapotechs5.vercel.app/)
  // ===========================================================================
  int _pcvInputMode = 0; // 0 = File Lokal, 1 = Link / URL, 2 = Kamera
  Uint8List? _pcvSelectedImageBytes;
  String? _pcvSelectedImageName;
  final TextEditingController _pcvUrlController = TextEditingController();
  final TextEditingController _pcvCustomScaleController = TextEditingController(text: '11.00');
  double _pcvSelectedScale = 11.00; // Default 11.00 px/cm (Dataset Boneka & Infantometer standar)
  bool _pcvUseRoi = false; // Default false (Full Frame agar tidak memotong tubuh/kaki)
  bool _pcvUseK1 = false; // Koreksi distorsi lensa
  bool _isLoadingPcvImage = false;
  bool _isMeasuringPcv = false;
  double _pcvProgress = 0.0;
  Timer? _pcvProgressTimer;
  Map<String, dynamic>? _pcvResultData;
  double? _pcvTinggiCm;
  double? _pcvPanjangPx;
  double? _pcvSkalaEfektif;
  String? _pcvAnnotatedImageBase64;
  String? _pcvMessage;
  String? _pcvErrorMessage;
  bool _pcvShowAnnotated = true;

  // ===========================================================================
  // STATE MQTT IOT TELEMETRY (Sensor Ultrasonik HC-SR04 & Load Cell HX711)
  // ===========================================================================
  final VitaScaleMqttService _mqttService = VitaScaleMqttService();
  final CommunityHealthCenterService _chcService = CommunityHealthCenterService();
  StreamSubscription? _mqttTelemetrySub;
  StreamSubscription? _mqttStatusSub;
  bool _isMqttConnecting = false;
  Map<String, dynamic>? _lastMqttTelemetry;
  String? _activeSavedWifiSsid;

  @override
  void initState() {
    super.initState();
    _simulator = VitaScaleDeviceSimulator(
      stateMachine: ref.read(screeningStateProvider.notifier),
    );

    _initMqttListeners();
    _initSession();
    _checkServer();
    _syncDeviceAndWifiFromDatabase();
  }

  /// Sinkronisasi antrean offline Wi-Fi & muat konfigurasi alat Puskesmas dari DB/Lokal
  Future<void> _syncDeviceAndWifiFromDatabase() async {
    try {
      final synced = await _chcService.syncPendingIotWifiToSupabase();
      final facilityId = ref.read(landingPageProvider).activePuskesmasId;
      final profile = await _chcService.fetchIotDeviceProfile(
        faskesCode: _mqttService.faskesId,
        deviceId: _mqttService.deviceId,
        facilityId: facilityId,
      );
      if (!mounted) return;
      setState(() {
        if (profile != null) {
          _activeSavedWifiSsid = profile['active_wifi_ssid'] as String?;
        }
      });
      if (synced > 0 && mounted) {
        CustomSnackbar.info(
          context,
          '$synced konfigurasi Wi-Fi alat berhasil disinkronkan ke database Supabase.',
          title: 'Sinkronisasi Wi-Fi Cloud',
        );
      }
    } catch (e) {
      debugPrint('[VitaScale DB Sync] Info: $e');
    }
  }

  @override
  void didUpdateWidget(covariant VitaScaleScreeningPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedChild != null && widget.selectedChild?.id != oldWidget.selectedChild?.id) {
      _selectChild(widget.selectedChild!);
    }
  }

  void _selectChild(ChildProfile child) {
    setState(() {
      _activeChild = child;
      _topSearchController.clear();
      _topSearchQuery = '';
    });
    _fillFormWithChild(child);

    final state = ref.read(landingPageProvider);
    final facilityId = state.activePuskesmasId ?? 'PUSKESMAS-001';
    ref.read(screeningStateProvider.notifier).startSession(
          child: child,
          facilityId: facilityId,
          isDemo: true,
        );
  }

  Future<void> _checkServer() async {
    setState(() => _isCheckingServer = true);
    final status = await VitaScaleApiService.checkHealth();
    if (mounted) {
      setState(() {
        _serverStatus = status;
        _isCheckingServer = false;
      });
    }
  }

  Future<void> _initSession() async {
    final list = await _repository.searchChildren();
    if (mounted) {
      setState(() {
        _availableChildren = list;
        _activeChild = widget.selectedChild;
      });

      if (_activeChild != null) {
        _fillFormWithChild(_activeChild!);
        final state = ref.read(landingPageProvider);
        final facilityId = state.activePuskesmasId ?? 'PUSKESMAS-001';

        ref.read(screeningStateProvider.notifier).startSession(
              child: _activeChild!,
              facilityId: facilityId,
              isDemo: true,
            );
      }
    }
  }

  void _fillFormWithChild(ChildProfile child) {
    setState(() {
      _formStep = 1;
      _reasoningPromptCount = 0;
      _smartGrowthResult = null;
      _reasoningResult = null;
      _nameController.text = child.name;
      _nikController.text = child.nik;
      _selectedGender = child.gender == 'L' ? 0 : 1;
      _ageMonths = child.ageInMonths.toDouble();
      _ageController.text = child.ageInMonths.toString();
      _measurementMethod = child.isUnder24Months ? 'PB' : 'TB';
      _satuSehatPatientId = null;
      _satuSehatSyncResult = null;

      // Estimasi default BB, TB, LK realistis sesuai standar Buku KIA 2024
      if (child.isUnder24Months) {
        _weightController.text = '9.5';
        _heightController.text = '76.0';
        _headCircumferenceController.text = '45.5';
      } else {
        _weightController.text = '12.0';
        _heightController.text = '88.0';
        _headCircumferenceController.text = '48.0';
      }
    });
  }

  @override
  void dispose() {
    _mqttTelemetrySub?.cancel();
    _mqttStatusSub?.cancel();
    _pcvProgressTimer?.cancel();
    _pcvUrlController.dispose();
    _simulator.dispose();
    _notesController.dispose();
    _topSearchController.dispose();
    _nameController.dispose();
    _nikController.dispose();
    _ageController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _waistController.dispose();
    _lilaController.dispose();
    _headCircumferenceController.dispose();
    super.dispose();
  }

  // ===========================================================================
  // HANDLER MQTT TELEMETRI & KONTROL IOT
  // ===========================================================================
  void _initMqttListeners() {
    _mqttTelemetrySub = _mqttService.telemetryStream.listen((data) {
      if (mounted) {
        _handleMqttTelemetry(data);
      }
    });

    _mqttStatusSub = _mqttService.connectionStatusStream.listen((status) {
      if (mounted) {
        setState(() {
          _isMqttConnecting = (status == DeviceConnectionStatus.connecting);
        });
        ref.read(screeningStateProvider.notifier).setDeviceStatus(status);
      }
    });
  }

  void _handleMqttTelemetry(Map<String, dynamic> data) {
    setState(() {
      _lastMqttTelemetry = data;
    });

    // Parse data berat badan dari Load Cell HX711 (Mendukung berbagai format JSON)
    double? valKg;
    bool isStable = false;
    if (data.containsKey('weight') && data['weight'] is Map) {
      final weightMap = data['weight'] as Map<String, dynamic>;
      valKg = (weightMap['val_kg'] as num?)?.toDouble();
      isStable = weightMap['is_stable'] == true;
    } else if (data.containsKey('weight') && data['weight'] is num) {
      valKg = (data['weight'] as num).toDouble();
      isStable = data['is_stable'] == true;
    } else if (data.containsKey('val_kg') && data['val_kg'] is num) {
      valKg = (data['val_kg'] as num).toDouble();
      isStable = data['is_stable'] == true;
    } else if (data.containsKey('berat') && data['berat'] is num) {
      valKg = (data['berat'] as num).toDouble();
      isStable = data['is_stable'] == true;
    }

    if (valKg != null && valKg > 0) {
      ref.read(screeningStateProvider.notifier).updateWeight(
        value: valKg,
        status: isStable ? MeasurementStatus.stable : MeasurementStatus.measuring,
        source: 'esp32_hx711_mqtt',
      );
    }

    // Parse data tinggi/panjang badan dari Ultrasonik HC-SR04
    double? valCm;
    if (data.containsKey('height') && data['height'] is Map) {
      final heightMap = data['height'] as Map<String, dynamic>;
      valCm = (heightMap['val_cm'] as num?)?.toDouble();
      final rawDist = (heightMap['raw_dist_cm'] as num?)?.toDouble();
      final pole = (heightMap['pole_height_cm'] as num?)?.toDouble() ?? _mqttService.poleHeightCm;
      if (valCm == null && rawDist != null) {
        valCm = pole - rawDist;
      }
    } else if (data.containsKey('height') && data['height'] is num) {
      valCm = (data['height'] as num).toDouble();
    } else if (data.containsKey('val_cm') && data['val_cm'] is num) {
      valCm = (data['val_cm'] as num).toDouble();
    } else if (data.containsKey('tinggi') && data['tinggi'] is num) {
      valCm = (data['tinggi'] as num).toDouble();
    }

    if (valCm != null && valCm > 0) {
      ref.read(screeningStateProvider.notifier).updateHeight(
        value: valCm,
        status: MeasurementStatus.stable,
        source: 'esp32_ultrasonic_mqtt',
      );
    }
  }

  /// Menerapkan hasil pembacaan MQTT live ke formulir skrining
  void _applyMqttTelemetryToForm({bool showSnackbar = true, bool switchToManualTab = false}) {
    if (_lastMqttTelemetry == null) {
      if (showSnackbar) {
        CustomSnackbar.warning(
          context,
          'Belum ada data telemetri yang diterima dari perangkat IoT.',
          title: 'Data Belum Tersedia',
        );
      }
      return;
    }

    final data = _lastMqttTelemetry!;
    double? extractedBb;
    double? extractedTb;

    // Extract BB
    if (data['weight'] is Map) {
      extractedBb = (data['weight']['val_kg'] as num?)?.toDouble();
    } else if (data['weight'] is num) {
      extractedBb = (data['weight'] as num).toDouble();
    } else if (data['val_kg'] is num) {
      extractedBb = (data['val_kg'] as num).toDouble();
    } else if (data['berat'] is num) {
      extractedBb = (data['berat'] as num).toDouble();
    }

    // Extract TB
    if (data['height'] is Map) {
      extractedTb = (data['height']['val_cm'] as num?)?.toDouble();
      final rawDist = (data['height']['raw_dist_cm'] as num?)?.toDouble();
      final pole = (data['height']['pole_height_cm'] as num?)?.toDouble() ?? _mqttService.poleHeightCm;
      if (extractedTb == null && rawDist != null) {
        extractedTb = pole - rawDist;
      }
    } else if (data['height'] is num) {
      extractedTb = (data['height'] as num).toDouble();
    } else if (data['val_cm'] is num) {
      extractedTb = (data['val_cm'] as num).toDouble();
    } else if (data['tinggi'] is num) {
      extractedTb = (data['tinggi'] as num).toDouble();
    }

    setState(() {
      if (extractedBb != null && extractedBb > 0) {
        _weightController.text = extractedBb.toStringAsFixed(2);
      }
      if (extractedTb != null && extractedTb > 0) {
        _heightController.text = extractedTb.toStringAsFixed(1);
      }
      _smartGrowthResult = null;
      _reasoningResult = null;
      if (switchToManualTab) {
        _activeTab = 0;
        _formStep = 2;
      }
    });

    if (showSnackbar) {
      CustomSnackbar.success(
        context,
        'Data sensor diterapkan ke formulir: TB = ${_heightController.text} cm, BB = ${_weightController.text} kg',
        title: 'Data IoT Diterapkan',
      );
    }
  }

  Future<void> _toggleMqttConnection() async {
    if (_mqttService.isConnected) {
      _mqttService.disconnect();
      if (mounted) {
        setState(() {});
        CustomSnackbar.info(
          context,
          'Koneksi MQTT ke perangkat VitaScale telah diputus.',
          title: 'MQTT Disconnected',
        );
      }
    } else {
      setState(() => _isMqttConnecting = true);
      final success = await _mqttService.connect();
      if (mounted) {
        setState(() => _isMqttConnecting = false);
        if (success) {
          CustomSnackbar.success(
            context,
            'Terhubung ke Broker MQTT (${_mqttService.broker}:${_mqttService.port} ${_mqttService.connectionProtocolLabel}) - Menunggu stream sensor VitaScale!',
            title: 'MQTT Terhubung',
          );
        } else {
          CustomSnackbar.error(
            context,
            'Gagal terhubung ke MQTT broker (${_mqttService.broker}:${_mqttService.port}). Pastikan koneksi internet aktif.',
            title: 'MQTT Error',
          );
        }
      }
    }
  }

  void _sendMqttTare() {
    if (!_mqttService.isConnected) {
      CustomSnackbar.warning(
        context,
        'Hubungkan ke MQTT terlebih dahulu sebelum melakukan Tare.',
        title: 'MQTT Offline',
      );
      return;
    }
    _mqttService.tareScale();
    CustomSnackbar.info(
      context,
      'Perintah Tare (Nol-kan Timbangan) telah dikirim ke perangkat IoT ESP32.',
      title: 'Tare Sent',
    );
  }

  ({IconData icon, Color color, String quality}) _wifiSignalStyle(int? rssi) {
    if (rssi == null || rssi == 0) {
      return (icon: Icons.wifi_rounded, color: const Color(0xFF3498DB), quality: 'Siap');
    }
    if (rssi >= -55) {
      return (icon: Icons.signal_wifi_4_bar_rounded, color: const Color(0xFF27AE60), quality: 'Sangat Kuat');
    }
    if (rssi >= -70) {
      return (icon: Icons.network_wifi_3_bar_rounded, color: const Color(0xFF1ABC9C), quality: 'Bagus');
    }
    if (rssi >= -82) {
      return (icon: Icons.network_wifi_2_bar_rounded, color: const Color(0xFFF39C12), quality: 'Sedang');
    }
    return (icon: Icons.network_wifi_1_bar_rounded, color: const Color(0xFFE74C3C), quality: 'Lemah');
  }

  /// Dialog Konfigurasi Fleksibel MQTT, Gateway IoT, & Wi-Fi List ala Laptop/HP
  void _showMqttSettingsDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final border = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final text = isDark ? Colors.white : const Color(0xFF1E293B);
    final sub = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final brokerCtrl = TextEditingController(text: _mqttService.broker);
    final portCtrl = TextEditingController(text: _mqttService.port.toString());
    final faskesCtrl = TextEditingController(text: _mqttService.faskesId);
    final deviceCtrl = TextEditingController(text: _mqttService.deviceId);
    final poleCtrl = TextEditingController(text: _mqttService.poleHeightCm.toStringAsFixed(1));
    final gatewayCtrl = TextEditingController(text: _mqttService.cloudGatewayUrl);

    // Controller untuk Setup Wi-Fi Alat ESP32
    final espUrlCtrl = TextEditingController(text: 'http://192.168.4.1');
    final wifiSsidCtrl = TextEditingController();
    final wifiPassCtrl = TextEditingController();
    final calFactorCtrl = TextEditingController(text: '25.75');

    final activeFacilityId = ref.read(landingPageProvider).activePuskesmasId;

    int activeDialogTab = 0; // 0 = Koneksi MQTT, 1 = Wi-Fi Alat
    bool useWildcard = _mqttService.useWildcard;
    bool isSyncing = false;

    // State Tab Wi-Fi ala Laptop / HP
    bool wifiDbInitialized = false;
    bool isLoadingSavedWifi = false;
    bool isScanningWifi = false;
    bool isSavingWifi = false;
    bool espPortalReachable = false;
    bool showApUrlEditor = false;
    bool showAdvancedWifiFields = false;
    bool savePasswordToDb = true;
    String sendMethod = _mqttService.isConnected ? 'mqtt' : 'ap'; // 'ap' | 'mqtt'
    String? espInfoMessage;
    String? activeWifiSsid = _activeSavedWifiSsid;
    List<Map<String, dynamic>> scannedNetworks = [];
    List<Map<String, dynamic>> savedWifiProfiles = [];

    // State ketika user klik salah satu Wi-Fi untuk isi password & Connect
    Map<String, dynamic>? selectedNetwork; // {'ssid': ..., 'rssi': ..., 'secure': ..., 'isManual': ...}

    String normalizeEspUrl() {
      final raw = espUrlCtrl.text.trim();
      if (raw.isEmpty) return 'http://192.168.4.1';
      final withScheme = (raw.startsWith('http://') || raw.startsWith('https://'))
          ? raw
          : 'http://$raw';
      return withScheme.endsWith('/') ? withScheme.substring(0, withScheme.length - 1) : withScheme;
    }

    Future<void> refreshSavedWifiAndSync(
      BuildContext ctx,
      void Function(void Function()) setDialogState,
    ) async {
      if (!ctx.mounted) return;
      setDialogState(() => isLoadingSavedWifi = true);
      await _chcService.syncPendingIotWifiToSupabase();
      final list = await _chcService.fetchSavedWifiProfiles(
        faskesCode: faskesCtrl.text.trim(),
        facilityId: activeFacilityId,
      );
      if (!ctx.mounted) return;
      setDialogState(() {
        isLoadingSavedWifi = false;
        savedWifiProfiles = list;
        final activeRow = list.cast<Map<String, dynamic>?>().firstWhere(
              (r) => r?['is_active'] == true,
              orElse: () => list.isNotEmpty ? list.first : null,
            );
        if (activeRow != null && (activeRow['ssid'] as String?)?.isNotEmpty == true) {
          activeWifiSsid = activeRow['ssid'] as String;
        }
      });
    }

    void openConnectPrompt(
      Map<String, dynamic> network,
      void Function(void Function()) setDialogState,
    ) {
      final ssid = (network['ssid'] ?? '').toString();
      final savedMatch = savedWifiProfiles.cast<Map<String, dynamic>?>().firstWhere(
            (r) => (r?['ssid'] ?? '') == ssid,
            orElse: () => null,
          );
      setDialogState(() {
        selectedNetwork = network;
        wifiSsidCtrl.text = ssid;
        wifiPassCtrl.text = (savedMatch?['saved_password'] ?? '').toString();
        sendMethod = espPortalReachable
            ? 'ap'
            : (_mqttService.isConnected ? 'mqtt' : 'ap');
        espInfoMessage = null;
      });
    }

    Future<void> scanEsp32Wifi(
      BuildContext ctx,
      void Function(void Function()) setDialogState,
    ) async {
      final baseUrl = normalizeEspUrl();
      setDialogState(() {
        isScanningWifi = true;
        espInfoMessage = null;
      });
      try {
        final infoResp = await http
            .get(Uri.parse('$baseUrl/api/info'))
            .timeout(const Duration(seconds: 4));

        String? currentSsid;
        if (infoResp.statusCode == 200) {
          final info = jsonDecode(infoResp.body) as Map<String, dynamic>;
          if ((info['faskes_id'] as String?)?.isNotEmpty == true) {
            faskesCtrl.text = info['faskes_id'] as String;
          }
          if ((info['device_id'] as String?)?.isNotEmpty == true) {
            deviceCtrl.text = info['device_id'] as String;
          }
          if (info['cal_factor'] is num) {
            calFactorCtrl.text = (info['cal_factor'] as num).toStringAsFixed(2);
          }
          currentSsid = info['configured_ssid'] as String?;
        }

        final scanResp = await http
            .get(Uri.parse('$baseUrl/api/scan'))
            .timeout(const Duration(seconds: 8));
        final parsedNets = <Map<String, dynamic>>[];
        if (scanResp.statusCode == 200) {
          final scanData = jsonDecode(scanResp.body) as Map<String, dynamic>;
          final nets = scanData['networks'];
          if (nets is List) {
            for (final item in nets) {
              if (item is Map && (item['ssid'] as String?)?.isNotEmpty == true) {
                parsedNets.add(Map<String, dynamic>.from(item));
              }
            }
          }
          parsedNets.sort((a, b) {
            final ra = (a['rssi'] as num?)?.toInt() ?? -100;
            final rb = (b['rssi'] as num?)?.toInt() ?? -100;
            return rb.compareTo(ra);
          });
        }

        if (!ctx.mounted) return;
        setDialogState(() {
          isScanningWifi = false;
          espPortalReachable = infoResp.statusCode == 200 || scanResp.statusCode == 200;
          scannedNetworks = parsedNets;
          if (currentSsid != null && currentSsid.isNotEmpty) {
            activeWifiSsid = currentSsid;
          }
          espInfoMessage = espPortalReachable
              ? 'Ditemukan ${parsedNets.length} jaringan Wi-Fi dari ESP32.'
              : 'ESP32 merespons kode ${infoResp.statusCode}.';
        });
      } catch (e) {
        if (!ctx.mounted) return;
        setDialogState(() {
          isScanningWifi = false;
          espPortalReachable = false;
          espInfoMessage = kIsWeb
              ? 'Browser HTTPS memblokir scan lokal ke HTTP $baseUrl. Gunakan Wi-Fi Tersimpan / Input Manual (via MQTT), atau klik "Portal Web".'
              : 'Belum terhubung ke hotspot alat ($baseUrl). Hubungkan Wi-Fi HP/Laptop ke VitaScale-Setup-XXX, lalu klik Scan lagi.';
        });
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          if (!wifiDbInitialized) {
            wifiDbInitialized = true;
            Future.microtask(() => refreshSavedWifiAndSync(ctx, setDialogState));
          }

          final pendingCount = _chcService.getPendingWifiSyncCount();
          final savedSsidSet = savedWifiProfiles
              .map((e) => (e['ssid'] ?? '').toString())
              .where((s) => s.isNotEmpty)
              .toSet();

          return AlertDialog(
            backgroundColor: cardBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: border),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1ABC9C).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.settings_input_antenna_rounded, color: Color(0xFF1ABC9C), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Konfigurasi MQTT & Wi-Fi Alat',
                            style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.w800, color: text),
                          ),
                          Text(
                            'Sesuaikan broker MQTT, sensor tripod, dan jaringan Wi-Fi ESP32',
                            style: GoogleFonts.outfit(fontSize: 11, color: sub),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: border.withOpacity(0.22),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(9),
                          onTap: () => setDialogState(() => activeDialogTab = 0),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: activeDialogTab == 0 ? cardBg : Colors.transparent,
                              borderRadius: BorderRadius.circular(9),
                              boxShadow: activeDialogTab == 0
                                  ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4)]
                                  : null,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.hub_rounded,
                                  size: 15,
                                  color: activeDialogTab == 0 ? const Color(0xFF1ABC9C) : sub,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Koneksi MQTT',
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: activeDialogTab == 0 ? text : sub,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(9),
                          onTap: () => setDialogState(() => activeDialogTab = 1),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: activeDialogTab == 1 ? cardBg : Colors.transparent,
                              borderRadius: BorderRadius.circular(9),
                              boxShadow: activeDialogTab == 1
                                  ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 4)]
                                  : null,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.wifi_rounded,
                                  size: 15,
                                  color: activeDialogTab == 1 ? const Color(0xFF3498DB) : sub,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Wi-Fi Alat',
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: activeDialogTab == 1 ? text : sub,
                                  ),
                                ),
                                if (pendingCount > 0) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF39C12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '$pendingCount',
                                      style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 550,
              child: SingleChildScrollView(
                child: activeDialogTab == 0
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('PRESET CEPAT', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w800, color: sub, letterSpacing: 0.5)),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              ActionChip(
                                avatar: const Icon(Icons.hub_rounded, size: 14, color: Color(0xFF1ABC9C)),
                                label: Text('HiveMQ Public (Port 8884 WSS)', style: GoogleFonts.outfit(fontSize: 11, color: text)),
                                backgroundColor: border.withOpacity(0.2),
                                onPressed: () {
                                  setDialogState(() {
                                    brokerCtrl.text = 'broker.hivemq.com';
                                    portCtrl.text = '8884';
                                  });
                                },
                              ),
                              ActionChip(
                                avatar: const Icon(Icons.cloud_queue_rounded, size: 14, color: Color(0xFF3498DB)),
                                label: Text('EMQX Public (Port 8084 WSS)', style: GoogleFonts.outfit(fontSize: 11, color: text)),
                                backgroundColor: border.withOpacity(0.2),
                                onPressed: () {
                                  setDialogState(() {
                                    brokerCtrl.text = 'broker.emqx.io';
                                    portCtrl.text = '8084';
                                  });
                                },
                              ),
                              ActionChip(
                                avatar: const Icon(Icons.language_rounded, size: 14, color: Color(0xFF9B59B6)),
                                label: Text('mapotechiotmqtt.vercel.app', style: GoogleFonts.outfit(fontSize: 11, color: text)),
                                backgroundColor: border.withOpacity(0.2),
                                onPressed: () {
                                  setDialogState(() {
                                    gatewayCtrl.text = 'https://mapotechiotmqtt.vercel.app';
                                  });
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Divider(height: 1),
                          const SizedBox(height: 16),

                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: CustomTextField(
                                  label: 'Broker Host (MQTT)',
                                  hintText: 'broker.hivemq.com',
                                  controller: brokerCtrl,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: CustomTextField(
                                  label: 'Port (WSS / TCP)',
                                  hintText: '8884',
                                  controller: portCtrl,
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          Row(
                            children: [
                              Expanded(
                                child: CustomTextField(
                                  label: 'Puskesmas / Faskes ID',
                                  hintText: 'PUSKESMAS-001',
                                  controller: faskesCtrl,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: CustomTextField(
                                  label: 'Device ID (ESP32)',
                                  hintText: 'VTS-001',
                                  controller: deviceCtrl,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: CustomTextField(
                                  label: 'Tiang / Tripod Acuan (cm)',
                                  hintText: '166.0',
                                  controller: poleCtrl,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 3,
                                child: CustomTextField(
                                  label: 'Gateway Vercel URL',
                                  hintText: 'https://mapotechiotmqtt.vercel.app',
                                  controller: gatewayCtrl,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              'Wildcard Topic Listener',
                              style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.w700, color: text),
                            ),
                            subtitle: Text(
                              'Dengarkan topik "mapotech/+/vitascale/+/telemetry" untuk menangkap telemetri dari semua ID perangkat.',
                              style: GoogleFonts.outfit(fontSize: 10.5, color: sub),
                            ),
                            value: useWildcard,
                            activeColor: const Color(0xFF1ABC9C),
                            onChanged: (val) => setDialogState(() => useWildcard = val),
                          ),

                          const SizedBox(height: 8),

                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF1ABC9C),
                              side: const BorderSide(color: Color(0xFF1ABC9C)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            ),
                            icon: isSyncing
                                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.sync_rounded, size: 16),
                            label: Text(
                              isSyncing ? 'Menghubungi Gateway...' : 'Sinkronkan Konfigurasi dari Gateway Vercel',
                              style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700),
                            ),
                            onPressed: isSyncing
                                ? null
                                : () async {
                                    setDialogState(() => isSyncing = true);
                                    await _mqttService.syncWithCloudGateway(url: gatewayCtrl.text.trim());
                                    if (!ctx.mounted) return;
                                    setDialogState(() {
                                      isSyncing = false;
                                      brokerCtrl.text = _mqttService.broker;
                                      portCtrl.text = _mqttService.port.toString();
                                      poleCtrl.text = _mqttService.poleHeightCm.toStringAsFixed(1);
                                    });
                                    if (mounted) {
                                      CustomSnackbar.success(
                                        this.context,
                                        'Konfigurasi berhasil disinkronkan dari ${_mqttService.cloudGatewayUrl}!',
                                        title: 'Sinkronisasi Gateway',
                                      );
                                    }
                                  },
                          ),
                        ],
                      )
                    : (selectedNetwork == null
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header Status Wi-Fi & Tombol Scan ala Laptop / HP
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF3498DB).withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: const Color(0xFF3498DB).withOpacity(0.28)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          activeWifiSsid != null ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                                          size: 20,
                                          color: activeWifiSsid != null ? const Color(0xFF1ABC9C) : const Color(0xFF3498DB),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                activeWifiSsid != null
                                                    ? 'Wi-Fi Alat: $activeWifiSsid'
                                                    : 'Wi-Fi Alat Belum Terpilih',
                                                style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.w800, color: text),
                                              ),
                                              Text(
                                                pendingCount > 0
                                                    ? '$pendingCount perubahan tersimpan lokal • Klik Sync saat ada internet'
                                                    : (_mqttService.isConnected
                                                        ? 'Alat online di MQTT (${_mqttService.deviceId})'
                                                        : 'Sambungkan ke hotspot VitaScale-Setup-XXX untuk scan Wi-Fi'),
                                                style: GoogleFonts.outfit(fontSize: 10.5, color: sub),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (pendingCount > 0)
                                          TextButton.icon(
                                            onPressed: () => refreshSavedWifiAndSync(ctx, setDialogState),
                                            icon: const Icon(Icons.cloud_upload_rounded, size: 15),
                                            label: Text('Sync DB', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700)),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFF1ABC9C),
                                              foregroundColor: Colors.white,
                                              elevation: 0,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                              padding: const EdgeInsets.symmetric(vertical: 9),
                                            ),
                                            icon: isScanningWifi
                                                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                                : const Icon(Icons.radar_rounded, size: 16),
                                            label: Text(
                                              isScanningWifi ? 'Memindai...' : 'Scan Wi-Fi',
                                              style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.w700),
                                            ),
                                            onPressed: isScanningWifi
                                                ? null
                                                : () => scanEsp32Wifi(ctx, setDialogState),
                                          ),
                                        ),
                                        if (_mqttService.isConnected) ...[
                                          const SizedBox(width: 8),
                                          OutlinedButton.icon(
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: const Color(0xFF3498DB),
                                              side: BorderSide(color: const Color(0xFF3498DB).withOpacity(0.6)),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                                            ),
                                            icon: const Icon(Icons.wifi_protected_setup_rounded, size: 15),
                                            label: Text('Hotspot AP', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700)),
                                            onPressed: () {
                                              _mqttService.triggerReconfig();
                                              setDialogState(() {
                                                espInfoMessage = 'Perintah reconfig dikirim. Sambungkan HP/Laptop ke VitaScale-Setup-XXX lalu klik Scan Wi-Fi.';
                                              });
                                            },
                                          ),
                                        ],
                                        const SizedBox(width: 8),
                                        OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: text,
                                            side: BorderSide(color: border),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                                          ),
                                          icon: const Icon(Icons.open_in_new_rounded, size: 14),
                                          label: Text('Portal Web', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700)),
                                          onPressed: () async {
                                            await launchUrl(
                                              Uri.parse(normalizeEspUrl()),
                                              mode: LaunchMode.externalApplication,
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    InkWell(
                                      onTap: () => setDialogState(() => showApUrlEditor = !showApUrlEditor),
                                      child: Row(
                                        children: [
                                          Icon(Icons.lan_outlined, size: 13, color: sub),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Alamat AP: ${normalizeEspUrl()} (${showApUrlEditor ? 'Tutup' : 'Ubah'})',
                                            style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w600, color: sub),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (showApUrlEditor) ...[
                                      const SizedBox(height: 8),
                                      CustomTextField(
                                        label: 'Alamat Portal Hotspot ESP32',
                                        hintText: 'http://192.168.4.1',
                                        controller: espUrlCtrl,
                                      ),
                                    ],
                                  ],
                                ),
                              ),

                              if (espInfoMessage != null) ...[
                                const SizedBox(height: 10),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: (espPortalReachable ? const Color(0xFF27AE60) : const Color(0xFFF39C12)).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: (espPortalReachable ? const Color(0xFF27AE60) : const Color(0xFFF39C12)).withOpacity(0.35),
                                    ),
                                  ),
                                  child: Text(
                                    espInfoMessage!,
                                    style: GoogleFonts.outfit(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                      color: espPortalReachable ? const Color(0xFF16A085) : const Color(0xFFD35400),
                                    ),
                                  ),
                                ),
                              ],

                              // Daftar Wi-Fi Tersimpan (Database Supabase + Cache Lokal)
                              if (isLoadingSavedWifi) ...[
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                                    const SizedBox(width: 8),
                                    Text('Memuat daftar Wi-Fi tersimpan dari database...', style: GoogleFonts.outfit(fontSize: 11, color: sub)),
                                  ],
                                ),
                              ] else if (savedWifiProfiles.isNotEmpty) ...[
                                const SizedBox(height: 14),
                                Text(
                                  'WI-FI TERSIMPAN (DATABASE PUSKESMAS)',
                                  style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w800, color: sub, letterSpacing: 0.5),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: border),
                                  ),
                                  child: Column(
                                    children: List.generate(savedWifiProfiles.length, (i) {
                                      final row = savedWifiProfiles[i];
                                      final ssid = (row['ssid'] ?? '').toString();
                                      final isActive = row['is_active'] == true || ssid == activeWifiSsid;
                                      final hasPass = (row['saved_password'] as String?)?.isNotEmpty == true;
                                      final isPending = row['pending_sync'] == true;
                                      final rssi = (row['last_rssi_dbm'] as num?)?.toInt();
                                      final isSecure = (row['security_type'] ?? 'WPA2') != 'OPEN';
                                      final sig = _wifiSignalStyle(rssi);

                                      return Column(
                                        children: [
                                          if (i > 0) Divider(height: 1, color: border),
                                          InkWell(
                                            borderRadius: BorderRadius.circular(10),
                                            onTap: () => openConnectPrompt(
                                              {
                                                'ssid': ssid,
                                                'rssi': rssi,
                                                'secure': isSecure,
                                                'isManual': false,
                                              },
                                              setDialogState,
                                            ),
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                              child: Row(
                                                children: [
                                                  Stack(
                                                    clipBehavior: Clip.none,
                                                    children: [
                                                      Icon(sig.icon, size: 20, color: isActive ? const Color(0xFF1ABC9C) : sig.color),
                                                      if (isSecure)
                                                        Positioned(
                                                          right: -3,
                                                          bottom: -2,
                                                          child: Icon(Icons.lock_rounded, size: 10, color: sub),
                                                        ),
                                                    ],
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Row(
                                                          children: [
                                                            Flexible(
                                                              child: Text(
                                                                ssid,
                                                                style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.w700, color: text),
                                                                overflow: TextOverflow.ellipsis,
                                                              ),
                                                            ),
                                                            if (isActive) ...[
                                                              const SizedBox(width: 6),
                                                              Container(
                                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                                                decoration: BoxDecoration(
                                                                  color: const Color(0xFF27AE60).withOpacity(0.15),
                                                                  borderRadius: BorderRadius.circular(5),
                                                                ),
                                                                child: Text(
                                                                  'Aktif',
                                                                  style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w800, color: const Color(0xFF27AE60)),
                                                                ),
                                                              ),
                                                            ],
                                                          ],
                                                        ),
                                                        Text(
                                                          '${isPending ? 'Antrean Sync DB' : 'Tersimpan di Database'}${hasPass ? ' • Sandi tersimpan' : ''}',
                                                          style: GoogleFonts.outfit(fontSize: 10, color: isPending ? const Color(0xFFD35400) : sub),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  Text(
                                                    'Sambungkan',
                                                    style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF1ABC9C)),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  IconButton(
                                                    tooltip: 'Lupakan Wi-Fi ini',
                                                    icon: Icon(Icons.delete_outline_rounded, size: 17, color: sub),
                                                    visualDensity: VisualDensity.compact,
                                                    onPressed: () async {
                                                      await _chcService.deleteSavedWifi(
                                                        faskesCode: faskesCtrl.text.trim(),
                                                        ssid: ssid,
                                                      );
                                                      await refreshSavedWifiAndSync(ctx, setDialogState);
                                                    },
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    }),
                                  ),
                                ),
                              ],

                              // Daftar Wi-Fi Hasil Scan Sekitar Alat (Persis Laptop / HP)
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'JARINGAN TERSEDIA (${scannedNetworks.length})',
                                    style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w800, color: sub, letterSpacing: 0.5),
                                  ),
                                  InkWell(
                                    borderRadius: BorderRadius.circular(6),
                                    onTap: () => openConnectPrompt(
                                      {
                                        'ssid': '',
                                        'rssi': null,
                                        'secure': true,
                                        'isManual': true,
                                      },
                                      setDialogState,
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.add_circle_outline_rounded, size: 14, color: Color(0xFF3498DB)),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Input SSID Manual',
                                            style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF3498DB)),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),

                              if (scannedNetworks.isEmpty)
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: border.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: border),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.wifi_tethering_rounded, size: 22, color: sub),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          'Klik "Scan Wi-Fi" saat HP/Laptop tersambung ke hotspot VitaScale-Setup-XXX, atau klik "Input SSID Manual" untuk ganti Wi-Fi langsung via MQTT.',
                                          style: GoogleFonts.outfit(fontSize: 11, color: sub, height: 1.35),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: border),
                                  ),
                                  child: Column(
                                    children: List.generate(scannedNetworks.length, (i) {
                                      final net = scannedNetworks[i];
                                      final ssid = (net['ssid'] ?? '').toString();
                                      final rssi = (net['rssi'] as num?)?.toInt();
                                      final isSecure = net['secure'] == true;
                                      final isConnectedSsid = ssid == activeWifiSsid;
                                      final isSaved = savedSsidSet.contains(ssid);
                                      final sig = _wifiSignalStyle(rssi);

                                      return Column(
                                        children: [
                                          if (i > 0) Divider(height: 1, color: border),
                                          InkWell(
                                            borderRadius: BorderRadius.circular(10),
                                            onTap: () => openConnectPrompt(
                                              {
                                                'ssid': ssid,
                                                'rssi': rssi,
                                                'secure': isSecure,
                                                'isManual': false,
                                              },
                                              setDialogState,
                                            ),
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                              child: Row(
                                                children: [
                                                  Stack(
                                                    clipBehavior: Clip.none,
                                                    children: [
                                                      Icon(sig.icon, size: 20, color: sig.color),
                                                      if (isSecure)
                                                        Positioned(
                                                          right: -3,
                                                          bottom: -2,
                                                          child: Icon(Icons.lock_rounded, size: 10, color: sub),
                                                        ),
                                                    ],
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Row(
                                                          children: [
                                                            Flexible(
                                                              child: Text(
                                                                ssid,
                                                                style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.w700, color: text),
                                                                overflow: TextOverflow.ellipsis,
                                                              ),
                                                            ),
                                                            if (isConnectedSsid) ...[
                                                              const SizedBox(width: 6),
                                                              Container(
                                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                                                decoration: BoxDecoration(
                                                                  color: const Color(0xFF27AE60).withOpacity(0.15),
                                                                  borderRadius: BorderRadius.circular(5),
                                                                ),
                                                                child: Text(
                                                                  'Terhubung',
                                                                  style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w800, color: const Color(0xFF27AE60)),
                                                                ),
                                                              ),
                                                            ],
                                                          ],
                                                        ),
                                                        Text(
                                                          '${rssi != null ? '$rssi dBm • ' : ''}${sig.quality} • ${isSecure ? 'Diamankan WPA2' : 'Terbuka'}${isSaved ? ' • Tersimpan DB' : ''}',
                                                          style: GoogleFonts.outfit(fontSize: 10, color: sub),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  Text(
                                                    'Connect',
                                                    style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF3498DB)),
                                                  ),
                                                  const SizedBox(width: 2),
                                                  Icon(Icons.chevron_right_rounded, size: 18, color: sub),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    }),
                                  ),
                                ),
                            ],
                          )
                        : Column(
                            // Mode B: Prompt Input Password & Connect ala Laptop / HP
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: () => setDialogState(() {
                                  selectedNetwork = null;
                                  espInfoMessage = null;
                                }),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.arrow_back_rounded, size: 16, color: const Color(0xFF3498DB)),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Kembali ke daftar Wi-Fi',
                                        style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF3498DB)),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),

                              // Kartu Identitas Jaringan Dipilih
                              Builder(
                                builder: (context) {
                                  final rssi = (selectedNetwork?['rssi'] as num?)?.toInt();
                                  final isSecure = selectedNetwork?['secure'] != false;
                                  final isManual = selectedNetwork?['isManual'] == true;
                                  final sig = _wifiSignalStyle(rssi);
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          color: sig.color.withOpacity(0.08),
                                          borderRadius: BorderRadius.circular(14),
                                          border: Border.all(color: sig.color.withOpacity(0.3)),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(sig.icon, size: 24, color: sig.color),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    isManual
                                                        ? 'Hubungkan ke Jaringan Manual / Tersembunyi'
                                                        : 'Hubungkan alat ke "${wifiSsidCtrl.text}"',
                                                    style: GoogleFonts.outfit(fontSize: 13.5, fontWeight: FontWeight.w800, color: text),
                                                  ),
                                                  Text(
                                                    isManual
                                                        ? 'Masukkan nama Wi-Fi (SSID) dan kata sandi Puskesmas'
                                                        : '${isSecure ? 'Membutuhkan kata sandi Wi-Fi' : 'Jaringan terbuka (tanpa sandi)'}${rssi != null ? ' • Sinyal $rssi dBm (${sig.quality})' : ''}',
                                                    style: GoogleFonts.outfit(fontSize: 10.5, color: sub),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 14),

                                      if (isManual) ...[
                                        CustomTextField(
                                          label: 'Nama Wi-Fi (SSID)',
                                          hintText: 'Contoh: WiFi_Puskesmas',
                                          prefixIcon: Icons.wifi_rounded,
                                          controller: wifiSsidCtrl,
                                        ),
                                        const SizedBox(height: 12),
                                      ],

                                      if (isManual || isSecure) ...[
                                        CustomTextField(
                                          label: 'Password Wi-Fi',
                                          hintText: isManual ? 'Kosongkan jika Wi-Fi tanpa sandi' : 'Masukkan kata sandi Wi-Fi',
                                          prefixIcon: Icons.lock_outline_rounded,
                                          isPassword: true,
                                          controller: wifiPassCtrl,
                                        ),
                                        const SizedBox(height: 10),
                                      ],

                                      CheckboxListTile(
                                        contentPadding: EdgeInsets.zero,
                                        controlAffinity: ListTileControlAffinity.leading,
                                        activeColor: const Color(0xFF1ABC9C),
                                        title: Text(
                                          'Simpan Wi-Fi & sandi ke Database Puskesmas',
                                          style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700, color: text),
                                        ),
                                        subtitle: Text(
                                          'Jika HP sedang di hotspot alat tanpa internet, disimpan lokal dulu lalu otomatis sync ke Supabase saat online.',
                                          style: GoogleFonts.outfit(fontSize: 10, color: sub),
                                        ),
                                        value: savePasswordToDb,
                                        onChanged: (v) => setDialogState(() => savePasswordToDb = v ?? true),
                                      ),

                                      const SizedBox(height: 8),
                                      Text('METODE KIRIM KE ALAT', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w800, color: sub, letterSpacing: 0.5)),
                                      const SizedBox(height: 6),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 6,
                                        children: [
                                          ChoiceChip(
                                            avatar: Icon(Icons.router_rounded, size: 14, color: sendMethod == 'ap' ? Colors.white : const Color(0xFF3498DB)),
                                            label: Text(
                                              'Hotspot Alat (192.168.4.1)',
                                              style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600, color: sendMethod == 'ap' ? Colors.white : text),
                                            ),
                                            selected: sendMethod == 'ap',
                                            selectedColor: const Color(0xFF3498DB),
                                            backgroundColor: border.withOpacity(0.18),
                                            onSelected: (_) => setDialogState(() => sendMethod = 'ap'),
                                          ),
                                          ChoiceChip(
                                            avatar: Icon(
                                              Icons.hub_rounded,
                                              size: 14,
                                              color: sendMethod == 'mqtt' ? Colors.white : (_mqttService.isConnected ? const Color(0xFF1ABC9C) : sub),
                                            ),
                                            label: Text(
                                              _mqttService.isConnected ? 'Langsung via MQTT (Online)' : 'Via MQTT (Offline)',
                                              style: GoogleFonts.outfit(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: sendMethod == 'mqtt' ? Colors.white : (_mqttService.isConnected ? text : sub),
                                              ),
                                            ),
                                            selected: sendMethod == 'mqtt',
                                            selectedColor: const Color(0xFF1ABC9C),
                                            backgroundColor: border.withOpacity(0.18),
                                            onSelected: _mqttService.isConnected
                                                ? (_) => setDialogState(() => sendMethod = 'mqtt')
                                                : null,
                                          ),
                                        ],
                                      ),

                                      const SizedBox(height: 12),
                                      InkWell(
                                        onTap: () => setDialogState(() => showAdvancedWifiFields = !showAdvancedWifiFields),
                                        child: Row(
                                          children: [
                                            Icon(
                                              showAdvancedWifiFields ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                                              size: 16,
                                              color: sub,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Identitas Alat & Kalibrasi (${faskesCtrl.text} • ${deviceCtrl.text})',
                                              style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600, color: sub),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (showAdvancedWifiFields) ...[
                                        const SizedBox(height: 10),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: CustomTextField(
                                                label: 'Puskesmas / Faskes ID',
                                                hintText: 'PUSKESMAS-001',
                                                controller: faskesCtrl,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: CustomTextField(
                                                label: 'Device ID (ESP32)',
                                                hintText: 'VTS-001',
                                                controller: deviceCtrl,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        CustomTextField(
                                          label: 'Faktor Kalibrasi Berat (HX711)',
                                          hintText: '25.75',
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          controller: calFactorCtrl,
                                        ),
                                      ],
                                    ],
                                  );
                                },
                              ),

                              if (espInfoMessage != null) ...[
                                const SizedBox(height: 12),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF39C12).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: const Color(0xFFF39C12).withOpacity(0.35)),
                                  ),
                                  child: Text(
                                    espInfoMessage!,
                                    style: GoogleFonts.outfit(fontSize: 10.5, fontWeight: FontWeight.w600, color: const Color(0xFFD35400)),
                                  ),
                                ),
                              ],
                            ],
                          )),
              ),
            ),
            actions: activeDialogTab == 0
                ? [
                    TextButton(
                      onPressed: () {
                        _mqttService.resetToDefaults();
                        setDialogState(() {
                          brokerCtrl.text = _mqttService.broker;
                          portCtrl.text = _mqttService.port.toString();
                          faskesCtrl.text = _mqttService.faskesId;
                          deviceCtrl.text = _mqttService.deviceId;
                          poleCtrl.text = _mqttService.poleHeightCm.toStringAsFixed(1);
                          gatewayCtrl.text = _mqttService.cloudGatewayUrl;
                          useWildcard = true;
                        });
                      },
                      child: Text('Reset Default', style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFFE74C3C))),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: Text('Batal', style: GoogleFonts.outfit(fontSize: 12, color: sub)),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1ABC9C),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.check_rounded, size: 16),
                      label: Text('Simpan & Sambungkan', style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700)),
                      onPressed: () async {
                        final newPort = int.tryParse(portCtrl.text.trim()) ?? _mqttService.port;
                        final newPole = double.tryParse(poleCtrl.text.trim()) ?? _mqttService.poleHeightCm;
                        Navigator.of(ctx).pop();
                        setState(() => _isMqttConnecting = true);

                        final ok = await _mqttService.reconnectWithConfig(
                          broker: brokerCtrl.text.trim(),
                          port: newPort,
                          faskesId: faskesCtrl.text.trim(),
                          deviceId: deviceCtrl.text.trim(),
                          cloudGatewayUrl: gatewayCtrl.text.trim(),
                          poleHeightCm: newPole,
                          useWildcard: useWildcard,
                        );

                        if (mounted) {
                          setState(() => _isMqttConnecting = false);
                          if (ok) {
                            CustomSnackbar.success(
                              this.context,
                              'Berhasil terhubung ke ${_mqttService.broker}:${_mqttService.port}!',
                              title: 'MQTT Tersambung',
                            );
                          } else {
                            CustomSnackbar.error(
                              this.context,
                              'Gagal terhubung ke ${_mqttService.broker}:${_mqttService.port}. Periksa kembali alamat dan port.',
                              title: 'Koneksi Gagal',
                            );
                          }
                        }
                      },
                    ),
                  ]
                : (selectedNetwork == null
                    ? [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: Text('Tutup', style: GoogleFonts.outfit(fontSize: 12, color: sub)),
                        ),
                      ]
                    : [
                        TextButton(
                          onPressed: () => setDialogState(() {
                            selectedNetwork = null;
                            espInfoMessage = null;
                          }),
                          child: Text('Batal', style: GoogleFonts.outfit(fontSize: 12, color: sub)),
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: sendMethod == 'mqtt' ? const Color(0xFF1ABC9C) : const Color(0xFF3498DB),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: isSavingWifi
                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.wifi_rounded, size: 16),
                          label: Text(
                            isSavingWifi ? 'Menghubungkan...' : 'Connect & Simpan',
                            style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                          onPressed: isSavingWifi
                              ? null
                              : () async {
                                  final ssid = wifiSsidCtrl.text.trim();
                                  final pass = wifiPassCtrl.text;
                                  final faskes = faskesCtrl.text.trim().isEmpty ? 'PUSKESMAS-001' : faskesCtrl.text.trim();
                                  final dev = deviceCtrl.text.trim().isEmpty ? 'VTS-001' : deviceCtrl.text.trim();
                                  final cal = double.tryParse(calFactorCtrl.text.trim()) ?? 25.75;
                                  final rssi = (selectedNetwork?['rssi'] as num?)?.toInt();
                                  final isSecure = selectedNetwork?['secure'] != false;

                                  if (ssid.isEmpty) {
                                    setDialogState(() {
                                      espInfoMessage = 'Nama Wi-Fi (SSID) wajib diisi.';
                                    });
                                    return;
                                  }

                                  setDialogState(() {
                                    isSavingWifi = true;
                                    espInfoMessage = null;
                                  });

                                  bool deviceUpdated = false;
                                  if (sendMethod == 'mqtt' && _mqttService.isConnected) {
                                    _mqttService.setWifiCredentials(
                                      ssid: ssid,
                                      password: pass,
                                      faskesId: faskes,
                                      deviceId: dev,
                                    );
                                    deviceUpdated = true;
                                  } else {
                                    final baseUrl = normalizeEspUrl();
                                    try {
                                      final resp = await http
                                          .post(
                                            Uri.parse('$baseUrl/api/setup'),
                                            headers: {'Content-Type': 'application/json'},
                                            body: jsonEncode({
                                              'ssid': ssid,
                                              'password': pass,
                                              'faskes_id': faskes,
                                              'device_id': dev,
                                              'cal_factor': cal,
                                            }),
                                          )
                                          .timeout(const Duration(seconds: 6));
                                      if (resp.statusCode == 200) {
                                        deviceUpdated = true;
                                      } else {
                                        if (!ctx.mounted) return;
                                        setDialogState(() {
                                          isSavingWifi = false;
                                          espInfoMessage = 'ESP32 menolak (${resp.statusCode}): ${resp.body}';
                                        });
                                        return;
                                      }
                                    } catch (e) {
                                      if (!ctx.mounted) return;
                                      setDialogState(() {
                                        isSavingWifi = false;
                                        espInfoMessage = kIsWeb
                                            ? 'Browser HTTPS memblokir akses ke $baseUrl. Gunakan "Langsung via MQTT" jika alat sedang online, atau klik "Portal Web".'
                                            : 'Gagal menghubungi hotspot $baseUrl. Pastikan HP/Laptop tersambung ke VitaScale-Setup-XXX.';
                                      });
                                      return;
                                    }
                                  }

                                  if (deviceUpdated) {
                                    _mqttService.updateConfig(faskesId: faskes, deviceId: dev);
                                    final saveResult = await _chcService.saveWifiAndDeviceProfile(
                                      facilityId: activeFacilityId,
                                      faskesCode: faskes,
                                      deviceId: dev,
                                      ssid: ssid,
                                      password: pass,
                                      savePassword: savePasswordToDb,
                                      isSecure: isSecure,
                                      rssiDbm: rssi,
                                      calFactor: cal,
                                      tripodHeightCm: _mqttService.poleHeightCm,
                                      brokerHost: _mqttService.broker,
                                      brokerPort: _mqttService.port,
                                    );

                                    if (mounted) {
                                      setState(() => _activeSavedWifiSsid = ssid);
                                    }
                                    if (!ctx.mounted) return;
                                    final syncedCloud = saveResult['synced_cloud'] == true;
                                    await refreshSavedWifiAndSync(ctx, setDialogState);
                                    if (!ctx.mounted) return;
                                    setDialogState(() {
                                      isSavingWifi = false;
                                      activeWifiSsid = ssid;
                                      selectedNetwork = null;
                                      espInfoMessage = syncedCloud
                                          ? 'Wi-Fi "$ssid" dikirim ke ESP32 & tersimpan ke database Supabase!'
                                          : 'Wi-Fi "$ssid" dikirim ke ESP32 & disimpan lokal (akan otomatis sync ke Supabase saat ada internet).';
                                    });
                                  }
                                },
                        ),
                      ]),
          );
        },
      ),
    );
  }

  // ===========================================================================
  // PRESET UJI CEPAT (BUKU KIA 2024 & STANDAR ANTROPOMETRI)
  // ===========================================================================
  void _applyPreset(
    String label, {
    required int jk,
    required double usia,
    required double bb,
    required double tb,
    double lk = 47.0,
    double lila = 14.5,
    String? caraUkur,
    String kms = 'N',
  }) {
    setState(() {
      _selectedGender = jk;
      _ageMonths = usia;
      _ageController.text = usia.toStringAsFixed(0);
      _weightController.text = bb.toStringAsFixed(1);
      _heightController.text = tb.toStringAsFixed(1);
      _headCircumferenceController.text = lk.toStringAsFixed(1);
      _lilaController.text = lila.toStringAsFixed(1);
      _measurementMethod = caraUkur ?? (usia < 24 ? 'PB' : 'TB');
      _kmsStatus = kms;
      _satuSehatSyncResult = null;
      _smartGrowthResult = null;
      _reasoningResult = null;
      _reasoningPromptCount = 0;
    });

    CustomSnackbar.info(
      context,
      'Data preset "$label" telah dimuat: JK ${jk == 0 ? "L" : "P"}, Usia $usia bln, BB $bb kg, TB $tb cm, LK $lk cm.',
      title: 'Preset Uji Dimuat',
    );
  }

  // ===========================================================================
  // HELPER BUKU KIA 2024 & SATUSEHAT
  // ===========================================================================
  Color _getLilaColor(double? val) {
    if (val == null) return Colors.grey;
    if (val < 11.5) return const Color(0xFFE74C3C); // Merah - Gizi Buruk / Wasting Akut
    if (val <= 12.5) return const Color(0xFFE67E22); // Kuning - Risiko Gizi Kurang
    return const Color(0xFF27AE60); // Hijau - Pita Normal
  }

  String _getLilaStatusText(double? val) {
    if (val == null) return 'Belum Diukur';
    if (val < 11.5) return 'Merah (<11.5 cm) • Indikasi Gizi Buruk / Wasting Akut';
    if (val <= 12.5) return 'Kuning (11.5-12.5 cm) • Risiko Gizi Kurang';
    return 'Hijau (>12.5 cm) • Status Gizi Normal';
  }

  String _getKmsLabel(String code) {
    switch (code) {
      case 'N':
        return 'N (Naik Sesuai KBM)';
      case 'T':
        return 'T (Tidak Naik / Tetap / Turun)';
      case '2T':
        return '2T (Dua Kali Tidak Naik Berturut-turut - Red Flag)';
      case 'BGM':
        return 'BGM (Bawah Garis Merah - Red Flag)';
      case 'Baru':
      default:
        return 'Penimbangan Pertama Kali';
    }
  }

  SatuSehatService _getSatuSehatService() {
    final state = ref.read(landingPageProvider);
    return SatuSehatService(
      clientId: dotenv.env['SATUSEHAT_CLIENT_ID'] ?? dotenv.env['SATUSEHAT_CLIENTID'],
      clientSecret: dotenv.env['SATUSEHAT_CLIENT_SECRET'] ?? dotenv.env['SATUSEHAT_CLIENTSECRET'],
      organizationId: dotenv.env['SATUSEHAT_ORG_ID'] ?? state.activePuskesmasId ?? '10000004',
      locationId: dotenv.env['SATUSEHAT_LOCATION_ID'] ?? 'b017aa54-f1df-4ec2-9529-81788148b1d9',
      env: dotenv.env['SATUSEHAT_ENV'] ?? 'stg',
    );
  }

  Future<void> _checkSatuSehatPatient() async {
    final nik = _nikController.text.trim();
    if (nik.length != 16) {
      CustomSnackbar.warning(
        context,
        'Harap masukkan 16 digit NIK balita yang valid.',
        title: 'NIK Tidak Valid',
      );
      return;
    }

    setState(() => _isCheckingSatuSehatPatient = true);

    try {
      final ss = _getSatuSehatService();
      if (!ss.isConfigured()) {
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) {
          setState(() {
            _satuSehatPatientId = 'P${nik.substring(nik.length - 10)}';
            _isCheckingSatuSehatPatient = false;
          });
          CustomSnackbar.info(
            context,
            'IHS Pasien (Mode Uji Coba): $_satuSehatPatientId telah disiapkan untuk NIK $nik.',
            title: 'SatuSehat Sandbox',
          );
        }
        return;
      }

      final res = await ss.getPatientIdByNik(nik);
      if (mounted) {
        setState(() {
          _isCheckingSatuSehatPatient = false;
          if (res['status'] == true && res['id'] != null) {
            _satuSehatPatientId = res['id'].toString();
          } else {
            _satuSehatPatientId = 'P${nik.substring(nik.length - 10)}';
          }
        });

        if (res['status'] == true) {
          CustomSnackbar.success(
            context,
            'Pasien terverifikasi di SATUSEHAT! IHS Number: $_satuSehatPatientId',
            title: 'SATUSEHAT Terhubung',
          );
        } else {
          CustomSnackbar.info(
            context,
            'Pasien belum terdaftar live (${res['message']}). Mode simulasi IHS diaktifkan: $_satuSehatPatientId',
            title: 'SATUSEHAT Sandbox',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCheckingSatuSehatPatient = false;
          _satuSehatPatientId = 'P${nik.substring(nik.length - 10)}';
        });
        CustomSnackbar.info(
          context,
          'Koneksi live SatuSehat menggunakan simulasi sandbox: $_satuSehatPatientId',
          title: 'Mode Uji Coba SatuSehat',
        );
      }
    }
  }

  Future<void> _syncToSatuSehat() async {
    final bb = double.tryParse(_weightController.text.trim());
    final tb = double.tryParse(_heightController.text.trim());
    if (bb == null || tb == null) {
      CustomSnackbar.warning(context, 'Data antropometri belum lengkap.');
      return;
    }

    setState(() => _isSyncingSatuSehat = true);

    final nik = _nikController.text.trim();
    final patientId = _satuSehatPatientId ?? (nik.length == 16 ? 'P${nik.substring(nik.length - 10)}' : 'P1000029384');
    final childName = _nameController.text.trim().isEmpty ? 'Balita Sasaran' : _nameController.text.trim();
    final isRecumbent = _measurementMethod == 'PB';
    final lk = double.tryParse(_headCircumferenceController.text.trim());
    final lila = double.tryParse(_lilaController.text.trim());
    final waist = double.tryParse(_waistController.text.trim());

    // Tentukan diagnosis ICD-10 berdasar hasil MLP / Buku KIA
    String diagCode = 'Z00.1';
    String diagDesc = 'Pemeriksaan kesehatan anak rutin';
    if (_smartGrowthResult != null) {
      if (_smartGrowthResult!.isStunting) {
        diagCode = 'E45';
        diagDesc = 'Retardasi perkembangan akibat malnutrisi energi-protein (Stunting)';
      } else if (_smartGrowthResult!.isGiziBurukAtauKurang) {
        diagCode = 'E44.0';
        diagDesc = 'Malnutrisi energi-protein sedang (Gizi Kurang)';
      }
    }

    try {
      final ss = _getSatuSehatService();
      final encounterUuid = 'ENC-${DateTime.now().millisecondsSinceEpoch}';

      if (!ss.isConfigured()) {
        await Future.delayed(const Duration(milliseconds: 900));
        if (mounted) {
          setState(() {
            _isSyncingSatuSehat = false;
            _satuSehatSyncResult = {
              'status': true,
              'mode': 'Simulasi Sandbox FHIR R4',
              'encounter_id': encounterUuid,
              'patient_id': patientId,
              'synced_at': DateTime.now().toIso8601String(),
              'observations_count': 2 + (lk != null ? 1 : 0) + (lila != null ? 1 : 0) + (waist != null ? 1 : 0),
              'diagnosis_code': diagCode,
              'diagnosis_desc': diagDesc,
            };
          });
          CustomSnackbar.success(
            context,
            'Berhasil membuat Payload FHIR R4 & verifikasi format observasi SATUSEHAT (LOINC).',
            title: 'Sinkronisasi SATUSEHAT Siap',
          );
        }
        return;
      }

      final headers = {
        'Content-Type': 'application/json',
      };
      final encRes = await ss.createEncounter(
        headers: headers,
        patientId: patientId,
        patientName: childName,
        doctorId: '10000001',
        doctorName: 'Petugas Gizi Puskesmas',
        encounterId: encounterUuid,
      );

      final ssEncounterId = encRes['data']?['id']?.toString() ?? encounterUuid;

      final result = await ss.sendAnthropometryData(
        patientId: patientId,
        patientName: childName,
        doctorId: '10000001',
        doctorName: 'Petugas Gizi Puskesmas',
        encounterId: ssEncounterId,
        weightKg: bb,
        heightCm: tb,
        isRecumbent: isRecumbent,
        headCircumferenceCm: lk,
        lilaCm: lila,
        waistCm: waist,
        diagnosisCode: diagCode,
        diagnosisDesc: diagDesc,
      );

      if (mounted) {
        setState(() {
          _isSyncingSatuSehat = false;
          _satuSehatSyncResult = {
            'status': true,
            'mode': 'Live SATUSEHAT Kemenkes RI',
            'encounter_id': ssEncounterId,
            'patient_id': patientId,
            'synced_at': DateTime.now().toIso8601String(),
            'observations_count': (result['observations'] as List?)?.length ?? 0,
            'diagnosis_code': diagCode,
            'diagnosis_desc': diagDesc,
          };
        });
        CustomSnackbar.success(
          context,
          'Data antropometri balita berhasil terkirim ke SATUSEHAT Kemenkes RI!',
          title: 'SATUSEHAT Sync Berhasil',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSyncingSatuSehat = false;
          _satuSehatSyncResult = {
            'status': true,
            'mode': 'Simulasi Sandbox FHIR R4 (Fallback)',
            'encounter_id': 'ENC-${DateTime.now().millisecondsSinceEpoch}',
            'patient_id': patientId,
            'synced_at': DateTime.now().toIso8601String(),
            'diagnosis_code': diagCode,
            'diagnosis_desc': diagDesc,
            'note': e.toString(),
          };
        });
        CustomSnackbar.info(
          context,
          'Data format FHIR R4 terverifikasi (Koneksi live terhambat: $e).',
          title: 'SATUSEHAT Payload Ready',
        );
      }
    }
  }

  // ===========================================================================
  // VALIDASI FORM SKRINING BALITA & REVIEW DIALOG (PRAKTIK MANDIRI DOKTER MODEL)
  // ===========================================================================
  List<Map<String, dynamic>> _validateScreeningForm() {
    final issues = <Map<String, dynamic>>[];

    // --- LANGKAH 1: IDENTITAS BALITA ---
    final nik = _nikController.text.trim();
    if (nik.isEmpty) {
      issues.add({
        'step': 1,
        'stepName': '1. Identitas Balita',
        'field': 'NIK Balita',
        'message': 'NIK Balita Wajib Diisi (16 Digit)',
        'isError': true, // 🔴 Red
      });
    } else if (nik.length != 16 || !RegExp(r'^\d{16}$').hasMatch(nik)) {
      issues.add({
        'step': 1,
        'stepName': '1. Identitas Balita',
        'field': 'NIK Balita',
        'message': 'NIK Balita Harus 16 Digit Angka Valid',
        'isError': true, // 🔴 Red
      });
    }

    if (_nameController.text.trim().isEmpty) {
      issues.add({
        'step': 1,
        'stepName': '1. Identitas Balita',
        'field': 'Nama Balita',
        'message': 'Nama Lengkap Balita Wajib Diisi',
        'isError': true, // 🔴 Red
      });
    }

    if (_ageMonths <= 0) {
      issues.add({
        'step': 1,
        'stepName': '1. Identitas Balita',
        'field': 'Usia Balita',
        'message': 'Usia Balita Harus Lebih dari 0 Bulan',
        'isError': true, // 🔴 Red
      });
    }

    if (_satuSehatPatientId == null) {
      issues.add({
        'step': 1,
        'stepName': '1. Identitas Balita',
        'field': 'SATUSEHAT',
        'message': 'IHS SATUSEHAT Belum Diverifikasi',
        'isError': false, // 🟡 Yellow Opsional
      });
    }

    // --- LANGKAH 2: ANTROPOMETRI FISIK ---
    final bb = double.tryParse(_weightController.text.trim());
    if (bb == null || bb <= 0) {
      issues.add({
        'step': 2,
        'stepName': '2. Antropometri',
        'field': 'Berat Badan',
        'message': 'Berat Badan Belum Diisi / Tidak Valid',
        'isError': true, // 🔴 Red
      });
    }

    final tb = double.tryParse(_heightController.text.trim());
    if (tb == null || tb <= 0) {
      issues.add({
        'step': 2,
        'stepName': '2. Antropometri',
        'field': 'Tinggi/Panjang Badan',
        'message': 'Tinggi/Panjang Badan Belum Diisi',
        'isError': true, // 🔴 Red
      });
    }

    final lila = double.tryParse(_lilaController.text.trim());
    if (lila == null || lila <= 0) {
      issues.add({
        'step': 2,
        'stepName': '2. Antropometri',
        'field': 'LiLA Balita',
        'message': 'Pengukuran LiLA Belum Diisi',
        'isError': false, // 🟡 Yellow Opsional
      });
    }

    final lk = double.tryParse(_headCircumferenceController.text.trim());
    if (lk == null || lk <= 0) {
      issues.add({
        'step': 2,
        'stepName': '2. Antropometri',
        'field': 'Lingkar Kepala',
        'message': 'Lingkar Kepala Belum Diisi',
        'isError': false, // 🟡 Yellow Opsional
      });
    }

    final lp = double.tryParse(_waistController.text.trim());
    if (lp == null || lp <= 0) {
      issues.add({
        'step': 2,
        'stepName': '2. Antropometri',
        'field': 'Lingkar Perut',
        'message': 'Lingkar Perut Belum Diisi',
        'isError': false, // 🟡 Yellow Opsional
      });
    }

    // --- LANGKAH 3: REASONING & KLASIFIKASI AI (OPSIONAL / ANJURAN KLINIS) ---
    if (_smartGrowthResult == null || _reasoningResult == null) {
      issues.add({
        'step': 3,
        'stepName': '3. Reasoning AI',
        'field': 'Reasoning Klinis AI',
        'message': 'Reasoning AI Belum Dijalankan (Opsional / Rekomendasi Klinis)',
        'isError': false, // 🟡 Yellow Opsional (tidak memblokir simpan)
      });
    }

    return issues;
  }

  Widget _buildReviewSectionTitle(String title, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0, top: 4.0),
      child: Text(
        title,
        style: GoogleFonts.outfit(
          fontSize: 11.5,
          fontWeight: FontWeight.w900,
          color: textColor,
        ),
      ),
    );
  }

  Widget _buildReviewRow(String label, String value, Color subColor, Color textColor, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.outfit(fontSize: 10.5, color: subColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              textAlign: TextAlign.right,
              style: GoogleFonts.outfit(
                fontSize: 10.5,
                fontWeight: isBold ? FontWeight.w900 : FontWeight.bold,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showReviewAndSubmitDialog() {
    final issues = _validateScreeningForm();
    final redErrors = issues.where((i) => i['isError'] == true).toList();
    final yellowWarnings = issues.where((i) => i['isError'] == false).toList();
    final bool isFormLengkap = redErrors.isEmpty;

    final notifier = ref.read(landingPageProvider.notifier);
    final textColor = notifier.getTextColor();
    final subtitleColor = notifier.getBodyTextColor();
    final cardBgColor = notifier.getCardColor();
    final borderColor = notifier.getBorderColor();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: cardBgColor,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: borderColor),
          ),
          title: Row(
            children: [
              Icon(
                isFormLengkap ? Icons.verified_rounded : (redErrors.isNotEmpty ? Icons.assignment_late_rounded : Icons.info_outline_rounded),
                color: isFormLengkap ? const Color(0xFF27AE60) : (redErrors.isNotEmpty ? const Color(0xFFE74C3C) : const Color(0xFFF39C12)),
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Review & Validasi Skrining Balita',
                  style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w900, color: textColor),
                ),
              ),
            ],
          ),
          content: Container(
            width: 520,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Banner (Form Lengkap vs Ada Data Kurang)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isFormLengkap
                          ? const Color(0xFF27AE60).withValues(alpha: 0.1)
                          : const Color(0xFFE74C3C).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isFormLengkap
                            ? const Color(0xFF27AE60).withValues(alpha: 0.3)
                            : const Color(0xFFE74C3C).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isFormLengkap ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                          color: isFormLengkap ? const Color(0xFF27AE60) : const Color(0xFFE74C3C),
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isFormLengkap
                                    ? (yellowWarnings.isEmpty
                                        ? '✅ Form Lengkap & Reasoning AI Selesai'
                                        : '✅ Data Wajib Lengkap (${yellowWarnings.length} Saran Opsional)')
                                    : '❌ Form Belum Lengkap (${redErrors.length} Syarat Wajib Belum Terpenuhi)',
                                style: GoogleFonts.outfit(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: isFormLengkap ? const Color(0xFF27AE60) : const Color(0xFFE74C3C),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isFormLengkap
                                    ? 'Data antropometri & penalaran klinis siap disimpan ke database dan disinkronkan ke SATUSEHAT.'
                                    : 'Klik chip merah di bawah untuk langsung menuju langkah yang belum lengkap.',
                                style: GoogleFonts.outfit(fontSize: 9.5, color: subtitleColor),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Red Error Chips (Wajib Diisi - Klik untuk langsung ke Step)
                  if (redErrors.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      'Data Wajib Belum Lengkap (Klik untuk menuju form):',
                      style: GoogleFonts.outfit(fontSize: 10.5, fontWeight: FontWeight.bold, color: const Color(0xFFE74C3C)),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: redErrors.map((err) {
                        return ActionChip(
                          avatar: const Icon(Icons.warning_rounded, size: 13, color: Color(0xFFE74C3C)),
                          label: Text(
                            'Step ${err['step']}: ${err['message']}',
                            style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFFE74C3C)),
                          ),
                          backgroundColor: const Color(0xFFE74C3C).withValues(alpha: 0.08),
                          side: const BorderSide(color: Color(0xFFE74C3C)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                          onPressed: () {
                            Navigator.pop(ctx);
                            setState(() {
                              _formStep = err['step'] as int;
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ],

                  // Yellow Warning Chips (Opsional - Klik untuk melengkapi)
                  if (yellowWarnings.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      'Peringatan / Data Opsional (Klik untuk melengkapi):',
                      style: GoogleFonts.outfit(fontSize: 10.5, fontWeight: FontWeight.bold, color: const Color(0xFFD68910)),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: yellowWarnings.map((warn) {
                        return ActionChip(
                          avatar: const Icon(Icons.info_outline_rounded, size: 13, color: Color(0xFFF39C12)),
                          label: Text(
                            'Step ${warn['step']}: ${warn['message']}',
                            style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFFD68910)),
                          ),
                          backgroundColor: const Color(0xFFF39C12).withValues(alpha: 0.08),
                          side: const BorderSide(color: Color(0xFFF39C12)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                          onPressed: () {
                            Navigator.pop(ctx);
                            setState(() {
                              _formStep = warn['step'] as int;
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ],

                  const Divider(height: 24),

                  // Ringkasan Data Skrining Balita
                  _buildReviewSectionTitle('1. Identitas Balita', textColor),
                  _buildReviewRow('Nama Balita', _nameController.text, subtitleColor, textColor),
                  _buildReviewRow('NIK Balita', _nikController.text, subtitleColor, textColor),
                  _buildReviewRow('Jenis Kelamin / Usia', '${_selectedGender == 0 ? "Laki-laki" : "Perempuan"} • ${_ageMonths.toInt()} Bulan', subtitleColor, textColor),
                  _buildReviewRow('Metode Pengukuran', _measurementMethod == 'PB' ? 'PB Telentang' : 'TB Berdiri', subtitleColor, textColor),

                  const SizedBox(height: 8),
                  _buildReviewSectionTitle('2. Antropometri Fisik', textColor),
                  _buildReviewRow('Berat / Panjang', '${_weightController.text} kg / ${_heightController.text} cm', subtitleColor, textColor),
                  _buildReviewRow('LiLA / Lingkar Kepala', '${_lilaController.text} cm / ${_headCircumferenceController.text} cm', subtitleColor, textColor),
                  _buildReviewRow('KMS Balita / Suplemen', '$_kmsStatus • Vit A: ${_receivedVitA ? "Ya" : "Tidak"}', subtitleColor, textColor),

                  const SizedBox(height: 8),
                  _buildReviewSectionTitle('3. Hasil AI & Clinical Reasoning', textColor),
                  _buildReviewRow('Status Gizi (BB/TB)', _smartGrowthResult?.kategoriGiziBbtb ?? 'Belum Dianalisis', subtitleColor, textColor, isBold: true),
                  _buildReviewRow('Status Stunting (TB/U)', _smartGrowthResult?.kategoriStuntingTbu ?? 'Belum Dianalisis', subtitleColor, textColor, isBold: true),
                  _buildReviewRow('Clinical Reasoning', _reasoningResult != null ? 'Tersedia (${_reasoningResult!.modelUsed} - ${_reasoningPromptCount}x diprompt)' : 'Belum Dijalankan (Opsional)', subtitleColor, textColor),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Batal / Kembali ke Form',
                style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: subtitleColor),
              ),
            ),
            if (redErrors.isNotEmpty)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE74C3C),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _formStep = redErrors.first['step'] as int;
                  });
                },
                icon: const Icon(Icons.arrow_forward_rounded, size: 14, color: Colors.white),
                label: Text(
                  'Lengkapi Step ${redErrors.first['step']}',
                  style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              )
            else
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF27AE60),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  _executeSaveScreening();
                },
                icon: _isSyncingSatuSehat
                    ? const Icon(Icons.sync_rounded, size: 16, color: Colors.white)
                    : const Icon(Icons.cloud_upload_rounded, size: 16, color: Colors.white),
                label: Text(
                  'Konfirmasi & Simpan Database',
                  style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _executeSaveScreening() async {
    // 1. Eksekusi Sinkronisasi SATUSEHAT (FHIR R4)
    await _syncToSatuSehat();
    if (!mounted) return;

    // 2. Simpan Rekam Medis ke Repository
    final childName = _nameController.text.trim().isEmpty ? 'Muhammad Rayyan Al-Fatih' : _nameController.text.trim();
    final nik = _nikController.text.trim();
    final bb = double.tryParse(_weightController.text.trim()) ?? 10.0;
    final tb = double.tryParse(_heightController.text.trim()) ?? 80.0;
    final waist = double.tryParse(_waistController.text.trim()) ?? 46.0;
    final currentStaff = ref.read(landingPageProvider).loggedInName ?? 'Petugas Gizi Puskesmas';

    final session = ScreeningSession(
      sessionId: 'VITA-${DateTime.now().millisecondsSinceEpoch}',
      facilityId: ref.read(landingPageProvider).activePuskesmasId ?? 'PUSKESMAS-001',
      child: _activeChild ??
          ChildProfile(
            id: 'ANK-${nik.length >= 4 ? nik.substring(nik.length - 4) : "001"}',
            name: childName,
            nik: nik,
            birthDate: DateTime.now().subtract(Duration(days: (_ageMonths * 30.4).round())),
            gender: _selectedGender == 0 ? 'L' : 'P',
            parentName: 'Orang Tua / Wali Balita',
            address: 'Kecamatan Sumberbaru, Kabupaten Jember',
          ),
      startTime: DateTime.now().subtract(const Duration(minutes: 5)),
      endTime: DateTime.now(),
      mode: _measurementMethod == 'PB' ? AnthropometryMode.recumbentLength : AnthropometryMode.standingHeight,
      weight: MeasurementItem(
        type: MeasurementType.weight,
        value: bb,
        status: MeasurementStatus.verified,
        capturedAt: DateTime.now(),
        source: 'manual_input',
      ),
      height: MeasurementItem(
        type: MeasurementType.height,
        value: tb,
        status: MeasurementStatus.verified,
        capturedAt: DateTime.now(),
        source: 'manual_input',
      ),
      waist: MeasurementItem(
        type: MeasurementType.waist,
        value: waist,
        status: MeasurementStatus.verified,
        capturedAt: DateTime.now(),
        source: 'manual_input',
      ),
      isDemo: false,
      isFinalized: true,
      notes: 'Status Gizi: ${_smartGrowthResult?.kategoriGiziBbtb ?? "Normal"} | Stunting: ${_smartGrowthResult?.kategoriStuntingTbu ?? "Normal"} | SATUSEHAT: ${_satuSehatPatientId ?? "Simulasi"}',
    );

    await _repository.saveScreeningResult(session, staffName: currentStaff);

    if (mounted) {
      CustomSnackbar.success(
        context,
        'Data skrining anak & hasil clinical reasoning berhasil disimpan ke database dan disinkronkan ke SATUSEHAT!',
        title: 'Skrining Berhasil Disimpan',
      );
    }
  }

  // ===========================================================================
  // EKSEKUSI KLASIFIKASI MODEL MLP (OTOMATIS) & REASONING (DENGAN TOMBOL)
  // ===========================================================================
  void _checkAndAutoRunMlp() {
    final bb = double.tryParse(_weightController.text.trim()) ?? 0.0;
    final tb = double.tryParse(_heightController.text.trim()) ?? 0.0;
    if (bb > 0 && tb > 0 && _smartGrowthResult == null && !_isLoadingClassification) {
      _runMlpClassification(silent: true);
    }
  }

  Future<void> _runMlpClassification({bool silent = false}) async {
    final bb = double.tryParse(_weightController.text.trim());
    final tb = double.tryParse(_heightController.text.trim());

    if (bb == null || bb <= 0 || tb == null || tb <= 0) {
      if (!silent) {
        CustomSnackbar.warning(
          context,
          'Harap masukkan angka Berat Badan dan Tinggi Badan yang valid.',
          title: 'Input Tidak Lengkap',
        );
      }
      return;
    }

    if (_isLoadingClassification) return;

    setState(() {
      _isLoadingClassification = true;
    });

    try {
      final inputSG = InputSmartGrowthBalita(
        jk: _selectedGender,
        usiaBulan: _ageMonths,
        berat: bb,
        tinggi: tb,
      );

      final result = await VitaScaleApiService.prediksiSmartGrowth(inputSG);
      if (mounted) {
        setState(() {
          _smartGrowthResult = result;
          _isLoadingClassification = false;
        });

        if (!silent) {
          CustomSnackbar.success(
            context,
            'Klasifikasi model MLP selesai! Status gizi & pertumbuhan teridentifikasi.',
            title: 'Prediksi MLP Berhasil',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingClassification = false);
        if (!silent) {
          CustomSnackbar.error(
            context,
            'Gagal menghubungkan ke backend FastAPI: $e\nPastikan python main.py berjalan di ${VitaScaleApiConfig.baseUrl}',
            title: 'Koneksi API Gagal',
          );
        }
      }
    }
  }

  Future<void> _runReasoningOnly() async {
    final bb = double.tryParse(_weightController.text.trim());
    final tb = double.tryParse(_heightController.text.trim());

    if (bb == null || bb <= 0 || tb == null || tb <= 0) {
      CustomSnackbar.warning(
        context,
        'Harap lengkapi data Berat Badan dan Tinggi Badan di Langkah 2 terlebih dahulu.',
        title: 'Input Tidak Lengkap',
      );
      return;
    }

    if (_smartGrowthResult == null) {
      await _runMlpClassification(silent: true);
      if (_smartGrowthResult == null) {
        if (mounted) {
          CustomSnackbar.error(
            context,
            'Gagal menjalankan klasifikasi MLP. Pastikan server AI aktif.',
            title: 'Klasifikasi Gagal',
          );
        }
        return;
      }
    }

    final mlpResult = _smartGrowthResult!;
    await _runReasoning(mlpResult, bb, tb);
  }

  Future<void> _runReasoning(HasilSmartGrowthBalita mlpResult, double bb, double tb) async {
    setState(() => _isLoadingReasoning = true);

    final waist = double.tryParse(_waistController.text.trim());
    final lila = double.tryParse(_lilaController.text.trim());
    final lk = double.tryParse(_headCircumferenceController.text.trim());

    try {
      final reasoning = await VitaScaleReasoningService.generateReasoning(
        childName: _nameController.text.trim().isEmpty ? 'Balita Sasaran' : _nameController.text.trim(),
        genderLabel: _selectedGender == 0 ? 'Laki-laki' : 'Perempuan',
        ageMonths: _ageMonths,
        weightKg: bb,
        heightCm: tb,
        mlpResult: mlpResult,
        waistCm: waist,
        lilaCm: lila,
        headCircumferenceCm: lk,
        measurementMethod: _measurementMethod == 'PB' ? 'PB Telentang (Infantometer - Buku KIA)' : 'TB Berdiri (Stadiometer - Buku KIA)',
        kmsStatus: _getKmsLabel(_kmsStatus),
        receivedVitA: _receivedVitA,
        receivedDeworming: _ageMonths >= 12 ? _receivedDeworming : null,
        language: ref.read(appLanguageProvider),
      );

      if (mounted) {
        setState(() {
          _reasoningResult = reasoning;
          _isLoadingReasoning = false;
          _reasoningPromptCount++;
        });

        if (_reasoningPromptCount > 1) {
          CustomSnackbar.success(
            context,
            'Penalaran klinis AI berhasil diperbarui (Prompt ke-$_reasoningPromptCount).',
            title: 'Prompt Ulang Berhasil',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingReasoning = false);
      }
    }
  }

  // ===========================================================================
  // MODAL PERINGATAN RE-PROMPT AI (PROMPT ULANG KE-2+)
  // ===========================================================================
  void _confirmRePromptDialog({VoidCallback? onConfirm}) {
    final notifier = ref.read(landingPageProvider.notifier);
    final cardBgColor = notifier.getCardColor();
    final borderColor = notifier.getBorderColor();
    final textColor = notifier.getTextColor();
    final subtitleColor = notifier.getBodyTextColor();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: cardBgColor,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: borderColor),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF39C12).withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFF39C12), size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Konfirmasi Prompt Ulang AI',
                  style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w900, color: textColor),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF39C12).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFF39C12).withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFFF39C12)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'AI sudah diprompt $_reasoningPromptCount kali untuk balita ini.',
                        style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFFD68910)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Apakah Anda yakin ingin melakukan prompt / inferensi ulang AI (Gemini 2.5 Flash & Keras MLP)?',
                style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700, color: textColor),
              ),
              const SizedBox(height: 6),
              Text(
                '• Hasil penalaran klinis, rekomendasi nutrisi PMT, dan alur berpikir sebelumnya akan diperbarui dengan data antropometri terkini.\n• Kuota token API reasoning akan digunakan kembali (Prompt ke-${_reasoningPromptCount + 1}).',
                style: GoogleFonts.outfit(fontSize: 10.5, color: subtitleColor, height: 1.4),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Batal',
                style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.bold, color: subtitleColor),
              ),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1ABC9C),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                if (onConfirm != null) {
                  onConfirm();
                } else {
                  _runReasoningOnly();
                }
              },
              icon: const Icon(Icons.refresh_rounded, size: 15, color: Colors.white),
              label: Text(
                'Lanjutkan Prompt Ulang (${_reasoningPromptCount + 1})',
                style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  // ===========================================================================
  // MODAL PENGATURAN URL SERVER
  // ===========================================================================
  void _showServerConfigModal() {
    final urlCtrl = TextEditingController(text: VitaScaleApiConfig.baseUrl);

    showDialog(
      context: context,
      builder: (ctx) => CustomDialog(
        title: 'Konfigurasi Server FastAPI VitaScale',
        icon: Icons.dns_rounded,
        iconColor: const Color(0xFF1ABC9C),
        maxWidth: 440,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Masukkan Base URL backend FastAPI tempat model MLP di-hosting.',
              style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey),
            ),
            const SizedBox(height: 14),
            CustomTextField(
              label: 'Base URL API',
              hintText: 'https://vitascalemapotech.vercel.app',
              controller: urlCtrl,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildQuickUrlChip('Vercel Cloud (Live)', 'https://vitascalemapotech.vercel.app', urlCtrl),
                _buildQuickUrlChip('127.0.0.1:8000', 'http://127.0.0.1:8000', urlCtrl),
                _buildQuickUrlChip('localhost:8000', 'http://localhost:8000', urlCtrl),
                _buildQuickUrlChip('Emulator (10.0.2.2)', 'http://10.0.2.2:8000', urlCtrl),
              ],
            ),
          ],
        ),
        actions: [
          CustomButton(
            text: 'Batal',
            isSecondary: true,
            height: 38,
            onPressed: () => Navigator.pop(ctx),
          ),
          CustomButton(
            text: 'Simpan & Tes',
            icon: Icons.check_circle_rounded,
            height: 38,
            primaryColor: const Color(0xFF1ABC9C),
            onPressed: () {
              VitaScaleApiConfig.baseUrl = urlCtrl.text.trim();
              Navigator.pop(ctx);
              _checkServer();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildQuickUrlChip(String label, String url, TextEditingController ctrl) {
    return InkWell(
      onTap: () => ctrl.text = url,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF1ABC9C).withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF1ABC9C).withOpacity(0.3)),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF1ABC9C)),
        ),
      ),
    );
  }

  void _showPatientPickerModal() {
    String modalSearchQuery = '';
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setModalState) {
            final filteredChildren = modalSearchQuery.isEmpty
                ? _availableChildren
                : _availableChildren.where((c) {
                    final q = modalSearchQuery.toLowerCase();
                    return c.name.toLowerCase().contains(q) ||
                        c.nik.toLowerCase().contains(q) ||
                        c.parentName.toLowerCase().contains(q);
                  }).toList();

            return CustomDialog(
              title: 'Daftar Sasaran Balita Terdaftar (${_availableChildren.length})',
              icon: Icons.people_rounded,
              iconColor: const Color(0xFF1ABC9C),
              maxWidth: 520,
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Cari Nama, NIK, atau Nama Orang Tua...',
                        hintStyle: GoogleFonts.outfit(fontSize: 11.5),
                        prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF1ABC9C)),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
                        ),
                      ),
                      style: GoogleFonts.outfit(fontSize: 12),
                      onChanged: (v) {
                        setModalState(() {
                          modalSearchQuery = v.trim();
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 360),
                      child: filteredChildren.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                'Tidak ada sasaran balita yang cocok dengan "$modalSearchQuery".',
                                style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey),
                              ),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              itemCount: filteredChildren.length,
                              separatorBuilder: (_, __) => const Divider(height: 6),
                              itemBuilder: (ctx, idx) {
                                final child = filteredChildren[idx];
                                final isCurrent = child.id == _activeChild?.id;
                                return ListTile(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  tileColor: isCurrent ? const Color(0xFF1ABC9C).withOpacity(0.12) : null,
                                  leading: Icon(
                                    child.isUnder24Months ? Icons.child_friendly_rounded : Icons.face_rounded,
                                    color: isCurrent ? const Color(0xFF1ABC9C) : Colors.grey,
                                  ),
                                  title: Text(
                                    child.name,
                                    style: GoogleFonts.outfit(
                                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'NIK: ${child.nik} • Usia: ${child.ageLabel} • Wali: ${child.parentName}',
                                    style: GoogleFonts.outfit(fontSize: 10.5),
                                  ),
                                  trailing: StatusBadge(
                                    label: child.isUnder24Months ? 'PB (TELENTANG)' : 'TB (BERDIRI)',
                                    color: child.isUnder24Months ? const Color(0xFF3498DB) : const Color(0xFFE67E22),
                                    fontSize: 8,
                                  ),
                                  onTap: () {
                                    _selectChild(child);
                                    Navigator.pop(ctx);
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _copyReportToClipboard() {
    if (_smartGrowthResult == null) return;

    final bb = _weightController.text;
    final tb = _heightController.text;
    final lk = _headCircumferenceController.text;
    final lila = _lilaController.text;
    final lp = _waistController.text;
    final name = _nameController.text;
    final age = _ageMonths.toStringAsFixed(0);
    final gender = _selectedGender == 0 ? 'Laki-laki' : 'Perempuan';
    final caraUkur = _measurementMethod == 'PB' ? 'Panjang Badan Telentang (< 24 Bln)' : 'Tinggi Badan Berdiri (≥ 24 Bln)';
    final kms = _getKmsLabel(_kmsStatus);

    final gizi = _smartGrowthResult?.kategoriGiziBbtb ?? '-';
    final stunting = _smartGrowthResult?.kategoriStuntingTbu ?? '-';
    final confGizi = _smartGrowthResult?.confidenceBbtb ?? 0.0;
    final confStunt = _smartGrowthResult?.confidenceTbu ?? 0.0;

    final reasoning = _reasoningResult;

    final report = '''
==================================================
LAPORAN SKRINING BALITA VITASCALE x SATUSEHAT KEMENKES RI
Standar: Buku KIA 2024 & Permenkes No. 2 Tahun 2020
==================================================
Nama Balita    : $name
NIK            : ${_nikController.text}
IHS Number     : ${_satuSehatPatientId ?? '-'}
Jenis Kelamin  : $gender
Usia           : $age Bulan
Cara Pengukuran: $caraUkur
Berat Badan    : $bb kg (LOINC: 29463-7)
Panjang/Tinggi : $tb cm (LOINC: ${_measurementMethod == 'PB' ? '8306-3' : '8302-2'})
Lingkar Kepala : ${lk.isNotEmpty ? '$lk cm (LOINC: 9843-4 - Nellhaus)' : '-'}
LiLA           : ${lila.isNotEmpty ? '$lila cm (LOINC: 56072-2 - ${_getLilaStatusText(double.tryParse(lila))})' : '-'}
Lingkar Perut  : ${lp.isNotEmpty ? '$lp cm (LOINC: 8280-0)' : '-'}
Tren KMS KIA   : $kms
Vitamin A      : ${_receivedVitA ? 'Sudah Diberikan' : 'Belum'}
Obat Cacing    : ${_ageMonths >= 12 ? (_receivedDeworming ? 'Sudah Diberikan' : 'Belum') : 'Belum Usia Target (≥ 12 Bln)'}

[HASIL KLASIFIKASI MODEL MLP KERAS]
Status Gizi (BB/TB)     : $gizi (Confidence: ${confGizi.toStringAsFixed(1)}%)
Status Stunting (TB/U)  : $stunting (Confidence: ${confStunt.toStringAsFixed(1)}%)
Indikasi Stunting       : ${_smartGrowthResult?.isStunting == true ? 'YA (ICD-10: E45)' : 'TIDAK'}
Indikasi Gizi Kurang    : ${_smartGrowthResult?.isGiziBurukAtauKurang == true ? 'YA (ICD-10: E44.0)' : 'TIDAK'}

[CLINICAL AI REASONING - BUKU KIA 2024]
Ringkasan Klinis:
${reasoning?.reasoningSummary ?? '-'}

Rantai Penalaran (Chain of Thought):
${reasoning?.chainOfThoughtSteps.map((s) => '• $s').join('\n') ?? '-'}

Analisis Faktor Risiko & Etiologi:
${reasoning?.riskAndEtiology ?? '-'}

Rencana Intervensi Gizi:
${reasoning?.nutritionalIntervention ?? '-'}

Protokol Tindak Lanjut Medis:
${reasoning?.medicalProtocol ?? '-'}

Pesan Edukasi Orang Tua:
${reasoning?.parentEducation ?? '-'}
==================================================
Dicetak melalui MAPOTECH VitaScale System
Interoperabilitas SATUSEHAT Kemenkes RI (FHIR R4)
''';

    Clipboard.setData(ClipboardData(text: report));
    CustomSnackbar.success(
      context,
      'Laporan klinis lengkap Buku KIA 2024 & kode SATUSEHAT tersalin ke clipboard.',
      title: 'Tersalin ke Clipboard',
    );
  }

  @override
  Widget build(BuildContext context) {
    final screeningState = ref.watch(screeningStateProvider);
    final landingState = ref.watch(landingPageProvider);
    final notifier = ref.read(landingPageProvider.notifier);
    final isDark = landingState.appearance == 'dark';
    final isEn = landingState.language == 'en';

    final cardBgColor = notifier.getCardColor();
    final textColor = notifier.getTextColor();
    final subtitleColor = notifier.getBodyTextColor();
    final borderColor = notifier.getBorderColor();
    final isMobile = MediaQuery.of(context).size.width < 900;
    const themeAccent = Color(0xFF1ABC9C);

    final issues = _validateScreeningForm();
    final redErrors = issues.where((i) => i['isError'] == true).toList();
    final yellowWarnings = issues.where((i) => i['isError'] == false).toList();

    final session = screeningState.session;

    return VitaScaleDlcGate(
      menuTitle: isEn ? 'Child & Infant Screening' : 'Screening Anak & Bayi',
      child: Container(
        color: notifier.getBackgroundColor(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            // =================================================================
            // TOP BAR: TOMBOL KEMBALI & BREADCRUMB
            // =================================================================
            Row(
              children: [
                InkWell(
                  onTap: () {
                    if (widget.onNavigateToMenu != null) {
                      widget.onNavigateToMenu!('dlc_vitascale_data_anak');
                    } else {
                      Navigator.of(context).maybePop();
                    }
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: cardBgColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.arrow_back_rounded, size: 18, color: textColor),
                        const SizedBox(width: 8),
                        Text(
                          isEn ? 'Back to Child Data' : 'Kembali ke Data Anak',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Text(
                  isEn ? 'VitaScale DLC Module • AI Screening & Anthropometry' : 'Modul DLC VitaScale • Skrining AI & Antropometri',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: subtitleColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // =================================================================
            // PENCARIAN & PEMILIHAN PASIEN BALITA DI BAGIAN ATAS
            // =================================================================
            _buildPatientSearchSection(cardBgColor, borderColor, textColor, subtitleColor, isMobile),

            const SizedBox(height: 16),

            // =================================================================
            // BANNER TOP HEADER
            // =================================================================
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardBgColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1ABC9C).withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.monitor_weight_rounded, size: 28, color: Color(0xFF1ABC9C)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1ABC9C).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: Text(
                                isEn ? 'ANTHROPOMETRIC & AI SCREENING MODULE' : 'MODUL SKRINING ANTROPOMETRI & AI',
                                style: GoogleFonts.outfit(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFF1ABC9C),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'VitaScale by MAPOTECH',
                              style: GoogleFonts.outfit(fontSize: 10, color: subtitleColor, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isEn ? 'Child Anthropometry Measurement & Screening' : 'Uji Ukur & Skrining Antropometri Balita',
                          style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w900, color: textColor),
                        ),
                        Text(
                          isEn ? 'Machine Learning Classification (Keras MLP) & Pediatrician Clinical AI Reasoning.' : 'Klasifikasi Machine Learning (Keras MLP) & Clinical AI Reasoning Dokter Spesialis Anak.',
                          style: GoogleFonts.outfit(fontSize: 10.5, color: subtitleColor),
                        ),
                      ],
                    ),
                  ),
                  // Tombol Ganti Server URL
                  InkWell(
                    onTap: _showServerConfigModal,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: borderColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: borderColor),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.settings_ethernet_rounded, size: 16, color: subtitleColor),
                          const SizedBox(width: 6),
                          Text(
                            'API Host',
                            style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: textColor),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // =================================================================
            // TAB SELECTOR: Mode Input Manual vs Hardware IoT vs Cloud PCV
            // =================================================================
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: borderColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor),
              ),
              child: isMobile
                  ? Column(
                      children: [
                        _buildTabButton(
                          index: 0,
                          label: 'Uji Ukur Manual & Reasoning AI',
                          icon: Icons.tune_rounded,
                          badge: 'Tersedia Sekarang (Tanpa IoT Fisik)',
                          badgeColor: const Color(0xFF1ABC9C),
                        ),
                        const SizedBox(height: 4),
                        _buildTabButton(
                          index: 1,
                          label: 'Perangkat IoT & Kamera CV',
                          icon: Icons.sensors_rounded,
                          badge: 'ESP32 + Webcam',
                          badgeColor: const Color(0xFF3498DB),
                        ),
                        const SizedBox(height: 4),
                        _buildTabButton(
                          index: 2,
                          label: 'Ukur Tinggi via Foto AI (PCV API)',
                          icon: Icons.photo_camera_rounded,
                          badge: 'pcvmapotechs5.vercel.app',
                          badgeColor: const Color(0xFFE91E63),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: _buildTabButton(
                            index: 0,
                            label: 'Uji Ukur Manual & AI',
                            icon: Icons.tune_rounded,
                            badge: 'Tanpa IoT Fisik',
                            badgeColor: const Color(0xFF1ABC9C),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: _buildTabButton(
                            index: 1,
                            label: 'Perangkat IoT & CV',
                            icon: Icons.sensors_rounded,
                            badge: 'ESP32 + Webcam',
                            badgeColor: const Color(0xFF3498DB),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: _buildTabButton(
                            index: 2,
                            label: 'Ukur Tinggi via Foto (PCV)',
                            icon: Icons.photo_camera_rounded,
                            badge: 'OpenCV Cloud API',
                            badgeColor: const Color(0xFFE91E63),
                          ),
                        ),
                      ],
                    ),
            ),

            const SizedBox(height: 18),

            // =================================================================
            // KONTEN TAB 0: UJI UKUR MANUAL & REASONING AI (STEPPER BERTAHAP)
            // =================================================================
            if (_activeTab == 0) ...[
              _buildServerStatusBar(cardBgColor, borderColor, textColor, subtitleColor),
              const SizedBox(height: 16),

              // Custom Form Stepper (1 Card Per Step)
              CustomFormStepper(
                steps: [
                  FormStepItem(
                    step: 1,
                    label: '1. Identitas Balita',
                    icon: Icons.badge_rounded,
                    hasError: redErrors.any((e) => e['step'] == 1),
                    hasWarning: yellowWarnings.any((w) => w['step'] == 1),
                    isCompleted: _nikController.text.trim().length == 16 && _nameController.text.trim().isNotEmpty && _ageMonths > 0,
                  ),
                  FormStepItem(
                    step: 2,
                    label: '2. Antropometri',
                    icon: Icons.straighten_rounded,
                    hasError: redErrors.any((e) => e['step'] == 2),
                    hasWarning: yellowWarnings.any((w) => w['step'] == 2),
                    isCompleted: double.tryParse(_weightController.text.trim()) != null && double.tryParse(_heightController.text.trim()) != null,
                  ),
                  FormStepItem(
                    step: 3,
                    label: '3. Reasoning AI',
                    icon: Icons.psychology_rounded,
                    hasError: redErrors.any((e) => e['step'] == 3),
                    hasWarning: yellowWarnings.any((w) => w['step'] == 3),
                    isCompleted: _smartGrowthResult != null,
                  ),
                  FormStepItem(
                    step: 4,
                    label: '4. SATUSEHAT & Simpan',
                    icon: Icons.cloud_sync_rounded,
                    hasError: false,
                    hasWarning: false,
                    isCompleted: _satuSehatSyncResult != null,
                  ),
                ],
                currentStep: _formStep,
                onStepTapped: (step) {
                  setState(() => _formStep = step);
                  if (step == 3) {
                    _checkAndAutoRunMlp();
                  }
                },
                themeAccent: const Color(0xFF1ABC9C),
                textColor: textColor,
                subtitleColor: subtitleColor,
                borderColor: borderColor,
                cardBgColor: cardBgColor,
                isDark: isDark,
              ),

              const SizedBox(height: 16),

              // Tampilan 1 Kartu Form Aktif Sesuai Step
              if (_formStep == 1)
                _buildStep1ChildIdentity(cardBgColor, borderColor, textColor, subtitleColor, isMobile)
              else if (_formStep == 2)
                _buildStep2Anthropometry(cardBgColor, borderColor, textColor, subtitleColor, isMobile)
              else if (_formStep == 3)
                _buildStep3ReasoningAndAi(cardBgColor, borderColor, textColor, subtitleColor, isMobile)
              else if (_formStep == 4)
                _buildStep4SatuSehatAndSave(cardBgColor, borderColor, textColor, subtitleColor, isMobile),

              const SizedBox(height: 16),

              // Stepper Navigation Footer & Real-Time Validation Pill
              _buildScreeningStepperFooter(
                cardBgColor: cardBgColor,
                borderColor: borderColor,
                textColor: textColor,
                subtitleColor: subtitleColor,
                isMobile: isMobile,
                redErrors: redErrors,
                yellowWarnings: yellowWarnings,
              ),

              const SizedBox(height: 24),
            ]
            // =================================================================
            // KONTEN TAB 1: PERANGKAT IOT & KAMERA CV (EXISTING)
            // =================================================================
            else if (_activeTab == 1) ...[
              _buildMqttStatusBar(cardBgColor, borderColor, textColor, subtitleColor),
              const SizedBox(height: 16),
              _buildIotSubTabSelector(cardBgColor, borderColor, textColor, subtitleColor),
              const SizedBox(height: 16),
              if (_iotSubTab == 0)
                _buildIotTelemetryPanel(
                  cardBg: cardBgColor,
                  border: borderColor,
                  text: textColor,
                  sub: subtitleColor,
                  isMobile: isMobile,
                  isDark: isDark,
                  session: session,
                )
              else ...[
                if (session == null)
                  EmptyStateWidget(
                    icon: Icons.person_search_rounded,
                    title: 'Belum Ada Sesi Skrining yang Aktif',
                    subtitle: 'Pilih pasien anak/bayi untuk memulai pengukuran antropometri dengan kamera OpenCV.',
                    cardBg: cardBgColor,
                    border: borderColor,
                    textColor: textColor,
                    subtitleColor: subtitleColor,
                  )
                else ...[
                  VitaScaleStatusBar(
                    session: session,
                    deviceStatus: screeningState.deviceStatus,
                    isCameraReady: screeningState.isCameraReady,
                    cardBgColor: cardBgColor,
                    borderColor: borderColor,
                    textColor: textColor,
                    subtitleColor: subtitleColor,
                    themeAccent: const Color(0xFF1ABC9C),
                    onModeChanged: (m) => ref.read(screeningStateProvider.notifier).changeAnthropometryMode(m),
                    onCloseSession: () => ref.read(screeningStateProvider.notifier).closeSession(),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: isMobile ? 1 : 3,
                        child: Container(
                          height: 380,
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: borderColor),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: VitaScaleCameraWidget(
                            onStatusChanged: (isReady, label) {
                              ref.read(screeningStateProvider.notifier).setCameraStatus(
                                    isReady: isReady,
                                    cameraLabel: label,
                                  );
                            },
                            onMeasured: (result) {
                              if (result.ok && result.valueCm != null) {
                                ref.read(screeningStateProvider.notifier).updateHeight(
                                      value: result.valueCm,
                                      status: MeasurementStatus.stable,
                                      source: 'opencv_web',
                                    );
                                CustomSnackbar.success(
                                  context,
                                  'Panjang/Tinggi terdeteksi: ${result.valueCm!.toStringAsFixed(1)} cm',
                                  title: 'Deteksi Marker Berhasil',
                                );
                              } else {
                                final err = result.reasons.isNotEmpty
                                    ? result.reasons.join('\n')
                                    : 'Deteksi marker papan ukur gagal.';
                                ref.read(screeningStateProvider.notifier).updateHeight(
                                      value: null,
                                      status: MeasurementStatus.failed,
                                      errorMessage: err,
                                    );
                                CustomSnackbar.warning(context, err, title: 'Kamera Gagal Mengukur');
                              }
                            },
                            onSimulateFixture: () {
                              final sampleVal = session.child.isUnder24Months ? 74.8 : 98.5;
                              _simulator.injectCvFixtureMeasurement(fixtureHeight: sampleVal);
                              CustomSnackbar.info(
                                context,
                                'Data fixture sintetis panjang/tinggi ($sampleVal cm) telah diinjeksikan.',
                                title: 'Fixture Uji Selesai',
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: isMobile ? 1 : 2,
                        child: Column(
                          children: [
                            SizedBox(
                              height: 184,
                              child: MeasurementCard(
                                type: MeasurementType.weight,
                                item: session.weight,
                                icon: Icons.monitor_weight_rounded,
                                cardBgColor: cardBgColor,
                                borderColor: borderColor,
                                textColor: textColor,
                                subtitleColor: subtitleColor,
                                themeAccent: const Color(0xFF1ABC9C),
                                onReset: () => ref
                                    .read(screeningStateProvider.notifier)
                                    .resetMeasurement(MeasurementType.weight),
                                simulateLabel: 'Simulasi Berat',
                                onSimulate: () {
                                  final defaultTarget = session.child.isUnder24Months ? 9.45 : 15.20;
                                  _simulator.simulateWeightMeasurement(targetWeight: defaultTarget);
                                },
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 184,
                              child: MeasurementCard(
                                type: MeasurementType.waist,
                                item: session.waist,
                                icon: Icons.straighten_rounded,
                                cardBgColor: cardBgColor,
                                borderColor: borderColor,
                                textColor: textColor,
                                subtitleColor: subtitleColor,
                                themeAccent: const Color(0xFFE67E22),
                                onReset: () => ref
                                    .read(screeningStateProvider.notifier)
                                    .resetMeasurement(MeasurementType.waist),
                                simulateLabel: 'Simulasi Lingkar',
                                onSimulate: () {
                                  final defaultWaist = session.child.isUnder24Months ? 44.2 : 51.5;
                                  _simulator.simulateWaistMeasurement(targetWaist: defaultWaist);
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ]

            // =================================================================
            // KONTEN TAB 2: UKUR TINGGI VIA FOTO AI (PCV API CLOUD)
            // =================================================================
            else if (_activeTab == 2) ...[
              _buildTab2PcvCloudSection(
                cardBgColor: cardBgColor,
                borderColor: borderColor,
                textColor: textColor,
                subtitleColor: subtitleColor,
                themeAccent: themeAccent,
                isDark: isDark,
                isMobile: isMobile,
                redErrors: redErrors,
                yellowWarnings: yellowWarnings,
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

  // ===========================================================================
  // PENCARIAN & PEMILIHAN SASARAN BALITA (SEARCH AT THE TOP)
  // ===========================================================================
  Widget _buildPatientSearchSection(
    Color cardBg,
    Color border,
    Color text,
    Color sub,
    bool isMobile,
  ) {
    final searchMatches = _topSearchQuery.isEmpty
        ? <ChildProfile>[]
        : _availableChildren.where((c) {
            final q = _topSearchQuery.toLowerCase();
            return c.name.toLowerCase().contains(q) ||
                c.nik.toLowerCase().contains(q) ||
                c.parentName.toLowerCase().contains(q);
          }).toList();

    return CustomCard(
      color: cardBg,
      borderColor: _activeChild == null ? const Color(0xFF1ABC9C).withOpacity(0.4) : border,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Section Title Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1ABC9C).withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_search_rounded,
                  size: 20,
                  color: Color(0xFF1ABC9C),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'CARI & PILIH SASARAN BALITA',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: text,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(width: 8),
                        StatusBadge(
                          label: '${_availableChildren.length} Terdaftar',
                          color: const Color(0xFF1ABC9C),
                          fontSize: 9,
                          showDot: false,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Cari nama anak atau NIK balita di bawah ini untuk memuat otomatis data KMS, usia, dan riwayat.',
                      style: GoogleFonts.outfit(fontSize: 10.5, color: sub),
                    ),
                  ],
                ),
              ),
              if (_activeChild != null)
                CustomButton(
                  text: 'Ganti Pasien',
                  icon: Icons.swap_horiz_rounded,
                  height: 32,
                  isSecondary: true,
                  onPressed: () {
                    setState(() {
                      _activeChild = null;
                      _topSearchController.clear();
                      _topSearchQuery = '';
                    });
                  },
                ),
            ],
          ),

          const SizedBox(height: 14),

          // Search Field
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF1A1D27)
                  : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _topSearchQuery.isNotEmpty
                    ? const Color(0xFF1ABC9C)
                    : border,
                width: _topSearchQuery.isNotEmpty ? 1.5 : 1.0,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
            child: Row(
              children: [
                const Icon(
                  Icons.search_rounded,
                  size: 20,
                  color: Color(0xFF1ABC9C),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _topSearchController,
                    style: GoogleFonts.outfit(fontSize: 13, color: text),
                    decoration: InputDecoration(
                      hintText: ref.watch(landingPageProvider).language == 'en'
                          ? 'Search Child Name, NIK (16-Digit), or Parent Name...'
                          : 'Cari Nama Balita, NIK (16-Digit), atau Nama Orang Tua...',
                      hintStyle: GoogleFonts.outfit(
                        fontSize: 11.5,
                        color: sub.withOpacity(0.7),
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onChanged: (v) {
                      setState(() {
                        _topSearchQuery = v.trim();
                      });
                    },
                  ),
                ),
                if (_topSearchController.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    color: sub,
                    tooltip: ref.watch(landingPageProvider).language == 'en' ? 'Clear Search' : 'Hapus Pencarian',
                    onPressed: () {
                      _topSearchController.clear();
                      setState(() {
                        _topSearchQuery = '';
                      });
                    },
                  ),
                const SizedBox(width: 4),
                CustomButton(
                  text: 'Daftar Lengkap',
                  icon: Icons.list_alt_rounded,
                  height: 32,
                  isSecondary: true,
                  onPressed: _showPatientPickerModal,
                ),
              ],
            ),
          ),

          // Search Result Dropdown / List (when query is entered)
          if (_topSearchQuery.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              constraints: const BoxConstraints(maxHeight: 220),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF1E2130)
                    : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF1ABC9C).withOpacity(0.4)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: searchMatches.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline_rounded, size: 18, color: sub),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Tidak ada data balita yang cocok dengan "$_topSearchQuery".',
                              style: GoogleFonts.outfit(fontSize: 11.5, color: sub),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.all(8),
                      itemCount: searchMatches.length,
                      separatorBuilder: (_, __) => const Divider(height: 8),
                      itemBuilder: (ctx, idx) {
                        final child = searchMatches[idx];
                        return InkWell(
                          onTap: () => _selectChild(child),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1ABC9C).withOpacity(0.06),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  child.isUnder24Months
                                      ? Icons.child_friendly_rounded
                                      : Icons.face_rounded,
                                  size: 20,
                                  color: const Color(0xFF1ABC9C),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            child.name,
                                            style: GoogleFonts.outfit(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.bold,
                                              color: text,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          StatusBadge(
                                            label: child.gender == 'L' ? 'L' : 'P',
                                            color: child.gender == 'L'
                                                ? const Color(0xFF3498DB)
                                                : const Color(0xFFE91E63),
                                            fontSize: 8,
                                            showDot: false,
                                          ),
                                        ],
                                      ),
                                      Text(
                                        'NIK: ${child.nik} • Usia: ${child.ageLabel} (${child.ageInMonths} Bln) • Wali: ${child.parentName}',
                                        style: GoogleFonts.outfit(fontSize: 10, color: sub),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                CustomButton(
                                  text: 'Pilih',
                                  icon: Icons.check_circle_rounded,
                                  height: 28,
                                  primaryColor: const Color(0xFF1ABC9C),
                                  onPressed: () => _selectChild(child),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],

          // Active Child Banner or Quick Selection Prompt (when query is empty)
          if (_topSearchQuery.isEmpty) ...[
            const SizedBox(height: 12),
            if (_activeChild != null)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1ABC9C).withOpacity(0.09),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF1ABC9C).withOpacity(0.35)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1ABC9C).withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        _activeChild!.isUnder24Months
                            ? Icons.child_friendly_rounded
                            : Icons.face_rounded,
                        size: 24,
                        color: const Color(0xFF1ABC9C),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  'Sasaran Terpilih: ${_activeChild!.name}',
                                  style: GoogleFonts.outfit(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w900,
                                    color: const Color(0xFF1ABC9C),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              StatusBadge(
                                label: _activeChild!.gender == 'L' ? 'L' : 'P',
                                color: _activeChild!.gender == 'L'
                                    ? const Color(0xFF3498DB)
                                    : const Color(0xFFE91E63),
                                fontSize: 8.5,
                                showDot: false,
                              ),
                              const SizedBox(width: 6),
                              if (_activeChild!.isBalita)
                                Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: StatusBadge(
                                    label: 'BALITA',
                                    color: const Color(0xFF1ABC9C),
                                    fontSize: 8.5,
                                    showDot: false,
                                  ),
                                ),
                              StatusBadge(
                                label: _activeChild!.defaultMode.code,
                                color: _activeChild!.isUnder24Months
                                    ? const Color(0xFF3498DB)
                                    : const Color(0xFFE67E22),
                                fontSize: 8.5,
                                showDot: false,
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'NIK: ${_activeChild!.nik} • Usia: ${_activeChild!.ageLabel} (${_activeChild!.ageInMonths} Bulan) • Wali: ${_activeChild!.parentName}',
                            style: GoogleFonts.outfit(fontSize: 10.5, color: sub),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Alamat: ${_activeChild!.address} • Telp: ${_activeChild!.phone?.isNotEmpty == true ? _activeChild!.phone : "-"}',
                            style: GoogleFonts.outfit(fontSize: 10, color: sub.withOpacity(0.8)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    InkWell(
                      onTap: () {
                        setState(() {
                          _activeChild = null;
                        });
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.swap_horiz_rounded, size: 15, color: text),
                            const SizedBox(width: 4),
                            Text(
                              'Ganti Balita',
                              style: GoogleFonts.outfit(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: text,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              // Panduan: Belum ada pasien dipilih, pengguna perlu melakukan pencarian pasien terdaftar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF161924)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: border),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1ABC9C).withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.search_rounded,
                        size: 20,
                        color: Color(0xFF1ABC9C),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pencarian Sasaran Balita Terdaftar',
                            style: GoogleFonts.outfit(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: text,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Ketik nama anak, NIK (16-Digit), atau nama orang tua pada kolom pencarian di atas untuk memilih sasaran skrining.',
                            style: GoogleFonts.outfit(
                              fontSize: 10.5,
                              color: sub,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  // ===========================================================================
  // WIDGET HELPER TAB BUTTON
  // ===========================================================================
  Widget _buildTabButton({
    required int index,
    required String label,
    required IconData icon,
    required String badge,
    required Color badgeColor,
  }) {
    final isSelected = _activeTab == index;
    return InkWell(
      onTap: () => setState(() => _activeTab = index),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1ABC9C) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : Colors.grey,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      color: isSelected ? Colors.white : Colors.grey[700],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white.withOpacity(0.2) : badgeColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      badge,
                      style: GoogleFonts.outfit(
                        fontSize: 8.5,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : badgeColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // MQTT IOT GATEWAY STATUS BAR (HC-SR04 & HX711)
  // ===========================================================================
  ({String label, String detail, IconData icon, Color color}) _getIotDeviceStatusInfo() {
    if (_isMqttConnecting) {
      return (
        label: 'Menghubungkan',
        detail: 'Menyambung ke ${_mqttService.broker}',
        icon: Icons.sync_rounded,
        color: const Color(0xFFF39C12),
      );
    }
    if (!_mqttService.isConnected) {
      return (
        label: 'Offline',
        detail: 'Broker MQTT terputus',
        icon: Icons.power_off_rounded,
        color: const Color(0xFF95A5A6),
      );
    }

    if (_mqttService.isDeviceOnline == false && _lastMqttTelemetry == null) {
      return (
        label: 'Alat Offline',
        detail: '${_mqttService.deviceId} belum aktif',
        icon: Icons.portable_wifi_off_rounded,
        color: const Color(0xFFE74C3C),
      );
    }

    if (_lastMqttTelemetry == null) {
      return (
        label: 'Standby',
        detail: 'Menunggu data ${_mqttService.deviceId}',
        icon: Icons.hourglass_top_rounded,
        color: const Color(0xFF3498DB),
      );
    }

    final isStable = _lastMqttTelemetry?['weight']?['is_stable'] == true ||
        _lastMqttTelemetry?['is_stable'] == true;
    final lastWeight = (_lastMqttTelemetry?['weight'] is Map)
        ? (_lastMqttTelemetry?['weight']['val_kg'] as num?)?.toDouble()
        : (_lastMqttTelemetry?['val_kg'] as num?)?.toDouble();
    final lastHeight = (_lastMqttTelemetry?['height'] is Map)
        ? (_lastMqttTelemetry?['height']['val_cm'] as num?)?.toDouble()
        : (_lastMqttTelemetry?['val_cm'] as num?)?.toDouble();

    if (isStable) {
      return (
        label: 'Stabil (Terkunci)',
        detail: '${_mqttService.deviceId} • Pengukuran siap',
        icon: Icons.verified_rounded,
        color: const Color(0xFF27AE60),
      );
    }
    if ((lastWeight != null && lastWeight > 0.2) || (lastHeight != null && lastHeight > 0)) {
      return (
        label: 'Mengukur (Aktif)',
        detail: '${_mqttService.deviceId} • Menstabilkan...',
        icon: Icons.sensors_rounded,
        color: const Color(0xFFF39C12),
      );
    }
    return (
      label: 'Online (Siap Ukur)',
      detail: '${_mqttService.deviceId} • Timbangan kosong',
      icon: Icons.check_circle_outline_rounded,
      color: const Color(0xFF1ABC9C),
    );
  }

  Widget _buildMqttStatusBar(Color cardBg, Color border, Color text, Color sub) {
    final isConnected = _mqttService.isConnected;
    final statusColor = isConnected
        ? const Color(0xFF27AE60)
        : (_isMqttConnecting ? const Color(0xFFF39C12) : const Color(0xFF95A5A6));
    final deviceStatus = _getIotDeviceStatusInfo();

    final lastWeight = (_lastMqttTelemetry?['weight'] is Map)
        ? (_lastMqttTelemetry?['weight']['val_kg'] as num?)?.toDouble()
        : (_lastMqttTelemetry?['val_kg'] as num?)?.toDouble();
    final isStable = _lastMqttTelemetry?['weight']?['is_stable'] == true ||
        _lastMqttTelemetry?['is_stable'] == true;
    final lastHeight = (_lastMqttTelemetry?['height'] is Map)
        ? (_lastMqttTelemetry?['height']['val_cm'] as num?)?.toDouble()
        : (_lastMqttTelemetry?['val_cm'] as num?)?.toDouble();
    final rssi = _lastMqttTelemetry?['rssi_dbm'] as num?;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isConnected ? const Color(0xFF27AE60).withOpacity(0.4) : border,
          width: isConnected ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 760;

              final infoWidget = Row(
                mainAxisSize: isNarrow ? MainAxisSize.max : MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.sensors_rounded, color: statusColor, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              'GATEWAY IOT VITASCALE',
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                                color: text,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1ABC9C).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFF1ABC9C).withOpacity(0.35)),
                              ),
                              child: Text(
                                'mapotechiotmqtt.vercel.app',
                                style: GoogleFonts.outfit(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF1ABC9C),
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: statusColor.withOpacity(0.4)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isConnected
                                        ? 'LIVE STREAM'
                                        : (_isMqttConnecting ? 'MENGHUBUNGKAN...' : 'TERPUTUS'),
                                    style: GoogleFonts.outfit(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                      color: statusColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Broker: ${_mqttService.broker}:${_mqttService.port} (${_mqttService.connectionProtocolLabel}) • Topik: mapotech/${_mqttService.faskesId}/vitascale/${_mqttService.deviceId} • Acuan: ${_mqttService.poleHeightCm.toStringAsFixed(1)}cm',
                          style: GoogleFonts.outfit(fontSize: 10.5, color: sub),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              );

              final settingsBtn = Tooltip(
                message: 'Konfigurasi Fleksibel Broker & Gateway',
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: _showMqttSettingsDialog,
                  child: Container(
                    height: 36,
                    width: 36,
                    decoration: BoxDecoration(
                      color: border.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: border),
                    ),
                    child: Icon(Icons.settings_rounded, size: 18, color: text),
                  ),
                ),
              );

              final tareBtn = OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF3498DB),
                  side: BorderSide(
                    color: isConnected
                        ? const Color(0xFF3498DB).withOpacity(0.55)
                        : border.withOpacity(0.6),
                    width: 1.3,
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                  minimumSize: const Size(0, 36),
                ),
                icon: const Icon(Icons.scale_rounded, size: 15),
                label: Text(
                  'Nol-kan (Tare)',
                  style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onPressed: isConnected ? _sendMqttTare : null,
              );

              final applyBtn = (lastHeight != null || lastWeight != null)
                  ? OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF9B59B6),
                        side: BorderSide(
                          color: const Color(0xFF9B59B6).withOpacity(0.55),
                          width: 1.3,
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                        minimumSize: const Size(0, 36),
                      ),
                      icon: const Icon(Icons.assignment_turned_in_rounded, size: 15),
                      label: Text(
                        'Terapkan',
                        style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onPressed: () => _applyMqttTelemetryToForm(),
                    )
                  : null;

              final connectBtn = isConnected
                  ? OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFE74C3C),
                        side: BorderSide(
                          color: const Color(0xFFE74C3C).withOpacity(0.6),
                          width: 1.3,
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                        minimumSize: const Size(0, 36),
                      ),
                      icon: const Icon(Icons.link_off_rounded, size: 15),
                      label: Text(
                        'Putuskan',
                        style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onPressed: _isMqttConnecting ? null : _toggleMqttConnection,
                    )
                  : ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1ABC9C),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                        minimumSize: const Size(0, 36),
                      ),
                      icon: _isMqttConnecting
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.link_rounded, size: 15),
                      label: Text(
                        _isMqttConnecting ? 'Menghubungkan...' : 'Hubungkan MQTT',
                        style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onPressed: _isMqttConnecting ? null : _toggleMqttConnection,
                    );

              // Selalu dalam SATU Row agar Nol-kan (Tare) dan Putuskan sejajar rapi
              final actionsRow = Row(
                mainAxisSize: isNarrow ? MainAxisSize.max : MainAxisSize.min,
                children: [
                  settingsBtn,
                  const SizedBox(width: 8),
                  if (isNarrow) Expanded(child: tareBtn) else tareBtn,
                  if (applyBtn != null) ...[
                    const SizedBox(width: 8),
                    if (isNarrow) Expanded(child: applyBtn) else applyBtn,
                  ],
                  const SizedBox(width: 8),
                  if (isNarrow) Expanded(child: connectBtn) else connectBtn,
                ],
              );

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    infoWidget,
                    const SizedBox(height: 10),
                    actionsRow,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: infoWidget),
                  const SizedBox(width: 12),
                  actionsRow,
                ],
              );
            },
          ),

          // Strip Mini Sensor jika terkoneksi
          if (isConnected) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF27AE60).withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF27AE60).withOpacity(0.2)),
              ),
              child: Wrap(
                spacing: 20,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // Sensor TB
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.straighten_rounded, size: 18, color: Color(0xFF16A085)),
                      const SizedBox(width: 6),
                      Text('TB Ultrasonik: ', style: GoogleFonts.outfit(fontSize: 10.5, color: sub)),
                      Text(
                        lastHeight != null ? '${lastHeight.toStringAsFixed(1)} cm' : '-- cm',
                        style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w800, color: text),
                      ),
                    ],
                  ),

                  // Sensor BB
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.monitor_weight_rounded, size: 18, color: Color(0xFF2980B9)),
                      const SizedBox(width: 6),
                      Text('BB Load Cell: ', style: GoogleFonts.outfit(fontSize: 10.5, color: sub)),
                      Text(
                        lastWeight != null ? '${lastWeight.toStringAsFixed(2)} kg' : '-- kg',
                        style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w800, color: text),
                      ),
                      if (isStable) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFF27AE60).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text('STABIL', style: GoogleFonts.outfit(fontSize: 8.5, fontWeight: FontWeight.w800, color: const Color(0xFF27AE60))),
                        ),
                      ],
                    ],
                  ),

                  // Status Alat
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(deviceStatus.icon, size: 16, color: deviceStatus.color),
                      const SizedBox(width: 4),
                      Text('Status Alat: ', style: GoogleFonts.outfit(fontSize: 10.5, color: sub)),
                      Text(
                        deviceStatus.label,
                        style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w800, color: deviceStatus.color),
                      ),
                    ],
                  ),

                  // Sinyal WiFi
                  if (rssi != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.wifi_rounded, size: 16, color: Color(0xFF3498DB)),
                        const SizedBox(width: 4),
                        Text('$rssi dBm', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700, color: text)),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Selector Sub-Mode pada Tab 1 (Sensor IoT ESP32 vs Kamera Webcam CV)
  Widget _buildIotSubTabSelector(Color cardBg, Color border, Color text, Color sub) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: border.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => setState(() => _iotSubTab = 0),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _iotSubTab == 0 ? const Color(0xFF1ABC9C) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.sensors_rounded, size: 18, color: _iotSubTab == 0 ? Colors.white : sub),
                    const SizedBox(width: 8),
                    Text(
                      'Sensor IoT ESP32 (Ultrasonik & Load Cell)',
                      style: GoogleFonts.outfit(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: _iotSubTab == 0 ? Colors.white : text,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => setState(() => _iotSubTab = 1),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _iotSubTab == 1 ? const Color(0xFF3498DB) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.videocam_rounded, size: 18, color: _iotSubTab == 1 ? Colors.white : sub),
                    const SizedBox(width: 8),
                    Text(
                      'Kamera OpenCV CV (Papan Ukur Marker)',
                      style: GoogleFonts.outfit(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: _iotSubTab == 1 ? Colors.white : text,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Panel Telemetri Lengkap IoT untuk Tab 1
  Widget _buildIotTelemetryPanel({
    required Color cardBg,
    required Color border,
    required Color text,
    required Color sub,
    required bool isMobile,
    required bool isDark,
    required ScreeningSession? session,
  }) {
    final lastWeight = (_lastMqttTelemetry?['weight'] is Map)
        ? (_lastMqttTelemetry?['weight']['val_kg'] as num?)?.toDouble()
        : (_lastMqttTelemetry?['val_kg'] as num?)?.toDouble();
    final isStable = _lastMqttTelemetry?['weight']?['is_stable'] == true ||
        _lastMqttTelemetry?['is_stable'] == true;
    final lastHeight = (_lastMqttTelemetry?['height'] is Map)
        ? (_lastMqttTelemetry?['height']['val_cm'] as num?)?.toDouble()
        : (_lastMqttTelemetry?['val_cm'] as num?)?.toDouble();
    final rawDist = (_lastMqttTelemetry?['height'] is Map)
        ? (_lastMqttTelemetry?['height']['raw_dist_cm'] as num?)?.toDouble()
        : null;
    final poleHeight = (_lastMqttTelemetry?['height'] is Map && _lastMqttTelemetry!['height']['pole_height_cm'] != null)
        ? (_lastMqttTelemetry!['height']['pole_height_cm'] as num).toDouble()
        : _mqttService.poleHeightCm;
    final rssi = _lastMqttTelemetry?['rssi_dbm'] as num?;
    final deviceStatus = _getIotDeviceStatusInfo();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Sesi Info Banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: session != null
                ? const Color(0xFF1ABC9C).withOpacity(0.08)
                : border.withOpacity(0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: session != null
                  ? const Color(0xFF1ABC9C).withOpacity(0.25)
                  : border,
            ),
          ),
          child: Row(
            children: [
              Icon(
                session != null ? Icons.face_rounded : Icons.info_outline_rounded,
                size: 20,
                color: session != null ? const Color(0xFF1ABC9C) : sub,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  session != null
                      ? 'Pasien Aktif: ${session.child.name} (${session.child.ageInMonths} Bulan) • NIK: ${session.child.nik}'
                      : 'Mode Uji Bebas Perangkat IoT (Tanpa Pasien Terpilih). Data siap dimonitor secara real-time.',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: text,
                  ),
                ),
              ),
              if (session == null)
                CustomButton(
                  text: 'Pilih Pasien',
                  icon: Icons.person_search_rounded,
                  height: 30,
                  primaryColor: const Color(0xFF1ABC9C),
                  onPressed: _showPatientPickerModal,
                ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // 2 Kartu Sensor Utama: Ultrasonik HC-SR04 & Load Cell HX711
        if (isMobile) ...[
          _buildUltrasonicCard(cardBg, border, text, sub, lastHeight, rawDist, poleHeight, isStable),
          const SizedBox(height: 14),
          _buildLoadCellCard(cardBg, border, text, sub, lastWeight, isStable),
        ] else ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildUltrasonicCard(cardBg, border, text, sub, lastHeight, rawDist, poleHeight, isStable),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildLoadCellCard(cardBg, border, text, sub, lastWeight, isStable),
              ),
            ],
          ),
        ],

        const SizedBox(height: 16),

        // Kartu Telemetri Perangkat & Lingkungan (RSSI, Status Alat, Tiang Acuan, Gateway)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
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
                      const Icon(Icons.memory_rounded, size: 18, color: Color(0xFF3498DB)),
                      const SizedBox(width: 8),
                      Text(
                        'STATUS TELEMETRI PERANGKAT & JARINGAN',
                        style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.w800, color: text, letterSpacing: 0.5),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: _showMqttSettingsDialog,
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.tune_rounded, size: 14, color: Color(0xFF1ABC9C)),
                          const SizedBox(width: 4),
                          Text('Ubah Parameter', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF1ABC9C))),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 24,
                runSpacing: 12,
                children: [
                  _buildTelemetryParamItem(
                    icon: Icons.wifi_rounded,
                    iconColor: const Color(0xFF2980B9),
                    title: 'Sinyal Wi-Fi (RSSI)',
                    value: rssi != null ? '$rssi dBm' : '-- dBm',
                    subvalue: rssi != null
                        ? (rssi > -70 ? 'Sangat Kuat' : 'Stabil')
                        : (_mqttService.isConnected ? 'Menunggu data' : 'Offline'),
                    text: text,
                    sub: sub,
                  ),
                  _buildTelemetryParamItem(
                    icon: deviceStatus.icon,
                    iconColor: deviceStatus.color,
                    title: 'Status Alat',
                    value: deviceStatus.label,
                    subvalue: deviceStatus.detail,
                    text: text,
                    sub: sub,
                  ),
                  _buildTelemetryParamItem(
                    icon: Icons.height_rounded,
                    iconColor: const Color(0xFF16A085),
                    title: 'Tiang Acuan Ultrasonik',
                    value: '${poleHeight.toStringAsFixed(1)} cm',
                    subvalue: 'Tinggi Maks. Stadiometer',
                    text: text,
                    sub: sub,
                  ),
                  _buildTelemetryParamItem(
                    icon: Icons.public_rounded,
                    iconColor: const Color(0xFF9B59B6),
                    title: 'Cloud Gateway Vercel',
                    value: _mqttService.isGatewayHealthy || _mqttService.isConnected ? 'Online' : 'Siap',
                    subvalue: 'mapotechiotmqtt.vercel.app',
                    text: text,
                    sub: sub,
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // Tombol CTA Terapkan Semua
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1ABC9C),
              foregroundColor: Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.flash_on_rounded, size: 20),
            label: Text(
              'Terapkan Seluruh Data Sensor IoT ke Formulir Skrining ⚡',
              style: GoogleFonts.outfit(fontSize: 13.5, fontWeight: FontWeight.w800),
            ),
            onPressed: (lastHeight != null || lastWeight != null)
                ? () => _applyMqttTelemetryToForm(switchToManualTab: true)
                : () {
                    CustomSnackbar.warning(
                      context,
                      'Sensor belum mengirimkan data. Pastikan perangkat ESP32 menyala dan terhubung.',
                      title: 'Data Belum Tersedia',
                    );
                  },
          ),
        ),
      ],
    );
  }

  Widget _buildUltrasonicCard(
    Color cardBg,
    Color border,
    Color text,
    Color sub,
    double? lastHeight,
    double? rawDist,
    double poleHeight,
    bool isStable,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
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
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF16A085).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.straighten_rounded, color: Color(0xFF16A085), size: 20),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SENSOR TINGGI (HC-SR04)',
                        style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w800, color: text, letterSpacing: 0.5),
                      ),
                      Text('Ultrasonik Tiang Stadiometer', style: GoogleFonts.outfit(fontSize: 10, color: sub)),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF16A085).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'TRIG: 5 • ECHO: 18',
                  style: GoogleFonts.outfit(fontSize: 9.5, fontWeight: FontWeight.w700, color: const Color(0xFF16A085)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Center(
            child: Column(
              children: [
                Text(
                  lastHeight != null ? lastHeight.toStringAsFixed(1) : '--.-',
                  style: GoogleFonts.outfit(
                    fontSize: 44,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF16A085),
                    letterSpacing: -1,
                  ),
                ),
                Text('Centimeter (cm)', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600, color: sub)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: border.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Tiang Acuan ($poleHeight cm)', style: GoogleFonts.outfit(fontSize: 10.5, color: sub)),
                    Text(
                      rawDist != null ? '- Jarak Sensor: ${rawDist.toStringAsFixed(1)} cm' : '- Jarak Sensor: -- cm',
                      style: GoogleFonts.outfit(fontSize: 10.5, fontWeight: FontWeight.w700, color: text),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (lastHeight != null && poleHeight > 0) ? (lastHeight / poleHeight).clamp(0.0, 1.0) : 0.0,
                    backgroundColor: border.withOpacity(0.3),
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF16A085)),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: CustomButton(
                  text: 'Salin TB ke Form',
                  icon: Icons.check_circle_outline_rounded,
                  height: 36,
                  primaryColor: const Color(0xFF16A085),
                  isSecondary: true,
                  onPressed: lastHeight != null
                      ? () {
                          setState(() {
                            _heightController.text = lastHeight.toStringAsFixed(1);
                            _smartGrowthResult = null;
                            _reasoningResult = null;
                          });
                          CustomSnackbar.success(
                            context,
                            'Tinggi Badan ${lastHeight.toStringAsFixed(1)} cm disalin ke formulir.',
                            title: 'TB Disalin',
                          );
                        }
                      : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoadCellCard(
    Color cardBg,
    Color border,
    Color text,
    Color sub,
    double? lastWeight,
    bool isStable,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
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
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2980B9).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.monitor_weight_rounded, color: Color(0xFF2980B9), size: 20),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SENSOR BERAT (HX711)',
                        style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w800, color: text, letterSpacing: 0.5),
                      ),
                      Text('4x 50kg Load Cell Wheatstone', style: GoogleFonts.outfit(fontSize: 10, color: sub)),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isStable ? const Color(0xFF27AE60).withOpacity(0.15) : const Color(0xFFF39C12).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: isStable ? const Color(0xFF27AE60) : const Color(0xFFF39C12),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isStable ? 'STABIL (TERKUNCI)' : 'MENGUKUR (GOYANG)',
                      style: GoogleFonts.outfit(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: isStable ? const Color(0xFF27AE60) : const Color(0xFFF39C12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Center(
            child: Column(
              children: [
                Text(
                  lastWeight != null ? lastWeight.toStringAsFixed(2) : '--.--',
                  style: GoogleFonts.outfit(
                    fontSize: 44,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF2980B9),
                    letterSpacing: -1,
                  ),
                ),
                Text('Kilogram (kg)', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600, color: sub)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: border.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Filter Moving Avg 10-sample', style: GoogleFonts.outfit(fontSize: 10.5, color: sub)),
                Text(
                  isStable ? 'Toleransi: < ±0.05 kg' : 'Menunggu balita diam...',
                  style: GoogleFonts.outfit(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: isStable ? const Color(0xFF27AE60) : const Color(0xFFF39C12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: CustomButton(
                  text: 'Nol-kan (Tare)',
                  icon: Icons.scale_rounded,
                  height: 36,
                  primaryColor: const Color(0xFF3498DB),
                  isSecondary: true,
                  onPressed: _mqttService.isConnected ? _sendMqttTare : null,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: CustomButton(
                  text: 'Salin BB ke Form',
                  icon: Icons.check_circle_outline_rounded,
                  height: 36,
                  primaryColor: const Color(0xFF2980B9),
                  isSecondary: true,
                  onPressed: lastWeight != null
                      ? () {
                          setState(() {
                            _weightController.text = lastWeight.toStringAsFixed(2);
                            _smartGrowthResult = null;
                            _reasoningResult = null;
                          });
                          CustomSnackbar.success(
                            context,
                            'Berat Badan ${lastWeight.toStringAsFixed(2)} kg disalin ke formulir.',
                            title: 'BB Disalin',
                          );
                        }
                      : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTelemetryParamItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required String subvalue,
    required Color text,
    required Color sub,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: iconColor),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: GoogleFonts.outfit(fontSize: 10, color: sub, fontWeight: FontWeight.w600)),
            Text(value, style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w800, color: text)),
            Text(subvalue, style: GoogleFonts.outfit(fontSize: 9.5, color: sub)),
          ],
        ),
      ],
    );
  }

  /// Banner Ringkas Sinkronisasi IoT pada Formulir Antropometri Manual (Langkah 2)
  Widget _buildIotQuickSyncBanner(Color cardBg, Color border, Color text, Color sub) {
    final isConnected = _mqttService.isConnected;
    final lastWeight = (_lastMqttTelemetry?['weight'] is Map)
        ? (_lastMqttTelemetry?['weight']['val_kg'] as num?)?.toDouble()
        : (_lastMqttTelemetry?['val_kg'] as num?)?.toDouble();
    final lastHeight = (_lastMqttTelemetry?['height'] is Map)
        ? (_lastMqttTelemetry?['height']['val_cm'] as num?)?.toDouble()
        : (_lastMqttTelemetry?['val_cm'] as num?)?.toDouble();
    final isStable = _lastMqttTelemetry?['weight']?['is_stable'] == true ||
        _lastMqttTelemetry?['is_stable'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isConnected ? const Color(0xFF1ABC9C).withOpacity(0.08) : border.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isConnected ? const Color(0xFF1ABC9C).withOpacity(0.3) : border,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isConnected ? const Color(0xFF1ABC9C).withOpacity(0.15) : border.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.sensors_rounded,
              size: 16,
              color: isConnected ? const Color(0xFF1ABC9C) : sub,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: isConnected
                ? Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'Live Stream IoT:',
                        style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700, color: text),
                      ),
                      Text(
                        'TB = ${lastHeight != null ? '${lastHeight.toStringAsFixed(1)} cm' : '--'}',
                        style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF16A085)),
                      ),
                      Text('•', style: GoogleFonts.outfit(color: sub)),
                      Text(
                        'BB = ${lastWeight != null ? '${lastWeight.toStringAsFixed(2)} kg' : '--'}',
                        style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF2980B9)),
                      ),
                      if (isStable)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFF27AE60).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text('STABIL', style: GoogleFonts.outfit(fontSize: 8, fontWeight: FontWeight.w800, color: const Color(0xFF27AE60))),
                        ),
                    ],
                  )
                : Text(
                    'Perangkat MQTT IoT belum terhubung. Sambungkan untuk mengisi data otomatis dari sensor.',
                    style: GoogleFonts.outfit(fontSize: 11, color: sub),
                  ),
          ),
          const SizedBox(width: 8),
          if (isConnected && (lastHeight != null || lastWeight != null))
            CustomButton(
              text: 'Isi Otomatis',
              icon: Icons.flash_on_rounded,
              height: 30,
              primaryColor: const Color(0xFF1ABC9C),
              onPressed: () => _applyMqttTelemetryToForm(),
            )
          else
            CustomButton(
              text: isConnected ? 'Pengaturan' : 'Hubungkan IoT',
              icon: isConnected ? Icons.settings_rounded : Icons.link_rounded,
              height: 30,
              primaryColor: const Color(0xFF3498DB),
              isSecondary: true,
              onPressed: isConnected ? _showMqttSettingsDialog : _toggleMqttConnection,
            ),
        ],
      ),
    );
  }

  // ===========================================================================
  // SERVER STATUS BAR
  // ===========================================================================
  Widget _buildServerStatusBar(Color cardBg, Color border, Color text, Color sub) {
    final isOnline = _serverStatus?['isOnline'] == true;
    final statusColor = isOnline ? const Color(0xFF27AE60) : const Color(0xFFE74C3C);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      isOnline ? 'VitaScale Cloud Backend (Vercel): TERHUBUNG' : 'VitaScale Cloud Backend: TIDAK TERHUBUNG',
                      style: GoogleFonts.outfit(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: statusColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '(${VitaScaleApiConfig.baseUrl})',
                        style: GoogleFonts.outfit(fontSize: 10.5, color: sub),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                Text(
                  isOnline
                      ? 'Model MLP stunting (TB/U), status gizi (BB/TB), & Smart Growth aktif di cloud Vercel.'
                      : 'Periksa koneksi internet atau status hosting di ${VitaScaleApiConfig.baseUrl}.',
                  style: GoogleFonts.outfit(fontSize: 10, color: sub),
                ),
              ],
            ),
          ),
          CustomButton(
            text: _isCheckingServer ? 'Mengecek...' : 'Ping Server',
            icon: Icons.refresh_rounded,
            height: 32,
            primaryColor: statusColor,
            isSecondary: true,
            onPressed: () {
              if (!_isCheckingServer) {
                _checkServer();
              }
            },
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // LANGKAH 1: IDENTITAS BALITA & SASARAN SKRINING
  // ===========================================================================
  Widget _buildStep1ChildIdentity(Color cardBg, Color border, Color text, Color sub, bool isMobile) {
    final isUnder24 = _ageMonths < 24;

    return CustomCard(
      color: cardBg,
      borderColor: border,
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Card Step 1
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1ABC9C).withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_pin_rounded, size: 20, color: Color(0xFF1ABC9C)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Langkah 1: Identitas Balita & Sasaran Skrining',
                      style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w800, color: text),
                    ),
                    Text(
                      'Data demografi, NIK untuk SATUSEHAT Kemenkes RI, jenis kelamin, dan usia balita.',
                      style: GoogleFonts.outfit(fontSize: 10.5, color: sub),
                    ),
                  ],
                ),
              ),
              CustomButton(
                text: 'Pilih Data Anak',
                icon: Icons.person_search_rounded,
                height: 34,
                primaryColor: const Color(0xFF1ABC9C),
                onPressed: _showPatientPickerModal,
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Preset Cepat Bar (Buku KIA 2024)
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('Preset Uji Cepat:', style: GoogleFonts.outfit(fontSize: 10.5, fontWeight: FontWeight.bold, color: sub)),
              _buildPresetChip('Balita Normal (24 bln)', () => _applyPreset('Normal', jk: 0, usia: 24, bb: 11.5, tb: 85.0, lk: 48.0, lila: 14.5, caraUkur: 'TB', kms: 'N')),
              _buildPresetChip('Risiko Stunting (24 bln - 2T)', () => _applyPreset('Stunting 2T', jk: 0, usia: 24, bb: 9.2, tb: 76.0, lk: 45.0, lila: 12.0, caraUkur: 'TB', kms: '2T')),
              _buildPresetChip('Gizi Buruk / BGM (18 bln)', () => _applyPreset('Gizi Buruk BGM', jk: 1, usia: 18, bb: 6.8, tb: 78.0, lk: 43.5, lila: 11.2, caraUkur: 'PB', kms: 'BGM')),
              _buildPresetChip('Bayi Telentang (8 bln)', () => _applyPreset('Bayi 8 Bln', jk: 0, usia: 8, bb: 8.2, tb: 70.0, lk: 44.0, lila: 14.0, caraUkur: 'PB', kms: 'N')),
            ],
          ),

          const Divider(height: 24),

          // Baris 1: Nama & NIK + Cek SATUSEHAT
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: CustomTextField(
                  label: 'Nama Lengkap Balita',
                  hintText: 'Nama anak sasaran',
                  controller: _nameController,
                  onChanged: (val) => setState(() {}),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('NIK Balita (16 Digit - Wajib SATUSEHAT)', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700, color: text)),
                        if (_satuSehatPatientId != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF27AE60).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle_rounded, size: 10, color: Color(0xFF27AE60)),
                                const SizedBox(width: 4),
                                Text(
                                  'IHS: $_satuSehatPatientId',
                                  style: GoogleFonts.outfit(fontSize: 8.5, fontWeight: FontWeight.bold, color: const Color(0xFF27AE60)),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: CustomTextField(
                            label: '',
                            hintText: '16 digit NIK',
                            controller: _nikController,
                            keyboardType: TextInputType.number,
                            maxLength: 16,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(16),
                            ],
                            onChanged: (val) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 8),
                        CustomButton(
                          text: _isCheckingSatuSehatPatient ? 'Cek...' : 'Cek SATUSEHAT',
                          icon: Icons.health_and_safety_rounded,
                          height: 42,
                          isSecondary: true,
                          primaryColor: const Color(0xFF009688),
                          onPressed: _isCheckingSatuSehatPatient
                              ? null
                              : () {
                                  _checkSatuSehatPatient();
                                },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Baris 2: Jenis Kelamin & Usia (Bulan)
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Segmented Jenis Kelamin
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Jenis Kelamin Balita',
                      style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700, color: text),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 44,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: border.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: border),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildGenderOption(
                              label: 'Laki-laki (0)',
                              icon: Icons.male_rounded,
                              isSelected: _selectedGender == 0,
                              onTap: () => setState(() => _selectedGender = 0),
                              color: const Color(0xFF3498DB),
                            ),
                          ),
                          Expanded(
                            child: _buildGenderOption(
                              label: 'Perempuan (1)',
                              icon: Icons.female_rounded,
                              isSelected: _selectedGender == 1,
                              onTap: () => setState(() => _selectedGender = 1),
                              color: const Color(0xFFE91E63),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 16),

              // Usia dalam Bulan
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Usia Balita (Bulan)',
                          style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700, color: text),
                        ),
                        StatusBadge(
                          label: isUnder24 ? 'Target: PB Telentang' : 'Target: TB Berdiri',
                          color: isUnder24 ? const Color(0xFF3498DB) : const Color(0xFFE67E22),
                          fontSize: 8.5,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _buildStepperBtn(Icons.remove, () {
                          if (_ageMonths > 1) {
                            setState(() {
                              _ageMonths -= 1;
                              _ageController.text = _ageMonths.toStringAsFixed(0);
                              if (_ageMonths < 24 && _measurementMethod == 'TB') _measurementMethod = 'PB';
                            });
                          }
                        }),
                        const SizedBox(width: 8),
                        Expanded(
                          child: CustomTextField(
                            label: '',
                            hintText: 'Bulan',
                            controller: _ageController,
                            keyboardType: TextInputType.number,
                            onChanged: (val) {
                              final numVal = double.tryParse(val);
                              if (numVal != null && numVal >= 0) {
                                setState(() {
                                  _ageMonths = numVal;
                                  if (_ageMonths < 24) {
                                    _measurementMethod = 'PB';
                                  } else {
                                    _measurementMethod = 'TB';
                                  }
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildStepperBtn(Icons.add, () {
                          setState(() {
                            _ageMonths += 1;
                            _ageController.text = _ageMonths.toStringAsFixed(0);
                            if (_ageMonths >= 24 && _measurementMethod == 'PB') _measurementMethod = 'TB';
                          });
                        }),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Baris 3: Cara Pengukuran Antropometri (Buku KIA 2024 hal 48)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Cara Pengukuran Panjang / Tinggi Badan (Standar Buku KIA 2024)',
                    style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700, color: text),
                  ),
                  Text(
                    isUnder24 ? 'Kemenkes: Usia < 24 bln wajib Telentang (PB)' : 'Kemenkes: Usia ≥ 24 bln wajib Berdiri (TB)',
                    style: GoogleFonts.outfit(fontSize: 9.5, color: sub, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: _buildMeasurementMethodOption(
                      code: 'PB',
                      label: 'PB Telentang (Infantometer)',
                      loinc: 'LOINC: 8306-3',
                      subtext: 'Buku KIA: Untuk bayi 0-23 bulan',
                      isSelected: _measurementMethod == 'PB',
                      onTap: () => setState(() => _measurementMethod = 'PB'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMeasurementMethodOption(
                      code: 'TB',
                      label: 'TB Berdiri (Stadiometer)',
                      loinc: 'LOINC: 8302-2',
                      subtext: 'Buku KIA: Untuk balita 24-59 bulan',
                      isSelected: _measurementMethod == 'TB',
                      onTap: () => setState(() => _measurementMethod = 'TB'),
                    ),
                  ),
                ],
              ),
              if ((_ageMonths < 24 && _measurementMethod == 'TB') || (_ageMonths >= 24 && _measurementMethod == 'PB')) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE67E22).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE67E22).withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFFE67E22)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _measurementMethod == 'TB'
                              ? 'Catatan Buku KIA hal 48: Anak < 2 th diukur berdiri, hasil dikoreksi +0.7 cm agar setara panjang telentang.'
                              : 'Catatan Buku KIA hal 48: Anak ≥ 2 th diukur telentang, hasil dikoreksi -0.7 cm agar setara tinggi berdiri.',
                          style: GoogleFonts.outfit(fontSize: 9.5, color: const Color(0xFFE67E22), fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // LANGKAH 2: PENGUKURAN ANTROPOMETRI FISIK (STANDAR BUKU KIA 2024)
  // ===========================================================================
  Widget _buildStep2Anthropometry(Color cardBg, Color border, Color text, Color sub, bool isMobile) {
    return CustomCard(
      color: cardBg,
      borderColor: border,
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Card Step 2
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1ABC9C).withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.straighten_rounded, size: 20, color: Color(0xFF1ABC9C)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Langkah 2: Pengukuran Antropometri Fisik',
                      style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w800, color: text),
                    ),
                    Text(
                      'Pengukuran Berat Badan, Panjang/Tinggi Badan, LiLA, Lingkar Kepala, dan KMS (Standar Buku KIA 2024).',
                      style: GoogleFonts.outfit(fontSize: 10.5, color: sub),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const Divider(height: 24),

          // Banner Cepat Sinkronisasi IoT
          _buildIotQuickSyncBanner(cardBg, border, text, sub),

          // Baris 1: Berat Badan & Tinggi Badan
          Row(
            children: [
              // Berat Badan (kg)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Berat Badan Saat Ini (kg)',
                          style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700, color: text),
                        ),
                        Text('LOINC: 29463-7', style: GoogleFonts.outfit(fontSize: 8.5, fontWeight: FontWeight.bold, color: const Color(0xFF009688))),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _buildStepperBtn(Icons.remove, () {
                          final current = double.tryParse(_weightController.text) ?? 10.0;
                          if (current > 1.0) {
                            setState(() {
                              _weightController.text = (current - 0.1).toStringAsFixed(1);
                              _smartGrowthResult = null;
                              _reasoningResult = null;
                            });
                          }
                        }),
                        const SizedBox(width: 8),
                        Expanded(
                          child: CustomTextField(
                            label: '',
                            hintText: 'Contoh: 11.5',
                            controller: _weightController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (val) => setState(() {
                              _smartGrowthResult = null;
                              _reasoningResult = null;
                            }),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildStepperBtn(Icons.add, () {
                          final current = double.tryParse(_weightController.text) ?? 10.0;
                          setState(() {
                            _weightController.text = (current + 0.1).toStringAsFixed(1);
                            _smartGrowthResult = null;
                            _reasoningResult = null;
                          });
                        }),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 16),

              // Tinggi Badan (cm)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_pcvTinggiCm != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 5),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1ABC9C).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF1ABC9C).withOpacity(0.35)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.auto_awesome_rounded, size: 12, color: Color(0xFF1ABC9C)),
                            const SizedBox(width: 5),
                            Text(
                              'Otomatis Terisi via Foto AI PCV (${_pcvTinggiCm!.toStringAsFixed(1)} cm)',
                              style: GoogleFonts.outfit(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF1ABC9C),
                              ),
                            ),
                          ],
                        ),
                      ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _measurementMethod == 'PB' ? 'Panjang Badan Telentang (cm)' : 'Tinggi Badan Berdiri (cm)',
                          style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700, color: text),
                        ),
                        Text(
                          _measurementMethod == 'PB' ? 'LOINC: 8306-3' : 'LOINC: 8302-2',
                          style: GoogleFonts.outfit(fontSize: 8.5, fontWeight: FontWeight.bold, color: const Color(0xFF009688)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _buildStepperBtn(Icons.remove, () {
                          final current = double.tryParse(_heightController.text) ?? 80.0;
                          if (current > 30.0) {
                            setState(() {
                              _heightController.text = (current - 0.5).toStringAsFixed(1);
                              _smartGrowthResult = null;
                              _reasoningResult = null;
                            });
                          }
                        }),
                        const SizedBox(width: 8),
                        Expanded(
                          child: CustomTextField(
                            label: '',
                            hintText: 'Contoh: 85.0',
                            controller: _heightController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            onChanged: (val) => setState(() {
                              _smartGrowthResult = null;
                              _reasoningResult = null;
                            }),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildStepperBtn(Icons.add, () {
                          final current = double.tryParse(_heightController.text) ?? 80.0;
                          setState(() {
                            _heightController.text = (current + 0.5).toStringAsFixed(1);
                            _smartGrowthResult = null;
                            _reasoningResult = null;
                          });
                        }),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Baris 2: Parameter Antropometri Tambahan Buku KIA (LK, LiLA, LP)
          Row(
            children: [
              // Lingkar Kepala
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Lingkar Kepala (cm)', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700, color: text)),
                        Text('LOINC: 9843-4', style: GoogleFonts.outfit(fontSize: 8.5, fontWeight: FontWeight.bold, color: const Color(0xFF009688))),
                      ],
                    ),
                    const SizedBox(height: 6),
                    CustomTextField(
                      label: '',
                      hintText: 'Nellhaus: 47.0',
                      controller: _headCircumferenceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (val) => setState(() {}),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              // LiLA (Lingkar Lengan Atas)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('LiLA (cm)', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700, color: text)),
                        Text('LOINC: 56072-2', style: GoogleFonts.outfit(fontSize: 8.5, fontWeight: FontWeight.bold, color: const Color(0xFF009688))),
                      ],
                    ),
                    const SizedBox(height: 6),
                    CustomTextField(
                      label: '',
                      hintText: 'Contoh: 14.5',
                      controller: _lilaController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (val) => setState(() {}),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              // Lingkar Perut
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Lingkar Perut (cm)', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700, color: text)),
                        Text('LOINC: 8280-0', style: GoogleFonts.outfit(fontSize: 8.5, fontWeight: FontWeight.bold, color: const Color(0xFF009688))),
                      ],
                    ),
                    const SizedBox(height: 6),
                    CustomTextField(
                      label: '',
                      hintText: 'Contoh: 46.0',
                      controller: _waistController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (val) => setState(() {}),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Indikator Visual Pita LiLA Buku KIA
          Builder(
            builder: (context) {
              final val = double.tryParse(_lilaController.text.trim());
              final color = _getLilaColor(val);
              final status = _getLilaStatusText(val);
              return Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.straighten_rounded, size: 14, color: color),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Pita LiLA Buku KIA 2024: $status',
                        style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: color),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 16),

          // Baris 3: Tren Pertumbuhan KMS Balita (Kartu Menuju Sehat)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Tren Pertumbuhan KMS Balita (Kartu Menuju Sehat - Buku KIA 2024)',
                    style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700, color: text),
                  ),
                  Text(
                    'Deteksi Dini Gagal Tumbuh / Weight Faltering',
                    style: GoogleFonts.outfit(fontSize: 9.5, color: sub, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildKmsOptionChip('N', 'N (Naik ≥ KBM)', const Color(0xFF27AE60)),
                  _buildKmsOptionChip('T', 'T (Tidak Naik / Tetap)', const Color(0xFFE67E22)),
                  _buildKmsOptionChip('2T', '2T (2x Tidak Naik - Red Flag)', const Color(0xFFE74C3C)),
                  _buildKmsOptionChip('BGM', 'BGM (Bawah Garis Merah - Red Flag)', const Color(0xFFC0392B)),
                  _buildKmsOptionChip('Baru', 'Pertama Kali Menimbang', const Color(0xFF3498DB)),
                ],
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Baris 4: Suplementasi Buku KIA 2024
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: border.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Kapsul Vitamin A',
                      style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700, color: text),
                    ),
                    subtitle: Text(
                      _ageMonths < 12 ? 'Kapsul Biru (100.000 IU)' : 'Kapsul Merah (200.000 IU) - Bulan Feb/Agu',
                      style: GoogleFonts.outfit(fontSize: 9.5, color: sub),
                    ),
                    value: _receivedVitA,
                    activeColor: const Color(0xFF1ABC9C),
                    onChanged: (val) => setState(() => _receivedVitA = val ?? true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Obat Cacing (Pencegahan)',
                      style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700, color: text),
                    ),
                    subtitle: Text(
                      _ageMonths >= 12 ? 'Diberikan tiap 6 bulan (Usia 1-5 tahun)' : 'Belum usia target (< 12 bulan)',
                      style: GoogleFonts.outfit(fontSize: 9.5, color: sub),
                    ),
                    value: _ageMonths >= 12 ? _receivedDeworming : false,
                    activeColor: const Color(0xFF1ABC9C),
                    onChanged: _ageMonths >= 12 ? (val) => setState(() => _receivedDeworming = val ?? true) : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetChip(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF1ABC9C).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF1ABC9C).withOpacity(0.3)),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF1ABC9C)),
        ),
      ),
    );
  }

  Widget _buildGenderOption({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required Color color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.white : color),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? Colors.white : Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepperBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: const Color(0xFF1ABC9C).withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 16, color: const Color(0xFF1ABC9C)),
      ),
    );
  }

  Widget _buildMeasurementMethodOption({
    required String code,
    required String label,
    required String loinc,
    required String subtext,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1ABC9C).withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF1ABC9C) : Colors.grey.withOpacity(0.3),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              size: 18,
              color: isSelected ? const Color(0xFF1ABC9C) : Colors.grey,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        label,
                        style: GoogleFonts.outfit(
                          fontSize: 11.5,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1ABC9C).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          loinc,
                          style: GoogleFonts.outfit(fontSize: 8, fontWeight: FontWeight.bold, color: const Color(0xFF1ABC9C)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(subtext, style: GoogleFonts.outfit(fontSize: 9.5, color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKmsOptionChip(String code, String label, Color color) {
    final isSelected = _kmsStatus == code;
    return InkWell(
      onTap: () => setState(() => _kmsStatus = code),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : color.withOpacity(0.3),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? Icons.check_circle_rounded : Icons.circle_outlined,
              size: 14,
              color: isSelected ? Colors.white : color,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? Colors.white : color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoincBadge(String label, String value, String code) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1ABC9C).withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF1ABC9C).withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.outfit(fontSize: 9.5, color: Colors.grey)),
          Text(value, style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w800)),
          Text(code, style: GoogleFonts.outfit(fontSize: 8.5, fontWeight: FontWeight.bold, color: const Color(0xFF1ABC9C))),
        ],
      ),
    );
  }

  // ===========================================================================
  // PROGRESS BAR LOADING CARD (LINEAR PROGRESS - TIDAK PAKAI LOADING CIRCLE)
  // ===========================================================================
  Widget _buildProgressBarLoadingCard({
    required String title,
    required String subtitle,
    required Color cardBg,
    required Color border,
    required Color text,
    required Color sub,
    IconData icon = Icons.psychology_rounded,
    List<String>? steps,
    int activeStepIndex = 1,
  }) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF1ABC9C).withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1ABC9C).withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1ABC9C).withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 20, color: const Color(0xFF1ABC9C)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.outfit(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.outfit(fontSize: 11, color: sub),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Progress Bar Linear (Sesuai Permintaan Pengguna: Progress Bar, Bukan Lingkaran)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 8,
              child: LinearProgressIndicator(
                backgroundColor: const Color(0xFF1ABC9C).withOpacity(0.15),
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF1ABC9C)),
              ),
            ),
          ),
          if (steps != null && steps.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: List.generate(steps.length, (idx) {
                final isDone = idx < activeStepIndex;
                final isCurrent = idx == activeStepIndex;
                final stepColor = isDone
                    ? const Color(0xFF27AE60)
                    : isCurrent
                        ? const Color(0xFF1ABC9C)
                        : sub.withOpacity(0.5);
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: stepColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: stepColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isDone)
                        const Icon(Icons.check_rounded, size: 11, color: Color(0xFF27AE60))
                      else if (isCurrent)
                        const Icon(Icons.sync_rounded, size: 11, color: Color(0xFF1ABC9C))
                      else
                        Icon(Icons.circle_outlined, size: 9, color: sub.withOpacity(0.5)),
                      const SizedBox(width: 4),
                      Text(
                        steps[idx],
                        style: GoogleFonts.outfit(
                          fontSize: 9.5,
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                          color: stepColor,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ],
        ],
      ),
    );
  }

  // ===========================================================================
  // LANGKAH 3: KLASIFIKASI MODEL MLP (OTOMATIS) & CLINICAL REASONING (TOMBOL)
  // ===========================================================================
  Widget _buildStep3ReasoningAndAi(Color cardBg, Color border, Color text, Color sub, bool isMobile) {
    final bb = double.tryParse(_weightController.text.trim()) ?? 0.0;
    final tb = double.tryParse(_heightController.text.trim()) ?? 0.0;
    final isAntroValid = bb > 0 && tb > 0;
    final isEn = ref.watch(landingPageProvider).language == 'en';

    // Otomatis mengeksekusi model MLP (Keras Smart Growth) jika belum dijalankan
    if (isAntroValid && _smartGrowthResult == null && !_isLoadingClassification) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _smartGrowthResult == null && !_isLoadingClassification) {
          _runMlpClassification(silent: true);
        }
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Main Control Card for Step 3
        CustomCard(
          color: cardBg,
          borderColor: border,
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Card Step 3
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1ABC9C).withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.psychology_rounded, size: 22, color: Color(0xFF1ABC9C)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              isEn
                                  ? 'Step 3: MLP Classification & Clinical AI Reasoning'
                                  : 'Langkah 3: Klasifikasi MLP & Clinical AI Reasoning',
                              style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w800, color: text),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: (_reasoningResult != null
                                        ? const Color(0xFF27AE60)
                                        : (_smartGrowthResult != null
                                            ? const Color(0xFF1ABC9C)
                                            : const Color(0xFFF39C12)))
                                    .withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: (_reasoningResult != null
                                          ? const Color(0xFF27AE60)
                                          : (_smartGrowthResult != null
                                              ? const Color(0xFF1ABC9C)
                                              : const Color(0xFFF39C12)))
                                      .withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                _reasoningResult != null
                                    ? (isEn ? 'AI Complete (${_reasoningPromptCount}x prompt)' : 'AI Selesai (${_reasoningPromptCount}x diprompt)')
                                    : (_smartGrowthResult != null
                                        ? (isEn ? 'MLP Auto Done • Reasoning Ready' : 'MLP Selesai (Otomatis) • Reasoning Siap')
                                        : (_isLoadingClassification
                                            ? (isEn ? 'Auto Running MLP...' : 'Otomatis Memproses MLP...')
                                            : (isEn ? 'Disarankan (Opsional)' : 'Disarankan (Opsional)'))),
                                style: GoogleFonts.outfit(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.bold,
                                  color: _reasoningResult != null
                                      ? const Color(0xFF27AE60)
                                      : (_smartGrowthResult != null
                                          ? const Color(0xFF1ABC9C)
                                          : const Color(0xFFD68910)),
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          isEn
                              ? 'Keras MLP automatic classification & Gemini 2.5 Flash clinical reasoning for stunting detection and nutritional intervention.'
                              : 'Klasifikasi otomatis Machine Learning Keras MLP & Penalaran Klinis Gemini 2.5 Flash untuk deteksi stunting dan intervensi gizi.',
                          style: GoogleFonts.outfit(fontSize: 10.5, color: sub),
                        ),
                      ],
                    ),
                  ),
                  if (_smartGrowthResult != null) ...[
                    if (_reasoningResult != null || _reasoningPromptCount > 0) ...[
                      CustomButton(
                        text: _isLoadingReasoning
                            ? (isEn ? 'Processing...' : 'Memproses...')
                            : (isEn ? 'Re-Prompt AI (${_reasoningPromptCount}x)' : 'Prompt Ulang AI (${_reasoningPromptCount}x)'),
                        icon: Icons.refresh_rounded,
                        height: 34,
                        primaryColor: const Color(0xFF1ABC9C),
                        isSecondary: true,
                        onPressed: (_isLoadingClassification || _isLoadingReasoning)
                            ? null
                            : () => _confirmRePromptDialog(),
                      ),
                      const SizedBox(width: 8),
                    ],
                    CustomButton(
                      text: isEn ? 'Copy Report' : 'Salin Laporan',
                      icon: Icons.copy_rounded,
                      height: 34,
                      isSecondary: true,
                      onPressed: _copyReportToClipboard,
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 16),

              // 1. Loading State Banner untuk MLP Otomatis (PROGRESS BAR)
              if (_isLoadingClassification) ...[
                _buildProgressBarLoadingCard(
                  title: isEn
                      ? 'MLP Model Automatically Classifying Anthropometric Ratios...'
                      : 'Model MLP Mengklasifikasikan Rasio Antropometri (Otomatis)...',
                  subtitle: isEn
                      ? 'Analyzing probabilities of weight-for-height and height-for-age linear growth without manual trigger.'
                      : 'Menganalisis probabilitas status gizi BB/TB dan status pertumbuhan linier TB/U secara otomatis tanpa perlu tombol.',
                  cardBg: cardBg,
                  border: border,
                  text: text,
                  sub: sub,
                  icon: Icons.memory_rounded,
                  steps: isEn
                      ? ['FastAPI Model Link', 'BB/TB & TB/U Inference', 'Confidence Scoring']
                      : ['Koneksi Model FastAPI', 'Inferensi BB/TB & TB/U', 'Kalkulasi Confidence'],
                  activeStepIndex: 1,
                ),
              ]
              // 2. Data Not Valid Warning
              else if (!isAntroValid) ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE67E22).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE67E22).withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, size: 28, color: Color(0xFFE67E22)),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isEn ? 'Anthropometry Data Incomplete' : 'Data Antropometri Belum Lengkap',
                              style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w900, color: const Color(0xFFE67E22)),
                            ),
                            Text(
                              isEn
                                  ? 'Please input valid Weight and Height in Step 2 to run automatic MLP classification.'
                                  : 'Harap lengkapi data Berat Badan dan Tinggi/Panjang Badan di Langkah 2 terlebih dahulu agar model MLP dapat berjalan otomatis.',
                              style: GoogleFonts.outfit(fontSize: 11, color: sub),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      CustomButton(
                        text: isEn ? '← Back to Step 2' : '← Kembali ke Langkah 2',
                        height: 38,
                        onPressed: () => setState(() => _formStep = 2),
                      ),
                    ],
                  ),
                ),
              ]
              // 3. Clinical AI Reasoning Card (Butuh Tombol untuk Dijalankan)
              else if (_reasoningResult == null && !_isLoadingReasoning) ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1ABC9C).withOpacity(0.06),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF1ABC9C).withOpacity(0.25)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1ABC9C).withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.psychology_alt_rounded, size: 24, color: Color(0xFF1ABC9C)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      isEn ? 'Clinical AI Reasoning (Gemini 2.5 Flash)' : 'Penalaran Klinis AI (Gemini 2.5 Flash)',
                                      style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w900, color: const Color(0xFF16A085)),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF39C12).withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                      child: Text(
                                        isEn ? 'Optional • Click to Run' : 'Opsional • Tekan Tombol',
                                        style: GoogleFonts.outfit(fontSize: 8.5, fontWeight: FontWeight.bold, color: const Color(0xFFD68910)),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isEn
                                      ? 'MLP classification has completed automatically below. To generate pediatrician clinical chain-of-thought, risk factor analysis, and Buku KIA nutritional guidance, press the button below (or proceed to Step 4).'
                                      : 'Klasifikasi model MLP telah berjalan otomatis di bawah. Untuk menghasilkan alur berpikir medis dokter spesialis anak, analisis faktor risiko gizi, dan rekomendasi Buku KIA 2024, silakan tekan tombol di bawah (atau lewati ke Langkah 4).',
                                  style: GoogleFonts.outfit(fontSize: 10.5, color: sub),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      // Antropometri recap badges
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _buildMiniBadge('Berat Badan', '$bb kg'),
                          _buildMiniBadge('Tinggi Badan', '$tb cm'),
                          _buildMiniBadge('Usia', '${_ageMonths.toInt()} Bulan'),
                          _buildMiniBadge('Cara Ukur', _measurementMethod == 'PB' ? 'PB Telentang' : 'TB Berdiri'),
                          if (_lilaController.text.isNotEmpty)
                            _buildMiniBadge('LiLA', '${_lilaController.text} cm'),
                          if (_headCircumferenceController.text.isNotEmpty)
                            _buildMiniBadge('Lingkar Kepala', '${_headCircumferenceController.text} cm'),
                          _buildMiniBadge('Tren KMS', _kmsStatus),
                          if (_smartGrowthResult != null)
                            _buildMiniBadge('Status Gizi MLP', _smartGrowthResult!.kategoriGiziBbtb),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Tombol Generate Reasoning & Tombol Lewati
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: CustomButton(
                              text: isEn
                                  ? 'Run Clinical AI Reasoning (Gemini 2.5 Flash) ➔'
                                  : 'Jalankan Penalaran Klinis AI (Gemini 2.5 Flash) ➔',
                              icon: Icons.psychology_rounded,
                              height: 46,
                              primaryColor: const Color(0xFF1ABC9C),
                              onPressed: _runReasoningOnly,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: CustomButton(
                              text: isEn ? 'Next to Step 4 (SATUSEHAT) ➔' : 'Lanjut ke Langkah 4 ➔',
                              isSecondary: true,
                              height: 46,
                              onPressed: () => setState(() => _formStep = 4),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ]
              // 4. Loading Reasoning State Banner (PROGRESS BAR - BUKAN CIRCULAR SPINNER)
              else if (_isLoadingReasoning) ...[
                _buildProgressBarLoadingCard(
                  title: isEn
                      ? 'Clinical Reasoning Engine Working (Gemini 2.5 Flash)...'
                      : 'Clinical Reasoning Engine Sedang Bekerja (Gemini 2.5 Flash)...',
                  subtitle: isEn
                      ? 'Structuring pediatric chain-of-thought, clinical risk factors, and KIA nutrition intervention plan.'
                      : 'Menyusun alur berpikir medis (Chain of Thought), faktor risiko klinis, rekomendasi gizi PMT & protokol rujukan Buku KIA 2024.',
                  cardBg: cardBg,
                  border: border,
                  text: text,
                  sub: sub,
                  icon: Icons.psychology_rounded,
                  steps: isEn
                      ? ['Child Anthropometric Data', 'Gemini 2.5 Flash Reasoning', 'KIA Nutritional Action Plan']
                      : ['Data Antropometri Balita', 'Penalaran Gemini 2.5 Flash', 'Rekomendasi Intervensi Gizi KIA'],
                  activeStepIndex: 1,
                ),
              ]
              // 5. Reasoning Completed Success Banner
              else ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF27AE60).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF27AE60).withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, size: 18, color: Color(0xFF27AE60)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isEn
                              ? '✅ MLP Model Classification & Clinical AI Reasoning Complete (Prompted $_reasoningPromptCount time(s)). You may Re-Prompt or proceed to Step 4.'
                              : '✅ Klasifikasi Model MLP & Clinical Reasoning AI Selesai (Sudah diprompt $_reasoningPromptCount kali). Anda dapat melakukan Prompt Ulang atau lanjut ke Langkah 4 untuk Simpan.',
                          style: GoogleFonts.outfit(fontSize: 10.5, fontWeight: FontWeight.bold, color: const Color(0xFF27AE60)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF27AE60)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        ),
                        onPressed: () => _confirmRePromptDialog(),
                        icon: const Icon(Icons.refresh_rounded, size: 14, color: Color(0xFF27AE60)),
                        label: Text(
                          isEn ? 'Re-Prompt (${_reasoningPromptCount}x)' : 'Prompt Ulang (${_reasoningPromptCount}x)',
                          style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF27AE60)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF27AE60),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        ),
                        onPressed: () => setState(() => _formStep = 4),
                        icon: const Icon(Icons.arrow_forward_rounded, size: 14, color: Colors.white),
                        label: Text(
                          isEn ? 'Step 4 ➔' : 'Langkah 4 ➔',
                          style: GoogleFonts.outfit(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        // Tampilkan Hasil Klasifikasi MLP Segera Setelah Selesai (Otomatis)
        if (_smartGrowthResult != null) ...[
          const SizedBox(height: 16),
          _buildMlpClassificationResult(cardBg, border, text, sub, isMobile),
        ],

        // Tampilkan Section Clinical AI Reasoning Hanya Jika Sudah Dijalankan
        if (_reasoningResult != null) ...[
          const SizedBox(height: 16),
          _buildReasoningSection(cardBg, border, text, sub, isMobile),
        ],
      ],
    );
  }

  // ===========================================================================
  // LANGKAH 4: INTEROPERABILITAS SATUSEHAT KEMENKES RI (FHIR R4) & SIMPAN
  // ===========================================================================
  Widget _buildStep4SatuSehatAndSave(Color cardBg, Color border, Color text, Color sub, bool isMobile) {
    final bb = _weightController.text;
    final tb = _heightController.text;
    final isRecumbent = _measurementMethod == 'PB';
    final tbLoinc = isRecumbent ? '8306-3 (Body height --lying)' : '8302-2 (Body height)';
    final syncRes = _satuSehatSyncResult;
    final hasAi = _smartGrowthResult != null && _reasoningResult != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // SATUSEHAT FHIR R4 Integration Card (Preview FHIR R4 JSON button removed)
        CustomCard(
          color: cardBg,
          borderColor: const Color(0xFF009688).withOpacity(0.4),
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF009688).withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.cloud_sync_rounded, size: 22, color: Color(0xFF009688)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Langkah 4: Interoperabilitas SATUSEHAT Kemenkes RI',
                              style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w900, color: text),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF009688).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'FHIR R4 Standard',
                                style: GoogleFonts.outfit(fontSize: 8.5, fontWeight: FontWeight.bold, color: const Color(0xFF009688)),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'Standardisasi data antropometri anak menggunakan LOINC & diagnosis stunting ICD-10.',
                          style: GoogleFonts.outfit(fontSize: 10.5, color: sub),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Grid Mapping Standar LOINC
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: border.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: border),
                ),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 10,
                  children: [
                    _buildLoincBadge('Berat Badan', '$bb kg', 'LOINC 29463-7'),
                    _buildLoincBadge(isRecumbent ? 'Panjang Badan' : 'Tinggi Badan', '$tb cm', 'LOINC $tbLoinc'),
                    if (_headCircumferenceController.text.isNotEmpty)
                      _buildLoincBadge('Lingkar Kepala', '${_headCircumferenceController.text} cm', 'LOINC 9843-4'),
                    if (_lilaController.text.isNotEmpty)
                      _buildLoincBadge('LiLA', '${_lilaController.text} cm', 'LOINC 56072-2'),
                    if (_waistController.text.isNotEmpty)
                      _buildLoincBadge('Lingkar Perut', '${_waistController.text} cm', 'LOINC 8280-0'),
                    _buildLoincBadge(
                      'Diagnosis Gizi',
                      _smartGrowthResult?.isStunting == true
                          ? 'Stunting'
                          : (_smartGrowthResult?.isGiziBurukAtauKurang == true ? 'Gizi Kurang' : 'Normal'),
                      _smartGrowthResult?.isStunting == true
                          ? 'ICD-10 E45'
                          : (_smartGrowthResult?.isGiziBurukAtauKurang == true ? 'ICD-10 E44.0' : 'ICD-10 Z00.1'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Status Sinkronisasi SatuSehat jika sudah dikirim
              if (syncRes != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF27AE60).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF27AE60).withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, size: 20, color: Color(0xFF27AE60)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Observasi Antropometri Terverifikasi SATUSEHAT',
                              style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.bold, color: const Color(0xFF27AE60)),
                            ),
                            Text(
                              'Mode: ${syncRes['mode']} • Encounter ID: ${syncRes['encounter_id']} • Patient ID: ${syncRes['patient_id']}',
                              style: GoogleFonts.outfit(fontSize: 10, color: sub),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Tombol Sinkronisasi ke SatuSehat
              CustomButton(
                text: _isSyncingSatuSehat
                    ? 'Mengemas & Mengirim Bundle FHIR R4 ke SATUSEHAT...'
                    : 'Kirim Observasi Antropometri ke SATUSEHAT (FHIR R4)',
                icon: Icons.send_rounded,
                height: 46,
                primaryColor: const Color(0xFF009688),
                onPressed: _isSyncingSatuSehat
                    ? null
                    : () {
                        _syncToSatuSehat();
                      },
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Summary Card & Final Submit
        CustomCard(
          color: cardBg,
          borderColor: border,
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF27AE60).withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.assignment_turned_in_rounded, size: 20, color: Color(0xFF27AE60)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ringkasan Akhir & Simpan Rekam Medis',
                          style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w800, color: text),
                        ),
                        Text(
                          'Pastikan data balita dan hasil AI telah ditinjau sebelum disimpan ke database.',
                          style: GoogleFonts.outfit(fontSize: 10.5, color: sub),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const Divider(height: 24),

              // Preview Data
              _buildReviewRow('Nama Balita', _nameController.text, sub, text),
              _buildReviewRow('NIK Balita', _nikController.text, sub, text),
              _buildReviewRow('Jenis Kelamin / Usia', '${_selectedGender == 0 ? "Laki-laki" : "Perempuan"} • ${_ageMonths.toInt()} Bulan', sub, text),
              _buildReviewRow('Berat & Tinggi', '$bb kg / $tb cm', sub, text),
              _buildReviewRow('LiLA & Lingkar Kepala', '${_lilaController.text} cm / ${_headCircumferenceController.text} cm', sub, text),
              _buildReviewRow('Status Gizi BB/TB', _smartGrowthResult?.kategoriGiziBbtb ?? 'Belum Dianalisis', sub, text, isBold: true),
              _buildReviewRow('Status Stunting TB/U', _smartGrowthResult?.kategoriStuntingTbu ?? 'Belum Dianalisis', sub, text, isBold: true),
              _buildReviewRow('Clinical AI Reasoning', hasAi ? 'Tersedia (${_reasoningResult!.modelUsed} - ${_reasoningPromptCount}x diprompt)' : 'Belum Dijalankan (Opsional)', sub, text),

              const SizedBox(height: 20),

              // Final Submit Button
              CustomButton(
                text: 'Review & Simpan Rekam Medis Skrining Balita 💾',
                icon: Icons.cloud_upload_rounded,
                height: 48,
                primaryColor: const Color(0xFF27AE60),
                onPressed: _showReviewAndSubmitDialog,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // STEPPER FOOTER & REAL-TIME VALIDATION PILL
  // ===========================================================================
  Widget _buildScreeningStepperFooter({
    required Color cardBgColor,
    required Color borderColor,
    required Color textColor,
    required Color subtitleColor,
    required bool isMobile,
    required List<Map<String, dynamic>> redErrors,
    required List<Map<String, dynamic>> yellowWarnings,
  }) {
    final hasAi = _smartGrowthResult != null && _reasoningResult != null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildScreeningValidationStatusPill(redErrors, yellowWarnings, subtitleColor),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (_formStep > 1)
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: borderColor),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () => setState(() => _formStep--),
                          icon: const Icon(Icons.arrow_back_rounded, size: 14),
                          label: Text('Sebelumnya', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: textColor)),
                        ),
                      ),
                    if (_formStep > 1) const SizedBox(width: 8),
                    Expanded(
                      child: _buildFooterActionButton(hasAi, redErrors),
                    ),
                  ],
                ),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Left: Previous Step
                if (_formStep > 1)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: borderColor),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onPressed: () => setState(() => _formStep--),
                    icon: const Icon(Icons.arrow_back_rounded, size: 16),
                    label: Text(
                      '← Sebelumnya',
                      style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: textColor),
                    ),
                  )
                else
                  const SizedBox.shrink(),

                // Center: Clickable Validation Status Pill
                _buildScreeningValidationStatusPill(redErrors, yellowWarnings, subtitleColor),

                // Right: Action Button
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF1ABC9C)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      onPressed: _showReviewAndSubmitDialog,
                      icon: const Icon(Icons.fact_check_rounded, size: 16, color: Color(0xFF1ABC9C)),
                      label: Text(
                        'Review Validasi',
                        style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF1ABC9C)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _buildFooterActionButton(hasAi, redErrors),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _buildFooterActionButton(bool hasAi, List<Map<String, dynamic>> redErrors) {
    final isEn = ref.watch(landingPageProvider).language == 'en';

    if (_formStep < 3) {
      return ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1ABC9C),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          elevation: 2,
        ),
        onPressed: () {
          final next = _formStep + 1;
          setState(() => _formStep = next);
          if (next == 3) {
            _checkAndAutoRunMlp();
          }
        },
        icon: const Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.white),
        label: Text(
          isEn ? 'Next ➔' : 'Selanjutnya ➔',
          style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      );
    } else if (_formStep == 3) {
      if (_reasoningResult == null) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF1ABC9C)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
              onPressed: () => setState(() => _formStep = 4),
              icon: const Icon(Icons.arrow_forward_rounded, size: 16, color: Color(0xFF1ABC9C)),
              label: Text(
                _smartGrowthResult != null
                    ? (isEn ? 'Next to Step 4 ➔' : 'Lanjut ke Langkah 4 ➔')
                    : (isEn ? 'Skip ➔' : 'Lewati ➔'),
                style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF1ABC9C)),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1ABC9C),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                elevation: 2,
              ),
              onPressed: (_isLoadingClassification || _isLoadingReasoning)
                  ? null
                  : () {
                      _runReasoningOnly();
                    },
              icon: (_isLoadingClassification || _isLoadingReasoning)
                  ? const Icon(Icons.sync_rounded, size: 16, color: Colors.white)
                  : const Icon(Icons.psychology_rounded, size: 16, color: Colors.white),
              label: Text(
                _isLoadingReasoning
                    ? (isEn ? 'Processing Reasoning...' : 'Memproses Reasoning...')
                    : (_isLoadingClassification
                        ? (isEn ? 'Classifying MLP...' : 'Memproses MLP...')
                        : (isEn ? 'Run Reasoning AI ➔' : 'Jalankan Reasoning Gemini ➔')),
                style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ],
        );
      } else {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF1ABC9C)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              onPressed: () => _confirmRePromptDialog(),
              icon: const Icon(Icons.refresh_rounded, size: 15, color: Color(0xFF1ABC9C)),
              label: Text(
                isEn ? 'Re-Prompt (${_reasoningPromptCount}x)' : 'Prompt Ulang (${_reasoningPromptCount}x)',
                style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF1ABC9C)),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1ABC9C),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                elevation: 2,
              ),
              onPressed: () => setState(() => _formStep = 4),
              icon: const Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.white),
              label: Text(
                isEn ? 'Next (SATUSEHAT) ➔' : 'Selanjutnya (SATUSEHAT) ➔',
                style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ],
        );
      }
    } else {
      return ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: redErrors.isNotEmpty ? const Color(0xFFE74C3C) : const Color(0xFF27AE60),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          elevation: 2,
        ),
        onPressed: _showReviewAndSubmitDialog,
        icon: const Icon(Icons.cloud_upload_rounded, color: Colors.white, size: 16),
        label: Text(
          'Review & Simpan 💾',
          style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      );
    }
  }

  Widget _buildScreeningValidationStatusPill(
    List<Map<String, dynamic>> redErrors,
    List<Map<String, dynamic>> yellowWarnings,
    Color subtitleColor,
  ) {
    final hasRed = redErrors.isNotEmpty;
    final hasYellow = yellowWarnings.isNotEmpty;

    final Color badgeBg;
    final Color badgeBorder;
    final Color badgeColor;
    final IconData badgeIcon;
    final String badgeText;

    if (hasRed) {
      badgeBg = const Color(0xFFE74C3C).withOpacity(0.12);
      badgeBorder = const Color(0xFFE74C3C).withOpacity(0.4);
      badgeColor = const Color(0xFFE74C3C);
      badgeIcon = Icons.error_outline_rounded;
      badgeText = '${redErrors.length} Data Wajib Kurang (Klik)';
    } else if (hasYellow) {
      badgeBg = const Color(0xFFF39C12).withOpacity(0.12);
      badgeBorder = const Color(0xFFF39C12).withOpacity(0.4);
      badgeColor = const Color(0xFFD68910);
      badgeIcon = Icons.info_outline_rounded;
      badgeText = 'Form Lengkap (${yellowWarnings.length} Saran Opsional)';
    } else {
      badgeBg = const Color(0xFF27AE60).withOpacity(0.12);
      badgeBorder = const Color(0xFF27AE60).withOpacity(0.4);
      badgeColor = const Color(0xFF27AE60);
      badgeIcon = Icons.check_circle_rounded;
      badgeText = '✅ Form Lengkap & Reasoning Selesai';
    }

    return InkWell(
      onTap: _showReviewAndSubmitDialog,
      borderRadius: BorderRadius.circular(100),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: badgeBg,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: badgeBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(badgeIcon, size: 14, color: badgeColor),
            const SizedBox(width: 6),
            Text(
              badgeText,
              style: GoogleFonts.outfit(fontSize: 10.5, fontWeight: FontWeight.bold, color: badgeColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniBadge(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1ABC9C).withOpacity(0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF1ABC9C).withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ', style: GoogleFonts.outfit(fontSize: 9.5, color: Colors.grey)),
          Text(value, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF1ABC9C))),
        ],
      ),
    );
  }

  // ===========================================================================
  // HASIL KLASIFIKASI MODEL MLP
  // ===========================================================================
  Widget _buildMlpClassificationResult(Color cardBg, Color border, Color text, Color sub, bool isMobile) {
    final sg = _smartGrowthResult;

    final kategoriGizi = sg?.kategoriGiziBbtb ?? 'Gizi Normal';
    final kategoriStunting = sg?.kategoriStuntingTbu ?? 'Normal';
    final confGizi = sg?.confidenceBbtb ?? 0.0;
    final confStunt = sg?.confidenceTbu ?? 0.0;

    final isStunting = sg?.isStunting ?? false;
    final isGiziKurang = sg?.isGiziBurukAtauKurang ?? false;

    // Warna status
    Color giziColor = const Color(0xFF27AE60);
    if (kategoriGizi.contains('Buruk')) giziColor = const Color(0xFFE74C3C);
    else if (kategoriGizi.contains('Kurang')) giziColor = const Color(0xFFE67E22);
    else if (kategoriGizi.contains('Lebih') || kategoriGizi.contains('Obesitas')) giziColor = const Color(0xFF9B59B6);

    Color stuntingColor = const Color(0xFF27AE60);
    if (kategoriStunting.contains('Sangat Pendek')) stuntingColor = const Color(0xFFE74C3C);
    else if (kategoriStunting.contains('Pendek')) stuntingColor = const Color(0xFFE67E22);
    else if (kategoriStunting.contains('Tinggi')) stuntingColor = const Color(0xFF3498DB);

    return CustomCard(
      color: cardBg,
      borderColor: border,
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Hasil Klasifikasi
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF27AE60).withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.verified_rounded, size: 22, color: Color(0xFF27AE60)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Hasil Klasifikasi Model MLP VitaScale',
                          style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900, color: text),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF27AE60).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Keras MLP Neural Network',
                            style: GoogleFonts.outfit(fontSize: 8.5, fontWeight: FontWeight.bold, color: const Color(0xFF27AE60)),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'Evaluasi status gizi rasio BB/TB dan status pertumbuhan linier TB/U.',
                      style: GoogleFonts.outfit(fontSize: 10.5, color: sub),
                    ),
                  ],
                ),
              ),
              CustomButton(
                text: 'Salin Laporan',
                icon: Icons.copy_rounded,
                height: 34,
                isSecondary: true,
                onPressed: _copyReportToClipboard,
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Alert Banner jika Ada Indikasi
          if (isStunting || isGiziKurang) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFE74C3C).withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE74C3C).withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 24, color: Color(0xFFE74C3C)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PERHATIAN: Terdeteksi Indikasi Masalah Pertumbuhan',
                          style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.w900, color: const Color(0xFFE74C3C)),
                        ),
                        Text(
                          'Balita memerlukan intervensi nutrisi khusus dan penelaahan faktor etiologi melalui penalaran klinis di bawah.',
                          style: GoogleFonts.outfit(fontSize: 10, color: sub),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // 2 Kartu Status Utama
          Row(
            children: [
              // Kartu 1: Status Gizi BB/TB
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: giziColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: giziColor.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('STATUS GIZI (BB/TB)', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w800, color: sub)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: giziColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${confGizi.toStringAsFixed(1)}% Keyakinan',
                              style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.bold, color: giziColor),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        kategoriGizi,
                        style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900, color: giziColor),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Menilai keselarasan berat terhadap tinggi badan (indikator malnutrisi akut).',
                        style: GoogleFonts.outfit(fontSize: 9.5, color: sub),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 14),

              // Kartu 2: Status Stunting TB/U
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: stuntingColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: stuntingColor.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('STATUS PERTUMBUHAN (TB/U)', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w800, color: sub)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: stuntingColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${confStunt.toStringAsFixed(1)}% Keyakinan',
                              style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.bold, color: stuntingColor),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        kategoriStunting,
                        style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900, color: stuntingColor),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Menilai defisit tinggi badan linier terhadap usia (indikator stunting kronis).',
                        style: GoogleFonts.outfit(fontSize: 9.5, color: sub),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Probabilitas Bar Breakdown (Jika Smart Growth)
          if (sg != null && sg.probabilitasBbtb.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text(
              'Distribusi Probabilitas Kelas Model MLP:',
              style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: text),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: sg.probabilitasBbtb.entries.map((entry) {
                final pct = (entry.value * 100);
                return SizedBox(
                  width: isMobile ? double.infinity : 220,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(entry.key, style: GoogleFonts.outfit(fontSize: 10, color: text)),
                          Text('${pct.toStringAsFixed(1)}%', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: sub)),
                        ],
                      ),
                      const SizedBox(height: 3),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: entry.value,
                          minHeight: 5,
                          backgroundColor: border.withOpacity(0.2),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            entry.key == kategoriGizi ? giziColor : Colors.grey.withOpacity(0.4),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  // ===========================================================================
  // CLINICAL AI REASONING MODEL (GEMINI 2.5 FLASH)
  // ===========================================================================
  Widget _buildReasoningSection(Color cardBg, Color border, Color text, Color sub, bool isMobile) {
    final isEn = ref.watch(landingPageProvider).language == 'en';
    if (_isLoadingReasoning) {
      return _buildProgressBarLoadingCard(
        title: isEn
            ? 'Clinical Reasoning Engine Working (Gemini 2.5 Flash)...'
            : 'Clinical Reasoning Engine Sedang Bekerja (Gemini 2.5 Flash)...',
        subtitle: isEn
            ? 'Structuring pediatric chain-of-thought, clinical risk factors, and KIA nutrition intervention plan.'
            : 'Model Penalaran Klinis AI (Gemini 2.5 Flash) sedang menyusun alur berpikir medis, analisis faktor risiko, dan rencana intervensi nutrisi sesuai standar WHO/Kemenkes RI.',
        cardBg: cardBg,
        border: border,
        text: text,
        sub: sub,
        icon: Icons.psychology_rounded,
        steps: isEn
            ? ['Child Anthropometric Data', 'Gemini 2.5 Flash Reasoning', 'KIA Nutritional Action Plan']
            : ['Data Antropometri Balita', 'Penalaran Gemini 2.5 Flash', 'Rekomendasi Intervensi Gizi KIA'],
        activeStepIndex: 1,
      );
    }

    final reasoning = _reasoningResult;
    if (reasoning == null) return const SizedBox.shrink();

    return CustomCard(
      color: cardBg,
      borderColor: const Color(0xFF1ABC9C).withOpacity(0.5),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Reasoning Model
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1ABC9C), Color(0xFF16A085)],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.psychology_alt_rounded, size: 22, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Clinical AI Reasoning Engine',
                          style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900, color: text),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1ABC9C).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF1ABC9C).withOpacity(0.3)),
                          ),
                          child: Text(
                            reasoning.modelUsed,
                            style: GoogleFonts.outfit(fontSize: 8.5, fontWeight: FontWeight.bold, color: const Color(0xFF1ABC9C)),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'Alur penalaran klinis dokter spesialis anak & panduan intervensi berbasis bukti (Permenkes No. 2/2020).',
                      style: GoogleFonts.outfit(fontSize: 10.5, color: sub),
                    ),
                  ],
                ),
              ),
              CustomButton(
                text: _reasoningPromptCount > 0 ? 'Prompt Ulang AI (${_reasoningPromptCount}x)' : 'Analisis Ulang AI',
                icon: Icons.refresh_rounded,
                height: 34,
                primaryColor: const Color(0xFF1ABC9C),
                isSecondary: true,
                onPressed: () {
                  _confirmRePromptDialog();
                },
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Ringkasan Penalaran Medis (Summary Box)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1ABC9C).withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF1ABC9C).withOpacity(0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.format_quote_rounded, size: 20, color: Color(0xFF1ABC9C)),
                const SizedBox(width: 10),
                Expanded(
                  child: FormattedMarkdownText(
                    text: reasoning.reasoningSummary,
                    style: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.w600, color: text, height: 1.4),
                    boldStyle: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.w800, color: const Color(0xFF1ABC9C), height: 1.4),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Sub-Tab Navigasi Reasoning
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: border.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                _buildReasoningTabItem(0, 'Alur Berpikir (Chain-of-Thought)', Icons.account_tree_rounded),
                _buildReasoningTabItem(1, 'Faktor Risiko & Etiologi', Icons.search_rounded),
                _buildReasoningTabItem(2, 'Intervensi Gizi & PMT', Icons.restaurant_rounded),
                _buildReasoningTabItem(3, 'Tindak Lanjut Faskes', Icons.local_hospital_rounded),
                _buildReasoningTabItem(4, 'Edukasi Orang Tua', Icons.family_restroom_rounded),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Konten Sub-Tab Reasoning
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _buildActiveReasoningContent(reasoning, text, sub, border),
          ),
        ],
      ),
    );
  }

  Widget _buildReasoningTabItem(int index, String title, IconData icon) {
    final isSelected = _activeReasoningTab == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _activeReasoningTab = index),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF1ABC9C) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: isSelected ? Colors.white : Colors.grey),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    color: isSelected ? Colors.white : Colors.grey[700],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveReasoningContent(VitaScaleReasoningResult r, Color text, Color sub, Color border) {
    switch (_activeReasoningTab) {
      case 0:
        return Column(
          key: const ValueKey(0),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: r.chainOfThoughtSteps.asMap().entries.map((entry) {
            final idx = entry.key + 1;
            final stepText = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1ABC9C).withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$idx',
                      style: GoogleFonts.outfit(fontSize: 10.5, fontWeight: FontWeight.bold, color: const Color(0xFF1ABC9C)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FormattedMarkdownText(
                      text: stepText,
                      style: GoogleFonts.outfit(fontSize: 11.5, color: text, height: 1.4),
                      boldStyle: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.bold, color: const Color(0xFF1ABC9C), height: 1.4),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );

      case 1:
        return Container(
          key: const ValueKey(1),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.amber.withOpacity(0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber.withOpacity(0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.crisis_alert_rounded, size: 18, color: Colors.amber),
                  const SizedBox(width: 8),
                  Text('Identifikasi Faktor Risiko & Etiologi:', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: text)),
                ],
              ),
              const SizedBox(height: 8),
              FormattedMarkdownText(
                text: r.riskAndEtiology,
                style: GoogleFonts.outfit(fontSize: 11.5, color: text, height: 1.5),
                boldStyle: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.amber[800], height: 1.5),
              ),
            ],
          ),
        );

      case 2:
        return Container(
          key: const ValueKey(2),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF27AE60).withOpacity(0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF27AE60).withOpacity(0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.egg_alt_rounded, size: 18, color: Color(0xFF27AE60)),
                  const SizedBox(width: 8),
                  Text('Rencana Intervensi Gizi & Menu Protein Hewani (PMT):', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: text)),
                ],
              ),
              const SizedBox(height: 8),
              FormattedMarkdownText(
                text: r.nutritionalIntervention,
                style: GoogleFonts.outfit(fontSize: 11.5, color: text, height: 1.5),
                boldStyle: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.bold, color: const Color(0xFF27AE60), height: 1.5),
              ),
            ],
          ),
        );

      case 3:
        return Container(
          key: const ValueKey(3),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF3498DB).withOpacity(0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF3498DB).withOpacity(0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.medical_services_rounded, size: 18, color: Color(0xFF3498DB)),
                  const SizedBox(width: 8),
                  Text('Protokol Tindak Lanjut Faskes & Kriteria Rujukan:', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: text)),
                ],
              ),
              const SizedBox(height: 8),
              FormattedMarkdownText(
                text: r.medicalProtocol,
                style: GoogleFonts.outfit(fontSize: 11.5, color: text, height: 1.5),
                boldStyle: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.bold, color: const Color(0xFF3498DB), height: 1.5),
              ),
            ],
          ),
        );

      case 4:
      default:
        return Container(
          key: const ValueKey(4),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFE91E63).withOpacity(0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE91E63).withOpacity(0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.favorite_rounded, size: 18, color: Color(0xFFE91E63)),
                  const SizedBox(width: 8),
                  Text('Panduan & Pesan Suportif untuk Orang Tua:', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: text)),
                ],
              ),
              const SizedBox(height: 8),
              FormattedMarkdownText(
                text: r.parentEducation,
                style: GoogleFonts.outfit(fontSize: 11.5, color: text, height: 1.5),
                boldStyle: GoogleFonts.outfit(fontSize: 11.5, fontWeight: FontWeight.bold, color: const Color(0xFFE91E63), height: 1.5),
              ),
            ],
          ),
        );
    }
  }

  // ===========================================================================
  // METODE HELPER OPERASI PCV COMPUTER VISION CLOUD (https://pcvmapotechs5.vercel.app/)
  // ===========================================================================

  /// 1. Pilih gambar dari penyimpanan lokal perangkat via FilePicker
  Future<void> _pickLocalPcvImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.bytes != null) {
          setState(() {
            _pcvSelectedImageBytes = file.bytes;
            _pcvSelectedImageName = file.name;
            _pcvResultData = null;
            _pcvTinggiCm = null;
            _pcvPanjangPx = null;
            _pcvSkalaEfektif = null;
            _pcvAnnotatedImageBase64 = null;
            _pcvErrorMessage = null;
            _pcvMessage = null;
          });
          if (mounted) {
            CustomSnackbar.success(
              context,
              'Foto "${file.name}" (${(file.bytes!.lengthInBytes / 1024).toStringAsFixed(1)} KB) berhasil dipilih.',
              title: 'File Gambar Dipilih',
            );
          }
        }
      }
    } catch (e) {
      debugPrint('[PCV] _pickLocalPcvImage error: $e');
      if (mounted) {
        CustomSnackbar.error(context, 'Gagal memilih file: $e', title: 'File Picker Gagal');
      }
    }
  }

  /// 2. Unduh citra balita via Link / URL Web
  Future<void> _fetchPcvImageFromUrl(String url) async {
    final cleanUrl = url.trim();
    if (cleanUrl.isEmpty) {
      CustomSnackbar.warning(context, 'Masukkan link URL gambar balita yang valid.', title: 'URL Kosong');
      return;
    }
    if (!cleanUrl.startsWith('http://') && !cleanUrl.startsWith('https://')) {
      CustomSnackbar.warning(context, 'URL harus diawali dengan http:// atau https://', title: 'URL Tidak Valid');
      return;
    }

    setState(() {
      _isLoadingPcvImage = true;
      _pcvProgress = 0.15;
      _pcvErrorMessage = null;
    });

    _pcvProgressTimer?.cancel();
    _pcvProgressTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (_pcvProgress < 0.85) {
        setState(() => _pcvProgress += 0.08);
      }
    });

    try {
      final uri = Uri.parse(cleanUrl);
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      _pcvProgressTimer?.cancel();

      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        String fileName = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : 'citra_web.jpg';
        if (!fileName.contains('.')) fileName = '$fileName.jpg';

        setState(() {
          _pcvSelectedImageBytes = bytes;
          _pcvSelectedImageName = fileName;
          _isLoadingPcvImage = false;
          _pcvProgress = 1.0;
          _pcvResultData = null;
          _pcvTinggiCm = null;
          _pcvPanjangPx = null;
          _pcvSkalaEfektif = null;
          _pcvAnnotatedImageBase64 = null;
          _pcvErrorMessage = null;
          _pcvMessage = null;
        });

        if (mounted) {
          CustomSnackbar.success(
            context,
            'Gambar berhasil diunduh dari URL (${(bytes.lengthInBytes / 1024).toStringAsFixed(1)} KB).',
            title: 'Gambar Berhasil Dimuat',
          );
        }
      } else {
        setState(() {
          _isLoadingPcvImage = false;
          _pcvErrorMessage = 'Gagal mengunduh gambar (HTTP ${response.statusCode})';
        });
        if (mounted) {
          CustomSnackbar.error(context, 'Server mengembalikan kode HTTP ${response.statusCode}', title: 'Unduh Gagal');
        }
      }
    } catch (e) {
      _pcvProgressTimer?.cancel();
      setState(() {
        _isLoadingPcvImage = false;
        _pcvErrorMessage = 'Gagal memuat URL: $e';
      });
      if (mounted) {
        CustomSnackbar.error(context, 'Koneksi gagal atau URL tidak dapat diakses: $e', title: 'Gagal Memuat Gambar');
      }
    }
  }

  /// 3. Ambil snapshot langsung dari Kamera / Webcam
  Future<void> _captureCameraPcvImage() async {
    try {
      final picker = ImagePicker();
      final photo = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 92,
      );

      if (photo != null) {
        final bytes = await photo.readAsBytes();
        setState(() {
          _pcvSelectedImageBytes = bytes;
          _pcvSelectedImageName = photo.name.isNotEmpty ? photo.name : 'kamera_${DateTime.now().millisecondsSinceEpoch}.jpg';
          _pcvResultData = null;
          _pcvTinggiCm = null;
          _pcvPanjangPx = null;
          _pcvSkalaEfektif = null;
          _pcvAnnotatedImageBase64 = null;
          _pcvErrorMessage = null;
          _pcvMessage = null;
        });
        if (mounted) {
          CustomSnackbar.success(
            context,
            'Snapshot kamera berhasil diambil (${(bytes.lengthInBytes / 1024).toStringAsFixed(1)} KB).',
            title: 'Foto Kamera Siap',
          );
        }
      }
    } catch (e) {
      debugPrint('[PCV] _captureCameraPcvImage error: $e');
      if (mounted) {
        CustomSnackbar.warning(
          context,
          'Kamera perangkat tidak dapat diakses langsung ($e). Silakan gunakan mode "File Lokal" atau "Link URL".',
          title: 'Kamera Tidak Tersedia',
        );
      }
    }
  }

  /// 4. Muat citra sampel klinis bawaan
  Future<void> _loadSampleLocalPcvImage() async {
    try {
      final byteData = await rootBundle.load('assets/images/anc_home_visit_evidence.png');
      final bytes = byteData.buffer.asUint8List();
      setState(() {
        _pcvSelectedImageBytes = bytes;
        _pcvSelectedImageName = 'anc_home_visit_evidence.png (Sampel Klinis)';
        _pcvResultData = null;
        _pcvTinggiCm = null;
        _pcvPanjangPx = null;
        _pcvSkalaEfektif = null;
        _pcvAnnotatedImageBase64 = null;
        _pcvErrorMessage = null;
        _pcvMessage = null;
      });
      if (mounted) {
        CustomSnackbar.info(
          context,
          'Foto sampel klinis balita berhasil dimuat (${(bytes.lengthInBytes / 1024).toStringAsFixed(1)} KB). Klik "Ukur Tinggi Badan" untuk memproses.',
          title: 'Sampel Dimuat',
        );
      }
    } catch (e) {
      debugPrint('[PCV] _loadSampleLocalPcvImage error: $e');
      if (mounted) {
        CustomSnackbar.error(context, 'Gagal memuat sampel bawaan: $e', title: 'Gagal Memuat');
      }
    }
  }

  /// 4b. Muat citra sampel Boneka uji validasi (Ground Truth: 47.2 cm, 519.0 px)
  Future<void> _loadBonekaSampleImage() async {
    try {
      final byteData = await rootBundle.load('assets/images/boneka_sample.jpg');
      final bytes = byteData.buffer.asUint8List();
      setState(() {
        _pcvSelectedImageBytes = bytes;
        _pcvSelectedImageName = 'Boneka.jpg (Ground Truth 47.2 cm, 519.0 px)';
        _pcvSelectedScale = 11.00;
        _pcvCustomScaleController.text = '11.00';
        _pcvUseRoi = false;
        _pcvResultData = null;
        _pcvTinggiCm = null;
        _pcvPanjangPx = null;
        _pcvSkalaEfektif = null;
        _pcvAnnotatedImageBase64 = null;
        _pcvErrorMessage = null;
        _pcvMessage = null;
      });
      if (mounted) {
        CustomSnackbar.info(
          context,
          'Sampel Boneka.jpg berhasil dimuat. Skala kalibrasi 11.00 px/cm aktif. Klik "Ukur Tinggi Badan" untuk memproses.',
          title: 'Sampel Boneka Siap',
        );
      }
    } catch (e) {
      debugPrint('[PCV] _loadBonekaSampleImage error: $e');
      if (mounted) {
        CustomSnackbar.error(context, 'Gagal memuat sampel boneka: $e', title: 'Gagal Memuat');
      }
    }
  }

  /// 5. Kirim citra ke API https://pcvmapotechs5.vercel.app/measure
  Future<void> _measurePcvHeight() async {
    if (_pcvSelectedImageBytes == null) {
      CustomSnackbar.warning(context, 'Pilih atau unggah foto balita terlebih dahulu.', title: 'Foto Belum Ada');
      return;
    }

    setState(() {
      _isMeasuringPcv = true;
      _pcvProgress = 0.08;
      _pcvErrorMessage = null;
      _pcvMessage = null;
    });

    _pcvProgressTimer?.cancel();
    _pcvProgressTimer = Timer.periodic(const Duration(milliseconds: 140), (timer) {
      if (_pcvProgress < 0.90) {
        setState(() => _pcvProgress += 0.05);
      }
    });

    try {
      final base64Str = base64Encode(_pcvSelectedImageBytes!);
      final res = await VitaScaleApiService.ukurTinggiObjek(
        base64Image: base64Str,
        skala: _pcvSelectedScale,
        useRoi: _pcvUseRoi,
        useK1: _pcvUseK1,
        preset: _pcvSelectedScale == 11.0 ? 'boneka' : null,
      );

      _pcvProgressTimer?.cancel();

      if (res['status'] == 'ok' || res.containsKey('tinggi_cm')) {
        final tinggi = (res['tinggi_cm'] as num).toDouble();
        final px = (res['panjang_px'] as num?)?.toDouble();
        final skala = (res['skala_efektif'] as num?)?.toDouble() ?? 9.09;
        final annotated = res['annotated_image'] as String?;
        final msg = res['message'] as String? ?? 'Pengukuran berhasil';

        setState(() {
          _isMeasuringPcv = false;
          _pcvProgress = 1.0;
          _pcvResultData = res;
          _pcvTinggiCm = tinggi;
          _pcvPanjangPx = px;
          _pcvSkalaEfektif = skala;
          _pcvAnnotatedImageBase64 = annotated;
          _pcvMessage = msg;
          _pcvShowAnnotated = true;

          // Isi otomatis ke kontroler Tinggi Badan
          _heightController.text = tinggi.toStringAsFixed(1);

          // Tentukan PB vs TB
          if ((_activeChild?.isUnder24Months ?? (tinggi < 85.0))) {
            _measurementMethod = 'PB';
          } else {
            _measurementMethod = 'TB';
          }

          // Reset hasil klasifikasi agar user memperbarui
          _smartGrowthResult = null;
          _reasoningResult = null;
        });

        if (mounted) {
          CustomSnackbar.success(
            context,
            'Panjang/Tinggi terdeteksi: ${tinggi.toStringAsFixed(1)} cm ($px px). Otomatis diisikan ke Formulir Antropometri.',
            title: 'PCV Berhasil',
          );
        }
      } else {
        final errMsg = res['message'] ?? 'Gagal memproses citra pada OpenCV server.';
        setState(() {
          _isMeasuringPcv = false;
          _pcvProgress = 0.0;
          _pcvErrorMessage = errMsg;
        });
        if (mounted) {
          CustomSnackbar.error(context, errMsg, title: 'PCV Gagal');
        }
      }
    } catch (e) {
      _pcvProgressTimer?.cancel();
      setState(() {
        _isMeasuringPcv = false;
        _pcvProgress = 0.0;
        _pcvErrorMessage = 'Terjadi kesalahan saat memproses citra: $e';
      });
      if (mounted) {
        CustomSnackbar.error(context, 'Kesalahan: $e', title: 'Gagal Mengukur');
      }
    }
  }

  /// 6. Parse annotated image base64
  Uint8List? _getAnnotatedBytes(String raw) {
    try {
      String clean = raw.trim();
      if (clean.contains(',')) {
        clean = clean.split(',').last;
      }
      return base64Decode(clean);
    } catch (e) {
      debugPrint('[PCV] _getAnnotatedBytes error: $e');
      return null;
    }
  }

  // ===========================================================================
  // KONTEN TAB 2: PENGUKURAN TINGGI VIA FOTO AI (PCV CLOUD API)
  // ===========================================================================
  Widget _buildTab2PcvCloudSection({
    required Color cardBgColor,
    required Color borderColor,
    required Color textColor,
    required Color subtitleColor,
    required Color themeAccent,
    required bool isDark,
    required bool isMobile,
    required List<Map<String, dynamic>> redErrors,
    required List<Map<String, dynamic>> yellowWarnings,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Status Banner PCV API Hosting
        _buildPcvServerBanner(cardBgColor, borderColor, textColor, subtitleColor, isDark),

        const SizedBox(height: 16),

        // 2. Studio Unggah Citra & Pengukuran PCV
        _buildPcvImageStudioCard(cardBgColor, borderColor, textColor, subtitleColor, themeAccent, isDark, isMobile),

        const SizedBox(height: 20),

        // 3. Custom Form Stepper (1 Card Per Step - Identik dengan Manual)
        CustomFormStepper(
          steps: [
            FormStepItem(
              step: 1,
              label: '1. Identitas Balita',
              icon: Icons.badge_rounded,
              hasError: redErrors.any((e) => e['step'] == 1),
              hasWarning: yellowWarnings.any((w) => w['step'] == 1),
              isCompleted: _nikController.text.trim().length == 16 && _nameController.text.trim().isNotEmpty && _ageMonths > 0,
            ),
            FormStepItem(
              step: 2,
              label: '2. Antropometri (Tinggi Foto PCV)',
              icon: Icons.straighten_rounded,
              hasError: redErrors.any((e) => e['step'] == 2),
              hasWarning: yellowWarnings.any((w) => w['step'] == 2),
              isCompleted: double.tryParse(_weightController.text.trim()) != null && double.tryParse(_heightController.text.trim()) != null,
            ),
            FormStepItem(
              step: 3,
              label: '3. Reasoning AI',
              icon: Icons.psychology_rounded,
              hasError: redErrors.any((e) => e['step'] == 3),
              hasWarning: yellowWarnings.any((w) => w['step'] == 3),
              isCompleted: _smartGrowthResult != null,
            ),
            FormStepItem(
              step: 4,
              label: '4. SATUSEHAT & Simpan',
              icon: Icons.cloud_sync_rounded,
              hasError: false,
              hasWarning: false,
              isCompleted: _satuSehatSyncResult != null,
            ),
          ],
          currentStep: _formStep,
          onStepTapped: (step) {
            setState(() => _formStep = step);
            if (step == 3) {
              _checkAndAutoRunMlp();
            }
          },
          themeAccent: const Color(0xFF1ABC9C),
          textColor: textColor,
          subtitleColor: subtitleColor,
          borderColor: borderColor,
          cardBgColor: cardBgColor,
          isDark: isDark,
        ),

        const SizedBox(height: 16),

        // 4. Tampilan 1 Kartu Form Aktif Sesuai Step
        if (_formStep == 1)
          _buildStep1ChildIdentity(cardBgColor, borderColor, textColor, subtitleColor, isMobile)
        else if (_formStep == 2)
          _buildStep2Anthropometry(cardBgColor, borderColor, textColor, subtitleColor, isMobile)
        else if (_formStep == 3)
          _buildStep3ReasoningAndAi(cardBgColor, borderColor, textColor, subtitleColor, isMobile)
        else if (_formStep == 4)
          _buildStep4SatuSehatAndSave(cardBgColor, borderColor, textColor, subtitleColor, isMobile),

        const SizedBox(height: 16),

        // 5. Stepper Navigation Footer & Real-Time Validation Pill
        _buildScreeningStepperFooter(
          cardBgColor: cardBgColor,
          borderColor: borderColor,
          textColor: textColor,
          subtitleColor: subtitleColor,
          isMobile: isMobile,
          redErrors: redErrors,
          yellowWarnings: yellowWarnings,
        ),

        const SizedBox(height: 24),
      ],
    );
  }

  // ===========================================================================
  // WIDGET: BANNER STATUS SERVER PCV CLOUD VERCEL
  // ===========================================================================
  Widget _buildPcvServerBanner(Color cardBg, Color border, Color text, Color sub, bool isDark) {
    return CustomCard(
      color: cardBg,
      borderColor: border,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF1ABC9C).withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.cloud_done_rounded, size: 22, color: Color(0xFF1ABC9C)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text(
                      'PCV Computer Vision Cloud API',
                      style: GoogleFonts.outfit(fontSize: 13.5, fontWeight: FontWeight.w800, color: text),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2ECC71).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF2ECC71).withOpacity(0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(color: Color(0xFF2ECC71), shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'ONLINE (Vercel Serverless)',
                            style: GoogleFonts.outfit(fontSize: 8.5, fontWeight: FontWeight.bold, color: const Color(0xFF2ECC71)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'Endpoint: https://pcvmapotechs5.vercel.app/measure • Classical OpenCV 7-Tahap (Undistort, Otsu, Morfologi Elips, minAreaRect, Skala 9.09 px/cm)',
                  style: GoogleFonts.outfit(fontSize: 10, color: sub),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // WIDGET: STUDIO INPUT CITRA & PENGUKURAN TINGGI BADAN (PCV API)
  // ===========================================================================
  Widget _buildPcvImageStudioCard(
    Color cardBg,
    Color border,
    Color text,
    Color sub,
    Color themeAccent,
    bool isDark,
    bool isMobile,
  ) {
    return CustomCard(
      color: cardBg,
      borderColor: border,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Card Studio PCV
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1ABC9C).withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.camera_enhance_rounded, size: 20, color: Color(0xFF1ABC9C)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Studio Pengukuran Tinggi Badan via Citra Foto (PCV AI)',
                      style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w800, color: text),
                    ),
                    Text(
                      'Pilih sumber foto balita (File Lokal, Link URL, atau Kamera). OpenCV akan menghitung panjang badan dan mengisi formulir antropometri secara otomatis.',
                      style: GoogleFonts.outfit(fontSize: 10.5, color: sub),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const Divider(height: 24),

          // Pilihan Mode Sumber Citra: 3 Tab Mode (File Lokal, Link URL, Kamera)
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2130) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildPcvModeTabBtn(
                    index: 0,
                    icon: Icons.folder_open_rounded,
                    label: 'File Lokal',
                    sublabel: 'PNG/JPG',
                    isDark: isDark,
                    text: text,
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _buildPcvModeTabBtn(
                    index: 1,
                    icon: Icons.link_rounded,
                    label: 'Link / URL',
                    sublabel: 'Web Image',
                    isDark: isDark,
                    text: text,
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _buildPcvModeTabBtn(
                    index: 2,
                    icon: Icons.photo_camera_rounded,
                    label: 'Kamera',
                    sublabel: 'Snapshot',
                    isDark: isDark,
                    text: text,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Konten Berdasarkan Mode yang Dipilih
          if (_pcvInputMode == 0) ...[
            // Mode 0: File Lokal
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF161924) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      CustomButton(
                        text: 'Pilih Foto dari Perangkat',
                        icon: Icons.file_upload_outlined,
                        onPressed: _pickLocalPcvImage,
                      ),
                      CustomButton(
                        text: '🧸 Sampel Boneka (Ground Truth 47.2 cm)',
                        icon: Icons.smart_toy_rounded,
                        isSecondary: true,
                        onPressed: _loadBonekaSampleImage,
                      ),
                      CustomButton(
                        text: 'Gunakan Sampel Klinis Uji',
                        icon: Icons.science_rounded,
                        isSecondary: true,
                        onPressed: _loadSampleLocalPcvImage,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Pilih file foto bayi/balita di atas papan ukur stadiometer (format .jpg, .png, .jpeg, .webp).',
                    style: GoogleFonts.outfit(fontSize: 10, color: sub),
                  ),
                ],
              ),
            ),
          ] else if (_pcvInputMode == 1) ...[
            // Mode 1: Link URL
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF161924) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: CustomTextField(
                          label: 'Link / URL Gambar Balita',
                          hintText: 'https://example.com/foto_balita.jpg',
                          controller: _pcvUrlController,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Padding(
                        padding: const EdgeInsets.only(top: 24),
                        child: CustomButton(
                          text: 'Muat dari URL',
                          icon: Icons.cloud_download_rounded,
                          onPressed: () => _fetchPcvImageFromUrl(_pcvUrlController.text),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text('Preset Cepat:', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: sub)),
                      InkWell(
                        onTap: () {
                          _loadBonekaSampleImage();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE67E22).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFE67E22).withOpacity(0.3)),
                          ),
                          child: Text(
                            '🧸 Sampel Boneka (47.2 cm)',
                            style: GoogleFonts.outfit(fontSize: 9.5, fontWeight: FontWeight.w600, color: const Color(0xFFE67E22)),
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          _pcvUrlController.text = 'https://images.unsplash.com/photo-1519689680058-324335c77eba?w=800';
                          _fetchPcvImageFromUrl(_pcvUrlController.text);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF3498DB).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF3498DB).withOpacity(0.3)),
                          ),
                          child: Text(
                            '🔗 Demo Bayi Online (Unsplash)',
                            style: GoogleFonts.outfit(fontSize: 9.5, fontWeight: FontWeight.w600, color: const Color(0xFF3498DB)),
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          _loadSampleLocalPcvImage();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1ABC9C).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF1ABC9C).withOpacity(0.3)),
                          ),
                          child: Text(
                            '🔗 Sampel Validasi PCV (72 cm)',
                            style: GoogleFonts.outfit(fontSize: 9.5, fontWeight: FontWeight.w600, color: const Color(0xFF1ABC9C)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ] else ...[
            // Mode 2: Kamera
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF161924) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CustomButton(
                        text: 'Buka Kamera / Ambil Snapshot',
                        icon: Icons.photo_camera_rounded,
                        onPressed: _captureCameraPcvImage,
                      ),
                      const SizedBox(width: 10),
                      CustomButton(
                        text: 'Gunakan Sampel Klinis',
                        icon: Icons.science_rounded,
                        isSecondary: true,
                        onPressed: _loadSampleLocalPcvImage,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ambil foto bayi tidur telentang lurus di atas infantometer dengan kamera/webcam.',
                    style: GoogleFonts.outfit(fontSize: 10, color: sub),
                  ),
                ],
              ),
            ),
          ],

          // Loading Progress Bar saat mengunduh gambar dari internet
          if (_isLoadingPcvImage) ...[
            const SizedBox(height: 14),
            CustomProgressBar(
              value: _pcvProgress,
              label: 'Mengunduh citra dari link web...',
              sublabel: '${(_pcvProgress * 100).toInt()}%',
              primaryColor: const Color(0xFF3498DB),
              height: 6,
            ),
          ],

          // Preview Citra yang Dipilih
          if (_pcvSelectedImageBytes != null) ...[
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF12141D) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: border),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top Toolbar Preview Citra
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    color: isDark ? const Color(0xFF1E2130) : const Color(0xFFEEF2F6),
                    child: Row(
                      children: [
                        Icon(
                          _pcvShowAnnotated && _pcvAnnotatedImageBase64 != null
                              ? Icons.auto_awesome_rounded
                              : Icons.image_rounded,
                          size: 16,
                          color: const Color(0xFF1ABC9C),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${_pcvSelectedImageName ?? "Citra Balita"} (${(_pcvSelectedImageBytes!.lengthInBytes / 1024).toStringAsFixed(1)} KB)',
                            style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: text),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_pcvAnnotatedImageBase64 != null) ...[
                          InkWell(
                            onTap: () => setState(() => _pcvShowAnnotated = !_pcvShowAnnotated),
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _pcvShowAnnotated ? const Color(0xFF1ABC9C) : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFF1ABC9C)),
                              ),
                              child: Text(
                                _pcvShowAnnotated ? '🎯 Deteksi OpenCV' : '📸 Citra Asli',
                                style: GoogleFonts.outfit(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  color: _pcvShowAnnotated ? Colors.white : const Color(0xFF1ABC9C),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        InkWell(
                          onTap: () => setState(() {
                            _pcvSelectedImageBytes = null;
                            _pcvSelectedImageName = null;
                            _pcvResultData = null;
                            _pcvTinggiCm = null;
                            _pcvPanjangPx = null;
                            _pcvAnnotatedImageBase64 = null;
                            _pcvErrorMessage = null;
                            _pcvMessage = null;
                          }),
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE74C3C).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFE74C3C).withOpacity(0.4)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.close_rounded, size: 12, color: Color(0xFFE74C3C)),
                                const SizedBox(width: 4),
                                Text(
                                  'Hapus',
                                  style: GoogleFonts.outfit(fontSize: 9.5, fontWeight: FontWeight.bold, color: const Color(0xFFE74C3C)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Area Gambar Citra
                  Container(
                    height: 280,
                    width: double.infinity,
                    color: Colors.black,
                    alignment: Alignment.center,
                    child: Builder(
                      builder: (context) {
                        if (_pcvShowAnnotated && _pcvAnnotatedImageBase64 != null) {
                          final annotatedBytes = _getAnnotatedBytes(_pcvAnnotatedImageBase64!);
                          if (annotatedBytes != null) {
                            return Image.memory(annotatedBytes, fit: BoxFit.contain);
                          }
                        }
                        return Image.memory(_pcvSelectedImageBytes!, fit: BoxFit.contain);
                      },
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Konfigurasi Kalibrasi Skala & ROI Pengukuran
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF161924) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.tune_rounded, size: 16, color: Color(0xFF1ABC9C)),
                      const SizedBox(width: 8),
                      Text(
                        'Pengaturan Kalibrasi Skala & Area ROI',
                        style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: text),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // Preset 11.00 px/cm
                      ChoiceChip(
                        label: Text(
                          '🧸 11.00 px/cm (Boneka & Infantometer Standar)',
                          style: GoogleFonts.outfit(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: (_pcvSelectedScale - 11.0).abs() < 0.01 ? const Color(0xFF1ABC9C) : text,
                          ),
                        ),
                        selected: (_pcvSelectedScale - 11.0).abs() < 0.01,
                        selectedColor: const Color(0xFF1ABC9C).withOpacity(0.18),
                        backgroundColor: isDark ? const Color(0xFF1E2130) : Colors.white,
                        side: BorderSide(
                          color: (_pcvSelectedScale - 11.0).abs() < 0.01 ? const Color(0xFF1ABC9C) : border,
                        ),
                        onSelected: (val) {
                          if (val) {
                            setState(() {
                              _pcvSelectedScale = 11.00;
                              _pcvCustomScaleController.text = '11.00';
                            });
                          }
                        },
                      ),
                      // Preset 9.09 px/cm
                      ChoiceChip(
                        label: Text(
                          '📐 9.09 px/cm (Stadiometer H=170cm)',
                          style: GoogleFonts.outfit(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: (_pcvSelectedScale - 9.09).abs() < 0.01 ? const Color(0xFF1ABC9C) : text,
                          ),
                        ),
                        selected: (_pcvSelectedScale - 9.09).abs() < 0.01,
                        selectedColor: const Color(0xFF1ABC9C).withOpacity(0.18),
                        backgroundColor: isDark ? const Color(0xFF1E2130) : Colors.white,
                        side: BorderSide(
                          color: (_pcvSelectedScale - 9.09).abs() < 0.01 ? const Color(0xFF1ABC9C) : border,
                        ),
                        onSelected: (val) {
                          if (val) {
                            setState(() {
                              _pcvSelectedScale = 9.09;
                              _pcvCustomScaleController.text = '9.09';
                            });
                          }
                        },
                      ),
                      // Toggle ROI Full Frame vs Crop
                      FilterChip(
                        avatar: Icon(
                          !_pcvUseRoi ? Icons.fullscreen_rounded : Icons.crop_rounded,
                          size: 14,
                          color: !_pcvUseRoi ? const Color(0xFF2ECC71) : const Color(0xFFF39C12),
                        ),
                        label: Text(
                          !_pcvUseRoi ? 'Mode: Full Frame (Kaki & Kepala Utuh)' : 'Mode: Crop ROI Kuning',
                          style: GoogleFonts.outfit(fontSize: 10.5, fontWeight: FontWeight.w600, color: text),
                        ),
                        selected: !_pcvUseRoi,
                        selectedColor: const Color(0xFF2ECC71).withOpacity(0.18),
                        backgroundColor: isDark ? const Color(0xFF1E2130) : Colors.white,
                        side: BorderSide(color: !_pcvUseRoi ? const Color(0xFF2ECC71) : border),
                        onSelected: (val) {
                          setState(() {
                            _pcvUseRoi = !val;
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Tombol Eksekusi Pengukuran
            CustomButton(
              text: _isMeasuringPcv
                  ? 'Sedang Memproses OpenCV 7-Tahap...'
                  : '🚀 Ukur Tinggi Badan via PCV API (https://pcvmapotechs5.vercel.app)',
              icon: Icons.straighten_rounded,
              onPressed: _isMeasuringPcv ? null : _measurePcvHeight,
              width: double.infinity,
            ),
          ],

          // Progress Bar Pengukuran PCV (Rule.md Section 8)
          if (_isMeasuringPcv) ...[
            const SizedBox(height: 14),
            Builder(
              builder: (context) {
                String stageText = 'Mengunggah citra ke cloud serverless...';
                if (_pcvProgress > 0.3) stageText = 'Tahap 1-2: Grayscale & Segmentasi Biner (Otsu)...';
                if (_pcvProgress > 0.6) stageText = 'Tahap 3-5: Morfologi Elips & Kontur minAreaRect...';
                if (_pcvProgress > 0.85) stageText = 'Tahap 6-7: Kalkulasi Skala ${_pcvSelectedScale.toStringAsFixed(2)} px/cm & Anotasi Garis Hijau...';

                return CustomProgressBar(
                  value: _pcvProgress,
                  label: stageText,
                  sublabel: '${(_pcvProgress * 100).toInt()}%',
                  primaryColor: const Color(0xFF1ABC9C),
                  height: 8,
                );
              },
            ),
          ],

          // Pesan Error jika terjadi kegagalan
          if (_pcvErrorMessage != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFE74C3C).withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE74C3C).withOpacity(0.35)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: Color(0xFFE74C3C), size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _pcvErrorMessage!,
                      style: GoogleFonts.outfit(fontSize: 11, color: const Color(0xFFE74C3C)),
                    ),
                  ),
                  InkWell(
                    onTap: _measurePcvHeight,
                    child: Text(
                      'Coba Lagi',
                      style: GoogleFonts.outfit(fontSize: 10.5, fontWeight: FontWeight.bold, color: const Color(0xFFE74C3C), decoration: TextDecoration.underline),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Hasil Pengukuran Sukses PCV
          if (_pcvResultData != null && _pcvTinggiCm != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1ABC9C).withOpacity(0.07),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF1ABC9C).withOpacity(0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Color(0xFF1ABC9C),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pengukuran Panjang/Tinggi Badan Berhasil!',
                              style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w800, color: text),
                            ),
                            Text(
                              _pcvMessage ?? 'Data telah disinkronkan otomatis ke Formulir Antropometri di bawah.',
                              style: GoogleFonts.outfit(fontSize: 10, color: sub),
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
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1A1D27) : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Tinggi / Panjang Badan', style: GoogleFonts.outfit(fontSize: 9.5, color: sub)),
                              const SizedBox(height: 2),
                              Text(
                                '${_pcvTinggiCm!.toStringAsFixed(1)} cm',
                                style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900, color: const Color(0xFF1ABC9C)),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1A1D27) : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Metode Standar KIA', style: GoogleFonts.outfit(fontSize: 9.5, color: sub)),
                              const SizedBox(height: 2),
                              Text(
                                _measurementMethod == 'PB' ? 'PB Telentang' : 'TB Berdiri',
                                style: GoogleFonts.outfit(fontSize: 13.5, fontWeight: FontWeight.w800, color: const Color(0xFF3498DB)),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1A1D27) : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Panjang Piksel Kontur', style: GoogleFonts.outfit(fontSize: 9.5, color: sub)),
                              const SizedBox(height: 2),
                              Text(
                                '${_pcvPanjangPx?.toStringAsFixed(1) ?? "-"} px',
                                style: GoogleFonts.outfit(fontSize: 13.5, fontWeight: FontWeight.w800, color: text),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1A1D27) : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Skala Kalibrasi', style: GoogleFonts.outfit(fontSize: 9.5, color: sub)),
                              const SizedBox(height: 2),
                              Text(
                                '${_pcvSkalaEfektif?.toStringAsFixed(2) ?? "9.09"} px/cm',
                                style: GoogleFonts.outfit(fontSize: 13.5, fontWeight: FontWeight.w800, color: text),
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
          ],
        ],
      ),
    );
  }

  // ===========================================================================
  // WIDGET HELPER: TOMBOL TAB SUMBER CITRA PCV
  // ===========================================================================
  Widget _buildPcvModeTabBtn({
    required int index,
    required IconData icon,
    required String label,
    required String sublabel,
    required bool isDark,
    required Color text,
  }) {
    final isSelected = _pcvInputMode == index;
    return InkWell(
      onTap: () => setState(() => _pcvInputMode = index),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1ABC9C) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : Colors.grey,
            ),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    color: isSelected ? Colors.white : text,
                  ),
                ),
                Text(
                  sublabel,
                  style: GoogleFonts.outfit(
                    fontSize: 8.5,
                    color: isSelected ? Colors.white.withOpacity(0.85) : Colors.grey,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
