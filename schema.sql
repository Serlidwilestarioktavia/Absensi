create extension if not exists pgcrypto;

-- Buat atau lengkapi tabel profiles jika tabel sudah pernah dibuat sebelumnya
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  full_name text,
  role text not null default 'teacher',
  created_at timestamptz not null default now()
);

-- Pastikan kolom-kolom yang diperlukan tersedia jika profiles sudah ada sebelumnya
alter table public.profiles add column if not exists email text;
alter table public.profiles add column if not exists full_name text;
alter table public.profiles add column if not exists role text not null default 'teacher';
alter table public.profiles add column if not exists created_at timestamptz not null default now();

-- Tabel siswa
create table if not exists public.students (
  id text primary key,
  name text not null,
  class_name text not null default '',
  email text not null default '',
  descriptor jsonb,
  updated_at timestamptz not null default now()
);

-- Tabel absensi
create table if not exists public.attendance (
  id uuid primary key default gen_random_uuid(),
  student_id text not null,
  name text not null,
  attendance_date date not null,
  attendance_time text not null,
  status text not null check (status in ('Hadir', 'Terlambat')),
  method text not null,
  created_at_ms bigint not null,
  unique (student_id, attendance_date)
);

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, email, full_name, role)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data ->> 'full_name', split_part(new.email, '@', 1)),
    'teacher'
  )
  on conflict (id) do update set
    email = excluded.email,
    full_name = coalesce(excluded.full_name, public.profiles.full_name);
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

create or replace function public.is_manager()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.profiles
    where id = (select auth.uid()) and role = 'manager'
  );
$$;

revoke all on function public.is_manager() from public;
grant execute on function public.is_manager() to authenticated;

alter table public.profiles enable row level security;
alter table public.students enable row level security;
alter table public.attendance enable row level security;

drop policy if exists "profiles_read_self_or_manager" on public.profiles;
create policy "profiles_read_self_or_manager" on public.profiles
for select to authenticated
using (id = (select auth.uid()) or (select public.is_manager()));

drop policy if exists "students_shared_access" on public.students;
create policy "students_shared_access" on public.students
for all to anon, authenticated
using (true)
with check (true);

drop policy if exists "attendance_shared_access" on public.attendance;
create policy "attendance_shared_access" on public.attendance
for all to anon, authenticated
using (true)
with check (true);

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'students'
  ) then
    alter publication supabase_realtime add table public.students;
  end if;
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'attendance'
  ) then
    alter publication supabase_realtime add table public.attendance;
  end if;
end;
$$;
