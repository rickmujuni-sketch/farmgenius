import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../legacy_content.dart';
import '../models/farm_zone.dart';
import '../models/operations_assist.dart';
import '../services/ai_orchestrator.dart';
import '../services/auth_service.dart';
import '../services/demo_seed_service.dart';
import '../services/localization_service.dart';
import '../services/operations_assist_service.dart';
import '../services/supabase_service.dart';
import 'dashboard_hub_scaffold.dart';

class ManagerHome extends StatefulWidget {
  const ManagerHome({super.key});

  @override
  State<ManagerHome> createState() => _ManagerHomeState();
}

class _ManagerHomeState extends State<ManagerHome> {
  late Future<_ManagerDashboardData> _dashboardFuture;

  @override
  void initState() {
    super.initState();
    _dashboardFuture = _loadData();
  }

  Future<_ManagerDashboardData> _loadData() async {
    final ai = Provider.of<AIOrchestrator>(context, listen: false);
    final userId = Provider.of<AuthService>(context, listen: false).user?.id;

    await DemoSeedService.ensureSeedData(userId: userId);

    final results = await Future.wait([
      ai.getPendingTasksForStaff(),
      ai.getAnomalies(),
      OperationsAssistService.loadSnapshot(),
      _loadStaffCount(),
      _loadReviewPendingCount(),
    ]);

    final tasks = results[0] as List<Task>;
    final anomalies = results[1] as List<AnomalyDetection>;

    final overdueCount = tasks.where((t) => t.isOverdue || t.status == TaskStatus.OVERDUE).length;
    final inProgressCount = tasks.where((t) => t.status == TaskStatus.IN_PROGRESS).length;

    return _ManagerDashboardData(
      tasks: tasks,
      anomalies: anomalies,
      assist: results[2] as OperationsAssistSnapshot,
      staffCount: results[3] as int,
      reviewPendingCount: results[4] as int,
      overdueCount: overdueCount,
      inProgressCount: inProgressCount,
    );
  }

  Future<int> _loadStaffCount() async {
    try {
      final rows = await SupabaseService.client.from('profiles').select('id').eq('role', 'staff');
      if (rows is List) return rows.length;
    } catch (_) {}
    return 0;
  }

  Future<int> _loadReviewPendingCount() async {
    try {
      final rows = await SupabaseService.client
          .from('tasks')
          .select('id')
          .eq('status', 'REVIEW_PENDING')
          .limit(300);
      if (rows is List) return rows.length;
    } catch (_) {}
    return 0;
  }

  Future<void> _runNowAndRefresh() async {
    final ai = Provider.of<AIOrchestrator>(context, listen: false);
    await ai.runDailyOrchestration();
    if (!mounted) return;
    setState(() {
      _dashboardFuture = _loadData();
    });
  }

  void _openTasksDetail(_ManagerDashboardData data) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DrillDownScaffold(
          title: 'Task Operations',
          children: [
            _infoChipRow([
              'Open: ${data.tasks.length}',
              'In Progress: ${data.inProgressCount}',
              'Overdue: ${data.overdueCount}',
            ]),
            const SizedBox(height: 8),
            ...data.tasks.map(
              (task) => ListTile(
                title: Text(task.title),
                subtitle: Text('${task.zoneId} • ${task.activity.name} • due ${task.dueDate.toLocal().toString().split(' ').first}'),
                trailing: Text(task.status.name),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openAlertsDetail(_ManagerDashboardData data) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DrillDownScaffold(
          title: 'Anomalies & Alerts',
          children: [
            _infoChipRow([
              'Alerts: ${data.anomalies.length}',
              'Critical: ${data.anomalies.where((a) => a.severity >= 0.8).length}',
            ]),
            const SizedBox(height: 8),
            ...data.anomalies.map(
              (anomaly) => ListTile(
                title: Text(anomaly.title),
                subtitle: Text(anomaly.description),
                trailing: Text('${(anomaly.severity * 100).toStringAsFixed(0)}%'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openTeamDetail(_ManagerDashboardData data) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DrillDownScaffold(
          title: 'Team Flow',
          children: [
            _metricTile('Team Size', '${data.staffCount} staff', Colors.indigo.shade700),
            _metricTile('Review Pending', '${data.reviewPendingCount} tasks', Colors.orange.shade800),
            _metricTile('In Progress', '${data.inProgressCount} tasks', Colors.blueGrey),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _runNowAndRefresh,
              icon: const Icon(Icons.bolt),
              label: const Text('Run Intelligence Now'),
            ),
          ],
        ),
      ),
    );
  }

  void _openAssistDetail(_ManagerDashboardData data) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DrillDownScaffold(
          title: 'Manager AI Brief',
          children: [
            _metricTile('Readiness', '${data.assist.readinessScore}/100', Colors.teal.shade700),
            const SizedBox(height: 10),
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

  Widget _infoChipRow(List<String> items) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((item) => Chip(label: Text(item))).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = Provider.of<LocalizationService>(context);
    final auth = Provider.of<AuthService>(context, listen: false);

    return DashboardHubScaffold(
      title: loc.t('manager_home'),
      onRefresh: () => setState(() => _dashboardFuture = _loadData()),
      onLogout: () async {
        await auth.signOut();
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/');
      },
      child: FutureBuilder<_ManagerDashboardData>(
        future: _dashboardFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return const Center(child: Text('Could not load manager dashboard'));
          }

          final data = snapshot.data!;

          final cards = [
            HubSummaryCard(
              icon: Icons.fact_check,
              title: 'Task Operations',
              primaryValue: '${data.tasks.length} open tasks',
              secondaryValue: '${data.overdueCount} overdue • ${data.inProgressCount} in progress',
              color: Colors.blue.shade700,
              onTap: () => _openTasksDetail(data),
            ),
            HubSummaryCard(
              icon: Icons.warning_amber,
              title: 'Alerts',
              primaryValue: '${data.anomalies.length} active anomalies',
              secondaryValue: 'Tap for severity and context',
              color: Colors.red.shade700,
              onTap: () => _openAlertsDetail(data),
            ),
            HubSummaryCard(
              icon: Icons.groups,
              title: 'Team Flow',
              primaryValue: '${data.staffCount} staff',
              secondaryValue: '${data.reviewPendingCount} awaiting review',
              color: Colors.purple.shade700,
              onTap: () => _openTeamDetail(data),
            ),
            HubSummaryCard(
              icon: Icons.psychology_alt,
              title: 'AI Brief',
              primaryValue: '${data.assist.readinessScore}/100 readiness',
              secondaryValue: '${data.assist.recommendations.length} recommendations',
              color: Colors.teal.shade700,
              onTap: () => _openAssistDetail(data),
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

class _ManagerDashboardData {
  final List<Task> tasks;
  final List<AnomalyDetection> anomalies;
  final OperationsAssistSnapshot assist;
  final int staffCount;
  final int reviewPendingCount;
  final int overdueCount;
  final int inProgressCount;

  const _ManagerDashboardData({
    required this.tasks,
    required this.anomalies,
    required this.assist,
    required this.staffCount,
    required this.reviewPendingCount,
    required this.overdueCount,
    required this.inProgressCount,
  });
}
