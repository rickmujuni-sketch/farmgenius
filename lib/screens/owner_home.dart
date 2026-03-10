import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/monthly_report.dart';
import '../models/owner_finance.dart';
import '../models/operations_assist.dart';
import '../services/auth_service.dart';
import '../services/localization_service.dart';
import '../services/monthly_report_service.dart';
import '../services/operations_assist_service.dart';
import '../services/owner_finance_service.dart';
import '../services/report_export_service.dart';

class OwnerHome extends StatefulWidget {
  const OwnerHome({super.key});

  @override
  State<OwnerHome> createState() => _OwnerHomeState();
}

class _OwnerHomeState extends State<OwnerHome> {
  late Future<_OwnerDashboardBundle> _dashboardFuture;

  Future<void> _shareMonthlyReportToWhatsApp({
    required PeriodReportDocument report,
    required LocalizationService loc,
  }) async {
    final text = Uri.encodeComponent(report.whatsappMessage);
    final whatsappUri = Uri.parse('whatsapp://send?text=$text');
    final fallbackUri = Uri.parse('https://wa.me/?text=$text');

    final launched = await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
    if (!launched) {
      final fallbackLaunched = await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
      if (!fallbackLaunched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.t('owner_whatsapp_not_available'))),
        );
      }
    }
  }

  Future<void> _copyMonthlyCsv({
    required PeriodReportDocument report,
    required LocalizationService loc,
  }) async {
    await Clipboard.setData(ClipboardData(text: report.csvContent));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(loc.t('owner_monthly_csv_copied'))),
    );
  }

  Future<void> _previewMonthlyReport({
    required PeriodReportDocument report,
    required LocalizationService loc,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('${loc.t('owner_monthly_report_title')} — ${report.periodLabel}'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...report.kpis.map(
                    (kpi) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('${kpi.label}: ${kpi.value}'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    loc.t('owner_monthly_highlights'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  ...report.highlights.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text('• ${item.title}: ${item.detail}'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(loc.t('cancel')),
            ),
          ],
        );
      },
    );
  }

  Future<void> _shareReportPdf({
    required PeriodReportDocument report,
    required LocalizationService loc,
  }) async {
    try {
      await ReportExportService.sharePdf(report: report);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.t('owner_pdf_export_failed'))),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _dashboardFuture = _loadBundle();
  }

  Future<_OwnerDashboardBundle> _loadBundle() async {
    final results = await Future.wait([
      OwnerFinanceService.loadDashboard(),
      OperationsAssistService.loadSnapshot(),
    ]);

    return _OwnerDashboardBundle(
      finance: results[0] as OwnerFinanceDashboardData,
      assist: results[1] as OperationsAssistSnapshot,
    );
  }

  String _tzs(double value) {
    final formatter = NumberFormat('#,##0', 'en_US');
    final prefix = value < 0 ? '-TZS ' : 'TZS ';
    return '$prefix${formatter.format(value.abs())}';
  }

  Color _netColor(double value) {
    if (value < 0) return Colors.red.shade700;
    return Colors.green.shade700;
  }

  Widget _amountCard({
    required String title,
    required double value,
    Color? valueColor,
  }) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 12, color: Colors.black54)),
              const SizedBox(height: 6),
              Text(
                _tzs(value),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: valueColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _simpleBreakdown(List<FinanceBreakdownItem> items) {
    if (items.isEmpty) {
      return const Text('No data');
    }
    return Column(
      children: items
          .map(
            (item) => ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(item.label),
              trailing: Text(
                _tzs(item.amount),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          )
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = Provider.of<LocalizationService>(context);
    final auth = Provider.of<AuthService>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.t('owner_home')),
        backgroundColor: const Color(0xFF1B5E20),
        actions: [
          IconButton(
            tooltip: loc.t('refresh'),
            onPressed: () {
              setState(() {
                _dashboardFuture = _loadBundle();
              });
            },
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: loc.t('logout'),
            onPressed: () async {
              await auth.signOut();
              if (!mounted) return;
              Navigator.pushReplacementNamed(context, '/');
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: FutureBuilder<_OwnerDashboardBundle>(
        future: _dashboardFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 40, color: Colors.red),
                  const SizedBox(height: 8),
                  Text(loc.t('owner_financial_load_error')),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _dashboardFuture = _loadBundle();
                      });
                    },
                    child: Text(loc.t('retry')),
                  ),
                ],
              ),
            );
          }

          final data = snapshot.data!.finance;
          final assist = snapshot.data!.assist;
          final monthlyReport = MonthlyReportService.buildMonthly(
            finance: data,
            assist: assist,
            reportMonth: DateTime.now(),
          );
          final weeklyReport = MonthlyReportService.buildWeekly(
            finance: data,
            assist: assist,
            reportDate: DateTime.now(),
          );
          final dailyReport = MonthlyReportService.buildDaily(
            finance: data,
            assist: assist,
            reportDate: DateTime.now(),
          );

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _sectionTitle(loc.t('owner_monthly_report_title')),
              _reportCard(
                title: loc.t('owner_daily_report'),
                report: dailyReport,
                loc: loc,
              ),
              _reportCard(
                title: loc.t('owner_weekly_report'),
                report: weeklyReport,
                loc: loc,
              ),
              _reportCard(
                title: loc.t('owner_monthly_report'),
                report: monthlyReport,
                loc: loc,
              ),

              _sectionTitle(loc.t('owner_financial_overview')),
              Row(
                children: [
                  _amountCard(
                    title: loc.t('owner_month_income'),
                    value: data.overview.monthIncome,
                    valueColor: Colors.green.shade700,
                  ),
                  const SizedBox(width: 8),
                  _amountCard(
                    title: loc.t('owner_month_expenses'),
                    value: data.overview.monthExpenses,
                    valueColor: Colors.orange.shade800,
                  ),
                ],
              ),
              Row(
                children: [
                  _amountCard(
                    title: loc.t('owner_month_net'),
                    value: data.overview.monthNet,
                    valueColor: _netColor(data.overview.monthNet),
                  ),
                  const SizedBox(width: 8),
                  _amountCard(
                    title: loc.t('owner_ytd_net'),
                    value: data.overview.ytdNet,
                    valueColor: _netColor(data.overview.ytdNet),
                  ),
                ],
              ),
              Card(
                child: ListTile(
                  title: Text(loc.t('owner_budget_vs_actual')),
                  subtitle: Text(
                    '${loc.t('owner_budget')}: ${_tzs(data.overview.monthBudget)}\n'
                    '${loc.t('owner_variance')}: ${_tzs(data.overview.budgetVariance)}',
                  ),
                ),
              ),

              _sectionTitle(loc.t('owner_revenue_tracking')),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(loc.t('owner_revenue_by_source'), style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      _simpleBreakdown(data.revenueBySource),
                      const Divider(),
                      Text(loc.t('owner_revenue_by_zone'), style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      _simpleBreakdown(data.revenueByZone),
                      const Divider(),
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(loc.t('owner_projected_revenue')),
                        trailing: Text(
                          _tzs(data.biologicalAssets.projectedRevenue),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              _sectionTitle(loc.t('owner_expense_analytics')),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(loc.t('owner_expense_by_category'), style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      ...data.expensesByCategory.map((row) {
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(row.label),
                          subtitle: Text(
                            '${loc.t('owner_budget')}: ${_tzs(row.budget)} • '
                            '${loc.t('owner_variance')}: ${_tzs(row.variance)}',
                          ),
                          trailing: Text(
                            _tzs(row.actual),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: row.isOverrun ? Colors.red.shade700 : null,
                            ),
                          ),
                        );
                      }),
                      const Divider(),
                      Text(loc.t('owner_expense_by_zone'), style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      _simpleBreakdown(data.expensesByZone),
                      const Divider(),
                      Text(loc.t('owner_expense_by_task_type'), style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      _simpleBreakdown(data.expensesByTaskType),
                    ],
                  ),
                ),
              ),

              _sectionTitle(loc.t('owner_zone_profitability')),
              ...data.zoneProfitability.map(
                (zone) => Card(
                  child: ListTile(
                    title: Text(zone.zoneName),
                    subtitle: Text(
                      '${loc.t('owner_revenue')}: ${_tzs(zone.revenue)}\n'
                      '${loc.t('owner_expenses')}: ${_tzs(zone.expenses)}\n'
                      'ROI: ${zone.roiPercent.toStringAsFixed(1)}%',
                    ),
                    trailing: Text(
                      _tzs(zone.net),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: zone.profitable ? Colors.green.shade700 : Colors.red.shade700,
                      ),
                    ),
                  ),
                ),
              ),

              _sectionTitle(loc.t('owner_biological_valuation')),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(loc.t('owner_livestock_value')),
                        trailing: Text(_tzs(data.biologicalAssets.livestockValue)),
                      ),
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(loc.t('owner_crop_value')),
                        trailing: Text(_tzs(data.biologicalAssets.cropValue)),
                      ),
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(loc.t('owner_total_asset_value')),
                        trailing: Text(
                          _tzs(data.biologicalAssets.totalValue),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(loc.t('owner_insurance_valuation')),
                        trailing: Text(_tzs(data.biologicalAssets.insuranceValue)),
                      ),
                    ],
                  ),
                ),
              ),

              _sectionTitle(loc.t('owner_ai_insights')),
              ...data.insights.map(
                (insight) => Card(
                  child: ListTile(
                    leading: Icon(
                      insight.severity == 'critical'
                          ? Icons.warning_amber
                          : insight.severity == 'warning'
                              ? Icons.info_outline
                              : insight.severity == 'positive'
                                  ? Icons.check_circle_outline
                                  : Icons.lightbulb_outline,
                      color: insight.severity == 'critical'
                          ? Colors.red.shade700
                          : insight.severity == 'warning'
                              ? Colors.orange.shade800
                              : insight.severity == 'positive'
                                  ? Colors.green.shade700
                                  : Colors.blueGrey,
                    ),
                    title: Text(insight.title),
                    subtitle: Text(insight.description),
                  ),
                ),
              ),

              _sectionTitle(loc.t('owner_ops_assist')),
              Card(
                child: ListTile(
                  title: Text(loc.t('owner_readiness_score')),
                  trailing: Text(
                    '${assist.readinessScore}/100',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: assist.readinessScore >= 80
                          ? Colors.green.shade700
                          : assist.readinessScore >= 60
                              ? Colors.orange.shade700
                              : Colors.red.shade700,
                    ),
                  ),
                ),
              ),
              _sectionTitle(loc.t('owner_recommended_actions')),
              ...assist.recommendations.map(
                (item) => Card(
                  child: ListTile(
                    leading: Icon(
                      item.priority == 'critical'
                          ? Icons.priority_high
                          : item.priority == 'high'
                              ? Icons.warning_amber
                              : Icons.lightbulb_outline,
                      color: item.priority == 'critical'
                          ? Colors.red.shade700
                          : item.priority == 'high'
                              ? Colors.orange.shade700
                              : Colors.blueGrey,
                    ),
                    title: Text(item.title),
                    subtitle: Text(
                      '${item.action}\n${item.expectedImpact}',
                    ),
                  ),
                ),
              ),
              _sectionTitle(loc.t('owner_data_ownership')),
              ...assist.ownershipRules.map(
                (rule) => Card(
                  child: ListTile(
                    title: Text(rule.dataType),
                    subtitle: Text(
                      '${loc.t('owner_primary_role')}: ${rule.primaryRole}\n'
                      '${loc.t('owner_review_role')}: ${rule.reviewRole}\n'
                      '${loc.t('owner_positive_impact')}: ${rule.positiveImpact}',
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _OwnerDashboardBundle {
  final OwnerFinanceDashboardData finance;
  final OperationsAssistSnapshot assist;

  const _OwnerDashboardBundle({
    required this.finance,
    required this.assist,
  });
}

extension on _OwnerHomeState {
  Widget _reportCard({
    required String title,
    required PeriodReportDocument report,
    required LocalizationService loc,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              '${loc.t('owner_report_period')}: ${report.periodLabel}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              '${loc.t('owner_report_generated_at')}: ${DateFormat('yyyy-MM-dd HH:mm').format(report.generatedAt)}',
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _previewMonthlyReport(report: report, loc: loc),
                  icon: const Icon(Icons.preview),
                  label: Text(loc.t('owner_preview_report')),
                ),
                ElevatedButton.icon(
                  onPressed: () => _shareMonthlyReportToWhatsApp(report: report, loc: loc),
                  icon: const Icon(Icons.send),
                  label: Text(loc.t('owner_share_whatsapp')),
                ),
                OutlinedButton.icon(
                  onPressed: () => _copyMonthlyCsv(report: report, loc: loc),
                  icon: const Icon(Icons.table_view),
                  label: Text(loc.t('owner_copy_csv')),
                ),
                OutlinedButton.icon(
                  onPressed: () => _shareReportPdf(report: report, loc: loc),
                  icon: const Icon(Icons.picture_as_pdf),
                  label: Text(loc.t('owner_export_pdf')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
