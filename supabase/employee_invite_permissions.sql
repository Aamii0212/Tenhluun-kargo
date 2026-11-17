-- Ажилтныг админ хэсгээс урих/идэвхжүүлэхэд service_role profile.role-г шинэчлэхийг зөвшөөрнө.
-- Энгийн хэрэглэгч өөрийн эрхийн төрлийг өөрчлөх хамгаалалт хэвээр үлдэнэ.
CREATE OR REPLACE FUNCTION public.protect_profile_role()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.role IS DISTINCT FROM OLD.role
     AND NOT (
       public.is_admin()
       OR coalesce(auth.role(), '') = 'service_role'
       OR session_user IN ('postgres', 'supabase_admin')
     )
  THEN
    RAISE EXCEPTION 'Хэрэглэгч өөрийн эрхийн төрлийг өөрчлөх боломжгүй.';
  END IF;

  RETURN NEW;
END;
$$;

-- Хуучин хамгаалалтын trigger байгаа эсэхийг баталгаажуулна.
DROP TRIGGER IF EXISTS protect_profile_role_trigger ON public.profiles;
CREATE TRIGGER protect_profile_role_trigger
BEFORE UPDATE OF role ON public.profiles
FOR EACH ROW
EXECUTE FUNCTION public.protect_profile_role();

NOTIFY pgrst, 'reload schema';
