-- Customer phone lookup RPC for Тэнхлүүн Карго.
-- Supabase SQL Editor дээр ажиллуулна. Phone-only lookup is not strong authentication;
-- production-д SMS OTP/customer auth ашиглахыг зөвлөж байна.
CREATE OR REPLACE FUNCTION public.get_customer_parcels_by_phone(p_phone text)
RETURNS SETOF jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT jsonb_build_object(
    'id', p.id, 'tracking_code', p.tracking_code,
    'customer_name', p.customer_name, 'customer_phone', p.customer_phone,
    'piece_number', p.piece_number, 'weight_kg', p.weight_kg,
    'volume_m3', p.volume_m3, 'price_mnt', p.price_mnt,
    'parcel_status', p.parcel_status, 'created_at', p.created_at,
    'description', p.description, 'branch_id', p.branch_id,
    'paid_at', p.paid_at, 'payment_method', p.payment_method,
    'received_by', p.received_by, 'branch_name', b.name,
    'branch_address', b.address, 'branch_hours', NULL,
    'branch_location', NULL
  )
  FROM public.parcels p
  LEFT JOIN public.branches b ON b.id = p.branch_id
  WHERE p.customer_phone = regexp_replace(coalesce(p_phone,''), '\\D', '', 'g')
    AND length(regexp_replace(coalesce(p_phone,''), '\\D', '', 'g')) = 8
  ORDER BY p.created_at DESC;
$$;
REVOKE ALL ON FUNCTION public.get_customer_parcels_by_phone(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_customer_parcels_by_phone(text) TO anon, authenticated;
NOTIFY pgrst, 'reload schema';
