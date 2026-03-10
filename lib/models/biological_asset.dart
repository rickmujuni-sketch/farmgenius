class BiologicalAssetDashboardSummary {
  final int activeAssets;
  final double totalQuantity;
  final double totalLow;
  final double totalMedium;
  final double totalHigh;
  final double cropsMedium;
  final double livestockMedium;

  const BiologicalAssetDashboardSummary({
    required this.activeAssets,
    required this.totalQuantity,
    required this.totalLow,
    required this.totalMedium,
    required this.totalHigh,
    required this.cropsMedium,
    required this.livestockMedium,
  });

  factory BiologicalAssetDashboardSummary.fromMap(Map<String, dynamic> map) {
    return BiologicalAssetDashboardSummary(
      activeAssets: _toInt(map['active_assets']),
      totalQuantity: _toDouble(map['total_quantity']),
      totalLow: _toDouble(map['total_low']),
      totalMedium: _toDouble(map['total_medium']),
      totalHigh: _toDouble(map['total_high']),
      cropsMedium: _toDouble(map['crops_medium']),
      livestockMedium: _toDouble(map['livestock_medium']),
    );
  }

  static int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }
}

class BiologicalAssetValueRow {
  final String assetId;
  final String assetType;
  final String species;
  final String zoneId;
  final double quantity;
  final String unit;
  final String? maturityStage;
  final DateTime? valuationDate;
  final double scenarioLow;
  final double scenarioMedium;
  final double scenarioHigh;
  final String currency;

  const BiologicalAssetValueRow({
    required this.assetId,
    required this.assetType,
    required this.species,
    required this.zoneId,
    required this.quantity,
    required this.unit,
    required this.maturityStage,
    required this.valuationDate,
    required this.scenarioLow,
    required this.scenarioMedium,
    required this.scenarioHigh,
    required this.currency,
  });

  factory BiologicalAssetValueRow.fromMap(Map<String, dynamic> map) {
    return BiologicalAssetValueRow(
      assetId: (map['asset_id'] ?? '').toString(),
      assetType: (map['asset_type'] ?? '').toString(),
      species: (map['species'] ?? '').toString(),
      zoneId: (map['zone_id'] ?? '').toString(),
      quantity: _toDouble(map['quantity']),
      unit: (map['unit'] ?? '').toString(),
      maturityStage: map['maturity_stage']?.toString(),
      valuationDate: map['valuation_date'] != null
          ? DateTime.tryParse(map['valuation_date'].toString())
          : null,
      scenarioLow: _toDouble(map['scenario_low']),
      scenarioMedium: _toDouble(map['scenario_medium']),
      scenarioHigh: _toDouble(map['scenario_high']),
      currency: (map['currency'] ?? 'TZS').toString(),
    );
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }
}

class BiologicalAssetCategorySummary {
  final String assetType;
  final int assetCount;
  final double totalLow;
  final double totalMedium;
  final double totalHigh;

  const BiologicalAssetCategorySummary({
    required this.assetType,
    required this.assetCount,
    required this.totalLow,
    required this.totalMedium,
    required this.totalHigh,
  });

  factory BiologicalAssetCategorySummary.fromMap(Map<String, dynamic> map) {
    return BiologicalAssetCategorySummary(
      assetType: (map['asset_type'] ?? '').toString(),
      assetCount: _toInt(map['asset_count']),
      totalLow: _toDouble(map['total_low']),
      totalMedium: _toDouble(map['total_medium']),
      totalHigh: _toDouble(map['total_high']),
    );
  }

  static int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }
}

class AssetZoneOption {
  final String id;
  final String name;

  const AssetZoneOption({
    required this.id,
    required this.name,
  });

  factory AssetZoneOption.fromMap(Map<String, dynamic> map) {
    return AssetZoneOption(
      id: (map['id'] ?? '').toString(),
      name: (map['name'] ?? '').toString(),
    );
  }
}

class DailyAssetCheck {
  final String id;
  final DateTime checkDate;
  final String timeBlock;
  final String? zoneId;
  final String checklistType;
  final Map<String, dynamic> observations;
  final List<dynamic> alerts;
  final String recordedBy;
  final DateTime? createdAt;

  const DailyAssetCheck({
    required this.id,
    required this.checkDate,
    required this.timeBlock,
    required this.zoneId,
    required this.checklistType,
    required this.observations,
    required this.alerts,
    required this.recordedBy,
    required this.createdAt,
  });

  factory DailyAssetCheck.fromMap(Map<String, dynamic> map) {
    return DailyAssetCheck(
      id: (map['id'] ?? '').toString(),
      checkDate: DateTime.tryParse((map['check_date'] ?? '').toString()) ?? DateTime.now(),
      timeBlock: (map['time_block'] ?? '').toString(),
      zoneId: map['zone_id']?.toString(),
      checklistType: (map['checklist_type'] ?? '').toString(),
      observations: (map['observations'] as Map<String, dynamic>?) ?? const {},
      alerts: (map['alerts'] as List?) ?? const [],
      recordedBy: (map['recorded_by'] ?? '').toString(),
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
    );
  }
}

class ZoneOperationalSnapshot {
  final List<String> linkedZoneIds;
  final int assetCount;
  final double totalQuantity;
  final double totalMediumValue;
  final int recentChecksCount;
  final DateTime? lastCheckDate;

  const ZoneOperationalSnapshot({
    required this.linkedZoneIds,
    required this.assetCount,
    required this.totalQuantity,
    required this.totalMediumValue,
    required this.recentChecksCount,
    required this.lastCheckDate,
  });

  const ZoneOperationalSnapshot.empty({required this.linkedZoneIds})
      : assetCount = 0,
        totalQuantity = 0,
        totalMediumValue = 0,
        recentChecksCount = 0,
        lastCheckDate = null;
}
