-- Customer parcel lookup that reads the canonical parcels table and bypasses
-- table RLS only inside this narrowly scoped phone-number lookup.
-- Run this once in Supabase SQL Editor.
create or replace function public.get_customer_parcels_by_phone_v2(p_phone text)
returns setof jsonb
language sql
stable
security definer
set search_path = public, pg_temp
as $function$
  select to_jsonb(p)
  from public.parcels as p
  where length(regexp_replace(coalesce(p_phone, ''), '[^0-9]', '', 'g')) = 8
    and regexp_replace(coalesce(p.customer_phone, ''), '[^0-9]', '', 'g')
        = regexp_replace(coalesce(p_phone, ''), '[^0-9]', '', 'g')
  order by p.created_at desc nulls last, p.id desc;
$function$;

revoke all on function public.get_customer_parcels_by_phone_v2(text) from public;
grant execute on function public.get_customer_parcels_by_phone_v2(text) to anon, authenticated;
