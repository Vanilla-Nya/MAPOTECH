# Shared Modules & Services MAPOTECH (`lib/shared/`)

Folder ini memuat pustaka logika inti bersama, layanan integrasi API pihak ketiga (Supabase, SatuSehat, RevGeo), utilitas formater, serta layanan lokasi GPS.

---

## 📦 Daftar Library Eksternal yang Digunakan di Modul Shared

Sesuai **Rule 1 (Pencatatan Library Eksternal)** pada `Rule.md`, berikut rincian paket pihak ketiga yang digunakan pada folder ini:

| Nama Package | Versi (pubspec) | Penggunaan & Alasan Kebutuhan | File Terkait |
| :--- | :--- | :--- | :--- |
| **`supabase_flutter`** | `^2.8.4` | Backend-as-a-Service utama (Database PostgreSQL, Otentikasi Pengguna, Realtime listener untuk antrian/pesanan). | `supabase_service.dart` |
| **`bcrypt`** | `^1.2.0` | Algoritma hashing kata sandi aman untuk enkripsi akun mandiri dan verifikasi PIN staf faskes. | `supabase_service.dart` |
| **`crypto`** | `^3.0.3` | Enkripsi hashing SHA-256 dan HMAC untuk integrasi protokol SatuSehat Kemenkes dan BPJS. | `satusehat_service.dart`, `supabase_service.dart` |
| **`http`** | `^1.6.0` | HTTP Client untuk integrasi REST API RevGeo (`https://revgeo.relvastudio.com/`) dan SatuSehat OAuth2. | `geo_boundary_service.dart`, `satusehat_service.dart` |
| **`geolocator`** | `^11.0.0` | Akses sensor GPS perangkat untuk menentukan koordinat pengguna saat mencari faskes terdekat. | `location_service.dart` |
| **`latlong2`** | `^0.9.1` | Perhitungan kalkulasi jarak geografis (Haversine) antara faskes dengan pasien. | `location_service.dart`, `geo_boundary_service.dart` |
| **`flutter_dotenv`** | `^5.2.1` | Memuat kredensial rahasia (Supabase URL, Anon Key, API Key) dari file `env`. | `supabase_service.dart`, `satusehat_service.dart` |
| **`uuid`** | `^4.5.3` | Generator identifier unik universal untuk transaksi resep, nomor antrian, dan log. | `supabase_service.dart` |

---

## 📂 Struktur Modul Shared

1. **`supabase_service.dart`**: Layanan terpusat untuk seluruh operasi database, autentikasi multi-peran (Dokter, Apotek, Pasien, Ponkesdes, Puskesmas, Admin), dan relasi faskes.
2. **`geo_boundary_service.dart`**: Integrasi wajib batas poligon wilayah administrasi menggunakan **RevGeo API** (`https://revgeo.relvastudio.com/`).
3. **`satusehat_service.dart`**: Integrasi standar rekam medis elektronik (RME) SatuSehat Kementerian Kesehatan Republik Indonesia.
4. **`location_service.dart`**: Layanan deteksi lokasi perangkat dan estimasi jarak faskes.
5. **`icd_codes.dart`**: Katalog kode diagnosis standar internasional ICD-10 untuk dokter dan perawat.
6. **`thousands_formatter.dart`**: Formatter angka dan mata uang Rupiah untuk modul keuangan dan kasir.
7. **`layouts/responsive_layout.dart`**: Breakpoint layout adaptif (Mobile, Tablet, Desktop, Wide).
8. **`widgets/`**: Seluruh koleksi komponen custom UI (lihat `widgets/README.md`).
