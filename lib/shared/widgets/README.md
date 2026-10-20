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
