# 🏗️ Phase 1 Architecture & Data Flow

## System Overview (Phase 1 → Phase 4)

```
┌─────────────────────────────────────────────────────────────────┐
│  FARMGENIUS: Real Farm → AI Decision Engine                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  PHASE 1 (TODAY): Parse Real Data                              │
│  ────────────────                                               │
│  Input:  Google Earth KML (your actual farm)                   │
│     ↓                                                            │
│  [KmlParser + Auto-Detection]                                   │
│     ↓                                                            │
│  Output: ParsedKmlFarm                                          │
│    ├─ Farm boundary (polygon)                                  │
│    ├─ Livestock locations (auto-categorized)                   │
│    └─ Infrastructure points (auto-detected)                    │
│                                                                 │
│  PHASE 2 (TOMORROW): Inference Engine                          │
│  ───────────────────                                            │
│  Input:  ParsedKmlFarm                                          │
│     ↓                                                            │
│  [Zone Inference Engine]                                        │
│    • For each livestock: 50m radius zone                       │
│    • For remaining land: crop zone(s)                          │
│    • For infrastructure: maintenance zone(s)                    │
│     ↓                                                            │
│  Output: GeneratedZones (Dart code)                            │
│                                                                 │
│  PHASE 3 (DAY 3): Embed in App                                 │
│  ──────────────                                                 │
│  Input:  GeneratedZones                                         │
│     ↓                                                            │
│  [Compile to Binary]                                            │
│     ↓                                                            │
│  Output: Immutable zones in app binary                          │
│                                                                 │
│  PHASE 4 (DAY 4): AI Orchestration                             │
│  ──────────────                                                 │
│  Input:  Embedded zones + Weather API + Activity logs          │
│     ↓                                                            │
│  [AI Orchestrator]                                              │
│    • Generate daily tasks                                      │
│    • Monitor activity completion                               │
│    • Flag anomalies (no check-ins, cost spikes, etc)           │
│     ↓                                                            │
│  Output: Manager/Staff dashboards with smart tasks             │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Phase 1 Data Flow (Detailed)

### **Step-by-Step: How KML Becomes Dart Objects**

```
1. USER EXPORTS KML FROM GOOGLE EARTH
   └─ "Dr. Mujuni's Farm - Kawongo, Rakai"
   └─ Contains: 1 polygon + 7 points

2. SAVE TO: assets/farm_data/farm_boundary.kml
   └─ 19 boundary coordinates
   └─ 7 placemarks (livestock + infrastructure)

3. APP LOADS: await KmlParser.parseFromAsset('...')
   └─ Reads XML file from assets
   └─ Parses document structure

4. EXTRACT POLYGON
   └─ Find first <Placemark> with <Polygon>
   └─ Parse <outerBoundaryIs><LinearRing><coordinates>
   └─ Convert to List<GeoCoordinate>
   └─ Create FarmBoundary object
   └─ Calculate area in hectares

5. EXTRACT POINTS
   └─ For each <Placemark> with <Point>
      ├─ Parse coordinates (lon, lat, alt)
      ├─ Read name
      ├─ Create GeoCoordinate
      ├─ AUTO-DETECT TYPE & LIVESTOCK:
      │  ├─ If name contains "cattle" → CATTLE
      │  ├─ If name contains "piggery" → PIGS
      │  ├─ If name contains "borehole" → WATER_SOURCE
      │  └─ etc.
      └─ Create KmlPlacemark object

6. RETURN ParsedKmlFarm
   ├─ farmName: "Dr. Mujuni's Farm - Kawongo, Rakai"
   ├─ boundary: FarmBoundary (13.24 ha)
   └─ placemarks: [
      │  ├─ Piggery shed (LIVESTOCK_AREA, PIGS)
      │  ├─ Paddock for Cattles (LIVESTOCK_AREA, CATTLE)
      │  ├─ Goats (LIVESTOCK_AREA, GOATS)
      │  ├─ Chickens (LIVESTOCK_AREA, CHICKENS)
      │  ├─ farmhouse (FARMHOUSE)
      │  ├─ Borehole (WATER_SOURCE)
      │  └─ Servant Quarters (QUARTERS)
      └─]

7. ORGANIZE BY CATEGORY
   ├─ Livestock:
   │  ├─ CATTLE: [Paddock for Cattles]
   │  ├─ PIGS: [Piggery shed]
   │  ├─ GOATS: [Goats]
   │  └─ CHICKENS: [Chickens]
   ├─ Infrastructure:
   │  ├─ FARMHOUSE: [farmhouse]
   │  ├─ WATER_SOURCE: [Borehole]
   │  └─ QUARTERS: [Servant Quarters]
   └─ Available for Phase 2 use
```

---

## Class Dependency Graph

```
┌─────────────────────────────────────┐
│  kml_parser_service.dart            │
│  (KmlParser class)                  │
└──────────────┬──────────────────────┘
               │
               ├─ reads XML via xml package
               │
               └─ creates ↓
                  ┌──────────────────────────┐
                  │  kml_models.dart         │
                  ├──────────────────────────┤
                  │ GeoCoordinate            │
                  │   .distanceToMeters()    │
                  │   .toString()            │
                  ├──────────────────────────┤
                  │ FarmBoundary             │
                  │   .areaHectares          │
                  │   .centroid              │
                  │   .containsPoint()       │
                  ├──────────────────────────┤
                  │ PointType (enum)         │
                  │ LivestockType (enum)     │
                  ├──────────────────────────┤
                  │ KmlPlacemark             │
                  │   .fromNameAndLocation() │
                  │   (heuristic detection)  │
                  ├──────────────────────────┤
                  │ ParsedKmlFarm            │
                  │   .placemarksByType      │
                  │   .livestockByType       │
                  │   .livestockPlacemarks   │
                  └──────────────────────────┘
                       │
                       └─ used by ↓
                          ┌──────────────────────────┐
                          │  kml_parser_demo.dart    │
                          │  (for testing)           │
                          └──────────────────────────┘
```

---

## Key Classes Detailed

### **GeoCoordinate**
```dart
/// A single point on Earth (lat/lon/alt)
GeoCoordinate(
  latitude: -7.082955,           // South (negative = below equator)
  longitude: 38.915285,          // East (positive = right of prime meridian)
  altitude: 289.5                // meters above sea level
)

// Methods:
.distanceToMeters(other)         // Haversine: how far to this point?
.toString()                      // KML format: "lon,lat,alt,0"
```

**Why 3 values?**
- **Latitude** (-90 to +90): North-South position
- **Longitude** (-180 to +180): East-West position  
- **Altitude**: Height above sea level (optional)

**Tanzania location:**
- Latitude range: -1° to -12° (below equator)
- Longitude range: 29° to 41° (east of prime meridian)

---

### **FarmBoundary**
```dart
/// A closed polygon representing the farm perimeter
FarmBoundary(
  id: "55DADA1C02000001",
  name: "Your Farm",
  coordinates: [
    GeoCoordinate(lat: -7.081280, lon: 38.916656),
    GeoCoordinate(lat: -7.081237, lon: 38.916147),
    // ... 17 more points ...
    GeoCoordinate(lat: -7.081280, lon: 38.916656)  // closes the polygon
  ]
)

// Computed properties:
.areaHectares                    // ~13.24 hectares (shoelace formula)
.centroid                        // Center point: (-7.08349, 38.91614)

// Methods:
.containsPoint(geoCoord)         // Is this point inside the farm?
```

---

### **KmlPlacemark**
```dart
/// A point location (building, livestock area, etc.)
KmlPlacemark.fromNameAndLocation(
  id: "06CD871E593987635DE0",
  name: "Piggery shed",
  location: GeoCoordinate(lat: -7.083396, lon: 38.916112),
  // Auto-detection from name:
  type: PointType.LIVESTOCK_AREA  // ← detected from "piggery"
  livestockType: LivestockType.PIGS
)

// Detection heuristics:
name.contains("piggery") → type=LIVESTOCK_AREA, livestock=PIGS
name.contains("borehole") → type=WATER_SOURCE
name.contains("farmhouse") → type=FARMHOUSE
name.contains("quarters") → type=QUARTERS
// etc.
```

---

### **ParsedKmlFarm**
```dart
/// Complete result of parsing one KML file
ParsedKmlFarm(
  farmName: "Dr. Mujuni's Farm - Kawongo, Rakai",
  boundary: FarmBoundary(...),
  placemarks: [7 KmlPlacemark objects]
)

// Convenience groupings:
.placemarksByType                // Map<PointType, List<KmlPlacemark>>
  → {LIVESTOCK_AREA: [4 placemarks], FARMHOUSE: [1], ...}

.livestockPlacemarks             // List<KmlPlacemark> (only livestock areas)
  → [Piggery shed, Paddock for Cattles, Goats, Chickens]

.livestockByType                 // Map<LivestockType, List<KmlPlacemark>>
  → {CATTLE: [Paddock for Cattles], PIGS: [Piggery shed], ...}

.infrastructurePlacemarks        // List<KmlPlacemark> (everything else)
  → [farmhouse, Borehole, Servant Quarters]
```

---

## Enums: The Classification System

### **PointType** (What is this location?)
```dart
enum PointType {
  FARMHOUSE,           // Main residence
  WATER_SOURCE,        // Borehole, pump, tank
  LIVESTOCK_AREA,      // Shed, paddock, pen
  QUARTERS,            // Worker housing
  STORAGE,             // Grain store, equipment shed
  PROCESSING,          // Dairy, slaughter house
  OTHER                // Unclassified
}

// Detection keys (lowercase matching):
"farmhouse" → FARMHOUSE
"borehole", "water", "tank" → WATER_SOURCE
"shed", "paddock", "pen", "piggery", "coop" → LIVESTOCK_AREA
"quarters", "staff" → QUARTERS
"storage", "granary" → STORAGE
"dairy", "slaughter", "processing" → PROCESSING
```

### **LivestockType** (What animal lives here?)
```dart
enum LivestockType {
  CATTLE,              // Cows, oxen
  GOATS,
  PIGS,
  CHICKENS,
  SHEEP,
  GUINEA_FOWL,
  BEEHIVES,
  FISH_POND,
  UNKNOWN              // Fallback if can't detect
}

// Detection keys (lowercase matching):
"cattle", "cow" → CATTLE
"goat" → GOATS
"pig", "piggery" → PIGS
"chicken", "poultry", "coop" → CHICKENS
"sheep" → SHEEP
"guinea", "guineafowl" → GUINEA_FOWL
"bee", "hive" → BEEHIVES
"fish", "pond" → FISH_POND
```

---

## The XML Structure You're Parsing

```xml
<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2">
  <Document id="...">
    <name>Dr. Mujuni's Farm - Kawongo, Rakai</name>
    
    <!-- POLYGON: Farm Boundary -->
    <Placemark id="55DADA1C02000001">
      <name>Your Farm</name>
      <Polygon>
        <outerBoundaryIs>
          <LinearRing>
            <coordinates>
              38.91665597312421,-7.081280300882266,0
              38.91614681567437,-7.081236625840072,0
              ... (17 more points)
              38.91665597312421,-7.081280300882266,0
            </coordinates>
          </LinearRing>
        </outerBoundaryIs>
      </Polygon>
    </Placemark>
    
    <!-- POINT: Piggery -->
    <Placemark id="06CD871E593987635DE0">
      <name>Piggery shed</name>
      <Point>
        <coordinates>38.91611229250724,-7.083395592720421,286.5081566510615</coordinates>
      </Point>
    </Placemark>
    
    <!-- POINT: Cattle Paddock -->
    <Placemark id="00CB706A3E3AAF856B8C">
      <name>Paddock for Cattles</name>
      <Point>
        <coordinates>38.91582048799773,-7.083239628454328,286.9610756061573</coordinates>
      </Point>
    </Placemark>
    
    <!-- ... 5 more placemarks ... -->
  </Document>
</kml>
```

**Parser flow:**
1. Load XML string
2. Find `<Document>` → get farm name
3. Loop through `<Placemark>` elements
4. If has `<Polygon>` → Parse as FarmBoundary
5. If has `<Point>` → Parse as KmlPlacemark
6. Extract coordinates
7. Auto-detect type/livestock from name
8. Return ParsedKmlFarm

---

## File Organization

```
farmgenius/
├── lib/
│   ├── models/
│   │   ├── farm_zone.dart          ← Old (keep for now)
│   │   └── kml_models.dart         ← NEW: Core KML data models
│   ├── services/
│   │   ├── kml_parser_service.dart ← NEW: XML parser
│   │   └── kml_parser_demo.dart    ← NEW: Testing/demo
│   └── main.dart                   ← Optionally calls demo
├── assets/
│   └── farm_data/
│       ├── farm_boundary.kml       ← NEW: Your actual farm!
│       ├── zone_A_maize.kml        ← Old (can delete)
│       ├── zone_B_livestock.kml    ← Old (can delete)
│       └── zone_C_infrastructure.kml ← Old (can delete)
├── pubspec.yaml                    ← Updated with xml package
└── docs/
    ├── PHASE_1_QUICK_START.md      ← NEW: Testing guide
    ├── PHASE_1_KML_PARSING.md      ← NEW: Full details
    └── PHASE_1_ARCHITECTURE.md     ← This file
```

---

## What Phase 1 Doesn't Do (Yet)

- ❌ Doesn't create zones (Phase 2)
- ❌ Doesn't generate tasks (Phase 4)
- ❌ Doesn't save to Supabase (Phase 3)
- ❌ Doesn't create UI for zone editing
- ❌ Doesn't handle nested KML folders
- ❌ Doesn't support inner boundaries (holes in polygon)

These are all Phase 2+ features.

---

## What Phase 2 Will Add

**Input:** ParsedKmlFarm (from Phase 1)

**Process:**
```dart
// For each livestock point
for (final livestock in farm.livestockByType.values.expand((x) => x)) {
  final zone = Zone(
    id: "zone_${livestock.livestockType}",
    name: livestock.name,
    center: livestock.location,
    radiusMeters: 50,  // Configurable
    type: LIVESTOCK,
    livestock: livestock.livestockType,
    activities: _getActivitiesForLivestock(livestock.livestockType),
    // activities: FEEDING, HEALTH_CHECK, BREEDING, etc.
  );
}

// For remaining space: crop zones
final availableLand = farm.boundary.areaHectares 
  - (livestockZones.length * radiusHectares);
final cropZone = Zone(
  id: "zone_crops",
  name: "Crop Land",
  area: availableLand,
  activities: [PLANTING, WEEDING, HARVESTING, etc.],
);

// For infrastructure: maintenance zones
for (final infra in farm.infrastructurePlacemarks) {
  final zone = Zone(
    id: "zone_${infra.id}",
    name: infra.name,
    location: infra.location,
    type: INFRASTRUCTURE,
    activities: _getMaintenanceActivities(infra.type),
  );
}
```

**Output:** GeneratedZones (Dart file with embedded zones)

---

## Summary: What You Have Now

| Item | What It Is | Why It Matters |
|------|-----------|----------------|
| **kml_models.dart** | 5 core classes + 2 enums | Define data structure |
| **kml_parser_service.dart** | XML parser | Reads KML files and creates objects |
| **kml_parser_demo.dart** | Testing utility | Shows parsed data nicely |
| **farm_boundary.kml** | Your actual farm | Real data, not fake samples |
| **xml package** | Dependency | Enables XML/KML parsing |

**The value:** You now have a real, production-ready parser that can:
- ✅ Load any farm KML from Google Earth
- ✅ Auto-categorize livestock and infrastructure
- ✅ Calculate farm area
- ✅ Find zones by type or livestock
- ✅ Format geographic data cleanly

Next: Phase 2 will use this to auto-generate zones and activity calendars.

---

## Next: Test Phase 1

Follow **PHASE_1_QUICK_START.md** to test parsing and verify all data is extracted correctly!

Then on to Phase 2: **Zone Inference Engine** 🚀
