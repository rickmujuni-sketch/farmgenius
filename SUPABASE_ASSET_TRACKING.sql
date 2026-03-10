-- FarmGenius Biological Asset Tracking + IAS 41 style valuation layer
-- Apply after SUPABASE_SETUP.sql (and optionally SUPABASE_RLS_PRODUCTION.sql)

begin;

-- ------------------------------------------------------------------
-- Role helper dependency
-- ------------------------------------------------------------------
-- Canonical definitions live in SUPABASE_RLS_PRODUCTION.sql
-- Ensure that script has been applied before this one.
do $$
begin
  if to_regprocedure('public.is_manager_or_owner()') is null then
    raise exception 'Missing required function public.is_manager_or_owner(). Run SUPABASE_RLS_PRODUCTION.sql first.';
  end if;
end $$;

-- ------------------------------------------------------------------
-- Core asset tracking schema
-- ------------------------------------------------------------------
create table if not exists public.asset_zones (
  id text primary key,
  name text not null,
  zone_type text not null,
  parent_zone_id text references public.asset_zones(id) on delete set null,
  boundary_geojson jsonb default '{}'::jsonb,
  metadata jsonb default '{}'::jsonb,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table if not exists public.biological_assets (
  id text primary key,
  asset_type text not null check (asset_type in ('banana_plot', 'tree_crop', 'livestock_group', 'livestock_individual')),
  species text not null,
  zone_id text references public.asset_zones(id) on delete set null,
  quantity numeric not null default 0,
  unit text not null default 'count',
  maturity_stage text,
  valuation_method text not null default 'market_price_x_expected_output',
  unit_price numeric,
  price_unit text,
  production_low numeric,
  production_medium numeric,
  production_high numeric,
  production_unit text,
  is_active boolean not null default true,
  metadata jsonb default '{}'::jsonb,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table if not exists public.asset_valuations (
  id bigint generated always as identity primary key,
  asset_id text not null references public.biological_assets(id) on delete cascade,
  valuation_date date not null,
  scenario_low numeric not null default 0,
  scenario_medium numeric not null default 0,
  scenario_high numeric not null default 0,
  currency text not null default 'TZS',
  notes text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz default now(),
  unique(asset_id, valuation_date)
);

create table if not exists public.daily_asset_checks (
  id text primary key,
  check_date date not null,
  time_block text not null,
  zone_id text references public.asset_zones(id) on delete set null,
  checklist_type text not null,
  observations jsonb default '{}'::jsonb,
  alerts jsonb default '[]'::jsonb,
  recorded_by uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz default now()
);

create table if not exists public.kml_zone_asset_zone_map (
  id bigint generated always as identity primary key,
  kml_zone_id text not null,
  asset_zone_id text not null references public.asset_zones(id) on delete cascade,
  sort_order int not null default 0,
  notes text,
  created_at timestamptz default now(),
  unique(kml_zone_id, asset_zone_id)
);

create index if not exists asset_zones_zone_type_idx on public.asset_zones(zone_type);
create index if not exists biological_assets_asset_type_idx on public.biological_assets(asset_type);
create index if not exists biological_assets_zone_id_idx on public.biological_assets(zone_id);
create index if not exists asset_valuations_asset_date_idx on public.asset_valuations(asset_id, valuation_date desc);
create index if not exists daily_asset_checks_date_idx on public.daily_asset_checks(check_date desc);
create index if not exists daily_asset_checks_zone_idx on public.daily_asset_checks(zone_id);
create index if not exists kml_zone_asset_zone_map_kml_idx on public.kml_zone_asset_zone_map(kml_zone_id, sort_order);

-- ------------------------------------------------------------------
-- Views for dashboard and reporting
-- ------------------------------------------------------------------
create or replace view public.biological_asset_latest_values as
with latest as (
  select distinct on (v.asset_id)
    v.asset_id,
    v.valuation_date,
    v.scenario_low,
    v.scenario_medium,
    v.scenario_high,
    v.currency,
    v.created_at
  from public.asset_valuations v
  order by v.asset_id, v.valuation_date desc, v.created_at desc
)
select
  a.id as asset_id,
  a.asset_type,
  a.species,
  a.zone_id,
  a.quantity,
  a.unit,
  a.maturity_stage,
  l.valuation_date,
  coalesce(l.scenario_low, 0) as scenario_low,
  coalesce(l.scenario_medium, 0) as scenario_medium,
  coalesce(l.scenario_high, 0) as scenario_high,
  coalesce(l.currency, 'TZS') as currency
from public.biological_assets a
left join latest l on l.asset_id = a.id
where a.is_active = true;

create or replace view public.biological_asset_dashboard_summary as
select
  count(*)::int as active_assets,
  coalesce(sum(quantity), 0) as total_quantity,
  coalesce(sum(scenario_low), 0) as total_low,
  coalesce(sum(scenario_medium), 0) as total_medium,
  coalesce(sum(scenario_high), 0) as total_high,
  coalesce(sum(case when asset_type in ('banana_plot', 'tree_crop') then scenario_medium else 0 end), 0) as crops_medium,
  coalesce(sum(case when asset_type in ('livestock_group', 'livestock_individual') then scenario_medium else 0 end), 0) as livestock_medium
from public.biological_asset_latest_values;

create or replace view public.biological_asset_category_summary as
select
  asset_type,
  count(*)::int as asset_count,
  coalesce(sum(scenario_low), 0) as total_low,
  coalesce(sum(scenario_medium), 0) as total_medium,
  coalesce(sum(scenario_high), 0) as total_high
from public.biological_asset_latest_values
group by asset_type
order by asset_type;

-- ------------------------------------------------------------------
-- RLS
-- ------------------------------------------------------------------
alter table public.asset_zones enable row level security;
alter table public.biological_assets enable row level security;
alter table public.asset_valuations enable row level security;
alter table public.daily_asset_checks enable row level security;
alter table public.kml_zone_asset_zone_map enable row level security;

-- asset_zones
-- readable by authenticated users, writable only by manager/owner
-- (used for operational map lookups by all staff)
drop policy if exists "asset_zones_select_authenticated" on public.asset_zones;
create policy "asset_zones_select_authenticated"
on public.asset_zones
for select
using (auth.uid() is not null);

drop policy if exists "asset_zones_write_manager_owner" on public.asset_zones;
create policy "asset_zones_write_manager_owner"
on public.asset_zones
for all
using (public.is_manager_or_owner())
with check (public.is_manager_or_owner());

-- biological_assets
-- readable by authenticated users, mutable by manager/owner

drop policy if exists "biological_assets_select_authenticated" on public.biological_assets;
create policy "biological_assets_select_authenticated"
on public.biological_assets
for select
using (auth.uid() is not null);

drop policy if exists "biological_assets_write_manager_owner" on public.biological_assets;
create policy "biological_assets_write_manager_owner"
on public.biological_assets
for all
using (public.is_manager_or_owner())
with check (public.is_manager_or_owner());

-- asset_valuations
-- readable by authenticated users, mutable by manager/owner

drop policy if exists "asset_valuations_select_authenticated" on public.asset_valuations;
create policy "asset_valuations_select_authenticated"
on public.asset_valuations
for select
using (auth.uid() is not null);

drop policy if exists "asset_valuations_write_manager_owner" on public.asset_valuations;
create policy "asset_valuations_write_manager_owner"
on public.asset_valuations
for all
using (public.is_manager_or_owner())
with check (public.is_manager_or_owner());

-- daily_asset_checks
-- staff can insert/view own logs, manager/owner can view/update all

drop policy if exists "daily_checks_select_own_or_manager" on public.daily_asset_checks;
create policy "daily_checks_select_own_or_manager"
on public.daily_asset_checks
for select
using (recorded_by = auth.uid() or public.is_manager_or_owner());

drop policy if exists "daily_checks_insert_own" on public.daily_asset_checks;
create policy "daily_checks_insert_own"
on public.daily_asset_checks
for insert
with check (recorded_by = auth.uid() or public.is_manager_or_owner());

drop policy if exists "daily_checks_update_manager_owner" on public.daily_asset_checks;
create policy "daily_checks_update_manager_owner"
on public.daily_asset_checks
for update
using (public.is_manager_or_owner())
with check (public.is_manager_or_owner());

-- kml_zone_asset_zone_map
-- readable by authenticated users, mutable by manager/owner
drop policy if exists "kml_zone_map_select_authenticated" on public.kml_zone_asset_zone_map;
create policy "kml_zone_map_select_authenticated"
on public.kml_zone_asset_zone_map
for select
using (auth.uid() is not null);

drop policy if exists "kml_zone_map_write_manager_owner" on public.kml_zone_asset_zone_map;
create policy "kml_zone_map_write_manager_owner"
on public.kml_zone_asset_zone_map
for all
using (public.is_manager_or_owner())
with check (public.is_manager_or_owner());

-- ------------------------------------------------------------------
-- Seed zones and baseline assets (as of 2025-10-12)
-- ------------------------------------------------------------------
insert into public.asset_zones (id, name, zone_type, metadata)
values
  ('PLT-12-BN', 'Plot 12 Banana Block', 'plot', '{"acreage":3,"crop":"banana"}'::jsonb),
  ('ORCH-A', 'Orchard Zone A (Palm/Coconut)', 'orchard', '{}'::jsonb),
  ('ORCH-B', 'Orchard Zone B (Mango)', 'orchard', '{}'::jsonb),
  ('ORCH-C', 'Orchard Zone C (Avocado/Guava)', 'orchard', '{}'::jsonb),
  ('ORCH-D', 'Orchard Zone D (Citrus)', 'orchard', '{}'::jsonb),
  ('ORCH-E', 'Orchard Zone E (Apple)', 'orchard', '{}'::jsonb),
  ('ORCH-F', 'Orchard Zone F (Soursop/Papaya)', 'orchard', '{}'::jsonb),
  ('LVST-P1', 'Poultry Compound', 'livestock', '{}'::jsonb),
  ('LVST-G1', 'Goat Pen', 'livestock', '{}'::jsonb),
  ('LVST-C1', 'Cattle Pen', 'livestock', '{}'::jsonb),
  ('LVST-R1', 'Rabbit Pen', 'livestock', '{}'::jsonb)
on conflict (id) do update
set name = excluded.name,
    zone_type = excluded.zone_type,
    metadata = excluded.metadata,
    updated_at = now();

insert into public.biological_assets (
  id, asset_type, species, zone_id, quantity, unit, maturity_stage,
  unit_price, price_unit, production_low, production_medium, production_high, production_unit, metadata
)
values
  ('BAN-P12-001', 'banana_plot', 'banana', 'PLT-12-BN', 1570, 'trees', 'mature', 15000, 'TZS_per_bunch', 0.8, 1.0, 1.2, 'bunches_per_tree_per_year', '{"location":"Plot No. 12"}'::jsonb),
  ('PALM-ORCH-A-001', 'tree_crop', 'palm', 'ORCH-A', 12, 'trees', 'fully_mature', 15000, 'TZS_per_bunch', 10, 10, 10, 'bunches_per_tree_per_year', '{}'::jsonb),
  ('APPL-ORCH-E-001', 'tree_crop', 'apple', 'ORCH-E', 18, 'trees', 'newly_planted', 1000, 'TZS_per_fruit', 500, 1250, 2000, 'fruits_per_tree_per_year', '{}'::jsonb),
  ('SOUR-ORCH-F-001', 'tree_crop', 'soursop', 'ORCH-F', 10, 'trees', 'established', 5000, 'TZS_per_fruit', 12, 18, 24, 'fruits_per_tree_per_year', '{}'::jsonb),
  ('AVOC-ORCH-C-001', 'tree_crop', 'avocado', 'ORCH-C', 58, 'trees', 'established', 1600, 'TZS_per_kg', 12, 84, 156, 'kg_per_tree_per_year', '{}'::jsonb),
  ('MANG-ORCH-B-001', 'tree_crop', 'mango', 'ORCH-B', 231, 'trees', 'established', 900, 'TZS_per_fruit', 40, 68.5, 97, 'fruits_per_tree_per_year', '{}'::jsonb),
  ('PAPA-ORCH-F-001', 'tree_crop', 'papaya', 'ORCH-F', 13, 'trees', 'producing', null, 'TZS_per_tree_per_harvest', 20000, 35000, 50000, 'TZS_per_tree_per_harvest', '{"annualization_harvests":[4,6,8]}'::jsonb),
  ('GUAV-ORCH-C-001', 'tree_crop', 'guava', 'ORCH-C', 20, 'trees', 'established', 4000, 'TZS_per_kg', 200, 275, 350, 'kg_per_tree_per_year', '{}'::jsonb),
  ('TANG-ORCH-D-001', 'tree_crop', 'tangerine', 'ORCH-D', 56, 'trees', 'established', 500, 'TZS_per_fruit', 500, 550, 600, 'fruits_per_tree_per_season', '{}'::jsonb),
  ('LEMO-ORCH-D-001', 'tree_crop', 'lemon', 'ORCH-D', 78, 'trees', 'established', 2000, 'TZS_per_kg', 150, 150, 150, 'kg_per_tree_per_year', '{}'::jsonb),
  ('COCO-ORCH-A-001', 'tree_crop', 'coconut', 'ORCH-A', 50, 'trees', 'established', 600, 'TZS_per_nut', 45, 45, 45, 'nuts_per_tree_per_year', '{}'::jsonb),
  ('ORAN-ORCH-D-001', 'tree_crop', 'orange', 'ORCH-D', 60, 'trees', 'established', 500, 'TZS_per_fruit', 400, 475, 550, 'fruits_per_tree_per_year', '{}'::jsonb),
  ('POUL-LVST-P1-001', 'livestock_group', 'poultry_mixed', 'LVST-P1', 112, 'birds', 'mixed', null, 'TZS_per_head', null, null, null, 'count', '{"morogoro_chickens":71,"guineafowl":9,"turkeys":5,"geese":3,"common_ducks":24,"group_market_value":3410000}'::jsonb),
  ('GOAT-LVST-G1-001', 'livestock_group', 'goats_mixed', 'LVST-G1', 45, 'goats', 'mixed', null, 'TZS_per_head', null, null, null, 'count', '{"gala_isoli_goats":15,"common_goats":30,"group_market_value":6300000}'::jsonb),
  ('CATL-LVST-C1-001', 'livestock_group', 'cattle', 'LVST-C1', 2, 'cattle', 'mixed', 1200000, 'TZS_per_head', 2, 2, 2, 'head', '{"group_market_value":2400000}'::jsonb),
  ('RABB-LVST-R1-001', 'livestock_group', 'rabbits', 'LVST-R1', 2, 'rabbits', 'mixed', 25000, 'TZS_per_head', 2, 2, 2, 'head', '{"group_market_value":50000}'::jsonb)
on conflict (id) do update
set asset_type = excluded.asset_type,
    species = excluded.species,
    zone_id = excluded.zone_id,
    quantity = excluded.quantity,
    unit = excluded.unit,
    maturity_stage = excluded.maturity_stage,
    unit_price = excluded.unit_price,
    price_unit = excluded.price_unit,
    production_low = excluded.production_low,
    production_medium = excluded.production_medium,
    production_high = excluded.production_high,
    production_unit = excluded.production_unit,
    metadata = excluded.metadata,
    updated_at = now();

insert into public.asset_valuations (
  asset_id, valuation_date, scenario_low, scenario_medium, scenario_high, currency, notes
)
values
  ('BAN-P12-001', '2025-10-12', 18840000, 23550000, 28260000, 'TZS', '1570 trees x 15000 x 0.8/1.0/1.2 bunches per tree'),
  ('PALM-ORCH-A-001', '2025-10-12', 1800000, 1800000, 1800000, 'TZS', '12 x 10 bunches x 15000'),
  ('APPL-ORCH-E-001', '2025-10-12', 9000000, 22500000, 36000000, 'TZS', 'newly planted, biological potential range'),
  ('SOUR-ORCH-F-001', '2025-10-12', 600000, 900000, 1200000, 'TZS', '10 trees x 12/18/24 fruits x 5000'),
  ('AVOC-ORCH-C-001', '2025-10-12', 1113600, 7795200, 14476800, 'TZS', '58 trees x 12/84/156 kg x 1600'),
  ('MANG-ORCH-B-001', '2025-10-12', 8316000, 14241150, 20166300, 'TZS', '231 trees x 40/68.5/97 fruits x 900'),
  ('PAPA-ORCH-F-001', '2025-10-12', 1040000, 2730000, 5200000, 'TZS', '13 trees x 20000/35000/50000 per harvest x 4/6/8 harvests'),
  ('GUAV-ORCH-C-001', '2025-10-12', 16000000, 22000000, 28000000, 'TZS', '20 trees x 200/275/350 kg x 4000'),
  ('TANG-ORCH-D-001', '2025-10-12', 14000000, 15400000, 16800000, 'TZS', '56 trees x 500/550/600 fruits x 500'),
  ('LEMO-ORCH-D-001', '2025-10-12', 23400000, 23400000, 23400000, 'TZS', '78 trees x 150 kg x 2000'),
  ('COCO-ORCH-A-001', '2025-10-12', 1350000, 1350000, 1350000, 'TZS', '50 trees x 45 nuts x 600'),
  ('ORAN-ORCH-D-001', '2025-10-12', 12000000, 14250000, 16500000, 'TZS', '60 trees x 400/475/550 fruits x 500'),
  ('POUL-LVST-P1-001', '2025-10-12', 3410000, 3410000, 3410000, 'TZS', 'current market value of mixed poultry group'),
  ('GOAT-LVST-G1-001', '2025-10-12', 6300000, 6300000, 6300000, 'TZS', 'current market value of goats'),
  ('CATL-LVST-C1-001', '2025-10-12', 2400000, 2400000, 2400000, 'TZS', 'current market value of cattle'),
  ('RABB-LVST-R1-001', '2025-10-12', 50000, 50000, 50000, 'TZS', 'current market value of rabbits')
on conflict (asset_id, valuation_date) do update
set scenario_low = excluded.scenario_low,
    scenario_medium = excluded.scenario_medium,
    scenario_high = excluded.scenario_high,
    notes = excluded.notes,
    created_at = now();

insert into public.kml_zone_asset_zone_map (kml_zone_id, asset_zone_id, sort_order, notes)
values
  ('zone_a', 'PLT-12-BN', 1, 'Primary banana plot represented in crop KML zone'),
  ('zone_a', 'ORCH-A', 2, 'Orchard cluster linked to crop operations'),
  ('zone_a', 'ORCH-B', 3, 'Orchard cluster linked to crop operations'),
  ('zone_a', 'ORCH-C', 4, 'Orchard cluster linked to crop operations'),
  ('zone_a', 'ORCH-D', 5, 'Orchard cluster linked to crop operations'),
  ('zone_a', 'ORCH-E', 6, 'Orchard cluster linked to crop operations'),
  ('zone_a', 'ORCH-F', 7, 'Orchard cluster linked to crop operations'),
  ('zone_b', 'LVST-P1', 1, 'Poultry operations in livestock KML zone'),
  ('zone_b', 'LVST-G1', 2, 'Goat operations in livestock KML zone'),
  ('zone_b', 'LVST-C1', 3, 'Cattle operations in livestock KML zone'),
  ('zone_b', 'LVST-R1', 4, 'Rabbit operations in livestock KML zone')
on conflict (kml_zone_id, asset_zone_id) do update
set sort_order = excluded.sort_order,
    notes = excluded.notes;

commit;

-- Verification helpers
select * from public.biological_asset_dashboard_summary;
select * from public.biological_asset_category_summary;
select * from public.kml_zone_asset_zone_map order by kml_zone_id, sort_order;
