-- FarmGenius Manager-Context QA Script (Executable)
-- Run this while authenticated as a manager/owner user.
-- Purpose: Execute core manager-only flows end-to-end with rollback-safe writes.
--
-- Preconditions:
-- 1) SUPABASE_SETUP.sql applied
-- 2) SUPABASE_ASSET_TRACKING.sql applied
-- 3) SUPABASE_FARM_INTELLIGENCE_ENGINE.sql applied
-- 4) Current session maps to profile role manager/owner

-- ==============================================================
-- A) Quick auth sanity
-- ==============================================================
select
  auth.uid() as current_user_id,
  public.current_user_role() as current_user_role,
  public.is_manager_or_owner() as is_manager_or_owner,
  public.is_system_context() as is_system_context;

-- Expect:
-- - current_user_id is not null
-- - current_user_role in ('manager','owner')
-- - is_manager_or_owner = true
-- - is_system_context = false (for regular manager JWT)

-- ==============================================================
-- B) Read-side contracts
-- ==============================================================
select * from public.get_map_overview(now()) limit 20;

select
  public.get_trigger_playbook('new_asset_added') is not null as trigger_playbook_available;

select * from public.get_recommendation_categories();

-- ==============================================================
-- C) Manager-only enqueue/generate checks (EXECUTABLE)
-- ==============================================================
-- Uses first available zone id; if no zones exist this section will fail by design.

with z as (
  select id as zone_id
  from public.asset_zones
  order by id
  limit 1
)
select
  (select zone_id from z) as target_zone,
  public.enqueue_zone_questions((select zone_id from z), '{"source":"manager_context_qa"}'::jsonb) as inserted_questions,
  public.generate_recommendations((select zone_id from z), '{"source":"manager_context_qa"}'::jsonb) as inserted_recommendations;

-- ==============================================================
-- D) Recommendation action lifecycle (rollback-safe)
-- ==============================================================
begin;

with candidate_zone as (
  select id as zone_id
  from public.asset_zones
  order by id
  limit 1
), seed_reco as (
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
    'operations',
    'MANAGER_QA_LIFECYCLE_TEST',
    '{"source":"manager_context_qa"}'::jsonb,
    0.82,
    '{"impact":"ops"}'::jsonb,
    2,
    'proposed',
    'manager_context_qa',
    now() + interval '1 day'
  from candidate_zone cz
  returning id
)
select (select id from seed_reco) as seeded_recommendation_id;

select
  case
    when auth.uid() is null then 'SKIPPED_NO_AUTH_CONTEXT'
    else 'EXECUTING_IN_AUTH_CONTEXT'
  end as lifecycle_execution_mode;

-- accept
do $$
declare
  v_target uuid;
begin
  if auth.uid() is null then
    raise notice 'Skipping accept action: no authenticated user context in SQL editor.';
    return;
  end if;

  select id into v_target
  from public.recommendations
  where recommendation_text = 'MANAGER_QA_LIFECYCLE_TEST'
  order by generated_at desc
  limit 1;

  perform public.act_on_recommendation(v_target, 'accept', 'accept via QA', '{}'::jsonb);
end
$$;

select
  'accept_status' as check_name,
  case when auth.uid() is null then 'SKIPPED_NO_AUTH_CONTEXT' else status end as status,
  case when auth.uid() is null then null else (status = 'accepted') end as pass
from public.recommendations
where recommendation_text = 'MANAGER_QA_LIFECYCLE_TEST'
order by generated_at desc
limit 1;

-- modify
do $$
declare
  v_target uuid;
begin
  if auth.uid() is null then
    raise notice 'Skipping modify action: no authenticated user context in SQL editor.';
    return;
  end if;

  select id into v_target
  from public.recommendations
  where recommendation_text = 'MANAGER_QA_LIFECYCLE_TEST'
  order by generated_at desc
  limit 1;

  perform public.act_on_recommendation(
    v_target,
    'modify',
    'modify via QA',
    '{"adjustment":"test"}'::jsonb
  );
end
$$;

select
  'modify_status' as check_name,
  case when auth.uid() is null then 'SKIPPED_NO_AUTH_CONTEXT' else status end as status,
  case when auth.uid() is null then null else (status = 'modified') end as pass
from public.recommendations
where recommendation_text = 'MANAGER_QA_LIFECYCLE_TEST'
order by generated_at desc
limit 1;

-- defer
do $$
declare
  v_target uuid;
begin
  if auth.uid() is null then
    raise notice 'Skipping defer action: no authenticated user context in SQL editor.';
    return;
  end if;

  select id into v_target
  from public.recommendations
  where recommendation_text = 'MANAGER_QA_LIFECYCLE_TEST'
  order by generated_at desc
  limit 1;

  perform public.act_on_recommendation(v_target, 'defer', 'defer via QA', '{}'::jsonb);
end
$$;

select
  'defer_status' as check_name,
  case when auth.uid() is null then 'SKIPPED_NO_AUTH_CONTEXT' else status end as status,
  case when auth.uid() is null then null else (status = 'deferred') end as pass
from public.recommendations
where recommendation_text = 'MANAGER_QA_LIFECYCLE_TEST'
order by generated_at desc
limit 1;

-- reject
do $$
declare
  v_target uuid;
begin
  if auth.uid() is null then
    raise notice 'Skipping reject action: no authenticated user context in SQL editor.';
    return;
  end if;

  select id into v_target
  from public.recommendations
  where recommendation_text = 'MANAGER_QA_LIFECYCLE_TEST'
  order by generated_at desc
  limit 1;

  perform public.act_on_recommendation(v_target, 'reject', 'reject via QA', '{}'::jsonb);
end
$$;

select
  'reject_status' as check_name,
  case when auth.uid() is null then 'SKIPPED_NO_AUTH_CONTEXT' else status end as status,
  case when auth.uid() is null then null else (status = 'rejected') end as pass
from public.recommendations
where recommendation_text = 'MANAGER_QA_LIFECYCLE_TEST'
order by generated_at desc
limit 1;

-- execute
do $$
declare
  v_target uuid;
begin
  if auth.uid() is null then
    raise notice 'Skipping execute action: no authenticated user context in SQL editor.';
    return;
  end if;

  select id into v_target
  from public.recommendations
  where recommendation_text = 'MANAGER_QA_LIFECYCLE_TEST'
  order by generated_at desc
  limit 1;

  perform public.act_on_recommendation(v_target, 'execute', 'execute via QA', '{}'::jsonb);
end
$$;

select
  'execute_status' as check_name,
  case when auth.uid() is null then 'SKIPPED_NO_AUTH_CONTEXT' else status end as status,
  case when auth.uid() is null then null else (status = 'executed') end as pass
from public.recommendations
where recommendation_text = 'MANAGER_QA_LIFECYCLE_TEST'
order by generated_at desc
limit 1;

-- action trail count for this recommendation
with target as (
  select id
  from public.recommendations
  where recommendation_text = 'MANAGER_QA_LIFECYCLE_TEST'
  order by generated_at desc
  limit 1
)
select
  'action_trail_min5' as check_name,
  count(*) as action_count,
  case when auth.uid() is null then null else (count(*) >= 5) end as pass
from public.recommendation_actions ra
where ra.recommendation_id = (select id from target);

rollback;

-- ==============================================================
-- E) Invalid action validation (should ERROR)
-- ==============================================================
-- Run this manually to validate defensive behavior:
-- with target as (
--   select id from public.recommendations order by generated_at desc limit 1
-- )
-- select public.act_on_recommendation((select id from target), 'invalid_action', 'negative test', '{}'::jsonb);

-- ==============================================================
-- F) Final manager-context summary
-- ==============================================================
select
  (select count(*) from public.question_queue where created_by_engine = true) as engine_questions_total,
  (select count(*) from public.recommendations where generated_by in ('engine','rule_engine','manager_context_qa')) as recommendations_total,
  (select count(*) from public.get_recommendation_categories()) as active_category_count;
