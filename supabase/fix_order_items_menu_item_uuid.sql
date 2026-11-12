-- Arreglo del error "operator does not exist: uuid = text" al confirmar el pago.
--
-- QUÉ PASABA
-- La Edge Function `confirm-payment` termina con:
--     update public.orders set status = 'paid', paid_at = ..., receipt_url = ...
-- Ese UPDATE dispara el trigger `orders_create_tracking_trg` (creado por
-- tracking.sql), cuyo join comparaba `menu_items.id` (uuid) con
-- `order_items.menu_item_id` (text). Postgres lanzaba el error 42883, el
-- UPDATE fallaba, la función devolvía 500 ("Error interno al confirmar el
-- pago"), la app mostraba ese error y el pedido se quedaba en 'pending'
-- aunque Stripe YA HABÍA COBRADO la tarjeta.
--
-- QUÉ HACE ESTE SCRIPT
--  1. Alinea public.order_items.menu_item_id a uuid (los valores actuales ya
--     son uuid y no hay filas huérfanas: se verificó antes de aplicarlo).
--  2. Agrega la FK order_items.menu_item_id -> public.menu_items(id).
--  3. Recrea el trigger con el join casteado (funciona con text o con uuid).
--
-- CÓMO APLICARLO
-- Panel de Supabase -> SQL Editor -> New query -> pegar -> Run.
-- Es idempotente: se puede ejecutar más de una vez sin romper nada.

-- ============ 1) Tipo de la columna ============
alter table public.order_items
  alter column menu_item_id type uuid using menu_item_id::uuid;

-- ============ 2) FK hacia menu_items ============
do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.order_items'::regclass
      and conname = 'order_items_menu_item_id_fkey'
  ) then
    alter table public.order_items
      add constraint order_items_menu_item_id_fkey
      foreign key (menu_item_id) references public.menu_items (id) on delete restrict;
  end if;
end $$;

-- ============ 3) Trigger corregido ============
create or replace function public.orders_create_tracking()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.order_tracking (order_id, restaurant_name, restaurant_lat, restaurant_lng)
  select new.id, r.name, r.lat, r.lng
  from public.order_items oi
  join public.menu_items mi on mi.id::text = oi.menu_item_id::text
  join public.restaurants r on r.id = mi.restaurant_id
  where oi.order_id = new.id
  limit 1
  on conflict (order_id) do nothing;

  insert into public.order_tracking (order_id) values (new.id)
  on conflict (order_id) do nothing;

  return new;
end;
$$;

-- ============ 4) Comprobación ============
-- Antes de aplicar el script esta consulta fallaba con
--   ERROR 42883: operator does not exist: uuid = text
-- Ahora debe ejecutarse sin error (y devolver las filas del join, porque
-- ambas columnas ya son uuid).
select oi.id, oi.menu_item_id
from public.order_items oi
join public.menu_items mi on mi.id = oi.menu_item_id
limit 1;

-- El trigger debe seguir instalado:
-- select tgname, pg_get_triggerdef(oid) from pg_trigger
-- where tgrelid = 'public.orders'::regclass and not tgisinternal;

-- ============ 5) Opcional: reconciliar pedidos ya cobrados por Stripe ============
-- Pedidos que quedaron en 'pending' aunque Stripe sí cobró (el trigger los
-- bloqueó). Al marcarlos como 'paid' el trigger les crea su seguimiento.
-- OJO: marca SOLO los que aparecen como succeeded en el panel de Stripe test.
--   update public.orders
--   set status = 'paid', paid_at = now()
--   where id in (
--     '2a0f38b7-c2a1-4ff6-86cc-b3499442d141',  -- pi_3Ub0eQ... (16:15)
--     'e2b82413-c9d6-4f60-a7af-9b012bdeb629'   -- pi_3Ub0uy... (16:32)
--   );
