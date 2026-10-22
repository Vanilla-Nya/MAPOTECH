# VitaScale ESP32 Firmware & Hardware Specification

Panduan perakitan dan konfigurasi mikrokontroler ESP32 untuk modul skrining antropometri VitaScale by MAPOTECH (Target Anggaran Hardware: ~Rp1.500.000).

## 1. Komponen Perangkat Keras

| No | Komponen | Estimasi Biaya | Keterangan / Fungsi |
|:---|:---|:---|:---|
| 1 | ESP32-WROOM-32 DevKit V1 | Rp65.000 | Mikrokontroler utama Wi-Fi & I2C/SPI bus. |
| 2 | Modul ADC HX711 24-bit | Rp15.000 | Pengkondisi sinyal jembatan Wheatstone timbangan. |
| 3 | 4x Half-Bridge Load Cell 50kg (Total 200kg) | Rp70.000 | Sensor berat badan anak/bayi. |
| 4 | Papan Combiner 4 Load Cell | Rp15.000 | Menggabungkan 4 load cell menjadi satu jembatan penuh (Full Wheatstone Bridge). |
| 5 | Sensor Magnetik AS5600 12-bit (I2C) | Rp35.000 | Pembacaan rotasi sudut pita ukur lingkar perut (resolusi 4096 step per putaran). |
| 6 | Magnet Diametrik Neodymium | Rp10.000 | Dipasang pada as poros roda/spool pita ukur. |
| 7 | Mekanik Papan Ukur, Spool Pita, & Enclosure 3D | Rp500.000 | Rangka papan ukur dengan 4 marker referensi + 1 marker ring geser. |
| 8 | Webcam USB 1080p (terhubung ke laptop) | Rp450.000 | Menghadap ke papan ukur anak via browser `getUserMedia()`. |
| 9 | Power Supply 5V 2A & Kabel | Rp50.000 | Catu daya stabil mikrokontroler. |
| **Total** | | **~Rp1.210.000** | Masuk dalam batas target anggaran Rp1.500.000. |

## 2. Diagram Pengkabelan (Wiring)

```
ESP32 Pinout:
- HX711 DOUT -> GPIO 19
- HX711 SCK  -> GPIO 18
- AS5600 SDA -> GPIO 21
- AS5600 SCL -> GPIO 22
- Status LED -> GPIO 2
- Setup Button -> GPIO 0 (BOOT button)
- VCC -> 3.3V / 5V
- GND -> GND
```

## 3. Wi-Fi Provisioning & Pairing

1. Saat perangkat pertama kali menyala atau tombol BOOT ditekan 3 detik, ESP32 membuat Access Point `VitaScale-Setup-XXXX`.
2. Petugas membuka browser di laptop/ponsel ke alamat `http://192.168.4.1/`.
3. Petugas memasukkan SSID & Password Wi-Fi Faskes serta 6-digit Kode Pairing dari portal MAPOTECH.
4. Kredensial disimpan ke memori Flash NVS yang aman, dan perangkat melakukan restart untuk terhubung ke internet.
5. ESP32 menukar kode pairing dengan token perangkat permanen melalui endpoint HTTPS `POST /vitascale-device/pair`.
