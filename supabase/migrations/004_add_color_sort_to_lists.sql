-- 004 — lists tablosuna renk ve sıralama yönü alanları.
-- Supabase → SQL → Run.

alter table public.lists
  add column if not exists color text not null default '#6366F1',
  add column if not exists sort_direction text not null default 'newest_first';
