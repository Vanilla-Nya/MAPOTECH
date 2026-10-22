# Kebijakan Keamanan & Privasi: VitaScale by MAPOTECH

Dokumentasi arsitektur keamanan, proteksi data anak, dan kepatuhan regulasi medis.

---

## 1. Privasi Data & Perlindungan Gambar Anak

- **Pemrosesan Citra di Browser (Client-Side Only)**: Pemrosesan computer vision papan ukur menggunakan OpenCV.js berjalan 100% di dalam RAM browser petugas.
- **Tanpa Unggah Foto**: Sistem tidak mengunggah atau menyimpan foto anak ke server/cloud storage. Hanya data numerik akhir (cm) dan status validitas yang dikirimkan.
- **Pembersihan Resource Kamera**: Seluruh `MediaStreamTrack` webcam dihentikan (`stop()`) dan elemen video di-detach saat sesi skrining ditutup atau saat petugas berpindah halaman.

---

## 2. Keamanan Kredensial & Hardware (ESP32)

- **Tanpa Hardcode Kredensial**: SSID dan Password Wi-Fi tidak ditanam dalam firmware. ESP32 menggunakan hotspot portal lokal `VitaScale-Setup-XXXX`.
- **Tanpa Service-Role Key di Firmware**: ESP32 tidak pernah memegang kunci administrator/service-role Supabase.
- **Hashed Token Authentication**: Token perangkat disimpan di database dalam bentuk SHA-256 hash (`token_hash`).
- **Kode Pairing Sekali Pakai (Single-Use)**: Kode pairing memiliki masa berlaku pendek (10 menit) dan langsung dihanguskan (`used_at`) saat registrasi berhasil.

---

## 3. Isolasi Multi-Tenant & Row Level Security (RLS)

- Setiap tabel dalam schema `vitascale` dilindungi dengan RLS PostgreSQL.
- Petugas Puskesmas hanya dapat melihat dan memverifikasi data anak dan perangkat yang terdaftar di bawah `facility_id` faskesnya sendiri.
- Akses lintas fasilitas secara tidak sah diblokir di level database.
