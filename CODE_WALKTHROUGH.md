# 📖 Code Walkthrough: Understanding Milestone 2

This guide walks through the most important files and explains how they work together.

---

## 1️⃣ **Farm Zone Definition: `lib/models/farm_zone.dart`**

### What It Does
Defines the core data models for zones, tasks, and activities.

### Key Classes

**`FarmZone`** (immutable)
```dart
const FarmZone(
  id: 'zone_a',
  name: 'Zone A - Maize',
  type: ZoneType.CROP,        // CROP, LIVESTOCK, INFRASTRUCTURE
  areaHectares: 5.2,
  boundary: [GeoPoint(...), ...],
  metadata: {'crop_name': 'Maize', 'planting_date': '2025-11-15', ...}
)
```
- **Never changes** after compiled
- **Immutable** – can't be modified in app
- Loaded from `GeneratedFarmZones.zones` list
- Metadata holds all extra info (crop variety, livestock count, etc.)

**`Task`** (AI-created work item)
```dart
const Task(
  id: '...',
  zoneId: 'zone_a',
  title: 'Germination Check - Zone A - Maize',
  activity: ActivityStage.GERMINATION,
  dueDate: DateTime(2025, 12, 2),
  priority: TaskPriority.MEDIUM,
  status: TaskStatus.PENDING,
  createdByAI: 'calendar_due',  // why was this created?
  metadata: {'zone_type': 'CROP'}
)
```
- Created by AI orchestrator
- Has UUID for unique identity
- Can transition: PENDING → IN_PROGRESS → COMPLETED
- `createdByAI` tracks *why* it was created: `'calendar_due'`, `'weather_risk'`, etc.

**`ActivityLog`** (staff work record)
```dart
const ActivityLog(
  id: '...',
  taskId: 'task_...',
  zoneId: 'zone_a',
  staffId: uuid,  // which staff member did this?
  activity: ActivityStage.GERMINATION,
  loggedAt: DateTime(...),
  photoUrls: {'before': 'gs://...', 'after': 'gs://...'},
  notes: 'Seedlings emerging normally',
  quantity: 2000,      // 2000 seedlings
  quantityUnit: 'seedlings',
  cost: 15000,         // TZS
)
```
- Created by staff when completing a task
- Ties task → evidence (photos, notes, cost)
- Feeds back to AI (anomaly detection uses this)

**`AnomalyDetection`** (AI alert)
```dart
const AnomalyDetection(
  id: '...',
  zoneId: 'zone_b',
  type: AnomalyType.ACTIVITY_GAP,
  title: 'Activity Gap Detected',
  description: 'No activity in Zone B for 45 days',
  severity: 0.8,  // 0 to 1.0; higher = more urgent
  detectedAt: DateTime(...),
)
```
- Flagged by AI when something's wrong
- Types: ACTIVITY_GAP, COST_SPIKE, YIELD_RISK, WEATHER_ALERT, HEALTH_ISSUE
- Manager can acknowledge/resolve

---

## 2️⃣ **Generated Zones: `lib/models/generated_farm_zones.dart`**

This is **auto-generated** from KML files. You don't edit it directly.

### What It Contains

```dart
class GeneratedFarmZones {
  static const List<FarmZone> zones = [
    FarmZone(
      id: 'zone_a',
      name: 'Zone A - Maize',
      // ... all 3 zones loaded from KML
    ),
    FarmZone(
      id: 'zone_b',
      name: 'Zone B - Livestock',
      // ...
    ),
    FarmZone(
      id: 'zone_c',
      name: 'Zone C - Infrastructure',
      // ...
    ),
  ];
}
```

### How To Update

1. Edit `assets/farm_data/*.kml` files
2. Run:
   ```bash
   python3 scripts/kml_to_dart.py assets/farm_data lib/models/generated_farm_zones.dart
   ```
3. The file is regenerated
4. Rebuild app: `flutter run`

---

## 3️⃣ **The AI Brain: `lib/services/ai_orchestrator.dart`**

The core engine. This is where decisions happen.

### Architecture

```dart
class AIOrchestrator extends ChangeNotifier {
  Future<void> runDailyOrchestration() async {
    // 1. Check each zone's expected activities
    // 2. Create tasks if overdue
    // 3. Check weather and create risk tasks
    // 4. Detect anomalies
    // 5. Persist to Supabase
  }
}
```

### Main Methods

**`runDailyOrchestration()`** – The main loop
- Iterates through all zones
- For each zone: checks calendar, weather, anomalies
- Persists tasks/anomalies to Supabase
- Call this daily (app does it on startup)

**`_checkCalendarActivities(zone)`** – Is work overdue?
```dart
// For each expected activity in the zone:
// 1. Get last time this activity was logged
// 2. Check: is it overdue?
// 3. If yes: create a task
```

**`_checkWeatherRisks(zone)`** – Weather alerts
```dart
// Fetch NASA POWER weather
// For next 3 days:
//   Assess risk (GERMINATION + DRY_SOIL = water it)
//   Create precautionary task if risky
```

**`_detectAnomalies(zone)`** – Flag problems
```dart
// Check: 
//   - Activity gap? (>14 days no work)
//   - Livestock health overdue? (>30 days)
//   - Cost spike?
// Create anomaly record if detected
```

### Key Logic: Task Creation Example

```dart
Task _createTaskForActivity(FarmZone zone, ActivityStage activity) {
  final now = DateTime.now();
  return Task(
    id: 'task_${zone.id}_${activity}_${now.millisecondsSinceEpoch}',
    zoneId: zone.id,
    title: '${activity} - ${zone.name}',  // "Germination Check - Zone A - Maize"
    activity: activity,
    dueDate: now.add(Duration(days: 1)),   // due tomorrow
    priority: TaskPriority.MEDIUM,
    status: TaskStatus.PENDING,
    createdAt: now,
    createdByAI: 'calendar_due',           // why created
    metadata: {'zone_type': zone.type.toString()}
  );
}
```

### Persisting Data

At the end, tasks/anomalies are inserted into Supabase:

```dart
Future<void> _persistTasks() async {
  for (final task in generatedTasks) {
    // Check if task already exists (avoid duplicates)
    // If not, INSERT into tasks table
    await SupabaseService.client.from('tasks').insert({
      'id': task.id,
      'zone_id': task.zoneId,
      'title': task.title,
      'due_date': task.dueDate.toIso8601String(),
      // ... more fields
    }).execute();
  }
}
```

---

## 4️⃣ **Weather Integration: `lib/services/weather_service.dart`**

Fetches real weather data from NASA POWER API.

### Main Method

```dart
static Future<List<WeatherData>> fetchWeatherForecast({
  required double lat,
  required double lng,
  required int days,
}) async {
  // 1. Build NASA POWER API URL
  // 2. Fetch JSON response
  // 3. Parse into WeatherData objects
  // 4. Return list of daily data
}
```

### Risk Assessment

```dart
static String assessWeatherRisk({
  required WeatherData weather,
  required ActivityStage activity,
}) {
  // Rules:
  // - Germination + soil moisture < 30% = "DRY_SOIL"
  // - Flowering + wind > 20 m/s = "HIGH_WIND"
  // - Harvest + rain > 5mm = "RAIN_RISK"
  // - Humidity > 90% & temp > 25°C = "FUNGAL_RISK"
  // Return risk type or "LOW_RISK"
}
```

### Example Usage (in AIOrchestrator)

```dart
// Get weather for zone center
final weather = await WeatherService.fetchWeatherForecast(
  lat: zone.center.lat,
  lng: zone.center.lng,
  days: 7,
);

// Check each day
for (final w in weather.take(3)) {
  final risk = WeatherService.assessWeatherRisk(
    weather: w,
    activity: ActivityStage.GERMINATION,
  );
  
  if (risk != 'LOW_RISK') {
    // Create precautionary task
    generatedTasks.add(Task(
      title: 'Weather Risk: $risk',
      dueDate: w.date,
      createdByAI: 'weather_risk'
    ));
  }
}
```

---

## 5️⃣ **Staff UI: `lib/screens/staff_home.dart`**

What staff members see.

### Widget Structure

```dart
class StaffHome extends StatefulWidget {
  // Loads pending tasks on init
  @override
  void initState() {
    _tasksFuture = ai.getPendingTasksForStaff();
  }
  
  // Renders task list
  @override
  Widget build(context) {
    return FutureBuilder<List<Task>>(
      future: _tasksFuture,
      builder: (context, snapshot) {
        final tasks = snapshot.data ?? [];
        return ListView.builder(
          itemCount: tasks.length,
          itemBuilder: (context, i) => TaskCard(tasks[i])
        );
      }
    );
  }
}
```

### Task Card Logic

```dart
class TaskCard extends StatelessWidget {
  @override
  Widget build(context) {
    // Color based on due date
    if (task.isOverdue) color = Colors.red;
    else if (task.isDueToday) color = Colors.orange;
    else color = Color(0xFF2E7D32);
    
    return Card(
      child: Column(
        children: [
          // Header with zone name, activity icon
          Container(
            color: statusColor,
            child: Row(children: [...])
          ),
          // Body with description, due date, buttons
          Padding(
            child: Column(children: [
              Text(task.description),
              Row(
                children: [
                  ElevatedButton.icon(
                    icon: Icons.location_on,
                    label: 'Go to Zone',
                    onPressed: () {
                      // TODO: GPS navigation
                    }
                  ),
                  ElevatedButton.icon(
                    icon: Icons.check,
                    label: 'Complete',
                    onPressed: () {
                      // TODO: Activity log form
                    }
                  )
                ]
              )
            ])
          )
        ]
      )
    );
  }
}
```

---

## 6️⃣ **Manager UI: `lib/screens/manager_home_v2.dart`**

Manager oversight dashboard.

### Tabs Structure

```dart
class ManagerHome extends StatefulWidget {
  late TabController _tabController;
  
  @override
  Widget build(context) {
    return Scaffold(
      appBar: AppBar(
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Tasks'),      // Pending, overdue, pending
            Tab(text: 'Anomalies'),  // Alerts, severity
            Tab(text: 'Zones')       // All zones
          ]
        )
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTasksTab(),
          _buildAnomaliesTab(),
          _buildZonesTab()
        ]
      )
    );
  }
}
```

### Tasks Tab

```dart
Widget _buildTasksTab() {
  return FutureBuilder<List<Task>>(
    future: ai.getPendingTasksForStaff(),
    builder: (context, snapshot) {
      final tasks = snapshot.data ?? [];
      
      // Summary stats
      return Column(children: [
        Container(
          child: Row(children: [
            _StatCard('Pending', tasks.length),
            _StatCard('Overdue', overdueTasks.length),
            _StatCard('AI-Generated', aiTasks.length)
          ])
        ),
        
        // Task list with override menu
        ListView.builder(
          itemCount: tasks.length,
          itemBuilder: (context, i) => ListTile(
            title: tasks[i].title,
            trailing: PopupMenuButton(
              itemBuilder: (_) => [
                PopupMenuItem(value: 'override', child: Text('Override')),
                PopupMenuItem(value: 'cancel', child: Text('Cancel'))
              ],
              onSelected: (value) {
                // TODO: Implement override/cancel
              }
            )
          )
        )
      ]);
    }
  );
}
```

### Anomalies Tab

```dart
Widget _buildAnomaliesTab() {
  return FutureBuilder<List<AnomalyDetection>>(
    future: ai.getAnomalies(),
    builder: (context, snapshot) {
      final anomalies = snapshot.data ?? [];
      
      // Summary: Total, High Severity, Unresolved
      // List: Each anomaly with severity bar + resolve button
      return ListView(
        children: [
          // Summary stats
          ...anomalies.map((a) => Card(
            color: a.severity > 0.7 ? Colors.red.shade50 : Colors.orange.shade50,
            child: Column(children: [
              Container(
                color: a.severity > 0.7 ? Colors.red : Colors.orange,
                child: Row(children: [
                  Icon(_getAnomalyIcon(a.type)),
                  Text(a.title),
                  Chip(label: Text('${(a.severity * 100).toInt()}%'))
                ])
              ),
              Text(a.description),
              ElevatedButton(
                label: 'Resolve',
                onPressed: () { /* TODO */ }
              )
            ])
          ))
        ]
      );
    }
  );
}
```

---

## 7️⃣ **Main Entry Point: `lib/main.dart`**

How everything ties together.

### Initialization

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 1. Connect to Supabase
  await SupabaseService.init(...);
  
  // 2. Load auth session (user stays logged in)
  final authService = AuthService();
  await authService.loadSession();
  
  // 3. Initialize AI engine (NEW!)
  final aiOrchestrator = AIOrchestrator();
  // 4. Run daily task generation (NEW!)
  aiOrchestrator.runDailyOrchestration().ignore();
  
  // 5. Start the app
  runApp(FarmGeniusApp(
    authService: authService,
    aiOrchestrator: aiOrchestrator  // Pass to app
  ));
}
```

### Provider Setup

```dart
class FarmGeniusApp extends StatelessWidget {
  final AuthService authService;
  final AIOrchestrator aiOrchestrator;
  
  @override
  Widget build(context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LocalizationService()),
        ChangeNotifierProvider(create: (_) => authService),
        ChangeNotifierProvider(create: (_) => aiOrchestrator),  // NEW!
      ],
      child: MaterialApp(
        routes: {
          '/': (_) => WelcomeScreen(),
          '/login': (_) => LoginScreen(),
          '/manager': (_) => ManagerHome(),
          '/staff': (_) => StaffHome(),
          // ...
        }
      )
    );
  }
}
```

---

## 🔗 Data Flow Summary

```
1. User logs in
   ↓
2. main.dart creates AIOrchestrator, runs runDailyOrchestration()
   ↓
3. AIOrchestrator loads zones from GeneratedFarmZones.zones
   ↓
4. For each zone:
   ├─ Check calendar (is activity overdue?)
   ├─ Check weather (NASA POWER API)
   └─ Detect anomalies
   ↓
5. Create Task objects, store in memory
   ↓
6. Persist to Supabase (tasks table, anomalies table)
   ↓
7. User opens Manager/Staff home
   ↓
8. Home screen queries Supabase: SELECT * FROM tasks WHERE status='PENDING'
   ↓
9. UI renders tasks with colors, icons, metadata
   ↓
10. Staff taps "Complete" → Activity log form (coming next milestone)
```

---

## 🎓 Key Takeaways

1. **FarmZones** are immutable compile-time data
2. **Tasks** are AI-generated, persisted to Supabase
3. **ActivityLogs** are staff submissions (photos, notes, costs)
4. **Anomalies** are AI-detected alerts
5. **AIOrchestrator** is the decision engine (calendar + weather + patterns)
6. **Staff UI** is simple: see tasks, do tasks, submit work
7. **Manager UI** is oversight: see everything, override if needed

Each component is independent but works together via Supabase as the shared database.

---

## 📚 Next: What To Read

- `MILESTONE_2_GUIDE.md` – Full architecture & design
- `MILESTONE_2_TESTING.md` – Step-by-step testing
- `SUPABASE_SETUP.sql` – Database schema
- `MILESTONE_2_SUMMARY.md` – High-level overview

Happy coding! 🚜
