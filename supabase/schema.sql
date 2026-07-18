-- ============================================================================
-- SISTEMA MISERICORDIA — Esquema Supabase (Postgres)
-- Migrado desde: Sistema_Misericordia_.xlsx
-- ============================================================================
-- Cómo correr esto:
--   1. Entrá a tu proyecto en supabase.com -> SQL Editor
--   2. Pegá este archivo completo -> Run
--   3. Después corré supabase/seed.sql (generado por migrate_from_excel.py)
--      para cargar los datos actuales de la planilla.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- ENUMS
-- ---------------------------------------------------------------------------
create type estado_item as enum (
  'Pendiente','En Produccion','Faltante','Cancelado',
  'Despachado','Entrega Bs As','sin existencia','Entregado',
  'Disponible','GE','ZF'
);

create type ubicacion_stock as enum ('Stock A','Stock B (IDUO)','Stock GE');

-- ---------------------------------------------------------------------------
-- CATÁLOGO: articulos  (reemplaza la hoja "Configuracion")
-- ---------------------------------------------------------------------------
create table articulos (
  id             bigserial primary key,
  codigo         text unique not null,       -- ej: "3072/01"
  descripcion    text,
  uds_por_bulto  numeric,
  categoria      text,                       -- ej: "Sabanas Importadas"
  familia_ctzf   text,                       -- ej: "Sabanas Importadas TWIN" (antes vía REGEXEXTRACT+SWITCH)
  created_at     timestamptz default now()
);

create index idx_articulos_codigo on articulos (codigo);

-- ---------------------------------------------------------------------------
-- clientes  (antes: texto libre repetido en varias columnas "Cliente")
-- ---------------------------------------------------------------------------
create table clientes (
  id      bigserial primary key,
  nombre  text unique not null
);

-- ---------------------------------------------------------------------------
-- pedidos_web  (reemplaza la hoja "PEDIDOS WEB" — intake crudo)
-- ---------------------------------------------------------------------------
create table pedidos_web (
  id             bigserial primary key,
  numero_pedido  text,
  fecha_carga    timestamptz default now(),
  solicitante    text,
  destino        text,
  articulo_id    bigint references articulos(id),
  cantidad       numeric,
  bultos         numeric,
  impo_nac       text check (impo_nac in ('IMPO','NAC')),
  color          text,
  urgente        boolean default false,
  estado         text default 'Nuevo'
);

-- ---------------------------------------------------------------------------
-- pedidos  (reemplaza la hoja "General")
-- ---------------------------------------------------------------------------
create table pedidos (
  id                bigserial primary key,
  numero_pedido     text unique not null,
  cliente_id        bigint references clientes(id),
  destino           text,                 -- Cliente / Galpón Externo / Oroño / Otro
  observaciones     text,
  fecha_ingreso     date,
  fecha_completado  date,
  created_at        timestamptz default now()
);

-- ---------------------------------------------------------------------------
-- pedido_items  (fusiona "Detalle" + "Entregados": la diferencia es el estado)
-- ---------------------------------------------------------------------------
create table pedido_items (
  id                  bigserial primary key,
  pedido_id           bigint references pedidos(id) on delete cascade,
  articulo_id         bigint references articulos(id),
  unidades            numeric,
  bultos              numeric,
  bultos_parciales    numeric,
  pallets             numeric,
  estado              estado_item default 'Pendiente',
  carga_en            text,               -- Zona Franca / Galpon Externo / Bs As
  remito_guia         text,
  fc                  text,
  destino             text,
  descarga_en         text,
  provincia_ciudad    text,
  transporte          text,               -- Pampero / Brinatti / Otro
  valor_aprox         numeric,
  adicional_x_envio   numeric,
  fecha_carga         date,
  despachado          boolean default false,
  observacion         text,
  created_at          timestamptz default now(),
  updated_at          timestamptz default now()
);

create index idx_pedido_items_pedido on pedido_items (pedido_id);
create index idx_pedido_items_articulo on pedido_items (articulo_id);
create index idx_pedido_items_despachado on pedido_items (despachado);

-- ---------------------------------------------------------------------------
-- stock  (reemplaza la hoja "Stock General")
-- ---------------------------------------------------------------------------
create table stock (
  id              bigserial primary key,
  articulo_id     bigint references articulos(id),
  ubicacion       ubicacion_stock not null,
  cantidad        numeric default 0,
  actualizado_at  timestamptz default now(),
  unique (articulo_id, ubicacion)
);

-- ---------------------------------------------------------------------------
-- Zona Franca: salidas_zf (Encabezados ZFE) + salida_zf_items (Detalle ZF)
-- ---------------------------------------------------------------------------
create table salidas_zf (
  id             bigserial primary key,
  numero_salida  text unique,
  numero_zfe     text,
  fecha          date
);

create table salida_zf_familias (
  id              bigserial primary key,
  salida_zf_id    bigint references salidas_zf(id) on delete cascade,
  familia         text,
  uds_declaradas  numeric
);

create table salida_zf_items (
  id             bigserial primary key,
  salida_zf_id   bigint references salidas_zf(id) on delete cascade,
  articulo_id    bigint references articulos(id),
  familia_ctzf   text,
  destino        text,                 -- Cliente / Stock GE
  pedido_id      bigint references pedidos(id),
  bultos         numeric,
  unidades       numeric,
  pallets        numeric,
  stock_origen   ubicacion_stock,
  observacion    text,
  cliente_id     bigint references clientes(id)
);

-- ---------------------------------------------------------------------------
-- guias_carga (reemplaza "Guia de Carga")
-- ---------------------------------------------------------------------------
create table guias_carga (
  id             bigserial primary key,
  transporte     text,
  fecha          date,
  estado         text default 'Intencion de Carga',  -- o "Carga Confirmada"
  created_at     timestamptz default now()
);

create table guia_carga_items (
  id              bigserial primary key,
  guia_carga_id   bigint references guias_carga(id) on delete cascade,
  pedido_item_id  bigint references pedido_items(id),
  validado_en_ge  boolean default false
);

-- ============================================================================
-- TRIGGERS: mantener stock y timestamps al día automáticamente
-- ============================================================================

-- updated_at automático en pedido_items
create or replace function set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create trigger trg_pedido_items_updated_at
  before update on pedido_items
  for each row execute function set_updated_at();

-- Al marcar un ítem "despachado", descuenta stock de la ubicación de origen.
-- Ajustá la lógica según cómo definan "carga_en" -> ubicacion_stock en la práctica.
create or replace function descontar_stock_al_despachar()
returns trigger as $$
begin
  if new.despachado = true and (old.despachado is distinct from true) then
    update stock
       set cantidad = cantidad - coalesce(new.unidades, 0),
           actualizado_at = now()
     where articulo_id = new.articulo_id
       and ubicacion = case
             when new.carga_en = 'Zona Franca' then 'Stock GE'::ubicacion_stock
             else 'Stock GE'::ubicacion_stock
           end;
  end if;
  return new;
end;
$$ language plpgsql;

create trigger trg_descontar_stock
  after update on pedido_items
  for each row execute function descontar_stock_al_despachar();

-- ============================================================================
-- VISTAS: reemplazan las fórmulas de "General" y "Dashboard"
-- ============================================================================

-- Estado general + lead time de cada pedido (antes: fórmula IF/COUNTIFS en General!D)
create or replace view vista_pedidos_estado as
select
  p.id,
  p.numero_pedido,
  p.cliente_id,
  c.nombre as cliente,
  p.destino,
  p.fecha_ingreso,
  p.fecha_completado,
  count(pi.id) as total_items,
  count(pi.id) filter (where pi.despachado) as items_despachados,
  case
    when count(pi.id) = 0 then 'Pendiente'
    when count(pi.id) filter (where pi.despachado) = 0 then 'Pendiente'
    when count(pi.id) filter (where pi.despachado) = count(pi.id) then 'Completado'
    else 'En proceso'
  end as estado_general,
  (p.fecha_completado - p.fecha_ingreso) as lead_time_dias
from pedidos p
left join clientes c on c.id = p.cliente_id
left join pedido_items pi on pi.pedido_id = p.id
group by p.id, c.nombre;

-- KPIs del Dashboard (antes: COUNTA/COUNTIF sueltas en Dashboard!A5:Q6)
create or replace view vista_dashboard_kpis as
select
  count(*)                                    as total_items,
  count(*) filter (where despachado)          as items_cargados,
  count(*) filter (where not despachado)      as items_pendientes,
  round(
    100.0 * count(*) filter (where despachado) / nullif(count(*), 0), 1
  ) as pct_cargado
from pedido_items;

-- Top artículos despachados (antes: QUERY + REGEXREPLACE en Dashboard!G10)
create or replace view vista_top_articulos as
select
  a.codigo,
  a.descripcion,
  sum(pi.unidades) as unidades_despachadas
from pedido_items pi
join articulos a on a.id = pi.articulo_id
where pi.despachado
group by a.codigo, a.descripcion
order by unidades_despachadas desc
limit 10;

-- Ítems despachados por transporte (antes: COUNTIFS por Pampero/Brinatti)
create or replace view vista_items_por_transporte as
select transporte, count(*) as items
from pedido_items
where despachado
group by transporte
order by items desc;

-- Stock consolidado por artículo (suma de las 3 ubicaciones)
create or replace view vista_stock_consolidado as
select
  a.codigo,
  a.descripcion,
  a.categoria,
  coalesce(sum(s.cantidad) filter (where s.ubicacion = 'Stock A'), 0)          as stock_a,
  coalesce(sum(s.cantidad) filter (where s.ubicacion = 'Stock B (IDUO)'), 0)   as stock_b,
  coalesce(sum(s.cantidad) filter (where s.ubicacion = 'Stock GE'), 0)         as stock_ge,
  coalesce(sum(s.cantidad), 0) as total
from articulos a
left join stock s on s.articulo_id = a.id
group by a.id, a.codigo, a.descripcion, a.categoria
order by a.codigo;

-- ============================================================================
-- ROW LEVEL SECURITY
-- ============================================================================
-- Nota: en ALAV COMEX el RLS bloqueaba escrituras silenciosamente y terminaron
-- deshabilitándolo. Arrancamos igual acá (todo el equipo entra con la misma
-- API key desde una red/app confiable). Si más adelante suman login por
-- usuario, ahí sí conviene activar policies por rol.
alter table articulos          disable row level security;
alter table clientes           disable row level security;
alter table pedidos_web        disable row level security;
alter table pedidos            disable row level security;
alter table pedido_items       disable row level security;
alter table stock              disable row level security;
alter table salidas_zf         disable row level security;
alter table salida_zf_familias disable row level security;
alter table salida_zf_items    disable row level security;
alter table guias_carga        disable row level security;
alter table guia_carga_items   disable row level security;
