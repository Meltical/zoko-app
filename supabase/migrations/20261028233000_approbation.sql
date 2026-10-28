-- Un seul foyer, et chaque nouveau téléphone doit être approuvé par un admin.

alter table public.household_members
  add column if not exists role text not null default 'member' check (role in ('admin', 'member')),
  add column if not exists status text not null default 'pending' check (status in ('pending', 'approved')),
  add column if not exists display_name text;

create or replace function public.current_household_id() returns uuid
language sql stable security definer set search_path = '' as $$
  select household_id from public.household_members where user_id = auth.uid() and status = 'approved'
$$;

create or replace function private.is_household_admin() returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.household_members
    where user_id = auth.uid() and status = 'approved' and role = 'admin'
  )
$$;

drop policy if exists "Membres de mon foyer" on public.household_members;
create policy "Membres de mon foyer" on public.household_members for select to authenticated
  using (household_id = (select public.current_household_id()) or user_id = (select auth.uid()));

create or replace function public.create_household(household_name text default 'Maison')
returns public.households
language plpgsql security definer set search_path = '' as $$
declare
  created public.households;
begin
  if auth.uid() is null then
    raise exception 'not_authenticated';
  end if;
  if exists (select 1 from public.households) then
    raise exception 'creation_closed';
  end if;
  insert into public.households (name) values (coalesce(nullif(trim(household_name), ''), 'Maison'))
  returning * into created;
  insert into public.household_members (user_id, household_id, role, status)
  values (auth.uid(), created.id, 'admin', 'approved');
  return created;
end $$;

drop function if exists public.join_household(text);

create or replace function public.join_household(code text, display_name text)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  normalized text := translate(upper(regexp_replace(code, '[^0-9A-Za-z]', '', 'g')), 'OIL', '011');
  target public.households;
  bootstrap boolean;
  membership public.household_members;
begin
  if auth.uid() is null then
    raise exception 'not_authenticated';
  end if;
  if (select count(*) from private.join_attempts
      where user_id = auth.uid() and attempted_at > now() - interval '1 hour') >= 10 then
    raise exception 'too_many_attempts';
  end if;

  select * into target from public.households where join_code = normalized;
  if target.id is null then
    insert into private.join_attempts (user_id) values (auth.uid());
    raise exception 'invalid_code';
  end if;

  select * into membership from public.household_members where user_id = auth.uid();
  if membership.household_id = target.id and membership.status = 'approved' then
    return jsonb_build_object('household_id', target.id, 'household_name', target.name,
                              'status', membership.status, 'role', membership.role);
  end if;

  bootstrap := not exists (
    select 1 from public.household_members where household_id = target.id and status = 'approved'
  );
  insert into public.household_members (user_id, household_id, role, status, display_name)
  values (auth.uid(), target.id,
          case when bootstrap then 'admin' else 'member' end,
          case when bootstrap then 'approved' else 'pending' end,
          nullif(left(trim(display_name), 40), ''))
  on conflict (user_id) do update
    set household_id = excluded.household_id, role = excluded.role, status = excluded.status,
        display_name = excluded.display_name, joined_at = now()
  returning * into membership;

  return jsonb_build_object('household_id', target.id, 'household_name', target.name,
                            'status', membership.status, 'role', membership.role);
end $$;

create or replace function public.my_membership()
returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object('household_id', h.id, 'household_name', h.name,
                            'status', m.status, 'role', m.role)
  from public.household_members m
  join public.households h on h.id = m.household_id
  where m.user_id = auth.uid()
$$;

create or replace function public.approve_member(member uuid)
returns void
language plpgsql security definer set search_path = '' as $$
begin
  if not private.is_household_admin() then
    raise exception 'admin_only';
  end if;
  update public.household_members set status = 'approved'
  where user_id = member and household_id = public.current_household_id();
end $$;

create or replace function public.remove_member(member uuid)
returns void
language plpgsql security definer set search_path = '' as $$
begin
  if not private.is_household_admin() then
    raise exception 'admin_only';
  end if;
  if member = auth.uid() then
    raise exception 'cannot_remove_self';
  end if;
  delete from public.household_members
  where user_id = member and household_id = public.current_household_id();
end $$;

create or replace function public.leave_household()
returns void
language plpgsql security definer set search_path = '' as $$
declare
  left_membership public.household_members;
begin
  delete from public.household_members where user_id = auth.uid() returning * into left_membership;
  if left_membership.role = 'admin' and left_membership.status = 'approved'
     and not exists (select 1 from public.household_members
                     where household_id = left_membership.household_id and role = 'admin' and status = 'approved') then
    update public.household_members set role = 'admin'
    where user_id = (select user_id from public.household_members
                     where household_id = left_membership.household_id and status = 'approved'
                     order by joined_at limit 1);
  end if;
end $$;

create or replace function public.rotate_join_code()
returns public.households
language plpgsql security definer set search_path = '' as $$
declare
  updated public.households;
begin
  if not private.is_household_admin() then
    raise exception 'admin_only';
  end if;
  update public.households set join_code = private.new_join_code()
  where id = public.current_household_id()
  returning * into updated;
  return updated;
end $$;

revoke execute on function public.join_household(text, text), public.my_membership(),
  public.approve_member(uuid), public.remove_member(uuid) from public, anon;
grant execute on function public.join_household(text, text), public.my_membership(),
  public.approve_member(uuid), public.remove_member(uuid) to authenticated;
revoke execute on function private.is_household_admin() from public, anon, authenticated;

do $$
begin
  if not exists (select 1 from pg_publication_tables
                 where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'household_members') then
    alter publication supabase_realtime add table public.household_members;
  end if;
end $$;
