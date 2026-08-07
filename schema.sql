-- ТРЕНЕР ИИ — Supabase schema
-- Qanday ishlatish: Supabase project ichida chap menyudan "SQL Editor" ni och,
-- shu faylning HAMMASINI ko'chirib qo'y (copy-paste), pastdagi ADMIN_EMAIL o'rniga
-- o'zingning haqiqiy email'ingni yoz (login qiladigan email), keyin "Run" bos.

-- ==========================================================
-- 1) access_grants — kimga qancha muddat ruxsat berilganini saqlaydi
-- ==========================================================
create table if not exists public.access_grants (
  email text primary key,
  plan text not null default 'manual',
  expires_at timestamptz not null,
  granted_by text,
  created_at timestamptz not null default now()
);

alter table public.access_grants enable row level security;

-- har bir login qilgan odam FAQAT o'z email'iga tegishli qatorni o'qiy oladi
drop policy if exists "read own grant" on public.access_grants;
create policy "read own grant" on public.access_grants
  for select using (auth.email() = email);

-- faqat admin (pastdagi email) barcha qatorlarni o'qiy/qo'sha/o'zgartira/o'chira oladi
drop policy if exists "admin manage grants" on public.access_grants;
create policy "admin manage grants" on public.access_grants
  for all
  using (auth.email() = 'axrorovasl@gmail.com')
  with check (auth.email() = 'axrorovasl@gmail.com');

-- ==========================================================
-- 2) user_state — har bir foydalanuvchining ilova ma'lumoti (bitta JSON qator)
-- ==========================================================
create table if not exists public.user_state (
  user_id uuid primary key references auth.users(id) on delete cascade,
  state jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

alter table public.user_state enable row level security;

drop policy if exists "select own state" on public.user_state;
create policy "select own state" on public.user_state
  for select using (auth.uid() = user_id);

drop policy if exists "insert own state" on public.user_state;
create policy "insert own state" on public.user_state
  for insert with check (auth.uid() = user_id);

drop policy if exists "update own state" on public.user_state;
create policy "update own state" on public.user_state
  for update using (auth.uid() = user_id);

-- updated_at avtomatik yangilanishi uchun
create or replace function public.set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists trg_user_state_updated on public.user_state;
create trigger trg_user_state_updated
  before update on public.user_state
  for each row execute function public.set_updated_at();

-- ==========================================================
-- 3) exercise_videos — har bir mashq nomiga bitta video ssilkasi
-- ==========================================================
create table if not exists public.exercise_videos (
  exercise_name text primary key,
  video_url text not null,
  uploaded_by text,
  updated_at timestamptz not null default now()
);

alter table public.exercise_videos enable row level security;

-- har bir tizimga kirgan (ruxsat berilgan) foydalanuvchi videolarni ko'ra oladi
drop policy if exists "read videos" on public.exercise_videos;
create policy "read videos" on public.exercise_videos
  for select using (auth.role() = 'authenticated');

-- faqat admin video qo'sha/almashtira/o'chira oladi
drop policy if exists "admin manage videos" on public.exercise_videos;
create policy "admin manage videos" on public.exercise_videos
  for all
  using (auth.email() = 'axrorovasl@gmail.com')
  with check (auth.email() = 'axrorovasl@gmail.com');

-- ==========================================================
-- 4) Storage bucket — video fayllarning o'zi shu yerda saqlanadi
-- ==========================================================
insert into storage.buckets (id, name, public)
values ('exercise-videos', 'exercise-videos', true)
on conflict (id) do nothing;

drop policy if exists "public read exercise videos" on storage.objects;
create policy "public read exercise videos" on storage.objects
  for select using (bucket_id = 'exercise-videos');

drop policy if exists "admin upload exercise videos" on storage.objects;
create policy "admin upload exercise videos" on storage.objects
  for insert with check (bucket_id = 'exercise-videos' and auth.email() = 'axrorovasl@gmail.com');

drop policy if exists "admin update exercise videos" on storage.objects;
create policy "admin update exercise videos" on storage.objects
  for update using (bucket_id = 'exercise-videos' and auth.email() = 'axrorovasl@gmail.com');

drop policy if exists "admin delete exercise videos" on storage.objects;
create policy "admin delete exercise videos" on storage.objects
  for delete using (bucket_id = 'exercise-videos' and auth.email() = 'axrorovasl@gmail.com');

-- ==========================================================
-- TAYYOR. Endi index.html ichidagi axrorovasl@gmail.comni ham xuddi shu emailga
-- almashtirishni unutma (barcha joyda bir xil bo'lishi shart).
-- ==========================================================
