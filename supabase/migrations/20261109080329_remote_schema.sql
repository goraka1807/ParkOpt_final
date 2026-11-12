SET local check_function_bodies = off;

CREATE EXTENSION "btree_gist" SCHEMA "public";

CREATE EXTENSION "postgis" SCHEMA "public";

CREATE TABLE "public"."bookings" (
  "id"             uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "driver_id"      uuid                     NOT NULL,
  "space_id"       uuid                     NOT NULL,
  "starts_at"      timestamp with time zone NOT NULL,
  "ends_at"        timestamp with time zone NOT NULL,
  "booking_period" tstzrange                GENERATED ALWAYS AS (tstzrange(starts_at, ends_at, '[)'::text)) STORED,
  "price_per_hour" integer                  NOT NULL,
  "duration_hours" numeric(8,2)             NOT NULL,
  "total_price"    integer                  NOT NULL,
  CONSTRAINT "booking_max_duration" CHECK ((EXTRACT(epoch FROM (ends_at - starts_at)) <= (2592000)::numeric)),
  CONSTRAINT "booking_min_duration" CHECK ((EXTRACT(epoch FROM (ends_at - starts_at)) >= (7200)::numeric)),
  CONSTRAINT "booking_time_order" CHECK ((ends_at > starts_at)),
  CONSTRAINT "bookings_duration_hours_check" CHECK ((duration_hours >= (2)::numeric)),
  CONSTRAINT "bookings_pkey" PRIMARY KEY (id),
  CONSTRAINT "bookings_price_per_hour_check" CHECK ((price_per_hour > 0)),
  CONSTRAINT "bookings_total_price_check" CHECK ((total_price > 0))
);

ALTER TABLE "public"."bookings"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."parking_spaces" (
  "id"             uuid                         NOT NULL DEFAULT gen_random_uuid(),
  "owner_id"       uuid                         NOT NULL,
  "name"           text                         NOT NULL,
  "description"    text,
  "address_line1"  text                         NOT NULL,
  "address_line2"  text,
  "city"           text                         NOT NULL,
  "state"          text                         NOT NULL,
  "country"        text                         NOT NULL DEFAULT 'India'::text,
  "postal_code"    text,
  "location"       public.geography(Point,4326) NOT NULL,
  "latitude"       numeric(10,8)                NOT NULL,
  "longitude"      numeric(11,8)                NOT NULL,
  "total_capacity" integer                      NOT NULL DEFAULT 1,
  "price_per_hour" integer                      NOT NULL,
  CONSTRAINT "parking_spaces_latitude_check" CHECK (((latitude >= ('-90'::integer)::numeric) AND (latitude <= (90)::numeric))),
  CONSTRAINT "parking_spaces_longitude_check" CHECK (((longitude >= ('-180'::integer)::numeric) AND (longitude <= (180)::numeric))),
  CONSTRAINT "parking_spaces_name_check" CHECK (((char_length(name) >= 3) AND (char_length(name) <= 150))),
  CONSTRAINT "parking_spaces_pkey" PRIMARY KEY (id),
  CONSTRAINT "parking_spaces_price_per_hour_check" CHECK ((price_per_hour > 0)),
  CONSTRAINT "parking_spaces_total_capacity_check" CHECK ((total_capacity >= 1))
);

ALTER TABLE "public"."parking_spaces"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."profiles" (
  "id"        uuid NOT NULL,
  "full_name" text NOT NULL DEFAULT ''::text,
  "phone"     text,
  CONSTRAINT "profiles_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."profiles"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."space_blocked_periods" (
  "id"            uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "space_id"      uuid                     NOT NULL,
  "blocked_from"  timestamp with time zone NOT NULL,
  "blocked_until" timestamp with time zone NOT NULL,
  "reason"        text,
  "created_at"    timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "blocked_period_valid" CHECK ((blocked_until > blocked_from)),
  CONSTRAINT "space_blocked_periods_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."space_blocked_periods"
  ENABLE ROW LEVEL SECURITY;

CREATE TYPE "public"."booking_status" AS ENUM (
  'pending',
  'confirmed',
  'cancelled',
  'completed',
  'no_show'
);

CREATE TYPE "public"."space_status" AS ENUM (
  'active',
  'inactive',
  'pending_review',
  'suspended'
);

CREATE TYPE "public"."user_role" AS ENUM (
  'driver',
  'owner',
  'admin'
);

ALTER TABLE "public"."profiles"
  ADD COLUMN "role" public.user_role NOT NULL DEFAULT 'driver'::public.user_role;

ALTER TABLE "public"."profiles"
  ADD COLUMN "avatar_url" text;

CREATE TYPE "public"."vehicle_type" AS ENUM (
  'motorcycle',
  'compact',
  'sedan',
  'suv',
  'van',
  'truck',
  'electric'
);

ALTER TABLE "public"."bookings"
  ADD COLUMN "vehicle_type" public.vehicle_type NOT NULL;

ALTER TABLE "public"."bookings"
  ADD COLUMN "vehicle_plate" text;

ALTER TABLE "public"."bookings"
  ADD COLUMN "status" public.booking_status NOT NULL DEFAULT 'confirmed'::public.booking_status;

ALTER TABLE "public"."bookings"
  ADD COLUMN "cancelled_at" timestamp WITH time zone;

ALTER TABLE "public"."bookings"
  ADD COLUMN "cancellation_reason" text;

ALTER TABLE "public"."bookings"
  ADD COLUMN "cancelled_by" uuid;

ALTER TABLE "public"."bookings"
  ADD COLUMN "payment_id" text;

ALTER TABLE "public"."bookings"
  ADD COLUMN "payment_status" text DEFAULT 'unpaid'::text;

ALTER TABLE "public"."bookings"
  ADD COLUMN "driver_notes" text;

ALTER TABLE "public"."bookings"
  ADD COLUMN "created_at" timestamp WITH time zone NOT NULL DEFAULT now();

ALTER TABLE "public"."bookings"
  ADD COLUMN "updated_at" timestamp WITH time zone NOT NULL DEFAULT now();

ALTER TABLE "public"."parking_spaces"
  ADD COLUMN "max_vehicle_type" public.vehicle_type NOT NULL DEFAULT 'sedan'::public.vehicle_type;

ALTER TABLE "public"."parking_spaces"
  ADD COLUMN "is_covered" boolean NOT NULL DEFAULT false;

ALTER TABLE "public"."parking_spaces"
  ADD COLUMN "is_gated" boolean NOT NULL DEFAULT false;

ALTER TABLE "public"."parking_spaces"
  ADD COLUMN "has_cctv" boolean NOT NULL DEFAULT false;

ALTER TABLE "public"."parking_spaces"
  ADD COLUMN "has_lighting" boolean NOT NULL DEFAULT false;

ALTER TABLE "public"."parking_spaces"
  ADD COLUMN "has_ev_charging" boolean NOT NULL DEFAULT false;

ALTER TABLE "public"."parking_spaces"
  ADD COLUMN "is_accessible" boolean NOT NULL DEFAULT false;

ALTER TABLE "public"."parking_spaces"
  ADD COLUMN "operating_hours" jsonb;

ALTER TABLE "public"."parking_spaces"
  ADD COLUMN "status" public.space_status NOT NULL DEFAULT 'active'::public.space_status;

ALTER TABLE "public"."parking_spaces"
  ADD COLUMN "image_urls" text[] DEFAULT '{}'::text[];

ALTER TABLE "public"."parking_spaces"
  ADD COLUMN "avg_rating" numeric(3,2);

ALTER TABLE "public"."parking_spaces"
  ADD COLUMN "review_count" integer NOT NULL DEFAULT 0;

ALTER TABLE "public"."parking_spaces"
  ADD COLUMN "created_at" timestamp WITH time zone NOT NULL DEFAULT now();

ALTER TABLE "public"."parking_spaces"
  ADD COLUMN "updated_at" timestamp WITH time zone NOT NULL DEFAULT now();

ALTER TABLE "public"."profiles"
  ADD COLUMN "preferred_vehicle" public.vehicle_type;

ALTER TABLE "public"."profiles"
  ADD COLUMN "tos_accepted" boolean NOT NULL DEFAULT false;

ALTER TABLE "public"."profiles"
  ADD COLUMN "is_active" boolean NOT NULL DEFAULT true;

ALTER TABLE "public"."profiles"
  ADD COLUMN "created_at" timestamp WITH time zone NOT NULL DEFAULT now();

ALTER TABLE "public"."profiles"
  ADD COLUMN "updated_at" timestamp WITH time zone NOT NULL DEFAULT now();

CREATE OR REPLACE FUNCTION public.calculate_booking_price (
  p_space_id  uuid,
  p_starts_at timestamp with time zone,
  p_ends_at   timestamp with time zone
)
  RETURNS TABLE (
    price_per_hour integer,
    duration_hours numeric,
    total_price    integer
  )
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_price_per_hour INTEGER;
  v_duration_secs  NUMERIC;
  v_duration_hours NUMERIC;
  v_total          INTEGER;
BEGIN
  -- Get the space's authoritative price
  SELECT ps.price_per_hour INTO v_price_per_hour
  FROM public.parking_spaces ps
  WHERE ps.id = p_space_id AND ps.status = 'active';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Space not found or not active: %', p_space_id;
  END IF;

  -- Calculate duration in hours (exact, not rounded)
  v_duration_secs  := EXTRACT(EPOCH FROM (p_ends_at - p_starts_at));
  v_duration_hours := v_duration_secs / 3600.0;

  -- Enforce minimum 2 hours
  IF v_duration_hours < 2.0 THEN
    RAISE EXCEPTION 'Minimum booking duration is 2 hours. Requested: % hours', 
      ROUND(v_duration_hours, 2);
  END IF;

  -- Price calculation: ceil to nearest hour (standard parking billing)
  -- e.g., 2.5 hours billed as 3 hours
  v_total := CEIL(v_duration_hours) * v_price_per_hour;

  RETURN QUERY SELECT v_price_per_hour, v_duration_hours, v_total;
END;
$function$;

REVOKE ALL ON FUNCTION "public"."calculate_booking_price"(uuid, timestamp WITH time zone, timestamp WITH time zone) FROM PUBLIC, "anon";

CREATE OR REPLACE FUNCTION public.cancel_booking (
  p_booking_id          uuid,
  p_cancellation_reason text DEFAULT NULL::text
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_caller_id UUID;
  v_booking   RECORD;
BEGIN
  v_caller_id := auth.uid();

  IF v_caller_id IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error_code', 'UNAUTHENTICATED',
      'message', 'You must be logged in.'
    );
  END IF;

  SELECT b.*, ps.owner_id AS space_owner_id
  INTO v_booking
  FROM public.bookings b
  JOIN public.parking_spaces ps ON ps.id = b.space_id
  WHERE b.id = p_booking_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'success', false,
      'error_code', 'BOOKING_NOT_FOUND',
      'message', 'Booking not found.'
    );
  END IF;

  -- Authorization: only the driver who booked, the space owner, or admin can cancel
  IF v_booking.driver_id != v_caller_id
    AND v_booking.space_owner_id != v_caller_id
    AND NOT EXISTS (
      SELECT 1 FROM public.profiles WHERE id = v_caller_id AND role = 'admin'
    )
  THEN
    RETURN jsonb_build_object(
      'success', false,
      'error_code', 'UNAUTHORIZED',
      'message', 'You are not authorized to cancel this booking.'
    );
  END IF;

  -- Status check: can only cancel pending or confirmed bookings
  IF v_booking.status NOT IN ('pending', 'confirmed') THEN
    RETURN jsonb_build_object(
      'success', false,
      'error_code', 'CANNOT_CANCEL',
      'message', format('Cannot cancel a booking with status: %s', v_booking.status)
    );
  END IF;

  -- Cannot cancel a booking that has already started
  IF v_booking.starts_at <= NOW() THEN
    RETURN jsonb_build_object(
      'success', false,
      'error_code', 'BOOKING_ALREADY_STARTED',
      'message', 'Cannot cancel a booking that has already started.'
    );
  END IF;

  UPDATE public.bookings
  SET
    status = 'cancelled',
    cancelled_at = NOW(),
    cancellation_reason = p_cancellation_reason,
    cancelled_by = v_caller_id
  WHERE id = p_booking_id;

  RETURN jsonb_build_object(
    'success', true,
    'booking_id', p_booking_id,
    'status', 'cancelled',
    'cancelled_at', NOW()
  );
END;
$function$;

REVOKE ALL ON FUNCTION "public"."cancel_booking"(uuid, text) FROM PUBLIC, "anon";

CREATE OR REPLACE FUNCTION public.check_space_availability (
  p_space_id  uuid,
  p_starts_at timestamp with time zone,
  p_ends_at   timestamp with time zone
)
  RETURNS integer
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_total_capacity INTEGER;
  v_booked_count   INTEGER;
BEGIN
  -- Input validation
  IF p_starts_at IS NULL OR p_ends_at IS NULL THEN
    RAISE EXCEPTION 'starts_at and ends_at are required.';
  END IF;

  IF p_starts_at >= p_ends_at THEN
    RAISE EXCEPTION 'starts_at must be before ends_at.';
  END IF;

  -- Note: we intentionally do NOT reject past timestamps here.
  -- This function is also used internally by create_booking() which has already
  -- checked for past start times. Rejecting past times here would break admin
  -- queries checking historical availability.

  -- Fetch total capacity for the given space (active spaces only)
  SELECT total_capacity INTO v_total_capacity
  FROM public.parking_spaces
  WHERE id = p_space_id AND status = 'active';

  IF NOT FOUND THEN
    RETURN 0;  -- space not found or not active
  END IF;

  -- Check if the entire space is blocked during this period (owner-defined block)
  IF EXISTS (
    SELECT 1 FROM public.space_blocked_periods
    WHERE
      space_id = p_space_id
      AND tstzrange(blocked_from, blocked_until, '[)') &&
          tstzrange(p_starts_at, p_ends_at, '[)')
  ) THEN
    RETURN 0;  -- owner-blocked period
  END IF;

  -- Count active bookings whose half-open interval [start, end) overlaps with
  -- the requested half-open interval [p_starts_at, p_ends_at).
  -- The && operator on tstzrange uses half-open semantics, so adjacent bookings
  -- (e.g., [10:00,12:00) and [12:00,14:00)) do NOT overlap — correct.
  SELECT COUNT(*) INTO v_booked_count
  FROM public.bookings
  WHERE
    space_id = p_space_id
    AND status IN ('pending', 'confirmed')
    AND booking_period && tstzrange(p_starts_at, p_ends_at, '[)');

  RETURN GREATEST(0, v_total_capacity - v_booked_count);
END;
$function$;

REVOKE ALL ON FUNCTION "public"."check_space_availability"(uuid, timestamp WITH time zone, timestamp WITH time zone) FROM PUBLIC, "anon";

CREATE OR REPLACE FUNCTION public.create_booking (
  p_space_id      uuid,
  p_starts_at     timestamp with time zone,
  p_ends_at       timestamp with time zone,
  p_vehicle_type  public.vehicle_type,
  p_vehicle_plate text                     DEFAULT NULL::text,
  p_driver_notes  text                     DEFAULT NULL::text
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_driver_id      UUID;
  v_space          RECORD;
  v_available      INTEGER;
  v_price_per_hour INTEGER;
  v_duration_secs  NUMERIC;
  v_duration_hours NUMERIC;
  v_total_price    INTEGER;
  v_booking_id     UUID;
  v_lock_key       BIGINT;
BEGIN
  -- -------------------------------------------------------------------------
  -- Step 1: Identify the authenticated caller via Supabase-injected JWT claim.
  -- auth.uid() cannot be spoofed from the client.
  -- -------------------------------------------------------------------------
  v_driver_id := auth.uid();

  IF v_driver_id IS NULL THEN
    RETURN jsonb_build_object(
      'success',    false,
      'error_code', 'UNAUTHENTICATED',
      'message',    'You must be logged in to make a booking.'
    );
  END IF;

  -- Verify the account exists and is active in profiles.
  -- Owners and admins can also book (inclusive — no role restriction here).
  IF NOT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = v_driver_id AND is_active = TRUE
  ) THEN
    RETURN jsonb_build_object(
      'success',    false,
      'error_code', 'ACCOUNT_NOT_FOUND',
      'message',    'User account not found or inactive.'
    );
  END IF;

  -- -------------------------------------------------------------------------
  -- Step 2: Input validation (fast-fail before touching the lock)
  -- -------------------------------------------------------------------------
  IF p_space_id IS NULL THEN
    RETURN jsonb_build_object(
      'success',    false,
      'error_code', 'INVALID_INPUT',
      'message',    'space_id is required.'
    );
  END IF;

  IF p_starts_at IS NULL OR p_ends_at IS NULL THEN
    RETURN jsonb_build_object(
      'success',    false,
      'error_code', 'INVALID_INPUT',
      'message',    'Arrival and departure times are required.'
    );
  END IF;

  IF p_starts_at >= p_ends_at THEN
    RETURN jsonb_build_object(
      'success',    false,
      'error_code', 'INVALID_TIME_RANGE',
      'message',    'Departure time must be after arrival time.'
    );
  END IF;

  -- Reject bookings starting in the past (5-minute grace for network delay)
  IF p_starts_at < (NOW() - INTERVAL '5 minutes') THEN
    RETURN jsonb_build_object(
      'success',    false,
      'error_code', 'PAST_START_TIME',
      'message',    'Arrival time cannot be in the past.'
    );
  END IF;

  -- Enforce minimum 2-hour duration before taking the lock
  v_duration_secs  := EXTRACT(EPOCH FROM (p_ends_at - p_starts_at));
  v_duration_hours := v_duration_secs / 3600.0;

  IF v_duration_hours < 2.0 THEN
    RETURN jsonb_build_object(
      'success',    false,
      'error_code', 'DURATION_TOO_SHORT',
      'message',    format('Minimum booking duration is 2 hours. Requested: %s hours.',
                           ROUND(v_duration_hours, 2))
    );
  END IF;

  -- -------------------------------------------------------------------------
  -- Step 3: Load the parking space record.
  -- Use FOR SHARE to prevent the space being deleted / status-changed while
  -- we hold the advisory lock below.
  -- -------------------------------------------------------------------------
  SELECT * INTO v_space
  FROM public.parking_spaces
  WHERE id = p_space_id
  FOR SHARE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'success',    false,
      'error_code', 'SPACE_NOT_FOUND',
      'message',    'Parking space not found.'
    );
  END IF;

  IF v_space.status != 'active' THEN
    RETURN jsonb_build_object(
      'success',    false,
      'error_code', 'SPACE_UNAVAILABLE',
      'message',    'This parking space is not currently available for booking.'
    );
  END IF;

  -- Prevent owners from booking their own listed space
  IF v_space.owner_id = v_driver_id THEN
    RETURN jsonb_build_object(
      'success',    false,
      'error_code', 'CANNOT_BOOK_OWN_SPACE',
      'message',    'You cannot book your own parking space.'
    );
  END IF;

  -- -------------------------------------------------------------------------
  -- Step 4: Vehicle compatibility check
  -- Hierarchy: motorcycle < compact < sedan < suv < van < truck
  -- electric is a separate category that also fits compact/sedan slots
  -- -------------------------------------------------------------------------
  IF NOT (
    CASE v_space.max_vehicle_type
      WHEN 'motorcycle' THEN p_vehicle_type = 'motorcycle'
      WHEN 'compact'    THEN p_vehicle_type IN ('motorcycle', 'compact')
      WHEN 'sedan'      THEN p_vehicle_type IN ('motorcycle', 'compact', 'sedan')
      WHEN 'suv'        THEN p_vehicle_type IN ('motorcycle', 'compact', 'sedan', 'suv')
      WHEN 'van'        THEN p_vehicle_type IN ('motorcycle', 'compact', 'sedan', 'suv', 'van')
      WHEN 'truck'      THEN p_vehicle_type IN ('motorcycle', 'compact', 'sedan', 'suv', 'van', 'truck')
      WHEN 'electric'   THEN p_vehicle_type IN ('motorcycle', 'compact', 'sedan', 'suv', 'electric')
      ELSE FALSE
    END
  ) THEN
    RETURN jsonb_build_object(
      'success',    false,
      'error_code', 'VEHICLE_INCOMPATIBLE',
      'message',    format('Your %s is not compatible with this space (max: %s).',
                           p_vehicle_type, v_space.max_vehicle_type)
    );
  END IF;

  -- -------------------------------------------------------------------------
  -- Step 5: Server-side price calculation (authoritative — client cannot inject)
  -- -------------------------------------------------------------------------
  v_price_per_hour := v_space.price_per_hour;
  -- Billing rounds UP to the next full hour (standard parking industry practice)
  v_total_price    := CEIL(v_duration_hours)::INTEGER * v_price_per_hour;

  -- -------------------------------------------------------------------------
  -- Step 6: Acquire a transaction-scoped advisory lock keyed to this space.
  --
  -- pg_advisory_xact_lock blocks until the lock is free, then holds it until
  -- the transaction commits or rolls back. Only one transaction per space_id
  -- can proceed past this point at a time.
  --
  -- Lock key derivation: XOR the high and low 64-bit halves of the UUID.
  -- This avoids the fragile string-casting approach in the original code and
  -- distributes keys well across the BIGINT space.
  -- -------------------------------------------------------------------------
  v_lock_key := (
    ('x' || lpad(replace(p_space_id::TEXT, '-', ''), 16, '0'))::BIT(64)::BIGINT
  ) # (
    ('x' || lpad(substr(replace(p_space_id::TEXT, '-', ''), 17, 16), 16, '0'))::BIT(64)::BIGINT
  );
  PERFORM pg_advisory_xact_lock(v_lock_key);

  -- -------------------------------------------------------------------------
  -- Step 7: Re-check availability INSIDE the lock.
  --
  -- This is the authoritative check. Any concurrent transaction that already
  -- inserted a booking and committed will be reflected here. Any transaction
  -- still holding the same lock (impossible — only one at a time) is excluded.
  --
  -- check_space_availability() counts active overlapping bookings and returns
  -- total_capacity - that count. If 0, the slot is full.
  -- -------------------------------------------------------------------------
  v_available := public.check_space_availability(p_space_id, p_starts_at, p_ends_at);

  IF v_available <= 0 THEN
    RETURN jsonb_build_object(
      'success',    false,
      'error_code', 'NO_AVAILABILITY',
      'message',    'Sorry, this parking space is fully booked for the requested time.'
    );
  END IF;

  -- -------------------------------------------------------------------------
  -- Step 8: Insert the booking record.
  -- The advisory lock guarantees that no other transaction is between the
  -- availability check above and this INSERT.
  -- -------------------------------------------------------------------------
  INSERT INTO public.bookings (
    driver_id,
    space_id,
    starts_at,
    ends_at,
    price_per_hour,
    duration_hours,
    total_price,
    vehicle_type,
    vehicle_plate,
    driver_notes,
    status
  )
  VALUES (
    v_driver_id,
    p_space_id,
    p_starts_at,
    p_ends_at,
    v_price_per_hour,
    v_duration_hours,
    v_total_price,
    p_vehicle_type,
    p_vehicle_plate,
    p_driver_notes,
    'confirmed'
  )
  RETURNING id INTO v_booking_id;

  -- -------------------------------------------------------------------------
  -- Step 9: Return success payload
  -- -------------------------------------------------------------------------
  RETURN jsonb_build_object(
    'success',        true,
    'booking_id',     v_booking_id,
    'space_id',       p_space_id,
    'space_name',     v_space.name,
    'driver_id',      v_driver_id,
    'starts_at',      p_starts_at,
    'ends_at',        p_ends_at,
    'duration_hours', v_duration_hours,
    'price_per_hour', v_price_per_hour,
    'total_price',    v_total_price,
    'vehicle_type',   p_vehicle_type,
    'status',         'confirmed'
  );

EXCEPTION
  WHEN OTHERS THEN
    -- Log full detail server-side; return a safe generic message to the client.
    RAISE WARNING 'create_booking error for space=% driver=%: % %',
      p_space_id, v_driver_id, SQLSTATE, SQLERRM;
    RETURN jsonb_build_object(
      'success',    false,
      'error_code', 'INTERNAL_ERROR',
      'message',    'An unexpected error occurred. Please try again.'
    );
END;
$function$;

REVOKE ALL ON FUNCTION "public"."create_booking"(uuid, timestamp WITH time zone, timestamp WITH time zone, public.vehicle_type, text, text) FROM PUBLIC, "anon";

CREATE OR REPLACE FUNCTION public.deactivate_user (
  p_target_user_id uuid,
  p_reason         text DEFAULT NULL::text
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_caller_id UUID;
BEGIN
  v_caller_id := auth.uid();

  IF v_caller_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'UNAUTHENTICATED');
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.profiles WHERE id = v_caller_id AND role = 'admin'
  ) THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'UNAUTHORIZED');
  END IF;

  UPDATE public.profiles
  SET is_active = FALSE
  WHERE id = p_target_user_id;

  -- Also deactivate all their parking spaces
  UPDATE public.parking_spaces
  SET status = 'suspended'
  WHERE owner_id = p_target_user_id AND status = 'active';

  RETURN jsonb_build_object(
    'success', true,
    'target_user_id', p_target_user_id,
    'action', 'deactivated'
  );
END;
$function$;

REVOKE ALL ON FUNCTION "public"."deactivate_user"(uuid, text) FROM PUBLIC, "anon";

CREATE OR REPLACE FUNCTION public.elevate_user_role (
  p_target_user_id uuid,
  p_new_role       public.user_role
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_caller_id UUID;
  v_caller_role user_role;
BEGIN
  v_caller_id := auth.uid();

  -- Must be authenticated
  IF v_caller_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'UNAUTHENTICATED');
  END IF;

  -- Must be an admin
  SELECT role INTO v_caller_role
  FROM public.profiles
  WHERE id = v_caller_id;

  IF v_caller_role != 'admin' THEN
    RETURN jsonb_build_object(
      'success', false,
      'error_code', 'UNAUTHORIZED',
      'message', 'Only administrators can change user roles.'
    );
  END IF;

  -- Prevent admins from demoting other admins (safety measure)
  IF EXISTS (
    SELECT 1 FROM public.profiles 
    WHERE id = p_target_user_id AND role = 'admin'
  ) AND p_new_role != 'admin' THEN
    RETURN jsonb_build_object(
      'success', false,
      'error_code', 'CANNOT_DEMOTE_ADMIN',
      'message', 'Cannot demote another admin through this function.'
    );
  END IF;

  UPDATE public.profiles
  SET role = p_new_role
  WHERE id = p_target_user_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object(
      'success', false,
      'error_code', 'USER_NOT_FOUND',
      'message', 'Target user not found.'
    );
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'target_user_id', p_target_user_id,
    'new_role', p_new_role
  );
END;
$function$;

REVOKE ALL ON FUNCTION "public"."elevate_user_role"(uuid, public.user_role) FROM PUBLIC, "anon";

CREATE OR REPLACE FUNCTION public.get_driver_bookings (
  p_status public.booking_status DEFAULT NULL::public.booking_status,
  p_limit  integer               DEFAULT 20,
  p_offset integer               DEFAULT 0
)
  RETURNS TABLE (
    booking_id      uuid,
    space_id        uuid,
    space_name      text,
    space_address   text,
    space_city      text,
    space_image_url text,
    starts_at       timestamp with time zone,
    ends_at         timestamp with time zone,
    duration_hours  numeric,
    price_per_hour  integer,
    total_price     integer,
    vehicle_type    public.vehicle_type,
    vehicle_plate   text,
    status          public.booking_status,
    created_at      timestamp with time zone,
    cancelled_at    timestamp with time zone
  )
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_driver_id UUID;
BEGIN
  v_driver_id := auth.uid();

  IF v_driver_id IS NULL THEN
    RAISE EXCEPTION 'UNAUTHENTICATED: You must be logged in.';
  END IF;

  RETURN QUERY
  SELECT
    b.id             AS booking_id,
    b.space_id,
    ps.name          AS space_name,
    ps.address_line1 AS space_address,
    ps.city          AS space_city,
    -- Return the first image URL or NULL
    CASE WHEN array_length(ps.image_urls, 1) > 0 
         THEN ps.image_urls[1] 
         ELSE NULL 
    END              AS space_image_url,
    b.starts_at,
    b.ends_at,
    b.duration_hours,
    b.price_per_hour,
    b.total_price,
    b.vehicle_type,
    b.vehicle_plate,
    b.status,
    b.created_at,
    b.cancelled_at
  FROM public.bookings b
  JOIN public.parking_spaces ps ON ps.id = b.space_id
  WHERE
    b.driver_id = v_driver_id
    AND (p_status IS NULL OR b.status = p_status)
  ORDER BY b.created_at DESC
  LIMIT p_limit
  OFFSET p_offset;
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_own_protected_profile_fields()
  RETURNS TABLE (
    role         public.user_role,
    is_active    boolean,
    tos_accepted boolean
  )
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  SELECT role, is_active, tos_accepted
  FROM public.profiles
  WHERE id = auth.uid();
$function$;

REVOKE ALL ON FUNCTION "public"."get_own_protected_profile_fields"() FROM PUBLIC, "anon";

CREATE OR REPLACE FUNCTION public.get_space_bookings (
  p_space_id uuid,
  p_status   public.booking_status DEFAULT NULL::public.booking_status,
  p_limit    integer               DEFAULT 50,
  p_offset   integer               DEFAULT 0
)
  RETURNS TABLE (
    booking_id     uuid,
    driver_name    text,
    driver_phone   text,
    starts_at      timestamp with time zone,
    ends_at        timestamp with time zone,
    duration_hours numeric,
    total_price    integer,
    vehicle_type   public.vehicle_type,
    vehicle_plate  text,
    status         public.booking_status,
    created_at     timestamp with time zone
  )
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_caller_id UUID;
  v_space_owner_id UUID;
BEGIN
  v_caller_id := auth.uid();

  IF v_caller_id IS NULL THEN
    RAISE EXCEPTION 'UNAUTHENTICATED';
  END IF;

  -- Verify the space exists and get its owner
  SELECT owner_id INTO v_space_owner_id
  FROM public.parking_spaces
  WHERE id = p_space_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'SPACE_NOT_FOUND';
  END IF;

  -- Only the owner or admin can see a space's bookings
  IF v_space_owner_id != v_caller_id AND NOT EXISTS (
    SELECT 1 FROM public.profiles WHERE id = v_caller_id AND role = 'admin'
  ) THEN
    RAISE EXCEPTION 'UNAUTHORIZED';
  END IF;

  RETURN QUERY
  SELECT
    b.id           AS booking_id,
    p.full_name    AS driver_name,
    p.phone        AS driver_phone,
    b.starts_at,
    b.ends_at,
    b.duration_hours,
    b.total_price,
    b.vehicle_type,
    b.vehicle_plate,
    b.status,
    b.created_at
  FROM public.bookings b
  JOIN public.profiles p ON p.id = b.driver_id
  WHERE
    b.space_id = p_space_id
    AND (p_status IS NULL OR b.status = p_status)
  ORDER BY b.starts_at DESC
  LIMIT p_limit
  OFFSET p_offset;
END;
$function$;

CREATE OR REPLACE FUNCTION public.handle_new_user()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO ''
  AS $function$
BEGIN
    INSERT INTO public.profiles (id, full_name, role)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data ->> 'full_name', ''),
        'driver'
    );
    RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.search_parking_spaces (
  p_lat          numeric,
  p_lng          numeric,
  p_radius_km    numeric                  DEFAULT 5.0,
  p_starts_at    timestamp with time zone DEFAULT NULL::timestamp WITH time zone,
  p_ends_at      timestamp with time zone DEFAULT NULL::timestamp WITH time zone,
  p_vehicle_type public.vehicle_type      DEFAULT NULL::public.vehicle_type,
  p_max_price    integer                  DEFAULT NULL::integer,
  p_covered_only boolean                  DEFAULT false,
  p_ev_charging  boolean                  DEFAULT false,
  p_limit        integer                  DEFAULT 20,
  p_offset       integer                  DEFAULT 0
)
  RETURNS TABLE (
    id                   uuid,
    name                 text,
    description          text,
    address_line1        text,
    city                 text,
    latitude             numeric,
    longitude            numeric,
    price_per_hour       integer,
    total_capacity       integer,
    available_spots      integer,
    max_vehicle_type     public.vehicle_type,
    is_covered           boolean,
    is_gated             boolean,
    has_cctv             boolean,
    has_lighting         boolean,
    has_ev_charging      boolean,
    is_accessible        boolean,
    avg_rating           numeric,
    review_count         integer,
    image_urls           text[],
    distance_meters      numeric,
    recommendation_score numeric
  )
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_search_point GEOGRAPHY;
BEGIN
  IF p_lat IS NULL OR p_lng IS NULL THEN
    RAISE EXCEPTION 'Latitude and longitude are required.';
  END IF;

  IF p_radius_km IS NULL OR p_radius_km <= 0 OR p_radius_km > 50 THEN
    RAISE EXCEPTION 'radius_km must be a positive number between 0 and 50.';
  END IF;

  IF p_limit IS NULL OR p_limit < 1 OR p_limit > 100 THEN
    RAISE EXCEPTION 'limit must be an integer between 1 and 100.';
  END IF;

  IF p_offset IS NULL OR p_offset < 0 THEN
    RAISE EXCEPTION 'offset must be a non-negative integer.';
  END IF;

  IF p_starts_at IS NOT NULL AND p_ends_at IS NOT NULL AND p_starts_at >= p_ends_at THEN
    RAISE EXCEPTION 'starts_at must be before ends_at.';
  END IF;

  -- Build the search origin point from the provided coordinates
  v_search_point := ST_MakePoint(p_lng, p_lat)::GEOGRAPHY;

  RETURN QUERY
  WITH space_availability AS (
    -- Pre-compute availability for each candidate space
    SELECT
      ps.id AS space_id,
      CASE
        WHEN p_starts_at IS NOT NULL AND p_ends_at IS NOT NULL THEN
          public.check_space_availability(ps.id, p_starts_at, p_ends_at)
        ELSE
          ps.total_capacity  -- no time filter: show total capacity
      END AS available_count
    FROM public.parking_spaces ps
    WHERE
      ps.status = 'active'
      -- Radius filter using PostGIS — ST_DWithin is extremely efficient with GIST index
      AND ST_DWithin(ps.location, v_search_point, p_radius_km * 1000)
  ),
  estimated_price AS (
    -- Pre-compute total estimated price for ordering
    SELECT
      ps.id AS space_id,
      CASE
        WHEN p_starts_at IS NOT NULL AND p_ends_at IS NOT NULL THEN
          CEIL(EXTRACT(EPOCH FROM (p_ends_at - p_starts_at)) / 3600.0) * ps.price_per_hour
        ELSE
          ps.price_per_hour  -- show hourly rate when no duration given
      END AS est_total_price
    FROM public.parking_spaces ps
    WHERE ps.status = 'active'
  )
  SELECT
    ps.id,
    ps.name,
    ps.description,
    ps.address_line1,
    ps.city,
    ps.latitude,
    ps.longitude,
    ps.price_per_hour,
    ps.total_capacity,
    sa.available_count::INTEGER AS available_spots,
    ps.max_vehicle_type,
    ps.is_covered,
    ps.is_gated,
    ps.has_cctv,
    ps.has_lighting,
    ps.has_ev_charging,
    ps.is_accessible,
    ps.avg_rating,
    ps.review_count,
    ps.image_urls,
    -- Distance from search point to parking space, in metres
    ST_Distance(ps.location, v_search_point)::NUMERIC AS distance_meters,

    -- ---------------------------------------------------------------------------
    -- Recommendation Score (lower = better match)
    -- Factors:
    --   1. Distance: normalized to 0-1 scale over the search radius
    --   2. Price: normalized to 0-1 over a max reference price (₹500/hr = 50000 paisa)
    --   3. Rating: inverted (5 stars = 0 penalty, no rating = 0.5 penalty)
    --   4. Availability ratio: fully available = lower score (preferred)
    --
    -- Weights can be tuned based on user feedback.
    -- ---------------------------------------------------------------------------
    ROUND(
      (
        -- 40% weight: distance penalty (closer is better)
        0.40 * (ST_Distance(ps.location, v_search_point) / (p_radius_km * 1000))
        +
        -- 35% weight: price penalty (cheaper is better)
        0.35 * LEAST(ep.est_total_price::NUMERIC / 50000.0, 1.0)
        +
        -- 15% weight: rating bonus (higher rating is better = lower score)
        0.15 * CASE
          WHEN ps.avg_rating IS NULL THEN 0.5
          ELSE (5.0 - ps.avg_rating) / 5.0
        END
        +
        -- 10% weight: availability ratio (more available = slightly preferred)
        0.10 * CASE
          WHEN ps.total_capacity = 0 THEN 1.0
          ELSE 1.0 - (sa.available_count::NUMERIC / ps.total_capacity)
        END
      )::NUMERIC,
      4
    ) AS recommendation_score

  FROM public.parking_spaces ps
  JOIN space_availability sa ON sa.space_id = ps.id
  JOIN estimated_price ep ON ep.space_id = ps.id
  WHERE
    ps.status = 'active'

    -- Availability filter: only show spaces with at least 1 spot
    AND sa.available_count > 0

    -- Vehicle compatibility filter
    AND (
      p_vehicle_type IS NULL
      OR CASE ps.max_vehicle_type
        WHEN 'motorcycle' THEN p_vehicle_type = 'motorcycle'
        WHEN 'compact'    THEN p_vehicle_type IN ('motorcycle', 'compact')
        WHEN 'sedan'      THEN p_vehicle_type IN ('motorcycle', 'compact', 'sedan')
        WHEN 'suv'        THEN p_vehicle_type IN ('motorcycle', 'compact', 'sedan', 'suv')
        WHEN 'van'        THEN p_vehicle_type IN ('motorcycle', 'compact', 'sedan', 'suv', 'van')
        WHEN 'truck'      THEN p_vehicle_type IN ('motorcycle', 'compact', 'sedan', 'suv', 'van', 'truck')
        WHEN 'electric'   THEN p_vehicle_type IN ('motorcycle', 'compact', 'sedan', 'suv', 'electric')
        ELSE FALSE
      END
    )

    -- Price filter (max total price in paisa)
    AND (p_max_price IS NULL OR ep.est_total_price <= p_max_price)

    -- Amenity filters
    AND (NOT p_covered_only OR ps.is_covered = TRUE)
    AND (NOT p_ev_charging OR ps.has_ev_charging = TRUE)

  ORDER BY
    recommendation_score ASC   -- best matches first

  LIMIT p_limit
  OFFSET p_offset;
END;
$function$;

CREATE OR REPLACE FUNCTION public.set_updated_at()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SET search_path TO ''
  AS $function$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$function$;

ALTER TABLE "public"."parking_spaces"
  ADD CONSTRAINT "parking_spaces_avg_rating_check" CHECK (((avg_rating >= (0)::numeric) AND (avg_rating <= (5)::numeric)));

ALTER TABLE "public"."bookings"
  ADD CONSTRAINT "bookings_space_id_fkey" FOREIGN KEY (space_id) REFERENCES public.parking_spaces(id) ON DELETE RESTRICT;

ALTER TABLE "public"."profiles"
  ADD CONSTRAINT "profiles_id_fkey" FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;

ALTER TABLE "public"."bookings"
  ADD CONSTRAINT "bookings_cancelled_by_fkey" FOREIGN KEY (cancelled_by) REFERENCES public.profiles(id);

ALTER TABLE "public"."bookings"
  ADD CONSTRAINT "bookings_driver_id_fkey" FOREIGN KEY (driver_id) REFERENCES public.profiles(id) ON DELETE RESTRICT;

ALTER TABLE "public"."parking_spaces"
  ADD CONSTRAINT "parking_spaces_owner_id_fkey" FOREIGN KEY (owner_id) REFERENCES public.profiles(id) ON DELETE CASCADE;

ALTER TABLE "public"."space_blocked_periods"
  ADD CONSTRAINT "space_blocked_periods_space_id_fkey" FOREIGN KEY (space_id) REFERENCES public.parking_spaces(id) ON DELETE CASCADE;

CREATE VIEW "public"."active_parking_spaces" AS  SELECT id,
    name,
    description,
    address_line1,
    address_line2,
    city,
    state,
    country,
    postal_code,
    latitude,
    longitude,
    price_per_hour,
    total_capacity,
    max_vehicle_type,
    is_covered,
    is_gated,
    has_cctv,
    has_lighting,
    has_ev_charging,
    is_accessible,
    operating_hours,
    avg_rating,
    review_count,
    image_urls,
    created_at
   FROM public.parking_spaces ps
  WHERE (status = 'active'::public.space_status);

CREATE VIEW "public"."my_bookings" AS  SELECT b.id AS booking_id,
    b.space_id,
    ps.name AS space_name,
    ps.address_line1 AS space_address,
    ps.city AS space_city,
    ps.latitude AS space_latitude,
    ps.longitude AS space_longitude,
        CASE
            WHEN (array_length(ps.image_urls, 1) > 0) THEN ps.image_urls[1]
            ELSE NULL::text
        END AS space_image_url,
    b.starts_at,
    b.ends_at,
    b.duration_hours,
    b.price_per_hour,
    b.total_price,
    b.vehicle_type,
    b.vehicle_plate,
    b.driver_notes,
    b.status,
    b.payment_status,
    b.cancelled_at,
    b.cancellation_reason,
    b.created_at
   FROM (public.bookings b
     JOIN public.parking_spaces ps ON ((ps.id = b.space_id)))
  WHERE (b.driver_id = auth.uid());

CREATE VIEW "public"."my_profile" AS  SELECT p.id,
    p.full_name,
    p.phone,
    p.role,
    p.avatar_url,
    p.preferred_vehicle,
    p.tos_accepted,
    p.is_active,
    p.created_at,
    u.email
   FROM (public.profiles p
     JOIN auth.users u ON ((u.id = p.id)))
  WHERE (p.id = auth.uid());

CREATE VIEW "public"."my_spaces" AS  SELECT id,
    owner_id,
    name,
    description,
    address_line1,
    address_line2,
    city,
    state,
    country,
    postal_code,
    location,
    latitude,
    longitude,
    total_capacity,
    price_per_hour,
    max_vehicle_type,
    is_covered,
    is_gated,
    has_cctv,
    has_lighting,
    has_ev_charging,
    is_accessible,
    operating_hours,
    status,
    image_urls,
    avg_rating,
    review_count,
    created_at,
    updated_at,
    ( SELECT count(*) AS count
           FROM public.bookings b
          WHERE ((b.space_id = ps.id) AND (b.status = ANY (ARRAY['pending'::public.booking_status, 'confirmed'::public.booking_status])))) AS active_booking_count
   FROM public.parking_spaces ps
  WHERE (owner_id = auth.uid());

CREATE INDEX idx_blocked_periods_range ON public.space_blocked_periods USING btree (space_id, blocked_from, blocked_until);

CREATE INDEX idx_blocked_periods_space_id ON public.space_blocked_periods USING btree (space_id);

CREATE INDEX idx_bookings_driver_id ON public.bookings USING btree (driver_id, created_at DESC);

CREATE INDEX idx_bookings_space_id ON public.bookings USING btree (space_id, starts_at, ends_at);

CREATE INDEX idx_bookings_starts_at ON public.bookings USING btree (starts_at)
  WHERE (status = ANY (ARRAY['pending'::public.booking_status, 'confirmed'::public.booking_status]));

CREATE INDEX idx_bookings_status ON public.bookings USING btree (status);

CREATE INDEX idx_parking_spaces_city_status ON public.parking_spaces USING btree (city, status);

CREATE INDEX idx_parking_spaces_location ON public.parking_spaces USING gist (location);

CREATE INDEX idx_parking_spaces_owner ON public.parking_spaces USING btree (owner_id);

CREATE INDEX idx_parking_spaces_status ON public.parking_spaces USING btree (status);

CREATE INDEX idx_parking_spaces_vehicle_type ON public.parking_spaces USING btree (max_vehicle_type);

CREATE INDEX idx_profiles_role ON public.profiles USING btree (ROLE);

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

CREATE TRIGGER set_bookings_updated_at
  BEFORE UPDATE ON public.bookings
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER set_parking_spaces_updated_at
  BEFORE UPDATE ON public.parking_spaces
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE TRIGGER set_profiles_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE POLICY "bookings_no_direct_insert" ON "public"."bookings"
  FOR INSERT
  TO PUBLIC
  WITH CHECK (false);

CREATE POLICY "bookings_no_direct_update" ON "public"."bookings"
  FOR UPDATE
  TO PUBLIC
  USING (false);

CREATE POLICY "bookings_select_admin" ON "public"."bookings"
  FOR SELECT
  TO PUBLIC
  USING ((EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = auth.uid()) AND (profiles.role = 'admin'::public.user_role)))));

CREATE POLICY "bookings_select_driver_own" ON "public"."bookings"
  FOR SELECT
  TO PUBLIC
  USING ((auth.uid() = driver_id));

CREATE POLICY "bookings_select_space_owner" ON "public"."bookings"
  FOR SELECT
  TO PUBLIC
  USING ((EXISTS ( SELECT 1
   FROM public.parking_spaces ps
  WHERE ((ps.id = bookings.space_id) AND (ps.owner_id = auth.uid())))));

CREATE POLICY "spaces_delete_owner" ON "public"."parking_spaces"
  FOR DELETE
  TO PUBLIC
  USING ((auth.uid() = owner_id));

CREATE POLICY "spaces_insert_owner" ON "public"."parking_spaces"
  FOR INSERT
  TO PUBLIC
  WITH CHECK (((auth.uid() = owner_id) AND (EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = auth.uid()) AND (profiles.role = ANY (ARRAY['owner'::public.user_role, 'admin'::public.user_role])))))));

CREATE POLICY "spaces_select_active" ON "public"."parking_spaces"
  FOR SELECT
  TO PUBLIC
  USING ((status = 'active'::public.space_status));

CREATE POLICY "spaces_select_admin" ON "public"."parking_spaces"
  FOR SELECT
  TO PUBLIC
  USING ((EXISTS ( SELECT 1
   FROM public.profiles
  WHERE ((profiles.id = auth.uid()) AND (profiles.role = 'admin'::public.user_role)))));

CREATE POLICY "spaces_select_own" ON "public"."parking_spaces"
  FOR SELECT
  TO PUBLIC
  USING ((auth.uid() = owner_id));

CREATE POLICY "spaces_update_owner" ON "public"."parking_spaces"
  FOR UPDATE
  TO PUBLIC
  USING ((auth.uid() = owner_id))
  WITH CHECK ((auth.uid() = owner_id));

CREATE POLICY "profiles_select_own_or_admin" ON "public"."profiles"
  FOR SELECT
  TO PUBLIC
  USING (((auth.uid() = id) OR (EXISTS ( SELECT 1
   FROM public.profiles p
  WHERE ((p.id = auth.uid()) AND (p.role = 'admin'::public.user_role))))));

CREATE POLICY "profiles_update_own_safe" ON "public"."profiles"
  FOR UPDATE
  TO PUBLIC
  USING ((auth.uid() = id))
  WITH CHECK (((auth.uid() = id) AND (role = ( SELECT p.role
   FROM public.get_own_protected_profile_fields() p(role, is_active, tos_accepted))) AND (is_active = ( SELECT p.is_active
   FROM public.get_own_protected_profile_fields() p(role, is_active, tos_accepted))) AND ((tos_accepted = true) OR (tos_accepted = ( SELECT p.tos_accepted
   FROM public.get_own_protected_profile_fields() p(role, is_active, tos_accepted))))));

CREATE POLICY "blocked_manage_owner" ON "public"."space_blocked_periods"
  FOR ALL
  TO PUBLIC
  USING ((EXISTS ( SELECT 1
   FROM public.parking_spaces ps
  WHERE ((ps.id = space_blocked_periods.space_id) AND (ps.owner_id = auth.uid())))));

CREATE POLICY "blocked_select_all" ON "public"."space_blocked_periods"
  FOR SELECT
  TO PUBLIC
  USING (true);

COMMENT ON EXTENSION "btree_gist" IS 'support for indexing common datatypes in GiST';

COMMENT ON EXTENSION "postgis" IS 'PostGIS geometry and geography spatial types and functions';

GRANT EXECUTE ON FUNCTION "public"."calculate_booking_price"(uuid, timestamp WITH time zone, timestamp WITH time zone) TO "authenticated";

REVOKE ALL ON FUNCTION "public"."calculate_booking_price"(uuid, timestamp WITH time zone, timestamp WITH time zone) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."calculate_booking_price"(uuid, timestamp WITH time zone, timestamp WITH time zone) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."calculate_booking_price"(uuid, timestamp WITH time zone, timestamp WITH time zone) TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."cancel_booking"(uuid, text) TO "authenticated";

REVOKE ALL ON FUNCTION "public"."cancel_booking"(uuid, text) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."cancel_booking"(uuid, text) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."cancel_booking"(uuid, text) TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."check_space_availability"(uuid, timestamp WITH time zone, timestamp WITH time zone) TO "authenticated";

REVOKE ALL ON FUNCTION "public"."check_space_availability"(uuid, timestamp WITH time zone, timestamp WITH time zone) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."check_space_availability"(uuid, timestamp WITH time zone, timestamp WITH time zone) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."check_space_availability"(uuid, timestamp WITH time zone, timestamp WITH time zone) TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."create_booking"(uuid, timestamp WITH time zone, timestamp WITH time zone, public.vehicle_type, text, text) TO "authenticated";

REVOKE ALL ON FUNCTION "public"."create_booking"(uuid, timestamp WITH time zone, timestamp WITH time zone, public.vehicle_type, text, text) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."create_booking"(uuid, timestamp WITH time zone, timestamp WITH time zone, public.vehicle_type, text, text) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."create_booking"(uuid, timestamp WITH time zone, timestamp WITH time zone, public.vehicle_type, text, text) TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."deactivate_user"(uuid, text) TO "authenticated";

REVOKE ALL ON FUNCTION "public"."deactivate_user"(uuid, text) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."deactivate_user"(uuid, text) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."deactivate_user"(uuid, text) TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."elevate_user_role"(uuid, public.user_role) TO "authenticated";

REVOKE ALL ON FUNCTION "public"."elevate_user_role"(uuid, public.user_role) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."elevate_user_role"(uuid, public.user_role) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."elevate_user_role"(uuid, public.user_role) TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."get_driver_bookings"(public.booking_status, integer, integer) TO PUBLIC, "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."get_driver_bookings"(public.booking_status, integer, integer) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."get_driver_bookings"(public.booking_status, integer, integer) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."get_driver_bookings"(public.booking_status, integer, integer) TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."get_own_protected_profile_fields"() TO "authenticated";

REVOKE ALL ON FUNCTION "public"."get_own_protected_profile_fields"() FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."get_own_protected_profile_fields"() TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."get_own_protected_profile_fields"() TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."get_space_bookings"(uuid, public.booking_status, integer, integer) TO PUBLIC, "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."get_space_bookings"(uuid, public.booking_status, integer, integer) FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."get_space_bookings"(uuid, public.booking_status, integer, integer) TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."get_space_bookings"(uuid, public.booking_status, integer, integer) TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."handle_new_user"() TO PUBLIC, "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."handle_new_user"() FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."handle_new_user"() TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."handle_new_user"() TO "service_role";

GRANT EXECUTE
  ON FUNCTION "public"."search_parking_spaces"(numeric, numeric, numeric, timestamp WITH time zone, timestamp
    WITH time zone, public.vehicle_type, integer, boolean, boolean, integer, integer)
  TO PUBLIC, "anon", "authenticated";

REVOKE ALL
  ON FUNCTION "public"."search_parking_spaces"(numeric, numeric, numeric, timestamp WITH time zone, timestamp
    WITH time zone, public.vehicle_type, integer, boolean, boolean, integer, integer)
  FROM "postgres";

GRANT EXECUTE
  ON FUNCTION "public"."search_parking_spaces"(numeric, numeric, numeric, timestamp WITH time zone, timestamp
    WITH time zone, public.vehicle_type, integer, boolean, boolean, integer, integer)
  TO "postgres";

GRANT EXECUTE
  ON FUNCTION "public"."search_parking_spaces"(numeric, numeric, numeric, timestamp WITH time zone, timestamp
    WITH time zone, public.vehicle_type, integer, boolean, boolean, integer, integer)
  TO "service_role";

GRANT EXECUTE ON FUNCTION "public"."set_updated_at"() TO PUBLIC, "anon", "authenticated";

REVOKE ALL ON FUNCTION "public"."set_updated_at"() FROM "postgres";

GRANT EXECUTE ON FUNCTION "public"."set_updated_at"() TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."set_updated_at"() TO "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."bookings" TO "anon", "authenticated";

REVOKE ALL ON TABLE "public"."bookings" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."bookings" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."bookings" TO "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."parking_spaces" TO "anon", "authenticated";

REVOKE ALL ON TABLE "public"."parking_spaces" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."parking_spaces" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."parking_spaces" TO "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."profiles" TO "anon", "authenticated";

REVOKE ALL ON TABLE "public"."profiles" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."profiles" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."profiles" TO "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."space_blocked_periods" TO "anon", "authenticated";

REVOKE ALL ON TABLE "public"."space_blocked_periods" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."space_blocked_periods" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."space_blocked_periods" TO "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."active_parking_spaces" TO "anon", "authenticated";

REVOKE ALL ON TABLE "public"."active_parking_spaces" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."active_parking_spaces" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."active_parking_spaces" TO "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."my_bookings" TO "anon", "authenticated";

REVOKE ALL ON TABLE "public"."my_bookings" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."my_bookings" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."my_bookings" TO "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."my_profile" TO "anon", "authenticated";

REVOKE ALL ON TABLE "public"."my_profile" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."my_profile" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."my_profile" TO "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."my_spaces" TO "anon", "authenticated";

REVOKE ALL ON TABLE "public"."my_spaces" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."my_spaces" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."my_spaces" TO "service_role";

