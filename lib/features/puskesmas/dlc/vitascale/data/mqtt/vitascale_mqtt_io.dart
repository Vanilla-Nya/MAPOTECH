import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

MqttClient createPlatformMqttClient({
  required String broker,
  required String clientId,
  required int port,
  bool useWebSocket = false,
  String wsPath = '/mqtt',
}) {
  final isWsPort = port == 8000 || port == 8083 || port == 8084 || port == 8884;
  final shouldUseWs = useWebSocket ||
      isWsPort ||
      broker.startsWith('ws://') ||
      broker.startsWith('wss://');
  final cleanBroker = broker.replaceFirst(RegExp(r'^(wss?|mqtts?)://'), '');

  if (shouldUseWs) {
    final normalizedPath = wsPath.startsWith('/') ? wsPath : '/$wsPath';
    final isSecureWs = port == 8884 ||
        port == 8084 ||
        port == 443 ||
        broker.startsWith('wss://');
    final scheme = isSecureWs ? 'wss' : 'ws';
    final wsUri = '$scheme://$cleanBroker$normalizedPath';
    final client = MqttServerClient(wsUri, clientId);
    client.port = port;
    client.useWebSocket = true;
    client.websocketProtocols = MqttClientConstants.protocolsSingleDefault;
    return client;
  }

  final client = MqttServerClient(cleanBroker, clientId);
  client.port = port;
  if (port == 8883 || broker.startsWith('mqtts://')) {
    client.secure = true;
  }
  return client;
}
