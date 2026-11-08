-- =============================================================================
-- Migration 009: Phase 1 facility hierarchy + secure QR identifiers
-- =============================================================================
-- Purpose:
--   - support both independent parking lots and mall-style facilities
--   - track facility -> floor -> zone -> parking space hierarchy
--   - assign secure QR identifiers to facilities and spaces
--   - create booking QR pass records used for digital parking verification
--
-- This migration is additive and backwards compatible:
--   - existing parking_spaces rows are preserved
--   - legacy searches and booking flows continue to function
--   - new facility relationships are backfilled for existing data
-- =============================================================================

CREATE TYPE facility_kind AS ENUM ('independent_lot', 'shopping_mall');
CREATE TYPE facility_status AS ENUM ('active', 'inactive', 'maintenance', 'archived');
CREATE TYPE booking_pass_status AS ENUM ('active', 'expired', 'revoked', 'used');

-- ---------------------------------------------------------------------------
-- Table: public.facilities
-- Purpose: top-level facility entity for independent lots and mall properties.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.facilities (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  name TEXT NOT NULL CHECK (char_length(name) BETWEEN 3 AND 180),
  kind facility_kind NOT NULL DEFAULT 'independent_lot',
  status facility_status NOT NULL DEFAULT 'active',
  qr_code_id TEXT NOT NULL UNIQUE,
  address_line1 TEXT NOT NULL,
  address_line2 TEXT,
  city TEXT NOT NULL,
  state TEXT NOT NULL,
  country TEXT NOT NULL DEFAULT 'India',
  postal_code TEXT,
  latitude NUMERIC(10, 8) NOT NULL CHECK (latitude BETWEEN -90 AND 90),
  longitude NUMERIC(11, 8) NOT NULL CHECK (longitude BETWEEN -180 AND 180),
  is_covered BOOLEAN NOT NULL DEFAULT FALSE,
  is_gated BOOLEAN NOT NULL DEFAULT FALSE,
  has_cctv BOOLEAN NOT NULL DEFAULT FALSE,
  has_lighting BOOLEAN NOT NULL DEFAULT FALSE,
  has_ev_charging BOOLEAN NOT NULL DEFAULT FALSE,
  is_accessible BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (qr_code_id ~ '^parkopt_fac_[A-Za-z0-9_-]{12,64}$')
);

CREATE INDEX IF NOT EXISTS idx_facilities_owner_id ON public.facilities(owner_id);
CREATE INDEX IF NOT EXISTS idx_facilities_kind ON public.facilities(kind);
CREATE INDEX IF NOT EXISTS idx_facilities_status ON public.facilities(status);
CREATE INDEX IF NOT EXISTS idx_facilities_city ON public.facilities(city, status);

DROP TRIGGER IF EXISTS set_facilities_updated_at ON public.facilities;
CREATE TRIGGER set_facilities_updated_at
  BEFORE UPDATE ON public.facilities
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

ALTER TABLE public.facilities ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "facilities_select_public_active" ON public.facilities;
DROP POLICY IF EXISTS "facilities_select_owner_or_admin" ON public.facilities;
DROP POLICY IF EXISTS "facilities_insert_owner" ON public.facilities;
DROP POLICY IF EXISTS "facilities_update_owner" ON public.facilities;

CREATE POLICY "facilities_select_public_active"
  ON public.facilities
  FOR SELECT
  USING (status = 'active');

CREATE POLICY "facilities_select_owner_or_admin"
  ON public.facilities
  FOR SELECT
  USING (
    auth.uid() = owner_id
    OR EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = auth.uid() AND p.role = 'admin'
    )
  );

CREATE POLICY "facilities_insert_owner"
  ON public.facilities
  FOR INSERT
  WITH CHECK (
    auth.uid() = owner_id
    AND EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = auth.uid() AND p.role IN ('owner', 'admin')
    )
  );

CREATE POLICY "facilities_update_owner"
  ON public.facilities
  FOR UPDATE
  USING (auth.uid() = owner_id)
  WITH CHECK (auth.uid() = owner_id);

-- ---------------------------------------------------------------------------
-- Table: public.facility_floors
-- Purpose: Floors within a mall or large facility.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.facility_floors (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  facility_id UUID NOT NULL REFERENCES public.facilities(id) ON DELETE CASCADE,
  floor_number INTEGER NOT NULL CHECK (floor_number >= -5 AND floor_number <= 100),
  label TEXT NOT NULL DEFAULT 'Level',
  qr_code_id TEXT NOT NULL UNIQUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (qr_code_id ~ '^parkopt_floor_[A-Za-z0-9_-]{12,64}$')
);

CREATE INDEX IF NOT EXISTS idx_facility_floors_facility_id ON public.facility_floors(facility_id);
CREATE INDEX IF NOT EXISTS idx_facility_floors_number ON public.facility_floors(facility_id, floor_number);

-- ---------------------------------------------------------------------------
-- Table: public.facility_zones
-- Purpose: logical zones inside a floor or facility (e.g., Basement A / East Wing / Level 2).
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.facility_zones (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  facility_id UUID NOT NULL REFERENCES public.facilities(id) ON DELETE CASCADE,
  floor_id UUID REFERENCES public.facility_floors(id) ON DELETE SET NULL,
  name TEXT NOT NULL CHECK (char_length(name) BETWEEN 2 AND 90),
  qr_code_id TEXT NOT NULL UNIQUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (qr_code_id ~ '^parkopt_zone_[A-Za-z0-9_-]{12,64}$')
);

CREATE INDEX IF NOT EXISTS idx_facility_zones_facility_id ON public.facility_zones(facility_id);
CREATE INDEX IF NOT EXISTS idx_facility_zones_floor_id ON public.facility_zones(floor_id);

-- ---------------------------------------------------------------------------
-- Extend parking_spaces for facility hierarchy and secure QR IDs.
-- ---------------------------------------------------------------------------
ALTER TABLE public.parking_spaces
  ADD COLUMN IF NOT EXISTS facility_id UUID,
  ADD COLUMN IF NOT EXISTS floor_id UUID,
  ADD COLUMN IF NOT EXISTS zone_id UUID,
  ADD COLUMN IF NOT EXISTS space_label TEXT,
  ADD COLUMN IF NOT EXISTS qr_code_id TEXT,
  ADD COLUMN IF NOT EXISTS is_public BOOLEAN NOT NULL DEFAULT TRUE;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.parking_spaces'::regclass
      AND conname = 'parking_spaces_facility_fk'
  ) THEN
    ALTER TABLE public.parking_spaces DROP CONSTRAINT parking_spaces_facility_fk;
  END IF;

  IF EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.parking_spaces'::regclass
      AND conname = 'parking_spaces_floor_fk'
  ) THEN
    ALTER TABLE public.parking_spaces DROP CONSTRAINT parking_spaces_floor_fk;
  END IF;

  IF EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.parking_spaces'::regclass
      AND conname = 'parking_spaces_zone_fk'
  ) THEN
    ALTER TABLE public.parking_spaces DROP CONSTRAINT parking_spaces_zone_fk;
  END IF;
END $$;

ALTER TABLE public.parking_spaces
  ADD CONSTRAINT parking_spaces_facility_fk
  FOREIGN KEY (facility_id) REFERENCES public.facilities(id) ON DELETE RESTRICT;

ALTER TABLE public.parking_spaces
  ADD CONSTRAINT parking_spaces_floor_fk
  FOREIGN KEY (floor_id) REFERENCES public.facility_floors(id) ON DELETE SET NULL;

ALTER TABLE public.parking_spaces
  ADD CONSTRAINT parking_spaces_zone_fk
  FOREIGN KEY (zone_id) REFERENCES public.facility_zones(id) ON DELETE SET NULL;

DO $$
BEGIN
  UPDATE public.parking_spaces ps
  SET facility_id = ps.id
  WHERE ps.facility_id IS NULL;
END $$;

DO $$
BEGIN
  INSERT INTO public.facilities (
    id,
    owner_id,
    name,
    kind,
    status,
    qr_code_id,
    address_line1,
    address_line2,
    city,
    state,
    country,
    postal_code,
    latitude,
    longitude,
    is_covered,
    is_gated,
    has_cctv,
    has_lighting,
    has_ev_charging,
    is_accessible,
    created_at,
    updated_at
  )
  SELECT
    ps.id,
    ps.owner_id,
    ps.name,
    'independent_lot',
    ps.status,
    'parkopt_fac_' || substr(md5(ps.id::text || 'facility:' || ps.name), 1, 24),
    ps.address_line1,
    ps.address_line2,
    ps.city,
    ps.state,
    ps.country,
    ps.postal_code,
    ps.latitude,
    ps.longitude,
    ps.is_covered,
    ps.is_gated,
    ps.has_cctv,
    ps.has_lighting,
    ps.has_ev_charging,
    ps.is_accessible,
    ps.created_at,
    ps.updated_at
  FROM public.parking_spaces ps
  WHERE ps.facility_id = ps.id
  ON CONFLICT (id) DO NOTHING;
END $$;

DO $$
BEGIN
  UPDATE public.parking_spaces ps
  SET qr_code_id = COALESCE(ps.qr_code_id, 'parkopt_space_' || substr(md5(ps.id::text || 'space:' || ps.name), 1, 24)),
      space_label = COALESCE(ps.space_label, 'A-' || floor(random() * 900 + 100)::text),
      facility_id = COALESCE(ps.facility_id, ps.id)
  WHERE ps.qr_code_id IS NULL OR ps.facility_id IS NULL;
END $$;

-- Ensure all existing rows now have a facility and secure space QR.
ALTER TABLE public.parking_spaces
  ALTER COLUMN facility_id SET NOT NULL,
  ALTER COLUMN qr_code_id SET NOT NULL,
  ALTER COLUMN space_label SET NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS idx_parking_spaces_qr_code_id
  ON public.parking_spaces(qr_code_id);

CREATE INDEX IF NOT EXISTS idx_parking_spaces_facility_id
  ON public.parking_spaces(facility_id);

CREATE INDEX IF NOT EXISTS idx_parking_spaces_floor_id
  ON public.parking_spaces(floor_id);

CREATE INDEX IF NOT EXISTS idx_parking_spaces_zone_id
  ON public.parking_spaces(zone_id);

-- ---------------------------------------------------------------------------
-- Table: public.booking_passes
-- Purpose: stores the secure QR token used for a confirmed parking pass.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.booking_passes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id UUID NOT NULL UNIQUE REFERENCES public.bookings(id) ON DELETE CASCADE,
  token TEXT NOT NULL UNIQUE,
  issued_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expires_at TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '30 days'),
  status booking_pass_status NOT NULL DEFAULT 'active',
  verified_at TIMESTAMPTZ,
  last_verified_by UUID REFERENCES auth.users(id),
  CHECK (token ~ '^parkopt_pass_[A-Za-z0-9_-]{18,128}$'),
  CHECK (expires_at > issued_at)
);

CREATE INDEX IF NOT EXISTS idx_booking_passes_status ON public.booking_passes(status);
CREATE INDEX IF NOT EXISTS idx_booking_passes_token ON public.booking_passes(token);

-- ---------------------------------------------------------------------------
-- Utility function: resolve a secure QR reference to a facility, space, or booking pass.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.resolve_qr_reference(p_qr_code TEXT)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_code TEXT;
BEGIN
  v_code := COALESCE(p_qr_code, '');

  IF v_code = '' THEN
    RETURN jsonb_build_object('valid', false, 'error_code', 'INVALID_QR');
  END IF;

  IF v_code LIKE 'parkopt_fac_%' THEN
    RETURN (
      SELECT jsonb_build_object(
        'valid', true,
        'kind', 'facility',
        'facility_id', f.id,
        'facility_name', f.name,
        'facility_qr_code', f.qr_code_id,
        'status', f.status
      )
      FROM public.facilities f
      WHERE f.qr_code_id = v_code
      LIMIT 1
    );
  END IF;

  IF v_code LIKE 'parkopt_space_%' THEN
    RETURN (
      SELECT jsonb_build_object(
        'valid', true,
        'kind', 'space',
        'space_id', ps.id,
        'facility_id', ps.facility_id,
        'space_label', ps.space_label,
        'space_qr_code', ps.qr_code_id,
        'status', ps.status
      )
      FROM public.parking_spaces ps
      WHERE ps.qr_code_id = v_code
      LIMIT 1
    );
  END IF;

  IF v_code LIKE 'parkopt_pass_%' THEN
    RETURN (
      SELECT jsonb_build_object(
        'valid', true,
        'kind', 'booking_pass',
        'booking_id', bp.booking_id,
        'pass_token', bp.token,
        'status', bp.status,
        'expires_at', bp.expires_at
      )
      FROM public.booking_passes bp
      WHERE bp.token = v_code
      LIMIT 1
    );
  END IF;

  RETURN jsonb_build_object('valid', false, 'error_code', 'UNSUPPORTED_QR_FORMAT');
END;
$$;

-- ---------------------------------------------------------------------------
-- Function: generate_booking_pass
-- Purpose: create or fetch a secure booking QR token for a confirmed booking.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.generate_booking_pass(p_booking_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_booking RECORD;
  v_pass RECORD;
BEGIN
  SELECT * INTO v_booking
  FROM public.bookings b
  WHERE b.id = p_booking_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'BOOKING_NOT_FOUND');
  END IF;

  IF v_booking.status NOT IN ('pending', 'confirmed') THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'BOOKING_NOT_ELIGIBLE');
  END IF;

  SELECT * INTO v_pass
  FROM public.booking_passes bp
  WHERE bp.booking_id = p_booking_id
  LIMIT 1;

  IF FOUND THEN
    RETURN jsonb_build_object(
      'success', true,
      'booking_id', p_booking_id,
      'token', v_pass.token,
      'expires_at', v_pass.expires_at,
      'status', v_pass.status
    );
  END IF;

  INSERT INTO public.booking_passes (booking_id, token, expires_at)
  VALUES (
    p_booking_id,
    'parkopt_pass_' || replace(gen_random_uuid()::text, '-', ''),
    NOW() + INTERVAL '30 days'
  )
  RETURNING * INTO v_pass;

  RETURN jsonb_build_object(
    'success', true,
    'booking_id', p_booking_id,
    'token', v_pass.token,
    'expires_at', v_pass.expires_at,
    'status', v_pass.status
  );
END;
$$;

-- ---------------------------------------------------------------------------
-- Function: verify_booking_pass
-- Purpose: backend validation for a booking QR pass.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.verify_booking_pass(p_token TEXT)
RETURNS JSONB
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_pass RECORD;
  v_now TIMESTAMPTZ;
BEGIN
  v_now := NOW();

  IF p_token IS NULL OR p_token = '' THEN
    RETURN jsonb_build_object('valid', false, 'error_code', 'MISSING_TOKEN');
  END IF;

  SELECT bp.*, b.starts_at, b.ends_at, b.status AS booking_status, b.space_id, ps.name AS space_name, f.name AS facility_name
  INTO v_pass
  FROM public.booking_passes bp
  JOIN public.bookings b ON b.id = bp.booking_id
  JOIN public.parking_spaces ps ON ps.id = b.space_id
  JOIN public.facilities f ON f.id = ps.facility_id
  WHERE bp.token = p_token;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('valid', false, 'error_code', 'INVALID_PASS');
  END IF;

  IF v_pass.status = 'expired' THEN
    RETURN jsonb_build_object('valid', false, 'error_code', 'PASS_EXPIRED');
  END IF;

  IF v_pass.status = 'revoked' THEN
    RETURN jsonb_build_object('valid', false, 'error_code', 'PASS_REVOKED');
  END IF;

  IF v_pass.booking_status NOT IN ('pending', 'confirmed') THEN
    RETURN jsonb_build_object('valid', false, 'error_code', 'BOOKING_NOT_ELIGIBLE');
  END IF;

  IF v_pass.expires_at <= v_now THEN
    UPDATE public.booking_passes
    SET status = 'expired', verified_at = v_now
    WHERE id = v_pass.id;
    RETURN jsonb_build_object('valid', false, 'error_code', 'PASS_EXPIRED');
  END IF;

  IF v_now < v_pass.starts_at OR v_now > v_pass.ends_at THEN
    RETURN jsonb_build_object('valid', false, 'error_code', 'PASS_NOT_ACTIVE_FOR_TIME');
  END IF;

  UPDATE public.booking_passes
  SET verified_at = v_now,
      last_verified_by = auth.uid()
  WHERE id = v_pass.id;

  RETURN jsonb_build_object(
    'valid', true,
    'booking_id', v_pass.booking_id,
    'space_id', v_pass.space_id,
    'space_name', v_pass.space_name,
    'facility_name', v_pass.facility_name,
    'starts_at', v_pass.starts_at,
    'ends_at', v_pass.ends_at,
    'status', v_pass.booking_status,
    'pass_status', 'active'
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.resolve_qr_reference(TEXT) TO anon;
GRANT EXECUTE ON FUNCTION public.resolve_qr_reference(TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.generate_booking_pass(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.verify_booking_pass(TEXT) TO anon;
GRANT EXECUTE ON FUNCTION public.verify_booking_pass(TEXT) TO authenticated;

-- ---------------------------------------------------------------------------
-- Seed backfill: generate pass tokens for existing confirmed bookings.
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  booking_row RECORD;
BEGIN
  FOR booking_row IN
    SELECT b.id
    FROM public.bookings b
    LEFT JOIN public.booking_passes bp ON bp.booking_id = b.id
    WHERE bp.id IS NULL
      AND b.status IN ('pending', 'confirmed')
  LOOP
    PERFORM public.generate_booking_pass(booking_row.id);
  END LOOP;
END $$;
