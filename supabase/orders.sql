-- Tablas de pedidos y pagos (Stripe).
-- Se ejecuta UNA vez en Supabase: panel -> SQL Editor -> New query -> pegar -> Run.
-- Requiere que public.menu_items ya exista (FK de order_items.menu_item_id).

create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id),
  status text not null default 'pending'
    check (status in ('pending', 'paid', 'failed')),
  total numeric(10, 2) not null check (total > 0),
  currency text not null default 'mxn',
  stripe_payment_intent_id text unique,
  receipt_url text,
  paid_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders (id) on delete cascade,
  menu_item_id uuid not null references public.menu_items (id) on delete restrict,
  name text not null,
  unit_price numeric(10, 2) not null,
  quantity integer not null check (quantity > 0)
);

-- Si la tabla ya existía con `menu_item_id text`, se alinea a `uuid`.
-- Importante: el trigger `orders_create_tracking` (tracking.sql) compara
-- order_items.menu_item_id con menu_items.id. Con tipos distintos Postgres
-- lanza "operator does not exist: uuid = text" y el UPDATE que marca el pedido
-- como pagado falla, por lo que confirm-payment responde 500 y el pedido se
-- queda en 'pending' aunque Stripe ya haya cobrado.
alter table public.order_items
  alter column menu_item_id type uuid using menu_item_id::uuid;

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

create index if not exists orders_user_id_idx on public.orders (user_id);
create index if not exists order_items_order_id_idx on public.order_items (order_id);

-- Seguridad (RLS): cada cliente solo puede LEER sus propios pedidos.
-- Nadie puede insertar/modificar desde la app: eso lo hacen únicamente las
-- Edge Functions con la clave de servicio, después de calcular el monto real.
alter table public.orders enable row level security;
alter table public.order_items enable row level security;

drop policy if exists "Ver mis pedidos" on public.orders;
create policy "Ver mis pedidos" on public.orders
  for select to authenticated
  using (user_id = auth.uid());

drop policy if exists "Ver los productos de mis pedidos" on public.order_items;
create policy "Ver los productos de mis pedidos" on public.order_items
  for select to authenticated
  using (
    exists (
      select 1 from public.orders o
      where o.id = order_items.order_id and o.user_id = auth.uid()
    )
  );
