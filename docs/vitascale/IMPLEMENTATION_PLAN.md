# VitaScale by MAPOTECH — Implementation Plan (Milestone 0)

> Status: **AUDIT SELESAI, MENUNGGU KONFIRMASI KEPUTUSAN** (lihat §7).
> Dokumen ini dibuat dari pemeriksaan read-only repository `c:\Project\mapotech` pada 2026-10-22.
> Tidak ada kode, migration, atau deploy yang dilakukan pada tahap ini.

---

## 1. Arsitektur existing MAPOTECH yang relevan

| Aspek | Temuan (terverifikasi dari kode) |
| :--- | :--- |
| Framework | **Flutter** (Dart SDK `^3.11.0`), target utama **Flutter Web** (`flutter run -d web-server`). Bukan React/Next/Vite. |
| Package manager | `pub` + `pubspec.lock`. Tidak ada `package.json`/npm. |
| State management | `flutter_riverpod` — `landingPageProvider` (`lib/features/landing/landing_page_data.dart`) memegang sesi login, role, bahasa, tema, favorit menu. |
| Routing | **Tidak memakai router URL.** Navigasi = `String _activeMenu` di `DashboardShell` (`lib/features/dashboard/dashboard_shell.dart`) → `switch` per role di `_buildRoleDashboardBody()`. |
| Navigasi / menu | `lib/features/dashboard/widgets/dashboard_drawer.dart`: `getMenuItemsForRole()` (sidebar) + `FullScreenDrawerOverlay` (grid cluster). DLC Puskesmas = `allDlcItems` dengan sub-kategori `kia_dlc`, `pelayanan_dlc`, `sistem_dlc` ("Integrasi Sistem & SatuSehat"). |
| Izin pekerja | `kPuskesmasPermissionDict` di `lib/features/pekerja/dashboard/frontend/management_pekerja.dart` (string permission per menu, termasuk `SATUSEHAT PRO`, `BPJS PCARE BRIDGING` di `sistem_dlc`). |
| Auth | Supabase (`supabase_flutter`) + tabel `public.user` (kolom `role`), login custom via `SupabaseService` (`lib/shared/supabase_service.dart`, bcrypt). |
| Backend | Supabase project ref `abdburxhqqwsobmzuwmz` (dari `env`, nilai secret tidak dibaca). Schema yang dipakai kode: `public`, `private_doctor`, `pharmacy`. |
| Edge Functions | Hanya dirujuk lewat env (`DUITKU_CALLBACK_URL` → `functions/v1/duitku-callback`). **Source Edge Function & migration tidak ada di repository.** |
| Data pasien | `public.user` (`id, name, nik, gender, birth_date, phone_number`, role `pasien`). Anak tanpa akun → `public.patient_family_members` (`patient_id, member_user_id, nama, nik, hubungan, usia, gender, ...`). Nilai `gender` tidak konsisten (`male` / `Laki-laki`). |
| Kunjungan / pemeriksaan | `private_doctor.clinical_encounters`, `private_doctor.vital_signs` (FK `id_clinical_ecounter`), `v_queues`. Dipakai portal **dokter**; portal **puskesmas** belum memakai tabel ini. |
| Halaman DLC Puskesmas existing | `puskesmas_pantauan_ibu_hamil.dart`, `puskesmas_form_ibu_hamil.dart` — **100% data dummy in-memory**, tidak ada query Supabase. |
| Kamera web | Sudah ada pola `getUserMedia` + `HtmlElementView` + enumerasi perangkat + stop track di `lib/features/apotek/dashboard/frontend/widgets/web_qr_scanner_web.dart` (pakai `dart:html`/`js_util`). |
| JS di web | `web/index.html` memuat `bundle.js` lokal & `jsQR` dari CDN; helper global `window.decodeQrFromVideo`. |
| Design system | `lib/shared/widgets/ui.dart` (CustomButton, CustomCard, CustomDialog, CustomSnackbar, StatusBadge, MetricCard, EmptyStateWidget, SkeletonLoading, dll.). Font Outfit/Inter. Tema `light`/`dark`/`rev` via `landingPageProvider.notifier.getPrimaryColor()` dsb. |
| Testing | Hanya `test/widget_test.dart` (template). `analysis_options.yaml` + `flutter_lints`. Tidak ada CI config di repo. |
| CV / antropometri | **Tidak ada** OpenCV, marker detection, prototype Python, Z-score WHO/Kemenkes, atau tabel antropometri. Kata "stunting/Z-Score" hanya muncul sebagai teks dialog DLC. |

## 2. Komponen yang dapat digunakan kembali

- `DashboardShell` switch-case + `FullScreenDrawerOverlay.allDlcItems` → titik integrasi menu DLC.
- `kPuskesmasPermissionDict` → permission pekerja untuk menu VitaScale.
- `web_qr_scanner_web.dart` → pola akses kamera (dipindah ke modul VitaScale sebagai file mandiri, tidak mengubah scanner apotek).
- `SupabaseService.searchPatients()` + `fetchFamilyMembers()` → sumber usia & jenis kelamin anak (tanpa input ganda).
- `ui.dart` (CustomCard, CustomButton, StatusBadge, CustomDialog, CustomSnackbar, EmptyStateWidget).

## 3. Integrasi yang BELUM tersedia

1. Mekanisme **DLC terkunci** sungguhan (entitlement per instansi). Saat ini tombol "Aktifkan DLC" hanya menampilkan snackbar.
2. Model **sesi skrining** / kunjungan untuk portal Puskesmas.
3. **Device registry, pairing code, device token, endpoint sensor** (tabel + Edge Function).
4. **Service WHO/Kemenkes** (Z-score BB/U, PB-TB/U, BB/PB-TB, IMT/U).
5. OpenCV.js di build.
6. Firmware ESP32 (tidak ada di repo).

## 4. File yang akan dibuat / diubah

### Dibuat (modul DLC mandiri — Rule §5)
```
lib/features/puskesmas/dlc/vitascale/
├── README.md                              # daftar library + contoh (Rule §1D)
├── vitascale_dlc_gate.dart                # gate DLC terkunci
├── data/
│   ├── vitascale_models.dart              # ChildProfile, ScreeningSession, Measurement, enums
│   ├── vitascale_repository.dart          # interface + impl Supabase + impl Simulasi
│   └── vitascale_device_simulator.dart    # mock ESP32 (berlabel SIMULASI)
├── logic/
│   ├── screening_state_machine.dart       # state sesi & per-pengukuran
│   ├── anthropometry_mode.dart            # <24 bln telentang / ≥24 bln berdiri + override
│   └── whtr.dart                          # rasio lingkar perut / tinggi (indikator tambahan)
├── cv/
│   ├── vitascale_camera_web.dart          # getUserMedia, pilih kamera, capture, release
│   ├── vitascale_camera_stub.dart         # non-web
│   └── marker_measurement.dart            # bridge ke JS OpenCV
├── widgets/                               # komponen panel (berbasis ui.dart)
└── pages/
    ├── vitascale_data_anak_page.dart      # menu "Data Anak/Bayi"
    └── vitascale_screening_page.dart      # menu "Screening Anak/Bayi"
web/vitascale/
├── vitascale_cv.js                        # marker detection + homografi (OpenCV.js)
└── opencv.js                              # vendored (dikelola repo, bukan CDN)
supabase/
├── migrations/<ts>_vitascale_init.sql     # DRAFT — tidak dijalankan tanpa izin
└── functions/vitascale-device/index.ts    # pairing + heartbeat + ingest (DRAFT)
firmware/vitascale-esp32/                  # sketsa referensi provisioning + kontrak API
docs/vitascale/                            # ARCHITECTURE, API_CONTRACT, SECURITY, TESTING
test/vitascale/                            # unit test state machine, mode, WHtR, validator
```

### Diubah (minimal)
- `dashboard_drawer.dart` — ganti sub-kategori `sistem_dlc` → VitaScale + 2 kartu menu.
- `dashboard_shell.dart` — 2 `case` route baru.
- `management_pekerja.dart` — 2 entri permission baru.
- `landing_page_data.dart` — id menu di `favoriteMenuItems` default.
- `web/index.html` — `<script>` OpenCV.js lokal (lazy).

## 5. Dampak database & keamanan

Draft migration minimal (schema baru `vitascale`, tidak menyentuh tabel lain):

| Tabel | Fungsi |
| :--- | :--- |
| `vitascale.devices` | identitas perangkat, `facility_id`, `token_hash` (bukan plaintext), `status`, `last_seen_at`, `firmware_version`, `revoked_at` |
| `vitascale.pairing_codes` | kode sekali pakai (hash), `expires_at` pendek, `used_at`, `facility_id` |
| `vitascale.screening_sessions` | `facility_id`, `patient_user_id` / `family_member_id`, `device_id`, `mode` (telentang/berdiri), `status` (open/closed/finalized), `is_demo` |
| `vitascale.measurement_events` | `session_id`, `device_id`, `type`, `value`, `unit`, `quality`, `captured_at`, `idempotency_key` **UNIQUE** |
| `vitascale.screening_results` | hasil final terverifikasi + `verified_by` + audit |

- ESP32 **tidak** menulis tabel langsung → hanya Edge Function `vitascale-device` (service role di server) yang memvalidasi token perangkat, sesi, unit, rentang nilai, idempotency.
- RLS: baca/tulis dibatasi `facility_id` = puskesmas login.
- Tidak ada password Wi-Fi di DB; tidak ada service-role key di firmware/frontend.
- Gambar kamera diproses di browser dan **tidak diunggah**.

> [!WARNING]
> Temuan keamanan existing (di luar scope, tidak diubah): file `env` dibundel sebagai asset Flutter (`pubspec.yaml` → `assets: - env`), sehingga `RESEND_API_KEY`, `DUITKU_MERCHANT_KEY`, `GEMINI_API_KEY` ikut terkirim ke browser. Disarankan dipindah ke Edge Function.

## 6. Urutan implementasi & kriteria keberhasilan

| Milestone | Isi | Kriteria |
| :--- | :--- | :--- |
| M1 UI & sesi | Menu DLC VitaScale, gate terkunci, halaman Data Anak/Bayi & Screening, state machine, simulator berlabel | `flutter analyze` bersih untuk file baru, unit test state machine lulus, data simulasi tidak bisa disimpan sebagai hasil klinis |
| M2 Webcam & CV | getUserMedia, pilih kamera, capture, OpenCV.js marker → cm, release stream | Capture gagal bila marker tidak valid; tidak ada klaim akurasi |
| M3 Device & API | Draft migration + Edge Function | Review manual; dijalankan hanya setelah izin |
| M4 Pairing | Halaman kelola perangkat, kode sekali pakai, revoke | Kode kedaluwarsa/terpakai ditolak (test function) |
| M5 Simpan hasil | Verifikasi petugas → final + audit | Duplikat ditolak via idempotency |
| M6 Test & docs | Semua test, dokumentasi, panduan hardware | Laporan jujur termasuk yang belum diuji fisik |

## 7. Risiko & keputusan yang membutuhkan konfirmasi

1. **Akses Supabase MAPOTECH** — project `abdburxhqqwsobmzuwmz` tidak terlihat oleh MCP Supabase yang tersedia (hanya `katalog_kasno`, `REVHELIX`). Schema, RLS, dan Edge Function asli **tidak dapat diverifikasi**. Tanpa akses, M3–M5 hanya bisa berupa draft file yang belum diuji.
2. **Nasib kartu "Modul DLC SatuSehat Pro" & "BPJS P-Care Bridging"** setelah sub-kategori diganti VitaScale.
3. **Mekanisme DLC terkunci** — belum ada sumber entitlement di DB.
4. **Vendoring `opencv.js`** (~8–10 MB) ke `web/vitascale/` — menambah ukuran bundle web.
5. **Puskesmas belum punya model kunjungan** — sesi skrining VitaScale akan menjadi entitas sendiri (`vitascale.screening_sessions`), bukan `private_doctor.clinical_encounters`.
6. **Z-score WHO/Kemenkes** tidak tersedia → ditampilkan "Belum tersedia — menunggu validasi referensi resmi". Tidak ada rumus/kategori karangan.
7. Akurasi sensor (HX711, AS5600) & mekanik papan ukur **belum divalidasi fisik**.
