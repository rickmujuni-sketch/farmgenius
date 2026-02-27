# 🚜 FarmGenius Milestone 2: AI-Driven Farm Management

## Overview

**Core Philosophy:** The AI is the farm's self-driving engine. It doesn't just record data—it *orchestrates* farm operations proactively.

The farm's geography (zones, boundaries, crop types) is now **embedded in the build** as compiled Dart objects. There's no UI for creating/deleting zones; the farm is defined statically in KML files converted to Dart code.

---

## 🗺️ What's New: Architecture

### 1. **Embedded Farm Geography (via KML)**

The farm is defined in `assets/farm_data/` as KML files (one per zone):
- `zone_A_maize.kml` – crop zone
- `zone_B_livestock.kml` – livestock operation
- `zone_C_infrastructure.kml` – water, equipment, irrigation

A Python converter (`scripts/kml_to_dart.py`) transforms these into `lib/models/generated_farm_zones.dart` - a compiled list of immutable FarmZone objects.

**Why this approach?**
- ✅ No runtime loading delays
- ✅ Zones are the immutable "farm DNA"
- ✅ Developers update KML; farmers don't need a UI for this
- ✅ GPS-bounded zones prevent accidental edits

**Running the converter:**
```bash
cd /Users/patrickmujuni/farmgenius
python3 scripts/kml_to_dart.py assets/farm_data lib/models/generated_farm_zones.dart
```

After changing KML files, re-run this command and rebuild the app.

---

### 2. **The AI Orchestrator**

File: `lib/services/ai_orchestrator.dart`

The orchestrator is a **ChangeNotifier service** that runs daily (or on-demand) to:

#### a) **Calendar-Based Task Generation**
- Each zone has an `expected_calendar` (e.g., PLANTING → GERMINATION → GROWTH → HARVEST)
- The orchestrator checks: when was the last time activity X was done?
- If overdue, it auto-creates a task for staff

#### b) **Weather Monitoring**
- Uses **NASA POWER API** to fetch weather + forecasts
- Assesses risk for upcoming activities (e.g., high rain = harvest postponement)
- Creates precautionary tasks (e.g., "Cover crops during heavy rain")

#### c) **Anomaly Detection**
- **Activity gaps:** no work done for 14+ days → flag it
- **Livestock health:** health check overdue → urgent alert
- **Cost anomalies:** unusual spending patterns (extensible)
- **Yield risks:** declining productivity indicators

### Key Methods:

```dart
// Run the full orchestration daily
await aiOrchestrator.runDailyOrchestration();

// Get tasks for staff
List<Task> tasks = await aiOrchestrator.getPendingTasksForStaff();

// Get anomalies for manager oversight
List<AnomalyDetection> anomalies = await aiOrchestrator.getAnomalies();
```

---

### 3. **Data Models**

#### **FarmZone** (immutable, loaded from KML)
```dart
const FarmZone(
  id: 'zone_a',
  name: 'Zone A - Maize',
  type: ZoneType.CROP,
  areaHectares: 5.2,
  boundary: [...], // list of GeoPoint
  metadata: {...}, // crop variety, planting date, etc.
)
```

#### **Task** (AI-generated work item)
```dart
const Task(
  id: '...',
  zoneId: 'zone_a',
  title: 'Germination Check - Zone A - Maize',
  activity: ActivityStage.GERMINATION,
  dueDate: DateTime(...),
  priority: TaskPriority.HIGH,
  status: TaskStatus.PENDING,
  createdByAI: 'calendar_due', // or 'weather_risk', 'anomaly_detected'
)
```

#### **ActivityLog** (staff completion record)
```dart
const ActivityLog(
  id: '...',
  taskId: '...',
  zoneId: 'zone_a',
  staffId: uuid,
  activity: ActivityStage.GERMINATION,
  loggedAt: DateTime(...),
  photoUrls: {'before': '...', 'after': '...'},
  notes: 'Seedlings emerging well',
  quantity: 2000, // seedlings or kg
  cost: 15000, // TZS
)
```

#### **AnomalyDetection** (AI insight/alert)
```dart
const AnomalyDetection(
  id: '...',
  zoneId: 'zone_b',
  type: AnomalyType.ACTIVITY_GAP, // or COST_SPIKE, YIELD_RISK, etc.
  title: 'Activity Gap Detected',
  severity: 0.8, // 0.0 to 1.0
  detectedAt: DateTime(...),
)
```

---

## 📊 Staff Experience

### **Staff Home Screen** (`lib/screens/staff_home.dart`)

Staff now see **only tasks the AI created**. No complexity:

1. **Pending Tasks List**
   - Shows AI-generated tasks, sorted by due date
   - Color-coded: green (due soon), orange (due today), red (overdue)
   - Each task linked to a zone + activity type

2. **Simple Task Actions**
   - **« Go to Zone »** – navigate to zone boundary using GPS (placeholder)
   - **« Complete »** – opens activity log screen to submit work

3. **Activity Log Submission** (To-Do: build this screen)
   - Photo upload (before/after/evidence)
   - Notes text input
   - Quantity (crops harvested, animals treated, etc.)
   - Cost if applicable (TZS)
   - GPS confirmation at zone center

**No decision-making:** Staff doesn't decide what to do. The AI tells them.

---

## 👨‍💼 Manager Experience

### **Manager Home Screen** (`lib/screens/manager_home_v2.dart`)

Tabbed interface with three sections:

#### **Tab 1: Tasks Dashboard**
- Summary: total pending, overdue, AI-generated
- List of all tasks with:
  - Priority indicator
  - AI reason (calendar_due, weather_risk, anomaly_detected)
  - **Override/Adjust** menu – manager can manually adjust due dates or cancel
- Manual task creation (coming next milestone)

#### **Tab 2: Anomalies Dashboard**
- High-severity alerts highlighted
- Activity gaps, cost spikes, yield risks, weather alerts
- Severity percentage
- **Resolve** button to mark as acknowledged

#### **Tab 3: Zones Overview**
- All `GeneratedFarmZones` listed
- Zone type icons (crop, livestock, infrastructure)
- Tap for zone detail (coming soon)

**Manager Powers:**
- Override AI decisions (temporarily)
- Acknowledge anomalies
- View task completion rates by zone
- Export insights/reports (future)

---

## 🌦️ Weather Integration

File: `lib/services/weather_service.dart`

Uses **NASA POWER API** (free, no auth required for basic queries).

```dart
// Fetch 7-day weather forecast for a location
List<WeatherData> weather = await WeatherService.fetchWeatherForecast(
  lat: -7.083,
  lng: 38.916,
  days: 7,
);
```

**Returns: temperature, humidity, rainfall, wind speed, soil moisture**

**Risk Assessment:**
- Germination + dry soil = create "watering" task
- Flowering + high wind = issue warning
- Harvest + rain forecast = delay task
- High humidity + heat = fungal disease risk

---

## 🗄️ Supabase Tables (Required!)

Copy and paste the SQL from `SUPABASE_SETUP.sql` into your Supabase dashboard:

### **tasks**
- `id`, `zone_id`, `title`, `description`, `activity`, `due_date`, `priority`, `status`
- `created_at`, `created_by_ai` (calendar_due, weather_risk, etc.)
- `metadata` (jsonb)

### **activity_logs**
- `id`, `task_id`, `zone_id`, `staff_id`, `activity`, `logged_at`
- `photo_urls` (jsonb with before/after/evidence)
- `notes`, `quantity`, `quantity_unit`, `cost`

### **anomalies**
- `id`, `zone_id`, `type`, `title`, `description`, `severity`
- `detected_at`, `resolved_at`, `manager_notes`, `data`

All three tables have **Row Level Security (RLS)** enabled.

---

## 🚀 How to Set Up & Run

### **Step 1: Update Supabase**

1. Go to your Supabase dashboard → **SQL Editor**
2. Copy the SQL from `SUPABASE_SETUP.sql`
3. Paste and execute
4. Verify tables appear in **Table Editor**

### **Step 2: (Optional) Update KML Zone Definitions**

If you want to change zones:

1. Edit `assets/farm_data/*.kml` files
2. Run the Python converter:
   ```bash
   python3 scripts/kml_to_dart.py assets/farm_data lib/models/generated_farm_zones.dart
   ```
3. Run the app: `flutter run`

### **Step 3: Run the App**

```bash
flutter pub get  # Install new dependencies (http, etc.)
flutter run      # On a device or simulator
```

The `main.dart` code now:
1. Initializes Supabase ✅
2. Loads auth session ✅
3. **Creates an AIOrchestrator** ← NEW
4. **Runs daily orchestration** ← NEW (in background)
5. Starts the app

### **Step 4: Test the Flow**

1. **Sign in as a Manager or Staff**
2. **Staff:** Tap a task → see activity log form (coming soon)
3. **Manager:** Tap through tasks, anomalies, zones

---

## 📝 How It Works: A Detailed Example

**Scenario:** You planted maize in Zone A on Nov 15, 2025. Today is Dec 1, 2025.

### **Daily Orchestration:**

```
AIOrchestrator.runDailyOrchestration()
  ├─ Load zones: zone_a (Maize)
  │
  ├─ Check zone_a calendar activities
  │  └─ Expected: PLANTING → GERMINATION → GROWTH → ...
  │  └─ Last activity: PLANTING on Nov 15
  │  └─ Days since: 16 days
  │  └─ Next activity: GERMINATION is due!
  │     └─ Create Task: "Germination Check - Zone A - Maize"
  │        ├─ Priority: MEDIUM
  │        ├─ DueDate: Dec 2
  │        ├─ CreatedByAI: 'calendar_due'
  │
  ├─ Check weather for zone_a
  │  └─ Fetch NASA data: temp 22°C, humidity 65%, rain 0mm
  │  └─ For GERMINATION: assess risk
  │     └─ Risk: LOW_RISK (good conditions)
  │
  ├─ Detect anomalies
  │  └─ No activity gaps (work done recently)
  │  └─ No anomalies
  │
  └─ Persist to Supabase
     └─ INSERT into tasks table
```

### **Staff sees:**
- 1 new task: "Germination Check - Zone A - Maize"
- Due tomorrow
- Taps "Go to Zone" → GPS shows Zone A boundary
- Taps "Complete" → submits activity log with photos

### **Manager sees:**
- Task in dashboard
- No anomalies
- Zone A health: ✅ on-schedule

---

## 🎯 Next Steps (Milestone 3+)

- [ ] Task detail & GPS check-in screen
- [ ] Activity photo & document upload
- [ ] Expense tracking (feeds into cost anomalies)
- [ ] Yield/harvest reporting
- [ ] Manager can manually create/assign tasks
- [ ] Export reports (PDF, CSV)
- [ ] Offline support for staff (sync on reconnect)
- [ ] Daily SMS/push notifications for overdue tasks
- [ ] AI learns from historical data (EMA yield trends)

---

## 💡 Key Concepts

| Concept | Definition | Example |
|---------|-----------|---------|
| **Zone** | Fixed farm area (crop, livestock, infrastructure) | Zone A - Maize |
| **Activity** | Specific work within a lifecycle | Germination, Harvest |
| **Task** | AI-assigned work item for staff | "Check seedlings in Zone A" |
| **ActivityLog** | Record of completed work | Staff logged: "2000 seedlings emerged" |
| **Anomaly** | AI-detected deviation from normal | "No activity in Zone B for 30 days" |
| **Severity** | Anomaly urgency (0.0–1.0) | 0.8 = high priority |

---

## ❓ FAQ

**Q: Can staff modify zones?**  
A: No. Zones are compile-time data. Farmers can't accidentally break boundaries.

**Q: What if the AI creates a wrong task?**  
A: Managers can override/cancel it. The AI learns from patterns (future milestone).

**Q: Does weather API require authentication?**  
A: No! NASA POWER is free and public. Just include lat/lng.

**Q: What if staff is offline?**  
A: Currently tasks won't load. Future: cache tasks locally, sync on reconnect.

**Q: Can we change the farm boundaries?**  
A: Yes, update the KML files and re-run the converter. Then rebuild the app.

---

## 📋 Checklist

- [x] KML files created for 3 zones
- [x] Python KML→Dart converter built and tested
- [x] FarmZone, Task, ActivityLog models created
- [x] AIOrchestrator service implemented
- [x] Weather service (NASA POWER) integrated
- [x] Staff home screen updated
- [x] Manager dashboard created
- [ ] Supabase tables created (run SQL in dashboard)
- [ ] Activity log detail screen built
- [ ] GPS navigation integrated
- [ ] Photo upload working
- [ ] End-to-end testing complete

---

## 📚 File Structure

```
lib/
  models/
    farm_zone.dart           ← Core model classes
    generated_farm_zones.dart ← Generated from KML (auto)
    
  services/
    ai_orchestrator.dart     ← Brain of the farm
    weather_service.dart     ← NASA POWER integration
    (others unchanged)
    
  screens/
    staff_home.dart          ← Task list for staff
    manager_home_v2.dart     ← AI oversight dashboard
    (others unchanged)

assets/
  farm_data/
    zone_A_maize.kml
    zone_B_livestock.kml
    zone_C_infrastructure.kml

scripts/
  kml_to_dart.py             ← Run this to regenerate zones
```

---

## 🔗 References

- **NASA POWER API**: https://power.larc.nasa.gov/
- **KML Format**: https://developers.google.com/kml/documentation
- **Supabase Auth**: https://supabase.com/docs/guides/auth

---

**Questions?** Feel free to iterate on this design. The beauty of embedding zones is flexibility—change a KML file, regenerate, rebuild. Done.
