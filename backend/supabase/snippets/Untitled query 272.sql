SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
AND table_name IN (
  'facilities',
  'facility_floors',
  'facility_zones',
  'parking_spaces',
  'booking_passes'
)
ORDER BY table_name;