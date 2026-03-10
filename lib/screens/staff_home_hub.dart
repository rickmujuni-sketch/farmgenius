import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/external_partner_entry.dart';
import '../legacy_content.dart';
import '../models/biological_asset.dart';
import '../models/farm_zone.dart';
import '../models/operations_assist.dart';
import '../services/ai_orchestrator.dart';
import '../services/auth_service.dart';
import '../services/biological_asset_service.dart';
import '../services/demo_seed_service.dart';
import '../services/external_partner_service.dart';
import '../services/ledger_service.dart';
import '../services/localization_service.dart';
import '../services/operations_assist_service.dart';
import '../services/supabase_service.dart';
import 'daily_asset_check_form_screen.dart';
import 'dashboard_hub_scaffold.dart';

class StaffHome extends StatefulWidget {
  const StaffHome({super.key});

  @override
  State<StaffHome> createState() => _StaffHomeState();
}

class _StaffHomeState extends State<StaffHome> {
  static const _storage = FlutterSecureStorage();
  static const _checksFilterKey = 'staff_checks_filter';

  late Future<_StaffDashboardData> _dashboardFuture;
  String _checksFilter = 'all';

  @override
  void initState() {
    super.initState();
    _dashboardFuture = _loadData();
    _loadSavedChecksFilter();
  }

  Future<void> _loadSavedChecksFilter() async {
    final saved = await _storage.read(key: _checksFilterKey);
    if (!mounted) return;
    if (saved == 'today' || saved == 'week' || saved == 'all') {
      setState(() => _checksFilter = saved!);
    }
  }

  Future<void> _setChecksFilter(String value) async {
    await _storage.write(key: _checksFilterKey, value: value);
    if (!mounted) return;
    setState(() => _checksFilter = value);
  }

  Future<_StaffDashboardData> _loadData() async {
    final ai = Provider.of<AIOrchestrator>(context, listen: false);
    final auth = Provider.of<AuthService>(context, listen: false);
    final staffId = auth.user?.id;

    await DemoSeedService.ensureSeedData(userId: staffId);

    final results = await Future.wait([
      ai.getPendingTasksForStaff(staffId),
      BiologicalAssetService.getRecentDailyChecks(limit: 30),
      _loadAccountabilityMetrics(staffId),
      OperationsAssistService.loadSnapshot(),
      ExternalPartnerService.getEntries(submittedBy: staffId, limit: 20),
    ]);

    final tasks = results[0] as List<Task>;
    final checks = results[1] as List<DailyAssetCheck>;

    return _StaffDashboardData(
      tasks: tasks,
      checks: checks,
      metrics: results[2] as _StaffMetrics,
      assist: results[3] as OperationsAssistSnapshot,
      externalEntries: results[4] as List<ExternalPartnerEntry>,
    );
  }

  Future<void> _openExternalEntriesDetail(_StaffDashboardData data) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DrillDownScaffold(
          title: 'External Service Log',
          children: [
            ElevatedButton.icon(
              onPressed: _openAddExternalEntryDialog,
              icon: const Icon(Icons.add),
              label: const Text('Log doctor/supplier event'),
            ),
            const SizedBox(height: 10),
            if (data.externalEntries.isEmpty)
              const ListTile(
                title: Text('No external events logged yet'),
                subtitle: Text('Doctor and suppliers can log each visit/service/delivery here.'),
              )
            else
              ...data.externalEntries.map(
                (entry) => ListTile(
                  title: Text('${entry.partnerType.toUpperCase()} • ${entry.partnerName}'),
                  subtitle: Text(
                    '${entry.entryKind} • ${entry.serviceDate == null ? '-' : DateFormat('dd MMM yyyy').format(entry.serviceDate!)}\n'
                    'Verification: ${entry.verificationStatus} • Payment: ${entry.paymentStatus}',
                  ),
                  isThreeLine: true,
                  trailing: Text(
                    NumberFormat('#,##0', 'en_US').format(entry.amountTzs),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Text(
              'Two-eyes control: your manager/owner verifies each doctor/supplier event before payment is approved.',
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );

    if (!mounted) return;
    setState(() => _dashboardFuture = _loadData());
  }

  Future<void> _openAddExternalEntryDialog() async {
    final partnerNameController = TextEditingController();
    final descriptionController = TextEditingController();
    final amountController = TextEditingController(text: '0');

    String partnerType = 'doctor';
    String entryKind = 'service';

    final approved = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Log external event'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: partnerType,
                  decoration: const InputDecoration(labelText: 'Partner type'),
                  items: const [
                    DropdownMenuItem(value: 'doctor', child: Text('Doctor/Vet')),
                    DropdownMenuItem(value: 'supplier', child: Text('Supplier')),
                    DropdownMenuItem(value: 'contractor', child: Text('Contractor')),
                    DropdownMenuItem(value: 'other', child: Text('Other')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setDialogState(() => partnerType = value);
                  },
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: entryKind,
                  decoration: const InputDecoration(labelText: 'Event kind'),
                  items: const [
                    DropdownMenuItem(value: 'visit', child: Text('Visit')),
                    DropdownMenuItem(value: 'service', child: Text('Service')),
                    DropdownMenuItem(value: 'delivery', child: Text('Delivery')),
                    DropdownMenuItem(value: 'invoice', child: Text('Invoice')),
                    DropdownMenuItem(value: 'payment_request', child: Text('Payment Request')),
                    DropdownMenuItem(value: 'note', child: Text('Note')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setDialogState(() => entryKind = value);
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: partnerNameController,
                  decoration: const InputDecoration(labelText: 'Partner name'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Amount (TZS)'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Description / What was done'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Submit')),
          ],
        ),
      ),
    );

    if (approved != true) return;
    final name = partnerNameController.text.trim();
    if (name.isEmpty) return;

    final amount = double.tryParse(amountController.text.trim()) ?? 0;

    try {
      await ExternalPartnerService.submitEntry(
        partnerType: partnerType,
        entryKind: entryKind,
        partnerName: name,
        serviceDate: DateTime.now(),
        description: descriptionController.text.trim(),
        amountTzs: amount,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('External event logged. Awaiting verification.')),
      );
      setState(() => _dashboardFuture = _loadData());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not log external event: $e')),
      );
    }
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

  Future<_StaffMetrics> _loadAccountabilityMetrics(String? staffId) async {
    if (staffId == null || staffId.isEmpty) {
      return const _StaffMetrics();
    }

    try {
      final rows = await SupabaseService.client
          .from('activity_logs')
          .select('logged_at,completed_at,notes,photo_urls,cost')
          .eq('staff_id', staffId)
          .order('completed_at', ascending: false)
          .limit(500);

      if (rows is! List) return const _StaffMetrics();

      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final weekStart = todayStart.subtract(const Duration(days: 6));
      final monthStart = DateTime(now.year, now.month, 1);

      double dailyEffort = 0;
      double weeklyEffort = 0;
      double monthlyEffort = 0;
      double monthlyLaborPayoutTzs = 0;
      int casualLaborEvents = 0;
      int evidenceLogs = 0;

      for (final row in rows.whereType<Map<String, dynamic>>()) {
        final completedAt = DateTime.tryParse((row['completed_at'] ?? row['logged_at'] ?? '').toString());
        if (completedAt == null) continue;

        final notes = (row['notes'] ?? '').toString();
        final photoUrls = row['photo_urls'];
        final hasPhotoEvidence = photoUrls is Map && photoUrls.isNotEmpty;
        if (hasPhotoEvidence) evidenceLogs++;

        final effortHours = _resolveEffortHours(row, notes);
        if (!completedAt.isBefore(todayStart)) dailyEffort += effortHours;
        if (!completedAt.isBefore(weekStart)) weeklyEffort += effortHours;
        if (!completedAt.isBefore(monthStart)) {
          monthlyEffort += effortHours;
          monthlyLaborPayoutTzs += _toDouble(row['cost']);
          if (notes.toLowerCase().contains('casual laborers:')) {
            casualLaborEvents += 1;
          }
        }
      }

      return _StaffMetrics(
        dailyEffortHours: dailyEffort,
        weeklyEffortHours: weeklyEffort,
        monthlyEffortHours: monthlyEffort,
        monthlyLaborPayoutTzs: monthlyLaborPayoutTzs,
        casualLaborEvents: casualLaborEvents,
        evidenceLogs: evidenceLogs,
      );
    } catch (_) {
      return const _StaffMetrics();
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

  double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  Future<void> _markTaskInProgress(Task task) async {
    final loc = Provider.of<LocalizationService>(context, listen: false);
    final staffId = Provider.of<AuthService>(context, listen: false).user?.id;
    if (staffId == null) return;

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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.t('task_marked_in_progress'))));
      setState(() => _dashboardFuture = _loadData());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${loc.t('staff_could_not_update_task')}: $e')),
      );
    }
  }

  Future<void> _submitQuickExecution(Task task) async {
    final loc = Provider.of<LocalizationService>(context, listen: false);
    final auth = Provider.of<AuthService>(context, listen: false);
    final staffId = auth.user?.id;
    if (staffId == null) return;

    final notesController = TextEditingController();
    final effortController = TextEditingController(text: '1.0');
    final casualWorkersController = TextEditingController(text: '0');
    final payPerWorkerController = TextEditingController(text: '0');
    final extraCostController = TextEditingController(text: '0');

    final approved = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(loc.t('staff_submit_task_for_review')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: notesController,
              maxLines: 3,
              decoration: InputDecoration(labelText: loc.t('execution_notes_label')),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: effortController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: loc.t('effort_hours_label')),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: casualWorkersController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Casual laborers used'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: payPerWorkerController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Pay per laborer (TZS)'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: extraCostController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Other direct cost (TZS)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(loc.t('cancel'))),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: Text(loc.t('submit'))),
        ],
      ),
    );

    if (approved != true) return;

    final effort = double.tryParse(effortController.text.trim()) ?? 1.0;
    final notes = notesController.text.trim().isEmpty ? loc.t('staff_execution_completed') : notesController.text.trim();
    final casualWorkers = int.tryParse(casualWorkersController.text.trim()) ?? 0;
    final payPerWorker = double.tryParse(payPerWorkerController.text.trim()) ?? 0;
    final extraCostTzs = double.tryParse(extraCostController.text.trim()) ?? 0;

    final laborCostTzs = effort * 3500;
    final casualLaborCostTzs = casualWorkers * payPerWorker;
    final totalCostTzs = laborCostTzs + casualLaborCostTzs + extraCostTzs;

    try {
      final now = DateTime.now();
      final activityLogId = 'log_${task.id}_${now.millisecondsSinceEpoch}';

      await SupabaseService.client.from('activity_logs').insert({
        'id': activityLogId,
        'task_id': task.id,
        'zone_id': task.zoneId,
        'staff_id': staffId,
        'activity': task.activity.name,
        'logged_at': now.subtract(Duration(minutes: (effort * 60).round())).toIso8601String(),
        'completed_at': now.toIso8601String(),
        'notes':
            'Execution Notes: $notes\n'
            'Effort Hours: ${effort.toStringAsFixed(2)}\n'
            'Labor Cost (TZS): ${laborCostTzs.toStringAsFixed(0)}\n'
            'Casual Laborers: $casualWorkers\n'
            'Pay Per Laborer (TZS): ${payPerWorker.toStringAsFixed(0)}\n'
            'Casual Labor Cost (TZS): ${casualLaborCostTzs.toStringAsFixed(0)}\n'
            'Other Direct Cost (TZS): ${extraCostTzs.toStringAsFixed(0)}\n'
            'Total Cost (TZS): ${totalCostTzs.toStringAsFixed(0)}',
        'cost': totalCostTzs,
      });

      await LedgerService.recordExecutionFinancials(
        activityLogId: activityLogId,
        taskId: task.id,
        staffId: staffId,
        zoneId: task.zoneId,
        activity: task.activity.name,
        occurredAt: now,
        financialCategory: 'labor',
        costTzs: totalCostTzs,
        revenueTzs: 0,
        metadata: {
          'effort_hours': effort,
          'base_labor_cost_tzs': laborCostTzs,
          'casual_workers': casualWorkers,
          'pay_per_worker_tzs': payPerWorker,
          'casual_labor_cost_tzs': casualLaborCostTzs,
          'extra_cost_tzs': extraCostTzs,
          'total_cost_tzs': totalCostTzs,
        },
      );

      await SupabaseService.client
          .from('tasks')
          .update({'status': 'REVIEW_PENDING', 'assigned_staff_id': staffId, 'updated_at': now.toIso8601String()})
          .eq('id', task.id);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.t('task_submitted_for_review'))));
      setState(() => _dashboardFuture = _loadData());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${loc.t('staff_could_not_submit_task')}: $e')),
      );
    }
  }

  Future<void> _openDailyCheckForm({DailyAssetCheck? existingCheck}) async {
    final loc = Provider.of<LocalizationService>(context, listen: false);
    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => DailyAssetCheckFormScreen(existingCheck: existingCheck)),
    );

    if (!mounted) return;
    if (updated == true) {
      setState(() => _dashboardFuture = _loadData());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(existingCheck == null ? loc.t('daily_check_created') : loc.t('daily_check_updated'))),
      );
    }
  }

  void _openTasksDetail(_StaffDashboardData data) {
    final loc = Provider.of<LocalizationService>(context, listen: false);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DrillDownScaffold(
          title: loc.t('staff_my_tasks'),
          children: data.tasks
              .map(
                (task) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(task.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(task.description),
                        const SizedBox(height: 6),
                        Text('${loc.t('due')}: ${task.dueDate.toLocal().toString().split(' ').first} • ${_taskStatusLabel(task.status, loc)}'),
                        if (task.status == TaskStatus.REVIEW_PENDING) ...[
                          const SizedBox(height: 8),
                          Chip(
                            label: Text(loc.t('awaiting_review')),
                            avatar: const Icon(Icons.hourglass_top, size: 18),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton(
                              onPressed: task.status == TaskStatus.PENDING ? () => _markTaskInProgress(task) : null,
                              child: Text(loc.t('staff_start')),
                            ),
                            ElevatedButton(
                              onPressed: task.status == TaskStatus.PENDING || task.status == TaskStatus.IN_PROGRESS
                                  ? () => _submitQuickExecution(task)
                                  : null,
                              child: Text(loc.t('staff_submit_review')),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  void _openAccountabilityDetail(_StaffDashboardData data) {
    final loc = Provider.of<LocalizationService>(context, listen: false);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DrillDownScaffold(
          title: loc.t('accountability_dashboard'),
          children: [
            _metricTile(loc.t('daily_effort'), '${data.metrics.dailyEffortHours.toStringAsFixed(1)}h / 8h', Colors.green.shade700),
            _metricTile(loc.t('weekly_effort'), '${data.metrics.weeklyEffortHours.toStringAsFixed(1)}h / 40h', Colors.blue.shade700),
            _metricTile(loc.t('monthly_effort'), '${data.metrics.monthlyEffortHours.toStringAsFixed(1)}h / 160h', Colors.purple.shade700),
            _metricTile(
              'Monthly Labor Payout',
              'TZS ${NumberFormat('#,##0', 'en_US').format(data.metrics.monthlyLaborPayoutTzs)}',
              Colors.brown.shade700,
            ),
            _metricTile('Casual Labor Events', '${data.metrics.casualLaborEvents}', Colors.indigo.shade700),
            _metricTile(loc.t('evidence_logs'), '${data.metrics.evidenceLogs}', Colors.orange.shade800),
          ],
        ),
      ),
    );
  }

  void _openChecksDetail(_StaffDashboardData data) {
    final loc = Provider.of<LocalizationService>(context, listen: false);
    final filtered = _applyChecksFilter(data.checks);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DrillDownScaffold(
          title: loc.t('staff_daily_checks'),
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(label: Text(loc.t('today')), selected: _checksFilter == 'today', onSelected: (_) => _setChecksFilter('today')),
                ChoiceChip(label: Text(loc.t('this_week')), selected: _checksFilter == 'week', onSelected: (_) => _setChecksFilter('week')),
                ChoiceChip(label: Text(loc.t('all')), selected: _checksFilter == 'all', onSelected: (_) => _setChecksFilter('all')),
                ElevatedButton.icon(
                  onPressed: () => _openDailyCheckForm(),
                  icon: const Icon(Icons.add),
                  label: Text(loc.t('staff_new_check')),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...filtered.map(
              (check) {
                final evidenceCount = _evidenceCountForCheck(check);
                return ListTile(
                  title: Text('${check.checklistType} • ${check.timeBlock}'),
                  subtitle: Text(
                    '${check.checkDate.toLocal().toString().split(' ').first} • ${check.zoneId ?? loc.t('staff_no_zone')}\n'
                    '${loc.t('staff_evidence_items')}: $evidenceCount',
                  ),
                  isThreeLine: true,
                  trailing: SizedBox(
                    width: 96,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          onPressed: evidenceCount == 0 ? null : () => _openEvidenceDialog(check),
                          icon: const Icon(Icons.photo_library_outlined),
                          tooltip: loc.t('staff_view_evidence'),
                        ),
                        IconButton(
                          onPressed: () => _openDailyCheckForm(existingCheck: check),
                          icon: const Icon(Icons.edit),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  int _evidenceCountForCheck(DailyAssetCheck check) {
    final evidence = (check.observations['evidence'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
    final receipts = (evidence['receipts'] as List?) ?? const [];
    final animals = (evidence['animals'] as List?) ?? const [];
    final plants = (evidence['plants'] as List?) ?? const [];
    final infrastructure = (evidence['infrastructure'] as List?) ?? const [];
    final other = (evidence['other'] as List?) ?? const [];
    return receipts.length + animals.length + plants.length + infrastructure.length + other.length;
  }

  Map<String, List<String>> _evidenceUrlsByCategory(DailyAssetCheck check, LocalizationService loc) {
    final evidence = (check.observations['evidence'] as Map<String, dynamic>?) ?? const <String, dynamic>{};

    List<String> toUrls(dynamic value) {
      if (value is! List) return const [];
      return value.map((item) => item.toString().trim()).where((url) => url.isNotEmpty).toList();
    }

    return {
      loc.t('staff_receipt_photos'): toUrls(evidence['receipts']),
      loc.t('staff_animal_photos'): toUrls(evidence['animals']),
      loc.t('staff_plant_photos'): toUrls(evidence['plants']),
      loc.t('staff_infrastructure_photos'): toUrls(evidence['infrastructure']),
      loc.t('staff_other_photos'): toUrls(evidence['other']),
    };
  }

  Future<void> _openEvidenceDialog(DailyAssetCheck check) async {
    final loc = Provider.of<LocalizationService>(context, listen: false);
    final categories = _evidenceUrlsByCategory(check, loc);
    final hasAny = categories.values.any((urls) => urls.isNotEmpty);

    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(loc.t('staff_evidence_urls_title')),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: hasAny
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: categories.entries
                        .where((entry) => entry.value.isNotEmpty)
                        .expand(
                          (entry) => [
                            Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 6),
                            ...entry.value.map(
                              (url) => ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.link, size: 18),
                                title: Text(
                                  url,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    decoration: TextDecoration.underline,
                                    color: Colors.blue,
                                  ),
                                ),
                                onTap: () => _openEvidenceUrl(url, loc),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                        )
                        .toList(),
                  )
                : Text(loc.t('staff_no_evidence_available')),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(loc.t('cancel'))),
        ],
      ),
    );
  }

  Future<void> _openEvidenceUrl(String url, LocalizationService loc) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.t('staff_could_not_open_link'))),
      );
      return;
    }

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.t('staff_could_not_open_link'))),
      );
    }
  }

  void _openAssistDetail(_StaffDashboardData data) {
    final loc = Provider.of<LocalizationService>(context, listen: false);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DrillDownScaffold(
          title: loc.t('staff_today_assist_tips'),
          children: [
            ...data.assist.recommendations.map(
              (item) => ListTile(
                title: Text(item.title),
                subtitle: Text(item.action),
                trailing: Text(item.priority.toUpperCase()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openLegacyDetail() {
    final loc = Provider.of<LocalizationService>(context, listen: false);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DrillDownScaffold(
          title: loc.t('staff_legacy'),
          children: const [
            Text(
              LegacyContent.signboard,
              style: TextStyle(fontWeight: FontWeight.w700, height: 1.4),
            ),
            SizedBox(height: 12),
            Text(
              LegacyContent.websiteHero,
              style: TextStyle(height: 1.4),
            ),
            SizedBox(height: 12),
            Text(
              LegacyContent.dedication,
              style: TextStyle(height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricTile(String title, String value, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600))),
          Text(value, style: TextStyle(fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }

  String _taskStatusLabel(TaskStatus status, LocalizationService loc) {
    switch (status) {
      case TaskStatus.PENDING:
        return loc.t('pending');
      case TaskStatus.IN_PROGRESS:
        return loc.t('in_progress');
      case TaskStatus.REVIEW_PENDING:
        return loc.t('awaiting_review');
      case TaskStatus.COMPLETED:
        return loc.t('completed');
      case TaskStatus.CANCELLED:
        return loc.t('cancelled');
      case TaskStatus.OVERDUE:
        return loc.t('overdue');
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = Provider.of<LocalizationService>(context);
    final auth = Provider.of<AuthService>(context, listen: false);

    return DashboardHubScaffold(
      title: loc.t('staff_home'),
      onRefresh: () => setState(() => _dashboardFuture = _loadData()),
      onLogout: () async {
        await auth.signOut();
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/');
      },
      child: FutureBuilder<_StaffDashboardData>(
        future: _dashboardFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return Center(child: Text(loc.t('staff_dashboard_load_error')));
          }

          final data = snapshot.data!;
          final filteredChecks = _applyChecksFilter(data.checks);
          final topTip = data.assist.recommendations.isEmpty ? loc.t('staff_no_tip_right_now') : data.assist.recommendations.first.title;

          final cards = [
            HubSummaryCard(
              icon: Icons.assignment_turned_in,
              title: loc.t('staff_my_tasks'),
              primaryValue: '${data.tasks.length} ${loc.t('staff_active_tasks')}',
              secondaryValue: loc.t('staff_tap_start_or_submit_review'),
              color: Colors.blue.shade700,
              onTap: () => _openTasksDetail(data),
            ),
            HubSummaryCard(
              icon: Icons.track_changes,
              title: loc.t('accountability_dashboard'),
              primaryValue: '${data.metrics.dailyEffortHours.toStringAsFixed(1)}h ${loc.t('today')}',
              secondaryValue: '${data.metrics.evidenceLogs} ${loc.t('evidence_logs')}',
              color: Colors.green.shade700,
              onTap: () => _openAccountabilityDetail(data),
            ),
            HubSummaryCard(
              icon: Icons.fact_check,
              title: loc.t('staff_daily_checks'),
              primaryValue: '${filteredChecks.length} ${loc.t('staff_visible_checks')}',
              secondaryValue: loc.t('staff_create_filter_edit_checks'),
              color: Colors.orange.shade800,
              onTap: () => _openChecksDetail(data),
            ),
            HubSummaryCard(
              icon: Icons.lightbulb_outline,
              title: loc.t('staff_assist_tip'),
              primaryValue: '${data.assist.readinessScore}/100 ${loc.t('staff_readiness')}',
              secondaryValue: topTip,
              color: Colors.purple.shade700,
              onTap: () => _openAssistDetail(data),
            ),
            HubSummaryCard(
              icon: Icons.medical_services,
              title: 'External Services',
              primaryValue: '${data.externalEntries.length} events logged',
              secondaryValue: 'Doctor/supplier logs + verification status',
              color: Colors.indigo.shade700,
              onTap: () => _openExternalEntriesDetail(data),
            ),
            HubSummaryCard(
              icon: Icons.favorite,
              title: loc.t('staff_legacy'),
              primaryValue: 'Dr. Pascal Fidelis Mujuni',
              secondaryValue: loc.t('staff_tap_view_dedication'),
              color: Colors.teal.shade700,
              onTap: _openLegacyDetail,
            ),
          ];

          return LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth > 760 ? 2 : 1;
              return GridView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: cards.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: crossAxisCount == 2 ? 1.7 : 2.0,
                ),
                itemBuilder: (_, index) => cards[index],
              );
            },
          );
        },
      ),
    );
  }
}

class _StaffDashboardData {
  final List<Task> tasks;
  final List<DailyAssetCheck> checks;
  final _StaffMetrics metrics;
  final OperationsAssistSnapshot assist;
  final List<ExternalPartnerEntry> externalEntries;

  const _StaffDashboardData({
    required this.tasks,
    required this.checks,
    required this.metrics,
    required this.assist,
    required this.externalEntries,
  });
}

class _StaffMetrics {
  final double dailyEffortHours;
  final double weeklyEffortHours;
  final double monthlyEffortHours;
  final double monthlyLaborPayoutTzs;
  final int casualLaborEvents;
  final int evidenceLogs;

  const _StaffMetrics({
    this.dailyEffortHours = 0,
    this.weeklyEffortHours = 0,
    this.monthlyEffortHours = 0,
    this.monthlyLaborPayoutTzs = 0,
    this.casualLaborEvents = 0,
    this.evidenceLogs = 0,
  });
}
