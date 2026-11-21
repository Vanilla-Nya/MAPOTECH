# Komponen Custom UI MAPOTECH (`lib/shared/widgets/`)

Folder ini berisi seluruh pustaka komponen antarmuka mandiri (*custom reusable UI components*) untuk proyek MAPOTECH. Seluruh tampilan halaman diwajibkan menggunakan komponen dari folder ini untuk menjaga konsistensi gaya visual, responsivitas, dan kepatuhan terhadap aturan tema **REV Mode** (sesuai `Rule.md`).

---

## 📦 Daftar Library Eksternal yang Digunakan di Modul Widgets

Sesuai **Rule 1 (Pencatatan Library Eksternal)** pada `Rule.md`, berikut adalah paket pihak ketiga yang digunakan di dalam folder ini:

| Nama Package | Versi (pubspec) | Penggunaan & Alasan Kebutuhan | File Terkait |
| :--- | :--- | :--- | :--- |
| **`google_fonts`** | `^6.2.0` | Tipografi modern seragam (`Outfit` / `Inter`) untuk judul, label input, badge, dan teks tombol. | `custom_button.dart`, `custom_search_bar.dart`, `custom_text_field.dart`, `custom_dropdown.dart`, `status_badge.dart`, `custom_dialog.dart`, `custom_snackbar.dart`, `custom_date_field.dart` |
| **`flutter_animate`** | `^4.5.2` | Animasi mikro interaktif, efek transisi transparan, dan bounce feedback pada kartu dan dialog. | `portal_widgets.dart`, `segera_hadir_mockup.dart`, `mapotech_loading_screen.dart` |
| **`flutter_map`** | `^6.1.0` | Komponen visualisasi peta interaktif open-source berbasis tile OpenStreetMap tanpa vendor lock-in. | `revgeo_wilayah_map_widget.dart` |
| **`latlong2`** | `^0.9.1` | Komputasi koordinat lintang & bujur (Latitude/Longitude), polygon batas, dan jarak antar faskes. | `revgeo_wilayah_map_widget.dart` |
| **`qr_flutter`** | `^4.1.0` | Generator QR Code berbasis widget untuk tiket antrian, resep obat digital, dan token faskes. | `auth_modals.dart`, `portal_widgets.dart` |
| **`http`** | `^1.6.0` | Pengambilan data GeoJSON polygon batas wilayah dari RevGeo API (`https://revgeo.relvastudio.com/`). | `revgeo_wilayah_map_widget.dart`, `location_selector_widget.dart` |

---

## 🎨 Katalog Komponen Custom UI

Untuk mengimpor seluruh komponen sekaligus, cukup gunakan:
```dart
import 'package:mapotech/shared/widgets/ui.dart';
```

### 1. `CustomButton`
* **File**: `custom_button.dart`
* **Fungsi**: Tombol interaktif seragam dengan efek hover, klik berskala (animated scale), dukungan gradient, primary, dan secondary outline.
* **Contoh**:
```dart
CustomButton(
  text: 'Simpan Pasien',
  icon: Icons.save_rounded,
  onPressed: () => _simpan(),
)
```

### 2. `CustomCard`
* **File**: `custom_card.dart`
* **Fungsi**: Wadah kartu dengan efek hover elevasi dinamis, glassmorphic option, dan sudut membulat modern.
* **Contoh**:
```dart
CustomCard(
  borderRadius: 18,
  padding: const EdgeInsets.all(20),
  child: Column(...),
)
```

### 3. `CustomTextField`
* **File**: `custom_text_field.dart`
* **Fungsi**: Input teks terstandarisasi menggantikan raw `TextField` / `TextFormField`. Mendukung single-line, multiline/catatan, pill search, toggle sandi otomatis, validasi error, dan adaptasi REV mode.
* **Contoh**:
```dart
CustomTextField(
  label: 'Nama Lengkap Pasien',
  hintText: 'Masukkan nama pasien',
  prefixIcon: Icons.person_outline,
  controller: _namaController,
)

// Versi Password:
CustomTextField(
  label: 'Kata Sandi',
  isPassword: true,
  controller: _passwordController,
)

// Versi Multiline (Catatan):
CustomTextField.multiline(
  label: 'Catatan Dokter',
  controller: _catatanController,
)
```

### 4. `CustomDropdown<T>`
* **File**: `custom_dropdown.dart`
* **Fungsi**: Dropdown pilihan seragam dengan styling identik dengan `CustomTextField`.
* **Contoh**:
```dart
CustomDropdown<String>(
  label: 'Golongan Darah',
  value: _selectedGolDarah,
  items: [
    CustomDropdownItem(value: 'A', label: 'Golongan Darah A'),
    CustomDropdownItem(value: 'B', label: 'Golongan Darah B'),
    CustomDropdownItem(value: 'O', label: 'Golongan Darah O'),
    CustomDropdownItem(value: 'AB', label: 'Golongan Darah AB'),
  ],
  onChanged: (val) => setState(() => _selectedGolDarah = val),
)
```

### 5. `CustomDialog` & `CustomConfirmDialog`
* **File**: `custom_dialog.dart`
* **Fungsi**: Dialog modal seragam menggantikan raw `AlertDialog` dengan animasi scale-in, header berikon, tombol aksi terintegrasi `CustomButton`.
* **Contoh**:
```dart
// Konfirmasi Hapus / Tindakan Bahaya
final confirmed = await CustomConfirmDialog.show(
  context: context,
  title: 'Hapus Antrian?',
  message: 'Pasien yang dihapus akan keluar dari daftar antrian aktif.',
  confirmText: 'Ya, Hapus',
  isDanger: true,
);

// Dialog Konten Bebas
CustomDialog.show(
  context: context,
  title: 'Detail Resep',
  icon: Icons.medication_liquid_rounded,
  content: MyResepDetailWidget(),
);
```

### 6. `CustomDateField`
* **File**: `custom_date_field.dart`
* **Fungsi**: Input pemilih tanggal terstandarisasi dengan format tanggal Indonesia dan picker terintegrasi.
* **Contoh**:
```dart
CustomDateField(
  label: 'Tanggal Lahir',
  selectedDate: _tanggalLahir,
  onDateSelected: (date) => setState(() => _tanggalLahir = date),
)
```

### 7. `CustomSnackbar`
* **File**: `custom_snackbar.dart`
* **Fungsi**: Notifikasi toast mengambang terstandarisasi menggantikan raw `ScaffoldMessenger`.
* **Contoh**:
```dart
CustomSnackbar.success(context, 'Data resep berhasil disimpan!');
CustomSnackbar.error(context, 'Gagal menghubungkan ke server.');
CustomSnackbar.warning(context, 'Stok obat tersisa 3 butir.');
```

### 8. `CustomSearchBar` & `CustomFilterChip`
* **File**: `custom_search_bar.dart`, `custom_filter_chip.dart`
* **Fungsi**: Bilah pencarian responsif dengan tombol clear otomatis dan chip filter kategori status.

### 9. `StatusBadge` & `EntityChip`
* **File**: `status_badge.dart`, `entity_chip.dart`
* **Fungsi**: Indikator status berwarna adaptif (Aktif, Menunggu, Selesai, Bahaya, dll.) dengan dot atau ikon.

### 10. `MetricCard` & `SkeletonLoading`
* **File**: `metric_card.dart`, `skeleton_loading.dart`
* **Fungsi**: Kartu KPI statistik dashboard dan animasi loading skeleton shimmer seragam.

### 11. `RevGeoWilayahMapWidget` & `LocationSelectorWidget`
* **File**: `revgeo_wilayah_map_widget.dart`, `location_selector_widget.dart`
* **Fungsi**: Visualisasi peta poligon batas administratif via **RevGeo API** (`https://revgeo.relvastudio.com/`) dan pemilih bertingkat Provinsi/Kabupaten/Kecamatan/Desa.
* **Fitur Utama**:
  - **Zero-Lag Lazy Loading**: Dilengkapi `SkeletonMap` dan `CustomProgressBar` animasi 1%–100% bawaan saat pertama kali dibuka sehingga transisi halaman tidak freeze / lag.
  - **Interactive Patient Pin & Callout**: Mendukung `onMarkerTap` yang membuka detail rekam medis / modal data pasien (`PatientAncDetailModal`). Pin pada Desktop memiliki efek hover tooltip rapi dan callout card mengambang interaktif.
  - **Multi-Polygon RevGeo Parsing**: Mengurai poligon batas wilayah resmi (Kecamatan Sumber Wringin, dsb.) secara otomatis dengan `PolygonLayer` dan auto-fit bounds kamera.

### 12. `CustomQrisDialog`
* **File**: `custom_qris_dialog.dart`
* **Fungsi**: Dialog pembayaran QRIS dinamis mandiri untuk paket langganan faskes & pasien dengan tampilan real harga, render QR code otomatis, tautan checkout, dan cek status instan.
* **Contoh**:
```dart
CustomQrisDialog.show(
  context: context,
  orderId: orderId,
  paymentUrl: paymentUrl,
  qrString: qrString,
  amount: 150000,
  packageType: 'subscription_30',
  packageTitle: 'Standard Subscription (30 Hari)',
  userId: userId,
  onPaymentSuccess: () => _applyPackage(),
);
```

### 13. `CustomCollapsibleCard`
* **File**: `custom_collapsible_card.dart`
* **Fungsi**: Wadah kartu lipat interaktif (*collapsible/expandable container*) dengan animasi halus, header berikon, indikator chevron rotasi, dan status awal yang dapat dikonfigurasi (misal tertutup secara default saat halaman dimuat).
* **Contoh**:
```dart
CustomCollapsibleCard(
  title: 'Ringkasan Statistik & Indikator Pasien',
  subtitle: '4 Metrik Utama Sasaran',
  icon: Icons.analytics_rounded,
  initiallyExpanded: false, // Tertutup saat pertama dibuka
  child: GridView.count(...),
)
```

### 14. `CustomFormStepper`
* **File**: `custom_form_stepper.dart`
* **Fungsi**: Indikator langkah (*step-by-step navigation stepper*) horizontal interaktif untuk form panjang yang dibagi menjadi kartu terpisah. Dilengkapi nomor/ikon langkah, indikator validasi (merah jika ada isian wajib kurang, kuning jika opsional kurang, hijau jika selesai), garis penghubung, serta adaptasi layar kompak (horizontal scroll) untuk mobile.
* **Contoh**:
```dart
CustomFormStepper(
  steps: [
    FormStepItem(step: 1, label: 'Identitas', isCompleted: true),
    FormStepItem(step: 2, label: 'Antropometri', hasError: true),
    FormStepItem(step: 3, label: 'Janin & DJJ'),
  ],
  currentStep: _formStep,
  onStepTapped: (step) => setState(() => _formStep = step),
  themeAccent: themeAccent,
  textColor: textColor,
  subtitleColor: subtitleColor,
  borderColor: borderColor,
  cardBgColor: cardBgColor,
  isDark: isDark,
)
```

### 15. `FormattedMarkdownText`
* **File**: `formatted_markdown_text.dart`
* **Fungsi**: Komponen parser dan penampil teks markdown (bold `**...**`, italic `*...*`, numbered & bullet lists, headings `#`, inline code) yang dihasilkan dari model AI/LLM (Gemini, MAPOTECH AI, VitaScale Clinical Reasoning) agar tidak menyisakan tanda bintang atau karakter mentah (`**`) di layar. Mendukung typewriter streaming tanpa bocor karakter mentah di akhir string.
* **Contoh**:
```dart
FormattedMarkdownText(
  text: message.text,
  style: GoogleFonts.outfit(fontSize: 14, color: textColor),
  accentColor: primaryColor,
)
```

### 16. `CustomLazyLoader` & `CustomPageLoader`
* **File**: `custom_lazy_loader.dart`
* **Fungsi**: Komponen lazy loading wajib untuk menggantikan raw `CircularProgressIndicator`. Menampilkan progress bar horizontal animasi (1% s/d 100% dari kiri ke kanan), teks persentase dinamis, label proses dwibahasa, serta kerangka `SkeletonLoading`. Ketika loading selesai, loader menghilang perlahan (*fade-out*) dan UI konten baru muncul secara halus (*fade-in* + micro-slide).
* **Contoh**:
```dart
// Pola Wrapper (Rekomendasi Utama):
CustomLazyLoader(
  isLoading: _isLoading,
  loadingText: isEn ? 'Loading health records...' : 'Memuat data rekam medis...',
  skeleton: const SkeletonChildrenList(),
  child: _buildMainContent(),
)

// Pola Standalone (Return Widget Langsung):
if (_isLoading) {
  return CustomPageLoader(
    message: isEn ? 'Loading directory...' : 'Memuat data direktori...',
    skeleton: const SkeletonPatientGrid(),
  );
}
```

### 17. `CustomProgressBar`
* **File**: `custom_lazy_loader.dart`
* **Fungsi**: Indikator progres linier horizontal (1% - 100%) dengan gradien warna tema, badge persentase, track anti-aliased, dan kilau cahaya (*shimmer flare*) animasi kiri-ke-kanan.
* **Contoh**:
```dart
CustomProgressBar(
  value: 0.75, // 75%
  label: 'Sinkronisasi SatuSehat...',
  height: 7.0,
)
```




