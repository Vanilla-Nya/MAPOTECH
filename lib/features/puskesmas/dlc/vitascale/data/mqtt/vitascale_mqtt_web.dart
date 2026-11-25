import 'package:mqtt_client/mqtt_browser_client.dart';
import 'package:mqtt_client/mqtt_client.dart';

MqttClient createPlatformMqttClient({
  required String broker,
  required String clientId,
  required int port,
  bool useWebSocket = true,
  String wsPath = '/mqtt',
}) {
  final cleanBroker = broker.replaceFirst(RegExp(r'^wss?://'), '');
  final normalizedPath = wsPath.startsWith('/') ? wsPath : '/$wsPath';
  final isSecure = port == 8884 || port == 8084 || port == 443 || port == 8883;
  final scheme = broker.startsWith('wss://')
      ? 'wss'
      : (broker.startsWith('ws://') ? 'ws' : (isSecure ? 'wss' : 'ws'));
  final uri = '$scheme://$cleanBroker$normalizedPath';
  final client = MqttBrowserClient(uri, clientId);
  client.port = port;
  client.websocketProtocols = MqttClientConstants.protocolsSingleDefault;
  return client;
}
