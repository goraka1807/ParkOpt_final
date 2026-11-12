-- Check allowed facility types and statuses
SELECT
  t.typname AS enum_name,
  e.enumlabel AS allowed_value
FROM pg_type t
JOIN pg_enum e ON e.enumtypid = t.oid
WHERE t.typname IN (
  'facility_kind',
  'facility_status',
  'space_status'
)
ORDER BY t.typname, e.enumsortorder;

-- Check existing local data
SELECT 'auth.users' AS table_name, COUNT(*) AS row_count FROM auth.users
UNION ALL
SELECT 'public.profiles', COUNT(*) FROM public.profiles
UNION ALL
SELECT 'public.facilities', COUNT(*) FROM public.facilities
UNION ALL
SELECT 'public.facility_floors', COUNT(*) FROM public.facility_floors
UNION ALL
SELECT 'public.facility_zones', COUNT(*) FROM public.facility_zones
UNION ALL
SELECT 'public.parking_spaces', COUNT(*) FROM public.parking_spaces;