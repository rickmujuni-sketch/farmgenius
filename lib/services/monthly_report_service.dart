import 'package:intl/intl.dart';

import '../models/biological_asset.dart';
import '../models/monthly_report.dart';
import '../models/operations_assist.dart';
import '../models/owner_finance.dart';

class MonthlyReportService {
  static PeriodReportDocument buildMonthly({
    required OwnerFinanceDashboardData finance,
    required OperationsAssistSnapshot assist,
    required DateTime reportMonth,
    List<DailyAssetCheck> dailyChecks = const [],
  }) {
    final monthLabel = DateFormat('MMMM yyyy').format(reportMonth);
    return _build(
      periodType: 'monthly',
      periodLabel: monthLabel,
      titlePrefix: 'FarmGenius Monthly Report',
      finance: finance,
      assist: assist,
      dailyChecks: dailyChecks,
      scale: 1,
    );
  }

  static PeriodReportDocument buildWeekly({
    required OwnerFinanceDashboardData finance,
    required OperationsAssistSnapshot assist,
    required DateTime reportDate,
    List<DailyAssetCheck> dailyChecks = const [],
  }) {
    final start = reportDate.subtract(Duration(days: reportDate.weekday - 1));
    final end = start.add(const Duration(days: 6));
    final label = '${DateFormat('dd MMM').format(start)} - ${DateFormat('dd MMM yyyy').format(end)}';
    return _build(
      periodType: 'weekly',
      periodLabel: label,
      titlePrefix: 'FarmGenius Weekly Report',
      finance: finance,
      assist: assist,
      dailyChecks: dailyChecks,
      scale: 0.25,
    );
  }

  static PeriodReportDocument buildDaily({
    required OwnerFinanceDashboardData finance,
    required OperationsAssistSnapshot assist,
    required DateTime reportDate,
    List<DailyAssetCheck> dailyChecks = const [],
  }) {
    final label = DateFormat('dd MMM yyyy').format(reportDate);
    return _build(
      periodType: 'daily',
      periodLabel: label,
      titlePrefix: 'FarmGenius Daily Report',
      finance: finance,
      assist: assist,
      dailyChecks: dailyChecks,
      scale: 1 / 30,
    );
  }

  static PeriodReportDocument build({
    required OwnerFinanceDashboardData finance,
    required OperationsAssistSnapshot assist,
    required DateTime reportMonth,
    List<DailyAssetCheck> dailyChecks = const [],
  }) {
    return buildMonthly(finance: finance, assist: assist, reportMonth: reportMonth, dailyChecks: dailyChecks);
  }

  static PeriodReportDocument _build({
    required String periodType,
    required String periodLabel,
    required String titlePrefix,
    required OwnerFinanceDashboardData finance,
    required OperationsAssistSnapshot assist,
    required List<DailyAssetCheck> dailyChecks,
    required double scale,
  }) {
    final scaledIncome = finance.overview.monthIncome * scale;
    final scaledExpenses = finance.overview.monthExpenses * scale;
    final scaledNet = scaledIncome - scaledExpenses;
    final scaledBudget = finance.overview.monthBudget * scale;
    final scaledVariance = scaledNet - (scaledIncome - scaledBudget);

    final evidenceSummary = _summarizeDailyChecks(dailyChecks);

    final kpis = <MonthlyReportKpi>[
      MonthlyReportKpi(label: 'Income', value: _tzs(scaledIncome)),
      MonthlyReportKpi(label: 'Expenses', value: _tzs(scaledExpenses)),
      MonthlyReportKpi(label: 'Net', value: _tzs(scaledNet)),
      MonthlyReportKpi(label: 'Budget', value: _tzs(scaledBudget)),
      MonthlyReportKpi(label: 'Variance', value: _tzs(scaledVariance)),
      MonthlyReportKpi(label: 'Readiness', value: '${assist.readinessScore}/100'),
      MonthlyReportKpi(label: 'Daily Checks', value: '${evidenceSummary.totalChecks}'),
      MonthlyReportKpi(label: 'Evidence Items', value: '${evidenceSummary.totalEvidence}'),
    ];

    final topExpenseCategory = finance.expensesByCategory.isEmpty
        ? null
        : (finance.expensesByCategory.toList()
          ..sort((a, b) => b.actual.compareTo(a.actual))).first;
    final topRevenueZone = finance.revenueByZone.isEmpty
        ? null
        : (finance.revenueByZone.toList()
          ..sort((a, b) => b.amount.compareTo(a.amount))).first;
    final topRiskAction = assist.recommendations.isEmpty
        ? null
        : assist.recommendations.first;

    final highlights = <MonthlyReportHighlight>[
      MonthlyReportHighlight(
        title: 'Profitability',
        detail: scaledNet >= 0
            ? 'Month closed with positive net performance.'
            : 'Month closed with a net loss requiring cost controls.',
      ),
      if (topExpenseCategory != null)
        MonthlyReportHighlight(
          title: 'Largest Cost Driver',
          detail: '${topExpenseCategory.label}: ${_tzs(topExpenseCategory.actual)}',
        ),
      if (topRevenueZone != null)
        MonthlyReportHighlight(
          title: 'Top Revenue Zone',
          detail: '${topRevenueZone.label}: ${_tzs(topRevenueZone.amount)}',
        ),
      if (topRiskAction != null)
        MonthlyReportHighlight(
          title: 'Priority Operations Action',
          detail: '${topRiskAction.title} (${topRiskAction.priority.toUpperCase()})',
        ),
      if (evidenceSummary.totalChecks > 0)
        MonthlyReportHighlight(
          title: 'Daily Check Evidence',
          detail:
              '${evidenceSummary.checksWithEvidence}/${evidenceSummary.totalChecks} checks include evidence • receipts ${evidenceSummary.receipts}, animals ${evidenceSummary.animals}, plants ${evidenceSummary.plants}, infrastructure ${evidenceSummary.infrastructure}, other ${evidenceSummary.other}',
        ),
    ];

    final whatsappMessage = _buildWhatsAppMessage(
      titlePrefix: titlePrefix,
      periodLabel: periodLabel,
      finance: finance,
      assist: assist,
      topExpenseCategory: topExpenseCategory,
      topRevenueZone: topRevenueZone,
      evidenceSummary: evidenceSummary,
      scale: scale,
    );

    final csvContent = _buildCsv(
      periodType: periodType,
      periodLabel: periodLabel,
      finance: finance,
      assist: assist,
      topExpenseCategory: topExpenseCategory,
      topRevenueZone: topRevenueZone,
      evidenceSummary: evidenceSummary,
      scale: scale,
    );

    return PeriodReportDocument(
      periodType: periodType,
      periodLabel: periodLabel,
      generatedAt: DateTime.now(),
      kpis: kpis,
      highlights: highlights,
      whatsappMessage: whatsappMessage,
      csvContent: csvContent,
    );
  }

  static String _buildWhatsAppMessage({
    required String titlePrefix,
    required String periodLabel,
    required OwnerFinanceDashboardData finance,
    required OperationsAssistSnapshot assist,
    required _CheckEvidenceSummary evidenceSummary,
    required double scale,
    ExpenseBudgetItem? topExpenseCategory,
    FinanceBreakdownItem? topRevenueZone,
  }) {
    final scaledIncome = finance.overview.monthIncome * scale;
    final scaledExpenses = finance.overview.monthExpenses * scale;
    final scaledNet = scaledIncome - scaledExpenses;
    final scaledBudget = finance.overview.monthBudget * scale;
    final scaledVariance = scaledNet - (scaledIncome - scaledBudget);

    final buffer = StringBuffer();
    buffer.writeln('$titlePrefix - $periodLabel');
    buffer.writeln('');
    buffer.writeln('Income: ${_tzs(scaledIncome)}');
    buffer.writeln('Expenses: ${_tzs(scaledExpenses)}');
    buffer.writeln('Net: ${_tzs(scaledNet)}');
    buffer.writeln('Budget: ${_tzs(scaledBudget)}');
    buffer.writeln('Variance: ${_tzs(scaledVariance)}');
    buffer.writeln('Readiness Score: ${assist.readinessScore}/100');

    if (topRevenueZone != null) {
      buffer.writeln('Top Revenue Zone: ${topRevenueZone.label} (${_tzs(topRevenueZone.amount)})');
    }

    if (topExpenseCategory != null) {
      buffer.writeln('Top Expense Category: ${topExpenseCategory.label} (${_tzs(topExpenseCategory.actual)})');
    }

    if (assist.recommendations.isNotEmpty) {
      final first = assist.recommendations.first;
      buffer.writeln('Priority Action: ${first.title}');
    }

    if (evidenceSummary.totalChecks > 0) {
      buffer.writeln('Daily Checks: ${evidenceSummary.totalChecks}');
      buffer.writeln('Evidence Items: ${evidenceSummary.totalEvidence}');
      buffer.writeln(
        'Evidence Mix: receipts ${evidenceSummary.receipts}, animals ${evidenceSummary.animals}, plants ${evidenceSummary.plants}, infrastructure ${evidenceSummary.infrastructure}, other ${evidenceSummary.other}',
      );
    }

    return buffer.toString().trim();
  }

  static String _buildCsv({
    required String periodType,
    required String periodLabel,
    required OwnerFinanceDashboardData finance,
    required OperationsAssistSnapshot assist,
    required _CheckEvidenceSummary evidenceSummary,
    required double scale,
    ExpenseBudgetItem? topExpenseCategory,
    FinanceBreakdownItem? topRevenueZone,
  }) {
    final scaledIncome = finance.overview.monthIncome * scale;
    final scaledExpenses = finance.overview.monthExpenses * scale;
    final scaledNet = scaledIncome - scaledExpenses;
    final scaledBudget = finance.overview.monthBudget * scale;
    final scaledVariance = scaledNet - (scaledIncome - scaledBudget);

    final rows = <String>[
      'period_type,period_label,income_tzs,expenses_tzs,net_tzs,budget_tzs,variance_tzs,readiness_score,top_revenue_zone,top_revenue_zone_amount_tzs,top_expense_category,top_expense_category_amount_tzs,daily_checks,evidence_items,checks_with_evidence,evidence_receipts,evidence_animals,evidence_plants,evidence_infrastructure,evidence_other',
      '${_csv(periodType)},${_csv(periodLabel)},${scaledIncome.toStringAsFixed(2)},${scaledExpenses.toStringAsFixed(2)},${scaledNet.toStringAsFixed(2)},${scaledBudget.toStringAsFixed(2)},${scaledVariance.toStringAsFixed(2)},${assist.readinessScore},${_csv(topRevenueZone?.label ?? '')},${((topRevenueZone?.amount ?? 0) * scale).toStringAsFixed(2)},${_csv(topExpenseCategory?.label ?? '')},${((topExpenseCategory?.actual ?? 0) * scale).toStringAsFixed(2)},${evidenceSummary.totalChecks},${evidenceSummary.totalEvidence},${evidenceSummary.checksWithEvidence},${evidenceSummary.receipts},${evidenceSummary.animals},${evidenceSummary.plants},${evidenceSummary.infrastructure},${evidenceSummary.other}',
    ];
    return rows.join('\n');
  }

  static _CheckEvidenceSummary _summarizeDailyChecks(List<DailyAssetCheck> checks) {
    var checksWithEvidence = 0;
    var receipts = 0;
    var animals = 0;
    var plants = 0;
    var infrastructure = 0;
    var other = 0;

    for (final check in checks) {
      final observations = check.observations;
      final evidence = (observations['evidence'] as Map<String, dynamic>?) ?? const <String, dynamic>{};

      final receiptList = (evidence['receipts'] as List?) ?? const [];
      final animalList = (evidence['animals'] as List?) ?? const [];
      final plantList = (evidence['plants'] as List?) ?? const [];
      final infrastructureList = (evidence['infrastructure'] as List?) ?? const [];
      final otherList = (evidence['other'] as List?) ?? const [];

      final hasEvidence =
          receiptList.isNotEmpty || animalList.isNotEmpty || plantList.isNotEmpty || infrastructureList.isNotEmpty || otherList.isNotEmpty;
      if (hasEvidence) {
        checksWithEvidence += 1;
      }

      receipts += receiptList.length;
      animals += animalList.length;
      plants += plantList.length;
      infrastructure += infrastructureList.length;
      other += otherList.length;
    }

    return _CheckEvidenceSummary(
      totalChecks: checks.length,
      checksWithEvidence: checksWithEvidence,
      receipts: receipts,
      animals: animals,
      plants: plants,
      infrastructure: infrastructure,
      other: other,
      totalEvidence: receipts + animals + plants + infrastructure + other,
    );
  }

  static String _tzs(double value) {
    final formatter = NumberFormat('#,##0', 'en_US');
    final prefix = value < 0 ? '-TZS ' : 'TZS ';
    return '$prefix${formatter.format(value.abs())}';
  }

  static String _csv(String value) {
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }
}

class _CheckEvidenceSummary {
  final int totalChecks;
  final int checksWithEvidence;
  final int receipts;
  final int animals;
  final int plants;
  final int infrastructure;
  final int other;
  final int totalEvidence;

  const _CheckEvidenceSummary({
    required this.totalChecks,
    required this.checksWithEvidence,
    required this.receipts,
    required this.animals,
    required this.plants,
    required this.infrastructure,
    required this.other,
    required this.totalEvidence,
  });
}
