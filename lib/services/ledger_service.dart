import 'supabase_service.dart';

class LedgerService {
  static Future<void> recordExecutionFinancials({
    required String activityLogId,
    required String staffId,
    required String zoneId,
    required String activity,
    required DateTime occurredAt,
    required String financialCategory,
    required double costTzs,
    required double revenueTzs,
    double? quantity,
    String? quantityUnit,
    String? taskId,
    Map<String, dynamic>? metadata,
  }) async {
    final safeCategory = financialCategory.trim().isEmpty ? 'labor' : financialCategory.trim().toLowerCase();
    final rows = <Map<String, dynamic>>[];

    if (costTzs > 0) {
      rows.add({
        'id': 'ledger_${activityLogId}_expense',
        'activity_log_id': activityLogId,
        'task_id': taskId,
        'zone_id': zoneId,
        'staff_id': staffId,
        'entry_type': 'expense',
        'category': safeCategory,
        'amount_tzs': costTzs,
        'quantity': quantity,
        'quantity_unit': quantityUnit,
        'occurred_at': occurredAt.toIso8601String(),
        'source': 'staff_execution',
        'metadata': {
          'activity': activity,
          ...?metadata,
        },
      });
    }

    if (revenueTzs > 0) {
      rows.add({
        'id': 'ledger_${activityLogId}_revenue',
        'activity_log_id': activityLogId,
        'task_id': taskId,
        'zone_id': zoneId,
        'staff_id': staffId,
        'entry_type': 'revenue',
        'category': _revenueCategoryForActivity(activity, safeCategory),
        'amount_tzs': revenueTzs,
        'quantity': quantity,
        'quantity_unit': quantityUnit,
        'occurred_at': occurredAt.toIso8601String(),
        'source': 'staff_execution',
        'metadata': {
          'activity': activity,
          ...?metadata,
        },
      });
    }

    if (rows.isEmpty) return;

    await SupabaseService.client.from('farm_ledger_entries').upsert(rows, onConflict: 'id');
  }

  static Future<List<Map<String, dynamic>>> loadEntries({
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final rows = await SupabaseService.client
          .from('farm_ledger_entries')
          .select('entry_type,category,amount_tzs,zone_id,occurred_at,metadata,staff_id')
          .gte('occurred_at', from.toIso8601String())
          .lt('occurred_at', to.toIso8601String())
          .order('occurred_at', ascending: true);
      if (rows is List) {
        return rows.whereType<Map<String, dynamic>>().toList();
      }
    } catch (_) {}
    return const [];
  }

  static String _revenueCategoryForActivity(String activity, String fallback) {
    final lower = activity.toLowerCase();
    if (lower.contains('harvest') || lower.contains('plant')) return 'crop_sales';
    if (lower.contains('health') || lower.contains('grazing') || lower.contains('livestock')) return 'livestock_sales';
    if (lower.contains('egg') || lower.contains('milk')) return 'other_income';
    if (fallback == 'crop_sales' || fallback == 'livestock_sales' || fallback == 'other_income') {
      return fallback;
    }
    return 'other_income';
  }
}
