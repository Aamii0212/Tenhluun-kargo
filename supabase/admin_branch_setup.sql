-- Тэнхлүүн Карго: салбарын бүртгэлийн огноо + давхар трак кодын хамгаалалт
-- Supabase Dashboard → SQL Editor дээр энэ файлыг бүхэлд нь нэг удаа ажиллуул.

ALTER TABLE public.parcels
ADD COLUMN IF NOT EXISTS arrival_date date;
NOTIFY pgrst, 'reload schema';


-- Одоогийн хуучин давхардсан бүртгэлийг устгахгүй; зөвхөн цаашдын INSERT/UPDATE-г хориглоно.

CREATE OR REPLACE FUNCTION public.prevent_duplicate_cargo_tracking_code()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  normalized_code text;
BEGIN
  normalized_code := upper(regexp_replace(btrim(coalesce(NEW.tracking_code, '')), '\s+', '', 'g'));

  IF normalized_code = '' THEN
    RAISE EXCEPTION 'Трак код хоосон байж болохгүй.'
      USING ERRCODE = '23514';
  END IF;

  -- Ижил кодын зэрэгцээ орж ирсэн хүсэлтүүдийг дарааллуулна.
  PERFORM pg_advisory_xact_lock(hashtextextended(normalized_code, 0));

  IF TG_TABLE_NAME = 'parcels' THEN
    IF EXISTS (
      SELECT 1 FROM public.parcels p
      WHERE upper(regexp_replace(btrim(coalesce(p.tracking_code, '')), '\s+', '', 'g')) = normalized_code
        AND p.id::text IS DISTINCT FROM NEW.id::text
    ) THEN
      RAISE EXCEPTION 'Энэ трак код өмнө нь бүртгэгдсэн: %', normalized_code
        USING ERRCODE = '23505';
    END IF;

    IF EXISTS (
      SELECT 1 FROM public.customer_pre_registrations r
      WHERE upper(regexp_replace(btrim(coalesce(r.tracking_code, '')), '\s+', '', 'g')) = normalized_code
        AND coalesce(r.status, 'pending') <> 'confirmed'
    ) THEN
      RAISE EXCEPTION 'Энэ трак код урьдчилан бүртгэгдсэн байна: %', normalized_code
        USING ERRCODE = '23505';
    END IF;
  ELSIF TG_TABLE_NAME = 'customer_pre_registrations' THEN
    IF EXISTS (
      SELECT 1 FROM public.customer_pre_registrations r
      WHERE upper(regexp_replace(btrim(coalesce(r.tracking_code, '')), '\s+', '', 'g')) = normalized_code
        AND r.id::text IS DISTINCT FROM NEW.id::text
    ) THEN
      RAISE EXCEPTION 'Энэ трак код урьдчилан бүртгэгдсэн байна: %', normalized_code
        USING ERRCODE = '23505';
    END IF;

    IF EXISTS (
      SELECT 1 FROM public.parcels p
      WHERE upper(regexp_replace(btrim(coalesce(p.tracking_code, '')), '\s+', '', 'g')) = normalized_code
    ) THEN
      RAISE EXCEPTION 'Энэ трак код ачаанд аль хэдийн бүртгэгдсэн байна: %', normalized_code
        USING ERRCODE = '23505';
    END IF;
  END IF;

  NEW.tracking_code := normalized_code;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS parcels_prevent_duplicate_tracking_code ON public.parcels;
CREATE TRIGGER parcels_prevent_duplicate_tracking_code
BEFORE INSERT OR UPDATE OF tracking_code ON public.parcels
FOR EACH ROW EXECUTE FUNCTION public.prevent_duplicate_cargo_tracking_code();

DROP TRIGGER IF EXISTS pre_registrations_prevent_duplicate_tracking_code ON public.customer_pre_registrations;
CREATE TRIGGER pre_registrations_prevent_duplicate_tracking_code
BEFORE INSERT OR UPDATE OF tracking_code ON public.customer_pre_registrations
FOR EACH ROW EXECUTE FUNCTION public.prevent_duplicate_cargo_tracking_code();

-- Давхардсан хуучин кодыг шалгах (устгахгүй):
-- SELECT upper(regexp_replace(btrim(tracking_code), '\s+', '', 'g')) AS code,
--        count(*) AS copies
-- FROM public.parcels
-- GROUP BY 1 HAVING count(*) > 1 ORDER BY copies DESC;
--
-- SELECT upper(regexp_replace(btrim(tracking_code), '\s+', '', 'g')) AS code,
--        count(*) AS copies
-- FROM public.customer_pre_registrations
-- GROUP BY 1 HAVING count(*) > 1 ORDER BY copies DESC;

NOTIFY pgrst, 'reload schema';


-- Ажилтан зөвхөн админаас оноосон салбарын ачаанд хандана.
CREATE TABLE IF NOT EXISTS public.employee_branch_access (
  employee_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  branch_id uuid NOT NULL REFERENCES public.branches(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (employee_id, branch_id)
);
ALTER TABLE public.employee_branch_access
  ADD COLUMN IF NOT EXISTS employee_email text;

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
  IF NOT EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin') THEN
    RAISE EXCEPTION 'Зөвхөн админ ажилтанд салбар онооно.';
  END IF;
  IF normalized_email = '' THEN
    RAISE EXCEPTION 'Ажилтны имэйл оруулна уу.';
  END IF;
  SELECT u.id INTO target_id
  FROM auth.users u
  JOIN public.profiles p ON p.id = u.id
  WHERE lower(u.email) = normalized_email AND p.role = 'employee'
  LIMIT 1;
  IF target_id IS NULL THEN
    RAISE EXCEPTION 'Энэ имэйлтэй employee эрхтэй хэрэглэгч олдсонгүй.';
  END IF;
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

CREATE INDEX IF NOT EXISTS employee_branch_access_branch_idx
  ON public.employee_branch_access(branch_id);

ALTER TABLE public.employee_branch_access ENABLE ROW LEVEL SECURITY;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.employee_branch_access TO authenticated;

DROP POLICY IF EXISTS employee_branch_access_read ON public.employee_branch_access;
CREATE POLICY employee_branch_access_read ON public.employee_branch_access
FOR SELECT TO authenticated
USING (
  employee_id = auth.uid()
  OR EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin')
);

DROP POLICY IF EXISTS employee_branch_access_admin_manage ON public.employee_branch_access;
CREATE POLICY employee_branch_access_admin_manage ON public.employee_branch_access
FOR ALL TO authenticated
USING (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin'))
WITH CHECK (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin'));

-- Нийтийн сайт салбаруудыг anon хэрэглэгчид харна; нэвтэрсэн ажилтан зөвхөн оноосон салбараа харна.
DROP POLICY IF EXISTS cargo_public_read_branches ON public.branches;
DROP POLICY IF EXISTS cargo_staff_read_branches ON public.branches;
CREATE POLICY cargo_public_read_branches ON public.branches
FOR SELECT TO anon USING (true);
CREATE POLICY cargo_staff_read_branches ON public.branches
FOR SELECT TO authenticated
USING (
  EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin')
  OR EXISTS (SELECT 1 FROM public.employee_branch_access a WHERE a.employee_id = auth.uid() AND a.branch_id = branches.id)
);

-- Ачааны унших/засах эрхийг салбарын оноолтоор хязгаарлана.
DROP POLICY IF EXISTS cargo_staff_read_parcels ON public.parcels;
CREATE POLICY cargo_staff_read_parcels ON public.parcels
FOR SELECT TO authenticated
USING (
  EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin')
  OR EXISTS (SELECT 1 FROM public.employee_branch_access a WHERE a.employee_id = auth.uid() AND a.branch_id = parcels.branch_id)
);

DROP POLICY IF EXISTS cargo_staff_update_parcels ON public.parcels;
CREATE POLICY cargo_staff_update_parcels ON public.parcels
FOR UPDATE TO authenticated
USING (
  EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin')
  OR EXISTS (SELECT 1 FROM public.employee_branch_access a WHERE a.employee_id = auth.uid() AND a.branch_id = parcels.branch_id)
)
WITH CHECK (
  EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin')
  OR EXISTS (SELECT 1 FROM public.employee_branch_access a WHERE a.employee_id = auth.uid() AND a.branch_id = parcels.branch_id)
);

-- Шинэ ачаа нэмэх, устгах эрх зөвхөн админд байна.
DROP POLICY IF EXISTS cargo_only_admin_insert_parcels ON public.parcels;
CREATE POLICY cargo_only_admin_insert_parcels ON public.parcels
FOR INSERT TO authenticated
WITH CHECK (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id=auth.uid() AND p.role='admin'));

DROP POLICY IF EXISTS cargo_only_admin_delete_parcels ON public.parcels;
CREATE POLICY cargo_only_admin_delete_parcels ON public.parcels
FOR DELETE TO authenticated
USING (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id=auth.uid() AND p.role='admin'));

-- Ажилтан зөвхөн жин, эзлэхүүн, үнэ, хүлээлгэн өгөх мэдээлэл өөрчилнө.
CREATE OR REPLACE FUNCTION public.cargo_guard_employee_parcel_update()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE current_role text;
BEGIN
  SELECT role INTO current_role FROM public.profiles WHERE id = auth.uid();
  IF current_role = 'employee' AND (
    NEW.tracking_code IS DISTINCT FROM OLD.tracking_code OR
    NEW.customer_name IS DISTINCT FROM OLD.customer_name OR
    NEW.customer_phone IS DISTINCT FROM OLD.customer_phone OR
    NEW.branch_id IS DISTINCT FROM OLD.branch_id OR
    NEW.created_at IS DISTINCT FROM OLD.created_at OR
    NEW.piece_number IS DISTINCT FROM OLD.piece_number OR
    NEW.description IS DISTINCT FROM OLD.description OR
    (NEW.parcel_status IS DISTINCT FROM OLD.parcel_status AND
      NOT (OLD.parcel_status IS DISTINCT FROM 'received' AND NEW.parcel_status = 'received')) OR
    ((NEW.paid_at IS DISTINCT FROM OLD.paid_at OR
      NEW.payment_method IS DISTINCT FROM OLD.payment_method OR
      NEW.received_by IS DISTINCT FROM OLD.received_by) AND
      NOT (OLD.parcel_status IS DISTINCT FROM 'received' AND NEW.parcel_status = 'received'))
  ) THEN
    RAISE EXCEPTION 'Ажилтан зөвхөн жин, эзлэхүүн, үнэ болон ачааг хүлээлгэн өгөх мэдээлэл өөрчилнө.';
  END IF;
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS cargo_employee_parcel_guard ON public.parcels;
CREATE TRIGGER cargo_employee_parcel_guard
BEFORE UPDATE ON public.parcels
FOR EACH ROW EXECUTE FUNCTION public.cargo_guard_employee_parcel_update();

-- Урьдчилсан бүртгэлийг зөвхөн админ харах/шийдвэрлэнэ.
DROP POLICY IF EXISTS "authenticated can view pre registrations" ON public.customer_pre_registrations;
DROP POLICY IF EXISTS "authenticated can update pre registrations" ON public.customer_pre_registrations;
DROP POLICY IF EXISTS "Admins manage parcel pre-registrations" ON public.customer_pre_registrations;
CREATE POLICY "Admins manage parcel pre-registrations" ON public.customer_pre_registrations
FOR ALL TO authenticated
USING (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin'))
WITH CHECK (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin'));

NOTIFY pgrst, 'reload schema';
