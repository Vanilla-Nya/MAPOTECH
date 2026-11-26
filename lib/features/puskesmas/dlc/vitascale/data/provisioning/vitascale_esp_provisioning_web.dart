import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';
import 'package:web/web.dart' as web;
import 'vitascale_esp_provisioning_types.dart';

bool get isWebSerialSupported {
  if (!web.window.isSecureContext) return false;
  final nav = web.window.navigator as JSObject;
  return nav.hasProperty('serial'.toJS).toDart;
}

bool get isWebBluetoothSupported {
  if (!web.window.isSecureContext) return false;
  final nav = web.window.navigator as JSObject;
  return nav.hasProperty('bluetooth'.toJS).toDart;
}

/// Sends Wi-Fi & MQTT configuration straight from browser to ESP32 over USB Serial (Web Serial API).
Future<EspProvisionResult> provisionEspViaUsbSerial(
  EspProvisionPayload payload,
) async {
  if (!isWebSerialSupported) {
    return const EspProvisionResult(
      success: false,
      message:
          'Browser ini belum mendukung USB Web Serial. Gunakan Google Chrome atau Microsoft Edge via HTTPS/localhost.',
    );
  }

  final nav = web.window.navigator as JSObject;
  final serial = nav.getProperty<JSObject>('serial'.toJS);
  JSObject? port;
  JSObject? reader;
  bool isPortOpen = false;

  try {
    port = await serial.callMethod<JSPromise<JSObject>>('requestPort'.toJS).toDart;

    final openOpts = {'baudRate': 115200}.jsify()!;
    await port.callMethod<JSPromise<JSAny?>>('open'.toJS, openOpts).toDart;
    isPortOpen = true;

    // Wait briefly in case ESP32 DevKit auto-resets when opening COM port.
    await Future<void>.delayed(const Duration(milliseconds: 1100));

    final writable = port.getProperty<JSObject?>('writable'.toJS);
    if (writable == null) {
      return const EspProvisionResult(
        success: false,
        message: 'Port USB tidak dapat ditulis (writable stream kosong).',
      );
    }

    final line = '${jsonEncode(payload.toJson())}\n';
    final bytes = Uint8List.fromList(utf8.encode(line));

    final writer = writable.callMethod<JSObject>('getWriter'.toJS);
    try {
      await writer
          .callMethod<JSPromise<JSAny?>>('write'.toJS, bytes.toJS)
          .toDart;
    } finally {
      try {
        writer.callMethod<JSAny?>('releaseLock'.toJS);
      } catch (_) {}
    }

    // Listen briefly for optional JSON acknowledgement from ESP32 firmware.
    Map<String, dynamic>? ackInfo;
    final readable = port.getProperty<JSObject?>('readable'.toJS);
    if (readable != null) {
      reader = readable.callMethod<JSObject>('getReader'.toJS);
      final deadline = DateTime.now().add(const Duration(milliseconds: 2200));
      final buffer = StringBuffer();
      while (DateTime.now().isBefore(deadline)) {
        try {
          final remaining = deadline.difference(DateTime.now());
          if (remaining.inMilliseconds <= 0) break;
          final chunkObj = await reader
              .callMethod<JSPromise<JSObject>>('read'.toJS)
              .toDart
              .timeout(remaining);
          final done =
              (chunkObj.getProperty<JSBoolean?>('done'.toJS))?.toDart ?? true;
          if (done) break;
          final val = chunkObj.getProperty<JSUint8Array?>('value'.toJS);
          if (val != null) {
            buffer.write(utf8.decode(val.toDart, allowMalformed: true));
            final text = buffer.toString();
            for (final candidate in text.split('\n')) {
              final trimmed = candidate.trim();
              if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
                try {
                  final decoded = jsonDecode(trimmed);
                  if (decoded is Map<String, dynamic> &&
                      decoded['status'] != null) {
                    ackInfo = decoded;
                  }
                } catch (_) {}
              }
            }
            if (ackInfo != null) break;
          }
        } on TimeoutException {
          break;
        } catch (_) {
          break;
        }
      }
      try {
        await reader
            .callMethod<JSPromise<JSAny?>>('cancel'.toJS)
            .toDart
            .timeout(const Duration(milliseconds: 500));
      } catch (_) {}
      try {
        reader.callMethod<JSAny?>('releaseLock'.toJS);
      } catch (_) {}
      reader = null;
    }

    final ackStatus = ackInfo?['status']?.toString();
    if (ackStatus == 'error') {
      return EspProvisionResult(
        success: false,
        message:
            ackInfo?['message']?.toString() ??
            'ESP32 melaporkan error saat menyimpan konfigurasi USB.',
        deviceInfo: ackInfo,
      );
    }

    return EspProvisionResult(
      success: true,
      message: ackInfo != null
          ? 'Konfigurasi Wi-Fi "${payload.ssid}" & MQTT dikonfirmasi ESP32 via USB!'
          : 'Konfigurasi Wi-Fi "${payload.ssid}" & MQTT terkirim ke ESP32 via USB (115200 baud).',
      deviceInfo: ackInfo,
    );
  } catch (e) {
    final err = e.toString();
    if (err.contains('NotFoundError') || err.contains('No port selected')) {
      return const EspProvisionResult(
        success: false,
        message: 'Pemilihan port USB ESP32 dibatalkan.',
      );
    }
    return EspProvisionResult(
      success: false,
      message: 'Gagal mengirim via USB Serial: $err',
    );
  } finally {
    if (reader != null) {
      try {
        await reader.callMethod<JSPromise<JSAny?>>('cancel'.toJS).toDart;
      } catch (_) {}
      try {
        reader.callMethod<JSAny?>('releaseLock'.toJS);
      } catch (_) {}
    }
    if (isPortOpen && port != null) {
      try {
        await port.callMethod<JSPromise<JSAny?>>('close'.toJS).toDart;
      } catch (_) {}
    }
  }
}

/// Sends Wi-Fi & MQTT configuration wirelessly from browser to ESP32 over Web Bluetooth (BLE GATT).
Future<EspProvisionResult> provisionEspViaBluetooth(
  EspProvisionPayload payload,
) async {
  if (!isWebBluetoothSupported) {
    return const EspProvisionResult(
      success: false,
      message:
          'Browser ini belum mendukung Web Bluetooth (BLE). Gunakan Chrome/Edge via HTTPS/localhost, atau pilih USB Serial.',
    );
  }

  final nav = web.window.navigator as JSObject;
  final bluetooth = nav.getProperty<JSObject>('bluetooth'.toJS);
  JSObject? gattServer;

  try {
    final options = {
      'filters': [
        {'services': [kVitaScaleBleServiceUuid]},
        {'namePrefix': 'VitaScale'},
      ],
      'optionalServices': [kVitaScaleBleServiceUuid],
    }.jsify()!;

    final device = await bluetooth
        .callMethod<JSPromise<JSObject>>('requestDevice'.toJS, options)
        .toDart;

    final gatt = device.getProperty<JSObject?>('gatt'.toJS);
    if (gatt == null) {
      return const EspProvisionResult(
        success: false,
        message: 'Perangkat Bluetooth terpilih tidak memiliki layanan GATT.',
      );
    }

    gattServer = await gatt.callMethod<JSPromise<JSObject>>('connect'.toJS).toDart;
    final service = await gattServer
        .callMethod<JSPromise<JSObject>>(
          'getPrimaryService'.toJS,
          kVitaScaleBleServiceUuid.toJS,
        )
        .toDart;
    final configChar = await service
        .callMethod<JSPromise<JSObject>>(
          'getCharacteristic'.toJS,
          kVitaScaleBleConfigCharUuid.toJS,
        )
        .toDart;

    // Chunk to 20-byte MTU-safe packets ending with '\n' so all BLE adapters work reliably.
    final payloadBytes = Uint8List.fromList(
      utf8.encode('${jsonEncode(payload.toJson())}\n'),
    );
    final useWriteWithResponse =
        configChar.hasProperty('writeValueWithResponse'.toJS).toDart;
    final writeMethod =
        useWriteWithResponse ? 'writeValueWithResponse' : 'writeValue';

    const chunkSize = 20;
    for (var offset = 0; offset < payloadBytes.length; offset += chunkSize) {
      final end = (offset + chunkSize > payloadBytes.length)
          ? payloadBytes.length
          : offset + chunkSize;
      final chunk = Uint8List.sublistView(payloadBytes, offset, end);
      await configChar
          .callMethod<JSPromise<JSAny?>>(writeMethod.toJS, chunk.toJS)
          .toDart;
    }

    final deviceName =
        device.getProperty<JSString?>('name'.toJS)?.toDart ?? 'ESP32 VitaScale';

    return EspProvisionResult(
      success: true,
      message:
          'Konfigurasi Wi-Fi "${payload.ssid}" & MQTT berhasil dikirim ke $deviceName via Bluetooth (BLE)!',
      deviceInfo: {'device_name': deviceName, 'transport': 'ble'},
    );
  } catch (e) {
    final err = e.toString();
    if (err.contains('NotFoundError') || err.contains('cancelled')) {
      return const EspProvisionResult(
        success: false,
        message: 'Pemilihan perangkat Bluetooth dibatalkan.',
      );
    }
    return EspProvisionResult(
      success: false,
      message: 'Gagal mengirim via Bluetooth BLE: $err',
    );
  } finally {
    if (gattServer != null) {
      try {
        gattServer.callMethod<JSAny?>('disconnect'.toJS);
      } catch (_) {}
    }
  }
}
