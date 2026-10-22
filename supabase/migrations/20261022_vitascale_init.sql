-- ==============================================================================
-- DRAFT MIGRATION: VITASCALE BY MAPOTECH
-- Module: IoT Anthropometry Screening (0–12 Years)
-- Status: DRAFT / PENDING HUMAN APPROVAL (Tidak dijalankan otomatis)
-- ==============================================================================

CREATE SCHEMA IF NOT EXISTS vitascale;

-- 1. Tabel Registrasi Perangkat Keras VitaScale
CREATE TABLE IF NOT EXISTS vitascale.devices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    facility_id UUID NOT NULL REFERENCES public.user(id) ON DELETE CASCADE,
    device_serial VARCHAR(64) UNIQUE NOT NULL,
    device_label VARCHAR(128) NOT NULL,
    token_hash VARCHAR(128) NOT NULL, -- Hashing SHA-256 token perangkat, BUKAN plaintext
    status VARCHAR(32) NOT NULL DEFAULT 'active' CHECK (status IN ('pending', 'active', 'revoked')),
    firmware_version VARCHAR(32) NOT NULL DEFAULT 'v1.0.0',
    last_ip VARCHAR(64),
    last_seen_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Index pencarian token hash untuk autentikasi cepat
CREATE INDEX IF NOT EXISTS idx_vitascale_devices_token ON vitascale.devices(token_hash);
CREATE INDEX IF NOT EXISTS idx_vitascale_devices_facility ON vitascale.devices(facility_id);

-- 2. Tabel Kode Pairing Sekali Pakai (One-Time Pairing Codes)
CREATE TABLE IF NOT EXISTS vitascale.pairing_codes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    facility_id UUID NOT NULL REFERENCES public.user(id) ON DELETE CASCADE,
    code_hash VARCHAR(128) NOT NULL UNIQUE,
    expires_at TIMESTAMPTZ NOT NULL,
    used_at TIMESTAMPTZ,
    used_by_device_id UUID REFERENCES vitascale.devices(id) ON DELETE SET NULL,
    created_by VARCHAR(64),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_vitascale_pairing_code ON vitascale.pairing_codes(code_hash);

-- 3. Tabel Sesi Skrining Aktif
CREATE TABLE IF NOT EXISTS vitascale.screening_sessions (
    id VARCHAR(64) PRIMARY KEY, -- Format VTS-YYYY-XXXXXXXX
    facility_id UUID NOT NULL REFERENCES public.user(id) ON DELETE CASCADE,
    child_id VARCHAR(64) NOT NULL,
    child_name VARCHAR(128) NOT NULL,
    child_nik VARCHAR(32),
    child_gender CHAR(1) NOT NULL CHECK (child_gender IN ('L', 'P')),
    child_birth_date DATE NOT NULL,
    mode VARCHAR(32) NOT NULL CHECK (mode IN ('recumbent_length', 'standing_height')),
    is_mode_manual_override BOOLEAN NOT NULL DEFAULT FALSE,
    device_id UUID REFERENCES vitascale.devices(id) ON DELETE SET NULL,
    is_demo BOOLEAN NOT NULL DEFAULT FALSE,
    status VARCHAR(32) NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'verified', 'cancelled')),
    start_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    end_time TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_vitascale_sessions_facility ON vitascale.screening_sessions(facility_id);
CREATE INDEX IF NOT EXISTS idx_vitascale_sessions_child ON vitascale.screening_sessions(child_id);

-- 4. Tabel Event Pengukuran Masuk (Sensor Event Ingestion dengan Pencegah Duplikasi)
CREATE TABLE IF NOT EXISTS vitascale.measurement_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id VARCHAR(64) NOT NULL REFERENCES vitascale.screening_sessions(id) ON DELETE CASCADE,
    device_id UUID REFERENCES vitascale.devices(id) ON DELETE SET NULL,
    measurement_type VARCHAR(32) NOT NULL CHECK (measurement_type IN ('weight', 'height', 'waist')),
    value_numeric NUMERIC(6, 2) NOT NULL,
    unit VARCHAR(16) NOT NULL,
    quality VARCHAR(32) NOT NULL CHECK (quality IN ('measuring', 'stable', 'failed', 'verified')),
    captured_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    idempotency_key VARCHAR(128) UNIQUE NOT NULL, -- Pencegah pencatatan ganda
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_vitascale_events_session ON vitascale.measurement_events(session_id);
CREATE INDEX IF NOT EXISTS idx_vitascale_events_idempotency ON vitascale.measurement_events(idempotency_key);

-- 5. Tabel Hasil Skrining Final Terverifikasi Petugas (Medical Record & Audit Trail)
CREATE TABLE IF NOT EXISTS vitascale.screening_results (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id VARCHAR(64) NOT NULL REFERENCES vitascale.screening_sessions(id) ON DELETE RESTRICT,
    facility_id UUID NOT NULL REFERENCES public.user(id) ON DELETE CASCADE,
    child_id VARCHAR(64) NOT NULL,
    child_name VARCHAR(128) NOT NULL,
    child_nik VARCHAR(32),
    child_age_months INT NOT NULL,
    mode VARCHAR(16) NOT NULL,
    weight_kg NUMERIC(5, 2) NOT NULL,
    height_cm NUMERIC(5, 1) NOT NULL,
    waist_cm NUMERIC(5, 1) NOT NULL,
    whtr_ratio NUMERIC(4, 2),
    verified_by VARCHAR(128) NOT NULL,
    verified_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_vitascale_results_facility ON vitascale.screening_results(facility_id);
CREATE INDEX IF NOT EXISTS idx_vitascale_results_child ON vitascale.screening_results(child_id);

-- ==============================================================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ==============================================================================

ALTER TABLE vitascale.devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE vitascale.pairing_codes ENABLE ROW LEVEL SECURITY;
ALTER TABLE vitascale.screening_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE vitascale.measurement_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE vitascale.screening_results ENABLE ROW LEVEL SECURITY;

-- Policy: Hanya faskes pemilik yang dapat melihat perangkatnya
CREATE POLICY vitascale_devices_isolation_policy ON vitascale.devices
    FOR ALL
    TO authenticated
    USING (facility_id = auth.uid());

CREATE POLICY vitascale_pairing_codes_isolation_policy ON vitascale.pairing_codes
    FOR ALL
    TO authenticated
    USING (facility_id = auth.uid());

CREATE POLICY vitascale_screening_sessions_isolation_policy ON vitascale.screening_sessions
    FOR ALL
    TO authenticated
    USING (facility_id = auth.uid());

CREATE POLICY vitascale_measurement_events_isolation_policy ON vitascale.measurement_events
    FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM vitascale.screening_sessions s
            WHERE s.id = measurement_events.session_id AND s.facility_id = auth.uid()
        )
    );

CREATE POLICY vitascale_screening_results_isolation_policy ON vitascale.screening_results
    FOR ALL
    TO authenticated
    USING (facility_id = auth.uid());
