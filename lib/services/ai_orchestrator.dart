import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../models/farm_zone.dart';
import '../models/generated_farm_zones.dart';
import '../models/operations_assist.dart';
import 'operations_assist_service.dart';
import 'supabase_service.dart';
import 'weather_service.dart';
import 'zone_inference_engine.dart';

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
  Future<void>? _zoneLoadFuture;

  AIOrchestrator() {
    _zoneLoadFuture = _initializeZones();
  }

  Future<void> _initializeZones() async {
    try {
      final inferredZones =
          await ZoneInferenceEngine.inferZonesFromAsset('assets/farm_data/farm_boundary.kml');

      if (inferredZones.isNotEmpty) {
        zones = inferredZones;
        print('🔍 ZONES LOADED: ${zones.length} zones (source: zone_inference_engine)');
      } else {
        zones = GeneratedFarmZones.allZones;
        print('🔍 ZONES LOADED: ${zones.length} zones (fallback: generated_farm_zones.dart)');
      }
    } catch (e) {
      print('Zone inference failed, falling back to generated zones: $e');
      zones = GeneratedFarmZones.allZones;
      print('🔍 ZONES LOADED: ${zones.length} zones (fallback: generated_farm_zones.dart)');
    }

    notifyListeners();
  }

  /// Run the orchestrator - checks all zones and creates necessary tasks
  /// Can be called daily or on-demand
  Future<void> runDailyOrchestration() async {
    if (isRunning) return;

    if (_zoneLoadFuture != null) {
      await _zoneLoadFuture;
    }

    final allowed = await _canRunOrchestrationForCurrentUser();
    if (!allowed) {
      print('🤖 ORCHESTRATION SKIPPED: current user is not manager/owner');
      return;
    }

    isRunning = true;
    notifyListeners();

    print('🤖 ORCHESTRATION START: zones=${zones.length}');

    try {
      generatedTasks.clear();
      detectedAnomalies.clear();

      // For each zone, check what activities are due and create tasks
      for (final zone in zones) {
        await _orchestrateZone(zone);
      }

      await _applyAssistRecommendations();

      print('🤖 ORCHESTRATION GENERATED: tasks=${generatedTasks.length}, anomalies=${detectedAnomalies.length}');

      // Persist tasks and anomalies to Supabase
      await _persistTasks();
      await _persistAnomalies();

      print('🤖 ORCHESTRATION END: persisted tasks/anomalies cycle complete');

      notifyListeners();
    } catch (e) {
      print('AIOrchestrator error: $e');
    } finally {
      isRunning = false;
      notifyListeners();
    }
  }

  Future<bool> _canRunOrchestrationForCurrentUser() async {
    try {
      final userId = SupabaseService.client.auth.currentUser?.id;
      if (userId == null || userId.isEmpty) return false;

      final profile = await SupabaseService.client
          .from('profiles')
          .select<Map<String, dynamic>>('role')
          .eq('id', userId)
          .maybeSingle();

      final role = (profile['role'] ?? '').toString().toLowerCase();
      return role == 'manager' || role == 'owner';
    } catch (_) {
      return false;
    }
  }

  /// Orchestrate a single zone
  Future<void> _orchestrateZone(FarmZone zone) async {
    print('🤖 ORCHESTRATE ZONE: ${zone.id} (${zone.type})');
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
        final dateKey = _dateKey(w.date);
        final task = Task(
          id: 'task_${zone.id}_weather_${risk}_$dateKey',
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
        final dateKey = _dateKey(DateTime.now());
        final anomaly = AnomalyDetection(
          id: _generateUuidV4(),
          zoneId: zone.id,
          type: AnomalyType.ACTIVITY_GAP,
          title: 'Activity Gap Detected',
          description: 'No activity in ${zone.name} for $daysSinceLastActivity days',
          severity: (daysSinceLastActivity / 30).clamp(0.0, 1.0),
          detectedAt: DateTime.now(),
          data: {'days_since_activity': daysSinceLastActivity, 'date_key': dateKey},
        );
        detectedAnomalies.add(anomaly);
      }
    } else {
      final dateKey = _dateKey(DateTime.now());
      detectedAnomalies.add(
        AnomalyDetection(
          id: _generateUuidV4(),
          zoneId: zone.id,
          type: AnomalyType.ACTIVITY_GAP,
          title: 'No Activity Baseline',
          description: 'No activity logs found yet for ${zone.name}. Confirm operational baseline.',
          severity: 0.35,
          detectedAt: DateTime.now(),
          data: {'reason': 'no_activity_logs', 'date_key': dateKey},
        ),
      );
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
        final dateKey = _dateKey(DateTime.now());
        final anomaly = AnomalyDetection(
          id: _generateUuidV4(),
          zoneId: zone.id,
          type: AnomalyType.HEALTH_ISSUE,
          title: 'Health Check Overdue',
          description: 'Livestock in ${zone.name} has not had health check for $daysOverdue days',
          severity: (daysOverdue / 60).clamp(0.2, 1.0),
          detectedAt: DateTime.now(),
          data: {'days_overdue': daysOverdue, 'date_key': dateKey},
        );
        detectedAnomalies.add(anomaly);
      }
    } else {
      final dateKey = _dateKey(DateTime.now());
      detectedAnomalies.add(
        AnomalyDetection(
          id: _generateUuidV4(),
          zoneId: zone.id,
          type: AnomalyType.HEALTH_ISSUE,
          title: 'Initial Health Check Required',
          description: 'No health check history found for ${zone.name}. Schedule the first health check.',
          severity: 0.4,
          detectedAt: DateTime.now(),
          data: {'reason': 'no_health_check_logs', 'date_key': dateKey},
        ),
      );
    }
  }

  /// Check if an activity is due for a zone
  bool _isActivityDue(FarmZone zone, ActivityStage activity, DateTime? lastTime) {
    // Simple rules - in production, use crop-specific calendars
    if (lastTime == null) {
      // Never done - check against planting/start date
      final plantingStr = zone.metadata['planting_date'];
      if (plantingStr != null && activity == ActivityStage.PLANTING) {
        final plantingDate = DateTime.parse(plantingStr);
        return DateTime.now().isAfter(plantingDate);
      }
      // First-run behavior: if we have no logs yet, bootstrap expected activities
      // so the system can become proactive immediately.
      return true;
    }

    // Check if overdue based on activity type
    final daysSinceLastTime = DateTime.now().difference(lastTime).inDays;

    // Different intervals for different activities
    final intervalDays = _getActivityInterval(activity);
    return daysSinceLastTime >= intervalDays;
  }

  Future<void> _applyAssistRecommendations() async {
    try {
      final snapshot = await OperationsAssistService.loadSnapshot();
      if (snapshot.recommendations.isEmpty) {
        return;
      }

      final dayKey = _dateKey(DateTime.now());
      for (final rec in snapshot.recommendations.take(4)) {
        final zone = _zoneForRecommendation(rec);
        if (zone == null) continue;

        final activity = _activityForRecommendation(rec);
        final priority = _priorityForRecommendation(rec.priority);
        final taskId = 'task_${zone.id}_assist_${rec.area}_$dayKey';

        generatedTasks.add(
          Task(
            id: taskId,
            zoneId: zone.id,
            title: 'Assist: ${rec.title}',
            description: rec.action,
            activity: activity,
            dueDate: DateTime.now().add(const Duration(days: 1)),
            priority: priority,
            status: TaskStatus.PENDING,
            createdAt: DateTime.now(),
            createdByAI: 'operations_assist',
            metadata: {
              'assist_area': rec.area,
              'assist_priority': rec.priority,
              'expected_impact': rec.expectedImpact,
              'source': 'self_improving_assist',
            },
          ),
        );

        if (rec.priority == 'critical' || rec.priority == 'high') {
          detectedAnomalies.add(
            AnomalyDetection(
              id: _generateUuidV4(),
              zoneId: zone.id,
              type: _anomalyTypeForRecommendation(rec.area),
              title: 'Assist Alert: ${rec.title}',
              description: rec.expectedImpact,
              severity: rec.priority == 'critical' ? 0.9 : 0.72,
              detectedAt: DateTime.now(),
              data: {
                'assist_area': rec.area,
                'assist_action': rec.action,
                'assist_priority': rec.priority,
              },
            ),
          );
        }
      }
    } catch (e) {
      print('Assist recommendation integration failed: $e');
    }
  }

  FarmZone? _zoneForRecommendation(OperationsAssistRecommendation rec) {
    if (zones.isEmpty) return null;
    switch (rec.area) {
      case 'maintenance':
      case 'procurement':
        return zones.firstWhere(
          (zone) => zone.type == ZoneType.INFRASTRUCTURE,
          orElse: () => zones.first,
        );
      case 'medication_vaccine':
        return zones.firstWhere(
          (zone) => zone.type == ZoneType.LIVESTOCK,
          orElse: () => zones.first,
        );
      case 'planting':
        return zones.firstWhere(
          (zone) => zone.type == ZoneType.CROP,
          orElse: () => zones.first,
        );
      default:
        return zones.first;
    }
  }

  ActivityStage _activityForRecommendation(OperationsAssistRecommendation rec) {
    switch (rec.area) {
      case 'maintenance':
      case 'procurement':
        return ActivityStage.MAINTENANCE;
      case 'medication_vaccine':
        return ActivityStage.HEALTH_CHECK;
      case 'planting':
        return ActivityStage.PLANTING;
      default:
        return ActivityStage.INSPECTION;
    }
  }

  TaskPriority _priorityForRecommendation(String priority) {
    switch (priority) {
      case 'critical':
        return TaskPriority.URGENT;
      case 'high':
        return TaskPriority.HIGH;
      case 'medium':
        return TaskPriority.MEDIUM;
      default:
        return TaskPriority.LOW;
    }
  }

  AnomalyType _anomalyTypeForRecommendation(String area) {
    switch (area) {
      case 'maintenance':
      case 'procurement':
        return AnomalyType.COST_SPIKE;
      case 'planting':
        return AnomalyType.YIELD_RISK;
      case 'medication_vaccine':
        return AnomalyType.HEALTH_ISSUE;
      default:
        return AnomalyType.ACTIVITY_GAP;
    }
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
    final dueDate = now.add(const Duration(days: 1));
    final dateKey = _dateKey(dueDate);
    return Task(
      id: 'task_${zone.id}_${activity.toString().split('.').last}_$dateKey',
      zoneId: zone.id,
      title: '${activity.toString().split('.').last.replaceAll('_', ' ')} - ${zone.name}',
      description: 'Perform ${activity.toString().split('.').last} activities in ${zone.name}',
      activity: activity,
      dueDate: dueDate,
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
      final result = activity != null
          ? await SupabaseService.client
              .from(_tableLogs)
              .select('logged_at')
              .eq('zone_id', zoneId)
              .eq('activity', activity.toString().split('.').last)
              .order('logged_at', ascending: false)
              .limit(1)
          : await SupabaseService.client
              .from(_tableLogs)
              .select('logged_at')
              .eq('zone_id', zoneId)
              .order('logged_at', ascending: false)
              .limit(1);

      if (result is List && result.isNotEmpty) {
        final firstRow = result.first;
        final loggedAtStr = firstRow is Map<String, dynamic> ? firstRow['logged_at'] as String? : null;
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
      int inserted = 0;
      for (final task in generatedTasks) {
        // Check if task already exists
        final existing = await SupabaseService.client
            .from(_tableTasks)
            .select('id')
            .eq('id', task.id)
            .limit(1);

        if (existing is List && existing.isEmpty) {
          // Task doesn't exist - create it
          try {
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
            });
            inserted++;
          } catch (e) {
            final message = e.toString().toLowerCase();
            final isDuplicate = message.contains('duplicate key value') || message.contains('code: 23505');
            if (!isDuplicate) {
              rethrow;
            }
          }
        }
      }
      print('🤖 TASK PERSIST: generated=${generatedTasks.length}, inserted=$inserted');
    } catch (e) {
      print('Error persisting tasks: $e');
    }
  }

  /// Persist anomalies to Supabase
  Future<void> _persistAnomalies() async {
    try {
      int inserted = 0;
      if (detectedAnomalies.isNotEmpty) {
        print('🤖 ANOMALY SAMPLE ID: ${detectedAnomalies.first.id}');
      }
      for (final anomaly in detectedAnomalies) {
        await SupabaseService.client.from(_tableAnomalies).upsert({
          'id': anomaly.id,
          'zone_id': anomaly.zoneId,
          'type': anomaly.type.toString().split('.').last,
          'title': anomaly.title,
          'description': anomaly.description,
          'severity': anomaly.severity,
          'detected_at': anomaly.detectedAt.toIso8601String(),
          'data': anomaly.data,
        }, onConflict: 'id');
        inserted++;
      }
      print('🤖 ANOMALY PERSIST: generated=${detectedAnomalies.length}, inserted=$inserted');
    } catch (e) {
      print('Error persisting anomalies: $e');
    }
  }

  /// Get actionable tasks for staff (assigned to current user or unassigned)
  Future<List<Task>> getPendingTasksForStaff([String? staffId]) async {
    try {
      var query = SupabaseService.client
          .from(_tableTasks)
          .select()
          .neq('status', 'COMPLETED')
          .neq('status', 'CANCELLED');

      if (staffId != null && staffId.isNotEmpty) {
        query = query
            .or('assigned_staff_id.eq.$staffId,assigned_staff_id.is.null');
      }

      final result = await query.order('due_date', ascending: true);

      if (result is List) {
        final tasks = result
            .map((t) => _taskFromMap(t as Map<String, dynamic>))
            .toList();
        return _dedupeTasks(tasks);
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
          .limit(50);

      if (result is List) {
        return result.map((a) => _anomalyFromMap(a as Map<String, dynamic>)).toList();
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
      severity: _safeToDouble(map['severity'], fallback: 0.5),
      detectedAt: DateTime.parse(map['detected_at']),
      data: (map['data'] as Map<String, dynamic>?) ?? {},
    );
  }

  double _safeToDouble(dynamic value, {double fallback = 0.0}) {
    if (value == null) return fallback;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? fallback;
  }

  String _dateKey(DateTime date) {
    return '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
  }

  List<Task> _dedupeTasks(List<Task> tasks) {
    final bySignature = <String, Task>{};
    for (final task in tasks) {
      final signature = '${task.zoneId}|${task.activity}|${task.dueDate.year}-${task.dueDate.month}-${task.dueDate.day}|${task.status}';
      final existing = bySignature[signature];
      if (existing == null || task.createdAt.isAfter(existing.createdAt)) {
        bySignature[signature] = task;
      }
    }

    final deduped = bySignature.values.toList();
    deduped.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return deduped;
  }

  String _generateUuidV4() {
    final random = math.Random();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));

    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    String toHex(int value) => value.toRadixString(16).padLeft(2, '0');
    final hex = bytes.map(toHex).join();

    return '${hex.substring(0, 8)}-'
        '${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-'
        '${hex.substring(20, 32)}';
  }
}
