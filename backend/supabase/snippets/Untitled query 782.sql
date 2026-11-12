UPDATE public.profiles
SET role = 'owner'
WHERE id = 'b55d1215-53e9-4f89-aa10-5576576ec2d9'
RETURNING id, role;