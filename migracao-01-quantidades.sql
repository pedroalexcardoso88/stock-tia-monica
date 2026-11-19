-- Migração 01 — quantidades e vendas parciais
-- Correr UMA vez no Supabase → SQL Editor

-- 1) Quantidade comprada por artigo
alter table public.artigos
  add column if not exists quantidade int not null default 1 check (quantidade >= 1);

-- 2) Vendas passam a ter tabela própria (várias vendas por artigo)
create table public.vendas (
  id bigint generated always as identity primary key,
  artigo_id bigint not null references public.artigos(id) on delete cascade,
  quantidade int not null default 1 check (quantidade >= 1),
  preco numeric(10,2) not null,            -- total recebido nesta venda
  canal text not null check (canal in ('vinted','presencial')),
  data_venda date not null default current_date,
  estado text not null default 'vendido' check (estado in ('vendido','enviado','concluido')),
  data_envio date,
  created_at timestamptz not null default now()
);
create index on public.vendas (artigo_id);
create index on public.vendas (data_venda);

alter table public.vendas enable row level security;
create policy "membros gerem vendas" on public.vendas
  for all to authenticated using (public.is_membro()) with check (public.is_membro());
grant select, insert, update, delete on public.vendas to authenticated;
grant usage on all sequences in schema public to authenticated;

-- 3) Passar as vendas já registadas para a nova tabela
insert into public.vendas (artigo_id, quantidade, preco, canal, data_venda, estado, data_envio)
select id, 1, preco_venda, coalesce(canal, 'presencial'), coalesce(data_venda, current_date),
       case when estado in ('vendido','enviado','concluido') then estado else 'concluido' end,
       data_envio
from public.artigos
where preco_venda is not null;

update public.artigos
set estado = case when canal = 'vinted' then 'publicado' else 'stock' end
where estado in ('vendido','enviado','concluido');

-- 4) Limpar colunas antigas
alter table public.artigos
  drop column if exists canal,
  drop column if exists preco_venda,
  drop column if exists data_venda,
  drop column if exists data_envio;
