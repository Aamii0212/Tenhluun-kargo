-- Ажилтан зөвхөн трак код + утас таарсан ачааг DB-ээс авах RPC.
-- Supabase SQL Editor дээр нэг удаа ажиллуулна.
CREATE OR REPLACE FUNCTION public.employee_parcel_lookup(p_tracking text, p_phone text)
RETURNS SETOF public.parcels
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT a.*
  FROM public.parcels a
  WHERE auth.uid() IS NOT NULL
    AND EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = auth.uid() AND p.role IN ('employee','admin')
    )
    AND upper(trim(a.tracking_code)) = upper(trim(p_tracking))
    AND regexp_replace(coalesce(a.customer_phone, a.phone, ''), '[^0-9]', '', 'g')
        = regexp_replace(coalesce(p_phone, ''), '[^0-9]', '', 'g')
    AND length(regexp_replace(coalesce(p_phone, ''), '[^0-9]', '', 'g')) = 8
  LIMIT 1;
$$;
REVOKE ALL ON FUNCTION public.employee_parcel_lookup(text,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.employee_parcel_lookup(text,text) TO authenticated;
