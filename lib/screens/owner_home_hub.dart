import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/external_partner_entry.dart';
import '../models/biological_asset.dart';
import '../models/monthly_report.dart';
import '../models/operations_assist.dart';
import '../models/owner_finance.dart';
import '../models/breed_recommendation.dart';
import '../services/auth_service.dart';
import '../services/biological_asset_service.dart';
import '../services/breed_recommendation_service.dart';
import '../services/demo_seed_service.dart';
import '../services/external_partner_service.dart';
import '../services/farmgenius_content_localizer.dart';
import '../services/localization_service.dart';
import '../services/monthly_report_service.dart';
import '../services/operations_assist_question_history_service.dart';
import '../services/operations_assist_question_service.dart';
import '../services/operations_assist_service.dart';
import '../services/owner_finance_service.dart';
import '../services/report_export_service.dart';
import '../services/supabase_service.dart';
import '../services/whatsapp_share_service.dart';
import '../screens/ai/knowledge_report_list_screen.dart';
import 'dashboard_hub_scaffold.dart';
import 'owner_team_admin_dialog.dart';

class OwnerHome extends StatefulWidget {
  const OwnerHome({
    super.key,
    this.teamAdminActorRoleOverride,
    this.teamAdminMemberOverrides,
    this.onAssignTeamAdminRole,
  });

  final String? teamAdminActorRoleOverride;
  final List<Map<String, dynamic>>? teamAdminMemberOverrides;
  final TeamAdminRoleAssignment? onAssignTeamAdminRole;

  @override
  State<OwnerHome> createState() => _OwnerHomeState();
}

class _OwnerHomeState extends State<OwnerHome> {
  static const int _fullTimeTeams = 4;
  static const double _monthlyPayPerTeamTzs = 100000;

  late Future<_OwnerDashboardBundle> _dashboardFuture;

  String _lp(String value) =>
      FarmGeniusContentLocalizer.localizePlainText(value);

  @override
  void initState() {
    super.initState();
    _dashboardFuture = _loadBundle();
  }

  Future<_OwnerDashboardBundle> _loadBundle() async {
    final userId = Provider.of<AuthService>(context, listen: false).user?.id;
    await DemoSeedService.ensureSeedData(userId: userId);

    final results = await Future.wait([
      OwnerFinanceService.loadDashboard(),
      OwnerFinanceService.loadZoneCashCowRanking(),
      OperationsAssistService.loadSnapshot(),
      BreedRecommendationService.recommendAllSpeciesFromFarm(),
      BiologicalAssetService.getDashboardSummary(),
      BiologicalAssetService.getCategorySummary(),
      BiologicalAssetService.getRecentDailyChecks(limit: 500),
      BiologicalAssetService.getTopAssetsByValue(limit: 40),
      ExternalPartnerService.getEntries(pendingOnly: true, limit: 30),
      BiologicalAssetService.getAssetZones(),
      _loadBioAssetExecutionTasks(),
    ]);

    final breedRecommendations =
        (results[3] as List<BreedRecommendationResult>);
    final assetZoneNames = <String, String>{
      for (final zone in results[9] as List<AssetZoneOption>)
        if (zone.id.trim().isNotEmpty && zone.name.trim().isNotEmpty)
          zone.id: zone.name,
    };

    return _OwnerDashboardBundle(
      finance: results[0] as OwnerFinanceDashboardData,
      zoneCashCowRanking: results[1] as ZoneCashCowRanking,
      assist: results[2] as OperationsAssistSnapshot,
      breedRecommendations: breedRecommendations,
      bioSummary: results[4] as BiologicalAssetDashboardSummary?,
      bioCategories: results[5] as List<BiologicalAssetCategorySummary>,
      dailyChecks: results[6] as List<DailyAssetCheck>,
      bioAssetRows: results[7] as List<BiologicalAssetValueRow>,
      pendingExternalEntries: results[8] as List<ExternalPartnerEntry>,
      assetZoneNames: assetZoneNames,
      bioAssetExecutionTaskRows: results[10] as List<Map<String, dynamic>>,
    );
  }

  double _monthlyPayrollBaselineTzs() => _fullTimeTeams * _monthlyPayPerTeamTzs;

  String _resolveBioAssetZoneLabel({
    required String zoneId,
    required Map<String, String> assetZoneNames,
  }) {
    final explicitName = assetZoneNames[zoneId]?.trim();
    final rawValue = explicitName == null || explicitName.isEmpty
        ? zoneId
        : explicitName;
    return FarmGeniusContentLocalizer.localizeZoneName(rawValue);
  }

  List<DailyAssetCheck> _checksForPeriod({
    required List<DailyAssetCheck> checks,
    required String periodType,
    required DateTime now,
  }) {
    if (periodType == 'daily') {
      return checks.where((check) {
        final date = check.checkDate;
        return date.year == now.year &&
            date.month == now.month &&
            date.day == now.day;
      }).toList();
    }

    if (periodType == 'weekly') {
      final start = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: now.weekday - 1));
      final end = start.add(const Duration(days: 7));
      return checks.where((check) {
        final date = DateTime(
          check.checkDate.year,
          check.checkDate.month,
          check.checkDate.day,
        );
        return !date.isBefore(start) && date.isBefore(end);
      }).toList();
    }

    return checks.where((check) {
      final date = check.checkDate;
      return date.year == now.year && date.month == now.month;
    }).toList();
  }

  String _tzs(double value) {
    final formatter = NumberFormat('#,##0', 'en_US');
    final prefix = value < 0 ? '-TZS ' : 'TZS ';
    return '$prefix${formatter.format(value.abs())}';
  }

  Future<void> _openTeamAdminDialog() async {
    await showDialog<void>(
      context: context,
      builder: (_) => OwnerTeamAdminDialog(
        actorRoleOverride: widget.teamAdminActorRoleOverride,
        memberOverrides: widget.teamAdminMemberOverrides,
        assignRoleOverride: widget.onAssignTeamAdminRole,
      ),
    );
    if (!mounted) return;
    setState(() {
      _dashboardFuture = _loadBundle();
    });
  }

  Future<void> _shareToWhatsApp(String text, LocalizationService loc) async {
    final result = await WhatsAppShareService.shareTextDetailed(text);
    if (!result.success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.t('owner_whatsapp_not_available'))),
      );
    }
  }

  Future<void> _copyCsv(
    PeriodReportDocument report,
    LocalizationService loc,
  ) async {
    await Clipboard.setData(ClipboardData(text: report.csvContent));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(loc.t('owner_monthly_csv_copied'))));
  }

  Future<void> _sharePdf(
    PeriodReportDocument report,
    LocalizationService loc,
  ) async {
    try {
      await ReportExportService.sharePdf(report: report);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(loc.t('owner_pdf_export_failed'))));
    }
  }

  void _openFinanceDetail(_OwnerDashboardBundle bundle) {
    final data = bundle.finance;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DrillDownScaffold(
          title: _lp('Financial Detail'),
          children: [
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Text(
                _lp(
                  'Source note: income and expense are calculated from activity logs (cost, quantity, and notes). If explicit amounts are missing, FarmGenius estimates values from unit defaults and effort-hours rules.',
                ),
                style: TextStyle(height: 1.35),
              ),
            ),
            _metricTile(
              _lp('Month Income'),
              _tzs(data.overview.monthIncome),
              Colors.green.shade700,
            ),
            _metricTile(
              _lp('Month Expenses'),
              _tzs(data.overview.monthExpenses),
              Colors.orange.shade800,
            ),
            _metricTile(
              _lp('Month Net'),
              _tzs(data.overview.monthNet),
              data.overview.monthNet < 0
                  ? Colors.red.shade700
                  : Colors.green.shade700,
            ),
            _metricTile(
              _lp('Planned Team Payroll'),
              _tzs(_monthlyPayrollBaselineTzs()),
              Colors.indigo.shade700,
            ),
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Text(
                _lp(
                  'Workforce plan: 4 full-time operator teams at TZS 100,000 each monthly. Feeding, accommodation, and medical support are treated as in-kind welfare and should be logged via external/service or ledger entries for full cost visibility.',
                ),
                style: TextStyle(height: 1.35),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _lp('Revenue by Source'),
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            ...data.revenueBySource.map(
              (item) => ListTile(
                title: Text(item.label),
                trailing: Text(_tzs(item.amount)),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _lp('Expenses by Category'),
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            ...data.expensesByCategory.map(
              (item) => ListTile(
                title: Text(item.label),
                subtitle: Text('${_lp('Budget')}: ${_tzs(item.budget)}'),
                trailing: Text(_tzs(item.actual)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openReportsDetail(
    _OwnerDashboardBundle bundle,
    LocalizationService loc,
  ) async {
    final now = DateTime.now();

    try {
      await BiologicalAssetService.compactOutdatedCheckEvidence();
    } catch (_) {}

    if (!mounted) return;

    final dailyChecks = _checksForPeriod(
      checks: bundle.dailyChecks,
      periodType: 'daily',
      now: now,
    );
    final weeklyChecks = _checksForPeriod(
      checks: bundle.dailyChecks,
      periodType: 'weekly',
      now: now,
    );
    final monthlyChecks = _checksForPeriod(
      checks: bundle.dailyChecks,
      periodType: 'monthly',
      now: now,
    );

    final reports = [
      MonthlyReportService.buildDaily(
        finance: bundle.finance,
        assist: bundle.assist,
        reportDate: now,
        dailyChecks: dailyChecks,
      ),
      MonthlyReportService.buildWeekly(
        finance: bundle.finance,
        assist: bundle.assist,
        reportDate: now,
        dailyChecks: weeklyChecks,
      ),
      MonthlyReportService.buildMonthly(
        finance: bundle.finance,
        assist: bundle.assist,
        reportMonth: now,
        dailyChecks: monthlyChecks,
      ),
    ];

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DrillDownScaffold(
          title: _lp('Report Center'),
          children: reports.map((report) {
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_lp(report.periodType)} • ${report.periodLabel}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ElevatedButton(
                          onPressed: () => showDialog<void>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: Text(
                                _lp('Preview ${report.periodType} report'),
                              ),
                              content: SizedBox(
                                width: 420,
                                child: SingleChildScrollView(
                                  child: Text(report.whatsappMessage),
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: Text(_lp('Close')),
                                ),
                              ],
                            ),
                          ),
                          child: Text(_lp('Preview')),
                        ),
                        OutlinedButton(
                          onPressed: () =>
                              _shareToWhatsApp(report.whatsappMessage, loc),
                          child: Text(_lp('WhatsApp')),
                        ),
                        OutlinedButton(
                          onPressed: () => _copyCsv(report, loc),
                          child: Text(_lp('Copy CSV')),
                        ),
                        OutlinedButton(
                          onPressed: () => _sharePdf(report, loc),
                          child: Text(_lp('Share PDF')),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  void _openAssistDetail(_OwnerDashboardBundle bundle) {
    final counts = bundle.assist.recommendationStatusCounts;
    final loc = Provider.of<LocalizationService>(context, listen: false);
    final questionContext = _buildAssistQuestionContext(bundle);
    final verificationQueueKey = GlobalKey();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DrillDownScaffold(
          title: _lp('AI Insights'),
          children: [
            _metricTile(
              _lp('Readiness Score'),
              '${bundle.assist.readinessScore}/100',
              Colors.blueGrey,
            ),
            const SizedBox(height: 12),
            _AssistQuestionCard(
              localize: _lp,
              questionContext: questionContext,
              onActionPressed: (response) {
                return _handleAssistQuestionAction(
                  response: response,
                  bundle: bundle,
                  loc: loc,
                  verificationQueueKey: verificationQueueKey,
                );
              },
            ),
            const SizedBox(height: 12),
            Text(
              _lp('Top Recommendations'),
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            ...bundle.assist.recommendations.map(
              (item) => ListTile(
                title: Text(item.title),
                subtitle: Text(item.action),
                trailing: Text(item.priority.toUpperCase()),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _lp('Implementation Tracker'),
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            if (counts.isEmpty)
              ListTile(
                title: Text(_lp('No recommendation tracking records yet')),
                subtitle: Text(
                  _lp(
                    'Actions (accept/modify/execute) will appear here after team updates.',
                  ),
                ),
              )
            else ...[
              _metricTile(
                _lp('Proposed'),
                '${counts['proposed'] ?? 0}',
                Colors.blueGrey.shade700,
              ),
              _metricTile(
                _lp('Accepted'),
                '${counts['accepted'] ?? 0}',
                Colors.blue.shade700,
              ),
              _metricTile(
                _lp('Modified'),
                '${counts['modified'] ?? 0}',
                Colors.orange.shade700,
              ),
              _metricTile(
                _lp('Deferred'),
                '${counts['deferred'] ?? 0}',
                Colors.deepPurple.shade700,
              ),
              _metricTile(
                _lp('Executed'),
                '${counts['executed'] ?? 0}',
                Colors.green.shade700,
              ),
            ],
            const SizedBox(height: 8),
            Text(
              _lp('How Addressed (Recent)'),
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            if (bundle.assist.recommendationExecutionLogs.isEmpty)
              ListTile(
                title: Text(_lp('No recommendation actions captured yet')),
              )
            else
              ...bundle.assist.recommendationExecutionLogs.map(
                (log) => ListTile(
                  title: Text(log.recommendationText),
                  subtitle: Text(
                    '${log.actionType.toUpperCase()}${log.notes == null || log.notes!.isEmpty ? '' : ' • ${log.notes}'}',
                  ),
                  trailing: Text(
                    log.actedAt == null
                        ? '-'
                        : DateFormat('dd MMM').format(log.actedAt!),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Container(
              key: verificationQueueKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _lp('Doctor/Supplier Verification Queue'),
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (bundle.pendingExternalEntries.isEmpty)
                    ListTile(
                      title: Text(_lp('No pending external entries')),
                      subtitle: Text(
                        _lp(
                          'All submitted doctor/supplier events are already verified.',
                        ),
                      ),
                    )
                  else
                    ...bundle.pendingExternalEntries.map(
                      (entry) => ListTile(
                        title: Text(
                          '${entry.partnerType.toUpperCase()} • ${entry.partnerName}',
                        ),
                        subtitle: Text(
                          '${entry.entryKind} • ${entry.serviceDate == null ? '-' : DateFormat('dd MMM yyyy').format(entry.serviceDate!)} • ${_tzs(entry.amountTzs)}',
                        ),
                        trailing: Wrap(
                          spacing: 6,
                          children: [
                            TextButton(
                              onPressed: () => _reviewExternalEntry(
                                entry: entry,
                                approved: false,
                              ),
                              child: Text(_lp('Reject')),
                            ),
                            ElevatedButton(
                              onPressed: () => _reviewExternalEntry(
                                entry: entry,
                                approved: true,
                              ),
                              child: Text(_lp('Approve')),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _lp('Data Ownership Rules'),
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            ...bundle.assist.ownershipRules.map(
              (rule) => ListTile(
                title: Text(rule.dataType),
                subtitle: Text('${rule.primaryRole} → ${rule.reviewRole}'),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _openForecastDetail(bundle),
                  icon: const Icon(Icons.timeline),
                  label: Text(_lp('Forecast Engine')),
                ),
                OutlinedButton.icon(
                  onPressed: () => _openBreedRecommendationDetail(bundle),
                  icon: const Icon(Icons.pets),
                  label: Text(_lp('Breed Recommendations')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  OperationsAssistQuestionContext _buildAssistQuestionContext(
    _OwnerDashboardBundle bundle,
  ) {
    final intelligence = _buildBioAssetIntelligence(bundle);
    final rankedBreedRecommendations = [...bundle.breedRecommendations]
      ..sort((left, right) {
        final herdComparison = right.herdSize.compareTo(left.herdSize);
        if (herdComparison != 0) {
          return herdComparison;
        }

        final leftScore = left.ranked.isEmpty
            ? 0.0
            : left.topRecommendation.score;
        final rightScore = right.ranked.isEmpty
            ? 0.0
            : right.topRecommendation.score;
        return rightScore.compareTo(leftScore);
      });

    final focus = rankedBreedRecommendations.isEmpty
        ? null
        : rankedBreedRecommendations.first;
    final totalLivestockCount = rankedBreedRecommendations.fold<int>(
      0,
      (sum, result) => sum + (result.herdSize < 0 ? 0 : result.herdSize),
    );
    final livestockCountBySpecies = <String, int>{};
    for (final result in rankedBreedRecommendations) {
      final species = result.species.trim().toLowerCase();
      if (species.isEmpty) continue;
      livestockCountBySpecies[species] =
          (livestockCountBySpecies[species] ?? 0) +
          (result.herdSize < 0 ? 0 : result.herdSize);
    }
    DateTime? latestLivestockStockUpdateAt;
    for (final result in rankedBreedRecommendations) {
      final updatedAt = result.stockUpdateDate;
      if (updatedAt == null) continue;
      if (latestLivestockStockUpdateAt == null ||
          updatedAt.isAfter(latestLivestockStockUpdateAt)) {
        latestLivestockStockUpdateAt = updatedAt;
      }
    }
    var pendingTaskCount = 0;
    var overdueTaskCount = 0;
    var completedTaskCount = 0;
    final now = DateTime.now();
    for (final row in bundle.bioAssetExecutionTaskRows) {
      final status = (row['status'] ?? '').toString().trim().toUpperCase();
      final dueDate = DateTime.tryParse((row['due_date'] ?? '').toString());

      if (status == 'COMPLETED') {
        completedTaskCount += 1;
        continue;
      }

      if (status == 'CANCELLED') {
        continue;
      }

      pendingTaskCount += 1;
      if (dueDate != null && dueDate.isBefore(now)) {
        overdueTaskCount += 1;
      }
    }

    final inventoryAlertCount = bundle.assist.recommendations.where((item) {
      final haystack = '${item.area} ${item.title} ${item.action}'
          .toLowerCase();
      return haystack.contains('inventory') ||
          haystack.contains('procurement') ||
          haystack.contains('stock');
    }).length;

    final medicationAlertCount = bundle.assist.recommendations.where((item) {
      final haystack = '${item.area} ${item.title} ${item.action}'
          .toLowerCase();
      return haystack.contains('medication') ||
          haystack.contains('vaccine') ||
          haystack.contains('health');
    }).length;
    final focusBreed = focus == null || focus.ranked.isEmpty
        ? null
        : focus.topRecommendation.breed.name;
    final focusReason =
        focus == null ||
            focus.ranked.isEmpty ||
            focus.topRecommendation.reasons.isEmpty
        ? null
        : focus.topRecommendation.reasons.first;
    final maintenanceFocus = focus == null || focus.maintenancePlan.isEmpty
        ? null
        : focus.maintenancePlan.first;

    return OperationsAssistQuestionContext(
      assist: bundle.assist,
      recentFieldLogCount: bundle.dailyChecks.length,
      last30DayCheckCount: intelligence.last30DaysChecks,
      last30DayCheckDeltaLabel: intelligence.last30DayCheckDeltaLabel,
      pendingVerificationCount: bundle.pendingExternalEntries.length,
      activeBioAssetCount: bundle.bioSummary?.activeAssets ?? 0,
      gestationStock: intelligence.gestationStock,
      newbornStock: intelligence.newbornStock,
      unhealthyTrees: intelligence.unhealthyTrees,
      breedRecommendationCount: bundle.breedRecommendations.length,
      totalLivestockCount: totalLivestockCount,
      livestockCountBySpecies: livestockCountBySpecies,
      latestLivestockStockUpdateAt: latestLivestockStockUpdateAt,
      bioAssetTaskPendingCount: pendingTaskCount,
      bioAssetTaskOverdueCount: overdueTaskCount,
      bioAssetTaskCompletedCount: completedTaskCount,
      inventoryAlertCount: inventoryAlertCount,
      medicationAlertCount: medicationAlertCount,
      livestockFocusSpecies: focus?.species,
      livestockFocusHerdSize: focus?.herdSize ?? 0,
      livestockFocusBreed: focusBreed,
      livestockFocusReason: focusReason,
      livestockMaintenanceFocus: maintenanceFocus,
    );
  }

  Future<bool> _handleAssistQuestionAction({
    required OperationsAssistQuestionResponse response,
    required _OwnerDashboardBundle bundle,
    required LocalizationService loc,
    required GlobalKey verificationQueueKey,
  }) async {
    switch (response.actionType) {
      case OperationsAssistQuestionActionType.createTask:
        final recommendation = response.taskRecommendation?.trim();
        if (recommendation == null || recommendation.isEmpty) {
          if (!mounted) return false;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _lp('No taskable AI action is available yet for this answer.'),
              ),
            ),
          );
          return false;
        }
        return _openCreateBioAssetActionDialog([recommendation]);
      case OperationsAssistQuestionActionType.openReports:
        await _openReportsDetail(bundle, loc);
        return true;
      case OperationsAssistQuestionActionType.openForecast:
        _openForecastDetail(bundle);
        return true;
      case OperationsAssistQuestionActionType.openBreedRecommendations:
        _openBreedRecommendationDetail(bundle);
        return true;
      case OperationsAssistQuestionActionType.reviewVerificationQueue:
        final targetContext = verificationQueueKey.currentContext;
        if (targetContext == null) {
          if (!mounted) return false;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_lp('Verification queue is already in this view.')),
            ),
          );
          return false;
        }
        await Scrollable.ensureVisible(
          targetContext,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
        return true;
    }
  }

  Future<void> _reviewExternalEntry({
    required ExternalPartnerEntry entry,
    required bool approved,
  }) async {
    try {
      await ExternalPartnerService.reviewEntry(
        entryId: entry.id,
        approved: approved,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            approved
                ? _lp('Entry approved for payment.')
                : _lp('Entry rejected for correction.'),
          ),
        ),
      );
      setState(() {
        _dashboardFuture = _loadBundle();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_lp('Could not update verification: $e'))),
      );
    }
  }

  void _openProfitabilityDetail(_OwnerDashboardBundle bundle) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ZoneProfitabilityDetailScreen(
          ranking: bundle.zoneCashCowRanking,
          localize: _lp,
          formatCurrency: _tzs,
          comparisonGraphBuilder: _zoneProfitabilityComparisonGraph,
        ),
      ),
    );
  }

  Widget _zoneProfitabilityComparisonGraph(List<ZoneFinancialSnapshot> zones) {
    if (zones.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blueGrey.shade100),
        ),
        child: Text(_lp('No zone data available for chart comparison.')),
      );
    }

    var maxAbsNet = 1.0;
    for (final zone in zones) {
      final magnitude = zone.net.abs();
      if (magnitude > maxAbsNet) {
        maxAbsNet = magnitude;
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blueGrey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _lp('Net Comparison by Zone'),
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          ...zones.map((zone) {
            final ratio = (zone.net.abs() / maxAbsNet).clamp(0.08, 1.0);
            final color = zone.net < 0
                ? Colors.red.shade700
                : Colors.green.shade700;

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          zone.zoneName,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        _tzs(zone.net),
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: ratio,
                      minHeight: 12,
                      color: color,
                      backgroundColor: color.withValues(alpha: 0.16),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _lp(
                      'Revenue ${_tzs(zone.revenue)} • Expense ${_tzs(zone.expenses)} • ROI ${zone.roiPercent.toStringAsFixed(1)}%',
                    ),
                    style: TextStyle(
                      color: Colors.blueGrey.shade700,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  _OwnerForecastSnapshot _buildForecastSnapshot(_OwnerDashboardBundle bundle) {
    final finance = bundle.finance;
    final intelligence = _buildBioAssetIntelligence(bundle);

    final monthIncome = finance.overview.monthIncome;
    final monthExpense = finance.overview.monthExpenses;
    final monthNet = finance.overview.monthNet;

    final monthlySaleRate = intelligence.sold <= 0 ? 1 : intelligence.sold;
    final currentBirthRate = intelligence.newbornStock;
    final gestationBacklog = intelligence.gestationStock;

    final births30 = currentBirthRate + (gestationBacklog * 0.25).round();
    final births60 = (currentBirthRate * 2) + (gestationBacklog * 0.50).round();
    final births90 = (currentBirthRate * 3) + (gestationBacklog * 0.75).round();

    final avgSaleValue = monthlySaleRate > 0
        ? monthIncome / monthlySaleRate
        : 0.0;
    final sales30 = (monthlySaleRate + (births30 * 0.25)).round();
    final sales60 = (monthlySaleRate * 2 + (births60 * 0.30)).round();
    final sales90 = (monthlySaleRate * 3 + (births90 * 0.35)).round();

    final pruningEffectMultiplier = intelligence.pruned > 0 ? 0.98 : 1.05;
    final unhealthyPressureMultiplier = intelligence.unhealthyTrees >= 6
        ? 1.16
        : intelligence.unhealthyTrees >= 3
        ? 1.10
        : 1.04;

    final expense30 =
        monthExpense * unhealthyPressureMultiplier * pruningEffectMultiplier;
    final expense60 =
        monthExpense *
        2 *
        unhealthyPressureMultiplier *
        pruningEffectMultiplier;
    final expense90 =
        monthExpense *
        3 *
        unhealthyPressureMultiplier *
        pruningEffectMultiplier;

    final income30 = (avgSaleValue * sales30).toDouble();
    final income60 = (avgSaleValue * sales60).toDouble();
    final income90 = (avgSaleValue * sales90).toDouble();

    final net30 = income30 - expense30;
    final net60 = income60 - expense60;
    final net90 = income90 - expense90;

    final pressureScore = _clampScore(
      35 +
          (intelligence.unhealthyTrees * 8) -
          (intelligence.pruned * 2) +
          (monthNet < 0 ? 20 : 0),
    );

    final readinessScore = _clampScore(
      bundle.assist.readinessScore +
          (intelligence.last30DaysChecks >= 12 ? 8 : -6) +
          (intelligence.newbornStock > 0 ? 5 : 0),
    );

    final focus = <String>[];
    if (intelligence.unhealthyTrees >= 3) {
      focus.add(
        'Run disease and pest containment in top-risk zones this week.',
      );
    }
    if (intelligence.gestationStock > intelligence.newbornStock) {
      focus.add(
        'Prepare birthing pens, kits, and staff rosters before the next 30 days.',
      );
    }
    if (monthNet < 0) {
      focus.add(
        'Delay non-critical spend and enforce weekly procurement approvals.',
      );
    }
    if (intelligence.pruned == 0) {
      focus.add(
        'Launch pruning cycle to reduce 60-90 day orchard disease pressure.',
      );
    }
    if (focus.isEmpty) {
      focus.add(
        'Maintain current execution cadence and monitor leading indicators weekly.',
      );
    }

    return _OwnerForecastSnapshot(
      income30: income30,
      income60: income60,
      income90: income90,
      expense30: expense30,
      expense60: expense60,
      expense90: expense90,
      net30: net30,
      net60: net60,
      net90: net90,
      births30: births30,
      births60: births60,
      births90: births90,
      sales30: sales30,
      sales60: sales60,
      sales90: sales90,
      riskPressureScore: pressureScore,
      executionReadinessScore: readinessScore,
      focusActions: focus,
    );
  }

  int _clampScore(int value) {
    if (value < 0) return 0;
    if (value > 100) return 100;
    return value;
  }

  void _openForecastDetail(_OwnerDashboardBundle bundle) {
    final forecast = _buildForecastSnapshot(bundle);

    Widget forecastBlock({
      required String label,
      required int births,
      required int sales,
      required double income,
      required double expense,
      required double net,
    }) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.blueGrey.shade100),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _lp(label),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              _metricTile(
                _lp('Projected Births / New Stock'),
                '$births',
                Colors.indigo.shade700,
              ),
              _metricTile(
                _lp('Projected Sales Units'),
                '$sales',
                Colors.orange.shade800,
              ),
              _metricTile(
                _lp('Projected Income'),
                _tzs(income),
                Colors.green.shade700,
              ),
              _metricTile(
                _lp('Projected Cost'),
                _tzs(expense),
                Colors.red.shade700,
              ),
              _metricTile(
                _lp('Projected Net'),
                _tzs(net),
                net < 0 ? Colors.red.shade800 : Colors.green.shade800,
              ),
            ],
          ),
        ),
      );
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DrillDownScaffold(
          title: _lp('Forecast Engine'),
          children: [
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Text(
                _lp(
                  'Forecasts blend current month financials with observed stock signals (gestation, newborn, unhealthy trees, pruned, sold). Treat this as decision support and recalibrate weekly as fresh checks arrive.',
                ),
                style: TextStyle(height: 1.35),
              ),
            ),
            _metricTile(
              _lp('Risk Pressure Score'),
              '${forecast.riskPressureScore}/100',
              Colors.red.shade700,
            ),
            _metricTile(
              _lp('Execution Readiness Score'),
              '${forecast.executionReadinessScore}/100',
              Colors.green.shade700,
            ),
            const SizedBox(height: 10),
            forecastBlock(
              label: '30 Day Outlook',
              births: forecast.births30,
              sales: forecast.sales30,
              income: forecast.income30,
              expense: forecast.expense30,
              net: forecast.net30,
            ),
            forecastBlock(
              label: '60 Day Outlook',
              births: forecast.births60,
              sales: forecast.sales60,
              income: forecast.income60,
              expense: forecast.expense60,
              net: forecast.net60,
            ),
            forecastBlock(
              label: '90 Day Outlook',
              births: forecast.births90,
              sales: forecast.sales90,
              income: forecast.income90,
              expense: forecast.expense90,
              net: forecast.net90,
            ),
            const SizedBox(height: 8),
            Text(
              _lp('Priority Focus'),
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            ...forecast.focusActions.map(
              (item) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.check_circle_outline, size: 20),
                title: Text(_lp(item)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openBreedRecommendationDetail(_OwnerDashboardBundle bundle) {
    if (bundle.breedRecommendations.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _lp('No livestock data available for recommendation yet.'),
          ),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DrillDownScaffold(
          title: _lp('Breed Recommendation'),
          children: [
            _metricTile(
              _lp('Species Assessed'),
              '${bundle.breedRecommendations.length}',
              Colors.brown.shade700,
            ),
            ...bundle.breedRecommendations.map(
              (recommendation) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        recommendation.species.toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _lp(
                          'Current Breed: ${recommendation.currentBreed ?? 'Not recorded'}',
                        ),
                      ),
                      Text(
                        _lp('Estimated Herd Size: ${recommendation.herdSize}'),
                      ),
                      Text(
                        _lp(
                          'Last Stock Update: ${recommendation.stockUpdateDate == null ? 'Not recorded' : DateFormat('dd MMM yyyy').format(recommendation.stockUpdateDate!)}',
                        ),
                      ),
                      Text(
                        _lp(
                          'Recommended Breed: ${recommendation.topRecommendation.breed.name} (${recommendation.topRecommendation.score.toStringAsFixed(1)}/100)',
                        ),
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (recommendation.stockUpdateNote != null &&
                          recommendation.stockUpdateNote!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            recommendation.stockUpdateNote!,
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                        ),
                      const SizedBox(height: 6),
                      Text(
                        _lp('Ranked Options'),
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      ...recommendation.ranked.map(
                        (item) => ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(item.breed.name),
                          subtitle: Text(item.reasons.join('  ')),
                          trailing: Text(
                            '${item.score.toStringAsFixed(1)}/100',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _lp('Maintenance Plan'),
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            ...bundle.breedRecommendations.first.maintenancePlan.map(
              (item) => ListTile(
                dense: true,
                leading: const Icon(Icons.check_circle_outline, size: 20),
                title: Text(_lp(item)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openBioassetDetail(_OwnerDashboardBundle bundle) {
    final summary = bundle.bioSummary;
    final intelligence = _buildBioAssetIntelligence(bundle);
    final aiRecommendations = _buildBioAssetRecommendations(
      bundle: bundle,
      intelligence: intelligence,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DrillDownScaffold(
          title: _lp('Asset Valuation'),
          children: [
            _metricTile(
              _lp('Active Bioassets'),
              '${summary?.activeAssets ?? 0}',
              Colors.teal.shade700,
            ),
            _metricTile(
              _lp('Total Quantity'),
              NumberFormat(
                '#,##0.##',
                'en_US',
              ).format(summary?.totalQuantity ?? 0),
              Colors.blueGrey.shade700,
            ),
            _metricTile(
              _lp('Total Medium Value'),
              _tzs(summary?.totalMedium ?? 0),
              Colors.green.shade700,
            ),
            _metricTile(
              _lp('Livestock Medium Value'),
              _tzs(summary?.livestockMedium ?? 0),
              Colors.brown.shade700,
            ),
            _metricTile(
              _lp('Crops Medium Value'),
              _tzs(summary?.cropsMedium ?? 0),
              Colors.lightGreen.shade700,
            ),
            const SizedBox(height: 12),
            Text(
              _lp('Operational Stock Signals'),
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _metricTile(
              _lp('In Gestation'),
              '${intelligence.gestationStock}',
              Colors.indigo.shade700,
            ),
            _metricTile(
              _lp('Newborn'),
              '${intelligence.newbornStock}',
              Colors.green.shade700,
            ),
            _metricTile(
              _lp('Unhealthy Trees'),
              '${intelligence.unhealthyTrees}',
              Colors.red.shade700,
            ),
            _metricTile(
              _lp('Pruned'),
              '${intelligence.pruned}',
              Colors.deepPurple.shade700,
            ),
            _metricTile(
              _lp('Sold'),
              '${intelligence.sold}',
              Colors.orange.shade700,
            ),
            _metricTile(
              _lp('Checks (Last 30 Days)'),
              '${intelligence.last30DaysChecks} (${_lp(intelligence.last30DayCheckDeltaLabel)})',
              Colors.blueGrey.shade700,
            ),
            const SizedBox(height: 12),
            Text(
              _lp('Bioasset Value List'),
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            if (bundle.bioAssetRows.isEmpty)
              ListTile(
                title: Text(_lp('No detailed asset valuation rows found yet')),
              )
            else
              ...bundle.bioAssetRows.map(
                (asset) => ListTile(
                  title: Text(
                    _lp(
                      '${_bioLabel(asset.species)} (${_bioLabel(asset.assetType)})',
                    ),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    _lp(
                      'Zone ${_resolveBioAssetZoneLabel(zoneId: asset.zoneId, assetZoneNames: bundle.assetZoneNames)} • Qty ${NumberFormat('#,##0.##', 'en_US').format(asset.quantity)} ${asset.unit}${asset.maturityStage == null || asset.maturityStage!.isEmpty ? '' : ' • ${asset.maturityStage}'}',
                    ),
                  ),
                  trailing: Text(
                    _tzs(asset.scenarioMedium),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.green.shade700,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Text(
              _lp('All Bioasset Categories'),
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            if (bundle.bioCategories.isEmpty)
              ListTile(title: Text(_lp('No bioasset category data yet')))
            else
              ...bundle.bioCategories.map(
                (category) => ListTile(
                  title: Text(_lp(category.assetType)),
                  subtitle: Text(_lp('Count ${category.assetCount}')),
                  trailing: Text(_tzs(category.totalMedium)),
                ),
              ),
            const SizedBox(height: 12),
            Text(
              _lp('AI Suggestions (Historical + Best Practice)'),
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            ...aiRecommendations.map(
              (recommendation) => Card(
                child: ListTile(
                  leading: const Icon(
                    Icons.auto_awesome,
                    color: Color(0xFF1B5E20),
                  ),
                  title: Text(_lp(recommendation)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _lp('Execution Tracker'),
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _lp(
                        'Convert AI suggestions into accountable tasks with owner, due date, and measurable outcomes.',
                      ),
                      style: TextStyle(height: 1.35),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: () =>
                          _openCreateBioAssetActionDialog(aiRecommendations),
                      icon: const Icon(Icons.add_task),
                      label: Text(_lp('Plan Bioasset Action')),
                    ),
                  ],
                ),
              ),
            ),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _loadBioAssetExecutionTasks(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final tasks = snapshot.data ?? const [];
                if (tasks.isEmpty) {
                  return ListTile(
                    title: Text(_lp('No bioasset execution tasks yet')),
                    subtitle: Text(
                      _lp('Create the first action from AI suggestions above.'),
                    ),
                  );
                }

                return Column(
                  children: tasks.map((task) {
                    final metadata = Map<String, dynamic>.from(
                      (task['metadata'] as Map<String, dynamic>?) ??
                          const <String, dynamic>{},
                    );
                    final status = (task['status'] ?? 'PENDING').toString();
                    final dueDate = DateTime.tryParse(
                      (task['due_date'] ?? '').toString(),
                    );
                    final owner = (metadata['owner'] ?? 'Unassigned')
                        .toString();
                    final outcomeTarget = (metadata['outcome_target'] ?? '')
                        .toString();
                    final outcomeNote = (metadata['outcome_note'] ?? '')
                        .toString();

                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _lp((task['description'] ?? '').toString()),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _taskStatusColor(
                                      status,
                                    ).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    _taskStatusLabel(status),
                                    style: TextStyle(
                                      color: _taskStatusColor(status),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _lp(
                                'Owner: $owner${dueDate == null ? '' : ' • Due ${DateFormat('dd MMM yyyy').format(dueDate)}'}',
                              ),
                            ),
                            if (outcomeTarget.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(_lp('Target: $outcomeTarget')),
                            ],
                            if (outcomeNote.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                _lp('Outcome: $outcomeNote'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                OutlinedButton(
                                  onPressed: status.toUpperCase() == 'PENDING'
                                      ? () async {
                                          await _updateBioAssetExecutionTask(
                                            task: task,
                                            status: 'IN_PROGRESS',
                                          );
                                          if (!mounted) return;
                                          setState(
                                            () => _dashboardFuture =
                                                _loadBundle(),
                                          );
                                        }
                                      : null,
                                  child: Text(_lp('Start')),
                                ),
                                ElevatedButton(
                                  onPressed: status.toUpperCase() == 'COMPLETED'
                                      ? null
                                      : () => _openExecutionOutcomeDialog(task),
                                  child: Text(_lp('Execute + Outcome')),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _loadBioAssetExecutionTasks() async {
    try {
      final rows = await SupabaseService.client
          .from('tasks')
          .select('id,title,description,status,due_date,metadata,created_at')
          .eq('created_by_ai', 'bioasset_assist')
          .order('due_date', ascending: true)
          .limit(20);
      return rows.whereType<Map<String, dynamic>>().toList();
    } catch (_) {}
    return const [];
  }

  Future<void> _createBioAssetExecutionTask({
    required String recommendation,
    required String owner,
    required DateTime dueDate,
    required String outcomeTarget,
  }) async {
    final now = DateTime.now();
    final id = 'bioasset_exec_${now.microsecondsSinceEpoch}';
    final normalizedRecommendation = recommendation.trim();

    final metadata = <String, dynamic>{
      'domain': 'bioasset',
      'owner': owner.trim(),
      'outcome_target': outcomeTarget.trim(),
      'recommendation_text': normalizedRecommendation,
      'created_via': 'bioasset_execution_tracker',
    };

    final priority =
        normalizedRecommendation.toLowerCase().contains('unhealthy') ||
            normalizedRecommendation.toLowerCase().contains('disease')
        ? 'HIGH'
        : 'MEDIUM';

    await SupabaseService.client.from('tasks').insert({
      'id': id,
      'zone_id': 'bioasset_control',
      'title': 'Bioasset AI Action',
      'description': normalizedRecommendation,
      'activity': 'MAINTENANCE',
      'due_date': dueDate.toIso8601String(),
      'priority': priority,
      'status': 'PENDING',
      'created_at': now.toIso8601String(),
      'created_by_ai': 'bioasset_assist',
      'metadata': metadata,
    });
  }

  String _formatBioAssetActionCreateError(Object error) {
    final message = error.toString().toLowerCase();

    if (message.contains('row-level security') ||
        message.contains('permission denied')) {
      return _lp(
        'Could not create bioasset action. Your current account cannot write tasks yet.',
      );
    }

    if (message.contains('tasks') && message.contains('does not exist')) {
      return _lp(
        'Could not create bioasset action. The tasks table is missing in Supabase.',
      );
    }

    return _lp('Could not create bioasset action right now. Please try again.');
  }

  Future<void> _updateBioAssetExecutionTask({
    required Map<String, dynamic> task,
    required String status,
    String? outcomeNote,
  }) async {
    final id = (task['id'] ?? '').toString();
    if (id.isEmpty) return;

    final metadata = Map<String, dynamic>.from(
      (task['metadata'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
    );

    if (outcomeNote != null && outcomeNote.trim().isNotEmpty) {
      metadata['outcome_note'] = outcomeNote.trim();
      metadata['outcome_logged_at'] = DateTime.now().toIso8601String();
    }

    await SupabaseService.client
        .from('tasks')
        .update({'status': status, 'metadata': metadata})
        .eq('id', id);
  }

  Future<bool> _openCreateBioAssetActionDialog(
    List<String> recommendations,
  ) async {
    if (recommendations.isEmpty) return false;

    final result =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return _CreateBioAssetActionDialog(
              recommendations: recommendations,
              localize: _lp,
              formatErrorMessage: _formatBioAssetActionCreateError,
              onCreate:
                  ({
                    required recommendation,
                    required owner,
                    required dueDate,
                    required outcomeTarget,
                  }) {
                    return _createBioAssetExecutionTask(
                      recommendation: recommendation,
                      owner: owner,
                      dueDate: dueDate,
                      outcomeTarget: outcomeTarget,
                    );
                  },
            );
          },
        ) ??
        false;

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_lp('Bioasset action task created.'))),
      );
      setState(() {
        _dashboardFuture = _loadBundle();
      });
    }

    return result;
  }

  Future<void> _openExecutionOutcomeDialog(Map<String, dynamic> task) async {
    final controller = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(_lp('Log Outcome & Mark Executed')),
          content: TextField(
            controller: controller,
            minLines: 2,
            maxLines: 5,
            decoration: InputDecoration(
              labelText: _lp('Outcome Note'),
              hintText: _lp(
                'Example: disease spots dropped from 22 trees to 9 after treatment cycle',
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(_lp('Cancel')),
            ),
            ElevatedButton(
              onPressed: () async {
                await _updateBioAssetExecutionTask(
                  task: task,
                  status: 'COMPLETED',
                  outcomeNote: controller.text,
                );
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext, true);
              },
              child: Text(_lp('Mark Executed')),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_lp('Execution outcome captured.'))),
      );
      setState(() {
        _dashboardFuture = _loadBundle();
      });
    }
  }

  String _taskStatusLabel(String raw) {
    final value = raw.toUpperCase();
    if (value == 'PENDING') return _lp('Pending');
    if (value == 'IN_PROGRESS') return _lp('In Progress');
    if (value == 'REVIEW_PENDING') return _lp('Review Pending');
    if (value == 'COMPLETED') return _lp('Completed');
    if (value == 'CANCELLED') return _lp('Cancelled');
    if (value == 'OVERDUE') return _lp('Overdue');
    return _lp(value);
  }

  Color _taskStatusColor(String raw) {
    final value = raw.toUpperCase();
    if (value == 'COMPLETED') return Colors.green.shade700;
    if (value == 'IN_PROGRESS') return Colors.blue.shade700;
    if (value == 'REVIEW_PENDING') return Colors.purple.shade700;
    if (value == 'CANCELLED' || value == 'OVERDUE') return Colors.red.shade700;
    return Colors.orange.shade800;
  }

  _BioAssetIntelligence _buildBioAssetIntelligence(
    _OwnerDashboardBundle bundle,
  ) {
    final checks = bundle.dailyChecks;
    final now = DateTime.now();
    final last30Start = now.subtract(const Duration(days: 30));
    final prev30Start = now.subtract(const Duration(days: 60));

    final last30 = checks
        .where((check) => check.checkDate.isAfter(last30Start))
        .toList();
    final previous30 = checks
        .where(
          (check) =>
              check.checkDate.isAfter(prev30Start) &&
              !check.checkDate.isAfter(last30Start),
        )
        .toList();

    final structuredGestation = _sumStructuredSignal(checks, 'gestation');
    final structuredNewborn = _sumStructuredSignal(checks, 'newborn');
    final structuredUnhealthyTrees = _sumStructuredSignal(
      checks,
      'unhealthy_trees',
    );
    final structuredPruned = _sumStructuredSignal(checks, 'pruned');
    final structuredSold = _sumStructuredSignal(checks, 'sold');

    final gestationStock = structuredGestation > 0
        ? structuredGestation
        : _keywordStockCount(
            checks: checks,
            keywords: const ['gestation', 'pregnant', 'in-calf', 'in kid'],
          );
    final newbornStock = structuredNewborn > 0
        ? structuredNewborn
        : _keywordStockCount(
            checks: checks,
            keywords: const [
              'newborn',
              'new born',
              'calf',
              'kids born',
              'hatch',
            ],
          );
    final unhealthyTrees = structuredUnhealthyTrees > 0
        ? structuredUnhealthyTrees
        : _keywordStockCount(
            checks: checks,
            keywords: const [
              'unhealthy tree',
              'tree disease',
              'pest',
              'wilt',
              'blight',
              'yellow leaves',
            ],
          );
    final pruned = structuredPruned > 0
        ? structuredPruned
        : _keywordStockCount(
            checks: checks,
            keywords: const ['pruned', 'pruning', 'trimmed'],
          );
    final sold = structuredSold > 0
        ? structuredSold
        : _keywordStockCount(
            checks: checks,
            keywords: const ['sold', 'sale', 'marketed', 'offloaded'],
          );

    final delta = last30.length - previous30.length;
    final deltaLabel = delta == 0
        ? 'flat vs prev 30d'
        : '${delta > 0 ? '+' : ''}$delta vs prev 30d';

    return _BioAssetIntelligence(
      gestationStock: gestationStock,
      newbornStock: newbornStock,
      unhealthyTrees: unhealthyTrees,
      pruned: pruned,
      sold: sold,
      last30DaysChecks: last30.length,
      previous30DaysChecks: previous30.length,
      last30DayCheckDeltaLabel: deltaLabel,
    );
  }

  int _sumStructuredSignal(List<DailyAssetCheck> checks, String key) {
    var total = 0;
    for (final check in checks) {
      final observations = check.observations;
      final stockSignals = observations['stock_signals'];
      if (stockSignals is! Map<String, dynamic>) continue;
      final raw = stockSignals[key];
      if (raw == null) continue;
      if (raw is int) {
        total += raw;
      } else if (raw is num) {
        total += raw.toInt();
      } else {
        total += int.tryParse(raw.toString()) ?? 0;
      }
    }
    return total;
  }

  List<String> _buildBioAssetRecommendations({
    required _OwnerDashboardBundle bundle,
    required _BioAssetIntelligence intelligence,
  }) {
    final recommendations = <String>[];

    if (intelligence.gestationStock > 0 && intelligence.newbornStock == 0) {
      recommendations.add(
        'Set up a gestation watchlist and prepare birthing kits; historical checks show gestation activity but no newborn confirmations yet.',
      );
    }

    if (intelligence.unhealthyTrees >= 3) {
      recommendations.add(
        'Prioritize orchard triage this week: isolate unhealthy trees, run targeted pest/disease treatment, and log treatment evidence per zone for trend tracking.',
      );
    }

    if (intelligence.pruned == 0 &&
        (bundle.bioSummary?.activeAssets ?? 0) > 0) {
      recommendations.add(
        'Schedule preventive pruning cycles by orchard block; best practice is to prune before peak disease pressure and record outcomes in daily checks.',
      );
    }

    if (intelligence.sold > intelligence.newbornStock &&
        intelligence.gestationStock > 0) {
      recommendations.add(
        'Sales are outpacing replenishment signals. Protect breeding stock and plan phased restocking to maintain long-term asset value.',
      );
    }

    if (intelligence.last30DaysChecks < 10) {
      recommendations.add(
        'Increase check frequency to at least 3-4 logs per week per active zone; stronger historical coverage improves AI confidence and anomaly detection.',
      );
    }

    final topAssist = bundle.assist.recommendations.isEmpty
        ? null
        : bundle.assist.recommendations.first;
    if (topAssist != null) {
      recommendations.add(
        'Carry over current AI priority: ${topAssist.title}. Action: ${topAssist.action}',
      );
    }

    if (recommendations.isEmpty) {
      recommendations.add(
        'Bioasset signals look stable. Continue weekly health checks, monthly valuation updates, and evidence logging for pricing and productivity optimization.',
      );
    }

    return recommendations;
  }

  int _keywordStockCount({
    required List<DailyAssetCheck> checks,
    required List<String> keywords,
  }) {
    var total = 0;

    for (final check in checks) {
      final text = _checkNarrative(check);
      var matched = false;
      for (final keyword in keywords) {
        if (!text.contains(keyword)) continue;
        final qty = _extractQuantityNearKeyword(text, keyword);
        total += qty > 0 ? qty : 1;
        matched = true;
        break;
      }
      if (!matched) {
        continue;
      }
    }

    return total;
  }

  String _checkNarrative(DailyAssetCheck check) {
    final notes = (check.observations['notes'] ?? '').toString().toLowerCase();
    final alerts = check.alerts
        .map((item) => item.toString().toLowerCase())
        .join(' ');
    return '$notes $alerts ${check.checklistType.toLowerCase()}';
  }

  int _extractQuantityNearKeyword(String text, String keyword) {
    final escaped = RegExp.escape(keyword);
    final keywordFirst = RegExp('$escaped\\s*[:=-]?\\s*(\\d+)');
    final numberFirst = RegExp('(\\d+)\\s+[^\\n]{0,28}$escaped');

    var sum = 0;
    for (final match in keywordFirst.allMatches(text)) {
      sum += int.tryParse(match.group(1) ?? '') ?? 0;
    }
    for (final match in numberFirst.allMatches(text)) {
      sum += int.tryParse(match.group(1) ?? '') ?? 0;
    }
    return sum;
  }

  String _bioLabel(String value) {
    if (value.isEmpty) return value;
    final cleaned = value.replaceAll('_', ' ').trim();
    return cleaned
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  Widget _metricTile(String title, String value, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.09),
            blurRadius: 7,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontFamily: 'Georgia',
                fontSize: 15.5,
                color: Color(0xFF2E3D34),
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16.5,
              color: color,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = Provider.of<LocalizationService>(context);
    final auth = Provider.of<AuthService>(context, listen: false);

    return DashboardHubScaffold(
      title: loc.t('owner_home'),
      onRefresh: () {
        setState(() {
          _dashboardFuture = _loadBundle();
        });
      },
      onLogout: () async {
        await auth.signOut();
        if (!context.mounted) return;
        Navigator.pushReplacementNamed(context, '/');
      },
      child: FutureBuilder<_OwnerDashboardBundle>(
        future: _dashboardFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const DashboardHubLoadingState(cardCount: 5);
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return Center(child: Text(_lp('Could not load owner dashboard')));
          }

          final bundle = snapshot.data!;
          final finance = bundle.finance;
          final negativeZones = finance.zoneProfitability
              .where((zone) => !zone.profitable)
              .length;
          final proposedRecommendations =
              bundle.assist.recommendationStatusCounts['proposed'] ?? 0;
          final executedRecommendations =
              bundle.assist.recommendationStatusCounts['executed'] ?? 0;
          final activeAssets = bundle.bioSummary?.activeAssets ?? 0;
          final overBudget = finance.overview.budgetVariance > 0;

          final cards = [
            HubSummaryCard(
              icon: Icons.account_balance_wallet,
              title: _lp('Financial Snapshot'),
              primaryValue: _tzs(finance.overview.monthNet),
              secondaryValue: _lp(
                'Income ${_tzs(finance.overview.monthIncome)} • Expense ${_tzs(finance.overview.monthExpenses)}',
              ),
              urgencyLabel: _lp(
                finance.overview.monthNet < 0
                    ? 'High attention'
                    : overBudget
                    ? 'Watch closely'
                    : 'Stable',
              ),
              nextStep: _lp(
                finance.overview.monthNet < 0
                    ? 'Open finance and inspect the biggest cost overruns first.'
                    : 'Open finance and compare revenue sources against category spend.',
              ),
              color: finance.overview.monthNet < 0
                  ? Colors.red.shade700
                  : Colors.green.shade700,
              progress: finance.overview.monthNet < 0
                  ? 0.95
                  : overBudget
                  ? 0.72
                  : 0.34,
              nextStepPriority: 2,
              actionLabel: _lp('Open Finance'),
              onTap: () => _openFinanceDetail(bundle),
            ),
            HubSummaryCard(
              icon: Icons.map,
              title: _lp('Zone Profitability'),
              primaryValue: _lp('${finance.zoneProfitability.length} zones'),
              secondaryValue: _lp(
                'Top today: ${bundle.zoneCashCowRanking.daily.topZone?.zoneName ?? 'N/A'} • $negativeZones under target',
              ),
              urgencyLabel: _lp(
                negativeZones > 0 ? 'Needs attention' : 'Healthy trend',
              ),
              nextStep: _lp(
                negativeZones > 0
                    ? 'Open zone profitability and review the weakest zone first.'
                    : 'Open zone profitability and compare the top performer across daily, weekly, and monthly windows.',
              ),
              color: Colors.brown.shade700,
              progress: negativeZones > 0 ? 0.83 : 0.36,
              nextStepPriority: 3,
              actionLabel: _lp('Review Zones'),
              onTap: () => _openProfitabilityDetail(bundle),
            ),
            HubSummaryCard(
              icon: Icons.inventory_2,
              title: _lp('Asset Valuation'),
              primaryValue: _tzs(bundle.finance.biologicalAssets.totalValue),
              secondaryValue: _lp(
                '$activeAssets active assets • ${bundle.bioCategories.length} categories tracked',
              ),
              urgencyLabel: _lp(
                activeAssets == 0 ? 'Record needed' : 'Monitor condition',
              ),
              nextStep: _lp(
                activeAssets == 0
                    ? 'Open bioassets and add the first asset records and daily checks.'
                    : 'Open bioassets and inspect the zones with missing checks or stale evidence.',
              ),
              color: Colors.cyan.shade700,
              progress: activeAssets == 0 ? 0.88 : 0.46,
              nextStepPriority: 5,
              actionLabel: _lp('Open Bioassets'),
              onTap: () => _openBioassetDetail(bundle),
            ),
            HubSummaryCard(
              icon: Icons.auto_graph,
              title: _lp('AI Insights'),
              primaryValue: '${bundle.assist.readinessScore}/100',
              secondaryValue: _lp(
                '$executedRecommendations executed • $proposedRecommendations proposed',
              ),
              urgencyLabel: _lp(
                proposedRecommendations > 0
                    ? 'Decision required'
                    : bundle.assist.readinessScore < 60
                    ? 'Below target'
                    : 'On track',
              ),
              nextStep: _lp(
                proposedRecommendations > 0
                    ? 'Open AI insights and convert the top suggestion into a task.'
                    : 'Open AI insights and review what is lowering readiness.',
              ),
              color: Colors.indigo.shade700,
              progress: proposedRecommendations > 0
                  ? 0.9
                  : bundle.assist.readinessScore < 60
                  ? 0.68
                  : 0.38,
              nextStepPriority: 1,
              actionLabel: _lp('Open AI'),
              onTap: () => _openAssistDetail(bundle),
            ),
            HubSummaryCard(
              icon: Icons.admin_panel_settings,
              title: _lp('Team Admin'),
              primaryValue: _lp('Role assignments'),
              secondaryValue: _lp('Assign manager and staff safely'),
              urgencyLabel: _lp('Owner action'),
              nextStep: _lp(
                'Open team admin and assign role changes through secure approval rules.',
              ),
              color: Colors.deepOrange.shade700,
              progress: 0.42,
              nextStepPriority: 4,
              actionLabel: _lp('Manage Team'),
              onTap: _openTeamAdminDialog,
            ),
            HubSummaryCard(
              icon: Icons.summarize,
              title: _lp('Reports'),
              primaryValue: _lp(
                '${bundle.dailyChecks.length} recent field logs',
              ),
              secondaryValue: _lp(
                'Daily, weekly, and monthly summaries are ready',
              ),
              urgencyLabel: _lp('Routine review'),
              nextStep: _lp(
                'Open reports and export or share the latest summary with leadership.',
              ),
              color: Colors.teal.shade700,
              progress: 0.32,
              nextStepPriority: 6,
              actionLabel: _lp('Open Reports'),
              onTap: () => _openReportsDetail(bundle, loc),
            ),
            HubSummaryCard(
              icon: Icons.document_scanner,
              title: _lp('Knowledge Hub'),
              primaryValue: _lp('AI and field insights'),
              secondaryValue: _lp('Browse recent knowledge reports and lessons learned'),
              urgencyLabel: _lp('Evidence sharing'),
              nextStep: _lp('Open knowledge reports and review AI-captured field insights.'),
              color: Colors.green.shade700,
              progress: 0.58,
              nextStepPriority: 7,
              actionLabel: _lp('View Reports'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const KnowledgeReportListScreen(),
                  ),
                );
              },
            ),
          ];

          return HubSummaryGrid(cards: cards);
        },
      ),
    );
  }
}

enum _ZoneProfitabilitySortField { zone, revenue, expenses, net, roi }

class _ZoneProfitabilityDetailScreen extends StatefulWidget {
  const _ZoneProfitabilityDetailScreen({
    required this.ranking,
    required this.localize,
    required this.formatCurrency,
    required this.comparisonGraphBuilder,
  });

  final ZoneCashCowRanking ranking;
  final String Function(String value) localize;
  final String Function(double value) formatCurrency;
  final Widget Function(List<ZoneFinancialSnapshot> zones)
  comparisonGraphBuilder;

  @override
  State<_ZoneProfitabilityDetailScreen> createState() =>
      _ZoneProfitabilityDetailScreenState();
}

class _ZoneProfitabilityDetailScreenState
    extends State<_ZoneProfitabilityDetailScreen> {
  _ZoneProfitabilitySortField _sortField = _ZoneProfitabilitySortField.net;
  bool _sortAscending = false;

  void _handleSort(_ZoneProfitabilitySortField field) {
    setState(() {
      if (_sortField == field) {
        _sortAscending = !_sortAscending;
        return;
      }

      _sortField = field;
      _sortAscending = field == _ZoneProfitabilitySortField.zone;
    });
  }

  List<ZoneFinancialSnapshot> _sortedZones(List<ZoneFinancialSnapshot> zones) {
    final sorted = [...zones];
    sorted.sort((left, right) {
      final comparison = switch (_sortField) {
        _ZoneProfitabilitySortField.zone =>
          left.zoneName.toLowerCase().compareTo(right.zoneName.toLowerCase()),
        _ZoneProfitabilitySortField.revenue => left.revenue.compareTo(
          right.revenue,
        ),
        _ZoneProfitabilitySortField.expenses => left.expenses.compareTo(
          right.expenses,
        ),
        _ZoneProfitabilitySortField.net => left.net.compareTo(right.net),
        _ZoneProfitabilitySortField.roi => left.roiPercent.compareTo(
          right.roiPercent,
        ),
      };

      return _sortAscending ? comparison : -comparison;
    });
    return sorted;
  }

  int _sortColumnIndex() {
    return switch (_sortField) {
      _ZoneProfitabilitySortField.zone => 0,
      _ZoneProfitabilitySortField.revenue => 1,
      _ZoneProfitabilitySortField.expenses => 2,
      _ZoneProfitabilitySortField.net => 3,
      _ZoneProfitabilitySortField.roi => 4,
    };
  }

  @override
  Widget build(BuildContext context) {
    final windows = [
      widget.ranking.daily,
      widget.ranking.weekly,
      widget.ranking.monthly,
    ];

    return DefaultTabController(
      length: windows.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.localize('Zone Profitability')),
          elevation: 0,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0F4F2C), Color(0xFF2F7D32)],
              ),
            ),
          ),
          bottom: TabBar(
            tabs: [
              for (final window in windows)
                Tab(text: widget.localize(window.label)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            for (final window in windows)
              _ZoneProfitabilityWindowView(
                window: window,
                localize: widget.localize,
                formatCurrency: widget.formatCurrency,
                comparisonGraphBuilder: widget.comparisonGraphBuilder,
                sortedZones: _sortedZones(window.rankedZones),
                sortColumnIndex: _sortColumnIndex(),
                sortAscending: _sortAscending,
                onSort: _handleSort,
              ),
          ],
        ),
      ),
    );
  }
}

class _ZoneProfitabilityWindowView extends StatelessWidget {
  const _ZoneProfitabilityWindowView({
    required this.window,
    required this.localize,
    required this.formatCurrency,
    required this.comparisonGraphBuilder,
    required this.sortedZones,
    required this.sortColumnIndex,
    required this.sortAscending,
    required this.onSort,
  });

  final ZoneCashCowWindow window;
  final String Function(String value) localize;
  final String Function(double value) formatCurrency;
  final Widget Function(List<ZoneFinancialSnapshot> zones)
  comparisonGraphBuilder;
  final List<ZoneFinancialSnapshot> sortedZones;
  final int sortColumnIndex;
  final bool sortAscending;
  final ValueChanged<_ZoneProfitabilitySortField> onSort;

  @override
  Widget build(BuildContext context) {
    if (window.rankedZones.isEmpty) {
      return Center(child: Text(localize('No data in this window')));
    }

    final bestZone = window.rankedZones.reduce(
      (left, right) => left.net >= right.net ? left : right,
    );
    final weakestZone = window.rankedZones.reduce(
      (left, right) => left.net <= right.net ? left : right,
    );
    final profitableZoneCount = window.rankedZones
        .where((zone) => zone.profitable)
        .length;
    final profitableColor = profitableZoneCount == 0
        ? Colors.red.shade700
        : profitableZoneCount == window.rankedZones.length
        ? Colors.green.shade700
        : Colors.orange.shade700;
    final compactSummary = MediaQuery.sizeOf(context).width < 760;
    final bestZoneCard = _ZoneProfitabilitySummaryTile(
      icon: Icons.emoji_events_rounded,
      title: localize('Best zone'),
      value: bestZone.zoneName,
      subtitle:
          '${localize('Net')} ${formatCurrency(bestZone.net)} • ${localize('ROI %')} ${bestZone.roiPercent.toStringAsFixed(1)}%',
      detail: localize('Positive net and ROI keep this zone ahead.'),
      color: Colors.green.shade700,
    );
    final weakestZoneCard = _ZoneProfitabilitySummaryTile(
      icon: Icons.trending_down_rounded,
      title: localize('Weakest zone'),
      value: weakestZone.zoneName,
      subtitle:
          '${localize('Net')} ${formatCurrency(weakestZone.net)} • ${localize('ROI %')} ${weakestZone.roiPercent.toStringAsFixed(1)}%',
      detail:
          '${localize('Reduce expenses or lift sellable output in')} ${weakestZone.zoneName}.',
      color: Colors.red.shade700,
    );
    final profitableZonesCard = _ZoneProfitabilitySummaryTile(
      icon: Icons.paid_rounded,
      title: localize('Profitable zones'),
      value: '$profitableZoneCount',
      subtitle:
          '$profitableZoneCount ${localize('of')} ${window.rankedZones.length} ${localize('zones are profitable.')}',
      detail: localize(
        'Profitability improves when revenue stays above expenses and ROI stays positive.',
      ),
      color: profitableColor,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
      children: [
        Text(
          localize('${window.label} Cash-Cow Ranking'),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1A2F22),
          ),
        ),
        const SizedBox(height: 12),
        if (compactSummary) ...[
          bestZoneCard,
          const SizedBox(height: 12),
          weakestZoneCard,
          const SizedBox(height: 12),
          profitableZonesCard,
        ] else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: bestZoneCard),
              const SizedBox(width: 12),
              Expanded(child: weakestZoneCard),
              const SizedBox(width: 12),
              Expanded(child: profitableZonesCard),
            ],
          ),
        const SizedBox(height: 14),
        comparisonGraphBuilder(window.rankedZones),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Material(
            color: Colors.white,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 760),
                child: PaginatedDataTable(
                  header: Text(
                    localize('Cash-Cow Ranking'),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  showFirstLastButtons:
                      sortedZones.length >
                      _defaultRowsPerPage(sortedZones.length),
                  rowsPerPage: _defaultRowsPerPage(sortedZones.length),
                  availableRowsPerPage: _rowsPerPageOptions(sortedZones.length),
                  sortColumnIndex: sortColumnIndex,
                  sortAscending: sortAscending,
                  columnSpacing: 20,
                  showCheckboxColumn: false,
                  columns: [
                    DataColumn(
                      label: Text(localize('Zone')),
                      onSort: (_, _) =>
                          onSort(_ZoneProfitabilitySortField.zone),
                    ),
                    DataColumn(
                      label: Text(localize('Revenue')),
                      numeric: true,
                      onSort: (_, _) =>
                          onSort(_ZoneProfitabilitySortField.revenue),
                    ),
                    DataColumn(
                      label: Text(localize('Expenses')),
                      numeric: true,
                      onSort: (_, _) =>
                          onSort(_ZoneProfitabilitySortField.expenses),
                    ),
                    DataColumn(
                      label: Text(localize('Net')),
                      numeric: true,
                      onSort: (_, _) => onSort(_ZoneProfitabilitySortField.net),
                    ),
                    DataColumn(
                      label: Text(localize('ROI %')),
                      numeric: true,
                      onSort: (_, _) => onSort(_ZoneProfitabilitySortField.roi),
                    ),
                  ],
                  source: _ZoneProfitabilityTableSource(
                    zones: sortedZones,
                    formatCurrency: formatCurrency,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  int _defaultRowsPerPage(int rowCount) {
    if (rowCount <= 5) {
      return rowCount;
    }
    if (rowCount <= 10) {
      return 5;
    }
    return 10;
  }

  List<int> _rowsPerPageOptions(int rowCount) {
    if (rowCount <= 5) {
      return [rowCount];
    }

    final options = <int>{5};
    if (rowCount > 5) {
      options.add(rowCount < 10 ? rowCount : 10);
    }
    if (rowCount > 10) {
      options.add(rowCount < 20 ? rowCount : 20);
    }

    final sortedOptions = options.toList()..sort();
    return sortedOptions;
  }
}

class _ZoneProfitabilitySummaryTile extends StatelessWidget {
  const _ZoneProfitabilitySummaryTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
    this.subtitle,
    this.detail,
  });

  final IconData icon;
  final String title;
  final String value;
  final String? subtitle;
  final String? detail;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF6A7F70),
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Color(0xFF183126),
              height: 1.15,
            ),
          ),
          if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
          if (detail != null && detail!.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              detail!,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.8,
                fontWeight: FontWeight.w600,
                color: Color(0xFF3E5447),
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ZoneProfitabilityTableSource extends DataTableSource {
  _ZoneProfitabilityTableSource({
    required this.zones,
    required this.formatCurrency,
  });

  final List<ZoneFinancialSnapshot> zones;
  final String Function(double value) formatCurrency;

  @override
  DataRow? getRow(int index) {
    if (index >= zones.length) {
      return null;
    }

    final zone = zones[index];
    final netColor = zone.net < 0 ? Colors.red.shade700 : Colors.green.shade700;

    return DataRow.byIndex(
      index: index,
      cells: [
        DataCell(
          Text(
            zone.zoneName,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        DataCell(Text(formatCurrency(zone.revenue))),
        DataCell(Text(formatCurrency(zone.expenses))),
        DataCell(
          Text(
            formatCurrency(zone.net),
            style: TextStyle(fontWeight: FontWeight.w800, color: netColor),
          ),
        ),
        DataCell(Text('${zone.roiPercent.toStringAsFixed(1)}%')),
      ],
    );
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => zones.length;

  @override
  int get selectedRowCount => 0;
}

typedef _BioAssetActionCreateCallback =
    Future<void> Function({
      required String recommendation,
      required String owner,
      required DateTime dueDate,
      required String outcomeTarget,
    });

class _CreateBioAssetActionDialog extends StatefulWidget {
  const _CreateBioAssetActionDialog({
    required this.recommendations,
    required this.localize,
    required this.formatErrorMessage,
    required this.onCreate,
  });

  final List<String> recommendations;
  final String Function(String value) localize;
  final String Function(Object error) formatErrorMessage;
  final _BioAssetActionCreateCallback onCreate;

  @override
  State<_CreateBioAssetActionDialog> createState() =>
      _CreateBioAssetActionDialogState();
}

class _CreateBioAssetActionDialogState
    extends State<_CreateBioAssetActionDialog> {
  late final TextEditingController _ownerController;
  late final TextEditingController _outcomeController;
  late String _selectedRecommendation;
  late DateTime _dueDate;

  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedRecommendation = widget.recommendations.first;
    _dueDate = DateTime.now().add(const Duration(days: 7));
    _ownerController = TextEditingController(text: widget.localize('Owner'));
    _outcomeController = TextEditingController();
  }

  @override
  void dispose() {
    _ownerController.dispose();
    _outcomeController.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked == null || !mounted) return;
    setState(() => _dueDate = picked);
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    final owner = _ownerController.text.trim();
    if (owner.isEmpty) {
      setState(() {
        _errorMessage = widget.localize('Owner / Assignee is required.');
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await widget.onCreate(
        recommendation: _selectedRecommendation,
        owner: owner,
        dueDate: _dueDate,
        outcomeTarget: _outcomeController.text.trim(),
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      debugPrint('Create bioasset action failed: $error');
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = widget.formatErrorMessage(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.localize('Create Bioasset Action')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _selectedRecommendation,
              items: widget.recommendations
                  .map(
                    (item) => DropdownMenuItem(
                      value: item,
                      child: Text(
                        widget.localize(item),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: _isSubmitting
                  ? null
                  : (value) {
                      if (value == null) return;
                      setState(() => _selectedRecommendation = value);
                    },
              decoration: InputDecoration(
                labelText: widget.localize('Recommendation'),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _ownerController,
              enabled: !_isSubmitting,
              decoration: InputDecoration(
                labelText: widget.localize('Owner / Assignee'),
              ),
            ),
            const SizedBox(height: 10),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(widget.localize('Due Date')),
              subtitle: Text(DateFormat('dd MMM yyyy').format(_dueDate)),
              trailing: IconButton(
                icon: const Icon(Icons.calendar_today),
                onPressed: _isSubmitting ? null : _pickDueDate,
              ),
            ),
            TextField(
              controller: _outcomeController,
              enabled: !_isSubmitting,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: widget.localize('Expected Outcome'),
                hintText: widget.localize(
                  'Example: reduce unhealthy trees by 30% in 14 days',
                ),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting
              ? null
              : () => Navigator.of(context).pop(false),
          child: Text(widget.localize('Cancel')),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(widget.localize('Create Action')),
        ),
      ],
    );
  }
}

class _OwnerDashboardBundle {
  final OwnerFinanceDashboardData finance;
  final ZoneCashCowRanking zoneCashCowRanking;
  final OperationsAssistSnapshot assist;
  final List<BreedRecommendationResult> breedRecommendations;
  final BiologicalAssetDashboardSummary? bioSummary;
  final List<BiologicalAssetCategorySummary> bioCategories;
  final List<DailyAssetCheck> dailyChecks;
  final List<BiologicalAssetValueRow> bioAssetRows;
  final List<ExternalPartnerEntry> pendingExternalEntries;
  final Map<String, String> assetZoneNames;
  final List<Map<String, dynamic>> bioAssetExecutionTaskRows;

  const _OwnerDashboardBundle({
    required this.finance,
    required this.zoneCashCowRanking,
    required this.assist,
    required this.breedRecommendations,
    required this.bioSummary,
    required this.bioCategories,
    required this.dailyChecks,
    required this.bioAssetRows,
    required this.pendingExternalEntries,
    required this.assetZoneNames,
    required this.bioAssetExecutionTaskRows,
  });
}

class _AssistQuestionCard extends StatefulWidget {
  const _AssistQuestionCard({
    required this.localize,
    required this.questionContext,
    required this.onActionPressed,
  });

  final String Function(String value) localize;
  final OperationsAssistQuestionContext questionContext;
  final Future<bool> Function(OperationsAssistQuestionResponse response)
  onActionPressed;

  @override
  State<_AssistQuestionCard> createState() => _AssistQuestionCardState();
}

class _AssistQuestionCardState extends State<_AssistQuestionCard> {
  final TextEditingController _controller = TextEditingController();
  OperationsAssistQuestionResponse? _response;
  List<OperationsAssistQuestionHistoryEntry> _history = const [];
  String? _activeHistoryId;
  bool _isLoadingHistory = true;
  bool _isSavingHistory = false;
  bool _isRunningAction = false;

  static const List<String> _promptSuggestions = [
    'Why did readiness drop this week?',
    'Which livestock group needs action first?',
    'What changed in feed or medicine?',
    'What should I review today?',
  ];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final history =
        await OperationsAssistQuestionHistoryService.loadRecentHistory();
    if (!mounted) {
      return;
    }

    setState(() {
      _history = history;
      _isLoadingHistory = false;
    });
  }

  void _upsertHistoryEntry(OperationsAssistQuestionHistoryEntry entry) {
    final updated = [entry, ..._history.where((item) => item.id != entry.id)];
    _history = updated.take(6).toList();
  }

  Future<void> _submitQuestion([String? seededQuestion]) async {
    final question = (seededQuestion ?? _controller.text).trim();
    if (question.isEmpty) {
      setState(() {
        _response = OperationsAssistQuestionService.answerQuestion(
          question: '',
          context: widget.questionContext,
        );
        _activeHistoryId = null;
      });
      return;
    }

    _controller.value = TextEditingValue(
      text: question,
      selection: TextSelection.collapsed(offset: question.length),
    );

    final response = OperationsAssistQuestionService.answerQuestion(
      question: question,
      context: widget.questionContext,
    );

    setState(() {
      _response = response;
      _activeHistoryId = null;
      _isSavingHistory = true;
    });

    final historyEntry =
        await OperationsAssistQuestionHistoryService.recordQuestion(
          question: question,
          response: response,
        );
    if (!mounted) {
      return;
    }

    setState(() {
      _isSavingHistory = false;
      if (historyEntry != null) {
        _activeHistoryId = historyEntry.id;
        _upsertHistoryEntry(historyEntry);
      }
    });
  }

  Future<void> _runAction() async {
    final response = _response;
    if (response == null || _isRunningAction || _isSavingHistory) {
      return;
    }

    setState(() => _isRunningAction = true);
    try {
      final actionSucceeded = await widget.onActionPressed(response);
      if (actionSucceeded && _activeHistoryId != null) {
        final updatedEntry =
            await OperationsAssistQuestionHistoryService.recordFollowUpAction(
              historyId: _activeHistoryId!,
              response: response,
              actionLabel: response.actionLabel,
            );
        if (mounted && updatedEntry != null) {
          setState(() {
            _upsertHistoryEntry(updatedEntry);
          });
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isRunningAction = false);
      }
    }
  }

  String _topicLabel(String topicKey) {
    switch (topicKey) {
      case 'readiness':
        return widget.localize('Readiness');
      case 'livestock':
        return widget.localize('Livestock');
      case 'inventory':
        return widget.localize('Inventory');
      case 'health':
        return widget.localize('Health');
      case 'workload':
        return widget.localize('Workload');
      case 'verification':
        return widget.localize('Verification');
      case 'logs':
        return widget.localize('Logs');
      default:
        return widget.localize('General');
    }
  }

  Widget _buildHistoryItem(OperationsAssistQuestionHistoryEntry entry) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.blueGrey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blueGrey.shade50,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        _topicLabel(entry.topicKey),
                        style: TextStyle(
                          color: Colors.blueGrey.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        entry.confidenceLabel,
                        style: TextStyle(
                          color: Colors.green.shade800,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                DateFormat('dd MMM • HH:mm').format(entry.askedAt),
                style: TextStyle(color: Colors.blueGrey.shade600),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            entry.question,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            entry.answer,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.blueGrey.shade800, height: 1.35),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  entry.suggestedActionLabel,
                  style: TextStyle(
                    color: Colors.orange.shade900,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (entry.hasSavedFollowUp)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    widget.localize(
                      '${entry.followUpActionLabel} saved ${entry.followUpTakenAt == null ? '' : '• ${DateFormat('dd MMM').format(entry.followUpTakenAt!)}'}',
                    ),
                    style: TextStyle(
                      color: Colors.green.shade800,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _actionIcon(OperationsAssistQuestionActionType actionType) {
    switch (actionType) {
      case OperationsAssistQuestionActionType.createTask:
        return Icons.add_task;
      case OperationsAssistQuestionActionType.openReports:
        return Icons.summarize;
      case OperationsAssistQuestionActionType.openForecast:
        return Icons.timeline;
      case OperationsAssistQuestionActionType.openBreedRecommendations:
        return Icons.pets;
      case OperationsAssistQuestionActionType.reviewVerificationQueue:
        return Icons.fact_check;
    }
  }

  @override
  Widget build(BuildContext context) {
    final response = _response;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.blueGrey.shade100),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.smart_toy_outlined,
                    color: Colors.blueGrey.shade700,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.localize('Ask Farm Assistant'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.localize(
                          'Ask about readiness, livestock, feed, health, workload, verification, or recent logs.',
                        ),
                        style: TextStyle(color: Colors.blueGrey.shade700),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _controller,
              minLines: 1,
              maxLines: 3,
              onSubmitted: (_) => _submitQuestion(),
              decoration: InputDecoration(
                hintText: widget.localize('Why did readiness drop this week?'),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                suffixIcon: IconButton(
                  onPressed: _submitQuestion,
                  icon: const Icon(Icons.send),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _promptSuggestions.map((prompt) {
                return ActionChip(
                  label: Text(widget.localize(prompt)),
                  onPressed: () => _submitQuestion(prompt),
                );
              }).toList(),
            ),
            if (_isLoadingHistory) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.localize('Loading saved question history...'),
                    ),
                  ),
                ],
              ),
            ] else if (_history.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(
                widget.localize('Recent Questions'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              ..._history.take(4).map(_buildHistoryItem),
            ],
            if (response != null) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.blueGrey.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.blueGrey.shade100),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        return Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: constraints.maxWidth,
                              ),
                              child: Text(
                                widget.localize('Assistant Answer'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: Colors.blueGrey.shade100,
                                ),
                              ),
                              child: Text(
                                response.confidenceLabel,
                                style: TextStyle(
                                  color: Colors.blueGrey.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    Text(response.answer, style: const TextStyle(height: 1.4)),
                    if (response.evidence.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      ...response.evidence.map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Icon(
                                  Icons.circle,
                                  size: 8,
                                  color: Colors.blueGrey.shade400,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  item,
                                  style: TextStyle(
                                    color: Colors.blueGrey.shade800,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: _isRunningAction || _isSavingHistory
                          ? null
                          : _runAction,
                      icon: _isRunningAction
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(_actionIcon(response.actionType)),
                      label: Text(response.actionLabel),
                    ),
                    if (_isSavingHistory) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const SizedBox(
                            height: 14,
                            width: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.localize(
                                'Saving question to your audit history...',
                              ),
                              style: TextStyle(color: Colors.blueGrey.shade700),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BioAssetIntelligence {
  final int gestationStock;
  final int newbornStock;
  final int unhealthyTrees;
  final int pruned;
  final int sold;
  final int last30DaysChecks;
  final int previous30DaysChecks;
  final String last30DayCheckDeltaLabel;

  const _BioAssetIntelligence({
    required this.gestationStock,
    required this.newbornStock,
    required this.unhealthyTrees,
    required this.pruned,
    required this.sold,
    required this.last30DaysChecks,
    required this.previous30DaysChecks,
    required this.last30DayCheckDeltaLabel,
  });
}

class _OwnerForecastSnapshot {
  final double income30;
  final double income60;
  final double income90;
  final double expense30;
  final double expense60;
  final double expense90;
  final double net30;
  final double net60;
  final double net90;
  final int births30;
  final int births60;
  final int births90;
  final int sales30;
  final int sales60;
  final int sales90;
  final int riskPressureScore;
  final int executionReadinessScore;
  final List<String> focusActions;

  const _OwnerForecastSnapshot({
    required this.income30,
    required this.income60,
    required this.income90,
    required this.expense30,
    required this.expense60,
    required this.expense90,
    required this.net30,
    required this.net60,
    required this.net90,
    required this.births30,
    required this.births60,
    required this.births90,
    required this.sales30,
    required this.sales60,
    required this.sales90,
    required this.riskPressureScore,
    required this.executionReadinessScore,
    required this.focusActions,
  });
}
