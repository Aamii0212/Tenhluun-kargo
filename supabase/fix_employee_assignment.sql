-- Ажилтны салбар оноох RPC засвар
-- Supabase Dashboard → SQL Editor дээр бүхэлд нь RUN хийнэ.
-- Auth хэрэглэгч байхгүй бол эхлээд Authentication → Users хэсгээс ажилтны имэйлээр хэрэглэгч урьж/үүсгэнэ.

CREATE OR REPLACE FUNCTION public.admin_assign_employee_branch(p_employee_email text, p_branch_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  target_id uuid;
  normalized_email text := lower(btrim(coalesce(p_employee_email, '')));
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.id = auth.uid() AND p.role = 'admin'
  ) THEN
    RAISE EXCEPTION 'Зөвхөн админ ажилтанд салбар онооно.';
  END IF;
  IF normalized_email = '' THEN
    RAISE EXCEPTION 'Ажилтны имэйл оруулна уу.';
  END IF;
  SELECT u.id INTO target_id
  FROM auth.users u
  WHERE lower(u.email) = normalized_email
  LIMIT 1;
  IF target_id IS NULL THEN
    RAISE EXCEPTION 'Энэ имэйл Supabase Auth-д бүртгэлгүй байна. Authentication → Users хэсгээс эхлээд ажилтны имэйлээр хэрэглэгч урьж/үүсгэнэ үү.';
  END IF;
  INSERT INTO public.profiles (id, role)
  VALUES (target_id, 'employee')
  ON CONFLICT (id) DO UPDATE
    SET role = CASE WHEN public.profiles.role = 'admin' THEN 'admin' ELSE 'employee' END;
  IF NOT EXISTS (SELECT 1 FROM public.branches b WHERE b.id = p_branch_id) THEN
    RAISE EXCEPTION 'Салбар олдсонгүй.';
  END IF;
  INSERT INTO public.employee_branch_access(employee_id, branch_id, employee_email)
  VALUES (target_id, p_branch_id, normalized_email)
  ON CONFLICT (employee_id, branch_id)
  DO UPDATE SET employee_email = EXCLUDED.employee_email;
  RETURN target_id;
END;
$$;
REVOKE ALL ON FUNCTION public.admin_assign_employee_branch(text, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_assign_employee_branch(text, uuid) TO authenticated;
NOTIFY pgrst, 'reload schema';
