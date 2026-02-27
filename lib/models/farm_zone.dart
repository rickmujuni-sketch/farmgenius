// Core data models for FarmGenius zones, tasks, and activities

/// Geographic point (latitude, longitude)
class GeoPoint {
  final double lat;
  final double lng;

  const GeoPoint({required this.lat, required this.lng});

  /// Calculate distance to another point in kilometers (haversine)
  double distanceTo(GeoPoint other) {
    const R = 6371; // Earth radius in km
    final dLat = _toRad(other.lat - lat);
    final dLng = _toRad(other.lng - lng);
    final a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
        Math.cos(_toRad(lat)) * Math.cos(_toRad(other.lat)) *
            Math.sin(dLng / 2) * Math.sin(dLng / 2);
    final c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return R * c;
  }

  static double _toRad(double deg) => deg * (3.14159265359 / 180);
}

import 'dart:math' as Math;

/// Zone type enumeration
enum ZoneType {
  CROP,
  LIVESTOCK,
  INFRASTRUCTURE,
}

/// Activity stage in a zone's lifecycle
enum ActivityStage {
  PLANTING,
  GERMINATION,
  GROWTH,
  FLOWERING,
  GRAIN_FILL,
  HARVEST,
  GRAZING,
  SUPPLEMENTAL_FEEDING,
  HEALTH_CHECK,
  BREEDING,
  CALVING,
  MAINTENANCE,
  REPAIR,
  CLEANING,
  INSPECTION,
  SEASONAL_CHECK,
}

/// A farm zone - immutable, defined in KML at compile time
class FarmZone {
  final String id;
  final String name;
  final String description;
  final ZoneType type;
  final double areaHectares;
  final List<GeoPoint> boundary;
  final Map<String, String> metadata;

  const FarmZone({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.areaHectares,
    required this.boundary,
    this.metadata = const {},
  });

  /// Get center point of zone (simple average)
  GeoPoint get center {
    if (boundary.isEmpty) return const GeoPoint(lat: 0, lng: 0);
    final avgLat = boundary.map((p) => p.lat).reduce((a, b) => a + b) / boundary.length;
    final avgLng = boundary.map((p) => p.lng).reduce((a, b) => a + b) / boundary.length;
    return GeoPoint(lat: avgLat, lng: avgLng);
  }

  /// Get expected activities for this zone
  List<ActivityStage> get expectedActivities {
    final calendarStr = metadata['expected_calendar'] ?? '';
    return calendarStr
        .split(',')
        .map((s) => ActivityStage.values.firstWhere(
              (e) => e.toString().split('.').last == s.trim(),
              orElse: () => ActivityStage.INSPECTION,
            ))
        .toList();
  }

  /// Check if zone has a specific activity
  bool hasActivity(ActivityStage stage) => expectedActivities.contains(stage);
}

/// AI-generated task for staff
class Task {
  final String id;
  final String zoneId;
  final String title;
  final String description;
  final ActivityStage activity;
  final DateTime dueDate;
  final TaskPriority priority;
  final TaskStatus status;
  final DateTime createdAt;
  final String? createdByAI; // 'anomaly_detected', 'calendar_due', 'weather_risk', etc.
  final Map<String, dynamic> metadata;

  const Task({
    required this.id,
    required this.zoneId,
    required this.title,
    required this.description,
    required this.activity,
    required this.dueDate,
    this.priority = TaskPriority.MEDIUM,
    this.status = TaskStatus.PENDING,
    required this.createdAt,
    this.createdByAI,
    this.metadata = const {},
  });

  bool get isOverdue => status == TaskStatus.PENDING && DateTime.now().isAfter(dueDate);

  bool get isDueToday {
    final now = DateTime.now();
    return dueDate.year == now.year &&
        dueDate.month == now.month &&
        dueDate.day == now.day &&
        status == TaskStatus.PENDING;
  }

  /// Create a copy with updated fields
  Task copyWith({
    TaskStatus? status,
    Map<String, dynamic>? metadata,
  }) {
    return Task(
      id: id,
      zoneId: zoneId,
      title: title,
      description: description,
      activity: activity,
      dueDate: dueDate,
      priority: priority,
      status: status ?? this.status,
      createdAt: createdAt,
      createdByAI: createdByAI,
      metadata: metadata ?? this.metadata,
    );
  }
}

enum TaskPriority { LOW, MEDIUM, HIGH, URGENT }

enum TaskStatus { PENDING, IN_PROGRESS, COMPLETED, CANCELLED, OVERDUE }

/// Record of work done by staff
class ActivityLog {
  final String id;
  final String taskId;
  final String zoneId;
  final String staffId;
  final ActivityStage activity;
  final DateTime loggedAt;
  final Map<String, String> photoUrls; // 'before', 'after', 'evidence'
  final String notes;
  final int? quantity; // crops harvested, animals treated, etc.
  final String? quantityUnit; // kg, head, liters, etc.
  final double? cost; // TZS

  const ActivityLog({
    required this.id,
    required this.taskId,
    required this.zoneId,
    required this.staffId,
    required this.activity,
    required this.loggedAt,
    this.photoUrls = const {},
    required this.notes,
    this.quantity,
    this.quantityUnit,
    this.cost,
  });
}

/// AI insight or anomaly detected
class AnomalyDetection {
  final String id;
  final String zoneId;
  final AnomalyType type;
  final String title;
  final String description;
  final double severity; // 0.0 to 1.0
  final DateTime detectedAt;
  final Map<String, dynamic> data;

  const AnomalyDetection({
    required this.id,
    required this.zoneId,
    required this.type,
    required this.title,
    required this.description,
    required this.severity,
    required this.detectedAt,
    this.data = const {},
  });
}

enum AnomalyType {
  ACTIVITY_GAP, // no activity for too long
  COST_SPIKE, // unexpected cost increase
  YIELD_RISK, // potential yield reduction
  WEATHER_ALERT, // weather event
  HEALTH_ISSUE, // livestock health concern
}

/// Weather data from NASA POWER API
class WeatherData {
  final String zoneId;
  final DateTime date;
  final double temperatureC;
  final double humidity;
  final double rainfall; // mm
  final double windSpeed; // m/s
  final double soilMoisture; // %

  const WeatherData({
    required this.zoneId,
    required this.date,
    required this.temperatureC,
    required this.humidity,
    required this.rainfall,
    required this.windSpeed,
    required this.soilMoisture,
  });
}
