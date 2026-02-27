import 'package:flutter/material.dart';
import '../models/farm_zone.dart';
import '../models/generated_farm_zones.dart';
import 'supabase_service.dart';
import 'weather_service.dart';

/// The AI Orchestrator: self-driving farm management engine
/// 
/// Responsibilities:
/// - Check each zone against its expected activity calendar
/// - Automatically create tasks when activities are due
/// - Monitor weather and create risk mitigation tasks
/// - Detect anomalies (cost spikes, activity gaps, yield risks)
/// - Generate insights for managers
class AIOrchestrator extends ChangeNotifier {
  static const String _tableTasks = 'tasks';
  static const String _tableAnomalies = 'anomalies';
  static const String _tableLogs = 'activity_logs';

  List<FarmZone> zones = [];
  List<Task> generatedTasks = [];
  List<AnomalyDetection> detectedAnomalies = [];
  bool isRunning = false;

  AIOrchestrator() {
    // Load zones from generated KML data at startup
    zones = List.from(GeneratedFarmZones.zones);
  }

  /// Run the orchestrator - checks all zones and creates necessary tasks
  /// Can be called daily or on-demand
  Future<void> runDailyOrchestration() async {
    if (isRunning) return;
    isRunning = true;
    notifyListeners();

    try {
      generatedTasks.clear();
      detectedAnomalies.clear();

      // For each zone, check what activities are due and create tasks
      for (final zone in zones) {
        await _orchestrateZone(zone);
      }

      // Persist tasks and anomalies to Supabase
      await _persistTasks();
      await _persistAnomalies();

      notifyListeners();
    } catch (e) {
      print('AIOrchestrator error: $e');
    } finally {
      isRunning = false;
      notifyListeners();
    }
  }

  /// Orchestrate a single zone
  Future<void> _orchestrateZone(FarmZone zone) async {
    // 1. Check calendar-based activities
    await _checkCalendarActivities(zone);

    // 2. Check weather and create risk mitigation tasks
    await _checkWeatherRisks(zone);

    // 3. Detect anomalies
    await _detectAnomalies(zone);
  }

  /// Check if zone activities are due based on expected calendar
  Future<void> _checkCalendarActivities(FarmZone zone) async {
    final expectedActivities = zone.expectedActivities;
    
    // For each expected activity, check if a task exists
    for (final activity in expectedActivities) {
      // Get the last completed or logged activity
      final lastLog = await _getLastActivityLog(zone.id, activity);
      
      // Determine if this activity is due
      final isDue = _isActivityDue(zone, activity, lastLog);
      
      if (isDue) {
        final task = _createTaskForActivity(zone, activity);
        generatedTasks.add(task);
      }
    }
  }

  /// Check weather and create precautionary tasks
  Future<void> _checkWeatherRisks(FarmZone zone) async {
    // Fetch weather for the zone
    final weather = await WeatherService.fetchWeatherForecast(
      lat: zone.center.lat,
      lng: zone.center.lng,
      days: 7,
    );

    if (weather.isEmpty) return;

    // Check upcoming weather against crop needs
    for (final w in weather.take(3)) {
      // Check next 3 days
      final risk = WeatherService.assessWeatherRisk(
        weather: w,
        activity: zone.expectedActivities.isNotEmpty
            ? zone.expectedActivities.first
            : ActivityStage.INSPECTION,
      );

      if (risk != 'LOW_RISK') {
        final task = Task(
          id: 'task_${zone.id}_weather_${DateTime.now().millisecondsSinceEpoch}',
          zoneId: zone.id,
          title: 'Weather Risk Mitigation: $risk',
          description:
              '${risk.replaceAll('_', ' ')} detected. Take precautionary measures.',
          activity: ActivityStage.INSPECTION,
          dueDate: w.date,
          priority: _riskToPriority(risk),
          status: TaskStatus.PENDING,
          createdAt: DateTime.now(),
          createdByAI: 'weather_risk',
          metadata: {'risk_type': risk, 'temperature': w.temperatureC, 'humidity': w.humidity},
        );
        generatedTasks.add(task);
      }
    }
  }

  /// Detect anomalies in zone behavior
  Future<void> _detectAnomalies(FarmZone zone) async {
    // 1. Check for activity gaps (no work done for too long)
    final lastLog = await _getLastActivityLog(zone.id);
    if (lastLog != null) {
      final daysSinceLastActivity = DateTime.now().difference(lastLog).inDays;
      if (daysSinceLastActivity > 14) {
        final anomaly = AnomalyDetection(
          id: 'anomaly_${zone.id}_gap_${DateTime.now().millisecondsSinceEpoch}',
          zoneId: zone.id,
          type: AnomalyType.ACTIVITY_GAP,
          title: 'Activity Gap Detected',
          description: 'No activity in ${zone.name} for $daysSinceLastActivity days',
          severity: (daysSinceLastActivity / 30).clamp(0.0, 1.0),
          detectedAt: DateTime.now(),
          data: {'days_since_activity': daysSinceLastActivity},
        );
        detectedAnomalies.add(anomaly);
      }
    }

    // 2. Check for cost anomalies (would need cost data in Supabase)
    // TODO: Implement cost anomaly detection when expense tracking is added

    // 3. Check livestock health status (if applicable)
    if (zone.type == ZoneType.LIVESTOCK) {
      await _checkLivestockAnomalies(zone);
    }
  }

  /// Check for livestock-specific anomalies
  Future<void> _checkLivestockAnomalies(FarmZone zone) async {
    // Check if health check tasks are overdue
    final lastHealthCheck = await _getLastActivityLog(zone.id, ActivityStage.HEALTH_CHECK);
    if (lastHealthCheck != null) {
      final daysOverdue = DateTime.now().difference(lastHealthCheck).inDays - 30;
      if (daysOverdue > 0) {
        final anomaly = AnomalyDetection(
          id: 'anomaly_${zone.id}_health_${DateTime.now().millisecondsSinceEpoch}',
          zoneId: zone.id,
          type: AnomalyType.HEALTH_ISSUE,
          title: 'Health Check Overdue',
          description: 'Livestock in ${zone.name} has not had health check for $daysOverdue days',
          severity: (daysOverdue / 60).clamp(0.2, 1.0),
          detectedAt: DateTime.now(),
          data: {'days_overdue': daysOverdue},
        );
        detectedAnomalies.add(anomaly);
      }
    }
  }

  /// Check if an activity is due for a zone
  bool _isActivityDue(FarmZone zone, ActivityStage activity, DateTime? lastTime) {
    // Simple rules - in production, use crop-specific calendars
    const int defaultDays = 7; // Re-check activities weekly by default

    if (lastTime == null) {
      // Never done - check against planting/start date
      final plantingStr = zone.metadata['planting_date'];
      if (plantingStr != null && activity == ActivityStage.PLANTING) {
        final plantingDate = DateTime.parse(plantingStr);
        return DateTime.now().isAfter(plantingDate);
      }
      return false;
    }

    // Check if overdue based on activity type
    final daysSinceLastTime = DateTime.now().difference(lastTime).inDays;

    // Different intervals for different activities
    final intervalDays = _getActivityInterval(activity);
    return daysSinceLastTime >= intervalDays;
  }

  /// Get recommended interval between activity occurrences
  int _getActivityInterval(ActivityStage activity) {
    switch (activity) {
      case ActivityStage.HEALTH_CHECK:
      case ActivityStage.GRAZING:
        return 7; // Weekly
      case ActivityStage.INSPECTION:
      case ActivityStage.MAINTENANCE:
        return 14; // Bi-weekly
      case ActivityStage.PLANTING:
      case ActivityStage.HARVEST:
        return 365; // Once per year
      default:
        return 7;
    }
  }

  /// Create a task for an activity
  Task _createTaskForActivity(FarmZone zone, ActivityStage activity) {
    final now = DateTime.now();
    return Task(
      id: 'task_${zone.id}_${activity.toString()}_$now.millisecondsSinceEpoch',
      zoneId: zone.id,
      title: '${activity.toString().split('.').last.replaceAll('_', ' ')} - ${zone.name}',
      description: 'Perform ${activity.toString().split('.').last} activities in ${zone.name}',
      activity: activity,
      dueDate: now.add(const Duration(days: 1)),
      priority: TaskPriority.MEDIUM,
      status: TaskStatus.PENDING,
      createdAt: now,
      createdByAI: 'calendar_due',
      metadata: {'zone_type': zone.type.toString()},
    );
  }

  /// Convert risk type to priority
  TaskPriority _riskToPriority(String risk) {
    if (risk.contains('HIGH') || risk.contains('HEAT') || risk.contains('FUNGAL')) {
      return TaskPriority.HIGH;
    }
    if (risk.contains('EXTREME') || risk.contains('RISK')) {
      return TaskPriority.URGENT;
    }
    return TaskPriority.MEDIUM;
  }

  /// Get last activity log for a zone
  Future<DateTime?> _getLastActivityLog(String zoneId, [ActivityStage? activity]) async {
    try {
      var query = SupabaseService.client
          .from(_tableLogs)
          .select('logged_at')
          .eq('zone_id', zoneId)
          .order('logged_at', ascending: false)
          .limit(1);

      if (activity != null) {
        query = query.eq('activity', activity.toString().split('.').last);
      }

      final result = await query.execute();
      if (result.error == null && result.data != null && (result.data as List).isNotEmpty) {
        final loggedAtStr = (result.data as List).first['logged_at'] as String?;
        if (loggedAtStr != null) {
          return DateTime.parse(loggedAtStr);
        }
      }
    } catch (e) {
      print('Error fetching activity logs: $e');
    }
    return null;
  }

  /// Persist generated tasks to Supabase
  Future<void> _persistTasks() async {
    try {
      for (final task in generatedTasks) {
        // Check if task already exists
        final existing = await SupabaseService.client
            .from(_tableTasks)
            .select()
            .eq('id', task.id)
            .execute();

        if (existing.error == null && (existing.data as List).isEmpty) {
          // Task doesn't exist - create it
          await SupabaseService.client.from(_tableTasks).insert({
            'id': task.id,
            'zone_id': task.zoneId,
            'title': task.title,
            'description': task.description,
            'activity': task.activity.toString().split('.').last,
            'due_date': task.dueDate.toIso8601String(),
            'priority': task.priority.toString().split('.').last,
            'status': task.status.toString().split('.').last,
            'created_at': task.createdAt.toIso8601String(),
            'created_by_ai': task.createdByAI,
            'metadata': task.metadata,
          }).execute();
        }
      }
    } catch (e) {
      print('Error persisting tasks: $e');
    }
  }

  /// Persist anomalies to Supabase
  Future<void> _persistAnomalies() async {
    try {
      for (final anomaly in detectedAnomalies) {
        await SupabaseService.client.from(_tableAnomalies).insert({
          'id': anomaly.id,
          'zone_id': anomaly.zoneId,
          'type': anomaly.type.toString().split('.').last,
          'title': anomaly.title,
          'description': anomaly.description,
          'severity': anomaly.severity,
          'detected_at': anomaly.detectedAt.toIso8601String(),
          'data': anomaly.data,
        }).execute();
      }
    } catch (e) {
      print('Error persisting anomalies: $e');
    }
  }

  /// Get pending tasks for staff
  Future<List<Task>> getPendingTasksForStaff() async {
    try {
      final result = await SupabaseService.client
          .from(_tableTasks)
          .select()
          .eq('status', 'PENDING')
          .order('due_date', ascending: true)
          .execute();

      if (result.error == null && result.data != null) {
        return (result.data as List)
            .map((t) => _taskFromMap(t as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      print('Error fetching tasks: $e');
    }
    return [];
  }

  /// Get anomalies for manager dashboard
  Future<List<AnomalyDetection>> getAnomalies() async {
    try {
      final result = await SupabaseService.client
          .from(_tableAnomalies)
          .select()
          .order('detected_at', ascending: false)
          .limit(50)
          .execute();

      if (result.error == null && result.data != null) {
        return (result.data as List).map((a) => _anomalyFromMap(a as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      print('Error fetching anomalies: $e');
    }
    return [];
  }

  /// Convert map from DB to Task object
  Task _taskFromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'],
      zoneId: map['zone_id'],
      title: map['title'],
      description: map['description'],
      activity: ActivityStage.values.firstWhere(
        (e) => e.toString().split('.').last == map['activity'],
        orElse: () => ActivityStage.INSPECTION,
      ),
      dueDate: DateTime.parse(map['due_date']),
      priority: TaskPriority.values.firstWhere(
        (e) => e.toString().split('.').last == map['priority'],
        orElse: () => TaskPriority.MEDIUM,
      ),
      status: TaskStatus.values.firstWhere(
        (e) => e.toString().split('.').last == map['status'],
        orElse: () => TaskStatus.PENDING,
      ),
      createdAt: DateTime.parse(map['created_at']),
      createdByAI: map['created_by_ai'],
      metadata: (map['metadata'] as Map<String, dynamic>?) ?? {},
    );
  }

  /// Convert map from DB to AnomalyDetection object
  AnomalyDetection _anomalyFromMap(Map<String, dynamic> map) {
    return AnomalyDetection(
      id: map['id'],
      zoneId: map['zone_id'],
      type: AnomalyType.values.firstWhere(
        (e) => e.toString().split('.').last == map['type'],
        orElse: () => AnomalyType.ACTIVITY_GAP,
      ),
      title: map['title'],
      description: map['description'],
      severity: (map['severity'] as num?)?.toDouble() ?? 0.5,
      detectedAt: DateTime.parse(map['detected_at']),
      data: (map['data'] as Map<String, dynamic>?) ?? {},
    );
  }
}
