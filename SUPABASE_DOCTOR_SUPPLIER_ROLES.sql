-- Enable doctor/supplier login roles while preserving owner/manager/staff.
-- Run this in Supabase SQL editor after SUPABASE_SETUP.sql.

begin;

alter table public.profiles drop constraint if exists profiles_role_check;

alter table public.profiles
  add constraint profiles_role_check
  check (role in ('owner', 'manager', 'staff', 'doctor', 'supplier'));

comment on column public.profiles.role is
  'Application role: owner, manager, staff, doctor, supplier. Doctor/supplier currently use staff dashboards with external service logging.';

commit;
