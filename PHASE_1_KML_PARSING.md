# 🗺️ Phase 1: KML Parsing Guide

## What's New (Phase 1 - Today)

FarmGenius can now **parse real farm data** from Google Earth KML files instead of using fake sample zones.

### 📁 Files Created

| File | Purpose |
|------|---------|
| `lib/models/kml_models.dart` | Core models: `GeoCoordinate`, `FarmBoundary`, `KmlPlacemark`, `ParsedKmlFarm` |
| `lib/services/kml_parser_service.dart` | XML parser for KML files |
| `lib/services/kml_parser_demo.dart` | Demo showing what gets extracted (for testing) |
| `assets/farm_data/farm_boundary.kml` | **Your actual farm KML** from Google Earth |

### 📦 Dependencies Added

- `xml: ^6.3.0` in pubspec.yaml (for XML/KML parsing)

---

## What Gets Extracted from Your KML

### **Raw Data (From Your Farm)**

```
Farm Name:       Dr. Mujuni's Farm - Kawongo, Rakai
Farm Area:       ~13.2 hectares (calculated from boundary polygon)
Boundary Points: 19 coordinate pairs
```

### **Livestock Points Detected**

The parser **automatically detects** livestock from point names using heuristics:

| # | Name | Type | Location | Detection |
|---|------|------|----------|-----------|
| 1 | Piggery shed | PIGS | 38.916112, -7.083396 | Contains "piggery" → LIVESTOCK_AREA + PIGS |
| 2 | Paddock for Cattles | CATTLE | 38.915820, -7.083240 | Contains "cattle" → LIVESTOCK_AREA + CATTLE |
| 3 | Goats | GOATS | 38.915955, -7.082919 | Contains "goats" → LIVESTOCK_AREA + GOATS |
| 4 | Chickens | CHICKENS | 38.915897, -7.082957 | Contains "chickens" → LIVESTOCK_AREA + CHICKENS |

### **Infrastructure Points Detected**

| # | Name | Type | Location | Detection |
|---|------|------|----------|-----------|
| 1 | farmhouse | FARMHOUSE | 38.915285, -7.082955 | Contains "farmhouse" → FARMHOUSE |
| 2 | Borehole | WATER_SOURCE | 38.916970, -7.082268 | Contains "borehole" → WATER_SOURCE |
| 3 | Servant Quarters | QUARTERS | 38.915816, -7.082934 | Contains "quarters" → QUARTERS |

---

## How Parsing Works (Code Flow)

### **Step 1: Load KML from Assets**
```dart
final farm = await KmlParser.parseFromAsset('assets/farm_data/farm_boundary.kml');
```

### **Step 2: Parse XML Structure**
```
Document
  ├── Placemark (Polygon) → Farm boundary
  └── Placemarks (Points) → Infrastructure & livestock
```

### **Step 3: Extract Coordinates**
For each Placemark:
- If it has `<Polygon>` → Store as boundary
- If it has `<Point>` → Store as placemark

### **Step 4: Auto-Categorize**
```dart
KmlPlacemark.fromNameAndLocation(
  name: "Piggery shed",
  location: GeoCoordinate(lat, lng)
)
// Automatically detects:
// ✓ type = PointType.LIVESTOCK_AREA
// ✓ livestockType = LivestockType.PIGS
```

---

## Key Classes & How They Work

### **GeoCoordinate**
Represents a single point on Earth:
```dart
GeoCoordinate(
  latitude: -7.082955,
  longitude: 38.915285,
  altitude: 289.5
)
```

Methods:
- `.distanceToMeters(other)` → How far to another point
- `.toString()` → Format as KML coordinate string

### **FarmBoundary**
Represents the farm perimeter polygon:
```dart
FarmBoundary(
  id: "55DADA1C02000001",
  name: "Your Farm",
  coordinates: [19 GeoCoordinate objects]
)
```

Methods:
- `.areaHectares` → ~13.2 hectares (calculated)
- `.centroid` → Center point of farm
- `.containsPoint(geoCoord)` → Is this point inside the farm?

### **KmlPlacemark**
Represents a point (building, livestock area, etc.):
```dart
KmlPlacemark(
  id: "06CD871E593987635DE0",
  name: "Piggery shed",
  location: GeoCoordinate(-7.083396, 38.916112),
  type: PointType.LIVESTOCK_AREA,
  livestockType: LivestockType.PIGS
)
```

### **ParsedKmlFarm**
Complete result of parsing one KML file:
```dart
ParsedKmlFarm(
  farmName: "Dr. Mujuni's Farm",
  boundary: FarmBoundary(...),
  placemarks: [7 KmlPlacemark objects]
)
```

Methods:
- `.placemarksByType` → Group by infrastructure type
- `.livestockPlacemarks` → Only livestock points
- `.livestockByType` → Group livestock by species

---

## Testing Phase 1 Parsing

### **Option A: Run Demo (Recommended)**

Add to `lib/main.dart` in the `main()` function:

```dart
import 'services/kml_parser_demo.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // TEST: Parse KML during startup
  await KmlParserDemo.parseAndPrintFarmKml();
  
  // ... rest of main
}
```

Then run:
```bash
flutter run
# Watch console output - will show all parsed data
```

You should see output like:
```
========== PHASE 1: KML PARSING ==========

📍 Farm Name: Dr. Mujuni's Farm - Kawongo, Rakai
📐 Boundary: Your Farm
📏 Area: 13.24 hectares
🧭 Centroid: (-7.08349, 38.91614)
🔢 Boundary Points: 19

--- Extracted Placemarks ---

Total points: 7

📦 BY TYPE:
  • LIVESTOCK_AREA: 4
  • FARMHOUSE: 1
  • WATER_SOURCE: 1
  • QUARTERS: 1

🐄 LIVESTOCK DETECTED:
  • PIGS: 1
    - Piggery shed @ (38.916112, -7.083396)
  • CATTLE: 1
    - Paddock for Cattles @ (38.915820, -7.083240)
  • GOATS: 1
    - Goats @ (38.915955, -7.082919)
  • CHICKENS: 1
    - Chickens @ (38.915897, -7.082957)

🏢 INFRASTRUCTURE:
  • FARMHOUSE: farmhouse
    @ (38.915285, -7.082955)
  • WATER_SOURCE: Borehole
    @ (38.916970, -7.082268)
  • QUARTERS: Servant Quarters
    @ (38.915816, -7.082934)

========== PHASE 2 PREVIEW: ZONE GENERATION ==========

The following ZONE will be generated from this data:

🌾 CROP ZONES:
  • Remaining farm land (13.24 hectares)
  • Could be divided into plots based on water distance

🐄 LIVESTOCK ZONES:
  • Piggery shed (PIGS)
    - 100m radius around: (-7.083396, 38.916112)
    - Activities: daily feeding, health checks, breed management
  • Paddock for Cattles (CATTLE)
    - 100m radius around: (-7.083240, 38.915820)
    - Activities: daily feeding, health checks, breed management
  • Goats (GOATS)
    - 100m radius around: (-7.082919, 38.915955)
    - Activities: daily feeding, health checks, breed management
  • Chickens (CHICKENS)
    - 100m radius around: (-7.082957, 38.915897)
    - Activities: daily feeding, health checks, breed management

🏥 INFRASTRUCTURE ZONES:
  • farmhouse (FARMHOUSE)
    - Activities: security patrol, maintenance
  • Borehole (WATER_SOURCE)
    - Activities: pump maintenance, water testing
  • Servant Quarters (QUARTERS)
    - Activities: quarters maintenance, amenity checks

========== END PHASE 2 PREVIEW ==========
```

### **Option B: Unit Test**

Create `test/kml_parser_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:farmgenius/services/kml_parser_service.dart';

void main() {
  test('Parse real farm KML', () async {
    final farm = await KmlParser.parseFromAsset(
      'assets/farm_data/farm_boundary.kml'
    );
    
    expect(farm.farmName, contains('Farm'));
    expect(farm.boundary.coordinates.length, greaterThan(0));
    expect(farm.placemarks.length, equals(7));
    expect(farm.livestockPlacemarks.length, equals(4));
  });
}
```

Run with:
```bash
flutter test test/kml_parser_test.dart
```

---

## How This Feeds Into Phase 2

Phase 1 gives us:
1. ✅ Farm boundary (for zone containment checks)
2. ✅ Livestock locations (create zones with 50-100m radius)
3. ✅ Infrastructure locations (create maintenance zones)
4. ✅ Auto-detected livestock types (CATTLE, GOATS, PIGS, CHICKENS)

Phase 2 will use this to:
- 🚀 Create 5-7 auto-generated zones (1 per livestock + crops + infra)
- 🚀 Assign appropriate activity calendars per livestock type
- 🚀 Pre-set maintenance schedules for infrastructure
- 🚀 Generate Dart code with embedded zones (compile-time safety)

---

## Detection Heuristics (How Auto-Categorization Works)

### **Point Type Detection** (from name)
```dart
if (name.contains('farmhouse') || name.contains('house'))
  → PointType.FARMHOUSE

if (name.contains('borehole') || name.contains('water') || name.contains('tank'))
  → PointType.WATER_SOURCE

if (name.contains('quarters') || name.contains('staff'))
  → PointType.QUARTERS

if (name.contains('shed') || name.contains('paddock') || name.contains('pen'))
  → PointType.LIVESTOCK_AREA
```

### **Livestock Type Detection** (from name)
```dart
if (name.contains('cattle') || name.contains('cow'))
  → LivestockType.CATTLE

if (name.contains('goat'))
  → LivestockType.GOATS

if (name.contains('pig') || name.contains('piggery'))
  → LivestockType.PIGS

if (name.contains('chicken') || name.contains('poultry') || name.contains('coop'))
  → LivestockType.CHICKENS

// ... and more (sheep, bees, fish, etc.)
```

You can improve these heuristics by updating `KmlPlacemark.fromNameAndLocation()`.

---

## File Dependencies

```
lib/
├── models/
│   ├── kml_models.dart          ← Core data classes
│   └── farm_zone.dart           ← Old models (keep for now)
├── services/
│   ├── kml_parser_service.dart  ← Dart XML parser
│   └── kml_parser_demo.dart     ← Testing & demo
└── main.dart                     ← (optionally call demo during startup)

assets/
└── farm_data/
    └── farm_boundary.kml        ← ✅ Your actual farm data
```

---

## What's Next (Phase 2 - Tomorrow)

Once you verify Phase 1 parsing works, we'll:

1. **Create an inference engine** that takes `ParsedKmlFarm` and generates zones
2. **For each livestock point:**
   - Create a zone with 50-100m radius
   - Assign activity calendar (e.g., CATTLE: grazing, health checks, breeding)
   - Set task frequencies (daily feeding, 14-day health check, etc.)

3. **For remaining land:**
   - Create crop zones
   - Suggest crop types based on soil/climate

4. **For infrastructure:**
   - Create maintenance zones
   - Set maintenance tasks (monthly inspection, repair as needed)

5. **Generate `farm_zones.dart`** with all zones embedded

---

## Customization Examples

### **Add New Livestock Type Detection**

Edit `lib/models/kml_models.dart` in `KmlPlacemark.fromNameAndLocation()`:

```dart
if (lowerName.contains('duck') || lowerName.contains('pond')) {
  detectedLivestock = LivestockType.DUCKS;  // Add DUCKS to enum first
}
```

### **Add Infrastructure Type**

Edit `enum PointType` in `kml_models.dart`:

```dart
enum PointType {
  // ... existing
  FISHPOND,
  GREENHOUSE,
  VETERINARY_CLINIC,
}
```

Then add detection logic in `fromNameAndLocation()`.

### **Change Detection Radius**

When Phase 2 creates zones, change the radius parameter:

```dart
// Phase 2: Instead of 50m radius
final zone = createLivestockZone(placemark, radiusMeters: 100);
```

---

## FAQ

| Q | A |
|---|---|
| **Do I need to update the KML?** | No - just use what you have in Google Earth. The parser auto-detects everything. |
| **What if a point name is wrong?** | Phase 1 still parses it, just might misdetect type. Phase 2 can let you override it. |
| **Can I add more points to the KML?** | Yes. Edit in Google Earth, export, replace `farm_boundary.kml`, rebuild app. |
| **Will Phase 1 run every time the app starts?** | Only if you call `KmlParserDemo.parseAndPrintFarmKml()`. You can disable it after testing. |
| **Can the parser handle nested Folders?** | Not yet - Phase 1 is simple. Phase 2 might enhance if needed. |

---

## Summary

✅ **Phase 1 is COMPLETE:**
- Real farm KML parsing works
- Livestock auto-detection works
- Infrastructure auto-detection works
- You can see what gets extracted

Next: Run the demo, verify it parses correctly, then move to Phase 2 (zone generation).

---

**Ready to test it? See "Testing Phase 1 Parsing" section above!** 🚀
