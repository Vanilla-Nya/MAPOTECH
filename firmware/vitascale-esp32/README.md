# VitaScale ESP32 Firmware & Hardware Specification

Panduan perakitan dan konfigurasi mikrokontroler ESP32 untuk modul skrining antropometri VitaScale by MAPOTECH (Target Anggaran Hardware: ~Rp1.500.000).

## 1. File Firmware
- [`vitascale_mqtt_esp32.ino`](vitascale_mqtt_esp32.ino): Firmware utama **MQTT + HC-SR04 + HX711 + Provisioning Langsung dari Web Browser (USB Web Serial & Bluetooth BLE)** tanpa perlu membuka portal IP lokal `192.168.4.1`.
- [`vitascale_firmware.ino`](vitascale_firmware.ino): Sketsa referensi lama berbasis HTTP Edge Function & encoder AS5600.
- [`mock_vitascale_mqtt.py`](mock_vitascale_mqtt.py): Simulator telemetri MQTT untuk pengujian UI tanpa perangkat fisik.

## 2. Diagram Pengkabelan (Wiring MQTT Sketch)

```text
ESP32 Pinout (vitascale_mqtt_esp32.ino):
- Ultrasonik TRIG -> GPIO 5
- Ultrasonik ECHO -> GPIO 18
- HX711 DOUT      -> GPIO 19
- HX711 SCK       -> GPIO 21
- Status LED      -> GPIO 2
- VCC             -> 5V (Ultrasonik/HX711) / 3.3V
- GND             -> GND
```

Library Arduino yang dibutuhkan: `PubSubClient`, `ArduinoJson`, `HX711`, serta library bawaan core ESP32 (`WiFi`, `Preferences`, `BLEDevice`).

## 3. Setup Wi-Fi & MQTT Langsung dari Web MAPOTECH (Tanpa `192.168.4.1`)

1. **Perangkat Baru / Penggantian ESP32 Rusak (Belum Online)**:
   - Colokkan ESP32 ke laptop lewat **kabel USB** → di dialog *Konfigurasi MQTT & Wi-Fi Alat* pilih **Kirim via USB (Web Serial)**, atau pilih **Bluetooth (BLE)** secara nirkabel di Chrome/Edge.
   - Pilih Wi-Fi Puskesmas tersimpan (atau isi SSID/sandi baru), lalu klik **Connect & Kirim**.
   - Kredensial & konfigurasi broker/faskes/device disimpan di NVS Flash ESP32 dan alat langsung terhubung ke MQTT (`broker.hivemq.com:1883` TCP, terbaca oleh browser via WSS port `8884`).
2. **Perangkat Sudah Online di MQTT**:
   - Ganti Wi-Fi atau kalibrasi tiang langsung dari tab Web lewat **Remote MQTT (`set_wifi`)** tanpa kabel USB.
