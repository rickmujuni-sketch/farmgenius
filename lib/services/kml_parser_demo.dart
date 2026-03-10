/// KML Parser Demo - Phase 1
/// Shows how the real farm KML is parsed and automatically categorized
/// Run this to see what zones will be auto-generated
library;

import 'package:flutter/foundation.dart';
import '../models/farm_zone.dart';
import 'kml_parser_service.dart';
import 'zone_inference_engine.dart';

class KmlParserDemo {
  /// Parse the actual farm KML and print extracted data
  static Future<void> parseAndPrintFarmKml() async {
    try {
      debugPrint('\n========== PHASE 1: KML PARSING ==========\n');

      // Parse the farm KML
      final farm = await KmlParser.parseFromAsset('assets/farm_data/farm_boundary.kml');

      debugPrint('📍 Farm Name: ${farm.farmName}');
      debugPrint('📐 Boundary: ${farm.boundary.name}');
      debugPrint('📏 Area: ${farm.boundary.areaHectares.toStringAsFixed(2)} hectares');
      debugPrint('🧭 Centroid: (${farm.boundary.centroid.latitude.toStringAsFixed(5)}, ${farm.boundary.centroid.longitude.toStringAsFixed(5)})');
      debugPrint('🔢 Boundary Points: ${farm.boundary.coordinates.length}');

      debugPrint('\n--- Extracted Placemarks ---\n');
      debugPrint('Total points: ${farm.placemarks.length}');

      debugPrint('\n📦 BY TYPE:');
      for (final type in farm.placemarksByType.keys) {
        final count = farm.placemarksByType[type]!.length;
        debugPrint('  • ${type.toString().split('.').last}: $count');
      }

      debugPrint('\n🐄 LIVESTOCK DETECTED:');
      if (farm.livestockByType.isEmpty) {
        debugPrint('  (none)');
      } else {
        for (final type in farm.livestockByType.keys) {
          final list = farm.livestockByType[type]!;
          debugPrint('  • ${type.toString().split('.').last}: ${list.length}');
          for (final pm in list) {
            debugPrint('    - ${pm.name} @ (${pm.location.latitude.toStringAsFixed(6)}, ${pm.location.longitude.toStringAsFixed(6)})');
          }
        }
      }

      debugPrint('\n🏢 INFRASTRUCTURE:');
      final infra = farm.infrastructurePlacemarks;
      if (infra.isEmpty) {
        debugPrint('  (none)');
      } else {
        for (final pm in infra) {
          final typeStr = pm.type?.toString().split('.').last ?? 'OTHER';
          debugPrint('  • $typeStr: ${pm.name}');
          debugPrint('    @ (${pm.location.latitude.toStringAsFixed(6)}, ${pm.location.longitude.toStringAsFixed(6)})');
        }
      }

      debugPrint('\n========== END PHASE 1 ==========\n');

      // Print summary for Phase 2
      debugPrint('\n========== PHASE 2: INFERENCE ENGINE OUTPUT ==========\n');
      final inferredZones = ZoneInferenceEngine.inferZones(farm);

      final livestockZones =
          inferredZones.where((z) => z.type == ZoneType.LIVESTOCK).toList();
      final cropZones =
          inferredZones.where((z) => z.type == ZoneType.CROP).toList();

      debugPrint('Inferred zones total: ${inferredZones.length}');

      debugPrint('\n🐄 LIVESTOCK ZONES: ${livestockZones.length}');
      for (final zone in livestockZones) {
        debugPrint('  • ${zone.name}');
        debugPrint('    - Radius: ${zone.metadata['radius_meters'] ?? 'n/a'}m');
        debugPrint('    - Area: ${zone.areaHectares.toStringAsFixed(2)} hectares');
        debugPrint('    - Livestock: ${zone.metadata['livestock_type'] ?? 'UNKNOWN'}');
        debugPrint('    - Activities: ${zone.metadata['expected_calendar'] ?? ''}');
      }

      debugPrint('\n🌾 CROP ZONES: ${cropZones.length}');
      for (final zone in cropZones) {
        debugPrint('  • ${zone.name}');
        debugPrint('    - Area: ${zone.areaHectares.toStringAsFixed(2)} hectares');
        debugPrint('    - Activities: ${zone.metadata['expected_calendar'] ?? ''}');
      }

      debugPrint('\n========== END PHASE 2 PREVIEW ==========\n');
    } catch (e, st) {
      debugPrint('❌ Parse Error: $e');
      debugPrint('$st');
    }
  }

  /// Quick test: verify KML file exists and is valid
  static Future<bool> testKmlFileExists() async {
    try {
      await KmlParser.parseFromAsset('assets/farm_data/farm_boundary.kml');
      debugPrint('✅ KML file parsed successfully');
      return true;
    } catch (e) {
      debugPrint('❌ KML file error: $e');
      return false;
    }
  }
}
