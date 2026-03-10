# Interactive Farm Intelligence Engine Specification

Version: 1.0  
Date: 2026-02-28  
Scope: Proactive, map-first farm intelligence system for FarmGenius

## 0) Mission and Operating Principle

The system acts as a **farm command center**, not a passive dashboard. It continuously:
- Observes zones, assets, schedules, checks, incidents, weather, and market signals.
- Detects risk/opportunity early.
- Prompts operators with high-value questions when data is missing.
- Recommends and prioritizes actions with rationale, confidence, and expected impact.
- Learns from accepted/rejected/executed actions and outcomes.

## 1) Interactive Map Interface Design (Primary UI)

### 1.1 Command Map Layout

The map is the home screen for manager/owner users and includes:
- **Zone boundary polygons** for all mapped farm zones.
- **Asset markers/layers** for crops, livestock groups, and infrastructure points.
- **Risk overlay** heat colors by zone (green/yellow/orange/red).
- **Status chips** per zone:
  - Open recommendations
  - Pending questions
  - Latest risk score
  - Last check date
  - Medium-value estimate (TZS)

### 1.2 Layer Controls

Required layer toggles:
- Base map: Satellite / Street.
- Asset class layers: Plot crops / Tree crops / Livestock / Infrastructure.
- Operational overlays: Tasks / Questions / Recommendations / Risk.
- Time filter: Today / 7D / 30D.

### 1.3 Interaction Controls

Required interactions:
- Pan/scroll map
- Pinch and button zoom (+/-)
- Tap zone to open **Zone Command Drawer**
- Tap asset marker to open **Asset Intelligence Card**
- Gesture enable/disable toggle for controlled navigation
- Auto-fit to all active zones

### 1.4 Zone Command Drawer

On zone tap, show:
- Zone profile: name, acreage, zone type, linked assets.
- Live metrics: pending tasks, unresolved anomalies, missing checks.
- Financial snapshot: low/medium/high value scenarios.
- Active recommendations with confidence + urgency.
- Active question queue with due times.
- Immediate action buttons.

## 2) Farm Data Baseline (Verified Input)

### 2.1 Plot Crop Baseline
- **PLOT_12**: 3 acres, bananas, 1,570 trees, TZS 15,000 per bunch, mature/producing.

### 2.2 Permanent Crop Baseline
- Palm: 12
- Apple: 18
- Soursop: 10
- Avocado: 58
- Mango: 231
- Papaya: 13
- Guava: 20
- Tangerine: 56
- Lemon: 78
- Coconut: 50
- Orange: 60

### 2.3 Livestock Baseline
- Poultry mixed: Morogoro chickens 71, guineafowl 9, turkeys 5, geese 3, ducks 24.
- Goats/cattle/rabbits: Gala Isoli goats 15, common goats 30, cattle 2, rabbits 2.

### 2.4 Infrastructure Baseline
- Fence target: 1 km barbed wire + wooden poles (planned).
- Gate locations: pending mapping.
- Water points: pending mapping.

### 2.5 Operational Schedule Baseline
- Time blocks from 05:30-06:00 through 19:00-06:00 as provided.
- High priority livestock rounds at 06:00-08:00 and 17:00-18:00.

## 3) Action Button Framework (Immediate Execution)

Every zone drawer and asset card must expose action buttons with one-tap flows.

### 3.1 Core Buttons
- **Create Task** (assign owner, due block, priority)
- **Start/Complete Task**
- **Log Daily Check**
- **Resolve Alert**
- **Escalate Incident**
- **Open Navigation**
- **Request Missing Data**

### 3.2 Recommendation Buttons
Per recommendation:
- Accept
- Modify
- Defer
- Reject
- Execute now

Each action writes an immutable action log with actor, timestamp, payload, and reason.

## 4) Proactive Question Engine

### 4.1 Trigger Sources
Questions are generated from:
- Missing expected daily checks by zone/time block.
- Livestock count mismatch.
- Production anomaly vs expected baseline.
- Risk threshold crossing (weather, disease, water, security).
- Incomplete asset metadata (location, variety, maturity stage, gate/water mapping).

### 4.2 Question Types
- Yes/No
- Numeric
- Choice/multi-choice
- Free text
- Evidence request (photo/video)

### 4.3 Lifecycle
- queued -> asked -> answered/skipped/escalated/expired

### 4.4 Priority Model
Priority score 1-100 computed from:
- Risk severity
- Financial exposure
- Time sensitivity
- Data criticality

## 5) Intelligent Recommendation Engine

### 5.1 Inputs
- Internal: zones, assets, checks, tasks, anomalies, historical actions/outcomes.
- External: weather forecasts, market signals, and seasonal trend context.

### 5.2 Recommendation Categories
- operations
- crop
- livestock
- infrastructure
- financial
- safety
- biosecurity
- harvest_optimization
- resource_allocation
- predator_prevention
- input_efficiency
- maintenance_prediction

### 5.3 Recommendation Output Contract
Each recommendation includes:
- Recommendation text
- Category
- Confidence (0-1)
- Expected impact (operational + financial)
- Effort score (1-5)
- Expiry time
- Machine rationale JSON

### 5.4 Ranking Function
Priority rank should maximize:

Score = (confidence × impact × urgency) / effort

with governance constraints for safety-critical recommendations.

## 6) Learning and Adaptation Loop

### 6.1 Feedback Signals
- Action taken (accept/modify/reject/defer/execute)
- Execution completion quality
- Outcome score over 1/7/30/90 days
- SLA adherence
- False-positive/false-negative feedback

### 6.2 Model Adaptation Rules
- Increase trigger weight for recommendations with high positive outcomes.
- Decrease confidence for repeatedly rejected recommendation patterns.
- Personalize timing and channel by operator response behavior.
- Detect and suppress repetitive low-value prompts.

### 6.3 Explainability Requirement
Every recommendation and question must show:
- Why this is being asked/recommended.
- Which data points triggered it.
- What happens if ignored.

## 7) Geospatial Intelligence Requirements

### 7.1 Required Geospatial Entities
- Zone polygons
- Asset point markers
- Infrastructure segments (fence/gates/water points)
- Incident and anomaly pins

### 7.2 Geospatial Analytics
- Distance-based alerting (e.g., incidents near vulnerable boundaries).
- Hotspot detection by zone and incident type.
- Coverage analysis for checks and patrol routes.
- Route recommendation for daily rounds and response tasks.

### 7.3 Mapping Gaps to Resolve
- Plot 12 precise boundary verification
- Water points geocoding
- Gate point mapping
- Fence segment map digitization

## 8) Data Model and Services

### 8.1 Core Tables/Views
- profiles
- tasks
- activity_logs
- anomalies
- asset_zones
- biological_assets
- asset_valuations
- daily_asset_checks
- kml_zone_asset_zone_map
- question_queue
- question_responses
- recommendations
- recommendation_actions
- recommendation_outcomes
- zone_risk_snapshots

### 8.2 Service Contracts
- get_map_overview
- get_zone_command_data
- enqueue_zone_questions
- generate_recommendations
- submit_question_response
- act_on_recommendation
- get_trigger_playbook
- get_recommendation_categories

## 9) Risk and Alert Intelligence

### 9.1 Risk Dimensions
- Disease risk
- Water risk
- Execution risk
- Security/theft risk
- Infrastructure risk
- Valuation risk

### 9.2 Alert Rules
- Critical SLA breach in high-priority livestock rounds
- Missing production logs where production is expected
- Sudden mortality or count mismatch
- Weather events exceeding predefined thresholds
- Unchecked high-value zones

### 9.3 Alert Actions
Each critical alert must provide immediate one-tap actions:
- Assign owner
- Set ETA
- Request evidence
- Escalate to manager
- Mark resolved

## 10) Role-Based UX and Security

### 10.1 Manager/Owner
- Full map command center
- Can enqueue questions/generate recommendations
- Can execute recommendation actions
- Can update critical records

### 10.2 Staff
- Task execution and check submission
- Respond to assigned questions
- View relevant zone context
- Restricted write actions by policy

### 10.3 Security
- RLS on all critical tables
- role helpers (`current_user_role`, `is_manager_or_owner`)
- immutable action trails for accountability

## 11) KPI and Success Metrics

### 11.1 Operational KPIs
- Daily check compliance by zone
- Task completion SLA
- Alert response median time
- Question answer latency

### 11.2 Recommendation KPIs
- Acceptance rate
- Execution rate
- Positive outcome rate
- Recommendation precision (low false-positive rate)

### 11.3 Financial KPIs
- Value-at-risk reduction
- Opportunity capture uplift
- Avoidable loss reduction

## 12) Rollout Roadmap

### Phase A: Map Command Baseline
- Full zone rendering, layers, controls, and command drawer.
- Live status chips and key action buttons.

### Phase B: Proactive Questions
- Trigger-driven question queue with lifecycle and SLA handling.

### Phase C: Recommendations + External Signals
- Weather/market-triggered recommendation generation and ranking.

### Phase D: Learning Engine
- Outcome feedback loop and adaptive prioritization.

## 13) Example Daily Intelligent Flow

1. 05:55 pre-round scan identifies missing poultry preparation signal.  
2. Engine asks manager a targeted question and proposes 2 immediate actions.  
3. Manager accepts recommendation, assigns task, sets ETA.  
4. Staff executes and submits evidence.  
5. Outcome score updates recommendation quality profile.  
6. End-of-day map summary shows resolved risks, deferred items, and next-day priorities.

## 14) Non-Functional Requirements

- Dashboard first meaningful paint < 3s on mobile network.
- Map interactions remain smooth at >= 60 FPS target on supported devices.
- Recommendation generation endpoint p95 < 2.5s for single-zone context.
- Full audit log retention and export capability.

## 15) Acceptance Criteria (Go/No-Go)

Go-live requires all to pass:
- All zones and linked assets visible and navigable on map.
- Immediate action buttons execute and persist correctly.
- Question queue triggers and transitions correctly.
- Recommendations generated with rationale and actionable buttons.
- Outcome feedback updates historical recommendation quality.
- Role/RLS behavior verified in manager and staff contexts.
