import 'package:mqtt_client/mqtt_client.dart';

MqttClient createPlatformMqttClient({
  required String broker,
  required String clientId,
  required int port,
  bool useWebSocket = true,
  String wsPath = '/mqtt',
}) {
  throw UnsupportedError('Platform ini tidak didukung untuk koneksi MQTT.');
}
