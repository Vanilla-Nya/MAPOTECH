# Modul DLC: VitaScale by MAPOTECH

Modul Skrining Antropometri Berbasis IoT & Computer Vision Zero-Install untuk Anak Usia 0–12 Tahun pada Faskes Puskesmas MAPOTECH.

## 1. Daftar Library / Package yang Digunakan

| No | Nama Library | Versi | Peruntukan & Alasan Penggunaan |
|:---|:---|:---|:---|
| 1 | `flutter_riverpod` | `^2.5.1` | State management reaktif untuk sesi skrining, status sensor, dan kontrol perangkat. |
| 2 | `google_fonts` | `^6.2.0` | Tipografi standar MAPOTECH (`Outfit` dan `Inter`) untuk konsistensi visual faskes. |
| 3 | `supabase_flutter` | `^2.8.4` | Akses data pasien Puskesmas, penyimpanan sesi skrining, dan audit trail klinis. |
| 4 | `uuid` | `^4.5.3` | Pembuatan session ID, idempotency key event sensor, dan pairing code transaksi. |
| 5 | `OpenCV.js (Vendored)` | `4.9.0` (Lokal di `web/vitascale/`) | Computer Vision zero-install di browser untuk deteksi marker fisik papan ukur anak tanpa Python atau Local Agent. |

## 2. Struktur Modul

- `vitascale_dlc_gate.dart`: Pengaman DLC terkunci (*locked-by-default*) dan aktivasi mode pratinjau (Demo).
- `data/`: Model data (`ChildProfile`, `ScreeningSession`, `MeasurementEvent`), repositori (Simulator + Supabase), dan mock adapter ESP32.
- `logic/`: Mesin status (*State Machine*), kalkulasi mode antropometri (WHO telentang <24 bln vs berdiri >=24 bln), dan rasio WHtR.
- `cv/`: Integrasi webcam browser (`getUserMedia`), modul OpenCV.js marker-based perspective correction, dan pembersihan media stream.
- `widgets/`: Komponen UI standar faskes (kartu pengukuran, indikator kestabilan sensor, status bar koneksi ESP32).
- `pages/`: 
  - `vitascale_data_anak_page.dart`: Menu Manajemen Data Anak/Bayi (0–12 tahun).
  - `vitascale_screening_page.dart`: Menu Sesi Skrining & Pengukuran Aktif VitaScale.

## 3. Contoh Penggunaan

```dart
// Navigasi ke Sesi Skrining dengan Pasien Terpilih
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => VitaScaleScreeningPage(
      selectedChild: childProfile,
    ),
  ),
);
```
