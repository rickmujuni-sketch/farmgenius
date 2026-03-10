import '../models/generated_farm_zones.dart';
import 'supabase_service.dart';

class DemoSeedService {
  static bool _attempted = false;

  static Future<void> ensureSeedData({required String? userId}) async {
    if (_attempted) return;
    _attempted = true;
    if (userId == null || userId.isEmpty) return;

    final now = DateTime.now();
    final todayKey = _dateKey(now);

    final tasksEmpty = await _isTableEmpty('tasks');
    if (tasksEmpty) {
      await _seedTasks(todayKey);
    }

    final hasOwnLogs = await _hasOwnLogs(userId);
    if (!hasOwnLogs) {
      await _seedActivityLogs(userId, now);
    }
  }

  static Future<bool> _isTableEmpty(String table) async {
    try {
      final rows = await SupabaseService.client.from(table).select('id').limit(1);
      return rows is List && rows.isEmpty;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _hasOwnLogs(String userId) async {
    try {
      final rows = await SupabaseService.client
          .from('activity_logs')
          .select('id')
          .eq('staff_id', userId)
          .limit(1);
      return rows is List && rows.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static Future<void> _seedTasks(String todayKey) async {
    final now = DateTime.now();
    final zones = GeneratedFarmZones.allZones;
    final records = <Map<String, dynamic>>[];

    if (zones.isNotEmpty) {
      records.add({
        'id': 'seed_task_${zones[0].id}_$todayKey',
        'zone_id': zones[0].id,
        'title': 'Seed: Morning zone inspection',
        'description': 'Run a quick field inspection and record observations.',
        'activity': 'INSPECTION',
        'due_date': now.add(const Duration(days: 1)).toIso8601String(),
        'priority': 'MEDIUM',
        'status': 'PENDING',
        'created_at': now.toIso8601String(),
        'created_by_ai': 'seed_data',
        'metadata': {'seed': true},
      });
    }

    if (zones.length > 1) {
      records.add({
        'id': 'seed_task_${zones[1].id}_$todayKey',
        'zone_id': zones[1].id,
        'title': 'Seed: Livestock health check',
        'description': 'Verify feed, water, and herd condition; note concerns.',
        'activity': 'HEALTH_CHECK',
        'due_date': now.add(const Duration(days: 2)).toIso8601String(),
        'priority': 'HIGH',
        'status': 'IN_PROGRESS',
        'created_at': now.toIso8601String(),
        'created_by_ai': 'seed_data',
        'metadata': {'seed': true},
      });
    }

    if (zones.length > 2) {
      records.add({
        'id': 'seed_task_${zones[2].id}_$todayKey',
        'zone_id': zones[2].id,
        'title': 'Seed: Infrastructure maintenance review',
        'description': 'Confirm pump and storage condition, then submit for review.',
        'activity': 'MAINTENANCE',
        'due_date': now.add(const Duration(days: 1)).toIso8601String(),
        'priority': 'MEDIUM',
        'status': 'REVIEW_PENDING',
        'created_at': now.toIso8601String(),
        'created_by_ai': 'seed_data',
        'metadata': {'seed': true},
      });
    }

    for (final record in records) {
      try {
        await SupabaseService.client.from('tasks').insert(record);
      } catch (_) {}
    }
  }

  static Future<void> _seedActivityLogs(String userId, DateTime now) async {
    final monthKey = '${now.year}${now.month.toString().padLeft(2, '0')}';
    final zones = GeneratedFarmZones.allZones;
    final zoneA = zones.isNotEmpty ? zones[0].id : 'zone_a';
    final zoneB = zones.length > 1 ? zones[1].id : 'zone_b';

    final logs = [
      {
        'id': 'seed_log_crop_$monthKey',
        'task_id': null,
        'zone_id': zoneA,
        'staff_id': userId,
        'activity': 'HARVEST',
        'logged_at': now.subtract(const Duration(days: 7, hours: 2)).toIso8601String(),
        'completed_at': now.subtract(const Duration(days: 7)).toIso8601String(),
        'notes': 'Seed sale log\nFinancial Category: crop_sales\nRevenue (TZS): 1450000\nEffort Hours: 3.5',
        'quantity': 580,
        'quantity_unit': 'kg',
        'cost': 95000,
      },
      {
        'id': 'seed_log_feed_$monthKey',
        'task_id': null,
        'zone_id': zoneB,
        'staff_id': userId,
        'activity': 'SUPPLEMENTAL_FEEDING',
        'logged_at': now.subtract(const Duration(days: 3, hours: 1)).toIso8601String(),
        'completed_at': now.subtract(const Duration(days: 3)).toIso8601String(),
        'notes': 'Seed operating expense\nFinancial Category: feed\nCost (TZS): 180000\nEffort Hours: 2.0',
        'quantity': 12,
        'quantity_unit': 'bunch',
        'cost': 180000,
      },
    ];

    for (final log in logs) {
      try {
        await SupabaseService.client.from('activity_logs').insert(log);
      } catch (_) {}
    }
  }

  static String _dateKey(DateTime value) {
    return '${value.year}${value.month.toString().padLeft(2, '0')}${value.day.toString().padLeft(2, '0')}';
  }
}