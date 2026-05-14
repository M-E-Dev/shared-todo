-- 005 — todos.due_date + color/sort_direction sütunlarının şema önbelleğine alınması.
--
-- Çalıştır: Supabase → SQL Editor → New query → Yapıştır → Run
--
-- Bu betik; 004'ü atladıysan color/sort_direction'ı da ekler.

alter table public.lists
  add column if not exists color          text not null default '#2563EB',
  add column if not exists sort_direction text not null default 'newest_first';

alter table public.todos
  add column if not exists due_date date;   -- NULL = tarih yok

create index if not exists todos_due_date_idx
  on public.todos (due_date)
  where due_date is not null;

-- PostgREST şema önbelleğini yenile (yeni sütunları API'ye bildir).
notify pgrst, 'reload schema';
