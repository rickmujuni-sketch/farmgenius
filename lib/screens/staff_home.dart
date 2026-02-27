import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/localization_service.dart';
import '../services/ai_orchestrator.dart';
import '../models/farm_zone.dart';
import '../models/generated_farm_zones.dart';

class StaffHome extends StatefulWidget {
  const StaffHome({super.key});

  @override
  State<StaffHome> createState() => _StaffHomeState();
}

class _StaffHomeState extends State<StaffHome> {
  late Future<List<Task>> _tasksFuture;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  void _loadTasks() {
    final ai = Provider.of<AIOrchestrator>(context, listen: false);
    _tasksFuture = ai.getPendingTasksForStaff();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context);
    final loc = Provider.of<LocalizationService>(context);
    final ai = Provider.of<AIOrchestrator>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.t('staff_home')),
        backgroundColor: const Color(0xFF2E7D32),
        actions: [
          IconButton(
            onPressed: () async {
              await auth.signOut();
              Navigator.pushReplacementNamed(context, '/');
            },
            icon: const Icon(Icons.logout),
          )
        ],
      ),
      body: FutureBuilder<List<Task>>(
        future: _tasksFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error loading tasks: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(_loadTasks);
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final tasks = snapshot.data ?? [];

          if (tasks.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_outline, size: 64, color: Color(0xFF2E7D32)),
                  const SizedBox(height: 16),
                  const Text(
                    'No tasks assigned.\nGreat work!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 32),
                  RefreshButton(onRefresh: _loadTasks),
                ],
              ),
            );
          }

          return Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                color: const Color(0xFFF5F5EF),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Tasks: ${tasks.length}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    RefreshButton(onRefresh: _loadTasks),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: tasks.length,
                  itemBuilder: (context, index) {
                    final task = tasks[index];
                    final zone = GeneratedFarmZones.zones.firstWhere(
                      (z) => z.id == task.zoneId,
                      orElse: () => FarmZone(
                        id: 'unknown',
                        name: 'Unknown Zone',
                        description: '',
                        type: ZoneType.CROP,
                        areaHectares: 0,
                        boundary: const [],
                      ),
                    );

                    return TaskCard(task: task, zone: zone);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class TaskCard extends StatelessWidget {
  final Task task;
  final FarmZone zone;

  const TaskCard({
    required this.task,
    required this.zone,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isOverdue = task.isOverdue;
    final isDueToday = task.isDueToday;

    Color statusColor = const Color(0xFF2E7D32);
    if (isOverdue) {
      statusColor = Colors.red;
    } else if (isDueToday) {
      statusColor = Colors.orange;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  _getActivityIcon(task.activity),
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        zone.name,
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(task.description),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Due: ${task.dueDate.toString().split(' ')[0]}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _priorityColor(task.priority),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        task.priority.toString().split('.').last,
                        style: const TextStyle(color: Colors.white, fontSize: 10),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.location_on),
                        label: const Text('Go to Zone'),
                        onPressed: () {
                          // TODO: Open task detail screen with GPS navigation
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('GPS navigation coming soon')),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.check),
                        label: const Text('Complete'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7D32),
                        ),
                        onPressed: () {
                          // TODO: Mark task complete and open activity log screen
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Task completion coming soon')),
                          );
                        },
                      ),
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

  IconData _getActivityIcon(ActivityStage activity) {
    switch (activity) {
      case ActivityStage.PLANTING:
        return Icons.spa;
      case ActivityStage.GROWTH:
      case ActivityStage.GERMINATION:
        return Icons.nature;
      case ActivityStage.FLOWERING:
        return Icons.local_florist;
      case ActivityStage.HARVEST:
      case ActivityStage.GRAIN_FILL:
        return Icons.local_dining;
      case ActivityStage.GRAZING:
        return Icons.pets;
      case ActivityStage.HEALTH_CHECK:
        return Icons.medical_services;
      case ActivityStage.BREEDING:
      case ActivityStage.CALVING:
        return Icons.birth_date;
      case ActivityStage.MAINTENANCE:
      case ActivityStage.REPAIR:
      case ActivityStage.CLEANING:
      case ActivityStage.SEASONAL_CHECK:
      case ActivityStage.INSPECTION:
        return Icons.build;
      case ActivityStage.SUPPLEMENTAL_FEEDING:
        return Icons.restaurant;
    }
  }

  Color _priorityColor(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.LOW:
        return Colors.blue;
      case TaskPriority.MEDIUM:
        return Colors.orange;
      case TaskPriority.HIGH:
        return Colors.red;
      case TaskPriority.URGENT:
        return Colors.deepOrange;
    }
  }
}

class RefreshButton extends StatelessWidget {
  final VoidCallback onRefresh;

  const RefreshButton({required this.onRefresh, super.key});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      icon: const Icon(Icons.refresh),
      label: const Text('Refresh'),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF2E7D32),
      ),
      onPressed: onRefresh,
    );
  }
}
