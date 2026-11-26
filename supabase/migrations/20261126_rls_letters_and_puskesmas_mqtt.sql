-- ============================================================================
-- MIGRATION: 20261126_rls_letters_and_puskesmas_mqtt.sql
-- Purpose:
--   1. Public Health Center (Puskesmas/Ponkesdes) MQTT & IoT device settings
--      with RLS & RPCs anchored directly to `public."user"` (`id`, `role`).
--   2. Medical Letter (Surat Rujukan, Surat Keterangan Sehat, Surat Keterangan
--      Sakit) QR Verification SECURITY DEFINER RPC (`get_medical_letter_verification`)
--      with masked NIK & safe doctor public profile + scoped RLS policies on
--      `private_doctor.*` and `public` doctor tables.
--
-- Auth Note:
--   MAPOTECH currently authenticates users via `public."user"` + client BCrypt
--   using the Supabase `anon` key (`auth.uid()` is NULL unless Supabase Auth is
--   active). Policies below therefore validate membership directly against
--   `public."user"` while staying forward-compatible with `auth.uid()`.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 0. SCHEMA USAGE GRANTS
-- ----------------------------------------------------------------------------
CREATE SCHEMA IF NOT EXISTS community_health_center;
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
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
-- PART 1: PUSKESMAS / PUBLIC HEALTH CENTER MQTT SETTINGS (ANCHORED TO public.user)
-- ============================================================================

ALTER TABLE IF EXISTS community_health_center.vitascale_iot_devices
  ADD COLUMN IF NOT EXISTS ws_path TEXT NOT NULL DEFAULT '/mqtt',
  ADD COLUMN IF NOT EXISTS cloud_gateway_url TEXT NOT NULL DEFAULT 'https://mapotechiotmqtt.vercel.app',
  ADD COLUMN IF NOT EXISTS use_wildcard BOOLEAN NOT NULL DEFAULT true;

CREATE INDEX IF NOT EXISTS idx_vitascale_iot_devices_facility_updated
  ON community_health_center.vitascale_iot_devices(facility_id, updated_at DESC);

-- Helper: validates that `p_user_id` is a valid Puskesmas / Ponkesdes account
-- in `public."user"` (or active `auth.uid()`).
CREATE OR REPLACE FUNCTION public.is_valid_public_health_center_user(p_user_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT p_user_id IS NOT NULL
    AND (
      (auth.uid() IS NOT NULL AND auth.uid() = p_user_id)
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

REVOKE ALL ON FUNCTION public.is_valid_public_health_center_user(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_valid_public_health_center_user(uuid) TO anon, authenticated, service_role;

-- Helper: validates `p_doctor_id` is a valid Doctor / Private Practice user in `public."user"`.
CREATE OR REPLACE FUNCTION public.is_valid_doctor_user(p_doctor_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT p_doctor_id IS NOT NULL
    AND (
      (auth.uid() IS NOT NULL AND auth.uid() = p_doctor_id)
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

REVOKE ALL ON FUNCTION public.is_valid_doctor_user(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_valid_doctor_user(uuid) TO anon, authenticated, service_role;

-- Helper: validates `p_user_id` exists in `public."user"` (doctor/patient/facility).
CREATE OR REPLACE FUNCTION public.is_existing_public_user(p_user_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT p_user_id IS NOT NULL
    AND (
      (auth.uid() IS NOT NULL AND auth.uid() = p_user_id)
      OR EXISTS (SELECT 1 FROM public."user" u WHERE u.id = p_user_id)
    );
$$;

REVOKE ALL ON FUNCTION public.is_existing_public_user(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_existing_public_user(uuid) TO anon, authenticated, service_role;

-- RLS on `community_health_center.vitascale_iot_devices` & `vitascale_saved_wifi`
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
  USING (public.is_valid_public_health_center_user(facility_id));

CREATE POLICY "vitascale_iot_devices_puskesmas_insert"
  ON community_health_center.vitascale_iot_devices
  FOR INSERT
  TO anon, authenticated
  WITH CHECK (public.is_valid_public_health_center_user(facility_id));

CREATE POLICY "vitascale_iot_devices_puskesmas_update"
  ON community_health_center.vitascale_iot_devices
  FOR UPDATE
  TO anon, authenticated
  USING (public.is_valid_public_health_center_user(facility_id))
  WITH CHECK (public.is_valid_public_health_center_user(facility_id));

CREATE POLICY "vitascale_iot_devices_puskesmas_delete"
  ON community_health_center.vitascale_iot_devices
  FOR DELETE
  TO anon, authenticated
  USING (public.is_valid_public_health_center_user(facility_id));

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
  USING (public.is_valid_public_health_center_user(facility_id));

CREATE POLICY "vitascale_saved_wifi_puskesmas_insert"
  ON community_health_center.vitascale_saved_wifi
  FOR INSERT
  TO anon, authenticated
  WITH CHECK (public.is_valid_public_health_center_user(facility_id));

CREATE POLICY "vitascale_saved_wifi_puskesmas_update"
  ON community_health_center.vitascale_saved_wifi
  FOR UPDATE
  TO anon, authenticated
  USING (public.is_valid_public_health_center_user(facility_id))
  WITH CHECK (public.is_valid_public_health_center_user(facility_id));

CREATE POLICY "vitascale_saved_wifi_puskesmas_delete"
  ON community_health_center.vitascale_saved_wifi
  FOR DELETE
  TO anon, authenticated
  USING (public.is_valid_public_health_center_user(facility_id));

GRANT SELECT, INSERT, UPDATE, DELETE
  ON TABLE community_health_center.vitascale_iot_devices
  TO anon, authenticated, service_role;
GRANT SELECT, INSERT, UPDATE, DELETE
  ON TABLE community_health_center.vitascale_saved_wifi
  TO anon, authenticated, service_role;

-- RLS on `public.user_detail_public_health_center` anchored to `public."user"`
DO $$
BEGIN
  IF to_regclass('public.user_detail_public_health_center') IS NOT NULL THEN
    EXECUTE 'ALTER TABLE public.user_detail_public_health_center ENABLE ROW LEVEL SECURITY';

    EXECUTE 'DROP POLICY IF EXISTS "puskesmas_detail_public_select" ON public.user_detail_public_health_center';
    EXECUTE 'CREATE POLICY "puskesmas_detail_public_select" ON public.user_detail_public_health_center FOR SELECT TO anon, authenticated USING (true)';

    EXECUTE 'DROP POLICY IF EXISTS "puskesmas_detail_owner_insert" ON public.user_detail_public_health_center';
    EXECUTE 'CREATE POLICY "puskesmas_detail_owner_insert" ON public.user_detail_public_health_center FOR INSERT TO anon, authenticated WITH CHECK (public.is_valid_public_health_center_user(id))';

    EXECUTE 'DROP POLICY IF EXISTS "puskesmas_detail_owner_update" ON public.user_detail_public_health_center';
    EXECUTE 'CREATE POLICY "puskesmas_detail_owner_update" ON public.user_detail_public_health_center FOR UPDATE TO anon, authenticated USING (public.is_valid_public_health_center_user(id)) WITH CHECK (public.is_valid_public_health_center_user(id))';

    EXECUTE 'DROP POLICY IF EXISTS "puskesmas_detail_owner_delete" ON public.user_detail_public_health_center';
    EXECUTE 'CREATE POLICY "puskesmas_detail_owner_delete" ON public.user_detail_public_health_center FOR DELETE TO anon, authenticated USING (public.is_valid_public_health_center_user(id))';
  END IF;
END $$;

-- RPC: Fetch Puskesmas MQTT settings anchored to `public."user"`
CREATE OR REPLACE FUNCTION public.get_puskesmas_mqtt_config(
  p_user_id uuid,
  p_device_id text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, community_health_center
AS $$
DECLARE
  v_user jsonb;
  v_detail jsonb;
  v_device community_health_center.vitascale_iot_devices%ROWTYPE;
  v_has_device boolean := false;
BEGIN
  IF p_user_id IS NULL THEN
    RETURN NULL;
  END IF;

  SELECT to_jsonb(u) - 'password_hash' - 'password'
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
    'facility_name', COALESCE(NULLIF(v_detail->>'nama_faskes', ''), v_user->>'name', 'Puskesmas'),
    'faskes_code', CASE WHEN v_has_device THEN v_device.faskes_code ELSE 'PUSKESMAS-001' END,
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

-- RPC: Save/Upsert Puskesmas MQTT settings anchored to `public."user"`
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
SET search_path = public, community_health_center
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
  IF NOT public.is_valid_public_health_center_user(p_user_id) THEN
    RAISE EXCEPTION 'Unauthorized: facility_id % bukan user puskesmas/ponkesdes yang valid di public.user', p_user_id;
  END IF;

  SELECT id
    INTO v_existing_id
  FROM community_health_center.vitascale_iot_devices
  WHERE facility_id = p_user_id
    AND lower(device_id) = lower(v_device)
  ORDER BY updated_at DESC
  LIMIT 1;

  IF v_existing_id IS NOT NULL THEN
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
-- PART 2: MEDICAL LETTER QR VERIFICATION RPC & RLS (SURAT RUJUKAN / SEHAT / SAKIT)
-- ============================================================================

-- Safe public QR verification RPC (`SECURITY DEFINER`):
-- Only exposes issued letters (`is_rujukan = true` OR non-empty
-- `surat_keterangan_type`), masks patient NIK, never exposes `password_hash`,
-- and returns public doctor profile + schedules + encounter clinical hash.
CREATE OR REPLACE FUNCTION public.get_medical_letter_verification(
  p_encounter_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, private_doctor
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
      COALESCE((to_jsonb(ce)->>'is_rujukan')::boolean, false) = true
      OR NULLIF(TRIM(COALESCE(to_jsonb(ce)->>'surat_keterangan_type', '')), '') IS NOT NULL
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

    SELECT to_jsonb(u) - 'password_hash' - 'password'
      INTO v_doc_user
    FROM public."user" u
    WHERE u.id = v_doctor_id
    LIMIT 1;

    IF to_regclass('public.user_detail_doctor') IS NOT NULL THEN
      EXECUTE 'SELECT to_jsonb(udd) FROM public.user_detail_doctor udd WHERE udd.id = $1 LIMIT 1'
        INTO v_doc_detail
        USING v_doctor_id;
    END IF;

    IF to_regclass('public.doctor_schedules') IS NOT NULL THEN
      EXECUTE 'SELECT COALESCE(jsonb_agg(to_jsonb(ds)), ''[]''::jsonb) FROM public.doctor_schedules ds WHERE ds.id_doctor = $1'
        INTO v_doc_schedules
        USING v_doctor_id;
    END IF;
  END IF;

  IF NULLIF(v_q->>'id_patient', '') IS NOT NULL THEN
    v_patient_id := (v_q->>'id_patient')::uuid;
    SELECT jsonb_build_object(
      'id', u.id,
      'name', to_jsonb(u)->>'name',
      'nik', to_jsonb(u)->>'nik',
      'gender', to_jsonb(u)->>'gender',
      'birth_date', to_jsonb(u)->>'birth_date',
      'birth_place', to_jsonb(u)->>'birth_place',
      'address', to_jsonb(u)->>'address'
    )
      INTO v_patient_user
    FROM public."user" u
    WHERE u.id = v_patient_id
    LIMIT 1;
  ELSIF NULLIF(v_q->>'id_guest_patient', '') IS NOT NULL THEN
    v_guest_id := (v_q->>'id_guest_patient')::uuid;
    SELECT to_jsonb(gp)
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
      'birth_place', COALESCE(v_patient_user->>'birth_place', v_guest->>'birth_place', ''),
      'address', COALESCE(v_patient_user->>'address', v_guest->>'address', '-')
    ),
    'doctor', COALESCE(v_doc_detail, '{}'::jsonb) || jsonb_build_object(
      'id', COALESCE(v_doctor_id::text, v_doc_user->>'id', ''),
      'name', COALESCE(NULLIF(v_doc_detail->>'name', ''), v_doc_user->>'name', 'Dokter'),
      'avatar_url', COALESCE(NULLIF(v_doc_detail->>'avatar_url', ''), v_doc_user->>'avatar_url'),
      'whatsapp_number', COALESCE(NULLIF(v_doc_detail->>'whatsapp_number', ''), v_doc_user->>'phone_number', ''),
      'address', COALESCE(NULLIF(v_doc_detail->>'address', ''), v_doc_user->>'address', ''),
      'province', COALESCE(NULLIF(v_doc_detail->>'province', ''), v_doc_user->>'province', ''),
      'district', COALESCE(NULLIF(v_doc_detail->>'district', ''), v_doc_user->>'district', ''),
      'sub_district', COALESCE(NULLIF(v_doc_detail->>'sub_district', ''), v_doc_user->>'sub_district', ''),
      'village', COALESCE(NULLIF(v_doc_detail->>'village', ''), v_doc_user->>'village', '')
    ),
    'doctor_schedules', COALESCE(v_doc_schedules, '[]'::jsonb)
  );
END;
$$;

REVOKE ALL ON FUNCTION public.get_medical_letter_verification(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_medical_letter_verification(uuid) TO anon, authenticated, service_role;

-- RLS on `private_doctor.*` & `public` doctor tables
DO $$
BEGIN
  -- 1. private_doctor.queue
  IF to_regclass('private_doctor.queue') IS NOT NULL THEN
    EXECUTE 'ALTER TABLE private_doctor.queue ENABLE ROW LEVEL SECURITY';
    EXECUTE 'GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE private_doctor.queue TO anon, authenticated, service_role';

    EXECUTE 'DROP POLICY IF EXISTS "queue_user_scoped_select" ON private_doctor.queue';
    EXECUTE $p$
      CREATE POLICY "queue_user_scoped_select"
        ON private_doctor.queue
        FOR SELECT
        TO anon, authenticated
        USING (
          public.is_valid_doctor_user(id_doctor)
          OR public.is_existing_public_user(id_patient)
        )
    $p$;

    EXECUTE 'DROP POLICY IF EXISTS "queue_user_scoped_write" ON private_doctor.queue';
    EXECUTE $p$
      CREATE POLICY "queue_user_scoped_write"
        ON private_doctor.queue
        FOR ALL
        TO anon, authenticated
        USING (public.is_valid_doctor_user(id_doctor))
        WITH CHECK (public.is_valid_doctor_user(id_doctor))
    $p$;
  END IF;

  -- 2. private_doctor.clinical_encounters
  IF to_regclass('private_doctor.clinical_encounters') IS NOT NULL THEN
    EXECUTE 'ALTER TABLE private_doctor.clinical_encounters ENABLE ROW LEVEL SECURITY';
    EXECUTE 'GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE private_doctor.clinical_encounters TO anon, authenticated, service_role';

    EXECUTE 'DROP POLICY IF EXISTS "clinical_encounters_letter_and_doctor_select" ON private_doctor.clinical_encounters';
    EXECUTE $p$
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
                public.is_valid_doctor_user(q.id_doctor)
                OR public.is_existing_public_user(q.id_patient)
              )
          )
        )
    $p$;

    EXECUTE 'DROP POLICY IF EXISTS "clinical_encounters_doctor_insert" ON private_doctor.clinical_encounters';
    EXECUTE $p$
      CREATE POLICY "clinical_encounters_doctor_insert"
        ON private_doctor.clinical_encounters
        FOR INSERT
        TO anon, authenticated
        WITH CHECK (
          EXISTS (
            SELECT 1
            FROM private_doctor.queue q
            WHERE q.id = clinical_encounters.id_queue
              AND public.is_valid_doctor_user(q.id_doctor)
          )
        )
    $p$;

    EXECUTE 'DROP POLICY IF EXISTS "clinical_encounters_doctor_update" ON private_doctor.clinical_encounters';
    EXECUTE $p$
      CREATE POLICY "clinical_encounters_doctor_update"
        ON private_doctor.clinical_encounters
        FOR UPDATE
        TO anon, authenticated
        USING (
          EXISTS (
            SELECT 1
            FROM private_doctor.queue q
            WHERE q.id = clinical_encounters.id_queue
              AND public.is_valid_doctor_user(q.id_doctor)
          )
        )
        WITH CHECK (
          EXISTS (
            SELECT 1
            FROM private_doctor.queue q
            WHERE q.id = clinical_encounters.id_queue
              AND public.is_valid_doctor_user(q.id_doctor)
          )
        )
    $p$;
  END IF;

  -- 3. private_doctor.vital_signs
  IF to_regclass('private_doctor.vital_signs') IS NOT NULL THEN
    EXECUTE 'ALTER TABLE private_doctor.vital_signs ENABLE ROW LEVEL SECURITY';
    EXECUTE 'GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE private_doctor.vital_signs TO anon, authenticated, service_role';

    EXECUTE 'DROP POLICY IF EXISTS "vital_signs_encounter_select" ON private_doctor.vital_signs';
    EXECUTE $p$
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
        )
    $p$;

    EXECUTE 'DROP POLICY IF EXISTS "vital_signs_doctor_write" ON private_doctor.vital_signs';
    EXECUTE $p$
      CREATE POLICY "vital_signs_doctor_write"
        ON private_doctor.vital_signs
        FOR ALL
        TO anon, authenticated
        USING (
          EXISTS (
            SELECT 1
            FROM private_doctor.clinical_encounters ce
            JOIN private_doctor.queue q ON q.id = ce.id_queue
            WHERE ce.id = vital_signs.id_clinical_ecounter
              AND public.is_valid_doctor_user(q.id_doctor)
          )
        )
        WITH CHECK (
          EXISTS (
            SELECT 1
            FROM private_doctor.clinical_encounters ce
            JOIN private_doctor.queue q ON q.id = ce.id_queue
            WHERE ce.id = vital_signs.id_clinical_ecounter
              AND public.is_valid_doctor_user(q.id_doctor)
          )
        )
    $p$;
  END IF;

  -- 4. private_doctor.anamnesis_ecounter
  IF to_regclass('private_doctor.anamnesis_ecounter') IS NOT NULL THEN
    EXECUTE 'ALTER TABLE private_doctor.anamnesis_ecounter ENABLE ROW LEVEL SECURITY';
    EXECUTE 'GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE private_doctor.anamnesis_ecounter TO anon, authenticated, service_role';

    EXECUTE 'DROP POLICY IF EXISTS "anamnesis_encounter_select" ON private_doctor.anamnesis_ecounter';
    EXECUTE $p$
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
        )
    $p$;

    EXECUTE 'DROP POLICY IF EXISTS "anamnesis_doctor_write" ON private_doctor.anamnesis_ecounter';
    EXECUTE $p$
      CREATE POLICY "anamnesis_doctor_write"
        ON private_doctor.anamnesis_ecounter
        FOR ALL
        TO anon, authenticated
        USING (
          EXISTS (
            SELECT 1
            FROM private_doctor.clinical_encounters ce
            JOIN private_doctor.queue q ON q.id = ce.id_queue
            WHERE ce.id = anamnesis_ecounter.id_clinical_ecounter
              AND public.is_valid_doctor_user(q.id_doctor)
          )
        )
        WITH CHECK (
          EXISTS (
            SELECT 1
            FROM private_doctor.clinical_encounters ce
            JOIN private_doctor.queue q ON q.id = ce.id_queue
            WHERE ce.id = anamnesis_ecounter.id_clinical_ecounter
              AND public.is_valid_doctor_user(q.id_doctor)
          )
        )
    $p$;
  END IF;

  -- 5. private_doctor.icdx_ecounter
  IF to_regclass('private_doctor.icdx_ecounter') IS NOT NULL THEN
    EXECUTE 'ALTER TABLE private_doctor.icdx_ecounter ENABLE ROW LEVEL SECURITY';
    EXECUTE 'GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE private_doctor.icdx_ecounter TO anon, authenticated, service_role';

    EXECUTE 'DROP POLICY IF EXISTS "icdx_encounter_select" ON private_doctor.icdx_ecounter';
    EXECUTE $p$
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
        )
    $p$;

    EXECUTE 'DROP POLICY IF EXISTS "icdx_doctor_write" ON private_doctor.icdx_ecounter';
    EXECUTE $p$
      CREATE POLICY "icdx_doctor_write"
        ON private_doctor.icdx_ecounter
        FOR ALL
        TO anon, authenticated
        USING (
          EXISTS (
            SELECT 1
            FROM private_doctor.clinical_encounters ce
            JOIN private_doctor.queue q ON q.id = ce.id_queue
            WHERE ce.id = icdx_ecounter.id_clinical_ecounters
              AND public.is_valid_doctor_user(q.id_doctor)
          )
        )
        WITH CHECK (
          EXISTS (
            SELECT 1
            FROM private_doctor.clinical_encounters ce
            JOIN private_doctor.queue q ON q.id = ce.id_queue
            WHERE ce.id = icdx_ecounter.id_clinical_ecounters
              AND public.is_valid_doctor_user(q.id_doctor)
          )
        )
    $p$;
  END IF;

  -- 6. private_doctor.guest_patients
  IF to_regclass('private_doctor.guest_patients') IS NOT NULL THEN
    EXECUTE 'ALTER TABLE private_doctor.guest_patients ENABLE ROW LEVEL SECURITY';
    EXECUTE 'GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE private_doctor.guest_patients TO anon, authenticated, service_role';

    EXECUTE 'DROP POLICY IF EXISTS "guest_patients_queue_select" ON private_doctor.guest_patients';
    EXECUTE $p$
      CREATE POLICY "guest_patients_queue_select"
        ON private_doctor.guest_patients
        FOR SELECT
        TO anon, authenticated
        USING (
          EXISTS (
            SELECT 1
            FROM private_doctor.queue q
            WHERE q.id_guest_patient = guest_patients.id
          )
        )
    $p$;

    EXECUTE 'DROP POLICY IF EXISTS "guest_patients_doctor_write" ON private_doctor.guest_patients';
    EXECUTE $p$
      CREATE POLICY "guest_patients_doctor_write"
        ON private_doctor.guest_patients
        FOR INSERT
        TO anon, authenticated
        WITH CHECK (true)
    $p$;
  END IF;

  -- 7. public.user_detail_doctor & public.doctor_schedules (public doctor profile for QR verification)
  IF to_regclass('public.user_detail_doctor') IS NOT NULL THEN
    EXECUTE 'ALTER TABLE public.user_detail_doctor ENABLE ROW LEVEL SECURITY';

    EXECUTE 'DROP POLICY IF EXISTS "doctor_detail_public_select" ON public.user_detail_doctor';
    EXECUTE 'CREATE POLICY "doctor_detail_public_select" ON public.user_detail_doctor FOR SELECT TO anon, authenticated USING (true)';

    EXECUTE 'DROP POLICY IF EXISTS "doctor_detail_owner_write" ON public.user_detail_doctor';
    EXECUTE 'CREATE POLICY "doctor_detail_owner_write" ON public.user_detail_doctor FOR ALL TO anon, authenticated USING (public.is_valid_doctor_user(id)) WITH CHECK (public.is_valid_doctor_user(id))';
  END IF;

  IF to_regclass('public.doctor_schedules') IS NOT NULL THEN
    EXECUTE 'ALTER TABLE public.doctor_schedules ENABLE ROW LEVEL SECURITY';

    EXECUTE 'DROP POLICY IF EXISTS "doctor_schedules_public_select" ON public.doctor_schedules';
    EXECUTE 'CREATE POLICY "doctor_schedules_public_select" ON public.doctor_schedules FOR SELECT TO anon, authenticated USING (true)';

    EXECUTE 'DROP POLICY IF EXISTS "doctor_schedules_owner_write" ON public.doctor_schedules';
    EXECUTE 'CREATE POLICY "doctor_schedules_owner_write" ON public.doctor_schedules FOR ALL TO anon, authenticated USING (public.is_valid_doctor_user(id_doctor)) WITH CHECK (public.is_valid_doctor_user(id_doctor))';
  END IF;
END $$;
