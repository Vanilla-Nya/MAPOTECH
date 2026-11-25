-- ==============================================================================
-- MAPOTECH SUPABASE MIGRATION: VITASCALE IOT DEVICES & SAVED WI-FI PROFILES
-- Schema: community_health_center
-- Date: 2026-11-25
-- ==============================================================================

CREATE SCHEMA IF NOT EXISTS community_health_center;
GRANT USAGE ON SCHEMA community_health_center TO anon, authenticated, service_role;

-- 1. Tabel Profil Konfigurasi Perangkat IoT VitaScale per Puskesmas
CREATE TABLE IF NOT EXISTS community_health_center.vitascale_iot_devices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    facility_id UUID REFERENCES public.user(id) ON DELETE CASCADE,
    faskes_code VARCHAR(64) NOT NULL DEFAULT 'PUSKESMAS-001',
    device_id VARCHAR(64) NOT NULL DEFAULT 'VTS-001',
    broker_host VARCHAR(128) NOT NULL DEFAULT 'broker.hivemq.com',
    broker_port INT NOT NULL DEFAULT 8884,
    tripod_height_cm NUMERIC(5, 1) NOT NULL DEFAULT 166.0,
    cal_factor NUMERIC(10, 4) NOT NULL DEFAULT 25.7500,
    active_wifi_ssid VARCHAR(128),
    last_rssi_dbm INT,
    last_status VARCHAR(32) NOT NULL DEFAULT 'offline',
    last_seen_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (faskes_code, device_id)
);

CREATE INDEX IF NOT EXISTS idx_vts_iot_devices_facility
    ON community_health_center.vitascale_iot_devices(facility_id);
CREATE INDEX IF NOT EXISTS idx_vts_iot_devices_faskes
    ON community_health_center.vitascale_iot_devices(faskes_code);

-- 2. Tabel Daftar Jaringan Wi-Fi Tersimpan per Puskesmas (Ala Saved Networks HP/Laptop)
CREATE TABLE IF NOT EXISTS community_health_center.vitascale_saved_wifi (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    facility_id UUID REFERENCES public.user(id) ON DELETE CASCADE,
    faskes_code VARCHAR(64) NOT NULL DEFAULT 'PUSKESMAS-001',
    device_id VARCHAR(64) NOT NULL DEFAULT 'VTS-001',
    ssid VARCHAR(128) NOT NULL,
    saved_password TEXT, -- Opsional: hanya terisi jika petugas mencentang "Simpan sandi Wi-Fi"
    security_type VARCHAR(32) NOT NULL DEFAULT 'WPA2',
    last_rssi_dbm INT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    last_connected_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (faskes_code, ssid)
);

CREATE INDEX IF NOT EXISTS idx_vts_saved_wifi_facility
    ON community_health_center.vitascale_saved_wifi(facility_id);
CREATE INDEX IF NOT EXISTS idx_vts_saved_wifi_faskes
    ON community_health_center.vitascale_saved_wifi(faskes_code);

-- 3. Row Level Security & Grants (selaras dengan skema community_health_center)
ALTER TABLE community_health_center.vitascale_iot_devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE community_health_center.vitascale_saved_wifi ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "policy_all_access_vitascale_iot_devices"
    ON community_health_center.vitascale_iot_devices;
CREATE POLICY "policy_all_access_vitascale_iot_devices"
    ON community_health_center.vitascale_iot_devices
    FOR ALL USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "policy_all_access_vitascale_saved_wifi"
    ON community_health_center.vitascale_saved_wifi;
CREATE POLICY "policy_all_access_vitascale_saved_wifi"
    ON community_health_center.vitascale_saved_wifi
    FOR ALL USING (true) WITH CHECK (true);

GRANT ALL ON TABLE community_health_center.vitascale_iot_devices TO anon, authenticated, service_role;
GRANT ALL ON TABLE community_health_center.vitascale_saved_wifi TO anon, authenticated, service_role;
