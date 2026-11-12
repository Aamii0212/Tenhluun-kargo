-- Тэнхлүүн Карго: ажилтны эрхийн хамгаалалт
-- Supabase SQL Editor дээр ADMIN эрхээр нэг удаа ажиллуулна.

ALTER TABLE public.parcels ENABLE ROW LEVEL SECURITY;

-- Ажилтан болон админ ачаа хайж/харах, шинэчлэх боломжтой
DROP POLICY IF EXISTS cargo_staff_read_parcels ON public.parcels;
CREATE POLICY cargo_staff_read_parcels ON public.parcels
FOR SELECT TO authenticated
USING (EXISTS (
  SELECT 1 FROM public.profiles p
  WHERE p.id = auth.uid() AND p.role IN ('admin','employee')
));

DROP POLICY IF EXISTS cargo_staff_update_parcels ON public.parcels;
CREATE POLICY cargo_staff_update_parcels ON public.parcels
FOR UPDATE TO authenticated
USING (EXISTS (
  SELECT 1 FROM public.profiles p
  WHERE p.id = auth.uid() AND p.role IN ('admin','employee')
))
WITH CHECK (EXISTS (
  SELECT 1 FROM public.profiles p
  WHERE p.id = auth.uid() AND p.role IN ('admin','employee')
));

-- Ажилтан ачаа шинээр үүсгэх/устгах эрхгүй (админд зөвшөөрнө)
DROP POLICY IF EXISTS cargo_only_admin_insert_parcels ON public.parcels;
CREATE POLICY cargo_only_admin_insert_parcels ON public.parcels
AS RESTRICTIVE FOR INSERT TO authenticated
WITH CHECK (EXISTS (
  SELECT 1 FROM public.profiles p WHERE p.id=auth.uid() AND p.role='admin'
));

DROP POLICY IF EXISTS cargo_only_admin_delete_parcels ON public.parcels;
CREATE POLICY cargo_only_admin_delete_parcels ON public.parcels
AS RESTRICTIVE FOR DELETE TO authenticated
USING (EXISTS (
  SELECT 1 FROM public.profiles p WHERE p.id=auth.uid() AND p.role='admin'
));

-- Ажилтан зөвхөн жин/эзлэхүүн/үнэ/хүлээлгэн өгөх талбар өөрчилнө.
-- Админ бүх талбарыг хэвийн өөрчилж болно.
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
    NEW.created_at IS DISTINCT FROM OLD.created_at
  ) THEN
    RAISE EXCEPTION 'Ажилтан зөвхөн үнэ, жин, хүлээлгэн өгөх мэдээлэл өөрчилнө.';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS cargo_employee_parcel_guard ON public.parcels;
CREATE TRIGGER cargo_employee_parcel_guard
BEFORE UPDATE ON public.parcels
FOR EACH ROW EXECUTE FUNCTION public.cargo_guard_employee_parcel_update();
