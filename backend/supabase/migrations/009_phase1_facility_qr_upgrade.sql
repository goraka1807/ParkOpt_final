-- =============================================================================
-- Migration 009: Phase 1 facility hierarchy + secure QR identifiers
-- =============================================================================
-- Purpose:
--   - support both independent parking lots and mall-style facilities
--   - track facility -> floor -> zone -> parking space hierarchy
--   - assign secure QR identifiers to facilities and spaces
--   - preserve legacy space records and booking data while adding hierarchy
-- =============================================================================

CREATE TYPE facility_kind AS ENUM ('independent_lot', 'shopping_mall');
CREATE TYPE facility_status AS ENUM ('active', 'inactive', 'maintenance', 'archived');
CREATE TYPE booking_pass_status AS ENUM ('active', 'expired', 'revoked', 'used');

-- Security helper for random opaque QR codes.
CREATE OR REPLACE FUNCTION public.generate_secure_qr_code(p_prefix TEXT)
RETURNS TEXT
LANGUAGE sql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT p_prefix || encode(extensions.gen_random_bytes(16), 'hex');
$$;

-- ---------------------------------------------------------------------------
-- Table: public.facilities
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
DROP POLICY IF EXISTS "facilities_delete_owner" ON public.facilities;

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

CREATE POLICY "facilities_delete_owner"
  ON public.facilities
  FOR DELETE
  USING (auth.uid() = owner_id);

-- ---------------------------------------------------------------------------
-- Table: public.facility_floors
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.facility_floors (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  facility_id UUID NOT NULL REFERENCES public.facilities(id) ON DELETE CASCADE,
  floor_number INTEGER NOT NULL CHECK (floor_number >= -5 AND floor_number <= 100),
  label TEXT NOT NULL DEFAULT 'Level',
  qr_code_id TEXT NOT NULL UNIQUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (qr_code_id ~ '^parkopt_floor_[A-Za-z0-9_-]{12,64}$'),
  UNIQUE (facility_id, floor_number)
);

CREATE INDEX IF NOT EXISTS idx_facility_floors_facility_id ON public.facility_floors(facility_id);
CREATE INDEX IF NOT EXISTS idx_facility_floors_number ON public.facility_floors(facility_id, floor_number);

ALTER TABLE public.facility_floors ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "facility_floors_select_public_active" ON public.facility_floors;
DROP POLICY IF EXISTS "facility_floors_select_owner_or_admin" ON public.facility_floors;
DROP POLICY IF EXISTS "facility_floors_insert_owner" ON public.facility_floors;
DROP POLICY IF EXISTS "facility_floors_update_owner" ON public.facility_floors;
DROP POLICY IF EXISTS "facility_floors_delete_owner" ON public.facility_floors;

CREATE POLICY "facility_floors_select_public_active"
  ON public.facility_floors
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.facilities f
      WHERE f.id = facility_id AND f.status = 'active'
    )
  );

CREATE POLICY "facility_floors_select_owner_or_admin"
  ON public.facility_floors
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.facilities f
      WHERE f.id = facility_id
        AND (f.owner_id = auth.uid() OR EXISTS (
          SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin'
        ))
    )
  );

CREATE POLICY "facility_floors_insert_owner"
  ON public.facility_floors
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.facilities f
      WHERE f.id = facility_id
        AND (f.owner_id = auth.uid() OR EXISTS (
          SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin'
        ))
    )
  );

CREATE POLICY "facility_floors_update_owner"
  ON public.facility_floors
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.facilities f
      WHERE f.id = facility_id AND f.owner_id = auth.uid()
    ) OR EXISTS (
      SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin'
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.facilities f
      WHERE f.id = facility_id AND f.owner_id = auth.uid()
    ) OR EXISTS (
      SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin'
    )
  );

CREATE POLICY "facility_floors_delete_owner"
  ON public.facility_floors
  FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM public.facilities f
      WHERE f.id = facility_id AND f.owner_id = auth.uid()
    ) OR EXISTS (
      SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin'
    )
  );

-- ---------------------------------------------------------------------------
-- Table: public.facility_zones
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

ALTER TABLE public.facility_zones ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "facility_zones_select_public_active" ON public.facility_zones;
DROP POLICY IF EXISTS "facility_zones_select_owner_or_admin" ON public.facility_zones;
DROP POLICY IF EXISTS "facility_zones_insert_owner" ON public.facility_zones;
DROP POLICY IF EXISTS "facility_zones_update_owner" ON public.facility_zones;
DROP POLICY IF EXISTS "facility_zones_delete_owner" ON public.facility_zones;

CREATE POLICY "facility_zones_select_public_active"
  ON public.facility_zones
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.facilities f
      WHERE f.id = facility_id AND f.status = 'active'
    )
  );

CREATE POLICY "facility_zones_select_owner_or_admin"
  ON public.facility_zones
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.facilities f
      WHERE f.id = facility_id
        AND (f.owner_id = auth.uid() OR EXISTS (
          SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin'
        ))
    )
  );

CREATE POLICY "facility_zones_insert_owner"
  ON public.facility_zones
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.facilities f
      WHERE f.id = facility_id
        AND (f.owner_id = auth.uid() OR EXISTS (
          SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin'
        ))
    )
  );

CREATE POLICY "facility_zones_update_owner"
  ON public.facility_zones
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.facilities f
      WHERE f.id = facility_id AND f.owner_id = auth.uid()
    ) OR EXISTS (
      SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin'
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.facilities f
      WHERE f.id = facility_id AND f.owner_id = auth.uid()
    ) OR EXISTS (
      SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin'
    )
  );

CREATE POLICY "facility_zones_delete_owner"
  ON public.facility_zones
  FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM public.facilities f
      WHERE f.id = facility_id AND f.owner_id = auth.uid()
    ) OR EXISTS (
      SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin'
    )
  );

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

-- Backfill facility rows before linking space rows to them.
DO $$
DECLARE
  v_row RECORD;
BEGIN
  FOR v_row IN
    SELECT ps.id, ps.owner_id, ps.name, ps.address_line1, ps.address_line2, ps.city,
           ps.state, ps.country, ps.postal_code, ps.latitude, ps.longitude,
           ps.is_covered, ps.is_gated, ps.has_cctv, ps.has_lighting,
           ps.has_ev_charging, ps.is_accessible, ps.created_at, ps.updated_at,
           ps.status
    FROM public.parking_spaces ps
    LEFT JOIN public.facilities f ON f.id = ps.id
    WHERE f.id IS NULL
  LOOP
    INSERT INTO public.facilities (
      id, owner_id, name, kind, status, qr_code_id,
      address_line1, address_line2, city, state, country,
      postal_code, latitude, longitude, is_covered, is_gated,
      has_cctv, has_lighting, has_ev_charging, is_accessible,
      created_at, updated_at
    )
    VALUES (
      v_row.id,
      v_row.owner_id,
      v_row.name,
      'independent_lot',
      CASE v_row.status
        WHEN 'active' THEN 'active'::facility_status
        WHEN 'inactive' THEN 'inactive'::facility_status
        WHEN 'pending_review' THEN 'inactive'::facility_status
        WHEN 'suspended' THEN 'inactive'::facility_status
        ELSE 'inactive'::facility_status
      END,
      public.generate_secure_qr_code('parkopt_fac_'),
      v_row.address_line1,
      v_row.address_line2,
      v_row.city,
      v_row.state,
      v_row.country,
      v_row.postal_code,
      v_row.latitude,
      v_row.longitude,
      v_row.is_covered,
      v_row.is_gated,
      v_row.has_cctv,
      v_row.has_lighting,
      v_row.has_ev_charging,
      v_row.is_accessible,
      v_row.created_at,
      v_row.updated_at
    );
  END LOOP;
END $$;

UPDATE public.parking_spaces ps
SET facility_id = ps.id,
    qr_code_id = COALESCE(ps.qr_code_id, public.generate_secure_qr_code('parkopt_space_')),
    space_label = COALESCE(ps.space_label, 'A-' || (floor(random() * 900 + 100))::int::text)
WHERE ps.facility_id IS NULL
   OR ps.qr_code_id IS NULL
   OR ps.space_label IS NULL;

ALTER TABLE public.parking_spaces
  ADD CONSTRAINT parking_spaces_facility_fk
  FOREIGN KEY (facility_id) REFERENCES public.facilities(id) ON DELETE RESTRICT;

ALTER TABLE public.parking_spaces
  ADD CONSTRAINT parking_spaces_floor_fk
  FOREIGN KEY (floor_id) REFERENCES public.facility_floors(id) ON DELETE SET NULL;

ALTER TABLE public.parking_spaces
  ADD CONSTRAINT parking_spaces_zone_fk
  FOREIGN KEY (zone_id) REFERENCES public.facility_zones(id) ON DELETE SET NULL;

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
-- Hierarchy validation triggers
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.validate_facility_hierarchy()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF TG_TABLE_NAME = 'facility_floors' THEN
    IF NEW.facility_id IS NULL THEN
      RAISE EXCEPTION 'facility_id is required for a floor.';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM public.facilities WHERE id = NEW.facility_id) THEN
      RAISE EXCEPTION 'Floor facility_id does not match an existing facility.';
    END IF;
  END IF;

  IF TG_TABLE_NAME = 'facility_zones' THEN
    IF NEW.facility_id IS NULL THEN
      RAISE EXCEPTION 'facility_id is required for a zone.';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM public.facilities WHERE id = NEW.facility_id) THEN
      RAISE EXCEPTION 'Zone facility_id does not match an existing facility.';
    END IF;

    IF NEW.floor_id IS NOT NULL AND NOT EXISTS (
      SELECT 1
      FROM public.facility_floors ff
      WHERE ff.id = NEW.floor_id
        AND ff.facility_id = NEW.facility_id
    ) THEN
      RAISE EXCEPTION 'Zone floor_id must belong to the same facility.';
    END IF;
  END IF;

  IF TG_TABLE_NAME = 'parking_spaces' THEN
    IF NEW.facility_id IS NULL THEN
      RAISE EXCEPTION 'facility_id is required for a parking space.';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM public.facilities WHERE id = NEW.facility_id) THEN
      RAISE EXCEPTION 'Parking space facility_id does not match an existing facility.';
    END IF;

    IF NEW.floor_id IS NOT NULL AND NOT EXISTS (
      SELECT 1
      FROM public.facility_floors ff
      WHERE ff.id = NEW.floor_id
        AND ff.facility_id = NEW.facility_id
    ) THEN
      RAISE EXCEPTION 'Parking space floor_id must belong to the same facility.';
    END IF;

    IF NEW.zone_id IS NOT NULL AND NOT EXISTS (
      SELECT 1
      FROM public.facility_zones fz
      WHERE fz.id = NEW.zone_id
        AND fz.facility_id = NEW.facility_id
    ) THEN
      RAISE EXCEPTION 'Parking space zone_id must belong to the same facility.';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS facility_floor_hierarchy_guard ON public.facility_floors;
CREATE TRIGGER facility_floor_hierarchy_guard
  BEFORE INSERT OR UPDATE ON public.facility_floors
  FOR EACH ROW EXECUTE FUNCTION public.validate_facility_hierarchy();

DROP TRIGGER IF EXISTS facility_zone_hierarchy_guard ON public.facility_zones;
CREATE TRIGGER facility_zone_hierarchy_guard
  BEFORE INSERT OR UPDATE ON public.facility_zones
  FOR EACH ROW EXECUTE FUNCTION public.validate_facility_hierarchy();

DROP TRIGGER IF EXISTS parking_space_hierarchy_guard ON public.parking_spaces;
CREATE TRIGGER parking_space_hierarchy_guard
  BEFORE INSERT OR UPDATE ON public.parking_spaces
  FOR EACH ROW EXECUTE FUNCTION public.validate_facility_hierarchy();

-- ---------------------------------------------------------------------------
-- Table: public.booking_passes
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

ALTER TABLE public.booking_passes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "booking_passes_select_owner_or_driver_or_admin" ON public.booking_passes;
DROP POLICY IF EXISTS "booking_passes_no_direct_insert" ON public.booking_passes;
DROP POLICY IF EXISTS "booking_passes_no_direct_update" ON public.booking_passes;
DROP POLICY IF EXISTS "booking_passes_no_direct_delete" ON public.booking_passes;

CREATE POLICY "booking_passes_select_owner_or_driver_or_admin"
  ON public.booking_passes
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.bookings b
      WHERE b.id = booking_id AND b.driver_id = auth.uid()
    )
    OR EXISTS (
      SELECT 1
      FROM public.bookings b
      JOIN public.parking_spaces ps ON ps.id = b.space_id
      WHERE b.id = booking_id AND ps.owner_id = auth.uid()
    )
    OR EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = auth.uid() AND p.role = 'admin'
    )
  );

CREATE POLICY "booking_passes_no_direct_insert"
  ON public.booking_passes
  FOR INSERT WITH CHECK (FALSE);

CREATE POLICY "booking_passes_no_direct_update"
  ON public.booking_passes
  FOR UPDATE USING (FALSE);

CREATE POLICY "booking_passes_no_direct_delete"
  ON public.booking_passes
  FOR DELETE USING (FALSE);

-- ---------------------------------------------------------------------------
-- Utility function: resolve a secure location QR reference.
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
  v_rec RECORD;
BEGIN
  v_code := NULLIF(btrim(COALESCE(p_qr_code, '')), '');

  IF v_code IS NULL OR v_code !~ '^parkopt_(fac|space|floor|zone)_[A-Za-z0-9_-]{12,64}$' THEN
    RETURN jsonb_build_object('valid', false, 'error_code', 'INVALID_QR');
  END IF;

  IF v_code LIKE 'parkopt_pass_%' THEN
    RETURN jsonb_build_object('valid', false, 'error_code', 'BOOKING_PASS_NOT_ALLOWED');
  END IF;

  IF v_code LIKE 'parkopt_fac_%' THEN
    SELECT f.id, f.name, f.qr_code_id, f.status INTO v_rec
    FROM public.facilities f
    WHERE f.qr_code_id = v_code AND f.status = 'active'
    LIMIT 1;

    IF NOT FOUND THEN
      RETURN jsonb_build_object('valid', false, 'error_code', 'FACILITY_NOT_FOUND');
    END IF;

    RETURN jsonb_build_object(
      'valid', true,
      'kind', 'facility',
      'facility_id', v_rec.id,
      'facility_name', v_rec.name,
      'facility_qr_code', v_rec.qr_code_id
    );
  END IF;

  IF v_code LIKE 'parkopt_floor_%' THEN
    SELECT ff.id, ff.facility_id, ff.floor_number, ff.qr_code_id, f.status INTO v_rec
    FROM public.facility_floors ff
    JOIN public.facilities f ON f.id = ff.facility_id
    WHERE ff.qr_code_id = v_code AND f.status = 'active'
    LIMIT 1;

    IF NOT FOUND THEN
      RETURN jsonb_build_object('valid', false, 'error_code', 'FLOOR_NOT_FOUND');
    END IF;

    RETURN jsonb_build_object(
      'valid', true,
      'kind', 'floor',
      'facility_id', v_rec.facility_id,
      'floor_id', v_rec.id,
      'floor_number', v_rec.floor_number,
      'floor_qr_code', v_rec.qr_code_id
    );
  END IF;

  IF v_code LIKE 'parkopt_zone_%' THEN
    SELECT fz.id, fz.facility_id, fz.floor_id, fz.name, fz.qr_code_id, f.status INTO v_rec
    FROM public.facility_zones fz
    JOIN public.facilities f ON f.id = fz.facility_id
    WHERE fz.qr_code_id = v_code AND f.status = 'active'
    LIMIT 1;

    IF NOT FOUND THEN
      RETURN jsonb_build_object('valid', false, 'error_code', 'ZONE_NOT_FOUND');
    END IF;

    RETURN jsonb_build_object(
      'valid', true,
      'kind', 'zone',
      'facility_id', v_rec.facility_id,
      'zone_id', v_rec.id,
      'zone_name', v_rec.name,
      'zone_qr_code', v_rec.qr_code_id
    );
  END IF;

  IF v_code LIKE 'parkopt_space_%' THEN
    SELECT ps.id, ps.facility_id, ps.space_label, ps.qr_code_id, f.status INTO v_rec
    FROM public.parking_spaces ps
    JOIN public.facilities f ON f.id = ps.facility_id
    WHERE ps.qr_code_id = v_code AND ps.status = 'active' AND f.status = 'active'
    LIMIT 1;

    IF NOT FOUND THEN
      RETURN jsonb_build_object('valid', false, 'error_code', 'SPACE_NOT_FOUND');
    END IF;

    RETURN jsonb_build_object(
      'valid', true,
      'kind', 'space',
      'space_id', v_rec.id,
      'facility_id', v_rec.facility_id,
      'space_label', v_rec.space_label,
      'space_qr_code', v_rec.qr_code_id
    );
  END IF;

  RETURN jsonb_build_object('valid', false, 'error_code', 'UNSUPPORTED_QR_FORMAT');
END;
$$;

REVOKE EXECUTE ON FUNCTION public.resolve_qr_reference(TEXT) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.resolve_qr_reference(TEXT) FROM anon;
GRANT EXECUTE ON FUNCTION public.resolve_qr_reference(TEXT) TO anon;
GRANT EXECUTE ON FUNCTION public.resolve_qr_reference(TEXT) TO authenticated;
