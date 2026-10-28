-- Étape 2 : à appliquer une fois la nouvelle app installée et le foyer rejoint.
-- Ferme la table products à l'accès anonyme : l'ancienne app cesse de fonctionner.

update public.products
set household_id = (select id from public.households order by created_at limit 1)
where household_id is null;

alter table public.products alter column household_id set not null;

drop policy if exists "Accept all" on public.products;
revoke all on public.products from anon;
revoke truncate, references, trigger on public.products, public.product_history, public.shopping_items,
  public.households, public.household_members from anon, authenticated;
