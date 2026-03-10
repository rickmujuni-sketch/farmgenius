import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';
import '../services/localization_service.dart';
import '../services/ai_orchestrator.dart';
import '../services/operations_assist_service.dart';
import '../services/supabase_service.dart';
import '../services/ledger_service.dart';
import '../services/biological_asset_service.dart';
import '../models/farm_zone.dart';
import '../models/generated_farm_zones.dart';
import '../models/biological_asset.dart';
import '../models/operations_assist.dart';
import 'daily_asset_check_form_screen.dart';

class StaffHome extends StatefulWidget {
  const StaffHome({super.key});

  @override
  State<StaffHome> createState() => _StaffHomeState();
}

class _StaffHomeState extends State<StaffHome> {
  static const _storage = FlutterSecureStorage();
  static const _checksFilterKey = 'staff_checks_filter';
  static const double _dailyTargetHours = 8;
  static const double _weeklyTargetHours = 40;
  static const double _monthlyTargetHours = 160;
  late Future<List<Task>> _tasksFuture;
  late Future<List<DailyAssetCheck>> _dailyChecksFuture;
  late Future<_StaffAccountabilityMetrics> _accountabilityFuture;
  late Future<OperationsAssistSnapshot> _opsAssistFuture;
  String _checksFilter = 'all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final loc = Provider.of<LocalizationService>(context, listen: false);
      if (loc.locale.languageCode != 'sw') {
        loc.setLocale(const Locale('sw'));
      }
    });
    _loadTasks();
    _loadSavedChecksFilter();
  }

  Future<void> _loadSavedChecksFilter() async {
    final saved = await _storage.read(key: _checksFilterKey);
    if (!mounted) return;
    if (saved == 'today' || saved == 'week' || saved == 'all') {
      setState(() {
        _checksFilter = saved!;
      });
    }
  }

  Future<void> _setChecksFilter(String value) async {
    await _storage.write(key: _checksFilterKey, value: value);
    if (!mounted) return;
    setState(() {
      _checksFilter = value;
    });
  }

  void _loadTasks() {
    final ai = Provider.of<AIOrchestrator>(context, listen: false);
    final staffId = Provider.of<AuthService>(context, listen: false).user?.id;
    _tasksFuture = ai.getPendingTasksForStaff(staffId);
    _dailyChecksFuture = BiologicalAssetService.getRecentDailyChecks(limit: 30);
    _accountabilityFuture = _loadAccountabilityMetrics(staffId);
    _opsAssistFuture = OperationsAssistService.loadSnapshot();
  }

  OperationsAssistRecommendation? _staffTopRecommendation(OperationsAssistSnapshot snapshot) {
    final preferred = snapshot.recommendations.where((item) {
      return item.area == 'maintenance' ||
          item.area == 'planting' ||
          item.area == 'medication_vaccine' ||
          item.area == 'procurement';
    });
    if (preferred.isNotEmpty) {
      return preferred.first;
    }
    if (snapshot.recommendations.isNotEmpty) {
      return snapshot.recommendations.first;
    }
    return null;
  }

  Widget _buildAssistTip(LocalizationService loc, OperationsAssistSnapshot snapshot) {
    final top = _staffTopRecommendation(snapshot);
    if (top == null) {
      return const SizedBox.shrink();
    }

    final iconColor = top.priority == 'critical'
        ? Colors.red.shade700
        : top.priority == 'high'
            ? Colors.orange.shade800
            : Colors.blueGrey;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2E7D32).withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loc.t('assist_today_tip'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(top.title),
                const SizedBox(height: 2),
                Text(top.action),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<_StaffAccountabilityMetrics> _loadAccountabilityMetrics(String? staffId) async {
    if (staffId == null || staffId.isEmpty) {
      return _StaffAccountabilityMetrics.empty(
        dailyTargetHours: _dailyTargetHours,
        weeklyTargetHours: _weeklyTargetHours,
        monthlyTargetHours: _monthlyTargetHours,
      );
    }

    try {
      final rows = await SupabaseService.client
          .from('activity_logs')
          .select('logged_at,completed_at,notes,photo_urls')
          .eq('staff_id', staffId)
          .order('completed_at', ascending: false)
          .limit(500);

      if (rows is! List) {
        return _StaffAccountabilityMetrics.empty(
          dailyTargetHours: _dailyTargetHours,
          weeklyTargetHours: _weeklyTargetHours,
          monthlyTargetHours: _monthlyTargetHours,
        );
      }

      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final weekStart = todayStart.subtract(const Duration(days: 6));
      final monthStart = DateTime(now.year, now.month, 1);

      double dailyEffort = 0;
      double weeklyEffort = 0;
      double monthlyEffort = 0;
      int evidenceLogs = 0;
      int issueReports = 0;
      int teamworkMentions = 0;

      for (final row in rows) {
        final map = row as Map<String, dynamic>;
        final completedAt = DateTime.tryParse((map['completed_at'] ?? map['logged_at'] ?? '').toString());
        if (completedAt == null) continue;

        final notes = (map['notes'] ?? '').toString();
        final photoUrls = map['photo_urls'];
        final hasPhotoEvidence = photoUrls is Map && photoUrls.isNotEmpty;
        final hasGps = notes.toLowerCase().contains('gps check-in:');
        if (hasGps && hasPhotoEvidence) {
          evidenceLogs++;
        }
        if (notes.toLowerCase().contains('issue type:') && !notes.toLowerCase().contains('issue type: none')) {
          issueReports++;
        }
        if (notes.toLowerCase().contains('teamwork:') && !notes.toLowerCase().contains('teamwork: solo')) {
          teamworkMentions++;
        }

        final effortHours = _resolveEffortHours(map, notes);
        if (!completedAt.isBefore(todayStart)) dailyEffort += effortHours;
        if (!completedAt.isBefore(weekStart)) weeklyEffort += effortHours;
        if (!completedAt.isBefore(monthStart)) monthlyEffort += effortHours;
      }

      return _StaffAccountabilityMetrics(
        dailyTargetHours: _dailyTargetHours,
        weeklyTargetHours: _weeklyTargetHours,
        monthlyTargetHours: _monthlyTargetHours,
        dailyEffortHours: dailyEffort,
        weeklyEffortHours: weeklyEffort,
        monthlyEffortHours: monthlyEffort,
        evidenceLogs: evidenceLogs,
        issueReports: issueReports,
        teamworkMentions: teamworkMentions,
      );
    } catch (_) {
      return _StaffAccountabilityMetrics.empty(
        dailyTargetHours: _dailyTargetHours,
        weeklyTargetHours: _weeklyTargetHours,
        monthlyTargetHours: _monthlyTargetHours,
      );
    }
  }

  double _resolveEffortHours(Map<String, dynamic> row, String notes) {
    final start = DateTime.tryParse((row['logged_at'] ?? '').toString());
    final end = DateTime.tryParse((row['completed_at'] ?? '').toString());
    if (start != null && end != null && end.isAfter(start)) {
      final diff = end.difference(start).inMinutes / 60;
      if (diff > 0) return diff;
    }

    final match = RegExp(r'Effort Hours:\s*([0-9]+(?:\.[0-9]+)?)', caseSensitive: false).firstMatch(notes);
    if (match != null) {
      return double.tryParse(match.group(1) ?? '') ?? 0;
    }
    return 0;
  }

  Widget _buildAccountabilityCard(_StaffAccountabilityMetrics metrics, LocalizationService loc) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5EF),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            loc.t('accountability_dashboard'),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _MetricCell(
                  title: loc.t('daily_effort'),
                  value: '${metrics.dailyEffortHours.toStringAsFixed(1)}h / ${metrics.dailyTargetHours.toStringAsFixed(0)}h',
                  progress: metrics.dailyProgress,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricCell(
                  title: loc.t('weekly_effort'),
                  value: '${metrics.weeklyEffortHours.toStringAsFixed(1)}h / ${metrics.weeklyTargetHours.toStringAsFixed(0)}h',
                  progress: metrics.weeklyProgress,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricCell(
                  title: loc.t('monthly_effort'),
                  value: '${metrics.monthlyEffortHours.toStringAsFixed(1)}h / ${metrics.monthlyTargetHours.toStringAsFixed(0)}h',
                  progress: metrics.monthlyProgress,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(label: Text('${loc.t('evidence_logs')}: ${metrics.evidenceLogs}')),
              Chip(label: Text('${loc.t('issue_reports')}: ${metrics.issueReports}')),
              Chip(label: Text('${loc.t('teamwork_mentions')}: ${metrics.teamworkMentions}')),
            ],
          ),
        ],
      ),
    );
  }

  List<DailyAssetCheck> _applyChecksFilter(List<DailyAssetCheck> checks) {
    final now = DateTime.now();
    if (_checksFilter == 'today') {
      return checks.where((check) {
        return check.checkDate.year == now.year &&
            check.checkDate.month == now.month &&
            check.checkDate.day == now.day;
      }).toList();
    }

    if (_checksFilter == 'week') {
      final weekAgo = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
      return checks.where((check) {
        final date = DateTime(check.checkDate.year, check.checkDate.month, check.checkDate.day);
        return !date.isBefore(weekAgo);
      }).toList();
    }

    return checks;
  }

  Future<void> _openDailyCheckForm({DailyAssetCheck? existingCheck}) async {
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => DailyAssetCheckFormScreen(existingCheck: existingCheck),
      ),
    );

    if (!mounted) return;
    if (updated == true) {
      setState(_loadTasks);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(existingCheck == null
              ? Provider.of<LocalizationService>(context, listen: false).t('daily_check_created')
              : Provider.of<LocalizationService>(context, listen: false).t('daily_check_updated')),
        ),
      );
    }
  }

  Future<void> _markTaskInProgress(Task task) async {
    final staffId = Provider.of<AuthService>(context, listen: false).user?.id;
    if (staffId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(Provider.of<LocalizationService>(context, listen: false).t('login_failed'))),
      );
      return;
    }

    try {
      await SupabaseService.client
          .from('tasks')
          .update({
            'status': 'IN_PROGRESS',
            'assigned_staff_id': staffId,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', task.id);

      if (!mounted) return;
      final loc = Provider.of<LocalizationService>(context, listen: false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.t('task_marked_in_progress'))),
      );
      setState(_loadTasks);
    } catch (e) {
      if (!mounted) return;
      final loc = Provider.of<LocalizationService>(context, listen: false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${loc.t('could_not_update_task')}: $e')),
      );
    }
  }

  Future<void> _executeTask(Task task) async {
    final loc = Provider.of<LocalizationService>(context, listen: false);
    final auth = Provider.of<AuthService>(context, listen: false);
    final staffId = auth.user?.id;
    if (staffId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.t('login_failed'))),
      );
      return;
    }

    final evidence = await showDialog<_TaskExecutionPayload>(
      context: context,
      builder: (_) => _TaskExecutionDialog(task: task, loc: loc),
    );

    if (evidence == null || !mounted) return;

    try {
      final now = DateTime.now();
      final effortMinutes = (evidence.effortHours * 60).round();
      final startedAt = now.subtract(Duration(minutes: effortMinutes > 0 ? effortMinutes : 1));
      final laborCost = evidence.effortHours * 3500;
      final totalCost = laborCost + evidence.directCostTzs;
      final activityLogId = 'log_${task.id}_${now.millisecondsSinceEpoch}';
      final photoUrls = <String, String>{
        if (evidence.photoUrl1.isNotEmpty) 'evidence_1': evidence.photoUrl1,
        if (evidence.photoUrl2.isNotEmpty) 'evidence_2': evidence.photoUrl2,
      };

      await SupabaseService.client.from('activity_logs').insert({
        'id': activityLogId,
        'task_id': task.id,
        'zone_id': task.zoneId,
        'staff_id': staffId,
        'activity': task.activity.name,
        'logged_at': startedAt.toIso8601String(),
        'completed_at': now.toIso8601String(),
        'photo_urls': photoUrls,
        'notes': _buildExecutionNotes(evidence),
        'quantity': evidence.quantity,
        'quantity_unit': evidence.quantityUnit.isEmpty ? null : evidence.quantityUnit,
        'cost': totalCost,
      });

      await LedgerService.recordExecutionFinancials(
        activityLogId: activityLogId,
        taskId: task.id,
        staffId: staffId,
        zoneId: task.zoneId,
        activity: task.activity.name,
        occurredAt: now,
        financialCategory: evidence.financialCategory,
        costTzs: totalCost,
        revenueTzs: evidence.revenueTzs,
        quantity: evidence.quantity?.toDouble(),
        quantityUnit: evidence.quantityUnit.isEmpty ? null : evidence.quantityUnit,
        metadata: {
          'unit_price_tzs': evidence.unitPriceTzs,
          'effort_hours': evidence.effortHours,
        },
      );

      await SupabaseService.client
          .from('tasks')
          .update({
            'status': 'REVIEW_PENDING',
            'assigned_staff_id': staffId,
            'updated_at': now.toIso8601String(),
          })
          .eq('id', task.id);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.t('task_submitted_for_review'))),
      );
      setState(_loadTasks);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${loc.t('could_not_complete_task')}: $e')),
      );
    }
  }

  String _buildExecutionNotes(_TaskExecutionPayload payload) {
    final laborCost = payload.effortHours * 3500;
    final totalCost = laborCost + payload.directCostTzs;
    final buffer = StringBuffer()
      ..writeln('Execution Notes: ${payload.notes}')
      ..writeln('Effort Hours: ${payload.effortHours.toStringAsFixed(2)}')
      ..writeln('Labor Cost (TZS): ${laborCost.toStringAsFixed(0)}')
      ..writeln('Direct Cost (TZS): ${payload.directCostTzs.toStringAsFixed(0)}')
      ..writeln('Total Cost (TZS): ${totalCost.toStringAsFixed(0)}')
      ..writeln('Revenue (TZS): ${payload.revenueTzs.toStringAsFixed(0)}')
      ..writeln('Unit Price (TZS): ${(payload.unitPriceTzs ?? 0).toStringAsFixed(0)}')
      ..writeln('Financial Category: ${payload.financialCategory}')
      ..writeln('Teamwork: ${payload.teamworkWith.isEmpty ? 'solo' : payload.teamworkWith}')
      ..writeln('GPS Check-in: ${payload.latitude.toStringAsFixed(6)}, ${payload.longitude.toStringAsFixed(6)}');

    if (payload.issueType != 'none') {
      buffer
        ..writeln('Issue Type: ${payload.issueType}')
        ..writeln('Issue Details: ${payload.issueDetails}');
    }

    return buffer.toString().trim();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final loc = Provider.of<LocalizationService>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.t('staff_home')),
        backgroundColor: const Color(0xFF2E7D32),
        actions: [
          IconButton(
            onPressed: () => _openDailyCheckForm(),
            icon: const Icon(Icons.add_task),
            tooltip: loc.t('create_daily_check'),
          ),
          IconButton(
            onPressed: () async {
              await auth.signOut();
              Navigator.pushReplacementNamed(context, '/');
            },
            icon: const Icon(Icons.logout),
          )
        ],
      ),
      body: FutureBuilder<List<Task>>(
        future: _tasksFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('${loc.t('error_loading_tasks')}: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(_loadTasks);
                    },
                    child: Text(loc.t('retry')),
                  ),
                ],
              ),
            );
          }

          final tasks = snapshot.data ?? [];

          if (tasks.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_outline, size: 64, color: Color(0xFF2E7D32)),
                  const SizedBox(height: 16),
                  Text(
                    loc.t('no_tasks_assigned'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 32),
                  RefreshButton(onRefresh: () => setState(_loadTasks), label: loc.t('refresh')),
                ],
              ),
            );
          }

          return Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                color: const Color(0xFFF5F5EF),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${loc.t('tasks_count')}: ${tasks.length}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    RefreshButton(onRefresh: () => setState(_loadTasks), label: loc.t('refresh')),
                  ],
                ),
              ),
              FutureBuilder<_StaffAccountabilityMetrics>(
                future: _accountabilityFuture,
                builder: (context, metricsSnapshot) {
                  final metrics = metricsSnapshot.data ??
                      _StaffAccountabilityMetrics.empty(
                        dailyTargetHours: _dailyTargetHours,
                        weeklyTargetHours: _weeklyTargetHours,
                        monthlyTargetHours: _monthlyTargetHours,
                      );
                  return _buildAccountabilityCard(metrics, loc);
                },
              ),
              FutureBuilder<OperationsAssistSnapshot>(
                future: _opsAssistFuture,
                builder: (context, assistSnapshot) {
                  final assist = assistSnapshot.data;
                  if (assist == null) {
                    return const SizedBox.shrink();
                  }
                  return _buildAssistTip(loc, assist);
                },
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                alignment: Alignment.centerLeft,
                child: Text(
                  loc.t('recent_daily_checks'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    ChoiceChip(
                      label: Text(loc.t('today')),
                      selected: _checksFilter == 'today',
                      onSelected: (_) => _setChecksFilter('today'),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: Text(loc.t('this_week')),
                      selected: _checksFilter == 'week',
                      onSelected: (_) => _setChecksFilter('week'),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: Text(loc.t('all')),
                      selected: _checksFilter == 'all',
                      onSelected: (_) => _setChecksFilter('all'),
                    ),
                  ],
                ),
              ),
              FutureBuilder<List<DailyAssetCheck>>(
                future: _dailyChecksFuture,
                builder: (context, checksSnapshot) {
                  if (checksSnapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(8),
                      child: CircularProgressIndicator(),
                    );
                  }

                  final checks = _applyChecksFilter(checksSnapshot.data ?? []);
                  if (checks.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(loc.t('no_checks_submitted')),
                      ),
                    );
                  }

                  return SizedBox(
                    height: 120,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: checks
                          .map(
                            (check) => Container(
                              width: 250,
                              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              child: Card(
                                child: ListTile(
                                  title: Text(check.checklistType, maxLines: 1, overflow: TextOverflow.ellipsis),
                                  subtitle: Text(
                                    '${check.timeBlock}\n${check.checkDate.toIso8601String().split('T').first}',
                                    maxLines: 2,
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.edit),
                                    onPressed: () => _openDailyCheckForm(existingCheck: check),
                                  ),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  );
                },
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: tasks.length,
                  itemBuilder: (context, index) {
                    final task = tasks[index];
                    final zone = GeneratedFarmZones.zones.firstWhere(
                      (z) => z.id == task.zoneId,
                      orElse: () => FarmZone(
                        id: 'unknown',
                        name: 'Unknown Zone',
                        description: '',
                        type: ZoneType.CROP,
                        areaHectares: 0,
                        boundary: const [],
                      ),
                    );

                    return TaskCard(
                      task: task,
                      zone: zone,
                      onStart: () => _markTaskInProgress(task),
                      onExecute: () => _executeTask(task),
                      onOpenZone: () async {
                        final point = zone.center;
                        if (zone.boundary.isEmpty || (point.lat == 0 && point.lng == 0)) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(loc.t('no_zone_location'))),
                          );
                          return;
                        }

                        final mapsUri = Uri.parse('https://www.google.com/maps/search/?api=1&query=${point.lat},${point.lng}');
                        final opened = await launchUrl(mapsUri, mode: LaunchMode.externalApplication);
                        if (!opened && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(loc.t('could_not_open_maps'))),
                          );
                        }
                      },
                      loc: loc,
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class TaskCard extends StatelessWidget {
  final Task task;
  final FarmZone zone;
  final VoidCallback onStart;
  final VoidCallback onExecute;
  final VoidCallback onOpenZone;
  final LocalizationService loc;

  const TaskCard({
    required this.task,
    required this.zone,
    required this.onStart,
    required this.onExecute,
    required this.onOpenZone,
    required this.loc,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isOverdue = task.isOverdue;
    final isDueToday = task.isDueToday;

    Color statusColor = const Color(0xFF2E7D32);
    if (isOverdue) {
      statusColor = Colors.red;
    } else if (isDueToday) {
      statusColor = Colors.orange;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  _getActivityIcon(task.activity),
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        zone.name,
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(task.description),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${loc.t('due')}: ${task.dueDate.toString().split(' ')[0]}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _priorityColor(task.priority),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        task.priority.toString().split('.').last,
                        style: const TextStyle(color: Colors.white, fontSize: 10),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.location_on),
                        label: Text(loc.t('open_in_maps')),
                        onPressed: onOpenZone,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.play_arrow),
                        label: Text(loc.t('mark_in_progress')),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                        ),
                        onPressed: onStart,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.assignment_turned_in),
                        label: Text(loc.t('execute_with_evidence')),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7D32),
                        ),
                        onPressed: onExecute,
                      ),
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

  IconData _getActivityIcon(ActivityStage activity) {
    switch (activity) {
      case ActivityStage.PLANTING:
        return Icons.spa;
      case ActivityStage.GROWTH:
      case ActivityStage.GERMINATION:
        return Icons.nature;
      case ActivityStage.FLOWERING:
        return Icons.local_florist;
      case ActivityStage.HARVEST:
      case ActivityStage.GRAIN_FILL:
        return Icons.local_dining;
      case ActivityStage.GRAZING:
        return Icons.pets;
      case ActivityStage.HEALTH_CHECK:
        return Icons.medical_services;
      case ActivityStage.BREEDING:
      case ActivityStage.CALVING:
        return Icons.child_care;
      case ActivityStage.MAINTENANCE:
      case ActivityStage.REPAIR:
      case ActivityStage.CLEANING:
      case ActivityStage.SEASONAL_CHECK:
      case ActivityStage.INSPECTION:
        return Icons.build;
      case ActivityStage.SUPPLEMENTAL_FEEDING:
        return Icons.restaurant;
    }
  }

  Color _priorityColor(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.LOW:
        return Colors.blue;
      case TaskPriority.MEDIUM:
        return Colors.orange;
      case TaskPriority.HIGH:
        return Colors.red;
      case TaskPriority.URGENT:
        return Colors.deepOrange;
    }
  }
}

class RefreshButton extends StatelessWidget {
  final VoidCallback onRefresh;
  final String label;

  const RefreshButton({required this.onRefresh, required this.label, super.key});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      icon: const Icon(Icons.refresh),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF2E7D32),
      ),
      onPressed: onRefresh,
    );
  }
}

class _MetricCell extends StatelessWidget {
  final String title;
  final String value;
  final double progress;

  const _MetricCell({required this.title, required this.value, required this.progress});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            backgroundColor: Colors.grey.shade200,
            color: progress >= 1 ? const Color(0xFF2E7D32) : Colors.orange,
          ),
        ],
      ),
    );
  }
}

class _StaffAccountabilityMetrics {
  final double dailyTargetHours;
  final double weeklyTargetHours;
  final double monthlyTargetHours;
  final double dailyEffortHours;
  final double weeklyEffortHours;
  final double monthlyEffortHours;
  final int evidenceLogs;
  final int issueReports;
  final int teamworkMentions;

  const _StaffAccountabilityMetrics({
    required this.dailyTargetHours,
    required this.weeklyTargetHours,
    required this.monthlyTargetHours,
    required this.dailyEffortHours,
    required this.weeklyEffortHours,
    required this.monthlyEffortHours,
    required this.evidenceLogs,
    required this.issueReports,
    required this.teamworkMentions,
  });

  factory _StaffAccountabilityMetrics.empty({
    required double dailyTargetHours,
    required double weeklyTargetHours,
    required double monthlyTargetHours,
  }) {
    return _StaffAccountabilityMetrics(
      dailyTargetHours: dailyTargetHours,
      weeklyTargetHours: weeklyTargetHours,
      monthlyTargetHours: monthlyTargetHours,
      dailyEffortHours: 0,
      weeklyEffortHours: 0,
      monthlyEffortHours: 0,
      evidenceLogs: 0,
      issueReports: 0,
      teamworkMentions: 0,
    );
  }

  double get dailyProgress => dailyTargetHours <= 0 ? 0 : dailyEffortHours / dailyTargetHours;
  double get weeklyProgress => weeklyTargetHours <= 0 ? 0 : weeklyEffortHours / weeklyTargetHours;
  double get monthlyProgress => monthlyTargetHours <= 0 ? 0 : monthlyEffortHours / monthlyTargetHours;
}

class _TaskExecutionPayload {
  final String notes;
  final double effortHours;
  final String teamworkWith;
  final int? quantity;
  final String quantityUnit;
  final double directCostTzs;
  final double revenueTzs;
  final double? unitPriceTzs;
  final String financialCategory;
  final String issueType;
  final String issueDetails;
  final String photoUrl1;
  final String photoUrl2;
  final double latitude;
  final double longitude;

  const _TaskExecutionPayload({
    required this.notes,
    required this.effortHours,
    required this.teamworkWith,
    required this.quantity,
    required this.quantityUnit,
    required this.directCostTzs,
    required this.revenueTzs,
    required this.unitPriceTzs,
    required this.financialCategory,
    required this.issueType,
    required this.issueDetails,
    required this.photoUrl1,
    required this.photoUrl2,
    required this.latitude,
    required this.longitude,
  });
}

class _TaskExecutionDialog extends StatefulWidget {
  final Task task;
  final LocalizationService loc;

  const _TaskExecutionDialog({required this.task, required this.loc});

  @override
  State<_TaskExecutionDialog> createState() => _TaskExecutionDialogState();
}

class _TaskExecutionDialogState extends State<_TaskExecutionDialog> {
  final _notesController = TextEditingController();
  final _effortHoursController = TextEditingController(text: '1.0');
  final _teamworkController = TextEditingController();
  final _quantityController = TextEditingController();
  final _unitController = TextEditingController();
  final _directCostController = TextEditingController(text: '0');
  final _revenueController = TextEditingController(text: '0');
  final _unitPriceController = TextEditingController();
  final _issueDetailsController = TextEditingController();
  final _photo1Controller = TextEditingController();
  final _photo2Controller = TextEditingController();

  String _issueType = 'none';
  String _financialCategory = 'labor';
  bool _capturingGps = false;
  double? _latitude;
  double? _longitude;

  @override
  void dispose() {
    _notesController.dispose();
    _effortHoursController.dispose();
    _teamworkController.dispose();
    _quantityController.dispose();
    _unitController.dispose();
    _directCostController.dispose();
    _revenueController.dispose();
    _unitPriceController.dispose();
    _issueDetailsController.dispose();
    _photo1Controller.dispose();
    _photo2Controller.dispose();
    super.dispose();
  }

  Future<void> _captureGps() async {
    setState(() => _capturingGps = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.loc.t('gps_permission_required'))),
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      if (!mounted) return;
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${widget.loc.t('gps_capture_failed')}: $e')),
      );
    } finally {
      if (mounted) setState(() => _capturingGps = false);
    }
  }

  void _submit() {
    if (_notesController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.loc.t('execution_notes_required'))),
      );
      return;
    }

    if (_latitude == null || _longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.loc.t('gps_checkin_required'))),
      );
      return;
    }

    final effortHours = double.tryParse(_effortHoursController.text.trim());
    if (effortHours == null || effortHours <= 0 || effortHours > 24) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.loc.t('effort_hours_required'))),
      );
      return;
    }

    final directCost = double.tryParse(_directCostController.text.trim()) ?? 0;
    final revenue = double.tryParse(_revenueController.text.trim()) ?? 0;
    final unitPrice = _unitPriceController.text.trim().isEmpty
        ? null
        : double.tryParse(_unitPriceController.text.trim());

    if (directCost < 0 || revenue < 0 || (unitPrice != null && unitPrice < 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.loc.t('owner_financial_invalid_amount'))),
      );
      return;
    }

    if (_issueType != 'none' && _issueDetailsController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.loc.t('issue_details_required'))),
      );
      return;
    }

    Navigator.pop(
      context,
      _TaskExecutionPayload(
        notes: _notesController.text.trim(),
        effortHours: effortHours,
        teamworkWith: _teamworkController.text.trim(),
        quantity: int.tryParse(_quantityController.text.trim()),
        quantityUnit: _unitController.text.trim(),
        directCostTzs: directCost,
        revenueTzs: revenue,
        unitPriceTzs: unitPrice,
        financialCategory: _financialCategory,
        issueType: _issueType,
        issueDetails: _issueDetailsController.text.trim(),
        photoUrl1: _photo1Controller.text.trim(),
        photoUrl2: _photo2Controller.text.trim(),
        latitude: _latitude!,
        longitude: _longitude!,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final issueOptions = [
      DropdownMenuItem(value: 'none', child: Text(widget.loc.t('issue_none'))),
      DropdownMenuItem(value: 'delay', child: Text(widget.loc.t('issue_delay'))),
      DropdownMenuItem(value: 'input_shortage', child: Text(widget.loc.t('issue_input_shortage'))),
      DropdownMenuItem(value: 'disease_pest', child: Text(widget.loc.t('issue_disease_pest'))),
      DropdownMenuItem(value: 'safety', child: Text(widget.loc.t('issue_safety'))),
      DropdownMenuItem(value: 'other', child: Text(widget.loc.t('issue_other'))),
    ];
    final financialCategoryOptions = [
      DropdownMenuItem(value: 'feed', child: Text(widget.loc.t('owner_financial_cat_feed'))),
      DropdownMenuItem(value: 'vet', child: Text(widget.loc.t('owner_financial_cat_vet'))),
      DropdownMenuItem(value: 'labor', child: Text(widget.loc.t('owner_financial_cat_labor'))),
      DropdownMenuItem(value: 'fertilizer', child: Text(widget.loc.t('owner_financial_cat_fertilizer'))),
      DropdownMenuItem(value: 'fuel', child: Text(widget.loc.t('owner_financial_cat_fuel'))),
      DropdownMenuItem(value: 'maintenance', child: Text(widget.loc.t('owner_financial_cat_maintenance'))),
    ];

    return AlertDialog(
      title: Text(widget.loc.t('execute_task_title')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: InputDecoration(labelText: widget.loc.t('execution_notes_label')),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _effortHoursController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: widget.loc.t('effort_hours_label')),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _teamworkController,
                    decoration: InputDecoration(labelText: widget.loc.t('teamwork_with_label')),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _quantityController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: widget.loc.t('quantity_label')),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _unitController,
                    decoration: InputDecoration(labelText: widget.loc.t('quantity_unit_label')),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _financialCategory,
              items: financialCategoryOptions,
              onChanged: (value) => setState(() => _financialCategory = value ?? 'labor'),
              decoration: InputDecoration(labelText: widget.loc.t('owner_financial_category')),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _directCostController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: widget.loc.t('owner_financial_direct_cost')),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _revenueController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: widget.loc.t('owner_financial_revenue_realized')),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _unitPriceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: widget.loc.t('owner_financial_unit_price')),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _issueType,
              items: issueOptions,
              onChanged: (value) => setState(() => _issueType = value ?? 'none'),
              decoration: InputDecoration(labelText: widget.loc.t('issue_type_label')),
            ),
            if (_issueType != 'none') ...[
              const SizedBox(height: 8),
              TextField(
                controller: _issueDetailsController,
                maxLines: 2,
                decoration: InputDecoration(labelText: widget.loc.t('issue_details_label')),
              ),
            ],
            const SizedBox(height: 8),
            TextField(
              controller: _photo1Controller,
              decoration: InputDecoration(labelText: widget.loc.t('photo_url_1_label')),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _photo2Controller,
              decoration: InputDecoration(labelText: widget.loc.t('photo_url_2_label')),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _capturingGps ? null : _captureGps,
                    icon: const Icon(Icons.my_location),
                    label: Text(widget.loc.t('capture_gps_checkin')),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _latitude == null || _longitude == null
                    ? widget.loc.t('gps_not_captured')
                    : '${widget.loc.t('gps_captured')}: ${_latitude!.toStringAsFixed(6)}, ${_longitude!.toStringAsFixed(6)}',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(widget.loc.t('cancel_task')),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: Text(widget.loc.t('submit_execution_report')),
        ),
      ],
    );
  }
}
