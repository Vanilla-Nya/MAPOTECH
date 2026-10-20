# ATURAN & STANDAR PENGEMBANGAN MAPOTECH (RULE.MD)

Dokumen ini adalah pedoman wajib bagi AI Assistant dan Developer sebelum melakukan penambahan kode, modifikasi, pembuatan menu, atau perancangan UI di dalam proyek **MAPOTECH**. Wajib dibaca dan dipatuhi setiap saat.

---

## 1. Pembuatan Komponen UI Mandiri (Custom UI & List Library)
* **Custom UI File**: Semua elemen antarmuka (UI) dalam proyek ini harus dibuat menggunakan file kustom di dalam proyek (misalnya diletakkan pada folder `lib/shared/widgets/` atau folder modul terkait).
* **Bikin Komponen Kustom Dulu**: Jika komponen UI yang dibutuhkan belum tersedia, **wajib membuat file komponen kustomnya terlebih dahulu**, bukan menaruh kode mentah secara ad-hoc atau berulang di setiap halaman.
* **Pencatatan Library Eksternal**: Jika sebuah modul atau komponen memerlukan library/package pihak ketiga:
  * Penggunaan library diperbolehkan.
  * **Wajib mencatat daftar library** yang digunakan pada folder terkait (buat file dokumentasi/list daftar library atau README di dalam folder tersebut) agar dependensi selalu terdata dengan rapi dan transparan.

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
  * Bentuk dan interaksi tombol, input teks (*text field*), *search bar*, *chip filter*, dan modal dialog.
* Hindari mendesain halaman dengan gaya yang berbeda jauh dari halaman-halaman yang sudah ada di proyek.
