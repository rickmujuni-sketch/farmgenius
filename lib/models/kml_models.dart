/// Models for KML parsing and manipulation
/// Used in Phase 1: Parse actual farm KML
/// Represents raw KML data before zone inference
library;

import 'dart:math' as math;

/// Represents a geographic coordinate (latitude, longitude)
class GeoCoordinate {
  final double latitude;
  final double longitude;
  final double? altitude;

  GeoCoordinate({
    required this.latitude,
    required this.longitude,
    this.altitude,
  });

  /// Format as "lat,lng,alt" (KML coordinate string)
  @override
  String toString() =>
      '$longitude,$latitude${altitude != null ? ',$altitude' : ''},0';

  /// Haversine distance between two points in meters
  double distanceToMeters(GeoCoordinate other) {
    const int earthRadiusMeters = 6371000;

    double dLat = _toRadians(other.latitude - latitude);
    double dLon = _toRadians(other.longitude - longitude);

    double a = (math.sin(dLat / 2) * math.sin(dLat / 2)) +
        (math.cos(_toRadians(latitude)) *
            math.cos(_toRadians(other.latitude)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2));

    double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusMeters * c;
  }

  double _toRadians(double degrees) => degrees * (3.14159265359 / 180);
}

/// Represents a farm boundary polygon extracted from KML
class FarmBoundary {
  final String id;
  final String name;
  final List<GeoCoordinate> coordinates;

  /// Calculate approximate area in hectares (simplified)
  double get areaHectares {
    if (coordinates.length < 3) return 0;
    return _calculatePolygonArea() / 10000; // m² to hectares
  }

  /// Calculate centroid of polygon
  GeoCoordinate get centroid {
    double sumLat = 0, sumLng = 0;
    for (var coord in coordinates) {
      sumLat += coord.latitude;
      sumLng += coord.longitude;
    }
    return GeoCoordinate(
      latitude: sumLat / coordinates.length,
      longitude: sumLng / coordinates.length,
    );
  }

  FarmBoundary({
    required this.id,
    required this.name,
    required this.coordinates,
  });

  /// Shoelace formula for polygon area (in square meters, approximate)
  double _calculatePolygonArea() {
    double area = 0;
    for (int i = 0; i < coordinates.length; i++) {
      int j = (i + 1) % coordinates.length;
      area += coordinates[i].longitude * coordinates[j].latitude;
      area -= coordinates[j].longitude * coordinates[i].latitude;
    }
    return (area.abs() / 2) * 111000 * 111000; // approximate conversion to m²
  }

  /// Check if a point is inside the farm boundary (point-in-polygon)
  bool containsPoint(GeoCoordinate point) {
    int crossings = 0;
    for (int i = 0; i < coordinates.length; i++) {
      int j = (i + 1) % coordinates.length;
      GeoCoordinate p1 = coordinates[i];
      GeoCoordinate p2 = coordinates[j];

      if ((p1.latitude <= point.latitude && point.latitude < p2.latitude) ||
          (p2.latitude <= point.latitude && point.latitude < p1.latitude)) {
        double xinters = (point.latitude - p1.latitude) /
                (p2.latitude - p1.latitude) *
                (p2.longitude - p1.longitude) +
            p1.longitude;
        if (point.longitude < xinters) crossings++;
      }
    }
    return (crossings % 2) == 1;
  }
}

/// Type of infrastructure/livestock point
enum PointType {
  FARMHOUSE,      // Main residence
  WATER_SOURCE,   // Borehole, water tank
  LIVESTOCK_AREA, // Paddock, shed, pen
  QUARTERS,       // Worker quarters
  STORAGE,        // Grain/equipment storage
  PROCESSING,     // Dairy, slaughter, etc
  OTHER
}

/// Livestock type detected from point name
enum LivestockType {
  CATTLE,
  GOATS,
  PIGS,
  CHICKENS,
  SHEEP,
  GUINEA_FOWL,
  BEEHIVES,
  FISH_POND,
  UNKNOWN
}

/// Represents a point (infrastructure or livestock) from KML
class KmlPlacemark {
  final String id;
  final String name;
  final GeoCoordinate location;
  final PointType? type;
  final LivestockType? livestockType;
  final Map<String, dynamic>? metadata; // ExtendedData as JSON

  KmlPlacemark({
    required this.id,
    required this.name,
    required this.location,
    this.type,
    this.livestockType,
    this.metadata,
  });

  /// Infer point type and livestock heuristically from name
  factory KmlPlacemark.fromNameAndLocation({
    required String id,
    required String name,
    required GeoCoordinate location,
    Map<String, dynamic>? metadata,
  }) {
    PointType? detectedType;
    LivestockType? detectedLivestock;

    final lowerName = name.toLowerCase();

    // Detect point type
    if (lowerName.contains('farmhouse') || lowerName.contains('house')) {
      detectedType = PointType.FARMHOUSE;
    } else if (lowerName.contains('borehole') ||
        lowerName.contains('water') ||
        lowerName.contains('tank')) {
      detectedType = PointType.WATER_SOURCE;
    } else if (lowerName.contains('quarters') || lowerName.contains('staff')) {
      detectedType = PointType.QUARTERS;
    } else if (lowerName.contains('storage') || lowerName.contains('granary')) {
      detectedType = PointType.STORAGE;
    } else if (lowerName.contains('shed') ||
        lowerName.contains('paddock') ||
        lowerName.contains('pen') ||
        lowerName.contains('pen') ||
        lowerName.contains('piggery') ||
        lowerName.contains('coop') ||
        lowerName.contains('kraal')) {
      detectedType = PointType.LIVESTOCK_AREA;
    }

    // Detect livestock type
    if (lowerName.contains('cattle') || lowerName.contains('cow')) {
      detectedLivestock = LivestockType.CATTLE;
    } else if (lowerName.contains('goat')) {
      detectedLivestock = LivestockType.GOATS;
    } else if (lowerName.contains('pig') || lowerName.contains('piggery')) {
      detectedLivestock = LivestockType.PIGS;
    } else if (lowerName.contains('chicken') ||
        lowerName.contains('poultry') ||
        lowerName.contains('coop')) {
      detectedLivestock = LivestockType.CHICKENS;
    } else if (lowerName.contains('sheep')) {
      detectedLivestock = LivestockType.SHEEP;
    } else if (lowerName.contains('guinea') || lowerName.contains('guineafowl')) {
      detectedLivestock = LivestockType.GUINEA_FOWL;
    } else if (lowerName.contains('bee') || lowerName.contains('hive')) {
      detectedLivestock = LivestockType.BEEHIVES;
    } else if (lowerName.contains('fish') || lowerName.contains('pond')) {
      detectedLivestock = LivestockType.FISH_POND;
    }

    if (detectedType == null && detectedLivestock != null) {
      detectedType = PointType.LIVESTOCK_AREA;
    }

    return KmlPlacemark(
      id: id,
      name: name,
      location: location,
      type: detectedType ?? PointType.OTHER,
      livestockType: detectedLivestock,
      metadata: metadata,
    );
  }

  @override
  String toString() => 'Placemark($name @ ${location.latitude}, ${location.longitude})';
}

/// Result of KML parsing - contains extracted data
class ParsedKmlFarm {
  final String farmName;
  final FarmBoundary boundary;
  final List<KmlPlacemark> placemarks;

  ParsedKmlFarm({
    required this.farmName,
    required this.boundary,
    required this.placemarks,
  });

  /// Group placemarks by type
  Map<PointType, List<KmlPlacemark>> get placemarksByType {
    final groups = <PointType, List<KmlPlacemark>>{};
    for (var pm in placemarks) {
      if (pm.type != null) {
        groups.putIfAbsent(pm.type!, () => []).add(pm);
      }
    }
    return groups;
  }

  /// Filter only livestock placemarks
  List<KmlPlacemark> get livestockPlacemarks =>
      placemarks
        .where((p) =>
          p.type == PointType.LIVESTOCK_AREA || p.livestockType != null)
        .toList();

  /// Filter only infrastructure placemarks
  List<KmlPlacemark> get infrastructurePlacemarks =>
      placemarks.where((p) => p.type != PointType.LIVESTOCK_AREA).toList();

  /// Group livestock by type
  Map<LivestockType, List<KmlPlacemark>> get livestockByType {
    final groups = <LivestockType, List<KmlPlacemark>>{};
    for (var pm in livestockPlacemarks) {
      if (pm.livestockType != null) {
        groups.putIfAbsent(pm.livestockType!, () => []).add(pm);
      }
    }
    return groups;
  }

  @override
  String toString() =>
      'ParsedKmlFarm($farmName, boundary: ${boundary.name}, points: ${placemarks.length})';
}
