-- Customer profile: first login saves name; subsequent login only needs phone.
create table if not exists public.customer_profiles (
  phone text primary key check (phone ~ '^[0-9]{8}$'),
  customer_name text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.customer_profiles enable row level security;

create or replace function public.save_customer_profile(p_phone text, p_name text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare result public.customer_profiles;
begin
  if p_phone !~ '^[0-9]{8}$' then raise exception 'Утасны дугаар 8 оронтой байх ёстой'; end if;
  if nullif(trim(p_name), '') is null then raise exception 'Захиалагчийн нэрээ оруулна уу'; end if;
  insert into public.customer_profiles(phone, customer_name) values (p_phone, trim(p_name))
  on conflict (phone) do update set customer_name=excluded.customer_name, updated_at=now()
  returning * into result;
  return jsonb_build_object('phone',result.phone,'customer_name',result.customer_name);
end; $$;

create or replace function public.get_customer_profile(p_phone text)
returns jsonb language sql security definer set search_path = public as $$
  select jsonb_build_object('phone',phone,'customer_name',customer_name)
  from public.customer_profiles where phone=p_phone and p_phone ~ '^[0-9]{8}$';
$$;

revoke all on function public.save_customer_profile(text,text) from public;
revoke all on function public.get_customer_profile(text) from public;
grant execute on function public.save_customer_profile(text,text) to anon, authenticated;
grant execute on function public.get_customer_profile(text) to anon, authenticated;

-- Refresh PostgREST function cache after applying this script.
notify pgrst, 'reload schema';
