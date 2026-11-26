import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:mqtt_client/mqtt_client.dart';
import '../vitascale_models.dart';
import 'vitascale_mqtt_client_factory.dart';

/// Service MQTT Client Universal untuk VitaScale (Mendukung Web, Desktop, & Mobile)
class VitaScaleMqttService {
  static final VitaScaleMqttService _instance = VitaScaleMqttService._internal();
  factory VitaScaleMqttService() => _instance;
  VitaScaleMqttService._internal();

  MqttClient? _client;
  StreamSubscription? _updatesSub;
  bool _isConnected = false;
  bool get isConnected => _isConnected;

  String _broker = 'broker.hivemq.com';
  int _port = kIsWeb ? 8884 : 1883; // 8884 WSS (HiveMQ) untuk Web, 1883 TCP untuk Desktop/Mobile
  String _wsPath = '/mqtt';
  String _faskesId = 'PUSKESMAS-001';
  String _deviceId = 'VTS-001';
  String _cloudGatewayUrl = 'https://mapotechiotmqtt.vercel.app';
  double _poleHeightCm = 166.0; // Acuan default tripod fisik ESP32 terbaru (otomatis ikut payload)
  bool _useWildcard = true;
  bool _hasCustomConfig = false;
  bool _isGatewayHealthy = false;
  bool? _isDeviceOnline;
  Map<String, dynamic>? _lastTelemetry;

  String get broker => _broker;
  int get port => _port;
  String get wsPath => _wsPath;
  String get faskesId => _faskesId;
  String get deviceId => _deviceId;
  String get cloudGatewayUrl => _cloudGatewayUrl;
  double get poleHeightCm => _poleHeightCm;
  bool get useWildcard => _useWildcard;
  bool get isGatewayHealthy => _isGatewayHealthy;
  bool? get isDeviceOnline => _isDeviceOnline;
  Map<String, dynamic>? get lastTelemetry => _lastTelemetry;

  String get connectionProtocolLabel {
    if (_port == 8884 || _port == 8084 || _port == 443) return 'WSS';
    if (_port == 8000 || _port == 8083) return 'WS';
    if (_port == 8883) return 'TLS';
    return 'TCP';
  }

  /// Memperbarui konfigurasi secara fleksibel
  void updateConfig({
    String? broker,
    int? port,
    String? wsPath,
    String? faskesId,
    String? deviceId,
    String? cloudGatewayUrl,
    double? poleHeightCm,
    bool? useWildcard,
  }) {
    if (broker != null && broker.trim().isNotEmpty) _broker = broker.trim();
    if (port != null && port > 0) _port = port;
    if (wsPath != null && wsPath.trim().isNotEmpty) _wsPath = wsPath.trim();
    if (faskesId != null && faskesId.trim().isNotEmpty) _faskesId = faskesId.trim();
    if (deviceId != null && deviceId.trim().isNotEmpty) _deviceId = deviceId.trim();
    if (cloudGatewayUrl != null && cloudGatewayUrl.trim().isNotEmpty) {
      _cloudGatewayUrl = cloudGatewayUrl.trim();
    }
    if (poleHeightCm != null && poleHeightCm > 0) _poleHeightCm = poleHeightCm;
    if (useWildcard != null) _useWildcard = useWildcard;
    _hasCustomConfig = true;
  }

  /// Kembalikan pengaturan ke default MAPOTECH Gateway (HiveMQ)
  void resetToDefaults() {
    _broker = 'broker.hivemq.com';
    _port = kIsWeb ? 8884 : 1883;
    _wsPath = '/mqtt';
    _faskesId = 'PUSKESMAS-001';
    _deviceId = 'VTS-001';
    _cloudGatewayUrl = 'https://mapotechiotmqtt.vercel.app';
    _poleHeightCm = 166.0;
    _useWildcard = true;
    _hasCustomConfig = false;
  }

  /// Reconnect dengan konfigurasi baru
  Future<bool> reconnectWithConfig({
    String? broker,
    int? port,
    String? wsPath,
    String? faskesId,
    String? deviceId,
    String? cloudGatewayUrl,
    double? poleHeightCm,
    bool? useWildcard,
  }) async {
    disconnect();
    updateConfig(
      broker: broker,
      port: port,
      wsPath: wsPath,
      faskesId: faskesId,
      deviceId: deviceId,
      cloudGatewayUrl: cloudGatewayUrl,
      poleHeightCm: poleHeightCm,
      useWildcard: useWildcard,
    );
    return await connect(syncGateway: false);
  }

  /// Sinkronisasi konfigurasi dari Cloud Gateway Vercel
  Future<void> syncWithCloudGateway({String? url, bool applyPort = true}) async {
    if (url != null && url.trim().isNotEmpty) {
      _cloudGatewayUrl = url.trim();
    }
    try {
      final uri = Uri.parse('$_cloudGatewayUrl/api/config');
      final resp = await http.get(uri).timeout(const Duration(seconds: 4));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final host = data['broker_host'] as String?;
        if (host != null && host.isNotEmpty) {
          _broker = host;
        }
        final path = data['websocket_path'] as String?;
        if (path != null && path.isNotEmpty) {
          _wsPath = path;
        }
        if (applyPort) {
          if (kIsWeb && data['port_websocket_wss'] is num) {
            _port = (data['port_websocket_wss'] as num).toInt();
          } else if (!kIsWeb && data['port_tcp'] is num) {
            _port = (data['port_tcp'] as num).toInt();
          }
        }
        final ultrasonicPole =
            data['sensors']?['ultrasonic']?['pole_height_default_cm'] as num?;
        if (!_hasCustomConfig && ultrasonicPole != null && ultrasonicPole > 0) {
          // Gunakan acuan gateway hanya jika belum ada pembacaan dari hardware ESP32
          if (_lastTelemetry == null) {
            _poleHeightCm = ultrasonicPole.toDouble();
          }
        }
        _isGatewayHealthy = true;
        debugPrint('[MQTT] Sinkronisasi Cloud Gateway sukses: $_broker:$_port ($_wsPath)');
      }
    } catch (e) {
      debugPrint('[MQTT] Info: Menggunakan konfigurasi default broker: $e');
    }
  }

  // Stream Controllers untuk Telemetri
  final _telemetryController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get telemetryStream => _telemetryController.stream;

  final _connectionStatusController = StreamController<DeviceConnectionStatus>.broadcast();
  Stream<DeviceConnectionStatus> get connectionStatusStream => _connectionStatusController.stream;

  String get _topicTelemetry => 'mapotech/$_faskesId/vitascale/$_deviceId/telemetry';
  String get _topicStatus => 'mapotech/$_faskesId/vitascale/$_deviceId/status';
  String get _topicCommand => 'mapotech/$_faskesId/vitascale/$_deviceId/command';

  /// Memulai koneksi ke Broker MQTT
  Future<bool> connect({
    String? broker,
    int? port,
    String? faskesId,
    String? deviceId,
    bool syncGateway = true,
  }) async {
    if (_isConnected) return true;

    // Sinkronisasi otomatis dari Cloud Gateway Vercel jika belum dikonfigurasi custom
    if (syncGateway && broker == null && port == null && !_hasCustomConfig) {
      await syncWithCloudGateway();
    }

    if (broker != null && broker.trim().isNotEmpty) _broker = broker.trim();
    if (faskesId != null && faskesId.trim().isNotEmpty) _faskesId = faskesId.trim();
    if (deviceId != null && deviceId.trim().isNotEmpty) _deviceId = deviceId.trim();
    if (port != null && port > 0) _port = port;

    final clientId = 'mapotech_vts_${DateTime.now().millisecondsSinceEpoch % 100000}';
    final shouldUseWs = kIsWeb ||
        _port == 8000 ||
        _port == 8083 ||
        _port == 8084 ||
        _port == 8884;
    debugPrint('[MQTT] Menghubungkan ke $_broker:$_port ($connectionProtocolLabel, Client ID: $clientId)...');

    _connectionStatusController.add(DeviceConnectionStatus.connecting);

    try {
      await _updatesSub?.cancel();
      _client = getPlatformMqttClient(
        broker: _broker,
        clientId: clientId,
        port: _port,
        useWebSocket: shouldUseWs,
        wsPath: _wsPath,
      );

      _client!.logging(on: false);
      _client!.keepAlivePeriod = 30;
      _client!.autoReconnect = true;

      _client!.onConnected = _onConnected;
      _client!.onDisconnected = _onDisconnected;
      _client!.onAutoReconnect = () => debugPrint('[MQTT] Auto-reconnecting...');
      _client!.onAutoReconnected = () {
        debugPrint('[MQTT] Auto-reconnected!');
        _subscribeTopicsOnly();
      };

      final connMessage = MqttConnectMessage()
          .withClientIdentifier(clientId)
          .startClean()
          .withWillTopic('mapotech/$_faskesId/vitascale/app_status')
          .withWillMessage('offline')
          .withWillQos(MqttQos.atLeastOnce);

      _client!.connectionMessage = connMessage;

      final status = await _client!.connect();
      if (status?.state == MqttConnectionState.connected) {
        _isConnected = true;
        _connectionStatusController.add(DeviceConnectionStatus.connected);
        _subscribeToTopics();
        return true;
      } else {
        debugPrint('[MQTT] Gagal terhubung, state: ${status?.state}');
        _connectionStatusController.add(DeviceConnectionStatus.disconnected);
        return false;
      }
    } catch (e) {
      debugPrint('[MQTT] Exception saat connect: $e');
      _isConnected = false;
      _connectionStatusController.add(DeviceConnectionStatus.disconnected);
      return false;
    }
  }

  void _onConnected() {
    debugPrint('[MQTT] Sukses terhubung ke $_broker!');
    _isConnected = true;
    _connectionStatusController.add(DeviceConnectionStatus.connected);
  }

  void _onDisconnected() {
    debugPrint('[MQTT] Terputus dari broker.');
    _isConnected = false;
    _isDeviceOnline = null;
    _connectionStatusController.add(DeviceConnectionStatus.disconnected);
  }

  void _subscribeTopicsOnly() {
    if (_client == null || !_isConnected) return;

    debugPrint('[MQTT] Subscribe ke: $_topicTelemetry');
    _client!.subscribe(_topicTelemetry, MqttQos.atLeastOnce);
    _client!.subscribe(_topicStatus, MqttQos.atLeastOnce);

    if (_useWildcard) {
      debugPrint('[MQTT] Subscribe wildcard ke: mapotech/+/vitascale/+/telemetry');
      _client!.subscribe('mapotech/+/vitascale/+/telemetry', MqttQos.atLeastOnce);
      _client!.subscribe('mapotech/+/vitascale/+/status', MqttQos.atLeastOnce);
    }
  }

  void _subscribeToTopics() {
    if (_client == null || !_isConnected) return;
    _subscribeTopicsOnly();

    _updatesSub?.cancel();
    _updatesSub = _client!.updates?.listen((List<MqttReceivedMessage<MqttMessage>> messages) {
      for (final msg in messages) {
        final recMess = msg.payload as MqttPublishMessage;
        final raw = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);

        try {
          final data = jsonDecode(raw) as Map<String, dynamic>;
          if (msg.topic.endsWith('/telemetry')) {
            _isDeviceOnline = true;
            _normalizeTelemetryData(data, msg.topic);
            _lastTelemetry = data;
            _telemetryController.add(data);
          } else if (msg.topic.endsWith('/status')) {
            debugPrint('[MQTT Status] Perangkat: ${data["status"]}');
            if (data["status"] == "online") {
              _isDeviceOnline = true;
              _connectionStatusController.add(DeviceConnectionStatus.connected);
            } else if (data["status"] == "offline") {
              _isDeviceOnline = false;
              _connectionStatusController.add(DeviceConnectionStatus.disconnected);
            }
          }
        } catch (e) {
          debugPrint('[MQTT] Gagal parse JSON dari ${msg.topic}: $e');
        }
      }
    });
  }

  void _normalizeTelemetryData(Map<String, dynamic> data, String topic) {
    // Ekstrak faskes_id / device_id dari topik bila belum ada di payload
    final topicParts = topic.split('/');
    if (topicParts.length >= 5 && topicParts[0] == 'mapotech') {
      data.putIfAbsent('faskes_id', () => topicParts[1]);
      data.putIfAbsent('device_id', () => topicParts[3]);
    }

    if (!data.containsKey('faskes_id') && data.containsKey('puskesmas_id')) {
      data['faskes_id'] = data['puskesmas_id'];
    }

    if (data.containsKey('height') && data['height'] is Map) {
      final hMap = data['height'] as Map<String, dynamic>;
      final rawDist = (hMap['raw_dist_cm'] as num?)?.toDouble();
      final valCm = (hMap['val_cm'] as num?)?.toDouble();
      final payloadPole = (hMap['pole_height_cm'] as num?)?.toDouble();

      // Ikuti acuan tiang/tripod dari firmware ESP32 jika dikirim (misal 166.0 cm atau 200.0 cm)
      if (payloadPole != null && payloadPole > 0) {
        _poleHeightCm = payloadPole;
      }

      final pole = payloadPole ?? _poleHeightCm;
      if (valCm == null && rawDist != null) {
        hMap['val_cm'] = double.parse((pole - rawDist).clamp(0.0, pole).toStringAsFixed(1));
      }
      if (!hMap.containsKey('pole_height_cm')) {
        hMap['pole_height_cm'] = pole;
      }
    }

    if (!data.containsKey('pole_height_cm')) {
      data['pole_height_cm'] = _poleHeightCm;
    }

    if (data.containsKey('weight') && data['weight'] is Map) {
      final wMap = data['weight'] as Map<String, dynamic>;
      final valKg = (wMap['val_kg'] as num?)?.toDouble();
      final rawG = (wMap['raw_g'] as num?)?.toDouble();
      if (valKg == null && rawG != null) {
        wMap['val_kg'] = double.parse((rawG / 1000.0).toStringAsFixed(2));
      } else if (rawG == null && valKg != null) {
        wMap['raw_g'] = double.parse((valKg * 1000.0).toStringAsFixed(1));
      }
    }
  }

  /// Mengirimkan perintah ke perangkat (misal: "tare", "calibrate", "reconfig")
  void sendCommand(String command, {Map<String, dynamic>? params}) {
    if (_client == null || !_isConnected) {
      debugPrint('[MQTT] Gagal kirim perintah: Client belum terhubung.');
      return;
    }

    final payload = {
      'command': command,
      'timestamp': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      ...?params,
    };

    final builder = MqttClientPayloadBuilder();
    builder.addString(jsonEncode(payload));
    _client!.publishMessage(_topicCommand, MqttQos.atLeastOnce, builder.payload!);
    debugPrint('[MQTT TX] Perintah terkirim ke $_topicCommand: $payload');
  }

  /// Perintah Tare (Nol-kan timbangan)
  void tareScale() {
    sendCommand('tare');
  }

  /// Perintah Kalibrasi Otomatis Timbangan ESP32 dengan beban acuan (gram)
  void calibrateScale(double weightGrams) {
    if (weightGrams <= 0) return;
    sendCommand('calibrate', params: {'weight_g': weightGrams});
  }

  /// Perintah Remote Buka Portal Wi-Fi Config ESP32 (192.168.4.1)
  void triggerReconfig() {
    sendCommand('reconfig');
  }

  /// Perintah Remote Ganti Wi-Fi & Parameter ESP32 Langsung via MQTT saat alat sedang online
  void setWifiCredentials({
    required String ssid,
    String password = '',
    String? faskesId,
    String? deviceId,
    String? broker,
    int? port,
    double? poleHeightCm,
    double? calFactor,
  }) {
    if (ssid.trim().isEmpty) return;
    sendCommand('set_wifi', params: {
      'ssid': ssid.trim(),
      'password': password,
      if (faskesId != null && faskesId.trim().isNotEmpty) 'faskes_id': faskesId.trim(),
      if (deviceId != null && deviceId.trim().isNotEmpty) 'device_id': deviceId.trim(),
      if (broker != null && broker.trim().isNotEmpty) 'broker': broker.trim(),
      if (port != null && port > 0) 'port': port,
      if (poleHeightCm != null && poleHeightCm > 0) 'pole_height_cm': poleHeightCm,
      if (calFactor != null && calFactor > 0) 'cal_factor': calFactor,
    });
  }

  /// Memutuskan koneksi MQTT
  void disconnect() {
    _updatesSub?.cancel();
    _updatesSub = null;
    if (_client != null && _isConnected) {
      _client!.disconnect();
    }
    _isConnected = false;
    _isDeviceOnline = null;
    _connectionStatusController.add(DeviceConnectionStatus.disconnected);
  }

  void dispose() {
    disconnect();
    _telemetryController.close();
    _connectionStatusController.close();
  }
}
