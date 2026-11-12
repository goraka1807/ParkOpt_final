SELECT
    name,
    qr_code_id,
    public.resolve_qr_reference(qr_code_id) AS resolver_result
FROM public.parking_spaces
ORDER BY name;