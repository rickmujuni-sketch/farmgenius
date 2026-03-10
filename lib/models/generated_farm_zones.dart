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
      boundary: [
      GeoPoint(lat: -7.078, lng: 38.914),
      GeoPoint(lat: -7.078, lng: 38.92),
      GeoPoint(lat: -7.083, lng: 38.92),
      GeoPoint(lat: -7.083, lng: 38.914),
      GeoPoint(lat: -7.078, lng: 38.914),
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
      description: 'Cattle grazing and rearing zone (updated stock records)',
      type: ZoneType.LIVESTOCK,
      areaHectares: 8.0,
      boundary: [
      GeoPoint(lat: -7.085, lng: 38.916),
      GeoPoint(lat: -7.085, lng: 38.924),
      GeoPoint(lat: -7.092, lng: 38.924),
      GeoPoint(lat: -7.092, lng: 38.916),
      GeoPoint(lat: -7.085, lng: 38.916),
    ],
      metadata: {
      'zone_id': 'zone_b',
      'zone_type': 'livestock',
      'livestock_type': 'Cattle',
      'head_count': '30',
      'area_hectares': '8.0',
      'breed': 'Jersey, Ayrshire, Holstein',
      'breed_mix': 'Jersey:10,Ayrshire:10,Holstein:10',
      'stock_update_date': '2026-02-16',
      'stock_update_note': 'Introduced Jersey, Ayrshire, Holstein cattle (10 each)',
      'expected_calendar': 'GRAZING,SUPPLEMENTAL_FEEDING,HEALTH_CHECK,BREEDING,CALVING',
    },
    ),

    FarmZone(
      id: 'zone_d',
      name: 'Zone D - Sheep',
      description: 'Dorper sheep grazing and health management zone',
      type: ZoneType.LIVESTOCK,
      areaHectares: 2.0,
      boundary: [
      GeoPoint(lat: -7.092, lng: 38.925),
      GeoPoint(lat: -7.092, lng: 38.927),
      GeoPoint(lat: -7.094, lng: 38.927),
      GeoPoint(lat: -7.094, lng: 38.925),
      GeoPoint(lat: -7.092, lng: 38.925),
    ],
      metadata: {
      'zone_id': 'zone_d',
      'zone_type': 'livestock',
      'livestock_type': 'Sheep',
      'head_count': '10',
      'area_hectares': '2.0',
      'breed': 'Dorper',
      'stock_update_date': '2026-02-16',
      'stock_update_note': 'Introduced Dorper sheep (10 head)',
      'expected_calendar': 'GRAZING,SUPPLEMENTAL_FEEDING,HEALTH_CHECK,BREEDING',
    },
    ),

    FarmZone(
      id: 'zone_c',
      name: 'Zone C - Infrastructure',
      description: 'Water storage, equipment shed, and irrigation infrastructure',
      type: ZoneType.INFRASTRUCTURE,
      areaHectares: 0.5,
      boundary: [
      GeoPoint(lat: -7.093, lng: 38.913),
      GeoPoint(lat: -7.093, lng: 38.915),
      GeoPoint(lat: -7.095, lng: 38.915),
      GeoPoint(lat: -7.095, lng: 38.913),
      GeoPoint(lat: -7.093, lng: 38.913),
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

  static List<FarmZone> get allZones {
    print('🔍 ZONES LOADED: ${zones.length} zones (source: generated_farm_zones.dart)');
    for (final zone in zones) {
      print('  - Zone: ${zone.name}, Type: ${zone.type}');
      print('    Boundary points: ${zone.boundary.length}');
      if (zone.boundary.isNotEmpty) {
        final first = zone.boundary.first;
        print('    Sample point: lat=${first.lat}, lng=${first.lng}');
      }
    }
    return List<FarmZone>.from(zones);
  }
}
