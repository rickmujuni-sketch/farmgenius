import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';
import '../services/localization_service.dart';
import '../services/ai_orchestrator.dart';
import '../services/operations_assist_service.dart';
import '../services/supabase_service.dart';
import '../models/farm_zone.dart';
import '../models/generated_farm_zones.dart';

class ManagerHome extends StatefulWidget {
  const ManagerHome({super.key});

  @override
  State<ManagerHome> createState() => _ManagerHomeState();
}

class _ManagerHomeState extends State<ManagerHome>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Future<List<Task>> _tasksFuture;
  late Future<List<AnomalyDetection>> _anomaliesFuture;
  late Future<_ManagerAIBrief> _aiBriefFuture;
  late Future<_PayrollDashboardData> _payrollFuture;
  late Future<_ManagerDailyDigest> _dailyDigestFuture;
  final MapController _zonesMapController = MapController();
  static const _storage = FlutterSecureStorage();
  static const _mapTypeKey = 'manager_map_type';
  static const _mapGesturesKey = 'manager_map_gestures';
  static const _overdueEscalationHoursKey = 'manager_escalation_overdue_hours';
  static const _stalledEscalationHoursKey = 'manager_escalation_stalled_hours';
  static const _satelliteImageryDate = '2025-07-09';
  static const double _monthlyTargetHoursPerStaff = 160;
  static const double _defaultHourlyWage = 3500;
  static const _satelliteUrlTemplate =
      'https://gibs.earthdata.nasa.gov/wmts/epsg3857/best/'
      'MODIS_Terra_CorrectedReflectance_TrueColor/default/'
      '$_satelliteImageryDate/GoogleMapsCompatible_Level9/{z}/{y}/{x}.jpg';
  String? _selectedZoneIdForMap;
  bool _hasAutoFittedZonePoints = false;
  bool _useSatelliteMap = true;
  bool _mapGesturesEnabled = true;
  double _zonesMapZoom = 15;
  int _overdueEscalationHours = 48;
  int _stalledEscalationHours = 24;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadData();
    _loadMapPreferences();
    _loadEscalationSettings();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runOrchestrationAndReload();
    });
  }

  void _loadData() {
    final ai = Provider.of<AIOrchestrator>(context, listen: false);
    _tasksFuture = ai.getPendingTasksForStaff();
    _anomaliesFuture = ai.getAnomalies();
    _aiBriefFuture = _loadManagerAIBrief();
    _payrollFuture = _loadPayrollDashboardData();
    _dailyDigestFuture = _loadDailyDigest();
    _hasAutoFittedZonePoints = false;
  }

  Future<_ManagerDailyDigest> _loadDailyDigest() async {
    final escalations = await _applyAutoEscalations();
    final aiBrief = await _loadManagerAIBrief();
    final assist = await OperationsAssistService.loadSnapshot();
    final payroll = await _loadPayrollDashboardData();

    final priority = <String>[];
    if (escalations.items.isNotEmpty) {
      priority.add(
        'Auto-escalation raised ${escalations.items.length} alert(s) this cycle.',
      );
    }
    priority.addAll(
      assist.recommendations
          .where((item) => item.priority == 'critical' || item.priority == 'high')
          .take(2)
          .map((item) => item.title),
    );
    priority.addAll(aiBrief.prompts.take(3));

    final followUps = <String>[];
    followUps.addAll(aiBrief.questions.take(3));
    followUps.addAll(aiBrief.missingData.take(3));
    if (assist.readinessScore < 75) {
      followUps.add('Farm readiness is ${assist.readinessScore}/100. Review top assist actions this week.');
    }

    final payrollRisks = <String>[];
    for (final row in payroll.rows.take(8)) {
      if (row.effortHours < (payroll.targetHoursPerStaff * 0.5)) {
        payrollRisks.add(
          '${row.staffName}: low logged effort (${row.effortHours.toStringAsFixed(1)}h).',
        );
      }
      if (row.evidenceCount < row.completedTasks) {
        payrollRisks.add(
          '${row.staffName}: missing execution evidence on completed tasks.',
        );
      }
    }

    if (priority.isEmpty) {
      priority.add(
        'No urgent incidents detected. Keep daily execution and evidence cycle active.',
      );
    }

    return _ManagerDailyDigest(
      generatedAt: DateTime.now(),
      priorityActions: priority,
      followUpQuestions: followUps,
      payrollRiskSignals: payrollRisks.take(4).toList(),
      escalations: escalations.items,
      openPromptCount:
          aiBrief.prompts.length +
          aiBrief.questions.length +
          aiBrief.missingData.length,
      opsReadinessScore: assist.readinessScore,
      assistActions: assist.recommendations.take(3).map((item) => item.action).toList(),
    );
  }

  Future<_EscalationResult> _applyAutoEscalations() async {
    try {
      final now = DateTime.now();
      final overdueCutoff = now.subtract(
        Duration(hours: _overdueEscalationHours),
      );
      final stalledCutoff = now.subtract(
        Duration(hours: _stalledEscalationHours),
      );

      final rows = await SupabaseService.client
          .from('tasks')
          .select(
            'id,title,zone_id,status,due_date,updated_at,assigned_staff_id',
          )
          .in_('status', [
            'PENDING',
            'IN_PROGRESS',
            'OVERDUE',
            'REVIEW_PENDING',
          ])
          .limit(400);

      if (rows is! List) {
        return const _EscalationResult(items: []);
      }

      final tasks = rows.whereType<Map<String, dynamic>>().toList();
      final openLoadByStaff = <String, int>{};
      for (final row in tasks) {
        final status = (row['status'] ?? '').toString().toUpperCase();
        if (status != 'PENDING' &&
            status != 'IN_PROGRESS' &&
            status != 'OVERDUE' &&
            status != 'REVIEW_PENDING') {
          continue;
        }
        final assigned = (row['assigned_staff_id'] ?? '').toString();
        if (assigned.isEmpty) continue;
        openLoadByStaff.update(
          assigned,
          (value) => value + 1,
          ifAbsent: () => 1,
        );
      }

      final availableStaff = <String>[];
      try {
        final profileRows = await SupabaseService.client
            .from('profiles')
            .select('id')
            .eq('role', 'staff')
            .limit(200);
        if (profileRows is List) {
          for (final row in profileRows.whereType<Map<String, dynamic>>()) {
            final id = (row['id'] ?? '').toString();
            if (id.isNotEmpty) {
              availableStaff.add(id);
              openLoadByStaff.putIfAbsent(id, () => 0);
            }
          }
        }
      } catch (_) {}

      final taskIds = tasks
          .map((row) => (row['id'] ?? '').toString())
          .where((id) => id.isNotEmpty)
          .toList();

      final logsByTask = <String, List<Map<String, dynamic>>>{};
      if (taskIds.isNotEmpty) {
        final logs = await SupabaseService.client
            .from('activity_logs')
            .select('task_id,notes,photo_urls,completed_at')
            .in_('task_id', taskIds)
            .order('completed_at', ascending: false)
            .limit(1000);

        if (logs is List) {
          for (final row in logs.whereType<Map<String, dynamic>>()) {
            final taskId = (row['task_id'] ?? '').toString();
            if (taskId.isEmpty) continue;
            logsByTask
                .putIfAbsent(taskId, () => <Map<String, dynamic>>[])
                .add(row);
          }
        }
      }

      final escalations = <_EscalationItem>[];

      for (final task in tasks) {
        final taskId = (task['id'] ?? '').toString();
        if (taskId.isEmpty) continue;

        final title = (task['title'] ?? 'Task').toString();
        final zoneId = (task['zone_id'] ?? '').toString();
        final status = (task['status'] ?? '').toString().toUpperCase();
        final dueDate = DateTime.tryParse((task['due_date'] ?? '').toString());
        final updatedAt = DateTime.tryParse(
          (task['updated_at'] ?? '').toString(),
        );
        final assigned = task['assigned_staff_id'];
        final hasAssignee = assigned != null && assigned.toString().isNotEmpty;
        final logs = logsByTask[taskId] ?? const <Map<String, dynamic>>[];

        final hasEvidence = logs.any((log) {
          final notes = (log['notes'] ?? '').toString().toLowerCase();
          final photos = log['photo_urls'];
          return notes.contains('gps check-in:') &&
              photos is Map &&
              photos.isNotEmpty;
        });

        if (status == 'PENDING' &&
            dueDate != null &&
            dueDate.isBefore(overdueCutoff)) {
          await SupabaseService.client
              .from('tasks')
              .update({
                'status': 'OVERDUE',
                'updated_at': now.toIso8601String(),
              })
              .eq('id', taskId);

          final id = 'esc_${taskId}_overdue_${_dayKey(now)}';
          await SupabaseService.client.from('anomalies').upsert({
            'id': id,
            'zone_id': zoneId,
            'type': 'ACTIVITY_GAP',
            'title': 'Escalation: Task Overdue > ${_overdueEscalationHours}h',
            'description':
                'Task "$title" exceeded overdue threshold and was auto-escalated.',
            'severity': 0.78,
            'detected_at': now.toIso8601String(),
            'data': {
              'task_id': taskId,
              'rule': 'overdue_${_overdueEscalationHours}h',
              'status_before': status,
            },
          }, onConflict: 'id');

          escalations.add(
            _EscalationItem(
              category: 'overdue',
              message: 'Task "$title" auto-escalated to OVERDUE.',
            ),
          );
        }

        if (status == 'IN_PROGRESS' &&
            !hasEvidence &&
            updatedAt != null &&
            updatedAt.isBefore(stalledCutoff)) {
          final id = 'esc_${taskId}_stalled_${_dayKey(now)}';
          await SupabaseService.client.from('anomalies').upsert({
            'id': id,
            'zone_id': zoneId,
            'type': 'ACTIVITY_GAP',
            'title':
                'Escalation: In-progress without evidence > ${_stalledEscalationHours}h',
            'description':
                'Task "$title" has no GPS/photo evidence after ${_stalledEscalationHours}h in progress.',
            'severity': 0.72,
            'detected_at': now.toIso8601String(),
            'data': {
              'task_id': taskId,
              'rule': 'in_progress_no_evidence_${_stalledEscalationHours}h',
            },
          }, onConflict: 'id');

          escalations.add(
            _EscalationItem(
              category: 'evidence',
              message: 'Task "$title" escalated for missing evidence.',
            ),
          );
        }

        if (status == 'REVIEW_PENDING' &&
            updatedAt != null &&
            updatedAt.isBefore(stalledCutoff)) {
          final id = 'esc_${taskId}_review_wait_${_dayKey(now)}';
          await SupabaseService.client.from('anomalies').upsert({
            'id': id,
            'zone_id': zoneId,
            'type': 'ACTIVITY_GAP',
            'title': 'Escalation: Review pending > ${_stalledEscalationHours}h',
            'description':
                'Task "$title" is waiting for manager verification beyond threshold.',
            'severity': 0.66,
            'detected_at': now.toIso8601String(),
            'data': {
              'task_id': taskId,
              'rule': 'review_pending_${_stalledEscalationHours}h',
            },
          }, onConflict: 'id');

          escalations.add(
            _EscalationItem(
              category: 'review',
              message: 'Task "$title" is waiting for manager review.',
            ),
          );
        }

        if (!hasAssignee && (status == 'PENDING' || status == 'OVERDUE')) {
          if (availableStaff.isNotEmpty) {
            availableStaff.sort((a, b) {
              final loadA = openLoadByStaff[a] ?? 0;
              final loadB = openLoadByStaff[b] ?? 0;
              final byLoad = loadA.compareTo(loadB);
              if (byLoad != 0) return byLoad;
              return a.compareTo(b);
            });

            final selectedStaffId = availableStaff.first;
            await SupabaseService.client
                .from('tasks')
                .update({
                  'assigned_staff_id': selectedStaffId,
                  'updated_at': now.toIso8601String(),
                })
                .eq('id', taskId);

            openLoadByStaff.update(
              selectedStaffId,
              (value) => value + 1,
              ifAbsent: () => 1,
            );

            escalations.add(
              _EscalationItem(
                category: 'assignment',
                message:
                    'Task "$title" auto-assigned to available staff (least workload).',
              ),
            );
          } else {
            escalations.add(
              _EscalationItem(
                category: 'assignment',
                message:
                    'Task "$title" is unassigned and needs owner allocation.',
              ),
            );
          }
        }
      }

      return _EscalationResult(items: escalations.take(10).toList());
    } catch (_) {
      return const _EscalationResult(items: []);
    }
  }

  String _dayKey(DateTime date) {
    return '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
  }

  Future<_ManagerAIBrief> _loadManagerAIBrief() async {
    try {
      final now = DateTime.now();
      final staleCutoff = now.subtract(const Duration(hours: 48));

      final taskRows = await SupabaseService.client
          .from('tasks')
          .select('id,title,status,due_date,assigned_staff_id')
          .in_('status', [
            'PENDING',
            'IN_PROGRESS',
            'OVERDUE',
            'REVIEW_PENDING',
          ])
          .order('due_date', ascending: true)
          .limit(200);

      if (taskRows is! List) {
        return const _ManagerAIBrief(
          prompts: [],
          questions: [],
          missingData: [],
        );
      }

      final activeTasks = taskRows.whereType<Map<String, dynamic>>().toList();
      final taskIds = activeTasks
          .map((row) => (row['id'] ?? '').toString())
          .where((id) => id.isNotEmpty)
          .toList();

      final logByTask = <String, List<Map<String, dynamic>>>{};
      if (taskIds.isNotEmpty) {
        try {
          final logs = await SupabaseService.client
              .from('activity_logs')
              .select('task_id,notes,photo_urls,completed_at')
              .in_('task_id', taskIds)
              .order('completed_at', ascending: false)
              .limit(500);

          if (logs is List) {
            for (final row in logs.whereType<Map<String, dynamic>>()) {
              final taskId = (row['task_id'] ?? '').toString();
              if (taskId.isEmpty) continue;
              logByTask
                  .putIfAbsent(taskId, () => <Map<String, dynamic>>[])
                  .add(row);
            }
          }
        } catch (_) {}
      }

      var stalePending = 0;
      var missingEvidence = 0;
      var unassigned = 0;
      var reviewPending = 0;
      final questions = <String>[];
      final missingData = <String>[];

      for (final task in activeTasks) {
        final taskId = (task['id'] ?? '').toString();
        final title = (task['title'] ?? 'Task').toString();
        final status = (task['status'] ?? '').toString().toUpperCase();
        final assignedStaff = task['assigned_staff_id'];
        final dueDate = DateTime.tryParse((task['due_date'] ?? '').toString());
        final logs = logByTask[taskId] ?? const <Map<String, dynamic>>[];

        if ((assignedStaff == null || assignedStaff.toString().isEmpty) &&
            status == 'PENDING') {
          unassigned++;
        }

        if (dueDate != null &&
            dueDate.isBefore(staleCutoff) &&
            status == 'PENDING') {
          stalePending++;
          if (questions.length < 4) {
            questions.add(
              'What is blocking "$title" and what support is required today?',
            );
          }
        }

        if (status == 'IN_PROGRESS' || status == 'OVERDUE') {
          final hasEvidence = logs.any((log) {
            final notes = (log['notes'] ?? '').toString().toLowerCase();
            final photos = log['photo_urls'];
            return notes.contains('gps check-in:') &&
                photos is Map &&
                photos.isNotEmpty;
          });

          if (!hasEvidence) {
            missingEvidence++;
            if (missingData.length < 4) {
              missingData.add(
                'Collect GPS + photo evidence for "$title" before close-out.',
              );
            }
          }
        }

        if (status == 'REVIEW_PENDING') {
          reviewPending++;
          if (questions.length < 4) {
            questions.add(
              'Who can verify "$title" now to satisfy four-eyes closeout?',
            );
          }
        }
      }

      final prompts = <String>[];
      if (stalePending > 0) {
        prompts.add(
          '$stalePending pending task(s) are older than 48h. Trigger blocker check-ins now.',
        );
      }
      if (unassigned > 0) {
        prompts.add(
          '$unassigned task(s) are unassigned. Auto-assign based on current workload.',
        );
      }
      if (missingEvidence > 0) {
        prompts.add(
          '$missingEvidence active task(s) have no verified GPS/photo evidence yet.',
        );
      }
      if (reviewPending > 0) {
        prompts.add(
          '$reviewPending task(s) are awaiting second-person verification.',
        );
      }
      if (prompts.isEmpty) {
        prompts.add(
          'Operations look healthy. Continue daily evidence-first execution cycle.',
        );
      }

      return _ManagerAIBrief(
        prompts: prompts,
        questions: questions,
        missingData: missingData,
      );
    } catch (_) {
      return const _ManagerAIBrief(prompts: [], questions: [], missingData: []);
    }
  }

  Future<_PayrollDashboardData> _loadPayrollDashboardData() async {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 1);

    final byStaff = <String, _StaffPayrollAccumulator>{};

    try {
      final logs = await SupabaseService.client
          .from('activity_logs')
          .select(
            'staff_id,task_id,logged_at,completed_at,notes,photo_urls,cost',
          )
          .gte('completed_at', monthStart.toIso8601String())
          .lt('completed_at', monthEnd.toIso8601String())
          .order('completed_at', ascending: true);

      if (logs is List) {
        for (final row in logs) {
          if (row is! Map<String, dynamic>) continue;
          final staffId = (row['staff_id'] ?? '').toString();
          if (staffId.isEmpty) continue;
          final acc = byStaff.putIfAbsent(
            staffId,
            () => _StaffPayrollAccumulator(staffId: staffId),
          );

          final notes = (row['notes'] ?? '').toString();
          final loggedAt = DateTime.tryParse(
            (row['logged_at'] ?? '').toString(),
          );
          final completedAt = DateTime.tryParse(
            (row['completed_at'] ?? '').toString(),
          );
          final taskId = (row['task_id'] ?? '').toString();
          final cost = row['cost'];

          final hours = _resolveEffortHours(loggedAt, completedAt, notes);
          acc.effortHours += hours;
          if (taskId.isNotEmpty) {
            acc.completedTaskIds.add(taskId);
          }

          if (cost is num && cost > 0) {
            acc.recordedCost += cost.toDouble();
          }

          final lower = notes.toLowerCase();
          final hasGps = lower.contains('gps check-in:');
          final photos = row['photo_urls'];
          final hasPhotos = photos is Map && photos.isNotEmpty;
          if (hasGps && hasPhotos) {
            acc.evidenceCount++;
          }

          if (lower.contains('issue type:') &&
              !lower.contains('issue type: none')) {
            acc.issueReports++;
          }

          if (lower.contains('teamwork:') &&
              !lower.contains('teamwork: solo')) {
            acc.teamworkMentions++;
          }
        }
      }
    } catch (_) {}

    final staffIds = byStaff.keys.toList();
    final profileNames = <String, String>{};
    if (staffIds.isNotEmpty) {
      try {
        final profiles = await SupabaseService.client
            .from('profiles')
            .select('id,email')
            .in_('id', staffIds);
        if (profiles is List) {
          for (final profile in profiles) {
            final profileMap = profile as Map<String, dynamic>;
            final id = (profileMap['id'] ?? '').toString();
            final email = (profileMap['email'] ?? '').toString();
            if (id.isNotEmpty) {
              profileNames[id] = email.isNotEmpty ? email : id;
            }
          }
        }
      } catch (_) {}
    }

    final rows = byStaff.values.map((acc) {
      final completedTasks = acc.completedTaskIds.length;
      final accountabilityScore = _calculateAccountabilityScore(
        effortHours: acc.effortHours,
        completedTasks: completedTasks,
        evidenceCount: acc.evidenceCount,
      );
      final estimatedWage = acc.recordedCost > 0
          ? acc.recordedCost
          : acc.effortHours * _defaultHourlyWage;

      return _StaffPayrollRow(
        staffId: acc.staffId,
        staffName: profileNames[acc.staffId] ?? acc.staffId.substring(0, 8),
        effortHours: acc.effortHours,
        completedTasks: completedTasks,
        evidenceCount: acc.evidenceCount,
        issueReports: acc.issueReports,
        teamworkMentions: acc.teamworkMentions,
        accountabilityScore: accountabilityScore,
        estimatedWage: estimatedWage,
      );
    }).toList()..sort((a, b) => b.estimatedWage.compareTo(a.estimatedWage));

    final prompts = <String>[];
    if (rows.isEmpty) {
      prompts.add(
        'No completed staff logs for this month. Ask teams to submit one execution report per task with effort, GPS, and photos.',
      );
    } else {
      for (final row in rows) {
        if (row.effortHours < 20) {
          prompts.add(
            'Ask ${row.staffName} to confirm monthly workload plan: only ${row.effortHours.toStringAsFixed(1)}h logged.',
          );
        }
        if (row.evidenceCount < row.completedTasks) {
          prompts.add(
            'Prompt ${row.staffName} to add missing GPS/photo evidence on completed tasks.',
          );
        }
        if (row.issueReports == 0 && row.completedTasks >= 3) {
          prompts.add(
            'Ask ${row.staffName} a quick blocker check: "Any delays, shortages, or safety issues this month?"',
          );
        }
      }
    }

    final totalPayout = rows.fold<double>(
      0,
      (sum, item) => sum + item.estimatedWage,
    );
    final totalHours = rows.fold<double>(
      0,
      (sum, item) => sum + item.effortHours,
    );

    return _PayrollDashboardData(
      monthLabel:
          '${monthStart.year}-${monthStart.month.toString().padLeft(2, '0')}',
      targetHoursPerStaff: _monthlyTargetHoursPerStaff,
      hourlyWage: _defaultHourlyWage,
      totalPayout: totalPayout,
      totalHours: totalHours,
      rows: rows,
      aiPrompts: prompts,
    );
  }

  double _resolveEffortHours(
    DateTime? loggedAt,
    DateTime? completedAt,
    String notes,
  ) {
    if (loggedAt != null &&
        completedAt != null &&
        completedAt.isAfter(loggedAt)) {
      final diff = completedAt.difference(loggedAt).inMinutes / 60;
      if (diff > 0) return diff;
    }
    final match = RegExp(
      r'Effort Hours:\s*([0-9]+(?:\.[0-9]+)?)',
      caseSensitive: false,
    ).firstMatch(notes);
    if (match != null) {
      return double.tryParse(match.group(1) ?? '') ?? 0;
    }
    return 0;
  }

  int _calculateAccountabilityScore({
    required double effortHours,
    required int completedTasks,
    required int evidenceCount,
  }) {
    final effortScore = ((effortHours / _monthlyTargetHoursPerStaff) * 60)
        .clamp(0, 60)
        .toInt();
    final executionScore = (completedTasks * 4).clamp(0, 20);
    final evidenceScore = (evidenceCount * 2).clamp(0, 20);
    return effortScore + executionScore + evidenceScore;
  }

  Future<void> _runOrchestrationAndReload() async {
    try {
      final ai = Provider.of<AIOrchestrator>(context, listen: false);
      await ai.runDailyOrchestration();
      if (!mounted) return;
      setState(_loadData);
    } catch (_) {
      if (!mounted) return;
      setState(_loadData);
    }
  }

  Future<_ZoneCommandMetrics> _loadZoneCommandMetrics(String zoneId) async {
    int openTasks = 0;
    int unresolvedAnomalies = 0;
    int openQuestions = 0;
    int openRecommendations = 0;

    try {
      final tasks = await SupabaseService.client
          .from('tasks')
          .select('status')
          .eq('zone_id', zoneId);

      if (tasks is List) {
        for (final row in tasks) {
          if (row is Map<String, dynamic>) {
            final status = (row['status'] ?? '').toString().toUpperCase();
            if (status == 'PENDING' ||
                status == 'IN_PROGRESS' ||
                status == 'OVERDUE' ||
                status == 'REVIEW_PENDING') {
              openTasks++;
            }
          }
        }
      }
    } catch (_) {}

    try {
      final anomalies = await SupabaseService.client
          .from('anomalies')
          .select('resolved_at')
          .eq('zone_id', zoneId);

      if (anomalies is List) {
        for (final row in anomalies) {
          if (row is Map<String, dynamic>) {
            if (row['resolved_at'] == null) {
              unresolvedAnomalies++;
            }
          }
        }
      }
    } catch (_) {}

    try {
      final questions = await SupabaseService.client
          .from('question_queue')
          .select('status')
          .eq('zone_id', zoneId);

      if (questions is List) {
        for (final row in questions) {
          if (row is Map<String, dynamic>) {
            final status = (row['status'] ?? '').toString().toLowerCase();
            if (status == 'queued' ||
                status == 'asked' ||
                status == 'escalated') {
              openQuestions++;
            }
          }
        }
      }
    } catch (_) {}

    try {
      final recommendations = await SupabaseService.client
          .from('recommendations')
          .select('status,expires_at')
          .eq('zone_id', zoneId);

      if (recommendations is List) {
        final now = DateTime.now();
        for (final row in recommendations) {
          if (row is Map<String, dynamic>) {
            final status = (row['status'] ?? '').toString().toLowerCase();
            final isOpen =
                status == 'proposed' ||
                status == 'accepted' ||
                status == 'modified' ||
                status == 'deferred';

            if (!isOpen) continue;
            final expiresAt = row['expires_at']?.toString();
            if (expiresAt == null ||
                DateTime.tryParse(expiresAt)?.isAfter(now) == true) {
              openRecommendations++;
            }
          }
        }
      }
    } catch (_) {}

    return _ZoneCommandMetrics(
      openTasks: openTasks,
      unresolvedAnomalies: unresolvedAnomalies,
      openQuestions: openQuestions,
      openRecommendations: openRecommendations,
      refreshedAt: DateTime.now(),
    );
  }

  Future<void> _openZoneInMaps(FarmZone zone) async {
    final point = zone.center;
    final mapsUri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${point.lat},${point.lng}',
    );
    await launchUrl(mapsUri, mode: LaunchMode.externalApplication);
  }

  void _openZoneCommandDrawer(FarmZone zone) {
    Future<_ZoneCommandMetrics> metricsFuture = _loadZoneCommandMetrics(
      zone.id,
    );

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> refreshMetrics() async {
              setModalState(() {
                metricsFuture = _loadZoneCommandMetrics(zone.id);
              });
            }

            Future<void> generateNow() async {
              await _runOrchestrationAndReload();
              if (!mounted) return;
              await refreshMetrics();
              final metrics = await _loadZoneCommandMetrics(zone.id);
              if (!mounted) return;
              ScaffoldMessenger.of(this.context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Intelligence updated • Tasks ${metrics.openTasks}, Anomalies ${metrics.unresolvedAnomalies}, Questions ${metrics.openQuestions}, Recommendations ${metrics.openRecommendations}',
                  ),
                ),
              );
            }

            return SafeArea(
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.72,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _getZoneIcon(zone.type),
                            color: const Color(0xFF2E7D32),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${zone.name} • Command',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      Text(zone.description),
                      const SizedBox(height: 10),
                      FutureBuilder<_ZoneCommandMetrics>(
                        future: metricsFuture,
                        builder: (context, snapshot) {
                          final metrics = snapshot.data;
                          if (snapshot.connectionState ==
                                  ConnectionState.waiting &&
                              metrics == null) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          final resolved =
                              metrics ??
                              const _ZoneCommandMetrics(
                                openTasks: 0,
                                unresolvedAnomalies: 0,
                                openQuestions: 0,
                                openRecommendations: 0,
                                refreshedAt: null,
                              );

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _buildAssetChip(
                                    'Open Tasks',
                                    resolved.openTasks.toString(),
                                  ),
                                  _buildAssetChip(
                                    'Unresolved',
                                    resolved.unresolvedAnomalies.toString(),
                                  ),
                                  _buildAssetChip(
                                    'Questions',
                                    resolved.openQuestions.toString(),
                                  ),
                                  _buildAssetChip(
                                    'Recommendations',
                                    resolved.openRecommendations.toString(),
                                  ),
                                ],
                              ),
                              if (resolved.refreshedAt != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Updated ${resolved.refreshedAt!.toLocal().toString().split('.').first}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Actions',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ElevatedButton.icon(
                            onPressed: generateNow,
                            icon: const Icon(Icons.psychology),
                            label: const Text('Generate Intelligence Now'),
                          ),
                          OutlinedButton.icon(
                            onPressed: refreshMetrics,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Refresh Metrics'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _openZoneInMaps(zone),
                            icon: const Icon(Icons.map),
                            label: const Text('Open in Maps'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Zone Snapshot',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 6),
                              Text('Type: ${zone.type.name}'),
                              Text(
                                'Area: ${zone.areaHectares.toStringAsFixed(2)} ha',
                              ),
                              Text(
                                'Center: ${zone.center.lat.toStringAsFixed(6)}, ${zone.center.lng.toStringAsFixed(6)}',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _loadMapPreferences() async {
    try {
      final savedMapType = await _storage.read(key: _mapTypeKey);
      final savedGestures = await _storage.read(key: _mapGesturesKey);
      if (!mounted) return;

      setState(() {
        _useSatelliteMap = savedMapType != 'street';
        _mapGesturesEnabled = savedGestures != 'off';
      });
    } catch (_) {}
  }

  Future<void> _persistMapPreferences() async {
    try {
      await _storage.write(
        key: _mapTypeKey,
        value: _useSatelliteMap ? 'satellite' : 'street',
      );
      await _storage.write(
        key: _mapGesturesKey,
        value: _mapGesturesEnabled ? 'on' : 'off',
      );
    } catch (_) {}
  }

  Future<void> _loadEscalationSettings() async {
    try {
      final overdueValue = await _storage.read(key: _overdueEscalationHoursKey);
      final stalledValue = await _storage.read(key: _stalledEscalationHoursKey);
      if (!mounted) return;

      setState(() {
        _overdueEscalationHours =
            int.tryParse(overdueValue ?? '')?.clamp(1, 336) ?? 48;
        _stalledEscalationHours =
            int.tryParse(stalledValue ?? '')?.clamp(1, 168) ?? 24;
      });
    } catch (_) {}
  }

  Future<void> _persistEscalationSettings() async {
    try {
      await _storage.write(
        key: _overdueEscalationHoursKey,
        value: _overdueEscalationHours.toString(),
      );
      await _storage.write(
        key: _stalledEscalationHoursKey,
        value: _stalledEscalationHours.toString(),
      );
    } catch (_) {}
  }

  Future<void> _openEscalationSettingsDialog(LocalizationService loc) async {
    final overdueController = TextEditingController(
      text: _overdueEscalationHours.toString(),
    );
    final stalledController = TextEditingController(
      text: _stalledEscalationHours.toString(),
    );
    String? error;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(loc.t('briefing_escalation_settings')),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: overdueController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: loc.t('briefing_overdue_threshold_hours'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: stalledController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: loc.t('briefing_stalled_threshold_hours'),
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      error!,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(loc.t('cancel')),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final overdue = int.tryParse(overdueController.text.trim());
                    final stalled = int.tryParse(stalledController.text.trim());
                    if (overdue == null ||
                        stalled == null ||
                        overdue < 1 ||
                        stalled < 1) {
                      setDialogState(() {
                        error = loc.t('briefing_threshold_validation');
                      });
                      return;
                    }

                    setState(() {
                      _overdueEscalationHours = overdue;
                      _stalledEscalationHours = stalled;
                      _loadData();
                    });
                    await _persistEscalationSettings();
                    if (!mounted) return;
                    Navigator.pop(dialogContext);
                  },
                  child: Text(loc.t('save')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _updateTaskStatus(Task task, TaskStatus status) async {
    try {
      await SupabaseService.client
          .from('tasks')
          .update({
            'status': status.name,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', task.id);

      if (!mounted) return;
      setState(_loadData);
      final loc = Provider.of<LocalizationService>(context, listen: false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${loc.t('task_updated')}: ${_formatTaskStatus(status)}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final loc = Provider.of<LocalizationService>(context, listen: false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${loc.t('could_not_update_task')}: $e')),
      );
    }
  }

  Future<void> _resolveAnomaly(AnomalyDetection anomaly) async {
    try {
      await SupabaseService.client
          .from('anomalies')
          .update({
            'resolved_at': DateTime.now().toIso8601String(),
            'resolved_by': SupabaseService.client.auth.currentUser?.id,
            'manager_notes': 'Resolved via manager dashboard',
          })
          .eq('id', anomaly.id);

      if (!mounted) return;
      setState(_loadData);
      final loc = Provider.of<LocalizationService>(context, listen: false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(loc.t('anomaly_resolved'))));
    } catch (e) {
      if (!mounted) return;
      final loc = Provider.of<LocalizationService>(context, listen: false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${loc.t('could_not_resolve_anomaly')}: $e')),
      );
    }
  }

  String _formatTaskStatus(TaskStatus status) {
    return _titleCase(status.name.replaceAll('_', ' '));
  }

  String _titleCase(String value) {
    return value
        .split(' ')
        .where((word) => word.isNotEmpty)
        .map(
          (word) =>
              '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
        )
        .join(' ');
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final loc = Provider.of<LocalizationService>(context);

    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        appBar: AppBar(
          title: Text(loc.t('manager_home')),
          backgroundColor: const Color(0xFF2E7D32),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () async {
                await _runOrchestrationAndReload();
              },
              tooltip: loc.t('refresh'),
            ),
            IconButton(
              onPressed: () async {
                await auth.signOut();
                Navigator.pushReplacementNamed(context, '/');
              },
              icon: const Icon(Icons.logout),
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            tabs: [
              Tab(icon: const Icon(Icons.assignment), text: loc.t('tasks_tab')),
              Tab(
                icon: const Icon(Icons.warning),
                text: loc.t('anomalies_tab'),
              ),
              Tab(icon: const Icon(Icons.info), text: loc.t('zones_tab')),
              Tab(icon: const Icon(Icons.payments), text: loc.t('payroll_tab')),
              Tab(
                icon: const Icon(Icons.auto_awesome_motion),
                text: loc.t('briefing_tab'),
              ),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            // Tasks Tab
            _buildTasksTab(),
            // Anomalies Tab
            _buildAnomaliesTab(),
            // Zones Tab
            _buildZonesTab(),
            // Payroll Tab
            _buildPayrollTab(),
            // Briefing Tab
            _buildBriefingTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildTasksTab() {
    final loc = Provider.of<LocalizationService>(context, listen: false);
    return FutureBuilder<List<Task>>(
      future: _tasksFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final tasks = snapshot.data ?? [];
        final sortedTasks = [...tasks]
          ..sort((a, b) {
            final aReview = a.status == TaskStatus.REVIEW_PENDING;
            final bReview = b.status == TaskStatus.REVIEW_PENDING;
            if (aReview != bReview) {
              return aReview ? -1 : 1;
            }

            final aOverdue = a.isOverdue;
            final bOverdue = b.isOverdue;
            if (aOverdue != bOverdue) {
              return aOverdue ? -1 : 1;
            }

            return a.dueDate.compareTo(b.dueDate);
          });
        final pendingTasks = tasks
            .where((t) => t.status == TaskStatus.PENDING)
            .toList();
        final overdueTasks = tasks.where((t) => t.isOverdue).toList();
        final awaitingReviewTasks = tasks
            .where((t) => t.status == TaskStatus.REVIEW_PENDING)
            .toList();

        return ListView(
          children: [
            FutureBuilder<_ManagerAIBrief>(
              future: _aiBriefFuture,
              builder: (context, aiSnapshot) {
                final aiBrief = aiSnapshot.data;
                if (aiBrief == null) {
                  return const SizedBox.shrink();
                }

                return Container(
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF2E7D32).withValues(alpha: 0.4),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.auto_awesome,
                            color: Color(0xFF2E7D32),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            loc.t('ai_operations_brief'),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...aiBrief.prompts.map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text('• $item'),
                        ),
                      ),
                      if (aiBrief.questions.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          loc.t('ai_questions_to_ask'),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        ...aiBrief.questions.map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text('• $item'),
                          ),
                        ),
                      ],
                      if (aiBrief.missingData.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          loc.t('ai_missing_data_requests'),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        ...aiBrief.missingData.map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text('• $item'),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
            Container(
              padding: const EdgeInsets.all(16),
              color: const Color(0xFFF5F5EF),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loc.t('task_summary'),
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _StatCard(
                        label: loc.t('pending'),
                        value: pendingTasks.length.toString(),
                        color: Colors.blue,
                      ),
                      _StatCard(
                        label: loc.t('overdue'),
                        value: overdueTasks.length.toString(),
                        color: Colors.red,
                      ),
                      _StatCard(
                        label: loc.t('awaiting_review'),
                        value: awaitingReviewTasks.length.toString(),
                        color: Colors.deepPurple,
                      ),
                      _StatCard(
                        label: loc.t('ai_generated'),
                        value: tasks
                            .where((t) => t.createdByAI != null)
                            .length
                            .toString(),
                        color: const Color(0xFF2E7D32),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                loc.t('recent_tasks'),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ...sortedTasks
                .take(10)
                .map((task) => _buildTaskTile(task))
                ,
          ],
        );
      },
    );
  }

  Widget _buildAssetChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.black54),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildAnomaliesTab() {
    final loc = Provider.of<LocalizationService>(context, listen: false);
    return FutureBuilder<List<AnomalyDetection>>(
      future: _anomaliesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final anomalies = snapshot.data ?? [];
        final highSeverity = anomalies.where((a) => a.severity > 0.7).toList();
        final unresolved = anomalies
            .where((a) => a.detectedAt == a.detectedAt)
            .toList();

        return ListView(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              color: const Color(0xFFF5F5EF),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loc.t('anomaly_alert_summary'),
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _StatCard(
                        label: loc.t('total'),
                        value: anomalies.length.toString(),
                        color: Colors.orange,
                      ),
                      _StatCard(
                        label: loc.t('high_severity'),
                        value: highSeverity.length.toString(),
                        color: Colors.red,
                      ),
                      _StatCard(
                        label: loc.t('unresolved'),
                        value: unresolved.length.toString(),
                        color: Colors.purple,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (anomalies.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    loc.t('no_anomalies_message'),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              ...anomalies.map((a) => _buildAnomalyTile(a)),
          ],
        );
      },
    );
  }

  Widget _buildZonesTab() {
    final loc = Provider.of<LocalizationService>(context, listen: false);
    final zones = GeneratedFarmZones.zones;
    if (zones.isEmpty) {
      return Center(child: Text(loc.t('no_zones_available')));
    }

    final selected = zones.firstWhere(
      (z) => z.id == _selectedZoneIdForMap,
      orElse: () => zones.first,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      children: [
        Card(
          child: SizedBox(
            height: 360,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: FlutterMap(
                mapController: _zonesMapController,
                options: MapOptions(
                  initialCenter: _toLatLng(selected.center),
                  initialZoom: 15,
                  minZoom: 5,
                  maxZoom: 20,
                  onPositionChanged: (position, _) {
                    _zonesMapZoom = position.zoom;
                  },
                  onMapReady: () {
                    if (!mounted) return;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;
                      _autoFitToZonePoints(zones);
                    });
                  },
                  interactionOptions: InteractionOptions(
                    flags: _mapGesturesEnabled
                        ? InteractiveFlag.drag |
                              InteractiveFlag.flingAnimation |
                              InteractiveFlag.pinchMove |
                              InteractiveFlag.pinchZoom |
                              InteractiveFlag.doubleTapZoom |
                              InteractiveFlag.scrollWheelZoom
                        : InteractiveFlag.none,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate: _useSatelliteMap
                        ? _satelliteUrlTemplate
                        : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    maxNativeZoom: _useSatelliteMap ? 9 : 19,
                    userAgentPackageName: 'com.farmgenius.app',
                  ),
                  MarkerLayer(
                    markers: zones.map((zone) {
                      final isSelected = zone.id == selected.id;
                      final baseColor = _zoneTypeColor(zone.type);
                      return Marker(
                        point: _toLatLng(zone.center),
                        width: isSelected ? 170 : 140,
                        height: isSelected ? 44 : 38,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedZoneIdForMap = zone.id;
                            });
                            _openZoneCommandDrawer(zone);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? baseColor.withValues(alpha: 0.92)
                                  : Colors.white.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected ? Colors.black87 : baseColor,
                                width: isSelected ? 2 : 1.2,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.location_on,
                                  size: 16,
                                  color: isSelected ? Colors.white : baseColor,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    zone.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: isSelected
                                          ? Colors.white
                                          : Colors.black87,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  Positioned(
                    right: 10,
                    top: 10,
                    child: Column(
                      children: [
                        Material(
                          color: Colors.white.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(8),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: _zoomIn,
                            child: const Padding(
                              padding: EdgeInsets.all(8),
                              child: Icon(Icons.add, size: 20),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Material(
                          color: Colors.white.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(8),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: _zoomOut,
                            child: const Padding(
                              padding: EdgeInsets.all(8),
                              child: Icon(Icons.remove, size: 20),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Satellite (2025-07-09)'),
              selected: _useSatelliteMap,
              onSelected: (_) {
                setState(() {
                  _useSatelliteMap = true;
                });
                _persistMapPreferences();
              },
            ),
            ChoiceChip(
              label: const Text('Street'),
              selected: !_useSatelliteMap,
              onSelected: (_) {
                setState(() {
                  _useSatelliteMap = false;
                });
                _persistMapPreferences();
              },
            ),
            FilterChip(
              label: Text(
                _mapGesturesEnabled ? 'Scroll/Zoom: On' : 'Scroll/Zoom: Off',
              ),
              selected: _mapGesturesEnabled,
              onSelected: (value) {
                setState(() {
                  _mapGesturesEnabled = value;
                });
                _persistMapPreferences();
              },
            ),
            Chip(label: Text('Zoom ${_zonesMapZoom.toStringAsFixed(1)}')),
            if (_useSatelliteMap)
              const Chip(label: Text('Imagery Date: 2025-07-09')),
          ],
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: zones.map((zone) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(zone.name),
                  selected: selected.id == zone.id,
                  onSelected: (_) {
                    setState(() {
                      _selectedZoneIdForMap = zone.id;
                    });
                  },
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          child: ListTile(
            leading: Icon(
              _getZoneIcon(selected.type),
              color: const Color(0xFF2E7D32),
              size: 32,
            ),
            title: Text(
              selected.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  selected.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${selected.areaHectares} ${loc.t('hectares')}',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            isThreeLine: true,
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openZoneCommandDrawer(selected),
          ),
        ),
      ],
    );
  }

  Widget _buildPayrollTab() {
    final loc = Provider.of<LocalizationService>(context, listen: false);
    return FutureBuilder<_PayrollDashboardData>(
      future: _payrollFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data;
        if (data == null) {
          return Center(child: Text(loc.t('payroll_no_data')));
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5EF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loc.t('payroll_monthly_engine'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text('${loc.t('payroll_month')}: ${data.monthLabel}'),
                  Text(
                    '${loc.t('payroll_hourly_rate')}: ${data.hourlyWage.toStringAsFixed(0)}',
                  ),
                  Text(
                    '${loc.t('payroll_total_hours')}: ${data.totalHours.toStringAsFixed(1)}h',
                  ),
                  Text(
                    '${loc.t('payroll_total_wages')}: ${data.totalPayout.toStringAsFixed(0)}',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              loc.t('payroll_staff_breakdown'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            if (data.rows.isEmpty)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: Text(loc.t('payroll_no_staff_rows')),
                  subtitle: Text(loc.t('payroll_collect_data_hint')),
                ),
              )
            else
              ...data.rows.map((row) {
                final progress = (row.effortHours / data.targetHoursPerStaff)
                    .clamp(0.0, 1.0);
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                row.staffName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${loc.t('payroll_wage')}: ${row.estimatedWage.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: progress,
                          color: progress >= 1
                              ? const Color(0xFF2E7D32)
                              : Colors.orange,
                          backgroundColor: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${loc.t('payroll_effort_hours')}: ${row.effortHours.toStringAsFixed(1)}h / ${data.targetHoursPerStaff.toStringAsFixed(0)}h',
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            Chip(
                              label: Text(
                                '${loc.t('payroll_tasks_done')}: ${row.completedTasks}',
                              ),
                            ),
                            Chip(
                              label: Text(
                                '${loc.t('payroll_evidence')}: ${row.evidenceCount}',
                              ),
                            ),
                            Chip(
                              label: Text(
                                '${loc.t('payroll_issues')}: ${row.issueReports}',
                              ),
                            ),
                            Chip(
                              label: Text(
                                '${loc.t('payroll_teamwork')}: ${row.teamworkMentions}',
                              ),
                            ),
                            Chip(
                              label: Text(
                                '${loc.t('payroll_accountability_score')}: ${row.accountabilityScore}/100',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
            const SizedBox(height: 16),
            Text(
              loc.t('payroll_ai_prompts'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            if (data.aiPrompts.isEmpty)
              Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.check_circle_outline,
                    color: Color(0xFF2E7D32),
                  ),
                  title: Text(loc.t('payroll_ai_all_good')),
                ),
              )
            else
              ...data.aiPrompts
                  .take(8)
                  .map(
                    (prompt) => Card(
                      child: ListTile(
                        leading: const Icon(
                          Icons.auto_awesome,
                          color: Color(0xFF2E7D32),
                        ),
                        title: Text(prompt),
                      ),
                    ),
                  ),
          ],
        );
      },
    );
  }

  Widget _buildBriefingTab() {
    final loc = Provider.of<LocalizationService>(context, listen: false);
    return FutureBuilder<_ManagerDailyDigest>(
      future: _dailyDigestFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final digest = snapshot.data;
        if (digest == null) {
          return Center(child: Text(loc.t('briefing_no_data')));
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFF2E7D32).withValues(alpha: 0.35),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.auto_awesome, color: Color(0xFF2E7D32)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          loc.t('briefing_title'),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => _openEscalationSettingsDialog(loc),
                        icon: const Icon(Icons.settings),
                        tooltip: loc.t('briefing_escalation_settings'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${loc.t('briefing_generated_at')}: ${digest.generatedAt.toLocal().toString().split('.').first}',
                  ),
                  Text(
                    '${loc.t('briefing_open_prompts')}: ${digest.openPromptCount}',
                  ),
                  Text(
                    '${loc.t('owner_readiness_score')}: ${digest.opsReadinessScore}/100',
                  ),
                  Text(
                    '${loc.t('briefing_escalation_thresholds')}: '
                    '${_overdueEscalationHours}h / ${_stalledEscalationHours}h',
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () => setState(_loadData),
                    icon: const Icon(Icons.refresh),
                    label: Text(loc.t('refresh')),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _BriefSection(
              title: loc.t('briefing_priority_actions'),
              icon: Icons.priority_high,
              items: digest.priorityActions,
            ),
            const SizedBox(height: 10),
            _BriefSection(
              title: loc.t('briefing_followup_questions'),
              icon: Icons.help_outline,
              items: digest.followUpQuestions,
            ),
            const SizedBox(height: 10),
            _BriefSection(
              title: loc.t('briefing_payroll_risks'),
              icon: Icons.payments,
              items: digest.payrollRiskSignals,
            ),
            const SizedBox(height: 10),
            _BriefSection(
              title: loc.t('briefing_escalations'),
              icon: Icons.notification_important,
              items: digest.escalations.map((item) => item.message).toList(),
            ),
            const SizedBox(height: 10),
            _BriefSection(
              title: loc.t('owner_recommended_actions'),
              icon: Icons.lightbulb_outline,
              items: digest.assistActions,
            ),
          ],
        );
      },
    );
  }

  Widget _buildTaskTile(Task task) {
    final loc = Provider.of<LocalizationService>(context, listen: false);
    final zone = GeneratedFarmZones.zones.firstWhere(
      (z) => z.id == task.zoneId,
      orElse: () => FarmZone(
        id: 'unknown',
        name: loc.t('unknown'),
        description: '',
        type: ZoneType.CROP,
        areaHectares: 0,
        boundary: const [],
      ),
    );

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: Container(
          width: 8,
          color: task.isOverdue
              ? Colors.red
              : task.isDueToday
              ? Colors.orange
              : const Color(0xFF2E7D32),
        ),
        title: Text(task.title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              zone.name,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                Chip(
                  label: Text(
                    _titleCase(task.priority.name),
                    style: const TextStyle(fontSize: 10),
                  ),
                  backgroundColor: task.priority == TaskPriority.URGENT
                      ? Colors.red
                      : task.priority == TaskPriority.HIGH
                      ? Colors.orange
                      : Colors.blue,
                  labelStyle: const TextStyle(color: Colors.white),
                  visualDensity: VisualDensity.compact,
                ),
                Chip(
                  label: Text(
                    _formatTaskStatus(task.status),
                    style: const TextStyle(fontSize: 10),
                  ),
                  backgroundColor: task.status == TaskStatus.IN_PROGRESS
                      ? Colors.indigo
                      : task.status == TaskStatus.REVIEW_PENDING
                      ? Colors.deepPurple
                      : task.status == TaskStatus.COMPLETED
                      ? const Color(0xFF2E7D32)
                      : task.status == TaskStatus.CANCELLED
                      ? Colors.grey
                      : Colors.blueGrey,
                  labelStyle: const TextStyle(color: Colors.white),
                  visualDensity: VisualDensity.compact,
                ),
                if (task.status == TaskStatus.REVIEW_PENDING)
                  ActionChip(
                    label: Text(
                      loc.t('awaiting_review'),
                      style: const TextStyle(fontSize: 10),
                    ),
                    backgroundColor: Colors.deepPurple.withValues(alpha: 0.14),
                    labelStyle: const TextStyle(color: Colors.deepPurple),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _openReviewActionsSheet(task, loc),
                  ),
                if (task.createdByAI != null)
                  Chip(
                    label: Text(
                      _titleCase(task.createdByAI!.replaceAll('_', ' ')),
                      style: const TextStyle(fontSize: 10),
                    ),
                    backgroundColor: Colors.purple,
                    labelStyle: const TextStyle(color: Colors.white),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ],
        ),
        isThreeLine: true,
        trailing: PopupMenuButton(
          itemBuilder: (context) {
            if (task.status == TaskStatus.REVIEW_PENDING) {
              return [
                PopupMenuItem(
                  value: 'approve',
                  child: Text(loc.t('approve_completion')),
                ),
                PopupMenuItem(
                  value: 'rework',
                  child: Text(loc.t('request_rework')),
                ),
              ];
            }
            return [
              PopupMenuItem(
                value: 'override',
                child: Text(loc.t('mark_in_progress')),
              ),
              PopupMenuItem(value: 'cancel', child: Text(loc.t('cancel_task'))),
            ];
          },
          onSelected: (value) async {
            if (value == 'approve') {
              await _updateTaskStatus(task, TaskStatus.COMPLETED);
            } else if (value == 'rework') {
              await _updateTaskStatus(task, TaskStatus.IN_PROGRESS);
            } else if (value == 'override') {
              await _updateTaskStatus(task, TaskStatus.IN_PROGRESS);
            } else if (value == 'cancel') {
              await _updateTaskStatus(task, TaskStatus.CANCELLED);
            }
          },
        ),
      ),
    );
  }

  Future<void> _openReviewActionsSheet(
    Task task,
    LocalizationService loc,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.verified, color: Color(0xFF2E7D32)),
                title: Text(loc.t('approve_completion')),
                onTap: () async {
                  Navigator.pop(context);
                  await _updateTaskStatus(task, TaskStatus.COMPLETED);
                },
              ),
              ListTile(
                leading: const Icon(Icons.undo, color: Colors.orange),
                title: Text(loc.t('request_rework')),
                onTap: () async {
                  Navigator.pop(context);
                  await _updateTaskStatus(task, TaskStatus.IN_PROGRESS);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  LatLng _toLatLng(GeoPoint point) => LatLng(point.lat, point.lng);

  void _zoomIn() {
    final camera = _zonesMapController.camera;
    final nextZoom = (camera.zoom + 1).clamp(5.0, 20.0);
    _zonesMapController.move(camera.center, nextZoom);
    setState(() {
      _zonesMapZoom = nextZoom;
    });
  }

  void _zoomOut() {
    final camera = _zonesMapController.camera;
    final nextZoom = (camera.zoom - 1).clamp(5.0, 20.0);
    _zonesMapController.move(camera.center, nextZoom);
    setState(() {
      _zonesMapZoom = nextZoom;
    });
  }

  void _autoFitToZonePoints(List<FarmZone> zones) {
    if (_hasAutoFittedZonePoints) return;
    final points = zones
        .where((zone) => zone.boundary.isNotEmpty)
        .map((zone) => _toLatLng(zone.center))
        .toList();

    if (points.isEmpty) return;
    if (points.length == 1) {
      _zonesMapController.move(points.first, 16);
      _hasAutoFittedZonePoints = true;
      return;
    }

    _zonesMapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(points),
        padding: const EdgeInsets.all(32),
      ),
    );
    _hasAutoFittedZonePoints = true;
  }

  Color _zoneTypeColor(ZoneType type) {
    switch (type) {
      case ZoneType.CROP:
        return const Color(0xFF2E7D32);
      case ZoneType.LIVESTOCK:
        return const Color(0xFF8D6E63);
      case ZoneType.INFRASTRUCTURE:
        return const Color(0xFF546E7A);
    }
  }

  Widget _buildAnomalyTile(AnomalyDetection anomaly) {
    final loc = Provider.of<LocalizationService>(context, listen: false);
    final zone = GeneratedFarmZones.zones.firstWhere(
      (z) => z.id == anomaly.zoneId,
      orElse: () => FarmZone(
        id: 'unknown',
        name: loc.t('unknown'),
        description: '',
        type: ZoneType.CROP,
        areaHectares: 0,
        boundary: const [],
      ),
    );

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: anomaly.severity > 0.7
          ? Colors.red.shade50
          : Colors.orange.shade50,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: anomaly.severity > 0.7 ? Colors.red : Colors.orange,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
            ),
            child: Row(
              children: [
                Icon(_getAnomalyIcon(anomaly.type), color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        anomaly.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        zone.name,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${(anomaly.severity * 100).toInt()}%',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(anomaly.description),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      anomaly.detectedAt.toString().split('.')[0],
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.check, size: 16),
                      label: Text(loc.t('resolve')),
                      onPressed: () => _resolveAnomaly(anomaly),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getAnomalyIcon(AnomalyType type) {
    switch (type) {
      case AnomalyType.ACTIVITY_GAP:
        return Icons.schedule;
      case AnomalyType.COST_SPIKE:
        return Icons.trending_up;
      case AnomalyType.YIELD_RISK:
        return Icons.agriculture;
      case AnomalyType.WEATHER_ALERT:
        return Icons.cloud;
      case AnomalyType.HEALTH_ISSUE:
        return Icons.health_and_safety;
    }
  }

  IconData _getZoneIcon(ZoneType type) {
    switch (type) {
      case ZoneType.CROP:
        return Icons.nature;
      case ZoneType.LIVESTOCK:
        return Icons.pets;
      case ZoneType.INFRASTRUCTURE:
        return Icons.build;
    }
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

class _ZoneCommandMetrics {
  final int openTasks;
  final int unresolvedAnomalies;
  final int openQuestions;
  final int openRecommendations;
  final DateTime? refreshedAt;

  const _ZoneCommandMetrics({
    required this.openTasks,
    required this.unresolvedAnomalies,
    required this.openQuestions,
    required this.openRecommendations,
    required this.refreshedAt,
  });
}

class _StaffPayrollAccumulator {
  final String staffId;
  double effortHours;
  double recordedCost;
  int evidenceCount;
  int issueReports;
  int teamworkMentions;
  final Set<String> completedTaskIds;

  _StaffPayrollAccumulator({required this.staffId})
    : effortHours = 0,
      recordedCost = 0,
      evidenceCount = 0,
      issueReports = 0,
      teamworkMentions = 0,
      completedTaskIds = <String>{};
}

class _StaffPayrollRow {
  final String staffId;
  final String staffName;
  final double effortHours;
  final int completedTasks;
  final int evidenceCount;
  final int issueReports;
  final int teamworkMentions;
  final int accountabilityScore;
  final double estimatedWage;

  const _StaffPayrollRow({
    required this.staffId,
    required this.staffName,
    required this.effortHours,
    required this.completedTasks,
    required this.evidenceCount,
    required this.issueReports,
    required this.teamworkMentions,
    required this.accountabilityScore,
    required this.estimatedWage,
  });
}

class _PayrollDashboardData {
  final String monthLabel;
  final double targetHoursPerStaff;
  final double hourlyWage;
  final double totalPayout;
  final double totalHours;
  final List<_StaffPayrollRow> rows;
  final List<String> aiPrompts;

  const _PayrollDashboardData({
    required this.monthLabel,
    required this.targetHoursPerStaff,
    required this.hourlyWage,
    required this.totalPayout,
    required this.totalHours,
    required this.rows,
    required this.aiPrompts,
  });
}

class _BriefSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<String> items;

  const _BriefSection({
    required this.title,
    required this.icon,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: const Color(0xFF2E7D32)),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (items.isEmpty)
              const Text('• No items at the moment.')
            else
              ...items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('• $item'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ManagerAIBrief {
  final List<String> prompts;
  final List<String> questions;
  final List<String> missingData;

  const _ManagerAIBrief({
    required this.prompts,
    required this.questions,
    required this.missingData,
  });
}

class _ManagerDailyDigest {
  final DateTime generatedAt;
  final List<String> priorityActions;
  final List<String> followUpQuestions;
  final List<String> payrollRiskSignals;
  final List<_EscalationItem> escalations;
  final int openPromptCount;
  final int opsReadinessScore;
  final List<String> assistActions;

  const _ManagerDailyDigest({
    required this.generatedAt,
    required this.priorityActions,
    required this.followUpQuestions,
    required this.payrollRiskSignals,
    required this.escalations,
    required this.openPromptCount,
    required this.opsReadinessScore,
    required this.assistActions,
  });
}

class _EscalationResult {
  final List<_EscalationItem> items;

  const _EscalationResult({required this.items});
}

class _EscalationItem {
  final String category;
  final String message;

  const _EscalationItem({required this.category, required this.message});
}
