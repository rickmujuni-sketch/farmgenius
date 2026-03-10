# FarmGenius QA Quick Start (Non-Technical)

Date: 2026-02-28  
Audience: Manual testers and operations leads

## Goal

Validate that the intelligence backend behaves correctly for:
- Manager user (allowed actions)
- Staff user (restricted actions)

## What You Need

- Supabase SQL Editor access
- Two test accounts:
  - `manager_user`
  - `staff_user`
- These scripts available in project:
  - `scripts/FARM_INTELLIGENCE_P0_VERIFICATION.sql`
  - `scripts/FARM_INTELLIGENCE_MANAGER_CONTEXT_QA.sql`
  - `scripts/FARM_INTELLIGENCE_STAFF_CONTEXT_NEGATIVE_QA.sql`

## 10-Minute Test Flow

### 1) Run baseline checks (any context)
Open and run:
- `scripts/FARM_INTELLIGENCE_P0_VERIFICATION.sql`

Pass if:
- No core table/function missing errors
- Trigger/category checks return true

### 2) Test manager behavior
Login as `manager_user`, then run:
- `scripts/FARM_INTELLIGENCE_MANAGER_CONTEXT_QA.sql`

Pass if:
- Manager auth check shows `is_manager_or_owner = true`
- Enqueue and generate recommendation calls succeed
- Lifecycle checks show expected statuses (accepted/modified/deferred/rejected/executed)

### 3) Test staff restrictions
Login as `staff_user`, then run:
- `scripts/FARM_INTELLIGENCE_STAFF_CONTEXT_NEGATIVE_QA.sql`

Pass if:
- Staff auth check shows `is_manager_or_owner = false`
- Read checks succeed
- Manager-only operations fail with expected authorization errors (when commented tests are executed)

## Expected Error Messages (Staff)

- `Only manager/owner can enqueue questions`
- `Only manager/owner can generate recommendations`

## Quick Pass/Fail Rule

Mark **PASS** only if:
1. Baseline script passes
2. Manager script succeeds for manager-only actions
3. Staff script blocks manager-only actions

Otherwise mark **FAIL** and capture:
- Script name
- SQL line/step
- Error text
- Screenshot

## Where to Report Results

Use the runbook template in:
- `FARM_INTELLIGENCE_QA_RUNBOOK.md`

and the detailed matrix in:
- `FARM_INTELLIGENCE_QA_MATRIX.md`
