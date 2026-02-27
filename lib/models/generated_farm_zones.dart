// GENERATED FILE - DO NOT EDIT MANUALLY
// This file was generated from KML zone files
// Run: python3 scripts/kml_to_dart.py assets/farm_data lib/models/generated/farm_zones.dart

import 'package:farmgenius/models/farm_zone.dart';

class GeneratedFarmZones {
  static const List<FarmZone> zones = [
    FarmZone(
      id: 'zone_a',
      name: 'Zone A - Maize',
      description: 'Primary maize crop zone',
      type: ZoneType.CROP,
      areaHectares: 5.2,
      boundary: const [
      const GeoPoint(lat: -7.078, lng: 38.914),
      const GeoPoint(lat: -7.078, lng: 38.92),
      const GeoPoint(lat: -7.083, lng: 38.92),
      const GeoPoint(lat: -7.083, lng: 38.914),
      const GeoPoint(lat: -7.078, lng: 38.914),
    ],
      metadata: {
      'zone_id': 'zone_a',
      'zone_type': 'crop',
      'crop_name': 'Maize',
      'crop_variety': 'Hybrid H515',
      'area_hectares': '5.2',
      'planting_date': '2025-11-15',
      'expected_maturity': '2026-02-28',
      'soil_type': 'loamy',
      'expected_calendar': 'PLANTING,GERMINATION,GROWTH,FLOWERING,GRAIN_FILL,HARVEST',
    },
    ),

    FarmZone(
      id: 'zone_b',
      name: 'Zone B - Livestock',
      description: 'Cattle grazing and rearing zone',
      type: ZoneType.LIVESTOCK,
      areaHectares: 8.0,
      boundary: const [
      const GeoPoint(lat: -7.085, lng: 38.916),
      const GeoPoint(lat: -7.085, lng: 38.924),
      const GeoPoint(lat: -7.092, lng: 38.924),
      const GeoPoint(lat: -7.092, lng: 38.916),
      const GeoPoint(lat: -7.085, lng: 38.916),
    ],
      metadata: {
      'zone_id': 'zone_b',
      'zone_type': 'livestock',
      'livestock_type': 'Cattle',
      'head_count': '24',
      'area_hectares': '8.0',
      'breed': 'Tanzanian Shorthorn',
      'expected_calendar': 'GRAZING,SUPPLEMENTAL_FEEDING,HEALTH_CHECK,BREEDING,CALVING',
    },
    ),

    FarmZone(
      id: 'zone_c',
      name: 'Zone C - Infrastructure',
      description: 'Water storage, equipment shed, and irrigation infrastructure',
      type: ZoneType.INFRASTRUCTURE,
      areaHectares: 0.5,
      boundary: const [
      const GeoPoint(lat: -7.093, lng: 38.913),
      const GeoPoint(lat: -7.093, lng: 38.915),
      const GeoPoint(lat: -7.095, lng: 38.915),
      const GeoPoint(lat: -7.095, lng: 38.913),
      const GeoPoint(lat: -7.093, lng: 38.913),
    ],
      metadata: {
      'zone_id': 'zone_c',
      'zone_type': 'infrastructure',
      'facilities': 'water_tank,equipment_shed,irrigation_pump',
      'water_tank_capacity_liters': '50000',
      'area_hectares': '0.5',
      'expected_calendar': 'MAINTENANCE,REPAIR,CLEANING,INSPECTION,SEASONAL_CHECK',
    },
    ),

  ];
}
