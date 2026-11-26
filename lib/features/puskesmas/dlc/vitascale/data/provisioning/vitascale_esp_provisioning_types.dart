const String kVitaScaleBleServiceUuid = '4fafc201-1fb5-459e-8fcc-c5c9c331914b';
const String kVitaScaleBleConfigCharUuid =
    'beb5483e-36e1-4688-b7f5-ea07361b26a8';
const String kVitaScaleBleStatusCharUuid =
    'beb5483f-36e1-4688-b7f5-ea07361b26a8';

/// Maps WebSocket/browser ports (e.g. 8884/8084 WSS) to the plain TCP MQTT port (1883)
/// expected by ESP32 PubSubClient firmware.
int esp32MqttTcpPortFromWebPort(int port) {
  if (port == 8884 || port == 8084 || port == 8083 || port == 8000) {
    return 1883;
  }
  return port > 0 ? port : 1883;
}

/// Payload sent directly from Web browser to ESP32 over USB Serial or BLE.
class EspProvisionPayload {
  final String ssid;
  final String password;
  final String broker;
  final int port;
  final String faskesId;
  final String deviceId;
  final double poleHeightCm;
  final double calFactor;

  const EspProvisionPayload({
    required this.ssid,
    required this.password,
    required this.broker,
    required this.port,
    required this.faskesId,
    required this.deviceId,
    required this.poleHeightCm,
    required this.calFactor,
  });

  Map<String, dynamic> toJson() => {
        'cmd': 'setup',
        'ssid': ssid,
        'password': password,
        'broker': broker,
        'port': port,
        'faskes_id': faskesId,
        'device_id': deviceId,
        'pole_height_cm': poleHeightCm,
        'cal_factor': calFactor,
      };
}

class EspProvisionResult {
  final bool success;
  final String message;
  final Map<String, dynamic>? deviceInfo;

  const EspProvisionResult({
    required this.success,
    required this.message,
    this.deviceInfo,
  });
}
