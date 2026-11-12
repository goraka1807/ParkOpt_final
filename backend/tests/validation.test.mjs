import fs from 'node:fs';
import path from 'node:path';
import test from 'node:test';
import assert from 'node:assert/strict';

import {
  hasExplicitTimezone,
  isSecureQrCode,
  isValidUuid,
  parseBooleanInput,
  validateBookingPassRequest,
  validateBookingRequest,
  validateSearchRequest,
} from '../supabase/functions/shared/validation.mjs';

const readMigration = (filename) => fs.readFileSync(path.join(process.cwd(), 'backend', 'supabase', 'migrations', filename), 'utf8');

test('timestamps require an explicit timezone', () => {
  assert.equal(hasExplicitTimezone('2026-11-01T10:00:00+05:30'), true);
  assert.equal(hasExplicitTimezone('2026-11-01T10:00:00'), false);
  assert.equal(hasExplicitTimezone('2026-11-01T10:00:00Z'), true);
});

test('boolean coercion does not treat string false as true', () => {
  assert.equal(parseBooleanInput('false'), false);
  assert.equal(parseBooleanInput('FALSE'), false);
  assert.equal(parseBooleanInput('true'), true);
  assert.equal(parseBooleanInput('0'), false);
  assert.equal(parseBooleanInput('1'), true);
  assert.equal(parseBooleanInput('nope', false), false);
});

test('UUID validation rejects malformed IDs', () => {
  assert.equal(isValidUuid('123e4567-e89b-42d3-a456-426614174000'), true);
  assert.equal(isValidUuid('not-a-uuid'), false);
});

test('search validation rejects invalid coordinates and zero radius', () => {
  const result = validateSearchRequest({
    lat: 90.1,
    lng: 77.5946,
    radius_km: 0,
    starts_at: '2026-11-01T10:00:00+05:30',
    ends_at: '2026-11-01T14:00:00+05:30',
    vehicle_type: 'sedan',
    limit: 20,
    offset: 0,
  });

  assert.equal(result.valid, false);
  assert.match(result.errors.join(' '), /lat|radius_km/);
});

test('search validation accepts valid search input and preserves boolean semantics', () => {
  const result = validateSearchRequest({
    lat: 12.9716,
    lng: 77.5946,
    radius_km: 5,
    starts_at: '2026-11-01T10:00:00+05:30',
    ends_at: '2026-11-01T14:00:00+05:30',
    vehicle_type: 'sedan',
    covered_only: 'false',
    ev_charging: 'false',
    limit: 20,
    offset: 0,
  });

  assert.equal(result.valid, true);
  assert.equal(result.normalized.covered_only, false);
  assert.equal(result.normalized.ev_charging, false);
});

test('booking validation accepts valid payload and rejects invalid type or time window', () => {
  const valid = validateBookingRequest({
    space_id: '123e4567-e89b-42d3-a456-426614174000',
    starts_at: '2026-11-01T10:00:00+05:30',
    ends_at: '2026-11-01T12:00:00+05:30',
    vehicle_type: 'sedan',
  });

  assert.equal(valid.valid, true);

  const invalid = validateBookingRequest({
    space_id: 'not-a-uuid',
    starts_at: '2026-11-01T10:00:00',
    ends_at: '2026-11-01T09:00:00',
    vehicle_type: 'wagon',
  });

  assert.equal(invalid.valid, false);
  assert.match(invalid.errors.join(' '), /space_id|timezone|vehicle_type|ends_at/);
});

test('facility and booking QR identifiers use secure ParkOpt patterns', () => {
  assert.equal(isSecureQrCode('parkopt_fac_9f8a3d1b1c2e'), true);
  assert.equal(isSecureQrCode('parkopt_space_82b72c1d4e29', 'space'), true);
  assert.equal(isSecureQrCode('parkopt_pass_8a7b9c6d5e4f9a1b2c3d4e5f6a7b8c9d', 'booking_pass'), true);
  assert.equal(isSecureQrCode('facility-123', 'facility'), false);
  assert.equal(isSecureQrCode('parkopt_pass_user-123', 'booking_pass'), false);
});

test('booking pass validation rejects unsafe tokens and accepts secure ones', () => {
  const valid = validateBookingPassRequest({ token: 'parkopt_pass_8a7b9c6d5e4f9a1b2c3d4e5f6a7b8c9d' });
  const invalid = validateBookingPassRequest({ token: 'user@example.com' });
  const reusedUserToken = validateBookingPassRequest({ token: 'parkopt_pass_user-123' });

  assert.equal(valid.valid, true);
  assert.equal(invalid.valid, false);
  assert.equal(reusedUserToken.valid, false);
  assert.match(invalid.errors.join(' '), /valid ParkOpt/);
});

test('migration 009 enforces safe facility backfill and hierarchy constraints', () => {
  const sql = readMigration('009_phase1_facility_qr_upgrade.sql');

  assert.match(sql, /CASE v_row\.status[\s\S]*WHEN 'pending_review' THEN 'inactive'/i);
  assert.match(sql, /public\.generate_secure_qr_code\(p_prefix TEXT\)/);
  assert.match(sql, /validate_facility_hierarchy\(\)/);
  assert.match(sql, /ALTER TABLE public\.parking_spaces\s+ALTER COLUMN facility_id SET NOT NULL/i);
  assert.match(sql, /CREATE POLICY "facility_floors_select_public_active"/);
  assert.match(sql, /CREATE POLICY "facility_zones_select_public_active"/);
});

test('migration 010 restricts pass generation and verification to authenticated callers', () => {
  const sql = readMigration('010_phase1_qr_security_and_pass_fixes.sql');

  assert.match(sql, /REVOKE EXECUTE ON FUNCTION public\.generate_booking_pass\(UUID\) FROM PUBLIC/i);
  assert.match(sql, /REVOKE EXECUTE ON FUNCTION public\.verify_booking_pass\(TEXT\) FROM PUBLIC/i);
  assert.match(sql, /auth\.uid\(\)/i);
  assert.match(sql, /current_setting\('role', true\) = 'service_role'/i);
  assert.match(sql, /gen_random_bytes\(32\)/i);
  assert.match(sql, /status IN \('revoked', 'used'\)/i);
});
