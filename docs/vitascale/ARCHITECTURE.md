# Arsitektur Sistem: VitaScale by MAPOTECH

Dokumentasi arsitektur Modul Skrining Antropometri Berbasis IoT & Zero-Install Computer Vision untuk Ekosistem MAPOTECH.

---

## 1. Diagram Komponen Arsitektur

```mermaid
graph TD
    subgraph Browser Petugas ["Browser Petugas (DLC VITASCALE)"]
        UI["Halaman Skrining & Data Anak"]
        Webcam["getUserMedia() Access"]
        OpenCV["OpenCV.js (Vendored Lokal)"]
        SM["Screening State Machine (Riverpod)"]
        Gate["DLC Gate (Locked by Default)"]
    end

    subgraph Hardware ["Perangkat Keras VitaScale (~Rp1.210.000)"]
        ESP32["ESP32 Microcontroller"]
        HX711["4x Load Cell 50kg + HX711 (Berat)"]
        AS5600["Rotary Magnetic Sensor AS5600 (Lingkar Perut)"]
        Prov["Wi-Fi Captive Portal (Setup Hotspot)"]
    end

    subgraph Backend ["Backend MAPOTECH (Supabase)"]
        EdgeFn["Edge Function: vitascale-device"]
        DB_Dev["vitascale.devices (Hashed Tokens)"]
        DB_Code["vitascale.pairing_codes (Single-Use)"]
        DB_Sess["vitascale.screening_sessions"]
        DB_Evt["vitascale.measurement_events (Unique Idempotency)"]
        DB_Res["vitascale.screening_results (Audit Trail)"]
    end

    Webcam -->|Stream Video Lokal| OpenCV
    OpenCV -->|Nilai Panjang/Tinggi (cm)| SM
    ESP32 -->|HX711 Reading| HX711
    ESP32 -->|AS5600 Angle| AS5600
    ESP32 -->|HTTPS POST /measurement (Token Header)| EdgeFn
    EdgeFn -->|Validasi Sesi & Idempotency| DB_Evt
    EdgeFn -->|Sinkronisasi Realtime/Polling| SM
    SM --> UI
```

---

## 2. Prinsip Arsitektur Utama

1. **Pengalaman Zero-Install Bagi Petugas**:
   Petugas puskesmas cukup membuka portal MAPOTECH melalui browser laptop modern (Chrome, Edge, Firefox). Tidak ada instalasi Python, Jupyter Notebook, Local Agent service, atau konfigurasi driver rumit.

2. **Privasi Gambar Pasien Anak**:
   Frame video dari webcam diproses secara lokal di memori browser menggunakan OpenCV.js. **Foto pasien anak TIDAK PERNAH diunggah ke cloud**. Yang dikirim ke server hanyalah angka hasil pengukuran (cm).

3. **Integritas Sensor Fisik**:
   ESP32 menyaring noise sensor secara lokal (averaging window & threshold kestabilan) sebelum mengirimkan satu event pengukuran final yang stabil ke backend.

4. **Pencegahan Duplikasi & Idempotency**:
   Setiap event sensor membawa `idempotency_key` unik. Pengiriman ulang karena koneksi terputus tidak akan menghasilkan pencatatan ganda pada database.
