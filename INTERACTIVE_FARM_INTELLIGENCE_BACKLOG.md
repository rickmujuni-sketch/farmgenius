# Interactive Farm Intelligence Engine Backlog

Version: 1.0  
Date: 2026-02-28  
Derived from: INTERACTIVE_FARM_INTELLIGENCE_ENGINE_SPEC.md

## 1) Delivery Milestones

- **M1 (Weeks 1-2): Map Command Center Foundation**
  - Zone boundary rendering, marker layers, map controls, zone drawer shell.
- **M2 (Weeks 3-4): Action Workflows + Daily Operations**
  - Task/check/alert action buttons and persistence.
- **M3 (Weeks 5-6): Proactive Question Engine**
  - Triggering, lifecycle, assignment, and response flows.
- **M4 (Weeks 7-8): Recommendation Engine v1**
  - Rule-based generation + ranking + action lifecycle.
- **M5 (Weeks 9-10): Learning Loop + External Signals**
  - Outcome feedback, adaptation, weather/market integration.
- **M6 (Weeks 11-12): Hardening + Go-Live**
  - Security, performance, QA, observability, and rollout.

## 2) Epic Breakdown

## EPIC A — Map Command Center

**Goal**: Make the map the operational command interface for all zones and assets.

### A-1 Zone Boundary & Layer Rendering
- [ ] Render all zones with accurate polygons and labels.
- [ ] Add layer toggles for crops, livestock, infrastructure, tasks, questions, recommendations.
- [ ] Show risk color overlay by zone.

**Acceptance Criteria**
- All zones visible with boundaries and names.
- Layer visibility toggles update map without reload.
- Risk overlays match latest snapshot values.

### A-2 Map Controls and Navigation
- [ ] Satellite/Street toggle.
- [ ] Zoom +/- buttons and pinch zoom.
- [ ] Pan/scroll gestures with enable/disable switch.
- [ ] Auto-fit to all active zones.

**Acceptance Criteria**
- Controls work consistently on iOS and Android.
- Preferences persist across app restarts.

### A-3 Zone Command Drawer
- [ ] Zone profile and metrics panel.
- [ ] Open recommendations/questions list.
- [ ] Quick actions from drawer.

**Acceptance Criteria**
- Tap zone opens drawer within 300ms.
- Drawer data matches backend contracts (`get_zone_command_data`).

---

## EPIC B — Action Execution Framework

**Goal**: Convert insights into immediate, traceable action.

### B-1 Task Action Buttons
- [ ] Create Task (owner, priority, due block).
- [ ] Start/Complete/Cancel task actions.
- [ ] In-map task status indicators.

### B-2 Alert and Incident Actions
- [ ] Resolve alert.
- [ ] Escalate incident.
- [ ] Request evidence.

### B-3 Check and Navigation Actions
- [ ] Log daily check from map.
- [ ] Open external navigation for selected zone.

**Acceptance Criteria**
- Every button writes to correct table with actor + timestamp.
- Errors are surfaced with actionable messages.

---

## EPIC C — Proactive Question Engine

**Goal**: Detect missing or risky context and ask high-value questions automatically.

### C-1 Trigger Builder
- [ ] Implement trigger rules for:
  - missing checks,
  - livestock mismatch,
  - production anomalies,
  - infrastructure mapping gaps,
  - risk threshold crossings.

### C-2 Queue Lifecycle
- [ ] Implement status transitions: queued -> asked -> answered/skipped/escalated/expired.
- [ ] Due-time and escalation scheduler behavior.

### C-3 Operator Response UX
- [ ] Question inbox by role.
- [ ] Typed responses (yes/no, numeric, text, choice, evidence).

**Acceptance Criteria**
- Trigger firing is idempotent for duplicate events.
- Lifecycle transitions are auditable.

---

## EPIC D — Recommendation Engine v1

**Goal**: Produce explainable, ranked recommendations with immediate actions.

### D-1 Recommendation Generation
- [ ] Rule engine categories: operations, crop, livestock, infrastructure, financial, safety, biosecurity.
- [ ] Extended categories: harvest_optimization, resource_allocation, predator_prevention, input_efficiency, maintenance_prediction.

### D-2 Ranking & Expiry
- [ ] Implement ranking function `(confidence × impact × urgency) / effort`.
- [ ] Enforce expiry and stale recommendation suppression.

### D-3 Recommendation Action Lifecycle
- [ ] Accept / Modify / Defer / Reject / Execute.
- [ ] Action trail insertion with payload details.

**Acceptance Criteria**
- Recommendation includes rationale + confidence + expected impact.
- Action updates status and writes audit trail correctly.

---

## EPIC E — Learning & Adaptive Intelligence

**Goal**: Improve recommendation quality over time via outcomes and operator behavior.

### E-1 Outcome Feedback Capture
- [ ] Capture 1/7/30/90-day outcome records.
- [ ] Track operational and financial result metrics.

### E-2 Adaptation Rules
- [ ] Increase/decrease trigger/recommendation weights based on outcome score and rejection patterns.
- [ ] De-duplicate repetitive low-value prompts.

### E-3 Explainability Layer
- [ ] Show trigger evidence and “why now” explanation in UI.

**Acceptance Criteria**
- Outcome data changes future recommendation ordering.
- Explainability present for 100% of surfaced recommendations/questions.

---

## EPIC F — External Signal Integration

**Goal**: Use weather and market signals to improve proactive decisions.

### F-1 Weather Ingestion
- [ ] Forecast pull + normalization.
- [ ] Weather risk triggers by zone/crop/livestock context.

### F-2 Market Ingestion
- [ ] Commodity price signal ingestion.
- [ ] Price-aware recommendation generation for harvest timing.

### F-3 Degraded Mode
- [ ] Detect feed outage and clearly flag stale external data.

**Acceptance Criteria**
- External signals generate at least one valid recommendation under test scenarios.
- Feed outages do not break core app operations.

---

## EPIC G — Geospatial Data Completion

**Goal**: Close mapping gaps for infrastructure and precise operational intelligence.

### G-1 Plot and Asset Mapping Completion
- [ ] Verify Plot 12 precision boundaries.
- [ ] Map water points.
- [ ] Map gates.
- [ ] Digitize fence segments.

### G-2 Geospatial Analytics
- [ ] Incident hotspot map.
- [ ] Distance-based risk proximity checks.
- [ ] Daily round route hints.

**Acceptance Criteria**
- Missing critical geospatial entities reduced to zero.
- Analytics overlays match underlying event data.

---

## EPIC H — Security, Observability, and Readiness

**Goal**: Make the system production-safe and diagnosable.

### H-1 Access and RLS Validation
- [ ] Role policy QA in manager/staff contexts.
- [ ] Manager-only write path verification.

### H-2 Telemetry and Monitoring
- [ ] Event logs for trigger firing, recommendation generation, and action execution.
- [ ] Error-rate and latency dashboards.

### H-3 Release Hardening
- [ ] Performance profiling for map + dashboard.
- [ ] Regression suite and release checklist.

**Acceptance Criteria**
- No P0 auth/data integrity defects.
- p95 map/drawer interactions meet target thresholds.

## 3) Ticket-Ready Story Set (Initial 24 Stories)

## Sprint 1 (M1)
1. Render inferred zone polygons on map.  
2. Add map base style toggle (satellite/street).  
3. Implement zoom +/- controls and current zoom indicator.  
4. Add gesture enable/disable toggle with persistence.  
5. Build layer toggle panel scaffold.  
6. Open zone drawer on polygon tap.

## Sprint 2 (M1-M2)
7. Show zone command metrics from `get_zone_command_data`.  
8. Add create/start/complete/cancel task actions in drawer.  
9. Add resolve anomaly action with audit notes.  
10. Add open-in-maps for zone navigation.  
11. Add daily check create/update from map context.  
12. Add action confirmation + snackbar error handling.

## Sprint 3 (M2-M3)
13. Implement trigger job for missing daily checks.  
14. Implement trigger job for livestock count mismatch.  
15. Build question queue list UI by role.  
16. Add question response form types and submit flow.

## Sprint 4 (M3-M4)
17. Implement recommendation generation service by category.  
18. Implement recommendation ranking and expiry logic.  
19. Build recommendation cards with explainability panel.  
20. Add recommendation actions (accept/modify/defer/reject/execute).

## Sprint 5 (M4-M5)
21. Capture recommendation outcomes (1/7/30/90).  
22. Implement adaptive weights from outcome feedback.  
23. Integrate weather signal ingestion and triggers.  
24. Integrate market signal ingestion and recommendation rules.

## 4) Priority Labels

- **P0**: Must-have for command-center viability and data safety.
- **P1**: Strong value, can ship in next increment.
- **P2**: Optimization and enhancement.

Suggested assignment:
- Epics A/B/C/D/H: mostly P0/P1
- Epics E/F/G: mostly P1/P2 (except mapping criticals as P0)

## 5) Dependency Map

- A -> B -> C -> D -> E
- A + G -> stronger D/F quality
- H runs continuously across all milestones

## 6) Definition of Done (Per Story)

A story is done only when:
- Implementation merged.
- QA scenario executed and pass evidence captured.
- RLS/role behavior verified if data write involved.
- Logging/telemetry added for trigger/recommendation/action flows.
- Documentation updated (spec/backlog/QA notes as relevant).

## 7) Release Gate Checklist

- [ ] All P0 stories in current milestone complete.
- [ ] No open P0 defects.
- [ ] Manager and staff role QA scripts pass.
- [ ] Recommendation/action audit trails verified.
- [ ] Performance and crash-free thresholds met.

## 8) Suggested GitHub Issue Template

Title: `[EPIC-X][Story] Short actionable title`

Body:
- Context
- User Story
- Scope (In)
- Scope (Out)
- Acceptance Criteria
- API/Data changes
- QA Steps
- Risks
- Rollback Plan
- Links to spec/backlog items

## 9) Immediate Next 3 Execution Tickets

1. **[P0] Zone Command Drawer v1**  
   Implement live zone metrics + quick actions in map drawer.

2. **[P0] Question Queue Trigger: Missing Checks**  
   Auto-create high-priority question when expected checks are missing.

3. **[P0] Recommendation Action Lifecycle UI**  
   Enable full accept/modify/defer/reject/execute interaction from manager dashboard.
