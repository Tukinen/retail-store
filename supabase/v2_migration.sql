-- Run AFTER schema.sql, on a fresh/test project first. Existing sales remain legacy records.
create table public.receipts(id uuid primary key default gen_random_uuid(),owner_id uuid not null default auth.uid() references auth.users(id),created_at timestamptz not null default now(),status text not null default 'completed');
create table public.receipt_lines(id uuid primary key default gen_random_uuid(),receipt_id uuid not null references public.receipts(id),owner_id uuid not null references auth.users(id),product_id uuid not null references public.products(id),quantity integer not null check(quantity>0),unit_price numeric(14,2) not null,unit_cost numeric(14,2) not null,returned_quantity integer not null default 0 check(returned_quantity>=0 and returned_quantity<=quantity));
create table public.receipt_payments(id uuid primary key default gen_random_uuid(),receipt_id uuid not null references public.receipts(id),owner_id uuid not null references auth.users(id),method text not null check(method in ('cash','bank','pos')),amount numeric(14,2) not null check(amount>0));
create table public.returns(id uuid primary key default gen_random_uuid(),owner_id uuid not null references auth.users(id),line_id uuid not null references public.receipt_lines(id),quantity integer not null check(quantity>0),restockable boolean not null,refund_method text not null check(refund_method in ('cash','bank','pos')),refund_amount numeric(14,2) not null check(refund_amount>=0),created_at timestamptz not null default now());
create table public.cash_sessions(id uuid primary key default gen_random_uuid(),owner_id uuid not null default auth.uid() references auth.users(id),opened_at timestamptz not null default now(),opening_amount numeric(14,2) not null check(opening_amount>=0),closed_at timestamptz,expected_amount numeric(14,2),counted_amount numeric(14,2),difference numeric(14,2),note text);
create unique index one_open_cash_session on public.cash_sessions(owner_id) where closed_at is null;
create index receipt_owner_time on public.receipts(owner_id,created_at);
create index returns_owner_time on public.returns(owner_id,created_at);
alter table public.expenses add column if not exists payment_method text not null default 'cash' check(payment_method in ('cash','bank','pos'));
-- Correct existing stock cost basis; no historical cost reconstruction possible for old sales.
-- For opening inventory, product.cost is assumed to be the opening weighted-average cost.
alter table public.receipts enable row level security;
alter table public.receipt_lines enable row level security;
alter table public.receipt_payments enable row level security;
alter table public.returns enable row level security;
alter table public.cash_sessions enable row level security;
create policy receipts_read on public.receipts for select to authenticated using(owner_id=auth.uid());
create policy lines_read on public.receipt_lines for select to authenticated using(owner_id=auth.uid());
create policy payments_read on public.receipt_payments for select to authenticated using(owner_id=auth.uid());
create policy returns_read on public.returns for select to authenticated using(owner_id=auth.uid());
create policy sessions_read on public.cash_sessions for select to authenticated using(owner_id=auth.uid());
revoke insert,update,delete on public.receipts,public.receipt_lines,public.receipt_payments,public.returns,public.cash_sessions from authenticated;
-- Prevent legacy sale RPC bypassing the receipt model.
revoke execute on function public.record_sale(uuid,integer,text) from authenticated;
create or replace function public.restock_product(p_product uuid,p_quantity integer,p_cost numeric)
returns void language plpgsql security definer set search_path = '' as $$
declare p public.products%rowtype; newcost numeric;
begin
 if auth.uid() is null or p_quantity is null or p_quantity<=0 or p_cost is null or p_cost<0 then raise exception 'Буруу утга'; end if;
 select * into p from public.products where id=p_product and owner_id=auth.uid() for update;
 if not found then raise exception 'Бараа олдсонгүй'; end if;
 newcost:=round((p.quantity*p.cost+p_quantity*p_cost)/(p.quantity+p_quantity),2);
 update public.products set quantity=quantity+p_quantity,cost=newcost where id=p.id;
 insert into public.stock_movements(owner_id,product_id,quantity,unit_cost) values(auth.uid(),p.id,p_quantity,p_cost);
end $$;
create or replace function public.create_receipt(p_lines jsonb,p_payments jsonb)
returns uuid language plpgsql security definer set search_path = '' as $$
declare r uuid; x record; p public.products%rowtype; total numeric:=0; paid numeric:=0; n integer:=0;
begin
 if auth.uid() is null then raise exception 'Нэвтэрнэ үү'; end if;
 if jsonb_typeof(p_lines)<>'array' or jsonb_array_length(p_lines)=0 or jsonb_array_length(p_lines)>100 or jsonb_typeof(p_payments)<>'array' then raise exception 'Буруу баримт'; end if;
 -- lock product rows in stable order to avoid deadlocks
 for x in select (value->>'product_id')::uuid as pid,sum((value->>'quantity')::integer) as qty from jsonb_array_elements(p_lines) group by 1 order by 1 loop
  if x.qty is null or x.qty<=0 then raise exception 'Тоо буруу'; end if;
  select * into p from public.products where id=x.pid and owner_id=auth.uid() for update;
  if not found or p.quantity<x.qty then raise exception 'Бараа олдсонгүй эсвэл үлдэгдэл хүрэлцэхгүй'; end if;
 end loop;
 insert into public.receipts(owner_id) values(auth.uid()) returning id into r;
 for x in select (value->>'product_id')::uuid as pid,(value->>'quantity')::integer as qty from jsonb_array_elements(p_lines) loop
  select * into p from public.products where id=x.pid and owner_id=auth.uid();
  insert into public.receipt_lines(receipt_id,owner_id,product_id,quantity,unit_price,unit_cost) values(r,auth.uid(),p.id,x.qty,p.price,p.cost);
  update public.products set quantity=quantity-x.qty where id=p.id;
  total:=total+x.qty*p.price;
 end loop;
 for x in select value->>'method' as method,(value->>'amount')::numeric as amount from jsonb_array_elements(p_payments) loop
  if x.method not in ('cash','bank','pos') or x.amount is null or x.amount<=0 then raise exception 'Төлбөр буруу'; end if;
  insert into public.receipt_payments(receipt_id,owner_id,method,amount) values(r,auth.uid(),x.method,x.amount);
  paid:=paid+x.amount;n:=n+1;
 end loop;
 if n=0 or round(paid,2)<>round(total,2) then raise exception 'Төлбөрийн нийлбэр баримтын дүнтэй тэнцэх ёстой'; end if;
 return r;
end $$;
create or replace function public.return_line(p_line uuid,p_quantity integer,p_restockable boolean,p_method text)
returns uuid language plpgsql security definer set search_path = '' as $$
declare l public.receipt_lines%rowtype; p public.products%rowtype; rid uuid; refund numeric; total_paid numeric; method_paid numeric;
begin
 if auth.uid() is null or p_quantity is null or p_quantity<=0 or p_restockable is null or p_method not in ('cash','bank','pos') then raise exception 'Буцаалтын мэдээлэл буруу'; end if;
 select * into l from public.receipt_lines where id=p_line and owner_id=auth.uid() for update;
 if not found or p_quantity>l.quantity-l.returned_quantity then raise exception 'Буцаах боломжгүй тоо'; end if;
 -- Refund method must be one of the methods originally paid; partial refunds can be allocated manually.
 select coalesce(sum(amount),0),coalesce(sum(amount) filter(where method=p_method),0) into total_paid,method_paid from public.receipt_payments where receipt_id=l.receipt_id and owner_id=auth.uid();
 if method_paid=0 then raise exception 'Анхны баримтад энэ төлбөрийн төрөл байхгүй'; end if;
 refund:=round(l.unit_price*p_quantity,2);
 update public.receipt_lines set returned_quantity=returned_quantity+p_quantity where id=l.id;
 if p_restockable then
  select * into p from public.products where id=l.product_id and owner_id=auth.uid() for update;
  update public.products set cost=round((quantity*cost+p_quantity*l.unit_cost)/(quantity+p_quantity),2),quantity=quantity+p_quantity where id=p.id;
 end if;
 insert into public.returns(owner_id,line_id,quantity,restockable,refund_method,refund_amount) values(auth.uid(),l.id,p_quantity,p_restockable,p_method,refund) returning id into rid;
 return rid;
end $$;
create or replace function public.open_cash(p_opening numeric) returns uuid language plpgsql security definer set search_path='' as $$
declare sid uuid;
begin
 if auth.uid() is null or p_opening is null or p_opening<0 then raise exception 'Буруу дүн'; end if;
 insert into public.cash_sessions(owner_id,opening_amount) values(auth.uid(),p_opening) returning id into sid;return sid;
end $$;
create or replace function public.close_cash(p_session uuid,p_counted numeric,p_note text default '') returns numeric language plpgsql security definer set search_path='' as $$
declare s public.cash_sessions%rowtype; expected numeric;
begin
 if auth.uid() is null or p_counted is null or p_counted<0 then raise exception 'Буруу дүн'; end if;
 select * into s from public.cash_sessions where id=p_session and owner_id=auth.uid() and closed_at is null for update;
 if not found then raise exception 'Нээлттэй касс олдсонгүй'; end if;
 select s.opening_amount
 +coalesce((select sum(rp.amount) from public.receipt_payments rp join public.receipts r on r.id=rp.receipt_id where rp.owner_id=auth.uid() and rp.method='cash' and r.created_at>=s.opened_at and r.created_at<=now()),0)
 -coalesce((select sum(t.refund_amount) from public.returns t where t.owner_id=auth.uid() and t.refund_method='cash' and t.created_at>=s.opened_at and t.created_at<=now()),0)
 -coalesce((select sum(e.amount) from public.expenses e where e.owner_id=auth.uid() and e.payment_method='cash' and e.spent_at>=s.opened_at and e.spent_at<=now()),0) into expected;
 update public.cash_sessions set closed_at=now(),expected_amount=expected,counted_amount=p_counted,difference=p_counted-expected,note=coalesce(p_note,'') where id=s.id;
 return p_counted-expected;
end $$;
revoke all on function public.create_receipt(jsonb,jsonb),public.return_line(uuid,integer,boolean,text),public.open_cash(numeric),public.close_cash(uuid,numeric,text) from public;
grant execute on function public.create_receipt(jsonb,jsonb),public.return_line(uuid,integer,boolean,text),public.open_cash(numeric),public.close_cash(uuid,numeric,text) to authenticated;
