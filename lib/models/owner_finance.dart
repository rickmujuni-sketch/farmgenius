class FinancialOverview {
  final double monthIncome;
  final double monthExpenses;
  final double monthNet;
  final double ytdIncome;
  final double ytdExpenses;
  final double ytdNet;
  final double monthBudget;
  final double budgetVariance;

  const FinancialOverview({
    required this.monthIncome,
    required this.monthExpenses,
    required this.monthNet,
    required this.ytdIncome,
    required this.ytdExpenses,
    required this.ytdNet,
    required this.monthBudget,
    required this.budgetVariance,
  });
}

class FinanceBreakdownItem {
  final String key;
  final String label;
  final double amount;

  const FinanceBreakdownItem({
    required this.key,
    required this.label,
    required this.amount,
  });
}

class ExpenseBudgetItem {
  final String key;
  final String label;
  final double actual;
  final double budget;

  const ExpenseBudgetItem({
    required this.key,
    required this.label,
    required this.actual,
    required this.budget,
  });

  double get variance => actual - budget;
  bool get isOverrun => budget > 0 && actual > budget;
}

class ZoneFinancialSnapshot {
  final String zoneId;
  final String zoneName;
  final double revenue;
  final double expenses;
  final double net;

  const ZoneFinancialSnapshot({
    required this.zoneId,
    required this.zoneName,
    required this.revenue,
    required this.expenses,
    required this.net,
  });

  double get roiPercent {
    if (expenses <= 0) return net > 0 ? 100 : 0;
    return (net / expenses) * 100;
  }

  bool get profitable => net >= 0;
}

class BiologicalAssetValuationSummary {
  final double livestockValue;
  final double cropValue;
  final double infrastructureValue;
  final double totalValue;
  final double insuranceValue;
  final double projectedRevenue;

  const BiologicalAssetValuationSummary({
    required this.livestockValue,
    required this.cropValue,
    required this.infrastructureValue,
    required this.totalValue,
    required this.insuranceValue,
    required this.projectedRevenue,
  });
}

class FinancialInsight {
  final String title;
  final String description;
  final String severity;

  const FinancialInsight({
    required this.title,
    required this.description,
    required this.severity,
  });
}

class OwnerFinanceDashboardData {
  final FinancialOverview overview;
  final List<FinanceBreakdownItem> revenueBySource;
  final List<FinanceBreakdownItem> revenueByZone;
  final List<ExpenseBudgetItem> expensesByCategory;
  final List<FinanceBreakdownItem> expensesByZone;
  final List<FinanceBreakdownItem> expensesByTaskType;
  final List<ZoneFinancialSnapshot> zoneProfitability;
  final BiologicalAssetValuationSummary biologicalAssets;
  final List<FinancialInsight> insights;

  const OwnerFinanceDashboardData({
    required this.overview,
    required this.revenueBySource,
    required this.revenueByZone,
    required this.expensesByCategory,
    required this.expensesByZone,
    required this.expensesByTaskType,
    required this.zoneProfitability,
    required this.biologicalAssets,
    required this.insights,
  });
}

class ZoneCashCowWindow {
  final String key;
  final String label;
  final List<ZoneFinancialSnapshot> rankedZones;

  const ZoneCashCowWindow({
    required this.key,
    required this.label,
    required this.rankedZones,
  });

  ZoneFinancialSnapshot? get topZone => rankedZones.isEmpty ? null : rankedZones.first;
}

class ZoneCashCowRanking {
  final ZoneCashCowWindow daily;
  final ZoneCashCowWindow weekly;
  final ZoneCashCowWindow monthly;

  const ZoneCashCowRanking({
    required this.daily,
    required this.weekly,
    required this.monthly,
  });
}
