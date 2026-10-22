# Panduan Pengujian & Simulasi: VitaScale by MAPOTECH

Dokumentasi tata cara pengujian otomatis dan manual untuk pengembangan fitur VitaScale.

---

## 1. Menjalankan Unit Tests Otomatis

Jalankan perintah berikut pada terminal root proyek:

```bash
flutter test test/vitascale
```

Pengujian mencakup:
- `anthropometry_mode_test.dart`: Validasi aturan mode telentang (< 24 bln) vs berdiri (≥ 24 bln) standar WHO/Kemenkes serta peringatan klinis override.
- `screening_state_machine_test.dart`: Pengujian siklus hidup sesi, validasi rentang fisik nilai (berat 1-150 kg, tinggi 30-200 cm, lingkar 25-140 cm), dan pencegahan double-submit.
- `whtr_test.dart`: Kalkulasi rasio lingkar perut terhadap tinggi badan dan pembatasan batasan pediatrik (< 5 tahun tidak menerapkan batas acuan dewasa 0.5).

---

## 2. Pengujian Mode Pratinjau (Simulator) di Browser

1. Jalankan aplikasi web:
   ```bash
   flutter run -d web-server --web-browser-flag "--disable-web-security"
   ```
2. Login sebagai Puskesmas (misal: Puskesmas Sumbersari).
3. Buka sidebar drawer, pilih filter **Custom Menu (DLC)**, lalu klik sub-kategori **VITASCALE By MAPOTECH**.
4. Dua menu DLC akan terlihat:
   - **Data Anak/Bayi** (`dlc_vitascale_data_anak`)
   - **Screening Anak/Bayi** (`dlc_vitascale_screening`)
5. Pada kondisi awal, modul akan berada dalam status **Terkunci** (Rule §5).
6. Klik tombol **Aktifkan Pratinjau (Demo)** pada dialog.
7. Buka halaman **Screening Anak/Bayi**:
   - Jika webcam tersedia, preview kamera akan aktif dengan pendeteksi marker papan ukur OpenCV.js.
   - Jika webcam fisik belum terpasang atau sedang digunakan proses lain, tombol **Simulasi Fixture CV** dapat digunakan untuk menguji alur.
   - Gunakan tombol **Simulasi Berat** dan **Simulasi Lingkar** untuk mengalirkan simulasi data stabil dari simulator sensor.
   - Klik **Verifikasi & Simpan Hasil** untuk memverifikasi proteksi input lengkap dan dialog ringkasan hasil akhir.

---

## 3. Checklist Validasi Pengujian Fisik (Setelah Hardware Terpasang)

- [ ] Papan ukur terkalibrasi dengan jarak tepat antara 4 marker referensi sudut (40 cm x 120 cm).
- [ ] Marker penggeser (ring) bergerak mulus bersama pembatas kepala/kaki anak.
- [ ] Pembacaan timbangan 4x load cell 50kg terkalibrasi menggunakan beban standar (anak timbangan terkalibrasi).
- [ ] Sensor AS5600 membaca putaran roda spool pita ukur tanpa slip atau loncatan sudut.
- [ ] Hotspot setup `VitaScale-Setup-XXXX` dapat diakses saat tombol BOOT ditekan.
- [ ] Pengiriman sensor lewat HTTPS membawa header `x-device-token` dan diverifikasi di server.
