# FarmGenius Proactive Intelligence System Specification

Version: 1.0  
Date: 2026-02-28

## 1) System Purpose

FarmGenius should operate as a proactive farm command engine, not just a dashboard. The system continuously monitors zone activity, assets, staff execution, infrastructure status, weather, and market signals to:

- Detect risk and opportunity early
- Ask context-aware follow-up questions
- Recommend high-impact actions with rationale
- Track user actions and outcomes over time

## 2) Functional Scope

### Core Capabilities

1. Map-first zone command center
- Live zone overview: pending questions, open recommendations, latest risk, last check date, value estimate
- Zone drill-down with operational and financial context

2. Proactive question engine
- Trigger-based question generation
- Queue lifecycle: queued, asked, answered, skipped, escalated, expired
- Staff/manager response capture and auditability

3. Recommendation engine
- Explainable recommendations with confidence, expected impact, and effort
- Action lifecycle: proposed, accepted, modified, rejected, deferred, executed, expired
- Outcome scoring over 1/7/30/90 day windows

4. Playbook layer
- Trigger templates (question/follow-up/options/recommendation/action arrays)
- Recommendation category templates (logic + example)

## 3) Implemented Data and Logic Baseline

### Trigger Playbooks Included

- new_asset_added
- no_egg_record_24h
- weather_forecast_heavy_rain
- market_price_spike_mangoes
- low_water_pressure_detected
- livestock_count_mismatch
- seasonal_pattern_avocado

### Recommendation Categories Included

- harvest_optimization
- resource_allocation
- predator_prevention
- input_efficiency
- maintenance_prediction

### Core Engine Interfaces

- get_map_overview
- get_zone_command_data
- enqueue_zone_questions
- generate_recommendations
- submit_question_response
- act_on_recommendation
- get_trigger_playbook
- get_recommendation_categories

## 4) Sample 24-Hour Interaction Log

- 05:45 — Daily startup scan identifies 2 zones needing attention before 09:00.
- 06:05 — Trigger: no_egg_record_24h. System asks manager to choose one action.
- 06:20 — Reminder dispatched to poultry lead; follow-up scheduled.
- 07:10 — Trigger: low_water_pressure_detected in Plot 12. Manager switches to backup.
- 08:05 — Verification confirms irrigation stress risk reduced.
- 09:30 — Trigger: weather_forecast_heavy_rain; manager accepts drainage and harvest prep actions.
- 11:40 — Trigger: new_asset_added for apple trees; manager supplies date, zone, variety, schedule preference.
- 13:15 — Recommendation: resource_allocation to recover weeding backlog; manager accepts.
- 16:10 — Trigger: livestock_count_mismatch; manager initiates fence check, zone search, and gate log review.
- 18:05 — Incident resolved; temporary fence fix complete; permanent repair scheduled.
- 20:30 — Market signal: mango price spike; manager accepts transport and sales prioritization actions.
- 21:45 — End-of-day summary: interventions, acceptance ratio, deferred items, and estimated risk reduction.

## 5) What-If Intelligence Scenarios

### Scenario A: Disease outbreak detected

Detection signals
- Abnormal mortality trend
- Rapid symptom reports
- Feed/water behavior anomalies

System response
- Raise critical zone alert and isolate affected zone
- Generate containment checklist and biosecurity tasks
- Trigger urgent triage questions and vet escalation
- Restrict movement recommendations until clearance

Success condition
- Spread contained within 24 hours and trend stabilized

### Scenario B: Major price drop forecast

Detection signals
- Market feed predicts more than 15% drop in next 72 hours
- Harvest-ready crop inventory concentrated in exposed zones

System response
- Re-rank harvest strategy by margin risk
- Propose staged sale and alternate channels
- Simulate revenue impact of each option

Success condition
- Realized revenue decline remains below defined threshold

### Scenario C: Staff do not complete assigned tasks

Detection signals
- SLA misses and repeated overdue tasks
- Zone-level backlog concentration

System response
- Escalate to team lead with root-cause prompts
- Propose labor reallocation and task slicing
- Create checkpoint reminders and next-day plan adjustments

Success condition
- Completion rate returns to target within 48 hours

## 6) MVP Roadmap with Acceptance Tests

### Phase 1: Basic map + zone dashboards

Scope
- Interactive map and zone cards
- Zone-level metrics and status chips
- Basic recommendation/question visibility

Acceptance tests
- AT1: Manager can open map and view all zones with status in one screen.
- AT2: Zone drill-down loads recommendations, questions, risk, and value without error.
- AT3: Dashboard refresh reflects latest changes within agreed refresh interval.

### Phase 2: Proactive questions

Scope
- Trigger template retrieval and queueing
- Question lifecycle management
- Response capture and assignment

Acceptance tests
- AT1: Trigger event creates correctly structured question entry.
- AT2: Manager/staff can answer; state transitions to answered.
- AT3: Escalation applies when due time is exceeded.

### Phase 3: External data integration

Scope
- Weather feed integration
- Market feed integration
- Sensor/infrastructure telemetry ingestion

Acceptance tests
- AT1: Weather and market events are ingested and visible in decision context.
- AT2: External signal generates at least one valid recommendation under test scenario.
- AT3: Feed outage is detected and surfaced with degraded-mode behavior.

### Phase 4: Predictive recommendations

Scope
- Category-aware recommendation scoring
- Outcome tracking feedback loop
- Prioritization by confidence x impact x urgency

Acceptance tests
- AT1: Engine generates category-specific recommendation with rationale payload.
- AT2: Accepted recommendations produce measurable outcomes in 7/30 day windows.
- AT3: Recommendation ranking improves against baseline acceptance and outcome metrics.

## 7) Success Metrics

Adoption
- Daily active manager rate
- Proactive prompt response rate

Operational
- Daily check compliance rate
- Task completion SLA
- Median critical incident response time

Recommendation quality
- Recommendation acceptance rate
- Positive outcome rate after action execution
- False alert rate

Financial
- Avoidable loss reduction versus baseline
- Opportunity capture rate for market-driven recommendations

Data quality
- Fresh data coverage by zone
- Missing-data incident count

## 8) Data Privacy and Security Considerations

Access and authorization
- Role-based access control with row-level security
- Manager/owner-gated write operations for high-impact entities
- Explicit system-context checks for automation workflows

Data protection
- Encryption in transit and at rest
- Token/session validation and rotation controls
- Principle of least privilege for service integrations

Auditability and governance
- Immutable action logs for questions, recommendations, and outcomes
- Structured retention policy by data class
- Controlled archival and deletion workflow

Privacy practices
- Collect only operationally necessary data
- Minimize personally identifiable information
- Provide traceable user activity exports for oversight

Incident response
- Detect, contain, remediate, and report workflow
- Priority handling for critical operational and security incidents

## 9) Delivery Notes

- This specification aligns with the current SQL engine structure and seeded playbooks.
- Next implementation step is to connect trigger and category playbooks to live recommendation generation in the app workflow.
