-- FarmGenius Milestone 2 Supabase Setup
-- Copy and paste these into your Supabase SQL Editor

-- Profiles table - app-level role and user metadata
create table if not exists profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  role text not null default 'staff' check (role in ('owner', 'manager', 'staff')),
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'profiles' and column_name = 'role'
  ) then
    create index if not exists profiles_role on profiles(role);
  end if;

  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'profiles' and column_name = 'email'
  ) then
    create index if not exists profiles_email on profiles(email);
  end if;
end $$;

-- Farm ledger entries - structured financial history for self-improving assist and reporting
create table if not exists farm_ledger_entries (
  id text primary key,
  activity_log_id text,
  task_id text,
  zone_id text not null,
  staff_id uuid not null,
  entry_type text not null check (entry_type in ('expense', 'revenue')),
  category text not null,
  amount_tzs double precision not null check (amount_tzs >= 0),
  quantity double precision,
  quantity_unit text,
  source text default 'staff_execution',
  metadata jsonb default '{}'::jsonb,
  occurred_at timestamptz default now(),
  created_at timestamptz default now()
);

do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'farm_ledger_entries' and column_name = 'zone_id'
  ) then
    create index if not exists farm_ledger_entries_zone_id on farm_ledger_entries(zone_id);
  end if;

  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'farm_ledger_entries' and column_name = 'staff_id'
  ) then
    create index if not exists farm_ledger_entries_staff_id on farm_ledger_entries(staff_id);
  end if;

  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'farm_ledger_entries' and column_name = 'entry_type'
  ) then
    create index if not exists farm_ledger_entries_entry_type on farm_ledger_entries(entry_type);
  end if;

  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'farm_ledger_entries' and column_name = 'category'
  ) then
    create index if not exists farm_ledger_entries_category on farm_ledger_entries(category);
  end if;

  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'farm_ledger_entries' and column_name = 'occurred_at'
  ) then
    create index if not exists farm_ledger_entries_occurred_at on farm_ledger_entries(occurred_at);
  end if;
end $$;

-- Inventory master - consumables and materials to support 3-week availability planning
create table if not exists inventory_items (
  id text primary key,
  name text not null,
  category text,
  unit text not null default 'unit',
  quantity_on_hand double precision not null default 0,
  reorder_level double precision not null default 0,
  target_days_cover int not null default 21,
  avg_daily_usage double precision not null default 0,
  unit_cost_tzs double precision not null default 0,
  is_active boolean not null default true,
  metadata jsonb default '{}'::jsonb,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table if not exists inventory_transactions (
  id text primary key,
  item_id text not null references inventory_items(id) on delete cascade,
  movement_type text not null check (movement_type in ('in', 'out', 'adjustment')),
  quantity double precision not null check (quantity >= 0),
  unit_cost_tzs double precision,
  transaction_date timestamptz not null default now(),
  reference_type text,
  reference_id text,
  notes text,
  verification_status text not null default 'pending_review' check (verification_status in ('pending_review', 'approved', 'rejected')),
  submitted_by uuid not null references auth.users(id) on delete cascade,
  reviewed_by uuid references auth.users(id) on delete set null,
  reviewed_at timestamptz,
  metadata jsonb default '{}'::jsonb,
  created_at timestamptz default now()
);

-- External entries - doctors/suppliers can submit records, then verified internally (two-eyes principle)
create table if not exists external_partner_entries (
  id text primary key,
  partner_type text not null check (partner_type in ('doctor', 'supplier', 'contractor', 'other')),
  entry_kind text not null check (entry_kind in ('visit', 'service', 'delivery', 'invoice', 'payment_request', 'note')),
  partner_name text not null,
  service_date timestamptz not null default now(),
  description text,
  amount_tzs double precision not null default 0 check (amount_tzs >= 0),
  payment_status text not null default 'pending' check (payment_status in ('pending', 'approved_for_payment', 'paid', 'disputed')),
  verification_status text not null default 'pending_review' check (verification_status in ('pending_review', 'approved', 'rejected')),
  submitted_by uuid not null references auth.users(id) on delete cascade,
  reviewed_by uuid references auth.users(id) on delete set null,
  reviewed_at timestamptz,
  metadata jsonb default '{}'::jsonb,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

do $$
begin
  create index if not exists inventory_items_category_idx on inventory_items(category);
  create index if not exists inventory_items_is_active_idx on inventory_items(is_active);
  create index if not exists inventory_transactions_item_id_idx on inventory_transactions(item_id);
  create index if not exists inventory_transactions_date_idx on inventory_transactions(transaction_date);
  create index if not exists inventory_transactions_verification_idx on inventory_transactions(verification_status);
  create index if not exists external_partner_entries_type_idx on external_partner_entries(partner_type);
  create index if not exists external_partner_entries_created_idx on external_partner_entries(created_at);
  create index if not exists external_partner_entries_verification_idx on external_partner_entries(verification_status);
end $$;

-- Tasks table - AI-generated work items
create table if not exists tasks (
  id text primary key,
  zone_id text not null,
  title text not null,
  description text,
  activity text,
  due_date timestamptz not null,
  priority text default 'MEDIUM',
  status text default 'PENDING',
  created_at timestamptz default now(),
  created_by_ai text,
  assigned_staff_id uuid,
  metadata jsonb default '{}'::jsonb,
  updated_at timestamptz default now()
);

do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'tasks' and column_name = 'zone_id'
  ) then
    create index if not exists tasks_zone_id on tasks(zone_id);
  end if;

  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'tasks' and column_name = 'status'
  ) then
    create index if not exists tasks_status on tasks(status);
  end if;

  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'tasks' and column_name = 'due_date'
  ) then
    create index if not exists tasks_due_date on tasks(due_date);
  end if;

  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'tasks' and column_name = 'assigned_staff_id'
  ) then
    create index if not exists tasks_assigned_staff_id on tasks(assigned_staff_id);
  end if;
end $$;

-- Activity logs - records of work completed by staff
create table if not exists activity_logs (
  id text primary key,
  task_id text references tasks(id) on delete set null,
  zone_id text not null,
  staff_id uuid not null references auth.users(id) on delete cascade,
  activity text not null,
  logged_at timestamptz default now(),
  completed_at timestamptz,
  photo_urls jsonb default '{}'::jsonb,
  notes text,
  quantity int,
  quantity_unit text,
  cost double precision,
  created_at timestamptz default now()
);

do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'activity_logs' and column_name = 'zone_id'
  ) then
    create index if not exists activity_logs_zone_id on activity_logs(zone_id);
  end if;

  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'activity_logs' and column_name = 'staff_id'
  ) then
    create index if not exists activity_logs_staff_id on activity_logs(staff_id);
  end if;

  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'activity_logs' and column_name = 'task_id'
  ) then
    create index if not exists activity_logs_task_id on activity_logs(task_id);
  end if;

  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'activity_logs' and column_name = 'logged_at'
  ) then
    create index if not exists activity_logs_logged_at on activity_logs(logged_at);
  end if;
end $$;

-- Anomaly detections - AI insights and alerts
create table if not exists anomalies (
  id text primary key,
  zone_id text not null,
  type text not null, -- ACTIVITY_GAP, COST_SPIKE, YIELD_RISK, WEATHER_ALERT, HEALTH_ISSUE
  title text not null,
  description text,
  severity double precision default 0.5, -- 0.0 to 1.0
  detected_at timestamptz default now(),
  resolved_at timestamptz,
  resolved_by uuid references auth.users(id),
  manager_notes text,
  data jsonb default '{}'::jsonb,
  created_at timestamptz default now()
);

do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'anomalies' and column_name = 'zone_id'
  ) then
    create index if not exists anomalies_zone_id on anomalies(zone_id);
  end if;

  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'anomalies' and column_name = 'severity'
  ) then
    create index if not exists anomalies_severity on anomalies(severity);
  end if;

  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'anomalies' and column_name = 'detected_at'
  ) then
    create index if not exists anomalies_detected_at on anomalies(detected_at);
  end if;
end $$;

-- Repair schema drift (safe to re-run)
alter table profiles add column if not exists email text;
alter table profiles add column if not exists role text;
alter table profiles add column if not exists created_at timestamptz default now();
alter table profiles add column if not exists updated_at timestamptz default now();
alter table profiles alter column role set default 'staff';
update profiles set role = 'staff' where role is null;
do $$
begin
  alter table profiles
    add constraint profiles_role_check
    check (role in ('owner', 'manager', 'staff'));
exception
  when duplicate_object then null;
end $$;

-- Backfill existing auth users into profiles (safe to re-run)
insert into profiles (id, email, role)
select id, email, 'staff'
from auth.users
on conflict (id) do update
set email = excluded.email,
    role = coalesce(profiles.role, excluded.role),
    updated_at = now();

alter table tasks add column if not exists zone_id text;
alter table tasks add column if not exists title text;
alter table tasks add column if not exists description text;
alter table tasks add column if not exists activity text;
alter table tasks add column if not exists due_date timestamptz;
alter table tasks add column if not exists priority text default 'MEDIUM';
alter table tasks add column if not exists status text default 'PENDING';
alter table tasks add column if not exists created_at timestamptz default now();
alter table tasks add column if not exists created_by_ai text;
alter table tasks add column if not exists assigned_staff_id uuid;
alter table tasks add column if not exists metadata jsonb default '{}'::jsonb;
alter table tasks add column if not exists updated_at timestamptz default now();

alter table activity_logs add column if not exists task_id text;
alter table activity_logs add column if not exists zone_id text;
alter table activity_logs add column if not exists staff_id uuid;
alter table activity_logs add column if not exists activity text;
alter table activity_logs add column if not exists logged_at timestamptz default now();
alter table activity_logs add column if not exists completed_at timestamptz;
alter table activity_logs add column if not exists photo_urls jsonb default '{}'::jsonb;
alter table activity_logs add column if not exists notes text;
alter table activity_logs add column if not exists quantity int;
alter table activity_logs add column if not exists quantity_unit text;
alter table activity_logs add column if not exists cost double precision;
alter table activity_logs add column if not exists created_at timestamptz default now();

alter table farm_ledger_entries add column if not exists activity_log_id text;
alter table farm_ledger_entries add column if not exists task_id text;
alter table farm_ledger_entries add column if not exists zone_id text;
alter table farm_ledger_entries add column if not exists staff_id uuid;
alter table farm_ledger_entries add column if not exists entry_type text;
alter table farm_ledger_entries add column if not exists category text;
alter table farm_ledger_entries add column if not exists amount_tzs double precision;
alter table farm_ledger_entries add column if not exists quantity double precision;
alter table farm_ledger_entries add column if not exists quantity_unit text;
alter table farm_ledger_entries add column if not exists source text default 'staff_execution';
alter table farm_ledger_entries add column if not exists metadata jsonb default '{}'::jsonb;
alter table farm_ledger_entries add column if not exists occurred_at timestamptz default now();
alter table farm_ledger_entries add column if not exists created_at timestamptz default now();

alter table inventory_items add column if not exists name text;
alter table inventory_items add column if not exists category text;
alter table inventory_items add column if not exists unit text default 'unit';
alter table inventory_items add column if not exists quantity_on_hand double precision default 0;
alter table inventory_items add column if not exists reorder_level double precision default 0;
alter table inventory_items add column if not exists target_days_cover int default 21;
alter table inventory_items add column if not exists avg_daily_usage double precision default 0;
alter table inventory_items add column if not exists unit_cost_tzs double precision default 0;
alter table inventory_items add column if not exists is_active boolean default true;
alter table inventory_items add column if not exists metadata jsonb default '{}'::jsonb;
alter table inventory_items add column if not exists created_at timestamptz default now();
alter table inventory_items add column if not exists updated_at timestamptz default now();

alter table inventory_transactions add column if not exists item_id text;
alter table inventory_transactions add column if not exists movement_type text;
alter table inventory_transactions add column if not exists quantity double precision;
alter table inventory_transactions add column if not exists unit_cost_tzs double precision;
alter table inventory_transactions add column if not exists transaction_date timestamptz default now();
alter table inventory_transactions add column if not exists reference_type text;
alter table inventory_transactions add column if not exists reference_id text;
alter table inventory_transactions add column if not exists notes text;
alter table inventory_transactions add column if not exists verification_status text default 'pending_review';
alter table inventory_transactions add column if not exists submitted_by uuid;
alter table inventory_transactions add column if not exists reviewed_by uuid;
alter table inventory_transactions add column if not exists reviewed_at timestamptz;
alter table inventory_transactions add column if not exists metadata jsonb default '{}'::jsonb;
alter table inventory_transactions add column if not exists created_at timestamptz default now();

alter table external_partner_entries add column if not exists partner_type text;
alter table external_partner_entries add column if not exists entry_kind text;
alter table external_partner_entries add column if not exists partner_name text;
alter table external_partner_entries add column if not exists service_date timestamptz default now();
alter table external_partner_entries add column if not exists description text;
alter table external_partner_entries add column if not exists amount_tzs double precision default 0;
alter table external_partner_entries add column if not exists payment_status text default 'pending';
alter table external_partner_entries add column if not exists verification_status text default 'pending_review';
alter table external_partner_entries add column if not exists submitted_by uuid;
alter table external_partner_entries add column if not exists reviewed_by uuid;
alter table external_partner_entries add column if not exists reviewed_at timestamptz;
alter table external_partner_entries add column if not exists metadata jsonb default '{}'::jsonb;
alter table external_partner_entries add column if not exists created_at timestamptz default now();
alter table external_partner_entries add column if not exists updated_at timestamptz default now();

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'farm_ledger_entries_activity_log_id_fkey'
  )
  and exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'farm_ledger_entries'
      and column_name = 'activity_log_id'
      and data_type = 'text'
  )
  and exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'activity_logs'
      and column_name = 'id'
      and data_type = 'text'
  ) then
    alter table farm_ledger_entries
      add constraint farm_ledger_entries_activity_log_id_fkey
      foreign key (activity_log_id) references activity_logs(id) on delete set null;
  end if;
end $$;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'inventory_transactions_item_id_fkey'
  ) then
    alter table inventory_transactions
      add constraint inventory_transactions_item_id_fkey
      foreign key (item_id) references inventory_items(id) on delete cascade;
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'inventory_transactions_submitted_by_fkey'
  ) then
    alter table inventory_transactions
      add constraint inventory_transactions_submitted_by_fkey
      foreign key (submitted_by) references auth.users(id) on delete cascade;
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'inventory_transactions_reviewed_by_fkey'
  ) then
    alter table inventory_transactions
      add constraint inventory_transactions_reviewed_by_fkey
      foreign key (reviewed_by) references auth.users(id) on delete set null;
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'external_partner_entries_submitted_by_fkey'
  ) then
    alter table external_partner_entries
      add constraint external_partner_entries_submitted_by_fkey
      foreign key (submitted_by) references auth.users(id) on delete cascade;
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'external_partner_entries_reviewed_by_fkey'
  ) then
    alter table external_partner_entries
      add constraint external_partner_entries_reviewed_by_fkey
      foreign key (reviewed_by) references auth.users(id) on delete set null;
  end if;
end $$;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'inventory_transactions_reviewing_requires_second_user'
  ) then
    alter table inventory_transactions
      add constraint inventory_transactions_reviewing_requires_second_user
      check (reviewed_by is null or reviewed_by <> submitted_by);
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'inventory_transactions_review_stamp_required'
  ) then
    alter table inventory_transactions
      add constraint inventory_transactions_review_stamp_required
      check (
        verification_status = 'pending_review'
        or (reviewed_by is not null and reviewed_at is not null)
      );
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'external_partner_entries_reviewing_requires_second_user'
  ) then
    alter table external_partner_entries
      add constraint external_partner_entries_reviewing_requires_second_user
      check (reviewed_by is null or reviewed_by <> submitted_by);
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'external_partner_entries_review_stamp_required'
  ) then
    alter table external_partner_entries
      add constraint external_partner_entries_review_stamp_required
      check (
        verification_status = 'pending_review'
        or (reviewed_by is not null and reviewed_at is not null)
      );
  end if;
end $$;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'farm_ledger_entries_task_id_fkey'
  )
  and exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'farm_ledger_entries'
      and column_name = 'task_id'
      and data_type = 'text'
  )
  and exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'tasks'
      and column_name = 'id'
      and data_type = 'text'
  ) then
    alter table farm_ledger_entries
      add constraint farm_ledger_entries_task_id_fkey
      foreign key (task_id) references tasks(id) on delete set null;
  end if;
end $$;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'farm_ledger_entries_staff_id_fkey'
  ) then
    alter table farm_ledger_entries
      add constraint farm_ledger_entries_staff_id_fkey
      foreign key (staff_id) references auth.users(id) on delete cascade;
  end if;
end $$;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'farm_ledger_entries_entry_type_check'
  ) then
    alter table farm_ledger_entries
      add constraint farm_ledger_entries_entry_type_check
      check (entry_type in ('expense', 'revenue'));
  end if;
end $$;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'farm_ledger_entries_amount_tzs_check'
  ) then
    alter table farm_ledger_entries
      add constraint farm_ledger_entries_amount_tzs_check
      check (amount_tzs >= 0);
  end if;
end $$;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'activity_logs_task_id_fkey'
  )
  and exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'activity_logs'
      and column_name = 'task_id'
      and data_type = 'text'
  )
  and exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'tasks'
      and column_name = 'id'
      and data_type = 'text'
  ) then
    alter table activity_logs
      add constraint activity_logs_task_id_fkey
      foreign key (task_id) references tasks(id) on delete set null;
  end if;
end $$;

-- Normalize key column types if older schema used uuid IDs
do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'activity_logs'
      and column_name = 'id'
      and data_type <> 'text'
  ) then
    alter table farm_ledger_entries drop constraint if exists farm_ledger_entries_activity_log_id_fkey;
    alter table activity_logs alter column id type text using id::text;
  end if;

  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'farm_ledger_entries'
      and column_name = 'activity_log_id'
      and data_type <> 'text'
  ) then
    alter table farm_ledger_entries alter column activity_log_id type text using activity_log_id::text;
  end if;

  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'tasks'
      and column_name = 'id'
      and data_type <> 'text'
  ) then
    alter table activity_logs drop constraint if exists activity_logs_task_id_fkey;
    alter table tasks alter column id type text using id::text;
  end if;

  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'activity_logs'
      and column_name = 'task_id'
      and data_type <> 'text'
  ) then
    alter table activity_logs alter column task_id type text using task_id::text;
  end if;

  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'farm_ledger_entries'
      and column_name = 'task_id'
      and data_type <> 'text'
  ) then
    alter table farm_ledger_entries alter column task_id type text using task_id::text;
  end if;
end $$;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'farm_ledger_entries_activity_log_id_fkey'
  )
  and exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'farm_ledger_entries'
      and column_name = 'activity_log_id'
      and data_type = 'text'
  )
  and exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'activity_logs'
      and column_name = 'id'
      and data_type = 'text'
  ) then
    alter table farm_ledger_entries
      add constraint farm_ledger_entries_activity_log_id_fkey
      foreign key (activity_log_id) references activity_logs(id) on delete set null;
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'farm_ledger_entries_task_id_fkey'
  )
  and exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'farm_ledger_entries'
      and column_name = 'task_id'
      and data_type = 'text'
  )
  and exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'tasks'
      and column_name = 'id'
      and data_type = 'text'
  ) then
    alter table farm_ledger_entries
      add constraint farm_ledger_entries_task_id_fkey
      foreign key (task_id) references tasks(id) on delete set null;
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'activity_logs_task_id_fkey'
  ) then
    alter table activity_logs
      add constraint activity_logs_task_id_fkey
      foreign key (task_id) references tasks(id) on delete set null;
  end if;
end $$;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'activity_logs_staff_id_fkey'
  ) then
    alter table activity_logs
      add constraint activity_logs_staff_id_fkey
      foreign key (staff_id) references auth.users(id) on delete cascade;
  end if;
end $$;

alter table anomalies add column if not exists zone_id text;
alter table anomalies add column if not exists type text;
alter table anomalies add column if not exists title text;
alter table anomalies add column if not exists description text;
alter table anomalies add column if not exists severity double precision default 0.5;
alter table anomalies add column if not exists detected_at timestamptz default now();
alter table anomalies add column if not exists resolved_at timestamptz;
alter table anomalies add column if not exists resolved_by uuid;
alter table anomalies add column if not exists manager_notes text;
alter table anomalies add column if not exists data jsonb default '{}'::jsonb;
alter table anomalies add column if not exists created_at timestamptz default now();

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'anomalies_resolved_by_fkey'
  ) then
    alter table anomalies
      add constraint anomalies_resolved_by_fkey
      foreign key (resolved_by) references auth.users(id);
  end if;
end $$;

-- Enable RLS on new tables
alter table profiles enable row level security;
alter table tasks enable row level security;
alter table activity_logs enable row level security;
alter table anomalies enable row level security;
alter table farm_ledger_entries enable row level security;
alter table inventory_items enable row level security;
alter table inventory_transactions enable row level security;
alter table external_partner_entries enable row level security;

-- RLS Policies for Profiles
drop policy if exists "users can view own profile" on profiles;
create policy "users can view own profile" on profiles
  for select using (id = auth.uid());

drop policy if exists "users can insert own profile" on profiles;
create policy "users can insert own profile" on profiles
  for insert with check (id = auth.uid() and role = 'staff');

drop policy if exists "users can update own profile" on profiles;
create policy "users can update own profile" on profiles
  for update using (id = auth.uid()) with check (id = auth.uid());

-- RLS Policies for Tasks
drop policy if exists "staff can view assigned tasks" on tasks;
drop policy if exists "staff can view actionable tasks" on tasks;
create policy "staff can view actionable tasks" on tasks
  for select using (assigned_staff_id = auth.uid() or assigned_staff_id is null);

drop policy if exists "manager can view all tasks" on tasks;
create policy "manager can view all tasks" on tasks
  for select using (
    auth.jwt() ->> 'role' = 'manager' or auth.jwt() ->> 'role' = 'owner'
  );

drop policy if exists "manager can update all tasks" on tasks;
create policy "manager can update all tasks" on tasks
  for update using (
    auth.jwt() ->> 'role' = 'manager' or auth.jwt() ->> 'role' = 'owner'
  ) with check (
    auth.jwt() ->> 'role' = 'manager' or auth.jwt() ->> 'role' = 'owner'
  );

drop policy if exists "ai can create tasks" on tasks;
create policy "ai can create tasks" on tasks
  for insert with check (
    auth.jwt() ->> 'role' = 'manager' or auth.jwt() ->> 'role' = 'owner'
  );

drop policy if exists "staff can update own or claim tasks" on tasks;
create policy "staff can update own or claim tasks" on tasks
  for update
  using (assigned_staff_id = auth.uid() or assigned_staff_id is null)
  with check (assigned_staff_id = auth.uid());

-- RLS Policies for Activity Logs
drop policy if exists "staff can view own logs" on activity_logs;
create policy "staff can view own logs" on activity_logs
  for select using (staff_id = auth.uid());

drop policy if exists "manager can view all logs" on activity_logs;
create policy "manager can view all logs" on activity_logs
  for select using (
    auth.jwt() ->> 'role' = 'manager' or auth.jwt() ->> 'role' = 'owner'
  );

drop policy if exists "staff can insert own logs" on activity_logs;
create policy "staff can insert own logs" on activity_logs
  for insert with check (staff_id = auth.uid());

-- RLS Policies for Farm Ledger Entries
drop policy if exists "staff can view own ledger entries" on farm_ledger_entries;
create policy "staff can view own ledger entries" on farm_ledger_entries
  for select using (staff_id = auth.uid());

drop policy if exists "manager can view all ledger entries" on farm_ledger_entries;
create policy "manager can view all ledger entries" on farm_ledger_entries
  for select using (
    auth.jwt() ->> 'role' = 'manager' or auth.jwt() ->> 'role' = 'owner'
  );

drop policy if exists "staff can insert own ledger entries" on farm_ledger_entries;
create policy "staff can insert own ledger entries" on farm_ledger_entries
  for insert with check (staff_id = auth.uid());

drop policy if exists "manager can update ledger entries" on farm_ledger_entries;
create policy "manager can update ledger entries" on farm_ledger_entries
  for update using (
    auth.jwt() ->> 'role' = 'manager' or auth.jwt() ->> 'role' = 'owner'
  ) with check (
    auth.jwt() ->> 'role' = 'manager' or auth.jwt() ->> 'role' = 'owner'
  );

-- RLS Policies for Inventory
drop policy if exists "staff can view inventory items" on inventory_items;
create policy "staff can view inventory items" on inventory_items
  for select using (auth.uid() is not null);

drop policy if exists "manager can manage inventory items" on inventory_items;
create policy "manager can manage inventory items" on inventory_items
  for all using (
    auth.jwt() ->> 'role' = 'manager' or auth.jwt() ->> 'role' = 'owner'
  ) with check (
    auth.jwt() ->> 'role' = 'manager' or auth.jwt() ->> 'role' = 'owner'
  );

drop policy if exists "staff can insert own inventory transactions" on inventory_transactions;
create policy "staff can insert own inventory transactions" on inventory_transactions
  for insert with check (submitted_by = auth.uid());

drop policy if exists "staff can view inventory transactions" on inventory_transactions;
create policy "staff can view inventory transactions" on inventory_transactions
  for select using (submitted_by = auth.uid() or auth.jwt() ->> 'role' in ('manager', 'owner'));

drop policy if exists "managers verify inventory transactions" on inventory_transactions;
create policy "managers verify inventory transactions" on inventory_transactions
  for update using (
    auth.jwt() ->> 'role' in ('manager', 'owner')
  ) with check (
    auth.jwt() ->> 'role' in ('manager', 'owner')
    and reviewed_by <> submitted_by
  );

-- RLS Policies for External Partner Entries
drop policy if exists "staff can insert own external entries" on external_partner_entries;
create policy "staff can insert own external entries" on external_partner_entries
  for insert with check (submitted_by = auth.uid());

drop policy if exists "staff can view external entries" on external_partner_entries;
create policy "staff can view external entries" on external_partner_entries
  for select using (submitted_by = auth.uid() or auth.jwt() ->> 'role' in ('manager', 'owner'));

drop policy if exists "managers verify external entries" on external_partner_entries;
create policy "managers verify external entries" on external_partner_entries
  for update using (
    auth.jwt() ->> 'role' in ('manager', 'owner')
  ) with check (
    auth.jwt() ->> 'role' in ('manager', 'owner')
    and reviewed_by <> submitted_by
  );

-- RLS Policies for Anomalies
drop policy if exists "manager can view anomalies" on anomalies;
create policy "manager can view anomalies" on anomalies
  for select using (
    auth.jwt() ->> 'role' = 'manager' or auth.jwt() ->> 'role' = 'owner'
  );

drop policy if exists "ai can create anomalies" on anomalies;
create policy "ai can create anomalies" on anomalies
  for insert with check (
    auth.jwt() ->> 'role' = 'manager' or auth.jwt() ->> 'role' = 'owner'
  );

-- ===== VERIFICATION (run after setup) =====
-- Expected tables
select table_name
from information_schema.tables
where table_schema = 'public'
  and table_name in (
    'profiles',
    'tasks',
    'activity_logs',
    'anomalies',
    'farm_ledger_entries',
    'inventory_items',
    'inventory_transactions',
    'external_partner_entries'
  )
order by table_name;

-- Quick row counts
select
  (select count(*) from profiles) as profiles_count,
  (select count(*) from tasks) as tasks_count,
  (select count(*) from activity_logs) as activity_logs_count,
  (select count(*) from anomalies) as anomalies_count,
  (select count(*) from farm_ledger_entries) as farm_ledger_entries_count,
  (select count(*) from inventory_items) as inventory_items_count,
  (select count(*) from inventory_transactions) as inventory_transactions_count,
  (select count(*) from external_partner_entries) as external_partner_entries_count;

-- ===== NEXT STEPS =====
-- 1. Copy all SQL above and paste into your Supabase SQL Editor
-- 2. Click "Run" to create the tables
-- 3. In Flutter, initialize the AIOrchestrator in main.dart
-- 4. Call aiOrchestrator.runDailyOrchestration() periodically (e.g., on app startup)
