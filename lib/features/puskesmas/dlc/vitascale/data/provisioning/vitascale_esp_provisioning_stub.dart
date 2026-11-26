import 'vitascale_esp_provisioning_types.dart';

bool get isWebSerialSupported => false;

bool get isWebBluetoothSupported => false;

Future<EspProvisionResult> provisionEspViaUsbSerial(
  EspProvisionPayload payload,
) async {
  return const EspProvisionResult(
    success: false,
    message:
        'Setup USB langsung hanya tersedia di browser web Chrome/Edge (HTTPS/localhost).',
  );
}

Future<EspProvisionResult> provisionEspViaBluetooth(
  EspProvisionPayload payload,
) async {
  return const EspProvisionResult(
    success: false,
    message:
        'Setup Bluetooth (BLE) langsung hanya tersedia di browser web Chrome/Edge.',
  );
}
