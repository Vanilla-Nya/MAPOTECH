-- ============================================================================
-- MIGRATION: 20261126_rls_letters_and_puskesmas_mqtt.sql
-- Purpose:
--   1. Ensure `community_health_center.vitascale_iot_devices` and
--      `community_health_center.vitascale_saved_wifi` exist with MQTT fields
--      (`ws_path`, `cloud_gateway_url`, `use_wildcard`) and RLS + RPCs anchored
--      directly to `public."user"`.
--   2. Configure Medical Letter (Surat Rujukan, Surat Keterangan Sehat, Surat
--      Keterangan Sakit) QR Verification RPC (`get_medical_letter_verification`)
--      with masked NIK & safe public doctor profile, plus scoped RLS policies
--      on `private_doctor.*` and `public` doctor tables + missing FK indexes.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 0. SCHEMAS & GRANTS
-- ----------------------------------------------------------------------------
CREATE SCHEMA IF NOT EXISTS private;
CREATE SCHEMA IF NOT EXISTS community_health_center;

GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
GRANT USAGE ON SCHEMA private TO anon, authenticated, service_role;
GRANT USAGE ON SCHEMA community_health_center TO anon, authenticated, service_role;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.schemata WHERE schema_name = 'private_doctor'
  ) THEN
    EXECUTE 'GRANT USAGE ON SCHEMA private_doctor TO anon, authenticated, service_role';
  END IF;
END $$;

-- ============================================================================
-- PART 1: INTERNAL RLS HELPER FUNCTIONS (PRIVATE SCHEMA, NOT EXPOSED TO API)
-- ============================================================================

CREATE OR REPLACE FUNCTION private.is_valid_public_health_center_user(p_user_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT p_user_id IS NOT NULL
    AND (
      ((SELECT auth.uid()) IS NOT NULL AND (SELECT auth.uid()) = p_user_id)
      OR EXISTS (
        SELECT 1
        FROM public."user" u
        WHERE u.id = p_user_id
          AND lower(COALESCE(u.role, '')) IN (
            'puskesmas',
            'ponkesdes',
            'public_health_center',
            'village_clinic',
            'admin'
          )
      )
    );
$$;

CREATE OR REPLACE FUNCTION private.is_valid_doctor_user(p_doctor_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT p_doctor_id IS NOT NULL
    AND (
      ((SELECT auth.uid()) IS NOT NULL AND (SELECT auth.uid()) = p_doctor_id)
      OR EXISTS (
        SELECT 1
        FROM public."user" u
        WHERE u.id = p_doctor_id
          AND lower(COALESCE(u.role, '')) IN (
            'dokter',
            'praktikmandiri',
            'asisten_dokter',
            'puskesmas',
            'ponkesdes',
            'public_health_center',
            'admin'
          )
      )
    );
$$;

CREATE OR REPLACE FUNCTION private.is_existing_public_user(p_user_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
  SELECT p_user_id IS NOT NULL
    AND (
      ((SELECT auth.uid()) IS NOT NULL AND (SELECT auth.uid()) = p_user_id)
      OR EXISTS (SELECT 1 FROM public."user" u WHERE u.id = p_user_id)
    );
$$;

REVOKE ALL ON FUNCTION private.is_valid_public_health_center_user(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION private.is_valid_public_health_center_user(uuid) TO anon, authenticated, service_role;

REVOKE ALL ON FUNCTION private.is_valid_doctor_user(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION private.is_valid_doctor_user(uuid) TO anon, authenticated, service_role;

REVOKE ALL ON FUNCTION private.is_existing_public_user(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION private.is_existing_public_user(uuid) TO anon, authenticated, service_role;

-- ============================================================================
-- PART 2: PUSKESMAS / PUBLIC HEALTH CENTER MQTT & WI-FI SETTINGS + RLS
-- ============================================================================

CREATE TABLE IF NOT EXISTS community_health_center.vitascale_iot_devices (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  facility_id       UUID REFERENCES public."user"(id) ON DELETE CASCADE,
  faskes_code       TEXT NOT NULL DEFAULT 'PUSKESMAS-001',
  device_id         TEXT NOT NULL DEFAULT 'timbangan-01',
  broker_host       TEXT NOT NULL DEFAULT 'broker.emqx.io',
  broker_port       INTEGER NOT NULL DEFAULT 8084,
  ws_path           TEXT NOT NULL DEFAULT '/mqtt',
  cloud_gateway_url TEXT NOT NULL DEFAULT 'https://mapotechiotmqtt.vercel.app',
  tripod_height_cm  NUMERIC(6,2) NOT NULL DEFAULT 200.0,
  cal_factor        NUMERIC(10,2) DEFAULT 420.0,
  use_wildcard      BOOLEAN NOT NULL DEFAULT true,
  active_wifi_ssid  TEXT,
  last_rssi_dbm     INTEGER,
  last_status       TEXT DEFAULT 'offline',
  last_seen_at      TIMESTAMPTZ,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (faskes_code, device_id)
);

ALTER TABLE IF EXISTS community_health_center.vitascale_iot_devices
  ADD COLUMN IF NOT EXISTS ws_path TEXT NOT NULL DEFAULT '/mqtt',
  ADD COLUMN IF NOT EXISTS cloud_gateway_url TEXT NOT NULL DEFAULT 'https://mapotechiotmqtt.vercel.app',
  ADD COLUMN IF NOT EXISTS use_wildcard BOOLEAN NOT NULL DEFAULT true;

CREATE INDEX IF NOT EXISTS idx_vitascale_iot_devices_facility_updated
  ON community_health_center.vitascale_iot_devices(facility_id, updated_at DESC);

CREATE TABLE IF NOT EXISTS community_health_center.vitascale_saved_wifi (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  facility_id       UUID REFERENCES public."user"(id) ON DELETE CASCADE,
  faskes_code       TEXT NOT NULL DEFAULT 'PUSKESMAS-001',
  device_id         TEXT NOT NULL DEFAULT 'timbangan-01',
  ssid              TEXT NOT NULL,
  saved_password    TEXT DEFAULT '',
  security_type     TEXT DEFAULT 'WPA2',
  last_rssi_dbm     INTEGER,
  is_active         BOOLEAN NOT NULL DEFAULT false,
  last_connected_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (faskes_code, ssid)
);

CREATE INDEX IF NOT EXISTS idx_vitascale_saved_wifi_facility
  ON community_health_center.vitascale_saved_wifi(facility_id);
CREATE INDEX IF NOT EXISTS idx_vitascale_saved_wifi_faskes
  ON community_health_center.vitascale_saved_wifi(faskes_code);

ALTER TABLE community_health_center.vitascale_iot_devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE community_health_center.vitascale_saved_wifi ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "policy_all_access_vitascale_iot_devices"
  ON community_health_center.vitascale_iot_devices;
DROP POLICY IF EXISTS "vitascale_iot_devices_puskesmas_select"
  ON community_health_center.vitascale_iot_devices;
DROP POLICY IF EXISTS "vitascale_iot_devices_puskesmas_insert"
  ON community_health_center.vitascale_iot_devices;
DROP POLICY IF EXISTS "vitascale_iot_devices_puskesmas_update"
  ON community_health_center.vitascale_iot_devices;
DROP POLICY IF EXISTS "vitascale_iot_devices_puskesmas_delete"
  ON community_health_center.vitascale_iot_devices;

CREATE POLICY "vitascale_iot_devices_puskesmas_select"
  ON community_health_center.vitascale_iot_devices
  FOR SELECT
  TO anon, authenticated
  USING ((SELECT private.is_valid_public_health_center_user(facility_id)));

CREATE POLICY "vitascale_iot_devices_puskesmas_insert"
  ON community_health_center.vitascale_iot_devices
  FOR INSERT
  TO anon, authenticated
  WITH CHECK ((SELECT private.is_valid_public_health_center_user(facility_id)));

CREATE POLICY "vitascale_iot_devices_puskesmas_update"
  ON community_health_center.vitascale_iot_devices
  FOR UPDATE
  TO anon, authenticated
  USING ((SELECT private.is_valid_public_health_center_user(facility_id)))
  WITH CHECK ((SELECT private.is_valid_public_health_center_user(facility_id)));

CREATE POLICY "vitascale_iot_devices_puskesmas_delete"
  ON community_health_center.vitascale_iot_devices
  FOR DELETE
  TO anon, authenticated
  USING ((SELECT private.is_valid_public_health_center_user(facility_id)));

DROP POLICY IF EXISTS "policy_all_access_vitascale_saved_wifi"
  ON community_health_center.vitascale_saved_wifi;
DROP POLICY IF EXISTS "vitascale_saved_wifi_puskesmas_select"
  ON community_health_center.vitascale_saved_wifi;
DROP POLICY IF EXISTS "vitascale_saved_wifi_puskesmas_insert"
  ON community_health_center.vitascale_saved_wifi;
DROP POLICY IF EXISTS "vitascale_saved_wifi_puskesmas_update"
  ON community_health_center.vitascale_saved_wifi;
DROP POLICY IF EXISTS "vitascale_saved_wifi_puskesmas_delete"
  ON community_health_center.vitascale_saved_wifi;

CREATE POLICY "vitascale_saved_wifi_puskesmas_select"
  ON community_health_center.vitascale_saved_wifi
  FOR SELECT
  TO anon, authenticated
  USING ((SELECT private.is_valid_public_health_center_user(facility_id)));

CREATE POLICY "vitascale_saved_wifi_puskesmas_insert"
  ON community_health_center.vitascale_saved_wifi
  FOR INSERT
  TO anon, authenticated
  WITH CHECK ((SELECT private.is_valid_public_health_center_user(facility_id)));

CREATE POLICY "vitascale_saved_wifi_puskesmas_update"
  ON community_health_center.vitascale_saved_wifi
  FOR UPDATE
  TO anon, authenticated
  USING ((SELECT private.is_valid_public_health_center_user(facility_id)))
  WITH CHECK ((SELECT private.is_valid_public_health_center_user(facility_id)));

CREATE POLICY "vitascale_saved_wifi_puskesmas_delete"
  ON community_health_center.vitascale_saved_wifi
  FOR DELETE
  TO anon, authenticated
  USING ((SELECT private.is_valid_public_health_center_user(facility_id)));

GRANT SELECT, INSERT, UPDATE, DELETE
  ON TABLE community_health_center.vitascale_iot_devices
  TO anon, authenticated, service_role;
GRANT SELECT, INSERT, UPDATE, DELETE
  ON TABLE community_health_center.vitascale_saved_wifi
  TO anon, authenticated, service_role;

-- Replace permissive policies on `public.user_detail_public_health_center` with user-anchored policies
DO $$
BEGIN
  IF to_regclass('public.user_detail_public_health_center') IS NOT NULL THEN
    EXECUTE 'ALTER TABLE public.user_detail_public_health_center ENABLE ROW LEVEL SECURITY';

    EXECUTE 'DROP POLICY IF EXISTS "Allow public select user_detail_public_health_center" ON public.user_detail_public_health_center';
    EXECUTE 'DROP POLICY IF EXISTS "Allow public insert user_detail_public_health_center" ON public.user_detail_public_health_center';
    EXECUTE 'DROP POLICY IF EXISTS "Allow public update user_detail_public_health_center" ON public.user_detail_public_health_center';
    EXECUTE 'DROP POLICY IF EXISTS "Allow public delete user_detail_public_health_center" ON public.user_detail_public_health_center';
    EXECUTE 'DROP POLICY IF EXISTS "puskesmas_detail_public_select" ON public.user_detail_public_health_center';
    EXECUTE 'DROP POLICY IF EXISTS "puskesmas_detail_owner_insert" ON public.user_detail_public_health_center';
    EXECUTE 'DROP POLICY IF EXISTS "puskesmas_detail_owner_update" ON public.user_detail_public_health_center';
    EXECUTE 'DROP POLICY IF EXISTS "puskesmas_detail_owner_delete" ON public.user_detail_public_health_center';

    EXECUTE 'CREATE POLICY "puskesmas_detail_public_select" ON public.user_detail_public_health_center FOR SELECT TO anon, authenticated USING (true)';
    EXECUTE 'CREATE POLICY "puskesmas_detail_owner_insert" ON public.user_detail_public_health_center FOR INSERT TO anon, authenticated WITH CHECK ((SELECT private.is_valid_public_health_center_user(id)))';
    EXECUTE 'CREATE POLICY "puskesmas_detail_owner_update" ON public.user_detail_public_health_center FOR UPDATE TO anon, authenticated USING ((SELECT private.is_valid_public_health_center_user(id))) WITH CHECK ((SELECT private.is_valid_public_health_center_user(id)))';
    EXECUTE 'CREATE POLICY "puskesmas_detail_owner_delete" ON public.user_detail_public_health_center FOR DELETE TO anon, authenticated USING ((SELECT private.is_valid_public_health_center_user(id)))';
  END IF;
END $$;

-- RPC: Fetch Puskesmas MQTT settings anchored directly to `public."user"`
CREATE OR REPLACE FUNCTION public.get_puskesmas_mqtt_config(
  p_user_id uuid,
  p_device_id text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_user jsonb;
  v_detail jsonb;
  v_device community_health_center.vitascale_iot_devices%ROWTYPE;
  v_has_device boolean := false;
  v_default_code text;
BEGIN
  IF p_user_id IS NULL THEN
    RETURN NULL;
  END IF;

  SELECT to_jsonb(u) - 'password' - 'password_hash' - 'two_factor_secret' - 'two_factor_recovery_codes'
    INTO v_user
  FROM public."user" u
  WHERE u.id = p_user_id
    AND lower(COALESCE(u.role, '')) IN (
      'puskesmas',
      'ponkesdes',
      'public_health_center',
      'village_clinic',
      'admin'
    )
  LIMIT 1;

  IF v_user IS NULL THEN
    RETURN NULL;
  END IF;

  IF to_regclass('public.user_detail_public_health_center') IS NOT NULL THEN
    EXECUTE 'SELECT to_jsonb(d) FROM public.user_detail_public_health_center d WHERE d.id = $1 LIMIT 1'
      INTO v_detail
      USING p_user_id;
  END IF;

  v_default_code := COALESCE(
    NULLIF(TRIM(COALESCE(v_detail->>'facility_code', '')), ''),
    'PUSKESMAS-001'
  );

  SELECT d.*
    INTO v_device
  FROM community_health_center.vitascale_iot_devices d
  WHERE d.facility_id = p_user_id
  ORDER BY
    CASE
      WHEN NULLIF(TRIM(COALESCE(p_device_id, '')), '') IS NOT NULL
        AND lower(d.device_id) = lower(TRIM(p_device_id))
      THEN 0
      ELSE 1
    END,
    d.updated_at DESC
  LIMIT 1;

  v_has_device := FOUND;

  RETURN jsonb_build_object(
    'facility_id', p_user_id,
    'user_name', COALESCE(v_user->>'name', ''),
    'user_role', COALESCE(v_user->>'role', 'puskesmas'),
    'facility_name', COALESCE(
      NULLIF(v_detail->>'facility_name', ''),
      NULLIF(v_detail->>'nama_faskes', ''),
      v_user->>'name',
      'Puskesmas'
    ),
    'faskes_code', CASE WHEN v_has_device THEN v_device.faskes_code ELSE v_default_code END,
    'device_id', CASE WHEN v_has_device THEN v_device.device_id ELSE COALESCE(NULLIF(TRIM(COALESCE(p_device_id, '')), ''), 'timbangan-01') END,
    'broker_host', CASE WHEN v_has_device THEN v_device.broker_host ELSE 'broker.emqx.io' END,
    'broker_port', CASE WHEN v_has_device THEN v_device.broker_port ELSE 8084 END,
    'ws_path', CASE WHEN v_has_device THEN v_device.ws_path ELSE '/mqtt' END,
    'cloud_gateway_url', CASE WHEN v_has_device THEN v_device.cloud_gateway_url ELSE 'https://mapotechiotmqtt.vercel.app' END,
    'tripod_height_cm', CASE WHEN v_has_device THEN v_device.tripod_height_cm ELSE 200.0 END,
    'cal_factor', CASE WHEN v_has_device THEN v_device.cal_factor ELSE 420.0 END,
    'use_wildcard', CASE WHEN v_has_device THEN v_device.use_wildcard ELSE true END,
    'active_wifi_ssid', CASE WHEN v_has_device THEN v_device.active_wifi_ssid ELSE NULL END,
    'last_rssi_dbm', CASE WHEN v_has_device THEN v_device.last_rssi_dbm ELSE NULL END,
    'last_status', CASE WHEN v_has_device THEN v_device.last_status ELSE 'offline' END,
    'last_seen_at', CASE WHEN v_has_device THEN v_device.last_seen_at ELSE NULL END,
    'updated_at', CASE WHEN v_has_device THEN v_device.updated_at ELSE NULL END,
    'has_saved_config', v_has_device
  );
END;
$$;

REVOKE ALL ON FUNCTION public.get_puskesmas_mqtt_config(uuid, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_puskesmas_mqtt_config(uuid, text) TO anon, authenticated, service_role;

-- RPC: Save/Upsert Puskesmas MQTT settings anchored directly to `public."user"`
CREATE OR REPLACE FUNCTION public.save_puskesmas_mqtt_config(
  p_user_id uuid,
  p_faskes_code text DEFAULT 'PUSKESMAS-001',
  p_device_id text DEFAULT 'timbangan-01',
  p_broker_host text DEFAULT 'broker.emqx.io',
  p_broker_port integer DEFAULT 8084,
  p_ws_path text DEFAULT '/mqtt',
  p_cloud_gateway_url text DEFAULT 'https://mapotechiotmqtt.vercel.app',
  p_tripod_height_cm numeric DEFAULT 200.0,
  p_use_wildcard boolean DEFAULT true,
  p_active_wifi_ssid text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_code text := COALESCE(NULLIF(TRIM(p_faskes_code), ''), 'PUSKESMAS-001');
  v_device text := COALESCE(NULLIF(TRIM(p_device_id), ''), 'timbangan-01');
  v_broker text := COALESCE(NULLIF(TRIM(p_broker_host), ''), 'broker.emqx.io');
  v_port integer := CASE WHEN COALESCE(p_broker_port, 0) > 0 THEN p_broker_port ELSE 8084 END;
  v_ws_path text := COALESCE(NULLIF(TRIM(p_ws_path), ''), '/mqtt');
  v_gateway text := COALESCE(NULLIF(TRIM(p_cloud_gateway_url), ''), 'https://mapotechiotmqtt.vercel.app');
  v_pole numeric := CASE WHEN COALESCE(p_tripod_height_cm, 0) > 0 THEN p_tripod_height_cm ELSE 200.0 END;
  v_existing_id uuid;
  v_saved community_health_center.vitascale_iot_devices%ROWTYPE;
BEGIN
  IF NOT private.is_valid_public_health_center_user(p_user_id) THEN
    RAISE EXCEPTION 'Unauthorized: facility_id % bukan user puskesmas/ponkesdes yang valid di public.user', p_user_id;
  END IF;

  SELECT d.id
    INTO v_existing_id
  FROM community_health_center.vitascale_iot_devices d
  WHERE d.facility_id = p_user_id
    AND lower(d.device_id) = lower(v_device)
  ORDER BY d.updated_at DESC
  LIMIT 1;

  IF v_existing_id IS NOT NULL THEN
    IF EXISTS (
      SELECT 1 FROM community_health_center.vitascale_iot_devices d
      WHERE d.faskes_code = v_code
        AND d.device_id = v_device
        AND d.id <> v_existing_id
        AND d.facility_id IS NOT NULL
        AND d.facility_id <> p_user_id
    ) THEN
      RAISE EXCEPTION 'Device (%, %) sudah terdaftar pada faskes lain.', v_code, v_device;
    END IF;

    UPDATE community_health_center.vitascale_iot_devices
       SET faskes_code = v_code,
           device_id = v_device,
           broker_host = v_broker,
           broker_port = v_port,
           ws_path = v_ws_path,
           cloud_gateway_url = v_gateway,
           tripod_height_cm = v_pole,
           use_wildcard = COALESCE(p_use_wildcard, true),
           active_wifi_ssid = COALESCE(NULLIF(TRIM(p_active_wifi_ssid), ''), active_wifi_ssid),
           updated_at = NOW()
     WHERE id = v_existing_id
     RETURNING * INTO v_saved;
  ELSE
    IF EXISTS (
      SELECT 1 FROM community_health_center.vitascale_iot_devices d
      WHERE d.faskes_code = v_code
        AND d.device_id = v_device
        AND d.facility_id IS NOT NULL
        AND d.facility_id <> p_user_id
    ) THEN
      RAISE EXCEPTION 'Device (%, %) sudah terdaftar pada faskes lain.', v_code, v_device;
    END IF;

    INSERT INTO community_health_center.vitascale_iot_devices (
      facility_id,
      faskes_code,
      device_id,
      broker_host,
      broker_port,
      ws_path,
      cloud_gateway_url,
      tripod_height_cm,
      use_wildcard,
      active_wifi_ssid,
      updated_at
    )
    VALUES (
      p_user_id,
      v_code,
      v_device,
      v_broker,
      v_port,
      v_ws_path,
      v_gateway,
      v_pole,
      COALESCE(p_use_wildcard, true),
      NULLIF(TRIM(p_active_wifi_ssid), ''),
      NOW()
    )
    ON CONFLICT (faskes_code, device_id) DO UPDATE
      SET facility_id = EXCLUDED.facility_id,
          broker_host = EXCLUDED.broker_host,
          broker_port = EXCLUDED.broker_port,
          ws_path = EXCLUDED.ws_path,
          cloud_gateway_url = EXCLUDED.cloud_gateway_url,
          tripod_height_cm = EXCLUDED.tripod_height_cm,
          use_wildcard = EXCLUDED.use_wildcard,
          active_wifi_ssid = COALESCE(EXCLUDED.active_wifi_ssid, community_health_center.vitascale_iot_devices.active_wifi_ssid),
          updated_at = NOW()
    RETURNING * INTO v_saved;
  END IF;

  RETURN to_jsonb(v_saved);
END;
$$;

REVOKE ALL ON FUNCTION public.save_puskesmas_mqtt_config(uuid, text, text, text, integer, text, text, numeric, boolean, text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.save_puskesmas_mqtt_config(uuid, text, text, text, integer, text, text, numeric, boolean, text) TO anon, authenticated, service_role;

-- ============================================================================
-- PART 3: MEDICAL LETTER QR VERIFICATION RPC & RLS (SURAT RUJUKAN / SEHAT / SAKIT)
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_medical_letter_verification(
  p_encounter_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_ce jsonb;
  v_q jsonb;
  v_vitals jsonb;
  v_anamnesis jsonb;
  v_diags jsonb := '[]'::jsonb;
  v_patient_user jsonb;
  v_guest jsonb;
  v_doc_user jsonb;
  v_doc_detail jsonb;
  v_doc_schedules jsonb := '[]'::jsonb;
  v_queue_id uuid;
  v_doctor_id uuid;
  v_patient_id uuid;
  v_guest_id uuid;
  v_raw_nik text;
  v_masked_nik text;
BEGIN
  IF p_encounter_id IS NULL THEN
    RETURN NULL;
  END IF;

  SELECT to_jsonb(ce)
    INTO v_ce
  FROM private_doctor.clinical_encounters ce
  WHERE ce.id = p_encounter_id
    AND (
      COALESCE(ce.is_rujukan, false) = true
      OR NULLIF(TRIM(COALESCE(ce.surat_keterangan_type, '')), '') IS NOT NULL
    )
  LIMIT 1;

  IF v_ce IS NULL THEN
    RETURN NULL;
  END IF;

  IF NULLIF(v_ce->>'id_queue', '') IS NOT NULL THEN
    v_queue_id := (v_ce->>'id_queue')::uuid;
    SELECT to_jsonb(q)
      INTO v_q
    FROM private_doctor.queue q
    WHERE q.id = v_queue_id
    LIMIT 1;
  END IF;

  SELECT to_jsonb(vs)
    INTO v_vitals
  FROM private_doctor.vital_signs vs
  WHERE vs.id_clinical_ecounter = p_encounter_id
  LIMIT 1;

  SELECT to_jsonb(an)
    INTO v_anamnesis
  FROM private_doctor.anamnesis_ecounter an
  WHERE an.id_clinical_ecounter = p_encounter_id
  LIMIT 1;

  SELECT COALESCE(jsonb_agg(to_jsonb(dx)), '[]'::jsonb)
    INTO v_diags
  FROM private_doctor.icdx_ecounter dx
  WHERE dx.id_clinical_ecounters = p_encounter_id;

  IF NULLIF(v_q->>'id_doctor', '') IS NOT NULL THEN
    v_doctor_id := (v_q->>'id_doctor')::uuid;

    SELECT jsonb_build_object(
      'id', u.id,
      'name', u.name,
      'avatar_url', u.avatar_url,
      'phone_number', u.phone_number,
      'address', u.address,
      'province', u.province,
      'district', u.district,
      'sub_district', u.sub_district,
      'village', u.village
    )
      INTO v_doc_user
    FROM public."user" u
    WHERE u.id = v_doctor_id
    LIMIT 1;

    IF to_regclass('public.user_detail_doctor') IS NOT NULL THEN
      EXECUTE 'SELECT jsonb_build_object(
        ''profession'', udd.profession,
        ''nama_faskes'', udd.nama_faskes,
        ''whatsapp_number'', udd.whatsapp_number,
        ''about'', udd.about,
        ''google_maps_link'', udd.google_maps_link,
        ''latitude'', udd.latitude,
        ''longitude'', udd.longitude,
        ''qr_token'', udd.qr_token,
        ''practice_licenses'', udd.practice_licenses
      ) FROM public.user_detail_doctor udd WHERE udd.id = $1 LIMIT 1'
        INTO v_doc_detail
        USING v_doctor_id;
    END IF;

    IF to_regclass('public.doctor_schedules') IS NOT NULL THEN
      EXECUTE 'SELECT COALESCE(jsonb_agg(jsonb_build_object(
        ''id'', ds.id,
        ''day'', ds.day,
        ''open_time'', ds.open_time,
        ''close_time'', ds.close_time,
        ''is_off'', ds.is_off
      )), ''[]''::jsonb) FROM public.doctor_schedules ds WHERE ds.id_doctor = $1'
        INTO v_doc_schedules
        USING v_doctor_id;
    END IF;
  END IF;

  IF NULLIF(v_q->>'id_patient', '') IS NOT NULL THEN
    v_patient_id := (v_q->>'id_patient')::uuid;
    SELECT jsonb_build_object(
      'id', u.id,
      'name', u.name,
      'nik', u.nik,
      'gender', u.gender,
      'birth_date', u.birth_date,
      'birth_place', u.birth_place,
      'address', u.address
    )
      INTO v_patient_user
    FROM public."user" u
    WHERE u.id = v_patient_id
    LIMIT 1;
  ELSIF NULLIF(v_q->>'id_guest_patient', '') IS NOT NULL THEN
    v_guest_id := (v_q->>'id_guest_patient')::uuid;
    SELECT jsonb_build_object(
      'id', gp.id,
      'name', gp.name,
      'nik', gp.nik,
      'gender', gp.gender,
      'birth_date', gp.birth_date,
      'address', gp.address
    )
      INTO v_guest
    FROM private_doctor.guest_patients gp
    WHERE gp.id = v_guest_id
    LIMIT 1;
  END IF;

  v_raw_nik := COALESCE(v_patient_user->>'nik', v_guest->>'nik', '');
  IF length(v_raw_nik) >= 10 THEN
    v_masked_nik := left(v_raw_nik, 6) || repeat('*', greatest(length(v_raw_nik) - 10, 4)) || right(v_raw_nik, 4);
  ELSIF length(v_raw_nik) > 0 THEN
    v_masked_nik := left(v_raw_nik, 2) || repeat('*', greatest(length(v_raw_nik) - 2, 2));
  ELSE
    v_masked_nik := '-';
  END IF;

  RETURN jsonb_build_object(
    'encounter', v_ce,
    'queue', COALESCE(v_q, '{}'::jsonb),
    'vitals', v_vitals,
    'anamnesis', v_anamnesis,
    'diagnoses', COALESCE(v_diags, '[]'::jsonb),
    'patient', jsonb_build_object(
      'id', COALESCE(v_patient_user->>'id', v_guest->>'id', v_q->>'id_patient', v_q->>'id_guest_patient', '-'),
      'name', COALESCE(v_patient_user->>'name', v_guest->>'name', 'Pasien'),
      'nik_masked', v_masked_nik,
      'gender', COALESCE(v_patient_user->>'gender', v_guest->>'gender', '-'),
      'birth_date', COALESCE(v_patient_user->>'birth_date', v_guest->>'birth_date', ''),
      'birth_place', COALESCE(v_patient_user->>'birth_place', ''),
      'address', COALESCE(v_patient_user->>'address', v_guest->>'address', '-')
    ),
    'doctor', COALESCE(v_doc_detail, '{}'::jsonb) || jsonb_build_object(
      'id', COALESCE(v_doctor_id::text, v_doc_user->>'id', ''),
      'name', COALESCE(v_doc_user->>'name', 'Dokter'),
      'avatar_url', v_doc_user->>'avatar_url',
      'profession', COALESCE(NULLIF(v_doc_detail->>'profession', ''), 'Dokter Praktik Mandiri'),
      'nama_faskes', COALESCE(NULLIF(v_doc_detail->>'nama_faskes', ''), 'Praktik Dokter Mandiri'),
      'whatsapp_number', COALESCE(NULLIF(v_doc_detail->>'whatsapp_number', ''), v_doc_user->>'phone_number', ''),
      'address', COALESCE(v_doc_user->>'address', ''),
      'province', COALESCE(v_doc_user->>'province', ''),
      'district', COALESCE(v_doc_user->>'district', ''),
      'sub_district', COALESCE(v_doc_user->>'sub_district', ''),
      'village', COALESCE(v_doc_user->>'village', '')
    ),
    'doctor_schedules', COALESCE(v_doc_schedules, '[]'::jsonb)
  );
END;
$$;

REVOKE ALL ON FUNCTION public.get_medical_letter_verification(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_medical_letter_verification(uuid) TO anon, authenticated, service_role;

-- Performance indexes on FK/RLS columns
CREATE INDEX IF NOT EXISTS idx_queue_id_doctor ON private_doctor.queue(id_doctor);
CREATE INDEX IF NOT EXISTS idx_queue_id_patient ON private_doctor.queue(id_patient);
CREATE INDEX IF NOT EXISTS idx_queue_id_guest_patient ON private_doctor.queue(id_guest_patient);
CREATE INDEX IF NOT EXISTS idx_clinical_encounters_id_queue ON private_doctor.clinical_encounters(id_queue);
CREATE INDEX IF NOT EXISTS idx_vital_signs_id_clinical_ecounter ON private_doctor.vital_signs(id_clinical_ecounter);
CREATE INDEX IF NOT EXISTS idx_anamnesis_id_clinical_ecounter ON private_doctor.anamnesis_ecounter(id_clinical_ecounter);
CREATE INDEX IF NOT EXISTS idx_icdx_id_clinical_ecounters ON private_doctor.icdx_ecounter(id_clinical_ecounters);
CREATE INDEX IF NOT EXISTS idx_guest_patients_id_doctor ON private_doctor.guest_patients(id_doctor);
CREATE INDEX IF NOT EXISTS idx_doctor_schedules_id_doctor ON public.doctor_schedules(id_doctor);

-- Scoped RLS on `private_doctor.*` (clean per-operation policies, no overlapping SELECT/ALL)
ALTER TABLE private_doctor.queue ENABLE ROW LEVEL SECURITY;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE private_doctor.queue TO anon, authenticated, service_role;

DROP POLICY IF EXISTS "queue_user_scoped_select" ON private_doctor.queue;
DROP POLICY IF EXISTS "queue_user_scoped_insert" ON private_doctor.queue;
DROP POLICY IF EXISTS "queue_user_scoped_update" ON private_doctor.queue;
DROP POLICY IF EXISTS "queue_user_scoped_delete" ON private_doctor.queue;

CREATE POLICY "queue_user_scoped_select"
  ON private_doctor.queue
  FOR SELECT
  TO anon, authenticated
  USING (
    (SELECT private.is_valid_doctor_user(id_doctor))
    OR (SELECT private.is_existing_public_user(id_patient))
  );

CREATE POLICY "queue_user_scoped_insert"
  ON private_doctor.queue
  FOR INSERT
  TO anon, authenticated
  WITH CHECK ((SELECT private.is_valid_doctor_user(id_doctor)));

CREATE POLICY "queue_user_scoped_update"
  ON private_doctor.queue
  FOR UPDATE
  TO anon, authenticated
  USING (
    (SELECT private.is_valid_doctor_user(id_doctor))
    OR (SELECT private.is_existing_public_user(id_patient))
  )
  WITH CHECK ((SELECT private.is_valid_doctor_user(id_doctor)));

CREATE POLICY "queue_user_scoped_delete"
  ON private_doctor.queue
  FOR DELETE
  TO anon, authenticated
  USING ((SELECT private.is_valid_doctor_user(id_doctor)));

ALTER TABLE private_doctor.clinical_encounters ENABLE ROW LEVEL SECURITY;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE private_doctor.clinical_encounters TO anon, authenticated, service_role;

DROP POLICY IF EXISTS "clinical_encounters_letter_and_doctor_select" ON private_doctor.clinical_encounters;
DROP POLICY IF EXISTS "clinical_encounters_doctor_insert" ON private_doctor.clinical_encounters;
DROP POLICY IF EXISTS "clinical_encounters_doctor_update" ON private_doctor.clinical_encounters;
DROP POLICY IF EXISTS "clinical_encounters_doctor_delete" ON private_doctor.clinical_encounters;

CREATE POLICY "clinical_encounters_letter_and_doctor_select"
  ON private_doctor.clinical_encounters
  FOR SELECT
  TO anon, authenticated
  USING (
    COALESCE(is_rujukan, false) = true
    OR NULLIF(TRIM(COALESCE(surat_keterangan_type, '')), '') IS NOT NULL
    OR EXISTS (
      SELECT 1
      FROM private_doctor.queue q
      WHERE q.id = clinical_encounters.id_queue
        AND (
          (SELECT private.is_valid_doctor_user(q.id_doctor))
          OR (SELECT private.is_existing_public_user(q.id_patient))
        )
    )
  );

CREATE POLICY "clinical_encounters_doctor_insert"
  ON private_doctor.clinical_encounters
  FOR INSERT
  TO anon, authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM private_doctor.queue q
      WHERE q.id = clinical_encounters.id_queue
        AND (SELECT private.is_valid_doctor_user(q.id_doctor))
    )
  );

CREATE POLICY "clinical_encounters_doctor_update"
  ON private_doctor.clinical_encounters
  FOR UPDATE
  TO anon, authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM private_doctor.queue q
      WHERE q.id = clinical_encounters.id_queue
        AND (SELECT private.is_valid_doctor_user(q.id_doctor))
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM private_doctor.queue q
      WHERE q.id = clinical_encounters.id_queue
        AND (SELECT private.is_valid_doctor_user(q.id_doctor))
    )
  );

CREATE POLICY "clinical_encounters_doctor_delete"
  ON private_doctor.clinical_encounters
  FOR DELETE
  TO anon, authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM private_doctor.queue q
      WHERE q.id = clinical_encounters.id_queue
        AND (SELECT private.is_valid_doctor_user(q.id_doctor))
    )
  );

-- vital_signs
ALTER TABLE private_doctor.vital_signs ENABLE ROW LEVEL SECURITY;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE private_doctor.vital_signs TO anon, authenticated, service_role;

DROP POLICY IF EXISTS "vital_signs_encounter_select" ON private_doctor.vital_signs;
DROP POLICY IF EXISTS "vital_signs_doctor_insert" ON private_doctor.vital_signs;
DROP POLICY IF EXISTS "vital_signs_doctor_update" ON private_doctor.vital_signs;
DROP POLICY IF EXISTS "vital_signs_doctor_delete" ON private_doctor.vital_signs;

CREATE POLICY "vital_signs_encounter_select"
  ON private_doctor.vital_signs
  FOR SELECT
  TO anon, authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM private_doctor.clinical_encounters ce
      WHERE ce.id = vital_signs.id_clinical_ecounter
    )
  );

CREATE POLICY "vital_signs_doctor_insert"
  ON private_doctor.vital_signs
  FOR INSERT
  TO anon, authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM private_doctor.clinical_encounters ce
      JOIN private_doctor.queue q ON q.id = ce.id_queue
      WHERE ce.id = vital_signs.id_clinical_ecounter
        AND (SELECT private.is_valid_doctor_user(q.id_doctor))
    )
  );

CREATE POLICY "vital_signs_doctor_update"
  ON private_doctor.vital_signs
  FOR UPDATE
  TO anon, authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM private_doctor.clinical_encounters ce
      JOIN private_doctor.queue q ON q.id = ce.id_queue
      WHERE ce.id = vital_signs.id_clinical_ecounter
        AND (SELECT private.is_valid_doctor_user(q.id_doctor))
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM private_doctor.clinical_encounters ce
      JOIN private_doctor.queue q ON q.id = ce.id_queue
      WHERE ce.id = vital_signs.id_clinical_ecounter
        AND (SELECT private.is_valid_doctor_user(q.id_doctor))
    )
  );

CREATE POLICY "vital_signs_doctor_delete"
  ON private_doctor.vital_signs
  FOR DELETE
  TO anon, authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM private_doctor.clinical_encounters ce
      JOIN private_doctor.queue q ON q.id = ce.id_queue
      WHERE ce.id = vital_signs.id_clinical_ecounter
        AND (SELECT private.is_valid_doctor_user(q.id_doctor))
    )
  );

-- anamnesis_ecounter
ALTER TABLE private_doctor.anamnesis_ecounter ENABLE ROW LEVEL SECURITY;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE private_doctor.anamnesis_ecounter TO anon, authenticated, service_role;

DROP POLICY IF EXISTS "anamnesis_encounter_select" ON private_doctor.anamnesis_ecounter;
DROP POLICY IF EXISTS "anamnesis_doctor_insert" ON private_doctor.anamnesis_ecounter;
DROP POLICY IF EXISTS "anamnesis_doctor_update" ON private_doctor.anamnesis_ecounter;
DROP POLICY IF EXISTS "anamnesis_doctor_delete" ON private_doctor.anamnesis_ecounter;

CREATE POLICY "anamnesis_encounter_select"
  ON private_doctor.anamnesis_ecounter
  FOR SELECT
  TO anon, authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM private_doctor.clinical_encounters ce
      WHERE ce.id = anamnesis_ecounter.id_clinical_ecounter
    )
  );

CREATE POLICY "anamnesis_doctor_insert"
  ON private_doctor.anamnesis_ecounter
  FOR INSERT
  TO anon, authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM private_doctor.clinical_encounters ce
      JOIN private_doctor.queue q ON q.id = ce.id_queue
      WHERE ce.id = anamnesis_ecounter.id_clinical_ecounter
        AND (SELECT private.is_valid_doctor_user(q.id_doctor))
    )
  );

CREATE POLICY "anamnesis_doctor_update"
  ON private_doctor.anamnesis_ecounter
  FOR UPDATE
  TO anon, authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM private_doctor.clinical_encounters ce
      JOIN private_doctor.queue q ON q.id = ce.id_queue
      WHERE ce.id = anamnesis_ecounter.id_clinical_ecounter
        AND (SELECT private.is_valid_doctor_user(q.id_doctor))
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM private_doctor.clinical_encounters ce
      JOIN private_doctor.queue q ON q.id = ce.id_queue
      WHERE ce.id = anamnesis_ecounter.id_clinical_ecounter
        AND (SELECT private.is_valid_doctor_user(q.id_doctor))
    )
  );

CREATE POLICY "anamnesis_doctor_delete"
  ON private_doctor.anamnesis_ecounter
  FOR DELETE
  TO anon, authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM private_doctor.clinical_encounters ce
      JOIN private_doctor.queue q ON q.id = ce.id_queue
      WHERE ce.id = anamnesis_ecounter.id_clinical_ecounter
        AND (SELECT private.is_valid_doctor_user(q.id_doctor))
    )
  );

-- icdx_ecounter
ALTER TABLE private_doctor.icdx_ecounter ENABLE ROW LEVEL SECURITY;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE private_doctor.icdx_ecounter TO anon, authenticated, service_role;

DROP POLICY IF EXISTS "icdx_encounter_select" ON private_doctor.icdx_ecounter;
DROP POLICY IF EXISTS "icdx_doctor_insert" ON private_doctor.icdx_ecounter;
DROP POLICY IF EXISTS "icdx_doctor_update" ON private_doctor.icdx_ecounter;
DROP POLICY IF EXISTS "icdx_doctor_delete" ON private_doctor.icdx_ecounter;

CREATE POLICY "icdx_encounter_select"
  ON private_doctor.icdx_ecounter
  FOR SELECT
  TO anon, authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM private_doctor.clinical_encounters ce
      WHERE ce.id = icdx_ecounter.id_clinical_ecounters
    )
  );

CREATE POLICY "icdx_doctor_insert"
  ON private_doctor.icdx_ecounter
  FOR INSERT
  TO anon, authenticated
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM private_doctor.clinical_encounters ce
      JOIN private_doctor.queue q ON q.id = ce.id_queue
      WHERE ce.id = icdx_ecounter.id_clinical_ecounters
        AND (SELECT private.is_valid_doctor_user(q.id_doctor))
    )
  );

CREATE POLICY "icdx_doctor_update"
  ON private_doctor.icdx_ecounter
  FOR UPDATE
  TO anon, authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM private_doctor.clinical_encounters ce
      JOIN private_doctor.queue q ON q.id = ce.id_queue
      WHERE ce.id = icdx_ecounter.id_clinical_ecounters
        AND (SELECT private.is_valid_doctor_user(q.id_doctor))
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM private_doctor.clinical_encounters ce
      JOIN private_doctor.queue q ON q.id = ce.id_queue
      WHERE ce.id = icdx_ecounter.id_clinical_ecounters
        AND (SELECT private.is_valid_doctor_user(q.id_doctor))
    )
  );

CREATE POLICY "icdx_doctor_delete"
  ON private_doctor.icdx_ecounter
  FOR DELETE
  TO anon, authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM private_doctor.clinical_encounters ce
      JOIN private_doctor.queue q ON q.id = ce.id_queue
      WHERE ce.id = icdx_ecounter.id_clinical_ecounters
        AND (SELECT private.is_valid_doctor_user(q.id_doctor))
    )
  );

-- guest_patients (replace old authenticated-only unindexed auth.uid() policies cleanly)
ALTER TABLE private_doctor.guest_patients ENABLE ROW LEVEL SECURITY;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE private_doctor.guest_patients TO anon, authenticated, service_role;

DROP POLICY IF EXISTS "Allow doctors to read their guest patients" ON private_doctor.guest_patients;
DROP POLICY IF EXISTS "Allow doctors to insert their guest patients" ON private_doctor.guest_patients;
DROP POLICY IF EXISTS "Allow doctors to update their guest patients" ON private_doctor.guest_patients;
DROP POLICY IF EXISTS "guest_patients_queue_select" ON private_doctor.guest_patients;
DROP POLICY IF EXISTS "guest_patients_doctor_insert" ON private_doctor.guest_patients;
DROP POLICY IF EXISTS "guest_patients_doctor_update" ON private_doctor.guest_patients;

CREATE POLICY "guest_patients_queue_select"
  ON private_doctor.guest_patients
  FOR SELECT
  TO anon, authenticated
  USING (
    (SELECT private.is_valid_doctor_user(id_doctor))
    OR EXISTS (
      SELECT 1
      FROM private_doctor.queue q
      WHERE q.id_guest_patient = guest_patients.id
    )
  );

CREATE POLICY "guest_patients_doctor_insert"
  ON private_doctor.guest_patients
  FOR INSERT
  TO anon, authenticated
  WITH CHECK ((SELECT private.is_valid_doctor_user(id_doctor)));

CREATE POLICY "guest_patients_doctor_update"
  ON private_doctor.guest_patients
  FOR UPDATE
  TO anon, authenticated
  USING ((SELECT private.is_valid_doctor_user(id_doctor)))
  WITH CHECK ((SELECT private.is_valid_doctor_user(id_doctor)));

-- Clean up duplicate SELECT policies & enforce user-anchored writes on `public.doctor_schedules` & `public.user_detail_doctor`
ALTER TABLE public.doctor_schedules ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow public read access" ON public.doctor_schedules;
DROP POLICY IF EXISTS "Allow public insert doctor schedules" ON public.doctor_schedules;
DROP POLICY IF EXISTS "Allow public update doctor schedules" ON public.doctor_schedules;
DROP POLICY IF EXISTS "Allow public delete doctor schedules" ON public.doctor_schedules;
DROP POLICY IF EXISTS "doctor_schedules_public_select" ON public.doctor_schedules;
DROP POLICY IF EXISTS "doctor_schedules_owner_insert" ON public.doctor_schedules;
DROP POLICY IF EXISTS "doctor_schedules_owner_update" ON public.doctor_schedules;
DROP POLICY IF EXISTS "doctor_schedules_owner_delete" ON public.doctor_schedules;

CREATE POLICY "doctor_schedules_public_select"
  ON public.doctor_schedules
  FOR SELECT
  TO anon, authenticated
  USING (true);

CREATE POLICY "doctor_schedules_owner_insert"
  ON public.doctor_schedules
  FOR INSERT
  TO anon, authenticated
  WITH CHECK ((SELECT private.is_valid_doctor_user(id_doctor)));

CREATE POLICY "doctor_schedules_owner_update"
  ON public.doctor_schedules
  FOR UPDATE
  TO anon, authenticated
  USING ((SELECT private.is_valid_doctor_user(id_doctor)))
  WITH CHECK ((SELECT private.is_valid_doctor_user(id_doctor)));

CREATE POLICY "doctor_schedules_owner_delete"
  ON public.doctor_schedules
  FOR DELETE
  TO anon, authenticated
  USING ((SELECT private.is_valid_doctor_user(id_doctor)));

ALTER TABLE public.user_detail_doctor ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Allow authenticated doctors to read their own detail" ON public.user_detail_doctor;
DROP POLICY IF EXISTS "Allow authenticated to read doctor details" ON public.user_detail_doctor;
DROP POLICY IF EXISTS "Allow public read doctor details" ON public.user_detail_doctor;
DROP POLICY IF EXISTS "Allow public update doctor details" ON public.user_detail_doctor;
DROP POLICY IF EXISTS "doctor_detail_public_select" ON public.user_detail_doctor;
DROP POLICY IF EXISTS "doctor_detail_owner_insert" ON public.user_detail_doctor;
DROP POLICY IF EXISTS "doctor_detail_owner_update" ON public.user_detail_doctor;

CREATE POLICY "doctor_detail_public_select"
  ON public.user_detail_doctor
  FOR SELECT
  TO anon, authenticated
  USING (true);

CREATE POLICY "doctor_detail_owner_insert"
  ON public.user_detail_doctor
  FOR INSERT
  TO anon, authenticated
  WITH CHECK ((SELECT private.is_valid_doctor_user(id)));

CREATE POLICY "doctor_detail_owner_update"
  ON public.user_detail_doctor
  FOR UPDATE
  TO anon, authenticated
  USING ((SELECT private.is_valid_doctor_user(id)))
  WITH CHECK ((SELECT private.is_valid_doctor_user(id)));
