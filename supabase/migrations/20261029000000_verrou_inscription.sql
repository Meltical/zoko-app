-- Aucune création de compte sans code de foyer valide, et catalogue réservé aux membres.
-- À brancher dans Authentication → Auth Hooks → « Before User Created » (Postgres, public.hook_before_user_created).

create or replace function public.hook_before_user_created(event jsonb)
returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  code text := translate(
    upper(regexp_replace(coalesce(event -> 'user' -> 'user_metadata' ->> 'join_code', ''), '[^0-9A-Za-z]', '', 'g')),
    'OIL', '011'
  );
begin
  if code <> '' and exists (select 1 from public.households where join_code = code) then
    return '{}'::jsonb;
  end if;
  return jsonb_build_object('error', jsonb_build_object('message', 'invalid_join_code', 'http_code', 403));
end $$;

revoke execute on function public.hook_before_user_created(jsonb) from public, anon, authenticated;
grant execute on function public.hook_before_user_created(jsonb) to supabase_auth_admin;

drop policy if exists "Lecture publique" on public.ingredients;
drop policy if exists "Lecture publique" on public.recipes;
drop policy if exists "Membres d'un foyer" on public.ingredients;
drop policy if exists "Membres d'un foyer" on public.recipes;
create policy "Membres d'un foyer" on public.ingredients for select to authenticated
  using ((select public.current_household_id()) is not null);
create policy "Membres d'un foyer" on public.recipes for select to authenticated
  using ((select public.current_household_id()) is not null);
revoke all on public.ingredients, public.recipes from anon;
