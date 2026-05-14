-- 002 (güncel) — list_members SELECT: lists alt sorgusu, lists politikasının list_members
-- kontrolü ile birlikte YİNE sonsuz özyinelemeye yol açabiliyordu.
-- Çözüm: Üyelik satırını kullanıcı yalnızca kendi user_id’si ile görsün.
--
-- Supabase → SQL → Run (eski 002’yi çalıştırdıysan bu betiği yine çalıştır).

drop policy if exists list_members_select on public.list_members;

create policy list_members_select on public.list_members for
select using (user_id = (select auth.uid ()));
