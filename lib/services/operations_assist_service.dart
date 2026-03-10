import '../models/operations_assist.dart';
import 'package:meta/meta.dart';
import 'supabase_service.dart';

class OperationsAssistService {
  static Future<OperationsAssistSnapshot> loadSnapshot({DateTime? now}) async {
    final current = now ?? DateTime.now();
    final lookbackStart = current.subtract(const Duration(days: 180));

    final activityLogs = await _loadActivityLogs(lookbackStart, current);
    final ledgerEntries = await _loadLedgerEntries(lookbackStart, current);
    final inventoryItems = await _loadInventoryItems();
    final inventoryTransactions = await _loadInventoryTransactions(current.subtract(const Duration(days: 42)), current);
    final externalEntries = await _loadExternalPartnerEntries(current.subtract(const Duration(days: 60)), current);
    final tasks = await _loadTasks(current.subtract(const Duration(days: 30)), current.add(const Duration(days: 30)));
    final anomalies = await _loadAnomalies(current.subtract(const Duration(days: 90)), current);
    final staffCount = await _loadStaffCount();
    final recommendationStatusCounts = await _loadRecommendationStatusCounts();
    final recommendationExecutionLogs = await _loadRecommendationExecutionLogs();

    final recommendations = <OperationsAssistRecommendation>[];

    _addMaintenanceRecommendations(recommendations, activityLogs, ledgerEntries, current);
    _addPlantingRecommendations(recommendations, tasks);
    _addHiringRecommendations(recommendations, tasks, staffCount);
    _addHealthRecommendations(recommendations, activityLogs, ledgerEntries, anomalies, current);
    _addProcurementRecommendations(recommendations, activityLogs, ledgerEntries);
    _addInventoryRecommendations(recommendations, inventoryItems, inventoryTransactions);
    _addExternalVerificationRecommendations(recommendations, externalEntries);
    _addRetrospectiveQualityRecommendations(recommendations, activityLogs, tasks, anomalies, current);

    recommendations.sort((a, b) => _priorityRank(a.priority).compareTo(_priorityRank(b.priority)));

    final readinessScore = _computeReadinessScore(recommendations);

    return OperationsAssistSnapshot(
      readinessScore: readinessScore,
      recommendations: recommendations.take(8).toList(),
      recommendationStatusCounts: recommendationStatusCounts,
      recommendationExecutionLogs: recommendationExecutionLogs,
      ownershipRules: const [
        DataEntryOwnershipRule(
          dataType: 'Task execution and yields',
          primaryRole: 'Staff',
          reviewRole: 'Manager',
          positiveImpact: 'Improves daily operational planning and harvest forecasting.',
        ),
        DataEntryOwnershipRule(
          dataType: 'Machine service and maintenance',
          primaryRole: 'Staff / Technician',
          reviewRole: 'Manager',
          positiveImpact: 'Reduces downtime and improves replacement and procurement timing.',
        ),
        DataEntryOwnershipRule(
          dataType: 'Medication and vaccines',
          primaryRole: 'Livestock staff / Vet',
          reviewRole: 'Manager',
          positiveImpact: 'Protects herd health, compliance, and treatment traceability.',
        ),
        DataEntryOwnershipRule(
          dataType: 'Procurement and financial ledger entries',
          primaryRole: 'Owner / Finance',
          reviewRole: 'Manager',
          positiveImpact: 'Improves budget control, vendor decisions, and fraud resistance.',
        ),
        DataEntryOwnershipRule(
          dataType: 'Hiring, attendance, and effort records',
          primaryRole: 'Manager',
          reviewRole: 'Owner',
          positiveImpact: 'Aligns labor capacity to seasonal workload and reduces overtime waste.',
        ),
        DataEntryOwnershipRule(
          dataType: 'Inventory balances and stock movements',
          primaryRole: 'Storekeeper / Staff',
          reviewRole: 'Manager',
          positiveImpact: 'Provides 3-week replenishment visibility and prevents stock-outs during critical operations.',
        ),
        DataEntryOwnershipRule(
          dataType: 'External doctor and supplier records',
          primaryRole: 'External partner',
          reviewRole: 'Manager / Owner',
          positiveImpact: 'Improves payment traceability and ensures all external services are verified before approval.',
        ),
      ],
    );
  }

  static Future<Map<String, int>> _loadRecommendationStatusCounts() async {
    try {
      final rows = await SupabaseService.client.from('recommendations').select('status,expires_at');
      final counts = <String, int>{
        'proposed': 0,
        'accepted': 0,
        'modified': 0,
        'deferred': 0,
        'executed': 0,
      };
      final now = DateTime.now();

      if (rows is List) {
        for (final row in rows) {
          if (row is! Map<String, dynamic>) continue;
          final status = (row['status'] ?? '').toString().toLowerCase();
          if (!counts.containsKey(status)) continue;

          final expiresAtRaw = row['expires_at']?.toString();
          if (status != 'executed' && expiresAtRaw != null) {
            final expiresAt = DateTime.tryParse(expiresAtRaw);
            if (expiresAt != null && expiresAt.isBefore(now)) continue;
          }

          counts[status] = (counts[status] ?? 0) + 1;
        }
      }

      return counts;
    } catch (_) {
      return const {};
    }
  }

  static Future<List<RecommendationExecutionLog>> _loadRecommendationExecutionLogs() async {
    try {
      final rows = await SupabaseService.client
          .from('recommendation_actions')
          .select('action_type,action_notes,acted_at,recommendations(recommendation_text)')
          .order('acted_at', ascending: false)
          .limit(8);

      if (rows is! List) {
        return const [];
      }

      final logs = <RecommendationExecutionLog>[];
      for (final row in rows) {
        if (row is! Map<String, dynamic>) continue;
        final recommendation = row['recommendations'];
        String recommendationText = 'Recommendation';
        if (recommendation is Map<String, dynamic>) {
          recommendationText = (recommendation['recommendation_text'] ?? 'Recommendation').toString();
        }

        logs.add(
          RecommendationExecutionLog(
            actionType: (row['action_type'] ?? '').toString(),
            recommendationText: recommendationText,
            notes: row['action_notes']?.toString(),
            actedAt: row['acted_at'] != null
                ? DateTime.tryParse(row['acted_at'].toString())
                : null,
          ),
        );
      }
      return logs;
    } catch (_) {
      return const [];
    }
  }

  static Future<List<Map<String, dynamic>>> _loadActivityLogs(DateTime start, DateTime end) async {
    try {
      final rows = await SupabaseService.client
          .from('activity_logs')
          .select('activity,notes,cost,completed_at,staff_id,zone_id,photo_urls')
          .gte('completed_at', start.toIso8601String())
          .lt('completed_at', end.toIso8601String())
          .order('completed_at', ascending: true);
      if (rows is List) {
        return rows.whereType<Map<String, dynamic>>().toList();
      }
    } catch (_) {}
    return const [];
  }

  static Future<List<Map<String, dynamic>>> _loadTasks(DateTime start, DateTime end) async {
    try {
      final rows = await SupabaseService.client
          .from('tasks')
          .select('activity,status,due_date,assigned_staff_id')
          .gte('due_date', start.toIso8601String())
          .lt('due_date', end.toIso8601String());
      if (rows is List) {
        return rows.whereType<Map<String, dynamic>>().toList();
      }
    } catch (_) {}
    return const [];
  }

  static Future<List<Map<String, dynamic>>> _loadLedgerEntries(DateTime start, DateTime end) async {
    try {
      final rows = await SupabaseService.client
          .from('farm_ledger_entries')
          .select('entry_type,category,amount_tzs,occurred_at,metadata')
          .gte('occurred_at', start.toIso8601String())
          .lt('occurred_at', end.toIso8601String())
          .order('occurred_at', ascending: true);
      if (rows is List) {
        return rows.whereType<Map<String, dynamic>>().toList();
      }
    } catch (_) {}
    return const [];
  }

  static Future<List<Map<String, dynamic>>> _loadAnomalies(DateTime start, DateTime end) async {
    try {
      final rows = await SupabaseService.client
          .from('anomalies')
          .select('type,status,severity,detected_at')
          .gte('detected_at', start.toIso8601String())
          .lt('detected_at', end.toIso8601String());
      if (rows is List) {
        return rows.whereType<Map<String, dynamic>>().toList();
      }
    } catch (_) {}
    return const [];
  }

  static Future<int> _loadStaffCount() async {
    try {
      final rows = await SupabaseService.client.from('profiles').select('id,role').eq('role', 'staff');
      if (rows is List) {
        return rows.length;
      }
    } catch (_) {}
    return 0;
  }

  static Future<List<Map<String, dynamic>>> _loadInventoryItems() async {
    try {
      final rows = await SupabaseService.client
          .from('inventory_items')
          .select('id,name,quantity_on_hand,reorder_level,target_days_cover,avg_daily_usage,unit_cost_tzs,unit,is_active')
          .eq('is_active', true);
      if (rows is List) {
        return rows.whereType<Map<String, dynamic>>().toList();
      }
    } catch (_) {}
    return const [];
  }

  static Future<List<Map<String, dynamic>>> _loadInventoryTransactions(DateTime start, DateTime end) async {
    try {
      final rows = await SupabaseService.client
          .from('inventory_transactions')
          .select('item_id,movement_type,quantity,transaction_date,verification_status')
          .gte('transaction_date', start.toIso8601String())
          .lt('transaction_date', end.toIso8601String())
          .order('transaction_date', ascending: true);
      if (rows is List) {
        return rows.whereType<Map<String, dynamic>>().toList();
      }
    } catch (_) {}
    return const [];
  }

  static Future<List<Map<String, dynamic>>> _loadExternalPartnerEntries(DateTime start, DateTime end) async {
    try {
      final rows = await SupabaseService.client
          .from('external_partner_entries')
          .select('partner_type,entry_kind,amount_tzs,verification_status,payment_status,created_at')
          .gte('created_at', start.toIso8601String())
          .lt('created_at', end.toIso8601String());
      if (rows is List) {
        return rows.whereType<Map<String, dynamic>>().toList();
      }
    } catch (_) {}
    return const [];
  }

  static void _addMaintenanceRecommendations(
    List<OperationsAssistRecommendation> out,
    List<Map<String, dynamic>> logs,
    List<Map<String, dynamic>> ledgerEntries,
    DateTime current,
  ) {
    final currentMonth = DateTime(current.year, current.month, 1);
    final previousMonth = DateTime(current.year, current.month - 1, 1);

    var currentCost = 0.0;
    var previousCost = 0.0;
    var maintenanceLogs = 0;

    final maintenanceLedger = ledgerEntries.where((entry) {
      final entryType = (entry['entry_type'] ?? '').toString().toLowerCase();
      final category = (entry['category'] ?? '').toString().toLowerCase();
      return entryType == 'expense' && category == 'maintenance';
    }).toList();

    if (maintenanceLedger.isNotEmpty) {
      for (final row in maintenanceLedger) {
        maintenanceLogs++;
        final occurredAt = DateTime.tryParse((row['occurred_at'] ?? '').toString());
        final cost = _toDouble(row['amount_tzs']);
        if (occurredAt == null) continue;
        final monthBucket = DateTime(occurredAt.year, occurredAt.month, 1);
        if (monthBucket == currentMonth) currentCost += cost;
        if (monthBucket == previousMonth) previousCost += cost;
      }
    } else {
      for (final row in logs) {
        final activity = (row['activity'] ?? '').toString().toLowerCase();
        final notes = (row['notes'] ?? '').toString().toLowerCase();
        if (!activity.contains('maintenance') && !activity.contains('repair') && !notes.contains('maintenance')) {
          continue;
        }

        maintenanceLogs++;
        final completedAt = DateTime.tryParse((row['completed_at'] ?? '').toString());
        final cost = _toDouble(row['cost']);
        if (completedAt == null) continue;

        final monthBucket = DateTime(completedAt.year, completedAt.month, 1);
        if (monthBucket == currentMonth) currentCost += cost;
        if (monthBucket == previousMonth) previousCost += cost;
      }
    }

    if (maintenanceLogs < 2) {
      out.add(
        const OperationsAssistRecommendation(
          area: 'maintenance',
          title: 'Establish machine maintenance baseline',
          action:
              'Log every service event with parts cost and downtime minutes to build wear-and-tear curves before failures occur.',
          expectedImpact: 'Enables better procurement timing and prevents emergency repairs.',
          priority: 'high',
        ),
      );
      return;
    }

    if (previousCost > 0 && currentCost > previousCost * 1.3) {
      out.add(
        OperationsAssistRecommendation(
          area: 'maintenance',
          title: 'Maintenance cost is rising faster than normal',
          action:
              'Create preventive service tasks for high-use equipment and compare suppliers for frequently replaced parts.',
          expectedImpact:
              'Current month maintenance spend (${currentCost.toStringAsFixed(0)} TZS) is significantly above last month (${previousCost.toStringAsFixed(0)} TZS).',
          priority: 'critical',
        ),
      );
    }
  }

  static void _addPlantingRecommendations(
    List<OperationsAssistRecommendation> out,
    List<Map<String, dynamic>> tasks,
  ) {
    var duePlanting = 0;
    var overduePlanting = 0;

    for (final row in tasks) {
      final activity = (row['activity'] ?? '').toString().toLowerCase();
      if (!activity.contains('plant')) continue;

      final dueDate = DateTime.tryParse((row['due_date'] ?? '').toString());
      final status = (row['status'] ?? '').toString().toUpperCase();
      if (dueDate == null) continue;

      duePlanting++;
      final isComplete = status == 'COMPLETED' || status == 'REVIEW_PENDING';
      if (!isComplete && dueDate.isBefore(DateTime.now())) {
        overduePlanting++;
      }
    }

    if (duePlanting == 0) return;
    final overdueRatio = overduePlanting / duePlanting;
    if (overdueRatio >= 0.25) {
      out.add(
        OperationsAssistRecommendation(
          area: 'planting',
          title: 'Planting execution risk detected',
          action:
              'Advance seed/input procurement by 2 weeks and assign backup labor for planting windows with high delay probability.',
          expectedImpact:
              '${(overdueRatio * 100).toStringAsFixed(0)}% of planting tasks are overdue; reducing delays protects seasonal yield.',
          priority: 'high',
        ),
      );
    }
  }

  static void _addHiringRecommendations(
    List<OperationsAssistRecommendation> out,
    List<Map<String, dynamic>> tasks,
    int staffCount,
  ) {
    var openTasks = 0;
    for (final row in tasks) {
      final status = (row['status'] ?? '').toString().toUpperCase();
      if (status == 'PENDING' || status == 'IN_PROGRESS' || status == 'REVIEW_PENDING') {
        openTasks++;
      }
    }

    final effectiveStaff = staffCount > 0 ? staffCount : 1;
    final tasksPerStaff = openTasks / effectiveStaff;

    if (tasksPerStaff >= 7) {
      out.add(
        OperationsAssistRecommendation(
          area: 'hiring',
          title: 'Labor capacity likely below workload',
          action:
              'Use seasonal hiring or shift rebalancing for the next 2-4 weeks, prioritizing zones with the highest overdue work.',
          expectedImpact:
              'Open workload is ${tasksPerStaff.toStringAsFixed(1)} tasks per staff member, which risks quality and timeline slippage.',
          priority: 'high',
        ),
      );
    }
  }

  static void _addHealthRecommendations(
    List<OperationsAssistRecommendation> out,
    List<Map<String, dynamic>> logs,
    List<Map<String, dynamic>> ledgerEntries,
    List<Map<String, dynamic>> anomalies,
    DateTime current,
  ) {
    DateTime? lastHealthLog;
    final healthLedger = ledgerEntries.where((entry) {
      final category = (entry['category'] ?? '').toString().toLowerCase();
      return category == 'vet';
    }).toList();

    if (healthLedger.isNotEmpty) {
      for (final row in healthLedger) {
        final occurredAt = DateTime.tryParse((row['occurred_at'] ?? '').toString());
        if (occurredAt == null) continue;
        if (lastHealthLog == null || occurredAt.isAfter(lastHealthLog)) {
          lastHealthLog = occurredAt;
        }
      }
    } else {
      for (final row in logs) {
        final activity = (row['activity'] ?? '').toString().toLowerCase();
        final notes = (row['notes'] ?? '').toString().toLowerCase();
        final isHealth = activity.contains('health') || notes.contains('vaccine') || notes.contains('medication');
        if (!isHealth) continue;

        final completedAt = DateTime.tryParse((row['completed_at'] ?? '').toString());
        if (completedAt == null) continue;
        if (lastHealthLog == null || completedAt.isAfter(lastHealthLog)) {
          lastHealthLog = completedAt;
        }
      }
    }

    final unresolvedHealthAnomalies = anomalies.where((row) {
      final type = (row['type'] ?? '').toString().toUpperCase();
      final status = (row['status'] ?? '').toString().toUpperCase();
      return type.contains('HEALTH') && status != 'RESOLVED';
    }).length;

    final daysSinceHealth = lastHealthLog == null ? 999 : current.difference(lastHealthLog).inDays;
    if (daysSinceHealth > 30 || unresolvedHealthAnomalies > 0) {
      out.add(
        OperationsAssistRecommendation(
          area: 'medication_vaccine',
          title: 'Livestock health follow-up needed',
          action:
              'Schedule medication/vaccine review this week and require batch-level entries (drug, dose, animal group, date).',
          expectedImpact:
              'Last health activity was $daysSinceHealth days ago with $unresolvedHealthAnomalies unresolved health anomalies.',
          priority: daysSinceHealth > 45 ? 'critical' : 'high',
        ),
      );
    }
  }

  static void _addProcurementRecommendations(
    List<OperationsAssistRecommendation> out,
    List<Map<String, dynamic>> logs,
    List<Map<String, dynamic>> ledgerEntries,
  ) {
    var feedCost = 0.0;
    var fertilizerCost = 0.0;
    var maintenanceCost = 0.0;

    if (ledgerEntries.isNotEmpty) {
      for (final row in ledgerEntries) {
        final entryType = (row['entry_type'] ?? '').toString().toLowerCase();
        if (entryType != 'expense') continue;
        final category = (row['category'] ?? '').toString().toLowerCase();
        final cost = _toDouble(row['amount_tzs']);

        if (category == 'feed') feedCost += cost;
        if (category == 'fertilizer') fertilizerCost += cost;
        if (category == 'maintenance') maintenanceCost += cost;
      }
    } else {
      for (final row in logs) {
        final notes = (row['notes'] ?? '').toString();
        final category = _extractFinancialCategory(notes);
        final cost = _toDouble(row['cost']);

        if (category == 'feed') feedCost += cost;
        if (category == 'fertilizer') fertilizerCost += cost;
        if (category == 'maintenance') maintenanceCost += cost;
      }
    }

    final totalTracked = feedCost + fertilizerCost + maintenanceCost;
    if (totalTracked <= 0) {
      out.add(
        const OperationsAssistRecommendation(
          area: 'procurement',
          title: 'Procurement intelligence is under-captured',
          action:
              'Enforce financial category selection for each execution report and map supplier IDs in future ledger entries.',
          expectedImpact: 'Improves supplier benchmarking, reorder planning, and budget discipline.',
          priority: 'medium',
        ),
      );
      return;
    }

    if (maintenanceCost > totalTracked * 0.40) {
      out.add(
        const OperationsAssistRecommendation(
          area: 'procurement',
          title: 'High maintenance share in tracked spend',
          action:
              'Negotiate preventive-service bundles and hold critical spare parts inventory before peak season.',
          expectedImpact: 'Shifts spend from emergency repairs to planned maintenance and reduces downtime.',
          priority: 'high',
        ),
      );
    }
  }

  static void _addInventoryRecommendations(
    List<OperationsAssistRecommendation> out,
    List<Map<String, dynamic>> items,
    List<Map<String, dynamic>> transactions,
  ) {
    if (items.isEmpty) {
      out.add(
        const OperationsAssistRecommendation(
          area: 'inventory',
          title: 'Inventory register is missing',
          action:
              'Create inventory item records for feed, fertilizer, seeds, medicine, and spare parts with opening balances.',
          expectedImpact: 'Enables 3-week stock visibility for budgeting and replenishment planning.',
          priority: 'high',
        ),
      );
      return;
    }

    final usageByItem = <String, double>{};
    for (final tx in transactions) {
      final movementType = (tx['movement_type'] ?? '').toString().toLowerCase();
      final verificationStatus = (tx['verification_status'] ?? '').toString().toLowerCase();
      if (movementType != 'out' || verificationStatus == 'rejected') continue;
      final itemId = (tx['item_id'] ?? '').toString();
      if (itemId.isEmpty) continue;
      usageByItem[itemId] = (usageByItem[itemId] ?? 0) + _toDouble(tx['quantity']);
    }

    final atRisk = <String>[];
    var totalRestockCost = 0.0;

    for (final item in items) {
      final id = (item['id'] ?? '').toString();
      final name = (item['name'] ?? 'Item').toString();
      final qtyOnHand = _toDouble(item['quantity_on_hand']);
      final targetDays = (_toDouble(item['target_days_cover']) > 0
              ? _toDouble(item['target_days_cover'])
              : 21)
          .toInt();

      final fallbackDailyUsage = _toDouble(item['avg_daily_usage']);
      final observedDailyUsage = (usageByItem[id] ?? 0) / 42;
      final dailyUsage = observedDailyUsage > 0 ? observedDailyUsage : fallbackDailyUsage;

      if (dailyUsage <= 0) continue;
      final coverageDays = qtyOnHand / dailyUsage;
      if (coverageDays <= targetDays) {
        atRisk.add('$name (${coverageDays.toStringAsFixed(0)} days left)');
        final neededQty = (targetDays * dailyUsage) - qtyOnHand;
        if (neededQty > 0) {
          totalRestockCost += neededQty * _toDouble(item['unit_cost_tzs']);
        }
      }
    }

    if (atRisk.isNotEmpty) {
      out.add(
        OperationsAssistRecommendation(
          area: 'inventory',
          title: 'Inventory needs replenishment within 3 weeks',
          action:
              'Trigger purchase planning now for: ${atRisk.take(4).join(', ')}${atRisk.length > 4 ? '...' : ''}.',
          expectedImpact:
              'Avoids stock-outs during field operations. Estimated restock budget: ${totalRestockCost.toStringAsFixed(0)} TZS.',
          priority: atRisk.length >= 3 ? 'critical' : 'high',
        ),
      );
    }
  }

  static void _addExternalVerificationRecommendations(
    List<OperationsAssistRecommendation> out,
    List<Map<String, dynamic>> entries,
  ) {
    if (entries.isEmpty) {
      return;
    }

    var pendingVerification = 0;
    var pendingPayment = 0;
    var payableAmount = 0.0;

    for (final row in entries) {
      final verificationStatus = (row['verification_status'] ?? '').toString().toLowerCase();
      final paymentStatus = (row['payment_status'] ?? '').toString().toLowerCase();
      final amount = _toDouble(row['amount_tzs']);

      if (verificationStatus == 'pending_review') {
        pendingVerification++;
      }

      final approved = verificationStatus == 'approved';
      final unpaid = paymentStatus == 'pending' || paymentStatus == 'approved_for_payment';
      if (approved && unpaid) {
        pendingPayment++;
        payableAmount += amount;
      }
    }

    if (pendingVerification > 0) {
      out.add(
        OperationsAssistRecommendation(
          area: 'external_services',
          title: 'External records waiting for two-eyes verification',
          action:
              'Review and approve/reject $pendingVerification doctor/supplier entries before they are used for payments and analytics.',
          expectedImpact: 'Protects data integrity and prevents unverified costs entering financial planning.',
          priority: pendingVerification >= 5 ? 'critical' : 'high',
        ),
      );
    }

    if (pendingPayment > 0) {
      out.add(
        OperationsAssistRecommendation(
          area: 'external_services',
          title: 'Approved external payments are pending',
          action: 'Schedule payment run for $pendingPayment approved entries and reconcile with budget lines.',
          expectedImpact: 'Expected payout to external partners: ${payableAmount.toStringAsFixed(0)} TZS.',
          priority: 'medium',
        ),
      );
    }
  }

  static void _addRetrospectiveQualityRecommendations(
    List<OperationsAssistRecommendation> out,
    List<Map<String, dynamic>> logs,
    List<Map<String, dynamic>> tasks,
    List<Map<String, dynamic>> anomalies,
    DateTime current,
  ) {
    if (logs.isEmpty && tasks.isEmpty && anomalies.isEmpty) {
      return;
    }

    final domains = <String, _DomainQuality>{
      'livestock': const _DomainQuality.empty(),
      'plants': const _DomainQuality.empty(),
      'infrastructure': const _DomainQuality.empty(),
      'tools': const _DomainQuality.empty(),
      'operations': const _DomainQuality.empty(),
    };

    for (final row in logs) {
      final activity = (row['activity'] ?? '').toString();
      final notes = (row['notes'] ?? '').toString();
      final domain = _activityDomain(activity, notes);
      final currentDomain = domains[domain] ?? const _DomainQuality.empty();

      domains[domain] = currentDomain.copyWith(
        totalActions: currentDomain.totalActions + 1,
        evidenceActions: currentDomain.evidenceActions + (_hasEvidence(row['photo_urls']) ? 1 : 0),
        disciplinedActions: currentDomain.disciplinedActions + (_hasEffortTag(notes) && _extractFinancialCategory(notes) != null ? 1 : 0),
        healthTrackedActions: currentDomain.healthTrackedActions + (_isLikelyHealthActivity(activity, notes) ? 1 : 0),
      );
    }

    for (final row in tasks) {
      final activity = (row['activity'] ?? '').toString();
      final domain = _activityDomain(activity, '');
      final status = (row['status'] ?? '').toString().toUpperCase();
      final dueDate = DateTime.tryParse((row['due_date'] ?? '').toString());
      if (dueDate == null) continue;

      final isCompleted = status == 'COMPLETED' || status == 'REVIEW_PENDING';
      final isOverdue = !isCompleted && dueDate.isBefore(current);
      if (!isOverdue) continue;

      final currentDomain = domains[domain] ?? const _DomainQuality.empty();
      domains[domain] = currentDomain.copyWith(overdueActions: currentDomain.overdueActions + 1);
    }

    for (final row in anomalies) {
      final type = (row['type'] ?? '').toString().toLowerCase();
      final status = (row['status'] ?? '').toString().toUpperCase();
      if (status == 'RESOLVED') continue;

      final domain = _activityDomain(type, type);
      final currentDomain = domains[domain] ?? const _DomainQuality.empty();
      domains[domain] = currentDomain.copyWith(unresolvedAnomalies: currentDomain.unresolvedAnomalies + 1);
    }

    for (final entry in domains.entries) {
      final domain = entry.key;
      final score = entry.value;
      if (score.totalActions == 0 && score.unresolvedAnomalies == 0 && score.overdueActions == 0) {
        continue;
      }

      final evidenceRatio = score.totalActions == 0 ? 1.0 : score.evidenceActions / score.totalActions;
      final disciplineRatio = score.totalActions == 0 ? 1.0 : score.disciplinedActions / score.totalActions;

      if (score.overdueActions > 0 || score.unresolvedAnomalies > 0 || evidenceRatio < 0.55 || disciplineRatio < 0.55) {
        final priority = (score.unresolvedAnomalies >= 2 || score.overdueActions >= 3 || evidenceRatio < 0.4)
            ? 'critical'
            : 'high';
        out.add(
          OperationsAssistRecommendation(
            area: 'retrospective_quality',
            title: '${_domainLabel(domain)} quality gaps detected from past actions',
            action:
                'Correct recurring misses in ${_domainLabel(domain).toLowerCase()}: close overdue actions (${score.overdueActions}), resolve anomalies (${score.unresolvedAnomalies}), and enforce evidence + structured execution notes for every critical step.',
            expectedImpact:
                'Evidence coverage ${(evidenceRatio * 100).toStringAsFixed(0)}%, discipline coverage ${(disciplineRatio * 100).toStringAsFixed(0)}% in ${_domainLabel(domain).toLowerCase()} actions. This identifies mistakes early and reduces repeated losses.',
            priority: priority,
          ),
        );
      }

      if (score.totalActions >= 4 && evidenceRatio >= 0.8 && disciplineRatio >= 0.75 && score.overdueActions == 0 && score.unresolvedAnomalies == 0) {
        out.add(
          OperationsAssistRecommendation(
            area: 'best_practices',
            title: 'Replicate strong ${_domainLabel(domain).toLowerCase()} practices farm-wide',
            action:
                'Use this domain as a best-practice template: capture what worked, train other teams, and mirror the same checklist/evidence discipline in weaker domains (livestock, plants, infrastructure, tools).',
            expectedImpact:
                '${_domainLabel(domain)} shows high-quality execution consistency; scaling these agronomic and operational habits lifts whole-farm performance.',
            priority: 'medium',
          ),
        );
      }
    }
  }

  @visibleForTesting
  static List<OperationsAssistRecommendation> buildRetrospectiveRecommendationsForTest({
    required List<Map<String, dynamic>> logs,
    required List<Map<String, dynamic>> tasks,
    required List<Map<String, dynamic>> anomalies,
    required DateTime now,
  }) {
    final recommendations = <OperationsAssistRecommendation>[];
    _addRetrospectiveQualityRecommendations(recommendations, logs, tasks, anomalies, now);
    return recommendations;
  }

  static String _activityDomain(String activity, String notes) {
    final value = '${activity.toLowerCase()} ${notes.toLowerCase()}';
    if (value.contains('health') || value.contains('vaccine') || value.contains('medication') || value.contains('graz') || value.contains('calv') || value.contains('livestock')) {
      return 'livestock';
    }
    if (value.contains('plant') || value.contains('harvest') || value.contains('fertiliz') || value.contains('irrig') || value.contains('crop')) {
      return 'plants';
    }
    if (value.contains('fence') || value.contains('pump') || value.contains('storage') || value.contains('infrastructure')) {
      return 'infrastructure';
    }
    if (value.contains('tool') || value.contains('machine') || value.contains('tractor') || value.contains('repair') || value.contains('maintenance')) {
      return 'tools';
    }
    return 'operations';
  }

  static bool _hasEvidence(dynamic photoUrls) {
    if (photoUrls is Map) {
      return photoUrls.isNotEmpty;
    }
    if (photoUrls is List) {
      return photoUrls.isNotEmpty;
    }
    return false;
  }

  static bool _hasEffortTag(String notes) {
    return RegExp(r'Effort Hours:\s*[0-9]+(?:\.[0-9]+)?', caseSensitive: false).hasMatch(notes);
  }

  static bool _isLikelyHealthActivity(String activity, String notes) {
    final value = '${activity.toLowerCase()} ${notes.toLowerCase()}';
    return value.contains('health') || value.contains('vaccine') || value.contains('medication') || value.contains('vet');
  }

  static String _domainLabel(String domain) {
    switch (domain) {
      case 'livestock':
        return 'Livestock';
      case 'plants':
        return 'Plants';
      case 'infrastructure':
        return 'Infrastructure';
      case 'tools':
        return 'Tools';
      default:
        return 'Operations';
    }
  }

  static int _computeReadinessScore(List<OperationsAssistRecommendation> recommendations) {
    var score = 100;
    for (final rec in recommendations) {
      switch (rec.priority) {
        case 'critical':
          score -= 18;
          break;
        case 'high':
          score -= 10;
          break;
        case 'medium':
          score -= 5;
          break;
        default:
          score -= 2;
      }
    }
    return score.clamp(35, 100).toInt();
  }

  static int _priorityRank(String priority) {
    switch (priority) {
      case 'critical':
        return 0;
      case 'high':
        return 1;
      case 'medium':
        return 2;
      default:
        return 3;
    }
  }

  static String? _extractFinancialCategory(String notes) {
    final match = RegExp(r'Financial Category:\s*([a-zA-Z_]+)', caseSensitive: false).firstMatch(notes);
    if (match == null) return null;
    return (match.group(1) ?? '').trim().toLowerCase();
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }
}

class _DomainQuality {
  final int totalActions;
  final int evidenceActions;
  final int disciplinedActions;
  final int healthTrackedActions;
  final int overdueActions;
  final int unresolvedAnomalies;

  const _DomainQuality({
    required this.totalActions,
    required this.evidenceActions,
    required this.disciplinedActions,
    required this.healthTrackedActions,
    required this.overdueActions,
    required this.unresolvedAnomalies,
  });

  const _DomainQuality.empty()
      : totalActions = 0,
        evidenceActions = 0,
        disciplinedActions = 0,
        healthTrackedActions = 0,
        overdueActions = 0,
        unresolvedAnomalies = 0;

  _DomainQuality copyWith({
    int? totalActions,
    int? evidenceActions,
    int? disciplinedActions,
    int? healthTrackedActions,
    int? overdueActions,
    int? unresolvedAnomalies,
  }) {
    return _DomainQuality(
      totalActions: totalActions ?? this.totalActions,
      evidenceActions: evidenceActions ?? this.evidenceActions,
      disciplinedActions: disciplinedActions ?? this.disciplinedActions,
      healthTrackedActions: healthTrackedActions ?? this.healthTrackedActions,
      overdueActions: overdueActions ?? this.overdueActions,
      unresolvedAnomalies: unresolvedAnomalies ?? this.unresolvedAnomalies,
    );
  }
}
