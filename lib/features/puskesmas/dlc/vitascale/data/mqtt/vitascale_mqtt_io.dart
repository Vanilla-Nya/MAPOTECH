import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

MqttClient createPlatformMqttClient({
  required String broker,
  required String clientId,
  required int port,
  bool useWebSocket = true,
}) {
  final client = MqttServerClient(broker, clientId);
  client.port = port;
  if (useWebSocket || port == 8083 || port == 8084) {
    client.useWebSocket = true;
    client.websocketProtocols = MqttClientConstants.protocolsSingleDefault;
  }
  return client;
}
