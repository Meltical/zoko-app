-- Étape 1 de la refonte. Additive : l'ancienne app (accès anonyme à products
-- via la policy « Accept all ») continue de fonctionner jusqu'à l'étape 2.

create schema if not exists private;

create or replace function private.new_join_code() returns text
language plpgsql volatile set search_path = '' as $$
declare
  alphabet constant text := '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
  bytes bytea := extensions.gen_random_bytes(12);
  code text := '';
begin
  for i in 0..11 loop
    code := code || substr(alphabet, (get_byte(bytes, i) % 32) + 1, 1);
  end loop;
  return code;
end $$;

create table if not exists public.households (
  id uuid primary key default gen_random_uuid(),
  name text not null default 'Maison',
  join_code text not null unique default private.new_join_code(),
  created_at timestamptz not null default now()
);

create table if not exists public.household_members (
  user_id uuid primary key references auth.users (id) on delete cascade,
  household_id uuid not null references public.households (id) on delete cascade,
  joined_at timestamptz not null default now()
);
create index if not exists household_members_household_idx on public.household_members (household_id);

create table if not exists private.join_attempts (
  user_id uuid not null,
  attempted_at timestamptz not null default now()
);
create index if not exists join_attempts_user_idx on private.join_attempts (user_id, attempted_at);

create or replace function public.current_household_id() returns uuid
language sql stable security definer set search_path = '' as $$
  select household_id from public.household_members where user_id = auth.uid()
$$;

-- Produits

alter table public.products add column if not exists location text not null default 'fridge';
alter table public.products drop constraint if exists products_location_check;
alter table public.products
  add constraint products_location_check check (location in ('fridge', 'freezer', 'pantry'));
alter table public.products
  add column if not exists household_id uuid references public.households (id) on delete cascade
  default public.current_household_id();
create index if not exists products_household_idx on public.products (household_id);

do $$
declare
  home uuid;
begin
  if not exists (select 1 from public.households) then
    insert into public.households (name) values ('Maison') returning id into home;
    update public.products set household_id = home where household_id is null;
  end if;
end $$;

drop policy if exists "Membres du foyer" on public.products;
create policy "Membres du foyer" on public.products for all to authenticated
  using (household_id = (select public.current_household_id()))
  with check (household_id = (select public.current_household_id()));

create table if not exists public.product_history (
  id bigint generated always as identity primary key,
  household_id uuid not null default public.current_household_id()
    references public.households (id) on delete cascade,
  name text not null,
  exp date,
  quantity smallint,
  location text,
  added_at timestamptz,
  outcome text not null check (outcome in ('eaten', 'wasted')),
  logged_at timestamptz not null default now()
);
create index if not exists product_history_household_idx on public.product_history (household_id, logged_at);

create table if not exists public.shopping_items (
  id bigint generated always as identity primary key,
  household_id uuid not null default public.current_household_id()
    references public.households (id) on delete cascade,
  name text not null check (length(trim(name)) > 0),
  note text,
  done boolean not null default false,
  created_at timestamptz not null default now()
);
create index if not exists shopping_items_household_idx on public.shopping_items (household_id);

alter table public.households enable row level security;
alter table public.household_members enable row level security;
alter table public.product_history enable row level security;
alter table public.shopping_items enable row level security;

drop policy if exists "Mon foyer" on public.households;
create policy "Mon foyer" on public.households for select to authenticated
  using (id = (select public.current_household_id()));

drop policy if exists "Membres de mon foyer" on public.household_members;
create policy "Membres de mon foyer" on public.household_members for select to authenticated
  using (household_id = (select public.current_household_id()));

drop policy if exists "Membres du foyer" on public.product_history;
create policy "Membres du foyer" on public.product_history for all to authenticated
  using (household_id = (select public.current_household_id()))
  with check (household_id = (select public.current_household_id()));

drop policy if exists "Membres du foyer" on public.shopping_items;
create policy "Membres du foyer" on public.shopping_items for all to authenticated
  using (household_id = (select public.current_household_id()))
  with check (household_id = (select public.current_household_id()));

revoke all on public.households, public.household_members, public.product_history, public.shopping_items from anon;
grant select on public.households, public.household_members to authenticated;
grant select, insert, update, delete on public.product_history, public.shopping_items to authenticated;

create or replace view public.product_suggestions with (security_invoker = true) as
with entries as (
  select household_id, name, exp, created_at as added_at, location from public.products
  union all
  select household_id, name, exp, added_at, location
  from public.product_history
  where exp is not null and added_at is not null
)
select
  lower(trim(name)) as key,
  (array_agg(trim(name) order by added_at desc))[1] as name,
  count(*)::int as uses,
  max(added_at) as last_added_at,
  greatest(
    0,
    round(percentile_cont(0.5) within group (
      order by (exp - (added_at at time zone 'Europe/Paris')::date)::float8
    ))
  )::int as shelf_days,
  mode() within group (order by location) as location,
  household_id
from entries
where trim(name) <> '' and household_id is not null
group by household_id, lower(trim(name));

revoke all on public.product_suggestions from anon;
grant select on public.product_suggestions to authenticated;

-- Foyer : création, adhésion par code, départ, nouveau code

create or replace function public.create_household(household_name text default 'Maison')
returns public.households
language plpgsql security definer set search_path = '' as $$
declare
  created public.households;
begin
  if auth.uid() is null then
    raise exception 'not_authenticated';
  end if;
  if exists (select 1 from public.household_members where user_id = auth.uid()) then
    raise exception 'already_in_household';
  end if;
  insert into public.households (name) values (coalesce(nullif(trim(household_name), ''), 'Maison'))
  returning * into created;
  insert into public.household_members (user_id, household_id) values (auth.uid(), created.id);
  return created;
end $$;

create or replace function public.join_household(code text)
returns public.households
language plpgsql security definer set search_path = '' as $$
declare
  normalized text := translate(upper(regexp_replace(code, '[^0-9A-Za-z]', '', 'g')), 'OIL', '011');
  target public.households;
  previous uuid;
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

  select household_id into previous from public.household_members where user_id = auth.uid();
  insert into public.household_members (user_id, household_id) values (auth.uid(), target.id)
  on conflict (user_id) do update set household_id = excluded.household_id, joined_at = now();

  if previous is not null and previous <> target.id
     and not exists (select 1 from public.household_members where household_id = previous) then
    delete from public.households where id = previous;
  end if;
  return target;
end $$;

create or replace function public.leave_household()
returns void
language plpgsql security definer set search_path = '' as $$
declare
  previous uuid;
begin
  delete from public.household_members where user_id = auth.uid() returning household_id into previous;
  if previous is not null and not exists (select 1 from public.household_members where household_id = previous) then
    delete from public.households where id = previous;
  end if;
end $$;

create or replace function public.rotate_join_code()
returns public.households
language plpgsql security definer set search_path = '' as $$
declare
  updated public.households;
begin
  update public.households set join_code = private.new_join_code()
  where id = public.current_household_id()
  returning * into updated;
  if updated.id is null then
    raise exception 'not_in_household';
  end if;
  return updated;
end $$;

revoke execute on function public.current_household_id(), public.create_household(text),
  public.join_household(text), public.leave_household(), public.rotate_join_code() from public, anon;
grant execute on function public.current_household_id(), public.create_household(text),
  public.join_household(text), public.leave_household(), public.rotate_join_code() to authenticated;

-- Catalogue de recettes (lecture seule pour tous)

create table if not exists public.ingredients (
  key text primary key,
  name text not null,
  aliases text[] not null default '{}',
  staple boolean not null default false
);

create table if not exists public.recipes (
  id bigint generated always as identity primary key,
  slug text not null unique,
  title text not null,
  image_url text,
  image_credit text,
  image_source text,
  prep_minutes smallint,
  cook_minutes smallint,
  servings smallint,
  difficulty text,
  tags text[] not null default '{}',
  ingredients jsonb not null,
  steps text[] not null,
  created_at timestamptz not null default now()
);

alter table public.ingredients enable row level security;
alter table public.recipes enable row level security;
drop policy if exists "Lecture publique" on public.ingredients;
drop policy if exists "Lecture publique" on public.recipes;
create policy "Lecture publique" on public.ingredients for select using (true);
create policy "Lecture publique" on public.recipes for select using (true);
revoke insert, update, delete, truncate on public.ingredients, public.recipes from anon, authenticated;
grant select on public.ingredients, public.recipes to anon, authenticated;

-- Temps réel

do $$
begin
  if not exists (select 1 from pg_publication_tables
                 where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'shopping_items') then
    alter publication supabase_realtime add table public.shopping_items;
  end if;
  if not exists (select 1 from pg_publication_tables
                 where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'products') then
    alter publication supabase_realtime add table public.products;
  end if;
end $$;
