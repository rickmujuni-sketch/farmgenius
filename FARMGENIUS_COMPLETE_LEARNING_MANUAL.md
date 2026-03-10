# 📘 FarmGenius Complete Learning Manual

## 1) Purpose of This Manual

This is the **single end-to-end learning guide** for FarmGenius.
It is designed for:
- New users learning how the app works
- Team leads onboarding staff and managers
- Developers maintaining or extending the system

You can use this document as a **practical handbook** with demonstrations, test commands, and expected results.

---

## 2) What FarmGenius Does (Current Build)

FarmGenius is a Flutter + Supabase farm operations platform with role-based dashboards:
- **Owner Dashboard**: financial oversight, operations-readiness insights, daily/weekly/monthly report generation (WhatsApp, CSV, PDF)
- **Manager Dashboard**: task/anomaly/zone monitoring, AI briefings, payroll intelligence, auto-escalation workflows
- **Staff Dashboard**: assigned tasks, execute-with-evidence workflow (GPS + photos + notes), accountability metrics, daily biological asset checks

Core capabilities in this build:
1. Email/password signup and login
2. Phone OTP flow support
3. Role-based routing (`owner`, `manager`, `staff`)
4. Supabase-backed operational data
5. Strict RLS policy support for production
6. Localization (English + Swahili), with Swahili default on staff dashboard
7. Multi-period reporting and share/export features for owners

---

## 3) High-Level Architecture

### Client Layer (Flutter)
- Entry: `lib/main.dart`
- Screens: `lib/screens/*`
- State/services: `Provider` + service classes in `lib/services/*`
- Models: `lib/models/*`

### Backend Layer (Supabase)
- Auth: Supabase Auth
- Data tables + policies: SQL scripts in root
  - `SUPABASE_SETUP.sql`
  - `SUPABASE_RLS_PRODUCTION.sql`

### Operational Intelligence Layer
- `AIOrchestrator` runs daily orchestration for owner/manager contexts
- Manager and staff dashboards consume orchestration output and logs
- Owner dashboard combines financial + operations assist snapshots for reporting

---

## 4) Project Structure (Most Important Files)

### App bootstrap and routing
- `lib/main.dart`
- Route force flag: `--dart-define=FORCE_HOME_ROUTE=owner|manager|staff`

### Authentication and session
- `lib/services/auth_service.dart`
- `lib/services/supabase_service.dart`

### Role dashboards
- `lib/screens/owner_home.dart`
- `lib/screens/manager_home_v2.dart` (exported through `manager_home.dart`)
- `lib/screens/staff_home.dart`

### Reporting
- `lib/services/monthly_report_service.dart` (daily/weekly/monthly builders)
- `lib/services/report_export_service.dart` (PDF export/share)
- `lib/models/monthly_report.dart` (period report document model)

### Localization
- `lib/services/localization_service.dart`

### Database setup and hardening
- `SUPABASE_SETUP.sql`
- `SUPABASE_RLS_PRODUCTION.sql`

### Assets
- `assets/farm_data/*.kml`

---

## 5) Setup Guide (From Zero)

### Prerequisites
- Flutter SDK
- Xcode + iOS Simulator (for macOS iOS testing)
- Supabase project (URL + anon key)

### Install dependencies
```bash
cd /Users/patrickmujuni/farmgenius
flutter pub get
```

### Configure Supabase connection
Run app with environment definitions:
```bash
flutter run \
  --dart-define=SUPABASE_URL="https://YOUR_PROJECT.supabase.co" \
  --dart-define=SUPABASE_ANON_KEY="YOUR_ANON_KEY"
```

### Apply database schema
1. Open Supabase SQL Editor
2. Run `SUPABASE_SETUP.sql`
3. For strict production rules, run `SUPABASE_RLS_PRODUCTION.sql`

---

## 6) How Users Move Through the App

### Welcome → Auth → Role Dashboard
1. User lands on welcome screen (`/`)
2. Chooses email login, phone login, signup, or reset
3. Auth session resolves role
4. User is routed to:
   - `/owner`
   - `/manager`
   - `/staff`

### Testing route-specific views quickly
Use forced home route:
```bash
flutter run --dart-define=FORCE_HOME_ROUTE=owner
flutter run --dart-define=FORCE_HOME_ROUTE=manager
flutter run --dart-define=FORCE_HOME_ROUTE=staff
```

---

## 7) Practical Demonstrations (Hands-On)

### Demo A: Authentication and Role Access
**Goal:** Verify auth and role-specific dashboard behavior.

### Steps
1. Run app from fresh session
2. Create accounts for Owner, Manager, and Staff
3. Log in with each account
4. Confirm dashboard changes by role

### Expected result
- Owner sees finance + reports + operations assist
- Manager sees operational tabs and briefing/escalation insights
- Staff sees assigned tasks + execution/evidence workflows

---

### Demo B: Staff Execution with Evidence
**Goal:** Validate accountability and field-execution capture.

### Steps
1. Open staff route:
   ```bash
   flutter run --dart-define=FORCE_HOME_ROUTE=staff
   ```
2. Open an assigned task
3. Mark in-progress / execute flow
4. Capture GPS check-in
5. Add execution notes, optional issue details, and photo URLs
6. Submit execution report

### Expected result
- Task state advances
- Evidence appears in activity log context
- Staff accountability cards update from logged effort/evidence

---

### Demo C: Manager Operational Oversight
**Goal:** Validate manager control loop and auto-escalation context.

### Steps
1. Open manager route:
   ```bash
   flutter run --dart-define=FORCE_HOME_ROUTE=manager
   ```
2. Review task/anomaly/zones/payroll/briefing tabs
3. Trigger refresh and observe briefing digest
4. Validate escalation settings (overdue and evidence thresholds)
5. Confirm manager actions like approval/rework where applicable

### Expected result
- Daily digest includes priority actions and follow-up prompts
- Escalation candidates are surfaced into anomalies/digest cards
- Zone and payroll operational view is available for management decisions

---

### Demo D: Owner Reporting + Sharing
**Goal:** Validate report generation and distribution pipeline.

### Steps
1. Open owner route:
   ```bash
   flutter run --dart-define=FORCE_HOME_ROUTE=owner
   ```
2. In report generator section, generate:
   - Daily report
   - Weekly report
   - Monthly report
3. For each report test actions:
   - Preview
   - Share to WhatsApp
   - Copy CSV
   - Export/share PDF

### Expected result
- Reports include KPI metrics + highlights + generated message
- WhatsApp opens with prefilled text (or fallback handling)
- CSV copied to clipboard
- PDF export/share succeeds from temporary storage

---

### Demo E: Localization Behavior
**Goal:** Validate language experience with staff-first Swahili default.

### Steps
1. Launch staff route
2. Confirm language defaults to Swahili on staff dashboard
3. Navigate to owner/manager and verify standard localization behavior

### Expected result
- Staff dashboard loads in Swahili by default
- Global localization remains switchable through localization service

---

## 8) Reporting System Explained

FarmGenius now supports **period-based reports** using one document model:
- Daily (`buildDaily`)
- Weekly (`buildWeekly`)
- Monthly (`buildMonthly`)

Each report includes:
- Period metadata
- KPI list (income, expenses, net, budget, variance, readiness)
- Business highlights
- WhatsApp-ready narrative text
- CSV export content
- PDF export/share via `ReportExportService`

### Distribution strategy
- **Source of truth**: App + Supabase data model
- **Distribution channel**: WhatsApp/PDF/CSV for stakeholder consumption

---

## 9) Security and Access Control (Production)

The strict policy script (`SUPABASE_RLS_PRODUCTION.sql`) applies:
- Helper role functions (`current_user_role`, `is_manager_or_owner`)
- RLS enablement across core tables
- Role-constrained select/insert/update policies
- Two-eyes style checks for review-sensitive tables (`reviewed_by <> submitted_by`)

### Why this matters
- Staff cannot self-escalate privileges
- Manager/owner privileges are explicit and auditable
- Write operations are constrained by role and ownership checks

---

## 10) Operational Playbook by Role

### Owner daily routine
1. Open dashboard and refresh
2. Review month financial overview + readiness score
3. Open report cards (daily/weekly/monthly)
4. Share report through WhatsApp/PDF
5. Act on highest-priority operations recommendation

### Manager daily routine
1. Open briefing tab first
2. Address escalations and unresolved anomalies
3. Validate task statuses and review submissions
4. Check payroll intelligence for low effort/missing evidence
5. Trigger follow-up with staff on missing data

### Staff daily routine
1. Open assigned tasks
2. Begin/execute task with evidence
3. Submit GPS + photo-backed report
4. Record daily biological checks
5. Track accountability metrics progress

---

## 11) Testing and Validation Commands

### Run unit/widget tests
```bash
flutter test
```

### Run a focused test file
```bash
flutter test test/widget_test.dart
flutter test test/zone_inference_engine_test.dart
```

### iOS simulator run
```bash
open -a Simulator
flutter devices
flutter run -d "iPhone 17 Pro" --debug
```

### Route-forced simulator run
```bash
flutter run -d "iPhone 17 Pro" --debug --dart-define=FORCE_HOME_ROUTE=owner
flutter run -d "iPhone 17 Pro" --debug --dart-define=FORCE_HOME_ROUTE=staff
```

---

## 12) Troubleshooting Guide

### App opens but role dashboard is wrong
- Confirm profile role in Supabase `profiles`
- Confirm auth metadata role
- Clear session and log in again

### WhatsApp share not opening
- WhatsApp may be unavailable on target simulator/device
- Fallback URL is attempted; verify external app handling

### PDF export issues
- Ensure storage/share permissions are available
- Current report formatting uses ASCII-safe punctuation for broad font compatibility

### iOS build or CocoaPods issues
- Re-run `pod install` in `ios/`
- Ensure valid Ruby/CocoaPods environment
- Retry with simulator SDK env setup if needed

---

## 13) Build Evolution Snapshot (Learning Context)

1. Milestone foundation: auth + role routing + core dashboards
2. Operations intelligence: tasks, anomalies, payroll/digest support
3. Owner finance and operations assist integration
4. Reporting expansion: monthly → daily/weekly/monthly
5. Distribution expansion: WhatsApp + CSV + PDF
6. Language refinement: staff default Swahili
7. Runtime polish: PDF glyph-safe output adjustments

This sequence is useful for onboarding teams on **how and why** the app architecture evolved.

---

## 14) Download and Use This Manual

### Option A (recommended): keep as project manual
- File: `FARMGENIUS_COMPLETE_LEARNING_MANUAL.md`
- Share it directly with your team as a downloadable markdown document.

### Option B: export to PDF for offline training
- Open this file in VS Code preview
- Print/Export to PDF
- Distribute as training handout

### Option B2: use pre-generated PDF (ready now)
- File: `FARMGENIUS_COMPLETE_LEARNING_MANUAL.pdf`
- Share directly with users as the downloadable training manual.

### Option C: include in release packs
- Bundle this file with build artifacts and SQL scripts for deployment handoff

---

## 15) Suggested Training Plan (90 Minutes)

- **0–15 min**: Architecture and role walkthrough
- **15–35 min**: Staff demo (execution + evidence)
- **35–55 min**: Manager demo (digest + escalations + payroll)
- **55–75 min**: Owner demo (financials + report sharing)
- **75–90 min**: Q&A + troubleshooting + responsibility matrix

---

## 16) Final Checklist (Go-Live Learning Readiness)

- [ ] Supabase schema applied
- [ ] Strict RLS policies applied in production
- [ ] Owner, Manager, Staff demo accounts validated
- [ ] Route-force test passes for all roles
- [ ] Reporting actions pass (preview/WhatsApp/CSV/PDF)
- [ ] Staff Swahili default confirmed
- [ ] Team trained with this manual and practical demos

---

**End of Manual**
