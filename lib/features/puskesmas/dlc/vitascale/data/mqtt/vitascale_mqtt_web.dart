import 'package:mqtt_client/mqtt_browser_client.dart';
import 'package:mqtt_client/mqtt_client.dart';

MqttClient createPlatformMqttClient({
  required String broker,
  required String clientId,
  required int port,
  bool useWebSocket = true,
}) {
  final scheme = (port == 8084 || port == 443) ? 'wss' : 'ws';
  final uri = '$scheme://$broker/mqtt';
  final client = MqttBrowserClient(uri, clientId);
  client.port = port;
  client.websocketProtocols = MqttClientConstants.protocolsSingleDefault;
  return client;
}
