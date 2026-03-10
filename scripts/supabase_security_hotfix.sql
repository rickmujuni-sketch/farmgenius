-- FarmGenius Supabase Security Hotfix (idempotent)
-- Run this in Supabase SQL Editor on the target project.

begin;

-- Ensure RLS is enabled on core tables
alter table if exists public.profiles enable row level security;
alter table if exists public.tasks enable row level security;
alter table if exists public.activity_logs enable row level security;
alter table if exists public.anomalies enable row level security;
alter table if exists public.farm_ledger_entries enable row level security;
alter table if exists public.inventory_items enable row level security;
alter table if exists public.inventory_transactions enable row level security;
alter table if exists public.external_partner_entries enable row level security;

-- 1) Prevent public self-signup role escalation
drop policy if exists "users can insert own profile" on public.profiles;
create policy "users can insert own profile"
on public.profiles
for insert
with check (id = auth.uid() and role = 'staff');

drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own"
on public.profiles
for insert
with check (id = auth.uid() and role = 'staff');

-- 2) Remove permissive AI insert policies
drop policy if exists "ai can create tasks" on public.tasks;
create policy "ai can create tasks"
on public.tasks
for insert
with check (
  auth.jwt() ->> 'role' = 'manager' or auth.jwt() ->> 'role' = 'owner'
);

drop policy if exists "tasks_insert_manager_owner_only" on public.tasks;
create policy "tasks_insert_manager_owner_only"
on public.tasks
for insert
with check (
  auth.jwt() ->> 'role' = 'manager' or auth.jwt() ->> 'role' = 'owner'
);

drop policy if exists "ai can create anomalies" on public.anomalies;
create policy "ai can create anomalies"
on public.anomalies
for insert
with check (
  auth.jwt() ->> 'role' = 'manager' or auth.jwt() ->> 'role' = 'owner'
);

drop policy if exists "anomalies_insert_manager_owner_only" on public.anomalies;
create policy "anomalies_insert_manager_owner_only"
on public.anomalies
for insert
with check (
  auth.jwt() ->> 'role' = 'manager' or auth.jwt() ->> 'role' = 'owner'
);

-- 3) Tighten broad inventory read policy
drop policy if exists "staff can view inventory items" on public.inventory_items;
create policy "staff can view inventory items"
on public.inventory_items
for select
using (auth.uid() is not null);

drop policy if exists "inventory_items_select_all_authenticated" on public.inventory_items;
create policy "inventory_items_select_all_authenticated"
on public.inventory_items
for select
using (auth.role() = 'authenticated');

commit;

-- -----------------------------
-- Verification queries
-- -----------------------------

-- A) Find dangerous permissive policies
select schemaname, tablename, policyname, cmd, qual, with_check
from pg_policies
where schemaname = 'public'
  and (
    coalesce(qual, '') ~* '(^|[^a-z_])true([^a-z_]|$)'
    or coalesce(with_check, '') ~* '(^|[^a-z_])true([^a-z_]|$)'
  )
order by tablename, policyname;

-- B) Verify core profile-insert policy prevents non-staff self role
select schemaname, tablename, policyname, cmd, with_check
from pg_policies
where schemaname = 'public'
  and tablename = 'profiles'
  and policyname in ('users can insert own profile', 'profiles_insert_own')
order by policyname;

-- C) Verify tasks/anomalies insert checks are not open
select schemaname, tablename, policyname, cmd, with_check
from pg_policies
where schemaname = 'public'
  and tablename in ('tasks', 'anomalies')
  and cmd = 'INSERT'
order by tablename, policyname;

-- D) Verify inventory read is authenticated-only
select schemaname, tablename, policyname, cmd, qual
from pg_policies
where schemaname = 'public'
  and tablename = 'inventory_items'
  and cmd = 'SELECT'
order by policyname;
