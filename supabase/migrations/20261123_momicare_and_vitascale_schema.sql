-- ==============================================================================
-- MAPOTECH SUPABASE MIGRATION: COMMUNITY HEALTH CENTER (PUSKESMAS)
-- Modules: MomiCare (Ibu Hamil, 0–9 Bulan) & VitaScale Anak (Balita, 0–59 Bulan)
-- Design: Append-Only (ALL INSERT) + Blockchain Hash Chain (SHA-256)
-- Schema: community_health_center
-- Execution Date: 2026-11-23
-- ==============================================================================

-- 0. Buat Skema & Extension Kriptografi
CREATE SCHEMA IF NOT EXISTS community_health_center;
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Berikan izin akses skema ke peran Supabase
GRANT USAGE ON SCHEMA community_health_center TO anon, authenticated, service_role;

-- ==============================================================================
-- 1. TABEL MODUL MOMICARE (IBU HAMIL 0–9 BULAN)
-- ==============================================================================

-- 1.1 Tabel Antrian Kehamilan (MomiCare Queue)
CREATE TABLE IF NOT EXISTS community_health_center.momicare_queue (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    facility_id UUID NOT NULL REFERENCES public.user(id) ON DELETE CASCADE,
    id_patient UUID REFERENCES public.user(id) ON DELETE SET NULL, -- NULL jika pasien belum terdaftar di Mapotech
    nik VARCHAR(32) NOT NULL,
    nama_lengkap VARCHAR(128) NOT NULL,
    nama_suami VARCHAR(128),
    no_kk VARCHAR(32),
    no_telepon VARCHAR(32), -- Kontak WA/Telp (Opsional)
    alamat TEXT NOT NULL,
    latitude NUMERIC(10, 7) NOT NULL DEFAULT -7.9582, -- Koordinat rumah untuk Home Visit jika no_telepon kosong
    longitude NUMERIC(10, 7) NOT NULL DEFAULT 113.9123,
    hpht DATE NOT NULL, -- Hari Pertama Haid Terakhir
    hpl DATE NOT NULL,  -- Hari Perkiraan Lahir (Taksiran Persalinan)
    gravida INT NOT NULL DEFAULT 1, -- Kehamilan ke-
    partus INT NOT NULL DEFAULT 0,  -- Jumlah persalinan lampau
    abortus INT NOT NULL DEFAULT 0, -- Jumlah keguguran
    kspr_score INT NOT NULL DEFAULT 2, -- Skor Poedji Rochjati (KRR: 2, KRT: 6-10, KRST: >= 12)
    kspr_status VARCHAR(32) NOT NULL DEFAULT 'KRR' CHECK (kspr_status IN ('KRR', 'KRT', 'KRST')),
    lifecycle VARCHAR(32) NOT NULL DEFAULT 'aktif' CHECK (lifecycle IN ('aktif', 'selesai', 'rujukan_eksternal', 'batal')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_momicare_queue_facility ON community_health_center.momicare_queue(facility_id);
CREATE INDEX IF NOT EXISTS idx_momicare_queue_patient ON community_health_center.momicare_queue(id_patient);
CREATE INDEX IF NOT EXISTS idx_momicare_queue_nik ON community_health_center.momicare_queue(nik);
CREATE INDEX IF NOT EXISTS idx_momicare_queue_lifecycle ON community_health_center.momicare_queue(lifecycle);

-- 1.2 Tabel Log Kunjungan ANC (ALL INSERT + Hash Chain SHA-256)
CREATE TABLE IF NOT EXISTS community_health_center.momicare_kunjungan (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    id_queue UUID NOT NULL REFERENCES community_health_center.momicare_queue(id) ON DELETE CASCADE,
    id_patient UUID REFERENCES public.user(id) ON DELETE SET NULL,
    visit_number VARCHAR(16) NOT NULL, -- 'K1', 'K2', 'K3', 'K4', 'K5', 'K6'
    visit_date DATE NOT NULL DEFAULT CURRENT_DATE,
    examiner_name VARCHAR(128) NOT NULL,
    examiner_role VARCHAR(32) NOT NULL DEFAULT 'Bidan' CHECK (examiner_role IN ('Bidan', 'Dokter', 'Kader')),
    is_home_visit BOOLEAN NOT NULL DEFAULT FALSE, -- Ditandai TRUE jika petugas mendatangi rumah pasien
    notes TEXT,
    previous_hash VARCHAR(64) NOT NULL, -- Genesis: 64 nol
    current_hash VARCHAR(64) NOT NULL,  -- SHA-256(previous_hash || id_queue || visit_number || visit_date || created_at)
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_momicare_kunjungan_queue ON community_health_center.momicare_kunjungan(id_queue);
CREATE INDEX IF NOT EXISTS idx_momicare_kunjungan_hash ON community_health_center.momicare_kunjungan(current_hash);
CREATE INDEX IF NOT EXISTS idx_momicare_kunjungan_date ON community_health_center.momicare_kunjungan(visit_date);

-- 1.3 Tabel Hasil Pemeriksaan Fisik & 10T ANC
CREATE TABLE IF NOT EXISTS community_health_center.momicare_pemeriksaan (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    id_kunjungan UUID NOT NULL REFERENCES community_health_center.momicare_kunjungan(id) ON DELETE CASCADE,
    usia_kehamilan_minggu NUMERIC(4, 1) NOT NULL,
    berat_badan_kg NUMERIC(5, 2) NOT NULL,
    tinggi_badan_cm NUMERIC(5, 1) NOT NULL,
    tekanan_darah_sistol INT NOT NULL DEFAULT 120,
    tekanan_darah_diastol INT NOT NULL DEFAULT 80,
    lila_cm NUMERIC(4, 1) NOT NULL, -- Lingkar Lengan Atas (Deteksi KEK jika < 23.5 cm)
    tfu_cm NUMERIC(4, 1),           -- Tinggi Fundus Uteri
    djj_bpm INT,                    -- Denyut Jantung Janin (120-160 normal)
    presentasi_janin VARCHAR(32) DEFAULT 'Kepala', -- 'Kepala', 'Sungsang', 'Lintang'
    status_imunisasi_tt VARCHAR(16) DEFAULT 'T2',
    tablet_fe_diberikan INT DEFAULT 30,
    hb_g_dl NUMERIC(4, 1),          -- Kadar Hemoglobin (Anemia jika < 11 g/dL)
    protein_urine VARCHAR(16) DEFAULT 'Negatif', -- 'Negatif', '+1', '+2', '+3'
    gula_darah_mg_dl NUMERIC(5, 1),
    tata_laksana_rujukan TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_momicare_pemeriksaan_kunjungan ON community_health_center.momicare_pemeriksaan(id_kunjungan);

-- 1.4 Tabel Diagnosa & Rekomendasi Kebidanan
CREATE TABLE IF NOT EXISTS community_health_center.momicare_diagnosa (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    id_kunjungan UUID NOT NULL REFERENCES community_health_center.momicare_kunjungan(id) ON DELETE CASCADE,
    icd10_code VARCHAR(16),
    diagnosa_text TEXT NOT NULL,
    faktor_risiko TEXT,
    tindakan_terapi TEXT,
    anjuran_nutrisi TEXT,
    satusehat_condition_id VARCHAR(64),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_momicare_diagnosa_kunjungan ON community_health_center.momicare_diagnosa(id_kunjungan);

-- 1.5 Tabel Pengingat Kunjungan ANC (Jadwal WhatsApp / SMS / Home Visit)
CREATE TABLE IF NOT EXISTS community_health_center.momicare_reminder (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    id_queue UUID NOT NULL REFERENCES community_health_center.momicare_queue(id) ON DELETE CASCADE,
    target_visit_number VARCHAR(16) NOT NULL,
    scheduled_date DATE NOT NULL,
    channel VARCHAR(16) NOT NULL DEFAULT 'whatsapp' CHECK (channel IN ('whatsapp', 'sms', 'home_visit')),
    status VARCHAR(16) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'sent', 'visited', 'overdue')),
    last_attempt_at TIMESTAMPTZ,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_momicare_reminder_queue ON community_health_center.momicare_reminder(id_queue);
CREATE INDEX IF NOT EXISTS idx_momicare_reminder_status ON community_health_center.momicare_reminder(status, scheduled_date);

-- ==============================================================================
-- 2. TABEL MODUL VITASCALE ANAK (BALITA 0–59 BULAN)
-- ==============================================================================

-- 2.1 Tabel Antrian Pemantauan Tumbuh Kembang Balita
CREATE TABLE IF NOT EXISTS community_health_center.vitascale_anak_queue (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    facility_id UUID NOT NULL REFERENCES public.user(id) ON DELETE CASCADE,
    id_momicare_queue UUID REFERENCES community_health_center.momicare_queue(id) ON DELETE SET NULL, -- Relasi transisi dari persalinan ibu
    id_patient UUID REFERENCES public.user(id) ON DELETE SET NULL, -- Akun anak jika terdaftar
    nik VARCHAR(32) NOT NULL,
    nama_anak VARCHAR(128) NOT NULL,
    jenis_kelamin CHAR(1) NOT NULL CHECK (jenis_kelamin IN ('L', 'P')),
    tanggal_lahir DATE NOT NULL,
    nama_wali VARCHAR(128) NOT NULL,
    no_kk VARCHAR(32),
    no_telepon VARCHAR(32), -- Kontak orang tua (Opsional)
    alamat TEXT NOT NULL,
    latitude NUMERIC(10, 7) NOT NULL DEFAULT -7.9582, -- Diwarisi dari ibu untuk Home Visit
    longitude NUMERIC(10, 7) NOT NULL DEFAULT 113.9123,
    lifecycle VARCHAR(32) NOT NULL DEFAULT 'aktif' CHECK (lifecycle IN ('aktif', 'lulus_59_bulan', 'pindah', 'meninggal')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_vitascale_anak_queue_facility ON community_health_center.vitascale_anak_queue(facility_id);
CREATE INDEX IF NOT EXISTS idx_vitascale_anak_queue_momicare ON community_health_center.vitascale_anak_queue(id_momicare_queue);
CREATE INDEX IF NOT EXISTS idx_vitascale_anak_queue_nik ON community_health_center.vitascale_anak_queue(nik);
CREATE INDEX IF NOT EXISTS idx_vitascale_anak_queue_lifecycle ON community_health_center.vitascale_anak_queue(lifecycle);

-- 2.2 Tabel Log Kunjungan Posyandu Balita (ALL INSERT + Hash Chain SHA-256)
CREATE TABLE IF NOT EXISTS community_health_center.vitascale_anak_kunjungan (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    id_queue UUID NOT NULL REFERENCES community_health_center.vitascale_anak_queue(id) ON DELETE CASCADE,
    id_patient UUID REFERENCES public.user(id) ON DELETE SET NULL,
    visit_number VARCHAR(16) NOT NULL, -- e.g. 'Bulan-1', 'Bulan-6', 'Bulan-12'
    visit_date DATE NOT NULL DEFAULT CURRENT_DATE,
    posyandu_name VARCHAR(128) NOT NULL DEFAULT 'Posyandu Terpadu Puskesmas',
    examiner_name VARCHAR(128) NOT NULL,
    is_home_visit BOOLEAN NOT NULL DEFAULT FALSE,
    notes TEXT,
    previous_hash VARCHAR(64) NOT NULL, -- Genesis: 64 nol
    current_hash VARCHAR(64) NOT NULL,  -- SHA-256(previous_hash || id_queue || visit_number || visit_date || created_at)
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_vitascale_anak_kunjungan_queue ON community_health_center.vitascale_anak_kunjungan(id_queue);
CREATE INDEX IF NOT EXISTS idx_vitascale_anak_kunjungan_hash ON community_health_center.vitascale_anak_kunjungan(current_hash);
CREATE INDEX IF NOT EXISTS idx_vitascale_anak_kunjungan_date ON community_health_center.vitascale_anak_kunjungan(visit_date);

-- 2.3 Tabel Hasil Antropometri IoT & Skrining Pertumbuhan
CREATE TABLE IF NOT EXISTS community_health_center.vitascale_anak_pemeriksaan (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    id_kunjungan UUID NOT NULL REFERENCES community_health_center.vitascale_anak_kunjungan(id) ON DELETE CASCADE,
    usia_bulan INT NOT NULL, -- 0 hingga 59 bulan
    berat_badan_kg NUMERIC(5, 2) NOT NULL,   -- Dari Load Cell HX711 atau timbangan digital
    panjang_tinggi_cm NUMERIC(5, 1) NOT NULL, -- Dari Ultrasonik HC-SR04 atau PCV kamera
    metode_ukur VARCHAR(8) NOT NULL DEFAULT 'PB' CHECK (metode_ukur IN ('PB', 'TB')), -- PB < 24 bln, TB >= 24 bln
    lingkar_kepala_cm NUMERIC(4, 1),
    lingkar_lengan_lila_cm NUMERIC(4, 1),
    lingkar_perut_cm NUMERIC(4, 1),
    zscore_bbu NUMERIC(4, 2), -- BB/U (Underweight jika < -2 SD)
    zscore_tbu NUMERIC(4, 2), -- TB/U (Stunting jika < -2 SD, Severely Stunted jika < -3 SD)
    zscore_bbtb NUMERIC(4, 2), -- BB/TB (Wasting jika < -2 SD)
    status_gizi VARCHAR(32) NOT NULL DEFAULT 'Gizi Baik',
    status_stunting VARCHAR(32) NOT NULL DEFAULT 'Normal',
    kms_status VARCHAR(16) DEFAULT 'N' CHECK (kms_status IN ('N', 'T', '2T', 'BGM', 'Baru')),
    dapat_vitamin_a BOOLEAN NOT NULL DEFAULT FALSE,
    dapat_obat_cacing BOOLEAN NOT NULL DEFAULT FALSE,
    imunisasi_diberikan VARCHAR(64),
    iot_source VARCHAR(64) DEFAULT 'esp32_hx711_ultrasonic',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_vitascale_anak_pemeriksaan_kunjungan ON community_health_center.vitascale_anak_pemeriksaan(id_kunjungan);

-- 2.4 Tabel Diagnosa AI Reasoning & Intervensi Gizi Balita
CREATE TABLE IF NOT EXISTS community_health_center.vitascale_anak_diagnosa (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    id_kunjungan UUID NOT NULL REFERENCES community_health_center.vitascale_anak_kunjungan(id) ON DELETE CASCADE,
    icd10_code VARCHAR(16) DEFAULT 'E44.0',
    diagnosa_primer TEXT NOT NULL,
    faktor_etiologi TEXT,
    rencana_nutrisi_harian TEXT NOT NULL,
    rekomendasi_protein_hewani TEXT, -- e.g. 1 butir telur/hari, ikan lokal, hati ayam
    edukasi_orang_tua TEXT,
    satusehat_observation_id VARCHAR(64),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_vitascale_anak_diagnosa_kunjungan ON community_health_center.vitascale_anak_diagnosa(id_kunjungan);

-- 2.5 Tabel Pengingat Posyandu Balita (Jadwal WhatsApp / SMS / Home Visit)
CREATE TABLE IF NOT EXISTS community_health_center.vitascale_anak_reminder (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    id_queue UUID NOT NULL REFERENCES community_health_center.vitascale_anak_queue(id) ON DELETE CASCADE,
    target_visit_number VARCHAR(16) NOT NULL,
    scheduled_date DATE NOT NULL,
    channel VARCHAR(16) NOT NULL DEFAULT 'whatsapp' CHECK (channel IN ('whatsapp', 'sms', 'home_visit')),
    status VARCHAR(16) NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'sent', 'visited', 'overdue')),
    last_attempt_at TIMESTAMPTZ,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_vitascale_anak_reminder_queue ON community_health_center.vitascale_anak_reminder(id_queue);
CREATE INDEX IF NOT EXISTS idx_vitascale_anak_reminder_status ON community_health_center.vitascale_anak_reminder(status, scheduled_date);

-- ==============================================================================
-- 3. FUNGSI OTOMATIS BLOCKCHAIN HASH CHAIN (SHA-256)
-- ==============================================================================

-- 3.1 Fungsi Hash Chain untuk MomiCare Kunjungan
CREATE OR REPLACE FUNCTION community_health_center.fn_momicare_hash_chain()
RETURNS TRIGGER AS $$
DECLARE
    last_hash VARCHAR(64);
    genesis_hash CONSTANT VARCHAR(64) := '0000000000000000000000000000000000000000000000000000000000000000';
BEGIN
    -- Cari hash kunjungan terakhir pada antrian ibu hamil yang sama
    SELECT current_hash INTO last_hash
    FROM community_health_center.momicare_kunjungan
    WHERE id_queue = NEW.id_queue
    ORDER BY created_at DESC
    LIMIT 1;

    -- Jika belum ada kunjungan sebelumnya, gunakan genesis hash (64 nol)
    IF last_hash IS NULL THEN
        NEW.previous_hash := genesis_hash;
    ELSE
        NEW.previous_hash := last_hash;
    END IF;

    -- Hitung SHA-256 hash saat ini
    NEW.current_hash := encode(
        digest(
            NEW.previous_hash || 
            NEW.id_queue::TEXT || 
            NEW.visit_number || 
            NEW.visit_date::TEXT || 
            COALESCE(NEW.created_at, NOW())::TEXT,
            'sha256'
        ),
        'hex'
    );

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_momicare_hash_chain ON community_health_center.momicare_kunjungan;
CREATE TRIGGER trg_momicare_hash_chain
BEFORE INSERT ON community_health_center.momicare_kunjungan
FOR EACH ROW
EXECUTE FUNCTION community_health_center.fn_momicare_hash_chain();

-- 3.2 Fungsi Hash Chain untuk VitaScale Anak Kunjungan
CREATE OR REPLACE FUNCTION community_health_center.fn_vitascale_anak_hash_chain()
RETURNS TRIGGER AS $$
DECLARE
    last_hash VARCHAR(64);
    genesis_hash CONSTANT VARCHAR(64) := '0000000000000000000000000000000000000000000000000000000000000000';
BEGIN
    -- Cari hash kunjungan terakhir pada antrian balita yang sama
    SELECT current_hash INTO last_hash
    FROM community_health_center.vitascale_anak_kunjungan
    WHERE id_queue = NEW.id_queue
    ORDER BY created_at DESC
    LIMIT 1;

    -- Jika belum ada kunjungan sebelumnya, gunakan genesis hash (64 nol)
    IF last_hash IS NULL THEN
        NEW.previous_hash := genesis_hash;
    ELSE
        NEW.previous_hash := last_hash;
    END IF;

    -- Hitung SHA-256 hash saat ini
    NEW.current_hash := encode(
        digest(
            NEW.previous_hash || 
            NEW.id_queue::TEXT || 
            NEW.visit_number || 
            NEW.visit_date::TEXT || 
            COALESCE(NEW.created_at, NOW())::TEXT,
            'sha256'
        ),
        'hex'
    );

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_vitascale_anak_hash_chain ON community_health_center.vitascale_anak_kunjungan;
CREATE TRIGGER trg_vitascale_anak_hash_chain
BEFORE INSERT ON community_health_center.vitascale_anak_kunjungan
FOR EACH ROW
EXECUTE FUNCTION community_health_center.fn_vitascale_anak_hash_chain();

-- ==============================================================================
-- 4. PENEGAKAN IMMUTABLE APPEND-ONLY (DILARANG UPDATE & DELETE PADA REKAM MEDIS)
-- ==============================================================================

CREATE OR REPLACE FUNCTION community_health_center.fn_enforce_append_only()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'REKAM MEDIS IMUTABEL: Tabel ini beroperasi dengan aturan Append-Only (ALL INSERT). Operasi UPDATE atau DELETE tidak diizinkan untuk menjamin keaslian audit trail rekam medis pasien.';
END;
$$ LANGUAGE plpgsql;

-- Pasang Trigger Penegak Immutability
DROP TRIGGER IF EXISTS trg_immutability_momicare_kunjungan ON community_health_center.momicare_kunjungan;
CREATE TRIGGER trg_immutability_momicare_kunjungan
BEFORE UPDATE OR DELETE ON community_health_center.momicare_kunjungan
FOR EACH ROW EXECUTE FUNCTION community_health_center.fn_enforce_append_only();

DROP TRIGGER IF EXISTS trg_immutability_momicare_pemeriksaan ON community_health_center.momicare_pemeriksaan;
CREATE TRIGGER trg_immutability_momicare_pemeriksaan
BEFORE UPDATE OR DELETE ON community_health_center.momicare_pemeriksaan
FOR EACH ROW EXECUTE FUNCTION community_health_center.fn_enforce_append_only();

DROP TRIGGER IF EXISTS trg_immutability_momicare_diagnosa ON community_health_center.momicare_diagnosa;
CREATE TRIGGER trg_immutability_momicare_diagnosa
BEFORE UPDATE OR DELETE ON community_health_center.momicare_diagnosa
FOR EACH ROW EXECUTE FUNCTION community_health_center.fn_enforce_append_only();

DROP TRIGGER IF EXISTS trg_immutability_vitascale_kunjungan ON community_health_center.vitascale_anak_kunjungan;
CREATE TRIGGER trg_immutability_vitascale_kunjungan
BEFORE UPDATE OR DELETE ON community_health_center.vitascale_anak_kunjungan
FOR EACH ROW EXECUTE FUNCTION community_health_center.fn_enforce_append_only();

DROP TRIGGER IF EXISTS trg_immutability_vitascale_pemeriksaan ON community_health_center.vitascale_anak_pemeriksaan;
CREATE TRIGGER trg_immutability_vitascale_pemeriksaan
BEFORE UPDATE OR DELETE ON community_health_center.vitascale_anak_pemeriksaan
FOR EACH ROW EXECUTE FUNCTION community_health_center.fn_enforce_append_only();

DROP TRIGGER IF EXISTS trg_immutability_vitascale_diagnosa ON community_health_center.vitascale_anak_diagnosa;
CREATE TRIGGER trg_immutability_vitascale_diagnosa
BEFORE UPDATE OR DELETE ON community_health_center.vitascale_anak_diagnosa
FOR EACH ROW EXECUTE FUNCTION community_health_center.fn_enforce_append_only();

-- ==============================================================================
-- 5. ROW LEVEL SECURITY (RLS) & HAK AKSES PERAN
-- ==============================================================================

-- Aktifkan RLS
ALTER TABLE community_health_center.momicare_queue ENABLE ROW LEVEL SECURITY;
ALTER TABLE community_health_center.momicare_kunjungan ENABLE ROW LEVEL SECURITY;
ALTER TABLE community_health_center.momicare_pemeriksaan ENABLE ROW LEVEL SECURITY;
ALTER TABLE community_health_center.momicare_diagnosa ENABLE ROW LEVEL SECURITY;
ALTER TABLE community_health_center.momicare_reminder ENABLE ROW LEVEL SECURITY;

ALTER TABLE community_health_center.vitascale_anak_queue ENABLE ROW LEVEL SECURITY;
ALTER TABLE community_health_center.vitascale_anak_kunjungan ENABLE ROW LEVEL SECURITY;
ALTER TABLE community_health_center.vitascale_anak_pemeriksaan ENABLE ROW LEVEL SECURITY;
ALTER TABLE community_health_center.vitascale_anak_diagnosa ENABLE ROW LEVEL SECURITY;
ALTER TABLE community_health_center.vitascale_anak_reminder ENABLE ROW LEVEL SECURITY;

-- Policy Akses Penuh untuk Service Role & Authenticated / Anon
DO $$
DECLARE
    tbl TEXT;
    tables TEXT[] := ARRAY[
        'momicare_queue', 'momicare_kunjungan', 'momicare_pemeriksaan', 'momicare_diagnosa', 'momicare_reminder',
        'vitascale_anak_queue', 'vitascale_anak_kunjungan', 'vitascale_anak_pemeriksaan', 'vitascale_anak_diagnosa', 'vitascale_anak_reminder'
    ];
BEGIN
    FOREACH tbl IN ARRAY tables LOOP
        EXECUTE format('DROP POLICY IF EXISTS "policy_all_access_%s" ON community_health_center.%I;', tbl, tbl);
        EXECUTE format('CREATE POLICY "policy_all_access_%s" ON community_health_center.%I FOR ALL USING (true) WITH CHECK (true);', tbl, tbl);
    END LOOP;
END $$;

-- Berikan izin manipulasi tabel ke anon, authenticated, dan service_role
GRANT ALL ON ALL TABLES IN SCHEMA community_health_center TO anon, authenticated, service_role;
GRANT ALL ON ALL ROUTINES IN SCHEMA community_health_center TO anon, authenticated, service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA community_health_center TO anon, authenticated, service_role;
