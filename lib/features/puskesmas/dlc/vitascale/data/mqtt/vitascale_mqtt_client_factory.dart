import 'package:mqtt_client/mqtt_client.dart';
import 'vitascale_mqtt_stub.dart'
    if (dart.library.io) 'vitascale_mqtt_io.dart'
    if (dart.library.html) 'vitascale_mqtt_web.dart';

MqttClient getPlatformMqttClient({
  required String broker,
  required String clientId,
  required int port,
  bool useWebSocket = true,
}) {
  return createPlatformMqttClient(
    broker: broker,
    clientId: clientId,
    port: port,
    useWebSocket: useWebSocket,
  );
}
