-- Тэнхлүүн Карго: branches хүснэгтийн утасны багана нэмэх
alter table public.branches
  add column if not exists phone text;

notify pgrst, 'reload schema';
