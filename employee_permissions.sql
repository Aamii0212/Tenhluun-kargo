-- Тэнхлүүн Карго: ажилтны эрхийн хамгаалалт
-- Supabase SQL Editor дээр ADMIN эрхээр нэг удаа ажиллуулна.

ALTER TABLE public.parcels ENABLE ROW LEVEL SECURITY;

CREATE TABLE IF NOT EXISTS public.employee_branch_access (
 employee_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
 branch_id uuid NOT NULL REFERENCES public.branches(id) ON DELETE CASCADE,
 created_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(employee_id,branch_id)
);
ALTER TABLE public.employee_branch_access ENABLE ROW LEVEL SECURITY;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.employee_branch_access TO authenticated;
DROP POLICY IF EXISTS employee_branch_access_read ON public.employee_branch_access;
CREATE POLICY employee_branch_access_read ON public.employee_branch_access FOR SELECT TO authenticated USING (employee_id=auth.uid() OR EXISTS(SELECT 1 FROM public.profiles p WHERE p.id=auth.uid() AND p.role='admin'));
DROP POLICY IF EXISTS employee_branch_access_admin_manage ON public.employee_branch_access;
CREATE POLICY employee_branch_access_admin_manage ON public.employee_branch_access FOR ALL TO authenticated USING (EXISTS(SELECT 1 FROM public.profiles p WHERE p.id=auth.uid() AND p.role='admin')) WITH CHECK (EXISTS(SELECT 1 FROM public.profiles p WHERE p.id=auth.uid() AND p.role='admin'));

-- Ажилтан болон админ ачаа хайж/харах, шинэчлэх боломжтой
DROP POLICY IF EXISTS cargo_staff_read_parcels ON public.parcels;
CREATE POLICY cargo_staff_read_parcels ON public.parcels
FOR SELECT TO authenticated
USING (
  EXISTS (SELECT 1 FROM public.profiles p WHERE p.id=auth.uid() AND p.role='admin')
  OR EXISTS (SELECT 1 FROM public.employee_branch_access a WHERE a.employee_id=auth.uid() AND a.branch_id=parcels.branch_id)
);

DROP POLICY IF EXISTS cargo_staff_update_parcels ON public.parcels;
CREATE POLICY cargo_staff_update_parcels ON public.parcels
FOR UPDATE TO authenticated
USING (
  EXISTS (SELECT 1 FROM public.profiles p WHERE p.id=auth.uid() AND p.role='admin')
  OR EXISTS (SELECT 1 FROM public.employee_branch_access a WHERE a.employee_id=auth.uid() AND a.branch_id=parcels.branch_id)
)
WITH CHECK (
  EXISTS (SELECT 1 FROM public.profiles p WHERE p.id=auth.uid() AND p.role='admin')
  OR EXISTS (SELECT 1 FROM public.employee_branch_access a WHERE a.employee_id=auth.uid() AND a.branch_id=parcels.branch_id)
);

-- Ажилтан ачаа шинээр үүсгэх/устгах эрхгүй (админд зөвшөөрнө)
DROP POLICY IF EXISTS cargo_only_admin_insert_parcels ON public.parcels;
CREATE POLICY cargo_only_admin_insert_parcels ON public.parcels
FOR INSERT TO authenticated
WITH CHECK (EXISTS (
  SELECT 1 FROM public.profiles p WHERE p.id=auth.uid() AND p.role='admin'
));

DROP POLICY IF EXISTS cargo_only_admin_delete_parcels ON public.parcels;
CREATE POLICY cargo_only_admin_delete_parcels ON public.parcels
FOR DELETE TO authenticated
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
