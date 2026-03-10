-- FarmGenius P0 Backend Verification Script
-- Purpose: Validate high-priority intelligence engine contracts
-- Run after:
--   1) SUPABASE_SETUP.sql
--   2) SUPABASE_ASSET_TRACKING.sql
--   3) SUPABASE_FARM_INTELLIGENCE_ENGINE.sql
--
-- Notes:
-- - This script is mostly read-safe. Optional write tests are wrapped in rollback blocks.
-- - Some checks (auth/RLS role behavior) require running in manager/staff authenticated contexts.

-- ==============================================================
-- 0) Baseline objects exist
-- ==============================================================
select
  'table_exists.question_queue' as check_name,
  to_regclass('public.question_queue') is not null as pass;

select
  'table_exists.recommendations' as check_name,
  to_regclass('public.recommendations') is not null as pass;

select
  'table_exists.intelligence_trigger_templates' as check_name,
  to_regclass('public.intelligence_trigger_templates') is not null as pass;

select
  'table_exists.intelligence_recommendation_categories' as check_name,
  to_regclass('public.intelligence_recommendation_categories') is not null as pass;

-- ==============================================================
-- 1) Core RPC availability and basic execution
-- ==============================================================
select
  'rpc_exists.get_map_overview' as check_name,
  exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'get_map_overview'
  ) as pass;

select
  'rpc_exists.get_zone_command_data' as check_name,
  exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'get_zone_command_data'
  ) as pass;

select
  'rpc_exists.get_trigger_playbook' as check_name,
  exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'get_trigger_playbook'
  ) as pass;

select
  'rpc_exists.get_recommendation_categories' as check_name,
  exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'get_recommendation_categories'
  ) as pass;

-- Should return one row per asset zone; no error means pass for interface contract
select * from public.get_map_overview(now()) limit 10;

-- Should return json payload for an existing seeded trigger key
select
  'rpc_result.get_trigger_playbook_new_asset_added' as check_name,
  public.get_trigger_playbook('new_asset_added') is not null as pass;

-- Should return at least the five seeded categories
select
  'rpc_result.get_recommendation_categories_min5' as check_name,
  (select count(*) from public.get_recommendation_categories()) >= 5 as pass;

-- ==============================================================
-- 2) Seed data integrity
-- ==============================================================
select
  'seed.trigger_templates_min7' as check_name,
  (select count(*) from public.intelligence_trigger_templates where is_active = true) >= 7 as pass;

select
  'seed.category_templates_min5' as check_name,
  (select count(*) from public.intelligence_recommendation_categories where is_active = true) >= 5 as pass;

select
  'seed.category_harvest_optimization_exists' as check_name,
  exists (
    select 1
    from public.intelligence_recommendation_categories
    where category_key = 'harvest_optimization'
  ) as pass;

-- ==============================================================
-- 3) Category constraint validation (write test, rolled back)
-- ==============================================================
begin;

-- Valid category should insert
with candidate_zone as (
  select id as zone_id
  from public.asset_zones
  order by id
  limit 1
)
insert into public.recommendations (
  zone_id,
  category,
  recommendation_text,
  rationale,
  confidence_score,
  expected_impact,
  effort_score,
  status,
  generated_by,
  expires_at
)
select
  cz.zone_id,
  'harvest_optimization',
  'P0 test valid category insert',
  '{"source":"p0_verification"}'::jsonb,
  0.70,
  '{"impact":"test"}'::jsonb,
  2,
  'proposed',
  'p0_verifier',
  now() + interval '1 day'
from candidate_zone cz;

select
  'constraint.valid_category_inserted' as check_name,
  exists (
    select 1 from public.recommendations where recommendation_text = 'P0 test valid category insert'
  ) as pass;

rollback;

-- Invalid category must fail: run manually and expect CHECK VIOLATION
-- begin;
-- with candidate_zone as (
--   select id as zone_id from public.asset_zones order by id limit 1
-- )
-- insert into public.recommendations (
--   zone_id, category, recommendation_text, rationale, confidence_score,
--   expected_impact, effort_score, status, generated_by, expires_at
-- )
-- select
--   cz.zone_id,
--   'invalid_category_key',
--   'P0 invalid category test',
--   '{"source":"p0_verification"}'::jsonb,
--   0.5,
--   '{"impact":"none"}'::jsonb,
--   3,
--   'proposed',
--   'p0_verifier',
--   now() + interval '1 day'
-- from candidate_zone cz;
-- rollback;

-- ==============================================================
-- 4) Recommendation action lifecycle contract (write test, rolled back)
-- ==============================================================
-- Requires authenticated manager/owner context to pass RLS and auth checks.
-- This section is optional for SQL editor without auth context.

-- begin;
--
-- with candidate_zone as (
--   select id as zone_id
--   from public.asset_zones
--   order by id
--   limit 1
-- ), seeded_reco as (
--   insert into public.recommendations (
--     zone_id,
--     category,
--     recommendation_text,
--     rationale,
--     confidence_score,
--     expected_impact,
--     effort_score,
--     status,
--     generated_by,
--     expires_at
--   )
--   select
--     cz.zone_id,
--     'operations',
--     'P0 action lifecycle seed recommendation',
--     '{"source":"p0_verification"}'::jsonb,
--     0.8,
--     '{"impact":"ops"}'::jsonb,
--     2,
--     'proposed',
--     'p0_verifier',
--     now() + interval '1 day'
--   from candidate_zone cz
--   returning id
-- )
-- select public.act_on_recommendation(
--   (select id from seeded_reco),
--   'accept',
--   'P0 accept action',
--   '{}'::jsonb
-- );
--
-- select
--   'lifecycle.accept_updates_status' as check_name,
--   exists (
--     select 1
--     from public.recommendations
--     where recommendation_text = 'P0 action lifecycle seed recommendation'
--       and status = 'accepted'
--   ) as pass;
--
-- rollback;

-- ==============================================================
-- 5) Authorization checks (context-specific)
-- ==============================================================
-- A) Manager/Owner context expected pass:
--    select public.enqueue_zone_questions('<ZONE_ID>', '{}'::jsonb);
--    select public.generate_recommendations('<ZONE_ID>', '{}'::jsonb);
--
-- B) Staff context expected fail with:
--    'Only manager/owner can enqueue questions'
--    'Only manager/owner can generate recommendations'

-- ==============================================================
-- 6) P0 quick summary snapshot
-- ==============================================================
select
  (select count(*) from public.intelligence_trigger_templates where is_active = true) as active_trigger_templates,
  (select count(*) from public.intelligence_recommendation_categories where is_active = true) as active_recommendation_categories,
  (select count(*) from public.get_recommendation_categories()) as rpc_category_count;
