# ATURAN & STANDAR PENGEMBANGAN MAPOTECH (RULE.MD)

Dokumen ini adalah pedoman wajib bagi AI Assistant dan Developer sebelum melakukan penambahan kode, modifikasi, pembuatan menu, atau perancangan UI di dalam proyek **MAPOTECH**. Wajib dibaca dan dipatuhi setiap saat.

---

## 1. Pembuatan Komponen UI Mandiri (Custom UI & List Library)

### A. Kebijakan Komponen UI Kustom
* **Custom UI File**: Semua elemen antarmuka (UI) dalam proyek ini **harus dibuat menggunakan file kustom** di dalam proyek yang diletakkan pada folder `lib/shared/widgets/` (atau folder modul terkait jika spesifik untuk modul tersebut).
* **Bikin Komponen Kustom Dulu**: Jika komponen UI yang dibutuhkan belum tersedia, **WAJIB membuat file komponen kustomnya terlebih dahulu** di `lib/shared/widgets/` dan diekspos melalui `lib/shared/widgets/ui.dart`, **bukan** menaruh kode mentah secara ad-hoc atau berulang (misal mendefinisikan `_buildTextField` atau raw `ElevatedButton` di setiap file).
* **Single Entry Point**: Halaman fitur diwajibkan mengimpor seluruh komponen custom melalui satu pintu:
  ```dart
  import 'package:mapotech/shared/widgets/ui.dart';
  ```

---

### B. Katalog Komponen Custom UI Standar MAPOTECH
Setiap elemen tampilan wajib menggunakan padanan komponen kustom berikut:

| Kebutuhan UI | Komponen Kustom Wajib | File Sumber (`lib/shared/widgets/`) | Keterangan / Pengganti |
| :--- | :--- | :--- | :--- |
| **Tombol Aksi** | `CustomButton` | `custom_button.dart` | Pengganti `ElevatedButton`, `TextButton`, `OutlinedButton`. Mendukung gradient, secondary, icon, hover & scale animation. |
| **Wadah / Kartu Konten** | `CustomCard` | `custom_card.dart` | Pengganti raw `Card` / `Container`. Dilengkapi hover elevation, glassmorphism, dan border seragam. |
| **Input Teks / Formulir** | `CustomTextField` | `custom_text_field.dart` | Pengganti `TextField` / `TextFormField`. Tersedia varian `.pill()`, `.multiline()`, toggle sandi otomatis, dan styling REV mode. |
| **Dropdown Pilihan** | `CustomDropdown<T>` | `custom_dropdown.dart` | Pengganti `DropdownButton` / `DropdownButtonFormField`. Styling border, padding, dan font serasi dengan `CustomTextField`. |
| **Dialog / Pop-up Modal** | `CustomDialog` / `CustomConfirmDialog` | `custom_dialog.dart` | Pengganti raw `AlertDialog`. Animasi scale-in, header berikon, tombol terintegrasi `CustomButton`. |
| **Pemilih Tanggal** | `CustomDateField` | `custom_date_field.dart` | Format tanggal Indonesia, terintegrasi picker kalender modern bertema faskes. |
| **Notifikasi / Toast** | `CustomSnackbar` | `custom_snackbar.dart` | Pengganti raw `ScaffoldMessenger`. Tersedia `.success()`, `.error()`, `.warning()`, `.info()`. |
| **Pencarian** | `CustomSearchBar` | `custom_search_bar.dart` | Input pencarian responsif dengan tombol clear otomatis dan ikon search. |
| **Filter Kategori** | `CustomFilterChip` | `custom_filter_chip.dart` | Filter chip interaktif untuk status, jenis faskes, atau kategori obat. |
| **Indikator Status** | `StatusBadge` | `status_badge.dart` | Badge pill untuk status antrian, pesanan obat, status rujukan (varian: `filled`, `subtle`, `outline`). |
| **Chip Entitas** | `EntityChip` | `entity_chip.dart` | Tag visual untuk nama dokter, klinik, apotek, atau poli. |
| **Kartu Metrik / KPI** | `MetricCard` | `metric_card.dart` | Kartu ringkasan angka statistik dashboard faskes. |
| **Placeholder Kosong** | `EmptyStateWidget` | `empty_state_widget.dart` | Tampilan saat data kosong / belum ada antrian/obat dengan tombol aksi. |
| **Indikator Loading** | `SkeletonLoading` / `MapotechLoadingScreen` | `skeleton_loading.dart`, `mapotech_loading_screen.dart` | Animasi shimmer skeleton loading untuk tabel, list, dan kartu saat fetching. |
| **Peta Batas Wilayah** | `RevGeoWilayahMapWidget` | `revgeo_wilayah_map_widget.dart` | Peta poligon wilayah administrasi via API RevGeo resmi. |
| **Pemilih Wilayah** | `LocationSelectorWidget` | `location_selector_widget.dart` | Dropdown bertingkat Provinsi / Kabupaten / Kecamatan / Desa terhubung API RevGeo. |
| **Paginasi Tabel** | `CommonPagination` | `common_pagination.dart` | Kontrol halaman data tabel (prev, next, info page). |
| **Peralihan Antar Portal** | `AnimatedPortalSwitcher` | `animated_portal_switcher.dart` | Transisi animasi halus saat beralih antar portal faskes. |

---

### C. Daftar Master Library Eksternal Seluruh Proyek MAPOTECH
Sesuai aturan pencatatan dependensi, berikut adalah seluruh library/package pihak ketiga yang resmi terpasang di `pubspec.yaml` beserta peruntukan dan folder implementasinya:

| No | Nama Package | Versi | Peruntukan & Alasan Digunakan | Modul / Folder Terkait |
| :---: | :--- | :--- | :--- | :--- |
| 1 | **`supabase_flutter`** | `^2.8.4` | Backend-as-a-Service utama untuk otentikasi multi-role, database PostgreSQL, dan listener Realtime. | `lib/shared/`, seluruh fitur |
| 2 | **`google_fonts`** | `^6.2.0` | Font tipografi modern standar (`Outfit` dan `Inter`) untuk UI yang seragam dan elegan. | `lib/shared/widgets/`, `lib/features/` |
| 3 | **`flutter_animate`** | `^4.5.2` | Animasi mikro dinamis (fade, slide, bounce, scale) pada komponen UI dan halaman. | `lib/shared/widgets/`, `lib/features/landing/` |
| 4 | **`flutter_riverpod`** | `^2.5.1` | State management reaktif untuk sesi AI chat, preferensi tema, dan state aplikasi. | `lib/features/pasien/`, `lib/main.dart` |
| 5 | **`flutter_map`** | `^6.1.0` | Engine peta interaktif open-source berbasis tile OpenStreetMap tanpa biaya langganan API berbayar. | `lib/shared/widgets/`, `lib/features/dokter/`, `lib/features/puskesmas/` |
| 6 | **`latlong2`** | `^0.9.1` | Kalkulasi koordinat geospasial, poligon batas wilayah, dan perhitungan jarak antar faskes. | `lib/shared/`, `lib/shared/widgets/` |
| 7 | **`http`** | `^1.6.0` | REST API client untuk integrasi data batas wilayah **RevGeo API** dan sinkronisasi SatuSehat. | `lib/shared/`, `lib/shared/widgets/` |
| 8 | **`google_generative_ai`**| `^0.4.7` | Integrasi kecerdasan buatan Gemini AI untuk fitur asisten kesehatan dan triage pasien mandiri. | `lib/features/pasien/dashboard/frontend/ai_assistant/` |
| 9 | **`geolocator`** | `^11.0.0` | Akses sensor GPS perangkat untuk mendeteksi posisi pasien saat mencari faskes terdekat. | `lib/shared/location_service.dart`, `lib/features/pasien/` |
| 10 | **`qr_flutter`** | `^4.1.0` | Pembuatan QR Code digital untuk tiket antrian faskes, kode pengambilan resep, dan login faskes. | `lib/shared/widgets/`, `lib/features/pasien/`, `lib/features/apotek/` |
| 11 | **`bcrypt`** | `^1.2.0` | Hashing kata sandi satu arah untuk keamanan akun dan proteksi data kredensial staf faskes. | `lib/shared/supabase_service.dart` |
| 12 | **`crypto`** | `^3.0.3` | Hashing SHA-256 dan enkripsi HMAC untuk integrasi standar keamanan SatuSehat Kemenkes dan BPJS. | `lib/shared/satusehat_service.dart`, `lib/shared/supabase_service.dart` |
| 13 | **`url_launcher`** | `^6.3.0` | Membuka tautan eksternal, WhatsApp kasir/pemesan obat, dan panggilan telepon faskes darurat. | `lib/features/apotek/`, `lib/features/dokter/` |
| 14 | **`file_picker`** | `^8.1.7` | Memilih file/dokumen (PDF izin SIP/SIA, foto profil, bukti transfer, berkas lab). | `lib/features/apotek/`, `lib/features/dokter/`, `lib/features/puskesmas/` |
| 15 | **`image`** | `^4.9.1` | Pemrosesan, resize, dan kompresi gambar di sisi klien sebelum diunggah ke storage. | `lib/features/apotek/` |
| 16 | **`flutter_dotenv`** | `^5.2.1` | Pengelolaan variabel lingkungan yang aman (`env`) untuk URL Supabase dan API keys. | `lib/main.dart`, `lib/shared/` |
| 17 | **`uuid`** | `^4.5.3` | Pembuatan identifier unik (UUID v4) untuk ID transaksi, pesan chat, dan batch queue. | `lib/shared/supabase_service.dart` |
| 18 | **`cupertino_icons`** | `^1.0.8` | Paket ikon pelengkap iOS/Cupertino untuk kebutuhan antarmuka spesifik. | `lib/shared/` |

---

### D. Kewajiban Dokumentasi Folder (README.md per Modul)
Setiap folder modul yang memanfaatkan library eksternal **WAJIB** memiliki file `README.md` lokal di dalam foldernya yang mencantumkan:
1. Daftar package yang digunakan di folder tersebut beserta versinya.
2. Alasan mengapa library tersebut dibutuhkan.
3. Contoh singkat implementasi atau pemanggilan fungsi.
*(File dokumentasi yang telah disediakan: `lib/shared/widgets/README.md`, `lib/shared/README.md`, dan `lib/features/README.md`)*.

---

## 2. Peta & Batas Wilayah Administrasi (Maps & RevGeo API)
* **Custom Map**: Untuk semua visualisasi peta, gunakan implementasi custom map yang telah disesuaikan dengan arsitektur proyek.
* **Data Batas Wilayah (Boundary Polygon)**: Jika fitur membutuhkan informasi batas wilayah administratif (Kecamatan, Kelurahan, Desa, Kabupaten, Provinsi):
  * **WAJIB** menggunakan API **REVGEO**:
    * URL API: **[https://revgeo.relvastudio.com/](https://revgeo.relvastudio.com/)**
  * Gunakan dan kembangkan integrasi yang ada (seperti pada `GeoBoundaryService` dan `RevGeoWilayahMapWidget`).

---

## 3. Palet Warna & Tampilan Tema REV Mode (`revmode`)
Secara default, tema **REV Mode** (`appearance == 'rev'`) **HANYA** boleh menggunakan kombinasi warna berikut:
1. **White** (Putih)
2. **Pink**
3. **Soft Pink** (Pink Lembut)
4. **Purple** (Ungu)
5. **Soft Purple** (Ungu Lembut)
6. **Soft Blue** (Biru Lembut)
7. **Blue** (Biru)
8. **Soft Yellow** (Kuning Lembut)
9. **Black** (Hitam) — khusus digunakan jika diperlukan untuk kontras teks agar mudah dibaca.

* **Pengaturan Warna (Settings)**:
  * Pada menu pengaturan (Settings), pengguna dapat mengubah atau menyesuaikan warna Rev Mode untuk memastikan kontras yang jelas dan nyaman antara teks dengan latar belakang.

---

## 4. Konfirmasi Menu Baru: DLC vs Fitur Bawaan (Wajib Tanya Terlebih Dahulu)
* Apabila ada permintaan penambahan menu baru dan **user tidak secara spesifik menyebutkan** apakah menu tersebut adalah fitur bawaan atau DLC:
  * **AI WAJIB BERTANYA KEPADA USER TERLEBIH DAHULU SEBELUM MEMBUAT KODE.**
  * Pertanyaan yang wajib diajukan:
    1. *Apakah menu ini merupakan fitur bawaan (core) aplikasi?*
    2. *Atau menu ini merupakan bagian dari sistem DLC (Downloadable Content / Add-on)?*
    3. *Jika DLC, untuk role/siapa DLC tersebut, apakah paket DLC baru, atau ekstensi dari DLC yang sudah ada?*
* Dilarang membuat asumsi sendiri tanpa konfirmasi dari user.

---

## 5. Sistem Modul DLC (Terkunci & File Mandiri)
* **Status Terkunci (Locked by Default)**:
  * Sistem DLC harus dalam kondisi **TERKUNCI** selama user / instansi belum melakukan ekspansi atau belum membeli modul DLC tersebut.
  * Jika user belum memiliki akses ke DLC tersebut, antarmuka harus menampilkan indikator terkunci atau dialog info/pembelian (tidak boleh langsung membuka fitur tanpa validasi pembelian/izin).
* **File Terpisah untuk Menu DLC**:
  * Seluruh file menu dan halaman fitur DLC **harus dibuat mandiri di file tersendiri** (terisolasi/modular), tidak digabung atau dicampur aduk dengan kode menu bawaan aplikasi.

---

## 6. Konsistensi Styling UI Antar Halaman (Uniformity)
* **Gaya Visual Seragam**: Styling UI harus konsisten di seluruh halaman aplikasi (*cross-page consistency*):
  * Radius sudut kartu (*border radius*), elevasi, bayangan (*box shadow*), dan tata letak *padding/margin*.
  * Tipografi, ukuran font, hierarki heading, dan warna teks.
  * Bentuk dan interaksi tombol (`CustomButton`), input teks (`CustomTextField`), dropdown (`CustomDropdown`), *search bar* (`CustomSearchBar`), *chip filter* (`CustomFilterChip`), dan modal dialog (`CustomDialog` / `CustomConfirmDialog`).
* Hindari mendesain halaman dengan gaya yang berbeda jauh dari halaman-halaman yang sudah ada di proyek.

---

## 7. Standar Internasionalisasi & Lokalisasi Bahasa (Multi-Language / L10n Standard)
* **Wajib Mendukung 2 Bahasa (Bilingual)**: Seluruh teks antarmuka (label menu, judul kartu, tombol aksi, tooltip, placeholder input pencarian, dialog modal/konfirmasi, status badge, dan opsi filter) **WAJIB** mendukung 2 bahasa:
  1. **Bahasa Indonesia (`'id'`)**
  2. **Bahasa Inggris (`'en'`)**
  * Dilarang keras melakukan hardcode teks hanya dalam satu bahasa saja di halaman mana pun.
* **Single Source of Truth**: Bahasa aplikasi dikontrol penuh oleh preferensi bahasa pengguna (`state.language` atau `appLanguageProvider` dari Riverpod `landingPageProvider`).
* **Zero-Lag & Kerapian Kode**:
  * Untuk mencegah *over-rebuilding* dan memastikan transisi pergantian bahasa berlangsung cepat serta **TIDAK NGELAG**, gunakan Riverpod selector:
    ```dart
    final isEn = ref.watch(isEnglishProvider); // Reaktif, ultra-cepat, 0-lag
    // atau
    final lang = ref.watch(appLanguageProvider);
    ```
  * Seluruh komponen lokalisasi diekspos melalui `lib/shared/widgets/ui.dart` (`AppTranslations`, `isEnglishProvider`, `appLanguageProvider`, serta extension `ref.tr(...)`).
* **Panduan AI Assistant & Developer Saat Menambah Menu / Fitur / UI Baru ("Jangan Panik")**:
  1. **Teks Dinamis / Inline**: Gunakan `ref.tr(id: '...', en: '...')` atau `isEn ? '...' : '...'`:
     ```dart
     CustomButton(
       text: ref.tr(id: 'Simpan Rekam Medis', en: 'Save Medical Record'),
       onPressed: () => _handleSave(),
     )
     ```
  2. **Format Tanggal Otomatis**: Dilarang membuat array nama hari/bulan manual di dalam file UI. Wajib menggunakan `AppTranslations.formatDate(...)`:
     ```dart
     final dateStr = AppTranslations.formatDate(DateTime.now(), lang: state.language);
     // ID: "Selasa, 26 Mei 2026"
     // EN: "Tuesday, 26 May 2026"
     ```
  3. **Konsistensi Lintas Tab**: Seluruh tab (Pasien, Dokter, Apotek, Puskesmas, Ponkesdes, dan seluruh DLC) harus merespons pilihan bahasa pengguna di Settings secara seragam.

