-- Хэрэглэгчийн өөрөө трак урьдчилан бүртгүүлэх хүсэлт
create table if not exists public.customer_pre_registrations (
  id uuid primary key default gen_random_uuid(),
  tracking_code text not null,
  customer_phone text not null,
  description text,
  status text not null default 'pending' check (status in ('pending','approved','rejected','confirmed')),
  admin_note text,
  created_at timestamptz not null default now(),
  reviewed_at timestamptz
);

alter table public.customer_pre_registrations enable row level security;
revoke all on table public.customer_pre_registrations from anon, authenticated;
grant insert on table public.customer_pre_registrations to anon, authenticated;
grant select, update, delete on table public.customer_pre_registrations to authenticated;

drop policy if exists "Public can submit parcel pre-registration" on public.customer_pre_registrations;
create policy "Public can submit parcel pre-registration"
on public.customer_pre_registrations for insert to anon, authenticated
with check (
  length(trim(tracking_code)) between 3 and 100
  and customer_phone ~ '^[0-9]{8}$'
  and status = 'pending'
  and admin_note is null
  and reviewed_at is null
);

-- Админ хэрэглэгч profiles.role='admin' үед хүсэлтүүдийг удирдана.
drop policy if exists "Admins manage parcel pre-registrations" on public.customer_pre_registrations;
create policy "Admins manage parcel pre-registrations"
on public.customer_pre_registrations for all to authenticated
using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin'))
with check (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role = 'admin'));

create index if not exists customer_pre_registrations_created_at_idx
on public.customer_pre_registrations (created_at desc);
create index if not exists customer_pre_registrations_tracking_code_idx
on public.customer_pre_registrations (tracking_code);
