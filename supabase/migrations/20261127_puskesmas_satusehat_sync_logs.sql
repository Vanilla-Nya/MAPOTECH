-- ==============================================================================
-- MAPOTECH SUPABASE MIGRATION: PUSKESMAS BOOKKEEPING & SATUSEHAT SYNC LOGS
-- Purpose:
--   1. Extend `public.user_detail_public_health_center` with optional SATUSEHAT
--      Location ID, Practitioner ID, and Environment fields.
--   2. Create `community_health_center.puskesmas_satusehat_sync_logs` to track
--      SATUSEHAT FHIR R4 synchronization status for Puskesmas-owned visits
--      (MomiCare ANC, VitaScale Anak, and general Puskesmas encounters) without
--      modifying immutable append-only clinical tables.
-- ==============================================================================

CREATE SCHEMA IF NOT EXISTS private;
CREATE SCHEMA IF NOT EXISTS community_health_center;

GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
GRANT USAGE ON SCHEMA private TO anon, authenticated, service_role;
GRANT USAGE ON SCHEMA community_health_center TO anon, authenticated, service_role;

-- 1. Helper RLS validator (idempotent, matches 20261126 migration)
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

REVOKE ALL ON FUNCTION private.is_valid_public_health_center_user(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION private.is_valid_public_health_center_user(uuid) TO anon, authenticated, service_role;

-- 2. Extend `public.user_detail_public_health_center` for complete Puskesmas SATUSEHAT credentials
ALTER TABLE IF EXISTS public.user_detail_public_health_center
  ADD COLUMN IF NOT EXISTS satusehat_location_id TEXT,
  ADD COLUMN IF NOT EXISTS id_satusehat TEXT,
  ADD COLUMN IF NOT EXISTS satusehat_env TEXT NOT NULL DEFAULT 'production';

-- 3. Puskesmas SATUSEHAT Sync Log Table (Owned by Puskesmas)
CREATE TABLE IF NOT EXISTS community_health_center.puskesmas_satusehat_sync_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  facility_id UUID NOT NULL REFERENCES public."user"(id) ON DELETE CASCADE,
  source_module TEXT NOT NULL CHECK (source_module IN ('momicare', 'vitascale', 'umum')),
  source_record_id TEXT NOT NULL,
  patient_id TEXT,
  patient_name TEXT NOT NULL,
  patient_nik TEXT,
  patient_type TEXT NOT NULL DEFAULT 'Umum' CHECK (patient_type IN ('BPJS', 'Umum')),
  satusehat_patient_id TEXT,
  satusehat_encounter_id TEXT,
  satusehat_resource_ids JSONB NOT NULL DEFAULT '{}'::jsonb,
  sync_status TEXT NOT NULL DEFAULT 'unsent' CHECK (sync_status IN ('unsent', 'success', 'failed')),
  last_error TEXT,
  synced_by TEXT,
  synced_at TIMESTAMPTZ,
  visit_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (facility_id, source_module, source_record_id)
);

CREATE INDEX IF NOT EXISTS idx_puskesmas_ss_logs_facility_visit
  ON community_health_center.puskesmas_satusehat_sync_logs (facility_id, visit_date DESC);

CREATE INDEX IF NOT EXISTS idx_puskesmas_ss_logs_facility_status
  ON community_health_center.puskesmas_satusehat_sync_logs (facility_id, sync_status);

CREATE INDEX IF NOT EXISTS idx_puskesmas_ss_logs_source
  ON community_health_center.puskesmas_satusehat_sync_logs (source_module, source_record_id);

-- 4. Row Level Security & Grants
ALTER TABLE community_health_center.puskesmas_satusehat_sync_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "puskesmas_ss_logs_select"
  ON community_health_center.puskesmas_satusehat_sync_logs;
DROP POLICY IF EXISTS "puskesmas_ss_logs_insert"
  ON community_health_center.puskesmas_satusehat_sync_logs;
DROP POLICY IF EXISTS "puskesmas_ss_logs_update"
  ON community_health_center.puskesmas_satusehat_sync_logs;
DROP POLICY IF EXISTS "puskesmas_ss_logs_delete"
  ON community_health_center.puskesmas_satusehat_sync_logs;

CREATE POLICY "puskesmas_ss_logs_select"
  ON community_health_center.puskesmas_satusehat_sync_logs
  FOR SELECT
  TO anon, authenticated
  USING ((SELECT private.is_valid_public_health_center_user(facility_id)));

CREATE POLICY "puskesmas_ss_logs_insert"
  ON community_health_center.puskesmas_satusehat_sync_logs
  FOR INSERT
  TO anon, authenticated
  WITH CHECK ((SELECT private.is_valid_public_health_center_user(facility_id)));

CREATE POLICY "puskesmas_ss_logs_update"
  ON community_health_center.puskesmas_satusehat_sync_logs
  FOR UPDATE
  TO anon, authenticated
  USING ((SELECT private.is_valid_public_health_center_user(facility_id)))
  WITH CHECK ((SELECT private.is_valid_public_health_center_user(facility_id)));

CREATE POLICY "puskesmas_ss_logs_delete"
  ON community_health_center.puskesmas_satusehat_sync_logs
  FOR DELETE
  TO anon, authenticated
  USING ((SELECT private.is_valid_public_health_center_user(facility_id)));

GRANT SELECT, INSERT, UPDATE, DELETE
  ON TABLE community_health_center.puskesmas_satusehat_sync_logs
  TO anon, authenticated, service_role;
