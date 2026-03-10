# FarmGenius QA Runbook (Master Runner Checklist)

Version: 1.0  
Date: 2026-02-28

## Purpose

Single checklist for QA to validate backend intelligence behavior by role, with expected outcomes and sign-off criteria.

## Scripts Covered

1. `scripts/FARM_INTELLIGENCE_P0_VERIFICATION.sql`
2. `scripts/FARM_INTELLIGENCE_MANAGER_CONTEXT_QA.sql`
3. `scripts/FARM_INTELLIGENCE_STAFF_CONTEXT_NEGATIVE_QA.sql`

## Prerequisites

- Database migrations applied in order:
  1. `SUPABASE_SETUP.sql`
  2. `SUPABASE_ASSET_TRACKING.sql`
  3. `SUPABASE_FARM_INTELLIGENCE_ENGINE.sql`
- Seed data present for trigger templates and recommendation categories
- Test users available:
  - `manager_user` (role = manager or owner)
  - `staff_user` (role = staff)
- At least one `asset_zones` row exists

## Execution Order (Required)

### Step 1 — Baseline P0 checks (neutral context)
Run:
- `scripts/FARM_INTELLIGENCE_P0_VERIFICATION.sql`

Expected:
- Object existence checks: PASS
- RPC existence checks: PASS
- Trigger/category seed counts meet minimums
- Valid category insert test passes and is rolled back
- No destructive data changes

Fail conditions:
- Any missing core table/function
- Seed counts below expected thresholds

---

### Step 2 — Manager-context executable flow
Login as `manager_user` and run:
- `scripts/FARM_INTELLIGENCE_MANAGER_CONTEXT_QA.sql`

Expected:
- Auth sanity: `is_manager_or_owner = true`
- `get_map_overview`, `get_trigger_playbook`, `get_recommendation_categories` succeed
- `enqueue_zone_questions` succeeds
- `generate_recommendations` succeeds
- Recommendation lifecycle transitions succeed:
  - accept -> accepted
  - modify -> modified
  - defer -> deferred
  - reject -> rejected
  - execute -> executed
- Lifecycle test data rolled back

Fail conditions:
- Any manager-only RPC denied
- Any lifecycle transition mismatch
- Missing action trail entries

---

### Step 3 — Staff-context negative security tests
Login as `staff_user` and run:
- `scripts/FARM_INTELLIGENCE_STAFF_CONTEXT_NEGATIVE_QA.sql`

Expected:
- Auth sanity: `is_manager_or_owner = false`
- Allowed reads succeed:
  - `get_map_overview`
  - `get_trigger_playbook`
  - `get_recommendation_categories`
- Manager-only operations fail (when uncommented and executed):
  - `enqueue_zone_questions` -> error `Only manager/owner can enqueue questions`
  - `generate_recommendations` -> error `Only manager/owner can generate recommendations`
- Direct restricted writes fail due to RLS/policy (when uncommented and executed)

Fail conditions:
- Staff can execute manager-only RPCs
- Staff can write manager-only resources

## Optional Validation Add-ons

- Invalid action check (`act_on_recommendation` with unsupported action) returns validation error
- Cross-check UI zone metrics against `get_zone_command_data`
- Compare map chips with `get_map_overview` values

## Role-to-Expected Behavior Matrix

| Capability | Manager/Owner | Staff |
|---|---|---|
| Read map overview | Allow | Allow |
| Read trigger playbooks | Allow | Allow |
| Read recommendation categories | Allow | Allow |
| Enqueue zone questions | Allow | Deny |
| Generate recommendations | Allow | Deny |
| Direct write trigger/category templates | Allow | Deny |
| Act on recommendations | Allow (when authorized) | Depends on policy + record visibility |

## Defect Logging Template

- Defect ID:
- Script:
- Step:
- Role context:
- Expected result:
- Actual result:
- Error text:
- Screenshot/log reference:
- Severity: P0 / P1 / P2

## Release Gate Criteria

Release is **GO** only if all are true:

1. P0 verification script passes baseline checks.
2. Manager-context script passes all executable checks.
3. Staff-context negative tests confirm denials for protected operations.
4. No P0 security or data integrity defects remain open.

Otherwise: **NO-GO**.
