# Modul Fitur MAPOTECH (`lib/features/`)

Folder ini memuat seluruh fitur fungsional per peran (role) pengguna dan fasilitas kesehatan dalam ekosistem MAPOTECH.

---

## 📦 Daftar Library Eksternal yang Digunakan per Modul Fitur

Sesuai **Rule 1 (Pencatatan Library Eksternal)** pada `Rule.md`, berikut adalah inventaris dependensi pihak ketiga pada tiap modul fitur:

| Modul Fitur | Package Eksternal | Alasan Penggunaan & Peruntukan | File Implementasi Utama |
| :--- | :--- | :--- | :--- |
| **`pasien`** | **`google_generative_ai`** (`^0.4.7`) | Integrasi AI Assistant (Gemini) untuk konsultasi awal gejala dan triage pasien. | `pasien/dashboard/frontend/ai_assistant/` |
| **`pasien`** | **`flutter_riverpod`** (`^2.5.1`) | State management reaktif untuk percakapan chat AI asisten pasien. | `pasien/dashboard/frontend/ai_assistant/presentation/ai_chat_provider.dart` |
| **`pasien`** | **`qr_flutter`** (`^4.1.0`) | Render barcode QR antrian pasien & bukti verifikasi resep digital. | `pasien/dashboard/frontend/pasien_qr_scanner_page.dart` |
| **`pasien`** | **`geolocator`** (`^11.0.0`) | Mengambil posisi GPS pengguna untuk mengurutkan faskes dan apotek terdekat. | `pasien/dashboard/frontend/pasien_dokter_search.dart`, `pasien_apotek_search.dart` |
| **`apotek`** | **`url_launcher`** (`^6.3.0`) | Menghubungkan langsung ke WhatsApp pembeli saat pesanan obat siap diambil/dikirim. | `apotek/dashboard/frontend/apotek_pesanan.dart` |
| **`apotek`** | **`file_picker`** (`^8.1.7`) | Mengunggah dokumen legalitas apotek (SIA, SIPA) dan foto katalog obat. | `apotek/dashboard/frontend/apotek_profile.dart`, `apotek_inventori.dart` |
| **`apotek`** | **`image`** (`^4.9.1`) | Kompresi dan manipulasi gambar obat sebelum diunggah ke storage. | `apotek/dashboard/frontend/apotek_profile.dart` |
| **`dokter`** | **`flutter_map`** & **`latlong2`** | Peta lokasi klinik praktik mandiri dokter. | `dokter/dashboard/frontend/web_map_widget.dart` |
| **`dokter`** | **`url_launcher`** (`^6.3.0`) | Navigasi pembukaan dokumen rujukan atau chat komunikasi pasien. | `dokter/dashboard/frontend/dokter_antrian.dart` |
| **`puskesmas`** | **`flutter_map`** & **`latlong2`** | Pemetaan persebaran lokasi Pustu / Ponkesdes binaan serta peta risiko ibu hamil. | `puskesmas/dashboard/frontend/management_pustu_ponkesdes.dart`, `puskesmas_pantauan_ibu_hamil.dart` |
| **`dashboard`** | **`google_fonts`** (`^6.2.0`) | Tipografi navigasi shell, dashboard drawer, dan header aplikasi. | `dashboard/dashboard_shell.dart`, `dashboard/widgets/dashboard_drawer.dart` |
| **`landing`** | **`flutter_animate`** (`^4.5.2`) | Efek visual interaktif animasi portal kesehatan di halaman awal. | `landing/widgets/achievements_section.dart`, `landing_page_layout.dart` |

---

## 🎨 Standar Penggunaan Komponen UI di Modul Fitur
Seluruh tampilan UI pada sub-folder `frontend/` diwajibkan mengimpor dan menggunakan komponen custom dari:
```dart
import 'package:mapotech/shared/widgets/ui.dart';
```
Dilarang menggunakan raw `ElevatedButton`, raw `TextField`, atau raw `AlertDialog` secara ad-hoc tanpa dibungkus komponen kustom.
