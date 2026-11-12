SELECT
    conrelid::regclass AS table_name,
    conname AS constraint_name,
    pg_get_constraintdef(oid) AS rule
FROM pg_constraint
WHERE conrelid IN (
    'public.facilities'::regclass,
    'public.facility_floors'::regclass,
    'public.facility_zones'::regclass,
    'public.parking_spaces'::regclass
)
AND contype = 'c'
AND conname LIKE '%qr_code_id%';