# Modul Dashboard Puskesmas (`lib/features/puskesmas/dashboard/`)

Folder ini berisi komponen frontend dan service backend khusus portal **Puskesmas** (Cluster 1–3, Lintas Cluster, MomiCare KIA, Profil Puskesmas, serta Pembukuan & Sinkronisasi SATUSEHAT).

---

## 📦 Daftar Library Eksternal yang Digunakan

Sesuai **Rule 1.D (`Rule.md`)**, berikut daftar library eksternal dari `pubspec.yaml` yang digunakan pada modul ini:

| Package | Versi (`pubspec.yaml`) | Peruntukan & Alasan Penggunaan | File Terkait |
| :--- | :---: | :--- | :--- |
| **`flutter_riverpod`** | `^2.5.1` | State management reaktif untuk tema, bahasa (`isEnglishProvider`), profil login Puskesmas, dan daftar pantauan MomiCare (`ibuHamilListProvider`). | `puskesmas_pembukuan.dart`, `puskesmas_dashboard.dart`, `puskesmas_pantauan_ibu_hamil.dart`, `puskesmas_profile.dart` |
| **`google_fonts`** | `^6.2.0` | Tipografi konsisten (`Outfit`) untuk judul, tabel, status badge, dan kartu metrik. | Seluruh file di `frontend/` |
| **`supabase_flutter`** | `^2.8.4` | Kueri dan persistensi database Supabase (`public.user_detail_public_health_center`, skema `community_health_center`, dan log sinkronisasi SATUSEHAT). | `puskesmas_satusehat_bookkeeping_service.dart`, `puskesmas_profile.dart`, `puskesmas_owner_dashboard.dart` |
| **`http`** | `^1.6.0` | Komunikasi REST & OAuth2 dengan API SATUSEHAT Kemenkes (`SatuSehatService`) serta RevGeo API. | `puskesmas_satusehat_bookkeeping_service.dart`, `puskesmas_form_ibu_hamil.dart` |
| **`flutter_dotenv`** | `^5.2.1` | Fallback pembacaan konfigurasi lingkungan (`env`) bila kredensial profil Puskesmas belum terisi. | `puskesmas_satusehat_bookkeeping_service.dart`, `puskesmas_form_ibu_hamil.dart` |
| **`flutter_map` & `latlong2`** | `^6.1.0` / `^0.9.1` | Peta wilayah kerja Puskesmas, titik lokasi pasien berisiko, dan sebaran Pustu/Ponkesdes. | `puskesmas_owner_dashboard.dart`, `puskesmas_pantauan_ibu_hamil.dart`, `management_pustu_ponkesdes.dart` |
| **`url_launcher`** | `^6.3.0` | Membuka WhatsApp atau tautan peta eksternal untuk koordinasi tindak lanjut pasien. | `puskesmas_pantauan_ibu_hamil.dart`, `puskesmas_profile.dart` |
| **`file_picker` & `image`** | `^8.1.7` / `^4.9.1` | Pemilihan dan kompresi gambar profil Puskesmas sebelum diunggah. | `puskesmas_profile.dart` |

---

## 🧩 Contoh Penggunaan Service Pembukuan SATUSEHAT Puskesmas

```dart
final service = PuskesmasSatuSehatBookkeepingService();

// 1. Muat kredensial SATUSEHAT milik Puskesmas
final config = await service.loadConfig(
  facilityId: appState.activePuskesmasId!,
  fallbackFacilityName: 'Puskesmas Sumber Wringin',
);

// 2. Muat daftar kunjungan Puskesmas (MomiCare, VitaScale, dan Poli)
final records = await service.loadEncounters(
  facilityId: config.facilityId,
  facilityName: config.facilityName,
  momicarePatients: ref.read(ibuHamilListProvider),
);

// 3. Sinkronkan kunjungan ke SATUSEHAT FHIR R4
final updated = await service.syncEncounterToSatuSehat(
  record: records.first,
  config: config,
  staffName: 'Bidan / Petugas Puskesmas',
);
```
