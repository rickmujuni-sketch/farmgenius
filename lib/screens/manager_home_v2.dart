import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/localization_service.dart';
import '../services/ai_orchestrator.dart';
import '../models/farm_zone.dart';
import '../models/generated_farm_zones.dart';

class ManagerHome extends StatefulWidget {
  const ManagerHome({super.key});

  @override
  State<ManagerHome> createState() => _ManagerHomeState();
}

class _ManagerHomeState extends State<ManagerHome> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Future<List<Task>> _tasksFuture;
  late Future<List<AnomalyDetection>> _anomaliesFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  void _loadData() {
    final ai = Provider.of<AIOrchestrator>(context, listen: false);
    _tasksFuture = ai.getPendingTasksForStaff();
    _anomaliesFuture = ai.getAnomalies();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final loc = Provider.of<LocalizationService>(context);
    final ai = Provider.of<AIOrchestrator>(context);

    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        appBar: AppBar(
          title: Text(loc.t('manager_home')),
          backgroundColor: const Color(0xFF2E7D32),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                setState(_loadData);
              },
            ),
            IconButton(
              onPressed: () async {
                await auth.signOut();
                Navigator.pushReplacementNamed(context, '/');
              },
              icon: const Icon(Icons.logout),
            )
          ],
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(icon: Icon(Icons.assignment), text: 'Tasks'),
              Tab(icon: Icon(Icons.warning), text: 'Anomalies'),
              Tab(icon: Icon(Icons.info), text: 'Zones'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            // Tasks Tab
            _buildTasksTab(),
            // Anomalies Tab
            _buildAnomaliesTab(),
            // Zones Tab
            _buildZonesTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildTasksTab() {
    return FutureBuilder<List<Task>>(
      future: _tasksFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final tasks = snapshot.data ?? [];
        final pendingTasks = tasks.where((t) => t.status == TaskStatus.PENDING).toList();
        final overdueTasks = tasks.where((t) => t.isOverdue).toList();

        return ListView(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              color: const Color(0xFFF5F5EF),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Task Summary',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _StatCard(
                        label: 'Pending',
                        value: pendingTasks.length.toString(),
                        color: Colors.blue,
                      ),
                      _StatCard(
                        label: 'Overdue',
                        value: overdueTasks.length.toString(),
                        color: Colors.red,
                      ),
                      _StatCard(
                        label: 'AI-Generated',
                        value: tasks.where((t) => t.createdByAI != null).length.toString(),
                        color: Color(0xFF2E7D32),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: const Text(
                'Recent Tasks',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
            ...tasks.take(10).map((task) => _buildTaskTile(task)).toList(),
          ],
        );
      },
    );
  }

  Widget _buildAnomaliesTab() {
    return FutureBuilder<List<AnomalyDetection>>(
      future: _anomaliesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final anomalies = snapshot.data ?? [];
        final highSeverity = anomalies.where((a) => a.severity > 0.7).toList();
        final unresolved = anomalies.where((a) => a.detectedAt == a.detectedAt).toList();

        return ListView(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              color: const Color(0xFFF5F5EF),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Anomaly Alert Summary',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _StatCard(
                        label: 'Total',
                        value: anomalies.length.toString(),
                        color: Colors.orange,
                      ),
                      _StatCard(
                        label: 'High Severity',
                        value: highSeverity.length.toString(),
                        color: Colors.red,
                      ),
                      _StatCard(
                        label: 'Unresolved',
                        value: unresolved.length.toString(),
                        color: Colors.purple,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (anomalies.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'No anomalies detected.\nFarm is operating normally!',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else
              ...anomalies.map((a) => _buildAnomalyTile(a)).toList(),
          ],
        );
      },
    );
  }

  Widget _buildZonesTab() {
    return ListView.builder(
      itemCount: GeneratedFarmZones.zones.length,
      itemBuilder: (context, index) {
        final zone = GeneratedFarmZones.zones[index];
        final icon = _getZoneIcon(zone.type);

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            leading: Icon(icon, color: const Color(0xFF2E7D32), size: 32),
            title: Text(zone.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(zone.description, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('${zone.areaHectares} hectares', style: const TextStyle(fontSize: 12)),
              ],
            ),
            isThreeLine: true,
            trailing: const Icon(Icons.arrow_forward),
            onTap: () {
              // TODO: Show zone detail with tasks, activities, and anomalies
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Zone ${zone.name} detail: coming soon')),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildTaskTile(Task task) {
    final zone = GeneratedFarmZones.zones.firstWhere(
      (z) => z.id == task.zoneId,
      orElse: () => FarmZone(
        id: 'unknown',
        name: 'Unknown',
        description: '',
        type: ZoneType.CROP,
        areaHectares: 0,
        boundary: const [],
      ),
    );

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: Container(
          width: 8,
          color: task.isOverdue
              ? Colors.red
              : task.isDueToday
                  ? Colors.orange
                  : const Color(0xFF2E7D32),
        ),
        title: Text(task.title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(zone.name, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            Row(
              children: [
                Chip(
                  label: Text(
                    task.priority.toString().split('.').last,
                    style: const TextStyle(fontSize: 10),
                  ),
                  backgroundColor: task.priority == TaskPriority.URGENT
                      ? Colors.red
                      : task.priority == TaskPriority.HIGH
                          ? Colors.orange
                          : Colors.blue,
                  labelStyle: const TextStyle(color: Colors.white),
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 8),
                if (task.createdByAI != null)
                  Chip(
                    label: Text(
                      task.createdByAI!.replaceAll('_', ' '),
                      style: const TextStyle(fontSize: 10),
                    ),
                    backgroundColor: Colors.purple,
                    labelStyle: const TextStyle(color: Colors.white),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ],
        ),
        isThreeLine: true,
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'override',
              child: Text('Override / Adjust'),
            ),
            const PopupMenuItem(
              value: 'cancel',
              child: Text('Cancel'),
            ),
          ],
          onSelected: (value) {
            // TODO: Implement override logic
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('$value: Coming soon')),
            );
          },
        ),
      ),
    );
  }

  Widget _buildAnomalyTile(AnomalyDetection anomaly) {
    final zone = GeneratedFarmZones.zones.firstWhere(
      (z) => z.id == anomaly.zoneId,
      orElse: () => FarmZone(
        id: 'unknown',
        name: 'Unknown',
        description: '',
        type: ZoneType.CROP,
        areaHectares: 0,
        boundary: const [],
      ),
    );

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: anomaly.severity > 0.7 ? Colors.red.shade50 : Colors.orange.shade50,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: anomaly.severity > 0.7 ? Colors.red : Colors.orange,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _getAnomalyIcon(anomaly.type),
                  color: Colors.white,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        anomaly.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        zone.name,
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${(anomaly.severity * 100).toInt()}%',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(anomaly.description),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      anomaly.detectedAt.toString().split('.')[0],
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Resolve'),
                      onPressed: () {
                        // TODO: Mark anomaly as resolved
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Anomaly resolution: coming soon')),
                        );
                      },
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

  IconData _getAnomalyIcon(AnomalyType type) {
    switch (type) {
      case AnomalyType.ACTIVITY_GAP:
        return Icons.schedule;
      case AnomalyType.COST_SPIKE:
        return Icons.trending_up;
      case AnomalyType.YIELD_RISK:
        return Icons.agriculture;
      case AnomalyType.WEATHER_ALERT:
        return Icons.cloud;
      case AnomalyType.HEALTH_ISSUE:
        return Icons.health_and_safety;
    }
  }

  IconData _getZoneIcon(ZoneType type) {
    switch (type) {
      case ZoneType.CROP:
        return Icons.nature;
      case ZoneType.LIVESTOCK:
        return Icons.pets;
      case ZoneType.INFRASTRUCTURE:
        return Icons.build;
    }
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
