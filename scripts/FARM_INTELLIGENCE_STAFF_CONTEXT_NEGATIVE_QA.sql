-- FarmGenius Staff-Context Negative QA Script (Executable)
-- Run this while authenticated as a STAFF user.
-- Purpose: Validate expected authorization failures and RLS boundaries.
--
-- Preconditions:
-- 1) SUPABASE_SETUP.sql applied
-- 2) SUPABASE_ASSET_TRACKING.sql applied
-- 3) SUPABASE_FARM_INTELLIGENCE_ENGINE.sql applied
-- 4) Current session maps to profile role staff

-- ==============================================================
-- A) Staff auth sanity
-- ==============================================================
select
  auth.uid() as current_user_id,
  public.current_user_role() as current_user_role,
  public.is_manager_or_owner() as is_manager_or_owner,
  public.is_system_context() as is_system_context;

-- Expected:
-- - current_user_id is not null
-- - current_user_role = 'staff'
-- - is_manager_or_owner = false
-- - is_system_context = false

-- ==============================================================
-- B) Read-side allowed checks
-- ==============================================================
-- Staff should be able to read general catalog/playbook data and map overview.
select * from public.get_map_overview(now()) limit 20;
select public.get_trigger_playbook('new_asset_added') as trigger_playbook;
select * from public.get_recommendation_categories();

-- ==============================================================
-- C) Manager-only RPC negative checks (EXPECTED FAILURES)
-- ==============================================================
-- Run each statement separately and verify exact failure intent.
-- Expected error message: Only manager/owner can enqueue questions

-- with z as (
--   select id as zone_id
--   from public.asset_zones
--   order by id
--   limit 1
-- )
-- select public.enqueue_zone_questions((select zone_id from z), '{"source":"staff_negative_qa"}'::jsonb);

-- Expected error message: Only manager/owner can generate recommendations

-- with z as (
--   select id as zone_id
--   from public.asset_zones
--   order by id
--   limit 1
-- )
-- select public.generate_recommendations((select zone_id from z), '{"source":"staff_negative_qa"}'::jsonb);

-- ==============================================================
-- D) RLS negative write checks (EXPECTED FAILURES)
-- ==============================================================
-- 1) Staff should not be able to insert into recommendations directly.
-- Expected: RLS/policy violation.

-- begin;
-- with z as (
--   select id as zone_id from public.asset_zones order by id limit 1
-- )
-- insert into public.recommendations (
--   zone_id,
--   category,
--   recommendation_text,
--   rationale,
--   confidence_score,
--   expected_impact,
--   effort_score,
--   status,
--   generated_by,
--   expires_at
-- )
-- select
--   (select zone_id from z),
--   'operations',
--   'STAFF_NEGATIVE_QA_DIRECT_WRITE',
--   '{"source":"staff_negative_qa"}'::jsonb,
--   0.5,
--   '{"impact":"none"}'::jsonb,
--   3,
--   'proposed',
--   'staff_negative_qa',
--   now() + interval '1 day';
-- rollback;

-- 2) Staff should not be able to write template catalogs.
-- Expected: RLS/policy violation.

-- begin;
-- insert into public.intelligence_trigger_templates (
--   trigger_key,
--   question,
--   priority,
--   metadata
-- ) values (
--   'staff_negative_test_key',
--   'Should fail for staff user',
--   10,
--   '{"source":"staff_negative_qa"}'::jsonb
-- );
-- rollback;

-- ==============================================================
-- E) Allowed staff response flow (positive control)
-- ==============================================================
-- Staff should be able to submit a response only when question is assigned/eligible by policy.
-- Use a real assigned question ID for this staff user.

-- select *
-- from public.question_queue
-- where assigned_to = auth.uid()
--   and status in ('queued','asked','escalated')
-- order by created_at desc
-- limit 5;

-- Example (replace UUID before running):
-- select public.submit_question_response(
--   '00000000-0000-0000-0000-000000000000'::uuid,
--   'text',
--   '{"answer":"checked and completed"}'::jsonb,
--   0.8
-- );

-- ==============================================================
-- F) Final staff-context summary
-- ==============================================================
select
  public.current_user_role() as role_check,
  (select count(*) from public.get_recommendation_categories()) as visible_category_count,
  (select count(*) from public.intelligence_trigger_templates where is_active = true) as visible_trigger_template_count;
