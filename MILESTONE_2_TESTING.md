# 🧪 Milestone 2: Quick-Start Testing Guide

## What You've Just Built

A **self-driving farm AI** that:
- ✅ Knows your farm geography (3 zones: maize, livestock, infrastructure)
- ✅ Automatically creates tasks when work is due
- ✅ Monitors weather and creates risk alerts
- ✅ Detects anomalies (gaps, cost spikes, health issues)
- ✅ Shows staff a simple "do this" task list
- ✅ Gives managers oversight dashboards

---

## Pre-Test Checklist

- [ ] Installed new dependencies: `flutter pub get`
- [ ] Created Supabase tables: Copy SQL from `SUPABASE_SETUP.sql` into your dashboard
- [ ] Converted KML to Dart: Ran `python3 scripts/kml_to_dart.py assets/farm_data lib/models/generated_farm_zones.dart`
- [ ] App builds: `flutter run`

---

## Test Flow

### **1. Create Manager Account**

1. Start the app
2. Select language (English or Kiswahili)
3. Tap "Email Login" → "Sign up"
4. Create account:
   - Email: `manager@farm.local`
   - Password: `Manager123!`
   - **Role: Manager**
5. Confirm email (check your mailbox or Supabase console)
6. Login with manager credentials

✅ You should land on **Manager Home Dashboard**.

---

### **2. Explore Manager Dashboard**

#### **Tab 1: Tasks**
- You'll see a summary showing:
  - Pending tasks (should be 0 initially)
  - Overdue tasks (0)
  - AI-generated (0, until we trigger orchestration)
- *Task list will be empty right now because we haven't run the AI yet.*

#### **Tab 2: Anomalies**
- Should show 0 anomalies
- Summary shows: Total, High Severity, Unresolved

#### **Tab 3: Zones**
- You'll see all 3 zones:
  - **Zone A - Maize** (5.2 hectares)
  - **Zone B - Livestock** (8.0 hectares)
  - **Zone C - Infrastructure** (0.5 hectares)
- Each zone shows type icon + area

---

### **3. Trigger the AI Orchestrator**

The app runs `aiOrchestrator.runDailyOrchestration()` on startup (in background). But you can force it:

**In main.dart (temporarily for testing):**

```dart
// Temporarily add this in the build() method after runDailyOrchestration():
WidgetsBinding.instance.addPostFrameCallback((_) {
  aiOrchestrator.runDailyOrchestration();
});
```

Or, if you prefer, create a debug button on the manager dashboard.

**For now, let's assume the orchestration ran.** Check Supabase `tasks` table:

```sql
-- In Supabase SQL Editor
SELECT * FROM tasks ORDER BY created_at DESC LIMIT 20;
```

You should see **generated tasks** with:
- `created_by_ai: 'calendar_due'` or `'weather_risk'`
- `status: 'PENDING'`
- `due_date` set to tomorrow or soon

---

### **4. Refresh Manager Dashboard**

Tap the **refresh button** (top-right) to reload tasks.

**Expected in Tasks tab:**
- Summary now shows: `Pending: 3` (or however many were generated)
- Task list shows:
  - "Germination Check - Zone A - Maize" (priority MEDIUM, due tomorrow)
  - "Health Check - Zone B - Livestock" (priority MEDIUM, due soon)
  - etc.
- Each task shows:
  - Zone name
  - AI reason: `calendar_due` or `weather_risk` as a purple badge
  - Priority as colored badge
  - Options to override or cancel

---

### **5. Create a Staff Account & Check Tasks**

1. Logout (tap logout icon)
2. Sign up as **Staff**:
   - Email: `staff@farm.local`
   - Password: `Staff123!`
   - **Role: Staff**
3. Login
4. You land on **Staff Home**

**Expected:**
- List of pending tasks (same ones the AI created)
- Each task card shows:
  - Task title + zone name
  - Color: green (due soon), orange (due today), red (overdue)
  - Activity icon (leaf for growth, wrench for maintenance, etc.)
  - **"Go to Zone"** button (placeholder – will integrate GPS)
  - **"Complete"** button (will open activity submission form)

---

### **6. Test Task Completion (Coming Soon)**

The **"Complete"** button is a placeholder. In the next milestone we'll build:
- Activity log detail screen
- GPS check-in at zone
- Photo upload (before/after/evidence)
- Cost input
- Quantity submitted (tons harvested, head treated, etc.)

For now, you can manually update the task status in Supabase:

```sql
UPDATE tasks 
SET status = 'COMPLETED', updated_at = now()
WHERE id = 'task_zone_a_GERMINATION...';
```

---

### **7. Test Anomaly Detection**

Anomalies are created if:
- **Activity gap:** No work logged in a zone for >14 days
- **Livestock health check overdue:** >30 days since last health check
- **Weather alerts:** NASA POWER detects risky conditions

For testing, manually insert an anomaly:

```sql
INSERT INTO anomalies (
  id, zone_id, type, title, description, severity, detected_at, data, created_at
) VALUES (
  'test_anomaly_1',
  'zone_b',
  'ACTIVITY_GAP',
  'Activity Gap Detected',
  'No activity in Zone B - Livestock for 45 days',
  0.8,
  now(),
  '{"days_since_activity": 45}'::jsonb,
  now()
);
```

Then refresh the manager dashboard → **Anomalies tab** should show the alert with:
- Red background (severity > 0.7)
- Icon + title + zone
- Severity percentage (80%)
- **"Resolve"** button

---

### **8. Test Language Toggle**

1. Logout and go back to Welcome screen
2. Toggle the switch: "English" ← → "Kiswahili"
3. All text should switch languages:
   - Welcome screen: "Karibu FarmGenius"
   - Login: "Ingia"
   - Staff tasks: "Mifumo" (future)

---

## 🐛 Troubleshooting

### **App crashes on startup**

**Error:** `MissingPluginException`
- **Fix:** Run `flutter pub get` and `flutter clean && flutter run`

### **Tasks table is empty after running the app**

**Possible causes:**
1. SQL tables not created in Supabase
   - **Fix:** Copy SQL from `SUPABASE_SETUP.sql` to your Supabase Dashboard → SQL Editor → Run
2. Orchestrator never ran
   - **Fix:** Add debug logging to `ai_orchestrator.dart` to see if it's executing
   - Check Supabase logs

### **NASA POWER API returns empty**

**Possible causes:**
1. API currently slow/down (it's free and public)
   - **Fix:** Retry later
2. Coordinates out of range
   - **Fix:** Verify `-7.083, 38.916` is correct for your farm

### **Tasks show but staff don't appear assigned**

**Expected behavior:** In Milestone 2, tasks are not yet assigned to specific staff. They're just in the pending pool. Staff can claim them (future milestone).

---

## 📊 What Happens Behind the Scenes

When you login as a manager and refresh:

```
1. Manager opens app (main.dart runs)
   ├─ SupabaseService.init() → connects to Supabase
   ├─ AuthService.loadSession() → loads your manager account
   └─ AIOrchestrator() → created, runDailyOrchestration() starts
   
2. AIOrchestrator checks all 3 zones (from generated_farm_zones.dart)
   ├─ Zone A (Maize):
   │  ├─ Expected activities: [PLANTING, GERMINATION, GROWTH, FLOWERING, GRAIN_FILL, HARVEST]
   │  ├─ Last activity? None logged yet (new zone)
   │  └─ Planting date was Nov 15 → Today it's due for GERMINATION
   │     └─ Create Task ✅
   │
   ├─ Zone B (Livestock):
   │  ├─ Expected activities: [GRAZING, SUPPLEMENTAL_FEEDING, HEALTH_CHECK, BREEDING, CALVING]
   │  └─ Health check overdue → Create Task ✅
   │
   └─ Zone C (Infrastructure):
      ├─ Expected: [MAINTENANCE, REPAIR, CLEANING, INSPECTION, SEASONAL_CHECK]
      └─ Maintenance due → Create Task ✅
      
3. Tasks are persisted to Supabase `tasks` table
   
4. Manager dashboard queries: SELECT * FROM tasks WHERE status='PENDING'
   
5. UI renders task cards for each zone
```

---

## ✅ Success Criteria

**Milestone 2 is working if:**

- [ ] App starts without crashes
- [ ] Manager can login and see empty dashboard
- [ ] 3 zones appear in Zones tab
- [ ] After orchestration, 3+ tasks appear in Tasks tab
- [ ] Each task shows zone name, priority, AI reason (purple badge)
- [ ] Tasks can be overridden/cancelled (manager options menu)
- [ ] Staff can login and see assigned tasks
- [ ] Task cards show activity icons
- [ ] "Go to Zone" and "Complete" buttons exist (placeholders are OK)
- [ ] Manager can view Anomalies tab
- [ ] Language toggle works (screens update in Swahili)
- [ ] Logout works and clears session

---

## 🎯 Next: Milestone 3

When you're ready, the next phase adds:

1. **Activity Log Screen** – staff submits work with photos/notes/cost
2. **GPS Check-In** – "Go to Zone" navigates to zone center + shows distance
3. **Expense Income Tracking** – feeds into cost anomalies
4. **Manager Task Creation** – manually override AI and assign custom tasks
5. **Offline Support** – tasks cached locally, sync on reconnect

---

## 📞 Quick Reference

| Action | Intent |
|--------|--------|
| Tap "Refresh" anywhere | Force reload from Supabase |
| Tap "Zones" tab | See all farm zones |
| Tap zone card | (Coming: zone detail + history) |
| Tap task "Complete" | (Coming: activity log form) |
| Tap "Override" on task | (Coming: reschedule or cancel) |
| Tap "Resolve" on anomaly | (Coming: mark acknowledged) |
| Toggle language switch | Update UI language |

---

**Ready to test?** Start with Step 1 and work through the flow. Report any issues and we'll iterate!
