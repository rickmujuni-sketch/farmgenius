-- FarmGenius Milestone 2 Supabase Setup
-- Copy and paste these into your Supabase SQL Editor

-- Tasks table - AI-generated work items
create table if not exists tasks (
  id text primary key,
  zone_id text not null,
  title text not null,
  description text,
  activity text, -- PLANTING, GERMINATION, GROWTH, FLOWERING, GRAIN_FILL, HARVEST, etc.
  due_date timestamptz not null,
  priority text default 'MEDIUM', -- LOW, MEDIUM, HIGH, URGENT
  status text default 'PENDING', -- PENDING, IN_PROGRESS, COMPLETED, CANCELLED, OVERDUE
  created_at timestamptz default now(),
  created_by_ai text, -- 'calendar_due', 'weather_risk', 'anomaly_detected'
  assigned_staff_id uuid,
  metadata jsonb default '{}'::jsonb,
  updated_at timestamptz default now()
);

create index if not exists tasks_zone_id on tasks(zone_id);
create index if not exists tasks_status on tasks(status);
create index if not exists tasks_due_date on tasks(due_date);
create index if not exists tasks_assigned_staff_id on tasks(assigned_staff_id);

-- Activity logs - records of work completed by staff
create table if not exists activity_logs (
  id text primary key,
  task_id text references tasks(id) on delete set null,
  zone_id text not null,
  staff_id uuid not null references auth.users(id) on delete cascade,
  activity text not null, -- same as Task.activity
  logged_at timestamptz default now(),
  completed_at timestamptz,
  photo_urls jsonb default '{}'::jsonb, -- { 'before': 'url', 'after': 'url', 'evidence': 'url' }
  notes text,
  quantity int, -- yield harvested, animals treated, etc.
  quantity_unit text, -- kg, head, liters, etc.
  cost double precision, -- TZS
  created_at timestamptz default now()
);

create index if not exists activity_logs_zone_id on activity_logs(zone_id);
create index if not exists activity_logs_staff_id on activity_logs(staff_id);
create index if not exists activity_logs_task_id on activity_logs(task_id);
create index if not exists activity_logs_logged_at on activity_logs(logged_at);

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

create index if not exists anomalies_zone_id on anomalies(zone_id);
create index if not exists anomalies_severity on anomalies(severity);
create index if not exists anomalies_detected_at on anomalies(detected_at);

-- Enable RLS on new tables
alter table tasks enable row level security;
alter table activity_logs enable row level security;
alter table anomalies enable row level security;

-- RLS Policies for Tasks
create policy "staff can view assigned tasks" on tasks
  for select using (assigned_staff_id = auth.uid());

create policy "manager can view all tasks" on tasks
  for select using (
    auth.jwt() ->> 'role' = 'manager' or auth.jwt() ->> 'role' = 'owner'
  );

create policy "ai can create tasks" on tasks
  for insert with check (true); -- Allow inserts from AI processes

-- RLS Policies for Activity Logs
create policy "staff can view own logs" on activity_logs
  for select using (staff_id = auth.uid());

create policy "manager can view all logs" on activity_logs
  for select using (
    auth.jwt() ->> 'role' = 'manager' or auth.jwt() ->> 'role' = 'owner'
  );

create policy "staff can insert own logs" on activity_logs
  for insert with check (staff_id = auth.uid());

-- RLS Policies for Anomalies
create policy "manager can view anomalies" on anomalies
  for select using (
    auth.jwt() ->> 'role' = 'manager' or auth.jwt() ->> 'role' = 'owner'
  );

create policy "ai can create anomalies" on anomalies
  for insert with check (true);

-- ===== NEXT STEPS =====
-- 1. Copy all SQL above and paste into your Supabase SQL Editor
-- 2. Click "Run" to create the tables
-- 3. In Flutter, initialize the AIOrchestrator in main.dart
-- 4. Call aiOrchestrator.runDailyOrchestration() periodically (e.g., on app startup)
