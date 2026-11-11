-- Seguimiento de pedidos para el cliente (ubicación simulada por etapas).
-- Aplícalo UNA sola vez a mano en el SQL Editor del dashboard de Supabase.
-- Requiere las tablas orders, order_items, menu_items y restaurants.

-- ============ Coordenadas de restaurantes ============
alter table public.restaurants
  add column if not exists lat double precision,
  add column if not exists lng double precision;

-- ============ Tabla de seguimiento ============
create table if not exists public.order_tracking (
  order_id uuid primary key references public.orders(id) on delete cascade,
  stage text not null default 'preparing'
    check (stage in ('preparing', 'on_the_way', 'delivered')),
  restaurant_name text,
  restaurant_lat double precision,
  restaurant_lng double precision,
  dropoff_address text,
  dropoff_lat double precision,
  dropoff_lng double precision,
  eta_minutes int not null default 20,
  on_the_way_at timestamptz,
  delivered_at timestamptz,
  updated_at timestamptz not null default now()
);

-- ============ Triggers ============

-- Al pagarse un pedido se crea su seguimiento (toma el restaurante del primer platillo).
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
  join public.menu_items mi on mi.id = oi.menu_item_id
  join public.restaurants r on r.id = mi.restaurant_id
  where oi.order_id = new.id
  limit 1
  on conflict (order_id) do nothing;

  -- Si no se encontró restaurante, se crea igual un seguimiento vacío.
  insert into public.order_tracking (order_id) values (new.id)
  on conflict (order_id) do nothing;

  return new;
end;
$$;

drop trigger if exists orders_create_tracking_trg on public.orders;
create trigger orders_create_tracking_trg
  after update of status on public.orders
  for each row
  when (new.status = 'paid' and old.status is distinct from 'paid')
  execute function public.orders_create_tracking();

-- Marca las horas al cambiar de etapa.
create or replace function public.order_tracking_touch()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  if new.stage = 'on_the_way' and old.stage is distinct from 'on_the_way' then
    new.on_the_way_at := now();
  end if;
  if new.stage = 'delivered' and old.stage is distinct from 'delivered' then
    new.delivered_at := now();
  end if;
  return new;
end;
$$;

drop trigger if exists order_tracking_touch_trg on public.order_tracking;
create trigger order_tracking_touch_trg
  before update on public.order_tracking
  for each row execute function public.order_tracking_touch();

-- Seguimiento para los pedidos que ya estaban pagados.
insert into public.order_tracking (order_id)
select id from public.orders where status = 'paid'
on conflict (order_id) do nothing;

-- ============ RLS ============
-- El cliente solo LEE el seguimiento de sus pedidos; las etapas las cambia
-- el administrador / service role (no hay política de update para clientes).

alter table public.order_tracking enable row level security;

create policy "tracking: leer propios" on public.order_tracking
  for select to authenticated
  using (exists (
    select 1 from public.orders o
    where o.id = order_tracking.order_id and o.user_id = auth.uid()
  ));

-- ============ Realtime ============
-- Para que la app se actualice sola al cambiar de etapa.
alter publication supabase_realtime add table public.order_tracking;

-- ============ Para probar ============
-- 1) Ponle coordenadas a un restaurante (ejemplo, ajústalas a tu ciudad):
--   update public.restaurants set lat = 19.4326, lng = -99.1332 where id = '<restaurant_id>';
-- 2) Destino del pedido (opcional; si no, la app usa un punto cercano al restaurante):
--   update public.order_tracking set dropoff_address = 'Calle Reforma 123',
--     dropoff_lat = 19.4420, dropoff_lng = -99.1200 where order_id = '<order_id>';
-- 3) Avanzar el pedido:
--   update public.order_tracking set stage = 'on_the_way', eta_minutes = 10 where order_id = '<order_id>';
--   update public.order_tracking set stage = 'delivered' where order_id = '<order_id>';
