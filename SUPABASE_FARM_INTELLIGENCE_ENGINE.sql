-- FarmGenius Interactive Farm Intelligence Engine
-- Apply after SUPABASE_SETUP.sql and SUPABASE_ASSET_TRACKING.sql

begin;

create extension if not exists pgcrypto;

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

create or replace function public.is_system_context()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    auth.uid() is null
    or coalesce(current_setting('request.jwt.claim.role', true), '') in ('service_role', 'supabase_admin');
$$;

revoke all on function public.is_system_context() from public;
grant execute on function public.is_system_context() to authenticated;

-- ------------------------------------------------------------------
-- Intelligence engine tables
-- ------------------------------------------------------------------
create table if not exists public.question_queue (
  id uuid primary key default gen_random_uuid(),
  zone_id text,
  asset_id text references public.biological_assets(id) on delete set null,
  question_text text not null,
  question_type text not null,
  priority int not null default 50 check (priority between 1 and 100),
  status text not null default 'queued' check (status in ('queued', 'asked', 'answered', 'skipped', 'escalated', 'expired')),
  context jsonb not null default '{}'::jsonb,
  due_at timestamptz,
  asked_at timestamptz,
  assigned_to uuid references auth.users(id) on delete set null,
  created_by_engine boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.question_responses (
  id uuid primary key default gen_random_uuid(),
  question_id uuid not null references public.question_queue(id) on delete cascade,
  responder_id uuid not null references auth.users(id) on delete cascade,
  response_type text not null check (response_type in ('yes_no', 'numeric', 'text', 'choice', 'multi_choice', 'media')),
  response_value jsonb not null default '{}'::jsonb,
  confidence numeric not null default 0.7 check (confidence between 0 and 1),
  responded_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create table if not exists public.recommendations (
  id uuid primary key default gen_random_uuid(),
  zone_id text,
  asset_id text references public.biological_assets(id) on delete set null,
  category text not null check (category in ('operations', 'crop', 'livestock', 'infrastructure', 'financial', 'safety', 'biosecurity')),
  recommendation_text text not null,
  rationale jsonb not null default '{}'::jsonb,
  confidence_score numeric not null default 0.5 check (confidence_score between 0 and 1),
  expected_impact jsonb not null default '{}'::jsonb,
  effort_score int not null default 3 check (effort_score between 1 and 5),
  status text not null default 'proposed' check (status in ('proposed', 'accepted', 'modified', 'rejected', 'deferred', 'executed', 'expired')),
  generated_by text not null default 'engine',
  generated_at timestamptz not null default now(),
  expires_at timestamptz
);

create table if not exists public.recommendation_actions (
  id uuid primary key default gen_random_uuid(),
  recommendation_id uuid not null references public.recommendations(id) on delete cascade,
  actor_id uuid references auth.users(id) on delete set null,
  action_type text not null check (action_type in ('accept', 'modify', 'reject', 'defer', 'execute')),
  action_notes text,
  modified_payload jsonb not null default '{}'::jsonb,
  acted_at timestamptz not null default now()
);

create table if not exists public.recommendation_outcomes (
  id uuid primary key default gen_random_uuid(),
  recommendation_id uuid not null references public.recommendations(id) on delete cascade,
  window_days int not null check (window_days in (1, 7, 30, 90)),
  outcome_metrics jsonb not null default '{}'::jsonb,
  outcome_score numeric not null default 0 check (outcome_score between -1 and 1),
  measured_at timestamptz not null default now()
);

create table if not exists public.zone_risk_snapshots (
  id bigint generated always as identity primary key,
  zone_id text not null,
  risk_total numeric not null default 0 check (risk_total between 0 and 100),
  disease_risk numeric not null default 0 check (disease_risk between 0 and 100),
  theft_risk numeric not null default 0 check (theft_risk between 0 and 100),
  water_risk numeric not null default 0 check (water_risk between 0 and 100),
  execution_risk numeric not null default 0 check (execution_risk between 0 and 100),
  valuation_risk numeric not null default 0 check (valuation_risk between 0 and 100),
  factors jsonb not null default '{}'::jsonb,
  created_by text not null default 'engine',
  captured_at timestamptz not null default now()
);

create table if not exists public.infrastructure_assets (
  id uuid primary key default gen_random_uuid(),
  asset_kind text not null check (asset_kind in ('fence_segment', 'gate', 'water_point', 'storage', 'road_access', 'utility')),
  zone_id text,
  name text not null,
  status text not null default 'planned' check (status in ('planned', 'in_progress', 'active', 'blocked', 'retired')),
  geometry_geojson jsonb not null default '{}'::jsonb,
  metadata jsonb not null default '{}'::jsonb,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.intelligence_trigger_templates (
  trigger_key text primary key,
  question text not null,
  follow_ups jsonb not null default '[]'::jsonb,
  options jsonb not null default '[]'::jsonb,
  recommendations jsonb not null default '[]'::jsonb,
  actions jsonb not null default '[]'::jsonb,
  priority int not null default 50 check (priority between 1 and 100),
  is_active boolean not null default true,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.intelligence_recommendation_categories (
  category_key text primary key,
  logic text not null,
  example text not null,
  is_active boolean not null default true,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.recommendations
drop constraint if exists recommendations_category_check;

alter table public.recommendations
add constraint recommendations_category_check
check (
  category in (
    'operations',
    'crop',
    'livestock',
    'infrastructure',
    'financial',
    'safety',
    'biosecurity',
    'harvest_optimization',
    'resource_allocation',
    'predator_prevention',
    'input_efficiency',
    'maintenance_prediction'
  )
);

-- ------------------------------------------------------------------
-- Indexes
-- ------------------------------------------------------------------
create index if not exists question_queue_zone_idx on public.question_queue(zone_id, status, priority desc);
create index if not exists question_queue_due_idx on public.question_queue(due_at);
create index if not exists question_responses_question_idx on public.question_responses(question_id);
create index if not exists recommendations_zone_status_idx on public.recommendations(zone_id, status, generated_at desc);
create index if not exists recommendations_expires_idx on public.recommendations(expires_at);
create index if not exists recommendation_actions_reco_idx on public.recommendation_actions(recommendation_id, acted_at desc);
create index if not exists recommendation_outcomes_reco_idx on public.recommendation_outcomes(recommendation_id, window_days);
create index if not exists zone_risk_snapshots_zone_time_idx on public.zone_risk_snapshots(zone_id, captured_at desc);
create index if not exists infrastructure_assets_kind_status_idx on public.infrastructure_assets(asset_kind, status);
create index if not exists intelligence_trigger_templates_active_idx on public.intelligence_trigger_templates(is_active, priority desc);
create index if not exists intelligence_recommendation_categories_active_idx on public.intelligence_recommendation_categories(is_active, category_key);

-- ------------------------------------------------------------------
-- RLS
-- ------------------------------------------------------------------
alter table public.question_queue enable row level security;
alter table public.question_responses enable row level security;
alter table public.recommendations enable row level security;
alter table public.recommendation_actions enable row level security;
alter table public.recommendation_outcomes enable row level security;
alter table public.zone_risk_snapshots enable row level security;
alter table public.infrastructure_assets enable row level security;
alter table public.intelligence_trigger_templates enable row level security;
alter table public.intelligence_recommendation_categories enable row level security;

-- question_queue

drop policy if exists "question_queue_select_auth" on public.question_queue;
create policy "question_queue_select_auth"
on public.question_queue
for select
using (
  auth.uid() is not null and (
    public.is_manager_or_owner()
    or assigned_to = auth.uid()
  )
);

drop policy if exists "question_queue_write_manager_owner" on public.question_queue;
create policy "question_queue_write_manager_owner"
on public.question_queue
for all
using (public.is_manager_or_owner())
with check (public.is_manager_or_owner());

-- question_responses

drop policy if exists "question_responses_select_auth" on public.question_responses;
create policy "question_responses_select_auth"
on public.question_responses
for select
using (
  auth.uid() is not null and (
    public.is_manager_or_owner()
    or responder_id = auth.uid()
  )
);

drop policy if exists "question_responses_insert_own_or_manager" on public.question_responses;
create policy "question_responses_insert_own_or_manager"
on public.question_responses
for insert
with check (responder_id = auth.uid() or public.is_manager_or_owner());

-- recommendations

drop policy if exists "recommendations_select_auth" on public.recommendations;
create policy "recommendations_select_auth"
on public.recommendations
for select
using (auth.uid() is not null);

drop policy if exists "recommendations_write_manager_owner" on public.recommendations;
create policy "recommendations_write_manager_owner"
on public.recommendations
for all
using (public.is_manager_or_owner())
with check (public.is_manager_or_owner());

-- recommendation_actions

drop policy if exists "recommendation_actions_select_auth" on public.recommendation_actions;
create policy "recommendation_actions_select_auth"
on public.recommendation_actions
for select
using (auth.uid() is not null);

drop policy if exists "recommendation_actions_insert_auth" on public.recommendation_actions;
create policy "recommendation_actions_insert_auth"
on public.recommendation_actions
for insert
with check (actor_id = auth.uid() or public.is_manager_or_owner());

drop policy if exists "recommendation_actions_update_manager_owner" on public.recommendation_actions;
create policy "recommendation_actions_update_manager_owner"
on public.recommendation_actions
for update
using (public.is_manager_or_owner())
with check (public.is_manager_or_owner());

-- recommendation_outcomes

drop policy if exists "recommendation_outcomes_select_auth" on public.recommendation_outcomes;
create policy "recommendation_outcomes_select_auth"
on public.recommendation_outcomes
for select
using (auth.uid() is not null);

drop policy if exists "recommendation_outcomes_write_manager_owner" on public.recommendation_outcomes;
create policy "recommendation_outcomes_write_manager_owner"
on public.recommendation_outcomes
for all
using (public.is_manager_or_owner())
with check (public.is_manager_or_owner());

-- zone_risk_snapshots

drop policy if exists "zone_risk_snapshots_select_auth" on public.zone_risk_snapshots;
create policy "zone_risk_snapshots_select_auth"
on public.zone_risk_snapshots
for select
using (auth.uid() is not null);

drop policy if exists "zone_risk_snapshots_write_manager_owner" on public.zone_risk_snapshots;
create policy "zone_risk_snapshots_write_manager_owner"
on public.zone_risk_snapshots
for all
using (public.is_manager_or_owner())
with check (public.is_manager_or_owner());

-- infrastructure_assets

drop policy if exists "infrastructure_assets_select_auth" on public.infrastructure_assets;
create policy "infrastructure_assets_select_auth"
on public.infrastructure_assets
for select
using (auth.uid() is not null);

drop policy if exists "infrastructure_assets_write_manager_owner" on public.infrastructure_assets;
create policy "infrastructure_assets_write_manager_owner"
on public.infrastructure_assets
for all
using (public.is_manager_or_owner())
with check (public.is_manager_or_owner());

-- intelligence_trigger_templates

drop policy if exists "intelligence_trigger_templates_select_auth" on public.intelligence_trigger_templates;
create policy "intelligence_trigger_templates_select_auth"
on public.intelligence_trigger_templates
for select
using (auth.uid() is not null);

drop policy if exists "intelligence_trigger_templates_write_manager_owner" on public.intelligence_trigger_templates;
create policy "intelligence_trigger_templates_write_manager_owner"
on public.intelligence_trigger_templates
for all
using (public.is_manager_or_owner())
with check (public.is_manager_or_owner());

-- intelligence_recommendation_categories

drop policy if exists "intelligence_recommendation_categories_select_auth" on public.intelligence_recommendation_categories;
create policy "intelligence_recommendation_categories_select_auth"
on public.intelligence_recommendation_categories
for select
using (auth.uid() is not null);

drop policy if exists "intelligence_recommendation_categories_write_manager_owner" on public.intelligence_recommendation_categories;
create policy "intelligence_recommendation_categories_write_manager_owner"
on public.intelligence_recommendation_categories
for all
using (public.is_manager_or_owner())
with check (public.is_manager_or_owner());

-- ------------------------------------------------------------------
-- RPC and helper functions
-- ------------------------------------------------------------------
create or replace function public.get_zone_command_data(p_zone_id text, p_now timestamptz default now())
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_open_recommendations int := 0;
  v_pending_questions int := 0;
  v_last_check date;
  v_latest_risk numeric := 0;
  v_medium_value numeric := 0;
begin
  select count(*) into v_open_recommendations
  from public.recommendations r
  where r.zone_id = p_zone_id
    and r.status in ('proposed', 'accepted', 'modified', 'deferred')
    and (r.expires_at is null or r.expires_at >= p_now);

  select count(*) into v_pending_questions
  from public.question_queue q
  where q.zone_id = p_zone_id
    and q.status in ('queued', 'asked', 'escalated');

  select max(c.check_date) into v_last_check
  from public.daily_asset_checks c
  where c.zone_id = p_zone_id;

  select coalesce(z.risk_total, 0) into v_latest_risk
  from public.zone_risk_snapshots z
  where z.zone_id = p_zone_id
  order by z.captured_at desc
  limit 1;

  select coalesce(sum(v.scenario_medium), 0) into v_medium_value
  from public.biological_asset_latest_values v
  where v.zone_id = p_zone_id;

  return jsonb_build_object(
    'zone_id', p_zone_id,
    'open_recommendations', v_open_recommendations,
    'pending_questions', v_pending_questions,
    'last_check_date', v_last_check,
    'latest_risk', v_latest_risk,
    'medium_value', v_medium_value
  );
end;
$$;

grant execute on function public.get_zone_command_data(text, timestamptz) to authenticated;

create or replace function public.get_map_overview(p_now timestamptz default now())
returns table (
  zone_id text,
  open_recommendations int,
  pending_questions int,
  latest_risk numeric,
  last_check_date date,
  medium_value numeric
)
language sql
stable
security definer
set search_path = public
as $$
with rec as (
  select r.zone_id, count(*)::int as open_recommendations
  from public.recommendations r
  where r.status in ('proposed', 'accepted', 'modified', 'deferred')
    and (r.expires_at is null or r.expires_at >= p_now)
  group by r.zone_id
), q as (
  select qq.zone_id, count(*)::int as pending_questions
  from public.question_queue qq
  where qq.status in ('queued', 'asked', 'escalated')
  group by qq.zone_id
), risk as (
  select distinct on (z.zone_id) z.zone_id, z.risk_total as latest_risk
  from public.zone_risk_snapshots z
  order by z.zone_id, z.captured_at desc
), checks as (
  select c.zone_id, max(c.check_date) as last_check_date
  from public.daily_asset_checks c
  group by c.zone_id
), val as (
  select v.zone_id, coalesce(sum(v.scenario_medium), 0) as medium_value
  from public.biological_asset_latest_values v
  group by v.zone_id
)
select
  az.id as zone_id,
  coalesce(rec.open_recommendations, 0) as open_recommendations,
  coalesce(q.pending_questions, 0) as pending_questions,
  coalesce(risk.latest_risk, 0) as latest_risk,
  checks.last_check_date,
  coalesce(val.medium_value, 0) as medium_value
from public.asset_zones az
left join rec on rec.zone_id = az.id
left join q on q.zone_id = az.id
left join risk on risk.zone_id = az.id
left join checks on checks.zone_id = az.id
left join val on val.zone_id = az.id
order by az.id;
$$;

grant execute on function public.get_map_overview(timestamptz) to authenticated;

create or replace function public.enqueue_zone_questions(p_zone_id text, p_context jsonb default '{}'::jsonb)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_last_check date;
  v_inserted int := 0;
begin
  if not (public.is_system_context() or public.is_manager_or_owner()) then
    raise exception 'Only manager/owner can enqueue questions';
  end if;

  select max(c.check_date) into v_last_check
  from public.daily_asset_checks c
  where c.zone_id = p_zone_id;

  if (
    v_last_check is null
    or v_last_check < current_date - interval '1 day'
  ) and not exists (
    select 1
    from public.question_queue q
    where q.zone_id = p_zone_id
      and q.question_type = 'check_compliance'
      and q.status in ('queued', 'asked', 'escalated')
      and q.created_by_engine = true
  ) then
    insert into public.question_queue (
      zone_id,
      question_text,
      question_type,
      priority,
      status,
      context,
      due_at,
      created_by_engine
    ) values (
      p_zone_id,
      'No zone check was logged in the last 24 hours. Should I prompt the team to submit one now?',
      'check_compliance',
      90,
      'queued',
      jsonb_build_object('source', 'enqueue_zone_questions', 'context', p_context),
      now() + interval '2 hours',
      true
    );
    v_inserted := v_inserted + 1;
  end if;

  if not exists (
    select 1
    from public.infrastructure_assets ia
    where ia.zone_id = p_zone_id
      and ia.asset_kind = 'water_point'
      and ia.status in ('in_progress', 'active')
  ) and not exists (
    select 1
    from public.question_queue q
    where q.zone_id = p_zone_id
      and q.question_type = 'resource_gap'
      and q.status in ('queued', 'asked', 'escalated')
      and q.created_by_engine = true
  ) then
    insert into public.question_queue (
      zone_id,
      question_text,
      question_type,
      priority,
      status,
      context,
      due_at,
      created_by_engine
    ) values (
      p_zone_id,
      'No active water point is mapped for this zone. Should I create a high-priority verification task now?',
      'resource_gap',
      80,
      'queued',
      jsonb_build_object('source', 'enqueue_zone_questions', 'context', p_context),
      now() + interval '6 hours',
      true
    );
    v_inserted := v_inserted + 1;
  end if;

  return v_inserted;
end;
$$;

grant execute on function public.enqueue_zone_questions(text, jsonb) to authenticated;

create or replace function public.generate_recommendations(p_zone_id text, p_context jsonb default '{}'::jsonb)
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_last_check date;
  v_value numeric := 0;
  v_inserted int := 0;
begin
  if not (public.is_system_context() or public.is_manager_or_owner()) then
    raise exception 'Only manager/owner can generate recommendations';
  end if;

  select max(c.check_date) into v_last_check
  from public.daily_asset_checks c
  where c.zone_id = p_zone_id;

  select coalesce(sum(v.scenario_medium), 0) into v_value
  from public.biological_asset_latest_values v
  where v.zone_id = p_zone_id;

  if (
    v_last_check is null
    or v_last_check < current_date - interval '1 day'
  ) and not exists (
    select 1
    from public.recommendations r
    where r.zone_id = p_zone_id
      and r.category = 'operations'
      and r.status in ('proposed', 'accepted', 'modified', 'deferred')
      and r.generated_by = 'rule_engine'
      and coalesce(r.rationale->>'reason', '') = 'check_gap'
      and (r.expires_at is null or r.expires_at >= now())
  ) then
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
    ) values (
      p_zone_id,
      'operations',
      'Trigger a daily check in this zone before next critical time block.',
      jsonb_build_object('reason', 'check_gap', 'last_check', v_last_check, 'context', p_context),
      0.86,
      jsonb_build_object('impact', 'higher execution reliability', 'window', '24h'),
      2,
      'proposed',
      'rule_engine',
      now() + interval '1 day'
    );
    v_inserted := v_inserted + 1;
  end if;

  if v_value >= 10000000 and not exists (
    select 1
    from public.recommendations r
    where r.zone_id = p_zone_id
      and r.category = 'financial'
      and r.status in ('proposed', 'accepted', 'modified', 'deferred')
      and r.generated_by = 'rule_engine'
      and coalesce(r.rationale->>'reason', '') = 'high_value_zone'
      and (r.expires_at is null or r.expires_at >= now())
  ) then
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
    ) values (
      p_zone_id,
      'financial',
      'Prioritize protection and evidence logging for this high-value zone.',
      jsonb_build_object('reason', 'high_value_zone', 'medium_value', v_value, 'context', p_context),
      0.78,
      jsonb_build_object('impact', 'reduced value-at-risk', 'window', '7d'),
      3,
      'proposed',
      'rule_engine',
      now() + interval '3 days'
    );
    v_inserted := v_inserted + 1;
  end if;

  return v_inserted;
end;
$$;

grant execute on function public.generate_recommendations(text, jsonb) to authenticated;

create or replace function public.submit_question_response(
  p_question_id uuid,
  p_response_type text,
  p_response_value jsonb,
  p_confidence numeric default 0.7
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_response_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  insert into public.question_responses (
    question_id,
    responder_id,
    response_type,
    response_value,
    confidence
  ) values (
    p_question_id,
    auth.uid(),
    p_response_type,
    p_response_value,
    greatest(0, least(1, p_confidence))
  )
  returning id into v_response_id;

  update public.question_queue
  set status = 'answered'
  where id = p_question_id;

  return v_response_id;
end;
$$;

grant execute on function public.submit_question_response(uuid, text, jsonb, numeric) to authenticated;

create or replace function public.act_on_recommendation(
  p_recommendation_id uuid,
  p_action text,
  p_notes text default null,
  p_modified_payload jsonb default '{}'::jsonb
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_next_status text;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  v_next_status := case p_action
    when 'accept' then 'accepted'
    when 'modify' then 'modified'
    when 'reject' then 'rejected'
    when 'defer' then 'deferred'
    when 'execute' then 'executed'
    else null
  end;

  if v_next_status is null then
    raise exception 'Invalid action: %', p_action;
  end if;

  insert into public.recommendation_actions (
    recommendation_id,
    actor_id,
    action_type,
    action_notes,
    modified_payload
  ) values (
    p_recommendation_id,
    auth.uid(),
    p_action,
    p_notes,
    coalesce(p_modified_payload, '{}'::jsonb)
  );

  update public.recommendations
  set status = v_next_status
  where id = p_recommendation_id;
end;
$$;

grant execute on function public.act_on_recommendation(uuid, text, text, jsonb) to authenticated;

create or replace function public.get_trigger_playbook(p_trigger_key text)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'trigger', t.trigger_key,
    'question', t.question,
    'follow_ups', t.follow_ups,
    'options', t.options,
    'recommendations', t.recommendations,
    'actions', t.actions,
    'priority', t.priority,
    'metadata', t.metadata
  )
  from public.intelligence_trigger_templates t
  where t.trigger_key = p_trigger_key
    and t.is_active = true;
$$;

grant execute on function public.get_trigger_playbook(text) to authenticated;

create or replace function public.get_recommendation_categories()
returns table (
  category_key text,
  logic text,
  example text,
  metadata jsonb
)
language sql
stable
security definer
set search_path = public
as $$
  select
    c.category_key,
    c.logic,
    c.example,
    c.metadata
  from public.intelligence_recommendation_categories c
  where c.is_active = true
  order by c.category_key;
$$;

grant execute on function public.get_recommendation_categories() to authenticated;

insert into public.intelligence_trigger_templates (
  trigger_key,
  question,
  follow_ups,
  options,
  recommendations,
  actions,
  priority,
  metadata
) values
(
  'new_asset_added',
  'Great update—18 apple trees were added. Let’s finish setup so tracking starts today:',
  jsonb_build_array(
    'What''s the exact planting date?',
    'Which zone are they in? (click on map)',
    'What variety?',
    'Would you like me to create a growth tracking schedule for them?'
  ),
  '[]'::jsonb,
  '[]'::jsonb,
  '[]'::jsonb,
  85,
  jsonb_build_object('source', 'seed_defaults', 'type', 'asset_tracking')
),
(
  'no_egg_record_24h',
  'No egg collection was logged yesterday for poultry. How should I handle it now?',
  '[]'::jsonb,
  jsonb_build_array(
    'Remind the morning team now',
    'Mark as holiday (no collection)',
    'Adjust expected production targets'
  ),
  '[]'::jsonb,
  '[]'::jsonb,
  88,
  jsonb_build_object('source', 'seed_defaults', 'type', 'poultry_operations')
),
(
  'weather_forecast_heavy_rain',
  'Heavy rain is forecast for Thursday. Want me to prepare your zones now?',
  '[]'::jsonb,
  '[]'::jsonb,
  jsonb_build_array(
    'Schedule banana harvest for Wednesday instead',
    'Check drainage in Plot 12',
    'Secure poultry housing against moisture',
    'Delay any spraying activities'
  ),
  '[]'::jsonb,
  90,
  jsonb_build_object('source', 'seed_defaults', 'type', 'weather_risk')
),
(
  'market_price_spike_mangoes',
  'Regional mango prices are up 25% this week, and your mango zone has 231 trees at 60-70% maturity. Next move?',
  '[]'::jsonb,
  '[]'::jsonb,
  jsonb_build_array(
    'Consider early harvest for premium pricing?',
    'Book transport for next 3 days',
    'Alert sales team to prioritize mango buyers'
  ),
  '[]'::jsonb,
  82,
  jsonb_build_object('source', 'seed_defaults', 'type', 'market_intelligence')
),
(
  'low_water_pressure_detected',
  'Water pressure is dropping in Plot 12 and could stress 1,570 banana trees. Which action should I trigger first?',
  '[]'::jsonb,
  '[]'::jsonb,
  '[]'::jsonb,
  jsonb_build_array(
    'Check pump station now',
    'Switch to backup system',
    'Reduce irrigation duration until fixed'
  ),
  92,
  jsonb_build_object('source', 'seed_defaults', 'type', 'infrastructure_alert')
),
(
  'livestock_count_mismatch',
  'Evening count is 28 goats versus 30 in the morning. Two are unaccounted for—what should I run first?',
  '[]'::jsonb,
  '[]'::jsonb,
  '[]'::jsonb,
  jsonb_build_array(
    'Check fence line section B3 (recent weak spot)',
    'Search grazing zone immediately',
    'Review gate log for last 12 hours'
  ),
  95,
  jsonb_build_object('source', 'seed_defaults', 'type', 'livestock_security')
),
(
  'seasonal_pattern_avocado',
  'Your 58 avocado trees are entering peak flowering season. Should I schedule the next steps now?',
  '[]'::jsonb,
  '[]'::jsonb,
  jsonb_build_array(
    'Schedule pollination support (bees)',
    'Increase calcium foliar spray',
    'Prepare harvest team for 4-6 months ahead'
  ),
  '[]'::jsonb,
  76,
  jsonb_build_object('source', 'seed_defaults', 'type', 'seasonal_pattern')
)
on conflict (trigger_key) do update
set question = excluded.question,
    follow_ups = excluded.follow_ups,
    options = excluded.options,
    recommendations = excluded.recommendations,
    actions = excluded.actions,
    priority = excluded.priority,
    metadata = excluded.metadata,
    updated_at = now();

insert into public.intelligence_recommendation_categories (
  category_key,
  logic,
  example,
  metadata
) values
(
  'harvest_optimization',
  'compare_ripeness_vs_market_price_vs_weather',
  'Your papayas (13 trees) are at 80% maturity and prices are strong. Recommend harvesting 50% today, 50% in 4 days to extend market presence.',
  jsonb_build_object('source', 'seed_defaults', 'domain', 'market_harvest')
),
(
  'resource_allocation',
  'analyze_task_completion_vs_labor_available',
  'Crop team completed only 60% of weeding yesterday. Consider reassigning 1 livestock team member for 2 hours today to catch up.',
  jsonb_build_object('source', 'seed_defaults', 'domain', 'labor_planning')
),
(
  'predator_prevention',
  'analyze_incident_patterns',
  '3 predator sightings near goat zone in last week. Recommend early evening lock-up (16:30 instead of 17:30) until further notice.',
  jsonb_build_object('source', 'seed_defaults', 'domain', 'livestock_risk')
),
(
  'input_efficiency',
  'track_usage_vs_optimal',
  'Feed consumption for chickens is 15% above expected for current egg production. Consider feed adjustment or health check.',
  jsonb_build_object('source', 'seed_defaults', 'domain', 'input_optimization')
),
(
  'maintenance_prediction',
  'usage_patterns_and_time_since_service',
  'Fence line section A7 (near water point) hasn''t been inspected in 3 months. Schedule check before rainy season.',
  jsonb_build_object('source', 'seed_defaults', 'domain', 'preventive_maintenance')
)
on conflict (category_key) do update
set logic = excluded.logic,
    example = excluded.example,
    metadata = excluded.metadata,
    updated_at = now();

commit;

-- ------------------------------------------------------------------
-- Verification helpers
-- ------------------------------------------------------------------
select * from public.get_map_overview(now());
select public.get_trigger_playbook('new_asset_added') as sample_trigger_playbook;
select * from public.get_recommendation_categories();
-- Run the next 2 calls only when testing as an authenticated manager/owner user:
-- select public.enqueue_zone_questions('LVST-P1', '{}'::jsonb) as inserted_questions;
-- select public.generate_recommendations('LVST-P1', '{}'::jsonb) as inserted_recommendations;
