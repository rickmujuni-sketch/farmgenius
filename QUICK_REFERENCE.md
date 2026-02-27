# 🗂️ Milestone 2: File Reference & Quick Links

## 📋 Complete File Inventory (What's New)

### **Core Models & Data**

| File | Purpose | Key Classes |
|------|---------|------------|
| `lib/models/farm_zone.dart` | Core data models | `FarmZone`, `Task`, `ActivityLog`, `AnomalyDetection`, `GeoPoint`, enums |
| `lib/models/generated_farm_zones.dart` | **[AUTO-GENERATED]** Zone definitions from KML | `GeneratedFarmZones.zones` constant |

### **Services (Business Logic)**

| File | Purpose | Key Methods |
|------|---------|------------|
| `lib/services/ai_orchestrator.dart` | AI decision engine; creates tasks, detects anomalies | `runDailyOrchestration()`, `getPendingTasksForStaff()`, `getAnomalies()` |
| `lib/services/weather_service.dart` | NASA POWER API integration | `fetchWeatherForecast()`, `assessWeatherRisk()` |

### **UI Screens (Updated)**

| File | Purpose | Key Components |
|------|---------|----------------|
| `lib/screens/staff_home.dart` | **[UPDATED]** Task list for staff | `StaffHome`, `TaskCard`, task colors/priorities |
| `lib/screens/manager_home.dart` | **[UPDATED]** Redirects to manager_home_v2.dart | Export only |
| `lib/screens/manager_home_v2.dart` | Manager dashboard with 3 tabs (Tasks/Anomalies/Zones) | `ManagerHome`, tabs, stat cards |

### **Entry Point**

| File | Purpose | Changes |
|------|---------|---------|
| `lib/main.dart` | **[UPDATED]** App initialization | Imports `AIOrchestrator`, creates instance, runs orchestration |

### **Asset Files (Farm Geography)**

| File | Purpose | Contains |
|------|---------|----------|
| `assets/farm_data/zone_A_maize.kml` | Zone A definition (crop) | Boundary, crop type, planting date, calendar |
| `assets/farm_data/zone_B_livestock.kml` | Zone B definition (livestock) | Boundary, livestock type, health schedule |
| `assets/farm_data/zone_C_infrastructure.kml` | Zone C definition (infrastructure) | Boundary, facilities, maintenance schedule |

### **Scripts (Tools)**

| File | Purpose | Usage |
|------|---------|-------|
| `scripts/kml_to_dart.py` | Convert KML → Dart code | `python3 scripts/kml_to_dart.py assets/farm_data lib/models/generated_farm_zones.dart` |

### **Configuration**

| File | Purpose | What To Do |
|------|---------|-----------|
| `pubspec.yaml` | **[UPDATED]** Added `http` dependency | Already done, just run `flutter pub get` |

### **Database Setup**

| File | Purpose | Action Required |
|------|---------|-----------------|
| `SUPABASE_SETUP.sql` | Supabase table schema | **Copy & paste into Supabase SQL Editor → Run** |

### **Documentation**

| File | Audience | Read This For |
|------|----------|---------------|
| `MILESTONE_2_GUIDE.md` | Developers | Full architecture, all concepts explained |
| `MILESTONE_2_TESTING.md` | QA/Testers | Step-by-step testing flow, troubleshooting |
| `MILESTONE_2_SUMMARY.md` | Overview | High-level summary, vision, next steps |
| `CODE_WALKTHROUGH.md` | Developers | Deep dive into key code sections |
| This file | Everyone | Quick navigation & file reference |

---

## 🚀 Getting Started (3 Quick Steps)

### **Step 1: Set Up Supabase Tables** ⚡

```
1. Open Supabase Dashboard
2. SQL Editor
3. Copy all SQL from SUPABASE_SETUP.sql
4. Paste & Run
5. Verify: check Tables section
```

### **Step 2: Install Dependencies** ⚡

```bash
cd /Users/patrickmujuni/farmgenius
flutter pub get
```

### **Step 3: Run App** ⚡

```bash
flutter run
```

The app will:
1. Load zones from KML (GeneratedFarmZones)
2. Run orchestrator on startup
3. Generate tasks based on calendar + weather
4. You'll see them on Manager Dashboard after refresh

---

## 📚 Learning Path

**Recommended reading order:**

1. **New here?** Start with `MILESTONE_2_SUMMARY.md`
   - Get the big picture
   - Understand philosophy

2. **Want details?** Read `MILESTONE_2_GUIDE.md`
   - Zones, tasks, anomalies explained
   - How AI works

3. **Ready to code?** Read `CODE_WALKTHROUGH.md`
   - Each file explained
   - Key logic sections

4. **Time to test?** Follow `MILESTONE_2_TESTING.md`
   - Step-by-step test flow
   - Troubleshooting tips

5. **Need to modify?** Check specific file in this guide
   - Edit KML → regenerate with Python script
   - Change thresholds in `ai_orchestrator.dart`
   - Add new task types

---

## 🔄 Common Tasks

### **I want to add a new zone (4th crop plot)**

1. Create `assets/farm_data/zone_D_new_crop.kml`
2. Run: `python3 scripts/kml_to_dart.py assets/farm_data lib/models/generated_farm_zones.dart`
3. Run: `flutter run`
4. Done! New zone appears in Manager Dashboard → Zones tab

### **I want to change planting dates**

1. Edit `assets/farm_data/zone_A_maize.kml` → update `<Data name="planting_date">`
2. Regenerate: `python3 scripts/kml_to_dart.py ...`
3. Rebuild: `flutter run`
4. Old task due dates will be recalculated next orchestration

### **I want to adjust task intervals**

1. Edit `lib/services/ai_orchestrator.dart`, method `_getActivityInterval()`
2. Change days for each activity type
3. Rebuild: `flutter run`

### **I want to update Supabase schema**

1. Edit `SUPABASE_SETUP.sql`
2. Copy new SQL → Supabase Dashboard
3. Run the SQL
4. Verify tables in **Tables** tab

### **I want to customize AI risk assessment**

1. Edit `lib/services/weather_service.dart`, method `assessWeatherRisk()`
2. Add/modify rules for activities
3. Rebuild: `flutter run`

### **I want to add more translations**

1. Edit `lib/services/localization_service.dart`
2. Add new keys to both `'en'` and `'sw'` maps
3. Use throughout UI: `loc.t('new_key')`
4. Rebuild

---

## 🎯 Architecture at a Glance

```
┌─────────────────────────────────────────┐
│         FarmGenius Milestone 2           │
├─────────────────────────────────────────┤
│ Input                                    │
│ ├─ Zones (KML → GeneratedFarmZones)     │
│ ├─ Weather (NASA POWER API)             │
│ └─ Activity history (Supabase)          │
│                                         │
│ Processing                               │
│ ├─ AIOrchestrator                       │
│ │  ├─ Check calendar (tasks due?)       │
│ │  ├─ Check weather (risks?)            │
│ │  └─ Detect anomalies                  │
│ └─ Persist to Supabase                  │
│                                         │
│ Output                                   │
│ ├─ Manager Dashboard (oversight)        │
│ │  ├─ Tasks tab (with override)         │
│ │  ├─ Anomalies tab (alert severity)    │
│ │  └─ Zones tab (farm overview)         │
│ └─ Staff Home (task list)               │
└─────────────────────────────────────────┘
```

---

## 🔑 Key Enums & Constants

### **TaskPriority**
- `LOW` → blue
- `MEDIUM` → orange
- `HIGH` → red
- `URGENT` → deep orange

### **TaskStatus**
- `PENDING` → not started
- `IN_PROGRESS` → being done
- `COMPLETED` → finished
- `CANCELLED` → removed
- `OVERDUE` → past due date

### **ZoneType**
- `CROP` → plant-based
- `LIVESTOCK` → animals
- `INFRASTRUCTURE` → buildings/equipment

### **AnomalyType**
- `ACTIVITY_GAP` → no work for 14+ days
- `COST_SPIKE` → unusual expenses
- `YIELD_RISK` → productivity declining
- `WEATHER_ALERT` → bad weather coming
- `HEALTH_ISSUE` → livestock health problem

### **ActivityStage**
- Crops: PLANTING, GERMINATION, GROWTH, FLOWERING, GRAIN_FILL, HARVEST
- Livestock: GRAZING, SUPPLEMENTAL_FEEDING, HEALTH_CHECK, BREEDING, CALVING
- Infrastructure: MAINTENANCE, REPAIR, CLEANING, INSPECTION, SEASONAL_CHECK

---

## 📊 Supabase Tables Overview

### **tasks**
```
id              TEXT        primary key
zone_id         TEXT        which zone (foreign key)
title           TEXT        task name
activity        TEXT        activity type (enum)
due_date        TIMESTAMP   when due
priority        TEXT        enum (LOW, MEDIUM, HIGH, URGENT)
status          TEXT        enum (PENDING, IN_PROGRESS, COMPLETED, etc)
created_by_ai   TEXT        'calendar_due', 'weather_risk', 'anomaly_detected'
metadata        JSONB       extra data
```

### **activity_logs**
```
id              TEXT        primary key
task_id         TEXT        which task completed (foreign key)
zone_id         TEXT        which zone
staff_id        UUID        which staff member (foreign key to auth.users)
activity        TEXT        what activity
logged_at       TIMESTAMP   when
photo_urls      JSONB       {'before': url, 'after': url, 'evidence': url}
notes           TEXT        what happened
quantity        INT         amount (kg, head, seedlings, etc)
quantity_unit   TEXT        'kg', 'head', 'seedlings', etc
cost            DOUBLE      TZS spent
```

### **anomalies**
```
id              TEXT        primary key
zone_id         TEXT        which zone affected
type            TEXT        enum (ACTIVITY_GAP, COST_SPIKE, etc)
title           TEXT        alert headline
description     TEXT        details
severity        DOUBLE      0.0–1.0 (higher = more urgent)
detected_at     TIMESTAMP   when detected
resolved_at     TIMESTAMP   when manager resolved it
resolved_by     UUID        which manager (foreign key)
manager_notes   TEXT        manager comment
data            JSONB       extra context
```

---

## 🧪 Testing Quick Checklist

- [ ] Supabase tables created
- [ ] Flutter dependencies installed (`flutter pub get`)
- [ ] App runs without errors (`flutter run`)
- [ ] Can login as Manager
- [ ] Can login as Staff
- [ ] Manager Dashboard shows 3 zones
- [ ] After orchestration, tasks appear
- [ ] Tasks show correct priority/icon
- [ ] Staff sees same tasks
- [ ] Language toggle works
- [ ] No console errors in logs

---

## 💬 FAQ: Quick Answers

| Q | A |
|---|---|
| Where's the zone boundary data? | `assets/farm_data/*.kml` files (KML format) |
| How do new tasks appear? | `AIOrchestrator.runDailyOrchestration()` runs on app startup |
| Who creates tasks? | The AI (based on calendar + weather), never manual in M2 |
| Where's task data stored? | Supabase `tasks` table |
| How does staff log work? | Complete button → activity log form (coming M3) |
| Can zones be edited in app? | NO – they're frozen at compile time (security feature) |
| What if farmer wants different zones? | Edit KML, regenerate, rebuild |
| Is there offline support? | No – tasks won't load without internet (M3 adds caching) |

---

## 📞 Important Files by Use Case

**"I changed KML and nothing happened"**
→ You need to regenerate: `python3 scripts/kml_to_dart.py ...`

**"Tasks aren't showing up"**
→ Check: 1) Supabase tables created? 2) Orchestrator ran? 3) Check Supabase `tasks` table

**"Staff don't see manager's tasks"**
→ Remember: M2 doesn't assign tasks, just creates them. Staff see pending pool.

**"I don't understand how X works"**
→ Start with `CODE_WALKTHROUGH.md`, find the relevant section

**"I want to customize AI behavior"**
→ Edit: `lib/services/ai_orchestrator.dart` and `lib/services/weather_service.dart`

**"Zone colors / icons look wrong"**
→ Edit: `lib/screens/staff_home.dart` and `lib/screens/manager_home_v2.dart`

---

## 🚀 Next Milestone Sneak Peek

Milestone 3 will add:

- ✅ Activity log form (photos, notes, costs)
- ✅ GPS navigation to zones
- ✅ Expense tracking integration
- ✅ Offline support (cache + sync)
- ✅ Manager manual task creation

The foundation is built. Now it gets real. 🚜

---

**Happy farming! Questions? Check the relevant doc above.** 📚
