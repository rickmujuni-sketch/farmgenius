import '../models/biological_asset.dart';
import 'supabase_service.dart';

class BiologicalAssetService {
  static const String _summaryView = 'biological_asset_dashboard_summary';
  static const String _latestValuesView = 'biological_asset_latest_values';
  static const String _categoryView = 'biological_asset_category_summary';
  static const String _zonesTable = 'asset_zones';
  static const String _checksTable = 'daily_asset_checks';
  static const String _kmlZoneMappingTable = 'kml_zone_asset_zone_map';

  static Future<BiologicalAssetDashboardSummary?> getDashboardSummary() async {
    try {
      final result = await SupabaseService.client.from(_summaryView).select().limit(1);
      if (result is List && result.isNotEmpty) {
        return BiologicalAssetDashboardSummary.fromMap(result.first as Map<String, dynamic>);
      }
    } catch (_) {}
    return null;
  }

  static Future<List<BiologicalAssetValueRow>> getTopAssetsByValue({int limit = 8}) async {
    try {
      final result = await SupabaseService.client
          .from(_latestValuesView)
          .select()
          .order('scenario_medium', ascending: false)
          .limit(limit);

      if (result is List) {
        return result
            .map((row) => BiologicalAssetValueRow.fromMap(row as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<List<BiologicalAssetCategorySummary>> getCategorySummary() async {
    try {
      final result = await SupabaseService.client
          .from(_categoryView)
          .select()
          .order('total_medium', ascending: false);

      if (result is List) {
        return result
            .map((row) => BiologicalAssetCategorySummary.fromMap(row as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<List<AssetZoneOption>> getAssetZones() async {
    try {
      final result = await SupabaseService.client
          .from(_zonesTable)
          .select('id,name')
          .order('name', ascending: true);

      if (result is List) {
        return result
            .map((row) => AssetZoneOption.fromMap(row as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<List<DailyAssetCheck>> getRecentDailyChecks({int limit = 15}) async {
    try {
      final result = await SupabaseService.client
          .from(_checksTable)
          .select()
          .order('check_date', ascending: false)
          .order('created_at', ascending: false)
          .limit(limit);

      if (result is List) {
        return result
            .map((row) => DailyAssetCheck.fromMap(row as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<void> createDailyAssetCheck({
    required DateTime checkDate,
    required String timeBlock,
    required String? zoneId,
    required String checklistType,
    required Map<String, dynamic> observations,
    required List<String> alerts,
  }) async {
    final userId = SupabaseService.client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('No authenticated user found');
    }

    await SupabaseService.client.from(_checksTable).insert({
      'id': 'chk_${DateTime.now().millisecondsSinceEpoch}',
      'check_date': checkDate.toIso8601String().split('T').first,
      'time_block': timeBlock,
      'zone_id': zoneId,
      'checklist_type': checklistType,
      'observations': observations,
      'alerts': alerts,
      'recorded_by': userId,
    });
  }

  static Future<void> updateDailyAssetCheck({
    required String id,
    required DateTime checkDate,
    required String timeBlock,
    required String? zoneId,
    required String checklistType,
    required Map<String, dynamic> observations,
    required List<String> alerts,
  }) async {
    await SupabaseService.client.from(_checksTable).update({
      'check_date': checkDate.toIso8601String().split('T').first,
      'time_block': timeBlock,
      'zone_id': zoneId,
      'checklist_type': checklistType,
      'observations': observations,
      'alerts': alerts,
    }).eq('id', id);
  }

  static Future<int> compactOutdatedCheckEvidence({
    int olderThanDays = 120,
    int limit = 300,
  }) async {
    final cutoffDate = DateTime.now().subtract(Duration(days: olderThanDays));
    final cutoffIso = cutoffDate.toIso8601String().split('T').first;

    final rows = await SupabaseService.client
        .from(_checksTable)
        .select('id,observations,check_date')
        .lt('check_date', cutoffIso)
        .order('check_date', ascending: true)
        .limit(limit);

    if (rows is! List || rows.isEmpty) {
      return 0;
    }

    var updatedCount = 0;
    final archivedAt = DateTime.now().toIso8601String();

    for (final row in rows.whereType<Map<String, dynamic>>()) {
      final id = (row['id'] ?? '').toString();
      if (id.isEmpty) continue;

      final existing = (row['observations'] as Map<String, dynamic>?) ?? <String, dynamic>{};
      final evidence = (existing['evidence'] as Map<String, dynamic>?) ?? <String, dynamic>{};

      final receipts = (evidence['receipts'] as List?) ?? const [];
      final animals = (evidence['animals'] as List?) ?? const [];
      final plants = (evidence['plants'] as List?) ?? const [];
      final infrastructure = (evidence['infrastructure'] as List?) ?? const [];
      final other = (evidence['other'] as List?) ?? const [];

      final totalEvidence = receipts.length + animals.length + plants.length + infrastructure.length + other.length;
      if (totalEvidence == 0) {
        continue;
      }

      final updatedObservations = Map<String, dynamic>.from(existing);
      updatedObservations['evidence_archive'] = {
        'archived_at': archivedAt,
        'counts': {
          'receipts': receipts.length,
          'animals': animals.length,
          'plants': plants.length,
          'infrastructure': infrastructure.length,
          'other': other.length,
          'total': totalEvidence,
        },
      };
      updatedObservations['evidence'] = {
        'receipts': const <dynamic>[],
        'animals': const <dynamic>[],
        'plants': const <dynamic>[],
        'infrastructure': const <dynamic>[],
        'other': const <dynamic>[],
        'total_count': totalEvidence,
        'archived': true,
        'archived_at': archivedAt,
      };

      await SupabaseService.client
          .from(_checksTable)
          .update({'observations': updatedObservations})
          .eq('id', id);

      updatedCount += 1;
    }

    return updatedCount;
  }

  static Future<ZoneOperationalSnapshot> getZoneOperationalSnapshot({
    required List<String> assetZoneIds,
  }) async {
    if (assetZoneIds.isEmpty) {
      return const ZoneOperationalSnapshot.empty(linkedZoneIds: []);
    }

    try {
      final assetRows = await SupabaseService.client
          .from(_latestValuesView)
          .select('asset_id,quantity,scenario_medium,zone_id')
          .in_('zone_id', assetZoneIds);

      final checkRows = await SupabaseService.client
          .from(_checksTable)
          .select('check_date,zone_id')
          .in_('zone_id', assetZoneIds)
          .order('check_date', ascending: false)
          .limit(100);

      var totalQuantity = 0.0;
      var totalMediumValue = 0.0;
      var assetCount = 0;

      if (assetRows is List) {
        for (final row in assetRows) {
          if (row is Map<String, dynamic>) {
            assetCount += 1;
            totalQuantity += _toDouble(row['quantity']);
            totalMediumValue += _toDouble(row['scenario_medium']);
          }
        }
      }

      DateTime? lastCheckDate;
      var recentChecksCount = 0;
      if (checkRows is List) {
        recentChecksCount = checkRows.length;
        if (checkRows.isNotEmpty && checkRows.first is Map<String, dynamic>) {
          lastCheckDate = DateTime.tryParse(((checkRows.first as Map<String, dynamic>)['check_date'] ?? '').toString());
        }
      }

      return ZoneOperationalSnapshot(
        linkedZoneIds: assetZoneIds,
        assetCount: assetCount,
        totalQuantity: totalQuantity,
        totalMediumValue: totalMediumValue,
        recentChecksCount: recentChecksCount,
        lastCheckDate: lastCheckDate,
      );
    } catch (_) {
      return ZoneOperationalSnapshot.empty(linkedZoneIds: assetZoneIds);
    }
  }

  static Future<List<String>> getLinkedAssetZoneIds({
    required String kmlZoneId,
    List<String> fallback = const [],
  }) async {
    try {
      final result = await SupabaseService.client
          .from(_kmlZoneMappingTable)
          .select('asset_zone_id,sort_order')
          .eq('kml_zone_id', kmlZoneId)
          .order('sort_order', ascending: true)
          .order('asset_zone_id', ascending: true);

      if (result is List && result.isNotEmpty) {
        final ids = <String>[];
        for (final row in result) {
          if (row is Map<String, dynamic>) {
            final id = (row['asset_zone_id'] ?? '').toString();
            if (id.isNotEmpty) {
              ids.add(id);
            }
          }
        }
        if (ids.isNotEmpty) {
          return ids;
        }
      }
    } catch (_) {}

    return fallback;
  }

  static Future<void> replaceKmlZoneMappings({
    required String kmlZoneId,
    required List<String> assetZoneIds,
  }) async {
    await SupabaseService.client
        .from(_kmlZoneMappingTable)
        .delete()
        .eq('kml_zone_id', kmlZoneId);

    if (assetZoneIds.isEmpty) {
      return;
    }

    final rows = <Map<String, dynamic>>[];
    for (var index = 0; index < assetZoneIds.length; index++) {
      rows.add({
        'kml_zone_id': kmlZoneId,
        'asset_zone_id': assetZoneIds[index],
        'sort_order': index + 1,
      });
    }

    await SupabaseService.client.from(_kmlZoneMappingTable).insert(rows);
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }
}
