-- Run in Supabase SQL editor. Never expose the service-role key in the browser.
create extension if not exists pgcrypto;
create table public.products (
 id uuid primary key default gen_random_uuid(), owner_id uuid not null default auth.uid() references auth.users(id),
 name text not null, sku text, category text not null default 'Бусад', image_path text,
 quantity integer not null default 0 check(quantity >= 0), cost numeric(14,2) not null check(cost >= 0),
 price numeric(14,2) not null check(price >= 0), low_stock integer not null default 5 check(low_stock >= 0),
 created_at timestamptz not null default now(), unique(owner_id,sku)
);
create table public.sales (
 id uuid primary key default gen_random_uuid(), owner_id uuid not null default auth.uid() references auth.users(id),
 product_id uuid not null references public.products(id), quantity integer not null check(quantity > 0),
 unit_price numeric(14,2) not null check(unit_price >= 0), unit_cost numeric(14,2) not null check(unit_cost >= 0),
 payment_method text not null check(payment_method in ('cash','bank','pos')),
 sold_at timestamptz not null default now()
);
create table public.expenses (
 id uuid primary key default gen_random_uuid(), owner_id uuid not null default auth.uid() references auth.users(id),
 category text not null, description text not null default '', amount numeric(14,2) not null check(amount > 0),
 spent_at timestamptz not null default now()
);
create table public.stock_movements (
 id uuid primary key default gen_random_uuid(), owner_id uuid not null default auth.uid() references auth.users(id),
 product_id uuid not null references public.products(id), quantity integer not null check(quantity > 0),
 unit_cost numeric(14,2) not null check(unit_cost >= 0), created_at timestamptz not null default now()
);
create index sales_owner_date on public.sales(owner_id,sold_at);
create index expenses_owner_date on public.expenses(owner_id,spent_at);
create index products_owner on public.products(owner_id);
alter table public.products enable row level security;
alter table public.sales enable row level security;
alter table public.expenses enable row level security;
alter table public.stock_movements enable row level security;
create policy products_owner on public.products for all to authenticated using(owner_id=auth.uid()) with check(owner_id=auth.uid());
create policy sales_read on public.sales for select to authenticated using(owner_id=auth.uid());
create policy expenses_owner on public.expenses for all to authenticated using(owner_id=auth.uid()) with check(owner_id=auth.uid());
create policy stock_read on public.stock_movements for select to authenticated using(owner_id=auth.uid());
-- Block direct client modification of inventory and historical sales; use atomic functions.
revoke insert,update,delete on public.sales from authenticated;
revoke insert,update,delete on public.stock_movements from authenticated;
revoke update,delete on public.products from authenticated;
create or replace function public.record_sale(p_product uuid,p_quantity integer,p_method text)
returns uuid language plpgsql security definer set search_path = '' as $$
declare p public.products%rowtype; sid uuid;
begin
 if auth.uid() is null then raise exception 'Нэвтэрнэ үү'; end if;
 if p_quantity is null or p_quantity <= 0 or p_method not in ('cash','bank','pos') then raise exception 'Буруу утга'; end if;
 select * into p from public.products where id=p_product and owner_id=auth.uid() for update;
 if not found then raise exception 'Бараа олдсонгүй'; end if;
 if p.quantity < p_quantity then raise exception 'Үлдэгдэл хүрэлцэхгүй'; end if;
 update public.products set quantity=quantity-p_quantity where id=p.id;
 insert into public.sales(owner_id,product_id,quantity,unit_price,unit_cost,payment_method)
 values(auth.uid(),p.id,p_quantity,p.price,p.cost,p_method) returning id into sid;
 return sid;
end $$;
create or replace function public.restock_product(p_product uuid,p_quantity integer,p_cost numeric)
returns void language plpgsql security definer set search_path = '' as $$
declare p public.products%rowtype;
begin
 if auth.uid() is null or p_quantity is null or p_quantity<=0 or p_cost is null or p_cost<0 then raise exception 'Буруу утга'; end if;
 select * into p from public.products where id=p_product and owner_id=auth.uid() for update;
 if not found then raise exception 'Бараа олдсонгүй'; end if;
 update public.products set quantity=quantity+p_quantity, cost=p_cost where id=p.id;
 insert into public.stock_movements(owner_id,product_id,quantity,unit_cost) values(auth.uid(),p.id,p_quantity,p_cost);
end $$;
revoke all on function public.record_sale(uuid,integer,text) from public;
revoke all on function public.restock_product(uuid,integer,numeric) from public;
grant execute on function public.record_sale(uuid,integer,text) to authenticated;
grant execute on function public.restock_product(uuid,integer,numeric) to authenticated;
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('product-images','product-images',false,5242880,array['image/jpeg','image/png','image/webp'])
on conflict(id) do nothing;
create policy image_insert on storage.objects for insert to authenticated
with check(bucket_id='product-images' and (storage.foldername(name))[1]=auth.uid()::text);
create policy image_read on storage.objects for select to authenticated
using(bucket_id='product-images' and (storage.foldername(name))[1]=auth.uid()::text);
