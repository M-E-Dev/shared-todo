-- Adım 1 — Ortak liste + todo iskelesi (liste üyeliği ile RLS).
-- Çalıştırma: Supabase Dashboard → SQL → New query → yapıştır → Run.
-- Ön koşul: Anonymous (veya başka) ile giriş yapan kullanıcılar JWT ile auth.uid() alır.

-- ---------------------------------------------------------------------------
-- Tablolar
-- ---------------------------------------------------------------------------

create table if not exists public.lists (
  id uuid primary key default gen_random_uuid (),
  title text not null default 'Yeni liste',
  created_by uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now()
);

create table if not exists public.list_members (
  list_id uuid not null references public.lists (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  inserted_at timestamptz not null default now(),
  primary key (list_id, user_id)
);

create index if not exists list_members_user_id_idx
  on public.list_members (user_id);

create table if not exists public.todos (
  id uuid primary key default gen_random_uuid (),
  list_id uuid not null references public.lists (id) on delete cascade,
  title text not null,
  completed boolean not null default false,
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);

create index if not exists todos_list_id_sort_idx
  on public.todos (list_id, sort_order, created_at);

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------

-- Politikalarda doğrudan `exists (select … from lists)` kullanmak, `lists`
-- politikasının `list_members`'a bakmasıyla INSERT sırasında özyineleme çıkarır.
create or replace function public.is_list_creator(p_list_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.lists l
    where l.id = p_list_id
      and l.created_by = (select auth.uid())
  );
$$;

revoke all on function public.is_list_creator(uuid) from public;
grant execute on function public.is_list_creator(uuid) to authenticated;

alter table public.lists enable row level security;
alter table public.list_members enable row level security;
alter table public.todos enable row level security;

-- Liste: oluşturan veya üyesi olduğun listeler.
create policy lists_select_member_or_creator on public.lists for
select using (
  created_by = (select auth.uid ())
  or exists (
    select 1 from public.list_members m
    where m.list_id = lists.id and m.user_id = (select auth.uid ())
  )
);

create policy lists_insert_self_as_creator on public.lists for
insert with check (created_by = (select auth.uid ()));

create policy lists_update_member on public.lists for
update using (
  exists (
    select 1 from public.list_members m
    where m.list_id = lists.id and m.user_id = (select auth.uid ())
  )
);

create policy lists_delete_creator on public.lists for delete using (
  created_by = (select auth.uid ())
);

-- Üyelik: yalnızca kendi satırın (list_members → lists → list_members döngüsünü önler).
create policy list_members_select on public.list_members for
select using (user_id = (select auth.uid ()));

-- İlk üyeliği yalnızca liste oluşturucusu ekler (fonksiyon RLS döngüsünü önler).
create policy list_members_insert_creator on public.list_members for
insert with check (
  user_id = (select auth.uid ())
  and public.is_list_creator(list_id)
);

create policy list_members_delete_creator on public.list_members for delete using (
  public.is_list_creator(list_id)
);

-- Todo: yalnızca üyesi olduğun liste.
create policy todos_select_member on public.todos for select using (
  exists (
    select 1 from public.list_members m
    where m.list_id = todos.list_id and m.user_id = (select auth.uid ())
  )
);

create policy todos_insert_member on public.todos for insert with check (
  exists (
    select 1 from public.list_members m
    where m.list_id = todos.list_id and m.user_id = (select auth.uid ())
  )
);

create policy todos_update_member on public.todos for
update using (
  exists (
    select 1 from public.list_members m
    where m.list_id = todos.list_id and m.user_id = (select auth.uid ())
  )
);

create policy todos_delete_member on public.todos for delete using (
  exists (
    select 1 from public.list_members m
    where m.list_id = todos.list_id and m.user_id = (select auth.uid ())
  )
);

-- ---------------------------------------------------------------------------
-- İzinler (JWT ile gelen anon + normal kullanıcılar için)
-- ---------------------------------------------------------------------------

grant select, insert, update, delete on public.lists to authenticated;
grant select, insert, update, delete on public.list_members to authenticated;
grant select, insert, update, delete on public.todos to authenticated;
