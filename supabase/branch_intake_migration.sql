-- Тэнхлүүн Карго: салбарын ачаа бүртгэлийн огноо
-- Supabase Dashboard → SQL Editor дээр нэг удаа ажиллуулна.
ALTER TABLE public.parcels
ADD COLUMN IF NOT EXISTS arrival_date date;
NOTIFY pgrst, 'reload schema';
