-- =============================================================================
-- Migration 010: Phase 1 QR security and booking pass hardening
-- =============================================================================
-- Purpose:
--   - keep facility/space QR patterns secure and non-identifying
--   - ensure booking pass tokens are unpredictable and lifecycle-checked
--   - reject invalid, cancelled, expired, completed or otherwise ineligible passes
--   - preserve compatibility with the existing Phase 1 schema already established
--     in migrations 001-009
-- =============================================================================

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
  v_now TIMESTAMPTZ;
  v_caller_id UUID;
  v_service_role BOOLEAN;
BEGIN
  v_now := NOW();
  v_caller_id := auth.uid();
  v_service_role := current_setting('role', true) = 'service_role';

  IF p_booking_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'INVALID_INPUT');
  END IF;

  IF v_caller_id IS NULL AND NOT v_service_role THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'UNAUTHENTICATED');
  END IF;

  PERFORM pg_advisory_xact_lock(hashtext(p_booking_id::text));

  SELECT b.*, ps.owner_id AS space_owner_id
    INTO v_booking
  FROM public.bookings b
  JOIN public.parking_spaces ps ON ps.id = b.space_id
  WHERE b.id = p_booking_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'BOOKING_NOT_FOUND');
  END IF;

  IF v_booking.status <> 'confirmed' THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'BOOKING_NOT_ELIGIBLE');
  END IF;

  IF NOT v_service_role AND v_booking.driver_id <> v_caller_id THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'UNAUTHORIZED');
  END IF;

  IF v_booking.ends_at <= v_now THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'BOOKING_NOT_ELIGIBLE');
  END IF;

  SELECT * INTO v_pass
  FROM public.booking_passes bp
  WHERE bp.booking_id = p_booking_id
  FOR UPDATE;

  IF FOUND THEN
    IF v_pass.status = 'active' AND v_pass.expires_at > v_now THEN
      RETURN jsonb_build_object(
        'success', true,
        'booking_id', p_booking_id,
        'token', v_pass.token,
        'expires_at', v_pass.expires_at,
        'status', v_pass.status
      );
    END IF;

    IF v_pass.status IN ('revoked', 'used') THEN
      RETURN jsonb_build_object('success', false, 'error_code', 'PASS_NOT_ELIGIBLE');
    END IF;

    IF v_pass.status = 'expired' AND v_now < v_booking.ends_at THEN
      UPDATE public.booking_passes
      SET token = 'parkopt_pass_' || encode(extensions.gen_random_bytes(32), 'hex'),
          expires_at = v_now + INTERVAL '30 days',
          issued_at = v_now,
          status = 'active',
          verified_at = NULL,
          last_verified_by = NULL
      WHERE id = v_pass.id
      RETURNING * INTO v_pass;

      RETURN jsonb_build_object(
        'success', true,
        'booking_id', p_booking_id,
        'token', v_pass.token,
        'expires_at', v_pass.expires_at,
        'status', v_pass.status
      );
    END IF;

    IF v_pass.status = 'expired' THEN
      RETURN jsonb_build_object('success', false, 'error_code', 'PASS_EXPIRED');
    END IF;
  END IF;

  INSERT INTO public.booking_passes (booking_id, token, expires_at, issued_at, status)
  VALUES (
    p_booking_id,
    'parkopt_pass_' || encode(extensions.gen_random_bytes(32), 'hex'),
    v_now + INTERVAL '30 days',
    v_now,
    'active'
  )
  ON CONFLICT (booking_id) DO UPDATE
  SET token = EXCLUDED.token,
      expires_at = EXCLUDED.expires_at,
      issued_at = EXCLUDED.issued_at,
      status = 'active',
      verified_at = NULL,
      last_verified_by = NULL
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

CREATE OR REPLACE FUNCTION public.verify_booking_pass(p_token TEXT)
RETURNS JSONB
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_caller_id UUID;
  v_pass RECORD;
  v_now TIMESTAMPTZ;
BEGIN
  v_now := NOW();
  v_caller_id := auth.uid();

  IF v_caller_id IS NULL THEN
    RETURN jsonb_build_object('valid', false, 'error_code', 'UNAUTHENTICATED');
  END IF;

  IF p_token IS NULL OR btrim(p_token) = '' THEN
    RETURN jsonb_build_object('valid', false, 'error_code', 'MISSING_TOKEN');
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.id = v_caller_id AND p.is_active = TRUE
  ) THEN
    RETURN jsonb_build_object('valid', false, 'error_code', 'UNAUTHORIZED');
  END IF;

  SELECT
    bp.*,
    b.id AS booking_id,
    b.status AS booking_status,
    b.driver_id,
    b.starts_at,
    b.ends_at,
    b.space_id,
    ps.name AS space_name,
    ps.owner_id AS space_owner_id,
    f.name AS facility_name
  INTO v_pass
  FROM public.booking_passes bp
  JOIN public.bookings b ON b.id = bp.booking_id
  JOIN public.parking_spaces ps ON ps.id = b.space_id
  LEFT JOIN public.facilities f ON f.id = ps.facility_id
  WHERE bp.token = p_token;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('valid', false, 'error_code', 'INVALID_PASS');
  END IF;

  IF NOT (
    EXISTS (
      SELECT 1 FROM public.profiles p WHERE p.id = v_caller_id AND p.role = 'admin'
    )
    OR v_pass.space_owner_id = v_caller_id
    OR v_pass.driver_id = v_caller_id
  ) THEN
    RETURN jsonb_build_object('valid', false, 'error_code', 'UNAUTHORIZED');
  END IF;

  IF v_pass.status IN ('expired', 'revoked', 'used') THEN
    RETURN jsonb_build_object('valid', false, 'error_code', 'PASS_NOT_ELIGIBLE');
  END IF;

  IF v_pass.booking_status NOT IN ('confirmed') THEN
    RETURN jsonb_build_object('valid', false, 'error_code', 'BOOKING_NOT_ELIGIBLE');
  END IF;

  IF v_pass.expires_at <= v_now THEN
    UPDATE public.booking_passes
    SET status = 'expired',
        verified_at = v_now,
        last_verified_by = v_caller_id
    WHERE id = v_pass.id;

    RETURN jsonb_build_object('valid', false, 'error_code', 'PASS_EXPIRED');
  END IF;

  IF v_now < v_pass.starts_at OR v_now > v_pass.ends_at THEN
    RETURN jsonb_build_object('valid', false, 'error_code', 'PASS_NOT_ACTIVE_FOR_TIME');
  END IF;

  UPDATE public.booking_passes
  SET verified_at = v_now,
      last_verified_by = v_caller_id
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

REVOKE EXECUTE ON FUNCTION public.generate_booking_pass(UUID) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.generate_booking_pass(UUID) FROM anon;
GRANT EXECUTE ON FUNCTION public.generate_booking_pass(UUID) TO authenticated;

REVOKE EXECUTE ON FUNCTION public.verify_booking_pass(TEXT) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.verify_booking_pass(TEXT) FROM anon;
GRANT EXECUTE ON FUNCTION public.verify_booking_pass(TEXT) TO authenticated;

-- The verify-booking-pass Edge Function should require a caller JWT.
-- Anonymous verification is deliberately not granted to avoid exposing booking
-- validity checks to unauthenticated clients.
