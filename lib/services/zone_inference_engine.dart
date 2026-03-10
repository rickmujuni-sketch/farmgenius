import 'dart:math' as math;

import '../models/farm_zone.dart';
import '../models/kml_models.dart';
import 'kml_parser_service.dart';

class ZoneInferenceEngine {
  static const int _circleSegments = 24;

  static Future<List<FarmZone>> inferZonesFromAsset(String assetPath) async {
    final parsed = await KmlParser.parseFromAsset(assetPath);
    return inferZones(parsed);
  }

  static List<FarmZone> inferZones(ParsedKmlFarm farm) {
    final zones = <FarmZone>[];
    final livestockZones = _buildLivestockZones(farm);
    zones.addAll(livestockZones);

    final farmAreaHectares = farm.boundary.areaHectares;
    final livestockAreaHectares = livestockZones
        .map((z) => z.areaHectares)
        .fold<double>(0, (sum, area) => sum + area);
    final remainingArea = (farmAreaHectares - livestockAreaHectares)
        .clamp(0.1, farmAreaHectares)
        .toDouble();

    zones.addAll(_buildCropZonesFromRemainingLand(
      boundary: farm.boundary,
      totalFarmAreaHectares: farmAreaHectares,
      livestockAreaHectares: livestockAreaHectares,
      remainingAreaHectares: remainingArea,
    ));

    return zones;
  }

  static List<FarmZone> _buildLivestockZones(ParsedKmlFarm farm) {
    final zones = <FarmZone>[];

    for (final placemark in farm.livestockPlacemarks) {
      final livestockType = placemark.livestockType ?? LivestockType.UNKNOWN;
      final radiusMeters = _radiusForLivestockType(livestockType);
      final boundary = _circleBoundary(
        center: placemark.location,
        radiusMeters: radiusMeters,
        segments: _circleSegments,
      );

      final areaHectares = (math.pi * radiusMeters * radiusMeters) / 10000;
      final calendar = _expectedLivestockActivities(livestockType)
          .map((e) => e.name)
          .join(',');

      zones.add(
        FarmZone(
          id: 'livestock_${placemark.id.toLowerCase()}',
          name: '${_livestockDisplayName(livestockType)} Zone - ${placemark.name}',
          description:
              'Inferred livestock zone for ${placemark.name} (${_livestockDisplayName(livestockType).toLowerCase()})',
          type: ZoneType.LIVESTOCK,
          areaHectares: areaHectares,
          boundary: boundary
              .map((c) => GeoPoint(lat: c.latitude, lng: c.longitude))
              .toList(),
          metadata: {
            'zone_type': 'livestock',
            'source': 'inference_engine',
            'source_placemark_id': placemark.id,
            'source_placemark_name': placemark.name,
            'livestock_type': livestockType.name,
            'radius_meters': radiusMeters.toStringAsFixed(0),
            'expected_calendar': calendar,
          },
        ),
      );
    }

    return zones;
  }

  static List<FarmZone> _buildCropZonesFromRemainingLand({
    required FarmBoundary boundary,
    required double totalFarmAreaHectares,
    required double livestockAreaHectares,
    required double remainingAreaHectares,
  }) {
    final cropBoundary = boundary.coordinates
        .map((c) => GeoPoint(lat: c.latitude, lng: c.longitude))
        .toList();

    return [
      FarmZone(
        id: 'crop_remaining_land',
        name: 'Crop Zone - Remaining Land',
        description:
            'Inferred crop zone created from farm land remaining after livestock allocation',
        type: ZoneType.CROP,
        areaHectares: remainingAreaHectares,
        boundary: cropBoundary,
        metadata: {
          'zone_type': 'crop',
          'source': 'inference_engine',
          'inference_mode': 'remaining_land',
          'total_farm_area_hectares': totalFarmAreaHectares.toStringAsFixed(2),
          'livestock_allocated_area_hectares':
              livestockAreaHectares.toStringAsFixed(2),
          'remaining_area_hectares': remainingAreaHectares.toStringAsFixed(2),
          'expected_calendar':
              'PLANTING,GERMINATION,GROWTH,FLOWERING,GRAIN_FILL,HARVEST',
        },
      ),
    ];
  }

  static double _radiusForLivestockType(LivestockType type) {
    switch (type) {
      case LivestockType.CATTLE:
        return 90;
      case LivestockType.GOATS:
      case LivestockType.SHEEP:
        return 55;
      case LivestockType.PIGS:
        return 45;
      case LivestockType.CHICKENS:
      case LivestockType.GUINEA_FOWL:
        return 30;
      case LivestockType.BEEHIVES:
        return 25;
      case LivestockType.FISH_POND:
        return 65;
      case LivestockType.UNKNOWN:
        return 40;
    }
  }

  static List<ActivityStage> _expectedLivestockActivities(LivestockType type) {
    switch (type) {
      case LivestockType.CATTLE:
        return const [
          ActivityStage.GRAZING,
          ActivityStage.SUPPLEMENTAL_FEEDING,
          ActivityStage.HEALTH_CHECK,
          ActivityStage.BREEDING,
          ActivityStage.CALVING,
        ];
      case LivestockType.GOATS:
      case LivestockType.SHEEP:
        return const [
          ActivityStage.GRAZING,
          ActivityStage.SUPPLEMENTAL_FEEDING,
          ActivityStage.HEALTH_CHECK,
          ActivityStage.BREEDING,
        ];
      case LivestockType.PIGS:
        return const [
          ActivityStage.SUPPLEMENTAL_FEEDING,
          ActivityStage.HEALTH_CHECK,
          ActivityStage.BREEDING,
          ActivityStage.CLEANING,
        ];
      case LivestockType.CHICKENS:
      case LivestockType.GUINEA_FOWL:
        return const [
          ActivityStage.SUPPLEMENTAL_FEEDING,
          ActivityStage.HEALTH_CHECK,
          ActivityStage.CLEANING,
          ActivityStage.INSPECTION,
        ];
      case LivestockType.BEEHIVES:
        return const [
          ActivityStage.INSPECTION,
          ActivityStage.HEALTH_CHECK,
          ActivityStage.MAINTENANCE,
          ActivityStage.SEASONAL_CHECK,
        ];
      case LivestockType.FISH_POND:
        return const [
          ActivityStage.HEALTH_CHECK,
          ActivityStage.INSPECTION,
          ActivityStage.MAINTENANCE,
        ];
      case LivestockType.UNKNOWN:
        return const [
          ActivityStage.SUPPLEMENTAL_FEEDING,
          ActivityStage.HEALTH_CHECK,
          ActivityStage.INSPECTION,
        ];
    }
  }

  static String _livestockDisplayName(LivestockType type) {
    switch (type) {
      case LivestockType.CATTLE:
        return 'Cattle';
      case LivestockType.GOATS:
        return 'Goats';
      case LivestockType.PIGS:
        return 'Pigs';
      case LivestockType.CHICKENS:
        return 'Chickens';
      case LivestockType.SHEEP:
        return 'Sheep';
      case LivestockType.GUINEA_FOWL:
        return 'Guinea Fowl';
      case LivestockType.BEEHIVES:
        return 'Beehives';
      case LivestockType.FISH_POND:
        return 'Fish Pond';
      case LivestockType.UNKNOWN:
        return 'Unknown Livestock';
    }
  }

  static List<GeoCoordinate> _circleBoundary({
    required GeoCoordinate center,
    required double radiusMeters,
    required int segments,
  }) {
    final points = <GeoCoordinate>[];
    final latRadians = center.latitude * (math.pi / 180);
    final metersPerDegreeLat = 111320.0;
    final metersPerDegreeLng = 111320.0 * math.cos(latRadians);

    for (int i = 0; i <= segments; i++) {
      final angle = (2 * math.pi * i) / segments;
      final x = radiusMeters * math.cos(angle);
      final y = radiusMeters * math.sin(angle);

      final lat = center.latitude + (y / metersPerDegreeLat);
      final lng = center.longitude + (x / metersPerDegreeLng);
      points.add(GeoCoordinate(latitude: lat, longitude: lng));
    }

    return points;
  }
}
