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
  bool _isConnected = false;
  bool get isConnected => _isConnected;

  String _broker = 'broker.emqx.io';
  int _port = kIsWeb ? 8084 : 1883; // 8084 WSS untuk Web, 1883 TCP untuk Desktop/Mobile
  String _faskesId = 'PUSKESMAS-001';
  String _deviceId = 'VTS-001';
  String _cloudGatewayUrl = 'https://mapotechiotmqtt.vercel.app';
  bool _isGatewayHealthy = false;

  String get broker => _broker;
  int get port => _port;
  String get faskesId => _faskesId;
  String get deviceId => _deviceId;
  String get cloudGatewayUrl => _cloudGatewayUrl;
  bool get isGatewayHealthy => _isGatewayHealthy;

  /// Sinkronisasi konfigurasi dari Cloud Gateway Vercel
  Future<void> syncWithCloudGateway({String? url}) async {
    _cloudGatewayUrl = url ?? _cloudGatewayUrl;
    try {
      final uri = Uri.parse('$_cloudGatewayUrl/api/config');
      final resp = await http.get(uri).timeout(const Duration(seconds: 4));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        if (data.containsKey('broker_host') && (data['broker_host'] as String).isNotEmpty) {
          _broker = data['broker_host'] as String;
        }
        if (kIsWeb && data.containsKey('port_websocket_wss')) {
          _port = (data['port_websocket_wss'] as num).toInt();
        } else if (!kIsWeb && data.containsKey('port_tcp')) {
          _port = (data['port_tcp'] as num).toInt();
        }
        _isGatewayHealthy = true;
        debugPrint('[MQTT] Sinkronisasi konfigurasi dari Cloud Gateway sukses: $_broker:$_port');
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
  }) async {
    if (_isConnected) return true;

    // Sinkronisasi otomatis dari Cloud Gateway Vercel
    await syncWithCloudGateway();

    _broker = broker ?? _broker;
    _faskesId = faskesId ?? _faskesId;
    _deviceId = deviceId ?? _deviceId;
    if (port != null) {
      _port = port;
    } else {
      _port = kIsWeb ? 8084 : 1883;
    }

    final clientId = 'mapotech_vts_${DateTime.now().millisecondsSinceEpoch % 100000}';
    debugPrint('[MQTT] Menghubungkan ke $_broker:$_port (Client ID: $clientId)...');

    _connectionStatusController.add(DeviceConnectionStatus.connecting);

    try {
      _client = getPlatformMqttClient(
        broker: _broker,
        clientId: clientId,
        port: _port,
        useWebSocket: kIsWeb || _port == 8083 || _port == 8084,
      );

      _client!.logging(on: false);
      _client!.keepAlivePeriod = 30;
      _client!.autoReconnect = true;

      _client!.onConnected = _onConnected;
      _client!.onDisconnected = _onDisconnected;
      _client!.onAutoReconnect = () => debugPrint('[MQTT] Auto-reconnecting...');
      _client!.onAutoReconnected = () => debugPrint('[MQTT] Auto-reconnected!');

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
    _connectionStatusController.add(DeviceConnectionStatus.disconnected);
  }

  void _subscribeToTopics() {
    if (_client == null || !_isConnected) return;

    debugPrint('[MQTT] Subscribe ke: $_topicTelemetry');
    _client!.subscribe(_topicTelemetry, MqttQos.atLeastOnce);
    _client!.subscribe(_topicStatus, MqttQos.atLeastOnce);

    _client!.updates?.listen((List<MqttReceivedMessage<MqttMessage>> messages) {
      for (final msg in messages) {
        final recMess = msg.payload as MqttPublishMessage;
        final raw = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);

        try {
          final data = jsonDecode(raw) as Map<String, dynamic>;
          if (msg.topic == _topicTelemetry) {
            _telemetryController.add(data);
          } else if (msg.topic == _topicStatus) {
            debugPrint('[MQTT Status] Perangkat: ${data["status"]}');
            if (data["status"] == "online") {
              _connectionStatusController.add(DeviceConnectionStatus.connected);
            } else if (data["status"] == "offline") {
              _connectionStatusController.add(DeviceConnectionStatus.disconnected);
            }
          }
        } catch (e) {
          debugPrint('[MQTT] Gagal parse JSON dari ${msg.topic}: $e');
        }
      }
    });
  }

  /// Mengirimkan perintah ke perangkat (misal: "tare")
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

  /// Memutuskan koneksi MQTT
  void disconnect() {
    if (_client != null && _isConnected) {
      _client!.disconnect();
    }
    _isConnected = false;
    _connectionStatusController.add(DeviceConnectionStatus.disconnected);
  }

  void dispose() {
    disconnect();
    _telemetryController.close();
    _connectionStatusController.close();
  }
}
