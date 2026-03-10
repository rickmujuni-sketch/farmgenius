-- FarmGenius strict production RLS variant
-- Apply this AFTER running SUPABASE_SETUP.sql successfully.
-- This script removes permissive policies and replaces them with strict role-based policies.

begin;

-- Helper functions based on profiles.role
-- SECURITY DEFINER avoids recursive RLS evaluation when policies call these helpers.
create or replace function public.current_user_role_lookup(target_user uuid)
returns text
language sql
stable
security definer
set search_path = public
as $$
  select coalesce((select p.role from public.profiles p where p.id = target_user), 'staff');
$$;

revoke all on function public.current_user_role_lookup(uuid) from public;
grant execute on function public.current_user_role_lookup(uuid) to authenticated;

create or replace function public.current_user_role()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select public.current_user_role_lookup(auth.uid());
$$;

revoke all on function public.current_user_role() from public;
grant execute on function public.current_user_role() to authenticated;

create or replace function public.is_manager_or_owner()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.current_user_role() in ('manager', 'owner');
$$;

revoke all on function public.is_manager_or_owner() from public;
grant execute on function public.is_manager_or_owner() to authenticated;

-- Keep RLS enabled
alter table public.profiles enable row level security;
alter table public.tasks enable row level security;
alter table public.activity_logs enable row level security;
alter table public.anomalies enable row level security;
alter table public.farm_ledger_entries enable row level security;
alter table public.inventory_items enable row level security;
alter table public.inventory_transactions enable row level security;
alter table public.external_partner_entries enable row level security;

-- ===== PROFILES =====
drop policy if exists "users can view own profile" on public.profiles;
drop policy if exists "users can insert own profile" on public.profiles;
drop policy if exists "users can update own profile" on public.profiles;
drop policy if exists "profiles_select_own_or_manager" on public.profiles;
drop policy if exists "profiles_insert_own" on public.profiles;
drop policy if exists "profiles_update_own_no_role_escalation" on public.profiles;
drop policy if exists "profiles_update_manager_owner" on public.profiles;

create policy "profiles_select_own_or_manager"
on public.profiles
for select
using (id = auth.uid() or public.is_manager_or_owner());

create policy "profiles_insert_own"
on public.profiles
for insert
with check (id = auth.uid() and role = 'staff');

-- Users can update their own profile but cannot self-escalate role.
create policy "profiles_update_own_no_role_escalation"
on public.profiles
for update
using (id = auth.uid())
with check (
  id = auth.uid()
  and role = (select p.role from public.profiles p where p.id = auth.uid())
);

-- Managers/owners can update profiles (for role administration).
create policy "profiles_update_manager_owner"
on public.profiles
for update
using (public.is_manager_or_owner())
with check (public.is_manager_or_owner());

-- ===== TASKS =====
drop policy if exists "staff can view assigned tasks" on public.tasks;
drop policy if exists "manager can view all tasks" on public.tasks;
drop policy if exists "ai can create tasks" on public.tasks;
drop policy if exists "tasks_select_assigned_or_manager" on public.tasks;
drop policy if exists "tasks_insert_manager_owner_only" on public.tasks;
drop policy if exists "tasks_update_manager_owner_only" on public.tasks;

create policy "tasks_select_assigned_or_manager"
on public.tasks
for select
using (
  assigned_staff_id = auth.uid()
  or assigned_staff_id is null
  or public.is_manager_or_owner()
);

-- Strict: no public insert-all. Only manager/owner can insert via client.
-- If AI automation should write tasks in production, do it through an Edge Function using service role key.
create policy "tasks_insert_manager_owner_only"
on public.tasks
for insert
with check (public.is_manager_or_owner());

create policy "tasks_update_manager_owner_only"
on public.tasks
for update
using (public.is_manager_or_owner())
with check (public.is_manager_or_owner());

drop policy if exists "tasks_update_staff_claim_or_complete" on public.tasks;
create policy "tasks_update_staff_claim_or_complete"
on public.tasks
for update
using (assigned_staff_id = auth.uid() or assigned_staff_id is null)
with check (assigned_staff_id = auth.uid() or public.is_manager_or_owner());

-- ===== ACTIVITY LOGS =====
drop policy if exists "staff can view own logs" on public.activity_logs;
drop policy if exists "manager can view all logs" on public.activity_logs;
drop policy if exists "staff can insert own logs" on public.activity_logs;
drop policy if exists "activity_logs_select_own_or_manager" on public.activity_logs;
drop policy if exists "activity_logs_insert_own" on public.activity_logs;
drop policy if exists "activity_logs_update_own_or_manager" on public.activity_logs;

create policy "activity_logs_select_own_or_manager"
on public.activity_logs
for select
using (
  staff_id = auth.uid()
  or public.is_manager_or_owner()
);

create policy "activity_logs_insert_own"
on public.activity_logs
for insert
with check (staff_id = auth.uid());

create policy "activity_logs_update_own_or_manager"
on public.activity_logs
for update
using (staff_id = auth.uid() or public.is_manager_or_owner())
with check (staff_id = auth.uid() or public.is_manager_or_owner());

-- ===== FARM LEDGER ENTRIES =====
drop policy if exists "farm_ledger_select_own_or_manager" on public.farm_ledger_entries;
drop policy if exists "farm_ledger_insert_own" on public.farm_ledger_entries;
drop policy if exists "farm_ledger_update_manager_owner" on public.farm_ledger_entries;

create policy "farm_ledger_select_own_or_manager"
on public.farm_ledger_entries
for select
using (
  staff_id = auth.uid()
  or public.is_manager_or_owner()
);

create policy "farm_ledger_insert_own"
on public.farm_ledger_entries
for insert
with check (staff_id = auth.uid());

create policy "farm_ledger_update_manager_owner"
on public.farm_ledger_entries
for update
using (public.is_manager_or_owner())
with check (public.is_manager_or_owner());

-- ===== ANOMALIES =====
drop policy if exists "manager can view anomalies" on public.anomalies;
drop policy if exists "ai can create anomalies" on public.anomalies;
drop policy if exists "anomalies_select_manager_owner" on public.anomalies;
drop policy if exists "anomalies_insert_manager_owner_only" on public.anomalies;
drop policy if exists "anomalies_update_manager_owner_only" on public.anomalies;

create policy "anomalies_select_manager_owner"
on public.anomalies
for select
using (public.is_manager_or_owner());

-- Strict: no public insert-all.
create policy "anomalies_insert_manager_owner_only"
on public.anomalies
for insert
with check (public.is_manager_or_owner());

create policy "anomalies_update_manager_owner_only"
on public.anomalies
for update
using (public.is_manager_or_owner())
with check (public.is_manager_or_owner());

-- ===== INVENTORY ITEMS =====
drop policy if exists "inventory_items_select_all_authenticated" on public.inventory_items;
drop policy if exists "inventory_items_manage_manager_owner" on public.inventory_items;

create policy "inventory_items_select_all_authenticated"
on public.inventory_items
for select
using (auth.role() = 'authenticated');

create policy "inventory_items_manage_manager_owner"
on public.inventory_items
for all
using (public.is_manager_or_owner())
with check (public.is_manager_or_owner());

-- ===== INVENTORY TRANSACTIONS =====
drop policy if exists "inventory_tx_select_own_or_manager" on public.inventory_transactions;
drop policy if exists "inventory_tx_insert_own" on public.inventory_transactions;
drop policy if exists "inventory_tx_update_manager_two_eyes" on public.inventory_transactions;

create policy "inventory_tx_select_own_or_manager"
on public.inventory_transactions
for select
using (
  submitted_by = auth.uid()
  or public.is_manager_or_owner()
);

create policy "inventory_tx_insert_own"
on public.inventory_transactions
for insert
with check (submitted_by = auth.uid());

create policy "inventory_tx_update_manager_two_eyes"
on public.inventory_transactions
for update
using (public.is_manager_or_owner())
with check (
  public.is_manager_or_owner()
  and reviewed_by <> submitted_by
);

-- ===== EXTERNAL PARTNER ENTRIES =====
drop policy if exists "external_entries_select_own_or_manager" on public.external_partner_entries;
drop policy if exists "external_entries_insert_own" on public.external_partner_entries;
drop policy if exists "external_entries_update_manager_two_eyes" on public.external_partner_entries;

create policy "external_entries_select_own_or_manager"
on public.external_partner_entries
for select
using (
  submitted_by = auth.uid()
  or public.is_manager_or_owner()
);

create policy "external_entries_insert_own"
on public.external_partner_entries
for insert
with check (submitted_by = auth.uid());

create policy "external_entries_update_manager_two_eyes"
on public.external_partner_entries
for update
using (public.is_manager_or_owner())
with check (
  public.is_manager_or_owner()
  and reviewed_by <> submitted_by
);

commit;

-- Verification
select schemaname, tablename, policyname, cmd
from pg_policies
where schemaname = 'public'
  and tablename in (
    'profiles',
    'tasks',
    'activity_logs',
    'anomalies',
    'farm_ledger_entries',
    'inventory_items',
    'inventory_transactions',
    'external_partner_entries'
  )
order by tablename, policyname;
