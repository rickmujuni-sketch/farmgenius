import '../models/generated_farm_zones.dart';
import '../models/owner_finance.dart';
import 'supabase_service.dart';

class OwnerFinanceService {
  static const _laborHourlyRateTzs = 3500.0;

  static const Map<String, double> _unitPriceDefaults = {
    'kg': 2500,
    'litre': 1800,
    'bunch': 15000,
    'head': 350000,
    'bird': 22000,
    'egg': 700,
    'eggs': 700,
    'crate': 11000,
    'unit': 5000,
  };

  static Future<OwnerFinanceDashboardData> loadDashboard({DateTime? now}) async {
    final current = now ?? DateTime.now();
    final monthStart = DateTime(current.year, current.month, 1);
    final monthEnd = DateTime(current.year, current.month + 1, 1);
    final ytdStart = DateTime(current.year, 1, 1);

    final zoneNames = await _loadZoneNames();
    final monthlyLogs = await _loadActivityLogs(monthStart, monthEnd);
    final ytdLogs = await _loadActivityLogs(ytdStart, monthEnd);
    final budgetTasks = await _loadBudgetTasks(monthStart, monthEnd);
    final valuationRows = await _loadValuations();

    final monthRevenueBySource = _aggregateRevenueBySource(monthlyLogs);
    final monthRevenueByZone = _aggregateRevenueByZone(monthlyLogs, zoneNames);
    final monthExpenseByCategory = _aggregateExpensesByCategory(monthlyLogs);
    final monthExpenseByZone = _aggregateExpensesByZone(monthlyLogs, zoneNames);
    final monthExpenseByTaskType = _aggregateExpensesByTaskType(monthlyLogs);
    final budgetsByCategory = _aggregateBudgetByCategory(budgetTasks);

    final monthIncome = monthRevenueBySource.values.fold<double>(0, (a, b) => a + b);
    final monthExpenses = monthExpenseByCategory.values.fold<double>(0, (a, b) => a + b);
    final monthNet = monthIncome - monthExpenses;

    final ytdIncome = _aggregateRevenueBySource(ytdLogs).values.fold<double>(0, (a, b) => a + b);
    final ytdExpenses = _aggregateExpensesByCategory(ytdLogs).values.fold<double>(0, (a, b) => a + b);
    final ytdNet = ytdIncome - ytdExpenses;

    final monthBudget = budgetsByCategory.values.fold<double>(0, (a, b) => a + b);
    final budgetVariance = monthNet - (monthIncome - monthBudget);

    final expensesByCategory = monthExpenseByCategory.entries
        .map((entry) => ExpenseBudgetItem(
              key: entry.key,
              label: _categoryLabel(entry.key),
              actual: entry.value,
              budget: budgetsByCategory[entry.key] ?? 0,
            ))
        .toList()
      ..sort((a, b) => b.actual.compareTo(a.actual));

    final zoneProfitability = _buildZoneProfitability(
      monthRevenueByZone,
      monthExpenseByZone,
      zoneNames,
    );

    final biologicalAssets = _buildBiologicalValuationSummary(valuationRows);
    final insights = _buildInsights(
      current: current,
      monthlyLogs: monthlyLogs,
      monthIncome: monthIncome,
      monthExpenses: monthExpenses,
      monthNet: monthNet,
      historicalNetBaseline: await _historicalNetBaseline(current),
      categoryExpenses: monthExpenseByCategory,
      projectedRevenue: biologicalAssets.projectedRevenue,
    );

    return OwnerFinanceDashboardData(
      overview: FinancialOverview(
        monthIncome: monthIncome,
        monthExpenses: monthExpenses,
        monthNet: monthNet,
        ytdIncome: ytdIncome,
        ytdExpenses: ytdExpenses,
        ytdNet: ytdNet,
        monthBudget: monthBudget,
        budgetVariance: budgetVariance,
      ),
      revenueBySource: monthRevenueBySource.entries
          .map((entry) => FinanceBreakdownItem(
                key: entry.key,
                label: _sourceLabel(entry.key),
                amount: entry.value,
              ))
          .toList()
        ..sort((a, b) => b.amount.compareTo(a.amount)),
      revenueByZone: monthRevenueByZone.entries
          .map((entry) => FinanceBreakdownItem(
                key: entry.key,
                label: zoneNames[entry.key] ?? entry.key,
                amount: entry.value,
              ))
          .toList()
        ..sort((a, b) => b.amount.compareTo(a.amount)),
      expensesByCategory: expensesByCategory,
      expensesByZone: monthExpenseByZone.entries
          .map((entry) => FinanceBreakdownItem(
                key: entry.key,
                label: zoneNames[entry.key] ?? entry.key,
                amount: entry.value,
              ))
          .toList()
        ..sort((a, b) => b.amount.compareTo(a.amount)),
      expensesByTaskType: monthExpenseByTaskType.entries
          .map((entry) => FinanceBreakdownItem(
                key: entry.key,
                label: _activityLabel(entry.key),
                amount: entry.value,
              ))
          .toList()
        ..sort((a, b) => b.amount.compareTo(a.amount)),
      zoneProfitability: zoneProfitability,
      biologicalAssets: biologicalAssets,
      insights: insights,
    );
  }

  static Future<ZoneCashCowRanking> loadZoneCashCowRanking({DateTime? now}) async {
    final current = now ?? DateTime.now();
    final dayStart = DateTime(current.year, current.month, current.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final weekStart = dayStart.subtract(Duration(days: dayStart.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 7));
    final monthStart = DateTime(current.year, current.month, 1);
    final monthEnd = DateTime(current.year, current.month + 1, 1);

    final zoneNames = await _loadZoneNames();

    final dailyRows = await _loadActivityLogs(dayStart, dayEnd);
    final weeklyRows = await _loadActivityLogs(weekStart, weekEnd);
    final monthlyRows = await _loadActivityLogs(monthStart, monthEnd);

    ZoneCashCowWindow buildWindow({
      required String key,
      required String label,
      required List<Map<String, dynamic>> rows,
    }) {
      final revenueByZone = _aggregateRevenueByZone(rows, zoneNames);
      final expenseByZone = _aggregateExpensesByZone(rows, zoneNames);
      final ranked = _buildZoneProfitability(revenueByZone, expenseByZone, zoneNames);
      return ZoneCashCowWindow(
        key: key,
        label: label,
        rankedZones: ranked,
      );
    }

    return ZoneCashCowRanking(
      daily: buildWindow(key: 'daily', label: 'Daily', rows: dailyRows),
      weekly: buildWindow(key: 'weekly', label: 'Weekly', rows: weeklyRows),
      monthly: buildWindow(key: 'monthly', label: 'Monthly', rows: monthlyRows),
    );
  }

  static Future<Map<String, String>> _loadZoneNames() async {
    final names = <String, String>{
      for (final zone in GeneratedFarmZones.allZones) zone.id: zone.name,
    };

    try {
      final zones = await SupabaseService.client
          .from('asset_zones')
          .select('id,name')
          .order('name', ascending: true);
      if (zones is List) {
        for (final row in zones) {
          if (row is! Map<String, dynamic>) continue;
          final id = (row['id'] ?? '').toString();
          final name = (row['name'] ?? '').toString();
          if (id.isNotEmpty && name.isNotEmpty) {
            names[id] = name;
          }
        }
      }
    } catch (_) {}

    return names;
  }

  static Future<List<Map<String, dynamic>>> _loadActivityLogs(DateTime start, DateTime end) async {
    try {
      final rows = await SupabaseService.client
          .from('activity_logs')
          .select('zone_id,activity,logged_at,completed_at,notes,quantity,quantity_unit,cost,task_id')
          .gte('completed_at', start.toIso8601String())
          .lt('completed_at', end.toIso8601String())
          .order('completed_at', ascending: true);
      if (rows is List) {
        return rows.whereType<Map<String, dynamic>>().toList();
      }
    } catch (_) {}
    return const [];
  }

  static Future<List<Map<String, dynamic>>> _loadBudgetTasks(DateTime start, DateTime end) async {
    try {
      final rows = await SupabaseService.client
          .from('tasks')
          .select('activity,zone_id,due_date,metadata')
          .gte('due_date', start.toIso8601String())
          .lt('due_date', end.toIso8601String())
          .order('due_date', ascending: true);
      if (rows is List) {
        return rows.whereType<Map<String, dynamic>>().toList();
      }
    } catch (_) {}
    return const [];
  }

  static Future<List<Map<String, dynamic>>> _loadValuations() async {
    try {
      final rows = await SupabaseService.client
          .from('biological_asset_latest_values')
          .select('asset_type,zone_id,scenario_low,scenario_medium,scenario_high');
      if (rows is List) {
        return rows.whereType<Map<String, dynamic>>().toList();
      }
    } catch (_) {}
    return const [];
  }

  static Map<String, double> _aggregateRevenueBySource(List<Map<String, dynamic>> rows) {
    final sourceMap = <String, double>{};
    for (final row in rows) {
      final source = _classifyRevenueSource(row);
      if (source == null) continue;
      final revenue = _resolveRevenueTzs(row);
      if (revenue <= 0) continue;
      sourceMap[source] = (sourceMap[source] ?? 0) + revenue;
    }
    return sourceMap;
  }

  static Map<String, double> _aggregateRevenueByZone(
    List<Map<String, dynamic>> rows,
    Map<String, String> zoneNames,
  ) {
    final zoneMap = <String, double>{};
    for (final row in rows) {
      if (_classifyRevenueSource(row) == null) continue;
      final zoneId = (row['zone_id'] ?? '').toString();
      if (zoneId.isEmpty) continue;
      final revenue = _resolveRevenueTzs(row);
      if (revenue <= 0) continue;
      zoneMap[zoneId] = (zoneMap[zoneId] ?? 0) + revenue;
    }

    for (final zoneId in zoneNames.keys) {
      zoneMap.putIfAbsent(zoneId, () => 0);
    }

    return zoneMap;
  }

  static Map<String, double> _aggregateExpensesByCategory(List<Map<String, dynamic>> rows) {
    final categoryMap = <String, double>{};
    for (final row in rows) {
      final category = _classifyExpenseCategory(row);
      final value = _resolveExpenseTzs(row);
      if (value <= 0) continue;
      categoryMap[category] = (categoryMap[category] ?? 0) + value;
    }
    return categoryMap;
  }

  static Map<String, double> _aggregateExpensesByZone(
    List<Map<String, dynamic>> rows,
    Map<String, String> zoneNames,
  ) {
    final zoneMap = <String, double>{};
    for (final row in rows) {
      final zoneId = (row['zone_id'] ?? '').toString();
      if (zoneId.isEmpty) continue;
      final value = _resolveExpenseTzs(row);
      if (value <= 0) continue;
      zoneMap[zoneId] = (zoneMap[zoneId] ?? 0) + value;
    }

    for (final zoneId in zoneNames.keys) {
      zoneMap.putIfAbsent(zoneId, () => 0);
    }

    return zoneMap;
  }

  static Map<String, double> _aggregateExpensesByTaskType(List<Map<String, dynamic>> rows) {
    final taskTypeMap = <String, double>{};
    for (final row in rows) {
      final activity = (row['activity'] ?? 'UNKNOWN').toString().toUpperCase();
      final value = _resolveExpenseTzs(row);
      if (value <= 0) continue;
      taskTypeMap[activity] = (taskTypeMap[activity] ?? 0) + value;
    }
    return taskTypeMap;
  }

  static Map<String, double> _aggregateBudgetByCategory(List<Map<String, dynamic>> tasks) {
    final budgetMap = <String, double>{};
    for (final task in tasks) {
      final metadata = task['metadata'];
      if (metadata is! Map) continue;

      final budget = _firstPositive([
        metadata['budget_tzs'],
        metadata['planned_cost_tzs'],
        metadata['expected_cost_tzs'],
        metadata['estimated_cost_tzs'],
      ]);
      if (budget <= 0) continue;

      final category = _classifyExpenseCategory({
        'activity': task['activity'],
        'notes': metadata['notes'],
      });
      budgetMap[category] = (budgetMap[category] ?? 0) + budget;
    }
    return budgetMap;
  }

  static List<ZoneFinancialSnapshot> _buildZoneProfitability(
    Map<String, double> revenueByZone,
    Map<String, double> expensesByZone,
    Map<String, String> zoneNames,
  ) {
    final zoneIds = {...zoneNames.keys, ...revenueByZone.keys, ...expensesByZone.keys};
    final snapshots = <ZoneFinancialSnapshot>[];

    for (final zoneId in zoneIds) {
      final revenue = revenueByZone[zoneId] ?? 0;
      final expenses = expensesByZone[zoneId] ?? 0;
      snapshots.add(
        ZoneFinancialSnapshot(
          zoneId: zoneId,
          zoneName: zoneNames[zoneId] ?? zoneId,
          revenue: revenue,
          expenses: expenses,
          net: revenue - expenses,
        ),
      );
    }

    snapshots.sort((a, b) => b.net.compareTo(a.net));
    return snapshots;
  }

  static BiologicalAssetValuationSummary _buildBiologicalValuationSummary(
    List<Map<String, dynamic>> rows,
  ) {
    var livestock = 0.0;
    var crops = 0.0;
    var infrastructure = 0.0;
    var insurance = 0.0;

    for (final row in rows) {
      final assetType = (row['asset_type'] ?? '').toString().toLowerCase();
      final medium = _toDouble(row['scenario_medium']);
      final high = _toDouble(row['scenario_high']);
      insurance += high > 0 ? high : medium;

      if (assetType.contains('livestock')) {
        livestock += medium;
      } else if (assetType.contains('crop') || assetType.contains('banana')) {
        crops += medium;
      } else {
        infrastructure += medium;
      }
    }

    final total = livestock + crops + infrastructure;

    return BiologicalAssetValuationSummary(
      livestockValue: livestock,
      cropValue: crops,
      infrastructureValue: infrastructure,
      totalValue: total,
      insuranceValue: insurance,
      projectedRevenue: total,
    );
  }

  static List<FinancialInsight> _buildInsights({
    required DateTime current,
    required List<Map<String, dynamic>> monthlyLogs,
    required double monthIncome,
    required double monthExpenses,
    required double monthNet,
    required double historicalNetBaseline,
    required Map<String, double> categoryExpenses,
    required double projectedRevenue,
  }) {
    final insights = <FinancialInsight>[];

    final forecastQuarterNet = monthNet * 3;
    insights.add(
      FinancialInsight(
        title: 'Next Quarter Forecast',
        description:
            'Projected net for next quarter is ${forecastQuarterNet.toStringAsFixed(0)} TZS if current trend holds.',
        severity: 'info',
      ),
    );

    if (historicalNetBaseline != 0) {
      final deltaPct = ((monthNet - historicalNetBaseline) / historicalNetBaseline.abs()) * 100;
      final better = deltaPct >= 0;
      insights.add(
        FinancialInsight(
          title: 'Historical Benchmark',
          description:
              'Current month net is ${deltaPct.abs().toStringAsFixed(1)}% ${better ? 'above' : 'below'} your recent historical average.',
          severity: better ? 'positive' : 'warning',
        ),
      );
    }

    final avgCategory = categoryExpenses.isEmpty
        ? 0.0
        : categoryExpenses.values.fold<double>(0, (a, b) => a + b) / categoryExpenses.length;
    for (final entry in categoryExpenses.entries) {
      if (avgCategory > 0 && entry.value > avgCategory * 1.8) {
        insights.add(
          FinancialInsight(
            title: 'Expense Anomaly: ${_categoryLabel(entry.key)}',
            description:
                '${entry.value.toStringAsFixed(0)} TZS spent, significantly above normal category spend this month.',
            severity: 'critical',
          ),
        );
      }
    }

    final whatIfGain = projectedRevenue * 0.10;
    insights.add(
      FinancialInsight(
        title: 'What-if: Maize +10%',
        description:
            'If maize-equivalent prices rise 10%, projected revenue could increase by ~${whatIfGain.toStringAsFixed(0)} TZS.',
        severity: 'info',
      ),
    );

    if (monthIncome <= 0 && monthExpenses > 0) {
      insights.add(
        const FinancialInsight(
          title: 'Revenue Gap Alert',
          description:
              'Expenses are being logged but no monetized production logs were detected. Capture sales output in execution notes for accurate P&L.',
          severity: 'warning',
        ),
      );
    }

    if (insights.isEmpty) {
      insights.add(
        const FinancialInsight(
          title: 'No Critical Financial Risks',
          description: 'Your current month financial signals look stable.',
          severity: 'positive',
        ),
      );
    }

    return insights.take(8).toList();
  }

  static Future<double> _historicalNetBaseline(DateTime current) async {
    final from = DateTime(current.year, current.month - 3, 1);
    final to = DateTime(current.year, current.month, 1);
    final rows = await _loadActivityLogs(from, to);
    if (rows.isEmpty) return 0;

    final byMonth = <String, double>{};
    for (final row in rows) {
      final completedAt = DateTime.tryParse((row['completed_at'] ?? '').toString());
      if (completedAt == null) continue;
      final key = '${completedAt.year}-${completedAt.month.toString().padLeft(2, '0')}';
      final revenue = _resolveRevenueTzs(row);
      final expense = _resolveExpenseTzs(row);
      byMonth[key] = (byMonth[key] ?? 0) + (revenue - expense);
    }

    if (byMonth.isEmpty) return 0;
    return byMonth.values.fold<double>(0, (a, b) => a + b) / byMonth.length;
  }

  static String? _classifyRevenueSource(Map<String, dynamic> row) {
    final financialCategory = _extractFinancialCategory((row['notes'] ?? '').toString());
    if (financialCategory == 'crop_sales' ||
        financialCategory == 'livestock_sales' ||
        financialCategory == 'other_income') {
      return financialCategory;
    }

    final activity = (row['activity'] ?? '').toString().toLowerCase();
    final notes = (row['notes'] ?? '').toString().toLowerCase();

    if (activity.contains('harvest') || notes.contains('harvest')) {
      return 'crop_sales';
    }
    if (notes.contains('milk') || notes.contains('dairy')) {
      return 'other_income';
    }
    if (activity.contains('egg') || notes.contains('egg')) {
      return 'other_income';
    }
    if (notes.contains('livestock sale') || notes.contains('sold') || notes.contains('cattle sale')) {
      return 'livestock_sales';
    }
    return null;
  }

  static String _classifyExpenseCategory(Map<String, dynamic> row) {
    final financialCategory = _extractFinancialCategory((row['notes'] ?? '').toString());
    switch (financialCategory) {
      case 'feed':
        return 'feed';
      case 'vet':
        return 'vet';
      case 'labor':
        return 'labor';
      case 'fertilizer':
        return 'fertilizer';
      case 'fuel':
        return 'fuel';
      case 'maintenance':
        return 'maintenance';
    }

    final activity = (row['activity'] ?? '').toString().toLowerCase();
    final notes = (row['notes'] ?? '').toString().toLowerCase();

    if (activity.contains('feeding') || notes.contains('feed')) return 'feed';
    if (activity.contains('health') || notes.contains('vet') || notes.contains('vaccine')) return 'vet';
    if (notes.contains('fertilizer') || notes.contains('manure') || notes.contains('pesticide')) return 'fertilizer';
    if (notes.contains('fuel') || notes.contains('diesel') || notes.contains('petrol')) return 'fuel';
    if (activity.contains('repair') || activity.contains('maintenance') || notes.contains('maintenance')) {
      return 'maintenance';
    }
    return 'labor';
  }

  static double _resolveRevenueTzs(Map<String, dynamic> row) {
    final notes = (row['notes'] ?? '').toString();
    final explicit = _extractAmount(notes, ['Revenue (TZS)', 'Revenue', 'Income', 'Sale Value']);
    if (explicit > 0) return explicit;

    final qty = _toDouble(row['quantity']);
    if (qty <= 0) return 0;

    final activity = (row['activity'] ?? '').toString().toLowerCase();
    final unit = (row['quantity_unit'] ?? '').toString().toLowerCase().trim();

    double price = _unitPriceDefaults[unit] ?? 0;
    if (price <= 0) {
      if (activity.contains('harvest')) price = 15000;
      if (activity.contains('egg')) price = 700;
      if (activity.contains('milk')) price = 1800;
      if (activity.contains('grazing') || activity.contains('calving')) price = 350000;
    }

    return qty * price;
  }

  static double _resolveExpenseTzs(Map<String, dynamic> row) {
    final directCost = _toDouble(row['cost']);
    if (directCost > 0) return directCost;

    final notes = (row['notes'] ?? '').toString();
    final explicit = _extractAmount(notes, ['Total Cost (TZS)', 'Cost', 'Expense']);
    if (explicit > 0) return explicit;

    final hours = _extractEffortHours(notes);
    if (hours > 0) {
      return hours * _laborHourlyRateTzs;
    }

    return 0;
  }

  static double _extractAmount(String text, List<String> labels) {
    for (final label in labels) {
      final escapedLabel = RegExp.escape(label);
      final regex = RegExp('$escapedLabel[^0-9\\-]*([0-9]+(?:\\.[0-9]+)?)', caseSensitive: false);
      final match = regex.firstMatch(text);
      if (match != null) {
        final value = double.tryParse(match.group(1) ?? '');
        if (value != null && value > 0) {
          return value;
        }
      }
    }
    return 0;
  }

  static String? _extractFinancialCategory(String notes) {
    final match = RegExp(r'Financial Category:\s*([a-zA-Z_]+)', caseSensitive: false).firstMatch(notes);
    if (match == null) return null;
    return (match.group(1) ?? '').trim().toLowerCase();
  }

  static double _extractEffortHours(String notes) {
    final match = RegExp(r'Effort Hours:\s*([0-9]+(?:\.[0-9]+)?)', caseSensitive: false)
        .firstMatch(notes);
    if (match == null) return 0;
    return double.tryParse(match.group(1) ?? '') ?? 0;
  }

  static double _firstPositive(List<dynamic> values) {
    for (final value in values) {
      final parsed = _toDouble(value);
      if (parsed > 0) return parsed;
    }
    return 0;
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  static String _sourceLabel(String key) {
    switch (key) {
      case 'crop_sales':
        return 'Crop sales';
      case 'livestock_sales':
        return 'Livestock sales';
      case 'other_income':
        return 'Other income';
      default:
        return key;
    }
  }

  static String _categoryLabel(String key) {
    switch (key) {
      case 'feed':
        return 'Feed';
      case 'vet':
        return 'Vet';
      case 'labor':
        return 'Labor';
      case 'fertilizer':
        return 'Fertilizer';
      case 'fuel':
        return 'Fuel';
      case 'maintenance':
        return 'Maintenance';
      default:
        return key;
    }
  }

  static String _activityLabel(String activity) {
    return activity
        .split('_')
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1).toLowerCase())
        .join(' ');
  }
}
