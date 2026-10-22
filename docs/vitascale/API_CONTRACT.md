# Kontrak API: VitaScale IoT Device Endpoints

Dokumentasi kontrak endpoint REST API untuk integrasi mikrokontroler ESP32 VitaScale dengan backend MAPOTECH.

Base URL: `https://<PROJECT-REF>.supabase.co/functions/v1/vitascale-device`

---

## 1. POST `/pair` — Registrasi & Pairing Perangkat

Digunakan oleh ESP32 untuk menukar kode pairing 6-digit faskes dengan token otentikasi permanen perangkat.

### Request Headers
```http
Content-Type: application/json
```

### Request Body
```json
{
  "pairing_code": "839201",
  "device_serial": "VTS-A4B2C3D4",
  "firmware_version": "v1.0.0"
}
```

### Response Success (200 OK)
```json
{
  "success": true,
  "message": "Perangkat berhasil terhubung ke faskes MAPOTECH.",
  "device_id": "b182cb44-332d-419b-a010-84cfba9e7428",
  "device_token": "vts_dev_9a7d83f120c94628a881ecbb834199aa",
  "facility_id": "f784aa92-1234-4567-89ab-cdef01234567"
}
```

---

## 2. POST `/heartbeat` — Pelaporan Status Online

ESP32 mengirimkan heartbeat berkala (setiap 60 detik) untuk memantau status online/offline di dashboard petugas.

### Request Headers
```http
Content-Type: application/json
x-device-token: vts_dev_9a7d83f120c94628a881ecbb834199aa
```

### Request Body
```json
{}
```

### Response Success (200 OK)
```json
{
  "status": "online",
  "device_id": "b182cb44-332d-419b-a010-84cfba9e7428",
  "server_time": "2026-10-22T10:30:00Z"
}
```

---

## 3. POST `/measurement` — Pengiriman Hasil Pengukuran Sensor

Mengirimkan hasil pembacaan sensor timbangan (HX711) atau lingkar perut (AS5600) yang sudah stabil.

### Request Headers
```http
Content-Type: application/json
x-device-token: vts_dev_9a7d83f120c94628a881ecbb834199aa
```

### Request Body
```json
{
  "session_id": "VTS-2026-8A3F12CD",
  "measurement_type": "weight",
  "value": 14.85,
  "unit": "kg",
  "quality": "stable",
  "captured_at": "2026-10-22T10:32:15Z",
  "idempotency_key": "VTS-A4B2C3D4-169800000-4821"
}
```

### Response Success (201 Created)
```json
{
  "success": true,
  "event_id": "e4720911-5342-4211-9a11-739ba64e2299",
  "message": "Data pengukuran sensor berhasil dicatat ke sesi."
}
```

### Response Idempotent Duplicate (200 OK)
Bila `idempotency_key` yang sama dikirimkan ulang karena retry jaringan:
```json
{
  "success": true,
  "message": "Event duplikat diabaikan (Idempotent OK).",
  "idempotent": true
}
```
