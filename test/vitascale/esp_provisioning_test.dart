import 'package:flutter_test/flutter_test.dart';
import 'package:mapotech/features/puskesmas/dlc/vitascale/data/provisioning/vitascale_esp_provisioning_bridge.dart';

void main() {
  group('VitaScale ESP Provisioning Tests', () {
    test('Maps browser WebSocket MQTT ports to ESP32 TCP port 1883', () {
      expect(esp32MqttTcpPortFromWebPort(8884), 1883);
      expect(esp32MqttTcpPortFromWebPort(8084), 1883);
      expect(esp32MqttTcpPortFromWebPort(8083), 1883);
      expect(esp32MqttTcpPortFromWebPort(8000), 1883);
      expect(esp32MqttTcpPortFromWebPort(1883), 1883);
      expect(esp32MqttTcpPortFromWebPort(1884), 1884);
      expect(esp32MqttTcpPortFromWebPort(0), 1883);
    });

    test('Serializes EspProvisionPayload to ESP32 setup JSON schema', () {
      const payload = EspProvisionPayload(
        ssid: 'Puskesmas_WiFi',
        password: 'secret',
        broker: 'broker.hivemq.com',
        port: 1883,
        faskesId: 'PUSKESMAS-001',
        deviceId: 'VTS-002',
        poleHeightCm: 166.0,
        calFactor: 25.75,
      );

      expect(payload.toJson(), {
        'cmd': 'setup',
        'ssid': 'Puskesmas_WiFi',
        'password': 'secret',
        'broker': 'broker.hivemq.com',
        'port': 1883,
        'faskes_id': 'PUSKESMAS-001',
        'device_id': 'VTS-002',
        'pole_height_cm': 166.0,
        'cal_factor': 25.75,
      });
    });

    test('Non-web stub disables browser USB Serial and BLE cleanly', () {
      expect(isWebSerialSupported, isFalse);
      expect(isWebBluetoothSupported, isFalse);
    });
  });
}
