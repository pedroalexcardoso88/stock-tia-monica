-- Stock · Loja da Tia Mónica
-- Correr uma vez no Supabase → SQL Editor (projeto novo)

-- 1) Quem tem acesso (trocar pelos emails Google reais)
create table public.membros (email text primary key);
insert into public.membros (email) values
  ('EMAIL_DA_MONICA@gmail.com'),
  ('EMAIL_DO_PEDRO@gmail.com');

-- 2) Compras (avulso ou lote)
create table public.compras (
  id bigint generated always as identity primary key,
  data date not null default current_date,
  tipo text not null check (tipo in ('avulso','lote')),
  origem text,
  custo_total numeric(10,2) not null default 0,
  notas text,
  created_at timestamptz not null default now()
);

-- 3) Artigos (o id é o código da etiqueta: #0001, #0002…)
create table public.artigos (
  id bigint generated always as identity primary key,
  compra_id bigint references public.compras(id) on delete cascade,
  nome text not null,
  categoria text,
  tamanho text,
  custo numeric(10,2) not null default 0,
  estado text not null default 'stock'
    check (estado in ('stock','publicado','vendido','enviado','concluido')),
  canal text check (canal in ('vinted','presencial')),
  preco_venda numeric(10,2),
  data_venda date,
  data_envio date,
  notas text,
  created_at timestamptz not null default now()
);
create index on public.artigos (compra_id);
create index on public.artigos (data_venda);

-- 4) Segurança: só os emails em "membros" leem/escrevem
create or replace function public.is_membro() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.membros
    where lower(email) = lower(auth.jwt() ->> 'email')
  );
$$;
revoke all on function public.is_membro() from public, anon;
grant execute on function public.is_membro() to authenticated;

alter table public.membros enable row level security;
alter table public.compras enable row level security;
alter table public.artigos enable row level security;

create policy "membros gerem compras" on public.compras
  for all to authenticated using (public.is_membro()) with check (public.is_membro());
create policy "membros gerem artigos" on public.artigos
  for all to authenticated using (public.is_membro()) with check (public.is_membro());

grant select, insert, update, delete on public.compras, public.artigos to authenticated;
grant usage on all sequences in schema public to authenticated;
