-- 003 — Liste oluştururken INSERT list_members: policies'de doğrudan `lists`
-- sorgusu, `lists_select` ile `list_members` arasında yeniden döngü yaratır.
--
-- Güvenli yol: `lists` iç satırına SECURITY DEFINER fonksiyonla bakmak (RLS atlanır).
-- Supabase → SQL → Run.

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

drop policy if exists list_members_insert_creator on public.list_members;
drop policy if exists list_members_delete_creator on public.list_members;

create policy list_members_insert_creator on public.list_members for
insert with check (
  user_id = (select auth.uid ())
  and public.is_list_creator(list_id)
);

create policy list_members_delete_creator on public.list_members for delete using (
  public.is_list_creator(list_id)
);
