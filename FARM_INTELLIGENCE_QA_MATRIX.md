# FarmGenius QA Test Matrix

Version: 1.0  
Date: 2026-02-28  
Scope: MVP Phases 1-4 for proactive farm intelligence

## Test Execution Rules

- Status values: Not Started, In Progress, Pass, Fail, Blocked
- Priority values: P0 (critical), P1 (high), P2 (medium)
- Evidence required for Pass: screenshot/log query/output + tester notes
- Any P0 failure blocks phase sign-off

## Environment Matrix

- App: Flutter mobile app (iOS simulator + Android emulator/device)
- Backend: Supabase (auth, RLS, RPC, Postgres)
- Data: Seeded trigger templates + recommendation categories
- Accounts:
  - Manager account
  - Staff account
  - Unauthenticated session

## Phase 1: Basic Map + Zone Dashboards

### P1-AT1 Map overview renders all zones
- ID: P1-AT1
- Priority: P0
- Preconditions:
  - Authenticated manager user
  - At least 3 zones exist
- Steps:
  1. Open app and navigate to zones map tab.
  2. Wait for map overview load.
  3. Count visible zone entries/chips.
- Expected Result:
  - All zones from data source are displayed.
  - No crash, layout overflow, or blank state unless data truly empty.
- Evidence:
  - Screenshot of full zone list/map + timestamp

### P1-AT2 Zone drill-down metrics integrity
- ID: P1-AT2
- Priority: P0
- Preconditions:
  - Zone has at least one check/recommendation/question history
- Steps:
  1. Open a zone detail panel.
  2. Compare displayed values with RPC output from get_zone_command_data.
- Expected Result:
  - UI values match RPC fields:
    - open_recommendations
    - pending_questions
    - last_check_date
    - latest_risk
    - medium_value
- Evidence:
  - Screenshot + SQL/RPC output

### P1-AT3 Map overview RPC consistency
- ID: P1-AT3
- Priority: P1
- Preconditions:
  - Authenticated manager
- Steps:
  1. Call get_map_overview.
  2. Refresh map screen.
  3. Compare zone-level values in UI and RPC result.
- Expected Result:
  - Values are consistent with no stale mismatches beyond refresh window.
- Evidence:
  - RPC response capture + screenshot

### P1-AT4 Role gating for unauthenticated user
- ID: P1-AT4
- Priority: P0
- Preconditions:
  - Logged out state
- Steps:
  1. Try to access map and zone details.
- Expected Result:
  - Access denied or redirect to login.
  - No sensitive data shown.
- Evidence:
  - Screenshot/video

## Phase 2: Proactive Questions

### P2-AT1 Trigger playbook retrieval
- ID: P2-AT1
- Priority: P0
- Preconditions:
  - Trigger templates seeded
- Steps:
  1. Call get_trigger_playbook for new_asset_added.
  2. Verify question and follow-up arrays.
- Expected Result:
  - Correct trigger payload is returned with active template only.
- Evidence:
  - Query output

### P2-AT2 Question enqueue authorization
- ID: P2-AT2
- Priority: P0
- Preconditions:
  - Manager session and staff session available
- Steps:
  1. As manager, call enqueue_zone_questions.
  2. As staff, call enqueue_zone_questions.
- Expected Result:
  - Manager call succeeds.
  - Staff call is blocked by authorization rule.
- Evidence:
  - Both outputs and error messages

### P2-AT3 Question response lifecycle
- ID: P2-AT3
- Priority: P0
- Preconditions:
  - At least one queued question exists
- Steps:
  1. Submit response using submit_question_response.
  2. Read question status.
- Expected Result:
  - Response row created.
  - Question status becomes answered.
- Evidence:
  - question_responses row + question_queue status snapshot

### P2-AT4 Escalation/expiry handling
- ID: P2-AT4
- Priority: P1
- Preconditions:
  - Question due_at set in near future
- Steps:
  1. Let due time pass without response.
  2. Run scheduler/escalation flow.
- Expected Result:
  - Question transitions to escalated or expired per policy.
- Evidence:
  - Before/after status logs

## Phase 3: External Data Integration

### P3-AT1 Weather trigger to recommendation
- ID: P3-AT1
- Priority: P0
- Preconditions:
  - Weather feed integration active or mocked heavy-rain signal
- Steps:
  1. Inject heavy rain forecast event.
  2. Run recommendation generation.
- Expected Result:
  - Relevant recommendations created (drainage, harvest rescheduling, spraying delay).
- Evidence:
  - recommendations rows + rationale payload

### P3-AT2 Market signal recommendation generation
- ID: P3-AT2
- Priority: P1
- Preconditions:
  - Market price input available/mocked
- Steps:
  1. Inject price spike and separately a price drop scenario.
  2. Evaluate generated recommendations.
- Expected Result:
  - Price-sensitive recommendations created with financial rationale.
- Evidence:
  - recommendations payload snapshots

### P3-AT3 Feed outage degraded mode
- ID: P3-AT3
- Priority: P0
- Preconditions:
  - Ability to disable weather/market feed
- Steps:
  1. Simulate external feed outage.
  2. Observe system behavior.
- Expected Result:
  - System remains operational with graceful degradation.
  - Explicit stale-data warning appears.
- Evidence:
  - App screenshot + logs

## Phase 4: Predictive Recommendations

### P4-AT1 Category eligibility validation
- ID: P4-AT1
- Priority: P0
- Preconditions:
  - recommendation categories seeded
- Steps:
  1. Insert recommendations using new categories:
     - harvest_optimization
     - resource_allocation
     - predator_prevention
     - input_efficiency
     - maintenance_prediction
  2. Attempt insert with invalid category string.
- Expected Result:
  - Valid categories succeed.
  - Invalid category fails with constraint error.
- Evidence:
  - SQL outputs

### P4-AT2 Category playbook retrieval
- ID: P4-AT2
- Priority: P1
- Preconditions:
  - Authenticated manager
- Steps:
  1. Call get_recommendation_categories.
  2. Validate returned logic and example text.
- Expected Result:
  - Only active categories returned with expected fields.
- Evidence:
  - Query output

### P4-AT3 Recommendation action lifecycle
- ID: P4-AT3
- Priority: P0
- Preconditions:
  - At least one proposed recommendation exists
- Steps:
  1. Run act_on_recommendation with accept/modify/reject/defer/execute.
  2. Verify recommendation_actions insertion and recommendation status update.
- Expected Result:
  - Each action maps to correct status.
  - Invalid action is rejected.
- Evidence:
  - Table snapshots + error case output

### P4-AT4 Outcome feedback signal
- ID: P4-AT4
- Priority: P1
- Preconditions:
  - recommendation_outcomes tracking enabled
- Steps:
  1. Insert outcome for executed recommendation.
  2. Confirm score and metrics available for analytics.
- Expected Result:
  - Outcome data persists with valid window_days and score bounds.
- Evidence:
  - recommendation_outcomes row capture

## Security and Privacy Validation

### SEC-1 RLS read protection
- ID: SEC-1
- Priority: P0
- Steps:
  1. Query protected tables as unauthenticated user.
- Expected Result:
  - Access denied or zero visibility per policy.

### SEC-2 Manager-only writes
- ID: SEC-2
- Priority: P0
- Steps:
  1. Attempt writes from staff for manager-only tables.
- Expected Result:
  - Write blocked by policy.

### SEC-3 System context safety
- ID: SEC-3
- Priority: P0
- Steps:
  1. Execute guarded RPCs in system context and user context.
- Expected Result:
  - System context allowed where intended.
  - Non-manager user context denied for protected operations.

### SEC-4 Audit traceability
- ID: SEC-4
- Priority: P1
- Steps:
  1. Execute recommendation and question actions.
  2. Verify action trail completeness.
- Expected Result:
  - Actor, action, timestamp, and payload are captured.

## Regression Pack (Run Every Release)

- RP-1: get_map_overview returns without errors
- RP-2: get_zone_command_data matches UI values
- RP-3: get_trigger_playbook returns active template only
- RP-4: get_recommendation_categories returns all active categories
- RP-5: enqueue_zone_questions authorization behavior unchanged
- RP-6: generate_recommendations authorization behavior unchanged
- RP-7: submit_question_response updates question status
- RP-8: act_on_recommendation updates status and logs action

## Phase Exit Criteria

Phase 1 exit
- All P0 tests in Phase 1 = Pass

Phase 2 exit
- All P0 tests in Phase 2 + SEC-1/SEC-2 = Pass

Phase 3 exit
- All P0 tests in Phase 3 + RP pack = Pass

Phase 4 exit
- All P0 tests in Phase 4 + SEC-3 + SEC-4 = Pass

## Test Run Template

- Build/Version:
- Environment:
- Tester:
- Date:
- Total Cases:
- Passed:
- Failed:
- Blocked:
- Key Defects:
- Go/No-Go Recommendation:
