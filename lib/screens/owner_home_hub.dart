import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/external_partner_entry.dart';
import '../legacy_content.dart';
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
import '../services/localization_service.dart';
import '../services/monthly_report_service.dart';
import '../services/operations_assist_service.dart';
import '../services/owner_finance_service.dart';
import '../services/report_export_service.dart';
import 'dashboard_hub_scaffold.dart';

class OwnerHome extends StatefulWidget {
  const OwnerHome({super.key});

  @override
  State<OwnerHome> createState() => _OwnerHomeState();
}

class _OwnerHomeState extends State<OwnerHome> {
  static const int _fullTimeTeams = 4;
  static const double _monthlyPayPerTeamTzs = 100000;

  late Future<_OwnerDashboardBundle> _dashboardFuture;

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
      ExternalPartnerService.getEntries(pendingOnly: true, limit: 30),
    ]);

    final breedRecommendations = (results[3] as List<BreedRecommendationResult>);

    return _OwnerDashboardBundle(
      finance: results[0] as OwnerFinanceDashboardData,
      zoneCashCowRanking: results[1] as ZoneCashCowRanking,
      assist: results[2] as OperationsAssistSnapshot,
      breedRecommendations: breedRecommendations,
      bioSummary: results[4] as BiologicalAssetDashboardSummary?,
      bioCategories: results[5] as List<BiologicalAssetCategorySummary>,
      dailyChecks: results[6] as List<DailyAssetCheck>,
      pendingExternalEntries: results[7] as List<ExternalPartnerEntry>,
    );
  }

  double _monthlyPayrollBaselineTzs() => _fullTimeTeams * _monthlyPayPerTeamTzs;

  List<DailyAssetCheck> _checksForPeriod({
    required List<DailyAssetCheck> checks,
    required String periodType,
    required DateTime now,
  }) {
    if (periodType == 'daily') {
      return checks.where((check) {
        final date = check.checkDate;
        return date.year == now.year && date.month == now.month && date.day == now.day;
      }).toList();
    }

    if (periodType == 'weekly') {
      final start = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
      final end = start.add(const Duration(days: 7));
      return checks.where((check) {
        final date = DateTime(check.checkDate.year, check.checkDate.month, check.checkDate.day);
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

  Future<void> _shareToWhatsApp(String text, LocalizationService loc) async {
    final encoded = Uri.encodeComponent(text);
    final whatsappUri = Uri.parse('whatsapp://send?text=$encoded');
    final fallbackUri = Uri.parse('https://wa.me/?text=$encoded');

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

  Future<void> _copyCsv(PeriodReportDocument report, LocalizationService loc) async {
    await Clipboard.setData(ClipboardData(text: report.csvContent));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(loc.t('owner_monthly_csv_copied'))),
    );
  }

  Future<void> _sharePdf(PeriodReportDocument report, LocalizationService loc) async {
    try {
      await ReportExportService.sharePdf(report: report);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.t('owner_pdf_export_failed'))),
      );
    }
  }

  void _openFinanceDetail(_OwnerDashboardBundle bundle) {
    final data = bundle.finance;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DrillDownScaffold(
          title: 'Financial Detail',
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
              child: const Text(
                'Source note: income and expense are calculated from activity logs (cost, quantity, and notes). If explicit amounts are missing, FarmGenius estimates values from unit defaults and effort-hours rules.',
                style: TextStyle(height: 1.35),
              ),
            ),
            _metricTile('Month Income', _tzs(data.overview.monthIncome), Colors.green.shade700),
            _metricTile('Month Expenses', _tzs(data.overview.monthExpenses), Colors.orange.shade800),
            _metricTile('Month Net', _tzs(data.overview.monthNet), data.overview.monthNet < 0 ? Colors.red.shade700 : Colors.green.shade700),
            _metricTile('Planned Team Payroll', _tzs(_monthlyPayrollBaselineTzs()), Colors.indigo.shade700),
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: const Text(
                'Workforce plan: 4 full-time operator teams at TZS 100,000 each monthly. Feeding, accommodation, and medical support are treated as in-kind welfare and should be logged via external/service or ledger entries for full cost visibility.',
                style: TextStyle(height: 1.35),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Revenue by Source', style: TextStyle(fontWeight: FontWeight.bold)),
            ...data.revenueBySource.map((item) => ListTile(title: Text(item.label), trailing: Text(_tzs(item.amount)))),
            const SizedBox(height: 8),
            const Text('Expenses by Category', style: TextStyle(fontWeight: FontWeight.bold)),
            ...data.expensesByCategory.map((item) => ListTile(
                  title: Text(item.label),
                  subtitle: Text('Budget: ${_tzs(item.budget)}'),
                  trailing: Text(_tzs(item.actual)),
                )),
          ],
        ),
      ),
    );
  }

  Future<void> _openReportsDetail(_OwnerDashboardBundle bundle, LocalizationService loc) async {
    final now = DateTime.now();

    try {
      await BiologicalAssetService.compactOutdatedCheckEvidence();
    } catch (_) {}

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
          title: 'Report Center',
          children: reports.map((report) {
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${report.periodType.toUpperCase()} • ${report.periodLabel}',
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
                              title: Text('Preview ${report.periodType} report'),
                              content: SizedBox(
                                width: 420,
                                child: SingleChildScrollView(
                                  child: Text(report.whatsappMessage),
                                ),
                              ),
                              actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
                            ),
                          ),
                          child: const Text('Preview'),
                        ),
                        OutlinedButton(
                          onPressed: () => _shareToWhatsApp(report.whatsappMessage, loc),
                          child: const Text('WhatsApp'),
                        ),
                        OutlinedButton(
                          onPressed: () => _copyCsv(report, loc),
                          child: const Text('Copy CSV'),
                        ),
                        OutlinedButton(
                          onPressed: () => _sharePdf(report, loc),
                          child: const Text('Share PDF'),
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

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DrillDownScaffold(
          title: 'Operations Assist',
          children: [
            _metricTile('Readiness Score', '${bundle.assist.readinessScore}/100', Colors.blueGrey),
            const SizedBox(height: 12),
            const Text('Top Recommendations', style: TextStyle(fontWeight: FontWeight.bold)),
            ...bundle.assist.recommendations.map(
              (item) => ListTile(
                title: Text(item.title),
                subtitle: Text(item.action),
                trailing: Text(item.priority.toUpperCase()),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Implementation Tracker', style: TextStyle(fontWeight: FontWeight.bold)),
            if (counts.isEmpty)
              const ListTile(
                title: Text('No recommendation tracking records yet'),
                subtitle: Text('Actions (accept/modify/execute) will appear here after team updates.'),
              )
            else ...[
              _metricTile('Proposed', '${counts['proposed'] ?? 0}', Colors.blueGrey.shade700),
              _metricTile('Accepted', '${counts['accepted'] ?? 0}', Colors.blue.shade700),
              _metricTile('Modified', '${counts['modified'] ?? 0}', Colors.orange.shade700),
              _metricTile('Deferred', '${counts['deferred'] ?? 0}', Colors.deepPurple.shade700),
              _metricTile('Executed', '${counts['executed'] ?? 0}', Colors.green.shade700),
            ],
            const SizedBox(height: 8),
            const Text('How Addressed (Recent)', style: TextStyle(fontWeight: FontWeight.bold)),
            if (bundle.assist.recommendationExecutionLogs.isEmpty)
              const ListTile(
                title: Text('No recommendation actions captured yet'),
              )
            else
              ...bundle.assist.recommendationExecutionLogs.map(
                (log) => ListTile(
                  title: Text(log.recommendationText),
                  subtitle: Text(
                    '${log.actionType.toUpperCase()}${log.notes == null || log.notes!.isEmpty ? '' : ' • ${log.notes}'}',
                  ),
                  trailing: Text(
                    log.actedAt == null ? '-' : DateFormat('dd MMM').format(log.actedAt!),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            const Text('Doctor/Supplier Verification Queue', style: TextStyle(fontWeight: FontWeight.bold)),
            if (bundle.pendingExternalEntries.isEmpty)
              const ListTile(
                title: Text('No pending external entries'),
                subtitle: Text('All submitted doctor/supplier events are already verified.'),
              )
            else
              ...bundle.pendingExternalEntries.map(
                (entry) => ListTile(
                  title: Text('${entry.partnerType.toUpperCase()} • ${entry.partnerName}'),
                  subtitle: Text(
                    '${entry.entryKind} • ${entry.serviceDate == null ? '-' : DateFormat('dd MMM yyyy').format(entry.serviceDate!)} • ${_tzs(entry.amountTzs)}',
                  ),
                  trailing: Wrap(
                    spacing: 6,
                    children: [
                      TextButton(
                        onPressed: () => _reviewExternalEntry(entry: entry, approved: false),
                        child: const Text('Reject'),
                      ),
                      ElevatedButton(
                        onPressed: () => _reviewExternalEntry(entry: entry, approved: true),
                        child: const Text('Approve'),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 12),
            const Text('Data Ownership Rules', style: TextStyle(fontWeight: FontWeight.bold)),
            ...bundle.assist.ownershipRules.map(
              (rule) => ListTile(
                title: Text(rule.dataType),
                subtitle: Text('${rule.primaryRole} → ${rule.reviewRole}'),
              ),
            ),
          ],
        ),
      ),
    );
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
        SnackBar(content: Text(approved ? 'Entry approved for payment.' : 'Entry rejected for correction.')),
      );
      setState(() => _dashboardFuture = _loadBundle());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update verification: $e')),
      );
    }
  }

  void _openProfitabilityDetail(_OwnerDashboardBundle bundle) {
    Widget section(ZoneCashCowWindow window) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${window.label} Cash-Cow Ranking', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          if (window.rankedZones.isEmpty)
            const ListTile(title: Text('No data in this window'))
          else
            ...window.rankedZones.asMap().entries.map(
              (entry) {
                final index = entry.key;
                final zone = entry.value;
                return ListTile(
                  title: Text('${index + 1}. ${zone.zoneName}'),
                  subtitle: Text('Revenue ${_tzs(zone.revenue)} • Expenses ${_tzs(zone.expenses)}'),
                  trailing: Text(
                    _tzs(zone.net),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: zone.net < 0 ? Colors.red.shade700 : Colors.green.shade700,
                    ),
                  ),
                );
              },
            ),
          const SizedBox(height: 10),
        ],
      );
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DrillDownScaffold(
          title: 'Zone Profitability',
          children: [
            section(bundle.zoneCashCowRanking.daily),
            section(bundle.zoneCashCowRanking.weekly),
            section(bundle.zoneCashCowRanking.monthly),
          ],
        ),
      ),
    );
  }

  void _openBreedRecommendationDetail(_OwnerDashboardBundle bundle) {
    if (bundle.breedRecommendations.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No livestock data available for recommendation yet.')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DrillDownScaffold(
          title: 'Breed Recommendation',
          children: [
            _metricTile('Species Assessed', '${bundle.breedRecommendations.length}', Colors.brown.shade700),
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
                      Text('Current Breed: ${recommendation.currentBreed ?? 'Not recorded'}'),
                      Text('Estimated Herd Size: ${recommendation.herdSize}'),
                      Text(
                        'Last Stock Update: ${recommendation.stockUpdateDate == null ? 'Not recorded' : DateFormat('dd MMM yyyy').format(recommendation.stockUpdateDate!)}',
                      ),
                      Text(
                        'Recommended Breed: ${recommendation.topRecommendation.breed.name} (${recommendation.topRecommendation.score.toStringAsFixed(1)}/100)',
                        style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.w600),
                      ),
                      if (recommendation.stockUpdateNote != null && recommendation.stockUpdateNote!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            recommendation.stockUpdateNote!,
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                        ),
                      const SizedBox(height: 6),
                      const Text('Ranked Options', style: TextStyle(fontWeight: FontWeight.bold)),
                      ...recommendation.ranked.map(
                        (item) => ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(item.breed.name),
                          subtitle: Text(item.reasons.join('  ')),
                          trailing: Text('${item.score.toStringAsFixed(1)}/100'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Maintenance Plan', style: TextStyle(fontWeight: FontWeight.bold)),
            ...bundle.breedRecommendations.first.maintenancePlan.map(
              (item) => ListTile(
                dense: true,
                leading: const Icon(Icons.check_circle_outline, size: 20),
                title: Text(item),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openBioassetDetail(_OwnerDashboardBundle bundle) {
    final summary = bundle.bioSummary;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DrillDownScaffold(
          title: 'Bioasset Status',
          children: [
            _metricTile('Active Bioassets', '${summary?.activeAssets ?? 0}', Colors.teal.shade700),
            _metricTile('Total Quantity', NumberFormat('#,##0.##', 'en_US').format(summary?.totalQuantity ?? 0), Colors.blueGrey.shade700),
            _metricTile('Total Medium Value', _tzs(summary?.totalMedium ?? 0), Colors.green.shade700),
            _metricTile('Livestock Medium Value', _tzs(summary?.livestockMedium ?? 0), Colors.brown.shade700),
            _metricTile('Crops Medium Value', _tzs(summary?.cropsMedium ?? 0), Colors.lightGreen.shade700),
            const SizedBox(height: 12),
            const Text('All Bioasset Categories', style: TextStyle(fontWeight: FontWeight.bold)),
            if (bundle.bioCategories.isEmpty)
              const ListTile(title: Text('No bioasset category data yet'))
            else
              ...bundle.bioCategories.map(
                (category) => ListTile(
                  title: Text(category.assetType),
                  subtitle: Text('Count ${category.assetCount}'),
                  trailing: Text(_tzs(category.totalMedium)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _openLegacyDetail() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DrillDownScaffold(
          title: 'Legacy',
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

  @override
  Widget build(BuildContext context) {
    final loc = Provider.of<LocalizationService>(context);
    final auth = Provider.of<AuthService>(context, listen: false);

    return DashboardHubScaffold(
      title: loc.t('owner_home'),
      onRefresh: () => setState(() => _dashboardFuture = _loadBundle()),
      onLogout: () async {
        await auth.signOut();
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/');
      },
      child: FutureBuilder<_OwnerDashboardBundle>(
        future: _dashboardFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return const Center(child: Text('Could not load owner dashboard'));
          }

          final bundle = snapshot.data!;
          final finance = bundle.finance;

          final cards = [
            HubSummaryCard(
              icon: Icons.account_balance_wallet,
              title: 'Financial Snapshot',
              primaryValue: _tzs(finance.overview.monthNet),
              secondaryValue: 'Income ${_tzs(finance.overview.monthIncome)}',
              color: finance.overview.monthNet < 0 ? Colors.red.shade700 : Colors.green.shade700,
              onTap: () => _openFinanceDetail(bundle),
            ),
            HubSummaryCard(
              icon: Icons.summarize,
              title: 'Reports',
              primaryValue: 'Daily • Weekly • Monthly',
              secondaryValue: 'Tap to preview and share',
              color: Colors.teal.shade700,
              onTap: () => _openReportsDetail(bundle, loc),
            ),
            HubSummaryCard(
              icon: Icons.auto_graph,
              title: 'Ops Readiness',
              primaryValue: '${bundle.assist.readinessScore}/100',
              secondaryValue:
                  '${(bundle.assist.recommendationStatusCounts['executed'] ?? 0)} executed • ${(bundle.assist.recommendationStatusCounts['proposed'] ?? 0)} proposed',
              color: Colors.indigo.shade700,
              onTap: () => _openAssistDetail(bundle),
            ),
            HubSummaryCard(
              icon: Icons.map,
              title: 'Zone Profitability',
              primaryValue: '${finance.zoneProfitability.length} zones',
              secondaryValue:
                  'Top today: ${bundle.zoneCashCowRanking.daily.topZone?.zoneName ?? 'N/A'}',
              color: Colors.brown.shade700,
              onTap: () => _openProfitabilityDetail(bundle),
            ),
            HubSummaryCard(
              icon: Icons.pets,
              title: 'Breed Recommendation',
              primaryValue: bundle.breedRecommendations.isEmpty
                  ? 'Not enough livestock data'
                  : bundle.breedRecommendations.first.topRecommendation.breed.name,
              secondaryValue: bundle.breedRecommendations.isEmpty
                  ? 'Tap for setup guidance'
                  : '${bundle.breedRecommendations.length} species assessed • ${bundle.breedRecommendations.first.topRecommendation.score.toStringAsFixed(1)}/100',
              color: Colors.deepOrange.shade700,
              onTap: () => _openBreedRecommendationDetail(bundle),
            ),
            HubSummaryCard(
              icon: Icons.inventory_2,
              title: 'Bioasset Status',
              primaryValue: '${bundle.bioSummary?.activeAssets ?? 0} active assets',
              secondaryValue: '${bundle.bioCategories.length} categories tracked',
              color: Colors.cyan.shade700,
              onTap: () => _openBioassetDetail(bundle),
            ),
            HubSummaryCard(
              icon: Icons.favorite,
              title: 'Legacy',
              primaryValue: 'Dr. Pascal Fidelis Mujuni',
              secondaryValue: 'Tap to view dedication',
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

class _OwnerDashboardBundle {
  final OwnerFinanceDashboardData finance;
  final ZoneCashCowRanking zoneCashCowRanking;
  final OperationsAssistSnapshot assist;
  final List<BreedRecommendationResult> breedRecommendations;
  final BiologicalAssetDashboardSummary? bioSummary;
  final List<BiologicalAssetCategorySummary> bioCategories;
  final List<DailyAssetCheck> dailyChecks;
  final List<ExternalPartnerEntry> pendingExternalEntries;

  const _OwnerDashboardBundle({
    required this.finance,
    required this.zoneCashCowRanking,
    required this.assist,
    required this.breedRecommendations,
    required this.bioSummary,
    required this.bioCategories,
    required this.dailyChecks,
    required this.pendingExternalEntries,
  });
}
