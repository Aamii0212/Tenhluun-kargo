-- Тэнхлүүн Карго: админ хэсгийн хүснэгт/талбарын суурь тохиргоо
-- Supabase Dashboard → SQL Editor дээр ADMIN эрхээр нэг удаа ажиллуулна.
-- Existing parcels/profiles өгөгдлийг устгахгүй.

CREATE TABLE IF NOT EXISTS public.branches (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL UNIQUE,
  address text,
  phone text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.site_settings (
  id integer PRIMARY KEY DEFAULT 1 CHECK (id = 1),
  kg_price numeric NOT NULL DEFAULT 2500,
  m3_price numeric NOT NULL DEFAULT 700,
  open_time text NOT NULL DEFAULT '10:00',
  close_time text NOT NULL DEFAULT '20:00',
  ereen_address text,
  ereen_contact text,
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.parcels
  ADD COLUMN IF NOT EXISTS branch_id uuid REFERENCES public.branches(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS paid_at timestamptz,
  ADD COLUMN IF NOT EXISTS payment_method text,
  ADD COLUMN IF NOT EXISTS received_by text;

CREATE INDEX IF NOT EXISTS parcels_branch_id_idx ON public.parcels(branch_id);
CREATE INDEX IF NOT EXISTS parcels_paid_at_idx ON public.parcels(paid_at);

ALTER TABLE public.branches ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.site_settings ENABLE ROW LEVEL SECURITY;

-- Admin л салбар болон сайтын тохиргоог өөрчилнө.
DROP POLICY IF EXISTS cargo_admin_manage_branches ON public.branches;
CREATE POLICY cargo_admin_manage_branches ON public.branches
FOR ALL TO authenticated
USING (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin'))
WITH CHECK (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin'));

DROP POLICY IF EXISTS cargo_admin_manage_site_settings ON public.site_settings;
CREATE POLICY cargo_admin_manage_site_settings ON public.site_settings
FOR ALL TO authenticated
USING (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin'))
WITH CHECK (EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = auth.uid() AND p.role = 'admin'));

-- Админ самбарын public key-ээр хүснэгтэд шууд нэвтрэхийг хаана.
-- Хэрэглэгчийн үнэ/ажлын цагийг public RPC эсвэл зөвшөөрөгдсөн endpoint-оор уншдаг бол
-- түүнд тусдаа, зөвхөн SELECT policy-г тохируулна.
